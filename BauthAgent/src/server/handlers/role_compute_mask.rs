use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct RoleComputeMaskHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleComputeMaskHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_id requerido".into(), data: None })?;
        let role_id = uuid::Uuid::parse_str(role_id_str)
            .map_err(|_| JsonRpcError { code: -32602, message: "role_id inválido".into(), data: None })?;
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let mask = crate::bitmask::resolver::compute_rol_bitmask(pg, role_id)
            .await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        let positions: Vec<usize> = mask.active_positions().collect();
        Ok(serde_json::json!({
            "role_id": role_id_str, "total_atoms": mask.len(),
            "active_count": positions.len(), "active_positions": positions,
            "base64": mask.to_base64(),
        }))
    }
}
