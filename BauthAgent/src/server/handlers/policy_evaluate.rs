use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct PolicyEvaluateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyEvaluateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        // H-010 FIX: validar params requeridos en vez de defaults arbitrarios
        let app_code: i16 = params.get("app_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "app_code requerido".into(), data: None })? as i16;
        let group_code: i16 = params.get("group_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "group_code requerido".into(), data: None })? as i16;
        let atom_code: i32 = params.get("atom_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "atom_code requerido".into(), data: None })? as i32;
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let rows = crate::db::load_policies_for_atom(pg, app_code, group_code, atom_code)
            .await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        let rules: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "slug": r.policy_slug, "data": r.policy_data,
        })).collect();
        Ok(serde_json::json!({
            "atom": {"app_code": app_code, "group_code": group_code, "atom_code": atom_code},
            "policies_count": rules.len(), "policies": rules,
        }))
    }
}
