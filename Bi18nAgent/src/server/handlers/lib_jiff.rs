/// server/handlers/lib_jiff.rs — Handler A.08.10: jiff 0.2.32
/// Propósito: expone 17 métodos RPC del namespace `bi18n.datetime.*`
///   usando los tipos Timestamp, Zoned, civil::Date, Span y TimeZone de jiff.
/// Librería: jiff 0.2.32 (features: tzdb-bundle-platform, serde)
/// Métodos RPC expuestos:
///   now_utc · now_tz · parse_jiff · from_unix · format_jiff · series
///   add_span · sub_span · diff_span · convert_tz · round · weekday_of_date
///   days_in_month · is_leap_year · nth_weekday · span_total · tz_info
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049).
/// Timestamps de entrada/salida: Unix seconds (i64) salvo donde se indique.
/// Referencia: A.08.10_INVENTARIO-LIB-JIFF-v1.0.md · PLAN-FASE-2 §10
/// Dependencias: jiff, serde_json, crate::error
use jiff::{civil, Span, Timestamp, Zoned, Unit, ZonedRound, tz::TimeZone};
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Construye un Span desde los campos opcionales del JSON: days, hours, minutes, seconds.
fn span_desde_params(params: &Value) -> Span {
    let mut s = Span::new();
    if let Some(v) = params["days"].as_i64()    { s = s.days(v); }
    if let Some(v) = params["hours"].as_i64()   { s = s.hours(v); }
    if let Some(v) = params["minutes"].as_i64() { s = s.minutes(v); }
    if let Some(v) = params["seconds"].as_i64() { s = s.seconds(v); }
    s
}

/// Convierte nombre de unidad de tiempo a `Unit` de jiff.
fn unit_desde_str(u: &str) -> Option<Unit> {
    match u {
        "years" | "year"     => Some(Unit::Year),
        "months" | "month"   => Some(Unit::Month),
        "weeks" | "week"     => Some(Unit::Week),
        "days" | "day"       => Some(Unit::Day),
        "hours" | "hour"     => Some(Unit::Hour),
        "minutes" | "minute" => Some(Unit::Minute),
        "seconds" | "second" => Some(Unit::Second),
        _ => None,
    }
}

/// Parsea un timestamp Unix (segundos) desde JSON o devuelve error.
fn ts_desde_unix(params: &Value) -> Result<Timestamp, Bi18nError> {
    let secs = params["unix"].as_i64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "unix".to_string() })?;
    Timestamp::from_second(secs).map_err(|e| Bi18nError::FechaInvalida {
        valor: secs.to_string(),
        causa: e.to_string(),
    })
}

/// Retorna el timestamp UTC actual como Unix seconds.
pub async fn now_utc(_ctx: &ServerContext, _p: &Value) -> Result<Value, Bi18nError> {
    let ts = Timestamp::now();
    Ok(json!({ "unix": ts.as_second(), "iso": ts.to_string() }))
}

/// Retorna el instante actual en la zona horaria IANA indicada.
/// Entrada: `{ "tz": "America/La_Paz", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string, "offset": string }`.
pub async fn now_tz(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let zdt = Timestamp::now().to_zoned(tz);
    Ok(json!({ "unix": zdt.timestamp().as_second(), "iso": zdt.to_string() }))
}

