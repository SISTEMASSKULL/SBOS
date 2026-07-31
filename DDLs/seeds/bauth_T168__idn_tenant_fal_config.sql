-- bauth_T168__idn_tenant_fal_config.sql — Seed generado de VPS SBOSDB
-- Filas: 1 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.idn_tenant_fal_config VALUES ('019faa0a-1730-7796-9b11-2b5b4b5dcdf3', '019f8ae0-4282-731e-8d71-c42029fded2f', 'bauth-internal-default', '{"en": "Default FAL1 configuration (SKULL)", "es": "Configuración FAL1 por defecto (SKULL)"}', 'Configuración base FAL1 para el tenant SKULL. PKCE obligatorio. Sin DPoP/mTLS (FAL1).', 'FAL1', '{OIDC}', true, false, false, 3600, 86400, 30, '{}', NULL, false, NULL, true, 'system', '2026-07-28 18:43:35.854294+00', '2026-07-28 18:43:35.854294+00') ON CONFLICT DO NOTHING;

SELECT 'T168__idn_tenant_fal_config: ' || 1 || ' filas' AS resultado;
