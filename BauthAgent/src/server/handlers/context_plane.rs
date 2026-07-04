// ============================================================
// bauth::server::handlers::context_plane — B16 Context Plane handlers
//
// bauth.ctx.create     → Crear dctx_id (pre-auth, delegado a BOS)
// bauth.ctx.validate   → Validar ctx_id activo (PDP en tiempo real)
// bauth.ctx.promote    → Promover dctx_id → ctx_id post-auth
// bauth.ctx.invalidate → Invalidar ctx_id (logout/timeout)
// bauth.ctx.propagate  → Headers W3C Trace Context + OTel Baggage
// ============================================================
use crate::context::engine::CtxEngine;
use crate::context::plane::CtxPlane;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use uuid::Uuid;

/// bauth.ctx.create — Crear dctx_id pre-auth.
/// NOTA: BOS es el governor del ctx_id. bAuth crea bajo delegación de BOS.
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
        let pos_logico = params.get("pos_logico").and_then(|v| v.as_str()).unwrap_or("default");
        let ttl = params.get("ttl_seconds").and_then(|v| v.as_u64()).unwrap_or(3600);

        let ctx = CtxPlane::new_pending(tenant_id, empresa_id, sucursal_id, pos_logico, ttl);
        Ok(serde_json::json!({
            "created": true,
            "ctx_id": ctx.to_header(),
            "state": "pending",
            "traceparent": ctx.traceparent,
            "nonce": ctx.nonce,
            "ttl_seconds": ttl,
            "note": "dctx_id creado. BOS es el governor del Context Plane. bAuth solo valida e inyecta."
        }))
    }
}

/// bauth.ctx.validate — Validar ctx_id activo (mejorado con W3C + anti-replay).
pub struct CtxValidateEnhancedHandler;
#[async_trait::async_trait]
impl JsonRpcHandler for CtxValidateEnhancedHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_header = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_header.is_empty() {
            return Ok(serde_json::json!({"valid": false, "reason": "ctx_id vacío — SBOS-049 requiere ctx_id en cada request"}));
        }

        let ctx = match CtxEngine::validate_structure(ctx_header) {
            Ok(c) => c,
            Err(e) => return Ok(serde_json::json!({"valid": false, "reason": e})),
        };

        let result = CtxEngine::validate_active(&ctx);
        Ok(serde_json::json!({
            "valid": result.valid,
            "ctx_id": result.ctx_id,
            "state": format!("{:?}", result.state),
            "tenant_id": result.tenant_id,
            "user_id": result.user_id,
            "reason": result.reason,
            "traceparent": result.traceparent,
            "w3c_headers": if result.valid {
                CtxEngine::propagation_headers(&ctx)
            } else { vec![] },
        }))
    }
}

/// bauth.ctx.promote — Promover dctx_id → ctx_id post-autenticación.
///
/// Flujo corregido (B-BAUTH-001 + B-BAUTH-002, 2026-06-28):
///   1. Validar estructura del ctx_header → CtxPlane
///   2. Extraer datos organizacionales ANTES de mover ctx
///   3. CtxEngine::promote() transforma dctx_id → ctx_id
///   4. Computar bitmask_hex desde privilege_role_atom (compute_rol_bitmask)
///   5. Persistir en ses_context con TODOS los datos correctos
///   6. Retornar ctx_id, bitmask_hex, y metadatos al caller
///
/// Si hay conexión a BD, persiste en ses_context para que context.evaluate
/// y el reconcile loop encuentren la sesión.
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

        // ── B-BAUTH-001: Extraer datos organizacionales ANTES de mover ctx ──
        let tenant_id_str   = ctx.tenant_id.to_string();
        let empresa_id_str  = ctx.empresa_id.to_string();
        let sucursal_id_str = ctx.sucursal_id.map(|id| id.to_string()).unwrap_or_default();
        let pos_logico_str  = ctx.pos_logico.clone();
        let session_kc      = params.get("session_kc").and_then(|v| v.as_str())
            .unwrap_or("bauthctl-promote").to_string();
        let loa_current     = params.get("loa_current").and_then(|v| v.as_i64()).unwrap_or(1) as i32;

        let result = CtxEngine::promote(ctx, user_id);
        let traceparent = result.traceparent.clone().unwrap_or_default();

        // ── B-BAUTH-002: Computar bitmask real del usuario ──
        let bitmask_hex = if let Some(ref pg) = self.pg_pool {
            compute_user_bitmask_for_promote(pg, user_id).await
        } else {
            String::new()
        };

        // Persistir en ses_context para que context.evaluate lo encuentre
        if let Some(ref pg) = self.pg_pool {
            let _ = sqlx::query(
                "INSERT INTO bauth.ses_context (ctx_id, tenant_id, empresa_id, sucursal_id,
                 pos_logico, user_uuid, session_kc, bitmask_hex, loa_current,
                 state, traceparent, created_at, expires_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
                         UPPER('active'), $10, now(), now() + interval '1 hour')
                 ON CONFLICT (ctx_id) DO UPDATE SET
                   user_uuid   = EXCLUDED.user_uuid,
                   empresa_id  = EXCLUDED.empresa_id,
                   sucursal_id = EXCLUDED.sucursal_id,
                   pos_logico  = EXCLUDED.pos_logico,
                   bitmask_hex = EXCLUDED.bitmask_hex,
                   loa_current = EXCLUDED.loa_current,
                   state       = UPPER('active'),
                   traceparent = EXCLUDED.traceparent,
                   expires_at  = now() + interval '1 hour'"
            )
            .bind(&result.ctx_id)
            .bind(&tenant_id_str)
            .bind(&empresa_id_str)
            .bind(&sucursal_id_str)
            .bind(&pos_logico_str)
            .bind(user_id)
            .bind(&session_kc)
            .bind(&bitmask_hex)
            .bind(loa_current)
            .bind(&traceparent)
            .execute(pg).await;
        }

        tracing::info!(
            %user_id,
            ctx_id = %result.ctx_id,
            bitmask_len = bitmask_hex.len(),
            "ctx_id promovido — datos organizacionales y bitmask persistidos"
        );

        Ok(serde_json::json!({
            "promoted": result.valid,
            "ctx_id": result.ctx_id,
            "state": format!("{:?}", result.state),
            "user_id": result.user_id,
            "tenant_id": tenant_id_str,
            "empresa_id": empresa_id_str,
            "sucursal_id": if sucursal_id_str.is_empty() { "null" } else { &sucursal_id_str },
            "pos_logico": pos_logico_str,
            "bitmask_hex": bitmask_hex,
            "bitmask_len": bitmask_hex.len(),
            "loa_current": loa_current,
            "reason": result.reason,
            "traceparent": traceparent,
        }))
    }
}

