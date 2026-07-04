-- ============================================================================
-- SEED: Tablas de Negocio Prioritarias — 7 tablas con datos reales
-- Fuente: DDL_skSBOS_db.sql · MANUAL_DB_DDL.md v18.0 · BAUTH-CRUD-ROLES-USUARIOS v3.0
-- Idempotente: TRUNCATE + RESTART IDENTITY CASCADE + INSERT
-- Orden topológico: idn_tenant → idn_tenant_config → idn_tenant_domain
--                    → org_empresa → org_sucursal → org_pos_logico
--                    → fin_decision_matrix → fin_limit → fin_approval_chain
--                    → aud_compliance_map
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. idn_tenant_config — Configuración regional SKULL (1:1 con tenant)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_tenant_config RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_tenant_config (
    tenant_id, locale_default, supported_locales, fallback_locales,
    date_format, time_format, number_format, first_day_of_week,
    timezone_default, supported_timezones,
    currency_default, multicurrency, multifiscal_enabled,
    max_open_fiscal_years, fiscal_year_start_month, fiscal_year_start_day
) VALUES (
    (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
    '{"locale":"es-BO","iso_639_1":"es","name":{"es":"Español (Bolivia)","en":"Spanish (Bolivia)"}}',
    '[{"locale":"es-BO","name":{"es":"Español (Bolivia)"}},{"locale":"en-US","name":{"en":"English (US)"}}]',
    '[{"locale":"es"},{"locale":"en"}]',
    'DD/MM/YYYY', 'HH:mm:ss', '1.234,56', 1,
    '{"timezone_id":"America/La_Paz","utc_offset":"-04:00","name":{"es":"Bolivia (La Paz)","en":"Bolivia Time"}}',
    '[{"timezone_id":"America/La_Paz","utc_offset":"-04:00"},{"timezone_id":"America/Argentina/Buenos_Aires","utc_offset":"-03:00"}]',
    '{"currency_code":"BOB","symbol":"Bs.","decimal_places":2,"name":{"es":{"singular":"Boliviano","plural":"Bolivianos"}}}',
    false, true, 3, 1, 1
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. idn_tenant_domain — Dominios del tenant SKULL
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.idn_tenant_domain RESTART IDENTITY CASCADE;

INSERT INTO bauth.idn_tenant_domain (
    tenant_id, fqdn, subdomain, domain_type, is_primary, dns_config, ssl_config, security_config
) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'skull.sbos.bo', NULL, 'WEB', true,
 '{"provider":"cloudflare","record_type":"A","target":"13.140.128.230","status":"VERIFIED"}',
 '{"provider":"letsencrypt","acme_challenge":"HTTP-01","status":"ACTIVE","expires_at":"2026-09-25T00:00:00Z"}',
 '{"force_ssl":true,"hsts_enabled":true,"hsts_max_age_s":31536000,"cors_origins":["https://skull.sbos.bo"],"rate_limit_rps":100}'),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'admin.skull.sbos.bo', 'admin', 'ADMIN', false,
 '{"provider":"cloudflare","record_type":"CNAME","target":"skull.sbos.bo","status":"VERIFIED"}',
 '{"provider":"letsencrypt","acme_challenge":"DNS-01","status":"ACTIVE"}',
 '{"force_ssl":true,"hsts_enabled":true,"allowed_ips":["10.0.1.0/24"],"rate_limit_rps":1000}'),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'api.skull.sbos.bo', 'api', 'API', false,
 '{"provider":"cloudflare","record_type":"CNAME","target":"skull.sbos.bo","status":"VERIFIED"}',
 '{"provider":"letsencrypt","acme_challenge":"DNS-01","status":"ACTIVE"}',
 '{"force_ssl":true,"cors_origins":["https://admin.skull.sbos.bo"],"rate_limit_rps":500}');

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. org_pos_logico — Puntos de Venta SKULL (jerarquía organizacional)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.org_pos_logico RESTART IDENTITY CASCADE;

INSERT INTO bauth.org_pos_logico (
    pos_id, sucursal_id, empresa_id, tenant_id,
    nombre, codigo_sucursal_sin, numero_punto_venta,
    modalidad_facturacion, ambiente_sin, tipo_factura,
    fecha_limite_emision, rango_inicio, rango_fin, numero_actual, estado_dosificacion
) VALUES
('POS-01', 'skull-central', 'NIT-1234567890', 'skull',
 'Caja Principal La Paz', '001', 1,
 'COMPUTARIZADA_EN_LINEA', 'PRODUCCION', 'FACTURA_CREDITO_FISCAL',
 '2027-06-25', 1000001, 2000000, 1000150, 'ACTIVA'),

