-- =============================================================================
-- bauth_43__cfg_policy_library_seeds_from_ath.sql
-- Consolida TODA la colección de políticas en cfg_policy_library:
--   FASE 1-3 : Importa ath_config_d1..12 y ath_policy_d1..12
--   FASE 4   : Enriquece enum_options para vocabularios controlados
--   FASE 5   : Políticas extendidas D3/D5/D6/D10/D12 por estándares
-- Autor       : bauth-developer · 2026-07-07
-- Idempotente : ON CONFLICT (path) — seguro ejecutar más de una vez
-- =============================================================================

BEGIN;
SET lock_timeout = '120s';

-- =============================================================================
-- FASES 1-3 — Importar ath_config_dN y ath_policy_dN (PL/pgSQL dinámico)
-- =============================================================================

DO $$
DECLARE
    num         int;
    dn          text;
    dom_path    ltree;
    cfg_path    ltree;
    pol_path    ltree;
    r_cfg       RECORD;
    r_pol       RECORD;
    prop_k      text;
    prop_v      jsonb;
    lbl         text;
    lbl_prop    text;
    pol_node    ltree;
    prop_node   ltree;
BEGIN
    -- FRAMEWORK raíz sbosSeeds
    INSERT INTO bauth.cfg_policy_library (
        section_name, parent_path, json_path, path, depth, order_index,
        node_type, level_type, source, is_required,
        content, content_en, content_es
    ) VALUES (
        'sbosSeeds', NULL, 'sbosSeeds', 'sbosSeeds', 1, 1,
        'section', 'FRAMEWORK', 'sbos_seeds_v1_2026', false,
        '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
    ) ON CONFLICT (path) DO NOTHING;

    FOR num IN 1..12 LOOP
        dn       := 'D' || num;
        dom_path := ('sbosSeeds.' || dn)::ltree;
        cfg_path := dom_path || 'config'::ltree;
        pol_path := dom_path || 'policy'::ltree;

        -- DOMAIN sbosSeeds.D{N}
        INSERT INTO bauth.cfg_policy_library (
            section_name, parent_path, json_path, path, depth, order_index,
            node_type, level_type, source, domain_map, is_required,
            content, content_en, content_es
        ) VALUES (
            dn, 'sbosSeeds', dom_path::text, dom_path, 2, num,
            'group', 'DOMAIN', 'sbos_seeds_v1_2026', ARRAY[dn], false,
            '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
        ) ON CONFLICT (path) DO NOTHING;

        -- POLICY_SET: sbosSeeds.D{N}.config
        INSERT INTO bauth.cfg_policy_library (
            section_name, parent_path, json_path, path, depth, order_index,
            node_type, level_type, source, domain_map, is_required,
            content, content_en, content_es
        ) VALUES (
            'config', dom_path::text, cfg_path::text, cfg_path, 3, 1,
            'group', 'POLICY_SET', 'sbos_seeds_v1_2026', ARRAY[dn], false,
            '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
        ) ON CONFLICT (path) DO NOTHING;

        -- POLICY_SET: sbosSeeds.D{N}.policy
        INSERT INTO bauth.cfg_policy_library (
            section_name, parent_path, json_path, path, depth, order_index,
            node_type, level_type, source, domain_map, is_required,
            content, content_en, content_es
        ) VALUES (
            'policy', dom_path::text, pol_path::text, pol_path, 3, 2,
            'group', 'POLICY_SET', 'sbos_seeds_v1_2026', ARRAY[dn], false,
            '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
        ) ON CONFLICT (path) DO NOTHING;

        -- FASE 2: ath_config_d{N} → RULE nodes (datos de referencia)
        FOR r_cfg IN EXECUTE
            'SELECT config_key, config_value, description, standard_ref
             FROM bauth.ath_config_d' || num
        LOOP
            lbl := regexp_replace(
                       regexp_replace(lower(r_cfg.config_key), '[^a-z0-9_]', '_', 'g'),
                   '_+', '_', 'g');
            lbl := btrim(lbl, '_');
            CONTINUE WHEN lbl = '';

            INSERT INTO bauth.cfg_policy_library (
                section_name, parent_path, json_path, path, depth, order_index,
                node_type, level_type, source, domain_map, standard_ref,
                description, is_required,
                content, content_en, content_es
            ) VALUES (
                r_cfg.config_key,
                cfg_path::text,
                (cfg_path || lbl::ltree)::text,
                cfg_path || lbl::ltree,
                4, 1,
                'group', 'RULE', 'sbos_seeds_v1_2026', ARRAY[dn],
                array_to_string(r_cfg.standard_ref, ', '),
                r_cfg.description,
                false,
                COALESCE(r_cfg.config_value, '{}'::jsonb),
                '{}'::jsonb,
                '{}'::jsonb
            ) ON CONFLICT (path) DO UPDATE SET
                content      = EXCLUDED.content,
                standard_ref = COALESCE(EXCLUDED.standard_ref, bauth.cfg_policy_library.standard_ref),
                description  = COALESCE(EXCLUDED.description,  bauth.cfg_policy_library.description);
        END LOOP;

        -- FASE 3: ath_policy_d{N} → POLICY + PROPERTY (reglas operacionales)
        -- Omitir entradas LIB- (referencias a nodos ya existentes)
        FOR r_pol IN EXECUTE
            'SELECT policy_code, policy_name, description, standard_ref, config
             FROM bauth.ath_policy_d' || num
             || ' WHERE policy_code NOT LIKE ''LIB-%'''
        LOOP
            lbl := regexp_replace(
                       regexp_replace(lower(r_pol.policy_code), '[^a-z0-9_]', '_', 'g'),
                   '_+', '_', 'g');
            lbl := btrim(lbl, '_');
            CONTINUE WHEN lbl = '';

            pol_node := pol_path || lbl::ltree;

            -- Insertar nodo POLICY
            INSERT INTO bauth.cfg_policy_library (
                section_name, parent_path, json_path, path, depth, order_index,
                node_type, level_type, source, domain_map, standard_ref,
                description, is_required,
                content, content_en, content_es
            ) VALUES (
                r_pol.policy_code,
                pol_path::text,
                pol_node::text,
                pol_node,
                4, 1,
                'policy', 'POLICY', 'sbos_seeds_v1_2026', ARRAY[dn],
                array_to_string(r_pol.standard_ref, ', '),
                COALESCE(r_pol.description, r_pol.policy_name),
                false,
                COALESCE(r_pol.config, '{}'::jsonb),
                '{}'::jsonb,
                '{}'::jsonb
            ) ON CONFLICT (path) DO UPDATE SET
                content      = EXCLUDED.content,
                standard_ref = COALESCE(EXCLUDED.standard_ref, bauth.cfg_policy_library.standard_ref),
                description  = COALESCE(EXCLUDED.description,  bauth.cfg_policy_library.description);

            -- Descomponer config JSONB en PROPERTY hijos (objetos con claves)
            IF r_pol.config IS NOT NULL AND jsonb_typeof(r_pol.config) = 'object' THEN
                FOR prop_k, prop_v IN
                    SELECT key, value FROM jsonb_each(r_pol.config)
                LOOP
                    lbl_prop := regexp_replace(
                                    regexp_replace(lower(prop_k), '[^a-z0-9_]', '_', 'g'),
                                '_+', '_', 'g');
                    lbl_prop := btrim(lbl_prop, '_');
                    CONTINUE WHEN lbl_prop = '';

                    prop_node := pol_node || lbl_prop::ltree;

                    INSERT INTO bauth.cfg_policy_library (
                        section_name, parent_path, json_path, path, depth, order_index,
                        node_type, level_type, source, domain_map,
                        value_type, default_value, enum_options,
                        is_required,
                        content, content_en, content_es
                    ) VALUES (
                        prop_k,
                        pol_node::text,
                        prop_node::text,
                        prop_node,
                        5, 1,
                        'config', 'PROPERTY', 'sbos_seeds_v1_2026', ARRAY[dn],
                        CASE jsonb_typeof(prop_v)
                            WHEN 'boolean' THEN 'BOOLEAN'
                            WHEN 'number'  THEN CASE WHEN prop_v::text LIKE '%.%'
                                                     THEN 'FLOAT' ELSE 'INTEGER' END
                            WHEN 'array'   THEN 'ENUM'
                            WHEN 'string'  THEN 'TEXT'
                            ELSE 'JSONB'
                        END,
                        CASE WHEN jsonb_typeof(prop_v) IN ('boolean','number','string')
                             THEN prop_v #>> '{}' ELSE NULL END,
                        CASE WHEN jsonb_typeof(prop_v) = 'array'
                             THEN ARRAY(SELECT jsonb_array_elements_text(prop_v))
                             ELSE NULL END,
                        false,
                        prop_v,
                        '{}'::jsonb,
                        '{}'::jsonb
                    ) ON CONFLICT (path) DO UPDATE SET
                        value_type    = EXCLUDED.value_type,
                        default_value = EXCLUDED.default_value,
                        enum_options  = EXCLUDED.enum_options,
                        content       = EXCLUDED.content;
                END LOOP;

            -- Config es un array → un PROPERTY ENUM con las opciones
            ELSIF r_pol.config IS NOT NULL AND jsonb_typeof(r_pol.config) = 'array' THEN
                prop_node := pol_node || 'values'::ltree;
                INSERT INTO bauth.cfg_policy_library (
                    section_name, parent_path, json_path, path, depth, order_index,
                    node_type, level_type, source, domain_map,
                    value_type, enum_options, is_required,
                    content, content_en, content_es
                ) VALUES (
                    'values',
                    pol_node::text,
                    prop_node::text,
                    prop_node,
                    5, 1,
                    'config', 'PROPERTY', 'sbos_seeds_v1_2026', ARRAY[dn],
                    'ENUM',
                    ARRAY(SELECT jsonb_array_elements_text(r_pol.config)),
                    false,
                    r_pol.config,
                    '{}'::jsonb,
                    '{}'::jsonb
                ) ON CONFLICT (path) DO UPDATE SET
                    enum_options = EXCLUDED.enum_options,
                    content      = EXCLUDED.content;
            END IF;

        END LOOP; -- fin FOR r_pol
    END LOOP; -- fin FOR num
