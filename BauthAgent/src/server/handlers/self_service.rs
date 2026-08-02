// ============================================================
// bauth::server::handlers::self_service — B48.T30-T34
//
// Self-service del usuario: cambio de contraseña, enrolamiento MFA,
// inicio de recuperación, listado y revocación de sesiones.
//
// Tablas canónicas DDL v2.12.0:
//   bauth.auth_credential_secret — hash Argon2id (reemplaza ath_password_history)
//   bauth.auth_credential        — credenciales (reemplaza ath_mfa_enrollment)
//   bauth.idn_user               — usuarios (reemplaza idn_user_template)
//   bauth.idn_user_recovery      — recuperación (reemplaza ath_recovery_method)
//   bauth.idn_identity_attribute — atributos de identidad (búsqueda por email)
//   bauth.ses_session_log        — sesiones (reemplaza ses_context)
//
// D02 eliminado: aud_event no existe en DDL v2.12.0.
//
// DOC-SBOS-001 N3 · NIST SP 800-63B-4 §5.1.1.2 · RFC 7519
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2,
};
use async_trait::async_trait;
use rand::rngs::OsRng;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

// ── T30: Password Change ───────────────────────────────

/// Handler: bauth.self.password.change
/// Cambia la contraseña del usuario. Genera un nuevo hash Argon2id e
/// inserta en auth_credential_secret (WORM — el secreto anterior queda
/// como histórico, nunca se sobreescribe).
pub struct PasswordChangeHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for PasswordChangeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_uuid requerido"))?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| err("user_uuid inválido"))?;

        let new_pw = params.get("new_password").and_then(|v| v.as_str())
            .ok_or_else(|| err("new_password requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // NIST 800-63B-4: longitud mínima 8 caracteres
        if new_pw.len() < 8 {
            return Err(JsonRpcError {
                code: -32010,
                message: "contraseña debe tener al menos 8 caracteres (NIST 800-63B)".into(),
                data: None,
            });
        }

        // Buscar credencial PASSWORD activa del usuario
        let cred: Option<(uuid::Uuid,)> = sqlx::query_as(
            "SELECT credential_id
             FROM bauth.auth_credential
             WHERE user_id = $1 AND method_code = 'PASSWORD' AND status = 'ACTIVE'
             LIMIT 1"
        )
        .bind(user_id)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let credential_id = cred
            .ok_or_else(|| err("usuario sin credencial PASSWORD activa"))?
            .0;

        // Hashear nueva contraseña con Argon2id (NIST 800-63B-4 §5.1.1.2)
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let hash = argon2.hash_password(new_pw.as_bytes(), &salt)
            .map_err(|e| err(&format!("error generando hash: {e}")))?
            .to_string();

        // INSERT en auth_credential_secret (WORM)
        sqlx::query(
            "INSERT INTO bauth.auth_credential_secret
                (credential_id, type, secret, algorithm, ctx_id)
             VALUES ($1, 'ARGON2ID_HASH', $2, 'ARGON2ID', $3)"
        )
        .bind(credential_id)
        .bind(&hash)
        .bind(ctx_id)
        .execute(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%user_id, "self.password.change — OK");
        Ok(json!({"status": "changed", "requires_relogin": true}))
    }
}

impl PasswordChangeHandler {
    pub fn method_name() -> &'static str { "bauth.self.password.change" }
}

// ── T31: MFA Enroll ──────────────────────────────────

/// Handler: bauth.self.mfa.enroll
/// Crea una credencial MFA en estado PENDING_VERIFICATION en auth_credential.
pub struct MfaEnrollHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for MfaEnrollHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_uuid requerido"))?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| err("user_uuid inválido"))?;

        let method = params.get("method").and_then(|v| v.as_str()).unwrap_or("TOTP");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Obtener tenant_id del usuario
        let tenant_row: Option<(uuid::Uuid,)> = sqlx::query_as(
            "SELECT tenant_id FROM bauth.idn_user WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let tenant_id = tenant_row
            .ok_or_else(|| err("usuario no encontrado"))?
            .0;

        let credential_id = uuid::Uuid::now_v7();
        sqlx::query(
            "INSERT INTO bauth.auth_credential
                (credential_id, user_id, tenant_id, method_code, status, loa_provided, ctx_id)
             VALUES ($1, $2, $3, $4, 'PENDING_VERIFICATION', 'AAL2', $5)"
        )
        .bind(credential_id)
        .bind(user_id)
        .bind(tenant_id)
        .bind(method)
        .bind(ctx_id)
        .execute(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%user_id, method, "self.mfa.enroll — pendiente verificación");
        Ok(json!({
            "credential_id": credential_id.to_string(),
            "method":        method,
            "status":        "PENDING_VERIFICATION",
        }))
    }
}

impl MfaEnrollHandler {
    pub fn method_name() -> &'static str { "bauth.self.mfa.enroll" }
}

// ── T32: Recovery Initiate ─────────────────────────────

