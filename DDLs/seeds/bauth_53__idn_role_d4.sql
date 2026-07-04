-- seed_idn_role_d4.sql — Roles pre-configurados D4 desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_role_d4 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_role_d4;

INSERT INTO bauth.idn_role_d4 (role_code, role_name, config, description)
SELECT 
  'D4_' || upper(regexp_replace(section_name, '[^a-zA-Z0-9]', '_', 'g')),
  jsonb_build_object('es', section_name, 'en', section_name),
  content_en,
  COALESCE(description, 'Política de ' || section_name || ' — Dominio D4 auto-generado desde cfg_policy_library')
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D4'] 
  AND jsonb_typeof(content_en) = 'object'
  AND depth <= 3
LIMIT 15;
