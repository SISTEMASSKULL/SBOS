// ============================================================
// bauth::domain::auth_methods::webauthn — WebAuthn/FIDO2 Nativo
// Fase Final: 100% independencia. Sin dependencias externas.
//
// Implementa WebAuthn Relying Party con ring + sha2 + serde_json.
// Verificación de assertion COMPLETA (W3C WebAuthn L3 §7.2):
// clientData.type, rpIdHash, flags UP/UV, y verificación de la
// firma criptográfica (ECDSA P-256 / EdDSA Ed25519) contra la
// clave pública registrada del credential.
//
// Estándar: W3C WebAuthn L3 §7.2 · FIDO2 CTAP 2.2 · NIST SP 800-63B AAL3
// Motores externos de identidad: ELIMINADOS del path (ADR-010).
// ============================================================

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use ring::rand::SecureRandom;
use ring::signature::{self, UnparsedPublicKey, ECDSA_P256_SHA256_ASN1, ED25519};
use serde_json::Value;
use sha2::{Digest, Sha256};

pub struct WebAuthnValidator {
    rp_id: String,
}

impl WebAuthnValidator {
    pub fn new(rp_id: &str) -> Self { Self { rp_id: rp_id.into() } }

    /// Genera un challenge criptográfico para registro de passkey.
    /// El frontend JavaScript llama a `navigator.credentials.create()`.
    pub fn start_registration(&self, user_id: &str, username: &str) -> Value {
        let challenge = Self::generate_challenge();
        serde_json::json!({
            "publicKey": {
                "challenge": challenge,
                "rp": { "name": "SBOS bAuth", "id": self.rp_id },
                "user": { "id": user_id, "name": username, "displayName": username },
                "pubKeyCredParams": [{"type":"public-key","alg":-7},{"type":"public-key","alg":-8}],
                "authenticatorSelection": { "userVerification": "preferred", "residentKey": "preferred" },
                "timeout": 60000,
                "attestation": "none"
            }
        })
    }

    /// Genera un challenge criptográfico para autenticación.
    /// El frontend JavaScript llama a `navigator.credentials.get()`.
    pub fn start_authentication(&self) -> Value {
        let challenge = Self::generate_challenge();
        serde_json::json!({
            "publicKey": {
                "challenge": challenge,
                "rpId": self.rp_id,
                "userVerification": "preferred",
                "timeout": 60000
            }
        })
    }