/// Parsea un timestamp desde formato strftime.
/// Entrada: `{ "format": "%Y-%m-%dT%H:%M:%S", "value": "2026-07-16T14:00:00", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64 }`.
pub async fn parse_jiff(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let fmt = params["format"].as_str().unwrap_or("%Y-%m-%dT%H:%M:%S");
    let val = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let ts = Timestamp::strptime(fmt, val).map_err(|e| Bi18nError::FechaInvalida {
        valor: val.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": ts.as_second() }))
}

/// Crea un Timestamp desde Unix seconds.
/// Entrada: `{ "unix": 1752000000, "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string }`.
pub async fn from_unix(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    Ok(json!({ "unix": ts.as_second(), "iso": ts.to_string() }))
}

/// Formatea un timestamp Unix según formato strftime.
/// Entrada: `{ "unix": 1752000000, "format": "%d/%m/%Y %H:%M", "tz": "America/La_Paz", "ctx_id": "..." }`.
/// Salida: `{ "display": string }`.
pub async fn format_jiff(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let fmt = params["format"].as_str().unwrap_or("%Y-%m-%d %H:%M:%S");
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let display = ts.to_zoned(tz).strftime(fmt).to_string();
    Ok(json!({ "display": display }))
}

/// Genera una serie de N timestamps separados por un span.
/// Entrada: `{ "unix": i64, "tz": "UTC", "days": 1, "count": 7, "ctx_id": "..." }`.
/// Salida: `{ "series": [i64, ...] }`.
pub async fn series(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let count = params["count"].as_u64().unwrap_or(7) as usize;
    let span = span_desde_params(params);
    let vals: Vec<i64> = ts.series(span).take(count).map(|t| t.as_second()).collect();
    Ok(json!({ "series": vals }))
}

/// Suma un span a un instante Zoned (DST-aware).
/// Entrada: `{ "unix": i64, "tz": "...", "hours": 2, "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string }`.
pub async fn add_span(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let span = span_desde_params(params);
    let result = ts.to_zoned(tz).checked_add(span).map_err(|e| Bi18nError::FechaInvalida {
        valor: "span".to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": result.timestamp().as_second(), "iso": result.to_string() }))
}

/// Resta un span a un instante Zoned (DST-aware).
pub async fn sub_span(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let span = span_desde_params(params);
    let result = ts.to_zoned(tz).checked_sub(span).map_err(|e| Bi18nError::FechaInvalida {
        valor: "span".to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "unix": result.timestamp().as_second(), "iso": result.to_string() }))
}

/// Calcula la diferencia entre dos instantes como Span.
/// Entrada: `{ "unix_from": i64, "unix_to": i64, "tz": "UTC", "ctx_id": "..." }`.
/// Salida: `{ "days": i64, "hours": i64, "minutes": i64, "seconds": i64 }`.
pub async fn diff_span(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let from_secs = params["unix_from"].as_i64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "unix_from".to_string() })?;
    let to_secs = params["unix_to"].as_i64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "unix_to".to_string() })?;
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let z1: Zoned = Timestamp::from_second(from_secs)
        .map_err(|e| Bi18nError::FechaInvalida { valor: from_secs.to_string(), causa: e.to_string() })?
        .to_zoned(tz.clone());
    let z2: Zoned = Timestamp::from_second(to_secs)
        .map_err(|e| Bi18nError::FechaInvalida { valor: to_secs.to_string(), causa: e.to_string() })?
        .to_zoned(tz);
    let span = z1.until(&z2).map_err(|e| Bi18nError::FechaInvalida {
        valor: "diff".to_string(), causa: e.to_string(),
    })?;
    Ok(json!({
        "days": span.get_days(), "hours": span.get_hours(),
        "minutes": span.get_minutes(), "seconds": span.get_seconds()
    }))
}

/// Convierte un instante a otra zona horaria IANA.
/// Entrada: `{ "unix": i64, "tz_from": "UTC", "tz_to": "America/La_Paz", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string }`.
pub async fn convert_tz(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let tz_from = TimeZone::get(params["tz_from"].as_str().unwrap_or("UTC"))
        .map_err(|e| Bi18nError::ZonaHorariaInvalida { tz: "tz_from".to_string(), causa: e.to_string() })?;
    let tz_to_name = params["tz_to"].as_str().unwrap_or("UTC");
    let tz_to = TimeZone::get(tz_to_name)
        .map_err(|e| Bi18nError::ZonaHorariaInvalida { tz: tz_to_name.to_string(), causa: e.to_string() })?;
    let result = ts.to_zoned(tz_from).with_time_zone(tz_to);
    Ok(json!({ "unix": result.timestamp().as_second(), "iso": result.to_string() }))
}

/// Redondea un instante Zoned a la unidad indicada.
/// Entrada: `{ "unix": i64, "tz": "UTC", "unit": "hour", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "iso": string }`.
pub async fn round(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let unit_str = params["unit"].as_str().unwrap_or("minute");
    let unit = unit_desde_str(unit_str).unwrap_or(Unit::Minute);
    let result = ts.to_zoned(tz).round(ZonedRound::new().smallest(unit))
        .map_err(|e| Bi18nError::FechaInvalida { valor: "round".to_string(), causa: e.to_string() })?;
    Ok(json!({ "unix": result.timestamp().as_second(), "iso": result.to_string() }))
}

