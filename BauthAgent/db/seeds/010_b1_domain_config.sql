INSERT INTO bauth.bos_domain_config (tenant_id, domain_code, active, override_params) VALUES
    ('00000000-0000-0000-0000-000000000001', 1, true, NULL),
    ('00000000-0000-0000-0000-000000000001', 3, true, '{"single_limit_bob":5000,"daily_limit_bob":25000}'::jsonb),
    ('00000000-0000-0000-0000-000000000001', 4, false, NULL),
    ('00000000-0000-0000-0000-000000000001', 6, false, NULL),
    ('00000000-0000-0000-0000-000000000001', 7, false, NULL),
    ('00000000-0000-0000-0000-000000000001', 9, true, '{"min_password_length":12,"mfa_required":true}'::jsonb),
    ('00000000-0000-0000-0000-000000000001', 10, false, NULL)
ON CONFLICT DO NOTHING;
