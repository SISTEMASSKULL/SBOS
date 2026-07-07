-- =============================================================================
-- bauth_74__lib_d10_delegacion.sql — Políticas de delegación D10 (incremento)
-- =============================================================================
-- Propósito  : Agregar políticas del dominio delegación directamente a
--              cfg_policy_library (sin depender de JSON fuente).
-- Normas     : RFC 7521 (2015) — JWT Bearer Tokens for OAuth Assertions
--              RFC 8693 (2020) — OAuth 2.0 Token Exchange
--              RFC 7522 (2015) — SAML 2.0 Bearer Assertion
--              NIST SP 800-53 Rev.5 AC-2, AC-3(9) — Account/Access Management
--              NIST SP 800-207 (2020) — Zero Trust Architecture (delegation)
--              NIST SP 800-162 (2014) — ABAC (Attribute-Based Access Control)
--              ISO 27001:2022 A.9.2.3 — Management of privileged access rights
--              COBIT 2019 APO01.03 — Organizational structures delegation
--              SOX §302 — Delegation of financial authority
--              IEC 62443-2-1 — Delegation in industrial control systems
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

-- 1. OAuth 2.0 Token Exchange — Delegación de identidad entre servicios
(
  'oauth2_token_exchange_delegation', NULL, 'd10_delegation_ext.oauth2_token_exchange_delegation',
  1, 0, 'policy', 'standard', ARRAY['D10','D9'], 'd10_delegation_ext',
  'RFC 8693 (2020)', ARRAY['RFC 8693 §2.1', 'RFC 8693 §2.2', 'OAuth 2.0 Security BCP draft-ietf-oauth-security-topics'],
  '{"title":"OAuth 2.0 Token Exchange for Delegation","description":"Service-to-service delegation within SBOS uses OAuth 2.0 Token Exchange (RFC 8693). A subject_token can be exchanged for an actor_token representing the calling service acting on behalf of the subject. Requirements: (1) Token exchange endpoint at /bauth/token/exchange, (2) may_act claim required in original token for impersonation scenarios, (3) act claim in exchanged token preserves delegation chain (actor chain), (4) Maximum delegation depth: 3 hops, (5) Exchange token valid: max 15 minutes (inherits access_token lifetime), (6) Actor tokens audited separately in aud_event with delegation chain logged, (7) Token exchange requires mutual TLS (mTLS) between services per RFC 8705.","configuration":{"endpoint":"/bauth/token/exchange","max_delegation_depth":3,"exchanged_token_max_minutes":15,"mtls_required":true,"act_claim":"delegation_chain_logged","may_act_claim":"required_for_impersonation"},"token_types":["urn:ietf:params:oauth:token-type:access_token","urn:ietf:params:oauth:token-type:jwt"]}',
  '{"title":"OAuth 2.0 Token Exchange Delegation","description":"RFC 8693 token exchange for service delegation. max_depth=3, 15min token lifetime, mTLS required between services, act chain logged, may_act claim for impersonation.","configuration":{"max_delegation_depth":3,"exchanged_token_max_minutes":15,"mtls_required":true}}',
  '{"titulo":"Delegación OAuth 2.0 Token Exchange","descripcion":"Intercambio de tokens RFC 8693 para delegación de servicios. prof_max=3, duración 15min, mTLS requerido entre servicios, cadena act registrada, claim may_act para suplantación.","configuracion":{"profundidad_delegacion_max":3,"token_intercambiado_max_minutos":15,"mtls_requerido":true}}',
  'mandatory', 'critical', 'active', 'AAL2', true, true
),

