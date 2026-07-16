/// domain/signal.rs — Manejo de señales POSIX del daemon bi18n.
/// Propósito: SIGHUP recarga country-rules sin reiniciar; SIGTERM apaga ordenado.
///   - Drenado máximo: drain_timeout_secs (GAP-03).
///   - Conteo atómico de solicitudes activas para esperar drenado.
/// Dependencias: tokio::signal, tokio::sync::watch, std::sync::atomic
use std::sync::{
    atomic::{AtomicU64, Ordering},
    Arc,
};
use tokio::sync::watch;
use crate::domain::country_rules::CountryRulesLoader;

/// Espera SIGHUP y recarga el catálogo de países atómicamente.
/// Si la recarga falla, loguea el error pero NO apaga el daemon (mantiene datos anteriores).
pub async fn manejar_sighup(
    loader: Arc<CountryRulesLoader>,
    activas: Arc<AtomicU64>,
    drain_timeout_secs: u64,
) {
    // Crear el listener UNA SOLA VEZ fuera del loop.
    let mut sighup = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::hangup())
        .expect("no se pudo registrar SIGHUP");

    loop {
        match sighup.recv().await {
            None => {
                tracing::error!("Stream SIGHUP cerrado — bi18n dejará de responder a recargas");
                break;
            }
            Some(()) => {
                tracing::info!("SIGHUP recibido — iniciando recarga de country-rules");
                drenar_solicitudes(&activas, drain_timeout_secs).await;
                match loader.recargar().await {
                    Ok(n)  => tracing::info!("Recarga completada: {} países cargados", n),
                    Err(e) => tracing::error!("Falló la recarga: {} — datos anteriores sin cambios", e),
                }
            }
        }
    }
}

/// Espera SIGTERM, drena conexiones activas y luego señaliza el shutdown.
/// El drenado respeta `drain_timeout_secs` como máximo de espera (GAP-03).
pub async fn manejar_sigterm(
    sd_tx: watch::Sender<bool>,
    activas: Arc<AtomicU64>,
    drain_timeout_secs: u64,
) {
    tokio::signal::unix::signal(
        tokio::signal::unix::SignalKind::terminate(),
    )
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

/// Bloquea hasta que no haya solicitudes activas o se agote el timeout.
async fn drenar_solicitudes(activas: &AtomicU64, timeout_secs: u64) {
    let limite = std::time::Instant::now()
        + std::time::Duration::from_secs(timeout_secs);

    loop {
        if activas.load(Ordering::SeqCst) == 0 {
            break;
        }
        if std::time::Instant::now() >= limite {
            let pendientes = activas.load(Ordering::SeqCst);
            tracing::warn!(
                "Timeout de drenado ({} s) alcanzado con {} solicitudes activas — continuando recarga",
                timeout_secs,
                pendientes
            );
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
}
