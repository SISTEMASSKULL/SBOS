-- ============================================================================
-- SEED: Templates de Rol por Dominio — idn_role_d1 a idn_role_d12
-- Arquitectura de merge: el admin selecciona 1 template por dominio
-- merge_role_templates() conjuga 12 → 1 idn_role_template (14 secciones JSONB)
-- Fuente: BAUTH-ROLTEMPLATE-SECCIONES.md v6.0
--         BAUTH-CRUD-ROLES-USUARIOS.md v3.0
--         COMMENT ON TABLE idn_role_d{n} en DDL_skSBOS_db.sql
-- Idempotente: TRUNCATE + RESTART IDENTITY CASCADE + INSERT
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- D1 — DOMINIO LÓGICO: OPERADOR_CAJA, GERENTE_REGIONAL, AUDITOR, VISOR_BASICO
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d1 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d1 (role_code, role_name, domain_code, config, description) VALUES
('D1-OPERADOR-CAJA', '{"es":"Operador de Caja","en":"Cashier Operator"}', 1,
 '{"logical_access":{"zones":[{"zone":"AREA-CAJA","scope":"branch","max_records":200,"classification":"internal","applications":[{"app":"Tryton","modules":[{"module":"sale_pos","verbs":["READ","WRITE","EXECUTE"]},{"module":"account_invoice","verbs":["READ"]},{"module":"account_payment","verbs":["READ","WRITE"]},{"module":"party","verbs":["READ"]}],"hidden_fields":["margin","cost_price"],"button_limits":{"confirm":5000}},{"app":"Superset","modules":[{"module":"caja_diaria","verbs":["READ"]},{"module":"ventas_sucursal","verbs":["READ"]}]},{"app":"Mattermost","modules":[{"module":"#cajas","verbs":["READ"]},{"module":"#sucursal-central","verbs":["READ"]}]}]}]}}',
 'Operador de caja: acceso a POS, facturación básica y pagos en zona de caja. Scope sucursal.'),

('D1-GERENTE-REGIONAL', '{"es":"Gerente Regional","en":"Regional Manager"}', 1,
 '{"logical_access":{"zones":[{"zone":"AREA-GERENCIA","scope":"region","max_records":1000,"classification":"confidential","applications":[{"app":"Tryton","modules":[{"module":"sale_pos","verbs":["READ"]},{"module":"account_invoice","verbs":["READ"]},{"module":"account_report","verbs":["READ","EXECUTE"]},{"module":"hr_employee","verbs":["READ"]}],"button_limits":{}},{"app":"Superset","modules":[{"module":"ventas_region","verbs":["READ","EXECUTE"]},{"module":"performance_equipo","verbs":["READ"]},{"module":"p&l_mensual","verbs":["READ"]}]}]}]}}',
 'Gerente regional: vista consolidada de todas las sucursales de la región. Sin acceso a escritura.'),

('D1-AUDITOR', '{"es":"Auditor","en":"Auditor"}', 1,
 '{"logical_access":{"zones":[{"zone":"AREA-AUDITORIA","scope":"enterprise","max_records":5000,"classification":"confidential","applications":[{"app":"Tryton","modules":[{"module":"account_invoice","verbs":["READ"]},{"module":"account_payment","verbs":["READ"]},{"module":"account_report","verbs":["READ","EXECUTE"]},{"module":"audit_trail","verbs":["READ","EXECUTE"]}],"all_fields_visible":true,"button_limits":{}},{"app":"Superset","modules":[{"module":"auditoria_general","verbs":["READ","EXECUTE"]}]}]}]}}',
 'Auditor: acceso solo lectura a todos los registros de la empresa. Sin botones de modificación.'),

