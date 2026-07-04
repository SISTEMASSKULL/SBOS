-- ============================================================================
-- SEED: merge_real_templates — merge de 2 roles con plantillas reales
-- Opera sobre idn_role_template.template (JSONB generado por seed_idn_role_template_data.sql)
-- Arquitectura: toma 2 roles existentes, conjuga sus secciones JSONB,
-- completa las 14 secciones del RolTemplate v6.0 con defaults donde falten.
-- Precedencia para keys en conflicto: rol primario gana sobre secundario.
-- Fuente: BAUTH-ROLTEMPLATE-SECCIONES.md v6.0
-- ============================================================================

BEGIN;

-- ─── FUNCIÓN: merge de 2 roles reales ───────────────────────
CREATE OR REPLACE FUNCTION bauth.merge_real_templates(
    p_primary_id TEXT,
    p_secondary_id TEXT,
    p_result_id TEXT,
    p_tier TEXT DEFAULT 'BIZ_N3'
) RETURNS JSONB AS $$
DECLARE
    v_primary JSONB;
    v_secondary JSONB;
    v_result JSONB;
    v_section TEXT;
    -- Mapeo de nombres legacy → v6.0 canónico
    v_name_map JSONB := '{
        "logical_access":"logical_access",
        "physical_access":"physical_access",
        "financial_limits":"financial",
        "temporal_schedule":"temporal",
        "credential_policy":"credentials",
        "audit":"audit",
        "sync_metadata":"sync"
    }';
    -- 14 secciones del template v6.0
    v_all_sections TEXT[] := ARRAY[
        'logical_access','physical_access','financial','temporal',
        'biometric','geospatial','network','context',
        'credentials','delegation','audit','blockchain',
        'security','compliance','sync'
    ];
BEGIN
    -- Cargar templates reales
    SELECT template INTO v_primary FROM bauth.idn_role_template WHERE id = p_primary_id;
    SELECT template INTO v_secondary FROM bauth.idn_role_template WHERE id = p_secondary_id;

    IF v_primary IS NULL THEN
        RAISE EXCEPTION 'Rol primario % no encontrado', p_primary_id;
    END IF;
    IF v_secondary IS NULL THEN
        RAISE EXCEPTION 'Rol secundario % no encontrado', p_secondary_id;
    END IF;

    -- Inicializar resultado con metadatos
    v_result := jsonb_build_object(
        'role', jsonb_build_object(
            'id', p_result_id,
            'tier', p_tier,
            'status', 'DEFINIDO',
            'version', '6.0.0',
            'name', jsonb_build_object(
                'es', 'Merge: ' || p_primary_id || ' + ' || p_secondary_id,
                'en', 'Merge: ' || p_primary_id || ' + ' || p_secondary_id
            ),
            'description', jsonb_build_object(
                'es', 'Rol fusionado desde ' || p_primary_id || ' y ' || p_secondary_id,
                'en', 'Role merged from ' || p_primary_id || ' and ' || p_secondary_id
            ),
            'merged_from', jsonb_build_array(p_primary_id, p_secondary_id),
            'merged_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        )
    );

    -- Para cada una de las 14 secciones v6.0:
    FOREACH v_section IN ARRAY v_all_sections LOOP
        -- Buscar en primario: primero con nombre v6.0, luego legacy
        IF v_primary ? v_section THEN
            v_result := jsonb_set(v_result, ARRAY[v_section], v_primary->v_section);
        -- Buscar mapeo inverso: ¿hay una key legacy que mapea a v_section?
        ELSE
            DECLARE
                v_legacy_key TEXT;
                v_found BOOLEAN := false;
            BEGIN
                FOR v_legacy_key IN SELECT jsonb_object_keys(v_name_map) LOOP
                    IF v_name_map->>v_legacy_key = v_section AND v_primary ? v_legacy_key THEN
                        v_result := jsonb_set(v_result, ARRAY[v_section], v_primary->v_legacy_key);
                        v_found := true;
                        EXIT;
                    END IF;
                END LOOP;

                -- Si no está en primario, buscar en secundario
                IF NOT v_found AND v_secondary ? v_section THEN
                    v_result := jsonb_set(v_result, ARRAY[v_section], v_secondary->v_section);
                ELSIF NOT v_found THEN
                    FOR v_legacy_key IN SELECT jsonb_object_keys(v_name_map) LOOP
                        IF v_name_map->>v_legacy_key = v_section AND v_secondary ? v_legacy_key THEN
                            v_result := jsonb_set(v_result, ARRAY[v_section], v_secondary->v_legacy_key);
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END;
        END IF;
    END LOOP;

    -- Copiar sync_metadata del primario (no es sección v6.0 pero es necesario)
    IF v_primary ? 'sync_metadata' THEN
        v_result := jsonb_set(v_result, ARRAY['sync'], v_primary->'sync_metadata');
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;

-- ─── DEMO: merge de 2 roles reales ──────────────────────────
DELETE FROM bauth.idn_role_template WHERE id IN ('ROL-MERGED-CAJ-SUPERVISOR', 'ROL-MERGED-CONT-AUDITOR');

-- Merge 1: Cajero + Supervisor = Cajero Senior con más alcance
INSERT INTO bauth.idn_role_template (
    id, tenant_id, empresa_id, parent_id, type_id, hierarchy_level, version, status, tier,
    loa_required, mfa_required, step_up_enabled, audit_level, sync_status,
    issuer, owner_tenant, start_time, created_by, rol_bitmask_base64, template, template_version
) VALUES (
    'ROL-MERGED-CAJ-SUPERVISOR',
    (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
    'NIT-1234567890',
    NULL, 'INTERNAL', 2, '6.0.0', 'DEFINIDO', 'BIZ_N4',
    2, true, false, 'basic', 'PENDING',
    'system', 'skull', now(), 'system', '0x0',
    bauth.merge_real_templates(
        'ROL-ORG-CCO',         -- primario: Chief Commercial Officer (BIZ_N1)
        'ROL-ORG-CONT-SENIOR', -- secundario: Contador Senior
        'ROL-MERGED-CAJ-SUPERVISOR', 'BIZ_N4'
    ),
    '6.0.0'
);

-- Merge 2: Contador Senior + Auditor = Contralor
INSERT INTO bauth.idn_role_template (
    id, tenant_id, empresa_id, parent_id, type_id, hierarchy_level, version, status, tier,
    loa_required, mfa_required, step_up_enabled, audit_level, sync_status,
    issuer, owner_tenant, start_time, created_by, rol_bitmask_base64, template, template_version
) VALUES (
    'ROL-MERGED-CONT-AUDITOR',
    (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull'),
    'NIT-1234567890',
    NULL, 'INTERNAL', 3, '6.0.0', 'DEFINIDO', 'BIZ_N4',
    3, true, false, 'full', 'PENDING',
    'system', 'skull', now(), 'system', '0x0',
    bauth.merge_real_templates(
        'ROL-ORG-CONT-SENIOR', -- primario: Contador Senior
        'ROL-ORG-CEO',         -- secundario: CEO (máxima autoridad)
        'ROL-MERGED-CONT-AUDITOR', 'BIZ_N4'
    ),
    '6.0.0'
);

COMMIT;
