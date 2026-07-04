// ============================================================
// bauth::domain::auth_methods::saml — SAML 2.0 Validator Nativo
// Fase Final: valida assertions SAML sin dependencia externa.
//
// Validación mínima para interoperabilidad enterprise:
//   - Verifica firma XML (opcional en staging)
//   - Extrae NameID
//   - Verifica condiciones (NotBefore/NotOnOrAfter)
//   - Extrae atributos
//
// Keycloak queda como OBSERVADOR de consistencia.
// No está en el path crítico de autenticación.
// ============================================================
#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use serde_json::Value;

pub struct SamlValidator;

impl SamlValidator {
    pub fn new() -> Self { Self }

    /// Valida un SAML Response contra el IdP esperado.
    /// `saml_response_b64`: SAML Response codificado en base64
    /// `expected_issuer`: EntityID del IdP esperado
    /// `expected_audience`: EntityID del SP (nosotros)
    pub fn validate_response(
        saml_response_b64: &str, expected_issuer: &str, expected_audience: &str,
    ) -> Result<SamlAssertion, AuthMethodError> {
        if saml_response_b64.is_empty() {
            return Err(AuthMethodError::MissingParam { method: "BAUTH_SAML".into(), param: "saml_response".into() });
        }

        // Decodificar base64
        let decoded = data_encoding::BASE64.decode(saml_response_b64.as_bytes()).map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: base64 inválido".into(),
        })?;

        let xml_str = String::from_utf8(decoded).map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: UTF-8 inválido".into(),
        })?;

        // G4: Verificar firma XML-DSig si existe Signature
        if xml_str.contains("<Signature") || xml_str.contains("<ds:Signature") {
            super::saml_signature::verify_saml_signature(&xml_str)?;
        }

        // Extraer campos del XML (parser ligero sin dependencia de quick-xml)
        let issuer = Self::extract_tag(&xml_str, "Issuer");
        let name_id = Self::extract_tag(&xml_str, "NameID");
        let not_before = Self::extract_attr(&xml_str, "Conditions", "NotBefore");
        let not_on_or_after = Self::extract_attr(&xml_str, "Conditions", "NotOnOrAfter");
        let audience = Self::extract_tag(&xml_str, "Audience");

        // Verificar issuer
        if !expected_issuer.is_empty() && issuer != expected_issuer {
            return Err(AuthMethodError::InvalidCredentials {
                method: format!("BAUTH_SAML: issuer mismatch — esperado '{}', recibido '{}'", expected_issuer, issuer),
            });
        }

        // Verificar audience
        if !expected_audience.is_empty() && audience != expected_audience {
            return Err(AuthMethodError::InvalidCredentials {
                method: format!("BAUTH_SAML: audience mismatch — esperado '{}', recibido '{}'", expected_audience, audience),
            });
        }

        // Verificar vigencia
        let now = chrono::Utc::now();
        if let Ok(nb) = chrono::DateTime::parse_from_rfc3339(&not_before) {
            if now < nb {
                return Err(AuthMethodError::Expired { method: "BAUTH_SAML: NotBefore futuro".into(), ttl_secs: 0 });
            }
        }
        if let Ok(noa) = chrono::DateTime::parse_from_rfc3339(&not_on_or_after) {
            if now > noa {
                return Err(AuthMethodError::Expired { method: "BAUTH_SAML: expirado".into(), ttl_secs: 0 });
            }
        }

        Ok(SamlAssertion {
            issuer,
            name_id,
            audience,
            not_before,
            not_on_or_after,
        })
    }

    /// Extrae el contenido de un tag XML sin namespace.
    fn extract_tag(xml: &str, tag: &str) -> String {
        let open = format!("<{}", tag);
        let close = format!("</{}>", tag);

        if let Some(start) = xml.find(&open) {
            let after_open = &xml[start..];
            if let Some(content_start) = after_open.find('>') {
                let content = &after_open[content_start + 1..];
                if let Some(end) = content.find(&close) {
                    return content[..end].trim().to_string();
                }
            }
        }

        // Buscar con namespace: <saml:Issuer>
        let open_ns = format!("<saml:{}", tag);
        if let Some(start) = xml.find(&open_ns) {
            let after_open = &xml[start..];
            if let Some(content_start) = after_open.find('>') {
                let close_ns = format!("</saml:{}>", tag);
                let content = &after_open[content_start + 1..];
                if let Some(end) = content.find(&close_ns) {
                    return content[..end].trim().to_string();
                }
            }
        }

        String::new()
    }

    /// Extrae un atributo de un tag XML.
    fn extract_attr(xml: &str, tag: &str, attr: &str) -> String {
        let patterns = vec![
            format!("<{}", tag),
            format!("<saml:{}", tag),
        ];

        for pat in &patterns {
            if let Some(start) = xml.find(pat) {
                let section = &xml[start..];
                let attr_pat = format!("{}=", attr);
                if let Some(attr_start) = section.find(&attr_pat) {
                    let after = &section[attr_start + attr_pat.len()..];
                    let quote = after.chars().next().unwrap_or('"');
                    if let Some(end) = after[1..].find(quote) {
                        return after[1..=end].to_string();
                    }
                }
            }
        }
        String::new()
    }
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct SamlAssertion {
    pub issuer: String,
    pub name_id: String,
    pub audience: String,
    pub not_before: String,
    pub not_on_or_after: String,
}

