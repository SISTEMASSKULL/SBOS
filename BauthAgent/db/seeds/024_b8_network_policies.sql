-- B8: Políticas de red D7 — CIDR, VPN, device posture, rate limit
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 7,
       'POL-D7-CIDR-CORPORATE',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',5,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','not','field','client_ip','value',jsonb_build_object('op','cidr_match','value','10.0.0.0/8')))),
         'params',jsonb_build_object('allowed_cidrs',jsonb_build_array('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16')),
         'message','IP fuera de rangos corporativos'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D7-CIDR-CORPORATE');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 7,
       'POL-D7-DEVICE-POSTURE',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',10,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','eq','field','device_compliant','value',false))),
         'params',jsonb_build_object('checks',jsonb_build_array('os_patched','av_running','firewall_enabled','disk_encrypted')),
         'message','Dispositivo no cumple requisitos de seguridad'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D7-DEVICE-POSTURE');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 7,
       'POL-D7-RATE-LIMIT',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',3,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','req_per_sec','value',100))),
         'params',jsonb_build_object('max_req_per_sec',100,'burst',20,'window_sec',60),
         'message','Rate limit excedido — máximo 100 req/s'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D7-RATE-LIMIT');

SELECT 'Politicas D7' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 7 AND active = TRUE;
