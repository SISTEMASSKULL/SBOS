-- =============================================================================
-- bauth_40__cfg_policy_library_ltree.sql
-- Migración: cfg_policy_library → árbol ltree + columnas operacionales
-- =============================================================================
-- Propósito : Convierte cfg_policy_library en el catálogo de ingredientes
--             canónico de bAuth. Agrega columna ltree para navegación jerárquica
--             nativa y columnas que permiten al SU componer RolTemplate y
--             UserTemplate seleccionando valores válidos (enum_options) sin
--             salirse de los estándares internacionales.
--
-- Jerarquía : dominio → política/config → rule → propiedad → valor + enum + norma
--
-- Modelo    : cfg_policy_library = ingredientes (INMUTABLE para SU)
--             bos_rol_template   = receta del rol (compuesta desde la biblioteca)
--             idn_user_template  = receta del usuario (ídem)
--
-- Estándares: NIST SP 800-63B · ISO 27001:2022 · PCI DSS 4.0 · ANSI/INCITS 359
-- Norma SBOS: SBOS-050 (puertos) · ADR-020 (Interface Dual) · ORQUESTA-051
-- Autor     : bauth-developer · 2026-07-07
-- HITL      : aprobado por Iván antes de ejecución
-- =============================================================================
-- IDEMPOTENCIA: ADD COLUMN IF NOT EXISTS + CREATE INDEX IF NOT EXISTS
-- ROLLBACK    : DROP COLUMN + DROP INDEX (reversible)
-- =============================================================================

BEGIN;
SET lock_timeout = '30s';

-- =============================================================================
-- FASE 1 — Extensión ltree
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS ltree;

-- =============================================================================
-- FASE 2 — Columna path ltree
-- Normalización de json_path → ltree:
--   [N]  → _N     (índices de array: algorithms[3] → algorithms_3)
--   :    → _      (DID methods: did:ion → did_ion)
--   /    → _      (slashes varios)
--   -    → _      (guiones: -chat-send → _chat_send)
-- =============================================================================

ALTER TABLE bauth.cfg_policy_library
    ADD COLUMN IF NOT EXISTS path ltree;

UPDATE bauth.cfg_policy_library
SET path = (
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(json_path, '\[([0-9]+)\]', '_\1', 'g'),
            ':', '_', 'g'),
        '/', '_', 'g'),
    '-', '_', 'g')
)::ltree
WHERE path IS NULL;

ALTER TABLE bauth.cfg_policy_library
    ALTER COLUMN path SET NOT NULL;

-- Unicidad garantizada (verificada pre-migración: 0 colisiones)
ALTER TABLE bauth.cfg_policy_library
    DROP CONSTRAINT IF EXISTS cfg_policy_library_path_unique;

ALTER TABLE bauth.cfg_policy_library
    ADD CONSTRAINT cfg_policy_library_path_unique UNIQUE (path);

-- =============================================================================
-- FASE 3 — Columnas operacionales del catálogo de ingredientes
-- =============================================================================

ALTER TABLE bauth.cfg_policy_library
    -- Cómo renderizar el campo en UI y cómo validar el valor
    ADD COLUMN IF NOT EXISTS value_type      TEXT,
    -- INTEGER | BOOLEAN | ENUM | TEXT | ARRAY | JSONB

    -- Opciones válidas para nodos ENUM — el SU solo puede elegir de aquí
    ADD COLUMN IF NOT EXISTS enum_options    TEXT[],

    -- Valor por defecto recomendado por la norma
    ADD COLUMN IF NOT EXISTS default_value   TEXT,

    -- Límites para tipos numéricos (INTEGER)
    ADD COLUMN IF NOT EXISTS constraint_min  TEXT,
    ADD COLUMN IF NOT EXISTS constraint_max  TEXT,

    -- Si true, el template NO puede omitir esta propiedad
    ADD COLUMN IF NOT EXISTS is_required     BOOLEAN NOT NULL DEFAULT false;

-- =============================================================================
-- FASE 4 — Índices
-- GiST  en path    → subtree queries: WHERE path <@ 'D3'  (< 1ms)
-- BTREE en depth   → queries por nivel: WHERE depth = 9
-- GIN   en domain_map → queries por dominio: WHERE domain_map @> '{D3}'
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cfg_policy_library_path_gist
    ON bauth.cfg_policy_library USING GIST (path);

CREATE INDEX IF NOT EXISTS idx_cfg_policy_library_depth
    ON bauth.cfg_policy_library (depth);

CREATE INDEX IF NOT EXISTS idx_cfg_policy_library_domain_map_gin
    ON bauth.cfg_policy_library USING GIN (domain_map);

CREATE INDEX IF NOT EXISTS idx_cfg_policy_library_node_type
    ON bauth.cfg_policy_library (node_type, semantic_type);

-- =============================================================================
-- FASE 5 — Seed inicial de value_type para nodos hoja conocidos
-- Clasifica los nodos de profundidad máxima según su semantic_type y contenido
-- =============================================================================

-- Nodos de tipo config con contenido JSONB complejo → JSONB
UPDATE bauth.cfg_policy_library
SET value_type = 'JSONB'
WHERE node_type = 'config'
  AND semantic_type IN ('guideline', 'standard')
  AND value_type IS NULL;

-- Nodos policy con content que tiene campos boolean → BOOLEAN
UPDATE bauth.cfg_policy_library
SET value_type = 'BOOLEAN'
WHERE node_type IN ('config', 'policy')
  AND (content::text ILIKE '%"enabled"%' OR content::text ILIKE '%"required"%'
       OR content::text ILIKE '%"allowed"%')
  AND jsonb_typeof(content) = 'object'
  AND (content ? 'value' AND jsonb_typeof(content->'value') = 'boolean')
  AND value_type IS NULL;

-- Nodos con contenido que es array de strings → ENUM candidates
UPDATE bauth.cfg_policy_library
SET value_type = 'ARRAY',
    enum_options = ARRAY(SELECT jsonb_array_elements_text(content))
WHERE node_type IN ('config', 'policy')
  AND jsonb_typeof(content) = 'array'
  AND value_type IS NULL;

-- Resto de nodos hoja → TEXT por defecto (se refinarán en seed siguiente)
UPDATE bauth.cfg_policy_library
SET value_type = 'TEXT'
WHERE value_type IS NULL
  AND node_type IN ('config', 'policy');

COMMIT;

-- =============================================================================
-- VERIFICACIÓN POST-MIGRACIÓN (ejecutar por separado, sin transacción)
-- =============================================================================
-- SELECT COUNT(*) FROM bauth.cfg_policy_library WHERE path IS NULL;
--   → debe ser 0
--
-- SELECT COUNT(*) FROM bauth.cfg_policy_library;
--   → debe ser 9184
--
-- SELECT * FROM bauth.cfg_policy_library
--   WHERE path <@ 'authenticationFramework' LIMIT 5;
--   → debe devolver nodos del árbol authenticationFramework
--
-- SELECT path, value_type, enum_options
--   FROM bauth.cfg_policy_library
--   WHERE node_type = 'config' AND enum_options IS NOT NULL
--   LIMIT 5;
--   → debe mostrar nodos con sus opciones
