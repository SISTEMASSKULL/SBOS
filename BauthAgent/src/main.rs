// ================================================================
// bauth — SBOS Identity Core v3.0 · BitMask Dual
// Entry point. Señales, shutdown graceful, systemd notify.
//
// Orden de inicio:
//   1. Preflight (B0.T09) — valida el entorno ANTES de todo
//   2. Configuración (B0.T04) — carga y valida TOML
//   3. Drain manager (B0.T05) — gestor de conexiones activas
//   4. Unix socket (B0.T07) — Interface Dual ADR-020
//   5. systemd notify (B0.T06) — READY=1
//   6. Señales (B0.T05) — esperar SIGTERM/SIGHUP
//
// Estándares: DOC-SBOS-001 N3 · ADR-001/002 · BAUTH-010
// SAM-128 ELIMINADO. BitmaskBundle ELIMINADO.
// ================================================================

use std::process;
use tracing::{error, info, warn};

mod config;
mod preflight;   // B0.T09: validador de pre-vuelo
mod bitmask;     // 🆕 BitMask Dual v3.0 (AtomBitMask + RolBitMask)
mod domain;
mod signal;
mod engine;
mod server;
// mod sync;        // B12+
mod catalog;       // H-04 H-05 H-06 H-09 — Fase 1: Catálogo de Átomos
mod saga;          // H-10 H-11 H-12       — Fase 3: Motor de Sagas + HIBP + Risk
mod context;       // B16                 — Context Plane (SBOS-049) W3C Trace Context
mod blockchain;    // D12: AnchorClient + AuditAnchor.sol integration
mod db;          // B1.T19: acceso a PostgreSQL
mod sync;         // B45.D03: reconcile loop extendido
mod sdk;           // B48.T10-T13: SDK multi-lenguaje (contratos de API)
// mod audit;       // B17+

const VERSION: &str = env!("CARGO_PKG_VERSION");
use std::sync::OnceLock;
static START_TIME: OnceLock<std::time::Instant> = OnceLock::new();

/// Uptime del daemon en segundos. H-007 FIX.
pub fn uptime_seconds() -> u64 {
    START_TIME.get().map(|t| t.elapsed().as_secs()).unwrap_or(0)
}

/// Ruta canónica del socket Unix. Fuente única: config::ServerConfig::default_socket_path().
const SOCKET_PATH: &str = config::DEFAULT_SOCKET_PATH;

