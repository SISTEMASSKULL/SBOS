//! Protocolo newline-delimited con bhnexus Puerta 1.
//! Conexión TCP persistente: handshake → loop rpc_call/rpc_response.
//! Mismo protocolo que el daemon banexus pero en una tarea tokio del SDK.

use anyhow::Result;
use serde_json::{json, Value};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::{mpsc::UnboundedReceiver, oneshot};

use crate::{Peticion, SdkConfig};

/// Tarea tokio principal: conecta a bhnexus, hace handshake y procesa peticiones.
/// Señala [ready_tx] cuando el handshake termina con éxito o falla.
pub async fn tarea_bhnexus(
    mut rx: UnboundedReceiver<Peticion>,
    config: SdkConfig,
    ready_tx: oneshot::Sender<Result<(), String>>,
) {
    match conectar_y_procesar(&mut rx, &config, ready_tx).await {
        Ok(_)  => tracing::info!("tarea bhnexus terminó limpiamente"),
        Err(e) => tracing::error!(error = %e, "tarea bhnexus terminó con error"),
    }
}

async fn conectar_y_procesar(
    rx: &mut UnboundedReceiver<Peticion>,
    config: &SdkConfig,
    ready_tx: oneshot::Sender<Result<(), String>>,
) -> Result<()> {
    let mut stream = TcpStream::connect(&config.bhnexus_addr).await
        .map_err(|e| anyhow::anyhow!("No se pudo conectar a bhnexus {}: {}", config.bhnexus_addr, e))?;

    // Handshake identificado como proxy SDK
    let hs = json!({
        "type":     "handshake",
        "node_id":  format!("{}-sdk", config.node_id),
        "modo":     "proxy",
        "dev_mode": config.dev_mode,
    }).to_string();
    escribir_linea(&mut stream, &hs).await?;

    let ack = leer_linea(&mut stream).await?;
    if ack.is_empty() {
        let _ = ready_tx.send(Err("bhnexus cerró la conexión sin ACK".into()));
        return Err(anyhow::anyhow!("handshake fallido — bhnexus cerró sin responder"));
    }
    tracing::info!(ack = %ack, "SDK handshake OK con bhnexus");

    // Handshake listo — señalar al llamador de banexus_init
    let _ = ready_tx.send(Ok(()));

    // Bucle de peticiones — una a la vez (serializado)
    while let Some(peticion) = rx.recv().await {
        let rpc_call = json!({
            "type":    "rpc_call",
            "payload": peticion.payload,
            "seq":     peticion.seq,
        }).to_string();

        if let Err(e) = escribir_linea(&mut stream, &rpc_call).await {
            let _ = peticion.resp_tx.send(Err(e.to_string()));
            break; // reconexión no implementada en Etapa 1
        }

        let resp_str = match leer_linea(&mut stream).await {
            Ok(s)  => s,
            Err(e) => {
                let _ = peticion.resp_tx.send(Err(e.to_string()));
                break;
            }
        };

        let resp: Value = serde_json::from_str(&resp_str)
            .unwrap_or_else(|_| json!({"error": "JSON inválido de bhnexus"}));

        let payload = resp.get("payload").cloned().unwrap_or_else(|| {
            let err = resp.get("error").and_then(Value::as_str).unwrap_or("proxy error");
            json!({"jsonrpc":"2.0","error":{"code":-32000,"message":err},"id":null})
        });

        let _ = peticion.resp_tx.send(Ok(payload));
    }

    Ok(())
}

// ─── Utilidades de protocolo ─────────────────────────────────

async fn escribir_linea(stream: &mut TcpStream, texto: &str) -> Result<()> {
    stream.write_all(texto.as_bytes()).await?;
    stream.write_u8(b'\n').await?;
    Ok(())
}

/// Lee hasta '\n' byte a byte — robusto ante fragmentación TCP.
async fn leer_linea(stream: &mut TcpStream) -> Result<String> {
    let mut buf = Vec::with_capacity(4096);
    let mut byte = [0u8; 1];
    loop {
        let n = stream.read(&mut byte).await?;
        if n == 0 { break; }
        if byte[0] == b'\n' { break; }
        buf.push(byte[0]);
        if buf.len() > 512 * 1024 {
            return Err(anyhow::anyhow!("respuesta de bhnexus supera 512 KB"));
        }
    }
    String::from_utf8(buf).map_err(|e| anyhow::anyhow!("UTF-8 inválido: {e}"))
}
