// ============================================================
// bauth::domain::config — Configuración de dominios por tenant (B1.T21)
//
// No todos los tenants necesitan todos los dominios.
// Una PyME opera con D1+D3+D9; una empresa de seguridad
// necesita D1+D2+D3+D5+D6+D7.
//
// Los override_params permiten ajustar umbrales por tenant
// sin modificar las políticas globales. Ej: límite $5,000
// para un tenant pequeño vs $50,000 para uno enterprise.
// ============================================================

#![allow(dead_code)]
use serde_json::Value;
use sqlx::PgPool;
use std::collections::HashMap;
use tracing::debug;

/// Configuración de dominios activos para un tenant.
///
/// Cargada desde `bauth.idn_tenant_domain` al inicio de una
/// sesión de evaluación. Es inmutable durante la evaluación.
#[derive(Debug, Clone, Default)]
pub struct DomainConfig {
    /// Dominios activos: domain_code → override_params (si existen).
    active_domains: HashMap<i16, Option<Value>>,
}

impl DomainConfig {
    /// Carga desde BD los dominios activos para un tenant.
    pub async fn load(pg: &PgPool, tenant_id: uuid::Uuid) -> Result<Self, DomainConfigError> {
        let rows = crate::db::load_active_domains(pg, tenant_id)
            .await
            .map_err(|e| DomainConfigError::Database(e.to_string()))?;

        let active_domains: HashMap<i16, Option<Value>> = rows
            .into_iter()
            .map(|r| (r.domain_code, r.override_params))
            .collect();

        debug!(
            %tenant_id,
            activos = active_domains.len(),
            "configuración de dominios cargada"
        );

        Ok(Self { active_domains })
    }

    /// ¿Debe evaluarse este dominio para este tenant?
    pub fn is_active(&self, domain_code: i16) -> bool {
        self.active_domains.contains_key(&domain_code)
    }

    /// Parámetros de override para un dominio (umbrales ajustados por tenant).
    /// Retorna None si el dominio no tiene overrides.
    pub fn override_params(&self, domain_code: i16) -> Option<&Value> {
        self.active_domains.get(&domain_code).and_then(|o| o.as_ref())
    }

    /// Lista de dominios activos ordenados.
    pub fn active_list(&self) -> Vec<i16> {
        let mut domains: Vec<i16> = self.active_domains.keys().copied().collect();
        domains.sort();
        domains
    }

    /// Cantidad de dominios activos.
    pub fn count(&self) -> usize {
        self.active_domains.len()
    }
}

#[derive(Debug, thiserror::Error)]
pub enum DomainConfigError {
    #[error("error al cargar configuración de dominios: {0}")]
    Database(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_empty() {
        let cfg = DomainConfig::default();
        assert!(!cfg.is_active(1));
        assert!(cfg.active_list().is_empty());
    }

    #[test]
    fn test_override_params_none_for_inactive() {
        let cfg = DomainConfig::default();
        assert!(cfg.override_params(99).is_none());
    }
}
