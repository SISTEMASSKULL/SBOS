-- 002_biedata_db.sql — biedata Data Integration operational database
-- Owner: biedata (Rust daemon)
-- Purpose: box execution history, DLQ for external messages, circuit breaker state
-- ISO 27001: A.8.12 (data leak prevention), A.8.15 (logging)
-- Version: 1.0.0 — 2026-05-12

CREATE SCHEMA IF NOT EXISTS biedata;
SET search_path TO biedata;

-- ============================================================================
-- 1. biedata_audit_log — box execution traces with full audit trail
-- ============================================================================
CREATE TABLE biedata_audit_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_id              UUID DEFAULT uuid_generate_v4() NOT NULL,
    box_id              VARCHAR(50) NOT NULL,
    box_type            VARCHAR(10) NOT NULL
        CHECK (box_type IN ('import', 'export')),
    direction           VARCHAR(6) GENERATED ALWAYS AS (box_type) STORED,
    trigger_type        VARCHAR(20)
        CHECK (trigger_type IN ('schedule', 'file_watch', 'manual', 'redis_cmd')),
    external_system     VARCHAR(100) NOT NULL,
    source_uri          TEXT,
    destination_uri     TEXT,
    status              VARCHAR(20) DEFAULT 'started'
        CHECK (status IN ('started', 'extracting', 'transforming', 'loading',
               'completed', 'completed_with_errors', 'failed', 'aborted')),
    rows_total          INT DEFAULT 0,
    rows_processed      INT DEFAULT 0,
    rows_failed         INT DEFAULT 0,
    bytes_transferred   BIGINT DEFAULT 0,
    duration_ms         INT,
    phase_durations     JSONB,
    error_message       TEXT,
    started_at          TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at        TIMESTAMPTZ,
    operator            VARCHAR(100)
);

COMMENT ON TABLE biedata_audit_log IS 'Complete box execution audit trail';
COMMENT ON COLUMN biedata_audit_log.phase_durations IS 'JSON: {"validate_ms":5, "auth_ms":12, "extract_ms":340, "transform_ms":52, "load_ms":89}';

CREATE INDEX idx_biedata_audit_box ON biedata_audit_log (box_id, started_at DESC);
CREATE INDEX idx_biedata_audit_status ON biedata_audit_log (status, started_at);
CREATE INDEX idx_biedata_audit_external ON biedata_audit_log (external_system, started_at);
CREATE INDEX idx_biedata_audit_job ON biedata_audit_log (job_id);

-- ============================================================================
-- 2. biedata_dlq — dead letter queue for external integration failures
-- ============================================================================
CREATE TABLE biedata_dlq (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_id              UUID NOT NULL,
    box_id              VARCHAR(50) NOT NULL,
    external_system     VARCHAR(100) NOT NULL,
    phase               VARCHAR(20) NOT NULL
        CHECK (phase IN ('extract', 'transform', 'load', 'authenticate')),
    row_index           INT DEFAULT 0,
    row_data            JSONB NOT NULL,
    error_message       TEXT NOT NULL,
    error_code          VARCHAR(50),
    retry_count         INT DEFAULT 0,
    max_retries         INT DEFAULT 3,
    next_retry_at       TIMESTAMPTZ,
    status              VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'retrying', 'discarded', 'resolved')),
    created_at          TIMESTAMPTZ DEFAULT now() NOT NULL,
    last_retry_at       TIMESTAMPTZ,
    resolved_at         TIMESTAMPTZ
);

COMMENT ON TABLE biedata_dlq IS 'Dead letter queue for failed external integration messages';

CREATE INDEX idx_biedata_dlq_status ON biedata_dlq (status, next_retry_at);
CREATE INDEX idx_biedata_dlq_box ON biedata_dlq (box_id, status);
CREATE INDEX idx_biedata_dlq_external ON biedata_dlq (external_system, created_at DESC);

-- ============================================================================
-- 3. biedata_circuit_state — circuit breaker per external system
-- ============================================================================
CREATE TABLE biedata_circuit_state (
    id                  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_system     VARCHAR(100) NOT NULL,
    state               VARCHAR(20) DEFAULT 'closed'
        CHECK (state IN ('closed', 'half_open', 'open')),
    failure_count       INT DEFAULT 0,
    success_count       INT DEFAULT 0,
    failure_threshold   INT DEFAULT 5,
    success_threshold   INT DEFAULT 3,
    cooldown_seconds    INT DEFAULT 60,
    last_failure        TIMESTAMPTZ,
    last_success        TIMESTAMPTZ,
    opened_at           TIMESTAMPTZ,
    closed_at           TIMESTAMPTZ,
    last_error_message  TEXT,
    updated_at          TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT uq_circuit_system UNIQUE (external_system)
);

COMMENT ON TABLE biedata_circuit_state IS 'Circuit breaker per external system — prevents cascading failures';
COMMENT ON COLUMN biedata_circuit_state.state IS 'closed=healthy, half_open=testing, open=blocked';
COMMENT ON COLUMN biedata_circuit_state.cooldown_seconds IS 'Seconds to wait before transitioning open→half_open';

CREATE INDEX idx_circuit_state ON biedata_circuit_state (state);
