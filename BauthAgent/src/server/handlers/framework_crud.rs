// ============================================================
// bauth::server::handlers::framework_crud — H-13 CRUD 7 tablas
//
// Handlers JSON-RPC para consultar las tablas del Authentication Framework.
// Métodos: bauth.method.list, bauth.policy.list, bauth.config.list,
//          bauth.crypto.list, bauth.federation.list, bauth.compliance.list
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

macro_rules! pg_required {
    ($pg:expr) => {
        $pg.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "base de datos no disponible".into(), data: None })?
    };
}

// ─── auth_method ──────────────────────────────────────────────

pub struct MethodListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for MethodListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { method_id: String, method_name: String, method_type: String, aal_level: String, nist_status: String, active: bool }
        let rows: Vec<Row> = sqlx::query_as("SELECT method_id, method_name, method_type, aal_level, nist_status, active FROM bauth.ath_method ORDER BY method_id")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"methods": rows, "count": rows.len()}))
    }
}

// ─── auth_policy ──────────────────────────────────────────────

pub struct PolicyListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for PolicyListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { policy_name: String, policy_type: String, tier: String, priority: i32, active: bool }
        let rows: Vec<Row> = sqlx::query_as("SELECT policy_name, policy_type, tier, priority, active FROM bauth.ath_policy ORDER BY priority, tier")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"policies": rows, "count": rows.len()}))
    }
}

// ─── auth_config ──────────────────────────────────────────────

pub struct ConfigListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for ConfigListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { config_key: String, config_value: serde_json::Value, tier: String, description: String, active: bool }
        let rows: Vec<Row> = sqlx::query_as("SELECT config_key, config_value, tier, description, active FROM bauth.ath_config ORDER BY config_key, tier")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"configs": rows, "count": rows.len()}))
    }
}

// ─── crypto_algorithm ─────────────────────────────────────────

pub struct CryptoListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for CryptoListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { algo_id: String, algo_name: String, algo_type: String, category: String, is_primary: bool }
        let rows: Vec<Row> = sqlx::query_as("SELECT algo_id, algo_name, algo_type, category, is_primary FROM bauth.bos_crypto_algorithm ORDER BY algo_type, algo_id")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"algorithms": rows, "count": rows.len()}))
    }
}

// ─── federation_protocol ──────────────────────────────────────

pub struct FederationListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for FederationListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { protocol_id: String, protocol_name: String, protocol_type: String, rfc_ref: Option<String>, bauth_status: String }
        let rows: Vec<Row> = sqlx::query_as("SELECT protocol_id, protocol_name, protocol_type, rfc_ref, bauth_status FROM bauth.ath_federation_protocol ORDER BY protocol_id")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"protocols": rows, "count": rows.len()}))
    }
}

// ─── compliance_map ───────────────────────────────────────────

pub struct ComplianceListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for ComplianceListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { standard: String, control_id: String, control_name: String, implementation_status: String }
        let rows: Vec<Row> = sqlx::query_as("SELECT standard, control_id, control_name, implementation_status FROM bauth.aud_compliance_map ORDER BY standard, control_id")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"compliance": rows, "count": rows.len()}))
    }
}
