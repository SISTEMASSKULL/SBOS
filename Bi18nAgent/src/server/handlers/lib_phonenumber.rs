/// server/handlers/lib_phonenumber.rs — Handler A.08.13: phonenumber 0.3.10
/// Propósito: expone 8 métodos RPC del namespace `bi18n.phone.*`
///   usando el crate phonenumber (libphonenumber — validación ITU-T E.164, 200+ países).
/// Librería: phonenumber 0.3.10+9.0.33
/// Métodos RPC expuestos:
///   parse_e164 · format · type · is_viable · info
///   parse_national · parse_rfc3966 · country_code
/// API: Type (no PhoneNumberType), number_type(&database) (no get_number_type),
///   is_viable toma string, code() -> &country::Code, code().code() -> u16.
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049).
/// Referencia: A.08.13_INVENTARIO-LIB-PHONENUMBER-v1.0.md · PLAN-FASE-2 §13
/// Dependencias: phonenumber, serde_json, crate::error
use phonenumber::{Mode, Type};
use phonenumber::country::Id;
use phonenumber::metadata::DATABASE;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae y parsea un número desde params["phone"] con región opcional params["region"].
fn parsear_numero(params: &Value) -> Result<phonenumber::PhoneNumber, Bi18nError> {
    let phone = params["phone"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "phone".to_string() })?;
    let region: Option<Id> = params["region"].as_str().and_then(|s| s.parse().ok());
    phonenumber::parse(region, phone).map_err(|e| Bi18nError::TelefonoInvalido {
        valor: phone.to_string(),
        causa: e.to_string(),
    })
}

/// Formatea el número al modo E.164 (ej: "+59171234567").
/// Entrada: `{ "phone": "+591 71234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "e164": "+59171234567" }`.
pub async fn phone_parse_e164(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let e164 = num.format().mode(Mode::E164).to_string();
    Ok(json!({ "e164": e164 }))
}

/// Formatea el número en formato internacional (ej: "+591 71234567").
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "formatted": "+591 71234567" }`.
pub async fn phone_format(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let formatted = num.format().mode(Mode::International).to_string();
    Ok(json!({ "formatted": formatted }))
}

/// Retorna el tipo de número (Mobile, FixedLine, TollFree, Voip, etc).
/// Usa DATABASE de phonenumber para determinar el tipo por región.
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "type": "Mobile" }`.
pub async fn phone_type(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let tipo: Type = num.number_type(&DATABASE);
    Ok(json!({ "type": format!("{tipo:?}") }))
}

/// Verifica si la cadena de texto tiene la forma básica de un número de teléfono
/// (viable), sin validar si pertenece a un carrier real.
/// Toma el string crudo — no requiere parseo previo.
/// Entrada: `{ "phone": "+59171234567", "ctx_id": "..." }`.
/// Salida: `{ "viable": true }`.
pub async fn phone_is_viable(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let phone = params["phone"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "phone".to_string() })?;
    let viable = phonenumber::is_viable(phone);
    Ok(json!({ "viable": viable }))
}

/// Retorna información completa del número: validez, viabilidad, tipo, formatos y código de país.
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "viable": true, "type": "Mobile",
///            "e164": "+59171234567", "national": "71234567",
///            "international": "+591 71234567", "country_code": 591 }`.
pub async fn phone_info(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let phone_raw = params["phone"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "phone".to_string() })?;
    let viable = phonenumber::is_viable(phone_raw);
    match parsear_numero(params) {
        Err(_) => Ok(json!({
            "valid": false, "viable": viable,
            "type": "Unknown", "e164": null,
            "national": null, "international": null, "country_code": null
        })),
        Ok(num) => {
            let valid = num.is_valid();
            let tipo = format!("{:?}", num.number_type(&DATABASE));
            let e164 = num.format().mode(Mode::E164).to_string();
            let national = num.format().mode(Mode::National).to_string();
            let international = num.format().mode(Mode::International).to_string();
            let country_code = num.code().value();
            Ok(json!({
                "valid": valid, "viable": viable,
                "type": tipo, "e164": e164,
                "national": national, "international": international,
                "country_code": country_code
            }))
        }
    }
}

/// Formatea el número en notación nacional (sin prefijo internacional).
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "national": "71234567" }`.
pub async fn phone_parse_national(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let national = num.format().mode(Mode::National).to_string();
    Ok(json!({ "national": national }))
}

/// Formatea el número en formato RFC 3966 (ej: "tel:+59171234567").
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "rfc3966": "tel:+59171234567" }`.
pub async fn phone_parse_rfc3966(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let rfc3966 = num.format().mode(Mode::Rfc3966).to_string();
    Ok(json!({ "rfc3966": rfc3966 }))
}

/// Retorna el código numérico de país del número (ej: 591 para Bolivia).
/// Entrada: `{ "phone": "+59171234567", "region"?: "BO", "ctx_id": "..." }`.
/// Salida: `{ "country_code": 591 }`.
pub async fn phone_country_code(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let num = parsear_numero(params)?;
    let code = num.code().value();
    Ok(json!({ "country_code": code }))
}
