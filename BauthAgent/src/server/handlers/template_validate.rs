// ============================================================
// bauth::server::handlers::template_validate — Motor de Validación
//
// Handler: bauth.role.template.validate
// Carga reglas desde cfg_validation_rule (248 reglas activas) y
// las aplica contra el template JSONB del rol.
//
// Las reglas son data-driven: target_table → sección del template,
// target_column → campo JSONB, min/max/allowed_values → validación.
// Cada regla referencia estándares de framework_raw.
//
// DOC-SBOS-001 N3 · cfg_validation_rule · framework_raw
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

pub struct TemplateValidateHandler { pub pg_pool: Option<sqlx::PgPool> }

// ─── Mapeo: domain → sección del template JSONB ──────────
// Agnostico de tabla. Usa el dominio declarado en la regla.
// Si domain=ALL → busca en TODAS las secciones.
fn domain_to_section(domain: &str) -> &str {
    match domain {
        "D1" => "logical_access",
        "D2" => "physical_access",
        "D3" => "financial_limits",
        "D4" => "temporal_schedule",
        "D5" => "biometric",
        "D6" => "geospatial",
        "D7" => "network",
        "D8" => "context",
        "D9" => "credentials",
        "D10" => "delegation",
        "D11" => "audit",
        "D12" => "blockchain",
        "SEC" | "COMP" => "compliance_security",
        "ALL" => "",  // cross-domain: buscar en todas las secciones
        _ => "",
    }
}

/// Secciones del template en orden canónico.
const ALL_SECTIONS: &[&str] = &[
    "role", "logical_access", "physical_access", "financial_limits",
    "temporal_schedule", "biometric", "geospatial", "network",
    "context", "credentials", "delegation", "audit",
    "blockchain", "compliance_security",
];

