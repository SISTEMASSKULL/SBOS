// ============================================================
// bauth::server::handlers::scim_server — B48.T20-T25
// SCIM v2.0 Server: Users, Groups, ServiceProviderConfig,
// ResourceTypes, Schemas (RFC 7644)
// Métodos: bauth.scim.user.*, bauth.scim.group.*
//
// Tablas canónicas DDL v2.12.0:
//   bauth.idn_user               — usuarios (reemplaza idn_user_template)
//   bauth.idn_identity_attribute — atributos de identidad (email)
//   bauth.idn_roles_rol_hierarchical — roles (reemplaza idn_role_template)
//
// Phantoms eliminados:
//   idn_user_template → idn_user + idn_identity_attribute
//   idn_role_template → idn_roles_rol_hierarchical
//
// DOC-SBOS-001 N3 · RFC 7644 · RFC 7643
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── SCIM Users (RFC 7644 §3.2) ────────────────────────

/// Handler: bauth.scim.user
/// CRUD de usuarios vía SCIM v2.0. La operación se indica en `_scim_op`.
pub struct ScimUsersHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for ScimUsersHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let start = params.get("startIndex").and_then(|v| v.as_i64()).unwrap_or(1);
        let count = params.get("count").and_then(|v| v.as_i64()).unwrap_or(100);
        let user_id = params.get("id").and_then(|v| v.as_str());
        let op = params.get("_scim_op").and_then(|v| v.as_str()).unwrap_or("list");

        match op {
            "get" if user_id.is_some() => {
                let uid = user_id.unwrap();
                let uid_parsed = uuid::Uuid::parse_str(uid).map_err(|_| err("id inválido"))?;

                let row: Option<(String, String)> = sqlx::query_as(
                    "SELECT u.user_id::text, u.username
                     FROM bauth.idn_user u
                     WHERE u.user_id = $1 AND u.status = 'ACTIVE'"
                )
                .bind(uid_parsed)
                .fetch_optional(pg)
                .await
                .unwrap_or(None);

                match row {
                    Some((id, uname)) => {
                        let email = buscar_email(pg, uid_parsed).await;
                        Ok(json!({
                            "id":       id,
                            "userName": uname,
                            "emails":   [{"value": email, "primary": true}],
                            "meta": {"resourceType": "User", "location": format!("/scim/v2/Users/{}", id)},
                        }))
                    }
                    None => Err(JsonRpcError { code: 404, message: "usuario no encontrado".into(), data: None }),
                }
            }
            "create" => {
                let uname = params.get("userName").and_then(|v| v.as_str()).unwrap_or("");
                let email = params.get("emails").and_then(|v| v[0].get("value")).and_then(|v| v.as_str()).unwrap_or("");
                let uid   = uuid::Uuid::now_v7();

                // SCIM crea un usuario minimal: entity_id es el mismo user_id (pos actor)
                sqlx::query(
                    "INSERT INTO bauth.idn_user
                        (user_id, tenant_id, entity_id, username, status, registration_method, ctx_id)
                     SELECT $1, t.tenant_id, $1, $2, 'PENDING_ACTIVATION', 'SCIM', 'system'
                     FROM bauth.idn_tenant t LIMIT 1"
                )
                .bind(uid)
                .bind(uname)
                .execute(pg)
                .await
                .map_err(|e| err(&e.to_string()))?;

                // Guardar email en idn_identity_attribute (entity_id = user_id por convención SCIM)
                if !email.is_empty() {
                    sqlx::query(
                        "INSERT INTO bauth.idn_identity_attribute
                            (entity_id, attr_key, attr_value, ctx_id)
                         VALUES ($1, 'email', to_jsonb($2::text), 'system')
                         ON CONFLICT (entity_id, attr_key) DO UPDATE SET attr_value = to_jsonb($2::text)"
                    )
                    .bind(uid)
                    .bind(email)
                    .execute(pg)
                    .await
                    .ok();
                }

                let uid_str = uid.to_string();
                Ok(json!({
                    "id":       uid_str,
                    "userName": uname,
                    "meta": {"resourceType": "User", "location": format!("/scim/v2/Users/{}", uid_str)},
                }))
            }
            "delete" if user_id.is_some() => {
                let uid = uuid::Uuid::parse_str(user_id.unwrap()).map_err(|_| err("id inválido"))?;
                sqlx::query(
                    "UPDATE bauth.idn_user SET status = 'ARCHIVED' WHERE user_id = $1"
                )
                .bind(uid)
                .execute(pg)
                .await
                .map_err(|e| err(&e.to_string()))?;
                Ok(json!({"status": "deleted"}))
            }
            _ => {
                // list
                let users: Vec<(String, String)> = sqlx::query_as(
                    "SELECT user_id::text, username
                     FROM bauth.idn_user
                     WHERE status = 'ACTIVE'
                     ORDER BY username LIMIT $1 OFFSET $2"
                )
                .bind(count)
                .bind((start - 1) * count)
                .fetch_all(pg)
                .await
                .unwrap_or_default();

                let total: i64 = sqlx::query_scalar(
                    "SELECT count(*) FROM bauth.idn_user WHERE status = 'ACTIVE'"
                )
                .fetch_one(pg)
                .await
                .unwrap_or(0);

                Ok(json!({
                    "schemas":       ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                    "totalResults":  total,
                    "startIndex":    start,
                    "itemsPerPage":  count,
                    "Resources": users.into_iter().map(|(id, uname)| {
                        json!({"id": id, "userName": uname})
                    }).collect::<Vec<_>>(),
                }))
            }
        }
    }
}

