// ============================================================
// bauth::server::handlers::user_template — B11 UserTemplate CRUD
// H-011 FIX: validacion UUID explicita en todos los handlers
// ============================================================
#![allow(dead_code)]

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

/// Valida y parsea UUID. H-011 FIX: error descriptivo en vez de nil silencioso.
fn parse_uuid(param: &str, value: &str) -> Result<Uuid, JsonRpcError> {
    Uuid::parse_str(value).map_err(|_| JsonRpcError {
        code: -32602,
        message: format!("{}: UUID invalido — '{}'", param, value),
        data: None,
    })
}

// ── Get User ─────────────────────────────────────────────────

pub struct UserGetHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let uuid = parse_uuid("uuid", uuid_str)?;

        #[derive(sqlx::FromRow)]
        struct Row {
            uuid: Uuid, username: String, email: String,
            tenant_id: String, empresa_id: String, sucursal_id: Option<String>,
            pos_logico: Option<String>, rol_ids: Vec<String>, status: String,
            rol_bitmask_base64: String, template: serde_json::Value,
            template_version: String, created_at: chrono::DateTime<chrono::Utc>,
            updated_at: chrono::DateTime<chrono::Utc>,
        }

        let row: Row = sqlx::query_as(
            "SELECT uuid, username, email, tenant_id, empresa_id, sucursal_id,
                    pos_logico, rol_ids, status, rol_bitmask_base64, template,
                    template_version, created_at, updated_at
             FROM bauth.idn_user_template WHERE uuid = $1"
        ).bind(uuid).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error: {}", e), data: None,
        })?.ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("usuario no encontrado: {}", uuid), data: None,
        })?;

        Ok(serde_json::json!({
            "uuid": row.uuid, "username": row.username, "email": row.email,
            "tenant_id": row.tenant_id, "empresa_id": row.empresa_id,
            "sucursal_id": row.sucursal_id, "pos_logico": row.pos_logico,
            "rol_ids": row.rol_ids, "status": row.status,
            "template_version": row.template_version, "template": row.template,
            "created_at": row.created_at, "updated_at": row.updated_at,
        }))
    }
}

// ── Create User ──────────────────────────────────────────────

pub struct UserCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let username = params.get("username").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "username requerido".into(), data: None })?;
        let email = params.get("email").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "email requerido".into(), data: None })?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str()).unwrap_or("default");
        let empresa_id = params.get("empresa_id").and_then(|v| v.as_str()).unwrap_or("default");
        let template = params.get("template").cloned().unwrap_or(serde_json::json!({}));
        // Validar 15 secciones UserTemplate v6.0
        let validation = crate::domain::usertemplate_validator::validate_usertemplate(&template);
        if !validation.valid {
            return Err(JsonRpcError {
                code: -32602,
                message: format!("template invalido: {} errores", validation.section_errors.len()),
                data: Some(serde_json::json!({"errors": validation.section_errors})),
            });
        }
        let rol_ids: Vec<String> = params.get("rol_ids").and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default();

        let uuid = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.idn_user_template (uuid, username, email, tenant_id, empresa_id, template, rol_ids, status)
             VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE')"
        ).bind(uuid).bind(username).bind(email).bind(tenant_id).bind(empresa_id)
         .bind(&template).bind(&rol_ids)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error creando usuario: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"created": true, "uuid": uuid.to_string(), "username": username}))
    }
}

// ── Update User ──────────────────────────────────────────────

pub struct UserUpdateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let uuid = parse_uuid("uuid", uuid_str)?;

        if let Some(t) = params.get("template") {
            sqlx::query("UPDATE bauth.idn_user_template SET template=$2, email=COALESCE($3,email), updated_at=now() WHERE uuid=$1")
                .bind(uuid).bind(t).bind(params.get("email").and_then(|v| v.as_str()))
                .execute(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error actualizando: {}", e), data: None,
            })?;
            return Ok(serde_json::json!({"updated": true, "uuid": uuid_str}));
        }

        sqlx::query("UPDATE bauth.idn_user_template SET email=COALESCE($2,email), updated_at=now() WHERE uuid=$1")
            .bind(uuid).bind(params.get("email").and_then(|v| v.as_str()))
            .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error actualizando: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"updated": true, "uuid": uuid_str}))
    }
}

// ── Delete User (soft) ───────────────────────────────────────

pub struct UserDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let uuid = parse_uuid("uuid", uuid_str)?;

        sqlx::query("UPDATE bauth.idn_user_template SET status='INACTIVE', termination_date=now(), updated_at=now() WHERE uuid=$1 AND status='ACTIVE'")
            .bind(uuid).execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error desactivando usuario: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"deleted": true, "uuid": uuid_str, "status": "INACTIVE"}))
    }
}

// ── Assign Role ──────────────────────────────────────────────

pub struct UserAssignRoleHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserAssignRoleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let role_id = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_id requerido".into(), data: None })?;
        let uuid = parse_uuid("uuid", uuid_str)?;

        sqlx::query(
            "UPDATE bauth.idn_user_template SET rol_ids = array_append(rol_ids, $2), updated_at=now()
             WHERE uuid=$1 AND NOT ($2 = ANY(rol_ids))"
        ).bind(uuid).bind(role_id).execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error asignando rol: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"assigned": true, "uuid": uuid_str, "role_id": role_id}))
    }
}

// ── Revoke Role ──────────────────────────────────────────────

pub struct UserRevokeRoleHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserRevokeRoleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let role_id = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_id requerido".into(), data: None })?;
        let uuid = parse_uuid("uuid", uuid_str)?;

        sqlx::query(
            "UPDATE bauth.idn_user_template SET rol_ids = array_remove(rol_ids, $2), updated_at=now()
             WHERE uuid=$1"
        ).bind(uuid).bind(role_id).execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error revocando rol: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"revoked": true, "uuid": uuid_str, "role_id": role_id}))
    }
}
