-- seed_menu_context.sql — Registro central de todos los dropdowns del sistema
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- REGLA: cada ENUM type en DDL = 1 entrada aquí. La UI consulta menu_context para poblar dropdowns.
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bglobal.menu_context RESTART IDENTITY CASCADE;
REINDEX TABLE bglobal.menu_context;

INSERT INTO bglobal.menu_context (tenant_id, context_key, entity_type, description) VALUES

-- Contextos de entidad base (menús contextuales)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'transaccion',    'Transaccion',   'Operaciones sobre transacciones financieras'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'usuario',        'Usuario',       'Acciones de administración sobre usuarios'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'cuenta_onchain', 'CuentaOnchain', 'Operaciones sobre cuentas blockchain'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'rol',            'Rol',           'Gestión de roles y permisos'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'documento',      'Documento',      'Acciones sobre documentos anclados'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'tenant',         'Tenant',         'Administración del tenant (solo SU)'),

-- Datos de selección para UserTemplate (antes eran 5 tablas separadas)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'account_type',   'AccountType',   'Tipo de cuenta: HUMAN, SERVICE, SYSTEM, GUEST'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'gender',         'Gender',        'Género: M, F, NB, NR'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'marital_status', 'MaritalStatus', 'Estado civil: SINGLE, MARRIED, DIVORCED, WIDOWED, NR, CIVIL_UNION, SEPARATED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'id_document_type','IDDocumentType','Tipo de documento: DNI, PASSPORT, CI, RUT, NIT, CÉDULA, etc.'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'employment_type','EmploymentType','Tipo de empleo: FULL_TIME, PART_TIME, CONTRACTOR, INTERN, TEMPORARY, CONSULTANT, FREELANCE'),

-- ENUMs del sistema (cada ENUM type en DDL = 1 entrada aquí)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'tenant_status',        'TenantStatus',        'PENDING_VERIFICATION, ACTIVE, SUSPENDED, MAINTENANCE, SOFT_DELETED, TERMINATED, PURGED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'tenant_type',          'TenantType',          'STANDARD, REGULATED, HIGH_SENSITIVITY'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'isolation_level',      'IsolationLevel',      'ROW_LEVEL, SCHEMA_PER_TENANT, DB_PER_TENANT'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'subscription_status',  'SubscriptionStatus',  'TRIAL, ACTIVE, PAST_DUE, CANCELLED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'plan_tier',            'PlanTier',            'BASIC, PRO, ENTERPRISE'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'provisioning_status',  'ProvisioningStatus',  'PENDING, INFRA_PROVISIONING, SCHEMA_CREATED, IDP_CONFIGURED, COMPLETED, FAILED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'audit_level',          'AuditLevel',          'basic, full'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'domain_type',          'DomainType',          'WEB, API, POS, ADMIN, PORTAL, STATIC, MAIL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'domain_status',        'DomainStatus',        'PENDING, VERIFIED, FAILED, PROPAGATING, ISSUED, EXPIRING, RENEWING, DEPLOYING, DEPLOYED, ROLLED_BACK, HEALTHY, DEGRADED, UNHEALTHY, UNKNOWN'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'network_type',         'NetworkType',         'LAN, WAN, VPN, DMZ, GUEST, MANAGEMENT'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fiscal_year_status',   'FiscalYearStatus',    'OPEN, CLOSED, CLOSED_WITH_ADJUSTMENTS, ARCHIVED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'calendar_type',        'CalendarType',        'WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'alarm_channel',        'AlarmChannel',        'EMAIL, SMS, WHATSAPP, PUSH, CHAT, UI'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_transaction_category','FinTransactionCategory','VENTAS, COMPRAS, PAGOS, COBROS, NOMINA, INVENTARIO, TRIBUTARIO, BANCARIO, ACTIVOS_FIJOS, IMPORTACION, EXPORTACION'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_risk_level',       'FinRiskLevel',        'BAJO, MEDIO, ALTO, CRITICO'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_limit_action',     'FinLimitAction',      'BLOCK, REQUIRE_APPROVAL, REQUIRE_DUAL_CONTROL, NOTIFY'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_approval_status',  'FinApprovalStatus',   'PENDING, APPROVED, REJECTED, ESCALATED, EXPIRED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_document_operation','FinDocumentOperation','EMIT, CANCEL, ADJUST, VOID, EXPORT_SIN'),

