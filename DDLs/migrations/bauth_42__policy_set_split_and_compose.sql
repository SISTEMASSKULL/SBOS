-- =============================================================================
-- bauth_42__policy_set_split_and_compose.sql
-- 1. Reclasificación POLICY → POLICY_SET | POLICY  (alineación XACML 3.0)
-- 2. Función bauth.fn_compose_tree()   — árbol → JSONB anidado
-- 3. Función bauth.fn_decompose_tree() — JSONB anidado → filas de la tabla
-- =============================================================================
-- Propósito : Alinear la jerarquía con XACML 3.0 (OASIS):
--
--   FRAMEWORK  → raíz del árbol (sin parent)
--   DOMAIN     → agrupación temática (depth ≤ 2)
--   POLICY_SET → contiene sub-PolicySets o Policies (no contiene Rules directas)
--   POLICY     → contiene solo Rules (política hoja evaluable)
--   RULE       → regla atómica evaluable: condition + effect
--   PROPERTY   → atributo atómico: tipo + valor + enum_options
--
--   POLICY_SET = 651 nodos (agrupadores)
--   POLICY     = 559 nodos (evaluables — sus hijos directos son RULE)
--
-- Composición : bauth.fn_compose_tree(raiz_path ltree)
--   Entrada  : path ltree de cualquier nodo (DOMAIN, POLICY_SET, POLICY, RULE)
--   Salida   : JSONB anidado completo del subárbol
--   Uso      : presentación, exportación, verificación, diff contra el JSON original
--
-- Descomposición : bauth.fn_decompose_tree(jsonb_arbol jsonb, parent ltree)
--   Entrada  : JSONB anidado + path del padre
--   Salida   : filas insertadas / actualizadas en cfg_policy_library
--   Uso      : importar nuevas políticas o actualizar la biblioteca
--
-- Estándares : XACML 3.0 (OASIS) · NIST SP 800-162 · ISO 27001:2022
-- Autor      : bauth-developer · 2026-07-07
-- HITL       : aprobado
-- =============================================================================

BEGIN;
SET lock_timeout = '30s';

-- =============================================================================
-- FASE 1 — Ampliar el CHECK constraint para incluir los nuevos valores
-- =============================================================================

ALTER TABLE bauth.cfg_policy_library
    DROP CONSTRAINT IF EXISTS chk_cfg_policy_library_level_type;

ALTER TABLE bauth.cfg_policy_library
    ADD CONSTRAINT chk_cfg_policy_library_level_type
    CHECK (level_type IN (
        'FRAMEWORK', 'DOMAIN', 'POLICY_SET', 'POLICY', 'RULE', 'PROPERTY'
    ));

-- =============================================================================
-- FASE 2 — Reclasificación POLICY → POLICY_SET | POLICY
--
-- Criterio XACML:
--   POLICY_SET = tiene al menos 1 hijo directo con level_type = 'POLICY'
--   POLICY     = todos sus hijos directos son RULE (no tiene sub-políticas)
-- =============================================================================

UPDATE bauth.cfg_policy_library p
SET level_type = 'POLICY_SET'
WHERE p.level_type = 'POLICY'
  AND EXISTS (
      SELECT 1
      FROM bauth.cfg_policy_library hijo
      WHERE hijo.parent_path = p.json_path
        AND hijo.level_type = 'POLICY'
  );

-- Los que quedaron como 'POLICY' ya son correctos (sus hijos son RULE)

-- =============================================================================
-- FASE 3 — Función bauth.fn_compose_tree(raiz_path ltree)
--
-- Recorre el subárbol en DFS y construye un JSONB anidado con la forma:
--
-- {
--   "_meta": { "level_type": "POLICY_SET", "source": "...", "standard_ref": "..." },
--   "authenticator_policies": {
--     "_meta": { "level_type": "POLICY" },
--     "platform_authenticator": {
--       "_meta": { "level_type": "RULE" },
--       "enabled":             { "_type": "BOOLEAN", "_value": "true" },
--       "minimum_key_size":    { "_type": "INTEGER", "_value": "256"  }
--     }
--   }
-- }
--
-- Nodos PROPERTY con value_type ARRAY se representan como array JSON:
--   "format_preferences": ["packed", "tpm", "android-key"]
--
-- Parámetros:
--   raiz_path  ltree  — path ltree del nodo raíz del subárbol
--   max_depth  int    — profundidad máxima a expandir (NULL = ilimitado)
-- =============================================================================

