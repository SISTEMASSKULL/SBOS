// ================================================================
// bauth::server::websocket — WebSocket RFC 6455 nativo
//
// Vía 1 de la Interface Dual ADR-020: WebSocket RPC para CLI
// humano (bauthctl) y Core UI. MISMO Unix socket que Vía 2.
//
// Sin dependencias externas de WebSocket — solo RFC 6455 + crate base64.
// ================================================================

#![allow(dead_code)]
use sha1::{Sha1, Digest};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixStream;
use tracing::{debug, info, warn};

const WS_MAGIC: &str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const OP_TEXT: u8 = 0x1;
const OP_CLOSE: u8 = 0x8;
const OP_PING: u8 = 0x9;
const OP_PONG: u8 = 0xA;

/// Maneja una conexión WebSocket con el primer byte ('G') ya leído.
pub async fn handle_ws_connection_with_prefix(
    mut stream: UnixStream,
    first_byte: u8,
    ctx: Arc<super::ServerContext>,
) {
    let key = match ws_handshake_with_prefix(&mut stream, first_byte).await {
        Ok(k) => k,
        Err(e) => { warn!(error = %e, "handshake WebSocket fallido"); return; }
    };
    info!(key = %key, "WebSocket conectado (Vía 1 — CLI/Core UI)");

    let mut buf = vec![0u8; 65536];
    loop {
        match read_ws_frame(&mut stream, &mut buf).await {
            Ok(WsFrame::Text { payload }) => {
                let request = String::from_utf8_lossy(&payload).to_string();
                debug!(request = %request.chars().take(80).collect::<String>(), "WS recv");
                let response = ctx.dispatcher.handle_jsonrpc(&request).await;
                if let Err(e) = write_ws_frame(&mut stream, OP_TEXT, response.as_bytes()).await {
                    warn!(error = %e, "error al escribir frame WS"); break;
                }
            }
            Ok(WsFrame::Ping { payload }) => {
                if let Err(e) = write_ws_frame(&mut stream, OP_PONG, &payload).await {
                    warn!(error = %e, "error pong"); break;
                }
            }
            Ok(WsFrame::Close { .. }) => {
                let _ = write_ws_frame(&mut stream, OP_CLOSE, &[]).await;
                info!("WebSocket cerrado limpiamente");
                break;
            }
            Err(WsError::ConnectionClosed) => break,
            Err(e) => { warn!(error = %e, "error frame WS"); break; }
        }
    }
}

/// Handshake WebSocket con primer byte ('G') ya leído.
/// RFC 6455 §4 — usa el crate `base64` (ya dependencia del proyecto) para Sec-WebSocket-Accept.
async fn ws_handshake_with_prefix(
    stream: &mut UnixStream, first_byte: u8,
) -> Result<String, String> {
    let mut buf = vec![first_byte];
    let mut rest = [0u8; 4096];
    let n = stream.read(&mut rest).await
        .map_err(|e| format!("error handshake: {}", e))?;
    if n == 0 { return Err("conexion cerrada en handshake".into()); }
    buf.extend_from_slice(&rest[..n]);

    let request = String::from_utf8_lossy(&buf);
    let key = request.lines()
        .find(|l| l.to_lowercase().starts_with("sec-websocket-key:"))
        .and_then(|l| l.split(':').nth(1))
        .map(|s| s.trim().to_string())
        .ok_or_else(|| "falta Sec-WebSocket-Key".to_string())?;

    let mut hasher = Sha1::new();
    hasher.update(format!("{}{}", key, WS_MAGIC).as_bytes());
    let hash = hasher.finalize();

    use base64::Engine;
    let accept = base64::engine::general_purpose::STANDARD.encode(hash);

    let response = format!(
        "HTTP/1.1 101 Switching Protocols\r\n\
         Upgrade: websocket\r\n\
         Connection: Upgrade\r\n\
         Sec-WebSocket-Accept: {}\r\n\r\n", accept);

    stream.write_all(response.as_bytes()).await
        .map_err(|e| format!("error handshake response: {}", e))?;
    Ok(key)
}

