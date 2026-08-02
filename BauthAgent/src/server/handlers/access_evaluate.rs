// ============================================================
// bauth::server::handlers::access_evaluate — bauth.access.evaluate
//
// Handler JSON-RPC: evalúa si un usuario puede ejecutar una operación.
//
// Pipeline canónico (DDL v2.12.0):
//   1. Resolver operation/resource → privilege_resource_atom
//   2. Verificar usuario en idn_user (status = ACTIVE)
//   3. Fast-Path: evaluation_path = 'FAST' → PERMITIDO (bitmask pendiente)
//   4. Policy-Path: evaluation_path = 'POLICY' → PENDIENTE (D01)
//
// Pendiente: cómputo real de RolBitMask cuando idn_roles_template
//            tenga átomos a depth=3 (migración B35).
//
// Eliminado:
//   - privilege_atom (phantom) → privilege_resource_atom
//   - idn_user_template (phantom D03) → idn_user
//   - privilege_role_atom (phantom) → sin equivalente
//   - privilege_atom_policy (phantom D05b) → sin equivalente
//
// DOC-SBOS-001 N3 · B1.T06 · SBOS-049
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

/// Información del átomo desde `privilege_resource_atom`.
#[derive(sqlx::FromRow)]
struct AtomInfo {
    pub id:              uuid::Uuid,
    pub resource:        String,
    pub operation:       String,
    pub domain_code:     i16,
    pub evaluation_path: String,
    pub obligation:      Option<serde_json::Value>,
}

/// Información del usuario desde `idn_user`.
#[derive(sqlx::FromRow)]
struct UserInfo {
    pub user_id:     uuid::Uuid,
    pub username:    String,
    pub status:      String,
    pub loa_min:     String,
    pub ial_achieved: Option<String>,
}

pub struct AccessEvaluateHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for AccessEvaluateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000,
            message: "base de datos no disponible".into(),
            data: None,
        })?;

        // ── Parámetros obligatorios ──────────────────────────
        let operation_slug = params.get("atom_slug")
            .or_else(|| params.get("operation"))
            .and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "atom_slug u operation requerido".into(),
                data: None,
            })?;

        let user_uuid_str = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "user_uuid requerido".into(),
                data: None,
            })?;

        let user_uuid = uuid::Uuid::parse_str(user_uuid_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("user_uuid inválido: {}", user_uuid_str),
            data: None,
        })?;

        let tenant_id_str = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "tenant_id requerido".into(),
                data: None,
            })?;

        let tenant_id = uuid::Uuid::parse_str(tenant_id_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("tenant_id inválido: {}", tenant_id_str),
            data: None,
        })?;

        // ── PASO 1: Resolver operación → privilege_resource_atom ──
        let atom: Option<AtomInfo> = sqlx::query_as(
            r#"
            SELECT id, resource, operation, domain_code, evaluation_path, obligation
            FROM bauth.privilege_resource_atom
            WHERE tenant_id = $1
              AND operation  = $2
              AND status     = 'ACTIVE'
            LIMIT 1
            "#,
        )
        .bind(tenant_id)
        .bind(operation_slug)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000,
            message: format!("error consultando átomo: {}", e),
            data: None,
        })?;

        let atom = match atom {
            Some(a) => a,
            None => {
                return Ok(serde_json::json!({
                    "veredicto":   "DENEGADO",
                    "motivo":      format!("operación '{}' no encontrada o inactiva", operation_slug),
                    "operation":   operation_slug,
                    "evaluacion_completa": true
                }));
            }
        };

        // ── PASO 2: Verificar usuario en idn_user ─────────────
        let user: Option<UserInfo> = sqlx::query_as(
            r#"
            SELECT user_id, username, status::text AS status,
                   loa_min, ial_achieved
            FROM bauth.idn_user
            WHERE user_id   = $1
              AND tenant_id = $2
            "#,
        )
        .bind(user_uuid)
        .bind(tenant_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000,
            message: format!("error buscando usuario: {}", e),
            data: None,
        })?;

        let user = match user {
            Some(u) => u,
            None => {
                return Ok(serde_json::json!({
                    "veredicto":   "DENEGADO",
                    "motivo":      "usuario no encontrado en este tenant",
                    "user_uuid":   user_uuid_str,
                    "tenant_id":   tenant_id_str,
                    "evaluacion_completa": true
                }));
            }
        };

        if user.status != "ACTIVE" {
            return Ok(serde_json::json!({
                "veredicto":   "DENEGADO",
                "motivo":      format!("usuario en estado {}", user.status),
                "user_uuid":   user_uuid_str,
                "username":    user.username,
                "evaluacion_completa": true
            }));
        }

        // ── PASO 3: Evaluación según evaluation_path ──────────
        //
        // Fast-Path ('FAST'): acceso por BitMask precomputado.
        //   Pendiente hasta que idn_roles_template tenga átomos depth=3.
        //   Por ahora: PERMITIDO si el usuario está activo.
        //
        // Policy-Path ('POLICY'): requiere evaluación XACML/ABAC completa.
        //   Pendiente implementación de auth_policy (D01).
        //
        let (veredicto, motivo) = match atom.evaluation_path.as_str() {
            "FAST" => (
                "PERMITIDO",
                format!(
                    "FastPath: usuario activo, operación '{}' en dominio D{:02}",
                    operation_slug, atom.domain_code
                ),
            ),
            "POLICY" => (
                "PENDIENTE_EVALUACION",
                "PolicyPath: evaluación XACML/ABAC pendiente de implementación (D01)".to_string(),
            ),
            "PRECONDITION" => (
                "PENDIENTE_EVALUACION",
                "PreconditionPath: evaluación de precondición pendiente".to_string(),
            ),
            other => (
                "DENEGADO",
                format!("evaluation_path desconocido: {}", other),
            ),
        };

        Ok(serde_json::json!({
            "veredicto": veredicto,
            "motivo":    motivo,
            "atom": {
                "id":              atom.id,
                "resource":        atom.resource,
                "operation":       atom.operation,
                "domain_code":     atom.domain_code,
                "evaluation_path": atom.evaluation_path,
                "obligation":      atom.obligation
            },
            "user": {
                "user_id":     user.user_id,
                "username":    user.username,
                "status":      user.status,
                "loa_min":     user.loa_min,
                "ial_achieved": user.ial_achieved
            },
            "policies":       [],
            "policies_count": 0,
            "evaluacion_completa": true
        }))
    }
}
