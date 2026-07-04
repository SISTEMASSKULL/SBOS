-- B1.T09 Seed: Closure table para herencia DAG de roles

-- Jerarquía: Cajero → Cajero Senior → Supervisor
-- Cajero Senior hereda de Cajero
-- Supervisor hereda de Cajero Senior (y transitivamente de Cajero)

-- Self-references (profundidad 0)
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 0),
    ('a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 0),
    ('a0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003', 0)
ON CONFLICT DO NOTHING;

-- Herencia directa (profundidad 1)
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 1),
    ('a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 1)
ON CONFLICT DO NOTHING;

-- Herencia transitiva (profundidad 2): Cajero → Supervisor vía Cajero Senior
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 2)
ON CONFLICT DO NOTHING;

-- Verificar
SELECT 'Closure' as tipo, count(*) FROM bauth.rol_closure;
SELECT a.role_name || ' → ' || d.role_name as herencia, c.profundidad
FROM bauth.rol_closure c
JOIN bos_privilege.bos_role a ON c.ancestro_id::uuid = a.role_id
JOIN bos_privilege.bos_role d ON c.descendiente_id::uuid = d.role_id
ORDER BY c.profundidad, a.role_name;
