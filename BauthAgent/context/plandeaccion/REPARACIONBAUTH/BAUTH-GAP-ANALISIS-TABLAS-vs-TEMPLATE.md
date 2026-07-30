# BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md — Cobertura de Datos

**Versión:** 1.0 · **Fecha:** 2026-06-24
**Propósito:** Mapear cada campo del Template v6.0 contra las tablas y seeds existentes.
**DDL analizada:** `DDL_skSBOS_db_test.sql` · **Seeds:** 23 archivos en `db/migrations/seeds/`

## LEYENDA

| Símbolo | Significado |
|:---:|---|
| ✅ | **Cubierto** — Tabla y columna existen, seed poblado con datos reales |
| 🟡 | **Parcial** — Tabla existe pero faltan columnas, o seed incompleto |
| 🔴 | **Falta** — No existe tabla ni seed para este dato |
| ⚠️ | **No aplica** — Se calcula en runtime o es solo-lectura |

---

## SECCIÓN 1 — `logical_access` (D1)

### 1.1 `availableMethods` — 14 métodos × 20 atributos

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| methodId, methodName, methodType | `bauth.ath_method` | 🟡 | Tabla `ath__method` existe pero con doble guion bajo `__`. Seed `seed_ath_method.sql` tiene 40 métodos. Faltan columnas: `loaMax`, `is_phishing_resistant`, `is_device_bound`, `can_be_primary`, `can_be_fallback`, `recovery_eligible`, `syncable`, `max_aal`, `description` |
| loaMin | `bauth.ath_method.loa_min` | 🟡 | Columna existe pero solo tiene `loa_min`, falta `loa_max` |
| tool | `bauth.ath_method.tool` | 🟡 | Existe como TEXT, debería documentar qué herramienta (keycloak/vault) |
| standard | `bauth.ath_method` | 🔴 | **Falta columna `standard TEXT`** — cada método debe citar su estándar (NIST, FIDO, RFC) |
| is_phishing_resistant | — | 🔴 | **Falta** — NIST 800-63B-4 exige este atributo |
| is_device_bound | — | 🔴 | **Falta** — necesario para diferenciar Passkey syncable vs device-bound |
| syncable / max_aal | — | 🔴 | **Falta** — NIST Rev.4: syncable solo AAL2, device-bound para AAL3 |
| description (método) | `bauth.ath_method` | 🟡 | Posiblemente se usa `metadata` JSONB pero no está documentado |
| min_length (password) | — | 🔴 | **Falta** — la política de password debe almacenarse |
| attestation / user_verification / resident_key | — | 🔴 | **Falta** — atributos FIDO2 WebAuthn |
| deprecated / deprecation_target (SMS) | — | 🔴 | **Falta** — necesario para marcar métodos deprecados |

**Resumen D1.1:** 🟡 14 métodos en seed, pero tabla `ath_method` necesita **8 columnas nuevas** para cubrir el catálogo completo.

### 1.2 `requiredMethods` — 8 flujos de autenticación

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| Flujos (standard_login, elevated_login, hardware_protected, financial_high_value, system_config, m2m, decoupled) | — | 🔴 | **Falta tabla `bauth.ath_auth_flow`** — Define qué métodos y orden por flujo |
| methodId, order, required por flujo | — | 🔴 | **Falta** — Relación N:M entre flujo y método |
| description del flujo | — | 🔴 | **Falta** |

**Resumen D1.2:** 🔴 **Nueva tabla requerida:** `bauth.ath_auth_flow` + `bauth.ath_auth_flow_method`

### 1.3 `alternativeMethods` — Resiliencia

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| replaces, with, requiresApproval, maxUses, reason | `bauth.ath_policy.policy_config` JSONB | 🟡 | El seed `seed_ath_policy.sql` tiene alternativas dentro de `policy_config`, pero no como estructura formal |
| notificationChannels | — | 🔴 | **Falta** |
| maxUsesWindow | — | 🔴 | **Falta** |

**Resumen D1.3:** 🟡 Datos parcialmente en `ath_policy.policy_config` JSONB. Necesita estandarización.

