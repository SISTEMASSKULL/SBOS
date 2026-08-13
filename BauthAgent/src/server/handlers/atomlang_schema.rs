// ============================================================
// bauth::server::handlers::atomlang_schema — Schema AtomLang
//
// Propósito: handlers JSON-RPC para consultar el catálogo de
//   grupos y atributos del editor de árbol AtomLang (T-580/T-581).
//
// Handler registrado:
//   bauth.atomlang.schema.node_type
//     Params:   { "node_type": "atom" | "rule" | "policy" | ... }
//     Respuesta: {
//       "node_type": "atom",
//       "grupos": [{
//         "schema_id", "slug", "parent_id", "parent_slug",
//         "label": {"es","en"}, "desc": {"es","en"},
//         "sort_order", "readonly", "reactivo",
//         "atributos": [{ "attr_id","key","label","desc",
//                         "tipo","enum_valores","sort_order",
//                         "readonly","nullable","obligatorio" }]
//       }],
//       "total_grupos": N,
//       "total_atributos": M
//     }
//
// Tablas: bauth.pol_atomlang_node_schema (T-580)
//         bauth.pol_atomlang_attr_schema  (T-581)
// DOC-SBOS-001 N3 · DDL T-580/T-581 · ADR-020
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::collections::HashMap;
use std::sync::Arc;

/// Construye un JsonRpcError estándar con código -32602.
fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

// ── Structs de mapeo sqlx ─────────────────────────────────────

/// Fila de grupo del schema AtomLang (T-580) — para node_type específico.
#[derive(sqlx::FromRow)]
struct GrupoRow {
    schema_id:   String,
    grupo_slug:  String,
    parent_id:   Option<String>,
    grupo_label: serde_json::Value,
    grupo_desc:  serde_json::Value,
    icono:       Option<String>,
    color:       Option<String>,
    sort_order:  i32,
    readonly:    bool,
    reactivo:    bool,
}

/// Fila del árbol jerárquico — CTE recursiva para bauth.atomlang.schema.all.
/// es_tipo = (grupo_slug = node_type): verdadero para filas "self" de cada tipo.
#[derive(sqlx::FromRow)]
struct NodoRow {
    schema_id:   String,
    node_type:   String,
    grupo_slug:  String,
    parent_id:   Option<String>,
    grupo_label: serde_json::Value,
    grupo_desc:  serde_json::Value,
    icono:       Option<String>,
    color:       Option<String>,
    sort_order:  i32,
    readonly:    bool,
    reactivo:    bool,
    es_tipo:     bool,
}

/// Fila de atributo del schema AtomLang (T-581).
/// attr_enum_valores se convierte a JSON en la query para evitar
/// decodificación de TEXT[] con sqlx.
#[derive(sqlx::FromRow)]
struct AttrRow {
    attr_id:              String,
    schema_id:            String,
    attr_key:             String,
    attr_label:           serde_json::Value,
    attr_desc:            serde_json::Value,
    attr_tipo:            String,
    enum_valores_json:    Option<serde_json::Value>,
    icono:                Option<String>,
    color:                Option<String>,
    sort_order:           i32,
    readonly:             bool,
    nullable:             bool,
    obligatorio:          bool,
}

// ── Handler ───────────────────────────────────────────────────

/// Handler: bauth.atomlang.schema.node_type
///
/// Devuelve todos los grupos (T-580) y sus atributos (T-581) para
/// el tipo de nodo indicado. Los grupos raíz tienen parent_id=NULL;
/// los subgrupos tienen parent_slug informado para que el cliente
/// pueda construir el título "Padre — Hijo".
pub struct AtomLangSchemaNodoTypeHandler {
    pub pg_pool: Option<PgPool>,
}

