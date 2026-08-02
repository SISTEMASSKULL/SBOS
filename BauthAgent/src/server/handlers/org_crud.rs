// ============================================================
// bauth::server::handlers::org_crud — CRUD Organizacional
//
// CRUD canónico para entidades organizacionales (DDL v2.12.0):
//   Tenant        — bauth.idn_tenant
//   Empresa       — bauth.idn_identity_entity (level='bdomain')
//   Sucursal      — bauth.idn_identity_entity (level='bsubdomain')
//   Punto de Venta — bauth.idn_identity_entity (level='pos')
//
// D04 ADR-010: org_empresa/sucursal/pos_logico eliminadas.
// Toda la jerarquía organizacional vive en idn_identity_entity.
// realm_kc/realm_kc_ext/namespace_k8s eliminados de idn_tenant (KC eliminado).
//
// DOC-SBOS-001 N3 · SBOS-050 · ISO 27001 A.5.15
// ============================================================

use crate::domain::validate;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

/// Tiers válidos de plan según plan_tier_enum del DDL.
const PLAN_TIERS: &[&str] = &["BASIC", "PRO", "ENTERPRISE"];

/// Tipos válidos de tenant según tenant_type_enum del DDL.
const TENANT_TYPES: &[&str] = &["STANDARD", "REGULATED", "HIGH_SENSITIVITY"];

// ── Helper ─────────────────────────────────────────────────

fn parse_uuid(param: &str, val: &str) -> Result<Uuid, JsonRpcError> {
    Uuid::parse_str(val).map_err(|_| JsonRpcError {
        code: -32602, message: format!("{}: UUID invalido", param), data: None,
    })
}

/// Genera un código de entidad desde el nombre (máx. 20 chars, minúsculas, guión medio como separador).
fn generar_code(nombre: &str) -> String {
    nombre
        .to_lowercase()
        .chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace())
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join("-")
        .chars()
        .take(20)
        .collect()
}

// ====================== TENANT CRUD =======================

/// Handler: bauth.org.tenant.create
/// Crea un tenant en bauth.idn_tenant. Sin KC (ADR-010).
pub struct TenantCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for TenantCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tenant_slug = params.get("tenant_slug").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_slug requerido".into(), data: None })?;
        let tenant_name = params.get("tenant_name").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_name requerido".into(), data: None })?;
        let country = params.get("country").and_then(|v| v.as_str()).unwrap_or("BO");
        let plan_tier = params.get("plan_tier").and_then(|v| v.as_str()).unwrap_or("BASIC");
        let tenant_type = params.get("tenant_type").and_then(|v| v.as_str()).unwrap_or("STANDARD");

        if let Err(e) = validate::tenant_slug(tenant_slug) {
            return Err(JsonRpcError { code: -32602, message: e, data: None });
        }
        if let Err(e) = validate::required_text(tenant_name, "tenant_name", 2, 100) {
            return Err(JsonRpcError { code: -32602, message: e, data: None });
        }
        if country.len() != 2 {
            return Err(JsonRpcError {
                code: -32602,
                message: "country: código ISO 3166-1 alpha-2 (ej: BO)".into(),
                data: None,
            });
        }
        if !PLAN_TIERS.contains(&plan_tier) {
            return Err(JsonRpcError {
                code: -32602,
                message: format!("plan_tier inválido. Opciones: {:?}", PLAN_TIERS),
                data: None,
            });
        }
        if !TENANT_TYPES.contains(&tenant_type) {
            return Err(JsonRpcError {
                code: -32602,
                message: format!("tenant_type inválido. Opciones: {:?}", TENANT_TYPES),
                data: None,
            });
        }

        let tenant_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.idn_tenant
                (tenant_id, tenant_slug, tenant_name, country,
                 plan_tier, tenant_type, status)
             VALUES ($1, $2, $3, $4, $5::text::plan_tier_enum, $6::text::tenant_type_enum, 'ACTIVE')"
        )
        .bind(tenant_id)
        .bind(tenant_slug)
        .bind(tenant_name)
        .bind(country)
        .bind(plan_tier)
        .bind(tenant_type)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error creando tenant: {}", e), data: None,
        })?;

        Ok(serde_json::json!({
            "created": true,
            "tenant_id": tenant_id.to_string(),
            "slug": tenant_slug,
            "plan": plan_tier,
            "type": tenant_type,
        }))
    }
}

/// Handler: bauth.org.tenant.get
pub struct TenantGetHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for TenantGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tid = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_id requerido".into(), data: None })?;
        let uuid = parse_uuid("tenant_id", tid)?;

        #[derive(sqlx::FromRow)]
        struct Row {
            tenant_id: Uuid,
            tenant_slug: String,
            tenant_name: String,
            status: Option<String>,
            plan_tier: Option<String>,
            country: Option<String>,
            legal_name: Option<String>,
        }
        let row: Row = sqlx::query_as(
            "SELECT tenant_id, tenant_slug, tenant_name, status::text, plan_tier::text,
                    country, legal_name
             FROM bauth.idn_tenant WHERE tenant_id = $1"
        )
        .bind(uuid)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        .ok_or_else(|| JsonRpcError {
            code: -32602, message: "tenant no encontrado".into(), data: None,
        })?;

        Ok(serde_json::json!({
            "tenant_id": row.tenant_id,
            "slug": row.tenant_slug,
            "name": row.tenant_name,
            "status": row.status,
            "plan": row.plan_tier,
            "country": row.country,
            "legal_name": row.legal_name,
        }))
    }
}

// ====================== EMPRESA (bdomain) CRUD =======================

