// ============================================================
// bauth::server::handlers::webauthn_handlers — G3 WebAuthn API
// ============================================================
#![allow(dead_code)]

use crate::domain::auth_methods::webauthn::WebAuthnValidator;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct WebAuthnRegisterHandler { pub validator: Arc<WebAuthnValidator> }
#[async_trait::async_trait]
impl JsonRpcHandler for WebAuthnRegisterHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id = params.get("user_id").and_then(|v| v.as_str()).unwrap_or("anonymous");
        let username = params.get("username").and_then(|v| v.as_str()).unwrap_or("user");
        Ok(self.validator.start_registration(user_id, username))
    }
}

pub struct WebAuthnVerifyRegistrationHandler { pub validator: Arc<WebAuthnValidator> }
#[async_trait::async_trait]
impl JsonRpcHandler for WebAuthnVerifyRegistrationHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let state = params.get("state").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "state requerido".into(), data: None })?;
        let response = params.get("response").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "response requerido".into(), data: None })?;
        self.validator.finish_registration(state, response)
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })
    }
}

pub struct WebAuthnAuthenticateHandler { pub validator: Arc<WebAuthnValidator> }
#[async_trait::async_trait]
impl JsonRpcHandler for WebAuthnAuthenticateHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(self.validator.start_authentication())
    }
}

pub struct WebAuthnVerifyAuthHandler { pub validator: Arc<WebAuthnValidator> }
#[async_trait::async_trait]
impl JsonRpcHandler for WebAuthnVerifyAuthHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let response = params.get("response").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "response requerido".into(), data: None })?;
        // La clave pública del credential registrado es OBLIGATORIA para verificar la firma
        // (W3C §7.2). Sin ella no se puede autenticar → fail-closed.
        // Arquitectura completa (pendiente, ver A.41 §base): el handler la buscará por
        // credential_id en la tabla de credenciales; hoy la recibe como parámetro del llamante.
        let pk_b64 = params.get("public_key_b64").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "public_key_b64 del credential requerido (registro)".into(), data: None })?;
        let public_key = data_encoding::BASE64URL_NOPAD.decode(pk_b64.as_bytes())
            .or_else(|_| data_encoding::BASE64.decode(pk_b64.as_bytes()))
            .map_err(|_| JsonRpcError { code: -32602, message: "public_key_b64 con codificación inválida".into(), data: None })?;
        self.validator.finish_authentication(&public_key, response)
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })
    }
}
