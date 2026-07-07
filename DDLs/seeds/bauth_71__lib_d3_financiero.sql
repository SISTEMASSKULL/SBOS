-- =============================================================================
-- bauth_71__lib_d3_financiero.sql — Políticas financieras D3 (incremento directo)
-- =============================================================================
-- Propósito  : Agregar políticas de autenticación del dominio financiero
--              directamente a cfg_policy_library (sin depender de JSON fuente).
-- Normas     : PCI DSS 4.0 (2022) — Req 7, 8, 10, 12
--              Bolivia SIN RND 102100000011 — Factura electrónica
--              Bolivia Ley 1178 SAFCO — Control gubernamental financiero
--              ISO 20022:2013/AMD1:2023 — Mensajería financiera
--              SWIFT CSP (Customer Security Programme) 2025
--              Basel III (BIS) — Riesgo operacional
--              SOX §302/§404 — Control interno financiero
--              GDPR Art.6, Art.22 — Procesamiento financiero automatizado
--              NIST SP 800-53 Rev.5 AC-2, AU-2, AU-12
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

-- 1. Verificación NIT Bolivia (SIN)
(
  'bolivia_nit_verification', NULL, 'd3_financial_ext.bolivia_nit_verification',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'Bolivia SIN RND 102100000011', ARRAY['Bolivia SIN RND 102100000011 Art.4', 'Bolivia Ley 812 Código Tributario Art.154'],
  '{"title":"Bolivia NIT Verification","description":"Toda transacción financiera en SBOS que emita o reciba documentos tributarios electrónicos debe validar el NIT del emisor y receptor contra el padrón tributario del SIN (Servicio de Impuestos Nacionales) antes de autorizar la operación. La verificación debe realizarse en tiempo real mediante web service del SIN.","requirements":{"nit_format":"8 digits, modulo-11 checksum","online_verification":true,"cache_ttl_seconds":300,"failure_action":"DENY","fallback":"offline_padron_daily_sync"},"auth_required":"AAL2","mfa_methods":["password","totp"]}',
  '{"title":"Bolivia NIT Verification","description":"Every financial transaction in SBOS that issues or receives electronic tax documents must validate the NIT (tax identification) of issuer and receiver against the SIN (National Tax Service) taxpayer registry before authorizing the operation.","requirements":{"nit_format":"8 digits, modulo-11 checksum","online_verification":true,"cache_ttl_seconds":300,"failure_action":"DENY","fallback":"offline_padron_daily_sync"},"auth_required":"AAL2","mfa_methods":["password","totp"]}',
  '{"titulo":"Verificación NIT Bolivia","descripcion":"Toda transacción financiera en SBOS que emita o reciba documentos tributarios electrónicos debe validar el NIT del emisor y receptor contra el padrón tributario del SIN antes de autorizar la operación.","requisitos":{"formato_nit":"8 dígitos, checksum módulo-11","verificacion_online":true,"ttl_cache_segundos":300,"accion_fallo":"DENEGAR","respaldo":"sincronizacion_padron_diaria"},"autenticacion_requerida":"AAL2","metodos_mfa":["contrasena","totp"]}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 2. Factura Electrónica Bolivia — Autenticación para emisión
(
  'bolivia_factura_electronica_auth', NULL, 'd3_financial_ext.bolivia_factura_electronica_auth',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'Bolivia SIN RND 102100000011', ARRAY['Bolivia SIN RND 102100000011 Art.8', 'Bolivia DS 27310 Art.5'],
  '{"title":"Bolivia Factura Electrónica Auth","description":"La emisión de facturas electrónicas en el sistema de facturación online (SIAT-SIN) requiere autenticación del emisor con certificado digital ADSIB o credencial delegada. El sistema SBOS debe firmar cada factura con clave privada del tenant y transmitir al SIN con SSL/TLS 1.3. Requiere CUIS (Código Único de Inicio de Sesión) y CUFD (Código Único de Facturación Diaria).","requirements":{"digital_signature":"ADSIB RSA-SHA256 o Ed25519","tls_version":"1.3","cuis_required":true,"cufd_required":true,"offline_mode":"allowed_up_to_24h","batch_authorization":"max_500_invoices_per_request"},"auth_required":"AAL2"}',
  '{"title":"Bolivia Electronic Invoice Auth","description":"Electronic invoice emission in Bolivia SIAT-SIN system requires issuer authentication with ADSIB digital certificate or delegated credential. SBOS must sign each invoice with the tenant private key and transmit to SIN with SSL/TLS 1.3. Requires CUIS and CUFD codes.","requirements":{"digital_signature":"ADSIB RSA-SHA256 or Ed25519","tls_version":"1.3","cuis_required":true,"cufd_required":true,"offline_mode":"allowed_up_to_24h","batch_authorization":"max_500_invoices_per_request"},"auth_required":"AAL2"}',
  '{"titulo":"Autenticación Factura Electrónica Bolivia","descripcion":"La emisión de facturas electrónicas requiere autenticación del emisor con certificado digital ADSIB. El sistema SBOS debe firmar cada factura y transmitir al SIN con TLS 1.3. Requiere CUIS y CUFD.","requisitos":{"firma_digital":"ADSIB RSA-SHA256 o Ed25519","version_tls":"1.3","cuis_requerido":true,"cufd_requerido":true,"modo_offline":"permitido_hasta_24h","autorizacion_lote":"maximo_500_facturas_por_solicitud"},"autenticacion_requerida":"AAL2"}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 3. PCI DSS 4.0 — Autenticación fuerte para datos de tarjeta
(
  'pci_dss_strong_customer_auth', NULL, 'd3_financial_ext.pci_dss_strong_customer_auth',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'PCI DSS 4.0', ARRAY['PCI DSS 4.0 Req 8.4.2', 'PCI DSS 4.0 Req 8.6.1', 'PCI DSS 4.0 Req 12.3.4'],
  '{"title":"PCI DSS 4.0 Strong Customer Authentication","description":"All personnel with non-consumer access to cardholder data environment (CDE) must authenticate with multi-factor authentication (MFA) consisting of at least two of: something you know (password ≥12 chars), something you have (TOTP/hardware token), something you are (biometric). MFA must be phishing-resistant for remote access per PCI DSS 4.0 Req 8.4.2. Session timeout: 15 minutes of inactivity. Maximum 10 failed attempts before lockout.","requirements":{"mfa_required":true,"min_factors":2,"phishing_resistant_remote":true,"session_timeout_idle_min":15,"max_failed_attempts":10,"lockout_duration_min":30,"password_min_length":12},"applies_to":"CDE access, remote access, shared accounts prohibited"}',
  '{"title":"PCI DSS 4.0 Strong Customer Authentication","description":"All personnel with non-consumer access to cardholder data environment (CDE) must authenticate with MFA consisting of at least two factors. MFA must be phishing-resistant for remote access per PCI DSS 4.0 Req 8.4.2.","requirements":{"mfa_required":true,"min_factors":2,"phishing_resistant_remote":true,"session_timeout_idle_min":15,"max_failed_attempts":10,"lockout_duration_min":30,"password_min_length":12},"applies_to":"CDE access"}',
  '{"titulo":"PCI DSS 4.0 Autenticación Fuerte de Cliente","descripcion":"Todo personal con acceso no consumidor al entorno de datos de tarjetas (CDE) debe autenticarse con MFA de al menos dos factores. El MFA debe ser resistente al phishing para acceso remoto.","requisitos":{"mfa_requerido":true,"factores_minimos":2,"resistente_phishing_remoto":true,"timeout_sesion_inactivo_min":15,"intentos_fallidos_max":10,"duracion_bloqueo_min":30,"longitud_minima_contrasena":12},"aplica_a":"Acceso CDE"}',
  'mandatory', 'critical', 'active', 'AAL3', true, true
),

-- 4. PCI DSS 4.0 — Control de acceso a datos de tarjeta
(
  'pci_dss_cardholder_access_control', NULL, 'd3_financial_ext.pci_dss_cardholder_access_control',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'PCI DSS 4.0', ARRAY['PCI DSS 4.0 Req 7.2.4', 'PCI DSS 4.0 Req 7.2.5', 'PCI DSS 4.0 Req 7.3.1'],
  '{"title":"PCI DSS Cardholder Data Access Control","description":"Access to cardholder data must be restricted to the minimum necessary for job function (least privilege). All access must be role-based, granted by explicit need-to-know, and reviewed at minimum every 6 months. Privileged access to CDE requires documented business justification and approval. All access attempts to CDE must be logged.","requirements":{"principle":"least_privilege","role_based":true,"access_review_months":6,"privileged_justification_required":true,"log_all_access":true,"deny_all_default":true,"separation_of_duties":true}}',
  '{"title":"PCI DSS Cardholder Data Access Control","description":"Access to cardholder data must be restricted by least privilege, role-based, reviewed every 6 months. All CDE access must be logged.","requirements":{"principle":"least_privilege","role_based":true,"access_review_months":6,"privileged_justification_required":true,"log_all_access":true,"deny_all_default":true,"separation_of_duties":true}}',
  '{"titulo":"Control Acceso Datos Tarjeta PCI DSS","descripcion":"El acceso a datos de tarjeta debe restringirse al mínimo necesario (mínimo privilegio), basado en roles, revisado cada 6 meses. Todo acceso al CDE debe registrarse.","requisitos":{"principio":"minimo_privilegio","basado_en_roles":true,"revision_acceso_meses":6,"justificacion_privilegiado_requerida":true,"registrar_todo_acceso":true,"denegar_por_defecto":true,"separacion_funciones":true}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 5. ISO 20022 — Autenticación en mensajería financiera
(
  'iso_20022_financial_messaging_auth', NULL, 'd3_financial_ext.iso_20022_financial_messaging_auth',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'ISO 20022:2013/AMD1:2023', ARRAY['ISO 20022:2013/AMD1:2023 §4.3', 'SWIFT CSP 2025 Mandatory Control 1.2'],
  '{"title":"ISO 20022 Financial Messaging Authentication","description":"All financial messages exchanged via ISO 20022 format (pain.001, pacs.008, camt.054 etc.) must be authenticated with digital signature per ISO 20022 security framework. Messages must include: BIC sender identification, digital signature (RSA-SHA256 or Ed25519), message integrity hash (SHA-256), and replay attack prevention via unique MessageIdentification per message.","requirements":{"digital_signature":"RSA-SHA256 or Ed25519","message_hash":"SHA-256","bic_required":true,"unique_message_id":true,"replay_prevention":true,"message_retention_years":7,"tls_mutual":"required"},"supported_messages":["pain.001","pain.002","pacs.008","pacs.009","camt.052","camt.053","camt.054"]}',
  '{"title":"ISO 20022 Financial Messaging Authentication","description":"All financial messages exchanged via ISO 20022 format must be authenticated with digital signature. Messages must include digital signature, message integrity hash, and replay attack prevention.","requirements":{"digital_signature":"RSA-SHA256 or Ed25519","message_hash":"SHA-256","bic_required":true,"unique_message_id":true,"replay_prevention":true,"message_retention_years":7,"tls_mutual":"required"}}',
  '{"titulo":"Autenticación Mensajería Financiera ISO 20022","descripcion":"Todos los mensajes financieros intercambiados en formato ISO 20022 deben autenticarse con firma digital. Los mensajes deben incluir firma digital, hash de integridad del mensaje y prevención de ataques de repetición.","requisitos":{"firma_digital":"RSA-SHA256 o Ed25519","hash_mensaje":"SHA-256","bic_requerido":true,"id_mensaje_unico":true,"prevencion_repeticion":true,"retencion_mensajes_anios":7,"tls_mutuo":"requerido"}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 6. SWIFT CSP 2025 — Controles de seguridad para conectividad SWIFT
(
  'swift_csp_2025_auth', NULL, 'd3_financial_ext.swift_csp_2025_auth',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'SWIFT CSP 2025', ARRAY['SWIFT CSP 2025 Mandatory Control 1.2A', 'SWIFT CSP 2025 Mandatory Control 4.1', 'SWIFT CSP 2025 Advisory Control 5.4A'],
  '{"title":"SWIFT Customer Security Programme 2025","description":"Institutions connected to SWIFT network must implement SWIFT CSP 2025 mandatory controls for authentication. Mandatory Control 1.2A: Restrict internet access. Mandatory Control 4.1: Password policy minimum 8 characters, complexity, 90-day expiry. Advisory Control 5.4A: Hardware token MFA for all SWIFT operators. The SBOS bAuth module must enforce these controls for any user accessing SWIFT-connected services.","mandatory_controls":{"1_2A":"Restrict and protect internet access to the local SWIFT infrastructure","4_1":{"password_min_length":8,"complexity":true,"max_age_days":90,"lockout_attempts":5},"5_4A_advisory":{"mfa_hardware_token":true,"token_types":["TOTP","FIDO2"]}},"annual_attestation_required":true}',
  '{"title":"SWIFT Customer Security Programme 2025","description":"SWIFT CSP 2025 mandatory authentication controls for institutions connected to SWIFT network. Includes restricted internet access, password policy, and hardware token MFA for operators.","mandatory_controls":{"1_2A":"Restrict internet access","4_1":{"password_min_length":8,"max_age_days":90},"5_4A_advisory":{"mfa_hardware_token":true}}}',
  '{"titulo":"Programa de Seguridad al Cliente SWIFT 2025","descripcion":"Controles de autenticación obligatorios SWIFT CSP 2025 para instituciones conectadas a la red SWIFT. Incluye acceso restringido a internet, política de contraseñas y token hardware MFA para operadores.","controles_obligatorios":{"1_2A":"Restringir acceso internet","4_1":{"longitud_min_contrasena":8,"max_dias_vigencia":90},"5_4A_recomendado":{"mfa_token_hardware":true}}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 7. SOX §404 — Control interno para sistemas financieros
(
  'sox_section404_internal_control', NULL, 'd3_financial_ext.sox_section404_internal_control',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'SOX §302/§404', ARRAY['SOX §404', 'PCAOB AS 2201', 'COSO 2013 Framework'],
  '{"title":"SOX Section 404 Internal Control — Financial System Access","description":"Public companies subject to SOX Section 404 must maintain adequate internal controls over financial reporting (ICFR). For SBOS: (1) All access to financial modules must be individually authenticated and logged, (2) Privileged access must require dual approval (SoD), (3) User access reviews every 90 days, (4) Segregation of duties: posting access ≠ approval access ≠ administrator access, (5) All changes to financial data must be audited with immutable log (WORM). Annual management assessment and auditor attestation required.","requirements":{"individual_auth":true,"privileged_dual_approval":true,"access_review_days":90,"sod_enforced":true,"immutable_audit_log":true,"annual_assessment":true,"log_retention_years":7}}',
  '{"title":"SOX Section 404 Internal Control","description":"SOX §404 requires adequate internal controls for financial reporting. SBOS must enforce individual authentication, dual approval for privileged access, 90-day access reviews, SoD, and immutable audit logging.","requirements":{"individual_auth":true,"privileged_dual_approval":true,"access_review_days":90,"sod_enforced":true,"immutable_audit_log":true,"log_retention_years":7}}',
  '{"titulo":"Control Interno SOX Sección 404","descripcion":"SOX §404 requiere controles internos adecuados para informes financieros. SBOS debe implementar autenticación individual, aprobación dual para acceso privilegiado, revisiones de acceso cada 90 días, SoD y registro de auditoría inmutable.","requisitos":{"auth_individual":true,"aprobacion_dual_privilegiado":true,"revision_acceso_dias":90,"sod_implementado":true,"registro_auditoria_inmutable":true,"retencion_registros_anios":7}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 8. Basel III — Controles de riesgo operacional para autenticación
(
  'basel_iii_operational_risk_auth', NULL, 'd3_financial_ext.basel_iii_operational_risk_auth',
  1, 0, 'policy', 'guideline', ARRAY['D3'], 'd3_financial_ext',
  'Basel III (BIS)', ARRAY['Basel III §634-654', 'BIS Principles for Sound Operational Risk Management (2021)', 'BCBS 239'],
  '{"title":"Basel III Operational Risk — Authentication Controls","description":"The Basel III framework requires banks to identify, assess and manage operational risk. Unauthorized access, authentication failures, and identity fraud are classified as operational risk events (ORCA category: Clients, Products and Business Practices). Requirements: (1) Authentication failures must be classified as operational risk events and reported, (2) MFA required for all transactions above risk threshold (AAL2+), (3) Suspicious authentication patterns trigger automated operational risk alerts, (4) Annual authentication security assessment as part of ICAAP, (5) RCSA (Risk and Control Self-Assessment) must include authentication controls.","risk_categories":{"fraud_type":"internal_external","regulatory_reporting":true,"mfa_threshold_usd":10000,"automated_alerts":true,"annual_assessment":"ICAAP"}}',
  '{"title":"Basel III Operational Risk Authentication Controls","description":"Authentication failures and identity fraud classified as operational risk events under Basel III. Requires MFA above risk threshold, automated alerts, and annual ICAAP assessment.","risk_categories":{"regulatory_reporting":true,"mfa_threshold_usd":10000,"automated_alerts":true}}',
  '{"titulo":"Controles Autenticación Riesgo Operacional Basel III","descripcion":"Los fallos de autenticación y el fraude de identidad se clasifican como eventos de riesgo operacional según Basilea III. Requiere MFA sobre umbral de riesgo, alertas automatizadas y evaluación ICAAP anual.","categorias_riesgo":{"reporte_regulatorio":true,"umbral_mfa_usd":10000,"alertas_automatizadas":true}}',
  'recommended', 'high', 'active', 'AAL2', true, false
),

-- 9. GDPR Art.22 — Decisiones automatizadas en procesos financieros
(
  'gdpr_art22_financial_automated_decisions', NULL, 'd3_financial_ext.gdpr_art22_financial_automated_decisions',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'GDPR Art.22', ARRAY['GDPR Art.22', 'GDPR Art.6(1)(b)', 'EBA Guidelines on Internal Governance 2021'],
  '{"title":"GDPR Art.22 — Automated Financial Decisions","description":"When SBOS makes automated decisions with legal or significant effects for financial transactions (credit scoring, fraud detection, access denial), GDPR Art.22 requirements apply: (1) Data subject must be informed about automated decision-making, (2) Right to human review must be provided, (3) Profiling for financial decisions must be based on lawful basis, (4) Authentication for contesting automated decisions requires verified identity (AAL2+). Explicit consent required for financial profiling beyond contractual necessity.","requirements":{"inform_subject":true,"human_review_right":true,"lawful_basis_required":true,"contest_auth_level":"AAL2","consent_for_profiling":true,"dpa_notification_required":true}}',
  '{"title":"GDPR Art.22 Automated Financial Decisions","description":"SBOS automated financial decisions with legal effects require GDPR Art.22 compliance: subject notification, human review right, lawful basis, and AAL2+ authentication for contesting decisions.","requirements":{"inform_subject":true,"human_review_right":true,"contest_auth_level":"AAL2","consent_for_profiling":true}}',
  '{"titulo":"Decisiones Financieras Automatizadas GDPR Art.22","descripcion":"Las decisiones financieras automatizadas de SBOS con efectos legales requieren cumplimiento GDPR Art.22: notificación al interesado, derecho de revisión humana, base legal y autenticación AAL2+ para impugnar decisiones.","requisitos":{"informar_interesado":true,"derecho_revision_humana":true,"nivel_auth_impugnacion":"AAL2","consentimiento_perfilado":true}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 10. Bolivia Ley 1178 SAFCO — Control gubernamental financiero
(
  'bolivia_safco_financial_control', NULL, 'd3_financial_ext.bolivia_safco_financial_control',
  1, 0, 'policy', 'standard', ARRAY['D3'], 'd3_financial_ext',
  'Bolivia Ley 1178 SAFCO', ARRAY['Bolivia Ley 1178 Art.1', 'Bolivia Ley 1178 Art.10', 'Bolivia DS 23215 Normas Básicas SACI'],
  '{"title":"Bolivia Ley 1178 SAFCO — Control Gubernamental Financiero","description":"Las entidades del sector público boliviano que usen SBOS para transacciones financieras deben cumplir la Ley 1178 (SAFCO) y el Reglamento SACI (Sistema de Administración y Control Interno). Requisitos: (1) Toda operación financiera debe tener un responsable identificado (autenticación individual obligatoria), (2) No se admiten firmas mancomunadas electrónicas sin firma digital certificada, (3) Las operaciones de compromisos presupuestarios requieren autenticación de dos funcionarios con roles diferentes (SoD), (4) Los logs de transacciones son de carácter público y deben conservarse 10 años, (5) Coordinación con SIGMA (Sistema Integrado de Gestión y Modernización Administrativa) para estados financieros.","requirements":{"individual_auth_mandatory":true,"certified_digital_signature":true,"sod_budget_commitments":true,"log_retention_years":10,"sigma_integration":true,"public_accountability":true}}',
  '{"title":"Bolivia SAFCO Law 1178 Financial Control","description":"Bolivian public sector entities using SBOS for financial transactions must comply with Law 1178 SAFCO. Requires individual authentication, certified digital signature, SoD for budget commitments, and 10-year log retention.","requirements":{"individual_auth_mandatory":true,"certified_digital_signature":true,"sod_budget_commitments":true,"log_retention_years":10}}',
  '{"titulo":"Control Financiero Gubernamental Ley 1178 SAFCO Bolivia","descripcion":"Las entidades del sector público boliviano deben cumplir la Ley 1178 SAFCO. Requiere autenticación individual, firma digital certificada, SoD para compromisos presupuestarios y retención de logs 10 años.","requisitos":{"auth_individual_obligatoria":true,"firma_digital_certificada":true,"sod_compromisos_presupuestarios":true,"retencion_logs_anios":10}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
)

ON CONFLICT (json_path) DO NOTHING;

SELECT COUNT(*) AS politicas_d3_incremento_insertadas FROM bauth.cfg_policy_library WHERE source = 'd3_financial_ext';
