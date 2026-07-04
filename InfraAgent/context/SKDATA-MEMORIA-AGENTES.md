# SKDATA — Rediseño como Sistema de Memoria de la Fábrica
**Fecha:** 2026-07-02
**Estado:** ✅ APLICADO — Migration 000 ejecutada el 2026-07-02
**Autor:** sbos-coordinador + humano

---

## 1. Diagnóstico del diseño actual

**Dato clave:** SKDATA tiene 31 tablas definidas y **0 filas en todas ellas**.
El schema existe pero nunca se usó con datos reales. Podemos rediseñar sin restricciones de migración.

**El problema central del diseño actual:** SKDATA fue concebido como base de datos del
Compositor (un agente). No resuelve los 6 problemas reales de la fábrica multi-agente.

### Los 6 problemas que SKDATA debe resolver

| # | Problema | Impacto real | Situación actual |
|---|---|---|---|
| **P1** | Un agente no sabe qué cambió en un documento desde la última vez que lo leyó | Lee el documento completo cada vez. Desperdicia 30-50% del contexto | `doctrina.documento` solo guarda hash. Sin historial de cambios ni resumen |
| **P2** | Al reiniciar, el agente no sabe dónde quedó | Reconstruye contexto leyendo REGISTRO-ESTADO.md (1116 líneas) | `proyectos.sesion.contexto_proxima_sesion` es texto libre sin estructura |
| **P3** | Para encontrar un archivo, el agente lee cada uno de principio a fin | 40-60% del contexto en localización, no en trabajo real | No existe índice de archivos |
| **P4** | Los documentos están escritos para humanos, no para agentes | El agente procesa prosa narrativa y extrae hechos — ineficiente | Ninguna tabla tiene resúmenes en formato agente |
| **P5** | Cada sesión, el agente aprende desde cero qué es "RPC", "ctx_id", "BitMask" | Tokens desperdiciados en re-aprender terminología del proyecto | No existe glosario |
| **P6** | Al reiniciar, el agente lee código que tocó hace una hora y lo "mejora" destruyéndolo | Código regresionado sin saberlo | No existe log de trabajo a nivel código/función |

---

## 2. Principio rector del nuevo diseño

> **SKDATA no es la BD del Compositor. Es la memoria estructurada de la fábrica entera.**
> Todo agente que trabaja en la fábrica lee de SKDATA al iniciar y escribe a SKDATA al cerrar.
> El objetivo es que ningún agente gaste más de 30 segundos en reconstruir contexto.

---

## 3. Diseño propuesto — Schemas y tablas

### 3.1 Schema `memoria` — NUEVO (el más crítico)

Resuelve P2, P3, P6. Es el corazón del sistema.

