/// server/handlers/health.rs — Handler de verificación de salud del daemon.
/// Propósito: responde a bi18n.health.check / HealthService.Check.
///   - Verifica que el loader tenga países cargados.
///   - Retorna versión del daemon y estado en español.
/// Dependencias: crate::server::context, crate::error
use crate::{error::Resultado, server::context::ServerContext};

/// Respuesta del health check.
#[derive(Debug)]
pub struct HealthResult {
    /// "ok" | "degradado" | "error"
    pub status: &'static str,
    pub version: &'static str,
    pub paises_cargados: u32,
    pub mensaje: String,
}

/// Ejecuta el health check contra el contexto del servidor.
pub async fn verificar(ctx: &ServerContext) -> Resultado<HealthResult> {
    let paises = ctx.loader.total().await;
    let (status, mensaje) = if paises > 0 {
        ("ok", format!("bi18n activo con {} países cargados", paises))
    } else {
        ("degradado", "bi18n activo pero sin reglas de país cargadas".to_string())
    };

    Ok(HealthResult {
        status,
        version: env!("CARGO_PKG_VERSION"),
        paises_cargados: paises as u32,
        mensaje,
    })
}
