/// server/dispatcher_helpers.rs — Parseo de parámetros JSON-RPC a tipos de dominio.
/// Propósito: convierte strings del wire-format JSON-RPC a enums Rust del dominio.
///   - EstrategiaMascara: "partial(4)", "full", "partial_both(2,3)", "from_country_rule"
///   - TipoDocumento: "CI", "NIT", "DNI", "PASSPORT", etc.
///   - Transformacion[]: ["uppercase", "strip_hyphen", ...]
///   - RegionalConfig: desde params inline o via resolver de tenant.
/// Convención wire format (1.01 §7.3): cadenas como "partial(4)", "partial_both(2,2)".
/// Dependencias: serde_json, crate::domain, crate::server
use serde_json::Value;
use crate::{
    domain::regional_config::RegionalConfig,
    error::Resultado,
    server::{
        context::ServerContext,
        handlers::{
            attr::Transformacion,
            mask::EstrategiaMascara,
            validate::TipoDocumento,
        },
    },
};

/// Parsea una estrategia de máscara desde el wire-format de cadena (1.01 §7.3).
/// Formas válidas: "none", "full", "partial(N)", "partial_prefix(N)", "partial_both(P,S)", "from_country_rule".
pub fn parsear_estrategia_mascara(s: &str) -> EstrategiaMascara {
    let s = s.trim();
    match s {
        "none"              => return EstrategiaMascara::Ninguna,
        "full"              => return EstrategiaMascara::Completa,
        "from_country_rule" => return EstrategiaMascara::ReglaPais,
        _ => {}
    }

    if let Some(int) = s.strip_prefix("partial_both(").and_then(|s| s.strip_suffix(')')) {
        let v: Vec<u32> = int.split(',').filter_map(|p| p.trim().parse().ok()).collect();
        if v.len() == 2 {
            return EstrategiaMascara::Ambos { prefix_visible: v[0], suffix_visible: v[1] };
        }
    }
    if let Some(int) = s.strip_prefix("partial_prefix(").and_then(|s| s.strip_suffix(')')) {
        if let Ok(n) = int.trim().parse() {
            return EstrategiaMascara::Prefijo { n };
        }
    }
    if let Some(int) = s.strip_prefix("partial(").and_then(|s| s.strip_suffix(')')) {
        if let Ok(n) = int.trim().parse() {
            return EstrategiaMascara::Parcial { n };
        }
    }
    EstrategiaMascara::Ninguna
}

/// Extrae (mask_n, mask_prefix, mask_suffix) del enum ya parseado.
/// Necesario para alimentar los parámetros separados de handlers::attr::pipeline.
pub fn extraer_params_mascara(e: &EstrategiaMascara) -> (u32, u32, u32) {
    match e {
        EstrategiaMascara::Parcial { n } | EstrategiaMascara::Prefijo { n } => (*n, 0, 0),
        EstrategiaMascara::Ambos { prefix_visible, suffix_visible } => (0, *prefix_visible, *suffix_visible),
        _ => (0, 0, 0),
    }
}

/// Parsea un tipo de documento desde string (insensible a mayúsculas).
pub fn parsear_tipo_documento(s: &str) -> TipoDocumento {
    match s.trim().to_uppercase().as_str() {
        "NIT"      => TipoDocumento::Nit,
        "CPF"      => TipoDocumento::Cpf,
        "CNPJ"     => TipoDocumento::Cnpj,
        "DNI"      => TipoDocumento::Dni,
        "CUIT"     => TipoDocumento::Cuit,
        "PASSPORT" => TipoDocumento::Passport,
        _          => TipoDocumento::Ci,
    }
}

/// Parsea un array JSON de strings a lista de transformaciones.
/// Strings desconocidos se ignoran silenciosamente.
pub fn parsear_transformaciones(arr: &Value) -> Vec<Transformacion> {
    arr.as_array()
        .map(|v| v.iter().filter_map(|e| e.as_str()).filter_map(parsear_una).collect())
        .unwrap_or_default()
}

fn parsear_una(s: &str) -> Option<Transformacion> {
    match s {
        "uppercase"     => Some(Transformacion::Mayusculas),
        "lowercase"     => Some(Transformacion::Minusculas),
        "title_case"    => Some(Transformacion::TituloCase),
        "trim"          => Some(Transformacion::Trim),
        "strip_hyphen"  => Some(Transformacion::QuitarGuiones),
        "strip_spaces"  => Some(Transformacion::QuitarEspacios),
        "strip_accents" => Some(Transformacion::QuitarAcentos),
        "digits_only"   => Some(Transformacion::SoloDigitos),
        "alpha_only"    => Some(Transformacion::SoloLetras),
        _               => None,
    }
}

/// Resuelve RegionalConfig desde params del request.
/// Prioridad: `regional_config` inline → `tenant_id` vía resolver estático.
pub async fn regional_desde_params(params: &Value, ctx: &ServerContext) -> Resultado<RegionalConfig> {
    if let Some(rc) = params.get("regional_config") {
        if rc.get("locale").and_then(|v| v.as_str()).is_some() {
            return Ok(RegionalConfig {
                locale:   rc["locale"].as_str().unwrap_or("es-BO").to_string(),
                timezone: rc["timezone"].as_str().unwrap_or("America/La_Paz").to_string(),
                currency: rc["currency"].as_str().unwrap_or("BOB").to_string(),
                country:  rc["country"].as_str().unwrap_or("BO").to_string(),
            });
        }
    }
    let tenant_id = params["tenant_id"].as_str().unwrap_or("");
    ctx.resolver.resolver(tenant_id, None, None).await
}
