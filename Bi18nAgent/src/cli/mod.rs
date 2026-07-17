/// cli/mod.rs — Módulos de subcomandos de Fase 2 para bi18nctl.
/// Propósito: separa los 107 subcomandos nuevos del entry point del binario.
///   Cada módulo define el enum del namespace y la función construir_llamada_*.
/// Dependencias: clap, serde_json::Value
pub mod admin_traducciones;
pub mod datetime;
pub mod format_fase2;
pub mod guard;
pub mod i18n;
pub mod locale_fase2;
pub mod mask_fase2;
pub mod phone;
pub mod text;
pub mod translate;
pub mod validate_fase2;
