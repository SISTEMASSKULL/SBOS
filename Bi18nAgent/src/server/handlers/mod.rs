/// server/handlers/mod.rs — Handlers de negocio compartidos entre JSON-RPC y gRPC.
/// Propósito: ÚNICA fuente de lógica por operación — elimina duplicación.
///   - JSON-RPC llama a estos handlers después de parsear el request.
///   - gRPC llama a los mismos handlers después de deserializar el proto.
///   - Garantía de paridad C11: mismo resultado, distinto transporte.
/// Dependencias: crate::server::context, crate::domain, crate::error
pub mod attr;
pub(crate) mod attr_helpers;
pub mod enums;
pub mod format;
pub(crate) mod format_utils;
pub mod health;
pub mod locale;
pub mod mask;
pub mod snapshot;
pub mod validate;
