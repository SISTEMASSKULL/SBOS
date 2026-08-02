//! bauth::sync — Reconcile Loop (B45.D03) + F4 Retención
//!
//! Loop cada 60s:
//!   1. Drift de políticas (cfg_policy_library vs auth_policy)
//!   2. Invalidación de sesiones expiradas (ses_session_log)
//!   3. Emisión de eventos CAEP session-revoked hacia bNotify (C-BAUTH-004)
//!
//! Tablas canónicas (DDL v2.12.0):
//!   bauth.auth_policy       — políticas de autenticación (reemplaza ath_policy_d1..12)
//!   bauth.ses_session_log   — sesiones (reemplaza ses_context)
//!   bauth.ses_caep_event_log — log CAEP receptor (reemplaza aud_event)
//!   bauth.cfg_policy_library — políticas y configuración global
//!
//! Eliminado:
//!   - ses_context (phantom D06)         → ses_session_log
//!   - ath_policy_d1..d12 (phantom D01)  → auth_policy
//!   - idn_user_template (phantom D03)   → idn_user
//!   - aud_event (phantom D02)           → ses_caep_event_log
//!   - sync_log (phantom)                → eliminado (no existe en DDL v2.12.0)
//!   - reevaluate_active_contexts        → eliminado (bitmask en Redis, no en SQL)

pub mod retention;  // F4: job de retención/compactación T-152 (B01 §gobernanza)

use crate::db::AppContext;
use crate::domain::caep::EventoCaep;
use crate::engine::caep_client::{CaepTransmitter, ErrorCaep};
use sqlx::PgPool;
use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;
use tracing::{info, warn};

/// TTL de sesión por defecto (segundos) — si no está en cfg_policy_library.
const SESSION_TIMEOUT_SECS_DEFAULT: i64 = 3600;

pub async fn reconcile_loop(ctx: AppContext, caep_tx: Arc<dyn CaepTransmitter>) {
    let mut interval = tokio::time::interval(Duration::from_secs(60));
    info!(transmisor_caep = caep_tx.nombre(),
        "sync::reconcile_loop — iniciado (60s) DDL canónico v2.12.0");

    // Dedup local de eventos CAEP ya emitidos (idempotencia del emisor).
    let mut caep_emitidos: HashSet<String> = HashSet::new();

    loop {
        interval.tick().await;
        let pg = &ctx.pg;

        if let Err(e) = check_policy_drift(pg).await {
            warn!(error = %e, "reconcile: error verificando drift de políticas");
        }
        if let Err(e) = invalidate_expired_sessions(pg).await {
            warn!(error = %e, "reconcile: error invalidando sesiones expiradas");
        }
        if let Err(e) = emit_caep_events(pg, &caep_tx, &mut caep_emitidos).await {
            warn!(error = %e, "reconcile: error emitiendo eventos CAEP");
        }
    }
}

/// Verifica drift entre políticas en `cfg_policy_library` y `auth_policy`.
///
/// Fuentes canónicas (DDL v2.12.0):
///   - `bauth.cfg_policy_library` — almacén global de políticas (node_type='policy')
///   - `bauth.auth_policy`         — políticas de autenticación por LoA/tenant (T-336)
///
/// Un delta ≠ 0 indica que las políticas de auth no están sincronizadas con la
/// biblioteca global. Se registra en tracing (sync_log eliminado — no existe en DDL).
async fn check_policy_drift(pg: &PgPool) -> Result<(), String> {
    let (lib_count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.cfg_policy_library WHERE node_type = 'policy'"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    let (ath_count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.auth_policy WHERE active = TRUE"
    ).fetch_one(pg).await.map_err(|e| e.to_string())?;

    let delta = lib_count - ath_count;
    if delta != 0 {
        warn!(
            biblioteca  = lib_count,
            auth_policy = ath_count,
            delta,
            "reconcile: drift detectado entre cfg_policy_library y auth_policy"
        );
    }
    Ok(())
}

/// Invalida sesiones cuyo `last_active_at` supera el TTL configurado.
///
/// Fuente canónica: `bauth.ses_session_log` (DDL v2.12.0 T-181).
/// `ses_context` fue eliminado (phantom D06).
///
/// TTL: se intenta leer de `cfg_policy_library` con clave `session.timeout_secs`;
/// si no existe se usa el default de 3600s.
///
/// Las sesiones terminadas se registran en `ses_caep_event_log` como
/// `session-revoked` (WORM append-only, RFC 8935).
async fn invalidate_expired_sessions(pg: &PgPool) -> Result<(), String> {
    let timeout_secs = leer_timeout_sesion(pg).await;

    // Marcar sesiones inactivas como terminadas (TIMEOUT)
    let result = sqlx::query(
        r#"
        UPDATE bauth.ses_session_log
        SET    terminated_at      = now(),
               termination_reason = 'TIMEOUT'
        WHERE  terminated_at IS NULL
          AND  last_active_at <= now() - ($1 * INTERVAL '1 second')
        "#,
    )
    .bind(timeout_secs)
    .execute(pg)
    .await
    .map_err(|e| e.to_string())?;

    let count = result.rows_affected();
    if count > 0 {
        info!(expiradas = count, timeout_secs, "reconcile: sesiones expiradas terminadas (TIMEOUT)");

        // Registrar en ses_caep_event_log las sesiones que acaban de terminar
        registrar_sesiones_revocadas(pg, count).await?;
    }
    Ok(())
}

