/// server/handlers/locale.rs — Handler de resolución y validación de locale.
/// Propósito:
///   - resolver_locale: resuelve la configuración regional por jerarquía (GAP-01).
///     Jerarquía: user_id → branch_id → tenant_id → default.
///   - validar_locale_bcp47: valida un locale BCP 47 con ICU4X (icu_locale_core).
///     Un locale inválido retorna error descriptivo en español.
/// Dependencias: crate::domain::regional_config, crate::server::context, icu_locale_core
use crate::{
    domain::regional_config::RegionalConfig,
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};
use icu_locale_core::Locale;

/// Resultado de resolución de locale.
#[derive(Debug)]
pub struct LocaleResult {
    pub config: RegionalConfig,
    /// Nivel desde el que se resolvió: "user" | "branch" | "tenant" | "default"
    pub fuente: &'static str,
}

/// Resuelve la configuración regional para un contexto de tenant/branch/user.
/// En MVP siempre resuelve desde el resolver estático (bi18n.toml).
/// En producción bAuth enviará RegionalConfig en cada request.
pub async fn resolver_locale(
    ctx: &ServerContext,
    tenant_id: &str,
    branch_id: &str,
    user_id: &str,
) -> Resultado<LocaleResult> {
    let config = ctx.resolver.resolver(
        tenant_id,
        if branch_id.is_empty() { None } else { Some(branch_id) },
        if user_id.is_empty() { None } else { Some(user_id) },
    ).await?;

    Ok(LocaleResult { config, fuente: "default" })
}

/// Valida que un locale BCP 47 sea reconocido por ICU4X.
/// Retorna el Locale parseado si es válido, o un error descriptivo en español.
///
/// Ejemplos:
/// - "es-BO" → Ok(Locale)
/// - "es-INVALIDO" → Err(LocaleInvalido { valor: "es-INVALIDO", ... })
/// - "und" → Ok(Locale) (locale undetermined — siempre válido)
pub fn validar_locale_bcp47(locale: &str) -> Resultado<Locale> {
    locale.parse::<Locale>().map_err(|_| Bi18nError::LocaleInvalido {
        locale: locale.to_string(),
        causa: "locale BCP 47 inválido según ICU4X (icu_locale_core)".to_string(),
    })
}

/// Verifica si un locale BCP 47 es válido. Versión bool para validaciones de params.
pub fn es_locale_valido(locale: &str) -> bool {
    locale.parse::<Locale>().is_ok()
}

/// Detecta la dirección de escritura de un locale BCP 47 (10.1).
/// Retorna "rtl" para lenguas con escritura derecha a izquierda conocidas; "ltr" para el resto.
/// La detección opera sobre el subtag de idioma — sin crate adicional (ICU4X no expone
/// dirección de script directamente en icu_locale_core).
pub fn detectar_direccion_texto(locale: &str) -> &'static str {
    let lang = locale.split('-').next().unwrap_or(locale);
    match lang {
        "ar" | "he" | "fa" | "ur" | "dv" | "yi" | "ug" | "ku" | "sd" | "ps" => "rtl",
        _ => "ltr",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_locale_valido_es_bo() {
        assert!(es_locale_valido("es-BO"));
        assert!(validar_locale_bcp47("es-BO").is_ok());
    }

    #[test]
    fn test_locale_invalido() {
        // ICU4X usa parsing lenient para subtags — rechazo con caracteres prohibidos BCP 47
        assert!(!es_locale_valido("!@#invalid"));
        let err = validar_locale_bcp47("!@#invalid");
        assert!(err.is_err());
    }

    #[test]
    fn test_locale_und_valido() {
        assert!(es_locale_valido("und"));
    }

    #[test]
    fn test_detectar_direccion_texto() {
        // RTL — lenguas conocidas con escritura derecha a izquierda
        assert_eq!(detectar_direccion_texto("ar-SA"), "rtl");
        assert_eq!(detectar_direccion_texto("he-IL"), "rtl");
        assert_eq!(detectar_direccion_texto("fa-IR"), "rtl");
        assert_eq!(detectar_direccion_texto("ur-PK"), "rtl");
        // LTR — lenguas del ecosistema SBOS y otras
        assert_eq!(detectar_direccion_texto("es-BO"), "ltr");
        assert_eq!(detectar_direccion_texto("pt-BR"), "ltr");
        assert_eq!(detectar_direccion_texto("en-US"), "ltr");
        assert_eq!(detectar_direccion_texto("es-AR"), "ltr");
    }
}
