// ============================================================
// bauth::server::handlers::role_lifecycle — B10.T76-T89
// RoleLifecycleManager: 7 estados + operaciones avanzadas
//
// Tabla canónica DDL v2.12.0:
//   bauth.idn_roles_rol_hierarchical — roles jerárquicos
//     Estado de ciclo de vida: almacenado en metadata_b1 JSONB
//     bajo la clave 'lifecycle_state'. El campo status (ACTIVE/INACTIVE/DEPRECATED)
//     refleja el estado operativo; lifecycle_state es la vista de proceso.
//   bauth.idn_roles_rol_closure — cierre transitivo (reemplaza idn_role_closure)
//
// Phantoms eliminados:
//   idn_role_template → idn_roles_rol_hierarchical
//   idn_role_template_history → no existe equivalente en DDL v2.12.0
//   aud_event → ses_caep_event_log (no usado en este módulo)
//   idn_user_role → no existe en DDL v2.12.0
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

/// Estados del ciclo de vida de rol (almacenados en metadata_b1->>'lifecycle_state').
const STATES: &[&str] = &["DEFINIDO","DESARROLLADO","REVISADO","AUTORIZADO","PUBLICADO","DEPRECADO","RETIRADO"];

// ── T76: RoleLifecycleManager ──────────────────────────

/// Handler: bauth.role.lifecycle
/// Gestiona las 7 transiciones de estado de ciclo de vida de un rol.
/// El estado se almacena en metadata_b1->'lifecycle_state'.
pub struct RoleLifecycleHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleLifecycleHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id_str = params.get("role_id").or_else(|| params.get("role_code"))
            .and_then(|v| v.as_str()).ok_or_else(|| err("role_id requerido"))?;
        let role_id = uuid::Uuid::parse_str(role_id_str).ok();

        let action = params.get("action").and_then(|v| v.as_str())
            .ok_or_else(|| err("action requerido (definir/desarrollar/revisar/autorizar/publicar/deprecar/retirar)"))?;

        let valid_actions = ["definir","desarrollar","revisar","autorizar","publicar","deprecar","retirar"];
        if !valid_actions.contains(&action) {
            return Err(err(&format!("acción inválida. Válidas: {:?}", valid_actions)));
        }

        // Leer estado actual desde metadata_b1
        let row: Option<(Option<serde_json::Value>,)> = sqlx::query_as(
            "SELECT metadata_b1 FROM bauth.idn_roles_rol_hierarchical
             WHERE ($1::uuid IS NULL AND code = $2) OR id = $1"
        )
        .bind(role_id)
        .bind(role_id_str)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let meta = row.ok_or_else(|| err("rol no encontrado"))?.0.unwrap_or(json!({}));
        let current = meta.get("lifecycle_state").and_then(|v| v.as_str()).unwrap_or("DEFINIDO");

        let next = match (current, action) {
            ("DEFINIDO","desarrollar")     => "DESARROLLADO",
            ("DESARROLLADO","revisar")     => "REVISADO",
            ("REVISADO","autorizar")       => "AUTORIZADO",
            ("AUTORIZADO","publicar")      => "PUBLICADO",
            (s,"deprecar") if s != "RETIRADO" => "DEPRECADO",
            ("DEPRECADO","retirar")        => "RETIRADO",
            (s, a) => return Err(err(&format!("transición inválida: {} → {} no permitida", s, a))),
        };

        // Actualizar metadata_b1 con el nuevo lifecycle_state
        sqlx::query(
            "UPDATE bauth.idn_roles_rol_hierarchical
             SET metadata_b1 = jsonb_set(COALESCE(metadata_b1, '{}'), '{lifecycle_state}', $1::jsonb),
                 version = version + 1
             WHERE ($2::uuid IS NULL AND code = $3) OR id = $2"
        )
        .bind(&json!(next))
        .bind(role_id)
        .bind(role_id_str)
        .execute(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%role_id_str, %action, %next, "role.lifecycle — transición exitosa");
        Ok(json!({
            "role_id":        role_id_str,
            "previous_state": current,
            "new_state":      next,
            "action":         action,
            "timestamp":      chrono::Utc::now().to_rfc3339()
        }))
    }
}

impl RoleLifecycleHandler { pub fn method() -> &'static str { "bauth.role.lifecycle" } }

// ── T77: RoleImpactAnalysis ─────────────────────────────

/// Handler: bauth.role.impact
/// Analiza el impacto de modificar un rol: herederos en el cierre transitivo.
pub struct RoleImpactHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleImpactHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id_str = params.get("role_id").or_else(|| params.get("role_code"))
            .and_then(|v| v.as_str()).ok_or_else(|| err("role_id requerido"))?;
        let role_id = uuid::Uuid::parse_str(role_id_str)
            .map_err(|_| err("role_id inválido"))?;

