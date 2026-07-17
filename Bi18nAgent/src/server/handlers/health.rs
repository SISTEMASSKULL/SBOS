/// server/handlers/health.rs — Handler de verificación de salud del daemon.
/// Propósito: responde a bi18n.health.check / HealthService.Check.
///   - Verifica que el loader tenga países cargados.
///   - Mensajes de estado localizados vía FluentBundle (Bloque 4).
///   - Retorna versión del daemon y estado en español.
/// Dependencias: crate::server::context, crate::error
use crate::{error::Resultado, server::context::ServerContext};
use crate::domain::fluent_loader::FluentLoader;

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
/// El mensaje de países usa el plural Fluent "paises-cargados".
pub async fn verificar(ctx: &ServerContext) -> Resultado<HealthResult> {
    let paises = ctx.loader.total().await;
    let (status, mensaje) = if paises > 0 {
        let args = FluentLoader::args_n(paises as i64);
        let plural = ctx.fluent.traducir("paises-cargados", Some(&args));
        ("ok", format!("bi18n activo — {}", plural))
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
