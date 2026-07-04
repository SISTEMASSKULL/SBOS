// ============================================================
// bauth::domain::policy::parser — Carga de políticas desde JSON/JSONB
//
// parse_policy_data(): convierte JSONB (bos_atom_policy.policy_data) → PolicyData.
// from_policy_data(): convierte PolicyData → PolicyRule evaluable.
// load_from_json(): carga reglas desde JSON (compatibilidad con framework v4).
// ============================================================

#![allow(dead_code)]
use super::condition::{CompareOp, PolicyCondition};
use super::resolver::resolve_conditions;
use super::rule::{EvaluateBlock, LogicOp, PolicyData, PolicyRule};
use std::collections::HashMap;

/// Valida que un policy_data JSONB cumple el schema canónico bos_policy_v1.
/// Rechaza documentos mal formados con mensaje descriptivo en español.
pub fn validate_policy_schema(json: &serde_json::Value) -> Result<(), String> {
    let required = ["$schema", "priority", "action", "evaluate", "params"];
    for field in &required {
        if json.as_object().and_then(|o| o.get(*field)).is_none() {
            return Err(format!("campo requerido ausente: '{}'", field));
        }
    }
    let action = json.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if !["deny","allow","step_up","pending_approval","mfa_required"].contains(&action) {
        return Err(format!("acción inválida: '{}'", action));
    }
    let priority = json.get("priority").and_then(|v| v.as_i64()).unwrap_or(0);
    if !(1..=999).contains(&priority) {
        return Err(format!("priority fuera de rango [1,999]: {}", priority));
    }
    let evaluate = json.get("evaluate").ok_or("falta bloque 'evaluate'")?;
    if evaluate.get("conditions").and_then(|v| v.as_array()).is_none() {
        return Err("evaluate.conditions debe ser un array".into());
    }
    Ok(())
}

