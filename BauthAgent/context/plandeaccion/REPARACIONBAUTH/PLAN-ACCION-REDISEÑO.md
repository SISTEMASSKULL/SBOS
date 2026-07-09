# PLAN-ACCION-REDISEÑO — Plan de Acción · Rediseño bAuth v3.0
## Carpeta de trabajo: REPARACIONBAUTH

**Versión:** 1.1.0 · **Fecha:** 2026-07-01 · **Última revisión:** 2026-07-01 · **Responsable:** bauth-developer (pane 7)
**Coordinador:** sbos-coordinador (pane 0)

---

## Contexto

El rediseño de bAuth v3.0 incluye:
1. **120 átomos CRUD D00** — reemplazan 20 átomos semánticos (5809-5928)
2. **188 átomos CRUD D4-D12** — catálogo de control por dominio
3. **36 átomos D13** — nuevo dominio blockchain/firma legal
4. **Tabla `idn_atributo`** — reemplaza `org_contacto` + `org_documento` + `org_direccion`
5. **Migración 003** — DDL para D00 + idn_atributo + átomos nuevos

**Condición de entrada:** Cobertura 100% verificada → `BAUTH-COBERTURA-100PCT.md` ✅
**Condición de salida:** Migración 003 aplicada en VPS + todos los seeds insertados + tests OK

---

## Documentos de referencia en esta carpeta

| Documento | Propósito |
|-----------|-----------|
| `BAUTH-COBERTURA-100PCT.md` | Matriz de cobertura 100% — base de validación |
| `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | 120 átomos CRUD para D00 (30 campos × 4) |
| `BAUTH-CATALOGO-ATOMOS-D4-D12.md` | 188 átomos CRUD para D4-D12 (47 campos × 4) |
| `BAUTH-DOMINIO-D13-BLOCKCHAIN.md` | 36 átomos D13 blockchain + firma legal |
| `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` | Diseño de idn_atributo + bglobal |
| `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` | Arquitectura master (v1.1.0) |

### Seeds — documentos fuente canónicos (SSOT)

| Documento | Propósito | Ruta |
|-----------|-----------|------|
| `BAUTH-USERTEMPLATE-SECCIONES.md` | 15 secciones canónicas UserTemplate v6.0 | `plandeaccion/bauth/` |
| `BAUTH-ROLTEMPLATE-SECCIONES.md` | 14 secciones canónicas RolTemplate v6.0 | `plandeaccion/bauth/` |
| `Authentication_Framework.json` | Framework de autenticación v2.0 (SSOT métodos) | `plandeaccion/bauth/` |
| `Policies_Authentication_Framework.json` | Políticas de autenticación v3.0 (SSOT políticas) | `plandeaccion/bauth/` |

> ⚠️ Los archivos `Authentication_Framework_v3.json` y `Policies_Authentication_Framework_v4.json`
> son versiones incorrectas — NO usar. Los correctos son los indicados arriba.

---

## Fases del rediseño

### FASE 0.S — Auditoría y Reparación de Seeds Existentes (SIN BLOQUEO — ejecutable ya)

**Propósito:** Sanear los 81 seeds existentes antes de agregar los nuevos del rediseño.
Esta fase no requiere aprobación DDL — trabaja solo con seeds ya existentes.
**Directorio:** `BauthAgent/db/migrations/seeds/` (83 archivos: 81 seeds + run_all_seeds.sql + 1 huérfano)
**SSOT de nomenclatura:** `BAUTH-USERTEMPLATE-SECCIONES.md` y `BAUTH-ROLTEMPLATE-SECCIONES.md`
**SSOT de autenticación:** `Authentication_Framework.json` (v2.0.0) y `Policies_Authentication_Framework.json` (v3.0.0)

---

#### GRUPO A — Inventario y organización lógica del orquestador run_all_seeds.sql

**Archivo:** `seeds/run_all_seeds.sql`
**Problema detectado:** La cabecera dice "Ejecución ordenada de **49 seeds**" pero hay **81** entradas `\ir`.
Además, `seed_compliance_results.sql` existe en disco pero no está incluido.

**A1 — Corregir encabezado del orquestador**
- Línea 2 del archivo: `-- run_all_seeds.sql — Ejecución ordenada de 49 seeds en producción`
- Cambiar a: `-- run_all_seeds.sql — Ejecución ordenada de 82 seeds en producción`
- Línea `\echo '=== 54 seeds ejecutados ==='` al final → cambiar a `\echo '=== 82 seeds ejecutados ==='`
- Verificación: `grep 'seeds ejecutados' run_all_seeds.sql` devuelve `82`

**A2 — Incorporar seed huérfano seed_compliance_results.sql**
- Archivo huérfano confirmado: `seed_compliance_results.sql` (fecha: 2026-06-29, 3,811 bytes)
- Ubicación en run_all_seeds.sql: agregar en FASE 11 después de la línea `\ir seed_compliance_qa.sql`
- Formato exacto a insertar: `\ir seed_compliance_results.sql`
- Verificación: `grep 'seed_compliance_results' run_all_seeds.sql` devuelve la línea

**A3 — Verificar dependencias FK entre fases**
- FASE 1 (`privilege_*`) debe ejecutarse ANTES que FASE 2 (`idn_tenant`) — ya está correcto
- FASE 2 (`idn_tenant`) debe ejecutarse ANTES que FASE 7 (`idn_role_template`, `idn_role_d*`) — ya está correcto
- FASE 3 (`ath_method`, `ath_config_d*`) debe ejecutarse ANTES que FASE 4 (`ath_policy_d*`) — ya está correcto
- FASE 6 (`cal_calendar`, `cal_schedule`) debe ejecutarse ANTES que FASE 7 (`idn_role_d*`) — verificar
- Verificación: leer línea a línea el orden y confirmar que cada `\ir` referencia una tabla cuyas FKs ya están cargadas

---

#### GRUPO B — Reparación completa de 064_idn_user_template_data.sql

**Archivo:** `seeds/064_idn_user_template_data.sql`
**SSOT:** `BAUTH-USERTEMPLATE-SECCIONES.md` v6.0 (15 secciones, snake_case, versión 6.0.0)
**DDL de referencia:** `idn_user_template` (DDL línea 3840) — columnas disponibles:
`uuid, external_id, username, email, tenant_id, empresa_id, sucursal_id, pos_logico,
bos_contexts, context_actual, rol_ids, rol_bitmask_base64, status, termination_date,
termination_reason, sync_status, kc_user_id, tryton_user_id, last_login_at, last_activity_at,
template, template_version, ctx_id, created_at, updated_at`

**B0 — Correcciones globales del archivo (3 problemas críticos)**

| # | Ubicación | Error actual | Corrección |
|---|-----------|-------------|------------|
| B0.1 | Línea 23, dentro del JSONB | `'version', '3.0'` | → `'version', '6.0.0'` |
| B0.2 | Línea 57, sección `rolesAssignments` | `u.mask_eff_hex` — columna NO EXISTE en DDL | → `u.rol_bitmask_base64` (columna real en DDL línea 3852) |
| B0.3 | Línea 136, clausula SET | `template_version = '3.0'` | → `template_version = '6.0.0'` |

**B1 — SECCIÓN 0: `identity` (líneas 27-34 del seed)**

El seed tiene 15 campos, el canónico SECCIÓN 0 define 4 grupos + 4 subobjetos.

*Claves internas a renombrar (camelCase → snake_case):*
| Campo actual | Campo correcto | Fuente DDL |
|---|---|---|
| `'tenantId', u.tenant_id` | `'tenant_id', u.tenant_id` | columna `tenant_id` |
| `'empresaId', u.empresa_id` | `'empresa_id', u.empresa_id` | columna `empresa_id` |
| `'sucursalId', u.sucursal_id` | `'sucursal_id', u.sucursal_id` | columna `sucursal_id` |
| `'posLogico', u.pos_logico` | `'pos_logico', u.pos_logico` | columna `pos_logico` |
| `'accountType', 'HUMAN'` | `'account_type', 'HUMAN'` | literal |
| `'userType', 'EMPLOYEE'` | `'user_type', 'EMPLOYEE'` | literal |
| `'preferredLanguage', 'es'` | `'preferred_language', 'es'` | literal |
| `'identityProvider', 'keycloak'` | `'identity_provider', 'keycloak'` | literal |
| `'kcUserId', u.kc_user_id` | `'kc_user_id', u.kc_user_id` | columna `kc_user_id` |

*Campos faltantes a agregar (columnas DDL disponibles):*
| Campo a agregar | SQL fuente | Referencia SECCIÓN 0 |
|---|---|---|
| `'external_id'` | `u.external_id` | campo `external_id` en DDL |
| `'zoneinfo'` | `COALESCE(u.template->>'zoneinfo', 'America/La_Paz')` | SECCIÓN 0, `zoneinfo` (IANA) |
| `'realm_kc'` | `u.tenant_id` | realm KC = tenant_id |
| `'namespace_k8s'` | `'tenant-' \|\| u.tenant_id` | derivado |

*Subobjetos faltantes a construir (4 subobjetos canónicos):*

```
lifecycle: jsonb_build_object(
  'created_at', u.created_at,
  'activated_at', null,
  'status_changed_at', null,
  'termination_date', u.termination_date,
  'termination_reason', u.termination_reason,
  'offboarding_status', null,
  'purge_after', null
)

