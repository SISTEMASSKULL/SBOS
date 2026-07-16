/// server/handlers/snapshot.rs — Snapshot completo de configuración regional.
/// Propósito: devuelve en una sola llamada todo lo que un daemon hermano necesita
///   para operar en el contexto regional del tenant: hora actual convertida,
///   locale, moneda con separadores, país, teléfono, enums y documentos.
///   Evita que bAuth, bpay u otros daemons hagan N llamadas para obtener
///   la misma información que bi18n ya tiene consolidada.
/// Dependencias: crate::domain, handlers::format, crate::error
use serde_json::Value;
use crate::{
    domain::{
        country_rules::IsoAlpha2,
        regional_config::RegionalConfig,
    },
    error::Resultado,
    server::context::ServerContext,
};
use super::format::{format_fecha_o_ahora, GranularidadFecha};

/// Resultado del snapshot regional completo.
pub struct SnapshotResult {
    pub payload: Value,
}

/// Construye el snapshot regional completo para el tenant indicado.
/// Combina: hora actual (jiff IANA) + RegionalConfig + CountryRules TOML.
pub async fn regional_snapshot(
    ctx: &ServerContext,
    tenant_id: &str,
    branch_id: Option<&str>,
    user_id: Option<&str>,
) -> Resultado<SnapshotResult> {
    let regional = ctx.resolver.resolver(tenant_id, branch_id, user_id).await?;
    let iso      = IsoAlpha2::nuevo(&regional.country);
    let reglas   = ctx.loader.obtener(&iso).await?;

    let ahora = format_fecha_o_ahora(
        ctx, None, GranularidadFecha::FechaHora, &regional,
    ).await?;
    let hora = format_fecha_o_ahora(
        ctx, None, GranularidadFecha::SoloHora, &regional,
    ).await?;

    let moneda = reglas.moneda.as_ref().map(|m| serde_json::json!({
        "iso4217":       m.iso4217,
        "simbolo_local": m.simbolo_local,
        "simbolo_intl":  m.simbolo_intl,
        "decimales":     m.decimales,
        "sep_decimal":   m.sep_decimal,
        "sep_miles":     m.sep_miles,
    })).unwrap_or(serde_json::json!({ "iso4217": regional.currency }));

    let pais = reglas.pais.as_ref().map(|p| serde_json::json!({
        "iso_alpha2":      p.iso_alpha2,
        "iso_alpha3":      p.iso_alpha3,
        "codigo_telefono": p.codigo_telefono,
        "locale_defecto":  p.locale_defecto,
        "tz_defecto":      p.tz_defecto,
        "ltr":             p.ltr,
    })).unwrap_or(serde_json::json!({ "iso_alpha2": regional.country }));

    let payload = serde_json::json!({
        "ahora":    ahora.display,
        "hora":     hora.display,
        "timezone": regional.timezone,
        "locale":   regional.locale,
        "currency": regional.currency,
        "country":  regional.country,
        "pais":     pais,
        "moneda":   moneda,
        "enums":    reglas.enums,
        "documentos": reglas.documentos.keys().collect::<Vec<_>>(),
    });

    Ok(SnapshotResult { payload })
}
