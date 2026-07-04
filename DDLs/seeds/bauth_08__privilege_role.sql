-- seed_privilege_role.sql — Roles de prueba para verificación BitMask
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

INSERT INTO bauth.privilege_role (role_id, tenant_id, role_code, role_name, role_slug, active)
VALUES
    ('00000000-0000-0000-0000-000000000101', '019f01e8-2e33-7734-a756-63d31a003a75', 101, 'Cajero de Prueba',      'test-cajero',       TRUE),
    ('00000000-0000-0000-0000-000000000102', '019f01e8-2e33-7734-a756-63d31a003a75', 102, 'Contador de Prueba',    'test-contador',      TRUE),
    ('00000000-0000-0000-0000-000000000103', '019f01e8-2e33-7734-a756-63d31a003a75', 103, 'Supervisor de Prueba',  'test-supervisor',    TRUE)
ON CONFLICT (role_id) DO NOTHING;
