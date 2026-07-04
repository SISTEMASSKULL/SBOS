// ================================================================
// bauth::server — Interface Dual ADR-020
//
// Escucha en Unix socket /run/bos/bauth.sock (0660, grupo bosagent).
// MISMO socket, DOS vías:
//   Vía 1: WebSocket RPC → CLI humano (bauthctl), Core UI
//   Vía 2: JSON-RPC 2.0  → daemons (biedata, bkernel), agentes IA
//
// DOC-SBOS-001 N3 · ADR-002 · ADR-020 · B0.T07 · B18
// ================================================================

use std::sync::Arc;

pub mod jsonrpc;
pub mod handlers;
pub mod websocket;
pub mod unix_socket;

/// Contexto del servidor compartido entre conexiones.
pub struct ServerContext {
    pub dispatcher: Arc<jsonrpc::JsonRpcDispatcher>,
    pub max_connections: usize,
    /// Límite de tamaño de request JSON-RPC en bytes (de config::ServerConfig).
    pub max_request_bytes: usize,
}
