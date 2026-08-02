// ============================================================
// bauth::server::handlers::policy_evaluate — bauth.policy.evaluate
//
// Handler JSON-RPC: evalúa políticas para una operación.
//
// Estado: privilege_atom_policy eliminada (D05b — sin equivalente canónico).
// Las políticas por operación se implementarán vía auth_policy (D01).
// Por ahora retorna lista vacía (sin restricciones adicionales).
//
// DOC-SBOS-001 N3 · SBOS-049
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct PolicyEvaluateHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyEvaluateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        // Validar params requeridos (preservado para compatibilidad de interfaz)
        let app_code: i16 = params.get("app_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "app_code requerido".into(), data: None,
            })? as i16;
        let group_code: i16 = params.get("group_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "group_code requerido".into(), data: None,
            })? as i16;
        let atom_code: i32 = params.get("atom_code").and_then(|v| v.as_i64())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "atom_code requerido".into(), data: None,
            })? as i32;

        // privilege_atom_policy eliminada (D05b) — sin cadena de políticas por átomo.
        // Migración pendiente: auth_policy por dominio (D01).
        Ok(serde_json::json!({
            "atom": {
                "app_code":   app_code,
                "group_code": group_code,
                "atom_code":  atom_code
            },
            "policies_count": 0,
            "policies": [],
            "nota": "cadena de políticas por átomo pendiente de migración a auth_policy (D01)"
        }))
    }
}
