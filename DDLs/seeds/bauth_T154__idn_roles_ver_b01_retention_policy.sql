-- bauth_T154__idn_roles_ver_b01_retention_policy.sql — Seed generado de VPS SBOSDB
-- Filas: 1 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.idn_roles_ver_b01_retention_policy VALUES ('019f9609-550a-7133-876b-5b6d081a9efe', 'idn_roles_rol_hierarchical', 'C1', '2 years', 'KEEP_ANCHORS', '10 years', 'Ley 843 Bolivia Art. 44 · ISO 27001 A.5.33 · NIST AU-11 · PCI DSS Req 10.5', '{Ley-843-Art44,A.5.33,AU-11,PCI-DSS-10.5,SOX-404}', false, 'bootstrap', '2026-07-24 21:30:21.833764+00', '2026-07-24 21:30:21.833764+00') ON CONFLICT DO NOTHING;

SELECT 'T154__idn_roles_ver_b01_retention_policy: ' || 1 || ' filas' AS resultado;
