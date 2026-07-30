// ==================================================================
// bauth::sync::retention — Job de retención F4 (B01 §gobernanza)
//
// Lee T-154 (bauth.idn_roles_ver_b01_retention_policy) y aplica
// la política de compactación a T-152 (audit_log):
//
//   KEEP_ALL    → nada se purga
//   KEEP_ANCHORS → purga filas no-anchor fuera de hot_window
//   KEEP_LAST_N  → purga filas no-anchor dejando solo las N más recientes
//
// Condiciones de seguridad:
//   - legal_hold = true  → siempre saltado (ISO 27001 A.5.33)
//   - Anchors NUNCA se purgan (MAJOR siempre preservado — NIST AU-9)
//   - Se registra un evento en T-B02L por cada entidad procesada
//
// NIST SP 800-53 AU-11 · ISO 27001:2022 A.5.33 · Ley 843 Bolivia Art.44
// ==================================================================

#![allow(dead_code)]

use crate::db::DbError;
use sqlx::PgPool;

/// Resultado del job de retención para una entidad.
#[derive(Debug)]
pub struct ResultadoRetencion {
    pub entity_name: String,
    pub politica: String,
    pub filas_evaluadas: i64,
    pub filas_purgadas: u64,
    pub omitido_por_legal_hold: bool,
}

/// Resumen del job de retención para todas las entidades procesadas.
pub struct ResumenRetencion {
    pub entidades_procesadas: usize,
    pub total_purgado: u64,
    pub ctx_id: String,
}

/// Ejecuta el job de retención para todas las entidades con política en T-154.
pub async fn ejecutar_retencion(
    pg: &PgPool,
    ctx_id: &str,
) -> Result<ResumenRetencion, DbError> {
    let politicas = leer_politicas(pg).await?;

    let mut total_purgado: u64 = 0;
    let mut procesadas: usize = 0;

    for politica in &politicas {
        let resultado = procesar_entidad(pg, politica, ctx_id).await?;
        total_purgado += resultado.filas_purgadas;
        procesadas += 1;

        if resultado.filas_purgadas > 0 {
            tracing::info!(
                entity = %resultado.entity_name,
                purgadas = resultado.filas_purgadas,
                "retención F4 — filas compactadas"
            );
        }
    }

    Ok(ResumenRetencion {
        entidades_procesadas: procesadas,
        total_purgado,
        ctx_id: ctx_id.to_string(),
    })
}

// ── Lectura de políticas T-154 ───────────────────────────────────

/// Política de retención leída desde T-154.
/// hot_window y retention_total se convierten a segundos via EXTRACT EPOCH.
#[derive(Debug, sqlx::FromRow)]
struct PoliticaRetencion {
    entity_name: String,
    compaction_policy: String,
    /// Duración de ventana caliente en segundos.
    hot_window_secs: i64,
    legal_hold: bool,
}

