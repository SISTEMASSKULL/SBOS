// ============================================================
// bauth::domain::auth_methods::email_otp — Email OTP
// NIST SP 800-63B Rev.4 §3.1.4 — Single-Factor OTP Verifier
// Genera código 6 dígitos, TTL 10 min, one-time use.
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use ring::digest;
use serde_json::Value;

pub struct EmailOtpValidator { ttl_seconds: u64, digits: u32 }

impl EmailOtpValidator {
    pub fn new() -> Self { Self { ttl_seconds: 600, digits: 6 } }

    /// Genera un código OTP de 6 dígitos y su hash SHA-256 con timestamp.
    pub fn generate(&self) -> (String, String, i64) {
        let code = format!("{:0width$}", rand::random::<u32>() % 10u32.pow(self.digits), width = self.digits as usize);
        let now = chrono::Utc::now().timestamp();
        let hash = Self::hash_with_time(&code, now);
        (code, hash, now)
    }

    /// Verifica un código OTP contra hash + timestamp.
    /// Rechaza si expiró (TTL excedido).
    pub fn verify(&self, code: &str, stored_hash: &str, created_at: i64) -> Result<bool, AuthMethodError> {
        let now = chrono::Utc::now().timestamp();
        if now - created_at > self.ttl_seconds as i64 {
            return Err(AuthMethodError::Expired { method: "BAUTH_EMAIL_OTP".into(), ttl_secs: self.ttl_seconds });
        }
        let computed = Self::hash_with_time(code, created_at);
        Ok(ring::constant_time::verify_slices_are_equal(
            computed.as_bytes(), stored_hash.as_bytes()).is_ok())
    }

    fn hash_with_time(code: &str, timestamp: i64) -> String {
        let input = format!("{}:{}", code, timestamp);
        let d = digest::digest(&digest::SHA256, input.as_bytes());
        data_encoding::HEXLOWER.encode(d.as_ref())
    }
}

#[async_trait]
impl AuthMethod for EmailOtpValidator {
    fn method_id(&self) -> &str { "BAUTH_EMAIL_OTP" }
    fn method_name(&self) -> &str { "Email OTP — Single-Factor One-Time Password (NIST §3.1.4)" }
    fn aal_level(&self) -> u8 { 1 }
    fn standard_ref(&self) -> &str { "NIST SP 800-63B Rev.4 §3.1.4" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let code = input.get("code").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_EMAIL_OTP".into(), param: "code".into() })?;
        let hash = input.get("hash").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_EMAIL_OTP".into(), param: "hash".into() })?;
        let created_at = input.get("created_at").and_then(|v| v.as_i64()).unwrap_or(0);

        match self.verify(code, hash, created_at) {
            Ok(true) => Ok(ValidateResult { valid: true, method_id: "BAUTH_EMAIL_OTP".into(), message: "Email OTP válido".into(), aal_satisfied: 1 }),
            Ok(false) => Ok(ValidateResult { valid: false, method_id: "BAUTH_EMAIL_OTP".into(), message: "Email OTP inválido".into(), aal_satisfied: 0 }),
            Err(e) => Ok(ValidateResult { valid: false, method_id: "BAUTH_EMAIL_OTP".into(), message: e.to_string(), aal_satisfied: 0 }),
        }
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult { enrolled: true, method_id: "BAUTH_EMAIL_OTP".into(), instance_id: uuid::Uuid::new_v4().to_string(), secret_preview: None, message: "Email OTP enrolado".into() })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_and_verify() {
        let v = EmailOtpValidator::new();
        let (code, hash, ts) = v.generate();
        assert_eq!(code.len(), 6);
        assert!(v.verify(&code, &hash, ts).unwrap());
    }

    #[test]
    fn test_wrong_code_fails() {
        let v = EmailOtpValidator::new();
        let (_, hash, ts) = v.generate();
        assert!(!v.verify("000000", &hash, ts).unwrap());
    }

    #[test]
    fn test_expired_code_fails() {
        let v = EmailOtpValidator::new();
        let (code, hash, _) = v.generate();
        let past = chrono::Utc::now().timestamp() - 601; // 10min+1s ago
        assert!(v.verify(&code, &hash, past).is_err());
    }
}
