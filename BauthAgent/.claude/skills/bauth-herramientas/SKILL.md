---
name: bauth-herramientas
description: >
  Protocolo de uso de las herramientas MCP disponibles para el agente bAuth:
  codebase-memory-mcp (grafo de código Rust, 14 tools), qex (búsqueda semántica
  en Documentacion/, 5 tools) y sequential-thinking (razonamiento estructurado).
  Invocar antes de explorar archivos manualmente — el grafo responde en <1ms,
  qex busca en 50+ manuales y 70+ anexos sin leer ninguno.
---

# Skill — bAuth: Herramientas MCP de Consulta Rápida

**Regla de oro:** usar MCP antes de leer archivos manualmente.  
El grafo responde en <1ms (~500 tokens) vs. ~80K tokens de exploración archivo por archivo.  
qex busca en 58K chunks de docs y código en español sin abrir ningún archivo.

---

## 1 · Prioridad de consulta (orden obligatorio)

| Necesidad | Herramienta | Cuándo pasar a la siguiente |
|-----------|-------------|----------------------------|
| Buscar concepto en documentación | `qex → search_code` | El resultado no cubre la pregunta |
| Encontrar función/símbolo en Rust | `codebase-memory-mcp → search_graph` | No aparece en el grafo |
| Rastrear flujo de llamadas | `codebase-memory-mcp → trace_path` | — |
| Ver código de una función | `codebase-memory-mcp → get_code_snippet` | — |
| Decisión arquitectónica compleja | `sequential-thinking` (alimentado de los anteriores) | — |
| **Último recurso** | `Read` del archivo específico | Solo si MCP no dio resultado |

**Nunca** abrir `context/Documentacion/INDICE.md` para navegar: usar `qex` directamente.  
**Nunca** hacer `grep -r` en `src/` para encontrar una función: usar `search_graph` o `trace_path`.

---

## 2 · qex — búsqueda semántica en documentación

**5 tools:** `search_code` · `index_codebase` · `get_indexing_status` · `download_model` · `clear_index`

**Cubre:** `context/Documentacion/` — 50+ manuales (1.NN_MANUAL-*.md) + 70+ anexos (A.NN_ANEXO-*.md)  
**Motor:** BM25 + vectores densos (snowflake-arctic-embed-s, 384-dim, ONNX) · Auto-indexa si detecta cambios.

### Patrones frecuentes en bAuth

| Pregunta | Query para `search_code` |
|----------|--------------------------|
| ¿Cómo funciona el motor BitMask? | `"BitMask dual máscara operacional domain_registry"` |
| ¿Qué hace AtomLang? | `"AtomLang lenguaje políticas compilador verbos"` |
| ¿Cómo se evalúa una política PDP? | `"PDP evaluación política árbol PERMIT DENY obligación"` |
| ¿Qué tablas tiene el dominio D14? | `"D14 PAM acceso privilegiado tablas DDL"` |
| ¿Cómo funciona el JIT? | `"JIT just-in-time acceso temporal PAM breakglass"` |
| ¿Qué métodos de autenticación están implementados? | `"motor métodos autenticación implementados FIDO2 WebAuthn"` |
| ¿Cómo funciona ctx_id? | `"ctx_id Context Plane capas SBOS-049 sesión"` |
| ¿Qué es T-162? | `"idn_roles_template árbol políticas átomo posición"` |
| ¿Cómo funciona SoD? | `"SoD Separation of Duties verbos conflicto validación"` |
| ¿Qué es el motor de versionado? | `"MVU versionado universal ciclo vida roles B01 B03"` |
| ¿Cómo se emite un JWT? | `"JWT emisión firma RolBitMask ctx_id Ed25519"` |
| ¿Qué es CAEP? | `"CAEP RFC 9396 continuous access evaluation session_revoked"` |
| ¿Cómo funciona el Identity Proofing? | `"proofing IAL evidencia NIST SP 800-63A"` |

### Verificar que el índice está activo

```
qex → get_indexing_status
```

Si el estado es `not_indexed` o `stale` → ejecutar `index_codebase` antes de buscar.

---

## 3 · codebase-memory-mcp — grafo del código Rust de bAuth

**14 tools:** `trace_path` · `search_graph` · `get_code_snippet` · `get_architecture` · `detect_changes` · `query_graph` · `search_code` · y más.

**Cubre:** el grafo de funciones, structs, traits e imports del código Rust en `src/`  
**Velocidad:** <1ms por consulta — sin leer ningún archivo.

### Patrones frecuentes en bAuth

#### Encontrar símbolos

