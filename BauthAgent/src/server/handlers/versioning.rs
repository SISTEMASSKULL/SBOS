// ============================================================
// bauth::server::handlers::versioning — B01 + B02 + Motor JSON-RPC
//
// Métodos de bajo nivel (escritura directa WORM):
//   bauth.role.version.record    — cierra una versión → T-152
//   bauth.role.version.history   — historial de versiones de un rol
//   bauth.role.lifecycle.record  — registra cambio de estado → T-B02L
//   bauth.role.lifecycle.history — historial de ciclo de vida de un rol
//
// Métodos de alto nivel (transición atómica 9 pasos, 1.13 §9.3):
//   bauth.version.propose        — aplica cambio; MAJOR → B03 quórum
//   bauth.version.as_of          — reconstruye estado de un rol en el tiempo
//   bauth.version.by_standard    — cambios por referencia normativa (auditor)
//   bauth.version.rollback       — propone rollback como cambio MAJOR
//   bauth.version.retention_status — estado retención T-154 de una entidad
//
// DOC-SBOS-001 N3 · NIST SP 800-53 AU-9 · ISO 27001:2022 A.8.15
// ============================================================

use crate::db::versioning::{NuevoEventoLifecycle, NuevoSnapshotAuditoria, registrar_evento_lifecycle, registrar_snapshot_auditoria};
use crate::db::version_store::{self, CambioRol, ResultadoCambio};
use crate::domain::versioning::{ChangeChannel, ChangeType, RolStatusDb, TriggerType};
use crate::domain::versioning::audit::{CambioResumen, validar_o_error};
use crate::domain::versioning::blocks::MapaBloques;
use crate::domain::versioning::policy::ConfigB3;
use crate::domain::versioning::transitions::validar_transicion;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use crate::sync::retention;
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

fn err_server(msg: String) -> JsonRpcError {
    JsonRpcError { code: -32000, message: msg, data: None }
}

fn parse_uuid(params: &Value, campo: &str) -> Result<Uuid, JsonRpcError> {
    let s = params.get(campo).and_then(|v| v.as_str())
        .ok_or_else(|| err(&format!("{campo} requerido (UUID)")))?;
    Uuid::parse_str(s).map_err(|_| err(&format!("{campo} no es un UUID válido: '{s}'")))
}

fn parse_datetime(params: &Value, campo: &str) -> Result<chrono::DateTime<chrono::Utc>, JsonRpcError> {
    let s = params.get(campo).and_then(|v| v.as_str())
        .ok_or_else(|| err(&format!("{campo} requerido (RFC3339)")))?;
    chrono::DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&chrono::Utc))
        .map_err(|_| err(&format!("{campo} no es RFC3339 válido: '{s}'")))
}

fn parse_str_vec(params: &Value, campo: &str) -> Vec<String> {
    params.get(campo)
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default()
}

// ── bauth.role.version.record ────────────────────────────────

