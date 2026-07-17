/// cli/phone.rs — Subcomandos bi18n.phone.* (A.08.13 phonenumber 0.3, 8 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Phone {
    /// Formatea el teléfono en el modo indicado (e164|national|international|rfc3966).
    Format {
        #[arg(long)] phone: String,
        #[arg(long, default_value = "national")] mode: String,
    },
    /// Devuelve el tipo de número (Mobile, FixedLine, TollFree…).
    Type {
        #[arg(long)] phone: String,
    },
    /// Comprueba si el número es viable (longitud + prefijo válidos).
    IsViable {
        #[arg(long)] phone: String,
    },
    /// Devuelve información completa del número (tipo, región, código de país).
    Info {
        #[arg(long)] phone: String,
    },
    /// Parsea y normaliza el número en formato E.164 (+591XXXXXXXX).
    ParseE164 {
        #[arg(long)] phone: String,
    },
    /// Parsea el número en formato nacional (requiere región ISO 3166-1).
    ParseNational {
        #[arg(long)] phone: String,
        #[arg(long, default_value = "BO")] region: String,
    },
    /// Parsea y devuelve el número en formato URI tel: (RFC 3966).
    ParseRfc3966 {
        #[arg(long)] phone: String,
    },
    /// Extrae el código de país numérico (ej: 591 para Bolivia).
    CountryCode {
        #[arg(long)] phone: String,
    },
}

pub fn construir_llamada(sub: &Phone, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Phone::Format { phone, mode } => (
            "bi18n.phone.format",
            json!({ "ctx_id": ctx_id, "phone": phone, "mode": mode }),
        ),
        Phone::Type { phone } => (
            "bi18n.phone.type",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
        Phone::IsViable { phone } => (
            "bi18n.phone.is_viable",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
        Phone::Info { phone } => (
            "bi18n.phone.info",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
        Phone::ParseE164 { phone } => (
            "bi18n.phone.parse_e164",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
        Phone::ParseNational { phone, region } => (
            "bi18n.phone.parse_national",
            json!({ "ctx_id": ctx_id, "phone": phone, "region": region }),
        ),
        Phone::ParseRfc3966 { phone } => (
            "bi18n.phone.parse_rfc3966",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
        Phone::CountryCode { phone } => (
            "bi18n.phone.country_code",
            json!({ "ctx_id": ctx_id, "phone": phone }),
        ),
    }
}
