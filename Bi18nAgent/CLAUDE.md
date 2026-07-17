# CLAUDE.md — Bi18nAgent (bi18n)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/i18n-orchestrator-rust.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bi18n** — Orquestador Universal de Internacionalización. Un crate Rust (`i18n-orchestrator`) + daemon systemd (`bi18nd`) que provee una API unificada de i18n para todo el ecosistema SBOS: localización (BCP 47), traducción (Fluent), formato fecha/hora (jiff + ICU4X), números, monedas, unidades, validación regional (teléfono, documentos de identidad), máscaras de entrada y PII, collation, bidi, y resolución multi-tenant de configuración regional. No reimplementa nada — **orquesta** las librerías correctas detrás de una sola API.

## Producto que desarrolla
`i18n-orchestrator` — crate Rust de propósito general + daemon `bi18nd` · **Plano:** Infraestructura transversal · **Stack:** Rust 1.85+ (MUSL)

## Interfaz (C11 ORQUESTA-048 — Interface Triple)

| Vía | Socket / Transporte | Protocolo | Consumidores |
|---|---|---|---|
| **WebSocket RPC** | `/run/bos/bi18n.sock` (0660, grupo `bos`) | WebSocket + JSON-RPC 2.0 framing | CLI humano, scripts, diagnóstico |
| **JSON-RPC 2.0** | mismo `/run/bos/bi18n.sock` | JSON-RPC 2.0 newline-delimited (ADR-020) | Daemons SBOS (bAuth, bpay, btax…) |
| **gRPC** | `/run/bos/bi18n-grpc.sock` (0660, grupo `bos`) | gRPC sobre Unix domain socket (HTTP/2 sin TCP) | Daemons con cliente tonic, integración binaria |

- CLI: `i18nctl` (clap) — mismo core, mismos métodos, sin socket.
- Namespace JSON-RPC `bi18n.*` · gRPC package `bi18n.v1` · Puertos TCP: **ninguno** (todo via Unix socket — SBOS-050 P9).
- Proto canónico: `proto/bi18n.proto` · Especificación completa: Anexo A.03.
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`Bi18nAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
**Interface Triple (C11)** · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).
- **Formato de documentos: Markdown (.md) obligatorio.** HTML solo a pedido explícito del humano.
- **C12 — AA-1 Evidencia obligatoria:** toda afirmación verificable con `verificar_afirmacion.sh`.

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bi18n-locale-resolver`
- `bi18n-format-engine`
- `bi18n-country-rules`
- `bi18n-attr-pipeline`
