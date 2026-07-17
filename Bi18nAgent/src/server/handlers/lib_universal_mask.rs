/// server/handlers/lib_universal_mask.rs — Handler A.08.09: universal_mask 0.1.0
/// Propósito: expone los 5 métodos RPC del namespace `bi18n.format.*_mask`
///   usando la función `mask(text, pattern)` del crate `universal_mask 0.1.0`.
/// Librería: universal_mask 0.1.0
/// Métodos RPC expuestos:
///   bi18n.format.structural_mask — máscara genérica con patrón arbitrario
///   bi18n.format.mask_cnpj      — CNPJ Brasil (XX.XXX.XXX/XXXX-XX)
///   bi18n.format.mask_cpf       — CPF Brasil (XXX.XXX.XXX-XX)
///   bi18n.format.mask_card      — Tarjeta de crédito (XXXX-XXXX-XXXX-XXXX)
///   bi18n.format.mask_ci_bo     — CI Bolivia (7 u 8 dígitos: XXXXXXX|XXXXXXXX)
/// Semántica del patrón: `X` = consume carácter del input; otros = separadores literales.
///   `|` separa patrones alternativos — elige el más adecuado según la longitud del input.
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049) + text (solo dígitos o alfanumérico).
/// Retorno común: `{ "masked": string_formateado }`.
/// Referencia: A.08.09_INVENTARIO-LIB-UNIVERSAL-MASK-v1.0.md · PLAN-FASE-2 §9
/// Dependencias: universal_mask, serde_json, crate::error
use serde_json::{json, Value};
use universal_mask::mask;

use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae el campo `text` o devuelve error ParamAusente.
fn extraer_text(params: &Value) -> Result<&str, Bi18nError> {
    params["text"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })
}

/// Aplica una máscara posicional genérica a la cadena de entrada.
/// El patrón usa `X` para cada carácter del input; el resto son literales.
/// Permite patrones alternativos separados por `|`.
/// Entrada: `{ "text": "1234567890", "pattern": "(XXX) XXX-XXXX", "ctx_id": "..." }`.
/// Salida: `{ "masked": "(123) 456-7890" }`.
pub async fn format_structural_mask(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let text = extraer_text(params)?;
    let pattern = params["pattern"]
        .as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "pattern".to_string() })?;
    let masked = mask(text, pattern);
    Ok(json!({ "masked": masked }))
}

/// Formatea un CNPJ brasileño (14 dígitos) como XX.XXX.XXX/XXXX-XX.
/// Entrada: `{ "text": "11222333000181", "ctx_id": "..." }`.
/// Salida: `{ "masked": "11.222.333/0001-81" }`.
pub async fn format_mask_cnpj(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let text = extraer_text(params)?;
    let masked = mask(text, "XX.XXX.XXX/XXXX-XX");
    Ok(json!({ "masked": masked }))
}

/// Formatea un CPF brasileño (11 dígitos) como XXX.XXX.XXX-XX.
/// Entrada: `{ "text": "12345678901", "ctx_id": "..." }`.
/// Salida: `{ "masked": "123.456.789-01" }`.
pub async fn format_mask_cpf(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let text = extraer_text(params)?;
    let masked = mask(text, "XXX.XXX.XXX-XX");
    Ok(json!({ "masked": masked }))
}

/// Formatea un número de tarjeta de crédito (16 dígitos) como XXXX-XXXX-XXXX-XXXX.
/// Entrada: `{ "text": "4111111111111111", "ctx_id": "..." }`.
/// Salida: `{ "masked": "4111-1111-1111-1111" }`.
pub async fn format_mask_card(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let text = extraer_text(params)?;
    let masked = mask(text, "XXXX-XXXX-XXXX-XXXX");
    Ok(json!({ "masked": masked }))
}

/// Formatea un número de CI boliviana (7 u 8 dígitos) con patrón alternativo.
/// El patrón `XXXXXXX|XXXXXXXX` elige automáticamente según la longitud del input.
/// Entrada: `{ "text": "1234567", "ctx_id": "..." }`.
/// Salida: `{ "masked": "1234567" }`.
pub async fn format_mask_ci_bo(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let text = extraer_text(params)?;
    let masked = mask(text, "XXXXXXX|XXXXXXXX");
    Ok(json!({ "masked": masked }))
}