-- Datos de selección desde cfg_policy_library (framework unificado)
-- Framework: semantic_type (CHECK constraint en cfg_policy_library)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'semantic_type',       'SemanticType',       'policy, configuration, method, standard, guideline, group'),
-- Framework: node_type estructural
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'node_type',           'NodeType',           'section, group, policy, config'),
-- Framework: 12 dominios de soberanía + SEC (seguridad general)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'domain_code',         'DomainCode',         'D1:Lógico, D2:Físico, D3:Financiero, D4:Temporal, D5:Biométrico, D6:Geolocalización, D7:Red/API, D8:Sesión/Emergencia, D9:Federación/Credenciales, D10:Delegación, D11:Auditoría/Cumplimiento, D12:Blockchain/Trazabilidad, SEC:Seguridad General'),
-- Framework: enforcement. NIST 800-53 usa baseline + tailoring; industria usa estos 3 niveles
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'enforcement',         'Enforcement',        'mandatory, recommended, optional'),
-- Framework: risk_level. Alineado con NIST RMF risk categorization
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'risk_level',          'RiskLevel',          'critical, high, medium, low'),
-- Framework: lifecycle stages. IAM policy lifecycle estándar
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'lifecycle',           'Lifecycle',          'draft, proposed, active, deprecated, superseded, retired'),
-- Framework: NIST SP 800-63 AAL + IAL + FAL (9 niveles independientes)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'assurance_level',     'AssuranceLevel',     'AAL1, AAL2, AAL3, IAL1, IAL2, IAL3, FAL1, FAL2, FAL3'),
-- Framework: auth_factor. NIST 800-63B: knowledge (saber), possession (tener), inherence (ser), context (contexto), multi (múltiple)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'auth_factor',         'AuthFactor',         'knowledge, possession, inherence, context, multi'),
-- Framework: phishing_resistant booleano (NIST Rev4: obligatorio AAL2+)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'phishing_resistant',  'PhishingResistant',  'true, false'),
-- Framework: mfa_required booleano
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'mfa_required',        'MFARequired',        'true, false'),
-- Framework: applicability scope (ABAC/IAM 2.0 target audiences)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'applicability',       'Applicability',      'workforce, customer, admin, service_account, device, api, partner, contractor, guest, all'),
-- Framework: 16 fuentes de políticas (extraído de cfg_policy_library)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'policy_source',       'PolicySource',       (SELECT string_agg(DISTINCT source, ', ' ORDER BY source) FROM bauth.cfg_policy_library));

