// D9 — Credenciales (Passwords, MFA, Certificados) · NIST SP 800-63B
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const CREDENTIAL_DOMAIN: DomainCode = 9;

pub struct CredentialEvaluator;
impl CredentialEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for CredentialEvaluator {
    fn domain_code(&self) -> DomainCode { CREDENTIAL_DOMAIN }
    fn domain_name(&self) -> &'static str { "Credenciales" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) { DomainResult::permitido(CREDENTIAL_DOMAIN) }
        else { DomainResult::denegado(CREDENTIAL_DOMAIN, "credenciales inválidas") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_password_length_ok() {
        let rules = vec![PolicyRule { slug: "POL-D9-PASS".into(), description: "Password".into(), domain: 9, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "password".into(), op: CompareOp::StringLen, raw_value: serde_json::json!(12) }],
            logic: LogicOp::And, action: "deny".into(), message: "Contraseña corta".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("password".into(), serde_json::json!("longenoughpassword"));
        assert!(!CredentialEvaluator::evaluate_rules(&rules, &ctx).0, "len>=12 → deny activa (condición cumple)");
    }
    #[test]
    fn test_password_length_fail() {
        let rules = vec![PolicyRule { slug: "POL-D9-PASS".into(), description: "Password".into(), domain: 9, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "password".into(), op: CompareOp::StringLen, raw_value: serde_json::json!(12) }],
            logic: LogicOp::And, action: "deny".into(), message: "Contraseña corta".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("password".into(), serde_json::json!("short"));
        assert!(CredentialEvaluator::evaluate_rules(&rules, &ctx).0, "len<12 → deny no activa");
    }
    #[test]
    fn test_mfa_enrolled() {
        let rules = vec![PolicyRule { slug: "POL-D9-MFA".into(), description: "MFA".into(), domain: 9, priority: 2,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "mfa_enrolled".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "allow".into(), message: "MFA requerido".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("mfa_enrolled".into(), serde_json::json!(true));
        assert!(CredentialEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_token_binding() {
        let rules = vec![PolicyRule { slug: "POL-D9-BINDING".into(), description: "Token".into(), domain: 9, priority: 3,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "token_bound".into(), op: CompareOp::Eq, raw_value: serde_json::json!(false) }],
            logic: LogicOp::And, action: "deny".into(), message: "Token no vinculado".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("token_bound".into(), serde_json::json!(false));
        assert!(!CredentialEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() { let e = CredentialEvaluator::new(); assert_eq!(e.domain_code(), 9); }
}
