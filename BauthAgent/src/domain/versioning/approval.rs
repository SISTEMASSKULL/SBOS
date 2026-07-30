// ==================================================================
// bauth::domain::versioning::approval — Lógica pura de aprobación B03
//
// Quórum N-de-M para cambios MAJOR sobre T-041.
// Dual control NIST SP 800-53 AC-5 (proposed_by ≠ resolved_by).
// SLA configurable con escalado automático (CM-3).
// Sin I/O, sin DB, sin HTTP.
//
// NIST SP 800-53 AC-5 (Separation of Duties)
// NIST SP 800-53 CM-3 (Configuration Change Control)
// ISO 27001:2022 A.5.3 (Segregation of Duties)
// MVU 1.13 §9.3
// ==================================================================

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Estado de una propuesta de cambio MAJOR.
/// Espejo del ENUM `bauth.ver_proposal_status_enum`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ProposalStatus {
    /// Pendiente de votos — en plazo SLA.
    Pending,
    /// Quórum alcanzado con votos de aprobación (control dual AC-5: resolver ≠ proposer).
    Approved,
    /// Rechazado por voto negativo de algún aprobador (control dual AC-5).
    Rejected,
    /// SLA vencido sin quórum — expirado por el loop de reconciliación (sin resolver_by).
    Expired,
    /// Retirada por el proponente antes de que llegue ningún voto (sin resolver_by).
    Cancelled,
}

impl ProposalStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            ProposalStatus::Pending   => "PENDING",
            ProposalStatus::Approved  => "APPROVED",
            ProposalStatus::Rejected  => "REJECTED",
            ProposalStatus::Expired   => "EXPIRED",
            ProposalStatus::Cancelled => "CANCELLED",
        }
    }

    /// Terminal = la propuesta ya no puede recibir más votos.
    pub fn es_terminal(&self) -> bool {
        !matches!(self, ProposalStatus::Pending)
    }

    /// Requiere resolver_by en BD (solo decisiones humanas con control dual).
    pub fn requiere_resolver_by(&self) -> bool {
        matches!(self, ProposalStatus::Approved | ProposalStatus::Rejected)
    }
}

impl std::fmt::Display for ProposalStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl std::str::FromStr for ProposalStatus {
    type Err = super::VersioningError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "PENDING"   => Ok(ProposalStatus::Pending),
            "APPROVED"  => Ok(ProposalStatus::Approved),
            "REJECTED"  => Ok(ProposalStatus::Rejected),
            "EXPIRED"   => Ok(ProposalStatus::Expired),
            "CANCELLED" => Ok(ProposalStatus::Cancelled),
            otro => Err(super::VersioningError::EstadoInvalido(otro.to_string())),
        }
    }
}

/// Un voto individual de un aprobador.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Voto {
    /// UUID del aprobador que emite el voto.
    pub approver_id: Uuid,
    /// Decisión del voto.
    pub decision: DecisionVoto,
    /// Timestamp exacto del voto.
    pub voted_at: DateTime<Utc>,
    /// Comentario opcional del aprobador.
    pub comment: Option<String>,
}

/// Decisión posible en un voto de aprobación.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DecisionVoto {
    /// El aprobador acepta el cambio propuesto.
    Approve,
    /// El aprobador rechaza el cambio propuesto.
    Reject,
}

impl DecisionVoto {
    pub fn as_str(&self) -> &'static str {
        match self {
            DecisionVoto::Approve => "APPROVE",
            DecisionVoto::Reject  => "REJECT",
        }
    }
}

impl std::str::FromStr for DecisionVoto {
    type Err = super::VersioningError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "APPROVE" => Ok(DecisionVoto::Approve),
            "REJECT"  => Ok(DecisionVoto::Reject),
            otro => Err(super::VersioningError::EstadoInvalido(format!("decisión inválida: {otro}"))),
        }
    }
}

/// Resultado de la evaluación de quórum tras recibir un voto.
#[derive(Debug, PartialEq, Eq)]
pub enum DecisionQuorum {
    /// El quórum de aprobaciones se alcanzó — propuesta APROBADA.
    Aprobada,
    /// Un aprobador rechazó — propuesta RECHAZADA (dual control AC-5).
    Rechazada,
    /// Todavía no hay quórum ni rechazo — continuar recibiendo votos.
    Pendiente,
    /// El SLA venció sin quórum — propuesta EXPIRADA.
    Expirada,
}

/// Evalúa el estado de la propuesta dado el conjunto actual de votos.
///
/// Reglas de dominio B03 (NIST AC-5 + CM-3):
/// - Cualquier REJECT → propuesta RECHAZADA (dual control estricto)
/// - Votos APPROVE ≥ `required_approvers` → propuesta APROBADA
/// - `now > sla_deadline` y aún PENDING → propuesta EXPIRADA
/// - Ninguna condición anterior → PENDIENTE
pub fn evaluar_quorum(
    votos: &[Voto],
    required_approvers: i32,
    sla_deadline: DateTime<Utc>,
    now: DateTime<Utc>,
) -> DecisionQuorum {
    // Rechazo inmediato ante cualquier voto negativo (dual control AC-5)
    if votos.iter().any(|v| v.decision == DecisionVoto::Reject) {
        return DecisionQuorum::Rechazada;
    }

    let aprobaciones = votos.iter().filter(|v| v.decision == DecisionVoto::Approve).count();
    if aprobaciones >= required_approvers as usize {
        return DecisionQuorum::Aprobada;
    }

    if now > sla_deadline {
        return DecisionQuorum::Expirada;
    }

    DecisionQuorum::Pendiente
}

