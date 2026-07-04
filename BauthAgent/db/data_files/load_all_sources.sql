-- ================================================================
-- load_all_sources.sql — Wrapper idempotente
-- Ejecutar: psql -d bauth_test -f load_all_sources.sql
-- NOTA: Los JSON limpios deben estar en /tmp/ del pod PostgreSQL:
--   kubectl cp Authentication_Framework_clean.json sbos-data/postgresql-0:/tmp/
--   kubectl cp Policies_Authentication_Framework_clean.json sbos-data/postgresql-0:/tmp/
-- ================================================================
\ir ../migrations/DDL_framework_unified.sql