### 1.4 `levelOfAssurance` + `stepUpRules`

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| LoA base del rol | `bauth.idn_role_template.loa_required` | ✅ | Columna existe |
| stepUpRules: trigger, condition, requiredLoa, maxAgeSeconds, acrValue | — | 🔴 | **Falta tabla `bauth.ath_step_up_rule`** |
| ruleId, reauthRequired, description | — | 🔴 | **Falta** |
| requiresJustification, approvalRequired, approverRoles | — | 🔴 | **Falta** — para reglas tipo SOD_OVERRIDE |

**Resumen D1.4:** 🔴 **Nueva tabla requerida:** `bauth.ath_step_up_rule`

### 1.5 `zones` — Zonas de negocio con apps y permisos

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| zoneCode, zoneName, category, isCritical | `bauth.log_zone` | ✅ | Tabla completa con seed de 29 zonas |
| verbs por zona | `bauth.bos_permiso_logico` | 🟡 | Tabla existe pero con `rol_id`, `zona_id`, `verb_code` — falta scope |
| scope (GLOBAL/REGIONAL/BRANCH/PERSONAL) | `bauth.bos_permiso_logico` | 🔴 | **Falta columna `scope`** |
| restrictions: maxRecordLimit, dataClassification, piiAccess | — | 🔴 | **Falta** — restricciones a nivel de zona |
| maskingPolicy, maskingRules | — | 🔴 | **Falta** — enmascaramiento de PII |
| applications[] con modules, visibleMenus, visibleActions | — | 🔴 | **Falta tabla `bauth.zone_application_map`** |
| hiddenFields por modelo | — | 🔴 | **Falta tabla `bauth.zone_field_restriction`** |
| readonlyFields | — | 🔴 | **Falta** |
| buttonRules (conditionPyson, usersRequired, sodCannotAlso, stepUpLoa) | — | 🔴 | **Falta tabla `bauth.zone_button_rule`** |
| recordRules (domainPyson por modelo) | — | 🔴 | **Falta tabla `bauth.zone_record_rule`** |
| gdprSensitive, gdprLawfulBasis, gdprRetentionDays | — | 🔴 | **Falta** |
| requiresSinDosificacion, requiresCafc | `bauth.fin_transaction_type.controls` JSONB | 🟡 | Está en controls pero no ligado a zona |

**Resumen D1.5:** 🔴 **5 nuevas tablas requeridas:** `zone_application_map`, `zone_field_restriction`, `zone_button_rule`, `zone_record_rule`, `zone_data_policy`. Tabla `bos_permiso_logico` necesita columna `scope`.

### 1.6 `trytonPrivileges` — 5 capas

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| modelAccess (25 modelos × CRUD) | — | 🔴 | **Falta tabla `bauth.tryton_model_access`** — ir.model.access de Tryton |
| visibleActions (22 acciones) | — | 🔴 | **Falta tabla `bauth.tryton_action_visibility`** |
| visibleButtons | — | 🔴 | **Falta** |
| fieldOverrides (17 campos ocultos) | `bauth.zone_field_restriction` (pendiente) | 🔴 | Usaría la misma tabla de D1.5 |
| buttonRules (6 reglas con PYSON) | `bauth.zone_button_rule` (pendiente) | 🔴 | Usaría la misma tabla de D1.5 |
| recordRules (4 reglas) | `bauth.zone_record_rule` (pendiente) | 🔴 | Usaría la misma tabla de D1.5 |

**Resumen D1.6:** 🔴 **3 nuevas tablas:** `tryton_model_access`, `tryton_action_visibility`, `tryton_action_group`

### 1.7 `temporalControl` + `sessionManagement`

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| allowedDays con shifts | `bcalendar.cal_schedule` | ✅ | Tabla con `days_of_week`, `start_time`, `end_time`, `shifts JSONB` |
| timezone | `bauth.idn_role_template` | 🔴 | **Falta columna `timezone TEXT`** en role_template |
| exceptions: holidays, specialDates, emergencyOverride | `bcalendar.cal_holiday` + `bcalendar.cal_event` | 🟡 | Tablas existen pero no hay seed de eventos de emergencia |
| sessionManagement: maxSessionDuration, inactivityTimeout, forceLogout, etc. | `bauth.idn_role_template` + `bauth.idn_tier_policy` | 🟡 | `session_timeout` y `max_sessions` existen en tier_policy. Faltan: `inactivity_timeout`, `force_logout_at_end_shift`, `reauthentication_interval` |
| tokenBinding (bindToDevice, bindToIp, etc.) | — | 🔴 | **Falta** |
| sessionTerminationTriggers | — | 🔴 | **Falta** |

