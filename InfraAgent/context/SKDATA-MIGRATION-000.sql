-- =================================================================
-- SKDATA — Migration 000: Sistema de Memoria de la Fábrica
-- Fecha: 2026-07-02
-- Autor: Bibliotecario SBOS
-- Estado: APLICADA ✅
-- Estrategia: DDL ADITIVO — solo CREATE, cero DROP, cero ALTER
--
-- Cubre los 6 problemas identificados en SKDATA-MEMORIA-AGENTES.md:
--   P1: Historia de docs       → conocimiento.documento_version
--   P2: Contexto al reiniciar  → memoria.bitacora_agente
--   P3: Índice de archivos     → memoria.indice_archivo
--   P4: Resumen en lenguaje agente → conocimiento.resumen_documento
--   P5: Glosario               → conocimiento.termino
--   P6: Log de código          → memoria.trabajo_codigo
--
-- Notas de aplicación:
--   - pgvector: PENDIENTE — requiere usuario 'postgres' en PG
--     (PG corre en contenedor, contraseña de postgres no disponible)
--   - Función arr_text() creada en schema public para GENERATED columns
--   - 0 tablas existentes modificadas — DDL puramente aditivo
-- =================================================================

-- Extensión pgvector — INSTALADA ✅ (2026-07-02, v0.8.0)
-- Credencial postgres: sbos2026!Postgres (contenedor 'biblioteca', podman)
CREATE EXTENSION IF NOT EXISTS vector;

-- -----------------------------------------------------------------
-- FIX INMUTABLE: función wrapper para array_to_string
-- PostgreSQL 18 requiere IMMUTABLE en expresiones de columnas generadas
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.arr_text(arr text[]) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT coalesce(array_to_string(arr, ' '), '') $$;

-- -----------------------------------------------------------------
-- SCHEMA memoria (NUEVO — resuelve P2, P3, P6)
-- -----------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS memoria;

-- P2: Estado de sesión activa — lectura al iniciar (<2s)
-- Patrón LangGraph: checkpoint JSONB atómico serializable
CREATE TABLE IF NOT EXISTS memoria.bitacora_agente (
    agente_id         TEXT        PRIMARY KEY,
    proyecto          TEXT        NOT NULL,
    actualizado_en    TIMESTAMPTZ DEFAULT now() NOT NULL,
    donde_quede       TEXT        NOT NULL,
    que_falta         TEXT        NOT NULL,
    proxima_accion    TEXT        DEFAULT '',
    archivos_activos  TEXT[]      DEFAULT '{}',
    funciones_activas TEXT[]      DEFAULT '{}',
    git_branch        TEXT,
    git_ultimo_commit TEXT,
    decisiones_hoy    TEXT        DEFAULT '',
    bloqueos          TEXT        DEFAULT '',
    -- Checkpoint LangGraph: {active_task_id, steps_completed[], artifacts[], last_session_id}
    checkpoint        JSONB       DEFAULT '{}'
);

COMMENT ON TABLE memoria.bitacora_agente IS
    'Estado de sesión activa por agente. Lectura al iniciar (<2s). Upsert al cerrar.';

