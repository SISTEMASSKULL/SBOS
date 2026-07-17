/// server/handlers/attr.rs — Handlers del pipeline y configuración de atributos.
/// Propósito: pipeline completo raw → validate → transform → format → mask,
///   y consultas de configuración de formato (mask_pattern, display_format) para UX.
///   - pipeline(): método central que bAuth invoca para CI/NIT/teléfono/email.
///   - config() / config_batch(): configuración liviana de campo para widgets (A.02 §3.2).
///     config() ahora incluye input_mask (máscara de formulario del locale BCP 47 §7.2).
/// Dependencias: crate::server::handlers, crate::domain, crate::error
use crate::{
    error::Resultado,
    server::context::ServerContext,
    domain::{regional_config::RegionalConfig, input_mask},
};
use super::attr_helpers::{aplicar_transformaciones, ejecutar_formato, ejecutar_validacion};

/// Transformaciones de texto aplicables en el pipeline (espejo del proto Transform enum).
#[derive(Debug, Clone, Copy)]
pub enum Transformacion {
    Mayusculas,
    Minusculas,
    TituloCase,
    Trim,
    QuitarGuiones,
    QuitarEspacios,
    QuitarAcentos,
    SoloDigitos,
    SoloLetras,
    RellenarIzquierda { largo: usize, caracter: char },
    RellenarDerecha   { largo: usize, caracter: char },
}

/// Resultado completo del pipeline de atributos.
#[derive(Debug)]
pub struct AttrPipelineResult {
    pub raw: String,
    pub valid: bool,
    pub transformed: String,
    pub display: String,
    pub masked: String,
    pub enum_label: String,
    pub errores_validacion: Vec<String>,
}

/// Ejecuta el pipeline completo: raw → validate → transform → format → mask.
pub async fn pipeline(
    ctx: &ServerContext,
    key: &str,
    valor: &str,
    validate_format: &str,
    transforms: &[Transformacion],
    format_code: &str,
    mascara: crate::server::handlers::mask::EstrategiaMascara,
    mask_n: u32,
    mask_prefix_visible: u32,
    mask_suffix_visible: u32,
    regional: &RegionalConfig,
) -> Resultado<AttrPipelineResult> {
    let raw = valor.to_string();

    let (valid, errores_val) = if !validate_format.is_empty() {
        ejecutar_validacion(ctx, validate_format, &raw, regional).await?
    } else {
        (true, vec![])
    };

    let transformed = aplicar_transformaciones(&raw, transforms);

    let display = if !format_code.is_empty() {
        ejecutar_formato(ctx, format_code, &transformed, regional)
            .await.unwrap_or_else(|_| transformed.clone())
    } else {
        transformed.clone()
    };

    let mascara_efecto = match mascara {
        crate::server::handlers::mask::EstrategiaMascara::Parcial { .. } if mask_n > 0 =>
            crate::server::handlers::mask::EstrategiaMascara::Parcial { n: mask_n },
        crate::server::handlers::mask::EstrategiaMascara::Prefijo { .. } if mask_n > 0 =>
            crate::server::handlers::mask::EstrategiaMascara::Prefijo { n: mask_n },
        crate::server::handlers::mask::EstrategiaMascara::Ambos { .. } =>
            crate::server::handlers::mask::EstrategiaMascara::Ambos {
                prefix_visible: mask_prefix_visible,
                suffix_visible: mask_suffix_visible,
            },
        otra => otra,
    };

    let masked = crate::server::handlers::mask::mask_value(
        ctx, &display, mascara_efecto, &regional.country, Some(key),
    ).await?.masked;

    Ok(AttrPipelineResult {
        raw, valid, transformed, display, masked,
        enum_label: String::new(),
        errores_validacion: errores_val,
    })
}

// ── Config liviana de atributo ────────────────────────────────────────────────

/// Resultado de consulta de configuración de formato (A.02 §3.2).
/// No ejecuta validación — devuelve solo lo necesario para configurar un widget cliente.
pub struct AttrConfigResult {
    /// Código de formato canónico. Ejemplo: "ID_BO", "E164", "DATE_ISO"
    pub display_format: String,
    /// Perfil de validación que el cliente devuelve en attr.pipeline (contrato A.04 §3).
    /// En esta versión es igual a display_format — campo explícito para extensibilidad futura.
    pub validator_profile: String,
    /// Patrón de máscara de entrada estructural (9=dígito, A=letra, literales).
    /// Ejemplo: "9999999-AA" para CI boliviana, "99/99/9999" para fecha en es-BO.
    pub mask_pattern: String,
    /// Máscara de formulario derivada del locale BCP 47 (manual 1.01 §7.2).
    /// Ejemplo: "99/99/9999" para fecha con locale "es-BO".
    pub input_mask: String,
    /// Indica si el valor contiene PII y debe enmascararse al almacenar o mostrar.
    pub masks_pii: bool,
}

/// Retorna la configuración de formato de un atributo dado su código y locale.
/// Operación síncrona — consulta el format_map estático e input_mask por locale.
pub fn config(display_format: &str, locale: &str) -> AttrConfigResult {
    use crate::domain::format_map;

    // Formatos que contienen PII: documentos de identidad y contacto personal.
    let masks_pii = matches!(
        display_format,
        "ID_BO" | "TAX_BO" | "DNI_AR" | "CUIT_AR"
        | "CPF_BR" | "CNPJ_BR" | "PASSPORT" | "EMAIL" | "E164"
    );

    let mask_pattern = format_map::obtener(display_format)
        .map(|s| s.patron.to_string())
        .unwrap_or_default();

    // Derivar máscara de formulario desde locale BCP 47 (§7.2)
    let input_mask_str = match display_format {
        "DATE_ISO" | "DATE_LOCAL" | "FECHA"         => input_mask::mascara_fecha(locale).patron.to_string(),
        "DATETIME" | "FECHA_HORA"                   => input_mask::mascara_fecha_hora(locale),
        "TIME" | "HORA"                             => input_mask::mascara_hora(locale).to_string(),
        "YEARMONTH" | "MES_ANIO"                    => input_mask::mascara_mes_anio(locale).to_string(),
        "YEAR" | "ANIO"                             => input_mask::mascara_anio(locale).to_string(),
        // Para formatos no temporales, la mask_pattern estructural ya es la máscara de input
        _                                           => mask_pattern.clone(),
    };

    AttrConfigResult {
        display_format: display_format.to_string(),
        validator_profile: display_format.to_string(),
        mask_pattern,
        input_mask: input_mask_str,
        masks_pii,
    }
}

/// Construye el payload JSON del config_batch desde el array `fields` del request.
/// Retorna un mapa key → config listo para serializar (A.02 §3.3).
pub fn config_batch_desde_json(
    fields: &serde_json::Value,
    locale: &str,
    _country: &str,
) -> serde_json::Value {
    let arr = match fields.as_array() {
        Some(a) => a,
        None    => return serde_json::json!({}),
    };

    let mut mapa = serde_json::Map::new();
    for campo in arr {
        let key            = campo["key"].as_str().unwrap_or("");
        let display_format = campo["display_format"].as_str().unwrap_or("");
        let r = config(display_format, locale);
        mapa.insert(key.to_string(), serde_json::json!({
            "display_format":    r.display_format,
            "validator_profile": r.validator_profile,
            "mask_pattern":      r.mask_pattern,
            "input_mask":        r.input_mask,
            "masks_pii":         r.masks_pii,
        }));
    }
    serde_json::Value::Object(mapa)
}
