#!/usr/bin/env bash
# =============================================================================
# inicializar_sbos_db.sh — Orquestador de carga DDL + Seeds para SBOS
#
# Uso:
#   ./inicializar_sbos_db.sh [DB_NAME] [DB_HOST] [DB_PORT] [DB_USER]
#
# Ejemplos:
#   ./inicializar_sbos_db.sh SBOSDB_copia localhost 15432    # prueba
#   ./inicializar_sbos_db.sh SBOSDB       localhost 15432    # producción
#   PGPASSWORD=secreto ./inicializar_sbos_db.sh SBOSDB_copia 13.140.128.230 15432
#
# Fases:
#   1. DDL principal  (SBOS_db_V2_DDL.sql)
#   2. BOS schema     (bos_01__control_plane.sql)
#   3. Migraciones    (migrations/*.sql en orden alfabético)
#   4. Seeds          (seeds/*.sql en orden alfabético)
#   5. Idempotencia   (segunda pasada de DDL + migraciones, 0 errores esperados)
#   6. Completitud    (conteo de tablas + tablas clave + seeds críticos)
# =============================================================================

set -euo pipefail

# ── Parámetros de conexión ───────────────────────────────────────────────────
DB_NAME="${1:-SBOSDB_copia}"
DB_HOST="${2:-localhost}"
DB_PORT="${3:-15432}"
DB_USER="${4:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ts()   { date '+%H:%M:%S'; }
log()  { echo -e "${GREEN}[$(ts)] $*${NC}"; }
info() { echo -e "${BLUE}[$(ts)] $*${NC}"; }
warn() { echo -e "${YELLOW}[$(ts)] AVISO: $*${NC}"; }
fail() { echo -e "${RED}[$(ts)] ERROR: $*${NC}"; exit 1; }

# ── Carga un archivo SQL; captura errores; devuelve número de ERRORs ─────────
cargar_archivo() {
    local archivo="$1"
    local descripcion="${2:-$(basename "$archivo")}"
    info "  → $descripcion" >&2
    local salida
    salida=$($PSQL -f "$archivo" 2>&1 || true)
    local errores
    errores=$(echo "$salida" | grep -c "^ERROR" || true)
    if [[ "$errores" -gt 0 ]]; then
        echo "$salida" | grep "^ERROR" | head -5 >&2
    fi
    echo "$errores"
}

# ── Verifica que el archivo exista ───────────────────────────────────────────
check_file() {
    [[ -f "$1" ]] || fail "Archivo no encontrado: $1"
}

# ── Conteo de errores acumulados ─────────────────────────────────────────────
TOTAL_ERRORES=0
sumar_errores() { TOTAL_ERRORES=$((TOTAL_ERRORES + $1)); }

# =============================================================================
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}  SBOS DB Initializer${NC}"
echo -e "${BOLD}  Base: $DB_NAME @ $DB_HOST:$DB_PORT (usuario: $DB_USER)${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

# ── Verificar conexión ───────────────────────────────────────────────────────
log "Verificando conexión a $DB_NAME..."
$PSQL -c "SELECT version();" -t 2>/dev/null | head -1 | xargs || \
    fail "No se puede conectar a $DB_NAME. Verifica host, puerto y credenciales."
log "Conexión OK"

# =============================================================================
# FASE 1 — DDL principal (bglobal + bauth + bcalendar — entrelazado por FK)
# =============================================================================
echo ""
log "FASE 1 — DDL principal (bglobal + bauth + bcalendar)"
check_file "$DIR/SBOS_db_V2_DDL.sql"
n=$(cargar_archivo "$DIR/SBOS_db_V2_DDL.sql" "SBOS_db_V2_DDL.sql")
sumar_errores "$n"
[[ "$n" -eq 0 ]] && log "FASE 1 OK" || warn "FASE 1: $n error(es)"

# =============================================================================
# FASE 2 — BOS Control Plane (schema bos — depende de bauth.idn_tenant)
# =============================================================================
echo ""
log "FASE 2 — BOS Control Plane (schema bos)"
check_file "$DIR/bos_01__control_plane.sql"
n=$(cargar_archivo "$DIR/bos_01__control_plane.sql" "bos_01__control_plane.sql")
sumar_errores "$n"
[[ "$n" -eq 0 ]] && log "FASE 2 OK" || warn "FASE 2: $n error(es)"

