// ============================================================
// bauth::domain::auth_methods::totp — TOTP RFC 6238
//
// Time-based One-Time Password. HMAC-SHA1/256/512 + dynamic truncation.
//
// RFC 6238: https://datatracker.ietf.org/doc/html/rfc6238
// Test vectors: Appendix B (SHA1, SHA256, SHA512)
// NIST SP 800-63B Rev.4 §3.1.4 — Single-Factor OTP Verifier
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use ring::hmac;
use serde_json::Value;

/// Validador TOTP nativo. Sin dependencia de Keycloak.
pub struct TotpValidator {
    /// Período en segundos (default: 30)
    period: u64,
    /// Número de dígitos (default: 6, RFC permite 6-8)
    digits: u32,
    /// Algoritmo de hash (default: SHA1)
    hash_algo: TotpHash,
    /// Ventana de tolerancia hacia atrás (pasos de período)
    window_back: u32,
    /// Ventana de tolerancia hacia adelante
    window_forward: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TotpHash {
    Sha1,
    Sha256,
    Sha512,
}

impl TotpValidator {
    pub fn new() -> Self {
        Self {
            period: 30,
            digits: 6,
            hash_algo: TotpHash::Sha1,
            window_back: 1,    // tolerar 1 paso hacia atrás (reloj desfasado)
            window_forward: 1, // tolerar 1 paso hacia adelante
        }
    }

    /// Configurar período personalizado
    pub fn with_period(mut self, period: u64) -> Self { self.period = period; self }

    /// Configurar cantidad de dígitos (6, 7, u 8)
    pub fn with_digits(mut self, digits: u32) -> Self { self.digits = digits; self }

    /// Configurar algoritmo de hash
    pub fn with_hash(mut self, algo: TotpHash) -> Self { self.hash_algo = algo; self }

    /// Calcular TOTP para un tiempo Unix dado.
    /// T = floor(time / period), HMAC(secret, T), truncate → OTP
    pub fn compute(&self, secret: &[u8], unix_time: u64) -> Result<String, AuthMethodError> {
        if secret.is_empty() {
            return Err(AuthMethodError::MissingParam {
                method: "BAUTH_TOTP".into(), param: "secret".into(),
            });
        }

        let t = unix_time / self.period;
        self.hotp_at(secret, t)
    }

    /// Verificar un código TOTP contra el secreto.
    /// Prueba el tiempo actual ± ventana.
    pub fn verify(
        &self, secret: &[u8], code: &str, unix_time: u64,
    ) -> Result<bool, AuthMethodError> {
        let t = unix_time / self.period;
        let start = t.saturating_sub(self.window_back as u64);
        let end = t.saturating_add(self.window_forward as u64);

        for step in start..=end {
            if let Ok(computed) = self.hotp_at(secret, step) {
                if constant_time_eq(computed.as_bytes(), code.as_bytes()) {
                    return Ok(true);
                }
            }
        }
        Ok(false)
    }

