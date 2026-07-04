// ============================================================
// bauth::server::handlers::policy_admin — B9.T25 PolicyAdministrator CRUD
//
// Handlers JSON-RPC 2.0 para administración de políticas por dominio:
//   bauth.policy.create   — INSERT en ath_policy_d{domain}
//   bauth.policy.update   — UPDATE en ath_policy_d{domain}
//   bauth.policy.delete   — Soft-delete (is_active = false)
//   bauth.policy.validate — Dry-run: validar política sin persistir
//
// Cada handler opera sobre la tabla ath_policy_dN correspondiente.
// Validación de reglas vía ath_converter::convert() — si el tipo de
// regla no está mapeado en el dispatch(), la política se rechaza.
//
// Cambios de política → SIGHUP al PolicyEngine → recarga sin reiniciar.
// Ref: NIST SP 800-207 §3 (PA role), ADR-020, XACML 3.0.
// ============================================================

#![allow(dead_code)]
use crate::domain::policy::conflict::{self, ConflictSeverity};
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use sqlx::PgPool;

// ── Helpers ──────────────────────────────────────────────────────

/// Valida que el dominio esté en [1,12].
fn check_domain(domain: u8) -> Result<(), JsonRpcError> {
    if (1..=12).contains(&domain) {
        Ok(())
    } else {
        Err(JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })
    }
}

/// Valida que el código de política no esté vacío.
fn check_policy_code(code: &str) -> Result<(), JsonRpcError> {
    if code.is_empty() {
        Err(JsonRpcError { code: -32602, message: "policy_code requerido".into(), data: None })
    } else if code.len() > 128 {
        Err(JsonRpcError { code: -32602, message: "policy_code excede 128 caracteres".into(), data: None })
    } else {
        Ok(())
    }
}

/// Valida que el config contenga el campo "rule" y que sea un tipo soportado.
fn validate_config_structure(config: &Value) -> Result<(), JsonRpcError> {
    let rule_type = config.get("rule")
        .and_then(|v| v.as_str())
        .ok_or_else(|| JsonRpcError {
            code: -32602,
            message: "config debe contener campo 'rule' de tipo string".into(),
            data: None,
        })?;

    // Lista blanca de rule_type soportados por ath_converter::dispatch()
    const VALID_RULES: &[&str] = &[
        // D1 Lógico
        "scope", "max_records", "record_filter", "field_restriction", "data_classification",
        // D2 Físico
        "anti_passback", "two_person", "mantrap_required", "escort_required",
        "biometric_enrollment", "duress_code",
        // D3 Financiero
        "dual_approval", "sod", "daily_limit", "monthly_limit", "approval_chain",
        "sin_compliance", "transaction_schedule", "secure_network_required",
        // D4 Temporal
        "schedule", "session_timeout", "breaks", "overtime",
        // D5 Biométrico
        "fmr_threshold", "liveness", "alternative_required", "gdpr_consent",
        // D6 Geoespacial
        "geofence_required", "country_restrict", "velocity_check", "data_residency",
        "trust_tier", "sanctions",
        // D7 Red
        "mtls_required", "vpn_required", "default_deny", "device_trust",
        "rate_limit", "continuous_verification",
        // D8 Contexto
        "ctx_id_required", "session_ttl", "reauth", "context_switch_audit", "caep",
        // D9 Credenciales
        "min_length", "hibp_check", "mfa_required", "mfa_hardware",
        "phishing_resistance", "max_concurrent_sessions", "progressive_lockout",
        "step_up", "no_complexity_rules", "no_periodic_rotation",
        "recovery_requires_mfa", "backup_codes", "history_check", "blocklist",
        "hash_algorithm",
        // D10 Delegación
        "max_duration", "requires_approval", "no_redelegation", "non_delegable",
        // D11 Auditoría
        "retention", "hash_chain", "access_review",
        // D12 Blockchain
        "merkle_anchor", "merkle_proof", "contract_audit", "consensus",
        "did_registry", "verifiable_credentials",
    ];

    if !VALID_RULES.contains(&rule_type) {
        return Err(JsonRpcError {
            code: -32602,
            message: format!(
                "rule_type '{}' no soportado. Tipos válidos: scope, dual_approval, mfa_required, mfa_hardware, ...",
                rule_type
            ),
            data: None,
        });
    }
    Ok(())
}

