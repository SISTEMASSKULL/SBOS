// ============================================================
// bauth::saga::step — Tipos atómicos del motor de sagas (H-10)
//
// SagaOp: 10 operaciones de paso de saga.
// SagaStep: un paso individual con acción + compensación.
// StepDetail: resultado detallado de un paso (auditoría).
// ============================================================
#![allow(dead_code)]
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Operaciones de paso de saga.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum SagaOp {
    Execute,      // Ejecutar acción principal
    Validate,     // Validar precondición (sin efectos secundarios)
    Compensate,   // Deshacer paso ya completado
    Await,        // Esperar evento externo (ej: callback OIDC)
    WaitFor,      // Esperar condición (ej: MFA aprobada)
    Emit,         // Emitir evento a Redis Stream
    Checkpoint,   // Guardar estado para posible resume
    Rollback,     // Volver a checkpoint anterior
    Notify,       // Notificar a otro daemon
    NoOp,         // Marcador de posición (ej: logging)
}

impl SagaOp {
    pub fn from_str(s: &str) -> Self {
        match s {
            "execute"    => SagaOp::Execute,
            "validate"   => SagaOp::Validate,
            "compensate" => SagaOp::Compensate,
            "await"      => SagaOp::Await,
            "wait_for"   => SagaOp::WaitFor,
            "emit"       => SagaOp::Emit,
            "checkpoint" => SagaOp::Checkpoint,
            "rollback"   => SagaOp::Rollback,
            "notify"     => SagaOp::Notify,
            _            => SagaOp::NoOp,
        }
    }
}

/// Un paso individual dentro de una saga.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SagaStep {
    pub name: String,
    pub op: SagaOp,
    pub action_ref: String,
    pub compensate_ref: Option<String>,
    pub timeout_ms: u64,
    pub max_retries: u32,
    pub depends_on: Vec<String>,
    pub preconditions: Vec<StepCondition>,
    pub postconditions: Vec<StepCondition>,
}

/// Condición de validación para pre/post condiciones.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepCondition {
    pub field: String,
    pub op: ConditionOp,
    pub value: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ConditionOp {
    Exists, NotExists, Eq, Ne, Gt, Gte, Lt, Lte, In, NotIn, Matches,
}

/// Resultado detallado de un paso ejecutado (para auditoría).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepDetail {
    pub step_name: String,
    pub op: SagaOp,
    pub status: StepStatus,
    pub expected: Value,
    pub actual: Value,
    pub duration_ms: u64,
    pub retry_count: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum StepStatus {
    Success,
    Failed { reason: String, recoverable: bool },
    Skipped { reason: String },
    Compensated,
    Timeout,
}
