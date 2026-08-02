// ============================================================
// bauth::server::handlers::org_structure — Estructura Organizacional
//
// DDL v2.12.0: los nodos organizacionales viven en idn_identity_entity (T-156).
// Jerarquía: tenant > bdomain (empresa) > bsubdomain (sucursal) > pos > actor.
//
// Concepto de la tabla:
//   entidad_nivel_enum  →  'tenant' | 'bdomain' | 'bsubdomain' | 'pos' | 'actor'
//   name JSONB          →  nombre en múltiples idiomas (name->>'es' = español)
//   metadata JSONB      →  campos adicionales (nit, direccion, tipo, etc.)
//   parent_id           →  FK al nodo padre en la misma tabla (closure implícita)
//   code                →  código de negocio único (RUC/NIT abreviado, sigla, etc.)
//
// Handlers:
//   OrgEmpresaListHandler  — lista nodos level='bdomain' (empresas)
//   OrgSucursalListHandler — lista nodos level='bsubdomain' (sucursales)
//   OrgPosListHandler      — lista nodos level='pos' (puntos de venta)
// ============================================================
#![allow(dead_code)]

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

// ── Lista de Empresas (level = bdomain) ──────────────────────

pub struct OrgEmpresaListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgEmpresaListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct Row {
            entity_id: uuid::Uuid,
            razon_social: Option<String>,
            tenant_id: uuid::Uuid,
            code: String,
            nit: Option<String>,
            status: String,
        }

        let rows: Vec<Row> = if let Some(tid) = tenant_id {
            let tid_uuid: uuid::Uuid = tid.parse().map_err(|_| JsonRpcError {
                code: -32602, message: "tenant_id UUID inválido".into(), data: None,
            })?;
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS razon_social,
                        tenant_id,
                        code,
                        metadata->>'nit' AS nit,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'bdomain'
                   AND tenant_id = $1
                   AND status = 'ACTIVE'
                 ORDER BY razon_social"
            ).bind(tid_uuid).fetch_all(pg)
        } else {
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS razon_social,
                        tenant_id,
                        code,
                        metadata->>'nit' AS nit,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'bdomain'
                   AND status = 'ACTIVE'
                 ORDER BY razon_social"
            ).fetch_all(pg)
        }.await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let empresas: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "empresa_id": r.entity_id.to_string(),
            "razon_social": r.razon_social,
            "tenant_id": r.tenant_id.to_string(),
            "code": r.code,
            "nit": r.nit,
            "status": r.status,
        })).collect();
        let count = empresas.len();
        Ok(serde_json::json!({ "empresas": empresas, "count": count }))
    }
}

// ── Lista de Sucursales (level = bsubdomain) ─────────────────
// parent_id de bsubdomain = entity_id del nodo bdomain (empresa)

pub struct OrgSucursalListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgSucursalListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let empresa_id = params.get("empresa_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct Row {
            entity_id: uuid::Uuid,
            nombre: Option<String>,
            parent_id: Option<uuid::Uuid>,
            tenant_id: uuid::Uuid,
            code: String,
            direccion: Option<String>,
            status: String,
        }

        let rows: Vec<Row> = if let Some(eid) = empresa_id {
            let eid_uuid: uuid::Uuid = eid.parse().map_err(|_| JsonRpcError {
                code: -32602, message: "empresa_id UUID inválido".into(), data: None,
            })?;
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS nombre,
                        parent_id,
                        tenant_id,
                        code,
                        metadata->>'direccion' AS direccion,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'bsubdomain'
                   AND parent_id = $1
                   AND status = 'ACTIVE'
                 ORDER BY nombre"
            ).bind(eid_uuid).fetch_all(pg)
        } else {
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS nombre,
                        parent_id,
                        tenant_id,
                        code,
                        metadata->>'direccion' AS direccion,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'bsubdomain'
                   AND status = 'ACTIVE'
                 ORDER BY nombre"
            ).fetch_all(pg)
        }.await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let sucursales: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "sucursal_id": r.entity_id.to_string(),
            "nombre": r.nombre,
            "empresa_id": r.parent_id.map(|u| u.to_string()),
            "tenant_id": r.tenant_id.to_string(),
            "code": r.code,
            "direccion": r.direccion,
            "status": r.status,
        })).collect();
        let count = sucursales.len();
        Ok(serde_json::json!({ "sucursales": sucursales, "count": count }))
    }
}

// ── Lista de Puntos de Venta (level = pos) ───────────────────
// parent_id de pos = entity_id del nodo bsubdomain (sucursal)

pub struct OrgPosListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgPosListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let sucursal_id = params.get("sucursal_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct Row {
            entity_id: uuid::Uuid,
            nombre: Option<String>,
            parent_id: Option<uuid::Uuid>,
            code: String,
            tipo: Option<String>,
            status: String,
        }

        let rows: Vec<Row> = if let Some(sid) = sucursal_id {
            let sid_uuid: uuid::Uuid = sid.parse().map_err(|_| JsonRpcError {
                code: -32602, message: "sucursal_id UUID inválido".into(), data: None,
            })?;
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS nombre,
                        parent_id,
                        code,
                        metadata->>'tipo' AS tipo,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'pos'
                   AND parent_id = $1
                   AND status = 'ACTIVE'
                 ORDER BY nombre"
            ).bind(sid_uuid).fetch_all(pg)
        } else {
            sqlx::query_as(
                "SELECT entity_id,
                        name->>'es' AS nombre,
                        parent_id,
                        code,
                        metadata->>'tipo' AS tipo,
                        status
                 FROM bauth.idn_identity_entity
                 WHERE level = 'pos'
                   AND status = 'ACTIVE'
                 ORDER BY nombre"
            ).fetch_all(pg)
        }.await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let pos_logicos: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "pos_id": r.entity_id.to_string(),
            "nombre": r.nombre,
            "sucursal_id": r.parent_id.map(|u| u.to_string()),
            "code": r.code,
            "tipo": r.tipo,
            "status": r.status,
        })).collect();
        let count = pos_logicos.len();
        Ok(serde_json::json!({ "pos_logicos": pos_logicos, "count": count }))
    }
}
