// ============================================================
// bauth::server::handlers::org_crud — CRUD Organizacional
//
// CRUD completo para:
//   Tenant       — idn_tenant (40 columnas)
//   Org Empresa  — org_empresa
//   Org Sucursal — org_sucursal
//   Org Pos      — org_pos_logico
//
// Pendiente: update y delete completo de cada una.
// List ya implementado en org_structure.rs y tenant_list.rs
// ============================================================
#![allow(dead_code)]

use crate::domain::validate;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

// ── Helper ─────────────────────────────────────────────────

fn parse_uuid(param: &str, val: &str) -> Result<Uuid, JsonRpcError> {
    Uuid::parse_str(val).map_err(|_| JsonRpcError {
        code: -32602, message: format!("{}: UUID invalido", param), data: None,
    })
}

// ====================== TENANT CRUD =======================

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

        // Validaciones con scrutiny
        if let Err(e) = validate::tenant_slug(tenant_slug) { return Err(JsonRpcError { code: -32602, message: e, data: None }); }
        if let Err(e) = validate::required_text(tenant_name, "tenant_name", 2, 100) { return Err(JsonRpcError { code: -32602, message: e, data: None }); }
        if country.len() != 2 {
            return Err(JsonRpcError { code: -32602, message: "country: codigo ISO 3166-1 alpha-2 (ej: BO)".into(), data: None });
        }
        let valid_plans = ["BASIC","PRO","ENTERPRISE","UNLIMITED"];
        if !valid_plans.contains(&plan_tier) {
            return Err(JsonRpcError { code: -32602, message: format!("plan_tier invalido: {}", plan_tier), data: None });
        }

        let realm_kc = format!("tenant_{}", tenant_slug);
        let tenant_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.idn_tenant (tenant_id, tenant_slug, tenant_name, country, plan_tier, realm_kc, realm_kc_ext, namespace_k8s, status)
             VALUES ($1, $2, $3, $4, $5::text::plan_tier_enum, $6, $7, $8, 'ACTIVE')"
        ).bind(tenant_id).bind(tenant_slug).bind(tenant_name).bind(country)
         .bind(plan_tier).bind(&realm_kc).bind(format!("{}_ext", realm_kc)).bind(format!("tenant-{}", tenant_slug))
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error creando tenant: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"created": true, "tenant_id": tenant_id.to_string(), "slug": tenant_slug}))
    }
}

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
        struct Row { tenant_id: Uuid, tenant_slug: String, tenant_name: String,
            status: Option<String>, plan_tier: Option<String>, country: Option<String>,
            legal_name: Option<String>, domain: Option<String>, }
        let row: Row = sqlx::query_as(
            "SELECT tenant_id, tenant_slug, tenant_name, status::text, plan_tier::text,
                    country, legal_name, domain FROM bauth.idn_tenant WHERE tenant_id = $1"
        ).bind(uuid).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("{}", e), data: None,
        })?.ok_or_else(|| JsonRpcError { code: -32602, message: "tenant no encontrado".into(), data: None })?;

        Ok(serde_json::json!({"tenant_id": row.tenant_id, "slug": row.tenant_slug, "name": row.tenant_name,
            "status": row.status, "plan": row.plan_tier, "country": row.country, "legal_name": row.legal_name}))
    }
}

// ====================== EMPRESA CRUD =======================

pub struct EmpresaCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for EmpresaCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_id requerido".into(), data: None })?;
        let razon_social = params.get("razon_social").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "razon_social requerido".into(), data: None })?;
        validate::razon_social(razon_social).map_err(|e| JsonRpcError { code: -32602, message: e, data: None })?;
        let empresa_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.org_empresa (empresa_id, tenant_id, razon_social) VALUES ($1, $2, $3)"
        ).bind(empresa_id).bind(tenant_id).bind(razon_social)
        .execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"created": true, "empresa_id": empresa_id.to_string()}))
    }
}

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
            sqlx::query("UPDATE bauth.org_empresa SET razon_social=$2 WHERE empresa_id=$1")
                .bind(uuid).bind(rz).execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        }
        Ok(serde_json::json!({"updated": true, "empresa_id": eid}))
    }
}

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
        sqlx::query("DELETE FROM bauth.org_empresa WHERE empresa_id=$1")
            .bind(uuid).execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"deleted": true, "empresa_id": eid}))
    }
}

// ====================== SUCURSAL CRUD =======================

pub struct SucursalCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for SucursalCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let empresa_id = params.get("empresa_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "empresa_id requerido".into(), data: None })?;
        let nombre = params.get("nombre").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "nombre requerido".into(), data: None })?;
        let sucursal_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.org_sucursal (sucursal_id, empresa_id, tenant_id, nombre) VALUES ($1, $2, $3, $4)"
        ).bind(sucursal_id).bind(empresa_id).bind("default").bind(nombre)
        .execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"created": true, "sucursal_id": sucursal_id.to_string()}))
    }
}

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
        sqlx::query("DELETE FROM bauth.org_sucursal WHERE sucursal_id=$1")
            .bind(uuid).execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"deleted": true, "sucursal_id": sid}))
    }
}

// ====================== POS LOGICO CRUD =======================

pub struct PosCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PosCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let sucursal_id = params.get("sucursal_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "sucursal_id requerido".into(), data: None })?;
        let nombre = params.get("nombre").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "nombre requerido".into(), data: None })?;
        let pos_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.org_pos_logico (pos_id, sucursal_id, nombre) VALUES ($1, $2, $3)"
        ).bind(pos_id).bind(sucursal_id).bind(nombre)
        .execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"created": true, "pos_id": pos_id.to_string()}))
    }
}
