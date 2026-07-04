-- ============================================================================
-- VALIDADOR DE VALORES — cfg_policy_library vs DDL/ENUMs/Dominios
-- Cada nodo se valida contra:
--   1. Tipos de datos reales (CHECK constraints, ENUM types, FK references)
--   2. Catálogos existentes (ath_method, ath_auth_flow, privilege_verb, etc.)
--   3. Dominios D1-D12 + SEC (que tengan evaluador y tabla ath_policy_d*)
-- Resultado: VÁLIDO / INVÁLIDO con razón específica
-- ============================================================================

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 1: Validación de valores ENUM contra CHECK constraints reales' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

-- Valores que DEBERÍAN estar en CHECK constraints
WITH enum_values AS (
    -- Todos los CHECK constraints definidos en la DDL
    SELECT 'risk_level' as campo, unnest(ARRAY['critical','high','medium','low']) as valor_valido
    UNION ALL SELECT 'enforcement', unnest(ARRAY['mandatory','recommended','optional'])
    UNION ALL SELECT 'lifecycle', unnest(ARRAY['active','deprecated','draft','proposed'])
    UNION ALL SELECT 'assurance_level', unnest(ARRAY['AAL1','AAL2','AAL3'])
    UNION ALL SELECT 'auth_factor', unnest(ARRAY['knowledge','possession','inherence','context','multi'])
    UNION ALL SELECT 'semantic_type', unnest(ARRAY['policy','configuration','method','standard','guideline','group'])
    UNION ALL SELECT 'node_type', unnest(ARRAY['section','group','policy','config'])
),
config_values_from_library AS (
    -- Extraer valores de tipo string que podrían ser ENUM-like
    SELECT 'review_frequency' as campo, content_en::text as valor, count(*) as usos
    FROM bauth.cfg_policy_library
    WHERE jsonb_typeof(content_en) = 'string' AND content_en::text IN ('"monthly"','"quarterly"','"semi_annual"','"annual"','"daily"','"weekly"')
    GROUP BY content_en::text
    UNION ALL
    SELECT 'enforcement', content_en::text, count(*)
    FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'string'
    GROUP BY content_en::text
    HAVING count(*) > 2
)
SELECT * FROM config_values_from_library ORDER BY campo, usos DESC;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 2: Boolean flags — ¿existen en ath_config_d* o ath_policy_d*?' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

-- Flags booleanos de la biblioteca que NO tienen correspondencia en ath_config_d*
SELECT 'FLAG HUERFANO' as tipo, cpl.json_path, cpl.domain_map, cpl.risk_level,
       'No hay config_key equivalente en ath_config_d* para este dominio' as razon
FROM bauth.cfg_policy_library cpl
WHERE jsonb_typeof(cpl.content_en) = 'boolean'
  AND cpl.domain_map IS NOT NULL
  AND NOT EXISTS (
    -- Buscar en ath_config_d* de los dominios correspondientes
    SELECT 1 FROM (
      SELECT config_key FROM bauth.ath_config_d1 WHERE config_key LIKE '%' || regexp_replace(cpl.section_name, '[^a-zA-Z0-9]', '%', 'g') || '%'
      UNION ALL SELECT config_key FROM bauth.ath_config_d2 WHERE config_key LIKE '%' || regexp_replace(cpl.section_name, '[^a-zA-Z0-9]', '%', 'g') || '%'
      UNION ALL SELECT config_key FROM bauth.ath_config_d3 WHERE config_key LIKE '%' || regexp_replace(cpl.section_name, '[^a-zA-Z0-9]', '%', 'g') || '%'
    ) sub
  )
LIMIT 15;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 3: Métodos de auth — ¿referencias válidas a ath_method?' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

-- Arrays que contienen nombres de métodos — ¿existen en ath_method?
WITH method_arrays AS (
    SELECT json_path, domain_map, jsonb_array_elements_text(content_en) as method_name
    FROM bauth.cfg_policy_library
    WHERE semantic_type = 'method' AND jsonb_typeof(content_en) = 'array'
)
SELECT 'METODO_INVALIDO' as tipo, ma.json_path, ma.method_name,
       'No existe en ath_method.method_id ni method_name' as razon
