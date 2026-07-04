-- ================================================================
-- bAuth Authentication Framework — 7 Tablas Declarativas
-- Seed idempotente completo v1.0.0 — 2026-06-21
--
-- Estándares: ISO 24760:2025, NIST SP 800-63B Rev.4, NIST SP 800-207,
--              ISO 27001:2022, PCI DSS 4.0.1, OWASP ASVS 4.0.3,
--              FIDO2/WebAuthn L3, OAuth 2.1 BCP, RFC 9470
--
-- 7 tablas que modelan el framework completo de autenticación:
--   1. auth_method        — 15 métodos de autenticación
--   2. auth_policy        — políticas por tier
--   3. auth_config        — configuraciones del sistema
--   4. crypto_algorithm   — algoritmos criptográficos
--   5. federation_protocol — protocolos de federación
--   6. saga_catalog       — 12 sagas de autenticación (orquestación)
--   7. compliance_map     — mapeo a estándares internacionales
-- ================================================================

-- ═══════════════════════════════════════════════════════════════
-- TABLA 1: auth_method — 15 Métodos de Autenticación
-- ISO/IEC 24760-4:2025 · NIST SP 800-63B Rev.4
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.auth_method (
    method_id       TEXT PRIMARY KEY,                  -- ej: KC_TOTP, KC_WEBAUTHN_PASSWORDLESS
    method_name     TEXT NOT NULL,                     -- ej: Time-based One-Time Password
    method_type     TEXT NOT NULL                      -- single_factor | multi_factor | phishing_resistant | federated | machine | recovery | adaptive
                    CHECK (method_type IN ('single_factor','multi_factor','phishing_resistant','federated','machine','recovery','adaptive','deprecated')),
    category        TEXT NOT NULL                      -- password | otp | biometric | cryptographic | federated | device | recovery
                    CHECK (category IN ('password','otp','biometric','cryptographic','federated','device','recovery','adaptive','deprecated')),
    aal_level       TEXT NOT NULL                      -- AAL1 | AAL2 | AAL3 | AAL1-AAL2 | AAL2-AAL3 | n/a
                    CHECK (aal_level IN ('AAL1','AAL2','AAL3','AAL1-AAL2','AAL2-AAL3','n/a')),
    nist_status     TEXT NOT NULL DEFAULT 'permitted'
                    CHECK (nist_status IN ('preferred','permitted','discouraged','deprecated')),
    applies_to      TEXT[] NOT NULL DEFAULT '{}',      -- {SU, SYS, BIZ_N3_N5, BIZ_N1_N2, EXT_N0, M2M, VISITANTE}
    rfc_ref         TEXT,                              -- RFC 6238, RFC 9470, etc.
    kc_implementation TEXT,                            -- Cómo lo implementa Keycloak 26.6.2
    requires_https  BOOLEAN NOT NULL DEFAULT TRUE,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    config          JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.auth_method IS 'Catálogo de 15 métodos de autenticación soportados — ISO 24760-4:2025 §4, NIST 800-63B Rev.4 AAL';
COMMENT ON COLUMN bauth.auth_method.aal_level IS 'NIST Authentication Assurance Level: AAL1(single), AAL2(multi), AAL3(phishing-resistant hardware)';
COMMENT ON COLUMN bauth.auth_method.nist_status IS 'Estado según NIST 800-63B Rev.4: preferred > permitted > discouraged > deprecated';

-- ═══════════════════════════════════════════════════════════════
-- TABLA 2: auth_policy — Políticas de Autenticación por Tier
-- NIST SP 800-53 Rev.5 AC-2,5,6 · ISO 27001:2022 A.5.15-18
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.auth_policy (
    policy_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name     TEXT NOT NULL,
    policy_type     TEXT NOT NULL                      -- password | rate_limit | mfa | session | ip | time | geo | device | step_up
                    CHECK (policy_type IN ('password','rate_limit','mfa','session','ip','time','geo','device','step_up','break_glass','audit','lockout','delegation')),
    tier            TEXT NOT NULL                      -- SU | SYS | BIZ_N3_N5 | BIZ_N1_N2 | EXT_N0 | M2M | VISITANTE | ALL
                    CHECK (tier IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE','ALL')),
    policy_data     JSONB NOT NULL,                    -- parámetros específicos de la política
    priority        INTEGER NOT NULL DEFAULT 50,       -- 1-999 (menor = más prioritario)
    standard_ref    TEXT[] DEFAULT '{}',               -- {NIST 800-63B, ISO 27001:2022 A.8.5, PCI DSS 4.0 Req 8}
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (policy_name, tier)
);

COMMENT ON TABLE bauth.auth_policy IS 'Políticas de autenticación por tier — NIST 800-53 Rev.5 AC-2/5/6, ISO 27001:2022 A.5.15-18';

-- ═══════════════════════════════════════════════════════════════
-- TABLA 3: auth_config — Configuraciones del Sistema
-- Parámetros operativos que gobiernan el motor de autenticación
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.auth_config (
    config_key      TEXT NOT NULL,                  -- ej: token.access_ttl.SU
    config_value    JSONB NOT NULL,
    config_type     TEXT NOT NULL                      -- token | hash | rotation | session | rate | screen | enrollment
                    CHECK (config_type IN ('token','hash','rotation','session','rate','screen','enrollment','audit','recovery','lockout')),
    tier            TEXT NOT NULL DEFAULT 'ALL'
                    CHECK (tier IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE','ALL')),
    description     TEXT NOT NULL,
    standard_ref    TEXT[] DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.auth_config IS 'Configuraciones operativas del motor de autenticación — parámetros por tier';

-- ═══════════════════════════════════════════════════════════════
-- TABLA 4: crypto_algorithm — Algoritmos Criptográficos
-- NIST FIPS 140-3, 203, 204, 205 · ISO/IEC 15408
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.crypto_algorithm (
    algo_id         TEXT PRIMARY KEY,                  -- ej: argon2id, crystals-kyber-1024
    algo_name       TEXT NOT NULL,
    algo_type       TEXT NOT NULL                      -- hashing | key_exchange | digital_signature | encryption | key_derivation | random
                    CHECK (algo_type IN ('hashing','key_exchange','digital_signature','encryption','key_derivation','random')),
    category        TEXT NOT NULL                      -- classical | post_quantum | hybrid
                    CHECK (category IN ('classical','post_quantum','hybrid')),
    purpose         TEXT NOT NULL,                     -- para qué se usa en bAuth
    params          JSONB NOT NULL,                    -- parámetros específicos
    fips_status     TEXT,                              -- FIPS 140-3 certified | FIPS 203 | FIPS 204 | FIPS 205
    nist_pqc_round  TEXT,                              -- NIST PQC Standardization round
    standard_ref    TEXT[] DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    is_primary      BOOLEAN NOT NULL DEFAULT TRUE,     -- algoritmo principal vs fallback
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.crypto_algorithm IS 'Catálogo de algoritmos criptográficos — NIST FIPS 140-3/203/204/205, ISO/IEC 15408';

-- ═══════════════════════════════════════════════════════════════
-- TABLA 5: federation_protocol — Protocolos de Federación
-- NIST SP 800-63C-4 · OAuth 2.1 BCP · OIDC Core
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.federation_protocol (
    protocol_id     TEXT PRIMARY KEY,                  -- ej: oauth2_auth_code_pkce
    protocol_name   TEXT NOT NULL,
    protocol_type   TEXT NOT NULL                      -- authorization | authentication | federation | delegation | device | token_exchange
                    CHECK (protocol_type IN ('authorization','authentication','federation','delegation','device','token_exchange','deprecated')),
    rfc_ref         TEXT,
    flow            TEXT NOT NULL,                     -- authorization_code | client_credentials | device | hybrid | saml_post | token_exchange
    pkce_required   BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to      TEXT[] NOT NULL DEFAULT '{}',
    bAuth_status    TEXT NOT NULL DEFAULT 'enabled'    -- enabled | disabled_permanently | enabled_controlled | planned
                    CHECK (bAuth_status IN ('enabled','disabled_permanently','enabled_controlled','planned')),
    config          JSONB DEFAULT '{}'::jsonb,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.federation_protocol IS 'Protocolos de federación soportados — NIST SP 800-63C-4, OAuth 2.1 BCP';

-- ═══════════════════════════════════════════════════════════════
-- TABLA 6: saga_catalog — YA EXISTE (creada por 018_saga_catalog.sql)
-- 12 sagas, 74 pasos. Se preserva con CREATE TABLE IF NOT EXISTS.
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- TABLA 7: compliance_map — Mapeo a Estándares Internacionales
-- ISO 27001:2022 · NIST SP 800-53 · PCI DSS · GDPR · eIDAS
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.compliance_map (
    compliance_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    standard        TEXT NOT NULL,                     -- ISO_27001_2022 | NIST_800_53 | NIST_800_63B | PCI_DSS_4_0 | GDPR | eIDAS_2_0 | OWASP_ASVS | FIDO2
    control_id      TEXT NOT NULL,                     -- A.5.15 | AC-2 | Req 8.4.2 | Art.32
    control_name    TEXT NOT NULL,
    description     TEXT NOT NULL,
    applies_to      TEXT NOT NULL,                     -- qué componente de bAuth lo implementa
    implementation_status TEXT NOT NULL DEFAULT 'planned'
                    CHECK (implementation_status IN ('implemented','partial','planned','not_applicable')),
    evidence_ref    TEXT,                              -- referencia a código, tabla, o seed
    last_reviewed   TIMESTAMPTZ DEFAULT now(),
    UNIQUE (standard, control_id)
);

COMMENT ON TABLE bauth.compliance_map IS 'Mapeo de cumplimiento normativo — ISO 27001:2022, NIST, PCI DSS, GDPR, eIDAS 2.0, OWASP';

-- ================================================================
-- DATOS INICIALES IDEMPOTENTES
-- ================================================================

-- ─── 1. MÉTODOS DE AUTENTICACIÓN (15) ──────────────────────────
INSERT INTO bauth.auth_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, rfc_ref, kc_implementation, requires_https) VALUES
('KC_PASSWORD',              'Password / Standard Browser Flow',      'single_factor',   'password',     'AAL1',       'permitted',   '{EXT_N0,BIZ_N1_N2}',                            NULL,                     'Browser Flow + Authorization Code', true),
('KC_TOTP',                  'Time-based One-Time Password (TOTP)',   'multi_factor',    'otp',          'AAL2',       'discouraged', '{BIZ_N2_N5,SYS_N3}',                             'RFC_6238',               'OTP Policy → FreeOTP / Google Auth', true),
('KC_HOTP',                  'HMAC-based One-Time Password',          'multi_factor',    'otp',          'AAL2',       'permitted',   '{BIZ_N3_N5}',                                     'RFC_4226',               'OTP Policy → Hardware tokens (YubiKey)', true),
('KC_WEBAUTHN_PASSWORDLESS', 'WebAuthn/FIDO2 Passwordless',           'phishing_resistant','cryptographic','AAL3',     'preferred',   '{SU,SYS_N1_N2}',                                  'W3C_WebAuthn_L2',        'WebAuthn Policy → Platform + Roaming Auth', true),
('KC_WEBAUTHN_2FA',          'WebAuthn/FIDO2 as Second Factor',       'multi_factor',    'cryptographic', 'AAL2',      'preferred',   '{BIZ_N3_N5,SYS_N3}',                              'W3C_WebAuthn_L2',        'WebAuthn Policy → 2FA mode', true),
('KC_PASSKEY',               'Passkey (Synced WebAuthn)',             'multi_factor',    'cryptographic', 'AAL1-AAL2',  'preferred',   '{EXT_N0,BIZ_N1}',                                 'W3C_WebAuthn_L2',        'WebAuthn Policy → Passkey mode', true),
('KC_X509',                  'X.509 Certificate Authentication (mTLS)','phishing_resistant','cryptographic','AAL2-AAL3', 'preferred',   '{M2M,SYS_N4,NEXUS}',                              'RFC_8705',               'X.509 Authenticator → Client Cert via mTLS', true),
('KC_KERBEROS',              'Kerberos / SPNEGO',                     'single_factor',   'cryptographic', 'AAL1',      'discouraged', '{BIZ_N1_N2}',                                     'RFC_4120_RFC_4559',      'Kerberos Authenticator → LDAP/AD', true),
('KC_IDP_SOCIAL',            'Social Login / Identity Brokering',     'federated',       'federated',    'AAL1',       'permitted',   '{EXT_N0}',                                        NULL,                     'Identity Provider → OIDC', true),
('KC_IDP_SAML',              'SAML 2.0 Identity Brokering',           'federated',       'federated',    'AAL1-AAL2',  'permitted',   '{BIZ,EXT}',                                       'SAML_2_0',               'SAML Identity Provider → Enterprise SSO', true),
('KC_CIBA',                  'Client Initiated Backchannel Auth',     'adaptive',        'device',       'AAL1-AAL2',  'permitted',   '{EXT_N0,BIZ_N1}',                                 'OpenID_CIBA_Core',       'CIBA Grant Type → Push notification', true),
('KC_DEVICE_AUTH',           'OAuth 2.0 Device Authorization Grant',  'device',          'device',       'AAL1',       'permitted',   '{EXT_N0,M2M_IoT}',                                'RFC_8628',               'Device Authorization Grant → TV/IoT/CLI', true),
('KC_CONDITIONAL_OTP',       'Conditional OTP / Adaptive MFA',        'adaptive',        'adaptive',     'AAL2',       'preferred',   '{BIZ_N1_N5}',                                     NULL,                     'Authentication Flow → Condition → OTP', true),
('KC_RECOVERY',              'Recovery Codes / Backup Codes',         'recovery',        'recovery',     'AAL2',       'permitted',   '{SU,SYS,BIZ_N3_N5}',                              NULL,                     'Recovery Codes Authenticator (SHA256)', true),
('KC_EMAIL_OTP',             'Email OTP / Magic Link',                'single_factor',   'otp',          'AAL1',       'permitted',   '{EXT_N0}',                                        NULL,                     'Email OTP Authenticator', true)
ON CONFLICT (method_id) DO UPDATE SET method_name = EXCLUDED.method_name, nist_status = EXCLUDED.nist_status;

-- ─── 2. POLÍTICAS DE AUTENTICACIÓN (por tier) ──────────────────
INSERT INTO bauth.auth_policy (policy_name, policy_type, tier, policy_data, priority, standard_ref) VALUES
-- Password policies per tier
('password.min_length',         'password',   'SU',           '{"min_length":20,"recommended":32,"max_length":128}',                                        10, '{NIST_800-63B_Rev4_§5.1.1}'),
('password.min_length',         'password',   'SYS',          '{"min_length":15,"recommended":24,"max_length":128}',                                        10, '{NIST_800-63B_Rev4_§5.1.1}'),
('password.min_length',         'password',   'BIZ_N3_N5',    '{"min_length":12,"recommended":20,"max_length":64}',                                         10, '{NIST_800-63B_Rev4_§5.1.1}'),
('password.min_length',         'password',   'BIZ_N1_N2',    '{"min_length":10,"recommended":15,"max_length":64}',                                         10, '{NIST_800-63B_Rev4_§5.1.1}'),
('password.min_length',         'password',   'EXT_N0',       '{"min_length":8,"recommended":12,"max_length":64}',                                          10, '{NIST_800-63B_Rev4_§5.1.1}'),
('password.no_composition',     'password',   'ALL',          '{"enabled":true,"reason":"NIST_800-63B_Rev4_prohibe_reglas_de_composicion"}',               15, '{NIST_800-63B_Rev4_§5.1.1.2}'),
('password.no_periodic_rotation','password',  'ALL',          '{"enabled":true,"rotation":"on_compromise_only","reason":"NIST_800-63B_Rev4"}',             15, '{NIST_800-63B_Rev4_§5.1.1.2}'),
('password.screening_hibp',     'password',   'ALL',          '{"enabled":true,"method":"k_anonymity","url":"api.pwnedpasswords.com","reject_on_match":true}',5, '{NIST_800-63B_Rev4_§5.1.1.2}'),

-- Rate limiting per tier
('rate_limit.auth_attempts',    'rate_limit', 'SU',           '{"requests_per_second":null,"burst":null,"comment":"unlimited"}',                           20, '{OWASP_ASVS_2.2.1,PCI_DSS_4.0_Req8}'),
('rate_limit.auth_attempts',    'rate_limit', 'SYS',          '{"requests_per_second":1000,"burst":50,"window_seconds":60}',                              20, '{OWASP_ASVS_2.2.1,PCI_DSS_4.0_Req8}'),
('rate_limit.auth_attempts',    'rate_limit', 'BIZ_N3_N5',    '{"requests_per_second":100,"burst":20,"window_seconds":60}',                               20, '{OWASP_ASVS_2.2.1,PCI_DSS_4.0_Req8}'),
('rate_limit.auth_attempts',    'rate_limit', 'BIZ_N1_N2',    '{"requests_per_second":50,"burst":10,"window_seconds":60}',                                20, '{OWASP_ASVS_2.2.1,PCI_DSS_4.0_Req8}'),
('rate_limit.auth_attempts',    'rate_limit', 'EXT_N0',       '{"requests_per_second":10,"burst":5,"window_seconds":60}',                                 20, '{OWASP_ASVS_2.2.1,PCI_DSS_4.0_Req8}'),

-- MFA policies per tier
('mfa.required',                'mfa',        'SU',           '{"required":true,"methods":["KC_WEBAUTHN_PASSWORDLESS","KC_X509"],"count":1}',             15, '{NIST_800-63B_Rev4_AAL3,PCI_DSS_4.0_Req8.4.2}'),
('mfa.required',                'mfa',        'SYS',          '{"required":true,"methods":["KC_WEBAUTHN_PASSWORDLESS","KC_X509","KC_TOTP"],"count":1}',  15, '{NIST_800-63B_Rev4_AAL2-AAL3,PCI_DSS_4.0_Req8.4.2}'),
('mfa.required',                'mfa',        'BIZ_N3_N5',    '{"required":true,"methods":["KC_TOTP","KC_WEBAUTHN_2FA"],"count":1}',                      15, '{NIST_800-63B_Rev4_AAL2}'),
('mfa.required',                'mfa',        'BIZ_N1_N2',    '{"required":false,"recommended":true,"methods":["KC_TOTP","KC_PASSKEY"],"count":0}',       15, '{NIST_800-63B_Rev4_AAL1-AAL2}'),
('mfa.required',                'mfa',        'EXT_N0',       '{"required":false,"recommended":false,"methods":["KC_PASSKEY","KC_EMAIL_OTP"],"count":0}',  15, '{NIST_800-63B_Rev4_AAL1}'),

-- Session policies
('session.max_duration',        'session',    'SU',           '{"max_hours":4,"recording":true,"step_up_required":true}',                                30, '{ISO_27001_2022_A.8.2,NIST_800-207}'),
('session.max_duration',        'session',    'SYS',          '{"max_hours":12,"recording":false}',                                                       30, '{ISO_27001_2022_A.8.5}'),
('session.max_duration',        'session',    'BIZ_N3_N5',    '{"max_hours":8,"inactivity_timeout_min":30}',                                              30, '{ISO_27001_2022_A.8.5}'),

-- Lockout policy
('lockout.progressive',         'lockout',    'ALL',          '{"attempts":[5,10,20],"windows_minutes":[5,15,60],"lock_duration_minutes":[5,15,60]}',    10, '{OWASP_ASVS_2.2.3,NIST_800-63B_Rev4}')
ON CONFLICT (policy_name, tier) DO UPDATE SET policy_data = EXCLUDED.policy_data, priority = EXCLUDED.priority;

-- ─── 3. CONFIGURACIONES ─────────────────────────────────────────
INSERT INTO bauth.auth_config (config_key, config_value, config_type, tier, description, standard_ref) VALUES
-- Token lifetimes
('token.access_ttl_minutes',    '{"value":5}',                      'token',    'SU',           'Access token TTL 5min — JIT only, no refresh',           '{NIST_800-63B_Rev4,OAuth_2.1_BCP}'),
('token.access_ttl_minutes',    '{"value":15}',                     'token',    'SYS',          'Access token TTL 15min — refresh 4h',                     '{NIST_800-63B_Rev4,OAuth_2.1_BCP}'),
('token.access_ttl_minutes',    '{"value":30}',                     'token',    'BIZ_N3_N5',    'Access token TTL 30min — refresh 8h',                     '{NIST_800-63B_Rev4}'),
('token.access_ttl_minutes',    '{"value":60}',                     'token',    'BIZ_N1_N2',    'Access token TTL 60min — refresh 30 days',                '{NIST_800-63B_Rev4}'),
('token.access_ttl_hours',      '{"value":24}',                     'token',    'EXT_N0',       'Access token TTL 24h — refresh 90 days',                  '{NIST_800-63B_Rev4}'),
('token.access_ttl_minutes',    '{"value":15}',                     'token',    'M2M',          'Access token TTL 15min — client_credentials only',        '{RFC_6749_§4.4,RFC_7523}'),
-- Hash params
('hash.argon2id.params',        '{"t":5,"m_mb":128,"p":2}',         'hash',     'SU',           'Argon2id — 5 iteraciones, 128MB, 2 hilos',                '{NIST_800-63B_Rev4_§5.1.1.2}'),
('hash.argon2id.params',        '{"t":3,"m_mb":64,"p":2}',          'hash',     'SYS',          'Argon2id — 3 iteraciones, 64MB, 2 hilos',                 '{NIST_800-63B_Rev4_§5.1.1.2}'),
('hash.argon2id.params',        '{"t":3,"m_mb":64,"p":2}',          'hash',     'BIZ_N3_N5',    'Argon2id — 3 iteraciones, 64MB, 2 hilos',                 '{NIST_800-63B_Rev4_§5.1.1.2}'),
('hash.argon2id.params',        '{"t":2,"m_mb":32,"p":1}',          'hash',     'BIZ_N1_N2',    'Argon2id — 2 iteraciones, 32MB, 1 hilo',                  '{NIST_800-63B_Rev4_§5.1.1.2}'),
('hash.argon2id.params',        '{"t":2,"m_mb":32,"p":1}',          'hash',     'EXT_N0',       'Argon2id — 2 iteraciones, 32MB, 1 hilo',                  '{NIST_800-63B_Rev4_§5.1.1.2}'),
-- Key rotation
('key.rotation',                '{"enabled":true,"strategy":"proactive","interval_hours":4,"min_interval_hours":1,"max_interval_hours":12}', 'rotation', 'ALL', 'Rotación proactiva de claves cada 4h con intervalo adaptativo', '{NIST_800-57,FIPS_140-3}'),
-- MFA enrollment
('mfa.enrollment',              '{"grace_period_days":7,"reset_requires_approval":true,"recovery_codes_count":10,"recovery_codes_single_use":true}', 'enrollment', 'ALL', 'Enrollment MFA con 7 días de gracia, recovery codes SHA256', '{NIST_800-63B_Rev4}')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, description = EXCLUDED.description;

-- ─── 4. ALGORITMOS CRIPTOGRÁFICOS ──────────────────────────────
INSERT INTO bauth.crypto_algorithm (algo_id, algo_name, algo_type, category, purpose, params, fips_status, nist_pqc_round, standard_ref, is_primary) VALUES
('argon2id',             'Argon2id',                  'hashing',          'classical',     'Password hashing (NIST SP 800-63B)',                                  '{"memory_kb":131072,"iterations":3,"parallelism":2,"salt_bytes":16,"hash_bytes":32}',              NULL,                 NULL,                 '{NIST_800-63B_Rev4,RFC_9106}',               TRUE),
('es256',                'ECDSA P-256 (ES256)',       'digital_signature','classical',     'JWT signing for access/refresh tokens',                                '{"curve":"P-256","key_bytes":32}',                                                                 'FIPS_140-3_certified',NULL,                 '{FIPS_186-5,RFC_7518}',                     TRUE),
('es384',                'ECDSA P-384 (ES384)',       'digital_signature','classical',     'JWT signing for M2M tokens',                                           '{"curve":"P-384","key_bytes":48}',                                                                 'FIPS_140-3_certified',NULL,                 '{FIPS_186-5,RFC_7518}',                     TRUE),
('aes_256_gcm',          'AES-256-GCM',               'encryption',       'classical',     'Encryption at rest (cache, offline creds, biometric templates)',       '{"key_bytes":32,"nonce_bytes":12,"tag_bytes":16}',                                                'FIPS_140-3_certified',NULL,                 '{FIPS_197,NIST_SP_800-38D}',                TRUE),
('sha256',               'SHA-256',                   'hashing',          'classical',     'Recovery codes hashing, Merkle tree leaves',                           '{"digest_bytes":32}',                                                                              'FIPS_140-3_certified',NULL,                 '{FIPS_180-4}',                              TRUE),
('sha3_256',             'SHA3-256 / Keccak-256',     'hashing',          'classical',     'Merkle tree for blockchain audit (D12)',                               '{"digest_bytes":32}',                                                                              'FIPS_202',            NULL,                 '{FIPS_202,NIST_SP_800-185}',                TRUE),
('hkdf_sha256',          'HKDF-SHA256',               'key_derivation',   'classical',     'Key derivation from master secrets',                                   '{"hash":"SHA-256","info":"bauth-v3.0","salt_bytes":32}',                                          'FIPS_140-3_certified',NULL,                 '{RFC_5869,NIST_SP_800-56C}',                TRUE),
('ed25519',              'Ed25519 (EdDSA)',            'digital_signature','classical',     'Release Plane signatures, firmware verification',                      '{"key_bytes":32}',                                                                                 'FIPS_186-5_compliant',NULL,                 '{FIPS_186-5,RFC_8032}',                     TRUE),
('crystals_kyber_1024',  'CRYSTALS-Kyber-1024',       'key_exchange',     'post_quantum',  'Post-quantum key exchange (NIST PQC standard)',                         '{"security_level":5,"failure_probability":"2^-174","key_bytes":1568,"ciphertext_bytes":1568}',     'FIPS_203',            'NIST_PQC_Final_2024','{FIPS_203,NIST_PQC}',                       TRUE),
('crystals_dilithium_5', 'CRYSTALS-Dilithium-5',      'digital_signature','post_quantum',  'Post-quantum digital signatures',                                      '{"security_level":3,"signature_bytes":2420,"public_key_bytes":1312}',                             'FIPS_204',            'NIST_PQC_Final_2024','{FIPS_204,NIST_PQC}',                       TRUE),
('sphincs_plus',         'SPHINCS+ SHA-256-256s',     'digital_signature','post_quantum',  'Stateless hash-based signatures (fallback)',                            '{"hash":"SHA-256","tree_height":64,"signature_bytes":17088}',                                     'FIPS_205',            'NIST_PQC_Final_2024','{FIPS_205,NIST_PQC}',                       FALSE),
('ntru_hps_4096',        'NTRU HPS-4096-821',         'key_exchange',     'post_quantum',  'Post-quantum key exchange (fallback to Kyber)',                         '{"security_level":5,"key_bytes":4096}',                                                            NULL,                  'NIST_PQC_Round_3',   '{NIST_PQC}',                                FALSE)
ON CONFLICT (algo_id) DO UPDATE SET params = EXCLUDED.params, fips_status = EXCLUDED.fips_status;

-- ─── 5. PROTOCOLOS DE FEDERACIÓN ─────────────────────────────────
INSERT INTO bauth.federation_protocol (protocol_id, protocol_name, protocol_type, rfc_ref, flow, pkce_required, applies_to, bAuth_status, config) VALUES
('oauth2_auth_code_pkce',    'OAuth 2.0 Authorization Code + PKCE',     'authorization',    'RFC_6749_RFC_7636',    'authorization_code',   TRUE,  '{SU,SYS,BIZ,EXT}',             'enabled',               '{"code_ttl_seconds":60,"max_code_uses":1,"token_lifetime_minutes":60}'),
('oauth2_client_credentials','OAuth 2.0 Client Credentials (M2M)',      'authorization',    'RFC_6749_§4.4',        'client_credentials',   FALSE, '{M2M,SYS_N4}',                 'enabled',               '{"access_token_ttl_minutes":15,"no_refresh_token":true,"jwt_assertion_preferred":true}'),
('oauth2_refresh_rotation',  'OAuth 2.0 Refresh Token Rotation',        'authorization',    'RFC_6749_§6',          'refresh_token',        FALSE, '{SU,SYS,BIZ,EXT}',             'enabled',               '{"rotation_on_every_use":true,"reuse_detection":"immediate_revocation","max_lifetime_days":90}'),
('oauth2_device_auth',       'OAuth 2.0 Device Authorization Grant',    'device',           'RFC_8628',             'device',               FALSE, '{EXT_N0,M2M_IoT}',             'enabled',               '{"device_code_ttl_seconds":600,"user_code_length":8,"polling_interval_seconds":5}'),
('oauth2_token_exchange',    'OAuth 2.0 Token Exchange (RFC 8693)',     'token_exchange',   'RFC_8693',             'token_exchange',       FALSE, '{SYS,BIZ_N3_N5}',              'enabled_controlled',    '{"max_impersonation_depth":2,"audience_restriction":"strict","audit_logging":"full"}'),
('oidc_auth_code',           'OpenID Connect Authorization Code Flow',  'authentication',   'OIDC_Core',            'authorization_code',   TRUE,  '{SU,SYS,BIZ,EXT}',             'enabled',               '{"nonce_required":true,"id_token_encryption":"optional"}'),
('saml2_web_sso',            'SAML 2.0 Web SSO',                        'federation',       'SAML_2_0',             'saml_post',            FALSE, '{BIZ,EXT}',                    'enabled',               '{"sign_assertions":true,"sign_metadata":true,"bindings":["HTTP-POST","HTTP-Redirect"]}'),
('mtls_rfc8705',             'mTLS OAuth 2.0 (RFC 8705)',               'authorization',    'RFC_8705',             'mtls',                 FALSE, '{M2M,SYS_N4,NEXUS}',           'enabled',               '{"cert_validation":"ocsp_stapling","key_usage":["clientAuth"]}'),
('dpop_rfc9449',             'DPoP (RFC 9449)',                         'authorization',    'RFC_9449',             'dpop',                 FALSE, '{SYS}',                         'planned',               '{"proof_required":true,"nonce_ttl_seconds":300}'),
('ciba',                     'Client Initiated Backchannel Auth (CIBA)','authentication',   'OpenID_CIBA_Core',     'ciba',                 FALSE, '{EXT_N0,BIZ_N1}',              'enabled',               '{"auth_req_id_ttl_seconds":300,"polling_interval_seconds":5}'),
('oauth2_ropc',              'Resource Owner Password Credentials',     'deprecated',       'RFC_6749_§4.3',        'password',             FALSE, '{}',                            'disabled_permanently',  '{"reason":"Deprecated_by_OAuth_2.1_BCP","replacement":"oauth2_auth_code_pkce"}'),
('oauth2_implicit',          'OAuth 2.0 Implicit Grant',                'deprecated',       'RFC_6749_§4.2',        'implicit',             FALSE, '{}',                            'disabled_permanently',  '{"reason":"Deprecated_by_OAuth_2.1_BCP_tokens_in_URL","replacement":"oauth2_auth_code_pkce"}')
ON CONFLICT (protocol_id) DO UPDATE SET bAuth_status = EXCLUDED.bAuth_status, config = EXCLUDED.config;

-- ─── 7. MAPEO DE CUMPLIMIENTO ───────────────────────────────────
INSERT INTO bauth.compliance_map (standard, control_id, control_name, description, applies_to, implementation_status, evidence_ref) VALUES
-- ISO 27001:2022
('ISO_27001_2022', 'A.5.15',  'Access Control Policy',            'Política de control de acceso documentada y revisada',                                  'auth_method + auth_policy',            'implemented', 'bauth.auth_policy, bauth.auth_method'),
('ISO_27001_2022', 'A.5.16',  'Identity Management',               'Gestión del ciclo de vida de identidades',                                              'auth_method + saga_catalog',            'partial',     'bauth.saga_catalog (S1,S6,S9,S10)'),
('ISO_27001_2022', 'A.5.17',  'Authentication Information',        'Gestión segura de información de autenticación',                                        'auth_method + crypto_algorithm',        'implemented', 'bauth.crypto_algorithm (argon2id)'),
('ISO_27001_2022', 'A.5.18',  'Access Rights',                     'Asignación, revisión y revocación de derechos de acceso',                                'auth_policy + saga_catalog',            'partial',     'bauth.auth_policy (mfa, session)'),
('ISO_27001_2022', 'A.8.2',   'Privileged Access Rights',          'Gestión de acceso privilegiado (PAM break-glass)',                                      'saga_catalog (S7) + auth_policy',       'partial',     'bauth.saga_catalog (auth.emergency.break_glass)'),
('ISO_27001_2022', 'A.8.5',   'Secure Authentication',             'Autenticación segura con MFA para acceso sensible',                                      'auth_method + auth_policy',             'implemented', 'bauth.auth_method (KC_WEBAUTHN, KC_TOTP)'),
('ISO_27001_2022', 'A.8.15',  'Logging and Monitoring',            'Registro de eventos de autenticación y autorización',                                    'saga_catalog + compliance_map',         'partial',     'bauth.saga_execution (audit trail)'),
-- NIST SP 800-53 Rev.5
('NIST_800_53_Rev5','AC-2',   'Account Management',                'Gestión de cuentas: creación, modificación, desactivación, revisión periódica',          'saga_catalog (S1,S9,S12)',              'partial',     'bauth.saga_catalog'),
('NIST_800_53_Rev5','AC-5',   'Separation of Duties',              'Separación de funciones: SoD estática y dinámica',                                       'auth_policy (SoD conflicts)',            'planned',     '—'),
('NIST_800_53_Rev5','AC-6',   'Least Privilege',                   'Mínimo privilegio: acceso limitado a lo necesario',                                      'auth_policy + saga_catalog',            'implemented', 'bauth.auth_policy (per-tier)'),
-- NIST SP 800-63B Rev.4
('NIST_800_63B_Rev4','AAL1',  'Authenticator Assurance Level 1',    'Single-factor authentication permitted',                                                 'auth_method (KC_PASSWORD, KC_PASSKEY)', 'implemented', 'bauth.auth_method'),
('NIST_800_63B_Rev4','AAL2',  'Authenticator Assurance Level 2',    'Multi-factor authentication required',                                                    'auth_method (KC_TOTP, KC_WEBAUTHN_2FA)','implemented', 'bauth.auth_method'),
('NIST_800_63B_Rev4','AAL3',  'Authenticator Assurance Level 3',    'Phishing-resistant hardware-backed authentication',                                       'auth_method (KC_WEBAUTHN_PASSWORDLESS)','implemented', 'bauth.auth_method'),
('NIST_800_63B_Rev4','§5.1.1','Password Policy',                    'No composition rules, no periodic rotation, screening HIBP, Argon2id',                   'auth_policy + crypto_algorithm',        'implemented', 'bauth.auth_policy (password.*)'),
-- NIST SP 800-207 Zero Trust
('NIST_800_207',    'ZTA-1',  'Continuous Verification',            'Verificación continua de identidad, dispositivo y contexto',                              'saga_catalog (S11) + auth_policy',       'partial',     'bauth.saga_catalog (auth.session.validate)'),
('NIST_800_207',    'ZTA-2',  'Per-Session Access',                 'Acceso otorgado por sesión, no permanente',                                               'auth_config (token.access_ttl)',         'implemented', 'bauth.auth_config'),
-- PCI DSS 4.0.1
('PCI_DSS_4.0.1',  'Req_8.2','Unique User IDs',                    'Identificadores únicos para cada usuario',                                                'auth_method',                            'implemented', 'bauth.auth_method'),
('PCI_DSS_4.0.1',  'Req_8.4.2','MFA for CDE Access',                'MFA obligatorio para TODO acceso al CDE',                                                 'auth_policy (mfa.required)',             'implemented', 'bauth.auth_policy'),
('PCI_DSS_4.0.1',  'Req_8.5.1','MFA System Integrity',              'No revelar qué factor falló, todos deben ser exitosos antes de otorgar acceso',           'saga_catalog (S1-S4)',                   'planned',     '—'),
-- GDPR
('GDPR',            'Art.32',  'Security of Processing',            'Medidas técnicas para proteger datos personales (cifrado, MFA, logs)',                    'auth_method + crypto_algorithm + saga',  'implemented', 'bauth.crypto_algorithm (AES-256-GCM)'),
('GDPR',            'Art.33',  'Breach Notification',               'Notificación de brechas en 72 horas',                                                      'saga_catalog (S7) + compliance_map',     'planned',     '—'),
-- OWASP ASVS 4.0.3
('OWASP_ASVS_4.0.3','V2.1.1', 'Password Length ≥ 12 chars',         'Mínimo 12 caracteres para passwords',                                                      'auth_policy (password.min_length)',      'implemented', 'bauth.auth_policy'),
('OWASP_ASVS_4.0.3','V2.1.7', 'Breached Password Check',            'Verificación contra listas de passwords vulneradas',                                       'auth_policy (password.screening_hibp)',  'partial',     'bauth.auth_policy'),
('OWASP_ASVS_4.0.3','V2.2.1', 'Anti-Automation / Rate Limiting',    'Rate limiting en endpoints de autenticación',                                              'auth_policy (rate_limit.*)',             'implemented', 'bauth.auth_policy')
ON CONFLICT (standard, control_id) DO UPDATE SET implementation_status = EXCLUDED.implementation_status, evidence_ref = EXCLUDED.evidence_ref;

-- ─── VERIFICACIÓN ──────────────────────────────────────────────
SELECT 'auth_method' as tabla, count(*)::text as registros FROM bauth.auth_method
UNION ALL SELECT 'auth_policy', count(*)::text FROM bauth.auth_policy
UNION ALL SELECT 'auth_config', count(*)::text FROM bauth.auth_config
UNION ALL SELECT 'crypto_algorithm', count(*)::text FROM bauth.crypto_algorithm
UNION ALL SELECT 'federation_protocol', count(*)::text FROM bauth.federation_protocol
UNION ALL SELECT 'saga_catalog', count(*)::text FROM bauth.saga_catalog
UNION ALL SELECT 'compliance_map', count(*)::text FROM bauth.compliance_map;
