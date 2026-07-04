-- ══════════════════════════════════════════════════════════════════════
-- DDL_compliance_qa.sql — Sistema de Aseguramiento de Calidad
-- Estándares: ISO 27001:2022 A.8.5, A.8.9, A.9.2 · NIST 800-63B Rev.4 · OWASP ASVS 5.0
-- Referencia: BAUTH-QUALITY-ASSURANCE-SYSTEM.md v4.0
-- ══════════════════════════════════════════════════════════════════════

\echo '=== DDL Compliance QA: Catálogo de estándares ==='

-- T-620: compliance_standard — Catálogo de estándares de compliance
DROP TABLE IF EXISTS bauth.compliance_standard CASCADE;
CREATE TABLE IF NOT EXISTS bauth.compliance_standard (
    standard_id     TEXT        PRIMARY KEY,
    standard_name   TEXT        NOT NULL,
    version         TEXT        NOT NULL,
    category        TEXT        NOT NULL CHECK (category IN ('authentication','authorization','crypto','audit','federation')),
    url             TEXT,
    total_requirements INTEGER  NOT NULL DEFAULT 0,
    implemented_at  TIMESTAMPTZ,
    last_audited_at TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.compliance_standard IS
'[ISO 27001:2022 A.8.5] Catálogo de estándares de compliance. Cada estándar tiene requisitos específicos que los métodos de autenticación deben cumplir.';

-- T-621: compliance_requirement — Requisitos específicos por estándar
DROP TABLE IF EXISTS bauth.compliance_requirement CASCADE;
CREATE TABLE IF NOT EXISTS bauth.compliance_requirement (
    requirement_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    standard_id     TEXT        NOT NULL REFERENCES bauth.compliance_standard(standard_id),
    section         TEXT        NOT NULL,
    title           TEXT        NOT NULL,
    description     TEXT        NOT NULL,
    priority        TEXT        NOT NULL DEFAULT 'mandatory' CHECK (priority IN ('mandatory','recommended','optional')),
    applies_to      TEXT[]      NOT NULL,
    implementation_status TEXT  NOT NULL DEFAULT 'not_started' CHECK (implementation_status IN ('not_started','in_progress','implemented','verified','certified')),
    evidence_ref    TEXT,
    verified_by     TEXT,
    verified_at     TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (standard_id, section)
);
COMMENT ON TABLE bauth.compliance_requirement IS
'[ISO 27001:2022 A.8.5] Requisitos normativos extraídos de cada estándar. Mapean secciones específicas a métodos de autenticación.';
CREATE INDEX IF NOT EXISTS idx_cr_standard ON bauth.compliance_requirement(standard_id);
CREATE INDEX IF NOT EXISTS idx_cr_status ON bauth.compliance_requirement(implementation_status);

-- T-622: compliance_test_case — Casos de prueba por método
DROP TABLE IF EXISTS bauth.compliance_test_case CASCADE;
CREATE TABLE IF NOT EXISTS bauth.compliance_test_case (
    test_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    method_id       TEXT        NOT NULL,
    standard_id     TEXT        NOT NULL REFERENCES bauth.compliance_standard(standard_id),
    requirement_id  UUID        REFERENCES bauth.compliance_requirement(requirement_id),
    test_name       TEXT        NOT NULL,
    test_type       TEXT        NOT NULL CHECK (test_type IN ('official_vector','edge_case','negative','security','performance')),
    input_data      JSONB       NOT NULL,
    expected_output JSONB       NOT NULL,
    tolerance       TEXT        DEFAULT 'exact',
    weight          INTEGER     NOT NULL DEFAULT 1 CHECK (weight BETWEEN 1 AND 10),
    is_blocking     BOOLEAN     NOT NULL DEFAULT true,
    description     TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (method_id, test_name)
);
COMMENT ON TABLE bauth.compliance_test_case IS
'Casos de prueba por método de autenticación. Incluye vectores oficiales RFC, edge cases, pruebas negativas, de seguridad y de rendimiento.';
CREATE INDEX IF NOT EXISTS idx_ctc_method ON bauth.compliance_test_case(method_id);

-- T-623: compliance_test_result — Resultados de pruebas (WORM)
DROP TABLE IF EXISTS bauth.compliance_test_result CASCADE;
CREATE TABLE IF NOT EXISTS bauth.compliance_test_result (
    result_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    test_id         UUID        NOT NULL REFERENCES bauth.compliance_test_case(test_id),
    method_id       TEXT        NOT NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    executed_by     TEXT        NOT NULL,
    passed          BOOLEAN     NOT NULL,
    actual_output   JSONB,
    error_message   TEXT,
    execution_time_ms INTEGER,
    environment     TEXT        NOT NULL CHECK (environment IN ('local','staging','production')),
    commit_hash     TEXT,
    rust_version    TEXT,
    notes           TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.compliance_test_result IS
'[WORM — ISO 27001:2022 A.8.9] Resultados de ejecución de pruebas de compliance. Inmutable. Solo INSERT, nunca UPDATE ni DELETE.';
CREATE INDEX IF NOT EXISTS idx_ctr_method ON bauth.compliance_test_result(method_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ctr_passed ON bauth.compliance_test_result(method_id, passed);

-- T-624: compliance_score — Vista materializada de score por método
DROP MATERIALIZED VIEW IF EXISTS bauth.compliance_score;
CREATE MATERIALIZED VIEW IF NOT EXISTS bauth.compliance_score AS
WITH latest_results AS (
    SELECT DISTINCT ON (test_id) test_id, passed
    FROM bauth.compliance_test_result
    ORDER BY test_id, executed_at DESC
)
SELECT
    tc.method_id,
    COUNT(DISTINCT tc.test_id) AS total_tests,
    COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) AS passed_tests,
    COUNT(DISTINCT tc.requirement_id) AS total_requirements,
    COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) AS total_blocking,
    COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed AND tc.is_blocking) AS blocking_passed,
    CASE WHEN COUNT(DISTINCT tc.test_id) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed)
              / COUNT(DISTINCT tc.test_id), 1)
    END AS score_pct,
    CASE
        WHEN COUNT(DISTINCT tc.test_id) = 0 THEN 0
        WHEN COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) > 0
         AND COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed AND tc.is_blocking)
            < COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) THEN 0
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) = COUNT(DISTINCT tc.test_id) THEN 4
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) >= 0.8 * COUNT(DISTINCT tc.test_id) THEN 3
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) >= 0.5 * COUNT(DISTINCT tc.test_id) THEN 2
        ELSE 1
    END AS compliance_level
