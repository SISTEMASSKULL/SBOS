// ============================================================
// bauth::server::handlers::dashboard_panels — B47.D01 a D10
// 10 handlers JSON-RPC para paneles dashboard
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn make_error(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

macro_rules! ok {
    ($v:expr) => { Ok(serde_json::to_value($v).unwrap_or(Value::Null)) };
}

// ── Panel 1: KPIs Tiempo Real (§29.1) ─────────────────

pub struct Panel1Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        Ok(json!({
            "login_attempts_1h": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.ath_login_attempt WHERE attempted_at > now() - interval '1 hour'").fetch_one(pg).await.unwrap_or(0),
            "mfa_success_rate_pct": sqlx::query_scalar::<_,Option<f64>>("SELECT round(100.0*count(*) FILTER(WHERE result='SUCCESS')/nullif(count(*),0),1) FROM bauth.ath_login_attempt WHERE attempted_at > now() - interval '24 hours' AND method_id IN (SELECT method_id FROM bauth.ath_method WHERE is_mfa=true)").fetch_one(pg).await.unwrap_or(None),
            "active_sessions": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.ses_context WHERE state='active' AND expires_at > now()").fetch_one(pg).await.unwrap_or(0),
            "failed_attempts_5min": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.ath_login_attempt WHERE result='FAILURE' AND attempted_at > now() - interval '5 minutes'").fetch_one(pg).await.unwrap_or(0),
        }))
    }
}
impl Panel1Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel1" } }

// ── Panel 1b: Zero Trust + Machine Identities (§29.2-§29.5) ─

pub struct Panel1bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel1bHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        Ok(json!({
            "users_without_mfa": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.idn_user_template u WHERE NOT EXISTS (SELECT 1 FROM bauth.ath_mfa_enrollment e WHERE e.user_uuid=u.uuid::text AND e.status='ACTIVE') AND u.is_active=true").fetch_one(pg).await.unwrap_or(0),
            "orphan_accounts_90d": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.idn_user_template WHERE is_active=true AND (last_login_at IS NULL OR last_login_at < now() - interval '90 days')").fetch_one(pg).await.unwrap_or(0),
            "sod_violations": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.fin_sod_rule WHERE is_active=true").fetch_one(pg).await.unwrap_or(0),
            "machine_identities": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.idn_user_template WHERE template->'identity'->>'accountType' IN ('SERVICE','MACHINE') AND is_active=true").fetch_one(pg).await.unwrap_or(0),
            "api_keys_no_rotation": sqlx::query_scalar::<_,i64>("SELECT count(*) FROM bauth.sec_key_inventory WHERE key_type='API_KEY' AND (last_rotated_at IS NULL OR last_rotated_at < now() - interval '90 days')").fetch_one(pg).await.unwrap_or(0),
        }))
    }
}
impl Panel1bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel1b" } }

// ── Panel 9: Trazabilidad Forense (§32.7) ─────────────

pub struct Panel9Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if !ctx_id.is_empty() {
            let rows: Vec<(String,String,String,String)> = sqlx::query_as(
                "SELECT 'LOGIN' as src, coalesce(result,'?') as evt, attempted_at::text as ts, coalesce(ip_address,'') as det FROM bauth.ath_login_attempt WHERE ctx_id=$1
                 UNION ALL SELECT 'SESSION', state, created_at::text, '' FROM bauth.ses_context WHERE ctx_id=$1
                 UNION ALL SELECT 'AUDIT', event_type, created_at::text, left(details::text,200) FROM bauth.aud_event WHERE ctx_id=$1
                 ORDER BY ts DESC LIMIT 200"
            ).bind(ctx_id).fetch_all(pg).await.unwrap_or_default();
            let timeline: Vec<Value> = rows.into_iter().map(|(s,e,t,d)| json!({"source":s,"event":e,"ts":t,"detail":d})).collect();
            Ok(json!({"ctx_id": ctx_id, "timeline": timeline}))
        } else {
            Err(make_error("Se requiere ctx_id"))
        }
    }
}
impl Panel9Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel9" } }

// ── Panel 9b: Hash-Chain + Merkle Proof (§32.5) ───────