-- P6: Log de código — event sourcing append-only (ESAA pattern)
-- NUNCA se hace UPDATE sobre esta tabla
CREATE TABLE IF NOT EXISTS memoria.trabajo_codigo (
    id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    agente_id    TEXT        NOT NULL,
    sesion_id    TEXT        NOT NULL,
    proyecto     TEXT        NOT NULL,
    ruta_archivo TEXT        NOT NULL,
    funcion      TEXT,
    accion       TEXT        NOT NULL,
    linea_desde  INTEGER,
    linea_hasta  INTEGER,
    outcome      TEXT,
    detalle      TEXT,
    ts           TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT chk_tc_accion  CHECK (accion  IN ('READ','EDITED','CREATED','DELETED','TESTED','COMPILADO','REVERTIDO')),
    CONSTRAINT chk_tc_outcome CHECK (outcome IN ('OK','ERROR','SKIPPED','REVERTIDO') OR outcome IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_tc_sesion  ON memoria.trabajo_codigo (sesion_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_tc_archivo ON memoria.trabajo_codigo (ruta_archivo, accion);
CREATE INDEX IF NOT EXISTS idx_tc_agente  ON memoria.trabajo_codigo (agente_id, ts DESC);

COMMENT ON TABLE memoria.trabajo_codigo IS
    'Log append-only de acciones sobre código. El agente sabe exactamente qué tocó al reiniciar.';

-- Resumen ejecutivo de sesión (detalle granular en trabajo_codigo)
CREATE TABLE IF NOT EXISTS memoria.trabajo_sesion (
    id                    UUID        PRIMARY KEY DEFAULT uuidv7(),
    agente_id             TEXT        NOT NULL,
    proyecto              TEXT        NOT NULL,
    sesion_id             TEXT        NOT NULL UNIQUE,
    fecha_inicio          TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_fin             TIMESTAMPTZ,
    git_branch            TEXT,
    git_commits           TEXT[]      DEFAULT '{}',
    archivos_creados      TEXT[]      DEFAULT '{}',
    archivos_modificados  JSONB       DEFAULT '[]',
    archivos_eliminados   TEXT[]      DEFAULT '{}',
    funciones_agregadas   JSONB       DEFAULT '[]',
    funciones_modificadas JSONB       DEFAULT '[]',
    funciones_eliminadas  JSONB       DEFAULT '[]',
    resumen               TEXT,
    estado                TEXT        DEFAULT 'activo' NOT NULL,
    CONSTRAINT chk_ts_estado CHECK (estado IN ('activo','completado','interrumpido'))
);

CREATE INDEX IF NOT EXISTS idx_tsesion_agente   ON memoria.trabajo_sesion (agente_id, fecha_inicio DESC);
CREATE INDEX IF NOT EXISTS idx_tsesion_proyecto ON memoria.trabajo_sesion (proyecto, fecha_inicio DESC);

COMMENT ON TABLE memoria.trabajo_sesion IS
    'Resumen ejecutivo de sesión. Detalle granular en trabajo_codigo.';

-- P3: Índice del filesystem con FTS
CREATE TABLE IF NOT EXISTS memoria.indice_archivo (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    ruta_absoluta  TEXT        NOT NULL UNIQUE,
    proyecto       TEXT        NOT NULL,
    tipo           TEXT        NOT NULL,
    descripcion    TEXT        NOT NULL,
    -- Hechos atómicos, máx 200 chars, sin prosa narrativa
    resumen_agente TEXT        NOT NULL,
    palabras_clave TEXT[]      DEFAULT '{}',
    hash_contenido TEXT,
    lineas         INTEGER,
    vigente        BOOLEAN     DEFAULT true,
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    ts             TSVECTOR    GENERATED ALWAYS AS (
                     to_tsvector('spanish',
                       ruta_absoluta || ' ' || descripcion || ' ' ||
                       resumen_agente || ' ' || public.arr_text(palabras_clave))
                   ) STORED,
    CONSTRAINT chk_ia_tipo CHECK (tipo IN ('codigo','doc','config','ddl','ficha','test','seed','script','otro'))
);

CREATE INDEX IF NOT EXISTS idx_ia_fts      ON memoria.indice_archivo USING GIN (ts);
CREATE INDEX IF NOT EXISTS idx_ia_proyecto ON memoria.indice_archivo (proyecto, tipo, vigente);

COMMENT ON TABLE memoria.indice_archivo IS
    'Mapa del filesystem. El agente busca aquí antes de leer archivos directo.';

-- -----------------------------------------------------------------
-- SCHEMA fabrica (NUEVO — registro permanente de agentes del grid)
-- -----------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS fabrica;

CREATE TABLE IF NOT EXISTS fabrica.agente (
    id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    codigo      TEXT        NOT NULL UNIQUE,
    nombre      TEXT        NOT NULL,
    tipo        TEXT        NOT NULL,
    slot_tmux   INTEGER,
    proyecto    TEXT,
    modelo_llm  TEXT,
    unix_socket TEXT,
    estado      TEXT        DEFAULT 'activo',
    descripcion TEXT,
    creado_en   TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_fa_tipo   CHECK (tipo   IN ('desarrollador','staff','coordinador','revisor','testeador','planificador','documentador')),
    CONSTRAINT chk_fa_estado CHECK (estado IN ('activo','inactivo','suspendido'))
);

CREATE INDEX IF NOT EXISTS idx_fa_tipo_estado ON fabrica.agente (tipo, estado);

COMMENT ON TABLE fabrica.agente IS
    'Registro permanente de los 12 agentes del grid tmux. Referencia estable para trazabilidad.';

-- -----------------------------------------------------------------
-- SCHEMA conocimiento — tablas nuevas (no toca las existentes)
-- Resuelve P1, P4, P5
-- -----------------------------------------------------------------

-- P1: Historial de versiones con patrón bitemporal (Zep/Graphiti)
CREATE TABLE IF NOT EXISTS conocimiento.documento_version (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    ruta_archivo   TEXT        NOT NULL,
    proyecto       TEXT        NOT NULL,
    version_num    INTEGER     NOT NULL,
    section_id     TEXT,
    hash_contenido TEXT        NOT NULL,
    patch_diff     JSONB,                   -- JSONPatch RFC 6902. NULL en v1
    resumen_cambio TEXT,
    resumen_agente TEXT,
    autor_agente   TEXT,
    event_time     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ingestion_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ruta_archivo, version_num)
);

CREATE INDEX IF NOT EXISTS idx_dv_archivo  ON conocimiento.documento_version (ruta_archivo, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_dv_proyecto ON conocimiento.documento_version (proyecto, ingestion_time DESC);

COMMENT ON TABLE conocimiento.documento_version IS
    'Historial bitemporal de documentos. event_time=cuándo cambió, ingestion_time=cuándo el agente lo vio.';

-- P4: Resumen actual de cada documento en lenguaje agente
CREATE TABLE IF NOT EXISTS conocimiento.resumen_documento (
    ruta_archivo   TEXT        PRIMARY KEY,
    proyecto       TEXT        NOT NULL,
    version_num    INTEGER     NOT NULL,
    hash_contenido TEXT        NOT NULL,
    resumen_agente TEXT        NOT NULL,
    puntos_clave   TEXT[]      DEFAULT '{}',
    restricciones  TEXT[]      DEFAULT '{}',
    dependencias   TEXT[]      DEFAULT '{}',
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    ts             TSVECTOR    GENERATED ALWAYS AS (
                     to_tsvector('spanish',
                       resumen_agente || ' ' ||
                       public.arr_text(puntos_clave) || ' ' ||
                       public.arr_text(restricciones))
                   ) STORED
);

CREATE INDEX IF NOT EXISTS idx_rd_fts      ON conocimiento.resumen_documento USING GIN (ts);
CREATE INDEX IF NOT EXISTS idx_rd_proyecto ON conocimiento.resumen_documento (proyecto);

COMMENT ON TABLE conocimiento.resumen_documento IS
    'Estado actual de cada doc en formato agente. Leer esto en lugar del archivo completo.';

-- P5: Glosario de términos técnicos
CREATE TABLE IF NOT EXISTS conocimiento.termino (
    codigo          TEXT        PRIMARY KEY,
    proyecto        TEXT,
    nombre          TEXT        NOT NULL,
    definicion      TEXT        NOT NULL,
    resumen_agente  TEXT        NOT NULL,
    rutas_docs      TEXT[]      DEFAULT '{}',
    ejemplo         TEXT,
    relacionado_con TEXT[]      DEFAULT '{}',
    vigente         BOOLEAN     DEFAULT true,
    ts              TSVECTOR    GENERATED ALWAYS AS (
                      to_tsvector('spanish',
                        codigo || ' ' || nombre || ' ' || definicion || ' ' || resumen_agente)
                    ) STORED
);

CREATE INDEX IF NOT EXISTS idx_termino_fts      ON conocimiento.termino USING GIN (ts);
CREATE INDEX IF NOT EXISTS idx_termino_proyecto ON conocimiento.termino (proyecto, vigente);

COMMENT ON TABLE conocimiento.termino IS
    'Glosario de la fábrica. El agente resuelve ambigüedades aquí antes de preguntar.';

-- fragmento_doc: complementa conocimiento.patron (que se conserva intacto)
CREATE TABLE IF NOT EXISTS conocimiento.fragmento_doc (
    id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    proyecto   TEXT        NOT NULL,
    categoria  TEXT        NOT NULL,
    titulo     TEXT        NOT NULL,
    contenido  TEXT        NOT NULL,
    fuente     TEXT        NOT NULL,
    vigente    BOOLEAN     DEFAULT true,
    creado_en  TIMESTAMPTZ DEFAULT now(),
    ts         TSVECTOR    GENERATED ALWAYS AS (
                 to_tsvector('spanish', titulo || ' ' || contenido)
               ) STORED,
    CONSTRAINT chk_fd_categoria CHECK (
        categoria IN ('decision','regla','estado','diseño','restriccion','arquitectura','protocolo')
    )
);

CREATE INDEX IF NOT EXISTS idx_fd_fts      ON conocimiento.fragmento_doc USING GIN (ts);
CREATE INDEX IF NOT EXISTS idx_fd_proyecto ON conocimiento.fragmento_doc (proyecto, categoria, vigente);

COMMENT ON TABLE conocimiento.fragmento_doc IS
    'Fragmentos indexables de documentos. Complementa patron (que se conserva).';

-- -----------------------------------------------------------------
-- SCHEMA proyectos — tabla nueva config_entorno
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS proyectos.config_entorno (
    id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    proyecto_id UUID        NOT NULL REFERENCES proyectos.proyecto(id),
    entorno     TEXT        NOT NULL,
    parametros  JSONB       NOT NULL DEFAULT '{}',
    descripcion TEXT,
    activo      BOOLEAN     DEFAULT true,
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    UNIQUE (proyecto_id, entorno),
    CONSTRAINT chk_ce_entorno CHECK (entorno IN ('local','staging','prod','test'))
);

CREATE INDEX IF NOT EXISTS idx_ce_proyecto ON proyectos.config_entorno (proyecto_id, activo);

COMMENT ON TABLE proyectos.config_entorno IS
    'Parámetros de entorno por proyecto: IPs VPS, puertos, rutas canónicas.';

-- -----------------------------------------------------------------
-- SEMILLAS: agentes del grid (12 del grid tmux)
-- -----------------------------------------------------------------

INSERT INTO fabrica.agente (codigo, nombre, tipo, slot_tmux, proyecto, modelo_llm, descripcion) VALUES
    ('revisor',      'Revisor de Código',          'revisor',       0,  'fabrica', 'claude-sonnet-4-6', 'Calidad arquitectónica: SOLID, Clean Architecture, OWASP, ISO 27001'),
    ('testeador',    'Testeador Integral',          'testeador',     1,  'fabrica', 'claude-sonnet-4-6', 'Validación contra VPS real con BD poblada. No testea mocks.'),
    ('bos',          'IAM Installer (BOS)',         'desarrollador', 2,  'SBOS',    'claude-sonnet-4-6', 'Core del BOS y ctx_id. Go 1.26+. 23 comandos bosctl.'),
    ('bauth',        'Identity Control Plane',      'desarrollador', 3,  'SBOS',    'deepseek',         'Daemon IAM. Keycloak + SPIs + BitMask 64-bit. ctx_id owner.'),
    ('biblio',       'Bibliotecario SBOS',          'documentador',  4,  'fabrica', 'deepseek',         'Custodio documental: BOS_V8, CLAUDE.md, fichas YAML.'),
    ('coordinador',  'Coordinador de Fábrica',      'coordinador',   5,  'fabrica', 'deepseek',         'Grafo SKDATA vía JSON-RPC :8095. Destraba bloqueos.'),
    ('biedata',      'Data Gateway',                'desarrollador', 6,  'SBOS',    'deepseek',         'Orquestador JSON-RPC 2.0. HTTP externo soberano.'),
    ('bkernel',      'Data Kernel',                 'desarrollador', 7,  'SBOS',    'deepseek',         'CDC WAL → Redis Streams. Sin HTTP, sin REST.'),
    ('btax',         'Facturación Bolivia SIN',     'desarrollador', 8,  'SBOS',    'deepseek',         'Daemon de facturación electrónica. Dep: biedata.'),
    ('bsearch',      'Motor de Búsqueda',           'desarrollador', 9,  'SBOS',    'deepseek',         'PostgreSQL 18+ nativo. WebSocket wss://. ctx_id filter.'),
    ('brate',        'Tipos de Cambio',             'desarrollador', 10, 'SBOS',    'deepseek',         'Colección actualizada de tipos de cambio globales.'),
    ('bcms',         'CMS Corporativo',             'desarrollador', 11, 'SBOS',    'deepseek',         'CMS multi-tenant gobernado por ctx_id.')
ON CONFLICT (codigo) DO NOTHING;

-- -----------------------------------------------------------------
-- SEMILLAS: glosario base (8 términos críticos del SBOS)
-- -----------------------------------------------------------------

INSERT INTO conocimiento.termino (codigo, proyecto, nombre, definicion, resumen_agente, rutas_docs, relacionado_con) VALUES
    ('ctx_id',    'SBOS', 'Context ID',
     'Objeto de contexto distribuido obligatorio en toda operación. Contiene tenant, empresa, sucursal, pos_logico, user_id, traceparent.',
     'Obligatorio en todo request. Sin ctx_id no hay trazabilidad. Owner: bos. Propagación: W3C Trace Context + OTel Baggage.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md'],
     ARRAY['traceparent','tenant','bitmask']),

    ('BitMask',   'SBOS', 'BitMask 64-bit de Privilegios',
     'Máscara de bits de 64 posiciones que codifica los privilegios de un usuario en un dominio dado.',
     '64 bits. Operaciones: AND/OR/XOR/NOT. 12 dominios D1-D12. Dual: RolBitMask + ContextBitMask. Owner: bauth.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-021-DAEMON-BAUTH.md'],
     ARRAY['ctx_id','LoA','SoD']),

    ('saga',      'SBOS', 'Saga de Orquestación',
     'Secuencia de operaciones distribuidas con compensación automática en caso de fallo.',
     'Pattern: orquestación (no coreografía). Compensación obligatoria. Timeout: 30min install. Owner: biedata.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-024-DAEMON-BIEDATA.md'],
     ARRAY['biedata','bos','rollback']),

    ('ficha',     'SBOS', 'Ficha de Despliegue',
     'Unidad atómica de despliegue del SBOS. Manifest YAML declarativo + saga de instalación. 18 estados.',
     'YAML en servers/. 18 estados (PENDIENTE→INSTALADA→…→DESINSTALADA). Owner: bos. Nunca editar pods directamente.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-019-FICHAS.md'],
     ARRAY['bos','saga','bootstrap']),

    ('UUIDv7',    NULL, 'UUID versión 7',
     'UUID ordenado por tiempo. Nativo en PostgreSQL 18+. DEFAULT uuidv7(). Mejor rendimiento de índice que UUIDv4.',
     'Usar DEFAULT uuidv7() en toda PK. NUNCA uuid_generate_v4(). Ordenado cronológicamente = índices eficientes.',
     ARRAY[]::TEXT[], ARRAY['postgresql']),

    ('RPC',       NULL, 'JSON-RPC 2.0',
     'Protocolo de invocación remota sobre Unix socket. Todos los daemons SBOS lo exponen.',
     'Transport: Unix socket /run/bos/<daemon>.sock (0660). Naming: bauth.session.create. Prohibido HTTP.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md'],
     ARRAY['unix_socket','ctx_id']),

    ('WAL',       'SBOS', 'Write-Ahead Log',
     'Log de PostgreSQL que registra cambios antes de aplicarlos. bKernel lo escucha vía pgoutput.',
     'bkernel escucha via CDC/pgoutput. Publica en Redis Streams. Loop prevention via pg_replication_origin.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-023-DAEMON-BKERNEL.md'],
     ARRAY['bkernel','redis_streams','CDC']),

    ('LoA',       'SBOS', 'Level of Assurance',
     'Nivel de garantía de autenticación LoA 1-4 según NIST SP 800-63.',
     'LoA 1=básico, LoA 4=hardware+biometría. Step-Up RFC 9470. Codificado en JWT claims. Owner: bauth.',
     ARRAY['context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-021-DAEMON-BAUTH.md'],
     ARRAY['bauth','BitMask','StepUp'])

ON CONFLICT (codigo) DO NOTHING;

-- =================================================================
-- pgvector v0.8.0 INSTALADO ✅
-- Para activar embeddings cuando FTS produzca >20% falsos negativos:
--   ALTER TABLE memoria.indice_archivo ADD COLUMN embedding vector(1536);
--   CREATE INDEX ON memoria.indice_archivo USING hnsw(embedding vector_cosine_ops);
-- =================================================================
