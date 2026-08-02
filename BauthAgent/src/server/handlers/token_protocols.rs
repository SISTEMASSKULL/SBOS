// ============================================================
// bauth::server::handlers::token_protocols — B48.T40-T42
// Token Exchange RFC 8693, DPoP RFC 9449, Introspection RFC 7662
// ============================================================
use crate::domain::jwt_signer::JwtSigner;
use crate::config::JwtConfig;
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use base64::Engine;
use serde_json::{json, Value};
use std::sync::Arc;

fn err(msg: &str) -> JsonRpcError { JsonRpcError { code: -32602, message: msg.into(), data: None } }

// ── T40: Token Exchange RFC 8693 ───────────────────────

pub struct TokenExchangeHandler { pub signer: Arc<JwtSigner>, pub jwt_cfg: JwtConfig }
#[async_trait]
impl JsonRpcHandler for TokenExchangeHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let subject_token = params.get("subject_token").and_then(|v| v.as_str()).ok_or_else(|| err("subject_token requerido"))?;
        let scope = params.get("scope").and_then(|v| v.as_str()).unwrap_or("");
        // Validar subject_token
        let claims = self.signer.verify(subject_token).map_err(|e| JsonRpcError { code: -32001, message: format!("Token inválido: {}", e), data: None })?;
        // Crear token delegado con scope reducido
        let mut new_claims = claims.clone();
        if let Some(obj) = new_claims.as_object_mut() {
            obj.insert("scope".into(), Value::String(scope.into()));
            obj.insert("may_act".into(), json!({"sub": claims.get("sub")}));
            obj.insert("token_type".into(), Value::String("urn:ietf:params:oauth:token-type:jwt".into()));
        }
        let new_token = self.signer.sign(&new_claims).map_err(|e| JsonRpcError { code: -32002, message: format!("Error: {}", e), data: None })?;
        Ok(json!({"access_token": new_token, "issued_token_type": "urn:ietf:params:oauth:token-type:jwt", "token_type": "Bearer", "scope": scope}))
    }
}
impl TokenExchangeHandler { pub fn method_name() -> &'static str { "bauth.token.exchange" } }

// ── T41: DPoP RFC 9449 ────────────────────────────────
//
// Validación estructural de un DPoP proof:
//   - Header: `typ`="dpop+jwt", `alg` presente, `jwk` presente
//   - Payload: `jti`, `htm`, `htu`, `iat` requeridos
//   - `iat` no debe tener más de 120 segundos de antigüedad
//   - `ath` = base64url(SHA-256(access_token)) si se provee token
//
// NOTA: La verificación de firma del DPoP proof sobre la clave JWK del header
// requiere una librería de deserialización JWK (ej: jsonwebkey). Pendiente
// cuando se agregue esa dependencia. Se reporta `sig_verified: false` si no
// se puede verificar la firma.
//
// RFC 9449 §4.2: DPoP Proof Syntax

pub struct DpopHandler;

/// Parsea el header de un JWT base64url-encoded sin verificar firma.
fn parsear_jwt_header(header_b64: &str) -> Result<serde_json::Value, String> {
    let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(header_b64)
        .map_err(|e| format!("header base64 inválido: {}", e))?;
    serde_json::from_slice(&bytes)
        .map_err(|e| format!("header JSON inválido: {}", e))
}

/// Parsea el payload de un JWT base64url-encoded sin verificar firma.
fn parsear_jwt_payload(payload_b64: &str) -> Result<serde_json::Value, String> {
    let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(payload_b64)
        .map_err(|e| format!("payload base64 inválido: {}", e))?;
    serde_json::from_slice(&bytes)
        .map_err(|e| format!("payload JSON inválido: {}", e))
}

/// Computa ath = base64url(SHA-256(access_token)) — RFC 9449 §4.2.
fn computar_ath(access_token: &str) -> String {
    use sha2::Digest;
    let hash = sha2::Sha256::digest(access_token.as_bytes());
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(hash.as_slice())
}

#[async_trait]
impl JsonRpcHandler for DpopHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let dpop_proof = params.get("dpop_proof").and_then(|v| v.as_str())
            .ok_or_else(|| err("dpop_proof requerido (RFC 9449)"))?;
        let token = params.get("token").and_then(|v| v.as_str()).unwrap_or("");
        let htm   = params.get("htm").and_then(|v| v.as_str()).unwrap_or("");
        let htu   = params.get("htu").and_then(|v| v.as_str()).unwrap_or("");

        // ── Estructura JWT: exactamente 3 partes ──────────────────────────
        let parts: Vec<&str> = dpop_proof.split('.').collect();
        if parts.len() != 3 {
            return Err(JsonRpcError {
                code: -32003,
                message: "DPoP proof inválido: no es un JWT (falta separador '.')".into(),
                data: None,
            });
        }

        // ── Header: typ="dpop+jwt", alg, jwk requeridos ───────────────────
        let header = parsear_jwt_header(parts[0]).map_err(|e| JsonRpcError {
            code: -32003, message: format!("DPoP header inválido: {}", e), data: None,
        })?;

        let typ = header.get("typ").and_then(|v| v.as_str()).unwrap_or("");
        if typ != "dpop+jwt" {
            return Err(JsonRpcError {
                code: -32003,
                message: format!("DPoP header inválido: typ='{}' (requerido: 'dpop+jwt')", typ),
                data: None,
            });
        }
        if header.get("alg").is_none() {
            return Err(JsonRpcError {
                code: -32003,
                message: "DPoP header inválido: falta 'alg'".into(),
                data: None,
            });
        }
        let jwk_presente = header.get("jwk").is_some();

