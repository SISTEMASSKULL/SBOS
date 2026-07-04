// ============================================================
// bauth::server::handlers::domain_crud — dominio tenants
//
// CRUD para bauth.idn_tenant_domain — subdominios por tenant.
// Cada tenant tiene su propio dominio para email, web, api, etc.
// El tenant 0 (skull) ya tiene su dominio configurado.
// ============================================================
#![allow(dead_code)]

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

pub struct DomainListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for DomainListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str());
        let domain_type = params.get("domain_type").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { domain_id: Uuid, tenant_id: Uuid, subdomain: Option<String>, fqdn: String,
            domain_type: String, is_primary: bool, deploy_status: Option<String>, }

        let rows = if let (Some(t), Some(d)) = (tenant_id, domain_type) {
            sqlx::query_as("SELECT domain_id, tenant_id, subdomain, fqdn, domain_type::text, is_primary, deploy_status::text FROM bauth.idn_tenant_domain WHERE tenant_id=$1 AND domain_type=$2::domain_type_enum")
                .bind(Uuid::parse_str(t).unwrap_or(Uuid::nil())).bind(d).fetch_all(pg).await
        } else if let Some(t) = tenant_id {
            sqlx::query_as("SELECT domain_id, tenant_id, subdomain, fqdn, domain_type::text, is_primary, deploy_status::text FROM bauth.idn_tenant_domain WHERE tenant_id=$1")
                .bind(Uuid::parse_str(t).unwrap_or(Uuid::nil())).fetch_all(pg).await
        } else {
            sqlx::query_as("SELECT domain_id, tenant_id, subdomain, fqdn, domain_type::text, is_primary, deploy_status::text FROM bauth.idn_tenant_domain ORDER BY tenant_id, domain_type")
                .fetch_all(pg).await
        };
        let rows: Vec<Row> = rows.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"domains": rows, "count": rows.len()}))
    }
}

pub struct DomainCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for DomainCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant_id requerido".into(), data: None })?;
        let tid = Uuid::parse_str(tenant_id).map_err(|_| JsonRpcError { code: -32602, message: "tenant_id UUID invalido".into(), data: None })?;

        let domain_type = params.get("domain_type").and_then(|v| v.as_str()).unwrap_or("WEB");
        let subdomain = params.get("subdomain").and_then(|v| v.as_str()).unwrap_or("");
        let is_primary = params.get("is_primary").and_then(|v| v.as_bool()).unwrap_or(false);

        // Construir FQDN
        let tenant_slug: String = sqlx::query_scalar("SELECT tenant_slug FROM bauth.idn_tenant WHERE tenant_id=$1")
            .bind(tid).fetch_optional(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
            .ok_or_else(|| JsonRpcError { code: -32602, message: "tenant no encontrado".into(), data: None })?;

        let fqdn = if subdomain.is_empty() {
            format!("{}.sbos.bo", tenant_slug)
        } else {
            format!("{}.{}.sbos.bo", subdomain, tenant_slug)
        };

        // Validar fqdn unico
        let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM bauth.idn_tenant_domain WHERE fqdn=$1)")
            .bind(&fqdn).fetch_one(pg).await.unwrap_or(false);
        if exists {
            return Err(JsonRpcError { code: -32602, message: format!("dominio '{}' ya existe", fqdn), data: None });
        }

        let domain_id = Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.idn_tenant_domain (domain_id, tenant_id, subdomain, fqdn, domain_type, is_primary)
             VALUES ($1, $2, $3, $4, $5::domain_type_enum, $6)"
        ).bind(domain_id).bind(tid).bind(subdomain).bind(&fqdn).bind(domain_type).bind(is_primary)
        .execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({"created": true, "domain_id": domain_id.to_string(), "fqdn": fqdn}))
    }
}

pub struct DomainDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for DomainDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;
        let did = params.get("domain_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain_id requerido".into(), data: None })?;
        let uuid = Uuid::parse_str(did).map_err(|_| JsonRpcError { code: -32602, message: "domain_id UUID invalido".into(), data: None })?;
        sqlx::query("DELETE FROM bauth.idn_tenant_domain WHERE domain_id=$1")
            .bind(uuid).execute(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"deleted": true, "domain_id": did}))
    }
}
