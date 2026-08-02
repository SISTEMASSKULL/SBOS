// ============================================================
// bauth::server::handlers::token_issue — B48.T03
//
// Handler: bauth.token.issue
// Emite un JWT de bAuth con todos los claims del Identity Control Plane.
//
// Tablas canónicas DDL v2.12.0:
//   bauth.idn_user              — usuario (reemplaza idn_user_template)
//   bauth.idn_roles_template    — átomos (reemplaza privilege_atom)
//                                 nodos con node_type='atom', columna atom_position
//   bauth.privilege_atom_grant  — asignaciones G-12
//   bauth.ses_session_log       — sesiones abiertas
//   bauth.auth_policy           — política de autenticación del tenant
//
// Phantom D02 eliminado: aud_event no existe en DDL v2.12.0.
// Phantom D05 eliminado: privilege_role, privilege_atom, privilege_role_atom
//   → se usa idn_roles_template (path + atom_position).
// Phantom D03 eliminado: idn_user_template → idn_user.
//
// BitMask: se computa desde privilege_atom_grant (modelo G-12, 5 columnas)
//   referenciando idn_roles_template.atom_position.
//   Capacidad dinámica vía crate::db::count_atoms() — sin hardcode.
//
// DOC-SBOS-001 N3 · RFC 7519 · NIST SP 800-63B · OAuth 2.0 RFC 6749
// ============================================================

use crate::config::JwtConfig;
use crate::db::count_atoms;
use crate::domain::jwt_signer::JwtSigner;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use base64::Engine;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

// ── TokenIssueHandler ─────────────────────────────────

/// Handler: bauth.token.issue
/// Emite un JWT firmado con Ed25519 (JwtSigner) con los claims de identidad,
/// bitmask de roles y metadata de sesión.
pub struct TokenIssueHandler {
    pub pg_pool:  Option<PgPool>,
    pub signer:   Arc<JwtSigner>,
    pub jwt_cfg:  JwtConfig,
}

#[async_trait]
impl JsonRpcHandler for TokenIssueHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| err("base de datos no disponible"))?;

        let user_id_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| err("user_uuid requerido"))?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| err("user_uuid inválido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Obtener datos del usuario desde idn_user
        let user: Option<(uuid::Uuid, Option<uuid::Uuid>, String, String, Option<String>)> =
            sqlx::query_as(
                "SELECT user_id, tenant_id, username, status::text, ial_achieved::text
                 FROM bauth.idn_user WHERE user_id = $1"
            )
            .bind(user_id)
            .fetch_optional(pg)
            .await
            .map_err(|e| err(&e.to_string()))?;

        let (uid, tenant_id, username, status, ial) = user
            .ok_or_else(|| err("usuario no encontrado"))?;

        if status != "ACTIVE" {
            return Err(JsonRpcError {
                code: -32401,
                message: format!("usuario no activo: {}", status),
                data: None,
            });
        }

        let tenant_id = tenant_id.ok_or_else(|| err("usuario sin tenant_id"))?;

        // Capacidad de bitmask dinámica — sin hardcode
        let total_atoms = count_atoms(pg).await.map_err(|e| err(&e.to_string()))?;
        let bitmask_len = (total_atoms as usize + 7) / 8;

        let bitmask_b64 = computar_bitmask(pg, uid, bitmask_len).await?;

        // Obtener política del tenant (max_session_secs, loa_required)
        let policy: Option<(Option<i32>, String)> = sqlx::query_as(
            "SELECT max_session_secs, loa_required
             FROM bauth.auth_policy
             WHERE (tenant_id = $1 OR tenant_id IS NULL) AND active = TRUE
             ORDER BY tenant_id NULLS LAST LIMIT 1"
        )
        .bind(tenant_id)
        .fetch_optional(pg)
        .await
        .unwrap_or(None);

        let (max_session_secs, loa_required) = policy
            .unwrap_or((Some(self.jwt_cfg.default_ttl_seconds as i32), "AAL1".into()));
        let ttl = max_session_secs.unwrap_or(self.jwt_cfg.default_ttl_seconds as i32) as i64;

        // Registrar sesión en ses_session_log
        registrar_sesion(pg, uid, tenant_id, ctx_id).await?;

        // Construir claims y firmar con Ed25519 (JwtSigner)
        let now = chrono::Utc::now().timestamp();
        let claims = json!({
            "sub":      uid.to_string(),
            "username": username,
            "tenant":   tenant_id.to_string(),
            "iss":      &self.jwt_cfg.issuer,
            "iat":      now,
            "exp":      now + ttl,
            "ctx_id":   ctx_id,
            "bitmask":  bitmask_b64,
            "loa":      loa_required,
            "ial":      ial,
        });

        let signed = self.signer.sign(&claims)
            .map_err(|e| err(&format!("firma JWT falló: {}", e)))?;

        Ok(json!({
            "token":   signed.jwt,
            "expires": now + ttl,
            "ctx_id":  ctx_id,
        }))
    }
}

impl TokenIssueHandler {
    pub fn method_name() -> &'static str { "bauth.token.issue" }
}

// ── Bitmask ───────────────────────────────────────────

/// Computa el bitmask OR de todos los átomos activos para el usuario.
/// Modelo G-12: grants en privilege_atom_grant con 5 columnas.
/// atom_position desde idn_roles_template (DDL v2.12.0).
async fn computar_bitmask(
    pg: &PgPool,
    user_id: uuid::Uuid,
    bitmask_len: usize,
) -> Result<String, JsonRpcError> {
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

    let len = bitmask_len.max(1);
    let mut bits = vec![0u8; len];

    for (pos,) in positions {
        if pos >= 0 {
            let byte_idx = (pos as usize) / 8;
            let bit_idx  = 7 - ((pos as usize) % 8);
            if byte_idx < bits.len() {
                bits[byte_idx] |= 1 << bit_idx;
            }
        }
    }

    Ok(base64::engine::general_purpose::STANDARD.encode(&bits))
}

// ── Sesión ────────────────────────────────────────────

/// Registra o actualiza la sesión activa en ses_session_log.
async fn registrar_sesion(
    pg: &PgPool,
    user_id: uuid::Uuid,
    tenant_id: uuid::Uuid,
    ctx_id: &str,
) -> Result<(), JsonRpcError> {
    sqlx::query(
        "INSERT INTO bauth.ses_session_log
            (user_id, tenant_id, ctx_id, started_at, last_active_at)
         VALUES ($1, $2, $3, now(), now())
         ON CONFLICT (ctx_id) DO UPDATE SET last_active_at = now()"
    )
    .bind(user_id)
    .bind(tenant_id)
    .bind(ctx_id)
    .execute(pg)
    .await
    .map_err(|e| err(&e.to_string()))?;
    Ok(())
}
