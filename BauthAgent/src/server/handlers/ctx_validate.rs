#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct CtxValidateHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for CtxValidateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() {
            return Ok(serde_json::json!({"valid": false, "reason": "ctx_id vacío"}));
        }
        let parts: Vec<&str> = ctx_id.split(':').collect();
        let valid = parts.len() >= 4;
        Ok(serde_json::json!({
            "valid": valid, "ctx_id": ctx_id, "fields_detected": parts.len(),
            "reason": if valid { "estructura válida" } else { "estructura incompleta (mín 4 campos)" }
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[tokio::test]
    async fn test_ctx_validate_empty() {
        let h = CtxValidateHandler;
        let r = h.handle(json!({"ctx_id": ""})).await.unwrap();
        assert_eq!(r["valid"], false);
    }
    #[tokio::test]
    async fn test_ctx_validate_incomplete() {
        let h = CtxValidateHandler;
        let r = h.handle(json!({"ctx_id": "test"})).await.unwrap();
        assert_eq!(r["valid"], false);
    }
}
