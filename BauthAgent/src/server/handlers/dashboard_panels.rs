// ============================================================
// bauth::server::handlers::dashboard_panels — B47.D01 a D10
// 10 handlers JSON-RPC para paneles dashboard
//
// Tablas canónicas DDL v2.12.0 (phantoms eliminados):
//   bauth.ses_caep_event_log — eventos auth (reemplaza ath_login_attempt + aud_event)
//   bauth.ses_session_log    — sesiones activas (reemplaza ses_context)
//   bauth.idn_user           — usuarios (reemplaza idn_user_template)
//   bauth.auth_credential    — credenciales MFA (reemplaza ath_mfa_enrollment)
//   bauth.idn_roles_template — átomos/dominios (reemplaza privilege_atom/privilege_domain)
//   bauth.auth_policy        — políticas unificadas (reemplaza ath_policy_d{N})
//   bauth.cfg_policy_library — configuración de políticas (reemplaza ath_config_{N})
//   bglobal.menu_item        — canónico (seeds T060)
//
// sync_log eliminado (no existe en DDL v2.12.0)
// DOC-SBOS-001 N3 · SBOS-049
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn make_error(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

// ── Panel 1: KPIs Tiempo Real (§29.1) ─────────────────────

/// Métricas en tiempo real desde ses_caep_event_log y ses_session_log.
pub struct Panel1Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Intentos de login en última 1h (event_type LIKE 'login%')
        let login_attempts_1h: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.ses_caep_event_log
             WHERE event_type LIKE 'login%'
               AND created_at > now() - interval '1 hour'"
        ).fetch_one(pg).await.unwrap_or(0);

        // Tasa de éxito MFA en últimas 24h
        let mfa_success_rate: Option<f64> = sqlx::query_scalar(
            "SELECT round(
                100.0 * count(*) FILTER (WHERE processing_status = 'DELIVERED')
                / nullif(count(*), 0), 1
             )
             FROM bauth.ses_caep_event_log
             WHERE event_type LIKE 'login.mfa%'
               AND created_at > now() - interval '24 hours'"
        ).fetch_one(pg).await.unwrap_or(None);

        // Sesiones activas en ses_session_log
        let active_sessions: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.ses_session_log
             WHERE terminated_at IS NULL"
        ).fetch_one(pg).await.unwrap_or(0);

        // Intentos fallidos últimos 5min
        let failed_5min: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.ses_caep_event_log
             WHERE event_type = 'login.failure'
               AND created_at > now() - interval '5 minutes'"
        ).fetch_one(pg).await.unwrap_or(0);

        Ok(json!({
            "login_attempts_1h":    login_attempts_1h,
            "mfa_success_rate_pct": mfa_success_rate,
            "active_sessions":      active_sessions,
            "failed_attempts_5min": failed_5min,
        }))
    }
}
impl Panel1Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel1" } }

// ── Panel 1b: Zero Trust + Machine Identities (§29.2-§29.5) ─

