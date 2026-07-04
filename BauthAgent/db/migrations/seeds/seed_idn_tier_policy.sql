-- seed_idn_tier_policy.sql — Políticas por tier (NIST 800-63B-4)
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Schema real: tier TEXT PK, tier_name, loa_default, mfa_default, mfa_methods,
--   session_timeout_secs, max_sessions, audit_default, step_up_allowed,
--   delegation_allowed, description, nist_aal_ref
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_tier_policy RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_tier_policy;

INSERT INTO bauth.idn_tier_policy (tier, tier_name, loa_default, mfa_default, mfa_methods, session_timeout_secs, max_sessions, audit_default, step_up_allowed, delegation_allowed, nist_aal_ref) VALUES
('SU',        'Superusuario PAM',         3, TRUE,  '{FIDO2,WebAuthn}',               14400, 0, 'full',   TRUE,  FALSE, 'AAL3'),
('BIZ_N1',    'Admin Plataforma',         3, TRUE,  '{FIDO2,WebAuthn,TOTP}',           28800, 0, 'full',   TRUE,  TRUE,  'AAL3'),
('BIZ_N2',    'Dirección',                2, TRUE,  '{WebAuthn,TOTP}',                 28800, 3, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N3',    'Gerencia / Supervisión',   2, TRUE,  '{TOTP,WebAuthn}',                 28800, 3, 'basic',  TRUE,  TRUE,  'AAL2'),
('BIZ_N4',    'Operativo Calificado',     2, TRUE,  '{TOTP}',                          28800, 3, 'basic',  FALSE, FALSE, 'AAL2'),
('BIZ_N5',    'Operativo / Soporte',      2, TRUE,  '{TOTP}',                          28800, 2, 'basic',  FALSE, FALSE, 'AAL2'),
('EXT_N0',    'Cliente Externo',          1, FALSE, '{Password,Social}',               14400, 5, 'none',   FALSE, FALSE, 'AAL1'),
('M2M',       'Service Accounts',         0, FALSE, '{ClientCredentials,mTLS}',         86400, 0, 'full',   FALSE, TRUE,  'M2M'),
('VISITANTE', 'Visitante Temporal',       1, FALSE, '{EmailOTP}',                      3600,  1, 'basic',  FALSE, FALSE, 'AAL1');

-- SELECT count(*) FROM bauth.idn_tier_policy; -- debe ser 9
