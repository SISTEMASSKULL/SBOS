// B8: NetworkDomain (D7) — CIDR, VPN, mTLS, device posture (External-Path vía Kong)
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
pub struct NetworkAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for NetworkAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        #[derive(sqlx::FromRow, serde::Serialize)] struct Row { atom_slug: String, atom_name: String, app_code: i16, group_code: i16, verb_code: i16, atom_position: i32 }
        let rows: Vec<Row> = sqlx::query_as("SELECT atom_slug, atom_name, app_code, group_code, verb_code, atom_position FROM bauth.privilege_atom WHERE domain_code = 7 ORDER BY atom_position").fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"domain":"network","domain_code":7,"atoms":rows,"count":rows.len()}))
    }
}
