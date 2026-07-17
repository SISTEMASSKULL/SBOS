/// domain/fluent_loader.rs — Cargador de mensajes Fluent para bi18n.
/// Propósito: carga archivos .ftl del directorio `locales/{locale}/` y expone
///   traducción, listado e inspección de atributos. Recarga atómica vía
///   TranslationsBundle (ArcSwap) — sin bloqueo de lectores.
///   Usa FluentBundle::new_concurrent → thread-safe (IntlLangMemoizer Send+Sync).
/// Referencia: Project Fluent <https://projectfluent.org/> · fluent-bundle 0.15
/// Dependencias: arc-swap, fluent-bundle, unic-langid, crate::domain::translations, crate::error
use arc_swap::ArcSwap;
use fluent_bundle::{
    concurrent::FluentBundle, FluentArgs, FluentResource,
};
use unic_langid::LanguageIdentifier;
use std::{path::Path, sync::Arc};
use crate::{
    domain::translations::TranslationsBundle,
    error::{Bi18nError, Resultado},
};

/// Tipo de bundle thread-safe (concurrent IntlLangMemoizer).
type Bundle = FluentBundle<FluentResource>;

/// Cargador de mensajes Fluent con swap atómico (Bloque 11.2).
/// Clonación barata por Arc — compartido entre todos los handlers.
/// recargar() usa ArcSwap::store() — lectores en vuelo no se bloquean.
#[derive(Clone)]
pub struct FluentLoader {
    bundle: Arc<TranslationsBundle>,
    locale: String,
    /// IDs de mensajes del bundle activo — swapeados junto con el bundle.
    ids: Arc<ArcSwap<Vec<String>>>,
}

impl FluentLoader {
    /// Carga el bundle inicial para el locale indicado.
    /// Lee todos los `.ftl` de `fluent_dir/{locale}/`.
    pub fn cargar(locale: &str, fluent_dir: &Path) -> Resultado<Self> {
        let (bundle, ids) = construir_bundle(locale, fluent_dir)?;
        Ok(Self {
            bundle: Arc::new(TranslationsBundle::nuevo(bundle)),
            locale: locale.to_string(),
            ids: Arc::new(ArcSwap::new(Arc::new(ids))),
        })
    }

    /// Recarga todos los archivos FTL sin reiniciar el daemon (build-then-swap).
    /// Si el parseo falla, el bundle anterior sigue activo — rollback implícito.
    pub fn recargar(&self, fluent_dir: &Path) -> Resultado<()> {
        let (nuevo, nuevos_ids) = construir_bundle(&self.locale, fluent_dir)?;
        self.bundle.intercambiar(nuevo);
        self.ids.store(Arc::new(nuevos_ids));
        tracing::info!("Fluent: bundle '{}' recargado con swap atómico", self.locale);
        Ok(())
    }

    /// Traduce un mensaje con argumentos opcionales. Fallback: devuelve el id literal.
    pub fn traducir<'a>(&self, id: &str, args: Option<&'a FluentArgs<'a>>) -> String {
        let guard = self.bundle.cargar();
        let bundle: &Bundle = &**guard;
        let Some(msg) = bundle.get_message(id) else { return id.to_string() };
        let Some(pattern) = msg.value() else { return id.to_string() };
        let mut errores = vec![];
        bundle.format_pattern(pattern, args, &mut errores).to_string()
    }

    /// Verifica si el bundle tiene un mensaje dado. Sin bloqueo de escritura.
    pub fn tiene_mensaje(&self, id: &str) -> bool {
        let guard = self.bundle.cargar();
        guard.has_message(id)
    }

    /// Lista todos los IDs de mensajes del bundle activo (copia barata por Arc).
    pub fn listar_ids(&self) -> Vec<String> {
        self.ids.load().as_ref().clone()
    }

    /// Traduce un atributo de un mensaje (`.label`, `.placeholder`, etc.).
    /// Busca el atributo por nombre via iterator — fluent-bundle 0.15 no expone lookup directo.
    /// Devuelve None si el mensaje o atributo no existen.
    pub fn traducir_atributo(&self, id: &str, atributo: &str) -> Option<String> {
        let guard = self.bundle.cargar();
        let bundle: &Bundle = &**guard;
        let msg = bundle.get_message(id)?;
        let attr = msg.attributes().find(|a| a.id() == atributo)?;
        let mut errores = vec![];
        Some(bundle.format_pattern(attr.value(), None, &mut errores).to_string())
    }

    /// Construye FluentArgs de un solo argumento entero (útil para plurales).
    pub fn args_n(n: i64) -> FluentArgs<'static> {
        let mut args = FluentArgs::new();
        args.set("n", n);
        args
    }
}

