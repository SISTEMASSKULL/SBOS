// ============================================================
// bauth::server::handlers::role_template — B10 RolTemplate CRUD
//
// Handlers:
//   bauth.role.template.list     — listar con filtros tier/status
//   bauth.role.template.get      — template completo por ID
//   bauth.role.template.create   — crear nuevo RolTemplate (B10 completado)
//   bauth.role.template.update   — modificar template existente
//   bauth.role.template.delete   — soft-delete (status=RETIRED)
//   bauth.role.template.validate — validar 14 secciones contra estándares
//
// 14 secciones JSONB v6.0: role, logical_access, physical_access,
//   financial_limits, temporal_schedule, biometric, geospatial,
//   network, context, credentials, delegation, audit,
//   blockchain, compliance_security
//
// DOC-SBOS-001 N3 · BAUTH-ROLTEMPLATE-SECCIONES.md v6.0
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

/// Handler: bauth.role.template.list
/// Lista todas las plantillas de rol con filtros opcionales por tier y status.
pub struct RoleTemplateListHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleTemplateListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let tier_filter = params.get("tier").and_then(|v| v.as_str());
        let status_filter = params.get("status").and_then(|v| v.as_str());
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);

        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row {
            id: String,
            tier: String,
            status: String,
            hierarchy_level: i32,
            loa_required: i32,
            mfa_required: bool,
            template_version: Option<String>,
            parent_id: Option<String>,
        }

        let mut query = String::from(
            "SELECT id, tier, status, hierarchy_level, loa_required, mfa_required, template_version, parent_id
             FROM bauth.idn_role_template WHERE 1=1"
        );
        if tier_filter.is_some() { query.push_str(" AND tier = $2"); }
        if status_filter.is_some() { query.push_str(" AND status = $3"); }
        query.push_str(" ORDER BY tier, hierarchy_level, id LIMIT $1");

        let mut q = sqlx::query_as::<_, Row>(&query).bind(limit);
        if let Some(t) = tier_filter { q = q.bind(t); }
        if let Some(s) = status_filter { q = q.bind(s); }

        let rows: Vec<Row> = q.fetch_all(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error listando templates: {}", e), data: None,
        })?;

        let list: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "id": r.id, "tier": r.tier, "status": r.status,
            "hierarchy_level": r.hierarchy_level,
            "loa_required": r.loa_required, "mfa_required": r.mfa_required,
            "template_version": r.template_version,
            "parent_id": r.parent_id,
        })).collect();

        Ok(serde_json::json!({"templates": list, "count": list.len()}))
    }
}

/// Handler: bauth.role.template.get
/// Retorna el template completo (JSONB) con todas las secciones v6.0.
pub struct RoleTemplateGetHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleTemplateGetHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let role_id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "id requerido (ej: ROL-ORG-CAJ)".into(), data: None,
            })?;

        #[derive(sqlx::FromRow)]
        struct Row {
            id: String,
            tier: String,
            status: String,
            hierarchy_level: i32,
            loa_required: i32,
            mfa_required: bool,
            step_up_enabled: bool,
            sod_group: Option<String>,
            max_sessions: i32,
            session_timeout: Option<i32>,
            audit_level: Option<String>,
            template_version: Option<String>,
            template: serde_json::Value,
            created_at: chrono::DateTime<chrono::Utc>,
            updated_at: chrono::DateTime<chrono::Utc>,
        }

        let row: Row = sqlx::query_as(
            "SELECT id, tier, status, hierarchy_level, loa_required, mfa_required,
                    step_up_enabled, sod_group, max_sessions, session_timeout,
                    audit_level, template_version, template, created_at, updated_at
             FROM bauth.idn_role_template WHERE id = $1"
        )
        .bind(role_id)
        .fetch_optional(pg)
        .await
        .map_err(|e| JsonRpcError {
            code: -32000, message: format!("error consultando template: {}", e), data: None,
        })?
        .ok_or_else(|| JsonRpcError {
            code: -32602, message: format!("template no encontrado: {}", role_id), data: None,
        })?;

        // Extraer secciones del JSONB para validación
        let sections: Vec<&str> = vec![
            "role", "logical_access", "physical_access", "financial_limits",
            "temporal_schedule", "biometric", "geospatial", "network",
            "context", "credentials", "delegation", "audit",
            "blockchain", "compliance_security"
        ];
        let mut present_sections = Vec::new();
        if let Some(obj) = row.template.as_object() {
            for sec in &sections {
                if obj.contains_key(*sec) { present_sections.push(*sec); }
            }
        }

        Ok(serde_json::json!({
            "id": row.id,
            "tier": row.tier,
            "status": row.status,
            "hierarchy_level": row.hierarchy_level,
            "loa_required": row.loa_required,
            "mfa_required": row.mfa_required,
            "step_up_enabled": row.step_up_enabled,
            "sod_group": row.sod_group,
            "max_sessions": row.max_sessions,
            "session_timeout": row.session_timeout,
            "audit_level": row.audit_level,
            "template_version": row.template_version,
            "template": row.template,
            "sections_present": present_sections,
            "sections_count": present_sections.len(),
            "created_at": row.created_at,
            "updated_at": row.updated_at,
        }))
    }
}

