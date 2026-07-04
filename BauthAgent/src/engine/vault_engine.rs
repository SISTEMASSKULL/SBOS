// ============================================================
// bauth::engine::vault_engine — G6 Vault PKI Client
//
// HashiCorp Vault integration para emision de certificados X.509.
//   - PKI Secrets Engine: emitir/revocar certificados
//   - AppRole/Token auth
//   - Facturacion SIN (Bolivia): RSA-SHA256 certificates (Ley 164)
//   - mTLS: certificados cliente para M2M
//
// Vault es parte de S02 (gateway) en el stack SBOS.
// bAuth usa Vault SOLO para EMITIR certificados.
// La VALIDACION de certificados es nativa (BAUTH_MTLS).
// ============================================================
#![allow(dead_code)]

use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::info;

#[derive(Debug, Error)]
pub enum VaultError {
    #[error("Vault no disponible: {0}")]
    Connection(String),
    #[error("Vault auth fallida: {0}")]
    AuthFailed(String),
    #[error("Vault PKI: {0}")]
    PkiError(String),
}

/// Cliente Vault para PKI certificate issuance.
pub struct VaultPkiClient {
    vault_url: String,
    http: reqwest::Client,
    token: std::sync::Mutex<Option<CachedToken>>,
}

struct CachedToken {
    value: String,
    expires_at: chrono::DateTime<chrono::Utc>,
}

impl VaultPkiClient {
    pub fn new(vault_url: &str) -> Self {
        Self {
            vault_url: vault_url.trim_end_matches('/').to_string(),
            http: reqwest::Client::new(),
            token: std::sync::Mutex::new(None),
        }
    }

    /// Autenticar via AppRole (recomendado para M2M).
    pub async fn login_approle(&self, role_id: &str, secret_id: &str) -> Result<(), VaultError> {
        let resp: Value = self.http
            .post(format!("{}/v1/auth/approle/login", self.vault_url))
            .json(&serde_json::json!({"role_id": role_id, "secret_id": secret_id}))
            .send().await.map_err(|e| VaultError::Connection(e.to_string()))?
            .json().await.map_err(|e| VaultError::AuthFailed(e.to_string()))?;

        let token = resp["auth"]["client_token"].as_str()
            .ok_or_else(|| VaultError::AuthFailed("no client_token".into()))?;
        let ttl = resp["auth"]["lease_duration"].as_i64().unwrap_or(3600);

        let mut cache = self.token.lock().unwrap();
        *cache = Some(CachedToken {
            value: token.to_string(),
            expires_at: chrono::Utc::now() + chrono::Duration::seconds(ttl.saturating_sub(60)),
        });
        info!(ttl, "Vault AppRole login exitoso");
        Ok(())
    }

    /// Autenticar via Token directo.
    pub fn set_token(&self, token: &str) {
        let mut cache = self.token.lock().unwrap();
        *cache = Some(CachedToken {
            value: token.to_string(),
            expires_at: chrono::Utc::now() + chrono::Duration::hours(24),
        });
    }

    /// Emitir un certificado X.509 via PKI secrets engine.
    /// `role`: nombre del rol PKI en Vault (ej: "sbos-client", "sin-facturacion")
    /// `common_name`: CN del certificado
    /// `ttl`: tiempo de vida (ej: "720h" = 30 dias)
    pub async fn issue_certificate(
        &self, role: &str, common_name: &str, ttl: &str,
    ) -> Result<CertBundle, VaultError> {
        let token = self.get_token()?;
        let resp: Value = self.http
            .post(format!("{}/v1/pki/issue/{}", self.vault_url, role))
            .header("X-Vault-Token", &token)
            .json(&serde_json::json!({"common_name": common_name, "ttl": ttl}))
            .send().await.map_err(|e| VaultError::Connection(e.to_string()))?
            .json().await.map_err(|e| VaultError::PkiError(e.to_string()))?;

        let data = &resp["data"];
        Ok(CertBundle {
            certificate: data["certificate"].as_str().unwrap_or("").to_string(),
            private_key: data["private_key"].as_str().unwrap_or("").to_string(),
            issuing_ca: data["issuing_ca"].as_str().unwrap_or("").to_string(),
            ca_chain: data["ca_chain"].as_array()
                .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
            serial_number: data["serial_number"].as_str().unwrap_or("").to_string(),
        })
    }

    /// Revocar un certificado por serial number.
    pub async fn revoke_certificate(&self, serial_number: &str) -> Result<(), VaultError> {
        let token = self.get_token()?;
        self.http
            .post(format!("{}/v1/pki/revoke", self.vault_url))
            .header("X-Vault-Token", &token)
            .json(&serde_json::json!({"serial_number": serial_number}))
            .send().await.map_err(|e| VaultError::Connection(e.to_string()))?;
        info!(%serial_number, "Vault: certificado revocado");
        Ok(())
    }

    fn get_token(&self) -> Result<String, VaultError> {
        let cache = self.token.lock().unwrap();
        match &*cache {
            Some(c) if chrono::Utc::now() < c.expires_at => Ok(c.value.clone()),
            _ => Err(VaultError::AuthFailed("token expirado o no configurado".into())),
        }
    }
}

use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CertBundle {
    pub certificate: String,
    pub private_key: String,
    pub issuing_ca: String,
    pub ca_chain: Vec<String>,
    pub serial_number: String,
}

// ── Tests ──────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_client_creation() {
        let client = VaultPkiClient::new("https://vault.sbos.bo:8200");
        assert!(client.get_token().is_err()); // sin auth previa
    }

    #[test]
    fn test_set_token() {
        let client = VaultPkiClient::new("https://vault:8200");
        client.set_token("test-token");
        assert_eq!(client.get_token().unwrap(), "test-token");
    }
}