/// B-BAUTH-002: Computa el bitmask efectivo para un usuario.
///
/// Flujo:
///   1. Consulta idn_user_template.rol_ids (TEXT[]) para obtener los slugs de rol
///   2. Para cada slug, busca el role_id en privilege_role
///   3. Para cada role_id, invoca compute_rol_bitmask() desde privilege_role_atom
///   4. Hace OR de todas las máscaras (merge de RolBitMask)
///   5. Retorna base64 de la máscara fusionada
///
/// Si el usuario no tiene roles → bitmask vacío (no es error).
async fn compute_user_bitmask_for_promote(
    pg: &sqlx::PgPool,
    user_uuid: Uuid,
) -> String {
    // Paso 1: Obtener slugs de rol desde idn_user_template.rol_ids (TEXT[])
    #[derive(sqlx::FromRow)]
    struct UserRolSlugs {
        rol_ids: Vec<String>,
    }

    let row = match sqlx::query_as::<_, UserRolSlugs>(
        "SELECT rol_ids FROM bauth.idn_user_template WHERE uuid = $1"
    )
    .bind(user_uuid)
    .fetch_optional(pg).await
    {
        Ok(Some(r)) => r,
        Ok(None) => {
            tracing::info!(%user_uuid, "usuario no encontrado en idn_user_template");
            return String::new();
        }
        Err(e) => {
            tracing::warn!(%user_uuid, error = %e, "no se pudo consultar idn_user_template");
            return String::new();
        }
    };

    let slugs = row.rol_ids;
    if slugs.is_empty() {
        tracing::info!(%user_uuid, "usuario sin roles asignados — bitmask vacío");
        return String::new();
    }

    // Paso 2: Resolver slug → role_id y computar bitmask para cada rol
    let mut masks: Vec<crate::bitmask::RolBitMask> = Vec::new();
    for slug in &slugs {
        #[derive(sqlx::FromRow)]
        struct RoleIdRow { role_id: Uuid }

        let role_id = match sqlx::query_as::<_, RoleIdRow>(
            "SELECT role_id FROM bauth.privilege_role WHERE role_slug = $1"
        )
        .bind(slug)
        .fetch_optional(pg).await
        {
            Ok(Some(r)) => r.role_id,
            Ok(None) => {
                tracing::debug!(%slug, "slug de rol no encontrado en privilege_role");
                continue;
            }
            Err(e) => {
                tracing::warn!(%slug, error = %e, "error buscando role_id por slug");
                continue;
            }
        };

        match crate::bitmask::resolver::compute_rol_bitmask(pg, role_id).await {
            Ok(mask) if mask.count_active() > 0 => {
                masks.push(mask);
            }
            Ok(_) => {
                tracing::debug!(%role_id, %slug, "rol sin átomos — omitido");
            }
            Err(e) => {
                tracing::warn!(%role_id, %slug, error = %e, "error computando bitmask de rol");
            }
        }
    }

    if masks.is_empty() {
        tracing::info!(%user_uuid, slugs = slugs.len(), "ningún rol con átomos — bitmask vacío");
        return String::new();
    }

    // Paso 3: Merge OR de todas las máscaras
    let refs: Vec<&crate::bitmask::RolBitMask> = masks.iter().collect();
    let merged = crate::bitmask::RolBitMask::merge(&refs)
        .unwrap_or_else(|| crate::bitmask::RolBitMask::with_capacity(5808));

    let active = merged.count_active();
    let encoded = merged.to_base64();
    tracing::info!(%user_uuid, roles = slugs.len(), active_atoms = active, "bitmask computado para promote");
    encoded
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
            "ctx_id": result.ctx_id,
            "state": "invalidated",
            "reason": result.reason,
            "idempotent": true,
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
            "ctx_id": ctx.to_header(),
            "w3c_headers": headers.iter().map(|(k, v)| serde_json::json!({"name": k, "value": v})).collect::<Vec<_>>(),
            "is_active": ctx.is_active(),
        }))
    }
}

