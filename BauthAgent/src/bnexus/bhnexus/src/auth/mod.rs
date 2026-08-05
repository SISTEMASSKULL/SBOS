//! Motor de autenticación de Puerta 1 — Etapa 1: dev CA autofirmada.
//! Etapa 3: reemplazar por SPIFFE/SVID desde Vault/SPIRE.
//! SSOT: BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

mod dev_auth;

pub use dev_auth::DevCa;
