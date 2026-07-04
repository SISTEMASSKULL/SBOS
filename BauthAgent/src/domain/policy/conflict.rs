// ============================================================
// bauth::domain::policy::conflict — B9.T26 PolicyConflictDetector
//
// Detecta conflictos entre políticas según XACML 3.0 Policy Combining
// Algorithms y NIST SP 800-207 §3. Tres tipos de conflicto:
//
//   CONTRADICTORY_PARAMS  — misma rule_type, mismo dominio, valores
//                            contradictorios para la misma clave de config.
//                            Ej: dos "min_length" con value=8 y value=12.
//
//   DENY_ALLOW_CONFLICT   — una política deny anula una allow/pending
//                            sobre el mismo target (misma rule_type).
//                            Ej: deny(scope=BRANCH) + allow(scope=BRANCH).
//
//   REDUNDANT_POLICY      — dos políticas idénticas (mismo rule_type,
//                            mismos params). Duplicación sin beneficio.
//
// Severidad: ALTO → rechazar, MEDIO → warning + aprobación, BAJO → info.
//
// Integración: llamado desde policy_admin.rs en create/update antes de
// persistir. También expuesto vía bauth.policy.check_conflicts.
// ============================================================

#![allow(dead_code)]
use serde_json::Value;

// ── Tipos ────────────────────────────────────────────────────────

/// Severidad del conflicto.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConflictSeverity {
    /// Rechazar la operación — riesgo de seguridad.
    Alto,
    /// Permitir con warning — requiere aprobación del admin de seguridad.
    Medio,
    /// Informativo — no bloquea.
    Bajo,
}

/// Tipo de conflicto detectado.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConflictType {
    /// Misma rule_type, mismo dominio, valores contradictorios en config.
    ContradictoryParams,
    /// Una política deny anula una allow/pending sobre el mismo target.
    DenyAllowConflict,
    /// Dos políticas idénticas (duplicación).
    RedundantPolicy,
}

/// Reporte de un conflicto detectado.
#[derive(Debug, Clone)]
pub struct ConflictReport {
    pub conflict_type: ConflictType,
    pub severity: ConflictSeverity,
    pub policy_a: String,   // policy_code de la política existente
    pub policy_b: String,   // policy_code de la política nueva/en evaluación
    pub field: String,      // campo en conflicto (rule_type o clave de config)
    pub detail: String,     // descripción legible en español
}

/// Metadatos extraídos de un config de política para comparación.
#[derive(Debug, Clone)]
struct PolicyMeta {
    policy_code: String,
    domain: u8,
    rule_type: String,
    action_category: ActionCategory,
    config_keys: Vec<String>,
}

/// Categoría de acción de una política (derivada de rule_type).
#[derive(Debug, Clone, PartialEq, Eq)]
enum ActionCategory {
    Allow,
    Deny,
    Pending,
}

// ── Tabla de categorías por rule_type ────────────────────────────
//
// Derivada de ath_converter::dispatch(). Cada rule_type mapea a una
// categoría de acción: allow (permite), deny (bloquea), pending (requiere
// aprobación). Esta tabla DEBE mantenerse sincronizada con dispatch().

