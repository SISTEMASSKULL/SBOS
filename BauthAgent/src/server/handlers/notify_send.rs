// ============================================================
// bauth::server::handlers::notify_send — G2 bnotify integration
//
// bauth.notify.send — enviar notificacion via bnotify
// ============================================================
#![allow(dead_code)]

use crate::domain::notify::{NotifyClient, StubNotifyClient};
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::sync::Arc;

pub struct NotifySendHandler { pub client: Arc<dyn NotifyClient> }

#[async_trait::async_trait]
impl JsonRpcHandler for NotifySendHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let channel = params.get("channel").and_then(|v| v.as_str()).unwrap_or("email");
        let recipient = params.get("recipient").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError { code: -32602, message: "recipient requerido".into(), data: None })?;

        match channel {
            "email" | "smtp" => {
                let code = params.get("code").and_then(|v| v.as_str()).unwrap_or("");
                let ttl = params.get("ttl_minutes").and_then(|v| v.as_u64()).unwrap_or(10) as u32;
                self.client.send_email_otp(recipient, code, ttl).await.map_err(|e| JsonRpcError {
                    code: -32000, message: e.to_string(), data: None,
                })?;
            }
            "push" => {
                let number = params.get("number").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                let nonce = params.get("nonce").and_then(|v| v.as_str()).unwrap_or("");
                let ttl = params.get("ttl_seconds").and_then(|v| v.as_u64()).unwrap_or(300);
                self.client.send_push_challenge(recipient, number, nonce, ttl).await.map_err(|e| JsonRpcError {
                    code: -32000, message: e.to_string(), data: None,
                })?;
            }
            "recovery" => {
                let code = params.get("code").and_then(|v| v.as_str()).unwrap_or("");
                self.client.send_recovery_code(recipient, code).await.map_err(|e| JsonRpcError {
                    code: -32000, message: e.to_string(), data: None,
                })?;
            }
            "mattermost" | "slack" | "discord" | "telegram" => {
                let subject = params.get("subject").and_then(|v| v.as_str()).unwrap_or("SBOS");
                self.client.send_chat_message(recipient, subject).await.map_err(|e| JsonRpcError {
                    code: -32000, message: e.to_string(), data: None,
                })?;
            }
            other => return Err(JsonRpcError {
                code: -32602, message: format!("channel '{}' no soportado. Use: email, push, recovery, mattermost", other), data: None,
            }),
        }
        Ok(serde_json::json!({"sent": true, "channel": channel, "recipient": recipient}))
    }
}

pub fn default_notify_handler() -> NotifySendHandler {
    NotifySendHandler { client: Arc::new(StubNotifyClient) }
}
