// ============================================================
// bauth::server::handlers::identidad_crud — Motor de Identidad
//
// Handlers CRUD + consulta del Motor de Identidad (2.15 §5).
//
//   bauth.identidad.list      — listar entidades
//   bauth.identidad.get        — obtener entidad + atributos
//   bauth.identidad.hijos      — hijos directos de una entidad
//   bauth.identidad.atributo.list    — atributos de entidad
//   bauth.identidad.atributo.get     — atributo específico
//   bauth.identidad.atributo.search  — búsqueda de atributos
//
// DOC-SBOS-001 N3 · 2.15 Manual Motor de Identidad.
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use sqlx::Row;

// ═══════════════════════════════════════════════════════════
// bauth.identidad.list — listar entidades por tipo y nivel
// ═══════════════════════════════════════════════════════════

pub struct IdentidadListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let entidad_tipo = params.get("tipo").and_then(|v| v.as_str());
        let tenant_id = params.get("tenant_id").and_then(|v| v.as_str());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        let mut results: Vec<Value> = Vec::new();

        // ── Tenants ──
        if entidad_tipo.is_none() || entidad_tipo == Some("tenant") {
            let rows = sqlx::query(
                "SELECT tenant_id, tenant_slug, tenant_name, tenant_type, status, is_internal
                 FROM bauth.idn_tenant ORDER BY is_internal DESC, tenant_slug LIMIT $1"
            ).bind(limit).fetch_all(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error listando tenants: {e}"), data: None,
            })?;
            for r in rows {
                results.push(serde_json::json!({
                    "id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                    "slug": r.get::<String, _>("tenant_slug"),
                    "nombre": r.get::<String, _>("tenant_name"),
                    "tipo": r.get::<String, _>("tenant_type"),
                    "nivel": "tenant",
                    "status": r.get::<String, _>("status"),
                    "is_internal": r.get::<bool, _>("is_internal"),
                }));
            }
        }

        // ── Empresas (bdomain) ──
        if entidad_tipo.is_none() || entidad_tipo == Some("bdomain") {
            let mut q = String::from(
                "SELECT uuid, tenant_id, nombre, slug, tipo FROM bauth.org_empresa WHERE 1=1"
            );
            if let Some(tid) = tenant_id {
                q.push_str(&format!(" AND tenant_id = '{tid}'::uuid"));
            }
            q.push_str(&format!(" ORDER BY nombre LIMIT {limit}"));
            let rows = sqlx::query(&q).fetch_all(pg).await
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error listando empresas: {e}"), data: None,
                })?;
            for r in rows {
                results.push(serde_json::json!({
                    "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
                    "slug": r.get::<String, _>("slug"),
                    "nombre": r.get::<String, _>("nombre"),
                    "tipo": r.get::<Option<String>, _>("tipo"),
                    "nivel": "bdomain",
                    "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                }));
            }
        }

        // ── Sucursales (bsubdomain) ──
        if entidad_tipo.is_none() || entidad_tipo == Some("bsubdomain") {
            let mut q = String::from(
                "SELECT uuid, tenant_id, empresa_id, nombre, slug, tipo FROM bauth.org_sucursal WHERE 1=1"
            );
            if let Some(tid) = tenant_id {
                q.push_str(&format!(" AND tenant_id = '{tid}'::uuid"));
            }
            q.push_str(&format!(" ORDER BY nombre LIMIT {limit}"));
            let rows = sqlx::query(&q).fetch_all(pg).await
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error listando sucursales: {e}"), data: None,
                })?;
            for r in rows {
                results.push(serde_json::json!({
                    "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
                    "slug": r.get::<String, _>("slug"),
                    "nombre": r.get::<String, _>("nombre"),
                    "tipo": r.get::<Option<String>, _>("tipo"),
                    "nivel": "bsubdomain",
                    "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                    "parent_id": r.get::<sqlx::types::Uuid, _>("empresa_id").to_string(),
                }));
            }
        }

        // ── Puntos lógicos (pos) ──
        if entidad_tipo.is_none() || entidad_tipo == Some("pos") {
            let mut q = String::from(
                "SELECT uuid, tenant_id, sucursal_id, nombre, slug, tipo FROM bauth.org_pos_logico WHERE 1=1"
            );
            if let Some(tid) = tenant_id {
                q.push_str(&format!(" AND tenant_id = '{tid}'::uuid"));
            }
            q.push_str(&format!(" ORDER BY nombre LIMIT {limit}"));
            let rows = sqlx::query(&q).fetch_all(pg).await
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error listando pos: {e}"), data: None,
                })?;
            for r in rows {
                results.push(serde_json::json!({
                    "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
                    "slug": r.get::<String, _>("slug"),
                    "nombre": r.get::<String, _>("nombre"),
                    "tipo": r.get::<Option<String>, _>("tipo"),
                    "nivel": "pos",
                    "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                    "parent_id": r.get::<sqlx::types::Uuid, _>("sucursal_id").to_string(),
                }));
            }
        }

        Ok(serde_json::json!({"entidades": results, "count": results.len()}))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.get — obtener entidad con sus atributos