END $$;

-- =============================================================================
-- FASE 4 — Enriquecer enum_options para vocabularios controlados conocidos
-- Solo actualiza nodos TEXT/ENUM que todavía no tienen enum_options
-- =============================================================================

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['1m','5m','15m','30m','1h','6h','12h','daily','weekly','continuous','realtime']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('updateFrequency','update_frequency','syncFrequency')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['7d','30d','90d','180d','365d','1y','2y','3y','5y','7y','permanent']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('retention','retentionPeriod','retention_period','maxAge','max_age','keyRotation','key_rotation')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['none','minimal','basic','standard','detailed','comprehensive','verbose','full']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('logging','log_level','logLevel','verbosity')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED','SECRET','TOP_SECRET']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('classification','data_classification','dataClassification',
                       'sensitivity','sensitivity_level','sensitivityLevel')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['none','standard','enhanced','mfa','multiFactor','maximum','required']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('authentication','auth_requirement','authRequired','mfa_policy')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['none','basic','controlled','standard','strict','high','maximum','audit_only']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('securityLevel','security_level','accessControls','access_controls',
                       'enforcement','enforceLevel')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['100ms','500ms','1s','3s','5s','10s','30s','1m','5m','15m','30m','1h','4h','24h','immediate']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('responseTime','response_time','timeout','gracePeriod','grace_period',
                       'critical','warning','rto','rpo')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['memory','temporary','encryptedDB','cloud','secureKeyVault',
                          'hardwareSecured','hsm','primaryHSM','isolatedHSM']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('storage','keyStorage','key_storage','storageType')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['low','normal','high','highest','critical','immediate',
                          'denyOverrides','permitOverrides','firstApplicable']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('priority','combining_algorithm','combiningAlgorithm')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['none','required','cryptographic','continuous',
                          'biometric','physical','magnetic_field_test']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('verification','identity_verification','liveness_detection')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['local','branch','regional','national','global',
                          'eu_eea','home_country_only','sanctioned_countries']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('region','scope','geographic_scope','access_region')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['INFO','LOW','MEDIUM','HIGH','CRITICAL','CATASTROPHIC']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('risk_level','riskLevel','severity','impact')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['none','passive','soft','standard','active','hard','hybrid','strict','maximum']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('mode','operation_mode','operationMode','detection_mode','liveness_mode')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['LOG','ALERT','WARN','CHALLENGE','BLOCK','DENY','LOCKOUT','REVOKE']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('on_failure','onFailure','action','failure_action','failureAction',
                        'lockdown_action','breach_action')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY[
    'SHA-256','SHA-384','SHA-512','SHA3-256','SHA3-512','BLAKE2b',
    'Argon2id','bcrypt','RSA-4096','ECDSA-P384','Ed25519','Ed448',
    'ML-DSA-65','ML-DSA-87','SLH-DSA','ML-KEM-768','ML-KEM-1024',
    'HmacSHA1','HmacSHA256','HmacSHA512'
]
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('algorithm','hash_algorithm','hashAlgorithm','signature_algorithm',
                        'signatureAlgorithm','kdf','key_algorithm')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['AAL1','AAL2','AAL3']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('aal','aal_level','assurance_level','authAssuranceLevel',
                        'minimum_aal','required_aal')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['IAL1','IAL2','IAL3']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('ial','ial_level','identity_assurance','proofing_level')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['SU','SYS','BIZ_N1','BIZ_N2','BIZ_N3','BIZ_N4','BIZ_N5',
                          'EXT_N0','M2M','VISITANTE']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('tier','role_tier','applies_to_tier','minimum_tier','required_tier')
  AND enum_options IS NULL;