/// Cierra una versión de rol y escribe el snapshot en T-152.
///
/// Parámetros obligatorios:
/// - `entity_id` UUID — FK a idn_roles_rol_hierarchical(id)
/// - `sys_period_inicio` RFC3339 — inicio del período cerrado
/// - `sys_period_fin` RFC3339 — fin del período cerrado (no puede ser infinity)
/// - `version_number` int — número de versión secuencial (≥ 0)
/// - `template_version` string — ej: "v6.0"
/// - `change_type` string — "MAJOR" | "MINOR" | "PATCH"
/// - `change_channel` string — "API" | "CLI" | "BOOTSTRAP" | "RECONCILE"
/// - `ctx_id` string — context ID de la operación (SBOS-049)
///
/// Parámetros opcionales:
/// - `blocks_touched` string[] — bloques B01-B10 modificados
/// - `standard_ref` string[] — referencias normativas
/// - `fields_changed` object — {"campo": {"antes": X, "despues": Y}}
/// - `snapshot` object — estado completo (obligatorio si is_anchor=true o change_type=MAJOR)
/// - `is_anchor` bool — si es anchor de versión major (default: false)
/// - `change_reason` string — razón del cambio (obligatoria si MAJOR)
/// - `changed_by` UUID — autor del cambio
/// - `approved_by` UUID — aprobador
/// - `approved_at` RFC3339 — timestamp de aprobación
pub struct VersionRecordHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VersionRecordHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_id = parse_uuid(&params, "entity_id")?;
        let sys_period_inicio = parse_datetime(&params, "sys_period_inicio")?;
        let sys_period_fin = parse_datetime(&params, "sys_period_fin")?;

        let version_number = params.get("version_number").and_then(|v| v.as_i64())
            .ok_or_else(|| err("version_number requerido (int ≥ 0)"))? as i32;

        let template_version = params.get("template_version").and_then(|v| v.as_str())
            .unwrap_or("v6.0").to_string();

        let change_type: ChangeType = params.get("change_type").and_then(|v| v.as_str())
            .ok_or_else(|| err("change_type requerido: MAJOR | MINOR | PATCH"))
            .and_then(|s| match s {
                "MAJOR" => Ok(ChangeType::Major),
                "MINOR" => Ok(ChangeType::Minor),
                "PATCH" => Ok(ChangeType::Patch),
                _ => Err(err("change_type inválido: debe ser MAJOR, MINOR o PATCH")),
            })?;

        let change_channel: ChangeChannel = params.get("change_channel").and_then(|v| v.as_str())
            .ok_or_else(|| err("change_channel requerido: API | CLI | BOOTSTRAP | RECONCILE"))
            .and_then(|s| match s {
                "API"       => Ok(ChangeChannel::Api),
                "CLI"       => Ok(ChangeChannel::Cli),
                "BOOTSTRAP" => Ok(ChangeChannel::Bootstrap),
                "RECONCILE" => Ok(ChangeChannel::Reconcile),
                _ => Err(err("change_channel inválido")),
            })?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido (SBOS-049)"))?.to_string();

        let is_anchor = params.get("is_anchor").and_then(|v| v.as_bool()).unwrap_or(false);
        let change_reason = params.get("change_reason").and_then(|v| v.as_str()).map(String::from);
        let snapshot = params.get("snapshot").cloned();
        let blocks_touched = parse_str_vec(&params, "blocks_touched");
        let standard_ref = parse_str_vec(&params, "standard_ref");
        let fields_changed = params.get("fields_changed").cloned().unwrap_or_else(|| json!({}));
        let changed_by = params.get("changed_by").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let approved_by = params.get("approved_by").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let approved_at = params.get("approved_at").and_then(|v| v.as_str())
            .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
            .map(|dt| dt.with_timezone(&chrono::Utc));

        // Validar precondiciones MAJOR antes de tocar la BD
        let resumen = CambioResumen {
            change_type,
            change_reason: change_reason.as_deref(),
            is_anchor,
            snapshot: snapshot.as_ref(),
            sys_period_valido: sys_period_fin > sys_period_inicio,
        };
        validar_o_error(&resumen).map_err(|e| err(&e.to_string()))?;

        let snap = NuevoSnapshotAuditoria {
            entity_id,
            sys_period_inicio,
            sys_period_fin,
            version_number,
            template_version,
            blocks_touched,
            standard_ref,
            fields_changed,
            snapshot,
            is_anchor,
            change_type,
            change_reason,
            change_channel,
            changed_by,
            approved_by,
            approved_at,
            ctx_id: ctx_id.clone(),
        };

        let id = registrar_snapshot_auditoria(&self.pg, &snap).await
            .map_err(|e| err_server(format!("error al registrar versión: {e}")))?;

        tracing::info!(%entity_id, %change_type, %ctx_id, "version.record — snapshot T-152 registrado");
        Ok(json!({
            "id":           id,
            "entity_id":    entity_id,
            "change_type":  change_type.as_str(),
            "version_number": snap.version_number,
            "is_anchor":    snap.is_anchor,
        }))
    }
}
impl VersionRecordHandler { pub fn method() -> &'static str { "bauth.role.version.record" } }

// ── bauth.role.version.history ───────────────────────────────

/// Lee el historial de versiones de un rol desde T-152.
///
/// Parámetros: `entity_id` UUID, `limit` int (default 20, máx 100).
pub struct VersionHistoryHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VersionHistoryHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_id = parse_uuid(&params, "entity_id")?;
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20).min(100);

        let rows: Vec<(Uuid, i32, String, String, String, chrono::DateTime<chrono::Utc>)> =
            sqlx::query_as(
                r#"
                SELECT id, version_number, change_type::text, template_version,
                       change_channel::text, lower(sys_period) as recorded_at
                FROM bauth.idn_roles_ver_b01_audit_log
                WHERE entity_id = $1
                ORDER BY version_number DESC
                LIMIT $2
                "#,
            )
            .bind(entity_id)
            .bind(limit)
            .fetch_all(&self.pg)
            .await
            .map_err(|e| err_server(e.to_string()))?;

        let items: Vec<Value> = rows.into_iter().map(|(id, ver, ct, tv, ch, at)| json!({
            "id": id,
            "version_number": ver,
            "change_type": ct,
            "template_version": tv,
            "channel": ch,
            "recorded_at": at.to_rfc3339(),
        })).collect();

        Ok(json!({"entity_id": entity_id, "count": items.len(), "versions": items}))
    }
}
impl VersionHistoryHandler { pub fn method() -> &'static str { "bauth.role.version.history" } }

// ── bauth.role.lifecycle.record ──────────────────────────────

/// Registra un evento de cambio de estado en T-B02L.
///
/// Parámetros obligatorios:
/// - `role_id` UUID — FK a idn_roles_rol_hierarchical(id)
/// - `to_status` string — estado destino (ACTIVE|INACTIVE|SUSPENDED|DEPRECATED|ARCHIVED|IN_REVIEW)
/// - `trigger_type` string — MANUAL|AUTO_EXPIRY|RECONCILE|IGA_REVIEW|BREAKGLASS|BOOTSTRAP
/// - `ctx_id` string — context ID (SBOS-049)
///
/// Parámetros opcionales:
/// - `from_status` string — estado origen (None = creación inicial)
/// - `actor_id` UUID — actor humano o servicio
/// - `reason` string — motivo del cambio
/// - `validity_snapshot` object — snapshot de campos de vigencia
pub struct LifecycleRecordHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for LifecycleRecordHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id = parse_uuid(&params, "role_id")?;