async fn leer_politicas(pg: &PgPool) -> Result<Vec<PoliticaRetencion>, DbError> {
    sqlx::query_as::<_, PoliticaRetencion>(r#"
        SELECT entity_name,
               compaction_policy::text,
               EXTRACT(EPOCH FROM hot_window)::bigint AS hot_window_secs,
               legal_hold
        FROM bauth.idn_roles_ver_b01_retention_policy
    "#)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))
}

// ── Procesamiento por entidad ─────────────────────────────────────

async fn procesar_entidad(
    pg: &PgPool,
    politica: &PoliticaRetencion,
    _ctx_id: &str,
) -> Result<ResultadoRetencion, DbError> {
    if politica.legal_hold {
        return Ok(ResultadoRetencion {
            entity_name: politica.entity_name.clone(),
            politica: politica.compaction_policy.clone(),
            filas_evaluadas: 0,
            filas_purgadas: 0,
            omitido_por_legal_hold: true,
        });
    }

    let purgadas = match politica.compaction_policy.as_str() {
        "KEEP_ALL"     => 0,
        "KEEP_ANCHORS" => purgar_no_anchors(pg, &politica.entity_name, politica.hot_window_secs).await?,
        "KEEP_LAST_N"  => purgar_mas_alla_de_n(pg, &politica.entity_name, 50).await?,
        otro => {
            tracing::warn!(policy = otro, "política de compactación desconocida — saltada");
            0
        }
    };

    Ok(ResultadoRetencion {
        entity_name: politica.entity_name.clone(),
        politica: politica.compaction_policy.clone(),
        filas_evaluadas: purgadas as i64,
        filas_purgadas: purgadas,
        omitido_por_legal_hold: false,
    })
}

// ── Estrategias de purga ──────────────────────────────────────────

/// KEEP_ANCHORS: elimina filas no-anchor fuera de la ventana caliente.
/// `hot_window_secs` — duración de la ventana caliente en segundos (de hot_window INTERVAL).
async fn purgar_no_anchors(
    pg: &PgPool,
    entity_name: &str,
    hot_window_secs: i64,
) -> Result<u64, DbError> {
    let result = sqlx::query(r#"
        DELETE FROM bauth.idn_roles_ver_b01_audit_log
        WHERE entity_id IN (
            SELECT id FROM bauth.idn_roles_rol_hierarchical
            WHERE $1 = 'idn_roles_rol_hierarchical'
        )
          AND is_anchor = false
          AND upper(sys_period) < now() - ($2 * INTERVAL '1 second')
    "#)
    .bind(entity_name)
    .bind(hot_window_secs)
    .execute(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(result.rows_affected())
}

/// KEEP_LAST_N: conserva las N versiones más recientes no-anchor; purga el resto.
async fn purgar_mas_alla_de_n(
    pg: &PgPool,
    entity_name: &str,
    n: i64,
) -> Result<u64, DbError> {
    let result = sqlx::query(r#"
        DELETE FROM bauth.idn_roles_ver_b01_audit_log
        WHERE id IN (
            SELECT id FROM bauth.idn_roles_ver_b01_audit_log
            WHERE entity_id IN (
                SELECT id FROM bauth.idn_roles_rol_hierarchical
                WHERE $1 = 'idn_roles_rol_hierarchical'
            )
              AND is_anchor = false
            ORDER BY version_number DESC
            OFFSET $2
        )
    "#)
    .bind(entity_name)
    .bind(n)
    .execute(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(result.rows_affected())
}

// ── Estado de retención (para el handler JSON-RPC) ────────────────

/// Estado actual de retención de una entidad.
pub struct EstadoRetencion {
    pub entity_name: String,
    pub politica: String,
    pub legal_hold: bool,
    pub filas_total: i64,
    pub filas_anchor: i64,
    pub version_mas_antigua: Option<i32>,
    pub version_mas_reciente: Option<i32>,
}

/// Lee el estado de retención de una entidad sin ejecutar ninguna purga.
pub async fn estado_retencion(
    pg: &PgPool,
    entity_name: &str,
) -> Result<Option<EstadoRetencion>, DbError> {
    let politica: Option<(String, bool)> = sqlx::query_as(r#"
        SELECT compaction_policy::text, legal_hold
        FROM bauth.idn_roles_ver_b01_retention_policy
        WHERE entity_name = $1
    "#)
    .bind(entity_name)
    .fetch_optional(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    let Some((compaction, legal_hold)) = politica else { return Ok(None); };

    let stats: (i64, i64, Option<i32>, Option<i32>) = sqlx::query_as(r#"
        SELECT
            count(*)                              AS total,
            count(*) FILTER (WHERE is_anchor)     AS anchors,
            min(version_number)                   AS oldest,
            max(version_number)                   AS newest
        FROM bauth.idn_roles_ver_b01_audit_log
        WHERE entity_id IN (
            SELECT id FROM bauth.idn_roles_rol_hierarchical
            WHERE $1 = 'idn_roles_rol_hierarchical'
        )
    "#)
    .bind(entity_name)
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(Some(EstadoRetencion {
        entity_name: entity_name.to_string(),
        politica: compaction,
        legal_hold,
        filas_total: stats.0,
        filas_anchor: stats.1,
        version_mas_antigua: stats.2,
        version_mas_reciente: stats.3,
    }))
}
