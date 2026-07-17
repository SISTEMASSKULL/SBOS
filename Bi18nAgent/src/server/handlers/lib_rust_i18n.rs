/// server/handlers/lib_rust_i18n.rs — Handler A.08.02: rust-i18n 4.x
/// Propósito: expone los 4 métodos RPC del namespace `bi18n.i18n.*`
///   usando las funciones de runtime de rust-i18n como puente.
/// Librería: rust-i18n 4.x — macro i18n! + backend YAML/TOML
/// Métodos RPC expuestos:
///   bi18n.i18n.locale_activo · bi18n.i18n.set_locale
///   bi18n.i18n.available_locales · bi18n.i18n.translate
/// Notas:
///   - El locale global de rust-i18n (AtomicStr) afecta el proceso entero.
///     set_locale debe usarse solo en contextos de admin/test, no por request.
///   - available_locales combina locales YAML (rust-i18n) + directorios FTL (Fluent).
///   - translate: usa t!() de rust-i18n; si no hay YAML, fallback = key literal.
/// Parámetro ctx_id: validado en el dispatcher antes de llegar aquí (SBOS-049).
/// Referencia: A.08.02_INVENTARIO-LIB-RUST-I18N-v1.0.md · PLAN-FASE-2 §2
/// Dependencias: rust-i18n (via lib.rs i18n!()), serde_json, crate::error, crate::server::context
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Devuelve el locale activo según rust-i18n (estado global del proceso).
/// Salida: `{ "locale": "es-BO", "fuente": "rust-i18n-global" }`.
pub async fn i18n_locale_activo(_ctx: &ServerContext, _params: &Value) -> Result<Value, Bi18nError> {
    let locale = rust_i18n::locale().to_string();
    Ok(json!({ "locale": locale, "fuente": "rust-i18n-global" }))
}

/// Cambia el locale activo global de rust-i18n para el proceso.
/// ⚠️ Afecta todos los requests concurrentes — usar solo en admin/test.
/// Entrada: `{ "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "locale_anterior": "en", "locale_nuevo": "es-BO", "advertencia": str }`.
pub async fn i18n_set_locale(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let nuevo = params["locale"].as_str().unwrap_or("");
    if nuevo.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "locale".to_string() });
    }
    let anterior = rust_i18n::locale().to_string();
    rust_i18n::set_locale(nuevo);
    Ok(json!({
        "locale_anterior": anterior,
        "locale_nuevo": nuevo,
        "advertencia": "cambio global de proceso — afecta requests concurrentes",
    }))
}

/// Lista los locales disponibles: YAML en rust-i18n + directorios FTL en fluent_dir.
/// Salida: `{ "locales": ["es-BO", "en-US"], "count": 2, "fuente": "fluent-dir" }`.
pub async fn i18n_available_locales(ctx: &ServerContext, _params: &Value) -> Result<Value, Bi18nError> {
    // Locales de rust-i18n (archivos YAML compilados en el binario)
    let mut locales: Vec<String> = rust_i18n::available_locales!()
        .iter()
        .map(|l| l.to_string())
        .collect();

    // Complementar con directorios FTL del fluent_dir
    if let Ok(entradas) = std::fs::read_dir(&ctx.config.rutas.fluent_dir) {
        for entrada in entradas.flatten() {
            if let Ok(meta) = entrada.metadata() {
                if meta.is_dir() {
                    if let Some(nombre) = entrada.file_name().to_str() {
                        let nombre = nombre.to_string();
                        if !locales.contains(&nombre) {
                            locales.push(nombre);
                        }
                    }
                }
            }
        }
    }

    locales.sort();
    let count = locales.len();
    Ok(json!({ "locales": locales, "count": count, "fuente": "rust-i18n+fluent-dir" }))
}

/// Traduce una clave usando rust-i18n (t!). Fallback: key literal si no hay YAML.
/// Si el key no se encuentra en rust-i18n, delega a FluentLoader.
/// Entrada: `{ "key": "saludo", "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "text": "Hola", "key": "saludo", "locale": "es-BO", "backend": "fluent|rust-i18n" }`.
pub async fn i18n_translate(ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let key = params["key"].as_str().unwrap_or("");
    if key.is_empty() {
        return Err(Bi18nError::ParamAusente { param: "key".to_string() });
    }
    let locale = params["locale"].as_str()
        .unwrap_or(&ctx.config.regional.locale);

    // Intentar rust-i18n primero — si hay YAML con la clave, lo usa
    let texto_i18n = rust_i18n::t!(key, locale = locale).to_string();

    // Si rust-i18n devuelve el key literal (sin traducción YAML), intentar Fluent
    if texto_i18n == key {
        let texto_fluent = ctx.fluent.traducir(key, None);
        if texto_fluent != key {
            return Ok(json!({ "text": texto_fluent, "key": key, "locale": locale, "backend": "fluent" }));
        }
    }

    Ok(json!({ "text": texto_i18n, "key": key, "locale": locale, "backend": "rust-i18n" }))
}
