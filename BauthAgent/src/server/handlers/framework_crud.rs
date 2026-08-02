// ============================================================
// bauth::server::handlers::framework_crud — H-13 CRUD 7 tablas
//
// Handlers JSON-RPC para consultar las tablas del Authentication Framework.
// Métodos: bauth.method.list, bauth.policy.list, bauth.config.list,
//          bauth.crypto.list, bauth.federation.list, bauth.compliance.list
//
// DDL v2.12.0 — tablas canónicas (phantoms eliminados):
//   ath_method              → auth_method  (code, category, name JSONB, loa_provided, status)
//   ath_policy              → auth_policy  (name, loa_required, active)
//   ath_config              → auth_config  (key, value JSONB, description)
//   bos_crypto_algorithm    → auth_crypto_algorithm (code, type, status, is_pqc)
//   ath_federation_protocol → auth_method WHERE category='D' (métodos de federación)
//   aud_compliance_map      → auth_compliance_map (standard, control_id, control_description, coverage_level)
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
        // auth_method.name es JSONB multilingüe → extraer 'es'
        // is_primary → (status = 'IMPLEMENTED')
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row {
            method_id: String,
            method_name: Option<String>,
            method_type: String,
            aal_level: String,
            nist_status: String,
            active: bool,
        }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT method_id::text AS method_id,
                    name->>'es' AS method_name,
                    category AS method_type,
                    loa_provided AS aal_level,
                    status AS nist_status,
                    (status = 'IMPLEMENTED') AS active
             FROM bauth.auth_method
             ORDER BY category, sort_order"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"methods": rows, "count": rows.len()}))
    }
}

// ─── auth_policy ──────────────────────────────────────────────
// auth_policy NO tiene columnas tier/priority — solo name, loa_required, active.

pub struct PolicyListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for PolicyListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { policy_name: String, policy_type: String, active: bool }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT name AS policy_name, loa_required AS policy_type, active
             FROM bauth.auth_policy
             ORDER BY loa_required, name"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"policies": rows, "count": rows.len()}))
    }
}

// ─── auth_config ──────────────────────────────────────────────
// auth_config NO tiene columnas tier/active — tiene key, value JSONB, description.

pub struct ConfigListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for ConfigListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { config_key: String, config_value: serde_json::Value, description: String }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT key AS config_key, value AS config_value, description
             FROM bauth.auth_config
             ORDER BY key"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"configs": rows, "count": rows.len()}))
    }
}

// ─── auth_crypto_algorithm ────────────────────────────────────
// Reemplaza bos_crypto_algorithm. Columnas: algo_id, code, type, is_pqc, status.

pub struct CryptoListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for CryptoListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { algo_id: String, algo_name: String, algo_type: String, is_pqc: bool, status: String }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT algo_id::text AS algo_id,
                    code AS algo_name,
                    type AS algo_type,
                    is_pqc,
                    status
             FROM bauth.auth_crypto_algorithm
             ORDER BY type, code"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"algorithms": rows, "count": rows.len()}))
    }
}

// ─── Métodos de Federación (categoría D) ──────────────────────
// ath_federation_protocol no existe en DDL v2.12.0.
// Los métodos de federación son métodos auth_method con category='D'.

pub struct FederationListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for FederationListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { protocol_id: String, protocol_name: Option<String>, loa_provided: String, bauth_status: String }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT method_id::text AS protocol_id,
                    name->>'es' AS protocol_name,
                    loa_provided,
                    status AS bauth_status
             FROM bauth.auth_method
             WHERE category = 'D'
             ORDER BY sort_order"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"protocols": rows, "count": rows.len()}))
    }
}

// ─── auth_compliance_map ──────────────────────────────────────
// Reemplaza aud_compliance_map. Columnas: standard, control_id, control_description, coverage_level.

pub struct ComplianceListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for ComplianceListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_required!(self.pg_pool);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { standard: String, control_id: String, control_name: String, implementation_status: String }
        let rows: Vec<Row> = sqlx::query_as(
            "SELECT standard,
                    control_id,
                    control_description AS control_name,
                    coverage_level AS implementation_status
             FROM bauth.auth_compliance_map
             ORDER BY standard, control_id"
        )
        .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({"compliance": rows, "count": rows.len()}))
    }
}
