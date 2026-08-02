// ============================================================
// bauth::server::handlers::domain_logical — B3 LogicalDomain (D1)
//
// Consulta de átomos lógicos y evaluación Fast-Path.
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct LogicalAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for LogicalAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { atom_slug: String, atom_name: Option<String>, domain_number: i32, atom_position: i64 }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT path AS atom_slug, name->>'es' AS atom_name, domain_number, atom_position
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND domain_number = 1 AND is_active = TRUE
             ORDER BY atom_position"
        ).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"domain": "logical", "domain_number": 1, "atoms": rows, "count": rows.len()}))
    }
}
