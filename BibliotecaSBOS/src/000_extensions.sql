-- 000_extensions.sql — PostgreSQL extensions for SBOS daemon databases
-- Required by: bkernel_db, biedata_db, bauth_db, bcompass_db, bos_db
-- Version: 1.0.0 — 2026-05-12

CREATE EXTENSION IF NOT EXISTS pg_replication_origin;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
