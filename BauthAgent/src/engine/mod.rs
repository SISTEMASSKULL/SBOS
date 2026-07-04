// ================================================================
// bauth::engine — Traits del framework orquestador (B1.T01-T02)
//
// ADR-004: bAuth es un Framework que ORQUESTA, no un engine monolítico.
// Cada motor externo implementa AuthEngine. EngineRegistry permite
// registrar nuevos motores sin modificar el core (Open/Closed).
//
// Motores implementados:
//   KeycloakEngine — B12: Admin REST API para identidad (OIDC, SAML, WebAuthn)
//   TrytonEngine   — B13: DEPRECADO (ADR-010, 2026-06-28)
//
// DOC-SBOS-001 N3 · BAUTH-ARQUITECTURA-FRAMEWORK.md
// ================================================================
#![allow(dead_code)]

pub mod keycloak_engine;
pub mod vault_engine;  // G6: Vault PKI — emision de certificados X.509

use std::collections::HashMap;
use std::sync::Arc;
use thiserror::Error;
use tracing::info;

// ── TRAIT AuthEngine (B1.T01) ──────────────────────────────

/// Trait que todo motor de autenticación debe implementar.
///
/// # Reglas del framework
/// - Ningún motor se consulta directamente desde fuera de bAuth
/// - Cada motor declara qué dominios cubre (`covered_domains`)
/// - Salida normalizada a JWT con BitmaskBundle
/// - Motores independientes: fallo en uno no afecta a otros
#[async_trait::async_trait]
pub trait AuthEngine: Send + Sync {
    /// Nombre único del motor. Ej: "keycloak", "tryton", "nexus".
    fn name(&self) -> &str;

    /// Dominios que este motor cubre.
    fn covered_domains(&self) -> Vec<String>;

    /// Sincronizar un RolTemplate con este motor.
    async fn sync_role(&self, role_id: &str, tenant_id: &str) -> Result<(), EngineError>;

    /// Sincronizar un UserTemplate con este motor.
    async fn sync_user(&self, user_uuid: &str, tenant_id: &str) -> Result<(), EngineError>;

    /// Reconciliar: comparar estado real vs bauth_db y corregir drift.
    async fn reconcile(&self, tenant_id: &str) -> Result<ReconcileReport, EngineError>;

    /// Health check del motor.
    async fn health_check(&self) -> bool;
}

/// Reporte de reconciliación.
#[derive(Debug, Clone, Default)]
pub struct ReconcileReport {
    pub engine_name: String,
    pub roles_created: usize,
    pub roles_updated: usize,
    pub roles_deleted: usize,
    pub users_created: usize,
    pub users_updated: usize,
    pub users_disabled: usize,
    pub errors: Vec<String>,
}

impl ReconcileReport {
    pub fn total_changes(&self) -> usize {
        self.roles_created + self.roles_updated + self.roles_deleted
            + self.users_created + self.users_updated + self.users_disabled
    }
}

/// Error de motor con mensaje en español.
#[derive(Debug, Error)]
pub enum EngineError {
    #[error("motor '{engine}': error de conexión: {message}")]
    Connection { engine: String, message: String },

    #[error("motor '{engine}': timeout ({timeout_secs}s)")]
    Timeout { engine: String, timeout_secs: u64 },

    #[error("motor '{engine}': operación rechazada: {reason}")]
    Rejected { engine: String, reason: String },

    #[error("motor '{engine}': {message}")]
    Other { engine: String, message: String },
}

// ── ENGINE REGISTRY (B1.T05) ───────────────────────────────

/// Registro central de motores. HashMap por nombre.
/// Permite agregar motores sin modificar el core (Open/Closed).
#[derive(Default)]
pub struct EngineRegistry {
    engines: HashMap<String, Arc<dyn AuthEngine>>,
}

impl EngineRegistry {
    pub fn new() -> Self {
        Self { engines: HashMap::new() }
    }

    /// Registrar un motor. Error si ya existe uno con el mismo nombre.
    pub fn register(&mut self, engine: Arc<dyn AuthEngine>) -> Result<(), EngineError> {
        let name = engine.name().to_string();
        if self.engines.contains_key(&name) {
            return Err(EngineError::Other { engine: name.clone(), message: "motor ya registrado".into() });
        }
        info!(engine = %name, domains = ?engine.covered_domains(), "motor registrado");
        self.engines.insert(name, engine);
        Ok(())
    }

    pub async fn sync_role_all(&self, role_id: &str, tenant_id: &str) -> Vec<Result<(), EngineError>> {
        let mut results = Vec::new();
        for engine in self.engines.values() {
            results.push(engine.sync_role(role_id, tenant_id).await);
        }
        results
    }

    pub fn get(&self, name: &str) -> Option<&Arc<dyn AuthEngine>> { self.engines.get(name) }
    pub fn len(&self) -> usize { self.engines.len() }
    pub fn is_empty(&self) -> bool { self.engines.is_empty() }
    pub fn names(&self) -> Vec<String> { self.engines.keys().cloned().collect() }
}

// ── TESTS ───────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    struct FakeEngine { name: String, domains: Vec<String>, calls: Mutex<Vec<String>> }

    #[async_trait::async_trait]
    impl AuthEngine for FakeEngine {
        fn name(&self) -> &str { &self.name }
        fn covered_domains(&self) -> Vec<String> { self.domains.clone() }
        async fn sync_role(&self, role_id: &str, _t: &str) -> Result<(), EngineError> {
            self.calls.lock().unwrap().push(role_id.into());
            Ok(())
        }
        async fn sync_user(&self, _u: &str, _t: &str) -> Result<(), EngineError> { Ok(()) }
        async fn reconcile(&self, _t: &str) -> Result<ReconcileReport, EngineError> {
            Ok(ReconcileReport { engine_name: self.name.clone(), ..Default::default() })
        }
        async fn health_check(&self) -> bool { true }
    }

    fn fake(name: &str) -> Arc<FakeEngine> {
        Arc::new(FakeEngine { name: name.into(), domains: vec![], calls: Mutex::new(vec![]) })
    }

    #[test]
    fn test_register_and_get() {
        let mut r = EngineRegistry::new();
        r.register(fake("kc")).unwrap();
        assert_eq!(r.len(), 1);
        assert!(r.get("kc").is_some());
    }

    #[test]
    fn test_duplicate_fails() {
        let mut r = EngineRegistry::new();
        r.register(fake("dup")).unwrap();
        assert!(r.register(fake("dup")).is_err());
    }

    #[test]
    fn test_names() {
        let mut r = EngineRegistry::new();
        r.register(fake("kc")).unwrap();
        r.register(fake("nexus")).unwrap();
        let mut names = r.names();
        names.sort(); // HashMap no garantiza orden
        assert_eq!(names, vec!["kc", "nexus"]);
    }
}