/// Extrae IDs de mensaje de texto FTL sin dependencias externas.
/// Solo captura identificadores al inicio de línea (no términos ni comentarios).
fn extraer_ids_ftl(contenido: &str) -> Vec<String> {
    let mut ids = Vec::new();
    for linea in contenido.lines() {
        let trimmed = linea.trim_start();
        // Términos (-term), comentarios (#) y líneas vacías o de continuación se ignoran
        if trimmed.starts_with('#') || trimmed.starts_with('-') || trimmed.is_empty() {
            continue;
        }
        let pos = match trimmed.find('=').or_else(|| trimmed.find('(')) {
            Some(p) => p,
            None => continue,
        };
        let id = trimmed[..pos].trim();
        if !id.is_empty() && id.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_') {
            ids.push(id.to_string());
        }
    }
    ids
}

/// Construye un FluentBundle concurrent y extrae los IDs del locale.
/// Si el directorio no existe, devuelve bundle vacío (fallback al id literal).
fn construir_bundle(locale: &str, fluent_dir: &Path) -> Resultado<(Bundle, Vec<String>)> {
    let langid: LanguageIdentifier = locale.parse()
        .unwrap_or_else(|_| "und".parse().expect("und es un locale válido"));

    let mut bundle: Bundle = FluentBundle::new_concurrent(vec![langid]);
    bundle.set_use_isolating(false);
    let mut ids_total: Vec<String> = Vec::new();

    let locale_dir = fluent_dir.join(locale);
    if !locale_dir.exists() {
        tracing::warn!("Fluent: directorio no encontrado: {:?} — bundle vacío", locale_dir);
        return Ok((bundle, ids_total));
    }

    let entradas = std::fs::read_dir(&locale_dir).map_err(|e| Bi18nError::ConfigLectura {
        ruta: locale_dir.clone(),
        causa: e.to_string(),
    })?;

    for entrada in entradas {
        let entrada = entrada.map_err(|e| Bi18nError::ConfigLectura {
            ruta: locale_dir.clone(),
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
        ids_total.extend(extraer_ids_ftl(&contenido));
        let recurso = FluentResource::try_new(contenido).map_err(|(_, errs)| {
            Bi18nError::ConfigParseo {
                ruta: ruta.clone(),
                causa: format!("{errs:?}"),
            }
        })?;
        if let Err(conflictos) = bundle.add_resource(recurso) {
            tracing::warn!("Fluent: conflictos al cargar {:?}: {:?}", ruta, conflictos);
        } else {
            tracing::debug!("Fluent: cargado {:?}", ruta);
        }
    }

    Ok((bundle, ids_total))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn ruta_locales() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("locales")
    }

    #[test]
    fn test_traducir_plural_n1() {
        let loader = FluentLoader::cargar("es-BO", &ruta_locales()).unwrap();
        let args = FluentLoader::args_n(1);
        let msg = loader.traducir("paises-cargados", Some(&args));
        assert_eq!(msg, "1 país cargado");
    }

    #[test]
    fn test_traducir_plural_n5() {
        let loader = FluentLoader::cargar("es-BO", &ruta_locales()).unwrap();
        let args = FluentLoader::args_n(5);
        let msg = loader.traducir("paises-cargados", Some(&args));
        assert_eq!(msg, "5 países cargados");
    }

    #[test]
    fn test_fallback_id_si_no_existe() {
        let loader = FluentLoader::cargar("es-BO", &ruta_locales()).unwrap();
        let msg = loader.traducir("mensaje-inexistente", None);
        assert_eq!(msg, "mensaje-inexistente");
    }

    #[test]
    fn test_locale_faltante_no_falla() {
        let loader = FluentLoader::cargar("es-ZZ", &ruta_locales()).unwrap();
        let msg = loader.traducir("error-email-invalido", None);
        assert_eq!(msg, "error-email-invalido");
    }

    #[test]
    fn test_extraer_ids_ftl_basico() {
        let ftl = "saludo = Hola\n# comentario\n-termino = interno\nboton-aceptar = Aceptar\n";
        let ids = extraer_ids_ftl(ftl);
        assert!(ids.contains(&"saludo".to_string()));
        assert!(ids.contains(&"boton-aceptar".to_string()));
        assert!(!ids.contains(&"-termino".to_string()));
    }
}
