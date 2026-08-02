// ============================================================
// bauth::server::handlers::context_plane — B16 Context Plane handlers
//
// bauth.ctx.create     → Crear dctx_id (pre-auth, delegado a BOS)
// bauth.ctx.validate   → Validar ctx_id activo (PDP en tiempo real)
// bauth.ctx.promote    → Promover dctx_id → ctx_id post-auth
// bauth.ctx.invalidate → Invalidar ctx_id (logout/timeout)
// bauth.ctx.propagate  → Headers W3C Trace Context + OTel Baggage
// bauth.ctx.get_session → Obtener sesión activa
//
// Tabla canónica DDL v2.12.0:
//   bauth.ses_session_log — sesiones (reemplaza ses_context)
//
// Phantom D06 eliminado: ses_context no existe en DDL v2.12.0.
// Phantom D03 eliminado: idn_user_template → privilege_atom_grant para bitmask.
// Phantom D05 eliminado: privilege_role → privilege_atom_grant G-12 directo.
//
// DOC-SBOS-001 N3 · SBOS-049 Context Plane · W3C Trace Context
// ============================================================

use crate::context::engine::CtxEngine;
use crate::context::plane::CtxPlane;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use base64::Engine;
use serde_json::Value;
use uuid::Uuid;

/// bauth.ctx.create — Crear dctx_id pre-auth.
pub struct CtxCreateHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for CtxCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let tenant_id = Uuid::parse_str(
            params.get("tenant_id").and_then(|v| v.as_str()).unwrap_or("")
        ).map_err(|_| JsonRpcError { code: -32602, message: "tenant_id requerido (UUID)".into(), data: None })?;

        let empresa_id = Uuid::parse_str(
            params.get("empresa_id").and_then(|v| v.as_str()).unwrap_or("")
        ).map_err(|_| JsonRpcError { code: -32602, message: "empresa_id requerido (UUID)".into(), data: None })?;

        let sucursal_id = params.get("sucursal_id").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let pos_logico  = params.get("pos_logico").and_then(|v| v.as_str()).unwrap_or("default");
        let ttl         = params.get("ttl_seconds").and_then(|v| v.as_u64()).unwrap_or(3600);

        let ctx = CtxPlane::new_pending(tenant_id, empresa_id, sucursal_id, pos_logico, ttl);
        Ok(serde_json::json!({
            "created":    true,
            "ctx_id":     ctx.to_header(),
            "state":      "pending",
            "traceparent": ctx.traceparent,
            "nonce":      ctx.nonce,
            "ttl_seconds": ttl,
            "note": "dctx_id creado. BOS es el governor del Context Plane. bAuth solo valida e inyecta."
        }))
    }
}

/// bauth.ctx.validate — Validar ctx_id activo.
pub struct CtxValidateEnhancedHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for CtxValidateEnhancedHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_header = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_header.is_empty() {
            return Ok(serde_json::json!({"valid": false, "reason": "ctx_id vacío — SBOS-049"}));
        }

        let ctx = match CtxEngine::validate_structure(ctx_header) {
            Ok(c)  => c,
            Err(e) => return Ok(serde_json::json!({"valid": false, "reason": e})),
        };

        let result = CtxEngine::validate_active(&ctx);
        Ok(serde_json::json!({
            "valid":      result.valid,
            "ctx_id":     result.ctx_id,
            "state":      format!("{:?}", result.state),
            "tenant_id":  result.tenant_id,
            "user_id":    result.user_id,
            "reason":     result.reason,
            "traceparent": result.traceparent,
            "w3c_headers": if result.valid { CtxEngine::propagation_headers(&ctx) } else { vec![] },
        }))
    }
}

