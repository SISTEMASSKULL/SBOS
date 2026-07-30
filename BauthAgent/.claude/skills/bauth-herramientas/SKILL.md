---
name: bauth-herramientas
description: >
  Protocolo profesional de uso de los 3 servidores MCP disponibles para bAuth:
  codebase-memory-mcp (14 tools — grafo de código Rust, 99.2% menos tokens que grep),
  qex (5 tools — búsqueda semántica BM25+vector en Documentacion/),
  sequential-thinking (1 tool — razonamiento estructurado con revisión y branching).
  Invocar antes de leer cualquier archivo manualmente.
---

# Skill — bAuth: Herramientas MCP · Protocolo Profesional

## Tres servidores · propósito único de cada uno

| Servidor | Tools | Dominio | Cuándo |
|----------|-------|---------|--------|
| `codebase-memory-mcp` | 14 | **Código Rust** — grafo de llamadas, funciones, structs, traits | Explorar `src/`, entender flujos, detectar impacto de cambios |
| `qex` | 5 | **Documentación** — manuales y anexos en `context/Documentacion/` | Responder "¿cómo funciona X?" sin leer archivos manualmente |
| `sequential-thinking` | 1 | **Razonamiento** — decisiones complejas, diagnóstico, diseño | DESPUÉS de consultar los otros dos, nunca antes ni solo |

**Eficiencia probada:** 5 queries al grafo = ~3 400 tokens · equivalente en grep = ~412 000 tokens. **Reducción del 99.2%.**

---

## Orden de prioridad — obligatorio

```
1. qex → search_code          si la pregunta es sobre documentación/especificación
2. codebase-memory-mcp → search_graph / trace_path  si es sobre código Rust
3. codebase-memory-mcp → get_code_snippet           si necesito el código exacto
4. sequential-thinking                               tras recopilar datos de 1 y 2
5. Read <archivo>                                    SOLO si los 4 anteriores no bastan
```

**Nunca:** `grep -r` en `src/` · abrir `INDICE.md` para navegar · `Read` de un manual completo.

---

## 1 · codebase-memory-mcp — 14 tools

### 1.1 Indexación (3 tools)

| Tool | Parámetros | Uso |
|------|-----------|-----|
| `index_repository` | `repo_path` (string, absoluta) | Indexar o re-indexar el repo bAuth. Incremental por hash — solo re-indexa archivos cambiados. |
| `index_status` | — | Verificar estado: node/edge counts, relaciones, tipos de propiedades por label. Usar antes de la primera sesión. |
| `list_projects` | — | Listar todos los proyectos indexados con timestamps, conteos de nodos/aristas. Útil en entorno multi-repo. |

> **Cuándo re-indexar:** solo si `index_status` reporta 0 nodos o si hubo un `git pull` grande. El auto-sync cubre cambios menores.

### 1.2 Búsqueda y exploración (6 tools)

#### `search_graph` — buscar nodos por patrón

```
search_graph(
  label          = "Function" | "Method" | "Class" | "Struct" | "Trait" | "Enum" | "Route" | "Module",
  name_pattern   = ".*bitmask.*",       # regex, case-insensitive por defecto
  project        = "bauth",             # aislar en multi-repo
  file_pattern   = ".*policy.*",        # filtrar por ruta de archivo
  relationship   = "CALLS",            # filtrar por tipo de arco
  direction      = "inbound" | "outbound",
  min_degree     = 10,                  # mínimo de conexiones (fan-out alto)
  max_degree     = 0,                   # 0 = código muerto
  exclude_entry_points = true,          # excluir main(), handlers, etc.
  case_sensitive = false,               # por defecto false
  limit          = 50,                  # paginación
  offset         = 0
)
# Respuesta: { total, has_more, results: [{name, qualified_name, file_path, start_line, ...}] }
```

**Patrones frecuentes en bAuth:**

