// ================================================================
// bauth::db — Acceso a datos PostgreSQL (SBOSDB, 158 tablas)
//
// Fuente de verdad: DDL canónico `SBOS_db_V2_DDL.sql` v2.12.0
// Instancia: SBOSDB · PostgreSQL localhost:15432
//
// Tablas eliminadas (no existen en DDL canónico):
//   - privilege_atom_policy  → ELIMINADO (D05b)
//   - privilege_role_atom    → ELIMINADO (sin equivalente)
//   - privilege_role         → ELIMINADO (sin equivalente)
//   - privilege_domain       → REESCRITO a privilege_resource_atom (D05)
//   - idn_role_closure       → REESCRITO a idn_roles_rol_closure
//   - privilege_atom         → REESCRITO a privilege_resource_atom
//
// DOC-SBOS-001 N3 · SBOS-049 Context Plane
// ================================================================

#![allow(dead_code)]
use crate::config::Config;
use tracing::info;

/// Contexto de base de datos compartido entre todos los módulos.
#[derive(Clone)]
pub struct AppContext {
    pub pg: sqlx::PgPool,
}

/// Inicializa el pool de conexiones a PostgreSQL (SBOSDB).
pub async fn init(cfg: &Config) -> Result<AppContext, DbError> {
    let pg = sqlx::postgres::PgPoolOptions::new()
        .max_connections(cfg.database.pool_size)
        .acquire_timeout(std::time::Duration::from_secs(
            cfg.database.connect_timeout_secs,
        ))
        .connect(&cfg.database.url)
        .await
        .map_err(|e| DbError::Postgres(e.to_string()))?;

    info!(pool_size = cfg.database.pool_size, "PostgreSQL conectado");
    Ok(AppContext { pg })
}

/// Errores de base de datos con mensajes en español.
#[derive(Debug, thiserror::Error)]
pub enum DbError {
    #[error("error de conexión PostgreSQL: {0}")]
    Postgres(String),
    #[error("{0}")]
    Other(String),
}

pub mod versioning;    // WORM T-152 (B01) y T-B02L (B02) — canónico
pub mod approval;      // Cola quórum N-de-M T-153 (B03) — canónico
pub mod version_store; // Transición atómica 9 pasos + queries — canónico

// ─── Átomos de privilegio (T-170) ───────────────────────────
//
// Fuente: bauth.privilege_resource_atom
// Reemplaza: bauth.privilege_atom (phantom), bauth.privilege_domain (phantom)

/// Cuenta átomos activos en el catálogo de privilegios.
/// Usado para dimensionar el espacio del RolBitMask en health check.
pub async fn count_atoms(pg: &sqlx::PgPool) -> Result<i64, DbError> {
    let (count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.privilege_resource_atom WHERE status = 'ACTIVE'",
    )
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(count)
}

// ─── Herencia de roles (closure table) ──────────────────────
//
// Fuente: bauth.idn_roles_rol_closure
// Reemplaza: bauth.idn_role_closure (columnas legacy: ancestro_id, descendiente_id, profundidad)

/// Carga los IDs de ancestros de un rol desde la closure table.
///
/// Retorna todos los roles de los que hereda el rol dado (depth >= 1),
/// ordenados por profundidad ascendente. Solo ancestros activos.
/// La closure table es mantenida por triggers — no se edita directamente.
pub async fn load_role_ancestors(
    pg: &sqlx::PgPool,
    role_id: uuid::Uuid,
) -> Result<Vec<uuid::Uuid>, DbError> {
    let rows: Vec<(uuid::Uuid,)> = sqlx::query_as(
        r#"
        SELECT ancestor_id
        FROM bauth.idn_roles_rol_closure
        WHERE descendant_id = $1
          AND depth          >= 1
          AND is_active      = TRUE
        ORDER BY depth
        "#,
    )
    .bind(role_id)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows.into_iter().map(|(id,)| id).collect())
}

