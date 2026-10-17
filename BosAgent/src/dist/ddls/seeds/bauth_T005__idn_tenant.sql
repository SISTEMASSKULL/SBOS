-- bauth_T005__idn_tenant.sql — Seed generado de VPS SBOSDB
-- Filas: 2 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.idn_tenant VALUES ('019f8ae0-4282-731e-8d71-c42029fded2f', 'skull', 'Sistemas SKULL', 'HIGH_SENSITIVITY', true, 'ACTIVE', 'COMPLETED', NULL, NULL, NULL, NULL, '2026-08-21 17:29:40.734337+00', 'Sistemas SKULL S.R.L.', '1234567890', NULL, 'BO', NULL, NULL, 'admin@sksistemas.com', 2555, NULL, NULL, 'secret/bauth/skull', 'SCHEMA_PER_TENANT', false, 'length(12)_argon2id_t3_m64', 28800, 3600, 100, '{}', 'ENTERPRISE', 'ACTIVE', 'full', '{email}', NULL, '{}', '{}', '2026-07-22 17:29:40.734337+00', '2026-07-22 17:29:40.734337+00') ON CONFLICT DO NOTHING;
INSERT INTO bauth.idn_tenant_fal_config VALUES ('019faa0a-1730-7796-9b11-2b5b4b5dcdf3', '019f8ae0-4282-731e-8d71-c42029fded2f', 'bauth-internal-default', '{"en": "Default FAL1 configuration (SKULL)", "es": "Configuración FAL1 por defecto (SKULL)"}', 'Configuración base FAL1 para el tenant SKULL. PKCE obligatorio. Sin DPoP/mTLS (FAL1).', 'FAL1', '{OIDC}', true, false, false, 3600, 86400, 30, '{}', NULL, false, NULL, true, 'system', '2026-07-28 18:43:35.854294+00', '2026-07-28 18:43:35.854294+00') ON CONFLICT DO NOTHING;

SELECT 'T005__idn_tenant: ' || 2 || ' filas' AS resultado;
