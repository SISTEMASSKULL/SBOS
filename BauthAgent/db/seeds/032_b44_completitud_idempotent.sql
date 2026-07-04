-- Fix constraints for new method types
ALTER TABLE bauth.auth_method DROP CONSTRAINT IF EXISTS auth_method_category_check;
ALTER TABLE bauth.auth_method ADD CONSTRAINT auth_method_category_check CHECK (category = ANY (ARRAY['password','otp','biometric','cryptographic','federated','device','recovery','adaptive','deprecated','continuous','out_of_band']));
ALTER TABLE bauth.auth_method DROP CONSTRAINT IF EXISTS auth_method_aal_level_check;
ALTER TABLE bauth.auth_method ADD CONSTRAINT auth_method_aal_level_check CHECK (aal_level = ANY (ARRAY['AAL1','AAL2','AAL3','AAL1-AAL2','AAL2-AAL3','AAL1-AAL3','n/a']));
ALTER TABLE bauth.auth_method DROP CONSTRAINT IF EXISTS auth_method_nist_status_check;
ALTER TABLE bauth.auth_method ADD CONSTRAINT auth_method_nist_status_check CHECK (nist_status = ANY (ARRAY['preferred','permitted','discouraged','deprecated','restricted','n/a']));

-- ================================================================
-- B44 — Actualización de Estándares 2026-Q2 · IDEMPOTENTE
-- Ejecutar N veces = mismo resultado · ON CONFLICT DO NOTHING
-- ================================================================

-- B01: Renombrar PQC a nombres FIPS oficiales (idempotente por WHERE)
UPDATE bauth.crypto_algorithm SET algo_name='ML-KEM-1024', fips_status='FIPS_203' 
WHERE algo_id='crystals_kyber_1024' AND algo_name != 'ML-KEM-1024';
UPDATE bauth.crypto_algorithm SET algo_name='ML-DSA-87', fips_status='FIPS_204' 
WHERE algo_id='crystals_dilithium_5' AND algo_name != 'ML-DSA-87';
UPDATE bauth.crypto_algorithm SET algo_name='SLH-DSA-SHA2-256s', fips_status='FIPS_205' 
WHERE algo_id='sphincs_plus' AND algo_name != 'SLH-DSA-SHA2-256s';
UPDATE bauth.crypto_algorithm SET active=false, fips_status=NULL 
WHERE algo_id='ntru_hps_4096' AND active=true;

-- B02: Agregar nuevos algoritmos
INSERT INTO bauth.crypto_algorithm (algo_id, algo_name, algo_type, category, purpose, params, fips_status, is_primary) VALUES
('ml_kem_768','ML-KEM-768','key_exchange','post_quantum','KEM PQ nivel 3 (uso general)','{"security_level":3}','FIPS_203',TRUE),
('fn_dsa','FN-DSA (FALCON)','digital_signature','post_quantum','Firma PQ ultra-compacta (FIPS 206)','{"security_level":5}','FIPS_206_draft',TRUE),
('x25519','X25519 (Curve25519)','key_exchange','classical','ECDH pre-transición PQC','{"key_bytes":32}','FIPS_140-3',TRUE),
('chacha20_poly1305','ChaCha20-Poly1305','encryption','classical','Cifrado sin hardware AES-NI','{"key_bytes":32}','FIPS_140-3',FALSE)
ON CONFLICT (algo_id) DO NOTHING;

-- B03: Email OTP → discouraged (idempotente por WHERE)
UPDATE bauth.auth_method SET nist_status='discouraged' 
WHERE method_id='KC_EMAIL_OTP' AND nist_status != 'discouraged';

-- B04: Agregar 8 métodos faltantes
INSERT INTO bauth.auth_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, requires_https) VALUES
('KC_SMS_OTP','SMS OTP (Out-of-Band)','out_of_band','otp','AAL1','restricted','{EXT_N0}',true),
('KC_PASSKEY_SYNCED','Passkey Sincronizado','multi_factor','cryptographic','AAL2','preferred','{BIZ_N1_N2,EXT_N0}',true),
('KC_PASSKEY_DEVICE_BOUND','Passkey Vinculado al Dispositivo','phishing_resistant','cryptographic','AAL2-AAL3','preferred','{SU,SYS,BIZ_N3_N5}',true),
('KC_HARDWARE_OTP','Hardware OTP Token','device','otp','AAL1-AAL2','permitted','{BIZ_N1_N2}',true),
('KC_ADAPTIVE_AUTH','Autenticación Adaptativa','adaptive','adaptive','AAL1-AAL3','preferred','{BIZ_N1_N5}',true),
('KC_BEHAVIORAL_BIOMETRICS','Biometría Comportamental Continua','continuous','biometric','n/a','preferred','{BIZ_N3_N5,SYS}',true),
('VC_MDOC','VC mDL (ISO 18013-5)','federated','federated','AAL2','preferred','{EXT_N0}',true),
('VC_W3C','VC W3C 2.0','federated','federated','AAL2','permitted','{EXT_N0,BIZ}',true)
ON CONFLICT (method_id) DO NOTHING;

