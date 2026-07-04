-- seed_idn_role_closure.sql — Herencia DAG para verificación BitMask
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- FK → idn_role_template(id). Usa templates existentes del tenant.
-- ROL-ORG-CFO(N2) → ROL-ORG-COO(N1) → ROL-ORG-CEO(N0)
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

INSERT INTO bauth.idn_role_closure (ancestro_id, descendiente_id, profundidad, ctx_id)
VALUES
    -- Auto-referencias (profundidad=0)
    ('ROL-ORG-CEO', 'ROL-ORG-CEO', 0, 'seed'),
    ('ROL-ORG-COO', 'ROL-ORG-COO', 0, 'seed'),
    ('ROL-ORG-CFO', 'ROL-ORG-CFO', 0, 'seed'),
    -- COO → CEO (profundidad=1)
    ('ROL-ORG-COO', 'ROL-ORG-CEO', 1, 'seed'),
    -- CFO → COO (profundidad=1)
    ('ROL-ORG-CFO', 'ROL-ORG-COO', 1, 'seed'),
    -- CFO → CEO (profundidad=2, transitiva)
    ('ROL-ORG-CFO', 'ROL-ORG-CEO', 2, 'seed')
ON CONFLICT (ancestro_id, descendiente_id) DO NOTHING;
