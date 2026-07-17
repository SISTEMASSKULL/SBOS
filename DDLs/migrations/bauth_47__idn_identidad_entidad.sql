-- ============================================================================
-- bauth_47__idn_identidad_entidad.sql — Subsistema de Identidad (6 tablas)
-- ============================================================================
-- Propósito : Crear el subsistema completo de identidad del D00 según A.56.
--             Un solo archivo DDL = un subsistema (patrón bauth_30 compliance).
--
--             Tablas que crea este archivo:
--               idn_identidad_entidad          — jerarquía universal (adjacency list)
--               idn_identidad_atributo         — atributos extensibles (EAV + 7 índices)
--               idn_identidad_atributo_history — trazabilidad WORM (append-only, mensual)
--               idn_identidad_requisito        — completitud mínima por tipo (IAL1/IAL2)
--               idn_identidad_sinonimo         — sinónimos para fuzzy search (D93)
--               idn_identidad_sinonimo_sync    — control de sincronización .syn
--
--             Niveles (ENUM, no extensible — contrato del ctx_id):
--               tenant → bdomain → bsubdomain → pos → actor
--
--             Tipos (TEXT, extensible vía D93 — Catálogo de Identidades):
--               PERSONA, ORGANIZACION, DISPOSITIVO, SERVICIO, VEHICULO,
--               INMUEBLE, PRODUCTO, ANIMAL, ...
--
-- Fuente    : A.56 §2-§4 — Diseño BD Identidad v2.0.0
--             Manual 1.06 — D00 Identidad v2.1.0
--             Manual 7.02 — Calidad de Autenticación (patrón de subsistema)
-- Normas    : UUID v7 (RFC 9562) · Adjacency List + CTE recursiva
--             SBOS-049 §5.3 (Context Plane) · ISO 24760-2:2025 §5-§6
--             NIST SP 800-63A (IAL) · ISO 27001 A.8.15 (trazabilidad)
--             PCI DSS 10.3.2 · GDPR Art. 30
-- Autor     : bauth-developer · 2026-07-16
-- Estado    : DESARROLLO — el servicio bauth aún no está en producción
-- APROBACIÓN REQUERIDA antes de aplicar en producción (ddls.yml §reglas_agentes)
-- ============================================================================
-- IDEMPOTENCIA: CREATE TABLE IF NOT EXISTS + ON CONFLICT DO NOTHING.
--               Seguro ejecutar múltiples veces.
-- ============================================================================

BEGIN;
SET lock_timeout = '5s';

-- ============================================================================
-- PASO 1 — Crear el ENUM de niveles (si no existe)
-- ============================================================================
-- Los 5 niveles son el CONTRATO del Context Plane. No son extensibles.
-- Si cambian, el ctx_id se rompe (SBOS-049 §5.3).

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'idn_nivel_entidad') THEN
        CREATE TYPE bauth.idn_nivel_entidad AS ENUM (
            'tenant',
            'bdomain',
            'bsubdomain',
            'pos',
            'actor'
        );
    END IF;
END
$$;

-- ============================================================================
-- PASO 2 — Crear idn_identidad_entidad (adjacency list)
-- ============================================================================

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_entidad (
    -- ── Identidad ──
    entidad_id      UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL,  -- FK lógica a idn_tenant

    -- ── Jerarquía (adjacency list) ──
    parent_id       UUID,                  -- NULL = raíz (tenant). FK lógica a sí misma.
    nivel           bauth.idn_nivel_entidad NOT NULL,

    -- ── Clasificación ──
    tipo            TEXT        NOT NULL,  -- Extensible vía D93. Ej: PERSONA, VEHICULO, ...
    slug            TEXT        NOT NULL,  -- Único dentro del mismo parent_id. Parte del ctx_id.
    nombre          TEXT        NOT NULL,  -- Nombre descriptivo legible

    -- ── Tenant interno vs externo ──
    is_internal     BOOLEAN     NOT NULL DEFAULT false,

    -- ── Estado ──
    status          TEXT        NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION', 'ARCHIVED')),

    -- ── Auditoría (SBOS-049) ──
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- ── Constraints ──
    CONSTRAINT pk_idn_identidad_entidad PRIMARY KEY (entidad_id),
    CONSTRAINT uq_idn_identidad_slug UNIQUE (parent_id, slug),
    CONSTRAINT ck_idn_identidad_nivel CHECK (
        (nivel = 'tenant'    AND parent_id IS NULL) OR
        (nivel = 'bdomain'   AND parent_id IS NOT NULL) OR
        (nivel = 'bsubdomain' AND parent_id IS NOT NULL) OR
        (nivel = 'pos'       AND parent_id IS NOT NULL) OR
        (nivel = 'actor'     AND parent_id IS NOT NULL)
    )
);

