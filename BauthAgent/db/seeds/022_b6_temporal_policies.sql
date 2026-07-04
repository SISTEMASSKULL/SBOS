-- B6: Políticas temporales D4 adicionales
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 4,
       'POL-D4-MAX-SESSION',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',32,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','session_hours','value',8))),
         'params',jsonb_build_object('max_hours',8),
         'message','Sesión excedida — máximo 8 horas'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 1 AND ac.verb_code = 1 -- átomos de ingreso de sesión
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D4-MAX-SESSION');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 4,
       'POL-D4-INACTIVITY',
       jsonb_build_object('$schema','bos_policy_v1','action','mfa_required','priority',35,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','idle_minutes','value',15))),
         'params',jsonb_build_object('idle_minutes',15),
         'message','Sesión inactiva por más de 15 minutos — requiere MFA'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac
WHERE ac.domain_code = 1 -- todos los átomos lógicos
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D4-INACTIVITY');

SELECT 'Politicas D4' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 4 AND active = TRUE;