federation: jsonb_build_object(
  'federated_idp', null,
  'federated_user_id', null,
  'federated_username', null,
  'identity_provider', 'keycloak',
  'brokering_enabled', false
)

digital_signature: jsonb_build_object(
  'algorithm', 'EdDSA_Ed25519',
  'post_quantum_planned', 'CRYSTALS-Dilithium',
  'certificate_thumbprint', null,
  'timestamp', null,
  'validity', jsonb_build_object('not_before', null, 'not_after', null)
)

audit_trail: jsonb_build_object(
  'created_by', 'system',
  'updated_by', 'system',
  'updated_at', u.updated_at
)
```

*Verificación:* `SELECT template->>'identity' IS NOT NULL, template->'identity'->'lifecycle' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → ambos `true`

**B2 — SECCIÓN 1: `personal_info` (líneas 37-43 del seed)**

Nombre actual: `'personalInfo'` → `'personal_info'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'maritalStatus'` | `'marital_status'` |
| `'idDocumentType'` | `'id_document_type'` |
| `'preferredLanguage'` | `'preferred_language'` |

*Estructura actual insuficiente — agregar subestructuras según SECCIÓN 1:*

```
_classification: 'CONFIDENTIAL'
_access_control: jsonb_build_object(
  'full_access_roles', jsonb_build_array('ROL-SYS-ADMIN-SEGURIDAD'),
  'masked_access_roles', jsonb_build_array('ROL-ORG-GER-RRHH'),
  'restricted_fields', jsonb_build_array('national_id','birth_date','bank_account'),
  'gdpr_sensitive_fields', jsonb_build_array('gender','nationality','biometric_data','health_info')
)
name: jsonb_build_object(
  'given_name', null, 'middle_name', null, 'family_name', null,
  'second_family_name', null, 'full_name', null, 'formatted_name', null,
  'initials', null, 'previous_names', '[]'::jsonb
)
demographics: jsonb_build_object(
  'birth_date', null, 'gender', <query bglobal menu_context gender>,
  'nationality', null, 'nationality_secondary', null,
  'marital_status', <query bglobal menu_context marital_status>
)
identification: jsonb_build_object(
  'primary_document', jsonb_build_object(
    'type', <query bglobal menu_context id_document_type>,
    'number', null, 'verified', false
  ),
  'secondary_documents', '[]'::jsonb,
  'tax_identifiers', '[]'::jsonb,
  'social_identifiers', '[]'::jsonb
)
contact: jsonb_build_object(
  'emails', '[]'::jsonb,
  'phones', '[]'::jsonb,
  'ims', '[]'::jsonb,
  'websites', '[]'::jsonb
)
addresses: '[]'::jsonb
emergency_contacts: '[]'::jsonb
health_info: jsonb_build_object(
  '_classification', 'RESTRICTED',
  '_access_roles', jsonb_build_array('ROL-ORG-CHRO'),
  'blood_type', null, 'allergies', '[]'::jsonb
)
biometric_data: jsonb_build_object(
  '_classification', 'RESTRICTED',
  '_gdpr_basis', 'explicit_consent',
  'face_photo_url', null, 'face_photo_hash', null
)
```

