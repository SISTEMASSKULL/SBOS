/// server/handlers/lib_admin_traducciones.rs — Gestión de traducciones FTL en runtime.
/// Propósito: 4 métodos bi18n.admin.* para listar, leer y actualizar mensajes FTL.
///   Decisión: sin servidor HTTP separado — usa WebSocket+JSON-RPC existente (ADR: SBOS-050).
///   - list_locales: subdirectorios de fluent_dir → locales disponibles
///   - list_messages: IDs y textos de todos los archivos .ftl de un locale
///   - get_message: texto de un ID específico en un locale
///   - update_message: reescribe una clave en el FTL + ArcSwap reload
/// Dependencias: crate::server::context, crate::error, serde_json, std::fs
use serde::Deserialize;
use serde_json::Value;
use std::{collections::HashMap, path::PathBuf};
use crate::{
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};

/// Parámetros para list_messages.
#[derive(Deserialize)]
struct LocaleParam {
    #[allow(dead_code)]
    ctx_id: String,
    locale: String,
}

/// Parámetros para get_message.
#[derive(Deserialize)]
struct GetMessageParam {
    #[allow(dead_code)]
    ctx_id: String,
    locale: String,
    id: String,
}

/// Parámetros para update_message.
#[derive(Deserialize)]
struct UpdateMessageParam {
    #[allow(dead_code)]
    ctx_id: String,
    locale: String,
    id: String,
    text: String,
    /// Hash SHA-256 de la contraseña admin (generado por clipass_rs en bi18nctl).
    admin_token: String,
}

/// Lista los locales disponibles: subdirectorios de fluent_dir.
pub async fn admin_list_locales(ctx: &ServerContext, _params: &Value) -> Resultado<Value> {
    let fluent_dir = &ctx.config.rutas.fluent_dir;
    let mut locales: Vec<String> = Vec::new();

    let entradas = std::fs::read_dir(fluent_dir).map_err(|e| Bi18nError::ConfigLectura {
        ruta: fluent_dir.clone(),
        causa: e.to_string(),
    })?;

    for entrada in entradas {
        let entrada = entrada.map_err(|e| Bi18nError::ConfigLectura {
            ruta: fluent_dir.clone(),
            causa: e.to_string(),
        })?;
        if entrada.path().is_dir() {
            if let Some(nombre) = entrada.file_name().to_str() {
                locales.push(nombre.to_string());
            }
        }
    }
    locales.sort();
    Ok(serde_json::json!({ "locales": locales, "count": locales.len() }))
}

/// Lista todos los IDs y textos de un locale (lee los .ftl directamente desde disco).
pub async fn admin_list_messages(ctx: &ServerContext, params: &Value) -> Resultado<Value> {
    let p: LocaleParam = serde_json::from_value(params.clone())
        .map_err(|e| Bi18nError::ParamAusente { param: format!("locale: {e}") })?;

    let mensajes = leer_mensajes_locale(&ctx.config.rutas.fluent_dir, &p.locale)?;
    let count = mensajes.len();
    Ok(serde_json::json!({ "locale": p.locale, "messages": mensajes, "count": count }))
}

/// Obtiene el texto de un ID específico en un locale.
pub async fn admin_get_message(ctx: &ServerContext, params: &Value) -> Resultado<Value> {
    let p: GetMessageParam = serde_json::from_value(params.clone())
        .map_err(|e| Bi18nError::ParamAusente { param: format!("locale/id: {e}") })?;

    let mensajes = leer_mensajes_locale(&ctx.config.rutas.fluent_dir, &p.locale)?;
    match mensajes.get(&p.id) {
        Some(texto) => Ok(serde_json::json!({
            "locale": p.locale,
            "id": p.id,
            "text": texto,
        })),
        None => Err(Bi18nError::MetodoNoEncontrado {
            metodo: format!("id '{}' en locale '{}'", p.id, p.locale),
        }),
    }
}

/// Actualiza un ID en el FTL + recarga atómica. Requiere admin_token válido.
/// El ID se reescribe en main.ftl; si no existe, se agrega al final.
pub async fn admin_update_message(ctx: &ServerContext, params: &Value) -> Resultado<Value> {
    let p: UpdateMessageParam = serde_json::from_value(params.clone())
        .map_err(|e| Bi18nError::ParamAusente { param: format!("locale/id/text/admin_token: {e}") })?;

    validar_admin_token(&ctx, &p.admin_token)?;

    let ruta_ftl = ctx.config.rutas.fluent_dir.join(&p.locale).join("main.ftl");
    reescribir_clave_ftl(&ruta_ftl, &p.id, &p.text)?;

    ctx.fluent.recargar(&ctx.config.rutas.fluent_dir)
        .map_err(|e| Bi18nError::ConfigLectura {
            ruta: ctx.config.rutas.fluent_dir.clone(),
            causa: e.to_string(),
        })?;

    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    tracing::info!("admin.update_message: '{}' actualizado en locale '{}'", p.id, p.locale);
    Ok(serde_json::json!({
        "ok": true,
        "reloaded_at": ts,
        "locale": p.locale,
        "id": p.id,
    }))
}

