# PROTOCOLO DE SESIÓN — Agente BOS-REPAIR
## Cómo el agente abre, ejecuta y cierra cada sesión de trabajo

**Proyecto:** BosAgent / SBOS · SKULL  
**Versión:** 1.0 · Junio 2026  
**Aplica a:** Claude Code ejecutando átomos del BOS-REPAIR-PLAN-MAESTRO-v3  
**Principio central:** Ninguna sesión empieza sin saber dónde estamos. Ninguna sesión termina sin dejar el estado escrito.

---

## Por qué existe este protocolo

Claude Code no tiene memoria entre sesiones. Una sesión puede interrumpirse a la mitad de un átomo — por un error de compilación, por un timeout, por una decisión del operador. Sin un protocolo explícito, la siguiente sesión empieza a ciegas y puede:

- Rehacer trabajo ya hecho
- Asumir que el build está limpio cuando no lo está
- Ejecutar un átomo sin verificar que el anterior está ✅
- Tomar decisiones que contradicen las del átomo anterior

El protocolo convierte al agente en un profesional de guardia: llega, lee el libro de novedades, verifica el estado del sistema, trabaja, entrega el turno documentado.

---

## Estructura de una sesión

```
APERTURA (5 min, obligatoria)
    ↓
EJECUCIÓN (variable — uno o más átomos)
    ↓
CIERRE (5 min, obligatoria)
    ↓
SESION-LOG.md actualizado
```

La apertura y el cierre son tan importantes como la ejecución. Un átomo ejecutado sin cierre es un átomo en riesgo.

---

## FASE 1 — APERTURA DE SESIÓN

### 1.1 Leer el libro de novedades

Lo primero que hace el agente al iniciar cualquier sesión:

```bash
# Conectar a VPS DEV
ssh skull@144.91.76.130
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/

# Leer el SESION-LOG.md (las últimas 2 sesiones)
tail -80 plandeaccion/plandeaccion/SESION-LOG.md
```

Si `SESION-LOG.md` no existe todavía, es la primera sesión. Crearlo con la plantilla del §Apéndice A.

**Lo que el agente busca en el log:**
- ¿Hubo un átomo interrumpido? → va directo a ese átomo
- ¿Hubo una decisión técnica no obvia? → leerla antes de tocar código
- ¿Hubo un problema que quedó sin resolver? → no avanzar hasta resolverlo

### 1.2 Verificar el estado oficial del plan

```bash
# Estado de todos los átomos
cat plandeaccion/plandeaccion/REGISTRO-ESTADO.md | grep -E "🟡|⚠️" | head -20
# Si hay algún 🟡 EN PROGRESO → ese es el átomo a retomar primero

# Resumen rápido de progreso
cat plandeaccion/plandeaccion/REGISTRO-ESTADO.md | tail -20
```

### 1.3 Ejecutar la señal de retoma global

**Este paso es obligatorio antes de tocar cualquier archivo de código.**

```bash
echo "=== SEÑAL DE RETOMA GLOBAL — $(date '+%Y-%m-%d %H:%M') ==="

echo "--- Build ---"
go build ./... && echo "✅ BUILD LIMPIO" || echo "🔴 BUILD ROTO — no continuar hasta resolver"

echo "--- Tests con race detector ---"
go test -race -count=3 ./... 2>&1 | grep -E "DATA RACE|^ok|^FAIL" | tail -20

echo "--- Estado de fases (señal de retoma BOS-REPAIR-INDEX) ---"
echo -n "F0 (paquetes):      "; [ -f internal/audit/doc.go ] && echo "✅" || echo "❌"
echo -n "F1 (infra extraída):"; grep -q "func auditLog" cmd/bos/main.go 2>/dev/null && echo "❌ auditLog en main" || echo "✅"
echo -n "F2 (WS unificado):  "; grep -rq "gorilla/websocket" cmd/ 2>/dev/null && echo "❌ gorilla en cmd/" || echo "✅"
echo -n "F3 (install_ui):    "; lines=$(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999); [ "$lines" -gt 500 ] && echo "❌ ($lines líneas)" || echo "✅"
echo -n "F4 (bosctl limpio): "; [ -f internal/security/rbac_provider.go ] && echo "❌ rbac_provider existe" || echo "✅"
echo -n "F5 (context plane): "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F6 (sagas consulta):"; grep -q "bos.query.system" internal/server/jsonrpc.go 2>/dev/null && echo "✅" || echo "❌"
echo -n "F7.8 (runbooks):    "; [ -f docs/runbooks/RB-01-FICHA-DEGRADADA.md ] && echo "✅" || echo "❌"
echo -n "F9 (operator):      "; [ -d internal/scaler ] && echo "✅" || echo "❌"
echo -n "F10 (biaos):        "; [ -f internal/biaos/gateway.go ] && echo "✅" || echo "❌"

echo ""
echo "--- Último commit ---"
git log --oneline -3

echo ""
echo "--- Archivos modificados sin commit ---"
git status --short
```