*Verificación:* `SELECT template->'personal_info'->>'_classification' FROM bauth.idn_user_template LIMIT 1;` → `'CONFIDENTIAL'`

**B3 — SECCIÓN 2: `professional_info` (líneas 46-49 del seed)**

Nombre actual: `'professionalInfo'` → `'professional_info'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'employeeType'` | `'employee_type'` |
| `'empresaId', u.empresa_id` | `'empresa_id', u.empresa_id` |
| `'sucursalId', u.sucursal_id` | `'sucursal_id', u.sucursal_id` |
| `'posLogico', u.pos_logico` | `'pos_logico', u.pos_logico` |

*Subestructuras faltantes según SECCIÓN 2:*
```
employee_code: null
employment_status: u.status
job: jsonb_build_object(
  'title', null, 'title_en', null, 'job_family', null,
  'job_level', null, 'job_code', null, 'fte_ratio', 1.0
)
organization: jsonb_build_object(
  'department', null, 'division', null, 'cost_center', null,
  'business_unit', null, 'legal_entity', null
)
reporting_line: jsonb_build_object(
  'manager_uuid', null, 'manager_username', null,
  'direct_reports_count', 0, 'direct_reports', '[]'::jsonb
)
employment_details: jsonb_build_object(
  'hire_date', null, 'original_hire_date', null,
  'termination_date', u.termination_date,
  'contract_type', 'INDEFINITE'
)
compensation: jsonb_build_object(
  '_classification', 'RESTRICTED',
  '_access_roles', jsonb_build_array('ROL-ORG-CHRO','ROL-ORG-CFO'),
  'salary_currency', null, 'salary_amount', null
)
office_location: jsonb_build_object(
  'building', null, 'floor', null, 'desk', null
)
schedule: jsonb_build_object(
  'assigned_schedule_id', (SELECT schedule_id FROM bcalendar.cal_schedule WHERE is_default = true LIMIT 1),
  'timezone', 'America/La_Paz'
)
certifications: '[]'::jsonb
education: '[]'::jsonb
skills: '[]'::jsonb
```

*Verificación:* `SELECT template->'professional_info'->'job' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B4 — SECCIÓN 3: `roles_assignments` (líneas 52-57 del seed)**

Nombre actual: `'rolesAssignments'` → `'roles_assignments'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'availableRoles'` | `'available_roles'` |
| `'assignedRoles'` | `'assigned_roles'` |
| `'primaryRoleId'` | `'primary_role_id'` |
| `'effectiveBitmask'` | `'effective_bitmask'` |

*Bug crítico a corregir:* `u.mask_eff_hex` → `u.rol_bitmask_base64` (columna DDL correcta, línea 3852)

*Subestructuras faltantes según SECCIÓN 3:*
```
active_roles: COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
    'assignment_id', r.assignment_id,
    'role_id', r.role_id,
    'assigned_at', r.assigned_at,
    'valid_from', r.valid_from,
    'valid_until', r.valid_until,
    'status', CASE WHEN r.is_active THEN 'ACTIVE' ELSE 'INACTIVE' END,
    'is_primary_role', true
  ))
  FROM bauth.idn_user_role r WHERE r.user_uuid = u.uuid AND r.is_active = true
), '[]'::jsonb)
role_history: '[]'::jsonb
delegations_received: '[]'::jsonb
delegations_given: '[]'::jsonb
role_compliance: jsonb_build_object(
  'sod_conflicts_detected', '[]'::jsonb,
  'compliant', true,
  'last_sod_check_at', null
)
```

*Verificación:* `SELECT template->'roles_assignments'->'active_roles' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B5 — SECCIÓN 4: `keycloak_credentials` (líneas 60-66 del seed)**

Nombre actual: `'keycloakCredentials'` → `'keycloak_credentials'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'mfaRequired'` | `'mfa_required'` |
| `'phishingResistantRequired'` | `'phishing_resistant_required'` |
| `'passkeyEnabled'` | `'passkey_enabled'` |
| `'kcUserId'` | `'kc_user_id'` |
| `'syncedToKC'` | `'synced_to_kc'` |
| `'recoveryMethods'` | `'recovery_methods'` |
| `'stepUpTriggers'` | `'step_up_triggers'` |

*Subestructuras faltantes según SECCIÓN 4 (contenido READ-ONLY desde KC):*
```
_readonly: true
_description: 'Estado sincronizado desde Keycloak Admin API — bAuth actualiza cada 60s'
password: jsonb_build_object(
  'has_password', true,
  'password_last_changed', null,
  'password_expires_at', null,
  'hibp_screened', false,
  'hibp_compromised', false
)
totp: jsonb_build_object('has_totp', false, 'devices', '[]'::jsonb)
webauthn: jsonb_build_object('has_webauthn', false, 'credentials', '[]'::jsonb)
passkeys: jsonb_build_object('has_passkey', false, 'credentials', '[]'::jsonb)
smartcard_x509: jsonb_build_object('has_x509_smartcard', false, 'credentials', '[]'::jsonb)
federated: jsonb_build_object('has_federated', false, 'providers', '[]'::jsonb)
backup_codes: jsonb_build_object('generated', false, 'remaining_codes', 0)
recovery: jsonb_build_object('methods', '[]'::jsonb, 'challenges', '[]'::jsonb)
credentials_compliance: jsonb_build_object('compliant', false, 'missing_methods', '[]'::jsonb)
login_activity: jsonb_build_object(
  'last_successful_login_at', u.last_login_at,
  'failed_login_attempts_24h', 0,
  'account_locked', false
)
kc_integration: jsonb_build_object(
  'kc_user_id', u.kc_user_id,
  'kc_realm', u.tenant_id,
  'kc_required_actions', '[]'::jsonb,
  'kc_email_verified', false
)
available_methods: COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
    'method_id', method_id, 'method_name', method_name,
    'aal_level', aal_level, 'nist_status', nist_status
  )) FROM bauth.ath_method WHERE active = true
), '[]'::jsonb)
```

