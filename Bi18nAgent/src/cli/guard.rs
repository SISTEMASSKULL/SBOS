/// cli/guard.rs — Subcomandos bi18n.guard.* (A.08.14 prism3-core 0.2, 12 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Guard {
    /// Verifica que un número esté en el rango [min, max].
    NumInRange {
        #[arg(long)] name: String,
        #[arg(long)] value: f64,
        #[arg(long)] min: f64,
        #[arg(long)] max: f64,
    },
    /// Verifica que un string no esté vacío.
    StrNonEmpty {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
    },
    /// Verifica que un string haga match con el patrón regex.
    StrMatch {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
        #[arg(long)] pattern: String,
    },
    /// Verifica que un string tenga longitud en [min, max].
    StrLength {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
        #[arg(long)] min: Option<usize>,
        #[arg(long)] max: Option<usize>,
    },
    /// Verifica que una colección (coma-separada) no esté vacía.
    ColNonEmpty {
        #[arg(long)] name: String,
        #[arg(long, help = "Valores separados por coma")] values: String,
    },
    /// Verifica que una colección tenga entre min y max elementos.
    ColSize {
        #[arg(long)] name: String,
        #[arg(long)] values: String,
        #[arg(long)] min: Option<usize>,
        #[arg(long)] max: Option<usize>,
    },
    /// Verifica que todos los elementos de la colección sean únicos.
    ColUnique {
        #[arg(long)] name: String,
        #[arg(long)] values: String,
    },
    /// Verifica que todos los elementos de la colección hagan match con el patrón.
    ColAllMatch {
        #[arg(long)] name: String,
        #[arg(long)] values: String,
        #[arg(long)] pattern: String,
    },
    /// Verifica que una fecha ISO 8601 sea válida.
    DateValid {
        #[arg(long)] value: String,
    },
    /// Verifica que una fecha no sea en el pasado.
    DateNotPast {
        #[arg(long)] value: String,
    },
    /// Verifica que una fecha no sea en el futuro.
    DateNotFuture {
        #[arg(long)] value: String,
    },
    /// Verifica que una fecha esté en el rango [min, max] (formato ISO 8601).
    DateInRange {
        #[arg(long)] value: String,
        #[arg(long)] min: String,
        #[arg(long)] max: String,
    },
}

pub fn construir_llamada(sub: &Guard, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Guard::NumInRange { name, value, min, max } => (
            "bi18n.guard.num_in_range",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "min": min, "max": max }),
        ),
        Guard::StrNonEmpty { name, value } => (
            "bi18n.guard.str_non_empty",
            json!({ "ctx_id": ctx_id, "name": name, "value": value }),
        ),
        Guard::StrMatch { name, value, pattern } => (
            "bi18n.guard.str_match",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "pattern": pattern }),
        ),
        Guard::StrLength { name, value, min, max } => (
            "bi18n.guard.str_length",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "min": min, "max": max }),
        ),
        Guard::ColNonEmpty { name, values } => (
            "bi18n.guard.col_non_empty",
            json!({ "ctx_id": ctx_id, "name": name, "values": values }),
        ),
        Guard::ColSize { name, values, min, max } => (
            "bi18n.guard.col_size",
            json!({ "ctx_id": ctx_id, "name": name, "values": values, "min": min, "max": max }),
        ),
        Guard::ColUnique { name, values } => (
            "bi18n.guard.col_unique",
            json!({ "ctx_id": ctx_id, "name": name, "values": values }),
        ),
        Guard::ColAllMatch { name, values, pattern } => (
            "bi18n.guard.col_all_match",
            json!({ "ctx_id": ctx_id, "name": name, "values": values, "pattern": pattern }),
        ),
        Guard::DateValid { value } => (
            "bi18n.guard.date_valid",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Guard::DateNotPast { value } => (
            "bi18n.guard.date_not_past",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Guard::DateNotFuture { value } => (
            "bi18n.guard.date_not_future",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Guard::DateInRange { value, min, max } => (
            "bi18n.guard.date_in_range",
            json!({ "ctx_id": ctx_id, "value": value, "min": min, "max": max }),
        ),
    }
}
