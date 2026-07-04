-- seed_ath_config_d11.sql — Configuraciones D11 desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_config_d11 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_config_d11;

INSERT INTO bauth.ath_config_d11 (config_key, config_value, description, standard_ref)
SELECT 
  lower(regexp_replace(section_name, '[^a-zA-Z0-9]', '_', 'g')),
  content_en,
  COALESCE(description, 'Configuración ' || section_name || ' para ' || 'D11'),
  compliance_ref
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D11'] 
  AND jsonb_typeof(content_en) = 'object'
  AND depth <= 4
LIMIT 20;
