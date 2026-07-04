use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct SyncReconcileHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for SyncReconcileHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(serde_json::json!({
            "status": "triggered",
            "message": "Reconciliación disparada — el reconcile loop (60s) verificará drift de políticas, sesiones y roles."
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[tokio::test]
    async fn test_sync_reconcile_triggered() {
        let h = SyncReconcileHandler;
        let r = h.handle(json!({})).await.unwrap();
        assert_eq!(r["status"], "triggered");
    }
}