// ═══════════════════════════════════════════════════════════

pub struct IdentidadGetHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let entidad_id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "id requerido (UUID)".into(), data: None,
            })?;
        let id = sqlx::types::Uuid::parse_str(entidad_id).map_err(|_| JsonRpcError {
            code: -32602, message: "id inválido".into(), data: None,
        })?;

        // Intentar encontrar la entidad en cada tabla de nivel
        if let Some(e) = buscar_tenant(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }
        if let Some(e) = buscar_empresa(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }
        if let Some(e) = buscar_sucursal(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }
        if let Some(e) = buscar_pos(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }

        Err(JsonRpcError {
            code: -32602, message: format!("entidad no encontrada: {entidad_id}"), data: None,
        })
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.hijos — hijos directos de una entidad
// ═══════════════════════════════════════════════════════════

pub struct IdentidadHijosHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadHijosHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let entidad_id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "id requerido (UUID)".into(), data: None,
            })?;
        let id = sqlx::types::Uuid::parse_str(entidad_id).map_err(|_| JsonRpcError {
            code: -32602, message: "id inválido".into(), data: None,
        })?;

        // Tenant → empresas (bdomain)
        if let Some(t) = buscar_tenant(pg, id).await? {
            let hijos = listar_empresas_por_tenant(pg, id).await?;
            return Ok(serde_json::json!({"padre": t, "hijos": hijos}));
        }
        // Empresa → sucursales (bsubdomain)
        if let Some(e) = buscar_empresa(pg, id).await? {
            let hijos = listar_sucursales_por_empresa(pg, id).await?;
            return Ok(serde_json::json!({"padre": e, "hijos": hijos}));
        }
        // Sucursal → pos
        if let Some(s) = buscar_sucursal(pg, id).await? {
            let hijos = listar_pos_por_sucursal(pg, id).await?;
            return Ok(serde_json::json!({"padre": s, "hijos": hijos}));
        }
        // Pos → actores (users)
        if buscar_pos(pg, id).await?.is_some() {
            let hijos = listar_usuarios_por_pos(pg, id).await?;
            return Ok(serde_json::json!({"hijos": hijos}));
        }

        Ok(serde_json::json!({"hijos": []}))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.list — listar atributos de entidad
// ═══════════════════════════════════════════════════════════

pub struct IdentidadAtributoListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadAtributoListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let entity_id = params.get("entity_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "entity_id requerido (UUID)".into(), data: None,
            })?;
        let id = sqlx::types::Uuid::parse_str(entity_id).map_err(|_| JsonRpcError {
            code: -32602, message: "entity_id inválido".into(), data: None,
        })?;

        let namespace = params.get("attr_namespace").and_then(|v| v.as_str());
        let attr_key = params.get("attr_key").and_then(|v| v.as_str());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        let atributos = listar_atributos(pg, id, namespace, attr_key, limit).await?;
        Ok(serde_json::json!({"atributos": atributos, "count": atributos.len()}))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.get — atributo específico
// ═══════════════════════════════════════════════════════════

