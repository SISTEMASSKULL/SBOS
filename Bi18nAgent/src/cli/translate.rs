/// cli/translate.rs — Subcomandos bi18n.translate.* (A.08.01 fluent-bundle, 6 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Translate {
    /// Traduce un mensaje por ID en el locale indicado.
    Message {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
    },
    /// Traduce un mensaje sustituyendo el argumento numérico {$n}.
    MessageWithArgs {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
        #[arg(long)] n: i64,
    },
    /// Traduce múltiples IDs en una sola llamada (coma-separados).
    Batch {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long, help = "IDs separados por coma")] ids: String,
    },
    /// Lista todos los IDs de mensajes disponibles en el locale.
    ListMessages {
        #[arg(long, default_value = "es-BO")] locale: String,
    },
    /// Comprueba si existe un ID de mensaje en el locale.
    HasMessage {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
    },
    /// Traduce un atributo de mensaje (ej: `.label`, `.placeholder`).
    Attribute {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
        #[arg(long)] attribute: String,
    },
}

pub fn construir_llamada(sub: &Translate, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Translate::Message { locale, id } => (
            "bi18n.translate.message",
            json!({ "ctx_id": ctx_id, "locale": locale, "id": id }),
        ),
        Translate::MessageWithArgs { locale, id, n } => (
            "bi18n.translate.message_with_args",
            json!({ "ctx_id": ctx_id, "locale": locale, "id": id, "n": n }),
        ),
        Translate::Batch { locale, ids } => (
            "bi18n.translate.batch",
            json!({ "ctx_id": ctx_id, "locale": locale, "ids": ids }),
        ),
        Translate::ListMessages { locale } => (
            "bi18n.translate.list_messages",
            json!({ "ctx_id": ctx_id, "locale": locale }),
        ),
        Translate::HasMessage { locale, id } => (
            "bi18n.translate.has_message",
            json!({ "ctx_id": ctx_id, "locale": locale, "id": id }),
        ),
        Translate::Attribute { locale, id, attribute } => (
            "bi18n.translate.attribute",
            json!({ "ctx_id": ctx_id, "locale": locale, "id": id, "attribute": attribute }),
        ),
    }
}