```
# Módulos de los 7 motores
search_graph(label="Module", name_pattern=".*bitmask.*")
search_graph(label="Module", name_pattern=".*policy.*")
search_graph(label="Module", name_pattern=".*auth_method.*")
search_graph(label="Module", name_pattern=".*signature.*")
search_graph(label="Module", name_pattern=".*audit.*")
search_graph(label="Module", name_pattern=".*session.*")

# Funciones de evaluación de acceso
search_graph(label="Function", name_pattern=".*evaluat.*")
search_graph(label="Function", name_pattern=".*validate.*")
search_graph(label="Function", name_pattern=".*authorize.*")

# Código de alto fan-out (candidatos a refactor)
search_graph(label="Function", relationship="CALLS", direction="outbound", min_degree=10)

# Código muerto — sin callers (excluir entry points)
search_graph(label="Function", relationship="CALLS", direction="inbound", max_degree=0, exclude_entry_points=true)

# Todas las rutas JSON-RPC registradas
search_graph(label="Route")
```

---

#### `trace_path` — rastrear cadenas de llamadas

```
trace_path(
  function_name = "evaluate_bitmask",
  direction     = "inbound" | "outbound" | "both",
  depth         = 3,          # 1–5, por defecto 3. Usar 5 para flujos críticos
  risk_labels   = true        # añade CRITICAL/HIGH/MEDIUM/LOW a cada nodo
)
```

**Cuándo usar cada dirección:**
- `inbound` → "¿quién llama a X?" — impacto de un cambio en X
- `outbound` → "¿qué hace X?" — entender el flujo completo de una operación
- `both` → "¿cómo está conectada X en el grafo?" — para refactor o eliminación

**Flujos críticos de bAuth:**

```
# ¿Quién llama al evaluador de acceso?
trace_path(function_name="evaluate_access", direction="inbound", depth=4, risk_labels=true)

# ¿Qué hace el validador de token?
trace_path(function_name="validate_token", direction="outbound", depth=5)

# Flujo completo del motor BitMask
trace_path(function_name="build_bitmask", direction="both", depth=3, risk_labels=true)

# ¿Quién emite JWT?
trace_path(function_name="sign_jwt", direction="inbound", depth=3)

# Flujo de solicitud JIT
trace_path(function_name="handle_jit_request", direction="outbound", depth=5, risk_labels=true)

# Cadena de autenticación WebAuthn
trace_path(function_name="verify_webauthn", direction="both", depth=4)

# Motor de políticas — evaluación AtomLang
trace_path(function_name="evaluate_policy", direction="outbound", depth=5)
```

> **Resultado:** el grafo marca con CRITICAL las funciones en paths de alta conectividad — priorizar esas en revisión de seguridad.

---

#### `detect_changes` — impacto de cambios git

```
detect_changes(
  scope       = "unstaged" | "staged" | "all" | "branch",
  base_branch = "main",    # solo con scope="branch"
  depth       = 3
)
# Devuelve: archivos cambiados → símbolos afectados → callers impactados → clasificación de riesgo
```

**Usar ANTES de:**
- Hacer un commit — saber exactamente qué cambió y qué puede haberse roto
- Ir a la VPS de prueba — identificar qué tests ejecutar
- Entregar al humano — reportar blast radius real

---

#### `query_graph` — Cypher para patrones complejos

Sintaxis soportada: `MATCH`, `WHERE` (`=`, `<>`, `>`, `<`, `>=`, `<=`, `=~`, `CONTAINS`, `STARTS WITH`, `AND`, `OR`, `NOT`), `RETURN`, `ORDER BY`, `LIMIT`, `DISTINCT`, `COUNT`, paths variables `-[:CALLS*1..3]->`.  
**No soportado:** `WITH`, `COLLECT`, `SUM`, `OPTIONAL MATCH`, `UNION`, escrituras.  
**Máximo:** 200 filas. **Case-sensitivity:** sensible por defecto; usar `(?i)` para insensible.