pub struct IdentidadAtributoGetHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadAtributoGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let entity_id = params.get("entity_id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "entity_id requerido (UUID)".into(), data: None,
            })?;
        let id = sqlx::types::Uuid::parse_str(entity_id).map_err(|_| JsonRpcError {
            code: -32602, message: "entity_id inválido".into(), data: None,
        })?;
        let attr_key = params.get("attr_key").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "attr_key requerido".into(), data: None,
            })?;
        let q = "SELECT attribute_id, attr_namespace, attr_key,
                        attr_value, attr_type, verified, verified_by, created_at
                 FROM bauth.idn_identity_attribute WHERE entity_id = $1 AND attr_key = $2
                 ORDER BY sort_order LIMIT 1";

        let row = sqlx::query(q)
            .bind(id).bind(attr_key)
            .fetch_optional(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error: {e}"), data: None,
            })?
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: format!("atributo {attr_key} no encontrado"), data: None,
            })?;

        Ok(serde_json::json!({
            "attribute_id": row.get::<sqlx::types::Uuid, _>("attribute_id").to_string(),
            "attr_namespace": row.get::<String, _>("attr_namespace"),
            "attr_key": row.get::<String, _>("attr_key"),
            "attr_value": row.get::<Option<serde_json::Value>, _>("attr_value"),
            "attr_type": row.get::<String, _>("attr_type"),
            "verified": row.get::<bool, _>("verified"),
            "verified_by": row.get::<Option<sqlx::types::Uuid>, _>("verified_by").map(|u| u.to_string()),
            "created_at": row.get::<chrono::DateTime<chrono::Utc>, _>("created_at"),
        }))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.search — búsqueda de atributos
// ═══════════════════════════════════════════════════════════

pub struct IdentidadAtributoSearchHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadAtributoSearchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let attr_key = params.get("attr_key").and_then(|v| v.as_str());
        let pattern = params.get("pattern").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "pattern requerido".into(), data: None,
            })?;
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20);

        let mut q = String::from(
            "SELECT entity_id, attr_namespace, attr_key, attr_value
             FROM bauth.idn_identity_attribute WHERE attr_value::text ILIKE $1"
        );
        if let Some(ak) = attr_key {
            q.push_str(&format!(" AND attr_key = '{ak}'"));
        }
        q.push_str(&format!(" ORDER BY attr_key LIMIT {limit}"));

        let rows = sqlx::query(&q)
            .bind(format!("%{pattern}%"))
            .fetch_all(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error en búsqueda: {e}"), data: None,
            })?;

        let results: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "entity_id": r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
            "attr_namespace": r.get::<String, _>("attr_namespace"),
            "attr_key": r.get::<String, _>("attr_key"),
            "attr_value": r.get::<Option<serde_json::Value>, _>("attr_value"),
        })).collect();

        Ok(serde_json::json!({"results": results, "count": results.len()}))
    }
}

// ═══════════════════════════════════════════════════════════
// Helpers de búsqueda por tipo de entidad
// ═══════════════════════════════════════════════════════════

async fn buscar_tenant(pg: &sqlx::PgPool, id: sqlx::types::Uuid) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT tenant_id, tenant_slug, tenant_name, tenant_type, status
         FROM bauth.idn_tenant WHERE tenant_id = $1"
    ).bind(id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
        code: -32000, message: e.to_string(), data: None,
    })?;
    Ok(row.map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
        "slug": r.get::<String, _>("tenant_slug"),
        "nombre": r.get::<String, _>("tenant_name"),
        "tipo": r.get::<String, _>("tenant_type"),
        "nivel": "tenant",
        "status": r.get::<String, _>("status"),
    })))
}

async fn buscar_empresa(pg: &sqlx::PgPool, id: sqlx::types::Uuid) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT uuid, tenant_id, nombre, slug, tipo FROM bauth.org_empresa WHERE uuid = $1"
    ).bind(id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
        code: -32000, message: e.to_string(), data: None,
    })?;
    Ok(row.map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "bdomain",
        "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
    })))
}

async fn buscar_sucursal(pg: &sqlx::PgPool, id: sqlx::types::Uuid) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT uuid, tenant_id, empresa_id, nombre, slug, tipo FROM bauth.org_sucursal WHERE uuid = $1"
    ).bind(id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
        code: -32000, message: e.to_string(), data: None,
    })?;
    Ok(row.map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "bsubdomain",
        "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
        "parent_id": r.get::<sqlx::types::Uuid, _>("empresa_id").to_string(),
    })))
}

