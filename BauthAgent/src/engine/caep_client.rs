// ============================================================
// bauth::engine::caep_client — SSF Transmitter hacia bNotify (gRPC)
//
// Propósito: transmitir eventos CAEP al método gRPC
//   `bnotify.v1.NotifyDispatcher/ReceiveCaepEvent` de bNotify sobre el
//   Unix socket /run/bos/bnotify.sock (contrato C-BAUTH-004 · C-BNOTIFY-001).
// Entradas: `EventoCaep` del dominio (domain::caep).
// Salidas: Ok(()) solo si bNotify confirmó con CaepAck{received:true}
//   — el contrato exige esperar el ACK antes de dar por entregado.
// Dependencias: tonic/prost (gRPC), tower (conector), hyper-util (TokioIo).
//   SIN tonic-build/protoc: los mensajes se declaran con `prost::Message`
//   derive — el proto canónico vive en BNOTIFY-001; los tags 1..6 son
//   contrato y no pueden cambiar.
// Estándar: OpenID SSF/CAEP 1.0 · SBOS-050 P9 (cero HTTP/TCP entre
//   daemons — el canal es Unix socket) · ADR-001 bNotify (gRPC).
// ============================================================
#![allow(dead_code)]

use crate::domain::caep::EventoCaep;
use hyper_util::rt::TokioIo;
use std::collections::HashMap;
use std::time::Duration;
use tokio::net::UnixStream;
use tonic::codegen::http::uri::PathAndQuery;
use tonic::transport::{Channel, Endpoint, Uri};
use tower::service_fn;
use tracing::{info, warn};

// ── Mensajes de alambre (proto BNOTIFY-001 — tags inmutables) ──

/// CaepEvent del contrato (tags 1..6 — NO cambiar: rompe el proto).
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CaepEventWire {
    #[prost(string, tag = "1")]
    pub event_type: String,
    #[prost(string, tag = "2")]
    pub subject_ctx_id: String,
    #[prost(string, tag = "3")]
    pub subject_user_id: String,
    #[prost(string, tag = "4")]
    pub tenant_id: String,
    #[prost(string, tag = "5")]
    pub occurred_at: String,
    #[prost(map = "string, string", tag = "6")]
    pub event_data: HashMap<String, String>,
}

/// CaepAck del contrato — bNotify confirma la recepción.
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CaepAckWire {
    #[prost(bool, tag = "1")]
    pub received: bool,
}

impl From<&EventoCaep> for CaepEventWire {
    /// Convierte el evento de dominio al mensaje de alambre.
    /// Inyecta el `event_id` determinista en `event_data` (idempotencia).
    fn from(evento: &EventoCaep) -> Self {
        let mut event_data: HashMap<String, String> =
            evento.event_data.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        event_data.insert("event_id".to_string(), evento.event_id());
        Self {
            event_type: evento.tipo.como_texto().to_string(),
            subject_ctx_id: evento.subject_ctx_id.clone(),
            subject_user_id: evento.subject_user_id.clone(),
            tenant_id: evento.tenant_id.clone(),
            occurred_at: evento.occurred_at.clone(),
            event_data,
        }
    }
}

// ── Errores (mensajes en español — DOC-SBOS-001) ──────────────

/// Error de transmisión CAEP.
#[derive(Debug, thiserror::Error)]
pub enum ErrorCaep {
    /// bNotify no está disponible (socket ausente o conexión rechazada).
    #[error("bnotify no disponible en '{0}'")]
    NoDisponible(String),
    /// Error de transporte/estado gRPC distinto de indisponibilidad.
    #[error("transporte gRPC hacia bnotify: {0}")]
    Transporte(String),
    /// bNotify respondió pero NO confirmó (received=false) — no entregado.
    #[error("bnotify no confirmó el evento (received=false)")]
    SinAck,
}

// ── Trait del transmisor (permite stub cuando bnotify no existe) ──

