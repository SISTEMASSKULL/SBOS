// ================================================================
// bauth::db — Acceso a datos PostgreSQL (B1.T19)
//
// PostgreSQL: fuente de verdad (bauth_db, 85 tablas, 3 schemas).
// Redis: cache caliente (B10+).
//
// DOC-SBOS-001 N3: documentación en español.
// ================================================================

#![allow(dead_code)]
use crate::config::Config;
use tracing::info;

/// Contexto de base de datos compartido entre todos los módulos.
#[derive(Clone)]
pub struct AppContext {
    pub pg: sqlx::PgPool,
}

/// Inicializa la conexión a PostgreSQL.
pub async fn init(cfg: &Config) -> Result<AppContext, DbError> {
    let pg = sqlx::postgres::PgPoolOptions::new()
        .max_connections(cfg.database.pool_size)
        .acquire_timeout(std::time::Duration::from_secs(cfg.database.connect_timeout_secs))
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

// ─── Queries de políticas (B1.T19) ──────────────────────────

/// Fila cruda de bos_atom_policy desde la BD.
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct PolicyRow {
    pub policy_slug: String,
    pub policy_data: serde_json::Value,
}

/// Carga todas las políticas activas encadenadas a un átomo.
/// Ordenadas por priority (menor = primero).
pub async fn load_policies_for_atom(
    pg: &sqlx::PgPool,
    app_code: i16,
    group_code: i16,
    atom_code: i32,
) -> Result<Vec<PolicyRow>, DbError> {
    let rows: Vec<PolicyRow> = sqlx::query_as(
        r#"
        SELECT policy_slug, policy_data
        FROM bauth.privilege_atom_policy
        WHERE app_code = $1 AND group_code = $2 AND atom_code = $3
          AND active = TRUE
        ORDER BY (policy_data->>'priority')::integer
        "#
    )
    .bind(app_code)
    .bind(group_code)
    .bind(atom_code)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows)
}

/// Cuenta políticas activas en la BD (para health check).
pub async fn count_policies(pg: &sqlx::PgPool) -> Result<i64, DbError> {
    let (count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.privilege_atom_policy WHERE active = TRUE"
    )
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(count)
}

// ─── Queries de roles (B1.T07) ─────────────────────────────

/// Posición de átomo asignada a un rol (de bos_role_atom).
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct RoleAtomRow {
    pub atom_position: i32,
}

/// Carga los átomos asignados a un rol (allowed=true).
/// Retorna las posiciones activas para construir el RolBitMask.
pub async fn load_role_atoms(
    pg: &sqlx::PgPool,
    role_id: uuid::Uuid,
) -> Result<Vec<RoleAtomRow>, DbError> {
    let rows: Vec<RoleAtomRow> = sqlx::query_as(
        r#"
        SELECT atom_position
        FROM bauth.privilege_role_atom
        WHERE role_id = $1 AND allowed = TRUE
        ORDER BY atom_position
        "#
    )
    .bind(role_id)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows)
}

/// Obtiene el número total de átomos en el catálogo (tamaño del RolBitMask).
pub async fn count_atoms(pg: &sqlx::PgPool) -> Result<i64, DbError> {
    let (count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.privilege_atom"
    )
    .fetch_one(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(count)
}

// ─── Queries de herencia (B1.T09) ──────────────────────────

/// Carga los ancestros de un rol desde la closure table.
/// Retorna los `ancestro_id` de todos los roles de los que hereda
/// (excluyendo self, profundidad >= 1).
pub async fn load_role_ancestors(
    pg: &sqlx::PgPool,
    role_id: &str,
) -> Result<Vec<String>, DbError> {
    let rows: Vec<(String,)> = sqlx::query_as(
        r#"
        SELECT ancestro_id
        FROM bauth.idn_role_closure
        WHERE descendiente_id = $1 AND profundidad >= 1
        ORDER BY profundidad
        "#
    )
    .bind(role_id)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows.into_iter().map(|(id,)| id).collect())
}

