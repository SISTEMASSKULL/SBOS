// ============================================================
// bauth::server::handlers::tenant_list — bauth.tenant.list
//
// Lista tenants registrados desde idn_tenant (PostgreSQL).
// Retorna: tenant_id, slug, nombre, plan, estado.
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct TenantListHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for TenantListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        #[derive(sqlx::FromRow)]
        struct TenantRow {
            tenant_id: uuid::Uuid,
            tenant_slug: String,
            tenant_name: String,
            plan_tier: Option<String>,
            status: Option<String>,
            legal_name: Option<String>,
            domain: Option<String>,
            created_at: Option<chrono::DateTime<chrono::Utc>>,
        }

        let rows: Vec<TenantRow> = sqlx::query_as(
            "SELECT tenant_id, tenant_slug, tenant_name,
                    plan_tier::text AS plan_tier, status::text AS status,
                    legal_name, domain, created_at
             FROM bauth.idn_tenant
             ORDER BY created_at DESC"
        ).fetch_all(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando tenants: {}", e), data: None,
        })?;

        let tenants: Vec<Value> = rows.iter().map(|t| {
            serde_json::json!({
                "tenant_id": t.tenant_id.to_string(),
                "slug": t.tenant_slug,
                "name": t.tenant_name,
                "legal_name": t.legal_name,
                "plan": t.plan_tier,
                "status": t.status,
                "domain": t.domain,
                "created_at": t.created_at.map(|d| d.to_rfc3339()),
            })
        }).collect();

        Ok(serde_json::json!({
            "count": tenants.len(),
            "tenants": tenants,
        }))
    }
}
