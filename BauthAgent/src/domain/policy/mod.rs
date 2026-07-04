// ============================================================
// bauth::domain::policy — Motor de Políticas XACML 3.0
//
// Arquitectura: XACML 3.0 / NIST ABAC SP 800-162 / OPA/Rego / AWS IAM.
//
// ┌─────────────────────────────────────────────────────────────────┐
// │  ATENCIÓN: EXISTEN DOS CAPAS DE EVALUACIÓN DISTINTAS.          │
// │  Confundirlas genera handlers duplicados.                       │
// ├──────────────────────┬──────────────────────────────────────────┤
// │  CAPA A — XACML      │  CAPA B — ath_policy_dN (B9.T24)        │
// │  Fuente: bos_atom_policy.policy_data                            │
// │           → formato bos_policy_v1 complejo                     │
// │  Fuente: bauth.ath_policy_d1..d12                              │
// │           → formato simple {"rule":"X",...}                    │
// │  Uso: átomos de permiso por rol                                │
// │  Uso: evaluación de dominio en tiempo real                     │
// │  Entrypoint: bauth.policy.evaluate                              │
// │  Entrypoint: bauth.policy.domain.evaluate                      │
// │  Módulo: parser.rs → evaluate.rs                               │
// │  Módulo: ath_converter.rs → ath_loader.rs → evaluate.rs       │
// └──────────────────────┴──────────────────────────────────────────┘
//
// NOTA: cfg_policy_library (9,142 normas ISO/NIST/COBIT) NO se evalúa
//       en runtime — es una biblioteca de referencia consultable vía
//       bauth.policy.library.search (policy_domain.rs).
//
// Submódulos (todos ≤200 líneas):
//   condition.rs     — CompareOp (17 variantes), PolicyCondition, ConditionDetail
//   rule.rs          — PolicyRule, PolicyResult, PolicyData, EvaluateBlock, EvalContext
//   resolver.rs      — resolve_value(), haversine_km(), simple_cidr_match()
//   parser.rs        — parse_policy_data(), load_from_json() — SOLO para Capa A
//   evaluate.rs      — eval_condition(), eval_rule(), evaluate() — motor compartido
//   ath_converter.rs — convierte {"rule":"X"} → PolicyRule (Capa B)
//   ath_loader.rs    — carga ath_policy_dN D1-D12 desde PostgreSQL (Capa B)
// ============================================================

#![allow(dead_code)]
use crate::bitmask::PolicyState;

pub mod condition;
pub mod rule;
pub mod resolver;
pub mod parser;
pub mod evaluate;
pub mod tests;
pub mod ath_converter;  // B9.T24: convierte config ath_policy_dN → PolicyRule
pub mod ath_loader;     // B9.T24: carga ath_policy_dN desde PostgreSQL
pub mod conflict;       // B9.T26: detector de conflictos XACML 3.0

#[allow(unused_imports)]
pub use condition::{CompareOp, PolicyCondition};
pub use evaluate::{eval_condition, eval_rule, evaluate};
pub use parser::{from_policy_data, load_from_json, parse_policy_data};
#[allow(unused_imports)]
pub use rule::{EvalContext, LogicOp, PolicyData, PolicyResult, PolicyRule};

/// Estructura vacía — el intérprete no tiene estado.
pub struct PolicyEngine;

impl PolicyEngine {
    pub fn parse_policy_data(json: &serde_json::Value) -> Result<PolicyData, String> {
        parse_policy_data(json)
    }
    pub fn from_policy_data(pd: &PolicyData) -> PolicyRule {
        from_policy_data(pd)
    }
    pub fn eval_condition(cond: &PolicyCondition, ctx: &EvalContext) -> bool {
        eval_condition(cond, ctx)
    }
    pub fn eval_rule(rule: &PolicyRule, ctx: &EvalContext) -> PolicyResult {
        eval_rule(rule, ctx)
    }
    pub fn evaluate(rules: &[PolicyRule], ctx: &EvalContext) -> (bool, PolicyState, Vec<PolicyResult>) {
        evaluate(rules, ctx)
    }
    pub fn load_from_json(json: &serde_json::Value) -> Vec<PolicyRule> {
        load_from_json(json)
    }
}
