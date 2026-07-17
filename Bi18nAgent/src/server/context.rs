/// server/context.rs — Contexto compartido entre los tres servidores (Interface Triple).
/// Propósito: concentra todos los recursos del daemon en un Arc clonable.
///   - JSON-RPC, gRPC y WebSocket comparten EXACTAMENTE el mismo contexto.
///   - Garantía de paridad de capacidades (C11): misma lógica, distinto transporte.
/// Dependencias: Arc, CountryRulesLoader, RegionalConfigResolver, FluentLoader, Config
use std::sync::{atomic::AtomicU64, Arc};
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
}

impl ServerContext {
    /// Construye el contexto completo del servidor.
    pub fn nuevo(
        loader: Arc<CountryRulesLoader>,
        resolver: Arc<dyn RegionalConfigResolver>,
        fluent: Arc<FluentLoader>,
        config: Arc<Config>,
        activas: Arc<AtomicU64>,
    ) -> Self {
        Self { loader, resolver, fluent, config, activas }
    }

    /// Incrementa el contador de solicitudes activas.
    pub fn solicitud_iniciada(&self) {
        self.activas.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    }

    /// Decrementa el contador de solicitudes activas.
    pub fn solicitud_finalizada(&self) {
        self.activas.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }
}
