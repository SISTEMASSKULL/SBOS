/// server/handlers/lib_icu_datetime.rs — Handler A.08.03: icu_datetime 2.2.0
/// Propósito: expone los 6 métodos RPC del namespace `bi18n.format.*_icu`
///   usando DateTimeFormatter / NoCalendarFormatter de ICU4X con datos CLDR compilados.
/// Librería: icu_datetime 2.2.0 (feature: compiled_data, unstable_jiff_0_2)
/// Métodos RPC expuestos:
///   bi18n.format.datetime_icu · bi18n.format.date_icu · bi18n.format.time_icu
///   bi18n.format.weekday_name · bi18n.format.month_name · bi18n.format.datetime_with_time
/// Entrada común: ts_unix (i64 Unix segundos) + locale (BCP-47) + length (short|medium|long|full)
/// Parámetro ctx_id: validado en el dispatcher antes de llegar aquí (SBOS-049).
/// Referencia: A.08.03_INVENTARIO-LIB-ICU-DATETIME-v1.0.md · PLAN-FASE-2 §3
/// Dependencias: icu_datetime, icu_locale_core, jiff, serde_json, crate::error
use icu_datetime::{
    fieldsets,
    fieldsets::enums::{CalendarPeriodFieldSet, DateAndTimeFieldSet, DateFieldSet},
    DateTimeFormatter, DateTimeFormatterPreferences, NoCalendarFormatter,
};
use icu_locale_core::Locale;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Parsea locale BCP-47 string a DateTimeFormatterPreferences de ICU.
fn parsear_prefs(locale_str: &str) -> Result<DateTimeFormatterPreferences, Bi18nError> {
    let locale: Locale = locale_str.parse().map_err(|_| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(),
        causa: "BCP-47 inválido".to_string(),
    })?;
    Ok(DateTimeFormatterPreferences::from(&locale))
}

/// Parsea Unix timestamp (segundos) a jiff::civil::DateTime en UTC.
fn parsear_ts(ts_unix: i64) -> Result<jiff::civil::DateTime, Bi18nError> {
    let ts = jiff::Timestamp::from_second(ts_unix).map_err(|e| Bi18nError::FechaInvalida {
        valor: ts_unix.to_string(),
        causa: e.to_string(),
    })?;
    let zdt = ts.in_tz("UTC").map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: "UTC".to_string(),
        causa: e.to_string(),
    })?;
    Ok(zdt.datetime())
}

/// Devuelve el DateFieldSet::YMD para la longitud indicada.
/// Nota: "full" no existe en icu_datetime 2.2.0 — se mapea a "long".
fn ymd_por_longitud(l: &str) -> DateFieldSet {
    match l {
        "short" => DateFieldSet::YMD(fieldsets::YMD::short()),
        "long" | "full" => DateFieldSet::YMD(fieldsets::YMD::long()),
        _ => DateFieldSet::YMD(fieldsets::YMD::medium()),
    }
}

/// Formatea fecha + hora (año, mes, día, hora:min). Longitud configurable.
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "length": "medium", "ctx_id": "..." }`.
/// Salida: `{ "display": "17 jul 2026, 10:26", "locale": "es-BO" }`.
pub async fn format_datetime_icu(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let length = params["length"].as_str().unwrap_or("medium");
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = match length {
        "short" => DateAndTimeFieldSet::YMDT(fieldsets::YMDT::short()),
        "long" | "full" => DateAndTimeFieldSet::YMDT(fieldsets::YMDT::long()),
        _ => DateAndTimeFieldSet::YMDT(fieldsets::YMDT::medium()),
    };
    let fmt = DateTimeFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea solo la fecha (año, mes, día). Longitud configurable.
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "length": "long", "ctx_id": "..." }`.
/// Salida: `{ "display": "17 de julio de 2026", "locale": "es-BO" }`.
pub async fn format_date_icu(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let length = params["length"].as_str().unwrap_or("medium");
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = ymd_por_longitud(length);
    let fmt = DateTimeFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt.date()).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea solo la hora (HH:MM o HH:MM:SS). Parámetro `seconds` (bool) para incluir segundos.
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "seconds": false, "ctx_id": "..." }`.
/// Salida: `{ "display": "10:26 a. m.", "locale": "es-BO" }`.
pub async fn format_time_icu(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let con_segundos = params["seconds"].as_bool().unwrap_or(false);
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = if con_segundos { fieldsets::T::hms() } else { fieldsets::T::hm() };
    let fmt = NoCalendarFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt.time()).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Devuelve el nombre del día de semana localizado (p. ej. "martes").
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "display": "jueves", "locale": "es-BO" }`.
pub async fn format_weekday_name(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = DateFieldSet::E(fieldsets::E::long());
    let fmt = DateTimeFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt.date()).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Devuelve el nombre del mes y año localizado (p. ej. "julio de 2026").
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "display": "julio de 2026", "locale": "es-BO" }`.
pub async fn format_month_name(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = CalendarPeriodFieldSet::YM(fieldsets::YM::long());
    let fmt = DateTimeFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt.date()).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea fecha completa con día de semana y hora:min.
/// Entrada: `{ "ts_unix": 1750000000, "locale": "es-BO", "length": "long", "ctx_id": "..." }`.
/// Salida: `{ "display": "jueves, 17 de julio de 2026, 10:26 a. m.", "locale": "es-BO" }`.
pub async fn format_datetime_with_time(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let ts_unix = params["ts_unix"].as_i64().unwrap_or(0);
    let length = params["length"].as_str().unwrap_or("medium");
    let prefs = parsear_prefs(locale_str)?;
    let civil_dt = parsear_ts(ts_unix)?;
    let fset = match length {
        "short" => DateAndTimeFieldSet::YMDET(fieldsets::YMDET::short()),
        "long" | "full" => DateAndTimeFieldSet::YMDET(fieldsets::YMDET::long()),
        _ => DateAndTimeFieldSet::YMDET(fieldsets::YMDET::medium()),
    };
    let fmt = DateTimeFormatter::try_new(prefs, fset).map_err(|e| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(), causa: e.to_string(),
    })?;
    let display = fmt.format(&civil_dt).to_string();
    Ok(json!({ "display": display, "locale": locale_str }))
}
