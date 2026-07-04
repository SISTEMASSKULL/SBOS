## INFORME DE CIERRE — Átomo F0.2
**ID:** F0.2 — `doc.go` × 11 paquetes nuevos
**Estado:** ✅ CERRADO
**Inicio:** 2026-06-09 · **Cierre:** 2026-06-09 · **Duración real:** ~15 min

### Resumen ejecutivo

Creados los 11 archivos `doc.go` de la arquitectura objetivo, uno por cada paquete
nuevo de `internal/`. Cada archivo sigue el estándar ADR-003 con 6 secciones:
Responsabilidades, Fuera de alcance, Dependencias, Callers principales,
Estándares y referencias, Ejemplo de uso.

Estos contratos son irrenunciables — definen QUÉ hace cada paquete antes de
escribir una línea de código, previniendo scope creep y malentendidos en F1-F10.

### Cambios realizados

| Paquete | Archivo | Líneas | Nota crítica |
|---|---|---|---|
| `internal/audit` | `doc.go` | +43 | ISO 27001 A.8.15 |
| `internal/bootstrap` | `doc.go` | +42 | Criterios C-01..C-08 |
| `internal/cgroup` | `doc.go` | +38 | Criterio C-02 |
| `internal/network` | `doc.go` | +38 | Criterio C-03 |
| `internal/observer` | `doc.go` | +46 | **Race P6/P14 documentada** |
| `internal/paths` | `doc.go` | +41 | Fuente única de rutas |
| `internal/context` | `doc.go` | +51 | ctx_id + alias bosctx |
| `internal/biaos` | `doc.go` | +50 | Reemplaza internal/ai/ |
| `internal/scaler` | `doc.go` | +44 | Anti-death-spiral ADR-004 |
| `internal/maintenance` | `doc.go` | +49 | Saga cordon→drain→uncordon |
| `internal/metrics` | `doc.go` | +45 | Solo loopback 127.0.0.1:9095 |

### Decisiones técnicas tomadas

1. **`internal/context` — alias `bosctx` obligatorio:** El paquete se llama `context`
   como el paquete estándar de Go. Para evitar confusión, el doc.go documenta
   explícitamente que todo caller debe importarlo con alias `bosctx`.

2. **`internal/observer` documenta el mutex ANTES de implementarlo:** La race
   condition P6/P14 (dos goroutines llamando `Repair()` sin mutex) es el bug
   más crítico del plan. Documentarla en el contrato del paquete garantiza que
   F1.5 no puede "olvidar" implementar el mutex — está en el doc del paquete.

3. **`internal/paths` sin imports:** Por diseño tiene cero dependencias internas,
   previniendo ciclos de importación. Cualquier paquete puede importarlo.

4. **`internal/metrics` — puerto 9095 solo loopback:** Documentado explícitamente
   contra SBOS-050 P6. El implementador no puede exponer el endpoint en una
   interfaz externa sin violar el contrato del doc.go.

5. **`internal/biaos` documenta la migración:** El doc.go menciona explícitamente
   que reemplaza `internal/ai/` y que el código existente se archivará en `_legacy/`
   antes de migrar (F10.2).

### Evidencia de validación (DoD F0.2)

```
✅ go build ./... — sin errores
✅ go vet ./... — sin warnings
✅ gofmt -l . — sin archivos sin formato
✅ go test -race -count=3 ./... — 4 suites pasan (config, domain, health, reconcile)
✅ 11 nuevos paquetes: [no test files] — correcto para doc.go stubs
✅ Commit 4f95388 — 11 files changed, 512 insertions
```

### Código preservado en `_legacy/`
Ninguno — F0.2 crea contratos nuevos, no modifica código existente.

### Impacto en átomos dependientes

- **F1.1..F1.5:** Al extraer funciones de `main.go`, los implementadores deben
  respetar los contratos de `audit`, `bootstrap`, `cgroup`, `network`, `observer`.
- **F1.5 (CRÍTICO):** El doc.go de `observer` ya documenta el mutex requerido —
  el implementador no puede ignorarlo.
- **F5.1..F5.6:** El doc.go de `context` es la especificación completa del
  Context Plane que se implementa en Fase 5.
- **F10.2:** La migración de `internal/ai/` a `internal/biaos/` está documentada
  en el contrato del paquete.
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