#[async_trait]
impl JsonRpcHandler for AtomLangSchemaNodoTypeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref()
            .ok_or_else(|| err("base de datos no disponible"))?;

        let node_type = params.get("node_type")
            .and_then(|v| v.as_str())
            .ok_or_else(|| err("parámetro 'node_type' requerido"))?
            .to_owned();

        // ── Consulta de grupos ────────────────────────────────
        let grupos: Vec<GrupoRow> = sqlx::query_as(
            "SELECT schema_id::text,
                    grupo_slug,
                    parent_id::text,
                    grupo_label,
                    grupo_desc,
                    icono,
                    color,
                    sort_order::int,
                    readonly,
                    reactivo
             FROM bauth.pol_atomlang_node_schema
             WHERE node_type = $1 AND is_active = true
             ORDER BY sort_order",
        )
        .bind(&node_type)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&format!("error consultando grupos: {}", e)))?;

        // ── Consulta de atributos ─────────────────────────────
        // array_to_json convierte TEXT[] a JSON evitando el codec de arrays.
        let attrs: Vec<AttrRow> = sqlx::query_as(
            "SELECT a.attr_id::text,
                    a.schema_id::text,
                    a.attr_key,
                    a.attr_label,
                    a.attr_desc,
                    a.attr_tipo::text,
                    array_to_json(a.attr_enum_valores) AS enum_valores_json,
                    a.icono,
                    a.color,
                    a.sort_order::int,
                    a.readonly,
                    a.nullable,
                    a.obligatorio
             FROM bauth.pol_atomlang_attr_schema a
             JOIN bauth.pol_atomlang_node_schema g
               ON a.schema_id = g.schema_id
             WHERE g.node_type = $1 AND a.is_active = true
             ORDER BY g.sort_order, a.sort_order",
        )
        .bind(&node_type)
        .fetch_all(pg)
        .await
        .map_err(|e| err(&format!("error consultando atributos: {}", e)))?;

        // ── Construcción de la respuesta ──────────────────────

        // Índice schema_id → [atributos JSON]
        let mut attrs_por_grupo: HashMap<String, Vec<Value>> = HashMap::new();
        let total_atributos = attrs.len();
        for a in attrs {
            attrs_por_grupo
                .entry(a.schema_id)
                .or_default()
                .push(json!({
                    "attr_id":     a.attr_id,
                    "key":         a.attr_key,
                    "label":       a.attr_label,
                    "desc":        a.attr_desc,
                    "tipo":        a.attr_tipo,
                    "enum_valores": a.enum_valores_json,
                    "icono":       a.icono,
                    "color":       a.color,
                    "sort_order":  a.sort_order,
                    "readonly":    a.readonly,
                    "nullable":    a.nullable,
                    "obligatorio": a.obligatorio,
                }));
        }

        // Índice schema_id → grupo_slug para resolver parent_slug
        let slug_por_id: HashMap<String, String> = grupos
            .iter()
            .map(|g| (g.schema_id.clone(), g.grupo_slug.clone()))
            .collect();

        let total_grupos = grupos.len();
        let grupos_json: Vec<Value> = grupos.into_iter().map(|g| {
            let parent_slug = g.parent_id
                .as_ref()
                .and_then(|pid| slug_por_id.get(pid))
                .cloned();
            let atributos = attrs_por_grupo
                .remove(&g.schema_id)
                .unwrap_or_default();

            json!({
                "schema_id":   g.schema_id,
                "slug":        g.grupo_slug,
                "parent_id":   g.parent_id,
                "parent_slug": parent_slug,
                "label":       g.grupo_label,
                "desc":        g.grupo_desc,
                "icono":       g.icono,
                "color":       g.color,
                "sort_order":  g.sort_order,
                "readonly":    g.readonly,
                "reactivo":    g.reactivo,
                "atributos":   atributos,
            })
        }).collect();

        Ok(json!({
            "node_type":       node_type,
            "grupos":          grupos_json,
            "total_grupos":    total_grupos,
            "total_atributos": total_atributos,
        }))
    }
}

// ── Handler: bauth.atomlang.schema.all ───────────────────────

/// Handler: bauth.atomlang.schema.all
///
/// Devuelve la jerarquía completa del árbol AtomLang como lista plana
/// ordenada padre-primero (ruta_orden). El cliente Flutter reconstruye
/// el árbol usando parentId.
///
/// Excluye: _common, attribute, enum, object, list, event, tenant.
/// Incluye: domain → block → policy_set / policy → rule → atom.
///
/// Params: {} (ninguno requerido)
/// Respuesta:
///   {
///     "nodos": [
///       { "schema_id", "node_type", "slug", "parent_id",
///         "es_tipo", "label", "desc", "icono", "color",
///         "sort_order", "readonly", "reactivo",
///         "atributos": [{...}] },
///       ...
///     ]
///   }
///
/// es_tipo=true  → fila "self" del tipo de nodo (encabezado, no seleccionable).
/// es_tipo=false → grupo de atributos (seleccionable en Bloque A).
pub struct AtomLangSchemaAllHandler {
    pub pg_pool: Option<PgPool>,
}

