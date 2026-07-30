---
name: bos-herramientas
description: >
  Protocolo MCP para el agente bos-developer: codebase-memory-mcp (14 tools, grafo Go
  19K nodos), qex (5 tools, búsqueda semántica en los 27 manuales + 13 anexos de BOS),
  sequential-thinking (1 tool). Invocar antes de explorar el código o la documentación.
---

# Skill — BOS: Herramientas MCP

**Regla de oro:** MCP primero, `Read` como último recurso.

| Reducción de tokens | Exploración manual ~80K · 5 queries al grafo ~3,400 | **Ahorro: 99.2 %** |
|--------------------|------------------------------------------------------|---------------------|

---

## 1 · codebase-memory-mcp — Grafo Go de BOS (14 tools)

**Proyecto BOS en el grafo:**

| Métrica | Valor |
|---------|-------|
| Proyecto indexado | `bos` |
| Nodos | 19,120 |
| Edges | 76,442 |
| Código | 527 archivos .go |
| Raíz Go | `BosAgent/src/` (módulo `bos`) |

### 1.1 Indexación

| Tool | Uso |
|------|-----|
| `index_repository` | Indexar o re-indexar BOS tras commits grandes |
| `index_status` | Ver cuándo se indexó por última vez |
| `list_projects` | Ver todos los proyectos disponibles |

```python
# Re-indexar BOS después de commits masivos
index_repository(repo_path="/opt/skull/orquestador/proyectos/SBOS/BosAgent/src", name="bos")
```

---

### 1.2 Búsqueda estructural

#### `search_graph` — buscar símbolos Go por patrón

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `name_pattern` | regex | — | Patrón sobre el nombre (ej. `".*Handler.*"`) |
| `label` | str | — | Tipo: `Function`, `Method`, `Struct`, `Interface`, `File`… |
| `min_degree` | int | — | Mínimo de aristas (nodos bien conectados) |
| `max_degree` | int | — | Máximo; `max_degree=0` → **código muerto** |
| `exclude_entry_points` | bool | false | Excluir `main()`, handlers de entrada |
| `project` | str | — | Filtrar por proyecto |
| `file_pattern` | regex | — | Filtrar por ruta (ej. `".*installer.*"`) |
| `direction` | enum | both | `inbound` / `outbound` / `both` |
| `limit` | int | 20 | Resultados máximos |
| `offset` | int | 0 | Paginación |

```python
# Buscar handlers del Context Plane
search_graph(name_pattern=".*[Cc]tx.*", label="Method", project="bos")

# Buscar implementaciones del dispatcher K8s (Principio P1)
search_graph(name_pattern=".*[Kk]ubectl.*|.*[Dd]ispatch.*", label="Function", project="bos")

# Código muerto en el motor de fichas
search_graph(label="Function", max_degree=0, exclude_entry_points=true,
             file_pattern=".*ficha.*", project="bos")

# Funciones de saga con más de 8 callers
search_graph(name_pattern=".*[Ss]aga.*", min_degree=8, direction="inbound", project="bos")
```

---

#### `trace_path` — cadena de llamadas Go

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `function_name` | str | requerido | Nombre o qualified_name |
| `direction` | enum | — | `inbound` (quién llama) / `outbound` (qué llama) |
| `depth` | int 1-5 | 3 | Profundidad máxima |
| `risk_labels` | list[str] | — | Resaltar nodos con estas etiquetas |

```python
# ¿Quién llama al dispatcher K8s? (verificar Principio P1)
trace_path("k8s.Core.Apply", direction="inbound", depth=4)

# ¿Qué hace Install en la saga? (traza hacia afuera)
trace_path("installer.InstallSaga", direction="outbound", depth=3)

# Cadena completa del Context Plane con riesgo marcado
trace_path("context.Service.CreateCtx", direction="outbound", depth=4,
           risk_labels=["db_write", "external_rpc"])

# ¿Quién llama al State Manager? (verificar Principio P8 — solo state.Manager escribe)
trace_path("state.Manager.Write", direction="inbound", depth=5)
```

