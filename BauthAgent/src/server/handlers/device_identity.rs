// ============================================================
// bauth::server::handlers::device_identity — T63-T66
//
// Gestión de dispositivos y evaluación de confianza.
// DDL v2.12.0 — tablas canónicas en SBOSDB:
//
//   auth_device (T-Xnn):
//     device_id, tenant_id, user_id, device_key, name, category, platform,
//     os_version, hardware_id, aaguid, trust_level, is_managed, mdm_device_id,
//     is_osdp, osdp_address, osdp_version, status, last_seen_at, last_seen_ip,
//     registered_at, ctx_id, created_at, updated_at.
//     category CHECK: 'DESKTOP','MOBILE','TABLET','SERVER','IOT','SECURITY_KEY',
//                     'SMART_CARD','OSDP_READER','NFC_READER'
//     trust_level CHECK: 'TRUSTED','CONDITIONALLY_TRUSTED','UNTRUSTED','QUARANTINE'
//     status CHECK: 'PENDING','ACTIVE','SUSPENDED','REVOKED','LOST','DECOMMISSIONED'
//
//   auth_device_posture (T-Xnn):
//     posture_id, device_id, tenant_id, disk_encrypted, screen_lock_enabled,
//     antivirus_active, os_patches_current, is_jailbroken, mdm_enrolled,
//     mdm_provider, mdm_compliance, risk_score (smallint 0-100),
//     compliance_status CHECK('COMPLIANT','NON_COMPLIANT','UNKNOWN','EXEMPTED'),
//     posture_source CHECK('MDM','EDR','AGENT','SELF_REPORTED','MANUAL'),
//     raw_report JSONB, evaluated_at, valid_until, ctx_id.
//
//   ses_session_log — termination_reason CHECK:
//     'LOGOUT','TIMEOUT','CAEP_REVOKE','ADMIN_REVOKE','EXPIRY'
//     Un dispositivo comprometido genera CAEP_REVOKE.
//
// Handlers:
//   DeviceRegisterHandler  — bauth.device.register
//   DeviceAttestHandler    — bauth.device.attest (postura de seguridad)
//   CtxTransferHandler     — bauth.ctx.transfer  (registrado en idn_audit_event_log)
//   DeviceTrustScoreHandler — bauth.device.trust_score
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── T63: Device Register ───────────────────────────────────
// Registra un dispositivo en auth_device.
// category debe ser uno de: DESKTOP, MOBILE, TABLET, SERVER, IOT,
//   SECURITY_KEY, SMART_CARD, OSDP_READER, NFC_READER.
// trust_level inicial: UNTRUSTED (requiere attestation).

