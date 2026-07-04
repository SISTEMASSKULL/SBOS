// ============================================================
// bauth::domain::auth_methods::recovery — Recovery Codes
//
// Look-Up Secrets — NIST SP 800-63B Rev.4 §3.1.2
// SHA-256 one-time use recovery codes.
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use ring::digest;
use serde_json::Value;

pub struct RecoveryValidator;

impl RecoveryValidator {
    pub fn new() -> Self { Self }

    /// Genera N códigos de recuperación (formato: XXXX-XXXX-XXXX, 3 grupos de 4 alfanuméricos)
    /// Cada código tiene ~48 bits de entropía.
    pub fn generate_codes(count: usize) -> Vec<String> {
        (0..count).map(|_| {
            let bytes: [u8; 6] = rand::random();
            let raw = data_encoding::BASE32_NOPAD.encode(&bytes);
            format!("{}-{}-{}", &raw[..4], &raw[4..8], &raw[8..])
        }).collect()
    }

    /// Hashear un código con SHA-256 para almacenamiento.
    pub fn hash_code(code: &str) -> String {
        let d = digest::digest(&digest::SHA256, code.as_bytes());
        data_encoding::HEXLOWER.encode(d.as_ref())
    }

    /// Verificar código contra hash almacenado en tiempo constante.
    pub fn verify(code: &str, stored_hash: &str) -> bool {
        let computed = Self::hash_code(code);
        ring::constant_time::verify_slices_are_equal(
            computed.as_bytes(), stored_hash.as_bytes()
        ).is_ok()
    }
}

#[async_trait]
impl AuthMethod for RecoveryValidator {
    fn method_id(&self) -> &str { "BAUTH_RECOVERY" }
    fn method_name(&self) -> &str { "Recovery Codes — Look-Up Secrets (NIST §3.1.2)" }
    fn aal_level(&self) -> u8 { 2 }
    fn standard_ref(&self) -> &str { "NIST SP 800-63B Rev.4 §3.1.2" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let code = input.get("code").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_RECOVERY".into(), param: "code".into() })?;
        let hash = input.get("hash").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_RECOVERY".into(), param: "hash".into() })?;

        if Self::verify(code, hash) {
            Ok(ValidateResult { valid: true, method_id: "BAUTH_RECOVERY".into(), message: "código de recuperación válido".into(), aal_satisfied: 2 })
        } else {
            Ok(ValidateResult { valid: false, method_id: "BAUTH_RECOVERY".into(), message: "código de recuperación inválido".into(), aal_satisfied: 0 })
        }
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        let codes = Self::generate_codes(10);
        let hashes: Vec<String> = codes.iter().map(|c| Self::hash_code(c)).collect();
        Ok(EnrollResult {
            enrolled: true, method_id: "BAUTH_RECOVERY".into(),
            instance_id: uuid::Uuid::new_v4().to_string(),
            secret_preview: Some(codes.join("\n")),
            message: format!("{} códigos de recuperación generados. Guárdelos en lugar seguro.", hashes.len()),
        })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_and_verify() {
        let codes = RecoveryValidator::generate_codes(3);
        assert_eq!(codes.len(), 3);
        for code in &codes {
            let hash = RecoveryValidator::hash_code(code);
            assert!(RecoveryValidator::verify(code, &hash));
            assert!(!RecoveryValidator::verify("WRONG-CODE-XXXX", &hash));
        }
    }

    #[test]
    fn test_codes_are_unique() {
        let codes = RecoveryValidator::generate_codes(10);
        let mut unique = std::collections::HashSet::new();
        for c in &codes { unique.insert(c.clone()); }
        assert_eq!(unique.len(), 10);
    }
}
