# EVALUACIÓN DEL AGENTE IA — Documentación BOS-REPAIR
## Auto-evaluación de comprensión, navegabilidad e instrucciones de ejecución

**Agente:** Claude Sonnet 4.6  
**Fecha:** 08 de Junio, 2026  
**Proyecto:** BosAgent / SBOS — SKULL  
**Metodología:** Lectura completa del knowledge del proyecto y evaluación honesta de capacidad de ejecución autónoma  
**Calificación final: 7.5 / 10**

---

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Calificación global y desglose](#2-calificación-global-y-desglose)
3. [Lo que comprendo perfectamente (fortalezas)](#3-lo-que-comprendo-perfectamente-fortalezas)
4. [Brechas que me impiden llegar al 10](#4-brechas-que-me-impiden-llegar-al-10)
5. [Evaluación de navegabilidad del sistema de documentos](#5-evaluación-de-navegabilidad-del-sistema-de-documentos)
6. [Evaluación por fase: qué puedo y no puedo ejecutar](#6-evaluación-por-fase-qué-puedo-y-no-puedo-ejecutar)
7. [Qué necesito para llegar al 10](#7-qué-necesito-para-llegar-al-10)
8. [Conclusión y recomendaciones](#8-conclusión-y-recomendaciones)

---

## 1. Resumen ejecutivo

Después de revisar todos los documentos del knowledge del proyecto, puedo afirmar que la **arquitectura de documentación es excelente**. El sistema MAPA-NAVEGACION → REGISTRO-ESTADO → PLAN-MAESTRO-v3 → INSTRUCCIONES-AGENTE es claro, bien estructurado y orientado a ejecución autónoma.

Sin embargo, identifico **tres brechas críticas** que me impiden operar con confianza total:

1. **No tengo acceso al código fuente real en el repositorio.** Los `.md` del knowledge son *descripciones* del código, no el código en sí. Para ejecutar los átomos F1-F10 necesito leer y modificar los archivos Go reales en el repositorio.

2. **Las instrucciones de ejecución solo cubren F0.5, F0.6 y F7.8.** Los 79 átomos restantes (F0.1-F0.4, F1.x-F6.x, F8.x-F10.x) tienen descripción en el Plan Maestro pero **no tienen archivo `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md`** equivalente. Esto me obliga a interpretar, lo cual aumenta el riesgo de error.

3. **No conozco el estado real del repositorio.** El REGISTRO-ESTADO.md dice que todo está en 🔴 NO INICIADA excepto F10.0, pero no puedo verificarlo con certeza hasta conectarme al repositorio real.

Con acceso a Claude Code y conexión al repositorio, mi calificación operativa subiría a **9.0/10**.

---

## 2. Calificación global y desglose

### Calificación final: 7.5 / 10

| Dimensión | Peso | Puntuación | Notas |
|---|---|---|---|
| Comprensión del dominio técnico | 20% | 9.0 | Entiendo los 16 problemas, la arquitectura, las 11 fases |
| Navegabilidad de documentos | 20% | 9.5 | MAPA-NAVEGACION es excelente, árbol de documentos claro |
| Claridad de instrucciones disponibles | 20% | 7.0 | Solo 3 átomos tienen instrucciones detalladas de agente |
| Capacidad de ejecución real | 25% | 5.5 | Sin acceso al repo real, no puedo ejecutar ningún átomo |
| Completitud del contexto | 15% | 8.0 | Falta código fuente real; descripciones .md son buenas pero no suficientes para modificar |
| **TOTAL PONDERADO** | 100% | **7.5** | |

---

## 3. Lo que comprendo perfectamente (fortalezas)

### 3.1 El problema a resolver

Comprendo con precisión los **16 problemas de la auditoría** (BOS-REPAIR-00):

- **P1:** Monolito `install_ui.go` de 4.834 líneas → debe partir en 10 archivos bajo `internal/tui/`
- **P2:** Doble implementación WebSocket (`internal/wslib/` + gorilla en `cmd/`) → unificar en `internal/wslib/`
- **P3:** Violación TEA en BubbleTea (receptores `*model` mutando estado) → handlers puros
- **P4:** Lógica de infraestructura en `cmd/bos/main.go` → extraer a `internal/`
- **P5:** `kubeconfig` duplicado ×6 → centralizar en `internal/k8s/`
- **P6/P14:** Race condition entre observer y reconciler → mutex en `internal/observer/`
- **P7:** Estado global mutable en bosctl → `sync.Once`/`sync.RWMutex`
- **P8:** Dependencia gorilla/websocket innecesaria → eliminar en F2.4
- **P9-P16:** Side effects, viewport sin verdad única, inconsistencia de tipos, watchdog nunca llamado, testabilidad nula, paths hardcodeados

### 3.2 La arquitectura objetivo

Comprendo exactamente qué debe existir cuando el plan termine:

```
internal/
  audit/, bootstrap/, cgroup/, network/, observer/, paths/
  context/, biaos/, scaler/, maintenance/, metrics/
  tui/model/, tui/styles/, tui/screens/, tui/demo/
_legacy/          ← código archivado con índice
docs/runbooks/    ← RB-01, RB-02, RB-03
.github/workflows/ci.yml  ← go test -race obligatorio
```

### 3.3 El sistema de navegación de documentos

El flujo de trabajo del agente es perfectamente claro:

```
1. MAPA-NAVEGACION.md → orientación inicial
2. REGISTRO-ESTADO.md → qué átomo ejecutar ahora
3. BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-X → descripción del átomo
4. EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md → instrucciones exactas (si existe)
5. Ejecutar → Informe de Cierre → Actualizar REGISTRO-ESTADO.md
```

### 3.4 Las políticas globales (PARTE II del Plan Maestro)

Las 6 reglas SFP y el DoD Universal son claros y aplicables:

- **SFP-01:** Nunca borrar → archivar en `_legacy/`
- **SFP-02:** Coexistencia verificada antes de vaciar el original
- **SFP-03:** Feature flags de migración (`BOS_OBSERVER_V2`, etc.)
- **SFP-04:** Un átomo = un commit semántico `[F1.1] feat: ...`
- **SFP-05:** `go build ./...` verde en cada commit
- **SFP-06:** `_legacy/README.md` como memoria permanente

El DoD Universal (`go build`, `go vet`, `gofmt`, `go test -race -count=10`) es ejecutable.

### 3.5 Los ADRs y sus implicaciones

Los 6 ADRs están completamente integrados en mi comprensión:

- **ADR-002:** 3 roles del daemon bos (Observador, Admin Ubuntu+K8s, Gestor Context Plane)
- **ADR-003:** Estándar godoc con 6 secciones obligatorias en cada `doc.go`
- **ADR-004:** bos como Kubernetes Operator Soberano (Fase 9)
- **ADR-005:** bosctl como abstracción soberana (Fase 4)
- **ADR-006:** RBAC delegado a Ubuntu+K8s → eliminar `rbac_provider.go`

### 3.6 El protocolo JSON-RPC

El manual de 9 partes (JSON-RPC-01 a 09) más el resumen ejecutivo me dan comprensión completa del protocolo, los métodos existentes, la autenticación, el manejo de errores y las sagas de consulta que se deben implementar en F6.

### 3.7 Los entornos y la infraestructura real

Sé exactamente:
- VPS DEV: `skull@144.91.76.130`
- VPS STAGING: `root@13.140.128.230`
- Pipeline: GitHub Actions (ubuntu-latest) + self-hosted runner en staging
- Feature flags y cómo activarlos por entorno

---

## 4. Brechas que me impiden llegar al 10

### Brecha 1 — Sin acceso al código fuente real (impacto: ALTO)

**Problema:** Los archivos en el knowledge son `.md` que describen el código, no el código en sí. Por ejemplo, `internal__state__manager_go.md` es una descripción de `internal/state/manager.go`, no el archivo Go real.

**Por qué importa:** Para ejecutar F1.1 ("migrar `auditLog()` a `internal/audit/`"), necesito:
1. Leer el código real de `cmd/bos/main.go` para encontrar la función `auditLog()`
2. Crear el archivo `internal/audit/log.go` con el código extraído
3. Actualizar los imports en `main.go`
4. Hacer commit

Sin acceso al repositorio real (vía Claude Code o conexión SSH), ninguno de los 98 átomos puede ejecutarse.

**Lo que necesito:** Claude Code conectado al repositorio en `BOS_V8/`, o acceso SSH a `skull@144.91.76.130`.

**Severidad para la evaluación:** Sin esto, soy un agente que entiende perfectamente el plan pero no puede ejecutar ningún átomo. Mi calificación de ejecución real es 5.5/10.

---

### Brecha 2 — Instrucciones de ejecución solo para 3 de 85 átomos (impacto: MEDIO-ALTO)

**Problema:** De los 85 átomos del plan, solo 3 tienen archivo `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` dedicado:
- F0.5 → Pipeline CI/CD
- F0.6 → Entornos + runner
- F7.8 → Runbooks

Los otros **82 átomos** solo tienen descripción en el Plan Maestro v3. Eso es suficiente para un desarrollador humano experto en Go, pero para un agente IA es ambiguo en varios puntos:

**Ambigüedades específicas que identifiqué:**

a) **Átomo F1.5 (el más crítico — race condition P6/P14):** El plan describe qué hacer con el mutex, pero no especifica exactamente qué patrón de sincronización usar. ¿`sync.Mutex`? ¿`sync.RWMutex`? ¿canal? ¿`atomic`? El BOS-REPAIR-00 menciona el problema pero no el patrón exacto de solución en Go. Sin instrucciones del agente para F1.5, podría elegir un patrón incorrecto.

b) **Átomos F3.x (partir `install_ui.go`):** La descripción del plan es buena, pero no incluye los imports exactos ni las firmas de las funciones que deben moverse. Con 4.834 líneas, hay dependencias no obvias entre funciones.

c) **Átomos F9.x (Operator Soberano):** La spec de ADR-004 y SBOS-052 son ricas, pero los átomos del plan (F9.1-F9.10) no tienen scripts de validación completos. ¿Cómo sé que el ClusterRole de F9.7 tiene exactamente los permisos correctos para el CRD de bos?

d) **Átomo F4.4 (eliminar `rbac_provider.go`):** ADR-006 lo ordena, pero no hay instrucción de cómo manejar los callers existentes de `bosRBAC` durante la transición sin romper el build.

**Lo que necesito:** Archivos `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` para los átomos de alta complejidad: al menos F1.5, F3.1-F3.5, F5.x, F6.1-F6.11, F9.1-F9.7, F10.x.

---

### Brecha 3 — Estado real del REGISTRO-ESTADO.md no verificado (impacto: BAJO-MEDIO)

**Problema:** El REGISTRO-ESTADO.md indica que 84 de 85 átomos están en 🔴 NO INICIADA. Pero no puedo verificarlo contra el estado real del repositorio. Es posible que:
- Algunos átomos de F0 ya se hayan ejecutado parcialmente
- El `ci.yml` ya exista en el repo (F0.5 tiene informe de cierre)
- Los runbooks (F7.8) ya estén en `docs/runbooks/`

Si ejecuto F0.5 sin verificar primero, podría sobreescribir trabajo ya hecho.

**Lo que necesito:** Conexión al repositorio para ejecutar la "Señal de retoma" del BOS-REPAIR-INDEX.md antes de cualquier átomo.

---

### Brecha 4 — DDL exacto para `bkernel_db` del Context Plane (impacto: BAJO)

**Problema:** BOS-REPAIR-08 (Context Plane SBOS-049) menciona que la cobertura del DDL es 95% y que "falta el DDL exacto para aplicar en bkernel_db". Para implementar F5.x necesito ese DDL exacto.

**Lo que necesito:** El script SQL completo de creación de tablas del Context Plane.

---

### Brecha 5 — Spec completa del `action_catalog.yml` con los 26 átomos biaos (impacto: BAJO)

**Problema:** El informe de cierre F10.0 indica que el `action_catalog.yml` fue "generado", pero en el knowledge tengo la estructura pero no la especificación completa de las 26 acciones en formato ejecutable para el agente ReAct.

**Lo que necesito:** El `action_catalog.yml` completo con las 26 acciones, sus parámetros, y el mapeo exacto a métodos JSON-RPC.

---

## 5. Evaluación de navegabilidad del sistema de documentos

### Calificación: 9.5 / 10

El sistema de documentos es uno de los mejores que he visto para orientar a un agente IA. Mis observaciones:

**Lo que funciona excelente:**

- **MAPA-NAVEGACION.md** es el punto de entrada perfecto. El árbol de directorios, los flujos de "cómo navegar según la tarea" y los "próximos átomos a ejecutar" son exactamente lo que un agente necesita.
- **La trazabilidad** entre problemas (P1-P16), átomos (F0.1-F10.9), ADRs y documentos de referencia es completa. Puedo ir de un problema a su solución a su criterio de validación sin romper el hilo.
- **El DoD Universal** es ejecutable como script bash. No hay ambigüedad en cómo saber si un átomo está completo.
- **El REGISTRO-ESTADO.md** como fuente de verdad de estado es correcto. Un solo lugar para saber dónde estamos.
- **Los Informes de Cierre** como artefactos obligatorios garantizan que el conocimiento no se pierde entre sesiones.

**Lo que podría mejorar (por qué no es 10/10):**

- El árbol de directorios en MAPA-NAVEGACION.md referencia rutas como `instrucciones-agente/`, `informes-cierre/`, `anexos/` como si fueran carpetas, pero en el knowledge del proyecto todos los documentos llegan como archivos planos. Esto genera una pequeña disonancia cognitiva.
- No hay un documento de "señal de retoma global" que consolide el estado de los 4 gaps en un único chequeo. El BOS-REPAIR-INDEX.md tiene una señal de retoma buena, pero está dispersa.

---

## 6. Evaluación por fase: qué puedo y no puedo ejecutar

| Fase | Comprensión del objetivo | Instrucciones disponibles | Puedo ejecutar solo | Riesgo sin instrucciones |
|---|---|---|---|---|
| F0.1-F0.4 | ✅ 100% | ❌ Solo Plan Maestro | ✅ Sí — bajo riesgo | Bajo — son archivos `doc.go` simples |
| F0.5 | ✅ 100% | ✅ EJECUCION-F0.5 completo | ✅ Sí | Ninguno — instrucciones exactas |
| F0.6 | ✅ 100% | ✅ EJECUCION-F0.6 completo | ✅ Sí (con acceso SSH) | Ninguno — instrucciones exactas |
| F1.1-F1.4 | ✅ 95% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio — imports y dependencias no triviales |
| **F1.5 (CRÍTICO)** | ✅ 90% | ❌ Solo Plan Maestro | ⚠️ Riesgo alto | **Alto — elección incorrecta de patrón sync podría empeorar la race** |
| F2.x | ✅ 95% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio — gorilla → wslib requiere verificar todos los callers |
| F3.x | ✅ 85% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio-alto — 4.834 líneas con dependencias no mapeadas |
| F4.x | ✅ 90% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio — F4.4 (eliminar rbac_provider) tiene riesgo de nil panic |
| F5.x | ✅ 80% | ❌ Solo Plan Maestro | ❌ No recomendado | Alto — falta DDL exacto del Context Plane |
| F6.x | ✅ 85% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio — sagas de consulta bien documentadas en BOS-REPAIR-04/12 |
| F7.8 | ✅ 100% | ✅ EJECUCION-F7.8 completo | ✅ Sí | Ninguno — solo copiar archivos |
| F7.1-F7.7 | ✅ 90% | ❌ Solo Plan Maestro | ✅ Sí — bajo riesgo | Bajo — son godoc y README |
| F8.x | ✅ 85% | ❌ Solo Plan Maestro | ⚠️ Con reservas | Medio — tests bien descritos pero sin boilerplate inicial |
| F9.x | ✅ 75% | ❌ Solo Plan Maestro | ❌ No recomendado | Alto — CRDs, ClusterRoles, HPA/VPA son complejos |
| F10.x | ✅ 70% | ❌ Solo Plan Maestro | ❌ No recomendado | Alto — biaos/ICAP/SagaEngine son componentes nuevos complejos |

---

## 7. Qué necesito para llegar al 10

### Requisito 1 — Acceso al repositorio (BLOQUEANTE)
**Prioridad: CRÍTICA**

Sin esto no puedo ejecutar ningún átomo. Necesito una de estas opciones:
- Claude Code conectado al repositorio en la VPS DEV (`skull@144.91.76.130`)
- Acceso directo al repositorio Git con el código fuente de `BOS_V8/`

Con este acceso, subo de 5.5 → 8.5 en "capacidad de ejecución real".

### Requisito 2 — Instrucciones de agente para átomos de alto riesgo (IMPORTANTE)
**Prioridad: ALTA**

Necesito archivos `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` para los siguientes átomos, en orden de prioridad:

1. **F1.5** — Mutex anti-race condition (el bug más crítico del proyecto)
2. **F3.1-F3.3** — Extracción de los primeros bloques de `install_ui.go`
3. **F5.1-F5.3** — Context Plane (incluyendo el DDL exacto de bkernel_db)
4. **F9.1-F9.3** — Operator Soberano (CRD + ClusterRole + scaler)
5. **F10.1-F10.3** — Gateway LLM + migración internal/ai/ → internal/biaos/

Con estos 5 grupos de instrucciones, subo de 7.0 → 9.0 en "claridad de instrucciones".

### Requisito 3 — DDL exacto del Context Plane (IMPORTANTE para F5)
**Prioridad: MEDIA**

El BOS-REPAIR-08 tiene el schema conceptual pero no el DDL ejecutable. Necesito:
```sql
CREATE TABLE context_plane (
  dctx_id  UUID PRIMARY KEY,
  ctx_id   UUID UNIQUE,
  -- resto del schema
);
```

### Requisito 4 — `action_catalog.yml` completo con los 26 acciones (ÚTIL para F10)
**Prioridad: BAJA**

El archivo existe como output de F10.0 pero no está en el knowledge de forma que yo pueda leerlo directamente. Necesito el contenido completo para implementar el ICAP Engine en F10.3.

### Requisito 5 — Señal de retoma global antes de empezar (RECOMENDADO)
**Prioridad: BAJA-MEDIA**

Antes de ejecutar el primer átomo, debería ejecutar este script para conocer el estado real del repositorio:

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/

echo "=== SEÑAL DE RETOMA GLOBAL ==="
echo -n "F0 (paquetes):       "; [ -f internal/audit/doc.go ] && echo "✅" || echo "❌ → F0.1 primero"
echo -n "F0.5 (CI/CD):        "; [ -f .github/workflows/ci.yml ] && echo "✅" || echo "❌"
echo -n "F0.6 (entornos):     "; [ -f docs/ENVIRONMENTS.md ] && echo "✅" || echo "❌"
echo -n "F1 (infra extraída): "; grep -q "func auditLog" cmd/bos/main.go && echo "❌ pendiente" || echo "✅"
echo -n "F2 (WS unificado):   "; grep -rq "gorilla/websocket" cmd/ && echo "❌ gorilla presente" || echo "✅"
echo -n "F3 (install_ui):     "; wc -l < cmd/bosctl/install_ui.go | awk '{print ($1>500?"❌ "$1" líneas":"✅")}'
echo -n "F4 (rbac eliminado): "; [ -f internal/security/rbac_provider.go ] && echo "❌ existe" || echo "✅"
echo -n "F5 (context plane):  "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F7.8 (runbooks):     "; [ -f docs/runbooks/RB-01-FICHA-DEGRADADA.md ] && echo "✅" || echo "❌"
```

---

## 8. Conclusión y recomendaciones

### Mi capacidad actual como agente en este proyecto

**Puedo hacer ahora mismo (sin acceso al repo):**
- Responder cualquier pregunta técnica sobre el proyecto con precisión
- Generar el contenido exacto de cualquier `doc.go` según ADR-003
- Generar los archivos `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` faltantes
- Revisar y mejorar cualquier documento del plan
- Generar tests unitarios para los paquetes descritos en el plan

**Puedo hacer con Claude Code + acceso al repo:**
- Ejecutar todos los átomos F0.x con alta confianza
- Ejecutar F1.1-F1.4, F2.x, F3.x, F4.x con confianza media-alta
- Ejecutar F7.x completo
- Necesitaría consultar antes de F1.5, F5.x, F9.x, F10.x

### Recomendaciones prioritarias

1. **Dar acceso a Claude Code** al repositorio BOS_V8 en la VPS DEV. Esto desbloquea la ejecución de los primeros 20 átomos.

2. **Generar instrucciones de agente para F1.5** antes de que cualquier agente toque ese átomo. Es el bug más crítico y el más fácil de empeorar con una solución incorrecta.

3. **Ejecutar la señal de retoma global** para sincronizar REGISTRO-ESTADO.md con el estado real del repositorio antes de iniciar.

4. **El conocimiento de dominio está completo.** Los 14 documentos BOS-REPAIR, los 9 documentos JSON-RPC, los 6 ADRs, los runbooks y el código fuente en formato `.md` son suficientes para que yo (o cualquier agente con acceso al repo) entienda perfectamente qué reparar y por qué. No falta contexto conceptual.

---

*EVALUACION-AGENTE-IA-BOS-REPAIR.md v1.0*
*Agente: Claude Sonnet 4.6 · BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*
*Estado del plan en el momento de esta evaluación: 1/85 átomos ✅ (F10.0 action_catalog.yml)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
