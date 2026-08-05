//! Capa de transporte — conexión WebSocket hacia bhnexus Puerta 1.
//! DOC-SBOS-001 N3 · BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

mod conexion;
mod heartbeat;

use crate::config::BanexusConfig;

/// Conecta a bhnexus y mantiene la sesión activa con reconexión automática.
pub async fn conectar_y_mantener(cfg: BanexusConfig) -> anyhow::Result<()> {
    conexion::ejecutar_con_reconexion(cfg).await
}
