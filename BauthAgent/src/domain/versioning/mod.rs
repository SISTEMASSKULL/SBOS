// ==================================================================
// bauth::domain::versioning — Tipos puros para versionado B01 + B02
//
// Sin I/O, sin DB, sin HTTP. Solo contratos de datos.
//
// B01: T-152 idn_roles_ver_b01_audit_log  (historial WORM de versiones)
// B02: T-B02L idn_roles_rol_lifecycle_event (log WORM de ciclo de vida)
//
// NIST SP 800-53 AU-9 · ISO 27001:2022 A.8.15 · ANSI INCITS 359-2004 §4.3
// ==================================================================

#![allow(dead_code)]

pub mod approval;
pub mod audit;
pub mod blocks;
pub mod classify;
pub mod lifecycle;
pub mod policy;
pub mod reconcile;
pub mod semver;
pub mod transitions;

pub use transitions::{db_a_lifecycle, lifecycle_a_db, validar_transicion};

use serde::{Deserialize, Serialize};

/// Espejo Rust del ENUM PostgreSQL `rol_status_enum`.
/// Sincronizar con el DDL si se agrega un estado.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum RolStatusDb {
    /// Rol activo, asignable a nuevos usuarios.
    Active,
    /// Rol inactivo: creado pero no desplegado.
    Inactive,
    /// Rol suspendido temporalmente por decisión operativa.
    Suspended,
    /// Rol deprecado: ya no se asigna a nuevos usuarios.
    Deprecated,
    /// Rol archivado: solo existe en logs de auditoría (estado terminal).
    Archived,
    /// Rol bajo revisión IGA (B02 — campaña de recertificación).
    InReview,
}

impl RolStatusDb {
    /// Convierte al string exacto del ENUM PostgreSQL `rol_status_enum`.
    pub fn as_str(&self) -> &'static str {
        match self {
            RolStatusDb::Active => "ACTIVE",
            RolStatusDb::Inactive => "INACTIVE",
            RolStatusDb::Suspended => "SUSPENDED",
            RolStatusDb::Deprecated => "DEPRECATED",
            RolStatusDb::Archived => "ARCHIVED",
            RolStatusDb::InReview => "IN_REVIEW",
        }
    }
}

impl std::fmt::Display for RolStatusDb {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl std::str::FromStr for RolStatusDb {
    type Err = VersioningError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "ACTIVE" => Ok(RolStatusDb::Active),
            "INACTIVE" => Ok(RolStatusDb::Inactive),
            "SUSPENDED" => Ok(RolStatusDb::Suspended),
            "DEPRECATED" => Ok(RolStatusDb::Deprecated),
            "ARCHIVED" => Ok(RolStatusDb::Archived),
            "IN_REVIEW" => Ok(RolStatusDb::InReview),
            otro => Err(VersioningError::EstadoInvalido(otro.to_string())),
        }
    }
}

/// Disparador que inicia un evento de ciclo de vida de rol.
/// Espejo de la columna `trigger_type` (TEXT + CHECK) en T-B02L.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TriggerType {
    /// Acción explícita de un actor humano (operador, administrador).
    Manual,
    /// Expiración automática disparada por trigger `trg_irrh_b02_validity`.
    AutoExpiry,
    /// Expiración detectada y corregida por `fn_b02_reconcile_expiry()`.
    Reconcile,
    /// Revisión periódica del motor IGA (campaña de recertificación).
    IgaReview,
    /// Acceso de emergencia break-glass (RFC 9470 Step-Up Auth).
    Breakglass,
    /// Creación inicial durante bootstrap del sistema.
    Bootstrap,
}

impl TriggerType {
    /// Convierte al string de la columna `trigger_type` en BD.
    pub fn as_str(&self) -> &'static str {
        match self {
            TriggerType::Manual => "MANUAL",
            TriggerType::AutoExpiry => "AUTO_EXPIRY",
            TriggerType::Reconcile => "RECONCILE",
            TriggerType::IgaReview => "IGA_REVIEW",
            TriggerType::Breakglass => "BREAKGLASS",
            TriggerType::Bootstrap => "BOOTSTRAP",
        }
    }
}

