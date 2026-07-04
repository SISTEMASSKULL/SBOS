-- seed_ath_step_up_rule.sql — Reglas RFC 9470 Step-Up Authentication
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: RFC 9470 OAuth 2.0 Step-Up Authentication Challenge Protocol · NIST SP 800-63B-4
-- ═══════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_step_up_rule RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_step_up_rule;

INSERT INTO bauth.ath_step_up_rule (rule_code, trigger_event, condition_json, required_loa, max_age_seconds, acr_value, reauth_required, requires_justification, requires_approval, approver_roles, description) VALUES

('STEP-FIN-APPROVE', 'financial_approve',
 '{"field":"amount","operator":">","value_ref":"user.financial_limits.transaction_limits.single_transaction_limit"}',
 3, 300, 'sbos_aal3', true, false, false, '{}',
 'Aprobación financiera por encima del límite del rol requiere AAL3 fresco (últimos 5 min).'),

('STEP-SYSTEM-CONFIG', 'system_config_change',
 '{}',
 3, 0, 'sbos_aal3_fresh', true, true, false, '{}',
 'Cambio de configuración del sistema requiere AAL3 con autenticación cero segundos de antigüedad.'),

('STEP-USER-MGMT', 'user_role_assignment',
 '{"target_roles":["ROL-SYS-ADMIN-*","ROL-ORG-CFO","ROL-ORG-CEO"]}',
 3, 300, 'sbos_aal3', true, false, false, '{}',
 'Asignar/modificar roles privilegiados requiere AAL3 con trazabilidad completa.'),

('STEP-DATA-EXPORT', 'bulk_data_export',
 '{"field":"record_count","operator":">","value":100}',
 3, 600, 'sbos_aal3', true, false, false, '{}',
 'Exportación masiva de datos (>100 registros) requiere AAL3. Prevención de exfiltración.'),

('STEP-DELEGATION', 'delegation_create',
 '{}',
 3, 60, 'sbos_aal3_fresh', true, false, true, '{ROL-ORG-GER-VENT}',
 'Crear una delegación de permisos requiere AAL3 fresco + aprobación del gerente.'),

('STEP-SOD-OVERRIDE', 'sod_override',
 '{}',
 3, 0, 'sbos_aal3_hw_key', true, true, true, '{ROL-SYS-ADMIN-SEGURIDAD,ROL-ORG-CCO}',
 'Override de SoD requiere AAL3 con hardware key + justificación formal + aprobación dual.'),

('STEP-VOID-INVOICE', 'void_invoice',
 '{}',
 3, 0, 'sbos_aal3_fresh', true, false, false, '{}',
 'Anulación de factura requiere AAL3 fresco. Prevención de fraude fiscal.'),

('STEP-CLOSE-CASH', 'close_cash_register',
 '{}',
 3, 300, 'sbos_aal3', true, false, false, '{}',
 'Cierre de caja requiere AAL3. Trazabilidad completa de arqueo.');

-- SELECT rule_code, trigger_event, required_loa, acr_value FROM bauth.ath_step_up_rule ORDER BY rule_code;