```sql
CREATE SCHEMA memoria;

-- P2: Estado activo de sesión — lee en 2 segundos al iniciar
CREATE TABLE memoria.bitacora_agente (
    agente_id        TEXT        PRIMARY KEY,            -- 'bauth-developer', 'bibliotecario', etc.
    actualizado_en   TIMESTAMPTZ DEFAULT now() NOT NULL,
    proyecto         TEXT        NOT NULL,               -- 'SBOS', 'fabrica', etc.
    donde_quede      TEXT        NOT NULL,               -- "Archivo X, función Y, línea ~230"
    que_falta        TEXT        NOT NULL,               -- "Implementar handler logout, luego tests"
    archivos_activos TEXT[]      DEFAULT '{}',           -- rutas de archivos que estoy tocando
    funciones_activas TEXT[]     DEFAULT '{}',           -- funciones que estoy modificando
    decisiones_hoy   TEXT        DEFAULT '',             -- decisiones tomadas en esta sesión
    bloqueos         TEXT        DEFAULT '',             -- qué impide avanzar
    proxima_accion   TEXT        DEFAULT '',             -- exactamente qué hacer al reiniciar
    git_branch       TEXT,                              -- rama activa
    git_ultimo_commit TEXT                              -- último commit hash
);

COMMENT ON TABLE memoria.bitacora_agente IS
    'Estado de sesión activa de cada agente. Lectura al iniciar (<2s). Escritura al cerrar.';


-- P6: Log de trabajo a nivel código — qué se tocó realmente esta sesión
CREATE TABLE memoria.trabajo_sesion (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    agente_id        TEXT        NOT NULL,
    proyecto         TEXT        NOT NULL,
    fecha_inicio     TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_fin        TIMESTAMPTZ,
    git_branch       TEXT,
    git_commits      TEXT[]      DEFAULT '{}',           -- commits hechos en esta sesión
    archivos_creados TEXT[]      DEFAULT '{}',           -- rutas absolutas
    archivos_modificados JSONB   DEFAULT '[]',           -- [{ruta, descripcion_cambio}]
    archivos_eliminados TEXT[]   DEFAULT '{}',
    funciones_agregadas  JSONB   DEFAULT '[]',           -- [{archivo, funcion, descripcion}]
    funciones_modificadas JSONB  DEFAULT '[]',           -- [{archivo, funcion, tipo_cambio}]
    funciones_eliminadas  JSONB  DEFAULT '[]',
    resumen          TEXT,                              -- resumen ejecutivo de la sesión
    estado           TEXT        DEFAULT 'activo' NOT NULL,
    CONSTRAINT chk_trabajo_estado CHECK (estado IN ('activo','completado','interrumpido'))
);

CREATE INDEX ON memoria.trabajo_sesion (agente_id, fecha_inicio DESC);
CREATE INDEX ON memoria.trabajo_sesion (proyecto, fecha_inicio DESC);

COMMENT ON TABLE memoria.trabajo_sesion IS
    'Registro preciso de qué código tocó cada agente en cada sesión. Evita regresiones al reiniciar.';


-- P3: Índice del filesystem con resúmenes en lenguaje agente
CREATE TABLE memoria.indice_archivo (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    ruta_absoluta    TEXT        NOT NULL UNIQUE,
    proyecto         TEXT        NOT NULL,
    tipo             TEXT        NOT NULL,               -- 'codigo','doc','config','ddl','ficha','test'
    descripcion      TEXT        NOT NULL,               -- para humanos: qué es este archivo
    resumen_agente   TEXT        NOT NULL,               -- PARA AGENTES: hechos clave, formato lista
    palabras_clave   TEXT[]      DEFAULT '{}',
    hash_contenido   TEXT,                              -- SHA256 para detectar cambios
    lineas           INTEGER,
    vigente          BOOLEAN     DEFAULT true,
    actualizado_en   TIMESTAMPTZ DEFAULT now(),
    ts               TSVECTOR GENERATED ALWAYS AS (
                       to_tsvector('spanish',
                         ruta_absoluta || ' ' || descripcion || ' ' ||
                         resumen_agente || ' ' || array_to_string(palabras_clave, ' '))
                     ) STORED,
    CONSTRAINT chk_tipo CHECK (tipo IN ('codigo','doc','config','ddl','ficha','test','seed','script','otro'))
);

CREATE INDEX ON memoria.indice_archivo USING GIN (ts);
CREATE INDEX ON memoria.indice_archivo (proyecto, tipo, vigente);

COMMENT ON TABLE memoria.indice_archivo IS
    'Mapa del filesystem. El agente busca aquí primero, antes de leer archivos directos.';
```

---

### 3.2 Schema `conocimiento` — REFACTORIZADO

Resuelve P1, P4, P5. Mantiene lo que sirve, agrega lo que falta.

