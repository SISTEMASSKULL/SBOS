// ============================================================
// bauth::server::jsonrpc — JSON-RPC 2.0 Dispatcher (ADR-020)
//
// TIPOS + DISPATCHER solamente. Handlers en src/server/handlers/.
// DOC-SBOS-001 N3 · ADR-020 Interface Dual §2
// ============================================================

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;

// ─── JSON-RPC 2.0 Types ────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct Request {
    pub jsonrpc: String,
    pub method: String,
    #[serde(default)]
    pub params: Value,
    pub id: Value,
}

#[derive(Debug, Serialize)]
pub struct Response {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
    pub id: Value,
}

#[derive(Debug, Serialize)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

impl Response {
    pub fn success(id: Value, result: Value) -> Self {
        Self { jsonrpc: "2.0".into(), result: Some(result), error: None, id }
    }
    pub fn error(id: Value, code: i32, message: &str) -> Self {
        Self { jsonrpc: "2.0".into(), result: None,
            error: Some(JsonRpcError { code, message: message.into(), data: None }), id }
    }
    pub fn method_not_found(id: Value) -> Self {
        Self::error(id, -32601, "método no encontrado")
    }
    pub fn invalid_request(id: Value, msg: &str) -> Self {
        Self::error(id, -32600, msg)
    }
    pub fn parse_error() -> Self {
        Self::error(Value::Null, -32700, "error de parseo JSON-RPC")
    }
}

// ─── Handler trait ─────────────────────────────────────────

/// Un handler JSON-RPC — recibe params y retorna result.
#[async_trait::async_trait]
pub trait JsonRpcHandler: Send + Sync {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError>;
}

/// Catálogo de métodos JSON-RPC 2.0.
pub struct JsonRpcDispatcher {
    handlers: HashMap<String, Arc<dyn JsonRpcHandler>>,
}

impl JsonRpcDispatcher {
    pub fn new() -> Self {
        Self { handlers: HashMap::new() }
    }

    /// Registra un handler para un método (ej: "bauth.health.check").
    pub fn register(&mut self, method: &str, handler: Arc<dyn JsonRpcHandler>) {
        self.handlers.insert(method.to_string(), handler);
    }

    /// Procesa un string JSON y retorna la respuesta serializada (async).
    pub async fn handle_jsonrpc(&self, json_str: &str) -> String {
        let request: Request = match serde_json::from_str(json_str) {
            Ok(r) => r,
            Err(_e) => return serde_json::to_string(&Response::parse_error()).unwrap_or_default(),
        };

        if request.jsonrpc != "2.0" {
            return serde_json::to_string(&Response::invalid_request(
                request.id, "jsonrpc debe ser '2.0'")).unwrap_or_default();
        }

        let handler = match self.handlers.get(&request.method) {
            Some(h) => h,
            None => return serde_json::to_string(
                &Response::method_not_found(request.id)).unwrap_or_default(),
        };

        match handler.handle(request.params).await {
            Ok(result) => serde_json::to_string(
                &Response::success(request.id, result)).unwrap_or_default(),
            Err(e) => serde_json::to_string(
                &Response::error(request.id, e.code, &e.message)).unwrap_or_default(),
        }
    }

    pub fn list_methods(&self) -> Vec<String> {
        let mut methods: Vec<String> = self.handlers.keys().cloned().collect();
        methods.sort();
        methods
    }
}
