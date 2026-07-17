/// cli/mask_fase2.rs — Subcomandos bi18n.mask.* Fase 2 (A.08.08 mask-pii, 3 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum MaskFase2 {
    /// Enmascara emails en texto libre (reemplaza con ***@***.***).
    EmailInText {
        #[arg(long)] text: String,
    },
    /// Enmascara números de teléfono en texto libre.
    PhoneInText {
        #[arg(long)] text: String,
    },
    /// Enmascara datos PII (email + teléfono) en texto libre.
    Pii {
        #[arg(long)] text: String,
    },
    /// Enmascara PII reemplazando con el carácter indicado.
    PiiWithChar {
        #[arg(long)] text: String,
        #[arg(long, default_value = "*")] char: String,
    },
}

pub fn construir_llamada(sub: &MaskFase2, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        MaskFase2::EmailInText { text } => (
            "bi18n.mask.email_in_text",
            json!({ "ctx_id": ctx_id, "text": text }),
        ),
        MaskFase2::PhoneInText { text } => (
            "bi18n.mask.phone_in_text",
            json!({ "ctx_id": ctx_id, "text": text }),
        ),
        MaskFase2::Pii { text } => (
            "bi18n.mask.pii",
            json!({ "ctx_id": ctx_id, "text": text }),
        ),
        MaskFase2::PiiWithChar { text, char } => (
            "bi18n.mask.pii_with_char",
            json!({ "ctx_id": ctx_id, "text": text, "char": char }),
        ),
    }
}