/// Calcula el deadline SLA de una propuesta.
/// Por defecto 48 horas desde `now`. Ajustable por política de tenant.
pub fn calcular_sla_deadline(now: DateTime<Utc>, horas_sla: i64) -> DateTime<Utc> {
    now + Duration::hours(horas_sla)
}

/// Valida que un voto de aprobación cumpla el control dual AC-5.
///
/// Regla: el aprobador no puede ser el mismo que propuso el cambio.
pub fn validar_control_dual(
    approver_id: Uuid,
    proposed_by: Uuid,
) -> Result<(), super::VersioningError> {
    if approver_id == proposed_by {
        return Err(super::VersioningError::TransicionNoPermitida(
            "control dual AC-5 violado".into(),
            "el proponente no puede aprobar su propio cambio".into(),
        ));
    }
    Ok(())
}

/// Verifica que el aprobador tiene un rol autorizado para votar.
///
/// `approver_roles` = roles que T-153 acepta como aprobadores válidos.
/// `roles_del_actor` = roles asignados al aprobador en la sesión.
pub fn es_aprobador_valido(approver_roles: &[String], roles_del_actor: &[String]) -> bool {
    roles_del_actor.iter().any(|r| approver_roles.contains(r))
}

/// Verifica que el aprobador no haya votado ya en esta propuesta.
pub fn ya_voto(votos: &[Voto], approver_id: Uuid) -> bool {
    votos.iter().any(|v| v.approver_id == approver_id)
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn dt(offset_horas: i64) -> DateTime<Utc> {
        Utc::now() + Duration::hours(offset_horas)
    }

    fn voto_aprobacion(id: Uuid) -> Voto {
        Voto { approver_id: id, decision: DecisionVoto::Approve, voted_at: Utc::now(), comment: None }
    }

    fn voto_rechazo(id: Uuid) -> Voto {
        Voto { approver_id: id, decision: DecisionVoto::Reject, voted_at: Utc::now(), comment: None }
    }

    #[test]
    fn test_quorum_alcanzado_con_dos_aprobaciones() {
        let votos = vec![voto_aprobacion(Uuid::new_v4()), voto_aprobacion(Uuid::new_v4())];
        assert_eq!(evaluar_quorum(&votos, 2, dt(48), Utc::now()), DecisionQuorum::Aprobada);
    }

    #[test]
    fn test_rechazo_inmediato_con_un_voto_negativo() {
        let votos = vec![voto_aprobacion(Uuid::new_v4()), voto_rechazo(Uuid::new_v4())];
        assert_eq!(evaluar_quorum(&votos, 2, dt(48), Utc::now()), DecisionQuorum::Rechazada);
    }

    #[test]
    fn test_pendiente_sin_quorum_dentro_de_sla() {
        let votos = vec![voto_aprobacion(Uuid::new_v4())];
        assert_eq!(evaluar_quorum(&votos, 2, dt(48), Utc::now()), DecisionQuorum::Pendiente);
    }

    #[test]
    fn test_expirada_cuando_sla_vencido_sin_quorum() {
        let votos = vec![voto_aprobacion(Uuid::new_v4())];
        let sla_pasado = dt(-1); // hace 1 hora
        assert_eq!(evaluar_quorum(&votos, 2, sla_pasado, Utc::now()), DecisionQuorum::Expirada);
    }

    #[test]
    fn test_control_dual_mismo_usuario_falla() {
        let id = Uuid::new_v4();
        assert!(validar_control_dual(id, id).is_err());
    }

    #[test]
    fn test_control_dual_usuarios_distintos_ok() {
        assert!(validar_control_dual(Uuid::new_v4(), Uuid::new_v4()).is_ok());
    }

    #[test]
    fn test_es_aprobador_valido_con_rol_correcto() {
        let roles_requeridos = vec!["bauth.admin".to_string(), "iga.reviewer".to_string()];
        let roles_actor = vec!["biz.contabilidad".to_string(), "iga.reviewer".to_string()];
        assert!(es_aprobador_valido(&roles_requeridos, &roles_actor));
    }

    #[test]
    fn test_es_aprobador_invalido_sin_rol() {
        let roles_requeridos = vec!["bauth.admin".to_string()];
        let roles_actor = vec!["biz.ventas".to_string()];
        assert!(!es_aprobador_valido(&roles_requeridos, &roles_actor));
    }

    #[test]
    fn test_ya_voto_detecta_duplicado() {
        let id = Uuid::new_v4();
        let votos = vec![voto_aprobacion(id)];
        assert!(ya_voto(&votos, id));
        assert!(!ya_voto(&votos, Uuid::new_v4()));
    }

    #[test]
    fn test_proposal_status_terminal() {
        assert!(!ProposalStatus::Pending.es_terminal());
        assert!(ProposalStatus::Approved.es_terminal());
        assert!(ProposalStatus::Rejected.es_terminal());
        assert!(ProposalStatus::Expired.es_terminal());
        assert!(ProposalStatus::Cancelled.es_terminal());
        assert!(ProposalStatus::Approved.requiere_resolver_by());
        assert!(ProposalStatus::Rejected.requiere_resolver_by());
        assert!(!ProposalStatus::Expired.requiere_resolver_by());
        assert!(!ProposalStatus::Cancelled.requiere_resolver_by());
        assert!(!ProposalStatus::Pending.requiere_resolver_by());
    }
}
