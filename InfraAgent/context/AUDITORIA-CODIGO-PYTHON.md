# Auditoría del Código Python — Fábrica ORQUESTA
**Fecha:** 2026-07-02
**Autor:** Bibliotecario SBOS (análisis + agente especializado)
**Propósito:** Diagnóstico completo del estado real del código Python de la fábrica.
Base para el plan de corrección integral.

---

## 1. Inventario de módulos auditados

### 1.1 compositor-agent (núcleo de la fábrica)

```
orquesta/
├── coordinador/
│   ├── servidor.py          — 110 líneas  — Servidor JSON-RPC :8095
│   ├── rpc_handlers.py      — 220 líneas  — 11 handlers completos
│   ├── db_coordinacion.py   — 330 líneas  — CRUD sobre trazas.*
│   ├── grafo.py             — ~200 líneas — Algoritmos de grafo (DFS, Kahn, CPM)
│   ├── dependencias.py      — N líneas    — Gestión de dependencias
│   └── negociacion.py       — N líneas    — Protocolo de negociación
├── core/
│   ├── pge.py               — Máquina de estados del Ciclo PGE
│   ├── progress_reporter.py — 314 líneas  — Reporter de progreso (conecta SKDATA)
│   ├── budget_guard.py      — 130 líneas  — Guardián de presupuesto API
│   ├── checkpoint.py        — N líneas    — Checkpoints de estado
│   ├── health.py            — N líneas    — Health check
│   ├── model_router.py      — N líneas    — Router de modelos LLM
│   ├── model_lifecycle.py   — N líneas    — Ciclo de vida de modelos
│   ├── logger.py            — N líneas    — Logger estructurado
│   └── backoff.py           — N líneas    — Retry con backoff exponencial
├── db/
│   └── biblioteca.py        — N líneas    — Pool psycopg2 → SKDATA :5402
├── tools/
│   ├── ctx_filter.py        — 245 líneas  — Filtrado y compresión de contexto
│   ├── cache_mgr.py         — 178 líneas  — Caché de artefactos
│   ├── ctx_distil.py        — 48 líneas   — Destilación de contexto
│   ├── ctx_comp.py          — 27 líneas   — Compresión de contexto
│   ├── gaps_validator.py    — 84 líneas   — Validador de GAPS
│   ├── gen_ai_doc.py        — 87 líneas   — Generador de AI-docs
│   ├── gen_manifest.py      — 131 líneas  — Generador de manifests YAML
│   ├── gen_db.py            — 25 líneas   — [STUB] Generador de DDL
│   ├── gen_doc.py           — 21 líneas   — [STUB] Generador de docs
│   ├── gen_migration.py     — 26 líneas   — [STUB] Generador de migraciones
│   ├── gen_runbooks.py      — 24 líneas   — [STUB] Generador de runbooks
│   ├── gen_tests.py         — 25 líneas   — [STUB] Generador de tests
│   └── batch_queue.py       — 41 líneas   — Cola de operaciones en batch
├── security/
│   └── agent_identity.py    — 0 líneas    — [VACÍO] Identidad de agente
├── eval/
│   ├── casos.py             — N líneas    — Casos de evaluación
│   └── harness.py           — N líneas    — Harness de evaluación
└── schemas/
    └── (schemas de validación)
```

### 1.2 bibliotecario-agent

```
bibliotecario-agent/
├── bibliotecario/
│   └── materializador.py    — N líneas   — Materializa árbol de carpetas + CLAUDE.md
└── src/
    └── bibliotecario.py     — N líneas   — Agente principal (filesystem + BD opcional)
```

### 1.3 OrquestaCoreSBOS

```
OrquestaCoreSBOS/src/
├── orquesta_core_sbos.py    — CLI principal (status/next/validate)
├── build_state.py           — Persistencia en build_state.json (NO usa SKDATA)
├── ci_gates.py              — Gates de CI
└── sbos_build_config.py     — Configuración del build SBOS
```