        let to_status: RolStatusDb = params.get("to_status").and_then(|v| v.as_str())
            .ok_or_else(|| err("to_status requerido"))?
            .parse()
            .map_err(|e: crate::domain::versioning::VersioningError| err(&e.to_string()))?;

        let from_status: Option<RolStatusDb> = params.get("from_status")
            .and_then(|v| v.as_str())
            .map(|s| s.parse())
            .transpose()
            .map_err(|e: crate::domain::versioning::VersioningError| err(&e.to_string()))?;

        // Si hay from_status, validar que la transición esté permitida
        if let Some(ref desde) = from_status {
            validar_transicion(*desde, to_status)
                .map_err(|e| err(&e.to_string()))?;
        }

        let trigger_type: TriggerType = params.get("trigger_type").and_then(|v| v.as_str())
            .ok_or_else(|| err("trigger_type requerido: MANUAL|AUTO_EXPIRY|RECONCILE|IGA_REVIEW|BREAKGLASS|BOOTSTRAP"))
            .and_then(|s| match s {
                "MANUAL"      => Ok(TriggerType::Manual),
                "AUTO_EXPIRY" => Ok(TriggerType::AutoExpiry),
                "RECONCILE"   => Ok(TriggerType::Reconcile),
                "IGA_REVIEW"  => Ok(TriggerType::IgaReview),
                "BREAKGLASS"  => Ok(TriggerType::Breakglass),
                "BOOTSTRAP"   => Ok(TriggerType::Bootstrap),
                _ => Err(err("trigger_type inválido")),
            })?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido (SBOS-049)"))?.to_string();

        let actor_id = params.get("actor_id").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let reason = params.get("reason").and_then(|v| v.as_str()).map(String::from);
        let validity_snapshot = params.get("validity_snapshot").cloned();

        let ev = NuevoEventoLifecycle {
            role_id,
            from_status,
            to_status,
            trigger_type,
            actor_id,
            reason,
            validity_snapshot,
            ctx_id: ctx_id.clone(),
        };

        let id = registrar_evento_lifecycle(&self.pg, &ev).await
            .map_err(|e| err_server(format!("error al registrar evento: {e}")))?;