/// Retorna el nombre del día de la semana de un timestamp (en inglés: Monday, Tuesday...).
/// Entrada: `{ "unix": i64, "tz": "UTC", "ctx_id": "..." }`.
/// Salida: `{ "weekday": "Wednesday" }`.
pub async fn weekday_of_date(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ts = ts_desde_unix(params)?;
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    let tz = TimeZone::get(tz_name).map_err(|e| Bi18nError::ZonaHorariaInvalida {
        tz: tz_name.to_string(), causa: e.to_string(),
    })?;
    let weekday = format!("{:?}", ts.to_zoned(tz).weekday());
    Ok(json!({ "weekday": weekday }))
}

/// Retorna el número de días del mes indicado.
/// Entrada: `{ "year": 2026, "month": 2, "ctx_id": "..." }`.
/// Salida: `{ "days": 28 }`.
pub async fn days_in_month(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let year  = params["year"].as_i64().unwrap_or(2024) as i16;
    let month = params["month"].as_i64().unwrap_or(1) as i8;
    let date = civil::Date::new(year, month, 1).map_err(|e| Bi18nError::FechaInvalida {
        valor: format!("{year}-{month}"), causa: e.to_string(),
    })?;
    Ok(json!({ "days": date.days_in_month() }))
}

/// Indica si el año dado es bisiesto.
/// Entrada: `{ "year": 2024, "ctx_id": "..." }`.
/// Salida: `{ "leap": bool }`.
pub async fn is_leap_year(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let year = params["year"].as_i64().unwrap_or(2024) as i16;
    let date = civil::Date::new(year, 1, 1).map_err(|e| Bi18nError::FechaInvalida {
        valor: year.to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "leap": date.in_leap_year() }))
}

/// Retorna el N-ésimo día de semana del mes.
/// Entrada: `{ "year": 2026, "month": 7, "nth": 2, "weekday": "Monday", "ctx_id": "..." }`.
/// Salida: `{ "unix": i64, "date": "YYYY-MM-DD" }`.
pub async fn nth_weekday(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let year  = params["year"].as_i64().unwrap_or(2024) as i16;
    let month = params["month"].as_i64().unwrap_or(1) as i8;
    let nth   = params["nth"].as_i64().unwrap_or(1) as i8;
    let wd_str = params["weekday"].as_str().unwrap_or("Monday");
    let weekday = match wd_str {
        "Monday" => civil::Weekday::Monday, "Tuesday" => civil::Weekday::Tuesday,
        "Wednesday" => civil::Weekday::Wednesday, "Thursday" => civil::Weekday::Thursday,
        "Friday" => civil::Weekday::Friday, "Saturday" => civil::Weekday::Saturday,
        _ => civil::Weekday::Sunday,
    };
    let date = civil::Date::new(year, month, 1).map_err(|e| Bi18nError::FechaInvalida {
        valor: format!("{year}-{month}"), causa: e.to_string(),
    })?;
    let result = date.nth_weekday_of_month(nth, weekday).map_err(|e| Bi18nError::FechaInvalida {
        valor: format!("nth={nth}"), causa: e.to_string(),
    })?;
    Ok(json!({ "date": result.to_string() }))
}

/// Calcula el total de un span en la unidad indicada.
/// Entrada: `{ "days": 2, "hours": 12, "unit": "hours", "ctx_id": "..." }`.
/// Salida: `{ "total": f64, "unit": string }`.
pub async fn span_total(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let span = span_desde_params(params);
    let unit_str = params["unit"].as_str().unwrap_or("hours");
    let unit = unit_desde_str(unit_str).unwrap_or(Unit::Hour);
    let total = span.total(unit).map_err(|e| Bi18nError::FechaInvalida {
        valor: "span_total".to_string(), causa: e.to_string(),
    })?;
    Ok(json!({ "total": total, "unit": unit_str }))
}

/// Retorna información de una zona horaria IANA.
/// Entrada: `{ "tz": "America/La_Paz", "ctx_id": "..." }`.
/// Salida: `{ "iana_name": string, "valid": bool }`.
pub async fn tz_info(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let tz_name = params["tz"].as_str().unwrap_or("UTC");
    match TimeZone::get(tz_name) {
        Ok(tz) => {
            let name = tz.iana_name().unwrap_or(tz_name).to_string();
            Ok(json!({ "iana_name": name, "valid": true }))
        }
        Err(_) => Ok(json!({ "iana_name": tz_name, "valid": false })),
    }
}
