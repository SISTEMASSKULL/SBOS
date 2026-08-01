-- =============================================================================
-- MIGRACIÓN ISO 27001:2022 BACKLOG — T-520..T-524, T-526..T-528, T-564, T-565
-- T-BACKLOG-001..009 implementados en SBOSDB
-- Fecha: 2026-08-01
-- IDEMPOTENTE: seguro de ejecutar múltiples veces
-- Orden de dependencias:
--   T-BACKLOG-008 → habilita T-BACKLOG-002 + A.5.13
--   T-BACKLOG-003, T-BACKLOG-005, T-BACKLOG-009 (independientes)
--   T-BACKLOG-001 → habilita T-BACKLOG-006 + T-BACKLOG-007
--   T-BACKLOG-002 (después de T-008)
--   T-BACKLOG-006, T-BACKLOG-007 (después de T-001)
-- =============================================================================

BEGIN;

-- ============================================================
-- T-BACKLOG-008: pii_category + legal_basis en T-157
-- idn_identity_attribute ya existe en SBOSDB → ALTER TABLE
-- ============================================================

ALTER TABLE bauth.idn_identity_attribute
    ADD COLUMN IF NOT EXISTS pii_category TEXT
        CHECK (pii_category IN (
            'EMAIL','PHONE','NID','BIOMETRIC','FINANCIAL',
            'ADDRESS','NAME','DATE_OF_BIRTH','NONE'
        ));

ALTER TABLE bauth.idn_identity_attribute
    ADD COLUMN IF NOT EXISTS legal_basis TEXT
        CHECK (legal_basis IN (
            'CONTRACT','LEGAL_OBLIGATION','LEGITIMATE_INTEREST',
            'CONSENT','VITAL_INTEREST'
        ));

COMMENT ON COLUMN bauth.idn_identity_attribute.pii_category IS
'[ISO 27001 A.5.34] Categoría formal de PII del atributo. NULL = no es dato personal.';
COMMENT ON COLUMN bauth.idn_identity_attribute.legal_basis IS
'[ISO 27001 A.5.34][GDPR Art.6] Base legal de procesamiento por atributo individual. NULL = no-PII.';

-- ============================================================
-- T-BACKLOG-001 — T-520: inc_incident
-- ============================================================