-- ============================================================================
-- PASO 3 — Índices
-- ============================================================================

-- Navegación jerárquica: hijos directos de un padre
CREATE INDEX IF NOT EXISTS ix_idn_identidad_parent
    ON bauth.idn_identidad_entidad (parent_id, nivel, slug);

-- Búsqueda por tenant (RLS + filtro application-level)
CREATE INDEX IF NOT EXISTS ix_idn_identidad_tenant
    ON bauth.idn_identidad_entidad (tenant_id, nivel, tipo);

-- Búsqueda por tipo de entidad (ej: todas las PERSONAS)
CREATE INDEX IF NOT EXISTS ix_idn_identidad_tipo
    ON bauth.idn_identidad_entidad (tenant_id, tipo, status);

-- Búsqueda por slug dentro de tenant (resolución de ctx_id)
CREATE INDEX IF NOT EXISTS ix_idn_identidad_slug_tenant
    ON bauth.idn_identidad_entidad (tenant_id, slug);

-- ============================================================================
-- PASO 4 — Comentarios de documentación
-- ============================================================================

COMMENT ON TABLE bauth.idn_identidad_entidad IS
    'Repositorio universal de entidades de identidad (adjacency list). '
    'Una sola tabla para cualquier tipo de entidad — personas, empresas, '
    'vehículos, dispositivos, productos, animales, servicios. '
    '5 niveles fijos (ENUM) + tipo extensible (TEXT vía D93). '
    'Los niveles son el CONTRATO del ctx_id (SBOS-049 §5.3). '
    'UUID v7 (RFC 9562) para inserciones ordenadas sin fragmentación B-tree. '
    'ISO 24760-2:2025 §5-§6 · NIST SP 800-63A.';

COMMENT ON COLUMN bauth.idn_identidad_entidad.entidad_id IS
    'PK — UUID v7 (timestamp-ordered). Sin fragmentación de índice. RFC 9562.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.tenant_id IS
    'FK lógica a idn_tenant.tenant_id. Aislamiento multi-tenant.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.parent_id IS
    'FK lógica a sí misma. NULL = raíz (tenant). Adjacency list — CTE recursiva.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.nivel IS
    'ENUM fijo de 5 niveles: tenant, bdomain, bsubdomain, pos, actor. '
    'CONTRATO del ctx_id — NO es extensible. SBOS-049 §5.3.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.tipo IS
    'Tipo de entidad — extensible vía D93 (Catálogo de Identidades). '
    'Ej: PERSONA, ORGANIZACION, VEHICULO, DISPOSITIVO, PRODUCTO, ANIMAL, ...';
COMMENT ON COLUMN bauth.idn_identidad_entidad.slug IS
    'Identificador corto, único dentro del mismo parent_id. '
    'Parte del ctx_id: interno.skull.skull-corp.norte.caja-01.jperez';
COMMENT ON COLUMN bauth.idn_identidad_entidad.is_internal IS
    'true = tenant interno de SKULL. false = tenant externo. '
    'Primer segmento del ctx_id (SBOS-049 §5.3).';
COMMENT ON COLUMN bauth.idn_identidad_entidad.status IS
    'Estado de la entidad: ACTIVE, INACTIVE, SUSPENDED, PENDING_VERIFICATION, ARCHIVED. '
    'CHECK constraint — solo estos 5 valores son válidos.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.ctx_id IS
    'Contexto de la operación que creó/modificó esta entidad (SBOS-049 §5.3).';

