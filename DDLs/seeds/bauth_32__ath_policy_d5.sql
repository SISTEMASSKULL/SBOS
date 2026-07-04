-- seed_ath_policy_d5.sql — Políticas D5 Biométrico
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d5 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d5;
INSERT INTO bauth.ath_policy_d5 (policy_code, policy_name, description, standard_ref, config) VALUES
('BIOMETRIC_LIVENESS_PASSIVE','Liveness pasiva obligatoria','Verificación de vida sin desafío activo. Anti-spoofing nivel 2. ISO 30107-3 PAD.','{ISO 30107-3,NIST SP 800-63B-4 §5.2.3}','{"rule":"liveness","method":"passive","anti_spoofing_level":2}'),
('BIOMETRIC_FMR_1_10000','FMR 1:10,000','False Match Rate máximo para LoA 2. NIST SP 800-63B-4 obligatorio.','{NIST SP 800-63B-4 §5.2.3}','{"rule":"fmr_threshold","value":"1:10000","min_loa":2}'),
('BIOMETRIC_FMR_1_100000','FMR 1:100,000','False Match Rate máximo para LoA 3. Zonas de máxima seguridad.','{NIST SP 800-63B-4 §5.2.3,ISO 19794}','{"rule":"fmr_threshold","value":"1:100000","min_loa":3}'),
('BIOMETRIC_GDPR_CONSENT','Consentimiento GDPR biométrico','Consentimiento explícito requerido. Revocable. Datos encriptados en reposo.','{GDPR Art.9,ISO 27701}','{"rule":"gdpr_consent","requires_explicit":true,"revocable":true,"retention_days":365}'),
('BIOMETRIC_ALTERNATIVE_REQUIRED','Alternativa no biométrica obligatoria','NIST exige método alternativo no biométrico disponible (QR dinámico).','{NIST SP 800-63B-4 §5.2.3}','{"rule":"alternative_required","fallback":"QR_DYNAMIC","max_uses_per_day":5}');
