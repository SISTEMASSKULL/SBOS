// D8 — Contexto (ctx_id, Sesión, Trazabilidad) · SBOS-049
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const CONTEXT_DOMAIN: DomainCode = 8;

pub struct ContextEvaluator;
impl ContextEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for ContextEvaluator {
    fn domain_code(&self) -> DomainCode { CONTEXT_DOMAIN }
    fn domain_name(&self) -> &'static str { "Contexto" }
    fn evaluate(&self, _ctx: &str, _user: &str, _rol: &RolBitMask, _ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        DomainResult::permitido(CONTEXT_DOMAIN) // Pre-BitMask: se evalúa antes del fast-path
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_ctx_required_present() {
        let rules = vec![PolicyRule { slug: "POL-D8-CTX".into(), description: "ctx_id".into(), domain: 8, priority: 0,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "ctx_id".into(), op: CompareOp::Exists, raw_value: serde_json::Value::Null }],
            logic: LogicOp::And, action: "deny".into(), message: "ctx_id requerido".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("ctx_id".into(), serde_json::json!("ctx-abc"));
        assert!(!ContextEvaluator::evaluate_rules(&rules, &ctx).0, "ctx_id existe → deny activa");
    }
    #[test]
    fn test_ctx_required_missing() {
        let rules = vec![PolicyRule { slug: "POL-D8-CTX".into(), description: "ctx_id".into(), domain: 8, priority: 0,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "ctx_id".into(), op: CompareOp::Exists, raw_value: serde_json::Value::Null }],
            logic: LogicOp::And, action: "deny".into(), message: "ctx_id requerido".into() }];
        assert!(ContextEvaluator::evaluate_rules(&rules, &EvalContext::new()).0, "sin ctx_id → deny no activa");
    }
    #[test]
    fn test_ctx_structure_valid() {
        let rules = vec![PolicyRule { slug: "POL-D8-STRUCT".into(), description: "Estructura".into(), domain: 8, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "has_6_fields".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "deny".into(), message: "ctx_id inválido".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("has_6_fields".into(), serde_json::json!(true));
        assert!(!ContextEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_anti_replay() {
        let rules = vec![PolicyRule { slug: "POL-D8-REPLAY".into(), description: "Anti-replay".into(), domain: 8, priority: 2,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "nonce_used".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "deny".into(), message: "Nonce reutilizado".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("nonce_used".into(), serde_json::json!(true));
        assert!(!ContextEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() { let e = ContextEvaluator::new(); assert_eq!(e.domain_code(), 8); }
}
