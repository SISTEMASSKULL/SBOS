// ==================================================================
// bauth::db::approval — Queries para T-153 (B03 approval workflow)
//
// T-153: bauth.idn_roles_ver_b03_approval_queue
// Cola de cambios MAJOR pendientes de quórum N-de-M.
//
// Restricciones de DDL que este módulo respeta:
// - chk_irvb03aq_only_major: change_type siempre 'MAJOR'
// - chk_irvb03aq_dual_ctrl:  resolved_by ≠ proposed_by
// - chk_irvb03aq_quorum:     required_approvers ∈ [1, |approver_roles|]
// - chk_irvb03aq_resolved:   PENDING ↔ resolved_by/at NULL; resuelto ↔ NOT NULL
//
// NIST SP 800-53 AC-5 · CM-3 · ISO 27001:2022 A.5.3
// ==================================================================

#![allow(dead_code)]

use crate::db::DbError;
use crate::domain::versioning::approval::{DecisionVoto, ProposalStatus, Voto};
use chrono::{DateTime, Utc};
use serde_json::Value;
use uuid::Uuid;

// ── Someter propuesta ────────────────────────────────────────────

/// Parámetros para abrir una propuesta de cambio MAJOR en T-153.
pub struct NuevaProposal {
    /// UUID del rol que se quiere modificar (FK T-041).
    pub entity_id: Uuid,
    /// Estado propuesto del rol como JSONB completo.
    pub proposed_state: Value,
    /// Bloques B01-B10 que el cambio afecta.
    pub blocks_touched: Vec<String>,
    /// Referencias normativas aplicables.
    pub standard_ref: Vec<String>,
    /// Razón del cambio (obligatoria para MAJOR).
    pub change_reason: String,
    /// Impacto de seguridad estimado: LOW | MEDIUM | HIGH | CRITICAL.
    pub security_impact: String,
    /// UUID del actor que propone el cambio.
    pub proposed_by: Uuid,
    /// Número mínimo de votos de aprobación para alcanzar quórum.
    pub required_approvers: i32,
    /// Roles que pueden emitir votos válidos en esta propuesta.
    pub approver_roles: Vec<String>,
    /// Deadline SLA para obtener quórum.
    pub sla_deadline: DateTime<Utc>,
    /// Context ID de la operación (SBOS-049).
    pub ctx_id: String,
}

/// Abre una propuesta de cambio MAJOR en T-153.
/// Retorna el UUID de la propuesta creada.
pub async fn someter_propuesta(
    pg: &sqlx::PgPool,
    p: &NuevaProposal,
) -> Result<Uuid, DbError> {
    let (id,): (Uuid,) = sqlx::query_as(
        r#"
        INSERT INTO bauth.idn_roles_ver_b03_approval_queue
            (entity_id, proposed_state, blocks_touched, standard_ref,
             change_reason, security_impact, proposed_by,
             required_approvers, approver_roles, sla_deadline, ctx_id)
        VALUES
            ($1, $2::jsonb, $3, $4,
             $5, $6::risk_level_enum, $7,
             $8, $9, $10, $11)
        RETURNING id
        "#,
    )
    .bind(p.entity_id)
    .bind(&p.proposed_state)
    .bind(&p.blocks_touched)
    .bind(&p.standard_ref)
    .bind(&p.change_reason)
    .bind(&p.security_impact)
    .bind(p.proposed_by)
    .bind(p.required_approvers)
    .bind(&p.approver_roles)
    .bind(p.sla_deadline)
    .bind(&p.ctx_id)
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(id)
}

// ── Votar — operaciones transaccionales ─────────────────────────

