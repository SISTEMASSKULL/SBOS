/// config/mod.rs — Configuración del daemon bi18n-daemon-orchestrator.
/// Propósito: carga y valida /etc/bos/bi18n.toml al arrancar.
///   - Resolución de rutas absolutas (C7 — sin hardcodes).
///   - Valores por defecto explícitos para campos opcionales.
///   - Validación semántica antes de retornar (C6).
/// Dependencias: serde, toml, thiserror, crate::error
use std::path::{Path, PathBuf};
use serde::{Deserialize, Serialize};
use crate::error::{Bi18nError, Resultado};

/// Configuración principal leída de bi18n.toml.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub servidor: ServidorConfig,
    pub regional: RegionalDefecto,
    pub rutas: RutasConfig,
    pub log: LogConfig,
}

/// Parámetros de los sockets Unix (Interface Triple C11).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServidorConfig {
    /// Ruta del socket JSON-RPC + WebSocket. Valor por defecto: /run/bos/bi18n.sock
    pub socket_path: PathBuf,
    /// Ruta del socket gRPC (Unix domain, sin TCP). Valor por defecto: /run/bos/bi18n-grpc.sock
    pub grpc_socket_path: PathBuf,
    /// Segundos máximos de drenado de conexiones activas en SIGHUP (GAP-03).
    pub drain_timeout_secs: u64,
}

/// Configuración regional por defecto para MVP (GAP-01 — estática).
/// En producción bAuth envía RegionalConfig en cada request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegionalDefecto {
    /// BCP 47. Ejemplo: "es-BO"
    pub locale: String,
    /// IANA tzdata. Ejemplo: "America/La_Paz"
    pub timezone: String,
    /// ISO 4217. Ejemplo: "BOB"
    pub currency: String,
    /// ISO 3166-1 alpha-2. Ejemplo: "BO"
    pub country: String,
}

/// Rutas de datos en el sistema de archivos.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RutasConfig {
    /// Directorio con los archivos country-rules/{iso}.toml (GAP-02).
    pub country_rules_dir: PathBuf,
    /// Directorio con los archivos de traducción Fluent (.ftl).
    pub fluent_dir: PathBuf,
}

/// Configuración de logging (tracing-subscriber).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogConfig {
    /// Nivel de log: "trace" | "debug" | "info" | "warn" | "error"
    pub nivel: String,
    /// Si true, emite JSON estructurado; si false, texto legible por humano.
    pub json: bool,
}

impl Default for Config {
    /// Valores por defecto usados en ausencia de /etc/bos/bi18n.toml.
    /// Solo para pruebas locales — en producción siempre debe existir el TOML.
    fn default() -> Self {
        Self {
            servidor: ServidorConfig {
                socket_path: PathBuf::from("/run/bos/bi18n.sock"),
                grpc_socket_path: PathBuf::from("/run/bos/bi18n-grpc.sock"),
                drain_timeout_secs: 5,
            },
            regional: RegionalDefecto {
                locale: "es-BO".to_string(),
                timezone: "America/La_Paz".to_string(),
                currency: "BOB".to_string(),
                country: "BO".to_string(),
            },
            rutas: RutasConfig {
                country_rules_dir: PathBuf::from("/etc/bos/bi18n/country-rules"),
                fluent_dir: PathBuf::from("/etc/bos/bi18n/locales"),
            },
            log: LogConfig {
                nivel: "info".to_string(),
                json: true,
            },
        }
    }
}

/// Inicializa el subsistema de logging con el formato y nivel configurados.
pub fn inicializar_log(log_cfg: &LogConfig) {
    use tracing_subscriber::{fmt, EnvFilter};
    let filtro = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(&log_cfg.nivel));
    if log_cfg.json {
        fmt().json().with_env_filter(filtro).init();
    } else {
        fmt().with_env_filter(filtro).init();
    }
}

/// Carga la configuración desde la ruta indicada.
/// Falla rápido si el archivo no existe o tiene errores de parseo.
pub fn cargar(ruta: &Path) -> Resultado<Config> {
    let contenido = std::fs::read_to_string(ruta)
        .map_err(|e| Bi18nError::ConfigLectura {
            ruta: ruta.to_path_buf(),
            causa: e.to_string(),
        })?;

    let config: Config = toml::from_str(&contenido)
        .map_err(|e| Bi18nError::ConfigParseo {
            ruta: ruta.to_path_buf(),
            causa: e.to_string(),
        })?;

    validar(&config)?;
    Ok(config)
}

/// Valida las restricciones semánticas de la configuración.
fn validar(cfg: &Config) -> Resultado<()> {
    if cfg.regional.locale.is_empty() {
        return Err(Bi18nError::ConfigFaltante { parametro: "regional.locale" });
    }
    if cfg.regional.timezone.is_empty() {
        return Err(Bi18nError::ConfigFaltante { parametro: "regional.timezone" });
    }
    if cfg.regional.currency.len() != 3 {
        return Err(Bi18nError::ConfigFaltante { parametro: "regional.currency (debe ser ISO 4217 de 3 letras)" });
    }
    if cfg.regional.country.len() != 2 {
        return Err(Bi18nError::ConfigFaltante { parametro: "regional.country (debe ser ISO 3166-1 alpha-2)" });
    }
    Ok(())
}