FROM bauth.compliance_test_case tc
LEFT JOIN latest_results lr ON tc.test_id = lr.test_id
GROUP BY tc.method_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_cs_method ON bauth.compliance_score(method_id);
COMMENT ON MATERIALIZED VIEW bauth.compliance_score IS
'Score de completitud de compliance por método de autenticación. Nivel 0=sin tests, 1=<50%, 2=<80%, 3=<100%, 4=100% con bloqueantes. Solo considera el último resultado de cada test case.';

-- T-625: certification_certificate — Certificados emitidos (WORM)
DROP TABLE IF EXISTS bauth.certification_certificate CASCADE;
CREATE TABLE IF NOT EXISTS bauth.certification_certificate (
    certificate_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    method_id          TEXT        NOT NULL,
    certification_level INTEGER    NOT NULL CHECK (certification_level BETWEEN 0 AND 5),
    issued_by          TEXT        NOT NULL,
    issued_to          TEXT        NOT NULL,
    standard_ref       TEXT[]      NOT NULL,
    score_pct          NUMERIC(5,1) NOT NULL,
    total_tests        INTEGER     NOT NULL,
    passed_tests       INTEGER     NOT NULL,
    blocking_passed    INTEGER     NOT NULL,
    valid_from         TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until        TIMESTAMPTZ NOT NULL,
    commit_hash        TEXT        NOT NULL,
    signature_ed25519  TEXT,
    reviewer_id        TEXT,
    report_uri         TEXT,
    revoked_at         TIMESTAMPTZ,
    revocation_reason  TEXT,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cc_method ON bauth.certification_certificate(method_id, certification_level DESC);
CREATE INDEX IF NOT EXISTS idx_cc_valid ON bauth.certification_certificate(valid_until) WHERE revoked_at IS NULL;
COMMENT ON TABLE bauth.certification_certificate IS
'[WORM — ISO 27001:2022 A.8.9] Registro inmutable de certificaciones de métodos de autenticación. Cada certificado es trazable al commit, al agente certificador, y al score de compliance. Firma Ed25519 verificable criptográficamente.';

\echo 'DDL Compliance QA: 5 tablas + 1 vista materializada creadas'
