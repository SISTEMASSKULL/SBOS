//! Listener del socket Unix — Interface Dual ADR-020.
//! Acepta conexiones WebSocket RPC (operadores humanos) y JSON-RPC 2.0 (daemons).
//! SSOT: BnexusAgent/context/Documentacion/2.03_MANUAL-INTERFACE-DUAL-NEXUS.md

use crate::node::RegistroNodos;
use std::path::Path;
use tokio::net::UnixListener;
use tracing::{error, info, warn};

/// Escucha en el socket Unix y despacha conexiones WebSocket.
pub async fn escuchar(
    socket_path: String,
    registro: RegistroNodos,
) -> anyhow::Result<()> {
    // Limpia socket anterior si quedó de sesión previa.
    if Path::new(&socket_path).exists() {
        std::fs::remove_file(&socket_path)?;
    }

    let listener = UnixListener::bind(&socket_path)?;
    info!(socket = %socket_path, "Interface Dual escuchando");

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                let reg = registro.clone();
                tokio::spawn(async move {
                    if let Err(e) = super::websocket::manejar_conexion(stream, reg).await {
                        error!(error = %e, "Error en conexión Interface Dual");
                    }
                });
            }
            Err(e) => warn!(error = %e, "Error aceptando conexión Unix"),
        }
    }
}