---

## 2. Tabla de veredictos

| Módulo | Es real | Escribe a BD | Veredicto | Categoría |
|--------|:-------:|:------------:|-----------|-----------|
| `servidor.py` (:8095) | ✅ | — | Funciona. HTTP real, 11 métodos. WebSocket en docstring pero no implementado. | REAL |
| `rpc_handlers.py` | ✅ | Via db | Funciona. 11 handlers completos, ningún stub. | REAL |
| `db_coordinacion.py` | ✅ | ✅ `trazas.*` | Funciona. SQL transaccional real. 21 filas en BD lo prueban. | REAL |
| `grafo.py` | ✅ | ❌ | Funciona. DFS, Kahn, camino crítico — correctos. No persiste. | LIBRERÍA PURA |
| `biblioteca.py` | ✅ | ✅ Pool real | Funciona. Pool psycopg2 con lazy init a `:5402/SKDATA`. | REAL |
| `progress_reporter.py` | ✅ | Con degradación | Semi-real. Si SKDATA conecta, escribe. Si no, silencio. | SEMI-REAL |
| `budget_guard.py` | ✅ | Con degradación | Semi-real. Registra invocaciones API si SKDATA conecta. | SEMI-REAL |
| `pge.py` | ✅ | ❌ | Funciona. Máquina de estados en memoria. El caller persiste. | LIBRERÍA PURA |
| `checkpoint.py` | ✅ | Con degradación | Semi-real. Guarda estado si SKDATA conecta. | SEMI-REAL |
| `ctx_filter.py` | ✅ | ❌ | Funciona. Filtrado de contexto para reducir tokens. | REAL |
| `cache_mgr.py` | ✅ | ❌ | Funciona. Caché en disco de artefactos. | REAL |
| `gen_ai_doc.py` | ✅ | ❌ | Funciona. Genera AI-docs via ciclo PGE. | REAL |
| `gen_manifest.py` | ✅ | ❌ | Funciona. Genera manifests YAML. | REAL |
| `gen_db.py` | ⚠️ | ❌ | STUB. Extrae comentarios del modelo de dominio pero no genera DDL real. Tiene `# TODO`. | STUB |
| `gen_doc.py` | ⚠️ | ❌ | STUB. Copia los primeros 4000 chars del AI-doc. No transforma. Tiene `# TODO`. | STUB |
| `gen_migration.py` | ⚠️ | ❌ | STUB. Genera template vacío con `-- ALTER statements aquí`. | STUB |
| `gen_runbooks.py` | ⚠️ | ❌ | STUB. Similar a gen_doc — copia contenido sin transformar. | STUB |
| `gen_tests.py` | ⚠️ | ❌ | STUB. Genera un `def test_smoke(): assert True`. No produce tests reales. | STUB |
| `agent_identity.py` | ❌ | ❌ | ARCHIVO VACÍO. 0 líneas de código. | VACÍO |
| `memoria.py` DocumentStore | ⚠️ | Con degradación | SEMI-STUB. Guardado es SQL real. "Búsqueda semántica" es `ILIKE %query%` — sin pgvector, sin embeddings. | SEMI-STUB |
| `memoria.py` KnowledgeGraph | ✅ | Con degradación | Funciona si SKDATA conecta. Escribe en `conocimiento.decision`. | SEMI-REAL |
| `bibliotecario.py` | ✅ | Condicional | Funciona. Filesystem siempre. BD solo si `project_id` es UUID válido. | SEMI-REAL |
| `materializador.py` | ✅ | ❌ | Funciona. Crea carpetas y `CLAUDE.md` en disco. Independiente de SKDATA. | REAL |
| `OrquestaCoreSBOS` | ✅ | ❌ | Funciona como CLI. Persiste en `build_state.json`. SKDATA es opcional con `except: pass`. | REAL (autónomo) |

---

