# REGISTRO-ESTADO-REDISEÑO — Control de Avance · bAuth Rediseño v3.0
## Carpeta REPARACIONBAUTH · Registro canónico y autoritativo

**Versión:** 1.1.0 · **Fecha inicio:** 2026-07-01
**Última actualización:** 2026-07-01

---

## Estado general

| Fase | Nombre | Estado | Inicio | Cierre |
|------|--------|:------:|:------:|:------:|
| FASE 0 | Diseño — cobertura 100% | ✅ COMPLETADA | 2026-07-01 | 2026-07-01 |
| **FASE 0.S** | **Auditoría y Reparación Seeds Existentes** | **⏳ PENDIENTE** | — | — |
| FASE 1 | DDL D00 + idn_atributo | 🔒 BLOQUEADA — aprobación DDL | — | — |
| FASE 2 | DDL D4-D12 átomos | 🔒 BLOQUEADA — aprobación DDL | — | — |
| FASE 3 | DDL D13 blockchain | 🔒 BLOQUEADA — aprobación DDL | — | — |
| FASE 4 | Seeds nuevos (rediseño) | ⏳ PENDIENTE (depende F0.S + F1-F3) | — | — |
| FASE 5 | Código Rust domain/ | ⏳ PENDIENTE (depende F4) | — | — |
| FASE 6 | Validación VPS | ⏳ PENDIENTE (depende F5) | — | — |

---

## FASE 0 — DISEÑO (COMPLETADA)

| ID | Tarea | Estado | Fecha | Resultado |
|----|-------|:------:|:-----:|-----------|
| F0.D1 | Verificar cobertura UserTemplate v6.0 (16 bloques) | ✅ | 2026-07-01 | BAUTH-COBERTURA-100PCT.md §PARTE1 |
| F0.D2 | Verificar cobertura RolTemplate v6.0 (14 bloques) | ✅ | 2026-07-01 | BAUTH-COBERTURA-100PCT.md §PARTE2 |
| F0.D3 | Diseñar 120 átomos CRUD D00 (30 campos × 4) | ✅ | 2026-07-01 | BAUTH-CATALOGO-ATOMOS-D00-CRUD.md |
| F0.D4 | Diseñar 188 átomos CRUD D4-D12 (47 campos × 4) | ✅ | 2026-07-01 | BAUTH-CATALOGO-ATOMOS-D4-D12.md |
| F0.D5 | Diseñar 36 átomos D13 blockchain + firma legal | ✅ | 2026-07-01 | BAUTH-DOMINIO-D13-BLOCKCHAIN.md |
| F0.D6 | Definir idn_atributo + bglobal integration (v1.3.0) | ✅ | 2026-07-01 | BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md |
| F0.D7 | Actualizar BAUTH-ARQUITECTURA-ATOMICA-FINAL.md (v1.1.0) | ✅ | 2026-07-01 | BAUTH-ARQUITECTURA-ATOMICA-FINAL.md |
| F0.D8 | Confirmar cobertura 100% (82 campos UT + 74 campos RT) | ✅ | 2026-07-01 | BAUTH-COBERTURA-100PCT.md §Conclusión |

**Resultado FASE 0:** ✅ COMPLETADA — Diseño 100% verificado. Listo para aprobación DDL.

---

## FASE 0.S — Auditoría y Reparación de Seeds Existentes

**Sin bloqueo — ejecutable sin aprobación DDL.**
**Directorio:** `BauthAgent/db/migrations/seeds/` (83 archivos: 81 seeds + run_all_seeds.sql + 1 huérfano)
**SSOT nomenclatura:** `BAUTH-USERTEMPLATE-SECCIONES.md` · `BAUTH-ROLTEMPLATE-SECCIONES.md`
**SSOT autenticación:** `Authentication_Framework.json` (v2.0.0) · `Policies_Authentication_Framework.json` (v3.0.0)

---

### GRUPO A — Inventario y organización lógica del orquestador

**Archivo objetivo:** `seeds/run_all_seeds.sql`

| ID | Tarea atómica | Cambio exacto | Criterio de verificación | Estado | Inicio | Cierre |
|----|--------------|---------------|--------------------------|:------:|:------:|:------:|
| F0S.A1 | Corregir encabezado contador en línea 2 | `'49 seeds'` → `'82 seeds'` | `grep 'run_all_seeds.sql — Ejecución ordenada de 82'` retorna la línea | ⏳ | — | — |
| F0S.A2 | Corregir `\echo` final del archivo | `'=== 54 seeds ejecutados ==='` → `'=== 82 seeds ejecutados ==='` | `grep '82 seeds ejecutados' run_all_seeds.sql` retorna la línea | ⏳ | — | — |
| F0S.A3 | Agregar `seed_compliance_results.sql` en FASE 11 | Insertar `\ir seed_compliance_results.sql` después de `\ir seed_compliance_qa.sql` en FASE 11 | `grep 'seed_compliance_results' run_all_seeds.sql` retorna línea con `\ir` | ⏳ | — | — |
| F0S.A4 | Verificar orden FK: FASE 1 antes que FASE 2 | Confirmar que `privilege_*` (FASE 1) precede a `idn_tenant` (FASE 2) en el archivo | `grep -n 'FASE 1\|FASE 2' run_all_seeds.sql` muestra FASE 1 con número de línea menor | ⏳ | — | — |

---

### GRUPO B — Reparación completa de 064_idn_user_template_data.sql

**Archivo objetivo:** `seeds/064_idn_user_template_data.sql` (138 líneas)
**Tabla DDL:** `bauth.idn_user_template` (DDL línea 3840–3866)
**Columna DDL corregida:** `rol_bitmask_base64` (línea 3852) — reemplaza `mask_eff_hex` que NO existe
**SSOT:** `BAUTH-USERTEMPLATE-SECCIONES.md` v6.0 — 15 secciones snake_case, versión `'6.0.0'`

#### B0 — Correcciones globales (3 bugs críticos)

