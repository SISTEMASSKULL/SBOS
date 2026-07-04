-- 004_bcompass_db.sql — bCompass AI Intelligence operational database
-- Owner: bcompass (Go daemon)
-- Purpose: route execution traces, feedback, proposals
-- ISO 27001: A.8.25 (security in development lifecycle), A.8.28 (secure coding)
-- Version: 1.0.0 — 2026-05-12

CREATE SCHEMA IF NOT EXISTS bcompass;
SET search_path TO bcompass;

-- ============================================================================
-- 1. bcompass_route_log — route execution traces
-- ============================================================================
CREATE TABLE bcompass_route_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id            VARCHAR(50) NOT NULL,
    route_type          VARCHAR(20) NOT NULL
        CHECK (route_type IN ('report', 'analysis', 'qa', 'suggest', 'plan',
               'customer_analysis', 'inventory_analysis', 'employee_analysis',
               'sales_forecast', 'financial_analysis', 'compliance_check')),
    user_id             UUID NOT NULL,
    governance_level    SMALLINT NOT NULL DEFAULT 1
        CHECK (governance_level BETWEEN 1 AND 3),
    model_used          VARCHAR(50) NOT NULL,
    prompt_template     VARCHAR(100),
    prompt_tokens       INT DEFAULT 0,
    completion_tokens   INT DEFAULT 0,
    total_tokens        INT GENERATED ALWAYS AS (prompt_tokens + completion_tokens) STORED,
    context_docs        INT DEFAULT 0,
    confidence          DECIMAL(3,2),
    latency_ms          INT NOT NULL,
    ollama_latency_ms   INT,
    status              VARCHAR(20) DEFAULT 'completed'
        CHECK (status IN ('pending', 'running', 'completed', 'failed',
               'cancelled', 'requires_approval')),
    approval_status     VARCHAR(20) DEFAULT 'not_required'
        CHECK (approval_status IN ('not_required', 'pending', 'approved',
               'rejected', 'expired')),
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    langfuse_trace_id   VARCHAR(100),
    output_summary      TEXT,
    error_message       TEXT,
    executed_at         TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_langfuse_trace UNIQUE (langfuse_trace_id)
);

COMMENT ON TABLE bcompass_route_log IS 'AI route execution traces with full Langfuse observability';
COMMENT ON COLUMN bcompass_route_log.confidence IS 'Model confidence score for the output';
COMMENT ON COLUMN bcompass_route_log.langfuse_trace_id IS 'Langfuse trace ID for LLM observability';

CREATE INDEX idx_route_log_route ON bcompass_route_log (route_id, executed_at DESC);
CREATE INDEX idx_route_log_user ON bcompass_route_log (user_id, executed_at DESC);
CREATE INDEX idx_route_log_approval ON bcompass_route_log (approval_status, executed_at);
CREATE INDEX idx_route_log_model ON bcompass_route_log (model_used, executed_at DESC);

-- ============================================================================
-- 2. bcompass_feedback — user ratings per route output
-- ============================================================================
CREATE TABLE bcompass_feedback (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_log_id        BIGINT NOT NULL
        REFERENCES bcompass_route_log(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL,
    rating              SMALLINT NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    useful              BOOLEAN,
    accuracy_ok         BOOLEAN,
    comment             TEXT,
    tags                TEXT[] DEFAULT '{}',
    created_at          TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT uq_feedback_route_user UNIQUE (route_log_id, user_id)
);

COMMENT ON TABLE bcompass_feedback IS 'HITL feedback on AI-generated outputs (1-5 rating)';
COMMENT ON COLUMN bcompass_feedback.tags IS 'Array of tags: {"hallucination","incomplete","perfect","off_topic"}';

CREATE INDEX idx_feedback_route ON bcompass_feedback (route_log_id);
CREATE INDEX idx_feedback_rating ON bcompass_feedback (rating, created_at DESC);

-- ============================================================================
-- 3. bcompass_proposals — generated proposals with confidence and approval flow
-- ============================================================================
CREATE TABLE bcompass_proposals (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id            VARCHAR(50) NOT NULL,
    route_log_id        BIGINT
        REFERENCES bcompass_route_log(id) ON DELETE SET NULL,
    proposal_type       VARCHAR(50) NOT NULL
        CHECK (proposal_type IN ('rule_suggestion', 'report_insight',
               'inventory_alert', 'customer_segment', 'pricing_suggestion',
               'process_optimization', 'anomaly_investigation',
               'compliance_finding', 'forecast', 'general')),
    title               VARCHAR(200) NOT NULL,
    proposal_data       JSONB NOT NULL,
    confidence          DECIMAL(3,2) NOT NULL
        CHECK (confidence BETWEEN 0.00 AND 1.00),
    impact              VARCHAR(10) DEFAULT 'low'
        CHECK (impact IN ('low', 'medium', 'high', 'critical')),
    governance_level    SMALLINT DEFAULT 1
        CHECK (governance_level BETWEEN 1 AND 3),
    status              VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'under_review', 'approved',
               'rejected', 'implemented', 'expired')),
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    rejection_reason    TEXT,
    implementation_ref  VARCHAR(200),
    expires_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_proposal_confidence CHECK (
        (governance_level = 3 AND confidence >= 0.80) OR
        (governance_level = 2 AND confidence >= 0.60) OR
        governance_level = 1
    )
);

COMMENT ON TABLE bcompass_proposals IS 'AI-generated business proposals requiring human approval';
COMMENT ON COLUMN bcompass_proposals.proposal_data IS 'Full proposal payload: context, analysis, recommendation, evidence';
COMMENT ON COLUMN bcompass_proposals.confidence IS 'Minimum 0.80 for governance_level=3, 0.60 for level=2';

CREATE INDEX idx_proposals_route ON bcompass_proposals (route_id, status);
CREATE INDEX idx_proposals_status ON bcompass_proposals (status, created_at DESC);
CREATE INDEX idx_proposals_governance ON bcompass_proposals (governance_level, status);
CREATE INDEX idx_proposals_expires ON bcompass_proposals (expires_at)
    WHERE status IN ('pending', 'under_review');
