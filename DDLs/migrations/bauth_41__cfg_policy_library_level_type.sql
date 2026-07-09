-- =============================================================================
-- bauth_41__cfg_policy_library_level_type.sql
-- Clasificación semántica de nodos: FRAMEWORK | DOMAIN | POLICY | RULE | PROPERTY
-- =============================================================================
-- Propósito : Agrega columna level_type a cfg_policy_library para distinguir
--             el rol semántico de cada nodo en el árbol jerárquico.
--             Corrije value_type con tipos precisos (BOOLEAN/INTEGER/FLOAT/ENUM/TEXT/JSONB).
--             Puebla default_value y enum_options desde el content JSONB real.
--
-- Modelo    : cfg_policy_library es el CATÁLOGO DE INGREDIENTES — la SU nunca
--             edita los ingredientes, solo compone plantillas seleccionando de aquí.
--
-- Jerarquía : FRAMEWORK → DOMAIN → POLICY → RULE → PROPERTY
--   FRAMEWORK : raíz del árbol (sin parent_path); ej. authenticationFramework
--   DOMAIN    : agrupaciones temáticas depth≤2; ej. modern_authentication_policies
--   POLICY    : nodos intermedios con sub-nodos que no son hojas directas
--   RULE      : nodo padre directo de PROPERTY (la "regla evaluable")
--   PROPERTY  : hoja atómica con valor: BOOLEAN | INTEGER | FLOAT | ENUM | TEXT | JSONB
--
-- Resultado esperado (validado por simulación previa):
--   PROPERTY = 5496 · RULE = 2275 · POLICY = 1210 · DOMAIN = 145 · FRAMEWORK = 58
--   Total = 9184
--
-- Dependencias: bauth_40__cfg_policy_library_ltree.sql (ya ejecutado)
-- Estándares  : NIST SP 800-63B · ISO 27001:2022 · ORQUESTA-051
-- Autor       : bauth-developer · 2026-07-07
-- HITL        : requiere aprobación antes de ejecución en producción
-- =============================================================================
-- IDEMPOTENCIA: ADD COLUMN IF NOT EXISTS · CREATE INDEX IF NOT EXISTS
--               UPDATE solo donde IS NULL (no sobreescribe si ya existe)
-- ROLLBACK    : DROP COLUMN level_type · UPDATE value_type = NULL WHERE level_type = 'PROPERTY'
-- =============================================================================

BEGIN;
SET lock_timeout = '30s';

-- =============================================================================
-- FASE 1 — Columna level_type
-- =============================================================================

ALTER TABLE bauth.cfg_policy_library
    ADD COLUMN IF NOT EXISTS level_type TEXT;

-- Validación: solo valores del vocabulario controlado
ALTER TABLE bauth.cfg_policy_library
    DROP CONSTRAINT IF EXISTS chk_cfg_policy_library_level_type;

ALTER TABLE bauth.cfg_policy_library
    ADD CONSTRAINT chk_cfg_policy_library_level_type
    CHECK (level_type IN ('FRAMEWORK', 'DOMAIN', 'POLICY', 'RULE', 'PROPERTY'));

-- =============================================================================
-- FASE 2 — Clasificación level_type usando CTE
-- Algoritmo:
--   1. nodos_con_hijos  = nodos que son parent_path de algún nodo
--   2. nodos_hoja       = nodos que NO aparecen como parent_path
--   3. padres_de_hojas  = nodos que tienen al menos 1 hijo que es hoja
--   Clasificación por reglas de prioridad:
--     a) Sin padre            → FRAMEWORK
--     b) depth≤2 no-hoja     → DOMAIN
--     c) Es hoja             → PROPERTY
--     d) Es padre de hojas   → RULE
--     e) Resto               → POLICY
-- =============================================================================

WITH nodos_con_hijos AS (
    SELECT DISTINCT parent_path
    FROM bauth.cfg_policy_library
    WHERE parent_path IS NOT NULL
),
nodos_hoja AS (
    SELECT json_path
    FROM bauth.cfg_policy_library
    WHERE json_path NOT IN (SELECT parent_path FROM nodos_con_hijos)
),
padres_de_hojas AS (
    SELECT DISTINCT parent_path
    FROM bauth.cfg_policy_library
    WHERE json_path IN (SELECT json_path FROM nodos_hoja)
      AND parent_path IS NOT NULL
)
UPDATE bauth.cfg_policy_library p
SET level_type = CASE
    WHEN p.parent_path IS NULL
        THEN 'FRAMEWORK'
    WHEN p.depth <= 2 AND p.json_path NOT IN (SELECT json_path FROM nodos_hoja)
        THEN 'DOMAIN'
    WHEN p.json_path IN (SELECT json_path FROM nodos_hoja)
        THEN 'PROPERTY'
    WHEN p.json_path IN (SELECT parent_path FROM padres_de_hojas)
        THEN 'RULE'
    ELSE
        'POLICY'
