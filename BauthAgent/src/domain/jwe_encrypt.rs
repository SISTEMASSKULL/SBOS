// ============================================================
// bauth::domain::jwe_encrypt — Cifrado JWE (RFC 7516)
// B48.T02 — Cifrado AES-256-GCM para tokens sensibles
//
// JWE Compact Serialization:
//   header.encrypted_key.iv.ciphertext.tag
//
// Algoritmos:
//   Key Encryption:  dir (direct encryption)
//   Content Encryption: A256GCM (AES-256-GCM, FIPS 197)
//
// DOC-SBOS-001 N3 · RFC 7516 · NIST SP 800-38D
// ============================================================

#![allow(dead_code)]
use aes_gcm::aead::{Aead, KeyInit, OsRng};
use aes_gcm::{Aes256Gcm, Nonce};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use rand::RngCore;

/// Resultado del cifrado JWE.
pub struct JweToken {
    /// JWE compacto: header.key.iv.ciphertext.tag
    pub compact: String,
    pub header_b64: String,
    pub encrypted_key_b64: String,
    pub iv_b64: String,
    pub ciphertext_b64: String,
    pub tag_b64: String,
}

/// Cifrador JWE con AES-256-GCM.
pub struct JweEncryptor {
    cipher: Aes256Gcm,
}

impl JweEncryptor {
    /// Crea un nuevo cifrador con una clave AES-256-GCM aleatoria.
    pub fn new_random() -> Self {
        let mut key = [0u8; 32];
        OsRng.fill_bytes(&mut key);
        // SAFETY: key se genera con 32 bytes exactos (OsRng.fill_bytes(&mut [0u8; 32]))
        // Aes256Gcm::new_from_slice solo falla si key.len() != 32
        let cipher = Aes256Gcm::new_from_slice(&key)
            .expect("clave AES-256-GCM inválida — imposible: key generada con 32 bytes exactos");
        Self { cipher }
    }

    /// Cifra un payload JWT y retorna el JWE compacto.
    pub fn encrypt_jwt(&self, jwt: &str) -> Result<JweToken, String> {
        // Generar IV aleatorio (96 bits = 12 bytes para GCM)
        let mut iv_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut iv_bytes);
        let nonce = Nonce::from_slice(&iv_bytes);

        // Cifrar el JWT con AES-256-GCM
        let ciphertext = self.cipher
            .encrypt(nonce, jwt.as_bytes())
            .map_err(|e| format!("error cifrando JWT: {}", e))?;

        // Separar ciphertext (últimos 16 bytes son el tag de autenticación GCM)
        let tag_start = ciphertext.len().saturating_sub(16);
        let ct = &ciphertext[..tag_start];
        let tag = &ciphertext[tag_start..];

        // Construir header JWE
        let header = serde_json::json!({
            "alg": "dir",
            "enc": "A256GCM",
            "typ": "JWT",
        });
        let header_json = serde_json::to_string(&header)
            .map_err(|e| format!("header: {}", e))?;
        let header_b64 = URL_SAFE_NO_PAD.encode(header_json.as_bytes());
        let iv_b64 = URL_SAFE_NO_PAD.encode(iv_bytes);
        let ct_b64 = URL_SAFE_NO_PAD.encode(ct);
        let tag_b64 = URL_SAFE_NO_PAD.encode(tag);

        // encrypted_key vacío (dir = direct encryption)
        let ek_b64 = String::new();

        // JWE Compact: header..iv.ciphertext.tag
        let compact = format!(
            "{}.{}.{}.{}.{}",
            header_b64, ek_b64, iv_b64, ct_b64, tag_b64
        );

        Ok(JweToken {
            compact,
            header_b64,
            encrypted_key_b64: ek_b64,
            iv_b64,
            ciphertext_b64: ct_b64,
            tag_b64,
        })
    }

    /// Descifra un JWE compacto y retorna el JWT original.
    pub fn decrypt_jwe(&self, jwe: &str) -> Result<String, String> {
        let parts: Vec<&str> = jwe.split('.').collect();
        if parts.len() != 5 {
            return Err("JWE inválido: formato incorrecto".into());
        }

        let iv = URL_SAFE_NO_PAD
            .decode(parts[2].as_bytes())
            .map_err(|e| format!("iv: {}", e))?;
        let ct = URL_SAFE_NO_PAD
            .decode(parts[3].as_bytes())
            .map_err(|e| format!("ct: {}", e))?;
        let tag = URL_SAFE_NO_PAD
            .decode(parts[4].as_bytes())
            .map_err(|e| format!("tag: {}", e))?;

        // Reconstruir ciphertext + tag
        let mut ciphertext = ct;
        ciphertext.extend_from_slice(&tag);

        let nonce = Nonce::from_slice(&iv);
        let plaintext = self.cipher
            .decrypt(nonce, ciphertext.as_slice())
            .map_err(|_| "descifrado fallido — clave incorrecta o datos corruptos".to_string())?;

        String::from_utf8(plaintext)
            .map_err(|e| format!("utf8: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt_roundtrip() {
        let encryptor = JweEncryptor::new_random();
        let jwt = "eyJhbGciOiJFZERTQSJ9.eyJzdWIiOiJ1c2VyLTEyMyJ9.signature";

        let jwe = encryptor.encrypt_jwt(jwt).unwrap();
        assert!(!jwe.compact.is_empty());
        assert!(jwe.compact.contains('.'));
        // JWE debe ser diferente del JWT original
        assert_ne!(jwe.compact, jwt);

        let decrypted = encryptor.decrypt_jwe(&jwe.compact).unwrap();
        assert_eq!(decrypted, jwt);
    }

    #[test]
    fn test_jwe_has_five_parts() {
        let encryptor = JweEncryptor::new_random();
        let jwe = encryptor.encrypt_jwt("test-jwt").unwrap();
        let parts: Vec<&str> = jwe.compact.split('.').collect();
        assert_eq!(parts.len(), 5, "JWE debe tener 5 partes");
    }
}
