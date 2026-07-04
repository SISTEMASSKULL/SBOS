// ============================================================
// bauth::server::handlers::token_jwks — B48.T04 JWKS Endpoint
//
// Handler: bauth.token.jwks
// RFC 7517 — JSON Web Key Set endpoint.
// Expone la clave pública Ed25519 para que cualquier aplicación
// pueda validar tokens de bAuth sin consultar el daemon.
//
// Formato JWKS:
//   {"keys":[{"kty":"OKP","crv":"Ed25519","x":"<base64url>","kid":"...","use":"sig","alg":"EdDSA"}]}
//
// DOC-SBOS-001 N3 · RFC 7517 · RFC 8037
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use serde_json::Value;

pub struct TokenJwksHandler {
    pub signer: std::sync::Arc<crate::domain::jwt_signer::JwtSigner>,
    pub jwt_cfg: crate::config::JwtConfig,
}

#[async_trait::async_trait]
impl JsonRpcHandler for TokenJwksHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pub_key_bytes = self.signer.public_key_hex();
        let pub_key_bytes_decoded = hex::decode(pub_key_bytes).unwrap_or_default();
        let pub_key_base64url = URL_SAFE_NO_PAD.encode(pub_key_bytes_decoded);

        Ok(serde_json::json!({
            "keys": [{
                "kty": "OKP",
                "crv": "Ed25519",
                "x": pub_key_base64url,
                "kid": self.signer.kid(),
                "use": "sig",
                "alg": "EdDSA",
                "key_ops": ["verify"],
            }],
            "issuer": self.jwt_cfg.issuer,
            "jwks_uri": self.jwt_cfg.jwks_uri,
            "message": "JWKS endpoint de bAuth. Clave Ed25519 para validación de tokens."
        }))
    }
}
