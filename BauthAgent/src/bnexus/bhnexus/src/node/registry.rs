//! Registro en memoria de nodos banexus activos.
//! Operaciones concurrentes via RwLock — lectura sin bloqueo.
//! SSOT: BnexusAgent/context/Documentacion/1.03_MANUAL-IDENTIDADES-NEXUS.md

use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

/// Información de un nodo banexus conectado.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct NodoConectado {
    /// Identificador único del nodo (generado al conectarse).
    pub node_id: Uuid,
    /// Dirección TCP del agente (IP:puerto).
    pub addr: String,
    /// Modo de operación: "daemon" o "gateway".
    pub modo: String,
    /// Momento de conexión inicial.
    pub conectado_en: DateTime<Utc>,
    /// Último heartbeat recibido.
    pub ultimo_ping: DateTime<Utc>,
}

/// Registro compartido de nodos activos (Arc<RwLock> para concurrencia tokio).
#[derive(Clone, Default)]
pub struct RegistroNodos {
    nodos: Arc<RwLock<HashMap<Uuid, NodoConectado>>>,
}

impl RegistroNodos {
    pub fn nuevo() -> Self {
        Self::default()
    }

    /// Registra un nodo al conectarse. Retorna el node_id asignado.
    pub async fn registrar(&self, addr: String, modo: String) -> Uuid {
        let node_id = Uuid::new_v4();
        let ahora = Utc::now();
        let nodo = NodoConectado {
            node_id,
            addr,
            modo,
            conectado_en: ahora,
            ultimo_ping: ahora,
        };
        self.nodos.write().await.insert(node_id, nodo);
        node_id
    }

    /// Actualiza el timestamp del último heartbeat.
    pub async fn actualizar_ping(&self, node_id: &Uuid) {
        if let Some(nodo) = self.nodos.write().await.get_mut(node_id) {
            nodo.ultimo_ping = Utc::now();
        }
    }

    /// Elimina un nodo al desconectarse.
    pub async fn remover(&self, node_id: &Uuid) {
        self.nodos.write().await.remove(node_id);
    }

    /// Retorna lista de nodos activos (snapshot inmutable).
    pub async fn listar(&self) -> Vec<NodoConectado> {
        self.nodos.read().await.values().cloned().collect()
    }
}