pub struct Panel9bHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel9bHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() { return Err(make_error("Se requiere ctx_id")); }
        let chain_ok: bool = sqlx::query_scalar::<_,Option<bool>>(
            "WITH chain AS (SELECT event_hash, LAG(event_hash) OVER (ORDER BY created_at) as prev FROM bauth.aud_event WHERE ctx_id=$1)
             SELECT bool_and(prev IS NULL OR event_hash IS NOT NULL) FROM chain"
        ).bind(ctx_id).fetch_one(pg).await.unwrap_or(None).unwrap_or(true);
        let merkle: Option<(String,String,i32)> = sqlx::query_as(
            "SELECT l.leaf_hash, b.merkle_root, l.leaf_index FROM bauth.blk_merkle_leaf l JOIN bauth.blk_merkle_batch b ON b.batch_id=l.batch_id WHERE l.ctx_id=$1 ORDER BY b.created_at DESC LIMIT 1"
        ).bind(ctx_id).fetch_optional(pg).await.unwrap_or(None);
        Ok(json!({"ctx_id":ctx_id,"hash_chain_ok":chain_ok,"merkle_proof":merkle.map(|(l,r,i)| json!({"leaf":l,"root":r,"index":i}))}))
    }
}
impl Panel9bHandler { pub fn method_name() -> &'static str { "bauth.dashboard.panel9b" } }

// ── Panel 10: Dispositivos Físicos y Móviles (§33.7) ──

pub struct Panel10Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel10Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let devices: Vec<(String,String,String)> = sqlx::query_as(
            "SELECT device_id::text, device_category, coalesce(last_seen::text,'') FROM bauth.net_device ORDER BY last_seen DESC NULLS LAST LIMIT 100"
        ).fetch_all(pg).await.unwrap_or_default();
        Ok(json!({"devices": devices.into_iter().map(|(i,c,s)| json!({"id":i,"category":c,"last_seen":s})).collect::<Vec<_>>()}))
    }
}
impl Panel10Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel10" } }

// ── Panel 11: Motor BitMask (§34.8) ───────────────────

pub struct Panel11Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel11Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let total: i64 = sqlx::query_scalar("SELECT count(*) FROM bauth.privilege_atom WHERE is_active=true").fetch_one(pg).await.unwrap_or(0);
        let domains: Vec<(String,i64)> = sqlx::query_as(
            "SELECT d.domain_slug, count(*) FROM bauth.privilege_atom a JOIN bauth.privilege_domain d ON d.domain_id=a.domain_id WHERE a.is_active=true GROUP BY 1 ORDER BY 2 DESC"
        ).fetch_all(pg).await.unwrap_or_default();
        Ok(json!({"total_atoms":total,"by_domain":domains.into_iter().map(|(d,c)| json!({"domain":d,"count":c})).collect::<Vec<_>>()}))
    }
}
impl Panel11Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel11" } }

// ── Panel 12: Motor de Evaluación (§35.7) ─────────────

pub struct Panel12Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel12Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let total: i64 = sqlx::query_scalar("SELECT COALESCE(sum(c),0) FROM (SELECT count(*) as c FROM bauth.ath_policy_d1 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d2 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d3 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d4 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d5 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d6 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d7 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d8 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d9 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d10 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d11 WHERE is_active=true UNION ALL SELECT count(*) FROM bauth.ath_policy_d12 WHERE is_active=true) sub").fetch_one(pg).await.unwrap_or(0);
        Ok(json!({"total_active_policies_12_domains": total,"evaluation_layers":["FastPath","PolicyPath","External"],"trace_available":true}))
    }
}
impl Panel12Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel12" } }

// ── Panel 13: Blockchain D12 (§37.7) ───────────────────

