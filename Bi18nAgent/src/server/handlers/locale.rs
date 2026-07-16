/// server/handlers/locale.rs — Handler de resolución de locale.
/// Propósito: resuelve la configuración regional por jerarquía (GAP-01).
///   - Jerarquía: user_id → branch_id → tenant_id → default.
///   - En MVP siempre retorna la config estática del TOML.
///   - Informa el nivel de resolución ("fuente") para diagnóstico.
/// Dependencias: crate::domain::regional_config, crate::server::context
use crate::{
    domain::regional_config::RegionalConfig,
    error::Resultado,
    server::context::ServerContext,
};

/// Resultado de resolución de locale.
#[derive(Debug)]
pub struct LocaleResult {
    pub config: RegionalConfig,
    /// Nivel desde el que se resolvió: "user" | "branch" | "tenant" | "default"
    pub fuente: &'static str,
}

/// Resuelve la configuración regional para un contexto de tenant/branch/user.
pub async fn resolver_locale(
    ctx: &ServerContext,
    tenant_id: &str,
    branch_id: &str,
    user_id: &str,
) -> Resultado<LocaleResult> {
    // En MVP siempre resuelve desde el resolver estático (bi18n.toml).
    // En producción bAuth enviará RegionalConfig en cada request.
    let config = ctx.resolver.resolver(
        tenant_id,
        if branch_id.is_empty() { None } else { Some(branch_id) },
        if user_id.is_empty() { None } else { Some(user_id) },
    ).await?;

    // La fuente siempre es "default" en MVP porque usamos ResolverEstatico.
    // Cuando bAuth implemente la jerarquía, esta lógica cambiará.
    Ok(LocaleResult { config, fuente: "default" })
}
