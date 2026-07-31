-- bauth_T386__auth_compliance_map.sql — Seed generado de VPS SBOSDB
-- Filas: 14 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6517-761f-8b1e-3090858592af', 'NIST_SP_800_63B_4', '§5.1.1', 'Memorized Secret — Argon2id, mínimo 8 chars', '{PASSWORD}', '{PASSWORD_MFA,RECOVERY_FLOW}', 'FULL', 'Argon2id m=64MB t=3 p=4') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-77ae-8cc4-994044b5bd28', 'NIST_SP_800_63B_4', '§5.1.3', 'TOTP — TOTP (RFC 6238), ventana ±1 paso', '{TOTP}', '{PASSWORD_MFA}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7945-9fd8-1c29ede0b6b0', 'NIST_SP_800_63B_4', '§5.1.7', 'WebAuthn L3 — FIDO2 Passkey anti-phishing', '{WEBAUTHN_PASSWORDLESS,PASSKEY}', '{PASSWORDLESS_FIDO2}', 'FULL', 'W3C WebAuthn L3') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-79a7-bc81-074ec6560ac1', 'NIST_SP_800_63B_4', '§5.2.5', 'Step-Up Auth — RFC 9470 elevación temporal', '{WEBAUTHN_2FA,X509_MTLS}', '{STEP_UP_AAL2_AAL3}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-79eb-8256-f2f34bcb9284', 'NIST_SP_800_63B_4', '§7.2', 'Revocación en <30s — invalidación activa', '{PASSWORD,TOTP,WEBAUTHN_PASSWORDLESS,X509_MTLS}', '{RECOVERY_FLOW}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7a3c-ad57-f7853521cfdf', 'PCI_DSS_4_0', 'Req8.2.4', 'Lockout tras N fallos consecutivos', '{PASSWORD}', '{PASSWORD_MFA}', 'FULL', 'N configurable en T-337 auth.config') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7a7a-8ffb-980ee9a18e63', 'PCI_DSS_4_0', 'Req8.2.8', 'Log de todos los intentos de autenticación', '{PASSWORD,TOTP,WEBAUTHN_PASSWORDLESS}', '{PASSWORD_MFA,PASSWORDLESS_FIDO2}', 'FULL', 'T-334 auth_attempt_log WORM') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7ab8-8389-232087056d2f', 'PCI_DSS_4_0', 'Req8.4.2', 'MFA para acceso a CDE — AAL2 mínimo', '{TOTP,WEBAUTHN_2FA,PASSKEY}', '{PASSWORD_MFA,STEP_UP_AAL2_AAL3}', 'FULL', 'CDE = cardholder data environment') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7af3-98e3-6d61e275faec', 'OWASP_ASVS_5_0', '§2.1.1', 'Política de contraseña — min 12 chars, diceware', '{PASSWORD}', '{PASSWORD_MFA,RECOVERY_FLOW}', 'FULL', 'NIST SP 800-63B §5.1.1') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7b3c-9c47-0765555dc0ee', 'OWASP_ASVS_5_0', '§2.2.1', 'Anti-phishing — credenciales resistentes', '{WEBAUTHN_PASSWORDLESS,PASSKEY,X509_MTLS}', '{PASSWORDLESS_FIDO2,M2M_MTLS}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7b7b-9e3b-c803e9460f11', 'OWASP_ASVS_5_0', '§2.3.1', 'Cambio de credencial verificado — identity proof', '{PASSWORD}', '{RECOVERY_FLOW}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7bb8-8a0f-be538b703999', 'OWASP_ASVS_5_0', '§2.5.4', 'Recuperación segura — sin preguntas de seguridad', '{EMAIL_OTP,RECOVERY_CODES}', '{RECOVERY_FLOW}', 'FULL', 'T-322 idn_user_recovery') ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7c0f-8339-c507bbde7d62', 'ISO_27001_2022', 'A.8.2', 'Privileged access management — MFA obligatorio', '{WEBAUTHN_2FA,PASSKEY,X509_MTLS}', '{BREAKGLASS_EMERGENCY,STEP_UP_AAL2_AAL3}', 'FULL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_compliance_map VALUES ('019fb478-6519-7c47-bd9d-73c28d70df9c', 'FIPS_140_3', 'Level2', 'Módulo criptográfico — algoritmos APPROVED', '{X509_MTLS,WEBAUTHN_PASSWORDLESS}', '{M2M_MTLS,PASSWORDLESS_FIDO2}', 'FULL', 'AES-256-GCM, ED25519, ML-KEM-768') ON CONFLICT DO NOTHING;

SELECT 'T386__auth_compliance_map: ' || 14 || ' filas' AS resultado;
