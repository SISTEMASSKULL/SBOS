// ================================================================
// bauth::signal — Manejo de señales del sistema operativo
//
// SIGTERM: apagado graceful con drenaje (≤ 5 segundos)
// SIGHUP:  recarga de configuración sin interrupción
//
// BAUTH-010: TERM=drain ≤5s, HUP=reload. Patrón bkernel.
// DOC-SBOS-001 N3: documentación en español.
// ================================================================

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::signal;
use tokio::sync::Notify;
use tracing::{error, info, warn};

/// Timeout de drenaje para SIGTERM (segundos).
pub const DRAIN_TIMEOUT_SECS: u64 = 5;

/// Gestor de drenaje graceful.
///
/// Mantiene un contador de conexiones activas y notifica cuando
/// todas han terminado. Usado por el servidor para saber cuándo
/// es seguro apagar.
#[derive(Debug, Clone, Default)]
pub struct DrainManager {
    /// Contador de conexiones activas.
    active: Arc<AtomicU64>,
    /// Notificación de apagado.
    shutdown: Arc<Notify>,
}

impl DrainManager {
    /// Crear un nuevo gestor de drenaje.
    pub fn new() -> Self {
        Self {
            active: Arc::new(AtomicU64::new(0)),
            shutdown: Arc::new(Notify::new()),
        }
    }

    /// Incrementar el contador de conexiones activas.
    /// Llamar al aceptar una nueva conexión.
    pub fn connection_start(&self) {
        self.active.fetch_add(1, Ordering::Release);
    }

    /// Decrementar el contador de conexiones activas.
    /// Llamar al cerrar una conexión.
    /// Si el contador llega a 0 y el shutdown está pendiente,
    /// notifica que todas las conexiones terminaron.
    pub fn connection_end(&self) {
        // H-023 FIX: evitar underflow si connection_end se llama de mas
        let prev = self.active.load(Ordering::Acquire);
        if prev == 0 { return; }
        let prev = self.active.fetch_sub(1, Ordering::Release);
        if prev == 1 {
            self.shutdown.notify_waiters();
        }
    }

    /// Conexiones activas en este momento.
    pub fn active_connections(&self) -> u64 {
        self.active.load(Ordering::Acquire)
    }

    /// Esperar hasta que todas las conexiones terminen o
    /// se alcance el timeout de drenaje.
    pub async fn drain(&self, timeout_secs: u64) -> DrainResult {
        if self.active_connections() == 0 {
            return DrainResult::Clean;
        }

        info!(active = self.active_connections(), "esperando drenaje de conexiones activas");

        tokio::select! {
            _ = self.shutdown.notified() => {
                info!("todas las conexiones finalizadas — drenaje completo");
                DrainResult::Clean
            }
            _ = tokio::time::sleep(std::time::Duration::from_secs(timeout_secs)) => {
                let remaining = self.active_connections();
                warn!(remaining, "drenaje excedió timeout — forzando cierre");
                DrainResult::Timeout { remaining }
            }
        }
    }
}

/// Resultado de la operación de drenaje.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DrainResult {
    /// Todas las conexiones terminaron limpiamente.
    Clean,
    /// Timeout alcanzado, quedan conexiones activas.
    Timeout { remaining: u64 },
}

/// Inicializa los handlers de señales del sistema operativo.
///
/// Retorna un `ShutdownSource` que se completa cuando se recibe
/// SIGTERM (apagado) o SIGINT (Ctrl+C).
///
/// SIGHUP se maneja internamente llamando a `on_reload` si se proporciona.
pub async fn wait_for_shutdown(on_reload: Option<fn()>) {
    #[cfg(unix)]
    {
        let mut sigterm = match signal::unix::signal(signal::unix::SignalKind::terminate()) {
            Ok(s) => s,
            Err(e) => {
                error!("no se pudo registrar handler SIGTERM: {e}");
                return;
            }
        };

        let mut sigint = match signal::unix::signal(signal::unix::SignalKind::interrupt()) {
            Ok(s) => s,
            Err(_) => return,
        };

        let mut sighup = match signal::unix::signal(signal::unix::SignalKind::hangup()) {
            Ok(s) => s,
            Err(_) => return,
        };

        loop {
            tokio::select! {
                _ = sigterm.recv() => {
                    info!("SIGTERM recibido — iniciando apagado graceful");
                    break;
                }
                _ = sigint.recv() => {
                    info!("SIGINT recibido — iniciando apagado graceful");
                    break;
                }
                _ = sighup.recv() => {
                    info!("SIGHUP recibido — recargando configuración");
                    if let Some(reload_fn) = on_reload {
                        reload_fn();
                    }
                }
            }
        }
    }

    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c().await.ok();
        info!("Ctrl+C recibido — iniciando apagado");
    }
}

// ── TESTS ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_drain_manager_empty() {
        let dm = DrainManager::new();
        assert_eq!(dm.active_connections(), 0);
    }

    #[test]
    fn test_drain_manager_count() {
        let dm = DrainManager::new();
        dm.connection_start();
        dm.connection_start();
        assert_eq!(dm.active_connections(), 2);
        dm.connection_end();
        assert_eq!(dm.active_connections(), 1);
        dm.connection_end();
        assert_eq!(dm.active_connections(), 0);
    }

    #[tokio::test]
    async fn test_drain_clean_when_empty() {
        let dm = DrainManager::new();
        let result = dm.drain(1).await;
        assert_eq!(result, DrainResult::Clean);
    }

    #[tokio::test]
    async fn test_drain_timeout() {
        let dm = DrainManager::new();
        dm.connection_start(); // Una conexión activa que nunca termina
        let result = dm.drain(0).await; // Timeout 0 = inmediato
        assert!(matches!(result, DrainResult::Timeout { .. }));
    }

    #[test]
    fn test_drain_result_equality() {
        assert_eq!(DrainResult::Clean, DrainResult::Clean);
        assert_ne!(DrainResult::Clean, DrainResult::Timeout { remaining: 1 });
    }
}
