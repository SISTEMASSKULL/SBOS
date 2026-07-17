/// server/handlers/lib_mask_pii.rs — Handler A.08.08: mask-pii 0.2.0
/// Propósito: expone los 3 métodos RPC nuevos del namespace `bi18n.mask.*`
///   usando el crate `mask-pii 0.2.0` directamente (sin pasar por mask.rs).
/// Librería: mask-pii 0.2.0
/// Métodos RPC expuestos:
///   bi18n.mask.email_in_text · bi18n.mask.phone_in_text · bi18n.mask.pii_with_char
/// Nota: bi18n.mask.pii (Fase 1) ya existe en mask.rs — ahora usa mask-pii internamente (FIX).
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049) + text (string plano de entrada).
/// Retorno común: `{ "result": string_enmascarado }`.
/// Comportamiento: emails → 1er char visible + `*` × resto + `@domain.tld`.
///                 teléfonos → últimos 4 dígitos visibles + `*` en el resto.
/// Referencia: A.08.08_INVENTARIO-LIB-MASK-PII-v1.0.md · PLAN-FASE-2 §8
/// Dependencias: mask-pii, serde_json, crate::error
use mask_pii::Masker;
use serde_json::{json, Value};

use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae el campo `text` como `&str` o devuelve string vacío.
fn extraer_text(params: &Value) -> &str {
    params["text"].as_str().unwrap_or("")
}

/// Enmascara todos los emails encontrados en el texto de entrada.
/// El resto del texto permanece sin cambios.
/// Entrada: `{ "text": "Contacto: alice@empresa.com", "ctx_id": "..." }`.
/// Salida: `{ "result": "Contacto: a****@empresa.com" }`.
pub async fn mask_email_in_text(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let text = extraer_text(params);
    let result = Masker::new().mask_emails().process(text);
    Ok(json!({ "result": result }))
}

/// Enmascara todos los números de teléfono encontrados en el texto de entrada.
/// El resto del texto permanece sin cambios.
/// Entrada: `{ "text": "Llame al +59171234567", "ctx_id": "..." }`.
/// Salida: `{ "result": "Llame al *******4567" }`.
pub async fn mask_phone_in_text(
    _ctx: &ServerContext,
    params: &Value,
) -> Result<Value, Bi18nError> {
    let text = extraer_text(params);
    let result = Masker::new().mask_phones().process(text);
    Ok(json!({ "result": result }))
}

/// Enmascara emails y teléfonos usando un caracter de máscara personalizado.
/// El caracter por defecto es `*`; se puede cambiar con el campo `mask_char` (1 carácter).
/// Entrada: `{ "text": "Email: a@b.com", "mask_char": "X", "ctx_id": "..." }`.
/// Salida: `{ "result": "Email: aXXXX@b.com" }`.
pub async fn mask_pii_with_char(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let text = extraer_text(params);
    let mask_char = params["mask_char"]
        .as_str()
        .and_then(|s| s.chars().next())
        .unwrap_or('*');
    let result = Masker::new()
        .with_mask_char(mask_char)
        .mask_emails()
        .mask_phones()
        .process(text);
    Ok(json!({ "result": result }))
}