UPDATE bauth.cfg_policy_library
SET enum_options = ARRAY['enabled','disabled','automatic','manual','on_breach']
WHERE level_type IN ('PROPERTY','RULE') AND value_type = 'TEXT'
  AND section_name IN ('rotation','key_rotation','credential_rotation',
                        'auto_renewal','auto_rotate')
  AND enum_options IS NULL;

-- =============================================================================
-- FASE 5 — Políticas extendidas para dominios con poca cobertura
-- D3 (98 nodos) · D5 (66 nodos) · D6 (106 nodos) · D10 (106 nodos) · D12 (179 nodos)
-- =============================================================================

-- POLICY_SET extended por dominio
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, is_required,
    content, content_en, content_es, description
) VALUES
('extended','sbosSeeds.D3','sbosSeeds.D3.extended','sbosSeeds.D3.extended',
 3,3,'group','POLICY_SET','sbos_seeds_v1_2026',ARRAY['D3'],false,
 '{}'::jsonb,'{}'::jsonb,'{}'::jsonb,
 'Políticas de métodos de autenticación — NIST SP 800-63B Rev.4'),

('extended','sbosSeeds.D5','sbosSeeds.D5.extended','sbosSeeds.D5.extended',
 3,3,'group','POLICY_SET','sbos_seeds_v1_2026',ARRAY['D5'],false,
 '{}'::jsonb,'{}'::jsonb,'{}'::jsonb,
 'Políticas de gestión de credenciales — NIST SP 800-63B Rev.4'),

('extended','sbosSeeds.D6','sbosSeeds.D6.extended','sbosSeeds.D6.extended',
 3,3,'group','POLICY_SET','sbos_seeds_v1_2026',ARRAY['D6'],false,
 '{}'::jsonb,'{}'::jsonb,'{}'::jsonb,
 'Políticas de sesiones y tokens JWT — OAuth 2.0 / NIST 800-63B'),

('extended','sbosSeeds.D10','sbosSeeds.D10.extended','sbosSeeds.D10.extended',
 3,3,'group','POLICY_SET','sbos_seeds_v1_2026',ARRAY['D10'],false,
 '{}'::jsonb,'{}'::jsonb,'{}'::jsonb,
 'Políticas de federación — OAuth 2.0 RFC 6749 / OIDC / SAML 2.0'),

('extended','sbosSeeds.D12','sbosSeeds.D12.extended','sbosSeeds.D12.extended',
 3,3,'group','POLICY_SET','sbos_seeds_v1_2026',ARRAY['D12'],false,
 '{}'::jsonb,'{}'::jsonb,'{}'::jsonb,
 'Políticas biométricas — FIDO2/WebAuthn / ISO/IEC 19794')

ON CONFLICT (path) DO NOTHING;

-- -----------------------------------------------------------------------------
-- D3 — POLÍTICA: contraseñas NIST 800-63B Rev.4
-- -----------------------------------------------------------------------------
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('EXT_PASSWORD_NIST63B','sbosSeeds.D3.extended',
 'sbosSeeds.D3.extended.ext_password_nist63b','sbosSeeds.D3.extended.ext_password_nist63b',
 4,1,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D3'],
 'NIST SP 800-63B Rev.4 §5.1',false,
 '{"min_length":8,"max_length":64,"breach_check":true,"complexity_required":false,"no_periodic_rotation":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Contraseñas NIST 800-63B Rev.4: longitud 8-64, verificación de compromiso, sin rotación periódica'),

