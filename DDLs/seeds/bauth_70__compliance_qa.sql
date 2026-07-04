-- ══════════════════════════════════════════════════════════════════════
-- seed_compliance_qa.sql — Seeds idempotentes del Sistema QA
-- IDEMPOTENTE: ON CONFLICT DO UPDATE/NOTHING en todos los INSERT
-- Referencia: BAUTH-QUALITY-ASSURANCE-SYSTEM.md v4.0
-- ══════════════════════════════════════════════════════════════════════

\echo '=== Seed Compliance QA: Fase 1 — Estándares ==='

-- 1. INSERT de estándares (idempotente)
INSERT INTO bauth.compliance_standard (standard_id, standard_name, version, category, total_requirements, url) VALUES
('NIST_800_63B_Rev4',  'NIST SP 800-63B Digital Identity Guidelines',       'Rev.4 (Jul 2025)', 'authentication',  7, 'https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63b-4.pdf'),
('OWASP_ASVS_5.0',    'OWASP Application Security Verification Standard',   '5.0 (May 2025)',   'authentication',  8, 'https://github.com/OWASP/ASVS'),
('ISO_27001_2022',    'ISO/IEC 27001 Information Security Management',      '2022',              'authentication',  5, 'https://www.iso.org/standard/27001'),
('RFC_6238',          'TOTP: Time-Based One-Time Password Algorithm',       'RFC 6238',          'authentication', 18, 'https://datatracker.ietf.org/doc/html/rfc6238'),
('RFC_4226',          'HOTP: HMAC-Based One-Time Password Algorithm',       'RFC 4226',          'authentication', 10, 'https://datatracker.ietf.org/doc/html/rfc4226'),
('RFC_8037_RFC_7519', 'EdDSA + JWT',                                         'RFC 8037/7519',     'crypto',          5, 'https://datatracker.ietf.org/doc/html/rfc8037'),
('RFC_9106',          'Argon2 Memory-Hard Function for Password Hashing',   'RFC 9106',          'crypto',          5, 'https://www.rfc-editor.org/rfc/rfc9106.html'),
('RFC_8705',          'OAuth 2.0 Mutual-TLS Client Authentication',         'RFC 8705',          'authentication',  3, 'https://datatracker.ietf.org/doc/html/rfc8705'),
('FIDO_CTAP_2.2',     'FIDO2 Client to Authenticator Protocol 2.2',         'CTAP 2.2 (2025)',   'authentication', 10, 'https://developers.yubico.com/CTAP/CTAP2.2.html')
ON CONFLICT (standard_id) DO UPDATE SET version = EXCLUDED.version, url = EXCLUDED.url, total_requirements = EXCLUDED.total_requirements;

\echo '=== Seed Compliance QA: Fase 2 — Requisitos normativos ==='

INSERT INTO bauth.compliance_requirement (standard_id, section, title, description, priority, applies_to, implementation_status) VALUES
('NIST_800_63B_Rev4', 'Sec_3.1.1', 'Memorized Secret Verifier',
 'El verificador DEBE exigir mínimo 8 caracteres (MFA) o 15 (single-factor). DEBE validar contra lista de passwords comunes (HIBP). DEBE usar Argon2id con t>=2, m>=32768, p>=1.',
 'mandatory', ARRAY['BAUTH_PASSWORD'], 'not_started'),
('NIST_800_63B_Rev4', 'Sec_3.1.2', 'Look-Up Secret Verifier',
 'El verificador DEBE generar secrets con mínimo 112 bits de entropía. DEBE invalidar después de uso único. DEBE almacenar como hash (SHA-256).',
 'mandatory', ARRAY['BAUTH_RECOVERY'], 'not_started'),
('NIST_800_63B_Rev4', 'Sec_3.1.3', 'Out-of-Band Device Verifier',
 'El verificador DEBE transmitir secreto por canal independiente. DEBE requerir transferencia de secreto entre canales (no approve/deny simple). Email PROHIBIDO como canal OOB.',
 'mandatory', ARRAY['BAUTH_PUSH'], 'not_started'),
('NIST_800_63B_Rev4', 'Sec_3.1.4', 'Single-Factor OTP Verifier',
 'El verificador DEBE usar approved random bit generator. DEBE invalidar tras uso único. TTL máximo 10 minutos. Rate limiting obligatorio si secreto < 64 bits.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_HOTP','BAUTH_EMAIL_OTP'], 'not_started'),
('NIST_800_63B_Rev4', 'Sec_3.2.7', 'Replay Resistance',
 'El verificador DEBE rechazar autenticación con nonce/sequence/code ya utilizado. DEBE detectar replay en todos los métodos OTP.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_HOTP','BAUTH_RECOVERY','BAUTH_EMAIL_OTP','BAUTH_PUSH'], 'not_started'),
('OWASP_ASVS_5.0',   'V6.2',     'Password Security Requirements',
 'La aplicación DEBE verificar passwords contra lista de passwords comunes. DEBE usar Argon2id con parámetros adecuados al tier. DEBE rechazar passwords comprometidos (HIBP).',
 'mandatory', ARRAY['BAUTH_PASSWORD'], 'not_started'),
('OWASP_ASVS_5.0',   'V6.3',     'General Authentication Security',
 'La aplicación DEBE implementar rate limiting en endpoints de auth. DEBE usar bloqueo progresivo. DEBE responder con mensajes genéricos (sin revelar si usuario existe).',
 'mandatory', ARRAY['BAUTH_PASSWORD','BAUTH_TOTP','BAUTH_EMAIL_OTP'], 'not_started'),
