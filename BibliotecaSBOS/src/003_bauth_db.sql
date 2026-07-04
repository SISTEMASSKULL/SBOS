-- 003_bauth_db.sql — bAuth Auth Enforce operational database
-- Owner: bauth (Go daemon)
-- Purpose: sync log, drift history, delegations, access log
-- ISO 27001: A.5.15 (access control), A.5.18 (access rights), A.8.5 (secure auth)
-- Version: 1.0.0 — 2026-05-12

CREATE SCHEMA IF NOT EXISTS bauth;
SET search_path TO bauth;

-- ============================================================================
-- 1. bauth_sync_log — role template sync traceability
-- ============================================================================
CREATE TABLE bauth_sync_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    template_type       VARCHAR(20) NOT NULL
        CHECK (template_type IN ('role_template', 'user_template')),
    template_id         VARCHAR(100) NOT NULL,
    template_version    VARCHAR(20),
    action              VARCHAR(30) NOT NULL
        CHECK (action IN ('create_role', 'update_role', 'delete_role',
               'sync_user', 'sync_attributes', 'force_resync',
               'recalculate_mask', 'provision_realm')),
    kc_status           VARCHAR(20) DEFAULT 'pending'
        CHECK (kc_status IN ('pending', 'syncing', 'synced', 'error', 'skipped')),
    tryton_status       VARCHAR(20) DEFAULT 'pending'
        CHECK (tryton_status IN ('pending', 'syncing', 'synced', 'error', 'skipped')),
    privilege_mask      BIGINT,
    mask_previous       BIGINT,
    kc_objects_created  INT DEFAULT 0,
    kc_objects_updated  INT DEFAULT 0,
    kc_objects_deleted  INT DEFAULT 0,
    tryton_groups_synced INT DEFAULT 0,
    duration_ms         INT NOT NULL,
    error_message       TEXT,
    drift_detected      BOOLEAN DEFAULT false,
    drift_corrected     BOOLEAN DEFAULT false,
    triggered_by        VARCHAR(100),
    synced_at           TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE bauth_sync_log IS 'Complete role/user template sync traceability';
COMMENT ON COLUMN bauth_sync_log.privilege_mask IS 'Calculated 64-bit BitMask applied to Keycloak';
COMMENT ON COLUMN bauth_sync_log.mask_previous IS 'Previous BitMask before this sync — for rollback audit';

CREATE INDEX idx_bauth_sync_template ON bauth_sync_log (template_id, synced_at DESC);
CREATE INDEX idx_bauth_sync_kc_status ON bauth_sync_log (kc_status, synced_at);
CREATE INDEX idx_bauth_sync_tryton ON bauth_sync_log (tryton_status, synced_at);
CREATE INDEX idx_bauth_sync_triggered ON bauth_sync_log (triggered_by, synced_at DESC);

