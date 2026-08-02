// ============================================================
// bauth::server::handlers::token_refresh — B48.T05
//
// Handler: bauth.token.refresh
// Rota el token JWT re-evaluando el bitmask desde BD para detectar
// cambios de privilegios desde la emisión original.
//
// Flujo de seguridad:
//   1. Verifica firma Ed25519 del token (JwtSigner::verify)
//   2. Extrae sub (user_id) y ctx_id
//   3. Verifica que el usuario sigue ACTIVE en idn_user
//   4. Re-computa bitmask desde privilege_atom_grant (G-12 fresco)
//   5. Obtiene TTL desde auth_policy del tenant
//   6. Actualiza last_active_at en ses_session_log
//   7. Emite nuevo token con bitmask actualizado y exp fresco
//
// Tablas canónicas DDL v2.12.0:
//   bauth.idn_user             — verificación de estado ACTIVE
//   bauth.privilege_atom_grant — bitmask G-12 re-evaluado
//   bauth.idn_roles_template   — atom_position (resolver verb→bit)
//   bauth.auth_policy          — TTL del tenant
//   bauth.ses_session_log      — actualización last_active_at
//
// DOC-SBOS-001 N3 · RFC 7519 · NIST SP 800-63B · OAuth 2.0 RFC 6749
// ============================================================

use super::token_issue::{computar_bitmask, registrar_sesion};
use crate::config::JwtConfig;
use crate::db::count_atoms;
use crate::domain::jwt_signer::JwtSigner;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(code: i32, msg: &str) -> JsonRpcError {
    JsonRpcError { code, message: msg.into(), data: None }
}

/// Handler: bauth.token.refresh
/// Re-emite el token JWT verificando estado del usuario y recomputando bitmask.
pub struct TokenRefreshHandler {
    pub signer:  Arc<JwtSigner>,
    pub jwt_cfg: JwtConfig,
    pub pg:      Option<PgPool>,
}

#[async_trait]
impl JsonRpcHandler for TokenRefreshHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg.as_ref().ok_or_else(|| err(-32000, "base de datos no disponible"))?;

        let token = params.get("token").and_then(|v| v.as_str())
            .ok_or_else(|| err(-32602, "se requiere 'token'"))?;

        // ── 1. Verificar firma Ed25519 (JwtSigner::verify NO verifica exp) ─────
        let claims = self.signer.verify(token).map_err(|e| {
            tracing::warn!(error = %e, "token.refresh — firma inválida");
            err(-32001, &format!("token con firma inválida: {}", e))
        })?;

        // ── 2. Extraer identidad del token ────────────────────────────────────
        let user_id_str = claims.get("sub").and_then(|v| v.as_str())
            .ok_or_else(|| err(-32602, "token sin claim 'sub'"))?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| err(-32602, "sub inválido: no es UUID"))?;

        let ctx_id = claims.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // ── 3. Verificar usuario sigue ACTIVE en BD ───────────────────────────
        let usuario: Option<(uuid::Uuid, String)> = sqlx::query_as(
            "SELECT tenant_id, status::text FROM bauth.idn_user WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| err(-32000, &format!("error consultando usuario: {}", e)))?;

        let (tenant_id, status) = usuario
            .ok_or_else(|| err(-32401, "usuario no encontrado"))?;

        if status != "ACTIVE" {
            tracing::warn!(%user_id, %status, "token.refresh — usuario no activo");
            return Err(err(-32401, &format!("usuario no activo: {}", status)));
        }

        // ── 4. Re-computar bitmask desde BD (captura cambios de privilegios) ──
        let total_atoms = count_atoms(pg).await
            .map_err(|e| err(-32000, &format!("error contando átomos: {}", e)))?;
        let bitmask_len = (total_atoms as usize + 7) / 8;
        let bitmask_b64 = computar_bitmask(pg, user_id, bitmask_len).await?;

        // ── 5. Obtener TTL desde política del tenant ──────────────────────────
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
        let ttl = max_session_secs
            .unwrap_or(self.jwt_cfg.default_ttl_seconds as i32) as i64;

        // ── 6. Actualizar last_active_at en ses_session_log ───────────────────
        // PostgreSQL no soporta LIMIT en UPDATE — se usa CTE para seleccionar
        // la sesión más reciente del contexto antes de actualizar.
        let filas_actualizadas = sqlx::query(
            "WITH target AS (
                 SELECT session_id FROM bauth.ses_session_log
                 WHERE ctx_id = $1 AND user_id = $2 AND terminated_at IS NULL
                 ORDER BY started_at DESC LIMIT 1
             )
             UPDATE bauth.ses_session_log SET last_active_at = now()
             WHERE session_id IN (SELECT session_id FROM target)"
        )
        .bind(ctx_id)
        .bind(user_id)
        .execute(pg)
        .await
        .map_err(|e| err(-32000, &format!("error actualizando sesión: {}", e)))?
        .rows_affected();

        let loa_str = claims.get("loa").and_then(|v| v.as_str()).unwrap_or("AAL1");
        if filas_actualizadas == 0 {
            // La sesión fue eliminada o expirada — registrar nueva fila
            registrar_sesion(pg, user_id, tenant_id, ctx_id, "TOKEN_REFRESH", loa_str).await?;
        }

        // ── 7. Construir y firmar nuevo token con bitmask actualizado ─────────
        let now = chrono::Utc::now().timestamp();
        let ial = claims.get("ial").cloned().unwrap_or(Value::Null);
        let username = claims.get("username").and_then(|v| v.as_str()).unwrap_or("");

        let new_claims = json!({
            "sub":          user_id.to_string(),
            "username":     username,
            "tenant":       tenant_id.to_string(),
            "iss":          &self.jwt_cfg.issuer,
            "iat":          now,
            "exp":          now + ttl,
            "ctx_id":       ctx_id,
            "bitmask":      bitmask_b64,
            "loa":          loa_required,
            "ial":          ial,
            "refreshed_at": chrono::Utc::now().to_rfc3339(),
        });

        let signed = self.signer.sign(&new_claims)
            .map_err(|e| err(-32002, &format!("firma JWT falló: {}", e)))?;

        tracing::info!(%user_id, %ctx_id, "token.refresh — token renovado con bitmask actualizado");

        Ok(json!({
            "access_token": signed.jwt,
            "token_type":   "Bearer",
            "expires_at":   now + ttl,
            "user_uuid":    user_id.to_string(),
            "ctx_id":       ctx_id,
        }))
    }
}
