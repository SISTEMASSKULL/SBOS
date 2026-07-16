/// main.rs — Entry point del daemon bi18n-daemon-orchestrator (bi18nd).
/// Propósito: arranque del daemon soberano de i18n del ecosistema SBOS.
///   - Carga configuración → inicia loader → arranca Interface Triple en paralelo.
///   - SIGHUP: recarga country-rules sin reiniciar (GAP-03 resuelto).
///   - SIGTERM/SIGINT: apagado ordenado con drenado de solicitudes.
/// Líneas: ≤ 50 (DOC-SBOS-001 N3).
use std::{path::PathBuf, sync::{atomic::AtomicU64, Arc}};
use bi18n_daemon_orchestrator::{
    config,
    domain::{country_rules::CountryRulesLoader, regional_config::ResolverEstatico, signal},
    server::{context::ServerContext, grpc, unix_socket},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let ruta_cfg = PathBuf::from(
        std::env::var("BI18N_CONFIG").unwrap_or_else(|_| "/etc/bos/bi18n.toml".to_string()),
    );
    let cfg = config::cargar(&ruta_cfg).unwrap_or_else(|_| config::Config::default());
    config::inicializar_log(&cfg.log);

    tracing::info!("bi18n arrancando — versión {}", env!("CARGO_PKG_VERSION"));

    let loader   = Arc::new(CountryRulesLoader::nuevo(&cfg.rutas.country_rules_dir).await?);
    let resolver = Arc::new(ResolverEstatico::nuevo(&cfg.regional));
    let activas  = Arc::new(AtomicU64::new(0));
    let cfg      = Arc::new(cfg);
    let ctx      = ServerContext::nuevo(Arc::clone(&loader), resolver, Arc::clone(&cfg), Arc::clone(&activas));

    let (sd_tx, sd_rx) = tokio::sync::watch::channel(false);

    tokio::select! {
        r = unix_socket::iniciar_jsonrpc(cfg.servidor.socket_path.clone(), ctx.clone(), sd_rx.clone()) =>
            tracing::error!("JSON-RPC finalizó inesperadamente: {:?}", r),
        r = grpc::iniciar_grpc(cfg.servidor.grpc_socket_path.clone(), ctx, sd_rx) =>
            tracing::error!("gRPC finalizó inesperadamente: {:?}", r),
        _ = signal::manejar_sighup(Arc::clone(&loader), Arc::clone(&activas), cfg.servidor.drain_timeout_secs) => {},
        _ = signal::manejar_sigterm(sd_tx.clone(), Arc::clone(&activas), cfg.servidor.drain_timeout_secs) => {},
        _ = signal::manejar_sigint(sd_tx) => {},
    }

    tracing::info!("bi18n apagado limpiamente");
    Ok(())
}