| ID | Ubicación exacta | Valor actual | Valor correcto | Verificación | Estado |
|----|-----------------|-------------|----------------|-------------|:------:|
| F0S.B0.1 | Línea 23 dentro del JSONB `template` | `'version', '3.0'` | `'version', '6.0.0'` | `SELECT template->>'version' FROM bauth.idn_user_template LIMIT 1` → `'6.0.0'` | ⏳ |
| F0S.B0.2 | Línea 57 en sección `rolesAssignments` | `u.mask_eff_hex` | `u.rol_bitmask_base64` | `\d bauth.idn_user_template` confirma columna existe | ⏳ |
| F0S.B0.3 | Línea 136 clausula SET | `template_version = '3.0'` | `template_version = '6.0.0'` | `SELECT template_version FROM bauth.idn_user_template LIMIT 1` → `'6.0.0'` | ⏳ |

#### B1 — SECCIÓN 0: identity (líneas 27–34)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B1.1 | Renombrar 9 claves internas | `tenantId`→`tenant_id`, `empresaId`→`empresa_id`, `sucursalId`→`sucursal_id`, `posLogico`→`pos_logico`, `accountType`→`account_type`, `userType`→`user_type`, `preferredLanguage`→`preferred_language`, `identityProvider`→`identity_provider`, `kcUserId`→`kc_user_id` | `SELECT template->'identity'->>'tenant_id' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B1.2 | Agregar campo `external_id` | Fuente: `u.external_id` (columna DDL línea 3842) | `SELECT template->'identity'->>'external_id' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B1.3 | Agregar campo `zoneinfo` | `COALESCE(u.template->>'zoneinfo', 'America/La_Paz')` | `SELECT template->'identity'->>'zoneinfo' FROM bauth.idn_user_template LIMIT 1` → `'America/La_Paz'` | ⏳ |
| F0S.B1.4 | Agregar campo `realm_kc` | Fuente: `u.tenant_id` (realm KC = tenant_id) | `SELECT template->'identity'->>'realm_kc' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B1.5 | Agregar campo `namespace_k8s` | `'tenant-' \|\| u.tenant_id` | `SELECT template->'identity'->>'namespace_k8s' FROM bauth.idn_user_template LIMIT 1` → `'tenant-...'` | ⏳ |
| F0S.B1.6 | Agregar subobjeto `lifecycle` | 7 campos: `created_at`, `activated_at=null`, `status_changed_at=null`, `termination_date`, `termination_reason`, `offboarding_status=null`, `purge_after=null` (fuentes: DDL cols lines 3855-3858) | `SELECT template->'identity'->'lifecycle'->>'created_at' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B1.7 | Agregar subobjeto `federation` | 5 campos: `federated_idp=null`, `federated_user_id=null`, `federated_username=null`, `identity_provider='keycloak'`, `brokering_enabled=false` | `SELECT template->'identity'->'federation'->>'identity_provider' FROM bauth.idn_user_template LIMIT 1` → `'keycloak'` | ⏳ |
| F0S.B1.8 | Agregar subobjeto `digital_signature` | 5 campos: `algorithm='EdDSA_Ed25519'`, `post_quantum_planned='CRYSTALS-Dilithium'`, `certificate_thumbprint=null`, `timestamp=null`, `validity={not_before:null,not_after:null}` | `SELECT template->'identity'->'digital_signature'->>'algorithm' FROM bauth.idn_user_template LIMIT 1` → `'EdDSA_Ed25519'` | ⏳ |
| F0S.B1.9 | Agregar subobjeto `audit_trail` | 3 campos: `created_by='system'`, `updated_by='system'`, `updated_at=u.updated_at` (DDL col línea 3866) | `SELECT template->'identity'->'audit_trail'->>'created_by' FROM bauth.idn_user_template LIMIT 1` → `'system'` | ⏳ |

#### B2 — SECCIÓN 1: personal_info (líneas 37–43)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B2.1 | Renombrar clave principal | `'personalInfo'` → `'personal_info'` en JSONB raíz | `SELECT template->'personal_info' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B2.2 | Renombrar claves internas | `maritalStatus`→`marital_status`, `idDocumentType`→`id_document_type`, `preferredLanguage`→`preferred_language` | `SELECT template->'personal_info'->>'marital_status' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B2.3 | Agregar `_classification` y `_access_control` | `_classification='CONFIDENTIAL'`, `_access_control={full_access_roles:[ROL-SYS-ADMIN-SEGURIDAD], masked_access_roles:[ROL-ORG-GER-RRHH], restricted_fields:[national_id,birth_date,bank_account], gdpr_sensitive_fields:[gender,nationality,biometric_data,health_info]}` | `SELECT template->'personal_info'->>'_classification' FROM bauth.idn_user_template LIMIT 1` → `'CONFIDENTIAL'` | ⏳ |
| F0S.B2.4 | Agregar subobjeto `name` | 8 campos: `given_name=null`, `middle_name=null`, `family_name=null`, `second_family_name=null`, `full_name=null`, `formatted_name=null`, `initials=null`, `previous_names=[]` | `SELECT template->'personal_info'->'name' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B2.5 | Agregar subobjeto `demographics` | 5 campos: `birth_date=null`, `gender=null`, `nationality=null`, `nationality_secondary=null`, `marital_status=null` | `SELECT template->'personal_info'->'demographics' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B2.6 | Agregar subobjeto `identification` | Estructura: `primary_document={type,number,verified:false}`, `secondary_documents=[]`, `tax_identifiers=[]`, `social_identifiers=[]` | `SELECT template->'personal_info'->'identification'->'primary_document'->>'verified' FROM bauth.idn_user_template LIMIT 1` → `'false'` | ⏳ |
| F0S.B2.7 | Agregar subobjeto `contact` | 4 arrays: `emails=[]`, `phones=[]`, `ims=[]`, `websites=[]` | `SELECT jsonb_array_length(template->'personal_info'->'contact'->'emails') FROM bauth.idn_user_template LIMIT 1` → `0` | ⏳ |
| F0S.B2.8 | Agregar arrays: `addresses=[]`, `emergency_contacts=[]` | Arrays vacíos según SECCIÓN 1 | `SELECT jsonb_array_length(template->'personal_info'->'addresses') FROM bauth.idn_user_template LIMIT 1` → `0` | ⏳ |
| F0S.B2.9 | Agregar subobjetos restringidos: `health_info` y `biometric_data` | `health_info={_classification:RESTRICTED, _access_roles:[ROL-ORG-CHRO], blood_type:null, allergies:[]}`, `biometric_data={_classification:RESTRICTED, _gdpr_basis:explicit_consent, face_photo_url:null, face_photo_hash:null}` | `SELECT template->'personal_info'->'health_info'->>'_classification' FROM bauth.idn_user_template LIMIT 1` → `'RESTRICTED'` | ⏳ |

