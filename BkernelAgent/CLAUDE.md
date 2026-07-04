# CLAUDE.md — BkernelAgent (bKernel)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-023-DAEMON-BKERNEL.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bKernel** — Data Kernel — Listener CDC + Fanout Engine. Escucha el WAL de PostgreSQL (pgoutput), normaliza eventos y los publica en Redis Streams. NO escribe en BDs de apps ni expone API REST. Loop prevention vía pg_replication_origin.

## Producto que desarrolla
Data Kernel — Listener CDC + Fanout Engine · **Plano:** Datos · **Stack:** Rust 1.85+ (tokio)

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bkernel.sock` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `bkernel.*` · Puerto: — (solo métricas, sin API — SBOS-050 P9)
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BkernelAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (biedata (orquesta las actualizaciones) · bsearch (consume bkernel:index_queue)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bkernel-cdc-wal-pgoutput`
- `bkernel-fanout-redis-streams`
