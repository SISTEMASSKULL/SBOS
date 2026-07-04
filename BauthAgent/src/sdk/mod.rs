// ============================================================
// bauth::sdk — B48.T10-T13: SDK multi-lenguaje
// Contratos de API para Go, Python, JavaScript/TypeScript, Java
// Todos usan JSON-RPC 2.0 sobre Unix socket /run/bos/bauth.sock
// ============================================================

/// API unificada para todos los SDKs
pub const API_VERSION: &str = "1.0.0";
pub const DEFAULT_SOCKET: &str = "/run/bos/bauth.sock";

/// Métodos expuestos vía SDK
pub const SDK_METHODS: &[(&str, &str)] = &[
    ("GetContext", "bauth.context.evaluate"),
    ("AccessEvaluate", "bauth.access.evaluate"),
    ("TokenIssue", "bauth.token.issue"),
    ("TokenValidate", "bauth.token.validate"),
    ("TokenRefresh", "bauth.token.refresh"),
    ("SelfPasswordChange", "bauth.self.password.change"),
    ("SelfMfaEnroll", "bauth.self.mfa.enroll"),
    ("SelfRecoveryInitiate", "bauth.self.recovery.initiate"),
    ("SelfSessionList", "bauth.self.session.list"),
    ("SelfSessionRevoke", "bauth.self.session.revoke"),
    ("DeviceRegister", "bauth.device.register"),
    ("DeviceAttest", "bauth.device.attest"),
    ("CtxTransfer", "bauth.ctx.transfer"),
    ("HealthCheck", "bauth.health.check"),
];

/// Contrato de tipos para el Context que retorna GetContext()
#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct ContextResponse {
    pub user_uuid: String,
    pub tenant_id: String,
    pub empresa_id: String,
    pub sucursal_id: String,
    pub pos_logico: String,
    pub rol_bitmask: String,
    pub domain_results: serde_json::Value,
    pub trust_level: i32,
    pub loa: i32,
}
