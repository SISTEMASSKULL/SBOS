-- =============================================================================
-- bauth_72__lib_d4_temporal.sql — Políticas de acceso temporal D4 (incremento)
-- =============================================================================
-- Propósito  : Agregar políticas del dominio temporal directamente a
--              cfg_policy_library (sin depender de JSON fuente).
-- Normas     : RFC 6238 (2011) — TOTP: Time-Based One-Time Password
--              RFC 4226 (2005) — HOTP: HMAC-Based One-Time Password
--              RFC 7519 (2015) — JWT: JSON Web Tokens (exp, nbf, iat)
--              RFC 8628 (2019) — OAuth 2.0 Device Authorization
--              NIST SP 800-57 Part 1 Rev.5 (2020) — Key Management (temporal)
--              NIST SP 800-63B-4 (2024) §5.1.3 — OTP Authenticators
--              NIST SP 800-53 Rev.5 AC-2(9), AC-12, IA-11 — Session Management
--              OWASP ASVS v5.0 §3.2, §3.3 — Session Management
--              ISO 27001:2022 A.8.5 — Privileged access management (temporal)
-- Fuente     : Investigación 2025-2026 (normas vigentes hasta 2026)
-- Idempotente: Sí — ON CONFLICT (json_path) DO NOTHING
-- =============================================================================
SET lock_timeout = '5s';

INSERT INTO bauth.cfg_policy_library (
  section_name, parent_path, json_path, depth, array_index, node_type,
  semantic_type, domain_map, source, standard_ref, compliance_ref,
  content, content_en, content_es,
  enforcement, risk_level, lifecycle,
  assurance_level, mfa_required, phishing_resistant
) VALUES

-- 1. TOTP RFC 6238 — Política de configuración
(
  'totp_rfc6238_policy', NULL, 'd4_temporal_ext.totp_rfc6238_policy',
  1, 0, 'policy', 'standard', ARRAY['D4'], 'd4_temporal_ext',
  'RFC 6238 (2011)', ARRAY['RFC 6238 §4', 'RFC 6238 §5.2', 'NIST SP 800-63B-4 §5.1.4.1'],
  '{"title":"TOTP RFC 6238 Policy","description":"Time-based One-Time Password (TOTP) per RFC 6238 is a valid AAL2 authenticator. SBOS TOTP configuration: time step 30 seconds (RFC 6238 default), SHA-1 HMAC (TOTP-SHA1 base), optional SHA-256 or SHA-512 for enhanced security, 6-digit code, clock drift tolerance ±1 step (±30s). Shared secret minimum 160 bits (20 bytes). Backup codes: 8 one-time codes of 8 alphanumeric chars each, NIST SP 800-63B-4 §6.1.2.3. The verifier must not allow code reuse within same time step.","configuration":{"time_step_seconds":30,"algorithm":"HMAC-SHA1","preferred_algorithm":"HMAC-SHA256","code_digits":6,"clock_drift_steps":1,"secret_min_bits":160,"backup_codes":8,"backup_code_length":8,"code_reuse":"prohibited"},"compatibility":["Google Authenticator","Microsoft Authenticator","Authy","1Password","Bitwarden"]}',
  '{"title":"TOTP RFC 6238 Policy","description":"TOTP per RFC 6238: 30s time step, SHA-1/SHA-256 HMAC, 6-digit code, ±1 step drift tolerance, 160-bit minimum secret. Code reuse prohibited.","configuration":{"time_step_seconds":30,"algorithm":"HMAC-SHA1","code_digits":6,"clock_drift_steps":1,"secret_min_bits":160,"backup_codes":8,"code_reuse":"prohibited"}}',
  '{"titulo":"Política TOTP RFC 6238","descripcion":"TOTP según RFC 6238: paso de tiempo 30s, HMAC SHA-1/SHA-256, código 6 dígitos, tolerancia ±1 paso, secreto mínimo 160 bits. Reutilización de código prohibida.","configuracion":{"paso_tiempo_segundos":30,"algoritmo":"HMAC-SHA1","digitos_codigo":6,"tolerancia_pasos_reloj":1,"bits_minimos_secreto":160,"codigos_respaldo":8,"reutilizacion_codigo":"prohibida"}}',
  'mandatory', 'medium', 'active', 'AAL2', true, false
),

