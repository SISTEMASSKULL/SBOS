/// server/handlers/format.rs — Handlers de formateo de fecha, número y moneda.
/// Propósito: formatea valores crudos en representaciones localizadas para el tenant.
///   - FormatDate: jiff para conversión zonal (ICU4X en Fase 3).
///   - FormatNumber: separadores desde TOML del país vía format_utils.
///   - FormatMoney: símbolo y decimales desde country-rules TOML.
/// Utilidades internas (separadores, formatear_numero) → format_utils.rs (DOC-SBOS-001 N3).
/// Dependencias: jiff, crate::domain, crate::server
use crate::{
    domain::{
        country_rules::IsoAlpha2,
        regional_config::RegionalConfig,
    },
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};
use super::format_utils::{formatear_numero, separadores};

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
    ctx: &ServerContext,
    valor: &str,
    decimales: u32,
    regional: &RegionalConfig,
) -> Resultado<FormatNumberResult> {
    let n: f64 = valor.parse().map_err(|_| Bi18nError::FormatoDesconocido {
        codigo: format!("número inválido: '{}'", valor),
    })?;

    // Preferir separadores de [numeracion] del TOML del país (evita inferencia errónea por locale).
    let iso   = crate::domain::country_rules::IsoAlpha2::nuevo(&regional.country);
    let reglas = ctx.loader.obtener(&iso).await.ok();
    let (sep_dec, sep_miles) = match reglas.as_ref().and_then(|r| r.numeracion.as_ref()) {
        Some(num) => (num.sep_decimal.clone(), num.sep_miles.clone()),
        None      => separadores(reglas.as_ref().and_then(|r| r.moneda.as_ref()), &regional.locale),
    };

    let display = formatear_numero(n, decimales, &sep_dec, &sep_miles);
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
            (m.simbolo_local, m.decimales as u32, m.sep_decimal.clone(), m.sep_miles.clone())
        }
        ref opt => {
            // Fallback: separadores desde reglas de moneda (si existen) o por locale.
            let (sd, sm) = separadores(opt.as_ref(), &regional.locale);
            (currency_code.to_string(), 2u32, sd, sm)
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

