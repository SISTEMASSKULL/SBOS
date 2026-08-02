// ============================================================
// bauth::server::handlers::dashboard_panels — B47.D01 a D13
//
// Tablas canónicas DDL v2.12.0 usadas:
//
//   auth_attempt_log      — intentos de autenticación (WORM, particionada por attempted_at)
//     outcome CHECK: 'SUCCESS','FAILURE','LOCKED','STEP_UP_REQUIRED','EXPIRED','INVALID_USER','REVOKED_CREDENTIAL'
//     timestamp: attempted_at (NO created_at)
//
//   ses_caep_event_log    — eventos CAEP externos (session-revoked, credential-change, etc.)
//     event_type CHECK: 'session-revoked','token-claims-change','credential-change',
//                       'assurance-level-change','device-compliance-change','risk-level-change'
//     timestamp: received_at (NO created_at)
//     processing_status CHECK: 'RECEIVED','PROCESSING','APPLIED','FAILED','IGNORED'
//
//   ses_session_log       — sesiones activas
//   auth_credential       — credenciales MFA enrolladas
//   idn_user              — cuentas de login (NO tiene columna metadata)
//   idn_identity_attribute — atributos EAV (attr_namespace, attr_key, attr_value JSONB)
//   idn_financial_sod_rule — reglas SoD financiero (status CHECK: 'ACTIVE','DISABLED')
//   idn_roles_template    — átomos/dominios BitMask
//   auth_policy           — políticas unificadas (active BOOLEAN, created_at solo — sin updated_at)
//   cfg_policy_library    — biblioteca de políticas por dominio
//   auth_device           — dispositivos ZTA (category, last_seen_at — NO device_category/last_seen)
//   idn_audit_event_log   — auditoría WORM hash-chain (hash_actual, prev_hash, logged_at)
//   blk_merkle_batch      — lotes Merkle (created_at, status: OPEN/CLOSED/COMPUTING/ANCHORED/FAILED)
//   blk_anchor            — anclajes blockchain con tx_hash (NO en blk_merkle_batch)
//   blk_merkle_leaf       — hojas del árbol (event_id — NO ctx_id)
//   blk_reconciliation    — conciliación on-chain (verified_at — NO created_at;
//                           status CHECK: 'OK','DISCREPANCY','CORRECTED' — NO 'PENDING')
//
// Phantoms eliminados: net_device, bauth_44, sec_key_inventory, fin_sod_rule (legado)
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
// Métricas de autenticación en tiempo real.
// FUENTE: auth_attempt_log (no ses_caep_event_log — CAEP es para eventos externos).

pub struct Panel1Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Total intentos en la última hora (SUCCESS + FAILURE + LOCKED...)
        let login_attempts_1h: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_attempt_log
             WHERE attempted_at > now() - interval '1 hour'"
        ).fetch_one(pg).await.unwrap_or(0);

        // Tasa de éxito MFA en últimas 24h
        // MFA = cualquier método que no sea PASSWORD (TOTP, WEBAUTHN, etc.)
        let mfa_success_rate: Option<f64> = sqlx::query_scalar(
            "SELECT round(
                100.0 * count(*) FILTER (WHERE outcome = 'SUCCESS')
                / nullif(count(*), 0)
             , 1)
             FROM bauth.auth_attempt_log
             WHERE method_code <> 'PASSWORD'
               AND attempted_at > now() - interval '24 hours'"
        ).fetch_one(pg).await.unwrap_or(None);

        // Sesiones activas (ses_session_log — correcto para esta métrica)
        let active_sessions: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.ses_session_log
             WHERE terminated_at IS NULL"
        ).fetch_one(pg).await.unwrap_or(0);

        // Fallos en últimos 5 minutos
        let failed_5min: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_attempt_log
             WHERE outcome = 'FAILURE'
               AND attempted_at > now() - interval '5 minutes'"
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

// ── Panel 1b: Zero Trust + Identidades Máquina (§29.2-§29.5) ─
// idn_user NO tiene columna metadata.
// account_type se almacena en idn_identity_attribute (attr_key='account_type').
// idn_financial_sod_rule.status CHECK: 'ACTIVE','DISABLED' (no is_active boolean).
// sec_key_inventory NO existe en DDL v2.12.0 — se aproxima con auth_credential.

