-- B9: Políticas de credenciales D9 — password, MFA, token binding, certificate
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 9,
       'POL-D9-PASSWORD-LENGTH',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',1,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','string_len','field','password','value',12))),
         'params',jsonb_build_object('min_length',12,'max_length',64),
         'message','Contraseña demasiado corta — mínimo 12 caracteres (NIST SP 800-63B)'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1 AND ac.verb_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D9-PASSWORD-LENGTH');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 9,
       'POL-D9-MFA-REQUIRED',
       jsonb_build_object('$schema','bos_policy_v1','action','step_up','priority',2,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','eq','field','mfa_enrolled','value',false))),
         'params',jsonb_build_object('mfa_methods',jsonb_build_array('totp','webauthn','passkey')),
         'message','MFA requerido — enrolle un segundo factor'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D9-MFA-REQUIRED');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 9,
       'POL-D9-TOKEN-BINDING',
       jsonb_build_object('$schema','bos_policy_v1','action','deny','priority',3,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','eq','field','token_bound','value',false))),
         'params',jsonb_build_object('binding_methods',jsonb_build_array('mtls_rfc8705','dpop_rfc9449')),
         'message','Token no vinculado al dispositivo — requiere mTLS o DPoP'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D9-TOKEN-BINDING');

SELECT 'Politicas D9' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 9 AND active = TRUE;
