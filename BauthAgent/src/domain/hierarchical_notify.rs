// ============================================================
// bauth::domain::hierarchical_notify — Notificacion Jerarquica
//
// ctx_id → enruta automaticamente a:
//   👤 DM Usuario  (siempre)
//   🏬 Sucursal    (si pertenece)
//   🏭 Empresa     (si pertenece)
//   🏢 Tenant      (eventos criticos)
//
// El ctx_id YA contiene toda la informacion necesaria.
// ============================================================
#![allow(dead_code)]

use crate::domain::notify::NotifyClient;
use std::collections::HashMap;
use std::sync::Arc;

pub struct HierarchicalNotifier {
    client: Arc<dyn NotifyClient>,
    /// Webhooks por sucursal: sucursal_id → webhook_id
    sucursal_hooks: HashMap<String, String>,
    /// Webhooks por empresa: empresa_id → webhook_id
    empresa_hooks: HashMap<String, String>,
    /// Webhook tenant (general)
    tenant_hook: String,
    /// User notifier para DMs
    mm_url: String,
    mm_token: String,
    pg: Option<sqlx::PgPool>,
}

impl HierarchicalNotifier {
    pub fn new(
        client: Arc<dyn NotifyClient>,
        tenant_hook: &str,
        mm_url: &str,
        mm_token: &str,
        pg: Option<sqlx::PgPool>,
    ) -> Self {
        Self {
            client, tenant_hook: tenant_hook.to_string(),
            mm_url: mm_url.to_string(), mm_token: mm_token.to_string(),
            pg, sucursal_hooks: HashMap::new(), empresa_hooks: HashMap::new(),
        }
    }

    pub fn add_sucursal(&mut self, id: &str, hook: &str) { self.sucursal_hooks.insert(id.into(), hook.into()); }
    pub fn add_empresa(&mut self, id: &str, hook: &str)  { self.empresa_hooks.insert(id.into(), hook.into()); }

    /// Notifica un evento de acceso denegado a TODOS los niveles relevantes.
    pub async fn notify_access_denied(
        &self, tenant_id: &str, empresa_id: &str, sucursal_id: &str,
        user_uuid: &str, atom: &str, domain: u8, motivo: &str,
    ) {
        let domain_name = match domain {
            1=>"Logico",2=>"Fisico",3=>"Financiero",4=>"Temporal",5=>"Biometrico",
            6=>"Geoespacial",7=>"Red",8=>"Contexto",9=>"Credenciales",10=>"Delegacion",
            11=>"Auditoria",12=>"Blockchain", _=>"Desconocido"
        };

        let title = format!("⛔ Acceso Denegado — D{} {}", domain, domain_name);
        let body = format!(
            "**Operacion:** {}\n**Usuario:** {}\n**Dominio:** D{} ({})\n**Motivo:** {}\n**Sucursal:** {}\n**Timestamp:** {}",
            atom, user_uuid, domain, domain_name, motivo, sucursal_id,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        );

        // 1. DM al usuario (siempre)
        self.send_dm(user_uuid, &title, &format!("{}\n\n**Accion:** Contacta a tu supervisor si necesitas acceso a esta operacion.", body)).await;

        // 2. Canal de sucursal
        if let Some(hook) = self.sucursal_hooks.get(sucursal_id) {
            let _ = self.client.send_chat_message(hook, &format!("## {} {}\n\n{}",  "🏬 Sucursal", title, body)).await;
        }

        // 3. Canal de empresa
        if let Some(hook) = self.empresa_hooks.get(empresa_id) {
            let _ = self.client.send_chat_message(hook, &format!("## {} {}\n\n{}", "🏭 Empresa", title, body)).await;
        }

        // 4. Canal tenant (evento critico si D3 financiero o D9 credenciales)
        if domain == 3 || domain == 9 {
            let _ = self.client.send_chat_message(&self.tenant_hook, &format!("## {} {}\n\n{}", "🏢 Tenant", title, body)).await;
        }
    }

    async fn send_dm(&self, user_uuid: &str, title: &str, body: &str) {
        let email = match self.lookup_email(user_uuid).await {
            Some(e) => e, None => return,
        };
        let mm_user = match self.find_mm_user(&email).await {
            Some(u) => u, None => return,
        };

        let msg = format!("## {}\n\n{}", title, body);
        let client = reqwest::Client::new();

        // Crear canal directo
        let channel: serde_json::Value = match client
            .post(format!("{}/api/v4/channels/direct", self.mm_url))
            .header("Authorization", format!("Bearer {}", self.mm_token))
            .json(&serde_json::json!([self.get_bot_id().await, mm_user]))
            .send().await { Ok(r) => r.json().await.unwrap_or_default(), _ => return };

        let ch_id = channel["id"].as_str().unwrap_or("");
        if ch_id.is_empty() { return; }

        // Enviar mensaje
        let _ = client
            .post(format!("{}/api/v4/posts", self.mm_url))
            .header("Authorization", format!("Bearer {}", self.mm_token))
            .json(&serde_json::json!({"channel_id": ch_id, "message": msg}))
            .send().await;

        tracing::info!(%user_uuid, "DM enviado");
    }

    async fn get_bot_id(&self) -> String {
        let client = reqwest::Client::new();
        let resp = client.get(format!("{}/api/v4/users/me", self.mm_url))
            .header("Authorization", format!("Bearer {}", self.mm_token))
            .send().await;
        match resp {
            Ok(r) => match r.json::<serde_json::Value>().await {
                Ok(v) => v["id"].as_str().unwrap_or("").to_string(),
                _ => String::new(),
            },
            _ => String::new(),
        }
    }

    async fn find_mm_user(&self, email: &str) -> Option<String> {
        let client = reqwest::Client::new();
        client.get(format!("{}/api/v4/users/search", self.mm_url))
            .header("Authorization", format!("Bearer {}", self.mm_token))
            .query(&[("term", email)])
            .send().await.ok()?
            .json::<serde_json::Value>().await.ok()?
            .as_array()?.first()?.get("id")?.as_str().map(String::from)
    }

    async fn lookup_email(&self, user_uuid: &str) -> Option<String> {
        let pg = self.pg.as_ref()?;
        let uuid: uuid::Uuid = user_uuid.parse().ok()?;
        sqlx::query_scalar::<_, String>(
            "SELECT email FROM bauth.idn_user_template WHERE uuid = $1"
        ).bind(uuid).fetch_optional(pg).await.ok()?
    }
}
