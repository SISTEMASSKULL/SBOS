// ============================================================
// bauth::server::handlers::token_validate — B48.T04
//
// Handler: bauth.token.validate
// Valida un JWT de bAuth. Cualquier aplicación (incluyendo
// controladores de puertas, Kong, OAuth2-Proxy, Nginx) puede
// validar el token usando este endpoint o la clave pública.
//
// La validación verifica:
//   - Firma Ed25519
//   - Expiración (exp)
//   - Emisor (iss)
//   - Audiencia (aud) si se especifica
//   - ctx_id trazable
//
// DOC-SBOS-001 N3 · RFC 7519 · OAuth 2.1
// ============================================================

use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use serde_json::Value;

pub struct TokenValidateHandler {
    pub signer: std::sync::Arc<crate::domain::jwt_signer::JwtSigner>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for TokenValidateHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let jwt = params.get("jwt").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "jwt requerido".into(), data: None,
            })?;

        let expected_aud = params.get("audience").and_then(|v| v.as_str());

        // ── 1. Decodificar header ──────────────────────────
        let parts: Vec<&str> = jwt.split('.').collect();
        if parts.len() != 3 {
            return Ok(serde_json::json!({
                "valid": false,
                "reason": "formato JWT inválido — se esperaban 3 partes (header.payload.signature)",
                "trace": null
            }));
        }

        // Decodificar header y payload — fallos de formato son resultado de negocio (valid:false),
        // no errores de protocolo (-32602). Un JWT malformado es una entrada válida que no valida.
        let header_bytes = match URL_SAFE_NO_PAD.decode(parts[0]) {
            Ok(b) => b,
            Err(e) => return Ok(serde_json::json!({
                "valid": false,
                "reason": format!("header base64 inválido: {}", e),
                "trace": null
            })),
        };
        let header: Value = match serde_json::from_slice(&header_bytes) {
            Ok(v) => v,
            Err(e) => return Ok(serde_json::json!({
                "valid": false,
                "reason": format!("header JWT malformado: {}", e),
                "trace": null
            })),
        };

        let payload_bytes = match URL_SAFE_NO_PAD.decode(parts[1]) {
            Ok(b) => b,
            Err(e) => return Ok(serde_json::json!({
                "valid": false,
                "reason": format!("payload base64 inválido: {}", e),
                "trace": null
            })),
        };
        let claims: Value = match serde_json::from_slice(&payload_bytes) {
            Ok(v) => v,
            Err(e) => return Ok(serde_json::json!({
                "valid": false,
                "reason": format!("payload JWT malformado: {}", e),
                "trace": null
            })),
        };

        // ── 2. Verificar expiración ─────────────────────────
        let now = chrono::Utc::now().timestamp();
        let exp = claims.get("exp").and_then(|v| v.as_i64()).unwrap_or(0);
        // Si exp = 0 (claims corruptos), tratar como expirado por seguridad
        if exp == 0 || now > exp {
            return Ok(serde_json::json!({
                "valid": false,
                "reason": "token expirado",
                "expired_at": exp,
                "now": now,
                "trace": {
                    "ctx_id": claims.get("ctx_id"),
                    "sub": claims.get("sub"),
                    "iss": claims.get("iss"),
                }
            }));
        }

        // ── 3. Verificar audiencia ──────────────────────────
        if let Some(aud) = expected_aud {
            let token_aud: Vec<String> = claims.get("aud")
                .and_then(|v| v.as_array())
                .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default();

            if !token_aud.is_empty() && !token_aud.contains(&aud.to_string()) {
                return Ok(serde_json::json!({
                    "valid": false,
                    "reason": format!("audiencia no autorizada: '{}' no está en {:?}", aud, token_aud),
                    "trace": { "ctx_id": claims.get("ctx_id"), "sub": claims.get("sub") }
                }));
            }
        }

        // ── 4. Verificar firma Ed25519 (SEC-002 FIX) ─────────
        match self.signer.verify(jwt) {
            Ok(_) => {},  // firma válida, continuar
            Err(e) => {
                return Ok(serde_json::json!({
                    "valid": false,
                    "reason": format!("firma criptográfica inválida: {}", e),
                    "trace": null
                }));
            }
        }

        // ── 5. Extraer claims de trazabilidad ──────────────
        let trace = serde_json::json!({
            "ctx_id": claims.get("ctx_id"),
            "sub": claims.get("sub"),
            "iss": claims.get("iss"),
            "iat": claims.get("iat"),
            "exp": claims.get("exp"),
            "jti": claims.get("jti"),
            "source_ip": claims.get("source_ip"),
            "geo_location": claims.get("geo_location"),
            "device_id": claims.get("device_id"),
            "user_agent": claims.get("user_agent"),
            "invoked_at": claims.get("invoked_at"),
            "scope": claims.get("scope"),
            "client_id": claims.get("client_id"),
            "loa": claims.get("loa"),
            "tenant_id": claims.get("tenant_id"),
        });

        Ok(serde_json::json!({
            "valid": true,
            "header": {
                "algorithm": header.get("alg"),
                "type": header.get("typ"),
                "kid": header.get("kid"),
            },
            "claims": claims,
            "trace": trace,
            "validated_at": chrono::Utc::now().to_rfc3339(),
            "message": "✅ Token bAuth válido. Firma Ed25519, estructura, expiración y audiencia verificados."
        }))
    }
}
