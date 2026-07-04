// ============================================================
// bauth::domain::rule_engine — Motor de Validación de Valores
//
// Carga cfg_validation_rule desde BD y evalúa valores configurados
// contra las reglas definidas. Las reglas son DATOS, no código.
// Cada regla tiene trazabilidad a su estándar de origen.
//
// Categorías de validación:
//   TYPE     — ¿El tipo de dato coincide?
//   RANGE    — ¿El valor está dentro del rango [min, max]?
//   ENUM     — ¿El valor está en la lista de valores permitidos?
//   SEMANTIC — ¿El valor cumple su propósito de negocio?
// ============================================================

#![allow(dead_code)]
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

/// Una regla de validación cargada desde cfg_validation_rule.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ValidationRule {
    pub rule_id: uuid::Uuid,
    pub rule_code: String,
    pub rule_name: String,
    pub description: String,
    pub target_table: String,
    pub target_column: String,
    pub domain: String,
    pub category: String,
    pub data_type: String,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub allowed_values: Option<Vec<String>>,
    pub regex_pattern: Option<String>,
    pub required: bool,
    pub error_message: String,
    pub error_code: String,
    pub standard_ref: Option<Vec<String>>,
    pub standard_section: Option<String>,
    pub severity: String,
}

/// Resultado de una validación individual.
#[derive(Debug, Clone, Serialize)]
pub struct ValidationResult {
    pub rule_code: String,
    pub passed: bool,
    pub actual_value: serde_json::Value,
    pub expected: String,
    pub error_code: String,
    pub error_message: String,
    pub severity: String,
    pub standard_ref: Option<Vec<String>>,
}

/// Informe completo de validación.
#[derive(Debug, Clone, Serialize)]
pub struct ValidationReport {
    pub total_rules: usize,
    pub passed: usize,
    pub failed: usize,
    pub errors: Vec<ValidationResult>,
    pub warnings: Vec<ValidationResult>,
}

/// El RuleEngine: carga reglas, evalúa valores, produce informes.
pub struct RuleEngine {
    rules: Vec<ValidationRule>,
}