pub struct DeviceRegisterHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for DeviceRegisterHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id = params.get("user_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_id requerido"))?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("tenant_id requerido"))?;
        let name = params.get("name").and_then(|v| v.as_str())
            .ok_or_else(|| err("name requerido"))?;
        let category = params.get("category").and_then(|v| v.as_str()).unwrap_or("MOBILE");
        let platform = params.get("platform").and_then(|v| v.as_str()).unwrap_or("UNKNOWN");
        let device_key = params.get("device_key").and_then(|v| v.as_str()).unwrap_or_default();
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        // Validar category contra el CHECK constraint de auth_device
        let valid_categories = ["DESKTOP","MOBILE","TABLET","SERVER","IOT","SECURITY_KEY","SMART_CARD","OSDP_READER","NFC_READER"];
        if !valid_categories.contains(&category) {
            return Err(err(&format!("category inválida. Válidas: {:?}", valid_categories)));
        }

        // Validar platform contra el CHECK constraint de auth_device
        let valid_platforms = ["WINDOWS","LINUX","MACOS","ANDROID","IOS","EMBEDDED","FIDO2_HW","OSDP_HW","UNKNOWN"];
        if !valid_platforms.contains(&platform) {
            return Err(err(&format!("platform inválida. Válidas: {:?}", valid_platforms)));
        }

        let device_id = uuid::Uuid::now_v7().to_string();
        // device_key es UNIQUE — si no se provee, generamos uno
        let effective_key = if device_key.is_empty() {
            uuid::Uuid::now_v7().to_string()
        } else {
            device_key.to_string()
        };

        sqlx::query(
            "INSERT INTO bauth.auth_device
             (device_id, tenant_id, user_id, device_key, name, category, platform,
              trust_level, status, ctx_id)
             VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7,
                     'UNTRUSTED', 'PENDING', $8)"
        )
        .bind(&device_id).bind(tenant_id).bind(user_id).bind(&effective_key)
        .bind(name).bind(category).bind(platform).bind(ctx_id)
        .execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        tracing::info!(%user_id, %device_id, category, "device.register");
        Ok(json!({
            "device_id": device_id,
            "device_key": effective_key,
            "status": "PENDING",
            "trust_level": "UNTRUSTED",
            "message": "Dispositivo registrado. Ejecute device.attest para activarlo.",
        }))
    }
}
impl DeviceRegisterHandler { pub fn method_name() -> &'static str { "bauth.device.register" } }

// ── T64: Device Attest (Evaluación de Postura) ─────────────
// Evalúa la postura de seguridad del dispositivo y actualiza
// auth_device_posture + auth_device.trust_level.
// risk_score (0-100): menor = más seguro.
// compliance_status: 'COMPLIANT' | 'NON_COMPLIANT' | 'UNKNOWN' | 'EXEMPTED'
// posture_source: 'MDM' | 'EDR' | 'AGENT' | 'SELF_REPORTED' | 'MANUAL'

pub struct DeviceAttestHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for DeviceAttestHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let device_id = params.get("device_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("device_id requerido"))?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("tenant_id requerido"))?;
        let posture_source = params.get("posture_source").and_then(|v| v.as_str()).unwrap_or("SELF_REPORTED");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("rpc");

        let valid_sources = ["MDM","EDR","AGENT","SELF_REPORTED","MANUAL"];
        if !valid_sources.contains(&posture_source) {
            return Err(err(&format!("posture_source inválido. Válidos: {:?}", valid_sources)));
        }

        // Evaluar postura desde params
        let disk_encrypted    = params.get("disk_encrypted").and_then(|v| v.as_bool()).unwrap_or(false);
        let screen_lock       = params.get("screen_lock_enabled").and_then(|v| v.as_bool()).unwrap_or(false);
        let antivirus         = params.get("antivirus_active").and_then(|v| v.as_bool()).unwrap_or(false);
        let os_current        = params.get("os_patches_current").and_then(|v| v.as_bool()).unwrap_or(false);
        let is_jailbroken     = params.get("is_jailbroken").and_then(|v| v.as_bool()).unwrap_or(false);

        // risk_score: penalizaciones acumuladas (0-100, menor = más seguro)
        let mut risk: i16 = 0;
        if !disk_encrypted  { risk += 20; }
        if !screen_lock     { risk += 15; }
        if !antivirus       { risk += 20; }
        if !os_current      { risk += 20; }
        if is_jailbroken    { risk += 25; }
        let risk_score = risk.min(100);

        let compliance_status = if is_jailbroken || risk_score >= 80 {
            "NON_COMPLIANT"
        } else if risk_score >= 40 {
            "UNKNOWN"
        } else {
            "COMPLIANT"
        };

        // Actualizar postura en auth_device_posture
        sqlx::query(
            "INSERT INTO bauth.auth_device_posture
             (device_id, tenant_id, disk_encrypted, screen_lock_enabled,
              antivirus_active, os_patches_current, is_jailbroken,
              risk_score, compliance_status, posture_source, ctx_id)
             VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
        )
        .bind(device_id).bind(tenant_id)
        .bind(disk_encrypted).bind(screen_lock).bind(antivirus).bind(os_current).bind(is_jailbroken)
        .bind(risk_score).bind(compliance_status).bind(posture_source).bind(ctx_id)
        .execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        // Actualizar trust_level en auth_device según compliance
        let trust_level = match compliance_status {
            "COMPLIANT"     => "TRUSTED",
            "NON_COMPLIANT" => "QUARANTINE",
            _               => "CONDITIONALLY_TRUSTED",
        };

        sqlx::query(
            "UPDATE bauth.auth_device
             SET trust_level = $2, status = $3, last_seen_at = now(), ctx_id = $4
             WHERE device_id = $1::uuid"
        )
        .bind(device_id)
        .bind(trust_level)
        .bind(if compliance_status == "NON_COMPLIANT" { "SUSPENDED" } else { "ACTIVE" })
        .bind(ctx_id)
        .execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        // Si el dispositivo es NON_COMPLIANT: terminar sesiones del usuario (CAEP_REVOKE)
        if compliance_status == "NON_COMPLIANT" {
            // termination_reason CHECK: 'LOGOUT','TIMEOUT','CAEP_REVOKE','ADMIN_REVOKE','EXPIRY'
            sqlx::query(
                "UPDATE bauth.ses_session_log ssl
                 SET terminated_at = now(), termination_reason = 'CAEP_REVOKE'
                 FROM bauth.auth_device ad
                 WHERE ad.device_id = $1::uuid
                   AND ssl.user_id = ad.user_id
                   AND ssl.terminated_at IS NULL"
            ).bind(device_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        }

        tracing::info!(%device_id, risk_score, compliance_status, trust_level, "device.attest");
        Ok(json!({
            "device_id": device_id,
            "risk_score": risk_score,
            "compliance_status": compliance_status,
            "trust_level": trust_level,
        }))
    }
}
impl DeviceAttestHandler { pub fn method_name() -> &'static str { "bauth.device.attest" } }

// ── T65: Context Transfer ──────────────────────────────────
// Transfiere un ctx_id de un dispositivo a otro.
// El evento se registra en idn_audit_event_log (no existe tabla dedicada en DDL v2.12.0).

pub struct CtxTransferHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for CtxTransferHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let from_device = params.get("from_device_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("from_device_id requerido"))?;
        let to_device = params.get("to_device_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("to_device_id requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido"))?;
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("tenant_id requerido"))?;
        let method = params.get("transfer_method").and_then(|v| v.as_str()).unwrap_or("QR");
        let valid_methods = ["QR","NFC","BLE","UWB","WIFI_AWARE"];
        if !valid_methods.contains(&method) {
            return Err(err(&format!("transfer_method inválido: {:?}", valid_methods)));
        }

        let transfer_id = uuid::Uuid::now_v7().to_string();

        // Registrar en idn_audit_event_log (tabla canónica de auditoría para eventos bAuth)
        // domain_code D06 = contexto de sesión
        sqlx::query(
            "INSERT INTO bauth.idn_audit_event_log
             (tenant_id, domain_code, event_type, action, outcome, ctx_id, metadata)
             VALUES ($1::uuid, 'D06', 'ctx.transfer', 'TRANSFER', 'PERMIT', $2, $3::jsonb)"
        )
        .bind(tenant_id).bind(ctx_id)
        .bind(serde_json::json!({
            "transfer_id": transfer_id,
            "from_device": from_device,
            "to_device": to_device,
            "method": method,
        }).to_string())
        .execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        tracing::info!(%ctx_id, %from_device, %to_device, method, "ctx.transfer");
        Ok(json!({
            "transfer_id": transfer_id,
            "ctx_id": ctx_id,
            "from_device": from_device,
            "to_device": to_device,
            "method": method,
            "status": "COMPLETED",
        }))
    }
}
impl CtxTransferHandler { pub fn method_name() -> &'static str { "bauth.ctx.transfer" } }

// ── T66: Multi-Device Trust Scoring ────────────────────────
// Consulta dispositivos del usuario desde auth_device y su última postura
// desde auth_device_posture para calcular el score de confianza agregado.

pub struct DeviceTrustScoreHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for DeviceTrustScoreHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id = params.get("user_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_id requerido"))?;

