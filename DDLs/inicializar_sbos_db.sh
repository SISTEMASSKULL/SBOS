#!/usr/bin/env bash
# =============================================================================
# inicializar_sbos_db.sh — Carga ordenada de la base de datos SBOS: DDLs → seeds.
#
# Dos fases separadas (best practice: migrations primero, seeds después):
#   FASE 1  ESQUEMA — las DDLs en orden de dependencia.
#   FASE 2  DATOS   — los seeds, cada uno en su ARCHIVO INDEPENDIENTE, en orden.
#
# Los seeds NO se fusionan ni se concatenan: se mantienen modulares (un archivo
# por seed) y este script los recorre en el orden definido en run_all_seeds.sql
# (única fuente del orden). Idempotente: DDLs con IF NOT EXISTS, seeds con
# ON CONFLICT; la fase de datos desactiva la validación de FK durante la carga
# para tolerar FK cruzadas sin reordenar.
#
# Uso:
#   SBOS_DSN="postgresql://user@host:5432/SBOS_db" ./inicializar_sbos_db.sh [--solo-ddl|--solo-seeds]
#
# Config (variables de entorno, sin rutas hardcodeadas — regla C3):
#   SBOS_DSN       cadena de conexión psql (obligatoria)
#   SBOS_LOAD_LOG  ruta del log (por defecto /tmp/sbos_load_<fecha>.log)
# =============================================================================
set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
DDL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSN="${SBOS_DSN:-}"
LOG="${SBOS_LOAD_LOG:-/tmp/sbos_load_$(date +%Y%m%d_%H%M%S).log}"
MODO="${1:-completo}"          # completo | --solo-ddl | --solo-seeds

# Orden de carga de las DDLs (fase 1) — de menor a mayor dependencia.
DDL_ORDEN=(
  "migrations/sbos_00__esquema_base.sql"                 # maestro: 6 schemas + núcleo
  "migrations/bos_01__control_plane.sql"                # BOS Control Plane
  "migrations/bauth_10__d00_identidad_organizacional.sql"  # Dominio D00
  "migrations/bauth_20__framework_politicas.sql"         # políticas y configs
  "migrations/bauth_30__compliance_qa.sql"             # compliance / QA
)

# Orden de carga de los catálogos de normas (fase 2 — antes escondido dentro de
# DDL_framework_unified.sql; extraído de ahí para que cada archivo sea autónomo).
CATALOGO_ORDEN=(
  "seeds/bauth_fw_01__authentication_framework.sql"
  "seeds/bauth_fw_02__policies_framework.sql"
  "seeds/bauth_fw_03__nist_rev4.sql"
  "seeds/bauth_fw_04__fido2_ctap.sql"
  "seeds/bauth_fw_05__nist_pqc.sql"
  "seeds/bauth_fw_06__oauth_21.sql"
  "seeds/bauth_fw_07__zero_trust.sql"
  "seeds/bauth_fw_08__iso_27001.sql"
  "seeds/bauth_fw_09__industry.sql"
  "seeds/bauth_fw_10__d3_financiero.sql"
  "seeds/bauth_fw_11__d4_temporal.sql"
  "seeds/bauth_fw_12__d6_geo.sql"
  "seeds/bauth_fw_13__d10_delegacion.sql"
  "seeds/bauth_fw_14__cis_k8s.sql"
  "seeds/bauth_fw_15__aws_iam.sql"
  "seeds/bauth_fw_16__soc2.sql"
)

