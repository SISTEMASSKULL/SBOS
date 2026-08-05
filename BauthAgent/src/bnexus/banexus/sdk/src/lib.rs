//! banexus-sdk — DLL FFI para Flutter desktop (dart:ffi).
//!
//! Flutter carga esta biblioteca con `DynamicLibrary.open('banexus.dll')`
//! y llama a las funciones C exportadas. No hay proceso separado ni puerto TCP local.
//!
//! Flujo:
//!   banexus_init(config_json) → conecta a bhnexus, hace handshake
//!   banexus_llamar(método, params_json) → rpc_call → rpc_response → JSON string
//!   banexus_liberar(ptr) → libera la cadena retornada por banexus_llamar
//!   banexus_estado() → 0=no-init 2=conectado 3=error
//!   banexus_cerrar() → libera recursos
//!
//! SSOT: SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.3

mod ffi;
mod protocolo;

// ─── Directivas de exportación PE (Windows) ──────────────────
// La sección .drectve incrusta directivas de linker en el COFF object.
// El linker lee esta sección y añade las funciones a la PE export table.
// Necesario porque cargo-zigbuild (zig/lld MinGW) no procesa .def externos
// y #[no_mangle] pub extern "C" no setea __declspec(dllexport) en GNU target.
// Tipo [u8; 114]: los bytes van directo a .drectve (no un fat pointer).
#[cfg(target_os = "windows")]
#[link_section = ".drectve"]
#[used]
static DRECTVE: [u8; 114] = *b" /EXPORT:banexus_init /EXPORT:banexus_llamar /EXPORT:banexus_liberar /EXPORT:banexus_estado /EXPORT:banexus_cerrar";

use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

// ─── Estado global ───────────────────────────────────────────

/// Estado global del SDK — inicializado una sola vez por proceso.
static SDK: OnceLock<Mutex<Option<SdkState>>> = OnceLock::new();
/// Contador de seq para correlacionar rpc_call / rpc_response.
static SEQ: AtomicU64 = AtomicU64::new(1);

/// Estado interno del SDK tras inicialización exitosa.
struct SdkState {
    /// Runtime tokio multi-hilo que ejecuta la tarea bhnexus.
    rt: Arc<tokio::runtime::Runtime>,
    /// Canal para enviar peticiones a la tarea bhnexus.
    tx: tokio::sync::mpsc::UnboundedSender<Peticion>,
}

/// Petición RPC interna: payload JSON + canal de respuesta.
pub struct Peticion {
    pub payload: Value,
    pub seq: u64,
    pub resp_tx: tokio::sync::oneshot::Sender<Result<Value, String>>,
}

/// Configuración pasada a banexus_init vía JSON.
pub struct SdkConfig {
    pub bhnexus_addr: String,
    pub node_id: String,
    pub dev_mode: bool,
}

// ─── API C exportada ─────────────────────────────────────────

/// Inicializa el SDK y conecta a bhnexus.
///
/// config_json: `{"bhnexus_addr":"host:9444","node_id":"...","dev_mode":true}`
///
/// Retorna: 0 OK · -1 UTF-8 · -2 JSON inválido · -3 error de conexión.
/// Bloquea hasta que el handshake con bhnexus termina (~100-500 ms).
/// Si ya está inicializado, retorna 0 inmediatamente.
#[no_mangle]
pub extern "C" fn banexus_init(config_json: *const c_char) -> i32 {
    let cfg_str = unsafe {
        match CStr::from_ptr(config_json).to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return -1,
        }
    };

    let cfg: Value = match serde_json::from_str(&cfg_str) {
        Ok(v) => v,
        Err(_) => return -2,
    };

    let config = SdkConfig {
        bhnexus_addr: cfg["bhnexus_addr"].as_str().unwrap_or("127.0.0.1:9444").to_owned(),
        node_id: cfg["node_id"].as_str().unwrap_or("desktop-sdk").to_owned(),
        dev_mode: cfg["dev_mode"].as_bool().unwrap_or(true),
    };

    match init_impl(config) {
        Ok(_) => 0,
        Err(_) => -3,
    }
}

