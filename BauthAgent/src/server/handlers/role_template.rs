// ============================================================
// bauth::server::handlers::role_template — B10 RolTemplate CRUD
//
// Handlers:
//   bauth.role.template.list     — listar con filtros tier/status
//   bauth.role.template.get      — obtener por id (incluye business_justification)
//   bauth.role.template.create   — crear nueva plantilla de rol
//   bauth.role.template.update   — actualizar campos de una plantilla
//   bauth.role.template.delete   — desactivar plantilla (status=INACTIVE)
//
// Tabla canónica DDL v2.12.0:
//   bauth.idn_roles_rol_hierarchical — árbol jerárquico de roles
//     Columnas relevantes: id, tenant_id, parent_id, tier (rol_tier_enum),
//     code, name JSONB, depth, is_inheritable, status (rol_status_enum),
//     version, ial_min, template_id, business_justification JSONB.
//
// D05 eliminado: idn_role_template no existe en DDL v2.12.0.
//   Las plantillas de rol se almacenan como nodos en idn_roles_rol_hierarchical
//   con business_justification JSONB (14 bloques B01-B14 de la plantilla canónica).
//
// DOC-SBOS-001 N3 · NIST RBAC Nivel 3 · BAUTH-CATALOGO-ROLES-EMPRESARIALES v2.0
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

/// Tiers válidos según rol_tier_enum (DDL v2.12.0).
const TIER_VALIDOS: &[&str] = &["SU", "SYS", "BIZ_N1", "BIZ_N2", "BIZ_N3", "BIZ_N4", "BIZ_N5",
                                  "EXT_N0", "M2M", "VISITANTE"];
/// Estados válidos según rol_status_enum (DDL v2.12.0).
const STATUS_VALIDOS: &[&str] = &["ACTIVE", "INACTIVE", "DEPRECATED"];

/// Obtiene el PgPool desde un Option<PgPool> o retorna error.
fn pg_req(opt: &Option<PgPool>) -> Result<&PgPool, JsonRpcError> {
    opt.as_ref().ok_or_else(|| err("base de datos no disponible"))
}

// ── List ──────────────────────────────────────────────

/// Handler: bauth.role.template.list
/// Lista roles desde idn_roles_rol_hierarchical con filtros opcionales.
pub struct RoleTemplateListHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for RoleTemplateListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("tenant_uuid inválido")))
            .transpose()?;
        let tier   = params.get("tier").and_then(|v| v.as_str());
        let status = params.get("status").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct RolRow {
            id:             uuid::Uuid,
            tenant_id:      Option<uuid::Uuid>,
            parent_id:      Option<uuid::Uuid>,
            tier:           String,
            code:           String,
            name:           serde_json::Value,
            depth:          i32,
            is_inheritable: bool,
            status:         String,
            version:        i32,
            ial_min:        Option<String>,
        }

        let rows: Vec<RolRow> = sqlx::query_as(
            "SELECT id, tenant_id, parent_id, tier::text, code, name, depth,
                    is_inheritable, status::text, version, ial_min
             FROM bauth.idn_roles_rol_hierarchical
             WHERE ($1::uuid IS NULL OR tenant_id = $1)
               AND ($2::text IS NULL OR tier::text = $2)
               AND ($3::text IS NULL OR status::text = $3)
             ORDER BY depth, code
             LIMIT 500"
        )
        .bind(tenant_id)
        .bind(tier)
        .bind(status)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let total = rows.len();
        let items: Vec<Value> = rows.into_iter().map(|r| json!({
            "id":             r.id.to_string(),
            "tenant_id":      r.tenant_id.map(|t| t.to_string()),
            "parent_id":      r.parent_id.map(|p| p.to_string()),
            "tier":           r.tier,
            "code":           r.code,
            "name":           r.name,
            "depth":          r.depth,
            "is_inheritable": r.is_inheritable,
            "status":         r.status,
            "version":        r.version,
            "ial_min":        r.ial_min,
        })).collect();

        Ok(json!({"roles": items, "total": total}))
    }
}

