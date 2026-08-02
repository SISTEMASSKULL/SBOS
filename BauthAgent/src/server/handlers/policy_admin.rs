// ============================================================
// bauth::server::handlers::policy_admin — B9.T25-T28 PolicyAdministrator
//
// Administración de políticas de autenticación.
//
// Tabla canónica DDL v2.12.0:
//   bauth.auth_policy — tabla unificada de políticas (reemplaza ath_policy_d1..12)
//
// D01 eliminado: ath_policy_d{N} no existe en DDL v2.12.0.
//   La tabla auth_policy NO tiene columna domain — las políticas aplican
//   por tenant y por nivel de garantía (loa_required), no por dominio.
// D02 eliminado: aud_policy_change no existe en DDL v2.12.0.
//
// Handlers:
//   bauth.policy.create           — crear política
//   bauth.policy.update           — actualizar campos
//   bauth.policy.delete           — desactivar política
//   bauth.policy.validate         — validar parámetros sin persistir
//   bauth.policy.list             — listar con filtros
//   bauth.policy.check_conflicts  — detectar conflictos entre políticas
//   bauth.policy.audit            — historial de cambios (ses_caep_event_log)
//
// DOC-SBOS-001 N3 · NIST SP 800-63B-4 · NIST SP 800-207
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

/// Niveles de garantía válidos (NIST SP 800-63B).
const LOA_VALIDOS: &[&str] = &["AAL1", "AAL2", "AAL3"];

/// Obtiene el PgPool desde un Option<PgPool> o retorna error.
fn pg_req(opt: &Option<PgPool>) -> Result<&PgPool, JsonRpcError> {
    opt.as_ref().ok_or_else(|| err("base de datos no disponible"))
}

/// Valida que el nivel de garantía sea uno de los valores canónicos.
fn validar_loa(loa: &str) -> Result<(), JsonRpcError> {
    if LOA_VALIDOS.contains(&loa) {
        Ok(())
    } else {
        Err(err(&format!("loa_required inválido: '{}'. Válidos: AAL1, AAL2, AAL3", loa)))
    }
}

// ── T25a: Policy Create ────────────────────────────────

/// Handler: bauth.policy.create
/// Crea una política de autenticación en auth_policy.
pub struct PolicyCreateHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let name = params.get("name").and_then(|v| v.as_str())
            .ok_or_else(|| err("name requerido"))?;
        let description = params.get("description").and_then(|v| v.as_str()).unwrap_or("");
        let loa = params.get("loa_required").and_then(|v| v.as_str()).unwrap_or("AAL1");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");
        let max_session = params.get("max_session_secs").and_then(|v| v.as_i64());

        validar_loa(loa)?;

        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("tenant_uuid inválido")))
            .transpose()?;

        let allowed: Vec<String> = params.get("allowed_methods")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|m| m.as_str().map(String::from)).collect())
            .unwrap_or_default();

        let required: Vec<String> = params.get("required_methods")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|m| m.as_str().map(String::from)).collect())
            .unwrap_or_default();

        let step_up = params.get("step_up_trigger").cloned().unwrap_or(Value::Null);
        let policy_id = uuid::Uuid::now_v7();

        sqlx::query(
            "INSERT INTO bauth.auth_policy
                (policy_id, tenant_id, name, description, loa_required,
                 allowed_methods, required_methods, max_session_secs,
                 step_up_trigger, active, ctx_id)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE, $10)"
        )
        .bind(policy_id)
        .bind(tenant_id)
        .bind(name)
        .bind(description)
        .bind(loa)
        .bind(&allowed)
        .bind(&required)
        .bind(max_session)
        .bind(step_up)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%policy_id, %name, loa, "policy.create — OK");
        Ok(json!({"policy_id": policy_id.to_string(), "status": "created"}))
    }
}

// ── T25b: Policy Update ───────────────────────────────

/// Handler: bauth.policy.update
/// Actualiza campos de una política (PATCH semántico).
pub struct PolicyUpdateHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let policy_id_str = params.get("policy_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("policy_id requerido"))?;
        let policy_id = uuid::Uuid::parse_str(policy_id_str)
            .map_err(|_| err("policy_id inválido"))?;

        let loa = params.get("loa_required").and_then(|v| v.as_str());
        if let Some(l) = loa { validar_loa(l)?; }

        let name        = params.get("name").and_then(|v| v.as_str());
        let description = params.get("description").and_then(|v| v.as_str());
        let max_session = params.get("max_session_secs").and_then(|v| v.as_i64());
        let ctx_id      = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        sqlx::query(
            "UPDATE bauth.auth_policy SET
                name             = COALESCE($2, name),
                description      = COALESCE($3, description),
                loa_required     = COALESCE($4, loa_required),
                max_session_secs = COALESCE($5, max_session_secs),
                ctx_id           = $6
             WHERE policy_id = $1"
        )
        .bind(policy_id)
        .bind(name)
        .bind(description)
        .bind(loa)
        .bind(max_session)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%policy_id, "policy.update — OK");
        Ok(json!({"status": "updated", "policy_id": policy_id_str}))
    }
}

// ── T25c: Policy Delete (desactivar) ──────────────────

