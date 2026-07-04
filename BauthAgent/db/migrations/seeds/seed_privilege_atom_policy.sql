-- seed_privilege_atom_policy.sql — Políticas base por dominio
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_atom_policy RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_atom_policy;

-- Política base SoD para átomos D1 (Fast-Path: verbo suficiente, ctx_id requerido)
INSERT INTO bauth.privilege_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active)
SELECT a.app_code, a.group_code, a.atom_code, 1, 'sod_standard',
  jsonb_build_object(
    '$schema', 'bos_policy_v1',
    'priority', 1,
    'action', 'allow',
    'evaluate', jsonb_build_object(
      'logic', 'and',
      'conditions', jsonb_build_array(
        jsonb_build_object('field', 'ctx_id', 'op', 'exists', 'value', true)
      )
    ),
    'params', jsonb_build_object('description', 'Fast-Path D1: verbo suficiente, sin restricciones adicionales')
  ),
  true
FROM bauth.privilege_atom a WHERE a.domain_code = 1;

-- Política financiera para átomos D3
INSERT INTO bauth.privilege_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data, active)
SELECT a.app_code, a.group_code, a.atom_code, 3, 'financial_limit_default',
  jsonb_build_object(
    '$schema', 'bos_policy_v1',
    'priority', 50,
    'action', 'deny',
    'evaluate', jsonb_build_object(
      'logic', 'and',
      'conditions', jsonb_build_array(
        jsonb_build_object('field', 'amount', 'op', 'gt', 'value', 10000)
      )
    ),
    'params', jsonb_build_object(
      'max_amount', 10000,
      'currency', 'BOB',
      'period', 'daily',
      'description', 'Limite financiero por defecto. Requiere aprobacion para montos >10000 BOB.'
    )
  ),
  true
FROM bauth.privilege_atom a WHERE a.domain_code = 3;
