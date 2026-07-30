// ==================================================================
// bauth::db::version_store — Transición atómica de versión (9 pasos)
//
// Implementa la operación de "cambio de versión de rol" de 1.13 §9.3:
//
//   1. BEGIN + SELECT T-041 FOR UPDATE NOWAIT
//   2. Clasificar campos cambiados → blocks_touched, bump_mínimo
//   3. Validar bump declarado ≥ bump_mínimo (fail-closed)
//   4. MAJOR + approval_required → INSERT T-153 + COMMIT → EnRevision
//   5. INSERT T-152 (versión cerrada con sys_period=[sys_since, now()))
//   6. UPDATE T-041 (campos nuevos + versión bumpeada + sys_since=now())
//   7. COMMIT → Aplicado
//
// Además, expone queries de lectura: as_of, history, diff, by_standard.
//
// B01: NIST AU-9 · ISO 27001:2022 A.8.15
// B02: NIST AC-2 g.4 · ISO 24760-2:2025
// B03: NIST AC-5 · NIST CM-3 · ISO 27001 A.5.3
// ==================================================================

#![allow(dead_code)]

use crate::db::{approval as db_approval, DbError};
use crate::domain::versioning::{
    blocks::MapaBloques,
    classify::clasificar,
    policy::ConfigB3,
    semver::{validar_bump_declarado, Semver},
    ChangeChannel, ChangeType,
};
use crate::db::approval::NuevaProposal;
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

// ── Tipos públicos ────────────────────────────────────────────────

/// Parámetros para aplicar un cambio de versión a un rol.
pub struct CambioRol {
    /// UUID del rol a modificar (FK T-041).
    pub role_id: Uuid,
    /// JSON object con SOLO los campos que van a cambiar.
    pub campos_nuevos: Value,
    /// Versión semántica nueva declarada por el caller (ej: "2.0.0").
    pub bump_declarado: String,
    /// Razón del cambio (obligatoria en MAJOR).
    pub change_reason: Option<String>,
    /// Canal de entrada del cambio.
    pub change_channel: ChangeChannel,
    /// Actor que solicita el cambio.
    pub changed_by: Option<Uuid>,
    /// Context ID (SBOS-049).
    pub ctx_id: String,
}

/// Resultado de `aplicar_cambio`.
pub enum ResultadoCambio {
    /// El cambio fue aplicado directamente (MINOR/PATCH).
    Aplicado { nueva_version: String },
    /// El cambio MAJOR fue encolado y requiere aprobación quórum.
    EnRevision { proposal_id: Uuid },
}

// ── Fila de T-041 leída en la transacción ───────────────────────

#[derive(Debug, sqlx::FromRow)]
struct FilaRolBloqueada {
    pub version: String,
    pub version_number: i32,
    pub sys_since: DateTime<Utc>,
    pub approval_required: bool,
    pub metadata_b1: Option<Value>,
}

// ── Transición atómica (9 pasos) ─────────────────────────────────

