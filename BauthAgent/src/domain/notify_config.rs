// ============================================================
// bauth::domain::notify_config — Configuracion de notificaciones
//
// Carga desde bauth.toml [notify] o variables de entorno.
// Elimina hardcodeos H-001, H-002, H-003 del informe de auditoria.
// ============================================================
#![allow(dead_code)]

use serde::Deserialize;

/// Configuracion de notificaciones (bauth.toml [notify])
#[derive(Debug, Clone, Deserialize)]
pub struct NotifyConfig {
    /// URL base de Mattermost (ej: http://localhost:8065)
    #[serde(default = "default_mm_url")]
    pub mattermost_url: String,

    /// Token de acceso a Mattermost API
    #[serde(default)]
    pub mattermost_token: String,

    /// Webhook del canal Seguridad (tenant)
    #[serde(default)]
    pub tenant_security_hook: String,

    /// Webhooks por empresa: empresa_id → webhook_id
    #[serde(default)]
    pub empresa_hooks: Vec<EmpresaNotify>,

    /// Webhooks por sucursal: sucursal_id → webhook_id
    #[serde(default)]
    pub sucursal_hooks: Vec<SucursalNotify>,

    /// Ruta al socket de bnotify
    #[serde(default = "default_bnotify_socket")]
    pub bnotify_socket: String,

    /// OIDC issuer URL
    #[serde(default = "default_oidc_issuer")]
    pub oidc_issuer: String,

    /// Verificar TLS en conexiones salientes
    #[serde(default = "default_true")]
    pub tls_verify: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct EmpresaNotify {
    pub empresa_id: String,
    pub webhook_token: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SucursalNotify {
    pub sucursal_id: String,
    pub webhook_token: String,
}

fn default_mm_url() -> String { "http://localhost:8065".into() }
fn default_bnotify_socket() -> String { "/run/bos/bnotify.sock".into() }
fn default_oidc_issuer() -> String { "https://bauth.sbos.bo".into() }
fn default_true() -> bool { true }

impl Default for NotifyConfig {
    fn default() -> Self {
        Self {
            mattermost_url: default_mm_url(),
            mattermost_token: String::new(),
            tenant_security_hook: String::new(),
            empresa_hooks: Vec::new(),
            sucursal_hooks: Vec::new(),
            bnotify_socket: default_bnotify_socket(),
            oidc_issuer: default_oidc_issuer(),
            tls_verify: true,
        }
    }
}

impl NotifyConfig {
    /// Cargar desde archivo de configuracion o variables de entorno
    pub fn load() -> Self {
        // Intentar desde /etc/bos/mattermost/notify.conf
        if let Ok(content) = std::fs::read_to_string("/etc/bos/mattermost/notify.conf") {
            let token = content.lines()
                .find(|l| l.starts_with("MM_TOKEN="))
                .map(|l| l.trim_start_matches("MM_TOKEN=").to_string())
                .unwrap_or_default();
            let url = content.lines()
                .find(|l| l.starts_with("MM_URL="))
                .map(|l| l.trim_start_matches("MM_URL=").to_string())
                .unwrap_or_else(default_mm_url);

            if !token.is_empty() {
                return Self {
                    mattermost_url: url,
                    mattermost_token: token,
                    ..Default::default()
                };
            }
        }

        // Fallback: variables de entorno
        Self {
            mattermost_token: std::env::var("BAUTH_MM_TOKEN").unwrap_or_default(),
            mattermost_url: std::env::var("BAUTH_MM_URL").unwrap_or_else(|_| default_mm_url()),
            bnotify_socket: std::env::var("BAUTH_BNOTIFY_SOCKET").unwrap_or_else(|_| default_bnotify_socket()),
            oidc_issuer: std::env::var("BAUTH_OIDC_ISSUER").unwrap_or_else(|_| default_oidc_issuer()),
            ..Default::default()
        }
    }

    /// Verificar si el token de MM esta configurado
    pub fn has_mm_token(&self) -> bool {
        !self.mattermost_token.is_empty()
    }
}
