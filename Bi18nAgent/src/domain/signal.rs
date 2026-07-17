/// domain/signal.rs — Manejo de señales POSIX del daemon bi18n.
/// Propósito: SIGHUP recarga country-rules + FluentBundle sin reiniciar; SIGTERM apaga ordenado.
///   - Drenado máximo: drain_timeout_secs (GAP-03).
///   - Conteo atómico de solicitudes activas para esperar drenado.
///   - Bloque 4: FluentLoader también se recarga en SIGHUP (mensajes Fluent en vivo).
///   - Bloque 6.2: watchdog systemd — sd_notify cada WatchdogSec/2 (< 800 líneas OK).
/// Dependencias: tokio::signal, tokio::sync::watch, std::sync::atomic, sd_notify
use std::sync::{
    atomic::{AtomicU64, Ordering},
    Arc,
};
use tokio::sync::watch;
use crate::domain::{
    country_rules::CountryRulesLoader,
    fluent_loader::FluentLoader,
};

// sd_notify es no-op si NOTIFY_SOCKET no está definido (sin systemd en desarrollo)
use sd_notify;

/// Espera SIGHUP y recarga country-rules + FluentBundle atómicamente.
/// Si la recarga falla, loguea el error pero NO apaga el daemon (mantiene datos anteriores).
pub async fn manejar_sighup(
    loader: Arc<CountryRulesLoader>,
    fluent: Arc<FluentLoader>,
    activas: Arc<AtomicU64>,
    drain_timeout_secs: u64,
    fluent_dir: std::path::PathBuf,
) {
    let mut sighup = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::hangup())
        .expect("no se pudo registrar SIGHUP");

    loop {
        match sighup.recv().await {
            None => {
                tracing::error!("Stream SIGHUP cerrado — bi18n dejará de responder a recargas");
                break;
            }
            Some(()) => {
                tracing::info!("SIGHUP recibido — recargando country-rules + mensajes Fluent");
                drenar_solicitudes(&activas, drain_timeout_secs).await;

                match loader.recargar().await {
                    Ok(n)  => tracing::info!("country-rules: {} países cargados", n),
                    Err(e) => tracing::error!("country-rules: falló recarga: {}", e),
                }
                match fluent.recargar(&fluent_dir) {
                    Ok(())  => tracing::info!("Fluent: bundle recargado desde {:?}", fluent_dir),
                    Err(e) => tracing::error!("Fluent: falló recarga: {}", e),
                }
            }
        }
    }
}

/// Espera SIGTERM, drena conexiones activas y luego señaliza el shutdown.
pub async fn manejar_sigterm(
    sd_tx: watch::Sender<bool>,
    activas: Arc<AtomicU64>,
    drain_timeout_secs: u64,
) {
    tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("no se pudo registrar SIGTERM")
        .recv()
        .await;

    let n = activas.load(Ordering::SeqCst);
    tracing::info!("SIGTERM recibido — drenando {} conexiones activas (timeout {}s)", n, drain_timeout_secs);
    drenar_solicitudes(&activas, drain_timeout_secs).await;
    tracing::info!("Drenado completo — apagando bi18n");
    let _ = sd_tx.send(true);
}

/// Espera SIGINT (Ctrl+C en desarrollo) y señaliza el shutdown.
pub async fn manejar_sigint(sd_tx: watch::Sender<bool>) {
    tokio::signal::ctrl_c()
        .await
        .expect("no se pudo registrar SIGINT");
    tracing::info!("SIGINT recibido — apagando bi18n (modo desarrollo)");
    let _ = sd_tx.send(true);
}

/// Loop del watchdog systemd (Bloque 6.2).
/// Envía sd_notify WATCHDOG=1 cada intervalo_secs para que systemd no mate el proceso.
/// Si NOTIFY_SOCKET no está definido (desarrollo), la llamada es no-op.
pub async fn manejar_watchdog(intervalo_secs: u64) {
    if intervalo_secs == 0 { return; }
    let intervalo = std::time::Duration::from_secs(intervalo_secs);
    loop {
        tokio::time::sleep(intervalo).await;
        if let Err(e) = sd_notify::notify(false, &[sd_notify::NotifyState::Watchdog]) {
            tracing::debug!("watchdog sd_notify no enviado (normal en desarrollo): {}", e);
        }
    }
}

/// Bloquea hasta que no haya solicitudes activas o se agote el timeout.
async fn drenar_solicitudes(activas: &AtomicU64, timeout_secs: u64) {
    let limite = std::time::Instant::now()
        + std::time::Duration::from_secs(timeout_secs);
    loop {
        if activas.load(Ordering::SeqCst) == 0 { break; }
        if std::time::Instant::now() >= limite {
            tracing::warn!(
                "Timeout de drenado ({} s) con {} solicitudes activas — continuando",
                timeout_secs, activas.load(Ordering::SeqCst)
            );
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
}
