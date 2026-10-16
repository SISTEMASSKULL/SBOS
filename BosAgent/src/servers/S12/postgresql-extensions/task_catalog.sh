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
_psql() { _k exec -n "$NS" "$PG_POD" -c postgresql -- psql -U postgres "$@"; }

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
    _k exec -n "$NS" "$PG_POD" -c postgresql -- bash -c "
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq \
            postgresql-${pg_major}-postgis-3 \
            postgresql-${pg_major}-pgvector \
            postgresql-${pg_major}-pg-cron \
            python3-setuptools python3-pip 2>/dev/null || true
    " >> "$FICHA_LOG" 2>&1 || _log "ADVERTENCIA: No se pudieron instalar paquetes via apt (imagen puede no ser Debian)"

    echo "${__STEP_OK__} instalar_paquetes_extension"

    # Habilitar pg_cron SOLO si la librería existe en el pod
    # La imagen postgres:xx-alpine NO incluye pg_cron por defecto.
    # Verificar antes de tocar shared_preload_libraries para evitar CrashLoop.
    echo "${__STEP_START__} configurar_shared_preload_libraries"
    local pg_cron_so
    pg_cron_so=$(_k exec -n "$NS" "$PG_POD" -c postgresql -- \
        find /usr/lib/postgresql /usr/local/lib/postgresql -name "pg_cron.so" 2>/dev/null | head -1 || echo "")
    if [[ -z "$pg_cron_so" ]]; then
        _log "pg_cron.so no encontrado en imagen — skipping shared_preload_libraries (imagen Alpine sin pg_cron)"
        # Limpiar pg_cron del auto.conf si quedó de ejecuciones previas.
        # Sin pg_cron.so, PostgreSQL crashea al arrancar con esa librería cargada.
        local pg_autoconf="/data/postgres/pgdata/postgresql.auto.conf"
        if [[ -f "$pg_autoconf" ]] && grep -qE 'pg_cron|cron\.database_name' "$pg_autoconf" 2>/dev/null; then
            sed -i '/pg_cron/d; /cron\.database_name/d' "$pg_autoconf"
            _log "pg_cron eliminado de $pg_autoconf — reiniciando pod"
            kubectl --kubeconfig="${KUBECONFIG_DEST:-/etc/bos/.kube/config}" \
                delete pod "$PG_POD" -n "$NS" --grace-period=5 2>/dev/null || true
            sleep 8
        fi
        echo "${__STEP_SKIP__} configurar_shared_preload_libraries: pg_cron no disponible en imagen"
    else
        local current_libs
        current_libs=$(_psql -tc "SELECT current_setting('shared_preload_libraries');" 2>/dev/null | tr -d ' \n' || echo "")
        if echo "$current_libs" | grep -q "pg_cron"; then
            echo "${__STEP_SKIP__} configurar_shared_preload_libraries: pg_cron ya configurado"
        else
            _psql -c "ALTER SYSTEM SET shared_preload_libraries = '${current_libs:+$current_libs,}pg_cron';" >> "$FICHA_LOG" 2>&1 || true
            _psql -c "ALTER SYSTEM SET cron.database_name = 'postgres';" >> "$FICHA_LOG" 2>&1 || true
            _log "pg_cron agregado — reiniciando pod para activar"
            _k rollout restart statefulset postgresql -n "$NS" >> "$FICHA_LOG" 2>&1 || true
            _k rollout status statefulset postgresql -n "$NS" --timeout=120s >> "$FICHA_LOG" 2>&1 || true
            echo "${__STEP_OK__} configurar_shared_preload_libraries"
        fi
    fi

    # Instalar extensiones que sí estén disponibles en esta imagen
    # Primero consultar pg_available_extensions (fuente de verdad del binario)
    echo "${__STEP_START__} crear_extensiones_disponibles"
    local available
    available=$(_psql -tc "SELECT name FROM pg_available_extensions ORDER BY name;" 2>/dev/null | tr -d ' \n' || echo "")
    _log "Extensiones disponibles en imagen: $(echo "$available" | tr '\n' ' ' | head -c 200)"

    # Solo intentar las que pg_available_extensions confirma que existen
    local wanted=("unaccent" "pg_trgm" "btree_gin" "btree_gist" "hstore" "uuid-ossp"
                  "postgis" "postgis_topology" "vector" "pg_cron" "pg_partman"
                  "timescaledb" "plpython3u")
    for ext in "${wanted[@]}"; do
        if echo "$available" | grep -qw "$ext"; then
            if _ext_exists "$ext"; then
                _log "Extensión $ext ya existe — skip"
            else
                _psql -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 && \
                    _log "Extensión $ext creada" || \
                    _log "ADVERTENCIA: $ext disponible pero CREATE EXTENSION falló"
            fi
        else
            _log "Extensión $ext no disponible en esta imagen — skip"
        fi
    done
    echo "${__STEP_OK__} crear_extensiones_disponibles"

    # Crear extensiones estándar en template1 (heredadas por nuevas BDs)
    echo "${__STEP_START__} crear_extensiones_template1"
    for ext in unaccent pg_trgm btree_gin; do
        if echo "$available" | grep -qw "$ext"; then
            _k exec -n "$NS" "$PG_POD" -c postgresql -- psql -U postgres -d template1 \
                -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 || true
        fi
    done
    echo "${__STEP_OK__} crear_extensiones_template1"

    # Habilitar extensiones disponibles en SBOSDB
    echo "${__STEP_START__} crear_extensiones_sbosdb"
    for ext in unaccent pg_trgm btree_gin uuid-ossp hstore; do
        if echo "$available" | grep -qw "$ext"; then
            _k exec -n "$NS" "$PG_POD" -c postgresql -- psql -U postgres -d SBOSDB \
                -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" >> "$FICHA_LOG" 2>&1 || true
        fi
    done
    echo "${__STEP_OK__} crear_extensiones_sbosdb"

    echo "${__STEP_START__} verificar_extensiones"
    local installed
    installed=$(_psql -tc "SELECT extname FROM pg_extension ORDER BY extname;" 2>/dev/null | tr -d ' ' | grep -v '^$' | paste -sd ',' || echo "ninguna")
    _log "Extensiones en BD postgres: $installed"
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