*Verificación:* `SELECT template->'keycloak_credentials'->>'_readonly', template->'keycloak_credentials'->'login_activity' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `'true', true`

**B6 — SECCIÓN 5: `physical_credentials` (líneas 68-73 del seed)**

Nombre actual: `'physicalCredentials'` → `'physical_credentials'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'cardTypes'` | `'card_types'` |
| `'biometricEnrolled'` | `'biometric_enrolled'` |
| `'escortRequired'` | `'escort_required'` |
| `'twoPersonRule'` | `'two_person_rule'` |

*Subestructuras faltantes según SECCIÓN 5:*
```
smart_cards: '[]'::jsonb
mobile_credentials: '[]'::jsonb
biometric_enrollments: '[]'::jsonb
access_history: '[]'::jsonb
physical_restrictions: jsonb_build_object(
  'max_security_zone', 2,
  'requires_escort_in', '[]'::jsonb,
  'restricted_zones', '[]'::jsonb,
  'allowed_schedules', jsonb_build_array('business_hours'),
  'allowed_access_methods', COALESCE((
    SELECT jsonb_agg(DISTINCT method_id)
    FROM bauth.fis_zone_method_requirement
  ), '[]'::jsonb)
)
```

*Verificación:* `SELECT template->'physical_credentials'->'smart_cards' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B7 — SECCIÓN 6: `device_registry` (líneas 75-79 del seed)**

Nombre actual: `'deviceRegistry'` → `'device_registry'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'maxDevices'` | `'max_devices'` |
| `'requireAttestation'` | `'require_attestation'` |
| `'jailbreakDetection'` | `'jailbreak_detection'` |

*Subestructuras faltantes según SECCIÓN 6:*
```
primary_device: null
secondary_devices: '[]'::jsonb
device_trust_summary: jsonb_build_object(
  'active_devices_count', 0,
  'compromised_devices_count', 0,
  'any_jailbreak_detected', false,
  'any_root_detected', false
)
```

*Verificación:* `SELECT template->'device_registry'->'device_trust_summary' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B8 — SECCIÓN 7: `session_state` (líneas 81-86 del seed)**

Nombre actual: `'sessionState'` → `'session_state'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'maxConcurrentSessions'` | `'max_concurrent_sessions'` |
| `'sessionTimeoutMinutes'` | `'session_timeout_minutes'` |
| `'idleTimeoutMinutes'` | `'idle_timeout_minutes'` |
| `'lastLoginAt'` | `'last_login_at'` |
| `'lastActivityAt'` | `'last_activity_at'` |
| `'forceReauthAfterHours'` | `'force_reauth_after_hours'` |
| `'rememberDeviceDays'` | `'remember_device_days'` |
| `'contextId'` | `'current_ctx_id'` |
| `'contextHistory'` | `'bos_contexts'` |

*Subestructuras faltantes según SECCIÓN 7:*
```
dctx_id: null
context_actual: u.context_actual
ruta_canonica: null
active_sessions: '[]'::jsonb
session_history: '[]'::jsonb
context_switches: '[]'::jsonb
emergency_overrides: '[]'::jsonb
session_compliance: jsonb_build_object(
  'max_sessions_allowed', 1,
  'concurrent_sessions', 0,
  'within_limit', true,
  'force_logout_on_end_shift', true
)
```

*Verificación:* `SELECT template->'session_state'->>'context_actual' FROM bauth.idn_user_template LIMIT 1;` → valor de `context_actual`

**B9 — SECCIÓN 8: `location_profile` (líneas 88-93 del seed)**

Nombre actual: `'locationProfile'` → `'location_profile'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'homeCountry'` | `'home_country'` |
| `'homeTimezone'` | `'home_timezone'` |
| `'allowedCountries'` | `'allowed_countries'` |
| `'gpsTrackingConsent'` | `'gps_tracking_consent'` |

*Subestructuras faltantes según SECCIÓN 8:*
```
home_location: jsonb_build_object('country', 'BO', 'city', null, 'trust_tier', 'LOW')
work_location: jsonb_build_object('country', 'BO', 'geo_fence_status', null)
assigned_branches: '[]'::jsonb
blocked_countries: '[]'::jsonb
current_location: null
location_history: '[]'::jsonb
velocity_checks: '[]'::jsonb
velocity_violations: '[]'::jsonb
location_compliance: jsonb_build_object(
  'geo_fence_compliant', true,
  'country_allowed', true,
  'trust_tier_sufficient', true,
  'compliant', true
)
```

*Verificación:* `SELECT template->'location_profile'->'location_compliance' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B10 — SECCIÓN 9: `temporal_profile` (líneas 96-100 del seed)**

Nombre actual: `'temporalProfile'` → `'temporal_profile'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'overtimeAllowed'` | → eliminar, reemplazar por `'overtime'` como subobjeto |
| `'afterHoursRequiresApproval'` | → mover dentro de `'overtime'.requires_approval` |
| `'weekendAccessBlocked'` | → mover dentro de `'work_schedule'` |
| `'breakPolicy'` | `'breaks'` como subobjeto con subestructura |
| `'holidayCalendar'` | → mover dentro de `'holidays'.upcoming_holidays` |