// ── B10: Create RolTemplate ───────────────────────────────────

pub struct RoleTemplateCreateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleTemplateCreateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "id requerido (ej: ROL-ORG-CAJ)".into(), data: None })?;
        let tier = params.get("tier").and_then(|v| v.as_str()).unwrap_or("BIZ_N1");
        let template = params.get("template").cloned().unwrap_or(serde_json::json!({}));
        let parent_id = params.get("parent_id").and_then(|v| v.as_str());
        let sod_group = params.get("sod_group").and_then(|v| v.as_str());

        // Validar 14 secciones contra contrato v6.0
        let validation = crate::domain::roltemplate_validator::validate_roltemplate(&template);
        if !validation.valid {
            return Err(JsonRpcError {
                code: -32602,
                message: format!("template invalido: {} errores en {} secciones. Ej: {}",
                    validation.section_errors.len(), validation.sections_total,
                    validation.section_errors.first().map(|e| e.message.clone()).unwrap_or_default()),
                data: Some(serde_json::json!({
                    "errors": validation.section_errors.iter().map(|e| serde_json::json!({
                        "section": e.section, "field": e.field, "message": e.message
                    })).collect::<Vec<_>>()
                })),
            });
        }

        let sections_present = count_sections(&template);

        sqlx::query(
            "INSERT INTO bauth.idn_role_template (id, tier, status, template, parent_id, sod_group, template_version)
             VALUES ($1, $2, 'DEFINED', $3, $4, $5, 'v6.0')
             ON CONFLICT (id) DO UPDATE SET tier=$2, template=$3, parent_id=$4, sod_group=$5, updated_at=now()"
        ).bind(id).bind(tier).bind(&template).bind(parent_id).bind(sod_group)
        .execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error creando template: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"created": true, "id": id, "tier": tier, "sections_present": sections_present}))
    }
}

// ── B10: Update RolTemplate ───────────────────────────────────

pub struct RoleTemplateUpdateHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleTemplateUpdateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "id requerido".into(), data: None })?;

        if let Some(template) = params.get("template") {
            // Validar 14 secciones contra contrato v6.0
            let validation = crate::domain::roltemplate_validator::validate_roltemplate(template);
            if !validation.valid {
                return Err(JsonRpcError {
                    code: -32602,
                    message: format!("template invalido: {} errores", validation.section_errors.len()),
                    data: Some(serde_json::json!({"errors": validation.section_errors})),
                });
            }
            let sections = count_sections(template);
            sqlx::query("UPDATE bauth.idn_role_template SET template=$2, updated_at=now() WHERE id=$1")
                .bind(id).bind(template).execute(pg).await.map_err(|e| JsonRpcError {
                code: -32000, message: format!("error actualizando: {}", e), data: None,
            })?;
            Ok(serde_json::json!({"updated": true, "id": id, "sections_present": sections}))
        } else {
            Err(JsonRpcError { code: -32602, message: "template requerido para update".into(), data: None })
        }
    }
}

// ── B10: Delete RolTemplate (soft-delete → RETIRED) ────────────

pub struct RoleTemplateDeleteHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for RoleTemplateDeleteHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let id = params.get("id").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "id requerido".into(), data: None })?;

        sqlx::query("UPDATE bauth.idn_role_template SET status='RETIRED', updated_at=now() WHERE id=$1 AND status!='RETIRED'")
            .bind(id).execute(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error retirando template: {}", e), data: None,
        })?;

        Ok(serde_json::json!({"deleted": true, "id": id, "status": "RETIRED"}))
    }
}

// ── Helpers ────────────────────────────────────────────────────

fn count_sections(template: &Value) -> usize {
    const SECTIONS: &[&str] = &[
        "role", "logical_access", "physical_access", "financial_limits",
        "temporal_schedule", "biometric", "geospatial", "network",
        "context", "credentials", "delegation", "audit",
        "blockchain", "compliance_security",
    ];
    template.as_object().map(|o| SECTIONS.iter().filter(|s| o.contains_key(**s)).count()).unwrap_or(0)
}