impl ScimUsersHandler { pub fn method_name() -> &'static str { "bauth.scim.user" } }

/// Obtiene el email de un usuario desde idn_identity_attribute.
async fn buscar_email(pg: &PgPool, user_id: uuid::Uuid) -> String {
    let row: Option<(String,)> = sqlx::query_as(
        "SELECT a.attr_value #>> '{}' as email
         FROM bauth.idn_user u
         JOIN bauth.idn_identity_entity e ON e.entity_id = u.entity_id
         JOIN bauth.idn_identity_attribute a ON a.entity_id = e.entity_id
         WHERE u.user_id = $1 AND a.attr_key = 'email'
         LIMIT 1"
    )
    .bind(user_id)
    .fetch_optional(pg)
    .await
    .unwrap_or(None);
    row.map(|(e,)| e).unwrap_or_default()
}

// ── SCIM Groups (RFC 7644 §3.3) ───────────────────────

/// Handler: bauth.scim.group
/// Lista roles como grupos SCIM desde idn_roles_rol_hierarchical.
pub struct ScimGroupsHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for ScimGroupsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let groups: Vec<(uuid::Uuid, String, serde_json::Value)> = sqlx::query_as(
            "SELECT id, code, name FROM bauth.idn_roles_rol_hierarchical
             WHERE status = 'ACTIVE' ORDER BY code LIMIT 200"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        let total: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_roles_rol_hierarchical WHERE status = 'ACTIVE'"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        Ok(json!({
            "schemas":      ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
            "totalResults": total,
            "Resources": groups.into_iter().map(|(id, code, name)| {
                let display = name.get("es").and_then(|v| v.as_str()).unwrap_or(&code).to_string();
                json!({"id": id.to_string(), "displayName": display, "meta": {"resourceType": "Group"}})
            }).collect::<Vec<_>>(),
        }))
    }
}

impl ScimGroupsHandler { pub fn method_name() -> &'static str { "bauth.scim.group" } }

// ── SCIM ServiceProviderConfig (RFC 7644 §4) ──────────

pub struct ScimSpConfigHandler;

#[async_trait]
impl JsonRpcHandler for ScimSpConfigHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({
            "schemas": ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
            "patch":   {"supported": true},
            "bulk":    {"supported": false, "maxOperations": 0, "maxPayloadSize": 0},
            "filter":  {"supported": true, "maxResults": 200},
            "changePassword": {"supported": true},
            "sort":    {"supported": false},
            "etag":    {"supported": false},
            "authenticationSchemes": [
                {"type": "oauth2",  "name": "OAuth2", "description": "bAuth JWT EdDSA"},
                {"type": "httpBasic", "name": "mTLS", "description": "Mutual TLS X.509"}
            ],
        }))
    }
}

impl ScimSpConfigHandler { pub fn method_name() -> &'static str { "bauth.scim.spconfig" } }

// ── SCIM ResourceTypes ────────────────────────────────

pub struct ScimResourceTypesHandler;

#[async_trait]
impl JsonRpcHandler for ScimResourceTypesHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({"schemas": ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
            "Resources": [
                {"id":"User","name":"User","endpoint":"/scim/v2/Users","schema":"urn:ietf:params:scim:schemas:core:2.0:User","schemaExtensions":[]},
                {"id":"Group","name":"Group","endpoint":"/scim/v2/Groups","schema":"urn:ietf:params:scim:schemas:core:2.0:Group","schemaExtensions":[]},
            ],
        }))
    }
}

impl ScimResourceTypesHandler { pub fn method_name() -> &'static str { "bauth.scim.resourcetypes" } }

// ── SCIM Schemas ──────────────────────────────────────

pub struct ScimSchemasHandler;

#[async_trait]
impl JsonRpcHandler for ScimSchemasHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({
            "User": {
                "id":"urn:ietf:params:scim:schemas:core:2.0:User","name":"User",
                "attributes":[
                    {"name":"userName","type":"string","required":true,"mutability":"readWrite"},
                    {"name":"emails","type":"complex","multiValued":true,"subAttributes":[
                        {"name":"value","type":"string"},{"name":"primary","type":"boolean"}
                    ]},
                    {"name":"active","type":"boolean","mutability":"readWrite"},
                ],
            },
            "Group": {
                "id":"urn:ietf:params:scim:schemas:core:2.0:Group","name":"Group",
                "attributes":[
                    {"name":"displayName","type":"string","required":true,"mutability":"readWrite"},
                    {"name":"members","type":"complex","multiValued":true,"subAttributes":[
                        {"name":"value","type":"string"},{"name":"$ref","type":"reference"}
                    ]},
                ],
            },
        }))
    }
}

impl ScimSchemasHandler { pub fn method_name() -> &'static str { "bauth.scim.schemas" } }

// ── Factory ────────────────────────────────────────────

pub fn all_scim_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        ("bauth.scim.user".into(),         Arc::new(ScimUsersHandler     { pg: pg.clone() })),
        ("bauth.scim.group".into(),        Arc::new(ScimGroupsHandler    { pg: pg.clone() })),
        ("bauth.scim.spconfig".into(),     Arc::new(ScimSpConfigHandler)),
        ("bauth.scim.resourcetypes".into(),Arc::new(ScimResourceTypesHandler)),
        ("bauth.scim.schemas".into(),      Arc::new(ScimSchemasHandler)),
    ]
}