*Estructura completa según SECCIÓN 9:*
```
assigned_schedule_id: (SELECT schedule_id FROM bcalendar.cal_schedule WHERE is_default = true LIMIT 1)
schedule_name: (SELECT name FROM bcalendar.cal_schedule WHERE is_default = true LIMIT 1)
timezone: 'America/La_Paz'
work_schedule: jsonb_build_object(
  'days', (SELECT jsonb_agg(jsonb_build_object('day', day_of_week, 'shifts', working_hours))
           FROM bcalendar.cal_schedule s, unnest(s.days_of_week) AS day_of_week
           WHERE is_default = true LIMIT 5),
  'total_hours_per_week', 40,
  'weekend_access_blocked', true
)
breaks: (SELECT jsonb_build_object(
  'lunch', jsonb_build_object('duration_minutes', b.lunch_duration_minutes, 'required', true),
  'short_breaks', jsonb_build_object('count', b.short_breaks_allowed, 'duration_minutes', b.short_break_minutes)
) FROM bcalendar.cal_break_policy b WHERE is_active = true LIMIT 1)
overtime: (SELECT jsonb_build_object(
  'authorized', false,
  'max_daily_hours', o.max_daily_hours,
  'rate_multiplier', o.rate_multiplier,
  'requires_approval', o.requires_approval
) FROM bcalendar.cal_overtime_policy o WHERE is_active = true LIMIT 1)
holidays: jsonb_build_object(
  'calendar_id', null,
  'behavior', 'BLOCKED',
  'upcoming_holidays', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('date', holiday_date, 'name', name, 'country', country_code))
    FROM bcalendar.cal_holiday WHERE country_code = 'BO' AND is_recurring = true
  ), '[]'::jsonb)
)
temporal_exceptions: '[]'::jsonb
attendance_today: null
attendance_history: '[]'::jsonb
fiscal_calendar: jsonb_build_object('current_fiscal_year', EXTRACT(year FROM now())::int)
```

*Verificación:* `SELECT template->'temporal_profile'->'overtime' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B11 — SECCIÓN 10: `network_profile` (líneas 102-106 del seed)**

Nombre actual: `'networkProfile'` → `'network_profile'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'vpnRequired'` | `'vpn_required'` |
| `'mTLSRequired'` | `'mtls_required'` |
| `'allowedServices'` | `'allowed_services'` → mover dentro de `ztna` |

*Subestructuras faltantes según SECCIÓN 10:*
```
allowed_cidrs: COALESCE((
  SELECT jsonb_agg(cidr) FROM bauth.idn_tenant_network WHERE is_active = true
), '[]'::jsonb)
device_trust_min_score: 70
current_network: null
network_history: '[]'::jsonb
vpn: jsonb_build_object('configured', false, 'provider', 'WIREGUARD', 'required_for_remote', true)
ztna: jsonb_build_object(
  'default_action', 'DENY',
  'allowed_services', COALESCE((
    SELECT jsonb_agg(app_slug) FROM bauth.privilege_application WHERE active = true
  ), '[]'::jsonb),
  'microsegmentation_enabled', false
)
certificate_pinning: jsonb_build_object(
  'enabled', true,
  'pinned_hosts', '[]'::jsonb,
  'last_pin_rotation', null
)
```

*Verificación:* `SELECT template->'network_profile'->'ztna' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B12 — SECCIÓN 11: `audit_profile` (líneas 108-113 del seed)**

Nombre actual: `'auditProfile'` → `'audit_profile'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'auditLevel'` | `'audit_level'` |
| `'logRetentionDays'` | `'retention_days'` |
| `'immutableLogs'` | `'hash_chain_required'` |
| `'complianceFrameworks'` | → mover dentro de `compliance_status` |
| `'auditEvents'` | → mover dentro de `event_summary` |

*Subestructuras faltantes según SECCIÓN 11:*
```
audit_level: 'basic'
retention_days: 2555
hash_chain_required: false
review_schedule: jsonb_build_object(
  'frequency', 'QUARTERLY',
  'last_review_date', null,
  'next_review_date', null,
  'sla_days', 14
)
significant_events: '[]'::jsonb
event_summary: jsonb_build_object(
  'total_events_90d', 0,
  'access_granted_90d', 0,
  'access_denied_90d', 0,
  'auth_failures_90d', 0
)
compliance_status: jsonb_build_object(
  'iso_27001', jsonb_build_object('applicable', true, 'compliant', true),
  'gdpr', jsonb_build_object('applicable', true, 'pii_access', true, 'legal_basis', 'legitimate_interest')
)
ghost_account_check: jsonb_build_object(
  'last_checked_at', null,
  'is_ghost', false,
  'days_since_last_login', 0,
  'kc_active_and_hr_active', true,
  'tryton_synced', u.tryton_user_id IS NOT NULL,
  'risk_score', 0
)
```

*Verificación:* `SELECT template->'audit_profile'->'ghost_account_check' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B13 — SECCIÓN 12: `external_services` (líneas 115-119 del seed)**

Nombre actual: `'externalServices'` → `'external_services'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'connectedApps'` | → reemplazar por `'consented_apps'` con estructura completa |
| `'federationProtocols'` | → mover a subobjeto dentro de `consented_apps` |

*Estructura completa según SECCIÓN 12:*
```
consented_apps: COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
    'client_id', app_slug, 'client_name', app_name, 'client_type', 'oidc',
    'scopes_granted', jsonb_build_array('openid','profile','email'),
    'consent_status', 'granted'
  )) FROM bauth.privilege_application WHERE active = true
), '[]'::jsonb)
consent_withdrawn: '[]'::jsonb
active_external_sessions: '[]'::jsonb
token_activity: jsonb_build_object(
  'total_tokens_issued_30d', 0,
  'tokens_refreshed_30d', 0,
  'tokens_revoked_30d', 0
)
consent_audit: jsonb_build_object(
  'total_consents_active', 0,
  'total_consents_withdrawn', 0,
  'gdpr_consent_compliant', true
)
```

*Verificación:* `SELECT template->'external_services'->'consent_audit' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B14 — SECCIÓN 13: `compliance_profile` (líneas 121-126 del seed)**

