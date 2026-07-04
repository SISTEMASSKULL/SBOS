// ================================================================
// bauth::config — Carga y validación de configuración
//
// Carga /etc/bos/bauth.toml al inicio del daemon.
// SIGHUP recarga sin interrumpir conexiones activas.
//
// DOC-SBOS-001 N3: documentación en español.
// Cada struct con doc comment explicando propósito y campos.
// ================================================================

use serde::{Deserialize, Serialize};
use std::path::Path;
use tracing::{info, warn};

/// Error de configuración con mensaje descriptivo en español.
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("archivo de configuración no encontrado en {path}: {source}")]
    FileNotFound { path: String, source: std::io::Error },

    #[error("formato TOML inválido: {source}")]
    InvalidToml { source: toml::de::Error },

    #[error("campo requerido ausente o inválido: {field}")]
    MissingField { field: String },

    #[error("valor inválido para '{field}': {reason}")]
    InvalidValue { field: String, reason: String },
}

/// Configuración raíz del daemon bauth.
/// Cargada desde /etc/bos/bauth.toml.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Configuración del servidor Interface Dual ADR-020.
    #[serde(default)]
    pub server: ServerConfig,

    /// Conexión a PostgreSQL (SBOS_db).
    pub database: DatabaseConfig,

    /// Conexión a Redis (cache + sesiones).
    #[serde(default)]
    pub redis: RedisConfig,

    /// Clientes de motores externos.
    #[serde(default)]
    pub engines: EnginesConfig,

    /// Niveles de auditoría y logging.
    #[serde(default)]
    pub audit: AuditConfig,

    /// Parámetros financieros (precisión decimal, monedas).
    #[serde(default)]
    pub financial: FinancialConfig,

    /// Configuración de emisión de tokens JWT (B48).
    #[serde(default)]
    pub jwt: JwtConfig,

    /// Configuración del screening HIBP (NIST SP 800-63B §5.1.1.2).
    #[serde(default)]
    pub hibp: HibpConfig,
}

/// Configuración del check HIBP k-anonymity (NIST SP 800-63B §5.1.1.2).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct HibpConfig {
    /// URL base de la API HIBP (default: api.pwnedpasswords.com).
    pub api_url: String,
    /// Timeout de red en segundos (default: 5).
    pub timeout_secs: u64,
}

impl Default for HibpConfig {
    fn default() -> Self {
        Self {
            api_url: "https://api.pwnedpasswords.com/range".into(),
            timeout_secs: 5,
        }
    }
}

/// Configuración del módulo JWT de bAuth.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct JwtConfig {
    /// Issuer para tokens JWT (default: bauth.sbos.bo).
    pub issuer: String,
    /// TTL por defecto en segundos (default: 3600 = 1 hora).
    pub default_ttl_seconds: i64,
    /// LoA por defecto (default: 2).
    pub default_loa: i32,
    /// URI del endpoint JWKS.
    pub jwks_uri: String,
}

impl Default for JwtConfig {
    fn default() -> Self {
        Self {
            issuer: "bauth.sbos.bo".into(),
            default_ttl_seconds: 3600,
            default_loa: 2,
            jwks_uri: "https://bauth.sbos.bo/.well-known/jwks.json".into(),
        }
    }
}

/// Configuración del servidor Unix socket.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct ServerConfig {
    /// Ruta del Unix socket (default: /run/bos/bauth.sock).
    #[serde(default = "default_socket_path")]
    pub socket_path: String,

    /// Permisos del socket en octal (default: 0o660).
    #[serde(default = "default_socket_perms")]
    pub socket_perms: u32,

    /// Grupo propietario del socket (default: bosagent).
    #[serde(default = "default_socket_group")]
    pub socket_group: String,

    /// Máximo de conexiones concurrentes.
    #[serde(default = "default_max_connections")]
    pub max_connections: usize,

    /// Tamaño máximo de un request JSON-RPC en bytes (default: 262144 = 256 KB).
    #[serde(default = "default_max_request_bytes")]
    pub max_request_bytes: usize,
}