```sql
-- P1: Historial de versiones de documentos con resúmenes de cambio
CREATE TABLE conocimiento.documento_version (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    ruta_archivo     TEXT        NOT NULL,               -- ruta absoluta del documento
    proyecto         TEXT        NOT NULL,
    version_num      INTEGER     NOT NULL,
    hash_contenido   TEXT        NOT NULL,               -- SHA256 del contenido
    resumen_cambio   TEXT,                              -- qué cambió vs versión anterior (humano)
    resumen_agente   TEXT,                              -- qué cambió en formato lista de hechos (agente)
    autor_agente     TEXT,                              -- qué agente hizo el cambio
    session_id       UUID,                              -- referencia a trabajo_sesion
    fecha            TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (ruta_archivo, version_num)
);

CREATE INDEX ON conocimiento.documento_version (ruta_archivo, version_num DESC);
CREATE INDEX ON conocimiento.documento_version (proyecto, fecha DESC);

COMMENT ON TABLE conocimiento.documento_version IS
    'Historial de evolución de documentos. El agente consulta el último resumen_agente en lugar de leer el doc completo.';


-- P4: Resumen técnico de documentos en lenguaje agente
-- (complementa documento_version — se puede materializar aquí el estado actual)
CREATE TABLE conocimiento.resumen_documento (
    ruta_archivo     TEXT        PRIMARY KEY,
    proyecto         TEXT        NOT NULL,
    version_num      INTEGER     NOT NULL,              -- última versión indexada
    hash_contenido   TEXT        NOT NULL,
    -- Resumen en lenguaje agente: lista de hechos, no prosa
    -- Ejemplo: "47 handlers JSON-RPC | Puerto 9450 | Dep: Keycloak 26.6.1 | ctx_id obligatorio"
    resumen_agente   TEXT        NOT NULL,
    puntos_clave     TEXT[]      DEFAULT '{}',          -- lista de hechos atómicos
    restricciones    TEXT[]      DEFAULT '{}',          -- qué NO hacer según este doc
    dependencias     TEXT[]      DEFAULT '{}',          -- qué otros docs/módulos referencia
    actualizado_en   TIMESTAMPTZ DEFAULT now(),
    ts               TSVECTOR GENERATED ALWAYS AS (
                       to_tsvector('spanish',
                         resumen_agente || ' ' ||
                         array_to_string(puntos_clave, ' ') || ' ' ||
                         array_to_string(restricciones, ' '))
                     ) STORED
);

CREATE INDEX ON conocimiento.resumen_documento USING GIN (ts);
CREATE INDEX ON conocimiento.resumen_documento (proyecto);

COMMENT ON TABLE conocimiento.resumen_documento IS
    'Resumen actual de cada documento en formato agente. El agente lee esto, no el archivo completo.';


-- P5: Glosario de términos técnicos del proyecto/fábrica
CREATE TABLE conocimiento.termino (
    codigo           TEXT        PRIMARY KEY,           -- 'RPC', 'ctx_id', 'BitMask', 'UUIDv7', 'saga'
    proyecto         TEXT,                             -- NULL = global a toda la fábrica
    nombre           TEXT        NOT NULL,
    definicion       TEXT        NOT NULL,             -- para humanos
    resumen_agente   TEXT        NOT NULL,             -- "Usa X cuando Y. Nunca Z. Ejemplo: ..."
    rutas_docs       TEXT[]      DEFAULT '{}',         -- rutas a los docs autoritativos
    ejemplo          TEXT,                            -- snippet de código o uso concreto
    relacionado_con  TEXT[]      DEFAULT '{}',         -- otros termino.codigo relacionados
    vigente          BOOLEAN     DEFAULT true,
    ts               TSVECTOR GENERATED ALWAYS AS (
                       to_tsvector('spanish',
                         codigo || ' ' || nombre || ' ' || definicion || ' ' || resumen_agente)
                     ) STORED
);

CREATE INDEX ON conocimiento.termino USING GIN (ts);
CREATE INDEX ON conocimiento.termino (proyecto, vigente);

COMMENT ON TABLE conocimiento.termino IS
    'Glosario de la fábrica. El agente resuelve términos ambiguos aquí en lugar de preguntar.';


-- Índice FTS de fragmentos (ya propuesto, se mantiene)
CREATE TABLE conocimiento.fragmento_doc (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    proyecto         TEXT        NOT NULL,
    categoria        TEXT        NOT NULL,             -- 'decision','regla','estado','diseño','restriccion'
    titulo           TEXT        NOT NULL,
    contenido        TEXT        NOT NULL,
    fuente           TEXT        NOT NULL,             -- ruta del archivo origen
    vigente          BOOLEAN     DEFAULT true,
    creado_en        TIMESTAMPTZ DEFAULT now(),
    ts               TSVECTOR GENERATED ALWAYS AS (
                       to_tsvector('spanish', titulo || ' ' || contenido)
                     ) STORED
);

CREATE INDEX ON conocimiento.fragmento_doc USING GIN (ts);
CREATE INDEX ON conocimiento.fragmento_doc (proyecto, categoria, vigente);

-- Mantener: decision, patron (ya existentes, son útiles)
-- Eliminar o simplificar: gap (reemplazado por trabajo_sesion.bloqueos)
-- Eliminar: recurso_infraestructura (era para el Compositor, no para la fábrica)
```

