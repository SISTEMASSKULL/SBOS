//! Configuración de banexus desde banexus.toml.
//! mode = "daemon" | "gateway" — mismo binario, distinto despliegue.
//! local_api — TCP listener para Flutter desktop (127.0.0.1:9446).
//! SSOT: BnexusAgent/context/Documentacion/ · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.1-§24.2

use serde::Deserialize;
use std::path::Path;
use thiserror::Error;

/// Errores de configuración con contexto legible.
#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("No se pudo leer {ruta}: {causa}")]
    LecturaFallida { ruta: String, causa: std::io::Error },

    #[error("TOML inválido en {ruta}: {causa}")]
    TomlInvalido { ruta: String, causa: toml::de::Error },

    #[error("mode inválido '{0}' — debe ser 'daemon' o 'gateway'")]
    ModoInvalido(String),
}

/// Modo de operación del agente banexus.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Modo {
    Daemon,
    Gateway,
}

impl std::fmt::Display for Modo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Modo::Daemon  => write!(f, "daemon"),
            Modo::Gateway => write!(f, "gateway"),
        }
    }
}

/// Configuración raíz de banexus.
#[derive(Debug, Clone)]
pub struct BanexusConfig {
    pub agente: AgenteConfig,
    pub dev: DevConfig,
    /// API local TCP para Flutter desktop (127.0.0.1:9446 por defecto).
    pub local_api: LocalApiConfig,
}

/// Parámetros de la API local TCP para el desktop Flutter.
#[derive(Debug, Clone)]
pub struct LocalApiConfig {
    /// Dirección de escucha (default "127.0.0.1" — solo loopback).
    pub addr: String,
    /// Puerto TCP (default 9446). SBOS-050: rango daemons 9400-9499.
    pub puerto: u16,
}

impl Default for LocalApiConfig {
    fn default() -> Self {
        Self { addr: "127.0.0.1".into(), puerto: 9446 }
    }
}

/// Parámetros de conexión y modo del agente.
#[derive(Debug, Clone)]
pub struct AgenteConfig {
    /// Modo de operación: Daemon (workstation/POS) o Gateway (SBC/Pi remoto).
    pub modo: Modo,
    /// Dirección de bhnexus: host:9444.
    pub bhnexus_addr: String,
    /// Identificador único del nodo (persiste entre reinicios).
    pub node_id: String,
}

/// Parámetros de modo desarrollo (Etapa 1).
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct DevConfig {
    pub dev_mode: bool,
    /// Ruta al cert generado por la dev CA de bhnexus.
    pub cert_path: String,
    /// Ruta a la clave privada del agente.
    pub key_path: String,
}

/// Estructura TOML cruda (antes de parsear mode).
#[derive(Deserialize)]
struct ConfigRaw {
    agente: AgenteRaw,
    dev: DevRaw,
    #[serde(default)]
    local_api: LocalApiRaw,
}

#[derive(Deserialize)]
struct LocalApiRaw {
    #[serde(default = "default_local_api_addr")]
    addr: String,
    #[serde(default = "default_local_api_puerto")]
    puerto: u16,
}

fn default_local_api_addr() -> String { "127.0.0.1".into() }
fn default_local_api_puerto() -> u16 { 9446 }

impl Default for LocalApiRaw {
    fn default() -> Self {
        Self { addr: default_local_api_addr(), puerto: default_local_api_puerto() }
    }
}

#[derive(Deserialize)]
struct AgenteRaw {
    mode: String,
    bhnexus_addr: String,
    node_id: String,
}

#[derive(Deserialize)]
struct DevRaw {
    dev_mode: bool,
    cert_path: String,
    key_path: String,
}

impl BanexusConfig {
    /// Carga configuración desde TOML y parsea el campo mode.
    pub fn cargar(ruta: impl AsRef<Path>) -> Result<Self, ConfigError> {
        let ruta_str = ruta.as_ref().display().to_string();
        let contenido = std::fs::read_to_string(&ruta).map_err(|causa| {
            ConfigError::LecturaFallida { ruta: ruta_str.clone(), causa }
        })?;
        let raw: ConfigRaw = toml::from_str(&contenido).map_err(|causa| {
            ConfigError::TomlInvalido { ruta: ruta_str, causa }
        })?;

        let modo = match raw.agente.mode.as_str() {
            "daemon"  => Modo::Daemon,
            "gateway" => Modo::Gateway,
            otro => return Err(ConfigError::ModoInvalido(otro.to_string())),
        };

        Ok(Self {
            agente: AgenteConfig {
                modo,
                bhnexus_addr: raw.agente.bhnexus_addr,
                node_id: raw.agente.node_id,
            },
            dev: DevConfig {
                dev_mode: raw.dev.dev_mode,
                cert_path: raw.dev.cert_path,
                key_path: raw.dev.key_path,
            },
            local_api: LocalApiConfig {
                addr: raw.local_api.addr,
                puerto: raw.local_api.puerto,
            },
        })
    }
}
