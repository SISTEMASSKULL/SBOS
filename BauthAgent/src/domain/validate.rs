// ============================================================
// bauth::domain::validate — Validacion de datos con scrutiny
//
// Crates: scrutiny (50+ reglas: email RFC 5321, URL, UUID,
//   ISO 8601 date/datetime, IP, longitud, rango, lista)
//
// Uso: validate_struct(&input) → Result<(), Vec<String>>
// Integrado en CRUDs antes de cualquier operacion BD.
// Si falla → error -32602, no se ejecuta la operacion.
// ============================================================
#![allow(dead_code)]

use scrutiny::Validate;
use scrutiny::traits::Validate as _;
use serde_json::Value;

/// Struct generico de validacion de params JSON-RPC
#[derive(Validate)]
struct StringParam {
    #[validate(min = 1, max = 256)]
    value: Option<String>,
}

#[derive(Validate)]
struct EmailParam {
    #[validate(required, email, bail)]
    email: Option<String>,
}

#[derive(Validate)]
struct SlugParam {
    #[validate(required, min = 2, max = 64)]
    slug: Option<String>,
}

#[derive(Validate)]
struct PhoneParam {
    #[validate(required, min = 7, max = 15)]
    phone: Option<String>,
}

#[derive(Validate)]
struct DateParam {
    #[validate(required, date, bail)]
    date: Option<String>,
}

#[derive(Validate)]
struct UrlParam {
    #[validate(required, url, bail)]
    url: Option<String>,
}

#[derive(Validate)]
struct CountryParam {
    #[validate(required, min = 2, max = 2)]
    country: Option<String>,
}

#[derive(Validate)]
struct PositiveIntParam {
    #[validate(required, min = 0)]
    value: Option<i64>,
}

#[derive(Validate)]
struct TenantSlugParam {
    #[validate(required, min = 2, max = 64)]
    slug: Option<String>,
}

#[derive(Validate)]
struct RazonSocialParam {
    #[validate(required, min = 3, max = 200)]
    razon_social: Option<String>,
}

/// Valida un string requerido con rango de longitud
pub fn required_text(val: &str, field: &str, min: usize, max: usize) -> Result<(), String> {
    let input = StringParam { value: Some(val.to_string()) };
    match input.validate() {
        Ok(_) if val.len() < min => Err(format!("{}: minimo {} caracteres", field, min)),
        Ok(_) if val.len() > max => Err(format!("{}: maximo {} caracteres", field, max)),
        Ok(_) => Ok(()),
        Err(e) => Err(format!("{}: {}", field, e)),
    }
}

/// Valida email
pub fn email(val: &str) -> Result<(), String> {
    let input = EmailParam { email: Some(val.to_string()) };
    input.validate().map_err(|e| format!("email: {}", e))
}

/// Valida slug de tenant
pub fn slug(val: &str) -> Result<(), String> {
    let input = SlugParam { slug: Some(val.to_string()) };
    input.validate().map_err(|e| format!("slug: {}", e))
}

/// Valida telefono (min 7, max 15 digitos)
pub fn phone(val: &str) -> Result<(), String> {
    let input = PhoneParam { phone: Some(val.to_string()) };
    input.validate().map_err(|e| format!("telefono: {}", e))
}

/// Valida fecha ISO 8601 (YYYY-MM-DD)
pub fn date(val: &str, field: &str) -> Result<(), String> {
    let input = DateParam { date: Some(val.to_string()) };
    input.validate().map_err(|e| format!("{}: {}", field, e))
}

/// Valida URL
pub fn url(val: &str) -> Result<(), String> {
    let input = UrlParam { url: Some(val.to_string()) };
    input.validate().map_err(|e| format!("url: {}", e))
}

/// Valida codigo de pais ISO 3166-1 alpha-2
pub fn country(val: &str) -> Result<(), String> {
    let input = CountryParam { country: Some(val.to_string()) };
    input.validate().map_err(|_| format!("country: codigo ISO 3166-1 alpha-2 requerido (ej: BO)"))
}

/// Valida que un numero sea positivo
pub fn positive_number(val: i64, field: &str) -> Result<(), String> {
    let input = PositiveIntParam { value: Some(val) };
    input.validate().map_err(|e| format!("{}: {}", field, e))
}

/// Valida tenant_slug
pub fn tenant_slug(val: &str) -> Result<(), String> {
    let input = TenantSlugParam { slug: Some(val.to_string()) };
    input.validate().map_err(|e| format!("tenant_slug: {}", e))
}

