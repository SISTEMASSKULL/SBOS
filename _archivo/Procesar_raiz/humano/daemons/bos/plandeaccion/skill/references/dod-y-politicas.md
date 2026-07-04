# DoD Universal y Políticas SFP — BOS-REPAIR

## Definition of Done (DoD) Universal

Todo átomo debe cumplir estos criterios antes de marcarse ✅.
Ejecutar desde `BosAgent/src/`:

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src

echo "=== DOD UNIVERSAL ==="
go build ./...                            && echo "✅ BUILD"  || echo "❌ BUILD FALLA — no cerrar átomo"
go vet ./...                              && echo "✅ VET"    || echo "❌ VET FALLA"
gofmt -l . | wc -l | grep "^0$"          && echo "✅ FORMAT" || echo "❌ FORMAT — ejecutar: gofmt -w ."
go test -race -count=10 ./...             && echo "✅ TESTS"  || echo "❌ TESTS FALLAN"

# Godoc en todo código exportado nuevo
grep -rn "^// [A-Z]" <paquete_nuevo>/*.go | wc -l | grep -E "^[1-9]" && echo "✅ GODOC"

# Legado archivado si se extrajo código
ls _legacy/*$(date +%Y-%m-%d)* 2>/dev/null && echo "✅ LEGACY ARCHIVADO" || echo "⚠️  SIN LEGACY (OK si no hubo extracción)"
```

**Criterio de cierre:** todos ✅ antes de marcar el átomo en REGISTRO-ESTADO.md.

---

## Políticas SFP (Strangler Fig Pattern) — NUNCA VIOLAR

### SFP-01 — Nunca borrar, siempre archivar
```bash
# ANTES de modificar cualquier bloque de código existente:
cp <archivo_origen> _legacy/$(date +%Y-%m-%d)_F<X.Y>_<descripcion>.go

# El archivo archivado lleva este header:
// ARCHIVADO: F<X.Y> — $(date +%Y-%m-%d)
// Origen: <ruta original>
// Razón: <por qué se extrae/modifica>
// Informe de Cierre: informes-cierre/INFORME-CIERRE-F<X.Y>-*.md
```

### SFP-02 — Coexistencia verificada
```
El código nuevo compila y pasa go test -race ANTES de tocar el archivo origen.
El origen se vacía (no se borra) solo cuando el nuevo pasa todos los tests.
```

### SFP-03 — Feature flags de migración
```bash
# Cada extracción mayor usa variable de entorno:
BOS_OBSERVER_V2=true   → usa internal/observer/ (nuevo)
BOS_OBSERVER_V2=false  → usa runObserverLoop en main.go (legado)
BOS_TUI_V2=true        → usa internal/tui/ (nuevo)

# El legado permanece disponible hasta validación en staging.
# Staging: ssh root@13.140.128.230
# Activar: systemctl edit bos-staging.service → Environment=BOS_OBSERVER_V2=true
```

### SFP-04 — Un átomo = un commit semántico
```
Formato: [FASE-X.Y] tipo: descripcion_breve

Ejemplos correctos:
  [F0.1] feat: crear _legacy/ y README memoria del proyecto
  [F1.5] fix: mutex compartido anti-race en internal/observer/
  [F3.2] refactor: Screen enum a internal/tui/model/types.go
  [F7.8] docs: 3 runbooks operacionales + índice + log de incidentes

El cuerpo del commit incluye el número de Informe de Cierre.
```

### SFP-05 — Sin regresión de compilación
```bash
# go build ./... debe pasar VERDE en CADA commit.
# Si rompe inmediatamente después de un commit:
git revert HEAD    # revertir
# Analizar qué falló, nueva estrategia, luego reintentar.
# NUNCA hacer push con build roto.
```

### SFP-06 — _legacy/ es la memoria del proyecto
```
_legacy/README.md contiene la tabla completa de código archivado.
Actualizar en cada átomo que archive código.

Formato de la tabla:
| Archivo | Fase | Origen | Fecha | Qué resolvía | Informe de Cierre |
```

---

## Plantilla de Informe de Cierre

Crear en `plandeaccion/plandeaccion/informes-cierre/INFORME-CIERRE-FX.Y-[NOMBRE].md`:

```markdown
## INFORME DE CIERRE — Átomo [FX.Y]
**ID:** FX.Y — [nombre del átomo]
**Estado:** ✅ CERRADO
**Inicio:** YYYY-MM-DD HH:MM | **Cierre:** YYYY-MM-DD HH:MM | **Duración real:** Xh

### Resumen ejecutivo
[2-3 oraciones: qué se hizo, qué problema resolvió, resultado]

### Cambios realizados
| Archivo | Acción | Líneas Δ |
|---|---|---|
| path/to/nuevo.go | CREADO | +N |
| path/to/origen.go | VACIADO | -N |
| _legacy/fecha_desc.go | ARCHIVADO | ref |

### Código preservado en `_legacy/`
[Lista o "Ninguno — átomo no extrajo código legado"]

### Evidencia de validación
[Output real del DoD Universal]

### Problemas encontrados y resolución
[Descripción y resolución, o "Ninguno"]

### Decisiones técnicas tomadas
[Decisiones no obvias — CRÍTICO para continuidad entre sesiones]

### Señal de retoma
[Si quedó incompleto: exactamente dónde continuar]

### Impacto en átomos dependientes
[Qué átomos posteriores dependen de este]
```

---

## Formato de entrada del SESION-LOG

```markdown
## SESIÓN — YYYY-MM-DD HH:MM

**Agente:** Claude Code (Sonnet 4.x)
**Operador:** [nombre o "autónomo"]

### Apertura
- Build al abrir: ✅ / 🔴 [descripción]
- DATA RACE: ninguna / [descripción]
- Último commit: [hash] — [mensaje]
- Cambios sin commit: ninguno / [lista]
- Átomo a ejecutar: FX.Y — [nombre]
- Motivo: retoma / siguiente / solicitado
- Gate de aprobación: sí (pendiente) / no aplica
- Inventario BosAgent/ raíz: [primera sesión: listar archivos encontrados]

### Ejecución
- Pasos ejecutados: [resumen]
- Problemas: ninguno / [descripción y resolución]
- Decisiones técnicas no obvias: [DOCUMENTAR SIEMPRE]
- Código archivado: ninguno / [lista]

### Cierre
- Átomo FX.Y: ✅ COMPLETO / 🟡 EN PROGRESO / ❌ BLOQUEADO
- Commit: [hash] / WIP [hash] / ninguno
- Build al cerrar: ✅ / 🔴
- Pipeline CI: ✅ / ❌ / ⏳
- Informe de Cierre: creado / pendiente / no aplica
- Próximo átomo: FX.Z — [nombre]
- Notas críticas para la próxima sesión: [ESENCIAL]
- Duración: ~X min
```

*dod-y-politicas.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
