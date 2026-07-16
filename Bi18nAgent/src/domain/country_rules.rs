/// domain/country_rules.rs — Catálogo de reglas por país (GAP-02 resuelto).
/// Propósito: carga y mantiene en caché los archivos country-rules/{iso}.toml.
///   - Sin PostgreSQL — bi18n es stateless; datos viven en TOML en disco.
///   - Recarga atómica en SIGHUP: RwLock swap solo si todos los TOML son válidos.
///   - Rollback automático si algún TOML falla durante la recarga (GAP-03).
/// Dependencias: serde, toml, tokio::sync::RwLock, crate::error
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::Arc,
};
use serde::Deserialize;
use tokio::sync::RwLock;
use crate::error::{Bi18nError, Resultado};

/// Código de país ISO 3166-1 alpha-2 (ej: "BO", "AR", "BR").
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct IsoAlpha2(pub String);

impl IsoAlpha2 {
    pub fn nuevo(s: &str) -> Self {
        Self(s.to_uppercase())
    }
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Reglas de un país cargadas desde country-rules/{iso}.toml.
#[derive(Debug, Clone, Deserialize)]
pub struct CountryRules {
    #[serde(default)]
    pub moneda: Option<MonedaRules>,
    #[serde(default)]
    pub pais: Option<PaisRules>,
    #[serde(default)]
    pub documentos: HashMap<String, DocumentoRules>,
    #[serde(default)]
    pub mascaras: HashMap<String, MascaraRules>,
    /// Catálogo de etiquetas localizadas por enum de negocio.
    /// Estructura: { "gender": { "M": "Masculino", "F": "Femenino" } }
    /// Usado por EnumService.Display (Fase 2 — actualmente con catálogo embebido).
    #[serde(default)]
    pub enums: HashMap<String, HashMap<String, String>>,
}

/// Reglas de moneda local (GAP-02 — sin bglobal en línea).
#[derive(Debug, Clone, Deserialize)]
pub struct MonedaRules {
    pub iso4217: String,
    pub simbolo_local: String,
    pub simbolo_intl: String,
    pub decimales: u8,
    pub sep_decimal: String,
    pub sep_miles: String,
}

/// Metadatos del país para resolución de locale y formatos.
#[derive(Debug, Clone, Deserialize)]
pub struct PaisRules {
    pub iso_alpha2: String,
    pub iso_alpha3: String,
    pub codigo_telefono: String,
    pub locale_defecto: String,
    pub tz_defecto: String,
    pub ltr: bool,
}

/// Reglas de validación de un documento de identidad nacional.
#[derive(Debug, Clone, Deserialize)]
pub struct DocumentoRules {
    /// Expresión regular de validación. Ejemplo: r"^\d{6,8}-[A-Z]{2}$"
    pub regex: String,
    /// Ejemplo de valor válido para el Testeador.
    pub ejemplo: String,
    /// Mensaje de error localizado en español.
    pub error_mensaje: String,
}

/// Reglas de enmascaramiento PII definidas por el país.
#[derive(Debug, Clone, Deserialize)]
pub struct MascaraRules {
    /// Estrategia: "full" | "partial" | "prefix" | "both"
    pub estrategia: String,
    pub n: Option<u32>,
    pub prefix_visible: Option<u32>,
    pub suffix_visible: Option<u32>,
}

/// Loader de reglas de países con recarga atómica SIGHUP (GAP-03).
pub struct CountryRulesLoader {
    /// Mapa en caché: ISO alpha-2 → reglas.
    /// RwLock permite lecturas concurrentes sin bloqueo.
    reglas: Arc<RwLock<HashMap<IsoAlpha2, CountryRules>>>,
    /// Directorio base donde viven los TOML.
    dir: PathBuf,
}

impl CountryRulesLoader {
    /// Construye el loader y carga todos los TOML del directorio.
    pub async fn nuevo(dir: &Path) -> Resultado<Self> {
        let reglas = cargar_directorio(dir).await?;
        Ok(Self {
            reglas: Arc::new(RwLock::new(reglas)),
            dir: dir.to_path_buf(),
        })
    }

    /// Retorna las reglas de un país. Error si el TOML no está en caché.
    pub async fn obtener(&self, iso: &IsoAlpha2) -> Resultado<CountryRules> {
        let mapa = self.reglas.read().await;
        mapa.get(iso)
            .cloned()
            .ok_or_else(|| Bi18nError::PaisNoEncontrado {
                iso: iso.as_str().to_string(),
                causa: "país no cargado en country-rules".to_string(),
            })
    }

    /// Recarga todos los TOML atómicamente (SIGHUP — GAP-03).
    /// Si algún TOML falla, el mapa anterior NO se toca (rollback implícito).
    pub async fn recargar(&self) -> Resultado<usize> {
        let nuevo_mapa = cargar_directorio(&self.dir).await?;
        let n = nuevo_mapa.len();
        // Escritura: solo en este punto, después de validar todos los TOML.
        *self.reglas.write().await = nuevo_mapa;
        tracing::info!("country-rules recargados: {} países", n);
        Ok(n)
    }

    /// Número de países actualmente en caché.
    pub async fn total(&self) -> usize {
        self.reglas.read().await.len()
    }
}

/// Carga todos los archivos {iso}.toml del directorio en un HashMap.
/// Falla si el directorio no existe o si algún TOML tiene errores de sintaxis.
async fn cargar_directorio(dir: &Path) -> Resultado<HashMap<IsoAlpha2, CountryRules>> {
    let mut entradas = tokio::fs::read_dir(dir)
        .await
        .map_err(|e| Bi18nError::PaisDirectorio {
            ruta: dir.to_path_buf(),
            causa: e.to_string(),
        })?;

    let mut mapa = HashMap::new();

    while let Some(entrada) = entradas.next_entry().await.map_err(|e| Bi18nError::Io(e))? {
        let ruta = entrada.path();
        if ruta.extension().and_then(|e| e.to_str()) != Some("toml") {
            continue;
        }
        let iso = ruta
            .file_stem()
            .and_then(|s| s.to_str())
            .map(|s| IsoAlpha2::nuevo(s))
            .unwrap_or_else(|| IsoAlpha2::nuevo("XX"));

        let contenido = tokio::fs::read_to_string(&ruta)
            .await
            .map_err(|e| Bi18nError::PaisNoEncontrado {
                iso: iso.as_str().to_string(),
                causa: e.to_string(),
            })?;

        let reglas: CountryRules = toml::from_str(&contenido)
            .map_err(|e| Bi18nError::PaisParseo {
                ruta: ruta.clone(),
                causa: e.to_string(),
            })?;

        mapa.insert(iso, reglas);
    }

    Ok(mapa)
}
