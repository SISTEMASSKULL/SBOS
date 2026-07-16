/// server/mod.rs — Capa de interfaz del daemon bi18n (Interface Triple C11).
/// Propósito: declara los tres servidores y el contexto compartido.
///   - unix_socket: JSON-RPC 2.0 + WebSocket sobre /run/bos/bi18n.sock
///   - grpc: gRPC sobre /run/bos/bi18n-grpc.sock (sin TCP — SBOS-050 P9)
///   - handlers: lógica de negocio compartida entre ambos servidores
/// Dependencias: tokio, tonic, serde_json, crate::domain, crate::error
pub mod context;
pub mod grpc;
pub mod grpc_attr;
pub mod grpc_validate;
pub mod handlers;
pub mod unix_socket;

pub use context::ServerContext;
