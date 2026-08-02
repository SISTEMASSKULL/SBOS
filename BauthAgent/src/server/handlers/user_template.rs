// ============================================================
// bauth::server::handlers::user_template — B11 UserTemplate CRUD
//
// DDL v2.12.0 — Subscriber Account management (NIST SP 800-63-4 §3.1).
//
// Concepto de las tablas:
//   idn_user (T-320):
//     Cuenta de login digital. Una entidad (actor en T-156) puede tener
//     cuentas en múltiples tenants. Contiene: username, status, loa_min,
//     failed_attempts, lockout_until. NO contiene email, empresa_id, rol_ids.
//
//   idn_identity_attribute (T-157):
//     Atributos PII de la entidad. El email es attr_key='email' en
//     namespace='contact'. attr_value es JSONB — texto plano con to_jsonb().
//     La extracción usa: attr_value #>> '{}' para obtener el string.
//
//   privilege_atom_grant (T-041):
//     Concesiones atómicas de privilegio (modelo G-12). CLAVE CONCEPTUAL:
//     privilege_atom_grant.user_id es FK a idn_identity_entity.entity_id
//     (NO a idn_user.user_id). El privilegio se concede al actor (identidad
//     organizacional), no a la cuenta de login. Se resuelve via:
//     idn_user.entity_id → privilege_atom_grant.user_id.
//
//   idn_roles_template (T-162):
//     Catálogo de átomos y jerarquía de roles. node_type='atom' identifica
//     átomos individuales. path = slug único. atom_position = bit en BitMask.
//
// Nota arquitectónica: el parámetro externo "role_id" se trata como atom_path
// (slug del átomo en T-162). Para expansión completa de rol → todos sus átomos,
// el Motor de Identidad debe traversar idn_roles_rol_closure.
// ============================================================
#![allow(dead_code)]

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

/// Parsea UUID con error descriptivo (H-011 FIX).
fn parse_uuid(param: &str, value: &str) -> Result<Uuid, JsonRpcError> {
    Uuid::parse_str(value).map_err(|_| JsonRpcError {
        code: -32602,
        message: format!("{}: UUID inválido — '{}'", param, value),
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
        let user_id = parse_uuid("uuid", uuid_str)?;

        #[derive(sqlx::FromRow)]
        struct Row {
            user_id: Uuid,
            username: String,
            tenant_id: Uuid,
            entity_id: Uuid,
            status: String,
            loa_min: String,
            last_login_at: Option<chrono::DateTime<chrono::Utc>>,
            created_at: chrono::DateTime<chrono::Utc>,
            updated_at: chrono::DateTime<chrono::Utc>,
            email: Option<String>,
        }

        let row: Row = sqlx::query_as(
            "SELECT u.user_id, u.username, u.tenant_id, u.entity_id,
                    u.status, u.loa_min, u.last_login_at, u.created_at, u.updated_at,
                    ia.attr_value #>> '{}' AS email
             FROM bauth.idn_user u
             LEFT JOIN bauth.idn_identity_attribute ia
               ON ia.entity_id = u.entity_id
              AND ia.attr_key = 'email'
              AND ia.is_active = true
             WHERE u.user_id = $1
             LIMIT 1"
        ).bind(user_id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error: {}", e), data: None,
        })?.ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("usuario no encontrado: {}", user_id), data: None,
        })?;

        Ok(serde_json::json!({
            "uuid": row.user_id.to_string(),
            "username": row.username,
            "tenant_id": row.tenant_id.to_string(),
            "entity_id": row.entity_id.to_string(),
            "email": row.email,
            "status": row.status,
            "loa_min": row.loa_min,
            "last_login_at": row.last_login_at.map(|d| d.to_rfc3339()),
            "created_at": row.created_at.to_rfc3339(),
            "updated_at": row.updated_at.to_rfc3339(),
        }))
    }
}

