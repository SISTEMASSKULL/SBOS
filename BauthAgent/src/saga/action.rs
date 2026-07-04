// ============================================================
// bauth::saga::action — Acción compuesta de saga (H-10)
//
// SagaAction: secuencia de pasos con lógica de flujo.
// SagaResult: resultado de la ejecución completa.
// ============================================================
#![allow(dead_code)]
use super::step::{SagaStep, StepDetail};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

/// Tipo de secuencia para la ejecución de pasos.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum SequenceOp {
    Sequential,
    Parallel,
    Conditional,
}

/// Estrategia de compensación si la saga falla.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CompensationStrategy {
    FullRollback,
    BestEffort,
    Checkpoint,
    Manual,
    NoCompensation,
}

impl CompensationStrategy {
    pub fn from_str(s: &str) -> Self {
        match s {
            "full_rollback" => CompensationStrategy::FullRollback,
            "best_effort"   => CompensationStrategy::BestEffort,
            "checkpoint"    => CompensationStrategy::Checkpoint,
            "manual"        => CompensationStrategy::Manual,
            _               => CompensationStrategy::NoCompensation,
        }
    }
}

/// Contexto de evaluación de la saga compartido entre pasos.
#[derive(Clone)]
pub struct SagaEvalContext {
    pub saga_name: String,
    pub saga_id: String,
    pub ctx_id: String,
    pub params: Value,
    pub state: HashMap<String, Value>,
    pub started_at: chrono::DateTime<chrono::Utc>,
    /// B35: ActionRegistry para ejecución real (None = modo simulación)
    pub registry: Option<std::sync::Arc<crate::saga::registry::ActionRegistry>>,
}

impl std::fmt::Debug for SagaEvalContext {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SagaEvalContext")
            .field("saga_name", &self.saga_name)
            .field("saga_id", &self.saga_id)
            .field("ctx_id", &self.ctx_id)
            .field("params", &self.params)
            .field("state", &self.state)
            .field("started_at", &self.started_at)
            .field("registry", &self.registry.as_ref().map(|_| "ActionRegistry"))
            .finish()
    }
}

/// Acción de saga completa.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SagaAction {
    pub name: String,
    pub version: String,
    pub description: String,
    pub sequence: SequenceOp,
    pub steps: Vec<SagaStep>,
    pub max_total_timeout_ms: u64,
    pub compensation_strategy: CompensationStrategy,
}

/// Resultado de la ejecución completa.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SagaResult {
    pub saga_name: String,
    pub saga_id: String,
    pub status: SagaStatus,
    pub steps_executed: usize,
    pub steps_compensated: usize,
    pub step_details: Vec<StepDetail>,
    pub final_state: HashMap<String, Value>,
    pub duration_ms: u64,
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum SagaStatus {
    Completed,
    PartiallyCompleted { failed_step: String },
    Compensated,
    Failed { reason: String },
    Timeout,
    Rejected { reason: String },
}

impl SagaStatus {
    pub fn is_success(&self) -> bool {
        matches!(self, SagaStatus::Completed)
    }
}
