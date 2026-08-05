//! banexus — Nexus Agent · SBOS
//! Entry point: carga config, determina mode (daemon|gateway), conecta a bhnexus.
//! SSOT: BnexusAgent/context/Documentacion/ · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.1-§24.2

mod config;
mod transport;

use config::BanexusConfig;
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    inicializar_tracing();

    let cfg = BanexusConfig::cargar("banexus.toml")?;
    info!(modo = %cfg.agente.modo, version = "0.1.0", "banexus arrancando");

    transport::conectar_y_mantener(cfg).await
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