/// Transmisor de eventos CAEP — bAuth como SSF Transmitter.
#[async_trait::async_trait]
pub trait CaepTransmitter: Send + Sync {
    /// Transmite un evento y espera el CaepAck (contrato C-BAUTH-004).
    async fn transmitir(&self, evento: &EventoCaep) -> Result<(), ErrorCaep>;
    /// Nombre del transmisor (para logs y diagnóstico).
    fn nombre(&self) -> &'static str;
}

/// Ruta gRPC del método (servicio y método EXACTOS del contrato C-BNOTIFY-001).
const RUTA_METODO: &str = "/bnotify.v1.NotifyDispatcher/ReceiveCaepEvent";
/// Timeout por intento (contrato: reintento si no responde en 5 s).
const TIMEOUT_INTENTO: Duration = Duration::from_secs(5);
/// Máximo de intentos con backoff exponencial (contrato: 3).
const MAX_INTENTOS: u32 = 3;

// ── Implementación gRPC real ──────────────────────────────────

/// Transmisor gRPC sobre Unix socket — la implementación del contrato.
pub struct GrpcCaepTransmitter {
    /// Ruta del Unix socket de bNotify (ej. /run/bos/bnotify.sock).
    socket: String,
}

impl GrpcCaepTransmitter {
    /// Crea el transmisor apuntando al socket indicado. No conecta aún
    /// (la conexión es por llamada — volumen bajo, ciclo de vida simple).
    pub fn new(socket: &str) -> Self {
        Self { socket: socket.to_string() }
    }

    /// Abre el canal HTTP/2 sobre el Unix socket. La URI es ficticia:
    /// tonic la exige pero el conector la ignora y usa el socket.
    async fn conectar(&self) -> Result<Channel, ErrorCaep> {
        let ruta = self.socket.clone();
        Endpoint::try_from("http://bnotify.interno")
            .map_err(|e| ErrorCaep::Transporte(format!("endpoint inválido: {e}")))?
            .connect_with_connector(service_fn(move |_: Uri| {
                let ruta = ruta.clone();
                async move {
                    Ok::<_, std::io::Error>(TokioIo::new(UnixStream::connect(ruta).await?))
                }
            }))
            .await
            .map_err(|_| ErrorCaep::NoDisponible(self.socket.clone()))
    }

    /// Un intento único: conectar + unary + validar el ACK.
    async fn intento(&self, wire: CaepEventWire) -> Result<(), ErrorCaep> {
        let canal = self.conectar().await?;
        let mut grpc = tonic::client::Grpc::new(canal);
        grpc.ready()
            .await
            .map_err(|e| ErrorCaep::Transporte(format!("canal no listo: {e}")))?;
        let codec: tonic::codec::ProstCodec<CaepEventWire, CaepAckWire> =
            tonic::codec::ProstCodec::default();
        let ruta = PathAndQuery::from_static(RUTA_METODO);
        let respuesta = grpc
            .unary(tonic::Request::new(wire), ruta, codec)
            .await
            .map_err(|estado| match estado.code() {
                tonic::Code::Unavailable => ErrorCaep::NoDisponible(self.socket.clone()),
                otro => ErrorCaep::Transporte(format!("{otro:?}: {}", estado.message())),
            })?;
        if respuesta.into_inner().received { Ok(()) } else { Err(ErrorCaep::SinAck) }
    }
}

#[async_trait::async_trait]
impl CaepTransmitter for GrpcCaepTransmitter {
    /// Transmite con la garantía del contrato: espera el CaepAck; si bNotify
    /// no responde en 5 s, reintenta con backoff exponencial (3 intentos máx).
    async fn transmitir(&self, evento: &EventoCaep) -> Result<(), ErrorCaep> {
        let wire = CaepEventWire::from(evento);
        let mut ultimo = ErrorCaep::NoDisponible(self.socket.clone());
        for numero in 1..=MAX_INTENTOS {
            match tokio::time::timeout(TIMEOUT_INTENTO, self.intento(wire.clone())).await {
                Ok(Ok(())) => return Ok(()),
                Ok(Err(e)) => ultimo = e,
                Err(_) => ultimo = ErrorCaep::Transporte("timeout de 5s por intento".into()),
            }
            if numero < MAX_INTENTOS {
                // Backoff exponencial: 500 ms → 1 s (→ 2 s si hubiera más intentos).
                tokio::time::sleep(Duration::from_millis(500 * 2u64.pow(numero - 1))).await;
            }
        }
        Err(ultimo)
    }

