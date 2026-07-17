/// cli/datetime.rs — Subcomandos bi18n.datetime.* (A.08.10 jiff 17 + A.08.11 chrono 10).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum Datetime {
    // ── jiff (A.08.10) ────────────────────────────────────────────────────
    /// Fecha y hora actual en UTC (jiff).
    NowUtc,
    /// Fecha y hora actual en la zona horaria indicada (jiff).
    NowTz { #[arg(long, default_value = "America/La_Paz")] tz: String },
    /// Parsea un string de fecha/hora con zona horaria (jiff).
    ParseJiff {
        #[arg(long)] datetime: String,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Formatea un timestamp Unix con patrón strftime (jiff).
    FormatJiff {
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "%Y-%m-%d")] format: String,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Suma un span de tiempo a un timestamp.
    AddSpan {
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "0")] days: i64,
        #[arg(long, default_value = "0")] hours: i64,
        #[arg(long, default_value = "0")] minutes: i64,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Resta un span de tiempo a un timestamp.
    SubSpan {
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "0")] days: i64,
        #[arg(long, default_value = "0")] hours: i64,
        #[arg(long, default_value = "0")] minutes: i64,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Diferencia entre dos timestamps como span (jiff).
    DiffSpan {
        #[arg(long)] from: i64,
        #[arg(long)] to: i64,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Convierte un timestamp de una zona horaria a otra.
    ConvertTz {
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "UTC")] from: String,
        #[arg(long)] to: String,
    },
    /// Convierte un Unix timestamp a objeto de fecha/hora jiff.
    FromUnix { #[arg(long)] ts: i64 },
    /// Redondea un timestamp a la unidad indicada (second|minute|hour|day).
    Round {
        #[arg(long)] ts_unix: i64,
        #[arg(long, default_value = "hour")] unit: String,
        #[arg(long, default_value = "UTC")] tz: String,
    },
    /// Número de días del mes de un año/mes dado.
    DaysInMonth {
        #[arg(long)] year: i32,
        #[arg(long)] month: u8,
    },
    /// Indica si un año es bisiesto.
    IsLeapYear { #[arg(long)] year: i32 },
    /// Primer día del mes indicado.
    FirstOfMonth {
        #[arg(long)] year: i32,
        #[arg(long)] month: u8,
    },
    /// N-ésimo día de la semana en el mes (ej: 2do lunes de julio).
    NthWeekday {
        #[arg(long)] year: i32,
        #[arg(long)] month: u8,
        #[arg(long, help = "Monday|Tuesday|…|Sunday")] weekday: String,
        #[arg(long)] n: u8,
    },
    /// Genera una serie de timestamps desde `from_unix` con paso `step_days`.
    Series {
        #[arg(long)] from_unix: i64,
        #[arg(long, default_value = "UTC")] tz: String,
        #[arg(long, default_value = "1")] step_days: i64,
        #[arg(long, default_value = "7")] count: usize,
    },
    /// Total de la diferencia en la unidad indicada (hours|minutes|seconds).
    SpanTotal {
        #[arg(long)] from: i64,
        #[arg(long)] to: i64,
        #[arg(long, default_value = "hours")] unit: String,
    },
    /// Información de zona horaria (offset UTC, nombre, DST activo).
    TzInfo { #[arg(long)] tz: String },
    /// Día de la semana de un timestamp (lunes=1 … domingo=7).
    WeekdayOfDate { #[arg(long)] ts_unix: i64 },

    // ── chrono (A.08.11) ──────────────────────────────────────────────────
    /// Fecha y hora actual UTC (chrono).
    ChronoNowUtc,
    /// Fecha y hora actual en local (chrono).
    ChronoNowLocal,
    /// Parsea un string ISO 8601 con chrono.
    ChronoParseIso { #[arg(long)] datetime: String },
    /// Formatea timestamp Unix con patrón strftime (chrono).
    ChronoFormatStrftime {
        #[arg(long)] unix: i64,
        #[arg(long, default_value = "%Y-%m-%d")] format: String,
    },
    /// Formatea timestamp Unix como RFC 3339 (chrono).
    ChronoFormatRfc3339 { #[arg(long)] unix: i64 },
    /// Formatea timestamp Unix como RFC 2822 (chrono).
    ChronoFormatRfc2822 { #[arg(long)] unix: i64 },
    /// Suma días a un timestamp Unix (chrono).
    ChronoAddDays { #[arg(long)] unix: i64, #[arg(long)] days: i64 },
    /// Resta días a un timestamp Unix (chrono).
    ChronoSubDays { #[arg(long)] unix: i64, #[arg(long)] days: i64 },
    /// Suma segundos a un timestamp Unix (chrono).
    ChronoAddSeconds { #[arg(long)] unix: i64, #[arg(long)] seconds: i64 },
    /// Diferencia en segundos entre dos timestamps Unix (chrono).
    ChronoDiffSeconds { #[arg(long)] from: i64, #[arg(long)] to: i64 },
}

pub fn construir_llamada(sub: &Datetime, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        Datetime::NowUtc => ("bi18n.datetime.now_utc", json!({ "ctx_id": ctx_id })),
        Datetime::NowTz { tz } => ("bi18n.datetime.now_tz", json!({ "ctx_id": ctx_id, "tz": tz })),
        Datetime::ParseJiff { datetime, tz } => (
            "bi18n.datetime.parse_jiff",
            json!({ "ctx_id": ctx_id, "datetime": datetime, "tz": tz }),
        ),
        Datetime::FormatJiff { ts_unix, format, tz } => (
            "bi18n.datetime.format_jiff",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix, "format": format, "tz": tz }),
        ),
        Datetime::AddSpan { ts_unix, days, hours, minutes, tz } => (
            "bi18n.datetime.add_span",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix, "days": days, "hours": hours, "minutes": minutes, "tz": tz }),
        ),
        Datetime::SubSpan { ts_unix, days, hours, minutes, tz } => (
            "bi18n.datetime.sub_span",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix, "days": days, "hours": hours, "minutes": minutes, "tz": tz }),
        ),
        Datetime::DiffSpan { from, to, tz } => (
            "bi18n.datetime.diff_span",
            json!({ "ctx_id": ctx_id, "from": from, "to": to, "tz": tz }),
        ),
        Datetime::ConvertTz { ts_unix, from, to } => (
            "bi18n.datetime.convert_tz",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix, "from": from, "to": to }),
        ),
        Datetime::FromUnix { ts } => (
            "bi18n.datetime.from_unix",
            json!({ "ctx_id": ctx_id, "ts": ts }),
        ),
        Datetime::Round { ts_unix, unit, tz } => (
            "bi18n.datetime.round",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix, "unit": unit, "tz": tz }),
        ),
        Datetime::DaysInMonth { year, month } => (
            "bi18n.datetime.days_in_month",
            json!({ "ctx_id": ctx_id, "year": year, "month": month }),
        ),
        Datetime::IsLeapYear { year } => (
            "bi18n.datetime.is_leap_year",
            json!({ "ctx_id": ctx_id, "year": year }),
        ),
        Datetime::FirstOfMonth { year, month } => (
            "bi18n.datetime.first_of_month",
            json!({ "ctx_id": ctx_id, "year": year, "month": month }),
        ),
        Datetime::NthWeekday { year, month, weekday, n } => (
            "bi18n.datetime.nth_weekday",
            json!({ "ctx_id": ctx_id, "year": year, "month": month, "weekday": weekday, "n": n }),
        ),
        Datetime::Series { from_unix, tz, step_days, count } => (
            "bi18n.datetime.series",
            json!({ "ctx_id": ctx_id, "from_unix": from_unix, "tz": tz, "step_days": step_days, "count": count }),
        ),
        Datetime::SpanTotal { from, to, unit } => (
            "bi18n.datetime.span_total",
            json!({ "ctx_id": ctx_id, "from": from, "to": to, "unit": unit }),
        ),
        Datetime::TzInfo { tz } => (
            "bi18n.datetime.tz_info",
            json!({ "ctx_id": ctx_id, "tz": tz }),
        ),
        Datetime::WeekdayOfDate { ts_unix } => (
            "bi18n.datetime.weekday_of_date",
            json!({ "ctx_id": ctx_id, "ts_unix": ts_unix }),
        ),
        Datetime::ChronoNowUtc => ("bi18n.datetime.chrono_now_utc", json!({ "ctx_id": ctx_id })),
        Datetime::ChronoNowLocal => ("bi18n.datetime.chrono_now_local", json!({ "ctx_id": ctx_id })),
        Datetime::ChronoParseIso { datetime } => (
            "bi18n.datetime.chrono_parse_iso",
            json!({ "ctx_id": ctx_id, "datetime": datetime }),
        ),
        Datetime::ChronoFormatStrftime { unix, format } => (
            "bi18n.datetime.chrono_format_strftime",
            json!({ "ctx_id": ctx_id, "unix": unix, "format": format }),
        ),
        Datetime::ChronoFormatRfc3339 { unix } => (
            "bi18n.datetime.chrono_format_rfc3339",
            json!({ "ctx_id": ctx_id, "unix": unix }),
        ),
        Datetime::ChronoFormatRfc2822 { unix } => (
            "bi18n.datetime.chrono_format_rfc2822",
            json!({ "ctx_id": ctx_id, "unix": unix }),
        ),
        Datetime::ChronoAddDays { unix, days } => (
            "bi18n.datetime.chrono_add_days",
            json!({ "ctx_id": ctx_id, "unix": unix, "days": days }),
        ),
        Datetime::ChronoSubDays { unix, days } => (
            "bi18n.datetime.chrono_sub_days",
            json!({ "ctx_id": ctx_id, "unix": unix, "days": days }),
        ),
        Datetime::ChronoAddSeconds { unix, seconds } => (
            "bi18n.datetime.chrono_add_seconds",
            json!({ "ctx_id": ctx_id, "unix": unix, "seconds": seconds }),
        ),
        Datetime::ChronoDiffSeconds { from, to } => (
            "bi18n.datetime.chrono_diff_seconds",
            json!({ "ctx_id": ctx_id, "from": from, "to": to }),
        ),
    }
}