**Regla de apertura:** si el build está roto (`go build ./...` falla), el agente NO ejecuta ningún átomo nuevo. Su único trabajo en esa sesión es restaurar el build a verde. Si no puede, cierra la sesión documentando el problema.

### 1.4 Decidir qué átomo ejecutar

Con la información del log y del REGISTRO-ESTADO, el agente determina:

```
SI hay un átomo en 🟡 EN PROGRESO:
    → retomar ESE átomo (señal de retoma específica del EJECUCION-FX.Y)

SI no hay 🟡, buscar el siguiente 🔴 cuya fase previa es ✅:
    → leer EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md antes de empezar
    → si no existe EJECUCION-FX.Y → leer §FASE-X del Plan Maestro v3

SI el átomo es de RIESGO ALTO (F1.5, F4.4, F9.x destructivos):
    → GATE DE APROBACIÓN (ver §2.3 más abajo)
    → no ejecutar sin confirmación explícita del operador
```

### 1.5 Registrar apertura en SESION-LOG.md

```markdown
## SESIÓN — YYYY-MM-DD HH:MM

**Agente:** Claude Code (Sonnet 4.x)
**Estado al abrir:**
- Build: ✅ / 🔴 [indicar resultado]
- DATA RACE: ninguna / [describir si hay]
- Átomo a ejecutar: FX.Y — [nombre]
- Motivo de elección: [retoma / siguiente en secuencia / solicitado por operador]
- Novedades del log anterior: [resumen o "ninguna"]
```

---

## FASE 2 — EJECUCIÓN

### 2.1 Un átomo por sesión como norma

La norma es ejecutar **un solo átomo por sesión** a menos que el operador pida explícitamente encadenar varios. Motivo: cada átomo tiene su propio DoD, su propio informe de cierre, y su propio commit. Encadenar átomos sin cerrar cada uno aumenta la deuda de documentación y el riesgo de confusión.

**Excepción permitida:** átomos de documentación pura (F7.x, godoc) o de preparación estructural (F0.1-F0.4) pueden agruparse si son triviales y toman menos de 20 minutos cada uno.

### 2.2 Durante la ejecución

El agente sigue el archivo `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` paso a paso, sin saltear verificaciones.

En cada paso que produce un cambio en el código, el agente verifica localmente antes de continuar:

```bash
# Verificación mínima después de cualquier cambio de código:
go build ./... || { echo "🔴 BUILD ROTO — revertir cambio"; git diff HEAD; }
```

Si el build se rompe, el agente revierte con `git checkout -- <archivo>` o `git revert HEAD` y documenta el problema en el log antes de reintentar con otra estrategia. Nunca avanza con un build roto.

### 2.3 Gate de aprobación para átomos de riesgo alto

Los siguientes átomos requieren confirmación explícita del operador antes de ejecutar cualquier cambio:

| Átomo | Riesgo | Razón |
|---|---|---|
| F1.5 | ALTO | Mutex en el loop de control central — patrón incorrecto puede empeorar la race |
| F4.4 | ALTO | Eliminar rbac_provider.go — nil panic en producción si hay callers residuales |
| F9.2+ | MUY ALTO | Operaciones sobre el cluster K8s real (Scale, Cordon, Drain) |
| F9.7 | MUY ALTO | ClusterRole — permisos incorrectos = vector de ataque |
| Cualquier `kubectl delete` | CRÍTICO | Irreversible — requiere aprobación explícita y backup previo |

