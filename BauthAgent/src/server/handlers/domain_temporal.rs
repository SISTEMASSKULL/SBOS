// B6: TemporalDomain (D4) — horarios, turnos, feriados (Policy-Path encadenado a D1)
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
pub struct TemporalAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for TemporalAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        #[derive(sqlx::FromRow, serde::Serialize)] struct Row { atom_slug: String, atom_name: Option<String>, domain_number: i32, atom_position: i64 }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT path AS atom_slug, name->>'es' AS atom_name, domain_number, atom_position
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND domain_number = 4 AND is_active = TRUE
             ORDER BY atom_position"
        ).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"domain":"temporal","domain_number":4,"atoms":rows,"count":rows.len()}))
    }
}
