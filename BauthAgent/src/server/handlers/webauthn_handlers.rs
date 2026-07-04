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
        let state = params.get("state").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "state requerido".into(), data: None })?;
        let response = params.get("response").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "response requerido".into(), data: None })?;
        self.validator.finish_authentication(state, response)
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })
    }
}
