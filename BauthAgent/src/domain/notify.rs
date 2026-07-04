// ============================================================
// bauth::domain::notify — G2 Integracion con sbos-notifier
//
// sbos-notifier (bnotify) — daemon Python 3.14 del ecosistema.
//   Stack: Apprise (100+ providers) + Centrifugo (WebSocket)
//   Socket: /run/bos/bnotify.sock (JSON-RPC 2.0, ADR-020)
//   Ficha: servers/S06/sbos-notifier/manifest.yml v1.0.0
//
// bAuth envia OTP, push challenges y recovery codes via bnotify.
// bnotify maneja la entrega real (email via SMTP, push via Centrifugo).
// ============================================================
#![allow(dead_code)]

use serde_json::Value;

#[async_trait::async_trait]
pub trait NotifyClient: Send + Sync {
    async fn send_email_otp(&self, email: &str, code: &str, ttl_minutes: u32) -> Result<(), NotifyError>;
    async fn send_push_challenge(&self, user_id: &str, number: u32, nonce: &str, ttl_seconds: u64) -> Result<(), NotifyError>;
    async fn send_recovery_code(&self, email: &str, code: &str) -> Result<(), NotifyError>;
    async fn send_chat_message(&self, recipient: &str, message: &str) -> Result<(), NotifyError>;
    /// B47.C01 — Enviar alarma de calendario via bnotify.trigger
    async fn send_calendar_alarm(&self, alarm_id: &str, payload_json: &str) -> Result<(), NotifyError>;
    async fn health_check(&self) -> bool;
}

#[derive(Debug, thiserror::Error)]
pub enum NotifyError {
    #[error("bnotify no disponible: {0}")]
    Unavailable(String),
    #[error("envio fallido: {0}")]
    SendFailed(String),
}

// ── Cliente Real: sbos-notifier via Unix socket ───────────────

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;

pub struct SbOsNotifierClient {
    socket_path: String,
}

impl SbOsNotifierClient {
    pub fn new(socket_path: &str) -> Self {
        Self { socket_path: socket_path.to_string() }
    }

    async fn rpc(&self, method: &str, params: &Value) -> Result<Value, NotifyError> {
        let stream = UnixStream::connect(&self.socket_path).await
            .map_err(|e| NotifyError::Unavailable(format!("socket: {}", e)))?;

        let (mut reader, mut writer) = stream.into_split();
        let request = serde_json::json!({
            "jsonrpc": "2.0", "method": method, "params": params, "id": 1
        });

        writer.write_all(format!("{}\n", serde_json::to_string(&request).unwrap()).as_bytes()).await
            .map_err(|e| NotifyError::SendFailed(format!("write: {}", e)))?;

        let mut buf_reader = BufReader::new(&mut reader);
        let mut line = String::new();
        buf_reader.read_line(&mut line).await
            .map_err(|e| NotifyError::SendFailed(format!("read: {}", e)))?;

        let response: Value = serde_json::from_str(&line)
            .map_err(|e| NotifyError::SendFailed(format!("parse: {}", e)))?;

        if response.get("error").is_some() {
            return Err(NotifyError::SendFailed(
                response["error"]["message"].as_str().unwrap_or("unknown").to_string()
            ));
        }
        Ok(response["result"].clone())
    }
}

#[async_trait::async_trait]
impl NotifyClient for SbOsNotifierClient {
    async fn send_email_otp(&self, email: &str, code: &str, ttl_minutes: u32) -> Result<(), NotifyError> {
        self.rpc("bnotify.send", &serde_json::json!({
            "channel": "email",
            "recipient": email,
            "subject": "SBOS — Codigo de Verificacion",
            "body": format!("Su codigo SBOS: {}\nExpira en {} minutos.", code, ttl_minutes)
        })).await?;
        tracing::info!(%email, "OTP via bnotify");
        Ok(())
    }

    async fn send_push_challenge(&self, user_id: &str, number: u32, nonce: &str, ttl_seconds: u64) -> Result<(), NotifyError> {
        self.rpc("bnotify.mfa", &serde_json::json!({
            "user_id": user_id, "number": number, "nonce": nonce,
            "ttl_seconds": ttl_seconds,
            "message": format!("Ingrese {} en su pantalla de login para confirmar", number)
        })).await?;
        tracing::info!(%user_id, number, "MFA via bnotify");
        Ok(())
    }

    async fn send_recovery_code(&self, email: &str, code: &str) -> Result<(), NotifyError> {
        self.rpc("bnotify.send", &serde_json::json!({
            "channel": "email",
            "recipient": email,
            "subject": "SBOS — Codigo de Recuperacion",
            "body": format!("Codigo de recuperacion: {}\nUn solo uso.", code)
        })).await?;
        tracing::info!(%email, "Recovery via bnotify");
        Ok(())
    }

    async fn send_chat_message(&self, recipient: &str, message: &str) -> Result<(), NotifyError> {
        self.rpc("bnotify.send", &serde_json::json!({
            "channel": "mattermost",
            "recipient": recipient,
            "subject": "SBOS",
            "body": message,
        })).await?;
        tracing::info!("chat message via bnotify");
        Ok(())
    }

    async fn send_calendar_alarm(&self, alarm_id: &str, payload_json: &str) -> Result<(), NotifyError> {
        let payload: serde_json::Value = serde_json::from_str(payload_json)
            .map_err(|e| NotifyError::SendFailed(format!("parse payload: {}", e)))?;
        self.rpc("bnotify.trigger", &payload).await?;
        tracing::info!(%alarm_id, "Calendar alarm via bnotify.trigger");
        Ok(())
    }

    async fn health_check(&self) -> bool {
        self.rpc("bnotify.health", &serde_json::json!({}))
            .await.map(|r| r.get("status").and_then(|s| s.as_str()) == Some("operativo"))
            .unwrap_or(false)
    }
}

// ── Stub (bnotify no desplegado en staging) ───────────────────

pub struct StubNotifyClient;

#[async_trait::async_trait]
impl NotifyClient for StubNotifyClient {
    async fn send_email_otp(&self, email: &str, code: &str, ttl_minutes: u32) -> Result<(), NotifyError> {
        tracing::info!(%email, code, ttl_minutes, "[STUB] bnotify.send — /run/bos/bnotify.sock");
        Ok(())
    }
    async fn send_push_challenge(&self, user_id: &str, number: u32, nonce: &str, ttl_seconds: u64) -> Result<(), NotifyError> {
        tracing::info!(%user_id, number, nonce, ttl_seconds, "[STUB] bnotify.mfa — /run/bos/bnotify.sock");
        Ok(())
    }
    async fn send_recovery_code(&self, email: &str, code: &str) -> Result<(), NotifyError> {
        tracing::info!(%email, code, "[STUB] bnotify.send recovery");
        Ok(())
    }
    async fn send_chat_message(&self, recipient: &str, message: &str) -> Result<(), NotifyError> {
        tracing::info!(%recipient, message, "[STUB] Chat → bnotify.send mattermost");
        Ok(())
    }
    async fn send_calendar_alarm(&self, alarm_id: &str, _payload_json: &str) -> Result<(), NotifyError> {
        tracing::info!(%alarm_id, "[STUB] bnotify.trigger calendar alarm");
        Ok(())
    }
    async fn health_check(&self) -> bool { true }
}
