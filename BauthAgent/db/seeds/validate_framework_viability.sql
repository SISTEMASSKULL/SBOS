-- ============================================================================
-- VALIDADOR: Viabilidad de cfg_policy_library (9,142 nodos) en bAuth
-- Cada nodo se evalúa contra la arquitectura real de bAuth:
--   DomainRegistry (12 evaluadores) + PolicyEngine (17 operadores) +
--   Fast-Path BitMask + ath_policy_d* + ath_config_d* + ath_method
-- Resultado: APTO / NO_APTO / REFERENCIA
-- ============================================================================

BEGIN;

DROP TABLE IF EXISTS bauth._validation_report;
CREATE TEMP TABLE _validation_report (
    nodo_id         INTEGER,
    json_path       TEXT,
    node_type       TEXT,
    semantic_type   TEXT,
    domain_map      TEXT[],
    enforcement     TEXT,
    risk_level      TEXT,
    clasificacion   TEXT,
    viable          BOOLEAN,
    razon           TEXT,
    accion          TEXT
);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 1: Políticas condicionales (operadores detectados)
-- APTO si: tiene 'op', 'operator', 'condition', 'rule', 'threshold', 'action'
-- El PolicyEngine de bAuth (17 operadores) puede evaluarlas
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'POLITICA_CONDICIONAL',
    true,
    'Config contiene campos evaluables (op/operator/condition/rule/threshold/action). Compatible con PolicyEngine 17 operadores.',
    'Registrar en ath_policy_d{n} con config JSONB. PolicyEngine::eval_rule() la evaluará.'
FROM bauth.cfg_policy_library
WHERE (content_en::text LIKE '%"op"%' OR content_en::text LIKE '%"operator"%'
       OR content_en::text LIKE '%"condition"%' OR content_en::text LIKE '%"rule"%'
       OR content_en::text LIKE '%"threshold"%' OR content_en::text LIKE '%"action"%')
  AND node_type != 'group';

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 2: Métodos de autenticación
-- APTO si: semantic_type = 'method'
-- bAuth los maneja via ath_method + ath_auth_flow + ath_binding
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'METODO_AUTENTICACION',
    true,
    'Método de autenticación documentado. bAuth lo gestiona via ath_method + ath_auth_flow_method + Keycloak.',
    'Registrar en ath_method.method_id. Asignar aal_level según NIST. Vincular a ath_auth_flow via ath_auth_flow_method.'
FROM bauth.cfg_policy_library
WHERE semantic_type = 'method'
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 3: Estándares normativos (ISO, NIST, PCI, SOX, GDPR)
-- REFERENCIA: documentan cumplimiento, no son evaluables
-- Pero son NECESARIOS para audit_compliance_map y reportes de compliance
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'ESTANDAR_NORMATIVO',
    true,
    'Referencia a estándar internacional. Requerido para compliance reports y audit_compliance_map. No evaluable por PolicyEngine.',
    'Mapear a aud_compliance_map.standard + control_id. Usar compliance_ref[] para trazabilidad.'
FROM bauth.cfg_policy_library
WHERE semantic_type IN ('standard')
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 4: Guías de industria (AWS, Google, Microsoft, Okta)
-- REFERENCIA: mejores prácticas, no obligatorias
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'GUIA_INDUSTRIA',
    true,
    'Guía de mejores prácticas de la industria. enforcement=recommended. Informativo para administradores.',
    'Disponible en UI como referencia. No genera alertas de cumplimiento.'
FROM bauth.cfg_policy_library
WHERE semantic_type IN ('guideline')
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 5: Configuraciones con valores numéricos/de texto concretos
-- APTO si: el JSONB tiene claves con valores escalares (no objetos anidados profundos)
-- bAuth puede leerlas directamente via ath_config_d*
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'CONFIG_DIRECTA',
    CASE
        WHEN domain_map IS NOT NULL AND array_length(domain_map,1) > 0 THEN true
        ELSE false
    END,
    CASE
        WHEN domain_map IS NULL THEN 'Sin domain_map asignado. No se puede determinar qué evaluador de dominio la procesa.'
        WHEN array_length(domain_map,1) = 0 THEN 'domain_map vacío. Requiere asignación a dominio D1-D12.'
        ELSE 'Configuración con valores concretos. Puede almacenarse en ath_config_d{n} y leerse directamente.'
    END,
    CASE
        WHEN domain_map IS NULL THEN 'Asignar domain_map explícito (ej: {D9} para credenciales).'
        WHEN array_length(domain_map,1) = 0 THEN 'Asignar al menos un dominio D1-D12.'
        ELSE 'INSERT INTO ath_config_d{n} (config_key, config_value) VALUES.'
    END
