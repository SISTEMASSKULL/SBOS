//! banexus — Nexus Agent · SBOS
//! Entry point: carga config, arranca local_api (Flutter) + transport (bhnexus heartbeat).
//! SSOT: BnexusAgent/context/Documentacion/ · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.1-§24.2

mod config;
mod local_api;
mod transport;

use config::BanexusConfig;
use std::sync::Arc;
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    inicializar_tracing();

    let cfg = Arc::new(BanexusConfig::cargar("banexus.toml")?);
    info!(modo = %cfg.agente.modo, version = "0.1.0", "banexus arrancando");

    // Local API para Flutter y transporte a bhnexus corren en paralelo.
    // Logeamos si alguno termina pero no abortamos el otro.
    let (r_api, r_transport) = tokio::join!(
        local_api::escuchar(cfg.clone()),
        transport::conectar_y_mantener((*cfg).clone()),
    );
    if let Err(e) = r_api { tracing::error!(error = %e, "local_api terminó con error"); }
    if let Err(e) = r_transport { tracing::error!(error = %e, "transport terminó con error"); }

    Ok(())
}

fn inicializar_tracing() {
    let filtro = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info"));
    fmt::Subscriber::builder()
        .with_env_filter(filtro)
        .with_target(false)
        .json()
        .init();
}
