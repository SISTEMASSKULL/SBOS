// ============================================================
// bauth::server::handlers::health — bauth.health.check
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct HealthHandler { pub socket_path: String }

#[async_trait::async_trait]
impl JsonRpcHandler for HealthHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(serde_json::json!({
            "status": "operativo",
            "version": env!("CARGO_PKG_VERSION"),
            "socket": self.socket_path,
            "uptime_seconds": crate::uptime_seconds()
        }))
    }
}
