-- ============================================================================
-- SEED: Configuraciones por Dominio — ath_config_d1 a ath_config_d12
-- Fuente: MANUAL_DB_DDL.md v18.0 §31, §6
--         COMMENT ON TABLE ath_config_d{n} en DDL_skSBOS_db.sql
-- Idempotente: TRUNCATE + RESTART IDENTITY CASCADE + INSERT
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- D1 — DOMINIO LÓGICO: token_ttl, rate_limit, max_records_default, session_ttl
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d1 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d1 (config_key, config_value, description, standard_ref) VALUES
('token_ttl', '{"access_token_seconds":3600,"refresh_token_seconds":86400,"id_token_seconds":3600}',
 'TTL de tokens de acceso (1h), refresh (24h) e identidad (1h). OAuth 2.1 BCP.',
 ARRAY['OAuth 2.0 RFC 6749','OAuth 2.1 BCP']),
('rate_limit', '{"authenticated_rps":100,"unauthenticated_rps":10,"admin_rps":1000,"burst_multiplier":2}',
 'Rate limiting: autenticado 100 req/s, no autenticado 10 req/s, admin 1000 req/s.',
 ARRAY['PCI-DSS 4.0 Req 11.3','SBOS-054 NRS-08']),
('max_records_default', '{"per_query":200,"export_max":10000,"api_page_size":50}',
 'Límites: 200 registros/query, 10000 exportación, 50 página API.',
 ARRAY['OWASP ASVS V5.1.3','ISO 27001 A.9.4']),
('session_ttl_d1', '{"max_idle_minutes":60,"absolute_max_hours":12,"extend_on_activity":true}',
 'Sesión D1: inactividad 60min, máximo 12h, extender en actividad.',
 ARRAY['NIST SP 800-63B §7','OWASP ASVS V3.3']),
('audit_verbosity', '{"log_all_queries":false,"log_sensitive_access":true,"sample_rate_pct":100}',
 'Auditoría D1: solo accesos sensibles, muestreo 100% para críticas.',
 ARRAY['ISO 27001 A.8.15','NIST SP 800-53 AU-12']),