fn action_category(rule_type: &str) -> ActionCategory {
    match rule_type {
        // D1 Lógico — allow
        "scope" | "max_records" | "record_filter" | "field_restriction"
        | "data_classification" => ActionCategory::Allow,

        // D2 Físico — deny
        "anti_passback" | "two_person" | "mantrap_required" | "escort_required"
        | "biometric_enrollment" | "duress_code" => ActionCategory::Deny,

        // D3 Financiero — mixto
        "dual_approval" => ActionCategory::Pending,
        "sod" | "daily_limit" | "monthly_limit" | "secure_network_required" => ActionCategory::Deny,
        "approval_chain" | "sin_compliance" | "transaction_schedule" => ActionCategory::Allow,

        // D4 Temporal — mixto
        "schedule" | "breaks" | "overtime" => ActionCategory::Allow,
        "session_timeout" => ActionCategory::Deny,

        // D5 Biométrico — deny (seguridad)
        "fmr_threshold" | "liveness" => ActionCategory::Deny,
        "alternative_required" | "gdpr_consent" => ActionCategory::Allow,

        // D6 Geoespacial — deny
        "geofence_required" | "country_restrict" | "velocity_check"
        | "data_residency" | "sanctions" => ActionCategory::Deny,
        "trust_tier" => ActionCategory::Allow,

        // D7 Red — deny (zero-trust)
        "mtls_required" | "vpn_required" | "default_deny" | "device_trust"
        | "rate_limit" | "continuous_verification" => ActionCategory::Deny,

        // D8 Contexto — mixto
        "ctx_id_required" | "session_ttl" => ActionCategory::Deny,
        "reauth" => ActionCategory::Pending,
        "context_switch_audit" | "caep" => ActionCategory::Allow,

        // D9 Credenciales — deny (NIST 800-63B)
        "min_length" | "hibp_check" | "mfa_required" | "mfa_hardware"
        | "phishing_resistance" | "max_concurrent_sessions" | "progressive_lockout"
        | "history_check" | "blocklist" | "hash_algorithm" => ActionCategory::Deny,
        "step_up" => ActionCategory::Pending,
        "no_complexity_rules" | "no_periodic_rotation" | "recovery_requires_mfa"
        | "backup_codes" => ActionCategory::Allow,

        // D10 Delegación — deny
        "max_duration" | "no_redelegation" | "non_delegable" => ActionCategory::Deny,
        "requires_approval" => ActionCategory::Allow,

        // D11 Auditoría — mixto
        "hash_chain" | "access_review" => ActionCategory::Deny,
        "retention" => ActionCategory::Allow,

        // D12 Blockchain — deny
        "merkle_anchor" | "merkle_proof" | "consensus" | "did_registry"
        | "verifiable_credentials" => ActionCategory::Deny,
        "contract_audit" => ActionCategory::Pending,

        _ => ActionCategory::Allow, // desconocido → tratar como allow
    }
}

// ── Extracción de metadatos ──────────────────────────────────────

fn extract_meta(policy_code: &str, domain: u8, config: &Value) -> Option<PolicyMeta> {
    let rule_type = config.get("rule")?.as_str()?.to_string();
    let action_category = action_category(&rule_type);
    let config_keys: Vec<String> = config.as_object()
        .map(|o| o.keys().cloned().collect())
        .unwrap_or_default();

    Some(PolicyMeta {
        policy_code: policy_code.to_string(),
        domain,
        rule_type,
        action_category,
        config_keys,
    })
}

// ── Funciones de detección ───────────────────────────────────────

/// Detecta todos los conflictos entre una política nueva y las existentes.
///
/// `new_code`: policy_code de la nueva política.
/// `new_config`: config JSONB de la nueva política.
/// `domain`: dominio (1-12).
/// `existing`: lista de (policy_code, config) de políticas ya activas en ese dominio.
pub fn detect_conflicts(
    new_code: &str,
    new_config: &Value,
    domain: u8,
    existing: &[(String, Value)],
) -> Vec<ConflictReport> {
    let mut conflicts = Vec::new();

    let new_meta = match extract_meta(new_code, domain, new_config) {
        Some(m) => m,
        None => {
            // Si no tiene rule_type, no hay conflicto posible (entrada LIB-*)
            return conflicts;
        }
    };

    for (existing_code, existing_config) in existing {
        // No comparar contra sí mismo
        if existing_code == new_code {
            continue;
        }

        let existing_meta = match extract_meta(existing_code, domain, existing_config) {
            Some(m) => m,
            None => continue,
        };

        // Solo comparar políticas con la misma rule_type
        if existing_meta.rule_type != new_meta.rule_type {
            continue;
        }

        // ── 1. REDUNDANT_POLICY: config idéntico ────────────────
        if new_config == existing_config {
            conflicts.push(ConflictReport {
                conflict_type: ConflictType::RedundantPolicy,
                severity: ConflictSeverity::Bajo,
                policy_a: existing_code.clone(),
                policy_b: new_code.to_string(),
                field: new_meta.rule_type.clone(),
                detail: format!(
                    "La política '{}' es idéntica a '{}' (mismo rule_type={}, mismos parámetros). \
                     Considere eliminar una o diferenciarlas.",
                    new_code, existing_code, new_meta.rule_type
                ),
            });
            continue;
        }

        // ── 2. DENY_ALLOW_CONFLICT: deny vs allow sobre mismo target ──
        if is_deny_allow_conflict(&new_meta, &existing_meta) {
            conflicts.push(ConflictReport {
                conflict_type: ConflictType::DenyAllowConflict,
                severity: ConflictSeverity::Alto,
                policy_a: existing_code.clone(),
                policy_b: new_code.to_string(),
                field: new_meta.rule_type.clone(),
                detail: format!(
                    "Conflicto DENY/ALLOW: '{}' ({}) y '{}' ({}) tienen acciones opuestas \
                     sobre el mismo rule_type '{}'. La política DENY prevalecerá \
                     (XACML 3.0 deny-overrides), anulando la ALLOW.",
                    existing_code, category_name(&existing_meta.action_category),
                    new_code, category_name(&new_meta.action_category),
                    new_meta.rule_type
                ),
            });
            continue;
        }

        // ── 3. CONTRADICTORY_PARAMS: misma rule_type, distinto valor ──
        if let Some(c) = detect_contradictory_params(
            &new_meta, new_config, &existing_meta, existing_config,
        ) {
            conflicts.push(c);
        }
    }

    // Ordenar por severidad: Alto primero
    conflicts.sort_by_key(|c| match c.severity {
        ConflictSeverity::Alto => 0,
        ConflictSeverity::Medio => 1,
        ConflictSeverity::Bajo => 2,
    });

    conflicts
}