---

### 3.3 Schema `fabrica` — NUEVO

Registro permanente de los agentes de la fábrica.

```sql
CREATE SCHEMA fabrica;

-- Registro permanente de agentes (no JIT — permanece aunque el agente no esté activo)
CREATE TABLE fabrica.agente (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    codigo           TEXT        NOT NULL UNIQUE,      -- 'bauth-developer', 'bibliotecario', etc.
    nombre           TEXT        NOT NULL,
    tipo             TEXT        NOT NULL,             -- 'desarrollador','staff','coordinador','revisor'
    pane_tmux        INTEGER,                         -- índice en el grid tmux
    proyecto         TEXT,                            -- proyecto asignado (NULL = transversal)
    modelo_llm       TEXT,                            -- 'claude-sonnet-4-6', 'deepseek', etc.
    unix_socket      TEXT,                            -- /run/bos/<daemon>.sock si aplica
    estado           TEXT        DEFAULT 'activo',
    descripcion      TEXT,
    creado_en        TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_tipo CHECK (tipo IN ('desarrollador','staff','coordinador','revisor','testeador','planificador','documentador'))
);

COMMENT ON TABLE fabrica.agente IS
    'Registro permanente de los agentes de la fábrica. Referencia estable para trazabilidad.';
```

---

### 3.4 Schema `proyectos` — EXPANDIDO

```sql
-- Agregar configuraciones de entorno por proyecto
CREATE TABLE proyectos.config_entorno (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    proyecto_id      UUID        NOT NULL REFERENCES proyectos.proyecto(id),
    entorno          TEXT        NOT NULL,            -- 'staging', 'prod', 'local'
    parametros       JSONB       NOT NULL DEFAULT '{}', -- IP, puertos, rutas, credenciales (encriptadas)
    descripcion      TEXT,
    activo           BOOLEAN     DEFAULT true,
    actualizado_en   TIMESTAMPTZ DEFAULT now(),
    UNIQUE (proyecto_id, entorno)
);

COMMENT ON TABLE proyectos.config_entorno IS
    'Parámetros de entorno por proyecto: IPs VPS, puertos, rutas canónicas. Refleja config/entornos/*.yml';
```

---

### 3.5 Schemas que se conservan simplificados

| Schema | Acción | Tablas que se conservan |
|---|---|---|
| `proyectos` | Conservar + expandir | `proyecto`, `sesion`, + nueva `config_entorno` |
| `trazas` | Conservar + simplificar | `tarea_coordinada`, `bloqueo`, `incidente`, `prueba_bos`, `error_instalador`, `invocacion_llm` |
| `seguridad` | Conservar | `identidad_agente` (JIT), `evento_identidad` |
| `doctrina` | Simplificar | `documento` (solo metadata), `eval_compositor` |
| `testing` | Conservar | `ejecucion_suite`, `fallo_test` |

### 3.6 Schemas que se eliminan o absorben

| Schema | Acción | Razón |
|---|---|---|
| `arboles` | Evaluar eliminación | Era exclusivo del Compositor. Si el Compositor se refactoriza, revisar |
| `perfiles` | Absorber en `fabrica` y `memoria` | `perfil` → `fabrica.agente` + `memoria.bitacora_agente` |
| `conocimiento.recurso_infraestructura` | Eliminar | Era para el Compositor, sin uso real |
| `conocimiento.gap` | Simplificar o eliminar | Reemplazado por `memoria.bitacora_agente.bloqueos` |

---

## 4. Correcciones técnicas obligatorias

### 4.1 UUIDv7 en lugar de UUIDv4

PG18 soporta `uuidv7()` nativo. Toda PK debe usarlo:

```sql
-- En PG18:
DEFAULT uuidv7()  -- no DEFAULT public.uuid_generate_v4()

-- Ventaja: UUIDv7 es ordenado por tiempo → índices B-tree más eficientes,
-- inserciones sin fragmentación de páginas, correlación natural con timestamp
```

