-- seed_ath_policy_d2.sql — Políticas pre-diseñadas D2 Físico
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d2 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d2;
INSERT INTO bauth.ath_policy_d2 (policy_code, policy_name, description, standard_ref, config) VALUES
('ANTI_PASSBACK_HARD','Anti-Passback Estricto','Bloquea entrada sin salida previa registrada. Reset cada 24h. Hard mode: bloqueo físico.','{IEC 60839-11-5,SIA OSDP v2.2.3}','{"rule":"anti_passback","mode":"hard","reset_hours":24}'),
('ANTI_PASSBACK_SOFT','Anti-Passback Suave','Permite entrada sin salida previa pero alerta a seguridad.','{IEC 60839-11-5}','{"rule":"anti_passback","mode":"soft","reset_hours":24}'),
('ESCORT_REQUIRED','Escolta requerida para visitantes','Visitantes deben ser escoltados por personal autorizado en zonas restringidas.','{ISO 27001 A.7.2,NIST SP 800-53 PE-3}','{"rule":"escort_required","applies_to":["VISITANTE","EXT_N0"]}'),
('TWO_PERSON_RULE','Regla de dos personas','Zonas críticas requieren mínimo 2 personas simultáneamente (bóvedas, data centers).','{ISO 27001 A.7.1,NIST SP 800-53 PE-3}','{"rule":"two_person","zones":["PHY_ZONE_SERVIDOR","PHY_ZONE_BOVEDA"]}'),
('MANTRAP_REQUIRED','Esclusa de seguridad','Cámara entre dos puertas para zonas de máxima seguridad.','{IEC 60839-11-5,NIST SP 800-53 PE-3}','{"rule":"mantrap_required","zones":["PHY_ZONE_SERVIDOR"]}'),
('BIOMETRIC_ENROLLMENT_HYBRID','Enrolamiento biométrico híbrido','Usuario registra biométrico, admin aprueba. Liveness pasiva. Argon2id.','{ISO 30107-3,NIST SP 800-63B-4 §5.2.3}','{"rule":"biometric_enrollment","mode":"hybrid","liveness":"passive","hash":"Argon2id"}'),
('DURESS_CODE_ENABLED','Código de coacción','PIN alternativo que abre la puerta pero alerta silenciosamente a seguridad.','{IEC 60839-11-5,BS 5979}','{"rule":"duress_code","enabled":true,"silent_alarm":true,"lockdown_zone":true}');
