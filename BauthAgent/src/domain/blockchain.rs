// D12 — Blockchain (Merkle Anchoring + Liquidación Besu QBFT)
// SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const BLOCKCHAIN_DOMAIN: DomainCode = 12;

pub struct BlockchainEvaluator;
impl BlockchainEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for BlockchainEvaluator {
    fn domain_code(&self) -> DomainCode { BLOCKCHAIN_DOMAIN }
    fn domain_name(&self) -> &'static str { "Blockchain" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) { DomainResult::permitido(BLOCKCHAIN_DOMAIN) }
        else { DomainResult::denegado(BLOCKCHAIN_DOMAIN, "anclaje blockchain no verificado") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_anchor_frequency_gold() {
        let rules = vec![PolicyRule { slug: "POL-D12-ANCHOR".into(), description: "Frecuencia".into(), domain: 12, priority: 10,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "anchor_interval_h".into(), op: CompareOp::Lte, raw_value: serde_json::json!(1) }],
            logic: LogicOp::And, action: "allow".into(), message: "Gold tier: 1h".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("anchor_interval_h".into(), serde_json::json!(0.5));
        assert!(BlockchainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_gas_balance_ok() {
        let rules = vec![PolicyRule { slug: "POL-D12-GAS".into(), description: "Gas".into(), domain: 12, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "eth_balance".into(), op: CompareOp::Gte, raw_value: serde_json::json!(0.005) }],
            logic: LogicOp::And, action: "allow".into(), message: "Gas suficiente".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("eth_balance".into(), serde_json::json!(0.01));
        assert!(BlockchainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_gas_balance_low() {
        let rules = vec![PolicyRule { slug: "POL-D12-GAS".into(), description: "Gas".into(), domain: 12, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "eth_balance".into(), op: CompareOp::Lt, raw_value: serde_json::json!(0.005) }],
            logic: LogicOp::And, action: "deny".into(), message: "Gas insuficiente".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("eth_balance".into(), serde_json::json!(0.001));
        assert!(!BlockchainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_settlement_confirmations() {
        let rules = vec![PolicyRule { slug: "POL-D12-CONFIRM".into(), description: "Confirmaciones".into(), domain: 12, priority: 15,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "confirmations".into(), op: CompareOp::Gte, raw_value: serde_json::json!(1) }],
            logic: LogicOp::And, action: "allow".into(), message: "Confirmaciones suficientes".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("confirmations".into(), serde_json::json!(3));
        assert!(BlockchainEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() { let e = BlockchainEvaluator::new(); assert_eq!(e.domain_code(), 12); }
}
