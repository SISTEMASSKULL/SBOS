// ============================================================
// bauth::server::handlers::identidad_crud — Motor de Identidad
//
// Handlers CRUD + consulta del Motor de Identidad (2.15 §5).
// Tablas canónicas DDL v2.12.0:
//   bauth.idn_identity_entity  — jerarquía unificada (D04)
//   bauth.idn_identity_attribute — atributos de entidad
//   bauth.idn_user             — cuentas de usuario (D03)
//   bauth.idn_tenant           — tenants
//
// D04: org_empresa/sucursal/pos_logico eliminadas (ADR-010).
// Toda la jerarquía vive en idn_identity_entity (level enum).
//
// Métodos:
//   bauth.identidad.list             — listar entidades por tipo
//   bauth.identidad.get              — obtener entidad + atributos
//   bauth.identidad.hijos            — hijos directos
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
        let tenant_id_str = params.get("tenant_id").and_then(|v| v.as_str());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);
        let mut results: Vec<Value> = Vec::new();

        // ── Tenants ──
        if entidad_tipo.is_none() || entidad_tipo == Some("tenant") {
            let rows = sqlx::query(
                "SELECT tenant_id, tenant_slug, tenant_name, tenant_type::text, status::text, is_internal
                 FROM bauth.idn_tenant ORDER BY is_internal DESC, tenant_slug LIMIT $1"
            )
            .bind(limit)
            .fetch_all(pg)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000, message: format!("error listando tenants: {e}"), data: None,
            })?;

            for r in rows {
                results.push(serde_json::json!({
                    "id":          r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                    "slug":        r.get::<String, _>("tenant_slug"),
                    "nombre":      r.get::<String, _>("tenant_name"),
                    "tipo":        r.get::<String, _>("tenant_type"),
                    "nivel":       "tenant",
                    "status":      r.get::<String, _>("status"),
                    "is_internal": r.get::<bool, _>("is_internal"),
                }));
            }
        }

        // ── Entidades en idn_identity_entity (bdomain, bsubdomain, pos) ──
        let niveles: &[(&str, &str)] = &[
            ("bdomain",    "empresa"),
            ("bsubdomain", "sucursal"),
            ("pos",        "pos"),
        ];
        for (nivel_db, nivel_ui) in niveles {
            if entidad_tipo.is_some()
                && entidad_tipo != Some(nivel_ui)
                && entidad_tipo != Some(nivel_db)
            {
                continue;
            }

            let tenant_uuid = tenant_id_str
                .map(|t| sqlx::types::Uuid::parse_str(t))
                .transpose()
                .map_err(|_| JsonRpcError {
                    code: -32602, message: "tenant_id inválido".into(), data: None,
                })?;

            let rows = sqlx::query(
                "SELECT entity_id, tenant_id, parent_id, code, name, status
                 FROM bauth.idn_identity_entity
                 WHERE level = $1
                   AND status != 'ARCHIVED'
                   AND ($2::uuid IS NULL OR tenant_id = $2)
                 ORDER BY code LIMIT $3"
            )
            .bind(nivel_db)
            .bind(tenant_uuid)
            .bind(limit)
            .fetch_all(pg)
            .await
            .map_err(|e| JsonRpcError {
                code: -32000,
                message: format!("error listando {nivel_ui}: {e}"),
                data: None,
            })?;

            for r in rows {
                let nombre_json: Option<serde_json::Value> = r.get("name");
                let nombre = nombre_json.as_ref()
                    .and_then(|v| v.get("es"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                results.push(serde_json::json!({
                    "id":        r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
                    "slug":      r.get::<String, _>("code"),
                    "nombre":    nombre,
                    "nivel":     nivel_ui,
                    "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
                    "parent_id": r.get::<Option<sqlx::types::Uuid>, _>("parent_id").map(|u| u.to_string()),
                    "status":    r.get::<String, _>("status"),
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

        if let Some(e) = buscar_tenant(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }
        if let Some(e) = buscar_entity(pg, id).await? {
            let atributos = listar_atributos(pg, id, None, 100).await?;
            return Ok(serde_json::json!({"entidad": e, "atributos": atributos}));
        }

        Err(JsonRpcError {
            code: -32602,
            message: format!("entidad no encontrada: {entidad_id}"),
            data: None,
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
            let hijos = listar_entities_por_tenant(pg, id, "bdomain").await?;
            return Ok(serde_json::json!({"padre": t, "hijos": hijos}));
        }

        // Entidades → hijos directos por parent_id
        if let Some(e) = buscar_entity(pg, id).await? {
            let nivel = e.get("nivel").and_then(|v| v.as_str()).unwrap_or("");
            if nivel == "pos" {
                // Pos → actores (usuarios)
                let actores = listar_usuarios_por_pos(pg, id).await?;
                return Ok(serde_json::json!({"padre": e, "hijos": actores}));
            }
            let hijos = listar_hijos_entity(pg, id).await?;
            return Ok(serde_json::json!({"padre": e, "hijos": hijos}));
        }

        Ok(serde_json::json!({"hijos": []}))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.list
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
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        let atributos = listar_atributos(pg, id, namespace, limit).await?;
        Ok(serde_json::json!({"atributos": atributos, "count": atributos.len()}))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.get
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

        let row = sqlx::query(
            "SELECT attribute_id, attr_namespace, attr_key,
                    attr_value, attr_type, verified, verified_by, created_at
             FROM bauth.idn_identity_attribute
             WHERE entity_id = $1 AND attr_key = $2
             ORDER BY sort_order LIMIT 1"
        )
        .bind(id)
        .bind(attr_key)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError { code: -32000, message: format!("error: {e}"), data: None })?
        .ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("atributo {attr_key} no encontrado"), data: None,
        })?;

        Ok(serde_json::json!({
            "attribute_id":   row.get::<sqlx::types::Uuid, _>("attribute_id").to_string(),
            "attr_namespace": row.get::<String, _>("attr_namespace"),
            "attr_key":       row.get::<String, _>("attr_key"),
            "attr_value":     row.get::<Option<serde_json::Value>, _>("attr_value"),
            "attr_type":      row.get::<String, _>("attr_type"),
            "verified":       row.get::<bool, _>("verified"),
            "verified_by":    row.get::<Option<sqlx::types::Uuid>, _>("verified_by").map(|u| u.to_string()),
            "created_at":     row.get::<chrono::DateTime<chrono::Utc>, _>("created_at"),
        }))
    }
}

// ═══════════════════════════════════════════════════════════
// bauth.identidad.atributo.search
// ═══════════════════════════════════════════════════════════

pub struct IdentidadAtributoSearchHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for IdentidadAtributoSearchHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let pattern = params.get("pattern").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "pattern requerido".into(), data: None,
            })?;
        let attr_key = params.get("attr_key").and_then(|v| v.as_str());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(20);

        let rows = sqlx::query(
            "SELECT entity_id, attr_namespace, attr_key, attr_value
             FROM bauth.idn_identity_attribute
             WHERE attr_value::text ILIKE $1
               AND ($3::text IS NULL OR attr_key = $3)
             ORDER BY attr_key LIMIT $2"
        )
        .bind(format!("%{pattern}%"))
        .bind(limit)
        .bind(attr_key)
        .fetch_all(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error en búsqueda: {e}"), data: None,
        })?;

        let results: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "entity_id":      r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
            "attr_namespace": r.get::<String, _>("attr_namespace"),
            "attr_key":       r.get::<String, _>("attr_key"),
            "attr_value":     r.get::<Option<serde_json::Value>, _>("attr_value"),
        })).collect();

        Ok(serde_json::json!({"results": results, "count": results.len()}))
    }
}