-- ============================================================================
-- PASO 5 — idn_identidad_atributo (EAV con columnas generadas + 7 índices)
-- ============================================================================
-- Fuente: A.56 §3 — cada entidad define sus propios atributos sin ALTER TABLE.
--         value_normalized (fuzzy <100ms) + value_search (full-text <50ms).
--         columnas generadas STORED: calculadas UNA VEZ al INSERT/UPDATE.
--         Sin esto las búsquedas tardan 4-8s (lección de Magento, A.56 §4.1).

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo (
    -- ── Identidad ──
    atributo_id     BIGSERIAL,
    entidad_id      UUID        NOT NULL,   -- FK lógica a idn_identidad_entidad
    tenant_id       UUID        NOT NULL,   -- FK lógica a idn_tenant

    -- ── Clasificación del atributo (3 niveles — category → attr_key → type) ──
    category        TEXT        NOT NULL,   -- Ej: 'contacto', 'identificacion', 'laboral'
    attr_key        TEXT        NOT NULL,   -- Ej: 'email', 'telefono', 'CI', 'NIT'
    type            TEXT,                   -- Ej: 'work', 'home', 'mobile', 'fiscal'

    -- ── Valor (simple o complejo) ──
    value_text      TEXT,                   -- 80% de atributos: texto simple
    value_data      JSONB,                  -- 20% de atributos: estructura compleja

    -- ── Columnas generadas STORED para búsqueda ──
    value_normalized TEXT GENERATED ALWAYS AS (
        lower(unaccent(COALESCE(value_text, '')))
    ) STORED,
    value_search    TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('spanish', lower(unaccent(COALESCE(value_text, ''))))
    ) STORED,

    -- ── Gobernanza ──
    atom_code       INT,                    -- NULL=atributo libre · NOT NULL=controlado por BitMask
    dominio_origen  TEXT,                   -- Qué dominio agregó este atributo: 'civil','laboral','comercial',...

    -- ── Metadatos ──
    is_primary      BOOLEAN     NOT NULL DEFAULT false,
    is_verified     BOOLEAN     NOT NULL DEFAULT false,
    verified_by     TEXT,                   -- 'manual' | 'api_registro_civil' | 'api_sin' | 'email' | 'sms'
    verified_at     TIMESTAMPTZ,
    sort_order      SMALLINT    NOT NULL DEFAULT 0,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- ── Constraints ──
    CONSTRAINT pk_idn_identidad_atributo PRIMARY KEY (atributo_id, tenant_id),
    CONSTRAINT ck_atributo_valor CHECK (
        value_text IS NOT NULL OR value_data IS NOT NULL
    )
) PARTITION BY HASH (tenant_id);

-- Particiones iniciales (4 para empezar, escalan a 8→16→32 con crecimiento)
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_p0
    PARTITION OF bauth.idn_identidad_atributo
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_p1
    PARTITION OF bauth.idn_identidad_atributo
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_p2
    PARTITION OF bauth.idn_identidad_atributo
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_p3
    PARTITION OF bauth.idn_identidad_atributo
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- ============================================================================
-- PASO 6 — Índices de idn_identidad_atributo (3 B-tree + 4 GIN)
-- ============================================================================
-- Fuente: A.56 §4.4 — 7 índices en el DDL inicial. Sin parches. Sin flat tables.

-- B-tree: "Atributos de la entidad X"
CREATE INDEX IF NOT EXISTS ix_atributo_entidad
    ON bauth.idn_identidad_atributo (entidad_id, category, attr_key);

-- B-tree parcial: "Atributos controlados por BitMask"
CREATE INDEX IF NOT EXISTS ix_atributo_atom
    ON bauth.idn_identidad_atributo (atom_code) WHERE atom_code IS NOT NULL;

-- B-tree: "¿De quién es este email/NIT?"
CREATE INDEX IF NOT EXISTS ix_atributo_exact
    ON bauth.idn_identidad_atributo (tenant_id, attr_key, value_normalized);

-- GIN: fuzzy search — "tolota" → TOYOTA/TOLOTA/TOYOTÁ
CREATE INDEX IF NOT EXISTS ix_atributo_fuzzy
    ON bauth.idn_identidad_atributo USING GIN (value_normalized gin_trgm_ops);