**Queries Cypher de bAuth:**

```cypher
-- ¿Quién llama a evaluate_bitmask?
MATCH (a:Function)-[:CALLS]->(b:Function)
WHERE b.name = 'evaluate_bitmask'
RETURN a.name, a.qualified_name, a.file_path

-- Funciones del motor de políticas que llaman a la BD
MATCH (f:Function)-[:CALLS]->(db:Function)
WHERE f.name =~ '(?i).*policy.*' AND db.name =~ '(?i).*query.*'
RETURN f.name, db.name LIMIT 20

-- Cadena de llamadas desde entry point hasta firma JWT (hasta 4 hops)
MATCH (e:Function)-[:CALLS*1..4]->(j:Function)
WHERE e.is_entry_point = true AND j.name =~ '(?i).*sign.*'
RETURN e.name, j.name

-- Llamadas HTTP entre servicios con alta confianza
MATCH (a)-[r:HTTP_CALLS]->(b)
WHERE r.confidence > 0.7
RETURN a.name, r.url_path, r.http_method, r.confidence
ORDER BY r.confidence DESC LIMIT 20

-- Funciones que implementan un trait de seguridad
MATCH (f:Function)-[:IMPLEMENTS]->(t:Trait)
WHERE t.name =~ '(?i).*auth.*'
RETURN f.name, t.name

-- Funciones con muchos callers (hotspots de seguridad)
MATCH (b:Function)<-[r:CALLS]-(a:Function)
WITH b, COUNT(r) AS caller_count
WHERE caller_count > 5
RETURN b.name, caller_count ORDER BY caller_count DESC LIMIT 15
```

---

#### `get_architecture` — vista estructural del proyecto

```
get_architecture(
  aspects = ["all"]
  # O selectivo:
  aspects = ["languages", "packages", "entry_points", "routes", "hotspots",
             "boundaries", "services", "layers", "clusters", "file_tree", "adr"]
)
```

**Uso típico en bAuth:**
```
# Orientación rápida al inicio de sesión — ver los 7 módulos de src/
get_architecture(aspects=["packages", "entry_points", "hotspots"])

# Ver si hay routes JSON-RPC registradas
get_architecture(aspects=["routes"])

# Ver el ADR guardado (decisiones arquitectónicas persistidas)
get_architecture(aspects=["adr"])
```

---

#### `get_graph_schema` — entender el grafo antes de queries complejas

```
get_graph_schema()
# Devuelve: tipos de nodos, tipos de aristas, conteos, propiedades disponibles, ejemplos
```

Usar antes de escribir un query Cypher complejo para confirmar qué labels y relationships existen en el grafo actual de bAuth.

---

### 1.3 Acceso a código y ADR (3 tools)

#### `get_code_snippet` — código exacto sin leer el archivo

```
get_code_snippet(qualified_name = "bauth.src.bitmask.engine.BitMaskEngine.evaluate")
# Formato: <proyecto>.<path_con_puntos>.<Struct.method>
```

> Primero buscar con `search_graph` para obtener el `qualified_name` exacto, luego llamar aquí.

```
# Flujo correcto:
# 1. search_graph(label="Function", name_pattern=".*evaluate.*")
#    → encuentra qualified_name: "bauth.src.bitmask.BitMaskEngine.evaluate"
# 2. get_code_snippet(qualified_name="bauth.src.bitmask.BitMaskEngine.evaluate")
```

---

#### `search_code` — grep semántico en archivos

```
search_code(
  pattern        = "TODO|FIXME|HACK",
  regex          = true,
  case_sensitive = false,   # por defecto false
  max_results    = 50,
  offset         = 0
)
```

**Usar para:** strings literales de config, mensajes de error exactos, `unwrap()` sin manejo, `TODO` de seguridad.  
**No usar para:** buscar funciones o símbolos → usar `search_graph`.