/// Formatea una fila de política como JSON de respuesta.
fn policy_row(row: &PolicyRow) -> Value {
    serde_json::json!({
        "policy_id":     row.policy_id,
        "policy_code":   row.policy_code,
        "policy_name":   row.policy_name,
        "description":   row.description,
        "domain":        row.domain,
        "config":        row.config,
        "rule_type":     row.config.get("rule"),
        "standard_ref":  row.standard_ref,
        "is_active":     row.is_active,
        "created_at":    row.created_at,
        "updated_at":    row.updated_at,
    })
}

// ── Estructura de fila ───────────────────────────────────────────

#[derive(sqlx::FromRow, serde::Serialize)]
struct PolicyRow {
    policy_id:    sqlx::types::Uuid,
    policy_code:  String,
    policy_name:  String,
    #[sqlx(default)]
    domain:       i32,
    description:  Option<String>,
    config:       serde_json::Value,
    standard_ref: Vec<String>,
    is_active:    bool,
    created_at:   chrono::DateTime<chrono::Utc>,
    updated_at:   chrono::DateTime<chrono::Utc>,
}

// ── bauth.policy.create ──────────────────────────────────────────
//
// Crea una nueva política en ath_policy_d{domain}.
// Params: domain (1-12), policy_code, policy_name, config (JSONB con "rule"),
//         description?, standard_ref? (string[])

pub struct PolicyCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })?
            as u8;
        check_domain(domain)?;

        let policy_code = params.get("policy_code").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "policy_code requerido".into(), data: None })?;
        check_policy_code(policy_code)?;

        let policy_name = params.get("policy_name").and_then(|v| v.as_str())
            .unwrap_or(policy_code);

        let description = params.get("description").and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let config = params.get("config").cloned()
            .unwrap_or_else(|| serde_json::json!({"rule": "scope"}));
        validate_config_structure(&config)?;

        // ── B9.T26: Detección de conflictos antes de persistir ──
        let conflict_warnings = check_conflicts_before_save(pg, policy_code, &config, domain).await?;

        let standard_ref: Vec<String> = params.get("standard_ref")
            .and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default();

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        let sql = format!(
            "INSERT INTO bauth.ath_policy_d{} (policy_code, policy_name, description, config, standard_ref, is_active, ctx_id) \
             VALUES ($1, $2, $3, $4, $5, true, $6) \
             ON CONFLICT (policy_code) DO UPDATE SET \
               policy_name = EXCLUDED.policy_name, \
               description = EXCLUDED.description, \
               config      = EXCLUDED.config, \
               standard_ref = EXCLUDED.standard_ref, \
               is_active   = true, \
               updated_at  = now(), \
               ctx_id      = EXCLUDED.ctx_id \
             RETURNING policy_id, policy_code, policy_name, description, config, standard_ref, is_active, created_at, updated_at",
            domain
        );

        let row: PolicyRow = sqlx::query_as(&sql)
            .bind(policy_code)
            .bind(policy_name)
            .bind(&description)
            .bind(&config)
            .bind(&standard_ref)
            .bind(ctx_id)
            .fetch_one(pg).await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error al crear política: {}", e),
                data: None,
            })?;

        // ── B9.T28: Auditoría WORM ──
        let changed_by = params.get("changed_by").and_then(|v| v.as_str()).unwrap_or("system");
        let reason     = params.get("reason").and_then(|v| v.as_str()).unwrap_or("creación de política");
        audit_policy_change(pg, policy_code, "CREATE", None, Some(&config), changed_by, reason, ctx_id).await;

        let mut result = policy_row(&row);
        if let Some(obj) = result.as_object_mut() {
            obj.insert("domain".into(), serde_json::json!(domain));
            if !conflict_warnings.is_empty() {
                obj.insert("conflict_warnings".into(), serde_json::json!(conflict_warnings));
            }
        }

        tracing::info!(policy_code, domain, "política creada/actualizada");
        Ok(result)
    }
}

