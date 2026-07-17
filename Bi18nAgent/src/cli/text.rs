/// cli/text.rs — Subcomandos bi18n.text.* (A.08.12 regex 1.13, 6 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Text {
    /// Comprueba si el texto hace match con el patrón regex.
    RegexMatch {
        #[arg(long)] text: String,
        #[arg(long)] pattern: String,
    },
    /// Extrae el primer grupo capturado del patrón en el texto.
    RegexExtract {
        #[arg(long)] text: String,
        #[arg(long)] pattern: String,
    },
    /// Extrae todos los matches del patrón en el texto.
    RegexExtractAll {
        #[arg(long)] text: String,
        #[arg(long)] pattern: String,
    },
    /// Verifica si el texto hace match con alguno de los patrones (separados por coma).
    RegexMatchSet {
        #[arg(long)] text: String,
        #[arg(long, help = "Patrones separados por coma")] patterns: String,
    },
    /// Divide el texto usando el patrón regex como delimitador.
    RegexSplit {
        #[arg(long)] text: String,
        #[arg(long)] pattern: String,
    },
    /// Reemplaza el primer match del patrón por el texto de reemplazo.
    RegexReplace {
        #[arg(long)] text: String,
        #[arg(long)] pattern: String,
        #[arg(long)] replacement: String,
    },
}

pub fn construir_llamada(sub: &Text, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Text::RegexMatch { text, pattern } => (
            "bi18n.text.regex_match",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern }),
        ),
        Text::RegexExtract { text, pattern } => (
            "bi18n.text.regex_extract",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern }),
        ),
        Text::RegexExtractAll { text, pattern } => (
            "bi18n.text.regex_extract_all",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern }),
        ),
        Text::RegexMatchSet { text, patterns } => (
            "bi18n.text.regex_match_set",
            json!({ "ctx_id": ctx_id, "text": text, "patterns": patterns }),
        ),
        Text::RegexSplit { text, pattern } => (
            "bi18n.text.regex_split",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern }),
        ),
        Text::RegexReplace { text, pattern, replacement } => (
            "bi18n.text.regex_replace",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern, "replacement": replacement }),
        ),
    }
}
