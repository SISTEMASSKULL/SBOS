---
name: sbos-arquitectura
description: >
  El propósito común del ecosistema SBOS y su arquitectura soberana. Úsala para entender QUÉ
  persigue el proyecto (soberanía digital) y CÓMO bos, bauth, bkernel, biedata, bsearch, bnexus
  y bnotify colaboran bajo reglas comunes: planos, Interface Dual, Context Plane, puertos.
  No es cómo desarrollar un daemon (eso vive en el CLAUDE/skill de cada microservicio).
---

# Skill — Arquitectura común del ecosistema SBOS

**Propósito común (léelo en la doc del proyecto):** `context/BOS_V8/` —
`BOS_V8_SBOS-001-VISION.md`, `-002-ARCH.md`, `-003-DOMAIN.md`, `-004-RULES.md`.
El SBOS **no es un microservicio** ni un puñado sueltos: es **un ecosistema soberano** de
daemons que persiguen un **fin común** — dar soberanía de identidad, datos, búsqueda,
conectividad y notificación. Esta skill describe ese fin común y las reglas que lo hacen posible.

## Los daemons y su rol en el fin común
| Daemon | Plano | Aporte al propósito común |
|--------|-------|---------------------------|
| **bos** | Control | IAM Installer — despliega y gobierna el plano de control (fichas, sagas, Context Plane) |
| **bauth** | Identidad | Orquestador central de identidad — enruta a los motores, emite el token unificado |
| **bkernel** | Datos | Listener CDC + Fanout — WAL → Redis Streams, sin API |
| **biedata** | Integración | Orquestador JSON-RPC 2.0 — aduana única de lectura/escritura entre apps |
| **bsearch** | Búsqueda | Motor de búsqueda soberano — PostgreSQL 18+ nativo |
| **bnexus** (bh/ba) | Conectividad/Edge | Proxy de hardware universal + centinela edge |
| **bnotify** | Notificación | Push MFA y notificaciones del sistema |

Catálogo con rutas de cada uno: `paths.yml → microservicios`.

## Reglas irrenunciables COMUNES (todo daemon del ecosistema las cumple)
- **Interface Dual (ADR-020):** WebSocket RPC (humanos/CLI) + JSON-RPC 2.0 (otros daemons) sobre el **mismo** Unix socket `/run/bos/<daemon>.sock` (0660, grupo `bos`). **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9).
- **Context Plane (SBOS-049):** `ctx_id` obligatorio en toda operación — logs, auditoría, requests (ISO 27001 A.8.15).
- **Puertos (SBOS-050):** rango daemons 9400–9499; BD solo ClusterIP; deny-all salvo 22/80/443.
- **systemd en el host** (no pods K8s). K8s solo aloja infraestructura (PostgreSQL, Redis, Keycloak, Vault, Kong).
- **Naming + 3 capas:** `<componente>.<modulo>.<operacion>`; servidor Domain/RPC/Transport (ORQUESTA-043).

## Cómo colaboran (fin común, no implementación)
Un daemon consulta a otro por su **contrato** (JSON-RPC / `PROPOSITO.md`), nunca su código interno.
El **producto** de cada daemon y **cómo se desarrolla** viven en el CLAUDE/skill de **ese microservicio** —
esta skill solo explica el ecosistema y su propósito compartido.