/// Ruta canónica del socket Unix — fuente única para todo el proyecto.
pub const DEFAULT_SOCKET_PATH: &str = "/run/bos/bauth.sock";
fn default_socket_path() -> String { DEFAULT_SOCKET_PATH.to_string() }
fn default_socket_perms() -> u32 { 0o660 }
fn default_socket_group() -> String { "bosagent".to_string() }
fn default_max_connections() -> usize { 1000 }
fn default_max_request_bytes() -> usize { 256 * 1024 }

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            socket_path: default_socket_path(),
            socket_perms: default_socket_perms(),
            socket_group: default_socket_group(),
            max_connections: default_max_connections(),
            max_request_bytes: default_max_request_bytes(),
        }
    }
}

/// Conexión a PostgreSQL.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseConfig {
    /// URL de conexión: postgres://user:pass@host:port/SBOS_db
    pub url: String,

    /// Máximo de conexiones en el pool.
    #[serde(default = "default_db_pool_size")]
    pub pool_size: u32,

    /// Timeout de conexión en segundos.
    #[serde(default = "default_db_timeout")]
    pub connect_timeout_secs: u64,
}

fn default_db_pool_size() -> u32 {
    10
}
fn default_db_timeout() -> u64 {
    5
}

/// Conexión a Redis.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct RedisConfig {
    /// URL de conexión: redis://host:port
    #[serde(default = "default_redis_url")]
    pub url: String,

    /// TTL por defecto para cache (segundos).
    #[serde(default = "default_redis_ttl")]
    pub default_ttl_secs: u64,
}

impl Default for RedisConfig {
    fn default() -> Self {
        Self {
            url: default_redis_url(),
            default_ttl_secs: default_redis_ttl(),
        }
    }
}

fn default_redis_url() -> String {
    "redis://localhost:6379".to_string()
}
fn default_redis_ttl() -> u64 {
    30
}

/// Configuración de motores externos.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EnginesConfig {
    pub keycloak: Option<KeycloakConfig>,
    pub nexus: Option<NexusConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeycloakConfig {
    pub base_url: String,
    pub admin_realm: String,
    pub client_id: String,
    pub client_secret_vault_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NexusConfig {
    pub grpc_socket_path: String,
}

/// Configuración de auditoría.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct AuditConfig {
    /// Nivel de auditoría por defecto para roles sin config explícita.
    #[serde(default = "default_audit_level")]
    pub default_level: String,
}

fn default_audit_level() -> String { "basic".to_string() }

impl Default for AuditConfig {
    fn default() -> Self {
        Self { default_level: default_audit_level() }
    }
}

/// Parámetros financieros configurables por tenant/entorno.
/// Sin hardcodear — los estándares pueden cambiar (ISO 20022, ERC-20, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct FinancialConfig {
    /// Precisión decimal mínima para montos monetarios.
    /// ISO 20022: 13 (ActiveCurrencyAnd13DecimalAmount).
    #[serde(default = "default_financial_decimals")]
    pub decimal_places: usize,
}

fn default_financial_decimals() -> usize { 13 }

impl Default for FinancialConfig {
    fn default() -> Self {
        Self { decimal_places: default_financial_decimals() }
    }
}

// ── CARGA Y VALIDACIÓN ─────────────────────────────────────────

/// Ruta canónica del archivo de configuración.
const CONFIG_PATH: &str = "/etc/bos/bauth.toml";

/// Carga la configuración desde /etc/bos/bauth.toml.
/// Valida campos requeridos y aplica defaults.
pub fn load() -> Result<Config, ConfigError> {
    load_from(CONFIG_PATH)
}

/// Carga configuración desde una ruta específica (útil para testing).
pub fn load_from(path: impl AsRef<Path>) -> Result<Config, ConfigError> {
    let path = path.as_ref();
    let contents = std::fs::read_to_string(path).map_err(|e| ConfigError::FileNotFound {
        path: path.display().to_string(),
        source: e,
    })?;

    let cfg: Config = toml::from_str(&contents).map_err(|e| ConfigError::InvalidToml { source: e })?;

    cfg.validate()?;

    Ok(cfg)
}

/// Recarga la configuración sin reiniciar el daemon (SIGHUP).
/// TODO: implementar hot-reload con Arc<Swap> sin interrumpir conexiones.
pub fn reload() -> Result<(), ConfigError> {
    let _cfg = load()?;
    warn!("H-013: SIGHUP — configuracion recargada del archivo pero estado global NO actualizado. Se requiere reinicio para aplicar cambios.");
    Ok(())
}

