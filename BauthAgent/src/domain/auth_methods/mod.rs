// ============================================================
// bauth::domain::auth_methods — Validadores Nativos de Autenticación
// Fase 1 Roadmap · 2026-06-29
//
// bAuth valida directamente métodos criptográficos sin delegar
// a Keycloak ni a ningún motor externo. Keycloak queda SOLO para
// WebAuthn/FIDO2 y SAML 2.0 (protocolos que requieren navegador
// o federación externa).
//
// Submódulos:
//   totp.rs     — RFC 6238 (HMAC-SHA1/256/512, time-based)
//   hotp.rs     — RFC 4226 (HMAC-SHA1, counter-based)
//   recovery.rs — NIST 800-63B §3.1.2 (look-up secrets, SHA-256)
//   email_otp.rs— NIST 800-63B §3.1.4 (single-factor OTP, email)
//   push.rs     — Ed25519 challenge-response
//   mtls.rs     — X.509 certificate validation
//   password.rs — Argon2id verification (delega a domain/password_policy.rs)
//
// DOC-SBOS-001 N3 · ADR-010 · BAUTH-RECONCILIACION-METODOS-AUTENTICACION.md
// ============================================================
#![allow(dead_code)]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use thiserror::Error;
use tracing::info;

// ── Submódulos ─────────────────────────────────────────────

pub mod totp;
pub mod hotp;
pub mod recovery;
pub mod email_otp;
pub mod push;
pub mod mtls;
pub mod webauthn;  // WebAuthn/FIDO2 nativo — webauthn-rs — elimina dependencia Keycloak
pub mod saml;            // SAML 2.0 nativo — validación ligera — elimina dependencia Keycloak
pub mod saml_signature;  // G4: verificación de firma XML-DSig (xmldsig)

// ── Trait AuthMethod ────────────────────────────────────────

/// Todo método de autenticación implementa este trait.
/// Define el contrato mínimo que bAuth necesita para validar,
/// enrolar y revocar un método de autenticación.
#[async_trait::async_trait]
pub trait AuthMethod: Send + Sync {
    /// Identificador único del método (ej: "BAUTH_TOTP", "BAUTH_HOTP")
    fn method_id(&self) -> &str;

    /// Nombre descriptivo en español
    fn method_name(&self) -> &str;

    /// NIST Authenticator Assurance Level
    fn aal_level(&self) -> u8; // 1, 2, o 3

    /// RFC o estándar que implementa
    fn standard_ref(&self) -> &str;

    /// Validar una autenticación. Retorna true si las credenciales son válidas.
    /// `input`: parámetros específicos del método (JSON)
    async fn validate(&self, input: &serde_json::Value) -> Result<ValidateResult, AuthMethodError>;

    /// Enrolar un nuevo método para un usuario.
    async fn enroll(&self, user_uuid: &str, params: &serde_json::Value) -> Result<EnrollResult, AuthMethodError>;

    /// Revocar/desactivar un método para un usuario.
    async fn revoke(&self, user_uuid: &str, method_instance_id: &str) -> Result<(), AuthMethodError>;

    /// Health check del método
    async fn health_check(&self) -> bool;
}

/// Resultado de validación de un método.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidateResult {
    pub valid: bool,
    pub method_id: String,
    pub message: String,
    pub aal_satisfied: u8,
}

/// Resultado de enrolamiento de un método.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrollResult {
    pub enrolled: bool,
    pub method_id: String,
    pub instance_id: String, // UUID único de esta instancia de método
    pub secret_preview: Option<String>, // TOTP secret URI, recovery codes preview, etc.
    pub message: String,
}

/// Errores de métodos de autenticación en español.
#[derive(Debug, Error)]
pub enum AuthMethodError {
    #[error("método '{method}': credenciales inválidas")]
    InvalidCredentials { method: String },

    #[error("método '{method}': credencial expirada (TTL: {ttl_secs}s)")]
    Expired { method: String, ttl_secs: u64 },

    #[error("método '{method}': credencial ya utilizada (replay detectado)")]
    ReplayDetected { method: String },

    #[error("método '{method}': rate limit excedido ({attempts} intentos en {window_secs}s)")]
    RateLimited { method: String, attempts: u32, window_secs: u64 },

