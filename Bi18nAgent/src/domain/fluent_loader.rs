/// domain/fluent_loader.rs — Cargador de mensajes Fluent para bi18n.
/// Propósito: carga archivos .ftl del directorio `locales/{locale}/` y expone
///   `traducir(id, args)` para mensajes localizados con plurales y variables.
///   Recargable en SIGHUP sin reiniciar el daemon (recargar + swap atómico).
///   Usa FluentBundle::new_concurrent → thread-safe (Arc sin Mutex adicional).
/// Referencia: Project Fluent <https://projectfluent.org/> · fluent-bundle 0.15
/// Dependencias: fluent-bundle, unic-langid, crate::error
use fluent_bundle::{
    concurrent::FluentBundle, FluentArgs, FluentResource,
};
use unic_langid::LanguageIdentifier;
use std::{
    path::Path,
    sync::{Arc, RwLock},
};
use crate::error::{Bi18nError, Resultado};

/// Tipo de bundle thread-safe (concurrent IntlLangMemoizer).
type Bundle = FluentBundle<FluentResource>;

/// Cargador de mensajes Fluent.
/// Clonación barata por Arc interno — compartido entre todos los handlers.
#[derive(Clone)]
pub struct FluentLoader {
    bundle: Arc<RwLock<Bundle>>,
    locale: String,
}

impl FluentLoader {
    /// Carga el bundle inicial para el locale indicado.
    /// Lee todos los `.ftl` de `fluent_dir/{locale}/`.
    pub fn cargar(locale: &str, fluent_dir: &Path) -> Resultado<Self> {
        let bundle = construir_bundle(locale, fluent_dir)?;
        Ok(Self {
            bundle: Arc::new(RwLock::new(bundle)),
            locale: locale.to_string(),
        })
    }

    /// Recarga todos los archivos FTL sin reiniciar el daemon (SIGHUP).
    /// Swap atómico: mientras se construye el nuevo bundle, el anterior sigue activo.
    pub fn recargar(&self, fluent_dir: &Path) -> Resultado<()> {
        let nuevo = construir_bundle(&self.locale, fluent_dir)?;
        let mut guard = self.bundle.write()
            .map_err(|_| Bi18nError::ConfigFaltante { parametro: "fluent_loader_lock" })?;
        *guard = nuevo;
        tracing::info!("Fluent: bundle '{}' recargado", self.locale);
        Ok(())
    }

    /// Traduce un mensaje con argumentos opcionales.
    /// Si el id no existe o el bundle no está disponible, retorna el id sin modificar.
    pub fn traducir<'a>(&self, id: &str, args: Option<&'a FluentArgs<'a>>) -> String {
        let Ok(guard) = self.bundle.read() else { return id.to_string() };
        let Some(msg) = guard.get_message(id) else { return id.to_string() };
        let Some(pattern) = msg.value() else { return id.to_string() };
        let mut errores = vec![];
        guard.format_pattern(pattern, args, &mut errores).to_string()
    }

    /// Construye args de un solo argumento entero (útil para plurales).
    pub fn args_n(n: i64) -> FluentArgs<'static> {
        let mut args = FluentArgs::new();
        args.set("n", n);
        args
    }

    /// Verifica si el bundle tiene un mensaje dado.
    pub fn tiene_mensaje(&self, id: &str) -> bool {
        self.bundle.read()
            .map(|g| g.has_message(id))
            .unwrap_or(false)
    }
}

/// Construye un FluentBundle concurrent desde el directorio de locale.
/// Carga todos los archivos `.ftl` encontrados en `fluent_dir/{locale}/`.
/// Si el directorio no existe, devuelve bundle vacío (fallback al id literal).
fn construir_bundle(locale: &str, fluent_dir: &Path) -> Resultado<Bundle> {
    let langid: LanguageIdentifier = locale.parse()
        .unwrap_or_else(|_| "und".parse().expect("und es un locale válido"));

    let mut bundle: Bundle = FluentBundle::new_concurrent(vec![langid]);
    // Sin caracteres de aislamiento bidi (más legible en terminales y logs)
    bundle.set_use_isolating(false);

    let locale_dir = fluent_dir.join(locale);
    if !locale_dir.exists() {
        tracing::warn!("Fluent: directorio no encontrado: {:?} — usando fallback literal", locale_dir);
        return Ok(bundle);
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

    Ok(bundle)
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
        // Si el directorio es-ZZ no existe, el loader no falla — devuelve bundle vacío
        let loader = FluentLoader::cargar("es-ZZ", &ruta_locales()).unwrap();
        let msg = loader.traducir("error-email-invalido", None);
        // Fallback: devuelve el id
        assert_eq!(msg, "error-email-invalido");
    }
}
