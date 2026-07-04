-- seed_aud_compliance_map.sql — Mapa de cumplimiento desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.aud_compliance_map RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.aud_compliance_map;

INSERT INTO bauth.aud_compliance_map (compliance_id, standard, control_id, control_name, description, applies_to, implementation_status, ctx_id, last_reviewed)
SELECT
  gen_random_uuid(),
  source,
  ref,
  section_name,
  COALESCE(description, 'Control from ' || source),
  'all',
  'implemented',
  'seed-library',
  now()
FROM bauth.cfg_policy_library,
     unnest(compliance_ref) AS ref
WHERE compliance_ref IS NOT NULL AND depth <= 2;
