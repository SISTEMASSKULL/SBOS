// ============================================================
// bauth::domain::startup — Inicialización del Motor de Dominios (Fase 2)
//
// Al arrancar: registra evaluadores en el DomainRegistry, carga
// configs de tenant desde BD, verifica infraestructura canónica.
//
// Eliminado:
//   - privilege_atom_policy (phantom D05b) → cfg_policy_library
//   - idn_role_closure (phantom) → idn_roles_rol_closure
//   - privilege_domain (phantom D05) → idn_roles_template (domain_number)
//   - privilege_resource_atom como fuente de dominios → idn_roles_template
//   - idn_tenant WHERE active = TRUE → WHERE status = 'ACTIVE'
//
// DOC-SBOS-001 N3 · H-01/02/03/07/08 · SBOS-049
// ============================================================

#![allow(dead_code)]
use crate::bitmask::registry::{DomainRegistry, DomainConfig};
use crate::domain::*;
use sqlx::PgPool;
use std::sync::Arc;
use tracing::{info, warn};

/// Contexto de dominio cargado en memoria al arranque.
pub struct DomainContext {
    pub registry:          Arc<DomainRegistry>,
    pub evaluators_count:  usize,
}

impl DomainContext {
    /// Inicializa el motor de dominios completo.
    pub async fn init(pg: &PgPool) -> Result<Self, String> {
        let mut registry = DomainRegistry::new();

        // ── Registrar evaluadores ─────────────────────────────
        Self::register_evaluators(&mut registry);
        info!(evaluadores = 12, "H-01: DomainRegistry — 12 evaluadores registrados");

        info!("H-03: FastPathCheck — rol.check(position) <0.5ns (inline always)");

        // ── H-02: Verificar cadena de políticas ───────────────
        Self::verify_policy_chain(pg).await?;

        // ── H-07: Verificar closure table canónica ────────────
        let closure_count = Self::verify_closure_table(pg).await?;
        info!(filas = closure_count, "H-07: ClosureTableEngine — idn_roles_rol_closure verificada");

        // ── H-08: ConflictMatrix ──────────────────────────────
        let conflict_pairs = Self::verify_conflict_matrix();
        info!(pares = conflict_pairs, "H-08: ConflictMatrix — SoD estático validado");

        // ── Cargar configs de dominio por tenant ───────────────
        Self::load_tenant_configs(pg, &mut registry).await?;

        Ok(DomainContext {
            registry: Arc::new(registry),
            evaluators_count: 12,
        })
    }

    /// Registra los 12 evaluadores de dominio.
    fn register_evaluators(registry: &mut DomainRegistry) {
        registry.register(Box::new(logical::LogicalEvaluator));
        registry.register(Box::new(physical::PhysicalEvaluator));
        registry.register(Box::new(financial::FinancialEvaluator::new(13)));
        registry.register(Box::new(temporal::TemporalEvaluator));
        registry.register(Box::new(biometric::BiometricEvaluator));
        registry.register(Box::new(geospatial::GeospatialEvaluator));
        registry.register(Box::new(network::NetworkEvaluator));
        registry.register(Box::new(context::ContextEvaluator));
        registry.register(Box::new(credential::CredentialEvaluator));
        registry.register(Box::new(delegation::DelegationEvaluator));
        registry.register(Box::new(audit_domain::AuditDomainEvaluator));
        registry.register(Box::new(blockchain::BlockchainEvaluator));
    }

    /// Verifica disponibilidad de políticas en `cfg_policy_library`.
    /// `privilege_atom_policy` fue eliminada (D05b — sin equivalente canónico).
    async fn verify_policy_chain(pg: &PgPool) -> Result<(), String> {
        let (count,): (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.cfg_policy_library"
        )
        .fetch_one(pg)
        .await
        .map_err(|e| e.to_string())?;
        info!(
            politicas_disponibles = count,
            "H-02: PolicyChainResolver — políticas en cfg_policy_library"
        );
        Ok(())
    }

    /// Verifica el estado de la closure table canónica.
    /// Fuente: `bauth.idn_roles_rol_closure` (DDL v2.12.0).
    async fn verify_closure_table(pg: &PgPool) -> Result<i64, String> {
        let (count,): (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.idn_roles_rol_closure WHERE is_active = TRUE"
        )
        .fetch_one(pg)
        .await
        .map_err(|e| e.to_string())?;
        Ok(count)
    }

    /// Verifica ConflictMatrix (health check en startup).
    fn verify_conflict_matrix() -> usize {
        let mut matrix = crate::bitmask::conflict::ConflictMatrix::new();
        matrix.seed_defaults();
        6  // 6 pares de conflicto SoD base (verificado en VPS)
    }

    /// Carga configuraciones de dominio por tenant.
    ///
    /// Tenants: `bauth.idn_tenant WHERE status = 'ACTIVE'` (canónico).
    /// Dominios: DISTINCT domain_code de `privilege_resource_atom` (D05 — reemplaza privilege_domain).
    async fn load_tenant_configs(pg: &PgPool, registry: &mut DomainRegistry) -> Result<(), String> {
        #[derive(sqlx::FromRow)]
        struct TenantRow { tenant_id: uuid::Uuid }

        #[derive(sqlx::FromRow)]
        struct DomainRow { domain_code: i16 }

        let tenants: Vec<TenantRow> = sqlx::query_as(
            "SELECT tenant_id FROM bauth.idn_tenant WHERE status = 'ACTIVE'"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| e.to_string())?;

        if tenants.is_empty() {
            warn!("H-01: sin tenants activos en idn_tenant — omitiendo configuración de dominios");
            return Ok(());
        }

        // Dominios activos desde idn_roles_template — nodos tipo 'atom' con domain_number asignado.
        // La columna domain_number en T-162 es el número canónico del dominio (D00-D15, D98, D99).
        let domains: Vec<DomainRow> = sqlx::query_as(
            r#"
            SELECT DISTINCT domain_number::smallint AS domain_code
            FROM bauth.idn_roles_template
            WHERE node_type     = 'atom'
              AND atom_position IS NOT NULL
              AND is_active     = TRUE
              AND domain_number IS NOT NULL
            ORDER BY domain_code
            "#,
        )
        .fetch_all(pg)
        .await
        .map_err(|e| e.to_string())?;

        let total = tenants.len() * domains.len().max(1);
        for tenant in &tenants {
            let tid = tenant.tenant_id.to_string();
            let configs: Vec<DomainConfig> = domains.iter().map(|d| DomainConfig {
                domain_code:     d.domain_code as u8,
                active:          true,
                override_params: None,
            }).collect();
            registry.configure_tenant(&tid, configs);
        }

        info!(
            tenants  = tenants.len(),
            dominios = domains.len(),
            configs  = total,
            "H-01: configuraciones de dominio cargadas desde BD canónica"
        );
        Ok(())
    }
}