CREATE OR REPLACE FUNCTION bauth.fn_compose_tree(
    raiz_path  ltree,
    max_depth  int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    resultado    jsonb;
    nodo_raiz    bauth.cfg_policy_library%ROWTYPE;
BEGIN
    SELECT * INTO nodo_raiz
    FROM bauth.cfg_policy_library
    WHERE path = raiz_path;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'nodo no encontrado: ' || raiz_path::text);
    END IF;

    resultado := bauth._fn_compose_nodo(nodo_raiz, max_depth);
    RETURN resultado;
END;
$$;

-- Función auxiliar recursiva (privada, prefijo _)
CREATE OR REPLACE FUNCTION bauth._fn_compose_nodo(
    nodo      bauth.cfg_policy_library,
    max_depth int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    hijo        bauth.cfg_policy_library%ROWTYPE;
    resultado   jsonb := '{}'::jsonb;
    meta        jsonb;
    hijos_count int;
BEGIN
    -- Metadata del nodo actual
    meta := jsonb_strip_nulls(jsonb_build_object(
        'level_type',   nodo.level_type,
        'source',       nodo.source,
        'standard_ref', nodo.standard_ref,
        'risk_level',   nodo.risk_level,
        'is_required',  CASE WHEN nodo.is_required THEN true ELSE NULL END
    ));

    resultado := jsonb_build_object('_meta', meta);

    -- Verificar límite de profundidad
    IF max_depth IS NOT NULL AND nodo.depth >= max_depth THEN
        RETURN resultado || jsonb_build_object('_truncated', true);
    END IF;

    -- Contar hijos directos
    SELECT COUNT(*) INTO hijos_count
    FROM bauth.cfg_policy_library
    WHERE parent_path = nodo.json_path;

    -- Nodo hoja (PROPERTY sin hijos)
    IF hijos_count = 0 THEN
        resultado := resultado || jsonb_build_object(
            '_type',    nodo.value_type,
            '_value',   nodo.default_value,
            '_options', CASE WHEN nodo.enum_options IS NOT NULL
                             THEN to_jsonb(nodo.enum_options)
                             ELSE NULL
                        END
        );
        RETURN jsonb_strip_nulls(resultado);
    END IF;

    -- Nodo RULE con content array (lista de opciones enumeradas)
    IF nodo.level_type = 'RULE' AND nodo.value_type = 'ARRAY' THEN
        resultado := resultado || jsonb_build_object(
            '_type',    'ENUM',
            '_options', nodo.content
        );
    END IF;

    -- Expandir hijos recursivamente
    FOR hijo IN
        SELECT *
        FROM bauth.cfg_policy_library
        WHERE parent_path = nodo.json_path
        ORDER BY path
    LOOP
        resultado := resultado || jsonb_build_object(
            hijo.section_name,
            bauth._fn_compose_nodo(hijo, max_depth)
        );
    END LOOP;

    RETURN resultado;
END;
$$;

-- =============================================================================
-- FASE 4 — Función bauth.fn_decompose_tree(jsonb_arbol jsonb, raiz_path ltree)
--
-- Recibe un JSONB anidado (generado por fn_compose_tree o importado externamente)
-- y hace UPSERT en cfg_policy_library para cada nodo del árbol.
--
-- Uso principal: importar nuevas políticas o actualizar valores en la biblioteca.
-- El SU NO usa esta función directamente — solo SKULL / migraciones.
--
-- Parámetros:
--   jsonb_arbol  jsonb  — árbol JSONB anidado
--   raiz_path    ltree  — path del nodo padre donde se injerta el árbol
--   fuente       text   — identificador de la fuente (ej. 'Authentication_Framework_v3')
-- =============================================================================

CREATE OR REPLACE FUNCTION bauth.fn_decompose_tree(
    jsonb_arbol  jsonb,
    raiz_path    ltree,
    fuente       text DEFAULT 'manual'
)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    clave        text;
    valor        jsonb;
    nodo_path    ltree;
    nodo_meta    jsonb;
    contador     int := 0;
    ltree_label  text;
BEGIN
    FOR clave, valor IN SELECT * FROM jsonb_each(jsonb_arbol)
    LOOP
        -- Ignorar claves internas (_meta, _type, _value, _options, _truncated)
        CONTINUE WHEN clave LIKE '\_%';

        -- Normalizar el nombre a label ltree válido
        ltree_label := REGEXP_REPLACE(
                           REGEXP_REPLACE(
                               REGEXP_REPLACE(
                                   REGEXP_REPLACE(clave, '\[([0-9]+)\]', '_\1', 'g'),
                               ':', '_', 'g'),
                           '/', '_', 'g'),
                       '-', '_', 'g');

        nodo_path := raiz_path || ltree_label::ltree;
        nodo_meta := COALESCE(valor -> '_meta', '{}'::jsonb);

        -- UPSERT del nodo
        INSERT INTO bauth.cfg_policy_library (
            section_name, parent_path, json_path, path,
            depth, node_type, level_type,
            value_type, default_value, enum_options,
            source, standard_ref, is_required,
            content, order_index
        )
        VALUES (
            clave,
            raiz_path::text,
            REPLACE(nodo_path::text, '.', '.'),
            nodo_path,
            nlevel(nodo_path),
            COALESCE((nodo_meta->>'level_type'), 'config'),
            nodo_meta->>'level_type',
            valor->>'_type',
            valor->>'_value',
            CASE WHEN valor ? '_options' AND jsonb_typeof(valor->'_options') = 'array'
                 THEN ARRAY(SELECT jsonb_array_elements_text(valor->'_options'))
                 ELSE NULL
            END,
            fuente,
            nodo_meta->>'standard_ref',
            COALESCE((nodo_meta->>'is_required')::boolean, false),
            CASE WHEN valor ? '_value' THEN to_jsonb(valor->>'_value')
                 WHEN valor ? '_options' THEN valor->'_options'
                 ELSE NULL
            END,
            1
        )
        ON CONFLICT (path) DO UPDATE SET
            value_type    = EXCLUDED.value_type,
            default_value = EXCLUDED.default_value,
            enum_options  = EXCLUDED.enum_options,
            level_type    = COALESCE(EXCLUDED.level_type, bauth.cfg_policy_library.level_type),
            standard_ref  = COALESCE(EXCLUDED.standard_ref, bauth.cfg_policy_library.standard_ref);

        contador := contador + 1;

        -- Recursión en sub-nodos (si el valor es un objeto con claves no-privadas)
        IF jsonb_typeof(valor) = 'object'
           AND EXISTS (
               SELECT 1 FROM jsonb_object_keys(valor) k WHERE k NOT LIKE '\_%'
           )
        THEN
            contador := contador + bauth.fn_decompose_tree(valor, nodo_path, fuente);
        END IF;
    END LOOP;

    RETURN contador;
END;
$$;

-- =============================================================================
-- FASE 5 — Vista de navegación del árbol (lectura rápida sin JSONB)
-- =============================================================================

CREATE OR REPLACE VIEW bauth.v_policy_tree AS
SELECT
    repeat('  ', depth - 1) || section_name   AS nodo,
    level_type,
    value_type,
    default_value,
    enum_options,
    standard_ref,
    risk_level,
    depth,
    path
FROM bauth.cfg_policy_library
ORDER BY path;

COMMENT ON VIEW bauth.v_policy_tree IS
    'Vista de navegación del árbol de políticas. ORDER BY path preserva el orden DFS (padre → hijos).';

COMMIT;

-- =============================================================================
-- EJEMPLOS DE USO (ejecutar fuera de transacción)
-- =============================================================================
--
-- 1. Ver árbol completo como JSONB (subárbol webauthn_fido2):
--    SELECT bauth.fn_compose_tree(
--        'policiesAuthenticationFramework.PoliciesAuthenticationFramework.modern_authentication_policies.webauthn_fido2'
--    );
--
-- 2. Ver árbol solo hasta profundidad 7 (sin las hojas más profundas):
--    SELECT bauth.fn_compose_tree(
--        'policiesAuthenticationFramework.PoliciesAuthenticationFramework.modern_authentication_policies',
--        7
--    );
--
-- 3. Ver la vista de navegación de un dominio:
--    SELECT * FROM bauth.v_policy_tree
--    WHERE path <@ 'policiesAuthenticationFramework.PoliciesAuthenticationFramework.modern_authentication_policies'
--    LIMIT 50;
--
-- 4. Verificar distribución post-migración:
--    SELECT level_type, COUNT(*)
--    FROM bauth.cfg_policy_library
--    GROUP BY level_type
--    ORDER BY ARRAY_POSITION(
--        ARRAY['FRAMEWORK','DOMAIN','POLICY_SET','POLICY','RULE','PROPERTY'],
--        level_type
--    );
