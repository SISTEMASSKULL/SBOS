-- ================================================================
-- Seed idempotente: 10 roles + políticas + role_atom + closure
-- Corre en cualquier momento sin dañar datos existentes
-- ================================================================

-- ─── 1. ROLES (10 roles con nombres reales) ────────────────────
-- Usamos role_codes 100-109 para no colisionar con existentes (1-25)

INSERT INTO bos_privilege.bos_role (role_id, tenant_id, role_code, role_name, role_slug, active, created_at, updated_at)
SELECT gen_random_uuid(), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid, code, name, slug, true, now(), now()
FROM (VALUES
    (100, 'Auditor Financiero',     'auditor-financiero'),
    (101, 'Operador de Red',        'operador-red'),
    (102, 'Verificador Blockchain', 'verificador-blockchain'),
    (103, 'Supervisor Temporal',    'supervisor-temporal'),
    (104, 'Admin de Contexto',      'admin-contexto'),
    (105, 'Cajero',                 'cajero'),
    (106, 'Gerente de Sucursal',    'gerente-sucursal'),
    (107, 'Auditor de Seguridad',   'auditor-seguridad'),
    (108, 'Operador Biométrico',    'operador-biometrico'),
    (109, 'Super Admin',            'super-admin')
) AS t(code, name, slug)
WHERE NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role WHERE role_code = t.code
);

-- ─── 2. ROLE-ATOM: Asignar átomos a roles ─────────────────────

-- Auditor Financiero (D3): átomos financieros con verbo=ver(4) y editar(2)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed, granted_at)
SELECT r.role_id, ac.app_code, ac.group_code, ac.atom_code, ac.atom_position, true, now()
FROM bos_privilege.bos_role r
CROSS JOIN bos_privilege.bos_atom_catalog ac
WHERE r.role_code = 100
  AND ac.domain_code = 3
  AND ac.verb_code IN (2, 4)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role_atom ra
    WHERE ra.role_id = r.role_id AND ra.app_code = ac.app_code
      AND ra.group_code = ac.group_code AND ra.atom_code = ac.atom_code
  );

-- Operador de Red (D7): átomos de red con verbo=ver(4)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed, granted_at)
SELECT r.role_id, ac.app_code, ac.group_code, ac.atom_code, ac.atom_position, true, now()
FROM bos_privilege.bos_role r
CROSS JOIN bos_privilege.bos_atom_catalog ac
WHERE r.role_code = 101
  AND ac.domain_code = 7
  AND ac.verb_code = 4
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role_atom ra
    WHERE ra.role_id = r.role_id AND ra.app_code = ac.app_code
      AND ra.group_code = ac.group_code AND ra.atom_code = ac.atom_code
  );

-- Verificador Blockchain (D12): átomos blockchain con verbo=ver(4) y editar(2)
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed, granted_at)
SELECT r.role_id, ac.app_code, ac.group_code, ac.atom_code, ac.atom_position, true, now()
FROM bos_privilege.bos_role r
CROSS JOIN bos_privilege.bos_atom_catalog ac
WHERE r.role_code = 102
  AND ac.domain_code = 12
  AND ac.verb_code IN (2, 4)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role_atom ra
    WHERE ra.role_id = r.role_id AND ra.app_code = ac.app_code
      AND ra.group_code = ac.group_code AND ra.atom_code = ac.atom_code
  );

-- Supervisor Temporal (D4): átomos temporales todos los verbos
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed, granted_at)
SELECT r.role_id, ac.app_code, ac.group_code, ac.atom_code, ac.atom_position, true, now()
FROM bos_privilege.bos_role r
CROSS JOIN bos_privilege.bos_atom_catalog ac
WHERE r.role_code = 103
  AND ac.domain_code = 4
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role_atom ra
    WHERE ra.role_id = r.role_id AND ra.app_code = ac.app_code
      AND ra.group_code = ac.group_code AND ra.atom_code = ac.atom_code
  );

-- Admin de Contexto (D8): átomos de contexto ver=ver y editar
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed, granted_at)
SELECT r.role_id, ac.app_code, ac.group_code, ac.atom_code, ac.atom_position, true, now()
FROM bos_privilege.bos_role r
CROSS JOIN bos_privilege.bos_atom_catalog ac
WHERE r.role_code = 104
  AND ac.domain_code = 8
  AND ac.verb_code IN (2, 4)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_role_atom ra
    WHERE ra.role_id = r.role_id AND ra.app_code = ac.app_code
      AND ra.group_code = ac.group_code AND ra.atom_code = ac.atom_code
  );

-- ─── 3. POLÍTICAS: Asignar políticas a átomos ─────────────────

-- Política require_mfa para átomos D3 Financiero con verbo=nuevo(1) o eliminar(3)
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'require_mfa',
       jsonb_build_object('priority', 10, 'mfa_methods', '["totp","webauthn"]'::jsonb, 'description', 'Requiere MFA para operaciones financieras sensibles'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 3
  AND ac.verb_code IN (1, 3)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'require_mfa'
  );

-- Política require_approval para D12 Blockchain
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'require_approval',
       jsonb_build_object('priority', 20, 'approvers_count', 2, 'description', 'Requiere doble aprobación para operaciones blockchain'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 12
  AND ac.verb_code IN (1, 2, 3)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'require_approval'
  );

-- Política time_restricted para D4 Temporal (solo horario laboral)
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'time_restricted',
       jsonb_build_object('priority', 5, 'allowed_hours', '{"start":"08:00","end":"18:00","timezone":"America/La_Paz"}'::jsonb, 'description', 'Restringido a horario laboral'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 4
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'time_restricted'
  );

-- ─── 4. CLOSURE TABLE: Herencia de roles ──────────────────────

-- Auditor Financiero (100) hereda de Cajero (105)
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad)
SELECT r_auditor.role_id::text, r_cajero.role_id::text, 1
FROM bos_privilege.bos_role r_auditor, bos_privilege.bos_role r_cajero
WHERE r_auditor.role_code = 100 AND r_cajero.role_code = 105
  AND NOT EXISTS (
    SELECT 1 FROM bauth.rol_closure rc
    WHERE rc.ancestro_id = r_auditor.role_id::text
      AND rc.descendiente_id = r_cajero.role_id::text
  );

-- Gerente de Sucursal (106) hereda de Cajero (105)
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad)
SELECT r_gerente.role_id::text, r_cajero.role_id::text, 1
FROM bos_privilege.bos_role r_gerente, bos_privilege.bos_role r_cajero
WHERE r_gerente.role_code = 106 AND r_cajero.role_code = 105
  AND NOT EXISTS (
    SELECT 1 FROM bauth.rol_closure rc
    WHERE rc.ancestro_id = r_gerente.role_id::text
      AND rc.descendiente_id = r_cajero.role_id::text
  );

-- Super Admin (109) hereda de Auditor de Seguridad (107)
INSERT INTO bauth.rol_closure (ancestro_id, descendiente_id, profundidad)
SELECT r_super.role_id::text, r_auditor.role_id::text, 1
FROM bos_privilege.bos_role r_super, bos_privilege.bos_role r_auditor
WHERE r_super.role_code = 109 AND r_auditor.role_code = 107
  AND NOT EXISTS (
    SELECT 1 FROM bauth.rol_closure rc
    WHERE rc.ancestro_id = r_super.role_id::text
      AND rc.descendiente_id = r_auditor.role_id::text
  );
