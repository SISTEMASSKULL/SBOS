-- ============================================================================
-- seed_idn_user_template_v6.sql — UserTemplate 15 secciones v6.0
-- Principio: El UserTemplate define QUIÉN ES el usuario.
--   bAuth usa estos datos para evaluar con KC/Tryton/BESU y generar el ctx_id.
--   El usuario NUNCA interactúa con KC, Tryton ni BESU directamente.
--   bAuth es el orquestador central de autenticación y autorización.
--
-- Flujo real:
--   Usuario → bAuth → KC (validar credencial) → token
--                    → Tryton (validar permisos) → autorización
--                    → BitMask (Fast-Path <0.5ns) → permiso inmediato
--                    → PolicyEngine (Policy-Path <5ms) → condiciones
--                    → DomainEvaluators (External-Path) → contexto
--                    → RuleEngine (242 reglas) → validación
--   bAuth → promueve dctx_id → ctx_id
--        → ensambla Context Plane (identidad + permisos + ubicación + confianza)
--        → retorna token + contexto al usuario
--
-- IDEMPOTENTE: UPDATE para todos los usuarios, template_version controla ejecución
-- Fuente: BAUTH-USERTEMPLATE-SECCIONES.md v6.0 · SCIM 2.0 RFC 7643/7644
-- ============================================================================

SET lock_timeout = '5s';