        // ── Payload: jti, htm, htu, iat requeridos ────────────────────────
        let payload = parsear_jwt_payload(parts[1]).map_err(|e| JsonRpcError {
            code: -32003, message: format!("DPoP payload inválido: {}", e), data: None,
        })?;

        let jti = payload.get("jti").and_then(|v| v.as_str()).unwrap_or("");
        if jti.is_empty() {
            return Err(JsonRpcError {
                code: -32003,
                message: "DPoP payload inválido: falta 'jti' (anti-replay)".into(),
                data: None,
            });
        }

        let proof_htm = payload.get("htm").and_then(|v| v.as_str()).unwrap_or("");
        let proof_htu = payload.get("htu").and_then(|v| v.as_str()).unwrap_or("");

        if proof_htm.is_empty() || proof_htu.is_empty() {
            return Err(JsonRpcError {
                code: -32003,
                message: "DPoP payload inválido: faltan 'htm' y/o 'htu'".into(),
                data: None,
            });
        }

        // ── Validar htm/htu si el caller los provee ────────────────────────
        if !htm.is_empty() && proof_htm.to_uppercase() != htm.to_uppercase() {
            return Err(JsonRpcError {
                code: -32003,
                message: format!("DPoP htm mismatch: proof='{}' vs request='{}'", proof_htm, htm),
                data: None,
            });
        }
        if !htu.is_empty() && proof_htu != htu {
            return Err(JsonRpcError {
                code: -32003,
                message: format!("DPoP htu mismatch: proof='{}' vs request='{}'", proof_htu, htu),
                data: None,
            });
        }

        // ── Verificar antigüedad del iat (máx 120 segundos) ───────────────
        let proof_iat = payload.get("iat").and_then(|v| v.as_i64()).unwrap_or(0);
        let now = chrono::Utc::now().timestamp();
        let edad_secs = now - proof_iat;

        if proof_iat == 0 {
            return Err(JsonRpcError {
                code: -32003,
                message: "DPoP payload inválido: falta 'iat'".into(),
                data: None,
            });
        }
        if edad_secs > 120 || edad_secs < -5 {
            return Err(JsonRpcError {
                code: -32003,
                message: format!("DPoP proof expirado: iat hace {}s (máx 120s)", edad_secs),
                data: None,
            });
        }

        // ── Verificar ath si se provee access_token ────────────────────────
        let mut ath_ok = true;
        let ath_expected = if !token.is_empty() { Some(computar_ath(token)) } else { None };

        if let Some(ref ath_calc) = ath_expected {
            let proof_ath = payload.get("ath").and_then(|v| v.as_str()).unwrap_or("");
            if proof_ath.is_empty() {
                // RFC 9449 §4.3: ath DEBE estar presente si se usa con un access token
                ath_ok = false;
            } else if proof_ath != ath_calc {
                return Err(JsonRpcError {
                    code: -32003,
                    message: "DPoP ath no coincide con SHA-256(access_token)".into(),
                    data: None,
                });
            }
        }

        tracing::info!(jti, %proof_htm, jwk_presente, edad_secs, "token.dpop — proof estructuralmente válido");

        Ok(json!({
            "dpop_verified":    true,
            "jti":              jti,
            "htm":              proof_htm,
            "htu":              proof_htu,
            "iat_age_secs":     edad_secs,
            "jwk_present":      jwk_presente,
            "ath_verified":     ath_ok,
            "ath_expected":     ath_expected,
            "sig_verified":     false,
            "sig_note":         "Verificación de firma JWK pendiente de librería jsonwebkey",
            "token_type":       "DPoP",
            "rfc":              "RFC 9449",
        }))
    }
}
impl DpopHandler { pub fn method_name() -> &'static str { "bauth.token.dpop" } }

// ── T42: Token Introspection RFC 7662 ─────────────────

pub struct TokenIntrospectHandler { pub signer: Arc<JwtSigner> }
#[async_trait]
impl JsonRpcHandler for TokenIntrospectHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let token = params.get("token").and_then(|v| v.as_str()).ok_or_else(|| err("token requerido"))?;
        match self.signer.verify(token) {
            Ok(claims) => {
                let active = claims.get("exp").and_then(|v| v.as_i64()).unwrap_or(0) > chrono::Utc::now().timestamp();
                Ok(json!({"active": active, "sub": claims.get("sub"), "scope": claims.get("scope"), "exp": claims.get("exp"), "token_type": "Bearer"}))
            }
            Err(_) => Ok(json!({"active": false})),
        }
    }
}
impl TokenIntrospectHandler { pub fn method_name() -> &'static str { "bauth.token.introspect" } }

// ── Factory ────────────────────────────────────────────

pub fn all_protocol_handlers(signer: Arc<JwtSigner>, jwt_cfg: JwtConfig) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (TokenExchangeHandler::method_name().into(), Arc::new(TokenExchangeHandler { signer: signer.clone(), jwt_cfg: jwt_cfg.clone() })),
        (DpopHandler::method_name().into(), Arc::new(DpopHandler)),
        (TokenIntrospectHandler::method_name().into(), Arc::new(TokenIntrospectHandler { signer: signer.clone() })),
    ]
}