El gate se activa así:

```
GATE DE APROBACIÓN — Átomo [FX.Y]

El agente presenta al operador:
  1. Qué archivo va a modificar exactamente
  2. Qué líneas específicas van a cambiar (diff esperado)
  3. El riesgo si algo sale mal
  4. El plan de reversión

El agente ESPERA confirmación antes de proceder.
Sin confirmación explícita, el átomo queda en estado "PENDIENTE APROBACIÓN"
y la sesión se cierra con esa nota en el SESION-LOG.md.
```

### 2.4 Si el átomo no puede completarse en la sesión

Si el tiempo, un problema técnico o una decisión pendiente impide completar el átomo:

```bash
# Marcar el átomo como EN PROGRESO en REGISTRO-ESTADO.md
# NO hacer commit si el build está roto
# Si hay código parcial útil, hacer un WIP commit:
git add <archivos_nuevos_en_progreso>
git commit -m "[F1.5] WIP: observer.go parcial — mutex implementado, tests pendientes"
```

Documentar en el SESION-LOG.md exactamente dónde quedó y qué falta.

---

## FASE 3 — CIERRE DE SESIÓN

### 3.1 Completar el DoD Universal

Antes de cerrar, el agente ejecuta el DoD Universal completo y registra el output:

```bash
echo "=== DOD UNIVERSAL — CIERRE DE SESIÓN ==="
go build ./...                        && echo "✅ BUILD"  || echo "🔴 BUILD FALLA"
go vet ./...                          && echo "✅ VET"    || echo "🔴 VET FALLA"
gofmt -l . | wc -l | grep "^0$"      && echo "✅ FORMAT" || echo "🔴 FORMAT — ejecutar: gofmt -w ."
go test -race -count=10 ./...         && echo "✅ TESTS"  || echo "🔴 TESTS FALLAN"
```

Si el átomo se completó: el DoD debe pasar completo antes de marcarlo ✅.
Si el átomo quedó en progreso: el build debe pasar verde como mínimo.

### 3.2 Actualizar REGISTRO-ESTADO.md

```bash
# Abrir REGISTRO-ESTADO.md y actualizar la línea del átomo:
# 🔴 NO INICIADA → ✅ COMPLETA [hash-commit]
# o
# 🔴 NO INICIADA → 🟡 EN PROGRESO
```

### 3.3 Escribir el Informe de Cierre

Si el átomo se completó, crear `plandeaccion/plandeaccion/informes-cierre/INFORME-CIERRE-FX.Y-[NOMBRE].md` con la plantilla del Plan Maestro §2.3:

```markdown
## INFORME DE CIERRE — Átomo [FX.Y]
**ID:** FX.Y — [nombre]
**Estado:** ✅ CERRADO
**Inicio:** YYYY-MM-DD HH:MM | **Cierre:** YYYY-MM-DD HH:MM | **Duración real:** Xh

### Resumen ejecutivo
[2-3 oraciones: qué se hizo, qué problema resolvió, resultado]

### Cambios realizados
| Archivo | Acción | Líneas Δ |
|---|---|---|
| ... | CREADO/MODIFICADO/ARCHIVADO | +N / -N |

### Código preservado en `_legacy/`
[Lista de archivos archivados o "Ninguno — átomo no extrajo código legado"]

### Evidencia de validación
[Output real del DoD Universal ejecutado]

### Problemas encontrados y resolución
[Si los hubo. Si no: "Ninguno."]

### Decisiones tomadas
[Decisiones no obvias que afectarán átomos futuros — CRÍTICO documentar esto]

### Lecciones aprendidas
[Qué funcionó, qué no, qué haría distinto]

### Señal de retoma
[Si el átomo quedó incompleto: exactamente dónde continuar]

### Impacto en átomos dependientes
[Qué átomos posteriores dependen de este]
```

### 3.4 Hacer el commit semántico

