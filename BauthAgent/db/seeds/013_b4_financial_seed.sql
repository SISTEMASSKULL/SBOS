-- B4: Límites financieros para roles de prueba

INSERT INTO bauth.bos_financial_limit (role_id, tenant_id, max_transaction, max_daily, max_monthly, currency) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'skull-test', 10000.00, 50000.00, 200000.00, 'BOB'),
    ('a0000000-0000-0000-0000-000000000002', 'skull-test', 25000.00, 100000.00, 500000.00, 'BOB'),
    ('a0000000-0000-0000-0000-000000000003', 'skull-test', 100000.00, 500000.00, 2000000.00, 'BOB');

INSERT INTO bauth.bos_financial_decision_matrix (role_slug, requires_dual_approval_above, sod_profile, timeout_minutes) VALUES
    ('cajero', 5000.00, 'STANDARD', 30),
    ('cajero_senior', 10000.00, 'SENIOR', 30),
    ('supervisor', 50000.00, 'SUPERVISOR', 15);

SELECT 'Limites:' || count(*) FROM bauth.bos_financial_limit;
SELECT 'Decision:' || count(*) FROM bauth.bos_financial_decision_matrix;