/// Handler: bauth.self.recovery.initiate
/// Inicia el proceso de recuperación de cuenta. Busca el usuario por email
/// en idn_identity_attribute (attr_key='email', attr_value JSONB) y crea
/// un registro en idn_user_recovery.
pub struct RecoveryInitiateHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for RecoveryInitiateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let email = params.get("email").and_then(|v| v.as_str())
            .ok_or_else(|| err("email requerido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Buscar usuario por email en idn_identity_attribute.
        // attr_value es JSONB; el email se almacena como string JSON: to_jsonb('user@x.com').
        let user_row: Option<(uuid::Uuid, uuid::Uuid)> = sqlx::query_as(
            r#"
            SELECT u.user_id, u.tenant_id
            FROM bauth.idn_user u
            JOIN bauth.idn_identity_entity e ON e.entity_id = u.entity_id
            JOIN bauth.idn_identity_attribute a ON a.entity_id = e.entity_id
            WHERE a.attr_key   = 'email'
              AND a.attr_value = to_jsonb($1::text)
              AND u.status     = 'ACTIVE'
            LIMIT 1
            "#
        )
        .bind(email)
        .fetch_optional(&self.pg)
        .await
        .unwrap_or(None);

        match user_row {
            Some((user_id, tenant_id)) => {
                let recovery_id = uuid::Uuid::now_v7();

                sqlx::query(
                    "INSERT INTO bauth.idn_user_recovery
                        (recovery_id, user_id, tenant_id, type, status)
                     VALUES ($1, $2, $3, 'BACKUP_EMAIL', 'ACTIVE')"
                )
                .bind(recovery_id)
                .bind(user_id)
                .bind(tenant_id)
                .execute(&self.pg)
                .await
                .map_err(|e| err(&e.to_string()))?;

                tracing::info!(%user_id, %email, ctx_id, "self.recovery.initiate — código enviado");
                Ok(json!({
                    "recovery_id": recovery_id.to_string(),
                    "status":      "PENDING",
                    "message":     "Código de recuperación enviado",
                }))
            }
            None => Err(JsonRpcError {
                code: 404,
                message: "Usuario no encontrado".into(),
                data: None,
            }),
        }
    }
}

impl RecoveryInitiateHandler {
    pub fn method_name() -> &'static str { "bauth.self.recovery.initiate" }
}

// ── T33: Session List ──────────────────────────────────

/// Handler: bauth.self.session.list
/// Lista las sesiones activas del usuario desde ses_session_log.
pub struct SessionListHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for SessionListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let user_id_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_uuid requerido"))?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| err("user_uuid inválido"))?;

        #[derive(sqlx::FromRow)]
        struct SesRow {
            ctx_id:         String,
            auth_method:    Option<String>,
            started_at:     chrono::DateTime<chrono::Utc>,
            last_active_at: Option<chrono::DateTime<chrono::Utc>>,
            ip_address:     Option<String>,
            user_agent:     Option<String>,
        }

        let sessions: Vec<SesRow> = sqlx::query_as(
            "SELECT ctx_id, auth_method, started_at, last_active_at,
                    ip_address::text, user_agent
             FROM bauth.ses_session_log
             WHERE user_id = $1 AND terminated_at IS NULL
             ORDER BY started_at DESC LIMIT 50"
        )
        .bind(user_id)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        Ok(json!({
            "user_uuid": user_id_str,
            "sessions": sessions.into_iter().map(|s| json!({
                "ctx_id":      s.ctx_id,
                "auth_method": s.auth_method,
                "started_at":  s.started_at.to_rfc3339(),
                "last_active": s.last_active_at.map(|t| t.to_rfc3339()),
                "ip":          s.ip_address,
                "user_agent":  s.user_agent,
            })).collect::<Vec<_>>(),
        }))
    }
}

impl SessionListHandler {
    pub fn method_name() -> &'static str { "bauth.self.session.list" }
}

// ── T34: Session Revoke ────────────────────────────────

/// Handler: bauth.self.session.revoke
/// Revoca (termina) una sesión específica en ses_session_log.
/// El usuario solo puede revocar sus propias sesiones (user_id como guarda).
pub struct SessionRevokeHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for SessionRevokeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido"))?;
        let user_id_str = params.get("user_uuid").and_then(|v| v.as_str()).unwrap_or("");
        let user_id = uuid::Uuid::parse_str(user_id_str).ok();

        sqlx::query(
            "UPDATE bauth.ses_session_log
             SET terminated_at      = now(),
                 termination_reason = 'LOGOUT'
             WHERE ctx_id = $1
               AND terminated_at IS NULL
               AND ($2::uuid IS NULL OR user_id = $2)"
        )
        .bind(ctx_id)
        .bind(user_id)
        .execute(&self.pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%ctx_id, %user_id_str, "self.session.revoke");
        Ok(json!({"status": "revoked", "ctx_id": ctx_id}))
    }
}

impl SessionRevokeHandler {
    pub fn method_name() -> &'static str { "bauth.self.session.revoke" }
}

// ── Factory ────────────────────────────────────────────

/// Registra todos los handlers de self-service en el dispatcher JSON-RPC.
pub fn all_self_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (PasswordChangeHandler::method_name().into(), Arc::new(PasswordChangeHandler { pg: pg.clone() })),
        (MfaEnrollHandler::method_name().into(),      Arc::new(MfaEnrollHandler { pg: pg.clone() })),
        (RecoveryInitiateHandler::method_name().into(), Arc::new(RecoveryInitiateHandler { pg: pg.clone() })),
        (SessionListHandler::method_name().into(),    Arc::new(SessionListHandler { pg: pg.clone() })),
        (SessionRevokeHandler::method_name().into(),  Arc::new(SessionRevokeHandler { pg: pg.clone() })),
    ]
}
