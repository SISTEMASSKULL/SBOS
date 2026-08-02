// ============================================================
// bauth::server::handlers::context_evaluate — bauth.context.evaluate (B45.D01)
//
// Evalúa los dominios para un ctx_id usando DomainRegistry::evaluate_all().
// Carga la sesión desde ses_session_log (DDL v2.12.0) y el bitmask del
// usuario desde privilege_atom_grant (G-12, cero roles intermedios).
//
// Phantoms eliminados (Capa 3 refactor):
//   ses_context       → ses_session_log
//   privilege_atom    → idn_roles_template (node_type='atom')
//   privilege_role_atom → privilege_atom_grant (G-12)
//   Hardcoded 5808    → count_atoms() dinámico
//
// DOC-SBOS-001 N3 · SBOS-049 Context Plane · NIST SP 800-207
// ============================================================

#![allow(dead_code)]
use crate::bitmask::registry::DomainRegistry;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;
use std::time::Instant;
use uuid::Uuid;

pub struct ContextEvaluateHandler {
    pub registry: Arc<DomainRegistry>,
    pub pg_pool: Option<sqlx::PgPool>,
    pub notifier: Option<Arc<crate::domain::hierarchical_notify::HierarchicalNotifier>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for ContextEvaluateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("");
        if ctx_id.is_empty() {
            return Err(JsonRpcError {
                code: -32003, message: "ctx_id requerido".into(), data: None,
            });
        }

        let atom_path = params.get("atom_slug").and_then(|v| v.as_str())
            .unwrap_or("sistema.sesion.activa");

        let t_start = Instant::now();

        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // Carga sesión activa desde ses_session_log (DDL v2.12.0)
        let session = super::context_plane::query_session(pg, ctx_id).await?;
        let tenant_id_str = session.tenant_id.to_string();
        let user_id_str   = session.user_id.to_string();
        let t_resolve = t_start.elapsed().as_nanos() as u64;

        // Resolver átomo desde idn_roles_template (path = slug canónico)
        let (atom_position, atom_code) = self.resolve_atom(pg, atom_path).await?;

        // Cargar RolBitMask del usuario desde privilege_atom_grant (G-12)
        let rol = self.load_user_rolmask(pg, session.user_id).await.unwrap_or_else(|_| {
            crate::bitmask::RolBitMask::with_capacity(0)
        });
        let atom = crate::bitmask::AtomBitMask::from_u64(atom_code);

        let results = self.registry.evaluate_all(
            &tenant_id_str, ctx_id, &user_id_str, &rol, atom_position, &atom,
        );

        let t_eval = t_start.elapsed().as_nanos() as u64;

        let domain_results: Vec<Value> = results.iter().map(|r| {
            serde_json::json!({
                "domain":       r.domain,
                "result":       r.result.as_u8(),
                "policy_state": crate::bitmask::PolicyState::from_u8(r.policy_state as u8).is_approved(),
                "latency_ns":   r.latency_ns,
            })
        }).collect();

        // Notificar acceso denegado al notificador jerárquico (si está configurado)
        if let Some(ref notifier) = self.notifier {
            for r in &results {
                if r.result.as_u8() == 0 {
                    let motivo = format!("Dominio {}: política denegó el acceso", r.domain);
                    // empresa_id y sucursal_id no están en ses_session_log — se pasan vacíos
                    notifier.notify_access_denied(
                        &tenant_id_str, "", "", &user_id_str, atom_path, r.domain as u8, &motivo,
                    ).await;
                }
            }
        }

        let total_ns = t_start.elapsed().as_nanos() as u64;

        Ok(serde_json::json!({
            "ctx_id":    ctx_id,
            "atom_slug": atom_path,
            "session": {
                "user_id":      user_id_str,
                "tenant_id":    tenant_id_str,
                "auth_method":  session.auth_method,
                "loa_initial":  session.loa_initial,
                "loa_peak":     session.loa_peak,
                "ip_address":   session.ip_address,
                "started_at":   session.started_at.to_rfc3339(),
                "last_active":  session.last_active_at.to_rfc3339(),
            },
            "domains_evaluated": domain_results.len(),
            "domains": domain_results,
            "latency": {
                "resolve_ns":  t_resolve,
                "evaluate_ns": t_eval - t_resolve,
                "total_ns":    total_ns,
            },
        }))
    }
}

impl ContextEvaluateHandler {
    /// Resuelve un átomo por path canónico desde idn_roles_template (DDL v2.12.0).
    async fn resolve_atom(
        &self,
        pg: &sqlx::PgPool,
        atom_path: &str,
    ) -> Result<(usize, u64), JsonRpcError> {
        #[derive(sqlx::FromRow)]
        struct AtomRow { atom_position: i64 }

        let row: AtomRow = sqlx::query_as(
            "SELECT atom_position
             FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND path = $1 AND is_active = TRUE"
        )
        .bind(atom_path)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando átomo: {}", e), data: None,
        })?
        .ok_or_else(|| JsonRpcError {
            code: -32602,
            message: format!("átomo no encontrado en catálogo: {}", atom_path),
            data: None,
        })?;

        let pos = row.atom_position.max(0) as usize;
        // atom_code = posición como u64 (compatible con AtomBitMask::from_u64)
        Ok((pos, row.atom_position as u64))
    }

    /// Computa RolBitMask del usuario desde privilege_atom_grant (G-12).
    /// Evita tablas intermedias de roles — consulta directa a grants activos.
    async fn load_user_rolmask(
        &self,
        pg: &sqlx::PgPool,
        user_id: Uuid,
    ) -> Result<crate::bitmask::RolBitMask, String> {
        let total_atoms = crate::db::count_atoms(pg)
            .await
            .map_err(|e| e.to_string())? as usize;

        let positions: Vec<(i64,)> = sqlx::query_as(
            "SELECT rt.atom_position
             FROM bauth.privilege_atom_grant pag
             JOIN bauth.idn_roles_template rt
               ON rt.path = pag.atom_path
              AND rt.node_type = 'atom'
              AND rt.is_active = TRUE
             WHERE pag.user_id = $1
               AND (pag.general = TRUE AND pag.effect = TRUE
                    OR pag.general = FALSE AND pag.access = TRUE)
               AND (pag.expires_at IS NULL OR pag.expires_at > now())"
        )
        .bind(user_id)
        .fetch_all(pg)
        .await
        .map_err(|e| e.to_string())?;

        let pos_list: Vec<usize> = positions.iter()
            .filter_map(|(p,)| if *p >= 0 { Some(*p as usize) } else { None })
            .collect();

        Ok(crate::bitmask::RolBitMask::from_positions(&pos_list, total_atoms))
    }
}
