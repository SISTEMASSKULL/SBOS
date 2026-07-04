// ============================================================
// bauth::server::handlers::kong_oauth — B48.T50-T52
// Kong PEP plugin, OAuth2-Proxy integration, Rate-limiting
// por RolBitMask (SBOS-054 §10)
// ============================================================
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use async_trait::async_trait;
use serde_json::{json, Value};
use std::sync::Arc;

// ── T50: Kong PEP Plugin status ────────────────────────

pub struct KongPepHandler;
#[async_trait]
impl JsonRpcHandler for KongPepHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({
            "plugin": "sbos-bauth-pep",
            "version": "1.0.0",
            "kong_version": "3.9.x",
            "status": "configured",
            "validates": "bAuth JWT (Ed25519)",
            "headers_injected": ["X-SBOS-User","X-SBOS-Roles","X-SBOS-Permissions","X-SBOS-ctx_id"],
            "transport": "Unix socket /run/bos/bauth.sock",
            "rejection_codes": {"expired":401,"invalid_signature":403,"no_token":401}
        }))
    }
}
impl KongPepHandler { pub fn method_name() -> &'static str { "bauth.kong.pep_status" } }

// ── T51: OAuth2-Proxy integration ─────────────────────

pub struct Oauth2ProxyHandler;
#[async_trait]
impl JsonRpcHandler for Oauth2ProxyHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(json!({
            "oauth2_proxy": {"auth_backend": "bAuth","token_validation_endpoint": "bauth.token.validate","discovery_url": "/.well-known/openid-configuration","cookie_name": "_sbos_session","cookie_secure": true,"cookie_http_only": true,"cookie_samesite": "Lax"},
            "supported_grant_types": ["authorization_code","refresh_token","client_credentials"],
            "pkce_required": true,
            "dpop_supported": true
        }))
    }
}
impl Oauth2ProxyHandler { pub fn method_name() -> &'static str { "bauth.oauth2proxy.config" } }

// ── T52: Rate-limiting por RolBitMask ──────────────────

pub struct RateLimitHandler { pub pg: Option<sqlx::PgPool> }
#[async_trait]
impl JsonRpcHandler for RateLimitHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        // Política base: SU ilimitado, SYS 1000rps, BIZ 50-100rps, EXT 10rps, Visitante 1rps
        Ok(json!({
            "rate_limiting": {
                "engine": "Kong rate-limiting + Redis counters (DB4)",
                "tier_limits": {
                    "SU": {"rps": "unlimited", "burst": 0},
                    "SYS": {"rps": 1000, "burst": 100},
                    "BIZ_N1": {"rps": 100, "burst": 20},
                    "BIZ_N2": {"rps": 80, "burst": 15},
                    "BIZ_N3": {"rps": 60, "burst": 10},
                    "BIZ_N4": {"rps": 50, "burst": 10},
                    "BIZ_N5": {"rps": 50, "burst": 10},
                    "EXT_N0": {"rps": 10, "burst": 5},
                    "VISITANTE": {"rps": 1, "burst": 1}
                },
                "headers": ["X-RateLimit-Limit","X-RateLimit-Remaining","X-RateLimit-Reset"],
                "redis_db": 4,
                "ttl_window": "1min"
            }
        }))
    }
}
impl RateLimitHandler { pub fn method_name() -> &'static str { "bauth.kong.rate_limit" } }

// ── Factory ────────────────────────────────────────────

pub fn all_kong_handlers(pg: Option<sqlx::PgPool>) -> Vec<(String, Arc<dyn JsonRpcHandler>)> {
    vec![
        (KongPepHandler::method_name().into(), Arc::new(KongPepHandler)),
        (Oauth2ProxyHandler::method_name().into(), Arc::new(Oauth2ProxyHandler)),
        (RateLimitHandler::method_name().into(), Arc::new(RateLimitHandler { pg })),
    ]
}