/// Valida el admin_token contra el hash SHA-256 configurado en ServidorConfig.
fn validar_admin_token(ctx: &ServerContext, token: &str) -> Resultado<()> {
    match &ctx.config.servidor.admin_hash {
        None => Err(Bi18nError::AccesoDenegado {
            motivo: "admin_hash no configurado en bi18n.toml".to_string(),
        }),
        Some(hash) if hash.as_str() == token => Ok(()),
        _ => Err(Bi18nError::AccesoDenegado {
            motivo: "admin_token inválido".to_string(),
        }),
    }
}

/// Lee todos los mensajes FTL del locale dado, fusionando todos los archivos .ftl.
fn leer_mensajes_locale(fluent_dir: &PathBuf, locale: &str) -> Resultado<HashMap<String, String>> {
    let dir = fluent_dir.join(locale);
    let mut mensajes: HashMap<String, String> = HashMap::new();

    let entradas = std::fs::read_dir(&dir).map_err(|e| Bi18nError::ConfigLectura {
        ruta: dir.clone(),
        causa: format!("locale '{}' no encontrado: {}", locale, e),
    })?;

    for entrada in entradas {
        let entrada = entrada.map_err(|e| Bi18nError::ConfigLectura {
            ruta: dir.clone(),
            causa: e.to_string(),
        })?;
        let ruta = entrada.path();
        if ruta.extension().and_then(|e| e.to_str()) != Some("ftl") {
            continue;
        }
        let contenido = std::fs::read_to_string(&ruta).map_err(|e| Bi18nError::ConfigLectura {
            ruta: ruta.clone(),
            causa: e.to_string(),
        })?;
        parsear_mensajes_ftl(&contenido, &mut mensajes);
    }
    Ok(mensajes)
}

/// Parsea un FTL: extrae pares clave=texto. Ignora términos (-), comentarios (#).
/// Soporta mensajes multilínea (líneas de continuación con sangría).
fn parsear_mensajes_ftl(contenido: &str, out: &mut HashMap<String, String>) {
    let mut id_actual: Option<String> = None;
    let mut partes: Vec<String> = Vec::new();

    for linea in contenido.lines() {
        if linea.starts_with('#') || linea.starts_with('-') || linea.trim().is_empty() {
            volcar_mensaje(&mut id_actual, &mut partes, out);
            continue;
        }
        if linea.starts_with(' ') || linea.starts_with('\t') {
            if id_actual.is_some() {
                partes.push(linea.trim().to_string());
            }
            continue;
        }
        if let Some(pos) = linea.find('=') {
            let clave = linea[..pos].trim();
            let es_id_valido = !clave.is_empty()
                && clave.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_');
            if es_id_valido {
                volcar_mensaje(&mut id_actual, &mut partes, out);
                id_actual = Some(clave.to_string());
                partes.push(linea[pos + 1..].trim().to_string());
                continue;
            }
        }
        volcar_mensaje(&mut id_actual, &mut partes, out);
    }
    volcar_mensaje(&mut id_actual, &mut partes, out);
}

fn volcar_mensaje(id: &mut Option<String>, partes: &mut Vec<String>, out: &mut HashMap<String, String>) {
    if let Some(clave) = id.take() {
        out.insert(clave, partes.join(" ").trim().to_string());
    }
    partes.clear();
}

/// Reescribe `id = nuevo_texto` en el archivo FTL dado.
/// Salta las líneas de continuación del ID existente. Si no existe, lo agrega al final.
fn reescribir_clave_ftl(ruta: &std::path::Path, id: &str, nuevo_texto: &str) -> Resultado<()> {
    let contenido = std::fs::read_to_string(ruta).map_err(|e| Bi18nError::ConfigLectura {
        ruta: ruta.to_path_buf(),
        causa: e.to_string(),
    })?;

    let nueva_linea = format!("{} = {}", id, nuevo_texto);
    let mut salida: Vec<String> = Vec::new();
    let mut encontrado = false;
    let lineas: Vec<&str> = contenido.lines().collect();
    let mut i = 0;

    while i < lineas.len() {
        let linea = lineas[i];
        let clave = linea.splitn(2, '=').next().map(|s| s.trim());
        if clave == Some(id) && linea.contains('=') {
            salida.push(nueva_linea.clone());
            encontrado = true;
            i += 1;
            // Saltar líneas de continuación multilínea
            while i < lineas.len()
                && (lineas[i].starts_with(' ') || lineas[i].starts_with('\t'))
            {
                i += 1;
            }
        } else {
            salida.push(linea.to_string());
            i += 1;
        }
    }

    if !encontrado {
        salida.push(nueva_linea);
    }

    let nuevo_contenido = salida.join("\n") + "\n";
    std::fs::write(ruta, nuevo_contenido).map_err(|e| Bi18nError::ConfigLectura {
        ruta: ruta.to_path_buf(),
        causa: e.to_string(),
    })?;
    Ok(())
}
