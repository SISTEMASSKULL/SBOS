// ============================================================
// bauth::server::handlers::role_list — bauth.role.list
//
// Handler JSON-RPC: lista roles activos de un tenant.
// Fuente canónica: bauth.idn_roles_rol_hierarchical (DDL v2.12.0)
//
// Eliminado: privilege_role (phantom) → idn_roles_rol_hierarchical
//
// DOC-SBOS-001 N3 · SBOS-049 · ADR-010
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

/// Fila de rol desde `idn_roles_rol_hierarchical`.
#[derive(sqlx::FromRow, serde::Serialize)]
struct RolRow {
    pub id:     uuid::Uuid,
    pub code:   String,
    pub name:   serde_json::Value,
    pub tier:   String,
    pub status: String,
    pub depth:  i32,
}

pub struct RoleListHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for RoleListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000,
            message: "base de datos no disponible".into(),
            data: None,
        })?;

        let tenant_id_str = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "tenant_id requerido".into(),
                data: None,
            })?;

        let tenant_id = uuid::Uuid::parse_str(tenant_id_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("tenant_id inválido: {}", tenant_id_str),
            data: None,
        })?;

        let rows: Vec<RolRow> = sqlx::query_as(
            r#"
            SELECT id,
                   code,
                   name,
                   tier::text   AS tier,
                   status::text AS status,
                   depth
            FROM bauth.idn_roles_rol_hierarchical
            WHERE tenant_id = $1
              AND status    = 'ACTIVE'
            ORDER BY tier, depth, code
            "#,
        )
        .bind(tenant_id)
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000,
            message: e.to_string(),
            data: None,
        })?;

        let count = rows.len();
        Ok(serde_json::json!({ "roles": rows, "count": count }))
    }
}