// ── Create User ──────────────────────────────────────────────
// Requiere entity_id previo: el nodo actor (level='actor') debe existir
// en idn_identity_entity antes de crear la cuenta de login en idn_user.

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
        let tenant_id = parse_uuid("tenant_id",
            params.get("tenant_id").and_then(|v| v.as_str())
                .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_id requerido".into(), data: None })?
        )?;
        let entity_id = parse_uuid("entity_id",
            params.get("entity_id").and_then(|v| v.as_str())
                .ok_or_else(|| JsonRpcError { code: -32602, message: "entity_id requerido (nodo actor en idn_identity_entity)".into(), data: None })?
        )?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        // Validar template si se provee (15 secciones UserTemplate v6.0)
        if let Some(t) = params.get("template") {
            let validation = crate::domain::usertemplate_validator::validate_usertemplate(t);
            if !validation.valid {
                return Err(JsonRpcError {
                    code: -32602,
                    message: format!("template inválido: {} errores", validation.section_errors.len()),
                    data: Some(serde_json::json!({"errors": validation.section_errors})),
                });
            }
        }

        let user_id = Uuid::now_v7();

        // 1. Crear la cuenta de login en idn_user
        sqlx::query(
            "INSERT INTO bauth.idn_user
             (user_id, tenant_id, entity_id, username, status, registration_method, ctx_id)
             VALUES ($1, $2, $3, $4, 'PENDING_ACTIVATION', 'ADMIN', $5)"
        ).bind(user_id).bind(tenant_id).bind(entity_id).bind(username).bind(ctx_id)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error creando usuario: {}", e), data: None,
        })?;

        // 2. Registrar email como atributo PII del actor (namespace='contact', attr_key='email')
        sqlx::query(
            "INSERT INTO bauth.idn_identity_attribute
             (entity_id, attr_namespace, attr_key, attr_value, attr_type,
              pii_category, legal_basis, ctx_id)
             VALUES ($1, 'contact', 'email', to_jsonb($2::text), 'EMAIL',
                     'EMAIL', 'CONTRACT', $3)
             ON CONFLICT (entity_id, attr_namespace, attr_key) DO UPDATE
             SET attr_value = to_jsonb($2::text), updated_at = now()"
        ).bind(entity_id).bind(email).bind(ctx_id)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error guardando email: {}", e), data: None,
        })?;

        Ok(serde_json::json!({
            "created": true,
            "user_id": user_id.to_string(),
            "username": username,
            "entity_id": entity_id.to_string(),
        }))
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
        let user_id = parse_uuid("uuid", uuid_str)?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        // Actualizar status en idn_user si se provee
        if let Some(status) = params.get("status").and_then(|v| v.as_str()) {
            sqlx::query(
                "UPDATE bauth.idn_user
                 SET status = $2, updated_at = now(), ctx_id = $3
                 WHERE user_id = $1"
            ).bind(user_id).bind(status).bind(ctx_id)
            .execute(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error actualizando usuario: {}", e), data: None,
            })?;
        }

        // Actualizar email en idn_identity_attribute via JOIN con idn_user.entity_id
        if let Some(email) = params.get("email").and_then(|v| v.as_str()) {
            sqlx::query(
                "UPDATE bauth.idn_identity_attribute ia
                 SET attr_value = to_jsonb($2::text), updated_at = now(), ctx_id = $3
                 FROM bauth.idn_user u
                 WHERE ia.entity_id = u.entity_id
                   AND u.user_id = $1
                   AND ia.attr_key = 'email'
                   AND ia.attr_namespace = 'contact'"
            ).bind(user_id).bind(email).bind(ctx_id)
            .execute(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error actualizando email: {}", e), data: None,
            })?;
        }

        Ok(serde_json::json!({ "updated": true, "uuid": uuid_str }))
    }
}

// ── Delete User (soft) ───────────────────────────────────────
// status='DEACTIVATED' es el estado previo a 'ARCHIVED' (irreversible).

pub struct UserDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let user_id = parse_uuid("uuid", uuid_str)?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        sqlx::query(
            "UPDATE bauth.idn_user
             SET status = 'DEACTIVATED', updated_at = now(), ctx_id = $2
             WHERE user_id = $1
               AND status <> 'ARCHIVED'"
        ).bind(user_id).bind(ctx_id)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error desactivando usuario: {}", e), data: None,
        })?;

        Ok(serde_json::json!({ "deleted": true, "uuid": uuid_str, "status": "DEACTIVATED" }))
    }
}