        tracing::info!(%role_id, ?to_status, %ctx_id, "lifecycle.record — evento T-B02L registrado");
        Ok(json!({
            "id":           id,
            "role_id":      role_id,
            "from_status":  from_status.map(|s| s.as_str()),
            "to_status":    to_status.as_str(),
            "trigger_type": trigger_type.as_str(),
        }))
    }
}
impl LifecycleRecordHandler { pub fn method() -> &'static str { "bauth.role.lifecycle.record" } }

// ── bauth.role.lifecycle.history ────────────────────────────

/// Lee el historial de eventos de ciclo de vida de un rol desde T-B02L.
///
/// Parámetros: `role_id` UUID, `limit` int (default 20, máx 100).
pub struct LifecycleHistoryHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for LifecycleHistoryHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id = parse_uuid(&params, "role_id")?;
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20).min(100);

        let rows: Vec<(Uuid, Option<String>, String, String, chrono::DateTime<chrono::Utc>)> =
            sqlx::query_as(
                r#"
                SELECT id, from_status::text, to_status::text,
                       trigger_type, occurred_at
                FROM bauth.idn_roles_rol_lifecycle_event
                WHERE role_id = $1
                ORDER BY occurred_at DESC
                LIMIT $2
                "#,
            )
            .bind(role_id)
            .bind(limit)
            .fetch_all(&self.pg)
            .await
            .map_err(|e| err_server(e.to_string()))?;

        let items: Vec<Value> = rows.into_iter().map(|(id, from, to, trigger, at)| json!({
            "id":           id,
            "from_status":  from,
            "to_status":    to,
            "trigger_type": trigger,
            "occurred_at":  at.to_rfc3339(),
        })).collect();

        Ok(json!({"role_id": role_id, "count": items.len(), "events": items}))
    }
}
impl LifecycleHistoryHandler { pub fn method() -> &'static str { "bauth.role.lifecycle.history" } }

// ── bauth.version.propose ────────────────────────────────────

/// Aplica un cambio de versión a un rol mediante la transición atómica de 9 pasos.
///
/// Parámetros:
/// - `role_id`       UUID — rol a modificar (T-041)
/// - `campos_nuevos` object — solo los campos que cambian (whitelist en blocks_map.toml)
/// - `bump_declarado` string — nueva versión "X.Y.Z"
/// - `change_reason` string — obligatoria para MAJOR
/// - `change_channel` string — API | CLI | BOOTSTRAP | RECONCILE
/// - `changed_by`    UUID — actor (obligatorio si MAJOR)
/// - `ctx_id`        string — context ID SBOS-049
pub struct VersionProposeHandler {
    pub pg: PgPool,
    pub mapa: Arc<MapaBloques>,
    pub b3: Arc<ConfigB3>,
}

#[async_trait]
impl JsonRpcHandler for VersionProposeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id = parse_uuid(&params, "role_id")?;
        let campos_nuevos = params.get("campos_nuevos").cloned()
            .ok_or_else(|| err("campos_nuevos requerido (object)"))?;
        let bump_declarado = params.get("bump_declarado").and_then(|v| v.as_str())
            .ok_or_else(|| err("bump_declarado requerido (ej: '2.0.0')"))?.to_string();
        let change_reason = params.get("change_reason").and_then(|v| v.as_str()).map(String::from);
        let change_channel = parse_change_channel(&params)?;
        let changed_by = params.get("changed_by").and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido (SBOS-049)"))?.to_string();

        let cambio = CambioRol { role_id, campos_nuevos, bump_declarado, change_reason,
            change_channel, changed_by, ctx_id: ctx_id.clone() };

        let resultado = version_store::aplicar_cambio(&self.pg, &self.mapa, &self.b3, &cambio)
            .await
            .map_err(|e| err_server(format!("error al aplicar cambio: {e}")))?;

        tracing::info!(%role_id, %ctx_id, "version.propose — cambio procesado");
        match resultado {
            ResultadoCambio::Aplicado { nueva_version } => Ok(json!({
                "estado": "APLICADO",
                "role_id": role_id,
                "nueva_version": nueva_version,
            })),
            ResultadoCambio::EnRevision { proposal_id } => Ok(json!({
                "estado": "EN_REVISION",
                "role_id": role_id,
                "proposal_id": proposal_id,
                "mensaje": "cambio MAJOR encolado en T-153; requiere quórum de aprobación",
            })),
        }
    }
}
impl VersionProposeHandler { pub fn method() -> &'static str { "bauth.version.propose" } }

// ── bauth.version.as_of ──────────────────────────────────────

/// Reconstruye el snapshot de un rol en un punto en el tiempo.
///
/// Parámetros: `entity_id` UUID, `at` RFC3339 — punto en el tiempo.
pub struct VersionAsOfHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VersionAsOfHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_id = parse_uuid(&params, "entity_id")?;
        let at = parse_datetime(&params, "at")?;

