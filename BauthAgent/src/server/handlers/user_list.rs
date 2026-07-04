// ============================================================
// bauth::server::handlers::user_list — bauth.user.list
//
// Consulta usuarios desde idn_user_template (PostgreSQL).
// Keycloak es el motor de autenticación, pero la fuente de verdad
// de identidad es bauth_db.
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct UserListHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for UserListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let limit = params.get("limit").and_then(|v| v.as_u64()).unwrap_or(100) as i64;

        // Intentar BD primero
        if let Some(ref pg) = self.pg_pool {
            #[derive(sqlx::FromRow)]
            struct UserRow {
                uuid: uuid::Uuid,
                username: String,
                email: Option<String>,
                status: Option<String>,
                tenant_id: Option<String>,
                rol_ids: Option<Vec<String>>,
                last_login_at: Option<chrono::DateTime<chrono::Utc>>,
                created_at: Option<chrono::DateTime<chrono::Utc>>,
            }

            match sqlx::query_as::<_, UserRow>(
                "SELECT uuid, username, email, status, tenant_id, rol_ids,
                        last_login_at, created_at
                 FROM bauth.idn_user_template
                 ORDER BY created_at DESC NULLS LAST
                 LIMIT $1"
            ).bind(limit).fetch_all(pg).await
            {
                Ok(rows) => {
                    let users: Vec<Value> = rows.iter().map(|u| {
                        serde_json::json!({
                            "uuid": u.uuid.to_string(),
                            "username": u.username.clone(),
                            "email": u.email.clone(),
                            "status": u.status.clone(),
                            "tenant_id": u.tenant_id.clone(),
                            "roles": u.rol_ids.clone().unwrap_or_default(),
                            "last_login": u.last_login_at.map(|d| d.to_rfc3339()),
                            "created_at": u.created_at.map(|d| d.to_rfc3339()),
                        })
                    }).collect();
                    return Ok(serde_json::json!({
                        "users": users, "count": users.len(), "source": "idn_user_template",
                        "message": format!("{} usuarios cargados desde bauth_db", users.len())
                    }));
                }
                Err(e) => {
                    tracing::warn!(error = %e, "user.list: error consultando idn_user_template");
                }
            }
        }

        // Fallback sin BD
        Ok(serde_json::json!({
            "users": [], "count": 0, "source": "none",
            "message": "Base de datos no disponible — sin usuarios cargados."
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn test_user_list_no_db() {
        let h = UserListHandler { pg_pool: None };
        let r = h.handle(json!({})).await.unwrap();
        assert_eq!(r["source"], "none");
        assert_eq!(r["count"], 0);
    }
}
