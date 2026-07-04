// ============================================================
// bauth::domain::policy::rule — Reglas, resultados y documento JSONB
//
// PolicyRule: una regla evaluable (condiciones + acción).
// PolicyData: representación fiel del JSONB bos_atom_policy.policy_data.
// PolicyResult: resultado de evaluar una regla.
// ============================================================

#![allow(dead_code)]
use super::condition::{ConditionDetail, PolicyCondition};
use crate::bitmask::PolicyState;
use std::collections::HashMap;

/// Combinador lógico entre condiciones.
#[derive(Debug, Clone)]
pub enum LogicOp {
    And,
    Or,
}

/// Una regla de política completamente resuelta (condiciones + acción).
#[derive(Debug, Clone)]
pub struct PolicyRule {
    pub slug: String,
    pub description: String,
    pub domain: u8,
    pub priority: i32,
    pub conditions: Vec<PolicyCondition>,
    pub logic: LogicOp,
    pub action: String,
    pub message: String,
}

/// Resultado de evaluar una regla.
#[derive(Debug, Clone)]
pub struct PolicyResult {
    pub slug: String,
    pub conditions_met: bool,
    pub action: String,
    pub state: PolicyState,
    pub message: String,
    /// Detalle de cada condición evaluada (para auditoría).
    pub condition_details: Vec<ConditionDetail>,
}

/// Representación fiel del JSONB en `bos_atom_policy.policy_data`.
#[derive(Debug, Clone)]
pub struct PolicyData {
    pub schema: String,
    pub priority: i32,
    pub action: String,
    pub message: String,
    pub evaluate: EvaluateBlock,
    pub params: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone)]
pub struct EvaluateBlock {
    pub logic: LogicOp,
    pub conditions: Vec<PolicyCondition>,
}

/// Contexto de evaluación: mapa de valores extraídos del request.
pub type EvalContext = HashMap<String, serde_json::Value>;
