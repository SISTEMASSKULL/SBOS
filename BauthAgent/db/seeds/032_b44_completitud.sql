-- B44 — Actualización de Estándares 2026-Q2 (Completitud)

-- B01: Renombrar PQC a nombres FIPS oficiales
UPDATE bauth.crypto_algorithm SET algo_name='ML-KEM-1024', fips_status='FIPS_203' WHERE algo_id='crystals_kyber_1024';
UPDATE bauth.crypto_algorithm SET algo_name='ML-DSA-87', fips_status='FIPS_204' WHERE algo_id='crystals_dilithium_5';
UPDATE bauth.crypto_algorithm SET algo_name='SLH-DSA-SHA2-256s', fips_status='FIPS_205' WHERE algo_id='sphincs_plus';
UPDATE bauth.crypto_algorithm SET active=false, fips_status=NULL WHERE algo_id='ntru_hps_4096';

-- B02: Agregar nuevos algoritmos
INSERT INTO bauth.crypto_algorithm (algo_id, algo_name, algo_type, category, purpose, params, fips_status, is_primary) VALUES
('ml_kem_768','ML-KEM-768','key_exchange','post_quantum','Intercambio de claves PQ nivel 3 (uso general)','{"security_level":3,"key_bytes":1184,"ciphertext_bytes":1088}','FIPS_203',TRUE),
('fn_dsa','FN-DSA (FALCON)','digital_signature','post_quantum','Firma digital PQ ultra-compacta (FIPS 206)','{"security_level":5,"signature_bytes":666,"public_key_bytes":897}','FIPS_206_draft',TRUE),
('x25519','X25519 (Curve25519)','key_exchange','classical','ECDH clásico pre-transición PQC','{"key_bytes":32,"rfc":7748}','FIPS_140-3',TRUE),
('chacha20_poly1305','ChaCha20-Poly1305','encryption','classical','Cifrado autenticado sin hardware AES-NI','{"key_bytes":32,"nonce_bytes":12,"rfc":8439}','FIPS_140-3',FALSE)
ON CONFLICT (algo_id) DO UPDATE SET algo_name=EXCLUDED.algo_name, fips_status=EXCLUDED.fips_status;

-- B03: Actualizar Email OTP a discouraged
UPDATE bauth.auth_method SET nist_status='discouraged' WHERE method_id='KC_EMAIL_OTP';

-- B04: Agregar métodos de autenticación faltantes
INSERT INTO bauth.auth_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, requires_https) VALUES
('KC_SMS_OTP','SMS OTP (Out-of-Band)','single_factor','otp','AAL1','restricted','{EXT_N0}',true),
('KC_PASSKEY_SYNCED','Passkey Sincronizado (iCloud/Google)','multi_factor','cryptographic','AAL2','preferred','{BIZ_N1_N2,EXT_N0}',true),
('KC_PASSKEY_DEVICE_BOUND','Passkey Vinculado al Dispositivo','phishing_resistant','cryptographic','AAL2-AAL3','preferred','{SU,SYS,BIZ_N3_N5}',true),
('KC_HARDWARE_OTP','Hardware OTP Token (YubiKey OTP)','single_factor','otp','AAL1-AAL2','permitted','{BIZ_N1_N2}',true),
('KC_ADAPTIVE_AUTH','Autenticación Adaptativa (Risk-Based)','adaptive','adaptive','AAL1-AAL3','preferred','{BIZ_N1_N5}',true),
('KC_BEHAVIORAL_BIOMETRICS','Biometría Comportamental Continua','continuous','biometric','n/a','preferred','{BIZ_N3_N5,SYS}',true),
('VC_MDOC','Verifiable Credential mDL (ISO 18013-5)','federated','federated','AAL2','preferred','{EXT_N0}',true),
('VC_W3C','Verifiable Credential W3C 2.0','federated','federated','AAL2','permitted','{EXT_N0,BIZ}',true)
ON CONFLICT (method_id) DO UPDATE SET method_name=EXCLUDED.method_name, nist_status=EXCLUDED.nist_status;

