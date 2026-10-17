-- bauth_T156__idn_identity_entity.sql — Seed generado de VPS SBOSDB
-- Filas: 1 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.idn_identity_entity VALUES ('019faa08-698e-79a8-a7ad-f474e7e8b41c', '019f8ae0-4282-731e-8d71-c42029fded2f', NULL, 'actor', 'BAUTH_SYSTEM', '{"en": "bAuth System (internal actor)", "es": "Sistema bAuth (actor interno)"}', NULL, 0, NULL, 'IAL1', 'ACTIVE', '{}', 'system', '2026-07-28 18:41:45.869203+00', '2026-07-28 18:41:45.869203+00') ON CONFLICT DO NOTHING;

SELECT 'T156__idn_identity_entity: ' || 1 || ' filas' AS resultado;
