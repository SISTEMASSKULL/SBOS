-- B12: D12 Blockchain — Variante A (Merkle anchoring) + Variante B (liquidación Besu QBFT)
INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 12,
       'POL-D12-MERKLE-ANCHOR',
       jsonb_build_object('$schema','bos_policy_v1','action','allow','priority',10,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array()),
         'params',jsonb_build_object('hash_algo','SHA3-256','batch_size',1000,'chain','Arbitrum One','gas_limit',100000),
         'message','Anclaje Merkle en Arbitrum One — SHA3-256, lotes de 1000 eventos'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D12-MERKLE-ANCHOR');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 12,
       'POL-D12-SETTLEMENT',
       jsonb_build_object('$schema','bos_policy_v1','action','pending_approval','priority',20,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array(jsonb_build_object('op','gt','field','amount','value',10000))),
         'params',jsonb_build_object('network','Besu_QBFT','validators',4,'consensus','QBFT','block_time_sec',2,'confirmations',1,'high_value_confirmations',3,'threshold_usd',100000),
         'message','Liquidación on-chain vía Besu QBFT — confirmación en 2s, high-value requiere 3 confirmaciones'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 3
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D12-SETTLEMENT');

INSERT INTO bos_privilege.bos_atom_policy (policy_id, app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active, created_at, updated_at)
SELECT gen_random_uuid(), ac.app_code, ac.group_code, ac.atom_code, 12,
       'POL-D12-VERIFY',
       jsonb_build_object('$schema','bos_policy_v1','action','allow','priority',30,
         'evaluate',jsonb_build_object('logic','and','conditions',jsonb_build_array()),
         'params',jsonb_build_object('methods',jsonb_build_array('onchain','merkle_proof','bos-verify'),'public_access',true),
         'message','Verificación pública de anclajes — sin autenticación requerida'),
       true, now(), now()
FROM bos_privilege.bos_atom_catalog ac WHERE ac.domain_code = 1
  AND NOT EXISTS (SELECT 1 FROM bos_privilege.bos_atom_policy ap WHERE ap.app_code=ac.app_code AND ap.group_code=ac.group_code AND ap.atom_code=ac.atom_code AND ap.policy_slug='POL-D12-VERIFY');

SELECT 'Politicas D12' as label, count(*) FROM bos_privilege.bos_atom_policy WHERE policy_domain = 12 AND active = TRUE;