('D1-VISOR-BASICO', '{"es":"Visor Básico","en":"Basic Viewer"}', 1,
 '{"logical_access":{"zones":[{"zone":"AREA-PUBLICA","scope":"branch","max_records":50,"classification":"public","applications":[{"app":"Superset","modules":[{"module":"dashboard_publico","verbs":["READ"]}]}]}]}}',
 'Visor básico: acceso mínimo solo lectura a dashboards públicos. Para roles externos y visitantes.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D2 — DOMINIO FÍSICO: EMPLEADO_STANDARD, VISITANTE, TECNICO, SUPERVISOR_SEGURIDAD
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d2 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d2 (role_code, role_name, domain_code, config, description) VALUES
('D2-EMPLEADO-STANDARD', '{"es":"Empleado Estándar","en":"Standard Employee"}', 2,
 '{"physical_access":{"buildings":[{"building":"HQ Central","floors":[{"floor":"Planta Baja","areas":[{"area":"Piso de Ventas","zone":"PHY_ZONE_VENTAS","level":2,"access":"FULL","methods":["NFC","QR","HUELLA"],"schedule":"business_hours"},{"area":"Cafetería","zone":"PHY_ZONE_CAFETERIA","level":1,"access":"FULL","methods":["NFC","QR"]}]},{"floor":"Piso 4","areas":[{"area":"Oficinas","zone":"PHY_ZONE_OFICINAS","level":2,"access":"FULL","methods":["NFC","QR"]}]}]}],"anti_passback":true,"require_escort":false}}',
 'Empleado estándar: acceso a zonas de ventas, cafetería y oficinas. Anti-passback activo.'),

('D2-VISITANTE', '{"es":"Visitante","en":"Visitor"}', 2,
 '{"physical_access":{"buildings":[{"building":"HQ Central","floors":[{"floor":"Planta Baja","areas":[{"area":"Recepción","zone":"PHY_ZONE_RECEPCION","level":1,"access":"TEMPORAL","methods":["QR"],"schedule":"business_hours","max_duration_hours":12}]}]}],"anti_passback":true,"require_escort":true}}',
 'Visitante: acceso solo a recepción con escolta. QR temporal, 12h máximo.'),

('D2-TECNICO-MANTENIMIENTO', '{"es":"Técnico de Mantenimiento","en":"Maintenance Technician"}', 2,
 '{"physical_access":{"buildings":[{"building":"HQ Central","floors":[{"floor":"Planta Baja","areas":[{"area":"Cuarto de Servidores","zone":"PHY_ZONE_SERVIDORES","level":4,"access":"FULL","methods":["NFC","HUELLA"],"schedule":"extended_hours"},{"area":"Cuarto Eléctrico","zone":"PHY_ZONE_ELECTRICO","level":3,"access":"FULL","methods":["NFC"]}]},{"floor":"Sótano","areas":[{"area":"Cuarto de Máquinas","zone":"PHY_ZONE_MAQUINAS","level":3,"access":"FULL","methods":["NFC"]}]}]}],"anti_passback":true,"require_escort":false,"alarm_bypass":true}}',
 'Técnico: acceso a zonas de infraestructura (servidores, eléctrico, máquinas). Bypass de alarmas.'),

('D2-SUPERVISOR-SEGURIDAD', '{"es":"Supervisor de Seguridad","en":"Security Supervisor"}', 2,
 '{"physical_access":{"all_zones":true,"level":5,"access":"FULL","methods":["NFC","QR","HUELLA","PIN"],"schedule":"24x7","alarm_management":true,"emergency_override":true,"cctv_access":true}}',
 'Supervisor de seguridad: acceso total a todas las zonas. Gestión de alarmas y emergencias.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D3 — DOMINIO FINANCIERO: CAJERO, APROBADOR_N1, APROBADOR_N2, AUDITOR_FINANCIERO
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d3 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d3 (role_code, role_name, domain_code, config, description) VALUES
('D3-CAJERO', '{"es":"Cajero","en":"Cashier"}', 3,
 '{"financial":{"transaction_types":[{"type":"FAC_EMITIR","limit":{"per_operation_bob":2000,"daily_bob":20000},"requires_dual":false,"sod":"creador_no_aprobador"},{"type":"COBRO_RECIBIR","limit":{"per_operation_bob":5000,"daily_bob":50000},"max_efectivo":50000,"requires_dual":false},{"type":"CIERRE_CAJA","limit":{},"cuadre_obligatorio":true,"max_diferencia_bob":100,"deposito_banco_24h":true},{"type":"APERTURA_CAJA","limit":{},"requiere_supervisor":false}],"currency":"BOB","approval_chain_level":1}}',
 'Cajero: facturación hasta Bs 2,000, cobros hasta Bs 5,000. Cierre de caja con cuadre obligatorio.'),

('D3-APROBADOR-N1', '{"es":"Aprobador Nivel 1","en":"Level 1 Approver"}', 3,
 '{"financial":{"transaction_types":[{"type":"FAC_EMITIR","limit":{"per_operation_bob":10000},"requires_dual":true,"sod":"aprobador_no_creador"},{"type":"PAGO_APROBAR","limit":{"per_operation_bob":50000,"daily_bob":200000},"requires_dual":true,"approval_timeout_h":4},{"type":"NC_EMITIR","limit":{"per_operation_bob":5000},"requires_dual":true}],"currency":"BOB","approval_chain_level":1,"can_approve_level":1}}',
 'Aprobador N1: autoriza transacciones hasta Bs 10,000. Timeout 4h, escala automática.'),

('D3-APROBADOR-N2', '{"es":"Aprobador Nivel 2","en":"Level 2 Approver"}', 3,
 '{"financial":{"transaction_types":[{"type":"FAC_EMITIR","limit":{"per_operation_bob":100000},"requires_dual":true,"requires_n1_first":true},{"type":"PAGO_APROBAR","limit":{"per_operation_bob":500000},"requires_dual":true,"approval_timeout_h":8}],"currency":"BOB","approval_chain_level":2,"can_approve_level":2}}',
 'Aprobador N2: autoriza transacciones hasta Bs 100,000. Requiere N1 previo. Timeout 8h.'),

('D3-AUDITOR-FINANCIERO', '{"es":"Auditor Financiero","en":"Financial Auditor"}', 3,
 '{"financial":{"transaction_types":[{"type":"AUDITORIA","limit":{},"read_only":true,"all_transactions_visible":true}],"currency":"ALL","approval_chain_level":0,"can_approve":false,"can_initiate":false,"can_view_all":true,"sod":"sin_conflicto_operativo"}}',
 'Auditor financiero: solo lectura sobre todas las transacciones. Sin capacidad de iniciar ni aprobar.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D4 — DOMINIO TEMPORAL: HORARIO_OFICINA, TURNO_ROTATIVO, GUARDIA_24X7, FLEXIBLE
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d4 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d4 (role_code, role_name, domain_code, config, description) VALUES
('D4-HORARIO-OFICINA', '{"es":"Horario de Oficina","en":"Office Hours"}', 4,
 '{"temporal":{"schedule":{"days":[1,2,3,4,5],"hours":[{"start":"08:00","end":"12:00"},{"start":"14:00","end":"18:00"}],"timezone":"America/La_Paz"},"breaks":[{"name":"almuerzo","start":"12:00","duration_min":120}],"overtime_allowed":false,"holidays":"national_and_regional","session_ttl_hours":8,"inactivity_timeout_min":15}}',
 'Horario de oficina: Lun-Vie 8-12/14-18, almuerzo 2h. Sin horas extra. Feriados nacionales.'),

('D4-TURNO-ROTATIVO', '{"es":"Turno Rotativo","en":"Rotating Shift"}', 4,
 '{"temporal":{"schedule":{"days":[1,2,3,4,5,6],"shifts":[{"name":"mañana","start":"06:00","end":"14:00"},{"name":"tarde","start":"14:00","end":"22:00"},{"name":"noche","start":"22:00","end":"06:00"}],"rotation_days":7,"timezone":"America/La_Paz"},"breaks":[{"name":"descanso","duration_min":30,"per_shift":1}],"overtime_allowed":true,"overtime_rate":1.5,"holidays":"national","session_ttl_hours":12}}',
 'Turno rotativo: 3 turnos de 8h con rotación semanal. Horas extra ×1.5. Sin feriados regionales.'),

('D4-GUARDIA-24X7', '{"es":"Guardia 24x7","en":"24x7 Guard"}', 4,
 '{"temporal":{"schedule":{"days":[1,2,3,4,5,6,7],"hours":[{"start":"00:00","end":"23:59"}],"timezone":"America/La_Paz"},"breaks":[{"name":"descanso","duration_min":60,"per_shift":2}],"overtime_allowed":true,"overtime_rate":2.0,"night_rate":2.5,"holidays":"all_including_regional","session_ttl_hours":12,"inactivity_timeout_min":30}}',
 'Guardia 24x7: acceso continuo todos los días. Horas extra ×2.0, nocturna ×2.5. Todos los feriados.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D5 — DOMINIO BIOMÉTRICO: HUELLA_DACTILAR, RECONOCIMIENTO_FACIAL, SIN_BIOMETRIA
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d5 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d5 (role_code, role_name, domain_code, config, description) VALUES
('D5-HUELLA-DACTILAR', '{"es":"Huella Dactilar","en":"Fingerprint"}', 5,
 '{"biometric":{"method":"fingerprint","fmr_threshold":0.0001,"fnmr_threshold":0.01,"liveness":"passive","quality_min_score":80,"min_resolution_dpi":500,"enrollment_supervised":true,"max_templates_per_user":10,"template_retention":"delete_on_offboarding","gdpr_consent_required":true,"attestation_required":false}}',
 'Huella dactilar: FMR 0.01%, calidad ≥80, enrollment supervisado. GDPR consentimiento obligatorio.'),

('D5-RECONOCIMIENTO-FACIAL', '{"es":"Reconocimiento Facial","en":"Facial Recognition"}', 5,
 '{"biometric":{"method":"face","fmr_threshold":0.001,"fnmr_threshold":0.01,"liveness":"active_and_passive","active_challenges":["blink","smile","turn_head"],"quality_min_score":85,"min_resolution":"1080p","max_pose_angle":15,"enrollment_supervised":true,"max_templates_per_user":5,"template_retention":"delete_on_offboarding","gdpr_consent_required":true,"attestation_required":true}}',
 'Reconocimiento facial: FMR 0.1%, liveness activo+pasivo, calidad ≥85. Atestación requerida.'),

('D5-SIN-BIOMETRIA', '{"es":"Sin Biometría","en":"No Biometrics"}', 5,
 '{"biometric":{"enabled":false,"reason":"no_sensor_or_consent","fallback_methods":["TOTP","PASSKEY_DEVICE"]}}',
 'Sin biometría: para usuarios sin sensor biométrico o que no consienten. Fallback a TOTP/Passkey.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D6 — DOMINIO GEOESPACIAL: LOCAL_BOLIVIA, REGIONAL_LATAM, GLOBAL, RESTRINGIDO_SUCURSAL
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d6 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d6 (role_code, role_name, domain_code, config, description) VALUES
('D6-LOCAL-BOLIVIA', '{"es":"Local Bolivia","en":"Bolivia Only"}', 6,
 '{"geospatial":{"countries":["BO"],"trust_tiers":[{"name":"oficina_corporativa","trust":0.95},{"name":"sucursal_registrada","trust":0.85},{"name":"home_office_bo","trust":0.70}],"velocity_max_kmh":900,"geo_fence_required":true,"jurisdiction":"BO","cross_border_blocked":true,"ip_geolocation_required":true}}',
 'Local Bolivia: acceso solo desde Bolivia. Trust alto en oficinas, medio en home office.'),

('D6-REGIONAL-LATAM', '{"es":"Regional LATAM","en":"LATAM Regional"}', 6,
 '{"geospatial":{"countries":["BO","AR","CL","PE","BR","CO","EC","PY","UY"],"trust_tiers":[{"name":"oficina_pais","trust":0.90},{"name":"viaje_negocios","trust":0.65},{"name":"remoto_latam","trust":0.50}],"velocity_max_kmh":900,"geo_fence_required":false,"jurisdiction":"MULTI","cross_border_allowed":true,"ip_geolocation_required":true}}',
 'Regional LATAM: acceso desde 9 países de Sudamérica. Trust medio en viajes y remoto.'),

('D6-RESTRINGIDO-SUCURSAL', '{"es":"Restringido a Sucursal","en":"Branch Restricted"}', 6,
 '{"geospatial":{"countries":["BO"],"trust_tiers":[{"name":"sucursal_asignada","trust":0.98}],"velocity_max_kmh":100,"geo_fence_required":true,"geo_fence_radius_m":100,"jurisdiction":"BO","cross_border_blocked":true,"ip_geolocation_required":true,"block_outside_fence":true}}',
 'Restringido a sucursal: solo desde la sucursal asignada. Geo-cerca 100m. Bloqueo fuera de fence.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D7 — DOMINIO RED: CORPORATIVO, VPN, REMOTO_SEGURO, ZTNA_BASICO
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d7 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d7 (role_code, role_name, domain_code, config, description) VALUES
('D7-CORPORATIVO', '{"es":"Corporativo","en":"Corporate"}', 7,
 '{"network":{"cidr":["10.0.1.0/24","10.0.2.0/24"],"device_trust_min":80,"vpn_required":false,"mtls_required":true,"ztna_enabled":true,"continuous_verification":true,"allowed_protocols":["https","wss"],"block_tor":true,"block_vpn_external":true}}',
 'Corporativo: red interna 10.0.x.x, device trust ≥80. mTLS y ZTNA. Sin VPN requerida.'),

('D7-VPN', '{"es":"VPN Corporativa","en":"Corporate VPN"}', 7,
 '{"network":{"cidr":["172.16.0.0/16"],"device_trust_min":70,"vpn_required":true,"vpn_type":"wireguard","device_cert_required":true,"mtls_required":true,"ztna_enabled":true,"session_max_hours":12,"continuous_verification":true}}',
 'VPN: WireGuard obligatorio, certificado de dispositivo. Trust ≥70. Sesión 12h máx.'),

('D7-REMOTO-SEGURO', '{"es":"Remoto Seguro","en":"Secure Remote"}', 7,
 '{"network":{"cidr":[],"device_trust_min":85,"vpn_required":true,"vpn_type":"wireguard","device_cert_required":true,"mtls_required":true,"ztna_enabled":true,"allow_public_wifi":false,"require_encrypted_dns":true,"continuous_verification":true,"grace_period_s":30}}',
 'Remoto seguro: VPN obligatoria, no WiFi público, DNS cifrado, trust ≥85. Solo desde dispositivo certificado.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D8 — DOMINIO CONTEXTO: SESION_8H, SESION_EXTENDIDA, BREAK_GLASS, READ_ONLY
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d8 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d8 (role_code, role_name, domain_code, config, description) VALUES
('D8-SESION-8H', '{"es":"Sesión 8 Horas","en":"8 Hour Session"}', 8,
 '{"context":{"session_ttl_seconds":28800,"inactivity_timeout_seconds":900,"reauth_timeout_seconds":14400,"max_contexts":3,"context_switch_allowed":true,"caep_events":["session-revoked","assurance-change"],"ctx_id_propagation":"w3c_traceparent","dctx_required":true}}',
 'Sesión 8h: estándar NIST 800-63B. Reauth cada 4h. Hasta 3 contextos. CAEP eventos básicos.'),

('D8-SESION-EXTENDIDA', '{"es":"Sesión Extendida","en":"Extended Session"}', 8,
 '{"context":{"session_ttl_seconds":43200,"inactivity_timeout_seconds":1800,"reauth_timeout_seconds":28800,"max_contexts":5,"context_switch_allowed":true,"caep_events":["session-revoked","assurance-change","device-change"],"ctx_id_propagation":"w3c_traceparent","dctx_required":true}}',
 'Sesión extendida: 12h máximo. Inactividad 30min. Reauth cada 8h. 5 contextos.'),

('D8-BREAK-GLASS', '{"es":"Break-Glass Emergencia","en":"Break-Glass Emergency"}', 8,
 '{"context":{"session_ttl_seconds":14400,"inactivity_timeout_seconds":14400,"reauth_timeout_seconds":0,"max_contexts":1,"context_switch_allowed":false,"caep_events":["session-revoked","assurance-change","device-change","risk-score-change"],"emergency_override":true,"vault_2of3_unseal":true,"session_recording":true,"post_event_audit_24h":true,"dctx_required":false}}',
 'Break-Glass: 4h máximo, sin timeout inactividad, Vault 2-of-3. Auditoría post-evento en 24h.'),

('D8-READ-ONLY', '{"es":"Solo Lectura","en":"Read Only"}', 8,
 '{"context":{"session_ttl_seconds":14400,"inactivity_timeout_seconds":600,"reauth_timeout_seconds":7200,"max_contexts":1,"context_switch_allowed":false,"caep_events":["session-revoked"],"read_only_mode":true,"dctx_required":true}}',
 'Solo lectura: sesión 4h, inactividad 10min. Sin cambios de contexto. Solo consultas.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D9 — DOMINIO CREDENCIALES: AAL1_BASICO, AAL2_MFA, AAL3_HARDWARE, M2M_MTLS
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d9 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d9 (role_code, role_name, domain_code, config, description) VALUES
('D9-AAL1-BASICO', '{"es":"AAL1 Básico","en":"AAL1 Basic"}', 9,
 '{"credentials":{"methods":[{"method":"PASSWORD","required":true,"position":1}],"flow":"password_only","alternatives":[],"policies":["PWD_MIN_LENGTH_8","PWD_HIBP_CHECK"],"session_ttl_hours":8,"step_up_available":false,"mfa_grace_days":0}}',
 'AAL1: solo contraseña con verificación HIBP. Para roles externos N0. Sin MFA ni step-up.'),

('D9-AAL2-MFA', '{"es":"AAL2 MFA","en":"AAL2 Multi-Factor"}', 9,
 '{"credentials":{"methods":[{"method":"PASSWORD","required":true,"position":1},{"method":"TOTP","required":true,"position":2}],"flow":"password_then_totp","alternatives":[{"primary":"TOTP","fallback":"BACKUP_CODES","requires_approval":false}],"policies":["PWD_MIN_LENGTH_12","PWD_HIBP_CHECK","PWD_NO_ROTATION","AAL2_REQUIRED","PHISH_FIDO2","PROGRESSIVE_LOCKOUT","TIMEOUT_8H","CONCURRENT_1","RECOVERY_MFA"],"session_ttl_hours":8,"step_up_available":true,"mfa_grace_days":7}}',
 'AAL2: contraseña + TOTP. 9 políticas aplicadas. Step-up disponible. Gracia MFA 7 días.'),

('D9-AAL3-HARDWARE', '{"es":"AAL3 Hardware","en":"AAL3 Hardware"}', 9,
 '{"credentials":{"methods":[{"method":"PASSWORD","required":true,"position":1},{"method":"WEBAUTHN_PWDLESS","required":true,"position":2},{"method":"PASSKEY_DEVICE","required":true,"position":3}],"flow":"password_webauthn_passkey","alternatives":[{"primary":"PASSKEY_DEVICE","fallback":"SMARTCARD_X509","requires_approval":true}],"policies":["PWD_MIN_LENGTH_20","PWD_HIBP_CHECK","PWD_NO_ROTATION","AAL3_REQUIRED","PHISH_FIDO2","FIDO2_HW_ONLY","PROGRESSIVE_LOCKOUT","TIMEOUT_4H","CONCURRENT_1","RECOVERY_MFA"],"session_ttl_hours":4,"step_up_available":false,"mfa_grace_days":0}}',
 'AAL3: contraseña + WebAuthn + Passkey device-bound. 10 políticas. Sesión 4h. Sin step-up (ya es máximo).'),

('D9-M2M-MTLS', '{"es":"M2M mTLS","en":"M2M mTLS"}', 9,
 '{"credentials":{"methods":[{"method":"CLIENT_CREDENTIALS","required":true,"position":1},{"method":"MTLS","required":true,"position":0}],"flow":"mtls_client_credentials","alternatives":[{"primary":"CLIENT_CREDENTIALS","fallback":"TOKEN_EXCHANGE","requires_approval":false}],"policies":["NO_PASSWORD","MTLS_REQUIRED","CERT_TTL_24H","AUTO_ROTATION","NO_HUMAN_LOGIN"],"session_ttl_hours":24,"step_up_available":false,"mfa_grace_days":0}}',
 'M2M: mTLS + client_credentials. Sin password. Certificados 24h auto-rotativos.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D10 — DOMINIO DELEGACIÓN: SIN_DELEGACION, DELEGACION_BASICA, DELEGACION_SUPERVISOR
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d10 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d10 (role_code, role_name, domain_code, config, description) VALUES
('D10-SIN-DELEGACION', '{"es":"Sin Delegación","en":"No Delegation"}', 10,
 '{"delegation":{"enabled":false,"reason":"rol_operativo_sin_necesidad"}}',
 'Sin delegación: roles operativos que no requieren delegar autoridad.'),

('D10-DELEGACION-BASICA', '{"es":"Delegación Básica","en":"Basic Delegation"}', 10,
 '{"delegation":{"enabled":true,"max_duration_days":7,"max_chain_depth":1,"auto_revoke_on_expiry":true,"allowed_target_roles":["mismo_nivel"],"require_approval":false,"non_delegable_atoms":["DELETE","SECURITY_CHANGE"]}}',
 'Delegación básica: 7 días máximo, sin redelegación. Auto-revocación. Átomos críticos excluidos.'),

('D10-DELEGACION-SUPERVISOR', '{"es":"Delegación Supervisor","en":"Supervisor Delegation"}', 10,
 '{"delegation":{"enabled":true,"max_duration_days":21,"max_chain_depth":1,"auto_revoke_on_expiry":true,"allowed_target_roles":["mismo_nivel","nivel_inferior"],"require_approval":true,"approver":"manager","non_delegable_atoms":["DELETE","SECURITY_CHANGE","FINANCIAL_APPROVAL"]}}',
 'Delegación supervisor: 21 días, requiere aprobación del manager. Átomos financieros excluidos.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D11 — DOMINIO AUDITORÍA: BASICO, COMPLETO, SOX, PCI_DSS, GDPR
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d11 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d11 (role_code, role_name, domain_code, config, description) VALUES
('D11-BASICO', '{"es":"Auditoría Básica","en":"Basic Audit"}', 11,
 '{"audit":{"level":"basic","event_types":["AUTHENTICATION","AUTHORIZATION"],"retention_months":12,"hash_chain":false,"review_frequency":"annual","frameworks":["ISO_27001_A.8.15"],"worm_enabled":true}}',
 'Auditoría básica: solo auth y autorización. Retención 12m. Sin hash-chain.'),

('D11-COMPLETO', '{"es":"Auditoría Completa","en":"Full Audit"}', 11,
 '{"audit":{"level":"full","event_types":["AUTHENTICATION","AUTHORIZATION","DATA_ACCESS","CONFIG_CHANGE","DELEGATION"],"retention_years":10,"hash_chain":true,"hash_algorithm":"sha256","review_frequency":"quarterly","frameworks":["ISO_27001","NIST_800-53","SOX_404"],"worm_enabled":true,"blockchain_anchor":true}}',
 'Auditoría completa: todos los eventos, 10 años, hash-chain SHA-256, anclaje blockchain.'),

('D11-SOX', '{"es":"Cumplimiento SOX","en":"SOX Compliance"}', 11,
 '{"audit":{"level":"full","event_types":["AUTHENTICATION","AUTHORIZATION","DATA_ACCESS","CONFIG_CHANGE","DELEGATION","ROLE_ASSIGNMENT"],"retention_years":7,"hash_chain":true,"hash_algorithm":"sha256","review_frequency":"quarterly","frameworks":["SOX_302","SOX_404","COSO"],"worm_enabled":true,"blockchain_anchor":true,"requires_manager_signoff":true}}',
 'SOX: 7 años retención, hash-chain, revisión trimestral con firma del manager. Anclaje blockchain.'),

('D11-GDPR', '{"es":"Cumplimiento GDPR","en":"GDPR Compliance"}', 11,
 '{"audit":{"level":"full","event_types":["AUTHENTICATION","AUTHORIZATION","DATA_ACCESS","CONSENT"],"retention":"minimum_necessary","hash_chain":true,"review_frequency":"semi_annual","frameworks":["GDPR_Art30","GDPR_Art33"],"worm_enabled":true,"anonymize_pii_on_export":true,"right_to_erasure":true,"breach_notification_72h":true}}',
 'GDPR: retención mínima necesaria, anonimización PII, derecho al olvido, notificación 72h.');

-- ═══════════════════════════════════════════════════════════════════════════
-- D12 — DOMINIO BLOCKCHAIN: SIN_ANCLAJE, ANCLAJE_MERKLE, DID_BASICO
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_role_d12 RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_role_d12 (role_code, role_name, domain_code, config, description) VALUES
('D12-SIN-ANCLAJE', '{"es":"Sin Anclaje Blockchain","en":"No Blockchain Anchor"}', 12,
 '{"blockchain":{"enabled":false,"reason":"no_requiere_verificabilidad_externa"}}',
 'Sin anclaje: para roles que no requieren verificabilidad externa blockchain.'),

('D12-ANCLAJE-MERKLE', '{"es":"Anclaje Merkle","en":"Merkle Anchor"}', 12,
 '{"blockchain":{"enabled":true,"variant":"A","anchor_frequency_s":3600,"tier":"gold","network":"arbitrum_one","merkle_algorithm":"keccak256","batch_size":1000,"verifiable_externally":true,"gas_limit":100000}}',
 'Anclaje Merkle: Variante A, cada 1h en Arbitrum One. Keccak-256. Gold tier.'),

('D12-DID-BASICO', '{"es":"DID Básico","en":"Basic DID"}', 12,
 '{"blockchain":{"enabled":true,"variant":"A","did_methods":["did:web"],"vc_formats":["jwt_vc"],"resolution_cache_min":60,"status":"planned_2027"}}',
 'DID básico: did:web con JWT-VC. Planeado para 2027. Configuración preparatoria.');

COMMIT;
