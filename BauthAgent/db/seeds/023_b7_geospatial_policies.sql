-- B7: Políticas geoespaciales D6 — país, viaje imposible, geofence
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 6,
       'POL-D6-COUNTRY-ALLOWLIST',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',5,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','not_in','field','country','value',jsonb_build_array('BO','AR','CL','PE','BR')))),
         'params',jsonb_build_object('allowed_countries',jsonb_build_array('BO','AR','CL','PE','BR')),
         'message','País no permitido — acceso solo desde Bolivia, Argentina, Chile, Perú, Brasil'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D6-COUNTRY-ALLOWLIST');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 6,
       'POL-D6-IMPOSSIBLE-TRAVEL',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',10,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','distance_km','value',900),jsonb_build_object('op','lt','field','time_since_last_h','value',1))),
         'params',jsonb_build_object('max_speed_kmh',900,'min_hours_between',1),
         'message','Viaje imposible detectado — velocidad > 900 km/h'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D6-IMPOSSIBLE-TRAVEL');

SELECT 'Politicas D6 nuevas' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 6 AND active = TRUE;
