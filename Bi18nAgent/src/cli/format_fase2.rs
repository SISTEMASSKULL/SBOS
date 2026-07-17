/// cli/format_fase2.rs — Subcomandos bi18n.format.* Fase 2.
/// Cubre: icu_datetime (6), icu_decimal (4), universal_mask (5) — total 15.
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum FormatFase2 {
    // ── ICU datetime (A.08.03) ────────────────────────────────────────────
    /// Formatea fecha y hora completa con ICU (locale CLDR).
    DatetimeIcu {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long, help = "Unix timestamp segundos")] ts_unix: i64,
    },
    /// Formatea solo la fecha con ICU.
    DateIcu {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] ts_unix: i64,
    },
    /// Formatea solo la hora con ICU.
    TimeIcu {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] ts_unix: i64,
    },
    /// Nombre del día de la semana localizado (lunes, Monday…).
    WeekdayName {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] ts_unix: i64,
    },
    /// Nombre del mes localizado (enero, January…).
    MonthName {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] ts_unix: i64,
    },
    /// Fecha+hora con zona horaria explícita (ICU).
    DatetimeWithTimezone {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "America/La_Paz")] tz: String,
    },

    // ── ICU decimal (A.08.05) ─────────────────────────────────────────────
    /// Formatea número con agrupación CLDR por locale.
    NumberIcu {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] number: String,
    },
    /// Formatea número sin agrupación de miles.
    NumberNoGrouping {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] number: String,
    },
    /// Formatea número siempre con agrupación de miles.
    NumberGroupingAlways {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] number: String,
    },
    /// Formatea número con agrupación mínimo 2 dígitos en grupo.
    NumberGroupingMin2 {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] number: String,
    },

    // ── universal_mask (A.08.09) ──────────────────────────────────────────
    /// Aplica máscara estructural con patrón X (ej: "(XXX) XXX-XXXX").
    StructuralMask {
        #[arg(long)] text: String,
        #[arg(long, help = "Patrón con X como comodín")] pattern: String,
    },
    /// Enmascara número de Seguro Social (XXX-XX-XXXX → ***-**-6789).
    MaskSsn {
        #[arg(long)] ssn: String,
    },
    /// Enmascara número de tarjeta (solo últimos 4 dígitos visibles).
    MaskCard {
        #[arg(long)] card: String,
    },
    /// Enmascara fecha ISO (YYYY-MM-DD → ****-MM-DD).
    MaskDateIso {
        #[arg(long)] date: String,
    },
    /// Enmascara carnet de identidad boliviano (primeros dígitos ocultos).
    MaskCiBo {
        #[arg(long)] ci: String,
    },
}

pub fn construir_llamada(sub: &FormatFase2, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        FormatFase2::DatetimeIcu { locale, ts_unix } => (
            "bi18n.format.datetime_icu",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix }),
        ),
        FormatFase2::DateIcu { locale, ts_unix } => (
            "bi18n.format.date_icu",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix }),
        ),
        FormatFase2::TimeIcu { locale, ts_unix } => (
            "bi18n.format.time_icu",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix }),
        ),
        FormatFase2::WeekdayName { locale, ts_unix } => (
            "bi18n.format.weekday_name",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix }),
        ),
        FormatFase2::MonthName { locale, ts_unix } => (
            "bi18n.format.month_name",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix }),
        ),
        FormatFase2::DatetimeWithTimezone { locale, ts_unix, tz } => (
            "bi18n.format.datetime_with_timezone",
            json!({ "ctx_id": ctx_id, "locale": locale, "ts_unix": ts_unix, "tz": tz }),
        ),
        FormatFase2::NumberIcu { locale, number } => (
            "bi18n.format.number_icu",
            json!({ "ctx_id": ctx_id, "locale": locale, "number": number }),
        ),
        FormatFase2::NumberNoGrouping { locale, number } => (
            "bi18n.format.number_no_grouping",
            json!({ "ctx_id": ctx_id, "locale": locale, "number": number }),
        ),
        FormatFase2::NumberGroupingAlways { locale, number } => (
            "bi18n.format.number_grouping_always",
            json!({ "ctx_id": ctx_id, "locale": locale, "number": number }),
        ),
        FormatFase2::NumberGroupingMin2 { locale, number } => (
            "bi18n.format.number_grouping_min2",
            json!({ "ctx_id": ctx_id, "locale": locale, "number": number }),
        ),
        FormatFase2::StructuralMask { text, pattern } => (
            "bi18n.format.structural_mask",
            json!({ "ctx_id": ctx_id, "text": text, "pattern": pattern }),
        ),
        FormatFase2::MaskSsn { ssn } => (
            "bi18n.format.mask_ssn",
            json!({ "ctx_id": ctx_id, "ssn": ssn }),
        ),
        FormatFase2::MaskCard { card } => (
            "bi18n.format.mask_card",
            json!({ "ctx_id": ctx_id, "card": card }),
        ),
        FormatFase2::MaskDateIso { date } => (
            "bi18n.format.mask_date_iso",
            json!({ "ctx_id": ctx_id, "date": date }),
        ),
        FormatFase2::MaskCiBo { ci } => (
            "bi18n.format.mask_ci_bo",
            json!({ "ctx_id": ctx_id, "ci": ci }),
        ),
    }
}