        let resultado = version_store::as_of(&self.pg, entity_id, at)
            .await
            .map_err(|e| err_server(format!("error en as_of: {e}")))?;

        match resultado {
            Some(snap) => Ok(snap),
            None => Ok(json!({"entity_id": entity_id, "snapshot": null,
                "mensaje": "no hay snapshot disponible para ese punto en el tiempo"})),
        }
    }
}
impl VersionAsOfHandler { pub fn method() -> &'static str { "bauth.version.as_of" } }

// ── bauth.version.by_standard ────────────────────────────────

/// Lista cambios que afectan una referencia normativa en un período.
///
/// Parámetros: `standard_ref` string, `desde` RFC3339, `hasta` RFC3339.
pub struct VersionByStandardHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VersionByStandardHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let standard_ref = params.get("standard_ref").and_then(|v| v.as_str())
            .ok_or_else(|| err("standard_ref requerido"))?.to_string();
        let desde = parse_datetime(&params, "desde")?;
        let hasta = parse_datetime(&params, "hasta")?;
        if hasta <= desde {
            return Err(err("'hasta' debe ser posterior a 'desde'"));
        }

        let cambios = version_store::by_standard(&self.pg, &standard_ref, desde, hasta)
            .await
            .map_err(|e| err_server(format!("error en by_standard: {e}")))?;

        Ok(json!({"standard_ref": standard_ref, "count": cambios.len(), "cambios": cambios}))
    }
}
impl VersionByStandardHandler { pub fn method() -> &'static str { "bauth.version.by_standard" } }

// ── bauth.version.rollback ───────────────────────────────────

/// Propone un rollback de un rol a una versión anterior como cambio MAJOR.
///
/// Parámetros: `role_id` UUID, `target_version` int (version_number),
///             `change_reason` string, `changed_by` UUID, `ctx_id` string.
pub struct VersionRollbackHandler {
    pub pg: PgPool,
    pub mapa: Arc<MapaBloques>,
    pub b3: Arc<ConfigB3>,
}

#[async_trait]
impl JsonRpcHandler for VersionRollbackHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let role_id = parse_uuid(&params, "role_id")?;
        let target_ver = params.get("target_version").and_then(|v| v.as_i64())
            .ok_or_else(|| err("target_version requerido (int — version_number de T-152)"))? as i32;
        let change_reason = params.get("change_reason").and_then(|v| v.as_str())
            .ok_or_else(|| err("change_reason obligatoria en rollback"))?.to_string();
        let changed_by = parse_uuid(&params, "changed_by")?;
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| err("ctx_id requerido"))?.to_string();

        // Buscar el snapshot del target_version en T-152
        let snap: Option<(Value, String)> = sqlx::query_as(r#"
            SELECT snapshot, template_version
            FROM bauth.idn_roles_ver_b01_audit_log
            WHERE entity_id = $1 AND version_number = $2 AND snapshot IS NOT NULL
        "#)
        .bind(role_id)
        .bind(target_ver)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| err_server(e.to_string()))?;

        let (snapshot, _template) = snap.ok_or_else(|| err(&format!(
            "no hay snapshot para rol {role_id} versión {target_ver}"
        )))?;

        // Obtener la versión actual para calcular el bump MAJOR
        let (ver_actual,): (String,) = sqlx::query_as(
            "SELECT version FROM bauth.idn_roles_rol_hierarchical WHERE id = $1"
        )
        .bind(role_id)
        .fetch_one(&self.pg)
        .await
        .map_err(|e| err_server(e.to_string()))?;

        let base = crate::domain::versioning::semver::Semver::parse(&ver_actual)
            .map_err(|e| err_server(e.to_string()))?;
        let nueva = base.bump(ChangeType::Major).format();

        let reason = format!("ROLLBACK a v{target_ver}: {change_reason}");
        let cambio = CambioRol {
            role_id,
            campos_nuevos: snapshot,
            bump_declarado: nueva,
            change_reason: Some(reason),
            change_channel: ChangeChannel::Api,
            changed_by: Some(changed_by),
            ctx_id: ctx_id.clone(),
        };

        let resultado = version_store::aplicar_cambio(&self.pg, &self.mapa, &self.b3, &cambio)
            .await
            .map_err(|e| err_server(format!("error al proponer rollback: {e}")))?;

        match resultado {
            ResultadoCambio::EnRevision { proposal_id } => Ok(json!({
                "estado": "EN_REVISION",
                "role_id": role_id,
                "target_version": target_ver,
                "proposal_id": proposal_id,
            })),
            ResultadoCambio::Aplicado { nueva_version } => Ok(json!({
                "estado": "APLICADO",
                "role_id": role_id,
                "nueva_version": nueva_version,
            })),
        }
    }
}
impl VersionRollbackHandler { pub fn method() -> &'static str { "bauth.version.rollback" } }

// ── bauth.version.retention_status ───────────────────────────

/// Estado de retención de una entidad (sin ejecutar purga).
///
/// Parámetros: `entity_name` string — nombre canónico de la tabla.
pub struct VersionRetentionStatusHandler { pub pg: PgPool }

#[async_trait]
impl JsonRpcHandler for VersionRetentionStatusHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let entity_name = params.get("entity_name").and_then(|v| v.as_str())
            .ok_or_else(|| err("entity_name requerido"))?.to_string();

