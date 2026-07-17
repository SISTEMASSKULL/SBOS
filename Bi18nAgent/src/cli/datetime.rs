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
    /// Parsea un string RFC 3339 con chrono.
    ChronoParseRfc3339 { #[arg(long)] value: String },
    /// Parsea un string RFC 2822 con chrono.
    ChronoParseRfc2822 { #[arg(long)] value: String },
    /// Convierte un Unix timestamp a string RFC 3339 (chrono).
    ChronoToRfc3339 { #[arg(long)] unix: i64 },
    /// Convierte un Unix timestamp a string RFC 2822 (chrono).
    ChronoToRfc2822 { #[arg(long)] unix: i64 },
    /// Formatea timestamp Unix con patrón strftime (chrono).
    ChronoFormat {
        #[arg(long)] unix: i64,
        #[arg(long, default_value = "%Y-%m-%d %H:%M:%S")] format: String,
    },
    /// Formatea timestamp Unix con patrón strftime localizado (chrono).
    ChronoFormatLocalized {
        #[arg(long)] unix: i64,
        #[arg(long, default_value = "%A %d %B %Y")] format: String,
        #[arg(long, default_value = "es_BO")] locale: String,
    },
    /// Convierte un string RFC 3339 a Unix timestamp (chrono).
    ChronoToUnix { #[arg(long)] value: String },
    /// Indica si una fecha (year/month/day) cae en año bisiesto (chrono).
    ChronoLeapYear {
        #[arg(long)] year: i32,
        #[arg(long)] month: u32,
        #[arg(long)] day: u32,
    },
    /// Parsea un string de fecha con formato personalizado (chrono NaiveDate).
    ChronoNaiveParse {
        #[arg(long)] value: String,
        #[arg(long, default_value = "%Y-%m-%d")] format: String,
    },
    /// Total de un TimeDelta en la unidad indicada (hours|minutes|seconds).
    ChronoTimedeltaTotal {
        #[arg(long, default_value = "0")] days: i64,
        #[arg(long, default_value = "0")] hours: i64,
        #[arg(long, default_value = "0")] minutes: i64,
        #[arg(long, default_value = "0")] seconds: i64,
        #[arg(long, default_value = "hours")] unit: String,
    },
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
        Datetime::ChronoParseRfc3339 { value } => (
            "bi18n.datetime.chrono_parse_rfc3339",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Datetime::ChronoParseRfc2822 { value } => (
            "bi18n.datetime.chrono_parse_rfc2822",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Datetime::ChronoToRfc3339 { unix } => (
            "bi18n.datetime.chrono_to_rfc3339",
            json!({ "ctx_id": ctx_id, "unix": unix }),
        ),
        Datetime::ChronoToRfc2822 { unix } => (
            "bi18n.datetime.chrono_to_rfc2822",
            json!({ "ctx_id": ctx_id, "unix": unix }),
        ),
        Datetime::ChronoFormat { unix, format } => (
            "bi18n.datetime.chrono_format",
            json!({ "ctx_id": ctx_id, "unix": unix, "format": format }),
        ),
        Datetime::ChronoFormatLocalized { unix, format, locale } => (
            "bi18n.datetime.chrono_format_localized",
            json!({ "ctx_id": ctx_id, "unix": unix, "format": format, "locale": locale }),
        ),
        Datetime::ChronoToUnix { value } => (
            "bi18n.datetime.chrono_to_unix",
            json!({ "ctx_id": ctx_id, "value": value }),
        ),
        Datetime::ChronoLeapYear { year, month, day } => (
            "bi18n.datetime.chrono_leap_year",
            json!({ "ctx_id": ctx_id, "year": year, "month": month, "day": day }),
        ),
        Datetime::ChronoNaiveParse { value, format } => (
            "bi18n.datetime.chrono_naive_parse",
            json!({ "ctx_id": ctx_id, "value": value, "format": format }),
        ),
        Datetime::ChronoTimedeltaTotal { days, hours, minutes, seconds, unit } => (
            "bi18n.datetime.chrono_timedelta_total",
            json!({ "ctx_id": ctx_id, "days": days, "hours": hours, "minutes": minutes, "seconds": seconds, "unit": unit }),
        ),
    }
}
