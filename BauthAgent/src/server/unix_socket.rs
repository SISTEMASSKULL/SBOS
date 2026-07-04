// ================================================================
// bauth::server::unix_socket — Listener Unix Socket /run/bos/bauth.sock
// B0.T07 — ADR-020 Interface Dual
//
// Escucha en Unix socket con permisos 0660 grupo bosagent.
// MISMO socket, DOS vías:
//   Vía 1: WebSocket RPC → CLI humano (bauthctl), Core UI
//   Vía 2: JSON-RPC 2.0  → daemons (biedata, bkernel), agentes IA
//
// Detección automática de protocolo por primer byte:
//   'G' → WebSocket (HTTP GET upgrade)
//   '{' → JSON-RPC 2.0 (raw)
//
// DOC-SBOS-001 N3 · ADR-002 · ADR-020 · B0.T07
// ================================================================

use crate::config::ServerConfig;
use crate::server::ServerContext;
use crate::signal::DrainManager;
use std::io;
use std::os::unix::fs::PermissionsExt;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;
use tracing::{error, info, warn};

/// Inicia el listener del Unix socket con dispatch dual.
/// Detecta automáticamente WebSocket vs JSON-RPC por el primer byte.
pub async fn listen(cfg: ServerConfig, drain: DrainManager, ctx: ServerContext) -> io::Result<()> {
    let path = &cfg.socket_path;

    if std::path::Path::new(path).exists() {
        warn!(path, "eliminando socket huérfano");
        std::fs::remove_file(path)?;
    }
    if let Some(parent) = std::path::Path::new(path).parent() {
        std::fs::create_dir_all(parent)?;
    }

    let listener = UnixListener::bind(path)?;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(cfg.socket_perms))?;

    if let Err(e) = change_group(path, &cfg.socket_group) {
        warn!(group = %cfg.socket_group, error = %e, "no se pudo cambiar grupo del socket");
    }

    info!(path, perms = format!("{:o}", cfg.socket_perms), group = %cfg.socket_group,
          "Interface Dual activa — WebSocket (Vía 1) + JSON-RPC 2.0 (Vía 2)");

    let ctx = Arc::new(ctx);

    loop {
        match listener.accept().await {
            Ok((stream, _addr)) => {
                if drain.active_connections() >= ctx.max_connections as u64 {
                    warn!(max = ctx.max_connections, "conexión rechazada — máximo alcanzado");
                    drop(stream);
                    continue;
                }
                drain.connection_start();
                let ctx = ctx.clone();
                let drain = drain.clone();
                tokio::spawn(async move {
                    handle_connection_dual(stream, ctx).await;
                    drain.connection_end();
                });
            }
            Err(e) => {
                error!(error = %e, "error al aceptar conexión");
            }
        }
    }
}

/// Maneja una conexión con detección automática de protocolo.
/// Lee el primer byte: 'G' → WebSocket | resto → JSON-RPC.
/// Aplanado con early returns (H-018).
async fn handle_connection_dual(mut stream: tokio::net::UnixStream, ctx: Arc<ServerContext>) {
    let mut first = [0u8; 1];
    let _n = match stream.read(&mut first).await {
        Ok(n) if n > 0 => n,
        _ => return,
    };

    if first[0] == b'G' {
        info!("conexión WebSocket detectada (Vía 1)");
        crate::server::websocket::handle_ws_connection_with_prefix(stream, first[0], ctx).await;
    } else {
        handle_jsonrpc_with_prefix(stream, first[0], ctx).await;
    }
}