#### B3 — SECCIÓN 2: professional_info (líneas 46–49)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B3.1 | Renombrar clave principal | `'professionalInfo'` → `'professional_info'` | `SELECT template->'professional_info' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B3.2 | Renombrar claves internas | `employeeType`→`employee_type`, `empresaId`→`empresa_id`, `sucursalId`→`sucursal_id`, `posLogico`→`pos_logico` | `SELECT template->'professional_info'->>'employee_type' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B3.3 | Agregar `employment_status` | Fuente: `u.status` (DDL col línea 3853) | `SELECT template->'professional_info'->>'employment_status' FROM bauth.idn_user_template LIMIT 1` retorna valor de `u.status` | ⏳ |
| F0S.B3.4 | Agregar subobjetos: `job`, `organization`, `reporting_line`, `employment_details` | `job={title,title_en,job_family,job_level,job_code,fte_ratio:1.0}`, `organization={department,division,cost_center,business_unit,legal_entity}`, `reporting_line={manager_uuid,manager_username,direct_reports_count:0,direct_reports:[]}`, `employment_details={hire_date,original_hire_date,termination_date:u.termination_date,contract_type:INDEFINITE}` | `SELECT template->'professional_info'->'job'->>'fte_ratio' FROM bauth.idn_user_template LIMIT 1` → `'1'` | ⏳ |
| F0S.B3.5 | Agregar `compensation` (clasificación RESTRICTED) | `{_classification:RESTRICTED, _access_roles:[ROL-ORG-CHRO,ROL-ORG-CFO], salary_currency:null, salary_amount:null}` | `SELECT template->'professional_info'->'compensation'->>'_classification' FROM bauth.idn_user_template LIMIT 1` → `'RESTRICTED'` | ⏳ |
| F0S.B3.6 | Agregar arrays: `certifications=[]`, `education=[]`, `skills=[]` | Arrays vacíos según SECCIÓN 2 | `SELECT jsonb_array_length(template->'professional_info'->'skills') FROM bauth.idn_user_template LIMIT 1` → `0` | ⏳ |