// ── Assign Atom Grant (antes: Assign Role) ───────────────────
//
// En G-12, los privilegios se otorgan como átomos individuales.
// privilege_atom_grant.user_id es FK a idn_identity_entity.entity_id
// (identidad organizacional del actor), NO a idn_user.user_id.
//
// El parámetro role_id se trata como atom_path (slug en T-162).
// Para otorgar todos los átomos de un rol, se debe iterar sobre
// idn_roles_rol_closure — esta implementación otorga un átomo por llamada.

pub struct UserAssignRoleHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserAssignRoleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let atom_path = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_id (atom_path) requerido".into(), data: None })?;
        let user_id = parse_uuid("uuid", uuid_str)?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        // Obtener tenant_id y entity_id del usuario
        // entity_id es la FK que privilege_atom_grant.user_id referencia
        let (tenant_id, entity_id): (Uuid, Uuid) = sqlx::query_as(
            "SELECT tenant_id, entity_id FROM bauth.idn_user WHERE user_id = $1"
        ).bind(user_id).fetch_one(pg).await.map_err(|_| JsonRpcError {
            code: -32602, message: format!("usuario no encontrado: {}", user_id), data: None,
        })?;

        // Buscar átomo por path en idn_roles_template (T-162)
        let atom = sqlx::query_as::<_, (Uuid, i64)>(
            "SELECT id, atom_position FROM bauth.idn_roles_template
             WHERE path = $1 AND node_type = 'atom' AND is_active = TRUE
             LIMIT 1"
        ).bind(atom_path).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando átomo: {}", e), data: None,
        })?.ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("átomo no encontrado: {}", atom_path), data: None,
        })?;

        let (id_atom, atom_position) = atom;
        // bitmask_value precomputado: valor del bit en la posición del átomo
        let bitmask_value: i64 = 1_i64.checked_shl(atom_position as u32).unwrap_or(atom_position);

        // INSERT grant solo si no existe uno activo para el mismo (entity_id, id_atom)
        sqlx::query(
            "INSERT INTO bauth.privilege_atom_grant
             (tenant_id, user_id, id_atom, atom_position, bitmask_value,
              effect, general, access, grant_type, status, granted_by, ctx_id)
             SELECT $1, $2, $3, $4, $5,
                    TRUE, TRUE, TRUE, 'STANDARD', 'ACTIVE', $2, $6
             WHERE NOT EXISTS (
                 SELECT 1 FROM bauth.privilege_atom_grant
                 WHERE user_id = $2 AND id_atom = $3 AND status = 'ACTIVE'
             )"
        ).bind(tenant_id).bind(entity_id)
         .bind(id_atom).bind(atom_position).bind(bitmask_value).bind(ctx_id)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error asignando átomo: {}", e), data: None,
        })?;

        Ok(serde_json::json!({
            "assigned": true,
            "uuid": uuid_str,
            "atom_path": atom_path,
            "atom_id": id_atom.to_string(),
        }))
    }
}

// ── Revoke Atom Grant (antes: Revoke Role) ───────────────────

pub struct UserRevokeRoleHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for UserRevokeRoleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let uuid_str = params.get("uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "uuid requerido".into(), data: None })?;
        let atom_path = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_id (atom_path) requerido".into(), data: None })?;
        let user_id = parse_uuid("uuid", uuid_str)?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        // Obtener entity_id (FK que usa privilege_atom_grant.user_id)
        let (entity_id,): (Uuid,) = sqlx::query_as(
            "SELECT entity_id FROM bauth.idn_user WHERE user_id = $1"
        ).bind(user_id).fetch_one(pg).await.map_err(|_| JsonRpcError {
            code: -32602, message: format!("usuario no encontrado: {}", user_id), data: None,
        })?;

        sqlx::query(
            "UPDATE bauth.privilege_atom_grant
             SET status = 'REVOKED', updated_at = now(), ctx_id = $3
             WHERE user_id = $1
               AND id_atom = (
                   SELECT id FROM bauth.idn_roles_template
                   WHERE path = $2 AND node_type = 'atom' AND is_active = TRUE
                   LIMIT 1
               )
               AND status = 'ACTIVE'"
        ).bind(entity_id).bind(atom_path).bind(ctx_id)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error revocando átomo: {}", e), data: None,
        })?;

        Ok(serde_json::json!({ "revoked": true, "uuid": uuid_str, "atom_path": atom_path }))
    }
}
