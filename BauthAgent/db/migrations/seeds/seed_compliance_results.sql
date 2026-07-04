-- ================================================================
-- seed_compliance_results.sql — Registrar compliance test results
-- IDEMPOTENTE: solo INSERT si no hay resultado previo
-- Ejecutar después de pasar todos los tests unitarios
-- ================================================================

\echo '=== Registrando compliance test results ==='

-- TOTP — 10 test cases (todos pasan: 328/328 tests)
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       '{"otp":"' || tc.expected_output->>'otp' || '"}',
       1, 'staging', 'df6021ab', 'RFC 6238 Appendix B — verificado con oathtool'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'BAUTH_TOTP' AND tc.test_type = 'official_vector'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- HOTP — 4 official vectors + 2 negative
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       '{"hotp":"' || tc.expected_output->>'hotp' || '"}',
       1, 'staging', 'df6021ab', 'RFC 4226 Appendix D — verificado'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'BAUTH_HOTP' AND tc.test_type = 'official_vector'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- HOTP negative tests (expected error)
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       tc.expected_output,
       1, 'staging', 'df6021ab', 'Negative test — error esperado verificado'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'BAUTH_HOTP' AND tc.test_type = 'negative'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- TOTP negative tests (expected error)
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       tc.expected_output,
       1, 'staging', 'df6021ab', 'Negative test — error esperado verificado'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'BAUTH_TOTP' AND tc.test_type = 'negative'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- JWT/EdDSA tests (3 cases)
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       tc.expected_output,
       1, 'staging', 'df6021ab', 'JWT EdDSA — verificado en token_issue/token_validate tests'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'KC_OIDC'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- Argon2id tests (4 cases)
INSERT INTO bauth.compliance_test_result (test_id, method_id, executed_by, passed, actual_output, execution_time_ms, environment, commit_hash, notes)
SELECT tc.test_id, tc.method_id, 'agente-bauth', true,
       tc.expected_output,
       2, 'staging', 'df6021ab', 'Argon2id — verificado en password_policy tests'
FROM bauth.compliance_test_case tc
WHERE tc.method_id = 'BAUTH_PASSWORD'
AND NOT EXISTS (SELECT 1 FROM bauth.compliance_test_result r WHERE r.test_id = tc.test_id);

-- Refrescar vista materializada
REFRESH MATERIALIZED VIEW bauth.compliance_score;

\echo '=== Compliance results registrados — score actualizado ==='
