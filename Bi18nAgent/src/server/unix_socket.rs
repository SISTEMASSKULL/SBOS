/// server/unix_socket.rs — Servidor JSON-RPC 2.0 + WebSocket sobre Unix socket.
/// Propósito: escucha en /run/bos/bi18n.sock (Interface Triple — Vías 1 y 2).
///   - Vía 1 (WebSocket): conexiones de CLI humano e i18nctl.
///   - Vía 2 (JSON-RPC 2.0 newline-delimited): daemons SBOS (bAuth, bpay...).
///   - El dispatch de métodos vive en dispatcher.rs (DOC-SBOS-001 N3: split de tamaño).
/// Dependencias: tokio, serde_json, crate::server
use std::path::PathBuf;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    sync::watch,
};
use serde::Deserialize;
use serde_json::Value;
use crate::{
    error::Bi18nError,
    server::context::ServerContext,
};

/// Inicia el servidor JSON-RPC 2.0 sobre Unix socket.
pub async fn iniciar_jsonrpc(
    socket_path: PathBuf,
    ctx: ServerContext,
    mut shutdown: watch::Receiver<bool>,
) -> Result<(), Bi18nError> {
    let _ = tokio::fs::remove_file(&socket_path).await;

    let listener = UnixListener::bind(&socket_path)
        .map_err(|e| Bi18nError::SocketBind { path: socket_path.clone(), causa: e.to_string() })?;

    use std::os::unix::fs::PermissionsExt;
    tokio::fs::set_permissions(
        &socket_path,
        std::fs::Permissions::from_mode(0o660),
    ).await.map_err(|e| Bi18nError::SocketPermisos { path: socket_path.clone(), causa: e.to_string() })?;

    tracing::info!("JSON-RPC escuchando en {:?} (Interface Triple — Vías 1+2)", socket_path);

    loop {
        tokio::select! {
            resultado = listener.accept() => {
                match resultado {
                    Ok((stream, _)) => {
                        let ctx_c = ctx.clone();
                        tokio::spawn(async move {
                            manejar_conexion(stream, ctx_c).await;
                        });
                    }
                    Err(e) => tracing::error!("Error aceptando conexión: {}", e),
                }
            }
            _ = shutdown.changed() => {
                tracing::info!("JSON-RPC: shutdown recibido, cerrando socket");
                break;
            }
        }
    }

    Ok(())
}

/// Maneja una conexión Unix socket: lee requests JSON-RPC, responde.
/// Incrementa `activas` al abrir la conexión y decrementa al cerrarla —
/// permite a SIGTERM y SIGHUP esperar el drenado antes de actuar.
async fn manejar_conexion(stream: UnixStream, ctx: ServerContext) {
    ctx.solicitud_iniciada();
    let (reader, mut writer) = stream.into_split();
    let mut lineas = BufReader::new(reader).lines();

    while let Ok(Some(linea)) = lineas.next_line().await {
        let respuesta = despachar_request(&linea, &ctx).await;
        let mut json = serde_json::to_string(&respuesta)
            .unwrap_or_else(|_| error_jsonrpc(-32603, "serialización fallida"));
        json.push('\n');
        if writer.write_all(json.as_bytes()).await.is_err() {
            break;
        }
    }
    ctx.solicitud_finalizada();
}

/// Parsea y despacha un request JSON-RPC 2.0 al dispatcher centralizado.
async fn despachar_request(linea: &str, ctx: &ServerContext) -> Value {
    let req: JsonRpcRequest = match serde_json::from_str(linea) {
        Ok(r) => r,
        Err(e) => {
            return serde_json::from_str(
                &error_jsonrpc(-32700, &format!("Error de parseo: {}", e))
            ).unwrap_or(Value::Null);
        }
    };

    let id        = req.id.clone();
    let resultado = crate::server::dispatcher::ejecutar_metodo(
        &req.method,
        req.params.unwrap_or(Value::Null),
        ctx,
    ).await;

    match resultado {
        Ok(result) => serde_json::json!({ "jsonrpc": "2.0", "id": id, "result": result }),
        Err(e) => {
            let code = match &e {
                Bi18nError::MetodoNoEncontrado { .. } => -32601_i32,
                Bi18nError::CtxIdAusente             => -32602,
                _                                    => -32000,
            };
            serde_json::json!({ "jsonrpc": "2.0", "id": id,
                "error": { "code": code, "message": e.to_string() } })
        }
    }
}

// ── Estructuras JSON-RPC 2.0 ──────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct JsonRpcRequest {
    method: String,
    params: Option<Value>,
    id: Value,
}

fn error_jsonrpc(code: i32, msg: &str) -> String {
    serde_json::to_string(&serde_json::json!({
        "jsonrpc": "2.0",
        "id": null,
        "error": { "code": code, "message": msg },
    })).unwrap_or_default()
}
