// ============================================================
// bauth::domain::policy_chain — PolicyChainResolver (B1.T19)
//
// Resuelve la cadena de políticas encadenadas a un átomo.
// Consulta bos_atom_policy en PostgreSQL, parsea policy_data JSONB,
// y devuelve Vec<PolicyRule> listo para evaluación por el PolicyEngine.
//
// D4 y D6 no tienen átomos propios — se activan encadenados a átomos
// de D1 (ej: sistema.sesion.ingresar → D4 + D6).
//
// Estándares:
//   NIST ABAC SP 800-162 — resolución de políticas por atributos
//   OASIS XACML 3.0 — Policy Decision Point (PDP)
//   ISO 27001:2022 A.5.15 — control de acceso basado en políticas
// ============================================================

#![allow(dead_code)]
use super::policy::{parse_policy_data, from_policy_data, PolicyRule};
use crate::db::load_policies_for_atom;
use sqlx::PgPool;
use tracing::{debug, warn};

/// Resolvedor de cadena de políticas.
///
/// Sin estado propio — opera sobre el pool de PostgreSQL.
/// Todas las políticas se cargan desde BD en cada evaluación.
/// Para producción, agregar caché en Redis con TTL 30s (B10+).
pub struct PolicyChainResolver;

impl PolicyChainResolver {
    /// Carga y resuelve todas las políticas encadenadas a un átomo.
    ///
    /// # Argumentos
    /// - `pg`: pool de conexiones PostgreSQL
    /// - `app_code`, `group_code`, `atom_code`: identificador del átomo
    ///
    /// # Retorno
    /// - `Vec<PolicyRule>` ordenado por priority, listo para PolicyEngine::evaluate()
    /// - Vec vacío si el átomo no tiene políticas encadenadas
    pub async fn resolve(
        pg: &PgPool,
        app_code: i16,
        group_code: i16,
        atom_code: i32,
    ) -> Result<Vec<PolicyRule>, PolicyChainError> {
        let rows = load_policies_for_atom(pg, app_code, group_code, atom_code).await?;

        if rows.is_empty() {
            debug!(
                app_code, group_code, atom_code,
                "sin políticas encadenadas"
            );
            return Ok(Vec::new());
        }

        let mut rules = Vec::with_capacity(rows.len());

        for row in &rows {
            match parse_policy_data(&row.policy_data) {
                Ok(pd) => {
                    let mut rule = from_policy_data(&pd);
                    // El slug viene de la BD, no del JSONB (permite búsqueda inversa)
                    rule.slug = row.policy_slug.clone();
                    // El dominio se infiere del policy_domain en la BD (ya está en la query)
                    rules.push(rule);
                }
                Err(e) => {
                    warn!(
                        slug = %row.policy_slug,
                        error = %e,
                        "política mal formada — omitiendo"
                    );
                    // Continuar con las demás políticas — no detener la evaluación
                }
            }
        }

        debug!(
            app_code, group_code, atom_code,
            total = rules.len(),
            "políticas cargadas y resueltas"
        );

        Ok(rules)
    }

    /// Devuelve los dominios adicionales que deben evaluarse para un átomo.
    ///
    /// Útil para D4 y D6 que se encadenan sin átomos propios.
    /// Retorna los domain_code distintos de las políticas activas.
    pub async fn chained_domains(
        pg: &PgPool,
        app_code: i16,
        group_code: i16,
        atom_code: i32,
    ) -> Result<Vec<u8>, PolicyChainError> {
        let rows: Vec<(i16,)> = sqlx::query_as(
            r#"
            SELECT DISTINCT policy_domain
            FROM bauth.privilege_atom_policy
            WHERE app_code = $1 AND group_code = $2 AND atom_code = $3
              AND active = TRUE
            ORDER BY policy_domain
            "#
        )
        .bind(app_code)
        .bind(group_code)
        .bind(atom_code)
        .fetch_all(pg)
        .await
        .map_err(|e| PolicyChainError::Database(e.to_string()))?;

        Ok(rows.into_iter().map(|(d,)| d as u8).collect())
    }
}

/// Error del PolicyChainResolver con mensajes en español.
#[derive(Debug, thiserror::Error)]
pub enum PolicyChainError {
    #[error("error de base de datos: {0}")]
    Database(String),
}

impl From<crate::db::DbError> for PolicyChainError {
    fn from(e: crate::db::DbError) -> Self {
        PolicyChainError::Database(e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verifica que parseo de policy_data JSONB → PolicyRule funciona
    /// con datos simulados como los que vienen de la BD.
    #[test]
    fn test_parse_policy_row_to_rule() {
        let json = serde_json::json!({
            "$schema": "bos_policy_v1",
            "priority": 10,
            "action": "deny",
            "message": "Límite excedido",
            "evaluate": {
                "logic": "and",
                "conditions": [
                    {"field": "amount", "op": "gt", "value": "${params.limit}"}
                ]
            },
            "params": {"limit": 10000}
        });

        let pd = parse_policy_data(&json).unwrap();
        let mut rule = from_policy_data(&pd);
        rule.slug = "POL-D3-LIMITE-TEST".into();

        assert_eq!(rule.slug, "POL-D3-LIMITE-TEST");
        assert_eq!(rule.priority, 10);
        assert_eq!(rule.action, "deny");
        assert_eq!(rule.conditions.len(), 1);
        // Verificar que ${params.limit} fue resuelto a 10000
        assert_eq!(rule.conditions[0].raw_value, serde_json::json!(10000));
    }

    #[test]
    fn test_parse_invalid_policy_graceful() {
        let json = serde_json::json!({"invalid": "data"});
        assert!(parse_policy_data(&json).is_err());
    }
}