### 4.2 TIMESTAMPTZ en lugar de TIMESTAMP

```sql
-- INCORRECTO (todo lo existente):
fecha timestamp without time zone DEFAULT now()

-- CORRECTO:
fecha TIMESTAMPTZ DEFAULT now()

-- Razón: sin zona horaria, dos agentes en zonas distintas generan ambigüedad
-- en el historial. La fábrica puede operar en múltiples servidores.
```

### 4.3 Índices faltantes

```sql
-- Los más críticos:
CREATE INDEX ON memoria.bitacora_agente (agente_id);           -- lectura al iniciar
CREATE INDEX ON conocimiento.resumen_documento (proyecto);     -- búsqueda por proyecto
CREATE INDEX ON conocimiento.termino USING GIN (ts);           -- búsqueda de términos
CREATE INDEX ON fabrica.agente (tipo, estado);                 -- filtro por tipo de agente
CREATE INDEX ON proyectos.proyecto (estado);                   -- proyectos activos
```

---

## 5. Mapa de uso — qué lee/escribe cada agente

| Momento | Qué hace el agente | Tabla SKDATA |
|---|---|---|
| **Al iniciar sesión** | Lee su estado anterior | `memoria.bitacora_agente` (1 fila, <1ms) |
| **Al buscar un archivo** | Busca por concepto | `memoria.indice_archivo` FTS |
| **Al leer un documento** | Lee el resumen primero | `conocimiento.resumen_documento` |
| **Al no entender un término** | Busca en glosario | `conocimiento.termino` |
| **Antes de tocar código** | Revisa qué tocó la sesión anterior | `memoria.trabajo_sesion` (último registro) |
| **Al tomar una decisión** | Registra la decisión | `conocimiento.decision` |
| **Al terminar sesión** | Actualiza su bitácora | `memoria.bitacora_agente` (upsert) |
| **Al cerrar una sesión** | Registra qué tocó | `memoria.trabajo_sesion` (insert) |
| **Al modificar un doc** | Registra versión + resumen | `conocimiento.documento_version` + `resumen_documento` |

---

## 6. Protocolo SessionStart/Stop con nuevo diseño

### Hook SessionStart (en `.claude/settings.json`)

```bash
psql 'postgresql://root@localhost:5402/SKDATA' -t -A -c "
SELECT
  '=== ESTADO PREVIO ===' || chr(10) ||
  'Proyecto: '      || proyecto        || chr(10) ||
  'Dónde quedé: '   || donde_quede     || chr(10) ||
  'Qué falta: '     || que_falta       || chr(10) ||
  'Archivos activos: ' || array_to_string(archivos_activos, ', ') || chr(10) ||
  'Próxima acción: ' || proxima_accion || chr(10) ||
  'Rama git: '      || COALESCE(git_branch, 'no registrada') || chr(10) ||
  'Último commit: ' || COALESCE(git_ultimo_commit, 'no registrado')
FROM memoria.bitacora_agente
WHERE agente_id = '<AGENTE_ID>';" 2>/dev/null \
|| echo 'Sin estado previo. Sesión nueva.'
```

### Hook SessionStop (protocolo de cierre)

```bash
# Ejecutar al terminar sesión
psql 'postgresql://root@localhost:5402/SKDATA' -c "
INSERT INTO memoria.bitacora_agente
  (agente_id, proyecto, donde_quede, que_falta, archivos_activos,
   funciones_activas, decisiones_hoy, bloqueos, proxima_accion, git_branch, git_ultimo_commit)
VALUES
  ('<AGENTE>', '<PROYECTO>', '<DONDE>', '<QUE_FALTA>',
   ARRAY['<arch1>','<arch2>'], ARRAY['<func1>'], '<decisiones>', '<bloqueos>',
   '<proxima>', '<branch>', '<commit_hash>')
ON CONFLICT (agente_id) DO UPDATE SET
  proyecto          = EXCLUDED.proyecto,
  donde_quede       = EXCLUDED.donde_quede,
  que_falta         = EXCLUDED.que_falta,
  archivos_activos  = EXCLUDED.archivos_activos,
  funciones_activas = EXCLUDED.funciones_activas,
  decisiones_hoy    = EXCLUDED.decisiones_hoy,
  bloqueos          = EXCLUDED.bloqueos,
  proxima_accion    = EXCLUDED.proxima_accion,
  git_branch        = EXCLUDED.git_branch,
  git_ultimo_commit = EXCLUDED.git_ultimo_commit,
  actualizado_en    = now();"
```

