// ================================================================
// bauth::server::handlers::keycloak_sync — B12 handlers Keycloak
//
// bauth.keycloak.status  — health check + estado del motor
// bauth.keycloak.sync    — sync manual de rol o usuario a KC
// bauth.keycloak.reconcile — comparar KC vs bauth_db (drift detection)
// ================================================================

#![allow(dead_code)]
use crate::engine::keycloak_engine::KeycloakEngine;
use crate::engine::AuthEngine;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct KeycloakStatusHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakStatusHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let healthy = engine.health_check().await;

        Ok(serde_json::json!({
            "engine": engine.name(),
            "healthy": healthy,
            "domains": engine.covered_domains(),
            "mode": if healthy { "operativo" } else { "degradado" },
        }))
    }
}

pub struct KeycloakSyncHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakSyncHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let sync_type = params.get("type").and_then(|v| v.as_str()).unwrap_or("role");
        let id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "id requerido".into(), data: None })?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str()).unwrap_or("default");

        match sync_type {
            "role" => {
                engine.sync_role(id, tenant_id).await
                    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
                Ok(serde_json::json!({
                    "synced": true, "type": "role", "id": id,
                    "engine": engine.name(), "target": "Keycloak Composite Role",
                }))
            }
            "user" => {
                engine.sync_user(id, tenant_id).await
                    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
                Ok(serde_json::json!({
                    "synced": true, "type": "user", "id": id,
                    "engine": engine.name(), "target": "Keycloak User",
                }))
            }
            other => Err(JsonRpcError {
                code: -32602, message: format!("type '{}' desconocido — use 'role' o 'user'", other), data: None,
            }),
        }
    }
}

pub struct KeycloakReconcileHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakReconcileHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str()).unwrap_or("default");

        let report = engine.reconcile(tenant_id).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "engine": report.engine_name,
            "roles_created": report.roles_created,
            "roles_updated": report.roles_updated,
            "roles_deleted": report.roles_deleted,
            "users_created": report.users_created,
            "users_updated": report.users_updated,
            "users_disabled": report.users_disabled,
            "total_changes": report.total_changes(),
            "errors": report.errors,
        }))
    }
}

// ── B12.1: Sync Auth Flow ──────────────────────────────────────

pub struct KeycloakSyncFlowHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakSyncFlowHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let flow_alias = params.get("flow_alias").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "flow_alias requerido".into(), data: None })?;
        let tier = params.get("tier").and_then(|v| v.as_str()).unwrap_or("ALL");
        let methods: Vec<String> = params.get("methods").and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default();

        engine.sync_auth_flow(flow_alias, &methods, tier).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "synced": true, "flow_alias": flow_alias, "tier": tier, "methods": methods,
            "engine": engine.name(),
        }))
    }
}

// ── B12.1: Sync Realm Roles from Bits ───────────────────────────

pub struct KeycloakSyncRolesHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakSyncRolesHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let role_slug = params.get("role_slug").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "role_slug requerido".into(), data: None })?;

        // Cargar átomos desde BD
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        #[derive(sqlx::FromRow)]
        struct AtomPos { atom_position: i32 }

        let atoms: Vec<AtomPos> = sqlx::query_as(
            "SELECT pra.atom_position FROM bauth.privilege_role_atom pra
             JOIN bauth.privilege_role pr ON pr.role_id = pra.role_id
             WHERE pr.role_slug = $1 AND pra.is_active = true"
        ).bind(role_slug).fetch_all(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando átomos: {}", e), data: None,
        })?;

        let positions: Vec<usize> = atoms.iter().map(|a| a.atom_position as usize).collect();
        let created = engine.sync_realm_roles_from_bits(&positions).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "synced": true, "role_slug": role_slug,
            "total_positions": positions.len(), "created_roles": created,
            "engine": engine.name(),
        }))
    }
}

// ── B12.1: Reconcile Full ──────────────────────────────────────

pub struct KeycloakReconcileFullHandler {
    pub engine: Option<Arc<KeycloakEngine>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for KeycloakReconcileFullHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let engine = self.engine.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "KeycloakEngine no configurado".into(), data: None,
        })?;

        let report = engine.reconcile_full().await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "engine": report.engine_name,
            "roles_found": report.roles_updated,
            "users_found": report.users_updated,
            "users_disabled": report.users_disabled,
            "total_changes": report.total_changes(),
            "errors": report.errors,
        }))
    }
}
