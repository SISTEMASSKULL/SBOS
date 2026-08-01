#!/usr/bin/env bash
# =============================================================================
# generar_catalog.sh — Genera DDLs/catalog_sbos.yml desde pg_description
#
# Lee los COMMENT ON TABLE de los 4 schemas de SBOS_db en PostgreSQL y
# genera un archivo YAML indexado por área funcional, consumible por agentes IA.
# NO se edita a mano — siempre se regenera con este script.
#
# Uso:
#   ./generar_catalog.sh [DB_NAME] [DB_HOST] [DB_PORT] [DB_USER]
#   PGPASSWORD=postgres ./generar_catalog.sh SBOSDB localhost 15432
#
# Salida: DDLs/catalog_sbos.yml
# =============================================================================

set -euo pipefail

DB_NAME="${1:-SBOSDB_copia}"
DB_HOST="${2:-localhost}"
DB_PORT="${3:-15432}"
DB_USER="${4:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -A"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$DIR/catalog_sbos.yml"

echo "Generando $SALIDA desde $DB_NAME..."

$PSQL -c "SELECT 1" > /dev/null 2>&1 || {
    echo "ERROR: No se puede conectar a $DB_NAME"; exit 1
}

# Totales
TOTAL=$($PSQL -c "
SELECT COUNT(*) FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r' AND c.relispartition = false;
" 2>/dev/null | tr -d ' \n')

DONE=$($PSQL -c "
SELECT COUNT(*) FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r' AND c.relispartition = false
  AND (
      (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
    + (obj_description(c.oid,'pg_class') ~* 'administra')::int
    + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
    + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
    + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
    + (length(obj_description(c.oid,'pg_class')) > 120)::int
  ) >= 5;
" 2>/dev/null | tr -d ' \n')

PCT=$(( (DONE * 100) / TOTAL ))

cat > "$SALIDA" <<YAML_HEADER
# =============================================================================
# catalog_sbos.yml — Catálogo de tablas SBOS_db por área funcional
# GENERADO AUTOMÁTICAMENTE — no editar a mano
# Comando: ./DDLs/tools/generar_catalog.sh ${DB_NAME}
# =============================================================================
generado_en: "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fuente: "pg_description de ${DB_NAME} @ ${DB_HOST}:${DB_PORT}"
total_tablas_padre: ${TOTAL}
tablas_documentadas: ${DONE}
cobertura_score_alto: "${PCT}%"

# Cómo usar este catálogo:
#   1. Busca el área funcional del subdominio que te interesa
#   2. Lee el campo 'resumen' para entender el propósito de la tabla
#   3. El campo 'fqn' (schema.tabla) es el nombre completo en SQL
#   4. El campo 't_code' es el código de trazabilidad (T-NNN) del DDL Manual
#
# Para documentación detallada: ejecuta en BD:
#   SELECT obj_description('schema.tabla'::regclass, 'pg_class');
#   SELECT col_description('schema.tabla'::regclass, attnum) FROM pg_attribute...

YAML_HEADER

# ── Extraer datos por schema y tabla ─────────────────────────────────────────
$PSQL -c "
SELECT
    n.nspname                                               AS schema,
    c.relname                                               AS tabla,
    COALESCE(
        LEFT(obj_description(c.oid,'pg_class'), 200),
        '(sin documentación)'
    )                                                       AS comentario,
    CASE
        WHEN (
              (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
            + (obj_description(c.oid,'pg_class') ~* 'administra')::int
            + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
            + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
            + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
            + (length(obj_description(c.oid,'pg_class')) > 120)::int
        ) >= 5 THEN 'DONE'
        WHEN obj_description(c.oid,'pg_class') IS NULL THEN 'NOT_STARTED'
        WHEN length(obj_description(c.oid,'pg_class')) < 30 THEN 'NOT_STARTED'
        ELSE 'IN_PROGRESS'
    END                                                     AS estado,
    LEAST(6,
        (obj_description(c.oid,'pg_class') ~* 'fuente:|fuente ')::int
      + (obj_description(c.oid,'pg_class') ~* 'administra')::int
      + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
      + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR|SOX|FIPS|FAPI|SPIFFE|eIDAS|NIC|SIN|Ley 164|OWASP|IEC')::int
      + (obj_description(c.oid,'pg_class') ~* 'WORM|particionada|particionad')::int
      + (length(obj_description(c.oid,'pg_class')) > 120)::int
    )                                                       AS score,
    c.relispartition                                        AS es_particion
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r'
ORDER BY n.nspname, c.relname;
" 2>/dev/null | while IFS='|' read -r schema tabla comentario estado score es_particion; do
    [[ -z "$schema" ]] && continue
    # Escapar comillas en el comentario para YAML
    comentario_esc="${comentario//\"/\'}"
    comentario_short=$(echo "$comentario_esc" | head -c 180 | tr '\n' ' ')

    echo "  - schema: ${schema}"
    echo "    tabla: ${tabla}"
    echo "    fqn: ${schema}.${tabla}"
    echo "    estado: ${estado}"
    echo "    score: ${score}/6"
    echo "    es_particion: ${es_particion}"
    echo "    resumen: \"${comentario_short}\""
    echo ""
done >> "$SALIDA"

echo "✓ Generado: $SALIDA (${TOTAL} tablas, ${DONE} DONE — ${PCT}%)"
