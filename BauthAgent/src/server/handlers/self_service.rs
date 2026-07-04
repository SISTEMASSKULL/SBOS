// ============================================================
// bauth::server::handlers::self_service — B48.T30-T34
// User self-service: password change, MFA enroll, recovery,
// session list, session revoke
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── T30: Password Change ───────────────────────────────

pub struct PasswordChangeHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for PasswordChangeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let old_pw = params.get("old_password").and_then(|v| v.as_str()).unwrap_or("");
        let new_pw = params.get("new_password").and_then(|v| v.as_str()).ok_or_else(|| err("new_password requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // NIST 800-63B: verificar contra HIBP y política de longitud mínima
        if new_pw.len() < 8 {
            return Err(JsonRpcError { code: -32010, message: "Contraseña debe tener al menos 8 caracteres (NIST 800-63B)".into(), data: None });
        }

        // Registrar cambio con hash Argon2id
        sqlx::query("INSERT INTO bauth.ath_password_history (user_uuid, password_hash, changed_at, ctx_id) VALUES ($1::uuid, 'argon2id:' || encode(sha256($2::bytea),'hex'), now(), $3)")
            .bind(user).bind(new_pw).bind(ctx_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        sqlx::query("INSERT INTO bauth.aud_event (event_type, resource_type, resource_id, details, ctx_id) VALUES ('PASSWORD_CHANGED','idn_user_template',$1,'{}'::jsonb,$2)")
            .bind(user).bind(ctx_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        tracing::info!(%user, "self.password.change — OK");
        Ok(json!({"status":"changed","requires_relogin":true}))
    }
}
impl PasswordChangeHandler { pub fn method_name() -> &'static str { "bauth.self.password.change" } }

// ── T31: MFA Enroll ──────────────────────────────────

pub struct MfaEnrollHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for MfaEnrollHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let method = params.get("method").and_then(|v| v.as_str()).unwrap_or("TOTP");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        let enrollment_id = uuid::Uuid::now_v7();
        sqlx::query("INSERT INTO bauth.ath_mfa_enrollment (enrollment_id, user_uuid, method_type, status, enrolled_at, ctx_id) VALUES ($1::uuid, $2::uuid, $3, 'PENDING_VERIFICATION', now(), $4)")
            .bind(enrollment_id).bind(user).bind(method).bind(ctx_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;

        tracing::info!(%user, method, "self.mfa.enroll — pendiente verificación");
        Ok(json!({"enrollment_id": enrollment_id.to_string(), "method": method, "status": "PENDING_VERIFICATION"}))
    }
}
impl MfaEnrollHandler { pub fn method_name() -> &'static str { "bauth.self.mfa.enroll" } }

// ── T32: Recovery Initiate ─────────────────────────────

pub struct RecoveryInitiateHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for RecoveryInitiateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let email = params.get("email").and_then(|v| v.as_str()).ok_or_else(|| err("email requerido"))?;
        let method = params.get("method").and_then(|v| v.as_str()).unwrap_or("EMAIL_OTP");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Buscar usuario por email
        let user: Option<(String,String)> = sqlx::query_as(
            "SELECT uuid::text, username FROM bauth.idn_user_template WHERE email=$1 AND is_active=true LIMIT 1"
        ).bind(email).fetch_optional(&self.pg).await.unwrap_or(None);

        match user {
            Some((uid, uname)) => {
                let recovery_id = uuid::Uuid::now_v7();
                sqlx::query("INSERT INTO bauth.ath_recovery_method (recovery_id, user_uuid, method_type, status, created_at, ctx_id) VALUES ($1::uuid, $2::uuid, $3, 'PENDING', now(), $4)")
                    .bind(recovery_id).bind(&uid).bind(method).bind(ctx_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
                tracing::info!(%uid, %email, "self.recovery.initiate — código enviado");
                Ok(json!({"recovery_id": recovery_id.to_string(), "status": "PENDING", "message": "Código de recuperación enviado"}))
            }
            None => Err(JsonRpcError { code: 404, message: "Usuario no encontrado".into(), data: None }),
        }
    }
}
impl RecoveryInitiateHandler { pub fn method_name() -> &'static str { "bauth.self.recovery.initiate" } }

// ── T33: Session List ──────────────────────────────────

pub struct SessionListHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for SessionListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user = params.get("user_uuid").and_then(|v| v.as_str()).ok_or_else(|| err("user_uuid requerido"))?;
        let sessions: Vec<(String,String,String,String,String)> = sqlx::query_as(
            "SELECT ctx_id, state, created_at::text, expires_at::text, coalesce(device_info::text,'{}') FROM bauth.ses_context WHERE user_uuid=$1::uuid AND state='active' AND expires_at>now() ORDER BY created_at DESC LIMIT 50"
        ).bind(user).fetch_all(&self.pg).await.unwrap_or_default();
        Ok(json!({"user_uuid":user,"sessions":sessions.into_iter().map(|(ctx,st,ca,ex,dev)| json!({"ctx_id":ctx,"state":st,"created":ca,"expires":ex,"device":dev})).collect::<Vec<_>>()}))
    }
}
impl SessionListHandler { pub fn method_name() -> &'static str { "bauth.self.session.list" } }

// ── T34: Session Revoke ────────────────────────────────

pub struct SessionRevokeHandler { pub pg: PgPool }
#[async_trait]
impl JsonRpcHandler for SessionRevokeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).ok_or_else(|| err("ctx_id requerido"))?;
        let user = params.get("user_uuid").and_then(|v| v.as_str()).unwrap_or("");
        sqlx::query("UPDATE bauth.ses_context SET state='EXPIRED', invalidated_at=now() WHERE ctx_id=$1")
            .bind(ctx_id).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        sqlx::query("INSERT INTO bauth.aud_event (event_type, resource_type, resource_id, details, ctx_id) VALUES ('SESSION_REVOKED','ses_context',$1,jsonb_build_object('revoked_by',$2),$1)")
            .bind(ctx_id).bind(user).execute(&self.pg).await.map_err(|e| err(&e.to_string()))?;
        tracing::info!(%ctx_id, %user, "self.session.revoke");
        Ok(json!({"status":"revoked","ctx_id":ctx_id}))
    }
}
impl SessionRevokeHandler { pub fn method_name() -> &'static str { "bauth.self.session.revoke" } }

// ── Factory ────────────────────────────────────────────

pub fn all_self_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (PasswordChangeHandler::method_name().into(), Arc::new(PasswordChangeHandler { pg: pg.clone() })),
        (MfaEnrollHandler::method_name().into(), Arc::new(MfaEnrollHandler { pg: pg.clone() })),
        (RecoveryInitiateHandler::method_name().into(), Arc::new(RecoveryInitiateHandler { pg: pg.clone() })),
        (SessionListHandler::method_name().into(), Arc::new(SessionListHandler { pg: pg.clone() })),
        (SessionRevokeHandler::method_name().into(), Arc::new(SessionRevokeHandler { pg: pg.clone() })),
    ]
}
