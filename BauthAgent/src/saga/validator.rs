// ============================================================
// bauth::saga::validator — Validación estructural de sagas (H-10)
//
// 7 reglas de validación. Detección de ciclos DFS.
// Se ejecuta al cargar sagas desde BD y en bauth.saga.validate.
// ============================================================
#![allow(dead_code)]
use super::action::SagaAction;
use super::step::SagaOp;
use std::collections::{HashMap, HashSet};

#[derive(Debug)]
pub struct ValidationError {
    pub field: String,
    pub message: String,
}

/// Valida una saga completa. Retorna Ok(()) o Vec de errores.
pub fn validate_saga(action: &SagaAction) -> Result<(), Vec<ValidationError>> {
    let mut errors = vec![];

    // R1: Al menos 1 paso
    if action.steps.is_empty() {
        errors.push(ValidationError {
            field: "steps".into(),
            message: "la saga debe tener al menos 1 paso".into(),
        });
    }

    // R2: Nombres de paso únicos
    let mut names = HashSet::new();
    for step in &action.steps {
        if !names.insert(&step.name) {
            errors.push(ValidationError {
                field: format!("steps.{}", step.name),
                message: "nombre de paso duplicado".into(),
            });
        }
    }

    // R3: Timeout total >= suma de timeouts individuales
    let total_step_timeout: u64 = action.steps.iter().map(|s| s.timeout_ms).sum();
    if action.max_total_timeout_ms < total_step_timeout {
        errors.push(ValidationError {
            field: "max_total_timeout_ms".into(),
            message: format!(
                "timeout total ({}ms) debe ser >= suma de timeouts de pasos ({}ms)",
                action.max_total_timeout_ms, total_step_timeout
            ),
        });
    }

    // R4: DAG sin ciclos
    if let Err(cycle) = validate_no_cycles(&action.steps) {
        errors.push(ValidationError {
            field: "steps.depends_on".into(),
            message: format!("ciclo detectado: {}", cycle),
        });
    }

    // R5: Dependencias solo a pasos existentes
    for step in &action.steps {
        for dep in &step.depends_on {
            if !names.contains(dep) {
                errors.push(ValidationError {
                    field: format!("steps.{}.depends_on", step.name),
                    message: format!("dependencia '{}' no existe en la saga", dep),
                });
            }
        }
    }

    // R6: Al menos un paso Execute
    let has_execute = action.steps.iter().any(|s| s.op == SagaOp::Execute);
    if !has_execute {
        errors.push(ValidationError {
            field: "steps".into(),
            message: "la saga debe tener al menos un paso Execute".into(),
        });
    }

    // R7: max_total_timeout_ms > 0
    if action.max_total_timeout_ms == 0 {
        errors.push(ValidationError {
            field: "max_total_timeout_ms".into(),
            message: "timeout total debe ser > 0".into(),
        });
    }

    if errors.is_empty() { Ok(()) } else { Err(errors) }
}

/// Detecta ciclos en el grafo de dependencias (DFS con colores: 0=blanco, 1=gris, 2=negro).
fn validate_no_cycles(steps: &[super::step::SagaStep]) -> Result<(), String> {
    let name_to_idx: HashMap<&str, usize> = steps.iter()
        .enumerate().map(|(i, s)| (s.name.as_str(), i)).collect();

    let mut adj: Vec<Vec<usize>> = vec![vec![]; steps.len()];
    for (i, step) in steps.iter().enumerate() {
        for dep in &step.depends_on {
            if let Some(&j) = name_to_idx.get(dep.as_str()) {
                adj[i].push(j);
            }
        }
    }

    let mut color = vec![0u8; steps.len()];
    for i in 0..steps.len() {
        if color[i] == 0 {
            if let Some(cycle) = dfs_cycle(i, &adj, &mut color, steps) {
                return Err(cycle);
            }
        }
    }
    Ok(())
}

fn dfs_cycle(u: usize, adj: &[Vec<usize>], color: &mut [u8], steps: &[super::step::SagaStep]) -> Option<String> {
    color[u] = 1;
    for &v in &adj[u] {
        if color[v] == 1 {
            return Some(format!("{} -> {}", steps[u].name, steps[v].name));
        }
        if color[v] == 0 {
            if let Some(cycle) = dfs_cycle(v, adj, color, steps) {
                return Some(cycle);
            }
        }
    }
    color[u] = 2;
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::step::*;
    use super::super::action::*;

    fn make_step(name: &str, op: SagaOp, deps: Vec<&str>) -> SagaStep {
        SagaStep {
            name: name.into(), op, action_ref: format!("act.{}", name),
            compensate_ref: None, timeout_ms: 1000, max_retries: 0,
            depends_on: deps.into_iter().map(|s| s.into()).collect(),
            preconditions: vec![], postconditions: vec![],
        }
    }

    fn make_action(steps: Vec<SagaStep>) -> SagaAction {
        SagaAction {
            name: "test".into(), version: "1.0.0".into(), description: "test".into(),
            sequence: SequenceOp::Sequential, steps,
            max_total_timeout_ms: 10000,
            compensation_strategy: CompensationStrategy::FullRollback,
        }
    }

    #[test]
    fn test_empty_rejected() {
        assert!(validate_saga(&make_action(vec![])).is_err());
    }

    #[test]
    fn test_duplicate_names_rejected() {
        let s = make_step("p1", SagaOp::Execute, vec![]);
        assert!(validate_saga(&make_action(vec![s.clone(), s])).is_err());
    }

    #[test]
    fn test_cycle_detected() {
        let steps = vec![
            make_step("p1", SagaOp::Execute, vec!["p2"]),
            make_step("p2", SagaOp::Execute, vec!["p1"]),
        ];
        let errs = validate_saga(&make_action(steps)).unwrap_err();
        assert!(errs.iter().any(|e| e.message.contains("ciclo")));
    }

    #[test]
    fn test_broken_dependency() {
        let steps = vec![make_step("p1", SagaOp::Execute, vec!["no_existe"])];
        let errs = validate_saga(&make_action(steps)).unwrap_err();
        assert!(errs.iter().any(|e| e.message.contains("no_existe")));
    }

    #[test]
    fn test_no_execute_rejected() {
        let steps = vec![make_step("p1", SagaOp::Validate, vec![])];
        assert!(validate_saga(&make_action(steps)).is_err());
    }

    #[test]
    fn test_valid_saga_passes() {
        let steps = vec![
            make_step("p1", SagaOp::Execute, vec![]),
            make_step("p2", SagaOp::Validate, vec!["p1"]),
        ];
        assert!(validate_saga(&make_action(steps)).is_ok());
    }
}
