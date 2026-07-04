-- seed_ath_config_d8.sql — Configuraciones D8 desde cfg_policy_library
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_config_d8 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_config_d8;

INSERT INTO bauth.ath_config_d8 (config_key, config_value, description, standard_ref)
SELECT 
  lower(regexp_replace(section_name, '[^a-zA-Z0-9]', '_', 'g')),
  content_en,
  COALESCE(description, 'Configuración ' || section_name || ' para ' || 'D8'),
  compliance_ref
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D8'] 
  AND jsonb_typeof(content_en) = 'object'
  AND depth <= 4
LIMIT 20;

-- risk_params: parámetros del RiskEngine (NIST SP 800-207). Cargados desde JSON, no hardcodeados.
INSERT INTO bauth.ath_config_d8 (config_key, config_value, description, standard_ref)
VALUES ('risk_params',
  '{"weight_identity":0.25,"weight_device":0.25,"weight_network":0.30,"weight_behavioral":0.20,"threshold_allow":25.0,"threshold_mfa_recommend":50.0,"threshold_mfa_require":75.0,"threshold_deny":100.0,"tor_min_score":85.0,"device_unknown_score":60.0,"network_tor_score":95.0,"network_vpn_score":50.0,"network_new_location_score":20.0,"behavioral_madrugada_score":40.0,"behavioral_fuera_horario_score":15.0,"identity_high_attempts_score":80.0,"identity_medium_attempts_score":50.0,"identity_low_attempts_score":25.0,"high_velocity_threshold":10,"business_hours_start":8,"business_hours_end":18}',
  'Parámetros del Risk Scoring Engine: pesos, umbrales, thresholds NIST SP 800-207.',
  ARRAY['NIST SP 800-207']
) ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, updated_at = now();
