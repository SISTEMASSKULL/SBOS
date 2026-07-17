/// server/handlers/validate.rs — Handlers de validación de atributos.
/// Propósito: valida documentos de identidad, teléfonos y emails.
///   - Documentos nacionales: regex desde country-rules TOML del país.
///   - Teléfonos: phonenumber crate (libphonenumber — E.164).
///   - Emails: regex RFC 5321.
///   - Mensajes de error: FluentBundle (Bloque 4) — recargables en SIGHUP.
///     Al cambiar locales/es-BO/main.ftl + SIGHUP, los mensajes cambian en vivo.
/// Dependencias: regex, phonenumber, fluent_bundle, crate::domain
use crate::{
    domain::country_rules::IsoAlpha2,
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};
use fluent_bundle::FluentArgs;

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

    /// ID de mensaje Fluent para el error de formato inválido.
    pub fn fluent_id(&self) -> &'static str {
        match self {
            Self::Ci       => "error-ci-invalido",
            Self::Nit      => "error-nit-invalido",
            Self::Cpf      => "error-cpf-invalido",
            Self::Cnpj     => "error-cnpj-invalido",
            Self::Dni      => "error-dni-invalido",
            Self::Cuit     => "error-cuit-invalido",
            Self::Passport => "error-passport-invalido",
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
/// El mensaje de error proviene del FluentBundle del servidor (recargable en SIGHUP).
pub async fn validate_national_id(
    ctx: &ServerContext,
    tipo: TipoDocumento,
    valor: &str,
    pais: &str,
) -> Resultado<ValidateIdResult> {
    let iso    = IsoAlpha2::nuevo(pais);
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
                // Mensaje Fluent con el ejemplo de formato del TOML
                let mut args = FluentArgs::new();
                args.set("ejemplo", doc_rules.ejemplo.as_str());
                let msg = ctx.fluent.traducir(tipo.fluent_id(), Some(&args));
                Ok(ValidateIdResult {
                    valid: false,
                    normalized: String::new(),
                    errores: vec![msg],
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
/// Los mensajes de error vienen del FluentBundle (recargables en SIGHUP).
pub async fn validate_phone(
    ctx: &ServerContext,
    valor: &str,
    pais_hint: &str,
) -> Resultado<ValidatePhoneResult> {
    use phonenumber::country::Id;

    let country: Option<Id> = pais_hint.parse().ok();
    let numero = match phonenumber::parse(country, valor) {
        Err(e) => {
            let mut args = FluentArgs::new();
            args.set("detalle", e.to_string());
            let msg = ctx.fluent.traducir("error-telefono-invalido", Some(&args));
            return Ok(ValidatePhoneResult {
                valid: false,
                e164: String::new(),
                errores: vec![msg],
            });
        }
        Ok(n) => n,
    };

    if !numero.is_valid() {
        let msg = ctx.fluent.traducir("error-telefono-pais", None);
        return Ok(ValidatePhoneResult {
            valid: false,
            e164: String::new(),
            errores: vec![msg],
        });
    }

    let e164 = numero.format().mode(phonenumber::Mode::E164).to_string();
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

/// Valida una dirección de email con regex RFC 5321.
/// El mensaje de error viene del FluentBundle (recargable en SIGHUP).
pub async fn validate_email(
    ctx: &ServerContext,
    valor: &str,
) -> Resultado<ValidateEmailResult> {
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
        let msg = ctx.fluent.traducir("error-email-invalido", None);
        Ok(ValidateEmailResult {
            valid: false,
            normalized: String::new(),
            errores: vec![msg],
        })
    }
}
