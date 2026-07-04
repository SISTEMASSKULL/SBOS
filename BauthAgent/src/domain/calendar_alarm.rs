// ============================================================
// bauth::domain::calendar_alarm — B47.C01: Cron Job poll_cal_alarms()
//
// Cada 60s consulta bcalendar.cal_alarm buscando alarmas pendientes.
// Para cada alarma: (1) expande RRULE vía consulta SQL,
// (2) construye payload JSON-RPC para bnotify,
// (3) invoca bnotify.trigger sobre /run/bos/bnotify.sock,
// (4) INSERT en cal_notification_log (WORM),
// (5) UPDATE cal_alarm.next_trigger_at con próxima ocurrencia.
//
// Referencias: RFC 5545 §3.8.6, ISO 27001 A.8.15
// ============================================================

use crate::domain::notify::NotifyClient;
use sqlx::PgPool;
use std::sync::Arc;
use std::time::Duration;
use tracing::{info, warn, error};

/// Contexto necesario para el poller de alarmas
pub struct AlarmPoller {
    pg: PgPool,
    notify: Arc<dyn NotifyClient>,
}

impl AlarmPoller {
    pub fn new(pg: PgPool, notify: Arc<dyn NotifyClient>) -> Self {
        Self { pg, notify }
    }

    /// Loop principal — se ejecuta como tarea background en main.rs
    pub async fn run(self) {
        let mut interval = tokio::time::interval(Duration::from_secs(60));
        info!("cal_alarm::poller — iniciado (60s)");

        loop {
            interval.tick().await;
            if let Err(e) = self.poll_and_dispatch().await {
                error!(error = %e, "cal_alarm::poller — error en ciclo");
            }
        }
    }

    /// Consulta alarmas pendientes, las expande y las despacha
    async fn poll_and_dispatch(&self) -> Result<(), String> {
        // 1. Buscar alarmas activas cuyo next_trigger_at ya pasó
        let rows: Vec<AlarmRow> = sqlx::query_as(
            r#"SELECT
                a.alarm_id, a.event_id, a.trigger_seconds,
                a.channel, a.template_ref, a.recipient_id,
                e.rrule as rrule_text,
                a.next_trigger_at, a.is_active
               FROM bcalendar.cal_alarm a
               JOIN bcalendar.cal_event e ON e.event_id = a.event_id
               WHERE a.is_active = true
                 AND a.next_trigger_at <= now()
               ORDER BY a.next_trigger_at ASC
               LIMIT 50"#
        )
        .fetch_all(&self.pg)
        .await
        .map_err(|e| format!("query cal_alarm: {}", e))?;

        if rows.is_empty() {
            return Ok(());
        }

        info!(pendientes = rows.len(), "cal_alarm::poller — alarmas encontradas");

        for alarm in &rows {
            if let Err(e) = self.dispatch_alarm(alarm).await {
                warn!(alarm_id = %alarm.alarm_id, error = %e, "cal_alarm::poller — falló despacho");
            }
        }

        Ok(())
    }

    /// Despacha una alarma: bnotify → WORM log → update next_trigger_at
    async fn dispatch_alarm(&self, alarm: &AlarmRow) -> Result<(), String> {
        let ctx_id = uuid::Uuid::now_v7().to_string();

        // 1. Calcular próxima ocurrencia vía función PL/pgSQL
        let next_ts: Option<chrono::NaiveDateTime> = if let Some(ref rrule) = alarm.rrule_text {
            sqlx::query_scalar::<_, chrono::NaiveDateTime>(
                "SELECT bcalendar.rrule_next_occurrence($1, $2::timestamptz)"
            )
            .bind(rrule)
            .bind(alarm.next_trigger_at)
            .fetch_optional(&self.pg)
            .await
            .map_err(|e| format!("rrule_next_occurrence: {}", e))?
        } else {
            None // alarma única, sin recurrencia
        };

        // 2. Construir payload JSON-RPC para bnotify
        let payload = serde_json::json!({
            "template_ref": alarm.template_ref.as_deref().unwrap_or("sbos_cal_alarm"),
            "recipient_id": alarm.recipient_id.as_deref().unwrap_or("system"),
            "channel": alarm.channel.as_deref().unwrap_or("CHAT"),
            "ctx_id": ctx_id,
            "payload": {
                "alarm_id": alarm.alarm_id.to_string(),
                "calendar_id": alarm.event_id.to_string(),
                "event_id": alarm.event_id.to_string(),
                "trigger_seconds": alarm.trigger_seconds,
                "channel": alarm.channel,
            }
        });

        // 3. Invocar bnotify.trigger vía JSON-RPC (el método trigger en NotifyClient)
        let notify_result = self.notify.send_calendar_alarm(
            &alarm.alarm_id.to_string(),
            &payload.to_string(),
        ).await;

        let status = if notify_result.is_ok() { "SENT" } else { "FAILED" };
        let error_msg = notify_result.as_ref().err().map(|e| e.to_string());

        // 4. INSERT en cal_notification_log (WORM)
        sqlx::query(
            r#"INSERT INTO bcalendar.cal_notification_log
               (alarm_id, channel, status, payload, error_message, sent_at, ctx_id)
               VALUES ($1, $2, $3, $4::jsonb, $5, now(), $6)"#
        )
        .bind(alarm.alarm_id)
        .bind(alarm.channel.as_deref().unwrap_or("CHAT"))
        .bind(status)
        .bind(&payload)
        .bind(&error_msg)
        .bind(&ctx_id)
        .execute(&self.pg)
        .await
        .map_err(|e| format!("insert cal_notification_log: {}", e))?;

        // 5. UPDATE cal_alarm.next_trigger_at
        let new_next = next_ts.unwrap_or_else(|| {
            // Sin recurrencia: desactivar alarma
            chrono::Utc::now().naive_utc()
        });

        sqlx::query(
            r#"UPDATE bcalendar.cal_alarm
               SET next_trigger_at = $1,
                   last_triggered_at = now()
               WHERE alarm_id = $2"#
        )
        .bind(new_next)
        .bind(alarm.alarm_id)
        .execute(&self.pg)
        .await
        .map_err(|e| format!("update cal_alarm: {}", e))?;

        info!(
            alarm_id = %alarm.alarm_id,
            channel = ?alarm.channel,
            status = status,
            next = ?new_next,
            "cal_alarm::poller — alarma despachada"
        );

        Ok(())
    }
}

/// Fila de alarma desde PostgreSQL (JOIN cal_alarm + cal_event)
#[derive(Debug, sqlx::FromRow)]
struct AlarmRow {
    alarm_id: uuid::Uuid,
    event_id: uuid::Uuid,
    trigger_seconds: Option<i32>,
    channel: Option<String>,
    template_ref: Option<String>,
    recipient_id: Option<String>,
    rrule_text: Option<String>,
    next_trigger_at: chrono::NaiveDateTime,
    is_active: bool,
}
