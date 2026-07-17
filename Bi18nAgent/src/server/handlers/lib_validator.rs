/// server/handlers/lib_validator.rs — Handler A.08.06: validator 0.19.0
/// Propósito: expone los 12 métodos RPC del namespace `bi18n.validate.*`
///   usando los traits de validación del crate `validator 0.19.0`.
/// Librería: validator 0.19.0
/// Métodos RPC expuestos:
///   bi18n.validate.email_html5 · bi18n.validate.url
///   bi18n.validate.ip · bi18n.validate.ipv4 · bi18n.validate.ipv6
///   bi18n.validate.length · bi18n.validate.range
///   bi18n.validate.contains · bi18n.validate.not_contains
///   bi18n.validate.required · bi18n.validate.credit_card
///   bi18n.validate.must_match
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049) + value (string) + params opcionales.
/// Retorno común: `{ "valid": bool }` salvo must_match (`{ "match": bool }`).
/// NOTA API: en validator 0.19 NO existen funciones libres validate_email/url/ip;
///   todos son traits. La única función libre es `validate_must_match`.
///   Los métodos de ValidateIp son `validate_ipv4()` y `validate_ipv6()` (sin guión en v4/v6).
/// Referencia: A.08.06_INVENTARIO-LIB-VALIDATOR-v1.0.md · PLAN-FASE-2 §6
/// Dependencias: validator, serde_json, crate::error
use serde_json::{json, Value};
use validator::{
    validate_must_match, ValidateCreditCard, ValidateDoesNotContain, ValidateEmail, ValidateIp,
    ValidateLength, ValidateRange, ValidateRequired, ValidateUrl, ValidateContains,
};

use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae el campo `value` como `&str` o devuelve error ParamAusente.
fn extraer_value(params: &Value) -> Result<&str, Bi18nError> {
    params["value"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })
}

/// Valida correo electrónico según la especificación HTML5 (subset de RFC 5321).
/// HTML5 es más estricto que RFC 5322: no admite quoted strings ni comentarios.
/// Entrada: `{ "value": "usuario@ejemplo.com", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_email_html5(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_email();
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea una URL absoluta bien formada (usa la crate url internamente).
/// Entrada: `{ "value": "https://ejemplo.com/ruta", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_url(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_url();
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea una dirección IP válida (IPv4 o IPv6).
/// Entrada: `{ "value": "192.168.1.1", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_ip(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_ip();
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea una dirección IPv4 válida.
/// Entrada: `{ "value": "10.0.0.1", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_ipv4(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_ipv4();
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea una dirección IPv6 válida.
/// Entrada: `{ "value": "::1", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_ipv6(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_ipv6();
    Ok(json!({ "valid": valid }))
}

/// Valida la longitud de una cadena en caracteres Unicode.
/// Parámetros opcionales: `min`, `max`, `equal` (u64). Si se especifica `equal`, ignora min/max.
/// Entrada: `{ "value": "hola", "min": 2, "max": 10, "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_length(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let min = params["min"].as_u64();
    let max = params["max"].as_u64();
    let equal = params["equal"].as_u64();
    let valid = value.validate_length(min, max, equal);
    Ok(json!({ "valid": valid }))
}

/// Valida que un valor numérico esté dentro del rango dado.
/// Parámetros opcionales: `min`, `max`, `exclusive_min`, `exclusive_max` (f64).
/// Entrada: `{ "value": 42.5, "min": 0.0, "max": 100.0, "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_range(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = params["value"]
        .as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let min = params["min"].as_f64();
    let max = params["max"].as_f64();
    let excl_min = params["exclusive_min"].as_f64();
    let excl_max = params["exclusive_max"].as_f64();
    let valid = value.validate_range(min, max, excl_min, excl_max);
    Ok(json!({ "valid": valid }))
}

/// Valida que una cadena contenga la subcadena indicada en `needle`.
/// Entrada: `{ "value": "hola mundo", "needle": "mundo", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_contains(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let needle = params["needle"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "needle".to_string() })?;
    let valid = value.validate_contains(needle);
    Ok(json!({ "valid": valid }))
}

/// Valida que una cadena NO contenga la subcadena indicada en `needle`.
/// Entrada: `{ "value": "hola mundo", "needle": "adios", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_not_contains(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let needle = params["needle"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "needle".to_string() })?;
    let valid = value.validate_does_not_contain(needle);
    Ok(json!({ "valid": valid }))
}

/// Valida que el campo `value` esté presente y no sea una cadena vacía.
/// Usa ValidateRequired sobre Option<&str> — None o "" → valid: false.
/// Entrada: `{ "value": "datos", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_required(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let maybe: Option<&str> = params["value"]
        .as_str()
        .filter(|s| !s.is_empty());
    let valid = maybe.validate_required();
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea un número de tarjeta de crédito válido según el algoritmo de Luhn.
/// Entrada: `{ "value": "4111111111111111", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_credit_card(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = value.validate_credit_card();
    Ok(json!({ "valid": valid }))
}

/// Verifica que `value1` y `value2` sean iguales (comparación por igualdad de cadenas).
/// Útil para confirmar contraseñas, emails o cualquier campo de confirmación.
/// Entrada: `{ "value1": "abc123", "value2": "abc123", "ctx_id": "..." }`.
/// Salida: `{ "match": bool }`.
pub async fn validate_must_match_fields(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let a = params["value1"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value1".to_string() })?;
    let b = params["value2"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value2".to_string() })?;
    let matched = validate_must_match(a, b);
    Ok(json!({ "match": matched }))
}
