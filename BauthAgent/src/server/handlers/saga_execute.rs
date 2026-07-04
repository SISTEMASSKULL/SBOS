// ============================================================
// bauth::server::handlers::saga_execute — B35 Handler
//
// Ejecuta sagas de autenticación con ActionRegistry real.
// Pipeline: cargar definición → crear contexto → ejecutar pasos → retornar resultado.
//
// DOC-SBOS-001 N3 · B35 · ALT-001 FIX
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct SagaExecuteHandler {
    pub pg_pool: Option<sqlx::PgPool>,
    pub registry: Option<Arc<crate::saga::registry::ActionRegistry>>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for SagaExecuteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let saga_name = params.get("saga").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "campo 'saga' requerido".into(), data: None,
            })?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .unwrap_or("saga-anon");

        let saga_params = params.get("params").cloned().unwrap_or(Value::Null);

        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        // ── Cargar definición de saga ─────────────────────────
        let steps = crate::db::load_saga_steps(pg, saga_name).await
            .map_err(|e| JsonRpcError {
                code: -32000, message: format!("error cargando saga: {}", e), data: None,
            })?;

        // ── Si no hay pasos pero hay registry, intentar ejecutar acción directa ──
        if steps.is_empty() {
            if let Some(ref registry) = self.registry {
                let state = std::collections::HashMap::new();
                let ctx_val = crate::saga::action::SagaEvalContext {
                    saga_name: saga_name.to_string(),
                    saga_id: uuid::Uuid::new_v4().to_string(),
                    ctx_id: ctx_id.to_string(),
                    params: saga_params.clone(),
                    state: state.clone(),
                    started_at: chrono::Utc::now(),
                    registry: Some(registry.clone()),
                };

                match registry.execute(saga_name, &ctx_val, Some(pg)).await {
                    Ok(result) => return Ok(serde_json::json!({
                        "status": "completed",
                        "saga": saga_name,
                        "ctx_id": ctx_id,
                        "result": result,
                        "message": "Acción ejecutada directamente vía ActionRegistry."
                    })),
                    Err(e) => return Ok(serde_json::json!({
                        "status": "failed",
                        "saga": saga_name,
                        "ctx_id": ctx_id,
                        "error": e,
                        "message": "Acción falló en ActionRegistry."
                    })),
                }
            }

            // Sin registry y sin pasos → simulado
            return Ok(serde_json::json!({
                "status": "not_found",
                "saga": saga_name,
                "ctx_id": ctx_id,
                "message": format!("saga '{}' no encontrada y ActionRegistry no disponible", saga_name),
            }));
        }

        // ── Construir contexto de saga ───────────────────────
        let mut ctx = crate::saga::action::SagaEvalContext {
            saga_name: saga_name.to_string(),
            saga_id: uuid::Uuid::new_v4().to_string(),
            ctx_id: ctx_id.to_string(),
            params: saga_params,
            state: std::collections::HashMap::new(),
            started_at: chrono::Utc::now(),
            registry: self.registry.clone(),
        };

        // ── Ejecutar saga completa ───────────────────────────
        let mut step_details: Vec<Value> = Vec::new();
        let mut final_status = "completed";

        for step_row in &steps {
            let step = crate::saga::step::SagaStep {
                name: step_row.step_name.clone(),
                op: match step_row.saga_op.as_str() {
                    "execute" => crate::saga::step::SagaOp::Execute,
                    "validate" => crate::saga::step::SagaOp::Validate,
                    "compensate" => crate::saga::step::SagaOp::Compensate,
                    _ => crate::saga::step::SagaOp::Execute,
                },
                action_ref: step_row.action_ref.clone(),
                compensate_ref: step_row.compensate_ref.clone(),
                timeout_ms: step_row.timeout_ms as u64,
                max_retries: step_row.max_retries as u32,
                depends_on: step_row.depends_on.clone().unwrap_or_default(),
                preconditions: Vec::new(),
                postconditions: Vec::new(),
            };

            let detail = crate::saga::executor::exec_step(&step, &mut ctx).await;
            step_details.push(serde_json::json!({
                "step": detail.step_name,
                "status": format!("{:?}", detail.status),
                "duration_ms": detail.duration_ms,
                "retries": detail.retry_count,
            }));

            let failed = matches!(detail.status, crate::saga::step::StepStatus::Failed { .. });
            if failed {
                final_status = "failed";
                break;
            }
        }

        Ok(serde_json::json!({
            "status": final_status,
            "saga": saga_name,
            "ctx_id": ctx_id,
            "steps_executed": step_details.len(),
            "step_details": step_details,
            "message": if final_status == "completed" {
                "Saga completada exitosamente vía ActionRegistry."
            } else {
                "Saga falló — revisar step_details."
            },
        }))
    }
}