---

#### `manage_adr` — Architecture Decision Records persistentes

```
manage_adr(
  mode     = "get" | "store" | "update" | "delete",
  content  = "...",   # solo en store
  sections = {        # solo en update — actualiza secciones específicas
    "PATTERNS": "...",
    "TRADEOFFS": "..."
  }
)
# Secciones disponibles: PURPOSE · STACK · ARCHITECTURE · PATTERNS · TRADEOFFS · PHILOSOPHY
# Máximo: 8000 caracteres
```

**Uso en bAuth:** persistir decisiones arquitectónicas de la sesión para que futuras sesiones las encuentren con `get_architecture(aspects=["adr"])`.

```
# Registrar decisión sobre el motor de políticas fail-closed
manage_adr(mode="update", sections={
  "PATTERNS": "- Motor de políticas: fail-closed (None ⇒ denegado). RFC: SBOS-031\n- BitMask: label-encoding (T-162) separado de one-hot (T-170)\n- SoD: solo validación, no participa en BitMask",
  "TRADEOFFS": "- fail-closed penaliza UX ante error de BD pero es la única opción segura en un PDP\n- atom_position en T-162 (no T-170) para inmutabilidad del audit log"
})
```

---

### 1.4 Herramienta avanzada (1 tool)

#### `ingest_traces` — validar HTTP_CALLS con trazas reales

Ingerir trazas de runtime para confirmar o corregir las aristas `HTTP_CALLS` del grafo (el parser estático puede inferir errores). Usar cuando el grafo muestra llamadas HTTP entre servicios que no coinciden con lo observado en la VPS de prueba.

---

## 2 · qex — 5 tools

**Dominio:** `context/Documentacion/` — 50+ manuales (1.NN_MANUAL-*.md) + 70+ anexos (A.NN_ANEXO-*.md)  
**Motor:** BM25 (tantivy) + vectores ONNX (snowflake-arctic-embed-s, 384-dim, 33 MB) → hybrid RRF  
**Velocidad:** BM25 < 5ms · Híbrido ~50ms · Incrementos en <100ms

### 2.1 `search_code` — búsqueda principal

```
search_code(
  path             = "/opt/skull/orquestador/proyectos/SBOS/BauthAgent",
  query            = "política árbol AtomLang compilador evaluación",  # lenguaje natural, español
  limit            = 10,                    # por defecto 10; subir a 15-20 si la respuesta es escasa
  extension_filter = "md"                   # forzar solo Markdown (documentación)
)
# Devuelve: snippets con file_path, line_range, relevance_score
```

**Principios del query:**
- Escribir en **español** — el índice está en español
- Usar términos del **dominio** (nombres de tablas, motores, normas): "D14", "PAM", "ctx_id", "idn_roles_template"
- Combinar nombre técnico + concepto: `"T-162 árbol políticas atom_position"` mejor que solo `"árbol"`
- Si la respuesta es genérica → agregar más términos específicos; si no hay resultados → simplificar

**Queries frecuentes en bAuth:**

