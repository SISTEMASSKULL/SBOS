// ============================================================
// bauth::saga::catalog — Carga de sagas desde BD (H-10)
//
// Convierte SagaCatalogRow + SagaStepRow → SagaAction.
// Valida cada saga cargada; las inválidas se omiten con warning.
// ============================================================
#![allow(dead_code)]
use super::action::{SagaAction, SequenceOp, CompensationStrategy};
use super::step::{SagaStep, SagaOp};
use super::validator::validate_saga;
use crate::db;
use sqlx::PgPool;
use tracing::{info, warn};

/// Carga todas las sagas activas desde la BD y las valida.
pub async fn load_all_sagas(pg: &PgPool) -> Vec<SagaAction> {
    let catalog_rows = match db::load_saga_catalog(pg).await {
        Ok(rows) => rows,
        Err(e) => {
            warn!(error = %e, "no se pudieron cargar sagas desde BD");
            return vec![];
        }
    };

    let mut actions = vec![];
    for row in &catalog_rows {
        let step_rows = match db::load_saga_steps(pg, &row.saga_name).await {
            Ok(steps) => steps,
            Err(e) => {
                warn!(saga = %row.saga_name, error = %e, "pasos no cargados");
                continue;
            }
        };

        if step_rows.is_empty() {
            warn!(saga = %row.saga_name, "saga sin pasos — omitiendo");
            continue;
        }

        let steps: Vec<SagaStep> = step_rows.iter().map(|s| SagaStep {
            name: s.step_name.clone(),
            op: SagaOp::from_str(&s.saga_op),
            action_ref: s.action_ref.clone(),
            compensate_ref: s.compensate_ref.clone(),
            timeout_ms: s.timeout_ms as u64,
            max_retries: s.max_retries as u32,
            depends_on: s.depends_on.clone().unwrap_or_default(),
            preconditions: vec![],
            postconditions: vec![],
        }).collect();

        let action = SagaAction {
            name: row.saga_name.clone(),
            version: row.version.clone(),
            description: row.description.clone(),
            sequence: SequenceOp::Sequential,
            steps,
            max_total_timeout_ms: row.max_timeout_ms as u64,
            compensation_strategy: CompensationStrategy::from_str(&row.compensation),
        };

        match validate_saga(&action) {
            Ok(()) => {
                info!(saga = %action.name, pasos = action.steps.len(), "saga validada");
                actions.push(action);
            }
            Err(errors) => {
                for e in errors {
                    warn!(saga = %action.name, field = %e.field, error = %e.message, "saga inválida — omitiendo");
                }
            }
        }
    }

    info!(total = actions.len(), cargadas = catalog_rows.len(), "catálogo de sagas validado");
    actions
}