/// Aplica un cambio de versión a un rol de forma atómica.
///
/// Si el cambio es MAJOR y el rol tiene `approval_required = true`,
/// crea una propuesta B03 en T-153 y retorna `EnRevision`.
/// En caso contrario, aplica el cambio directamente y retorna `Aplicado`.
pub async fn aplicar_cambio(
    pg: &PgPool,
    mapa: &MapaBloques,
    b3_defaults: &ConfigB3,
    cambio: &CambioRol,
) -> Result<ResultadoCambio, DbError> {
    // Paso 1 — BEGIN + SELECT FOR UPDATE NOWAIT
    let mut tx = pg.begin().await.map_err(|e| DbError::Postgres(e.to_string()))?;

    let fila = bloquear_rol_tx(&mut tx, cambio.role_id).await?;

    // Paso 2 — Clasificar campos
    let resultado = clasificar(mapa, &cambio.campos_nuevos)
        .map_err(|e| DbError::Other(format!("clasificación: {e}")))?;

    // Paso 3 — Validar bump declarado (fail-closed)
    let version_base = Semver::parse(&fila.version)
        .map_err(|e| DbError::Other(format!("versión de rol malformada: {e}")))?;
    let version_nueva = Semver::parse(&cambio.bump_declarado)
        .map_err(|e| DbError::Other(format!("bump declarado inválido: {e}")))?;

    validar_bump_declarado(&version_base, &version_nueva, resultado.bump_minimo)
        .map_err(|e| DbError::Other(format!("validación de bump: {e}")))?;

    let es_major = matches!(resultado.bump_minimo, ChangeType::Major);
    let version_str = version_nueva.format();

    // Paso 4 — Si MAJOR + approval_required → B03
    if es_major && fila.approval_required {
        // Commitear la transacción libera el lock sin modificar T-041.
        tx.commit().await.map_err(|e| DbError::Postgres(e.to_string()))?;
        let proposal_id = someter_b03(pg, cambio, &fila, &resultado.bloques_afectados,
            &resultado.standard_ref, b3_defaults).await?;
        return Ok(ResultadoCambio::EnRevision { proposal_id });
    }

    // Pasos 5-6-7 — Aplicar directamente (MINOR/PATCH, o MAJOR sin approval)
    insertar_version_cerrada(
        &mut tx, cambio, &fila, &resultado.bloques_afectados,
        &resultado.standard_ref, resultado.bump_minimo, &version_str,
    ).await?;

    actualizar_rol_tx(&mut tx, cambio, &version_str).await?;

    tx.commit().await.map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(ResultadoCambio::Aplicado { nueva_version: version_str })
}

// ── Helpers de la transacción ─────────────────────────────────────

async fn bloquear_rol_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    role_id: Uuid,
) -> Result<FilaRolBloqueada, DbError> {
    sqlx::query_as::<_, FilaRolBloqueada>(
        r#"
        SELECT version, version_number, sys_since, approval_required, metadata_b1
        FROM bauth.idn_roles_rol_hierarchical
        WHERE id = $1
        FOR UPDATE NOWAIT
        "#,
    )
    .bind(role_id)
    .fetch_optional(&mut **tx)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?
    .ok_or_else(|| DbError::Other(format!("rol {role_id} no encontrado")))
}

/// Inserta la propuesta de cambio MAJOR en T-153 (fuera de transacción).
/// Precondición: la transacción de lectura ya fue commiteada (lock liberado).
async fn someter_b03(
    pg: &PgPool,
    cambio: &CambioRol,
    fila: &FilaRolBloqueada,
    bloques: &[String],
    normas: &[String],
    b3_defaults: &ConfigB3,
) -> Result<Uuid, DbError> {
    let meta_default = json!({});
    let meta_b1 = fila.metadata_b1.as_ref().unwrap_or(&meta_default);
    let b3 = b3_defaults.clone().con_override(meta_b1);

    let proposed_by = cambio.changed_by.ok_or_else(|| {
        DbError::Other("changed_by es obligatorio para propuestas MAJOR".into())
    })?;
    let change_reason = cambio.change_reason.as_deref()
        .ok_or_else(|| DbError::Other("change_reason es obligatorio para MAJOR".into()))?;

    db_approval::someter_propuesta(pg, &NuevaProposal {
        entity_id: cambio.role_id,
        proposed_state: cambio.campos_nuevos.clone(),
        blocks_touched: bloques.to_vec(),
        standard_ref: normas.to_vec(),
        change_reason: change_reason.to_string(),
        security_impact: "MEDIUM".to_string(),
        proposed_by,
        required_approvers: b3.required_approvers,
        approver_roles: b3.approver_roles.clone(),
        sla_deadline: b3.sla_deadline(Utc::now()),
        ctx_id: cambio.ctx_id.clone(),
    }).await
}

