# PROTOCOLO DE SESIÓN — Agente bKernel
## Cómo el agente abre, ejecuta y cierra cada sesión de trabajo

**Proyecto:** BkernelAgent / SBOS · SKULL  
**Versión:** 1.0 · Junio 2026  
**Aplica a:** Claude Code ejecutando átomos del BKERNEL-PLAN-MAESTRO-v1  
**Principio central:** Ninguna sesión empieza sin saber dónde estamos. Ninguna sesión termina sin dejar el estado escrito.

---

## Por qué existe este protocolo

Claude Code no tiene memoria entre sesiones. Una sesión puede interrumpirse a la mitad
de un átomo — por un error de compilación, por un timeout, por una decisión del operador.
Sin un protocolo explícito, la siguiente sesión empieza a ciegas y puede:

- Rehacer trabajo ya hecho
- Asumir que el build está limpio cuando no lo está
- Ejecutar un átomo sin verificar que el anterior está ✅
- Tomar decisiones que contradicen las del átomo anterior

El protocolo convierte al agente en un profesional de guardia: llega, lee el libro de
novedades, verifica el estado del sistema, trabaja, entrega el turno documentado.

---

## Estructura de una sesión

```
APERTURA (5 min, obligatoria)
    ↓
EJECUCIÓN (variable — uno o más átomos)
    ↓
CIERRE (5 min, obligatoria)
    ↓
LOG-DE-SESIONES.md actualizado
```

La apertura y el cierre son tan importantes como la ejecución. Un átomo ejecutado
sin cierre es un átomo en riesgo.

---

## FASE 1 — APERTURA DE SESIÓN

### 1.1 Leer el libro de novedades

Lo primero que hace el agente al iniciar cualquier sesión:

```bash
# Ruta del plan de acción
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bkernel/plandeaccion/bkernel/

# Leer el LOG-DE-SESIONES.md (últimas 2 sesiones)
tail -80 LOG-DE-SESIONES.md
```

Si `LOG-DE-SESIONES.md` no existe todavía, es la primera sesión. Crearlo con la
plantilla del §Apéndice A.

**Lo que el agente busca en el log:**
- ¿Hubo un átomo interrumpido? → va directo a ese átomo
- ¿Hubo una decisión técnica no obvia? → leerla antes de tocar código
- ¿Hubo un problema que quedó sin resolver? → no avanzar hasta resolverlo

### 1.2 Verificar el estado oficial del plan

```bash
# Estado de todos los átomos
grep -E "🟡|⚠️" REGISTRO-ESTADO.md | head -20
# Si hay algún 🟡 EN PROGRESO → ese es el átomo a retomar primero

# Resumen rápido de progreso
grep "TOTAL" REGISTRO-ESTADO.md
```

### 1.3 Ejecutar la señal de retoma global

**Este paso es obligatorio antes de tocar cualquier archivo de código.**

```bash
echo "=== SEÑAL DE RETOMA GLOBAL bKernel — $(date '+%Y-%m-%d %H:%M') ==="

echo "--- Rust toolchain ---"
rustc --version && cargo --version || echo "🔴 Rust no instalado — G0.E2.T1 bloqueado"

echo "--- Build ---"
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent
cargo build 2>&1 | tail -5 || echo "🔴 BUILD ROTO — no continuar hasta resolver"

echo "--- Tests ---"
cargo test 2>&1 | grep -E "test result|FAILED" | tail -10

echo "--- Clippy ---"
cargo clippy -- -D warnings 2>&1 | tail -5 || echo "⚠️ Clippy warnings"

echo "--- Último commit ---"
git log --oneline -3

echo "--- Estado de gates ---"
echo -n "G0 (esqueleto):   "; grep "G0 — Esqueleto" -A1 REGISTRO-ESTADO.md | tail -1
echo -n "G1 (cdc):         "; grep "G1 — CDC" -A1 REGISTRO-ESTADO.md | tail -1
echo -n "G2 (pipeline):    "; grep "G2 — Pipeline" -A1 REGISTRO-ESTADO.md | tail -1
echo -n "G3 (contexto):    "; grep "G3 — Contexto" -A1 REGISTRO-ESTADO.md | tail -1
```

