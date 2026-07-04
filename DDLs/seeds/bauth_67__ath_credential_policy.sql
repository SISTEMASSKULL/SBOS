-- seed_ath_credential_policy.sql — Política de credenciales desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-63B-4 Final (2025) · OWASP ASVS V2
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_credential_policy RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_credential_policy;

INSERT INTO bauth.ath_credential_policy (policy_id, policy_code, policy_name, credential_type, min_strength_bits, requires_csprng, allow_diceware, rotate_by_time, ttl_max_days, rotate_on_compromise, rotate_on_event, requires_hibp_screening, max_failed_attempts, lockout_duration_minutes, history_retention_count, notify_on_change, is_active, ctx_id, created_at, updated_at) VALUES

(gen_random_uuid(), 'NIST-REV4-PASSWORD', 'NIST 800-63B Rev 4 Password Policy', 'PASSWORD', 112, true, true, false, 365, true, true, true, 5, 15, 24, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'NIST-REV4-TOTP', 'NIST 800-63B Rev 4 TOTP Policy', 'TOTP', 80, true, false, true, 90, true, false, false, 3, 30, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'NIST-REV4-WEBAUTHN', 'NIST 800-63B Rev 4 WebAuthn/Passkey Policy', 'WEBAUTHN', 128, true, false, true, 365, false, true, false, 3, 15, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'NIST-REV4-X509', 'NIST 800-63B Rev 4 X.509 Certificate Policy', 'X509_CERT', 256, true, false, true, 365, true, true, false, 3, 15, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'SBOS-OAUTH-SECRET', 'SBOS OAuth 2.1 Client Secret Policy', 'OAUTH_SECRET', 128, true, false, true, 90, true, true, false, 3, 15, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'SBOS-API-KEY', 'SBOS API Key Policy', 'API_KEY', 256, true, false, true, 90, true, true, false, 5, 15, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'SBOS-ENCRYPTION-KEY', 'SBOS Encryption Key Policy', 'ENCRYPTION_KEY', 256, true, false, true, 365, true, true, false, 3, 15, 0, true, true, 'seed-library', now(), now()),

(gen_random_uuid(), 'SBOS-SIGNING-KEY', 'SBOS Signing Key Policy', 'SIGNING_KEY', 256, true, false, true, 365, true, true, false, 3, 15, 0, true, true, 'seed-library', now(), now());