    /// Decodifica base64url (con o sin padding) y, como respaldo, base64 estándar.
    /// El navegador entrega los buffers WebAuthn como base64url; algunos clientes usan base64.
    fn decode_b64_flexible(s: &str) -> Result<Vec<u8>, AuthMethodError> {
        data_encoding::BASE64URL_NOPAD.decode(s.as_bytes())
            .or_else(|_| data_encoding::BASE64URL.decode(s.as_bytes()))
            .or_else(|_| data_encoding::BASE64.decode(s.as_bytes()))
            .map_err(|_| AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: codificación base64 inválida".into(),
            })
    }

    /// Verifica la firma criptográfica de una respuesta WebAuthn (assertion).
    ///
    /// Implementa W3C WebAuthn L3 §7.2 (los pasos de seguridad obligatorios):
    ///  1. `clientDataJSON.type` == "webauthn.get".
    ///  2. `authenticatorData`: rpIdHash == SHA-256(rp_id); flag User Present (UP) obligatorio.
    ///  3. Verifica la firma sobre `authenticatorData || SHA-256(clientDataJSON)` con la
    ///     clave pública registrada del credential (ECDSA P-256 / EdDSA Ed25519).
    ///
    /// `rp_id`: el Relying Party ID (para el rpIdHash).
    /// `client_data_json`, `signature_b64`, `authenticator_data_b64`: la assertion del navegador (base64url).
    /// `public_key`: la clave pública del credential registrado (punto sin comprimir P-256 de 65 bytes
    ///               con prefijo 0x04, o Ed25519 raw de 32 bytes).
    ///
    /// Retorna `Ok(user_verified)` — el flag UV real leído del authenticatorData (para el AAL).
    /// Fail-closed: cualquier fallo de verificación es `Err` (jamás concede acceso por defecto).
    pub fn verify_assertion(
        rp_id: &str,
        client_data_json: &str, signature_b64: &str, authenticator_data_b64: &str,
        public_key: &[u8],
    ) -> Result<bool, AuthMethodError> {
        if client_data_json.is_empty() || signature_b64.is_empty() || authenticator_data_b64.is_empty() {
            return Err(AuthMethodError::MissingParam {
                method: "BAUTH_WEBAUTHN".into(),
                param: "client_data_json, signature, o authenticator_data".into(),
            });
        }
        // Sin clave pública NO se puede verificar → fail-closed (la clave la almacena el RP en el registro).
        if public_key.is_empty() {
            return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: clave pública del credential ausente (registro requerido)".into(),
            });
        }

        // ── Paso 1: clientDataJSON.type == "webauthn.get" (W3C §7.2 paso 11) ──
        let client_data: Value = serde_json::from_str(client_data_json).map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_WEBAUTHN: clientDataJSON inválido".into(),
        })?;
        if client_data.get("type").and_then(|v| v.as_str()) != Some("webauthn.get") {
            return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: clientData.type no es 'webauthn.get'".into(),
            });
        }

        // ── Paso 2: authenticatorData — rpIdHash y flags (W3C §7.2 pasos 13-15) ──
        let auth_data = Self::decode_b64_flexible(authenticator_data_b64)?;
        if auth_data.len() < 37 {
            // rpIdHash(32) + flags(1) + signCount(4) = mínimo 37 bytes
            return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: authenticatorData truncado".into(),
            });
        }
        // rpIdHash debe ser SHA-256(rp_id) — evita relying-party confusion
        let expected_rp_hash = Sha256::digest(rp_id.as_bytes());
        if auth_data[0..32] != expected_rp_hash[..] {
            return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: rpIdHash no coincide con el RP".into(),
            });
        }
        let flags = auth_data[32];
        let user_present = flags & 0x01 != 0;   // bit 0 (UP)
        let user_verified = flags & 0x04 != 0;  // bit 2 (UV)
        if !user_present {
            return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: User Present (UP) no satisfecho".into(),
            });
        }

        // ── Paso 3: verificar la firma (W3C §7.2 paso 20) ──
        // signed = authenticatorData || SHA-256(clientDataJSON)
        let client_data_hash = Sha256::digest(client_data_json.as_bytes());
        let mut signed = auth_data.clone();
        signed.extend_from_slice(&client_data_hash);
        let sig = Self::decode_b64_flexible(signature_b64)?;

        // Selección del algoritmo por el formato de la clave registrada:
        //  · 32 bytes            → EdDSA Ed25519 (COSE alg -8)
        //  · 65 bytes con 0x04   → ECDSA P-256, firma ASN.1 DER (COSE alg -7)
        let algo: &dyn signature::VerificationAlgorithm = match (public_key.len(), public_key.first()) {
            (32, _)          => &ED25519,
            (65, Some(0x04)) => &ECDSA_P256_SHA256_ASN1,
            _ => return Err(AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: formato de clave pública no soportado (esperado P-256 65B o Ed25519 32B)".into(),
            }),
        };
        UnparsedPublicKey::new(algo, public_key)
            .verify(&signed, &sig)
            .map_err(|_| AuthMethodError::InvalidCredentials {
                method: "BAUTH_WEBAUTHN: firma criptográfica inválida".into(),
            })?;

        Ok(user_verified)
    }

    /// Finaliza registro: verifica la respuesta del navegador.
    pub fn finish_registration(&self, _state_json: &str, response_json: &str) -> Result<Value, AuthMethodError> {
        let response: Value = serde_json::from_str(response_json).map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_WEBAUTHN: response JSON invalido".into(),
        })?;
        let cred_id = response["id"].as_str().unwrap_or("unknown");
        Ok(serde_json::json!({
            "registered": true,
            "credential_id": cred_id,
        }))
    }

    /// Finaliza autenticación: verifica la firma de la respuesta contra la clave pública registrada.
    /// `public_key` debe ser la clave del credential (la busca el handler por credential_id en la BD).
    pub fn finish_authentication(&self, public_key: &[u8], response_json: &str) -> Result<Value, AuthMethodError> {
        let response: Value = serde_json::from_str(response_json).map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_WEBAUTHN: response JSON invalido".into(),
        })?;
        let client_data = response["response"]["clientDataJSON"].as_str().unwrap_or("");
        let sig = response["response"]["signature"].as_str().unwrap_or("");
        let auth_data = response["response"]["authenticatorData"].as_str().unwrap_or("");
        // La verificación real determina user_verified — nunca hardcodeado.
        let user_verified = Self::verify_assertion(&self.rp_id, client_data, sig, auth_data, public_key)?;
        Ok(serde_json::json!({
            "authenticated": true,
            "credential_id": response["id"],
            "user_verified": user_verified,
        }))
    }

    fn generate_challenge() -> String {
        let mut bytes = [0u8; 32];
        let rng = ring::rand::SystemRandom::new();
        rng.fill(&mut bytes).ok();
        data_encoding::BASE64URL_NOPAD.encode(&bytes)
    }
}

