-- ============================================================================
-- SEED: Sincronización cfg_policy_library → ath_policy_d* + ath_config_d*
-- Extrae políticas y configuraciones de la biblioteca unificada (9,142 nodos)
-- y las inserta en las tablas por dominio (ath_policy_d1..d12, ath_config_d1..d12)
-- Idempotente: DELETE + INSERT para políticas que vienen de la biblioteca
-- Fuente: cfg_policy_library (16 fuentes, 13 dominios D1-D12+SEC)
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- POLÍTICAS: Insertar desde cfg_policy_library donde node_type = 'policy'
-- Cada política de la biblioteca con domain_map se inserta en TODOS los
-- dominios que la referencian.
-- ═══════════════════════════════════════════════════════════════════════════

-- Limpiar políticas generadas desde biblioteca (conservar las manuales)
DELETE FROM bauth.ath_policy_d1  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d2  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d3  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d4  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d5  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d6  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d7  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d8  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d9  WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d10 WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d11 WHERE policy_code LIKE 'LIB-%';
DELETE FROM bauth.ath_policy_d12 WHERE policy_code LIKE 'LIB-%';

-- D1: Lógico
INSERT INTO bauth.ath_policy_d1 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-') AS policy_code,
    COALESCE(cpl.content_en->>'title', cpl.section_name) AS policy_name,
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada') AS description,
    COALESCE(cpl.compliance_ref,
        CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END) AS standard_ref,
    cpl.content_en AS config
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D1' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D2: Físico
INSERT INTO bauth.ath_policy_d2 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D2' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D3: Financiero
INSERT INTO bauth.ath_policy_d3 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D3' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D4: Temporal
INSERT INTO bauth.ath_policy_d4 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D4' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D5: Biométrico
INSERT INTO bauth.ath_policy_d5 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D5' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D6: Geoespacial
INSERT INTO bauth.ath_policy_d6 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D6' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D7: Red
INSERT INTO bauth.ath_policy_d7 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D7' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D8: Contexto
INSERT INTO bauth.ath_policy_d8 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D8' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D9: Credenciales
INSERT INTO bauth.ath_policy_d9 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D9' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D10: Delegación
INSERT INTO bauth.ath_policy_d10 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D10' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D11: Auditoría
INSERT INTO bauth.ath_policy_d11 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D11' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

-- D12: Blockchain
INSERT INTO bauth.ath_policy_d12 (policy_code, policy_name, description, standard_ref, config)
SELECT
    'LIB-' || replace(cpl.json_path, '/', '-'),
    COALESCE(cpl.content_en->>'title', cpl.section_name),
    COALESCE(cpl.description, cpl.content_en->>'description', 'Política importada de la biblioteca unificada'),
    COALESCE(cpl.compliance_ref, CASE WHEN cpl.standard_ref IS NOT NULL THEN ARRAY[cpl.standard_ref] ELSE ARRAY[]::text[] END),
    cpl.content_en
FROM bauth.cfg_policy_library cpl
WHERE cpl.node_type = 'policy'
  AND cpl.domain_map IS NOT NULL
  AND 'D12' = ANY(cpl.domain_map)
  AND cpl.lifecycle != 'deprecated'
ON CONFLICT (policy_code) DO UPDATE SET
    policy_name = EXCLUDED.policy_name,
    description = EXCLUDED.description,
    standard_ref = EXCLUDED.standard_ref,
    config = EXCLUDED.config,
    updated_at = now();

COMMIT;
