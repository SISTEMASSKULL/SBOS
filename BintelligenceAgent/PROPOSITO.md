# PROPOSITO — BintelligenceAgent (bSearch)

**Rol:** Motor de Búsqueda Soberano — PostgreSQL 18+ nativo
**Plano:** Búsqueda · **Stack:** Go 1.22 · **Doc:** `context/BOS_V8/BOS_V8_SBOS-026-DAEMON-BSEARCH.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Solo PostgreSQL 18+ nativo (GIN, tsvector, pg_trgm). WebSocket exclusivo (wss://). Consume del Redis Stream bkernel:index_queue. Concepto futuro: pgvector para búsqueda vectorial. NO usa Meilisearch en el core.
- **Socket:** `/run/bos/bsearch.sock` · **Namespace JSON-RPC:** `bsearch.*` · **Puerto:** 9493
- **Métodos principales:**
  - `bsearch.query.execute`
  - `bsearch.index.status`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
