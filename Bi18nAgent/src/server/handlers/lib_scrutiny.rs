/// server/handlers/lib_scrutiny.rs — Handler A.08.07: scrutiny 0.1.2
/// Propósito: expone los 6 métodos RPC del namespace `bi18n.validate.*`
///   que son exclusivos de scrutiny (formatos que validator no cubre).
/// Librería: scrutiny 0.1.2 (features: uuid-parse, ulid-parse, timezone, serde_json)
/// Métodos RPC expuestos:
///   bi18n.validate.uuid · bi18n.validate.ulid · bi18n.validate.mac_address
///   bi18n.validate.hex_color · bi18n.validate.timezone · bi18n.validate.is_json
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049) + value (string).
/// Retorno común: `{ "valid": bool }`.
/// NOTA API: las funciones viven en `scrutiny::rules::format` — son `pub fn` aunque el crate
///   recomienda usarlas vía derive. Las importamos directamente como funciones libres.
/// Referencia: A.08.07_INVENTARIO-LIB-SCRUTINY-v1.0.md · PLAN-FASE-2 §7
/// Dependencias: scrutiny, serde_json, crate::error
use scrutiny::rules::format::{
    is_hex_color, is_json, is_mac_address, is_timezone, is_ulid, is_uuid,
};
use serde_json::{json, Value};

use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae el campo `value` como `&str` o devuelve error ParamAusente.
fn extraer_value(params: &Value) -> Result<&str, Bi18nError> {
    params["value"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })
}

/// Valida que la cadena sea un UUID RFC 4122 en cualquier versión (v1–v8).
/// Usa el crate `uuid` internamente — acepta la forma canónica con guiones.
/// Entrada: `{ "value": "550e8400-e29b-41d4-a716-446655440000", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_uuid(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_uuid(value);
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea un ULID según la especificación ulid/spec.
/// Crockford base32, 26 caracteres — sensible a mayúsculas/minúsculas.
/// Entrada: `{ "value": "01ARZ3NDEKTSV4RRFFQ69G5FAV", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_ulid(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_ulid(value);
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea una dirección MAC IEEE 802 con formato XX:XX:XX:XX:XX:XX o XX-XX-XX-XX-XX-XX.
/// Entrada: `{ "value": "00:1A:2B:3C:4D:5E", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_mac_address(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_mac_address(value);
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea un color hex válido: #RGB, #RRGGBB o #RRGGBBAA.
/// Acepta solo dígitos hexadecimales (0-9, A-F, a-f) después del #.
/// Entrada: `{ "value": "#FF5733", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_hex_color(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_hex_color(value);
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea un nombre de zona horaria IANA reconocido.
/// Usa la base de datos IANA embebida en el crate chrono-tz.
/// Ejemplo de zonas válidas: "America/La_Paz", "Europe/Madrid", "UTC".
/// Entrada: `{ "value": "America/La_Paz", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_timezone(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_timezone(value);
    Ok(json!({ "valid": valid }))
}

/// Valida que la cadena sea JSON bien formado (parseable por serde_json).
/// Acepta cualquier tipo JSON válido: objeto, array, string, número, bool, null.
/// Entrada: `{ "value": "{\"key\": 1}", "ctx_id": "..." }`.
/// Salida: `{ "valid": bool }`.
pub async fn validate_is_json(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let value = extraer_value(params)?;
    let valid = is_json(value);
    Ok(json!({ "valid": valid }))
}