---

#### `detect_changes` — impacto de commits

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `project` | str | requerido | Nombre del proyecto |
| `scope` | enum | commit | `commit` / `branch` / `staged` |
| `base_branch` | str | main | Rama base en scope=branch |
| `depth` | int | 2 | Profundidad de impacto transitivo |

```python
# ¿Qué cambió en el último commit?
detect_changes(project="bos", scope="commit")

# Impacto completo de la rama actual
detect_changes(project="bos", scope="branch", base_branch="main", depth=4)
```

---

#### `query_graph` — Cypher sobre el grafo Go

**Soporte:** MATCH, WHERE, WITH, RETURN, LIMIT, COUNT, COLLECT, OPTIONAL MATCH ✅ · APOC ❌ · escritura ❌

```python
# Verificar Principio P1: todas las rutas a kubectl pasan por k8s.Core
query_graph(query="""
  MATCH (caller:Function)-[:CALLS]->(kubectl:Function)
  WHERE kubectl.name CONTAINS 'kubectl' OR kubectl.name CONTAINS 'Kubectl'
  AND NOT caller.file CONTAINS 'internal/k8s'
  RETURN caller.name, caller.file
""")

# Funciones de saga sin compensación (candidatos a bug)
query_graph(query="""
  MATCH (saga:Function)-[:CALLS]->(step:Function)
  WHERE saga.name CONTAINS 'Saga'
  AND NOT EXISTS {
    MATCH (saga)-[:CALLS]->(comp:Function)
    WHERE comp.name CONTAINS 'Rollback' OR comp.name CONTAINS 'Compensate'
  }
  RETURN saga.name, saga.file
""")

# Paquetes Go que acceden al state manager directamente (violación P8)
query_graph(query="""
  MATCH (caller:Function)-[:CALLS]->(writer:Function {name: "Write"})
  WHERE writer.file CONTAINS 'state'
  WITH caller.file AS pkg, COUNT(caller) AS calls
  WHERE calls > 0
  RETURN pkg, calls ORDER BY calls DESC
""")

# Hotspots — métodos con >10 callers (candidatos a refactor)
query_graph(query="""
  MATCH (caller)-[:CALLS]->(f:Function)
  WHERE f.file CONTAINS 'internal'
  WITH f, COUNT(caller) AS callers
  WHERE callers > 10
  RETURN f.name, f.file, callers ORDER BY callers DESC LIMIT 20
""")

# Ciclos de importación entre paquetes Go
query_graph(query="""
  MATCH (a:Package)-[:IMPORTS]->(b:Package)-[:IMPORTS]->(a)
  RETURN a.name, b.name
""")
```

---

#### `get_architecture` — estructura de BOS

```python
# Vista general del proyecto Go
get_architecture(project="bos", aspects=["overview", "packages", "entry_points"])

# Dependencias externas (librerías de terceros)
get_architecture(project="bos", aspects=["dependencies"])

# Clusters de paquetes (detectar separación de dominio)
get_architecture(project="bos", aspects=["clusters"])
```

---

#### `get_graph_schema`
Sin parámetros. Devuelve tipos de nodo y arista del grafo — útil antes de escribir Cypher custom.

---

### 1.3 Acceso a código fuente

#### `get_code_snippet` — código Go sin leer el archivo

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `qualified_name` | str | Nombre calificado del símbolo Go |

**Formato qualified_name para Go (módulo `bos`):**
```
"bos/internal/context.Service.CreateCtx"    ← paquete.Tipo.Método
"bos/internal/installer.InstallSaga"        ← paquete.Función
"bos/cmd/bos.main"                          ← cmd.función
"k8s.Core.Apply"                            ← Tipo.Método (forma corta)
"ficha.Parser.Parse"                        ← Tipo.Método (forma corta)
```