Nombre actual: `'complianceProfile'` → `'compliance_profile'`

*Claves internas a renombrar:*
| Campo actual | Campo correcto |
|---|---|
| `'gdprConsent'` | `'gdpr_consent'` dentro de subobjeto |
| `'dataSubjectRights'` | `'data_subject_rights'` dentro de subobjeto |
| `'dataRetention'` | `'data_retention'` dentro de subobjeto |

*Estructura completa según SECCIÓN 13:*
```
segregation_of_duties: jsonb_build_object(
  'active_conflicts', '[]'::jsonb,
  'conflicts_overridden', '[]'::jsonb,
  'last_sod_check_at', null,
  'compliant', true
)
conflict_of_interest: jsonb_build_object(
  'declarations', '[]'::jsonb,
  'family_relationships_in_company', '[]'::jsonb,
  'outside_interests', '[]'::jsonb,
  'compliant', true
)
required_certifications: '[]'::jsonb
policy_acknowledgments: '[]'::jsonb
risk_assessment: jsonb_build_object(
  'inherent_risk_score', 0,
  'residual_risk_score', 0,
  'risk_trend', 'STABLE',
  'last_assessment_at', null
)
gdpr_consent: jsonb_build_object('data_processing', true, 'marketing', false, 'third_party', false)
data_subject_rights: jsonb_build_array('access','rectification','erasure','portability','restriction','objection')
data_retention: jsonb_build_object('authentication_data_days', 365, 'audit_logs_days', 2555)
```

*Verificación:* `SELECT template->'compliance_profile'->'segregation_of_duties' IS NOT NULL FROM bauth.idn_user_template LIMIT 1;` → `true`

**B15 — SECCIÓN 14: `lifecycle_automation` (líneas 128-135 del seed)**

Nombre actual: `'lifecycleAutomation'` → `'lifecycle_automation'`

*Claves internas a renombrar y reestructurar:*
| Campo actual | Campo correcto |
|---|---|
| `'provisioning'` → objeto plano | `'provisioning'` con subestructura SECCIÓN 14 |
| `'syncStatus'` → objeto plano | `'sync_state'` con KC y Tryton separados |

*Estructura completa según SECCIÓN 14:*
```
provisioning: jsonb_build_object(
  'provisioning_source', 'MANUAL',
  'provisioning_method', 'SCIM_2_0',
  'provisioned_at', u.created_at,
  'provisioning_status', 'COMPLETED',
  'auto_provisioned_resources', jsonb_build_array(
    jsonb_build_object('resource','keycloak_user','status', CASE WHEN u.kc_user_id IS NOT NULL THEN 'CREATED' ELSE 'PENDING' END),
    jsonb_build_object('resource','tryton_res_user','status', CASE WHEN u.tryton_user_id IS NOT NULL THEN 'CREATED' ELSE 'PENDING' END)
  )
)
deprovisioning: jsonb_build_object(
  'deprovisioning_method', 'AUTOMATIC',
  'grace_period_days', 30,
  'steps', jsonb_build_array(
    jsonb_build_object('step','REVOKE_SESSIONS','order',1,'delay_after_termination','IMMEDIATE'),
    jsonb_build_object('step','REVOKE_CREDENTIALS','order',2,'delay_after_termination','IMMEDIATE'),
    jsonb_build_object('step','DISABLE_KC_ACCOUNT','order',3,'delay_after_termination','IMMEDIATE'),
    jsonb_build_object('step','PURGE_PII','order',4,'delay_after_termination','30_DAYS')
  )
)
sync_state: jsonb_build_object(
  'kc_sync_status', u.sync_status,
  'kc_user_id', u.kc_user_id,
  'kc_last_sync_at', null,
  'tryton_sync_status', CASE WHEN u.tryton_user_id IS NOT NULL THEN 'SYNCED' ELSE 'PENDING' END,
  'tryton_user_id', u.tryton_user_id,
  'tryton_last_sync_at', null,
  'drift_detected', false
)
notifications: jsonb_build_object(
  'on_role_change', true,
  'on_password_change', true,
  'on_new_device', true,
  'on_suspicious_activity', true,
  'channels', jsonb_build_array('email','push'),
  'preferred_channel', 'push'
)
```

*Verificación:* `SELECT template->'lifecycle_automation'->'sync_state'->>'kc_sync_status' FROM bauth.idn_user_template LIMIT 1;` → valor de `sync_status`

---

#### GRUPO C — Reparación completa de seed_idn_role_template_data.sql

**Archivo:** `seeds/seed_idn_role_template_data.sql`
**SSOT:** `BAUTH-ROLTEMPLATE-SECCIONES.md` v6.0 (14 secciones canónicas)
**Nota:** `template_version = '6.0.0'` en línea 11 ya es correcto — no requiere cambio.

**C1 — BLOQUE 4: `financial` → `financial_limits` (línea 118)**

- Línea exacta: `'financial', (`
- Cambiar a: `'financial_limits', (`
- Dominio: D3 (Financiero)
- Referencia canónica: SECCIÓN 3 `financial_limits` en `BAUTH-ROLTEMPLATE-SECCIONES.md`
- Verificación: `SELECT template->'financial_limits' IS NOT NULL FROM bauth.idn_role_template LIMIT 1;` → `true`

**C2 — BLOQUE 5: `temporal` → `temporal_schedule` (línea 164)**

- Línea exacta: `'temporal', (`
- Cambiar a: `'temporal_schedule', (`
- Dominio: D4 (Temporal)
- Referencia canónica: SECCIÓN 4 `temporal_schedule`
- Verificación: `SELECT template->'temporal_schedule' IS NOT NULL FROM bauth.idn_role_template LIMIT 1;` → `true`

