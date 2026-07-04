// ============================================================
// bauth::context::engine — B16 Context Engine (SBOS-049)
//
// Ciclo de vida del ctx_id:
//   1. BOS crea dctx_id (pre-auth) → Redis + PostgreSQL
//   2. Usuario autentica en Keycloak → dctx_id validado
//   3. bAuth promueve dctx_id → ctx_id (asigna user_id, bitmask)
//   4. Kong valida ctx_id en cada request (PEP)
//   5. bAuth invalida ctx_id en logout/timeout
//
// ARQUITECTURA DE RESPONSABILIDAD:
//   BOS: CREA + GOBIERNA el ciclo de vida (create/destroy)
//   bAuth: VALIDA + INYECTA tenant/user/role (authenticate/inject)
//   Kong: ENFORCE (valida header X-SBOS-Context en cada request)
// ============================================================
#![allow(dead_code)]
use super::plane::{CtxPlane, CtxState};
use uuid::Uuid;

/// Resultado de una operación del Context Plane.
#[derive(Debug, Clone)]
pub struct CtxResult {
    pub valid: bool,
    pub ctx_id: String,
    pub state: CtxState,
    pub tenant_id: Option<Uuid>,
    pub user_id: Option<Uuid>,
    pub reason: String,
    pub traceparent: Option<String>,
}

/// Motor del Context Plane — opera entre BOS (governor) y Kong (enforcer).
pub struct CtxEngine;

impl CtxEngine {
    /// Valida la estructura canónica de un ctx_id (SBOS-049 §3).
    /// 6 campos requeridos: tenant_id, empresa_id, sucursal_id, pos_logico, user_id, traceparent
    pub fn validate_structure(ctx_header: &str) -> Result<CtxPlane, String> {
        if ctx_header.is_empty() {
            return Err("ctx_id vacío — requerido por SBOS-049".into());
        }
        CtxPlane::from_header(ctx_header)
    }

    /// Verifica que un dctx_id (pre-auth) existe y está en estado Pending.
    /// Llamado ANTES de permitir la autenticación en Keycloak (B16.T15).
    /// Si dctx_id no existe → denegar autenticación (sin dispositivo registrado).
    pub fn validate_pre_auth(ctx: &CtxPlane) -> CtxResult {
        if !ctx.is_pending() {
            return CtxResult {
                valid: false,
                ctx_id: ctx.to_header(),
                state: CtxState::Invalidated,
                tenant_id: Some(ctx.tenant_id),
                user_id: None,
                reason: "dctx_id ya fue promovido — posible replay attack".into(),
                traceparent: Some(ctx.traceparent.clone()),
            };
        }
        if ctx.is_expired() {
            return CtxResult {
                valid: false,
                ctx_id: ctx.to_header(),
                state: CtxState::Invalidated,
                tenant_id: Some(ctx.tenant_id),
                user_id: None,
                reason: "dctx_id expirado — el dispositivo debe re-registrarse con BOS".into(),
                traceparent: Some(ctx.traceparent.clone()),
            };
        }
        CtxResult {
            valid: true,
            ctx_id: ctx.to_header(),
            state: CtxState::Pending,
            tenant_id: Some(ctx.tenant_id),
            user_id: None,
            reason: "dctx_id válido — listo para autenticación".into(),
            traceparent: Some(ctx.traceparent.clone()),
        }
    }

    /// Promueve dctx_id → ctx_id después de autenticación exitosa.
    /// Asigna user_id y reinicia secuencia + nonce (B16.T04, B16.T12).
    pub fn promote(mut ctx: CtxPlane, user_id: Uuid) -> CtxResult {
        if !ctx.is_pending() {
            return CtxResult {
                valid: false,
                ctx_id: ctx.to_header(),
                state: CtxState::Quarantined,
                tenant_id: Some(ctx.tenant_id),
                user_id: Some(user_id),
                reason: "ctx_id ya promovido — no se puede promover dos veces".into(),
                traceparent: Some(ctx.traceparent.clone()),
            };
        }

        ctx.promote(user_id);
        let new_traceparent = ctx.traceparent.clone();
        let header = ctx.to_header();

        CtxResult {
            valid: true,
            ctx_id: header,
            state: CtxState::Active,
            tenant_id: Some(ctx.tenant_id),
            user_id: Some(user_id),
            reason: "ctx_id promovido exitosamente".into(),
            traceparent: Some(new_traceparent),
        }
    }

    /// Invalida un ctx_id (logout, timeout, o anomalía de seguridad).
    /// Idempotente — invalidar 2 veces no causa error (B16.T05, B16.T13).
    pub fn invalidate(ctx: &CtxPlane) -> CtxResult {
        CtxResult {
            valid: true,
            ctx_id: ctx.to_header(),
            state: CtxState::Invalidated,
            tenant_id: Some(ctx.tenant_id),
            user_id: if ctx.user_id.is_nil() { None } else { Some(ctx.user_id) },
            reason: "ctx_id invalidado — sesión terminada".into(),
            traceparent: Some(ctx.traceparent.clone()),
        }
    }