// ─── Dominios activos por tenant (T-170) ────────────────────
//
// Fuente: bauth.privilege_resource_atom
// Reemplaza: bauth.privilege_domain (phantom, columnas: domain_code, requires_policy)

/// Configuración de dominio derivada para un tenant.
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct DomainConfigRow {
    /// Código del dominio (D00-D15, D98, D99).
    pub domain_code: i16,
    /// `true` si el dominio tiene átomos activos para el tenant.
    pub active: bool,
    /// Obligación JSONB del dominio, si aplica.
    pub override_params: Option<serde_json::Value>,
}

/// Carga los dominios activos para un tenant.
///
/// Un dominio se considera activo cuando tiene al menos un átomo con
/// `status = 'ACTIVE'` en `privilege_resource_atom` para ese tenant.
/// Los tenants sin átomos retornan lista vacía (sin acceso a ningún dominio).
pub async fn load_active_domains(
    pg: &sqlx::PgPool,
    tenant_id: uuid::Uuid,
) -> Result<Vec<DomainConfigRow>, DbError> {
    let rows: Vec<DomainConfigRow> = sqlx::query_as(
        r#"
        SELECT DISTINCT
            domain_code,
            TRUE        AS active,
            NULL::jsonb AS override_params
        FROM bauth.privilege_resource_atom
        WHERE status    = 'ACTIVE'
          AND tenant_id = $1
        ORDER BY domain_code
        "#,
    )
    .bind(tenant_id)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows)
}

// ─── Configuración global del ecosistema (bglobal) ──────────
//
// El schema `bglobal` es compartido entre todos los servicios SBOS.
// No es una tabla de bauth — es la configuración global del ecosistema.

/// Carga un valor desde `bglobal.global_config`.
///
/// Retorna `None` si la clave no existe. El schema `bglobal` es
/// co-propiedad del ecosistema SBOS (read-only para bAuth).
pub async fn load_global_config(
    pg: &sqlx::PgPool,
    key: &str,
) -> Result<Option<serde_json::Value>, DbError> {
    let row: Option<(serde_json::Value,)> = sqlx::query_as(
        "SELECT config_value FROM bglobal.global_config WHERE config_key = $1",
    )
    .bind(key)
    .fetch_optional(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(row.map(|(v,)| v))
}

// ─── Catálogo de sagas (migración B35 pendiente) ─────────────
//
// Las tablas `saga_catalog` y `saga_step` no existen en DDL v2.12.0.
// Se mantienen como stubs que retornan error descriptivo (H-012).

/// Fila del catálogo de sagas.
#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct SagaCatalogRow {
    pub saga_name:     String,
    pub version:       String,
    pub description:   String,
    pub compensation:  String,
    pub max_timeout_ms: i32,
    pub tier_minimum:  String,
    pub active:        bool,
}

/// Fila de paso de saga.
#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct SagaStepRow {
    pub step_order:     i32,
    pub step_name:      String,
    pub saga_op:        String,
    pub action_ref:     String,
    pub compensate_ref: Option<String>,
    pub timeout_ms:     i32,
    pub max_retries:    i32,
    pub depends_on:     Option<Vec<String>>,
}

/// Carga las sagas activas. Pendiente: migración B35.
pub async fn load_saga_catalog(_pg: &sqlx::PgPool) -> Result<Vec<SagaCatalogRow>, DbError> {
    Err(DbError::Other(
        "saga_catalog: tabla no disponible — migración B35 pendiente".into(),
    ))
}

/// Carga los pasos de una saga. Pendiente: migración B35.
pub async fn load_saga_steps(
    _pg: &sqlx::PgPool,
    _saga_name: &str,
) -> Result<Vec<SagaStepRow>, DbError> {
    Err(DbError::Other(
        "saga_steps: tabla no disponible — migración B35 pendiente".into(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_db_error_display_spanish() {
        let err = DbError::Postgres("connection refused".into());
        assert!(err.to_string().contains("error de conexión PostgreSQL"));
    }
}
