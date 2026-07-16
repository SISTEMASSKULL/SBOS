/// server/handlers/enums.rs — Handler de traducción de enums de negocio.
/// Propósito: traduce valores de enum canónicos a etiquetas localizadas.
///   - Los catálogos se cargan desde country-rules TOML (sección [enums]).
///   - Si no se encuentra: retorna el valor original como fallback.
///   - Ejemplo: ("gender", "M", es-BO) → "Masculino"
/// Dependencias: crate::server::context, crate::domain, crate::error
use crate::{error::Resultado, server::context::ServerContext};

/// Resultado de la traducción de enum.
#[derive(Debug)]
pub struct EnumDisplayResult {
    pub label: String,
    pub found: bool,
    pub fallback: String,
}

/// Traduce un valor de enum de negocio a su etiqueta localizada.
pub async fn display(
    _ctx: &ServerContext,
    enum_name: &str,
    valor: &str,
    locale: &str,
) -> Resultado<EnumDisplayResult> {
    // Catálogo embebido para los enums más frecuentes (Fase 2: desde TOML).
    let label = buscar_en_catalogo_embebido(enum_name, valor, locale);

    match label {
        Some(etiqueta) => Ok(EnumDisplayResult {
            label: etiqueta,
            found: true,
            fallback: String::new(),
        }),
        None => Ok(EnumDisplayResult {
            label: valor.to_string(),
            found: false,
            fallback: valor.to_string(),
        }),
    }
}

/// Busca la etiqueta en el catálogo embebido (MVP).
/// En Fase 2 se reemplaza por lectura desde los TOML de country-rules.
fn buscar_en_catalogo_embebido(enum_name: &str, valor: &str, locale: &str) -> Option<String> {
    let es = locale.starts_with("es");

    match (enum_name, valor) {
        ("gender", "M") | ("genero", "M")  => Some(if es { "Masculino" } else { "Male" }.to_string()),
        ("gender", "F") | ("genero", "F")  => Some(if es { "Femenino" } else { "Female" }.to_string()),
        ("gender", "O") | ("genero", "O")  => Some(if es { "Otro" } else { "Other" }.to_string()),

        ("marital_status", "SINGLE")   => Some(if es { "Soltero/a" } else { "Single" }.to_string()),
        ("marital_status", "MARRIED")  => Some(if es { "Casado/a" } else { "Married" }.to_string()),
        ("marital_status", "DIVORCED") => Some(if es { "Divorciado/a" } else { "Divorced" }.to_string()),
        ("marital_status", "WIDOWED")  => Some(if es { "Viudo/a" } else { "Widowed" }.to_string()),

        ("employment_type", "FULL_TIME")  => Some(if es { "Tiempo completo" } else { "Full-time" }.to_string()),
        ("employment_type", "PART_TIME")  => Some(if es { "Medio tiempo" } else { "Part-time" }.to_string()),
        ("employment_type", "FREELANCE")  => Some(if es { "Independiente" } else { "Freelance" }.to_string()),
        ("employment_type", "UNEMPLOYED") => Some(if es { "Desempleado/a" } else { "Unemployed" }.to_string()),

        ("status", "ACTIVE")   => Some(if es { "Activo" } else { "Active" }.to_string()),
        ("status", "INACTIVE") => Some(if es { "Inactivo" } else { "Inactive" }.to_string()),
        ("status", "PENDING")  => Some(if es { "Pendiente" } else { "Pending" }.to_string()),
        ("status", "BLOCKED")  => Some(if es { "Bloqueado" } else { "Blocked" }.to_string()),

        _ => None,
    }
}