**C3 — BLOQUE 9: `context` → `session_context` (línea 293)**

- Línea exacta: `'context', (`
- Cambiar a: `'session_context', (`
- Dominio: D8 (Contexto/Sesión)
- Referencia canónica: SECCIÓN 8 `session_context`
- Verificación: `SELECT template->'session_context' IS NOT NULL FROM bauth.idn_role_template LIMIT 1;` → `true`

**C4 — BLOQUE 10: `credentials` → `credential_policy` (línea 316)**

- Línea exacta: `'credentials', (`
- Cambiar a: `'credential_policy', (`
- Dominio: D9 (Credenciales)
- Referencia canónica: SECCIÓN 9 `credential_policy`
- Verificación: `SELECT template->'credential_policy' IS NOT NULL FROM bauth.idn_role_template LIMIT 1;` → `true`

**C5-C6 — BLOQUE 14+15: `security` + `compliance` → fusionar en `conflict_management` (líneas 438 y 462)**

- Bloque `'security'` (línea 438): eliminar el bloque completo (contiene `keyInventory`, `cryptoAlgorithms`, `sodValidation`, `securityZone`)
- Bloque `'compliance'` (línea 462): renombrar a `'conflict_management'`
- Contenido a fusionar: incorporar `'sodValidation'` del bloque eliminado dentro del nuevo `'conflict_management'`
- Dominio: SoD/Compliance
- Referencia canónica: SECCIÓN 14 `conflict_management`
- Estructura final de `conflict_management`:
```
'conflict_management', (
  WITH sod_config AS (
    SELECT jsonb_build_object(
      'check_frequency', check_frequency, 'auto_remediate', auto_remediate
    ) AS config
    FROM bauth.sod_validation_config WHERE is_active = true LIMIT 1
  )
  SELECT jsonb_build_object(
    'frameworks', jsonb_build_array('ISO 27001:2022','NIST SP 800-53 Rev 5','PCI DSS 4.0','GDPR','SOX §404'),
    'sod_validation', COALESCE((SELECT config FROM sod_config), '{}'::jsonb),
    'gdpr_consent', jsonb_build_object('data_processing', true, 'marketing', false, 'third_party', false),
    'data_subject_rights', jsonb_build_array('access','rectification','erasure','portability','restriction','objection'),
    'data_retention_days', 2555,
    'breach_notification_hours', 72,
    'compliance_status', CASE WHEN r.tier IN ('SU','SYS','BIZ_N1') THEN 'full'
                              WHEN r.audit_level = 'full' THEN 'full'
                              ELSE 'basic' END,
    'controls_implemented', (SELECT count(*)::int FROM bauth.aud_compliance_map WHERE implementation_status = 'implemented'),
    'controls_total', (SELECT count(*)::int FROM bauth.aud_compliance_map)
  )
)
```
- Verificación: `SELECT template->'conflict_management' IS NOT NULL, template->'security' IS NULL FROM bauth.idn_role_template LIMIT 1;` → `true, true`

**C7 — BLOQUE 16: `sync` → `sync_metadata` (línea 480)**

- Línea exacta: `'sync', jsonb_build_object(`
- Cambiar a: `'sync_metadata', jsonb_build_object(`
- Dominio: META (sincronización KC + Tryton)
- Referencia canónica: SECCIÓN 13 `sync_metadata`
- Verificación: `SELECT template->'sync_metadata' IS NOT NULL FROM bauth.idn_role_template LIMIT 1;` → `true`

---

#### GRUPO D — Verificación de frameworks referenciados

**D1 — Verificar ausencia de frameworks incorrectos en seeds**
- Comando: `grep -rl "Authentication_Framework_v3\|Policies_Authentication_Framework_v4" seeds/`
- Resultado esperado: sin salida (ningún archivo los referencia)
- Si hay referencias: corregir en el archivo señalado → cambiar a `Authentication_Framework.json` y `Policies_Authentication_Framework.json`

**D2 — Verificar frameworks correctos disponibles**
- Verificar existencia: `ls plandeaccion/bauth/Authentication_Framework.json plandeaccion/bauth/Policies_Authentication_Framework.json`
- Resultado esperado: ambos archivos existen (12,945 líneas y 2,545 líneas respectivamente)
- Estos son los SSOT de autenticación para cualquier referencia en los seeds

---

### FASE 1 — DDL: idn_atributo + D00 (PENDIENTE APROBACIÓN HUMANO)

Crear migración `003_d00_rediseño_completo.sql` con:

| Paso | Cambio DDL | Estado |
|------|-----------|:------:|
| 1.1 | Agregar `is_internal boolean` a `idn_tenant` | ⏳ |
| 1.2 | Habilitar `domain_code=0` en `privilege_domain` CHECK | ⏳ |
| 1.3 | Insertar dominio D00 en `privilege_domain` | ⏳ |
| 1.4 | Insertar aplicación `org` (app_code=13) | ⏳ |
| 1.5 | Insertar 5 grupos (g1=tenant, g2=bdomain, g3=bsubdomain, g4=pos, g5=actor) | ⏳ |
| 1.6 | Eliminar verbos semánticos 51-63 (reemplazados por CRUD 1-4) | ⏳ |
| 1.7 | Insertar 120 átomos CRUD D00 (posiciones 5809-5928) en `privilege_atom` | ⏳ |
| 1.8 | Crear tabla `idn_atributo` (diseño en BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md) | ⏳ |
| 1.9 | Migrar datos de `org_contacto` → `idn_atributo` (category=contacto) | ⏳ |
| 1.10 | Migrar datos de `org_documento` → `idn_atributo` (category=documento) | ⏳ |
| 1.11 | Migrar datos de `org_direccion` → `idn_atributo` (category=ubicacion) | ⏳ |
| 1.12 | DROP TABLE `org_contacto`, `org_documento`, `org_direccion` (después de validar migración) | ⏳ |