    /// HOTP interno: HMAC(secret, counter) → OTP para un contador específico
    fn hotp_at(&self, secret: &[u8], counter: u64) -> Result<String, AuthMethodError> {
        let counter_bytes = counter.to_be_bytes();

        let hmac_result = match self.hash_algo {
            TotpHash::Sha1 => {
                let key = hmac::Key::new(hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY, secret);
                hmac::sign(&key, &counter_bytes)
            }
            TotpHash::Sha256 => {
                let key = hmac::Key::new(hmac::HMAC_SHA256, secret);
                hmac::sign(&key, &counter_bytes)
            }
            TotpHash::Sha512 => {
                let key = hmac::Key::new(hmac::HMAC_SHA512, secret);
                hmac::sign(&key, &counter_bytes)
            }
        };

        let hmac_bytes = hmac_result.as_ref();
        let otp = dynamic_truncation(hmac_bytes, self.digits);
        Ok(otp)
    }
}

impl Default for TotpValidator {
    fn default() -> Self { Self::new() }
}

/// Dynamic Truncation — RFC 4226 §5.3
/// offset = last nibble of HMAC
/// p = hmac[offset..offset+4] & 0x7FFFFFFF
/// otp = p % 10^digits
pub(crate) fn dynamic_truncation(hmac: &[u8], digits: u32) -> String {
    let offset = (hmac.last().unwrap_or(&0) & 0x0F) as usize;
    let p = u32::from_be_bytes([
        hmac[offset] & 0x7F,
        hmac[offset + 1],
        hmac[offset + 2],
        hmac[offset + 3],
    ]);
    let otp = p % 10u32.pow(digits);
    format!("{:0width$}", otp, width = digits as usize)
}

/// Comparación en tiempo constante para prevenir timing attacks.
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() { return false; }
    let mut result: u8 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        result |= x ^ y;
    }
    result == 0
}

// ── Trait AuthMethod ────────────────────────────────────────

#[async_trait]
impl AuthMethod for TotpValidator {
    fn method_id(&self) -> &str { "BAUTH_TOTP" }
    fn method_name(&self) -> &str { "TOTP — Time-based One-Time Password (RFC 6238)" }
    fn aal_level(&self) -> u8 { 2 }
    fn standard_ref(&self) -> &str { "RFC 6238 / NIST SP 800-63B Rev.4 §3.1.4" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let secret_str = input.get("secret").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "BAUTH_TOTP".into(), param: "secret".into(),
            })?;
        let code = input.get("code").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "BAUTH_TOTP".into(), param: "code".into(),
            })?;
        let time = input.get("time").and_then(|v| v.as_u64())
            .unwrap_or_else(|| std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs());

        let secret = base32_secret(secret_str);

        if self.verify(&secret, code, time)? {
            Ok(ValidateResult { valid: true, method_id: "BAUTH_TOTP".into(),
                message: "TOTP válido".into(), aal_satisfied: 2 })
        } else {
            Ok(ValidateResult { valid: false, method_id: "BAUTH_TOTP".into(),
                message: "TOTP inválido".into(), aal_satisfied: 0 })
        }
    }

    async fn enroll(&self, _user_uuid: &str, params: &Value) -> Result<EnrollResult, AuthMethodError> {
        let label = params.get("label").and_then(|v| v.as_str()).unwrap_or("bauth-user");
        let issuer = params.get("issuer").and_then(|v| v.as_str()).unwrap_or("SBOS");
        let secret_bytes: Vec<u8> = (0..20).map(|_| rand::random::<u8>()).collect();
        let secret_b32 = data_encoding::BASE32_NOPAD.encode(&secret_bytes);
        let uri = format!("otpauth://totp/{}:{}?secret={}&issuer={}&algorithm=SHA1&digits=6&period=30",
            issuer, label, secret_b32, issuer);

        Ok(EnrollResult {
            enrolled: true, method_id: "BAUTH_TOTP".into(),
            instance_id: uuid::Uuid::new_v4().to_string(),
            secret_preview: Some(uri),
            message: "TOTP enrolado exitosamente. Escanea el QR o ingresa el secret en tu app authenticator.".into(),
        })
    }

    async fn revoke(&self, _user_uuid: &str, _instance_id: &str) -> Result<(), AuthMethodError> {
        Ok(()) // TOTP no tiene estado persistente en el validador. La BD maneja el ciclo de vida.
    }

    async fn health_check(&self) -> bool { true }
}

/// Decodifica un secret en base32. Fallback a bytes directos si no es base32 válido.
fn base32_secret(input: &str) -> Vec<u8> {
    let cleaned = input.to_uppercase().replace(' ', "");
    if let Ok(bytes) = data_encoding::BASE32_NOPAD.decode(cleaned.as_bytes()) {
        if !bytes.is_empty() { return bytes; }
    }
    // Si no es base32, asumir ASCII directo (ej: "12345678901234567890")
    input.as_bytes().to_vec()
}

