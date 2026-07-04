-- 001_bkernel_db.sql — bKernel Data Kernel operational database
-- Owner: bkernel (Rust daemon)
-- Purpose: operational state only — never stores business data (D7 frontier)
-- ISO 27001: A.8.15 (logging), A.8.16 (monitoring)
-- Version: 1.0.0 — 2026-05-12

-- ============================================================================
-- Schema creation
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS bkernel;
SET search_path TO bkernel;

-- ============================================================================
-- 1. replication_state — WAL slot state and LSN tracking
-- ============================================================================
CREATE TABLE replication_state (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slot_name       VARCHAR(100) NOT NULL,
    database_name   VARCHAR(100) NOT NULL,
    last_lsn        PG_LSN NOT NULL,
    last_processed  TIMESTAMPTZ DEFAULT now(),
    events_total    BIGINT DEFAULT 0,
    events_since    BIGINT DEFAULT 0,
    lag_bytes       BIGINT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'paused', 'error', 'recovering')),
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT uq_slot_name UNIQUE (slot_name)
);

COMMENT ON TABLE replication_state IS 'WAL replication slot state — one row per active slot';
COMMENT ON COLUMN replication_state.last_lsn IS 'Last confirmed LSN position';
COMMENT ON COLUMN replication_state.lag_bytes IS 'Replication lag in bytes (pg_wal_lsn_diff)';

CREATE INDEX idx_replication_state_status ON replication_state (status);
CREATE INDEX idx_replication_state_updated ON replication_state (updated_at);

-- ============================================================================
-- 2. sync_log — executed synchronizations (date-partitioned)
-- ============================================================================
CREATE TABLE sync_log (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    event_id        UUID NOT NULL,
    rule_id         VARCHAR(50) NOT NULL,
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    target_app      VARCHAR(100) NOT NULL,
    target_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'UPSERT')),
    rows_affected   INT DEFAULT 0,
    duration_ms     INT NOT NULL,
    status          VARCHAR(20) DEFAULT 'completed'
        CHECK (status IN ('completed', 'failed', 'skipped', 'retrying')),
    error_message   TEXT,
    executed_at     TIMESTAMPTZ DEFAULT now() NOT NULL
) PARTITION BY RANGE (executed_at);

COMMENT ON TABLE sync_log IS 'Executed synchronization log — partitioned by date';
COMMENT ON COLUMN sync_log.rows_affected IS 'Number of rows written to target';

-- Default partition for current month
CREATE TABLE sync_log_2026_05 PARTITION OF sync_log
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE INDEX idx_sync_log_rule ON sync_log (rule_id, executed_at);
CREATE INDEX idx_sync_log_status ON sync_log (status, executed_at);
CREATE INDEX idx_sync_log_source ON sync_log (source_app, source_table);

