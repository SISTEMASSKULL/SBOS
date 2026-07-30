-- ============================================================================
-- SEED: Tablas Complementarias — 17 tablas de soporte para los 12 dominios
-- Fuente: DDL_skSBOS_db.sql · MANUAL_DB_DDL.md v18.0
-- Idempotente: TRUNCATE + RESTART IDENTITY CASCADE + INSERT
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ath_auth_flow — 8 flujos de autenticación predefinidos
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_auth_flow_method RESTART IDENTITY CASCADE;
TRUNCATE bauth.ath_auth_flow RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_auth_flow (flow_code, flow_name, min_loa, description) VALUES
('standard_login', 'Login Estándar (AAL2)', 2, 'Contraseña + TOTP. Flujo por defecto para BIZ N1-N5.'),
('elevated_login', 'Login Elevado (AAL2+ phishing-resistant)', 2, 'Contraseña + WebAuthn. Phishing-resistant.'),
('hardware_protected_login', 'Login Hardware (AAL3)', 3, 'WebAuthn + Passkey device-bound. Obligatorio SU/N1.'),
('financial_high_value', 'Login Financiero Alto Valor (AAL3)', 3, '3 factores para transacciones >$10K. Password + WebAuthn + TOTP.'),
('system_config_change', 'Cambio Configuración Sistema (AAL3)', 3, 'Doble factor hardware para cambios de seguridad.'),
('m2m_service_account', 'M2M Service Account', 0, 'mTLS + client_credentials. Sin password. TTL 24h.'),
('decoupled_external', 'Desacoplado Externo (CIBA)', 2, 'Notificación push. Usuario aprueba en dispositivo.'),
('unauthenticated', 'No Autenticado (AAL0)', 0, 'Acceso público sin credenciales. Solo recursos públicos.');

