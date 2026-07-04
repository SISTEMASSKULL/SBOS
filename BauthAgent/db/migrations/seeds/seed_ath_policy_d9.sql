-- seed_ath_policy_d9.sql — Políticas pre-diseñadas D9 Credenciales
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-63B-4 Final (2025) · OWASP ASVS V2 (2024) · FIDO2 Level 3
-- ═══════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d9 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d9;

INSERT INTO bauth.ath_policy_d9 (policy_code, policy_name, description, standard_ref, config) VALUES

-- Password policies (NIST SP 800-63B-4 Final 2025)
('PWD_MIN_LENGTH_12', 'Longitud Mínima 12 caracteres', 'NIST Rev.4: mínimo 8, SBOS recomienda 12. Sin reglas de complejidad forzadas.',
 '{NIST SP 800-63B-4 §5.1.1.2,OWASP ASVS V2.1.1}',
 '{"rule":"min_length","value":12}'),

('PWD_NO_COMPLEXITY', 'Sin reglas de complejidad', 'NIST Rev.4: NO exigir mayúsculas, números ni caracteres especiales. Solo longitud + HIBP.',
 '{NIST SP 800-63B-4 §5.1.1.2}',
 '{"rule":"no_complexity_rules"}'),

('PWD_NO_ROTATION', 'Sin rotación periódica forzada', 'NIST Rev.4: SHALL NOT require periodic password changes. Solo rotar si hay evidencia de compromiso.',
 '{NIST SP 800-63B-4 §5.1.1.2}',
 '{"rule":"no_periodic_rotation"}'),

('PWD_HIBP_CHECK', 'Verificación HIBP obligatoria', 'Cribado contra Have I Been Pwned usando k-anonymity. Obligatorio en enrolamiento + cambio.',
 '{NIST SP 800-63B-4 §5.1.1.2,OWASP ASVS V2.1.7}',
 '{"rule":"hibp_check","required":true,"method":"k_anonymity"}'),

('PWD_BLOCKLIST', 'Lista de bloqueo de passwords comunes', 'Bloquear passwords comunes, nombre de empresa, variaciones de "admin", "skull", "sbos".',
 '{NIST SP 800-63B-4 §5.1.1.2,OWASP ASVS V2.1.2}',
 '{"rule":"blocklist","items":["password","12345678","admin","skull","sbos","bolivia123","lapaz123"]}'),

('PWD_HISTORY_5', 'Historial de 5 passwords', 'No reutilizar ninguna de las últimas 5 contraseñas.',
 '{OWASP ASVS V2.1.6}',
 '{"rule":"history_check","count":5}'),

('PWD_ARGON2ID', 'Hash Argon2id obligatorio', 'Argon2id con t=3, m=64MB, p=2. OWASP ASVS V2.4.3 recomendado.',
 '{OWASP ASVS V2.4.3,NIST SP 800-63B-4 §5.1.1.2}',
 '{"rule":"hash_algorithm","algorithm":"Argon2id","params":{"time_cost":3,"memory_mb":64,"parallelism":2}}'),

-- MFA policies (NIST SP 800-63B-4 AAL2/AAL3)
('MFA_AAL2_REQUIRED', 'MFA obligatorio AAL2', 'Dos factores distintos requeridos para usuarios internos. Phishing-resistant debe ser ofrecido.',
 '{NIST SP 800-63B-4 §4.2,FIDO2 Level 2}',
 '{"rule":"mfa_required","aal":"AAL2","factors":2,"phishing_resistant_option_required":true}'),

('MFA_AAL3_HARDWARE', 'MFA AAL3 Hardware Device-Bound', 'Passkey device-bound FIPS 140-3. Clave no exportable. Syncable authenticators PROHIBIDOS.',
 '{NIST SP 800-63B-4 §4.3,FIPS 140-3}',
 '{"rule":"mfa_hardware","aal":"AAL3","device_bound":true,"syncable_prohibited":true}'),

('MFA_STEPUP_RFC9470', 'Step-Up RFC 9470', 'Elevación temporal al exceder límite financiero. De AAL2 a AAL3. Duración 5 minutos.',
 '{RFC 9470,NIST SP 800-63B-4 §4.3}',
 '{"rule":"step_up","trigger":"amount_exceeds_limit","from_aal":"AAL2","to_aal":"AAL3","duration_seconds":300}'),

-- Phishing resistance
('PR_PHISH_FIDO2', 'Phishing-Resistant AAL2+', 'Passkeys/WebAuthn obligatorios como opción phishing-resistant para AAL2+. Syncable permitido AAL2, prohibido AAL3.',
 '{NIST SP 800-63B-4 Final §4.2,FIDO2 Level 3}',
 '{"rule":"phishing_resistance","required_aal2_plus":true,"syncable_allowed_aal2":true,"device_bound_required_aal3":true}'),

-- Recovery policies
('RECOVERY_MFA', 'Recuperación con MFA', 'Recuperación de cuenta requiere segundo factor. Rate limit: 3 intentos por hora.',
 '{OWASP ASVS V2.5.1,NIST SP 800-63B-4 §4.4}',
 '{"rule":"recovery_requires_mfa","methods":["EMAIL_OTP","TOTP"],"rate_limit":{"max_attempts":3,"window_seconds":3600}}'),

('RECOVERY_BACKUP_CODES', 'Códigos de respaldo', '10 códigos de respaldo SHA-256 hasheados. Un solo uso cada uno.',
 '{OWASP ASVS V2.5.1}',
 '{"rule":"backup_codes","count":10,"single_use":true,"hash":"SHA-256"}'),

-- Lockout policies
('LOCKOUT_PROGRESSIVE', 'Bloqueo progresivo', '3 intentos→15min CAPTCHA, 5→1h MFA, 10→24h cuenta congelada, 50→bloqueo permanente.',
 '{NIST SP 800-53 AC-7,OWASP ASVS V2.1.2,PCI DSS 4.0 Req 8.3.4}',
 '{"rule":"progressive_lockout","levels":[{"attempts":3,"duration":900,"action":"CAPTCHA"},{"attempts":5,"duration":3600,"action":"MFA_CHALLENGE"},{"attempts":10,"duration":86400,"action":"ACCOUNT_FROZEN"}],"permanent_lock":50}'),

-- Session policies
('SESSION_TIMEOUT_8H', 'Timeout de sesión 8h', 'Sesión máxima 8 horas. Inactividad 15 minutos. Reautenticación cada 4 horas.',
 '{NIST SP 800-63B-4 §7,OWASP ASVS V3.3}',
 '{"rule":"session_timeout","max_seconds":28800,"idle_seconds":900,"reauth_seconds":14400}'),

('SESSION_CONCURRENT_1', 'Una sesión concurrente', 'Máximo 1 sesión activa por usuario. Force logout al iniciar nueva sesión.',
 '{NIST SP 800-63B-4 §7}',
 '{"rule":"max_concurrent_sessions","value":1,"action_on_exceed":"LOGOUT_OLDEST"}');

-- SELECT count(*) AS total_d9_policies FROM bauth.ath_policy_d9;
