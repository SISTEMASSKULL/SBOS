// ============================================================
// bauth::domain::policy_chain — PolicyChainResolver (B1.T19)
//
// Resuelve la cadena de políticas asociadas a una operación.
//
// Estado actual: `privilege_atom_policy` fue eliminada del DDL canónico (D05b).
// No existe tabla equivalente en DDL v2.12.0 para políticas por átomo.
// El sistema de políticas se migrará a `cfg_policy_library` (clave-valor)
// o `auth_policy` (política por dominio) en iteraciones futuras.
//
// Estándares:
//   NIST ABAC SP 800-162 — resolución de políticas por atributos
//   OASIS XACML 3.0 — Policy Decision Point (PDP)
//   ISO 27001:2022 A.5.15 — control de acceso basado en políticas
// ============================================================

#![allow(dead_code)]
use super::policy::{parse_policy_data, from_policy_data, PolicyRule};
use sqlx::PgPool;
use tracing::debug;

/// Resolvedor de cadena de políticas.
///
/// Sin estado propio — opera sobre el pool de PostgreSQL.
/// Carga políticas desde `cfg_policy_library` cuando estén disponibles.
pub struct PolicyChainResolver;

impl PolicyChainResolver {
    /// Carga las políticas encadenadas a una operación.
    ///
    /// **Estado actual:** retorna Vec vacío — `privilege_atom_policy` fue
    /// eliminada (D05b). Las políticas por dominio se gestionarán vía
    /// `auth_policy` cuando el módulo de políticas sea migrado (D01).
    ///
    /// # Argumentos
    /// - `pg`: pool de conexiones PostgreSQL
    /// - `app_code`, `group_code`, `atom_code`: identificador de la operación
    ///
    /// # Retorno
    /// - `Vec<PolicyRule>` (vacío en la implementación actual)
    pub async fn resolve(
        _pg: &PgPool,
        app_code: i16,
        group_code: i16,
        atom_code: i32,
    ) -> Result<Vec<PolicyRule>, PolicyChainError> {
        debug!(
            app_code, group_code, atom_code,
            "policies: sin cadena disponible (privilege_atom_policy eliminada D05b)"
        );
        Ok(Vec::new())
    }

    /// Carga políticas genéricas desde `cfg_policy_library` por clave.
    ///
    /// Sustituto parcial de `privilege_atom_policy` para políticas globales.
    /// Las políticas específicas por dominio se implementarán vía `auth_policy`.
    pub async fn resolve_from_config(
        pg: &PgPool,
        policy_key: &str,
    ) -> Result<Vec<PolicyRule>, PolicyChainError> {
        let row: Option<(serde_json::Value,)> = sqlx::query_as(
            "SELECT policy_value FROM bauth.cfg_policy_library WHERE policy_key = $1",
        )
        .bind(policy_key)
        .fetch_optional(pg)
        .await
        .map_err(|e| PolicyChainError::Database(e.to_string()))?;

        let Some((policy_data,)) = row else {
            return Ok(Vec::new());
        };

        match parse_policy_data(&policy_data) {
            Ok(pd) => {
                let mut rule = from_policy_data(&pd);
                rule.slug = policy_key.to_string();
                Ok(vec![rule])
            }
            Err(e) => {
                debug!(key = policy_key, error = %e, "política en cfg_policy_library mal formada");
                Ok(Vec::new())
            }
        }
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
        assert_eq!(rule.conditions[0].raw_value, serde_json::json!(10000));
    }

    #[test]
    fn test_parse_invalid_policy_graceful() {
        let json = serde_json::json!({"invalid": "data"});
        assert!(parse_policy_data(&json).is_err());
    }
}
