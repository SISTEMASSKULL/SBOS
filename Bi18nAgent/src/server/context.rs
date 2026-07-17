/// server/context.rs — Contexto compartido entre los tres servidores (Interface Triple).
/// Propósito: concentra todos los recursos del daemon en un Arc clonable.
///   - JSON-RPC, gRPC y WebSocket comparten EXACTAMENTE el mismo contexto.
///   - Garantía de paridad de capacidades (C11): misma lógica, distinto transporte.
///   - push_tx: canal broadcast para enviar eventos a clientes WebSocket conectados
///     (patrón A.09 §12 — propagación en vivo de translations.updated).
/// Dependencias: Arc, CountryRulesLoader, RegionalConfigResolver, FluentLoader, Config
use std::sync::{atomic::AtomicU64, Arc};
use tokio::sync::broadcast;
use crate::{
    config::Config,
    domain::{
        country_rules::CountryRulesLoader,
        fluent_loader::FluentLoader,
        regional_config::RegionalConfigResolver,
    },
};

/// Contexto del servidor — clonación barata por Arc interno.
/// Todos los servidores reciben una copia de este struct; comparten los mismos datos.
#[derive(Clone)]
pub struct ServerContext {
    /// Catálogo de reglas por país (recargable en SIGHUP).
    pub loader: Arc<CountryRulesLoader>,
    /// Resolutor de configuración regional (MVP: estático; prod: por request).
    pub resolver: Arc<dyn RegionalConfigResolver>,
    /// Mensajes Fluent localizados (recargables en SIGHUP — Bloque 4).
    pub fluent: Arc<FluentLoader>,
    /// Configuración del daemon (lectura en tiempo de arranque).
    pub config: Arc<Config>,
    /// Contador de solicitudes activas (para drenado en SIGHUP — GAP-03).
    pub activas: Arc<AtomicU64>,
    /// Canal de eventos push para todos los clientes WebSocket conectados.
    /// Capacidad 64: si un cliente se retrasa, pierde eventos intermedios (lagged).
    pub push_tx: broadcast::Sender<String>,
}

impl ServerContext {
    /// Construye el contexto completo del servidor.
    pub fn nuevo(
        loader: Arc<CountryRulesLoader>,
        resolver: Arc<dyn RegionalConfigResolver>,
        fluent: Arc<FluentLoader>,
        config: Arc<Config>,
        activas: Arc<AtomicU64>,
        push_tx: broadcast::Sender<String>,
    ) -> Self {
        Self { loader, resolver, fluent, config, activas, push_tx }
    }

    /// Incrementa el contador de solicitudes activas.
    pub fn solicitud_iniciada(&self) {
        self.activas.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    }

    /// Decrementa el contador de solicitudes activas.
    pub fn solicitud_finalizada(&self) {
        self.activas.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }

    /// Emite un evento push `translations.updated` a todos los clientes WebSocket.
    /// Si no hay clientes conectados, la operación es silenciosa (broadcast::SendError ignorado).
    pub fn emitir_traducciones_actualizadas(&self, namespace: &str, locale: &str) {
        let evento = serde_json::json!({
            "event": "translations.updated",
            "namespace": namespace,
            "locale": locale,
        }).to_string();
        let _ = self.push_tx.send(evento);
    }
}