-- 2. HOTP RFC 4226 — Política para tokens físicos
(
  'hotp_rfc4226_policy', NULL, 'd4_temporal_ext.hotp_rfc4226_policy',
  1, 0, 'policy', 'standard', ARRAY['D4'], 'd4_temporal_ext',
  'RFC 4226 (2005)', ARRAY['RFC 4226 §5', 'RFC 4226 §7.4', 'NIST SP 800-63B-4 §5.1.4.2'],
  '{"title":"HOTP RFC 4226 Policy","description":"HMAC-Based One-Time Password (HOTP) per RFC 4226 for hardware OTP tokens. SBOS HOTP requirements: HMAC-SHA1 (mandatory per RFC), 6-digit minimum code (8 preferred), counter synchronization window maximum 10, re-synchronization requires user re-authentication. Throttling: max 3 consecutive failures before 30-second lockout. Counter value persisted server-side with rollover protection. Hardware tokens require FIPS 140-2 Level 1 minimum certification.","configuration":{"algorithm":"HMAC-SHA1","code_digits_min":6,"code_digits_preferred":8,"counter_window":10,"max_consecutive_failures":3,"lockout_seconds":30,"fips_level_min":"140-2 Level 1","counter_storage":"server_side"}}',
  '{"title":"HOTP RFC 4226 Policy","description":"HOTP per RFC 4226 for hardware OTP tokens: HMAC-SHA1, 6-8 digit code, 10-step counter window, 3 failures before 30s lockout, FIPS 140-2 Level 1 minimum for hardware.","configuration":{"algorithm":"HMAC-SHA1","code_digits_min":6,"counter_window":10,"max_consecutive_failures":3}}',
  '{"titulo":"Política HOTP RFC 4226","descripcion":"HOTP según RFC 4226 para tokens OTP físicos: HMAC-SHA1, código 6-8 dígitos, ventana contador 10 pasos, 3 fallos antes de bloqueo 30s, mínimo FIPS 140-2 Nivel 1 para hardware.","configuracion":{"algoritmo":"HMAC-SHA1","digitos_codigo_min":6,"ventana_contador":10,"fallos_consecutivos_max":3}}',
  'mandatory', 'medium', 'active', 'AAL2', true, false
),

