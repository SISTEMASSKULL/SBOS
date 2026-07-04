-- ============================================================
-- SEED 051: Políticas por tier
-- Tabla: bos_tier_policy (NIST 800-63B-4 AAL)
-- IDEMPOTENTE: ON CONFLICT (tier) DO NOTHING
-- ============================================================

INSERT INTO bauth.bos_tier_policy (tier, tier_name, loa_default, mfa_default, mfa_methods, session_timeout_secs, max_sessions, audit_default, step_up_allowed, delegation_allowed, nist_aal_ref) VALUES
('SU',        'Superusuario PAM',        3, TRUE,  '{FIDO2,WebAuthn}',               14400,  0, 'full',   TRUE,  FALSE, 'AAL3'),
('SYS',       'Administrador de Sistema', 2, TRUE,  '{TOTP,FIDO2,WebAuthn}',          28800,  3, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N5',    'Dirección General',        2, TRUE,  '{TOTP,WebAuthn_2FA}',            28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N4',    'Gerencia',                 2, TRUE,  '{TOTP,WebAuthn_2FA}',            28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N3',    'Supervisión',              2, TRUE,  '{TOTP}',                         28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N2',    'Operativo Calificado',     1, FALSE, '{TOTP}',                         28800,  1, 'basic',  TRUE,  FALSE, 'AAL1-AAL2'),
('BIZ_N1',    'Operativo Estándar',       1, FALSE, '{TOTP}',                         28800,  1, 'basic',  FALSE, FALSE, 'AAL1'),
('EXT_N0',    'Externo / Cliente',        1, FALSE, '{Passkey,Email_OTP}',            86400,  1, 'none',   FALSE, FALSE, 'AAL1'),
('M2M',       'Machine-to-Machine',       0, FALSE, '{mTLS}',                          86400, 10, 'basic',  FALSE, FALSE, 'n/a'),
('VISITANTE', 'Visitante Temporal',       1, FALSE, '{Email_OTP}',                    3600,   1, 'basic',  FALSE, FALSE, 'AAL1')
ON CONFLICT (tier) DO NOTHING;

-- ============================================================
