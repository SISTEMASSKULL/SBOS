/// server/handlers/lib_chrono.rs — Handler A.08.11: chrono 0.4.45
/// Propósito: expone 10 métodos RPC del namespace `bi18n.datetime.chrono_*`
///   usando los tipos DateTime, NaiveDate y TimeDelta de chrono.
/// Librería: chrono 0.4.45 (features: serde, unstable-locales)
/// Métodos RPC expuestos:
///   chrono_parse_rfc3339 · chrono_parse_rfc2822 · chrono_to_rfc3339
///   chrono_to_rfc2822 · chrono_format · chrono_format_localized
///   chrono_to_unix · chrono_leap_year · chrono_naive_parse
///   chrono_timedelta_total
/// Complementa a jiff (A.08.10): chrono cubre RFC3339/RFC2822 y formateo localizado.
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049).
/// Referencia: A.08.11_INVENTARIO-LIB-CHRONO-v1.0.md · PLAN-FASE-2 §11
/// Dependencias: chrono, serde_json, crate::error
use chrono::{DateTime, Locale, NaiveDate, TimeDelta, Utc};
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Crea DateTime<Utc> desde Unix seconds o devuelve error.
fn dt_desde_unix(params: &Value) -> Result<DateTime<Utc>, Bi18nError> {
    let secs = params["unix"].as_i64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "unix".to_string() })?;
    DateTime::from_timestamp(secs, 0).ok_or_else(|| Bi18nError::FechaInvalida {
        valor: secs.to_string(),
        causa: "timestamp fuera de rango".to_string(),
    })
}

/// Parsea un timestamp RFC 3339 y retorna Unix seconds.
/// Entrada: `{ "value": "2026-07-16T14:00:00+00:00", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string }`.
pub async fn chrono_parse_rfc3339(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let dt = DateTime::parse_from_rfc3339(s).map_err(|e| Bi18nError::FechaInvalida {
        valor: s.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": dt.timestamp(), "iso": dt.to_rfc3339() }))
}

/// Parsea un timestamp RFC 2822 y retorna Unix seconds.
/// Entrada: `{ "value": "Thu, 16 Jul 2026 14:00:00 +0000", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64 }`.
pub async fn chrono_parse_rfc2822(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let dt = DateTime::parse_from_rfc2822(s).map_err(|e| Bi18nError::FechaInvalida {
        valor: s.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": dt.timestamp(), "iso": dt.to_rfc2822() }))
}

/// Convierte Unix seconds a formato RFC 3339 (ISO 8601 con offset UTC).
/// Entrada: `{ "unix": 1752000000, "ctx_id": "..." }`.
/// Salida: `{ "rfc3339": string }`.
pub async fn chrono_to_rfc3339(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let dt = dt_desde_unix(params)?;
    Ok(json!({ "rfc3339": dt.to_rfc3339() }))
}

/// Convierte Unix seconds a formato RFC 2822 (email date format).
/// Entrada: `{ "unix": 1752000000, "ctx_id": "..." }`.
/// Salida: `{ "rfc2822": string }`.
pub async fn chrono_to_rfc2822(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let dt = dt_desde_unix(params)?;
    Ok(json!({ "rfc2822": dt.to_rfc2822() }))
}

/// Formatea un timestamp Unix con formato strftime.
/// Entrada: `{ "unix": 1752000000, "format": "%d/%m/%Y %H:%M:%S", "ctx_id": "..." }`.
/// Salida: `{ "display": string }`.
pub async fn chrono_format(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let dt = dt_desde_unix(params)?;
    let fmt = params["format"].as_str().unwrap_or("%Y-%m-%d %H:%M:%S");
    Ok(json!({ "display": dt.format(fmt).to_string() }))
}

/// Formatea un timestamp con nombres de días/meses localizados (feature unstable-locales).
/// El campo `locale` debe ser en formato POSIX con guión bajo (ej: "es_BO", "pt_BR").
/// Entrada: `{ "unix": i64, "format": "%A, %d de %B de %Y", "locale": "es_ES", "ctx_id": "..." }`.
/// Salida: `{ "display": "jueves, 16 de julio de 2026" }`.
pub async fn chrono_format_localized(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let dt = dt_desde_unix(params)?;
    let fmt = params["format"].as_str().unwrap_or("%A %d %B %Y");
    let locale_str = params["locale"].as_str().unwrap_or("es_BO");
    let locale_normalized = locale_str.replace('-', "_");
    let locale: Locale = locale_normalized.parse().unwrap_or(Locale::POSIX);
    Ok(json!({ "display": dt.format_localized(fmt, locale).to_string() }))
}

/// Parsea una cadena RFC3339 y retorna Unix seconds.
/// Útil para convertir strings de fecha a epoch para comparaciones.
/// Entrada: `{ "value": "2026-07-16T00:00:00Z", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64 }`.
pub async fn chrono_to_unix(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let dt = DateTime::parse_from_rfc3339(s).map_err(|e| Bi18nError::FechaInvalida {
        valor: s.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": dt.timestamp() }))
}

/// Indica si el año de la fecha dada es bisiesto.
/// Entrada: `{ "year": 2024, "month": 1, "day": 1, "ctx_id": "..." }`.
/// Salida: `{ "leap": bool }`.
pub async fn chrono_leap_year(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let year  = params["year"].as_i64().unwrap_or(2024) as i32;
    let month = params["month"].as_u64().unwrap_or(1) as u32;
    let day   = params["day"].as_u64().unwrap_or(1) as u32;
    let date = NaiveDate::from_ymd_opt(year, month, day)
        .ok_or_else(|| Bi18nError::FechaInvalida {
            valor: format!("{year}-{month:02}-{day:02}"),
            causa: "fecha inválida".to_string(),
        })?;
    Ok(json!({ "leap": date.leap_year() }))
}

/// Parsea una fecha en formato strftime a una cadena ISO.
/// Entrada: `{ "value": "16/07/2026", "format": "%d/%m/%Y", "ctx_id": "..." }`.
/// Salida: `{ "date": "2026-07-16" }`.
pub async fn chrono_naive_parse(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let fmt = params["format"].as_str().unwrap_or("%Y-%m-%d");
    let date = NaiveDate::parse_from_str(s, fmt).map_err(|e| Bi18nError::FechaInvalida {
        valor: s.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "date": date.to_string() }))
}

/// Calcula el total de un TimeDelta en la unidad indicada.
/// Entrada: `{ "days": 2, "hours": 12, "unit": "hours", "ctx_id": "..." }`.
/// Salida: `{ "total": 60, "unit": "hours" }`.
pub async fn chrono_timedelta_total(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let mut td = TimeDelta::zero();
    if let Some(d) = params["days"].as_i64()    { td = td + TimeDelta::try_days(d).unwrap_or_default(); }
    if let Some(h) = params["hours"].as_i64()   { td = td + TimeDelta::try_hours(h).unwrap_or_default(); }
    if let Some(m) = params["minutes"].as_i64() { td = td + TimeDelta::try_minutes(m).unwrap_or_default(); }
    if let Some(s) = params["seconds"].as_i64() { td = td + TimeDelta::try_seconds(s).unwrap_or_default(); }
    let unit_str = params["unit"].as_str().unwrap_or("hours");
    let total: i64 = match unit_str {
        "days"    => td.num_days(),
        "minutes" => td.num_minutes(),
        "seconds" => td.num_seconds(),
        _         => td.num_hours(),
    };
    Ok(json!({ "total": total, "unit": unit_str }))
}
