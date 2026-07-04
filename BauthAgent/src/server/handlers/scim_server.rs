// ============================================================
// bauth::server::handlers::scim_server — B48.T20-T25
// SCIM v2.0 Server: Users, Groups, ServiceProviderConfig,
// ResourceTypes, Schemas (RFC 7644)
// Métodos: bauth.scim.user.*, bauth.scim.group.*
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── SCIM Users (RFC 7644 §3.2) ────────────────────────

pub struct ScimUsersHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for ScimUsersHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let filter = params.get("filter").and_then(|v| v.as_str()).unwrap_or("");
        let start = params.get("startIndex").and_then(|v| v.as_i64()).unwrap_or(1);
        let count = params.get("count").and_then(|v| v.as_i64()).unwrap_or(100);
        let user_id = params.get("id").and_then(|v| v.as_str());
        let op = params.get("_scim_op").and_then(|v| v.as_str()).unwrap_or("list");

        match op {
            "get" if user_id.is_some() => {
                let row: Option<(String,String,String)> = sqlx::query_as(
                    "SELECT uuid::text, username, email FROM bauth.idn_user_template WHERE uuid::text=$1 AND is_active=true"
                ).bind(user_id.unwrap()).fetch_optional(pg).await.unwrap_or(None);
                match row {
                    Some((id, uname, email)) => Ok(json!({"id":id,"userName":uname,"emails":[{"value":email,"primary":true}],"meta":{"resourceType":"User","location":format!("/scim/v2/Users/{}",id)}})),
                    None => Err(JsonRpcError{code:404,message:"Usuario no encontrado".into(),data:None}),
                }
            }
            "create" => {
                let uname = params.get("userName").and_then(|v| v.as_str()).unwrap_or("");
                let email = params.get("emails").and_then(|v| v[0].get("value")).and_then(|v| v.as_str()).unwrap_or("");
                let uid = uuid::Uuid::now_v7().to_string();
                sqlx::query("INSERT INTO bauth.idn_user_template (uuid, username, email, is_active) VALUES ($1::uuid, $2, $3, true)")
                    .bind(&uid).bind(uname).bind(email).execute(pg).await.map_err(|e| err(&e.to_string()))?;
                Ok(json!({"id":uid,"userName":uname,"meta":{"resourceType":"User","location":format!("/scim/v2/Users/{}",uid)}}))
            }
            "delete" if user_id.is_some() => {
                sqlx::query("UPDATE bauth.idn_user_template SET is_active=false WHERE uuid::text=$1")
                    .bind(user_id.unwrap()).execute(pg).await.map_err(|e| err(&e.to_string()))?;
                Ok(json!({"status":"deleted"}))
            }
            _ => { // list
                let users: Vec<(String,String,String)> = sqlx::query_as(
                    "SELECT uuid::text, username, email FROM bauth.idn_user_template WHERE is_active=true ORDER BY username LIMIT $1 OFFSET $2"
                ).bind(count).bind((start-1)*count).fetch_all(pg).await.unwrap_or_default();
                let total: i64 = sqlx::query_scalar("SELECT count(*) FROM bauth.idn_user_template WHERE is_active=true").fetch_one(pg).await.unwrap_or(0);
                Ok(json!({"schemas":["urn:ietf:params:scim:api:messages:2.0:ListResponse"],"totalResults":total,"startIndex":start,"itemsPerPage":count,
                    "Resources":users.into_iter().map(|(i,u,e)| json!({"id":i,"userName":u,"emails":[{"value":e}]})).collect::<Vec<_>>()}))
            }
        }
    }
}
impl ScimUsersHandler { pub fn method_name() -> &'static str { "bauth.scim.user" } }

// ── SCIM Groups (RFC 7644 §3.3) ───────────────────────

pub struct ScimGroupsHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for ScimGroupsHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let groups: Vec<(String,String)> = sqlx::query_as(
            "SELECT r.role_code, r.role_name FROM bauth.idn_role_template r WHERE r.is_active=true ORDER BY r.role_code LIMIT 200"
        ).fetch_all(pg).await.unwrap_or_default();
        let total: i64 = sqlx::query_scalar("SELECT count(*) FROM bauth.idn_role_template WHERE is_active=true").fetch_one(pg).await.unwrap_or(0);
        Ok(json!({"schemas":["urn:ietf:params:scim:api:messages:2.0:ListResponse"],"totalResults":total,
            "Resources":groups.into_iter().map(|(c,n)| json!({"id":c,"displayName":n,"meta":{"resourceType":"Group"}})).collect::<Vec<_>>()}))
    }
}
impl ScimGroupsHandler { pub fn method_name() -> &'static str { "bauth.scim.group" } }

// ── SCIM ServiceProviderConfig (RFC 7644 §4) ──────────

pub struct ScimSpConfigHandler;
#[async_trait]
impl JsonRpcHandler for ScimSpConfigHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({"schemas":["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
            "patch":{"supported":true},"bulk":{"supported":false,"maxOperations":0,"maxPayloadSize":0},
            "filter":{"supported":true,"maxResults":200},"changePassword":{"supported":true},
            "sort":{"supported":false},"etag":{"supported":false},
            "authenticationSchemes":[{"type":"oauth2","name":"OAuth2","description":"bAuth JWT"},
            {"type":"http","name":"mTLS","description":"Mutual TLS X.509"}]}))
    }
}
impl ScimSpConfigHandler { pub fn method_name() -> &'static str { "bauth.scim.spconfig" } }

// ── SCIM ResourceTypes (RFC 7644 §4) ──────────────────

pub struct ScimResourceTypesHandler;
#[async_trait]
impl JsonRpcHandler for ScimResourceTypesHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({"schemas":["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
            "Resources":[
                {"id":"User","name":"User","endpoint":"/scim/v2/Users","schema":"urn:ietf:params:scim:schemas:core:2.0:User","schemaExtensions":[]},
                {"id":"Group","name":"Group","endpoint":"/scim/v2/Groups","schema":"urn:ietf:params:scim:schemas:core:2.0:Group","schemaExtensions":[]}
            ]}))
    }
}
impl ScimResourceTypesHandler { pub fn method_name() -> &'static str { "bauth.scim.resourcetypes" } }

// ── SCIM Schemas (RFC 7644 §7) ────────────────────────

pub struct ScimSchemasHandler;
#[async_trait]
impl JsonRpcHandler for ScimSchemasHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({
            "User": {"id":"urn:ietf:params:scim:schemas:core:2.0:User","name":"User","attributes":[
                {"name":"userName","type":"string","required":true,"mutability":"readWrite"},
                {"name":"name","type":"complex","required":false,"subAttributes":[{"name":"familyName","type":"string"},{"name":"givenName","type":"string"}]},
                {"name":"emails","type":"complex","multiValued":true,"subAttributes":[{"name":"value","type":"string"},{"name":"primary","type":"boolean"}]},
                {"name":"active","type":"boolean","mutability":"readWrite"}
            ]},
            "Group": {"id":"urn:ietf:params:scim:schemas:core:2.0:Group","name":"Group","attributes":[
                {"name":"displayName","type":"string","required":true,"mutability":"readWrite"},
                {"name":"members","type":"complex","multiValued":true,"subAttributes":[{"name":"value","type":"string"},{"name":"$ref","type":"reference"}]}
            ]}
        }))
    }
}
impl ScimSchemasHandler { pub fn method_name() -> &'static str { "bauth.scim.schemas" } }

// ── Factory ────────────────────────────────────────────

pub fn all_scim_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        ("bauth.scim.user".into(), Arc::new(ScimUsersHandler { pg: pg.clone() })),
        ("bauth.scim.group".into(), Arc::new(ScimGroupsHandler { pg: pg.clone() })),
        ("bauth.scim.spconfig".into(), Arc::new(ScimSpConfigHandler)),
        ("bauth.scim.resourcetypes".into(), Arc::new(ScimResourceTypesHandler)),
        ("bauth.scim.schemas".into(), Arc::new(ScimSchemasHandler)),
    ]
}
