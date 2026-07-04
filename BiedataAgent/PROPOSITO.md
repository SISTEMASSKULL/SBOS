# PROPOSITO — BiedataAgent (biedata)

**Rol:** Data Gateway — Orquestador JSON-RPC 2.0 (aduana soberana BC-08)
**Plano:** Integración · **Stack:** Rust 1.85+ (tokio) · **Doc:** `context/BOS_V8/BOS_V8_SBOS-024-DAEMON-BIEDATA.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Punto ÚNICO de lectura/escritura de datos entre apps del ecosistema. Fichas declarativas (manifest + validation + task_catalog). NO llama APIs externas directamente — cada app maneja las suyas. Servidor 3 capas (ORQUESTA-043).
- **Socket:** `/run/bos/biedata.sock` · **Namespace JSON-RPC:** `biedata.*` · **Puerto:** 9470
- **Métodos principales:**
  - `biedata.fiscal.factura.obtener_datos`
  - `biedata.saga.execute`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