UPDATE bauth.idn_user_template u SET
  template_version = '6.0.0',
  template = jsonb_build_object(
    'version', '6.0.0',
    'schema', 'SCIM 2.0 RFC 7643',

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 0: identity — QUIÉN es este usuario
    -- Datos que bAuth usa para identificar al usuario ante KC, Tryton, y el Context Plane
    -- ═══════════════════════════════════════════════
    'identity', jsonb_build_object(
      'uuid', u.uuid,
      'external_id', u.external_id,
      'username', u.username,
      'email', u.email,
      'display_name', COALESCE(u.template->'identity'->>'display_name', u.username),
      'locale', 'es-BO',
      'timezone', 'America/La_Paz',
      'account_type', 'HUMAN',
      'status', u.status,
      -- Contexto organizacional (bAuth lo usa para armar el ctx_id)
      'tenant_id', u.tenant_id,
      'empresa_id', u.empresa_id,
      'sucursal_id', u.sucursal_id,
      'pos_logico', u.pos_logico,
      -- Identidad federada (bAuth delega a KC para autenticar)
      'identity_provider', 'keycloak',
      'kc_user_id', u.kc_user_id,
      'tryton_user_id', u.tryton_user_id,
      -- Ciclo de vida
      'lifecycle', jsonb_build_object(
        'created_at', u.created_at,
        'status', u.status,
        'termination_date', u.termination_date,
        'offboarding_status', CASE WHEN u.termination_date IS NOT NULL THEN 'PENDING_OFFBOARD' ELSE NULL END
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 1: personal_info — DATOS PERSONALES (PII CONFIDENTIAL)
    -- bAuth usa: nombre completo para JWT claims y display; documento para IAL verification
    -- ═══════════════════════════════════════════════
    'personal_info', jsonb_build_object(
      '_classification', 'CONFIDENTIAL',
      'name', jsonb_build_object(
        'given_name', COALESCE(u.template->'personal_info'->'name'->>'given_name',
          split_part(u.username, '.', 1)),
        'family_name', COALESCE(u.template->'personal_info'->'name'->>'family_name',
          split_part(u.username, '.', 2))
      ),
      'document_type', (SELECT description FROM bglobal.menu_context WHERE context_key = 'id_document_type' LIMIT 1),
      'locale', 'es-BO',
      'timezone', 'America/La_Paz'
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 2: professional_info — DATOS LABORALES
    -- bAuth usa: para mapear a Tryton res.user y company.employee
    -- ═══════════════════════════════════════════════
    'professional_info', jsonb_build_object(
      'empresa_id', u.empresa_id,
      'sucursal_id', u.sucursal_id,
      'pos_logico', u.pos_logico,
      'employee_type', (SELECT description FROM bglobal.menu_context WHERE context_key = 'employment_type' LIMIT 1)
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 3: roles_assignments — ROLES ASIGNADOS
    -- bAuth usa: para calcular RolBitMask efectivo (herencia DAG + OR)
    --           para enviar a KC como groups y a Tryton como grupos
    -- ═══════════════════════════════════════════════
    'roles_assignments', jsonb_build_object(
      'assigned_roles', to_jsonb(u.rol_ids),
      'primary_role', CASE WHEN array_length(u.rol_ids,1) > 0 THEN to_jsonb(u.rol_ids[1]) ELSE 'null'::jsonb END,
      'effective_bitmask', u.mask_eff_hex,
      'available_roles', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object('role_id', r.id, 'tier', r.tier, 'status', r.status))
         FROM bauth.idn_role_template r WHERE r.status = 'DEFINIDO' AND r.tier != 'M2M'),
        '[]'::jsonb
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 4: credentials — ESTADO DE CREDENCIALES (solo lectura desde KC)
    -- bAuth usa: para saber qué métodos tiene disponibles el usuario
    --           para step-up cuando el rol requiere un método que el usuario no tiene activo
    -- NUNCA configura KC — solo refleja el estado real
    -- ═══════════════════════════════════════════════
    'credentials', (
      SELECT jsonb_build_object(
        'enrolled_methods', COALESCE(
          (SELECT jsonb_agg(jsonb_build_object(
            'method_id', am.method_id,
            'method_name', am.method_name,
            'aal_level', am.aal_level,
            'phishing_resistant', am.method_type = 'phishing_resistant'
          )) FROM bauth.ath_method am WHERE am.active = true),
          '[]'::jsonb
        ),
        'mfa_required', CASE
          WHEN EXISTS (SELECT 1 FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids) AND r.mfa_required = true)
          THEN true ELSE false END,
        'loa_required', COALESCE(
          (SELECT max(r.loa_required) FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids)),
          1
        ),
        'kc_synced', u.sync_status = 'SYNCED',
        'last_login', u.last_login_at
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 5: physical_credentials — ACCESO FÍSICO
    -- bAuth usa: para evaluar D2 (PhysicalEvaluator) — zonas, métodos requeridos
    -- ═══════════════════════════════════════════════
    'physical_credentials', jsonb_build_object(
      'max_security_zone', COALESCE(
        (SELECT max(r.hierarchy_level) FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids)),
        0
      ),
      'requires_escort', EXISTS(
        SELECT 1 FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids) AND r.tier IN ('VISITANTE','EXT_N0')
      ),
      'allowed_methods', jsonb_build_array('NFC','QR','HUELLA')
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 6: device_registry — DISPOSITIVOS VINCULADOS
    -- bAuth usa: para D5 (BiometricEvaluator) y D7 (NetworkEvaluator)
    --           para calcular device_trust_score y verificar atestación
    -- ═══════════════════════════════════════════════
    'device_registry', jsonb_build_object(
      'platforms_allowed', jsonb_build_array('ios','android','windows','macos','linux'),
      'max_devices', 5,
      'attestation_required', true,
      'jailbreak_detection', true,
      'registered_devices', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object(
          'device_id', nd.device_id,
          'device_type', nd.device_type,
          'status', nd.status,
          'last_seen', nd.last_seen
        )) FROM bauth.net_device nd WHERE nd.tenant_id::text = u.tenant_id AND nd.status = 'ACTIVE'),
        '[]'::jsonb
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 7: session_state — ESTADO DE SESIÓN (solo lectura)
    -- bAuth usa: para D8 (ContextEvaluator) — ctx_id activo, sesiones concurrentes
    -- ═══════════════════════════════════════════════
    'session_state', jsonb_build_object(
      'active_sessions', COALESCE(
        (SELECT count(*) FROM bauth.ses_context WHERE user_uuid::text = u.uuid::text AND expires_at > now()),
        0
      ),
      'max_concurrent', CASE
        WHEN EXISTS (SELECT 1 FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids) AND r.tier IN ('SU','SYS')) THEN 3
        ELSE 1 END,
      'last_activity', u.last_activity_at,
      'context_id', u.context_actual
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 8: location_profile — UBICACIÓN
    -- bAuth usa: para D6 (GeospatialEvaluator) — país, geo-fence, trust tier
    -- ═══════════════════════════════════════════════
    'location_profile', jsonb_build_object(
      'home_country', 'BO',
      'home_timezone', 'America/La_Paz',
      'allowed_countries', jsonb_build_array('BO','AR','BR','CL','PE'),
      'gps_tracking_consent', false
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 9: temporal_profile — HORARIO
    -- bAuth usa: para D4 (TemporalEvaluator) — turno, breaks, overtime
    -- ═══════════════════════════════════════════════
    'temporal_profile', jsonb_build_object(
      'schedule_id', (SELECT schedule_id FROM bcalendar.cal_schedule WHERE is_default = true LIMIT 1),
      'overtime_allowed', false,
      'after_hours_requires_approval', true,
      'holiday_country', 'BO'
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 10: network_profile — RED
    -- bAuth usa: para D7 (NetworkEvaluator) — CIDR, VPN, device trust, ZTNA
    -- ═══════════════════════════════════════════════
    'network_profile', jsonb_build_object(
      'vpn_required', CASE
        WHEN EXISTS (SELECT 1 FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids) AND r.tier NOT IN ('SU','SYS')) THEN true
        ELSE false END,
      'mtls_required', true,
      'allowed_networks', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object('name', n.name, 'cidr', n.cidr, 'type', n.network_type))
         FROM bauth.idn_tenant_network n WHERE n.tenant_id::text = u.tenant_id AND n.is_active = true),
        '[]'::jsonb
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 11: audit_profile — AUDITORÍA
    -- bAuth usa: para D11 (AuditDomainEvaluator) — eventos, retención, compliance
    -- ═══════════════════════════════════════════════
    'audit_profile', jsonb_build_object(
      'audit_level', COALESCE(
        (SELECT max(r.audit_level) FROM bauth.idn_role_template r WHERE r.id = ANY(u.rol_ids)),
        'basic'
      ),
      'retention_days', 2555,
      'recent_events', COALESCE(
        (SELECT jsonb_agg(ev ORDER BY ev->>'created_at' DESC) FROM (
          SELECT jsonb_build_object(
            'event_type', ae.event_type, 'severity', ae.severity, 'created_at', ae.created_at
          ) as ev FROM bauth.aud_event ae WHERE ae.ctx_id = u.context_actual LIMIT 20
        ) sub),
        '[]'::jsonb
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 12: external_services — SERVICIOS EXTERNOS
    -- bAuth usa: para consentimientos GDPR, OAuth grants, servicios vinculados
    -- ═══════════════════════════════════════════════
    'external_services', jsonb_build_object(
      'connected_apps', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object('app_code', app_code, 'app_name', app_name))
         FROM bauth.privilege_application WHERE active = true),
        '[]'::jsonb
      ),
      'gdpr_consents', jsonb_build_object(
        'data_processing', true,
        'marketing', false,
        'third_party', false,
        'biometric', false
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 13: compliance_profile — COMPLIANCE
    -- bAuth usa: para verificar SoD, training, políticas aceptadas
    -- ═══════════════════════════════════════════════
    'compliance_profile', jsonb_build_object(
      'frameworks', jsonb_build_array('ISO 27001:2022','NIST SP 800-53 Rev 5','PCI DSS 4.0','GDPR','SOX §404'),
      'data_retention_days', 2555,
      'breach_notification_hours', 72,
      'controls_applicable', COALESCE(
        (SELECT count(*)::int FROM bauth.aud_compliance_map WHERE implementation_status = 'implemented'),
        0
      )
    ),

    -- ═══════════════════════════════════════════════
    -- SECCIÓN 14: lifecycle_automation — CICLO DE VIDA
    -- bAuth usa: para JML (Joiner-Mover-Leaver), sync status, notificaciones
    -- ═══════════════════════════════════════════════
    'lifecycle_automation', jsonb_build_object(
      'provisioning', jsonb_build_object(
        'scim_enabled', true,
        'kc_provisioned', u.kc_user_id IS NOT NULL,
        'tryton_provisioned', u.tryton_user_id IS NOT NULL
      ),
      'deprovisioning', jsonb_build_object(
        'on_termination', 'DISABLE',
        'deletion_after_days', 365,
        'retain_audit_logs', true
      ),
      'sync_status', jsonb_build_object(
        'status', u.sync_status,
        'kc_user_id', u.kc_user_id,
        'tryton_linked', CASE WHEN u.tryton_user_id IS NOT NULL THEN 'linked' ELSE 'not_linked' END
      ),
      'notifications', jsonb_build_object(
        'on_create', jsonb_build_array('EMAIL'),
        'on_disable', jsonb_build_array('EMAIL'),
        'on_suspicious', jsonb_build_array('EMAIL','PUSH')
      )
    )
  ),
  updated_at = now()
WHERE template_version IS NULL OR template_version != '6.0.0';