```bash
# Formato SFP-04:
git add -A
git commit -m "[FX.Y] tipo: descripcion_breve

Resumen de lo que hace este commit.
Informe de Cierre: informes-cierre/INFORME-CIERRE-FX.Y-[NOMBRE].md"

git push origin main
# Verificar que el pipeline de GitHub Actions pasa en verde
```

### 3.5 Registrar cierre en SESION-LOG.md

Completar la entrada de sesión iniciada en la apertura:

```markdown
**Estado al cerrar:**
- Átomo FX.Y: ✅ COMPLETO / 🟡 EN PROGRESO / ❌ BLOQUEADO
- Commit: [hash] / WIP / ninguno
- Build al cerrar: ✅ / 🔴
- Pipeline CI: ✅ verde / ❌ rojo / ⏳ pendiente
- Próximo átomo recomendado: FX.Z — [nombre]
- Notas para la próxima sesión: [lo que el agente DEBE saber antes de empezar]
- Duración de la sesión: ~X minutos
```

---

## Apéndice A — Plantilla SESION-LOG.md

Crear este archivo en `plandeaccion/plandeaccion/SESION-LOG.md` en la primera sesión:

```markdown
# SESION-LOG — BOS-REPAIR
## Registro cronológico de sesiones del agente

**Proyecto:** BosAgent / SBOS · SKULL  
**Propósito:** Continuidad entre sesiones. El agente lee las últimas 2 entradas al abrir.  
**Regla:** Nunca eliminar entradas. Agregar siempre al final.

---

[Las sesiones se agregan aquí en orden cronológico]
```

---

## Apéndice B — Escenarios especiales

### B.1 El agente encuentra el build roto al abrir

```
1. NO ejecutar ningún átomo nuevo
2. Identificar el commit que rompió el build: git bisect o git log --oneline -10
3. Si el commit es del agente anterior: git revert <hash>
4. Si el commit es externo: documentar y esperar instrucciones del operador
5. Cerrar la sesión con nota: "BUILD ROTO — revertido/pendiente resolución"
```

### B.2 El agente encuentra una DATA RACE al abrir

```
1. Documentar el reporte completo en el SESION-LOG.md
2. Verificar si F1.5 ya está completo: [ -f internal/observer/observer.go ]
3. Si F1.5 no está completo: no ejecutar ningún átomo que requiera F1 ✅
4. Si F1.5 está completo y la race persiste: registrar como incidente en
   docs/runbooks/INCIDENTES-LOG.md y escalar al operador
```

### B.3 El agente recibe una instrucción que contradice el plan maestro

```
1. Informar al operador la contradicción específica
2. Citar el documento del plan que establece la restricción (ADR, SFP, política)
3. Proponer alternativas dentro del plan
4. NO ejecutar la instrucción contradictoria sin confirmación explícita
   de que el operador quiere hacer una excepción documentada
```

### B.4 El agente no sabe qué átomo sigue

```
1. Leer REGISTRO-ESTADO.md — buscar primer átomo con:
   - Estado 🟡 EN PROGRESO → retomar ese
   - Estado 🔴 NO INICIADA Y fase previa ✅ → ejecutar ese
2. Si hay ambigüedad, consultar al operador con opciones concretas:
   "Los próximos átomos disponibles son F0.2 (doc.go ×11) y F0.5 (pipeline CI/CD).
    F0.2 es más simple. F0.5 desbloquea la detección automática de races.
    ¿Cuál ejecuto?"
```

### B.5 Una sesión se interrumpe abruptamente (sin cierre formal)

```
La siguiente sesión detectará:
- git status mostrará archivos modificados sin commit
- SESION-LOG.md tendrá una apertura sin cierre
- REGISTRO-ESTADO.md puede estar desactualizado

Protocolo de recuperación:
1. go build ./... — si falla: revertir cambios huérfanos
2. git diff HEAD — revisar todos los cambios sin commit
3. Decidir: ¿son cambios útiles? → commit WIP o descartar
4. Actualizar SESION-LOG.md marcando la sesión anterior como "INTERRUMPIDA"
5. Actualizar REGISTRO-ESTADO.md al estado real
6. Continuar como una apertura normal
```

---

## Apéndice C — Checklist de apertura rápida

Para copiar y ejecutar al inicio de cada sesión:

