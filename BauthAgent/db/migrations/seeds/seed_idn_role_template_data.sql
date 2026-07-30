-- ============================================================================
-- seed_idn_role_template_data.sql — Templates JSONB 14 secciones RolTemplate v6.0
-- IDEMPOTENTE: UPDATE para todos los roles existentes
-- Cada sección consulta tablas DDL reales: available* = catálogo, selected* = rol
-- Fuente: BAUTH-ROLTEMPLATE-SECCIONES.md v6.0 · DDL_skSBOS_db.sql (179 tablas)
-- ============================================================================

SET lock_timeout = '5s';

UPDATE bauth.idn_role_template r SET
  template_version = '6.0.0',
  template = jsonb_build_object(

    -- ═══════════════════════════════════════════════
    -- BLOQUE 1 — IDENTIDAD (cabecera del rol)
    -- ═══════════════════════════════════════════════
    'role', jsonb_build_object(
      'id', r.id,
      'parent_id', CASE WHEN r.parent_id = '' THEN null ELSE r.parent_id END,
      'type_id', r.type_id,
      'hierarchy_level', r.hierarchy_level,
      'version', '6.0.0',
      'status', r.status,
      'tier', r.tier,
      'loa_required', r.loa_required,
      'mfa_required', r.mfa_required,
      'name', COALESCE(r.template->'role'->'name', r.template->'name', jsonb_build_object('es', r.id, 'en', r.id)),
      'description', COALESCE(r.template->'role'->'description', r.template->'description', jsonb_build_object('es', 'Rol ' || r.id, 'en', 'Role ' || r.id)),
      'metadata', jsonb_build_object(
        'tier', r.tier,
        'audit_level', r.audit_level,
        'sync_status', r.sync_status,
        'version', '6.0.0'
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 2 — logical_access (D1) desde log_zone + privilege_*
    -- ═══════════════════════════════════════════════
    'logical_access', (
      WITH zones AS (
        SELECT jsonb_agg(jsonb_build_object(
          'zone_code', zona_id,
          'zone_name', COALESCE(nombre, zona_id),
          'category', COALESCE(categoria, 'OPERATIVA'),
          'is_critical', COALESCE(es_critica, false)
        )) AS available
        FROM bauth.log_zone WHERE activo = true
      ),
      role_zones AS (
        SELECT jsonb_agg(zona_id) AS selected
        FROM bauth.log_zone WHERE activo = true
          AND CASE WHEN r.tier IN ('SU','SYS','BIZ_N1','BIZ_N2','M2M') THEN true
                   WHEN r.tier IN ('BIZ_N3','BIZ_N4') THEN COALESCE(categoria,'OPERATIVA') IN ('OPERATIVA','COMERCIAL','ADMINISTRATIVA')
                   WHEN r.tier = 'BIZ_N5' THEN COALESCE(categoria,'OPERATIVA') IN ('OPERATIVA','ADMINISTRATIVA')
                   ELSE COALESCE(categoria,'COMERCIAL') = 'COMERCIAL' END
        LIMIT 5
      ),
      apps AS (
        SELECT jsonb_agg(jsonb_build_object('app_code', app_code, 'app_name', COALESCE(app_name, app_code::text))) AS available
        FROM bauth.privilege_application WHERE active = true
      ),
      verbs AS (
        SELECT jsonb_agg(DISTINCT verb_code ORDER BY verb_code) AS all_verbs
        FROM bauth.privilege_verb WHERE verb_code BETWEEN 1 AND 4
      )
      SELECT jsonb_build_object(
        'availableZones', COALESCE((SELECT available FROM zones), '[]'::jsonb),
        'selectedZones', COALESCE((SELECT selected FROM role_zones), '[]'::jsonb),
        'availableApplications', COALESCE((SELECT available FROM apps), '[]'::jsonb),
        'availableVerbs', COALESCE((SELECT all_verbs FROM verbs), '[1,2,3,4]'::jsonb),
        'selectedVerbs', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1','BIZ_N2','M2M') THEN '[1,2,3,4]'::jsonb
                              WHEN r.tier IN ('BIZ_N3','BIZ_N4') THEN '[1,2,4]'::jsonb
                              WHEN r.tier = 'BIZ_N5' THEN '[1,4]'::jsonb
                              ELSE '[4]'::jsonb END,
        'scope', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1','BIZ_N2','M2M') THEN 'GLOBAL'
                      WHEN r.tier IN ('BIZ_N3','BIZ_N4') THEN 'COMPANY'
                      WHEN r.tier = 'BIZ_N5' THEN 'BRANCH'
                      ELSE 'PERSONAL' END,
        'dataClassification', CASE WHEN r.audit_level = 'full' THEN 'RESTRICTED'
                                     WHEN r.audit_level = 'basic' THEN 'INTERNAL'
                                     ELSE 'PUBLIC' END
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 3 — physical_access (D2) desde fis_*
    -- ═══════════════════════════════════════════════
    'physical_access', (
      WITH zones AS (
        SELECT jsonb_agg(jsonb_build_object(
          'zone_id', az.zone_id, 'name', az.name
        )) AS available
        FROM bauth.fis_access_zone az
      ),
      methods AS (
        SELECT jsonb_agg(jsonb_build_object(
          'zone_level', zone_level, 'method_id', method_id, 'loa_required', loa_required
        )) AS zone_methods
        FROM bauth.fis_zone_method_requirement
      )
      SELECT jsonb_build_object(
        'availableZones', COALESCE((SELECT available FROM zones), '[]'::jsonb),
        'selectedZones', '[]'::jsonb,
        'zoneMethods', COALESCE((SELECT zone_methods FROM methods), '[]'::jsonb),
        'maxSecurityZone', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN 5
                                 WHEN r.tier = 'BIZ_N2' THEN 4
                                 WHEN r.tier IN ('BIZ_N3','BIZ_N4') THEN 3
                                 ELSE 2 END,
        'requiresEscort', r.tier IN ('VISITANTE','EXT_N0'),
        'requiresTwoPerson', r.tier IN ('SU','SYS') AND r.audit_level = 'full'
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 4 — financial (D3) desde fin_*
    -- ═══════════════════════════════════════════════
    'financial', (
      WITH all_types AS (
        SELECT jsonb_agg(jsonb_build_object(
          'code', code, 'name', name, 'category', category,
          'riskLevel', risk_level, 'controls', COALESCE(controls, '{}'::jsonb)
        )) AS available
        FROM bauth.fin_transaction_type WHERE is_active = true
      ),
      role_limits AS (
        SELECT jsonb_agg(jsonb_build_object(
          'transactionType', code,
          'maxAmount', CASE WHEN r.tier IN ('SU','SYS') THEN 999999999
                             WHEN r.tier = 'BIZ_N1' THEN 100000
                             WHEN r.tier = 'BIZ_N2' THEN 50000
                             WHEN r.tier = 'BIZ_N3' THEN 10000
                             WHEN r.tier = 'BIZ_N4' THEN 2000
                             WHEN r.tier = 'BIZ_N5' THEN 500
                             ELSE 0 END,
          'period', 'daily',
          'requiresDualApproval', r.tier IN ('BIZ_N2','BIZ_N3') AND COALESCE(risk_level,'BAJO') = 'CRITICO'
        )) AS limits
        FROM bauth.fin_transaction_type WHERE is_active = true
      ),
      sod_rules AS (
        SELECT jsonb_agg(jsonb_build_object(
          'position_a', position_a, 'position_b', position_b, 'riskLevel', COALESCE(risk_level,'HIGH')
        )) AS active_sod
        FROM bauth.fin_sod_rule
      )
      SELECT jsonb_build_object(
        'availableTransactionTypes', COALESCE((SELECT available FROM all_types), '[]'::jsonb),
        'limits', COALESCE((SELECT limits FROM role_limits), '[]'::jsonb),
        'requiresDualApproval', r.tier IN ('BIZ_N2','BIZ_N3'),
        'maxApprovalAmount', CASE WHEN r.tier IN ('SU','SYS') THEN 999999999
                                   WHEN r.tier = 'BIZ_N1' THEN 100000
                                   WHEN r.tier = 'BIZ_N2' THEN 50000
                                   WHEN r.tier = 'BIZ_N3' THEN 10000
                                   WHEN r.tier = 'BIZ_N4' THEN 2000
                                   ELSE 0 END,
        'activeSoDRules', COALESCE((SELECT active_sod FROM sod_rules), '[]'::jsonb)
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 5 — temporal (D4) desde cal_*
    -- ═══════════════════════════════════════════════
    'temporal', (
      WITH schedules AS (
        SELECT jsonb_agg(jsonb_build_object(
          'schedule_id', schedule_id, 'name', name,
          'days_of_week', days_of_week, 'start_time', start_time, 'end_time', end_time,
          'schedule_type', schedule_type
        )) AS available
        FROM bcalendar.cal_schedule
      ),
      holidays AS (
        SELECT jsonb_agg(jsonb_build_object(
          'name', name, 'date', holiday_date, 'country', country_code, 'is_recurring', is_recurring
        )) AS all_holidays
        FROM bcalendar.cal_holiday WHERE country_code = 'BO'
      ),
      overtime AS (
        SELECT jsonb_build_object(
          'max_daily_hours', max_daily_hours, 'rate_multiplier', rate_multiplier,
          'requires_approval', requires_approval
        ) AS policy
        FROM bcalendar.cal_overtime_policy WHERE is_active = true LIMIT 1
      ),
      breaks AS (
        SELECT jsonb_build_object(
          'lunch_minutes', lunch_duration_minutes, 'short_break_minutes', short_break_minutes,
          'short_breaks_per_day', short_breaks_allowed
        ) AS policy
        FROM bcalendar.cal_break_policy WHERE is_active = true LIMIT 1
      )
      SELECT jsonb_build_object(
        'availableSchedules', COALESCE((SELECT available FROM schedules), '[]'::jsonb),
        'selectedScheduleId', (SELECT schedule_id FROM bcalendar.cal_schedule WHERE is_default = true LIMIT 1),
        'holidays', COALESCE((SELECT all_holidays FROM holidays), '[]'::jsonb),
        'overtimePolicy', COALESCE((SELECT policy FROM overtime), '{}'::jsonb),
        'breakPolicy', COALESCE((SELECT policy FROM breaks), '{}'::jsonb),
        'allowOvertime', r.tier IN ('SU','SYS','BIZ_N1','BIZ_N2'),
        'requiresApprovalOutside', r.tier NOT IN ('SU','SYS','BIZ_N1')
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 6 — biometric (D5) desde ath_method + ath_policy_d5 + ath_config_d5
    -- ═══════════════════════════════════════════════
    'biometric', (
      WITH methods AS (
        SELECT jsonb_agg(jsonb_build_object(
          'method_id', method_id, 'method_name', method_name,
          'method_type', method_type, 'aal_level', aal_level
        )) AS available
        FROM bauth.ath_method WHERE active = true
          AND (method_name ILIKE '%finger%' OR method_name ILIKE '%face%' OR method_name ILIKE '%iris%'
               OR method_name ILIKE '%bio%' OR method_name ILIKE '%touch%' OR method_name ILIKE '%voice%'
               OR method_id IN ('FINGERPRINT','FACE_ID','TOUCH_ID','IRIS_SCAN'))
      ),
      policies AS (
        SELECT jsonb_agg(jsonb_build_object('code', policy_code, 'name', policy_name, 'config', config)) AS active
        FROM bauth.ath_policy_d5 WHERE is_active = true
      ),
      configs AS (
        SELECT jsonb_agg(jsonb_build_object('key', config_key, 'value', config_value)) AS defaults
        FROM bauth.ath_config_d5 WHERE is_active = true
      )
      SELECT jsonb_build_object(
        'availableMethods', COALESCE((SELECT available FROM methods), '[]'::jsonb),
        'policies', COALESCE((SELECT active FROM policies), '[]'::jsonb),
        'configDefaults', COALESCE((SELECT defaults FROM configs), '[]'::jsonb),
        'fmrThreshold', CASE WHEN r.loa_required >= 3 THEN 0.0001 ELSE 0.001 END,
        'livenessRequired', r.loa_required >= 2,
        'enrollmentSupervised', r.tier IN ('SU','SYS','BIZ_N1','BIZ_N2')
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 7 — geospatial (D6) desde geo_*
    -- ═══════════════════════════════════════════════
    'geospatial', (
      WITH fences AS (
        SELECT jsonb_agg(jsonb_build_object('fence_id', fence_id, 'name', fence_name, 'center', center_point::text, 'radius_m', radius_meters)) AS available
        FROM bauth.geo_fence WHERE is_active = true
      ),
      trust_tiers AS (
        SELECT jsonb_agg(jsonb_build_object('tier_name', tier_name, 'tier_level', tier_level, 'requires_step_up', requires_step_up)) AS tiers
        FROM bauth.geo_trust_tier WHERE is_active = true
      ),
      velocity AS (
        SELECT jsonb_build_object('max_kmh', max_velocity_kmh, 'on_violation', on_violation) AS policy
        FROM bauth.geo_velocity_policy WHERE is_active = true LIMIT 1
      )
      SELECT jsonb_build_object(
        'availableGeoFences', COALESCE((SELECT available FROM fences), '[]'::jsonb),
        'trustTiers', COALESCE((SELECT tiers FROM trust_tiers), '[]'::jsonb),
        'velocityPolicy', COALESCE((SELECT policy FROM velocity), '{}'::jsonb),
        'homeCountry', 'BO',
        'allowedCountries', jsonb_build_array('BO','AR','BR','CL','PE'),
        'crossBorderBlocked', r.tier NOT IN ('SU','SYS','BIZ_N1')
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 8 — network (D7) desde net_* + idn_tenant_network
    -- ═══════════════════════════════════════════════
    'network', (
      WITH networks AS (
        SELECT jsonb_agg(jsonb_build_object('name', name, 'cidr', cidr, 'network_type', network_type)) AS available
        FROM bauth.idn_tenant_network WHERE is_active = true
      ),
      devices AS (
        SELECT jsonb_agg(jsonb_build_object('device_type', device_type, 'status', status, 'firmware_version', firmware_version)) AS available
        FROM bauth.net_device WHERE status = 'ACTIVE'
      ),
      ztna AS (
        SELECT jsonb_build_object('default_action', default_action, 'microsegmentation', microsegmentation) AS policy
        FROM bauth.net_ztna_policy WHERE is_active = true LIMIT 1
      )
      SELECT jsonb_build_object(
        'availableNetworks', COALESCE((SELECT available FROM networks), '[]'::jsonb),
        'availableDeviceTypes', COALESCE((SELECT available FROM devices), '[]'::jsonb),
        'ztnaPolicy', COALESCE((SELECT policy FROM ztna), '{}'::jsonb),
        'vpnRequired', r.tier NOT IN ('SU','SYS'),
        'mTLSRequired', true,
        'deviceTrustMin', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN 80
                                WHEN r.tier IN ('BIZ_N2','BIZ_N3') THEN 60
                                ELSE 40 END
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 9 — context (D8) desde ses_*
    -- ═══════════════════════════════════════════════
    'context', (
      WITH risk AS (
        SELECT jsonb_build_object('risk_factors', risk_factors, 'threshold_high', threshold_high, 'action_critical', action_critical) AS policy
        FROM bauth.ses_ses_risk_policy WHERE is_active = true LIMIT 1
      ),
      caep AS (
        SELECT jsonb_agg(jsonb_build_object('event', caep_event, 'enabled', is_enabled)) AS events
        FROM bauth.ses_caep_config WHERE is_enabled = true
      )
      SELECT jsonb_build_object(
        'sessionTtlSeconds', CASE WHEN r.tier IN ('SU') THEN 14400 WHEN r.tier = 'M2M' THEN 86400 ELSE 28800 END,
        'inactivityTimeoutSeconds', CASE WHEN r.tier IN ('SU') THEN 600 ELSE 900 END,
        'maxContexts', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN 5 ELSE 3 END,
        'contextSwitchAllowed', r.tier NOT IN ('EXT_N0','VISITANTE'),
        'caepEvents', COALESCE((SELECT events FROM caep), '[]'::jsonb),
        'riskPolicy', COALESCE((SELECT policy FROM risk), '{}'::jsonb),
        'dctxRequired', true
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 10 — credentials (D9) desde ath_method + ath_policy_d9 + idn_tier_policy
    -- ═══════════════════════════════════════════════
    'credentials', (
      WITH tier AS (
        SELECT * FROM bauth.idn_tier_policy WHERE tier = r.tier
      ),
      available AS (
        SELECT jsonb_agg(jsonb_build_object(
          'methodId', method_id, 'methodName', method_name, 'methodType', method_type,
          'aalLevel', aal_level, 'phishingResistant', CASE WHEN method_type IN ('FIDO2','FIDO2_HW') THEN true ELSE false END
        ) ORDER BY method_name) AS methods
        FROM bauth.ath_method WHERE active = true
          AND CASE WHEN r.loa_required >= 3 THEN aal_level IN ('AAL3','AAL4')
                   WHEN r.loa_required >= 2 THEN aal_level IN ('AAL2','AAL3')
                   ELSE true END
      ),
      required AS (
        SELECT jsonb_build_array(
          jsonb_build_object('methodId', method_id, 'methodName', method_name, 'order', 1, 'required', true)
        ) AS primary_method
        FROM bauth.ath_method WHERE active = true
          AND CASE WHEN r.loa_required >= 3 THEN method_type = 'FIDO2_HW'
                   WHEN r.loa_required >= 2 THEN method_type IN ('FIDO2_HW','FIDO2','OTP_APP')
                   ELSE method_type = 'MEMORIZED_SECRET' END
        ORDER BY CASE WHEN r.loa_required >= 3 THEN 1 WHEN r.loa_required >= 2 THEN 2 ELSE 3 END
        LIMIT 1
      ),
      mfa_method AS (
        SELECT jsonb_build_object('methodId', method_id, 'methodName', method_name, 'order', 2, 'required', true) AS second
        FROM bauth.ath_method WHERE active = true
          AND method_type IN ('OTP_APP','FIDO2')
        ORDER BY CASE WHEN r.loa_required >= 2 THEN method_type = 'OTP_APP' ELSE method_type = 'FIDO2' END
        LIMIT 1
      ),
      policies AS (
        SELECT jsonb_agg(jsonb_build_object('policyId', policy_id, 'policyName', policy_name, 'config', config)) AS applied
        FROM bauth.ath_policy_d9 WHERE is_active = true
      ),
      step_up AS (
        SELECT jsonb_agg(jsonb_build_object('rule_code', rule_code, 'trigger_event', trigger_event, 'required_loa', required_loa)) AS rules
        FROM bauth.ath_step_up_rule WHERE is_active = true
      )
      SELECT jsonb_build_object(
        'availableMethods', COALESCE((SELECT methods FROM available), '[]'::jsonb),
        'requiredMethods', jsonb_build_object(
          'standard', jsonb_build_array(
            COALESCE((SELECT primary_method FROM required), '{}'::jsonb),
            COALESCE((SELECT second FROM mfa_method), '{}'::jsonb)
          )
        ),
        'appliedPolicies', COALESCE((SELECT applied FROM policies), '[]'::jsonb),
        'stepUpRules', COALESCE((SELECT rules FROM step_up), '[]'::jsonb),
        'mfaRequired', (SELECT mfa_default FROM tier),
        'minAal', CASE WHEN r.loa_required >= 3 THEN 'AAL3' WHEN r.loa_required >= 2 THEN 'AAL2' ELSE 'AAL1' END,
        'sessionTimeoutSecs', (SELECT session_timeout_secs FROM tier),
        'maxSessions', (SELECT max_sessions FROM tier),
        'stepUpAllowed', (SELECT step_up_allowed FROM tier)
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 11 — delegation (D10) desde dlg_delegation
    -- ═══════════════════════════════════════════════
    'delegation', (
      SELECT jsonb_build_object(
        'enabled', r.tier NOT IN ('EXT_N0','VISITANTE'),
        'maxDurationDays', CASE WHEN r.tier IN ('SU','SYS') THEN 4
                                 WHEN r.tier IN ('BIZ_N1','BIZ_N2') THEN 21
                                 ELSE 7 END,
        'maxChainDepth', CASE WHEN r.tier IN ('SU','SYS') THEN 1 ELSE 1 END,
        'autoRevokeOnExpiry', true,
        'requiresApproval', r.tier IN ('BIZ_N3','BIZ_N4','BIZ_N5'),
        'nonDelegableRoles', jsonb_build_array('SU','SYS-SECURITY'),
        'allowedTargetRoles', jsonb_build_array('mismo_nivel','nivel_inferior')
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 12 — audit (D11) desde aud_* + idn_tier_policy
    -- ═══════════════════════════════════════════════
    'audit', (
      WITH compliance AS (
        SELECT jsonb_agg(jsonb_build_object(
          'standard', standard, 'control_id', control_id, 'control_name', control_name,
          'status', implementation_status
        )) AS controls
        FROM bauth.aud_compliance_map WHERE implementation_status IN ('implemented','partial')
      )
      SELECT jsonb_build_object(
        'level', r.audit_level,
        'retentionDays', 2555,
        'hashChainRequired', r.audit_level = 'full',
        'blockchainAnchorRequired', r.audit_level = 'full',
        'reviewFrequency', CASE WHEN r.tier IN ('SU','SYS') THEN 'monthly'
                                 WHEN r.tier IN ('BIZ_N1','BIZ_N2') THEN 'quarterly'
                                 WHEN r.tier IN ('BIZ_N3','BIZ_N4','BIZ_N5') THEN 'semi_annual'
                                 ELSE 'annual' END,
        'complianceControls', COALESCE((SELECT controls FROM compliance), '[]'::jsonb),
        'stepUpAllowed', (SELECT step_up_allowed FROM bauth.idn_tier_policy WHERE tier = r.tier),
        'delegationAllowed', (SELECT delegation_allowed FROM bauth.idn_tier_policy WHERE tier = r.tier),
        'nistAalRef', (SELECT nist_aal_ref FROM bauth.idn_tier_policy WHERE tier = r.tier)
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 13 — blockchain (D12) desde blk_*
    -- ═══════════════════════════════════════════════
    'blockchain', (
      SELECT jsonb_build_object(
        'enabled', r.audit_level = 'full',
        'variant', 'A',
        'anchorFrequencySeconds', 3600,
        'network', 'arbitrum_one',
        'merkleAlgorithm', 'keccak256',
        'batchSize', 1000,
        'verifiableExternally', true,
        'gasLimit', 100000,
        'lastBatch', COALESCE((SELECT jsonb_build_object('batch_number', batch_number, 'merkle_root', merkle_root, 'tx_hash', onchain_tx_hash, 'sealed_at', sealed_at) FROM bauth.blk_merkle_batch ORDER BY batch_number DESC LIMIT 1), '{}'::jsonb)
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 14 — security (SEC) desde sec_* + sod_*
    -- ═══════════════════════════════════════════════
    'security', (
      WITH keys AS (
        SELECT jsonb_agg(jsonb_build_object('key_type', key_type, 'state', state)) AS inventory
        FROM bauth.sec_key_inventory WHERE state = 'ACTIVE'
      ),
      algorithms AS (
        SELECT jsonb_agg(jsonb_build_object('algo_id', algo_id, 'algo_name', algo_name, 'algo_type', algo_type, 'category', category)) AS crypto
        FROM bauth.bos_crypto_algorithm WHERE active = true
      ),
      sod_config AS (
        SELECT jsonb_build_object('check_frequency', check_frequency, 'auto_remediate', auto_remediate) AS config
        FROM bauth.sod_validation_config WHERE is_active = true LIMIT 1
      )
      SELECT jsonb_build_object(
        'keyInventory', COALESCE((SELECT inventory FROM keys), '[]'::jsonb),
        'cryptoAlgorithms', COALESCE((SELECT crypto FROM algorithms), '[]'::jsonb),
        'sodValidation', COALESCE((SELECT config FROM sod_config), '{}'::jsonb),
        'securityZone', CASE WHEN r.tier IN ('SU','SYS') THEN 5 WHEN r.tier IN ('BIZ_N1','BIZ_N2') THEN 4 ELSE 3 END
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 15 — compliance (COMP) desde aud_compliance_map
    -- ═══════════════════════════════════════════════
    'compliance', (
      SELECT jsonb_build_object(
        'frameworks', jsonb_build_array('ISO 27001:2022','NIST SP 800-53 Rev 5','PCI DSS 4.0','GDPR','SOX §404'),
        'gdprConsent', jsonb_build_object('dataProcessing', true, 'marketing', false, 'thirdParty', false),
        'dataSubjectRights', jsonb_build_array('access','rectification','erasure','portability','restriction','objection'),
        'dataRetentionDays', 2555,
        'breachNotificationHours', 72,
        'complianceStatus', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN 'full'
                                  WHEN r.audit_level = 'full' THEN 'full'
                                  ELSE 'basic' END,
        'controlsImplemented', (SELECT count(*)::int FROM bauth.aud_compliance_map WHERE implementation_status = 'implemented'),
        'controlsTotal', (SELECT count(*)::int FROM bauth.aud_compliance_map)
      )
    ),

    -- ═══════════════════════════════════════════════
    -- BLOQUE 16 — sync (metadatos de sincronización KC + Tryton)
    -- ═══════════════════════════════════════════════
    'sync', jsonb_build_object(
      'kcCompositeRole', r.id,
      'kcAuthFlow', CASE WHEN r.loa_required >= 3 THEN 'sbos-passkey-aal3'
                          WHEN r.loa_required >= 2 THEN 'sbos-webauthn-2fa'
                          WHEN r.loa_required >= 1 THEN 'browser'
                          ELSE 'client-credentials' END,
      'trytonGroup', r.id,
      'trytonIrModelAccess', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN '{"*":{"create":true,"read":true,"write":true,"delete":true}}'::jsonb
                                   ELSE '{}'::jsonb END,
      'syncStatus', r.sync_status,
      'lastSyncAt', r.last_sync_at
    )

  ),
  updated_at = now()
WHERE r.id IS NOT NULL;