---

## 7. Lo que NO necesita SKDATA

| Herramienta | Decisión | Razón |
|---|---|---|
| **Embeddings vectoriales (pgvector)** | No ahora | PostgreSQL FTS con tsvector es suficiente para búsqueda de docs en español. Embeddings agregan complejidad sin beneficio comprobado para este caso de uso. Revisar en 6 meses si FTS no alcanza. |
| **Redis para memoria** | No | SKDATA ya es local en :5402. Redis agrega una capa. La latencia de PostgreSQL local es <1ms — suficiente para hooks de sesión. |
| **Almacenar contenido completo de documentos** | No | Los archivos ya están en disco. SKDATA guarda solo resúmenes y hashes. Duplicar contenido en BD es antipatrón. |

---

## 8. Estado del diseño — pendiente de completar

| Sección | Estado |
|---|---|
| Análisis del DDL actual | ✅ Completo — 0 filas, rediseño libre |
| 6 problemas identificados | ✅ |
| Schema `memoria` (P2, P3, P6) | ✅ APLICADO — 4 tablas en SKDATA |
| Schema `conocimiento` refactorizado (P1, P4, P5) | ✅ APLICADO — 4 tablas nuevas (las existentes intactas) |
| Schema `fabrica` (agentes permanentes) | ✅ APLICADO — 12 agentes del grid registrados |
| Schema `proyectos` expandido | ✅ APLICADO — config_entorno creada |
| Investigación externa de mejores prácticas | ✅ Completa (sec. 9) |
| DDL ejecutable completo (migration 000) | ✅ APLICADO — ver SKDATA-MIGRATION-000.sql |
| Semillas iniciales (glosario base, agentes de la fábrica) | ✅ APLICADO — 12 agentes + 8 términos |
| pgvector v0.8.0 | ✅ INSTALADO — contenedor 'biblioteca' (podman), usuario postgres |
| Hook SessionStart/Stop implementado | ⏳ PENDIENTE — Fase 7 del plan |

---

## 9. Hallazgos de la investigación externa (2025-2026)

Fuentes: LangGraph PostgreSQL persistence, Zep/Graphiti, Letta, ESAA (arXiv 2602.23193),
Mem0, Cognee, Aiven PostgreSQL FTS vs pgvector, Vectorize.io agent memory survey.

### 9.1 Correcciones al diseño propuesto

Los patrones de la industria refinan 4 decisiones del diseño anterior:

---

#### Corrección 1 — `documento_version` necesita patrón bitemporal (Zep/Graphiti 2025)

El problema de un solo timestamp es que no distingue "cuándo cambió el hecho" de "cuándo
el agente lo vio". Sin esta distinción, un agente no sabe si su lectura está desactualizada.

```sql
-- REEMPLAZA el diseño anterior de conocimiento.documento_version
CREATE TABLE conocimiento.documento_version (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    ruta_archivo     TEXT        NOT NULL,
    proyecto         TEXT        NOT NULL,
    version_num      INTEGER     NOT NULL,
    section_id       TEXT,                              -- sección específica si el doc tiene partes
    hash_contenido   TEXT        NOT NULL,
    patch_diff       JSONB,                             -- solo lo que cambió (JSONPatch RFC 6902)
                                                       -- NULL en v1 (primera versión)
    resumen_cambio   TEXT,                             -- para humanos: qué cambió
    resumen_agente   TEXT,                             -- lista de hechos atómicos: qué cambió
    autor_agente     TEXT,
    -- BITEMPORAL: dos timestamps
    event_time       TIMESTAMPTZ NOT NULL DEFAULT now(), -- cuándo cambió el hecho real
    ingestion_time   TIMESTAMPTZ NOT NULL DEFAULT now(), -- cuándo el agente lo procesó/indexó
    UNIQUE (ruta_archivo, version_num)
);

CREATE INDEX ON conocimiento.documento_version (ruta_archivo, event_time DESC);
CREATE INDEX ON conocimiento.documento_version (proyecto, ingestion_time DESC);
```