#### B4 — SECCIÓN 3: roles_assignments (líneas 52–57)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B4.1 | Renombrar clave principal | `'rolesAssignments'` → `'roles_assignments'` | `SELECT template->'roles_assignments' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B4.2 | Renombrar claves internas | `availableRoles`→`available_roles`, `assignedRoles`→`assigned_roles`, `primaryRoleId`→`primary_role_id`, `effectiveBitmask`→`effective_bitmask` | `SELECT template->'roles_assignments'->>'primary_role_id' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B4.3 | Corregir columna DDL en `effective_bitmask` | Fuente: `u.mask_eff_hex` (NO EXISTE) → `u.rol_bitmask_base64` (DDL línea 3852) | `SELECT template->'roles_assignments'->>'effective_bitmask' IS NOT NULL FROM bauth.idn_user_template WHERE rol_bitmask_base64 IS NOT NULL LIMIT 1` → `true` | ⏳ |
| F0S.B4.4 | Agregar `active_roles` desde subconsulta | Sub-SELECT de `bauth.idn_user_role` filtrando por `user_uuid=u.uuid AND is_active=true` — estructura: `{assignment_id,role_id,assigned_at,valid_from,valid_until,status,is_primary_role}` | `SELECT jsonb_array_length(template->'roles_assignments'->'active_roles') FROM bauth.idn_user_template LIMIT 1` retorna número | ⏳ |
| F0S.B4.5 | Agregar arrays y objeto compliance | `role_history=[]`, `delegations_received=[]`, `delegations_given=[]`, `role_compliance={sod_conflicts_detected:[],compliant:true,last_sod_check_at:null}` | `SELECT template->'roles_assignments'->'role_compliance'->>'compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |

#### B5 — SECCIÓN 4: keycloak_credentials (líneas 60–66)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B5.1 | Renombrar clave principal | `'keycloakCredentials'` → `'keycloak_credentials'` | `SELECT template->'keycloak_credentials' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B5.2 | Renombrar 7 claves internas | `mfaRequired`→`mfa_required`, `phishingResistantRequired`→`phishing_resistant_required`, `passkeyEnabled`→`passkey_enabled`, `kcUserId`→`kc_user_id`, `syncedToKC`→`synced_to_kc`, `recoveryMethods`→`recovery_methods`, `stepUpTriggers`→`step_up_triggers` | `SELECT template->'keycloak_credentials'->>'mfa_required' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B5.3 | Agregar marcador `_readonly=true` y `_description` | Marca que la sección es sincronizada desde KC Admin API cada 60s | `SELECT template->'keycloak_credentials'->>'_readonly' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |
| F0S.B5.4 | Agregar subobjetos de credenciales individuales | `password={has_password:true,password_last_changed:null,hibp_screened:false}`, `totp={has_totp:false,devices:[]}`, `webauthn={has_webauthn:false,credentials:[]}`, `passkeys={has_passkey:false,credentials:[]}`, `smartcard_x509={has_x509_smartcard:false}`, `backup_codes={generated:false,remaining_codes:0}` | `SELECT template->'keycloak_credentials'->'password'->>'has_password' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |
| F0S.B5.5 | Agregar `login_activity` y `kc_integration` | `login_activity={last_successful_login_at:u.last_login_at,failed_login_attempts_24h:0,account_locked:false}`, `kc_integration={kc_user_id:u.kc_user_id,kc_realm:u.tenant_id,kc_required_actions:[],kc_email_verified:false}` | `SELECT template->'keycloak_credentials'->'kc_integration'->>'kc_realm' FROM bauth.idn_user_template LIMIT 1` retorna valor de `tenant_id` | ⏳ |

#### B6 — SECCIÓN 5: physical_credentials (líneas 68–73)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B6.1 | Renombrar clave principal | `'physicalCredentials'` → `'physical_credentials'` | `SELECT template->'physical_credentials' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B6.2 | Renombrar 4 claves internas | `cardTypes`→`card_types`, `biometricEnrolled`→`biometric_enrolled`, `escortRequired`→`escort_required`, `twoPersonRule`→`two_person_rule` | `SELECT template->'physical_credentials'->>'escort_required' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B6.3 | Agregar arrays y subobjeto de restricciones | `smart_cards=[]`, `mobile_credentials=[]`, `biometric_enrollments=[]`, `access_history=[]`, `physical_restrictions={max_security_zone:2,requires_escort_in:[],restricted_zones:[],allowed_schedules:[business_hours]}` | `SELECT template->'physical_credentials'->'physical_restrictions'->>'max_security_zone' FROM bauth.idn_user_template LIMIT 1` → `'2'` | ⏳ |

#### B7 — SECCIÓN 6: device_registry (líneas 75–79)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B7.1 | Renombrar clave principal | `'deviceRegistry'` → `'device_registry'` | `SELECT template->'device_registry' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B7.2 | Renombrar 3 claves internas | `maxDevices`→`max_devices`, `requireAttestation`→`require_attestation`, `jailbreakDetection`→`jailbreak_detection` | `SELECT template->'device_registry'->>'max_devices' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B7.3 | Agregar `primary_device=null`, `secondary_devices=[]`, `device_trust_summary` | `device_trust_summary={active_devices_count:0,compromised_devices_count:0,any_jailbreak_detected:false,any_root_detected:false}` | `SELECT template->'device_registry'->'device_trust_summary'->>'active_devices_count' FROM bauth.idn_user_template LIMIT 1` → `'0'` | ⏳ |

#### B8 — SECCIÓN 7: session_state (líneas 81–86)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B8.1 | Renombrar clave principal | `'sessionState'` → `'session_state'` | `SELECT template->'session_state' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B8.2 | Renombrar 9 claves internas | `maxConcurrentSessions`→`max_concurrent_sessions`, `sessionTimeoutMinutes`→`session_timeout_minutes`, `idleTimeoutMinutes`→`idle_timeout_minutes`, `lastLoginAt`→`last_login_at`, `lastActivityAt`→`last_activity_at`, `forceReauthAfterHours`→`force_reauth_after_hours`, `rememberDeviceDays`→`remember_device_days`, `contextId`→`current_ctx_id`, `contextHistory`→`bos_contexts` | `SELECT template->'session_state'->>'current_ctx_id' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B8.3 | Agregar campos de contexto faltantes | `dctx_id=null`, `context_actual=u.context_actual` (DDL línea 3851), `ruta_canonica=null` | `SELECT template->'session_state'->>'context_actual' FROM bauth.idn_user_template LIMIT 1` retorna valor de `u.context_actual` | ⏳ |
| F0S.B8.4 | Agregar arrays de sesión y compliance | `active_sessions=[]`, `session_history=[]`, `context_switches=[]`, `emergency_overrides=[]`, `session_compliance={max_sessions_allowed:1,concurrent_sessions:0,within_limit:true,force_logout_on_end_shift:true}` | `SELECT template->'session_state'->'session_compliance'->>'force_logout_on_end_shift' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |

#### B9 — SECCIÓN 8: location_profile (líneas 88–93)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B9.1 | Renombrar clave principal | `'locationProfile'` → `'location_profile'` | `SELECT template->'location_profile' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B9.2 | Renombrar 4 claves internas | `homeCountry`→`home_country`, `homeTimezone`→`home_timezone`, `allowedCountries`→`allowed_countries`, `gpsTrackingConsent`→`gps_tracking_consent` | `SELECT template->'location_profile'->>'home_country' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B9.3 | Agregar subobjetos de ubicación y arrays | `home_location={country:BO,city:null,trust_tier:LOW}`, `work_location={country:BO,geo_fence_status:null}`, `assigned_branches=[]`, `blocked_countries=[]`, `current_location=null`, `location_history=[]`, `velocity_checks=[]`, `velocity_violations=[]` | `SELECT template->'location_profile'->'home_location'->>'trust_tier' FROM bauth.idn_user_template LIMIT 1` → `'LOW'` | ⏳ |
| F0S.B9.4 | Agregar `location_compliance` | `{geo_fence_compliant:true,country_allowed:true,trust_tier_sufficient:true,compliant:true}` | `SELECT template->'location_profile'->'location_compliance'->>'compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |

#### B10 — SECCIÓN 9: temporal_profile (líneas 96–100)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B10.1 | Renombrar clave principal | `'temporalProfile'` → `'temporal_profile'` | `SELECT template->'temporal_profile' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B10.2 | Eliminar 5 claves planas y reemplazar por subobjetos | Eliminar: `overtimeAllowed`, `afterHoursRequiresApproval`, `weekendAccessBlocked`, `breakPolicy`, `holidayCalendar` → reemplazar con `work_schedule`, `breaks`, `overtime`, `holidays` | `SELECT template->'temporal_profile'->'work_schedule' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B10.3 | Agregar `assigned_schedule_id` y `schedule_name` | Sub-SELECT de `bcalendar.cal_schedule WHERE is_default=true LIMIT 1` | `SELECT template->'temporal_profile'->>'assigned_schedule_id' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B10.4 | Agregar `timezone='America/La_Paz'` | Valor fijo IANA para Bolivia | `SELECT template->'temporal_profile'->>'timezone' FROM bauth.idn_user_template LIMIT 1` → `'America/La_Paz'` | ⏳ |
| F0S.B10.5 | Agregar arrays y campos restantes | `temporal_exceptions=[]`, `attendance_today=null`, `attendance_history=[]`, `fiscal_calendar={current_fiscal_year:<año actual>}` | `SELECT template->'temporal_profile'->'fiscal_calendar'->>'current_fiscal_year' FROM bauth.idn_user_template LIMIT 1` → año actual | ⏳ |

