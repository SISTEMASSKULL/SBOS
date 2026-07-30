// ============================================================
// bauth::server::handlers::approval — B03 JSON-RPC
//
// Expone 5 métodos:
//   bauth.role.version.propose      — abre propuesta MAJOR → T-153
//   bauth.role.version.vote         — emite voto atómico (aprobar/rechazar)
//   bauth.role.version.cancel       — cancela propuesta PENDING (solo el proponente)
//   bauth.role.version.list_pending — lista propuestas PENDING
//   bauth.role.version.get_proposal — detalle completo de una propuesta
//
// NIST SP 800-53 AC-5 · CM-3 · ISO 27001:2022 A.5.3
// ============================================================

use crate::db::approval::{
    aplicar_voto_tx, bloquear_propuesta_tx, cancelar_propuesta,
    deserializar_votos, listar_pendientes, obtener_propuesta,
    someter_propuesta, NuevaProposal,
};
use crate::domain::versioning::approval::{
    calcular_sla_deadline, evaluar_quorum, validar_control_dual,
    ya_voto, DecisionVoto, ProposalStatus, Voto,
};
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use chrono::Utc;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}
fn err_server(msg: String) -> JsonRpcError {
    JsonRpcError { code: -32000, message: msg, data: None }
}
fn parse_uuid(params: &Value, campo: &str) -> Result<Uuid, JsonRpcError> {
    let s = params.get(campo).and_then(|v| v.as_str())
        .ok_or_else(|| err(&format!("{campo} requerido (UUID)")))?;
    Uuid::parse_str(s).map_err(|_| err(&format!("{campo} UUID inválido: '{s}'")))
}
fn parse_str_vec(params: &Value, campo: &str) -> Vec<String> {
    params.get(campo).and_then(|v| v.as_array())
        .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default()
}

// ── bauth.role.version.propose ───────────────────────────────

/// Abre una propuesta de cambio MAJOR en T-153.
///
/// Parámetros obligatorios:
/// - `entity_id` UUID — rol a modificar
/// - `proposed_state` object — estado propuesto (JSONB completo)
/// - `change_reason` string — justificación del cambio
/// - `security_impact` string — LOW | MEDIUM | HIGH | CRITICAL
/// - `proposed_by` UUID — actor proponente
/// - `required_approvers` int — quórum mínimo (≥ 1)
/// - `approver_roles` string[] — roles autorizados a votar
/// - `ctx_id` string — context ID (SBOS-049)
///
/// Parámetros opcionales:
/// - `blocks_touched` string[] — bloques B01-B10 afectados
/// - `standard_ref` string[] — referencias normativas
/// - `sla_horas` int — plazo en horas (default 48)
pub struct ProposeHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for ProposeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_id    = parse_uuid(&params, "entity_id")?;
        let proposed_by  = parse_uuid(&params, "proposed_by")?;
        let ctx_id       = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido (SBOS-049)"))?.to_string();
        let proposed_state = params.get("proposed_state").cloned()
            .ok_or_else(|| err("proposed_state requerido (JSONB)"))?;
        let change_reason = params.get("change_reason").and_then(|v| v.as_str())
            .ok_or_else(|| err("change_reason requerido"))?.to_string();
        let security_impact = params.get("security_impact").and_then(|v| v.as_str())
            .ok_or_else(|| err("security_impact requerido: LOW|MEDIUM|HIGH|CRITICAL"))?.to_string();
        let required_approvers = params.get("required_approvers").and_then(|v| v.as_i64())
            .ok_or_else(|| err("required_approvers requerido (int ≥ 1)"))? as i32;
        let approver_roles = parse_str_vec(&params, "approver_roles");

        if approver_roles.is_empty() {
            return Err(err("approver_roles no puede estar vacío"));
        }
        if required_approvers < 1 || required_approvers > approver_roles.len() as i32 {
            return Err(err("required_approvers debe ser ≥ 1 y ≤ longitud de approver_roles"));
        }

        let sla_horas = params.get("sla_horas").and_then(|v| v.as_i64()).unwrap_or(48);
        let sla_deadline = calcular_sla_deadline(Utc::now(), sla_horas);

        let proposal = NuevaProposal {
            entity_id, proposed_state,
            blocks_touched: parse_str_vec(&params, "blocks_touched"),
            standard_ref: parse_str_vec(&params, "standard_ref"),
            change_reason, security_impact, proposed_by,
            required_approvers, approver_roles, sla_deadline, ctx_id: ctx_id.clone(),
        };

        let id = someter_propuesta(&self.pg, &proposal).await
            .map_err(|e| err_server(format!("error al someter propuesta: {e}")))?;

        tracing::info!(%id, %entity_id, %ctx_id, "version.propose — propuesta MAJOR abierta");
        Ok(json!({
            "proposal_id":        id,
            "entity_id":          entity_id,
            "status":             "PENDING",
            "required_approvers": proposal.required_approvers,
            "sla_deadline":       sla_deadline.to_rfc3339(),
        }))
    }
}
impl ProposeHandler { pub fn method() -> &'static str { "bauth.role.version.propose" } }

// ── bauth.role.version.vote ──────────────────────────────────

/// Emite un voto de aprobación o rechazo sobre una propuesta.
///
/// El handler lee `proposed_by`, `required_approvers`, `sla_deadline`
/// y `current_approvals` de la BD — el cliente NO los pasa.
/// Esto garantiza que ningún cliente puede manipular el quórum, el control
/// dual o el historial de votos.
///
/// Parámetros del cliente (única fuente de confianza del caller):
/// - `proposal_id` UUID — propuesta a votar
/// - `approver_id` UUID — actor que vota
/// - `decision` string — "APPROVE" | "REJECT"
/// - `ctx_id` string — context ID (SBOS-049)
///
/// Parámetros opcionales:
/// - `comment` string — comentario del aprobador
pub struct VoteHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VoteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        // Sólo estos 4 campos vienen del cliente
        let proposal_id = parse_uuid(&params, "proposal_id")?;
        let approver_id = parse_uuid(&params, "approver_id")?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido (SBOS-049)"))?.to_string();
        let decision: DecisionVoto = params.get("decision").and_then(|v| v.as_str())
            .ok_or_else(|| err("decision requerido: APPROVE | REJECT"))
            .and_then(|s| s.parse()
                .map_err(|e: crate::domain::versioning::VersioningError| err(&e.to_string())))?;
        let comment = params.get("comment").and_then(|v| v.as_str()).map(String::from);