```python
# Primero: encontrar el qualified_name exacto
search_graph(name_pattern=".*CreateCtx.*", label="Method", project="bos")

# Luego: obtener el código
get_code_snippet(qualified_name="context.Service.CreateCtx")
```

---

#### `search_code` — búsqueda de texto en código Go

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `pattern` | str | requerido | Texto o regex |
| `regex` | bool | false | Tratar como regex |
| `project` | str | — | Filtrar por proyecto |

```python
# Encontrar todos los puntos donde se usa ctx_id
search_code(pattern="ctx_id", project="bos")

# Puertos hardcodeados (violación P6)
search_code(pattern=":\\d{4,5}", regex=true, project="bos")

# Uso directo de kubectl fuera de internal/k8s (violación P1)
search_code(pattern="exec\\.Command.*kubectl", regex=true, project="bos")
```

---

#### `manage_adr` — ADRs del proyecto BOS

```python
# Listar ADRs de BOS
manage_adr(project="bos", mode="get")

# Registrar decisión arquitectónica
manage_adr(project="bos", mode="create", sections={
    "title": "ADR: Context Plane — un solo Service, sin acceso directo",
    "status": "Accepted",
    "context": "Múltiples paquetes necesitan ctx_id",
    "decision": "Solo internal/context.Service expone ctx_id. Nadie más toca la BD de contexto.",
    "consequences": "Toda operación de contexto pasa por la interfaz ContextPort"
})
```

---

### 1.4 Trazas avanzadas

#### `ingest_traces` — validar llamadas externas

```python
# Verificar que bos llama a bAuth solo por Unix socket (Principio P9)
ingest_traces(traces=[{
    "caller": "bos/internal/bauth.Client.ValidateToken",
    "callee_url": "unix:///run/bos/bauth.sock",
    "method": "JSON-RPC"
}])
```

---

## 2 · qex — Búsqueda semántica en documentación BOS (5 tools)

**Corpus BOS:** 27 manuales + 13 anexos en `context/Documentacion/` · organizados por 6 motores.

### `search_code` — preguntas en español sobre documentación

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `query` | str | requerido | Pregunta en lenguaje natural |
| `path` | str | — | Directorio a buscar |
| `limit` | int | 10 | Resultados máximos |
| `extension_filter` | list[str] | — | Filtrar por extensión |

**Queries por motor:**

```python
# Motor ① IAM Installer
search_code(query="secuencia de instalación day 0 bootstrap 6 capas")
search_code(query="saga de instalación compensación y rollback")
search_code(query="ciclo de vida de tenants alta baja suspensión")
search_code(query="hardening de red NetworkPolicy y TLS")

# Motor ② SO Observable
search_code(query="watchdog 3 capas y rollback automático del daemon")
search_code(query="reconciliación de drift y reparación multi-capa")
search_code(query="health checks y métricas de observabilidad")

# Motor ③ Server FICHAS
search_code(query="máquina de estados de la ficha 18 estados")
search_code(query="anatomía canónica de una ficha manifest.yml")
search_code(query="executor y parser de fichas declarativas")
search_code(query="port manager asignación de puertos Kardex")
search_code(query="catálogo de fichas disponibles en servers/")

# Motor ④ Context Plane
search_code(query="ctx_id creación ciclo de vida y propagación")
search_code(query="Context Plane integración con bAuth dctx_id")
search_code(query="seguridad del contexto y trazabilidad")

# Motor ⑤ Dashboard
search_code(query="JSON-RPC métodos bos.ctx bos.ficha bos.tenant")
search_code(query="WebSocket sobre Unix socket Interface Dual")
search_code(query="contratos de eventos y momentos de conexión")

# Búsqueda cross-motor
search_code(query="principios de diseño P1 a P14 BOS")
search_code(query="rutas canónicas del sistema bos.toml rbac roles")

# Solo en documentación de BOS
search_code(
    query="flujo end-to-end de operación instalación a steady state",
    path="/opt/skull/orquestador/proyectos/SBOS/BosAgent/context/Documentacion",
    extension_filter=[".md"]
)
```

