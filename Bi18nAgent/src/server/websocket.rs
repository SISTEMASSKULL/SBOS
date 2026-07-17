/// server/websocket.rs — Servidor WebSocket sobre TCP para clientes remotos (Bloque 9.1).
/// Propósito: recibe conexiones WebSocket de cualquier cliente (agnóstico de plataforma —
///   Dart, TypeScript, Python, Go, curl, wscat — cualquier cosa que hable WS).
///   Kong proxea la ruta pública (/ws o similar) hacia ws_bind del daemon.
///   El protocolo es idéntico al del Unix socket: JSON-RPC 2.0, un objeto JSON por frame.
///   - Rate limiting por conexión (ventana deslizante 1s): protege contra clientes sin debounce.
///   - Timeout por request: evita que un handler lento bloquee la conexión completa.
///   - Mismo dispatcher ejecutar_metodo — un solo core, dos transportes (C11).
/// Dependencias: tokio, tokio-tungstenite, futures-util, serde_json, crate::server

use std::time::{Duration, Instant};
use tokio::{net::TcpListener, sync::watch};
use tokio_tungstenite::{accept_async, tungstenite::Message};
use futures_util::{SinkExt, StreamExt};
use serde_json::Value;
use crate::{
    error::Bi18nError,
    server::{context::ServerContext, dispatcher},
};

/// Inicia el servidor WebSocket sobre TCP.
/// Falla con `Bi18nError::SocketBind` si el puerto ya está ocupado.
pub async fn iniciar_websocket(
    bind: String,
    ctx: ServerContext,
    rate_limit_rps: u32,
    timeout_ms: u64,
    mut shutdown: watch::Receiver<bool>,
) -> Result<(), Bi18nError> {
    let listener = TcpListener::bind(&bind).await
        .map_err(|e| Bi18nError::SocketBind {
            path: std::path::PathBuf::from(&bind),
            causa: e.to_string(),
        })?;

    tracing::info!("WebSocket TCP escuchando en {} (clientes remotos vía Kong)", bind);

    loop {
        tokio::select! {
            resultado = listener.accept() => {
                match resultado {
                    Ok((stream, addr)) => {
                        let ctx_c = ctx.clone();
                        tokio::spawn(async move {
                            tracing::debug!("WS: conexión entrante desde {}", addr);
                            manejar_conexion(stream, ctx_c, rate_limit_rps, timeout_ms).await;
                        });
                    }
                    Err(e) => tracing::error!("WS: error aceptando conexión TCP: {}", e),
                }
            }
            _ = shutdown.changed() => {
                tracing::info!("WebSocket TCP: shutdown recibido, cerrando");
                break;
            }
        }
    }
    Ok(())
}

/// Maneja una conexión WebSocket individual.
/// Realiza el upgrade HTTP→WS, luego procesa mensajes con rate limiting y timeout.
async fn manejar_conexion(
    stream: tokio::net::TcpStream,
    ctx: ServerContext,
    rate_limit_rps: u32,
    timeout_ms: u64,
) {
    let mut ws = match accept_async(stream).await {
        Ok(ws) => ws,
        Err(e) => { tracing::warn!("WS: handshake fallido: {}", e); return; }
    };

    ctx.solicitud_iniciada();

    // Estado de rate limiting local a esta conexión: ventana deslizante de 1 segundo.
    let mut ventana_inicio = Instant::now();
    let mut contador: u32 = 0;
    let timeout = Duration::from_millis(timeout_ms);

    while let Some(resultado) = ws.next().await {
        let msg = match resultado {
            Ok(m)  => m,
            Err(e) => { tracing::debug!("WS: error de frame: {}", e); break; }
        };

        match msg {
            Message::Text(texto) => {
                // Ventana deslizante: reiniciar contador si pasó ≥ 1 segundo
                let ahora = Instant::now();
                if ahora.duration_since(ventana_inicio) >= Duration::from_secs(1) {
                    ventana_inicio = ahora;
                    contador = 0;
                }
                contador += 1;

                let respuesta = if rate_limit_rps > 0 && contador > rate_limit_rps {
                    tracing::warn!("WS: rate limit excedido ({} req en ventana actual)", contador);
                    error_ws(Value::Null, -32000, "rate limit excedido — demasiados requests por segundo")
                } else {
                    match tokio::time::timeout(timeout, despachar(&texto, &ctx)).await {
                        Ok(r)  => r,
                        Err(_) => {
                            tracing::warn!("WS: timeout de {}ms excedido en request", timeout_ms);
                            error_ws(Value::Null, -32001, "timeout: el handler no respondió en el tiempo configurado")
                        }
                    }
                };

                if ws.send(Message::Text(respuesta)).await.is_err() { break; }
            }
            Message::Ping(data) => { let _ = ws.send(Message::Pong(data)).await; }
            Message::Close(_)   => break,
            _                   => {}
        }
    }

    ctx.solicitud_finalizada();
    tracing::debug!("WS: conexión cerrada");
}

/// Parsea un texto JSON-RPC y lo despacha al dispatcher central.
async fn despachar(texto: &str, ctx: &ServerContext) -> String {
    let req: Value = match serde_json::from_str(texto) {
        Ok(v)  => v,
        Err(e) => return error_ws(Value::Null, -32700, &format!("parse error: {}", e)),
    };

    let id     = req.get("id").cloned().unwrap_or(Value::Null);
    let method = req["method"].as_str().unwrap_or("");
    let params = req.get("params").cloned().unwrap_or(Value::Null);

    match dispatcher::ejecutar_metodo(method, params, ctx).await {
        Ok(result) => serde_json::to_string(
            &serde_json::json!({ "jsonrpc": "2.0", "id": id, "result": result })
        ).unwrap_or_default(),
        Err(e) => {
            let code = match &e {
                Bi18nError::MetodoNoEncontrado { .. } => -32601_i32,
                Bi18nError::CtxIdAusente             => -32602,
                _                                    => -32000,
            };
            error_ws(id, code, &e.to_string())
        }
    }
}

/// Construye un response de error JSON-RPC 2.0 serializado como String.
fn error_ws(id: Value, code: i32, msg: &str) -> String {
    serde_json::to_string(&serde_json::json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": msg }
    })).unwrap_or_default()
}