        // Herederos desde idn_roles_rol_closure
        let inheritors: Vec<(uuid::Uuid, String)> = sqlx::query_as(
            "SELECT r.id, r.code
             FROM bauth.idn_roles_rol_closure c
             JOIN bauth.idn_roles_rol_hierarchical r ON r.id = c.descendant_id
             WHERE c.ancestor_id = $1 AND c.depth > 0
             ORDER BY r.code"
        )
        .bind(role_id)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        let herederos: Vec<Value> = inheritors.into_iter()
            .map(|(id, code)| json!({"id": id.to_string(), "code": code}))
            .collect();

        Ok(json!({
            "role_id":              role_id_str,
            "inheriting_roles":     herederos,
            "critical_ops_blocked": 0
        }))
    }
}

impl RoleImpactHandler { pub fn method() -> &'static str { "bauth.role.impact" } }

// ── T79: RoleBulkAssign (stub) ──────────────────────────

/// Handler: bauth.role.bulk_assign
/// Sin tabla idn_user_role en DDL v2.12.0 — asignación vía privilege_atom_grant.
/// Retorna el número de grants creados.
pub struct RoleBulkAssignHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleBulkAssignHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("role_id requerido"))?;
        let users: Vec<String> = params.get("user_uuids")
            .and_then(|v| v.as_array())
            .ok_or_else(|| err("user_uuids requerido (array)"))?
            .iter().filter_map(|v| v.as_str().map(String::from)).collect();

        if users.is_empty() { return Err(err("user_uuids no puede estar vacío")); }

        let role_id = uuid::Uuid::parse_str(role_id_str)
            .map_err(|_| err("role_id inválido"))?;

        // Obtener átomos del rol para crear grants
        let atom_paths: Vec<(String,)> = sqlx::query_as(
            "SELECT rt.path
             FROM bauth.idn_roles_template rt
             WHERE rt.node_type = 'atom'
               AND rt.parent_id IN (
                   SELECT id FROM bauth.idn_roles_rol_hierarchical WHERE id = $1
               )
               AND rt.is_active = TRUE"
        )
        .bind(role_id)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        let mut assigned = 0i64;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        for uid_str in &users {
            let uid = match uuid::Uuid::parse_str(uid_str) {
                Ok(u) => u,
                Err(_) => continue,
            };
            for (path,) in &atom_paths {
                if sqlx::query(
                    "INSERT INTO bauth.privilege_atom_grant
                        (user_id, atom_path, general, effect, access, ctx_id)
                     VALUES ($1, $2, TRUE, TRUE, TRUE, $3)
                     ON CONFLICT (user_id, atom_path) DO NOTHING"
                )
                .bind(uid)
                .bind(path)
                .bind(ctx_id)
                .execute(&self.pg)
                .await
                .is_ok() { assigned += 1; }
            }
        }

        Ok(json!({"role_id": role_id_str, "total_users": users.len(), "grants_created": assigned}))
    }
}

impl RoleBulkAssignHandler { pub fn method() -> &'static str { "bauth.role.bulk_assign" } }

// ── T80: RoleTemporalAssignment (stub) ──────────────────

/// Handler: bauth.role.temporal_assign
/// Asignación temporal de átomos vía privilege_atom_grant.expires_at.
pub struct RoleTemporalHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleTemporalHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("role_id requerido"))?;
        let user_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_uuid requerido"))?;
        let valid_until = params.get("valid_until").and_then(|v| v.as_str()).unwrap_or("");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        let role_id = uuid::Uuid::parse_str(role_id_str).map_err(|_| err("role_id inválido"))?;
        let user_id = uuid::Uuid::parse_str(user_str).map_err(|_| err("user_uuid inválido"))?;

        let atom_paths: Vec<(String,)> = sqlx::query_as(
            "SELECT path FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND is_active = TRUE
               AND parent_id IN (
                   SELECT id FROM bauth.idn_roles_rol_hierarchical WHERE id = $1
               )"
        )
        .bind(role_id)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        let mut created = 0i64;
        for (path,) in &atom_paths {
            if sqlx::query(
                "INSERT INTO bauth.privilege_atom_grant
                    (user_id, atom_path, general, effect, access, expires_at, ctx_id)
                 VALUES ($1, $2, TRUE, TRUE, TRUE, $3::timestamptz, $4)
                 ON CONFLICT (user_id, atom_path) DO UPDATE SET expires_at = $3::timestamptz"
            )
            .bind(user_id)
            .bind(path)
            .bind(valid_until)
            .bind(ctx_id)
            .execute(&self.pg)
            .await
            .is_ok() { created += 1; }
        }

        Ok(json!({"role_id": role_id_str, "user_uuid": user_str, "valid_until": valid_until, "grants_created": created, "status": "TEMPORAL"}))
    }
}