('zone_defaults', '{"default_scope":"branch","default_classification":"internal","allow_cross_tenant":false}',
 'Defaults zona nueva: scope sucursal, clasificación interna, sin cross-tenant.',
 ARRAY['NIST RBAC §4.2','ISO 24760-2:2025']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D2 — DOMINIO FÍSICO: door_relay_ms, anti_passback, duress, max_access_points
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d2 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d2 (config_key, config_value, description, standard_ref) VALUES
('door_relay_ms', '{"unlock_pulse_ms":5000,"lock_immediate_on_close":true,"extended_open_ms":30000}',
 'Relé: pulso apertura 5s, bloqueo inmediato al cerrar, extendida 30s.',
 ARRAY['IEC 60839-11-5','BS 5979:2007']),
('anti_passback_reset_h', '{"reset_at_utc":"04:00","manual_reset_allowed":true,"violation_grace_period_s":30}',
 'Anti-passback: reset diario 04:00 UTC, gracia 30s en violación.',
 ARRAY['IEC 60839-11-5','NIST SP 800-53 PE-3']),
('duress_timeout', '{"duress_pin_arm_delay_s":0,"silent_alarm_enabled":true,"lockdown_on_duress":false}',
 'Coacción: PIN coacción arma alarma silenciosa inmediata, sin lockdown.',
 ARRAY['BS 5979:2007','NIST SP 800-53 PE-3']),
('max_access_points', '{"per_building_default":50,"per_area_default":10,"per_controller":4}',
 'Límites: 50 puntos/edificio, 10/área, 4 puertas/controladora OSDP.',
 ARRAY['IEC 60839-11-5','OSDP v2.2.2']),
('osdp_secure_channel', '{"enabled":true,"encryption":"AES-128","key_rotation_days":30,"require_secure_all":true}',
 'Canal OSDP: AES-128 obligatorio, rotación 30d.',
 ARRAY['IEC 60839-11-5','SIA OSDP v2.2.2']),
('visitor_badge_ttl', '{"default_hours":12,"max_hours":24,"auto_invalidate_at_midnight":true}',
 'Credencial visitante: 12h default, 24h máx, invalidación a medianoche.',
 ARRAY['NIST SP 800-53 PE-2','ISO 27001 A.11.1.2']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D3 — DOMINIO FINANCIERO: currency_default, sin_environment, approval_timeout
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d3 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d3 (config_key, config_value, description, standard_ref) VALUES
('currency_default', '{"code":"BOB","decimal_places":2,"symbol":"Bs.","minor_unit":"centavo"}',
 'Moneda default: Boliviano BOB, 2 decimales, símbolo Bs.',
 ARRAY['ISO 4217']),
('sin_environment', '{"url_prod":"https://pilotosi.impuestos.gob.bo","timeout_s":30,"max_retries":3}',
 'SIN Bolivia: timeout 30s, 3 reintentos.',
 ARRAY['SIN RND 102100000011']),
('approval_timeout_h', '{"level_1":4,"level_2":8,"level_3":24,"auto_escalate":true,"notify_on_timeout":true}',
 'Timeouts aprobación: N1 4h, N2 8h, N3 24h. Escalación automática.',
 ARRAY['SOX §404','COSO']),
('max_tiers', '{"approval_chain_max_depth":5,"skip_absent_approver":true,"require_final_approval":true}',
 'Cadena aprobación: máx 5 niveles, saltar ausente, nivel final obligatorio.',
 ARRAY['SOX §404','ISO 20022']),
('transaction_idempotency', '{"idempotency_key_ttl_hours":24,"reject_duplicate_idempotency_key":true}',
 'Idempotencia: clave 24h, rechazar duplicados.',
 ARRAY['ISO 20022']),
('reconciliation_tolerance', '{"amount_bob":1.00,"auto_resolve_minor":true,"alert_threshold_bob":100.00}',
 'Tolerancia reconciliación: ±1 Bs auto, alerta >100 Bs.',
 ARRAY['SOX §404','NIST SP 800-53 AU-7']),
('cufd_renewal', '{"schedule_utc":"04:05","retry_minutes":5,"max_retries":12,"alert_after_minutes":30}',
 'CUFD: diario 04:05 UTC, reintento cada 5min, alerta P2 si >30min.',
 ARRAY['SIN RND 102100000011']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D4 — DOMINIO TEMPORAL: timezone, shift, overtime, break
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d4 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d4 (config_key, config_value, description, standard_ref) VALUES
('timezone_default', '{"iana":"America/La_Paz","utc_offset":"-04:00","observes_dst":false}',
 'Zona horaria: America/La_Paz UTC-4, sin DST.',
 ARRAY['IANA TZ Database','ISO 8601']),
('shift_duration_max', '{"regular_hours":8,"max_daily_hours":12,"max_weekly_hours":48,"rest_between_shifts_h":11}',
 'Turno: 8h regular, 12h máx/día, 48h/semana, 11h descanso.',
 ARRAY['ISO 8601']),
('overtime_rate', '{"multiplier":1.5,"night_multiplier":2.0,"holiday_multiplier":2.5,"requires_pre_approval":true}',
 'Horas extra: ×1.5 normal, ×2.0 nocturna, ×2.5 feriado. Requiere aprobación.',
 ARRAY['ISO 8601']),
('break_duration', '{"short_break_minutes":15,"lunch_break_minutes":60,"max_work_without_break_hours":4}',
 'Pausas: 15min corta, 60min almuerzo, máx 4h continuas.',
 ARRAY['ISO 8601','NIST SP 800-53 AC-11']),
('schedule_grace_period', '{"clock_in_early_minutes":15,"clock_in_late_minutes":15,"clock_out_early_minutes":15}',
 'Gracia fichaje: ±15min. Tarde si >15min.',
 ARRAY['ISO 8601']),
('holiday_country', '{"default":"BO","include_regional":true,"auto_update_from_calendar":true}',
 'Feriados default: Bolivia, incluir regionales, auto desde calendario.',
 ARRAY['RFC 5545','ISO 3166-1']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D5 — DOMINIO BIOMÉTRICO: fmr, liveness, argon2_params, template_retention
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d5 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d5 (config_key, config_value, description, standard_ref) VALUES
('fmr_default', '{"fingerprint":0.0001,"face":0.001,"iris":0.00001,"voice":0.01}',
 'FMR: huella 0.01%, rostro 0.1%, iris 0.001%, voz 1%.',
 ARRAY['ISO/IEC 19795','NIST SP 800-63B §5.2']),
('liveness_method', '{"mode":"active_and_passive","active_challenges":["blink","smile","turn_head"],"max_attempts":3}',
 'Liveness: activo (parpadeo,sonrisa,giro) + pasivo. 3 intentos.',
 ARRAY['ISO/IEC 30107-3','FIDO Alliance']),
('argon2_params', '{"fingerprint":{"t":3,"m":64},"face":{"t":3,"m":64},"iris":{"t":5,"m":128},"voice":{"t":2,"m":32}}',
 'Argon2id: FP t=3 m=64MB, rostro t=3 m=64MB, iris t=5 m=128MB, voz t=2 m=32MB.',
 ARRAY['NIST SP 800-63B §5.2','OWASP ASVS V6.2']),
('template_retention_days', '{"active_employee":0,"former_employee":30,"visitor":1,"contractor":90}',
 'Retención template: empleado indef, ex 30d, visita 1d, contratista 90d.',
 ARRAY['RGPD Art.9','ISO/IEC 19794']),
('quality_threshold', '{"fingerprint":{"min_score":80,"min_dpi":500},"face":{"min_resolution":"1080p","max_pose_angle":15},"iris":{"min_score":90}}',
 'Calidad captura: huella ≥80, rostro 1080p ±15°, iris ≥90.',
 ARRAY['ISO/IEC 19794','NIST SP 800-63B §5.2']),
('gdpr_biometric_consent', '{"require_explicit":true,"renewal_months":12,"revocable":true,"minor_parental_consent":true}',
 'GDPR biométrico: consentimiento explícito, renovable 12m, revocable.',
 ARRAY['RGPD Art.9','RGPD Art.7']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D6 — DOMINIO GEOESPACIAL: velocity, tolerance, fence_radius, trust_tiers
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d6 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d6 (config_key, config_value, description, standard_ref) VALUES
('velocity_max_kmh', '{"absolute_max":900,"car_max":150,"human_max":10}',
 'Velocidad máx: 900km/h absoluto, 150 auto, 10 humano.',
 ARRAY['NIST SP 800-207','OWASP ASVS V2.8']),
('tolerance_km', '{"gps":0.05,"wifi":0.5,"cell_tower":5.0,"ip_geolocation":50.0}',
 'Precisión: GPS 50m, WiFi 500m, celular 5km, IP 50km.',
 ARRAY['ISO 6709','NIST SP 800-207']),
('fence_radius_default', '{"office_meters":200,"home_office_meters":500,"branch_meters":100,"warehouse_meters":1000}',
 'Geo-cerca: oficina 200m, home 500m, sucursal 100m, almacén 1km.',
 ARRAY['ISO 6709']),
('location_history', '{"retention_hours":24,"max_locations":1000,"sampling_minutes":5}',
 'Historial ubicación: 24h, 1000 máx, muestreo cada 5min.',
 ARRAY['RGPD Art.5','ISO 27001 A.8.15']),
('trust_tier_thresholds', '{"high":0.85,"medium":0.60,"low":0.30,"untrusted":0.0}',
 'Confianza ubicación: alta ≥85%, media ≥60%, baja ≥30%.',
 ARRAY['NIST SP 800-207']),
('jurisdiction_block', '{"block_cross_border_pii":true,"allowlist":["BO"]}',
 'Bloqueo transfronterizo PII. Solo Bolivia.',
 ARRAY['RGPD Art.44','Ley 164 Bolivia']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D7 — DOMINIO RED: device_score, verification, grace, mtls, vpn, ztna
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d7 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d7 (config_key, config_value, description, standard_ref) VALUES
('device_score_min', '{"trusted":80,"medium":60,"restricted":40,"block_below":40}',
 'Score dispositivo: confiable ≥80, medio ≥60, restringido ≥40, bloquear <40.',
 ARRAY['NIST SP 800-207','CIS Benchmarks']),
('verification_interval_s', '{"full_check":300,"light_check":60,"on_network_change":true,"on_ip_change":true}',
 'Verificación continua: completa 300s, ligera 60s, al cambiar red/IP.',
 ARRAY['NIST SP 800-207','SBOS-054 §4']),
('grace_period_s', '{"network_switch":10,"ip_change":30,"vpn_reconnect":60,"sleep_wake":15}',
 'Gracia: cambio red 10s, IP 30s, reconexión VPN 60s.',
 ARRAY['NIST SP 800-207']),
('mtls_config', '{"min_tls":"1.3","cert_ttl_hours":24,"issuer":"vault_pki_internal","require_client_cert":true}',
 'mTLS: TLS 1.3, cert 24h, Vault PKI, client cert obligatorio.',
 ARRAY['RFC 8705','SBOS-050 P9','NIST SP 800-52']),
('vpn_required', '{"for_external":true,"vpn_type":"wireguard","device_cert_required":true,"session_max_hours":12}',
 'VPN: obligatoria externo, WireGuard, cert dispositivo, sesión 12h.',
 ARRAY['NIST SP 800-207','SBOS-054 NRS-07']),
('ztna_mode', '{"enabled":true,"implicit_trust_zones":"none","per_request_authz":true,"microsegmentation":"calico"}',
 'Zero Trust: sin confianza implícita, authz por request, Calico.',
 ARRAY['NIST SP 800-207','CISA ZTA Maturity Model']),
('network_policy_default', '{"ingress":"deny_all","egress":"restricted","allow_sbos_only":true}',
 'Red default: deny-all ingress, egress restringido a SBOS.',
 ARRAY['SBOS-054 §6','CIS K8s Benchmark']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D8 — DOMINIO CONTEXTO: session_ttl, inactivity, reauth, ctx_id, caep
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d8 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d8 (config_key, config_value, description, standard_ref) VALUES
('session_ttl_max', '{"default_s":28800,"su_s":14400,"m2m_s":86400,"absolute_max_s":43200}',
 'TTL sesión: default 8h, SU 4h, M2M 24h, máx 12h.',
 ARRAY['NIST SP 800-63B §7','OWASP ASVS V3.3']),
('inactivity_timeout', '{"default_min":15,"su_min":10,"break_glass_min":240,"lock_screen":true}',
 'Inactividad: default 15min, SU 10min, break-glass 4h. Bloquear pantalla.',
 ARRAY['NIST SP 800-63B §7','ISO 27001 A.9.4']),
('reauth_timeout', '{"default_hours":4,"for_sensitive":true,"step_up_ops":["financial_approval","security_change"]}',
 'Reauth cada 4h. Step-up para aprobación financiera y cambio seguridad.',
 ARRAY['NIST SP 800-63B §7','RFC 9470']),
('max_contexts', '{"per_user":5,"per_session":1,"switch_allowed":true,"max_switches":20}',
 'Contextos: 5 por usuario, 1 activo por sesión, 20 cambios máx.',
 ARRAY['SBOS-049','NIST SP 800-207']),
('ctx_id_format', '{"uuid_version":7,"propagation":"w3c_traceparent","cache":"redis_db0","ttl_sync_with_session":true}',
 'ctx_id: UUIDv7, W3C traceparent, Redis DB0. TTL = sesión.',
 ARRAY['SBOS-049','W3C Trace Context']),
('caep_config', '{"event_types":["session-revoked","assurance-change","device-change"],"target_latency_ms":500,"require_ack":true}',
 'CAEP: 3 eventos, latencia <500ms, ACK requerido.',
 ARRAY['OpenID CAEP 1.0','SBOS-049']),
('dctx_ttl', '{"pre_auth_s":300,"reject_if_expired":true,"auto_cleanup":true}',
 'dctx_id: 300s pre-auth, rechazar expirado, auto-limpieza.',
 ARRAY['SBOS-049 §3','NIST SP 800-207']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D9 — DOMINIO CREDENCIALES: password, hibp, lockout, rotation, mfa, recovery
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d9 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d9 (config_key, config_value, description, standard_ref) VALUES
('password_min_length', '{"SU":20,"SYS":15,"BIZ":12,"EXT":8,"M2M":0,"no_complexity_rules":true}',
 'Longitud mín: SU 20, SYS 15, BIZ 12, EXT 8. Sin reglas complejidad (NIST Rev.4).',
 ARRAY['NIST SP 800-63B §5.1.1.2','OWASP ASVS V2.1']),
('hibp_enabled', '{"on_registration":true,"on_change":true,"check_daily":true,"method":"k_anonymity","block_if_pwned":true}',
 'HIBP: al registrar, cambiar, diario. k-anonymity. Bloquear si comprometida.',
 ARRAY['NIST SP 800-63B §5.1.1.2','OWASP ASVS V2.1.7']),
('lockout_levels', '{"thresholds":[{"attempts":5,"min":15},{"attempts":10,"min":60},{"attempts":20,"permanent":true}],"counter_reset_min":30,"notify":true}',
 'Bloqueo: 5→15min, 10→1h, 20→perm. Reset 30min sin intentos.',
 ARRAY['NIST SP 800-63B §5.2.2','OWASP ASVS V2.2']),
('rotation_days', '{"service_passwords":90,"api_keys":90,"mtls_certs_h":24,"human_passwords":0,"human":"no_forced"}',
 'Rotación: servicio 90d, API 90d, mTLS 24h. Sin rotación forzada humana.',
 ARRAY['NIST SP 800-63B §5.1.1.2','NIST SP 800-57']),
('mfa_grace_period', '{"days":7,"reminders":[1,3,7],"block_after_expiry":true,"allow_recovery_during_grace":true}',
 'Gracia MFA: 7d enrolar, recordatorios día 1,3,7. Bloquear tras expirar.',
 ARRAY['NIST SP 800-63B §5.1','OWASP ASVS V2.8']),
('recovery_codes', '{"count":10,"hash":"sha256","single_use":true,"show_once":true,"regenerate_on_depletion":true}',
 'Códigos recuperación: 10, SHA-256, un uso, mostrar una vez.',
 ARRAY['NIST SP 800-63B §5.1.6','OWASP ASVS V2.5']),
('step_up_max_duration', '{"elevation_min":15,"reuse_in_window":false,"audit_every":true,"methods":{"AAL2":"TOTP","AAL3":"FIDO2_HW"}}',
 'Step-Up: 15min máx, auditoría obligatoria. AAL2→TOTP, AAL3→FIDO2 HW.',
 ARRAY['RFC 9470','NIST SP 800-63B §5.1']),
('argon2id_params', '{"SU":{"t":5,"m":128,"p":1},"SYS":{"t":4,"m":64,"p":1},"BIZ":{"t":3,"m":32,"p":1},"EXT":{"t":2,"m":16,"p":1}}',
 'Argon2id: SU t=5,128MB; SYS t=4,64MB; BIZ t=3,32MB; EXT t=2,16MB.',
 ARRAY['OWASP ASVS V6.2','NIST SP 800-63B']),
('token_binding', '{"SU":"mtls","SYS":"dpop","M2M":"mtls","pkce_for_public":true,"dpop_for_sys":true}',
 'Binding token: SU/M2M mTLS, SYS DPoP. PKCE clientes públicos.',
 ARRAY['RFC 8705','RFC 9449','OAuth 2.1 BCP']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D10 — DOMINIO DELEGACIÓN: max_duration, max_concurrent, auto_revoke
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d10 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d10 (config_key, config_value, description, standard_ref) VALUES
('max_duration_h', '{"standard":504,"extended":2160,"emergency":4}',
 'Delegación: estándar 21d (504h), extendida 90d, emergencia 4h.',
 ARRAY['NIST SP 800-53 AC-2(2)','ISO 27001 A.9.2']),
('max_concurrent', '{"per_granter":5,"per_grantee":3,"per_tenant":100}',
 'Concurrentes: 5 por delegante, 3 por delegado, 100 por tenant.',
 ARRAY['NIST SP 800-53 AC-2','ISO 27001 A.9.2']),
('auto_revoke', '{"on_granter_deactivated":true,"on_role_changed":true,"on_grantee_deactivated":true,"delay_s":0}',
 'Auto-revocación inmediata: desactivar delegante, cambiar rol, desactivar delegado.',
 ARRAY['NIST SP 800-53 AC-2','SOX §404']),
('non_delegable_list', '{"atoms":["SU_ACTIVATE","BREAK_GLASS","CHANGE_SECURITY","DELETE_AUDIT"],"roles":["SU","S002","S003"]}',
 'No delegable: SU, break-glass, cambio seguridad, eliminar auditoría.',
 ARRAY['NIST SP 800-53 AC-5','SOX §404']),
('chain_depth_max', '{"default":1,"with_security_approval":2,"absolute_max":2}',
 'Redelegación: 1 nivel default, 2 con aprobación seguridad.',
 ARRAY['NIST SP 800-53 AC-2']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D11 — DOMINIO AUDITORÍA: retention, hash_chain, review, worm, compliance
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d11 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d11 (config_key, config_value, description, standard_ref) VALUES
('retention_days_default', '{"auth_events":365,"audit_events":3650,"pii_data":2555,"session_logs":365}',
 'Retención: auth 1a, auditoría 10a, PII 7a (2555d Ley 2492), sesiones 1a.',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.7','Ley 2492 Bolivia','RGPD Art.17']),
('hash_chain_default', '{"algorithm":"sha256","per_ctx_id":true,"verification_hours":1}',
 'Hash-chain: SHA-256 por ctx_id, verificación cada 1h.',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.5','NIST SP 800-53 AU-9']),
('review_frequency_default', '{"SU":"monthly","SYS":"monthly","BIZ_N4_N5":"quarterly","BIZ_N1_N3":"semi_annual","EXT":"annual","M2M":"quarterly","escalation_days":14}',
 'Revisión: SU/SYS mensual, BIZ alto trimestral, EXT anual. Escala 14d.',
 ARRAY['ISO 27001 A.9.2.5','NIST SP 800-53 AC-6','SOX §404']),
('worm_enforcement', '{"revoke_update":true,"revoke_delete":true,"partition_by_month":true,"auto_partitions":true}',
 'WORM: REVOKE UPDATE/DELETE, partición mensual automática.',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.5']),
('compliance_frameworks', '{"iso_27001":["A.8.15","A.8.16","A.9.2"],"pci_dss":["10.1","10.2","10.3","10.5"],"sox":["302","404"],"gdpr":["Art.30","Art.33"],"nist_800_53":["AU-2","AU-3","AU-9"]}',
 'Marcos: ISO 27001, PCI-DSS, SOX, GDPR, NIST 800-53.',
 ARRAY['ISO 27001','PCI-DSS 4.0','SOX §404','RGPD','NIST SP 800-53']),
('purge_policy', '{"method":"drop_partition","anonymize_before":true,"legal_hold_override":true,"pre_purge_verification":true}',
 'Purgado: DROP PARTITION, anonimizar, respetar legal hold.',
 ARRAY['RGPD Art.17','ISO 27001 A.8.15']);

-- ═══════════════════════════════════════════════════════════════════════════
-- D12 — DOMINIO BLOCKCHAIN: anchor_frequency, gas, network, contract, merkle, validators
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_config_d12 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_config_d12 (config_key, config_value, description, standard_ref) VALUES
('anchor_frequency', '{"interval_s":3600,"tier":"gold","max_batch":1000,"max_delay_s":7200}',
 'Anclaje: cada 3600s (1h), Gold tier, lote 1000, retraso máx 2h.',
 ARRAY['RFC 6962','NIST IR 8202','EVALUACION GA-03']),
('gas_limit', '{"anchor_tx":100000,"max_priority_fee_gwei":1,"max_fee_per_gas_gwei":50,"buffer_pct":20}',
 'Gas: 100K/tx, priority 1 gwei, fee máx 50 gwei, buffer 20%.',
 ARRAY['EIP-1559']),
('network', '{"anchor":"arbitrum_one","settlement":"besu_qbft_private","testnet":"arbitrum_sepolia","chain_ids":{"arbitrum_one":42161,"sepolia":421614,"besu":2026}}',
 'Redes: Arbitrum One (anclaje), Besu QBFT (liquidación).',
 ARRAY['EVALUACION GB-01','EIP-1559']),
('contract_address', '{"arbitrum_one":"0x0","arbitrum_sepolia":"0x0","note":"Actualizar tras deploy con forge create"}',
 'Direcciones smart contracts. Pendientes de deploy.',
 ARRAY['Solidity 0.8.26','OpenZeppelin']),
('merkle_tree', '{"hash":"keccak256","structure":"binary_rfc6962","leaf_domain":"0x00","node_domain":"0x01"}',
 'Merkle: Keccak-256, binario RFC 6962, domain separation.',
 ARRAY['RFC 6962 §2.1','NIST IR 8202']),
('besu_validators', '{"count":4,"consensus":"qbft","block_s":2,"gas_limit":134217727,"min_gas_price":0,"fault_tolerance":1}',
 'Besu: 4 validadores, QBFT, bloque 2s, f=1.',
 ARRAY['Hyperledger Besu','EVALUACION GB-01']),
('reconciliation', '{"frequency_min":15,"diff_tolerance":0.01,"forensic_replay":true,"alert_on_diff":true}',
 'Reconciliación on-chain: cada 15min, tolerancia ±0.01.',
 ARRAY['EVALUACION GB-11','ISO 20022']);

COMMIT;