// ═══════════════════════════════════════════════════════════
// Helpers internos
// ═══════════════════════════════════════════════════════════

async fn buscar_tenant(
    pg: &sqlx::PgPool,
    id: sqlx::types::Uuid,
) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT tenant_id, tenant_slug, tenant_name, tenant_type::text, status::text
         FROM bauth.idn_tenant WHERE tenant_id = $1"
    )
    .bind(id)
    .fetch_optional(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(row.map(|r| serde_json::json!({
        "id":     r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
        "slug":   r.get::<String, _>("tenant_slug"),
        "nombre": r.get::<String, _>("tenant_name"),
        "tipo":   r.get::<String, _>("tenant_type"),
        "nivel":  "tenant",
        "status": r.get::<String, _>("status"),
    })))
}

/// Busca cualquier entidad en idn_identity_entity.
async fn buscar_entity(
    pg: &sqlx::PgPool,
    id: sqlx::types::Uuid,
) -> Result<Option<Value>, JsonRpcError> {
    let row = sqlx::query(
        "SELECT entity_id, tenant_id, parent_id, level::text, code, name, status
         FROM bauth.idn_identity_entity WHERE entity_id = $1"
    )
    .bind(id)
    .fetch_optional(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(row.map(|r| {
        let nombre_json: Option<serde_json::Value> = r.get("name");
        let nombre = nombre_json.as_ref()
            .and_then(|v| v.get("es"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        serde_json::json!({
            "id":        r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
            "slug":      r.get::<String, _>("code"),
            "nombre":    nombre,
            "nivel":     r.get::<String, _>("level"),
            "tenant_id": r.get::<sqlx::types::Uuid, _>("tenant_id").to_string(),
            "parent_id": r.get::<Option<sqlx::types::Uuid>, _>("parent_id").map(|u| u.to_string()),
            "status":    r.get::<String, _>("status"),
        })
    }))
}

async fn listar_atributos(
    pg: &sqlx::PgPool,
    entidad_id: sqlx::types::Uuid,
    namespace: Option<&str>,
    limit: i64,
) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query(
        "SELECT attribute_id, attr_namespace, attr_key, attr_value, attr_type, verified, verified_by
         FROM bauth.idn_identity_attribute
         WHERE entity_id = $1
           AND ($3::text IS NULL OR attr_namespace = $3)
         ORDER BY attr_namespace, attr_key, sort_order LIMIT $2"
    )
    .bind(entidad_id)
    .bind(limit)
    .bind(namespace)
    .fetch_all(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(rows.iter().map(|r| serde_json::json!({
        "attribute_id":   r.get::<sqlx::types::Uuid, _>("attribute_id").to_string(),
        "attr_namespace": r.get::<String, _>("attr_namespace"),
        "attr_key":       r.get::<String, _>("attr_key"),
        "attr_value":     r.get::<Option<serde_json::Value>, _>("attr_value"),
        "attr_type":      r.get::<String, _>("attr_type"),
        "verified":       r.get::<bool, _>("verified"),
        "verified_by":    r.get::<Option<sqlx::types::Uuid>, _>("verified_by").map(|u| u.to_string()),
    })).collect())
}

async fn listar_entities_por_tenant(
    pg: &sqlx::PgPool,
    tenant_id: sqlx::types::Uuid,
    nivel: &str,
) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query(
        "SELECT entity_id, code, name, parent_id, status
         FROM bauth.idn_identity_entity
         WHERE tenant_id = $1 AND level = $2 AND status != 'ARCHIVED'
         ORDER BY code"
    )
    .bind(tenant_id)
    .bind(nivel)
    .fetch_all(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(rows.iter().map(|r| {
        let n: Option<serde_json::Value> = r.get("name");
        let nombre = n.as_ref().and_then(|v| v.get("es")).and_then(|v| v.as_str()).unwrap_or("").to_string();
        serde_json::json!({
            "id":        r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
            "slug":      r.get::<String, _>("code"),
            "nombre":    nombre,
            "nivel":     nivel,
            "parent_id": r.get::<Option<sqlx::types::Uuid>, _>("parent_id").map(|u| u.to_string()),
            "status":    r.get::<String, _>("status"),
        })
    }).collect())
}

async fn listar_hijos_entity(
    pg: &sqlx::PgPool,
    parent_id: sqlx::types::Uuid,
) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query(
        "SELECT entity_id, code, name, level::text, status
         FROM bauth.idn_identity_entity
         WHERE parent_id = $1 AND status != 'ARCHIVED'
         ORDER BY level, code"
    )
    .bind(parent_id)
    .fetch_all(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(rows.iter().map(|r| {
        let n: Option<serde_json::Value> = r.get("name");
        let nombre = n.as_ref().and_then(|v| v.get("es")).and_then(|v| v.as_str()).unwrap_or("").to_string();
        serde_json::json!({
            "id":     r.get::<sqlx::types::Uuid, _>("entity_id").to_string(),
            "slug":   r.get::<String, _>("code"),
            "nombre": nombre,
            "nivel":  r.get::<String, _>("level"),
            "status": r.get::<String, _>("status"),
        })
    }).collect())
}

/// Lista usuarios (actores) cuya entidad padre es el pos indicado.
async fn listar_usuarios_por_pos(
    pg: &sqlx::PgPool,
    pos_id: sqlx::types::Uuid,
) -> Result<Vec<Value>, JsonRpcError> {
    let rows = sqlx::query(
        "SELECT u.user_id, u.username, u.status
         FROM bauth.idn_user u
         JOIN bauth.idn_identity_entity e ON e.entity_id = u.entity_id
         WHERE e.parent_id = $1 AND e.level = 'actor'
         ORDER BY u.username"
    )
    .bind(pos_id)
    .fetch_all(pg)
    .await
    .map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;

    Ok(rows.iter().map(|r| serde_json::json!({
        "id":       r.get::<sqlx::types::Uuid, _>("user_id").to_string(),
        "username": r.get::<String, _>("username"),
        "status":   r.get::<String, _>("status"),
        "nivel":    "actor",
    })).collect())
}