-- ENUMs DDL faltantes que deben ser menús contextuales
INSERT INTO bglobal.menu_context (tenant_id, context_key, entity_type, description) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'calendar_role',        'CalendarRole',        'OWNER, EDITOR, VIEWER'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'calendar_owner_type',  'CalendarOwnerType',   'TENANT, COMPANY, BRANCH, USER'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_device_type',      'FisDeviceType',       'CARD_READER, PIN_KEYPAD, BIOMETRIC_READER, MAGNETIC_LOCK, ELECTRIC_STRIKE, DOOR_CONTACT, MOTION_SENSOR, IP_CAMERA, PTZ_CAMERA, INTERCOM, REX_BUTTON, ALARM_SIREN, GLASS_BREAK, SMOKE_DETECTOR, POS_TERMINAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_device_status',    'FisDeviceStatus',     'ACTIVE, INACTIVE, ALARM, FAULT, MAINTENANCE, OFFLINE'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_device_protocol',  'FisDeviceProtocol',   'OSDP, WIEGAND, ONVIF, MQTT, MODBUS, SIP, TCPIP'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_location_type',    'FisLocationType',     'SITE, BUILDING, FLOOR, WING, AREA, DOOR, DEVICE'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_perimeter_type',   'FisPerimeterType',    'FENCE, WALL, VEHICLE_BARRIER, GATE'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'language_scope',       'LanguageScope',       'individual, macrolanguage, special, collection'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'language_type',        'LanguageType',        'living, extinct, ancient, constructed, historic'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'text_direction',       'TextDirection',       'ltr, rtl, ttb'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'translation_status',   'TranslationStatus',   'COMPLETE, PARTIAL, MACHINE_TRANSLATED, NOT_TRANSLATED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'menu_type',            'MenuType',            'HIERARCHICAL, CONTEXTUAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'role_type',            'RoleType',            'TYPE_OPERATIVO, TYPE_SUPERVISOR, TYPE_GERENCIA_MEDIA, TYPE_DIRECCION, TYPE_ADMIN_SISTEMA, TYPE_SERVICIO, TYPE_AUDITORIA, TYPE_COMERCIAL, TYPE_TECNICO'),
-- Ciclo de vida del rol (G-B01-05) — NIST SP 800-53 AC-2(j)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'role_status',          'RoleStatus',          'DRAFT, REVIEW, ACTIVE, SUSPENDED, DEPRECATED, ARCHIVED'),
-- Vigencia temporal del rol (G-B02-01) — NIST SP 800-53 AC-2(d)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'role_validity_type',   'RoleValidityType',    'INDEFINITE, FIXED, PROJECT_BASED, TEMPORARY, EMERGENCY'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'schedule_status',      'ScheduleStatus',      'OPEN, CLOSED, LAUNCH, BREAK, OVERTIME'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'verification_status',  'VerificationStatus',  'PENDING, IN_PROGRESS, PASSED, FAILED'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'verification_step',    'VerificationStep',    'IDENTITY_CHECK, LEGAL_CHECK, TECHNICAL_SETUP, SECURITY_REVIEW, FINAL_APPROVAL'),

-- ═══════════════════════════════════════════════════════════════════════════
-- ENUMS desde cfg_validation_rule — Cada regla ENUM = 1 dropdown en CRUD
-- El usuario solo puede seleccionar entre valores pre-validados contra estándares
-- ═══════════════════════════════════════════════════════════════════════════

-- D1: Lógico — scope de acceso
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'access_scope',       'AccessScope',      'GLOBAL, COMPANY, BRANCH, PERSONAL'),
-- D1: Clasificación de datos
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'data_classif_levels', 'DataClassifLevels', 'PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED, sensitive, full, basic, controlled, enhanced, comprehensive'),
-- D1: Idiomas oficiales
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'locale_active',       'LocaleActive',     'true, false'),

-- D2: Nivel de autenticación física (OSDP)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fis_auth_level',      'FisAuthLevel',     '1:Tarjeta, 2:Tarjeta+PIN, 3:Biométrico, 4:Doble factor'),
-- D2: Zona de seguridad física (BS 5979)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'security_zone_level', 'SecurityZoneLevel', '0:Pública, 1:Recepción, 2:Empleados, 3:Restringida, 4:Crítica, 5:Bóveda'),

-- D3: Acción SoD (SOX §404)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'sod_action',          'SoDAction',        'BLOCK, COMPENSATE, ALLOW_LOG'),
-- D3: Nivel de riesgo financiero (COSO)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_risk_level_full', 'FinRiskLevelFull', 'BAJO, MEDIO, ALTO, CRITICO'),
-- D3: Categoría de transacción (ISO 20022)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'fin_tx_category',     'FinTxCategory',    'VENTAS, COMPRAS, PAGOS, COBROS, NOMINA, INVENTARIO, TRIBUTARIO, BANCARIO, ACTIVOS_FIJOS, IMPORTACION, EXPORTACION'),

-- D4: Días de semana (ISO 8601)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'iso_day_of_week',     'ISODayOfWeek',     '1:Lunes, 2:Martes, 3:Miércoles, 4:Jueves, 5:Viernes, 6:Sábado, 7:Domingo'),