-- ============================================================================
-- 3. rule_execution_log — rule evaluation traces
-- ============================================================================
CREATE TABLE rule_execution_log (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id         VARCHAR(50) NOT NULL,
    event_lsn       PG_LSN NOT NULL,
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    condition_match BOOLEAN DEFAULT false,
    jq_evaluated    BOOLEAN DEFAULT false,
    actions_count   INT DEFAULT 0,
    duration_ms     INT NOT NULL,
    status          VARCHAR(20) DEFAULT 'success'
        CHECK (status IN ('success', 'error', 'timeout', 'cancelled')),
    error_message   TEXT,
    executed_at     TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE rule_execution_log IS 'Rule engine evaluation traces with timing';

CREATE INDEX idx_relog_rule ON rule_execution_log (rule_id, executed_at);
CREATE INDEX idx_relog_executed ON rule_execution_log (executed_at DESC);
CREATE INDEX idx_relog_status ON rule_execution_log (status, executed_at);

-- ============================================================================
-- 4. conflict_log — inter-app data conflicts detected
-- ============================================================================
CREATE TABLE conflict_log (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id         VARCHAR(50),
    source_app_a    VARCHAR(100) NOT NULL,
    source_table_a  VARCHAR(200),
    source_id_a     VARCHAR(200),
    source_app_b    VARCHAR(100) NOT NULL,
    source_table_b  VARCHAR(200),
    source_id_b     VARCHAR(200),
    conflict_type   VARCHAR(50) NOT NULL
        CHECK (conflict_type IN ('duplicate_email', 'duplicate_tax_id',
               'divergent_name', 'divergent_address', 'stale_reference',
               'missing_target', 'type_mismatch', 'other')),
    resolution      VARCHAR(20) DEFAULT 'unresolved'
        CHECK (resolution IN ('unresolved', 'auto_resolved', 'manual', 'ignored')),
    resolved_by     UUID,
    detail          JSONB,
    detected_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
    resolved_at     TIMESTAMPTZ
);

COMMENT ON TABLE conflict_log IS 'Inter-application data conflicts requiring attention';

CREATE INDEX idx_conflict_type ON conflict_log (conflict_type, resolution);
CREATE INDEX idx_conflict_detected ON conflict_log (detected_at DESC);

-- ============================================================================
-- 5. audit_events — ISO 27001 global audit log (date-partitioned)
-- ============================================================================
CREATE TABLE audit_events (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    event_id        UUID DEFAULT uuid_generate_v4() NOT NULL,
    event_type      VARCHAR(50) NOT NULL
        CHECK (event_type IN ('data_sync', 'auth_change', 'role_update',
               'delegation', 'config_change', 'admin_action', 'access_denied',
               'drift_detected', 'circuit_open', 'dlq_event')),
    user_id         UUID,
    role_id         VARCHAR(100),
    source_app      VARCHAR(100),
    source_table    VARCHAR(200),
    operation       VARCHAR(20),
    target_app      VARCHAR(100),
    target_table    VARCHAR(200),
    old_value       JSONB,
    new_value       JSONB,
    ip_address      INET,
    user_agent      TEXT,
    reason          TEXT,
    iso_control     VARCHAR(50),
    severity        VARCHAR(10) DEFAULT 'info'
        CHECK (severity IN ('debug', 'info', 'warning', 'error', 'critical')),
    occurred_at     TIMESTAMPTZ DEFAULT now() NOT NULL
) PARTITION BY RANGE (occurred_at);

COMMENT ON TABLE audit_events IS 'ISO 27001 A.8.15 global audit log — partitioned';

CREATE TABLE audit_events_2026_05 PARTITION OF audit_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE INDEX idx_audit_type ON audit_events (event_type, occurred_at);
CREATE INDEX idx_audit_user ON audit_events (user_id, occurred_at);
CREATE INDEX idx_audit_severity ON audit_events (severity, occurred_at);
CREATE INDEX idx_audit_occurred ON audit_events (occurred_at DESC);

-- ============================================================================
-- 6. anomaly_events — detected anomalies with severity and notification
-- ============================================================================
CREATE TABLE anomaly_events (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    anomaly_type    VARCHAR(50) NOT NULL
        CHECK (anomaly_type IN ('throughput_spike', 'throughput_drop',
               'latency_spike', 'error_burst', 'dlq_backlog', 'lag_increase',
               'conflict_surge', 'unknown_table', 'unknown_operation')),
    source_app      VARCHAR(100),
    source_table    VARCHAR(200),
    severity        VARCHAR(10) NOT NULL DEFAULT 'warning'
        CHECK (severity IN ('info', 'warning', 'critical')),
    metric_name     VARCHAR(100),
    metric_value    DOUBLE PRECISION,
    threshold_value DOUBLE PRECISION,
    detail          JSONB,
    notified        BOOLEAN DEFAULT false,
    notified_at     TIMESTAMPTZ,
    detected_at     TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE anomaly_events IS 'Operational anomalies detected by bKernel monitoring';

CREATE INDEX idx_anomaly_type ON anomaly_events (anomaly_type, severity);
CREATE INDEX idx_anomaly_detected ON anomaly_events (detected_at DESC);
CREATE INDEX idx_anomaly_notified ON anomaly_events (notified, detected_at);

-- ============================================================================
-- 7. dead_letter_queue — failed events for retry
-- ============================================================================
CREATE TABLE dead_letter_queue (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id        UUID NOT NULL,
    rule_id         VARCHAR(50),
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    event_data      JSONB NOT NULL,
    error_message   TEXT NOT NULL,
    error_code      VARCHAR(20),
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,
    next_retry_at   TIMESTAMPTZ,
    retry_backoff   INT[] DEFAULT ARRAY[1, 5, 15],
    status          VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'retrying', 'discarded', 'replayed')),
    created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
    last_retry_at   TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ
);

COMMENT ON TABLE dead_letter_queue IS 'Failed WAL events pending retry or manual intervention';

CREATE INDEX idx_dlq_status ON dead_letter_queue (status, next_retry_at);
CREATE INDEX idx_dlq_rule ON dead_letter_queue (rule_id, status);
CREATE INDEX idx_dlq_created ON dead_letter_queue (created_at DESC);

-- ============================================================================
-- 8. entity_crossref — cross-app entity identity mapping
-- ============================================================================
CREATE TABLE entity_crossref (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type     VARCHAR(100) NOT NULL
        CHECK (entity_type IN ('employee', 'customer', 'product', 'invoice',
               'vendor', 'account', 'user', 'contact')),
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    source_id       VARCHAR(200) NOT NULL,
    target_app      VARCHAR(100) NOT NULL,
    target_table    VARCHAR(200) NOT NULL,
    target_id       VARCHAR(200) NOT NULL,
    confidence      DECIMAL(3,2) DEFAULT 1.00,
    created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT uq_crossref UNIQUE (source_app, source_table, source_id, target_app, target_table)
);

COMMENT ON TABLE entity_crossref IS 'Cross-application entity identity mapping (MDM Hub)';
COMMENT ON COLUMN entity_crossref.confidence IS 'Match confidence: 1.00 = exact, <1.00 = fuzzy';

CREATE INDEX idx_crossref_source ON entity_crossref (source_app, source_table, source_id);
CREATE INDEX idx_crossref_target ON entity_crossref (target_app, target_table, target_id);
CREATE INDEX idx_crossref_type ON entity_crossref (entity_type);