        // Iniciar transacción y bloquear la fila (FOR UPDATE NOWAIT)
        let mut tx = self.pg.begin().await
            .map_err(|e| err_server(format!("error iniciando transacción: {e}")))?;

        let propuesta = bloquear_propuesta_tx(&mut tx, proposal_id).await
            .map_err(|e| err_server(e.to_string()))?;

        // Todos los datos de dominio vienen de la BD, no del cliente
        if propuesta.status != "PENDING" {
            return Err(err(&format!(
                "la propuesta ya está resuelta: estado = {}", propuesta.status
            )));
        }

        let votos_actuales = deserializar_votos(&propuesta.approvals);

        // Validaciones de dominio sobre datos de BD
        validar_control_dual(approver_id, propuesta.proposed_by)
            .map_err(|e| err(&e.to_string()))?;
        if ya_voto(&votos_actuales, approver_id) {
            return Err(err("el aprobador ya emitió su voto en esta propuesta"));
        }

        let voto = Voto { approver_id, decision, voted_at: Utc::now(), comment };

        let mut votos_con_nuevo = votos_actuales;
        votos_con_nuevo.push(voto.clone());

        let decision_quorum = evaluar_quorum(
            &votos_con_nuevo,
            propuesta.required_approvers,
            propuesta.sla_deadline,
            Utc::now(),
        );

        let nuevo_status = match decision_quorum {
            crate::domain::versioning::approval::DecisionQuorum::Aprobada  => ProposalStatus::Approved,
            crate::domain::versioning::approval::DecisionQuorum::Rechazada => ProposalStatus::Rejected,
            crate::domain::versioning::approval::DecisionQuorum::Expirada  => ProposalStatus::Expired,
            crate::domain::versioning::approval::DecisionQuorum::Pendiente => ProposalStatus::Pending,
        };

        // resolver_por solo en APPROVED/REJECTED (control dual); EXPIRED = sistema
        let resolver_por = if nuevo_status.requiere_resolver_by() { Some(approver_id) } else { None };
        let nota = if nuevo_status.es_terminal() {
            Some(format!("Quórum: {} → {}", decision.as_str(), nuevo_status.as_str()))
        } else {
            None
        };

        aplicar_voto_tx(&mut tx, proposal_id, &voto, nuevo_status, resolver_por, nota.as_deref())
            .await
            .map_err(|e| err_server(format!("error al aplicar voto: {e}")))?;

        tx.commit().await
            .map_err(|e| err_server(format!("error al confirmar transacción: {e}")))?;

        let aprobaciones = votos_con_nuevo.iter()
            .filter(|v| v.decision == DecisionVoto::Approve).count();

        tracing::info!(
            %proposal_id, %approver_id,
            decision = decision.as_str(),
            status = nuevo_status.as_str(),
            %ctx_id,
            "version.vote — voto registrado"
        );
        Ok(json!({
            "proposal_id":         proposal_id,
            "decision":            decision.as_str(),
            "nuevo_status":        nuevo_status.as_str(),
            "es_terminal":         nuevo_status.es_terminal(),
            "aprobaciones":        aprobaciones,
            "required_approvers":  propuesta.required_approvers,
        }))
    }
}
impl VoteHandler { pub fn method() -> &'static str { "bauth.role.version.vote" } }

// ── bauth.role.version.cancel ────────────────────────────────

/// Cancela una propuesta PENDING. Solo puede cancelarla el proponente original.
///
/// Parámetros obligatorios:
/// - `proposal_id` UUID — propuesta a cancelar
/// - `cancelled_by` UUID — debe coincidir con `proposed_by` en BD
/// - `reason` string — motivo de la cancelación
/// - `ctx_id` string
pub struct CancelHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for CancelHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let proposal_id  = parse_uuid(&params, "proposal_id")?;
        let cancelled_by = parse_uuid(&params, "cancelled_by")?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido"))?.to_string();
        let reason = params.get("reason").and_then(|v| v.as_str())
            .ok_or_else(|| err("reason requerido"))?;

