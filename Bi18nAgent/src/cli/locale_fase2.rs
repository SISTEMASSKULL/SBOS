/// cli/locale_fase2.rs — Subcomandos bi18n.locale.* Fase 2 (A.08.04 icu_locale, 4 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum LocaleFase2 {
    /// Parsea y valida una etiqueta BCP 47 (subtags, script, región).
    ParseBcp47 {
        #[arg(long)] locale_str: String,
    },
    /// Canonicaliza un locale BCP 47 (expansión de aliases CLDR).
    Canonicalize {
        #[arg(long)] locale_str: String,
    },
    /// Negocia el mejor locale disponible para una lista de preferencias.
    Negotiate {
        #[arg(long)] locale_str: String,
        #[arg(long, help = "Locales disponibles separados por coma")] available: String,
    },
    /// Extrae los subtags (lenguaje, script, región, variantes) de un locale.
    Subtags {
        #[arg(long)] locale_str: String,
    },
}

pub fn construir_llamada(sub: &LocaleFase2, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        LocaleFase2::ParseBcp47 { locale_str } => (
            "bi18n.locale.parse_bcp47",
            json!({ "ctx_id": ctx_id, "locale": locale_str }),
        ),
        LocaleFase2::Canonicalize { locale_str } => (
            "bi18n.locale.canonicalize",
            json!({ "ctx_id": ctx_id, "locale": locale_str }),
        ),
        LocaleFase2::Negotiate { locale_str, available } => (
            "bi18n.locale.negotiate",
            json!({ "ctx_id": ctx_id, "locale": locale_str, "available": available }),
        ),
        LocaleFase2::Subtags { locale_str } => (
            "bi18n.locale.subtags",
            json!({ "ctx_id": ctx_id, "locale": locale_str }),
        ),
    }
}
