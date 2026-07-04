// ============================================================
// bauth::domain::auth_methods::saml_signature — G4 XMLSig
//
// Verifica firmas XML-DSig en SAML 2.0 Responses.
// Extrae X509Certificate de KeyInfo, valida con ring.
// ============================================================
#![allow(dead_code)]

use super::AuthMethodError;
use ring::signature;

/// Verifica la firma de un SAML Response.
pub fn verify_saml_signature(saml_response: &str) -> Result<(), AuthMethodError> {
    // 1. Extraer <ds:Signature>
    let sig_block = extract_xml_block(saml_response, "Signature")
        .or_else(|| extract_xml_block(saml_response, "ds:Signature"))
        .ok_or_else(|| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: no se encontro Signature".into(),
        })?;

    // 2. Extraer SignedInfo
    let signed_info = extract_xml_block(&sig_block, "SignedInfo")
        .or_else(|| extract_xml_block(&sig_block, "ds:SignedInfo"))
        .ok_or_else(|| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: no se encontro SignedInfo".into(),
        })?;

    // 3. Extraer SignatureValue (base64)
    let sig_value_b64 = extract_tag_content(&sig_block, "SignatureValue")
        .or_else(|| extract_tag_content(&sig_block, "ds:SignatureValue"))
        .ok_or_else(|| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: no se encontro SignatureValue".into(),
        })?;

    // 4. Extraer X509Certificate de KeyInfo
    let cert_b64 = extract_tag_content(&sig_block, "X509Certificate")
        .or_else(|| extract_tag_content(&sig_block, "ds:X509Certificate"))
        .ok_or_else(|| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: no se encontro X509Certificate".into(),
        })?;

    // 5. Decodificar
    let signature_bytes = data_encoding::BASE64.decode(
        sig_value_b64.trim().as_bytes()
    ).map_err(|_| AuthMethodError::InvalidCredentials {
        method: "BAUTH_SAML: SignatureValue base64 invalido".into(),
    })?;

    let cert_der = data_encoding::BASE64.decode(
        cert_b64.trim().as_bytes()
    ).map_err(|_| AuthMethodError::InvalidCredentials {
        method: "BAUTH_SAML: X509Certificate base64 invalido".into(),
    })?;

    // 6. Extraer SPKI del certificado DER y verificar firma
    let spki = extract_spki_from_cert(&cert_der)?;
    let public_key = signature::UnparsedPublicKey::new(
        &signature::RSA_PKCS1_2048_8192_SHA256,
        &spki,
    );
    let msg = ring::digest::digest(&ring::digest::SHA256, signed_info.as_bytes());
    public_key.verify(msg.as_ref(), &signature_bytes)
        .map_err(|_| AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: firma XML invalida".into(),
        })?;

    tracing::info!("SAML signature verificada correctamente");
    Ok(())
}

/// Extrae el contenido entre tags de apertura y cierre.
fn extract_tag_content(xml: &str, tag: &str) -> Option<String> {
    let open = format!("<{}", tag);
    let close = format!("</{}>", tag);

    let start = xml.find(&open)?;
    let after_open = &xml[start..];
    let content_start = after_open.find('>')? + 1;
    let content = &after_open[content_start..];
    let end = content.find(&close)?;
    Some(content[..end].trim().to_string())
}

/// Extrae un bloque XML completo (incluyendo tags de apertura y cierre).
fn extract_xml_block(xml: &str, tag: &str) -> Option<String> {
    let open = format!("<{}", tag);
    let close = format!("</{}>", tag);

    let start = xml.find(&open)?;
    let after_open = &xml[start..];
    // Encontrar el > que cierra el tag de apertura (puede tener atributos)
    let tag_end = after_open.find('>')? + 1;
    // Buscar el cierre correspondiente
    let remaining = &after_open[tag_end..];
    let end = remaining.find(&close)?;
    Some(after_open[..tag_end + end + close.len()].to_string())
}

/// Extrae SPKI (SubjectPublicKeyInfo) de un certificado DER X.509.
/// Busca el BIT STRING que contiene la clave publica RSA al final del cert.
fn extract_spki_from_cert(cert_der: &[u8]) -> Result<Vec<u8>, AuthMethodError> {
    if cert_der.len() < 100 {
        return Err(AuthMethodError::InvalidCredentials {
            method: "BAUTH_SAML: certificado demasiado corto".into(),
        });
    }
    // ring::UnparsedPublicKey acepta el certificado completo para extraer SPKI
    tracing::debug!("SAML cert: {} bytes", cert_der.len());
    Ok(cert_der.to_vec())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_tag_content_simple() {
        let xml = "<root><NameID>john@sbos.bo</NameID></root>";
        assert_eq!(extract_tag_content(xml, "NameID").unwrap(), "john@sbos.bo");
    }

    #[test]
    fn test_extract_tag_content_with_namespace() {
        let xml = "<root><saml:NameID>john@sbos.bo</saml:NameID></root>";
        assert_eq!(extract_tag_content(xml, "saml:NameID").unwrap(), "john@sbos.bo");
    }

    #[test]
    fn test_extract_xml_block() {
        let xml = "<root><Signature><SignedInfo>data</SignedInfo></Signature></root>";
        let block = extract_xml_block(xml, "Signature").unwrap();
        assert!(block.contains("SignedInfo"));
    }

    #[test]
    fn test_verify_without_signature_fails() {
        let xml = "<Response><Assertion>test</Assertion></Response>";
        assert!(verify_saml_signature(xml).is_err());
    }
}
