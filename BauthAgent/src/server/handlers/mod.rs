// ============================================================
// bauth::server::handlers — Handlers JSON-RPC 2.0 por método
// Cada handler en su propio archivo (DOC-SBOS-001 N3: ≤200 líneas)
// ============================================================
pub mod health;
pub mod policy_evaluate;
pub mod role_compute_mask;
pub mod access_evaluate;   // H-15: Evaluación de acceso completa (FastPath + PolicyPath)
pub mod inheritance_evaluate; // H-16: Herencia DAG (closure table + máscara efectiva)
pub mod sod_check;           // H-17: SoD Conflict Check (fin_sod_rule → ConflictMatrix)
pub mod role_template;       // B10: RolTemplate CRUD (list/get templates v6.0)
pub mod template_validate;   // B10: Validador de hardening (60+ reglas NIST/OWASP/FIDO2)
pub mod token_issue;         // B48.T03: Emisor de tokens JWT de bAuth
pub mod token_validate;      // B48.T04: Validador de tokens JWT
pub mod token_jwks;          // B48.T04: JWKS endpoint (RFC 7517)
pub mod ctx_validate;
pub mod saga_list;
pub mod saga_execute;
pub mod role_list;
pub mod user_list;
pub mod sync_reconcile;
pub mod sync_status;
pub mod framework_crud;    // H-13: CRUD para 6 tablas del framework
pub mod domain_audit;     // H-14: DomainEvaluationAudit + H-15: DomainConfig
pub mod domain_logical;    // B3: LogicalDomain (D1)
pub mod domain_financial;  // B4: FinancialDomain (D3)
pub mod domain_biometric;  // B5: BiometricDomain (D5)
pub mod context_plane;   // B16: Context Plane (SBOS-049)
pub mod domain_physical;    // B2: PhysicalDomain (D2)
pub mod domain_geospatial;  // B7: GeospatialDomain (D6)
pub mod domain_temporal;    // B6: TemporalDomain (D4)
pub mod domain_network;     // B8: NetworkDomain (D7)
pub mod commercial;      // B33: Productos Comerciales D12
pub mod idp_external;    // B34: IdP Externo (OIDC Discovery, SAML, SCIM, Admin API)
pub mod blockchain_panel; // B29.T20: Panel Blockchain — lotes, verificar, publicar, liquidaciones
pub mod context_evaluate; // B45.D01: Evaluador de 12 dominios vía DomainRegistry
pub mod policy_domain;   // B9.T24: PolicyEngine sobre ath_policy_dN (D1-D12)
pub mod policy_admin;    // B9.T25: PolicyAdministrator CRUD (create/update/delete/validate/list)
pub mod policy_simulate;     // B9.T27: PolicySimulator — dry-run de cambios de políticas
pub mod policy_distribution; // B9.T29: PolicyDistributionMonitor — NIST SP 800-207 CDM
pub mod framework_reload;    // B9.T31: FrameworkHotReload — recarga JSON sin reiniciar
pub mod keycloak_sync;       // B12: KeycloakEngine — sync roles/users + reconcile
pub mod user_template;       // B11: UserTemplate CRUD — get/create/update/delete/assign_role/revoke_role
pub mod notify_send;         // G2: bnotify integration — enviar notificaciones (stub/dev)
pub mod webauthn_handlers;   // G3: WebAuthn API — register/authenticate via JSON-RPC
pub mod vault_pki;           // G6: Vault PKI — emitir/revocar certificados X.509
pub mod org_structure;       // H-028: list org_empresa, org_sucursal, org_pos_logico
pub mod org_crud;            // CRUD: crear/actualizar/eliminar tenant, empresa, sucursal, pos
pub mod domain_crud;         // CRUD: subdominios por tenant (idn_tenant_domain)
pub mod oidc_provider;       // Fase 2: OIDC Provider Nativo (Discovery, Token, Introspect, UserInfo)
pub mod tenant_list;       // Tenant CRUD (list desde idn_tenant)
pub mod sign_internal;     // Firma digital interna Ed25519
pub mod merge_templates;   // B45.D02: merge_role_templates()
pub mod dashboard_panels;  // B47.D01-D10: 10 paneles dashboard
pub mod token_refresh;     // B48.T05: bauth.token.refresh
pub mod scim_server;       // B48.T20-T25: SCIM v2 server
pub mod self_service;      // B48.T30-T34: User self-service
pub mod token_protocols;   // B48.T40-T42: Token Exchange + DPoP + Introspection
pub mod kong_oauth;        // B48.T50-T52: Kong PEP + OAuth2-Proxy + Rate-limiting
pub mod device_identity;   // B48.T63-T66: Device register/attest/transfer/trust
pub mod role_lifecycle;    // B10.T76-T89: Role lifecycle, impact, search, bulk, rollback, batch (panel1,1b,4,9,9b,10,11,12,13,78)