# =============================================================================
# FASE 3 — Migraciones (orden alfabético dentro de migrations/)
# =============================================================================
echo ""
log "FASE 3 — Migraciones bAuth dominios"
MIGRACIONES=("$DIR/migrations/"*.sql)
if [[ ${#MIGRACIONES[@]} -eq 0 || ! -f "${MIGRACIONES[0]}" ]]; then
    warn "No hay archivos en migrations/ — omitiendo fase 3"
else
    fase3_err=0
    for archivo in "${MIGRACIONES[@]}"; do
        n=$(cargar_archivo "$archivo")
        sumar_errores "$n"
        fase3_err=$((fase3_err + n))
    done
    [[ "$fase3_err" -eq 0 ]] && log "FASE 3 OK (${#MIGRACIONES[@]} migración(es))" || warn "FASE 3: $fase3_err error(es)"
fi

# =============================================================================
# FASE 4 — Seeds (orden alfabético: bglobal → bauth → bcalendar → bos)
# =============================================================================
echo ""
log "FASE 4 — Seeds"
SEEDS=("$DIR/seeds/"*.sql)
if [[ ${#SEEDS[@]} -eq 0 || ! -f "${SEEDS[0]}" ]]; then
    warn "No hay seeds en seeds/ — omitiendo fase 4"
else
    fase4_err=0
    for seed in "${SEEDS[@]}"; do
        n=$(cargar_archivo "$seed")
        sumar_errores "$n"
        fase4_err=$((fase4_err + n))
    done
    [[ "$fase4_err" -eq 0 ]] && log "FASE 4 OK (${#SEEDS[@]} seed(s))" || warn "FASE 4: $fase4_err error(es)"
fi

# =============================================================================
# FASE 5 — Idempotencia (segunda pasada de DDL + migraciones)
# Los seeds ya son idempotentes por ON CONFLICT — no se re-verifican aquí
# =============================================================================
echo ""
log "FASE 5 — Verificación de idempotencia (segunda pasada)"

idempotencia_err=0

for archivo in \
    "$DIR/SBOS_db_V2_DDL.sql" \
    "$DIR/bos_01__control_plane.sql" \
    "${MIGRACIONES[@]:-}"; do
    [[ -f "$archivo" ]] || continue
    n=$(cargar_archivo "$archivo" "[idempotencia] $(basename "$archivo")")
    idempotencia_err=$((idempotencia_err + n))
done

if [[ "$idempotencia_err" -eq 0 ]]; then
    log "FASE 5 OK — Idempotencia verificada (0 errores en segunda pasada)"
else
    fail "FASE 5 FALLA — $idempotencia_err error(es) de idempotencia detectados"
fi

# =============================================================================
# FASE 6 — Completitud
# =============================================================================
echo ""
log "FASE 6 — Verificación de completitud"

# ── 6.1 Tablas por schema ────────────────────────────────────────────────────
echo ""
info "  Tablas por schema:"
$PSQL -t -c "
SELECT '  ' || RPAD(table_schema, 12) || ' → ' || COUNT(*)::TEXT || ' tablas'
FROM information_schema.tables
WHERE table_schema IN ('bauth','bglobal','bcalendar','bos')
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY table_schema;
" 2>/dev/null

TOTAL_TABLAS=$($PSQL -t -c "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema IN ('bauth','bglobal','bcalendar','bos')
  AND table_type = 'BASE TABLE';
" 2>/dev/null | tr -d ' \n')
info "  Total: $TOTAL_TABLAS tablas (BASE TABLE, excluye particiones en este conteo)"

# Total incluyendo particiones
TOTAL_CON_PARTIC=$($PSQL -t -c "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema IN ('bauth','bglobal','bcalendar','bos');
" 2>/dev/null | tr -d ' \n')
info "  Total incluyendo particiones: $TOTAL_CON_PARTIC"

# ── 6.2 Tablas clave ─────────────────────────────────────────────────────────
echo ""
info "  Tablas clave bAuth (D99 Admin Global):"
FALTANTES=0
verificar_tabla() {
    local schema="$1" tabla="$2"
    local existe
    existe=$($PSQL -t -c "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema='$schema' AND table_name='$tabla';
" 2>/dev/null | tr -d ' \n')
    if [[ "$existe" == "1" ]]; then
        echo -e "    ${GREEN}✓ $schema.$tabla${NC}"
    else
        echo -e "    ${RED}✗ $schema.$tabla — FALTA${NC}"
        FALTANTES=$((FALTANTES + 1))
    fi
}

# D99
verificar_tabla bauth idn_global_admin
verificar_tabla bauth idn_global_crypto_params
verificar_tabla bauth idn_global_notification
verificar_tabla bauth idn_global_hitl_exception
verificar_tabla bauth idn_global_compliance_control
verificar_tabla bauth idn_global_sbom
echo ""
info "  D07 Red/ZTA:"
verificar_tabla bauth idn_network_connection_policy
verificar_tabla bauth idn_network_dpop_binding
verificar_tabla bauth idn_network_segment
echo ""
info "  D09 Credenciales:"
verificar_tabla bauth idn_credential_password_history
verificar_tabla bauth idn_credential_token_issued
echo ""
info "  D02 Acceso Físico:"
verificar_tabla bauth idn_physical_access_location
verificar_tabla bauth idn_physical_access_reader
verificar_tabla bauth idn_physical_access_event_log
echo ""
info "  D03 Financiero:"
verificar_tabla bauth idn_financial_limit
verificar_tabla bauth idn_financial_approval
verificar_tabla bauth idn_financial_tpp_consent
echo ""
info "  D04 Temporal:"
verificar_tabla bauth idn_temporal_window
verificar_tabla bauth idn_temporal_shift
echo ""
info "  D05 Biométrico:"
verificar_tabla bauth idn_biometric_enrollment
verificar_tabla bauth idn_biometric_pad_policy
echo ""
info "  D06 Geoespacial:"
verificar_tabla bauth idn_geospatial_geofence
verificar_tabla bauth idn_geospatial_location_log
verificar_tabla bauth idn_geospatial_data_residency
echo ""
info "  D10 Delegación:"
verificar_tabla bauth idn_delegation_grant
verificar_tabla bauth idn_delegation_chain
verificar_tabla bauth idn_delegation_rar_request
echo ""
info "  D11 Auditoría:"
verificar_tabla bauth idn_audit_event_log
verificar_tabla bauth idn_audit_retention_policy
verificar_tabla bauth idn_audit_siem_target
echo ""
info "  D12 Blockchain:"
verificar_tabla bauth idn_blockchain_anchor_ext
verificar_tabla bauth idn_blockchain_wallet
echo ""
info "  D13 Firma Digital:"
verificar_tabla bauth idn_signature_request
verificar_tabla bauth idn_signature_ca_chain
verificar_tabla bauth idn_signature_ltv_evidence
echo ""
info "  D14 PAM:"
verificar_tabla bauth pam_session_recording
echo ""
info "  D15 NHI:"
verificar_tabla bauth idn_nhi_rotation_policy
verificar_tabla bauth idn_nhi_svid
echo ""
info "  D98 Meta-Registro:"
verificar_tabla bauth idn_registry_atom_catalog
verificar_tabla bauth idn_registry_attribute_schema
verificar_tabla bauth idn_registry_bitmask_version
echo ""
info "  BOS Context Plane:"
verificar_tabla bos   ctx_context_session
verificar_tabla bos   ctx_context_policy
verificar_tabla bos   fch_ficha_state
verificar_tabla bos   ins_bootstrap_event

# ── 6.3 Seeds críticos ───────────────────────────────────────────────────────
echo ""
info "  Seeds críticos (conteo de filas):"

seed_count() {
    local schema="$1" tabla="$2" etiqueta="$3"
    local n
    n=$($PSQL -t -c "SELECT COUNT(*) FROM $schema.$tabla;" 2>/dev/null | tr -d ' \n' || echo "ERROR")
    if [[ "$n" == "ERROR" || "$n" == "0" ]]; then
        echo -e "    ${YELLOW}⚠ $etiqueta: $n fila(s)${NC}"
    else
        echo -e "    ${GREEN}✓ $etiqueta: $n fila(s)${NC}"
    fi
}

seed_count bauth  idn_global_crypto_params  "T-513 algoritmos cripto"
seed_count bauth  idn_audit_siem_target     "T-423 destinos SIEM"
seed_count bauth  idn_audit_retention_policy "T-421 políticas retención"
seed_count bauth  idn_tenant                "T-005 tenants"
seed_count bauth  idn_identity_entity       "T-156 entidades identidad"
seed_count bauth  idn_roles_template        "T-162 plantillas roles"
seed_count bglobal global_country           "bglobal países ISO 3166"
seed_count bcalendar cal_calendar           "bcalendar calendarios"

# =============================================================================
# RESULTADO FINAL
# =============================================================================
echo ""
echo -e "${BOLD}============================================================${NC}"
if [[ "$TOTAL_ERRORES" -eq 0 && "$FALTANTES" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ INICIALIZACIÓN EXITOSA${NC}"
    echo -e "  BD: $DB_NAME | Tablas: $TOTAL_TABLAS (+particiones: $TOTAL_CON_PARTIC)"
elif [[ "$TOTAL_ERRORES" -gt 0 ]]; then
    echo -e "${RED}${BOLD}  ✗ INICIALIZACIÓN CON ERRORES: $TOTAL_ERRORES error(es) SQL${NC}"
else
    echo -e "${YELLOW}${BOLD}  ⚠ INICIALIZACIÓN INCOMPLETA: $FALTANTES tabla(s) faltante(s)${NC}"
fi
echo -e "${BOLD}============================================================${NC}"
echo ""

[[ "$TOTAL_ERRORES" -eq 0 && "$FALTANTES" -eq 0 ]] || exit 1