pub struct Panel1bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1bHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Usuarios activos sin credencial MFA enrollada
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

        // Cuentas sin sesión en los últimos 90 días (posible privilege creep)
        let orphan_accounts_90d: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_user u
             WHERE u.status = 'ACTIVE'
               AND NOT EXISTS (
                   SELECT 1 FROM bauth.ses_session_log s
                   WHERE s.user_id = u.user_id
                     AND s.started_at > now() - interval '90 days'
               )"
        ).fetch_one(pg).await.unwrap_or(0);

        // Reglas SoD financieras activas (idn_financial_sod_rule — status='ACTIVE')
        let sod_active_rules: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_financial_sod_rule WHERE status = 'ACTIVE'"
        ).fetch_one(pg).await.unwrap_or(0);

        // Identidades máquina/servicio: entidades con attr_key='account_type' y valor M2M/SERVICE
        // idn_user no tiene metadata — el account_type vive en idn_identity_attribute (EAV)
        let machine_identities: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.idn_user u
             JOIN bauth.idn_identity_attribute ia
               ON ia.entity_id = u.entity_id
              AND ia.attr_key = 'account_type'
              AND ia.attr_value #>> '{}' IN ('SERVICE','MACHINE','M2M')
              AND ia.is_active = true
             WHERE u.status = 'ACTIVE'"
        ).fetch_one(pg).await.unwrap_or(0);

        // Credenciales activas sin uso en más de 90 días (aproximación — sec_key_inventory no existe)
        // Representa credenciales candidatas a rotación / revocación
        let credentials_stale_90d: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_credential
             WHERE status = 'ACTIVE'
               AND (last_used_at IS NULL OR last_used_at < now() - interval '90 days')"
        ).fetch_one(pg).await.unwrap_or(0);

        Ok(json!({
            "users_without_mfa":      users_without_mfa,
            "orphan_accounts_90d":    orphan_accounts_90d,
            "sod_active_rules":       sod_active_rules,
            "machine_identities":     machine_identities,
            "credentials_stale_90d":  credentials_stale_90d,
        }))
    }
}
impl Panel1bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel1b" } }

// ── Panel 9: Trazabilidad Forense (§32.7) ─────────────────
// Timeline por ctx_id combinando ses_caep_event_log y ses_session_log.
// ses_caep_event_log usa received_at (NO created_at).

pub struct Panel9Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() { return Err(make_error("Se requiere ctx_id")); }

        // Combina eventos CAEP (received_at) y sesiones para el ctx_id dado
        let events: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT 'CAEP'::text as src,
                    event_type as evt,
                    received_at::text as ts,
                    left(event_payload::text, 200) as det
             FROM bauth.ses_caep_event_log
             WHERE ctx_id = $1
             UNION ALL
             SELECT 'SESSION'::text,
                    auth_method,
                    started_at::text,
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
// Tabla canónica WORM: idn_audit_event_log (NO bauth_44 — phantom eliminado).
// Columnas hash: hash_actual (calculado por trigger), prev_hash (hash del evento anterior).
// Columna timestamp: logged_at (NO created_at).
// blk_merkle_leaf NO tiene ctx_id — se vincula por event_id = idn_audit_event_log.id.

pub struct Panel9bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9bHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() { return Err(make_error("Se requiere ctx_id")); }

        // Verificar integridad de cadena hash en idn_audit_event_log.
        // Cada fila debe tener prev_hash == hash_actual de la fila anterior (ORDER BY logged_at).
        let chain_ok: bool = sqlx::query_scalar::<_, Option<bool>>(
            "WITH chain AS (
                SELECT hash_actual,
                       prev_hash,
                       LAG(hash_actual) OVER (ORDER BY logged_at) AS expected_prev
                FROM bauth.idn_audit_event_log
                WHERE ctx_id = $1
             )
             SELECT bool_and(
                 prev_hash IS NULL
                 OR prev_hash = expected_prev
             ) FROM chain"
        )
        .bind(ctx_id)
        .fetch_one(pg)
        .await
        .unwrap_or(None)
        .unwrap_or(true);

        // Merkle proof: blk_merkle_leaf se vincula a idn_audit_event_log.id (event_id).
        // No tiene columna ctx_id — la búsqueda va a través de la tabla de auditoría.
        let merkle: Option<(String, Option<String>, i32)> = sqlx::query_as(
            "SELECT l.leaf_hash, b.merkle_root, l.leaf_index
             FROM bauth.idn_audit_event_log a
             JOIN bauth.blk_merkle_leaf l ON l.event_id = a.id
             JOIN bauth.blk_merkle_batch b ON b.batch_id = l.batch_id
             WHERE a.ctx_id = $1
             ORDER BY b.created_at DESC LIMIT 1"
        )
        .bind(ctx_id)
        .fetch_optional(pg)
        .await
        .unwrap_or(None);

        Ok(json!({
            "ctx_id":        ctx_id,
            "hash_chain_ok": chain_ok,
            "merkle_proof":  merkle.map(|(leaf, root, idx)| json!({
                "leaf_hash":   leaf,
                "merkle_root": root,
                "leaf_index":  idx,
            })),
        }))
    }
}
impl Panel9bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel9b" } }

// ── Panel 10: Dispositivos Físicos y Móviles (§33.7) ──────
// Tabla canónica: auth_device (NO net_device — phantom eliminado).
// Columnas correctas: category (NO device_category), last_seen_at (NO last_seen).

