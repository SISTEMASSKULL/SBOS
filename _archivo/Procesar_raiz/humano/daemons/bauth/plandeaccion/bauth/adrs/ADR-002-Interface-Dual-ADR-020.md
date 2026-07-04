# ADR-002 — Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre Unix Socket

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

bAuth debe ser invocable tanto por humanos (CLI `bauthctl`, Core UI) como por otros daemons y agentes IA (biedata, bkernel, sagas automatizadas). La comunicación entre daemons está restringida por SBOS-050 P9: HTTP vetado entre daemons. Solo se permite Unix socket o WebSocket.

## Decisión

**Interface Dual sobre un mismo Unix socket `/run/bos/bauth.sock` (0660, grupo bosagent):**

- **Vía 1 — WebSocket RPC**: para `bauthctl` CLI y Core UI (administración humana, comandos interactivos)
- **Vía 2 — JSON-RPC 2.0**: para biedata, bkernel, bauth, bsearch y agentes IA (invocación programática, sagas, automatización)

El socket multiplexa ambos protocolos — WebSocket upgrade vs JSON-RPC directo se discrimina por el primer byte de la request.

## Alternativas

| Alternativa | Problema |
|------------|---------|
| HTTP REST | Violaría SBOS-050 P9 (HTTP vetado entre daemons). Requiere puerto TCP adicional. |
| gRPC exclusivo | No apto para CLI humano (requiere protobuf toolchain). JSON-RPC es más accesible para agentes IA. |
| Dos sockets separados | Complejidad innecesaria. Un socket = un punto de administración. |

## Consecuencias

- 14 métodos JSON-RPC documentados (B18.T09-T14): roltemplate.*, usertemplate.*, auth.validate, ctx.*, sign.*, dominio.evaluate
- Todos los daemons y smarts siguen el mismo patrón (ADR-020 generalizado)
- Sin puertos TCP adicionales — cumple SBOS-050 P9

## Referencias
- ADR-020 (Interface Dual obligatoria para todos los daemons)
- SBOS-050 P9 (Port Catalog: HTTP vetado entre daemons)
- JSON-RPC 2.0 Specification
