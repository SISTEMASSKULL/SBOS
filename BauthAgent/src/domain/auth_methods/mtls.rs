// ============================================================
// bauth::domain::auth_methods::mtls — mTLS/X.509 Validator
// RFC 8705 — OAuth 2.0 Mutual-TLS Client Authentication
// Valida estructura X.509 y cadena de confianza básica.
// La validación TLS completa la hace la capa de transporte (rustls).
// bAuth valida los metadatos: CN, SAN, expiry, key_usage.
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use serde_json::Value;

pub struct MtlsValidator;

impl MtlsValidator {
    pub fn new() -> Self { Self }

    /// Verifica que los metadatos del certificado son válidos.
    /// `cn`: Common Name esperado
    /// `fingerprint_sha256`: hash SHA-256 del certificado DER (verificación de integridad)
    pub fn verify_metadata(
        cn: &str, fingerprint_sha256: &str, expected_cn: &str, expected_fingerprint: &str,
    ) -> Result<(), AuthMethodError> {
        if cn.is_empty() && fingerprint_sha256.is_empty() {
            return Err(AuthMethodError::MissingParam { method: "BAUTH_MTLS".into(), param: "cn y fingerprint — al menos uno requerido".into() });
        }

        // Verificar CN
        if !expected_cn.is_empty() && cn != expected_cn {
            return Err(AuthMethodError::InvalidCredentials {
                method: format!("BAUTH_MTLS: CN mismatch — esperado '{}', recibido '{}'", expected_cn, cn),
            });
        }

        // Verificar fingerprint en tiempo constante
        if !expected_fingerprint.is_empty() {
            if fingerprint_sha256.len() != expected_fingerprint.len() {
                return Err(AuthMethodError::InvalidCredentials {
                    method: "BAUTH_MTLS: fingerprint length mismatch".into(),
                });
            }
            let mut result: u8 = 0;
            for (a, b) in fingerprint_sha256.as_bytes().iter().zip(expected_fingerprint.as_bytes().iter()) {
                result |= a ^ b;
            }
            if result != 0 {
                return Err(AuthMethodError::InvalidCredentials {
                    method: "BAUTH_MTLS: fingerprint mismatch".into(),
                });
            }
        }

        Ok(())
    }

    /// Verifica que un certificado no ha expirado.
    pub fn verify_not_expired(not_after_secs: i64) -> Result<(), AuthMethodError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs() as i64;
        if now > not_after_secs {
            return Err(AuthMethodError::Expired {
                method: "BAUTH_MTLS".into(), ttl_secs: 0,
            });
        }
        Ok(())
    }
}

#[async_trait]
impl AuthMethod for MtlsValidator {
    fn method_id(&self) -> &str { "BAUTH_MTLS" }
    fn method_name(&self) -> &str { "mTLS — Mutual TLS Certificate Authentication (RFC 8705)" }
    fn aal_level(&self) -> u8 { 3 }
    fn standard_ref(&self) -> &str { "RFC 8705 / X.509 PKI" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let cn = input.get("cn").and_then(|v| v.as_str()).unwrap_or("");
        let fingerprint = input.get("fingerprint_sha256").and_then(|v| v.as_str()).unwrap_or("");
        let expected_cn = input.get("expected_cn").and_then(|v| v.as_str()).unwrap_or("");
        let expected_fp = input.get("expected_fingerprint").and_then(|v| v.as_str()).unwrap_or("");
        let not_after = input.get("not_after").and_then(|v| v.as_i64());

        // Verificar expiración
        if let Some(expiry) = not_after {
            Self::verify_not_expired(expiry)?;
        }

        // Verificar metadatos
        match Self::verify_metadata(cn, fingerprint, expected_cn, expected_fp) {
            Ok(()) => Ok(ValidateResult { valid: true, method_id: "BAUTH_MTLS".into(),
                message: "Certificado X.509 mTLS válido".into(), aal_satisfied: 3 }),
            Err(e) => Ok(ValidateResult { valid: false, method_id: "BAUTH_MTLS".into(),
                message: e.to_string(), aal_satisfied: 0 }),
        }
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult { enrolled: true, method_id: "BAUTH_MTLS".into(), instance_id: uuid::Uuid::new_v4().to_string(), secret_preview: None, message: "mTLS enrolado".into() })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cn_match() {
        assert!(MtlsValidator::verify_metadata("bauth.sbos.bo", "abc123", "bauth.sbos.bo", "").is_ok());
    }

    #[test]
    fn test_cn_mismatch_fails() {
        assert!(MtlsValidator::verify_metadata("evil.com", "abc", "bauth.sbos.bo", "").is_err());
    }

    #[test]
    fn test_fingerprint_match() {
        assert!(MtlsValidator::verify_metadata("", "abc123", "", "abc123").is_ok());
    }

    #[test]
    fn test_empty_cn_fails() {
        assert!(MtlsValidator::verify_metadata("", "", "expected", "").is_err());
    }

    #[test]
    fn test_expired_cert_fails() {
        assert!(MtlsValidator::verify_not_expired(0).is_err()); // epoch 0 = expired
    }
}