-- B05: Actualizar DPoP de planned → enabled
UPDATE bauth.federation_protocol SET bAuth_status='enabled', config='{"proof_required":true}' WHERE protocol_id='dpop_rfc9449';

-- B06: Agregar RFC 9700 y RFC 9728
INSERT INTO bauth.federation_protocol (protocol_id, protocol_name, protocol_type, rfc_ref, flow, pkce_required, applies_to, bAuth_status) VALUES
('oauth2_bcp_rfc9700','OAuth 2.0 Security BCP','authorization','RFC_9700','best_practice',TRUE,'{ALL}','enabled'),
('oauth2_resource_metadata','OAuth 2.0 Protected Resource Metadata','authorization','RFC_9728','discovery',FALSE,'{SYS}','enabled'),
('oauth2_jar','JWT Secured Authorization Request (JAR)','authorization','RFC_9101','authorization_code',FALSE,'{AAL3}','enabled'),
('oauth2_par','Pushed Authorization Requests (PAR)','authorization','RFC_9126','authorization_code',TRUE,'{ALL}','enabled')
ON CONFLICT (protocol_id) DO UPDATE SET bAuth_status=EXCLUDED.bAuth_status;

-- B07: Agregar compliance controls faltantes
INSERT INTO bauth.compliance_map (standard, control_id, control_name, description, applies_to, implementation_status) VALUES
('GDPR','Art.25','Privacy by Design','Protección de datos desde el diseño — passkeys no transmiten PII','auth_method','implemented'),
('GDPR','Art.17','Derecho al Olvido','Revocación completa de authenticators al ejercer derecho','saga_catalog','planned'),
('NIST_800_53_Rev5','IA-5','Authenticator Management','Gestión completa del ciclo de vida de authenticators','auth_method + auth_config','implemented'),
('NIST_800_53_Rev5','IA-8','Non-Organizational Users','Identificación para usuarios externos (EXT_N0)','auth_method (EXT_N0)','implemented'),
('ISO_27001_2022','A.5.14','Information Transfer','Seguridad en transferencia de tokens entre servicios','federation_protocol','implemented'),
('ISO_27001_2022','A.8.17','Clock Synchronization','Sincronización de relojes — crítico para TOTP','auth_config','planned'),
('RFC_9700','ALL','OAuth 2.0 Security BCP','Token binding, PKCE obligatorio, redirect URI matching','federation_protocol','implemented'),
('OWASP_ASVS_5.0.0','V2.1.1','Password Length ≥ 12 chars','Actualizado desde ASVS 4.0.3 V2.1.1','auth_policy','implemented'),
('OWASP_ASVS_5.0.0','V2.1.7','Breached Password Check','Actualizado desde ASVS 4.0.3 V2.1.7','auth_policy','partial'),
('OWASP_ASVS_5.0.0','V2.2.1','Anti-Automation / Rate Limiting','Actualizado desde ASVS 4.0.3 V2.2.1','auth_policy','implemented')
ON CONFLICT (standard, control_id) DO UPDATE SET implementation_status=EXCLUDED.implementation_status,
    description=EXCLUDED.description;

-- B08: Agregar políticas faltantes
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
ON CONFLICT (policy_name, tier) DO UPDATE SET policy_data=EXCLUDED.policy_data, priority=EXCLUDED.priority;

SELECT 'B44 completado' as status,
  (SELECT count(*) FROM bauth.auth_method) as metodos,
  (SELECT count(*) FROM bauth.crypto_algorithm WHERE active=true) as algoritmos,
  (SELECT count(*) FROM bauth.federation_protocol WHERE bAuth_status='enabled') as protocolos,
  (SELECT count(*) FROM bauth.compliance_map) as compliance,
  (SELECT count(*) FROM bauth.auth_policy) as politicas;
