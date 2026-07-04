# CLAUDE.md — BnexusAgent (bhnexus + banexus)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-039-DAEMON-NEXUS.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bhnexus + banexus** — Nexus — Proxy de Hardware Universal + Centinela Edge. Nexus Host (bhnexus): WebSocket mTLS (10K+ conexiones), Hardware Bridge (OSDP/MQTT/ONVIF/Wiegand), Auth Cache in-memory (TTL 30s). Nexus Agent (banexus): centinela edge en Fedora VDI, interceptor USB/shell (udev+PAM+polkit), Policy Cache efímero (AES-256-GCM).

## Producto que desarrolla
Nexus — Proxy de Hardware Universal + Centinela Edge · **Plano:** Conectividad / Edge · **Stack:** Go 1.22

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bhnexus.sock (+ /run/bos/banexus.sock)` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `bhnexus / banexus.*` · Puerto: 9444 (bhnexus)
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BnexusAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (bauth (validación de identidad por Unix socket)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `nexus-mtls-hardware-bridge`
- `nexus-edge-udev-interceptor`