// ── bauth.policy.update ──────────────────────────────────────────
//
// Actualiza una política existente en ath_policy_d{domain}.
// Búsqueda por policy_code. Solo actualiza campos provistos.

pub struct PolicyUpdateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })?
            as u8;
        check_domain(domain)?;

        let policy_code = params.get("policy_code").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "policy_code requerido".into(), data: None })?;
        check_policy_code(policy_code)?;

        // Validar config si se provee
        if let Some(config) = params.get("config") {
            validate_config_structure(config)?;
        }

        // Obtener valores actuales para merge
        let select_sql = format!(
            "SELECT policy_code, policy_name, description, config, standard_ref, is_active \
             FROM bauth.ath_policy_d{} WHERE policy_code = $1",
            domain
        );
        #[derive(sqlx::FromRow)]
        struct Current {
            policy_name:  String,
            description:  Option<String>,
            config:       serde_json::Value,
            standard_ref: Vec<String>,
            is_active:    bool,
        }
        let current: Current = sqlx::query_as(&select_sql)
            .bind(policy_code)
            .fetch_optional(pg).await
            .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?
            .ok_or_else(|| JsonRpcError {
                code: -32602,
                message: format!("política '{}' no encontrada en D{}", policy_code, domain),
                data: None,
            })?;

        let old_config      = current.config.clone(); // B9.T28: preservar para auditoría
        let new_name        = params.get("policy_name").and_then(|v| v.as_str()).unwrap_or(&current.policy_name);
        let new_description = params.get("description").and_then(|v| v.as_str()).map(|s| s.to_string()).or(current.description);
        let new_config      = params.get("config").cloned().unwrap_or(current.config);
        let new_standard    = params.get("standard_ref").and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or(current.standard_ref);
        let new_active      = params.get("is_active").and_then(|v| v.as_bool()).unwrap_or(current.is_active);
        let ctx_id          = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // ── B9.T26: Detección de conflictos antes de persistir ──
        let conflict_warnings = check_conflicts_before_save(pg, policy_code, &new_config, domain).await?;

        let update_sql = format!(
            "UPDATE bauth.ath_policy_d{} \
             SET policy_name = $2, description = $3, config = $4, standard_ref = $5, \
                 is_active = $6, ctx_id = $7, updated_at = now() \
             WHERE policy_code = $1 \
             RETURNING policy_id, policy_code, policy_name, description, config, standard_ref, is_active, created_at, updated_at",
            domain
        );

        let row: PolicyRow = sqlx::query_as(&update_sql)
            .bind(policy_code)
            .bind(new_name)
            .bind(&new_description)
            .bind(&new_config)
            .bind(&new_standard)
            .bind(new_active)
            .bind(ctx_id)
            .fetch_one(pg).await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error al actualizar política: {}", e),
                data: None,
            })?;

        // ── B9.T28: Auditoría WORM ──
        let changed_by = params.get("changed_by").and_then(|v| v.as_str()).unwrap_or("system");
        let reason     = params.get("reason").and_then(|v| v.as_str()).unwrap_or("actualización de política");
        audit_policy_change(pg, policy_code, "UPDATE", Some(&old_config), Some(&new_config), changed_by, reason, ctx_id).await;

        let mut result = policy_row(&row);
        if let Some(obj) = result.as_object_mut() {
            obj.insert("domain".into(), serde_json::json!(domain));
            if !conflict_warnings.is_empty() {
                obj.insert("conflict_warnings".into(), serde_json::json!(conflict_warnings));
            }
        }

        tracing::info!(policy_code, domain, "política actualizada");
        Ok(result)
    }
}

// ── bauth.policy.delete ──────────────────────────────────────────
//
// Soft-delete: marca is_active = false. NO elimina la fila.
// La política deja de cargarse en el PolicyEngine.

