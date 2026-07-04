// ============================================================
// bauth::server::handlers::domain_financial — B4 FinancialDomain (D3)
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct FinancialAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for FinancialAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { atom_slug: String, atom_name: String, app_code: i16, group_code: i16, verb_code: i16, atom_position: i32 }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT atom_slug, atom_name, app_code, group_code, verb_code, atom_position FROM bauth.privilege_atom WHERE domain_code = 3 ORDER BY atom_position"
        ).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"domain": "financial", "domain_code": 3, "atoms": rows, "count": rows.len()}))
    }
}