/// Maneja conexión JSON-RPC con primer byte ya leído (H-018: unificada).
/// Buffer dinámico con límite configurable (ctx.max_request_bytes) — evita DoS (M-03).
async fn handle_jsonrpc_with_prefix(mut stream: tokio::net::UnixStream, first_byte: u8, ctx: Arc<ServerContext>) {
    let max_bytes = ctx.max_request_bytes;
    let mut buf = Vec::with_capacity(512);
    buf.push(first_byte);

    let mut chunk = [0u8; 4096];
    loop {
        match stream.read(&mut chunk).await {
            Ok(0) => break,
            Ok(n) => {
                if buf.len() + n > max_bytes {
                    warn!(limit = max_bytes, "request JSON-RPC excede límite — conexión cerrada");
                    return;
                }
                buf.extend_from_slice(&chunk[..n]);
                if buf.contains(&b'\n') { break; }
            }
            Err(_) => return,
        }
    }

    let data = String::from_utf8_lossy(&buf);
    let requests = extract_jsonrpc_requests(&data);
    if requests.is_empty() && !data.trim().is_empty() {
        // Contenido recibido pero ninguna línea es JSON-RPC → -32700
        let parse_err = serde_json::to_string(&crate::server::jsonrpc::Response::parse_error())
            .unwrap_or_default();
        let _ = stream.write_all(parse_err.as_bytes()).await;
    } else {
        for req in requests {
            let response = ctx.dispatcher.handle_jsonrpc(&req).await;
            let _ = stream.write_all(response.as_bytes()).await;
        }
    }
}

/// Extrae requests JSON-RPC individuales de un buffer.
fn extract_jsonrpc_requests(data: &str) -> Vec<String> {
    data.lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty() && l.starts_with('{'))
        .collect()
}

/// Cambia el grupo propietario del socket via POSIX lchown (B-04).
/// No lanza subprocesos — usa syscalls del kernel directamente.
fn change_group(path: &str, group_name: &str) -> io::Result<()> {
    let gid = group_gid(group_name)?;
    let path_c = std::ffi::CString::new(path)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "ruta contiene byte nulo"))?;
    // lchown: no sigue symlinks — previene race TOCTOU. uid=u32::MAX → no cambiar uid.
    let ret = unsafe { libc::lchown(path_c.as_ptr(), u32::MAX, gid) };
    if ret != 0 {
        return Err(io::Error::last_os_error());
    }
    info!(path, group = group_name, gid, "grupo del socket cambiado");
    Ok(())
}

/// Resuelve el GID de un grupo via POSIX getgrnam_r (sin subprocesos).
fn group_gid(group_name: &str) -> io::Result<libc::gid_t> {
    let name_c = std::ffi::CString::new(group_name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "nombre de grupo contiene byte nulo"))?;
    let mut grp: libc::group = unsafe { std::mem::zeroed() };
    let mut result: *mut libc::group = std::ptr::null_mut();
    let mut buf = vec![0u8; 4096];
    let ret = unsafe {
        libc::getgrnam_r(
            name_c.as_ptr(),
            &mut grp,
            buf.as_mut_ptr() as *mut libc::c_char,
            buf.len(),
            &mut result,
        )
    };
    if ret != 0 {
        return Err(io::Error::from_raw_os_error(ret));
    }
    if result.is_null() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("grupo '{}' no encontrado en el sistema", group_name),
        ));
    }
    Ok(unsafe { (*result).gr_gid })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::server::jsonrpc::JsonRpcDispatcher;

    #[tokio::test]
    async fn test_cleanup_stale_socket() {
        let tmp = tempfile::tempdir().unwrap();
        let sock_path = tmp.path().join("bauth.sock");
        std::fs::write(&sock_path, b"stale").unwrap();
        assert!(sock_path.exists());

        let cfg = ServerConfig {
            socket_path: sock_path.to_str().unwrap().to_string(),
            ..Default::default()
        };
        let dispatcher = Arc::new(JsonRpcDispatcher::new());
        let default_cfg = crate::config::ServerConfig::default();
        let ctx = ServerContext { dispatcher, max_connections: 10, max_request_bytes: default_cfg.max_request_bytes };
        let drain = DrainManager::new();
        let handle = tokio::spawn(async move { let _ = listen(cfg, drain, ctx).await; });
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        handle.abort();
        assert!(sock_path.exists());
    }
}
