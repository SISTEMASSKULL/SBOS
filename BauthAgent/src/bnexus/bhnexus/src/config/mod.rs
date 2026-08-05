//! Configuración de bhnexus desde bhnexus.toml.
//! DOC-SBOS-001 N3 · SBOS-050 (puertos) · SBOS-049 (ctx_id)

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

    #[error("dev_mode=true está prohibido en SBOS_ENV=production")]
    DevModeEnProduccion,
}

/// Configuración raíz de bhnexus.
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct BhnexusConfig {
    pub servidor: ServidorConfig,
    pub dev: DevConfig,
    pub bauth: BauthConfig,
}

/// Parámetros de red del servidor.
#[derive(Debug, Deserialize)]
pub struct ServidorConfig {
    /// Socket Unix para Interface Dual (WebSocket RPC + JSON-RPC 2.0).
    pub socket_unix: String,
    /// Puerto TCP para Puerta 1 (banexus agents). SBOS-050: 9444.
    pub puerto_puerta1: u16,
}

/// Parámetros de modo desarrollo (Etapa 1 — solo dev CA autofirmada).
#[derive(Debug, Deserialize)]
pub struct DevConfig {
    /// Habilita dev CA autofirmada. PROHIBIDO en producción.
    pub dev_mode: bool,
    /// Ruta al cert de la dev CA (PEM). Generada con rcgen al arrancar si no existe.
    pub dev_ca_cert: String,
    /// Ruta a la clave privada de la dev CA (PEM).
    pub dev_ca_key: String,
}

/// Conexión a bAuth para validación JWT.
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct BauthConfig {
    /// Socket Unix de bAuth para obtener JWKS (bauth.token.jwks — RFC 7517).
    pub jwks_socket: String,
    /// Método JSON-RPC para obtener la clave pública Ed25519.
    pub jwks_method: String,
}

impl BhnexusConfig {
    /// Carga la configuración desde un archivo TOML.
    pub fn cargar(ruta: impl AsRef<Path>) -> Result<Self, ConfigError> {
        let ruta_str = ruta.as_ref().display().to_string();
        let contenido = std::fs::read_to_string(&ruta).map_err(|causa| {
            ConfigError::LecturaFallida { ruta: ruta_str.clone(), causa }
        })?;
        toml::from_str(&contenido).map_err(|causa| {
            ConfigError::TomlInvalido { ruta: ruta_str, causa }
        })
    }

    /// Valida que dev_mode no esté activo en producción.
    pub fn validar_entorno(&self) -> Result<(), ConfigError> {
        if self.dev.dev_mode
            && std::env::var("SBOS_ENV").unwrap_or_default() == "production"
        {
            return Err(ConfigError::DevModeEnProduccion);
        }
        Ok(())
    }
}

impl Default for BhnexusConfig {
    fn default() -> Self {
        Self {
            servidor: ServidorConfig {
                socket_unix: "/run/bos/bhnexus.sock".into(),
                puerto_puerta1: 9444,
            },
            dev: DevConfig {
                dev_mode: true,
                dev_ca_cert: "/etc/bhnexus/dev/ca.crt".into(),
                dev_ca_key: "/etc/bhnexus/dev/ca.key".into(),
            },
            bauth: BauthConfig {
                jwks_socket: "/run/bos/bauth.sock".into(),
                jwks_method: "bauth.token.jwks".into(),
            },
        }
    }
}