        let razon_completa = format!("Cancelado por proponente. Motivo: {reason}");

        let cancelada = cancelar_propuesta(&self.pg, proposal_id, cancelled_by, &razon_completa)
            .await
            .map_err(|e| err_server(e.to_string()))?;

        if !cancelada {
            return Err(err(
                "no se pudo cancelar: la propuesta no existe, ya fue resuelta, o cancelled_by no es el proponente"
            ));
        }

        tracing::info!(%proposal_id, %cancelled_by, %ctx_id, "version.cancel — propuesta cancelada");
        Ok(json!({
            "proposal_id": proposal_id,
            "status":      "CANCELLED",
            "reason":      razon_completa,
        }))
    }
}
impl CancelHandler { pub fn method() -> &'static str { "bauth.role.version.cancel" } }

// ── bauth.role.version.list_pending ─────────────────────────

/// Lista propuestas PENDING ordenadas por urgencia de SLA.
///
/// Parámetros opcionales:
/// - `entity_id` UUID — filtrar por rol específico
/// - `limit` int — máximo registros (default 20, máx 100)
pub struct ListPendingHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for ListPendingHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_id = params.get("entity_id").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20).min(100);

        let filas = listar_pendientes(&self.pg, entity_id, limit).await
            .map_err(|e| err_server(e.to_string()))?;

        let now = Utc::now();
        let items: Vec<Value> = filas.into_iter().map(|f| {
            let horas_restantes = (f.sla_deadline - now).num_hours();
            json!({
                "proposal_id":       f.id,
                "entity_id":         f.entity_id,
                "change_reason":     f.change_reason,
                "security_impact":   f.security_impact,
                "proposed_by":       f.proposed_by,
                "required_approvers":f.required_approvers,
                "approvals_count":   f.approvals_count,
                "sla_deadline":      f.sla_deadline.to_rfc3339(),
                "horas_restantes":   horas_restantes,
                "escalated":         f.escalated,
                "created_at":        f.created_at.to_rfc3339(),
            })
        }).collect();

        Ok(json!({"count": items.len(), "pending": items}))
    }
}
impl ListPendingHandler { pub fn method() -> &'static str { "bauth.role.version.list_pending" } }

// ── bauth.role.version.get_proposal ─────────────────────────

/// Devuelve el detalle completo de una propuesta incluyendo votos.
///
/// Parámetros obligatorios: `proposal_id` UUID.
pub struct GetProposalHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for GetProposalHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let proposal_id = parse_uuid(&params, "proposal_id")?;

        let fila = obtener_propuesta(&self.pg, proposal_id).await
            .map_err(|e| err_server(e.to_string()))?
            .ok_or_else(|| JsonRpcError {
                code: -32001,
                message: format!("propuesta {proposal_id} no encontrada"),
                data: None,
            })?;

        let votos = deserializar_votos(&fila.approvals);
        let aprobaciones = votos.iter().filter(|v| v.decision == DecisionVoto::Approve).count();
        let rechazos = votos.iter().filter(|v| v.decision == DecisionVoto::Reject).count();

        Ok(json!({
            "proposal_id":       fila.id,
            "entity_id":         fila.entity_id,
            "status":            fila.status,
            "change_reason":     fila.change_reason,
            "security_impact":   fila.security_impact,
            "proposed_by":       fila.proposed_by,
            "proposed_state":    fila.proposed_state,
            "blocks_touched":    fila.blocks_touched,
            "required_approvers":fila.required_approvers,
            "approver_roles":    fila.approver_roles,
            "aprobaciones":      aprobaciones,
            "rechazos":          rechazos,
            "total_votos":       votos.len(),
            "approvals":         fila.approvals,
            "sla_deadline":      fila.sla_deadline.to_rfc3339(),
            "escalated":         fila.escalated,
            "resolved_by":       fila.resolved_by,
            "resolved_at":       fila.resolved_at.map(|t| t.to_rfc3339()),
            "resolution_note":   fila.resolution_note,
            "ctx_id":            fila.ctx_id,
            "created_at":        fila.created_at.to_rfc3339(),
        }))
    }
}
impl GetProposalHandler { pub fn method() -> &'static str { "bauth.role.version.get_proposal" } }

// ── Factory ──────────────────────────────────────────────────

pub fn all_approval_handlers(pg: PgPool) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (ProposeHandler::method().into(),     Arc::new(ProposeHandler     { pg: pg.clone() })),
        (VoteHandler::method().into(),        Arc::new(VoteHandler        { pg: pg.clone() })),
        (CancelHandler::method().into(),      Arc::new(CancelHandler      { pg: pg.clone() })),
        (ListPendingHandler::method().into(), Arc::new(ListPendingHandler { pg: pg.clone() })),
        (GetProposalHandler::method().into(), Arc::new(GetProposalHandler { pg })),
    ]
}
