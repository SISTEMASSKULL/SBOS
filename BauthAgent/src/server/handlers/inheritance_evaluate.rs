// ============================================================
// bauth::server::handlers::inheritance_evaluate — H-16 Herencia DAG
//
// Handlers:
//   bauth.inheritance.compute — máscara efectiva con herencia DAG
//   bauth.inheritance.check   — verificar si un ancestro hereda de un descendiente
//
// La herencia opera como OR transitivo sobre el RolBitMask:
//   mask_eff(senior) = mask_own(senior) | mask_eff(junior)
//
// DOC-SBOS-001 N3 · B1.T09 · MANUAL-PRIVILEGIOS §6
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use tracing::info;

/// Handler: bauth.inheritance.compute
/// Calcula la máscara efectiva de un role_id considerando TODA su cadena de herencia.
pub struct InheritanceComputeHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for InheritanceComputeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let role_id = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "role_id requerido (texto)".into(), data: None,
            })?;

        // Cargar ancestros desde closure table
        let ancestors = crate::db::load_role_ancestors(pg, role_id)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000, message: format!("error cargando ancestros: {}", e), data: None,
            })?;

        // Calcular máscara efectiva con herencia
        let effective_mask = crate::bitmask::resolver::inherit_from_parents(pg, role_id)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000, message: format!("error computando herencia: {}", e), data: None,
            })?;

        let active: Vec<usize> = effective_mask.active_positions().collect();

        info!(
            role_id = %role_id,
            ancestros = ancestors.len(),
            atomos_propios = active.len(),
            "máscara efectiva computada con herencia DAG"
        );

        Ok(serde_json::json!({
            "role_id": role_id,
            "ancestros": ancestors,
            "profundidad_herencia": ancestors.len(),
            "atomos_efectivos": active.len(),
            "mascara_efectiva_base64": effective_mask.to_base64(),
        }))
    }
}

/// Handler: bauth.inheritance.check
/// Verifica si un rol (ancestro) hereda de otro (descendiente) vía closure table.
pub struct InheritanceCheckHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for InheritanceCheckHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let ancestro_id = params.get("ancestro_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "ancestro_id requerido".into(), data: None,
            })?;

        let descendiente_id = params.get("descendiente_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "descendiente_id requerido".into(), data: None,
            })?;

        #[derive(sqlx::FromRow)]
        struct ClosureRow {
            profundidad: i32,
        }

        let row: Option<ClosureRow> = sqlx::query_as(
            "SELECT profundidad FROM bauth.idn_role_closure
             WHERE ancestro_id = $1 AND descendiente_id = $2 AND profundidad >= 1"
        )
        .bind(ancestro_id)
        .bind(descendiente_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando herencia: {}", e), data: None,
        })?;

        match row {
            Some(r) => Ok(serde_json::json!({
                "hereda": true,
                "ancestro_id": ancestro_id,
                "descendiente_id": descendiente_id,
                "profundidad": r.profundidad,
                "mensaje": format!("{} hereda de {} (distancia: {} niveles)", ancestro_id, descendiente_id, r.profundidad),
            })),
            None => Ok(serde_json::json!({
                "hereda": false,
                "ancestro_id": ancestro_id,
                "descendiente_id": descendiente_id,
                "mensaje": format!("{} NO hereda de {}", ancestro_id, descendiente_id),
            })),
        }
    }
}