## 3. Diagnóstico de SKDATA — por qué hay 0 filas en la mayoría de schemas

### Estado actual de la BD (verificado 2026-07-02)

| Schema | Tabla | Filas | Observación |
|--------|-------|------:|-------------|
| `trazas` | `tarea_coordinada` | **21** | El único schema activo |
| `trazas` | `dependencia_tarea` | **3** | |
| `trazas` | `bloqueo` | **0** | |
| `trazas` | `colaboracion_agentes` | **0** | |
| `conocimiento` | `*` | **0** | Nunca se usó |
| `perfiles` | `*` | **0** | Nunca se usó |
| `arboles` | `*` | **0** | Nunca se usó |
| `memoria` | (no existe) | — | Schema no creado |
| `fabrica` | (no existe) | — | Schema no creado |

### Las 21 tareas reales en `trazas.tarea_coordinada`

| tipo | estado | descripción |
|------|--------|-------------|
| codigo | en_ejecucion | T-DEV-001: IAM Installer v3.1 |
| codigo | declarada | T-DEV-002: kubeadm + Calico 100% |
| codigo | declarada | T-DEV-003: BSTYLE design system |
| codigo | declarada | T-DEV-004: BINTELLIGENCE bCompass + bSearch |
| codigo | declarada | T-DEV-005: BNEXUS WebSocket mTLS |
| codigo | declarada | T-DEV-006: INFRA 16 servidores lógicos |
| codigo | declarada | bCompass: schema bcompass_db (x2 duplicado) |
| codigo | declarada | bCompass: implementar db_query real (x2 duplicado) |
| codigo | declarada | bCompass: implementar result_emitter real (x2 duplicado) |
| codigo | declarada | bCompass: primera ruta analyst (x2 duplicado) |
| configuracion | completada | agregar bcommand al grid tmux |
| configuracion | completada | activar sbos-coordinador |
| documentacion | completada | actualizar CLAUDE.md de agentes |
| coordinacion | en_ejecucion | bootstrap-coordinacion-sbos |
| verificacion | en_ejecucion | verificar-comunicacion-bidireccional |
| verificacion | en_ejecucion | prueba-comunicacion bcommand |
| verificacion | declarada | prueba-busqueda bsearch |

**Anomalía detectada:** 6 tareas están duplicadas (misma descripción, dos UUIDs distintos).

### Causa raíz: degradación silenciosa universal

El patrón que causó las "0 filas" existe en todos los módulos que usan SKDATA fuera del coordinador:

```python
# Patrón universal en memoria.py, bibliotecario.py, progress_reporter.py, etc.
def guardar_algo(self, datos):
    if not self.bd.verificar_conexion():
        print("[SKDATA] Sin conexión — continuando sin persistir")
        return "skdata-no-disponible"   # ← retorna sin error, sin INSERT
    # ... SQL que nunca se ejecuta si la BD no conecta
```

Cuando SKDATA era inaccesible o el schema no existía:
1. El código imprimía un mensaje amigable y continuaba
2. El agente veía ese mensaje y asumía que había persistido
3. No era una mentira intencional — era silencio estructural

**El servidor :8095 no tuvo este problema** porque fue el único proceso que siempre estuvo activo cuando los agentes llamaron a `declare_task`. Los otros módulos dependían de que el agente llamante iniciara la conexión en su propio proceso.

---

## 4. Bugs confirmados

### BUG-001 — `get_graph` falla con metadata NULL (BLOQUEANTE)

**Archivo:** `rpc_handlers.py` — función `get_graph`
**Severidad:** Alta — método completamente inutilizable con la BD actual

**Causa:**
```python
# ROTO — si metadata está en el dict pero es None, .get() retorna None (no {})
duracion_estimada=t.get('metadata', {}).get('duracion_minutos', 10),
# ↑ AttributeError: 'NoneType' object has no attribute 'get'
```

