// B2: PhysicalDomain (D2) — puertas, zonas, niveles, dispositivos
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
pub struct PhysicalAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for PhysicalAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        #[derive(sqlx::FromRow, serde::Serialize)] struct Row { atom_slug: String, atom_name: String, atom_position: i32 }
        let rows: Vec<Row> = sqlx::query_as("SELECT atom_slug, atom_name, atom_position FROM bauth.privilege_atom WHERE domain_code = 2 ORDER BY atom_position").fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"domain":"physical","domain_code":2,"atoms":rows,"count":rows.len()}))
    }
}