pub struct PolicyDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })?
            as u8;
        check_domain(domain)?;

        let policy_code = params.get("policy_code").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "policy_code requerido".into(), data: None })?;
        check_policy_code(policy_code)?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        let sql = format!(
            "UPDATE bauth.ath_policy_d{} \
             SET is_active = false, ctx_id = $2, updated_at = now() \
             WHERE policy_code = $1 AND is_active = true \
             RETURNING policy_id, policy_code, policy_name, description, config, standard_ref, is_active, created_at, updated_at",
            domain
        );

        let row: Option<PolicyRow> = sqlx::query_as(&sql)
            .bind(policy_code)
            .bind(ctx_id)
            .fetch_optional(pg).await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error al eliminar política: {}", e),
                data: None,
            })?;

        match row {
            Some(r) => {
                // ── B9.T28: Auditoría WORM ──
                let changed_by = params.get("changed_by").and_then(|v| v.as_str()).unwrap_or("system");
                let reason     = params.get("reason").and_then(|v| v.as_str()).unwrap_or("eliminación de política");
                audit_policy_change(pg, policy_code, "DELETE", Some(&r.config), None, changed_by, reason, ctx_id).await;

                tracing::info!(policy_code, domain, "política desactivada (soft-delete)");
                let mut result = policy_row(&r);
                if let Some(obj) = result.as_object_mut() {
                    obj.insert("domain".into(), serde_json::json!(domain));
                }
                Ok(result)
            }
            None => Err(JsonRpcError {
                code: -32602,
                message: format!("política '{}' no encontrada o ya inactiva en D{}", policy_code, domain),
                data: None,
            }),
        }
    }
}

// ── bauth.policy.validate ────────────────────────────────────────
//
// Dry-run: valida el config de una política sin persistir.
// Retorna el rule_type detectado y si la validación fue exitosa.
// Útil para Core UI antes de hacer create/update.

pub struct PolicyValidateHandler;

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyValidateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let config = params.get("config")
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "config requerido (JSONB con campo 'rule')".into(), data: None,
            })?;

        // Validar estructura del config
        let rule_type = config.get("rule")
            .and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "config debe contener campo 'rule' de tipo string".into(), data: None,
            })?;

        // Validar contra ath_converter (regla mapeada?)
        match validate_config_structure(config) {
            Ok(()) => {
                let warnings: Vec<String> = check_config_sanity(rule_type, config);
                Ok(serde_json::json!({
                    "valid": true,
                    "rule_type": rule_type,
                    "message": format!("config válido para rule_type '{}'", rule_type),
                    "warnings": warnings,
                }))
            }
            Err(e) => Ok(serde_json::json!({
                "valid": false,
                "rule_type": rule_type,
                "message": e.message,
                "warnings": serde_json::json!([]),
            })),
        }
    }
}

/// Sanity checks adicionales sobre el config.
/// Retorna warnings no bloqueantes.
fn check_config_sanity(rule_type: &str, config: &Value) -> Vec<String> {
    let mut warnings = Vec::new();

    match rule_type {
        "scope" => {
            if config.get("allowed").is_none() && config.get("level").is_none() {
                warnings.push("scope sin 'allowed' ni 'level' — usando default [BRANCH]".into());
            }
        }
        "dual_approval" | "daily_limit" | "monthly_limit" => {
            if config.get("threshold").is_none() && config.get("amount").is_none() {
                warnings.push(format!(
                    "{} sin 'threshold' ni 'amount' — el umbral será 0.0", rule_type
                ));
            }
        }
        "session_timeout" | "session_ttl" => {
            if config.get("max_seconds").is_none() {
                warnings.push(format!(
                    "{} sin 'max_seconds' — timeout será 0s (denegación inmediata)", rule_type
                ));
            }
        }
        "min_length" => {
            if let Some(v) = config.get("value").and_then(|v| v.as_i64()) {
                if v < 8 {
                    warnings.push(format!("min_length={} — NIST 800-63B exige ≥8 para AAL1", v));
                }
            } else {
                warnings.push("min_length sin 'value' — default 0".into());
            }
        }
        "reauth" | "continuous_verification" => {
            if config.get("interval_seconds").is_none() {
                warnings.push(format!("{} sin 'interval_seconds' — default 0s", rule_type));
            }
        }
        "velocity_check" => {
            if config.get("max_kmh").is_none() {
                warnings.push("velocity_check sin 'max_kmh' — default 0 km/h".into());
            }
        }
        _ => {}
    }

    // Chequeo genérico: prioridad fuera de rango
    if let Some(p) = config.get("priority").and_then(|v| v.as_i64()) {
        if p < 1 || p > 100 {
            warnings.push(format!("priority={} fuera de rango [1-100]", p));
        }
    }

    warnings
}

