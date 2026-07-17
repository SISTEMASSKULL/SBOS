/// main.rs — Entry point del daemon bi18n-daemon-orchestrator (bi18nd).
/// Propósito: arranque del daemon soberano de i18n del ecosistema SBOS.
///   - Preflight (Bloque 6.1): valida entorno antes de arrancar.
///   - Carga configuración → inicia loader + FluentBundle → arranca Interface Triple.
///   - sd_notify READY=1 (Bloque 6.2): notifica a systemd que el daemon está listo.
///   - SIGHUP: recarga country-rules + FluentBundle sin reiniciar.
///   - SIGTERM/SIGINT: apagado ordenado con drenado de solicitudes.
///   - Watchdog systemd: ping sd_notify cada WatchdogSec/2.
use std::{path::PathBuf, sync::{atomic::AtomicU64, Arc}};
use bi18n_daemon_orchestrator::{
    config,
    domain::{
        country_rules::CountryRulesLoader,
        fluent_loader::FluentLoader,
        regional_config::ResolverEstatico,
        signal,
    },
    preflight,
    server::{context::ServerContext, grpc, unix_socket, websocket},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let ruta_cfg = PathBuf::from(
        std::env::var("BI18N_CONFIG").unwrap_or_else(|_| "/etc/bos/bi18n.toml".to_string()),
    );
    let cfg = config::cargar(&ruta_cfg).unwrap_or_else(|_| config::Config::default());
    config::inicializar_log(&cfg.log);

    tracing::info!("bi18n arrancando — versión {}", env!("CARGO_PKG_VERSION"));

    // Bloque 6.1 — Preflight: verificar entorno antes de cargar recursos
    preflight::ejecutar(&cfg).await?;

    let loader = Arc::new(CountryRulesLoader::nuevo(&cfg.rutas.country_rules_dir).await?);
    let fluent = Arc::new(
        FluentLoader::cargar(&cfg.regional.locale, &cfg.rutas.fluent_dir)
            .unwrap_or_else(|e| {
                tracing::warn!("Fluent no disponible: {} — fallback a ids literales", e);
                FluentLoader::cargar("und", &cfg.rutas.fluent_dir)
                    .expect("FluentLoader siempre arranca aunque el dir no exista")
            }),
    );
    let resolver = Arc::new(ResolverEstatico::nuevo(&cfg.regional));
    let activas  = Arc::new(AtomicU64::new(0));
    let cfg      = Arc::new(cfg);

    let ctx = ServerContext::nuevo(
        Arc::clone(&loader),
        resolver,
        Arc::clone(&fluent),
        Arc::clone(&cfg),
        Arc::clone(&activas),
    );

    // Bloque 6.2 — Notificar a systemd que el daemon está listo (READY=1)
    if let Err(e) = sd_notify::notify(false, &[sd_notify::NotifyState::Ready]) {
        tracing::debug!("sd_notify READY no enviado (normal en desarrollo): {}", e);
    } else {
        tracing::info!("sd_notify: READY=1 enviado a systemd");
    }

    // Bloque 6.2 — Intervalo del watchdog: WatchdogSec/2 (por defecto 15s si WatchdogSec=30)
    let watchdog_intervalo = cfg.servidor.drain_timeout_secs.min(30) / 2;

    let (sd_tx, sd_rx) = tokio::sync::watch::channel(false);

    let ws_bind        = cfg.servidor.ws_bind.clone();
    let ws_rate_limit  = cfg.servidor.ws_rate_limit_rps;
    let ws_timeout     = cfg.servidor.ws_timeout_ms;

    tokio::select! {
        r = unix_socket::iniciar_jsonrpc(cfg.servidor.socket_path.clone(), ctx.clone(), sd_rx.clone()) =>
            tracing::error!("JSON-RPC finalizó inesperadamente: {:?}", r),
        r = grpc::iniciar_grpc(cfg.servidor.grpc_socket_path.clone(), ctx.clone(), sd_rx.clone()) =>
            tracing::error!("gRPC finalizó inesperadamente: {:?}", r),
        r = websocket::iniciar_websocket(ws_bind, ctx, ws_rate_limit, ws_timeout, sd_rx) =>
            tracing::error!("WebSocket finalizó inesperadamente: {:?}", r),
        _ = signal::manejar_sighup(Arc::clone(&loader), Arc::clone(&fluent), Arc::clone(&activas), cfg.servidor.drain_timeout_secs, cfg.rutas.fluent_dir.clone()) => {},
        _ = signal::manejar_sigterm(sd_tx.clone(), Arc::clone(&activas), cfg.servidor.drain_timeout_secs) => {},
        _ = signal::manejar_sigint(sd_tx) => {},
        _ = signal::manejar_watchdog(watchdog_intervalo) => {},
    }

    tracing::info!("bi18n apagado limpiamente");
    Ok(())
}