('OWASP_ASVS_5.0',   'V6.5',     'Multi-factor Authentication',
 'La aplicación DEBE implementar MFA con al menos 2 factores distintos. DEBE ofrecer opción phishing-resistant. DEBE impedir bypass de MFA.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_HOTP','KC_WEBAUTHN_PASSWORDLESS'], 'not_started'),
('ISO_27001_2022',   'A.8.5',    'Secure Authentication',
 'La organización DEBE implementar autenticación multifactor para acceso a información sensible. DEBE mantener registro de auditoría de intentos de autenticación.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_RECOVERY','BAUTH_PASSWORD'], 'not_started'),
('ISO_27001_2022',   'A.8.9',    'Logging and Monitoring',
 'La organización DEBE registrar eventos de autenticación (éxito y fallo) con trazabilidad completa. Los logs deben ser inmutables (WORM).',
 'mandatory', ARRAY['BAUTH_PASSWORD','BAUTH_TOTP','BAUTH_HOTP','BAUTH_EMAIL_OTP','BAUTH_PUSH','BAUTH_MTLS'], 'not_started')
ON CONFLICT (standard_id, section) DO UPDATE SET description = EXCLUDED.description, applies_to = EXCLUDED.applies_to;

\echo '=== Seed Compliance QA: Fase 3 — Casos de prueba TOTP (RFC 6238 App B) ==='

INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
-- 6 vectores oficiales SHA1
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=59', 'official_vector',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"94287082"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1111111109', 'official_vector',
 '{"secret":"12345678901234567890","time":1111111109,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"07081804"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1111111111', 'official_vector',
 '{"secret":"12345678901234567890","time":1111111111,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"14050471"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1234567890', 'official_vector',
 '{"secret":"12345678901234567890","time":1234567890,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"89005924"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=2000000000', 'official_vector',
 '{"secret":"12345678901234567890","time":2000000000,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"69279037"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=20000000000', 'official_vector',
 '{"secret":"12345678901234567890","time":20000000000,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"65353130"}', 5, true),
-- Edge cases
('BAUTH_TOTP', 'RFC_6238', 'TOTP-digits=6', 'edge_case',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":6,"hash":"SHA1"}',
 '{"otp":"287082"}', 2, false),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-digits=7', 'edge_case',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":7,"hash":"SHA1"}',
 '{"otp":"4287082"}', 2, false),
-- Negative tests
('BAUTH_TOTP', 'RFC_6238', 'TOTP-empty-secret', 'negative',
 '{"secret":"","time":59,"period":30,"digits":8,"hash":"SHA1"}',
 '{"error":"secret_required"}', 3, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-invalid-hash', 'negative',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":8,"hash":"MD5"}',
 '{"error":"unsupported_hash"}', 3, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

\echo '=== Seed Compliance QA: Fase 4 — Casos de prueba HOTP (RFC 4226 App D) ==='

INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=0', 'official_vector',
 '{"secret":"12345678901234567890","counter":0,"digits":6}',
 '{"hotp":"755224","hmac_intermediate":"cc93cf18508d94934c64b65d8ba7667fb7cde4b0"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=1', 'official_vector',
 '{"secret":"12345678901234567890","counter":1,"digits":6}',
 '{"hotp":"287082"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=4', 'official_vector',
 '{"secret":"12345678901234567890","counter":4,"digits":6}',
 '{"hotp":"338314"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=9', 'official_vector',
 '{"secret":"12345678901234567890","counter":9,"digits":6}',
 '{"hotp":"520489"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-empty-secret', 'negative',
 '{"secret":"","counter":0,"digits":6}',
 '{"error":"secret_required"}', 3, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter-negative', 'negative',
 '{"secret":"12345678901234567890","counter":-1,"digits":6}',
 '{"error":"invalid_counter"}', 3, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

\echo '=== Seed Compliance QA: Fase 5 — Casos de prueba JWT/EdDSA ==='

INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
('KC_OIDC', 'RFC_8037_RFC_7519', 'JWT-EdDSA-verify-valid', 'official_vector',
 '{"algorithm":"EdDSA","kid":"test-key-1"}',
 '{"verify":true}', 5, true),
('KC_OIDC', 'RFC_8037_RFC_7519', 'JWT-alg-none', 'negative',
 '{"header":{"alg":"none"}}',
 '{"error":"algorithm_not_allowed"}', 5, true),
('KC_OIDC', 'RFC_8037_RFC_7519', 'JWT-no-signature', 'negative',
 '{"signature":""}',
 '{"error":"signature_required"}', 5, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

\echo '=== Seed Compliance QA: Fase 6 — Casos de prueba Password/Argon2id ==='

INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
('BAUTH_PASSWORD', 'RFC_9106', 'Argon2id-verify-valid', 'official_vector',
 '{"password":"test-password-v1","t":2,"m":32768,"p":1}',
 '{"verify":true}', 5, true),
('BAUTH_PASSWORD', 'RFC_9106', 'Argon2id-verify-invalid', 'negative',
 '{"password":"wrong-password","hash":"$argon2id$v=19$m=32768,t=2,p=1$YWJj...$..."}',
 '{"verify":false}', 5, true),
('BAUTH_PASSWORD', 'NIST_800_63B_Rev4', 'Password-min-length', 'edge_case',
 '{"password":"a","min_length":8}',
 '{"error":"password_too_short"}', 3, true),
('BAUTH_PASSWORD', 'NIST_800_63B_Rev4', 'Password-HIBP-compromised', 'security',
 '{"password":"P@ssw0rd","check_hibp":true}',
 '{"error":"password_compromised"}', 5, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

\echo '=== Seed Compliance QA: 20+ test cases insertados (idempotente) ==='

-- Refrescar vista materializada
REFRESH MATERIALIZED VIEW bauth.compliance_score;

\echo '=== compliance_score refrescado ==='
