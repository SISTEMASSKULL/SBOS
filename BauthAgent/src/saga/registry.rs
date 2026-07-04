// ============================================================
// bauth::saga::registry — ActionRegistry (B35)
//
// Mapea action_ref → función real de autenticación.
// Reemplaza simulate_action() con implementaciones verificables.
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

/// Crea el registro con las acciones de autenticación implementadas.
pub fn default_registry(pg_pool: sqlx::PgPool, hibp_cfg: crate::config::HibpConfig) -> ActionRegistry {
    let mut registry = ActionRegistry::new();

    // bauth.login.verify_argon2id
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

    // bauth.login.record_failed
    let pg = pg_pool.clone();
    registry.actions.insert("bauth.login.record_failed".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let pg = pg.clone();
            let username = ctx.params.get("username").cloned().unwrap_or_default();
            let ip = ctx.params.get("client_ip").cloned().unwrap_or_default();
            Box::pin(async move {
                crate::saga::actions::login::record_failed_attempt(
                    &pg,
                    username.as_str().unwrap_or(""),
                    ip.as_str().unwrap_or("127.0.0.1"),
                ).await
            })
        }
    ));

    // bauth.login.hibp_check
    let hibp_api_url = hibp_cfg.api_url.clone();
    let hibp_timeout = hibp_cfg.timeout_secs;
    registry.actions.insert("bauth.login.hibp_check".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let password = ctx.params.get("password").cloned().unwrap_or_default();
            let url = hibp_api_url.clone();
            let timeout = hibp_timeout;
            Box::pin(async move {
                let password_str = password.as_str().unwrap_or("");
                crate::saga::actions::hibp::check_hibp(password_str, &url, timeout).await
                    .map(|result| serde_json::json!({
                        "breached": result.breached,
                        "count": result.count,
                    }))
            })
        }
    ));

    // bauth.audit.record
    let pg = pg_pool.clone();
    registry.actions.insert("bauth.audit.record".into(), Arc::new(
        move |ctx: &SagaEvalContext, _pg: Option<&sqlx::PgPool>| {
            let pg = pg.clone();
            let event_type = ctx.params.get("event_type").cloned().unwrap_or_default();
            let reason = ctx.params.get("reason").cloned().unwrap_or_default();
            let ctx_id = ctx.ctx_id.clone();
            Box::pin(async move {
                sqlx::query(
                    "INSERT INTO bauth.aud_event (event_type, resource_type, details, ctx_id)
                     VALUES ($1, 'saga', $2, $3)"
                )
                .bind(event_type.as_str().unwrap_or("SAGA_EVENT"))
                .bind(reason.as_str().unwrap_or("saga execution"))
                .bind(&ctx_id)
                .execute(&pg).await
                .map(|_| Value::String("audit_recorded".into()))
                .map_err(|e| e.to_string())
            })
        }
    ));

    registry
}
