// ============================================================
// bauth::server::handlers::role_lifecycle — B10.T76-T89
// RoleLifecycleManager: 7 estados + operaciones avanzadas
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

const STATES: &[&str] = &["DEFINIDO","DESARROLLADO","REVISADO","AUTORIZADO","PUBLICADO","DEPRECADO","RETIRADO"];

// ── T76: RoleLifecycleManager ──────────────────────────

pub struct RoleLifecycleHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleLifecycleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role_code").and_then(|v| v.as_str()).ok_or_else(|| err("role_code requerido"))?;
        let action = params.get("action").and_then(|v| v.as_str()).ok_or_else(|| err("action requerido (definir/desarrollar/revisar/autorizar/publicar/deprecar/retirar)"))?;
        let actor = params.get("actor").and_then(|v| v.as_str()).unwrap_or("system");
        let pg = &self.pg;

        let valid_actions = ["definir","desarrollar","revisar","autorizar","publicar","deprecar","retirar"];
        if !valid_actions.contains(&action) {
            return Err(err(&format!("Acción inválida. Válidas: {:?}", valid_actions)));
        }

        let current: (String,) = sqlx::query_as("SELECT coalesce(config->'role'->>'lifecycle_state','DEFINIDO') FROM bauth.idn_role_template WHERE role_code=$1")
            .bind(role).fetch_optional(pg).await.map_err(|e| err(&e.to_string()))?.ok_or_else(|| err("Rol no encontrado"))?;

        let next = match (current.0.as_str(), action) {
            ("DEFINIDO","desarrollar") => "DESARROLLADO",
            ("DESARROLLADO","revisar") => "REVISADO",
            ("REVISADO","autorizar") => "AUTORIZADO",
            ("AUTORIZADO","publicar") => "PUBLICADO",
            (s,"deprecar") if s!="RETIRADO" => "DEPRECADO",
            ("DEPRECADO","retirar") => "RETIRADO",
            (s,a) => return Err(err(&format!("Transición inválida: {} → {} no permitida", s, a))),
        };

        sqlx::query("UPDATE bauth.idn_role_template SET config=jsonb_set(config,'{role,lifecycle_state}',$1::jsonb), updated_at=now() WHERE role_code=$2")
            .bind(&json!(next)).bind(role).execute(pg).await.map_err(|e| err(&e.to_string()))?;
        sqlx::query("INSERT INTO bauth.idn_role_template_history (role_code, version, changed_by, change_type, new_state, changed_at) VALUES ($1,(SELECT coalesce(max(version),0)+1 FROM bauth.idn_role_template_history WHERE role_code=$1),$2,$3,$4,now())")
            .bind(role).bind(actor).bind(action).bind(next).execute(pg).await.map_err(|e| err(&e.to_string()))?;

        tracing::info!(%role, %action, %next, "role.lifecycle — transición exitosa");
        Ok(json!({"role_code":role,"previous_state":current.0,"new_state":next,"action":action,"timestamp":chrono::Utc::now().to_rfc3339()}))
    }
}
impl RoleLifecycleHandler { pub fn method() -> &'static str { "bauth.role.lifecycle" } }

// ── T77: RoleImpactAnalysis ─────────────────────────────

pub struct RoleImpactHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleImpactHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role_code").and_then(|v| v.as_str()).ok_or_else(|| err("role_code requerido"))?;
        let pg = &self.pg;
        let affected: i64 = sqlx::query_scalar("SELECT count(*) FROM bauth.idn_user_role WHERE role_code=$1").bind(role).fetch_one(pg).await.unwrap_or(0);
        let inheritors: Vec<String> = sqlx::query_as("SELECT descendant_code FROM bauth.idn_role_closure WHERE ancestor_code=$1 AND depth>0").bind(role).fetch_all(pg).await.unwrap_or_default().into_iter().map(|(d,):(String,)| d).collect();
        Ok(json!({"role_code":role,"affected_users":affected,"inheriting_roles":inheritors,"critical_operations_blocked":0}))
    }
}
impl RoleImpactHandler { pub fn method() -> &'static str { "bauth.role.impact" } }

// ── T79: RoleBulkAssign ─────────────────────────────────

pub struct RoleBulkAssignHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleBulkAssignHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role_code").and_then(|v| v.as_str()).ok_or_else(|| err("role_code requerido"))?;
        let users: Vec<String> = params.get("user_uuids").and_then(|v| v.as_array()).ok_or_else(|| err("user_uuids requerido (array)"))?.iter().filter_map(|v| v.as_str().map(String::from)).collect();
        if users.is_empty() { return Err(err("user_uuids no puede estar vacío")); }
        let pg = &self.pg;
        let mut assigned = 0i64;
        for uid in &users {
            if let Err(e) = sqlx::query("INSERT INTO bauth.idn_user_role (user_uuid,role_code,assigned_at) VALUES ($1::uuid,$2,now()) ON CONFLICT DO NOTHING").bind(uid).bind(role).execute(pg).await {
                tracing::warn!(%uid, %role, error=%e, "bulk_assign — falló para usuario");
            } else { assigned += 1; }
        }
        Ok(json!({"role_code":role,"total":users.len(),"assigned":assigned,"failed":users.len() as i64 - assigned}))
    }
}
impl RoleBulkAssignHandler { pub fn method() -> &'static str { "bauth.role.bulk_assign" } }

// ── T80: RoleTemporalAssignment ─────────────────────────

pub struct RoleTemporalHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleTemporalHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role_code").and_then(|v| v.as_str()).ok_or_else(|| err("role_code requerido"))?;
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let valid_until = params.get("valid_until").and_then(|v| v.as_str()).unwrap_or("");
        let valid_from = params.get("valid_from").and_then(|v| v.as_str());
        let pg = &self.pg;
        sqlx::query("INSERT INTO bauth.idn_user_role (user_uuid,role_code,assigned_at,expires_at,valid_from) VALUES ($1::uuid,$2,$3::timestamptz,$4::timestamptz,$5::timestamptz) ON CONFLICT (user_uuid,role_code) DO UPDATE SET expires_at=$4::timestamptz,valid_from=$5::timestamptz")
            .bind(user).bind(role).bind(chrono::Utc::now()).bind(&valid_until).bind(valid_from).execute(pg).await.map_err(|e| err(&e.to_string()))?;
        Ok(json!({"role_code":role,"user_uuid":user,"valid_until":valid_until,"valid_from":valid_from,"status":"TEMPORAL"}))
    }
}
impl RoleTemporalHandler { pub fn method() -> &'static str { "bauth.role.temporal_assign" } }

// ── T86: TemplateSearchEngine ───────────────────────────

pub struct RoleSearchHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleSearchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let query = params.get("q").and_then(|v| v.as_str()).unwrap_or("");
        let tier = params.get("tier").and_then(|v| v.as_str());
        let domain = params.get("domain").and_then(|v| v.as_str());
        let pg = &self.pg;
        let mut sql = "SELECT role_code, role_name, tier, config->'role'->>'lifecycle_state' as state FROM bauth.idn_role_template WHERE is_active=true".to_string();
        if !query.is_empty() { sql.push_str(&format!(" AND (role_code ILIKE '%{}%' OR role_name ILIKE '%{}%')", query, query)); }
        if let Some(t) = tier { sql.push_str(&format!(" AND tier='{}'", t)); }
        sql.push_str(" ORDER BY tier, role_code LIMIT 200");
        let results: Vec<(String,String,String,String)> = sqlx::query_as(&sql).fetch_all(pg).await.unwrap_or_default();
        let count = results.len();
        let mapped: Vec<Value> = results.into_iter().map(|(c,n,t,s)| json!({"code":c,"name":n,"tier":t,"state":s})).collect();
        Ok(json!({"query":query,"results":mapped,"count":count}))
    }
}
impl RoleSearchHandler { pub fn method() -> &'static str { "bauth.role.search" } }

// ── T83: TemplateRollback ───────────────────────────────

pub struct RoleRollbackHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleRollbackHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role = params.get("role_code").and_then(|v| v.as_str()).ok_or_else(|| err("role_code requerido"))?;
        let version = params.get("version").and_then(|v| v.as_i64()).unwrap_or(0);
        let pg = &self.pg;
        let prev: Option<(serde_json::Value,)> = sqlx::query_as("SELECT config_snapshot FROM bauth.idn_role_template_history WHERE role_code=$1 AND version=$2")
            .bind(role).bind(version).fetch_optional(pg).await.unwrap_or(None);
        match prev {
            Some((config,)) => {
                sqlx::query("UPDATE bauth.idn_role_template SET config=$1::jsonb, updated_at=now() WHERE role_code=$2")
                    .bind(&config).bind(role).execute(pg).await.map_err(|e| err(&e.to_string()))?;
                Ok(json!({"role_code":role,"restored_to_version":version,"status":"ROLLED_BACK"}))
            }
            None => Err(err(&format!("Versión {} no encontrada para {}", version, role))),
        }
    }
}
impl RoleRollbackHandler { pub fn method() -> &'static str { "bauth.role.rollback" } }

// ── T87: TemplateBatchOps ───────────────────────────────

pub struct RoleBatchHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RoleBatchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let action = params.get("batch_action").and_then(|v| v.as_str()).ok_or_else(|| err("batch_action requerido"))?;
        let filter_tier = params.get("filter_tier").and_then(|v| v.as_str()).unwrap_or("");
        let reason = params.get("reason").and_then(|v| v.as_str()).unwrap_or("batch operation");
        let pg = &self.pg;
        let mut sql = format!("UPDATE bauth.idn_role_template SET updated_at=now()");
        match action {
            "enable" => sql.push_str(", is_active=true"),
            "disable" => sql.push_str(", is_active=false"),
            "deprecate" => sql.push_str(", config=jsonb_set(config,'{role,lifecycle_state}','\"DEPRECADO\"')"),
            _ => return Err(err("batch_action inválido: enable/disable/deprecate")),
        }
        if !filter_tier.is_empty() { sql.push_str(&format!(" WHERE tier='{}'", filter_tier)); } else { sql.push_str(" WHERE is_active=true"); }
        let result = sqlx::query(&sql).execute(pg).await.map_err(|e| err(&e.to_string()))?;
        sqlx::query("INSERT INTO bauth.aud_event (event_type,resource_type,details,ctx_id) VALUES ('ROLE_BATCH_OP','idn_role_template',$1::jsonb,'system')")
            .bind(&json!({"action":action,"tier":filter_tier,"reason":reason,"affected":result.rows_affected()})).execute(pg).await.ok();
        Ok(json!({"batch_action":action,"tier_filter":filter_tier,"affected_rows":result.rows_affected()}))
    }
}
impl RoleBatchHandler { pub fn method() -> &'static str { "bauth.role.batch" } }

// ── Factory ────────────────────────────────────────────

pub fn all_role_lifecycle_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (RoleLifecycleHandler::method().into(), Arc::new(RoleLifecycleHandler { pg: pg.clone() })),
        (RoleImpactHandler::method().into(), Arc::new(RoleImpactHandler { pg: pg.clone() })),
        (RoleBulkAssignHandler::method().into(), Arc::new(RoleBulkAssignHandler { pg: pg.clone() })),
        (RoleTemporalHandler::method().into(), Arc::new(RoleTemporalHandler { pg: pg.clone() })),
        (RoleSearchHandler::method().into(), Arc::new(RoleSearchHandler { pg: pg.clone() })),
        (RoleRollbackHandler::method().into(), Arc::new(RoleRollbackHandler { pg: pg.clone() })),
        (RoleBatchHandler::method().into(), Arc::new(RoleBatchHandler { pg: pg.clone() })),
    ]
}