```python
# Especificación de motores
search_code(query="BitMask dual máscara operacional domain_registry evaluación O(1)")
search_code(query="AtomLang lenguaje políticas compilador gramática verbos PERMIT DENY")
search_code(query="motor políticas PDP árbol jerarquía fail-closed evaluación")
search_code(query="motor métodos autenticación MethodRegistry FIDO2 WebAuthn Passkey")
search_code(query="motor firmas Ed25519 Vault ADSIB RSA-SHA256 doble firma JWT")
search_code(query="motor auditoría WORM hash-chain ISO 27001 eventos trazabilidad")
search_code(query="motor versionado MVU ciclo vida roles B01 aprobación quórum")

# DDL y tablas
search_code(query="T-162 idn_roles_template árbol políticas atom_position SEQUENCE")
search_code(query="T-170 privilege_atom_grant per-user JIT BREAKGLASS grant_type")
search_code(query="T-174 T-175 verbos SoD conflicto validación trigger INSERT")
search_code(query="T-182 PAM JIT solicitud aprobación multi-nivel quórum breakglass")
search_code(query="idn_identidad_entidad árbol 5 niveles tenant bdomain bsubdomain pos actor")

# Dominios de identidad
search_code(query="D00 identidad organizacional árbol N-to-N 37 sub-dominios multi-tenant")
search_code(query="D14 PAM acceso privilegiado checkout credenciales tier EMERGENCY")
search_code(query="D15 NHI identidades no-humanas daemons pipelines agentes IA")
search_code(query="D98 D99 administración global bglobal criptografía atributos versionado normas")

# Protocolos y estándares
search_code(query="ctx_id Context Plane 6 capas SBOS-049 trazabilidad sesión")
search_code(query="CAEP RFC 9396 continuous access evaluation session_revoked step_up")
search_code(query="Identity Proofing IAL evidencias NIST SP 800-63A-4 FAIR STRONG SUPERIOR")
search_code(query="JWT emisión firma RolBitMask ctx_id Ed25519 OIDC Provider nativo")
search_code(query="FAL Federation Assurance Level relying party DPoP mTLS FAPI 2.0")

# Arquitectura y decisiones
search_code(query="ADR-010 autosuficiencia Keycloak eliminado OIDC provider propio Rust")
search_code(query="SBOS-049 ctx_id obligatorio toda operación ISO 27001 A.8.15")
search_code(query="Interface Dual Unix socket WebSocket JSON-RPC namespace bauth")
```

---

### 2.2 Gestión del índice (4 tools)

```python
# Verificar estado del índice al inicio de sesión
get_indexing_status(path="/opt/skull/orquestador/proyectos/SBOS/BauthAgent")
# Respuesta: {indexed: true/false, file_count, chunk_count, languages, dense_available}

# Re-indexar (solo si get_indexing_status devuelve indexed=false o stale)
index_codebase(
  path       = "/opt/skull/orquestador/proyectos/SBOS/BauthAgent",
  force      = false,                    # true solo para limpiar índice corrupto
  extensions = ["md"]                    # solo documentación Markdown
)

# Descargar modelo ONNX (solo si dense_available=false)
download_model(force=false)

# Limpiar índice (solo si está corrupto o cambió el embedding provider)
clear_index(path="/opt/skull/orquestador/proyectos/SBOS/BauthAgent")
```

> **Nota sobre `extension_filter="md"`:** qex indexa código Rust Y documentación Markdown. Para búsquedas en `context/Documentacion/`, usar `extension_filter="md"` o solo `path` apuntando a `context/Documentacion/`. Para búsquedas en código Rust, no filtrar por extensión.

---

## 3 · sequential-thinking — 1 tool

**Propósito:** razonamiento iterativo, revisable y multi-ruta. No genera código — organiza lo que ya sabes para tomar una decisión bien fundamentada.

### 3.1 Parámetros del tool `sequentialthinking`

```json
{
  "thought"           : "string — el paso de razonamiento actual",
  "thoughtNumber"     : 1,         // posición en la secuencia (empezar en 1)
  "totalThoughts"     : 6,         // estimado inicial; puede expandirse
  "nextThoughtNeeded" : true,      // false = fin del razonamiento
  "needsMoreThoughts" : false,     // true = el problema es más complejo de lo estimado → aumentar totalThoughts
  "isRevision"        : false,     // true = este thought corrige un thought anterior
  "revisesThought"    : null,      // número del thought que se corrige (solo si isRevision=true)
  "branchFromThought" : null,      // número del thought desde el que bifurca (exploración paralela)
  "branchId"          : null       // identificador de la rama (solo con branchFromThought)
}
```

**Diferencia crítica: `isRevision` vs `branchFromThought`**

