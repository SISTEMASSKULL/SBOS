//! API local TCP para Flutter desktop — escucha en 127.0.0.1:9446.
//! Cada sesión Flutter abre una conexión proxy independiente a bhnexus Puerta 1.
//! Protocolo: JSON newline-delimited (cada mensaje termina en '\n').
//!
//! Flujo por sesión:
//!   Flutter → [TCP 9446] → banexus local_api
//!   banexus → [TCP 9444] → bhnexus Puerta 1 (handshake + rpc_call)
//!   bhnexus → [Unix socket] → bAuth (reenvío JSON-RPC)
//!   respuesta ← ← ← retorna por la misma cadena
//!
//! SSOT: BnexusAgent/context/Documentacion/ · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.3

use crate::config::BanexusConfig;
use anyhow::Result;
use serde_json::{json, Value};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tracing::{error, info, warn};

/// Levanta el listener TCP de la local API y acepta sesiones de Flutter.
pub async fn escuchar(cfg: Arc<BanexusConfig>) -> Result<()> {
    let addr = format!("{}:{}", cfg.local_api.addr, cfg.local_api.puerto);
    let listener = TcpListener::bind(&addr).await?;
    info!(addr = %addr, "Local API escuchando — Flutter puede conectar aquí");

    loop {
        match listener.accept().await {
            Ok((stream, peer)) => {
                let cfg = cfg.clone();
                info!(peer = %peer, "Flutter conectado a Local API");
                tokio::spawn(async move {
                    if let Err(e) = manejar_sesion_flutter(stream, &cfg).await {
                        warn!(error = %e, "Sesión Flutter finalizada con error");
                    }
                });
            }
            Err(e) => error!(error = %e, "Error aceptando conexión en Local API"),
        }
    }
}

/// Gestiona una sesión Flutter completa.
/// Abre una conexión dedicada a bhnexus Puerta 1 y reenvía cada llamada RPC.
async fn manejar_sesion_flutter(flutter: TcpStream, cfg: &BanexusConfig) -> Result<()> {
    // Conectar a bhnexus Puerta 1
    let mut bhnexus = TcpStream::connect(&cfg.agente.bhnexus_addr).await
        .map_err(|e| anyhow::anyhow!("No se pudo conectar a bhnexus {}: {}", cfg.agente.bhnexus_addr, e))?;

    // Handshake identificado como proxy (modo distinto al heartbeat daemon)
    let hs = json!({
        "type": "handshake",
        "node_id": format!("{}-desktop", cfg.agente.node_id),
        "modo": "proxy",
        "dev_mode": cfg.dev.dev_mode,
    }).to_string();
    escribir_linea(&mut bhnexus, &hs).await?;

    // Leer ACK del handshake con la misma función line-based que usamos para respuestas.
    // Esto consume el '\n' correctamente y no deja bytes huérfanos en el buffer.
    let ack = leer_linea_bhnexus(&mut bhnexus).await?;
    if ack.is_empty() { return Err(anyhow::anyhow!("bhnexus cerró conexión tras handshake")); }
    info!(ack = %ack, "Proxy handshake OK con bhnexus");

    // Loop de reenvío: Flutter → rpc_call → bhnexus → rpc_response → Flutter
    let (flutter_read, mut flutter_write) = flutter.into_split();
    let mut lector = BufReader::new(flutter_read);
    let mut linea = String::new();
    let mut seq: u64 = 0;

    loop {
        linea.clear();
        let n = lector.read_line(&mut linea).await?;
        if n == 0 {
            info!("Flutter cerró la conexión");
            break;
        }

        let texto = linea.trim();
        if texto.is_empty() { continue; }

        // Parsear el JSON-RPC de Flutter (puede fallar si el cliente envía basura)
        let payload: Value = match serde_json::from_str(texto) {
            Ok(v) => v,
            Err(e) => {
                warn!(error = %e, "JSON inválido de Flutter — ignorando");
                let err = json!({"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"},"id":null});
                escribir_linea_split(&mut flutter_write, &err.to_string()).await?;
                continue;
            }
        };

        seq += 1;

        // Envolver como rpc_call para bhnexus
        let rpc_call = json!({
            "type": "rpc_call",
            "payload": payload,
            "seq": seq,
        }).to_string();
        escribir_linea(&mut bhnexus, &rpc_call).await?;

        // Leer rpc_response de bhnexus (newline-delimited)
        let resp_str = leer_linea_bhnexus(&mut bhnexus).await?;
        let resp: Value = serde_json::from_str(&resp_str)
            .unwrap_or_else(|_| json!({"error": "respuesta inválida de bhnexus"}));

        // Extraer payload y retornar a Flutter
        let flutter_resp = resp.get("payload")
            .cloned()
            .unwrap_or_else(|| {
                let msg = resp.get("error")
                    .and_then(Value::as_str)
                    .unwrap_or("proxy error");
                json!({"jsonrpc":"2.0","error":{"code":-32000,"message":msg},"id":null})
            });

        escribir_linea_split(&mut flutter_write, &flutter_resp.to_string()).await?;
    }

    Ok(())
}

/// Escribe `{texto}\n` al stream bhnexus.
async fn escribir_linea(stream: &mut TcpStream, texto: &str) -> Result<()> {
    stream.write_all(texto.as_bytes()).await?;
    stream.write_u8(b'\n').await?;
    Ok(())
}

/// Escribe `{texto}\n` al write half de Flutter.
async fn escribir_linea_split(
    writer: &mut tokio::net::tcp::OwnedWriteHalf,
    texto: &str,
) -> Result<()> {
    writer.write_all(texto.as_bytes()).await?;
    writer.write_u8(b'\n').await?;
    Ok(())
}

/// Lee una línea completa de bhnexus (newline-terminated).
/// Lee byte a byte hasta '\n' para robustez ante fragmentación TCP.
async fn leer_linea_bhnexus(stream: &mut TcpStream) -> Result<String> {
    let mut resultado = Vec::with_capacity(4096);
    let mut byte = [0u8; 1];
    loop {
        let n = tokio::io::AsyncReadExt::read(stream, &mut byte).await?;
        if n == 0 { break; }
        if byte[0] == b'\n' { break; }
        resultado.push(byte[0]);
        if resultado.len() > 512 * 1024 {
            return Err(anyhow::anyhow!("Respuesta de bhnexus supera 512 KB — abortando"));
        }
    }
    String::from_utf8(resultado).map_err(|e| anyhow::anyhow!("UTF-8 inválido: {e}"))
}