    /// Valida un ctx_id activo en tiempo real (Policy Decision Point).
    /// Verifica: estructura, no expirado, user_id asignado (B16.T03).
    pub fn validate_active(ctx: &CtxPlane) -> CtxResult {
        // Validar estructura (6 campos)
        if ctx.tenant_id.is_nil() || ctx.empresa_id.is_nil() {
            return CtxResult {
                valid: false, ctx_id: ctx.to_header(),
                state: CtxState::Invalidated,
                tenant_id: None, user_id: None,
                reason: "ctx_id con estructura inválida (tenant/empresa nulos)".into(),
                traceparent: None,
            };
        }

        // Validar expiración
        if ctx.is_expired() {
            return CtxResult {
                valid: false, ctx_id: ctx.to_header(),
                state: CtxState::Invalidated,
                tenant_id: Some(ctx.tenant_id),
                user_id: if ctx.user_id.is_nil() { None } else { Some(ctx.user_id) },
                reason: format!("ctx_id expirado (TTL: {}s)", ctx.ttl_seconds),
                traceparent: Some(ctx.traceparent.clone()),
            };
        }

        // Validar que tenga usuario (post-auth)
        if ctx.is_pending() {
            return CtxResult {
                valid: false, ctx_id: ctx.to_header(),
                state: CtxState::Pending,
                tenant_id: Some(ctx.tenant_id), user_id: None,
                reason: "ctx_id en estado Pending — requiere autenticación".into(),
                traceparent: Some(ctx.traceparent.clone()),
            };
        }

        CtxResult {
            valid: true, ctx_id: ctx.to_header(),
            state: CtxState::Active,
            tenant_id: Some(ctx.tenant_id),
            user_id: Some(ctx.user_id),
            reason: "ctx_id válido y activo".into(),
            traceparent: Some(ctx.traceparent.clone()),
        }
    }

    /// Genera headers W3C Trace Context + OpenTelemetry Baggage.
    /// Para propagación entre daemons (B16.T11).
    pub fn propagation_headers(ctx: &CtxPlane) -> Vec<(String, String)> {
        vec![
            ("traceparent".into(), ctx.traceparent.clone()),
            ("tracestate".into(), format!("sbos={}", ctx.tenant_id)),
            ("baggage".into(), format!("ctx_id={},user_id={}",
                ctx.to_header().replace(':', "%3A"), ctx.user_id)),
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_pending() -> CtxPlane {
        CtxPlane::new_pending(
            Uuid::new_v4(), Uuid::new_v4(), Some(Uuid::new_v4()),
            "POS-01", 3600,
        )
    }

    #[test]
    fn test_validate_pre_auth_accepts_pending() {
        let ctx = make_pending();
        let result = CtxEngine::validate_pre_auth(&ctx);
        assert!(result.valid);
        assert_eq!(result.state, CtxState::Pending);
    }

    #[test]
    fn test_validate_pre_auth_rejects_expired() {
        let mut ctx = make_pending();
        ctx.created_at = chrono::Utc::now() - chrono::Duration::hours(2);
        let result = CtxEngine::validate_pre_auth(&ctx);
        assert!(!result.valid);
    }

    #[test]
    fn test_promote_activates_context() {
        let ctx = make_pending();
        let user_id = Uuid::new_v4();
        let result = CtxEngine::promote(ctx, user_id);
        assert!(result.valid);
        assert_eq!(result.state, CtxState::Active);
        assert_eq!(result.user_id, Some(user_id));
    }

    #[test]
    fn test_promote_rejects_already_active() {
        let mut ctx = make_pending();
        ctx.user_id = Uuid::new_v4(); // ya promovido
        ctx.sequence = 1;
        let result = CtxEngine::promote(ctx, Uuid::new_v4());
        assert!(!result.valid, "no se puede promover dos veces");
    }

    #[test]
    fn test_validate_active_rejects_pending() {
        let ctx = make_pending();
        let result = CtxEngine::validate_active(&ctx);
        assert!(!result.valid);
        assert!(result.reason.contains("Pending"));
    }

    #[test]
    fn test_validate_active_accepts_valid() {
        let mut ctx = make_pending();
        ctx.promote(Uuid::new_v4());
        let result = CtxEngine::validate_active(&ctx);
        assert!(result.valid);
        assert_eq!(result.state, CtxState::Active);
    }

    #[test]
    fn test_invalidate_is_idempotent() {
        let ctx = make_pending();
        let r1 = CtxEngine::invalidate(&ctx);
        let r2 = CtxEngine::invalidate(&ctx);
        assert!(r1.valid);
        assert!(r2.valid);
        assert_eq!(r1.state, CtxState::Invalidated);
        assert_eq!(r2.state, CtxState::Invalidated);
    }

    #[test]
    fn test_propagation_headers_w3c_format() {
        let mut ctx = make_pending();
        ctx.promote(Uuid::new_v4());
        let headers = CtxEngine::propagation_headers(&ctx);
        assert!(headers.iter().any(|(k, _)| k == "traceparent"));
        assert!(headers.iter().any(|(k, _)| k == "tracestate"));
        assert!(headers.iter().any(|(k, _)| k == "baggage"));
    }
}
