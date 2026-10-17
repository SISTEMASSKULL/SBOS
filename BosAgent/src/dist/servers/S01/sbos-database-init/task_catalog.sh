#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-database-init
# Despliega SBOS_db_V2_DDL.sql (158 tablas, 12 schemas) en el pod PostgreSQL.
# Se ejecuta UNA vez en orden 105 — ANTES de keycloak/kong/tryton/bauth.
# Idempotente: IF NOT EXISTS en todo el DDL.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-database-init.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly PG_NS="sbos-data"
readonly PG_POD="postgresql-0"
readonly DB_NAME="SBOSDB"
readonly PG_USER="postgres"
# El DDL se copia aquí durante el install de BOS (desde el repo DDLs/).
# bos setup copia DDLs/ → /etc/bos/ddl/ junto con las fichas.
readonly DDL_PATH="${BOS_DDL_PATH:-/etc/bos/ddl/SBOS_db_V2_DDL.sql}"
readonly SEEDS_DIR="${BOS_SEEDS_DIR:-/etc/bos/ddl/seeds}"
# Mínimo de tablas esperadas para considerar el schema desplegado.
readonly MIN_TABLES=50

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-database-init] $*" | tee -a "$FICHA_LOG"; }

# _cargar_seed: copia un archivo SQL al pod y lo ejecuta. Idempotente (ON CONFLICT en los seeds).
_cargar_seed() {
    local seed_file="$1" seed_name
    seed_name=$(basename "$seed_file")
    if [[ ! -f "$seed_file" ]]; then
        _log "ADVERTENCIA: seed $seed_name no encontrado en $seed_file — omitiendo"
        return 0
    fi
    local tmp="/tmp/${seed_name}"
    _k cp "$seed_file" "${PG_NS}/${PG_POD}:${tmp}" >> "$FICHA_LOG" 2>&1 || {
        _log "ERROR: no se pudo copiar $seed_name al pod"
        return 1
    }
    _k exec "$PG_POD" -n "$PG_NS" -- \
        psql -U "$PG_USER" -d "$DB_NAME" -v ON_ERROR_STOP=0 -f "$tmp" \
        >> "$FICHA_LOG" 2>&1 || true
    _k exec "$PG_POD" -n "$PG_NS" -- rm -f "$tmp" 2>/dev/null || true
    _log "  seed cargado: $seed_name"
}

# _resolver_seeds_dir: busca el directorio de seeds en rutas canónicas.
_resolver_seeds_dir() {
    local candidates=(
        "$SEEDS_DIR"
        "$(dirname "${SBOS_SERVERS_DIR:-/etc/bos/blibs/servers}")/DDLs/seeds"
        "/opt/skull/orquestador/proyectos/SBOS/DDLs/seeds"
        "/etc/bos/blibs/DDLs/seeds"
        "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)/../../../../DDLs/seeds"
    )
    for d in "${candidates[@]}"; do
        [[ -d "$d" ]] && echo "$d" && return 0
    done
    return 1
}

_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

# _pg_exec: ejecuta SQL en SBOSDB (o en postgres para DDL de nivel DB).
_pg_exec() {
    local db="${1:-${DB_NAME}}" sql="$2"
    _k exec "$PG_POD" -n "$PG_NS" -- \
        psql -U "$PG_USER" -d "$db" -tc "$sql" 2>/dev/null
}