#[async_trait::async_trait]
impl JsonRpcHandler for TemplateValidateHandler {
    #[allow(clippy::collapsible_match)]
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let role_id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "id requerido (ej: ROL-ORG-CCO)".into(), data: None,
            })?;

        // ── 1. Cargar template ─────────────────────────────
        // idn_role_template no existe en DDL v2.12.0.
        // Tabla canónica: idn_roles_rol_hierarchical (rol registrado).
        // loa_required/mfa_required/step_up provienen de idn_roles_rol_tier (por tier).
        // El template a validar es metadata_b1 (JSONB del rol).
        #[derive(sqlx::FromRow)]
        struct Tpl {
            tier: String,
            status: String,
            loa_required: i32,
            mfa_required: bool,
            step_up_enabled: bool,
            max_sessions: Option<i32>,
            session_timeout: Option<i32>,
            template: serde_json::Value,
        }

        let tpl: Tpl = sqlx::query_as(
            "SELECT r.tier::text,
                    r.status::text,
                    t.loa_required,
                    (t.loa_required >= 2) AS mfa_required,
                    (t.step_up_loa IS NOT NULL) AS step_up_enabled,
                    NULL::integer AS max_sessions,
                    NULL::integer AS session_timeout,
                    r.metadata_b1 AS template
             FROM bauth.idn_roles_rol_hierarchical r
             JOIN bauth.idn_roles_rol_tier t ON t.tier::text = r.tier::text
             WHERE r.code = $1"
        ).bind(role_id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error: {}", e), data: None,
        })?.ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("rol no encontrado: {}", role_id), data: None,
        })?;

        // ── 2. Cargar reglas activas ───────────────────────
        #[derive(sqlx::FromRow)]
        struct Rule { rule_code: String, rule_name: String, domain: String,
            category: String, data_type: String, target_table: String,
            target_column: String, min_value: String, max_value: String,
            allowed_values: Option<Vec<String>>, required: bool,
            severity: String, error_message: Option<String>,
            standard_ref: Vec<String>, provenance_url: Option<String> }

        let rules: Vec<Rule> = sqlx::query_as(
            "SELECT rule_code, rule_name, domain, category, data_type,
                    target_table, target_column,
                    COALESCE(min_value::text, '0') as min_value,
                    COALESCE(max_value::text, '0') as max_value,
                    allowed_values, required, severity, error_message,
                    standard_ref, provenance_url
             FROM bauth.cfg_validation_rule WHERE is_active = TRUE
             ORDER BY domain, category, rule_code"
        ).fetch_all(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error cargando reglas: {}", e), data: None,
        })?;

        // ── 3. Aplicar reglas ──────────────────────────────
        let mut violations: Vec<Value> = Vec::new();
        let mut passed: i32 = 0;
        let mut failed: i32 = 0;
        let mut domains_checked: std::collections::HashSet<String> = std::collections::HashSet::new();

        for rule in &rules {
            domains_checked.insert(rule.domain.clone());

            // Mapeo domain → sección (agnóstico de tabla)
            let section_name = domain_to_section(&rule.domain);
            let field_val = if section_name.is_empty() {
                // ALL: buscar en TODAS las secciones
                ALL_SECTIONS.iter().find_map(|sec| {
                    tpl.template.get(*sec).and_then(|s| s.get(&rule.target_column))
                })
            } else {
                tpl.template.get(section_name).and_then(|s| s.get(&rule.target_column))
            };

            match rule.category.as_str() {
                "RANGE" => {
                    if let Some(val) = field_val.and_then(|v| v.as_i64()) {
                        let min: i64 = rule.min_value.parse().unwrap_or(i64::MIN);
                        let max: i64 = rule.max_value.parse().unwrap_or(i64::MAX);
                        if val < min || val > max {
                            failed += 1;
                            violations.push(serde_json::json!({
                                "rule_code": rule.rule_code, "rule_name": rule.rule_name,
                                "domain": rule.domain, "severity": rule.severity,
                                "field": format!("{}.{}", if section_name.is_empty() { "ALL" } else { section_name }, rule.target_column),
                                "current_value": val, "expected": format!("[{}, {}]", min, max),
                                "message": rule.error_message.as_deref().unwrap_or("valor fuera de rango"),
                                "standard_ref": rule.standard_ref.clone(),
                                "provenance_url": rule.provenance_url,
                            }));
                        } else { passed += 1; }
                    } else if rule.required {
                        failed += 1;
                        violations.push(serde_json::json!({
                            "rule_code": rule.rule_code, "rule_name": rule.rule_name,
                            "domain": rule.domain, "severity": rule.severity,
                            "field": format!("{}.{}", if section_name.is_empty() { "ALL" } else { section_name }, rule.target_column),
                            "current_value": null, "expected": "requerido",
                            "message": rule.error_message.as_deref().unwrap_or("campo requerido ausente"),
                            "standard_ref": rule.standard_ref.clone(),
                            "provenance_url": rule.provenance_url,
                        }));
                    } else { passed += 1; }
                }

                "ENUM" => {
                    if let Some(val) = field_val.and_then(|v| v.as_str()) {
                        let allowed: Vec<String> = rule.allowed_values.clone().unwrap_or_default();

                        if !allowed.is_empty() && !allowed.iter().any(|a| a == val) {
                            failed += 1;
                            violations.push(serde_json::json!({
                                "rule_code": rule.rule_code, "rule_name": rule.rule_name,
                                "domain": rule.domain, "severity": rule.severity,
                                "field": format!("{}.{}", if section_name.is_empty() { "ALL" } else { section_name }, rule.target_column),
                                "current_value": val, "expected": allowed,
                                "message": rule.error_message.as_deref().unwrap_or("valor no permitido"),
                                "standard_ref": rule.standard_ref.clone(),
                                "provenance_url": rule.provenance_url,
                            }));
                        } else { passed += 1; }
                    } else if rule.required {
                        failed += 1;
                        violations.push(serde_json::json!({
                            "rule_code": rule.rule_code, "rule_name": rule.rule_name,
                            "domain": rule.domain, "severity": rule.severity,
                            "field": format!("{}.{}", if section_name.is_empty() { "ALL" } else { section_name }, rule.target_column),
                            "current_value": null, "expected": "requerido (ENUM)",
                            "message": rule.error_message.as_deref().unwrap_or("campo requerido ausente"),
                            "standard_ref": rule.standard_ref.clone(),
                            "provenance_url": rule.provenance_url,
                        }));
                    } else { passed += 1; }
                }

                "TYPE" => {
                    if rule.required && field_val.is_none() {
                        failed += 1;
                        violations.push(serde_json::json!({
                            "rule_code": rule.rule_code, "rule_name": rule.rule_name,
                            "domain": rule.domain, "severity": rule.severity,
                            "field": format!("{}.{}", if section_name.is_empty() { "ALL" } else { section_name }, rule.target_column),
                            "current_value": null, "expected": format!("{} (tipo: {})", "requerido", rule.data_type),
                            "message": rule.error_message.as_deref().unwrap_or("campo obligatorio ausente"),
                            "standard_ref": rule.standard_ref.clone(),
                            "provenance_url": rule.provenance_url,
                        }));
                    } else { passed += 1; }
                }

                _ => { passed += 1; }
            }
        }

        // ── 4. Estándares referenciados ────────────────────
        let mut standards: Vec<String> = rules.iter()
            .flat_map(|r| r.standard_ref.clone())
            .collect();
        standards.sort();
        standards.dedup();

        // ── 5. Resumen ─────────────────────────────────────
        let errors = violations.iter().filter(|v| v["severity"] == "error").count();
        let warnings = violations.iter().filter(|v| v["severity"] == "warning").count();
        let infos = violations.iter().filter(|v| v["severity"] == "info").count();

        Ok(serde_json::json!({
            "template_id": role_id,
            "tier": tpl.tier,
            "loa_required": tpl.loa_required,
            "validated_at": chrono::Utc::now().to_rfc3339(),
            "rules_loaded": rules.len(),
            "checks_passed": passed,
            "checks_failed": failed,
            "violations": violations,
            "violations_count": violations.len(),
            "by_severity": { "error": errors, "warning": warnings, "info": infos },
            "domains_checked": domains_checked.len(),
            "standards_referenced": standards,
            "veredicto": if violations.is_empty() {
                "✅ Template cumple todas las reglas de cfg_validation_rule".to_string()
            } else if errors > 0 {
                format!("❌ {} errores — el template NO es conforme", errors)
            } else {
                format!("⚠️ {} avisos — revisar antes de producción", violations.len())
            }
        }))
    }
}
