-- seed_ath_config_d9.sql — Configuraciones D9 Credenciales
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_config_d9 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_config_d9;
INSERT INTO bauth.ath_config_d9 (config_key, config_value, description, standard_ref) VALUES
('password_min_length','12','Longitud mínima de password. NIST Rev.4: mínimo 8, SBOS: 12.','{NIST SP 800-63B-4 §5.1.1.2}'),
('hibp_screening_enabled','true','Cribado HIBP k-anonymity obligatorio en enrolamiento y cambio.','{NIST SP 800-63B-4 §5.1.1.2}'),
('lockout_progressive_levels','[{"attempts":3,"duration":900,"action":"CAPTCHA"},{"attempts":5,"duration":3600,"action":"MFA_CHALLENGE"},{"attempts":10,"duration":86400,"action":"ACCOUNT_FROZEN"}]','Bloqueo progresivo NIST 800-53 AC-7.','{NIST SP 800-53 AC-7}'),
('mfa_required_aal2','true','MFA obligatorio para AAL2+. Dos factores distintos.','{NIST SP 800-63B-4 AAL2}'),
('password_history_count','5','No reutilizar últimas 5 contraseñas.','{OWASP ASVS V2.1.6}'),
('argon2id_default_params','{"time_cost":3,"memory_mb":64,"parallelism":2,"salt_length":16,"hash_length":32}','Parámetros Argon2id por defecto.','{OWASP ASVS V2.4.3}'),
('recovery_rate_limit','{"max_attempts":3,"window_seconds":3600}','Rate limit de recuperación: 3 intentos/hora.','{OWASP ASVS V2.5.1}'),
('session_max_seconds','28800','Duración máxima de sesión: 8 horas.','{NIST SP 800-63B-4 §7}'),
('session_idle_seconds','900','Timeout por inactividad: 15 minutos.','{NIST SP 800-63B-4 §7}'),
('phishing_resistant_required_aal2_plus','true','Opción phishing-resistant obligatoria AAL2+. NIST Rev.4 Final 2025.','{NIST SP 800-63B-4 Final}');