# Orden de carga de los seeds (fase 3) — cada archivo INDEPENDIENTE, listado
# explícitamente aquí (antes escondido en run_all_seeds.sql). Se ve qué seed se
# carga y en qué orden. Los 5 seeds obsoletos (divergen del esquema, sin datos
# en la VPS) quedan fuera: seed_menu_item, seed_test_users, seed_auth_method_native,
# 064_idn_user_template_data, seed_idn_user_template_v6.
SEED_ORDEN=(
  "seeds/bglobal_01__global_country.sql"
  "seeds/bglobal_02__global_language.sql"
  "seeds/bglobal_03__geo_timezone.sql"
  "seeds/bauth_01__cfg_key_translation.sql"
  "seeds/bauth_02__privilege_domain.sql"
  "seeds/bauth_03__privilege_verb.sql"
  "seeds/bauth_04__privilege_application.sql"
  "seeds/bauth_05__privilege_group.sql"
  "seeds/bauth_06__privilege_atom.sql"
  "seeds/bauth_07__privilege_atom_policy.sql"
  "seeds/bauth_08__privilege_role.sql"
  "seeds/bauth_09__privilege_role_atom.sql"
  "seeds/bauth_10__idn_tenant.sql"
  "seeds/bauth_11__idn_tier_policy.sql"
  "seeds/bauth_12__log_zone.sql"
  "seeds/bauth_13__geo_trust_tier.sql"
  "seeds/bauth_14__ath_method.sql"
  "seeds/bauth_15__ath_federation_protocol.sql"
  "seeds/bauth_16__ath_config_d1.sql"
  "seeds/bauth_17__ath_config_d2.sql"
  "seeds/bauth_18__ath_config_d3.sql"
  "seeds/bauth_19__ath_config_d4.sql"
  "seeds/bauth_20__ath_config_d5.sql"
  "seeds/bauth_21__ath_config_d6.sql"
  "seeds/bauth_22__ath_config_d7.sql"
  "seeds/bauth_23__ath_config_d8.sql"
  "seeds/bauth_24__ath_config_d9.sql"
  "seeds/bauth_25__ath_config_d10.sql"
  "seeds/bauth_26__ath_config_d11.sql"
  "seeds/bauth_27__ath_config_d12.sql"
  "seeds/bauth_28__ath_policy_d1.sql"
  "seeds/bauth_29__ath_policy_d2.sql"
  "seeds/bauth_30__ath_policy_d3.sql"
  "seeds/bauth_31__ath_policy_d4.sql"
  "seeds/bauth_32__ath_policy_d5.sql"
  "seeds/bauth_33__ath_policy_d6.sql"
  "seeds/bauth_34__ath_policy_d7.sql"
  "seeds/bauth_35__ath_policy_d8.sql"
  "seeds/bauth_36__ath_policy_d9.sql"
  "seeds/bauth_37__ath_policy_d10.sql"
  "seeds/bauth_38__ath_policy_d11.sql"
  "seeds/bauth_39__ath_policy_d12.sql"
  "seeds/bauth_40__ath_auth_flow.sql"
  "seeds/bauth_41__ath_step_up_rule.sql"
  "seeds/bauth_42__validation_rules.sql"
  "seeds/bauth_43__framework_sync.sql"
  "seeds/bauth_44__fin_transaction_type.sql"
  "seeds/bauth_45__fin_sod_rule.sql"
  "seeds/bauth_46__fin_limit.sql"
  "seeds/bauth_47__fin_decision_matrix.sql"
  "seeds/bcalendar_01__cal_calendar.sql"
  "seeds/bcalendar_02__cal_schedule.sql"
  "seeds/bcalendar_03__cal_holiday_complete.sql"
  "seeds/bauth_48__idn_role_template.sql"
  "seeds/bauth_49__idn_role_template_data.sql"
  "seeds/bauth_50__idn_role_d1.sql"
  "seeds/bauth_51__idn_role_d2.sql"
  "seeds/bauth_52__idn_role_d3.sql"
  "seeds/bauth_53__idn_role_d4.sql"
  "seeds/bauth_54__idn_role_d5.sql"
  "seeds/bauth_55__idn_role_d6.sql"
  "seeds/bauth_56__idn_role_d7.sql"
  "seeds/bauth_57__idn_role_d8.sql"
  "seeds/bauth_58__idn_role_d9.sql"
  "seeds/bauth_59__idn_role_d10.sql"
  "seeds/bauth_60__idn_role_d11.sql"
  "seeds/bauth_61__idn_role_d12.sql"
  "seeds/bauth_62__idn_role_closure.sql"
  "seeds/bglobal_04__menu_context.sql"
  "seeds/bauth_63__org_empresa.sql"
  "seeds/bauth_64__org_sucursal.sql"
  "seeds/bauth_65__mobile_app_config.sql"
  "seeds/bauth_66__zone_application_map.sql"
  "seeds/bauth_67__ath_credential_policy.sql"
  "seeds/bauth_68__idn_user_template.sql"
  "seeds/bauth_69__aud_compliance_map.sql"
  "seeds/bauth_70__compliance_qa.sql"
)

OK=0; FALLO=0; FALLIDOS=()

# ── Utilidades ───────────────────────────────────────────────────────────────

# registra un mensaje en consola y en el log.
log() { echo "$*" | tee -a "$LOG" ; }

# verifica los prerrequisitos: DSN definido y conexión viva.
verificar_entorno() {
  if [[ -z "$DSN" ]]; then
    echo "ERROR: definir SBOS_DSN (cadena de conexión psql). No hay rutas ni credenciales hardcodeadas." >&2
    exit 2
  fi
  if ! psql "$DSN" -tAc "SELECT 1" >/dev/null 2>&1; then
    echo "ERROR: no se pudo conectar con SBOS_DSN." >&2
    exit 2
  fi
}

# ejecuta un archivo SQL y cuenta el resultado.
# Args: $1 = ruta relativa a DDL_DIR · $2 = etiqueta para el log.
ejecutar_sql() {
  local rel="$1" etiqueta="$2" ruta="$DDL_DIR/$1"
  if [[ ! -f "$ruta" ]]; then
    log "  ✗ $etiqueta — NO EXISTE: $rel"
    FALLO=$((FALLO+1)); FALLIDOS+=("$rel (no existe)"); return
  fi
  local errores
  errores=$(psql "$DSN" -v ON_ERROR_STOP=0 -f "$ruta" 2>&1 | tee -a "$LOG" | grep -ciE '^psql.*ERROR|^ERROR') || true
  if [[ "$errores" -eq 0 ]]; then
    log "  ✓ $etiqueta — $rel"
    OK=$((OK+1))
  else
    log "  ✗ $etiqueta — $rel ($errores errores, ver log)"
    FALLO=$((FALLO+1)); FALLIDOS+=("$rel ($errores errores)")
  fi
}