// ============================================================
// bauth.ctx.get_session — B-BAUTH-004 (C-BOS-006)
//
// Devuelve los datos completos de una sesión activa desde ses_context.
// Alternativa ligera a context.evaluate cuando solo se necesitan datos
// de sesión sin evaluación de dominios.
//
// Request:  {"method": "bauth.ctx.get_session", "params": {"ctx_id": "..."}}
// Response: {ctx_id, tenant_id, empresa_id, sucursal_id, pos_logico,
//            user_uuid, bitmask_hex, loa_current, traceparent, state,
//            device_id, device_hostname, device_ip, session_kc,
//            created_at, expires_at}
// ============================================================

pub struct CtxGetSessionHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for CtxGetSessionHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() {
            return Err(JsonRpcError {
                code: -32602, message: "ctx_id requerido".into(), data: None,
            });
        }

        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let row = query_session(pg, ctx_id).await?;

        Ok(serde_json::json!({
            "ctx_id":           row.ctx_id,
            "tenant_id":        row.tenant_id,
            "empresa_id":       row.empresa_id,
            "sucursal_id":      row.sucursal_id,
            "pos_logico":       row.pos_logico,
            "user_uuid":        row.user_uuid.map(|u| u.to_string()),
            "bitmask_hex":      row.bitmask_hex,
            "loa_current":      row.loa_current,
            "traceparent":      row.traceparent,
            "state":            row.state,
            "device_id":        row.device_id,
            "device_hostname":  row.device_hostname,
            "device_ip":        row.device_ip,
            "session_kc":       row.session_kc,
            "created_at":       row.created_at.map(|d| d.to_rfc3339()),
            "expires_at":       row.expires_at.map(|d| d.to_rfc3339()),
        }))
    }
}

// ── Query compartida: ses_context → SessionRow ─────────────────

#[derive(sqlx::FromRow)]
pub(crate) struct SessionRow {
    pub ctx_id:          String,
    pub tenant_id:       String,
    pub empresa_id:      String,
    pub sucursal_id:     Option<String>,
    pub pos_logico:      Option<String>,
    pub user_uuid:       Option<uuid::Uuid>,
    pub bitmask_hex:     String,
    pub loa_current:     i32,
    pub traceparent:     Option<String>,
    pub state:           String,
    pub device_id:       Option<String>,
    pub device_hostname: Option<String>,
    pub device_ip:       Option<String>,
    pub session_kc:      String,
    pub created_at:      Option<chrono::DateTime<chrono::Utc>>,
    pub expires_at:      Option<chrono::DateTime<chrono::Utc>>,
}

/// Consulta ses_context por ctx_id. Retorna error si no existe o expiró.
pub(crate) async fn query_session(
    pg: &sqlx::PgPool,
    ctx_id: &str,
) -> Result<SessionRow, JsonRpcError> {
    sqlx::query_as::<_, SessionRow>(
        "SELECT ctx_id, tenant_id, empresa_id, sucursal_id, pos_logico,
                user_uuid, bitmask_hex, loa_current, traceparent, state,
                device_id, device_hostname, device_ip, session_kc,
                created_at, expires_at
         FROM bauth.ses_context
         WHERE ctx_id = $1 AND state = 'ACTIVE' AND expires_at > now()"
    )
    .bind(ctx_id)
    .fetch_optional(pg).await
    .map_err(|e| JsonRpcError {
        code: -32000, message: format!("error consultando ses_context: {}", e), data: None,
    })?
    .ok_or_else(|| JsonRpcError {
        code: -32003,
        message: format!("ctx_id '{}' no encontrado, expirado o no activo", ctx_id),
        data: None,
    })
}
