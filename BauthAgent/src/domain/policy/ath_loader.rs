// ============================================================
// bauth::domain::policy::ath_loader — Carga ath_policy_dN desde PostgreSQL
//
// Carga las 12 tablas ath_policy_dN y convierte cada fila a PolicyRule
// mediante ath_converter::convert(). Omite filas sin campo "rule" en config.
//
// Sin caché en este módulo — cada evaluación consulta la BD.
// (Caché Redis con TTL 30s: tarea B10+, igual que PolicyChainResolver).
// ============================================================

#![allow(dead_code)]
use super::ath_converter;
use super::rule::PolicyRule;
use sqlx::PgPool;

/// Carga y convierte todas las políticas activas de un dominio (1–12).
/// Omite filas con config sin campo "rule" (entradas LIB-* de referencia).
pub async fn load_domain(pg: &PgPool, domain: u8) -> Vec<PolicyRule> {
    if !(1..=12).contains(&domain) {
        tracing::warn!(domain, "dominio fuera de rango [1,12] — omitido");
        return vec![];
    }

    #[derive(sqlx::FromRow)]
    struct Row {
        policy_code: String,
        policy_name: String,
        config: serde_json::Value,
    }

    // D01 resuelto: ath_policy_dN → auth_policy (tabla unificada DDL v2.12.0)
    // metadata JSONB reemplaza config; policy_id::text como policy_code
    let sql = format!(
        "SELECT policy_id::text AS policy_code, name AS policy_name, metadata AS config
         FROM bauth.auth_policy
         WHERE active = TRUE AND metadata ? 'rule'
         ORDER BY policy_id -- domain={} (sin columna domain en DDL v2.12.0)",
        domain
    );

    match sqlx::query_as::<_, Row>(&sql).fetch_all(pg).await {
        Ok(rows) => {
            let count = rows.len();
            let rules: Vec<PolicyRule> = rows.into_iter().enumerate().filter_map(|(i, r)| {
                let priority = r.config.get("priority")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(50 + i as i64) as i32;
                ath_converter::convert(&r.policy_code, &r.policy_name, &r.config, priority, domain)
            }).collect();
            tracing::debug!(domain, total_rows = count, converted = rules.len(), "políticas D{} cargadas", domain);
            rules
        }
        Err(e) => {
            tracing::warn!(domain, error = %e, "error cargando ath_policy_d{} — retornando vacío", domain);
            vec![]
        }
    }
}

/// Carga todos los dominios (D1–D12) en paralelo.
/// Retorna mapa domain_code → Vec<PolicyRule>.
pub async fn load_all(pg: &PgPool) -> std::collections::HashMap<u8, Vec<PolicyRule>> {
    let handles: Vec<_> = (1u8..=12).map(|d| {
        let pg = pg.clone();
        tokio::spawn(async move { (d, load_domain(&pg, d).await) })
    }).collect();

    let mut map = std::collections::HashMap::new();
    for h in handles {
        if let Ok((d, rules)) = h.await {
            map.insert(d, rules);
        }
    }
    map
}