/// Parsea un `serde_json::Value` que representa el JSONB `policy_data`.
pub fn parse_policy_data(json: &serde_json::Value) -> Result<PolicyData, String> {
    validate_policy_schema(json)?;
    let schema = json.get("$schema").and_then(|v| v.as_str()).unwrap_or("bos_policy_v1").to_string();
    let priority = json.get("priority").and_then(|v| v.as_i64()).unwrap_or(50) as i32;
    let action = json.get("action").and_then(|v| v.as_str()).unwrap_or("deny").to_string();
    let message = json.get("message").and_then(|v| v.as_str()).unwrap_or("").to_string();

    let evaluate = json.get("evaluate").ok_or("falta bloque 'evaluate' en policy_data")?;
    let logic_str = evaluate.get("logic").and_then(|v| v.as_str()).unwrap_or("and");
    let logic = match logic_str.to_lowercase().as_str() {
        "or" => LogicOp::Or,
        _ => LogicOp::And,
    };

    let conditions_arr = evaluate
        .get("conditions")
        .and_then(|v| v.as_array())
        .ok_or("falta 'evaluate.conditions' en policy_data")?;

    let mut conditions = Vec::new();
    for c in conditions_arr {
        let field = c.get("field").and_then(|v| v.as_str())
            .ok_or("condición sin 'field'")?.to_string();
        let op_str = c.get("op").and_then(|v| v.as_str()).unwrap_or("eq");
        let value = c.get("value").cloned().unwrap_or(serde_json::Value::Null);
        let op = CompareOp::from_str(op_str).map_err(|e| format!("condición '{}': {}", field, e))?;
        conditions.push(PolicyCondition { field, op, raw_value: value });
    }

    let params: HashMap<String, serde_json::Value> = json
        .get("params")
        .and_then(|v| v.as_object())
        .map(|obj| obj.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
        .unwrap_or_default();

    Ok(PolicyData { schema, priority, action, message, evaluate: EvaluateBlock { logic, conditions }, params })
}

/// Convierte un documento `policy_data` en un `PolicyRule` evaluable.
/// Resuelve todas las referencias ${params.*} en las condiciones.
pub fn from_policy_data(pd: &PolicyData) -> PolicyRule {
    let resolved = resolve_conditions(&pd.evaluate.conditions, &pd.params);
    PolicyRule {
        slug: String::new(),
        description: pd.message.clone(),
        domain: 0,
        priority: pd.priority,
        conditions: resolved,
        logic: pd.evaluate.logic.clone(),
        action: pd.action.clone(),
        message: pd.message.clone(),
    }
}

/// Carga reglas desde un JSON (formato Policies_Authentication_Framework_v4.json).
/// Recorre recursivamente buscando objetos con policy_slug + conditions.
pub fn load_from_json(json: &serde_json::Value) -> Vec<PolicyRule> {
    let mut rules = Vec::new();
    if let Some(obj) = json.as_object() {
        for (_k, v) in obj {
            extract_rules(v, &mut rules, 0);
        }
    }
    rules
}

/// Detecta conflictos entre políticas: misma prioridad, acciones contradictorias.
/// Retorna lista de conflictos encontrados (vacío = sin conflictos).
pub fn detect_conflicts(rules: &[PolicyRule]) -> Vec<String> {
    let mut conflicts = Vec::new();
    for i in 0..rules.len() {
        for j in i+1..rules.len() {
            let a = &rules[i]; let b = &rules[j];
            // Misma prioridad + acción contradictoria → conflicto
            if a.priority == b.priority && a.action != b.action {
                conflicts.push(format!(
                    "Conflicto: '{}' (p{}, {}) vs '{}' (p{}, {}) — misma prioridad, acciones opuestas",
                    a.slug, a.priority, a.action, b.slug, b.priority, b.action
                ));
            }
            // deny + allow sobre mismo dominio → deny prevalece (pero es warning)
            if a.action == "deny" && b.action == "allow" && a.domain == b.domain {
                conflicts.push(format!(
                    "Advertencia: '{}' (deny) anula '{}' (allow) en dominio {}",
                    a.slug, b.slug, a.domain
                ));
            }
        }
    }
    conflicts
}

fn extract_rules(val: &serde_json::Value, rules: &mut Vec<PolicyRule>, depth: u32) {
    if depth > 6 { return; }
    match val {
        serde_json::Value::Object(obj) => {
            if let (Some(slug), Some(conditions)) = (
                obj.get("policy_slug").and_then(|v| v.as_str()),
                obj.get("conditions").and_then(|v| v.as_array()),
            ) {
                let mut parsed = Vec::new();
                for c in conditions {
                    if let (Some(field), Some(op_str), Some(value)) = (
                        c.get("field").and_then(|v| v.as_str()),
                        c.get("operator").and_then(|v| v.as_str()),
                        c.get("value"),
                    ) {
                        let op = match CompareOp::from_str(op_str) {
                            Ok(o) => o,
                            Err(e) => { tracing::warn!(error = %e, "condición omitida"); continue; }
                        };
                        parsed.push(PolicyCondition {
                            field: field.to_string(),
                            op,
                            raw_value: value.clone(),
                        });
                    }
                }
                if !parsed.is_empty() {
                    let params: HashMap<String, serde_json::Value> = obj
                        .get("params").and_then(|v| v.as_object())
                        .map(|o| o.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
                        .unwrap_or_default();
                    let resolved = parsed.iter().map(|c| PolicyCondition {
                        field: c.field.clone(), op: c.op.clone(),
                        raw_value: super::resolver::resolve_value(&c.raw_value, &params),
                    }).collect();
                    let logic = match obj.get("logic").and_then(|v| v.as_str()).unwrap_or("and") {
                        "or" | "OR" => LogicOp::Or,
                        _ => LogicOp::And,
                    };
                    rules.push(PolicyRule {
                        slug: slug.to_string(),
                        description: obj.get("description").and_then(|v| v.as_str()).unwrap_or("").into(),
                        domain: obj.get("domain").and_then(|v| v.as_u64()).unwrap_or(1) as u8,
                        priority: obj.get("priority").and_then(|v| v.as_i64()).unwrap_or(50) as i32,
                        conditions: resolved, logic,
                        action: obj.get("action").and_then(|v| v.as_str()).unwrap_or("allow").into(),
                        message: obj.get("message").and_then(|v| v.as_str()).unwrap_or("").into(),
                    });
                }
            }
            for (_k, v) in obj { extract_rules(v, rules, depth + 1); }
        }
        serde_json::Value::Array(arr) => {
            for v in arr { extract_rules(v, rules, depth + 1); }
        }
        _ => {}
    }
}
