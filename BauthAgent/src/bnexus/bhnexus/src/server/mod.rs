//! Capa de servidor bhnexus — Interface Dual + Puerta 1.
//! Levanta dos listeners en paralelo:
//!   1. Unix socket — Interface Dual (WebSocket RPC + JSON-RPC 2.0)
//!   2. TCP 9444    — Puerta 1 (banexus-daemon y banexus-gateway)
//! SSOT: BnexusAgent/context/Documentacion/2.03_MANUAL-INTERFACE-DUAL-NEXUS.md

mod bauth_proxy;
mod jsonrpc;
mod puerta1;
mod unix_socket;
mod websocket;

use crate::auth::DevCa;
use crate::config::BhnexusConfig;
use crate::node::RegistroNodos;
use tracing::info;

/// Inicia todos los listeners de bhnexus.
pub async fn iniciar(cfg: BhnexusConfig) -> anyhow::Result<()> {
    let dev_ca = DevCa::generar_o_cargar(
        &cfg.dev.dev_ca_cert,
        &cfg.dev.dev_ca_key,
    )?;

    let registro = RegistroNodos::nuevo();

    info!(
        socket = %cfg.servidor.socket_unix,
        puerta1 = cfg.servidor.puerto_puerta1,
        bauth_socket = %cfg.bauth.jwks_socket,
        "Levantando listeners"
    );

    let socket_path  = cfg.servidor.socket_unix.clone();
    let puerto_p1    = cfg.servidor.puerto_puerta1;
    let registro_p1  = registro.clone();
    // Usamos jwks_socket como socket general de bAuth para proxying RPC.
    let bauth_socket = cfg.bauth.jwks_socket.clone();

    tokio::try_join!(
        unix_socket::escuchar(socket_path, registro.clone()),
        puerta1::escuchar(puerto_p1, dev_ca, registro_p1, bauth_socket),
    )?;

    Ok(())
}
