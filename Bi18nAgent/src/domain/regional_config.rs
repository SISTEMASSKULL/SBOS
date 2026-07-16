/// domain/regional_config.rs — Trait y tipo de configuración regional.
/// Propósito: abstracción GAP-01 — resuelve RegionalConfig para cada operación.
///   - En MVP: se usa la config estática de bi18n.toml (StaticResolver).
///   - En producción: bAuth envía regional_config en cada request (RequestResolver).
/// Dependencias: async-trait, serde, crate::error
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use crate::error::{Bi18nError, Resultado};

/// Configuración regional resuelta para una operación.
/// Espejo del mensaje proto `RegionalConfig` — se convierte desde/hacia proto.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RegionalConfig {
    /// Locale BCP 47. Ejemplo: "es-BO", "en-US"
    pub locale: String,
    /// Zona horaria IANA. Ejemplo: "America/La_Paz"
    pub timezone: String,
    /// Moneda ISO 4217. Ejemplo: "BOB", "USD"
    pub currency: String,
    /// País ISO 3166-1 alpha-2. Ejemplo: "BO", "US"
    pub country: String,
}

/// Trait de resolución de configuración regional.
/// Toda implementación debe ser Send + Sync para uso en Arc compartido.
#[async_trait]
pub trait RegionalConfigResolver: Send + Sync {
    /// Resuelve la configuración regional para el contexto indicado.
    /// La jerarquía es: user_id → branch_id → tenant_id → default.
    async fn resolver(
        &self,
        tenant_id: &str,
        branch_id: Option<&str>,
        user_id: Option<&str>,
    ) -> Resultado<RegionalConfig>;
}

/// Implementación MVP: retorna siempre la config estática del TOML.
/// Sustituida en producción por la config enviada por bAuth en el request.
pub struct ResolverEstatico {
    config: RegionalConfig,
}

impl ResolverEstatico {
    /// Construye el resolver con la config leída de bi18n.toml.
    pub fn nuevo(cfg: &crate::config::RegionalDefecto) -> Self {
        Self {
            config: RegionalConfig {
                locale: cfg.locale.clone(),
                timezone: cfg.timezone.clone(),
                currency: cfg.currency.clone(),
                country: cfg.country.clone(),
            },
        }
    }
}

#[async_trait]
impl RegionalConfigResolver for ResolverEstatico {
    async fn resolver(
        &self,
        _tenant_id: &str,
        _branch_id: Option<&str>,
        _user_id: Option<&str>,
    ) -> Resultado<RegionalConfig> {
        Ok(self.config.clone())
    }
}

/// Resuelve la config desde el campo opcional del request (producción).
/// Si el campo está presente lo retorna directamente; si no, delega en el fallback.
pub async fn resolver_desde_request(
    request_regional: Option<RegionalConfig>,
    fallback: &dyn RegionalConfigResolver,
    tenant_id: &str,
) -> Resultado<RegionalConfig> {
    match request_regional {
        Some(rc) => {
            validar_regional(&rc)?;
            Ok(rc)
        }
        None => fallback.resolver(tenant_id, None, None).await,
    }
}

/// Valida que los campos obligatorios de RegionalConfig no estén vacíos.
fn validar_regional(rc: &RegionalConfig) -> Resultado<()> {
    if rc.locale.is_empty() {
        return Err(Bi18nError::LocaleInvalido {
            locale: rc.locale.clone(),
            causa: "locale vacío".to_string(),
        });
    }
    Ok(())
}
