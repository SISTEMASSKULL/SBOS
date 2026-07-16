/// server/handlers/format.rs — Handlers de formateo de fecha, número y moneda.
/// Propósito: formatea valores crudos en representaciones localizadas para el tenant.
///   - FormatDate: ICU4X DateTimeFormatter con datos CLDR embebidos (compiled_data).
///     Usa jiff para conversión zonal (IANA tzdb) → civil date/time → ICU4X.
///   - FormatNumber: separadores desde TOML del país (fuente de verdad).
///     Si no hay TOML disponible, fallback a ICU4X FixedDecimalFormatter.
///   - FormatMoney: símbolo y decimales desde country-rules TOML.
/// Utilidades internas (separadores, formatear_numero) → format_utils.rs (cohesión).
/// Dependencias: jiff, icu_datetime, icu_decimal, crate::domain, crate::server
use crate::{
    domain::{
        country_rules::IsoAlpha2,
        regional_config::RegionalConfig,
    },
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};
use super::format_utils::{formatear_numero, formatear_numero_por_locale, separadores};
use icu_datetime::{DateTimeFormatter, NoCalendarFormatter, fieldsets};
use icu_locale_core::Locale;
use writeable::Writeable;

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

/// Formatea un timestamp ISO 8601 (UTC) al locale del tenant con ICU4X + CLDR.
/// Convierte a la zona horaria del tenant con jiff (IANA tzdb), luego usa
/// DateTimeFormatter para producir texto localizado ("16 de julio de 2026").
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

    // Convertir a la zona horaria del tenant.
    let tz = jiff::tz::TimeZone::get(&regional.timezone)
        .map_err(|_| Bi18nError::ZonaHorariaInvalida {
            tz: regional.timezone.clone(),
            causa: "zona horaria no reconocida por jiff/IANA tzdb".to_string(),
        })?;
    let zdt = ts.to_zoned(tz);

    // Parsear locale BCP 47 del tenant; "und" como fallback seguro.
    let locale: Locale = regional.locale.parse()
        .unwrap_or_else(|_| "und".parse().expect("und es locale válido"));
    let prefs = locale.into();

    let display = format_con_icu(prefs, &zdt, granularidad)?;
    let _ = ctx;
    Ok(FormatDateResult { display })
}

/// Formatea una fecha/hora con ICU4X DateTimeFormatter (datos CLDR embebidos).
/// Cada granularidad usa un fieldset diferente y fallback al formato ISO básico.
fn format_con_icu(
    prefs: icu_datetime::DateTimeFormatterPreferences,
    zdt: &jiff::Zoned,
    granularidad: GranularidadFecha,
) -> Resultado<String> {
    let s = match granularidad {
        GranularidadFecha::SoloFecha => {
            let date = zdt.date();
            DateTimeFormatter::try_new(prefs, fieldsets::YMD::long())
                .map(|f| f.format(&date).write_to_string().into_owned())
                .unwrap_or_else(|_| format!("{:04}-{:02}-{:02}",
                    zdt.year(), zdt.month(), zdt.day()))
        }
        GranularidadFecha::FechaHora => {
            let dt = zdt.datetime();
            DateTimeFormatter::try_new(prefs, fieldsets::YMDT::medium())
                .map(|f| f.format(&dt).write_to_string().into_owned())
                .unwrap_or_else(|_| format!("{:04}-{:02}-{:02} {:02}:{:02}:{:02}",
                    zdt.year(), zdt.month(), zdt.day(),
                    zdt.hour(), zdt.minute(), zdt.second()))
        }
        GranularidadFecha::MesAnio => {
            let date = zdt.date();
            DateTimeFormatter::try_new(prefs, fieldsets::YM::long())
                .map(|f| f.format(&date).write_to_string().into_owned())
                .unwrap_or_else(|_| format!("{:04}-{:02}", zdt.year(), zdt.month()))
        }
        GranularidadFecha::SoloAnio => {
            let date = zdt.date();
            DateTimeFormatter::try_new(prefs, fieldsets::Y::medium())
                .map(|f| f.format(&date).write_to_string().into_owned())
                .unwrap_or_else(|_| format!("{:04}", zdt.year()))
        }
        GranularidadFecha::SoloHora => {
            let time = zdt.time();
            NoCalendarFormatter::try_new(prefs, fieldsets::T::short())
                .map(|f| f.format(&time).write_to_string().into_owned())
                .unwrap_or_else(|_| format!("{:02}:{:02}", zdt.hour(), zdt.minute()))
        }
    };
    Ok(s)
}

// ── FormatNumber ──────────────────────────────────────────────────────────────

/// Respuesta de formateo de número.
#[derive(Debug)]
pub struct FormatNumberResult {
    pub display: String,
}

/// Formatea un número decimal con los separadores del locale del tenant.
/// Prioridad: separadores de [numeracion] TOML del país → ICU4X FixedDecimalFormatter.
/// Bolivia: bo.toml define sep_decimal="." y sep_miles=",", que toma prioridad
/// sobre los datos CLDR (evita que es-BO sea interpretado como separadores europeos).
pub async fn format_number(
    ctx: &ServerContext,
    valor: &str,
    decimales: u32,
    regional: &RegionalConfig,
) -> Resultado<FormatNumberResult> {
    let n: f64 = valor.parse().map_err(|_| Bi18nError::FormatoDesconocido {
        codigo: format!("número inválido: '{}'", valor),
    })?;

    let iso    = IsoAlpha2::nuevo(&regional.country);
    let reglas = ctx.loader.obtener(&iso).await.ok();

    let display = if let Some(num) = reglas.as_ref().and_then(|r| r.numeracion.as_ref()) {
        // TOML del país tiene prioridad (fuente de verdad soberana)
        formatear_numero(n, decimales, &num.sep_decimal, &num.sep_miles)
    } else {
        // Sin TOML: inferir separadores desde moneda TOML o familia de locale BCP 47
        let seps = separadores(reglas.as_ref().and_then(|r| r.moneda.as_ref()), &regional.locale);
        formatear_numero_por_locale(n, decimales, seps)
    };

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

    let (simbolo, decimales, sep_dec, sep_miles): (String, u32, String, String) = match reglas.moneda {
        Some(m) if m.iso4217.eq_ignore_ascii_case(currency_code) || currency_code.is_empty() => {
            (m.simbolo_local, m.decimales as u32, m.sep_decimal.clone(), m.sep_miles.clone())
        }
        ref opt => {
            let (sd, sm) = separadores(opt.as_ref(), &regional.locale);
            (currency_code.to_string(), 2u32, sd, sm)
        }
    };

    let numero  = formatear_numero(n, decimales, &sep_dec, &sep_miles);
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
