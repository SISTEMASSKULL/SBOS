// ============================================================
// bauth::domain::user_notify — Notificaciones Personales
//
// Cada ctx_id → user_uuid → usuario real.
// Envia eventos personales al usuario via Mattermost DM.
//
// Eventos personales:
//   - Token expirado
//   - Turno/horario terminado
//   - Acceso denegado (politica)
//   - Cuenta bloqueada
//   - MFA requerido
// ============================================================
#![allow(dead_code)]

use serde_json::Value;

pub struct UserNotifier {
    mattermost_url: String,
    mattermost_token: String,
    bot_id: String,
    pg_pool: Option<sqlx::PgPool>,
}

impl UserNotifier {
    pub fn new(mm_url: &str, mm_token: &str, pg: Option<sqlx::PgPool>) -> Self {
        Self {
            mattermost_url: mm_url.trim_end_matches('/').to_string(),
            mattermost_token: mm_token.to_string(),
            bot_id: String::new(),
            pg_pool: pg,
        }
    }

    /// Inicializa el bot de Mattermost para enviar DMs.
    pub async fn init_bot(&mut self) -> Result<(), String> {
        let resp: Value = reqwest::Client::new()
            .get(format!("{}/api/v4/users/me", self.mattermost_url))
            .header("Authorization", format!("Bearer {}", self.mattermost_token))
            .send().await.map_err(|e| e.to_string())?
            .json().await.map_err(|e| e.to_string())?;
        self.bot_id = resp["id"].as_str().unwrap_or("").to_string();
        Ok(())
    }

    /// Busca el usuario Mattermost por email.
    async fn find_mm_user(&self, email: &str) -> Option<String> {
        let client = reqwest::Client::new();
        let resp: Value = client
            .get(format!("{}/api/v4/users/search", self.mattermost_url))
            .header("Authorization", format!("Bearer {}", self.mattermost_token))
            .query(&[("term", email)])
            .send().await.ok()?
            .json().await.ok()?;
        resp.as_array()?.first()?.get("id")?.as_str().map(String::from)
    }

    /// Crea un canal directo con un usuario y envia un mensaje.
    async fn send_dm(&self, mm_user_id: &str, message: &str) -> Result<(), String> {
        let client = reqwest::Client::new();

        // Crear canal directo
        let channel: Value = client
            .post(format!("{}/api/v4/channels/direct", self.mattermost_url))
            .header("Authorization", format!("Bearer {}", self.mattermost_token))
            .json(&serde_json::json!([self.bot_id, mm_user_id]))
            .send().await.map_err(|e| e.to_string())?
            .json().await.map_err(|e| e.to_string())?;
        let channel_id = channel["id"].as_str().unwrap_or("");

        // Enviar mensaje
        let _: Value = client
            .post(format!("{}/api/v4/posts", self.mattermost_url))
            .header("Authorization", format!("Bearer {}", self.mattermost_token))
            .json(&serde_json::json!({
                "channel_id": channel_id,
                "message": message,
            }))
            .send().await.map_err(|e| e.to_string())?
            .json().await.map_err(|e| e.to_string())?;

        Ok(())
    }

    /// Envia notificacion personal a un usuario via email lookup.
    pub async fn notify_user(&self, user_uuid: &str, title: &str, body: &str) {
        let email = match self.lookup_email(user_uuid).await {
            Some(e) => e,
            None => { tracing::warn!(%user_uuid, "no email found"); return; }
        };

        let mm_user = match self.find_mm_user(&email).await {
            Some(u) => u,
            None => { tracing::warn!(%email, "no MM user"); return; }
        };

        let msg = format!("## {}\n\n{}", title, body);
        match self.send_dm(&mm_user, &msg).await {
            Ok(()) => tracing::info!(%user_uuid, %email, "DM enviado"),
            Err(e) => tracing::warn!(%user_uuid, %e, "DM fallido"),
        }
    }

    /// Busca email del usuario vía JOIN idn_user + idn_identity_attribute (attr_key='email').
    async fn lookup_email(&self, user_uuid: &str) -> Option<String> {
        let pg = self.pg_pool.as_ref()?;
        let uuid: uuid::Uuid = user_uuid.parse().ok()?;
        sqlx::query_scalar::<_, String>(
            "SELECT ia.attr_value #>> '{}' FROM bauth.idn_identity_attribute ia
             JOIN bauth.idn_user u ON u.entity_id = ia.entity_id
             WHERE u.user_id = $1 AND ia.attr_key = 'email' LIMIT 1"
        ).bind(uuid).fetch_optional(pg).await.ok()?
    }

    // ── Eventos predefinidos ─────────────────────────────

    pub async fn token_expired(&self, user_uuid: &str) {
        self.notify_user(user_uuid, "🔑 Token Expirado",
            "Tu sesion ha expirado. Vuelve a iniciar sesion para continuar."
        ).await;
    }

    pub async fn access_denied(&self, user_uuid: &str, atom: &str, motivo: &str) {
        self.notify_user(user_uuid, "⛔ Acceso Denegado",
            &format!("**Operacion:** {}\n**Motivo:** {}", atom, motivo)
        ).await;
    }

    pub async fn account_locked(&self, user_uuid: &str, minutos: u32) {
        self.notify_user(user_uuid, "🚫 Cuenta Bloqueada",
            &format!("Demasiados intentos fallidos. Tu cuenta esta bloqueada por {} minutos.", minutos)
        ).await;
    }

    pub async fn policy_violation(&self, user_uuid: &str, policy: &str, detalle: &str) {
        self.notify_user(user_uuid, "⚠️ Politica de Seguridad",
            &format!("**Politica:** {}\n**Detalle:** {}", policy, detalle)
        ).await;
    }

    pub async fn schedule_ended(&self, user_uuid: &str, turno: &str) {
        self.notify_user(user_uuid, "🕐 Turno Finalizado",
            &format!("Tu turno ({}) ha terminado. Tu sesion se cerrara pronto.", turno)
        ).await;
    }
}
