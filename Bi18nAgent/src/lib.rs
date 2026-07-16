/// lib.rs — Punto de entrada del crate bi18n-daemon-orchestrator.
/// Propósito: re-exporta los módulos públicos del orquestador.
///   - El crate es tanto una librería (para tests e integración) como un daemon.
///   - Las implementaciones viven en los submódulos; lib.rs solo declara.
/// Dependencias: todos los módulos del crate.
pub mod config;
pub mod domain;
pub mod error;
pub mod generated;
pub mod server;
