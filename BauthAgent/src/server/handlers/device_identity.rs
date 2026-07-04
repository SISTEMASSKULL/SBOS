// ============================================================
// bauth::server::handlers::device_identity — B48.T63-T66
// Universal Identity Hub: device.register, device.attest,
// ctx.transfer, multi-device trust scoring
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── T63: Device Register ───────────────────────────────

pub struct DeviceRegisterHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for DeviceRegisterHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let category = params.get("device_category").and_then(|v| v.as_str()).unwrap_or("MOBILE");
        let authenticator = params.get("platform_authenticator").and_then(|v| v.as_str()).unwrap_or("FIDO2_PASSKEY");
        let public_key = params.get("public_key").and_then(|v| v.as_str()).unwrap_or("");
        let valid_cats = ["MOBILE","WATCH","RING","IMPLANT","CARD","WEARABLE","IOT","CHIP"];
        if !valid_cats.contains(&category) {
            return Err(JsonRpcError { code: -32602, message: format!("device_category inválida. Válidas: {:?}", valid_cats), data: None });
        }
        let device_id = uuid::Uuid::now_v7().to_string();
        let challenge = uuid::Uuid::now_v7().to_string();
        sqlx::query("INSERT INTO bauth.user_client_device (device_id, user_uuid, device_category, platform_authenticator, public_key_hash, trust_level, is_active) VALUES ($1::uuid,$2::uuid,$3,$4,encode(sha256($5::bytea),'hex'),50,true)")
            .bind(&device_id).bind(user).bind(category).bind(authenticator).bind(public_key).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        tracing::info!(%user, %device_id, category, "device.register");
        Ok(json!({"device_id": device_id, "challenge": challenge, "status": "REGISTERED", "trust_level": 50}))
    }
}
impl DeviceRegisterHandler { pub fn method_name() -> &'static str { "bauth.device.register" } }

// ── T64: Device Attest ─────────────────────────────────

pub struct DeviceAttestHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for DeviceAttestHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let device_id = params.get("device_id").and_then(|v| v.as_str()).ok_or_else(|| err("device_id requerido"))?;
        let attest_token = params.get("attestation_token").and_then(|v| v.as_str()).unwrap_or("");
        let platform = params.get("platform").and_then(|v| v.as_str()).unwrap_or("android");
        // Simular verificación de atestación
        let trust_score = if !attest_token.is_empty() { 85 } else { 30 };
        let status = if trust_score >= 60 { "TRUSTED" } else { "COMPROMISED" };
        sqlx::query("INSERT INTO bauth.device_attestation_log (device_id, attestation_provider, attestation_result, trust_score, checked_at, ctx_id) VALUES ($1::uuid,$2,$3,$4,now(),'system')")
            .bind(device_id).bind(platform).bind(status).bind(trust_score).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        sqlx::query("UPDATE bauth.user_client_device SET trust_level=$1 WHERE device_id=$2::uuid")
            .bind(trust_score).bind(device_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        if status == "COMPROMISED" {
            sqlx::query("UPDATE bauth.ses_context SET state='EXPIRED', invalidated_at=now() WHERE device_id=$1::uuid AND state='active'")
                .bind(device_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        }
        tracing::info!(%device_id, trust_score, status, "device.attest");
        Ok(json!({"device_id":device_id,"trust_score":trust_score,"status":status}))
    }
}
impl DeviceAttestHandler { pub fn method_name() -> &'static str { "bauth.device.attest" } }

// ── T65: Context Transfer ──────────────────────────────

pub struct CtxTransferHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for CtxTransferHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let from_device = params.get("from_device_id").and_then(|v| v.as_str()).ok_or_else(|| err("from_device_id requerido"))?;
        let to_device = params.get("to_device_id").and_then(|v| v.as_str()).ok_or_else(|| err("to_device_id requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).ok_or_else(|| err("ctx_id requerido"))?;
        let method = params.get("transfer_method").and_then(|v| v.as_str()).unwrap_or("QR");
        let valid_methods = ["QR","NFC","BLE","UWB","WIFI_AWARE"];
        if !valid_methods.contains(&method) {
            return Err(err(&format!("transfer_method inválido: {:?}", valid_methods)));
        }
        let transfer_id = uuid::Uuid::now_v7().to_string();
        sqlx::query("INSERT INTO bauth.ctx_transfer_log (transfer_id, ctx_id, from_device_id, to_device_id, transfer_method, status, created_at) VALUES ($1::uuid,$2,$3::uuid,$4::uuid,$5,'COMPLETED',now())")
            .bind(&transfer_id).bind(ctx_id).bind(from_device).bind(to_device).bind(method).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        tracing::info!(%ctx_id, %from_device, %to_device, method, "ctx.transfer");
        Ok(json!({"transfer_id":transfer_id,"ctx_id":ctx_id,"from_device":from_device,"to_device":to_device,"method":method,"status":"COMPLETED"}))
    }
}
impl CtxTransferHandler { pub fn method_name() -> &'static str { "bauth.ctx.transfer" } }

// ── T66: Multi-Device Trust Scoring ────────────────────

pub struct DeviceTrustScoreHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for DeviceTrustScoreHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let scores: Vec<(String,String,i32)> = sqlx::query_as(
            "SELECT device_id::text, device_category, trust_level FROM bauth.user_client_device WHERE user_uuid=$1::uuid AND is_active=true"
        ).bind(user).fetch_all(&self.pg).await.unwrap_or_default();
        let combined = if scores.is_empty() { 0.0 } else {
            scores.iter().map(|(_,cat,t)| {
                let weight = match cat.as_str() {
                    "MOBILE" => 0.25, "WATCH" => 0.15, "CARD" => 0.20,
                    "WEARABLE" => 0.15, "IOT" => 0.10, "RING" => 0.05,
                    "IMPLANT" => 0.05, "CHIP" => 0.05, _ => 0.0,
                };
                (*t as f64) * weight
            }).sum::<f64>() / scores.iter().map(|(_,_,_)| 1.0).sum::<f64>()
        };
        Ok(json!({"user_uuid":user,"devices":scores.into_iter().map(|(i,c,t)| json!({"device_id":i,"category":c,"trust":t})).collect::<Vec<_>>(),"combined_trust_score": (combined as i32).min(100)}))
    }
}
impl DeviceTrustScoreHandler { pub fn method_name() -> &'static str { "bauth.device.trust_score" } }

// ── Factory ────────────────────────────────────────────

pub fn all_device_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (DeviceRegisterHandler::method_name().into(), Arc::new(DeviceRegisterHandler { pg: pg.clone() })),
        (DeviceAttestHandler::method_name().into(), Arc::new(DeviceAttestHandler { pg: pg.clone() })),
        (CtxTransferHandler::method_name().into(), Arc::new(CtxTransferHandler { pg: pg.clone() })),
        (DeviceTrustScoreHandler::method_name().into(), Arc::new(DeviceTrustScoreHandler { pg: pg.clone() })),
    ]
}