/// Llama a un método bAuth via bhnexus (síncrono).
///
/// metodo: nombre del método, p.ej. `"bauth.health.check"`
/// params_json: parámetros como JSON object, p.ej. `"{}"`
///
/// Retorna puntero a JSON string con la respuesta JSON-RPC 2.0.
/// **El caller DEBE liberar el puntero con `banexus_liberar`.**
/// Nunca retorna null — en error retorna un objeto `{"error":{...}}`.
#[no_mangle]
pub extern "C" fn banexus_llamar(
    metodo: *const c_char,
    params_json: *const c_char,
) -> *mut c_char {
    let metodo_str = unsafe {
        match CStr::from_ptr(metodo).to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return ptr_json_error(-1, "método con UTF-8 inválido"),
        }
    };

    let params: Value = if params_json.is_null() {
        json!({})
    } else {
        unsafe {
            CStr::from_ptr(params_json)
                .to_str()
                .ok()
                .and_then(|s| serde_json::from_str(s).ok())
                .unwrap_or(json!({}))
        }
    };

    let seq = SEQ.fetch_add(1, Ordering::Relaxed);

    let payload = json!({
        "jsonrpc": "2.0",
        "method":  metodo_str,
        "params":  params,
        "id":      seq,
    });

    // Obtener runtime y canal sin mantener el mutex durante el block_on
    let (rt, tx) = match obtener_rt_y_tx() {
        Some(v) => v,
        None => return ptr_json_error(-2, "SDK no inicializado — llama banexus_init primero"),
    };

    let (resp_tx, resp_rx) = tokio::sync::oneshot::channel();
    let _ = tx.send(Peticion { payload, seq, resp_tx });

    // Bloqueamos el hilo actual (hilo del isolate Dart) hasta tener respuesta.
    // El runtime tokio procesa la petición en sus propios hilos.
    let resultado = rt.block_on(async move {
        tokio::time::timeout(std::time::Duration::from_secs(30), resp_rx).await
    });

    let json_str = match resultado {
        Ok(Ok(Ok(v)))  => v.to_string(),
        Ok(Ok(Err(e))) => json!({"jsonrpc":"2.0","error":{"code":-32000,"message":e},"id":seq}).to_string(),
        Ok(Err(_))     => json!({"jsonrpc":"2.0","error":{"code":-32001,"message":"canal cerrado"},"id":seq}).to_string(),
        Err(_)         => json!({"jsonrpc":"2.0","error":{"code":-32002,"message":"timeout 30s"},"id":seq}).to_string(),
    };

    match CString::new(json_str) {
        Ok(cs) => cs.into_raw(),
        Err(_) => ptr_json_error(-3, "respuesta contiene bytes nulos"),
    }
}

/// Libera un puntero retornado por `banexus_llamar`.
/// OBLIGATORIO llamar para cada puntero recibido — sin esto hay memory leak.
#[no_mangle]
pub extern "C" fn banexus_liberar(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)); }
    }
}

/// Estado de la conexión: 0=no-init · 2=conectado · 3=error.
#[no_mangle]
pub extern "C" fn banexus_estado() -> i32 {
    let sdk = SDK.get_or_init(|| Mutex::new(None));
    if sdk.lock().unwrap().is_some() { 2 } else { 0 }
}

/// Cierra la conexión y libera el runtime tokio.
#[no_mangle]
pub extern "C" fn banexus_cerrar() {
    let sdk = SDK.get_or_init(|| Mutex::new(None));
    *sdk.lock().unwrap() = None;
}

// ─── Internos ────────────────────────────────────────────────

/// Inicializa el runtime, conecta a bhnexus y espera el handshake.
fn init_impl(config: SdkConfig) -> Result<(), String> {
    let sdk = SDK.get_or_init(|| Mutex::new(None));

    // Ya inicializado — no-op
    if sdk.lock().unwrap().is_some() {
        return Ok(());
    }

    let rt = Arc::new(
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?,
    );

    let (peticion_tx, peticion_rx) = tokio::sync::mpsc::unbounded_channel::<Peticion>();
    let (ready_tx, ready_rx) = tokio::sync::oneshot::channel::<Result<(), String>>();

    // Lanzar la tarea de conexión en el runtime
    rt.spawn(protocolo::tarea_bhnexus(peticion_rx, config, ready_tx));

    // Esperar handshake — block_on en este hilo, tokio procesa en sus hilos
    rt.block_on(ready_rx)
        .map_err(|_| "tarea bhnexus terminó antes del handshake".to_owned())??;

    *sdk.lock().unwrap() = Some(SdkState { rt, tx: peticion_tx });
    Ok(())
}

/// Extrae el runtime y el canal sin mantener el mutex.
fn obtener_rt_y_tx() -> Option<(
    Arc<tokio::runtime::Runtime>,
    tokio::sync::mpsc::UnboundedSender<Peticion>,
)> {
    let sdk = SDK.get_or_init(|| Mutex::new(None));
    let guard = sdk.lock().unwrap();
    guard.as_ref().map(|s| (Arc::clone(&s.rt), s.tx.clone()))
}

/// Genera un puntero a JSON de error (nunca null).
fn ptr_json_error(code: i32, msg: &str) -> *mut c_char {
    let json = json!({"jsonrpc":"2.0","error":{"code":code,"message":msg},"id":null});
    CString::new(json.to_string()).unwrap().into_raw()
}