/// Handler: bauth.policy.delete
/// Desactiva una política (active = FALSE). No elimina el registro.
pub struct PolicyDeleteHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let policy_id_str = params.get("policy_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("policy_id requerido"))?;
        let policy_id = uuid::Uuid::parse_str(policy_id_str)
            .map_err(|_| err("policy_id inválido"))?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        sqlx::query(
            "UPDATE bauth.auth_policy SET active = FALSE, ctx_id = $2 WHERE policy_id = $1"
        )
        .bind(policy_id)
        .bind(ctx_id)
        .execute(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        tracing::info!(%policy_id, "policy.delete — desactivada OK");
        Ok(json!({"status": "deleted", "policy_id": policy_id_str}))
    }
}

// ── T25d: Policy Validate (sin persistir) ─────────────

/// Handler: bauth.policy.validate
/// Valida los parámetros de una política sin persistirla en BD.
pub struct PolicyValidateHandler;

#[async_trait]
impl JsonRpcHandler for PolicyValidateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let mut errores: Vec<String> = Vec::new();

        if params.get("name").and_then(|v| v.as_str()).is_none() {
            errores.push("name requerido".into());
        }

        if let Some(loa) = params.get("loa_required").and_then(|v| v.as_str()) {
            if !LOA_VALIDOS.contains(&loa) {
                errores.push(format!("loa_required inválido: '{}'", loa));
            }
        }

        if errores.is_empty() {
            Ok(json!({"valid": true, "errors": []}))
        } else {
            Ok(json!({"valid": false, "errors": errores}))
        }
    }
}

// ── T25e: Policy List ─────────────────────────────────

/// Handler: bauth.policy.list
/// Lista políticas activas. Filtros: tenant_uuid, loa_required.
pub struct PolicyListHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("tenant_uuid inválido")))
            .transpose()?;
        let loa_filter = params.get("loa_required").and_then(|v| v.as_str());

        #[derive(sqlx::FromRow)]
        struct PolicyRow {
            policy_id:        uuid::Uuid,
            tenant_id:        Option<uuid::Uuid>,
            name:             String,
            description:      Option<String>,
            loa_required:     String,
            allowed_methods:  Vec<String>,
            required_methods: Vec<String>,
            max_session_secs: Option<i32>,
            active:           bool,
        }

        let rows: Vec<PolicyRow> = sqlx::query_as(
            "SELECT policy_id, tenant_id, name, description, loa_required,
                    allowed_methods, required_methods, max_session_secs, active
             FROM bauth.auth_policy
             WHERE active = TRUE
               AND ($1::uuid IS NULL OR tenant_id = $1)
               AND ($2::text IS NULL OR loa_required = $2)
             ORDER BY name"
        )
        .bind(tenant_id)
        .bind(loa_filter)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let total = rows.len();
        let items: Vec<Value> = rows.into_iter().map(|r| json!({
            "policy_id":       r.policy_id.to_string(),
            "tenant_id":       r.tenant_id.map(|t| t.to_string()),
            "name":            r.name,
            "description":     r.description,
            "loa_required":    r.loa_required,
            "allowed_methods": r.allowed_methods,
            "required_methods": r.required_methods,
            "max_session_secs": r.max_session_secs,
            "active":          r.active,
        })).collect();

        Ok(json!({"policies": items, "total": total}))
    }
}

// ── T26: Policy Check Conflicts ───────────────────────

/// Handler: bauth.policy.check_conflicts
/// Detecta políticas con configuraciones en conflicto para un tenant.
pub struct PolicyCheckConflictsHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyCheckConflictsHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let tenant_id = params.get("tenant_uuid").and_then(|v| v.as_str())
            .map(|s| uuid::Uuid::parse_str(s).map_err(|_| err("tenant_uuid inválido")))
            .transpose()?;

        // Detectar múltiples políticas activas con el mismo loa_required para un tenant
        let conflictos: Vec<(String, i64)> = sqlx::query_as(
            "SELECT loa_required, count(*) AS cnt
             FROM bauth.auth_policy
             WHERE active = TRUE
               AND ($1::uuid IS NULL OR tenant_id = $1)
             GROUP BY loa_required
             HAVING count(*) > 1
             ORDER BY loa_required"
        )
        .bind(tenant_id)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let hay_conflicto = !conflictos.is_empty();
        let detalles: Vec<Value> = conflictos.into_iter().map(|(loa, cnt)| {
            json!({"loa_required": loa, "policies": cnt, "conflict": "duplicate_loa"})
        }).collect();

        Ok(json!({
            "has_conflicts": hay_conflicto,
            "conflicts":     detalles,
        }))
    }
}

// ── T28: Policy Audit Trail ───────────────────────────

/// Handler: bauth.policy.audit
/// Devuelve eventos CAEP relacionados con políticas desde ses_caep_event_log.
pub struct PolicyAuditHandler { pub pg_pool: Option<PgPool> }

#[async_trait]
impl JsonRpcHandler for PolicyAuditHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = pg_req(&self.pg_pool)?;

        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        let events: Vec<(uuid::Uuid, String, String, String, chrono::DateTime<chrono::Utc>)> =
            sqlx::query_as(
                "SELECT event_id, event_type, subject_id, transmitter_id, created_at
                 FROM bauth.ses_caep_event_log
                 WHERE event_type LIKE 'policy-%'
                 ORDER BY created_at DESC
                 LIMIT $1"
            )
            .bind(limit)
            .fetch_all(pg)
            .await
            .unwrap_or_default();

        let items: Vec<Value> = events.into_iter().map(|(eid, etype, sid, tx, ts)| json!({
            "event_id":      eid.to_string(),
            "event_type":    etype,
            "subject_id":    sid,
            "transmitter":   tx,
            "created_at":    ts.to_rfc3339(),
        })).collect();

        Ok(json!({"events": items, "total": items.len()}))
    }
}
