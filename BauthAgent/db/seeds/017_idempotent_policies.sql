-- Políticas idempotentes con estructura validada (ck_policy_data_valid)

-- MFA para D3 Financiero (verbos nuevo/eliminar)
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'require_mfa',
       jsonb_build_object(
           '$schema', 'bos_policy_v1',
           'action', 'mfa_required',
           'priority', 10,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('op', 'eq', 'field', 'domain_code', 'value', 3),
               jsonb_build_object('op', 'in', 'field', 'verb_code', 'value', jsonb_build_array(1, 3))
           )),
           'params', jsonb_build_object('mfa_methods', jsonb_build_array('totp', 'webauthn')),
           'message', 'Operaciones financieras requieren MFA'
       ),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 3
  AND ac.verb_code IN (1, 3)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'require_mfa'
  );

-- Doble aprobación para D12 Blockchain
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'require_approval',
       jsonb_build_object(
           '$schema', 'bos_policy_v1',
           'action', 'pending_approval',
           'priority', 20,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('op', 'eq', 'field', 'domain_code', 'value', 12)
           )),
           'params', jsonb_build_object('approvers_count', 2, 'quorum', 'majority'),
           'message', 'Operaciones blockchain requieren doble aprobación'
       ),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 12
  AND ac.verb_code IN (1, 2, 3)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'require_approval'
  );

-- Restricción horaria para D4 Temporal
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'time_restricted',
       jsonb_build_object(
           '$schema', 'bos_policy_v1',
           'action', 'deny',
           'priority', 5,
           'evaluate', jsonb_build_object('logic', 'or', 'conditions', jsonb_build_array(
               jsonb_build_object('op', 'lt', 'field', 'current_hour', 'value', 8),
               jsonb_build_object('op', 'gte', 'field', 'current_hour', 'value', 18)
           )),
           'params', jsonb_build_object('timezone', 'America/La_Paz', 'start_hour', 8, 'end_hour', 18),
           'message', 'Operaciones temporales restringidas a horario laboral (08:00-18:00)'
       ),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 4
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'time_restricted'
  );

-- IP whitelist para D8 Contexto
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, ac.domain_code,
       'ip_whitelist',
       jsonb_build_object(
           '$schema', 'bos_policy_v1',
           'action', 'deny',
           'priority', 15,
           'evaluate', jsonb_build_object('logic', 'not', 'conditions', jsonb_build_array(
               jsonb_build_object('op', 'in', 'field', 'client_ip', 'value', jsonb_build_array('192.168.0.0/16', '10.0.0.0/8'))
           )),
           'params', jsonb_build_object('allowed_cidrs', jsonb_build_array('192.168.0.0/16', '10.0.0.0/8')),
           'message', 'Acceso a contexto solo desde redes internas'
       ),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 8
  AND ac.verb_code IN (1, 2, 3)
  AND NOT EXISTS (
    SELECT 1 FROM bos_privilege.bos_atom_policy ap
    WHERE ap.app_code = ac.app_code AND ap.group_code = ac.group_code
      AND ap.atom_code = ac.atom_code AND ap.policy_slug = 'ip_whitelist'
  );