Las 21 tareas en BD tienen `metadata = NULL`. La función `_fila_a_tarea` en `db_coordinacion.py` retorna el campo `metadata` como `None` cuando la columna es NULL en BD. El código en `get_graph` asume que siempre es un dict.

**Fix de 1 línea:**
```python
duracion_estimada=(t.get('metadata') or {}).get('duracion_minutos', 10),
```

---

### BUG-002 — WebSocket `/rpc/ws` documentado pero no implementado

**Archivo:** `servidor.py` — docstring y header del módulo
**Severidad:** Media — ningún agente puede conectar via WebSocket

**Causa:** El docstring dice *"WebSocket /rpc/ws"* pero el `CoordinadorHandler` solo implementa `do_POST` y `do_GET`. No hay ninguna librería WebSocket (`websockets`, `aiohttp`, etc.) en el código.

**Impacto:** Los agentes que intenten conectar via WebSocket recibirán 404. Solo HTTP POST `/rpc` funciona.

---

### BUG-003 — Tareas duplicadas en `trazas.tarea_coordinada`

**Tabla:** `trazas.tarea_coordinada`
**Severidad:** Media — el grafo contiene nodos duplicados, `get_graph` retornaría información incorrecta

**Causa:** `declare_task` no verifica si ya existe una tarea con la misma descripción para el mismo agente y proyecto. Llama directamente a `crear_tarea` con un `uuid4()` nuevo cada vez.

**Evidencia:** 6 tareas con descripciones idénticas, UUIDs distintos.

---

### BUG-004 — `agent_identity.py` vacío

**Archivo:** `security/agent_identity.py`
**Severidad:** Baja (actualmente) — Alta en cuanto se necesite identidad de agente

**Causa:** Archivo creado pero nunca implementado. 0 líneas de código.

---

### BUG-005 — OrquestaCoreSBOS desconectado de SKDATA

**Archivo:** `OrquestaCoreSBOS/src/build_state.py`
**Severidad:** Media — el seguimiento del build pipeline no está en la BD central

**Causa:** El pipeline de construcción de BOS persiste su estado en `build_state.json` (archivo local en disco). El `_sync_from_skdata` tiene `except Exception: pass`. El progreso real del IAM Installer nunca aparece en `trazas.tarea_coordinada`.

---

## 5. Módulos STUB — generadores que no generan

Estos 5 módulos crean archivos en disco pero su contenido es decorativo:

| Módulo | Qué produce realmente | Qué debería producir |
|--------|----------------------|----------------------|
| `gen_db.py` | Comentarios extraídos por `if "entidad" in línea` | DDL SQL real desde el modelo de dominio |
| `gen_doc.py` | Los primeros 4000 chars del AI-doc copiados | Documentación técnica transformada |
| `gen_migration.py` | Template `BEGIN; -- ALTER aquí; COMMIT;` | ALTER SQL calculado comparando DDL anterior vs nuevo |
| `gen_runbooks.py` | Template con información del servicio copiada | Runbook operativo con pasos concretos |
| `gen_tests.py` | `def test_smoke(): assert True` | Suite de tests derivada de reglas de negocio |

Todos tienen `# TODO: Planner detecta... → Generator produce... → Evaluator valida` — el ciclo PGE completo está previsto pero no implementado.

---

## 6. Lo que funciona correctamente

| Componente | Qué hace bien |
|-----------|---------------|
| Servidor :8095 HTTP | Recibe JSON-RPC, despacha a handlers, responde. Estable (uptime 3.3 días). |
| CRUD de tareas en `trazas.*` | INSERT/UPDATE/SELECT transaccional, correcto. |
| Algoritmos de grafo | DFS, Kahn, CPM — implementados y testeables en aislamiento. |
| Materializador | Crea estructura de carpetas y `CLAUDE.md` de forma confiable. |
| ctx_filter / cache_mgr | Gestión de contexto y caché en disco funcionales. |
| gen_manifest / gen_ai_doc | Generan artefactos útiles (YAML y AI-docs). |
| backoff.py / logger.py | Infraestructura de retry y logging sólida. |
| OrquestaCoreSBOS CLI | Tracking de build pipeline funcional como herramienta local. |