# ── Fase 1: ESQUEMA (DDLs) ───────────────────────────────────────────────────
cargar_ddls() {
  log ""
  log "── FASE 1: ESQUEMA (DDLs, en orden de dependencia) ──"
  local d
  for d in "${DDL_ORDEN[@]}"; do
    ejecutar_sql "$d" "DDL"
  done
}

# ── Fase 2: CATÁLOGOS de normas (inserts, cada archivo independiente) ───────
cargar_catalogos() {
  log ""
  log "── FASE 2: CATÁLOGOS de normas (inserts en orden) ──"
  local pgopts_previo="${PGOPTIONS:-}"
  export PGOPTIONS="-c session_replication_role=replica"
  local c
  for c in "${CATALOGO_ORDEN[@]}"; do
    ejecutar_sql "$c" "catálogo"
  done
  if [[ -n "$pgopts_previo" ]]; then export PGOPTIONS="$pgopts_previo"; else unset PGOPTIONS; fi
}

# extrae las tablas destino (INSERT INTO) de todos los seeds del orden.
# Devuelve nombres schema.tabla únicos, uno por línea.
tablas_de_seeds() {
  local s
  for s in "${SEED_ORDEN[@]}"; do
    [[ -f "$DDL_DIR/$s" ]] && grep -ioE 'INSERT[[:space:]]+INTO[[:space:]]+[a-z_][a-z0-9_.]*' "$DDL_DIR/$s"
  done | sed -E 's/INSERT[[:space:]]+INTO[[:space:]]+//I' | sort -u
}

# ── Fase 3: DATOS (seeds independientes, en orden; idempotente por refresh) ──
cargar_seeds() {
  log ""
  log "── FASE 3: SEEDS (archivos independientes, en orden de dependencia) ──"
  # Desactivar la validación de FK durante TODA la fase de datos. PGOPTIONS
  # aplica a CADA conexión psql (session_replication_role es por sesión).
  local pgopts_previo="${PGOPTIONS:-}"
  export PGOPTIONS="-c session_replication_role=replica"

  # IDEMPOTENCIA POR REFRESH: los seeds son datos de REFERENCIA (catálogos,
  # roles, políticas), no datos de usuario. Como muchos insertan con UUID
  # aleatorio sin ON CONFLICT, se truncan sus tablas antes de recargar: así
  # trunca+recarga produce SIEMPRE el mismo estado (carga idempotente).
  log "  Vaciando tablas de referencia antes de recargar (idempotencia)..."
  local tablas; tablas=$(tablas_de_seeds | tr '\n' ',' | sed 's/,$//')
  if [[ -n "$tablas" ]]; then
    psql "$DSN" -q -c "TRUNCATE TABLE $tablas RESTART IDENTITY CASCADE;" >>"$LOG" 2>&1 \
      || log "  (aviso: no se pudieron truncar todas; se continúa)"
  fi

  local s
  for s in "${SEED_ORDEN[@]}"; do
    ejecutar_sql "$s" "seed"
  done

  # Restaurar PGOPTIONS al estado previo.
  if [[ -n "$pgopts_previo" ]]; then export PGOPTIONS="$pgopts_previo"; else unset PGOPTIONS; fi
}

# ── Resumen ──────────────────────────────────────────────────────────────────
resumen() {
  log ""
  log "════════════════════════════════════════════════════════════════"
  log "  Carga terminada — OK: $OK · Con errores: $FALLO"
  log "  Log completo: $LOG"
  if [[ "$FALLO" -gt 0 ]]; then
    log "  Archivos con errores:"
    local f; for f in "${FALLIDOS[@]}"; do log "    - $f"; done
  fi
  log "════════════════════════════════════════════════════════════════"
  [[ "$FALLO" -eq 0 ]]
}

# ── Orquestación ─────────────────────────────────────────────────────────────
main() {
  verificar_entorno
  log "SBOS — carga de base de datos ($(date '+%Y-%m-%d %H:%M:%S'))"
  case "$MODO" in
    --solo-ddl)       cargar_ddls ;;
    --solo-catalogos) cargar_catalogos ;;
    --solo-seeds)     cargar_seeds ;;
    completo)         cargar_ddls; cargar_catalogos; cargar_seeds ;;
    *) echo "Uso: $0 [--solo-ddl|--solo-catalogos|--solo-seeds]" >&2; exit 2 ;;
  esac
  resumen
}

main "$@"