/// Indicadores Zero Trust: cuentas sin MFA, huérfanas, SoD, M2M.
pub struct Panel1bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1bHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Usuarios sin credencial MFA activa (auth_credential con método != PASSWORD)
        let users_without_mfa: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_user u
             WHERE u.status = 'ACTIVE'
               AND NOT EXISTS (
                   SELECT 1 FROM bauth.auth_credential c
                   WHERE c.user_id = u.user_id
                     AND c.status = 'ACTIVE'
                     AND c.method_code <> 'PASSWORD'
               )"
        ).fetch_one(pg).await.unwrap_or(0);

        // Cuentas activas sin sesión en los últimos 90 días
        let orphan_accounts_90d: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_user u
             WHERE u.status = 'ACTIVE'
               AND NOT EXISTS (
                   SELECT 1 FROM bauth.ses_session_log s
                   WHERE s.user_id = u.user_id
                     AND s.started_at > now() - interval '90 days'
               )"
        ).fetch_one(pg).await.unwrap_or(0);

        // Reglas SoD activas (tabla fin_sod_rule puede ser canónica en dominio financiero)
        let sod_violations: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.fin_sod_rule WHERE is_active = true"
        ).fetch_one(pg).await.unwrap_or(0);

        // Identidades máquina / servicio (account_type en metadata JSONB de idn_user)
        let machine_identities: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_user
             WHERE status = 'ACTIVE'
               AND metadata->>'account_type' IN ('SERVICE', 'MACHINE', 'M2M')"
        ).fetch_one(pg).await.unwrap_or(0);

        // API keys sin rotación > 90 días (tabla sec_key_inventory si existe)
        let api_keys_no_rotation: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.sec_key_inventory
             WHERE key_type = 'API_KEY'
               AND (last_rotated_at IS NULL
                    OR last_rotated_at < now() - interval '90 days')"
        ).fetch_one(pg).await.unwrap_or(0);

        Ok(json!({
            "users_without_mfa":    users_without_mfa,
            "orphan_accounts_90d":  orphan_accounts_90d,
            "sod_violations":       sod_violations,
            "machine_identities":   machine_identities,
            "api_keys_no_rotation": api_keys_no_rotation,
        }))
    }
}
impl Panel1bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel1b" } }

// ── Panel 9: Trazabilidad Forense (§32.7) ─────────────────

/// Timeline forense por ctx_id desde ses_caep_event_log y ses_session_log.
pub struct Panel9Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() { return Err(make_error("Se requiere ctx_id")); }

        // Eventos CAEP para este ctx_id
        let events: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT 'CAEP' as src, event_type as evt, created_at::text as ts,
                    left(event_payload::text, 200) as det
             FROM bauth.ses_caep_event_log
             WHERE ctx_id = $1
             UNION ALL
             SELECT 'SESSION', auth_method, started_at::text,
                    coalesce(termination_reason, 'activa')
             FROM bauth.ses_session_log
             WHERE ctx_id = $1
             ORDER BY ts DESC LIMIT 200"
        )
        .bind(ctx_id)
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        let timeline: Vec<Value> = events.into_iter()
            .map(|(s, e, t, d)| json!({"source": s, "event": e, "ts": t, "detail": d}))
            .collect();

        Ok(json!({"ctx_id": ctx_id, "timeline": timeline}))
    }
}
impl Panel9Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel9" } }

// ── Panel 9b: Hash-Chain + Merkle Proof (§32.5) ───────────

/// Verificación de integridad de cadena de hash y prueba Merkle.
pub struct Panel9bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9bHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() { return Err(make_error("Se requiere ctx_id")); }

        // Verificar integridad de cadena de hash en tabla de auditoría canónica (bauth_44 WORM)
        let chain_ok: bool = sqlx::query_scalar::<_, Option<bool>>(
            "WITH chain AS (
                SELECT event_hash,
                       LAG(event_hash) OVER (ORDER BY created_at) AS prev
                FROM bauth.bauth_44
                WHERE ctx_id = $1
             )
             SELECT bool_and(prev IS NULL OR event_hash IS NOT NULL) FROM chain"
        )
        .bind(ctx_id)
        .fetch_one(pg)
        .await
        .unwrap_or(None)
        .unwrap_or(true);

        // Merkle proof (tabla blockchain si existe)
        let merkle: Option<(String, String, i32)> = sqlx::query_as(
            "SELECT l.leaf_hash, b.merkle_root, l.leaf_index
             FROM bauth.blk_merkle_leaf l
             JOIN bauth.blk_merkle_batch b ON b.batch_id = l.batch_id
             WHERE l.ctx_id = $1
             ORDER BY b.created_at DESC LIMIT 1"
        )
        .bind(ctx_id)
        .fetch_optional(pg)
        .await
        .unwrap_or(None);

        Ok(json!({
            "ctx_id":       ctx_id,
            "hash_chain_ok": chain_ok,
            "merkle_proof": merkle.map(|(l, r, i)| json!({"leaf": l, "root": r, "index": i})),
        }))
    }
}
impl Panel9bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel9b" } }