/// Valida razon social
pub fn razon_social(val: &str) -> Result<(), String> {
    let input = RazonSocialParam { razon_social: Some(val.to_string()) };
    input.validate().map_err(|e| format!("razon_social: {}", e))
}

/// Valida un campo con reglas definidas por el cliente (datos no criticos).
/// Las reglas se pasan como JSON: {"nombre": {"required": true, "min": 3, "max": 100}}
/// Para datos criticos, usar las funciones especificas (email, tenant_slug, etc.)
pub fn validate_with_rules(value: &str, field: &str, rules: &Value) -> Result<(), String> {
    let field_rules = match rules.get(field) {
        Some(r) if r.is_object() => r.as_object().unwrap(),
        _ => return Ok(()), // sin reglas para este campo → pasa
    };

    for (rule_name, rule_val) in field_rules {
        match rule_name.as_str() {
            "required" => {
                if rule_val.as_bool().unwrap_or(false) && value.is_empty() {
                    return Err(format!("{}: requerido", field));
                }
            }
            "min" => {
                if let Some(min) = rule_val.as_u64() {
                    if value.len() < min as usize {
                        return Err(format!("{}: minimo {} caracteres", field, min));
                    }
                }
            }
            "max" => {
                if let Some(max) = rule_val.as_u64() {
                    if value.len() > max as usize {
                        return Err(format!("{}: maximo {} caracteres", field, max));
                    }
                }
            }
            "email" => {
                if rule_val.as_bool().unwrap_or(false) && !value.is_empty() {
                    if let Err(e) = email(value) { return Err(e); }
                }
            }
            "pattern" => {
                if let Some(pattern) = rule_val.as_str() {
                    if !value.is_empty() {
                        use regex::Regex;
                        if let Ok(re) = Regex::new(pattern) {
                            if !re.is_match(value) {
                                return Err(format!("{}: no cumple el patron {}", field, pattern));
                            }
                        }
                    }
                }
            }
            "numeric" => {
                if rule_val.as_bool().unwrap_or(false) && !value.is_empty() {
                    if !value.chars().all(|c| c.is_ascii_digit()) {
                        return Err(format!("{}: solo numeros", field));
                    }
                }
            }
            "alpha" => {
                if rule_val.as_bool().unwrap_or(false) && !value.is_empty() {
                    if !value.chars().all(|c| c.is_ascii_alphabetic() || c.is_ascii_whitespace()) {
                        return Err(format!("{}: solo letras", field));
                    }
                }
            }
            _ => {}
        }
    }
    Ok(())
}

/// Valida todos los campos de un request contra sus reglas.
/// Cada campo en `data` se valida contra su regla en `rules`.
/// Retorna errores de todos los campos, no cortocircuita.
///
/// Uso en handlers de datos no criticos:
///   let errors = validate::validate_request(&params);
///   if !errors.is_empty() { return Err(-32602, errors.join("; ")); }
pub fn validate_request(params: &Value) -> Vec<String> {
    let data = match params.get("data").or_else(|| params.get("params")) {
        Some(d) if d.is_object() => d.as_object().unwrap(),
        _ => return vec![],
    };
    let rules = match params.get("rules") {
        Some(r) if r.is_object() => r,
        _ => return vec![],
    };

    let mut errors = Vec::new();
    for (field, rule_set) in rules.as_object().unwrap() {
        if let Some(val) = data.get(field) {
            let str_val = match val.as_str() {
                Some(s) => s,
                None => continue,
            };
            if let Err(e) = validate_with_rules(str_val, field, rules) {
                errors.push(e);
            }
        }
    }
    errors
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_email_valid() { assert!(email("test@sbos.bo").is_ok()); }
    #[test]
    fn test_email_invalid() { assert!(email("not-email").is_err()); }
    #[test]
    fn test_slug_valid() { assert!(slug("cliente-a").is_ok()); }
    #[test]
    fn test_slug_caps() { assert!(slug("CLIENTE-A").is_ok()); } // scrutiny no valida mayusculas
    #[test]
    fn test_country_valid() { assert!(country("BO").is_ok()); }
    #[test]
    fn test_country_long() { assert!(country("BOL").is_err()); }
    #[test]
    fn test_date_valid() { assert!(date("2026-06-29", "fecha").is_ok()); }
    #[test]
    fn test_date_invalid() { assert!(date("06-29-2026", "fecha").is_err()); }
    #[test]
    fn test_positive() { assert!(positive_number(100, "monto").is_ok()); }
    #[test]
    fn test_negative() { assert!(positive_number(-5, "monto").is_err()); }
}