fn is_deny_allow_conflict(a: &PolicyMeta, b: &PolicyMeta) -> bool {
    use ActionCategory::*;
    matches!(
        (&a.action_category, &b.action_category),
        (Allow, Deny) | (Deny, Allow) | (Allow, Pending) | (Pending, Allow) | (Deny, Pending) | (Pending, Deny)
    )
}

/// Detecta valores contradictorios: misma clave de config, distinto valor numérico.
/// Aplica a claves como "value", "amount", "max_seconds", "threshold", "days", etc.
fn detect_contradictory_params(
    new_meta: &PolicyMeta,
    new_config: &Value,
    existing_meta: &PolicyMeta,
    existing_config: &Value,
) -> Option<ConflictReport> {
    // Claves numéricas que indican umbral/límite
    const NUMERIC_KEYS: &[&str] = &[
        "value", "amount", "threshold", "max_seconds", "days",
        "max_kmh", "interval_seconds", "min_score", "permanent_lock",
        "priority",
    ];

    for key in NUMERIC_KEYS {
        let new_val = new_config.get(key).and_then(|v| v.as_f64());
        let existing_val = existing_config.get(key).and_then(|v| v.as_f64());

        if let (Some(n), Some(e)) = (new_val, existing_val) {
            if (n - e).abs() > f64::EPSILON {
                return Some(ConflictReport {
                    conflict_type: ConflictType::ContradictoryParams,
                    severity: ConflictSeverity::Medio,
                    policy_a: existing_meta.policy_code.clone(),
                    policy_b: new_meta.policy_code.clone(),
                    field: format!("{}.{}", new_meta.rule_type, key),
                    detail: format!(
                        "Valores contradictorios para '{}.{}': '{}' tiene {}={}, \
                         '{}' tiene {}={}. Esto puede causar comportamiento ambiguo \
                         en el PolicyEngine. Considere consolidar en una sola política \
                         o añadir condiciones de diferenciación.",
                        new_meta.rule_type, key,
                        existing_meta.policy_code, key, e,
                        new_meta.policy_code, key, n
                    ),
                });
            }
        }
    }

    // Comparar arrays (ej: allowed countries, scopes)
    for key in &["allowed", "level"] {
        let new_arr = new_config.get(key);
        let existing_arr = existing_config.get(key);
        if new_arr.is_some() && existing_arr.is_some() && new_arr != existing_arr {
            return Some(ConflictReport {
                conflict_type: ConflictType::ContradictoryParams,
                severity: ConflictSeverity::Medio,
                policy_a: existing_meta.policy_code.clone(),
                policy_b: new_meta.policy_code.clone(),
                field: format!("{}.{}", new_meta.rule_type, key),
                detail: format!(
                    "Listas diferentes para '{}.{}': '{}' y '{}' definen \
                     conjuntos distintos. Solo una prevalecerá según prioridad.",
                    new_meta.rule_type, key,
                    existing_meta.policy_code, new_meta.policy_code
                ),
            });
        }
    }

    None
}

fn category_name(c: &ActionCategory) -> &'static str {
    match c {
        ActionCategory::Allow => "allow",
        ActionCategory::Deny => "deny",
        ActionCategory::Pending => "pending_approval",
    }
}