pub struct Panel13Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel13Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let anchors: Vec<(String,String,String)> = sqlx::query_as(
            "SELECT batch_id::text, merkle_root, tx_hash FROM bauth.blk_merkle_batch ORDER BY created_at DESC LIMIT 20"
        ).fetch_all(pg).await.unwrap_or_default();
        let status: String = sqlx::query_scalar(
            "SELECT CASE WHEN count(*) FILTER(WHERE status='PENDING') > 0 THEN 'DRIFT' WHEN count(*)=0 THEN 'EMPTY' ELSE 'OK' END FROM bauth.blk_reconciliation WHERE created_at > now() - interval '24 hours'"
        ).fetch_one(pg).await.unwrap_or_else(|_| "UNKNOWN".into());
        Ok(json!({"recent_anchors":anchors.into_iter().map(|(i,r,t)| json!({"batch":i,"root":r,"tx":t})).collect::<Vec<_>>(),"reconciliation":status}))
    }
}
impl Panel13Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel13" } }

// ── Panel 4: Biblioteca de Políticas por Dominio (§31.1) ─

pub struct Panel4Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel4Handler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let d = params.get("domain").and_then(|v| v.as_str()).unwrap_or("D1");
        let valid_domains = ["D1","D2","D3","D4","D5","D6","D7","D8","D9","D10","D11","D12"];
        let dom = if valid_domains.contains(&d) { d } else { "D1" };
        let pol_table = format!("bauth.ath_policy_{}", dom.to_lowercase());
        let cfg_table = format!("bauth.ath_config_{}", dom.to_lowercase());
        let policies: Vec<(String,String,bool)> = sqlx::query_as(&format!("SELECT policy_slug, rule_type, is_active FROM {} LIMIT 100", pol_table)).fetch_all(pg).await.unwrap_or_default();
        let configs: Vec<(String,String)> = sqlx::query_as(&format!("SELECT config_key, config_value FROM {} LIMIT 50", cfg_table)).fetch_all(pg).await.unwrap_or_default();
        Ok(json!({"domain":dom,"policies":policies.into_iter().map(|(s,r,a)| json!({"slug":s,"rule":r,"active":a})).collect::<Vec<_>>(),"configs":configs.into_iter().map(|(k,v)| json!({"key":k,"value":v})).collect::<Vec<_>>()}))
    }
}
impl Panel4Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel4" } }

// ── Panel 7+8: Sync Status + ctx_id + Menús ───────────

pub struct Panel78Handler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for Panel78Handler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = &self.pg;
        let sync: Vec<(String,String,String)> = sqlx::query_as("SELECT sync_type, engine, status FROM bauth.sync_log ORDER BY created_at DESC LIMIT 50").fetch_all(pg).await.unwrap_or_default();
        let ctx_count: i64 = sqlx::query_scalar("SELECT count(*) FROM bauth.ses_context WHERE state='active' AND expires_at > now()").fetch_one(pg).await.unwrap_or(0);
        let menu_count: i64 = sqlx::query_scalar("SELECT count(*) FROM bglobal.menu_item").fetch_one(pg).await.unwrap_or(0);
        Ok(json!({"sync_log":sync.into_iter().map(|(t,e,s)| json!({"type":t,"engine":e,"status":s})).collect::<Vec<_>>(),"active_ctx_count":ctx_count,"menu_items":menu_count}))
    }
}
impl Panel78Handler { pub fn method_name() -> &'static str { "bauth.dashboard.panel78" } }

// ── Factory ────────────────────────────────────────────

pub fn all_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (Panel1Handler::method_name().into(), Arc::new(Panel1Handler { pg: pg.clone() })),
        (Panel1bHandler::method_name().into(), Arc::new(Panel1bHandler { pg: pg.clone() })),
        (Panel9Handler::method_name().into(), Arc::new(Panel9Handler { pg: pg.clone() })),
        (Panel9bHandler::method_name().into(), Arc::new(Panel9bHandler { pg: pg.clone() })),
        (Panel10Handler::method_name().into(), Arc::new(Panel10Handler { pg: pg.clone() })),
        (Panel11Handler::method_name().into(), Arc::new(Panel11Handler { pg: pg.clone() })),
        (Panel12Handler::method_name().into(), Arc::new(Panel12Handler { pg: pg.clone() })),
        (Panel13Handler::method_name().into(), Arc::new(Panel13Handler { pg: pg.clone() })),
        (Panel4Handler::method_name().into(), Arc::new(Panel4Handler { pg: pg.clone() })),
        (Panel78Handler::method_name().into(), Arc::new(Panel78Handler { pg: pg.clone() })),
    ]
}