-- D5: Verdict Play Integrity (Android)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'play_integrity_verdict','PlayIntegrityVerdict','NO_INTEGRITY, BASIC_INTEGRITY, DEVICE_INTEGRITY, STRONG_INTEGRITY'),

-- D7: Modo Zero Trust (NIST 800-207)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'ztna_default_action', 'ZTNADefaultAction', 'DENY, ALLOW'),
-- D7: Versión TLS permitida (RFC 8996)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'tls_min_version',     'TLSMinVersion',    'TLS1.2, TLS1.3'),
-- D7: Firewall default action (NIST SC-7)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'firewall_default',    'FirewallDefault',   'DENY, REJECT'),

-- D8: Eventos CAEP (OpenID CAEP 1.0)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'caep_event_type',     'CAEPEventType',    'session-revoked, token-claims-change, assurance-level-change, credential-change, device-compliance-change'),

-- D9: AAL (NIST SP 800-63B §4)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'aal_level',           'AALevel',          'AAL1, AAL2, AAL3, AAL4'),
-- D9: Tipo de método de autenticación (NIST §5.1)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'auth_method_type',    'AuthMethodType',   'single_factor, multi_factor, phishing_resistant, federated, machine, recovery, adaptive, deprecated, device, continuous, out_of_band'),
-- D9: Tipo de factor de autenticación (NIST 800-63B)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'auth_factor_type_full','AuthFactorTypeFull','knowledge, possession, inherence, context, multi'),
-- D9: Algoritmo TOTP (RFC 6238)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'totp_algorithm',      'TOTPAlgorithm',    'SHA1, SHA256, SHA512'),
-- D9: Atestación WebAuthn (FIDO2 L2)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'webauthn_attestation','WebAuthnAttestation','none, indirect, direct, enterprise'),
-- D9: Verificación de usuario WebAuthn
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'webauthn_user_verify','WebAuthnUserVerify','discouraged, preferred, required'),
-- D9: Clave residente WebAuthn
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'webauthn_resident_key','WebAuthnResidentKey','discouraged, preferred, required'),
-- D9: Algoritmo de clave SmartCard (FIPS 201-3)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'smartcard_key_algo',  'SmartcardKeyAlgo', 'RSA-2048, RSA-4096, ECDSA-P256, ECDSA-P384'),
-- D9: Backup code hash
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'backup_code_hash',    'BackupCodeHash',   'SHA-256, SHA-512'),
-- D9: PKCE challenge method (OAuth 2.1)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'pkce_method',         'PKCEMethod',       'S256'),
-- D9: OAuth response types (OAuth 2.1)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'oauth_response_types','OAuthResponseTypes','code, code id_token, code token'),
-- D9: Token Exchange subject types (RFC 8693)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'token_exchange_types','TokenExchangeTypes','urn:ietf:params:oauth:token-type:access_token, urn:ietf:params:oauth:token-type:refresh_token'),
-- D9: Algoritmo firma JWT (RFC 7518)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'jwt_sign_algo',       'JWTSignAlgo',      'RS256, RS384, RS512, ES256, ES384, ES512, EdDSA'),
-- D9: Protocolo NFC (ISO 14443)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'nfc_protocol_type',   'NFCProtocolType',  'ISO14443-4, MIFARE_DESFIRE, NTAG424, FeliCa'),

-- D11: Frecuencia de revisión (ISO 27001 A.9.2.5)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'review_frequency',    'ReviewFrequency',  'monthly, quarterly, semi_annual, annual'),
-- D11: Frecuencia de revisión extendida
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'review_freq_extended','ReviewFreqExtended','daily, weekly, monthly, quarterly, semi_annual, annual, hourly, realtime, continuous, periodic'),

-- COMP: Nivel IAL (NIST SP 800-63A)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'ial_level',           'IALevel',          'IAL1, IAL2, IAL3'),

