// ============================================================
// bauth::server::handlers::inheritance_evaluate — Herencia DAG
//
// Handlers:
//   bauth.inheritance.compute — máscara efectiva con herencia DAG
//   bauth.inheritance.check   — verificar si un rol hereda de otro
//
// Fuente canónica: bauth.idn_roles_rol_closure (DDL v2.12.0)
//   Columnas canónicas: ancestor_id, descendant_id, depth, is_active
//
// Eliminado: idn_role_closure (phantom — columnas legacy:
//            ancestro_id, descendiente_id, profundidad)
//
// DOC-SBOS-001 N3 · B1.T09 · SBOS-049
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use tracing::info;

/// Handler: bauth.inheritance.compute
///
/// Calcula la máscara efectiva de un role_id considerando su cadena de herencia.
/// Fuente: `bauth.idn_roles_rol_closure` (closure table canónica).
pub struct InheritanceComputeHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for InheritanceComputeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000,
            message: "base de datos no disponible".into(),
            data: None,
        })?;

        let role_id_str = params.get("role_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "role_id requerido".into(),
                data: None,
            })?;

        let role_id = uuid::Uuid::parse_str(role_id_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("role_id inválido: {}", role_id_str),
            data: None,
        })?;

        // Cargar ancestros desde closure table canónica
        let ancestors = crate::db::load_role_ancestors(pg, role_id)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error cargando ancestros: {}", e),
                data: None,
            })?;

        // Calcular máscara efectiva con herencia
        let effective_mask = crate::bitmask::resolver::inherit_from_parents(pg, role_id)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error computando herencia: {}", e),
                data: None,
            })?;

        let active: Vec<usize> = effective_mask.active_positions().collect();
        let ancestors_str: Vec<String> = ancestors.iter().map(|id| id.to_string()).collect();

        info!(
            role_id = %role_id,
            ancestros = ancestors.len(),
            atomos_efectivos = active.len(),
            "máscara efectiva computada con herencia DAG"
        );

        Ok(serde_json::json!({
            "role_id":                role_id_str,
            "ancestros":              ancestors_str,
            "profundidad_herencia":   ancestors.len(),
            "atomos_efectivos":       active.len(),
            "mascara_efectiva_base64": effective_mask.to_base64(),
        }))
    }
}

/// Handler: bauth.inheritance.check
///
/// Verifica si un rol hereda de otro vía closure table canónica.
/// Fuente: `bauth.idn_roles_rol_closure` (columnas: ancestor_id, descendant_id, depth).
pub struct InheritanceCheckHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for InheritanceCheckHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000,
            message: "base de datos no disponible".into(),
            data: None,
        })?;

        let ancestor_str = params.get("ancestro_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "ancestro_id requerido".into(),
                data: None,
            })?;

        let descendant_str = params.get("descendiente_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: "descendiente_id requerido".into(),
                data: None,
            })?;

        let ancestor_id = uuid::Uuid::parse_str(ancestor_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("ancestro_id inválido: {}", ancestor_str),
            data: None,
        })?;

        let descendant_id = uuid::Uuid::parse_str(descendant_str).map_err(|_| JsonRpcError {
            code: -32602,
            message: format!("descendiente_id inválido: {}", descendant_str),
            data: None,
        })?;

        // Consulta canónica: idn_roles_rol_closure (columnas: ancestor_id, descendant_id, depth)
        #[derive(sqlx::FromRow)]
        struct ClosureRow {
            depth: i32,
        }

        let row: Option<ClosureRow> = sqlx::query_as(
            r#"
            SELECT depth
            FROM bauth.idn_roles_rol_closure
            WHERE ancestor_id   = $1
              AND descendant_id = $2
              AND depth         >= 1
              AND is_active     = TRUE
            "#,
        )
        .bind(ancestor_id)
        .bind(descendant_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000,
            message: format!("error consultando closure: {}", e),
            data: None,
        })?;

        match row {
            Some(r) => Ok(serde_json::json!({
                "hereda":          true,
                "ancestro_id":     ancestor_str,
                "descendiente_id": descendant_str,
                "profundidad":     r.depth,
                "mensaje": format!(
                    "{} hereda de {} (distancia: {} nivel/es)",
                    ancestor_str, descendant_str, r.depth
                ),
            })),
            None => Ok(serde_json::json!({
                "hereda":          false,
                "ancestro_id":     ancestor_str,
                "descendiente_id": descendant_str,
                "mensaje": format!("{} NO hereda de {}", ancestor_str, descendant_str),
            })),
        }
    }
}
