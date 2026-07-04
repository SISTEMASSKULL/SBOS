-- seed_ath_policy_d6.sql — Políticas D6 Geolocalización
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-53 PE-3 · Google BeyondCorp · GDPR Art.44-49 · OFAC
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d6 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d6;

INSERT INTO bauth.ath_policy_d6 (policy_code, policy_name, description, standard_ref, config) VALUES
('GEOFENCE_REQUIRED',       'Geo-fence obligatorio',          'Usuario debe estar dentro del geo-fence de su sucursal asignada.', '{NIST SP 800-53 PE-3,Google BeyondCorp}', '{"rule":"geofence_required","action_on_violation":"DENY"}'),
('VELOCITY_CHECK_900KMH',   'Viaje imposible >900 km/h',      'Logins consecutivos con velocidad >900km/h → step-up. Tolerancia GPS 10km.', '{NIST SP 800-63B-4,Google BeyondCorp}', '{"rule":"velocity_check","max_kmh":900,"tolerance_km":10,"window_minutes":5}'),
('COUNTRY_RESTRICT_BO',     'Restricción geográfica Bolivia',  'Solo acceso desde Bolivia. Otros países bloqueados.', '{ISO 3166-1}', '{"rule":"country_restrict","allowed":["BO"],"action":"DENY"}'),
('GDPR_DATA_RESIDENCY',     'Residencia de datos EEA',        'Datos personales solo se procesan en servidores dentro del EEA.', '{GDPR Art.44-49,NIS 2}', '{"rule":"data_residency","allowed_regions":["BO","EEA"],"block_cross_border":true}'),
('OFAC_SANCTIONS_BLOCK',    'Bloqueo OFAC',                   'Países sancionados: acceso denegado a nivel gateway.', '{OFAC,SWIFT KYC}', '{"rule":"sanctions","type":"BLOCK","countries":["KP","IR","SY","CU"]}'),
('TRUST_TIER_EVALUATION',   'Evaluación de trust tier',       'Asignar tier de confianza basado en IP, GPS,WiFi y frecuencia de visitas.', '{Google BeyondCorp}', '{"rule":"trust_tier","signals":["GPS","IP","WIFI","FREQUENCY"],"tiers":["HIGH","MEDIUM","LOW","UNTRUSTED"]}');
