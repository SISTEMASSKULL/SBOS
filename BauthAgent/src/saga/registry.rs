// ============================================================
// bauth::saga::registry — ActionRegistry (B35)
//
// Mapea action_ref → función real de autenticación.
//
// Acciones canónicas:
//   bauth.login.verify_argon2id — verifica hash desde auth_credential_secret
//   bauth.login.record_failed   — registra en auth_attempt_log (D01 canónico)
//   bauth.login.hibp_check      — k-Anonymity HIBP local
//
// Eliminado: bauth.audit.record (usaba aud_event — phantom D02;
//            sin equivalente para eventos de saga en DDL v2.12.0)
//
// DOC-SBOS-001 N3 · B35 · ALT-001 FIX
// ============================================================

#![allow(dead_code)]
use crate::saga::action::SagaEvalContext;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;

/// Tipo de función que implementa una acción de saga.
pub type ActionFn = Arc<
    dyn Fn(&SagaEvalContext, Option<&sqlx::PgPool>) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value, String>> + Send>>
    + Send + Sync
>;

/// Registro de acciones de saga. Mapea action_ref → implementación real.
pub struct ActionRegistry {
    actions: HashMap<String, ActionFn>,
}

impl ActionRegistry {
    pub fn new() -> Self {
        Self { actions: HashMap::new() }
    }

    pub fn register<F, Fut>(&mut self, name: &str, action: F)
    where
        F: (Fn(String, serde_json::Value, Option<sqlx::PgPool>) -> Fut) + Send + Sync + 'static,
        Fut: std::future::Future<Output = Result<Value, String>> + Send,
    {
        let action_arc = Arc::new(action);
        let name = name.to_string();
        self.actions.insert(name.clone(), Arc::new(move |ctx: &SagaEvalContext, pg: Option<&sqlx::PgPool>| {
            let name = name.clone();
            let params = ctx.params.clone();
            let pg_clone = pg.cloned();
            let action = action_arc.clone();
            Box::pin(async move {
                action(name, params, pg_clone).await
            })
        }));
    }

    pub async fn execute(
        &self,
        action_ref: &str,
        ctx: &SagaEvalContext,
        pg: Option<&sqlx::PgPool>,
    ) -> Result<Value, String> {
        match self.actions.get(action_ref) {
            Some(action) => action(ctx, pg).await,
            None => Err(format!("acción '{}' no registrada en ActionRegistry", action_ref)),
        }
    }

    pub fn names(&self) -> Vec<&str> {
        self.actions.keys().map(|s| s.as_str()).collect()
    }
}

/// Parsea un UUID desde un campo JSON del contexto de saga.
fn parse_uuid_from_ctx(ctx: &SagaEvalContext, field: &str) -> Option<uuid::Uuid> {
    ctx.params.get(field)
        .and_then(|v| v.as_str())
        .and_then(|s| uuid::Uuid::parse_str(s).ok())
}

/// Crea el registro con las acciones de autenticación implementadas.
pub fn default_registry(pg_pool: sqlx::PgPool, hibp_cfg: crate::config::HibpConfig) -> ActionRegistry {
    let mut registry = ActionRegistry::new();

    // bauth.login.verify_argon2id — verifica hash Argon2id desde auth_credential_secret
    let pg = pg_pool.clone();
    registry.actions.insert("bauth.login.verify_argon2id".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let pg = pg.clone();
            let username = ctx.params.get("username").cloned().unwrap_or_default();
            let password = ctx.params.get("password").cloned().unwrap_or_default();
            Box::pin(async move {
                crate::saga::actions::login::verify_argon2id(
                    &pg,
                    username.as_str().unwrap_or(""),
                    password.as_str().unwrap_or(""),
                ).await
            })
        }
    ));

    // bauth.login.record_failed — registra en auth_attempt_log (D01 canónico)
    // Extrae tenant_id, user_id, method_code y ctx_id del contexto de saga.
    let pg = pg_pool.clone();
    registry.actions.insert("bauth.login.record_failed".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let pg       = pg.clone();
            let username = ctx.params.get("username").cloned().unwrap_or_default();
            let ip       = ctx.params.get("client_ip").cloned().unwrap_or_default();
            let reason   = ctx.params.get("failure_reason").and_then(|v| v.as_str().map(String::from));
            let method   = ctx.params.get("method_code")
                .and_then(|v| v.as_str().map(String::from))
                .unwrap_or_else(|| "PASSWORD".to_string());
            let ctx_id   = ctx.ctx_id.clone();
            // tenant_id es obligatorio en auth_attempt_log (NOT NULL)
            let tenant_id = parse_uuid_from_ctx(ctx, "tenant_id");
            let user_id   = parse_uuid_from_ctx(ctx, "user_id");

            Box::pin(async move {
                let tid = match tenant_id {
                    Some(t) => t,
                    None => return Err("tenant_id requerido para registrar intento fallido".into()),
                };
                crate::saga::actions::login::record_failed_attempt(
                    &pg,
                    tid,
                    user_id,
                    username.as_str().unwrap_or(""),
                    &method,
                    ip.as_str().unwrap_or(""),
                    reason.as_deref(),
                    &ctx_id,
                ).await
            })
        }
    ));

    // bauth.login.hibp_check — verificación k-Anonymity HIBP
    let hibp_api_url = hibp_cfg.api_url.clone();
    let hibp_timeout = hibp_cfg.timeout_secs;
    registry.actions.insert("bauth.login.hibp_check".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let password = ctx.params.get("password").cloned().unwrap_or_default();
            let url      = hibp_api_url.clone();
            let timeout  = hibp_timeout;
            Box::pin(async move {
                let password_str = password.as_str().unwrap_or("");
                crate::saga::actions::hibp::check_hibp(password_str, &url, timeout).await
                    .map(|result| serde_json::json!({
                        "breached": result.breached,
                        "count":    result.count,
                    }))
            })
        }
    ));

    registry
}