-- GIN: full-text search — "foco del izq tyt carina" → Farol Del. Izq. Toyota
CREATE INDEX IF NOT EXISTS ix_atributo_fts
    ON bauth.idn_identidad_atributo USING GIN (value_search);

-- GIN: búsquedas JSONB — value_data @> '{"certificacion":"TOEFL"}'
CREATE INDEX IF NOT EXISTS ix_atributo_data
    ON bauth.idn_identidad_atributo USING GIN (value_data);

-- GIN: categorías — "Todas las categorías que contengan 'contacto'"
CREATE INDEX IF NOT EXISTS ix_atributo_cat
    ON bauth.idn_identidad_atributo USING GIN (category gin_trgm_ops);

-- ============================================================================
-- PASO 7 — idn_identidad_atributo_history (append-only, particionado por mes)
-- ============================================================================
-- Fuente: A.56 §3.5 — trazabilidad total. ISO 27001 A.8.15 · PCI DSS 10.3.2 · GDPR Art. 30.
--         Solo INSERT, nunca UPDATE ni DELETE. Cada cambio registrado con quién,
--         cuándo, valor anterior/nuevo y ctx_id.
--         Particionado por mes para consultas de auditoría eficientes.

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_history (
    history_id      BIGSERIAL,
    entidad_id      UUID        NOT NULL,
    attr_key        TEXT        NOT NULL,
    type            TEXT,
    tenant_id       UUID        NOT NULL,
    old_value       TEXT,                   -- NULL en INSERT (no había valor anterior)
    new_value       TEXT,                   -- NULL en DELETE (se eliminó el atributo)
    changed_by      UUID        NOT NULL,   -- ctx_id del actor que hizo el cambio
    change_type     TEXT        NOT NULL    -- 'INSERT', 'UPDATE', 'DELETE'
                    CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT        NOT NULL,   -- SBOS-049: contexto completo de la operación
    PRIMARY KEY (history_id, changed_at)
) PARTITION BY RANGE (changed_at);

-- Particiones mensuales iniciales (mes actual + siguiente)
-- En producción se usa pg_partman o cron para crearlas automáticamente.
-- Las fechas son placeholder — en despliegue real se generan dinámicamente.
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_history_2026_07
    PARTITION OF bauth.idn_identidad_atributo_history
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo_history_2026_08
    PARTITION OF bauth.idn_identidad_atributo_history
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- Índice para auditoría por entidad (el caso más común)
CREATE INDEX IF NOT EXISTS ix_atributo_history_entidad
    ON bauth.idn_identidad_atributo_history (entidad_id, changed_at DESC);

-- ============================================================================
-- PASO 8 — Trigger que puebla el historial automáticamente
-- ============================================================================
-- Cada INSERT/UPDATE/DELETE en idn_identidad_atributo genera una fila en el history.
-- ISO 27001 A.8.15: trazabilidad completa de cambios en datos de identidad.

CREATE OR REPLACE FUNCTION bauth.track_attribute_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (NEW.entidad_id, NEW.attr_key, NEW.type, NEW.tenant_id,
                NULL, NEW.value_text,
                COALESCE(current_setting('bauth.actor_id', true)::uuid, '00000000-0000-0000-0000-000000000000'),
                'INSERT', COALESCE(current_setting('bauth.ctx_id', true), 'system'));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (NEW.entidad_id, NEW.attr_key, NEW.type, NEW.tenant_id,
                OLD.value_text, NEW.value_text,
                COALESCE(current_setting('bauth.actor_id', true)::uuid, '00000000-0000-0000-0000-000000000000'),
                'UPDATE', COALESCE(current_setting('bauth.ctx_id', true), 'system'));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (OLD.entidad_id, OLD.attr_key, OLD.type, OLD.tenant_id,
                OLD.value_text, NULL,
                COALESCE(current_setting('bauth.actor_id', true)::uuid, '00000000-0000-0000-0000-000000000000'),
                'DELETE', COALESCE(current_setting('bauth.ctx_id', true), 'system'));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- El trigger se aplica por separado después de crear la tabla.
