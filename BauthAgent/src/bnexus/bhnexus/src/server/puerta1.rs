//! Puerta 1 — listener TCP 9444 para banexus-daemon y banexus-gateway.
//! Etapa 1: TLS con dev CA autofirmada. Etapa 3: SPIFFE/SVID.
//! SSOT: BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

use crate::auth::DevCa;
use crate::node::RegistroNodos;
use serde_json::{json, Value};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tracing::{error, info, warn};
use uuid::Uuid;

/// Escucha en TCP 9444 y procesa conexiones de banexus agents.
pub async fn escuchar(
    puerto: u16,
    _dev_ca: DevCa,
    registro: RegistroNodos,
) -> anyhow::Result<()> {
    let addr = format!("0.0.0.0:{puerto}");
    let listener = TcpListener::bind(&addr).await?;
    info!(addr = %addr, "Puerta 1 escuchando");

    loop {
        match listener.accept().await {
            Ok((mut stream, peer_addr)) => {
                let reg = registro.clone();
                let addr_str = peer_addr.to_string();
                tokio::spawn(async move {
                    if let Err(e) = manejar_agente(&mut stream, addr_str, reg).await {
                        error!(error = %e, "Error en agente Puerta 1");
                    }
                });
            }
            Err(e) => warn!(error = %e, "Error aceptando conexión Puerta 1"),
        }
    }
}

/// Protocolo mínimo Etapa 1: recibe JSON, procesa heartbeat y auth.
async fn manejar_agente(
    stream: &mut tokio::net::TcpStream,
    addr: String,
    registro: RegistroNodos,
) -> anyhow::Result<()> {
    // Registro del nodo al conectarse (modo desconocido hasta handshake).
    let node_id = registro.registrar(addr.clone(), "desconocido".into()).await;
    info!(node_id = %node_id, addr = %addr, "Agente banexus conectado");

    let mut buf = vec![0u8; 4096];
    loop {
        let n = stream.read(&mut buf).await?;
        if n == 0 {
            // Conexión cerrada limpiamente.
            registro.remover(&node_id).await;
            info!(node_id = %node_id, "Agente desconectado");
            return Ok(());
        }

        let texto = std::str::from_utf8(&buf[..n]).unwrap_or("");
        let respuesta = procesar_mensaje(texto, &node_id, &registro).await;
        stream.write_all(respuesta.as_bytes()).await?;
    }
}

/// Procesa un mensaje JSON del agente y retorna respuesta JSON.
async fn procesar_mensaje(
    texto: &str,
    node_id: &Uuid,
    registro: &RegistroNodos,
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
            // Etapa 1: acepta cualquier handshake — GRANTED.
            let modo = msg.get("modo").and_then(Value::as_str).unwrap_or("daemon").to_string();
            // Actualizar modo en el registro tras handshake.
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
        _ => json!({"error": "tipo de mensaje desconocido"}).to_string(),
    }
}
