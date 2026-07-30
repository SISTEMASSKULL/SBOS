// ==================================================================
// bauth::db::versioning — Escritura WORM a T-152 y T-B02L
//
// T-152:  bauth.idn_roles_ver_b01_audit_log  — historial de versiones
// T-B02L: bauth.idn_roles_rol_lifecycle_event — log de ciclo de vida
//
// Los hash-chain (prev_hash / entry_hash) los calculan los triggers
// de BD — este módulo solo pasa los campos de negocio.
//
// DOC-SBOS-001 N3 · NIST SP 800-53 AU-9 · ISO 27001:2022 A.8.15
// ==================================================================

#![allow(dead_code)]

use crate::db::DbError;
use crate::domain::versioning::{ChangeChannel, ChangeType, RolStatusDb, TriggerType};
use chrono::{DateTime, Utc};
use serde_json::Value;
use uuid::Uuid;

// ── T-B02L — Evento de ciclo de vida ────────────────────────────

/// Parámetros para registrar un evento en T-B02L.
/// Los campos `prev_hash` y `entry_hash` los calcula `trg_irle_worm`.
pub struct NuevoEventoLifecycle {
    /// UUID del rol en `bauth.idn_roles_rol_hierarchical` (T-041).
    pub role_id: Uuid,
    /// Estado anterior al evento. None = creación inicial del rol.
    pub from_status: Option<RolStatusDb>,
    /// Estado del rol después del evento (obligatorio).
    pub to_status: RolStatusDb,
    /// Tipo de disparador que inició el evento.
    pub trigger_type: TriggerType,
    /// UUID del actor humano o servicio que originó el cambio.
    pub actor_id: Option<Uuid>,
    /// Motivo del cambio en texto libre.
    pub reason: Option<String>,
    /// Snapshot JSONB de campos de vigencia al momento del evento
    /// (validity_type, valid_from, valid_until, duration_interval).
    pub validity_snapshot: Option<Value>,
    /// Context ID de la operación — obligatorio (SBOS-049).
    pub ctx_id: String,
}

/// Inserta un evento de ciclo de vida en T-B02L.
/// Retorna el UUID (`id`) del registro insertado.
///
/// Garantías del trigger `trg_irle_worm`:
/// - `prev_hash` = entry_hash del registro anterior
/// - `entry_hash` = SHA256(id || role_id || estados || trigger || ctx_id || prev_hash)
pub async fn registrar_evento_lifecycle(
    pg: &sqlx::PgPool,
    ev: &NuevoEventoLifecycle,
) -> Result<Uuid, DbError> {
    let from_str: Option<&str> = ev.from_status.as_ref().map(|s| s.as_str());
    let to_str: &str = ev.to_status.as_str();
    let trigger_str: &str = ev.trigger_type.as_str();

    let (id,): (Uuid,) = sqlx::query_as(
        r#"
        INSERT INTO bauth.idn_roles_rol_lifecycle_event
            (role_id, from_status, to_status, trigger_type,
             actor_id, reason, validity_snapshot, ctx_id)
        VALUES
            ($1,
             $2::rol_status_enum,
             $3::rol_status_enum,
             $4,
             $5,
             $6,
             $7::jsonb,
             $8)
        RETURNING id
        "#,
    )
    .bind(ev.role_id)
    .bind(from_str)
    .bind(to_str)
    .bind(trigger_str)
    .bind(ev.actor_id)
    .bind(ev.reason.as_deref())
    .bind(ev.validity_snapshot.as_ref())
    .bind(&ev.ctx_id)
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(id)
}

// ── T-152 — Snapshot de auditoría ───────────────────────────────

