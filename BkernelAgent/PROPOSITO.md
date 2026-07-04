# PROPOSITO — BkernelAgent (bKernel)

**Rol:** Data Kernel — Listener CDC + Fanout Engine
**Plano:** Datos · **Stack:** Rust 1.85+ (tokio) · **Doc:** `context/BOS_V8/BOS_V8_SBOS-023-DAEMON-BKERNEL.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Escucha el WAL de PostgreSQL (pgoutput), normaliza eventos y los publica en Redis Streams. NO escribe en BDs de apps ni expone API REST. Loop prevention vía pg_replication_origin.
- **Socket:** `/run/bos/bkernel.sock` · **Namespace JSON-RPC:** `bkernel.*` · **Puerto:** — (solo métricas, sin API — SBOS-050 P9)
- **Métodos principales:**
  - `bkernel.cdc.status`
  - `bkernel.fanout.stats`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