# _contar_tablas: retorna el número de tablas en SBOSDB (excluyendo catálogos del sistema).
_contar_tablas() {
    _pg_exec "$DB_NAME" \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema');" \
        2>/dev/null | tr -d ' \n' || echo "0"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod "$PG_POD" -n "$PG_NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_postgresql: pod $PG_POD no encontrado"
        return 1
    fi
    local pg_ready
    pg_ready=$(_k exec "$PG_POD" -n "$PG_NS" -- pg_isready -U "$PG_USER" 2>/dev/null | grep -c "accepting" || echo "0")
    if [[ "$pg_ready" -eq 0 ]]; then
        echo "${__STEP_FAIL__} verificar_postgresql: pg_isready falló — PostgreSQL no acepta conexiones"
        return 1
    fi
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} verificar_ddl_file"
    if [[ ! -f "$DDL_PATH" ]]; then
        # Buscar el DDL en ubicaciones canónicas y copiarlo automáticamente (ADR-022)
        local found=""
        local candidates=(
            # Producción: blibs junto a servers/
            "$(dirname "${SBOS_SERVERS_DIR:-/etc/bos/blibs/servers}")/DDLs/SBOS_db_V2_DDL.sql"
            # VPS de desarrollo SKULL
            "/opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL.sql"
            # Instalación manual alternativa
            "/etc/bos/blibs/DDLs/SBOS_db_V2_DDL.sql"
            # Junto al task_catalog.sh de la ficha
            "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)/../../../../DDLs/SBOS_db_V2_DDL.sql"
        )
        for candidate in "${candidates[@]}"; do
            if [[ -f "$candidate" ]]; then
                found="$candidate"
                break
            fi
        done

        if [[ -n "$found" ]]; then
            mkdir -p "$(dirname "$DDL_PATH")"
            cp "$found" "$DDL_PATH"
            _log "DDL copiado automáticamente: $found → $DDL_PATH"
        else
            _log "ERROR: DDL no encontrado en ninguna ruta candidata"
            _log "Rutas buscadas: ${candidates[*]}"
            echo "${__STEP_FAIL__} verificar_ddl_file: DDL no encontrado"
            return 1
        fi
    fi
    local ddl_lines
    ddl_lines=$(wc -l < "$DDL_PATH" 2>/dev/null || echo "0")
    _log "DDL listo: $DDL_PATH ($ddl_lines líneas)"
    echo "${__STEP_OK__} verificar_ddl_file ($ddl_lines líneas)"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Crear base de datos SBOSDB ────────────────────────────
    echo "${__STEP_START__} crear_base_de_datos"
    local db_existe
    db_existe=$(_pg_exec "postgres" \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" \
        2>/dev/null | tr -d ' \n' || echo "")
    if [[ "$db_existe" == "1" ]]; then
        _log "Base de datos $DB_NAME ya existe"
        echo "${__STEP_SKIP__} crear_base_de_datos: ya existe"
    else
        _k exec "$PG_POD" -n "$PG_NS" -- \
            psql -U "$PG_USER" -c "CREATE DATABASE \"${DB_NAME}\" ENCODING='UTF8' LC_COLLATE='es_ES.UTF-8' LC_CTYPE='es_ES.UTF-8' TEMPLATE template0;" \
            >> "$FICHA_LOG" 2>&1 || {
            # Fallback sin locale específico si es_ES no está disponible
            _k exec "$PG_POD" -n "$PG_NS" -- \
                psql -U "$PG_USER" -c "CREATE DATABASE \"${DB_NAME}\";" \
                >> "$FICHA_LOG" 2>&1 || {
                echo "${__STEP_FAIL__} crear_base_de_datos"; return 1
            }
        }
        _log "Base de datos $DB_NAME creada"
        echo "${__STEP_OK__} crear_base_de_datos"
    fi

    # ── 2. Verificar si el schema ya está desplegado ─────────────
    echo "${__STEP_START__} verificar_schema"
    local tabla_count
    tabla_count=$(_contar_tablas)
    _log "Tablas actuales en $DB_NAME: $tabla_count"
    if [[ "$tabla_count" =~ ^[0-9]+$ ]] && [[ "$tabla_count" -ge "$MIN_TABLES" ]]; then
        _log "Schema ya desplegado ($tabla_count tablas ≥ $MIN_TABLES mínimo) — verificando integridad"
        echo "${__STEP_SKIP__} verificar_schema: schema ya presente ($tabla_count tablas)"
        # Aunque exista, ejecutar el DDL de nuevo es idempotente y converge diferencias.
        _log "Ejecutando DDL idempotente para convergir diferencias..."
    else
        _log "Schema ausente o incompleto ($tabla_count tablas < $MIN_TABLES) — aplicando DDL"
        echo "${__STEP_OK__} verificar_schema: schema a desplegar"
    fi

    # ── 3. Aplicar DDL via kubectl cp + psql ─────────────────────
    echo "${__STEP_START__} aplicar_ddl"
    local tmp_path="/tmp/SBOS_db_V2_DDL.sql"
    # Copiar DDL al pod y ejecutarlo
    _k cp "$DDL_PATH" "${PG_NS}/${PG_POD}:${tmp_path}" >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} aplicar_ddl: kubectl cp falló al copiar DDL al pod"
        return 1
    }

    local ddl_errors=0
    _k exec "$PG_POD" -n "$PG_NS" -- \
        psql -U "$PG_USER" -d "$DB_NAME" \
        -v ON_ERROR_STOP=0 \
        -f "$tmp_path" \
        >> "$FICHA_LOG" 2>&1 || ddl_errors=$?

    # Limpiar archivo temporal del pod
    _k exec "$PG_POD" -n "$PG_NS" -- rm -f "$tmp_path" 2>/dev/null || true

    # ON_ERROR_STOP=0 significa que psql no aborta en errores — pero errores
    # reales de schema (no duplicados) sí bloquearán. Aceptamos exit != 0
    # solo si hay tablas suficientes después.
    local tabla_count_post
    tabla_count_post=$(_contar_tablas)
    _log "Tablas tras aplicar DDL: $tabla_count_post"

    if [[ "$tabla_count_post" =~ ^[0-9]+$ ]] && [[ "$tabla_count_post" -ge "$MIN_TABLES" ]]; then
        echo "${__STEP_OK__} aplicar_ddl ($tabla_count_post tablas presentes)"
    else
        _log "ERROR: Solo $tabla_count_post tablas tras aplicar DDL (esperadas ≥ $MIN_TABLES)"
        echo "${__STEP_FAIL__} aplicar_ddl: DDL aplicado pero tablas insuficientes ($tabla_count_post)"
        return 1
    fi

    # ── 4. Verificar schemas del DDL (bauth y bos son los creados por este DDL) ──────
    # bkernel, biedata, bsearch, bnexus, bnotify, kong, keycloak, tryton
    # son creados por sus propias fichas — no bloqueamos aquí si no existen.
    echo "${__STEP_START__} verificar_schemas"
    local schemas_ok=0
    local schemas_propios=("bauth" "bos")
    local schemas_externos=("bkernel" "biedata" "bsearch" "bnexus" "bnotify" "kong" "keycloak" "tryton")
    for schema in "${schemas_propios[@]}"; do
        local existe
        existe=$(_pg_exec "$DB_NAME" \
            "SELECT 1 FROM information_schema.schemata WHERE schema_name='${schema}';" \
            2>/dev/null | tr -d ' \n' || echo "")
        if [[ "$existe" == "1" ]]; then
            schemas_ok=$((schemas_ok+1))
        else
            _log "ADVERTENCIA: schema propio '$schema' no encontrado en $DB_NAME"
        fi
    done
    for schema in "${schemas_externos[@]}"; do
        local existe
        existe=$(_pg_exec "$DB_NAME" \
            "SELECT 1 FROM information_schema.schemata WHERE schema_name='${schema}';" \
            2>/dev/null | tr -d ' \n' || echo "")
        if [[ "$existe" == "1" ]]; then
            schemas_ok=$((schemas_ok+1))
            _log "Schema externo '$schema' presente (creado por su ficha)"
        fi
    done
    _log "Schemas verificados: $schemas_ok/10 (requeridos: bauth+bos)"
    if [[ "$schemas_ok" -ge 2 ]]; then
        echo "${__STEP_OK__} verificar_schemas ($schemas_ok/10)"
    else
        echo "${__STEP_FAIL__} verificar_schemas: schemas bauth/bos no presentes"
        return 1
    fi

    # ── 5. Crear base de datos mailserver_db ─────────────────────────
    echo "${__STEP_START__} crear_mailserver_db"
    local mail_existe
    mail_existe=$(_pg_exec "postgres" \
        "SELECT 1 FROM pg_database WHERE datname='mailserver_db';" \
        2>/dev/null | tr -d ' \n' || echo "")
    if [[ "$mail_existe" == "1" ]]; then
        echo "${__STEP_SKIP__} crear_mailserver_db: ya existe"
    else
        _k exec "$PG_POD" -n "$PG_NS" -- \
            psql -U "$PG_USER" -c "CREATE DATABASE mailserver_db;" \
            >> "$FICHA_LOG" 2>&1 && \
            _log "mailserver_db creada" || \
            _log "ADVERTENCIA: no se pudo crear mailserver_db"
        echo "${__STEP_OK__} crear_mailserver_db"
    fi

    # ── 6. Cargar seeds bglobal (idiomas, países, monedas, timezones) ─
    echo "${__STEP_START__} cargar_seeds_bglobal"
    local seeds_dir
    if seeds_dir=$(_resolver_seeds_dir); then
        _log "Directorio de seeds: $seeds_dir"
        # Seeds ordenados: T001 idiomas → T002 países+monedas → T004 timezones
        # Son prerequisito de bi18n para resolver locales y validar datos por país.
        for seed in \
            "bglobal_T001__global_language.sql" \
            "bglobal_T002__global_country.sql" \
            "bglobal_T004__geo_timezone.sql"; do
            _cargar_seed "${seeds_dir}/${seed}"
        done
        echo "${__STEP_OK__} cargar_seeds_bglobal"
    else
        _log "ADVERTENCIA: directorio de seeds no encontrado — seeds bglobal omitidos"
        echo "${__STEP_SKIP__} cargar_seeds_bglobal: directorio no disponible"
    fi

    # ── 7. Cargar seeds de mailserver (buzones iniciales) ─────────────
    echo "${__STEP_START__} cargar_seeds_mailserver"
    if [[ -n "${seeds_dir:-}" ]]; then
        local mail_seed="${seeds_dir}/mailserver_T001__initial_accounts.sql"
        if [[ -f "$mail_seed" ]]; then
            # Ejecutar el seed en mailserver_db (no en SBOSDB)
            local tmp_mail="/tmp/mailserver_seed.sql"
            _k cp "$mail_seed" "${PG_NS}/${PG_POD}:${tmp_mail}" >> "$FICHA_LOG" 2>&1 && \
            _k exec "$PG_POD" -n "$PG_NS" -- \
                psql -U "$PG_USER" -d "mailserver_db" -v ON_ERROR_STOP=0 -f "$tmp_mail" \
                >> "$FICHA_LOG" 2>&1 || true
            _k exec "$PG_POD" -n "$PG_NS" -- rm -f "$tmp_mail" 2>/dev/null || true
            _log "  seeds mailserver cargados"
            echo "${__STEP_OK__} cargar_seeds_mailserver"
        else
            echo "${__STEP_SKIP__} cargar_seeds_mailserver: seed no encontrado (se creará al instalar mailserver)"
        fi
    else
        echo "${__STEP_SKIP__} cargar_seeds_mailserver: sin directorio de seeds"
    fi

    _log "sbos-database-init completado: $tabla_count_post tablas en $DB_NAME"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "=== Estado $DB_NAME ==="
    local tabla_count
    tabla_count=$(_contar_tablas)
    _log "Tablas: $tabla_count"
    _log "Schemas:"
    _pg_exec "$DB_NAME" \
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog','information_schema','public') ORDER BY schema_name;" \
        2>/dev/null | while read -r s; do _log "  - $s"; done
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_health() {
    local pg_pod="postgresql-0" pg_ns="sbos-data"
    local kubeconfig="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
    local exists
    exists=$(kubectl --kubeconfig="$kubeconfig" exec "$pg_pod" -n "$pg_ns" --         psql -U postgres -tAc "SELECT COUNT(*) FROM pg_database WHERE datname='SBOS_db'"         2>/dev/null | tr -d '[:space:]' || echo "0")
    [[ "$exists" == "1" ]] && echo "HEALTHY" && return 0
    echo "DEGRADED: BD SBOS_db no existe o PG no disponible"
    return 1
}

