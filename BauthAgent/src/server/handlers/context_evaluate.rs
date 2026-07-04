// bauth::server::handlers::context_evaluate — bauth.context.evaluate (B45.D01)
// Ampliado B-BAUTH-003 (2026-06-28): incluye bloque "session" con datos de ses_context
// Evalúa 12 dominios para un ctx_id usando DomainRegistry::evaluate_all()

#![allow(dead_code)]
use crate::bitmask::registry::DomainRegistry;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;
use std::time::Instant;

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

        let atom_slug = params.get("atom_slug").and_then(|v| v.as_str())
            .unwrap_or("sistema.sesion.activa");

        let t_start = Instant::now();

        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // ── B-BAUTH-003: Query completa de sesión (antes solo 3 campos) ──
        let session = super::context_plane::query_session(pg, ctx_id).await?;
        let tenant_id = session.tenant_id.clone();
        let user_id = session.user_uuid.map(|u| u.to_string()).unwrap_or_default();
        let t_resolve = t_start.elapsed().as_nanos() as u64;

        // Resolver átomo
        let (atom_position, atom_code) = self.resolve_atom(pg, atom_slug).await?;

        // Cargar RolBitMask real del usuario (desde privilege_role_atom)
        let rol = self.load_user_rolmask(&user_id).await.unwrap_or_else(|_| {
            crate::bitmask::RolBitMask::with_capacity(5808)
        });
        let atom = crate::bitmask::AtomBitMask::from_u64(atom_code);

        let results = self.registry.evaluate_all(
            &tenant_id, ctx_id, &user_id, &rol, atom_position, &atom,
        );

        let t_eval = t_start.elapsed().as_nanos() as u64;

        let domain_results: Vec<Value> = results.iter().map(|r| {
            serde_json::json!({
                "domain": r.domain,
                "result": r.result.as_u8(),
                "policy_state": crate::bitmask::PolicyState::from_u8(r.policy_state as u8).is_approved(),
                "latency_ns": r.latency_ns,
            })
        }).collect();

        // Notificar si algún dominio denegó
        if let Some(ref notifier) = self.notifier {
            for r in &results {
                if r.result.as_u8() == 0 { // Denegado
                    let empresa = session.empresa_id.clone();
                    let sucursal = session.sucursal_id.clone().unwrap_or_default();
                    let motivo = format!("Dominio {}: politica denego el acceso", r.domain);
                    notifier.notify_access_denied(
                        &session.tenant_id, &empresa, &sucursal,
                        &user_id, atom_slug, r.domain as u8, &motivo,
                    ).await;
                }
            }
        }

        let total_latency_ns = t_start.elapsed().as_nanos() as u64;
        Ok(serde_json::json!({
            "ctx_id": ctx_id,
            "atom_slug": atom_slug,
            // ── B-BAUTH-003: Bloque session con datos completos ──
            "session": {
                "user_uuid":      session.user_uuid.map(|u| u.to_string()),
                "tenant_id":      session.tenant_id,
                "empresa_id":     session.empresa_id,
                "sucursal_id":    session.sucursal_id,
                "pos_logico":     session.pos_logico,
                "bitmask_hex":    session.bitmask_hex,
                "loa_current":    session.loa_current,
                "device_id":      session.device_id,
                "device_hostname":session.device_hostname,
                "device_ip":      session.device_ip,
                "session_kc":     session.session_kc,
                "traceparent":    session.traceparent,
                "state":          session.state,
                "created_at":     session.created_at.map(|d| d.to_rfc3339()),
                "expires_at":     session.expires_at.map(|d| d.to_rfc3339()),
            },
            "domains_evaluated": domain_results.len(),
            "domains": domain_results,
            "latency": {
                "resolve_ns": t_resolve,
                "evaluate_ns": t_eval - t_resolve,
                "total_ns": total_latency_ns,
            },
        }))
    }
}

impl ContextEvaluateHandler {
    async fn resolve_atom(&self, pg: &sqlx::PgPool, atom_slug: &str)
        -> Result<(usize, u64), JsonRpcError>
    {
        #[derive(sqlx::FromRow)]
        struct AtomRow { atom_position: i32, contextual_mask: i32, logical_mask: i32 }

        let atom: AtomRow = sqlx::query_as(
            "SELECT atom_position, contextual_mask, logical_mask
             FROM bauth.privilege_atom WHERE atom_slug = $1"
        ).bind(atom_slug).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando átomo: {}", e), data: None,
        })?.ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("átomo no encontrado: {}", atom_slug), data: None,
        })?;

        let atom_code: u64 = ((atom.contextual_mask as u64) << 32) | (atom.logical_mask as u64);
        Ok((atom.atom_position as usize, atom_code))
    }

    /// Carga el RolBitMask real del usuario desde privilege_role_atom.
    async fn load_user_rolmask(&self, user_uuid: &str) -> Result<crate::bitmask::RolBitMask, String> {
        let pg = self.pg_pool.as_ref().ok_or("BD no disponible")?;
        if let Ok(role_id) = uuid::Uuid::parse_str(user_uuid) {
            crate::bitmask::resolver::compute_rol_bitmask(pg, role_id).await
                .map_err(|e| e.to_string())
        } else {
            Ok(crate::bitmask::RolBitMask::with_capacity(5808))
        }
    }
}
