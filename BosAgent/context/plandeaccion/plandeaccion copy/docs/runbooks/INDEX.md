# Runbooks Operacionales — SBOS · SKULL
## Índice · docs/runbooks/

**Versión:** 1.0 · Junio 2026
**Átomos del plan:** F7.8 (GAP 3 cerrado)

---

## Qué es un runbook en SBOS

Un runbook es el procedimiento exacto que un operador (o el agente biaos)
debe seguir para resolver un tipo específico de incidente. Cada runbook:

- Tiene **síntomas observables** que activan su uso — ninguna ambigüedad
- Cubre **múltiples causas** con árbol de decisión explícito
- Da **comandos exactos** listos para ejecutar — no descripciones
- Incluye **verificación final** — el operador sabe cuándo el incidente terminó
- Registra en el **log de incidentes** — trazabilidad ISO 27001 A.8.15

---

## Runbooks disponibles

| ID | Nombre | Síntoma principal | SLO afectado | Estado |
|---|---|---|---|---|
| RB-01 | Ficha en estado DEGRADADA | `.fichas[].state == "DEGRADADA"` | MTTR < 10min | ✅ v1.0 |
| RB-02 | DATA RACE detectada | `journalctl \| grep "DATA RACE"` | Estabilidad daemon | ✅ v1.0 |
| RB-03 | Context Plane Down | C-13 falla / bos.ctx.device.register > 2s | p99 < 2s | ✅ v1.0 |

---

## Log de incidentes

Cada incidente resuelto con un runbook debe registrarse en:
`docs/runbooks/INCIDENTES-LOG.md`

Formato mínimo:
```markdown
## YYYY-MM-DD HH:MM — [RB-XX] Descripción breve

**Ficha/componente afectado:** X
**Causa confirmada:** Y
**Tiempo de resolución:** N minutos
**Solución aplicada:** Z
**Runbook seguido:** RB-XX — ¿completamente? ¿algún paso no aplicó?
**Acción preventiva:** [si aplica]
```

---

## Agregar un nuevo runbook

Cuando aparezca un tipo de incidente no cubierto:

```
1. Crear: docs/runbooks/RB-0N-nombre-descriptivo.md
2. Seguir la estructura de RB-01 (síntomas → diagnóstico → árbol de decisión → casos → verificación)
3. Agregar entrada en esta tabla
4. Referenciar el átomo del plan que resuelve la causa raíz (si existe)
5. Registrar en INCIDENTES-LOG.md el primer incidente que motivó el runbook
```

---

## Runbooks candidatos (futuros)

| Prioridad | Incidente | Motivación |
|---|---|---|
| Alta | VDI Layer degradado (semáforo ROJO) | Involucra 4 componentes — necesita su propio runbook |
| Alta | Pipeline CI falla (race detection) | F0.5 activo — los desarrolladores necesitan saber qué hacer |
| Media | Ficha en ERROR_NO_CORREGIBLE | Reintentos agotados — requiere intervención humana específica |
| Media | bos.service no arranca (systemd) | Puede ser config, binario, o estado corrupto |
| Baja | biaos no responde (F10.x) | Gateway LLM caído o sin conectividad |

---

*runbooks/INDEX.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
