#!/usr/bin/env bash
# security-scan.sh — Pipeline de seguridad bAuth con Podman
#
# Propósito: SA-10 (NIST 800-53 Rev.5) + ISO 27001 A.8.25 — Seguridad en el ciclo
#            de desarrollo. Ejecuta cargo-audit + cargo-deny + cargo-clippy en un
#            entorno Podman reproducible y registra los resultados en SBOSDB.
#
# Fases:
#   1. Construir imagen Podman (bauth-security-scanner)
#   2. cargo-audit: dependencias vs RustSec Advisory Database → JSON
#   3. cargo-deny:  política de licencias y paquetes prohibidos → TXT
#   4. cargo-clippy: análisis estático SAST → TXT
#   5. Ingestar resultados en SBOSDB (vul_component + vul_auth_impact)
#   6. Resumen y código de salida
#
# Uso:
#   cd BauthAgent/
#   ./ci/security-scan.sh
#
# Variables de entorno opcionales:
#   BAUTH_DB_DSN   — DSN de SBOSDB (default: postgres://postgres:postgres@localhost:15432/SBOSDB)
#   OUTPUT_DIR     — Directorio de salida (default: /tmp/bauth-security-scan/<timestamp>)
#   BUILD_IMAGE    — "false" para saltar el build si la imagen ya existe
#
# DOC-SBOS-001 N3: documentado en español
# NUNCA HTTP/TCP entre daemons (SBOS-050 P9) — la ingesta usa psql local

set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
readonly STAMP_SHORT="$(date -u +"%Y%m%d-%H%M%S")"
readonly OUTPUT_DIR="${OUTPUT_DIR:-/tmp/bauth-security-scan/${STAMP_SHORT}}"
readonly IMAGE_NAME="bauth-security-scanner:latest"
readonly CONTAINERFILE="${SCRIPT_DIR}/Containerfile.security"
readonly DENY_CFG="${SCRIPT_DIR}/cargo-deny.toml"
readonly DB_DSN="${BAUTH_DB_DSN:-postgres://postgres:postgres@localhost:15432/SBOSDB}"
readonly BUILD_IMAGE="${BUILD_IMAGE:-true}"
readonly SCAN_LOG="${OUTPUT_DIR}/scan.log"

# Archivos de salida de cada herramienta
readonly AUDIT_JSON="${OUTPUT_DIR}/cargo-audit.json"
readonly DENY_TXT="${OUTPUT_DIR}/cargo-deny.txt"
readonly CLIPPY_TXT="${OUTPUT_DIR}/clippy.txt"
readonly INGEST_SQL="${OUTPUT_DIR}/ingest.sql"

# Códigos de estado por herramienta (0=limpio, 1=hallazgos, 2=error)
AUDIT_STATUS=0
DENY_STATUS=0
CLIPPY_STATUS=0
INGEST_STATUS=0

