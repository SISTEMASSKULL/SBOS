-- seed_idn_user_template_data.sql — User Template JSONB 15 secciones documentadas
-- IDEMPOTENTE: UPDATE sobre registros existentes
-- Fuente: BAUTH-USERTEMPLATE-SECCIONES.md v6.0
--   SECCIÓN 0: identity (USER) — SCIM 2.0 RFC 7643 §4.1, NIST SP 800-63B §4
--   SECCIÓN 1: personalInfo (USER, PII CONFIDENTIAL) — SCIM §4.1.2, GDPR Art.9
--   SECCIÓN 2: professionalInfo (USER/ORG) — SCIM Enterprise §4.3
--   SECCIÓN 3: rolesAssignments (D1) — ANSI/INCITS 359-2004, NIST 800-53 AC-2
--   SECCIÓN 4: keycloakCredentials (D9) — FIDO2 L3, RFC 6238, NIST 800-63B §5
--   SECCIÓN 5: physicalCredentials (D2) — SIA OSDP, ISO/IEC 14443
--   SECCIÓN 6: deviceRegistry (D5/D7) — FIDO2 CTAP 2.2, WebAuthn L3
--   SECCIÓN 7: sessionState (D8) — SBOS-049, NIST 800-63B-4 §7, CAEP 1.0
--   SECCIÓN 8: locationProfile (D6) — Google BeyondCorp, GDPR Art.44-49
--   SECCIÓN 9: temporalProfile (D4) — RFC 5545, ISO 8601, Ley Trabajo Bolivia
--   SECCIÓN 10: networkProfile (D7) — NIST 800-207 ZTA, CISA ZTMM v2
--   SECCIÓN 11: auditProfile (D11) — ISO 27001 A.8.15, PCI DSS 10.3.2
--   SECCIÓN 12: externalServices (D5/D9) — OIDC, OAuth 2.1, SAML 2.0
--   SECCIÓN 13: complianceProfile (D11/D14) — SOX §404, COSO 2013
--   SECCIÓN 14: lifecycleAutomation (USER/D1/D9) — SCIM RFC 7644
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