---

## 7. Lo que no existe pero está prometido

| Funcionalidad prometida | En qué módulo | Estado real |
|------------------------|--------------|-------------|
| WebSocket `/rpc/ws` | `servidor.py` | No implementado |
| Búsqueda semántica / pgvector | `memoria.py` | Es `ILIKE %query%` |
| Identidad de agente | `security/agent_identity.py` | Archivo vacío |
| Generación real de DDL | `gen_db.py` | Stub con TODOs |
| Generación real de migraciones | `gen_migration.py` | Template vacío |
| Generación real de tests | `gen_tests.py` | Solo smoke test |
| Integración OrquestaCoreSBOS ↔ SKDATA | `build_state.py` | Desconectado |
| Memoria de agente entre sesiones | ningún schema | Schema no creado |
| Índice de archivos con FTS | ningún schema | Schema no creado |
| Glosario de términos | ningún schema | Schema no creado |

---

## 8. Evaluación por dimensión

### Infraestructura base (coordinator :8095 + trazas.*)
**Estado:** FUNCIONA — No tocar.
El corazón del coordinador es código real y bien escrito. Las 21 tareas en BD prueban que opera. Solo necesita:
- Corregir el bug de `get_graph` (BUG-001)
- Agregar unicidad en `declare_task` (BUG-003)

### Capa de persistencia (biblioteca.py + degradación silenciosa)
**Estado:** FUNCIONA CON RIESGO.
La conexión a SKDATA es real. El problema es que el silencio de los errores enmascara fallos. Necesita:
- Cambiar `if not verificar_conexion(): return` por logging explícito y alarma
- Separar: "no puedo conectar" de "la tabla no existe"

### Generadores (tools/gen_*.py)
**Estado:** STUBS ESTRUCTURADOS.
Son esqueletos con la arquitectura correcta (ciclo PGE) pero sin implementación real del contenido. El plan PGE (Planner → Generator → Evaluator) está diseñado — falta el LLM en el ciclo.

### Memoria de agente (schemas nuevos)
**Estado:** NO EXISTE.
Los schemas `memoria`, `fabrica`, y las tablas de memoria de agente (`bitacora_agente`, `trabajo_codigo`, etc.) aún no se han creado en SKDATA. Es trabajo nuevo, no corrección.

### OrquestaCoreSBOS
**Estado:** AUTÓNOMO Y DESCONECTADO.
Funciona bien como herramienta local pero vive en su propio mundo. Su estado de build nunca llega al grafo de tareas del coordinador.

---

## 9. Resumen ejecutivo

**¿El código Python de la fábrica hace algo?**
SÍ. El servidor :8095 y la capa de coordinación de tareas es código real y funcional. Las 21 tareas en `trazas.tarea_coordinada` son evidencia directa.

**¿Por qué SKDATA tenía "0 filas"?**
Solo el schema `trazas` fue usado activamente. Los otros schemas (`conocimiento`, `perfiles`, `arboles`) quedaron en 0 por degradación silenciosa — los módulos que los usan fallan sin ruido cuando no conectan.

**¿Cuánto es decorativo?**
5 generadores son stubs con TODOs. 1 archivo está vacío. La "búsqueda semántica" es un ILIKE disfrazado. La memoria de agente entre sesiones no existe como schema en BD.

**¿Qué hay que construir desde cero?**
Los schemas nuevos de SKDATA (`memoria`, `fabrica`) y los hooks de SessionStart/Stop. Eso es el plan de reestructuración.

**¿Qué hay que corregir?**
4 bugs concretos (ver sección 4) y eliminar la degradación silenciosa universal de la capa de BD.