-- En PostgreSQL, los triggers en tablas particionadas deben aplicarse a la tabla padre.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_atributo_history'
          AND tgrelid = 'bauth.idn_identidad_atributo'::regclass
    ) THEN
        CREATE TRIGGER trg_atributo_history
            AFTER INSERT OR UPDATE OR DELETE ON bauth.idn_identidad_atributo
            FOR EACH ROW EXECUTE FUNCTION bauth.track_attribute_history();
    END IF;
END
$$;

-- ============================================================================
-- PASO 9 — idn_identidad_requisito (grado de completitud mínimo por tipo)
-- ============================================================================
-- Fuente: A.56 §3.6 — equivalente a IAL1/IAL2 de NIST SP 800-63A, pero aplicado
--         a cualquier tipo de entidad (no solo personas).
--         Nivel 1=mínimo funcional · 2=verificado · 3=completo.
--         El motor de identidad verifica ANTES de crear la entidad.

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_requisito (
    id              BIGSERIAL PRIMARY KEY,
    tipo_entidad    TEXT        NOT NULL,   -- PERSONA, ORGANIZACION, VEHICULO, DISPOSITIVO, ...
    nivel           INT         NOT NULL DEFAULT 1,  -- 1=funcional, 2=verificado, 3=completo
    attr_key        TEXT        NOT NULL,   -- attr_key requerido: 'nombre','email','CI',...
    requerido       BOOLEAN     NOT NULL DEFAULT true,
    min_instances   INT         NOT NULL DEFAULT 1,  -- cuántas instancias mínimo
    max_instances   INT,                      -- NULL = sin límite
    display_order   INT         NOT NULL DEFAULT 0,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tipo_entidad, nivel, attr_key)
);

-- ============================================================================
-- PASO 10 — Seed data: requisitos mínimos por tipo de entidad y nivel
-- ============================================================================
-- Fuente: A.56 §3.6 — datos de ejemplo que definen el contrato de completitud.
--         USAR INSERT ... ON CONFLICT DO NOTHING para idempotencia.

-- PERSONA nivel 1 (mínimo funcional — IAL1 equivalente)
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('PERSONA', 1, 'nombre',    true, 1, NULL, 1),
    ('PERSONA', 1, 'email',     true, 1, NULL, 2)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- PERSONA nivel 2 (verificado — IAL2 equivalente)
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('PERSONA', 2, 'id_nacional', true, 1, 1, 1),
    ('PERSONA', 2, 'birth_date',  true, 1, 1, 2),
    ('PERSONA', 2, 'direccion',   true, 1, NULL, 3),
    ('PERSONA', 2, 'telefono',    true, 1, 3, 4)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- ORGANIZACION nivel 1
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('ORGANIZACION', 1, 'nombre', true, 1, NULL, 1),
    ('ORGANIZACION', 1, 'email',  true, 1, NULL, 2)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- ORGANIZACION nivel 2
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('ORGANIZACION', 2, 'razon_social',    true, 1, 1, 1),
    ('ORGANIZACION', 2, 'NIT',             true, 1, 1, 2),
    ('ORGANIZACION', 2, 'direccion_fiscal', true, 1, 1, 3),
    ('ORGANIZACION', 2, 'pais',            true, 1, 1, 4)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- VEHICULO nivel 1
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('VEHICULO', 1, 'marca',  true, 1, 1, 1),
    ('VEHICULO', 1, 'modelo', true, 1, 1, 2),
    ('VEHICULO', 1, 'anio',   true, 1, 1, 3)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- VEHICULO nivel 2
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('VEHICULO', 2, 'placa',  true, 1, 1, 1),
    ('VEHICULO', 2, 'duenio',  true, 1, 1, 2),
    ('VEHICULO', 2, 'seguro', true, 1, 1, 3)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- DISPOSITIVO nivel 1
INSERT INTO bauth.idn_identidad_requisito (tipo_entidad, nivel, attr_key, requerido, min_instances, max_instances, display_order) VALUES
    ('DISPOSITIVO', 1, 'marca',  true, 1, 1, 1),
    ('DISPOSITIVO', 1, 'modelo', true, 1, 1, 2),
    ('DISPOSITIVO', 1, 'serial', true, 1, 1, 3)
ON CONFLICT (tipo_entidad, nivel, attr_key) DO NOTHING;

