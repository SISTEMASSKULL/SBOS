# INFORME DE CIERRE — Átomo F7.8
## Runbooks Operacionales · GAP 3 CERRADO

**Átomo:** F7.8 — 3 Runbooks operacionales (cierra GAP 3)
**Estado:** 📋 ESPECIFICACIÓN LISTA — implementación pendiente
**Fecha:** 07 de Junio, 2026
**Archivos generados:** 5 (RB-01, RB-02, RB-03, INDEX.md, INCIDENTES-LOG.md)

---

## 1. Resumen ejecutivo

El GAP 3 queda cerrado. Los 3 runbooks fueron generados íntegramente desde
la documentación del proyecto (BOS-REPAIR-00..13, código fuente real) sin
necesidad de investigación externa adicional — todo el conocimiento necesario
estaba en el knowledge del proyecto.

Los runbooks tienen un nivel de detalle superior al inicialmente planeado:
- Cada uno cubre múltiples causas del mismo síntoma (árbol de decisión)
- Los comandos son exactos y listos para ejecutar
- RB-02 incluye la advertencia crítica sobre el estado pre-F1.5 del plan
- RB-03 distingue explícitamente entre "F5.x implementado" y "F5.x pendiente"

---

## 2. Decisión de diseño: sin investigación externa

A diferencia de F0.5 (pipeline) y F0.6 (entornos), que requerían investigación
externa porque el proyecto no tenía esa información, F7.8 no requirió ningún
archivo externo. Toda la información necesaria estaba en:

- `BOS-REPAIR-00` → P6/P14 para RB-02
- `BOS-REPAIR-01` → saga estándar y SLOs para RB-01 y RB-03
- `BOS-REPAIR-08` → Context Plane para RB-03
- `BOS-REPAIR-13` → flujo end-to-end para RB-01
- `internal/repair/repair_manager.go` → fases exactas de reparación para RB-01
- `internal/state/manager.go` → estados y recovery para RB-01 y RB-02

**Esto confirma que la documentación BOS-REPAIR-00..13 es completa y suficiente
como base de conocimiento operacional.**

---

## 3. Contenido de cada runbook

### RB-01 — Ficha en estado DEGRADADA

Cubre 5 casos: OOMKilled (más común), disco lleno, dependencia caída, saga
anterior fallida, estado JSON corrupto. Incluye la advertencia §pre-F1.5
para el escenario donde P6/P14 está activa. Proporciona el árbol de decisión
completo y la verificación final con criterios C-0X.

**Comandos clave:**
```bash
bosctl rpc bos.ficha.repair '{"ficha_id":"<ID>"}'
bosctl rpc bos.ficha.probe '{"ficha_id":"<ID>"}'
bosctl bootstrap verify --only=C-0X
```

### RB-02 — DATA RACE Detectada

El runbook más técnico. Explica el mecanismo de P6/P14 con pseudocódigo,
da instrucciones para capturar el reporte de TSan, distingue entre corrupción
activa y race sin corrupción, y da tanto la solución temporal
(`watchdog_auto_repair=false`) como la solución permanente (F1.5).

**Señal de resolución permanente:**
```bash
go test -race -count=100 ./internal/observer/ -run TestObserver_NoParallelRepair
# → 100/100 sin DATA RACE
```

### RB-03 — Context Plane Down

Cubre el caso único de este runbook: distingue si el problema es de
infraestructura (Redis DB1 / PostgreSQL), de código (F5.x no implementado),
o de operación normal (contextos expirados por TTL). La cadena de dependencias
al final del documento da contexto visual del por qué este componente es
tan crítico.

---

## 4. Hallazgo: runbooks candidatos futuros

Durante la redacción se identificaron 5 incidentes adicionales que deberían
tener runbooks antes del go-live:

| Prioridad | Incidente | Cuándo crear |
|---|---|---|
| Alta | VDI Layer degradado (semáforo ROJO) | Antes de F9.9 |
| Alta | Pipeline CI falla por race | Inmediatamente (F0.5 activo) |
| Media | Ficha en ERROR_NO_CORREGIBLE | Antes de go-live |
| Media | bos.service no arranca | Antes de go-live |
| Baja | biaos no responde | Cuando F10.x complete |

Estos están registrados en `docs/runbooks/INDEX.md` para que se creen
progresivamente con el avance del plan.

---

## 5. DoD específico de F7.8

```
[✅] docs/runbooks/RB-01-FICHA-DEGRADADA.md creado
[✅] docs/runbooks/RB-02-DATA-RACE-DETECTADA.md creado
[✅] docs/runbooks/RB-03-CONTEXT-PLANE-DOWN.md creado
[✅] docs/runbooks/INDEX.md con tabla de runbooks y candidatos futuros
[✅] docs/runbooks/INCIDENTES-LOG.md con estructura para registro histórico
[✅] Cada runbook tiene: síntomas, árbol de decisión, comandos exactos, verificación
[✅] RB-02 incluye advertencia sobre estado pre-F1.5
[✅] RB-03 distingue F5.x implementado vs pendiente
[✅] Referencia a ISO 27001 A.8.15 en el log de incidentes
```

---

## 6. Ubicación en el repositorio

```
docs/
└── runbooks/
    ├── INDEX.md              ← tabla de runbooks + candidatos futuros
    ├── INCIDENTES-LOG.md     ← historial de incidentes (vacío, listo para usar)
    ├── RB-01-FICHA-DEGRADADA.md
    ├── RB-02-DATA-RACE-DETECTADA.md
    └── RB-03-CONTEXT-PLANE-DOWN.md
```

---

*Informe de Cierre F7.8 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*
*Sin anexo externo — generado desde knowledge del proyecto*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
