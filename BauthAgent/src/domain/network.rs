// D7 — Red (CIDR, VPN, Protocolo, Device Posture)
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const NETWORK_DOMAIN: DomainCode = 7;

pub struct NetworkEvaluator;
impl NetworkEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for NetworkEvaluator {
    fn domain_code(&self) -> DomainCode { NETWORK_DOMAIN }
    fn domain_name(&self) -> &'static str { "Red" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) { DomainResult::permitido(NETWORK_DOMAIN) }
        else { DomainResult::denegado(NETWORK_DOMAIN, "IP fuera de rango") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_cidr_allowed() {
        let rules = vec![PolicyRule { slug: "POL-D7-CIDR".into(), description: "CIDR".into(), domain: 7, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "client_ip".into(), op: CompareOp::CidrMatch, raw_value: serde_json::json!("10.0.0.0/8") }],
            logic: LogicOp::And, action: "deny".into(), message: "IP fuera de rango".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("client_ip".into(), serde_json::json!("10.50.1.100"));
        assert!(!NetworkEvaluator::evaluate_rules(&rules, &ctx).0, "10.x en rango → deny activa (condición cumple)");
    }
    #[test]
    fn test_cidr_blocked() {
        let rules = vec![PolicyRule { slug: "POL-D7-CIDR".into(), description: "CIDR".into(), domain: 7, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "client_ip".into(), op: CompareOp::CidrMatch, raw_value: serde_json::json!("10.0.0.0/8") }],
            logic: LogicOp::And, action: "deny".into(), message: "IP fuera de rango".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("client_ip".into(), serde_json::json!("203.0.113.50"));
        assert!(NetworkEvaluator::evaluate_rules(&rules, &ctx).0, "IP externa → deny no activa");
    }
    #[test]
    fn test_device_posture() {
        let rules = vec![PolicyRule { slug: "POL-D7-POSTURE".into(), description: "Posture".into(), domain: 7, priority: 10,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "os_patched".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "allow".into(), message: "Dispositivo conforme".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("os_patched".into(), serde_json::json!(true));
        assert!(NetworkEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_rate_limit() {
        let rules = vec![PolicyRule { slug: "POL-D7-RATE".into(), description: "Rate".into(), domain: 7, priority: 3,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "req_per_sec".into(), op: CompareOp::Gt, raw_value: serde_json::json!(100) }],
            logic: LogicOp::And, action: "deny".into(), message: "Rate limit excedido".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("req_per_sec".into(), serde_json::json!(150));
        assert!(!NetworkEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() {
        let e = NetworkEvaluator::new(); assert_eq!(e.domain_code(), 7); assert_eq!(e.domain_name(), "Red");
    }
}