// ── Get ───────────────────────────────────────────────

/// Handler: bauth.role.template.get
/// Obtiene un rol por id con business_justification (14 bloques B01-B14).
pub struct RoleTemplateGetHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for RoleTemplateGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("role_id requerido"))?;
        let role_id = uuid::Uuid::parse_str(id_str).map_err(|_| err("role_id inválido"))?;

        type RolFull = (uuid::Uuid, Option<uuid::Uuid>, Option<uuid::Uuid>, String, String,
                        serde_json::Value, i32, bool, String, i32, Option<String>,
                        Option<serde_json::Value>, Option<uuid::Uuid>);

        let row: Option<RolFull> = sqlx::query_as(
            "SELECT id, tenant_id, parent_id, tier::text, code, name, depth,
                    is_inheritable, status::text, version, ial_min,
                    business_justification, template_id
             FROM bauth.idn_roles_rol_hierarchical WHERE id = $1"
        )
        .bind(role_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        match row {
            None => Err(JsonRpcError { code: 404, message: "rol no encontrado".into(), data: None }),
            Some((id, tid, pid, tier, code, name, depth, inh, status, ver, ial, bj, tmpl)) =>
                Ok(json!({
                    "id":                    id.to_string(),
                    "tenant_id":             tid.map(|t| t.to_string()),
                    "parent_id":             pid.map(|p| p.to_string()),
                    "tier":                  tier,
                    "code":                  code,
                    "name":                  name,
                    "depth":                 depth,
                    "is_inheritable":        inh,
                    "status":                status,
                    "version":               ver,
                    "ial_min":               ial,
                    "business_justification": bj,
                    "template_id":           tmpl.map(|t| t.to_string()),
                })),
        }
    }
}

// ── Create ────────────────────────────────────────────

/// Handler: bauth.role.template.create
/// Crea un nuevo nodo de rol en idn_roles_rol_hierarchical.
pub struct RoleTemplateCreateHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for RoleTemplateCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let code = params.get("code").and_then(|v| v.as_str())
            .ok_or_else(|| err("code requerido"))?;
        let name_es = params.get("name_es").and_then(|v| v.as_str())
            .ok_or_else(|| err("name_es requerido"))?;
        let tier = params.get("tier").and_then(|v| v.as_str())
            .ok_or_else(|| err("tier requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        if !TIER_VALIDOS.contains(&tier) {
            return Err(err(&format!("tier inválido: '{}'", tier)));
        }

        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("tenant_uuid inválido")))
            .transpose()?;

        let parent_id = params.get("parent_id").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("parent_id inválido")))
            .transpose()?;

        let is_inheritable = params.get("is_inheritable").and_then(|v| v.as_bool()).unwrap_or(true);
        let ial_min = params.get("ial_min").and_then(|v| v.as_str());
        let bj = params.get("business_justification").cloned().unwrap_or(Value::Null);

        // Calcular depth desde parent
        let depth: i32 = if let Some(pid) = parent_id {
            let parent: Option<(i32,)> = sqlx::query_as(
                "SELECT depth FROM bauth.idn_roles_rol_hierarchical WHERE id = $1"
            ).bind(pid).fetch_optional(pg).await.map_err(|e| err(&e.to_string()))?;
            parent.map(|(d,)| d + 1).unwrap_or(1)
        } else {
            0
        };

        let name_json = json!({"es": name_es});
        let role_id = uuid::Uuid::now_v7();

        sqlx::query(
            "INSERT INTO bauth.idn_roles_rol_hierarchical
                (id, tenant_id, parent_id, tier, code, name, depth,
                 is_inheritable, status, version, ial_min,
                 business_justification, ctx_id)
             VALUES ($1, $2, $3, $4::rol_tier_enum, $5, $6, $7, $8,
                     'ACTIVE'::rol_status_enum, 1, $9, $10, $11)"
        )
        .bind(role_id)
        .bind(tenant_id)
        .bind(parent_id)
        .bind(tier)
        .bind(code)
        .bind(name_json)
        .bind(depth)
        .bind(is_inheritable)
        .bind(ial_min)
        .bind(bj)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%role_id, %code, %tier, "role.template.create — OK");
        Ok(json!({"role_id": role_id.to_string(), "status": "created", "depth": depth}))
    }
}