| Campo | Significa | Cuándo usar |
|-------|-----------|-------------|
| `isRevision=true` + `revisesThought=N` | El thought N tenía un error — se corrige en el mismo hilo lógico | Descubres que una premisa anterior era incorrecta |
| `branchFromThought=N` + `branchId="opcion-B"` | Explorar alternativa sin abandonar el hilo principal | Hay 2 diseños igualmente válidos que quieres comparar |

**Anti-patrones que deben evitarse:**
- ❌ Llamar una sola vez con todo el razonamiento pre-computado — el tool exige llamadas iterativas
- ❌ Usar sequential-thinking antes de consultar qex y el grafo — sin datos reales es especulación
- ❌ Poner `totalThoughts` demasiado bajo — si el problema crece, usar `needsMoreThoughts=true`
- ❌ Confirmar decisiones evidentes con sequential-thinking — es para complejidad genuina
- ❌ Derivar conclusiones de sequential-thinking sin validar con código real o documentación

### 3.2 Cuándo usar en bAuth

| Situación | Flujo |
|-----------|-------|
| Decidir arquitectura de un motor (ej. fail-closed en PDP) | `qex "motor políticas evaluación"` → `get_architecture` → `sequential-thinking` 5-7 steps |
| Diagnosticar bug de autorización (ej. grant concedido incorrectamente) | `trace_path("evaluate_access", direction="both")` → `get_code_snippet` → `sequential-thinking` hipótesis → `get_code_snippet` verificar |
| Diseñar cambio en T-162 (árbol de políticas) | `qex "T-162 invariantes"` → `search_graph(name_pattern=".*roles_template.*")` → `sequential-thinking` análisis impacto |
| Elegir entre Opción A y B del DDL (ej. metadatos de atributo) | `qex "idn_identidad_atributo_catalog"` → `sequential-thinking` + `branchFromThought` para cada opción |
| Planificar migración de motor de métodos (9→18 implementados) | `qex "motor métodos 47 categorías"` → `detect_changes(scope="branch")` → `sequential-thinking` hoja de ruta |

### 3.3 Ejemplo de flujo completo — decisión arquitectónica

```
# Pregunta: ¿cómo implementar fail-closed en el motor de políticas?

# Paso previo: recopilar datos
qex → search_code("motor políticas PDP evaluación fail-closed None")
codebase-memory-mcp → search_graph(label="Function", name_pattern=".*policy.*")
codebase-memory-mcp → trace_path("evaluate_policy", direction="outbound", depth=5)

# Luego: sequential-thinking
thought 1: "Revisando la spec (qex): el motor debe devolver None cuando no hay política → denegar"
thought 2: "El grafo muestra que evaluate_policy retorna Option<Decision> — correcto para fail-closed"
thought 3: "Riesgo: los llamadores de evaluate_policy deben tratar None como DENY, no como ALLOW"
thought 4: "trace_path revela 3 llamadores: handle_request, step_up, caep_handler"
thought 5: "Verificar cada uno con get_code_snippet"
thought 6 (isRevision=true, revisesThought=3): "handle_request ya trata None como DENY — correcto. step_up NO — bug"
thought 7: "Decisión: corregir step_up, documentar invariante en manage_adr"
nextThoughtNeeded=false
```

---

## 4 · Flujos combinados — casos reales de bAuth

### Inicio de sesión (primeros 5 minutos)

```python
# 1. Estado del grafo
index_status()
# Si 0 nodos → index_repository(repo_path="<ruta_absoluta_de_bauth_src>")

# 2. Estado del índice qex
get_indexing_status(path="<ruta_bauth>")
# Si not indexed → index_codebase(path="<ruta_bauth>", extensions=["md"])

# 3. Orientación rápida
get_architecture(aspects=["packages", "entry_points", "hotspots"])
# → ver los 7 módulos, entry points activos, funciones más llamadas

# 4. Recuperar ADR de sesiones anteriores
get_architecture(aspects=["adr"])
```

