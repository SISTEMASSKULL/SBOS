// ============================================================
// bauth::server::handlers::policy_node_type — Catálogo de tipos de nodo
//
// Handler:
//   bauth.idn_policy_node_type.list — todos los tipos activos del catálogo
//
// Tabla: bauth.idn_policy_node_type (DDL T-161b)
// Respuesta: {"tipos": [...]}
//   Cada tipo: code, abbreviation, name_es, name_en, color_key,
//   color_key_valor, font_weight, font_size_token, monospace,
//   letter_spacing, show_badge, expanded_default.
//
// El cliente Flutter usa este catálogo para renderizar badges, colores
// y tipografía del árbol de políticas sin hardcoding.
//
// DOC-SBOS-001 N3 · DDL T-161b · ADR-020
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError {
    JsonRpcError { code: -32602, message: msg.into(), data: None }
}

/// Handler: bauth.idn_policy_node_type.list
/// Devuelve todos los tipos de nodo activos del catálogo, ordenados por sort_order.
/// Los campos de presentación visual (color_key, font_weight, etc.) son consumidos
/// directamente por ConfigTipoNodo.fromJson() en el cliente Flutter.
pub struct PolicyNodeTypeListHandler {
    pub pg_pool: Option<PgPool>,
}

#[async_trait]
impl JsonRpcHandler for PolicyNodeTypeListHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref()
            .ok_or_else(|| err("base de datos no disponible"))?;

        #[derive(sqlx::FromRow)]
        struct TipoRow {
            code:             String,
            abbreviation:     String,
            name_es:          String,
            name_en:          String,
            color_key:        String,
            color_key_valor:  String,
            font_weight:      i32,
            font_size_token:  String,
            monospace:        bool,
            letter_spacing:   f64,
            show_badge:       bool,
            expanded_default: bool,
        }

        let rows: Vec<TipoRow> = sqlx::query_as(
            "SELECT code,
                    abbreviation,
                    name_es,
                    name_en,
                    color_key,
                    color_key_valor,
                    font_weight,
                    font_size_token,
                    monospace,
                    letter_spacing::float8 AS letter_spacing,
                    show_badge,
                    expanded_default
             FROM bauth.idn_policy_node_type
             WHERE is_active = true
             ORDER BY sort_order"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| err(&e.to_string()))?;

        let tipos: Vec<Value> = rows.into_iter().map(|r| json!({
            "code":             r.code,
            "abbreviation":     r.abbreviation,
            "name_es":          r.name_es,
            "name_en":          r.name_en,
            "color_key":        r.color_key,
            "color_key_valor":  r.color_key_valor,
            "font_weight":      r.font_weight,
            "font_size_token":  r.font_size_token,
            "monospace":        r.monospace,
            "letter_spacing":   r.letter_spacing,
            "show_badge":       r.show_badge,
            "expanded_default": r.expanded_default,
        })).collect();

        Ok(json!({ "tipos": tipos }))
    }
}

/// Registra los handlers del catálogo de tipos de nodo en el dispatcher.
pub fn all_policy_node_type_handlers(pg: Option<PgPool>) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (
            "bauth.idn_policy_node_type.list".into(),
            Arc::new(PolicyNodeTypeListHandler { pg_pool: pg }),
        ),
    ]
}