// ── Tests con vectores oficiales RFC 6238 Appendix B ────────

#[cfg(test)]
mod tests {
    use super::*;

    const SECRET_SHA1: &str = "12345678901234567890";
    const SECRET_SHA256: &str = "12345678901234567890123456789012";
    const SECRET_SHA512: &str = "1234567890123456789012345678901234567890123456789012345678901234";

    #[test]
    fn test_rfc6238_appendix_b_sha1() {
        let v = TotpValidator::new().with_digits(8).with_hash(TotpHash::Sha1);
        let secret = SECRET_SHA1.as_bytes();

        assert_eq!(v.compute(secret, 59).unwrap(), "94287082");
        assert_eq!(v.compute(secret, 1111111109).unwrap(), "07081804");
        assert_eq!(v.compute(secret, 1111111111).unwrap(), "14050471");
        assert_eq!(v.compute(secret, 1234567890).unwrap(), "89005924");
        assert_eq!(v.compute(secret, 2000000000).unwrap(), "69279037");
        assert_eq!(v.compute(secret, 20000000000).unwrap(), "65353130");
    }

    #[test]
    fn test_rfc6238_appendix_b_sha256() {
        let v = TotpValidator::new().with_digits(8).with_hash(TotpHash::Sha256);
        let secret = SECRET_SHA256.as_bytes();

        assert_eq!(v.compute(secret, 59).unwrap(), "46119246");
        assert_eq!(v.compute(secret, 1111111109).unwrap(), "68084774");
        assert_eq!(v.compute(secret, 1111111111).unwrap(), "67062674");
        assert_eq!(v.compute(secret, 1234567890).unwrap(), "91819424");
        assert_eq!(v.compute(secret, 2000000000).unwrap(), "90698825");
        assert_eq!(v.compute(secret, 20000000000).unwrap(), "77737706");
    }

    #[test]
    fn test_rfc6238_appendix_b_sha512() {
        let v = TotpValidator::new().with_digits(8).with_hash(TotpHash::Sha512);
        let secret = SECRET_SHA512.as_bytes();

        assert_eq!(v.compute(secret, 59).unwrap(), "90693936");
        assert_eq!(v.compute(secret, 1111111109).unwrap(), "25091201");
        assert_eq!(v.compute(secret, 1111111111).unwrap(), "99943326");
        assert_eq!(v.compute(secret, 1234567890).unwrap(), "93441116");
        assert_eq!(v.compute(secret, 2000000000).unwrap(), "38618901");
        assert_eq!(v.compute(secret, 20000000000).unwrap(), "47863826");
    }

    #[test]
    fn test_totp_verify_success() {
        let v = TotpValidator::new().with_digits(8);
        let secret = SECRET_SHA1.as_bytes();
        assert!(v.verify(secret, "94287082", 59).unwrap());
    }

    #[test]
    fn test_totp_verify_wrong_code() {
        let v = TotpValidator::new().with_digits(8);
        let secret = SECRET_SHA1.as_bytes();
        assert!(!v.verify(secret, "00000000", 59).unwrap());
    }

    #[test]
    fn test_totp_digits_6() {
        let v = TotpValidator::new().with_digits(6);
        let secret = SECRET_SHA1.as_bytes();
        assert_eq!(v.compute(secret, 59).unwrap(), "287082");
    }

    #[test]
    fn test_totp_empty_secret_error() {
        let v = TotpValidator::new();
        assert!(v.compute(b"", 59).is_err());
    }

    #[test]
    fn test_constant_time_comparison() {
        assert!(constant_time_eq(b"123456", b"123456"));
        assert!(!constant_time_eq(b"123456", b"123457"));
        assert!(!constant_time_eq(b"1234", b"12345")); // different length
    }
}
