/// server/handlers/lib_icu_decimal.rs — Handler A.08.05: icu_decimal 2.2.0
/// Propósito: expone los 4 métodos RPC del namespace `bi18n.format.number_*`
///   usando DecimalFormatter de ICU4X con reglas CLDR por locale.
/// Librería: icu_decimal 2.2.0 (feature: compiled_data)
/// Métodos RPC expuestos:
///   bi18n.format.number_icu · bi18n.format.number_no_grouping
///   bi18n.format.number_grouping_always · bi18n.format.number_grouping_min2
/// Entrada común: number (string numérico o entero) + locale (BCP-47).
/// Parámetro ctx_id: validado en el dispatcher antes de llegar aquí (SBOS-049).
/// Referencia: A.08.05_INVENTARIO-LIB-ICU-DECIMAL-v1.0.md · PLAN-FASE-2 §5
/// Dependencias: icu_decimal, icu_locale_core, serde_json, crate::error
use icu_decimal::{
    input::Decimal,
    options::{DecimalFormatterOptions, GroupingStrategy},
    DecimalFormatter,
};
use icu_locale_core::Locale;
use serde_json::{json, Value};
use crate::{error::Bi18nError, server::context::ServerContext};

/// Parsea el número desde el parámetro JSON: string decimal o entero.
fn parsear_decimal(params: &Value) -> Result<Decimal, Bi18nError> {
    if let Some(n) = params["number"].as_i64() {
        return Ok(Decimal::from(n));
    }
    if let Some(s) = params["number"].as_str() {
        return s.parse::<Decimal>().map_err(|e| Bi18nError::FormatoDesconocido {
            codigo: format!("número inválido '{s}': {e}"),
        });
    }
    Err(Bi18nError::ParamAusente { param: "number".to_string() })
}

/// Parsea locale BCP-47 y construye el formatter ICU con la estrategia de agrupación dada.
fn formatear_con_estrategia(
    locale_str: &str,
    decimal: &Decimal,
    estrategia: GroupingStrategy,
) -> Result<String, Bi18nError> {
    let locale: Locale = locale_str.parse().map_err(|_| Bi18nError::LocaleInvalido {
        locale: locale_str.to_string(),
        causa: "BCP-47 inválido".to_string(),
    })?;
    let opciones = DecimalFormatterOptions::from(estrategia);
    let fmt = DecimalFormatter::try_new((&locale).into(), opciones)
        .map_err(|e| Bi18nError::LocaleInvalido {
            locale: locale_str.to_string(),
            causa: e.to_string(),
        })?;
    Ok(fmt.format(decimal).to_string())
}

/// Formatea un número con agrupación automática según las reglas del locale.
/// Para "es-BO": 1000000 → "1.000.000". Para "en-US": "1,000,000".
/// Entrada: `{ "number": 1000007, "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "display": "1.000.007", "locale": "es-BO" }`.
pub async fn format_number_icu(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let decimal = parsear_decimal(params)?;
    let display = formatear_con_estrategia(locale_str, &decimal, GroupingStrategy::Auto)?;
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea un número sin separadores de grupo (siempre sin comas ni puntos de miles).
/// Útil para campos técnicos, IDs, o cantidades sin formato cultural.
/// Entrada: `{ "number": 1000007, "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "display": "1000007", "locale": "es-BO" }`.
pub async fn format_number_no_grouping(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let decimal = parsear_decimal(params)?;
    let display = formatear_con_estrategia(locale_str, &decimal, GroupingStrategy::Never)?;
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea un número con agrupación siempre (incluso para números como 999 → "999" o "9.99").
/// En la práctica, para DecimalFormatter, Always se comporta como Auto.
/// Entrada: `{ "number": "1234.56", "locale": "fr-FR", "ctx_id": "..." }`.
/// Salida: `{ "display": "1\u{202f}234,56", "locale": "fr-FR" }`.
pub async fn format_number_grouping_always(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let decimal = parsear_decimal(params)?;
    let display = formatear_con_estrategia(locale_str, &decimal, GroupingStrategy::Always)?;
    Ok(json!({ "display": display, "locale": locale_str }))
}

/// Formatea un número con agrupación solo cuando hay 5+ dígitos (Min2 = mínimo 2 grupos).
/// Para "es-BO": 1234 → "1234" (sin separar); 12345 → "12.345".
/// Entrada: `{ "number": 12345, "locale": "es-BO", "ctx_id": "..." }`.
/// Salida: `{ "display": "12.345", "locale": "es-BO" }`.
pub async fn format_number_grouping_min2(_ctx: &ServerContext, params: &Value) -> Result<Value, Bi18nError> {
    let locale_str = params["locale"].as_str().unwrap_or("es-BO");
    let decimal = parsear_decimal(params)?;
    let display = formatear_con_estrategia(locale_str, &decimal, GroupingStrategy::Min2)?;
    Ok(json!({ "display": display, "locale": locale_str }))
}