CREATE TABLE IF NOT EXISTS bauth.inc_incident (
    inc_id         UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    incident_type  TEXT        NOT NULL,
    severity       TEXT        NOT NULL,
    detected_at    TIMESTAMPTZ NOT NULL,
    resolved_at    TIMESTAMPTZ NULL,
    caep_event_ref UUID        NULL,
    aud_event_ref  UUID        NULL,
    summary        TEXT        NOT NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_inc_severity CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    CONSTRAINT chk_inc_type     CHECK (incident_type IN (
        'CREDENTIAL_BREACH','UNAUTHORIZED_ACCESS','PRIVILEGE_ESCALATION',
        'DATA_EXFILTRATION','ACCOUNT_TAKEOVER','MFA_BYPASS','IOC_DETECTED',
        'POLICY_VIOLATION','INSIDER_THREAT','CONFIGURATION_ERROR','OTHER'
    ))
);
CREATE INDEX IF NOT EXISTS idx_inc_tenant ON bauth.inc_incident(tenant_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_inc_open   ON bauth.inc_incident(detected_at) WHERE resolved_at IS NULL;
COMMENT ON TABLE bauth.inc_incident IS
'INCIDENTES | Cabecera del incidente de seguridad. ISO 27001:2022 A.5.27. T-520.';

-- T-521: inc_root_cause
CREATE TABLE IF NOT EXISTS bauth.inc_root_cause (
    cause_id             UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    cause_category       TEXT        NOT NULL,
    description          TEXT        NOT NULL,
    contributing_factors JSONB       NULL,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_rc_incident  UNIQUE (inc_id),
    CONSTRAINT chk_rc_category CHECK (cause_category IN (
        'MISCONFIGURATION','MISSING_CONTROL','HUMAN_ERROR','SOFTWARE_BUG',
        'SOCIAL_ENGINEERING','EXTERNAL_ATTACK','POLICY_GAP','UNKNOWN'
    ))
);
COMMENT ON TABLE bauth.inc_root_cause IS
'INCIDENTES | Análisis de causa raíz (una por incidente). ISO 27001:2022 A.5.27. T-521.';

-- T-522: inc_corrective_action (incluye action_phase desde el inicio — A.5.26+A.5.27)
CREATE TABLE IF NOT EXISTS bauth.inc_corrective_action (
    action_id            UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    sequence_nr          INTEGER     NOT NULL DEFAULT 1,
    action_type          TEXT        NOT NULL,
    action_phase         TEXT        NOT NULL DEFAULT 'CORRECTIVE',
    target_table         TEXT        NULL,
    target_record_id     UUID        NULL,
    description          TEXT        NOT NULL,
    implemented_by       UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    implemented_at       TIMESTAMPTZ NULL,
    status               TEXT        NOT NULL DEFAULT 'PENDING',
    linked_revocation_id UUID        NULL REFERENCES bauth.idn_credencial_revocacion(revocacion_id),
    linked_thi_id        UUID        NULL,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ica_phase  CHECK (action_phase IN (
        'CONTAINMENT','ERADICATION','RECOVERY','CORRECTIVE','TRAINING'
    )),
    CONSTRAINT chk_ica_status CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','CANCELLED')),
    CONSTRAINT chk_ica_type   CHECK (action_type IN (
        'REVOKE_CREDENTIAL','BLOCK_IP','SUSPEND_ACCOUNT','PATCH_SYSTEM',
        'UPDATE_POLICY','CHANGE_CONFIG','NOTIFY_STAKEHOLDERS','TRAIN_USERS',
        'REVIEW_ACCESS','RESET_MFA','OTHER'
    ))
);
CREATE INDEX IF NOT EXISTS idx_ica_incident ON bauth.inc_corrective_action(inc_id, sequence_nr);
CREATE INDEX IF NOT EXISTS idx_ica_phase    ON bauth.inc_corrective_action(action_phase, status);
COMMENT ON TABLE bauth.inc_corrective_action IS
'INCIDENTES | Medidas correctivas. action_phase: A.5.26 (CONTAINMENT/ERADICATION/RECOVERY) + A.5.27 (CORRECTIVE/TRAINING). T-522.';

-- T-523: inc_effectiveness_review
CREATE TABLE IF NOT EXISTS bauth.inc_effectiveness_review (
    review_id            UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    review_date          TIMESTAMPTZ NOT NULL,
    reviewer_id          UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    reincidence_detected BOOLEAN     NOT NULL DEFAULT false,
    verdict              TEXT        NOT NULL DEFAULT 'PENDING',
    findings             TEXT        NULL,
    next_review_date     DATE        NULL,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ier_verdict CHECK (verdict IN (
        'EFFECTIVE','PARTIALLY_EFFECTIVE','INEFFECTIVE','PENDING'
    ))
);
COMMENT ON TABLE bauth.inc_effectiveness_review IS
'INCIDENTES | Revisión de efectividad (PDCA Check). ISO 27001:2022 A.5.27. T-523.';

-- ============================================================
-- T-BACKLOG-003 — T-524: cfg_retention_policy
-- ============================================================

CREATE TABLE IF NOT EXISTS bauth.cfg_retention_policy (
    policy_id      UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    table_name     TEXT        NOT NULL,
    column_name    TEXT        NULL,
    retention_days INTEGER     NOT NULL CHECK (retention_days > 0),
    purge_action   TEXT        NOT NULL,
    exemption      TEXT        NULL,
    legal_basis    TEXT        NOT NULL,
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_rp_accion   CHECK (purge_action IN ('DELETE','ANONYMIZE','ARCHIVE'))
);
-- Índice UNIQUE expresional: COALESCE no es válido en UNIQUE constraint de tabla
CREATE UNIQUE INDEX IF NOT EXISTS uq_rp_tabla_col
    ON bauth.cfg_retention_policy (table_name, COALESCE(column_name, '__all__'));
COMMENT ON TABLE bauth.cfg_retention_policy IS
'CICLO DE VIDA | Política de retención y eliminación por tabla/columna. ISO 27001:2022 A.8.10. T-524.';

INSERT INTO bauth.cfg_retention_policy
    (table_name, column_name, retention_days, purge_action, exemption, legal_basis, ctx_id)
VALUES
    ('bauth.idn_identity_attribute', NULL,     365*7, 'ANONYMIZE', NULL,   'Ley 843 Bolivia Art.44 — 7 años', 'system'),
    ('bauth.ses_session_log',         NULL,     365,   'DELETE',    NULL,   'ISO 27001 A.8.10 — 1 año',        'system'),
    ('bauth.auth_attempt_log',        NULL,     365,   'DELETE',    'WORM', 'ISO 27001 A.8.15 — 1 año mínimo', 'system'),
    ('bauth.pam_breakglass_activation',NULL,   365*3, 'ARCHIVE',   NULL,   'PCI DSS 4.0 Req 10.7 — 3 años',  'system')
ON CONFLICT (table_name, COALESCE(column_name, '__all__')) DO NOTHING;

-- ============================================================
-- T-BACKLOG-005 — T-564: thi_indicator + T-526: thi_correlation_log
-- ============================================================

CREATE TABLE IF NOT EXISTS bauth.thi_indicator (
    indicator_id    UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    indicator_type  TEXT        NOT NULL,
    indicator_value TEXT        NOT NULL,
    source          TEXT        NOT NULL,
    confidence      TEXT        NOT NULL,
    category        TEXT        NOT NULL,
    action          TEXT        NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    notes           TEXT        NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_thi_indicator   UNIQUE (indicator_type, indicator_value, source),
    CONSTRAINT chk_thi_type       CHECK (indicator_type  IN ('IPv4','IPv4_RANGE','DOMAIN','EMAIL_DOMAIN','HASH_SHA256','USER_AGENT')),
    CONSTRAINT chk_thi_source     CHECK (source          IN ('CISA','STIX_TAXII','ISAC','INTERNAL','MANUAL')),
    CONSTRAINT chk_thi_confidence CHECK (confidence      IN ('HIGH','MEDIUM','LOW')),
    CONSTRAINT chk_thi_category   CHECK (category        IN ('TOR_EXIT','CREDENTIAL_STUFFING','PHISHING','BOTNET','BRUTE_FORCE')),
    CONSTRAINT chk_thi_action     CHECK (action          IN ('BLOCK','REQUIRE_STEP_UP','MONITOR','ALERT_ONLY'))
);
CREATE INDEX IF NOT EXISTS idx_thi_active ON bauth.thi_indicator(indicator_type, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_thi_expiry ON bauth.thi_indicator(valid_until) WHERE valid_until IS NOT NULL AND is_active = true;
COMMENT ON TABLE bauth.thi_indicator IS
'AMENAZAS | Catálogo de IOCs. Consultado en pipeline auth. ISO 27001:2022 A.5.7. T-564.';

CREATE TABLE IF NOT EXISTS bauth.thi_correlation_log (
    corr_id          UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    indicator_id     UUID        NOT NULL REFERENCES bauth.thi_indicator(indicator_id),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    auth_attempt_ref UUID        NULL,
    matched_value    TEXT        NOT NULL,
    action_taken     TEXT        NOT NULL,
    entity_id        UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    detected_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_tcl_action CHECK (action_taken IN ('BLOCKED','STEP_UP_FORCED','MONITORED','ALERTED'))
);
CREATE INDEX IF NOT EXISTS idx_tcl_indicator ON bauth.thi_correlation_log(indicator_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_tcl_tenant    ON bauth.thi_correlation_log(tenant_id,    detected_at DESC);
REVOKE UPDATE, DELETE ON bauth.thi_correlation_log FROM bauth_app_role;
COMMENT ON TABLE bauth.thi_correlation_log IS
'AMENAZAS | Log WORM de correlaciones IOC. ISO 27001:2022 A.5.7. T-526.';

-- ============================================================
-- T-BACKLOG-009 — T-527: vul_component + T-528: vul_auth_impact
-- ============================================================

CREATE TABLE IF NOT EXISTS bauth.vul_component (
    component_id   UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    name           TEXT        NOT NULL,
    component_type TEXT        NOT NULL,
    version        TEXT        NOT NULL,
    source         TEXT        NOT NULL DEFAULT 'Cargo.toml',
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    last_scanned   TIMESTAMPTZ NULL,
    scan_tool      TEXT        NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_vul_component  UNIQUE (name, version),
    CONSTRAINT chk_vul_comp_type CHECK (component_type IN (
        'RUST_CRATE','SYSTEM_LIB','BINARY','CONFIG','PROTOCOL'
    ))
);
COMMENT ON TABLE bauth.vul_component IS
'VULNERABILIDADES | Inventario stack auth bAuth. ISO 27001:2022 A.8.8. T-527.';

CREATE TABLE IF NOT EXISTS bauth.vul_auth_impact (
    impact_id        UUID         NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    cve_id           TEXT         NOT NULL,
    component_id     UUID         NOT NULL REFERENCES bauth.vul_component(component_id),
    affected_methods TEXT[]       NOT NULL DEFAULT '{}',
    severity         TEXT         NOT NULL,
    cvss_score       NUMERIC(3,1) NULL CHECK (cvss_score BETWEEN 0.0 AND 10.0),
    impact_desc      TEXT         NOT NULL,
    mitigation       TEXT         NULL,
    action_taken     TEXT         NULL,
    disabled_methods TEXT[]       NOT NULL DEFAULT '{}',
    sla_deadline     TIMESTAMPTZ  NULL,
    resolved_at      TIMESTAMPTZ  NULL,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_vai_severity CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')),
    CONSTRAINT chk_vai_action   CHECK (
        action_taken IS NULL OR
        action_taken IN ('DISABLED_METHOD','PATCHED','MITIGATED','ACCEPTED','PENDING')
    )
);
CREATE INDEX IF NOT EXISTS idx_vai_sla_open ON bauth.vul_auth_impact(sla_deadline) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_vai_cve      ON bauth.vul_auth_impact(cve_id);
COMMENT ON TABLE bauth.vul_auth_impact IS
'VULNERABILIDADES | Impacto CVE en 18 métodos auth. SLA: CRITICAL=24h/HIGH=7d/MEDIUM=30d/LOW=90d. ISO 27001:2022 A.8.8. T-528.';

-- ============================================================
-- T-BACKLOG-006 — T-565: inc_security_event (depende de T-520)
-- ============================================================

CREATE TABLE IF NOT EXISTS bauth.inc_security_event (
    event_id       UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    source_table   TEXT        NOT NULL,
    source_ref     UUID        NULL,
    description    TEXT        NOT NULL,
    assessed_by    UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    assessed_at    TIMESTAMPTZ NULL,
    decision       TEXT        NULL,
    severity       TEXT        NULL,
    decision_notes TEXT        NULL,
    incident_id    UUID        NULL REFERENCES bauth.inc_incident(inc_id),
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ise_source   CHECK (source_table IN (
        'ses_caep_event_log','auth_attempt_log','aud_event_log','thi_correlation_log','MANUAL'
    )),
    CONSTRAINT chk_ise_decision CHECK (decision IS NULL OR decision IN (
        'CONFIRMED','FALSE_POSITIVE','MONITORING','ESCALATED'
    )),
    CONSTRAINT chk_ise_severity CHECK (severity IS NULL OR severity IN (
        'CRITICAL','HIGH','MEDIUM','LOW'
    ))
);
CREATE INDEX IF NOT EXISTS idx_ise_tenant  ON bauth.inc_security_event(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ise_pending ON bauth.inc_security_event(created_at) WHERE decision IS NULL;
COMMENT ON TABLE bauth.inc_security_event IS
'INCIDENTES | Triaje: decisión formal del analista sobre evento sospechoso. ISO 27001:2022 A.5.25. T-565.';

-- ============================================================
-- T-BACKLOG-002: CHECK constraint en T-157 (depende de T-BACKLOG-008)
-- Idempotente: DO $$ bloque verifica si ya existe antes de agregar.
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_schema = 'bauth'
          AND table_name        = 'idn_identity_attribute'
          AND constraint_name   = 'chk_attr_pii_metadata_completa'
    ) THEN
        ALTER TABLE bauth.idn_identity_attribute
        ADD CONSTRAINT chk_attr_pii_metadata_completa
        CHECK (
            attr_namespace NOT IN ('biometric','identification','fiscal','verification')
            OR (pii_category IS NOT NULL AND legal_basis IS NOT NULL)
        );
    END IF;
END $$;

-- ============================================================
-- T-BACKLOG-007: action_phase ya está en inc_corrective_action (T-522)
-- No se requiere ALTER — la columna fue incluida en el CREATE TABLE.
-- Verificación:
-- ============================================================
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema='bauth' AND table_name='inc_corrective_action'
--   AND column_name='action_phase';

COMMIT;

-- =============================================================================
-- VERIFICACIÓN POST-MIGRACIÓN (ejecutar por separado para confirmar)
-- =============================================================================
-- SELECT tablename FROM pg_tables WHERE schemaname='bauth'
--   AND tablename IN (
--     'inc_incident','inc_root_cause','inc_corrective_action','inc_effectiveness_review',
--     'cfg_retention_policy','thi_indicator','thi_correlation_log',
--     'vul_component','vul_auth_impact','inc_security_event'
--   )
-- ORDER BY tablename;
--
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema='bauth' AND table_name='idn_identity_attribute'
--   AND column_name IN ('pii_category','legal_basis');
--
-- SELECT constraint_name FROM information_schema.table_constraints
-- WHERE constraint_schema='bauth' AND table_name='idn_identity_attribute'
--   AND constraint_name='chk_attr_pii_metadata_completa';
