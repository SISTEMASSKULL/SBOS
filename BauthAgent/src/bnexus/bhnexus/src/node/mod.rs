//! Registro de nodos banexus conectados a bhnexus.
//! Estructura en memoria — TTL gestionado por heartbeat de Puerta 1.
//! SSOT: BnexusAgent/context/Documentacion/1.03_MANUAL-IDENTIDADES-NEXUS.md

mod registry;

pub use registry::RegistroNodos;