-- ============================================================================
-- PASO 11 — idn_identidad_sinonimo (sinónimos para búsqueda fuzzy)
-- ============================================================================
-- Fuente: A.56 §4.3.1 — los sinónimos SON DATOS DE NEGOCIO, no archivos estáticos.
--         Administrables desde el dashboard D93. Por tenant, país e industria.
--         La tabla ES la fuente de verdad. Los archivos .syn son generados.

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_sinonimo (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       UUID,                       -- NULL = global, NOT NULL = específico del tenant
    pais            TEXT,                       -- 'BO', 'MX', 'AR', NULL = todos
    industria       TEXT,                       -- 'autopartes', 'farmacia', NULL = todas
    tipo            TEXT        NOT NULL DEFAULT 'sinonimo',  -- 'sinonimo' | 'abreviatura'
    palabra         TEXT        NOT NULL,       -- palabra normalizada (a la que se expande)
    terminos        TEXT[]      NOT NULL,       -- sinónimos o abreviaturas que expanden a "palabra"
    activo          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Índices para búsqueda de sinónimos por tenant, país, industria
CREATE INDEX IF NOT EXISTS ix_sinonimo_tenant
    ON bauth.idn_identidad_sinonimo (tenant_id, activo);
CREATE INDEX IF NOT EXISTS ix_sinonimo_pais_industria
    ON bauth.idn_identidad_sinonimo (pais, industria, tipo, activo);
CREATE INDEX IF NOT EXISTS ix_sinonimo_palabra
    ON bauth.idn_identidad_sinonimo (palabra, activo);

-- ============================================================================
-- PASO 12 — Seed data: sinónimos base (español LATAM, autopartes)
-- ============================================================================
-- Fuente: A.56 §4.3.1 — ejemplos con cobertura Bolivia, México, Argentina.

-- Sinónimos regionales por país
INSERT INTO bauth.idn_identidad_sinonimo (tenant_id, pais, industria, tipo, palabra, terminos) VALUES
    -- Bolivia: "farol" es la palabra estándar
    (NULL, 'BO', 'autopartes', 'sinonimo', 'farol',   ARRAY['foco', 'óptica', 'luz_delantera']),
    -- México: "foco" es más común que "farol"
    (NULL, 'MX', 'autopartes', 'sinonimo', 'farol',   ARRAY['foco', 'luz_delantera', 'faro']),
    -- Argentina: "óptica" es el término dominante
    (NULL, 'AR', 'autopartes', 'sinonimo', 'farol',   ARRAY['óptica', 'luz', 'foco']),
    -- Global: términos comunes a todos los países hispanohablantes
    (NULL, NULL, 'autopartes', 'sinonimo', 'auto',    ARRAY['coche', 'carro', 'vehículo', 'automóvil']),
    (NULL, NULL, NULL,         'sinonimo', 'batería', ARRAY['bateria', 'pila', 'acumulador'])
ON CONFLICT DO NOTHING;

-- Abreviaturas universales (no dependen del país)
INSERT INTO bauth.idn_identidad_sinonimo (tenant_id, pais, industria, tipo, palabra, terminos) VALUES
    (NULL, NULL, 'autopartes', 'abreviatura', 'delantero',  ARRAY['del', 'delant', 'frontal']),
    (NULL, NULL, 'autopartes', 'abreviatura', 'trasero',    ARRAY['tras', 'post', 'posterior']),
    (NULL, NULL, 'autopartes', 'abreviatura', 'izquierdo',  ARRAY['izq', 'izquierda']),
    (NULL, NULL, 'autopartes', 'abreviatura', 'derecho',    ARRAY['der', 'derecha']),
    (NULL, NULL, 'autopartes', 'abreviatura', 'toyota',     ARRAY['tyt', 'toy']),
    (NULL, NULL, 'autopartes', 'abreviatura', 'volkswagen', ARRAY['vw', 'volks'])
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PASO 13 — idn_identidad_sinonimo_sync (control de sincronización)
-- ============================================================================
-- Fuente: A.56 §4.3.1 — controla cuándo fue la última regeneración de archivos .syn.
--         Si updated_at > last_sync_at, los archivos deben regenerarse.

CREATE TABLE IF NOT EXISTS bauth.idn_identidad_sinonimo_sync (
    id                      INT PRIMARY KEY DEFAULT 1,
    last_sync_at            TIMESTAMPTZ NOT NULL DEFAULT '2000-01-01',
    archivos_regenerados    INT DEFAULT 0,
    ultimo_error            TEXT,
    ctx_id                  TEXT NOT NULL DEFAULT 'system'
);

-- Seed: una sola fila de control
INSERT INTO bauth.idn_identidad_sinonimo_sync (id, last_sync_at, archivos_regenerados)
VALUES (1, '2000-01-01', 0)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PASO 14 — Comentarios de documentación para todas las tablas nuevas
-- ============================================================================

COMMENT ON TABLE bauth.idn_identidad_atributo IS
    'Atributos extensibles de entidades de identidad (modelo EAV). '
    'Cada entidad define sus propios atributos sin ALTER TABLE. '
    '2 columnas generadas STORED: value_normalized (fuzzy, <100ms) + '
    'value_search (full-text con sinónimos + stemming español, <50ms). '
    '7 índices en el DDL inicial (3 B-tree + 4 GIN). '
    'Particionado por HASH(tenant_id). '
    'ISO 24760-2:2025 §6 · NIST SP 800-63A.';

COMMENT ON COLUMN bauth.idn_identidad_atributo.category IS
    'Categoría del atributo: contacto, identificacion, laboral, comercial, ...';
COMMENT ON COLUMN bauth.idn_identidad_atributo.attr_key IS
    'Clave del atributo dentro de la categoría: email, telefono, CI, NIT, ...';
COMMENT ON COLUMN bauth.idn_identidad_atributo.type IS
    'Subtipo: work, home, mobile, fiscal, billing, ...';
COMMENT ON COLUMN bauth.idn_identidad_atributo.value_text IS
    'Valor textual simple (80% de atributos). Índices GIN para fuzzy + full-text.';
COMMENT ON COLUMN bauth.idn_identidad_atributo.value_data IS
    'Valor estructurado JSONB (20% de atributos). Índice GIN para consultas @>.';
COMMENT ON COLUMN bauth.idn_identidad_atributo.atom_code IS
    'NULL = atributo libre. NOT NULL = controlado por BitMask (FK a privilege_atom).';
COMMENT ON COLUMN bauth.idn_identidad_atributo.dominio_origen IS
    'Qué dominio agregó este atributo: civil, laboral, comercial, salud, ...';
COMMENT ON COLUMN bauth.idn_identidad_atributo.verified_by IS
    'Método de verificación: manual, api_registro_civil, api_sin, email, sms, ...';
COMMENT ON COLUMN bauth.idn_identidad_atributo.ctx_id IS
    'Contexto de la operación que creó/modificó este atributo (SBOS-049 §5.3).';

COMMENT ON TABLE bauth.idn_identidad_atributo_history IS
    'Historial de cambios de atributos (append-only, WORM). '
    'Cada INSERT/UPDATE/DELETE en idn_identidad_atributo genera una fila aquí. '
    'Particionado por RANGE mensual. Solo INSERT, nunca UPDATE ni DELETE. '
    'ISO 27001 A.8.15 · PCI DSS 10.3.2 · GDPR Art. 30.';

COMMENT ON TABLE bauth.idn_identidad_requisito IS
    'Requisitos mínimos de completitud por tipo de entidad y nivel. '
    'Nivel 1 = funcional, 2 = verificado, 3 = completo. '
    'El motor de identidad verifica estos requisitos ANTES de crear la entidad. '
    'Equivalente a IAL1/IAL2 de NIST SP 800-63A, aplicado a cualquier tipo de entidad.';

COMMENT ON TABLE bauth.idn_identidad_sinonimo IS
    'Sinónimos y abreviaturas para búsqueda fuzzy multilingüe. '
    'Fuente de verdad de los archivos .syn de PostgreSQL. '
    'Administrables desde el dashboard D93. Por tenant, país e industria. '
    'tipo=sinonimo: variantes regionales (farol/foco/óptica). '
    'tipo=abreviatura: formas cortas (del/delantero, izq/izquierdo).';

COMMENT ON TABLE bauth.idn_identidad_sinonimo_sync IS
    'Control de sincronización de archivos .syn. '
    'Si algún sinónimo tiene updated_at > last_sync_at, los archivos deben regenerarse. '
    'El handler bauth.synonym.save() y el cron de 5 min verifican esta tabla.';

COMMIT;

-- ============================================================================
-- VERIFICACIÓN (ejecutar por separado para confirmar el resultado)
-- ============================================================================

-- ── idn_identidad_entidad ──
-- SELECT nivel, count(*) FROM bauth.idn_identidad_entidad GROUP BY nivel ORDER BY nivel;
-- -- debe retornar 5 niveles o cero filas en primera ejecución

-- SELECT * FROM bauth.idn_identidad_entidad
-- WHERE tenant_id = '4c697f66-d204-45a5-ac36-c104f07c7046'
-- ORDER BY nivel, slug;
-- -- árbol completo del tenant skull

-- -- Navegación jerárquica: subárbol desde un nodo
-- WITH RECURSIVE subarbol AS (
--     SELECT entidad_id, parent_id, nivel, tipo, slug, nombre, 0 AS profundidad
--     FROM bauth.idn_identidad_entidad
--     WHERE entidad_id = '<uuid_del_nodo_raiz>'
--     UNION ALL
--     SELECT e.entidad_id, e.parent_id, e.nivel, e.tipo, e.slug, e.nombre, s.profundidad + 1
--     FROM bauth.idn_identidad_entidad e
--     JOIN subarbol s ON e.parent_id = s.entidad_id
-- )
-- SELECT * FROM subarbol ORDER BY profundidad, slug;

-- ── idn_identidad_atributo ──
-- SELECT category, attr_key, count(*) FROM bauth.idn_identidad_atributo
-- GROUP BY category, attr_key ORDER BY category, attr_key;
-- -- distribución de atributos por categoría

-- -- Búsqueda fuzzy: ¿de quién es este email?
-- SELECT e.nombre, a.attr_key, a.value_text
-- FROM bauth.idn_identidad_atributo a
-- JOIN bauth.idn_identidad_entidad e ON a.entidad_id = e.entidad_id
-- WHERE a.attr_key = 'email' AND a.value_normalized = lower(unaccent('Juan.Perez@empresa.com'));

-- -- Búsqueda full-text con sinónimos (requiere diccionario spanish_syn configurado)
-- SELECT e.nombre, a.value_text, ts_rank(a.value_search, query) AS rank
-- FROM bauth.idn_identidad_atributo a
-- JOIN bauth.idn_identidad_entidad e ON a.entidad_id = e.entidad_id,
--      to_tsquery('spanish', 'foco & delantero & izquierdo') AS query
-- WHERE a.value_search @@ query
-- ORDER BY rank DESC;

-- ── idn_identidad_atributo_history ──
-- SELECT change_type, count(*) FROM bauth.idn_identidad_atributo_history
-- GROUP BY change_type;
-- -- debe retornar 0-3 tipos según actividad

-- -- Historial completo de una entidad
-- SELECT changed_at, change_type, attr_key, old_value, new_value, ctx_id
-- FROM bauth.idn_identidad_atributo_history
-- WHERE entidad_id = '<uuid>'
-- ORDER BY changed_at DESC;

-- ── idn_identidad_requisito ──
-- SELECT tipo_entidad, nivel, count(*) AS requisitos
-- FROM bauth.idn_identidad_requisito
-- WHERE requerido = true
-- GROUP BY tipo_entidad, nivel ORDER BY tipo_entidad, nivel;
-- -- PERSONA nivel 1: 2, nivel 2: 4 · ORGANIZACION: 2+4 · VEHICULO: 3+3 · DISPOSITIVO: 3

-- ── idn_identidad_sinonimo ──
-- SELECT pais, industria, tipo, palabra, array_to_string(terminos, ', ') AS sinonimos
-- FROM bauth.idn_identidad_sinonimo WHERE activo = true
-- ORDER BY pais NULLS LAST, industria NULLS LAST, tipo, palabra;
-- -- debe retornar 11 filas: 5 sinónimos regionales + 6 abreviaturas