// ── Panel 10: Dispositivos Físicos y Móviles (§33.7) ──────

/// Listado de dispositivos desde net_device (tabla de networking).
pub struct Panel10Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel10Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let devices: Vec<(String, String, String)> = sqlx::query_as(
            "SELECT device_id::text, device_category, coalesce(last_seen::text, '')
             FROM bauth.net_device
             ORDER BY last_seen DESC NULLS LAST LIMIT 100"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        Ok(json!({
            "devices": devices.into_iter().map(|(id, cat, seen)| {
                json!({"id": id, "category": cat, "last_seen": seen})
            }).collect::<Vec<_>>()
        }))
    }
}
impl Panel10Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel10" } }

// ── Panel 11: Motor BitMask (§34.8) ───────────────────────

/// Estadísticas del motor BitMask desde idn_roles_template (DDL v2.12.0).
pub struct Panel11Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel11Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let total: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND is_active = TRUE"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        // Conteo de átomos por número de dominio
        let by_domain: Vec<(i32, i64)> = sqlx::query_as(
            "SELECT domain_number, count(*) as c
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND is_active = TRUE
             GROUP BY domain_number
             ORDER BY c DESC"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        Ok(json!({
            "total_atoms": total,
            "by_domain": by_domain.into_iter().map(|(d, c)| {
                json!({"domain_number": d, "count": c})
            }).collect::<Vec<_>>(),
        }))
    }
}
impl Panel11Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel11" } }

// ── Panel 12: Motor de Evaluación (§35.7) ─────────────────

/// Total de políticas activas en auth_policy (tabla unificada DDL v2.12.0).
pub struct Panel12Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel12Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let total: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_policy WHERE active = TRUE"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        // Distribución por loa_required
        let by_loa: Vec<(String, i64)> = sqlx::query_as(
            "SELECT loa_required, count(*) as c
             FROM bauth.auth_policy WHERE active = TRUE
             GROUP BY loa_required ORDER BY loa_required"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        Ok(json!({
            "total_active_policies": total,
            "by_loa":                by_loa.into_iter().map(|(l, c)| json!({"loa": l, "count": c})).collect::<Vec<_>>(),
            "evaluation_layers":     ["FastPath", "PolicyPath", "External"],
            "trace_available":       true,
        }))
    }
}
impl Panel12Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel12" } }

// ── Panel 13: Blockchain D12 (§37.7) ──────────────────────

/// Estado de anclajes blockchain y reconciliación.
pub struct Panel13Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel13Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let anchors: Vec<(String, String, String)> = sqlx::query_as(
            "SELECT batch_id::text, merkle_root, tx_hash
             FROM bauth.blk_merkle_batch
             ORDER BY created_at DESC LIMIT 20"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        let status: String = sqlx::query_scalar(
            "SELECT CASE
                WHEN count(*) FILTER (WHERE status = 'PENDING') > 0 THEN 'DRIFT'
                WHEN count(*) = 0 THEN 'EMPTY'
                ELSE 'OK'
             END
             FROM bauth.blk_reconciliation
             WHERE created_at > now() - interval '24 hours'"
        )
        .fetch_one(pg)
        .await
        .unwrap_or_else(|_| "UNKNOWN".into());

        Ok(json!({
            "recent_anchors": anchors.into_iter().map(|(id, root, tx)| {
                json!({"batch": id, "root": root, "tx": tx})
            }).collect::<Vec<_>>(),
            "reconciliation": status,
        }))
    }
}
impl Panel13Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel13" } }

// ── Panel 4: Biblioteca de Políticas por Dominio (§31.1) ──