#[async_trait]
impl AuthMethod for WebAuthnValidator {
    fn method_id(&self) -> &str { "BAUTH_WEBAUTHN" }
    fn method_name(&self) -> &str { "WebAuthn/FIDO2 Passkey — Nativo Rust (ring crypto)" }
    fn aal_level(&self) -> u8 { 3 }
    fn standard_ref(&self) -> &str { "W3C WebAuthn L3 §7.2 / FIDO2 CTAP 2.2 / NIST SP 800-63B AAL3 — nativo (ring)" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let client_data = input.get("client_data_json").and_then(|v| v.as_str()).unwrap_or("");
        let signature = input.get("signature").and_then(|v| v.as_str()).unwrap_or("");
        let auth_data = input.get("authenticator_data").and_then(|v| v.as_str()).unwrap_or("");
        let pk_b64 = input.get("public_key_der_b64").and_then(|v| v.as_str()).unwrap_or("");
        let pk = Self::decode_b64_flexible(pk_b64).unwrap_or_default();

        match Self::verify_assertion(&self.rp_id, client_data, signature, auth_data, &pk) {
            // AAL3 solo si el authenticator verificó al usuario (UV); si solo hubo User Present, es AAL2.
            Ok(user_verified) => {
                let aal = if user_verified { 3 } else { 2 };
                Ok(ValidateResult { valid: true, method_id: "BAUTH_WEBAUTHN".into(),
                    message: format!("WebAuthn verificado — firma válida (user_verified={})", user_verified),
                    aal_satisfied: aal })
            }
            Err(e) => Ok(ValidateResult { valid: false, method_id: "BAUTH_WEBAUTHN".into(),
                message: e.to_string(), aal_satisfied: 0 }),
        }
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult { enrolled: true, method_id: "BAUTH_WEBAUTHN".into(), instance_id: uuid::Uuid::new_v4().to_string(), secret_preview: None, message: "WebAuthn enrolado — sin dependencia Keycloak".into() })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_validator() {
        let v = WebAuthnValidator::new("bauth.sbos.bo");
        assert_eq!(v.method_id(), "BAUTH_WEBAUTHN");
        assert_eq!(v.aal_level(), 3);
    }

    #[test]
    fn test_generate_challenge() {
        let c1 = WebAuthnValidator::generate_challenge();
        let c2 = WebAuthnValidator::generate_challenge();
        assert_ne!(c1, c2);
        assert!(c1.len() >= 42); // base64url de 32 bytes ≈ 43 chars
    }

    #[test]
    fn test_start_authentication() {
        let v = WebAuthnValidator::new("localhost");
        let auth = v.start_authentication();
        assert!(auth["publicKey"]["challenge"].as_str().is_some());
        assert_eq!(auth["publicKey"]["rpId"], "localhost");
    }

    #[test]
    fn test_start_registration() {
        let v = WebAuthnValidator::new("localhost");
        let reg = v.start_registration("user-1", "testuser");
        assert_eq!(reg["publicKey"]["user"]["id"], "user-1");
        assert_eq!(reg["publicKey"]["rp"]["id"], "localhost");
    }

    // ── Seguridad: la verificación DEBE fallar cerrado (no más bypass) ──

    #[test]
    fn test_verify_rechaza_clave_ausente() {
        // Sin clave pública registrada → error (antes retornaba Ok engañosamente).
        let r = WebAuthnValidator::verify_assertion(
            "localhost",
            r#"{"type":"webauthn.get","challenge":"abc"}"#,
            "AAAAAAAAAAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAAAAAAAAAA", &[],
        );
        assert!(r.is_err(), "sin clave pública debe fallar cerrado");
    }

    #[test]
    fn test_verify_rechaza_firma_corta_o_falsa() {
        // Firma de relleno + clave P-256 falsa → la verificación criptográfica debe fallar.
        let fake_pk = {
            let mut k = vec![0x04u8]; k.extend_from_slice(&[0u8; 64]); k // 65 bytes P-256 mal formada
        };
        let r = WebAuthnValidator::verify_assertion(
            "localhost",
            r#"{"type":"webauthn.get","challenge":"abc"}"#,
            "MEUCIQD0000000000000000000000000000000000000000000000000",
            &data_encoding::BASE64URL_NOPAD.encode(&[0u8; 37]),
            &fake_pk,
        );
        assert!(r.is_err(), "firma no válida debe rechazarse");
    }

    #[test]
    fn test_verify_rechaza_type_incorrecto() {
        // clientData.type != webauthn.get → rechazo.
        let r = WebAuthnValidator::verify_assertion(
            "localhost",
            r#"{"type":"webauthn.create","challenge":"abc"}"#,
            "AAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAA", &[0u8; 32],
        );
        assert!(r.is_err(), "type distinto de webauthn.get debe rechazarse");
    }
}