### Otros tools qex

| Tool | Uso |
|------|-----|
| `index_codebase` | Re-indexar `context/Documentacion/` si se agregan manuales |
| `get_indexing_status` | Ver chunks/archivos indexados |
| `download_model` | Verificar modelo ONNX snowflake-arctic-embed-s |
| `clear_index` | Limpiar índice de un path específico |

---

## 3 · sequential-thinking — Razonamiento estructurado (1 tool)

**Regla:** nunca se usa solo — siempre alimentado de resultados reales de qex + grafo.

### Parámetros

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `thought` | str | Contenido del pensamiento actual |
| `thoughtNumber` | int | Número de pensamiento (1, 2, 3…) |
| `totalThoughts` | int | Estimación total (revisable con `needsMoreThoughts`) |
| `nextThoughtNeeded` | bool | `false` en el último para cerrar |
| `isRevision` | bool | Corrección de pensamiento del mismo hilo |
| `revisesThought` | int | Número que se corrige |
| `branchFromThought` | int | Inicio de rama paralela |
| `branchId` | str | Nombre de la rama (`"opcion-a"`, `"hipotesis-b"`) |
| `needsMoreThoughts` | bool | Hay más pensamientos aunque se llegó al total |

**`isRevision`** = corrijo el mismo hilo · **`branchFromThought`** = exploro alternativa paralela.

### Casos de uso BOS

| Situación | Flujo |
|-----------|-------|
| Diseño de nueva saga | `search_code` (protocolo sagas) → `trace_path` (sagas existentes) → `sequential-thinking` (pasos + compensaciones) |
| Bug en el State Manager | `trace_path("state.Manager.Write", inbound, depth=5)` → `get_code_snippet` → `sequential-thinking` (hipótesis concurrencia) |
| Agregar nueva ficha | `search_code` (anatomía ficha) → `get_architecture` (estructura actual) → `sequential-thinking` (diseño manifest.yml) |
| Refactor motor de fichas | `query_graph` (hotspots + ciclos) → `sequential-thinking` (plan) → `qex` (impacto en docs) |
| Verificar Principio P1 | `query_graph` (rutas a kubectl) → `sequential-thinking` (analizar violaciones) |

---

## 4 · Flujos combinados para BOS

### Inicio de sesión (PASO 0 obligatorio)
```python
# 1. Bitácora anterior
query("SELECT donde_quede, que_falta, proxima_accion FROM memoria.bitacora_agente WHERE agente_id = 'bos'")

# 2. Arquitectura general
get_architecture(project="bos", aspects=["overview", "packages"])

# 3. Contexto semántico del motor a trabajar
search_code(query="motor SO Observable watchdog reconciliación")  # adaptar al motor del día

# 4. Plan de sesión
sequentialthinking(thought="Bitácora dice que quedé en X. La arquitectura muestra Y. El plan de hoy es...",
                   thoughtNumber=1, totalThoughts=3, nextThoughtNeeded=True)
```

---

### Verificar integridad del Principio P1 (K8s dispatch único)
```python
# 1. Todas las rutas que llaman a kubectl fuera de k8s.Core
query_graph(query="""
  MATCH (caller:Function)-[:CALLS]->(kubectl:Function)
  WHERE (kubectl.name CONTAINS 'kubectl' OR kubectl.name CONTAINS 'exec')
  AND NOT caller.file CONTAINS 'internal/k8s'
  RETURN caller.name, caller.file
""")

# 2. Quién llama a k8s.Core.Apply
trace_path("k8s.Core.Apply", direction="inbound", depth=4)

# 3. Documentación del principio
search_code(query="Principio P1 dispatcher único kubectl k8s.Core")

# 4. Analizar hallazgos
sequentialthinking(thought="El grafo muestra N violaciones al P1. Las rutas son...",
                   thoughtNumber=1, totalThoughts=4, nextThoughtNeeded=True)
```

---

