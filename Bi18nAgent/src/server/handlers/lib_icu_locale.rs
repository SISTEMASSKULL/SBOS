/// server/handlers/lib_icu_locale.rs — Handler A.08.04: icu_locale_core 2.2.0
/// Propósito: expone los 4 métodos RPC del namespace `bi18n.locale.*`
///   usando icu_locale_core para parsing, normalización, negociación y subtags BCP-47.
/// Librería: icu_locale_core 2.2.0 — tipos BCP-47 (icu_locale no disponible en Cargo)
/// Métodos RPC expuestos:
///   bi18n.locale.parse_bcp47 · bi18n.locale.canonicalize
///   bi18n.locale.negotiate · bi18n.locale.subtags
/// Nota: bi18n.locale.resolve (Fase 1) sigue en locale.rs — no se duplica aquí.
/// Parámetro ctx_id: validado en el dispatcher antes de llegar aquí (SBOS-049).
/// Referencia: A.08.04_INVENTARIO-LIB-ICU-LOCALE-v1.0.md · PLAN-FASE-2 §4
/// Dependencias: icu_locale_core, serde_json, crate::error, crate::server::context
use icu_locale_core::Locale;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Parsea y valida un string BCP-47. Retorna los componentes si es válido.
/// Entrada: `{ "locale": "es-BO-419", "ctx_id": "..." }`.
/// Salida: `{ "valid": true, "normalized": "es-419-BO", "language": "es", ... }`.
pub async fn locale_parse_bcp47(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["locale"].as_str().unwrap_or("");
    if s.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "locale".to_string() });
    }
    match Locale::try_from_str(s) {
        Ok(locale) => {
            let lang = locale.id.language.to_string();
            let script = locale.id.script.map(|sc| sc.to_string());
            let region = locale.id.region.map(|r| r.to_string());
            let variants: Vec<String> = locale.id.variants.iter()
                .map(|v| v.to_string())
                .collect();
            Ok(json!({
                "valid": true,
                "normalized": locale.to_string(),
                "language": lang,
                "script": script,
                "region": region,
                "variants": variants,
            }))
        }
        Err(e) => Ok(json!({
            "valid": false,
            "error": e.to_string(),
            "locale": s,
        })),
    }
}

/// Normaliza un string de locale BCP-47 (capitalización canónica de subtags).
/// Usa Locale::normalize() de icu_locale_core (canonicalización básica sin datos CLDR).
/// Para canonicalización completa (zh-TW → zh-Hant-TW) se requiere icu_locale con datos.
/// Entrada: `{ "locale": "ES-bo", "ctx_id": "..." }`.
/// Salida: `{ "canonical": "es-BO", "original": "ES-bo" }`.
pub async fn locale_canonicalize(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["locale"].as_str().unwrap_or("");
    if s.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "locale".to_string() });
    }
    let canonical = Locale::normalize(s).map_err(|e| Bi18nError::LocaleInvalido {
        locale: s.to_string(),
        causa: e.to_string(),
    })?;
    Ok(json!({ "canonical": canonical.as_ref(), "original": s }))
}

/// Negocia el mejor locale disponible para un conjunto de preferencias.
/// Implementa fallback por truncación de subtags (BCP-47 §4 simplificado).
/// Si `available` no se pasa, usa los directorios del fluent_dir del daemon.
/// Entrada: `{ "preferences": ["es-BO", "pt-BR"], "available": ["es-BO", "en-US"], "ctx_id": "..." }`.
/// Salida: `{ "best": "es-BO", "preferences": [...], "available": [...] }`.
pub async fn locale_negotiate(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let prefs: Vec<&str> = params["preferences"].as_array()
        .map(|arr| arr.iter().filter_map(|v| v.as_str()).collect())
        .unwrap_or_default();

    // Construir lista de disponibles: del parámetro o de los directorios FTL
    let mut available: Vec<String> = if let Some(arr) = params["available"].as_array() {
        arr.iter().filter_map(|v| v.as_str().map(String::from)).collect()
    } else {
        listar_locales_disponibles(ctx)
    };
    available.sort();

    let best = negociar(&prefs, &available);
    Ok(json!({
        "best": best,
        "preferences": prefs,
        "available": available,
    }))
}

/// Extrae los subtags de un locale BCP-47: language, script, region, variants.
/// Entrada: `{ "locale": "zh-Hans-CN", "ctx_id": "..." }`.
/// Salida: `{ "language": "zh", "script": "Hans", "region": "CN", "variants": [] }`.
pub async fn locale_subtags(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let s = params["locale"].as_str().unwrap_or("");
    if s.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "locale".to_string() });
    }
    let locale = Locale::try_from_str(s).map_err(|e| Bi18nError::LocaleInvalido {
        locale: s.to_string(),
        causa: e.to_string(),
    })?;
    Ok(json!({
        "language": locale.id.language.to_string(),
        "script":   locale.id.script.map(|sc| sc.to_string()),
        "region":   locale.id.region.map(|r| r.to_string()),
        "variants": locale.id.variants.iter().map(|v| v.to_string()).collect::<Vec<_>>(),
    }))
}

/// Lista los locales disponibles en el directorio FTL del daemon.
fn listar_locales_disponibles(ctx: &ServerContext) -> Vec<String> {
    std::fs::read_dir(&ctx.config.rutas.fluent_dir)
        .map(|entradas| {
            entradas.flatten()
                .filter(|e| e.metadata().map(|m| m.is_dir()).unwrap_or(false))
                .filter_map(|e| e.file_name().to_str().map(String::from))
                .collect()
        })
        .unwrap_or_default()
}

/// Algoritmo de negociación BCP-47 simplificado: para cada preferencia, intenta
/// match exacto o fallback por truncación sucesiva de subtags.
fn negociar(preferences: &[&str], available: &[String]) -> String {
    for pref in preferences {
        let mut candidato = pref.to_string();
        loop {
            if available.iter().any(|a| a.eq_ignore_ascii_case(&candidato)) {
                return candidato;
            }
            // Truncar el último subtag (es-419-BO → es-419 → es)
            let Some(pos) = candidato.rfind('-') else { break };
            candidato.truncate(pos);
        }
    }
    // Fallback: primero de la lista o "und"
    available.first().cloned().unwrap_or_else(|| "und".to_string())
}
