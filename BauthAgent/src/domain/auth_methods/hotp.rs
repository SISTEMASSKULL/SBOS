// ============================================================
// bauth::domain::auth_methods::hotp — HOTP RFC 4226
//
// HMAC-based One-Time Password. Counter-based.
// RFC 4226: https://datatracker.ietf.org/doc/html/rfc4226
// Test vectors: Appendix D (counters 0-9)
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use ring::hmac;
use serde_json::Value;

pub struct HotpValidator { digits: u32 }

impl HotpValidator {
    pub fn new() -> Self { Self { digits: 6 } }
    pub fn with_digits(mut self, d: u32) -> Self { self.digits = d; self }

    pub fn compute(&self, secret: &[u8], counter: u64) -> Result<String, AuthMethodError> {
        if secret.is_empty() {
            return Err(AuthMethodError::MissingParam { method: "BAUTH_HOTP".into(), param: "secret".into() });
        }
        let key = hmac::Key::new(hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY, secret);
        let hmac_bytes = hmac::sign(&key, &counter.to_be_bytes());
        Ok(super::totp::dynamic_truncation(hmac_bytes.as_ref(), self.digits))
    }
}

#[async_trait]
impl AuthMethod for HotpValidator {
    fn method_id(&self) -> &str { "BAUTH_HOTP" }
    fn method_name(&self) -> &str { "HOTP — HMAC-based One-Time Password (RFC 4226)" }
    fn aal_level(&self) -> u8 { 2 }
    fn standard_ref(&self) -> &str { "RFC 4226 / NIST SP 800-63B Rev.4 §3.1.4" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let secret = input.get("secret").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_HOTP".into(), param: "secret".into() })?;
        let code = input.get("code").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_HOTP".into(), param: "code".into() })?;
        let counter = input.get("counter").and_then(|v| v.as_u64())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_HOTP".into(), param: "counter".into() })?;

        let computed = self.compute(secret.as_bytes(), counter)?;
        let valid = ring::constant_time::verify_slices_are_equal(computed.as_bytes(), code.as_bytes()).is_ok();
        Ok(ValidateResult { valid, method_id: "BAUTH_HOTP".into(),
            message: if valid { "HOTP válido".into() } else { "HOTP inválido".into() }, aal_satisfied: if valid { 2 } else { 0 } })
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult { enrolled: true, method_id: "BAUTH_HOTP".into(), instance_id: uuid::Uuid::new_v4().to_string(), secret_preview: None, message: "HOTP enrolado".into() })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rfc4226_appendix_d() {
        let v = HotpValidator::new();
        let secret = b"12345678901234567890";
        assert_eq!(v.compute(secret, 0).unwrap(), "755224");
        assert_eq!(v.compute(secret, 1).unwrap(), "287082");
        assert_eq!(v.compute(secret, 4).unwrap(), "338314");
        assert_eq!(v.compute(secret, 9).unwrap(), "520489");
    }

    #[test]
    fn test_empty_secret_error() {
        assert!(HotpValidator::new().compute(b"", 0).is_err());
    }
}