    fn nombre(&self) -> &'static str { "grpc" }
}

// ── Stub (bnotify aún no desplegado — gate G0) ────────────────

/// Stub que registra el evento en el log sin transmitir. Se usa cuando
/// el socket de bNotify no existe al arrancar (mismo patrón que notify.rs).
pub struct StubCaepTransmitter;

#[async_trait::async_trait]
impl CaepTransmitter for StubCaepTransmitter {
    async fn transmitir(&self, evento: &EventoCaep) -> Result<(), ErrorCaep> {
        info!(
            event_type = evento.tipo.como_texto(),
            ctx_id = %evento.subject_ctx_id,
            event_id = %evento.event_id(),
            "[STUB] CAEP → bnotify.v1.NotifyDispatcher/ReceiveCaepEvent"
        );
        Ok(())
    }

    fn nombre(&self) -> &'static str { "stub" }
}

/// Fabrica el transmisor según el entorno: gRPC real si el socket de
/// bNotify existe al arranque; stub si no (bnotify en concepción, G0).
pub fn fabricar(socket: &str) -> std::sync::Arc<dyn CaepTransmitter> {
    if std::path::Path::new(socket).exists() {
        info!(socket, "CAEP: transmisor gRPC real hacia bNotify");
        std::sync::Arc::new(GrpcCaepTransmitter::new(socket))
    } else {
        warn!(socket, "CAEP: socket de bNotify ausente — transmisor stub (solo log)");
        std::sync::Arc::new(StubCaepTransmitter)
    }
}

// ── TESTS ───────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use prost::Message;

    #[test]
    fn test_conversion_inyecta_event_id() {
        let ev = EventoCaep::sesion_revocada("ctx-9", "u-9", "t-9", "2026-07-10T21:00:00Z", "reconcile");
        let wire = CaepEventWire::from(&ev);
        assert_eq!(wire.event_type, "session-revoked");
        assert_eq!(wire.subject_ctx_id, "ctx-9");
        assert_eq!(wire.event_data.get("event_id"), Some(&ev.event_id()));
        assert_eq!(wire.event_data.get("origen"), Some(&"reconcile".to_string()));
    }

    #[test]
    fn test_roundtrip_protobuf() {
        // Codifica y decodifica el mensaje — valida los tags prost a mano.
        let ev = EventoCaep::sesion_revocada("ctx-7", "u-7", "t-7", "2026-07-10T20:00:00Z", "test");
        let wire = CaepEventWire::from(&ev);
        let bytes = wire.encode_to_vec();
        let decodificado = CaepEventWire::decode(bytes.as_slice()).expect("decodificar");
        assert_eq!(wire, decodificado);
    }

    #[tokio::test]
    async fn test_stub_confirma_sin_transmitir() {
        let stub = StubCaepTransmitter;
        let ev = EventoCaep::sesion_revocada("ctx-1", "u", "t", "2026-07-10T21:00:00Z", "test");
        assert!(stub.transmitir(&ev).await.is_ok());
        assert_eq!(stub.nombre(), "stub");
    }

    #[tokio::test]
    async fn test_grpc_sin_socket_reporta_no_disponible() {
        let tx = GrpcCaepTransmitter::new("/tmp/no-existe-bnotify.sock");
        let ev = EventoCaep::sesion_revocada("ctx-1", "u", "t", "2026-07-10T21:00:00Z", "test");
        match tx.transmitir(&ev).await {
            Err(ErrorCaep::NoDisponible(_)) => {}
            otro => panic!("se esperaba NoDisponible, llegó: {otro:?}"),
        }
    }
}