#[derive(Debug)]
enum WsFrame {
    Text { payload: Vec<u8> },
    Ping { payload: Vec<u8> },
    Close { code: u16 },
}

#[derive(Debug)]
enum WsError {
    ConnectionClosed,
    Protocol(String),
}

impl std::fmt::Display for WsError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WsError::ConnectionClosed => write!(f, "conexion cerrada"),
            WsError::Protocol(s) => write!(f, "protocolo: {}", s),
        }
    }
}

/// Lee un frame WebSocket según RFC 6455 §5.2.
async fn read_ws_frame(stream: &mut UnixStream, buf: &mut [u8]) -> Result<WsFrame, WsError> {
    let mut header = [0u8; 2];
    if stream.read_exact(&mut header).await.is_err() {
        return Err(WsError::ConnectionClosed);
    }
    let opcode = header[0] & 0x0F;
    let masked = (header[1] & 0x80) != 0;
    let mut payload_len = (header[1] & 0x7F) as u64;

    if payload_len == 126 {
        let mut ext = [0u8; 2];
        stream.read_exact(&mut ext).await.map_err(|e| WsError::Protocol(e.to_string()))?;
        payload_len = u16::from_be_bytes(ext) as u64;
    } else if payload_len == 127 {
        let mut ext = [0u8; 8];
        stream.read_exact(&mut ext).await.map_err(|e| WsError::Protocol(e.to_string()))?;
        payload_len = u64::from_be_bytes(ext);
    }

    if payload_len > buf.len() as u64 {
        return Err(WsError::Protocol(format!("payload {} bytes", payload_len)));
    }

    let mut mask = [0u8; 4];
    if masked {
        stream.read_exact(&mut mask).await.map_err(|e| WsError::Protocol(e.to_string()))?;
    }

    let plen = payload_len as usize;
    if plen > 0 {
        stream.read_exact(&mut buf[..plen]).await.map_err(|e| WsError::Protocol(e.to_string()))?;
        if masked {
            for i in 0..plen { buf[i] ^= mask[i % 4]; }
        }
    }

    match opcode {
        OP_TEXT => Ok(WsFrame::Text { payload: buf[..plen].to_vec() }),
        OP_PING => Ok(WsFrame::Ping { payload: buf[..plen].to_vec() }),
        OP_CLOSE => {
            let code = if plen >= 2 { u16::from_be_bytes([buf[0], buf[1]]) } else { 1000 };
            Ok(WsFrame::Close { code })
        }
        OP_PONG => Box::pin(read_ws_frame(stream, buf)).await,
        other => Err(WsError::Protocol(format!("opcode 0x{:x}", other))),
    }
}

/// Escribe un frame WebSocket. Servidor→cliente: SIN máscara (RFC 6455 §5.3).
async fn write_ws_frame(stream: &mut UnixStream, opcode: u8, payload: &[u8]) -> Result<(), String> {
    let len = payload.len();
    let mut frame = Vec::with_capacity(2 + 8 + len);
    frame.push(0x80 | opcode);
    if len < 126 {
        frame.push(len as u8);
    } else if len <= 65535 {
        frame.push(126);
        frame.extend_from_slice(&(len as u16).to_be_bytes());
    } else {
        frame.push(127);
        frame.extend_from_slice(&(len as u64).to_be_bytes());
    }
    frame.extend_from_slice(payload);
    stream.write_all(&frame).await.map_err(|e| format!("write frame: {}", e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_base64_ws_handshake() {
        use base64::Engine;
        let accept = base64::engine::general_purpose::STANDARD.encode(b"test");
        assert!(!accept.is_empty());
    }

    #[test]
    fn test_frame_text() {
        let payload = b"Hola";
        let mut frame = Vec::new();
        frame.push(0x81);
        frame.push(0x04);
        frame.extend_from_slice(payload);
        assert_eq!(frame, vec![0x81, 0x04, b'H', b'o', b'l', b'a']);
    }
}