('EXT_TOTP_POLICY','sbosSeeds.D3.extended',
 'sbosSeeds.D3.extended.ext_totp_policy','sbosSeeds.D3.extended.ext_totp_policy',
 4,2,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D3'],
 'RFC 6238 · NIST SP 800-63B §5.1.3',false,
 '{"algorithm":"HmacSHA256","digit_count":6,"period_seconds":30,"look_ahead_window":1}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'TOTP: HmacSHA256, 6 dígitos, ventana 30s, tolerancia 1 paso'),

('EXT_WEBAUTHN_RP','sbosSeeds.D3.extended',
 'sbosSeeds.D3.extended.ext_webauthn_rp','sbosSeeds.D3.extended.ext_webauthn_rp',
 4,3,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D3'],
 'W3C WebAuthn L2 · FIDO2 · NIST SP 800-63B §5.1.7',false,
 '{"attestation":"indirect","user_verification":"preferred","timeout_ms":60000,"rp_name":"SBOS Identity"}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'WebAuthn RP: attestation indirecta, user verification preferida, timeout 60s'),

('EXT_HOTP_POLICY','sbosSeeds.D3.extended',
 'sbosSeeds.D3.extended.ext_hotp_policy','sbosSeeds.D3.extended.ext_hotp_policy',
 4,4,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D3'],
 'RFC 4226 · NIST SP 800-63B §5.1.3',false,
 '{"algorithm":"HmacSHA1","digit_count":6,"counter_look_ahead":10,"resync_on_failure":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'HOTP: HmacSHA1, 6 dígitos, ventana adelanto 10, resincronización en fallo')

ON CONFLICT (path) DO NOTHING;

-- D3 PROPERTY hijos — EXT_PASSWORD_NIST63B
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    constraint_min, constraint_max, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('min_length','sbosSeeds.D3.extended.ext_password_nist63b',
 'sbosSeeds.D3.extended.ext_password_nist63b.min_length',
 'sbosSeeds.D3.extended.ext_password_nist63b.min_length',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'INTEGER','8',NULL,'8','256','NIST SP 800-63B §5.1.1.1',true,
 '"8"'::jsonb,'{}'::jsonb,'{}'::jsonb,'Longitud mínima de contraseña (NIST exige ≥ 8)'),

('max_length','sbosSeeds.D3.extended.ext_password_nist63b',
 'sbosSeeds.D3.extended.ext_password_nist63b.max_length',
 'sbosSeeds.D3.extended.ext_password_nist63b.max_length',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'INTEGER','64',NULL,'8','4096','NIST SP 800-63B §5.1.1.1',false,
 '"64"'::jsonb,'{}'::jsonb,'{}'::jsonb,'Longitud máxima (NIST exige aceptar ≥ 64)'),

('breach_check','sbosSeeds.D3.extended.ext_password_nist63b',
 'sbosSeeds.D3.extended.ext_password_nist63b.breach_check',
 'sbosSeeds.D3.extended.ext_password_nist63b.breach_check',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'BOOLEAN','true',NULL,NULL,NULL,'NIST SP 800-63B §5.1.1.2',true,
 '"true"'::jsonb,'{}'::jsonb,'{}'::jsonb,'Verificar contra bases de credenciales comprometidas'),

('complexity_required','sbosSeeds.D3.extended.ext_password_nist63b',
 'sbosSeeds.D3.extended.ext_password_nist63b.complexity_required',
 'sbosSeeds.D3.extended.ext_password_nist63b.complexity_required',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'BOOLEAN','false',NULL,NULL,NULL,'NIST SP 800-63B §5.1.1.2',false,
 '"false"'::jsonb,'{}'::jsonb,'{}'::jsonb,'NIST prohíbe requisitos de complejidad arbitrarios'),

('no_periodic_rotation','sbosSeeds.D3.extended.ext_password_nist63b',
 'sbosSeeds.D3.extended.ext_password_nist63b.no_periodic_rotation',
 'sbosSeeds.D3.extended.ext_password_nist63b.no_periodic_rotation',
 5,5,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'BOOLEAN','true',NULL,NULL,NULL,'NIST SP 800-63B §5.1.1.2',true,
 '"true"'::jsonb,'{}'::jsonb,'{}'::jsonb,'Sin rotación periódica forzada — solo en compromiso')

ON CONFLICT (path) DO NOTHING;

-- D3 PROPERTY hijos — EXT_TOTP_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('algorithm','sbosSeeds.D3.extended.ext_totp_policy',
 'sbosSeeds.D3.extended.ext_totp_policy.algorithm',
 'sbosSeeds.D3.extended.ext_totp_policy.algorithm',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'ENUM','HmacSHA256',ARRAY['HmacSHA1','HmacSHA256','HmacSHA512'],
 'RFC 6238',true,'"HmacSHA256"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('digit_count','sbosSeeds.D3.extended.ext_totp_policy',
 'sbosSeeds.D3.extended.ext_totp_policy.digit_count',
 'sbosSeeds.D3.extended.ext_totp_policy.digit_count',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'ENUM','6',ARRAY['6','8'],
 'RFC 6238',true,'"6"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('period_seconds','sbosSeeds.D3.extended.ext_totp_policy',
 'sbosSeeds.D3.extended.ext_totp_policy.period_seconds',
 'sbosSeeds.D3.extended.ext_totp_policy.period_seconds',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'ENUM','30',ARRAY['30','60'],
 'RFC 6238',true,'"30"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('look_ahead_window','sbosSeeds.D3.extended.ext_totp_policy',
 'sbosSeeds.D3.extended.ext_totp_policy.look_ahead_window',
 'sbosSeeds.D3.extended.ext_totp_policy.look_ahead_window',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'INTEGER','1',NULL,
 'RFC 6238 §5.2',false,'"1"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D3 PROPERTY hijos — EXT_WEBAUTHN_RP
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('attestation','sbosSeeds.D3.extended.ext_webauthn_rp',
 'sbosSeeds.D3.extended.ext_webauthn_rp.attestation',
 'sbosSeeds.D3.extended.ext_webauthn_rp.attestation',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'ENUM','indirect',ARRAY['none','indirect','direct','enterprise'],
 'W3C WebAuthn L2',false,'"indirect"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('user_verification','sbosSeeds.D3.extended.ext_webauthn_rp',
 'sbosSeeds.D3.extended.ext_webauthn_rp.user_verification',
 'sbosSeeds.D3.extended.ext_webauthn_rp.user_verification',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'ENUM','preferred',ARRAY['required','preferred','discouraged'],
 'W3C WebAuthn L2',true,'"preferred"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('timeout_ms','sbosSeeds.D3.extended.ext_webauthn_rp',
 'sbosSeeds.D3.extended.ext_webauthn_rp.timeout_ms',
 'sbosSeeds.D3.extended.ext_webauthn_rp.timeout_ms',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'INTEGER','60000',NULL,
 'W3C WebAuthn L2',false,'"60000"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('rp_name','sbosSeeds.D3.extended.ext_webauthn_rp',
 'sbosSeeds.D3.extended.ext_webauthn_rp.rp_name',
 'sbosSeeds.D3.extended.ext_webauthn_rp.rp_name',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D3'],
 'TEXT','SBOS Identity',NULL,
 'W3C WebAuthn L2',true,'"SBOS Identity"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- -----------------------------------------------------------------------------
-- D5 — POLÍTICA: ciclo de vida de credenciales
-- -----------------------------------------------------------------------------
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('EXT_CRED_LIFECYCLE','sbosSeeds.D5.extended',
 'sbosSeeds.D5.extended.ext_cred_lifecycle','sbosSeeds.D5.extended.ext_cred_lifecycle',
 4,1,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D5'],
 'NIST SP 800-63B §5.1 · OWASP ASVS v5.0 §2.1',false,
 '{"rotation_on_breach":true,"periodic_rotation":false,"min_age_hours":24,"history_count":10}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Ciclo de vida: rotación solo en compromiso, sin rotación periódica (NIST 800-63B Rev.4)'),

('EXT_RECOVERY_CODES','sbosSeeds.D5.extended',
 'sbosSeeds.D5.extended.ext_recovery_codes','sbosSeeds.D5.extended.ext_recovery_codes',
 4,2,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D5'],
 'NIST SP 800-63B §5.1.12 · OWASP ASVS v5.0 §2.5',false,
 '{"count":10,"length":10,"single_use":true,"algorithm":"DICEWARE","hash":"Argon2id"}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Códigos de recuperación: 10 códigos DICEWARE de 10 chars, uso único, hash Argon2id'),

('EXT_API_KEY_POLICY','sbosSeeds.D5.extended',
 'sbosSeeds.D5.extended.ext_api_key_policy','sbosSeeds.D5.extended.ext_api_key_policy',
 4,3,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D5'],
 'NIST SP 800-63B · OWASP API Security Top 10',false,
 '{"max_age_days":365,"rotation_warning_days":30,"prefix":"sbos_","hash":"SHA-256","revocable":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'API Keys: vigencia 365d, aviso 30d antes, prefijo sbos_, hash SHA-256, revocables'),

('EXT_CERT_POLICY','sbosSeeds.D5.extended',
 'sbosSeeds.D5.extended.ext_cert_policy','sbosSeeds.D5.extended.ext_cert_policy',
 4,4,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D5'],
 'RFC 5280 · Ley 164 Bolivia · ADSIB-FD-POLT-015 v2.3',false,
 '{"validity_days":365,"renewal_window_days":30,"algorithm":"Ed25519","revocation_check":"OCSP"}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Certificados: vigencia 365d, renovación 30d antes, Ed25519, verificación OCSP')

ON CONFLICT (path) DO NOTHING;

-- D5 PROPERTY hijos — EXT_CRED_LIFECYCLE
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('rotation_on_breach','sbosSeeds.D5.extended.ext_cred_lifecycle',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.rotation_on_breach',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.rotation_on_breach',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'BOOLEAN','true',NULL,'NIST SP 800-63B §5.1',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('periodic_rotation','sbosSeeds.D5.extended.ext_cred_lifecycle',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.periodic_rotation',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.periodic_rotation',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'BOOLEAN','false',NULL,'NIST SP 800-63B §5.1 (prohibido forzar)',true,'"false"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('min_age_hours','sbosSeeds.D5.extended.ext_cred_lifecycle',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.min_age_hours',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.min_age_hours',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'INTEGER','24',NULL,'NIST SP 800-63B',false,'"24"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('history_count','sbosSeeds.D5.extended.ext_cred_lifecycle',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.history_count',
 'sbosSeeds.D5.extended.ext_cred_lifecycle.history_count',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'INTEGER','10',NULL,'OWASP ASVS v5.0 §2.1',false,'"10"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D5 PROPERTY hijos — EXT_RECOVERY_CODES
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('count','sbosSeeds.D5.extended.ext_recovery_codes',
 'sbosSeeds.D5.extended.ext_recovery_codes.count',
 'sbosSeeds.D5.extended.ext_recovery_codes.count',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'ENUM','10',ARRAY['8','10','12','16'],'NIST SP 800-63B §5.1.12',true,'"10"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('length','sbosSeeds.D5.extended.ext_recovery_codes',
 'sbosSeeds.D5.extended.ext_recovery_codes.length',
 'sbosSeeds.D5.extended.ext_recovery_codes.length',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'ENUM','10',ARRAY['8','10','12'],'NIST SP 800-63B',true,'"10"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('single_use','sbosSeeds.D5.extended.ext_recovery_codes',
 'sbosSeeds.D5.extended.ext_recovery_codes.single_use',
 'sbosSeeds.D5.extended.ext_recovery_codes.single_use',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'BOOLEAN','true',NULL,'NIST SP 800-63B',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('algorithm','sbosSeeds.D5.extended.ext_recovery_codes',
 'sbosSeeds.D5.extended.ext_recovery_codes.algorithm',
 'sbosSeeds.D5.extended.ext_recovery_codes.algorithm',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'ENUM','DICEWARE',ARRAY['DICEWARE','BASE32','HEX','ALPHANUMERIC'],'NIST SP 800-63B',true,
 '"DICEWARE"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D5 PROPERTY hijos — EXT_CERT_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('algorithm','sbosSeeds.D5.extended.ext_cert_policy',
 'sbosSeeds.D5.extended.ext_cert_policy.algorithm',
 'sbosSeeds.D5.extended.ext_cert_policy.algorithm',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'ENUM','Ed25519',ARRAY['RSA-4096','Ed25519','ECDSA-P384'],
 'RFC 5280 · Ley 164 Bolivia',true,'"Ed25519"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('revocation_check','sbosSeeds.D5.extended.ext_cert_policy',
 'sbosSeeds.D5.extended.ext_cert_policy.revocation_check',
 'sbosSeeds.D5.extended.ext_cert_policy.revocation_check',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'ENUM','OCSP',ARRAY['OCSP','CRL','both','none'],
 'RFC 6960 (OCSP)',true,'"OCSP"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('validity_days','sbosSeeds.D5.extended.ext_cert_policy',
 'sbosSeeds.D5.extended.ext_cert_policy.validity_days',
 'sbosSeeds.D5.extended.ext_cert_policy.validity_days',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D5'],
 'INTEGER','365',NULL,'RFC 5280',false,'"365"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- -----------------------------------------------------------------------------
-- D6 — POLÍTICA: sesiones y tokens JWT
-- -----------------------------------------------------------------------------
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('EXT_SESSION_TIMEOUT','sbosSeeds.D6.extended',
 'sbosSeeds.D6.extended.ext_session_timeout','sbosSeeds.D6.extended.ext_session_timeout',
 4,1,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D6'],
 'NIST SP 800-63B §7.1 · OWASP ASVS v5.0 §3.3',false,
 '{"absolute_aal1_min":480,"absolute_aal2_min":720,"absolute_aal3_min":60,"idle_aal1_min":30,"idle_aal2_min":15,"idle_aal3_min":5}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Timeout por AAL: AAL1=8h abs/30m idle, AAL2=12h/15m, AAL3=1h/5m'),

('EXT_TOKEN_TTL','sbosSeeds.D6.extended',
 'sbosSeeds.D6.extended.ext_token_ttl','sbosSeeds.D6.extended.ext_token_ttl',
 4,2,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D6'],
 'RFC 6749 §4 · RFC 9449 DPoP · OIDC Core 1.0',false,
 '{"access_token_seconds":900,"refresh_token_hours":24,"id_token_seconds":300}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'TTL de tokens: access=15min, refresh=24h, id_token=5min'),

('EXT_CONCURRENT_SESSIONS','sbosSeeds.D6.extended',
 'sbosSeeds.D6.extended.ext_concurrent_sessions','sbosSeeds.D6.extended.ext_concurrent_sessions',
 4,3,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D6'],
 'NIST SP 800-53 Rev.5 AC-10 · ISO 27001:2022 A.5.15',false,
 '{"max_per_user":5,"max_per_tier_su":1,"max_per_tier_sys":3,"on_limit":"revoke_oldest"}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Sesiones concurrentes: máx 5/usuario, 1 para SU, 3 para SYS')

ON CONFLICT (path) DO NOTHING;

-- D6 PROPERTY hijos — EXT_SESSION_TIMEOUT
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('absolute_aal1_min','sbosSeeds.D6.extended.ext_session_timeout',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal1_min',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal1_min',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','480','NIST SP 800-63B §7.1',false,'"480"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('absolute_aal2_min','sbosSeeds.D6.extended.ext_session_timeout',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal2_min',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal2_min',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','720','NIST SP 800-63B §7.1',false,'"720"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('absolute_aal3_min','sbosSeeds.D6.extended.ext_session_timeout',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal3_min',
 'sbosSeeds.D6.extended.ext_session_timeout.absolute_aal3_min',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','60','NIST SP 800-63B §7.1',true,'"60"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('idle_aal1_min','sbosSeeds.D6.extended.ext_session_timeout',
 'sbosSeeds.D6.extended.ext_session_timeout.idle_aal1_min',
 'sbosSeeds.D6.extended.ext_session_timeout.idle_aal1_min',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','30','NIST SP 800-63B §7.1',false,'"30"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('idle_aal3_min','sbosSeeds.D6.extended.ext_session_timeout',
 'sbosSeeds.D6.extended.ext_session_timeout.idle_aal3_min',
 'sbosSeeds.D6.extended.ext_session_timeout.idle_aal3_min',
 5,5,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','5','NIST SP 800-63B §7.1',true,'"5"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D6 PROPERTY hijos — EXT_TOKEN_TTL
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('access_token_seconds','sbosSeeds.D6.extended.ext_token_ttl',
 'sbosSeeds.D6.extended.ext_token_ttl.access_token_seconds',
 'sbosSeeds.D6.extended.ext_token_ttl.access_token_seconds',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','900','RFC 6749 §4',true,'"900"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('refresh_token_hours','sbosSeeds.D6.extended.ext_token_ttl',
 'sbosSeeds.D6.extended.ext_token_ttl.refresh_token_hours',
 'sbosSeeds.D6.extended.ext_token_ttl.refresh_token_hours',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','24','RFC 6749',false,'"24"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('id_token_seconds','sbosSeeds.D6.extended.ext_token_ttl',
 'sbosSeeds.D6.extended.ext_token_ttl.id_token_seconds',
 'sbosSeeds.D6.extended.ext_token_ttl.id_token_seconds',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','300','OIDC Core §2',false,'"300"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D6 PROPERTY hijos — EXT_CONCURRENT_SESSIONS
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('max_per_user','sbosSeeds.D6.extended.ext_concurrent_sessions',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.max_per_user',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.max_per_user',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','5',NULL,'NIST SP 800-53 AC-10',false,'"5"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('max_per_tier_su','sbosSeeds.D6.extended.ext_concurrent_sessions',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.max_per_tier_su',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.max_per_tier_su',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'INTEGER','1',NULL,'ISO 27001 A.5.18',true,'"1"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('on_limit','sbosSeeds.D6.extended.ext_concurrent_sessions',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.on_limit',
 'sbosSeeds.D6.extended.ext_concurrent_sessions.on_limit',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D6'],
 'ENUM','revoke_oldest',ARRAY['block','revoke_oldest','warn','notify_only'],
 'NIST SP 800-53 AC-10',false,'"revoke_oldest"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- -----------------------------------------------------------------------------
-- D10 — POLÍTICA: federación OAuth2 / OIDC / SAML
-- -----------------------------------------------------------------------------
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('EXT_PKCE_POLICY','sbosSeeds.D10.extended',
 'sbosSeeds.D10.extended.ext_pkce_policy','sbosSeeds.D10.extended.ext_pkce_policy',
 4,1,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D10'],
 'RFC 7636 · OAuth 2.1 draft · FAPI 2.0',false,
 '{"required":true,"method":"S256","plain_allowed":false}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'PKCE obligatorio: S256, prohibir plain'),

('EXT_OAUTH2_SECURITY','sbosSeeds.D10.extended',
 'sbosSeeds.D10.extended.ext_oauth2_security','sbosSeeds.D10.extended.ext_oauth2_security',
 4,2,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D10'],
 'RFC 6749 · RFC 7636 · RFC 9449 · OAuth 2.1',false,
 '{"state_required":true,"redirect_exact_match":true,"token_endpoint_auth":"client_secret_basic","refresh_rotation":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'OAuth 2.0: state obligatorio, redirect exacta, autenticación de cliente, rotación de refresh'),

('EXT_SAML_POLICY','sbosSeeds.D10.extended',
 'sbosSeeds.D10.extended.ext_saml_policy','sbosSeeds.D10.extended.ext_saml_policy',
 4,3,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D10'],
 'SAML 2.0 · NIST SP 800-63C',false,
 '{"assertion_validity_s":300,"clock_skew_s":60,"sign_assertions":true,"encrypt_assertions":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'SAML 2.0: assertions válidas 5min, skew 60s, firma y cifrado obligatorios'),

('EXT_OIDC_POLICY','sbosSeeds.D10.extended',
 'sbosSeeds.D10.extended.ext_oidc_policy','sbosSeeds.D10.extended.ext_oidc_policy',
 4,4,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D10'],
 'OIDC Core 1.0 · NIST SP 800-63C §6',false,
 '{"response_type":"code","id_token_algorithm":"RS256","nonce_required":true}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'OIDC: flujo code, RS256, nonce obligatorio en authn request')

ON CONFLICT (path) DO NOTHING;

-- D10 PROPERTY hijos — EXT_PKCE_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('required','sbosSeeds.D10.extended.ext_pkce_policy',
 'sbosSeeds.D10.extended.ext_pkce_policy.required',
 'sbosSeeds.D10.extended.ext_pkce_policy.required',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'BOOLEAN','true',NULL,'RFC 7636',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('method','sbosSeeds.D10.extended.ext_pkce_policy',
 'sbosSeeds.D10.extended.ext_pkce_policy.method',
 'sbosSeeds.D10.extended.ext_pkce_policy.method',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'ENUM','S256',ARRAY['S256','plain'],'RFC 7636 §4.2',true,'"S256"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('plain_allowed','sbosSeeds.D10.extended.ext_pkce_policy',
 'sbosSeeds.D10.extended.ext_pkce_policy.plain_allowed',
 'sbosSeeds.D10.extended.ext_pkce_policy.plain_allowed',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'BOOLEAN','false',NULL,'RFC 7636 §7.2',true,'"false"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D10 PROPERTY hijos — EXT_SAML_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('assertion_validity_s','sbosSeeds.D10.extended.ext_saml_policy',
 'sbosSeeds.D10.extended.ext_saml_policy.assertion_validity_s',
 'sbosSeeds.D10.extended.ext_saml_policy.assertion_validity_s',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'INTEGER','300',NULL,'SAML 2.0',true,'"300"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('clock_skew_s','sbosSeeds.D10.extended.ext_saml_policy',
 'sbosSeeds.D10.extended.ext_saml_policy.clock_skew_s',
 'sbosSeeds.D10.extended.ext_saml_policy.clock_skew_s',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'INTEGER','60',NULL,'SAML 2.0',false,'"60"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('sign_assertions','sbosSeeds.D10.extended.ext_saml_policy',
 'sbosSeeds.D10.extended.ext_saml_policy.sign_assertions',
 'sbosSeeds.D10.extended.ext_saml_policy.sign_assertions',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'BOOLEAN','true',NULL,'SAML 2.0 · ISO 27001 A.8.24',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('encrypt_assertions','sbosSeeds.D10.extended.ext_saml_policy',
 'sbosSeeds.D10.extended.ext_saml_policy.encrypt_assertions',
 'sbosSeeds.D10.extended.ext_saml_policy.encrypt_assertions',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'BOOLEAN','true',NULL,'SAML 2.0 · NIST SP 800-63C',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D10 PROPERTY hijos — EXT_OIDC_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('response_type','sbosSeeds.D10.extended.ext_oidc_policy',
 'sbosSeeds.D10.extended.ext_oidc_policy.response_type',
 'sbosSeeds.D10.extended.ext_oidc_policy.response_type',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'ENUM','code',ARRAY['code','id_token','token','code id_token'],
 'OIDC Core 1.0',true,'"code"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('id_token_algorithm','sbosSeeds.D10.extended.ext_oidc_policy',
 'sbosSeeds.D10.extended.ext_oidc_policy.id_token_algorithm',
 'sbosSeeds.D10.extended.ext_oidc_policy.id_token_algorithm',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'ENUM','RS256',ARRAY['RS256','ES256','PS256'],
 'OIDC Core 1.0 §2',true,'"RS256"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('nonce_required','sbosSeeds.D10.extended.ext_oidc_policy',
 'sbosSeeds.D10.extended.ext_oidc_policy.nonce_required',
 'sbosSeeds.D10.extended.ext_oidc_policy.nonce_required',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D10'],
 'BOOLEAN','true',NULL,
 'OIDC Core 1.0 (protección replay)',true,'"true"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- -----------------------------------------------------------------------------
-- D12 — POLÍTICA: biometría FIDO2 / ISO 19794
-- -----------------------------------------------------------------------------
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, standard_ref, is_required,
    content, content_en, content_es, description
) VALUES
('EXT_FINGERPRINT_POLICY','sbosSeeds.D12.extended',
 'sbosSeeds.D12.extended.ext_fingerprint_policy','sbosSeeds.D12.extended.ext_fingerprint_policy',
 4,1,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ISO/IEC 19794-2 · NIST SP 800-76 · FIDO CTAP2',false,
 '{"min_minutiae":12,"liveness_detection":"passive","far_threshold":0.00001,"frr_threshold":0.02}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Huella dactilar: 12 minucias mínimo, liveness pasiva, FAR < 0.001%, FRR < 2%'),

('EXT_FACIAL_RECOG_POLICY','sbosSeeds.D12.extended',
 'sbosSeeds.D12.extended.ext_facial_recog_policy','sbosSeeds.D12.extended.ext_facial_recog_policy',
 4,2,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ISO/IEC 19794-5 · NIST FRVT · FIDO BioMetrics SIG',false,
 '{"min_confidence":0.95,"liveness_detection":"active","vendor_agnostic":true,"data_retention_days":0}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Reconocimiento facial: confianza 95%, liveness activa, no retener datos biométricos'),

('EXT_BIOMETRIC_ENROLLMENT','sbosSeeds.D12.extended',
 'sbosSeeds.D12.extended.ext_biometric_enrollment','sbosSeeds.D12.extended.ext_biometric_enrollment',
 4,3,'policy','POLICY','sbos_seeds_v1_2026',ARRAY['D12'],
 'NIST SP 800-63A §5 · ISO/IEC 29794-1 · FIDO2',false,
 '{"samples_required":3,"quality_threshold":0.8,"enrollment_ial":"IAL2","allow_self_enrollment":false}'::jsonb,
 '{}'::jsonb,'{}'::jsonb,
 'Enrolamiento biométrico: 3 muestras, calidad > 80%, IAL2, supervisado')

ON CONFLICT (path) DO NOTHING;

-- D12 PROPERTY hijos — EXT_FINGERPRINT_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('min_minutiae','sbosSeeds.D12.extended.ext_fingerprint_policy',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.min_minutiae',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.min_minutiae',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'INTEGER','12',NULL,'ISO/IEC 19794-2',true,'"12"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('liveness_detection','sbosSeeds.D12.extended.ext_fingerprint_policy',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.liveness_detection',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.liveness_detection',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ENUM','passive',ARRAY['none','passive','active'],
 'FIDO Alliance PAD Spec',true,'"passive"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('far_threshold','sbosSeeds.D12.extended.ext_fingerprint_policy',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.far_threshold',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.far_threshold',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'FLOAT','0.00001',NULL,'NIST SP 800-76',true,'"0.00001"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('frr_threshold','sbosSeeds.D12.extended.ext_fingerprint_policy',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.frr_threshold',
 'sbosSeeds.D12.extended.ext_fingerprint_policy.frr_threshold',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'FLOAT','0.02',NULL,'NIST SP 800-76',false,'"0.02"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D12 PROPERTY hijos — EXT_FACIAL_RECOG_POLICY
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('min_confidence','sbosSeeds.D12.extended.ext_facial_recog_policy',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.min_confidence',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.min_confidence',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'FLOAT','0.95',NULL,'NIST FRVT',true,'"0.95"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('liveness_detection','sbosSeeds.D12.extended.ext_facial_recog_policy',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.liveness_detection',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.liveness_detection',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ENUM','active',ARRAY['none','passive','active'],
 'ISO/IEC 30107-3',true,'"active"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('data_retention_days','sbosSeeds.D12.extended.ext_facial_recog_policy',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.data_retention_days',
 'sbosSeeds.D12.extended.ext_facial_recog_policy.data_retention_days',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ENUM','0',ARRAY['0','30','90','365'],
 'GDPR Art.5 · LOPD Bolivia',true,'"0"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

-- D12 PROPERTY hijos — EXT_BIOMETRIC_ENROLLMENT
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, value_type, default_value, enum_options,
    standard_ref, is_required, content, content_en, content_es
) VALUES
('samples_required','sbosSeeds.D12.extended.ext_biometric_enrollment',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.samples_required',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.samples_required',
 5,1,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'INTEGER','3',NULL,'NIST SP 800-63A §5.3',true,'"3"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('quality_threshold','sbosSeeds.D12.extended.ext_biometric_enrollment',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.quality_threshold',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.quality_threshold',
 5,2,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'FLOAT','0.8',NULL,'ISO/IEC 29794-1',true,'"0.8"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('enrollment_ial','sbosSeeds.D12.extended.ext_biometric_enrollment',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.enrollment_ial',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.enrollment_ial',
 5,3,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'ENUM','IAL2',ARRAY['IAL1','IAL2','IAL3'],
 'NIST SP 800-63A',true,'"IAL2"'::jsonb,'{}'::jsonb,'{}'::jsonb),

('allow_self_enrollment','sbosSeeds.D12.extended.ext_biometric_enrollment',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.allow_self_enrollment',
 'sbosSeeds.D12.extended.ext_biometric_enrollment.allow_self_enrollment',
 5,4,'config','PROPERTY','sbos_seeds_v1_2026',ARRAY['D12'],
 'BOOLEAN','false',NULL,'NIST SP 800-63A §5 (supervisado)',true,'"false"'::jsonb,'{}'::jsonb,'{}'::jsonb)

ON CONFLICT (path) DO NOTHING;

COMMIT;

-- =============================================================================
-- VERIFICACIÓN — ejecutar separadamente después del COMMIT
-- =============================================================================
-- SELECT source, level_type, COUNT(*)
-- FROM bauth.cfg_policy_library
-- WHERE source = 'sbos_seeds_v1_2026'
-- GROUP BY source, level_type
-- ORDER BY level_type;
--
-- SELECT d.dn, COUNT(*) AS total_nodos
-- FROM (VALUES('D1'),('D2'),('D3'),('D4'),('D5'),('D6'),
--            ('D7'),('D8'),('D9'),('D10'),('D11'),('D12'),('D99')) d(dn)
-- LEFT JOIN bauth.cfg_policy_library c ON c.domain_map @> ARRAY[d.dn]
-- GROUP BY d.dn ORDER BY d.dn;
--
-- SELECT value_type, COUNT(*) FILTER (WHERE enum_options IS NOT NULL) AS con_enum, COUNT(*) total
-- FROM bauth.cfg_policy_library WHERE level_type IN ('PROPERTY','RULE') GROUP BY value_type;
