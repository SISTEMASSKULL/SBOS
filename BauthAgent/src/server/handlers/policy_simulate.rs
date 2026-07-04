// ============================================================
// bauth::server::handlers::policy_simulate — B9.T27 PolicySimulator
//
// bauth.policy.simulate — dry-run XACML 3.0 Policy Testing:
//   "¿Qué pasaría si aplico este cambio de política?"
//
// Flujo:
//   1. Cargar políticas activas del dominio (baseline)
//   2. Evaluar contexto contra baseline
//   3. Aplicar cambios propuestos EN MEMORIA (sin tocar BD)
//   4. Evaluar mismo contexto contra políticas modificadas
//   5. Comparar resultados → delta (qué cambió, qué usuarios afectados)
//
// Params:
//   domain:    1-12
//   context:   mapa de valores runtime (igual que domain.evaluate)
//   proposed:  { add: [configs], remove: [policy_codes], modify: [{code, config}] }
//
// Response:
//   baseline:    resultado con políticas actuales
//   simulated:   resultado con políticas modificadas
//   delta:       [{ policy, baseline_state, simulated_state, impacto }]
//   resumen:     { unchanged, changed, new_policies, removed_policies }
// ============================================================

#![allow(dead_code)]
use crate::domain::policy::{ath_converter, ath_loader, evaluate};
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::collections::HashMap;

pub struct PolicySimulateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicySimulateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })?
            as u8;

        let ctx: HashMap<String, Value> = params.get("context")
            .and_then(|v| v.as_object())
            .map(|o| o.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
            .unwrap_or_default();

        let proposed = params.get("proposed").cloned()
            .unwrap_or(serde_json::json!({}));

        // ── 1. Cargar políticas activas actuales ──────────────
        let baseline_rules = ath_loader::load_domain(pg, domain).await;

        // ── 2. Evaluar baseline ──────────────────────────────
        let baseline_result = if baseline_rules.is_empty() {
            vec![]
        } else {
            let (_, _, results) = evaluate::evaluate(&baseline_rules, &ctx);
            results.iter().map(|r| serde_json::json!({
                "policy": r.slug,
                "state": format!("{:?}", r.state),
                "conditions_met": r.conditions_met,
                "message": r.message,
            })).collect()
        };

        // ── 3. Aplicar cambios propuestos en memoria ──────────
        let mut modified_rules = baseline_rules.clone();

        // remove
        if let Some(remove_list) = proposed.get("remove").and_then(|v| v.as_array()) {
            let codes_to_remove: Vec<&str> = remove_list.iter()
                .filter_map(|v| v.as_str()).collect();
            modified_rules.retain(|r| !codes_to_remove.contains(&r.slug.as_str()));
        }

        // modify
        if let Some(modify_list) = proposed.get("modify").and_then(|v| v.as_array()) {
            for mod_entry in modify_list {
                let code = mod_entry.get("policy_code").and_then(|v| v.as_str());
                let new_config = mod_entry.get("config");
                if let (Some(code), Some(config)) = (code, new_config) {
                    // Reemplazar política existente
                    modified_rules.retain(|r| r.slug != code);
                    let priority = config.get("priority").and_then(|v| v.as_i64()).unwrap_or(50) as i32;
                    if let Some(new_rule) = ath_converter::convert(
                        code, code, config, priority, domain,
                    ) {
                        modified_rules.push(new_rule);
                    }
                }
            }
        }

        // add
        let mut added_count = 0;
        if let Some(add_list) = proposed.get("add").and_then(|v| v.as_array()) {
            for (i, config) in add_list.iter().enumerate() {
                let code = config.get("policy_code").and_then(|v| v.as_str())
                    .unwrap_or("__simulated__");
                let name = config.get("policy_name").and_then(|v| v.as_str())
                    .unwrap_or(code);
                let priority = config.get("priority").and_then(|v| v.as_i64()).unwrap_or(50) as i32;
                if let Some(new_rule) = ath_converter::convert(
                    code, name, config, priority + i as i32, domain,
                ) {
                    modified_rules.push(new_rule);
                    added_count += 1;
                }
            }
        }

        // ── 4. Evaluar simulación ────────────────────────────
        let simulated_result = if modified_rules.is_empty() {
            vec![]
        } else {
            let (_, _, results) = evaluate::evaluate(&modified_rules, &ctx);
            results.iter().map(|r| serde_json::json!({
                "policy": r.slug,
                "state": format!("{:?}", r.state),
                "conditions_met": r.conditions_met,
                "message": r.message,
            })).collect()
        };

        // ── 5. Calcular delta ────────────────────────────────
        let baseline_map: HashMap<&str, &str> = baseline_result.iter()
            .filter_map(|v| Some((v.get("policy")?.as_str()?, v.get("state")?.as_str()?)))
            .collect();
        let simulated_map: HashMap<&str, &str> = simulated_result.iter()
            .filter_map(|v| Some((v.get("policy")?.as_str()?, v.get("state")?.as_str()?)))
            .collect();

        let mut delta = Vec::new();
        let mut all_keys: Vec<&str> = baseline_map.keys().copied()
            .chain(simulated_map.keys().copied())
            .collect();
        all_keys.sort();
        all_keys.dedup();

        for policy in &all_keys {
            let before = baseline_map.get(policy).copied().unwrap_or("no_existe");
            let after  = simulated_map.get(policy).copied().unwrap_or("eliminada");
            if before != after {
                delta.push(serde_json::json!({
                    "policy": policy,
                    "baseline_state": before,
                    "simulated_state": after,
                    "impacto": classify_impact(before, after),
                }));
            }
        }

        let unchanged = all_keys.len() - delta.len();

        Ok(serde_json::json!({
            "domain": domain,
            "baseline": {
                "policies_evaluated": baseline_result.len(),
                "results": baseline_result,
            },
            "simulated": {
                "policies_evaluated": simulated_result.len(),
                "policies_added": added_count,
                "policies_removed": baseline_result.len() as i64 - modified_rules.len() as i64 + added_count as i64,
                "results": simulated_result,
            },
            "delta": delta,
            "resumen": {
                "total_policies": all_keys.len(),
                "unchanged": unchanged,
                "changed": delta.len(),
                "bloqueante": delta.iter().any(|d| d["impacto"] == "DENEGACION_NUEVA"),
            },
        }))
    }
}

/// Clasifica el impacto de un cambio de estado entre baseline y simulado.
fn classify_impact(before: &str, after: &str) -> &'static str {
    match (before, after) {
        ("Aprobado", "Rechazado") => "DENEGACION_NUEVA",
        ("Aprobado", "Pendiente") => "APROBACION_ADICIONAL",
        ("Rechazado", "Aprobado") => "PERMISO_NUEVO",
        ("Rechazado", "Pendiente") => "APROBACION_ADICIONAL",
        ("Pendiente", "Aprobado") => "APROBACION_CONCEDIDA",
        ("Pendiente", "Rechazado") => "DENEGACION_NUEVA",
        (_, "eliminada") => "POLITICA_ELIMINADA",
        ("no_existe", _) => "POLITICA_NUEVA",
        _ => "SIN_CAMBIO",
    }
}