impl RuleEngine {
    /// Carga todas las reglas activas desde la base de datos.
    pub async fn load(pg: &PgPool) -> Result<Self, String> {
        let rules: Vec<ValidationRule> = sqlx::query_as(
            "SELECT rule_id, rule_code, rule_name, description,
                    target_table, target_column, domain, category,
                    data_type, min_value, max_value, allowed_values,
                    regex_pattern, required, error_message, error_code,
                    standard_ref, standard_section, severity
             FROM bauth.cfg_validation_rule
             WHERE is_active = true
             ORDER BY domain, rule_code"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| format!("Error cargando reglas de validación: {}", e))?;

        tracing::info!(reglas = rules.len(), "RuleEngine: reglas de validación cargadas");
        Ok(RuleEngine { rules })
    }

    /// Evalúa un valor contra TODAS las reglas que aplican a esa tabla/columna.
    pub fn validate(
        &self,
        table: &str,
        column: &str,
        value: &serde_json::Value,
    ) -> Vec<ValidationResult> {
        let mut results = Vec::new();

        for rule in &self.rules {
            if rule.target_table != table || rule.target_column != column {
                continue;
            }

            let result = match rule.category.as_str() {
                "TYPE" => Self::validate_type(rule, value),
                "RANGE" => Self::validate_range(rule, value),
                "ENUM" => Self::validate_enum(rule, value),
                "SEMANTIC" => Self::validate_semantic(rule, value),
                _ => ValidationResult {
                    rule_code: rule.rule_code.clone(),
                    passed: true,
                    actual_value: value.clone(),
                    expected: "categoría desconocida, se omite validación".into(),
                    error_code: rule.error_code.clone(),
                    error_message: rule.error_message.clone(),
                    severity: "info".into(),
                    standard_ref: rule.standard_ref.clone(),
                },
            };
            results.push(result);
        }

        results
    }

    /// Evalúa todos los valores de una fila de configuración.
    pub fn validate_row(
        &self,
        table: &str,
        row: &std::collections::HashMap<String, serde_json::Value>,
    ) -> ValidationReport {
        let mut errors = Vec::new();
        let mut warnings = Vec::new();
        let mut total = 0usize;
        let mut passed = 0usize;

        for rule in &self.rules {
            if rule.target_table != table {
                continue;
            }
            total += 1;

            let value = row.get(&rule.target_column).cloned().unwrap_or(serde_json::Value::Null);
            let result = match rule.category.as_str() {
                "TYPE" => Self::validate_type(rule, &value),
                "RANGE" => Self::validate_range(rule, &value),
                "ENUM" => Self::validate_enum(rule, &value),
                "SEMANTIC" => Self::validate_semantic(rule, &value),
                _ => ValidationResult {
                    rule_code: rule.rule_code.clone(),
                    passed: true,
                    actual_value: value,
                    expected: "skip".into(),
                    error_code: rule.error_code.clone(),
                    error_message: rule.error_message.clone(),
                    severity: "info".into(),
                    standard_ref: rule.standard_ref.clone(),
                },
            };

            if result.passed {
                passed += 1;
            } else if result.severity == "error" {
                errors.push(result);
            } else {
                warnings.push(result);
            }
        }

        ValidationReport {
            total_rules: total,
            passed,
            failed: errors.len() + warnings.len(),
            errors,
            warnings,
        }
    }

    // ─── Validadores por categoría ──────────────────────────

    fn validate_type(rule: &ValidationRule, value: &serde_json::Value) -> ValidationResult {
        let type_ok = match rule.data_type.as_str() {
            "integer" => value.is_number() && value.as_f64().map(|n| n.fract() == 0.0).unwrap_or(false),
            "numeric" => value.is_number(),
            "text" => value.is_string(),
            "boolean" => value.is_boolean(),
            "jsonb" => value.is_object() || value.is_array(),
            "uuid" => value.as_str().map(|s| uuid::Uuid::parse_str(s).is_ok()).unwrap_or(false),
            _ => true,
        };

        ValidationResult {
            rule_code: rule.rule_code.clone(),
            passed: type_ok,
            actual_value: value.clone(),
            expected: format!("tipo: {}", rule.data_type),
            error_code: rule.error_code.clone(),
            error_message: if type_ok { String::new() } else { rule.error_message.clone() },
            severity: rule.severity.clone(),
            standard_ref: rule.standard_ref.clone(),
        }
    }

    fn validate_range(rule: &ValidationRule, value: &serde_json::Value) -> ValidationResult {
        let num = match value.as_f64() {
            Some(n) => n,
            None => {
                // Si el valor no es numérico pero la regla espera un número
                return ValidationResult {
                    rule_code: rule.rule_code.clone(),
                    passed: false,
                    actual_value: value.clone(),
                    expected: format!("número entre {:?} y {:?}",
                        rule.min_value, rule.max_value),
                    error_code: rule.error_code.clone(),
                    error_message: format!("{}: se esperaba un número, se recibió {:?}",
                        rule.error_message, value),
                    severity: rule.severity.clone(),
                    standard_ref: rule.standard_ref.clone(),
                };
            }
        };

        let min_ok = rule.min_value.map(|min| num >= min).unwrap_or(true);
        let max_ok = rule.max_value.map(|max| num <= max).unwrap_or(true);

        let passed = min_ok && max_ok;

        ValidationResult {
            rule_code: rule.rule_code.clone(),
            passed,
            actual_value: serde_json::json!(num),
            expected: format!("rango: [{:?}, {:?}]",
                rule.min_value, rule.max_value),
            error_code: rule.error_code.clone(),
            error_message: if passed { String::new() } else { rule.error_message.clone() },
            severity: rule.severity.clone(),
            standard_ref: rule.standard_ref.clone(),
        }
    }

    fn validate_enum(rule: &ValidationRule, value: &serde_json::Value) -> ValidationResult {
        let allowed = rule.allowed_values.as_deref().unwrap_or(&[]);
        let val_str = match value {
            serde_json::Value::String(s) => s.clone(),
            other => other.to_string(),
        };

        let passed = allowed.iter().any(|a| a == &val_str);

        ValidationResult {
            rule_code: rule.rule_code.clone(),
            passed,
            actual_value: serde_json::json!(val_str),
            expected: format!("uno de: {:?}", allowed),
            error_code: rule.error_code.clone(),
            error_message: if passed { String::new() } else {
                format!("{}: '{}' no está en la lista de valores permitidos: {:?}",
                    rule.error_message, val_str, allowed)
            },
            severity: rule.severity.clone(),
            standard_ref: rule.standard_ref.clone(),
        }
    }

    fn validate_semantic(rule: &ValidationRule, value: &serde_json::Value) -> ValidationResult {
        // Reglas semánticas: validan significado, no solo tipo/rango
        // Ej: un session_ttl=28800 es válido para oficina pero no para break-glass (máx 4h)
        // La regla semántica se evalúa contra el contexto completo
        let val_str = match value {
            serde_json::Value::String(s) => s.clone(),
            serde_json::Value::Number(n) => n.to_string(),
            serde_json::Value::Bool(b) => b.to_string(),
            _ => value.to_string(),
        };

        // Por ahora, la validación semántica verifica el regex si está definido
        let regex_ok = if let Some(ref pattern) = rule.regex_pattern {
            regex::Regex::new(pattern)
                .map(|re| re.is_match(&val_str))
                .unwrap_or(true)
        } else {
            true
        };

        let required_ok = if rule.required {
            !val_str.is_empty() && val_str != "null"
        } else {
            true
        };

        let passed = regex_ok && required_ok;

        ValidationResult {
            rule_code: rule.rule_code.clone(),
            passed,
            actual_value: serde_json::json!(val_str),
            expected: format!("semántica: regex={}, required={}",
                rule.regex_pattern.as_deref().unwrap_or("none"),
                rule.required),
            error_code: rule.error_code.clone(),
            error_message: if passed { String::new() } else { rule.error_message.clone() },
            severity: rule.severity.clone(),
            standard_ref: rule.standard_ref.clone(),
        }
    }

    /// Retorna todas las reglas para un dominio específico.
    pub fn rules_for_domain(&self, domain: &str) -> Vec<&ValidationRule> {
        self.rules.iter().filter(|r| r.domain == domain || r.domain == "ALL").collect()
    }

    /// Cantidad de reglas cargadas.
    pub fn count(&self) -> usize {
        self.rules.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_rule(category: &str, data_type: &str, min: Option<f64>, max: Option<f64>, allowed: Option<Vec<String>>) -> ValidationRule {
        ValidationRule {
            rule_id: uuid::Uuid::new_v4(),
            rule_code: "TEST-001".into(),
            rule_name: "Test".into(),
            description: "Test rule".into(),
            target_table: "test_table".into(),
            target_column: "test_col".into(),
            domain: "D8".into(),
            category: category.into(),
            data_type: data_type.into(),
            min_value: min,
            max_value: max,
            allowed_values: allowed,
            regex_pattern: None,
            required: false,
            error_message: "Error de prueba".into(),
            error_code: "TEST-001".into(),
            standard_ref: Some(vec!["NIST TEST".into()]),
            standard_section: Some("§TEST".into()),
            severity: "error".into(),
        }
    }

    #[test]
    fn test_range_valid() {
        let engine = RuleEngine { rules: vec![make_rule("RANGE", "integer", Some(3600.0), Some(43200.0), None)] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!(28800));
        assert!(results[0].passed, "28800 debe ser válido en rango 3600-43200");
    }

    #[test]
    fn test_range_below_min() {
        let engine = RuleEngine { rules: vec![make_rule("RANGE", "integer", Some(3600.0), Some(43200.0), None)] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!(5));
        assert!(!results[0].passed, "5 debe ser rechazado (debajo de 3600)");
    }

    #[test]
    fn test_range_above_max() {
        let engine = RuleEngine { rules: vec![make_rule("RANGE", "integer", Some(3600.0), Some(43200.0), None)] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!(99999));
        assert!(!results[0].passed, "99999 debe ser rechazado (arriba de 43200)");
    }

    #[test]
    fn test_enum_valid() {
        let engine = RuleEngine { rules: vec![make_rule("ENUM", "text", None, None,
            Some(vec!["AAL1".into(), "AAL2".into(), "AAL3".into()]))] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!("AAL2"));
        assert!(results[0].passed, "AAL2 debe ser válido");
    }

    #[test]
    fn test_enum_invalid() {
        let engine = RuleEngine { rules: vec![make_rule("ENUM", "text", None, None,
            Some(vec!["AAL1".into(), "AAL2".into(), "AAL3".into()]))] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!("AAL0"));
        assert!(!results[0].passed, "AAL0 debe ser rechazado");
    }

    #[test]
    fn test_type_integer_rejects_string() {
        let engine = RuleEngine { rules: vec![make_rule("TYPE", "integer", None, None, None)] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!("H20000"));
        assert!(!results[0].passed, "'H20000' debe ser rechazado como integer");
    }

    #[test]
    fn test_type_integer_accepts_number() {
        let engine = RuleEngine { rules: vec![make_rule("TYPE", "integer", None, None, None)] };
        let results = engine.validate("test_table", "test_col", &serde_json::json!(28800));
        assert!(results[0].passed, "28800 debe ser aceptado como integer");
    }
}