-- B05: DPoP: planned → enabled
UPDATE bauth.federation_protocol SET bAuth_status='enabled' 
WHERE protocol_id='dpop_rfc9449' AND bAuth_status != 'enabled';

-- B06: Agregar protocolos RFC 9700, 9728, 9101, 9126
INSERT INTO bauth.federation_protocol (protocol_id, protocol_name, protocol_type, rfc_ref, flow, pkce_required, applies_to, bAuth_status) VALUES
('oauth2_bcp_rfc9700','OAuth 2.0 Security BCP','authorization','RFC_9700','best_practice',TRUE,'{ALL}','enabled'),
('oauth2_resource_metadata','OAuth 2.0 Protected Resource Metadata','authorization','RFC_9728','discovery',FALSE,'{SYS}','enabled'),
('oauth2_jar','JWT Secured Authorization Request','authorization','RFC_9101','authorization_code',FALSE,'{AAL3}','enabled'),
('oauth2_par','Pushed Authorization Requests','authorization','RFC_9126','authorization_code',TRUE,'{ALL}','enabled')
ON CONFLICT (protocol_id) DO NOTHING;

-- B07: Agregar 10 compliance controls
INSERT INTO bauth.compliance_map (standard, control_id, control_name, description, applies_to, implementation_status) VALUES
('GDPR','Art.25','Privacy by Design','Passkeys no transmiten PII','auth_method','implemented'),
('GDPR','Art.17','Derecho al Olvido','Revocación de authenticators','saga_catalog','planned'),
('NIST_800_53_Rev5','IA-5','Authenticator Management','Ciclo de vida de authenticators','auth_method','implemented'),
('NIST_800_53_Rev5','IA-8','Non-Organizational Users','Identificación usuarios externos EXT_N0','auth_method','implemented'),
('ISO_27001_2022','A.5.14','Information Transfer','Transferencia segura de tokens','federation_protocol','implemented'),
('ISO_27001_2022','A.8.17','Clock Synchronization','Sincronización TOTP','auth_config','planned'),
('RFC_9700','ALL','OAuth 2.0 Security BCP','Token binding, PKCE obligatorio','federation_protocol','implemented'),
('OWASP_ASVS_5.0.0','V2.1.1','Password Length ≥ 12 chars','ASVS 5.0 V2.1.1','auth_policy','implemented'),
('OWASP_ASVS_5.0.0','V2.1.7','Breached Password Check','ASVS 5.0 V2.1.7','auth_policy','partial'),
('OWASP_ASVS_5.0.0','V2.2.1','Anti-Automation','ASVS 5.0 V2.2.1','auth_policy','implemented')
ON CONFLICT (standard, control_id) DO NOTHING;

-- B08: Agregar 9 políticas de seguridad
INSERT INTO bauth.auth_policy (policy_name, policy_type, tier, policy_data, priority, standard_ref) VALUES
('mfa.phishing_resistant_only','mfa','SU','{"enabled":true}',10,'{NIST_800-63B-4_Rev4,NIST_AAL3}'),
('mfa.phishing_resistant_only','mfa','SYS','{"enabled":false}',10,'{NIST_800-63B-4_Rev4}'),
('passkey.allow_synced','mfa','SU','{"allowed":false}',12,'{NIST_800-63B-4_Rev4_§3.2.3}'),
('passkey.allow_synced','mfa','SYS','{"allowed":false}',12,'{NIST_800-63B-4_Rev4_§3.2.3}'),
('passkey.allow_synced','mfa','EXT_N0','{"allowed":true}',12,'{NIST_800-63B-4_Rev4_§3.2.3}'),
('token.dpop_required','session','SU','{"required":true}',8,'{RFC_9700,RFC_9449}'),
('token.dpop_required','session','SYS','{"required":true}',8,'{RFC_9700,RFC_9449}'),
('session.continuous_reeval_sec','session','SU','{"interval_sec":300}',15,'{NIST_800-207_Zero_Trust}'),
('session.continuous_reeval_sec','session','SYS','{"interval_sec":600}',15,'{NIST_800-207_Zero_Trust}')
ON CONFLICT (policy_name, tier) DO NOTHING;