FROM bauth.cfg_policy_library
WHERE node_type = 'config'
  AND semantic_type = 'policy'
  AND (jsonb_typeof(content_en) = 'object' OR jsonb_typeof(content_en) = 'number' OR jsonb_typeof(content_en) = 'string')
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 6: Metadatos (arrays, listas de strings)
-- NO APTO para evaluación directa. Son catálogos de valores permitidos.
-- Necesarios para UI (dropdowns, checkboxes) y validación de integridad referencial.
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'METADATO_CATALOGO',
    CASE
        WHEN domain_map IS NOT NULL AND array_length(domain_map,1) > 0 THEN true
        ELSE false
    END,
    CASE
        WHEN domain_map IS NULL THEN 'Array/lista sin dominio asignado. Útil como catálogo de referencia pero no vinculable a evaluador.'
        WHEN array_length(domain_map,1) = 0 THEN 'Catálogo sin dominio. Requiere domain_map para ser referenciado por el evaluador.'
        ELSE 'Catálogo de valores permitidos. Usado por UI para dropdowns/checkboxes. Validación de integridad referencial.'
    END,
    CASE
        WHEN domain_map IS NULL THEN 'Asignar domain_map. Ej: lista de compliance frameworks → {D11}.'
        ELSE 'Vincular a menu_context.entity_type para dropdowns en UI.'
    END
FROM bauth.cfg_policy_library
WHERE (jsonb_typeof(content_en) = 'array' OR (jsonb_typeof(content_en) = 'object' AND content_en::text LIKE '%[]%'))
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 7: Agrupadores (node_type = 'group')
-- NO APTO para evaluación. Son contenedores jerárquicos para organizar políticas.
-- Necesarios para navegación en UI.
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'AGRUPADOR',
    true,
    'Nodo contenedor jerárquico. Organiza políticas/configs en el árbol de navegación. Sin función evaluativa.',
    'Usar en UI como nodo expandible del árbol de políticas (Panel 4). Sin acción DDL adicional.'
FROM bauth.cfg_policy_library
WHERE node_type = 'group'
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 8: Secciones (node_type = 'section')
-- Son las 16 fuentes originales del framework. Nodos raíz.
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'FUENTE_FRAMEWORK',
    true,
    'Fuente original del framework cargada en framework_raw. Nodo raíz de la jerarquía.',
    'Metadatos en framework_raw.source_name. Sin acción adicional.'
FROM bauth.cfg_policy_library
WHERE node_type = 'section'
  AND section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 9: Resto sin clasificar
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO _validation_report
SELECT
    section_id, json_path, node_type, semantic_type, domain_map, enforcement, risk_level,
    'SIN_CLASIFICAR',
    false,
    'Nodo que no coincide con ninguna categoría conocida. Requiere revisión manual.',
    'Revisar content_en manualmente. Determinar si es config, metadata, o ruido.'
FROM bauth.cfg_policy_library
WHERE section_id NOT IN (SELECT nodo_id FROM _validation_report);

-- ═══════════════════════════════════════════════════════════════════════════
-- REPORTE FINAL
-- ═══════════════════════════════════════════════════════════════════════════
\echo '============================================'
\echo 'REPORTE DE VIABILIDAD — cfg_policy_library'
\echo '============================================'
SELECT
    clasificacion,
    viable,
    count(*) as nodos,
    round(count(*) * 100.0 / sum(count(*)) over(), 1) as porcentaje
FROM _validation_report
GROUP BY clasificacion, viable
ORDER BY count(*) DESC;

\echo ''
\echo '============================================'
\echo 'NODOS NO VIABLES — Requieren acción'
\echo '============================================'
SELECT
    clasificacion,
    count(*) as nodos,
    razon
FROM _validation_report
WHERE viable = false
GROUP BY clasificacion, razon
ORDER BY count(*) DESC;

\echo ''
\echo '============================================'
\echo 'MUESTRA: SIN_CLASIFICAR (requieren revisión)'
\echo '============================================'
SELECT json_path, node_type, semantic_type, domain_map,
       left(content_en::text, 150) as preview
FROM _validation_report
WHERE clasificacion = 'SIN_CLASIFICAR'
LIMIT 10;

\echo ''
\echo '============================================'
\echo 'RESUMEN POR DOMINIO'
\echo '============================================'
SELECT
    COALESCE(d.domain, 'SIN_DOMINIO') as dominio,
    count(*) as politicas,
    count(*) FILTER (WHERE viable = true) as viables,
    count(*) FILTER (WHERE viable = false) as no_viables
FROM _validation_report r,
     LATERAL (SELECT unnest(COALESCE(r.domain_map, ARRAY['SIN_DOMINIO']))) as d(domain)
GROUP BY d.domain
ORDER BY
    CASE d.domain
        WHEN 'D1' THEN 1 WHEN 'D2' THEN 2 WHEN 'D3' THEN 3 WHEN 'D4' THEN 4
        WHEN 'D5' THEN 5 WHEN 'D6' THEN 6 WHEN 'D7' THEN 7 WHEN 'D8' THEN 8
        WHEN 'D9' THEN 9 WHEN 'D10' THEN 10 WHEN 'D11' THEN 11 WHEN 'D12' THEN 12
        WHEN 'SEC' THEN 13
        ELSE 99
    END;

COMMIT;