**Resumen D1.7:** 🟡 Tablas de calendario OK. `idn_role_template` necesita **4 columnas nuevas**. `sessionTerminationTriggers` requiere nueva tabla.

---

## SECCIÓN 2 — `physical_access` (D2)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| availableMethods (9 métodos físicos) | — | 🔴 | **Falta tabla `bauth.fis_access_method`** — métodos de acceso físico |
| requiredMethods × zona | — | 🔴 | **Falta tabla `bauth.fis_zone_method_requirement`** |
| zones[] con security_level, access_level, schedule, access_points, max_duration | `bauth.fis_access_zone` | 🟡 | Tabla existe pero solo tiene `name`, `description`, `schedule_id`. Faltan: `security_level`, `access_level`, `category`, `max_occupancy`, `max_duration_minutes` |
| access_points por zona | `bauth.fis_zone_member` → `bauth.fis_location` | 🟡 | Cubierto parcialmente vía zone_member → location (DOOR). Falta mapeo directo. |
| anti_passback (enabled, mode, reset_hours) | `bauth.fis_area_config` | 🟡 | Tabla tiene `requires_anti_tailgating` pero no tiene `anti_passback_mode`, `reset_hours` |
| biometric_enrollment_policy | — | 🔴 | **Falta tabla `bauth.fis_biometric_policy`** |
| emergency_override con triggers | — | 🔴 | **Falta tabla `bauth.fis_emergency_config`** |
| duressCode | — | 🔴 | **Falta** |
| twoPersonRule, mantrapRequired por zona | `bauth.fis_area_config` | ✅ | Columnas `requires_two_person`, `requires_mantrap`, `requires_escort` existen |

**Resumen D2:** 🔴 **4 nuevas tablas:** `fis_access_method`, `fis_zone_method_requirement`, `fis_biometric_policy`, `fis_emergency_config`. `fis_access_zone` necesita **6 columnas nuevas**.

---

## SECCIÓN 3 — `financial_limits` (D3)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| availableMethods financieros | `bauth.ath_method` | 🟡 | Reutiliza métodos de D9 — ok |
| transactionTypes[] con controls (20 tipos) | `bauth.fin_transaction_type` | ✅ | Tabla completa. Seed `seed_fin_transaction_type.sql` tiene 20 tipos con `controls JSONB` |
| standardLimit por tipo | `bauth.fin_transaction_type.controls` | 🟡 | Está en JSONB `controls`. Debe estandarizarse campo `standard_limit` |
| transactionLimits multi-período | `bauth.fin_limit` | 🟡 | Tabla existe con `limits_config JSONB`. Seed no creado aún |
| approvalChain 4 tiers | `bauth.fin_approval_chain` + `bauth.fin_approval_level` | ✅ | Ambas tablas existen. `fin_approval_level` tiene `amount_up_to`, `approvers_required`, `approver_roles` |
| sodRules (5 reglas) | `bauth.fin_role_permission` | 🟡 | Tabla existe pero no tiene estructura formal de reglas SoD. Falta `sod_rules JSONB` o tabla dedicada |
| transactionSchedule con emergency_override | `bcalendar.cal_schedule` | 🟡 | Cubierto parcialmente. Falta tabla de schedule financiero |
| geospatialControl financiero | — | 🔴 | **Falta** — restricciones geo para transacciones |
| sinCompliance | `bauth.fin_transaction_type.controls` | 🟡 | Está en JSONB controls pero sin estructura formal |

**Resumen D3:** 🟡 Mayoría cubierto por tablas `fin_*`. Faltan: `fin_transaction_schedule`, `fin_geospatial_control`, `bauth.fin_sod_rule`.

---

