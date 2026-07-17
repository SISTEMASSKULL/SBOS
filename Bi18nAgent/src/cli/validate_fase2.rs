/// cli/validate_fase2.rs — Subcomandos bi18n.validate.* Fase 2.
/// Cubre: validator 0.19 (12) + scrutiny 0.1.2 (6) — total 18.
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum ValidateFase2 {
    // ── validator (A.08.06) ───────────────────────────────────────────────
    /// Valida email según HTML5 / RFC 5322.
    EmailHtml5 { #[arg(long)] value: String },
    /// Valida una URL (http/https).
    Url { #[arg(long)] value: String },
    /// Valida dirección IP (v4 o v6).
    Ip { #[arg(long)] value: String },
    /// Valida dirección IPv4.
    Ipv4 { #[arg(long)] value: String },
    /// Valida dirección IPv6.
    Ipv6 { #[arg(long)] value: String },
    /// Valida longitud de string (caracteres Unicode).
    Length {
        #[arg(long)] value: String,
        #[arg(long)] min: Option<u64>,
        #[arg(long)] max: Option<u64>,
    },
    /// Valida que un número esté en un rango (inclusivo).
    Range {
        #[arg(long)] value: f64,
        #[arg(long)] min: Option<f64>,
        #[arg(long)] max: Option<f64>,
    },
    /// Valida que un string contenga la subcadena indicada.
    Contains {
        #[arg(long)] value: String,
        #[arg(long)] needle: String,
    },
    /// Valida que un string NO contenga la subcadena indicada.
    NotContains {
        #[arg(long)] value: String,
        #[arg(long)] needle: String,
    },
    /// Valida que el valor no sea vacío/null.
    Required { #[arg(long)] value: String },
    /// Valida número de tarjeta de crédito (Luhn).
    CreditCard { #[arg(long)] value: String },
    /// Valida que dos strings sean iguales.
    MustMatch {
        #[arg(long)] a: String,
        #[arg(long)] b: String,
    },

    // ── scrutiny (A.08.07) ────────────────────────────────────────────────
    /// Valida que el valor sea un UUID válido.
    Uuid { #[arg(long)] value: String },
    /// Valida que el valor sea un ULID válido.
    Ulid { #[arg(long)] value: String },
    /// Valida que el valor sea una dirección MAC válida.
    MacAddress { #[arg(long)] value: String },
    /// Valida que el valor sea un color hexadecimal (#RRGGBB o #RGB).
    HexColor { #[arg(long)] value: String },
    /// Valida que el valor sea una zona horaria IANA válida.
    Timezone { #[arg(long)] value: String },
    /// Valida que el valor sea JSON bien formado.
    IsJson { #[arg(long)] value: String },
}

pub fn construir_llamada(sub: &ValidateFase2, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        ValidateFase2::EmailHtml5 { value } => (
            "bi18n.validate.email_html5",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Url { value } => (
            "bi18n.validate.url",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Ip { value } => (
            "bi18n.validate.ip",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Ipv4 { value } => (
            "bi18n.validate.ipv4",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Ipv6 { value } => (
            "bi18n.validate.ipv6",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Length { value, min, max } => (
            "bi18n.validate.length",
            json!({ "ctx_id": ctx_id, "value": value, "min": min, "max": max }),
        ),
        ValidateFase2::Range { value, min, max } => (
            "bi18n.validate.range",
            json!({ "ctx_id": ctx_id, "value": value, "min": min, "max": max }),
        ),
        ValidateFase2::Contains { value, needle } => (
            "bi18n.validate.contains",
            json!({ "ctx_id": ctx_id, "value": value, "needle": needle }),
        ),
        ValidateFase2::NotContains { value, needle } => (
            "bi18n.validate.not_contains",
            json!({ "ctx_id": ctx_id, "value": value, "needle": needle }),
        ),
        ValidateFase2::Required { value } => (
            "bi18n.validate.required",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::CreditCard { value } => (
            "bi18n.validate.credit_card",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::MustMatch { a, b } => (
            "bi18n.validate.must_match",
            json!({ "ctx_id": ctx_id, "a": a, "b": b }),
        ),
        ValidateFase2::Uuid { value } => (
            "bi18n.validate.uuid",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Ulid { value } => (
            "bi18n.validate.ulid",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::MacAddress { value } => (
            "bi18n.validate.mac_address",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::HexColor { value } => (
            "bi18n.validate.hex_color",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::Timezone { value } => (
            "bi18n.validate.timezone",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        ValidateFase2::IsJson { value } => (
            "bi18n.validate.is_json",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
    }
}