/// Handler: bauth.org.empresa.create
/// Crea una empresa (nivel bdomain) en bauth.idn_identity_entity.
pub struct EmpresaCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for EmpresaCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_id requerido".into(), data: None })?;
        let tenant_uuid = parse_uuid("tenant_id", tenant_id)?;

        let razon_social = params.get("razon_social").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "razon_social requerido".into(), data: None })?;
        validate::razon_social(razon_social)
            .map_err(|e| JsonRpcError { code: -32602, message: e, data: None })?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");
        let code = params.get("code").and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| generar_code(razon_social));

        let empresa_id = Uuid::now_v7();
        let name = serde_json::json!({"es": razon_social});

        sqlx::query(
            "INSERT INTO bauth.idn_identity_entity
                (entity_id, tenant_id, level, code, name, ctx_id)
             VALUES ($1, $2, 'bdomain', $3, $4, $5)"
        )
        .bind(empresa_id)
        .bind(tenant_uuid)
        .bind(&code)
        .bind(&name)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"created": true, "empresa_id": empresa_id.to_string(), "code": code}))
    }
}

/// Handler: bauth.org.empresa.update
pub struct EmpresaUpdateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for EmpresaUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let eid = params.get("empresa_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "empresa_id requerido".into(), data: None })?;
        let uuid = parse_uuid("empresa_id", eid)?;

        if let Some(rz) = params.get("razon_social").and_then(|v| v.as_str()) {
            let name = serde_json::json!({"es": rz});
            sqlx::query(
                "UPDATE bauth.idn_identity_entity
                 SET name = $2, updated_at = now()
                 WHERE entity_id = $1 AND level = 'bdomain'"
            )
            .bind(uuid)
            .bind(&name)
            .execute(pg)
            .await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        }

        Ok(serde_json::json!({"updated": true, "empresa_id": eid}))
    }
}

/// Handler: bauth.org.empresa.delete (soft-delete → ARCHIVED)
pub struct EmpresaDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for EmpresaDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let eid = params.get("empresa_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "empresa_id requerido".into(), data: None })?;
        let uuid = parse_uuid("empresa_id", eid)?;

        sqlx::query(
            "UPDATE bauth.idn_identity_entity
             SET status = 'ARCHIVED', updated_at = now()
             WHERE entity_id = $1 AND level = 'bdomain'"
        )
        .bind(uuid)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"archived": true, "empresa_id": eid}))
    }
}

// ====================== SUCURSAL (bsubdomain) CRUD =======================

/// Handler: bauth.org.sucursal.create
pub struct SucursalCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for SucursalCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let empresa_id = params.get("empresa_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "empresa_id requerido".into(), data: None })?;
        let parent_uuid = parse_uuid("empresa_id", empresa_id)?;

        let nombre = params.get("nombre").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "nombre requerido".into(), data: None })?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Obtener tenant_id de la empresa padre
        let tenant_row: Option<(Uuid,)> = sqlx::query_as(
            "SELECT tenant_id FROM bauth.idn_identity_entity WHERE entity_id = $1 AND level = 'bdomain'"
        )
        .bind(parent_uuid)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let tenant_id = tenant_row
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "empresa_id no encontrado".into(), data: None,
            })?
            .0;

        let sucursal_id = Uuid::now_v7();
        let code = params.get("code").and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| generar_code(nombre));
        let name = serde_json::json!({"es": nombre});

        sqlx::query(
            "INSERT INTO bauth.idn_identity_entity
                (entity_id, tenant_id, parent_id, level, code, name, ctx_id)
             VALUES ($1, $2, $3, 'bsubdomain', $4, $5, $6)"
        )
        .bind(sucursal_id)
        .bind(tenant_id)
        .bind(parent_uuid)
        .bind(&code)
        .bind(&name)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"created": true, "sucursal_id": sucursal_id.to_string(), "code": code}))
    }
}

/// Handler: bauth.org.sucursal.delete (soft-delete → ARCHIVED)
pub struct SucursalDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for SucursalDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let sid = params.get("sucursal_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "sucursal_id requerido".into(), data: None })?;
        let uuid = parse_uuid("sucursal_id", sid)?;

        sqlx::query(
            "UPDATE bauth.idn_identity_entity
             SET status = 'ARCHIVED', updated_at = now()
             WHERE entity_id = $1 AND level = 'bsubdomain'"
        )
        .bind(uuid)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"archived": true, "sucursal_id": sid}))
    }
}

// ====================== POS (pos) CRUD =======================

/// Handler: bauth.org.pos.create
pub struct PosCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PosCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let sucursal_id = params.get("sucursal_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "sucursal_id requerido".into(), data: None })?;
        let parent_uuid = parse_uuid("sucursal_id", sucursal_id)?;

        let nombre = params.get("nombre").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "nombre requerido".into(), data: None })?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Obtener tenant_id de la sucursal padre
        let tenant_row: Option<(Uuid,)> = sqlx::query_as(
            "SELECT tenant_id FROM bauth.idn_identity_entity WHERE entity_id = $1 AND level = 'bsubdomain'"
        )
        .bind(parent_uuid)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let tenant_id = tenant_row
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "sucursal_id no encontrado".into(), data: None,
            })?
            .0;

        let pos_id = Uuid::now_v7();
        let code = params.get("code").and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| generar_code(nombre));
        let name = serde_json::json!({"es": nombre});

        sqlx::query(
            "INSERT INTO bauth.idn_identity_entity
                (entity_id, tenant_id, parent_id, level, code, name, ctx_id)
             VALUES ($1, $2, $3, 'pos', $4, $5, $6)"
        )
        .bind(pos_id)
        .bind(tenant_id)
        .bind(parent_uuid)
        .bind(&code)
        .bind(&name)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"created": true, "pos_id": pos_id.to_string(), "code": code}))
    }
}
