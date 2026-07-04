//! bauth::sync — Reconcile Loop extendido (B45.D03)
//! Cada 60s: drift políticas, revalidación contextos, invalidación sesiones, eventos CAEP

use crate::db::AppContext;
use sqlx::PgPool;
use std::time::Duration;
use tracing::{info, warn};

pub async fn reconcile_loop(ctx: AppContext) {
    let mut interval = tokio::time::interval(Duration::from_secs(60));
    info!("sync::reconcile_loop — iniciado (60s) con B45.D03 extendido");

    loop {
        interval.tick().await;
        let pg = &ctx.pg;

        if let Err(e) = check_policy_drift(pg).await {
            warn!(error = %e, "reconcile: error verificando drift de políticas");
        }
        if let Err(e) = reevaluate_active_contexts(pg).await {
            warn!(error = %e, "reconcile: error re-evaluando contextos activos");
        }
        if let Err(e) = invalidate_expired_sessions(pg).await {
            warn!(error = %e, "reconcile: error invalidando sesiones expiradas");
        }
        if let Err(e) = emit_caep_events(pg).await {
            warn!(error = %e, "reconcile: error emitiendo eventos CAEP");
        }
    }
}

async fn check_policy_drift(pg: &PgPool) -> Result<(), String> {
    let (lib_count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.cfg_policy_library WHERE node_type = 'policy'"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    let (ath_count,): (i64,) = sqlx::query_as(
        "SELECT COALESCE(sum(c),0)::bigint FROM (
           SELECT count(*) as c FROM bauth.ath_policy_d1 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d2 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d3 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d4 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d5 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d6 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d7 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d8 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d9 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d10 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d11 WHERE is_active = true
           UNION ALL SELECT count(*) FROM bauth.ath_policy_d12 WHERE is_active = true
         ) sub"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    let delta = lib_count - ath_count;
    if delta != 0 {
        warn!(biblioteca = lib_count, ath_policy = ath_count, delta,
            "reconcile: drift detectado en políticas");
        sqlx::query(
            "INSERT INTO bauth.sync_log (sync_type, engine, status, error_message, ctx_id)
             VALUES ('POLICY_DRIFT_CHECK', 'BOTH', 'DRIFT_DETECTED', $1, 'system')"
        ).bind(format!("lib={} ath={} delta={}", lib_count, ath_count, delta))
        .execute(pg).await.map_err(|e| e.to_string())?;
    }
    Ok(())
}

async fn reevaluate_active_contexts(pg: &PgPool) -> Result<(), String> {
    let (stale,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.ses_context s
         JOIN bauth.idn_user_template u ON u.uuid::text = s.user_uuid
         WHERE s.expires_at > now() AND s.state = 'active'
           AND s.bitmask_hex != u.rol_bitmask_base64"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    if stale > 0 {
        warn!(desactualizadas = stale, "reconcile: invalidando sesiones con bitmask desactualizado");
        sqlx::query(
            "UPDATE bauth.ses_context s SET state = 'EXPIRED', invalidated_at = now()
             FROM bauth.idn_user_template u
             WHERE u.uuid::text = s.user_uuid AND s.expires_at > now()
               AND s.state = 'active' AND s.bitmask_hex != u.rol_bitmask_base64"
        ).execute(pg).await.map_err(|e| e.to_string())?;
    }
    Ok(())
}

async fn invalidate_expired_sessions(pg: &PgPool) -> Result<(), String> {
    let result = sqlx::query(
        "UPDATE bauth.ses_context SET state = 'EXPIRED', invalidated_at = now()
         WHERE expires_at <= now() AND state = 'active'"
    ).execute(pg).await.map_err(|e| e.to_string())?;

    let count = result.rows_affected();
    if count > 0 {
        info!(expiradas = count, "reconcile: sesiones expiradas invalidadas");
        sqlx::query(
            "INSERT INTO bauth.aud_event (event_type, resource_type, details, ctx_id)
             VALUES ('CONTEXT_INVALIDATE', 'ses_context', $1, 'system')"
        ).bind(format!("{} sesiones expiradas", count))
        .execute(pg).await.map_err(|e| e.to_string())?;
    }
    Ok(())
}

async fn emit_caep_events(pg: &PgPool) -> Result<(), String> {
    let (recent,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.ses_context WHERE invalidated_at > now() - interval '2 minutes' AND state = 'EXPIRED'"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    if recent > 0 {
        info!("reconcile: CAEP session-revoked — {} sesiones en último minuto", recent);
    }
    Ok(())
}