-- 3. JWT — Política de expiración y ciclo de vida de tokens
(
  'jwt_lifecycle_expiration_policy', NULL, 'd4_temporal_ext.jwt_lifecycle_expiration_policy',
  1, 0, 'policy', 'standard', ARRAY['D4','D9'], 'd4_temporal_ext',
  'RFC 7519 (2015)', ARRAY['RFC 7519 §4.1.4', 'RFC 7519 §4.1.5', 'NIST SP 800-63B-4 §7.1', 'OWASP ASVS v5.0 §3.2.1'],
  '{"title":"JWT Lifecycle and Expiration Policy","description":"JSON Web Tokens (JWT) used in SBOS must comply with RFC 7519 temporal claims: exp (expiration time), nbf (not before), iat (issued at). Policy: (1) Access tokens: max 15 minutes (900 seconds), (2) Refresh tokens: max 24 hours with rotation-on-use, (3) ID tokens: max 1 hour, (4) Service tokens (M2M): max 24 hours, (5) JWT must be rejected if exp is in the past or nbf is in the future, (6) Clock skew tolerance: ±5 minutes maximum, (7) Revocation via Redis blacklist for critical tokens, (8) Refresh token reuse detection: immediate family invalidation on suspected theft (RFC 6749 §10.4).","token_lifetimes_seconds":{"access_token":900,"refresh_token":86400,"id_token":3600,"service_token":86400},"clock_skew_seconds":300,"revocation_mechanism":"redis_blacklist","refresh_rotation":true,"reuse_detection":true}',
  '{"title":"JWT Lifecycle and Expiration Policy","description":"JWT temporal claims per RFC 7519. Access tokens: 15min, refresh: 24h with rotation, ID token: 1h, M2M: 24h. Clock skew: ±5min. Revocation via Redis blacklist. Refresh token reuse detection enabled.","token_lifetimes_seconds":{"access_token":900,"refresh_token":86400,"id_token":3600,"service_token":86400},"clock_skew_seconds":300}',
  '{"titulo":"Política Ciclo de Vida y Expiración JWT","descripcion":"Claims temporales JWT según RFC 7519. Tokens de acceso: 15min, refresh: 24h con rotación, ID token: 1h, M2M: 24h. Desviación reloj: ±5min. Revocación vía blacklist Redis. Detección de reutilización de refresh token activada.","tiempos_vida_segundos":{"token_acceso":900,"token_refresco":86400,"token_id":3600,"token_servicio":86400},"desviacion_reloj_segundos":300}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 4. Política de timeout de sesión por nivel AAL
(
  'session_timeout_by_aal', NULL, 'd4_temporal_ext.session_timeout_by_aal',
  1, 0, 'policy', 'standard', ARRAY['D4'], 'd4_temporal_ext',
  'NIST SP 800-63B-4', ARRAY['NIST SP 800-63B-4 §7.1', 'NIST SP 800-53 Rev.5 AC-12', 'OWASP ASVS v5.0 §3.3.2'],
  '{"title":"Session Timeout Policy by AAL Level","description":"Session timeout must be enforced by SBOS at the authentication assurance level achieved. Absolute session limits regardless of activity must be applied. Re-authentication must be triggered before expiry. Policy: AAL1: idle 30min/absolute 12h; AAL2: idle 15min/absolute 8h; AAL3: idle 10min/absolute 4h. For privileged/financial operations: idle 10min/absolute 2h regardless of AAL. The idle timer resets on verified user interaction (not background Ajax calls). Timeout must result in full re-authentication, not just token refresh.","timeouts":{"AAL1":{"idle_minutes":30,"absolute_hours":12},"AAL2":{"idle_minutes":15,"absolute_hours":8},"AAL3":{"idle_minutes":10,"absolute_hours":4},"privileged":{"idle_minutes":10,"absolute_hours":2}},"reauthentication":"full_required","idle_reset":"verified_user_interaction_only"}',
  '{"title":"Session Timeout Policy by AAL Level","description":"Session timeouts enforced by AAL. AAL1: 30min idle/12h absolute. AAL2: 15min idle/8h absolute. AAL3: 10min idle/4h absolute. Privileged: 10min idle/2h absolute. Full re-authentication required on timeout.","timeouts":{"AAL1":{"idle_minutes":30,"absolute_hours":12},"AAL2":{"idle_minutes":15,"absolute_hours":8},"AAL3":{"idle_minutes":10,"absolute_hours":4}}}',
  '{"titulo":"Política Timeout de Sesión por Nivel AAL","descripcion":"Timeouts de sesión según AAL. AAL1: 30min inactivo/12h absoluto. AAL2: 15min inactivo/8h absoluto. AAL3: 10min inactivo/4h absoluto. Privilegiado: 10min inactivo/2h absoluto. Se requiere re-autenticación completa al expirar.","timeouts":{"AAL1":{"minutos_inactivo":30,"horas_absoluto":12},"AAL2":{"minutos_inactivo":15,"horas_absoluto":8},"AAL3":{"minutos_inactivo":10,"horas_absoluto":4}}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 5. Política de rotación de claves criptográficas (temporal)
(
  'cryptographic_key_rotation_temporal', NULL, 'd4_temporal_ext.cryptographic_key_rotation_temporal',
  1, 0, 'policy', 'standard', ARRAY['D4'], 'd4_temporal_ext',
  'NIST SP 800-57 Part 1 Rev.5', ARRAY['NIST SP 800-57 Part 1 Rev.5 §5.3', 'NIST SP 800-57 Part 1 Rev.5 §5.6.4', 'ISO 27001:2022 A.8.24'],
  '{"title":"Cryptographic Key Rotation Policy","description":"Cryptographic keys used in SBOS authentication must have defined lifecycle periods per NIST SP 800-57 Part 1 Rev.5. Key rotation schedule: (1) JWT signing keys (Ed25519/RSA-4096): max 1 year, rotation automated via Vault, (2) TOTP shared secrets: rotate on device re-enrollment or suspected compromise, (3) TLS certificates: max 1 year (per CA/Browser Forum Ballot SC-65), (4) Database encryption keys (AES-256): max 2 years, (5) ADSIB certificates (external): per ADSIB validity period (max 3 years). Emergency rotation on: compromise, personnel departure, security incident. Zero-downtime rotation via dual-active key period (overlap 1 hour for JWTs).","key_lifetimes":{"jwt_signing_days":365,"totp_secrets":"on_event","tls_cert_days":365,"db_encryption_days":730,"adsib_cert_days":1095},"rotation_automation":"vault_dynamic_secrets","emergency_rotation_triggers":["compromise","personnel_departure","security_incident"],"zero_downtime":"dual_active_1h_overlap"}',
  '{"title":"Cryptographic Key Rotation Policy","description":"Key rotation per NIST SP 800-57: JWT signing (Ed25519) max 1 year, TLS certs max 1 year, DB keys max 2 years. Emergency rotation on compromise. Zero-downtime via dual-active overlap.","key_lifetimes":{"jwt_signing_days":365,"tls_cert_days":365,"db_encryption_days":730}}',
  '{"titulo":"Política Rotación Claves Criptográficas","descripcion":"Rotación de claves según NIST SP 800-57: claves de firma JWT (Ed25519) máximo 1 año, certificados TLS máximo 1 año, claves DB máximo 2 años. Rotación de emergencia ante compromiso. Sin tiempo de inactividad mediante período de solapamiento.","vida_util_claves":{"firma_jwt_dias":365,"cert_tls_dias":365,"cifrado_bd_dias":730}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 6. Acceso temporal de emergencia (break-glass)
(
  'break_glass_emergency_access', NULL, 'd4_temporal_ext.break_glass_emergency_access',
  1, 0, 'policy', 'policy', ARRAY['D4'], 'd4_temporal_ext',
  'NIST SP 800-53 Rev.5', ARRAY['NIST SP 800-53 Rev.5 AC-2(2)', 'NIST SP 800-53 Rev.5 AC-17(7)', 'ISO 27001:2022 A.9.4.4'],
  '{"title":"Break-Glass Emergency Access Policy","description":"In emergency situations where normal authentication is unavailable (disaster recovery, admin lockout), SBOS provides a time-limited break-glass access mechanism. Rules: (1) Break-glass credentials stored in Vault emergency compartment (never in normal Vault), (2) Access requires physical presence + supervisor authorization, (3) Time limit: maximum 4 hours per incident, automatically revoked, (4) Every action during break-glass is logged with enhanced detail (keystrokes, commands, data accessed), (5) Post-incident review mandatory within 24 hours, (6) Break-glass use triggers Security Operations Center (SOC) alert, (7) Maximum 2 uses per quarter before escalation to CISO.","requirements":{"storage":"vault_emergency_compartment","physical_presence":true,"supervisor_authorization":true,"max_duration_hours":4,"enhanced_logging":true,"post_incident_review_hours":24,"soc_alert":true,"max_uses_per_quarter":2},"revocation":"automatic_on_timeout"}',
  '{"title":"Break-Glass Emergency Access Policy","description":"Emergency break-glass access: Vault emergency compartment, physical presence + supervisor auth, max 4 hours, enhanced logging, mandatory post-incident review within 24h, SOC alert triggered.","requirements":{"physical_presence":true,"max_duration_hours":4,"enhanced_logging":true,"soc_alert":true}}',
  '{"titulo":"Política Acceso Emergencia Break-Glass","descripcion":"Acceso de emergencia break-glass: compartimento Vault de emergencia, presencia física + autorización supervisor, máximo 4 horas, registro mejorado, revisión post-incidente obligatoria en 24h, alerta SOC activada.","requisitos":{"presencia_fisica":true,"duracion_maxima_horas":4,"registro_mejorado":true,"alerta_soc":true}}',
  'mandatory', 'critical', 'active', 'AAL3', true, false
),

-- 7. Privileged Access Management — Temporal JIT
(
  'pam_jit_just_in_time', NULL, 'd4_temporal_ext.pam_jit_just_in_time',
  1, 0, 'policy', 'policy', ARRAY['D4','D10'], 'd4_temporal_ext',
  'NIST SP 800-207', ARRAY['NIST SP 800-207 §2.2', 'NIST SP 800-53 Rev.5 AC-2(9)', 'CyberArk PAM Best Practices 2025'],
  '{"title":"Just-In-Time (JIT) Privileged Access Policy","description":"Privileged access in SBOS must follow JIT principles per NIST SP 800-207 Zero Trust. Standing privileged access is prohibited for production systems. Requirements: (1) Privileged access is granted on-demand with time limit (max 8 hours), (2) Request requires justification ticket, manager approval, and SoD check, (3) Vault dynamic secrets used for database access (credentials valid only during session), (4) Session recording for all privileged sessions, (5) After session end: credentials automatically rotated, access revoked, (6) Unusual privileged activity triggers immediate SOC alert, (7) JIT access never extends beyond originally approved time window.","requirements":{"standing_access":"prohibited","max_duration_hours":8,"justification_required":true,"manager_approval":true,"sod_check":true,"vault_dynamic_credentials":true,"session_recording":true,"auto_revocation_on_expiry":true,"no_time_extension":true}}',
  '{"title":"JIT Privileged Access Policy","description":"JIT privileged access per NIST SP 800-207: no standing access, max 8h on-demand, approval workflow, Vault dynamic credentials, session recording, auto-revocation. No time extensions.","requirements":{"standing_access":"prohibited","max_duration_hours":8,"vault_dynamic_credentials":true,"session_recording":true}}',
  '{"titulo":"Política Acceso Privilegiado JIT","descripcion":"Acceso privilegiado JIT según NIST SP 800-207: sin acceso permanente, máximo 8h bajo demanda, flujo de aprobación, credenciales dinámicas Vault, grabación de sesión, revocación automática. Sin extensiones de tiempo.","requisitos":{"acceso_permanente":"prohibido","duracion_maxima_horas":8,"credenciales_dinamicas_vault":true,"grabacion_sesion":true}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 8. Sincronización NTP — Requisito temporal para OTP
(
  'ntp_clock_sync_requirement', NULL, 'd4_temporal_ext.ntp_clock_sync_requirement',
  1, 0, 'policy', 'configuration', ARRAY['D4'], 'd4_temporal_ext',
  'RFC 5905 (2010)', ARRAY['RFC 6238 §5.1', 'NIST SP 800-63B-4 §5.1.4.1', 'NIST Cybersecurity Framework 2.0 §PR.IP-9'],
  '{"title":"NTP Clock Synchronization Requirement","description":"Accurate time synchronization is critical for TOTP and all temporal access controls in SBOS. Requirements: (1) All SBOS nodes must synchronize to authoritative NTP servers (Stratum 2 or better), (2) NTP source preference: NIST time.nist.gov, RIPE ntp.ripe.net, pool.ntp.org, (3) Maximum clock drift: 5 seconds before authentication failures, (4) NTP authenticated transport (NTS - Network Time Security per RFC 8915), (5) Clock monitoring: alert if offset exceeds 1 second, (6) Hardware Security Module (HSM) real-time clock as backup for critical nodes, (7) Bolivia: synchronization with CNT (Corporación Nacional de Telecomunicaciones) NTP when available.","requirements":{"stratum_max":2,"preferred_sources":["time.nist.gov","ntp.ripe.net","pool.ntp.org"],"max_drift_seconds":5,"nts_authentication":true,"alert_offset_seconds":1,"hsm_rtc_backup":true},"monitoring_interval_seconds":60}',
  '{"title":"NTP Clock Synchronization Requirement","description":"SBOS NTP requirements for TOTP: Stratum 2 or better, NTS authenticated transport (RFC 8915), max 5s drift, alert on 1s offset, HSM RTC backup.","requirements":{"stratum_max":2,"max_drift_seconds":5,"nts_authentication":true}}',
  '{"titulo":"Requisito Sincronización Reloj NTP","descripcion":"Requisitos NTP de SBOS para TOTP: Stratum 2 o mejor, transporte autenticado NTS (RFC 8915), máxima deriva 5s, alerta en 1s de desfase, respaldo RTC HSM.","requisitos":{"stratum_maximo":2,"maxima_deriva_segundos":5,"autenticacion_nts":true}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
)

ON CONFLICT (json_path) DO NOTHING;

SELECT COUNT(*) AS politicas_d4_incremento_insertadas FROM bauth.cfg_policy_library WHERE source = 'd4_temporal_ext';
