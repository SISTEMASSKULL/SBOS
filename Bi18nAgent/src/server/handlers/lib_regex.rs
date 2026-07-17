/// server/handlers/lib_regex.rs — Handler A.08.12: regex 1.13.1
/// Propósito: expone 6 métodos RPC del namespace `bi18n.text.*`
///   usando Regex y RegexSet del crate regex 1.13.1 (motor NFA sin backtracking catastrófico).
/// Librería: regex 1.13.1
/// Métodos RPC expuestos:
///   regex_match · regex_extract · regex_extract_all
///   regex_replace · regex_split · regex_match_set
/// Nota: cada llamada compila el patrón; para alta frecuencia cachear en capa superior.
/// Entrada común: ctx_id (validado en dispatcher, SBOS-049).
/// Referencia: A.08.12_INVENTARIO-LIB-REGEX-v1.0.md · PLAN-FASE-2 §12
/// Dependencias: regex, serde_json, crate::error
use regex::{Regex, RegexBuilder, RegexSet};
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Extrae el patrón desde params y construye un Regex con soporte case_insensitive.
fn regex_desde_params(params: &Value) -> Result<Regex, Bi18nError> {
    let pat = params["pattern"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "pattern".to_string() })?;
    let ci = params["case_insensitive"].as_bool().unwrap_or(false);
    RegexBuilder::new(pat)
        .case_insensitive(ci)
        .build()
        .map_err(|e| Bi18nError::PatronRegex {
            patron: pat.to_string(),
            causa: e.to_string(),
        })
}

/// Comprueba si el patrón coincide en algún lugar del texto.
/// Entrada: `{ "pattern": "^\\d+$", "text": "123", "case_insensitive"?: false, "ctx_id": "..." }`.
/// Salida: `{ "matches": true }`.
pub async fn regex_match(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let re = regex_desde_params(params)?;
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    Ok(json!({ "matches": re.is_match(text) }))
}

/// Extrae grupos nombrados de la primera coincidencia del patrón en el texto.
/// Grupos: sintaxis `(?P<nombre>...)`. Retorna todos los grupos nombrados del patrón.
/// Entrada: `{ "pattern": "(?P<year>\\d{4})-(?P<month>\\d{2})", "text": "2026-07", "ctx_id": "..." }`.
/// Salida: `{ "found": true, "full": "2026-07", "groups": { "year": "2026", "month": "07" } }`.
pub async fn regex_extract(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let re = regex_desde_params(params)?;
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    match re.captures(text) {
        None => Ok(json!({ "found": false, "full": null, "groups": {} })),
        Some(caps) => {
            let full = caps.get(0).map(|m| m.as_str()).unwrap_or("");
            let mut groups = serde_json::Map::new();
            for name in re.capture_names().flatten() {
                if let Some(val) = caps.name(name) {
                    groups.insert(name.to_string(), Value::String(val.as_str().to_string()));
                }
            }
            Ok(json!({ "found": true, "full": full, "groups": groups }))
        }
    }
}

/// Extrae todas las coincidencias (texto completo) del patrón en el texto.
/// Entrada: `{ "pattern": "\\d+", "text": "hay 3 gatos y 12 perros", "ctx_id": "..." }`.
/// Salida: `{ "count": 2, "matches": ["3", "12"] }`.
pub async fn regex_extract_all(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let re = regex_desde_params(params)?;
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    let matches: Vec<&str> = re.find_iter(text).map(|m| m.as_str()).collect();
    let count = matches.len();
    Ok(json!({ "count": count, "matches": matches }))
}

/// Reemplaza coincidencias del patrón en el texto.
/// `all: true` (default) reemplaza todas las ocurrencias; `all: false` solo la primera.
/// Entrada: `{ "pattern": "\\s+", "text": "hola   mundo", "replacement": " ", "all"?: true, "ctx_id": "..." }`.
/// Salida: `{ "result": "hola mundo" }`.
pub async fn regex_replace(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let re = regex_desde_params(params)?;
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    let rep = params["replacement"].as_str().unwrap_or("");
    let all = params["all"].as_bool().unwrap_or(true);
    let result = if all {
        re.replace_all(text, rep).into_owned()
    } else {
        re.replace(text, rep).into_owned()
    };
    Ok(json!({ "result": result }))
}

/// Divide el texto usando el patrón como separador.
/// Entrada: `{ "pattern": "[,;]\\s*", "text": "a, b; c, d", "ctx_id": "..." }`.
/// Salida: `{ "parts": ["a", "b", "c", "d"] }`.
pub async fn regex_split(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let re = regex_desde_params(params)?;
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    let parts: Vec<&str> = re.split(text).collect();
    Ok(json!({ "parts": parts }))
}

/// Comprueba qué patrones de un conjunto (RegexSet) coinciden en el texto.
/// Retorna índices de los patrones que hicieron match (en orden de definición).
/// Entrada: `{ "patterns": ["\\d+", "[A-Z]+", "foo"], "text": "ABC 123", "ctx_id": "..." }`.
/// Salida: `{ "any": true, "matched_indices": [0, 1] }`.
pub async fn regex_match_set(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let pats: Vec<&str> = params["patterns"].as_array()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "patterns".to_string() })?
        .iter()
        .filter_map(|v| v.as_str())
        .collect();
    let text = params["text"].as_str()
        .ok_or_else(|| Bi18nError::ParamAusente { param: "text".to_string() })?;
    let set = RegexSet::new(&pats).map_err(|e| Bi18nError::PatronRegex {
        patron: pats.join("|"),
        causa: e.to_string(),
    })?;
    let matched: Vec<usize> = set.matches(text).into_iter().collect();
    let any = !matched.is_empty();
    Ok(json!({ "any": any, "matched_indices": matched }))
}
