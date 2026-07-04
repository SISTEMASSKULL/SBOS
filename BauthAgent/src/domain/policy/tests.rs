// ============================================================
// bauth::domain::policy::tests — Tests exhaustivos (34 tests)
//
// Cubre: resolución ${params.*}, 17 operadores, parseo JSONB,
//        evaluación de reglas, lote con cortocircuito,
//        políticas reales de dominios D1, D3, D4, D6, D7, D8, D9.
// ============================================================

#[cfg(test)]
mod tests {
    use super::super::condition::{CompareOp, PolicyCondition};
    use super::super::evaluate::{eval_condition, eval_rule, evaluate};
    use super::super::parser::{from_policy_data, load_from_json, parse_policy_data};
    use super::super::resolver::resolve_value;
    use super::super::rule::{EvalContext, LogicOp, PolicyRule};
    use super::super::PolicyEngine;
    use crate::bitmask::PolicyState;
    use std::collections::HashMap;

    fn ctx(pairs: &[(&str, serde_json::Value)]) -> EvalContext {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    // ── Resolución de ${params.*} ──────────────────────────

    #[test]
    fn test_resolve_params_direct() {
        let mut params = HashMap::new();
        params.insert("limit".into(), serde_json::json!(10000));
        let raw = serde_json::json!("${params.limit}");
        let resolved = resolve_value(&raw, &params);
        assert_eq!(resolved, serde_json::json!(10000));
    }

    #[test]
    fn test_resolve_params_array_value() {
        let mut params = HashMap::new();
        params.insert("countries".into(), serde_json::json!(["BO","AR","CL"]));
        let raw = serde_json::json!("${params.countries}");
        let resolved = resolve_value(&raw, &params);
        assert_eq!(resolved, serde_json::json!(["BO","AR","CL"]));
    }

    #[test]
    fn test_resolve_params_nested_in_string() {
        let mut params = HashMap::new();
        params.insert("user".into(), serde_json::json!("admin"));
        let raw = serde_json::json!("El usuario ${params.user} excedió el límite");
        let resolved = resolve_value(&raw, &params);
        assert_eq!(resolved, serde_json::json!("El usuario admin excedió el límite"));
    }

    // ── Operadores ────────────────────────────────────────

    #[test]
    fn test_op_eq() {
        let c = ctx(&[("country", serde_json::json!("BO"))]);
        let cond = PolicyCondition { field: "country".into(), op: CompareOp::Eq, raw_value: serde_json::json!("BO") };
        assert!(eval_condition(&cond, &c));
    }

    #[test]
    fn test_op_gt_and_lt() {
        let c = ctx(&[("amount", serde_json::json!(5000.0))]);
        assert!(eval_condition(&PolicyCondition { field: "amount".into(), op: CompareOp::Gt, raw_value: serde_json::json!(1000) }, &c));
        assert!(!eval_condition(&PolicyCondition { field: "amount".into(), op: CompareOp::Lt, raw_value: serde_json::json!(1000) }, &c));
    }

    #[test]
    fn test_op_in_and_not_in() {
        let c = ctx(&[("country", serde_json::json!("BO"))]);
        assert!(eval_condition(&PolicyCondition { field: "country".into(), op: CompareOp::In, raw_value: serde_json::json!(["BO","AR","CL"]) }, &c));
        assert!(!eval_condition(&PolicyCondition { field: "country".into(), op: CompareOp::NotIn, raw_value: serde_json::json!(["BO","AR","CL"]) }, &c));
    }

    #[test]
    fn test_op_contains_and_regex() {
        let c = ctx(&[("email", serde_json::json!("admin@skull.bo"))]);
        assert!(eval_condition(&PolicyCondition { field: "email".into(), op: CompareOp::Contains, raw_value: serde_json::json!("@skull.bo") }, &c));
        assert!(eval_condition(&PolicyCondition { field: "email".into(), op: CompareOp::Regex, raw_value: serde_json::json!(r"^[a-z]+@skull\.bo$") }, &c));
    }

    #[test]
    fn test_op_exists_not_exists() {
        let c = ctx(&[("user_id", serde_json::json!("u1"))]);
        assert!(eval_condition(&PolicyCondition { field: "user_id".into(), op: CompareOp::Exists, raw_value: serde_json::Value::Null }, &c));
        assert!(eval_condition(&PolicyCondition { field: "missing_field".into(), op: CompareOp::NotExists, raw_value: serde_json::Value::Null }, &c));
    }

    #[test]
    fn test_op_cidr_match() {
        let c = ctx(&[("ip", serde_json::json!("10.0.0.50"))]);
        assert!(eval_condition(&PolicyCondition { field: "ip".into(), op: CompareOp::CidrMatch, raw_value: serde_json::json!("10.0.0.0/8") }, &c));
        assert!(!eval_condition(&PolicyCondition { field: "ip".into(), op: CompareOp::CidrMatch, raw_value: serde_json::json!("192.168.0.0/16") }, &c));
    }

    #[test]
    fn test_op_geo_distance() {
        let c = ctx(&[("location", serde_json::json!([-16.5, -68.2]))]);
        let ref_point = serde_json::json!({"lat":-16.5,"lon":-68.15,"max_km":10.0});
        assert!(eval_condition(&PolicyCondition { field: "location".into(), op: CompareOp::GeoDistance, raw_value: ref_point }, &c));
    }

    #[test]
    fn test_op_time_between() {
        let c = ctx(&[("now_time", serde_json::json!("14:30"))]);
        let window = serde_json::json!({"start":"08:00","end":"17:00"});
        assert!(eval_condition(&PolicyCondition { field: "now_time".into(), op: CompareOp::TimeBetween, raw_value: window.clone() }, &c));
        let c_night = ctx(&[("now_time", serde_json::json!("03:00"))]);
        assert!(!eval_condition(&PolicyCondition { field: "now_time".into(), op: CompareOp::TimeBetween, raw_value: window }, &c_night));
    }

    #[test]
    fn test_op_string_len() {
        let c = ctx(&[("password", serde_json::json!("abcdefghijkl"))]);
        assert!(eval_condition(&PolicyCondition { field: "password".into(), op: CompareOp::StringLen, raw_value: serde_json::json!(12) }, &c));
        assert!(!eval_condition(&PolicyCondition { field: "password".into(), op: CompareOp::StringLen, raw_value: serde_json::json!(20) }, &c));
    }

    // ── Parseo de JSONB ───────────────────────────────────

    #[test]
    fn test_parse_policy_data_jsonb() {
        let json = serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"Límite diario excedido","evaluate":{"logic":"and","conditions":[{"field":"day_total","op":"gt","value":"${params.daily_limit}"}]},"params":{"daily_limit":50000,"single_limit":10000}});
        let pd = parse_policy_data(&json).unwrap();
        assert_eq!(pd.schema, "bos_policy_v1");
        assert_eq!(pd.priority, 10);
        assert_eq!(pd.action, "deny");
        assert_eq!(pd.params.get("daily_limit"), Some(&serde_json::json!(50000)));
        let rule = from_policy_data(&pd);
        assert_eq!(rule.priority, 10);
        assert_eq!(rule.conditions[0].raw_value, serde_json::json!(50000));
    }

    #[test]
    fn test_parse_policy_data_missing_optional() {
        let json = serde_json::json!({"$schema":"bos_policy_v1","priority":99,"action":"step_up","evaluate":{"logic":"or","conditions":[{"field":"risk_score","op":"gt","value":80}]},"params":{}});
        let pd = parse_policy_data(&json).unwrap();
        assert_eq!(pd.schema, "bos_policy_v1");
        assert_eq!(pd.priority, 99);
        assert_eq!(pd.action, "step_up");
    }

    #[test]
    fn test_parse_policy_data_missing_evaluate() {
        assert!(parse_policy_data(&serde_json::json!({"priority":1,"action":"deny"})).is_err());
    }

    // ── Reglas ────────────────────────────────────────────

    #[test]
    fn test_rule_and_all_pass() {
        let rule = PolicyRule {
            slug: "TEST-AND".into(), description: "".into(), domain: 1, priority: 1,
            conditions: vec![
                PolicyCondition { field: "amount".into(), op: CompareOp::Gt, raw_value: serde_json::json!(1000) },
                PolicyCondition { field: "country".into(), op: CompareOp::Eq, raw_value: serde_json::json!("BO") },
            ],
            logic: LogicOp::And, action: "deny".into(), message: "Bloqueado".into(),
        };
        let c = ctx(&[("amount", serde_json::json!(5000)), ("country", serde_json::json!("BO"))]);
        let result = eval_rule(&rule, &c);
        assert!(result.conditions_met);
        assert_eq!(result.state, PolicyState::Rechazado);
    }

    #[test]
    fn test_rule_or_any_pass() {
        let rule = PolicyRule {
            slug: "TEST-OR".into(), description: "".into(), domain: 1, priority: 1,
            conditions: vec![
                PolicyCondition { field: "a".into(), op: CompareOp::Eq, raw_value: serde_json::json!(1) },
                PolicyCondition { field: "b".into(), op: CompareOp::Eq, raw_value: serde_json::json!(2) },
            ],
            logic: LogicOp::Or, action: "allow".into(), message: "OK".into(),
        };
        let c = ctx(&[("a", serde_json::json!(99)), ("b", serde_json::json!(2))]);
        let result = eval_rule(&rule, &c);
        assert!(result.conditions_met);
        assert_eq!(result.state, PolicyState::Aprobado);
    }

    // ── Políticas de dominio D3 (Financiero) ─────────────

    #[test]
    fn test_d3_limite_transaccional_deny() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"Monto excede límite","evaluate":{"logic":"and","conditions":[{"field":"transaction_amount","op":"gt","value":"${params.single_limit_bob}"}]},"params":{"single_limit_bob":10000,"daily_limit_bob":50000}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(!eval_rule(&rule, &ctx(&[("transaction_amount", serde_json::json!(500))])).conditions_met);
        let r = eval_rule(&rule, &ctx(&[("transaction_amount", serde_json::json!(15000))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Rechazado);
    }

    #[test]
    fn test_d3_dual_approval() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":20,"action":"pending_approval","message":"Requiere segunda firma","evaluate":{"logic":"and","conditions":[{"field":"transaction_amount","op":"gt","value":"${params.approval_threshold}"},{"field":"is_approved","op":"eq","value":false}]},"params":{"approval_threshold":25000}})).unwrap();
        let rule = from_policy_data(&pd);
        let r = eval_rule(&rule, &ctx(&[("transaction_amount", serde_json::json!(30000)), ("is_approved", serde_json::json!(false))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Pendiente);
        let r2 = eval_rule(&rule, &ctx(&[("transaction_amount", serde_json::json!(30000)), ("is_approved", serde_json::json!(true))]));
        assert!(!r2.conditions_met);
    }

    #[test]
    fn test_d3_velocity_anti_fraud() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":5,"action":"deny","message":"Posible fraude","evaluate":{"logic":"and","conditions":[{"field":"tx_count_last_minutes","op":"gt","value":"${params.max_tx}"}]},"params":{"max_tx":10,"window_min":5}})).unwrap();
        let rule = from_policy_data(&pd);
        let r = eval_rule(&rule, &ctx(&[("tx_count_last_minutes", serde_json::json!(15)), ("window_minutes", serde_json::json!(5))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Rechazado);
    }

    // ── D4 Temporal ─────────────────────────────────────

    #[test]
    fn test_d4_shift_hours() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":30,"action":"deny","message":"Fuera de horario","evaluate":{"logic":"and","conditions":[{"field":"now_time","op":"time_between","value":{"start":"08:00","end":"17:00"}}]},"params":{}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(eval_rule(&rule, &ctx(&[("now_time", serde_json::json!("14:30"))])).conditions_met);
        assert!(!eval_rule(&rule, &ctx(&[("now_time", serde_json::json!("03:00"))])).conditions_met);
    }

    #[test]
    fn test_d4_inactivity_timeout() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":35,"action":"mfa_required","message":"Sesión inactiva","evaluate":{"logic":"and","conditions":[{"field":"idle_minutes","op":"gt","value":"${params.max_idle_min}"}]},"params":{"max_idle_min":15}})).unwrap();
        let rule = from_policy_data(&pd);
        let r = eval_rule(&rule, &ctx(&[("idle_minutes", serde_json::json!(20))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Pendiente);
    }

    // ── D6 Geoespacial ──────────────────────────────────

    #[test]
    fn test_d6_impossible_travel() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"Viaje imposible","evaluate":{"logic":"and","conditions":[{"field":"distance_km","op":"gt","value":"${params.max_km}"},{"field":"time_since_last_login_h","op":"lt","value":"${params.max_hours}"}]},"params":{"max_km":900,"max_hours":1}})).unwrap();
        let rule = from_policy_data(&pd);
        let r = eval_rule(&rule, &ctx(&[("distance_km", serde_json::json!(5000)), ("time_since_last_login_h", serde_json::json!(0.5))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Rechazado);
        assert!(!eval_rule(&rule, &ctx(&[("distance_km", serde_json::json!(100)), ("time_since_last_login_h", serde_json::json!(2.0))])).conditions_met);
    }

    #[test]
    fn test_d6_country_allowlist() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":5,"action":"deny","message":"País no permitido","evaluate":{"logic":"and","conditions":[{"field":"country","op":"not_in","value":"${params.allowed_countries}"}]},"params":{"allowed_countries":["BO","AR","MX","CO","PE","CL"]}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(!eval_rule(&rule, &ctx(&[("country", serde_json::json!("BO"))])).conditions_met);
        let r = eval_rule(&rule, &ctx(&[("country", serde_json::json!("VE"))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Rechazado);
    }

    #[test]
    fn test_d6_geofence() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":15,"action":"deny","message":"Fuera del perímetro","evaluate":{"logic":"and","conditions":[{"field":"user_location","op":"geo_distance","value":{"lat":-16.5,"lon":-68.15,"max_km":0.5}}]},"params":{}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(eval_rule(&rule, &ctx(&[("user_location", serde_json::json!([-16.5005, -68.1505]))])).conditions_met);
        assert!(!eval_rule(&rule, &ctx(&[("user_location", serde_json::json!([-16.58, -68.15]))])).conditions_met);
    }

    // ── D7 Red, D8 Contexto, D9 Credenciales, D1 Lógico ─

    #[test]
    fn test_d7_cidr_range() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":5,"action":"deny","message":"IP fuera de rango","evaluate":{"logic":"and","conditions":[{"field":"client_ip","op":"cidr_match","value":"${params.allowed_cidr}"}]},"params":{"allowed_cidr":"10.0.0.0/8"}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(eval_rule(&rule, &ctx(&[("client_ip", serde_json::json!("10.50.1.100"))])).conditions_met);
        assert!(!eval_rule(&rule, &ctx(&[("client_ip", serde_json::json!("203.0.113.50"))])).conditions_met);
    }

    #[test]
    fn test_d8_ctx_required() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":1,"action":"deny","message":"ctx_id requerido","evaluate":{"logic":"and","conditions":[{"field":"ctx_id","op":"exists","value":null}]},"params":{}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(eval_rule(&rule, &ctx(&[("ctx_id", serde_json::json!("ctx-abc-123"))])).conditions_met);
        assert!(!eval_rule(&rule, &EvalContext::new()).conditions_met);
    }

    #[test]
    fn test_d9_password_length() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":1,"action":"deny","message":"Contraseña corta","evaluate":{"logic":"and","conditions":[{"field":"password","op":"string_len","value":"${params.min_length}"}]},"params":{"min_length":12}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(!eval_rule(&rule, &ctx(&[("password", serde_json::json!("shortpw"))])).conditions_met);
        assert!(eval_rule(&rule, &ctx(&[("password", serde_json::json!("thisisalongpassword"))])).conditions_met);
    }

    #[test]
    fn test_d1_app_access_allowlist() {
        let pd = parse_policy_data(&serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"App no permitida","evaluate":{"logic":"and","conditions":[{"field":"app_code","op":"not_in","value":"${params.allowed_apps}"}]},"params":{"allowed_apps":[1,2,5]}})).unwrap();
        let rule = from_policy_data(&pd);
        assert!(!eval_rule(&rule, &ctx(&[("app_code", serde_json::json!(2))])).conditions_met);
        assert!(eval_rule(&rule, &ctx(&[("app_code", serde_json::json!(99))])).conditions_met);
    }

    // ── Evaluación de lote ──────────────────────────────

    #[test]
    fn test_evaluate_batch_priority_order() {
        let rules = vec![
            PolicyRule { slug: "POL-D3-LIMITE".into(), description: "Límite".into(), domain: 3, priority: 10, conditions: vec![PolicyCondition { field: "amount".into(), op: CompareOp::Gt, raw_value: serde_json::json!(10000) }], logic: LogicOp::And, action: "deny".into(), message: "Excede límite".into() },
            PolicyRule { slug: "POL-D4-SHIFT".into(), description: "Horario".into(), domain: 4, priority: 30, conditions: vec![PolicyCondition { field: "now_time".into(), op: CompareOp::TimeBetween, raw_value: serde_json::json!({"start":"08:00","end":"17:00"}) }], logic: LogicOp::And, action: "allow".into(), message: "En horario".into() },
        ];
        let c = ctx(&[("amount", serde_json::json!(500)), ("now_time", serde_json::json!("14:30"))]);
        let (ok, state, results) = evaluate(&rules, &c);
        assert!(ok);
        assert_eq!(state, PolicyState::Aprobado);
        assert_eq!(results.len(), 2);
        assert!(!results[0].conditions_met);
        assert!(results[1].conditions_met);
        let c2 = ctx(&[("amount", serde_json::json!(15000)), ("now_time", serde_json::json!("14:30"))]);
        let (ok2, state2, results2) = evaluate(&rules, &c2);
        assert!(!ok2);
        assert_eq!(state2, PolicyState::Rechazado);
        assert_eq!(results2.len(), 1);
    }

    #[test]
    fn test_evaluate_batch_step_up() {
        let rules = vec![PolicyRule { slug: "POL-D3-DUAL-APPROVAL".into(), description: "Doble firma".into(), domain: 3, priority: 1, conditions: vec![PolicyCondition { field: "amount".into(), op: CompareOp::Gt, raw_value: serde_json::json!(25000) }], logic: LogicOp::And, action: "pending_approval".into(), message: "Requiere segunda firma".into() }];
        let c = ctx(&[("amount", serde_json::json!(50000))]);
        let (ok, state, results) = evaluate(&rules, &c);
        assert!(ok);
        assert_eq!(state, PolicyState::Pendiente);
        assert_eq!(results[0].action, "pending_approval");
    }

    // ── Load from framework JSON ─────────────────────────

    #[test]
    fn test_load_from_framework_json() {
        let json = serde_json::json!({
            "section_test": {"policy_slug":"POL-D3-LIMITE","description":"Límite","domain":3,"priority":1,"logic":"and","action":"deny","message":"Excede","conditions":[{"field":"amount","operator":"gt","value":10000}]},
            "nested": {"inner": {"policy_slug":"POL-D4-SHIFT","description":"Horario","domain":4,"priority":2,"logic":"or","action":"allow","message":"OK","conditions":[{"field":"now_hour","operator":"gte","value":8}]}}
        });
        let rules = load_from_json(&json);
        assert_eq!(rules.len(), 2);
        let slugs: Vec<&str> = rules.iter().map(|r| r.slug.as_str()).collect();
        assert!(slugs.contains(&"POL-D3-LIMITE"));
        assert!(slugs.contains(&"POL-D4-SHIFT"));
        let or_rule = rules.iter().find(|r| r.slug == "POL-D4-SHIFT").unwrap();
        assert!(matches!(or_rule.logic, LogicOp::Or));
    }

    // ── Pipeline completo JSONB ──────────────────────────

    #[test]
    fn test_full_jsonb_pipeline() {
        let jsonb = serde_json::json!({"$schema":"bos_policy_v1","priority":15,"action":"deny","message":"Fuera del país","evaluate":{"logic":"and","conditions":[{"field":"country","op":"not_in","value":"${params.allowed}"},{"field":"risk_score","op":"gt","value":"${params.risk_threshold}"}]},"params":{"allowed":["BO","AR","CL"],"risk_threshold":50}});
        let pd = parse_policy_data(&jsonb).expect("parseo JSONB");
        assert_eq!(pd.schema, "bos_policy_v1");
        assert_eq!(pd.params.get("risk_threshold"), Some(&serde_json::json!(50)));
        let rule = from_policy_data(&pd);
        assert_eq!(rule.conditions[0].raw_value, serde_json::json!(["BO","AR","CL"]));
        assert_eq!(rule.conditions[1].raw_value, serde_json::json!(50));
        let r = eval_rule(&rule, &ctx(&[("country", serde_json::json!("VE")), ("risk_score", serde_json::json!(80))]));
        assert!(r.conditions_met);
        assert_eq!(r.state, PolicyState::Rechazado);
        assert_eq!(r.condition_details.len(), 2);
        let r2 = eval_rule(&rule, &ctx(&[("country", serde_json::json!("BO")), ("risk_score", serde_json::json!(30))]));
        assert!(!r2.conditions_met);
    }

    // ── Validación CHECK constraint ──────────────────────

    #[test]
    fn test_all_policies_pass_check_constraint() {
        let cases = vec![
            serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"","evaluate":{"logic":"and","conditions":[{"field":"amount","op":"gt","value":10000}]},"params":{}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":30,"action":"deny","message":"","evaluate":{"logic":"and","conditions":[{"field":"now_time","op":"time_between","value":{"start":"08:00","end":"17:00"}}]},"params":{}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":10,"action":"deny","message":"","evaluate":{"logic":"and","conditions":[{"field":"distance_km","op":"gt","value":900}]},"params":{"max_km":900}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":5,"action":"deny","message":"","evaluate":{"logic":"and","conditions":[{"field":"client_ip","op":"cidr_match","value":"10.0.0.0/8"}]},"params":{}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":1,"action":"deny","message":"ctx_id requerido","evaluate":{"logic":"and","conditions":[{"field":"ctx_id","op":"exists","value":null}]},"params":{}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":1,"action":"deny","message":"","evaluate":{"logic":"and","conditions":[{"field":"password","op":"string_len","value":12}]},"params":{"min_length":12}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":20,"action":"step_up","message":"Requiere elevación","evaluate":{"logic":"or","conditions":[{"field":"risk","op":"gt","value":80}]},"params":{}}),
            serde_json::json!({"$schema":"bos_policy_v1","priority":15,"action":"mfa_required","message":"MFA requerido","evaluate":{"logic":"and","conditions":[{"field":"new_device","op":"eq","value":true}]},"params":{}}),
        ];
        for (i, json) in cases.iter().enumerate() {
            let pd = parse_policy_data(json).unwrap_or_else(|e| panic!("caso {}: {}", i, e));
            assert!(!pd.schema.is_empty(), "caso {}", i);
            assert!((1..=999).contains(&pd.priority), "caso {}: priority {}", i, pd.priority);
            assert!(["deny","allow","step_up","pending_approval","mfa_required"].contains(&pd.action.as_str()), "caso {}", i);
            assert!(!pd.evaluate.conditions.is_empty(), "caso {}", i);
            let rule = from_policy_data(&pd);
            let _ = eval_rule(&rule, &EvalContext::new());
        }
    }
}
