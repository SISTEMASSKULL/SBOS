/// domain/file_watcher.rs — Vigilante de archivos FTL para recarga automática (Bloque 11.3).
/// Propósito: detecta cambios en locales/{locale}/*.ftl y dispara recarga de traducciones.
///   - Usa el crate `notify` (inotify en Linux) — latencia típica < 100ms.
///   - Criterio de done: editar un .ftl en el VPS → recarga visible en < 2s.
///   - Solo reacciona a eventos Create/Modify que afecten archivos .ftl (no any file).
///   - Correr como tarea en tokio::select! junto con los demás servidores.
/// Dependencias: notify, tokio::sync::mpsc, crate::domain::fluent_loader
use std::{path::PathBuf, sync::Arc};
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tokio::sync::mpsc;
use crate::domain::fluent_loader::FluentLoader;

/// Vigila `directorio` en busca de cambios FTL y recarga el bundle cuando detecta uno.
/// Tras cada recarga exitosa emite `translations.updated` al canal push (A.09 §12).
/// Retorna solo si el canal de eventos se cierra (error no recuperable del watcher).
/// Diseñado para correr bajo `tokio::select!` en main.rs.
pub async fn vigilar_traducciones(
    directorio: PathBuf,
    fluent: Arc<FluentLoader>,
    push_tx: tokio::sync::broadcast::Sender<String>,
) {
    let (tx, mut rx) = mpsc::channel::<notify::Result<notify::Event>>(32);

    let mut watcher = match RecommendedWatcher::new(
        move |res| {
            // blocking_send es seguro aquí: el watcher corre en hilo propio de notify.
            let _ = tx.blocking_send(res);
        },
        Config::default(),
    ) {
        Ok(w) => w,
        Err(e) => {
            tracing::error!("file_watcher: no se pudo crear watcher: {}", e);
            return;
        }
    };

    if let Err(e) = watcher.watch(&directorio, RecursiveMode::Recursive) {
        tracing::error!("file_watcher: no se pudo vigilar '{:?}': {}", directorio, e);
        return;
    }

    tracing::info!("file_watcher: vigilando cambios FTL en {:?}", directorio);

    while let Some(evento) = rx.recv().await {
        match evento {
            Ok(ev) => {
                let es_relevante = matches!(
                    ev.kind,
                    EventKind::Create(_) | EventKind::Modify(_)
                ) && ev.paths.iter().any(|p| {
                    p.extension().and_then(|e| e.to_str()) == Some("ftl")
                });

                if es_relevante {
                    tracing::info!("file_watcher: cambio FTL detectado ({:?}) — recargando", ev.paths);
                    match fluent.recargar(&directorio) {
                        Ok(()) => {
                            tracing::info!("file_watcher: traducciones recargadas con swap atómico");
                            // Notificar a todos los clientes WebSocket conectados (A.09 §12.5)
                            let evento = serde_json::json!({
                                "event": "translations.updated",
                                "namespace": "*",
                                "locale": "all",
                            }).to_string();
                            let _ = push_tx.send(evento);
                        }
                        Err(e) => tracing::error!("file_watcher: recarga fallida — versión anterior activa: {}", e),
                    }
                }
            }
            Err(e) => tracing::warn!("file_watcher: evento con error (ignorado): {}", e),
        }
    }

    tracing::warn!("file_watcher: canal de eventos cerrado — vigilancia detenida");
}