('POS-02', 'skull-central', 'NIT-1234567890', 'skull',
 'Caja Express La Paz', '001', 2,
 'COMPUTARIZADA_EN_LINEA', 'PRODUCCION', 'FACTURA_CREDITO_FISCAL',
 '2027-06-25', 2000001, 3000000, 2000045, 'ACTIVA'),

('POS-03', 'skull-sucursal-sc', 'NIT-1234567890', 'skull',
 'Caja Principal Santa Cruz', '002', 1,
 'COMPUTARIZADA_EN_LINEA', 'PRODUCCION', 'FACTURA_CREDITO_FISCAL',
 '2027-06-25', 3000001, 4000000, 3000020, 'ACTIVA'),

('POS-04', 'skull-sucursal-cbba', 'NIT-1234567890', 'skull',
 'Caja Principal Cochabamba', '003', 1,
 'COMPUTARIZADA_EN_LINEA', 'PRODUCCION', 'FACTURA_CREDITO_FISCAL',
 '2027-06-25', 4000001, 5000000, 4000010, 'ACTIVA');

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. fin_decision_matrix — Matriz de decisión financiera (3 niveles)
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.fin_decision_matrix RESTART IDENTITY CASCADE;

INSERT INTO bauth.fin_decision_matrix (
    tenant_id, nombre, tipo_transaccion, moneda,
    nivel_1_rol, nivel_1_monto_max, nivel_1_puede_delegar,
    nivel_2_rol, nivel_2_monto_max, nivel_2_puede_delegar,
    nivel_3_rol, nivel_3_monto_max,
    requiere_evidencia_adjunta, tiempo_max_aprobacion_horas, escala_automatica
) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'Matriz Facturación', 'FAC_EMITIR', 'BOB',
 'APROBADOR_N1', 10000.00, false,
 'APROBADOR_N2', 100000.00, false,
 'GERENTE_REGIONAL', 1000000.00,
 true, 48, true),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'Matriz Pagos', 'PAGO_APROBAR', 'BOB',
 'APROBADOR_N1', 50000.00, true,
 'APROBADOR_N2', 500000.00, false,
 'GERENTE_REGIONAL', 5000000.00,
 true, 72, true),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'Matriz Cobros', 'COBRO_RECIBIR', 'BOB',
 'CAJERO', 5000.00, false,
 'APROBADOR_N2', 50000.00, false,
 'GERENTE_REGIONAL', 200000.00,
 false, 24, true),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 'Matriz Cierre de Caja', 'CIERRE_CAJA', 'BOB',
 'CAJERO', 0.00, false,
 'APROBADOR_N1', 0.00, false,
 'APROBADOR_N2', 0.00,
 true, 8, false);

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. fin_limit — Límites financieros por tipo de transacción
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.fin_limit RESTART IDENTITY CASCADE;

INSERT INTO bauth.fin_limit (
    tenant_id, transaction_type_id, currency_code,
    limits_config, accumulators, exceed_action
) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 (SELECT type_id FROM bauth.fin_transaction_type WHERE code = 'FAC_EMITIR'), 'BOB',
 '{"per_operation":50000,"daily":500000,"monthly":5000000}',
 '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
 'REQUIRE_APPROVAL'),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 (SELECT type_id FROM bauth.fin_transaction_type WHERE code = 'PAGO_APROBAR'), 'BOB',
 '{"per_operation":500000,"daily":2000000,"monthly":20000000}',
 '{"daily":0,"monthly":0,"last_reset_daily":"2026-06-26","last_reset_monthly":"2026-06-01"}',
 'REQUIRE_APPROVAL'),

