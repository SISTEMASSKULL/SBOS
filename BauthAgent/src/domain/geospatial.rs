// ============================================================
// bauth::domain::geospatial — D6 Geoespacial (País, Viaje Imposible)
// SBOS-BAUTH-MOTORES-DOMINIO.md §D6
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{registry::{DomainEvaluator, DomainResult}, AtomBitMask, AtomPosition, DomainCode, RolBitMask};
use crate::domain::policy::{EvalContext, PolicyEngine, PolicyRule};
pub const GEOSPATIAL_DOMAIN: DomainCode = 6;

pub struct GeospatialEvaluator;
impl GeospatialEvaluator {
    pub fn new() -> Self { Self }
    pub fn evaluate_rules(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, Vec<crate::domain::policy::PolicyResult>) {
        let (passed, _, results) = PolicyEngine::evaluate(rules, ctx);
        (passed, results)
    }
}
impl DomainEvaluator for GeospatialEvaluator {
    fn domain_code(&self) -> DomainCode { GEOSPATIAL_DOMAIN }
    fn domain_name(&self) -> &'static str { "Geoespacial" }
    fn evaluate(&self, _ctx: &str, _user: &str, rol: &RolBitMask, ap: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
        if rol.check(ap) { DomainResult::permitido(GEOSPATIAL_DOMAIN) }
        else { DomainResult::denegado(GEOSPATIAL_DOMAIN, "ubicación no permitida") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::policy::{CompareOp, LogicOp};

    #[test]
    fn test_country_allowlist_deny() {
        let rules = vec![PolicyRule {
            slug: "POL-D6-COUNTRY".into(), description: "País".into(), domain: 6, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "country".into(), op: CompareOp::NotIn, raw_value: serde_json::json!(["BO","AR","CL"]) }],
            logic: LogicOp::And, action: "deny".into(), message: "País no permitido".into(),
        }];
        let mut ctx = EvalContext::new(); ctx.insert("country".into(), serde_json::json!("VE"));
        let (ok, _) = GeospatialEvaluator::evaluate_rules(&rules, &ctx);
        assert!(!ok, "VE no en allowlist → deny");
    }

    #[test]
    fn test_country_allowlist_ok() {
        let rules = vec![PolicyRule {
            slug: "POL-D6-COUNTRY".into(), description: "País".into(), domain: 6, priority: 5,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "country".into(), op: CompareOp::NotIn, raw_value: serde_json::json!(["BO","AR","CL"]) }],
            logic: LogicOp::And, action: "deny".into(), message: "País no permitido".into(),
        }];
        let mut ctx = EvalContext::new(); ctx.insert("country".into(), serde_json::json!("BO"));
        let (ok, _) = GeospatialEvaluator::evaluate_rules(&rules, &ctx);
        assert!(ok, "BO en allowlist → OK");
    }

    #[test]
    fn test_impossible_travel() {
        let rules = vec![PolicyRule {
            slug: "POL-D6-TRAVEL".into(), description: "Viaje".into(), domain: 6, priority: 10,
            conditions: vec![
                crate::domain::policy::PolicyCondition { field: "distance_km".into(), op: CompareOp::Gt, raw_value: serde_json::json!(900) },
                crate::domain::policy::PolicyCondition { field: "time_h".into(), op: CompareOp::Lt, raw_value: serde_json::json!(1) },
            ],
            logic: LogicOp::And, action: "deny".into(), message: "Viaje imposible".into(),
        }];
        let mut ctx = EvalContext::new(); ctx.insert("distance_km".into(), serde_json::json!(5000)); ctx.insert("time_h".into(), serde_json::json!(0.5));
        assert!(!GeospatialEvaluator::evaluate_rules(&rules, &ctx).0);
        let mut ctx2 = EvalContext::new(); ctx2.insert("distance_km".into(), serde_json::json!(100)); ctx2.insert("time_h".into(), serde_json::json!(2.0));
        assert!(GeospatialEvaluator::evaluate_rules(&rules, &ctx2).0);
    }

    #[test]
    fn test_geofence() {
        let rules = vec![PolicyRule {
            slug: "POL-D6-GEOFENCE".into(), description: "Perímetro".into(), domain: 6, priority: 15,
            conditions: vec![crate::domain::policy::PolicyCondition { field: "user_location".into(), op: CompareOp::GeoDistance, raw_value: serde_json::json!({"lat":-16.5,"lon":-68.15,"max_km":0.5}) }],
            logic: LogicOp::And, action: "deny".into(), message: "Fuera de perímetro".into(),
        }];
        let mut ctx = EvalContext::new(); ctx.insert("user_location".into(), serde_json::json!([-16.5005, -68.1505]));
        assert!(!GeospatialEvaluator::evaluate_rules(&rules, &ctx).0, "dentro de 500m → deny activa");
    }

    #[test]
    fn test_domain_evaluator() {
        let e = GeospatialEvaluator::new();
        assert_eq!(e.domain_code(), 6);
        assert_eq!(e.domain_name(), "Geoespacial");
    }
}