### 1.4 Determinar el siguiente átomo

```bash
# El siguiente átomo es el primer 🔴 del gate activo
# Gate activo = primer gate con átomos pendientes
grep -E "^\\| G[0-9]" REGISTRO-ESTADO.md | grep "🔴" | head -1
```

---

## FASE 2 — EJECUCIÓN DE ÁTOMOS

### 2.1 Antes de cada átomo

1. Leer la sección del átomo en `BKERNEL-PLAN-MAESTRO-v1.md`
2. Leer el documento SSOT asociado (columna D en REGISTRO-ESTADO)
3. Si existe `instrucciones-agente/EJECUCION-{ID}-INSTRUCCIONES-AGENTE.md`, leerlo
4. Verificar que las dependencias están ✅

### 2.2 Durante la ejecución

1. Implementar el entregable descrito en el plan
2. Verificar el criterio MEDIBLE
3. Si el criterio no se cumple → el átomo NO está completo
4. Commits pequeños y frecuentes con mensajes descriptivos

### 2.3 Reglas de ejecución

- **No mezclar átomos:** un commit = un átomo. Si un cambio afecta a varios átomos, separar en commits distintos.
- **No avanzar sin verificar:** el criterio de aceptación es binario — se cumple o no se cumple.
- **Bloqueo inmediato:** si un átomo no puede completarse por una razón externa, marcarlo ⚠️ BLOQUEADA y reportar en LOG-DE-SESIONES.md.
- **ADR requerido:** si un átomo requiere una decisión de arquitectura no cubierta por los documentos canónicos, crear ADR en `adrs/` antes de continuar.

---

## FASE 3 — CIERRE DE SESIÓN

### 3.1 Actualizar REGISTRO-ESTADO.md

Para cada átomo completado en la sesión:
```markdown
| G0.E2.T1 | Workspace Cargo + estructura de módulos | ✅ | abc1234 | Migrado a edition 2024 + LTO. cargo build + clippy limpios | ☑ | 0,2,3 | bK-050 |
```

Campos obligatorios: ID, Estado (✅), Commit SHA, Notas, Rev (☑).

### 3.2 Registrar en LOG-DE-SESIONES.md

```markdown
## Sesión S-XXX — YYYY-MM-DD

**Átomos ejecutados:** G0.E2.T1, G0.E2.T2  
**Resultado:** 2 completados, 0 bloqueados  
**Commits:** abc1234, def5678  
**Build:** ✅ limpio  
**Tests:** ✅ 42 passed  
**Notas:** Instalado Rust 1.85.0. MUSL static linking funcional.  
**Próximo átomo:** G0.E2.T3
```

### 3.3 Verificación final

Antes de terminar la sesión:
- [ ] REGISTRO-ESTADO.md actualizado con todos los átomos ejecutados
- [ ] LOG-DE-SESIONES.md actualizado con entrada de la sesión
- [ ] `cargo build` limpio (si se modificó código)
- [ ] `cargo test` verde (si se modificó código)
- [ ] `cargo clippy -- -D warnings` limpio (si se modificó código)
- [ ] Todos los commits tienen mensajes descriptivos

---

## APÉNDICE A — Plantilla de LOG-DE-SESIONES.md (primera sesión)

```markdown
# LOG DE SESIONES — Desarrollo bKernel
## Bitácora cronológica de sesiones de desarrollo

**Proyecto:** BkernelAgent / SBOS · SKULL
**Inicio:** YYYY-MM-DD

---

## Sesión S-001 — YYYY-MM-DD

**Átomos ejecutados:** —
**Resultado:** Sesión inicial — creada estructura documental
**Build:** N/A (no hay código todavía)
**Notas:** Creados MAPA-NAVEGACION.md, REGISTRO-ESTADO.md, BKERNEL-PLAN-MAESTRO-v1.md, PROTOCOLO-SESION-AGENTE.md, este LOG.
**Próximo átomo:** G0.E2.T1 — Workspace Cargo + estructura de módulos
```

---
*PROTOCOLO-SESION-AGENTE v1.0 · 2026-06-19 · SKULL*