/// Bloquea la fila de una propuesta PENDING para votar de forma atómica.
///
/// Usa `SELECT ... FOR UPDATE NOWAIT`: si la fila ya está bloqueada por
/// otra transacción concurrente, falla inmediatamente en lugar de esperar.
///
/// Llamar siempre dentro de una transacción (`pg.begin()`).
/// Después de las validaciones de dominio, llamar `aplicar_voto_tx()`.
pub async fn bloquear_propuesta_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    proposal_id: Uuid,
) -> Result<FilaProposalCompleta, DbError> {
    let fila = sqlx::query_as::<_, FilaProposalCompleta>(
        r#"
        SELECT id, entity_id, proposed_state, blocks_touched,
               change_reason, security_impact::text AS security_impact,
               proposed_by, required_approvers, approver_roles, approvals,
               sla_deadline, escalated, status::text AS status,
               resolved_by, resolved_at, resolution_note,
               ctx_id, created_at
        FROM bauth.idn_roles_ver_b03_approval_queue
        WHERE id = $1
        FOR UPDATE NOWAIT
        "#,
    )
    .bind(proposal_id)
    .fetch_optional(&mut **tx)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?
    .ok_or_else(|| DbError::Other(format!("propuesta {proposal_id} no encontrada")))?;

    Ok(fila)
}

/// Aplica un voto a la propuesta bloqueada y la resuelve si corresponde.
///
/// Llamar solo dentro de la misma transacción que inició `bloquear_propuesta_tx()`.
/// El `FOR UPDATE` de la lectura garantiza que nadie más modifica la fila.
pub async fn aplicar_voto_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    proposal_id: Uuid,
    voto: &Voto,
    nuevo_status: ProposalStatus,
    resolver_por: Option<Uuid>,
    nota_resolucion: Option<&str>,
) -> Result<(), DbError> {
    let voto_json = serde_json::to_value(voto)
        .map_err(|e| DbError::Other(format!("error serializando voto: {e}")))?;

    // resolved_at se fija para cualquier estado terminal
    let resolved_at: Option<DateTime<Utc>> = if nuevo_status.es_terminal() {
        Some(Utc::now())
    } else {
        None
    };
    // resolver_por solo aplica en APPROVED/REJECTED (control dual AC-5)
    // Para EXPIRED/CANCELLED el campo debe ser NULL (constraint del DDL)
    let resolver_por = if nuevo_status.requiere_resolver_by() { resolver_por } else { None };

    sqlx::query(
        r#"
        UPDATE bauth.idn_roles_ver_b03_approval_queue
        SET
            approvals       = approvals || $2::jsonb,
            status          = $3::bauth.ver_proposal_status_enum,
            resolved_by     = CASE WHEN $4::uuid IS NOT NULL     THEN $4::uuid        ELSE resolved_by     END,
            resolved_at     = CASE WHEN $5::timestamptz IS NOT NULL THEN $5::timestamptz ELSE resolved_at     END,
            resolution_note = CASE WHEN $6::text IS NOT NULL     THEN $6::text        ELSE resolution_note END
        WHERE id = $1
          AND status = 'PENDING'
        "#,
    )
    .bind(proposal_id)
    .bind(voto_json)
    .bind(nuevo_status.as_str())
    .bind(resolver_por)
    .bind(resolved_at)
    .bind(nota_resolucion)
    .execute(&mut **tx)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(())
}

// ── Cancelar ─────────────────────────────────────────────────────

/// Cancela una propuesta PENDING. Solo puede cancelarla el proponente original.
///
/// Usa status = 'CANCELLED' (no 'REJECTED'): la cancelación es una retirada
/// voluntaria del proponente, sin control dual. El DDL permite `resolved_by = NULL`
/// para CANCELLED y EXPIRED (sólo APPROVED/REJECTED exigen control dual AC-5).
///
/// Retorna `true` si se canceló, `false` si no era PENDING o no era el proponente.
pub async fn cancelar_propuesta(
    pg: &sqlx::PgPool,
    proposal_id: Uuid,
    cancelled_by: Uuid,
    razon: &str,
) -> Result<bool, DbError> {
    let result = sqlx::query(
        r#"
        UPDATE bauth.idn_roles_ver_b03_approval_queue
        SET
            status          = 'CANCELLED',
            resolved_by     = NULL,
            resolved_at     = now(),
            resolution_note = $3
        WHERE id = $1
          AND status      = 'PENDING'
          AND proposed_by = $2
        "#,
    )
    .bind(proposal_id)
    .bind(cancelled_by)
    .bind(razon)
    .execute(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(result.rows_affected() > 0)
}

// ── Leer ────────────────────────────────────────────────────────

/// Fila resumida de una propuesta pendiente.
#[derive(Debug, sqlx::FromRow)]
pub struct FilaProposalResumen {
    pub id: Uuid,
    pub entity_id: Uuid,
    pub change_reason: String,
    pub security_impact: String,
    pub proposed_by: Uuid,
    pub required_approvers: i32,
    pub sla_deadline: DateTime<Utc>,
    pub escalated: bool,
    pub created_at: DateTime<Utc>,
    pub approvals_count: i64,
}

/// Lista propuestas PENDING ordenadas por urgencia (deadline ASC).
pub async fn listar_pendientes(
    pg: &sqlx::PgPool,
    entity_id: Option<Uuid>,
    limit: i64,
) -> Result<Vec<FilaProposalResumen>, DbError> {
    let rows = sqlx::query_as::<_, FilaProposalResumen>(
        r#"
        SELECT id, entity_id, change_reason, security_impact::text AS security_impact,
               proposed_by, required_approvers, sla_deadline, escalated, created_at,
               jsonb_array_length(approvals) AS approvals_count
        FROM bauth.idn_roles_ver_b03_approval_queue
        WHERE status = 'PENDING'
          AND ($1::uuid IS NULL OR entity_id = $1)
        ORDER BY sla_deadline ASC
        LIMIT $2
        "#,
    )
    .bind(entity_id)
    .bind(limit)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows)
}

