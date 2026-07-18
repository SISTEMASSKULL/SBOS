/// server/handlers/mod.rs — Handlers de negocio compartidos entre JSON-RPC y gRPC.
/// Propósito: ÚNICA fuente de lógica por operación — elimina duplicación.
///   - JSON-RPC llama a estos handlers después de parsear el request.
///   - gRPC llama a los mismos handlers después de deserializar el proto.
///   - Garantía de paridad C11: mismo resultado, distinto transporte.
/// Dependencias: crate::server::context, crate::domain, crate::error
pub mod attr;
pub(crate) mod attr_helpers;
pub mod lib_admin_traducciones;
pub mod enums;
pub mod format;
pub(crate) mod format_utils;
pub mod health;
pub mod lib_chrono;
pub mod lib_fluent;
pub mod lib_jiff;
pub mod lib_mask_pii;
pub mod lib_icu_datetime;
pub mod lib_icu_decimal;
pub mod lib_icu_locale;
pub mod lib_phonenumber;
pub mod lib_prism3;
pub mod lib_regex;
pub mod lib_rust_i18n;
pub mod lib_scrutiny;
pub mod lib_universal_mask;
pub mod lib_validator;
pub mod locale;
pub mod mask;
pub mod sdk;
pub mod snapshot;
pub mod validate;
