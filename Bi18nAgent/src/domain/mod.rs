/// domain/mod.rs — Módulos de lógica pura de bi18n.
/// Sin HTTP, sin sockets directos. Transformaciones, reglas y gestión de recursos.
/// Dependencias: crate, crates externos (arc-swap, notify, fluent-bundle).
pub mod country_rules;
pub mod file_watcher;
pub mod fluent_loader;
pub mod format_map;
pub mod input_mask;
pub mod regional_config;
pub mod signal;
pub mod translations;