impl Config {
    /// Valida que los campos requeridos estén presentes y tengan valores coherentes.
    fn validate(&self) -> Result<(), ConfigError> {
        // database.url es obligatorio
        if self.database.url.is_empty() {
            return Err(ConfigError::MissingField {
                field: "database.url".to_string(),
            });
        }

        // database.url debe comenzar con postgres:// o postgresql://
        if !self.database.url.starts_with("postgres://")
            && !self.database.url.starts_with("postgresql://")
        {
            return Err(ConfigError::InvalidValue {
                field: "database.url".to_string(),
                reason: "debe comenzar con postgres:// o postgresql://".to_string(),
            });
        }

        // pool_size debe ser >= 1
        if self.database.pool_size < 1 {
            return Err(ConfigError::InvalidValue {
                field: "database.pool_size".to_string(),
                reason: "debe ser >= 1".to_string(),
            });
        }

        // socket_path no puede estar vacío
        if self.server.socket_path.is_empty() {
            return Err(ConfigError::MissingField {
                field: "server.socket_path".to_string(),
            });
        }

        // redis url no puede estar vacía
        if self.redis.url.is_empty() {
            return Err(ConfigError::MissingField {
                field: "redis.url".to_string(),
            });
        }

        // audit_level debe ser "basic" o "full"
        if self.audit.default_level != "basic" && self.audit.default_level != "full" {
            return Err(ConfigError::InvalidValue {
                field: "audit.default_level".to_string(),
                reason: "debe ser 'basic' o 'full'".to_string(),
            });
        }

        Ok(())
    }
}

// ── TESTS ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    /// Crea un archivo TOML temporal para testing.
    fn write_temp_config(content: &str) -> tempfile::TempPath {
        let mut file = tempfile::NamedTempFile::new().unwrap();
        file.write_all(content.as_bytes()).unwrap();
        file.into_temp_path()
    }

    #[test]
    fn test_server_defaults() {
        assert_eq!(default_socket_path(), "/run/bos/bauth.sock");
        assert_eq!(default_socket_perms(), 0o660);
        assert_eq!(default_socket_group(), "bosagent");
    }

    #[test]
    fn test_valid_config_loads() {
        let path = write_temp_config(
            r#"[server]
socket_path = "/run/bos/bauth.sock"

[database]
url = "postgres://bauth:pass@localhost:5432/SBOS_db"
"#,
        );
        let cfg = load_from(&path).unwrap();
        assert_eq!(cfg.database.url, "postgres://bauth:pass@localhost:5432/SBOS_db");
        assert_eq!(cfg.server.socket_path, "/run/bos/bauth.sock");
    }

    #[test]
    fn test_reject_empty_database_url() {
        let path = write_temp_config(
            r#"[database]
url = ""
"#,
        );
        let err = load_from(&path).unwrap_err();
        assert!(err.to_string().contains("database.url"));
    }

    #[test]
    fn test_reject_invalid_database_url() {
        let path = write_temp_config(
            r#"[database]
url = "mysql://localhost/db"
"#,
        );
        let err = load_from(&path).unwrap_err();
        assert!(err.to_string().contains("postgres://"));
    }

    #[test]
    fn test_reject_invalid_audit_level() {
        let path = write_temp_config(
            r#"[server]
socket_path = "/run/bos/bauth.sock"

[database]
url = "postgres://localhost/SBOS_db"

[audit]
default_level = "debug"
"#,
        );
        let err = load_from(&path).unwrap_err();
        assert!(err.to_string().contains("audit.default_level"));
    }

    #[test]
    fn test_file_not_found() {
        let result = load_from("/tmp/nonexistent_bauth_config_test.toml");
        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_toml_syntax() {
        let path = write_temp_config("esto no es toml {{{");
        let result = load_from(&path);
        assert!(result.is_err());
    }

    #[test]
    fn test_default_values_applied() {
        let path = write_temp_config(
            r#"[server]
socket_path = "/run/bos/bauth.sock"

[database]
url = "postgres://localhost/SBOS_db"
"#,
        );
        let cfg = load_from(&path).unwrap();
        assert_eq!(cfg.redis.url, "redis://localhost:6379");
        assert_eq!(cfg.redis.default_ttl_secs, 30);
        assert_eq!(cfg.audit.default_level, "basic");
    }
}