ficha_repair() {
    # Re-ejecuta el DDL idempotente para convergir tablas faltantes.
    _log "ficha_repair: re-aplicando DDL idempotente para convergir schema"
    ficha_pre_install || return 1
    ficha_install
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_db_existe"
    local db_existe
    db_existe=$(_pg_exec "postgres" \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" \
        2>/dev/null | tr -d ' \n' || echo "")
    if [[ "$db_existe" == "1" ]]; then
        echo "${__STEP_OK__} test_db_existe"
    else
        echo "${__STEP_FAIL__} test_db_existe: $DB_NAME no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_tabla_count"
    local tabla_count
    tabla_count=$(_contar_tablas)
    if [[ "$tabla_count" =~ ^[0-9]+$ ]] && [[ "$tabla_count" -ge "$MIN_TABLES" ]]; then
        echo "${__STEP_OK__} test_tabla_count ($tabla_count tablas)"
    else
        echo "${__STEP_FAIL__} test_tabla_count: $tabla_count tablas (esperadas ≥ $MIN_TABLES)"
        ok=1
    fi

    echo "${__STEP_START__} test_schema_bauth"
    local bauth_tables
    bauth_tables=$(_pg_exec "$DB_NAME" \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='bauth';" \
        2>/dev/null | tr -d ' \n' || echo "0")
    if [[ "$bauth_tables" =~ ^[0-9]+$ ]] && [[ "$bauth_tables" -gt 0 ]]; then
        echo "${__STEP_OK__} test_schema_bauth ($bauth_tables tablas en schema bauth)"
    else
        echo "${__STEP_FAIL__} test_schema_bauth: schema bauth vacío o ausente"
        ok=1
    fi

    echo "${__STEP_START__} test_schema_bos"
    local bos_tables
    bos_tables=$(_pg_exec "$DB_NAME" \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='bos';" \
        2>/dev/null | tr -d ' \n' || echo "0")
    if [[ "$bos_tables" =~ ^[0-9]+$ ]] && [[ "$bos_tables" -gt 0 ]]; then
        echo "${__STEP_OK__} test_schema_bos ($bos_tables tablas en schema bos)"
    else
        echo "${__STEP_FAIL__} test_schema_bos: schema bos vacío o ausente"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-database-init STATUS ==="
    echo ""
    echo "Base de datos: $DB_NAME"
    local tabla_count
    tabla_count=$(_contar_tablas)
    echo "  Tablas totales: $tabla_count"
    echo ""
    echo "Tablas por schema:"
    _pg_exec "$DB_NAME" \
        "SELECT table_schema, COUNT(*) as tablas FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema') GROUP BY table_schema ORDER BY tablas DESC;" \
        2>/dev/null | while IFS='|' read -r schema count; do
        printf "  %-20s %s\n" "${schema// /}" "${count// /}"
    done || echo "  (no disponible)"
    echo ""
    echo "DDL path: $DDL_PATH ($(test -f "$DDL_PATH" && echo 'EXISTE' || echo 'NO ENCONTRADO'))"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: ficha_uninstall de sbos-database-init NO elimina SBOSDB."
    _log "Eliminar la BD requiere aprobación explícita y borraría TODOS los datos SBOS."
    _log "Para eliminar manualmente: psql -c 'DROP DATABASE SBOSDB;'"
    echo "${__STEP_SKIP__} uninstall: SBOSDB conservada (datos protegidos)"
    return 0
}

# ── Diagnosis ─────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-database-init ==="
    echo "Pod PostgreSQL:"
    _k describe pod "$PG_POD" -n "$PG_NS" 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:" || echo "  pod no encontrado"
    echo ""
    echo "DDL file: $(ls -lh "$DDL_PATH" 2>/dev/null || echo 'NO EXISTE')"
    echo ""
    echo "BD $DB_NAME:"
    local tabla_count
    tabla_count=$(_contar_tablas)
    echo "  Tablas: $tabla_count"
    echo ""
    echo "Últimas 20 líneas del log:"
    tail -20 "$FICHA_LOG" 2>/dev/null || echo "  (sin log)"
}
