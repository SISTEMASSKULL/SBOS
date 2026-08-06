// ============================================================
// bauth::server::handlers::idn_roles_template — árbol AtomLang
//
// Handler:
//   bauth.idn_roles_template.todos — todos los nodos del árbol
//     para un tenant, en una sola query (carga completa).
//
// Tabla: bauth.idn_roles_template (DDL T-162 · v2.12.0)
// Respuesta: {"nodos": [...], "total": N}
//   Cada nodo incluye: id, parent_id, path, tipo, clave (JSONB label),
//   nombre (JSONB name), valor, help (JSONB), effect, verb_id,
//   domain_number, depth, sort_order, alias, block_code.
//
// DOC-SBOS-001 N3 · DDL T-162 · ADR-020
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

/// Handler: bauth.idn_roles_template.todos
/// Devuelve todos los nodos de idn_roles_template para un tenant,
/// ordenados por sort_order para preservar el orden de presentación.
/// Los campos JSONB (label, name, help) se retornan como objetos JSON
/// con claves "es"/"en" — el cliente desktop los lee con _es()/_esN().
pub struct IdnRolesTemplateTodosHandler {
    pub pg_pool: Option<PgPool>,
}

#[async_trait]
impl JsonRpcHandler for IdnRolesTemplateTodosHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref()
            .ok_or_else(|| err("base de datos no disponible"))?;

        let tenant_slug = params.get("tenant_slug")
            .and_then(|v| v.as_str())
            .unwrap_or("skull");

        #[derive(sqlx::FromRow)]
        struct NodoRow {
            id:            String,
            parent_id:     Option<String>,
            path:          String,
            tipo:          String,
            label:         serde_json::Value,
            name:          Option<serde_json::Value>,
            valor:         Option<String>,
            help:          Option<serde_json::Value>,
            effect:        bool,
            verb_id:       Option<String>,
            domain_number: Option<i32>,
            depth:         i32,
            sort_order:    i32,
            alias:         Option<String>,
            block_code:    Option<String>,
        }

        let rows: Vec<NodoRow> = sqlx::query_as(
            "SELECT irt.id::text,
                    irt.parent_id::text,
                    irt.path,
                    irt.node_type::text  AS tipo,
                    irt.label,
                    irt.name,
                    irt.value            AS valor,
                    irt.help,
                    irt.effect,
                    irt.verb_id::text,
                    irt.domain_number,
                    irt.depth,
                    irt.sort_order,
                    irt.alias,
                    irt.block_code
             FROM bauth.idn_roles_template irt
             WHERE irt.tenant_id = (
                 SELECT tenant_id FROM bauth.idn_tenant
                 WHERE tenant_slug = $1 LIMIT 1
             )
             ORDER BY irt.sort_order"
        )
        .bind(tenant_slug)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let total = rows.len();
        let nodos: Vec<Value> = rows.into_iter().map(|r| json!({
            "id":            r.id,
            "parent_id":     r.parent_id,
            "path":          r.path,
            "tipo":          r.tipo,
            "clave":         r.label,
            "nombre":        r.name,
            "valor":         r.valor,
            "help":          r.help,
            "effect":        r.effect,
            "verb_id":       r.verb_id,
            "domain_number": r.domain_number,
            "depth":         r.depth,
            "sort_order":    r.sort_order,
            "alias":         r.alias,
            "block_code":    r.block_code,
        })).collect();

        Ok(json!({ "nodos": nodos, "total": total }))
    }
}

/// Registra los handlers de idn_roles_template en el dispatcher.
pub fn all_idn_roles_template_handlers(pg: Option<PgPool>) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (
            "bauth.idn_roles_template.todos".into(),
            Arc::new(IdnRolesTemplateTodosHandler { pg_pool: pg }),
        ),
    ]
}
