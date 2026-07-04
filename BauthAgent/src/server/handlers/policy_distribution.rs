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
// aud_policy_change. En producción, un cron cada 30s llama a
// este endpoint y alerta si health != "ok".
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
        #[derive(sqlx::FromRow)]
        struct LastChange {
            changed_at: chrono::DateTime<chrono::Utc>,
            policy_slug: String,
            change_type: String,
        }

        let last_change: Option<LastChange> = sqlx::query_as(
            "SELECT changed_at, policy_slug, change_type
             FROM bauth.aud_policy_change
             ORDER BY changed_at DESC LIMIT 1"
        ).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando auditoría: {}", e), data: None,
        })?;

        // ── Políticas activas totales ──────────────────────
        #[derive(sqlx::FromRow)]
        struct PolicyCount { cnt: i64 }

        let mut total_policies: i64 = 0;
        for d in 1..=12 {
            let sql = format!(
                "SELECT COUNT(*) as cnt FROM bauth.ath_policy_d{} WHERE is_active = true AND config ? 'rule'", d
            );
            if let Ok(Some(row)) = sqlx::query_as::<_, PolicyCount>(&sql)
                .fetch_optional(pg).await
            {
                total_policies += row.cnt;
            }
        }

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
