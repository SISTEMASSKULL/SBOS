#!/usr/bin/env bash
# deploy_all.sh — Biblioteca-SBOS DDL deployment
# Applies all daemon database schemas in dependency order
# Version: 1.0.0 — 2026-05-12
# Required: PGHOST, PGPORT, PGUSER set via environment or .pgpass

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PGOPTIONS="--search_path=public"

echo "=== Biblioteca-SBOS: Deploying SBOS daemon databases ==="
echo "Timestamp: $(date -Iseconds)"

# 1. Extensions (must be superuser)
echo ""
echo "[1/7] Installing PostgreSQL extensions..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/000_extensions.sql"
echo "  Extensions: OK"

# 2. bkernel_db — 8 tables
echo ""
echo "[2/7] Creating bkernel_db (8 tables)..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/001_bkernel_db.sql"
echo "  bkernel_db: schema + 8 tables + indexes + constraints — OK"

# 3. biedata_db — 3 tables
echo ""
echo "[3/7] Creating biedata_db (3 tables)..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/002_biedata_db.sql"
echo "  biedata_db: schema + 3 tables + indexes + constraints — OK"

# 4. bauth_db — 4 tables
echo ""
echo "[4/7] Creating bauth_db (4 tables)..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/003_bauth_db.sql"
echo "  bauth_db: schema + 4 tables + indexes + constraints — OK"

# 5. bcompass_db — 3 tables
echo ""
echo "[5/7] Creating bcompass_db (3 tables)..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/004_bcompass_db.sql"
echo "  bcompass_db: schema + 3 tables + indexes + constraints — OK"

# 6. bos_db — 2 tables
echo ""
echo "[6/7] Creating bos_db (2 tables)..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/005_bos_db.sql"
echo "  bos_db: schema + 2 tables + indexes + constraints — OK"

# 7. Replication slots
echo ""
echo "[7/7] Creating WAL replication slots..."
psql -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/100_replication_slots.sql"
echo "  Replication slots: OK"

echo ""
echo "=== Deploy complete: 5 databases, 20 tables ==="
echo ""

# Verification
echo "--- Schema summary ---"
psql -qtA -c "
SELECT schemaname, count(*) AS tables
FROM pg_tables
WHERE schemaname IN ('bkernel', 'biedata', 'bauth', 'bcompass', 'bos')
GROUP BY schemaname
ORDER BY schemaname;
"

echo ""
echo "--- Replication slots ---"
psql -qtA -c "
SELECT slot_name, database, active
FROM pg_replication_slots
WHERE slot_name IN ('bkernel_slot', 'biedata_slot', 'bcompass_slot')
ORDER BY slot_name;
"