### Antes de modificar una función crítica

```python
# 1. ¿Quién la llama? (blast radius)
trace_path(function_name="<función>", direction="inbound", depth=4, risk_labels=true)

# 2. ¿Qué llama? (dependencias)
trace_path(function_name="<función>", direction="outbound", depth=3)

# 3. ¿Qué dice la spec sobre esta función?
search_code(query="<función> especificación invariante restricción")

# 4. Ver código actual
search_graph(label="Function", name_pattern=".*<función>.*")
# → obtener qualified_name
get_code_snippet(qualified_name="<qualified_name>")

# 5. Detectar impacto post-cambio
detect_changes(scope="unstaged", depth=3)
```

### Investigar un bug de autorización

```python
# 1. Rastrear el flujo de evaluación
trace_path(function_name="evaluate_access", direction="both", depth=5, risk_labels=true)

# 2. Buscar la spec de la decisión
search_code(query="PERMIT DENY evaluación política árbol restricción invariante")

# 3. Ver código del evaluador
get_code_snippet(qualified_name="<qualified_name_del_evaluador>")

# 4. Buscar el bug con regex
search_code(pattern="unwrap\(\)|expect\(|panic\!", regex=true)

# 5. Razonar
sequential-thinking: hipótesis → verificar con get_code_snippet → decidir fix
```

### Agregar un método de autenticación nuevo

```python
# 1. ¿Cómo está implementado un método existente?
search_graph(label="Function", name_pattern=".*webauthn.*")
trace_path(function_name="verify_webauthn", direction="outbound", depth=5)

# 2. ¿Qué dice la spec del MethodRegistry?
search_code(query="MethodRegistry PAM autenticación método nuevo registro trait")

# 3. ¿Qué traits implementa?
query_graph("MATCH (f:Function)-[:IMPLEMENTS]->(t:Trait) WHERE f.name =~ '(?i).*webauthn.*' RETURN f.name, t.name")

# 4. Impacto en el DDL
search_code(query="autenticación tabla DDL authenticator FIDO2 seed método")

# 5. sequential-thinking: diseñar la integración del nuevo método
```

---

## 5 · Tabla de decisión rápida

| Si necesito... | Tool | Parámetros clave |
|----------------|------|-----------------|
| "¿Cómo funciona X según la spec?" | `qex → search_code` | `query` en español, `extension_filter="md"` |
| "¿Qué tabla DDL es X?" | `qex → search_code` o skill bauth-ddl §6 | `query="T-NNN <nombre>"` |
| "¿Dónde está implementada la función X?" | `search_graph` | `label="Function", name_pattern=".*X.*"` |
| "¿Quién llama a X?" | `trace_path` | `direction="inbound", depth=3, risk_labels=true` |
| "¿Qué hace X?" | `trace_path` | `direction="outbound", depth=5` |
| "El código exacto de X" | `get_code_snippet` | `qualified_name` del search_graph |
| "Funciones sin callers" | `search_graph` | `max_degree=0, exclude_entry_points=true` |
| "Funciones de alta complejidad" | `search_graph` | `relationship="CALLS", direction="outbound", min_degree=10` |
| "Qué cambió y qué se rompe" | `detect_changes` | `scope="unstaged"` o `scope="branch"` |
| "La estructura de src/" | `get_architecture` | `aspects=["packages","hotspots"]` |
| "Un string literal o TODO" | `search_code` (grafo) | `pattern="TODO", regex=true` |
| "Decidir entre 2 opciones de diseño" | `sequential-thinking` + branching | `branchFromThought=N, branchId="opcion-A"` |
| "Corregir un paso de razonamiento" | `sequential-thinking` | `isRevision=true, revisesThought=N` |
| **Ninguno de los anteriores** | `Read <archivo>` | Solo si todo lo de arriba falló |