**Cómo lo usa el agente:**
```sql
-- "¿Qué cambió en este doc desde la última vez que lo leí?"
SELECT resumen_agente, patch_diff
FROM conocimiento.documento_version
WHERE ruta_archivo = $1
  AND event_time > $ultima_lectura_del_agente
ORDER BY version_num DESC;
-- Resultado: solo el diff — no el documento completo
```

---

#### Corrección 2 — `bitacora_agente` debe tener checkpoint JSONB serializable (LangGraph pattern)

LangGraph en producción usa un único campo JSONB que contiene el estado completo
serializable. Es más robusto que campos individuales porque el checkpoint es atómico.

```sql
-- VERSIÓN FINAL de memoria.bitacora_agente
CREATE TABLE memoria.bitacora_agente (
    agente_id        TEXT        PRIMARY KEY,
    proyecto         TEXT        NOT NULL,
    actualizado_en   TIMESTAMPTZ DEFAULT now() NOT NULL,
    -- Estado legible (para carga rápida en el hook SessionStart)
    donde_quede      TEXT        NOT NULL,
    que_falta        TEXT        NOT NULL,
    proxima_accion   TEXT        DEFAULT '',
    -- Arrays de trabajo activo
    archivos_activos   TEXT[]    DEFAULT '{}',
    funciones_activas  TEXT[]    DEFAULT '{}',
    -- Estado adicional
    git_branch         TEXT,
    git_ultimo_commit  TEXT,
    decisiones_hoy     TEXT      DEFAULT '',
    bloqueos           TEXT      DEFAULT '',
    -- Checkpoint completo serializado (LangGraph pattern) — para restauración exacta
    checkpoint         JSONB     DEFAULT '{}'
    -- checkpoint contiene: {active_task_id, steps_completed[], artifacts[], last_error, etc.}
);
```

---

#### Corrección 3 — `trabajo_codigo` debe ser event sourcing append-only (ESAA pattern)

El diseño anterior tenía `trabajo_sesion` con arrays. El patrón validado (ESAA arXiv 2025)
es **una fila por acción** — append-only, nunca se actualiza. Permite reconstruir
exactamente qué pasó y en qué orden.

```sql
-- NUEVA TABLA — reemplaza parcialmente trabajo_sesion
CREATE TABLE memoria.trabajo_codigo (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    agente_id        TEXT        NOT NULL,
    sesion_id        TEXT        NOT NULL,              -- id de sesión (timestamp al iniciar)
    proyecto         TEXT        NOT NULL,
    ruta_archivo     TEXT        NOT NULL,
    funcion          TEXT,                             -- nombre de función si aplica
    accion           TEXT        NOT NULL,             -- READ | EDITED | CREATED | DELETED | TESTED | COMPILADO
    linea_desde      INTEGER,
    linea_hasta      INTEGER,
    outcome          TEXT,                             -- OK | ERROR | SKIPPED | REVERTIDO
    detalle          TEXT,                             -- descripción del cambio
    ts               TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT chk_accion CHECK (accion IN ('READ','EDITED','CREATED','DELETED','TESTED','COMPILADO','REVERTIDO'))
);

-- Append-only: NUNCA se hace UPDATE sobre esta tabla
CREATE INDEX ON memoria.trabajo_codigo (sesion_id, ts DESC);
CREATE INDEX ON memoria.trabajo_codigo (ruta_archivo, accion);
CREATE INDEX ON memoria.trabajo_codigo (agente_id, ts DESC);
```

**Cómo lo usa el agente al reiniciar:**
```sql
-- "¿Qué archivos y funciones toqué en mi última sesión?"
SELECT DISTINCT ruta_archivo, funcion, accion, outcome
FROM memoria.trabajo_codigo
WHERE sesion_id = (
    SELECT checkpoint->>'last_session_id' FROM memoria.bitacora_agente WHERE agente_id = $1
)
ORDER BY ts DESC
LIMIT 50;
-- Resultado: sabe exactamente qué tocó — no toca código que ya fue modificado
```