## SECCIÓN 4 — `temporal_schedule` (D4)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| allowedDays con shifts | `bcalendar.cal_schedule` | ✅ | Completo |
| timezone | `bcalendar.cal_calendar.timezone` | ✅ | Existe |
| overtimePolicy | — | 🔴 | **Falta tabla `bcalendar.cal_overtime_policy`** |
| exceptions: holidays, specialDates | `bcalendar.cal_holiday` | ✅ | Seed con 11 feriados Bolivia + LATAM |
| emergencyOverride | `bcalendar.cal_event` | 🟡 | Tabla existe pero sin seed de emergencia |
| sessionManagement temporal | `bauth.idn_role_template` | 🟡 | Comparte columnas con D1.7 — mismas gaps |
| breakManagement (lunch, short breaks, autoLogout) | — | 🔴 | **Falta tabla `bcalendar.cal_break_policy`** |
| attendanceTracking (clockIn/Out methods, late thresholds) | — | 🔴 | **Falta tabla `bauth.attendance_policy`** |

**Resumen D4:** 🟡 Calendario base OK. 🔴 **3 nuevas tablas:** `cal_overtime_policy`, `cal_break_policy`, `attendance_policy`.

---

## SECCIÓN 5 — `biometric` (D5)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| types[] con standard, template_storage, sensor_types | — | 🔴 | **Falta tabla `bauth.bio_method`** |
| liveness_required, liveness_method, far_threshold | — | 🔴 | **Falta** |
| enrollment_policy completo (Argon2id, FMR, liveness) | — | 🔴 | **Falta tabla `bauth.bio_enrollment_policy`** |
| alternative_non_biometric | — | 🔴 | **Falta** |
| gdpr_compliance | — | 🔴 | **Falta tabla `bauth.bio_gdpr_config`** |

**Resumen D5:** 🔴 **Dominio biométrico sin tablas propias.** 3 nuevas tablas requeridas.

---

## SECCIÓN 6 — `geospatial` (D6)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| countries{} | `bglobal.global_country` | ✅ | Seed con 196 países |
| location_trust_tiers | — | 🔴 | **Falta tabla `bauth.geo_trust_tier`** |
| geo_fences[] | `bauth.fis_location` (coordinates, geo_fence_radius_m) | 🟡 | Parcial — coordenadas existen pero sin vínculo a políticas de rol |
| geo_velocity_check | — | 🔴 | **Falta tabla `bauth.geo_velocity_policy`** |
| max_distance_km | — | 🔴 | **Falta** |

**Resumen D6:** 🟡 Países OK. 🔴 **2 nuevas tablas:** `geo_trust_tier`, `geo_velocity_policy`.

---

## SECCIÓN 7 — `network` (D7)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| allowed_cidrs, vpn_required, mtls_required | `bauth.idn_tenant_network` | 🟡 | Tabla existe pero solo `network_cidr`, `network_type`. Faltan `vpn_required`, `mtls_required`, `vpn_config` |
| device_trust scoring (6 señales con pesos) | — | 🔴 | **Falta tabla `bauth.net_device_trust_policy`** |
| continuous_verification | — | 🔴 | **Falta** |
| network_segmentation (vlans, zones) | — | 🔴 | **Falta** |
| session_binding (bindToDevice, requireDpop) | — | 🔴 | **Falta** |
| ztna_policy (default_action, allowed_services) | — | 🔴 | **Falta tabla `bauth.net_ztna_policy`** |

**Resumen D7:** 🔴 **Dominio de red casi sin tablas.** `idn_tenant_network` necesita expansión. 3 nuevas tablas.

---

## SECCIÓN 8 — `session_context` (D8)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| ctx_id_scope, ctx_id_compliance | — | 🔴 | **Falta tabla `bauth.ses_context_config`** |
| session_risk (risk_factors, thresholds, actions) | — | 🔴 | **Falta tabla `bauth.ses_ses_risk_policy`** |
| context_switching granular | — | 🔴 | **Falta** |
| caep_events[] | — | 🔴 | **Falta tabla `bauth.ses_caep_config`** |
| force_logout_on[] | — | 🔴 | **Falta** |

**Resumen D8:** 🔴 **Dominio de sesión sin tablas.** 3 nuevas tablas requeridas.

---

