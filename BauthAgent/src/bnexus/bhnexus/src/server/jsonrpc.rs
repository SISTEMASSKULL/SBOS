//! Dispatcher JSON-RPC 2.0 — métodos bhnexus.* de Etapa 1.
//! Métodos implementados: bhnexus.health · bhnexus.status · bhnexus.node.list
//! SSOT: BnexusAgent/context/Documentacion/9.01_MANUAL-PRODUCTO-NEXUS.md

use crate::node::RegistroNodos;
use serde::Deserialize;
use serde_json::{json, Value};

/// Sobre de request JSON-RPC 2.0.
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct RpcRequest {
    jsonrpc: String,
    method: String,
    id: Option<Value>,
    params: Option<Value>,
}

/// Despacha un mensaje JSON-RPC y retorna la respuesta serializada.
pub async fn despachar(texto: &str, registro: &RegistroNodos) -> String {
    let respuesta = match serde_json::from_str::<RpcRequest>(texto) {
        Err(_) => error_parse(-32700, "Error de parse — JSON inválido", None),
        Ok(req) => {
            if req.jsonrpc != "2.0" {
                return serde_json::to_string(&error_parse(-32600, "jsonrpc debe ser '2.0'", req.id))
                    .unwrap_or_else(|_| r#"{"error":"interno"}"#.into());
            }
            match req.method.as_str() {
                "bhnexus.health"    => health(req.id),
                "bhnexus.status"    => status(req.id),
                "bhnexus.node.list" => node_list(req.id, registro).await,
                m => error_parse(
                    -32601,
                    &format!("Método no encontrado: {m}"),
                    req.id,
                ),
            }
        }
    };
    serde_json::to_string(&respuesta).unwrap_or_else(|_| r#"{"error":"interno"}"#.into())
}

fn health(id: Option<Value>) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": { "estado": "operativo", "version": "0.1.0" } })
}

fn status(id: Option<Value>) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": { "etapa": 1, "dev_mode": true } })
}

async fn node_list(id: Option<Value>, registro: &RegistroNodos) -> Value {
    let nodos: Vec<_> = registro.listar().await.iter().map(|n| {
        json!({
            "node_id": n.node_id,
            "addr": n.addr,
            "modo": n.modo,
            "ultimo_ping": n.ultimo_ping,
        })
    }).collect();
    json!({ "jsonrpc": "2.0", "id": id, "result": { "nodos": nodos } })
}

fn error_parse(code: i64, message: &str, id: Option<Value>) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": message }
    })
}
