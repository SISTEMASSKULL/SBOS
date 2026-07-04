-- 005_bos_db.sql — bos IAM Installer operational database
-- Owner: bos (Go daemon)
-- Purpose: ficha operation log, periodic health snapshots
-- ISO 27001: A.8.16 (monitoring), A.5.15 (access control)
-- Version: 1.0.0 — 2026-05-12

CREATE SCHEMA IF NOT EXISTS bos;
SET search_path TO bos;

-- ============================================================================
-- 1. bos_operation_log — ficha operations by phase and status
-- ============================================================================
CREATE TABLE bos_operation_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation_id        UUID DEFAULT uuid_generate_v4() NOT NULL,
    operation_type      VARCHAR(20) NOT NULL
        CHECK (operation_type IN ('install', 'update', 'repair', 'uninstall',
               'drain_node', 'delete_namespace', 'rotate_secrets',
               'bootstrap', 'health_check')),
    ficha_name          VARCHAR(100),
    product_name        VARCHAR(100),
    server_logico       VARCHAR(10),
    category            SMALLINT NOT NULL DEFAULT 1
        CHECK (category BETWEEN 1 AND 3),
    criticality         BOOLEAN DEFAULT false,
    phase               VARCHAR(30) NOT NULL
        CHECK (phase IN ('validate', 'pre_install', 'install', 'configure',
               'verify', 'rollback')),
    status              VARCHAR(20) DEFAULT 'started'
        CHECK (status IN ('started', 'running', 'completed', 'failed',
               'rolled_back', 'aborted', 'requires_approval')),
    duration_ms         INT,
    error_message       TEXT,
    dry_run             BOOLEAN DEFAULT false,
    operator            VARCHAR(100) NOT NULL,
    approval_count      SMALLINT DEFAULT 0,
    approval_required    SMALLINT DEFAULT 1,
    rollback_success    BOOLEAN,
    manifest_hash       VARCHAR(64),
    artifact_signature  VARCHAR(128),
    log_file_path       TEXT,
    started_at          TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at        TIMESTAMPTZ
);

COMMENT ON TABLE bos_operation_log IS 'Complete ficha operation history with phase tracking';
COMMENT ON COLUMN bos_operation_log.category IS 'Governance category: 1=low, 2=medium, 3=high impact';
COMMENT ON COLUMN bos_operation_log.artifact_signature IS 'Ed25519 signature of deployed artifact';

CREATE INDEX idx_bos_op_ficha ON bos_operation_log (ficha_name, started_at DESC);
CREATE INDEX idx_bos_op_type ON bos_operation_log (operation_type, status);
CREATE INDEX idx_bos_op_operator ON bos_operation_log (operator, started_at DESC);
CREATE INDEX idx_bos_op_status ON bos_operation_log (status, started_at);
CREATE INDEX idx_bos_op_category ON bos_operation_log (category, status);
CREATE UNIQUE INDEX idx_bos_op_unique ON bos_operation_log (operation_id);

-- ============================================================================
-- 2. bos_health_snapshot — periodic system health snapshots
-- ============================================================================
CREATE TABLE bos_health_snapshot (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fichas_total        INT NOT NULL DEFAULT 0,
    fichas_healthy      INT NOT NULL DEFAULT 0,
    fichas_degraded     INT DEFAULT 0,
    fichas_failed       INT DEFAULT 0,
    fichas_maintenance  INT DEFAULT 0,
    k8s_nodes           INT DEFAULT 0,
    k8s_nodes_ready     INT DEFAULT 0,
    k8s_pods_total      INT DEFAULT 0,
    k8s_pods_running    INT DEFAULT 0,
    k8s_pods_pending    INT DEFAULT 0,
    pg_connections      INT DEFAULT 0,
    pg_active_queries   INT DEFAULT 0,
    pg_replication_lag_bytes BIGINT DEFAULT 0,
    pg_wal_slots_active INT DEFAULT 0,
    redis_memory_mb     INT DEFAULT 0,
    system_load_1m      REAL,
    system_load_5m      REAL,
    system_mem_free_mb  INT,
    system_disk_used_pct REAL,
    tls_days_to_expiry  SMALLINT,
    overall_status      VARCHAR(10) DEFAULT 'healthy'
        CHECK (overall_status IN ('healthy', 'degraded', 'warning', 'critical')),
    alerts_active       INT DEFAULT 0,
    snapshot_at         TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE bos_health_snapshot IS 'Periodic system health snapshot — taken every 30s by health_checker';
COMMENT ON COLUMN bos_health_snapshot.overall_status IS 'Aggregated health: healthy > degraded > warning > critical';

CREATE INDEX idx_health_snapshot_at ON bos_health_snapshot (snapshot_at DESC);
CREATE INDEX idx_health_status ON bos_health_snapshot (overall_status, snapshot_at DESC);