## SECCIÓN 9 — `credential_policy` (D9)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| methods con available/required/alternatives | `bauth.ath_method` + `bauth.ath_policy` | 🟡 | Métodos existen (seed 40). Políticas existen (seed 22). Falta estructura de flujos. |
| phishing_resistance (required, allowed_methods, syncable vs device-bound) | — | 🔴 | **Falta tabla `bauth.ath_phishing_policy`** |
| password_policy (NIST Rev.4: 8 reglas) | `bauth.ath_policy` | 🟡 | Seed tiene políticas de password pero como registros individuales, no como bloque de política |
| recovery_policy | `bauth.ath_policy` | 🟡 | Seed tiene RECOVERY_MFA y RECOVERY_RATE |
| lockout_policy (progresivo 3 niveles) | `bauth.ath_policy` | 🟡 | Seed tiene LOCKOUT_PROGRESSIVE y LOCKOUT_MITIGATION |
| credential_rotation | — | 🔴 | **Falta tabla `bauth.ath_rotation_policy`** |
| applied_policies[] (6 políticas con enforcement) | `bauth.ath_policy` | ✅ | Seed con 22 políticas |

**Resumen D9:** 🟡 El más cubierto. `ath_method` (40) + `ath_policy` (22) existentes. Faltan 2 tablas de políticas específicas.

---

## SECCIÓN 10 — `delegation` (D10)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| can_delegate, allowed_target_roles, max_duration_hours | — | 🔴 | **Falta tabla `bauth.dlg_delegation_policy`** |
| non_delegable_permissions[] | — | 🔴 | **Falta** |
| delegation_chain (allow_redelegation, max_chain_depth) | — | 🔴 | **Falta** |
| notification_channels | — | 🔴 | **Falta** |
| audit_requirements | — | 🔴 | Existe `dlg_delegation_log` mencionada en docs pero no en DDL |

**Resumen D10:** 🔴 **Dominio sin tablas en DDL.** 1 tabla requerida: `dlg_delegation_policy`.

---

## SECCIÓN 11 — `audit` (D11)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| level, retention_days, hash_chain_required | `bauth.idn_role_template.audit_level` | 🟡 | Solo tiene `audit_level` (basic/full). Falta `retention_days`, `hash_chain_required` |
| events_to_log[] | — | 🔴 | **Falta tabla `bauth.aud_event_catalog`** |
| review_frequency, sla_days, escalation | — | 🔴 | **Falta tabla `bauth.aud_review_policy`** |
| regulatory_frameworks mapeo (pci_dss, sox, gdpr, iso27001) | — | 🔴 | **Falta tabla `bauth.aud_regulatory_mapping`** |
| change_tracking (tracked_elements, retention_years, tamper_proof) | — | 🔴 | **Falta** |
| reviewers[] | — | 🔴 | **Falta** |
| Registro WORM de auditoría | `bauth.privilege_atom_audit` | ✅ | Tabla WORM particionada por mes existe |

**Resumen D11:** 🟡 Auditoría WORM existe. 🔴 **3 nuevas tablas** para políticas de auditoría.

---

## SECCIÓN 12 — `blockchain` (D12)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| merkle_anchoring_required, anchor_frequency | — | 🔴 | **Falta tabla `bauth.blk_anchor_policy`** |
| did_identity (did_method, did_document, verification_methods) | — | 🔴 | **Falta tabla `bauth.blk_did_registry`** |
| proof_types (MERKLE_PROOF, ZK_SNARK, ZK_STARK) | — | 🔴 | **Falta** |
| smart_contract (address, chain_id, abi_reference, events) | — | 🔴 | **Falta tabla `bauth.blk_smart_contract`** |
| besu_config (network, node_url, consensus) | — | 🔴 | **Falta tabla `bauth.blk_besu_node`** |

**Resumen D12:** 🔴 **Dominio sin tablas en DDL.** 4 nuevas tablas requeridas.

---

