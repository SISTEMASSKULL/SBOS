/// server/handlers/attr.rs — Handler del pipeline de atributos (método principal bi18n).
/// Propósito: pipeline completo raw → validate → transform → format → mask.
///   - Método central que bAuth invoca para CI/NIT/teléfono/email.
///   - Las funciones helper viven en attr_helpers.rs (DOC-SBOS-001 N3: split por tamaño).
/// Dependencias: crate::server::handlers, crate::domain, crate::error
use crate::{
    error::Resultado,
    server::context::ServerContext,
    domain::regional_config::RegionalConfig,
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
