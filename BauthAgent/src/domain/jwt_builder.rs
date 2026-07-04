// ============================================================
// bauth::domain::jwt_builder — Constructor de Tokens JWT de bAuth
// B48.T01 — JwtBuilder: Construye JWT con RolBitMask + ctx_id + domain_results
//
// bAuth emite su PROPIO token. No depende de Keycloak para el contenido.
// KC sigue siendo IdP para OIDC, pero el JWT lo construye y firma bAuth.
//
// Claims del token bAuth:
//   sub, iss, aud, exp, iat, jti (RFC 7519)
//   ctx_id (SBOS-049, W3C Trace Context)
//   bos_rol_bitmask (base64, one-hot encoding)
//   bos_atom_bitmask (hex, 64-bit label encoding)
//   bos_domain_results (JSON, 12 dominios evaluados)
//   tenant_id, empresa_id, sucursal_id, pos_logico
//   loa, auth_methods, device_trust, session_id, risk_score
//
// DOC-SBOS-001 N3 · BAUTH-VISION.md · RFC 7519 · SBOS-049
// ============================================================

#![allow(dead_code)]
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

/// Claims estándar + extendidos del JWT de bAuth.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BauthClaims {
    // ─── RFC 7519: Registered claims ───
    #[serde(rename = "sub")]
    pub subject: String,
    #[serde(rename = "iss")]
    pub issuer: String,
    #[serde(rename = "aud", skip_serializing_if = "Option::is_none")]
    pub audience: Option<Vec<String>>,
    #[serde(rename = "exp")]
    pub expiration: i64,
    #[serde(rename = "iat")]
    pub issued_at: i64,
    #[serde(rename = "nbf", skip_serializing_if = "Option::is_none")]
    pub not_before: Option<i64>,
    #[serde(rename = "jti")]
    pub jwt_id: String,

    // ─── OpenID Connect Core 1.0 ───
    #[serde(rename = "nonce", skip_serializing_if = "Option::is_none")]
    pub nonce: Option<String>,
    #[serde(rename = "auth_time", skip_serializing_if = "Option::is_none")]
    pub auth_time: Option<i64>,
    #[serde(rename = "acr", skip_serializing_if = "Option::is_none")]
    pub acr: Option<String>,
    #[serde(rename = "amr", skip_serializing_if = "Option::is_none")]
    pub amr: Option<Vec<String>>,

    // ─── SBOS-049: Context Plane ───
    #[serde(rename = "ctx_id")]
    pub ctx_id: String,

    // ─── BitMask Dual ───
    // NOTA: RolBitMask y AtomBitMask NO se incluyen en el token.
    // El token es solo identidad. La evaluación de permisos es server-side
    // vía bauth.access.evaluate(atom_slug, ctx_id) → Redis (30s TTL) → FastPath <0.5ns.
    // Patrón: PDP/PEP (XACML/NIST 800-207). El token es la llave, no la carga.

    // ─── Domain evaluation results ───
    #[serde(rename = "bos_domain_results", skip_serializing_if = "Option::is_none")]
    pub domain_results: Option<Value>,

    // ─── Organization scope ───
    #[serde(rename = "tenant_id")]
    pub tenant_id: String,
    #[serde(rename = "empresa_id", skip_serializing_if = "Option::is_none")]
    pub empresa_id: Option<String>,
    #[serde(rename = "sucursal_id", skip_serializing_if = "Option::is_none")]
    pub sucursal_id: Option<String>,
    #[serde(rename = "pos_logico", skip_serializing_if = "Option::is_none")]
    pub pos_logico: Option<String>,

    // ─── Authentication context ───
    #[serde(rename = "loa")]
    pub level_of_assurance: i32,
    #[serde(rename = "auth_methods", skip_serializing_if = "Option::is_none")]
    pub auth_methods: Option<Vec<String>>,
    #[serde(rename = "device_trust", skip_serializing_if = "Option::is_none")]
    pub device_trust: Option<String>,
    #[serde(rename = "session_id", skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
    #[serde(rename = "risk_score", skip_serializing_if = "Option::is_none")]
    pub risk_score: Option<f64>,

    // ─── Trazabilidad forense ───
    // ─── W3C Trace Context (Distributed Tracing) ───
    #[serde(rename = "traceparent", skip_serializing_if = "Option::is_none")]
    pub traceparent: Option<String>,
    #[serde(rename = "tracestate", skip_serializing_if = "Option::is_none")]
    pub tracestate: Option<String>,

    #[serde(rename = "source_ip", skip_serializing_if = "Option::is_none")]
    pub source_ip: Option<String>,
    #[serde(rename = "source_mac", skip_serializing_if = "Option::is_none")]
    pub source_mac: Option<String>,
    #[serde(rename = "source_hostname", skip_serializing_if = "Option::is_none")]
    pub source_hostname: Option<String>,
    #[serde(rename = "network_zone", skip_serializing_if = "Option::is_none")]
    pub network_zone: Option<String>,
    #[serde(rename = "geo_location", skip_serializing_if = "Option::is_none")]
    pub geo_location: Option<GeoClaim>,
    #[serde(rename = "device_id", skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(rename = "device_category", skip_serializing_if = "Option::is_none")]
    pub device_category: Option<String>,
    #[serde(rename = "user_agent", skip_serializing_if = "Option::is_none")]
    pub user_agent: Option<String>,
    #[serde(rename = "invoked_at")]
    pub invoked_at: String,

    // ─── Cadena de autenticación ───
    #[serde(rename = "auth_chain", skip_serializing_if = "Option::is_none")]
    pub auth_chain: Option<Vec<AuthStep>>,

    // ─── OAuth 2.1 compatibility ───
    #[serde(rename = "scope", skip_serializing_if = "Option::is_none")]
    pub scope: Option<String>,
    #[serde(rename = "client_id", skip_serializing_if = "Option::is_none")]
    pub client_id: Option<String>,

    // ─── Hash-chain forense (ISO 27001 A.8.15) ───
    #[serde(rename = "prev_hash", skip_serializing_if = "Option::is_none")]
    pub prev_hash: Option<String>,
    #[serde(rename = "token_seq", skip_serializing_if = "Option::is_none")]
    pub token_seq: Option<u64>,
}

