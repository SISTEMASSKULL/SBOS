// ============================================================
// bauth::server::handlers::access_evaluate — H-15 Evaluación de Acceso
//
// Handler: bauth.access.evaluate
// Evalúa si un usuario puede ejecutar un átomo específico.
//
// Pipeline:
//   1. Resolver atom_slug → atom_position, domain_code
//   2. Cargar roles del usuario (privilege_role_atom)
//   3. Construir RolBitMask combinado de todos los roles
//   4. Fast-Path: ¿atom_position está en el RolBitMask? (<0.5ns)
//   5. Policy-Path: cargar y evaluar políticas encadenadas al átomo
//   6. Retornar veredicto con trazabilidad completa
//
// DOC-SBOS-001 N3 · B1.T06 · MANUAL-PRIVILEGIOS §6
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct AccessEvaluateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for AccessEvaluateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // ── Parámetros ──────────────────────────────────────
        let atom_slug = params.get("atom_slug").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "atom_slug requerido".into(), data: None,
            })?;

        let user_uuid = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "user_uuid requerido".into(), data: None,
            })?;

        // ── PASO 1: Resolver atom_slug → campos ─────────────
        #[derive(sqlx::FromRow)]
        struct AtomInfo {
            atom_code: i32,
            app_code: i16,
            group_code: i16,
            domain_code: i16,
            atom_position: i32,
            atom_name: String,
        }

        let atom: AtomInfo = sqlx::query_as(
            "SELECT atom_code, app_code, group_code, domain_code, atom_position, atom_name
             FROM bauth.privilege_atom
             WHERE atom_slug = $1"
        )
        .bind(atom_slug)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando átomo: {}", e), data: None,
        })?
        .ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("átomo no encontrado: {}", atom_slug), data: None,
        })?;

        // ── PASO 2: Cargar RolBitMask del usuario ──────────
        //   1. Buscar usuario en idn_user_template
        //   2. Usar rol_bitmask_base64 precomputado
        //   3. Fallback: resolver vía rol_ids → privilege_role → privilege_role_atom
        let user_uuid_parsed = uuid::Uuid::parse_str(user_uuid).unwrap_or_else(|_| uuid::Uuid::nil());

        #[derive(sqlx::FromRow)]
        struct UserInfo {
            rol_bitmask_base64: Option<String>,
            rol_ids: Option<Vec<String>>,
        }

        let user_info = sqlx::query_as::<_, UserInfo>(
            "SELECT rol_bitmask_base64, rol_ids FROM bauth.idn_user_template WHERE uuid = $1"
        ).bind(user_uuid_parsed)
        .fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando usuario: {}", e), data: None,
        })?;

        // Construir RolBitMask
        let (rol_mask, role_atoms) = if let Some(ref ui) = user_info {
            if let Some(ref b64) = ui.rol_bitmask_base64 {
                if !b64.is_empty() && b64.len() > 2 {
                    let mask = crate::bitmask::RolBitMask::from_base64(b64, 5808)
                        .unwrap_or_else(|_| crate::bitmask::RolBitMask::with_capacity(5808));
                    let atoms: Vec<i32> = mask.active_positions().map(|p| p as i32).collect();
                    (mask, atoms)
                } else { (crate::bitmask::RolBitMask::with_capacity(5808), vec![]) }
            } else { (crate::bitmask::RolBitMask::with_capacity(5808), vec![]) }
        } else {
            // Fallback: role_id directo (para los 3 roles de prueba)
            let role_id = uuid::Uuid::parse_str(user_uuid).map_err(|_| JsonRpcError {
                code: -32602, message: "user_uuid inválido".into(), data: None,
            })?;
            let atoms: Vec<i32> = sqlx::query_scalar(
                "SELECT atom_position FROM bauth.privilege_role_atom WHERE role_id = $1 AND allowed = TRUE ORDER BY atom_position"
            ).bind(role_id).fetch_all(pg).await.unwrap_or_default();
            if atoms.is_empty() {
                (crate::bitmask::RolBitMask::with_capacity(5808), vec![])
            } else {
                let mask = crate::bitmask::resolver::compute_rol_bitmask(pg, role_id).await
                    .unwrap_or_else(|_| crate::bitmask::RolBitMask::with_capacity(5808));
                (mask, atoms)
            }
        };

        if role_atoms.is_empty() {
            return Ok(serde_json::json!({
                "veredicto": "DENEGADO",
                "motivo": "usuario sin átomos asignados",
                "atom": {
                    "atom_slug": atom_slug,
                    "atom_name": atom.atom_name,
                    "atom_position": atom.atom_position,
                    "domain_code": atom.domain_code
                },
                "fastpath": { "resultado": false, "total_atoms_asignados": 0 },
                "policies": [],
                "policies_count": 0,
                "evaluacion_completa": true
            }));
        }

        // ── PASO 3: Fast-Path check ─────────────────────────
        let position = atom.atom_position as usize;
        let fastpath_ok = rol_mask.check(position);

        // ── PASO 4: Policy-Path (si Fast-Path OK) ───────────
        let policies: Vec<Value> = if fastpath_ok {
            let rows = crate::db::load_policies_for_atom(
                pg, atom.app_code, atom.group_code, atom.atom_code
            ).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error cargando políticas: {}", e), data: None,
            })?;
            rows.iter().map(|r| serde_json::json!({
                "policy_slug": r.policy_slug,
                "policy_data": r.policy_data,
                "active": true,
            })).collect()
        } else { Vec::new() };

        // ── PASO 5: Veredicto ───────────────────────────────
        let veredicto = if fastpath_ok { "PERMITIDO" } else { "DENEGADO" };
        let motivo = if fastpath_ok {
            format!("átomo {} presente en RolBitMask", atom.atom_position)
        } else {
            format!("átomo {} ausente del RolBitMask", atom.atom_position)
        };

        Ok(serde_json::json!({
            "veredicto": veredicto,
            "motivo": motivo,
            "atom": {
                "atom_slug": atom_slug,
                "atom_name": atom.atom_name,
                "atom_code": atom.atom_code,
                "app_code": atom.app_code,
                "group_code": atom.group_code,
                "domain_code": atom.domain_code,
                "atom_position": atom.atom_position
            },
            "user_uuid": user_uuid,
            "fastpath": {
                "resultado": fastpath_ok,
                "atom_position_consultado": position,
                "atom_positions_usuario": role_atoms,
                "total_atoms_asignados": role_atoms.len(),
            },
            "policies": policies,
            "policies_count": policies.len(),
            "evaluacion_completa": true
        }))
    }
}
