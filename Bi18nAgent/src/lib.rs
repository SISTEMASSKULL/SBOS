// lib.rs — Punto de entrada del crate bi18n-daemon-orchestrator.
// Re-exporta los módulos públicos; el crate funciona como librería (tests) y daemon.

// Inicialización compile-time de rust-i18n (A.08.02).
// Escanea locales/ buscando YAML/TOML; si no hay (solo FTL), genera backend vacío.
// Expone: rust_i18n::locale(), set_locale(), t!(), available_locales!()
rust_i18n::i18n!("locales");

pub mod cli;
pub mod config;
pub mod domain;
pub mod error;
pub mod generated;
pub mod preflight;
pub mod server;
