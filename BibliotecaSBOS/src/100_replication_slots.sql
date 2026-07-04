-- 100_replication_slots.sql — WAL replication slots for SBOS daemons
-- Required: wal_level = logical, max_replication_slots >= 20
-- Version: 1.0.0 — 2026-05-12

-- ============================================================================
-- bKernel slot — listens to ALL stack apps (tryton, orangehrm, saleor, espocrm, ...)
-- ============================================================================
SELECT pg_create_logical_replication_slot('bkernel_slot', 'pgoutput')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'bkernel_slot'
);

-- ============================================================================
-- biedata slot — listens to integration tables (invoices, vouchers from tryton_db)
-- ============================================================================
SELECT pg_create_logical_replication_slot('biedata_slot', 'pgoutput')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'biedata_slot'
);

-- ============================================================================
-- bcompass slot — listens to analytical tables (sales, inventory, accounting)
-- ============================================================================
SELECT pg_create_logical_replication_slot('bcompass_slot', 'pgoutput')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'bcompass_slot'
);

-- ============================================================================
-- Verification
-- ============================================================================
SELECT slot_name, database, plugin, slot_type, active, restart_lsn
FROM pg_replication_slots
WHERE slot_name IN ('bkernel_slot', 'biedata_slot', 'bcompass_slot')
ORDER BY slot_name;
