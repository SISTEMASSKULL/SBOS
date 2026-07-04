// D5 — Biométrico (Huella, Rostro, LoA) · NIST SP 800-63B
// External-Path: FastPath verifica átomo en RolBitMask (<0.5ns).
// Superado → Keycloak evalúa LoA, liveness, intentos máximos vía SPIs.
// El resultado se refleja en policy_state del JWT: 00=NoAplica, 01=Pendiente(step-up), 10=Aprobado.
#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const BIOMETRIC_DOMAIN: DomainCode = 5;

pub struct BiometricEvaluator;
impl BiometricEvaluator {
    pub fn new() -> Self { Self }

    /// Evalúa reglas biométricas (LoA, liveness, intentos) contra el contexto del usuario.
    /// Usado por el External-Path cuando Keycloak ya resolvió la autenticación biométrica.
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx); (passed, results)
    }
}
impl DomainEvaluator for BiometricEvaluator {
    fn domain_code(&self) -> DomainCode { BIOMETRIC_DOMAIN }
    fn domain_name(&self) -> &'static str { "Biométrico" }

    /// Flujo D5:
    ///   1. FastPath: ¿átomo en RolBitMask? → NO → DENEGADO
    ///   2. External-Path: Keycloak evalúa LoA + liveness + intentos
    ///      El LoA se almacena en ses_context.loa_current durante el login.
    ///      Si LoA < requerido → PENDIENTE (step-up RFC 9470).
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) {
            // FastPath OK — el átomo está en el RolBitMask.
            // La verificación biométrica real (LoA, liveness) ocurrió en Keycloak durante el login.
            // El resultado ya está en ses_context.loa_current y en el JWT.
            DomainResult::permitido(BIOMETRIC_DOMAIN)
        } else {
            DomainResult::denegado(BIOMETRIC_DOMAIN, "átomo biométrico no asignado al rol")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};
    #[test]
    fn test_loa_sufficient() {
        let rules = vec![PolicyRule { slug: "POL-D5-LOA".into(), description: "LoA".into(), domain: 5, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "loa_level".into(), op: CompareOp::Gte, raw_value: serde_json::json!(2) }],
            logic: LogicOp::And, action: "allow".into(), message: "LoA suficiente".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("loa_level".into(), serde_json::json!(3));
        assert!(BiometricEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_loa_insufficient() {
        let rules = vec![PolicyRule { slug: "POL-D5-LOA".into(), description: "LoA".into(), domain: 5, priority: 1,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "loa_level".into(), op: CompareOp::Lt, raw_value: serde_json::json!(3) }],
            logic: LogicOp::And, action: "deny".into(), message: "LoA insuficiente".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("loa_level".into(), serde_json::json!(1));
        assert!(!BiometricEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_liveness_required() {
        let rules = vec![PolicyRule { slug: "POL-D5-LIVE".into(), description: "Liveness".into(), domain: 5, priority: 2,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "liveness_passed".into(), op: CompareOp::Eq, raw_value: serde_json::json!(true) }],
            logic: LogicOp::And, action: "allow".into(), message: "Prueba de vida".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("liveness_passed".into(), serde_json::json!(true));
        assert!(BiometricEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_max_attempts() {
        let rules = vec![PolicyRule { slug: "POL-D5-ATTEMPTS".into(), description: "Intentos".into(), domain: 5, priority: 3,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "attempts".into(), op: CompareOp::Gt, raw_value: serde_json::json!(3) }],
            logic: LogicOp::And, action: "deny".into(), message: "Máx intentos".into() }];
        let mut ctx = EvalContext::new(); ctx.insert("attempts".into(), serde_json::json!(5));
        assert!(!BiometricEvaluator::evaluate_rules(&rules, &ctx).0);
    }
    #[test]
    fn test_domain_evaluator() { let e = BiometricEvaluator::new(); assert_eq!(e.domain_code(), 5); }
}
