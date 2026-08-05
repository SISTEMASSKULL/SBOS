//! Puerta 1 — listener TCP 9444 para banexus-daemon y banexus-gateway.
//! Protocolo: JSON newline-delimited (\n al final de cada mensaje).
//! Tipos de mensaje aceptados: handshake · heartbeat · rpc_call.
//! rpc_call → proxy a bAuth socket → rpc_response de vuelta al agente.
//! Etapa 1: TLS con dev CA autofirmada. Etapa 3: SPIFFE/SVID.
//! SSOT: BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

use crate::auth::DevCa;
use crate::node::RegistroNodos;
use crate::server::bauth_proxy;
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpListener;
use tracing::{error, info, warn};
use uuid::Uuid;

/// Escucha en TCP 9444 y procesa conexiones de banexus agents.
pub async fn escuchar(
    puerto: u16,
    _dev_ca: DevCa,
    registro: RegistroNodos,
    bauth_socket: String,
) -> anyhow::Result<()> {
    let addr = format!("0.0.0.0:{puerto}");
    let listener = TcpListener::bind(&addr).await?;
    info!(addr = %addr, "Puerta 1 escuchando");

    loop {
        match listener.accept().await {
            Ok((stream, peer_addr)) => {
                let reg = registro.clone();
                let addr_str = peer_addr.to_string();
                let socket = bauth_socket.clone();
                tokio::spawn(async move {
                    if let Err(e) = manejar_agente(stream, addr_str, reg, socket).await {
                        error!(error = %e, "Error en agente Puerta 1");
                    }
                });
            }
            Err(e) => warn!(error = %e, "Error aceptando conexión Puerta 1"),
        }
    }
}

/// Gestiona un agente banexus con protocolo newline-delimited.
async fn manejar_agente(
    stream: tokio::net::TcpStream,
    addr: String,
    registro: RegistroNodos,
    bauth_socket: String,
) -> anyhow::Result<()> {
    let node_id = registro.registrar(addr.clone(), "desconocido".into()).await;
    info!(node_id = %node_id, addr = %addr, "Agente banexus conectado");

    let (read_half, mut write_half) = stream.into_split();
    let mut lector = BufReader::new(read_half);
    let mut linea = String::new();

    loop {
        linea.clear();
        let n = lector.read_line(&mut linea).await?;
        if n == 0 {
            registro.remover(&node_id).await;
            info!(node_id = %node_id, "Agente desconectado");
            return Ok(());
        }

        let texto = linea.trim_end_matches(['\n', '\r']).trim();
        if texto.is_empty() {
            continue;
        }

        let respuesta =
            procesar_mensaje(texto, &node_id, &registro, &bauth_socket).await;
        // Respuesta newline-terminated
        write_half.write_all(respuesta.as_bytes()).await?;
        write_half.write_u8(b'\n').await?;
    }
}

/// Procesa un mensaje JSON del agente y retorna respuesta JSON.
async fn procesar_mensaje(
    texto: &str,
    node_id: &Uuid,
    registro: &RegistroNodos,
    bauth_socket: &str,
) -> String {
    let Ok(msg) = serde_json::from_str::<Value>(texto) else {
        return json!({"error": "JSON inválido"}).to_string();
    };

    match msg.get("type").and_then(Value::as_str) {
        Some("heartbeat") => {
            registro.actualizar_ping(node_id).await;
            json!({"type": "pong", "node_id": node_id}).to_string()
        }

        Some("handshake") => {
            let modo = msg
                .get("modo")
                .and_then(Value::as_str)
                .unwrap_or("daemon")
                .to_string();
            registro.actualizar_modo(node_id, modo.clone()).await;
            json!({
                "type": "handshake_ok",
                "node_id": node_id,
                "modo": modo,
                "granted": true,
                "dev_mode": true,
            })
            .to_string()
        }

        Some("rpc_call") => {
            // Extraer el payload JSON-RPC que viene del desktop Flutter
            let payload = match msg.get("payload") {
                Some(p) => p.clone(),
                None => {
                    return json!({"type":"rpc_error","error":"campo 'payload' ausente"})
                        .to_string();
                }
            };
            let seq = msg.get("seq").cloned().unwrap_or(json!(null));

            match bauth_proxy::llamar_bauth(bauth_socket, &payload).await {
                Ok(resp) => json!({
                    "type": "rpc_response",
                    "payload": resp,
                    "seq": seq,
                })
                .to_string(),
                Err(e) => {
                    warn!(error = %e, "Error proxying a bAuth");
                    json!({
                        "type": "rpc_error",
                        "error": e.to_string(),
                        "seq": seq,
                    })
                    .to_string()
                }
            }
        }

        _ => json!({"error": "tipo de mensaje desconocido"}).to_string(),
    }
}