/// bauth.ctx.promote — Promover dctx_id → ctx_id post-autenticación.
/// Flujo:
///   1. Validar estructura del ctx_header → CtxPlane
///   2. CtxEngine::promote() transforma dctx_id → ctx_id
///   3. Computar bitmask desde privilege_atom_grant (G-12)
///   4. Registrar sesión en ses_session_log (DDL v2.12.0)
pub struct CtxPromoteHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for CtxPromoteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_header = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        let user_id = Uuid::parse_str(
            params.get("user_id").and_then(|v| v.as_str()).unwrap_or("")
        ).map_err(|_| JsonRpcError { code: -32602, message: "user_id requerido (UUID)".into(), data: None })?;

        if ctx_header.is_empty() {
            return Err(JsonRpcError { code: -32602, message: "ctx_id requerido".into(), data: None });
        }

        let ctx = CtxEngine::validate_structure(ctx_header)
            .map_err(|e| JsonRpcError { code: -32602, message: e, data: None })?;

        let tenant_id_str   = ctx.tenant_id.to_string();
        let empresa_id_str  = ctx.empresa_id.to_string();
        let sucursal_id_str = ctx.sucursal_id.map(|id| id.to_string()).unwrap_or_default();
        let pos_logico_str  = ctx.pos_logico.clone();
        let loa_current     = params.get("loa_current").and_then(|v| v.as_i64()).unwrap_or(1) as i32;
        let auth_method     = params.get("auth_method").and_then(|v| v.as_str()).unwrap_or("PASSWORD");
        let ip_address      = params.get("ip_address").and_then(|v| v.as_str());
        let user_agent      = params.get("user_agent").and_then(|v| v.as_str());

        let result = CtxEngine::promote(ctx, user_id);
        let traceparent = result.traceparent.clone().unwrap_or_default();

        // Computar bitmask del usuario vía privilege_atom_grant (G-12)
        let bitmask_b64 = if let Some(ref pg) = self.pg_pool {
            compute_user_bitmask(pg, user_id).await
        } else {
            String::new()
        };

        // Registrar sesión en ses_session_log (DDL v2.12.0)
        if let Some(ref pg) = self.pg_pool {
            let tenant_uuid = Uuid::parse_str(&tenant_id_str).ok();
            let loa_str = match loa_current {
                3 => "AAL3",
                2 => "AAL2",
                _ => "AAL1",
            };
            if let Some(tid) = tenant_uuid {
                let _ = sqlx::query(
                    "INSERT INTO bauth.ses_session_log
                        (tenant_id, user_id, auth_method, loa_initial, loa_peak,
                         ip_address, user_agent, ctx_id)
                     VALUES ($1, $2, $3, $4, $4, $5::inet, $6, $7)
                     ON CONFLICT (ctx_id) DO UPDATE SET last_active_at = now()"
                )
                .bind(tid)
                .bind(user_id)
                .bind(auth_method)
                .bind(loa_str)
                .bind(ip_address)
                .bind(user_agent)
                .bind(&result.ctx_id)
                .execute(pg)
                .await;
            }
        }

        tracing::info!(
            %user_id,
            ctx_id = %result.ctx_id,
            bitmask_len = bitmask_b64.len(),
            "ctx_id promovido — sesión registrada en ses_session_log"
        );

        Ok(serde_json::json!({
            "promoted":    result.valid,
            "ctx_id":      result.ctx_id,
            "state":       format!("{:?}", result.state),
            "user_id":     result.user_id,
            "tenant_id":   tenant_id_str,
            "empresa_id":  empresa_id_str,
            "sucursal_id": if sucursal_id_str.is_empty() { null_str() } else { &sucursal_id_str },
            "pos_logico":  pos_logico_str,
            "bitmask_b64": bitmask_b64,
            "loa_current": loa_current,
            "reason":      result.reason,
            "traceparent": traceparent,
        }))
    }
}

fn null_str() -> &'static str { "null" }

/// Computa el bitmask de átomos activos para el usuario vía privilege_atom_grant (G-12).
async fn compute_user_bitmask(pg: &sqlx::PgPool, user_id: Uuid) -> String {
    let positions: Vec<(i64,)> = sqlx::query_as(
        "SELECT DISTINCT rt.atom_position
         FROM bauth.privilege_atom_grant pag
         JOIN bauth.idn_roles_template rt
           ON rt.path = pag.atom_path
          AND rt.node_type = 'atom'
          AND rt.is_active = TRUE
         WHERE pag.user_id = $1
           AND (pag.general = TRUE AND pag.effect = TRUE
                OR pag.general = FALSE AND pag.access = TRUE)
           AND (pag.expires_at IS NULL OR pag.expires_at > now())
         ORDER BY rt.atom_position"
    )
    .bind(user_id)
    .fetch_all(pg)
    .await
    .unwrap_or_default();

    if positions.is_empty() { return String::new(); }

    let max_pos = positions.iter().map(|(p,)| *p as usize).max().unwrap_or(0);
    let byte_len = (max_pos / 8) + 1;
    let mut bits = vec![0u8; byte_len];

    for (pos,) in positions {
        if pos >= 0 {
            let byte_idx = (pos as usize) / 8;
            let bit_idx  = 7 - ((pos as usize) % 8);
            if byte_idx < bits.len() {
                bits[byte_idx] |= 1 << bit_idx;
            }
        }
    }

    base64::engine::general_purpose::STANDARD.encode(&bits)
}

