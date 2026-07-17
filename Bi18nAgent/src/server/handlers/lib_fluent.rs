/// server/handlers/lib_fluent.rs — Handler A.08.01: fluent-bundle 0.15.3
/// Propósito: expone los 6 métodos RPC del namespace `bi18n.translate.*`
///   usando el FluentLoader del ServerContext como puente — no reimplementa
///   la librería, solo la expone vía JSON-RPC.
/// Librería: fluent-bundle 0.15.3 — Project Fluent (Mozilla)
/// Métodos RPC expuestos:
///   bi18n.translate.has_message · bi18n.translate.message
///   bi18n.translate.message_with_args · bi18n.translate.batch
///   bi18n.translate.list_messages · bi18n.translate.attribute
/// Parámetro ctx_id: validado en el dispatcher antes de llegar aquí (SBOS-049).
/// Referencia: A.08.01_INVENTARIO-LIB-FLUENT-BUNDLE-v1.0.md · PLAN-FASE-2 §1
/// Dependencias: serde_json, fluent-bundle (via FluentLoader), crate::error, crate::server::context
use fluent_bundle::FluentArgs;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Verifica si existe un mensaje con el ID dado en el bundle activo.
/// Entrada: `{ "id": "saludo", "ctx_id": "..." }`.
/// Salida: `{ "exists": true, "id": "saludo" }`.
pub async fn translate_has_message(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let id = params["id"].as_str().unwrap_or("");
    if id.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "id".to_string() });
    }
    let existe = ctx.fluent.tiene_mensaje(id);
    Ok(json!({ "exists": existe, "id": id }))
}

/// Traduce un mensaje por ID sin argumentos. Fallback: devuelve el id literal.
/// Entrada: `{ "id": "boton-aceptar", "ctx_id": "..." }`.
/// Salida: `{ "text": "Aceptar", "id": "boton-aceptar", "found": true }`.
pub async fn translate_message(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let id = params["id"].as_str().unwrap_or("");
    if id.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "id".to_string() });
    }
    let found = ctx.fluent.tiene_mensaje(id);
    let texto = ctx.fluent.traducir(id, None);
    Ok(json!({ "text": texto, "id": id, "found": found }))
}

/// Traduce un mensaje con argumentos nombrados pasados como objeto JSON.
/// Entrada: `{ "id": "paises-cargados", "args": { "n": 5 }, "ctx_id": "..." }`.
/// Salida: `{ "text": "5 países cargados", "id": "...", "found": true }`.
pub async fn translate_message_with_args(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let id = params["id"].as_str().unwrap_or("");
    if id.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "id".to_string() });
    }
    let found = ctx.fluent.tiene_mensaje(id);

    // Colectar claves y valores localmente para garantizar lifetimes de FluentArgs
    let mut claves: Vec<String> = Vec::new();
    let mut vals_num: Vec<(usize, i64)> = Vec::new();
    let mut vals_str: Vec<(usize, String)> = Vec::new();

    if let Some(obj) = params["args"].as_object() {
        for (k, v) in obj {
            let idx = claves.len();
            claves.push(k.clone());
            if let Some(n) = v.as_i64() {
                vals_num.push((idx, n));
            } else if let Some(s) = v.as_str() {
                vals_str.push((idx, s.to_string()));
            }
        }
    }

    let texto = if claves.is_empty() {
        ctx.fluent.traducir(id, None)
    } else {
        let mut args = FluentArgs::new();
        for (idx, n) in &vals_num {
            args.set(claves[*idx].as_str(), *n);
        }
        for (idx, s) in &vals_str {
            args.set(claves[*idx].as_str(), s.as_str());
        }
        ctx.fluent.traducir(id, Some(&args))
    };
    Ok(json!({ "text": texto, "id": id, "found": found }))
}

/// Traduce un lote de IDs en una sola llamada (sin args). IDs inexistentes → fallback literal.
/// Entrada: `{ "ids": ["boton-aceptar", "boton-cancelar"], "ctx_id": "..." }`.
/// Salida: `{ "translations": { "boton-aceptar": "Aceptar", ... }, "count": 2 }`.
pub async fn translate_batch(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let ids = match params["ids"].as_array() {
        Some(arr) => arr,
        None => return Err(Bi18nError::ParamAusente { param: "ids".to_string() }),
    };
    let mut resultado = serde_json::Map::new();
    for id_val in ids {
        let id = id_val.as_str().unwrap_or_default();
        let texto = ctx.fluent.traducir(id, None);
        resultado.insert(id.to_string(), json!(texto));
    }
    let count = resultado.len();
    Ok(json!({ "translations": resultado, "count": count }))
}

/// Lista todos los IDs de mensajes disponibles en el bundle activo.
/// Parámetro opcional `prefix` para filtrar por prefijo (p. ej. "bauth.").
/// Entrada: `{ "prefix": "bauth.", "ctx_id": "..." }`.
/// Salida: `{ "ids": ["bauth.login.titulo", ...], "count": N }`.
pub async fn translate_list_messages(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let mut ids = ctx.fluent.listar_ids();
    if let Some(prefix) = params["prefix"].as_str() {
        if !prefix.is_empty() {
            ids.retain(|id| id.starts_with(prefix));
        }
    }
    let count = ids.len();
    Ok(json!({ "ids": ids, "count": count }))
}

/// Traduce un atributo de un mensaje Fluent (`.label`, `.placeholder`, etc.).
/// Entrada: `{ "id": "campo-email", "attribute": "label", "ctx_id": "..." }`.
/// Salida: `{ "text": "Correo electrónico", "id": "...", "attribute": "label", "found": true }`.
pub async fn translate_attribute(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let id = params["id"].as_str().unwrap_or("");
    let attr = params["attribute"].as_str().unwrap_or("");
    if id.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "id".to_string() });
    }
    if attr.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "attribute".to_string() });
    }
    let resultado = ctx.fluent.traducir_atributo(id, attr);
    let found = resultado.is_some();
    let texto = resultado.unwrap_or_else(|| format!("{id}.{attr}"));
    Ok(json!({ "text": texto, "id": id, "attribute": attr, "found": found }))
}