UPDATE bauth.idn_user_template u SET template = jsonb_build_object(
  'version', '3.0',
  'library_ref', 'cfg_policy_library 2026-06-25',

  -- SECCIÓN 0: IDENTIDAD
  'identity', jsonb_build_object(
    'uuid', u.uuid, 'username', u.username, 'email', u.email,
    'tenantId', u.tenant_id, 'empresaId', u.empresa_id, 'sucursalId', u.sucursal_id,
    'posLogico', u.pos_logico, 'status', u.status,
    'accountType', 'HUMAN', 'userType', 'EMPLOYEE',
    'locale', 'es-BO', 'timezone', 'America/La_Paz', 'preferredLanguage', 'es',
    'identityProvider', 'keycloak', 'kcUserId', u.kc_user_id
  ),

  -- SECCIÓN 1: INFORMACIÓN PERSONAL (PII)
  'personalInfo', jsonb_build_object(
    '_classification', 'CONFIDENTIAL',
    'gender', (SELECT COALESCE(description, 'M,F,NB,NR') FROM bglobal.menu_context WHERE context_key='gender' LIMIT 1),
    'maritalStatus', (SELECT COALESCE(description, 'SINGLE,MARRIED,DIVORCED,WIDOWED,CIVIL_UNION') FROM bglobal.menu_context WHERE context_key='marital_status' LIMIT 1),
    'idDocumentType', (SELECT COALESCE(description, 'DNI,PASSPORT,CI,RUT,NIT') FROM bglobal.menu_context WHERE context_key='id_document_type' LIMIT 1),
    'locale', 'es-BO', 'timezone', 'America/La_Paz', 'preferredLanguage', 'es'
  ),

  -- SECCIÓN 2: INFORMACIÓN PROFESIONAL
  'professionalInfo', jsonb_build_object(
    'employeeType', (SELECT COALESCE(description, 'FULL_TIME,PART_TIME,CONTRACTOR') FROM bglobal.menu_context WHERE context_key='employment_type' LIMIT 1),
    'empresaId', u.empresa_id, 'sucursalId', u.sucursal_id, 'posLogico', u.pos_logico
  ),

  -- SECCIÓN 3: ROLES ASIGNADOS (D1)
  'rolesAssignments', jsonb_build_object(
    'availableRoles', COALESCE((SELECT jsonb_agg(jsonb_build_object('roleId',id,'tier',tier,'status',status)) FROM bauth.idn_role_template WHERE status='DEFINIDO'), '[]'::jsonb),
    'assignedRoles', to_jsonb(u.rol_ids),
    'primaryRoleId', CASE WHEN array_length(u.rol_ids,1)>0 THEN to_jsonb((u.rol_ids)[1]) ELSE 'null'::jsonb END,
    'effectiveBitmask', u.mask_eff_hex
  ),

  -- SECCIÓN 4: CREDENCIALES DIGITALES (D9)
  'keycloakCredentials', jsonb_build_object(
    'availableMethods', COALESCE((SELECT jsonb_agg(jsonb_build_object('methodId',method_id,'methodName',method_name,'aalLevel',aal_level,'nistStatus',nist_status)) FROM bauth.ath_method WHERE active=true), '[]'::jsonb),
    'mfaRequired', true, 'phishingResistantRequired', true, 'passkeyEnabled', true,
    'kcUserId', u.kc_user_id, 'syncedToKC', u.sync_status='SYNCED',
    'recoveryMethods', jsonb_build_array('BACKUP_CODES','EMAIL_OTP'),
    'stepUpTriggers', jsonb_build_array('financial_approve','system_config_change','sod_override')
  ),

  -- SECCIÓN 5: CREDENCIALES FÍSICAS (D2)
  'physicalCredentials', jsonb_build_object(
    'cardTypes', jsonb_build_array('NFC_MIFARE_DESFIRE','PROXIMITY_125KHZ','SMARTCARD_X509'),
    'biometricEnrolled', false, 'escortRequired', false, 'twoPersonRule', false
  ),

  -- SECCIÓN 6: DISPOSITIVOS VINCULADOS (D5/D7)
  'deviceRegistry', jsonb_build_object(
    'platforms', jsonb_build_array('ios','android','windows','macos','linux'),
    'maxDevices', 5, 'requireAttestation', true, 'jailbreakDetection', true
  ),

  -- SECCIÓN 7: ESTADO DE SESIÓN (D8)
  'sessionState', jsonb_build_object(
    'maxConcurrentSessions', 3, 'sessionTimeoutMinutes', 480, 'idleTimeoutMinutes', 15,
    'lastLoginAt', u.last_login_at, 'lastActivityAt', u.last_activity_at,
    'forceReauthAfterHours', 12, 'rememberDeviceDays', 30,
    'contextId', u.context_actual, 'contextHistory', to_jsonb(u.bos_contexts)
  ),

  -- SECCIÓN 8: PERFIL DE UBICACIÓN (D6)
  'locationProfile', jsonb_build_object(
    'homeCountry', 'BO', 'homeTimezone', 'America/La_Paz',
    'allowedCountries', jsonb_build_array('BO','AR','BR','CL','PE'),
    'gpsTrackingConsent', false
  ),

  -- SECCIÓN 9: PERFIL TEMPORAL (D4)
  'temporalProfile', jsonb_build_object(
    'overtimeAllowed', false, 'afterHoursRequiresApproval', true, 'weekendAccessBlocked', true,
    'breakPolicy', jsonb_build_object('lunchMinutes',60,'shortBreakMinutes',15,'shortBreaksPerDay',2),
    'holidayCalendar', COALESCE((SELECT jsonb_agg(name) FROM bcalendar.cal_holiday WHERE country_code='BO' AND region IS NULL), '[]'::jsonb)
  ),

  -- SECCIÓN 10: PERFIL DE RED (D7)
  'networkProfile', jsonb_build_object(
    'vpnRequired', false, 'mTLSRequired', false,
    'allowedServices', jsonb_build_array('tryton','keycloak','superset','grafana')
  ),

  -- SECCIÓN 11: PERFIL DE AUDITORÍA (D11)
  'auditProfile', jsonb_build_object(
    'auditLevel', 'full', 'logRetentionDays', 2555, 'immutableLogs', true,
    'complianceFrameworks', jsonb_build_array('ISO 27001:2022','NIST 800-53 Rev 5','PCI DSS 4.0','GDPR','SOX §404'),
    'auditEvents', jsonb_build_array('authentication','authorization','data_access','config_change','role_assignment')
  ),

  -- SECCIÓN 12: SERVICIOS EXTERNOS (D5/D9)
  'externalServices', jsonb_build_object(
    'connectedApps', COALESCE((SELECT jsonb_agg(jsonb_build_object('app',app_slug,'name',app_name)) FROM bauth.privilege_application WHERE active=true), '[]'::jsonb),
    'federationProtocols', COALESCE((SELECT jsonb_agg(jsonb_build_object('protocol',protocol_name,'type',protocol_type,'status',bAuth_status)) FROM bauth.ath_federation_protocol WHERE bAuth_status='enabled'), '[]'::jsonb)
  ),

  -- SECCIÓN 13: PERFIL DE COMPLIANCE (D11/D14)
  'complianceProfile', jsonb_build_object(
    'gdprConsent', jsonb_build_object('dataProcessing',true,'marketing',false,'thirdParty',false),
    'dataSubjectRights', jsonb_build_array('access','rectification','erasure','portability','restriction','objection'),
    'dataRetention', jsonb_build_object('authenticationDataDays',365,'auditLogsDays',2555)
  ),

  -- SECCIÓN 14: AUTOMATIZACIÓN DEL CICLO DE VIDA
  'lifecycleAutomation', jsonb_build_object(
    'provisioning', jsonb_build_object('scimEnabled',true,'kcProvisioning',true,'trytonProvisioning',true),
    'deprovisioning', jsonb_build_object('onTermination','DISABLE','deletionAfterDays',365,'retainAuditLogs',true),
    'reactivation', jsonb_build_object('allowed',true,'requiresApproval',true,'maxInactiveDays',365,'reverifyIdentity',true),
    'syncStatus', jsonb_build_object('syncStatus',u.sync_status,'syncError','none','kcUserId',u.kc_user_id,'trytonUserId',u.tryton_user_id),
    'notifications', jsonb_build_object('onCreate',jsonb_build_array('EMAIL','PUSH'),'onDisable',jsonb_build_array('EMAIL'),'onSuspiciousActivity',jsonb_build_array('EMAIL','PUSH','SMS'))
  )
), template_version = '3.0', updated_at = now()
WHERE template_version IS NULL OR template_version != '3.0';