/// Parámetros para registrar un snapshot en T-152.
/// Los campos `prev_hash` y `entry_hash` los calcula `trg_irvb01al_worm`.
///
/// Invariantes del DDL:
/// - `change_type = MAJOR` exige `change_reason IS NOT NULL` e `is_anchor = true`
/// - `is_anchor = true` exige `snapshot IS NOT NULL`
/// - `sys_period` debe ser cerrado (upper ≠ infinity)
pub struct NuevoSnapshotAuditoria {
    /// UUID del rol versionado en T-041.
    pub entity_id: Uuid,
    /// Inicio del período de vigencia de esta versión (inclusivo).
    pub sys_period_inicio: DateTime<Utc>,
    /// Fin del período de vigencia (exclusivo). Siempre obligatorio —
    /// T-152 solo acepta versiones cerradas (`NOT upper_inf`).
    pub sys_period_fin: DateTime<Utc>,
    /// Número de versión secuencial para esta entidad (desde 0).
    pub version_number: i32,
    /// Versión del template aplicado (ej: "v6.0").
    pub template_version: String,
    /// Bloques B01-B10 que cambiaron en esta versión.
    pub blocks_touched: Vec<String>,
    /// Referencias normativas aplicables (ej: "NIST SP 800-53 AC-2").
    pub standard_ref: Vec<String>,
    /// Mapa de campos modificados: {"campo": {"antes": X, "después": Y}}.
    pub fields_changed: Value,
    /// Snapshot completo del estado del rol. Obligatorio si `is_anchor = true`.
    pub snapshot: Option<Value>,
    /// Si true, este registro es un anchor de versión major (snapshot obligatorio).
    pub is_anchor: bool,
    /// Clasificación semántica del cambio.
    pub change_type: ChangeType,
    /// Razón del cambio. Obligatoria si `change_type = MAJOR`.
    pub change_reason: Option<String>,
    /// Canal de entrada del cambio.
    pub change_channel: ChangeChannel,
    /// UUID del autor del cambio (None = operación de sistema).
    pub changed_by: Option<Uuid>,
    /// UUID del aprobador del cambio (requerido para MAJOR en producción).
    pub approved_by: Option<Uuid>,
    /// Timestamp de aprobación (requerido si `approved_by IS NOT NULL`).
    pub approved_at: Option<DateTime<Utc>>,
    /// Context ID de la operación — obligatorio (SBOS-049).
    pub ctx_id: String,
}

/// Inserta un snapshot de auditoría en T-152.
/// Retorna el UUID (`id`) del registro insertado.
///
/// Precondiciones (validadas por CHECK constraints del DDL):
/// - `change_type == MAJOR` ⟹ `change_reason.is_some() && is_anchor == true`
/// - `is_anchor == true` ⟹ `snapshot.is_some()`
/// - `sys_period_fin` debe ser posterior a `sys_period_inicio`
pub async fn registrar_snapshot_auditoria(
    pg: &sqlx::PgPool,
    snap: &NuevoSnapshotAuditoria,
) -> Result<Uuid, DbError> {
    let (id,): (Uuid,) = sqlx::query_as(
        r#"
        INSERT INTO bauth.idn_roles_ver_b01_audit_log
            (entity_id, sys_period, version_number, template_version,
             blocks_touched, standard_ref, fields_changed, snapshot,
             is_anchor, change_type, change_reason, change_channel,
             changed_by, approved_by, approved_at, ctx_id)
        VALUES
            ($1,
             tstzrange($2, $3, '[)'),
             $4,
             $5,
             $6,
             $7,
             $8::jsonb,
             $9::jsonb,
             $10,
             $11::bauth.ver_semver_change_enum,
             $12,
             $13::bauth.ver_channel_enum,
             $14,
             $15,
             $16,
             $17)
        RETURNING id
        "#,
    )
    .bind(snap.entity_id)
    .bind(snap.sys_period_inicio)
    .bind(snap.sys_period_fin)
    .bind(snap.version_number)
    .bind(&snap.template_version)
    .bind(&snap.blocks_touched)
    .bind(&snap.standard_ref)
    .bind(&snap.fields_changed)
    .bind(snap.snapshot.as_ref())
    .bind(snap.is_anchor)
    .bind(snap.change_type.as_str())
    .bind(snap.change_reason.as_deref())
    .bind(snap.change_channel.as_str())
    .bind(snap.changed_by)
    .bind(snap.approved_by)
    .bind(snap.approved_at)
    .bind(&snap.ctx_id)
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(id)
}
