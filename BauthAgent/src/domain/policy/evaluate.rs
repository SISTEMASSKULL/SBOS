// ============================================================
// bauth::domain::policy::evaluate — Motor de evaluación de políticas
//
// eval_condition(): evalúa una condición atómica contra el contexto.
// eval_rule(): evalúa una regla completa (AND/OR sobre condiciones).
// evaluate(): evalúa un lote de reglas con cortocircuito en deny.
//
// Arquitectura: NIST ABAC SP 800-162 / OPA/Rego / AWS IAM.
// ============================================================

#![allow(dead_code)]
use super::condition::{CompareOp, ConditionDetail, PolicyCondition};
use super::resolver::{compare_numeric, haversine_km, simple_cidr_match};
use super::rule::{EvalContext, PolicyResult, PolicyRule};
use crate::bitmask::PolicyState;
use regex::Regex;

/// Evalúa una condición atómica contra el contexto.
/// Si el campo no existe: false (excepto para NotExists → true, Exists → false).
pub fn eval_condition(cond: &PolicyCondition, ctx: &EvalContext) -> bool {
    let actual = ctx.get(&cond.field);
    let value = &cond.raw_value;

    match cond.op {
        CompareOp::Exists => actual.is_some(),
        CompareOp::NotExists => actual.is_none(),
        _ => {
            let actual = match actual {
                Some(v) => v,
                None => return false,
            };
            match cond.op {
                CompareOp::Eq => actual == value,
                CompareOp::Ne => actual != value,
                CompareOp::Gt => compare_numeric(actual, value, |a, b| a > b),
                CompareOp::Gte => compare_numeric(actual, value, |a, b| a >= b),
                CompareOp::Lt => compare_numeric(actual, value, |a, b| a < b),
                CompareOp::Lte => compare_numeric(actual, value, |a, b| a <= b),
                CompareOp::In => {
                if let Some(arr) = value.as_array() {
                    arr.iter().any(|v| v == actual)
                } else {
                    tracing::warn!(field=%cond.field, value=?value, "operador 'in' espera un array — condición evaluada como falsa");
                    false
                }
            }
            CompareOp::NotIn => {
                if let Some(arr) = value.as_array() {
                    !arr.iter().any(|v| v == actual)
                } else {
                    // Si el valor no es un array (error de configuración), denegar: no está en la lista vacía
                    tracing::warn!(field=%cond.field, value=?value, "operador 'not_in' espera un array — denegando por seguridad");
                    false
                }
            }
            CompareOp::Contains => {
                let a = actual.as_str().unwrap_or("");
                let b = value.as_str().unwrap_or("");
                if a.is_empty() || b.is_empty() {
                    tracing::warn!(field=%cond.field, "operador 'contains' con valor vacío — condición evaluada como falsa");
                    false
                } else {
                    a.contains(b)
                }
            }
                CompareOp::Regex => actual.as_str().and_then(|a| {
                    value.as_str().and_then(|p| Regex::new(p).ok())
                        .map(|re| re.is_match(a))
                }).unwrap_or(false),
                CompareOp::CidrMatch | CompareOp::IpInRange => {
                    let ip = actual.as_str().unwrap_or("");
                    let cidr = value.as_str().unwrap_or("");
                    simple_cidr_match(ip, cidr)
                }
                CompareOp::GeoDistance => {
                    let max_km = value.get("max_km").and_then(|v| v.as_f64()).unwrap_or(0.0);
                    let ref_lat = value.get("lat").and_then(|v| v.as_f64()).unwrap_or(0.0);
                    let ref_lon = value.get("lon").and_then(|v| v.as_f64()).unwrap_or(0.0);
                    let coords = actual.as_array().and_then(|a| {
                        Some((a.first()?.as_f64()?, a.get(1)?.as_f64()?))
                    });
                    coords.map(|(lat, lon)| haversine_km(lat, lon, ref_lat, ref_lon) <= max_km)
                        .unwrap_or(false)
                }
                CompareOp::TimeBetween => {
                    let now = actual.as_str().unwrap_or("");
                    let start = value.get("start").and_then(|v| v.as_str()).unwrap_or("00:00");
                    let end = value.get("end").and_then(|v| v.as_str()).unwrap_or("23:59");
                    now >= start && now <= end
                }
                CompareOp::StringLen => {
                    let len = actual.as_str().map(|s| s.len()).unwrap_or(0);
                    len >= value.as_u64().unwrap_or(0) as usize
                }
                CompareOp::Exists | CompareOp::NotExists => unreachable!(),
            }
        }
    }
}

/// Evalúa una regla completa (condiciones combinadas con AND/OR).
pub fn eval_rule(rule: &PolicyRule, ctx: &EvalContext) -> PolicyResult {
    let mut details = Vec::new();
    let conditions_met = match rule.logic {
        super::rule::LogicOp::And => rule.conditions.iter().all(|c| {
            let m = eval_condition(c, ctx);
            details.push(ConditionDetail {
                field: c.field.clone(), op: format!("{:?}", c.op),
                expected: c.raw_value.clone(),
                actual: ctx.get(&c.field).cloned().unwrap_or(serde_json::Value::Null), matched: m,
            });
            m
        }),
        super::rule::LogicOp::Or => rule.conditions.iter().any(|c| {
            let m = eval_condition(c, ctx);
            details.push(ConditionDetail {
                field: c.field.clone(), op: format!("{:?}", c.op),
                expected: c.raw_value.clone(),
                actual: ctx.get(&c.field).cloned().unwrap_or(serde_json::Value::Null), matched: m,
            });
            m
        }),
    };

    let (_passed, state) = match rule.action.as_str() {
        "deny" if conditions_met => (false, PolicyState::Rechazado),
        "deny" => (true, PolicyState::Aprobado),
        "allow" if conditions_met => (true, PolicyState::Aprobado),
        "allow" => (false, PolicyState::Rechazado),
        "step_up" | "pending_approval" | "mfa_required" if conditions_met => (true, PolicyState::Pendiente),
        "step_up" | "pending_approval" | "mfa_required" => (true, PolicyState::Aprobado),
        _ if conditions_met => (true, PolicyState::Aprobado),
        _ => (false, PolicyState::Rechazado),
    };

    PolicyResult {
        slug: rule.slug.clone(), conditions_met, action: rule.action.clone(), state,
        message: if conditions_met { rule.message.clone() } else { format!("{}: no aplica", rule.slug) },
        condition_details: details,
    }
}

/// Evalúa una lista de reglas contra un contexto.
///
/// Algoritmo:
///   1. Ordena por priority (menor = primero)
///   2. Evalúa secuencialmente
///   3. Cortocircuito en "deny" (si una regla deniega, se detiene)
///   4. "step_up" / "pending_approval" / "mfa_required" no detienen pero marcan Pendiente
///
/// Retorna: (permitido, estado_global, resultados_individuales)
pub fn evaluate(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, PolicyState, Vec<PolicyResult>) {
    let mut results = Vec::new();
    let mut denied = false;
    let mut pending = false;

    let mut sorted: Vec<&PolicyRule> = rules.iter().collect();
    sorted.sort_by_key(|r| r.priority);

    for rule in &sorted {
        let result = eval_rule(rule, ctx);
        if result.conditions_met && result.action == "deny" { denied = true; }
        if result.state == PolicyState::Pendiente { pending = true; }
        results.push(result);
        if denied { break; }
    }

    let state = if denied { PolicyState::Rechazado }
        else if pending { PolicyState::Pendiente }
        else { PolicyState::Aprobado };

    (!denied, state, results)
}
