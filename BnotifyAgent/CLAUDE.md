# CLAUDE.md — BnotifyAgent (bnotify)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-Partitura-Maestra (en concepción).md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bnotify** — bnotify — Sistema de Notificaciones Universales. Push MFA, alertas y mensajes a clientes. Ficha sbos-notifier — CRÍTICA (el MFA de bAuth depende de ella). Estado: en concepción (Partitura Maestra).

## Producto que desarrolla
bnotify — Sistema de Notificaciones Universales · **Plano:** Notificación · **Stack:** por definir (Rust/Go) — daemon nativo en concepción

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bnotify.sock` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `bnotify.*` · Puerto: 28200-28205 (S06)
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BnotifyAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (bauth (Push MFA) · biedata (datos de destinatarios)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bnotify-push-mfa`
- `bnotify-plantillas-mensajes`
