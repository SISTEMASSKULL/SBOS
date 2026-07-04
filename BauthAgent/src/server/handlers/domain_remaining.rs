// ============================================================
// Handlers para listar ÁTOMOS de dominios D9-D12 en privilege_atom
//
// ESTADO: NO REGISTRADO en mod.rs ni en main.rs.
// Sirven para bauth.domain.credential.list, .delegation.list, etc.
// La evaluación de POLÍTICAS D9-D12 está en policy_domain.rs (B9.T24).
// Registrar aquí si se necesita listar los átomos (no las políticas).
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

macro_rules! domain_handler {
    ($name:ident, $code:expr, $label:expr) => {
        pub struct $name { pub pg_pool: Option<sqlx::PgPool> }
        #[async_trait::async_trait]
        impl JsonRpcHandler for $name {
            async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
                let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
                #[derive(sqlx::FromRow, serde::Serialize)]
                struct Row { atom_slug: String, atom_name: String, app_code: i16, group_code: i16, verb_code: i16, atom_position: i32 }
                let rows: Vec<Row> = sqlx::query_as(
                    "SELECT atom_slug, atom_name, app_code, group_code, verb_code, atom_position FROM bauth.privilege_atom WHERE domain_code = $1 ORDER BY atom_position"
                ).bind($code).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
                Ok(serde_json::json!({"domain": $label, "domain_code": $code, "atoms": rows, "count": rows.len()}))
            }
        }
    };
}

domain_handler!(CredentialAtomsHandler, 9, "credential");
domain_handler!(DelegationAtomsHandler, 10, "delegation");
domain_handler!(AuditAtomsHandler, 11, "audit");
domain_handler!(BlockchainAtomsHandler, 12, "blockchain");