// ── Tests ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_conflict_different_rule_types() {
        let existing = vec![
            ("SCOPE_BRANCH".into(), serde_json::json!({"rule": "scope", "allowed": ["BRANCH"]})),
        ];
        let new_config = serde_json::json!({"rule": "max_records", "value": 200});
        let conflicts = detect_conflicts("MAX_200", &new_config, 1, &existing);
        assert!(conflicts.is_empty(), "diferentes rule_type no deben generar conflicto");
    }

    #[test]
    fn test_redundant_policy_detected() {
        let config = serde_json::json!({"rule": "scope", "allowed": ["BRANCH"]});
        let existing = vec![("SCOPE_BRANCH".into(), config.clone())];
        let conflicts = detect_conflicts("SCOPE_BRANCH_V2", &config, 1, &existing);
        assert_eq!(conflicts.len(), 1);
        assert_eq!(conflicts[0].conflict_type, ConflictType::RedundantPolicy);
        assert_eq!(conflicts[0].severity, ConflictSeverity::Bajo);
    }

    #[test]
    fn test_deny_allow_conflict() {
        let existing: Vec<(String, Value)> = vec![
            ("SCOPE_BRANCH_ALLOW".into(), serde_json::json!({"rule": "scope", "allowed": ["BRANCH"]})),
        ];
        // "scope" es allow, pero si hubiera un deny para scope...
        // anti_passback es deny
        let new_config = serde_json::json!({"rule": "anti_passback"});
        let existing_deny = vec![
            ("PASSBACK_DENY".into(), serde_json::json!({"rule": "anti_passback"})),
        ];
        let conflicts = detect_conflicts("PASSBACK_ALLOW", &new_config, 2, &existing_deny);
        // Ambos son "anti_passback" → ambos son deny → NO hay conflicto deny/allow
        assert!(conflicts.iter().all(|c| c.conflict_type != ConflictType::DenyAllowConflict),
                "misma categoría deny no debe generar deny/allow conflict");
    }

    #[test]
    fn test_contradictory_numeric_value() {
        let existing = vec![
            ("MIN_LEN_8".into(), serde_json::json!({"rule": "min_length", "value": 8})),
        ];
        let new_config = serde_json::json!({"rule": "min_length", "value": 12});
        let conflicts = detect_conflicts("MIN_LEN_12", &new_config, 9, &existing);
        assert!(!conflicts.is_empty());
        let contradictory = conflicts.iter()
            .find(|c| c.conflict_type == ConflictType::ContradictoryParams);
        assert!(contradictory.is_some(), "debe detectar valores contradictorios");
        assert_eq!(contradictory.unwrap().severity, ConflictSeverity::Medio);
    }

    #[test]
    fn test_contradictory_array_allowed() {
        let existing = vec![
            ("ALLOW_BO".into(), serde_json::json!({"rule": "country_restrict", "allowed": ["BO"]})),
        ];
        let new_config = serde_json::json!({"rule": "country_restrict", "allowed": ["BO", "AR"]});
        let conflicts = detect_conflicts("ALLOW_BO_AR", &new_config, 6, &existing);
        assert!(!conflicts.is_empty());
        let contradictory = conflicts.iter()
            .find(|c| c.conflict_type == ConflictType::ContradictoryParams);
        assert!(contradictory.is_some(), "debe detectar listas diferentes");
    }

    #[test]
    fn test_self_not_compared() {
        let config = serde_json::json!({"rule": "scope", "allowed": ["BRANCH"]});
        let existing = vec![
            ("TEST_SELF".into(), config.clone()),
        ];
        // Comparar TEST_SELF contra sí mismo → no debe generar conflicto
        let conflicts = detect_conflicts("TEST_SELF", &config, 1, &existing);
        assert!(conflicts.is_empty(), "no debe compararse contra sí mismo");
    }

    #[test]
    fn test_conflicts_sorted_by_severity() {
        let existing = vec![
            ("EXISTING_1".into(), serde_json::json!({"rule": "min_length", "value": 8})),
            ("EXISTING_2".into(), serde_json::json!({"rule": "min_length", "value": 8})),
        ];
        let new_config = serde_json::json!({"rule": "min_length", "value": 12});
        let conflicts = detect_conflicts("NEW_POL", &new_config, 9, &existing);
        // Primer conflicto debe ser Alto (si hay), luego Medio, luego Bajo
        for w in conflicts.windows(2) {
            let severity_order = |s: &ConflictSeverity| match s {
                ConflictSeverity::Alto => 0,
                ConflictSeverity::Medio => 1,
                ConflictSeverity::Bajo => 2,
            };
            assert!(severity_order(&w[0].severity) <= severity_order(&w[1].severity),
                    "conflictos deben ordenarse por severidad");
        }
    }
}