-- SEC: Algoritmos criptográficos aprobados (FIPS 140-3)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'crypto_algo_approved','CryptoAlgoApproved','AES-256-GCM, AES-256, SHA-256, SHA-384, SHA-512, EdDSA, RSA-4096, ECDSA-P384, CRYSTALS-Kyber, CRYSTALS-Dilithium, SPHINCS+, NTRU'),
-- SEC: Formato de firma digital (ETSI EN 319)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'signature_format',    'SignatureFormat',  'PAdES, XAdES, CAdES, JAdES'),
-- SEC: Perfil de firma (ETSI B-Level)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'signature_profile',   'SignatureProfile', 'B-B, B-T, B-LT, B-LTA'),
-- SEC: Tipo de hardware de seguridad
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'storage_backend_type','StorageBackendType','HSM, SOFTWARE, VAULT_KV2, VAULT_TRANSIT, VAULT_PKI, HSM_PKCS11, POSTGRES_HASH, hardware, hardwareSecured, encrypted, immutable'),

-- FW: Canales de notificación
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'notification_channel','NotificationChannel','EMAIL, SMS, WHATSAPP, PUSH, CHAT, UI'),
-- FW: Modos de enforcement
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'enforcement_mode',    'EnforcementMode',  'strict, dynamic, adaptive, automated, immediate, realtime, periodic, continuous'),
-- FW: Niveles de auditoría
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'audit_detail_level',  'AuditDetailLevel', 'detailed, comprehensive, minimal, basic, full, enhanced, controlled, normal, verbose, restricted, none'),

-- ══════════════════════════════════════════════════════════════════════
-- BOS IAM Installer — ENUMs de DDL_bos_schema.sql (schema bos, sbos_db)
-- ══════════════════════════════════════════════════════════════════════

-- bos_context_state_enum (SBOS-049 §16.1) — 7 estados del Context Plane
-- DeviceContext: PENDIENTE→ACTIVO→(SUSPENDIDO|BLOQUEADO|INVALIDADO|EXPIRADO|ARCHIVADO)
-- SessionContext: ACTIVO directamente desde Promote/Create
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'bos_context_state',   'BosContextState',
 'PENDIENTE, ACTIVO, SUSPENDIDO, BLOQUEADO, INVALIDADO, EXPIRADO, ARCHIVADO'),

-- bos_ficha_state_enum (ADR-021) — 18 estados del ciclo de vida de fichas
-- Divide en: espera (2), transición-install (1), estable (1), actualización (3),
--            error (3), reparación (1), crítico (1), fallas (2), reversión (2), admin (2)
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'bos_ficha_state',     'BosFichaState',
 'PENDIENTE, LISTA, INSTALANDO, INSTALADA, ACTUALIZACION_DISPONIBLE, ACTUALIZACION_APROBADA, ACTUALIZANDO, DEGRADADA, ERROR_FISICO, ERROR_LOGICO, REPARANDO, ERROR_NO_CORREGIBLE, FALLA_INSTALACION, FALLA_ACTUALIZACION, ROLLBACK, LIMPIEZA, PAUSADA, DESINSTALADA'),

-- bos_bootstrap_stage_enum (SBOS-BOOTSTRAP-MANUAL.md) — 11 etapas del bootstrap
-- Sigue el orden de las 6 capas: Capa0=PREFLIGHT, Capa1=K8S_INIT+CALICO,
-- Capa2=POSTGRESQL+REDIS, Capa3=KEYCLOAK, Capa4=VAULT, Capa5=KONG, luego VERIFY+fin
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'bos_bootstrap_stage', 'BosBootstrapStage',
 'PREFLIGHT, K8S_INIT, CALICO, POSTGRESQL, REDIS, KEYCLOAK, VAULT, KONG, VERIFY, COMPLETED, FAILED'),

-- bos_bootstrap_result_enum — 5 resultados posibles por evento de bootstrap
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'bos_bootstrap_result','BosBootstrapResult',
 'RUNNING, OK, WARN, FAIL, SKIP');

-- SELECT count(*) FROM bglobal.menu_context; -- 99 entradas (95 previas + 4 BOS)
