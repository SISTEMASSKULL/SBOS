// ============================================================
// bauth::server::handlers::org_structure — H-028 FIX
// CRUD para tablas organizacionales: empresa, sucursal, pos_logico
// ============================================================
#![allow(dead_code)]

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct OrgEmpresaListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgEmpresaListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { empresa_id: String, razon_social: String, tenant_id: String, nit: Option<String> }

        let rows: Vec<Row> = if let Some(tid) = tenant_id {
            sqlx::query_as("SELECT empresa_id, razon_social, tenant_id, nit FROM bauth.org_empresa WHERE tenant_id = $1 ORDER BY razon_social")
                .bind(tid).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        } else {
            sqlx::query_as("SELECT empresa_id, razon_social, tenant_id, nit FROM bauth.org_empresa ORDER BY razon_social")
                .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        };

        Ok(serde_json::json!({"empresas": rows, "count": rows.len()}))
    }
}

pub struct OrgSucursalListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgSucursalListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let empresa_id = params.get("empresa_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { sucursal_id: String, nombre: String, empresa_id: String, tenant_id: String, direccion: Option<String> }

        let rows: Vec<Row> = if let Some(eid) = empresa_id {
            sqlx::query_as("SELECT sucursal_id, nombre, empresa_id, tenant_id, direccion FROM bauth.org_sucursal WHERE empresa_id = $1 ORDER BY nombre")
                .bind(eid).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        } else {
            sqlx::query_as("SELECT sucursal_id, nombre, empresa_id, tenant_id, direccion FROM bauth.org_sucursal ORDER BY nombre")
                .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        };

        Ok(serde_json::json!({"sucursales": rows, "count": rows.len()}))
    }
}

pub struct OrgPosListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for OrgPosListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let sucursal_id = params.get("sucursal_id").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { pos_id: String, nombre: String, sucursal_id: String, tipo: Option<String> }

        let rows: Vec<Row> = if let Some(sid) = sucursal_id {
            sqlx::query_as("SELECT pos_id, nombre, sucursal_id, tipo FROM bauth.org_pos_logico WHERE sucursal_id = $1 ORDER BY nombre")
                .bind(sid).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        } else {
            sqlx::query_as("SELECT pos_id, nombre, sucursal_id, tipo FROM bauth.org_pos_logico ORDER BY nombre")
                .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
        };

        Ok(serde_json::json!({"pos_logicos": rows, "count": rows.len()}))
    }
}
