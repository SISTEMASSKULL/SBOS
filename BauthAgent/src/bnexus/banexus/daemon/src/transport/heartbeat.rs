//! Heartbeat hacia bhnexus — ping cada 30 segundos.
//! Fallo en heartbeat = sesión inválida → reconexión en conexion.rs.
//! SSOT: BnexusAgent/context/Documentacion/5.01_MANUAL-AUTH-CACHE-BHNEXUS.md

use serde_json::json;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::{interval, timeout};
use tracing::{debug, warn};

const INTERVALO_PING: Duration = Duration::from_secs(30);
const TIMEOUT_PONG: Duration  = Duration::from_secs(10);

/// Envía pings periódicos y valida que bhnexus responda.
/// Retorna error si no llega pong en tiempo → provoca reconexión.
pub async fn ejecutar(stream: &mut TcpStream, node_id: &str) -> anyhow::Result<()> {
    let mut ticker = interval(INTERVALO_PING);
    let mut buf = vec![0u8; 512];

    loop {
        ticker.tick().await;

        let ping = json!({
            "type": "heartbeat",
            "node_id": node_id,
        })
        .to_string();

        stream.write_all(ping.as_bytes()).await?;
        debug!(node_id = %node_id, "Ping enviado");

        // Esperamos pong con timeout — si no llega, terminamos la sesión.
        match timeout(TIMEOUT_PONG, stream.read(&mut buf)).await {
            Ok(Ok(n)) if n > 0 => {
                debug!(raw = %std::str::from_utf8(&buf[..n]).unwrap_or("?"), "Pong recibido");
            }
            Ok(Ok(_)) => {
                warn!("bhnexus cerró la conexión");
                return Ok(());
            }
            Ok(Err(e)) => return Err(e.into()),
            Err(_) => {
                warn!(timeout_s = TIMEOUT_PONG.as_secs(), "Timeout esperando pong");
                return Err(anyhow::anyhow!("Timeout en heartbeat"));
            }
        }
    }
}
