-- seed_idn_role_d9.sql — Templates de rol D9 Credenciales
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-63B-4 AAL1-3 · FIDO2 Level 3
-- ═══════════════════════════════════════════════════════════════
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_role_d9 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_role_d9;

INSERT INTO bauth.idn_role_d9 (role_code, role_name, config, description) VALUES

('AAL1_BASICO', '{"es":"AAL1 — Autenticación Básica","en":"AAL1 — Basic Authentication"}',
 '{"credential_policy":{"min_aal":"AAL1","mfa_required":false,"phishing_resistance":{"required":false},"password_policy":{"min_length":12,"no_complexity_rules":true,"no_periodic_rotation":true,"hibp_check":true},"session_timeout_secs":28800,"applied_policies":["PWD_MIN_LENGTH_12","PWD_NO_COMPLEXITY","PWD_NO_ROTATION","PWD_HIBP_CHECK","PWD_ARGON2ID","SESSION_TIMEOUT_8H"]}}',
 'Nivel básico. Solo password con verificación HIBP. Sin MFA. Para roles de consulta o visitantes.'),

('AAL2_MFA', '{"es":"AAL2 — MFA Obligatorio","en":"AAL2 — MFA Required"}',
 '{"credential_policy":{"min_aal":"AAL2","mfa_required":true,"phishing_resistance":{"required":true,"allowed_methods":["WEBAUTHN_PWDLESS","WEBAUTHN_2FA"],"syncable_passkeys":{"allowed":true,"max_aal":"AAL2"}},"password_policy":{"min_length":12,"no_complexity_rules":true,"no_periodic_rotation":true,"hibp_check":true},"session_timeout_secs":28800,"recovery_policy":{"methods":["EMAIL_OTP","BACKUP_CODES"],"requires_mfa":true},"lockout_policy":{"type":"PROGRESSIVE"},"applied_policies":["PWD_MIN_LENGTH_12","PWD_NO_COMPLEXITY","PWD_NO_ROTATION","PWD_HIBP_CHECK","PWD_ARGON2ID","MFA_AAL2_REQUIRED","PR_PHISH_FIDO2","LOCKOUT_PROGRESSIVE","RECOVERY_MFA","SESSION_TIMEOUT_8H"]}}',
 'Nivel estándar para empleados. Password + TOTP o WebAuthn. Phishing-resistant ofrecido. MFA obligatorio.'),

('AAL3_HARDWARE', '{"es":"AAL3 — Hardware Device-Bound","en":"AAL3 — Hardware Device-Bound"}',
 '{"credential_policy":{"min_aal":"AAL3","mfa_required":true,"phishing_resistance":{"required":true,"allowed_methods":["PASSKEY_DEVICE","SMARTCARD_X509"],"syncable_passkeys":{"allowed":false},"device_bound_keys":{"required_for_aal3":true}},"password_policy":{"min_length":15,"no_complexity_rules":true,"no_periodic_rotation":true,"hibp_check":true,"history_check_count":10},"session_timeout_secs":14400,"recovery_policy":{"methods":["HARDWARE_TOKEN"],"requires_mfa":true},"lockout_policy":{"type":"PROGRESSIVE"},"applied_policies":["PWD_MIN_LENGTH_12","PWD_ARGON2ID","MFA_AAL3_HARDWARE","PR_PHISH_FIDO2","LOCKOUT_PROGRESSIVE","SESSION_TIMEOUT_8H","SESSION_CONCURRENT_1"]}}',
 'Nivel máximo para administradores y operaciones críticas. Passkey device-bound FIPS 140-3 + TOTP. Syncable passkeys PROHIBIDOS. Sesión 4h máximo.'),

('M2M_MTLS', '{"es":"M2M — mTLS Client Credentials","en":"M2M — mTLS Client Credentials"}',
 '{"credential_policy":{"min_aal":"M2M","mfa_required":false,"methods":{"required":{"m2m_service_account":[{"methodId":"OAUTH_M2M","order":1,"required":true}]}},"phishing_resistance":{"required":false},"session_timeout_secs":86400,"credential_rotation":{"enabled":true,"rotation_days":90,"auto_rotate_service_accounts":true},"applied_policies":["SESSION_TIMEOUT_8H"]}}',
 'Service accounts y daemons. OAuth 2.1 Client Credentials + PKCE. Rotación automática cada 90 días.'),

('EXTERNO_CLIENTE', '{"es":"Externo — Cliente/Visitante","en":"External — Client/Visitor"}',
 '{"credential_policy":{"min_aal":"AAL1","mfa_required":false,"phishing_resistance":{"required":false},"password_policy":{"min_length":12,"no_complexity_rules":true,"no_periodic_rotation":true,"hibp_check":true},"session_timeout_secs":3600,"applied_policies":["PWD_MIN_LENGTH_12","PWD_NO_COMPLEXITY","PWD_NO_ROTATION","PWD_HIBP_CHECK","PWD_ARGON2ID"]}}',
 'Clientes externos y visitantes. Solo password con HIBP. Sin MFA. Sesión 1 hora máximo.');

-- SELECT role_code, role_name->>'es' AS name FROM bauth.idn_role_d9 ORDER BY role_code;