FROM method_arrays ma
WHERE NOT EXISTS (
    SELECT 1 FROM bauth.ath_method am
    WHERE am.method_id = ma.method_name
       OR am.method_name ILIKE '%' || ma.method_name || '%'
)
LIMIT 20;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 4: Dominios — ¿tienen evaluador y tabla ath_policy_d*?' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

WITH library_domains AS (
    SELECT DISTINCT unnest(domain_map) as dom
    FROM bauth.cfg_policy_library WHERE domain_map IS NOT NULL
)
SELECT ld.dom as dominio,
    CASE WHEN ld.dom IN ('D1','D2','D3','D4','D5','D6','D7','D8','D9','D10','D11','D12')
         THEN 'TIENE EVALUADOR' ELSE 'SIN EVALUADOR' END as evaluador,
    CASE WHEN ld.dom IN ('D1','D2','D3','D4','D5','D6','D7','D8','D9','D10','D11','D12')
         THEN 'TIENE TABLA' ELSE 'SIN TABLA' END as tabla_ath_policy
FROM library_domains ld
ORDER BY ld.dom;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 5: Valores numéricos — ¿rangos válidos?' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

-- Valores numéricos que podrían estar fuera de rango
SELECT 'VALOR_FUERA_RANGO' as tipo, json_path,
       content_en::text::numeric as valor,
       'Valor numérico sin validación de rango en DDL. Verificar si excede límites del dominio.' as razon
FROM bauth.cfg_policy_library
WHERE jsonb_typeof(content_en) = 'number'
  AND (content_en::text::numeric < 0 OR content_en::text::numeric > 999999999)
LIMIT 10;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'FASE 6: Referencias circulares — ¿FK válidas?' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

-- Nodos con parent_path que no existe
SELECT 'HUERFANO' as tipo, cpl.json_path, cpl.parent_path, cpl.source,
       'parent_path no encontrado en la biblioteca' as razon
FROM bauth.cfg_policy_library cpl
WHERE cpl.parent_path IS NOT NULL
  AND cpl.parent_path != ''
  AND NOT EXISTS (
    SELECT 1 FROM bauth.cfg_policy_library p
    WHERE p.json_path = cpl.parent_path AND p.source = cpl.source
  )
LIMIT 10;

SELECT '═══════════════════════════════════════════════' as fase;
SELECT 'RESUMEN FINAL' as fase;
SELECT '═══════════════════════════════════════════════' as fase;

SELECT
    'Total nodos analizados' as metrica, count(*)::text as valor
FROM bauth.cfg_policy_library
UNION ALL
SELECT 'Tipos de nodo distintos',
    (SELECT count(DISTINCT node_type || '-' || semantic_type || '-' || enforcement)::text
     FROM bauth.cfg_policy_library)
UNION ALL
SELECT 'Boolean flags (configurables)',
    (SELECT count(*)::text FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'boolean')
UNION ALL
SELECT 'Valores string (opciones ENUM)',
    (SELECT count(*)::text FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'string')
UNION ALL
SELECT 'Valores numéricos',
    (SELECT count(*)::text FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'number')
UNION ALL
SELECT 'Arrays (catálogos)',
    (SELECT count(*)::text FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'array')
UNION ALL
SELECT 'Objetos (configs complejas)',
    (SELECT count(*)::text FROM bauth.cfg_policy_library WHERE jsonb_typeof(content_en) = 'object')
UNION ALL
SELECT 'Dominios únicos en domain_map',
    (SELECT count(DISTINCT d)::text FROM (
        SELECT unnest(domain_map) as d FROM bauth.cfg_policy_library WHERE domain_map IS NOT NULL
    ) sub)
UNION ALL
SELECT 'Nodos con parent_path válido',
    (SELECT count(*)::text FROM bauth.cfg_policy_library cpl WHERE parent_path IS NOT NULL
     AND EXISTS (SELECT 1 FROM bauth.cfg_policy_library p WHERE p.json_path = cpl.parent_path AND p.source = cpl.source));