/// Coordenadas geoespaciales para trazabilidad del token.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoClaim {
    pub lat: f64,
    pub lon: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub accuracy_m: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub country: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub city: Option<String>,
}

/// Paso en la cadena de autenticación (ISO 27001 A.8.15).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthStep {
    pub method: String,
    pub result: String,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub loa_achieved: Option<i32>,
}

/// Constructor de JWT con todos los claims de bAuth.
pub struct JwtBuilder {
    issuer: String,
    default_ttl_seconds: i64,
}

impl JwtBuilder {
    /// Crea un nuevo builder con el issuer configurado.
    pub fn new(issuer: impl Into<String>, default_ttl_seconds: i64) -> Self {
        Self {
            issuer: issuer.into(),
            default_ttl_seconds,
        }
    }

    /// Construye claims livianos: solo identidad y sesion.
    /// Los permisos NO se incluyen — se evaluan server-side via access.evaluate.
    pub fn build_claims(
        &self,
        user_uuid: &str,
        tenant_id: &str,
        ctx_id: &str,
        loa: i32,
        audience: Option<Vec<String>>,
    ) -> BauthClaims {
        let now = Utc::now();
        let jti = Uuid::new_v4().to_string();
        BauthClaims {
            subject: user_uuid.to_string(),
            issuer: self.issuer.clone(),
            audience,
            expiration: (now + chrono::Duration::seconds(self.default_ttl_seconds)).timestamp(),
            issued_at: now.timestamp(),
            not_before: Some(now.timestamp()),  // RFC 8725bis: nbf = iat
            jwt_id: jti.clone(),
            nonce: None,
            auth_time: Some(now.timestamp()),  // OpenID Connect: auth_time
            acr: Some(format!("sbos_aal{}", loa)),
            amr: None,
            ctx_id: ctx_id.to_string(),
            domain_results: None,
            tenant_id: tenant_id.to_string(),
            empresa_id: None,
            sucursal_id: None,
            pos_logico: None,
            level_of_assurance: loa,
            auth_methods: None,
            device_trust: None,
            session_id: None,
            risk_score: None,
            traceparent: None,
            tracestate: None,
            source_ip: None,
            source_mac: None,
            source_hostname: None,
            network_zone: None,
            geo_location: None,
            device_id: None,
            device_category: None,
            user_agent: None,
            invoked_at: now.to_rfc3339(),
            auth_chain: None,
            scope: None,
            client_id: None,
            prev_hash: None,
            token_seq: None,
        }
    }

    /// Extiende los claims con resultados de evaluación de dominio.
    pub fn with_domain_results(mut claims: BauthClaims, results: Value) -> BauthClaims {
        claims.domain_results = Some(results);
        claims
    }

    /// Extiende los claims con ámbito organizacional.
    pub fn with_org_scope(
        mut claims: BauthClaims,
        empresa_id: Option<String>,
        sucursal_id: Option<String>,
        pos_logico: Option<String>,
    ) -> BauthClaims {
        claims.empresa_id = empresa_id;
        claims.sucursal_id = sucursal_id;
        claims.pos_logico = pos_logico;
        claims
    }

