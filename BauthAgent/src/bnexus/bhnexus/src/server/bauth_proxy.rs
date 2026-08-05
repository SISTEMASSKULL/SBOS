//! Proxy de llamadas JSON-RPC al socket Unix de bAuth.
//! Abre una conexión nueva por cada rpc_call (simple — Etapa 1).
//! En Etapa 2 se añadirá pool de conexiones y validación SPIFFE/SVID.
//! SSOT: BnexusAgent/context/Documentacion/ · bAuth ADR-020 (Interface Dual)

use anyhow::Result;
use serde_json::Value;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{unix::OwnedReadHalf, UnixStream};
use tracing::debug;

/// Envía [payload] al socket Unix de bAuth y retorna la respuesta JSON.
/// Abre y cierra la conexión por cada llamada — latencia local ≈ 0 ms.
pub async fn llamar_bauth(socket_path: &str, payload: &Value) -> Result<Value> {
    let stream = UnixStream::connect(socket_path).await.map_err(|e| {
        anyhow::anyhow!("No se pudo conectar a bAuth en {}: {}", socket_path, e)
    })?;

    // bAuth lee hasta EOF antes de procesar — dividir el stream para hacer half-close
    // en el write side (SHUT_WR) tras enviar el payload, sin cerrar el read side.
    let (mut read_half, mut write_half) = stream.into_split();

    let msg = payload.to_string();
    debug!(metodo = payload.get("method").and_then(|v| v.as_str()).unwrap_or("?"), "→ bAuth");
    write_half.write_all(msg.as_bytes()).await?;
    // Señalar EOF al socket de bAuth: sin esto bAuth espera indefinidamente.
    write_half.shutdown().await?;

    let respuesta = leer_json_completo(&mut read_half).await?;
    debug!(bytes = respuesta.len(), "← bAuth");

    serde_json::from_str(&respuesta)
        .map_err(|e| anyhow::anyhow!("JSON inválido de bAuth: {e}"))
}

/// Lee un objeto JSON completo por conteo de llaves `{}`.
/// Robusto ante fragmentación TCP/Unix socket — lee byte a byte.
async fn leer_json_completo(stream: &mut OwnedReadHalf) -> Result<String> {
    let mut resultado: Vec<u8> = Vec::with_capacity(4096);
    let mut nivel: i32 = 0;
    let mut en_cadena = false;
    let mut escape_next = false;
    let mut iniciado = false;
    let mut byte = [0u8; 1];

    loop {
        let n = stream.read(&mut byte).await?;
        if n == 0 {
            if iniciado && nivel == 0 {
                break;
            }
            return Err(anyhow::anyhow!(
                "bAuth cerró conexión antes de completar el JSON (nivel={nivel})"
            ));
        }

        let c = byte[0];
        resultado.push(c);

        if escape_next {
            escape_next = false;
            continue;
        }
        if c == b'\\' && en_cadena {
            escape_next = true;
            continue;
        }
        if c == b'"' {
            en_cadena = !en_cadena;
            continue;
        }
        if en_cadena {
            continue;
        }

        match c {
            b'{' => {
                nivel += 1;
                iniciado = true;
            }
            b'}' => {
                nivel -= 1;
                if iniciado && nivel == 0 {
                    break;
                }
            }
            _ => {}
        }

        if resultado.len() > 512 * 1024 {
            return Err(anyhow::anyhow!("Respuesta de bAuth supera 512 KB — abortando"));
        }
    }

    String::from_utf8(resultado).map_err(|e| anyhow::anyhow!("UTF-8 inválido de bAuth: {e}"))
}
