// ============================================================
// bauth::server::handlers::sign_internal — bauth.sign.internal
//
// Firma digital interna con EdDSA Ed25519 (Vault PKI o ring dev).
// Retorna: firma hex, clave pública, algoritmo, kid.
// ============================================================
use crate::domain::jwt_signer::JwtSigner;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct SignInternalHandler {
    pub signer: Arc<JwtSigner>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for SignInternalHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let payload = params.get("payload").and_then(|v| v.as_str()).unwrap_or("");
        if payload.is_empty() {
            return Err(JsonRpcError {
                code: -32602, message: "payload requerido (texto a firmar)".into(), data: None,
            });
        }

        let payload_struct = serde_json::json!({
            "payload": payload,
            "iat": chrono::Utc::now().timestamp(),
        });

        let sig = self.signer.sign(&payload_struct).map_err(|e| JsonRpcError {
            code: -32000, message: format!("error al firmar: {}", e), data: None,
        })?;

        Ok(serde_json::json!({
            "jwt": sig.jwt,
            "signature_b64": sig.signature_b64,
            "algorithm": sig.algorithm,
            "kid": sig.kid,
            "public_key_hex": self.signer.public_key_hex(),
            "payload_signed": payload,
        }))
    }
}