((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
 (SELECT type_id FROM bauth.fin_transaction_type WHERE code = 'COBRO_RECIBIR'), 'BOB',
 '{"per_operation":50000,"daily":500000,"max_efectivo":100000}',
 '{"daily":0,"last_reset_daily":"2026-06-26"}',
 'REQUIRE_APPROVAL');

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. fin_approval_chain + fin_approval_level — Cadenas de aprobación
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.fin_approval_level RESTART IDENTITY CASCADE;
TRUNCATE bauth.fin_approval_chain RESTART IDENTITY CASCADE;

WITH chain_fact AS (
    INSERT INTO bauth.fin_approval_chain (
        tenant_id, transaction_type_id, currency_code, name, sla_hours,
        auto_escalate, requires_attachment
    ) VALUES (
        (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
        (SELECT type_id FROM bauth.fin_transaction_type WHERE code = 'FAC_EMITIR'),
        'BOB', 'Cadena Facturación', 48, true, true
    ) RETURNING chain_id
),
chain_pago AS (
    INSERT INTO bauth.fin_approval_chain (
        tenant_id, transaction_type_id, currency_code, name, sla_hours,
        auto_escalate, requires_attachment, requires_committee
    ) VALUES (
        (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
        (SELECT type_id FROM bauth.fin_transaction_type WHERE code = 'PAGO_APROBAR'),
        'BOB', 'Cadena Pagos', 72, true, true, false
    ) RETURNING chain_id
)
INSERT INTO bauth.fin_approval_level (chain_id, level_order, role_id, max_amount, description)
SELECT chain_id, 1, uuidv7(), 10000.00, 'Nivel 1 — Supervisor directo'
FROM chain_fact
UNION ALL
SELECT chain_id, 2, uuidv7(), 100000.00, 'Nivel 2 — Gerente de área'
FROM chain_fact
UNION ALL
SELECT chain_id, 3, uuidv7(), 1000000.00, 'Nivel 3 — Director financiero'
FROM chain_fact
UNION ALL
SELECT chain_id, 1, uuidv7(), 50000.00, 'Nivel 1 — Jefe de compras'
FROM chain_pago
UNION ALL
SELECT chain_id, 2, uuidv7(), 500000.00, 'Nivel 2 — Gerente financiero'
FROM chain_pago
UNION ALL
SELECT chain_id, 3, uuidv7(), 5000000.00, 'Nivel 3 — Comité ejecutivo'
FROM chain_pago;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. aud_compliance_map — 34 controles normativos mapeados
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.aud_compliance_map RESTART IDENTITY CASCADE;

INSERT INTO bauth.aud_compliance_map (standard, control_id, control_name, description, applies_to, implementation_status) VALUES
-- ISO 27001:2022
('ISO_27001:2022', 'A.5.15', 'Access Control', 'Control de acceso basado en requerimientos de negocio y seguridad.', 'bAuth, Keycloak, Tryton', 'implemented'),
('ISO_27001:2022', 'A.5.16', 'Identity Management', 'Gestión completa del ciclo de vida de identidades.', 'bAuth, idn_user_template', 'implemented'),
('ISO_27001:2022', 'A.5.17', 'Authentication Information', 'Gestión segura de secretos de autenticación y su ciclo de vida.', 'bAuth, Vault, Keycloak', 'implemented'),
('ISO_27001:2022', 'A.5.18', 'Access Rights', 'Derechos de acceso revisados periódicamente. Principio de mínimo privilegio.', 'idn_role_template, aud_review', 'partial'),
('ISO_27001:2022', 'A.8.2', 'Privileged Access Rights', 'Gestión y restricción de derechos de acceso privilegiado.', 'SU, SYS, break-glass', 'partial'),
('ISO_27001:2022', 'A.8.9', 'Configuration Management', 'Gestión de cambios en configuraciones de seguridad con registro auditado.', 'aud_policy_change, cfg_policy_library', 'implemented'),
('ISO_27001:2022', 'A.8.15', 'Logging', 'Registro de eventos de seguridad con trazabilidad completa.', 'aud_event, ctx_id', 'implemented'),
('ISO_27001:2022', 'A.8.16', 'Monitoring Activities', 'Monitoreo continuo de eventos de seguridad.', 'ses_risk_policy, ath_risk_evaluation', 'planned'),

-- NIST SP 800-53 Rev.5
('NIST_800-53_Rev5', 'AC-2', 'Account Management', 'Gestión completa del ciclo de vida de cuentas de usuario.', 'idn_user_template, JmlEngine', 'implemented'),
('NIST_800-53_Rev5', 'AC-3', 'Access Enforcement', 'Enforcement de decisiones de control de acceso.', 'PrivilegeEngine, DomainRegistry', 'implemented'),
('NIST_800-53_Rev5', 'AC-5', 'Separation of Duties', 'Separación de deberes para prevenir conflictos.', 'fin_sod_rule, sod_validation_config', 'implemented'),
('NIST_800-53_Rev5', 'AC-6', 'Least Privilege', 'Principio de mínimo privilegio aplicado a todos los roles.', 'idn_role_template, privilege_atom', 'implemented'),
('NIST_800-53_Rev5', 'AU-2', 'Audit Events', 'Definición de eventos auditables en el sistema.', 'aud_event, ath_login_attempt', 'implemented'),
('NIST_800-53_Rev5', 'AU-9', 'Protection of Audit Information', 'Protección de registros de auditoría contra alteración.', 'aud_event WORM, hash-chain SHA-256', 'implemented'),
('NIST_800-53_Rev5', 'IA-2', 'Identification and Authentication', 'Identificación y autenticación de usuarios antes de permitir acceso.', 'ath_method, ath_auth_flow', 'implemented'),
('NIST_800-53_Rev5', 'PE-3', 'Physical Access Control', 'Control de acceso físico a instalaciones.', 'fis_device, fis_access_zone', 'planned'),

-- PCI DSS 4.0
('PCI_DSS_4.0', 'Req_7.2', 'Access Control Systems', 'Sistemas de control de acceso para componentes del sistema.', 'bAuth, Kong, Keycloak', 'implemented'),
('PCI_DSS_4.0', 'Req_8.3', 'Multi-Factor Authentication', 'MFA requerido para todo acceso administrativo y remoto.', 'ath_method, ath_auth_flow', 'implemented'),
('PCI_DSS_4.0', 'Req_10.1', 'Audit Trails', 'Implementación de pistas de auditoría para todas las acciones.', 'aud_event WORM', 'implemented'),
('PCI_DSS_4.0', 'Req_10.3', 'Audit Record Content', 'Contenido mínimo de cada registro de auditoría.', 'aud_event columnas', 'implemented'),
('PCI_DSS_4.0', 'Req_10.5', 'Secure Audit Trails', 'Protección de pistas de auditoría contra alteración.', 'WORM, hash-chain', 'implemented'),
('PCI_DSS_4.0', 'Req_11.3', 'Penetration Testing', 'Pruebas de penetración basadas en metodología reconocida.', 'B31.T06, pentest_plan', 'planned'),

-- SOX §302/§404
('SOX', '302', 'Corporate Responsibility for Financial Reports', 'Responsabilidad corporativa sobre reportes financieros.', 'fin_approval, aud_event', 'implemented'),
('SOX', '404', 'Management Assessment of Internal Controls', 'Evaluación de controles internos por la gerencia.', 'fin_sod_rule, aud_review, aud_compliance_map', 'partial'),

-- GDPR
('GDPR', 'Art.7', 'Conditions for Consent', 'Condiciones para el consentimiento del titular de datos.', 'ath_consent, idn_tenant', 'implemented'),
('GDPR', 'Art.9', 'Processing of Special Categories', 'Procesamiento de categorías especiales de datos personales.', 'biometric template, gdpr_consent', 'implemented'),
('GDPR', 'Art.17', 'Right to Erasure', 'Derecho al olvido y eliminación de datos personales.', 'idn_user_template, purge_policy', 'implemented'),
('GDPR', 'Art.30', 'Records of Processing Activities', 'Registros de actividades de procesamiento de datos.', 'aud_event, ses_context', 'partial'),
('GDPR', 'Art.32', 'Security of Processing', 'Seguridad del procesamiento de datos personales.', 'Vault, encryption, TLS', 'implemented'),
('GDPR', 'Art.33', 'Notification of Data Breach', 'Notificación de brecha de datos personales ≤72h.', 'breach_notification, cal_notification_log', 'planned'),
('GDPR', 'Art.44', 'General Principle for Transfers', 'Principio general para transferencias internacionales.', 'jurisdiction_block, data_residency', 'implemented'),

-- eIDAS 2.0 (EU)
('eIDAS_2.0', 'Art.6', 'Mutual Recognition of eID', 'Reconocimiento mutuo de identificación electrónica.', 'federation_protocol, OIDC', 'planned'),

-- OWASP ASVS 5.0
('OWASP_ASVS_5.0', 'V2.1', 'Password Security', 'Requerimientos de seguridad de contraseñas para todos los niveles.', 'ath_credential_policy, password_min_length', 'implemented'),
('OWASP_ASVS_5.0', 'V2.8', 'Multi-Factor Auth & Phishing Resistance', 'MFA resistente a phishing para operaciones sensibles.', 'FIDO2, WebAuthn, ath_method', 'implemented');

COMMIT;
