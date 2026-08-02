// B2: PhysicalDomain (D2) — puertas, zonas, niveles, dispositivos
//
// Tabla canónica DDL v2.12.0:
//   bauth.idn_roles_template — átomos del dominio D02 (domain_number=2, node_type='atom')
//   reemplaza privilege_atom (phantom D05 eliminado)
//
// DOC-SBOS-001 N3

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

/// Handler: bauth.domain.physical.atoms
/// Lista los átomos del dominio físico D02 (acceso físico, zonas, dispositivos).
pub struct PhysicalAtomsHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PhysicalAtomsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "BD no disponible".into(), data: None,
        })?;

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row {
            path:          String,
            atom_position: i64,
            is_active:     bool,
        }

        let rows: Vec<Row> = sqlx::query_as(
            "SELECT path, atom_position, is_active
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND domain_number = 2 AND is_active = TRUE
             ORDER BY atom_position"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let count = rows.len();
        Ok(serde_json::json!({"domain": "physical", "domain_number": 2, "atoms": rows, "count": count}))
    }
}