---

#### Corrección 4 — pgvector instalado desde inicio, FTS como default

La investigación confirma: **FTS (tsvector) es suficiente para el caso actual del SBOS**:
- Vocabulario técnico fijo (ctx_id, BitMask, RPC, saga, ficha...)
- < 10K archivos en el índice
- < 5K términos en el glosario
- Búsquedas con los mismos términos que usan los documentos

**Pero:** instalar pgvector desde el inicio no tiene costo y prepara para búsqueda
semántica futura (cuando los agentes reporten falsos negativos).

```sql
-- Agregar a las extensiones existentes:
CREATE EXTENSION IF NOT EXISTS vector;  -- pgvector — instalado, no usado todavía
-- Activar en indice_archivo y termino cuando FTS no sea suficiente:
-- ALTER TABLE memoria.indice_archivo ADD COLUMN embedding vector(1536);
-- CREATE INDEX ON memoria.indice_archivo USING hnsw(embedding vector_cosine_ops);
```

Umbral para activar embeddings: cuando un agente busque "archivos de autenticación"
y FTS no encuentre `BauthAgent/src/engine.rs`. Si FTS + palabras_clave[] lo encuentra,
no se necesitan embeddings.

---

### 9.2 Formato validado para `resumen_agente` (agent language)

El consenso de la industria es **observational memory estructurada** — reduce 10x tokens
vs prosa completa. Formato validado en producción (Letta, Mem0, Cognee):

```
-- En lugar de texto libre como resumen_agente, usar este formato:
-- "47 handlers JSON-RPC operativos. Puerto 9450 Unix socket. Dep: Keycloak 26.6.1.
--  ctx_id obligatorio en cada request. BitMask 64-bit en PrivilegeEngine.
--  Estado: compila, 0 tests. Última modificación: src/domain/bitmask.rs"

-- Reglas para escribir resumen_agente:
-- 1. Hechos atómicos separados por punto o pipe
-- 2. Números concretos, no "varios" ni "algunos"
-- 3. Estados binarios: "compila / no compila", "tiene tests / sin tests"
-- 4. Dependencias nombradas con versión exacta
-- 5. Prohibido: "es un sistema que...", "se encarga de...", "permite que..."
-- 6. Máximo 200 caracteres — lo que no cabe en 200 chars va en puntos_clave[]
```

---

### 9.3 DDL final consolidado — cambios de la investigación sobre el diseño anterior

| Tabla | Cambio | Razón |
|---|---|---|
| `conocimiento.documento_version` | Agregar `event_time`, `ingestion_time`, `patch_diff JSONB`, `section_id` | Patrón bitemporal Zep/Graphiti |
| `memoria.bitacora_agente` | Agregar `checkpoint JSONB` | LangGraph pattern — estado atómico serializable |
| `memoria.trabajo_codigo` | Nueva tabla event sourcing append-only | ESAA pattern — una fila por acción |
| `memoria.trabajo_sesion` | Simplificar — es el resumen de sesión, `trabajo_codigo` tiene el detalle | Separación de concerns |
| `memoria.indice_archivo` | Sin cambio en estructura. Preparar columna `embedding vector(1536)` comentada | pgvector instalado, activación futura |
| `conocimiento.termino` | Sin cambio en estructura | FTS suficiente para glosario |
| Extensiones | Agregar `CREATE EXTENSION IF NOT EXISTS vector` | Preparación pgvector |

---

### 9.4 Tabla resumen — decisión FTS vs pgvector por caso de uso

| Caso | Solución | Cuándo activar pgvector |
|---|---|---|
| Buscar archivo por nombre/tipo | FTS tsvector | Nunca — búsqueda exacta |
| Buscar archivo por concepto ("autenticación") | FTS + palabras_clave[] | Si FTS produce > 20% falsos negativos |
| Buscar término en glosario | FTS tsvector | Cuando necesiten sinónimos |
| "¿Qué docs hablan de X?" | FTS tsvector + ts_rank | Si vocabulario crece > 50K fragmentos |
| "Docs conceptualmente similares a este" | SOLO pgvector | Activar cuando se pida esta feature |

---
*Documento actualizado con investigación externa — DDL ejecutable listo para aprobación*