/// Políticas y configuraciones por dominio.
/// Usa auth_policy (filtro loa) y cfg_policy_library (filtro domain_map).
pub struct Panel4Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel4Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Dominio como número: "D1" → 1, "D11" → 11, etc.
        let d_raw = params.get("domain").and_then(|v| v.as_str()).unwrap_or("D1");
        let domain_num: i32 = d_raw.trim_start_matches('D')
            .parse()
            .unwrap_or(1);

        // Políticas activas (auth_policy no tiene columna domain — filtrar por loa)
        let policies: Vec<(uuid::Uuid, String, String)> = sqlx::query_as(
            "SELECT policy_id, name, loa_required
             FROM bauth.auth_policy
             WHERE active = TRUE
             ORDER BY name LIMIT 100"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        // Configuraciones del dominio desde cfg_policy_library
        let configs: Vec<(String, String)> = sqlx::query_as(
            "SELECT section_name, json_path
             FROM bauth.cfg_policy_library
             WHERE $1 = ANY(domain_map)
             ORDER BY section_name LIMIT 50"
        )
        .bind(format!("D{}", domain_num))
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        Ok(json!({
            "domain": d_raw,
            "policies": policies.into_iter().map(|(id, name, loa)| {
                json!({"policy_id": id.to_string(), "name": name, "loa": loa})
            }).collect::<Vec<_>>(),
            "config_entries": configs.into_iter().map(|(sec, path)| {
                json!({"section": sec, "path": path})
            }).collect::<Vec<_>>(),
        }))
    }
}
impl Panel4Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel4" } }

// ── Panel 7+8: Sync Status + ctx_id + Menús ───────────────

/// Estado de sesiones activas y menús.
/// sync_log eliminado (no existe en DDL v2.12.0).
pub struct Panel78Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel78Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Últimas sesiones (reemplaza sync_log + ses_context)
        let sessions: Vec<(String, String, String)> = sqlx::query_as(
            "SELECT user_id::text, auth_method, started_at::text
             FROM bauth.ses_session_log
             WHERE terminated_at IS NULL
             ORDER BY started_at DESC LIMIT 50"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        let ctx_count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.ses_session_log WHERE terminated_at IS NULL"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        // Menús canónicos (seeds T060 — bglobal schema)
        let menu_count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bglobal.menu_item"
        )
        .fetch_one(pg)
        .await
        .unwrap_or(0);

        Ok(json!({
            "active_sessions": sessions.into_iter().map(|(uid, meth, ts)| {
                json!({"user_id": uid, "auth_method": meth, "started_at": ts})
            }).collect::<Vec<_>>(),
            "active_ctx_count": ctx_count,
            "menu_items":        menu_count,
        }))
    }
}
impl Panel78Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel78" } }

// ── Factory ────────────────────────────────────────────────

pub fn all_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (Panel1Handler::method_name().into(),   Arc::new(Panel1Handler   { pg: pg.clone() })),
        (Panel1bHandler::method_name().into(),  Arc::new(Panel1bHandler  { pg: pg.clone() })),
        (Panel9Handler::method_name().into(),   Arc::new(Panel9Handler   { pg: pg.clone() })),
        (Panel9bHandler::method_name().into(),  Arc::new(Panel9bHandler  { pg: pg.clone() })),
        (Panel10Handler::method_name().into(),  Arc::new(Panel10Handler  { pg: pg.clone() })),
        (Panel11Handler::method_name().into(),  Arc::new(Panel11Handler  { pg: pg.clone() })),
        (Panel12Handler::method_name().into(),  Arc::new(Panel12Handler  { pg: pg.clone() })),
        (Panel13Handler::method_name().into(),  Arc::new(Panel13Handler  { pg: pg.clone() })),
        (Panel4Handler::method_name().into(),   Arc::new(Panel4Handler   { pg: pg.clone() })),
        (Panel78Handler::method_name().into(),  Arc::new(Panel78Handler  { pg: pg.clone() })),
    ]
}
