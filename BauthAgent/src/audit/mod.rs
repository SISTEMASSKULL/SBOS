// ============================================================
// bauth::audit — Auditoría WORM de evaluación de acceso (B1.T20)
//
// Registra cada decisión en bos_atom_audit (particionada por mes).
// ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-3 · SBOS-049.
//
// WORM: solo INSERT permitido. UPDATE/DELETE revocados a nivel BD.
// ============================================================

use sqlx::PgPool;
use tracing::debug;

/// Evento de auditoría de UN dominio sobre UN átomo.
#[derive(Debug, Clone)]
pub struct AuditEvent {
    pub ctx_id: String,
    pub tenant_id: uuid::Uuid,
    pub role_id: uuid::Uuid,
    pub app_code: i16,
    pub group_code: i16,
    pub atom_code: i32,
    pub atom_position: i32,
    pub bitmask_atom: i64,
    pub policy_state: i16,
    pub result: i16,
    pub policy_slug: Option<String>,
    pub evaluator: String,
    pub domain_code: i16,
}

impl AuditEvent {
    pub async fn insert(&self, pg: &PgPool) -> Result<(), AuditError> {
        sqlx::query(
            "INSERT INTO bauth.privilege_atom_audit \
             (ctx_id,tenant_id,role_id,app_code,group_code,atom_code,\
              atom_position,bitmask_atom,policy_state,result,\
              policy_slug,evaluator,domain_code) \
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)"
        )
        .bind(&self.ctx_id).bind(self.tenant_id).bind(self.role_id)
        .bind(self.app_code).bind(self.group_code).bind(self.atom_code)
        .bind(self.atom_position).bind(self.bitmask_atom)
        .bind(self.policy_state).bind(self.result)
        .bind(&self.policy_slug).bind(&self.evaluator).bind(self.domain_code)
        .execute(pg).await
        .map_err(|e| AuditError::Database(e.to_string()))?;

        debug!(ctx_id=%self.ctx_id, domain=self.domain_code, result=self.result,
               "evento de auditoría registrado");
        Ok(())
    }
}

/// Registra dominio no evaluado (cortocircuito por deny previo).
pub async fn record_skipped(pg: &PgPool, base: &AuditEvent, domain: i16) -> Result<(), AuditError> {
    AuditEvent { policy_state: 0, result: 2, policy_slug: None, domain_code: domain, ..base.clone() }.insert(pg).await
}

/// Registra decisión de un dominio específico.
pub async fn record_decision(pg: &PgPool, base: &AuditEvent, domain: i16,
    state: i16, result: i16, slug: Option<&str>) -> Result<(), AuditError> {
    AuditEvent { domain_code: domain, policy_state: state, result,
        policy_slug: slug.map(|s| s.to_string()), ..base.clone() }.insert(pg).await
}

#[derive(Debug, thiserror::Error)]
pub enum AuditError {
    #[error("error de auditoría: {0}")]
    Database(String),
    #[error("ctx_id requerido (SBOS-049)")]
    MissingCtxId,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_event_construction() {
        let e = AuditEvent {
            ctx_id: "ctx-001".into(), tenant_id: uuid::Uuid::nil(), role_id: uuid::Uuid::nil(),
            app_code: 1, group_code: 1, atom_code: 1, atom_position: 0,
            bitmask_atom: 6295808, policy_state: 2, result: 1,
            policy_slug: Some("POL-D3-LIMITE".into()), evaluator: "bauth".into(), domain_code: 3,
        };
        assert_eq!(e.domain_code, 3);
        assert_eq!(e.result, 1);
    }

    #[test]
    fn test_error_missing_ctx() {
        assert!(AuditError::MissingCtxId.to_string().contains("ctx_id"));
    }
}
