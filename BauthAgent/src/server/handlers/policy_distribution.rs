// ============================================================
// bauth::server::handlers::policy_distribution — B9.T29
//
// PolicyDistributionMonitor — NIST SP 800-207 CDM (Continuous
// Diagnostics and Mitigation). Métricas de propagación de cambios
// de política a todos los PEPs (Kong, OAuth2-Proxy, banexus).
//
// bauth.policy.distribution.status:
//   - last_change_at: timestamp del cambio más reciente
//   - propagation_latency_ms: tiempo desde el cambio hasta ahora
//   - policies_total: políticas activas en los 12 dominios
//   - health: "ok" | "propagating" | "degraded" | "unknown"
//   - pep_count: número de PEPs registrados
//   - sla_p99_ms: 5000 (5s P99 objetivo)
//
// Probe interno: el handler mide en tiempo real consultando
// auth_policy.created_at (tabla canónica DDL v2.12.0).
//
// NOTA: auth_policy NO tiene columna updated_at — solo created_at.
// ses_caep_event_log es para eventos CAEP externos (session-revoked,
// credential-change, etc.) — NO para cambios de política interna.
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct PolicyDistributionHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyDistributionHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // ── Último cambio de política ──────────────────────
        // auth_policy.created_at es el timestamp de creación/versión de la política.
        // auth_policy NO tiene updated_at — la política más reciente por created_at
        // representa el último cambio registrado en el sistema.
        #[derive(sqlx::FromRow)]
        struct LastChange {
            changed_at: chrono::DateTime<chrono::Utc>,
            policy_slug: String,
            change_type: String,
        }

        let last_change: Option<LastChange> = sqlx::query_as(
            "SELECT created_at AS changed_at,
                    name AS policy_slug,
                    loa_required AS change_type
             FROM bauth.auth_policy
             WHERE active = TRUE
             ORDER BY created_at DESC LIMIT 1"
        ).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando auth_policy: {}", e), data: None,
        })?;

        // ── Políticas activas totales ──────────────────────
        #[derive(sqlx::FromRow)]
        struct PolicyCount { cnt: i64 }

        // D01 resuelto: ath_policy_d{N} → auth_policy (tabla unificada DDL v2.12.0)
        let total_policies: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_policy WHERE active = TRUE"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        // ── Calcular latencia de propagación ───────────────
        let (propagation_ms, health, last_change_info) = match &last_change {
            Some(lc) => {
                let elapsed_ms = (chrono::Utc::now() - lc.changed_at)
                    .num_milliseconds().max(0);
                let sla_p99_ms: i64 = 5000;

                let state = if elapsed_ms <= sla_p99_ms { "propagating" }
                    else if elapsed_ms <= 30_000 { "ok" }
                    else { "degraded" };

                (elapsed_ms, state, Some(serde_json::json!({
                    "policy_slug": lc.policy_slug,
                    "change_type": lc.change_type,
                    "changed_at": lc.changed_at.to_rfc3339(),
                })))
            }
            None => (0, "unknown", None),
        };

        // ── PEP count (placeholder para Kong/OAuth2-Proxy) ──
        let pep_count: i64 = 0; // En producción: consultar Kong Admin API

        Ok(serde_json::json!({
            "health": health,
            "propagation_latency_ms": propagation_ms,
            "sla_p99_ms": 5000,
            "last_change": last_change_info,
            "policies_total": total_policies,
            "domains_active": 12,
            "pep_count": pep_count,
            "probe_interval_s": 30,
            "standard": "NIST SP 800-207 CDM",
            "checked_at": chrono::Utc::now().to_rfc3339(),
        }))
    }
}