async fn insertar_version_cerrada(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    cambio: &CambioRol,
    fila: &FilaRolBloqueada,
    bloques: &[String],
    normas: &[String],
    change_type: ChangeType,
    version_str: &str,
) -> Result<(), DbError> {
    let es_major = matches!(change_type, ChangeType::Major);
    let snapshot: Option<Value> = if es_major {
        Some(cambio.campos_nuevos.clone())
    } else {
        None
    };

    sqlx::query(r#"
        INSERT INTO bauth.idn_roles_ver_b01_audit_log
            (entity_id, sys_period, version_number, template_version, blocks_touched,
             standard_ref, fields_changed, snapshot, is_anchor, change_type,
             change_reason, change_channel, changed_by, ctx_id)
        VALUES
            ($1,
             tstzrange($2, now(), '[)'),
             $3, $4, $5, $6, $7::jsonb, $8::jsonb,
             $9, $10::bauth.ver_semver_change_enum,
             $11, $12::bauth.ver_channel_enum, $13, $14)
    "#)
    .bind(cambio.role_id)
    .bind(fila.sys_since)
    .bind(fila.version_number)
    .bind(version_str)
    .bind(bloques)
    .bind(normas)
    .bind(&cambio.campos_nuevos)
    .bind(snapshot)
    .bind(es_major)
    .bind(change_type.as_str())
    .bind(cambio.change_reason.as_deref())
    .bind(cambio.change_channel.as_str())
    .bind(cambio.changed_by)
    .bind(&cambio.ctx_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(())
}

async fn actualizar_rol_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    cambio: &CambioRol,
    version_str: &str,
) -> Result<(), DbError> {
    // Aplica el JSON de campos_nuevos campo por campo usando jsonb_populate_record
    // trick: jsonb_to_record no es fácil en SQLx dinámico, así que actualizamos
    // los campos gestionados explícitamente con COALESCE.
    let c = &cambio.campos_nuevos;

    sqlx::query(r#"
        UPDATE bauth.idn_roles_rol_hierarchical SET
            tier               = COALESCE($2::rol_tier_enum,              tier),
            type_id            = COALESCE($3::uuid,                       type_id),
            ial_min            = COALESCE($4::ial_level_enum,             ial_min),
            risk_classification= COALESCE($5::risk_level_enum,            risk_classification),
            sensitivity_label  = COALESCE($6::sensitivity_label_enum,     sensitivity_label),
            approval_required  = COALESCE($7::boolean,                    approval_required),
            name               = COALESCE($8::jsonb,                      name),
            description        = COALESCE($9::jsonb,                      description),
            code               = COALESCE($10::text,                      code),
            is_inheritable     = COALESCE($11::boolean,                   is_inheritable),
            metadata_b1        = COALESCE($12::jsonb,                     metadata_b1),
            business_justification = COALESCE($13::jsonb,                 business_justification),
            max_simultaneous_holders = COALESCE($14::integer,             max_simultaneous_holders),
            version            = $15,
            sys_since          = now(),
            change_channel     = $16::bauth.ver_channel_enum,
            change_reason      = $17,
            updated_by         = $18,
            updated_at         = now()
        WHERE id = $1
    "#)
    .bind(cambio.role_id)
    .bind(c.get("tier").and_then(|v| v.as_str()))
    .bind(c.get("type_id").and_then(|v| v.as_str()).and_then(|s| Uuid::parse_str(s).ok()))
    .bind(c.get("ial_min").and_then(|v| v.as_str()))
    .bind(c.get("risk_classification").and_then(|v| v.as_str()))
    .bind(c.get("sensitivity_label").and_then(|v| v.as_str()))
    .bind(c.get("approval_required").and_then(|v| v.as_bool()))
    .bind(c.get("name").cloned())
    .bind(c.get("description").cloned())
    .bind(c.get("code").and_then(|v| v.as_str()))
    .bind(c.get("is_inheritable").and_then(|v| v.as_bool()))
    .bind(c.get("metadata_b1").cloned())
    .bind(c.get("business_justification").cloned())
    .bind(c.get("max_simultaneous_holders").and_then(|v| v.as_i64()).map(|n| n as i32))
    .bind(version_str)
    .bind(cambio.change_channel.as_str())
    .bind(cambio.change_reason.as_deref())
    .bind(cambio.changed_by)
    .execute(&mut **tx)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(())
}

// ── Queries de lectura ────────────────────────────────────────────

/// Fila de historial de versión para las queries de lectura.
#[derive(Debug, sqlx::FromRow)]
pub struct FilaHistorial {
    pub id: Uuid,
    pub version_number: i32,
    pub template_version: String,
    pub change_type: String,
    pub change_channel: String,
    pub change_reason: Option<String>,
    pub changed_by: Option<Uuid>,
    pub period_inicio: DateTime<Utc>,
    pub period_fin: DateTime<Utc>,
    pub blocks_touched: Vec<String>,
    pub standard_ref: Vec<String>,
}

/// Historial de versiones de un rol, ordenado por versión descendente.
pub async fn history(
    pg: &PgPool,
    entity_id: Uuid,
    limit: i64,
) -> Result<Vec<FilaHistorial>, DbError> {
    sqlx::query_as::<_, FilaHistorial>(r#"
        SELECT id, version_number, template_version,
               change_type::text,
               change_channel::text,
               change_reason,
               changed_by,
               lower(sys_period) AS period_inicio,
               upper(sys_period) AS period_fin,
               blocks_touched,
               standard_ref
        FROM bauth.idn_roles_ver_b01_audit_log
        WHERE entity_id = $1
        ORDER BY version_number DESC
        LIMIT $2
    "#)
    .bind(entity_id)
    .bind(limit)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))
}

/// Reconstruye el snapshot de un rol en un punto en el tiempo.
pub async fn as_of(
    pg: &PgPool,
    entity_id: Uuid,
    at: DateTime<Utc>,
) -> Result<Option<Value>, DbError> {
    let row: Option<(Value, i32, String)> = sqlx::query_as(r#"
        SELECT snapshot, version_number, template_version
        FROM bauth.idn_roles_ver_b01_audit_log
        WHERE entity_id = $1
          AND sys_period @> $2::timestamptz
          AND snapshot IS NOT NULL
        ORDER BY version_number DESC
        LIMIT 1
    "#)
    .bind(entity_id)
    .bind(at)
    .fetch_optional(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(row.map(|(snap, ver_num, tmpl)| json!({
        "entity_id": entity_id,
        "snapshot": snap,
        "version_number": ver_num,
        "template_version": tmpl,
        "at": at.to_rfc3339(),
    })))
}

/// Cambios por referencia normativa (query de auditor).
pub async fn by_standard(
    pg: &PgPool,
    standard_ref: &str,
    desde: DateTime<Utc>,
    hasta: DateTime<Utc>,
) -> Result<Vec<Value>, DbError> {
    let rows: Vec<(Uuid, Uuid, i32, String, DateTime<Utc>)> = sqlx::query_as(r#"
        SELECT id, entity_id, version_number,
               change_type::text,
               lower(sys_period) AS changed_at
        FROM bauth.idn_roles_ver_b01_audit_log
        WHERE $1 = ANY(standard_ref)
          AND lower(sys_period) BETWEEN $2 AND $3
        ORDER BY lower(sys_period) DESC
        LIMIT 200
    "#)
    .bind(standard_ref)
    .bind(desde)
    .bind(hasta)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows.iter().map(|(id, eid, ver, ct, at)| json!({
        "id": id, "entity_id": eid,
        "version_number": ver,
        "change_type": ct,
        "changed_at": at.to_rfc3339(),
        "standard_ref": standard_ref,
    })).collect())
}
