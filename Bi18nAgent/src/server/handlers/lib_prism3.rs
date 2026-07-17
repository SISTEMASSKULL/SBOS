/// server/handlers/lib_prism3.rs — Handler A.08.14: prism3-core 0.2.0
/// Propósito: expone 12 métodos RPC del namespace `bi18n.guard.*`
///   usando las guardas y precondiciones del crate prism3-core 0.2.0.
/// Librería: prism3-core 0.2.0
/// Métodos RPC expuestos:
///   check_bounds · check_element_index · check_position_index · num_compare
///   num_positive · num_non_negative · num_in_range
///   str_non_blank · str_length_range · str_match
///   col_non_empty · col_length_range
/// Salida común: `{ "valid": bool, "error"?: string }` — la falla es semántica, no error RPC.
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049).
/// Referencia: A.08.14_INVENTARIO-LIB-PRISM3-v1.0.md · PLAN-FASE-2 §14
/// Dependencias: prism3-core, regex, serde_json, crate::error
use prism3_core::{
    check_bounds, check_element_index, check_position_index,
    require_equal, require_not_equal,
    CollectionArgument, NumericArgument, StringArgument,
};
use regex::Regex;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Convierte ArgumentResult<T> a un JSON de resultado de guarda.
fn guard_ok<T>(result: prism3_core::ArgumentResult<T>) -> Result<Value, Bi18nError> {
    match result {
        Ok(_)  => Ok(json!({ "valid": true,  "error": null })),
        Err(e) => Ok(json!({ "valid": false, "error": e.message() })),
    }
}

/// Verifica que `[offset, offset+length)` está dentro de `[0, total_length]`.
/// Entrada: `{ "offset": 2, "length": 5, "total_length": 10, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_check_bounds(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let offset       = params["offset"].as_u64().unwrap_or(0) as usize;
    let length       = params["length"].as_u64().unwrap_or(0) as usize;
    let total_length = params["total_length"].as_u64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "total_length".to_string() })? as usize;
    guard_ok(check_bounds(offset, length, total_length))
}

/// Verifica que `index` es un índice válido en una colección de tamaño `size` (0 ≤ index < size).
/// Entrada: `{ "index": 3, "size": 10, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_check_element_index(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let index = params["index"].as_u64().unwrap_or(0) as usize;
    let size  = params["size"].as_u64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "size".to_string() })? as usize;
    guard_ok(check_element_index(index, size))
}

/// Verifica que `index` es una posición de inserción válida (0 ≤ index ≤ size).
/// Entrada: `{ "index": 5, "size": 5, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_check_position_index(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let index = params["index"].as_u64().unwrap_or(0) as usize;
    let size  = params["size"].as_u64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "size".to_string() })? as usize;
    guard_ok(check_position_index(index, size))
}

/// Compara dos valores numéricos (f64). `mode`: "equal" | "not_equal".
/// Entrada: `{ "name1": "min", "v1": 0.0, "name2": "max", "v2": 100.0, "mode": "not_equal", "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_num_compare(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name1 = params["name1"].as_str().unwrap_or("v1");
    let name2 = params["name2"].as_str().unwrap_or("v2");
    let v1: f64 = params["v1"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "v1".to_string() })?;
    let v2: f64 = params["v2"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "v2".to_string() })?;
    let mode = params["mode"].as_str().unwrap_or("equal");
    if mode == "not_equal" {
        guard_ok(require_not_equal(name1, v1, name2, v2))
    } else {
        guard_ok(require_equal(name1, v1, name2, v2))
    }
}

/// Verifica que el número f64 es positivo (> 0).
/// Entrada: `{ "name": "precio", "value": 42.5, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_num_positive(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v: f64 = params["value"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    guard_ok(v.require_positive(name))
}

/// Verifica que el número f64 es no negativo (≥ 0).
/// Entrada: `{ "name": "cantidad", "value": 0.0, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_num_non_negative(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v: f64 = params["value"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    guard_ok(v.require_non_negative(name))
}

/// Verifica que el número f64 está en el rango cerrado [min, max].
/// Entrada: `{ "name": "edad", "value": 25.0, "min": 0.0, "max": 120.0, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_num_in_range(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v: f64 = params["value"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let min: f64 = params["min"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "min".to_string() })?;
    let max: f64 = params["max"].as_f64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "max".to_string() })?;
    guard_ok(v.require_in_closed_range(name, min, max))
}

/// Verifica que el string no está en blanco (no vacío ni solo espacios).
/// Entrada: `{ "name": "usuario", "value": "admin", "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_str_non_blank(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    guard_ok(v.require_non_blank(name))
}

/// Verifica que la longitud del string está en el rango [min, max].
/// Entrada: `{ "name": "clave", "value": "secreto", "min": 8, "max": 64, "ctx_id": "..." }`.
/// Salida: `{ "valid": false, "error": "..." }`.
pub async fn guard_str_length_range(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let min = params["min"].as_u64().unwrap_or(0) as usize;
    let max = params["max"].as_u64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "max".to_string() })? as usize;
    guard_ok(v.require_length_in_range(name, min, max))
}

/// Verifica que el string coincide con el patrón regex dado.
/// Entrada: `{ "name": "ci", "value": "12345678", "pattern": "^\\d{7,8}$", "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_str_match(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name = params["name"].as_str().unwrap_or("value");
    let v = params["value"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let pat = params["pattern"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "pattern".to_string() })?;
    let re = Regex::new(pat).map_err(|e| Bi18nError::PatronRegex {
        patron: pat.to_string(), causa: e.to_string(),
    })?;
    guard_ok(v.require_match(name, &re))
}

/// Verifica que el array JSON no está vacío.
/// Entrada: `{ "name": "items", "value": [1, 2, 3], "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_col_non_empty(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name  = params["name"].as_str().unwrap_or("value");
    let items = params["value"].as_array()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    guard_ok(items.as_slice().require_non_empty(name))
}

/// Verifica que la longitud del array JSON está en el rango [min, max].
/// Entrada: `{ "name": "roles", "value": ["admin", "user"], "min": 1, "max": 10, "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "error": null }`.
pub async fn guard_col_length_range(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let name  = params["name"].as_str().unwrap_or("value");
    let items = params["value"].as_array()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "value".to_string() })?;
    let min = params["min"].as_u64().unwrap_or(0) as usize;
    let max = params["max"].as_u64()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "max".to_string() })? as usize;
    guard_ok(items.as_slice().require_length_in_range(name, min, max))
}