-- ============================================================================
-- 2. bauth_drift_history — detected drift between declared and actual state
-- ============================================================================
CREATE TABLE bauth_drift_history (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    template_id         VARCHAR(100) NOT NULL,
    drift_type          VARCHAR(50) NOT NULL
        CHECK (drift_type IN ('missing_composite_role', 'extra_realm_role',
               'wrong_attributes', 'missing_user_attributes',
               'stale_mask', 'missing_tryton_group', 'extra_tryton_privilege',
               'unauthorized_kc_change', 'delegation_not_revoked')),
    expected_value      JSONB NOT NULL,
    actual_value        JSONB NOT NULL,
    severity            VARCHAR(10) DEFAULT 'medium'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    corrected           BOOLEAN DEFAULT false,
    correction_method   VARCHAR(30)
        CHECK (correction_method IN ('auto_resync', 'force_resync', 'manual', NULL)),
    corrected_at        TIMESTAMPTZ,
    detected_at         TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE bauth_drift_history IS 'State drift between declared RolTemplate and actual Keycloak/Tryton';
COMMENT ON COLUMN bauth_drift_history.expected_value IS 'Declared state from RolTemplate';
COMMENT ON COLUMN bauth_drift_history.actual_value IS 'Observed state in Keycloak Admin API or Tryton XML-RPC';

CREATE INDEX idx_drift_template ON bauth_drift_history (template_id, detected_at DESC);
CREATE INDEX idx_drift_corrected ON bauth_drift_history (corrected, severity);
CREATE INDEX idx_drift_type ON bauth_drift_history (drift_type, detected_at DESC);

-- ============================================================================
-- 3. bauth_delegations — temporary access delegations
-- ============================================================================
CREATE TABLE bauth_delegations (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    delegated_to        UUID NOT NULL,
    delegated_from      UUID NOT NULL,
    role_template       VARCHAR(100) NOT NULL,
    reason              TEXT NOT NULL,
    bitmask_effective   BIGINT NOT NULL,
    valid_from          TIMESTAMPTZ NOT NULL,
    valid_until         TIMESTAMPTZ NOT NULL,
    auto_revoke         BOOLEAN DEFAULT true,
    status              VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('pending', 'active', 'expired', 'revoked', 'rejected')),
    approved_by         UUID,
    revoked_by          UUID,
    revoke_reason       TEXT,
    created_at          TIMESTAMPTZ DEFAULT now() NOT NULL,
    activated_at        TIMESTAMPTZ,
    revoked_at          TIMESTAMPTZ,

    CONSTRAINT chk_delegation_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_delegation_not_self CHECK (delegated_to != delegated_from)
);

COMMENT ON TABLE bauth_delegations IS 'Temporary access delegations with AND intersection BitMask';
COMMENT ON COLUMN bauth_delegations.bitmask_effective IS 'grantorMask & delegateeMask — minimum privilege principle';

CREATE INDEX idx_delegations_to ON bauth_delegations (delegated_to, status);
CREATE INDEX idx_delegations_from ON bauth_delegations (delegated_from, status);
CREATE INDEX idx_delegations_expiry ON bauth_delegations (valid_until, status)
    WHERE status = 'active';

-- ============================================================================
-- 4. bauth_access_log — access log with BitMask and domain decisions
-- ============================================================================
CREATE TABLE bauth_access_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             UUID NOT NULL,
    username            VARCHAR(200),
    node_id             VARCHAR(100),
    input_type          VARCHAR(20) NOT NULL
        CHECK (input_type IN ('password', 'otp', 'webauthn', 'qr', 'nfc',
               'fingerprint', 'face', 'sso')),
    domain_logical      BOOLEAN DEFAULT false,
    domain_physical     BOOLEAN DEFAULT false,
    domain_financial    BOOLEAN DEFAULT false,
    loa_level           SMALLINT DEFAULT 1
        CHECK (loa_level BETWEEN 1 AND 4),
    result              VARCHAR(10) NOT NULL
        CHECK (result IN ('GRANTED', 'DENIED', 'STEP_UP', 'EXPIRED', 'ERROR')),
    deny_reason         VARCHAR(50),
    bitmask             BIGINT,
    bitmask_operations  VARCHAR(100),
    ip_address          INET,
    geo_city            VARCHAR(100),
    geo_country         VARCHAR(2),
    session_id          UUID,
    latency_ms          INT NOT NULL,
    spi_latency_ms      JSONB,
    evaluated_at        TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE bauth_access_log IS 'Access decisions with full BitMask and 3-domain context';
COMMENT ON COLUMN bauth_access_log.spi_latency_ms IS 'Per-SPI latency: {"temporal":2,"geo":3,"validity":1}';

CREATE INDEX idx_access_user ON bauth_access_log (user_id, evaluated_at DESC);
CREATE INDEX idx_access_result ON bauth_access_log (result, evaluated_at);
CREATE INDEX idx_access_node ON bauth_access_log (node_id, evaluated_at DESC);
CREATE INDEX idx_access_evaluated ON bauth_access_log (evaluated_at DESC);
