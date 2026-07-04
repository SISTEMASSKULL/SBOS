# CLAUDE.md — BiedataAgent (biedata)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-024-DAEMON-BIEDATA.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**biedata** — Data Gateway — Orquestador JSON-RPC 2.0 (aduana soberana BC-08). Punto ÚNICO de lectura/escritura de datos entre apps del ecosistema. Fichas declarativas (manifest + validation + task_catalog). NO llama APIs externas directamente — cada app maneja las suyas. Servidor 3 capas (ORQUESTA-043).

## Producto que desarrolla
Data Gateway — Orquestador JSON-RPC 2.0 (aduana soberana BC-08) · **Plano:** Integración · **Stack:** Rust 1.85+ (tokio)

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/biedata.sock` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `biedata.*` · Puerto: 9470
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BiedataAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (bos (sagas de infraestructura) · bkernel (eventos CDC)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `biedata-jsonrpc-3capas`
- `biedata-fichas-declarativas`