// ── bauth.policy.check_conflicts ───────────────────────────────────
//
// Dry-run: detecta conflictos entre una política propuesta y las existentes.
// No persiste nada. Útil para Core UI antes de create/update.
//
// Params: domain (1-12), policy_code, config
// Retorna: lista de conflictos con severidad y detalle.

pub struct PolicyCheckConflictsHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyCheckConflictsHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-12]".into(), data: None })?
            as u8;
        check_domain(domain)?;

        let policy_code = params.get("policy_code").and_then(|v| v.as_str()).unwrap_or("__new__");
        let config = params.get("config").cloned()
            .unwrap_or_else(|| serde_json::json!({"rule": "scope"}));

        let wars = check_conflicts_before_save(pg, policy_code, &config, domain).await?;

        let has_alto = wars.iter().any(|w| w.contains("ALTO"));
        Ok(serde_json::json!({
            "domain": domain,
            "policy_code": policy_code,
            "conflicts_found": wars.len(),
            "bloqueante": has_alto,
            "warnings": wars,
        }))
    }
}

// ── Helper: cargar políticas existentes y ejecutar detector ─────

// ── Auditoría WORM (B9.T28) ──────────────────────────────────────

/// Registra un cambio de política en aud_policy_change (ISO 27001 A.8.9).
/// No bloquea la operación si falla — la auditoría es best-effort.
async fn audit_policy_change(
    pg: &PgPool,
    policy_slug: &str,
    change_type: &str,
    old_params: Option<&Value>,
    new_params: Option<&Value>,
    changed_by: &str,
    reason: &str,
    ctx_id: &str,
) {
    let changed_by_uuid = uuid::Uuid::parse_str(changed_by).unwrap_or(uuid::Uuid::nil());
    let result = sqlx::query(
        "INSERT INTO bauth.aud_policy_change (policy_slug, change_type, old_params, new_params, changed_by, reason, ctx_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(policy_slug)
    .bind(change_type)
    .bind(old_params)
    .bind(new_params)
    .bind(changed_by_uuid)
    .bind(reason)
    .bind(ctx_id)
    .execute(pg).await;

    match result {
        Ok(_) => tracing::info!(%policy_slug, %change_type, "auditoría de política registrada"),
        Err(e) => tracing::warn!(%policy_slug, %change_type, error=%e, "fallo al registrar auditoría (no bloqueante)"),
    }
}

/// Carga políticas activas del dominio, ejecuta conflict::detect_conflicts,
/// y retorna warnings formateados. Si hay conflicto ALTO, retorna error.
async fn check_conflicts_before_save(
    pg: &PgPool,
    policy_code: &str,
    config: &Value,
    domain: u8,
) -> Result<Vec<String>, JsonRpcError> {
    let sql = format!(
        "SELECT policy_code, config FROM bauth.ath_policy_d{} WHERE is_active = true",
        domain
    );
    #[derive(sqlx::FromRow)]
    struct ExistingPolicy {
        policy_code: String,
        config: serde_json::Value,
    }

    let rows: Vec<ExistingPolicy> = sqlx::query_as(&sql)
        .fetch_all(pg).await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    let existing: Vec<(String, Value)> = rows.into_iter()
        .map(|r| (r.policy_code, r.config))
        .collect();

    let conflicts = conflict::detect_conflicts(policy_code, config, domain, &existing);

    let mut warnings = Vec::new();
    for c in &conflicts {
        let severity_tag = match c.severity {
            ConflictSeverity::Alto => "ALTO",
            ConflictSeverity::Medio => "MEDIO",
            ConflictSeverity::Bajo => "BAJO",
        };
        warnings.push(format!("[{}] {}: {}", severity_tag, c.field, c.detail));

        if c.severity == ConflictSeverity::Alto {
            return Err(JsonRpcError {
                code: -32003,
                message: format!(
                    "Conflicto ALTO detectado: {}. Use bauth.policy.check_conflicts para revisar.",
                    c.detail
                ),
                data: Some(serde_json::json!({
                    "conflicts": warnings,
                    "hint": "Corrija los conflictos ALTO antes de persistir. Los conflictos MEDIO requieren aprobación."
                })),
            });
        }
    }

    Ok(warnings)
}

// ── bauth.policy.list (CRUD — todos los dominios) ─────────────────
//
// Lista políticas de un dominio específico o de todos (1-12).
// Diferente de policy.domain.list: incluye políticas inactivas y
// retorna la fila completa (policy_id, created_at, updated_at, ctx_id).

pub struct PolicyListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64()).map(|d| d as u8);
        let include_inactive = params.get("include_inactive").and_then(|v| v.as_bool()).unwrap_or(false);

        let domains: Vec<u8> = match domain {
            Some(d) => { check_domain(d)?; vec![d] }
            None => (1..=12).collect(),
        };

        let mut all_policies: Vec<Value> = Vec::new();

        for d in &domains {
            let active_clause = if include_inactive { "" } else { "AND is_active = true" };
            let sql = format!(
                "SELECT policy_id, policy_code, policy_name, description, config, standard_ref, is_active, created_at, updated_at \
                 FROM bauth.ath_policy_d{} WHERE 1=1 {} ORDER BY policy_code",
                d, active_clause
            );

            let rows: Vec<PolicyRow> = sqlx::query_as(&sql)
                .bind(domain.map(|d| d as i32))
                .fetch_all(pg).await
                .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

            for row in rows {
                let mut entry = policy_row(&row);
                if let Some(obj) = entry.as_object_mut() {
                    obj.insert("domain".into(), serde_json::json!(d));
                }
                all_policies.push(entry);
            }
        }

        Ok(serde_json::json!({
            "total": all_policies.len(),
            "domains_queried": domains,
            "policies": all_policies,
        }))
    }
}

