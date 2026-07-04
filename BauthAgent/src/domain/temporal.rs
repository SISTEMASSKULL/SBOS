// ============================================================
// bauth::domain::temporal — D4 Temporal (Horarios, Turnos, Feriados)
// SBOS-BAUTH-MOTORES-DOMINIO.md §D4
//
// Sin átomos propios — se activa encadenado a átomos de D1.
// Políticas: shift, holiday, max-session, inactivity, grace-period, overtime.
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};

pub const TEMPORAL_DOMAIN: DomainCode = 4;

pub struct TemporalEvaluator;

impl TemporalEvaluator {
    pub fn new() -> Self { Self }

    /// Evalúa políticas temporales contra el contexto.
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx);
        (passed, results)
    }
}

impl DomainEvaluator for TemporalEvaluator {
    fn domain_code(&self) -> DomainCode { TEMPORAL_DOMAIN }
    fn domain_name(&self) -> &'static str { "Temporal" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, atom_position: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(atom_position) { DomainResult::permitido(TEMPORAL_DOMAIN) }
        else { DomainResult::denegado(TEMPORAL_DOMAIN, "fuera de horario laboral") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};

    #[test]
    fn test_shift_inside_hours() {
        let rules = vec![PolicyRule {
            slug: "POL-D4-SHIFT".into(), description: "Horario".into(), domain: 4, priority: 30,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "now_time".into(), op: CompareOp::TimeBetween, raw_value: serde_json::json!({"start":"08:00","end":"17:00"}) }],
            logic: LogicOp::And, action: "deny".into(), message: "Fuera de horario".into(),
        }];
        let mut ctx = EvalContext::new();
        ctx.insert("now_time".into(), serde_json::json!("14:30"));
        let (ok, _) = TemporalEvaluator::evaluate_rules(&rules, &ctx);
        assert!(!ok, "14:30 dentro de horario → deny activa = false → la condición time_between cumple");
    }

    #[test]
    fn test_shift_outside_hours() {
        let rules = vec![PolicyRule {
            slug: "POL-D4-SHIFT".into(), description: "Horario".into(), domain: 4, priority: 30,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "now_time".into(), op: CompareOp::TimeBetween, raw_value: serde_json::json!({"start":"08:00","end":"17:00"}) }],
            logic: LogicOp::And, action: "deny".into(), message: "Fuera de horario".into(),
        }];
        let mut ctx = EvalContext::new();
        ctx.insert("now_time".into(), serde_json::json!("03:00"));
        let (ok, _) = TemporalEvaluator::evaluate_rules(&rules, &ctx);
        assert!(ok, "03:00 fuera de horario → condición no cumple → deny no aplica");
    }

    #[test]
    fn test_inactivity_timeout() {
        let rules = vec![PolicyRule {
            slug: "POL-D4-INACTIVITY".into(), description: "Inactividad".into(), domain: 4, priority: 35,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "idle_minutes".into(), op: CompareOp::Gt, raw_value: serde_json::json!(15) }],
            logic: LogicOp::And, action: "mfa_required".into(), message: "Sesión inactiva".into(),
        }];
        let mut ctx = EvalContext::new();
        ctx.insert("idle_minutes".into(), serde_json::json!(20));
        let (ok, results) = TemporalEvaluator::evaluate_rules(&rules, &ctx);
        assert!(ok);
        assert!(results.iter().any(|r| r.action == "mfa_required"));
    }

    #[test]
    fn test_max_session_duration() {
        let rules = vec![PolicyRule {
            slug: "POL-D4-MAX-SESSION".into(), description: "Sesión máxima".into(), domain: 4, priority: 32,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "session_hours".into(), op: CompareOp::Gt, raw_value: serde_json::json!(8) }],
            logic: LogicOp::And, action: "deny".into(), message: "Sesión excedida".into(),
        }];
        let mut ctx = EvalContext::new();
        ctx.insert("session_hours".into(), serde_json::json!(10));
        let (ok, _) = TemporalEvaluator::evaluate_rules(&rules, &ctx);
        assert!(!ok, "10h > 8h → deny");
    }

    #[test]
    fn test_domain_evaluator_impl() {
        let eval = TemporalEvaluator::new();
        assert_eq!(eval.domain_code(), 4);
        assert_eq!(eval.domain_name(), "Temporal");
        let rol = RolBitMask::from_positions(&[0], 180);
        let atom = AtomBitMask::from_u64(0);
        let result = eval.evaluate("", "", &rol, 0, &atom);
        assert_eq!(result.domain, TEMPORAL_DOMAIN);
    }
}
