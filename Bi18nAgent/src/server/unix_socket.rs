/// server/unix_socket.rs — Servidor JSON-RPC 2.0 + WebSocket sobre Unix socket.
/// Propósito: escucha en /run/bos/bi18n.sock (Interface Triple — Vías 1 y 2).
///   - Vía 1 (WebSocket): conexiones de CLI humano e i18nctl.
///   - Vía 2 (JSON-RPC 2.0 newline-delimited): daemons SBOS (bAuth, bpay...).
///   - Todos los requests se despachan a server/handlers/*.rs (paridad con gRPC).
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
async fn manejar_conexion(stream: UnixStream, ctx: ServerContext) {
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
}

/// Parsea y despacha un request JSON-RPC 2.0.
async fn despachar_request(linea: &str, ctx: &ServerContext) -> Value {
    let req: JsonRpcRequest = match serde_json::from_str(linea) {
        Ok(r) => r,
        Err(e) => {
            return serde_json::from_str(&error_jsonrpc(-32700, &format!("Error de parseo: {}", e))).unwrap_or(Value::Null);
        }
    };

    let id = req.id.clone();
    let resultado = ejecutar_metodo(&req.method, req.params.unwrap_or(Value::Null), ctx).await;

    match resultado {
        Ok(result) => serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": result,
        }),
        Err(e) => {
            // Códigos JSON-RPC 2.0: -32601 método no encontrado, -32602 params inválidos.
            let code = match &e {
                crate::error::Bi18nError::MetodoNoEncontrado { .. } => -32601_i32,
                crate::error::Bi18nError::CtxIdAusente => -32602,
                _ => -32000,
            };
            serde_json::json!({
                "jsonrpc": "2.0",
                "id": id,
                "error": { "code": code, "message": e.to_string() },
            })
        }
    }
}

/// Dispatcher de métodos bi18n.*.
async fn ejecutar_metodo(
    method: &str,
    params: Value,
    ctx: &ServerContext,
) -> Result<Value, Bi18nError> {
    use crate::server::handlers;

    // SBOS-049: ctx_id obligatorio en toda operación — ausente o vacío = error.
    let _ctx_id = match params.get("ctx_id").and_then(|v| v.as_str()) {
        Some(id) if !id.is_empty() => id.to_string(),
        _ => return Err(Bi18nError::CtxIdAusente),
    };

    match method {
        "bi18n.health.check" => {
            let r = handlers::health::verificar(ctx).await?;
            Ok(serde_json::json!({
                "status": r.status,
                "version": r.version,
                "paises_cargados": r.paises_cargados,
                "mensaje": r.mensaje,
            }))
        }

        "bi18n.locale.resolve" => {
            let tenant_id = params["tenant_id"].as_str().unwrap_or("");
            let branch_id = params["branch_id"].as_str().unwrap_or("");
            let user_id   = params["user_id"].as_str().unwrap_or("");
            let r = handlers::locale::resolver_locale(ctx, tenant_id, branch_id, user_id).await?;
            Ok(serde_json::json!({
                "locale": r.config.locale,
                "timezone": r.config.timezone,
                "currency": r.config.currency,
                "country": r.config.country,
                "fuente": r.fuente,
            }))
        }

        "bi18n.validate.email" => {
            let valor = params["value"].as_str().unwrap_or("");
            let r = handlers::validate::validate_email(ctx, valor).await?;
            Ok(serde_json::json!({ "valid": r.valid, "normalized": r.normalized, "errores": r.errores }))
        }

        "bi18n.validate.phone" => {
            let valor       = params["value"].as_str().unwrap_or("");
            let pais_hint   = params["country_hint"].as_str().unwrap_or("BO");
            let r = handlers::validate::validate_phone(ctx, valor, pais_hint).await?;
            Ok(serde_json::json!({ "valid": r.valid, "e164": r.e164, "errores": r.errores }))
        }

        "bi18n.mask.pii" => {
            let texto       = params["text"].as_str().unwrap_or("");
            let mask_emails = params["mask_emails"].as_bool().unwrap_or(true);
            let mask_phones = params["mask_phones"].as_bool().unwrap_or(true);
            let r = handlers::mask::mask_pii(ctx, texto, mask_emails, mask_phones).await?;
            Ok(serde_json::json!({ "redacted": r.redacted, "campos_redactados": r.campos_redactados }))
        }

        "bi18n.enum.display" => {
            let enum_name = params["enum_name"].as_str().unwrap_or("");
            let value     = params["value"].as_str().unwrap_or("");
            let locale    = params["locale"].as_str().unwrap_or("es-BO");
            let r = handlers::enums::display(ctx, enum_name, value, locale).await?;
            Ok(serde_json::json!({ "label": r.label, "found": r.found, "fallback": r.fallback }))
        }

        metodo_desconocido => Err(Bi18nError::MetodoNoEncontrado {
            metodo: metodo_desconocido.to_string(),
        }),
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