        // Dispositivos activos del usuario con su última postura
        #[derive(sqlx::FromRow)]
        struct DeviceRow {
            device_id: String,
            category: String,
            trust_level: String,
            risk_score: Option<i16>,
        }

        let devices: Vec<DeviceRow> = sqlx::query_as(
            "SELECT d.device_id::text, d.category, d.trust_level,
                    p.risk_score
             FROM bauth.auth_device d
             LEFT JOIN LATERAL (
                 SELECT risk_score FROM bauth.auth_device_posture
                 WHERE device_id = d.device_id
                 ORDER BY evaluated_at DESC LIMIT 1
             ) p ON true
             WHERE d.user_id = $1::uuid
               AND d.status = 'ACTIVE'"
        ).bind(user_id).fetch_all(&self.pg).await.unwrap_or_default();

        // Score combinado: promedio ponderado basado en trust_level
        let combined_score: f64 = if devices.is_empty() {
            0.0
        } else {
            let sum: f64 = devices.iter().map(|d| {
                // trust_level → score base (mayor = mejor)
                let base = match d.trust_level.as_str() {
                    "TRUSTED"               => 100.0,
                    "CONDITIONALLY_TRUSTED" => 65.0,
                    "QUARANTINE"            => 10.0,
                    _                       => 0.0, // UNTRUSTED
                };
                // Penalización por risk_score (si existe)
                let risk_penalty = d.risk_score.map(|r| r as f64 * 0.3).unwrap_or(0.0);
                (base - risk_penalty).max(0.0)
            }).sum();
            sum / devices.len() as f64
        };

        let device_list: Vec<Value> = devices.iter().map(|d| json!({
            "device_id": d.device_id,
            "category": d.category,
            "trust_level": d.trust_level,
            "risk_score": d.risk_score,
        })).collect();

        Ok(json!({
            "user_id": user_id,
            "devices": device_list,
            "combined_trust_score": (combined_score as i32).min(100),
        }))
    }
}
impl DeviceTrustScoreHandler { pub fn method_name() -> &'static str { "bauth.device.trust_score" } }

// ── Factory ────────────────────────────────────────────────

pub fn all_device_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (DeviceRegisterHandler::method_name().into(), Arc::new(DeviceRegisterHandler { pg: pg.clone() })),
        (DeviceAttestHandler::method_name().into(),   Arc::new(DeviceAttestHandler   { pg: pg.clone() })),
        (CtxTransferHandler::method_name().into(),    Arc::new(CtxTransferHandler    { pg: pg.clone() })),
        (DeviceTrustScoreHandler::method_name().into(), Arc::new(DeviceTrustScoreHandler { pg: pg.clone() })),
    ]
}
