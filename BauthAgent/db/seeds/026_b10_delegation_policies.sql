-- B10: Políticas de delegación D10 — privilegios temporales, AND reduction
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 10,
       'POL-D10-MAX-DEPTH',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',5,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','delegation_depth','value',3))),
         'params',jsonb_build_object('max_depth',3),
         'message','Profundidad de delegación excedida — máximo 3 niveles'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D10-MAX-DEPTH');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 10,
       'POL-D10-EXPIRY',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',10,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','hours_since_delegation','value',8))),
         'params',jsonb_build_object('max_hours',8),
         'message','Delegación expirada — máximo 8 horas'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D10-EXPIRY');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 10,
       'POL-D10-SOD-CHECK',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',35,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','eq','field','sod_conflict','value',true))),
         'params',jsonb_build_object('check','sod_static_matrix'),
         'message','Conflicto SoD detectado en delegación'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D10-SOD-CHECK');

SELECT 'Politicas D10' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 10 AND active = TRUE;
