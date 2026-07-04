-- B1.T07 Seed: Roles + asignaciones de átomos para validar ComputeRolBitMask
-- 3 roles con jerarquía: Cajero → Cajero Senior → Supervisor

-- Roles de prueba
INSERT INTO bos_privilege.bos_role (role_id, tenant_id, role_code, role_name, role_slug) VALUES
    ('a0000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 100, 'Cajero', 'cajero'),
    ('a0000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 101, 'Cajero Senior', 'cajero_senior'),
    ('a0000000-0000-0000-0000-000000000003'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 102, 'Supervisor', 'supervisor');

-- Cajero: átomos 0,1,3,4 (comprobantes nuevo+editar, ver; facturacion nuevo)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('a0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 1, 0, true),
    ('a0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 2, 1, true),
    ('a0000000-0000-0000-0000-000000000001'::uuid, 1, 2, 1, 4, true),
    ('a0000000-0000-0000-0000-000000000001'::uuid, 1, 3, 1, 6, true),
    ('a0000000-0000-0000-0000-000000000001'::uuid, 1, 4, 1, 8, true);

-- Cajero Senior: hereda Cajero (pos 0,1,4,6,8) + átomos propios (2,5,7)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 1, 1, 0, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 1, 2, 1, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 2, 1, 4, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 3, 1, 6, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 4, 1, 8, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 1, 3, 2, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 2, 2, 5, true),
    ('a0000000-0000-0000-0000-000000000002'::uuid, 1, 3, 2, 7, true);

-- Supervisor: todos los átomos del Cajero Senior (0,1,2,4,5,6,7,8) + aprobación (pos 9)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 1, 1, 0, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 1, 2, 1, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 1, 3, 2, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 2, 1, 4, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 2, 2, 5, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 3, 1, 6, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 3, 2, 7, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 4, 1, 8, true),
    ('a0000000-0000-0000-0000-000000000003'::uuid, 1, 4, 2, 9, true);

-- Closure table para herencia (Cajero Senior hereda de Cajero, Supervisor hereda de ambos)
-- INSERT INTO bos_privilege.rol_closure ... (B1.T15)

-- Verificar
SELECT 'ROLES' as tipo, count(*) FROM bos_privilege.bos_role
UNION ALL SELECT 'ASIGNACIONES', count(*) FROM bos_privilege.bos_role_atom;