// ── Update ────────────────────────────────────────────

/// Handler: bauth.role.template.update
/// Actualiza campos de un rol existente (PATCH semántico). Incrementa version.
pub struct RoleTemplateUpdateHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for RoleTemplateUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("role_id requerido"))?;
        let role_id = uuid::Uuid::parse_str(id_str).map_err(|_| err("role_id inválido"))?;

        let tier   = params.get("tier").and_then(|v| v.as_str());
        let status = params.get("status").and_then(|v| v.as_str());
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        if let Some(t) = tier {
            if !TIER_VALIDOS.contains(&t) {
                return Err(err(&format!("tier inválido: '{}'", t)));
            }
        }
        if let Some(s) = status {
            if !STATUS_VALIDOS.contains(&s) {
                return Err(err(&format!("status inválido: '{}'", s)));
            }
        }

        let name_es = params.get("name_es").and_then(|v| v.as_str());
        let is_inheritable = params.get("is_inheritable").and_then(|v| v.as_bool());
        let bj = params.get("business_justification").cloned();

        sqlx::query(
            "UPDATE bauth.idn_roles_rol_hierarchical SET
                tier             = COALESCE($2::rol_tier_enum,   tier),
                status           = COALESCE($3::rol_status_enum, status),
                name             = CASE WHEN $4::text IS NOT NULL
                                        THEN jsonb_set(name, '{es}', to_jsonb($4::text))
                                        ELSE name END,
                is_inheritable   = COALESCE($5, is_inheritable),
                business_justification = COALESCE($6, business_justification),
                version          = version + 1,
                ctx_id           = $7
             WHERE id = $1"
        )
        .bind(role_id)
        .bind(tier)
        .bind(status)
        .bind(name_es)
        .bind(is_inheritable)
        .bind(bj)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%role_id, "role.template.update — OK");
        Ok(json!({"status": "updated", "role_id": id_str}))
    }
}

// ── Delete (desactivar) ───────────────────────────────

/// Handler: bauth.role.template.delete
/// Desactiva una plantilla de rol (status = INACTIVE). No elimina el registro.
pub struct RoleTemplateDeleteHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for RoleTemplateDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("role_id requerido"))?;
        let role_id = uuid::Uuid::parse_str(id_str).map_err(|_| err("role_id inválido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        sqlx::query(
            "UPDATE bauth.idn_roles_rol_hierarchical
             SET status = 'INACTIVE'::rol_status_enum, ctx_id = $2 WHERE id = $1"
        )
        .bind(role_id)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%role_id, "role.template.delete — desactivado OK");
        Ok(json!({"status": "deleted", "role_id": id_str}))
    }
}

// ── Factory ────────────────────────────────────────────

/// Registra todos los handlers de role_template en el dispatcher JSON-RPC.
pub fn all_role_template_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    let p = Some(pg);
    vec![
        ("bauth.role.template.list".into(),   Arc::new(RoleTemplateListHandler   { pg_pool: p.clone() })),
        ("bauth.role.template.get".into(),    Arc::new(RoleTemplateGetHandler    { pg_pool: p.clone() })),
        ("bauth.role.template.create".into(), Arc::new(RoleTemplateCreateHandler { pg_pool: p.clone() })),
        ("bauth.role.template.update".into(), Arc::new(RoleTemplateUpdateHandler { pg_pool: p.clone() })),
        ("bauth.role.template.delete".into(), Arc::new(RoleTemplateDeleteHandler { pg_pool: p.clone() })),
    ]
}
