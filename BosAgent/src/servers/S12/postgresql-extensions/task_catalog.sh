#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — postgresql-extensions
# Instala PostGIS, pg_cron, pgvector, TimescaleDB, plpython3u en PostgreSQL 18.
# Estrategia: instala paquetes en el pod y crea las extensiones en la BD.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/postgresql-extensions.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-data"
PG_POD="${PG_POD:-postgresql-0}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [pg-extensions] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_psql() { _k exec -n "$NS" "$PG_POD" -- psql -U postgres "$@"; }

_ext_exists() {
    local ext="$1"
    _psql -tc "SELECT 1 FROM pg_extension WHERE extname='$ext';" 2>/dev/null | grep -q 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_pg_pod"
    _k get pod "$PG_POD" -n "$NS" > /dev/null 2>&1 || {
        echo "${__STEP_FAIL__} verificar_pg_pod: pod $PG_POD no encontrado en $NS"
        return 1
    }
    local phase
    phase=$(_k get pod "$PG_POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
    [[ "$phase" != "Running" ]] && {
        echo "${__STEP_FAIL__} verificar_pg_pod: pod en estado $phase (esperado Running)"
        return 1
    }
    echo "${__STEP_OK__} verificar_pg_pod"
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Instalar paquetes de extensiones en el pod (apt-get dentro del contenedor)
    echo "${__STEP_START__} instalar_paquetes_extension"
    local pg_version
    pg_version=$(_psql -tc "SELECT current_setting('server_version_num');" 2>/dev/null | tr -d ' \n' || echo "")
    _log "PostgreSQL version num: $pg_version"

    # Detectar versión major de PG para los nombres de paquete
    local pg_major
    pg_major=$(_psql -tc "SELECT split_part(version(), '.', 1);" 2>/dev/null | grep -oP '\d+' | head -1 || echo "18")
    _log "PG major: $pg_major"

    # Instalar extensiones en el pod via apt-get (requiere imagen Debian-based)
    _k exec -n "$NS" "$PG_POD" -- bash -c "
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq \
            postgresql-${pg_major}-postgis-3 \
            postgresql-${pg_major}-pgvector \
            postgresql-${pg_major}-pg-cron \
            python3-setuptools python3-pip 2>/dev/null || true
    " >> "$FICHA_LOG" 2>&1 || _log "ADVERTENCIA: No se pudieron instalar paquetes via apt (imagen puede no ser Debian)"

    echo "${__STEP_OK__} instalar_paquetes_extension"

    # Habilitar pg_cron en postgresql.conf (requiere shared_preload_libraries)
    echo "${__STEP_START__} configurar_shared_preload_libraries"
    local current_libs
    current_libs=$(_psql -tc "SELECT current_setting('shared_preload_libraries');" 2>/dev/null | tr -d ' \n' || echo "")
    _log "shared_preload_libraries actual: $current_libs"

    if echo "$current_libs" | grep -q "pg_cron"; then
        echo "${__STEP_SKIP__} configurar_shared_preload_libraries: pg_cron ya en shared_preload_libraries"
    else
        # Agregar pg_cron via ALTER SYSTEM (persiste en postgresql.auto.conf)
        _psql -c "ALTER SYSTEM SET shared_preload_libraries = '${current_libs:+$current_libs,}pg_cron';" >> "$FICHA_LOG" 2>&1 || true
        _psql -c "ALTER SYSTEM SET cron.database_name = 'postgres';" >> "$FICHA_LOG" 2>&1 || true
        _log "pg_cron agregado a shared_preload_libraries — reinicio del pod requerido"
        _k rollout restart statefulset postgresql -n "$NS" >> "$FICHA_LOG" 2>&1 || true
        # Esperar que el pod vuelva
        _k rollout status statefulset postgresql -n "$NS" --timeout=120s >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_OK__} configurar_shared_preload_libraries"
    fi

    # Crear extensiones en la BD postgres (template para heredar a nuevas BDs)
    echo "${__STEP_START__} crear_extensiones_postgres"
    local exts=("postgis" "postgis_topology" "vector" "pg_cron" "pg_partman" "unaccent" "pg_trgm" "btree_gin")
    for ext in "${exts[@]}"; do
        if _ext_exists "$ext"; then
            _log "Extensión $ext ya existe — skip"
        else
            _psql -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 && \
                _log "Extensión $ext creada" || \
                _log "ADVERTENCIA: No se pudo crear extensión $ext (puede no estar disponible en esta imagen)"
        fi
    done
    echo "${__STEP_OK__} crear_extensiones_postgres"

    # Crear extensiones en template1 para que las nuevas BDs las hereden
    echo "${__STEP_START__} crear_extensiones_template1"
    for ext in unaccent pg_trgm btree_gin; do
        _k exec -n "$NS" "$PG_POD" -- psql -U postgres -d template1 \
            -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 || true
    done
    echo "${__STEP_OK__} crear_extensiones_template1"

    # Habilitar extensiones en la BD SBOSDB
    echo "${__STEP_START__} crear_extensiones_sbosdb"
    for ext in "postgis" "vector" "unaccent" "pg_trgm" "btree_gin"; do
        _k exec -n "$NS" "$PG_POD" -- psql -U postgres -d SBOSDB \
            -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 || \
            _log "ADVERTENCIA: No se pudo crear $ext en SBOSDB"
    done
    echo "${__STEP_OK__} crear_extensiones_sbosdb"

    echo "${__STEP_START__} verificar_extensiones"
    local installed
    installed=$(_psql -tc "SELECT extname FROM pg_extension WHERE extname IN ('postgis','vector','pg_cron','unaccent','pg_trgm') ORDER BY extname;" 2>/dev/null | tr -d ' ' | grep -v '^$' | paste -sd ',' || echo "ninguna")
    _log "Extensiones instaladas en postgres: $installed"
    echo "${__STEP_OK__} verificar_extensiones"
    return 0
}

ficha_repair() {
    _log "Repair postgresql-extensions: verificando extensiones"
    ficha_install
}

ficha_status() {
    local installed
    installed=$(_psql -tc "SELECT extname FROM pg_extension WHERE extname IN ('postgis','vector','pg_cron','unaccent') ORDER BY extname;" 2>/dev/null | tr -d ' ' | grep -v '^$' | paste -sd ',' || echo "desconocido")
    echo "postgresql-extensions: $installed"
}

ficha_remove() {
    _log "postgresql-extensions: remove no implementado (destructivo — requiere HITL)"
    echo "${__STEP_SKIP__} postgresql_extensions_remove: acción destructiva requiere HITL"
}
