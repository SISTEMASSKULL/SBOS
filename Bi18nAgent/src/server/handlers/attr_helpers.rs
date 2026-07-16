/// server/handlers/attr_helpers.rs — Helpers del pipeline de atributos.
/// Propósito: funciones auxiliares de validación, formateo y transformación de texto.
///   - Extraídas de attr.rs para mantener ≤200 líneas por módulo (DOC-SBOS-001 N3).
///   - Visibilidad pub(super): solo attr.rs las usa directamente.
/// Dependencias: crate::domain, crate::server::context, crate::error
use crate::{
    domain::regional_config::RegionalConfig,
    error::Resultado,
    server::{
        context::ServerContext,
        handlers::{
            format::{format_date, format_money, GranularidadFecha},
            validate::{validate_email, validate_national_id, validate_phone, TipoDocumento},
        },
    },
};

/// Ejecuta la validación correspondiente al formato solicitado.
pub(crate) async fn ejecutar_validacion(
    ctx: &ServerContext,
    formato: &str,
    valor: &str,
    regional: &RegionalConfig,
) -> Resultado<(bool, Vec<String>)> {
    match formato {
        "EMAIL" => {
            let r = validate_email(ctx, valor).await?;
            Ok((r.valid, r.errores))
        }
        "E164" => {
            let r = validate_phone(ctx, valor, &regional.country).await?;
            Ok((r.valid, r.errores))
        }
        "ID_BO" => {
            let r = validate_national_id(ctx, TipoDocumento::Ci, valor, &regional.country).await?;
            Ok((r.valid, r.errores))
        }
        "TAX_BO" => {
            let r = validate_national_id(ctx, TipoDocumento::Nit, valor, &regional.country).await?;
            Ok((r.valid, r.errores))
        }
        _ => {
            use crate::domain::format_map;
            match format_map::obtener(formato) {
                Some(spec) if !spec.regex_validacion.is_empty() => {
                    let re = regex::Regex::new(spec.regex_validacion)
                        .map_err(|_| crate::error::Bi18nError::FormatoDesconocido {
                            codigo: formato.to_string(),
                        })?;
                    if re.is_match(valor) {
                        Ok((true, vec![]))
                    } else {
                        Ok((false, vec![format!("Formato inválido para '{}'", formato)]))
                    }
                }
                _ => Ok((true, vec![])),
            }
        }
    }
}

/// Aplica el formato de presentación al valor transformado.
pub(crate) async fn ejecutar_formato(
    ctx: &ServerContext,
    formato: &str,
    valor: &str,
    regional: &RegionalConfig,
) -> Resultado<String> {
    match formato {
        "MONEY_BOB" | "MONEY_USD" => {
            let currency = if formato == "MONEY_USD" { "USD" } else { "BOB" };
            let r = format_money(ctx, valor, currency, regional).await?;
            Ok(r.display)
        }
        "DATE_ISO" | "DATE_LOCAL_BO" => {
            let r = format_date(ctx, valor, GranularidadFecha::SoloFecha, regional).await?;
            Ok(r.display)
        }
        _ => Ok(valor.to_string()),
    }
}

/// Aplica una lista de transformaciones en orden sobre el valor.
pub(crate) fn aplicar_transformaciones(valor: &str, transforms: &[super::attr::Transformacion]) -> String {
    use super::attr::Transformacion;
    let mut resultado = valor.to_string();
    for t in transforms {
        resultado = match t {
            Transformacion::Mayusculas       => resultado.to_uppercase(),
            Transformacion::Minusculas       => resultado.to_lowercase(),
            Transformacion::Trim             => resultado.trim().to_string(),
            Transformacion::QuitarGuiones    => resultado.replace('-', ""),
            Transformacion::QuitarEspacios   => resultado.replace(' ', ""),
            Transformacion::SoloDigitos      => resultado.chars().filter(|c| c.is_ascii_digit()).collect(),
            Transformacion::SoloLetras       => resultado.chars().filter(|c| c.is_alphabetic()).collect(),
            Transformacion::TituloCase       => titulo_case(&resultado),
            Transformacion::QuitarAcentos    => quitar_acentos(&resultado),
            Transformacion::RellenarIzquierda { largo, caracter } => {
                format!("{:>width$}", resultado, width = *largo).replacen(' ', &caracter.to_string(), *largo)
            }
            Transformacion::RellenarDerecha { largo, caracter } => {
                format!("{:<width$}", resultado, width = *largo).replacen(' ', &caracter.to_string(), *largo)
            }
        };
    }
    resultado
}

fn titulo_case(s: &str) -> String {
    s.split_whitespace()
        .map(|w| {
            let mut c = w.chars();
            match c.next() {
                None    => String::new(),
                Some(f) => f.to_uppercase().to_string() + c.as_str(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn quitar_acentos(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            'á'|'à'|'ä'|'â' => 'a', 'é'|'è'|'ë'|'ê' => 'e',
            'í'|'ì'|'ï'|'î' => 'i', 'ó'|'ò'|'ö'|'ô' => 'o',
            'ú'|'ù'|'ü'|'û' => 'u', 'Á'|'À'|'Ä'|'Â' => 'A',
            'É'|'È'|'Ë'|'Ê' => 'E', 'Í'|'Ì'|'Ï'|'Î' => 'I',
            'Ó'|'Ò'|'Ö'|'Ô' => 'O', 'Ú'|'Ù'|'Ü'|'Û' => 'U',
            'ñ' => 'n', 'Ñ' => 'N', otro => otro,
        })
        .collect()
}