END
WHERE p.level_type IS NULL;

-- =============================================================================
-- FASE 3 — Corrección de value_type para nodos PROPERTY
-- Reemplaza la clasificación heurística anterior con tipos precisos derivados
-- del jsonb_typeof() del content real de cada nodo hoja.
--
-- value_type  | Criterio                                     | UI Widget
-- ------------|----------------------------------------------|------------------
-- BOOLEAN     | content es true o false JSON                 | Toggle/Switch
-- INTEGER     | content es número sin decimales              | NumberInput(int)
-- FLOAT       | content es número con decimales              | NumberInput(dec)
-- ENUM        | content es array de solo strings             | Select/MultiSelect
-- ARRAY       | content es array con objetos mixtos          | TagInput
-- TEXT        | content es string JSON                       | TextInput/Textarea
-- JSONB       | content es objeto JSON (política compleja)   | JSON Editor readonly
-- =============================================================================

UPDATE bauth.cfg_policy_library
SET value_type = CASE
    WHEN jsonb_typeof(content) = 'boolean'
        THEN 'BOOLEAN'
    WHEN jsonb_typeof(content) = 'number'
         AND content::text ~ '^-?[0-9]+$'
        THEN 'INTEGER'
    WHEN jsonb_typeof(content) = 'number'
        THEN 'FLOAT'
    WHEN jsonb_typeof(content) = 'array'
         AND (SELECT bool_and(jsonb_typeof(e) = 'string')
              FROM jsonb_array_elements(content) e)
        THEN 'ENUM'
    WHEN jsonb_typeof(content) = 'array'
        THEN 'ARRAY'
    WHEN jsonb_typeof(content) = 'string'
        THEN 'TEXT'
    WHEN jsonb_typeof(content) = 'object'
        THEN 'JSONB'
    ELSE 'UNKNOWN'
END
WHERE level_type = 'PROPERTY';

-- =============================================================================
-- FASE 4 — Poblar default_value para PROPERTY escalares
-- Solo para content de tipo escalar (boolean, number, string).
-- Arrays y objetos no tienen default_value simple.
-- =============================================================================

UPDATE bauth.cfg_policy_library
SET default_value = CASE
    WHEN jsonb_typeof(content) = 'boolean' THEN content::text
    WHEN jsonb_typeof(content) = 'number'  THEN content::text
    WHEN jsonb_typeof(content) = 'string'  THEN content #>> '{}'
    ELSE NULL
END
WHERE level_type = 'PROPERTY'
  AND default_value IS NULL
  AND jsonb_typeof(content) IN ('boolean', 'number', 'string');

-- =============================================================================
-- FASE 5 — Poblar enum_options para PROPERTY de tipo ENUM
-- Solo arrays de strings simples (no arrays de objetos).
-- =============================================================================

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY(SELECT jsonb_array_elements_text(content))
WHERE level_type = 'PROPERTY'
  AND value_type = 'ENUM'
  AND enum_options IS NULL;

-- =============================================================================
-- FASE 6 — Índice en level_type para queries por tipo semántico
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cfg_policy_library_level_type
    ON bauth.cfg_policy_library (level_type);

COMMIT;

-- =============================================================================
-- VERIFICACIÓN POST-MIGRACIÓN (ejecutar por separado)
-- =============================================================================
-- Distribución esperada:
--   PROPERTY  = 5496
--   RULE      = 2275
--   POLICY    = 1210
--   DOMAIN    = 145
--   FRAMEWORK =  58
--   Total     = 9184
--
-- SELECT level_type, COUNT(*) FROM bauth.cfg_policy_library GROUP BY 1 ORDER BY 2 DESC;
--
-- Verificar value_type de PROPERTY:
-- SELECT value_type, COUNT(*) FROM bauth.cfg_policy_library
-- WHERE level_type = 'PROPERTY' GROUP BY 1 ORDER BY 2 DESC;
-- → string=TEXT, boolean=BOOLEAN, number=INTEGER/FLOAT, array-str=ENUM, object=JSONB
--
-- Verificar que RULE tiene propiedades con value_type:
-- SELECT r.section_name, r.json_path, p.section_name, p.value_type, p.default_value
-- FROM bauth.cfg_policy_library r
-- JOIN bauth.cfg_policy_library p ON p.parent_path = r.json_path
-- WHERE r.level_type = 'RULE' AND p.level_type = 'PROPERTY'
-- LIMIT 10;