```
search_graph(name_pattern=".*bitmask.*")        # módulos y funciones del motor BitMask
search_graph(name_pattern=".*policy.*")          # motor de políticas / PDP
search_graph(name_pattern=".*auth_method.*")     # motor de métodos
search_graph(name_pattern=".*session.*")         # gestión de sesiones
search_graph(name_pattern=".*audit.*")           # trazabilidad y auditoría
search_graph(name_pattern=".*validate.*")        # validadores
search_graph(name_pattern=".*jwt.*")             # emisión de tokens
search_graph(name_pattern=".*caep.*")            # Continuous Access Evaluation
```

#### Rastrear cadenas de llamadas

```
trace_path("evaluate_access", direction="outbound")   # qué llama el evaluador de acceso
trace_path("validate_token", direction="inbound")     # quién llama al validador de token
trace_path("build_bitmask", direction="outbound")     # qué construye el BitMask
trace_path("sign_jwt", direction="inbound")           # quién solicita la firma de JWT
trace_path("handle_jit_request", direction="outbound") # flujo completo de una solicitud JIT
```

#### Ver código de una función sin leer el archivo

```
get_code_snippet("BitMaskEngine::evaluate")
get_code_snippet("PolicyChain::apply")
get_code_snippet("MethodRegistry::validate")
get_code_snippet("JwtEmitter::sign")
```

#### Ver arquitectura de módulos

```
get_architecture   # paquetes entry-points dependencias de src/
```

Esperar ver los 7 módulos principales: `bitmask/` · `policy/` · `auth_methods/` · `transport/` · `crypto/` · `domain/signature/` · `audit/`

#### Detectar impacto de un cambio

```
detect_changes   # qué funciones/archivos cambiaron en el último commit
```

Úsalo antes de verificar en VPS — saber exactamente qué cambió sin leer diffs.

#### Encontrar código sin callers (candidato a eliminar)

```
search_graph(name_pattern=".*", max_degree=0)   # funciones sin callers entrantes
```

#### Consultas avanzadas (Cypher)

```
query_graph("MATCH (f:Function)-[:CALLS]->(g:Function) WHERE g.name='evaluate_bitmask' RETURN f.name, f.file")
# → quién llama a evaluate_bitmask
```

---

## 4 · sequential-thinking — razonamiento estructurado

**1 tool:** `sequentialthinking`

**Regla:** nunca usar solo. Siempre alimentado de resultados de `qex` y `codebase-memory-mcp` primero.

### Cuándo usar en bAuth

| Situación | Flujo |
|-----------|-------|
| Decidir la arquitectura de un motor | `qex` buscar especificación → `get_architecture` verificar módulos → `sequential-thinking` decidir estructura |
| Diagnosticar un bug de autorización | `trace_path` rastrear flujo → `qex` buscar invariantes → `sequential-thinking` hipótesis → `get_code_snippet` verificar |
| Diseñar cambio en T-162 | `qex "árbol políticas invariantes"` → `search_graph(name_pattern=".*roles_template.*")` → `sequential-thinking` análisis de impacto |
| Elegir algoritmo criptográfico | `qex "algoritmos criptográficos NIST PQC"` → `sequential-thinking` evaluación → decisión documentada |
| Evaluar si un nuevo método de autenticación cabe en MethodRegistry | `qex "MethodRegistry PAM autenticación"` → `get_code_snippet("MethodRegistry")` → `sequential-thinking` análisis |

### Lo que sequential-thinking NO reemplaza

- No sustituye leer el DDL o el manual — úsalo DESPUÉS de leer las fuentes.
- Sus conclusiones siempre se validan contra código real o documentación antes de actuar.
- No es un oráculo — es un organizador de lo que ya sabes.

---

## 5 · Tabla de decisión rápida

| Si necesito... | Uso |
|----------------|-----|
| Qué dice el manual de un motor | `qex → search_code "<motor> especificación diseño"` |
| Qué tabla DDL corresponde a X | `qex → search_code "T-NNN <nombre>" o skill bauth-ddl §6` |
| Dónde está implementada una función | `search_graph(name_pattern=".*<nombre>.*")` |
| Quién llama a la función X | `trace_path("X", direction="inbound")` |
| Qué llama la función X | `trace_path("X", direction="outbound")` |
| El código exacto de una función | `get_code_snippet("<Struct::method>")` |
| La estructura de src/ | `get_architecture` |
| Qué cambió en el último commit | `detect_changes` |
| Razonar sobre una decisión compleja | `sequential-thinking` (tras qex + grafo) |
| El archivo completo (único caso válido) | `Read` — solo si todos los anteriores fallan |