    /// Extiende los claims con contexto de autenticación.
    pub fn with_auth_context(
        mut claims: BauthClaims,
        methods: Vec<String>,
        device_trust: Option<String>,
        session_id: Option<String>,
        risk_score: Option<f64>,
    ) -> BauthClaims {
        claims.auth_methods = Some(methods.clone());
        claims.amr = Some(methods);
        claims.device_trust = device_trust;
        claims.session_id = session_id;
        claims.risk_score = risk_score;
        claims
    }

    /// Agrega trazabilidad forense completa al token.
    /// ISO 27001:2022 A.8.15 · W3C Trace Context
    #[allow(clippy::too_many_arguments)]
    pub fn with_traceability(
        mut claims: BauthClaims,
        source_ip: Option<String>,
        source_mac: Option<String>,
        source_hostname: Option<String>,
        network_zone: Option<String>,
        geo: Option<GeoClaim>,
        device_id: Option<String>,
        device_category: Option<String>,
        user_agent: Option<String>,
    ) -> BauthClaims {
        claims.source_ip = source_ip;
        claims.source_mac = source_mac;
        claims.source_hostname = source_hostname;
        claims.network_zone = network_zone;
        claims.geo_location = geo;
        claims.device_id = device_id;
        claims.device_category = device_category;
        claims.user_agent = user_agent;
        claims
    }

    /// Agrega W3C Trace Context (traceparent + tracestate).
    /// Formato: 00-{trace_id}-{parent_id}-{trace_flags}
    pub fn with_w3c_trace(
        mut claims: BauthClaims,
        trace_id: &str,
        parent_span_id: &str,
        sampled: bool,
    ) -> BauthClaims {
        let flags = if sampled { "01" } else { "00" };
        claims.traceparent = Some(format!("00-{}-{}-{}", trace_id, parent_span_id, flags));
        claims.tracestate = Some(format!("sbos=bauth:{}", parent_span_id));
        claims
    }

    /// Agrega la cadena de autenticación (secuencia de métodos usados).
    /// ISO 27001 A.8.15: trazabilidad de cada paso del proceso de auth.
    pub fn with_auth_chain(
        mut claims: BauthClaims,
        steps: Vec<AuthStep>,
    ) -> BauthClaims {
        claims.auth_chain = Some(steps);
        claims
    }

    /// Agrega ámbito OAuth2 (scope + client_id).
    /// Permite que el token sea validado por cualquier Resource Server OAuth2.
    pub fn with_oauth2_scope(
        mut claims: BauthClaims,
        scope: Option<String>,
        client_id: Option<String>,
    ) -> BauthClaims {
        claims.scope = scope;
        claims.client_id = client_id;
        claims
    }

    /// Agrega hash-chain forense (ISO 27001 A.8.15).
    /// Cada token referencia el hash del token anterior → cadena inmutable.
    pub fn with_hash_chain(
        mut claims: BauthClaims,
        prev_token_hash: Option<String>,
        sequence: u64,
    ) -> BauthClaims {
        claims.prev_hash = prev_token_hash;
        claims.token_seq = Some(sequence);
        claims
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_base_claims() {
        let builder = JwtBuilder::new("bauth.sbos.bo", 3600);
        let claims = builder.build_claims(
            "user-uuid-123",
            "tenant-uuid-456",
            "ctx-uuid-789",
            2,
            Some(vec!["sbos-app".into()]),
        );

        assert_eq!(claims.subject, "user-uuid-123");
        assert_eq!(claims.issuer, "bauth.sbos.bo");
        assert_eq!(claims.tenant_id, "tenant-uuid-456");
        assert_eq!(claims.ctx_id, "ctx-uuid-789");
        assert_eq!(claims.level_of_assurance, 2);
        assert!(claims.expiration > claims.issued_at);
        assert!(!claims.jwt_id.is_empty());
    }

    #[test]
    fn test_with_domain_results() {
        let builder = JwtBuilder::new("bauth.sbos.bo", 3600);
        let claims = builder.build_claims("u", "t", "c", 2, None);
        let results = serde_json::json!({
            "D1": "PERMITIDO", "D2": "PERMITIDO", "D3": "DENEGADO"
        });
        let extended = JwtBuilder::with_domain_results(claims, results);
        assert!(extended.domain_results.is_some());
    }

    #[test]
    fn test_nbf_present() {
        let builder = JwtBuilder::new("bauth.sbos.bo", 3600);
        let claims = builder.build_claims("u", "t", "c", 2, None);
        assert!(claims.not_before.is_some());
        assert!(claims.not_before.unwrap() <= claims.issued_at);
    }
}