#### B11 — SECCIÓN 10: network_profile (líneas 102–106)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B11.1 | Renombrar clave principal | `'networkProfile'` → `'network_profile'` | `SELECT template->'network_profile' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B11.2 | Renombrar claves y mover `allowedServices` | `vpnRequired`→`vpn_required`, `mTLSRequired`→`mtls_required`, `allowedServices`→mover dentro de `ztna.allowed_services` | `SELECT template->'network_profile'->'ztna'->'allowed_services' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B11.3 | Agregar campos faltantes | `allowed_cidrs=[]` (sub-SELECT de `bauth.idn_tenant_network`), `device_trust_min_score=70`, `current_network=null`, `network_history=[]` | `SELECT template->'network_profile'->>'device_trust_min_score' FROM bauth.idn_user_template LIMIT 1` → `'70'` | ⏳ |
| F0S.B11.4 | Agregar subobjetos `vpn`, `ztna`, `certificate_pinning` | `vpn={configured:false,provider:WIREGUARD,required_for_remote:true}`, `ztna={default_action:DENY,microsegmentation_enabled:false}`, `certificate_pinning={enabled:true,pinned_hosts:[],last_pin_rotation:null}` | `SELECT template->'network_profile'->'ztna'->>'default_action' FROM bauth.idn_user_template LIMIT 1` → `'DENY'` | ⏳ |