## SECCIÓN 13 — `sync_metadata` (Transversal)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| sync_status, last_sync_at | `bauth.idn_role_template` | ✅ | Columnas `sync_status`, `last_sync_at`, `sync_error` existen |
| sync_targets: keycloak (composite_role, auth_flow, user_attributes) | — | 🔴 | **Falta tabla `bauth.sync_kc_config`** |
| sync_targets: tryton (group_name, ir_model_access, ir_rules) | — | 🔴 | **Falta tabla `bauth.sync_tryton_config`** |
| drift_detection (check_interval, auto_reconcile, max_tolerance) | — | 🔴 | **Falta tabla `bauth.sync_drift_config`** |

**Resumen D13:** 🟡 Estado de sync existe. 🔴 **3 nuevas tablas** para configuración de sincronización.

---

## SECCIÓN 14 — `conflict_management` (Transversal)

| Dato requerido | Tabla existente | Estado | Acción |
|---|---|---|---|
| incompatible_roles[] | — | 🔴 | **Falta tabla `bauth.sod_incompatible_role`** |
| incompatible_functions[] | — | 🔴 | **Falta tabla `bauth.sod_incompatible_function`** |
| conflict_validation (check_frequency, validation_scope) | — | 🔴 | **Falta tabla `bauth.sod_validation_config`** |
| interest_conflicts: restricted_entities, declaration_requirements | — | 🔴 | **Falta tabla `bauth.conflict_interest_policy`** |

**Resumen D14:** 🔴 **Dominio sin tablas.** 4 nuevas tablas requeridas.

---

## RESUMEN EJECUTIVO

### Tablas que YA CUBREN (✅)

| # | Tabla | Sección | Datos que cubre |
|---|-------|---------|-----------------|
| 1 | `bauth.ath_method` | D1, D9 | 40 métodos de autenticación |
| 2 | `bauth.ath_policy` | D1, D9 | 22 políticas de autenticación |
| 3 | `bauth.idn_role_template` | D1, D4, D11, D13 | Template base, LoA, sync_status |
| 4 | `bauth.idn_tier_policy` | D1, D9 | 9 tiers con LoA, MFA, sesiones |
| 5 | `bauth.log_zone` | D1 | 29 zonas de negocio |
| 6 | `bauth.privilege_domain` | D1 | 12 dominios D1-D12 |
| 7 | `bauth.privilege_verb` | D1 | 50 verbos |
| 8 | `bauth.privilege_application` | D1 | 12 aplicaciones |
| 9 | `bauth.privilege_group` | D1 | 48 grupos funcionales |
| 10 | `bauth.privilege_atom` | D1 | 5,808 átomos |
| 11 | `bauth.privilege_atom_policy` | D1 | 3,216 políticas de átomo |
| 12 | `bauth.fis_location` | D2, D6 | Ubicaciones físicas con coordenadas |
| 13 | `bauth.fis_device` | D2 | Dispositivos OSDP/ONVIF |
| 14 | `bauth.fis_access_zone` | D2 | Zonas de acceso físico |
| 15 | `bauth.fis_area_config` | D2 | Config de seguridad por área |
| 16 | `bauth.fin_transaction_type` | D3 | 20 tipos de transacción |
| 17 | `bauth.fin_limit` | D3 | Límites financieros |
| 18 | `bauth.fin_approval_chain` + `fin_approval_level` | D3 | Cadena de aprobación |
| 19 | `bcalendar.cal_calendar` | D4 | Calendarios |
| 20 | `bcalendar.cal_schedule` | D4 | Horarios |
| 21 | `bcalendar.cal_holiday` | D4 | Feriados |
| 22 | `bcalendar.cal_event` | D4 | Eventos |
| 23 | `bglobal.global_country` | D6 | 196 países |
| 24 | `bglobal.geo_timezone` | D6 | 319 zonas horarias |
| 25 | `bauth.idn_tenant_network` | D7 | CIDRs (parcial) |
| 26 | `bauth.privilege_atom_audit` | D11 | Auditoría WORM |
| 27 | `bauth.menu_item` + `menu_context` | D1 | Menús |
| 28 | `bauth.idn_tenant` | Global | Tenant bootstrap |

### Tablas que NECESITAN NUEVAS COLUMNAS (🟡)