/// Lee el TTL de sesión desde `cfg_policy_library`.
/// Retorna el default si la clave no existe o no es parseable.
async fn leer_timeout_sesion(pg: &PgPool) -> i64 {
    let row: Option<(serde_json::Value,)> = sqlx::query_as(
        "SELECT config_value FROM bauth.cfg_policy_library WHERE config_key = 'session.timeout_secs'"
    )
    .fetch_optional(pg)
    .await
    .unwrap_or(None);

    row.and_then(|(v,)| v.as_i64())
       .filter(|&t| t > 0)
       .unwrap_or(SESSION_TIMEOUT_SECS_DEFAULT)
}

/// Inserta un log de revocación en `ses_caep_event_log` para el reconcile de sesiones.
///
/// `ses_caep_event_log` es WORM — se usa para señalizar que el daemon revocó sesiones
/// por inactividad (event_type='session-revoked', subject_type='session').
async fn registrar_sesiones_revocadas(pg: &PgPool, count: u64) -> Result<(), String> {
    sqlx::query(
        r#"
        INSERT INTO bauth.ses_caep_event_log
            (event_type, subject_id, subject_type, transmitter_id,
             processing_status, event_payload, ctx_id)
        VALUES
            ('session-revoked', 'bauth:reconcile', 'session', 'bauth',
             'APPLIED',
             jsonb_build_object('source', 'reconcile_timeout', 'count', $1::bigint),
             'system')
        "#,
    )
    .bind(count as i64)
    .execute(pg)
    .await
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// Emite eventos CAEP `session-revoked` hacia bNotify por cada sesión terminada reciente.
///
/// Fuente canónica: `bauth.ses_session_log` con `terminated_at IS NOT NULL`
/// en la ventana de 10 minutos.
///
/// Idempotente: dedup local por `event_id` + bNotify deduplica del otro lado
/// (C-BNOTIFY-002 §3). Si bNotify no está disponible se corta el lote y el
/// próximo tick reintenta.
async fn emit_caep_events(
    pg: &PgPool,
    caep_tx: &Arc<dyn CaepTransmitter>,
    emitidos: &mut HashSet<String>,
) -> Result<(), String> {
    // Sesiones terminadas por timeout o revocación en los últimos 10 minutos
    let filas: Vec<(String, String, String, String)> = sqlx::query_as(
        r#"
        SELECT
            ctx_id,
            user_id::text,
            tenant_id::text,
            to_char(terminated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        FROM bauth.ses_session_log
        WHERE terminated_at   > now() - INTERVAL '10 minutes'
          AND termination_reason IN ('TIMEOUT', 'ADMIN_REVOKE', 'CAEP_REVOKE')
        ORDER BY terminated_at
        LIMIT 200
        "#,
    )
    .fetch_all(pg)
    .await
    .map_err(|e| e.to_string())?;

    // Poda del dedup local para evitar crecimiento ilimitado
    if emitidos.len() > 8192 {
        emitidos.clear();
    }

    let mut enviados: u32 = 0;
    for (ctx_id, user_id, tenant_id, instante) in filas {
        let evento = EventoCaep::sesion_revocada(&ctx_id, &user_id, &tenant_id, &instante, "reconcile");
        let id = evento.event_id();
        if emitidos.contains(&id) {
            continue;
        }
        match caep_tx.transmitir(&evento).await {
            Ok(()) => {
                emitidos.insert(id);
                enviados += 1;
            }
            Err(e @ ErrorCaep::NoDisponible(_)) => {
                warn!(error = %e, "reconcile: emisión CAEP interrumpida — bnotify no disponible");
                break;
            }
            Err(e) => {
                warn!(error = %e, ctx_id = %ctx_id, "reconcile: evento CAEP no confirmado");
            }
        }
    }

    if enviados > 0 {
        info!(
            enviados,
            transmisor = caep_tx.nombre(),
            "reconcile: eventos CAEP session-revoked emitidos"
        );
    }
    Ok(())
}
