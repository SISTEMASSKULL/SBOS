use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct SyncStatusHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for SyncStatusHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(serde_json::json!({
            "reconciler": "reconcile_loop", "interval_secs": 60,
            "last_run": null, "status": "pending_implementation",
            "message": "Reconciler planificado para B41."
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[tokio::test]
    async fn test_sync_status_pending() {
        let h = SyncStatusHandler;
        let r = h.handle(json!({})).await.unwrap();
        assert_eq!(r["reconciler"], "reconcile_loop");
    }
}
