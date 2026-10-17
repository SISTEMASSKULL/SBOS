-- bos_T399__ctx_context_policy.sql — Seed generado de VPS SBOSDB
-- Filas: 1 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bos.ctx_context_policy VALUES ('019fb4f8-abe0-7a9f-8fb8-fe681368a7a5', '019f8ae0-4282-731e-8d71-c42029fded2f', 28800, 43200, 30, 50, 5000, 500, false, false, '2026-07-30 21:40:23.633551+00', '2026-07-30 21:40:23.633551+00', 'system') ON CONFLICT DO NOTHING;

SELECT 'T399__ctx_context_policy: ' || 1 || ' filas' AS resultado;
