-- ============================================================================
-- main.sql — Orquestador IDEMPOTENTE de la base de datos SBOS_db
-- Punto de entrada que bos ejecuta al instalar o actualizar la DDL.
-- Orden definido por la doctrina: DDLs/ddls.yml (única fuente de verdad).
--
-- Ejecutar:
--   psql "$SKDATA_DSN" -v ON_ERROR_STOP=1 -f DDLs/main.sql
--
-- Garantía: idempotente — re-ejecutar sobre una BD existente no rompe nada
-- (todas las DDLs usan CREATE ... IF NOT EXISTS; los seeds usan ON CONFLICT).
--
-- ESTADO: PROPUESTA — pendiente de aprobación y prueba del humano antes de
-- usar en instalación real. Los cambios de DDL requieren aprobación explícita.
-- ============================================================================

\set ON_ERROR_STOP on
\echo '════════════════════════════════════════════════════════════════'
\echo '  SBOS_db — carga idempotente (DDLs/ddls.yml)'
\echo '════════════════════════════════════════════════════════════════'

-- ── FASE 1 — DDL MAESTRO: crea los 6 schemas y el núcleo de tablas ─────────
\echo '── Fase 1: DDL maestro (schemas + núcleo) ──'
\ir migrations/DDL_skSBOS_db.sql

-- ── FASE 2 — DDLs COMPLEMENTARIOS: tablas por área (dependen del maestro) ──
\echo '── Fase 2: DDLs complementarios ──'
\ir migrations/DDL_bos_schema.sql
\ir migrations/003_d00_identidad_organizacional.sql
\ir migrations/DDL_framework_unified.sql
\ir migrations/DDL_compliance_qa.sql

-- ── FASE 3 — CATÁLOGOS DE NORMAS ───────────────────────────────────────────
-- PENDIENTE: el orden de carga de los catálogos (catalogs/insert_*.sql) requiere
-- decisión del humano (ver ddls.yml → fase_3_catalogos). No se cargan aún para
-- no inventar un orden no verificado. Cuando el humano lo defina, se agregan
-- aquí los \ir de catalogs/ en su orden correcto.
\echo '── Fase 3: catálogos de normas — PENDIENTE de orden (ver ddls.yml) ──'

-- ── FASE 4 — SEEDS: semillas de datos, ordenadas por dependencias ──────────
\echo '── Fase 4: seeds (71 semillas, orden por dependencias) ──'
\ir seeds/run_all_seeds.sql

\echo '════════════════════════════════════════════════════════════════'
\echo '  Carga completa. BD SBOS_db operativa.'
\echo '════════════════════════════════════════════════════════════════'
