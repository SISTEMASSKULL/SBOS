-- seed_fin_limit.sql — Límites financieros por rol (D3 Policy-Path)
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- Estándar: COSO · SOX §404 · NIST SP 800-53 AC-5
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

-- Límites para Cajero (101): montos bajos, sin dual-approval automático
INSERT INTO bauth.fin_limit (limit_id, tenant_id, role_id, transaction_type_id, currency_code, limits_config, accumulators, exceed_action, is_active, ctx_id)
VALUES (
    '00000000-0000-0000-0000-000000000201',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '00000000-0000-0000-0000-000000000101',
    '019f01e8-330b-7d5b-a71c-acabef3e018f', -- FAC_EMITIR
    'BOB',
    '{"per_operation":5000,"daily":50000,"monthly":500000,"yearly":6000000}',
    '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
    'BLOCK',
    TRUE,
    'seed'
) ON CONFLICT (limit_id) DO NOTHING;

-- Límites para Contador (102): montos medios, requiere aprobación al exceder
INSERT INTO bauth.fin_limit (limit_id, tenant_id, role_id, transaction_type_id, currency_code, limits_config, accumulators, exceed_action, exceed_approver_1, is_active, ctx_id)
VALUES (
    '00000000-0000-0000-0000-000000000202',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '00000000-0000-0000-0000-000000000102',
    '019f01e8-330b-7d5b-a71c-acabef3e018f', -- FAC_EMITIR
    'BOB',
    '{"per_operation":50000,"daily":500000,"monthly":5000000,"yearly":50000000}',
    '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
    'REQUIRE_APPROVAL',
    '00000000-0000-0000-0000-000000000103', -- Supervisor (103) como aprobador
    TRUE,
    'seed'
) ON CONFLICT (limit_id) DO NOTHING;

-- Límites para Supervisor (103): montos altos, aprueba compras mayores
INSERT INTO bauth.fin_limit (limit_id, tenant_id, role_id, transaction_type_id, currency_code, limits_config, accumulators, exceed_action, is_active, ctx_id)
VALUES (
    '00000000-0000-0000-0000-000000000203',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '00000000-0000-0000-0000-000000000103',
    '019f01e8-330b-7d5b-a71c-acabef3e018f', -- FAC_EMITIR
    'BOB',
    '{"per_operation":500000,"daily":5000000,"monthly":50000000,"yearly":500000000}',
    '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
    'BLOCK',
    TRUE,
    'seed'
) ON CONFLICT (limit_id) DO NOTHING;

-- Límite Contador para Aprobar Pago (requiere comité)
INSERT INTO bauth.fin_limit (limit_id, tenant_id, role_id, transaction_type_id, currency_code, limits_config, accumulators, exceed_action, exceed_approver_1, is_active, ctx_id)
VALUES (
    '00000000-0000-0000-0000-000000000204',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '00000000-0000-0000-0000-000000000102',
    '019f01e8-330c-7641-a731-b60ce7c256b5', -- PAGO_APROBAR
    'BOB',
    '{"per_operation":100000,"daily":1000000,"monthly":10000000}',
    '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
    'REQUIRE_APPROVAL',
    '00000000-0000-0000-0000-000000000103', -- Supervisor debe aprobar
    TRUE,
    'seed'
) ON CONFLICT (limit_id) DO NOTHING;
