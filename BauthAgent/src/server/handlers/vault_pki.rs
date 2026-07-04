// ============================================================
// bauth::server::handlers::vault_pki — G6 Vault PKI handler
//
// bauth.vault.issue_cert  — emitir certificado X.509
// bauth.vault.revoke_cert — revocar certificado
// bauth.vault.status      — estado de Vault PKI
// ============================================================
#![allow(dead_code)]

use crate::engine::vault_engine::VaultPkiClient;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct VaultIssueCertHandler { pub client: Arc<VaultPkiClient> }

#[async_trait::async_trait]
impl JsonRpcHandler for VaultIssueCertHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role requerido".into(), data: None })?;
        let cn = params.get("common_name").and_then(|v| v.as_str()).unwrap_or("sbos-client");
        let ttl = params.get("ttl").and_then(|v| v.as_str()).unwrap_or("720h");

        let bundle = self.client.issue_certificate(role, cn, ttl).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "issued": true,
            "certificate": bundle.certificate,
            "private_key": bundle.private_key,
            "issuing_ca": bundle.issuing_ca,
            "serial_number": bundle.serial_number,
        }))
    }
}

pub struct VaultRevokeCertHandler { pub client: Arc<VaultPkiClient> }

#[async_trait::async_trait]
impl JsonRpcHandler for VaultRevokeCertHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let serial = params.get("serial_number").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "serial_number requerido".into(), data: None })?;
        self.client.revoke_certificate(serial).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"revoked": true, "serial_number": serial}))
    }
}

pub struct VaultStatusHandler { pub client: Arc<VaultPkiClient> }

#[async_trait::async_trait]
impl JsonRpcHandler for VaultStatusHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(serde_json::json!({
            "engine": "Vault PKI",
            "status": "operativo",
            "roles": ["sbos-client", "sin-facturacion", "mtls-internal"],
            "note": "Vault emite certificados. Validacion nativa en bAuth (BAUTH_MTLS)."
        }))
    }
}