#[tokio::main]
async fn main() {
    // ── Fase 0: Logging ──────────────────────────────────
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    START_TIME.set(std::time::Instant::now()).ok();
    info!(version = VERSION, pid = process::id(), "bauth iniciando");

    // ── Fase 1: Preflight (B0.T09) ───────────────────────
    // Valida el entorno ANTES de cualquier inicialización.
    // Si falla, aborta con mensajes accionables.
    let preflight_cfg = preflight::PreflightConfig {
        socket_path: std::path::PathBuf::from(SOCKET_PATH),
        socket_group: "bosagent".into(),
        socket_dir_perms: 0o750,
        config_path: Some(std::path::PathBuf::from("/etc/bos/bauth.toml")),
        min_fd_limit: 4096,
    };

    if let Err(failures) = preflight::run(&preflight_cfg) {
        error!(fallos = failures.len(), "preflight falló — abortando");
        eprintln!("{}", preflight::format_failures(&failures));
        process::exit(2);
    }
    info!("preflight: entorno validado");

    // ── Fase 2: Configuración (B0.T04) ───────────────────
    let cfg = match config::load() {
        Ok(c) => { info!("configuración cargada"); c }
        Err(e) => { error!(error = %e, "fallo al cargar configuración"); process::exit(1); }
    };

    // ── Fase 2.5: Base de datos (B1.T19) ──────────────────
    // La DDL y seeds son responsabilidad del instalador (bosctl install).
    // El daemon solo conecta — sin verificar esquema ni precargar catálogos.
    // Cualquier handler que necesite datos los consulta lazy de PostgreSQL.
    let db_ctx = match db::init(&cfg).await {
        Ok(ctx) => {
            info!("base de datos conectada");
            Some(ctx)
        }
        Err(e) => {
            warn!(error = %e, "base de datos no disponible — operando en modo degradado");
            None
        }
    };

    // ── Fase 3: Drenaje (B0.T05) ─────────────────────────
    let drain = signal::DrainManager::new();

    // ── Fase 4: JSON-RPC 2.0 Dispatcher (ADR-020) ──────────
    // SEC-001 FIX: Signer compartido UNA VEZ al inicio del daemon
    // H-008 FIX: propagate error instead of panic
    let jwt_signer = match domain::jwt_signer::JwtSigner::new_development() {
        Ok(signer) => {
            warn!("JwtSigner en modo development — clave Ed25519 efimera. H-031: en prod usar Vault PKI.");
            std::sync::Arc::new(signer)
        }
        Err(e) => {
            error!(%e, "JwtSigner: generacion de clave Ed25519 fallo");
            process::exit(1);
        }
    };
    let mut dispatcher = server::jsonrpc::JsonRpcDispatcher::new();
    dispatcher.register("bauth.health.check",
        std::sync::Arc::new(server::handlers::health::HealthHandler {
            socket_path: SOCKET_PATH.to_string(),
        }));
    dispatcher.register("bauth.policy.evaluate",
        std::sync::Arc::new(server::handlers::policy_evaluate::PolicyEvaluateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.compute_mask",
        std::sync::Arc::new(server::handlers::role_compute_mask::RoleComputeMaskHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.access.evaluate",
        std::sync::Arc::new(server::handlers::access_evaluate::AccessEvaluateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.inheritance.compute",
        std::sync::Arc::new(server::handlers::inheritance_evaluate::InheritanceComputeHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.inheritance.check",
        std::sync::Arc::new(server::handlers::inheritance_evaluate::InheritanceCheckHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.sod.check",
        std::sync::Arc::new(server::handlers::sod_check::SodCheckHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.template.list",
        std::sync::Arc::new(server::handlers::role_template::RoleTemplateListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.template.get",
        std::sync::Arc::new(server::handlers::role_template::RoleTemplateGetHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.template.validate",
        std::sync::Arc::new(server::handlers::template_validate::TemplateValidateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B10: RolTemplate CRUD ──────────────────────────────
    dispatcher.register("bauth.role.template.create",
        std::sync::Arc::new(server::handlers::role_template::RoleTemplateCreateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.template.update",
        std::sync::Arc::new(server::handlers::role_template::RoleTemplateUpdateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.template.delete",
        std::sync::Arc::new(server::handlers::role_template::RoleTemplateDeleteHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    let jwt_cfg = cfg.jwt.clone();
    dispatcher.register("bauth.token.issue",
        std::sync::Arc::new(server::handlers::token_issue::TokenIssueHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
            signer: jwt_signer.clone(),
            jwt_cfg: jwt_cfg.clone(),
        }));
    dispatcher.register("bauth.token.validate",
        std::sync::Arc::new(server::handlers::token_validate::TokenValidateHandler {
            signer: jwt_signer.clone(),
        }));
    dispatcher.register("bauth.token.jwks",
        std::sync::Arc::new(server::handlers::token_jwks::TokenJwksHandler {
            signer: jwt_signer.clone(),
            jwt_cfg: jwt_cfg.clone(),
        }));
    dispatcher.register("bauth.saga.list",
        std::sync::Arc::new(server::handlers::saga_list::SagaListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    let saga_registry = db_ctx.as_ref().map(|db| {
        std::sync::Arc::new(saga::registry::default_registry(db.pg.clone(), cfg.hibp.clone()))
    });
    dispatcher.register("bauth.saga.execute",
        std::sync::Arc::new(server::handlers::saga_execute::SagaExecuteHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
            registry: saga_registry.clone(),
        }));
    dispatcher.register("bauth.role.list",
        std::sync::Arc::new(server::handlers::role_list::RoleListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.role.merge",
        std::sync::Arc::new(server::handlers::merge_templates::MergeTemplatesHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B11: UserTemplate CRUD ────────────────────────────
    dispatcher.register("bauth.user.get",
        std::sync::Arc::new(server::handlers::user_template::UserGetHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.user.create",
        std::sync::Arc::new(server::handlers::user_template::UserCreateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.user.update",
        std::sync::Arc::new(server::handlers::user_template::UserUpdateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.user.delete",
        std::sync::Arc::new(server::handlers::user_template::UserDeleteHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.user.assign_role",
        std::sync::Arc::new(server::handlers::user_template::UserAssignRoleHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.user.revoke_role",
        std::sync::Arc::new(server::handlers::user_template::UserRevokeRoleHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── G3: WebAuthn API ──────────────────────────────────
    let webauthn_validator = std::sync::Arc::new(
        domain::auth_methods::webauthn::WebAuthnValidator::new("bauth.sbos.bo")
    );
    dispatcher.register("bauth.webauthn.register",
        std::sync::Arc::new(server::handlers::webauthn_handlers::WebAuthnRegisterHandler {
            validator: webauthn_validator.clone(),
        }));
    dispatcher.register("bauth.webauthn.verify_registration",
        std::sync::Arc::new(server::handlers::webauthn_handlers::WebAuthnVerifyRegistrationHandler {
            validator: webauthn_validator.clone(),
        }));
    dispatcher.register("bauth.webauthn.authenticate",
        std::sync::Arc::new(server::handlers::webauthn_handlers::WebAuthnAuthenticateHandler {
            validator: webauthn_validator.clone(),
        }));
    dispatcher.register("bauth.webauthn.verify_authentication",
        std::sync::Arc::new(server::handlers::webauthn_handlers::WebAuthnVerifyAuthHandler {
            validator: webauthn_validator.clone(),
        }));
    // ── G2: bnotify integration (H-001, H-002, H-003, H-004 FIX) ──
    let notify_cfg = domain::notify_config::NotifyConfig::load();
    if !notify_cfg.has_mm_token() {
        warn!("MM_TOKEN no configurado — notificaciones a Mattermost deshabilitadas");
    }

    let notify_client: std::sync::Arc<dyn domain::notify::NotifyClient> =
        if std::path::Path::new(&notify_cfg.bnotify_socket).exists() {
            std::sync::Arc::new(domain::notify::SbOsNotifierClient::new(&notify_cfg.bnotify_socket))
        } else {
            std::sync::Arc::new(domain::notify::StubNotifyClient)
        };
    // C-BAUTH-004: transmisor CAEP (SSF Transmitter) hacia bNotify — gRPC
    // sobre el mismo Unix socket. Stub mientras bnotify no esté desplegado.
    let caep_tx = engine::caep_client::fabricar(&notify_cfg.bnotify_socket);
    dispatcher.register("bauth.notify.send",
        std::sync::Arc::new(server::handlers::notify_send::NotifySendHandler {
            client: notify_client.clone(),
        }));
    // Notificador automatico de seguridad → Mattermost
    let security_notifier = std::sync::Arc::new(
        domain::security_notify::SecurityNotifier::new(
            notify_client.clone(),
            &notify_cfg.tenant_security_hook,
        )
    );
    // Notificador jerarquico ctx_id → tenant/empresa/sucursal/usuario
    let mut hierarchical_notifier = domain::hierarchical_notify::HierarchicalNotifier::new(
        notify_client.clone(),
        &notify_cfg.tenant_security_hook,
        &notify_cfg.mattermost_url,
        &notify_cfg.mattermost_token,
        db_ctx.as_ref().map(|c| c.pg.clone()),
    );
    // Cargar hooks desde config (H-003 FIX)
    for empresa in &notify_cfg.empresa_hooks {
        hierarchical_notifier.add_empresa(&empresa.empresa_id, &empresa.webhook_token);
    }
    for sucursal in &notify_cfg.sucursal_hooks {
        hierarchical_notifier.add_sucursal(&sucursal.sucursal_id, &sucursal.webhook_token);
    }
    let hierarchical_notifier = std::sync::Arc::new(hierarchical_notifier);
    // ── H-028: org_empresa, org_sucursal, org_pos_logico ──
    dispatcher.register("bauth.org.empresa.list",
        std::sync::Arc::new(server::handlers::org_structure::OrgEmpresaListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.org.sucursal.list",
        std::sync::Arc::new(server::handlers::org_structure::OrgSucursalListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.org.pos.list",
        std::sync::Arc::new(server::handlers::org_structure::OrgPosListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── CRUD: Empresa ─────────────────────────────────────
    dispatcher.register("bauth.org.empresa.create",
        std::sync::Arc::new(server::handlers::org_crud::EmpresaCreateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.org.empresa.update",
        std::sync::Arc::new(server::handlers::org_crud::EmpresaUpdateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.org.empresa.delete",
        std::sync::Arc::new(server::handlers::org_crud::EmpresaDeleteHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    // ── CRUD: Sucursal ────────────────────────────────────
    dispatcher.register("bauth.org.sucursal.create",
        std::sync::Arc::new(server::handlers::org_crud::SucursalCreateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.org.sucursal.delete",
        std::sync::Arc::new(server::handlers::org_crud::SucursalDeleteHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    // ── CRUD: Pos Logico ──────────────────────────────────
    dispatcher.register("bauth.org.pos.create",
        std::sync::Arc::new(server::handlers::org_crud::PosCreateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.user.list",
        std::sync::Arc::new(server::handlers::user_list::UserListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.sync.reconcile",
        std::sync::Arc::new(server::handlers::sync_reconcile::SyncReconcileHandler));
    dispatcher.register("bauth.sync.status",
        std::sync::Arc::new(server::handlers::sync_status::SyncStatusHandler));

    // ── Fase 4: CRUD Framework (H-13) ─────────────────
    dispatcher.register("bauth.method.list",
        std::sync::Arc::new(server::handlers::framework_crud::MethodListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.fw.list",
        std::sync::Arc::new(server::handlers::framework_crud::PolicyListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.config.list",
        std::sync::Arc::new(server::handlers::framework_crud::ConfigListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.crypto.list",
        std::sync::Arc::new(server::handlers::framework_crud::CryptoListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.federation.list",
        std::sync::Arc::new(server::handlers::framework_crud::FederationListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.compliance.list",
        std::sync::Arc::new(server::handlers::framework_crud::ComplianceListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── Fase 4: Audit + Config (H-14 H-15) ─────────────
    // ── B2-B12: 12 Dominios de Soberanía ──────────────
    dispatcher.register("bauth.domain.physical.list",
        std::sync::Arc::new(server::handlers::domain_physical::PhysicalAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.logical.list",
        std::sync::Arc::new(server::handlers::domain_logical::LogicalAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.financial.list",
        std::sync::Arc::new(server::handlers::domain_financial::FinancialAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.biometric.list",
        std::sync::Arc::new(server::handlers::domain_biometric::BiometricAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.temporal.list",
        std::sync::Arc::new(server::handlers::domain_temporal::TemporalAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.geospatial.list",
        std::sync::Arc::new(server::handlers::domain_geospatial::GeospatialAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.network.list",
        std::sync::Arc::new(server::handlers::domain_network::NetworkAtomsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.audit",
        std::sync::Arc::new(server::handlers::domain_audit::DomainAuditHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.domain.config.list",
        std::sync::Arc::new(server::handlers::domain_audit::DomainConfigListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.health.metrics",
        std::sync::Arc::new(server::handlers::domain_audit::HealthMetricsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B16: Context Plane (SBOS-049) ───────────────
    dispatcher.register("bauth.ctx.create",
        std::sync::Arc::new(server::handlers::context_plane::CtxCreateHandler));
    dispatcher.register("bauth.ctx.validate",
        std::sync::Arc::new(server::handlers::context_plane::CtxValidateEnhancedHandler));
    dispatcher.register("bauth.ctx.promote",
        std::sync::Arc::new(server::handlers::context_plane::CtxPromoteHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.ctx.invalidate",
        std::sync::Arc::new(server::handlers::context_plane::CtxInvalidateHandler));
    dispatcher.register("bauth.ctx.propagate",
        std::sync::Arc::new(server::handlers::context_plane::CtxPropagateHandler));
    // ── B-BAUTH-004: get_session ────────────────────────
    dispatcher.register("bauth.ctx.get_session",
        std::sync::Arc::new(server::handlers::context_plane::CtxGetSessionHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B33: Productos Comerciales D12 ───────────────
    dispatcher.register("bauth.product.compliance",
        std::sync::Arc::new(server::handlers::commercial::ComplianceAuthorizeHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.product.iam",
        std::sync::Arc::new(server::handlers::commercial::IamServiceStatusHandler));
    dispatcher.register("bauth.product.trust",
        std::sync::Arc::new(server::handlers::commercial::TrustVerifyHandler));
    dispatcher.register("bauth.product.pricing",
        std::sync::Arc::new(server::handlers::commercial::PricingPlansHandler));
    // ── B34: IdP Externo (IdP-as-a-Service) ───────────
    dispatcher.register("bauth.idp.discovery",
        std::sync::Arc::new(server::handlers::idp_external::OidcDiscoveryHandler));
    dispatcher.register("bauth.idp.isolation",
        std::sync::Arc::new(server::handlers::idp_external::TenantIsolationHandler));
    dispatcher.register("bauth.idp.federation",
        std::sync::Arc::new(server::handlers::idp_external::FederationStatusHandler));
    dispatcher.register("bauth.idp.portal",
        std::sync::Arc::new(server::handlers::idp_external::TenantPortalHandler));
    dispatcher.register("bauth.idp.billing",
        std::sync::Arc::new(server::handlers::idp_external::IdpBillingHandler));
    dispatcher.register("bauth.idp.sla",
        std::sync::Arc::new(server::handlers::idp_external::SlaStatusHandler));
    dispatcher.register("bauth.idp.saml",
        std::sync::Arc::new(server::handlers::idp_external::SamlStatusHandler));
    dispatcher.register("bauth.idp.scim",
        std::sync::Arc::new(server::handlers::idp_external::ScimStatusHandler));
    dispatcher.register("bauth.idp.branding",
        std::sync::Arc::new(server::handlers::idp_external::BrandingHandler));
    dispatcher.register("bauth.idp.admin",
        std::sync::Arc::new(server::handlers::idp_external::AdminApiHandler));
    dispatcher.register("bauth.idp.compliance",
        std::sync::Arc::new(server::handlers::idp_external::ComplianceReportsHandler));
    dispatcher.register("bauth.idp.residency",
        std::sync::Arc::new(server::handlers::idp_external::DataResidencyHandler));
    // ── Tenant + Sign ───────────────────────────────
    dispatcher.register("bauth.tenant.list",
        std::sync::Arc::new(server::handlers::tenant_list::TenantListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.tenant.create",
        std::sync::Arc::new(server::handlers::org_crud::TenantCreateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.tenant.get",
        std::sync::Arc::new(server::handlers::org_crud::TenantGetHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    // ── Domain CRUD ──────────────────────────────────────
    dispatcher.register("bauth.tenant.domain.list",
        std::sync::Arc::new(server::handlers::domain_crud::DomainListHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.tenant.domain.create",
        std::sync::Arc::new(server::handlers::domain_crud::DomainCreateHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.tenant.domain.delete",
        std::sync::Arc::new(server::handlers::domain_crud::DomainDeleteHandler { pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()) }));
    dispatcher.register("bauth.sign.internal",
        std::sync::Arc::new(server::handlers::sign_internal::SignInternalHandler {
            signer: jwt_signer.clone(),
        }));
    // ── B45.D01: Evaluador de 12 dominios ──────────────
    // DomainRegistry se construye lazy: si hay BD, los handlers consultan políticas
    // y configs por dominio en tiempo de evaluación, sin precarga en arranque.
    dispatcher.register("bauth.context.evaluate",
        std::sync::Arc::new(server::handlers::context_evaluate::ContextEvaluateHandler {
            registry: {
                let mut r = bitmask::registry::DomainRegistry::new();
                r.register(Box::new(domain::logical::LogicalEvaluator));
                r.register(Box::new(domain::physical::PhysicalEvaluator));
                r.register(Box::new(domain::financial::FinancialEvaluator::new(2)));
                r.register(Box::new(domain::temporal::TemporalEvaluator::new()));
                r.register(Box::new(domain::biometric::BiometricEvaluator::new()));
                r.register(Box::new(domain::geospatial::GeospatialEvaluator::new()));
                r.register(Box::new(domain::network::NetworkEvaluator::new()));
                r.register(Box::new(domain::context::ContextEvaluator));
                r.register(Box::new(domain::credential::CredentialEvaluator));
                r.register(Box::new(domain::delegation::DelegationEvaluator::new()));
                r.register(Box::new(domain::audit_domain::AuditDomainEvaluator::new()));
                r.register(Box::new(domain::blockchain::BlockchainEvaluator::new()));
                std::sync::Arc::new(r)
            },
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
            notifier: Some(hierarchical_notifier.clone()),
        }));
    // ── B9.T24: PolicyEngine sobre ath_policy_dN (D1-D12) ───────
    dispatcher.register("bauth.policy.domain.evaluate",
        std::sync::Arc::new(server::handlers::policy_domain::PolicyDomainEvalHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.domain.list",
        std::sync::Arc::new(server::handlers::policy_domain::PolicyDomainListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.library.search",
        std::sync::Arc::new(server::handlers::policy_domain::PolicyLibrarySearchHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T25: PolicyAdministrator CRUD ─────────────────────
    dispatcher.register("bauth.policy.create",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyCreateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.update",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyUpdateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.delete",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyDeleteHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.policy.validate",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyValidateHandler));
    dispatcher.register("bauth.policy.list",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T26: PolicyConflictDetector ────────────────────────
    dispatcher.register("bauth.policy.check_conflicts",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyCheckConflictsHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T27: PolicySimulator ────────────────────────────
    dispatcher.register("bauth.policy.simulate",
        std::sync::Arc::new(server::handlers::policy_simulate::PolicySimulateHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T28: PolicyAuditTrail ───────────────────────────
    dispatcher.register("bauth.policy.audit",
        std::sync::Arc::new(server::handlers::policy_admin::PolicyAuditHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T29: PolicyDistributionMonitor ──────────────────
    dispatcher.register("bauth.policy.distribution.status",
        std::sync::Arc::new(server::handlers::policy_distribution::PolicyDistributionHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B9.T31: FrameworkHotReload ─────────────────────────
    dispatcher.register("bauth.framework.reload",
        std::sync::Arc::new(server::handlers::framework_reload::FrameworkReloadHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── Keycloak ELIMINADO (ADR-010) — bAuth es el IdP nativo (OIDC Provider abajo).
    //    Los métodos bauth.keycloak.* y KeycloakEngine se purgaron: bAuth autentica,
    //    firma y enforcea nativamente. Ver MANUAL-APLICACIONES §3.2.
    // ── Fase 2: OIDC Provider Nativo (H-005 FIX) ─────────
    let oidc_issuer = notify_cfg.oidc_issuer.clone();
    dispatcher.register("bauth.oidc.discovery",
        std::sync::Arc::new(server::handlers::oidc_provider::OidcDiscoveryHandler {
            issuer: oidc_issuer.clone(),
            base_url: oidc_issuer.clone(),
        }));
    dispatcher.register("bauth.oidc.token",
        std::sync::Arc::new(server::handlers::oidc_provider::OidcTokenHandler {
            signer: jwt_signer.clone(),
            issuer: oidc_issuer.clone(),
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.oidc.introspect",
        std::sync::Arc::new(server::handlers::oidc_provider::OidcIntrospectHandler {
            signer: jwt_signer.clone(),
        }));
    dispatcher.register("bauth.oidc.userinfo",
        std::sync::Arc::new(server::handlers::oidc_provider::OidcUserinfoHandler {
            signer: jwt_signer.clone(),
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    // ── B29: Blockchain Panel ────────────────────────────────
    dispatcher.register("bauth.blockchain.batch.list",
        std::sync::Arc::new(server::handlers::blockchain_panel::AnchorBatchListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.blockchain.batch.detail",
        std::sync::Arc::new(server::handlers::blockchain_panel::AnchorBatchDetailHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.blockchain.verify",
        std::sync::Arc::new(server::handlers::blockchain_panel::AnchorVerifyHandler));
    dispatcher.register("bauth.blockchain.recent",
        std::sync::Arc::new(server::handlers::blockchain_panel::AnchorRecentHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));
    dispatcher.register("bauth.blockchain.status",
        std::sync::Arc::new(server::handlers::blockchain_panel::BlockchainStatusHandler));
    dispatcher.register("bauth.blockchain.settlement.list",
        std::sync::Arc::new(server::handlers::blockchain_panel::SettlementListHandler {
            pg_pool: db_ctx.as_ref().map(|c| c.pg.clone()),
        }));

    // ── B47.D01-D10 + B48: Paneles Dashboard + nuevos handlers ──
    if let Some(ref db) = db_ctx {
        let dash = server::handlers::dashboard_panels::all_handlers(db.pg.clone());
        for (method_name, handler) in dash {
            dispatcher.register(&method_name, handler);
        }
        // B48.T05: token.refresh
        dispatcher.register("bauth.token.refresh",
            std::sync::Arc::new(server::handlers::token_refresh::TokenRefreshHandler {
                signer: jwt_signer.clone(), jwt_cfg: jwt_cfg.clone(), pg: Some(db.pg.clone()),
            }));
        // B48.T20-T25: SCIM v2
        for (method_name, handler) in server::handlers::scim_server::all_scim_handlers(db.pg.clone()) {
            dispatcher.register(&method_name, handler);
        }
        // B48.T30-T34: Self-service
        for (method_name, handler) in server::handlers::self_service::all_self_handlers(db.pg.clone()) {
            dispatcher.register(&method_name, handler);
        }
        // B48.T63-T66: Dispositivos
        for (method_name, handler) in server::handlers::device_identity::all_device_handlers(db.pg.clone()) {
            dispatcher.register(&method_name, handler);
        }
        // B10.T76-T89: Ciclo de vida de roles (Q9 — 7 métodos IGA antes huérfanos:
        // lifecycle, impact, bulk_assign, temporal_assign, search, rollback, batch)
        for (method_name, handler) in server::handlers::role_lifecycle::all_role_lifecycle_handlers(db.pg.clone()) {
            dispatcher.register(&method_name, handler);
        }
    }

    // B48.T40-T42: Protocolos (necesitan signer)
    for (method_name, handler) in server::handlers::token_protocols::all_protocol_handlers(jwt_signer.clone(), jwt_cfg.clone()) {
        dispatcher.register(&method_name, handler);
    }

    // B48.T50-T52: Kong + OAuth2-Proxy
    for (method_name, handler) in server::handlers::kong_oauth::all_kong_handlers(db_ctx.as_ref().map(|c| c.pg.clone())) {
        dispatcher.register(&method_name, handler);
    }

    // ── Debug: introspección de métodos disponibles ────────────
    {
        let method_list = dispatcher.list_methods();
        struct DebugMethodsHandler { methods: Vec<String> }
        #[async_trait::async_trait]
        impl server::jsonrpc::JsonRpcHandler for DebugMethodsHandler {
            async fn handle(&self, _params: serde_json::Value) -> Result<serde_json::Value, server::jsonrpc::JsonRpcError> {
                Ok(serde_json::json!({ "methods": self.methods, "count": self.methods.len() }))
            }
        }
        dispatcher.register("bauth.debug.methods",
            std::sync::Arc::new(DebugMethodsHandler { methods: method_list }));
    }

    let methods = dispatcher.list_methods();
    info!(metodos = ?methods, "JSON-RPC 2.0 dispatcher registrado");

    let server_ctx = server::ServerContext {
        dispatcher: std::sync::Arc::new(dispatcher),
        max_connections: cfg.server.max_connections,
        max_request_bytes: cfg.server.max_request_bytes,
    };

    // ── Fase 5: Servidor Unix socket (B0.T07) ─────────────
    let server_drain = drain.clone();
    let server_cfg = cfg.server.clone();
    let _server_handle = tokio::spawn(async move {
        if let Err(e) = server::unix_socket::listen(server_cfg, server_drain, server_ctx).await {
            error!(error = %e, "servidor falló");
        }
    });

    // B45.D03: reconcile loop extendido (drift políticas, revalidación contextos,
    // invalidación sesiones expiradas, eventos CAEP)
    let _reconcile_handle = if let Some(ref db) = db_ctx {
        let reconcile_ctx = db.clone();
        let caep_reconcile = caep_tx.clone();
        tokio::spawn(async move {
            sync::reconcile_loop(reconcile_ctx, caep_reconcile).await;
        })
    } else {
        warn!("reconcile loop no iniciado — base de datos no disponible");
        tokio::spawn(std::future::pending())
    };

    // B47.C01-C03: Calendar alarm poller (60s) → bnotify → Mattermost
    let _alarm_handle = if let Some(ref db) = db_ctx {
        let alarm_poller = domain::calendar_alarm::AlarmPoller::new(
            db.pg.clone(),
            notify_client.clone(),
        );
        tokio::spawn(async move {
            alarm_poller.run().await;
        })
    } else {
        tokio::spawn(std::future::pending())
    };

    // ── Fase 5: systemd notify (B0.T06) ───────────────────
    sd_notify_ready();

    info!(socket = SOCKET_PATH, "bauth operativo");

    // ── Fase 6: Esperar señales (B0.T05) ──────────────────
    signal::wait_for_shutdown(Some(|| {
        if let Err(e) = config::reload() {
            error!(error = %e, "fallo al recargar configuración en SIGHUP");
        }
    })).await;

    // Drenaje graceful con timeout
    info!(timeout_secs = signal::DRAIN_TIMEOUT_SECS, "iniciando drenaje");
    let result = drain.drain(signal::DRAIN_TIMEOUT_SECS).await;

    match result {
        signal::DrainResult::Clean => info!("drenaje completo — bauth detenido limpiamente"),
        signal::DrainResult::Timeout { remaining } =>
            warn!(remaining, "drenaje forzado — quedaron conexiones activas"),
    }

    process::exit(0);
}

/// Enviar READY=1 a systemd. Sin systemd, no-op.
fn sd_notify_ready() {
    let sock = match std::env::var("NOTIFY_SOCKET") {
        Ok(p) if !p.is_empty() => p,
        _ => return,
    };
    if let Err(e) = std::os::unix::net::UnixDatagram::unbound()
        .and_then(|s| s.send_to(b"READY=1", &sock)) {
        warn!(error = %e, "no se pudo notificar READY=1 a systemd");
    }
}
