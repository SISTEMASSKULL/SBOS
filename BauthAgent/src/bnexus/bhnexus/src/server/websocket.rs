//! Manejo de conexiones WebSocket sobre el socket Unix (Interface Dual).
//! Despacha a JSON-RPC según el formato del mensaje recibido.
//! SSOT: BnexusAgent/context/Documentacion/2.03_MANUAL-INTERFACE-DUAL-NEXUS.md

use crate::node::RegistroNodos;
use tokio::net::UnixStream;
use tokio_tungstenite::tungstenite::Message;
use tokio_tungstenite::accept_async;
use futures_util::{SinkExt, StreamExt};
use tracing::debug;

/// Eleva el stream Unix a WebSocket y procesa mensajes JSON-RPC.
pub async fn manejar_conexion(
    stream: UnixStream,
    registro: RegistroNodos,
) -> anyhow::Result<()> {
    let ws = accept_async(stream).await?;
    let (mut tx, mut rx) = ws.split();

    while let Some(msg) = rx.next().await {
        match msg? {
            Message::Text(texto) => {
                debug!(raw = %texto, "Mensaje recibido Interface Dual");
                let respuesta = super::jsonrpc::despachar(&texto, &registro).await;
                tx.send(Message::Text(respuesta)).await?;
            }
            Message::Ping(datos) => {
                tx.send(Message::Pong(datos)).await?;
            }
            Message::Close(_) => break,
            _ => {}
        }
    }
    Ok(())
}