/// Carga los átomos de múltiples roles y los combina en posiciones únicas.
/// Útil para computar la máscara efectiva con herencia.
pub async fn load_atoms_for_roles(
    pg: &sqlx::PgPool,
    role_ids: &[String],
) -> Result<Vec<i32>, DbError> {
    if role_ids.is_empty() {
        return Ok(Vec::new());
    }

    // sqlx no soporta arrays nativos en query_as con IN, usamos ANY
    let ids: Vec<uuid::Uuid> = role_ids
        .iter()
        .filter_map(|id| uuid::Uuid::parse_str(id).ok())
        .collect();

    if ids.is_empty() {
        return Ok(Vec::new());
    }

    let rows: Vec<(i32,)> = sqlx::query_as(
        r#"
        SELECT DISTINCT atom_position
        FROM bauth.privilege_role_atom
        WHERE role_id = ANY($1) AND allowed = TRUE
        ORDER BY atom_position
        "#
    )
    .bind(&ids)
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows.into_iter().map(|(p,)| p).collect())
}

// ─── Configuración global (B1.T21) ─────────────────────────

/// Carga un valor de configuración global desde `bglobal.global_config`.
pub async fn load_global_config(
    pg: &sqlx::PgPool,
    key: &str,
) -> Result<Option<serde_json::Value>, DbError> {
    let row: Option<(serde_json::Value,)> = sqlx::query_as(
        "SELECT config_value FROM bglobal.global_config WHERE config_key = $1"
    )
    .bind(key)
    .fetch_optional(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(row.map(|(v,)| v))
}

// ─── Queries de configuración de dominios (B1.T21) ─────────

/// Configuración de un dominio para un tenant específico.
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct DomainConfigRow {
    pub domain_code: i16,
    pub active: bool,
    pub override_params: Option<serde_json::Value>,
}

/// Carga la configuración de dominios para un tenant.
/// Usa `privilege_domain` (12 dominios D1-D12) como fuente de verdad.
/// La activación por tenant se almacenará en `idn_tenant_config.metadata`
/// (B45 pendiente). Por ahora retorna todos los dominios activos.
pub async fn load_active_domains(
    pg: &sqlx::PgPool,
    _tenant_id: uuid::Uuid,
) -> Result<Vec<DomainConfigRow>, DbError> {
    let rows: Vec<DomainConfigRow> = sqlx::query_as(
        r#"
        SELECT domain_code, requires_policy AS active, NULL::jsonb AS override_params
        FROM bauth.privilege_domain
        ORDER BY domain_code
        "#
    )
    .fetch_all(pg)
    .await
    .map_err(|e| DbError::Postgres(e.to_string()))?;

    Ok(rows)
}

// ─── Queries de saga_catalog (B35) ─────────────────────────

/// Fila del catálogo de sagas.
#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct SagaCatalogRow {
    pub saga_name: String,
    pub version: String,
    pub description: String,
    pub compensation: String,
    pub max_timeout_ms: i32,
    pub tier_minimum: String,
    pub active: bool,
}

/// Fila de paso de saga.
#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct SagaStepRow {
    pub step_order: i32,
    pub step_name: String,
    pub saga_op: String,
    pub action_ref: String,
    pub compensate_ref: Option<String>,
    pub timeout_ms: i32,
    pub max_retries: i32,
    pub depends_on: Option<Vec<String>>,
}

/// Carga todas las sagas activas del catálogo.
/// TODO B35: Las tablas `saga_catalog` y `saga_step` no existen en DDL actual.
/// Deben crearse o migrarse desde bos_privilege schema antiguo.
pub async fn load_saga_catalog(_pg: &sqlx::PgPool) -> Result<Vec<SagaCatalogRow>, DbError> {
    // H-012 FIX: retornar error descriptivo en vez de silencioso vacio
    Err(DbError::Other("saga_catalog: tabla no disponible — migracion B35 pendiente".into()))
}

pub async fn load_saga_steps(_pg: &sqlx::PgPool, _saga_name: &str) -> Result<Vec<SagaStepRow>, DbError> {
    Err(DbError::Other("saga_steps: tabla no disponible — migracion B35 pendiente".into()))
}

// ─── Queries de role ────────────────────────────────────────

/// Fila de rol para listado.
#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct RoleRow {
    pub role_id: uuid::Uuid,
    pub role_code: i32,
    pub role_name: String,
    pub role_slug: String,
    pub active: bool,
}

/// Carga todos los roles activos.
pub async fn load_roles(pg: &sqlx::PgPool) -> Result<Vec<RoleRow>, DbError> {
    sqlx::query_as("SELECT role_id, role_code, role_name, role_slug, active FROM bauth.privilege_role WHERE active = TRUE ORDER BY role_code")
        .fetch_all(pg).await.map_err(|e| DbError::Postgres(e.to_string()))
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
