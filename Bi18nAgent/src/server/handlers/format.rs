/// server/handlers/format.rs — Handlers de formateo de fecha, número y moneda.
/// Propósito: formatea valores crudos en representaciones localizadas para el tenant.
///   - FormatDate: ICU4X icu_datetime + jiff para cálculo zonal.
///   - FormatNumber: ICU4X icu_decimal con separadores del locale.
///   - FormatMoney: símbolo y decimales desde country-rules TOML.
/// Dependencias: jiff, icu_datetime, icu_decimal, icu_locale_core, crate::domain
use crate::{
    domain::{
        country_rules::IsoAlpha2,
        regional_config::RegionalConfig,
    },
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};

// ── FormatDate ────────────────────────────────────────────────────────────────

/// Granularidad de presentación de fecha.
#[derive(Debug, Clone, Copy)]
pub enum GranularidadFecha {
    FechaHora,
    SoloFecha,
    MesAnio,
    SoloAnio,
    SoloHora,
}

/// Respuesta de formateo de fecha.
#[derive(Debug)]
pub struct FormatDateResult {
    pub display: String,
}

/// Formatea un timestamp ISO 8601 (UTC) al locale del tenant.
pub async fn format_date(
    ctx: &ServerContext,
    iso_datetime: &str,
    granularidad: GranularidadFecha,
    regional: &RegionalConfig,
) -> Resultado<FormatDateResult> {
    // Parsear el timestamp con jiff (IANA tzdb integrado).
    let ts = iso_datetime.parse::<jiff::Timestamp>()
        .map_err(|e| Bi18nError::FechaInvalida {
            valor: iso_datetime.to_string(),
            causa: e.to_string(),
        })?;

    // Convertir a la zona horaria del tenant (jiff 0.2: TimeZone::get, no FromStr).
    let tz = jiff::tz::TimeZone::get(&regional.timezone)
        .map_err(|_| Bi18nError::ZonaHorariaInvalida {
            tz: regional.timezone.clone(),
            causa: "zona horaria no reconocida por jiff/IANA tzdb".to_string(),
        })?;
    let zdt = ts.to_zoned(tz);

    // Formateo simple según granularidad (ICU4X en Fase 2).
    let display = match granularidad {
        GranularidadFecha::SoloFecha => {
            format!("{:04}-{:02}-{:02}", zdt.year(), zdt.month(), zdt.day())
        }
        GranularidadFecha::FechaHora => {
            format!(
                "{:04}-{:02}-{:02} {:02}:{:02}:{:02}",
                zdt.year(), zdt.month(), zdt.day(),
                zdt.hour(), zdt.minute(), zdt.second()
            )
        }
        GranularidadFecha::MesAnio => {
            format!("{:04}-{:02}", zdt.year(), zdt.month())
        }
        GranularidadFecha::SoloAnio => {
            format!("{:04}", zdt.year())
        }
        GranularidadFecha::SoloHora => {
            format!("{:02}:{:02}", zdt.hour(), zdt.minute())
        }
    };

    let _ = ctx; // ctx disponible para auditoría futura
    Ok(FormatDateResult { display })
}

// ── FormatNumber ──────────────────────────────────────────────────────────────

/// Respuesta de formateo de número.
#[derive(Debug)]
pub struct FormatNumberResult {
    pub display: String,
}

/// Formatea un número decimal con los separadores del locale del tenant.
pub async fn format_number(
    _ctx: &ServerContext,
    valor: &str,
    decimales: u32,
    regional: &RegionalConfig,
) -> Resultado<FormatNumberResult> {
    // Parsear el número canónico (punto como separador decimal).
    let n: f64 = valor.parse().map_err(|_| Bi18nError::FormatoDesconocido {
        codigo: format!("número inválido: '{}'", valor),
    })?;

    // Separadores por locale (ICU4X en Fase 2 — aquí lógica básica).
    let (sep_dec, sep_miles) = separadores_por_locale(&regional.locale);

    let display = formatear_numero(n, decimales, sep_dec, sep_miles);
    Ok(FormatNumberResult { display })
}

// ── FormatMoney ───────────────────────────────────────────────────────────────

/// Respuesta de formateo de moneda.
#[derive(Debug)]
pub struct FormatMoneyResult {
    pub display: String,
    pub symbol_local: String,
}

/// Formatea un monto con el símbolo y decimales del país del tenant.
pub async fn format_money(
    ctx: &ServerContext,
    monto: &str,
    currency_code: &str,
    regional: &RegionalConfig,
) -> Resultado<FormatMoneyResult> {
    let n: f64 = monto.parse().map_err(|_| Bi18nError::FormatoDesconocido {
        codigo: format!("monto inválido: '{}'", monto),
    })?;

    let iso = IsoAlpha2::nuevo(&regional.country);
    let reglas = ctx.loader.obtener(&iso).await?;

    // String owned en cada rama para evitar lifetime cruzado entre los brazos del match.
    let (simbolo, decimales, sep_dec, sep_miles): (String, u32, String, String) = match reglas.moneda {
        Some(m) if m.iso4217.eq_ignore_ascii_case(currency_code) || currency_code.is_empty() => {
            (m.simbolo_local, m.decimales as u32, m.sep_decimal, m.sep_miles)
        }
        _ => {
            // Fallback genérico cuando el país no define la moneda solicitada.
            let (sd, sm) = separadores_por_locale(&regional.locale);
            (currency_code.to_string(), 2u32, sd.to_string(), sm.to_string())
        }
    };

    let numero = formatear_numero(n, decimales, &sep_dec, &sep_miles);
    let display = format!("{} {}", simbolo, numero);
    Ok(FormatMoneyResult { display, symbol_local: simbolo })
}

// ── Helpers de conveniencia ───────────────────────────────────────────────────

/// Formatea la hora actual (o un timestamp opcional) en la zona del tenant.
/// `iso_datetime = None` → usa jiff::Timestamp::now().
pub async fn format_fecha_o_ahora(
    ctx: &ServerContext,
    iso_datetime: Option<&str>,
    granularidad: GranularidadFecha,
    regional: &RegionalConfig,
) -> Resultado<FormatDateResult> {
    let owned;
    let ts_str = match iso_datetime {
        Some(s) => s,
        None => {
            owned = jiff::Timestamp::now().to_string();
            &owned
        }
    };
    format_date(ctx, ts_str, granularidad, regional).await
}

// ── Utilidades internas ───────────────────────────────────────────────────────

/// Retorna (sep_decimal, sep_miles) según el locale BCP 47.
fn separadores_por_locale(locale: &str) -> (&'static str, &'static str) {
    // Locales con coma decimal: la mayoría de Europa y América Latina.
    // Locales con punto decimal: en-US, en-GB, zh-CN, etc.
    let usa_coma = !locale.starts_with("en") && !locale.starts_with("zh");
    if usa_coma { (",", ".") } else { (".", ",") }
}

/// Formatea un número con los separadores dados.
fn formatear_numero(n: f64, decimales: u32, sep_dec: &str, sep_miles: &str) -> String {
    let factor = 10_u64.pow(decimales) as f64;
    let redondeado = (n * factor).round() / factor;
    let parte_entera = redondeado.abs() as u64;
    let signo = if n < 0.0 { "-" } else { "" };

    // Aplicar separador de miles.
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