impl std::fmt::Display for TriggerType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Clasificación semántica del cambio en una versión de rol.
/// Espejo del ENUM `bauth.ver_semver_change_enum` en T-152.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ChangeType {
    /// Cambio incompatible: nuevos átomos, cambio de tier, reestructura.
    /// BD exige: change_reason IS NOT NULL y is_anchor = true.
    Major,
    /// Cambio compatible: ajuste de políticas, metadatos, descripciones.
    Minor,
    /// Corrección interna: typos, referencias, sin impacto funcional.
    Patch,
}

impl ChangeType {
    /// Convierte al string del ENUM `bauth.ver_semver_change_enum`.
    pub fn as_str(&self) -> &'static str {
        match self {
            ChangeType::Major => "MAJOR",
            ChangeType::Minor => "MINOR",
            ChangeType::Patch => "PATCH",
        }
    }
}

impl std::fmt::Display for ChangeType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Canal de entrada del cambio de versión.
/// Espejo del ENUM `bauth.ver_channel_enum` en T-152.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ChangeChannel {
    /// Cambio realizado vía API JSON-RPC (actor humano o integración).
    Api,
    /// Cambio aplicado vía CLI bauthctl (operación administrativa).
    Cli,
    /// Cambio generado durante el bootstrap inicial del sistema.
    Bootstrap,
    /// Cambio aplicado por el reconcile loop automático.
    Reconcile,
}

impl ChangeChannel {
    /// Convierte al string del ENUM `bauth.ver_channel_enum`.
    pub fn as_str(&self) -> &'static str {
        match self {
            ChangeChannel::Api => "API",
            ChangeChannel::Cli => "CLI",
            ChangeChannel::Bootstrap => "BOOTSTRAP",
            ChangeChannel::Reconcile => "RECONCILE",
        }
    }
}

impl std::fmt::Display for ChangeChannel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Errores del módulo de versionado.
#[derive(Debug, thiserror::Error)]
pub enum VersioningError {
    /// El string recibido no corresponde a ningún estado de rol conocido.
    #[error("estado de rol inválido: '{0}'")]
    EstadoInvalido(String),
    /// La transición entre estados no está permitida por las reglas de dominio.
    #[error("transición no permitida: {0} → {1}")]
    TransicionNoPermitida(String, String),
    /// Error de base de datos durante la escritura de logs de versionado.
    #[error("error de BD en versionado: {0}")]
    Db(String),
    /// El cambio MAJOR requiere `change_reason` no vacío e `is_anchor = true`.
    #[error("cambio MAJOR requiere razón del cambio y is_anchor = true")]
    RequisitosIncompletos,
    /// El bump declarado es menor que el mínimo requerido por los campos cambiados.
    #[error("bump insuficiente: {0}")]
    BumpInsuficiente(String),
    /// Error de formato de versión semántica.
    #[error("versión inválida: {0}")]
    VersionInvalida(String),
    /// Error en la configuración del motor (blocks_map, b3_defaults).
    #[error("error de configuración del motor: {0}")]
    Configuracion(String),
    /// Los campos recibidos no son un objeto JSON válido.
    #[error("campos inválidos: {0}")]
    CamposInvalidos(String),
}

// ── Trait principal ──────────────────────────────────────────────

/// Contrato del motor de versionado bAuth.
///
/// Abstrae las dos operaciones de escritura WORM que el daemon realiza:
/// - Cerrar una versión de rol → T-152 (B01 audit log)
/// - Registrar un cambio de estado → T-B02L (B02 lifecycle log)
///
/// La implementación concreta vive en `src/db/versioning.rs`.
/// Los consumidores (handlers JSON-RPC, reconcile loop) dependen del trait,
/// no de la implementación, lo que permite tests sin BD real.
#[async_trait::async_trait]
pub trait VersioningEngine: Send + Sync {
    /// Registra un evento de cambio de estado en T-B02L.
    ///
    /// Precondición: la transición `from → to` debe haber sido validada
    /// con `validar_transicion()` antes de llamar a este método.
    async fn registrar_evento_lifecycle(
        &self,
        ev: &crate::db::versioning::NuevoEventoLifecycle,
    ) -> Result<uuid::Uuid, VersioningError>;

    /// Cierra una versión de rol y registra el snapshot en T-152.
    ///
    /// Precondición: las precondiciones MAJOR deben haber sido validadas
    /// con `audit::validar_o_error()` antes de llamar a este método.
    async fn registrar_snapshot_auditoria(
        &self,
        snap: &crate::db::versioning::NuevoSnapshotAuditoria,
    ) -> Result<uuid::Uuid, VersioningError>;
}