#### B12 — SECCIÓN 11: audit_profile (líneas 108–113)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B12.1 | Renombrar clave principal | `'auditProfile'` → `'audit_profile'` | `SELECT template->'audit_profile' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B12.2 | Renombrar 5 claves internas | `auditLevel`→`audit_level`, `logRetentionDays`→`retention_days`, `immutableLogs`→`hash_chain_required`, `complianceFrameworks`→mover a `compliance_status`, `auditEvents`→mover a `event_summary` | `SELECT template->'audit_profile'->>'audit_level' FROM bauth.idn_user_template LIMIT 1` retorna valor | ⏳ |
| F0S.B12.3 | Agregar `review_schedule` | `{frequency:QUARTERLY,last_review_date:null,next_review_date:null,sla_days:14}` | `SELECT template->'audit_profile'->'review_schedule'->>'frequency' FROM bauth.idn_user_template LIMIT 1` → `'QUARTERLY'` | ⏳ |
| F0S.B12.4 | Agregar `event_summary` y `compliance_status` | `event_summary={total_events_90d:0,access_granted_90d:0,access_denied_90d:0,auth_failures_90d:0}`, `compliance_status={iso_27001:{applicable:true,compliant:true},gdpr:{applicable:true,pii_access:true,legal_basis:legitimate_interest}}` | `SELECT template->'audit_profile'->'compliance_status'->'iso_27001'->>'compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |
| F0S.B12.5 | Agregar `ghost_account_check` | `{last_checked_at:null,is_ghost:false,days_since_last_login:0,kc_active_and_hr_active:true,tryton_synced:u.tryton_user_id IS NOT NULL,risk_score:0}` | `SELECT template->'audit_profile'->'ghost_account_check'->>'is_ghost' FROM bauth.idn_user_template LIMIT 1` → `'false'` | ⏳ |

#### B13 — SECCIÓN 12: external_services (líneas 115–119)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B13.1 | Renombrar clave principal | `'externalServices'` → `'external_services'` | `SELECT template->'external_services' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B13.2 | Reemplazar `connectedApps` por `consented_apps` | Sub-SELECT de `bauth.privilege_application WHERE active=true` con estructura: `{client_id,client_name,client_type:oidc,scopes_granted:[openid,profile,email],consent_status:granted}` | `SELECT jsonb_array_length(template->'external_services'->'consented_apps') FROM bauth.idn_user_template LIMIT 1` retorna número ≥ 0 | ⏳ |
| F0S.B13.3 | Eliminar `federationProtocols` y agregar arrays/objetos faltantes | `consent_withdrawn=[]`, `active_external_sessions=[]`, `token_activity={total_tokens_issued_30d:0,tokens_refreshed_30d:0,tokens_revoked_30d:0}`, `consent_audit={total_consents_active:0,total_consents_withdrawn:0,gdpr_consent_compliant:true}` | `SELECT template->'external_services'->'consent_audit'->>'gdpr_consent_compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |

#### B14 — SECCIÓN 13: compliance_profile (líneas 121–126)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B14.1 | Renombrar clave principal | `'complianceProfile'` → `'compliance_profile'` | `SELECT template->'compliance_profile' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B14.2 | Agregar `segregation_of_duties` | `{active_conflicts:[],conflicts_overridden:[],last_sod_check_at:null,compliant:true}` | `SELECT template->'compliance_profile'->'segregation_of_duties'->>'compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |
| F0S.B14.3 | Agregar `conflict_of_interest` | `{declarations:[],family_relationships_in_company:[],outside_interests:[],compliant:true}` | `SELECT template->'compliance_profile'->'conflict_of_interest'->>'compliant' FROM bauth.idn_user_template LIMIT 1` → `'true'` | ⏳ |
| F0S.B14.4 | Agregar arrays y `risk_assessment` | `required_certifications=[]`, `policy_acknowledgments=[]`, `risk_assessment={inherent_risk_score:0,residual_risk_score:0,risk_trend:STABLE,last_assessment_at:null}` | `SELECT template->'compliance_profile'->'risk_assessment'->>'risk_trend' FROM bauth.idn_user_template LIMIT 1` → `'STABLE'` | ⏳ |
| F0S.B14.5 | Reestructurar claves GDPR existentes | `gdprConsent`→`gdpr_consent={data_processing:true,marketing:false,third_party:false}`, `dataSubjectRights`→`data_subject_rights=[access,rectification,erasure,portability,restriction,objection]`, `dataRetention`→`data_retention={authentication_data_days:365,audit_logs_days:2555}` | `SELECT jsonb_array_length(template->'compliance_profile'->'data_subject_rights') FROM bauth.idn_user_template LIMIT 1` → `6` | ⏳ |

#### B15 — SECCIÓN 14: lifecycle_automation (líneas 128–135)

| ID | Cambio | Detalle | Verificación | Estado |
|----|--------|---------|-------------|:------:|
| F0S.B15.1 | Renombrar clave principal | `'lifecycleAutomation'` → `'lifecycle_automation'` | `SELECT template->'lifecycle_automation' IS NOT NULL FROM bauth.idn_user_template LIMIT 1` → `true` | ⏳ |
| F0S.B15.2 | Reestructurar `provisioning` | De objeto plano → estructura completa: `{provisioning_source:MANUAL,provisioning_method:SCIM_2_0,provisioned_at:u.created_at,provisioning_status:COMPLETED,auto_provisioned_resources:[{resource:keycloak_user,...},{resource:tryton_res_user,...}]}` | `SELECT template->'lifecycle_automation'->'provisioning'->>'provisioning_method' FROM bauth.idn_user_template LIMIT 1` → `'SCIM_2_0'` | ⏳ |
| F0S.B15.3 | Agregar `deprovisioning` con 4 pasos | `{deprovisioning_method:AUTOMATIC,grace_period_days:30,steps:[{step:REVOKE_SESSIONS,order:1,delay:IMMEDIATE},{step:REVOKE_CREDENTIALS,order:2,delay:IMMEDIATE},{step:DISABLE_KC_ACCOUNT,order:3,delay:IMMEDIATE},{step:PURGE_PII,order:4,delay:30_DAYS}]}` | `SELECT jsonb_array_length(template->'lifecycle_automation'->'deprovisioning'->'steps') FROM bauth.idn_user_template LIMIT 1` → `4` | ⏳ |
| F0S.B15.4 | Reemplazar `syncStatus` por `sync_state` separado KC+Tryton | `sync_state={kc_sync_status:u.sync_status,kc_user_id:u.kc_user_id,kc_last_sync_at:null,tryton_sync_status:PENDING/SYNCED,tryton_user_id:u.tryton_user_id,tryton_last_sync_at:null,drift_detected:false}` | `SELECT template->'lifecycle_automation'->'sync_state'->>'kc_sync_status' FROM bauth.idn_user_template LIMIT 1` retorna valor de `sync_status` | ⏳ |
| F0S.B15.5 | Reestructurar `notifications` | `{on_role_change:true,on_password_change:true,on_new_device:true,on_suspicious_activity:true,channels:[email,push],preferred_channel:push}` | `SELECT template->'lifecycle_automation'->'notifications'->>'preferred_channel' FROM bauth.idn_user_template LIMIT 1` → `'push'` | ⏳ |

---

### GRUPO C — Reparación de seed_idn_role_template_data.sql

**Archivo objetivo:** `seeds/seed_idn_role_template_data.sql`
**SSOT:** `BAUTH-ROLTEMPLATE-SECCIONES.md` v6.0 (14 secciones canónicas)
**Nota:** `template_version = '6.0.0'` en línea 11 ya es correcto — no requiere cambio.

| ID | Ubicación exacta | Valor actual | Valor correcto | Acción | Verificación | Estado |
|----|-----------------|-------------|----------------|--------|-------------|:------:|
| F0S.C1 | Línea 118 | `'financial', (` | `'financial_limits', (` | Renombrar | `SELECT template->'financial_limits' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C2 | Línea 164 | `'temporal', (` | `'temporal_schedule', (` | Renombrar | `SELECT template->'temporal_schedule' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C3 | Línea 293 | `'context', (` | `'session_context', (` | Renombrar | `SELECT template->'session_context' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C4 | Línea 316 | `'credentials', (` | `'credential_policy', (` | Renombrar | `SELECT template->'credential_policy' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C5 | Línea 438 | Bloque `'security'` completo | Eliminar bloque; fusionar `sodValidation` en `conflict_management` | Eliminar + fusionar | `SELECT template->'security' IS NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C6 | Línea 462 | `'compliance', (` | `'conflict_management', (` + agregar contenido `sodValidation` del bloque eliminado | Renombrar + enriquecer | `SELECT template->'conflict_management' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |
| F0S.C7 | Línea 480 | `'sync', jsonb_build_object(` | `'sync_metadata', jsonb_build_object(` | Renombrar | `SELECT template->'sync_metadata' IS NOT NULL FROM bauth.idn_role_template LIMIT 1` → `true` | ⏳ |

**Verificación post-C completa:**
```sql
SELECT
  template->'financial_limits' IS NOT NULL AS d3_ok,
  template->'temporal_schedule' IS NOT NULL AS d4_ok,
  template->'session_context' IS NOT NULL AS d8_ok,
  template->'credential_policy' IS NOT NULL AS d9_ok,
  template->'security' IS NULL AS security_eliminado,
  template->'conflict_management' IS NOT NULL AS comp_ok,
  template->'sync_metadata' IS NOT NULL AS meta_ok
FROM bauth.idn_role_template LIMIT 1;
```
Resultado esperado: todas las columnas → `true`.

---

### GRUPO D — Verificación de frameworks referenciados

| ID | Tarea atómica | Comando exacto | Resultado esperado | Estado |
|----|--------------|----------------|--------------------|:------:|
| F0S.D1 | Verificar ausencia de `Authentication_Framework_v3.json` en seeds | `grep -rl "Authentication_Framework_v3" BauthAgent/db/migrations/seeds/` | Sin salida (0 archivos) | ⏳ |
| F0S.D2 | Verificar ausencia de `Policies_Authentication_Framework_v4.json` en seeds | `grep -rl "Policies_Authentication_Framework_v4" BauthAgent/db/migrations/seeds/` | Sin salida (0 archivos) | ⏳ |
| F0S.D3 | Verificar existencia de los 2 frameworks correctos | `ls plandeaccion/bauth/Authentication_Framework.json plandeaccion/bauth/Policies_Authentication_Framework.json` | Ambos archivos presentes, sin error | ⏳ |

**Resultado esperado FASE 0.S:** 83 tareas atómicas completadas. Seeds saneados, nomenclatura JSONB 100% alineada con canónicos v6.0, `run_all_seeds.sql` completo y correcto.

---

## FASE 1 — DDL: D00 + idn_atributo

**Bloqueante:** Requiere aprobación explícita del humano antes de escribir o aplicar.

| ID | Tarea atómica | Estado | Inicio | Cierre | Resultado |
|----|--------------|:------:|:------:|:------:|-----------|
| F1.01 | Escribir SQL: `ALTER TABLE idn_tenant ADD COLUMN is_internal boolean` | 🔒 | — | — | — |
| F1.02 | Escribir SQL: `ALTER TABLE privilege_domain DROP CONSTRAINT ck_domain_code` | 🔒 | — | — | — |
| F1.03 | Escribir SQL: insertar D00 en `privilege_domain` | 🔒 | — | — | — |
| F1.04 | Escribir SQL: insertar `org` (app_code=13) en `privilege_application` | 🔒 | — | — | — |
| F1.05 | Escribir SQL: insertar 5 grupos D00 en `privilege_group` | 🔒 | — | — | — |
| F1.06 | Escribir SQL: eliminar verbos semánticos 51-63 (reemplazados) | 🔒 | — | — | — |
| F1.07 | Escribir SQL: insertar 120 átomos CRUD D00 en `privilege_atom` (5809-5928) | 🔒 | — | — | — |
| F1.08 | Escribir SQL: CREATE TABLE `idn_atributo` con todos los campos del diseño | 🔒 | — | — | — |
| F1.09 | Escribir SQL: migrar `org_contacto` → `idn_atributo` | 🔒 | — | — | — |
| F1.10 | Escribir SQL: migrar `org_documento` → `idn_atributo` | 🔒 | — | — | — |
| F1.11 | Escribir SQL: migrar `org_direccion` → `idn_atributo` | 🔒 | — | — | — |
| F1.12 | Revisión humana del SQL completo F1.01-F1.11 | 🔒 | — | — | — |
| F1.13 | Aprobación humana explícita del DDL | 🔒 | — | — | — |
| F1.14 | Aplicar migración 003 en VPS (comando psql) | 🔒 | — | — | — |
| F1.15 | Verificar migración: `SELECT count(*) FROM idn_atributo` | 🔒 | — | — | — |
| F1.16 | DROP TABLE `org_contacto`, `org_documento`, `org_direccion` | 🔒 | — | — | — |

---

## FASE 2 — DDL: átomos D4-D12

**Bloqueante:** Requiere aprobación explícita del humano + FASE 1 completada.

| ID | Tarea atómica | Estado | Inicio | Cierre | Resultado |
|----|--------------|:------:|:------:|:------:|-----------|
| F2.01 | Escribir SQL: 28 átomos D4 (D4.001-D4.028) en `privilege_atom` | 🔒 | — | — | — |
| F2.02 | Escribir SQL: 20 átomos D5 (D5.001-D5.020) en `privilege_atom` | 🔒 | — | — | — |
| F2.03 | Escribir SQL: 16 átomos D6 (D6.001-D6.016) en `privilege_atom` | 🔒 | — | — | — |
| F2.04 | Escribir SQL: 24 átomos D7 (D7.001-D7.024) en `privilege_atom` | 🔒 | — | — | — |
| F2.05 | Escribir SQL: 24 átomos D8 (D8.001-D8.024) en `privilege_atom` | 🔒 | — | — | — |
| F2.06 | Escribir SQL: 20 átomos D9 (D9.001-D9.020) en `privilege_atom` | 🔒 | — | — | — |
| F2.07 | Escribir SQL: 12 átomos D10 (D10.001-D10.012) en `privilege_atom` | 🔒 | — | — | — |
| F2.08 | Escribir SQL: 16 átomos D11 (D11.001-D11.016) en `privilege_atom` | 🔒 | — | — | — |
| F2.09 | Escribir SQL: 28 átomos D12 (D12.001-D12.028) en `privilege_atom` | 🔒 | — | — | — |
| F2.10 | Actualizar `bitmask_bundle` para 364 posiciones nuevas | 🔒 | — | — | — |
| F2.11 | Revisión y aprobación humana | 🔒 | — | — | — |
| F2.12 | Aplicar en VPS + verificar conteo | 🔒 | — | — | — |

---

## FASE 3 — DDL: D13 blockchain

**Bloqueante:** Requiere aprobación explícita del humano.

| ID | Tarea atómica | Estado | Inicio | Cierre | Resultado |
|----|--------------|:------:|:------:|:------:|-----------|
| F3.01 | Escribir SQL: insertar D13 en `privilege_domain` | 🔒 | — | — | — |
| F3.02 | Escribir SQL: insertar 3 apps D13 (chain, did, legalsg) | 🔒 | — | — | — |
| F3.03 | Escribir SQL: insertar 36 átomos D13 (5929-5964) | 🔒 | — | — | — |
| F3.04 | Revisión y aprobación humana | 🔒 | — | — | — |
| F3.05 | Aplicar en VPS + verificar | 🔒 | — | — | — |

---

## FASE 4 — Seeds

| ID | Tarea atómica | Estado | Inicio | Cierre | Resultado |
|----|--------------|:------:|:------:|:------:|-----------|
| F4.01 | Seed: 120 átomos D00 con metadatos completos | ⏳ | — | — | — |
| F4.02 | Seed: 188 átomos D4-D12 con metadatos | ⏳ | — | — | — |
| F4.03 | Seed: 36 átomos D13 con metadatos | ⏳ | — | — | — |
| F4.04 | Seed: roles base (AUDITORIA_LECTURA, RR_HH, ADMIN_EMPRESA, SELF_SERVICE, COMPLIANCE_GDPR) | ⏳ | — | — | — |
| F4.05 | Seed: display_format codes iniciales en cfg_policy_library | ⏳ | — | — | — |
| F4.06 | Verificar seeds en VPS | ⏳ | — | — | — |

---

## FASE 5 — Código Rust

| ID | Tarea atómica | Módulo | Estado | Inicio | Cierre |
|----|--------------|--------|:------:|:------:|:------:|
| F5.01 | `domain/atributo_extensible.rs` — CRUD idn_atributo | domain/ | ⏳ | — | — |
| F5.02 | `domain/roltemplate_validator.rs` — 14 bloques RolTemplate v6.0 | domain/ | ⏳ | — | — |
| F5.03 | `domain/usertemplate_validator.rs` — 16 bloques UserTemplate v6.0 | domain/ | ⏳ | — | — |
| F5.04 | Adaptar `server/handlers/mod.rs` — rutas CRUD idn_atributo | server/ | ⏳ | — | — |
| F5.05 | Adaptar `sync/role_sync.rs` — sync átomos D4-D12 con KC | sync/ | ⏳ | — | — |
| F5.06 | Tests unitarios D00 CRUD (30 campos) | tests/ | ⏳ | — | — |
| F5.07 | Compilar MUSL local + scp VPS | — | ⏳ | — | — |

---

## FASE 6 — Validación VPS

| ID | Test atómico | Criterio de éxito | Estado |
|----|-------------|------------------|:------:|
| F6.01 | Compilación MUSL sin errores | `cargo build --release --target x86_64-unknown-linux-musl` OK | ⏳ |
| F6.02 | Migración 003 aplicada | `SELECT count(*) FROM bauth.privilege_atom WHERE domain_code=0` = 120 | ⏳ |
| F6.03 | idn_atributo funcional | INSERT + SELECT de email, teléfono, dirección OK | ⏳ |
| F6.04 | BitMask D00 funcional | Bit 5812 (bdomain_nit.READ) evaluable en runtime | ⏳ |
| F6.05 | UserTemplate 16 bloques | POST /bauth.user.create con body completo → 200 OK | ⏳ |
| F6.06 | RolTemplate 14 bloques | POST /bauth.rol.create con body completo → 200 OK | ⏳ |
| F6.07 | CRUD D00: CREATE actor | POST /bauth.actor.create → actor en idn_user_template | ⏳ |
| F6.08 | CRUD D00: READ actor con idn_atributo | GET /bauth.actor.get → incluye emails+phones+nationality | ⏳ |
| F6.09 | GDPR: right_to_forget | DELETE /bauth.actor.forget → limpia idn_atributo datos sensibles | ⏳ |
| F6.10 | Sync KC: actor creado en Keycloak | keycloak_id populated en idn_user_template | ⏳ |

---

## Estados posibles

| Estado | Significado |
|--------|------------|
| 🔒 BLOQUEADA | Requiere aprobación humana del DDL antes de ejecutar |
| ⏳ PENDIENTE | En cola, dependencias satisfechas próximamente |
| 🔄 EN EJECUCIÓN | Tarea activa en este momento |
| ✅ COMPLETADA | Resultado verificado en VPS |
| ❌ BLOQUEADA (técnico) | Bloqueada por bug/dependencia técnica — con descripción |

---

## Historial de estados

| Fecha | Evento |
|-------|--------|
| 2026-07-01 | FASE 0 completada — Diseño 100% verificado. 344 átomos diseñados en 3 documentos. Cobertura 82+74=156 campos validados. |
| 2026-07-01 | REPARACIONBAUTH creada. Plan de acción y registro de estado inicializados. |
| 2026-07-01 | Pendiente aprobación humana para iniciar FASE 1 (DDL idn_atributo + D00). |
| 2026-07-01 | FASE 0.S programada — Auditoría y reparación de seeds existentes. 81 seeds, 1 huérfano identificado (`seed_compliance_results.sql`). Problemas detectados: `064_idn_user_template_data.sql` (14 claves camelCase + versión '3.0' errónea), `seed_idn_role_template_data.sql` (7 nombres de bloque no canónicos). Frameworks incorrectos descartados (`_v3`, `_v4`). Sin bloqueo DDL — ejecutable ya. |

---

## Bloqueos activos

| ID | Bloqueo | Desde | Resolución |
|----|---------|:-----:|-----------|
| B-01 | FASE 1-3 requieren aprobación humana del DDL | 2026-07-01 | Humano debe revisar BAUTH-COBERTURA-100PCT.md y dar `OK DDL` explícito |

## Hallazgos registrados

| ID | Hallazgo | Archivo | Impacto | Estado |
|----|----------|---------|---------|:------:|
| H-01 | `seed_compliance_results.sql` no está en `run_all_seeds.sql` (huérfano) | `seeds/run_all_seeds.sql` | No se ejecuta en producción | ⏳ F0S.A2 |
| H-02 | 14 claves JSONB en camelCase en lugar de snake_case | `seeds/064_idn_user_template_data.sql` | Incompatible con BAUTH-USERTEMPLATE-SECCIONES.md v6.0 | ⏳ F0S.B3 |
| H-03 | `template_version = '3.0'` incorrecto | `seeds/064_idn_user_template_data.sql` | Incompatible con UserTemplate v6.0.0 | ⏳ F0S.B1 |
| H-04 | 7 nombres de bloque JSONB incorrectos en RolTemplate seed | `seeds/seed_idn_role_template_data.sql` | Incompatible con BAUTH-ROLTEMPLATE-SECCIONES.md v6.0 | ⏳ F0S.C1-C7 |
| H-05 | Cabecera dice "49 seeds" pero hay 82 entradas | `seeds/run_all_seeds.sql` | Confusión en operación | ⏳ F0S.A3 |
| H-06 | Frameworks `_v3` y `_v4` son versiones incorrectas | `plandeaccion/bauth/` | Usar `Authentication_Framework.json` y `Policies_Authentication_Framework.json` | ⏳ F0S.D1-D2 |
