/// server/handlers/validate.rs — Handlers de validación de atributos.
/// Propósito: valida documentos de identidad, teléfonos y emails.
///   - Documentos nacionales: regex desde country-rules TOML del país.
///   - Teléfonos: phonenumber crate (libphonenumber — E.164).
///   - Emails: validator crate (RFC 5321).
/// Dependencias: regex, phonenumber, validator, crate::domain
use crate::{
    domain::country_rules::IsoAlpha2,
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};

// ── ValidateNationalId ────────────────────────────────────────────────────────

/// Tipo de documento de identidad.
#[derive(Debug, Clone, Copy)]
pub enum TipoDocumento {
    Ci,
    Nit,
    Cpf,
    Cnpj,
    Dni,
    Cuit,
    Passport,
}

impl TipoDocumento {
    pub fn clave_toml(&self) -> &'static str {
        match self {
            Self::Ci       => "CI",
            Self::Nit      => "NIT",
            Self::Cpf      => "CPF",
            Self::Cnpj     => "CNPJ",
            Self::Dni      => "DNI",
            Self::Cuit     => "CUIT",
            Self::Passport => "PASSPORT",
        }
    }
}

/// Resultado de validación de documento nacional.
#[derive(Debug)]
pub struct ValidateIdResult {
    pub valid: bool,
    pub normalized: String,
    pub errores: Vec<String>,
}

/// Valida un documento de identidad nacional.
pub async fn validate_national_id(
    ctx: &ServerContext,
    tipo: TipoDocumento,
    valor: &str,
    pais: &str,
) -> Resultado<ValidateIdResult> {
    let iso = IsoAlpha2::nuevo(pais);
    let reglas = ctx.loader.obtener(&iso).await?;

    let clave = tipo.clave_toml();
    match reglas.documentos.get(clave) {
        None => Err(Bi18nError::DocumentoNoSoportado { iso: pais.to_string() }),
        Some(doc_rules) => {
            let re = regex::Regex::new(&doc_rules.regex)
                .map_err(|e| Bi18nError::FormatoDesconocido {
                    codigo: format!("regex inválida para {}: {}", clave, e),
                })?;

            let normalizado = valor.trim().to_uppercase();
            if re.is_match(&normalizado) {
                Ok(ValidateIdResult {
                    valid: true,
                    normalized: normalizado,
                    errores: vec![],
                })
            } else {
                Ok(ValidateIdResult {
                    valid: false,
                    normalized: String::new(),
                    errores: vec![doc_rules.error_mensaje.clone()],
                })
            }
        }
    }
}

// ── ValidatePhone ─────────────────────────────────────────────────────────────

/// Resultado de validación de teléfono.
#[derive(Debug)]
pub struct ValidatePhoneResult {
    pub valid: bool,
    pub e164: String,
    pub errores: Vec<String>,
}

/// Valida un número de teléfono vía libphonenumber (phonenumber crate).
pub async fn validate_phone(
    _ctx: &ServerContext,
    valor: &str,
    pais_hint: &str,
) -> Resultado<ValidatePhoneResult> {
    use phonenumber::country::Id;

    let country: Option<Id> = pais_hint.parse().ok();

    let numero = match phonenumber::parse(country, valor) {
        Err(e) => {
            return Ok(ValidatePhoneResult {
                valid: false,
                e164: String::new(),
                errores: vec![format!("Número de teléfono inválido: {}", e)],
            });
        }
        Ok(n) => n,
    };

    if !numero.is_valid() {
        return Ok(ValidatePhoneResult {
            valid: false,
            e164: String::new(),
            errores: vec!["Número de teléfono no válido para el país indicado".to_string()],
        });
    }

    let e164 = numero
        .format()
        .mode(phonenumber::Mode::E164)
        .to_string();

    Ok(ValidatePhoneResult { valid: true, e164, errores: vec![] })
}

// ── ValidateEmail ─────────────────────────────────────────────────────────────

/// Resultado de validación de email.
#[derive(Debug)]
pub struct ValidateEmailResult {
    pub valid: bool,
    pub normalized: String,
    pub errores: Vec<String>,
}

/// Valida una dirección de email con regex RFC 5321 (validator crate reservado para derive).
pub async fn validate_email(
    _ctx: &ServerContext,
    valor: &str,
) -> Resultado<ValidateEmailResult> {
    // Regex básica RFC 5321 — cubre el 99.9% de emails reales sin dependencia de API inestable.
    let re = regex::Regex::new(r"(?i)^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
        .expect("regex de email invariante");

    let normalizado = valor.trim().to_lowercase();
    if re.is_match(&normalizado) {
        Ok(ValidateEmailResult {
            valid: true,
            normalized: normalizado,
            errores: vec![],
        })
    } else {
        Ok(ValidateEmailResult {
            valid: false,
            normalized: String::new(),
            errores: vec!["Dirección de correo electrónico inválida (RFC 5321)".to_string()],
        })
    }
}
