// D11 — Auditoría (WORM, Trazabilidad, Compliance) · ISO 27001 A.8.15
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const AUDIT_DOMAIN: DomainCode = 11;

pub struct AuditDomainEvaluator;
impl AuditDomainEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for AuditDomainEvaluator {
    fn domain_code(&self) -> DomainCode { AUDIT_DOMAIN }
    fn domain_name(&self) -> &'static str { "Auditoría" }
    fn evaluate(&self, _ctx: &str, _user: &str, _rol: &RolBitMask, _ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        DomainResult::permitido(AUDIT_DOMAIN) // Post-hoc: siempre permite, solo registra
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_worm_insert_only() {
        let rules = vec![PolicyRule { slug: "POL-D11-WORM".into(), description: "WORM".into(), domain: 11, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "operation".into(), op: CompareOp::Eq, raw_value: serde_json::json!("INSERT") }],
            logic: LogicOp::And, action: "allow".into(), message: "Solo INSERT".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("operation".into(), serde_json::json!("INSERT"));
        assert!(AuditDomainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_ctx_required_for_audit() {
        let rules = vec![PolicyRule { slug: "POL-D11-CTX".into(), description: "ctx_id".into(), domain: 11, priority: 0,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "ctx_id".into(), op: CompareOp::Exists, raw_value: serde_json::Value::Null }],
            logic: LogicOp::And, action: "deny".into(), message: "ctx_id requerido".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("ctx_id".into(), serde_json::json!("ctx-001"));
        assert!(!AuditDomainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_retention_check() {
        let rules = vec![PolicyRule { slug: "POL-D11-RETENTION".into(), description: "Retención".into(), domain: 11, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "event_age_days".into(), op: CompareOp::Gt, raw_value: serde_json::json!(365) }],
            logic: LogicOp::And, action: "allow".into(), message: "Dentro de retención".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("event_age_days".into(), serde_json::json!(400));
        assert!(AuditDomainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_integrity_check() {
        let rules = vec![PolicyRule { slug: "POL-D11-INTEGRITY".into(), description: "Integridad".into(), domain: 11, priority: 10,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "hash_chain_intact".into(), op: CompareOp::Eq, raw_value: serde_json::json!(false) }],
            logic: LogicOp::And, action: "deny".into(), message: "Cadena rota".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("hash_chain_intact".into(), serde_json::json!(false));
        assert!(!AuditDomainEvaluator::evaluate_rules(&rules, &ctx).0, "cadena rota → deny");
    }
    #[test]
    fn test_domain_evaluator() { let e = AuditDomainEvaluator::new(); assert_eq!(e.domain_code(), 11); }
}
