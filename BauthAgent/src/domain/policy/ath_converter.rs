// ============================================================
// bauth::domain::policy::ath_converter — ath_policy_dN config → PolicyRule
//
// Las tablas ath_policy_dN almacenan políticas operativas en formato simple:
//   {"rule": "scope", "level": "BRANCH"}
//   {"rule": "daily_limit", "amount": 10000}
//
// Convierte cada tipo de regla a un PolicyRule evaluable por el PolicyEngine
// existente (XACML 3.0 / NIST ABAC SP 800-162).
//
// SEMÁNTICA DE ACCIONES (ver evaluate.rs):
//   allow  — concede acceso SI la condición se cumple. No bloquea globalmente.
//             Usar para permisos opcionales (D1 scope, D3 approval_chain).
//   deny   — BLOQUEA con cortocircuito SI la condición se cumple.
//             La condición = caso de fallo. Ej: deny(eq("has_mtls", false)).
//   pending_approval — requiere aprobación SI la condición se cumple.
//
// IMPORTANTE: compare_numeric usa unwrap_or(0.0) cuando el valor es Null.
//   Por lo tanto: v("clave") DEBE coincidir con la clave REAL en el config del seed.
//   Si la clave no existe, compare_numeric devuelve 0.0, lo cual puede disparar
//   deny incorrectamente (ej: gt(x, 0.0) es true para cualquier x > 0).
//
// Patrón: data-driven con helpers parametrizados.
// Agregar un nuevo tipo de regla = un solo arm en dispatch().
// ============================================================

#![allow(dead_code)]
use super::condition::{CompareOp, PolicyCondition};
use super::rule::{LogicOp, PolicyRule};
use serde_json::Value;

/// Convierte una fila de ath_policy_dN a PolicyRule evaluable.
/// Retorna None si el campo "rule" falta o el tipo no está implementado.
pub fn convert(slug: &str, name: &str, config: &Value, priority: i32, domain: u8) -> Option<PolicyRule> {
    let rule = config.get("rule")?.as_str()?;
    let (conditions, action) = dispatch(rule, config)?;
    Some(PolicyRule {
        slug: slug.into(),
        description: format!("{}: {}", rule, name),
        domain,
        priority,
        conditions,
        logic: LogicOp::And,
        action: action.into(),
        message: format!("[D{}·{}] {}", domain, rule, name),
    })
}

// ── Helpers: acciones ──────────────────────────────────────────

fn allow(c: Vec<PolicyCondition>) -> Option<(Vec<PolicyCondition>, &'static str)> {
    Some((c, "allow"))
}

fn deny(c: Vec<PolicyCondition>) -> Option<(Vec<PolicyCondition>, &'static str)> {
    Some((c, "deny"))
}

fn pending(c: Vec<PolicyCondition>) -> Option<(Vec<PolicyCondition>, &'static str)> {
    Some((c, "pending_approval"))
}

// ── Helpers: condiciones ───────────────────────────────────────

fn cond(field: &str, op: CompareOp, val: Value) -> PolicyCondition {
    PolicyCondition { field: field.into(), op, raw_value: val }
}

fn lte(field: &str, v: &Value)  -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Lte, v.clone())] }
fn gte(field: &str, v: &Value)  -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Gte, v.clone())] }
fn lt(field: &str, v: &Value)   -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Lt,  v.clone())] }
fn gt(field: &str, v: &Value)   -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Gt,  v.clone())] }
fn eq(field: &str, v: Value)    -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Eq,  v)] }
fn in_list(field: &str, v: Value)     -> Vec<PolicyCondition> { vec![cond(field, CompareOp::In,        v)] }
fn not_in_list(field: &str, v: Value) -> Vec<PolicyCondition> { vec![cond(field, CompareOp::NotIn,     v)] }
fn exists(field: &str)     -> Vec<PolicyCondition> { vec![cond(field, CompareOp::Exists,    Value::Null)] }
fn not_exists(field: &str) -> Vec<PolicyCondition> { vec![cond(field, CompareOp::NotExists, Value::Null)] }

fn time_between(field: &str, cfg: &Value) -> Vec<PolicyCondition> {
    let start = cfg.get("start_hour").and_then(|v| v.as_str()).unwrap_or("08:00");
    let end   = cfg.get("end_hour").and_then(|v| v.as_str()).unwrap_or("18:00");
    vec![cond(field, CompareOp::TimeBetween, serde_json::json!({"start": start, "end": end}))]
}

// ── Tabla de despacho ──────────────────────────────────────────────────────
//
// Criterio para elegir acción:
//   allow  → concesión de permiso (fallar no bloquea globalmente)
//   deny   → control de seguridad obligatorio (fallar = bloqueo inmediato)
//   pending → requiere aprobación humana antes de continuar
//
// CLAVES DE CONFIG: verificar contra los seeds reales en la BD.
// La función v(key) retorna Null si la clave no existe → compare_numeric = 0.0.

