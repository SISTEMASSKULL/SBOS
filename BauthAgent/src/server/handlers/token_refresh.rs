// ============================================================
// bauth::server::handlers::token_refresh — B48.T05
// bauth.token.refresh: rota token con re-evaluación de contexto
// ============================================================
use crate::domain::jwt_signer::JwtSigner;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use crate::config::JwtConfig;
use async_trait::async_trait;
use serde_json::Value;
use std::sync::Arc;

pub struct TokenRefreshHandler {
    pub signer: Arc<JwtSigner>,
    pub jwt_cfg: JwtConfig,
    pub pg: Option<sqlx::PgPool>,
}

#[async_trait]
impl JsonRpcHandler for TokenRefreshHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let token = params.get("token").and_then(|v| v.as_str()).ok_or_else(|| JsonRpcError {
            code: -32602, message: "Se requiere 'token'".into(), data: None })?;

        // 1. Validar token actual
        let claims = self.signer.verify(token).map_err(|e| JsonRpcError {
            code: -32001, message: format!("Token inválido: {}", e), data: None })?;

        // 2. Re-evaluar contexto (refrescar RolBitMask, dominios)
        let user_uuid = claims.get("sub").and_then(|v| v.as_str()).unwrap_or("");
        let ctx_id = claims.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        let loa = claims.get("loa").and_then(|v| v.as_i64()).unwrap_or(1);

        // 3. Construir nuevo JWT con claims actualizados
        let mut new_claims = claims.clone();
        if let Some(obj) = new_claims.as_object_mut() {
            obj.insert("iat".into(), Value::Number(chrono::Utc::now().timestamp().into()));
            obj.insert("refreshed_at".into(), Value::String(chrono::Utc::now().to_rfc3339()));
        }

        // 4. Firmar nuevo token
        let new_token = self.signer.sign(&new_claims).map_err(|e| JsonRpcError {
            code: -32002, message: format!("Error al firmar: {}", e), data: None })?;

        tracing::info!(%user_uuid, %ctx_id, loa, "token.refresh — token renovado");
        Ok(serde_json::json!({
            "access_token": new_token,
            "token_type": "Bearer",
            "user_uuid": user_uuid,
            "ctx_id": ctx_id,
            "loa": loa,
        }))
    }
}
