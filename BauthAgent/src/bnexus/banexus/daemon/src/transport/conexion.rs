//! Gestión de la conexión TCP hacia bhnexus Puerta 1.
//! Reconexión con backoff exponencial (1s → 60s máximo).
//! SSOT: BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

use crate::config::BanexusConfig;
use serde_json::json;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::sleep;
use tracing::{error, info, warn};

/// Bucle principal: conecta, envía handshake, luego delega al loop de heartbeat.
/// Reintenta con backoff exponencial ante cualquier fallo.
pub async fn ejecutar_con_reconexion(cfg: BanexusConfig) -> anyhow::Result<()> {
    let mut delay = Duration::from_secs(1);
    let delay_max = Duration::from_secs(60);

    loop {
        info!(addr = %cfg.agente.bhnexus_addr, "Conectando a bhnexus Puerta 1");
        match TcpStream::connect(&cfg.agente.bhnexus_addr).await {
            Ok(stream) => {
                delay = Duration::from_secs(1); // reset backoff tras conexión exitosa
                if let Err(e) = sesion(stream, &cfg).await {
                    warn!(error = %e, "Sesión terminada — reintentando");
                }
            }
            Err(e) => {
                error!(error = %e, delay_s = delay.as_secs(), "Conexión fallida");
            }
        }

        sleep(delay).await;
        delay = (delay * 2).min(delay_max);
    }
}

/// Gestiona una sesión activa: handshake + loop heartbeat.
async fn sesion(
    mut stream: TcpStream,
    cfg: &BanexusConfig,
) -> anyhow::Result<()> {
    // Handshake inicial
    let handshake = json!({
        "type": "handshake",
        "node_id": cfg.agente.node_id,
        "modo": cfg.agente.modo.to_string(),
        "dev_mode": cfg.dev.dev_mode,
    })
    .to_string();

    stream.write_all(handshake.as_bytes()).await?;

    let mut buf = vec![0u8; 1024];
    let n = stream.read(&mut buf).await?;
    let respuesta = std::str::from_utf8(&buf[..n]).unwrap_or("?");
    info!(respuesta = %respuesta, "Handshake recibido");

    // Loop de heartbeat — delega a heartbeat.rs
    super::heartbeat::ejecutar(&mut stream, &cfg.agente.node_id).await
}