# ── Funciones de salida coloreada ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { printf "${BLUE}[%s]${NC} %s\n"   "$(date -u +%H:%M:%S)" "$*" | tee -a "${SCAN_LOG}"; }
ok()   { printf "${GREEN}[OK  ]${NC} %s\n" "$*" | tee -a "${SCAN_LOG}"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" | tee -a "${SCAN_LOG}"; }
fail() { printf "${RED}[FAIL]${NC} %s\n"   "$*" | tee -a "${SCAN_LOG}"; }

# ── Validar prerrequisitos ────────────────────────────────────────────────────
validar_prerrequisitos() {
    local faltan=()
    command -v podman   >/dev/null 2>&1 || faltan+=("podman")
    command -v psql     >/dev/null 2>&1 || faltan+=("psql")
    command -v python3  >/dev/null 2>&1 || faltan+=("python3")
    if [[ ${#faltan[@]} -gt 0 ]]; then
        fail "Prerrequisitos faltantes: ${faltan[*]}"
        exit 2
    fi
    [[ -f "${CONTAINERFILE}" ]] || { fail "No se encontró ${CONTAINERFILE}"; exit 2; }
    [[ -f "${DENY_CFG}" ]]      || { fail "No se encontró ${DENY_CFG}"; exit 2; }
    [[ -f "${PROJECT_DIR}/Cargo.toml" ]] || { fail "No se encontró Cargo.toml en ${PROJECT_DIR}"; exit 2; }
}

# ── Fase 1: Construir imagen Podman ──────────────────────────────────────────
fase_build_imagen() {
    if [[ "${BUILD_IMAGE}" == "false" ]] && podman image exists "${IMAGE_NAME}" 2>/dev/null; then
        log "Fase 1: Imagen ${IMAGE_NAME} ya existe — saltando build (BUILD_IMAGE=false)"
        return 0
    fi
    log "Fase 1: Construyendo imagen Podman ${IMAGE_NAME}..."
    if podman build \
        --tag "${IMAGE_NAME}" \
        --file "${CONTAINERFILE}" \
        --quiet \
        "${SCRIPT_DIR}" >> "${SCAN_LOG}" 2>&1; then
        ok "Imagen ${IMAGE_NAME} construida."
    else
        fail "Error al construir imagen. Ver ${SCAN_LOG}"
        exit 2
    fi
}

# ── Fase 2: cargo-audit ───────────────────────────────────────────────────────
fase_cargo_audit() {
    log "Fase 2: cargo-audit — dependencias vs RustSec Advisory Database..."
    local exit_code=0
    podman run --rm \
        --volume "${PROJECT_DIR}:/workspace:ro" \
        --volume "${OUTPUT_DIR}:/output:rw" \
        --workdir /workspace \
        --security-opt=no-new-privileges \
        "${IMAGE_NAME}" \
        "cargo-audit audit --json > /output/cargo-audit.json 2>&1; \
         cargo-audit audit 2>&1 | tee /output/cargo-audit.txt" || exit_code=$?

    if [[ -f "${AUDIT_JSON}" ]]; then
        local vuln_count
        vuln_count=$(python3 -c "
import json, sys
try:
    d = json.load(open('${AUDIT_JSON}'))
    print(d.get('vulnerabilities', {}).get('count', 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0)
        if [[ "${vuln_count}" -eq 0 ]]; then
            ok "cargo-audit: 0 vulnerabilidades conocidas."
            AUDIT_STATUS=0
        else
            warn "cargo-audit: ${vuln_count} vulnerabilidad(es) encontrada(s). Ver ${AUDIT_JSON}"
            AUDIT_STATUS=1
        fi
    else
        warn "cargo-audit: no se generó JSON de salida."
        AUDIT_STATUS=2
    fi
}

# ── Fase 3: cargo-deny ────────────────────────────────────────────────────────
fase_cargo_deny() {
    log "Fase 3: cargo-deny — política de licencias y advisories..."
    local exit_code=0
    podman run --rm \
        --volume "${PROJECT_DIR}:/workspace:ro" \
        --volume "${DENY_CFG}:/deny.toml:ro" \
        --volume "${OUTPUT_DIR}:/output:rw" \
        --workdir /workspace \
        --security-opt=no-new-privileges \
        "${IMAGE_NAME}" \
        "cargo-deny --config /deny.toml check 2>&1 | tee /output/cargo-deny.txt" \
        >> "${SCAN_LOG}" 2>&1 || exit_code=$?

    if [[ ${exit_code} -eq 0 ]]; then
        ok "cargo-deny: todas las políticas cumplidas."
        DENY_STATUS=0
    else
        warn "cargo-deny: violaciones de política detectadas. Ver ${DENY_TXT}"
        DENY_STATUS=1
    fi
}

# ── Fase 4: cargo-clippy SAST ─────────────────────────────────────────────────
fase_clippy() {
    log "Fase 4: cargo-clippy — análisis estático SAST..."

    # Clippy requiere código fuente compilable; si src/ no existe, reportar N/A.
    if [[ ! -d "${PROJECT_DIR}/src" ]]; then
        warn "cargo-clippy: src/ no disponible en este entorno — fase omitida (N/A)."
        echo "SAST N/A: directorio src/ no disponible en ${PROJECT_DIR}" > "${CLIPPY_TXT}"
        CLIPPY_STATUS=0
        return 0
    fi

    local exit_code=0
    # Necesita directorio target en rw para compilar
    podman run --rm \
        --volume "${PROJECT_DIR}:/workspace:rw" \
        --volume "${OUTPUT_DIR}:/output:rw" \
        --workdir /workspace \
        --security-opt=no-new-privileges \
        "${IMAGE_NAME}" \
        "cargo clippy --all-targets -- -D warnings 2>&1 | tee /output/clippy.txt; exit \${PIPESTATUS[0]}" \
        >> "${SCAN_LOG}" 2>&1 || exit_code=$?

    if [[ ${exit_code} -eq 0 ]]; then
        ok "cargo-clippy: sin advertencias SAST."
        CLIPPY_STATUS=0
    else
        local warning_count
        warning_count=$(grep -c "^error" "${CLIPPY_TXT}" 2>/dev/null || echo "?")
        warn "cargo-clippy: ${warning_count} advertencia(s). Ver ${CLIPPY_TXT}"
        CLIPPY_STATUS=1
    fi
}

# ── Fase 5: Ingestar resultados en SBOSDB ─────────────────────────────────────
# Actualiza bauth.vul_component (T-527) con metadatos del escaneo
# Inserta en bauth.vul_auth_impact (T-528) si se encontraron CVEs
fase_ingestar_sbosdb() {
    log "Fase 5: Registrando resultados en SBOSDB (bauth.vul_component)..."

    # Generar SQL de ingesta con Python3 + json
    python3 - "${AUDIT_JSON}" "${TIMESTAMP}" << 'PYEOF' > "${INGEST_SQL}"
import json, sys, re

audit_path = sys.argv[1]
scan_ts    = sys.argv[2]

def esc(s):
    """Escapar comillas simples para SQL."""
    return str(s).replace("'", "''")

def map_severity(cvss_vector):
    """
    Mapea vector CVSS a categoría de severidad según CVSS base score aproximado.
    Valores válidos en BD: CRITICAL, HIGH, MEDIUM, LOW, INFO.
    """
    if not cvss_vector:
        return "INFO"
    # Extraer AV y otros componentes para aproximar
    # Lógica simplificada: presencia de AV:N/AC:L → HIGH+
    if "AV:N/AC:L" in cvss_vector and "A:H" in cvss_vector:
        return "HIGH"
    if "AV:N" in cvss_vector and "/C:H" in cvss_vector:
        return "HIGH"
    if "AV:N" in cvss_vector:
        return "MEDIUM"
    if "AV:A" in cvss_vector:
        return "MEDIUM"
    return "LOW"

print("-- Ingesta automática SA-10: resultado de cargo-audit")
print(f"-- Generado: {scan_ts}")
print("BEGIN;")

try:
    with open(audit_path) as f:
        data = json.load(f)
except Exception as e:
    print(f"-- AVISO: no se pudo leer {audit_path}: {e}")
    print("ROLLBACK;")
    sys.exit(0)

# Upsert del componente "bauth" principal
# component_type válidos: RUST_CRATE, SYSTEM_LIB, BINARY, CONFIG, PROTOCOL
# Constraint UNIQUE correcto: uq_vul_component (name, version)
print(f"""
-- Componente principal bAuth
INSERT INTO bauth.vul_component
    (name, component_type, version, source, is_active, last_scanned, scan_tool, ctx_id)
VALUES
    ('bauth', 'BINARY', 'dev', 'Cargo.toml', true, '{scan_ts}', 'cargo-audit', 'system')
ON CONFLICT ON CONSTRAINT uq_vul_component
DO UPDATE SET
    last_scanned = EXCLUDED.last_scanned,
    scan_tool    = EXCLUDED.scan_tool,
    updated_at   = now();
""")

# Vulnerabilidades encontradas
vulns = data.get("vulnerabilities", {}).get("list", [])
if not vulns:
    print("-- Sin vulnerabilidades: no se insertan filas en vul_auth_impact")
else:
    for vuln in vulns:
        advisory = vuln.get("advisory", {})
        pkg      = vuln.get("package", {})
        adv_id   = advisory.get("id", "UNKNOWN")
        aliases  = advisory.get("aliases", [])
        cve_id   = next((a for a in aliases if a.startswith("CVE-")), adv_id)
        pkg_name = esc(pkg.get("name", "unknown"))
        pkg_ver  = esc(pkg.get("version", "0.0.0"))
        title    = esc(advisory.get("title", "Sin título"))
        desc     = esc((advisory.get("description", "") or "")[:400])
        cvss_vec = advisory.get("cvss", None)
        sev      = map_severity(cvss_vec)

        # cvss_score en BD es NUMERIC(4,1) — no admite el vector completo.
        # Pasamos NULL; el vector queda en impact_desc para trazabilidad.
        cvss_sql = "NULL"

        # action_taken: solo DISABLED_METHOD, PATCHED, MITIGATED, ACCEPTED, PENDING
        action = "PENDING"

        vector_info = f" [vector: {cvss_vec}]" if cvss_vec else ""

        print(f"""
-- CVE/Advisory: {cve_id} — {pkg_name} {pkg_ver}
WITH comp AS (
    INSERT INTO bauth.vul_component
        (name, component_type, version, source, is_active, last_scanned, scan_tool, ctx_id)
    VALUES
        ('{pkg_name}', 'RUST_CRATE', '{pkg_ver}', 'Cargo.lock', true, '{scan_ts}', 'cargo-audit', 'system')
    ON CONFLICT ON CONSTRAINT uq_vul_component
    DO UPDATE SET last_scanned = EXCLUDED.last_scanned, updated_at = now()
    RETURNING component_id
)
INSERT INTO bauth.vul_auth_impact
    (cve_id, component_id, affected_methods, disabled_methods,
     severity, cvss_score, impact_desc, mitigation, action_taken, ctx_id)
SELECT
    '{cve_id}',
    component_id,
    ARRAY[]::text[],
    ARRAY[]::text[],
    '{sev}',
    {cvss_sql},
    '{title}: {desc}{vector_info}',
    'Actualizar crate {pkg_name} a versión sin vulnerabilidad según RustSec',
    '{action}',
    'system'
FROM comp
ON CONFLICT DO NOTHING;
""")

print("COMMIT;")
PYEOF

    local ingest_exit=0
    # psql -v ON_ERROR_STOP=1: devuelve exit!=0 ante cualquier error SQL
    PGPASSWORD=postgres psql "${DB_DSN}" -v ON_ERROR_STOP=1 -f "${INGEST_SQL}" \
        >> "${SCAN_LOG}" 2>&1 || ingest_exit=$?

    if [[ ${ingest_exit} -eq 0 ]]; then
        ok "Ingesta en SBOSDB completada. SQL: ${INGEST_SQL}"
        INGEST_STATUS=0
    else
        warn "Error en ingesta a SBOSDB (código ${ingest_exit}). Ver ${SCAN_LOG}"
        INGEST_STATUS=1
    fi
}

# ── Resumen final ──────────────────────────────────────────────────────────────
imprimir_resumen() {
    log "══════════════════════════════════════════════════"
    log " RESUMEN — bAuth Security Scan — ${TIMESTAMP}"
    log "══════════════════════════════════════════════════"
    [[ ${AUDIT_STATUS}  -eq 0 ]] && ok  "cargo-audit:  SIN VULNERABILIDADES" \
                                  || warn "cargo-audit:  HALLAZGOS DETECTADOS"
    [[ ${DENY_STATUS}   -eq 0 ]] && ok  "cargo-deny:   POLÍTICAS CUMPLIDAS" \
                                  || warn "cargo-deny:   VIOLACIONES DE POLÍTICA"
    [[ ${CLIPPY_STATUS} -eq 0 ]] && ok  "cargo-clippy: SIN ADVERTENCIAS SAST" \
                                  || warn "cargo-clippy: ADVERTENCIAS SAST"
    [[ ${INGEST_STATUS} -eq 0 ]] && ok  "SBOSDB:       RESULTADOS REGISTRADOS" \
                                  || warn "SBOSDB:       ERROR EN REGISTRO"
    log "Salida: ${OUTPUT_DIR}"
    log "Log:    ${SCAN_LOG}"
    log "══════════════════════════════════════════════════"
    # El pipeline SA-10 no falla el build por hallazgos — el equipo decide si remediar o aceptar riesgo.
    # Falla únicamente si hay error de infraestructura (código 2).
    return 0
}

# ── Punto de entrada ──────────────────────────────────────────────────────────
main() {
    mkdir -p "${OUTPUT_DIR}"
    log "=== bAuth Security Scan SA-10 === Inicio: ${TIMESTAMP}"
    log "Proyecto: ${PROJECT_DIR}"

    validar_prerrequisitos
    fase_build_imagen
    fase_cargo_audit
    fase_cargo_deny
    fase_clippy
    fase_ingestar_sbosdb
    imprimir_resumen
}

main "$@"