| # | Tabla | Columnas faltantes | Sección |
|---|-------|-------------------|---------|
| 1 | `bauth.ath_method` | `standard`, `is_phishing_resistant`, `is_device_bound`, `can_be_primary`, `can_be_fallback`, `recovery_eligible`, `syncable`, `max_aal`, `loa_max` | D1, D9 |
| 2 | `bauth.idn_role_template` | `timezone`, `inactivity_timeout`, `force_logout_at_end_shift`, `reauthentication_interval`, `retention_days` | D1, D4, D11 |
| 3 | `bauth.fis_access_zone` | `security_level`, `access_level`, `category`, `max_occupancy`, `max_duration_minutes`, `alarm_on` | D2 |
| 4 | `bauth.fis_area_config` | `anti_passback_mode`, `anti_passback_reset_hours`, `duress_code_enabled` | D2 |
| 5 | `bauth.fin_transaction_type` | `standard_limit_amount`, `standard_limit_currency`, `standard_limit_period`, `requires_step_up`, `step_up_loa` | D3 |
| 6 | `bauth.idn_tenant_network` | `vpn_required`, `mtls_required`, `vpn_config`, `device_trust_config` | D7 |
| 7 | `bauth.bos_permiso_logico` | `scope`, `max_record_limit`, `data_classification` | D1 |
| 8 | `bauth.log_zone` | `pii_access`, `gdpr_sensitive`, `gdpr_lawful_basis` | D1 |

### Tablas NUEVAS requeridas (🔴)

| # | Nueva tabla | Sección | Prioridad | Propósito |
|---|------------|---------|:---:|---|
| 1 | `bauth.ath_auth_flow` | D1 | **ALTA** | Flujos de autenticación (standard_login, elevated_login...) |
| 2 | `bauth.ath_auth_flow_method` | D1 | **ALTA** | Métodos × orden por flujo |
| 3 | `bauth.ath_step_up_rule` | D1 | **ALTA** | Reglas RFC 9470 step-up |
| 4 | `bauth.zone_application_map` | D1 | **ALTA** | Zonas → aplicaciones con modules, menús, acciones |
| 5 | `bauth.zone_field_restriction` | D1 | **ALTA** | Campos ocultos/solo-lectura por zona |
| 6 | `bauth.zone_button_rule` | D1 | **ALTA** | Reglas de botones con PYSON y SoD |
| 7 | `bauth.zone_record_rule` | D1 | **ALTA** | Reglas de registros (filtros SQL) |
| 8 | `bauth.zone_data_policy` | D1 | MEDIA | Políticas de datos, PII, masking, GDPR |
| 9 | `bauth.tryton_model_access` | D1 | MEDIA | ir.model.access de Tryton |
| 10 | `bauth.tryton_action_visibility` | D1 | MEDIA | Acciones visibles en Tryton |
| 11 | `bauth.fis_access_method` | D2 | MEDIA | Métodos de acceso físico (QR, NFC, biométrico, smartcard) |
| 12 | `bauth.fis_zone_method_requirement` | D2 | MEDIA | Métodos requeridos por zona física |
| 13 | `bauth.fis_biometric_policy` | D2 | MEDIA | Políticas de enrolamiento biométrico físico |
| 14 | `bauth.fis_emergency_config` | D2 | MEDIA | Override de emergencia para acceso físico |
| 15 | `bauth.fin_sod_rule` | D3 | **ALTA** | Reglas formales de SoD financiero |
| 16 | `bauth.fin_transaction_schedule` | D3 | MEDIA | Horarios de transacciones financieras |
| 17 | `bauth.fin_geospatial_control` | D3 | BAJA | Restricciones geo para transacciones |
| 18 | `bcalendar.cal_overtime_policy` | D4 | BAJA | Políticas de horas extra |
| 19 | `bcalendar.cal_break_policy` | D4 | BAJA | Políticas de descansos |
| 20 | `bauth.attendance_policy` | D4 | BAJA | Control de asistencia |
| 21 | `bauth.bio_method` | D5 | BAJA | Métodos biométricos con estándares ISO |
| 22 | `bauth.bio_enrollment_policy` | D5 | BAJA | Políticas de enrolamiento biométrico |
| 23 | `bauth.bio_gdpr_config` | D5 | BAJA | GDPR para biométricos |
| 24 | `bauth.geo_trust_tier` | D6 | BAJA | Tiers de confianza por ubicación |
| 25 | `bauth.geo_velocity_policy` | D6 | BAJA | Control de velocidad de viaje |
| 26 | `bauth.net_device_trust_policy` | D7 | MEDIA | Scoring de confianza de dispositivo |
| 27 | `bauth.net_ztna_policy` | D7 | MEDIA | Política ZTNA |
| 28 | `bauth.ses_context_config` | D8 | **ALTA** | Config de ctx_id SBOS-049 |
| 29 | `bauth.ses_ses_risk_policy` | D8 | **ALTA** | Políticas de riesgo de sesión |
| 30 | `bauth.ses_caep_config` | D8 | MEDIA | Eventos CAEP |
| 31 | `bauth.ath_phishing_policy` | D9 | **ALTA** | Política anti-phishing |
| 32 | `bauth.ath_rotation_policy` | D9 | BAJA | Rotación de credenciales |
| 33 | `bauth.dlg_delegation_policy` | D10 | MEDIA | Políticas de delegación |
| 34 | `bauth.aud_event_catalog` | D11 | MEDIA | Catálogo de eventos de auditoría |
| 35 | `bauth.aud_review_policy` | D11 | MEDIA | Políticas de revisión de acceso |
| 36 | `bauth.aud_regulatory_mapping` | D11 | MEDIA | Mapeo de marcos regulatorios |
| 37 | `bauth.blk_anchor_policy` | D12 | BAJA | Políticas de anclaje blockchain |
| 38 | `bauth.blk_did_registry` | D12 | BAJA | Registro de DIDs |
| 39 | `bauth.blk_smart_contract` | D12 | BAJA | Smart contracts |
| 40 | `bauth.blk_besu_node` | D12 | BAJA | Nodos Besu QBFT |
| 41 | `bauth.sync_kc_config` | D13 | MEDIA | Config de sincronización Keycloak |
| 42 | `bauth.sync_tryton_config` | D13 | MEDIA | Config de sincronización Tryton |
| 43 | `bauth.sync_drift_config` | D13 | MEDIA | Config de detección de drift |
| 44 | `bauth.sod_incompatible_role` | D14 | **ALTA** | Roles incompatibles (SoD estático) |
| 45 | `bauth.sod_incompatible_function` | D14 | **ALTA** | Funciones incompatibles (SoD dinámico) |
| 46 | `bauth.sod_validation_config` | D14 | MEDIA | Config de validación de conflictos |
| 47 | `bauth.conflict_interest_policy` | D14 | MEDIA | Políticas de conflicto de interés |

