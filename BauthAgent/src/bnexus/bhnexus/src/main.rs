//! bhnexus — Nexus Host · SBOS
//! Entry point: carga config, inicializa tracing, levanta servidor.
//! Interface Dual (ADR-020): /run/bos/bhnexus.sock + TCP 9444 (Puerta 1).
//! DOC-SBOS-001 N3 · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §23

mod auth;
mod config;
mod node;
mod server;
mod virtual_endpoints;

use config::BhnexusConfig;
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    inicializar_tracing();

    let cfg = BhnexusConfig::cargar("bhnexus.toml")?;
    info!(version = "0.1.0", modo = "etapa-1", "bhnexus arrancando");

    // Guardia: dev_mode prohibido en producción
    cfg.validar_entorno()?;

    server::iniciar(cfg).await
}

/// Inicializa tracing con filtro desde RUST_LOG o por defecto INFO.
fn inicializar_tracing() {
    let filtro = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info"));
    fmt::Subscriber::builder()
        .with_env_filter(filtro)
        .with_target(false)
        .json()
        .init();
}
