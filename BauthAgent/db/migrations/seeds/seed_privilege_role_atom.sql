-- seed_privilege_role_atom.sql — Asignaciones rol↔átomo para verificación BitMask
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- Pobla 3 roles con átomos de diferentes dominios para probar evaluación.
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

-- Cajero (101): átomos D1 posiciones 1-4 + D3 posiciones 1585-1588
INSERT INTO bauth.privilege_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed)
SELECT '00000000-0000-0000-0000-000000000101', app_code, group_code, atom_code, atom_position, TRUE
FROM bauth.privilege_atom
WHERE atom_position IN (1, 2, 3, 4, 1585, 1586, 1587, 1588)
ON CONFLICT (role_id, app_code, group_code, atom_code) DO NOTHING;

-- Contador (102): átomos D1 posiciones 1-10 + D3 posiciones 1585-1596
INSERT INTO bauth.privilege_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed)
SELECT '00000000-0000-0000-0000-000000000102', app_code, group_code, atom_code, atom_position, TRUE
FROM bauth.privilege_atom
WHERE atom_position BETWEEN 1 AND 10
   OR atom_position BETWEEN 1585 AND 1596
ON CONFLICT (role_id, app_code, group_code, atom_code) DO NOTHING;

-- Supervisor (103): átomos D1 pos 1-20 + D2 pos 34-43 + D3 pos 1585-1596
INSERT INTO bauth.privilege_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed)
SELECT '00000000-0000-0000-0000-000000000103', app_code, group_code, atom_code, atom_position, TRUE
FROM bauth.privilege_atom
WHERE atom_position BETWEEN 1 AND 20
   OR atom_position BETWEEN 34 AND 43
   OR atom_position BETWEEN 1585 AND 1596
ON CONFLICT (role_id, app_code, group_code, atom_code) DO NOTHING;