/// bauth.ctx.invalidate — Invalidar ctx_id (logout/timeout).
pub struct CtxInvalidateHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for CtxInvalidateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_header = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_header.is_empty() {
            return Err(JsonRpcError { code: -32602, message: "ctx_id requerido".into(), data: None });
        }
        let ctx = CtxEngine::validate_structure(ctx_header)
            .map_err(|_| JsonRpcError { code: -32602, message: "ctx_id con estructura inválida".into(), data: None })?;
        let result = CtxEngine::invalidate(&ctx);
        Ok(serde_json::json!({
            "invalidated": result.valid,
            "ctx_id":      result.ctx_id,
            "state":       "invalidated",
            "reason":      result.reason,
            "idempotent":  true,
        }))
    }
}

/// bauth.ctx.propagate — Generar headers W3C para propagación entre daemons.
pub struct CtxPropagateHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for CtxPropagateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_header = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_header.is_empty() {
            return Err(JsonRpcError { code: -32602, message: "ctx_id requerido".into(), data: None });
        }
        let ctx = CtxEngine::validate_structure(ctx_header)
            .map_err(|_| JsonRpcError { code: -32602, message: "ctx_id con estructura inválida".into(), data: None })?;
        let headers = CtxEngine::propagation_headers(&ctx);
        Ok(serde_json::json!({
            "ctx_id":      ctx.to_header(),
            "w3c_headers": headers.iter().map(|(k, v)| serde_json::json!({"name": k, "value": v})).collect::<Vec<_>>(),
            "is_active":   ctx.is_active(),
        }))
    }
}

/// bauth.ctx.get_session — Obtener sesión activa desde ses_session_log.
pub struct CtxGetSessionHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for CtxGetSessionHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() {
            return Err(JsonRpcError { code: -32602, message: "ctx_id requerido".into(), data: None });
        }

        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let row = query_session(pg, ctx_id).await?;

        Ok(serde_json::json!({
            "ctx_id":       row.ctx_id,
            "tenant_id":    row.tenant_id.to_string(),
            "user_id":      row.user_id.to_string(),
            "auth_method":  row.auth_method,
            "loa_initial":  row.loa_initial,
            "loa_peak":     row.loa_peak,
            "ip_address":   row.ip_address,
            "user_agent":   row.user_agent,
            "started_at":   row.started_at.to_rfc3339(),
            "last_active":  row.last_active_at.to_rfc3339(),
        }))
    }
}

/// Fila de sesión mapeada desde ses_session_log (DDL v2.12.0).
#[derive(sqlx::FromRow)]
pub(crate) struct SessionRow {
    pub ctx_id:         String,
    pub tenant_id:      uuid::Uuid,
    pub user_id:        uuid::Uuid,
    pub auth_method:    String,
    pub loa_initial:    String,
    pub loa_peak:       String,
    pub ip_address:     Option<String>,
    pub user_agent:     Option<String>,
    pub started_at:     chrono::DateTime<chrono::Utc>,
    pub last_active_at: chrono::DateTime<chrono::Utc>,
}

/// Consulta ses_session_log por ctx_id. Retorna error si no existe o está terminada.
pub(crate) async fn query_session(
    pg: &sqlx::PgPool,
    ctx_id: &str,
) -> Result<SessionRow, JsonRpcError> {
    sqlx::query_as::<_, SessionRow>(
        "SELECT ctx_id, tenant_id, user_id, auth_method, loa_initial, loa_peak,
                ip_address::text, user_agent, started_at, last_active_at
         FROM bauth.ses_session_log
         WHERE ctx_id = $1 AND terminated_at IS NULL"
    )
    .bind(ctx_id)
    .fetch_optional(pg)
    .await
    .map_err(|e| JsonRpcError {
        code: -32000, message: format!("error consultando ses_session_log: {}", e), data: None,
    })?
    .ok_or_else(|| JsonRpcError {
        code: -32003,
        message: format!("ctx_id '{}' no encontrado o sesión terminada", ctx_id),
        data: None,
    })
}