fn dispatch(rule: &str, cfg: &Value) -> Option<(Vec<PolicyCondition>, &'static str)> {
    let v = |key: &str| cfg.get(key).cloned().unwrap_or(Value::Null);

    match rule {
        // ── D1 Lógico — permisos de acceso, no controles de seguridad ───────
        // allow: concede IF la condición se cumple (no bloquea si falla)
        "scope" => {
            let allowed = cfg.get("allowed").cloned()
                .unwrap_or_else(|| cfg.get("level")
                    .map(|l| Value::Array(vec![l.clone()]))
                    .unwrap_or(serde_json::json!(["BRANCH"])));
            allow(in_list("user_scope", allowed))
        }
        "max_records"       => allow(lte("record_count", &v("value"))),
        "record_filter"     => allow(vec![]),
        "field_restriction" => allow(vec![]),
        "data_classification" => {
            let allowed = match cfg.get("level").and_then(|v| v.as_str()).unwrap_or("INTERNAL") {
                "PUBLIC"       => serde_json::json!(["PUBLIC","INTERNAL","CONFIDENTIAL","SECRET"]),
                "INTERNAL"     => serde_json::json!(["INTERNAL","CONFIDENTIAL","SECRET"]),
                "CONFIDENTIAL" => serde_json::json!(["CONFIDENTIAL","SECRET"]),
                _              => serde_json::json!(["SECRET"]),
            };
            allow(in_list("data_clearance", allowed))
        }

        // ── D2 Físico — controles de acceso físico → deny ────────────────────
        "anti_passback"        => deny(eq("last_exit_recorded", serde_json::json!(false))),
        "two_person"           => deny(eq("companion_present",  serde_json::json!(false))),
        "mantrap_required"     => deny(eq("mantrap_cleared",    serde_json::json!(false))),
        "escort_required"      => deny(eq("escort_present",     serde_json::json!(false))),
        "biometric_enrollment" => deny(eq("biometric_enrolled", serde_json::json!(false))),
        "duress_code"          => deny(eq("duress_active",      serde_json::json!(true))),

        // ── D3 Financiero ────────────────────────────────────────────────────
        // pending_approval: se dispara cuando monto ≥ umbral (config: "threshold")
        "dual_approval"    => pending(gte("amount", &v("threshold"))),
        // deny: SoD violado = bloqueo inmediato
        "sod"              => deny(eq("sod_ok", serde_json::json!(false))),
        // deny: superar límites = bloqueo — seeds usan "amount" (no "value")
        "daily_limit"      => deny(gt("daily_total",   &v("amount"))),
        "monthly_limit"    => deny(gt("monthly_total", &v("amount"))),
        // approval_chain: config tiene array "levels" complejo (sin campo numérico simple)
        // → allow vacío: la lógica de niveles la maneja el AccessEvaluator
        "approval_chain"   => allow(vec![]),
        // config-only: sin parámetro de runtime → always pass
        "sin_compliance" | "transaction_schedule" => allow(vec![]),
        // deny: red insegura = bloqueo
        "secure_network_required" => deny(eq("has_secure_network", serde_json::json!(false))),

        // ── D4 Temporal ──────────────────────────────────────────────────────
        // allow: dentro del horario = acceso concedido
        "schedule"        => allow(time_between("current_time", cfg)),
        // deny: sesión expirada = bloqueo — config usa "max_seconds", contexto: "session_age_s"
        "session_timeout" => deny(gt("session_age_s", &v("max_seconds"))),
        // allow: horario especial requiere autorización previa
        "breaks" | "overtime" => allow(eq("schedule_authorized", serde_json::json!(true))),

        // ── D5 Biométrico ────────────────────────────────────────────────────
        // deny: score fuera de rango = bloqueo
        "fmr_threshold"        => deny(gt("fmr_score",      &v("value"))),
        "liveness"             => deny(lt("liveness_score",  &cfg.get("min_score").cloned().unwrap_or(serde_json::json!(0.95)))),
        // allow: método alternativo = permiso adicional
        "alternative_required" => allow(eq("alternative_method_enrolled", serde_json::json!(true))),
        "gdpr_consent"         => allow(eq("gdpr_consent_given", serde_json::json!(true))),

        // ── D6 Geoespacial — controles de seguridad → deny ───────────────────
        "geofence_required" => deny(eq("inside_geofence",  serde_json::json!(false))),
        // config tiene "allowed": ["BO"] — v("allowed") ✓
        "country_restrict"  => deny(not_in_list("country_code",
            cfg.get("allowed").cloned().unwrap_or(serde_json::json!(["BO"])))),
        // config tiene "max_kmh" (no "max_speed_km_h"), contexto: "travel_speed_km_h"
        "velocity_check"    => deny(gt("travel_speed_km_h", &v("max_kmh"))),
        "data_residency"    => deny(eq("data_residency_ok", serde_json::json!(false))),
        // config tiene "tiers" (todos los posibles, sin subconjunto "allowed")
        // → allow vacío: la evaluación de tier la maneja el risk engine
        "trust_tier"        => allow(vec![]),
        "sanctions"         => deny(eq("not_sanctioned",   serde_json::json!(false))),

        // ── D7 Red — zero-trust → deny ────────────────────────────────────────
        "mtls_required"           => deny(eq("has_mtls",  serde_json::json!(false))),
        "vpn_required"            => deny(eq("has_vpn",   serde_json::json!(false))),
        // config tiene "explicit_allow": [...servicios...] (array), no boolean
        // → chequear campo boolean "has_explicit_allow" en el contexto de runtime
        "default_deny"            => deny(eq("has_explicit_allow", serde_json::json!(false))),
        // config tiene "min_score" (no "allowed_levels"), contexto: "device_trust_score"
        "device_trust"            => deny(lt("device_trust_score", &v("min_score"))),
        // config tiene "auth_req_s" (peticiones/segundo, no por minuto)
        "rate_limit"              => deny(gt("requests_per_s", &v("auth_req_s"))),
        // config tiene "interval_seconds" ✓, contexto: "seconds_since_verify"
        "continuous_verification" => deny(gt("seconds_since_verify", &v("interval_seconds"))),

        // ── D8 Contexto ──────────────────────────────────────────────────────
        // deny: ctx_id ausente = bloqueo inmediato (SBOS-049 obligatorio)
        "ctx_id_required"      => deny(not_exists("ctx_id")),
        // config tiene "max_seconds" ✓, contexto: "session_age_s"
        "session_ttl"          => deny(gt("session_age_s", &v("max_seconds"))),
        // pending: re-autenticación necesaria — config: "interval_seconds" ✓
        "reauth"               => pending(gt("seconds_since_auth", &v("interval_seconds"))),
        // audit/eventos: no bloquean
        "context_switch_audit" | "caep" => allow(vec![]),

        // ── D9 Credenciales ──────────────────────────────────────────────────
        // min_length: config tiene "value": 12 ✓
        "min_length"              => deny(lt("password_length",  &v("value"))),
        "hibp_check"              => deny(eq("hibp_compromised", serde_json::json!(true))),
        "mfa_required"            => deny(eq("mfa_verified",     serde_json::json!(false))),
        "mfa_hardware"            => deny(not_in_list("mfa_method",
            serde_json::json!(["fido2","webauthn","yubikey","smartcard"]))),
        "phishing_resistance"     => deny(not_in_list("mfa_method",
            serde_json::json!(["fido2","webauthn","passkey"]))),
        // max_concurrent_sessions: config tiene "value": 1 ✓
        "max_concurrent_sessions" => deny(gt("session_count",    &v("value"))),
        // progressive_lockout: config tiene "permanent_lock": 50 (no "max_attempts")
        "progressive_lockout"     => deny(gte("failed_attempts", &v("permanent_lock"))),
        // step_up: config tiene "from_aal"/"to_aal", contexto: "current_loa"
        "step_up"                 => pending(lt("current_loa",   &cfg.get("min_loa").cloned().unwrap_or(serde_json::json!(2)))),
        // config-only: declaraciones de política sin parámetro de runtime
        "no_complexity_rules" | "no_periodic_rotation" | "recovery_requires_mfa" | "backup_codes" => allow(vec![]),
        "history_check" => deny(eq("password_not_reused",  serde_json::json!(false))),
        "blocklist"     => deny(eq("password_not_blocked",  serde_json::json!(false))),
        // hash_algorithm: config tiene "algorithm" (no "allowed_algorithms") → lista hardcoded
        "hash_algorithm" => deny(not_in_list("password_hash_algorithm",
            serde_json::json!(["argon2id","bcrypt"]))),

        // ── D10 Delegación ───────────────────────────────────────────────────
        // config tiene "days" para max_duration ✓
        "max_duration"      => deny(gt("delegation_days", &v("days"))),
        "requires_approval" => allow(eq("delegation_approved", serde_json::json!(true))),
        "no_redelegation"   => deny(eq("is_redelegation", serde_json::json!(true))),
        "non_delegable"     => deny(eq("is_delegation",   serde_json::json!(true))),

        // ── D11 Auditoría ────────────────────────────────────────────────────
        "retention"     => allow(lte("data_age_days", &v("days"))),
        "hash_chain"    => deny(eq("hash_chain_valid", serde_json::json!(false))),
        "access_review" => deny(eq("access_reviewed",  serde_json::json!(false))),

        // ── D12 Blockchain ───────────────────────────────────────────────────
        "merkle_anchor"          => deny(eq("merkle_anchor_ready", serde_json::json!(false))),
        "merkle_proof"           => deny(eq("merkle_proof_valid",  serde_json::json!(false))),
        "contract_audit"         => pending(vec![]),
        "consensus"              => deny(eq("consensus_reached",   serde_json::json!(false))),
        "did_registry"           => deny(eq("did_registered",      serde_json::json!(false))),
        "verifiable_credentials" => deny(eq("vc_valid",            serde_json::json!(false))),

        other => {
            tracing::debug!(rule = other, "tipo de regla no mapeado — omitiendo");
            None
        }
    }
}
