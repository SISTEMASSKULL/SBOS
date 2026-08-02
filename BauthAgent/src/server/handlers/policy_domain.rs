// ============================================================
// bauth::server::handlers::policy_domain — B9.T24 PolicyEngine operativo
//
// Handlers JSON-RPC:
//   bauth.policy.domain.evaluate  — evalúa políticas vs contexto (usa cfg_policy_library)
//   bauth.policy.domain.list      — lista políticas en auth_policy (con filtro opcional)
//   bauth.policy.library.search   — busca en cfg_policy_library (9,142 entradas)
//
// D01 eliminado: ath_policy_d{N} no existe en DDL v2.12.0.
//   PolicyDomainListHandler usa auth_policy (tabla unificada).
//
// Motor de evaluación: PolicyEngine::evaluate() (XACML 3.0 / NIST ABAC).
// ath_loader::load_domain() carga desde cfg_policy_library (correcto).
// ============================================================

#![allow(dead_code)]
use crate::domain::policy::{ath_loader, evaluate};
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::collections::HashMap;

// ── bauth.policy.domain.evaluate ────────────────────────────

pub struct PolicyDomainEvalHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyDomainEvalHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let domain = params.get("domain").and_then(|v| v.as_u64())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "domain requerido [1-15]".into(), data: None })?
            as u8;

        // Contexto de evaluación: mapa de valores runtime del caller
        let ctx: HashMap<String, Value> = params.get("context")
            .and_then(|v| v.as_object())
            .map(|o| o.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
            .unwrap_or_default();

        // ath_loader::load_domain lee desde cfg_policy_library (canónico)
        let rules = ath_loader::load_domain(pg, domain).await;

        if rules.is_empty() {
            return Ok(serde_json::json!({
                "domain":    domain,
                "evaluated": 0,
                "state":     "aprobado",
                "message":   "sin políticas activas para este dominio"
            }));
        }

        let t0 = std::time::Instant::now();
        let (allowed, state, results) = evaluate::evaluate(&rules, &ctx);
        let elapsed_us = t0.elapsed().as_micros();

        let state_str = match state {
            crate::bitmask::PolicyState::Aprobado  => "aprobado",
            crate::bitmask::PolicyState::Rechazado => "rechazado",
            crate::bitmask::PolicyState::Pendiente => "pendiente",
            _                                       => "no_aplica",
        };

        let detail: Vec<Value> = results.iter().map(|r| serde_json::json!({
            "policy":         r.slug,
            "action":         r.action,
            "conditions_met": r.conditions_met,
            "state":          format!("{:?}", r.state),
            "message":        r.message,
        })).collect();

        let passed  = results.iter().filter(|r| matches!(r.state, crate::bitmask::PolicyState::Aprobado)).count();
        let failed  = results.iter().filter(|r| matches!(r.state, crate::bitmask::PolicyState::Rechazado)).count();
        let pending = results.iter().filter(|r| matches!(r.state, crate::bitmask::PolicyState::Pendiente)).count();

        Ok(serde_json::json!({
            "domain":     domain,
            "allowed":    allowed,
            "state":      state_str,
            "evaluated":  results.len(),
            "passed":     passed,
            "failed":     failed,
            "pending":    pending,
            "latency_us": elapsed_us,
            "results":    detail,
        }))
    }
}

// ── bauth.policy.domain.list ────────────────────────────────

/// Lista políticas desde auth_policy con filtro opcional por loa_required.
/// El parámetro `domain` es aceptado por compatibilidad pero ignorado:
/// auth_policy no tiene columna domain (DDL v2.12.0).
pub struct PolicyDomainListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyDomainListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let loa_filter = params.get("loa_required").and_then(|v| v.as_str());
        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).ok())
            .flatten();

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row {
            policy_id:        uuid::Uuid,
            name:             String,
            description:      Option<String>,
            loa_required:     String,
            allowed_methods:  Vec<String>,
            required_methods: Vec<String>,
            active:           bool,
        }

        let rows: Vec<Row> = sqlx::query_as(
            "SELECT policy_id, name, description, loa_required,
                    allowed_methods, required_methods, active
             FROM bauth.auth_policy
             WHERE active = TRUE
               AND ($1::text IS NULL OR loa_required = $1)
               AND ($2::uuid IS NULL OR tenant_id = $2)
             ORDER BY name"
        )
        .bind(loa_filter)
        .bind(tenant_id)
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        let entries: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "policy_id":      r.policy_id.to_string(),
            "name":           r.name,
            "description":    r.description,
            "loa_required":   r.loa_required,
            "allowed_methods": r.allowed_methods,
            "required_methods": r.required_methods,
            "is_active":      r.active,
        })).collect();

        Ok(serde_json::json!({
            "count":    entries.len(),
            "policies": entries,
        }))
    }
}

// ── bauth.policy.library.search ─────────────────────────────

/// Busca en cfg_policy_library (tabla canónica — sin cambios).
pub struct PolicyLibrarySearchHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for PolicyLibrarySearchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let source      = params.get("source").and_then(|v| v.as_str());
        let domain      = params.get("domain").and_then(|v| v.as_str());
        let semantic    = params.get("semantic_type").and_then(|v| v.as_str());
        let enforcement = params.get("enforcement").and_then(|v| v.as_str());
        let limit       = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20).min(100);

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row {
            section_id:      i32,
            section_name:    String,
            json_path:       String,
            source:          String,
            node_type:       String,
            semantic_type:   Option<String>,
            enforcement:     Option<String>,
            risk_level:      Option<String>,
            assurance_level: Option<String>,
        }

        let rows: Vec<Row> = sqlx::query_as(
            "SELECT section_id, section_name, json_path, source, node_type,
                    semantic_type, enforcement, risk_level, assurance_level
             FROM bauth.cfg_policy_library
             WHERE ($1::text IS NULL OR source = $1)
               AND ($2::text IS NULL OR $2 = ANY(domain_map))
               AND ($3::text IS NULL OR semantic_type = $3)
               AND ($4::text IS NULL OR enforcement = $4)
             ORDER BY source, json_path
             LIMIT $5"
        )
        .bind(source).bind(domain).bind(semantic).bind(enforcement).bind(limit)
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

        Ok(serde_json::json!({
            "count":         rows.len(),
            "total_library": 9142,
            "entries":       rows,
        }))
    }
}