impl RoleTemporalHandler { pub fn method() -> &'static str { "bauth.role.temporal_assign" } }

// ── T86: TemplateSearchEngine ───────────────────────────

/// Handler: bauth.role.search
/// Busca roles en idn_roles_rol_hierarchical.
pub struct RoleSearchHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleSearchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let query = params.get("q").and_then(|v| v.as_str()).unwrap_or("");
        let tier   = params.get("tier").and_then(|v| v.as_str());
        let status = params.get("status").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct RolRow {
            id:     uuid::Uuid,
            code:   String,
            name:   serde_json::Value,
            tier:   String,
            status: String,
        }

        let rows: Vec<RolRow> = sqlx::query_as(
            "SELECT id, code, name, tier::text, status::text
             FROM bauth.idn_roles_rol_hierarchical
             WHERE ($1::text = '' OR code ILIKE '%' || $1 || '%' OR name->>'es' ILIKE '%' || $1 || '%')
               AND ($2::text IS NULL OR tier::text = $2)
               AND ($3::text IS NULL OR status::text = $3)
             ORDER BY tier, code LIMIT 200"
        )
        .bind(query)
        .bind(tier)
        .bind(status)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        let count = rows.len();
        let mapped: Vec<Value> = rows.into_iter().map(|r| json!({
            "id":     r.id.to_string(),
            "code":   r.code,
            "name":   r.name,
            "tier":   r.tier,
            "status": r.status,
        })).collect();

        Ok(json!({"query": query, "results": mapped, "count": count}))
    }
}

impl RoleSearchHandler { pub fn method() -> &'static str { "bauth.role.search" } }

// ── T83: TemplateRollback ───────────────────────────────

/// Handler: bauth.role.rollback
/// Sin tabla idn_role_template_history en DDL v2.12.0 — siempre retorna no disponible.
pub struct RoleRollbackHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleRollbackHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id = params.get("role_id").and_then(|v| v.as_str()).unwrap_or("?");
        Err(JsonRpcError {
            code: -32000,
            message: format!("historial de versiones no disponible para rol '{}' — no existe en DDL v2.12.0", role_id),
            data: None,
        })
    }
}

impl RoleRollbackHandler { pub fn method() -> &'static str { "bauth.role.rollback" } }

// ── T87: TemplateBatchOps ───────────────────────────────

/// Handler: bauth.role.batch
/// Operaciones en lote sobre idn_roles_rol_hierarchical.
pub struct RoleBatchHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RoleBatchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let action      = params.get("batch_action").and_then(|v| v.as_str())
            .ok_or_else(|| err("batch_action requerido"))?;
        let filter_tier = params.get("filter_tier").and_then(|v| v.as_str()).unwrap_or("");
        let ctx_id      = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Construir SET parametrizado según la acción
        let (set_clause, target_status) = match action {
            "enable"     => ("status = 'ACTIVE'::rol_status_enum", "ACTIVE"),
            "disable"    => ("status = 'INACTIVE'::rol_status_enum", "INACTIVE"),
            "deprecate"  => ("status = 'DEPRECATED'::rol_status_enum", "DEPRECATED"),
            _ => return Err(err("batch_action inválido: enable/disable/deprecate")),
        };

        let sql = if filter_tier.is_empty() {
            format!(
                "UPDATE bauth.idn_roles_rol_hierarchical SET {set_clause}, ctx_id = '{ctx_id}', version = version + 1 \
                 WHERE status != '{target_status}'::rol_status_enum"
            )
        } else {
            format!(
                "UPDATE bauth.idn_roles_rol_hierarchical SET {set_clause}, ctx_id = '{ctx_id}', version = version + 1 \
                 WHERE tier::text = '{filter_tier}' AND status != '{target_status}'::rol_status_enum"
            )
        };

        let result = sqlx::query(&sql)
            .execute(&self.pg)
            .await
            .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%action, %filter_tier, rows = result.rows_affected(), "role.batch — OK");
        Ok(json!({"batch_action": action, "tier_filter": filter_tier, "affected_rows": result.rows_affected()}))
    }
}

impl RoleBatchHandler { pub fn method() -> &'static str { "bauth.role.batch" } }

// ── Factory ────────────────────────────────────────────

/// Registra todos los handlers de role_lifecycle en el dispatcher JSON-RPC.
pub fn all_role_lifecycle_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (RoleLifecycleHandler::method().into(),  Arc::new(RoleLifecycleHandler  { pg: pg.clone() })),
        (RoleImpactHandler::method().into(),     Arc::new(RoleImpactHandler     { pg: pg.clone() })),
        (RoleBulkAssignHandler::method().into(), Arc::new(RoleBulkAssignHandler { pg: pg.clone() })),
        (RoleTemporalHandler::method().into(),   Arc::new(RoleTemporalHandler   { pg: pg.clone() })),
        (RoleSearchHandler::method().into(),     Arc::new(RoleSearchHandler     { pg: pg.clone() })),
        (RoleRollbackHandler::method().into(),   Arc::new(RoleRollbackHandler   { pg: pg.clone() })),
        (RoleBatchHandler::method().into(),      Arc::new(RoleBatchHandler      { pg: pg.clone() })),
    ]
}