**Bloqueo:** Requiere aprobación explícita del humano antes de escribir o aplicar.

---

### FASE 2 — DDL: átomos D4-D12 (PENDIENTE APROBACIÓN HUMANO)

Insertar en `privilege_atom` los átomos de cada dominio:

| Paso | Dominio | Átomos | Estado |
|------|---------|:------:|:------:|
| 2.1 | D4 — Físico (D4.001-D4.028) | 28 | ⏳ |
| 2.2 | D5 — Dispositivos (D5.001-D5.020) | 20 | ⏳ |
| 2.3 | D6 — Geoespacial (D6.001-D6.016) | 16 | ⏳ |
| 2.4 | D7 — Financiero (D7.001-D7.024) | 24 | ⏳ |
| 2.5 | D8 — Temporal (D8.001-D8.024) | 24 | ⏳ |
| 2.6 | D9 — Red (D9.001-D9.020) | 20 | ⏳ |
| 2.7 | D10 — Auditoría (D10.001-D10.012) | 12 | ⏳ |
| 2.8 | D11 — Biométrico (D11.001-D11.016) | 16 | ⏳ |
| 2.9 | D12 — Delegación/Compliance (D12.001-D12.028) | 28 | ⏳ |
| 2.10 | Actualizar `bitmask_bundle` para incluir 364 posiciones nuevas | ⏳ |

**Bloqueo:** Requiere aprobación explícita del humano antes de escribir o aplicar.

---

### FASE 3 — DDL: D13 blockchain (PENDIENTE APROBACIÓN HUMANO)

| Paso | Cambio DDL | Estado |
|------|-----------|:------:|
| 3.1 | Insertar dominio D13 en `privilege_domain` | ⏳ |
| 3.2 | Insertar 3 aplicaciones D13 (chain, did, legalsg) | ⏳ |
| 3.3 | Insertar 36 átomos D13 (posiciones 5929-5964) | ⏳ |

**Bloqueo:** Requiere aprobación explícita del humano antes de escribir o aplicar.

---

### FASE 4 — Seeds: datos iniciales

| Paso | Seed | Estado |
|------|------|:------:|
| 4.1 | Seed átomos D00 (120 filas) en `privilege_atom` | ⏳ |
| 4.2 | Seed átomos D4-D12 (188 filas) en `privilege_atom` | ⏳ |
| 4.3 | Seed átomos D13 (36 filas) en `privilege_atom` | ⏳ |
| 4.4 | Seed roles base con asignaciones CRUD D00 (AUDITORIA_LECTURA, RR_HH, ADMIN, SELF_SERVICE) | ⏳ |
| 4.5 | Seed `idn_atributo` tipos de contacto por defecto (display_format codes) | ⏳ |

---

### FASE 5 — Código Rust: adaptar domain/

| Paso | Módulo Rust | Estado |
|------|------------|:------:|
| 5.1 | `domain/roltemplate_validator.rs` — validar contra 14 bloques nuevos | ⏳ |
| 5.2 | `domain/usertemplate_validator.rs` — validar contra 16 bloques nuevos | ⏳ |
| 5.3 | Nuevo: `domain/atributo_extensible.rs` — CRUD de `idn_atributo` | ⏳ |
| 5.4 | Adaptar `server/handlers/` para átomos CRUD D00-D13 | ⏳ |
| 5.5 | Adaptar `sync/role_sync.rs` para sincronizar con átomos D4-D12 en KC | ⏳ |

---

### FASE 6 — Validación en VPS

| Paso | Verificación | Estado |
|------|-------------|:------:|
| 6.1 | Compilar bAuth MUSL, scp a VPS | ⏳ |
| 6.2 | Aplicar migración 003 en VPS | ⏳ |
| 6.3 | Verificar 364 átomos nuevos en `privilege_atom` | ⏳ |
| 6.4 | Test CRUD: crear usuario con email+teléfono+nationality en idn_atributo | ⏳ |
| 6.5 | Test CRUD: asignar rol ADMIN con átomos D00 completos | ⏳ |
| 6.6 | Test BitMask: verificar que bitmask_bundle incluye bits D00 (5809-5928) | ⏳ |
| 6.7 | Test cobertura: crear UserTemplate completo (16 bloques) sin error | ⏳ |
| 6.8 | Test cobertura: crear RolTemplate completo (14 bloques) sin error | ⏳ |

---

## Dependencias entre fases

```
FASE 0 (Diseño) ✅ COMPLETADA
    ↓
FASE 0.S (Auditoría y Reparación Seeds Existentes) ← SIN BLOQUEO, ejecutable ya
    ↓
FASE 1 (DDL D00)  ← requiere aprobación humana
    ↓
FASE 2 (DDL D4-D12)  ←→  FASE 3 (DDL D13)  [paralelas]  ← requieren aprobación humana
    ↓
FASE 4 (Seeds Nuevos)  ← depende de FASE 1-3 + FASE 0.S
    ↓
FASE 5 (Código Rust)
    ↓
FASE 6 (VPS)
```

**FASE 0.S:** ejecutable sin aprobación DDL — solo edita seeds existentes.
**FASES 1-3:** requieren aprobación humana explícita del DDL antes de ejecutar.
**FASE 4:** solo puede ejecutarse después de FASE 0.S + FASES 1-3 completas.

---

## Reglas de trabajo en REPARACIONBAUTH

1. **Toda tarea nueva** se agrega primero en `REGISTRO-ESTADO-REDISEÑO.md` antes de ejecutarse
2. **Ningún DDL se escribe** sin aprobación explícita del humano
3. **Ningún DDL se aplica** sin haber sido revisado y aprobado
4. **Al completar cada paso**, marcar en REGISTRO-ESTADO-REDISEÑO.md con fecha y commit
5. **Compilar local, scp a VPS** — nunca compilar en servidor (ADR-016 flujo de trabajo)
6. **Español obligatorio** en código, comentarios y comunicación
