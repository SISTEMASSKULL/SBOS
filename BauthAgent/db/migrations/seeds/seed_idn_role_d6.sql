-- seed_idn_role_d6.sql — Roles pre-configurados D6 desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_role_d6 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_role_d6;

INSERT INTO bauth.idn_role_d6 (role_code, role_name, config, description)
SELECT 
  'D6_' || upper(regexp_replace(section_name, '[^a-zA-Z0-9]', '_', 'g')),
  jsonb_build_object('es', section_name, 'en', section_name),
  content_en,
  COALESCE(description, 'Política de ' || section_name || ' — Dominio D6 auto-generado desde cfg_policy_library')
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D6'] 
  AND jsonb_typeof(content_en) = 'object'
  AND depth <= 3
LIMIT 15;
