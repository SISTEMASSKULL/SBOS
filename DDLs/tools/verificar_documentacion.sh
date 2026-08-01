#!/usr/bin/env bash
# =============================================================================
# verificar_documentacion.sh — Control de avance de documentación SBOS_db
#
# Evalúa el estado de COMMENT ON TABLE y COMMENT ON COLUMN de las 216 tablas
# padre de los schemas bauth/bglobal/bcalendar/bos contra el estándar de 6 elementos.
#
# Uso:
#   ./verificar_documentacion.sh [DB_NAME] [DB_HOST] [DB_PORT] [DB_USER]
#   PGPASSWORD=postgres ./verificar_documentacion.sh SBOSDB localhost 15432
#
# Salida: reporte tabular con estado, score y resumen ejecutivo de avance.
# Convención de estados:
#   DONE        — score ≥ 5/6 + verificado en BD
#   IN_PROGRESS — COMMENT ON TABLE presente pero score < 5/6
#   NOT_STARTED — sin COMMENT ON TABLE (NULL o vacío)
#   BLOCKED     — requiere decisión de dominio (marcado manualmente)
# =============================================================================

set -euo pipefail

DB_NAME="${1:-SBOSDB_copia}"
DB_HOST="${2:-localhost}"
DB_PORT="${3:-15432}"
DB_USER="${4:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -A"

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  REPORTE DE DOCUMENTACIÓN — SBOS_db${NC}"
echo -e "${BOLD}  Base: $DB_NAME @ $DB_HOST:$DB_PORT  |  $(ts)${NC}"
echo -e "${BOLD}================================================================${NC}"

# ── Verificar conexión ────────────────────────────────────────────────────────
$PSQL -c "SELECT 1" > /dev/null 2>&1 || {
    echo -e "${RED}ERROR: No se puede conectar a $DB_NAME${NC}"
    exit 1
}

# ── Query principal — score de documentación por tabla ────────────────────────
QUERY_SCORE="
SELECT
    n.nspname                                               AS schema,
    c.relname                                               AS tabla,
    CASE
        WHEN obj_description(c.oid,'pg_class') IS NULL THEN 0
        WHEN length(obj_description(c.oid,'pg_class')) < 30 THEN 0
        ELSE
            LEAST(6,
              (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
            + (obj_description(c.oid,'pg_class') ~* 'administra')::int
            + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
            + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
            + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
            + (length(obj_description(c.oid,'pg_class')) > 120)::int
            )
    END                                                     AS score,
    CASE
        WHEN obj_description(c.oid,'pg_class') IS NULL THEN 'NOT_STARTED'
        WHEN length(obj_description(c.oid,'pg_class')) < 30 THEN 'NOT_STARTED'
        WHEN (
              (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
            + (obj_description(c.oid,'pg_class') ~* 'administra')::int
            + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
            + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
            + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
            + (length(obj_description(c.oid,'pg_class')) > 120)::int
            ) >= 5 THEN 'DONE'
        ELSE 'IN_PROGRESS'
    END                                                     AS estado,
    (SELECT COUNT(*) FROM pg_attribute a2
     WHERE a2.attrelid = c.oid
       AND a2.attnum > 0
       AND NOT a2.attisdropped
       AND col_description(a2.attrelid, a2.attnum) IS NULL)  AS cols_sin_doc
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r'
  AND c.relispartition = false
ORDER BY
    CASE WHEN obj_description(c.oid,'pg_class') IS NULL THEN 0
         WHEN length(obj_description(c.oid,'pg_class')) < 30 THEN 0
         ELSE LEAST(6,
              (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
            + (obj_description(c.oid,'pg_class') ~* 'administra')::int
            + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
            + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
            + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
            + (length(obj_description(c.oid,'pg_class')) > 120)::int
            )
    END ASC,
    n.nspname, c.relname;
"

echo ""
echo -e "${BOLD}  Schema       Tabla                                Score  Cols  Estado${NC}"
echo -e "  -----------  -----------------------------------  -----  ----  ----------"

TOTAL=0; DONE=0; IN_PROG=0; NOT_START=0

while IFS='|' read -r schema tabla score estado cols_sin; do
    [[ -z "$schema" ]] && continue
    TOTAL=$((TOTAL+1))

    # Padding
    schema_pad=$(printf '%-12s' "$schema")
    tabla_pad=$(printf '%-35s' "$tabla")
    score_pad=$(printf '%5s' "$score/6")
    cols_pad=$(printf '%4s' "$cols_sin")

    case "$estado" in
        DONE)
            DONE=$((DONE+1))
            echo -e "  ${GREEN}${schema_pad}  ${tabla_pad}  ${score_pad}  ${cols_pad}  ✓ DONE${NC}"
            ;;
        IN_PROGRESS)
            IN_PROG=$((IN_PROG+1))
            echo -e "  ${YELLOW}${schema_pad}  ${tabla_pad}  ${score_pad}  ${cols_pad}  ◑ IN_PROGRESS${NC}"
            ;;
        NOT_STARTED)
            NOT_START=$((NOT_START+1))
            echo -e "  ${RED}${schema_pad}  ${tabla_pad}  ${score_pad}  ${cols_pad}  ✗ NOT_STARTED${NC}"
            ;;
        *)
            echo -e "  ${CYAN}${schema_pad}  ${tabla_pad}  ${score_pad}  ${cols_pad}  ? ${estado}${NC}"
            ;;
    esac
done < <($PSQL -c "$QUERY_SCORE" 2>/dev/null)

# ── Conteo por schema ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Tablas por schema:${NC}"
$PSQL -c "
SELECT '  ' || RPAD(n.nspname,12) || ' → ' ||
    COUNT(CASE WHEN (
              (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
            + (obj_description(c.oid,'pg_class') ~* 'administra')::int
            + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
            + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
            + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
            + (length(obj_description(c.oid,'pg_class')) > 120)::int
    ) >= 5 THEN 1 END)::TEXT || ' DONE / ' || COUNT(*)::TEXT || ' tablas'
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r' AND c.relispartition = false
GROUP BY n.nspname ORDER BY n.nspname;
" 2>/dev/null

# ── Resumen ejecutivo ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  RESUMEN EJECUTIVO${NC}"
echo -e "${BOLD}================================================================${NC}"

if [[ $TOTAL -gt 0 ]]; then
    PCT_DONE=$(( (DONE * 100) / TOTAL ))
    PCT_PROG=$(( (IN_PROG * 100) / TOTAL ))
    PCT_NOT=$(( (NOT_START * 100) / TOTAL ))

    echo -e "  ${GREEN}DONE        : $DONE / $TOTAL  ($PCT_DONE %)${NC}"
    echo -e "  ${YELLOW}IN_PROGRESS : $IN_PROG / $TOTAL  ($PCT_PROG %)${NC}"
    echo -e "  ${RED}NOT_STARTED : $NOT_START / $TOTAL  ($PCT_NOT %)${NC}"
    echo ""
    echo -e "  ${BOLD}COBERTURA OBJETIVO: 100 % DONE${NC}"

    if [[ $NOT_START -eq 0 && $IN_PROG -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✓ OBJETIVO ALCANZADO — Documentación completa${NC}"
    else
        BRECHA=$((TOTAL - DONE))
        echo -e "  ${YELLOW}BRECHA ACTUAL: $BRECHA tablas pendientes${NC}"
    fi
fi

echo -e "${BOLD}================================================================${NC}"
echo ""