### Debug de bug en una saga
```python
# 1. Código de la saga problemática
search_graph(name_pattern=".*InstallSaga.*|.*RepairSaga.*", label="Function", project="bos")
get_code_snippet(qualified_name="installer.InstallSaga")

# 2. Cadena de llamadas
trace_path("installer.InstallSaga", direction="outbound", depth=4)

# 3. Documentación del protocolo de sagas
search_code(query="saga compensación rollback timeout instalación")

# 4. Hipótesis
sequentialthinking(thought="La saga falla en el paso 3. El trace muestra que...",
                   thoughtNumber=1, totalThoughts=5, nextThoughtNeeded=True)
```

---

### Diseñar una nueva ficha declarativa
```python
# 1. Anatomía de fichas existentes
search_code(query="anatomía canónica de ficha manifest.yml task_catalog")

# 2. Ver fichas similares en el grafo
search_graph(name_pattern=".*[Ff]icha.*", label="File", file_pattern=".*servers.*", project="bos")

# 3. Port Manager — verificar puertos disponibles (Principio P11)
search_code(query="catálogo de puertos SBOS-050 asignación")

# 4. Diseño con razonamiento estructurado
sequentialthinking(thought="La nueva ficha necesita: 1) manifest.yml con dependencias SO, 2) puertos en rango X, 3) task_catalog con install/health/remove...",
                   thoughtNumber=1, totalThoughts=5, nextThoughtNeeded=True)
```

---

## 5 · Matriz de decisión — qué usar cuándo (BOS)

| Necesidad | Herramienta | Tool |
|-----------|------------|------|
| "¿Qué llama al dispatcher kubectl?" | `codebase-memory-mcp` | `trace_path` inbound |
| "¿Qué hace InstallSaga?" | `codebase-memory-mcp` | `trace_path` outbound |
| "¿Dónde se define ContextPort?" | `codebase-memory-mcp` | `search_graph` label=Interface |
| "Dame el código de state.Manager.Write" | `codebase-memory-mcp` | `get_code_snippet` |
| "Funciones del motor de fichas sin callers" | `codebase-memory-mcp` | `search_graph` max_degree=0 |
| "¿Viola alguien el Principio P1?" | `codebase-memory-mcp` | `query_graph` Cypher |
| "¿Cómo funciona el Context Plane?" | `qex` | `search_code` en español |
| "Protocolo de sagas y compensación" | `qex` | `search_code` |
| "Anatomía de una ficha declarativa" | `qex` | `search_code` |
| "Estado de trabajo anterior" | `skdata-biblioteca` | `query` bitacora_agente |
| "Diseñar nueva saga con compensaciones" | `sequential-thinking` | `sequentialthinking` |
| "Strings de error exactos, TODOs" | `Grep` (bash) | — no usar MCP — |

---

## 6 · Anti-patterns críticos para BOS

| Anti-pattern | Consecuencia | Qué hacer |
|-------------|--------------|-----------|
| Leer `internal/k8s/` con Read para entender P1 | 80K tokens, fácil perderse | `trace_path("k8s.Core.Apply", inbound)` primero |
| Adivinar qualified_name sin buscar primero | Código equivocado o error | `search_graph` → copiar nombre exacto → `get_code_snippet` |
| Usar sequential-thinking sin datos del grafo | Razonamiento sin base real | Siempre correr `trace_path` o `query_graph` antes |
| Escribir Cypher con APOC | Error — APOC no disponible | Solo Cypher estándar: MATCH, WHERE, WITH, RETURN |
| Usar `qex search_code` para buscar código Go | qex es para documentación | Para código Go: `codebase-memory-mcp search_code` o `search_graph` |
| Buscar "en SBOS" sin especificar `project="bos"` | Resultados de todos los daemons | Siempre `project="bos"` en búsquedas de BOS |
| Asumir que el índice está actualizado tras commits masivos | Resultados obsoletos | Verificar con `index_status` y re-indexar si hace >1 día |
