/// server/mod.rs — Capa de interfaz del daemon bi18n (Interface Triple C11).
/// Propósito: declara los tres servidores, el dispatcher y el contexto compartido.
///   - unix_socket: JSON-RPC 2.0 + WebSocket sobre /run/bos/bi18n.sock
///   - dispatcher: match method→handler para todos los métodos JSON-RPC (DOC-SBOS-001 N3)
///   - grpc: gRPC sobre /run/bos/bi18n-grpc.sock (sin TCP — SBOS-050 P9)
///   - handlers: lógica de negocio compartida entre JSON-RPC y gRPC
/// Dependencias: tokio, tonic, serde_json, crate::domain, crate::error
pub mod context;
pub mod dispatcher;
pub mod dispatcher_helpers;
pub mod grpc;
pub mod grpc_attr;
pub mod grpc_validate;
pub mod handlers;
pub mod unix_socket;
pub mod websocket;

pub use context::ServerContext;