// ── bauth.policy.audit (B9.T28) ───────────────────────────────────
//
// Consulta el historial WORM de cambios de políticas (aud_policy_change).
// Filtrable por policy_slug, change_type. ISO 27001 A.8.9.

pub struct PolicyAuditHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyAuditHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let policy_slug = params.get("policy_slug").and_then(|v| v.as_str());
        let change_type = params.get("change_type").and_then(|v| v.as_str());
        let limit       = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50).min(200);

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct AuditRow {
            audit_id:    uuid::Uuid,
            policy_slug: String,
            change_type: String,
            old_params:  Option<serde_json::Value>,
            new_params:  Option<serde_json::Value>,
            changed_by:  uuid::Uuid,
            reason:      String,
            ctx_id:      String,
            changed_at:  chrono::DateTime<chrono::Utc>,
        }

        let rows: Vec<AuditRow> = sqlx::query_as(
            "SELECT audit_id, policy_slug, change_type, old_params, new_params,
                    changed_by, reason, ctx_id, changed_at
             FROM bauth.aud_policy_change
             WHERE ($1::text IS NULL OR policy_slug = $1)
               AND ($2::text IS NULL OR change_type = $2)
             ORDER BY changed_at DESC
             LIMIT $3"
        )
        .bind(policy_slug)
        .bind(change_type)
        .bind(limit)
        .fetch_all(pg).await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando auditoría: {}", e), data: None,
        })?;

        let entries: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "audit_id":    r.audit_id,
            "policy_slug": r.policy_slug,
            "change_type": r.change_type,
            "old_params":  r.old_params,
            "new_params":  r.new_params,
            "changed_by":  r.changed_by,
            "reason":      r.reason,
            "ctx_id":      r.ctx_id,
            "changed_at":  r.changed_at.to_rfc3339(),
        })).collect();

        Ok(serde_json::json!({
            "total": entries.len(),
            "filters": {
                "policy_slug": policy_slug,
                "change_type": change_type,
            },
            "entries": entries,
            "worm": true,
            "standard": "ISO 27001:2022 A.8.9",
        }))
    }
}
