-- B11: Políticas de auditoría D11 — WORM, retención, integridad (post-hoc, no evalúa)
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 11,
       'POL-D11-AUDIT-EVENT',
       jsonb_build_object('$schema','bos_policy_v1','action','allow','priority',99,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array()),
         'params',jsonb_build_object('retention_days',365,'storage','WORM','iso_27001','A.8.15'),
         'message','Registro de auditoría — siempre permite, solo registra (post-hoc)'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1 AND ac.verb_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D11-AUDIT-EVENT');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 11,
       'POL-D11-RETENTION',
       jsonb_build_object('$schema','bos_policy_v1','action','allow','priority',100,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array()),
         'params',jsonb_build_object('auth_events_days',365,'auth_events_years',7,'sessions_days',90),
         'message','Retención de auditoría configurada por tipo de evento'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D11-RETENTION');

SELECT 'Politicas D11' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 11 AND active = TRUE;