#[async_trait]
impl AuthMethod for SamlValidator {
    fn method_id(&self) -> &str { "BAUTH_SAML" }
    fn method_name(&self) -> &str { "SAML 2.0 Validator — Nativo Rust" }
    fn aal_level(&self) -> u8 { 2 }
    fn standard_ref(&self) -> &str { "SAML 2.0 / OASIS" }

    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let saml_b64 = input.get("saml_response_b64").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam { method: "BAUTH_SAML".into(), param: "saml_response_b64".into() })?;
        let issuer = input.get("expected_issuer").and_then(|v| v.as_str()).unwrap_or("");
        let audience = input.get("expected_audience").and_then(|v| v.as_str()).unwrap_or("");

        match Self::validate_response(saml_b64, issuer, audience) {
            Ok(assertion) => Ok(ValidateResult {
                valid: true, method_id: "BAUTH_SAML".into(),
                message: format!("SAML válido — NameID={}, Issuer={}", assertion.name_id, assertion.issuer),
                aal_satisfied: 2,
            }),
            Err(e) => Ok(ValidateResult { valid: false, method_id: "BAUTH_SAML".into(), message: e.to_string(), aal_satisfied: 0 }),
        }
    }

    async fn enroll(&self, _u: &str, _p: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult { enrolled: true, method_id: "BAUTH_SAML".into(), instance_id: uuid::Uuid::new_v4().to_string(), secret_preview: None, message: "SAML enrolado".into() })
    }

    async fn revoke(&self, _u: &str, _i: &str) -> Result<(), AuthMethodError> { Ok(()) }
    async fn health_check(&self) -> bool { true }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_saml_with_valid_issuer() {
        let saml = base64_saml("test-issuer", "user@sbos.bo", "bauth.sbos.bo");
        let result = SamlValidator::validate_response(&saml, "test-issuer", "bauth.sbos.bo");
        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_saml_issuer_mismatch() {
        let saml = base64_saml("evil-idp", "user@sbos.bo", "bauth.sbos.bo");
        let result = SamlValidator::validate_response(&saml, "good-idp", "bauth.sbos.bo");
        assert!(result.is_err());
    }

    #[test]
    fn test_empty_response_fails() {
        assert!(SamlValidator::validate_response("", "", "").is_err());
    }

    fn base64_saml(issuer: &str, name_id: &str, audience: &str) -> String {
        let xml = format!(
            "<Response><Assertion><Issuer>{}</Issuer><Subject><NameID>{}</NameID></Subject><Conditions NotBefore=\"2025-01-01T00:00:00Z\" NotOnOrAfter=\"2099-12-31T23:59:59Z\"><Audience>{}</Audience></Conditions></Assertion></Response>",
            issuer, name_id, audience
        );
        data_encoding::BASE64.encode(xml.as_bytes())
    }
}
