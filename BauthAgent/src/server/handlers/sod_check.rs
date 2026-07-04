// ============================================================
// bauth::server::handlers::sod_check — H-17 SoD Conflict Check
//
// Handler: bauth.sod.check
// Verifica si añadir átomos a un rol crea conflictos SoD.
// Carga reglas desde fin_sod_rule (6 pares: 5 ALTO/BLOCK + 1 MEDIO/COMPENSATE).
//
// NIST AC-5 · SOX §404 · COSO Control Activities
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct SodCheckHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for SodCheckHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // Cargar átomos existentes del rol (si se proporciona role_id)
        let mut existing: Vec<usize> = Vec::new();
        if let Some(role_id_str) = params.get("role_id").and_then(|v| v.as_str()) {
            if let Ok(role_id) = uuid::Uuid::parse_str(role_id_str) {
                let atoms: Vec<i32> = sqlx::query_scalar(
                    "SELECT atom_position FROM bauth.privilege_role_atom
                     WHERE role_id = $1 AND allowed = TRUE ORDER BY atom_position"
                )
                .bind(role_id)
                .fetch_all(pg)
                .await
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error cargando átomos: {}", e), data: None,
                })?;
                existing = atoms.iter().map(|&a| a as usize).collect();
            }
        }

        // Átomos nuevos a verificar
        let new_positions: Vec<usize> = params.get("new_positions")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_u64()).map(|n| n as usize).collect())
            .unwrap_or_default();

        // Cargar ConflictMatrix desde la BD
        let matrix = crate::bitmask::conflict::ConflictMatrix::load_from_db(pg)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000, message: format!("error cargando ConflictMatrix: {}", e), data: None,
            })?;

        // Verificar conflictos
        let conflicts = matrix.check(&existing, &new_positions);
        let blocking = conflicts.iter().any(|c| c.severity.is_blocking());

        Ok(serde_json::json!({
            "conflictos_detectados": conflicts.len(),
            "bloqueante": blocking,
            "existing_atoms": existing.len(),
            "new_positions": new_positions.len(),
            "conflicts": conflicts.iter().map(|c| serde_json::json!({
                "atom_a": c.atom_a,
                "atom_b": c.atom_b,
                "severity": format!("{:?}", c.severity),
                "is_blocking": c.severity.is_blocking(),
                "description": c.description,
            })).collect::<Vec<_>>(),
            "mensaje": if blocking {
                "❌ Conflicto SoD bloqueante detectado — la asignación NO puede realizarse"
            } else if !conflicts.is_empty() {
                "⚠️ Conflicto SoD no bloqueante — requiere aprobación adicional"
            } else {
                "✅ Sin conflictos SoD — asignación segura"
            },
        }))
    }
}