-- Flujos ↔ Métodos (ath_auth_flow_method)
INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required) VALUES
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='standard_login'), 'PASSWORD', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='standard_login'), 'TOTP', 2, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='elevated_login'), 'PASSWORD', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='elevated_login'), 'WEBAUTHN_PWDLESS', 2, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='hardware_protected_login'), 'WEBAUTHN_PWDLESS', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='hardware_protected_login'), 'PASSKEY_DEVICE', 2, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='financial_high_value'), 'WEBAUTHN_PWDLESS', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='financial_high_value'), 'TOTP', 2, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='system_config_change'), 'PASSKEY_DEVICE', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='system_config_change'), 'SMARTCARD_X509', 2, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='m2m_service_account'), 'CLIENT_CREDENTIALS', 1, true),
((SELECT flow_id FROM bauth.ath_auth_flow WHERE flow_code='decoupled_external'), 'CIBA', 1, true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. ath_step_up_rule — 7 reglas RFC 9470
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_step_up_rule RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_step_up_rule (rule_code, trigger_event, condition_json, required_loa, max_age_seconds, acr_value, requires_justification, requires_approval, description) VALUES
('STEPUP-FINANCIAL-10K', 'financial_approval', '{"min_amount_bob":10000,"currency":"BOB"}', 3, 900, 'aal3_fido2_hw', true, false, 'Step-Up AAL2→AAL3 para aprobación financiera >Bs 10,000.'),
('STEPUP-FINANCIAL-100K', 'financial_approval', '{"min_amount_bob":100000}', 3, 900, 'aal3_fido2_hw', true, true, 'Step-Up AAL2→AAL3 + aprobación dual para >Bs 100,000.'),
('STEPUP-SECURITY-CHANGE', 'security_config_change', '{"change_types":["policy","role","sod_matrix"]}', 3, 600, 'aal3_fido2_hw', true, true, 'Step-Up para cambios de configuración de seguridad.'),
('STEPUP-ARQUEO-CAJA', 'cash_register_close', '{}', 3, 900, 'aal3_fido2_hw', false, false, 'Step-Up AAL2→AAL3 para arqueo y cierre de caja.'),
('STEPUP-NEW-DEVICE', 'new_device_login', '{"trust_score_below":80}', 2, 300, 'aal2_webauthn', false, false, 'Step-Up AAL1→AAL2 cuando se detecta dispositivo nuevo.'),
('STEPUP-OUTSIDE-SCHEDULE', 'outside_schedule_access', '{}', 2, 300, 'aal2_totp', true, false, 'Step-Up AAL1→AAL2 para acceso fuera de horario.'),
('STEPUP-IMPOSSIBLE-TRAVEL', 'impossible_travel_detected', '{"velocity_kmh_above":900}', 3, 600, 'aal3_fido2_hw', true, true, 'Step-Up AAL2→AAL3 + justificación cuando se detecta viaje imposible.');

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. zone_field_restriction — Restricciones de campos por zona (Tryton capa 3)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.zone_field_restriction RESTART IDENTITY CASCADE;

INSERT INTO bauth.zone_field_restriction (zone_id, app_code, model_name, field_name, can_read, can_write, reason) VALUES
('AREA-VENT', 1, 'account_invoice', 'margin', true, false, 'Margen de ganancia oculto para cajeros'),
('AREA-VENT', 1, 'account_invoice', 'cost_price', true, false, 'Costo de compra oculto para cajeros'),
('AREA-VENT', 1, 'party', 'tax_id', true, false, 'NIT cliente visible pero no editable por cajero'),
('AREA-VENT', 1, 'party', 'bank_account', false, false, 'Cuenta bancaria oculta para cajeros'),
('AREA-DIR', 1, 'hr_employee', 'salary', true, false, 'Salario visible pero no editable por gerente'),
('AREA-DIR', 1, 'hr_employee', 'performance_score', true, true, 'Evaluación de desempeño editable por gerente'),
('AREA-COMP', 1, 'account_invoice', 'margin', true, true, 'Auditor puede ver y exportar margen'),
('AREA-COMP', 1, 'party', 'bank_account', true, true, 'Auditor puede ver cuenta bancaria para verificación');

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. zone_button_rule — Reglas de botones (Tryton capa 4)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.zone_button_rule RESTART IDENTITY CASCADE;

INSERT INTO bauth.zone_button_rule (zone_id, app_code, model_name, button_name, condition_json, users_required, sod_cannot_also, step_up_loa, description) VALUES
('AREA-VENT', 1, 'account_invoice', 'confirm', '{"max_amount":5000}', 1, NULL, NULL, 'Confirmar factura ≤Bs 5,000. Sin aprobación dual.'),
('AREA-VENT', 1, 'account_payment', 'post', '{}', 1, NULL, NULL, 'Registrar pago. Sin restricción de monto para cajero básico.'),
('AREA-DIR', 1, 'account_invoice', 'confirm', '{}', 1, NULL, 2, 'Gerente confirma facturas con step-up AAL2.'),
('AREA-VENT', 1, 'account_invoice', 'cancel', '{}', 2, 'AREA-VENT', 2, 'Cancelar factura requiere 2 personas de caja, SoD: no puede ser el mismo.'),
('AREA-COMP', 1, 'account_invoice', 'export_pii', '{}', 2, NULL, 3, 'Exportar PII requiere 2 auditores + step-up AAL3.');

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. zone_record_rule — Reglas de registros/filtros SQL por zona (Tryton capa 5)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.zone_record_rule RESTART IDENTITY CASCADE;

INSERT INTO bauth.zone_record_rule (zone_id, app_code, model_name, domain_json, scope, description) VALUES
('AREA-VENT', 1, 'account_invoice', '["company_id","=",user.company_id.id]', 'BRANCH', 'Cajero solo ve facturas de su sucursal'),
('AREA-VENT', 1, 'sale_pos', '["shop_id","=",user.shop_id.id]', 'PERSONAL', 'Cajero solo ve transacciones de su punto de venta'),
('AREA-DIR', 1, 'account_invoice', '["company_id","child_of",[user.company_id.id]]', 'REGIONAL', 'Gerente ve facturas de su región y sucursales hijas'),
('AREA-DIR', 1, 'hr_employee', '["department_id","child_of",[user.department_id.id]]', 'REGIONAL', 'Gerente ve empleados de su departamento y subordinados'),
('AREA-COMP', 1, 'account_invoice', '[]', 'GLOBAL', 'Auditor ve TODAS las facturas sin filtro'),
('AREA-COMP', 1, 'party', '[]', 'GLOBAL', 'Auditor ve TODOS los terceros');

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. zone_data_policy — Políticas de datos por zona
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.zone_data_policy RESTART IDENTITY CASCADE;

INSERT INTO bauth.zone_data_policy (zone_id, data_classification, pii_access, phi_access, gdpr_sensitive, masking_policy, retention_days, gdpr_lawful_basis) VALUES
('AREA-VENT', '{INTERNAL}', true, false, false, 'mask_tax_id', 2555, 'contract'),
('AREA-DIR', '{INTERNAL,CONFIDENTIAL}', true, false, true, 'none', 2555, 'contract'),
('AREA-COMP', '{INTERNAL,CONFIDENTIAL,RESTRICTED}', true, true, true, 'none', 3650, 'legal_obligation'),
('AREA-COM', '{PUBLIC}', false, false, false, 'mask_all_pii', 365, 'consent'),
('AREA-RRHH', '{INTERNAL,CONFIDENTIAL}', true, true, true, 'mask_salary', 2555, 'contract_and_legal');

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. tryton_action_visibility — Menús/acciones visibles en Tryton por zona
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.tryton_action_visibility RESTART IDENTITY CASCADE;

INSERT INTO bauth.tryton_action_visibility (zone_id, action_name, action_type, is_visible) VALUES
('AREA-VENT', 'menu_sales_pos', 'menu', true),
('AREA-VENT', 'menu_invoicing', 'menu', true),
('AREA-VENT', 'menu_payments', 'menu', true),
('AREA-VENT', 'wizard_close_shift', 'wizard', true),
('AREA-VENT', 'report_daily_sales', 'report', true),
('AREA-VENT', 'menu_accounting', 'menu', false),
('AREA-VENT', 'menu_hr', 'menu', false),
('AREA-DIR', 'menu_sales_pos', 'menu', true),
('AREA-DIR', 'menu_accounting', 'menu', true),
('AREA-DIR', 'menu_hr', 'menu', true),
('AREA-DIR', 'dashboard_sales_performance', 'dashboard', true),
('AREA-DIR', 'dashboard_pl_mensual', 'dashboard', true),
('AREA-COMP', 'menu_accounting', 'menu', true),
('AREA-COMP', 'menu_audit', 'menu', true),
('AREA-COMP', 'report_full_audit_trail', 'report', true),
('AREA-COM', 'dashboard_publico', 'dashboard', true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. fis_zone_method_requirement — Métodos por nivel de zona física
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.fis_zone_method_requirement RESTART IDENTITY CASCADE;

INSERT INTO bauth.fis_zone_method_requirement (zone_level, method_id, sort_order, loa_required) VALUES
('public_areas', 'QR', 1, 1),
('employee_areas', 'NFC', 1, 2),
('employee_areas', 'QR', 2, 1),
('restricted_areas', 'NFC', 1, 2),
('restricted_areas', 'FINGERPRINT', 2, 2),
('critical_areas', 'NFC', 1, 3),
('critical_areas', 'FINGERPRINT', 2, 3),
('critical_areas', 'PIN', 3, 3),
('maximum_security_areas', 'SMARTCARD_X509', 1, 3),
('maximum_security_areas', 'FINGERPRINT', 2, 3),
('maximum_security_areas', 'PIN', 3, 3);

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. fis_emergency_config — Configuración de emergencia física
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.fis_emergency_config RESTART IDENTITY CASCADE;

INSERT INTO bauth.fis_emergency_config (trigger_event, action, override_mode, requires_approval, approver_roles, max_duration_minutes) VALUES
('FIRE_ALARM', 'UNLOCK_ALL_EMERGENCY_EXITS', 'FAIL_SAFE', false, '{}', 120),
('MEDICAL_EMERGENCY', 'UNLOCK_SPECIFIC_ZONE', 'FAIL_SAFE', false, '{}', 60),
('SECURITY_BREACH', 'LOCKDOWN_ALL', 'FAIL_SECURE', true, '{S003,SYS-SECURITY}', 240),
('POWER_OUTAGE', 'FAIL_SAFE_UNLOCK', 'FAIL_SAFE', false, '{}', 180),
('NATURAL_DISASTER', 'UNLOCK_ALL', 'FAIL_SAFE', false, '{}', 240);

-- ═══════════════════════════════════════════════════════════════════════════
-- 10. cal_overtime_policy — Políticas de horas extra
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bcalendar.cal_overtime_policy RESTART IDENTITY CASCADE;

INSERT INTO bcalendar.cal_overtime_policy (max_daily_hours, max_weekly_hours, rate_multiplier, night_shift_rate, holiday_rate, requires_approval) VALUES
(4, 20, 1.5, 2.0, 2.5, true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 11. cal_break_policy — Políticas de descansos
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bcalendar.cal_break_policy RESTART IDENTITY CASCADE;

INSERT INTO bcalendar.cal_break_policy (lunch_required, lunch_duration_minutes, lunch_window_start, lunch_window_end, short_breaks_allowed, short_break_minutes, auto_logout_during_break, session_pause_during) VALUES
(true, 60, '12:00', '14:00', 2, 15, false, true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 12. net_ztna_policy — Zero Trust Network Access
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.net_ztna_policy RESTART IDENTITY CASCADE;

INSERT INTO bauth.net_ztna_policy (default_action, allowed_services, microsegmentation, require_just_in_time, verification_interval_s) VALUES
('DENY', '{postgresql,redis,vault,keycloak,tryton,kong,bkernel,biedata,bsearch,bhnexus}', true, true, 300);

-- ═══════════════════════════════════════════════════════════════════════════
-- 13. ses_ses_risk_policy — Política de riesgo de sesión
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ses_ses_risk_policy RESTART IDENTITY CASCADE;

INSERT INTO bauth.ses_ses_risk_policy (risk_factors, threshold_low, threshold_medium, threshold_high, threshold_critical, action_low, action_medium, action_high, action_critical) VALUES
('{ip_change,geo_velocity,device_change,outside_schedule,new_device,impossible_travel,failed_mfa,unusual_hour}', 30, 60, 80, 95, 'NONE', 'REQUIRE_STEP_UP', 'REQUIRE_STEP_UP', 'TERMINATE_SESSION');

-- ═══════════════════════════════════════════════════════════════════════════
-- 14. ses_caep_config — Configuración de eventos CAEP
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ses_caep_config RESTART IDENTITY CASCADE;

INSERT INTO bauth.ses_caep_config (caep_event, is_enabled, endpoint_url, retry_max, retry_delay_seconds) VALUES
('session-revoked', true, 'https://kong.sbos.skull.bo:8443/caep/session-revoked', 3, 30),
('token-claims-change', true, 'https://kong.sbos.skull.bo:8443/caep/token-change', 3, 30),
('assurance-level-change', true, 'https://kong.sbos.skull.bo:8443/caep/assurance-change', 3, 30),
('credential-change', true, 'https://kong.sbos.skull.bo:8443/caep/credential-change', 3, 30),
('device-compliance-change', true, 'https://kong.sbos.skull.bo:8443/caep/device-change', 3, 30);

-- ═══════════════════════════════════════════════════════════════════════════
-- 15. sod_validation_config — Configuración de validación SoD
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.sod_validation_config RESTART IDENTITY CASCADE;

INSERT INTO bauth.sod_validation_config (check_frequency, validation_scope, auto_remediate, notification_roles) VALUES
('REAL_TIME', '{DIRECT_CONFLICTS,INHERITED_CONFLICTS,DELEGATION_CONFLICTS}', false, '{S003,SYS-SECURITY}');

-- ═══════════════════════════════════════════════════════════════════════════
-- 16. conflict_interest_policy — Política de conflicto de interés
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.conflict_interest_policy RESTART IDENTITY CASCADE;

INSERT INTO bauth.conflict_interest_policy (restricted_entity_types, max_relationship_degrees, declaration_frequency, requires_update_on_change, verification_method) VALUES
('{VENDORS,COMPETITORS,SUPPLIERS,GOVERNMENT_AGENCIES}', 2, 'ANNUAL', true, 'COMPLIANCE_REVIEW');

COMMIT;
