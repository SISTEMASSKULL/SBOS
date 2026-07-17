/// cli/guard.rs — Subcomandos bi18n.guard.* (A.08.14 prism3-core 0.2, 12 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Guard {
    // ── Verificaciones de rango/índice ────────────────────────────────────
    /// Verifica que un rango [offset, offset+length) esté dentro de [0, total_length].
    CheckBounds {
        #[arg(long)] offset: usize,
        #[arg(long)] length: usize,
        #[arg(long)] total_length: usize,
    },
    /// Verifica que index sea un índice de elemento válido en una colección de tamaño size.
    CheckElementIndex {
        #[arg(long)] index: usize,
        #[arg(long)] size: usize,
    },
    /// Verifica que index sea una posición válida en una colección de tamaño size.
    CheckPositionIndex {
        #[arg(long)] index: usize,
        #[arg(long)] size: usize,
    },

    // ── Verificaciones numéricas ──────────────────────────────────────────
    /// Compara dos valores numéricos con nombre (v1 op v2).
    NumCompare {
        #[arg(long, default_value = "v1")] name1: String,
        #[arg(long, default_value = "v2")] name2: String,
        #[arg(long)] v1: f64,
    },
    /// Verifica que un número sea positivo (> 0).
    NumPositive {
        #[arg(long)] name: String,
        #[arg(long)] value: f64,
    },
    /// Verifica que un número sea no negativo (>= 0).
    NumNonNegative {
        #[arg(long)] name: String,
        #[arg(long)] value: f64,
    },
    /// Verifica que un número esté en el rango [min, max].
    NumInRange {
        #[arg(long)] name: String,
        #[arg(long)] value: f64,
        #[arg(long)] min: f64,
        #[arg(long)] max: f64,
    },

    // ── Verificaciones de string ──────────────────────────────────────────
    /// Verifica que un string no esté en blanco (no solo espacios).
    StrNonBlank {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
    },
    /// Verifica que un string tenga longitud en [min, max].
    StrLengthRange {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
        #[arg(long)] min: Option<usize>,
        #[arg(long)] max: Option<usize>,
    },
    /// Verifica que un string haga match con el patrón regex.
    StrMatch {
        #[arg(long)] name: String,
        #[arg(long)] value: String,
        #[arg(long)] pattern: String,
    },

    // ── Verificaciones de colección ───────────────────────────────────────
    /// Verifica que una colección JSON (array) no esté vacía.
    ColNonEmpty {
        #[arg(long)] name: String,
        #[arg(long, help = "Valores separados por coma", value_delimiter = ',')] value: Vec<String>,
    },
    /// Verifica que una colección tenga entre min y max elementos.
    ColLengthRange {
        #[arg(long)] name: String,
        #[arg(long, value_delimiter = ',')] value: Vec<String>,
        #[arg(long)] min: Option<usize>,
        #[arg(long)] max: Option<usize>,
    },
}

pub fn construir_llamada(sub: &Guard, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Guard::CheckBounds { offset, length, total_length } => (
            "bi18n.guard.check_bounds",
            json!({ "ctx_id": ctx_id, "offset": offset, "length": length, "total_length": total_length }),
        ),
        Guard::CheckElementIndex { index, size } => (
            "bi18n.guard.check_element_index",
            json!({ "ctx_id": ctx_id, "index": index, "size": size }),
        ),
        Guard::CheckPositionIndex { index, size } => (
            "bi18n.guard.check_position_index",
            json!({ "ctx_id": ctx_id, "index": index, "size": size }),
        ),
        Guard::NumCompare { name1, name2, v1 } => (
            "bi18n.guard.num_compare",
            json!({ "ctx_id": ctx_id, "name1": name1, "name2": name2, "v1": v1 }),
        ),
        Guard::NumPositive { name, value } => (
            "bi18n.guard.num_positive",
            json!({ "ctx_id": ctx_id, "name": name, "value": value }),
        ),
        Guard::NumNonNegative { name, value } => (
            "bi18n.guard.num_non_negative",
            json!({ "ctx_id": ctx_id, "name": name, "value": value }),
        ),
        Guard::NumInRange { name, value, min, max } => (
            "bi18n.guard.num_in_range",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "min": min, "max": max }),
        ),
        Guard::StrNonBlank { name, value } => (
            "bi18n.guard.str_non_blank",
            json!({ "ctx_id": ctx_id, "name": name, "value": value }),
        ),
        Guard::StrLengthRange { name, value, min, max } => (
            "bi18n.guard.str_length_range",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "min": min, "max": max }),
        ),
        Guard::StrMatch { name, value, pattern } => (
            "bi18n.guard.str_match",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "pattern": pattern }),
        ),
        Guard::ColNonEmpty { name, value } => (
            "bi18n.guard.col_non_empty",
            json!({ "ctx_id": ctx_id, "name": name, "value": value }),
        ),
        Guard::ColLengthRange { name, value, min, max } => (
            "bi18n.guard.col_length_range",
            json!({ "ctx_id": ctx_id, "name": name, "value": value, "min": min, "max": max }),
        ),
    }
}