/// Fila completa de una propuesta (con votos y estado propuesto).
#[derive(Debug, sqlx::FromRow)]
pub struct FilaProposalCompleta {
    pub id: Uuid,
    pub entity_id: Uuid,
    pub proposed_state: Value,
    pub blocks_touched: Vec<String>,
    pub change_reason: String,
    pub security_impact: String,
    pub proposed_by: Uuid,
    pub required_approvers: i32,
    pub approver_roles: Vec<String>,
    pub approvals: Value,
    pub sla_deadline: DateTime<Utc>,
    pub escalated: bool,
    pub status: String,
    pub resolved_by: Option<Uuid>,
    pub resolved_at: Option<DateTime<Utc>>,
    pub resolution_note: Option<String>,
    pub ctx_id: String,
    pub created_at: DateTime<Utc>,
}

/// Obtiene una propuesta completa por ID.
pub async fn obtener_propuesta(
    pg: &sqlx::PgPool,
    proposal_id: Uuid,
) -> Result<Option<FilaProposalCompleta>, DbError> {
    let row = sqlx::query_as::<_, FilaProposalCompleta>(
        r#"
        SELECT id, entity_id, proposed_state, blocks_touched,
               change_reason, security_impact::text AS security_impact,
               proposed_by, required_approvers, approver_roles, approvals,
               sla_deadline, escalated, status::text AS status,
               resolved_by, resolved_at, resolution_note,
               ctx_id, created_at
        FROM bauth.idn_roles_ver_b03_approval_queue
        WHERE id = $1
        "#,
    )
    .bind(proposal_id)
    .fetch_optional(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(row)
}

/// Parsea el array JSONB `approvals` de T-153 al tipo de dominio `Vec<Voto>`.
pub fn deserializar_votos(approvals_json: &Value) -> Vec<Voto> {
    match approvals_json.as_array() {
        Some(arr) => arr.iter()
            .filter_map(|v| serde_json::from_value(v.clone()).ok())
            .collect(),
        None => Vec::new(),
    }
}

/// Expira propuestas PENDING cuyo SLA venció.
///
/// Usa status = 'EXPIRED' con `resolved_by = NULL`: la expiración es automática
/// (sistema), no requiere actor humano. El DDL permite `resolved_by = NULL`
/// para EXPIRED (sólo APPROVED/REJECTED exigen control dual AC-5 con resolver ≠ proposer).
///
/// Retorna el número de propuestas marcadas como EXPIRED.
pub async fn expirar_sla_vencidos(pg: &sqlx::PgPool) -> Result<u64, DbError> {
    let result = sqlx::query(
        r#"
        UPDATE bauth.idn_roles_ver_b03_approval_queue
        SET status          = 'EXPIRED',
            resolved_by     = NULL,
            resolved_at     = now(),
            resolution_note = 'SLA vencido sin quórum — expirado automáticamente por reconcile loop'
        WHERE status       = 'PENDING'
          AND sla_deadline < now()
          AND resolved_by  IS NULL
        "#,
    )
    .execute(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(result.rows_affected())
}