async fn buscar_pos(pg: &sqlx::PgPool, id: sqlx::types::Uuid) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT uuid, tenant_id, sucursal_id, nombre, slug, tipo FROM bauth.org_pos_logico WHERE uuid = $1"
    ).bind(id).fetch_optional(pg).await.map_err(|e| JsonRpcError {
        code: -32000, message: e.to_string(), data: None,
    })?;
    Ok(row.map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "pos",
        "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
        "parent_id": r.get::<sqlx::types::Uuid, _>("sucursal_id").to_string(),
    })))
}

// ── Helpers de listado jerárquico ──

async fn listar_atributos(pg: &sqlx::PgPool, entidad_id: sqlx::types::Uuid,
    namespace: Option<&str>, _attr_key: Option<&str>, limit: i64) -> Result<Vec<Value>, JsonRpcError>
{
    let mut q = String::from(
        "SELECT attribute_id, attr_namespace, attr_key, attr_value, attr_type, verified, verified_by
         FROM bauth.idn_identity_attribute WHERE entity_id = $1"
    );
    if let Some(ns) = namespace { q.push_str(&format!(" AND attr_namespace = '{ns}'")); }
    q.push_str(&format!(" ORDER BY attr_namespace, attr_key, sort_order LIMIT {limit}"));

    let rows = sqlx::query(&q).bind(entidad_id).fetch_all(pg).await
        .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(rows.iter().map(|r| serde_json::json!({
        "attribute_id": r.get::<sqlx::types::Uuid, _>("attribute_id").to_string(),
        "attr_namespace": r.get::<String, _>("attr_namespace"),
        "attr_key": r.get::<String, _>("attr_key"),
        "attr_value": r.get::<Option<serde_json::Value>, _>("attr_value"),
        "attr_type": r.get::<String, _>("attr_type"),
        "verified": r.get::<bool, _>("verified"),
        "verified_by": r.get::<Option<sqlx::types::Uuid>, _>("verified_by").map(|u| u.to_string()),
    })).collect())
}

async fn listar_empresas_por_tenant(pg: &sqlx::PgPool, tenant_id: sqlx::types::Uuid) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query("SELECT uuid, nombre, slug, tipo FROM bauth.org_empresa WHERE tenant_id = $1 ORDER BY nombre")
        .bind(tenant_id).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
    Ok(rows.iter().map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "bdomain",
    })).collect())
}

async fn listar_sucursales_por_empresa(pg: &sqlx::PgPool, empresa_id: sqlx::types::Uuid) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query("SELECT uuid, nombre, slug, tipo FROM bauth.org_sucursal WHERE empresa_id = $1 ORDER BY nombre")
        .bind(empresa_id).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
    Ok(rows.iter().map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "bsubdomain",
    })).collect())
}

async fn listar_pos_por_sucursal(pg: &sqlx::PgPool, sucursal_id: sqlx::types::Uuid) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query("SELECT uuid, nombre, slug, tipo FROM bauth.org_pos_logico WHERE sucursal_id = $1 ORDER BY nombre")
        .bind(sucursal_id).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
    Ok(rows.iter().map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "slug": r.get::<String, _>("slug"),
        "nombre": r.get::<String, _>("nombre"),
        "tipo": r.get::<Option<String>, _>("tipo"),
        "nivel": "pos",
    })).collect())
}

async fn listar_usuarios_por_pos(pg: &sqlx::PgPool, pos_id: sqlx::types::Uuid) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query(
        "SELECT uuid, username, account_type, status FROM bauth.idn_user_template WHERE pos_id = $1 ORDER BY username"
    ).bind(pos_id).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
    Ok(rows.iter().map(|r| serde_json::json!({
        "id": r.get::<sqlx::types::Uuid, _>("uuid").to_string(),
        "username": r.get::<String, _>("username"),
        "tipo": r.get::<Option<String>, _>("account_type"),
        "status": r.get::<Option<String>, _>("status"),
        "nivel": "actor",
    })).collect())
}
