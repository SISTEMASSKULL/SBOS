// ============================================================
// bauth::domain::jwt_signer — Firmador de Tokens JWT (B48.T02)
//
// Firma tokens JWT con EdDSA Ed25519 usando ring (FIPS 186-5, RFC 8032).
// Modo development: clave generada en memoria. Producción: Vault PKI.
//
// DOC-SBOS-001 N3 · BAUTH-VISION.md §3 · NIST SP 800-186
// ============================================================

use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use ring::rand::SystemRandom;
use ring::signature::{Ed25519KeyPair, KeyPair, UnparsedPublicKey, ED25519};
use serde::Serialize;

/// Resultado de la firma de un JWT.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SignedToken {
    pub jwt: String,
    pub header_b64: String,
    pub payload_b64: String,
    pub signature_b64: String,
    pub algorithm: String,
    pub kid: String,
}

/// Firmador de JWT con Ed25519 via ring.
pub struct JwtSigner {
    key_pair: Ed25519KeyPair,
    kid: String,
    public_key_hex: String,
}

impl JwtSigner {
    /// Crea un firmador con clave Ed25519 efimera (development).
    /// ⚠️ La clave NO persiste entre reinicios. Tokens emitidos antes del reinicio
    /// seran invalidos. Para produccion usar `new_from_vault()`.
    /// H-031: modo development con advertencia explicita.
    pub fn new_development() -> Result<Self, String> {
        let rng = SystemRandom::new();
        let pkcs8_bytes = Ed25519KeyPair::generate_pkcs8(&rng)
            .map_err(|_| "generación de clave Ed25519 falló — entropía insuficiente".to_string())?;
        let key_pair = Ed25519KeyPair::from_pkcs8(pkcs8_bytes.as_ref())
            .map_err(|_| "clave Ed25519 inválida tras generación".to_string())?;

        let public_key_bytes = key_pair.public_key().as_ref();
        let kid = hex::encode(&public_key_bytes[..8]);
        let public_key_hex = hex::encode(public_key_bytes);

        Ok(Self { key_pair, kid, public_key_hex })
    }

    /// Retorna la clave pública en hex (64 chars).
    pub fn public_key_hex(&self) -> &str {
        &self.public_key_hex
    }

    /// Retorna el Key ID para el header JWT.
    pub fn kid(&self) -> &str {
        &self.kid
    }

    /// Firma un payload JWT y retorna el token completo.
    pub fn sign(&self, claims: &impl Serialize) -> Result<SignedToken, String> {
        let header = serde_json::json!({
            "alg": "EdDSA",
            "typ": "JWT",
            "kid": self.kid,
        });

        let header_json = serde_json::to_string(&header)
            .map_err(|e| format!("header: {}", e))?;
        let header_b64 = URL_SAFE_NO_PAD.encode(header_json.as_bytes());

        let payload_json = serde_json::to_string(claims)
            .map_err(|e| format!("claims: {}", e))?;
        let payload_b64 = URL_SAFE_NO_PAD.encode(payload_json.as_bytes());

        let signing_input = format!("{}.{}", header_b64, payload_b64);
        let signature = self.key_pair.sign(signing_input.as_bytes());
        let signature_b64 = URL_SAFE_NO_PAD.encode(signature.as_ref());

        Ok(SignedToken {
            jwt: format!("{}.{}.{}", header_b64, payload_b64, signature_b64),
            header_b64,
            payload_b64,
            signature_b64,
            algorithm: "EdDSA".into(),
            kid: self.kid.clone(),
        })
    }

    /// Verifica un JWT firmado con esta clave.
    pub fn verify(&self, jwt: &str) -> Result<serde_json::Value, String> {
        let parts: Vec<&str> = jwt.split('.').collect();
        if parts.len() != 3 {
            return Err("formato JWT inválido".into());
        }

        let signing_input = format!("{}.{}", parts[0], parts[1]);
        let signature_bytes = URL_SAFE_NO_PAD
            .decode(parts[2].as_bytes())
            .map_err(|e| format!("firma base64: {}", e))?;

        let public_key = UnparsedPublicKey::new(
            &ED25519,
            self.key_pair.public_key().as_ref(),
        );

        public_key
            .verify(signing_input.as_bytes(), &signature_bytes)
            .map_err(|_| "firma inválida".to_string())?;

        let payload_bytes = URL_SAFE_NO_PAD
            .decode(parts[1].as_bytes())
            .map_err(|e| format!("payload base64: {}", e))?;

        serde_json::from_slice(&payload_bytes)
            .map_err(|e| format!("payload JSON: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sign_and_verify() {
        let signer = JwtSigner::new_development().unwrap();
        let claims = serde_json::json!({
            "sub": "user-123",
            "iss": "bauth.sbos.bo",
            "ctx_id": "ctx-456",
            "loa": 2,
        });

        let token = signer.sign(&claims).unwrap();
        assert!(!token.jwt.is_empty());
        assert!(token.jwt.contains('.'));
        assert_eq!(token.algorithm, "EdDSA");

        let verified = signer.verify(&token.jwt).unwrap();
        assert_eq!(verified["sub"], "user-123");
        assert_eq!(verified["iss"], "bauth.sbos.bo");
        assert_eq!(verified["loa"], 2);
    }

    #[test]
    fn test_verify_tampered_fails() {
        let signer = JwtSigner::new_development().unwrap();
        let claims = serde_json::json!({"test": true});
        let token = signer.sign(&claims).unwrap();

        // Modificar signature → verificación falla
        let mut parts: Vec<&str> = token.jwt.split('.').collect();
        parts[2] = "INVALID_SIGNATURE_XXXX";
        let tampered = parts.join(".");
        assert!(signer.verify(&tampered).is_err());
    }

    #[test]
    fn test_public_key_export() {
        let signer = JwtSigner::new_development().unwrap();
        assert_eq!(signer.public_key_hex().len(), 64);
        assert!(!signer.kid().is_empty());
    }

    #[test]
    fn test_cross_signer_verification() {
        let signer1 = JwtSigner::new_development().unwrap();
        let signer2 = JwtSigner::new_development().unwrap();
        let claims = serde_json::json!({"test": true});
        let token = signer1.sign(&claims).unwrap();

        // signer2 NO puede verificar el token de signer1
        assert!(signer2.verify(&token.jwt).is_err());
    }
}
