// ============================================================
// bauth::server::handlers::user_list — bauth.user.list
//
// Lista cuentas de Subscriber Account (NIST SP 800-63-4 §3.1).
// DDL v2.12.0: idn_user = tabla canónica de cuentas de login.
// El email es un atributo PII almacenado en idn_identity_attribute
// (namespace='contact', attr_key='email'), vinculado al actor (entity_id).
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
        let status_filter = params.get("status").and_then(|v| v.as_str());

        if let Some(ref pg) = self.pg_pool {
            #[derive(sqlx::FromRow)]
            struct UserRow {
                user_id: uuid::Uuid,
                username: String,
                tenant_id: uuid::Uuid,
                status: String,
                loa_min: String,
                last_login_at: Option<chrono::DateTime<chrono::Utc>>,
                created_at: chrono::DateTime<chrono::Utc>,
                email: Option<String>,
            }

            let result = if let Some(st) = status_filter {
                sqlx::query_as::<_, UserRow>(
                    "SELECT u.user_id, u.username, u.tenant_id, u.status, u.loa_min,
                            u.last_login_at, u.created_at,
                            ia.attr_value #>> '{}' AS email
                     FROM bauth.idn_user u
                     LEFT JOIN bauth.idn_identity_attribute ia
                       ON ia.entity_id = u.entity_id
                      AND ia.attr_key = 'email'
                      AND ia.is_active = true
                     WHERE u.status = $1
                     ORDER BY u.created_at DESC NULLS LAST
                     LIMIT $2"
                ).bind(st).bind(limit).fetch_all(pg).await
            } else {
                sqlx::query_as::<_, UserRow>(
                    "SELECT u.user_id, u.username, u.tenant_id, u.status, u.loa_min,
                            u.last_login_at, u.created_at,
                            ia.attr_value #>> '{}' AS email
                     FROM bauth.idn_user u
                     LEFT JOIN bauth.idn_identity_attribute ia
                       ON ia.entity_id = u.entity_id
                      AND ia.attr_key = 'email'
                      AND ia.is_active = true
                     ORDER BY u.created_at DESC NULLS LAST
                     LIMIT $1"
                ).bind(limit).fetch_all(pg).await
            };

            match result {
                Ok(rows) => {
                    let users: Vec<Value> = rows.iter().map(|u| {
                        serde_json::json!({
                            "user_id": u.user_id.to_string(),
                            "username": u.username,
                            "email": u.email,
                            "status": u.status,
                            "loa_min": u.loa_min,
                            "tenant_id": u.tenant_id.to_string(),
                            "last_login_at": u.last_login_at.map(|d| d.to_rfc3339()),
                            "created_at": u.created_at.to_rfc3339(),
                        })
                    }).collect();
                    let count = users.len();
                    return Ok(serde_json::json!({
                        "users": users,
                        "count": count,
                        "source": "idn_user",
                        "message": format!("{} cuentas cargadas", count),
                    }));
                }
                Err(e) => {
                    tracing::warn!(error = %e, "user.list: error consultando idn_user");
                }
            }
        }

        Ok(serde_json::json!({
            "users": [], "count": 0, "source": "none",
            "message": "Base de datos no disponible — sin usuarios cargados.",
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