#[async_trait]
impl JsonRpcHandler for AtomLangSchemaAllHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref()
            .ok_or_else(|| err("base de datos no disponible"))?;

        // CTE recursiva: recorre la jerarquía domain→block→ps/po→rule→atom
        // en orden padre-primero usando ruta_orden como clave de ordenación.
        let nodos: Vec<NodoRow> = sqlx::query_as(
            "WITH RECURSIVE arbol AS (
                SELECT
                    schema_id::text,
                    node_type,
                    grupo_slug,
                    parent_id::text,
                    grupo_label,
                    grupo_desc,
                    icono,
                    color,
                    sort_order::int,
                    readonly,
                    reactivo,
                    (grupo_slug = node_type) AS es_tipo,
                    lpad(sort_order::text, 5, '0') AS ruta_orden
                FROM bauth.pol_atomlang_node_schema
                WHERE parent_id IS NULL
                  AND node_type NOT IN (
                      '_common','attribute','enum',
                      'object','list','event','tenant'
                  )
                  AND is_active = true
                UNION ALL
                SELECT
                    n.schema_id::text,
                    n.node_type,
                    n.grupo_slug,
                    n.parent_id::text,
                    n.grupo_label,
                    n.grupo_desc,
                    n.icono,
                    n.color,
                    n.sort_order::int,
                    n.readonly,
                    n.reactivo,
                    (n.grupo_slug = n.node_type) AS es_tipo,
                    a.ruta_orden || '.' || lpad(n.sort_order::text, 5, '0')
                FROM bauth.pol_atomlang_node_schema n
                JOIN arbol a ON n.parent_id::text = a.schema_id
                WHERE n.is_active = true
            )
            SELECT schema_id, node_type, grupo_slug, parent_id,
                   grupo_label, grupo_desc, icono, color,
                   sort_order, readonly, reactivo, es_tipo
            FROM arbol
            ORDER BY ruta_orden",
        )
        .fetch_all(pg)
        .await
        .map_err(|e| err(&format!("error consultando árbol: {}", e)))?;

        // Atributos de todos los nodos del árbol jerárquico.
        let attrs: Vec<AttrRow> = sqlx::query_as(
            "SELECT a.attr_id::text,
                    a.schema_id::text,
                    a.attr_key,
                    a.attr_label,
                    a.attr_desc,
                    a.attr_tipo::text,
                    array_to_json(a.attr_enum_valores) AS enum_valores_json,
                    a.icono,
                    a.color,
                    a.sort_order::int,
                    a.readonly,
                    a.nullable,
                    a.obligatorio
             FROM bauth.pol_atomlang_attr_schema a
             JOIN bauth.pol_atomlang_node_schema g ON a.schema_id = g.schema_id
             WHERE a.is_active = true
               AND g.is_active = true
               AND g.node_type NOT IN (
                   '_common','attribute','enum',
                   'object','list','event','tenant'
               )
             ORDER BY a.schema_id, a.sort_order",
        )
        .fetch_all(pg)
        .await
        .map_err(|e| err(&format!("error consultando atributos: {}", e)))?;

        // Índice schema_id → [atributos JSON]
        let mut attrs_por_nodo: HashMap<String, Vec<Value>> = HashMap::new();
        for a in attrs {
            attrs_por_nodo
                .entry(a.schema_id)
                .or_default()
                .push(json!({
                    "attr_id":      a.attr_id,
                    "key":          a.attr_key,
                    "label":        a.attr_label,
                    "desc":         a.attr_desc,
                    "tipo":         a.attr_tipo,
                    "enum_valores": a.enum_valores_json,
                    "icono":        a.icono,
                    "color":        a.color,
                    "sort_order":   a.sort_order,
                    "readonly":     a.readonly,
                    "nullable":     a.nullable,
                    "obligatorio":  a.obligatorio,
                }));
        }

        // Lista plana ordenada padre-primero con atributos embebidos.
        let nodos_json: Vec<Value> = nodos.into_iter().map(|n| {
            let atributos = attrs_por_nodo.remove(&n.schema_id).unwrap_or_default();
            json!({
                "schema_id":  n.schema_id,
                "node_type":  n.node_type,
                "slug":       n.grupo_slug,
                "parent_id":  n.parent_id,
                "es_tipo":    n.es_tipo,
                "label":      n.grupo_label,
                "desc":       n.grupo_desc,
                "icono":      n.icono,
                "color":      n.color,
                "sort_order": n.sort_order,
                "readonly":   n.readonly,
                "reactivo":   n.reactivo,
                "atributos":  atributos,
            })
        }).collect();

        Ok(json!({ "nodos": nodos_json }))
    }
}

// ── Registro de handlers ──────────────────────────────────────

/// Retorna los handlers del schema AtomLang para registro en el dispatcher.
pub fn all_atomlang_schema_handlers(
    pg: Option<PgPool>,
) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (
            "bauth.atomlang.schema.node_type".into(),
            Arc::new(AtomLangSchemaNodoTypeHandler { pg_pool: pg.clone() }),
        ),
        (
            "bauth.atomlang.schema.all".into(),
            Arc::new(AtomLangSchemaAllHandler { pg_pool: pg }),
        ),
    ]
}
