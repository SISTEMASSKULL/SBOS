# CLAUDE.md — BintelligenceAgent (bSearch)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-026-DAEMON-BSEARCH.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bSearch** — Motor de Búsqueda Soberano — PostgreSQL 18+ nativo. Solo PostgreSQL 18+ nativo (GIN, tsvector, pg_trgm). WebSocket exclusivo (wss://). Consume del Redis Stream bkernel:index_queue. Concepto futuro: pgvector para búsqueda vectorial. NO usa Meilisearch en el core.

## Producto que desarrolla
Motor de Búsqueda Soberano — PostgreSQL 18+ nativo · **Plano:** Búsqueda · **Stack:** Go 1.22

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bsearch.sock` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `bsearch.*` · Puerto: 9493
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BintelligenceAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (bkernel (Redis Stream bkernel:index_queue)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bsearch-postgres-nativo-gin-tsvector`
- `bsearch-websocket-wss`