-- 2. ABAC — Delegación basada en atributos
(
  'abac_attribute_based_delegation', NULL, 'd10_delegation_ext.abac_attribute_based_delegation',
  1, 0, 'policy', 'standard', ARRAY['D10','D1'], 'd10_delegation_ext',
  'NIST SP 800-162', ARRAY['NIST SP 800-162 §4.2', 'NIST SP 800-162 §5.3', 'NIST SP 800-53 Rev.5 AC-3(9)'],
  '{"title":"Attribute-Based Access Control Delegation Policy","description":"SBOS implements ABAC for fine-grained delegation control per NIST SP 800-162. Subject attributes, object attributes, environment attributes, and action attributes combine in policy rules to authorize delegation. Requirements: (1) Delegation authority derived from role + organizational position + time + location attributes, (2) Delegated permissions cannot exceed delegator permissions (no privilege escalation), (3) ABAC policies expressed in XACML 3.0 or equivalent policy language, (4) Policy evaluation engine: Policy Decision Point (PDP) in bAuth, (5) Policy enforcement: Policy Enforcement Point (PEP) in Kong gateway, (6) Attribute sources: LDAP/AD, bAuth user template, JWT claims, (7) Dynamic attribute resolution: max 50ms per decision.","attributes":{"subject":["role","department","clearance_level","employment_status"],"object":["classification","owner","sensitivity"],"environment":["time","location","network_zone"],"action":["read","write","delegate","approve"]},"max_decision_ms":50,"no_privilege_escalation":true,"policy_language":"XACML 3.0"}',
  '{"title":"ABAC Delegation Policy","description":"NIST SP 800-162 ABAC for delegation: subject/object/environment/action attributes. No privilege escalation in delegation. XACML 3.0 policies, max 50ms PDP evaluation.","attributes":{"subject":["role","department"],"environment":["time","location"],"no_privilege_escalation":true}}',
  '{"titulo":"Política Delegación Basada en Atributos ABAC","descripcion":"ABAC NIST SP 800-162 para delegación: atributos de sujeto/objeto/entorno/acción. Sin escalada de privilegios en delegación. Políticas XACML 3.0, evaluación PDP máximo 50ms.","atributos":{"sujeto":["rol","departamento"],"entorno":["tiempo","ubicacion"],"sin_escalada_privilegios":true}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 3. SoD en delegación — Segregación de funciones
(
  'delegation_separation_of_duties', NULL, 'd10_delegation_ext.delegation_separation_of_duties',
  1, 0, 'policy', 'standard', ARRAY['D10'], 'd10_delegation_ext',
  'NIST SP 800-53 Rev.5', ARRAY['NIST SP 800-53 Rev.5 AC-5', 'NIST SP 800-53 Rev.5 AC-6', 'ISO 27001:2022 A.9.2.3', 'SOX §404'],
  '{"title":"Separation of Duties in Delegation","description":"Delegation in SBOS must enforce Separation of Duties (SoD) to prevent conflict of interest and fraud. Static SoD rules (compiled at role design time): (1) The delegator cannot be the same as the delegate approver, (2) The transaction initiator cannot approve the same transaction, (3) The system administrator cannot also be the auditor. Dynamic SoD rules (evaluated at runtime): (1) Cross-reference delegation requests against existing user roles for conflicts, (2) SoD matrix maintained in bauth.fin_sod_rule, (3) Delegation requests that violate SoD automatically denied with CISO notification. Override only with dual CISO+CTO approval, documented, time-limited.","static_sod_rules":["delegator_ne_approver","initiator_ne_approver","sysadmin_ne_auditor"],"dynamic_sod":{"evaluation":"runtime","conflict_matrix":"bauth.fin_sod_rule","violation_action":"DENY_plus_CISO_notify"},"override":{"required_approvers":["CISO","CTO"],"documented":true,"time_limited":true}}',
  '{"title":"SoD in Delegation","description":"Static SoD: delegator≠approver, initiator≠approver, sysadmin≠auditor. Dynamic SoD from bauth.fin_sod_rule. Violations denied + CISO notify. Override requires CISO+CTO dual approval.","static_sod_rules":["delegator_ne_approver","initiator_ne_approver","sysadmin_ne_auditor"]}',
  '{"titulo":"Separación de Funciones en Delegación","descripcion":"SoD estático: delegador≠aprobador, iniciador≠aprobador, sysadmin≠auditor. SoD dinámico desde bauth.fin_sod_rule. Violaciones denegadas + notificación CISO. Anulación requiere aprobación dual CISO+CTO.","reglas_sod_estaticas":["delegador_ne_aprobador","iniciador_ne_aprobador","sysadmin_ne_auditor"]}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 4. Revocación inmediata de delegación
(
  'delegation_revocation_immediate', NULL, 'd10_delegation_ext.delegation_revocation_immediate',
  1, 0, 'policy', 'policy', ARRAY['D10'], 'd10_delegation_ext',
  'NIST SP 800-53 Rev.5', ARRAY['NIST SP 800-53 Rev.5 AC-2(3)', 'NIST SP 800-53 Rev.5 IA-3(1)', 'ISO 27001:2022 A.9.2.6'],
  '{"title":"Immediate Delegation Revocation Policy","description":"Delegated access in SBOS must be revocable immediately with near-real-time effect. Requirements: (1) Revocation propagated within 30 seconds via Redis pub/sub to all SBOS nodes, (2) Active sessions using revoked delegation must be terminated (session invalidation via JWT blacklist + WebSocket close), (3) Revocation triggers: role change, employment termination, security incident, voluntary revocation, expiry, (4) Delegate notified via email/push notification within 60 seconds of revocation, (5) Delegator can revoke any delegation they granted at any time, (6) Admin can revoke any delegation (emergency), (7) Revocation logged immutably in audit log with: actor, target, reason, timestamp, (8) Cascade revocation: revoking a delegation revokes all sub-delegations derived from it.","revocation_propagation_seconds":30,"session_invalidation":true,"notification_seconds":60,"cascade":true,"triggers":["role_change","termination","security_incident","voluntary","expiry"],"audit":"immutable_log_with_reason"}',
  '{"title":"Immediate Delegation Revocation","description":"Revocation within 30s via Redis pub/sub. Active sessions terminated (JWT blacklist + WebSocket close). Delegate notified within 60s. Cascade revocation of sub-delegations. Immutable audit log.","revocation_propagation_seconds":30,"cascade":true}',
  '{"titulo":"Revocación Inmediata de Delegación","descripcion":"Revocación en 30s vía Redis pub/sub. Sesiones activas terminadas (blacklist JWT + cierre WebSocket). Delegado notificado en 60s. Revocación en cascada de sub-delegaciones. Registro auditoría inmutable.","propagacion_revocacion_segundos":30,"cascada":true}',
  'mandatory', 'critical', 'active', 'AAL1', false, false
),

-- 5. Delegación temporal de autoridad financiera
(
  'financial_authority_delegation', NULL, 'd10_delegation_ext.financial_authority_delegation',
  1, 0, 'policy', 'standard', ARRAY['D10','D3'], 'd10_delegation_ext',
  'SOX §302', ARRAY['SOX §302', 'SOX §404', 'NIST SP 800-53 Rev.5 AC-2(6)', 'COBIT 2019 APO09.03'],
  '{"title":"Financial Authority Delegation Policy","description":"Delegation of financial authority (approval limits, signing authority, budget allocation) in SBOS must comply with SOX §302 requirements. Requirements: (1) Financial delegation must be in writing (digital signature) with defined scope and amount limit, (2) Delegation cannot exceed 50% of delegator own authority without Board approval, (3) Financial delegation automatically expires on: role change, employment termination, maximum 1 year, (4) All financial transactions executed under delegation logged with: original authority, delegate, amount, scope, (5) Dual control for transactions exceeding $50,000 (two delegates), (6) Delegated financial authority cannot be sub-delegated without explicit authorization chain, (7) Annual review of all active financial delegations mandatory.","limits":{"max_delegation_pct_of_delegator":50,"auto_expiry_days":365,"dual_control_threshold_usd":50000,"sub_delegation":"requires_explicit_chain"},"documentation":{"digital_signature_required":true,"scope_defined":true,"amount_limit_defined":true},"annual_review":true}',
  '{"title":"Financial Authority Delegation","description":"SOX §302 financial delegation: max 50% of delegator authority, 1-year max, dual control >$50k. Sub-delegation requires explicit chain. Annual review mandatory. All transactions logged.","limits":{"max_delegation_pct":50,"auto_expiry_days":365,"dual_control_threshold_usd":50000}}',
  '{"titulo":"Delegación Autoridad Financiera","descripcion":"Delegación financiera SOX §302: máximo 50% de la autoridad del delegador, máximo 1 año, control dual >$50k. Sub-delegación requiere cadena explícita. Revisión anual obligatoria. Todas las transacciones registradas.","limites":{"porcentaje_max_delegacion":50,"expiracion_automatica_dias":365,"umbral_control_dual_usd":50000}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 6. Impersonación controlada (run-as)
(
  'controlled_impersonation_run_as', NULL, 'd10_delegation_ext.controlled_impersonation_run_as',
  1, 0, 'policy', 'policy', ARRAY['D10'], 'd10_delegation_ext',
  'NIST SP 800-207', ARRAY['NIST SP 800-207 §2.2', 'NIST SP 800-53 Rev.5 AU-2(4)', 'OWASP ASVS v5.0 §4.2.3'],
  '{"title":"Controlled Impersonation (Run-As) Policy","description":"Impersonation (acting as another user) is permitted in SBOS only under strict controls for support/audit purposes. Requirements: (1) Impersonation requires: admin AAL3 authentication + supervisor written approval + logged reason, (2) Impersonation sessions are visually marked (UI indicator) — the user cannot be unaware they are being impersonated during an active session, (3) All actions during impersonation logged under BOTH the admin actor AND the target user, (4) Impersonation time limit: maximum 30 minutes per session, (5) Real-time SOC monitoring during impersonation sessions, (6) User receives notification AFTER impersonation ends (post-session notification) with summary of actions taken, (7) Impersonation prohibited for: financial transactions above $1,000, document signing, permission changes, password resets.","requirements":{"admin_aal":"AAL3","supervisor_approval":true,"logged_reason":true,"session_limit_minutes":30,"dual_logging":true,"soc_monitoring":true,"post_session_notification":true},"prohibitions":{"financial_above_usd":1000,"document_signing":true,"permission_changes":true,"password_resets":true}}',
  '{"title":"Controlled Impersonation Run-As Policy","description":"Impersonation requires AAL3 + supervisor approval + reason. 30min limit, dual logging, SOC monitoring. Post-session notification. Prohibited: transactions >$1k, signing, permission changes.","requirements":{"admin_aal":"AAL3","session_limit_minutes":30,"dual_logging":true}}',
  '{"titulo":"Política Suplantación Controlada (Run-As)","descripcion":"La suplantación requiere AAL3 + aprobación supervisor + razón. Límite 30min, registro dual, monitoreo SOC. Notificación post-sesión. Prohibido: transacciones >$1k, firma, cambios de permisos.","requisitos":{"aal_admin":"AAL3","limite_sesion_minutos":30,"registro_dual":true}}',
  'mandatory', 'critical', 'active', 'AAL3', true, true
),

-- 7. Alcance limitado de delegación (scoped delegation)
(
  'scoped_constrained_delegation', NULL, 'd10_delegation_ext.scoped_constrained_delegation',
  1, 0, 'policy', 'policy', ARRAY['D10'], 'd10_delegation_ext',
  'NIST SP 800-53 Rev.5', ARRAY['NIST SP 800-53 Rev.5 AC-3(9)', 'NIST SP 800-162 §4.3', 'Kerberos RFC 4556 S4U2Proxy'],
  '{"title":"Scoped Constrained Delegation Policy","description":"Delegation in SBOS must be scoped to minimum necessary resources and actions. Unconstrained delegation (access to all delegator resources) is prohibited. Requirements: (1) Every delegation must specify: resource scope (specific services/APIs), action scope (specific operations), time scope (start-end datetime), geographic scope (optional), (2) OAuth 2.0 scope parameter must exactly define delegated permissions, (3) Kerberos constrained delegation (S4U2Proxy) only to explicitly listed services, (4) Delegation scope cannot be modified after creation — requires re-delegation, (5) Service accounts (M2M) use constrained delegation scoped to specific API endpoints only.","scoping_requirements":{"resource_scope":"mandatory","action_scope":"mandatory","time_scope":"mandatory","geographic_scope":"optional"},"unconstrained_delegation":"prohibited","delegation_modification":"requires_new_delegation","m2m_endpoint_restriction":true}',
  '{"title":"Scoped Constrained Delegation","description":"All delegations must specify resource, action, and time scope. Unconstrained delegation prohibited. OAuth scope exact match required. Delegation cannot be modified — requires new delegation. M2M scoped to specific API endpoints.","scoping_requirements":{"resource_scope":"mandatory","action_scope":"mandatory","time_scope":"mandatory"}}',
  '{"titulo":"Delegación Restringida por Alcance","descripcion":"Todas las delegaciones deben especificar alcance de recurso, acción y tiempo. Delegación sin restricciones prohibida. Coincidencia exacta de ámbito OAuth requerida. La delegación no se puede modificar — requiere nueva delegación. M2M restringido a endpoints API específicos.","requisitos_alcance":{"alcance_recurso":"obligatorio","alcance_accion":"obligatorio","alcance_tiempo":"obligatorio"}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 8. Auditoría completa de cadena de delegación
(
  'delegation_chain_audit_trail', NULL, 'd10_delegation_ext.delegation_chain_audit_trail',
  1, 0, 'policy', 'standard', ARRAY['D10','D11'], 'd10_delegation_ext',
  'ISO 27001:2022', ARRAY['ISO 27001:2022 A.8.15', 'ISO 27001:2022 A.9.2.3', 'NIST SP 800-53 Rev.5 AU-12(3)', 'SOX §404'],
  '{"title":"Delegation Chain Audit Trail Policy","description":"Every delegation action in SBOS must be recorded in an immutable audit trail that captures the complete delegation chain. Requirements: (1) Audit record per delegation event: delegator, delegate, scope, approval, creation_time, expiry_time, revoker (if revoked), (2) Delegation chain recorded in act claim of JWT (RFC 8693 §4.1), (3) Audit records stored in bauth.aud_event with immutable flag, (4) Audit trail retention: 7 years (SOX), accessible for regulatory inspection, (5) Real-time delegation monitoring dashboard for CISO, (6) Automated report: weekly delegation activity summary to admin, (7) SIEM integration: delegation anomalies forwarded to Wazuh/SIEM within 30 seconds.","audit_fields":["delegator_id","delegate_id","scope_hash","approval_signature","created_at","expires_at","revoked_at","revoke_reason","jwt_act_chain"],"retention_years":7,"immutable":true,"siem_forwarding_seconds":30,"weekly_report":true}',
  '{"title":"Delegation Chain Audit Trail","description":"Immutable audit trail per delegation event: delegator, delegate, scope, approval, times, revocation. act JWT chain per RFC 8693. 7-year retention. SIEM forwarding <30s. Weekly admin report.","audit_fields":["delegator_id","delegate_id","scope_hash","created_at","expires_at"],"retention_years":7}',
  '{"titulo":"Pista Auditoría Cadena de Delegación","descripcion":"Pista de auditoría inmutable por evento de delegación: delegador, delegado, alcance, aprobación, tiempos, revocación. Cadena act JWT según RFC 8693. Retención 7 años. Reenvío SIEM <30s. Informe semanal admin.","campos_auditoria":["id_delegador","id_delegado","hash_alcance","creado_en","expira_en"],"retencion_anios":7}',
  'mandatory', 'high', 'active', 'AAL1', false, false
)

ON CONFLICT (json_path) DO NOTHING;

SELECT COUNT(*) AS politicas_d10_incremento_insertadas FROM bauth.cfg_policy_library WHERE source = 'd10_delegation_ext';