---

## ESTADÍSTICAS FINALES

| Concepto | Cantidad |
|----------|:---:|
| Tablas existentes que cubren datos | **28** |
| Tablas existentes que necesitan columnas nuevas | **8** |
| Tablas NUEVAS requeridas | **47** |
| — Prioridad ALTA (bloquean funcionalidad core) | **12** |
| — Prioridad MEDIA (completitud de dominio) | **21** |
| — Prioridad BAJA (futuro/especializado) | **14** |
| Seeds existentes poblados con datos reales | **23** |
| Seeds nuevos requeridos para tablas nuevas | **47** |

---

## ORDEN DE EJECUCIÓN RECOMENDADO

```
FASE A — ALTA (Core AAL2/AAL3):
  1. ALTER ath_method (8 columnas)
  2. CREATE ath_auth_flow + ath_auth_flow_method
  3. CREATE ath_step_up_rule
  4. CREATE zone_application_map + zone_field_restriction + zone_button_rule + zone_record_rule
  5. CREATE fin_sod_rule
  6. CREATE ses_context_config + ses_ses_risk_policy
  7. CREATE ath_phishing_policy
  8. CREATE sod_incompatible_role + sod_incompatible_function
  9. ALTER idn_role_template (5 columnas)

FASE B — MEDIA (Completitud):
  10-21: Tablas D2, D7, D8, D10, D11, D13

FASE C — BAJA (Futuro):
  22-35: Tablas D3, D4, D5, D6, D12
```

---

*Análisis generado 2026-06-24. 28 tablas evaluadas. 47 gaps identificados. 12 críticos.*