pub struct Panel10Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel10Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let devices: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT device_id::text,
                    category,
                    trust_level,
                    coalesce(last_seen_at::text, registered_at::text)
             FROM bauth.auth_device
             WHERE status = 'ACTIVE'
             ORDER BY last_seen_at DESC NULLS LAST LIMIT 100"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        let total: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_device WHERE status = 'ACTIVE'"
        ).fetch_one(pg).await.unwrap_or(0);

        // Dispositivos en cuarentena (riesgo ZTA)
        let quarantine_count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM bauth.auth_device WHERE trust_level = 'QUARANTINE' AND status != 'DECOMMISSIONED'"
        ).fetch_one(pg).await.unwrap_or(0);

        Ok(json!({
            "total_active": total,
            "quarantine":   quarantine_count,
            "devices": devices.into_iter().map(|(id, cat, trust, seen)| {
                json!({"id": id, "category": cat, "trust_level": trust, "last_seen_at": seen})
            }).collect::<Vec<_>>()
        }))
    }
}
impl Panel10Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel10" } }

// ── Panel 11: Motor BitMask (§34.8) ───────────────────────
// domain_number solo está en nodos tipo='domain'.
// Para contar átomos por dominio se necesita JOIN con el nodo padre dominio.

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

        // Átomos por dominio: JOIN del átomo con su nodo dominio ancestral
        // (domain_number solo existe en node_type='domain', no en 'atom')
        let by_domain: Vec<(Option<i32>, i64)> = sqlx::query_as(
            "SELECT d.domain_number, count(a.id) as c
             FROM bauth.idn_roles_template d
             JOIN bauth.idn_roles_template a
               ON a.path LIKE d.path || '.%'
              AND a.node_type = 'atom'
              AND a.is_active = TRUE
             WHERE d.node_type = 'domain'
             GROUP BY d.domain_number
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
// auth_policy tiene: active BOOLEAN, loa_required, created_at (NO updated_at).

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
            "by_loa": by_loa.into_iter().map(|(l, c)| json!({"loa": l, "count": c})).collect::<Vec<_>>(),
            "evaluation_layers": ["FastPath", "PolicyPath", "External"],
            "trace_available":   true,
        }))
    }
}
impl Panel12Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel12" } }

// ── Panel 13: Blockchain D12 (§37.7) ──────────────────────
// tx_hash vive en blk_anchor (NO en blk_merkle_batch).
// blk_reconciliation usa verified_at (NO created_at).
// blk_reconciliation.status CHECK: 'OK','DISCREPANCY','CORRECTED' (NO 'PENDING').
// DRIFT = tiene filas con status='DISCREPANCY' en últimas 24h.

pub struct Panel13Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel13Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        // Batches recientes con su anclaje (tx_hash en blk_anchor, no en blk_merkle_batch)
        let anchors: Vec<(String, Option<String>, String, Option<String>)> = sqlx::query_as(
            "SELECT b.batch_id::text, b.merkle_root, b.status, a.tx_hash
             FROM bauth.blk_merkle_batch b
             LEFT JOIN bauth.blk_anchor a
               ON a.batch_id = b.batch_id
              AND a.status = 'ANCHORED'
             ORDER BY b.created_at DESC LIMIT 20"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

        // Estado de reconciliación (verified_at — no created_at; status 'PENDING' no existe)
        let status: String = sqlx::query_scalar(
            "SELECT CASE
                WHEN count(*) FILTER (WHERE status = 'DISCREPANCY') > 0 THEN 'DRIFT'
                WHEN count(*) = 0 THEN 'EMPTY'
                ELSE 'OK'
             END
             FROM bauth.blk_reconciliation
             WHERE verified_at > now() - interval '24 hours'"
        )
        .fetch_one(pg)
        .await
        .unwrap_or_else(|_| "UNKNOWN".into());

        Ok(json!({
            "recent_anchors": anchors.into_iter().map(|(id, root, st, tx)| {
                json!({"batch": id, "root": root, "status": st, "tx_hash": tx})
            }).collect::<Vec<_>>(),
            "reconciliation": status,
        }))
    }
}
impl Panel13Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel13" } }

// ── Panel 4: Biblioteca de Políticas por Dominio (§31.1) ──

pub struct Panel4Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel4Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

        let d_raw = params.get("domain").and_then(|v| v.as_str()).unwrap_or("D1");
        let domain_num: i32 = d_raw.trim_start_matches('D').parse().unwrap_or(1);

        let policies: Vec<(uuid::Uuid, String, String)> = sqlx::query_as(
            "SELECT policy_id, name, loa_required
             FROM bauth.auth_policy
             WHERE active = TRUE
             ORDER BY name LIMIT 100"
        )
        .fetch_all(pg)
        .await
        .unwrap_or_default();

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

// ── Panel 7+8: Estado de Sesiones + Menús ─────────────────

pub struct Panel78Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel78Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;

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
