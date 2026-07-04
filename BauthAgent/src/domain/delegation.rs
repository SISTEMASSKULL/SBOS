// D10 — Delegación (Privilegios Temporales, Vigencia)
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const DELEGATION_DOMAIN: DomainCode = 10;

pub struct DelegationEvaluator;
impl DelegationEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for DelegationEvaluator {
    fn domain_code(&self) -> DomainCode { DELEGATION_DOMAIN }
    fn domain_name(&self) -> &'static str { "Delegación" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) { DomainResult::permitido(DELEGATION_DOMAIN) }
        else { DomainResult::denegado(DELEGATION_DOMAIN, "delegación no permitida") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_max_duration_exceeded() {
        let rules = vec![PolicyRule { slug: "POL-D10-DURATION".into(), description: "Duración".into(), domain: 10, priority: 40,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "delegation_days".into(), op: CompareOp::Gt, raw_value: serde_json::json!(21) }],
            logic: LogicOp::And, action: "deny".into(), message: "Duración excedida".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("delegation_days".into(), serde_json::json!(30));
        assert!(!DelegationEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_max_duration_ok() {
        let rules = vec![PolicyRule { slug: "POL-D10-DURATION".into(), description: "Duración".into(), domain: 10, priority: 40,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "delegation_days".into(), op: CompareOp::Gt, raw_value: serde_json::json!(21) }],
            logic: LogicOp::And, action: "deny".into(), message: "Duración OK".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("delegation_days".into(), serde_json::json!(7));
        assert!(DelegationEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_and_reduction() {
        let rules = vec![PolicyRule { slug: "POL-D10-AND".into(), description: "AND reduction".into(), domain: 10, priority: 10,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "mask_reduced".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "allow".into(), message: "Mínimo privilegio".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("mask_reduced".into(), serde_json::json!(true));
        assert!(DelegationEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_sod_precheck() {
        let rules = vec![PolicyRule { slug: "POL-D10-SOD".into(), description: "SoD check".into(), domain: 10, priority: 35,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "sod_conflict".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "deny".into(), message: "Conflicto SoD".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("sod_conflict".into(), serde_json::json!(true));
        assert!(!DelegationEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() { let e = DelegationEvaluator::new(); assert_eq!(e.domain_code(), 10); }
}