```bash
#!/bin/bash
# APERTURA-SESION.sh — ejecutar al inicio de cada sesión BOS-REPAIR

echo "=========================================="
echo "APERTURA DE SESIÓN — $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="

cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/ || exit 1

echo ""
echo "1. ÚLTIMAS NOVEDADES:"
tail -40 plandeaccion/plandeaccion/SESION-LOG.md 2>/dev/null || echo "Primera sesión — SESION-LOG.md no existe"

echo ""
echo "2. ÁTOMOS EN PROGRESO:"
grep "🟡" plandeaccion/plandeaccion/REGISTRO-ESTADO.md || echo "Ninguno en progreso"

echo ""
echo "3. BUILD:"
go build ./... && echo "✅ BUILD LIMPIO" || echo "🔴 BUILD ROTO"

echo ""
echo "4. RACE DETECTOR (rápido — 3 runs):"
go test -race -count=3 ./... 2>&1 | grep -E "DATA RACE|^ok|^FAIL" | tail -10

echo ""
echo "5. ESTADO DE FASES:"
echo -n "F0: "; [ -f internal/audit/doc.go ] && echo "✅" || echo "❌"
echo -n "F1: "; grep -q "func auditLog" cmd/bos/main.go 2>/dev/null && echo "❌" || echo "✅"
echo -n "F2: "; grep -rq "gorilla/websocket" cmd/ 2>/dev/null && echo "❌" || echo "✅"
echo -n "F3: "; [ "$(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999)" -gt 500 ] && echo "❌" || echo "✅"
echo -n "F4: "; [ -f internal/security/rbac_provider.go ] && echo "❌" || echo "✅"
echo -n "F5: "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F9: "; [ -d internal/scaler ] && echo "✅" || echo "❌"
echo -n "F10:"; [ -f internal/biaos/gateway.go ] && echo "✅" || echo "❌"

echo ""
echo "6. ÚLTIMO COMMIT:"
git log --oneline -3

echo ""
echo "7. CAMBIOS SIN COMMIT:"
git status --short || echo "Ninguno"

echo ""
echo "=========================================="
echo "APERTURA COMPLETA — listo para ejecutar"
echo "=========================================="
```

---

## Apéndice D — Checklist de cierre rápido

```bash
#!/bin/bash
# CIERRE-SESION.sh — ejecutar al final de cada sesión BOS-REPAIR
# Uso: ./CIERRE-SESION.sh F1.5 "completo"  (o "progreso" o "bloqueado")

ATOMO=${1:-"UNKNOWN"}
ESTADO=${2:-"progreso"}

echo "=========================================="
echo "CIERRE DE SESIÓN — $(date '+%Y-%m-%d %H:%M')"
echo "Átomo: $ATOMO | Estado: $ESTADO"
echo "=========================================="

echo ""
echo "DOD UNIVERSAL:"
go build ./... && echo "✅ BUILD"  || echo "🔴 BUILD FALLA"
go vet ./...   && echo "✅ VET"    || echo "🔴 VET FALLA"
gofmt -l . | wc -l | grep "^0$" && echo "✅ FORMAT" || echo "⚠️  FORMAT — ejecutar: gofmt -w ."
go test -race -count=10 ./... 2>&1 | tail -5

echo ""
echo "CAMBIOS PENDIENTES DE COMMIT:"
git status --short

echo ""
echo "==========================================="
echo "RECORDATORIOS:"
echo "  [ ] Actualizar REGISTRO-ESTADO.md"
echo "  [ ] Escribir INFORME-CIERRE-$ATOMO.md (si completo)"
echo "  [ ] Hacer commit semántico [FX.Y] tipo: descripcion"
echo "  [ ] Registrar cierre en SESION-LOG.md"
echo "  [ ] Verificar pipeline en GitHub Actions"
echo "==========================================="
```

---

*PROTOCOLO-SESION-AGENTE.md v1.0 · BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Diseñado para Claude Code ejecutando el BOS-REPAIR-PLAN-MAESTRO-v3.md*  
*Complementa — no reemplaza — el MAPA-NAVEGACION.md y el REGISTRO-ESTADO.md*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
