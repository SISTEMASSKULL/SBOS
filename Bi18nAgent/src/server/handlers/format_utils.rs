/// server/handlers/format_utils.rs — Utilidades internas de formateo numérico.
/// Propósito: funciones puras de cálculo extraídas de format.rs (cohesión lógica).
///   - separadores(): elige sep_decimal/sep_miles desde TOML o por inferencia de locale.
///   - formatear_numero(): aplica separadores de miles y decimales a un f64 (fuente TOML).
/// Diseño: las reglas TOML del país SIEMPRE prevalecen sobre la inferencia por locale.
///   Bolivia usa "." decimal (bo.toml) aunque el locale CLDR de es-BO diga coma.
///   Cuando no hay TOML disponible, se infiere el separador desde la familia de locale BCP 47.
///   La crate icu_decimal se reserva para números con lógica de agrupación no estándar
///   (ej: formato hindú) — no se usa aquí para no depender del feature "ryu" (f64→Decimal).
/// Dependencias: crate::domain::country_rules (MonedaRules)
use crate::domain::country_rules::MonedaRules;

/// Retorna (sep_decimal, sep_miles) desde country-rules o, como fallback,
/// inferido del locale BCP 47. Las reglas TOML siempre prevalecen.
pub(crate) fn separadores(moneda: Option<&MonedaRules>, locale: &str) -> (String, String) {
    if let Some(m) = moneda {
        return (m.sep_decimal.clone(), m.sep_miles.clone());
    }
    // Fallback: punto decimal en en-* y zh-*; coma en el resto.
    let usa_punto = locale.starts_with("en") || locale.starts_with("zh");
    if usa_punto { (".".into(), ",".into()) } else { (",".into(), ".".into()) }
}

/// Formatea un f64 con separadores de miles y decimales arbitrarios.
/// Entrada canónica: punto decimal (ej: `1234567.89`).
/// Salida: representación localizada (ej: `"1,234,567.89"` para Bolivia/US).
pub(crate) fn formatear_numero(n: f64, decimales: u32, sep_dec: &str, sep_miles: &str) -> String {
    let factor       = 10_u64.pow(decimales) as f64;
    let redondeado   = (n * factor).round() / factor;
    let parte_entera = redondeado.abs() as u64;
    let signo        = if n < 0.0 { "-" } else { "" };

    // Insertar separador de miles cada 3 dígitos de derecha a izquierda.
    let entero_str = parte_entera.to_string();
    let con_miles: String = entero_str
        .chars()
        .rev()
        .enumerate()
        .flat_map(|(i, c)| {
            if i > 0 && i % 3 == 0 {
                vec![sep_miles.chars().next().unwrap_or(','), c]
            } else {
                vec![c]
            }
        })
        .collect::<String>()
        .chars()
        .rev()
        .collect();

    if decimales > 0 {
        let parte_dec = ((redondeado.abs() - parte_entera as f64) * factor).round() as u64;
        format!("{}{}{}{:0>width$}", signo, con_miles, sep_dec, parte_dec, width = decimales as usize)
    } else {
        format!("{}{}", signo, con_miles)
    }
}

/// Formatea un número usando separadores inferidos del locale BCP 47.
/// Fallback de format_number cuando no hay reglas TOML del país cargadas.
/// Recibe la tupla ya calculada por separadores() para evitar recalcular.
pub(crate) fn formatear_numero_por_locale(
    n: f64,
    decimales: u32,
    seps: (String, String),
) -> String {
    formatear_numero(n, decimales, &seps.0, &seps.1)
}
