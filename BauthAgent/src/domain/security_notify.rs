// ============================================================
// bauth::domain::security_notify — Notificaciones automaticas
//
// Todo evento de seguridad en bAuth genera una notificacion
// automatica via bnotify al canal Seguridad de Mattermost.
//
// Eventos notificados:
//   - Login fallido (rate limit excedido, bloqueo)
//   - Token invalido/expirado/revocado
//   - MFA challenge fallido
//   - Contexto invalido/expirado
//   - Acceso denegado (evaluate)
//   - Politica creada/modificada/eliminada
// ============================================================
#![allow(dead_code)]

use crate::domain::notify::NotifyClient;
use std::sync::Arc;

/// Servicio central de notificaciones de seguridad.
pub struct SecurityNotifier {
    client: Arc<dyn NotifyClient>,
    webhook_id: String,
    enabled: bool,
}

impl SecurityNotifier {
    pub fn new(client: Arc<dyn NotifyClient>, webhook_id: &str) -> Self {
        Self { client, webhook_id: webhook_id.to_string(), enabled: true }
    }

    pub fn disabled() -> Self {
        Self {
            client: Arc::new(crate::domain::notify::StubNotifyClient),
            webhook_id: String::new(),
            enabled: false,
        }
    }

    /// Envia notificacion al canal Seguridad.
    async fn notify(&self, title: &str, body: &str) {
        if !self.enabled { return; }
        let msg = format!("## {}\n\n{}", title, body);
        let _ = self.client.send_chat_message(&self.webhook_id, &msg).await;
    }

    /// Login fallido por rate limit o bloqueo.
    pub async fn login_failed(&self, username: &str, ip: &str, reason: &str) {
        self.notify("🚫 Login Fallido", &format!(
            "**Usuario:** {}\n**IP:** {}\n**Motivo:** {}\n**Timestamp:** {}",
            username, ip, reason,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }

    /// Token invalido, expirado o manipulado.
    pub async fn token_invalid(&self, reason: &str, ip: &str) {
        self.notify("🔑 Token Invalido", &format!(
            "**Motivo:** {}\n**IP:** {}\n**Timestamp:** {}",
            reason, ip,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }

    /// MFA challenge fallido.
    pub async fn mfa_failed(&self, user_id: &str, method: &str) {
        self.notify("🔐 MFA Fallido", &format!(
            "**Usuario:** {}\n**Metodo:** {}\n**Timestamp:** {}",
            user_id, method,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }

    /// Contexto invalido o expirado.
    pub async fn ctx_invalid(&self, ctx_id: &str, reason: &str) {
        self.notify("📋 Contexto Invalido", &format!(
            "**ctx_id:** {}\n**Motivo:** {}\n**Timestamp:** {}",
            ctx_id, reason,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }

    /// Acceso denegado por el evaluador.
    pub async fn access_denied(&self, user_id: &str, atom: &str, domain: &str) {
        self.notify("⛔ Acceso Denegado", &format!(
            "**Usuario:** {}\n**Atomo:** {}\n**Dominio:** {}\n**Timestamp:** {}",
            user_id, atom, domain,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }

    /// Politica modificada.
    pub async fn policy_changed(&self, policy: &str, change: &str, by: &str) {
        self.notify("📝 Politica Modificada", &format!(
            "**Politica:** {}\n**Cambio:** {}\n**Por:** {}\n**Timestamp:** {}",
            policy, change, by,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        )).await;
    }
}
