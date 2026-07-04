-- ══════════════════════════════════════════════════════════════════════
-- seed_auth_method_native.sql — 13 métodos nativos BAUTH_*
-- IDEMPOTENTE: ON CONFLICT DO NOTHING/UPDATE
-- Expande bauth.auth_method de 15 (KC_*) a 28 (KC_* + BAUTH_*)
-- Fecha: 2026-06-29 · Fase 1 Roadmap completada
-- ══════════════════════════════════════════════════════════════════════

\echo '=== Seed Auth Methods: 13 métodos nativos BAUTH_* ==='

INSERT INTO bauth.auth_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, rfc_ref, kc_implementation, requires_https) VALUES
-- Fase 1: Validadores Nativos (implementados en Rust puro, sin Keycloak)

-- Password
('BAUTH_PASSWORD',           'Password / Argon2id Hash',              'single_factor',   'password',      'AAL1',  'permitted',  '{ALL}',              'RFC_9106_NIST_800-63B_3.1.1',     'BAUTH_NATIVE — argon2 crate + ring', true),

-- TOTP / HOTP
('BAUTH_TOTP',               'TOTP — RFC 6238 (SHA1/256/512)',       'multi_factor',    'otp',           'AAL2',  'discouraged','{BIZ_N2_N5,SYS_N3}', 'RFC_6238',                          'BAUTH_NATIVE — ring::hmac', true),
('BAUTH_HOTP',               'HOTP — RFC 4226 (Counter-based)',      'multi_factor',    'otp',           'AAL2',  'permitted',  '{BIZ_N3_N5}',        'RFC_4226',                          'BAUTH_NATIVE — ring::hmac', true),

-- Recovery Codes
('BAUTH_RECOVERY',           'Recovery Codes SHA-256',                'recovery',        'recovery',      'AAL2',  'permitted',  '{SU,SYS,BIZ_N3_N5}', NULL,                                 'BAUTH_NATIVE — ring::digest', true),

-- Email OTP
('BAUTH_EMAIL_OTP',          'Email OTP — Single-Factor',             'single_factor',   'otp',           'AAL1',  'permitted',  '{EXT_N0}',           NULL,                                 'BAUTH_NATIVE — ring::digest + TTL 10min', true),

-- Push Notification
('BAUTH_PUSH',               'Push Challenge — Number Matching',      'multi_factor',    'out_of_band',   'AAL2',  'preferred',  '{BIZ_N1_N5}',        'NIST_800-63B_Rev4_3.1.3',          'BAUTH_NATIVE — ring::rand + nonce', true),

-- mTLS / X.509
('BAUTH_MTLS',               'mTLS / X.509 Certificate',              'phishing_resistant','cryptographic','AAL3','preferred',  '{M2M,SYS_N4,NEXUS}',  'RFC_8705',                          'BAUTH_NATIVE — ring constant-time + CN/fingerprint', true),

-- WebAuthn / FIDO2
('BAUTH_WEBAUTHN',           'WebAuthn/FIDO2 Passkey — Nativo',       'phishing_resistant','cryptographic','AAL3','preferred',  '{ALL}',               'W3C_WebAuthn_L2_FIDO2_CTAP_2.2',    'BAUTH_NATIVE — ring crypto + serde_json', true),

-- SAML 2.0
('BAUTH_SAML',               'SAML 2.0 — Nativo Rust',                'federated',       'federated',     'AAL2',  'permitted',  '{BIZ,EXT}',          'SAML_2_0_OASIS',                    'BAUTH_NATIVE — parser XML ligero', true),

-- QR Login
('BAUTH_QR_LOGIN',           'QR Físico — JWT Ed25519',               'single_factor',   'cryptographic', 'AAL1',  'permitted',  '{EXT_N0}',           'ISO_18004',                         'BAUTH_NATIVE — ed25519-dalek + QR encode', true),

-- OIDC Provider (nativo)
('BAUTH_OIDC',               'OIDC Provider Nativo',                  'federated',       'federated',     'AAL2',  'preferred',  '{ALL}',               'OIDC_Core_RFC_6749_RFC_7662',       'BAUTH_NATIVE — oidc_provider.rs', true),

-- Firma Digital Ed25519
('BAUTH_SIGN_ED25519',       'Firma Digital Ed25519',                  'cryptographic',   'cryptographic', 'AAL3',  'preferred',  '{SU,SYS,M2M}',        'FIPS_186-5_RFC_8032',               'BAUTH_NATIVE — ed25519-dalek', true),

-- Blockchain / Merkle
('BAUTH_MERKLE',             'Anclaje Merkle Blockchain',              'cryptographic',   'cryptographic', 'AAL3',  'preferred',  '{SU,SYS}',            'FIPS_202_Keccak-256',               'BAUTH_NATIVE — blockchain/anchor.rs + Besu QBFT', true)

ON CONFLICT (method_id) DO UPDATE SET
    method_name = EXCLUDED.method_name,
    method_type = EXCLUDED.method_type,
    category = EXCLUDED.category,
    aal_level = EXCLUDED.aal_level,
    nist_status = EXCLUDED.nist_status,
    applies_to = EXCLUDED.applies_to,
    rfc_ref = EXCLUDED.rfc_ref,
    kc_implementation = EXCLUDED.kc_implementation;

\echo '=== 13 métodos nativos insertados/actualizados (idempotente) ==='