    #[error("método '{method}': parámetro requerido ausente: {param}")]
    MissingParam { method: String, param: String },

    #[error("método '{method}': error interno: {message}")]
    Internal { method: String, message: String },

    #[error("método '{method}': no enrolado para este usuario")]
    NotEnrolled { method: String },
}

// ── MethodRegistry ──────────────────────────────────────────

/// Registro central de métodos de autenticación nativos.
pub struct MethodRegistry {
    methods: HashMap<String, Arc<dyn AuthMethod>>,
}

impl MethodRegistry {
    pub fn new() -> Self {
        Self { methods: HashMap::new() }
    }

    pub fn register(&mut self, method: Arc<dyn AuthMethod>) -> Result<(), AuthMethodError> {
        let id = method.method_id().to_string();
        if self.methods.contains_key(&id) {
            return Err(AuthMethodError::Internal {
                method: id,
                message: "método ya registrado".into(),
            });
        }
        info!(method_id = %id, name = method.method_name(), "método de autenticación nativo registrado");
        self.methods.insert(id, method);
        Ok(())
    }

    pub fn get(&self, method_id: &str) -> Option<&Arc<dyn AuthMethod>> {
        self.methods.get(method_id)
    }

    pub fn list(&self) -> Vec<serde_json::Value> {
        self.methods.values().map(|m| serde_json::json!({
            "method_id": m.method_id(),
            "method_name": m.method_name(),
            "aal_level": m.aal_level(),
            "standard_ref": m.standard_ref(),
        })).collect()
    }

    pub fn len(&self) -> usize { self.methods.len() }
    pub fn is_empty(&self) -> bool { self.methods.is_empty() }
}

impl Default for MethodRegistry {
    fn default() -> Self { Self::new() }
}

// ── Tests ──────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    struct FakeMethod { id: String, healthy: AtomicBool }

    #[async_trait::async_trait]
    impl AuthMethod for FakeMethod {
        fn method_id(&self) -> &str { &self.id }
        fn method_name(&self) -> &str { "Fake para tests" }
        fn aal_level(&self) -> u8 { 1 }
        fn standard_ref(&self) -> &str { "TEST" }
        async fn validate(&self, _: &serde_json::Value) -> Result<ValidateResult, AuthMethodError> {
            Ok(ValidateResult { valid: true, method_id: self.id.clone(), message: "ok".into(), aal_satisfied: 1 })
        }
        async fn enroll(&self, _: &str, _: &serde_json::Value) -> Result<EnrollResult, AuthMethodError> {
            Ok(EnrollResult { enrolled: true, method_id: self.id.clone(), instance_id: "inst-1".into(), secret_preview: None, message: "ok".into() })
        }
        async fn revoke(&self, _: &str, _: &str) -> Result<(), AuthMethodError> { Ok(()) }
        async fn health_check(&self) -> bool { self.healthy.load(Ordering::Relaxed) }
    }

    #[test]
    fn test_registry_register_and_get() {
        let mut r = MethodRegistry::new();
        let m = Arc::new(FakeMethod { id: "FAKE".into(), healthy: AtomicBool::new(true) });
        r.register(m).unwrap();
        assert_eq!(r.len(), 1);
        assert!(r.get("FAKE").is_some());
    }

    #[test]
    fn test_registry_duplicate_fails() {
        let mut r = MethodRegistry::new();
        let m1 = Arc::new(FakeMethod { id: "DUP".into(), healthy: AtomicBool::new(true) });
        let m2 = Arc::new(FakeMethod { id: "DUP".into(), healthy: AtomicBool::new(true) });
        r.register(m1).unwrap();
        assert!(r.register(m2).is_err());
    }

    #[test]
    fn test_registry_list() {
        let mut r = MethodRegistry::new();
        r.register(Arc::new(FakeMethod { id: "A".into(), healthy: AtomicBool::new(true) })).unwrap();
        r.register(Arc::new(FakeMethod { id: "B".into(), healthy: AtomicBool::new(true) })).unwrap();
        let list = r.list();
        assert_eq!(list.len(), 2);
    }
}
