// ============================================================
// bauth::server::handlers::domain_audit — H-14 DomainEvaluationAudit
//
// Registra y consulta decisiones de dominio (WORM).
// ISO 27001 A.8.15 exige trazabilidad de cada decisión de acceso.
//
// Tablas canónicas DDL v2.12.0:
//   bauth.ses_caep_event_log — log CAEP WORM (reemplaza aud_event)
//   bauth.idn_roles_template — metadatos de dominios (reemplaza privilege_domain)
//
// Phantom D02 eliminado: aud_event no existe en DDL v2.12.0.
// Phantom D05 eliminado: privilege_domain no existe en DDL v2.12.0.
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

/// Handler: bauth.domain.audit — historial de evaluaciones desde ses_caep_event_log.
pub struct DomainAuditHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for DomainAuditHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct AuditRow {
            event_id:          uuid::Uuid,
            ctx_id:            Option<String>,
            event_type:        String,
            subject_id:        String,
            processing_status: String,
            created_at:        chrono::DateTime<chrono::Utc>,
        }

        let rows: Vec<AuditRow> = sqlx::query_as(
            "SELECT event_id, ctx_id, event_type, subject_id, processing_status, created_at
             FROM bauth.ses_caep_event_log
             ORDER BY created_at DESC LIMIT $1"
        )
        .bind(limit)
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let count = rows.len();
        Ok(serde_json::json!({"audit_events": rows, "count": count}))
    }
}

/// Handler: bauth.domain.config.list — lista dominios desde idn_roles_template.
pub struct DomainConfigListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for DomainConfigListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct ConfigRow {
            domain_number: i32,
            path:          String,
            label:         serde_json::Value,
            is_active:     bool,
        }

        let rows: Vec<ConfigRow> = sqlx::query_as(
            "SELECT DISTINCT domain_number, path, label, is_active
             FROM bauth.idn_roles_template
             WHERE node_type = 'domain' AND domain_number IS NOT NULL
             ORDER BY domain_number"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let count = rows.len();
        Ok(serde_json::json!({"domain_configs": rows, "count": count}))
    }
}

/// Handler: bauth.health.metrics — métricas en tiempo real desde BD.
pub struct HealthMetricsHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for HealthMetricsHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // Dominios: nodos con node_type='domain' en idn_roles_template
        let (dominios,): (i64,) = sqlx::query_as(
            "SELECT count(DISTINCT domain_number)
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND domain_number IS NOT NULL"
        )
        .fetch_one(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        // Átomos activos en idn_roles_template
        let (atomos,): (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.idn_roles_template WHERE node_type = 'atom' AND is_active = TRUE"
        )
        .fetch_one(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        // Políticas activas en auth_policy
        let (politicas,): (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.auth_policy WHERE active = TRUE"
        )
        .fetch_one(pg)
        .await
        .unwrap_or((0,));

        Ok(serde_json::json!({
            "dominios_activos":       dominios,
            "atomos_catalogo":        atomos,
            "politicas_activas":      politicas,
            "cumplimiento_iso_27001": "A.5.15-A.5.18, A.8.2, A.8.5, A.8.15",
            "cumplimiento_nist":      "800-63B Rev.4, 800-207 ZTA, 800-53 AC-2/5/6",
            "cumplimiento_pci":       "DSS 4.0.1 Req 8"
        }))
    }
}