        let estado = retention::estado_retencion(&self.pg, &entity_name)
            .await
            .map_err(|e| err_server(format!("error leyendo retención: {e}")))?;

        match estado {
            None => Ok(json!({
                "entity_name": entity_name,
                "error": "sin política de retención registrada en T-154",
            })),
            Some(e) => Ok(json!({
                "entity_name": e.entity_name,
                "politica": e.politica,
                "legal_hold": e.legal_hold,
                "filas_total": e.filas_total,
                "filas_anchor": e.filas_anchor,
                "version_mas_antigua": e.version_mas_antigua,
                "version_mas_reciente": e.version_mas_reciente,
            })),
        }
    }
}
impl VersionRetentionStatusHandler { pub fn method() -> &'static str { "bauth.version.retention_status" } }

// ── Helpers de parseo compartidos ────────────────────────────

fn parse_change_channel(params: &Value) -> Result<ChangeChannel, JsonRpcError> {
    let s = params.get("change_channel").and_then(|v| v.as_str()).unwrap_or("API");
    match s {
        "API"       => Ok(ChangeChannel::Api),
        "CLI"       => Ok(ChangeChannel::Cli),
        "BOOTSTRAP" => Ok(ChangeChannel::Bootstrap),
        "RECONCILE" => Ok(ChangeChannel::Reconcile),
        _ => Err(err(&format!("change_channel inválido: '{s}'"))),
    }
}

// ── Factory ──────────────────────────────────────────────────

pub fn all_versioning_handlers(
    pg: PgPool,
    mapa: Arc<MapaBloques>,
    b3: Arc<ConfigB3>,
) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        // Bajo nivel — escritura WORM directa
        (VersionRecordHandler::method().into(),   Arc::new(VersionRecordHandler   { pg: pg.clone() })),
        (VersionHistoryHandler::method().into(),  Arc::new(VersionHistoryHandler  { pg: pg.clone() })),
        (LifecycleRecordHandler::method().into(), Arc::new(LifecycleRecordHandler { pg: pg.clone() })),
        (LifecycleHistoryHandler::method().into(),Arc::new(LifecycleHistoryHandler{ pg: pg.clone() })),
        // Alto nivel — transición atómica 9 pasos (1.13 §9.3)
        (VersionProposeHandler::method().into(),
            Arc::new(VersionProposeHandler { pg: pg.clone(), mapa: mapa.clone(), b3: b3.clone() })),
        (VersionAsOfHandler::method().into(),
            Arc::new(VersionAsOfHandler { pg: pg.clone() })),
        (VersionByStandardHandler::method().into(),
            Arc::new(VersionByStandardHandler { pg: pg.clone() })),
        (VersionRollbackHandler::method().into(),
            Arc::new(VersionRollbackHandler { pg: pg.clone(), mapa: mapa.clone(), b3: b3.clone() })),
        (VersionRetentionStatusHandler::method().into(),
            Arc::new(VersionRetentionStatusHandler { pg: pg.clone() })),
    ]
}
