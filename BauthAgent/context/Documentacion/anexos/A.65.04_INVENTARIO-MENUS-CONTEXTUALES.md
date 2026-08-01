# A.65.04 — Inventario de Menús Contextuales (MC-0001..MC-0319)

**Versión:** 3.0.0 · **Fecha:** 2026-08-01 · **Estado:** VERIFICADO — 319 menús contextuales con concepto + valores válidos

---

## Concepto y propósito

### ¿Qué es un menú contextual en SBOS?

En SBOS, un **menú contextual** (`menu_context`) es el catálogo de opciones válidas para un campo
específico de la base de datos. Cuando una columna sólo acepta un conjunto cerrado de valores
(por ejemplo `status` sólo puede ser `ACTIVE` o `INACTIVE`), ese conjunto se registra como un
menú contextual con su lista de ítems (`menu_item`).

El menú contextual **no es un menú de navegación de la UI** — es una *tabla de referencia viva*
que la interfaz, las APIs y las validaciones consultan para mostrar opciones, validar entrada y
traducir valores técnicos a texto legible por dominio.

### ¿Qué problema resuelve?

Sin menús contextuales, cada componente que necesita mostrar opciones tiene que conocer
internamente los valores válidos de cada campo. Eso produce:

- **Código duplicado**: la lista `['ACTIVE', 'INACTIVE', 'SUSPENDED']` aparece en el backend,
  el frontend, las validaciones y los tests — y divergen con el tiempo.
- **Hardcoding**: los valores se escriben directamente en el código en lugar de consultarse.
- **Imposibilidad de auditoría**: no hay registro central de "cuáles son los valores válidos
  para este campo en producción".

El menú contextual resuelve esto con **una fuente de verdad única** consultable por todas las
capas del sistema.

### ¿Cómo se usa?

1. **La UI** consulta `bglobal.menu_context + menu_item` por `code` y obtiene la lista de opciones
   con sus etiquetas en el idioma del usuario (`label jsonb`).
2. **El backend** valida que el valor enviado existe como `menu_item` hijo del contexto correcto.
3. **Los informes** muestran el nombre legible en lugar del código técnico.
4. **Este documento** permite localizar cualquier menú por su código **MC-XXXX** y rastrear qué
   tabla/columna y qué T-code del DDL le da origen.

### Origen de los valores

Los 319 menús provienen de dos fuentes distintas del DDL de SBOSDB:

| Fuente | Cantidad | Cómo se cambian |
|--------|----------|-----------------|
| `CREATE TYPE ... AS ENUM` (PARTE A) | 58 | `ALTER TYPE ... ADD/RENAME VALUE` — inmutable en orden |
| `CHECK (col = ANY(ARRAY[...]))` (PARTE B) | 261 | `ALTER TABLE ... DROP CONSTRAINT / ADD CONSTRAINT` |

---

## Convenciones de lectura

| Campo | Significado |
|-------|-------------|
| **MC-XXXX** | Código único de menú contextual (4 dígitos, secuencial). Estable — no cambia aunque cambie el `code`. |
| **code** | Valor del campo `menu_context.code` — identificador semántico legible. PARTE A: nombre descriptivo. PARTE B: `dominio.entidad.atributo` en español. |
| **T-ref** | Código de tabla según A.65.02. Permite ir directo al DDL que define la columna origen. |
| **Origen** | `schema.tabla.columna` cuya restricción de valores da vida a este menú. |
| **Tipo pg / Constraint** | El artefacto PostgreSQL concreto que restringe los valores. |
| **Concepto** | Propósito semántico del menú — el PORQUÉ de su existencia. Permite navegar rápidamente de DDL → MC → dominio de negocio. |

Los valores de cada menú viven en `bglobal.menu_item` como registros hijos (`depth=1`,
`parent_id = menu_context.context_id`, `is_leaf = true`).

---

## PARTE A — ENUMs Formales (MC-0001 a MC-0058)

> Tipos `CREATE TYPE ... AS ENUM` declarados en el DDL de SBOSDB.
> Fuente: `pg_catalog.pg_enum`. Los valores son inmutables sin `ALTER TYPE`.


### Versionado de Roles

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0001** | `ver_canal` | T-041 | `bauth.idn_roles_rol_hierarchical.change_channel`, `bauth.idn_roles_ver_b01_audit_log.change_channel` | `ver_channel_enum` | Canal por el que se aplica un cambio de versión a un rol | `API` · `CLI` · `BOOTSTRAP` · `RECONCILE` |
| **MC-0002** | `ver_compactacion` | T-154 | `bauth.idn_roles_ver_b01_retention_policy.compaction_policy` | `ver_compaction_enum` | Política de compactación del historial de versiones de roles | `KEEP_ALL` · `KEEP_ANCHORS` · `KEEP_LAST_N` |
| **MC-0003** | `ver_estado_propuesta` | T-153 | `bauth.idn_roles_ver_b03_approval_queue.status` | `ver_proposal_status_enum` | Estado de una propuesta de cambio de versión en cola de aprobación | `PENDING` · `APPROVED` · `REJECTED` · `EXPIRED` · `CANCELLED` |
| **MC-0004** | `ver_tipo_cambio` | T-152 | `bauth.idn_roles_ver_b01_audit_log.change_type` | `ver_semver_change_enum` | Tipo de cambio semántico de versión (SemVer: mayor, menor, parche) | `MAJOR` · `MINOR` · `PATCH` |
| **MC-0005** | `rol_vigencia` | T-041 | `bauth.idn_roles_rol_hierarchical.validity_type` | `role_validity_type` | Tipo de vigencia temporal de un rol IAM | `INDEFINITE` · `FIXED` · `PROJECT_BASED` · `TEMPORARY` · `EMERGENCY` |

### Tenant y Gobernanza

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0006** | `nivel_auditoria` | T-005 | `bauth.idn_tenant.audit_level` | `audit_level_enum` | Nivel de profundidad de auditoría de un tenant | `basic` · `full` |
| **MC-0007** | `nivel_aislamiento` | T-005 | `bauth.idn_tenant.isolation_level` | `isolation_level_enum` | Modelo de aislamiento de datos entre tenants | `ROW_LEVEL` · `SCHEMA_PER_TENANT` · `DB_PER_TENANT` |
| **MC-0008** | `plan_nivel` | T-005 | `bauth.idn_tenant.plan_tier` | `plan_tier_enum` | Nivel de plan de suscripción del tenant | `BASIC` · `PRO` · `ENTERPRISE` |
| **MC-0009** | `suscripcion_estado` | T-005 | `bauth.idn_tenant.subscription_status` | `subscription_status_enum` | Estado del ciclo de vida de la suscripción del tenant | `TRIAL` · `ACTIVE` · `PAST_DUE` · `CANCELLED` |
| **MC-0010** | `tenant_estado` | T-005 | `bauth.idn_tenant.status` | `tenant_status_enum` | Estado operacional del tenant en el sistema | `PENDING_VERIFICATION` · `ACTIVE` · `SUSPENDED` · `MAINTENANCE` · `SOFT_DELETED` · `TERMINATED` · `PURGED` |
| **MC-0011** | `tenant_tipo` | T-005 | `bauth.idn_tenant.tenant_type` | `tenant_type_enum` | Tipo de tenant según sensibilidad regulatoria | `STANDARD` · `REGULATED` · `HIGH_SENSITIVITY` |
| **MC-0012** | `tenant_estado_provisionamiento` | T-005 | `bauth.idn_tenant.provisioning_status` | `provisioning_status_enum` | Fase de aprovisionamiento de infraestructura del tenant | `PENDING` · `INFRA_PROVISIONING` · `SCHEMA_CREATED` · `IDP_CONFIGURED` · `COMPLETED` · `FAILED` |
| **MC-0013** | `dominio_estado` | T-010 | `bauth.idn_tenant_domain.deploy_status`, `bauth.idn_tenant_domain.health_status` | `domain_status_enum` | Estado de despliegue y salud del dominio web del tenant | `PENDING` · `VERIFIED` · `FAILED` · `DEPLOYING` · `DEPLOYED` · `HEALTHY` · `DEGRADED` · `UNHEALTHY` · `UNKNOWN` |
| **MC-0014** | `dominio_tipo` | T-010 | `bauth.idn_tenant_domain.domain_type` | `domain_type_enum` | Categoría funcional del dominio del tenant | `WEB` · `API` · `POS` · `ADMIN` · `PORTAL` · `STATIC` · `MAIL` |
| **MC-0015** | `red_tipo` | T-011 | `bauth.idn_tenant_network.network_type` | `network_type_enum` | Tipo de segmento de red asignado al tenant | `LAN` · `WAN` · `VPN` · `DMZ` · `GUEST` · `MANAGEMENT` |

### Identidad y Proofing

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0016** | `entidad_nivel` | T-156 | `bauth.idn_identity_entity.level`, `bauth.idn_identity_requirement.entity_type` | `entidad_nivel_enum` | Nivel jerárquico de una entidad de identidad en el árbol organizacional | `tenant` · `bdomain` · `bsubdomain` · `pos` · `actor` |
| **MC-0017** | `nivel_ial` | T-156 | `bauth.idn_identity_entity.ial_min`, `bauth.idn_identity_proofing.ial_achieved` | `ial_level_enum` | Nivel de aseguramiento de proofing de identidad (NIST SP 800-63A) | `IAL1` · `IAL2` · `IAL3` |
| **MC-0018** | `verificacion_estado` | T-008 | `bauth.idn_tenant_verification.status` | `verification_status_enum` | Estado de verificación de un tenant en proceso de onboarding | `PENDING` · `IN_PROGRESS` · `PASSED` · `FAILED` |
| **MC-0019** | `verificacion_paso` | T-008 | `bauth.idn_tenant_verification.step` | `verification_step_enum` | Etapa del flujo de verificación de un nuevo tenant | `IDENTITY_CHECK` · `LEGAL_CHECK` · `TECHNICAL_SETUP` · `SECURITY_REVIEW` · `FINAL_APPROVAL` |
| **MC-0020** | `idioma_alcance` | T-001 | `bglobal.global_language.scope` | `language_scope_enum` | Ámbito de aplicación de un idioma (individual, macro, especial) | `individual` · `macrolanguage` · `special` · `collection` |
| **MC-0021** | `idioma_tipo` | T-001 | `bglobal.global_language.language_type` | `language_type_enum` | Tipo de idioma según clasificación ISO 639-3 | `living` · `extinct` · `ancient` · `constructed` · `historic` |
| **MC-0022** | `idioma_direccion` | T-001 | `bglobal.global_language.direction` | `text_direction_enum` | Dirección de escritura del idioma | `ltr` · `rtl` · `ttb` |
| **MC-0023** | `traduccion_estado` | T-007 | `bauth.idn_tenant_languages.translation_status` | `translation_status_enum` | Grado de completitud de traducción del idioma de un tenant | `COMPLETE` · `PARTIAL` · `MACHINE_TRANSLATED` · `NOT_TRANSLATED` |

### Roles y Privilegios

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0024** | `rol_estado` | T-041 | `bauth.idn_roles_rol_hierarchical.status` | `rol_status_enum` | Estado del ciclo de vida de un rol en el catálogo | `ACTIVE` · `INACTIVE` · `DEPRECATED` · `ARCHIVED` · `SUSPENDED` · `IN_REVIEW` |
| **MC-0025** | `rol_tier` | T-041 | `bauth.idn_roles_rol_hierarchical.tier` | `rol_tier_enum` | Nivel jerárquico del rol en la escala de privilegios (7 tiers) | `SU` · `T0` · `T1` · `BIZ_N1` · `BIZ_N2` · `BIZ_N3` · `BIZ_N4` · `BIZ_N5` · `EXT_N0` · `M2M` · `VISITOR` |
| **MC-0026** | `rol_tipo_cuenta` | T-162 | `bauth.idn_roles_template.account_type` | `rol_account_type_enum` | Tipo de cuenta que puede portar un rol | `INDIVIDUAL` · `M2M` · `SYSTEM` · `GROUP` · `TEMPLATE` · `VIRTUAL` · `BOT` · `DEVICE` · `SERVICE` · `EMERGENCY` |
| **MC-0027** | `etiqueta_sensibilidad` | T-041 | `bauth.idn_roles_rol_hierarchical.sensitivity_label` | `sensitivity_label_enum` | Clasificación de sensibilidad del rol según impacto en seguridad | `PUBLIC` · `INTERNAL` · `CONFIDENTIAL` · `RESTRICTED` · `SECRET` |
| **MC-0028** | `nivel_riesgo` | T-041 | `bauth.idn_roles_rol_hierarchical.risk_classification` | `risk_level_enum` | Clasificación de riesgo asociado a la asignación del rol | `LOW` · `MEDIUM` · `HIGH` · `CRITICAL` |
| **MC-0029** | `grant_estado` | T-170 | `bauth.privilege_atom_grant.status` | `grant_status_enum` | Estado de una concesión de átomo de privilegio | `ACTIVE` · `INACTIVE` · `REVOKED` · `EXPIRED` |
| **MC-0030** | `grant_tipo` | T-170 | `bauth.privilege_atom_grant.grant_type` | `grant_type_enum` | Modalidad de concesión de un átomo de privilegio | `STANDARD` · `JIT` · `BREAKGLASS` |

### IGA y Certificación

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0031** | `campana_alcance` | T-177 | `bauth.aud_certification_campaign.scope` | `campaign_scope_enum` | Alcance de la campaña de certificación de accesos IGA | `TENANT` · `USER` · `ROLE` · `ATOM` |
| **MC-0032** | `campana_estado` | T-177 | `bauth.aud_certification_campaign.status` | `campaign_status_enum` | Estado operacional de una campaña de certificación | `ACTIVE` · `COMPLETED` · `CANCELLED` · `OVERDUE` |
| **MC-0033** | `campana_tipo` | T-177 | `bauth.aud_certification_campaign.campaign_type` | `campaign_type_enum` | Tipo de campaña de revisión de accesos (periódica o por evento) | `QUARTERLY` · `ANNUAL` · `OFFBOARDING` · `INCIDENT` · `SOD_REVIEW` |
| **MC-0034** | `revision_decision` | T-178 | `bauth.aud_certification_review.decision` | `review_decision_enum` | Decisión del revisor en una revisión de certificación de acceso | `CERTIFY` · `REVOKE` · `ESCALATE` · `DEFER` |

### PAM y Break-Glass

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0035** | `estado_breakglass` | T-185 | `bauth.pam_breakglass_activation.status` | `breakglass_status_enum` | Estado de una activación de acceso de emergencia break-glass | `PENDING_APPROVAL` · `ACTIVE` · `DEACTIVATED` · `REVIEWED` |
| **MC-0036** | `jit_estado` | T-182 | `bauth.pam_jit_request.status` | `jit_status_enum` | Estado de una solicitud de acceso Just-In-Time | `PENDING` · `APPROVED` · `ACTIVE` · `EXPIRED` · `REVOKED` · `REJECTED` |
| **MC-0037** | `pam_tipo_acceso` | T-560 | `bauth.pam_cuenta_privilegiada.access_type` | `pam_access_type_enum` | Tipo de protocolo de acceso a cuenta privilegiada | `SSH` · `RDP` · `API` · `CONSOLE` · `DB` · `CLI` · `VAULT` |
| **MC-0038** | `nhi_estado` | T-546 | `bauth.idn_nhi_identity.status` | `nhi_status_enum` | Estado de ciclo de vida de una identidad no humana (NHI) | `ACTIVE` · `SUSPENDED` · `DECOMMISSIONED` |
| **MC-0039** | `nhi_tipo` | T-546 | `bauth.idn_nhi_identity.nhi_type` | `nhi_type_enum` | Categoría funcional de la identidad no humana | `DAEMON` · `PIPELINE` · `BOT` · `SERVICE_ACCOUNT` · `AGENT_AI` · `DEVICE` |
| **MC-0040** | `nhi_decision_cert` | T-188 | `bauth.idn_roles_nhi_certification.decision` | `nhi_cert_decision_enum` | Decisión en una certificación de NHI | `CERTIFY` · `DECOMMISSION` · `REDUCE_SCOPE` |
| **MC-0041** | `nhi_tipo_evento` | T-187 | `bauth.idn_roles_nhi_lifecycle_event.event_type` | `nhi_event_type_enum` | Tipo de evento en el ciclo de vida de una NHI | `PROVISIONED` · `CERTIFIED` · `ROTATED` · `SUSPENDED` · `REACTIVATED` · `DECOMMISSIONED` · `OWNER_CHANGED` |

### Autenticación

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0042** | `caep_tipo_evento` | T-191 | `bauth.ses_caep_event_log.event_type` | `caep_event_type_enum` | Tipo de evento de señal de autenticación continua (CAEP) | `credential_change` · `token_claims_change` · `session_revoked` · `assurance_level_change` · `ip_change` · `risk_score_change` |
| **MC-0043** | `caep_estado_proceso` | T-191 | `bauth.ses_caep_event_log.proc_status` | `caep_proc_status_enum` | Estado de procesamiento de un evento CAEP recibido | `RECEIVED` · `PROCESSING` · `APPLIED` · `FAILED` · `IGNORED` |
| **MC-0044** | `credencial_tipo_propietario` | T-330 | `bauth.auth_credential.owner_type` | `credential_owner_type_enum` | Categoría del propietario de una credencial (humano o NHI) | `HUMAN` · `NHI` |
| **MC-0045** | `credencial_tipo_ref` | T-183 | `bauth.pam_credential_ref.credential_type` | `credential_ref_type_enum` | Tipo de credencial privilegiada en PAM | `PASSWORD` · `API_KEY` · `CERTIFICATE` · `SSH_KEY` · `SERVICE_TOKEN` · `OAUTH_TOKEN` |
| **MC-0046** | `propuesta_estado` | T-241 | `bauth.idn_financial_approval.status` | `proposal_status_enum` | Estado de una propuesta de aprobación financiera (quorum) | `DRAFT` · `PENDING_QUORUM` · `APPROVED` · `REJECTED` · `EXPIRED` |
| **MC-0047** | `riesgo_accion` | T-180 | `bauth.ses_risk_policy.action_on_trigger` | `risk_action_enum` | Acción a tomar cuando se dispara una política de riesgo | `STEP_UP` · `REVOKE` · `SUSPEND` · `NOTIFY` · `REQUIRE_MFA` |

### Financiero (D03)

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0048** | `param_global_alcance` | T-114 | `bglobal.global_config.scope` | `global_param_scope_enum` | Ámbito de aplicación de un parámetro de configuración global | `global` · `security` · `calendar` · `auth` · `policy` · `billing` |
| **MC-0049** | `param_global_tipo` | T-114 | `bglobal.global_config.value_type` | `global_param_type_enum` | Tipo de dato del valor de un parámetro de configuración global | `TEXT` · `INTEGER` · `BOOLEAN` · `JSON` · `DECIMAL` |

### Calendario

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0050** | `tipo_calendario` | T-014 | `bcalendar.cal_calendar.calendar_type` | `calendar_type_enum` | Tipo de calendario empresarial (laboral, fiscal, festivo, etc.) | `WORK` · `FISCAL` · `PROCESS` · `COMPLIANCE` · `HOLIDAY` · `MAINTENANCE` |
| **MC-0051** | `calendario_rol` | T-013 | `bauth.idn_tenant_calendar_assignment.role` | `calendar_role_enum` | Rol de un tenant en la asignación de un calendario | `OWNER` · `EDITOR` · `VIEWER` |
| **MC-0052** | `calendario_tipo_propietario` | T-013 | `bauth.idn_tenant_calendar_assignment.owner_type` | `calendar_owner_type_enum` | Tipo de entidad propietaria del calendario | `TENANT` · `COMPANY` · `BRANCH` · `USER` |
| **MC-0053** | `anio_fiscal_estado` | T-012 | `bcalendar.cal_fiscal_year.status` | `fiscal_year_status_enum` | Estado de un año fiscal en el sistema de calendario | `OPEN` · `CLOSED` · `CLOSED_WITH_ADJUSTMENTS` · `ARCHIVED` |
| **MC-0054** | `horario_estado` | T-019 | `bcalendar.cal_schedule.status` | `schedule_status_enum` | Estado de un bloque horario en el calendario | `OPEN` · `CLOSED` · `LUNCH` · `BREAK` · `OVERTIME` |
| **MC-0055** | `canal_alarma` | T-016 | `bcalendar.cal_alarm.channel`, `bcalendar.cal_notification_log.channel` | `alarm_channel_enum` | Canal de notificación para alarmas de calendario | `EMAIL` · `SMS` · `WHATSAPP` · `PUSH` · `CHAT` · `UI` |

### Menú y Sistema

| MC | code | T-ref | Origen (tabla.columna) | Tipo pg | Concepto | Valores válidos |
|-----|------|-------|------------------------|---------|----------|-----------------|
| **MC-0056** | `menu_tipo` | T-060 | `bglobal.menu_context.menu_type` | `menu_type_enum` | Tipo de menú contextual (jerárquico o de contexto de campo) | `HIERARCHICAL` · `CONTEXTUAL` |
| **MC-0057** | `ssf_metodo_entrega` | T-192 | `bauth.ses_ssf_stream.delivery_method` | `ssf_delivery_method_enum` | Método de entrega de eventos SSF (push o polling) | `PUSH` · `POLL` |
| **MC-0058** | `ssf_estado_entrega` | T-193 | `bauth.ses_ssf_delivery_log.delivery_status` | `ssf_delivery_status_enum` | Estado de entrega de un evento en el log SSF | `SUCCESS` · `FAILED` · `RETRYING` · `ABANDONED` |

---

## PARTE B — CHECKs Implícitos (MC-0059 a MC-0319)

> Conjuntos de valores definidos mediante `CHECK (col = ANY(ARRAY[...]))` en el DDL.
> Fuente: `pg_catalog.pg_constraint`. Modificables con `ALTER TABLE ... DROP CONSTRAINT / ADD CONSTRAINT`.


### Autenticación (auth.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0059** | `auth.intento.resultado` | T-334 | `bauth.auth_attempt_log.outcome` | `chk_aal_outcome` | Resultado de un intento de autenticación | `SUCCESS` · `FAILURE` · `LOCKED` · `STEP_UP_REQUIRED` · `EXPIRED` · `INVALID_USER` · `REVOKED_CREDENTIAL` |
| **MC-0060** | `auth.cumplimiento.nivel_cobertura` | T-386 | `bauth.auth_compliance_map.coverage_level` | `chk_acm_cov` | Nivel de cobertura de un control de cumplimiento de autenticación | `FULL` · `PARTIAL` · `NOT_COVERED` |
| **MC-0061** | `auth.credencial.nivel_aal` | T-330 | `bauth.auth_credential.loa_provided` | `chk_ac_loa` | Nivel de aseguramiento de autenticación (AAL) provisto por la credencial | `AAL1` · `AAL2` · `AAL3` |
| **MC-0062** | `auth.credencial.estado` | T-330 | `bauth.auth_credential.status` | `chk_ac_status` | Estado del ciclo de vida de una credencial | `PENDING_ACTIVATION` · `ACTIVE` · `SUSPENDED` · `REVOKED` · `EXPIRED` |
| **MC-0063** | `auth.fido2.formato_atestacion` | T-332 | `bauth.auth_credential_fido2.attestation_fmt` | `chk_af2_fmt` | Formato de attestation de un dispositivo FIDO2 | `packed` · `tpm` · `fido-u2f` · `none` · `apple` · `android-safetynet` · `android-key` |
| **MC-0064** | `auth.secreto.tipo` | T-331 | `bauth.auth_credential_secret.type` | `chk_acs_type` | Tipo de secreto criptográfico almacenado para una credencial | `ARGON2ID_HASH` · `TOTP_SEED_ENC` · `HOTP_SEED_ENC` · `RECOVERY_CODE_HASH` · `PUSH_PUBKEY_ED25519` |
| **MC-0065** | `auth.x509.origen` | T-333 | `bauth.auth_credential_x509.origin` | `chk_ax509_origin` | Origen de emisión de un certificado X.509 | `VAULT_INTERNAL` · `ADSIB_EXTERNA` · `ENTERPRISE_PKI` · `SELF_SIGNED` |
| **MC-0066** | `auth.cripto.estado` | T-338 | `bauth.auth_crypto_algorithm.status` | `chk_aca_status` | Estado de aprobación de un algoritmo criptográfico | `APPROVED` · `DEPRECATED` · `FORBIDDEN` |
| **MC-0067** | `auth.cripto.tipo` | T-338 | `bauth.auth_crypto_algorithm.type` | `chk_aca_type` | Categoría funcional de un algoritmo criptográfico | `KDF` · `SYMMETRIC` · `ASYMMETRIC_SIG` · `ASYMMETRIC_KEM` · `HASH` · `PQC` |
| **MC-0068** | `auth.dispositivo.categoria` | T-390 | `bauth.auth_device.category` | `chk_ad_cat` | Categoría de hardware del dispositivo de autenticación | `DESKTOP` · `MOBILE` · `TABLET` · `SERVER` · `IOT` · `SECURITY_KEY` · `SMART_CARD` · `OSDP_READER` · `NFC_READER` |
| **MC-0069** | `auth.dispositivo.version_osdp` | T-390 | `bauth.auth_device.osdp_version` | `chk_ad_osdp` | Versión del protocolo OSDP del dispositivo de acceso físico | `v1.0` · `v2.1` · `v2.2` |
| **MC-0070** | `auth.dispositivo.plataforma` | T-390 | `bauth.auth_device.platform` | `chk_ad_plat` | Plataforma de sistema operativo del dispositivo de autenticación | `WINDOWS` · `LINUX` · `MACOS` · `ANDROID` · `IOS` · `EMBEDDED` · `FIDO2_HW` · `OSDP_HW` · `UNKNOWN` |
| **MC-0071** | `auth.dispositivo.estado` | T-390 | `bauth.auth_device.status` | `chk_ad_status` | Estado de ciclo de vida del dispositivo de autenticación | `PENDING` · `ACTIVE` · `SUSPENDED` · `REVOKED` · `LOST` · `DECOMMISSIONED` |
| **MC-0072** | `auth.dispositivo.confianza` | T-390 | `bauth.auth_device.trust_level` | `chk_ad_trust` | Nivel de confianza asignado al dispositivo | `TRUSTED` · `CONDITIONALLY_TRUSTED` · `UNTRUSTED` · `QUARANTINE` |
| **MC-0073** | `auth.vinculo_disp.tipo_vinculo` | T-392 | `bauth.auth_device_credential_binding.binding_type` | `chk_adcb_type` | Tipo de vinculación entre dispositivo y credencial | `FIDO2_RESIDENT` · `FIDO2_CROSS_PLATFORM` · `X509_MTLS` · `SOFT_TOTP` · `PUSH_NOTIFICATION` · `OSDP_CARD` |
| **MC-0074** | `auth.postura_disp.cumplimiento` | T-391 | `bauth.auth_device_posture.compliance_status` | `chk_adp_comp` | Estado de cumplimiento de la postura del dispositivo | `COMPLIANT` · `NON_COMPLIANT` · `UNKNOWN` · `EXEMPTED` |
| **MC-0075** | `auth.postura_disp.mdm` | T-391 | `bauth.auth_device_posture.mdm_compliance` | `chk_adp_mdm` | Estado de cumplimiento MDM del dispositivo | `COMPLIANT` · `NON_COMPLIANT` · `UNKNOWN` |
| **MC-0076** | `auth.postura_disp.fuente_postura` | T-391 | `bauth.auth_device_posture.posture_source` | `chk_adp_src` | Fuente tecnológica que reporta la postura del dispositivo | `MDM` · `EDR` · `AGENT` · `SELF_REPORTED` · `MANUAL` |
| **MC-0077** | `auth.federacion.estado` | T-384 | `bauth.auth_federation_protocol.status` | `chk_afp_status` | Estado de soporte de un protocolo de federación | `SUPPORTED` · `DEPRECATED` · `PLANNED` |
| **MC-0078** | `auth.metodo.categoria` | T-335 | `bauth.auth_method.category` | `chk_am_cat` | Categoría del método de autenticación según tipo de factor (A-F) | `A` · `B` · `C` · `D` · `E` · `F` |
| **MC-0079** | `auth.metodo.estado` | T-335 | `bauth.auth_method.status` | `chk_am_status` | Estado de implementación de un método de autenticación | `IMPLEMENTED` · `PLANNED` · `DEPRECATED` · `REMOVED` |
| **MC-0080** | `auth.saga.estado` | T-385 | `bauth.auth_saga_catalog.status` | `chk_asc_status` | Estado de una saga de autenticación en el catálogo | `ACTIVE` · `DEPRECATED` · `PLANNED` |

### Federación (fed.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0081** | `fed.cliente.perfil_fapi` | T-365 | `bauth.fed_client.fapi_profile` | `chk_fc_fapi` | Perfil FAPI del cliente OAuth2 federado | `BASELINE` · `ADVANCED` · `FAPI2` |
| **MC-0082** | `fed.cliente.estado` | T-365 | `bauth.fed_client.status` | `chk_fc_status` | Estado del cliente OAuth2 en la federación | `ACTIVE` · `SUSPENDED` · `REVOKED` |
| **MC-0083** | `fed.cliente.tipo` | T-365 | `bauth.fed_client.type` | `chk_fc_type` | Tipo de confidencialidad del cliente OAuth2 | `CONFIDENTIAL` · `PUBLIC` · `M2M` |
| **MC-0084** | `fed.proveedor.nivel_fal` | T-366 | `bauth.fed_provider_ext.fal` | `chk_fpe_fal` | Nivel de aseguramiento de federación (FAL) del proveedor externo | `FAL1` · `FAL2` · `FAL3` |
| **MC-0085** | `fed.proveedor.protocolo` | T-366 | `bauth.fed_provider_ext.protocol` | `chk_fpe_proto` | Protocolo de federación soportado por el proveedor externo | `OIDC` · `SAML2` · `GOOGLE` · `GITHUB` · `LINKEDIN` · `MICROSOFT_ENTRA` |
| **MC-0086** | `fed.token.tipo` | T-367 | `bauth.fed_token_issued.type` | `chk_fti_type` | Tipo de token emitido en la federación | `ACCESS_TOKEN` · `REFRESH_TOKEN` · `ID_TOKEN` · `EXCHANGE_TOKEN` |

### Configuración (cfg.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0087** | `cfg.politica.factor_auth` | T-999 | `bauth.cfg_policy_library.auth_factor` | `cfg_policy_library_auth_factor_check` | Factor de autenticación que aplica la política | `knowledge` · `possession` · `inherence` · `context` · `multi` |
| **MC-0088** | `cfg.politica.aplicacion` | T-999 | `bauth.cfg_policy_library.enforcement` | `cfg_policy_library_enforcement_check` | Nivel de aplicación obligatoria de una política de seguridad | `mandatory` · `recommended` · `optional` |
| **MC-0089** | `cfg.politica.ciclo_vida` | T-999 | `bauth.cfg_policy_library.lifecycle` | `cfg_policy_library_lifecycle_check` | Estado del ciclo de vida de una política en la biblioteca | `active` · `deprecated` · `draft` · `proposed` |
| **MC-0090** | `cfg.politica.tipo_nodo` | T-999 | `bauth.cfg_policy_library.node_type` | `cfg_policy_library_node_type_check` | Tipo de nodo en el árbol jerárquico de políticas | `section` · `group` · `policy` · `config` |
| **MC-0091** | `cfg.politica.nivel_riesgo` | T-999 | `bauth.cfg_policy_library.risk_level` | `cfg_policy_library_risk_level_check` | Nivel de riesgo asociado a una política de seguridad | `critical` · `high` · `medium` · `low` |
| **MC-0092** | `cfg.politica.tipo_semantico` | T-999 | `bauth.cfg_policy_library.semantic_type` | `cfg_policy_library_semantic_type_check` | Tipo semántico de un nodo de política en la biblioteca | `policy` · `configuration` · `method` · `standard` · `guideline` · `group` |
| **MC-0093** | `cfg.nodo_politica.tamano_fuente` | T-161b | `bauth.idn_policy_node_type.font_size_token` | `chk_itn_font_size_token` | Tamaño de fuente del tipo de nodo de política en la UI | `xs` · `sm` · `base` · `md` |

### Acceso y Contexto (acceso.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0094** | `acceso.contrato.tipo_acceso` | T-516 | `bauth.idn_access_contract.access_type` | `chk_iac_access_type` | Tipo de acceso que otorga un contrato de acceso formal | `ROLE_ACCESS` · `ATOM_ACCESS` · `TEMPORAL_ACCESS` · `EMERGENCY_ACCESS` · `DELEGATED_ACCESS` |
| **MC-0095** | `acceso.contrato.estado` | T-516 | `bauth.idn_access_contract.status` | `chk_iac_status` | Estado de un contrato de acceso formal | `DRAFT` · `ACTIVE` · `SUSPENDED` · `EXPIRED` · `REVOKED` |

### Identidad D00 (identidad.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0096** | `identidad.did.estado` | T-529 | `bauth.idn_did_document.status` | `chk_idd_status` | Estado de un documento DID (Decentralized Identifier) | `ACTIVE` · `DEACTIVATED` · `INVALID` · `EXPIRED` |
| **MC-0097** | `identidad.ciclo_vida.tipo_evento` | T-545 | `bauth.idn_identidad_lifecycle_event.event_type` | `chk_ile_event_type` | Tipo de evento en el ciclo de vida laboral de un empleado | `HIRED` · `TRANSFERRED` · `PROMOTED` · `ON_LEAVE` · `RETURNED` · `TERMINATED` · `REACTIVATED` |
| **MC-0098** | `identidad.atributo.mutabilidad` | T-157 | `bauth.idn_identity_attribute.mutability` | `chk_iiattr_mutability` | Mutabilidad de un atributo de identidad (pendiente DDL) | ⚑ DDL pendiente — columna no existe en DDL actual |
| **MC-0099** | `identidad.atributo.unicidad` | T-157 | `bauth.idn_identity_attribute.uniqueness` | `chk_iiattr_uniqueness` | Restricción de unicidad de un atributo de identidad (pendiente DDL) | ⚑ DDL pendiente — columna no existe en DDL actual |
| **MC-0100** | `identidad.attr_historial.operacion` | T-158 | `bauth.idn_identity_attribute_history.operation` | `chk_iah_operation` | Tipo de operación registrada en el historial de atributos | `INSERT` · `UPDATE` · `SOFT_DELETE` |
| **MC-0101** | `identidad.consentimiento.via_otorgamiento` | T-166 | `bauth.idn_identity_consent.granted_via` | `chk_ic_granted_via` | Canal por el que se otorgó el consentimiento de tratamiento de datos | `WEB` · `API` · `APP` · `IN_PERSON` · `EMAIL` |
| **MC-0102** | `identidad.consentimiento.base_legal` | T-166 | `bauth.idn_identity_consent.legal_basis` | `chk_ic_legal_basis` | Base legal que sustenta el tratamiento de datos personales | `CONSENT` · `CONTRACT` · `LEGAL_OBLIGATION` · `VITAL_INTEREST` · `PUBLIC_TASK` · `LEGITIMATE_INTEREST` |
| **MC-0103** | `identidad.consentimiento.via_retiro` | T-166 | `bauth.idn_identity_consent.withdrawn_via` | `chk_ic_withdrawn_via` | Canal por el que se retiró el consentimiento | `WEB` · `API` · `APP` · `IN_PERSON` · `EMAIL` · `ADMIN` |
| **MC-0104** | `identidad.entidad.estado` | T-156 | `bauth.idn_identity_entity.status` | `idn_identidad_entidad_status_check` | Estado operacional de una entidad de identidad | `ACTIVE` · `SUSPENDED` · `ARCHIVED` |
| **MC-0105** | `identidad.proofing.nivel_eidas` | T-165 | `bauth.idn_identity_proofing.eidas_level` | `chk_iip_eidas` | Nivel eIDAS de proofing de identidad (pendiente DDL) | ⚑ DDL pendiente — constraint no encontrado en DDL |
| **MC-0106** | `identidad.proofing.estado` | T-165 | `bauth.idn_identity_proofing.status` | `chk_ip_status` | Estado del proceso de proofing de identidad | `PENDING` · `IN_PROGRESS` · `PASSED` · `FAILED` · `EXPIRED` |
| **MC-0107** | `identidad.proofing.tipo_proofing` | T-165 | `bauth.idn_identity_proofing.proofing_type` | `chk_ip_type` | Modalidad del proceso de verificación de identidad | `SELF_ASSERTED` · `REMOTE_UNATTENDED` · `REMOTE_ATTENDED` · `IN_PERSON` · `TRUSTED_REFEREE` |
| **MC-0108** | `identidad.vc.tipo_vc_eidas` | T-167 | `bauth.idn_identity_vc.eidas_vc_type` | `chk_ivc_eidas_type` | Tipo de credencial verificable según eIDAS (pendiente DDL) | ⚑ DDL pendiente — constraint no encontrado en DDL |
| **MC-0109** | `identidad.vc.formato_vc` | T-167 | `bauth.idn_identity_vc.vc_format` | `chk_ivc_format` | Formato técnico de una credencial verificable (VC) | `VC_DATA_MODEL_1_1` · `VC_DATA_MODEL_2_0` · `SD_JWT_VC` |
| **MC-0110** | `identidad.usuario.metodo_registro` | T-320 | `bauth.idn_user.registration_method` | `chk_iu_reg_method` | Método por el que fue registrado el usuario | `ADMIN` · `SELF_SERVICE` · `PROVISIONED` · `FEDERATED` |
| **MC-0111** | `identidad.usuario.estado` | T-320 | `bauth.idn_user.status` | `chk_iu_status` | Estado del ciclo de vida de un usuario en el sistema | `PENDING_ACTIVATION` · `ACTIVE` · `LOCKED` · `SUSPENDED` · `DEACTIVATED` · `ARCHIVED` |
| **MC-0112** | `identidad.recuperacion.estado` | T-322 | `bauth.idn_user_recovery.status` | `chk_iur_status` | Estado de un método de recuperación de cuenta | `ACTIVE` · `USED` · `REVOKED` |
| **MC-0113** | `identidad.recuperacion.tipo` | T-322 | `bauth.idn_user_recovery.type` | `chk_iur_type` | Tipo de mecanismo de recuperación de cuenta | `BACKUP_EMAIL` · `BACKUP_PHONE` · `TRUSTED_CONTACT` · `ADMIN_OVERRIDE` |

### SCIM (scim.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0114** | `scim.mapeo_attr.mutabilidad_scim` | T-555 | `bauth.idn_scim_attribute_map.scim_mutability` | `chk_isam_mutability` | Mutabilidad SCIM de un atributo mapeado | `readOnly` · `readWrite` · `immutable` · `writeOnly` |
| **MC-0115** | `scim.mapeo_attr.recurso_scim` | T-555 | `bauth.idn_scim_attribute_map.scim_resource` | `chk_isam_resource` | Tipo de recurso SCIM al que pertenece el atributo mapeado | `User` · `Group` · `EnterpriseUser` · `ServiceAccount` · `CustomResource` |
| **MC-0116** | `scim.mapeo_attr.retorno_scim` | T-555 | `bauth.idn_scim_attribute_map.scim_returned` | `chk_isam_returned` | Política de retorno del atributo en respuestas SCIM | `always` · `never` · `default` · `request` |
| **MC-0117** | `scim.mapeo_attr.tabla_local` | T-555 | `bauth.idn_scim_attribute_map.local_table` | `chk_isam_table` | Tabla local de SBOS_db donde vive el atributo mapeado a SCIM | `idn_identidad_atributo` · `idn_identidad_entidad` · `idn_identidad_proofing` · `idn_identidad_vc` |

### D02 — Acceso Físico

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0118** | `d02.credencial_fisica.tipo_credencial` | T-228 | `bauth.idn_physical_access_credential.credential_type` | `idn_physical_access_credential_credential_type_check` | Tipo de credencial física para control de acceso | `RFID` · `SMARTCARD` · `PIV` · `BIOMETRIC` · `PIN` · `NFC` · `QR` |
| **MC-0119** | `d02.emergencia.modo_puerta` | T-225 | `bauth.idn_physical_access_emergency.door_mode` | `idn_physical_access_emergency_door_mode_check` | Modo de operación de la puerta durante una emergencia | `NORMAL` · `FAIL_SAFE` · `FAIL_SECURE` · `MANUAL_OVERRIDE` |
| **MC-0120** | `d02.emergencia.tipo_emergencia` | T-225 | `bauth.idn_physical_access_emergency.emergency_type` | `idn_physical_access_emergency_emergency_type_check` | Tipo de emergencia que activa el protocolo de acceso físico | `FIRE` · `INTRUSION` · `MEDICAL` · `EVACUATION` · `POWER_FAILURE` · `OTHER` |
| **MC-0121** | `d02.evento_fisico.tipo_credencial` | T-223 | `bauth.idn_physical_access_event_log.credential_type` | `idn_physical_access_event_log_credential_type_check` | Tipo de credencial presentada en el evento de acceso físico | `RFID` · `SMARTCARD` · `BIOMETRIC` · `PIN` · `MULTIFACTOR` |
| **MC-0122** | `d02.evento_fisico.tipo_evento` | T-223 | `bauth.idn_physical_access_event_log.event_type` | `idn_physical_access_event_log_event_type_check` | Tipo de evento registrado en el log de acceso físico | `ENTRY` · `EXIT` · `DENIED` · `ALARM` · `FORCED` · `ANTIPASSBACK` |
| **MC-0123** | `d02.evento_fisico.resultado` | T-223 | `bauth.idn_physical_access_event_log.outcome` | `idn_physical_access_event_log_outcome_check` | Resultado del intento de acceso físico | `GRANTED` · `DENIED` · `ALARM` · `TIMEOUT` |
| **MC-0124** | `d02.ubicacion_fisica.tipo_ubicacion` | T-220 | `bauth.idn_physical_access_location.location_type` | `idn_physical_access_location_location_type_check` | Tipo de ubicación física controlada | `BUILDING` · `FLOOR` · `ROOM` · `DATACENTER` · `WAREHOUSE` · `PERIMETER` · `VEHICLE_ACCESS` |
| **MC-0125** | `d02.ubicacion_fisica.estado` | T-220 | `bauth.idn_physical_access_location.status` | `idn_physical_access_location_status_check` | Estado operacional de una ubicación física | `ACTIVE` · `INACTIVE` · `MAINTENANCE` |
| **MC-0126** | `d02.lector.direccion` | T-221 | `bauth.idn_physical_access_reader.direction` | `idn_physical_access_reader_direction_check` | Dirección de flujo controlada por el lector físico | `ENTRY` · `EXIT` · `BIDIRECTIONAL` |
| **MC-0127** | `d02.lector.protocolo` | T-221 | `bauth.idn_physical_access_reader.protocol` | `idn_physical_access_reader_protocol_check` | Protocolo de comunicación del lector físico | `WIEGAND` · `OSDP_V1` · `OSDP_V2` · `OSDP_V2_2` |
| **MC-0128** | `d02.lector.tipo_lector` | T-221 | `bauth.idn_physical_access_reader.reader_type` | `idn_physical_access_reader_reader_type_check` | Tipo de tecnología del lector de acceso físico | `RFID` · `SMARTCARD` · `BIOMETRIC` · `PIN` · `MULTIFACTOR` · `OSDP` |
| **MC-0129** | `d02.lector.estado` | T-221 | `bauth.idn_physical_access_reader.status` | `idn_physical_access_reader_status_check` | Estado operacional del lector físico | `ACTIVE` · `OFFLINE` · `MAINTENANCE` · `DISABLED` |
| **MC-0130** | `d02.visita.estado` | T-224 | `bauth.idn_physical_access_visit.status` | `idn_physical_access_visit_status_check` | Estado de una visita programada a instalaciones | `SCHEDULED` · `ACTIVE` · `COMPLETED` · `CANCELLED` · `NO_SHOW` |

### D03 — Financiero

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0131** | `d03.aprobacion.tipo_operacion` | T-241 | `bauth.idn_financial_approval.operation_type` | `idn_financial_approval_operation_type_check` | Tipo de operación financiera que requiere aprobación | `PAYMENT` · `TRANSFER` · `APPROVAL` · `ISSUANCE` · `ACCOUNTING` |
| **MC-0132** | `d03.voto.decision` | T-248 | `bauth.idn_financial_approval_vote.decision` | `idn_financial_approval_vote_decision_check` | Decisión de un votante en un proceso de aprobación por quorum | `APPROVE` · `REJECT` · `ABSTAIN` |
| **MC-0133** | `d03.fraude.tipo_alerta` | T-245 | `bauth.idn_financial_fraud_alert.alert_type` | `idn_financial_fraud_alert_alert_type_check` | Tipo de patrón de fraude detectado en operaciones financieras | `UNUSUAL_AMOUNT` · `TIME_PATTERN` · `ANOMALOUS_LOCATION` · `SOD_VIOLATION` · `MULTIPLE_REJECTIONS` · `VELOCITY_CHECK` |
| **MC-0134** | `d03.fraude.resultado` | T-245 | `bauth.idn_financial_fraud_alert.result` | `idn_financial_fraud_alert_result_check` | Resultado de la investigación de una alerta de fraude | `FRAUD_CONFIRMED` · `FALSE_POSITIVE` · `PENDING` · `ESCALATED` |
| **MC-0135** | `d03.factura.estado_sin` | T-534 | `bauth.idn_financial_invoice_auth.sin_status` | `idn_financial_invoice_auth_sin_status_check` | Estado de autorización de factura ante el SIN Bolivia | `PENDING` · `AUTHORIZED` · `REJECTED` · `CANCELLED` · `CONTINGENCY` |
| **MC-0136** | `d03.limite.tipo_operacion` | T-240 | `bauth.idn_financial_limit.operation_type` | `idn_financial_limit_operation_type_check` | Tipo de operación al que aplica un límite financiero | `PAYMENT` · `TRANSFER` · `APPROVAL` · `ISSUANCE` · `ACCOUNTING` · `GENERAL` |
| **MC-0137** | `d03.limite.alcance` | T-240 | `bauth.idn_financial_limit.scope` | `idn_financial_limit_scope_check` | Alcance de sujeto al que aplica un límite financiero | `ROLE` · `USER` · `ENTITY` · `CLIENT` |
| **MC-0138** | `d03.limite.estado` | T-240 | `bauth.idn_financial_limit.status` | `idn_financial_limit_status_check` | Estado operacional de un límite financiero configurado | `ACTIVE` · `DISABLED` · `DRAFT` |
| **MC-0139** | `d03.reconciliacion.tipo_reconciliacion` | T-246 | `bauth.idn_financial_reconciliation.reconciliation_type` | `idn_financial_reconciliation_reconciliation_type_check` | Período de una reconciliación financiera | `DAILY` · `MONTHLY` · `QUARTERLY` · `ANNUAL` |
| **MC-0140** | `d03.reconciliacion.estado` | T-246 | `bauth.idn_financial_reconciliation.status` | `idn_financial_reconciliation_status_check` | Estado de un proceso de reconciliación financiera | `PENDING` · `IN_PROGRESS` · `COMPLETED` · `WITH_DIFFERENCES` · `APPROVED` |
| **MC-0141** | `d03.reporte.tipo_reporte` | T-244 | `bauth.idn_financial_report.report_type` | `idn_financial_report_report_type_check` | Tipo de reporte de cumplimiento o auditoría financiera | `SOX_302` · `SOX_404` · `PCI_DSS` · `QUARTERLY` · `ANNUAL` · `INCIDENT` · `AUDIT` |
| **MC-0142** | `d03.reporte.estado` | T-244 | `bauth.idn_financial_report.status` | `idn_financial_report_status_check` | Estado editorial de un reporte de cumplimiento | `DRAFT` · `REVIEW` · `APPROVED` · `PUBLISHED` · `ARCHIVED` |
| **MC-0143** | `d03.sod.tipo_conflicto` | T-242 | `bauth.idn_financial_sod_rule.conflict_type` | `idn_financial_sod_rule_conflict_type_check` | Tipo de conflicto SoD en una regla de separación de funciones | `MUTUALLY_EXCLUSIVE` · `REQUIRES_APPROVAL` · `SEQUENTIAL_ONLY` |
| **MC-0144** | `d03.tpp.perfil_fapi` | T-247 | `bauth.idn_financial_tpp_consent.fapi_profile` | `idn_financial_tpp_consent_fapi_profile_check` | Perfil FAPI del proveedor de pago (TPP) con consentimiento | `FAPI_1_0` · `FAPI_2_0` |
| **MC-0145** | `d03.tpp.revocado_por` | T-247 | `bauth.idn_financial_tpp_consent.revoked_by` | `idn_financial_tpp_consent_revoked_by_check` | Sujeto que revocó el consentimiento de un TPP | `USER` · `ADMIN` · `TPP` · `REGULATOR` · `EXPIRED` |

### D04 — Temporal

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0146** | `d04.excepcion_temp.tipo_excepcion` | T-265 | `bauth.idn_temporal_exception.exception_type` | `idn_temporal_exception_exception_type_check` | Tipo de excepción a la ventana temporal de acceso | `EXTENSION` · `REDUCTION` · `BLOCK` · `ADDITIONAL_GUARD` |
| **MC-0147** | `d04.turno.tipo_rotacion` | T-263 | `bauth.idn_temporal_shift.rotation_type` | `idn_temporal_shift_rotation_type_check` | Tipo de rotación del turno de trabajo | `FIXED` · `ROTATING` · `FLEXIBLE` · `GUARD` |
| **MC-0148** | `d04.ventana_temporal.tipo_ventana` | T-260 | `bauth.idn_temporal_window.window_type` | `idn_temporal_window_window_type_check` | Tipo de ventana de tiempo que restringe el acceso | `TIME_OF_DAY` · `DAILY` · `WEEKLY` · `MONTHLY` · `CUSTOM` |

### D05 — Biométrico

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0149** | `d05.inscripcion.tipo_biometrico` | T-280 | `bauth.idn_biometric_enrollment.biometric_type` | `idn_biometric_enrollment_biometric_type_check` | Modalidad biométrica inscrita para autenticación | `FINGERPRINT` · `IRIS` · `FACE` · `VOICE` · `RETINA` · `PALM` · `VEIN` |
| **MC-0150** | `d05.inscripcion.estado` | T-280 | `bauth.idn_biometric_enrollment.status` | `idn_biometric_enrollment_status_check` | Estado de una inscripción biométrica | `ACTIVE` · `SUSPENDED` · `REVOKED` · `EXPIRED` |
| **MC-0151** | `d05.identificacion.resultado` | T-283 | `bauth.idn_biometric_identification_log.result` | `idn_biometric_identification_log_result_check` | Resultado de un proceso de identificación biométrica 1:N | `IDENTIFIED` · `NOT_IDENTIFIED` · `MULTIPLE_MATCH` · `ERROR` |
| **MC-0152** | `d05.pad.accion_fallo` | T-282 | `bauth.idn_biometric_pad_policy.fail_action` | `idn_biometric_pad_policy_fail_action_check` | Acción ante detección de ataque de presentación (PAD) | `DENY` · `STEP_UP` · `LOG_AND_ALLOW` · `QUARANTINE` |
| **MC-0153** | `d05.pad.nivel_pad` | T-282 | `bauth.idn_biometric_pad_policy.pad_level` | `idn_biometric_pad_policy_pad_level_check` | Nivel de exigencia de la política anti-spoofing biométrico | `LEVEL_1` · `LEVEL_2` · `LEVEL_3` |
| **MC-0154** | `d05.pad.estado` | T-282 | `bauth.idn_biometric_pad_policy.status` | `idn_biometric_pad_policy_status_check` | Estado de una política de detección de ataque de presentación | `ACTIVE` · `DISABLED` |
| **MC-0155** | `d05.revocacion_bio.motivo_revocacion` | T-285 | `bauth.idn_biometric_revocation.revocation_reason` | `idn_biometric_revocation_revocation_reason_check` | Motivo de revocación de una inscripción biométrica | `COMPROMISE` · `USER_REQUEST` · `ADMIN` · `EXPIRATION` · `QUALITY_DEGRADED` · `INCIDENT` |
| **MC-0156** | `d05.verificacion_bio.resultado` | T-281 | `bauth.idn_biometric_verification_log.outcome` | `idn_biometric_verification_log_outcome_check` | Resultado de una verificación biométrica 1:1 | `MATCH` · `NO_MATCH` · `LIVENESS_FAIL` · `QUALITY_FAIL` · `ERROR` · `TIMEOUT` |

### D06 — Geoespacial

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0157** | `d06.residencia.aplica_a` | T-304 | `bauth.idn_geospatial_data_residency.apply_to` | `idn_geospatial_data_residency_apply_to_check` | Alcance de aplicación de una regla de residencia de datos | `ALL` · `DATA_RESIDENCY` · `AUTH_ONLY` · `STORAGE` |
| **MC-0158** | `d06.residencia.accion_violacion` | T-304 | `bauth.idn_geospatial_data_residency.violation_action` | `idn_geospatial_data_residency_violation_action_check` | Acción ante violación de residencia de datos | `DENY` · `LOG` · `NOTIFY` · `QUARANTINE` |
| **MC-0159** | `d06.geocerca.accion_dentro` | T-300 | `bauth.idn_geospatial_geofence.action_inside` | `idn_geospatial_geofence_action_inside_check` | Acción cuando el acceso ocurre dentro de la geocerca | `ALLOW` · `STEP_UP` · `LOG` · `NOTIFY` |
| **MC-0160** | `d06.geocerca.accion_fuera` | T-300 | `bauth.idn_geospatial_geofence.action_outside` | `idn_geospatial_geofence_action_outside_check` | Acción cuando el acceso ocurre fuera de la geocerca | `DENY` · `STEP_UP` · `LOG` · `NOTIFY` |
| **MC-0161** | `d06.geocerca.tipo_geocerca` | T-300 | `bauth.idn_geospatial_geofence.fence_type` | `idn_geospatial_geofence_fence_type_check` | Tipo geométrico o administrativo de la geocerca | `CIRCLE` · `POLYGON` · `COUNTRY` · `REGION` · `CITY` |
| **MC-0162** | `d06.ubicacion.fuente_ubicacion` | T-301 | `bauth.idn_geospatial_location_log.location_source` | `idn_geospatial_location_log_location_source_check` | Fuente tecnológica que detectó la ubicación del usuario | `GPS` · `WIFI` · `IP_GEOIP` · `CELL` · `MANUAL` · `BEACON` |

### D07 — Red / ZTA

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0163** | `d07.conexion.version_tls` | T-195 | `bauth.idn_network_connection_policy.min_tls_version` | `idn_network_connection_policy_min_tls_version_check` | Versión mínima de TLS requerida por política de red | `TLS_1_2` · `TLS_1_3` |
| **MC-0164** | `d07.propagacion.formato_propagacion` | T-201 | `bauth.idn_network_context_propagation.propagation_format` | `idn_network_context_propagation_propagation_format_check` | Formato de propagación del contexto de identidad entre servicios | `W3C_TRACEPARENT` · `W3C_BAGGAGE` · `SBOS_CTX_HEADER` · `OTEL_BAGGAGE` |
| **MC-0165** | `d07.dlp.accion_deteccion` | T-200 | `bauth.idn_network_dlp_policy.action_on_match` | `idn_network_dlp_policy_action_on_match_check` | Acción ante detección de fuga de datos (DLP) | `LOG` · `BLOCK` · `REDACT` · `QUARANTINE` |
| **MC-0166** | `d07.dpop.algoritmo` | T-196 | `bauth.idn_network_dpop_binding.alg` | `idn_network_dpop_binding_alg_check` | Algoritmo criptográfico de una prueba de posesión DPoP | `ES256` · `ES384` · `RS256` · `PS256` · `EdDSA` |
| **MC-0167** | `d07.postura_red.accion_fallo` | T-198 | `bauth.idn_network_posture_policy.action_on_fail` | `idn_network_posture_policy_action_on_fail_check` | Acción ante fallo de verificación de postura de red | `DENY` · `STEP_UP` · `NOTIFY` · `CHALLENGE` |
| **MC-0168** | `d07.tasa_limite.accion_exceso` | T-197 | `bauth.idn_network_rate_policy.action_on_exceed` | `idn_network_rate_policy_action_on_exceed_check` | Acción ante exceso de tasa de peticiones | `THROTTLE` · `BLOCK` · `NOTIFY` |
| **MC-0169** | `d07.tasa_limite.alcance` | T-197 | `bauth.idn_network_rate_policy.scope` | `idn_network_rate_policy_scope_check` | Ámbito de aplicación de una política de rate-limiting | `GLOBAL` · `TENANT` · `CLIENT` · `USER` · `IP` |
| **MC-0170** | `d07.segmento.tipo_segmento` | T-199 | `bauth.idn_network_segment.segment_type` | `idn_network_segment_segment_type_check` | Tipo de segmento de red en la arquitectura ZTA | `DMZ` · `INTERNAL` · `TRUSTED` · `ISOLATED` · `QUARANTINE` |
| **MC-0171** | `d07.segmento.confianza` | T-199 | `bauth.idn_network_segment.trust_level` | `idn_network_segment_trust_level_check` | Nivel de confianza de un segmento de red | `TRUSTED` · `CONDITIONALLY_TRUSTED` · `UNTRUSTED` |

### D09 — Credenciales

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0172** | `d09.revocacion_cred.motivo` | T-525 | `bauth.idn_credencial_revocacion.motivo` | `chk_idcr_motivo` | Motivo de revocación de una credencial | `COMPROMISED` · `LOST_DEVICE` · `USER_REQUEST` · `ADMIN_REVOKE` · `EXPIRED` · `ROTATION` |
| **MC-0173** | `d09.token.motivo_revocacion` | T-363 | `bauth.idn_credential_token_issued.revocation_reason` | `idn_credential_token_issued_revocation_reason_check` | Motivo de revocación de un token emitido | `USER_LOGOUT` · `ADMIN_REVOKE` · `CREDENTIAL_CHANGE` · `SESSION_EXPIRED` · `SUSPICIOUS_ACTIVITY` |
| **MC-0174** | `d09.token.tipo_token` | T-363 | `bauth.idn_credential_token_issued.token_type` | `idn_credential_token_issued_token_type_check` | Tipo de token de credencial emitido | `ACCESS` · `REFRESH` · `ID` · `EXCHANGE` · `DEVICE` |

### D10 — Delegación

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0175** | `d10.delegacion.tipo_delegacion` | T-415 | `bauth.idn_delegation_grant.delegation_type` | `idn_delegation_grant_delegation_type_check` | Modalidad de delegación de autoridad entre identidades | `IMPERSONATION` · `AGENT` · `PROXY` · `TOKEN_EXCHANGE` |
| **MC-0176** | `d10.rar.estado` | T-420 | `bauth.idn_delegation_rar_request.status` | `idn_delegation_rar_request_status_check` | Estado de una solicitud de autorización enriquecida (RAR) | `PENDING` · `APPROVED` · `REJECTED` · `EXPIRED` |
| **MC-0177** | `d10.restriccion.tipo_restriccion` | T-417 | `bauth.idn_delegation_restriction.restriction_type` | `idn_delegation_restriction_restriction_type_check` | Tipo de restricción aplicada a una delegación | `SCOPE_LIMIT` · `IP_WHITELIST` · `HOURS_ONLY` · `RESOURCE_LIMIT` · `APPROVAL_REQUIRED` |
| **MC-0178** | `d10.uso_delegacion.resultado` | T-419 | `bauth.idn_delegation_usage_log.outcome` | `idn_delegation_usage_log_outcome_check` | Resultado de un uso de delegación registrado | `PERMIT` · `DENY` · `ERROR` |

### D11 — Auditoría

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0179** | `d11.auditoria.codigo_dominio` | T-424 | `bauth.idn_audit_event_log.domain_code` | `idn_audit_event_log_domain_code_check` | Dominio de control al que pertenece el evento auditado | `D00` · `D01` · `D02` · `D03` · `D04` · `D05` · `D06` · `D07` · `D08` · `D09` · `D10` · `D11` · `D12` · `D13` · `D14` · `D15` · `D98` · `D99` |
| **MC-0180** | `d11.auditoria.resultado` | T-424 | `bauth.idn_audit_event_log.outcome` | `idn_audit_event_log_outcome_check` | Resultado de la decisión de autorización auditada | `PERMIT` · `DENY` · `ERROR` · `PARTIAL` |
| **MC-0181** | `d11.auditoria.tipo_sujeto` | T-424 | `bauth.idn_audit_event_log.subject_type` | `idn_audit_event_log_subject_type_check` | Tipo de sujeto que ejecutó la acción auditada | `USER` · `ENTITY` · `NHI` · `SYSTEM` |
| **MC-0182** | `d11.retencion.accion_expiracion` | T-421 | `bauth.idn_audit_retention_policy.expiration_action` | `idn_audit_retention_policy_expiration_action_check` | Acción al vencer el período de retención del log de auditoría | `DELETE` · `ARCHIVE` · `ANONYMIZE` · `KEEP` |
| **MC-0183** | `d11.siem.formato_log` | T-423 | `bauth.idn_audit_siem_target.log_format` | `idn_audit_siem_target_log_format_check` | Formato de log para la integración con SIEM externo | `CEF` · `LEEF` · `JSON` · `SYSLOG_RFC5424` · `WAZUH` |
| **MC-0184** | `d11.siem.tipo_protocolo` | T-423 | `bauth.idn_audit_siem_target.protocol_type` | `idn_audit_siem_target_protocol_type_check` | Protocolo de transporte para el envío de eventos al SIEM | `SYSLOG_UDP` · `SYSLOG_TCP` · `SYSLOG_TLS` · `HTTP_WEBHOOK` · `KAFKA` · `ELASTIC` |

### D12 — Blockchain

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0185** | `d12.ancla.tipo_evento_fuente` | T-425 | `bauth.idn_blockchain_anchor_ext.source_event_type` | `idn_blockchain_anchor_ext_source_event_type_check` | Tipo de evento que genera un anclaje de evidencia en blockchain | `PRIVILEGE_GRANT` · `AUDIT_BATCH` · `DIGITAL_SIGNATURE` · `VC_ISSUED` · `SOD_VIOLATION` |
| **MC-0186** | `d12.nodo.estado` | T-429 | `bauth.idn_blockchain_node.status` | `idn_blockchain_node_status_check` | Estado de un nodo en la red blockchain privada | `ACTIVE` · `SYNCING` · `OFFLINE` · `DECOMMISSIONED` |
| **MC-0187** | `d12.transaccion.estado` | T-426 | `bauth.idn_blockchain_transaction.status` | `idn_blockchain_transaction_status_check` | Estado de una transacción blockchain | `PENDING` · `CONFIRMED` · `FAILED` · `REVERTED` |
| **MC-0188** | `d12.transaccion.tipo_tx` | T-426 | `bauth.idn_blockchain_transaction.tx_type` | `idn_blockchain_transaction_tx_type_check` | Tipo de transacción enviada a la red blockchain | `SETTLE` · `FREEZE` · `UNFREEZE` · `REVERT` · `DEPLOY` · `CALL` |
| **MC-0189** | `d12.wallet.cadena` | T-427 | `bauth.idn_blockchain_wallet.chain` | `idn_blockchain_wallet_chain_check` | Red blockchain a la que está vinculada la wallet institucional | `BESU_QBFT` · `ARBITRUM` |
| **MC-0190** | `d12.wallet.estado` | T-427 | `bauth.idn_blockchain_wallet.status` | `idn_blockchain_wallet_status_check` | Estado operacional de una wallet blockchain institucional | `ACTIVE` · `FROZEN` · `DECOMMISSIONED` |

### D13 — Firma Digital

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0191** | `d13.cadena_ca.tipo_ca` | T-441 | `bauth.idn_signature_ca_chain.ca_type` | `idn_signature_ca_chain_ca_type_check` | Tipo de autoridad certificadora en la cadena PKI | `ROOT_CA` · `INTERMEDIATE_CA` · `ISSUING_CA` · `ADSIB` · `VAULT_PKI` |
| **MC-0192** | `d13.eudi_wallet.estado` | T-446 | `bauth.idn_signature_eudi_wallet.status` | `idn_signature_eudi_wallet_status_check` | Estado de una wallet EUDI vinculada para firma | `LINKED` · `SUSPENDED` · `REVOKED` · `PENDING` |
| **MC-0193** | `d13.solicitud_firma.tipo_documento` | T-440 | `bauth.idn_signature_request.document_type` | `idn_signature_request_document_type_check` | Tipo de documento a firmar digitalmente | `PDF` · `XML` · `JSON` · `INVOICE_SIN` · `VC` · `JWT` · `CONTRACT` |
| **MC-0194** | `d13.solicitud_firma.motor` | T-440 | `bauth.idn_signature_request.engine` | `idn_signature_request_engine_check` | Motor de firma digital utilizado en la solicitud | `INTERNAL_ED25519` · `EXTERNAL_ADSIB` · `DUAL` |
| **MC-0195** | `d13.solicitud_firma.formato_firma` | T-440 | `bauth.idn_signature_request.signature_format` | `idn_signature_request_signature_format_check` | Formato de firma digital avanzada aplicado | `PADES_B` · `PADES_T` · `PADES_LT` · `PADES_LTA` · `CADES_B` · `XADES_B` · `JADES` |
| **MC-0196** | `d13.solicitud_firma.estado` | T-440 | `bauth.idn_signature_request.status` | `idn_signature_request_status_check` | Estado de una solicitud de firma digital | `PENDING` · `SIGNING` · `SIGNED` · `FAILED` · `CANCELLED` |
| **MC-0197** | `d13.revocacion_cert.fuente_verificacion` | T-444 | `bauth.idn_signature_revocation_cache.check_source` | `idn_signature_revocation_cache_check_source_check` | Fuente de verificación del estado de revocación del certificado | `OCSP` · `CRL` · `VAULT` · `MANUAL` |
| **MC-0198** | `d13.revocacion_cert.estado` | T-444 | `bauth.idn_signature_revocation_cache.status` | `idn_signature_revocation_cache_status_check` | Estado de revocación según caché OCSP/CRL | `GOOD` · `REVOKED` · `UNKNOWN` |
| **MC-0199** | `d13.verificacion_firma.estado_cert` | T-571 | `bauth.idn_signature_verification_log.cert_status` | `idn_signature_verification_log_cert_status_check` | Estado del certificado al momento de verificar una firma | `VALID` · `REVOKED` · `EXPIRED` · `UNKNOWN` |
| **MC-0200** | `d13.verificacion_firma.resultado` | T-571 | `bauth.idn_signature_verification_log.outcome` | `idn_signature_verification_log_outcome_check` | Resultado de la verificación de una firma digital | `VALID` · `INVALID` · `EXPIRED` · `REVOKED` · `UNKNOWN` · `ERROR` |

### D14 — PAM

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0201** | `d14.breakglass.metodo_auth` | T-185 | `bauth.pam_breakglass_activation.auth_method` | `chk_pbga_auth_method` | Método de autenticación exigido para activar break-glass | `MTLS_X509` · `WEBAUTHN_ROAMING` · `WEBAUTHN_PLATFORM` |
| **MC-0202** | `d14.breakglass.estado` | T-185 | `bauth.pam_breakglass_activation.status` | `chk_pbga_deactivation` | Estado de una sesión de acceso de emergencia break-glass | `PENDING_APPROVAL` · `ACTIVE` · `DEACTIVATED` · `REVIEWED` |
| **MC-0203** | `d14.breakglass.estado._control` | T-185 | `bauth.pam_breakglass_activation.status` | `chk_pbga_dual_control` | Estado de la activación con control dual de break-glass | `PENDING_APPROVAL` · `ACTIVE` · `DEACTIVATED` · `REVIEWED` |
| **MC-0204** | `d14.credencial_priv.politica_rotacion` | T-183 | `bauth.pam_credential_ref.rotation_policy` | `chk_pcref_rot` | Política de rotación de una credencial privilegiada | `MANUAL` · `AUTO_7D` · `AUTO_30D` · `AUTO_90D` · `AUTO_1Y` |
| **MC-0205** | `d14.credencial_priv.estado` | T-183 | `bauth.pam_credential_ref.status` | `chk_pcref_status` | Estado de ciclo de vida de una credencial privilegiada | `ACTIVE` · `ROTATING` · `REVOKED` · `EXPIRED` |
| **MC-0206** | `d14.credencial_priv.tipo_credencial` | T-183 | `bauth.pam_credential_ref.credential_type` | `chk_pcref_type` | Tipo de credencial privilegiada gestionada por PAM | `PASSWORD` · `SSH_KEY` · `API_KEY` · `CERT` · `TOKEN` · `OAUTH_CLIENT` |
| **MC-0207** | `d14.cuenta_priv.estado` | T-560 | `bauth.pam_cuenta_privilegiada.estado` | `chk_pcp_estado` | Estado operacional de una cuenta privilegiada en PAM | `ACTIVE` · `INACTIVE` · `DECOMMISSIONED` |
| **MC-0208** | `d14.cuenta_priv.tipo` | T-560 | `bauth.pam_cuenta_privilegiada.tipo` | `chk_pcp_tipo` | Tipo de cuenta privilegiada gestionada en PAM | `LOCAL_ADMIN` · `DOMAIN_ADMIN` · `SERVICE_ACCOUNT` · `SHARED` · `ROOT` · `API_KEY` · `CERTIFICATE` · `SSH_KEY` · `DATABASE_DBA` · `CLOUD_ADMIN` |
| **MC-0209** | `d14.jit.decision` | T-182b | `bauth.pam_jit_approval.decision` | `chk_pja_decision` | Decisión de aprobación de una solicitud JIT | `APPROVED` · `REJECTED` |
| **MC-0210** | `d14.nhi_secreto.politica_rotacion` | T-189 | `bauth.pam_nhi_secret_ref.rotation_policy` | `chk_pnsr_rotation` | Política de rotación del secreto de una NHI | `AUTO_7D` · `AUTO_30D` · `AUTO_90D` · `MANUAL` · `ON_USE` |
| **MC-0211** | `d14.sesion_priv.estado` | T-184 | `bauth.pam_session_record.status` | `chk_psr_status` | Estado de una sesión privilegiada grabada en PAM | `ACTIVE` · `ENDED` · `TERMINATED` · `ERROR` |
| **MC-0212** | `d14.grabacion.storage.type` | T-461 | `bauth.pam_session_recording.storage_type` | `pam_session_recording_storage_type_check` | Tipo de almacenamiento para grabaciones de sesiones PAM | `MINIO` · `S3` · `LOCAL` · `NFS` |

### D15 — NHI

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0213** | `d15.nhi_rotacion.accion_fallo` | T-480 | `bauth.idn_nhi_rotation_policy.fail_action` | `idn_nhi_rotation_policy_fail_action_check` | Acción a tomar cuando falla la rotación de credencial de una NHI | `NOTIFY` · `SUSPEND_NHI` · `ALERT_ADMIN` |
| **MC-0214** | `d15.nhi_rotacion.tipo_nhi` | T-480 | `bauth.idn_nhi_rotation_policy.nhi_type` | `idn_nhi_rotation_policy_nhi_type_check` | Tipo de identidad no humana sujeta a política de rotación | `SERVICE_ACCOUNT` · `CI_CD` · `DAEMON` · `BOT` · `AGENT_IA` · `API_KEY` |
| **MC-0215** | `d15.svid.estado` | T-481 | `bauth.idn_nhi_svid.status` | `idn_nhi_svid_status_check` | Estado de un SVID (identidad de carga de trabajo SPIFFE) | `ACTIVE` · `ROTATED` · `REVOKED` · `EXPIRED` |
| **MC-0216** | `d15.svid.tipo_svid` | T-481 | `bauth.idn_nhi_svid.svid_type` | `idn_nhi_svid_svid_type_check` | Formato del SVID emitido para la carga de trabajo | `X509` · `JWT` |
| **MC-0217** | `d15.nhi_agente.tipo_sesion` | T-190 | `bauth.idn_roles_nhi_agent_identity.session_type` | `chk_iai_session` | Tipo de sesión que la identidad de agente IA puede establecer | `EPHEMERAL` · `PERSISTENT` |
| **MC-0218** | `d15.nhi_cert.decision` | T-188 | `bauth.idn_roles_nhi_certification.decision` | `chk_inc_decision` | Decisión del comité de certificación sobre una NHI en revisión | `CERTIFY` · `DECOMMISSION` · `REDUCE_SCOPE` · `ESCALATE` |
| **MC-0219** | `d15.nhi_identidad.estado` | T-186 | `bauth.idn_roles_nhi_identity.status` | `chk_inhi_status` | Estado operacional de una identidad no humana | `ACTIVE` · `DORMANT` · `DECOMMISSIONED` · `SUSPENDED` |
| **MC-0220** | `d15.nhi_identidad.tipo_nhi` | T-186 | `bauth.idn_roles_nhi_identity.nhi_type` | `chk_inhi_type` | Categoría de identidad no humana registrada en el sistema | `SERVICE_ACCOUNT` · `WORKLOAD` · `AGENT` · `BOT` · `API_CLIENT` · `CI_CD_PIPELINE` |
| **MC-0221** | `d15.nhi_ciclo.tipo_evento` | T-187 | `bauth.idn_roles_nhi_lifecycle_event.event_type` | `chk_inle_type` | Tipo de evento en el ciclo de vida de una NHI | `PROVISIONED` · `CERTIFIED` · `ROTATED` · `SUSPENDED` · `REACTIVATED` · `DECOMMISSIONED` · `OWNER_CHANGED` · `REVIEW_SCHEDULED` |

### D99 — Global Admin

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0222** | `d99.admin.rol_admin` | T-510 | `bauth.idn_global_admin.admin_role` | `idn_global_admin_admin_role_check` | Rol de administración global asignado al superusuario del sistema | `SUPER_ADMIN` · `SECURITY_ADMIN` · `AUDIT_ADMIN` · `SUPPORT_ADMIN` |
| **MC-0223** | `d99.cumplimiento.estado` | T-514 | `bauth.idn_global_compliance_control.status` | `idn_global_compliance_control_status_check` | Estado de implementación de un control de cumplimiento normativo global | `IMPLEMENTED` · `PARTIAL` · `PLANNED` · `NOT_APPLICABLE` · `GAP` |
| **MC-0224** | `d99.cripto.familia_algoritmo` | T-513 | `bauth.idn_global_crypto_params.algorithm_family` | `idn_global_crypto_params_algorithm_family_check` | Familia criptográfica de un algoritmo gestionado globalmente | `SYMMETRIC` · `ASYMMETRIC` · `HASH` · `KDF` · `KEM` · `SIGNATURE` · `MAC` |
| **MC-0225** | `d99.hitl.tipo_entidad` | T-512 | `bauth.idn_global_hitl_exception.affected_entity_type` | `idn_global_hitl_exception_affected_entity_type_check` | Tipo de entidad afectada por una excepción HITL global | `ALGORITHM` · `POLICY` · `TENANT` · `USER` · `ROLE` · `CERT` |
| **MC-0226** | `d99.hitl.tipo_excepcion` | T-512 | `bauth.idn_global_hitl_exception.exception_type` | `idn_global_hitl_exception_exception_type_check` | Motivo de la excepción aprobada por humano en el dominio global | `PROHIBITED_ALGO` · `POLICY_OVERRIDE` · `EMERGENCY_ACCESS` · `CRYPTO_DOWNGRADE` · `COMPLIANCE_BREACH` · `AI_DECISION_REVIEWED` |
| **MC-0227** | `d99.hitl.estado` | T-512 | `bauth.idn_global_hitl_exception.status` | `idn_global_hitl_exception_status_check` | Estado de tramitación de una excepción HITL global | `PENDING` · `APPROVED` · `REJECTED` · `EXPIRED` · `REVOKED` |
| **MC-0228** | `d99.notificacion.tipo_notificacion` | T-511 | `bauth.idn_global_notification.notification_type` | `idn_global_notification_notification_type_check` | Categoría de la notificación global emitida por el sistema | `SECURITY_ALERT` · `CRYPTO_EXPIRY` · `CERT_EXPIRY` · `COMPLIANCE_WARNING` · `MAINTENANCE` · `INCIDENT` · `POLICY_CHANGE` · `CAPACITY_ALERT` |
| **MC-0229** | `d99.notificacion.severidad` | T-511 | `bauth.idn_global_notification.severity` | `idn_global_notification_severity_check` | Nivel de severidad de una notificación global del sistema | `INFO` · `WARNING` · `ERROR` · `CRITICAL` |
| **MC-0230** | `d99.notificacion.alcance_destino` | T-511 | `bauth.idn_global_notification.target_scope` | `idn_global_notification_target_scope_check` | Alcance de los destinatarios de una notificación global | `ALL` · `TENANT` · `ADMIN` |
| **MC-0231** | `d99.sbom.tipo_componente` | T-515 | `bauth.idn_global_sbom.component_type` | `idn_global_sbom_component_type_check` | Tipo de componente software registrado en el inventario SBOM | `LIBRARY` · `FRAMEWORK` · `DAEMON` · `TOOL` · `OS_PACKAGE` · `CONTAINER` |
| **MC-0232** | `d99.sbom.nivel_riesgo` | T-515 | `bauth.idn_global_sbom.risk_level` | `idn_global_sbom_risk_level_check` | Nivel de riesgo de seguridad de un componente en el SBOM | `CRITICAL` · `HIGH` · `MEDIUM` · `LOW` · `NONE` |

### Privilegios (priv.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0233** | `priv.aseguramiento.resultado` | T-176 | `bauth.privilege_assurance_audit.outcome` | `privilege_assurance_audit_outcome_check` | Resultado de la evaluación de aseguramiento de un privilegio | `PERMIT` · `STEP_UP_REQUIRED` · `DENIED` |
| **MC-0234** | `priv.atom.operacion` | T-170b | `bauth.privilege_atom_audit.operation` | `privilege_atom_audit_operation_check` | Tipo de operación registrada en el log de auditoría de átomos | `GRANTED` · `REVOKED` · `EXPIRED` · `MODIFIED` · `STEP_UP` · `BREAKGLASS` |
| **MC-0235** | `priv.delegacion.estado` | T-172 | `bauth.privilege_delegation.status` | `chk_pd_status` | Estado de una delegación de privilegios entre entidades | `ACTIVE` · `EXPIRED` · `REVOKED` |
| **MC-0236** | `priv.excepcion_reg.tipo_excepcion` | T-179 | `bauth.privilege_exception_record.exception_type` | `chk_per_type` | Tipo de excepción al modelo de privilegios registrada formalmente | `SOD_EXCEPTION` · `TIER_EXCEPTION` · `SCOPE_EXCEPTION` · `OTHER` |
| **MC-0237** | `priv.anulacion.tipo_anulacion` | T-173 | `bauth.privilege_override.override_type` | `chk_po_override_type` | Dirección del override aplicado a una decisión de privilegio | `DENY_TO_PERMIT` · `PERMIT_TO_DENY` |
| **MC-0238** | `priv.recurso.ruta_eval` | T-171 | `bauth.privilege_resource_atom.evaluation_path` | `chk_pra_eval_path` | Ruta de evaluación usada por el motor de privilegios para un átomo | `FAST` · `POLICY` · `EXTERNAL` · `PRECONDITION` |
| **MC-0239** | `priv.recurso.estado` | T-171 | `bauth.privilege_resource_atom.status` | `chk_pra_status` | Estado operacional de un átomo de recurso en el motor BitMask | `ACTIVE` · `INACTIVE` · `DEPRECATED` |
| **MC-0240** | `priv.recurso.alcance_tenant` | T-171 | `bauth.privilege_resource_atom.tenant_scope` | `chk_pra_tenant_scope` | Alcance de aplicabilidad de un átomo de recurso por tenant | `GLOBAL` · `TENANT_SPECIFIC` |
| **MC-0241** | `priv.recurso.tipo_protocolo` | T-171 | `bauth.privilege_resource_atom.protocol_type` | `chk_pra_tipo_protocolo` | Protocolo de comunicación que protege el átomo de recurso | `WS_RPC` · `JSON_RPC` · `GRPC` · `UNIX_SOCKET` · `HTTP_EXT` |
| **MC-0242** | `priv.verbo_conflicto.tipo_conflicto` | T-175 | `bauth.privilege_verb_conflict.conflict_type` | `chk_pvc_conflict_type` | Tipo de conflicto SoD detectado entre verbos de privilegio | `STATIC_SOD` · `DYNAMIC_SOD` · `AFFINITY` |

### Sesiones (ses.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0243** | `ses.caep.tipo_evento` | T-191 | `bauth.ses_caep_event_log.event_type` | `chk_scel_event_type` | Tipo de evento CAEP emitido hacia suscriptores SSF | `session-revoked` · `token-claims-change` · `credential-change` · `assurance-level-change` · `device-compliance-change` · `risk-level-change` |
| **MC-0244** | `ses.caep.tipo_sujeto` | T-191 | `bauth.ses_caep_event_log.subject_type` | `chk_scel_subject_type` | Tipo de sujeto sobre el que ocurre el evento CAEP | `session` · `user` · `device` · `token` · `oauth_client` |
| **MC-0245** | `ses.sesion.motivo_fin` | T-181 | `bauth.ses_session_log.termination_reason` | `chk_ssl_reason` | Motivo de terminación de una sesión de usuario | `LOGOUT` · `TIMEOUT` · `CAEP_REVOKE` · `ADMIN_REVOKE` · `EXPIRY` |
| **MC-0246** | `ses.ssf.estado` | T-192 | `bauth.ses_ssf_stream.status` | `chk_sss_status` | Estado del stream SSF que entrega eventos CAEP a consumidores | `ACTIVE` · `PAUSED` · `TERMINATED` · `ERROR` |

### Firma PKI (sig.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0247** | `sig.adsib_ciclo.event` | T-356 | `bauth.sig_adsib_lifecycle.event` | `chk_sal_event` | Evento del ciclo de vida de un certificado ADSIB (Bolivia) | `ISSUED` · `ACTIVATED` · `ALERT_30D` · `ALERT_15D` · `ALERT_7D` · `RENEWAL_CSR` · `RENEWED` · `EXPIRED` · `REVOKED_BY_CA` · `REISSUED` |
| **MC-0248** | `sig.certificado.tipo_adsib` | T-351 | `bauth.sig_certificate.adsib_type` | `chk_sc_adsib` | Tipo de certificado digital emitido por la ADSIB (Ley 164) | `PERSONA_NATURAL` · `PERSONA_JURIDICA` · `FIRMA_AUTOMATICA` |
| **MC-0249** | `sig.certificado.motor` | T-351 | `bauth.sig_certificate.engine` | `chk_sc_engine` | Motor emisor del certificado PKI | `INTERNAL_VAULT` · `EXTERNAL_ADSIB` · `ENTERPRISE_PKI` |
| **MC-0250** | `sig.crl.motor` | T-352 | `bauth.sig_crl.engine` | `chk_scrl_engine` | Motor que emitió la CRL (lista de revocación de certificados) | `INTERNAL_VAULT` · `EXTERNAL_ADSIB` |
| **MC-0251** | `sig.doc_politica.engine.required` | T-357 | `bauth.sig_document_policy.engine_required` | `chk_sdp_eng` | Motor de firma exigido por la política de documento | `INTERNAL_VAULT` · `EXTERNAL_ADSIB` · `BOTH` |
| **MC-0252** | `sig.doc_politica.external.profile` | T-357 | `bauth.sig_document_policy.external_profile` | `chk_sdp_ext` | Perfil de firma externa XAdES exigido para el documento | `XAdES-BES` · `EXT-B` · `EXT-T` · `EXT-LT` · `EXT-LTA` |
| **MC-0253** | `sig.doc_politica.internal.profile` | T-357 | `bauth.sig_document_policy.internal_profile` | `chk_sdp_int` | Perfil de firma interna JWS exigido para el documento | `JWS` · `INT-B` · `INT-T` · `INT-LT` |
| **MC-0254** | `sig.llave.purpose` | T-350 | `bauth.sig_key.purpose` | `chk_sk_purpose` | Propósito criptográfico de una llave de firma gestionada | `JWT_SIGNING` · `DOCUMENT_SIGNING` · `CODE_SIGNING` · `TLS_CLIENT` · `ADSIB_BILLING` · `ADSIB_CONTRACTS` |
| **MC-0255** | `sig.llave.estado` | T-350 | `bauth.sig_key.status` | `chk_sk_status` | Estado de ciclo de vida de una llave de firma | `ACTIVE` · `ROTATING` · `SUSPENDED` · `REVOKED` |
| **MC-0256** | `sig.operacion.resultado` | T-353 | `bauth.sig_operation_log.outcome` | `chk_sol_outcome` | Resultado de una operación de firma digital registrada | `SUCCESS` · `FAILURE` · `CERT_EXPIRED` · `CERT_REVOKED` |
| **MC-0257** | `sig.operacion.tipo_firmante` | T-353 | `bauth.sig_operation_log.signer_type` | `chk_sol_stype` | Tipo de entidad que realizó la firma digital | `HUMAN` · `NHI` · `DAEMON` |

### Blockchain bajo nivel (blk.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0258** | `blk.cuenta.estado` | T-361 | `bauth.blk_account.status` | `chk_bac_status` | Estado de una cuenta blockchain gestionada por bAuth | `ACTIVE` · `FROZEN` · `CLOSED` |
| **MC-0259** | `blk.ancla.cadena` | T-358 | `bauth.blk_anchor.chain` | `chk_ba_chain` | Red blockchain destino para el anclaje de evidencia | `ARBITRUM_ONE` · `BESU_QBFT` |
| **MC-0260** | `blk.ancla.estado` | T-358 | `bauth.blk_anchor.status` | `chk_ba_status` | Estado de la transacción de anclaje en blockchain | `PENDING` · `SENT` · `ANCHORED` · `FAILED` |
| **MC-0261** | `blk.merkle.estado` | T-359 | `bauth.blk_merkle_batch.status` | `chk_bmb_status` | Estado del batch de Merkle antes de anclar en blockchain | `OPEN` · `CLOSED` · `COMPUTING` · `ANCHORED` · `FAILED` |
| **MC-0262** | `blk.reconciliacion.estado` | T-362 | `bauth.blk_reconciliation.status` | `chk_br_status` | Resultado de la reconciliación entre BD local y registro blockchain | `OK` · `DISCREPANCY` · `CORRECTED` |

### Verifiable Credentials (vc.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0263** | `vc.wallet.metodo_respaldo` | T-380 | `bauth.wallet.backup_method` | `chk_w_backup` | Método de respaldo seleccionado para la cartera digital | `NONE` · `ENCRYPTED_CLOUD` |
| **MC-0264** | `vc.wallet.estado` | T-380 | `bauth.wallet.status` | `chk_w_status` | Estado de una cartera digital de credenciales verificables | `ACTIVE` · `SUSPENDED` · `REVOKED` · `ARCHIVED` |
| **MC-0265** | `vc.emision.resultado` | T-383 | `bauth.wallet_issuance_log.outcome` | `chk_wil_outcome` | Resultado de la emisión de una credencial verificable | `ISSUED` · `REJECTED` · `PENDING` |
| **MC-0266** | `vc.emision.protocolo` | T-383 | `bauth.wallet_issuance_log.protocol` | `chk_wil_proto` | Protocolo usado para emitir la credencial verificable | `OPENID4VCI` · `DIRECT_ISSUE` · `IMPORTED` |
| **MC-0267** | `vc.item.estado` | T-381 | `bauth.wallet_item.status` | `chk_wi_status` | Estado de un ítem dentro de la cartera digital | `ACTIVE` · `EXPIRED` · `REVOKED` · `HIDDEN` |
| **MC-0268** | `vc.item.tipo` | T-381 | `bauth.wallet_item.type` | `chk_wi_type` | Tipo de credencial o documento almacenado en la cartera digital | `VC` · `FIDO2` · `X509_CERT` · `DID_DOC` · `SIG_CERT` · `NATIONAL_ID` · `LICENSE` · `PHYSICAL_PASS` |
| **MC-0269** | `vc.presentacion.resultado` | T-382 | `bauth.wallet_presentation_log.outcome` | `chk_wpl_outcome` | Resultado de la presentación de una credencial verificable | `ACCEPTED` · `REJECTED` · `PARTIAL` |
| **MC-0270** | `vc.presentacion.protocolo` | T-382 | `bauth.wallet_presentation_log.protocol` | `chk_wpl_proto` | Protocolo empleado para presentar la credencial verificable | `OPENID4VP` · `SAML_ASSERTION` · `DIRECT_API` |

### Roles — Versionado (rol.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0271** | `rol.ciclo_vida.tipo_disparador` | T-B02L | `bauth.idn_roles_rol_lifecycle_event.trigger_type` | `chk_irle_trigger` | Mecanismo que disparó el evento de ciclo de vida del rol | `MANUAL` · `AUTO_EXPIRY` · `RECONCILE` · `IGA_REVIEW` · `BREAKGLASS` · `BOOTSTRAP` |
| **MC-0272** | `rol.template.operacion` | T-163 | `bauth.idn_roles_template_history.operation` | `idn_roles_template_history_operation_check` | Tipo de operación registrada en el historial de cambios del template de rol | `INSERT` · `UPDATE` · `DEACTIVATE` |
| **MC-0273** | `rol.ver_retencion.clase_info` | T-154 | `bauth.idn_roles_ver_b01_retention_policy.info_class` | `chk_irvb01rp_class` | Clase de información sujeta a la política de retención del rol | `C1` · `C2` · `C3` · `C4` |
| **MC-0274** | `rol.ver_contrato.compatibilidad` | T-155 | `bauth.idn_roles_ver_contract_revision_log.compatibility` | `chk_irvcrl_compat` | Compatibilidad de una revisión de contrato de rol con versiones anteriores | `COMPATIBLE` · `BREAKING` |

### Registry (registry.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0275** | `registry.attr_schema.clasificacion` | T-517 | `bauth.idn_attribute_schema.classification` | `chk_idras_clas` | Nivel de sensibilidad de un atributo de identidad en el esquema | `PUBLIC` · `INTERNAL` · `CONFIDENTIAL` · `PII` · `SENSITIVE_PII` |
| **MC-0276** | `registry.attr_schema.mutabilidad` | T-517 | `bauth.idn_attribute_schema.mutability` | `chk_idras_mut` | Permisos de lectura/escritura sobre un atributo de identidad | `READ_ONLY` · `READ_WRITE` · `WRITE_ONLY` · `IMMUTABLE` |
| **MC-0277** | `registry.attr_schema.campo_retorno` | T-517 | `bauth.idn_attribute_schema.returned` | `chk_idras_ret` | Política de inclusión del atributo en las respuestas SCIM | `ALWAYS` · `NEVER` · `DEFAULT` · `REQUEST` |
| **MC-0278** | `registry.attr_schema.tipo_dato` | T-517 | `bauth.idn_attribute_schema.data_type` | `chk_idras_tipo` | Tipo de dato esperado para un atributo del esquema de identidad | `STRING` · `INTEGER` · `DECIMAL` · `BOOLEAN` · `DATE` · `DATETIME` · `UUID` · `JSON` · `BINARY` |
| **MC-0279** | `registry.schema_attr.categoria` | T-500 | `bauth.idn_registry_attribute_schema.category` | `idn_registry_attribute_schema_category_check` | Categoría semántica de un atributo en el registro global | `IDENTITY` · `CONTACT` · `LEGAL` · `BIOMETRIC` · `FINANCIAL` · `SYSTEM` · `CUSTOM` |
| **MC-0280** | `registry.schema_attr.clasificacion` | T-500 | `bauth.idn_registry_attribute_schema.classification` | `idn_registry_attribute_schema_classification_check` | Nivel de confidencialidad de un atributo en el registro global | `PUBLIC` · `INTERNAL` · `CONFIDENTIAL` · `SECRET` |
| **MC-0281** | `registry.schema_attr.tipo_dato` | T-500 | `bauth.idn_registry_attribute_schema.data_type` | `idn_registry_attribute_schema_data_type_check` | Tipo de dato de un atributo en el registro global | `TEXT` · `INTEGER` · `DECIMAL` · `BOOLEAN` · `DATE` · `DATETIME` · `JSON` · `BINARY` · `UUID` |
| **MC-0282** | `registry.schema_attr.mutabilidad` | T-500 | `bauth.idn_registry_attribute_schema.mutability` | `idn_registry_attribute_schema_mutability_check` | Política de modificación de un atributo en el registro global | `READ_ONLY` · `READ_WRITE` · `WRITE_ONCE` |
| **MC-0283** | `registry.schema_attr.fuente` | T-500 | `bauth.idn_registry_attribute_schema.source` | `idn_registry_attribute_schema_source_check` | Origen del valor de un atributo de identidad en el registro | `USER` · `SYSTEM` · `PROOFING` · `IMPORT` · `DERIVED` |

### Privacidad — DPIA (privacidad.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0284** | `privacidad.dpia_reg.estado` | T-530 | `bauth.idn_dpia_registro.estado` | `chk_idpia_estado` | Estado del proceso de evaluación de impacto de protección de datos (DPIA) | `DRAFT` · `IN_REVIEW` · `APPROVED` · `REJECTED` · `ARCHIVED` · `REQUIRES_DPA` |
| **MC-0285** | `privacidad.dpia_reg.riesgo_residual` | T-530 | `bauth.idn_dpia_registro.riesgo_residual` | `chk_idpia_riesgo` | Nivel de riesgo residual tras aplicar los controles definidos en la DPIA | `LOW` · `MEDIUM` · `HIGH` · `VERY_HIGH` |

### Menú Sistema (menu.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0286** | `menu.atom.efecto_requerido` | T-061 | `bglobal.menu_item_atom.required_effect` | `menu_item_atom_required_effect_check` | Efecto de privilegio requerido para que un ítem de menú sea accesible | `PERMIT` · `DENY` |

### BOS Control Plane (bos.*)

| MC | code | T-ref | Origen (tabla.columna) | Constraint | Concepto | Valores válidos |
|-----|------|-------|------------------------|------------|----------|-----------------|
| **MC-0287** | `bos.snapshot.alcance` | T-406 | `bos.cap_sistema_snapshot.scope` | `chk_cap_sn_scope` | Alcance del snapshot de capacidades del sistema BOS | `GLOBAL` · `TENANT` |
| **MC-0288** | `bos.tenant_politica.modo_politica` | T-407 | `bos.cap_tenant_policy.policy_mode` | `chk_cap_tp_mode` | Modo de gobernanza de capacidades aplicado al tenant | `autonomous` · `recommend` · `block_and_alert` · `emergency` |
| **MC-0289** | `bos.audit.operacion` | T-397 | `bos.ctx_context_audit.operation` | `chk_ca_operation` | Tipo de operación de contexto registrada en el log de auditoría BOS | `DEVICE_REGISTER` · `DEVICE_HEARTBEAT` · `SESSION_CREATE` · `SESSION_PROMOTE` · `SESSION_SWITCH` · `SESSION_INVALIDATE` · `SESSION_EXPIRE` · `SESSION_SUSPEND` · `SESSION_BLOCK` · `SESSION_ARCHIVE` · `CONTEXT_TRANSFER` · `EMERGENCY_ACTIVATE` · `EMERGENCY_APPROVE` · `COMPLIANCE_VIOLATION` · `ADMIN_OVERRIDE` |
| **MC-0290** | `bos.audit.estado_anterior` | T-397 | `bos.ctx_context_audit.old_state` | `chk_ca_state` | Estado previo del contexto antes de la operación auditada | `PENDING` · `ACTIVE` · `SUSPENDED` · `BLOCKED` · `INVALIDATED` · `EXPIRED` · `ARCHIVED` |
| **MC-0291** | `bos.emergencia.resultado_revision` | T-402 | `bos.ctx_context_emergency.review_outcome` | `chk_cem_review` | Dictamen de la revisión post-emergencia del acceso de emergencia | `JUSTIFIED` · `UNJUSTIFIED` · `POLICY_VIOLATION` |
| **MC-0292** | `bos.emergencia.estado` | T-402 | `bos.ctx_context_emergency.state` | `chk_cem_state` | Estado de un contexto de acceso de emergencia activado | `ACTIVATED` · `SESSION_CREATED` · `CLOSED` · `REVIEWED` · `EXPIRED` |
| **MC-0293** | `bos.transferencia.tipo_transferencia` | T-401 | `bos.ctx_context_transfer.transfer_type` | `chk_ct_type` | Modalidad de transferencia de contexto de sesión entre dispositivos | `USER_INITIATED` · `AUTO_CONTINUITY` · `ADMIN_TRANSFER` · `BREAKGLASS` |
| **MC-0294** | `bos.ficha_evento.resultado` | T-404 | `bos.fch_ficha_event.result` | `chk_fch_e_result` | Resultado de la ejecución de un evento sobre una ficha de despliegue | `OK` · `FAIL` · `PARTIAL` · `SKIPPED` |
| **MC-0295** | `bos.ficha_estado.backend` | T-403 | `bos.fch_ficha_state.backend` | `chk_fch_s_backend` | Motor de ejecución del backend de la ficha de despliegue | `bash` · `k8s` · `binary` · `python` |
| **MC-0296** | `bos.ficha_estado.estado` | T-403 | `bos.fch_ficha_state.state` | `chk_fch_s_state` | Estado de ciclo de vida de una ficha de despliegue en el servidor | `PENDING` · `READY` · `INSTALLING` · `INSTALLED` · `UPDATE_AVAILABLE` · `UPDATE_APPROVED` · `UPDATING` · `DEGRADED` · `PHYSICAL_ERROR` · `LOGICAL_ERROR` · `REPAIRING` · `UNRECOVERABLE` · `INSTALL_FAILED` · `UPDATE_FAILED` · `ROLLBACK` · `CLEANUP` · `PAUSED` · `UNINSTALLED` |
| **MC-0297** | `bos.bootstrap.estado` | T-405 | `bos.ins_bootstrap_event.state` | `chk_ins_be_state` | Estado de ejecución de un paso en el proceso de bootstrap BOS | `STARTED` · `COMPLETED` · `FAILED` · `SKIPPED` · `RETRYING` |
| **MC-0298** | `bos.saga.estado` | T-412 | `bos.ins_saga_execution.state` | `chk_ins_se_state` | Estado de ejecución de una saga de instalación/actualización | `RUNNING` · `COMPLETED` · `FAILED` · `COMPENSATING` · `COMPENSATED` |
| **MC-0299** | `bos.saga.tipo_saga` | T-412 | `bos.ins_saga_execution.saga_type` | `chk_ins_se_type` | Tipo de operación orquestada por la saga BOS | `install` · `update` · `repair` · `remove` · `deploy_tenant` · `remove_tenant` · `suspend_tenant` |
| **MC-0300** | `bos.inventario_cert.tipo_cert` | T-413 | `bos.net_cert_inventory.cert_type` | `chk_net_ci_cert_type` | Tipo de certificado TLS/PKI registrado en el inventario de red | `daemon_host` · `ficha_k8s` · `spiffe_svid` · `external_wildcard` · `kong_tls` · `ca_internal` |
| **MC-0301** | `bos.inventario_cert.motor_emisor` | T-413 | `bos.net_cert_inventory.issuer_engine` | `chk_net_ci_issuer_engine` | Motor que emitió el certificado TLS registrado en el inventario | `vault_pki` · `cert_manager` · `spire` · `acme_le` · `manual` |
| **MC-0302** | `bos.inventario_cert.algoritmo_llave` | T-413 | `bos.net_cert_inventory.key_algorithm` | `chk_net_ci_key_algo` | Algoritmo de la llave del certificado en el inventario de red | `ECDSA` · `RSA` · `Ed25519` |
| **MC-0303** | `bos.inventario_cert.estado` | T-413 | `bos.net_cert_inventory.status` | `chk_net_ci_status` | Estado de vigencia de un certificado en el inventario de red | `active` · `expiring_soon` · `expired` · `revoked` · `superseded` |
| **MC-0304** | `bos.evento_seg.severidad` | T-414 | `bos.net_security_events.severity` | `chk_net_se_severity` | Nivel de severidad de un evento de seguridad de red detectado por BOS | `info` · `warn` · `high` · `critical` |
| **MC-0305** | `bos.evento_seg.fuente` | T-414 | `bos.net_security_events.source` | `chk_net_se_source` | Subsistema BOS que generó el evento de seguridad de red | `portman` · `certman` · `fwman` · `ips` · `crowdsec` · `fail2ban` · `psad` · `bos_daemon` |
| **MC-0306** | `bos.evento_seg.tipo_evento` | T-414 | `bos.net_security_events.event_type` | `chk_net_se_type` | Tipo de evento de seguridad de red registrado por el plano de control BOS | `port_assigned` · `port_released` · `port_conflict` · `port_validated` · `cert_issued` · `cert_renewed` · `cert_expiring` · `cert_revoked` · `fw_rule_added` · `fw_rule_removed` · `netpol_synced` · `fw_drift_detected` · `ips_block` · `ips_unblock` · `port_scan_detected` · `crowdsec_ban` · `crowdsec_unban` · `fail2ban_ban` · `fail2ban_unban` · `ddos_detected` · `brute_force_detected` · `replay_detected` |
| **MC-0307** | `bos.puerto.tipo_activo` | T-408 | `bos.prt_port_assignment.asset_type` | `chk_prt_pa_asset` | Tipo de activo al que se asigna un puerto en el catálogo de puertos | `ficha` · `daemon` · `logical_server` · `k8s_node` · `k8s_service` · `kong_route` |
| **MC-0308** | `bos.puerto.tipo_puerto` | T-408 | `bos.prt_port_assignment.port_type` | `chk_prt_pa_port_type` | Clase de puerto asignado según el contexto de red de BOS | `HOST_PHYSICAL` · `HOST_LOGICAL` · `K8S_NODE_PORT` · `K8S_CLUSTER_IP` · `K8S_LOAD_BALANCER` |
| **MC-0309** | `bos.puerto.estado` | T-408 | `bos.prt_port_assignment.status` | `chk_prt_pa_status` | Estado de una asignación de puerto en el catálogo SBOS-050 | `assigned` · `released` · `revoked` · `conflict` |
| **MC-0310** | `bos.puerto.transporte` | T-408 | `bos.prt_port_assignment.transport` | `chk_prt_pa_transport` | Protocolo de transporte de la capa 4 para el puerto asignado | `TCP` · `UDP` · `SCTP` · `DCCP` |
| **MC-0311** | `bos.release.channel` | T-410 | `bos.rel_release_event.channel` | `chk_rel_re_channel` | Canal de distribución por el que se entrega una release a los servidores | `canary` · `early` · `stable` |
| **MC-0312** | `bos.release.operacion` | T-410 | `bos.rel_release_event.operation` | `chk_rel_re_op` | Tipo de operación ejecutada sobre una release en el servidor | `INSTALL` · `UPDATE` · `ROLLBACK` |
| **MC-0313** | `bos.release.resultado` | T-410 | `bos.rel_release_event.result` | `chk_rel_re_result` | Resultado de la aplicación de una release en un servidor | `OK` · `FAIL` · `PARTIAL` |
| **MC-0314** | `bos.release.disparado_por` | T-410 | `bos.rel_release_event.triggered_by` | `chk_rel_re_trigger` | Actor que inició la ejecución de la release | `scheduler` · `watchdog` · `human` |
| **MC-0315** | `bos.watchdog.accion_tomada` | T-411 | `bos.wdg_watchdog_event.action_taken` | `chk_wdg_we_action` | Acción correctiva tomada por el watchdog ante una anomalía detectada | `auto_repair` · `hitl_escalated` · `daemon_restart` · `rollback` · `none` |
| **MC-0316** | `bos.watchdog.capa_verificacion` | T-411 | `bos.wdg_watchdog_event.check_layer` | `chk_wdg_we_layer` | Capa de infraestructura donde el watchdog detectó la anomalía | `ubuntu_host` · `k8s_cluster` · `bos_fichas` |
| **MC-0317** | `bos.watchdog.tipo_recurso` | T-411 | `bos.wdg_watchdog_event.resource_type` | `chk_wdg_we_resource` | Tipo de recurso monitoreado por el watchdog de BOS | `host` · `node` · `pod` · `ficha` · `daemon` |
| **MC-0318** | `bos.watchdog.resultado_accion` | T-411 | `bos.wdg_watchdog_event.action_result` | `chk_wdg_we_result` | Resultado de la acción correctiva ejecutada por el watchdog | `OK` · `FAIL` · `PENDING` |
| **MC-0319** | `bos.watchdog.severidad` | T-411 | `bos.wdg_watchdog_event.severity` | `chk_wdg_we_severity` | Nivel de severidad de la anomalía detectada por el watchdog | `INFO` · `WARN` · `ERROR` · `CRITICAL` |

---

## ÍNDICE INVERSO — Tabla.Columna → MC

> Para cada columna que tiene un menú contextual, su código MC.
> Ordenado por schema.tabla.columna.

| Tabla.Columna | MC | Code del menú |
|---------------|-----|---------------|
| `bauth.aud_certification_campaign.campaign_type` | MC-0033 | `campana_tipo` |
| `bauth.aud_certification_campaign.scope` | MC-0031 | `campana_alcance` |
| `bauth.aud_certification_campaign.status` | MC-0032 | `campana_estado` |
| `bauth.aud_certification_review.decision` | MC-0034 | `revision_decision` |
| `bauth.auth_attempt_log.outcome` | MC-0059 | `auth.intento.resultado` |
| `bauth.auth_attempt_log_2026_07.outcome` | MC-0059 | `auth.intento.resultado` |
| `bauth.auth_attempt_log_2026_08.outcome` | MC-0059 | `auth.intento.resultado` |
| `bauth.auth_attempt_log_2026_09.outcome` | MC-0059 | `auth.intento.resultado` |
| `bauth.auth_compliance_map.coverage_level` | MC-0060 | `auth.cumplimiento.nivel_cobertura` |
| `bauth.auth_credential.loa_provided` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_credential.owner_type` | MC-0044 | `credencial_tipo_propietario` |
| `bauth.auth_credential.status` | MC-0062 | `auth.credencial.estado` |
| `bauth.auth_credential_fido2.attestation_fmt` | MC-0063 | `auth.fido2.formato_atestacion` |
| `bauth.auth_credential_secret.type` | MC-0064 | `auth.secreto.tipo` |
| `bauth.auth_credential_x509.origin` | MC-0065 | `auth.x509.origen` |
| `bauth.auth_crypto_algorithm.status` | MC-0066 | `auth.cripto.estado` |
| `bauth.auth_crypto_algorithm.type` | MC-0067 | `auth.cripto.tipo` |
| `bauth.auth_device.category` | MC-0068 | `auth.dispositivo.categoria` |
| `bauth.auth_device.osdp_version` | MC-0069 | `auth.dispositivo.version_osdp` |
| `bauth.auth_device.platform` | MC-0070 | `auth.dispositivo.plataforma` |
| `bauth.auth_device.status` | MC-0071 | `auth.dispositivo.estado` |
| `bauth.auth_device.trust_level` | MC-0072 | `auth.dispositivo.confianza` |
| `bauth.auth_device_credential_binding.binding_type` | MC-0073 | `auth.vinculo_disp.tipo_vinculo` |
| `bauth.auth_device_posture.compliance_status` | MC-0074 | `auth.postura_disp.cumplimiento` |
| `bauth.auth_device_posture.mdm_compliance` | MC-0075 | `auth.postura_disp.mdm` |
| `bauth.auth_device_posture.posture_source` | MC-0076 | `auth.postura_disp.fuente_postura` |
| `bauth.auth_federation_protocol.aal_max` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_federation_protocol.status` | MC-0077 | `auth.federacion.estado` |
| `bauth.auth_method.category` | MC-0078 | `auth.metodo.categoria` |
| `bauth.auth_method.loa_provided` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_method.status` | MC-0079 | `auth.metodo.estado` |
| `bauth.auth_policy.loa_required` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_saga_catalog.aal_produced` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_saga_catalog.aal_required` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.auth_saga_catalog.status` | MC-0080 | `auth.saga.estado` |
| `bauth.blk_account.status` | MC-0258 | `blk.cuenta.estado` |
| `bauth.blk_anchor.chain` | MC-0259 | `blk.ancla.cadena` |
| `bauth.blk_anchor.status` | MC-0260 | `blk.ancla.estado` |
| `bauth.blk_merkle_batch.status` | MC-0261 | `blk.merkle.estado` |
| `bauth.blk_reconciliation.status` | MC-0262 | `blk.reconciliacion.estado` |
| `bauth.cfg_policy_library.assurance_level` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.cfg_policy_library.auth_factor` | MC-0087 | `cfg.politica.factor_auth` |
| `bauth.cfg_policy_library.enforcement` | MC-0088 | `cfg.politica.aplicacion` |
| `bauth.cfg_policy_library.lifecycle` | MC-0089 | `cfg.politica.ciclo_vida` |
| `bauth.cfg_policy_library.node_type` | MC-0090 | `cfg.politica.tipo_nodo` |
| `bauth.cfg_policy_library.risk_level` | MC-0091 | `cfg.politica.nivel_riesgo` |
| `bauth.cfg_policy_library.semantic_type` | MC-0092 | `cfg.politica.tipo_semantico` |
| `bauth.fed_client.fapi_profile` | MC-0081 | `fed.cliente.perfil_fapi` |
| `bauth.fed_client.status` | MC-0082 | `fed.cliente.estado` |
| `bauth.fed_client.type` | MC-0083 | `fed.cliente.tipo` |
| `bauth.fed_provider_ext.fal` | MC-0084 | `fed.proveedor.nivel_fal` |
| `bauth.fed_provider_ext.protocol` | MC-0085 | `fed.proveedor.protocolo` |
| `bauth.fed_token_issued.loa_at_issuance` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.fed_token_issued.type` | MC-0086 | `fed.token.tipo` |
| `bauth.fed_token_issued_2026_07.loa_at_issuance` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.fed_token_issued_2026_07.type` | MC-0086 | `fed.token.tipo` |
| `bauth.fed_token_issued_2026_08.loa_at_issuance` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.fed_token_issued_2026_08.type` | MC-0086 | `fed.token.tipo` |
| `bauth.fed_token_issued_2026_09.loa_at_issuance` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.fed_token_issued_2026_09.type` | MC-0086 | `fed.token.tipo` |
| `bauth.idn_access_contract.access_type` | MC-0094 | `acceso.contrato.tipo_acceso` |
| `bauth.idn_access_contract.status` | MC-0095 | `acceso.contrato.estado` |
| `bauth.idn_attribute_schema.classification` | MC-0275 | `registry.attr_schema.clasificacion` |
| `bauth.idn_attribute_schema.data_type` | MC-0278 | `registry.attr_schema.tipo_dato` |
| `bauth.idn_attribute_schema.mutability` | MC-0276 | `registry.attr_schema.mutabilidad` |
| `bauth.idn_attribute_schema.returned` | MC-0277 | `registry.attr_schema.campo_retorno` |
| `bauth.idn_audit_event_log.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_audit_event_log.outcome` | MC-0180 | `d11.auditoria.resultado` |
| `bauth.idn_audit_event_log.subject_type` | MC-0181 | `d11.auditoria.tipo_sujeto` |
| `bauth.idn_audit_event_log_2026_07.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_audit_event_log_2026_07.outcome` | MC-0180 | `d11.auditoria.resultado` |
| `bauth.idn_audit_event_log_2026_07.subject_type` | MC-0181 | `d11.auditoria.tipo_sujeto` |
| `bauth.idn_audit_event_log_2026_08.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_audit_event_log_2026_08.outcome` | MC-0180 | `d11.auditoria.resultado` |
| `bauth.idn_audit_event_log_2026_08.subject_type` | MC-0181 | `d11.auditoria.tipo_sujeto` |
| `bauth.idn_audit_event_log_2026_09.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_audit_event_log_2026_09.outcome` | MC-0180 | `d11.auditoria.resultado` |
| `bauth.idn_audit_event_log_2026_09.subject_type` | MC-0181 | `d11.auditoria.tipo_sujeto` |
| `bauth.idn_audit_event_log_default.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_audit_event_log_default.outcome` | MC-0180 | `d11.auditoria.resultado` |
| `bauth.idn_audit_event_log_default.subject_type` | MC-0181 | `d11.auditoria.tipo_sujeto` |
| `bauth.idn_audit_retention_policy.expiration_action` | MC-0182 | `d11.retencion.accion_expiracion` |
| `bauth.idn_audit_siem_target.log_format` | MC-0183 | `d11.siem.formato_log` |
| `bauth.idn_audit_siem_target.protocol_type` | MC-0184 | `d11.siem.tipo_protocolo` |
| `bauth.idn_biometric_enrollment.biometric_type` | MC-0149 | `d05.inscripcion.tipo_biometrico` |
| `bauth.idn_biometric_enrollment.status` | MC-0150 | `d05.inscripcion.estado` |
| `bauth.idn_biometric_identification_log.result` | MC-0151 | `d05.identificacion.resultado` |
| `bauth.idn_biometric_identification_log_default.result` | MC-0151 | `d05.identificacion.resultado` |
| `bauth.idn_biometric_pad_policy.biometric_type` | MC-0149 | `d05.inscripcion.tipo_biometrico` |
| `bauth.idn_biometric_pad_policy.fail_action` | MC-0152 | `d05.pad.accion_fallo` |
| `bauth.idn_biometric_pad_policy.pad_level` | MC-0153 | `d05.pad.nivel_pad` |
| `bauth.idn_biometric_pad_policy.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_biometric_quality_policy.biometric_type` | MC-0149 | `d05.inscripcion.tipo_biometrico` |
| `bauth.idn_biometric_quality_policy.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_biometric_revocation.revocation_reason` | MC-0155 | `d05.revocacion_bio.motivo_revocacion` |
| `bauth.idn_biometric_verification_log.outcome` | MC-0156 | `d05.verificacion_bio.resultado` |
| `bauth.idn_biometric_verification_log_2026_07.outcome` | MC-0156 | `d05.verificacion_bio.resultado` |
| `bauth.idn_biometric_verification_log_2026_08.outcome` | MC-0156 | `d05.verificacion_bio.resultado` |
| `bauth.idn_biometric_verification_log_default.outcome` | MC-0156 | `d05.verificacion_bio.resultado` |
| `bauth.idn_blockchain_anchor_ext.source_event_type` | MC-0185 | `d12.ancla.tipo_evento_fuente` |
| `bauth.idn_blockchain_node.status` | MC-0186 | `d12.nodo.estado` |
| `bauth.idn_blockchain_transaction.status` | MC-0187 | `d12.transaccion.estado` |
| `bauth.idn_blockchain_transaction.tx_type` | MC-0188 | `d12.transaccion.tipo_tx` |
| `bauth.idn_blockchain_wallet.chain` | MC-0189 | `d12.wallet.cadena` |
| `bauth.idn_blockchain_wallet.status` | MC-0190 | `d12.wallet.estado` |
| `bauth.idn_credencial_revocacion.motivo` | MC-0172 | `d09.revocacion_cred.motivo` |
| `bauth.idn_credential_token_issued.revocation_reason` | MC-0173 | `d09.token.motivo_revocacion` |
| `bauth.idn_credential_token_issued.token_type` | MC-0174 | `d09.token.tipo_token` |
| `bauth.idn_credential_token_issued_2026_07.revocation_reason` | MC-0173 | `d09.token.motivo_revocacion` |
| `bauth.idn_credential_token_issued_2026_07.token_type` | MC-0174 | `d09.token.tipo_token` |
| `bauth.idn_credential_token_issued_2026_08.revocation_reason` | MC-0173 | `d09.token.motivo_revocacion` |
| `bauth.idn_credential_token_issued_2026_08.token_type` | MC-0174 | `d09.token.tipo_token` |
| `bauth.idn_credential_token_issued_2026_09.revocation_reason` | MC-0173 | `d09.token.motivo_revocacion` |
| `bauth.idn_credential_token_issued_2026_09.token_type` | MC-0174 | `d09.token.tipo_token` |
| `bauth.idn_credential_token_issued_default.revocation_reason` | MC-0173 | `d09.token.motivo_revocacion` |
| `bauth.idn_credential_token_issued_default.token_type` | MC-0174 | `d09.token.tipo_token` |
| `bauth.idn_delegation_grant.delegation_type` | MC-0175 | `d10.delegacion.tipo_delegacion` |
| `bauth.idn_delegation_grant.status` | MC-0150 | `d05.inscripcion.estado` |
| `bauth.idn_delegation_rar_request.status` | MC-0176 | `d10.rar.estado` |
| `bauth.idn_delegation_restriction.restriction_type` | MC-0177 | `d10.restriccion.tipo_restriccion` |
| `bauth.idn_delegation_usage_log.outcome` | MC-0178 | `d10.uso_delegacion.resultado` |
| `bauth.idn_delegation_usage_log_2026_07.outcome` | MC-0178 | `d10.uso_delegacion.resultado` |
| `bauth.idn_delegation_usage_log_2026_08.outcome` | MC-0178 | `d10.uso_delegacion.resultado` |
| `bauth.idn_delegation_usage_log_default.outcome` | MC-0178 | `d10.uso_delegacion.resultado` |
| `bauth.idn_did_document.status` | MC-0096 | `identidad.did.estado` |
| `bauth.idn_dpia_registro.estado` | MC-0284 | `privacidad.dpia_reg.estado` |
| `bauth.idn_dpia_registro.riesgo_residual` | MC-0285 | `privacidad.dpia_reg.riesgo_residual` |
| `bauth.idn_financial_approval.operation_type` | MC-0131 | `d03.aprobacion.tipo_operacion` |
| `bauth.idn_financial_approval.status` | MC-0046 | `propuesta_estado` |
| `bauth.idn_financial_approval_vote.decision` | MC-0132 | `d03.voto.decision` |
| `bauth.idn_financial_fraud_alert.alert_type` | MC-0133 | `d03.fraude.tipo_alerta` |
| `bauth.idn_financial_fraud_alert.result` | MC-0134 | `d03.fraude.resultado` |
| `bauth.idn_financial_invoice_auth.sin_status` | MC-0135 | `d03.factura.estado_sin` |
| `bauth.idn_financial_limit.operation_type` | MC-0136 | `d03.limite.tipo_operacion` |
| `bauth.idn_financial_limit.scope` | MC-0137 | `d03.limite.alcance` |
| `bauth.idn_financial_limit.status` | MC-0138 | `d03.limite.estado` |
| `bauth.idn_financial_reconciliation.reconciliation_type` | MC-0139 | `d03.reconciliacion.tipo_reconciliacion` |
| `bauth.idn_financial_reconciliation.status` | MC-0140 | `d03.reconciliacion.estado` |
| `bauth.idn_financial_report.report_type` | MC-0141 | `d03.reporte.tipo_reporte` |
| `bauth.idn_financial_report.status` | MC-0142 | `d03.reporte.estado` |
| `bauth.idn_financial_sod_rule.conflict_type` | MC-0143 | `d03.sod.tipo_conflicto` |
| `bauth.idn_financial_sod_rule.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_financial_tpp_consent.fapi_profile` | MC-0144 | `d03.tpp.perfil_fapi` |
| `bauth.idn_financial_tpp_consent.revoked_by` | MC-0145 | `d03.tpp.revocado_por` |
| `bauth.idn_geospatial_data_residency.apply_to` | MC-0157 | `d06.residencia.aplica_a` |
| `bauth.idn_geospatial_data_residency.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_geospatial_data_residency.violation_action` | MC-0158 | `d06.residencia.accion_violacion` |
| `bauth.idn_geospatial_geofence.action_inside` | MC-0159 | `d06.geocerca.accion_dentro` |
| `bauth.idn_geospatial_geofence.action_outside` | MC-0160 | `d06.geocerca.accion_fuera` |
| `bauth.idn_geospatial_geofence.fence_type` | MC-0161 | `d06.geocerca.tipo_geocerca` |
| `bauth.idn_geospatial_geofence.status` | MC-0138 | `d03.limite.estado` |
| `bauth.idn_geospatial_location_log.location_source` | MC-0162 | `d06.ubicacion.fuente_ubicacion` |
| `bauth.idn_geospatial_location_log_2026_07.location_source` | MC-0162 | `d06.ubicacion.fuente_ubicacion` |
| `bauth.idn_geospatial_location_log_2026_08.location_source` | MC-0162 | `d06.ubicacion.fuente_ubicacion` |
| `bauth.idn_geospatial_location_log_default.location_source` | MC-0162 | `d06.ubicacion.fuente_ubicacion` |
| `bauth.idn_geospatial_velocity_policy.action` | MC-0160 | `d06.geocerca.accion_fuera` |
| `bauth.idn_geospatial_velocity_policy.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_global_admin.admin_role` | MC-0222 | `d99.admin.rol_admin` |
| `bauth.idn_global_admin.status` | MC-0082 | `fed.cliente.estado` |
| `bauth.idn_global_compliance_control.status` | MC-0223 | `d99.cumplimiento.estado` |
| `bauth.idn_global_crypto_params.algorithm_family` | MC-0224 | `d99.cripto.familia_algoritmo` |
| `bauth.idn_global_hitl_exception.affected_entity_type` | MC-0225 | `d99.hitl.tipo_entidad` |
| `bauth.idn_global_hitl_exception.exception_type` | MC-0226 | `d99.hitl.tipo_excepcion` |
| `bauth.idn_global_hitl_exception.status` | MC-0227 | `d99.hitl.estado` |
| `bauth.idn_global_notification.notification_type` | MC-0228 | `d99.notificacion.tipo_notificacion` |
| `bauth.idn_global_notification.severity` | MC-0229 | `d99.notificacion.severidad` |
| `bauth.idn_global_notification.target_scope` | MC-0230 | `d99.notificacion.alcance_destino` |
| `bauth.idn_global_sbom.component_type` | MC-0231 | `d99.sbom.tipo_componente` |
| `bauth.idn_global_sbom.risk_level` | MC-0232 | `d99.sbom.nivel_riesgo` |
| `bauth.idn_identidad_lifecycle_event.event_type` | MC-0097 | `identidad.ciclo_vida.tipo_evento` |
| `bauth.idn_identity_attribute.classification` | MC-0275 | `registry.attr_schema.clasificacion` |
| `bauth.idn_identity_attribute.mutability` | MC-0098 | `identidad.atributo.mutabilidad` |
| `bauth.idn_identity_attribute.returned` | MC-0277 | `registry.attr_schema.campo_retorno` |
| `bauth.idn_identity_attribute.uniqueness` | MC-0099 | `identidad.atributo.unicidad` |
| `bauth.idn_identity_attribute_history.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_07.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_08.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_09.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_10.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_11.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_attribute_history_2026_12.operation` | MC-0100 | `identidad.attr_historial.operacion` |
| `bauth.idn_identity_consent.granted_via` | MC-0101 | `identidad.consentimiento.via_otorgamiento` |
| `bauth.idn_identity_consent.legal_basis` | MC-0102 | `identidad.consentimiento.base_legal` |
| `bauth.idn_identity_consent.withdrawn_via` | MC-0103 | `identidad.consentimiento.via_retiro` |
| `bauth.idn_identity_entity.ial_min` | MC-0017 | `nivel_ial` |
| `bauth.idn_identity_entity.level` | MC-0016 | `entidad_nivel` |
| `bauth.idn_identity_entity.status` | MC-0104 | `identidad.entidad.estado` |
| `bauth.idn_identity_proofing.eidas_level` | MC-0105 | `identidad.proofing.nivel_eidas` |
| `bauth.idn_identity_proofing.ial_achieved` | MC-0017 | `nivel_ial` |
| `bauth.idn_identity_proofing.proofing_type` | MC-0107 | `identidad.proofing.tipo_proofing` |
| `bauth.idn_identity_proofing.status` | MC-0106 | `identidad.proofing.estado` |
| `bauth.idn_identity_requirement.entity_type` | MC-0016 | `entidad_nivel` |
| `bauth.idn_identity_vc.eidas_assurance_level` | MC-0105 | `identidad.proofing.nivel_eidas` |
| `bauth.idn_identity_vc.eidas_vc_type` | MC-0108 | `identidad.vc.tipo_vc_eidas` |
| `bauth.idn_identity_vc.status` | MC-0150 | `d05.inscripcion.estado` |
| `bauth.idn_identity_vc.vc_format` | MC-0109 | `identidad.vc.formato_vc` |
| `bauth.idn_network_connection_policy.min_tls_version` | MC-0163 | `d07.conexion.version_tls` |
| `bauth.idn_network_connection_policy.status` | MC-0138 | `d03.limite.estado` |
| `bauth.idn_network_context_propagation.propagation_format` | MC-0164 | `d07.propagacion.formato_propagacion` |
| `bauth.idn_network_context_propagation.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_network_dlp_policy.action_on_match` | MC-0165 | `d07.dlp.accion_deteccion` |
| `bauth.idn_network_dlp_policy.status` | MC-0138 | `d03.limite.estado` |
| `bauth.idn_network_dpop_binding.alg` | MC-0166 | `d07.dpop.algoritmo` |
| `bauth.idn_network_posture_policy.action_on_fail` | MC-0167 | `d07.postura_red.accion_fallo` |
| `bauth.idn_network_posture_policy.status` | MC-0138 | `d03.limite.estado` |
| `bauth.idn_network_rate_policy.action_on_exceed` | MC-0168 | `d07.tasa_limite.accion_exceso` |
| `bauth.idn_network_rate_policy.scope` | MC-0169 | `d07.tasa_limite.alcance` |
| `bauth.idn_network_rate_policy.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_network_segment.segment_type` | MC-0170 | `d07.segmento.tipo_segmento` |
| `bauth.idn_network_segment.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_network_segment.trust_level` | MC-0171 | `d07.segmento.confianza` |
| `bauth.idn_nhi_identity.nhi_type` | MC-0039 | `nhi_tipo` |
| `bauth.idn_nhi_identity.status` | MC-0038 | `nhi_estado` |
| `bauth.idn_nhi_rotation_policy.fail_action` | MC-0213 | `d15.nhi_rotacion.accion_fallo` |
| `bauth.idn_nhi_rotation_policy.nhi_type` | MC-0214 | `d15.nhi_rotacion.tipo_nhi` |
| `bauth.idn_nhi_rotation_policy.status` | MC-0154 | `d05.pad.estado` |
| `bauth.idn_nhi_svid.status` | MC-0215 | `d15.svid.estado` |
| `bauth.idn_nhi_svid.svid_type` | MC-0216 | `d15.svid.tipo_svid` |
| `bauth.idn_physical_access_credential.credential_type` | MC-0118 | `d02.credencial_fisica.tipo_credencial` |
| `bauth.idn_physical_access_credential.status` | MC-0150 | `d05.inscripcion.estado` |
| `bauth.idn_physical_access_emergency.door_mode` | MC-0119 | `d02.emergencia.modo_puerta` |
| `bauth.idn_physical_access_emergency.emergency_type` | MC-0120 | `d02.emergencia.tipo_emergencia` |
| `bauth.idn_physical_access_event_log.credential_type` | MC-0121 | `d02.evento_fisico.tipo_credencial` |
| `bauth.idn_physical_access_event_log.event_type` | MC-0122 | `d02.evento_fisico.tipo_evento` |
| `bauth.idn_physical_access_event_log.outcome` | MC-0123 | `d02.evento_fisico.resultado` |
| `bauth.idn_physical_access_event_log_2026_07.credential_type` | MC-0121 | `d02.evento_fisico.tipo_credencial` |
| `bauth.idn_physical_access_event_log_2026_07.event_type` | MC-0122 | `d02.evento_fisico.tipo_evento` |
| `bauth.idn_physical_access_event_log_2026_07.outcome` | MC-0123 | `d02.evento_fisico.resultado` |
| `bauth.idn_physical_access_event_log_2026_08.credential_type` | MC-0121 | `d02.evento_fisico.tipo_credencial` |
| `bauth.idn_physical_access_event_log_2026_08.event_type` | MC-0122 | `d02.evento_fisico.tipo_evento` |
| `bauth.idn_physical_access_event_log_2026_08.outcome` | MC-0123 | `d02.evento_fisico.resultado` |
| `bauth.idn_physical_access_event_log_default.credential_type` | MC-0121 | `d02.evento_fisico.tipo_credencial` |
| `bauth.idn_physical_access_event_log_default.event_type` | MC-0122 | `d02.evento_fisico.tipo_evento` |
| `bauth.idn_physical_access_event_log_default.outcome` | MC-0123 | `d02.evento_fisico.resultado` |
| `bauth.idn_physical_access_location.location_type` | MC-0124 | `d02.ubicacion_fisica.tipo_ubicacion` |
| `bauth.idn_physical_access_location.status` | MC-0125 | `d02.ubicacion_fisica.estado` |
| `bauth.idn_physical_access_reader.direction` | MC-0126 | `d02.lector.direccion` |
| `bauth.idn_physical_access_reader.protocol` | MC-0127 | `d02.lector.protocolo` |
| `bauth.idn_physical_access_reader.reader_type` | MC-0128 | `d02.lector.tipo_lector` |
| `bauth.idn_physical_access_reader.status` | MC-0129 | `d02.lector.estado` |
| `bauth.idn_physical_access_visit.status` | MC-0130 | `d02.visita.estado` |
| `bauth.idn_policy_node_type.font_size_token` | MC-0093 | `cfg.nodo_politica.tamano_fuente` |
| `bauth.idn_registry_atom_catalog.domain_code` | MC-0179 | `d11.auditoria.codigo_dominio` |
| `bauth.idn_registry_attribute_schema.category` | MC-0279 | `registry.schema_attr.categoria` |
| `bauth.idn_registry_attribute_schema.classification` | MC-0280 | `registry.schema_attr.clasificacion` |
| `bauth.idn_registry_attribute_schema.data_type` | MC-0281 | `registry.schema_attr.tipo_dato` |
| `bauth.idn_registry_attribute_schema.mutability` | MC-0282 | `registry.schema_attr.mutabilidad` |
| `bauth.idn_registry_attribute_schema.returned` | MC-0277 | `registry.attr_schema.campo_retorno` |
| `bauth.idn_registry_attribute_schema.source` | MC-0283 | `registry.schema_attr.fuente` |
| `bauth.idn_roles_nhi_agent_identity.session_type` | MC-0217 | `d15.nhi_agente.tipo_sesion` |
| `bauth.idn_roles_nhi_certification.decision` | MC-0040 | `nhi_decision_cert` |
| `bauth.idn_roles_nhi_identity.nhi_type` | MC-0220 | `d15.nhi_identidad.tipo_nhi` |
| `bauth.idn_roles_nhi_identity.status` | MC-0219 | `d15.nhi_identidad.estado` |
| `bauth.idn_roles_nhi_lifecycle_event.event_type` | MC-0041 | `nhi_tipo_evento` |
| `bauth.idn_roles_rol_hierarchical.change_channel` | MC-0001 | `ver_canal` |
| `bauth.idn_roles_rol_hierarchical.risk_classification` | MC-0028 | `nivel_riesgo` |
| `bauth.idn_roles_rol_hierarchical.sensitivity_label` | MC-0027 | `etiqueta_sensibilidad` |
| `bauth.idn_roles_rol_hierarchical.status` | MC-0024 | `rol_estado` |
| `bauth.idn_roles_rol_hierarchical.tier` | MC-0025 | `rol_tier` |
| `bauth.idn_roles_rol_hierarchical.validity_type` | MC-0005 | `rol_vigencia` |
| `bauth.idn_roles_rol_lifecycle_event.trigger_type` | MC-0271 | `rol.ciclo_vida.tipo_disparador` |
| `bauth.idn_roles_template.account_type` | MC-0026 | `rol_tipo_cuenta` |
| `bauth.idn_roles_template_history.operation` | MC-0272 | `rol.template.operacion` |
| `bauth.idn_roles_ver_b01_audit_log.change_channel` | MC-0001 | `ver_canal` |
| `bauth.idn_roles_ver_b01_audit_log.change_type` | MC-0004 | `ver_tipo_cambio` |
| `bauth.idn_roles_ver_b01_retention_policy.compaction_policy` | MC-0002 | `ver_compactacion` |
| `bauth.idn_roles_ver_b01_retention_policy.info_class` | MC-0273 | `rol.ver_retencion.clase_info` |
| `bauth.idn_roles_ver_b03_approval_queue.status` | MC-0003 | `ver_estado_propuesta` |
| `bauth.idn_roles_ver_contract_revision_log.compatibility` | MC-0274 | `rol.ver_contrato.compatibilidad` |
| `bauth.idn_scim_attribute_map.local_table` | MC-0117 | `scim.mapeo_attr.tabla_local` |
| `bauth.idn_scim_attribute_map.scim_mutability` | MC-0114 | `scim.mapeo_attr.mutabilidad_scim` |
| `bauth.idn_scim_attribute_map.scim_resource` | MC-0115 | `scim.mapeo_attr.recurso_scim` |
| `bauth.idn_scim_attribute_map.scim_returned` | MC-0116 | `scim.mapeo_attr.retorno_scim` |
| `bauth.idn_signature_ca_chain.ca_type` | MC-0191 | `d13.cadena_ca.tipo_ca` |
| `bauth.idn_signature_eudi_wallet.status` | MC-0192 | `d13.eudi_wallet.estado` |
| `bauth.idn_signature_request.document_type` | MC-0193 | `d13.solicitud_firma.tipo_documento` |
| `bauth.idn_signature_request.engine` | MC-0194 | `d13.solicitud_firma.motor` |
| `bauth.idn_signature_request.signature_format` | MC-0195 | `d13.solicitud_firma.formato_firma` |
| `bauth.idn_signature_request.status` | MC-0196 | `d13.solicitud_firma.estado` |
| `bauth.idn_signature_revocation_cache.check_source` | MC-0197 | `d13.revocacion_cert.fuente_verificacion` |
| `bauth.idn_signature_revocation_cache.status` | MC-0198 | `d13.revocacion_cert.estado` |
| `bauth.idn_signature_verification_log.cert_status` | MC-0199 | `d13.verificacion_firma.estado_cert` |
| `bauth.idn_signature_verification_log.outcome` | MC-0200 | `d13.verificacion_firma.resultado` |
| `bauth.idn_temporal_exception.exception_type` | MC-0146 | `d04.excepcion_temp.tipo_excepcion` |
| `bauth.idn_temporal_shift.rotation_type` | MC-0147 | `d04.turno.tipo_rotacion` |
| `bauth.idn_temporal_window.window_type` | MC-0148 | `d04.ventana_temporal.tipo_ventana` |
| `bauth.idn_tenant.audit_level` | MC-0006 | `nivel_auditoria` |
| `bauth.idn_tenant.isolation_level` | MC-0007 | `nivel_aislamiento` |
| `bauth.idn_tenant.plan_tier` | MC-0008 | `plan_nivel` |
| `bauth.idn_tenant.provisioning_status` | MC-0012 | `tenant_estado_provisionamiento` |
| `bauth.idn_tenant.status` | MC-0010 | `tenant_estado` |
| `bauth.idn_tenant.subscription_status` | MC-0009 | `suscripcion_estado` |
| `bauth.idn_tenant.tenant_type` | MC-0011 | `tenant_tipo` |
| `bauth.idn_tenant_calendar_assignment.owner_type` | MC-0052 | `calendario_tipo_propietario` |
| `bauth.idn_tenant_calendar_assignment.role` | MC-0051 | `calendario_rol` |
| `bauth.idn_tenant_domain.deploy_status` | MC-0013 | `dominio_estado` |
| `bauth.idn_tenant_domain.domain_type` | MC-0014 | `dominio_tipo` |
| `bauth.idn_tenant_domain.health_status` | MC-0013 | `dominio_estado` |
| `bauth.idn_tenant_fal_config.fal_level` | MC-0084 | `fed.proveedor.nivel_fal` |
| `bauth.idn_tenant_languages.translation_status` | MC-0023 | `traduccion_estado` |
| `bauth.idn_tenant_network.network_type` | MC-0015 | `red_tipo` |
| `bauth.idn_tenant_verification.status` | MC-0018 | `verificacion_estado` |
| `bauth.idn_tenant_verification.step` | MC-0019 | `verificacion_paso` |
| `bauth.idn_user.loa_min` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.idn_user.registration_method` | MC-0110 | `identidad.usuario.metodo_registro` |
| `bauth.idn_user.status` | MC-0111 | `identidad.usuario.estado` |
| `bauth.idn_user_recovery.status` | MC-0112 | `identidad.recuperacion.estado` |
| `bauth.idn_user_recovery.type` | MC-0113 | `identidad.recuperacion.tipo` |
| `bauth.pam_breakglass_activation.auth_method` | MC-0201 | `d14.breakglass.metodo_auth` |
| `bauth.pam_breakglass_activation.status` | MC-0035 | `estado_breakglass` |
| `bauth.pam_credential_ref.credential_type` | MC-0045 | `credencial_tipo_ref` |
| `bauth.pam_credential_ref.rotation_policy` | MC-0204 | `d14.credencial_priv.politica_rotacion` |
| `bauth.pam_credential_ref.status` | MC-0205 | `d14.credencial_priv.estado` |
| `bauth.pam_cuenta_privilegiada.access_type` | MC-0037 | `pam_tipo_acceso` |
| `bauth.pam_cuenta_privilegiada.estado` | MC-0207 | `d14.cuenta_priv.estado` |
| `bauth.pam_cuenta_privilegiada.tipo` | MC-0208 | `d14.cuenta_priv.tipo` |
| `bauth.pam_jit_approval.decision` | MC-0209 | `d14.jit.decision` |
| `bauth.pam_jit_request.status` | MC-0036 | `jit_estado` |
| `bauth.pam_nhi_secret_ref.rotation_policy` | MC-0210 | `d14.nhi_secreto.politica_rotacion` |
| `bauth.pam_nhi_secret_ref.secret_type` | MC-0206 | `d14.credencial_priv.tipo_credencial` |
| `bauth.pam_nhi_secret_ref.status` | MC-0205 | `d14.credencial_priv.estado` |
| `bauth.pam_session_record.status` | MC-0211 | `d14.sesion_priv.estado` |
| `bauth.pam_session_recording.storage_type` | MC-0212 | `d14.grabacion.storage.type` |
| `bauth.privilege_assurance_audit.outcome` | MC-0233 | `priv.aseguramiento.resultado` |
| `bauth.privilege_assurance_audit.presented_loa` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.privilege_assurance_audit.required_loa` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.privilege_atom_audit.operation` | MC-0234 | `priv.atom.operacion` |
| `bauth.privilege_atom_audit_2026_07.operation` | MC-0234 | `priv.atom.operacion` |
| `bauth.privilege_atom_audit_2026_08.operation` | MC-0234 | `priv.atom.operacion` |
| `bauth.privilege_atom_audit_2026_09.operation` | MC-0234 | `priv.atom.operacion` |
| `bauth.privilege_atom_grant.grant_type` | MC-0030 | `grant_tipo` |
| `bauth.privilege_atom_grant.status` | MC-0029 | `grant_estado` |
| `bauth.privilege_delegation.status` | MC-0235 | `priv.delegacion.estado` |
| `bauth.privilege_exception_record.exception_type` | MC-0236 | `priv.excepcion_reg.tipo_excepcion` |
| `bauth.privilege_exception_record.status` | MC-0235 | `priv.delegacion.estado` |
| `bauth.privilege_override.override_type` | MC-0237 | `priv.anulacion.tipo_anulacion` |
| `bauth.privilege_override.status` | MC-0235 | `priv.delegacion.estado` |
| `bauth.privilege_resource_atom.?` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.privilege_resource_atom.evaluation_path` | MC-0238 | `priv.recurso.ruta_eval` |
| `bauth.privilege_resource_atom.protocol_type` | MC-0241 | `priv.recurso.tipo_protocolo` |
| `bauth.privilege_resource_atom.status` | MC-0239 | `priv.recurso.estado` |
| `bauth.privilege_resource_atom.tenant_scope` | MC-0240 | `priv.recurso.alcance_tenant` |
| `bauth.privilege_verb_conflict.conflict_type` | MC-0242 | `priv.verbo_conflicto.tipo_conflicto` |
| `bauth.ses_caep_event_log.event_type` | MC-0042 | `caep_tipo_evento` |
| `bauth.ses_caep_event_log.proc_status` | MC-0043 | `caep_estado_proceso` |
| `bauth.ses_caep_event_log.subject_type` | MC-0244 | `ses.caep.tipo_sujeto` |
| `bauth.ses_risk_policy.action_on_trigger` | MC-0047 | `riesgo_accion` |
| `bauth.ses_risk_policy.trigger_event` | MC-0243 | `ses.caep.tipo_evento` |
| `bauth.ses_session_log.loa_initial` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.ses_session_log.loa_peak` | MC-0061 | `auth.credencial.nivel_aal` |
| `bauth.ses_session_log.termination_reason` | MC-0245 | `ses.sesion.motivo_fin` |
| `bauth.ses_ssf_delivery_log.delivery_status` | MC-0058 | `ssf_estado_entrega` |
| `bauth.ses_ssf_stream.delivery_method` | MC-0057 | `ssf_metodo_entrega` |
| `bauth.ses_ssf_stream.status` | MC-0246 | `ses.ssf.estado` |
| `bauth.sig_adsib_lifecycle.event` | MC-0247 | `sig.adsib_ciclo.event` |
| `bauth.sig_certificate.adsib_type` | MC-0248 | `sig.certificado.tipo_adsib` |
| `bauth.sig_certificate.engine` | MC-0249 | `sig.certificado.motor` |
| `bauth.sig_certificate.status` | MC-0150 | `d05.inscripcion.estado` |
| `bauth.sig_crl.engine` | MC-0250 | `sig.crl.motor` |
| `bauth.sig_document_policy.engine_required` | MC-0251 | `sig.doc_politica.engine.required` |
| `bauth.sig_document_policy.external_profile` | MC-0252 | `sig.doc_politica.external.profile` |
| `bauth.sig_document_policy.internal_profile` | MC-0253 | `sig.doc_politica.internal.profile` |
| `bauth.sig_key.engine` | MC-0250 | `sig.crl.motor` |
| `bauth.sig_key.purpose` | MC-0254 | `sig.llave.purpose` |
| `bauth.sig_key.status` | MC-0255 | `sig.llave.estado` |
| `bauth.sig_operation_log.engine` | MC-0250 | `sig.crl.motor` |
| `bauth.sig_operation_log.outcome` | MC-0256 | `sig.operacion.resultado` |
| `bauth.sig_operation_log.signer_type` | MC-0257 | `sig.operacion.tipo_firmante` |
| `bauth.wallet.backup_method` | MC-0263 | `vc.wallet.metodo_respaldo` |
| `bauth.wallet.status` | MC-0264 | `vc.wallet.estado` |
| `bauth.wallet_issuance_log.outcome` | MC-0265 | `vc.emision.resultado` |
| `bauth.wallet_issuance_log.protocol` | MC-0266 | `vc.emision.protocolo` |
| `bauth.wallet_item.status` | MC-0267 | `vc.item.estado` |
| `bauth.wallet_item.type` | MC-0268 | `vc.item.tipo` |
| `bauth.wallet_presentation_log.outcome` | MC-0269 | `vc.presentacion.resultado` |
| `bauth.wallet_presentation_log.protocol` | MC-0270 | `vc.presentacion.protocolo` |
| `bauth.wallet_presentation_log_2026_07.outcome` | MC-0269 | `vc.presentacion.resultado` |
| `bauth.wallet_presentation_log_2026_07.protocol` | MC-0270 | `vc.presentacion.protocolo` |
| `bauth.wallet_presentation_log_2026_08.outcome` | MC-0269 | `vc.presentacion.resultado` |
| `bauth.wallet_presentation_log_2026_08.protocol` | MC-0270 | `vc.presentacion.protocolo` |
| `bcalendar.cal_alarm.channel` | MC-0055 | `canal_alarma` |
| `bcalendar.cal_calendar.calendar_type` | MC-0050 | `tipo_calendario` |
| `bcalendar.cal_fiscal_year.status` | MC-0053 | `anio_fiscal_estado` |
| `bcalendar.cal_notification_log.channel` | MC-0055 | `canal_alarma` |
| `bcalendar.cal_schedule.status` | MC-0054 | `horario_estado` |
| `bglobal.global_config.scope` | MC-0048 | `param_global_alcance` |
| `bglobal.global_config.value_type` | MC-0049 | `param_global_tipo` |
| `bglobal.global_language.direction` | MC-0022 | `idioma_direccion` |
| `bglobal.global_language.language_type` | MC-0021 | `idioma_tipo` |
| `bglobal.global_language.scope` | MC-0020 | `idioma_alcance` |
| `bglobal.menu_context.menu_type` | MC-0056 | `menu_tipo` |
| `bglobal.menu_item_atom.required_effect` | MC-0286 | `menu.atom.efecto_requerido` |
| `bos.cap_sistema_snapshot.scope` | MC-0287 | `bos.snapshot.alcance` |
| `bos.cap_sistema_snapshot_2026_07.scope` | MC-0287 | `bos.snapshot.alcance` |
| `bos.cap_tenant_policy.policy_mode` | MC-0288 | `bos.tenant_politica.modo_politica` |
| `bos.ctx_context_audit.old_state` | MC-0290 | `bos.audit.estado_anterior` |
| `bos.ctx_context_audit.operation` | MC-0289 | `bos.audit.operacion` |
| `bos.ctx_context_emergency.review_outcome` | MC-0291 | `bos.emergencia.resultado_revision` |
| `bos.ctx_context_emergency.state` | MC-0292 | `bos.emergencia.estado` |
| `bos.ctx_context_session.state` | MC-0290 | `bos.audit.estado_anterior` |
| `bos.ctx_context_transfer.transfer_type` | MC-0293 | `bos.transferencia.tipo_transferencia` |
| `bos.ctx_registered_device.state` | MC-0290 | `bos.audit.estado_anterior` |
| `bos.fch_ficha_event.result` | MC-0294 | `bos.ficha_evento.resultado` |
| `bos.fch_ficha_state.backend` | MC-0295 | `bos.ficha_estado.backend` |
| `bos.fch_ficha_state.state` | MC-0296 | `bos.ficha_estado.estado` |
| `bos.ins_bootstrap_event.result` | MC-0294 | `bos.ficha_evento.resultado` |
| `bos.ins_bootstrap_event.state` | MC-0297 | `bos.bootstrap.estado` |
| `bos.ins_saga_execution.saga_type` | MC-0299 | `bos.saga.tipo_saga` |
| `bos.ins_saga_execution.state` | MC-0298 | `bos.saga.estado` |
| `bos.net_cert_inventory.cert_type` | MC-0300 | `bos.inventario_cert.tipo_cert` |
| `bos.net_cert_inventory.issuer_engine` | MC-0301 | `bos.inventario_cert.motor_emisor` |
| `bos.net_cert_inventory.key_algorithm` | MC-0302 | `bos.inventario_cert.algoritmo_llave` |
| `bos.net_cert_inventory.status` | MC-0303 | `bos.inventario_cert.estado` |
| `bos.net_security_events.event_type` | MC-0306 | `bos.evento_seg.tipo_evento` |
| `bos.net_security_events.severity` | MC-0304 | `bos.evento_seg.severidad` |
| `bos.net_security_events.source` | MC-0305 | `bos.evento_seg.fuente` |
| `bos.net_security_events_default.event_type` | MC-0306 | `bos.evento_seg.tipo_evento` |
| `bos.net_security_events_default.severity` | MC-0304 | `bos.evento_seg.severidad` |
| `bos.net_security_events_default.source` | MC-0305 | `bos.evento_seg.fuente` |
| `bos.prt_port_assignment.asset_type` | MC-0307 | `bos.puerto.tipo_activo` |
| `bos.prt_port_assignment.port_type` | MC-0308 | `bos.puerto.tipo_puerto` |
| `bos.prt_port_assignment.status` | MC-0309 | `bos.puerto.estado` |
| `bos.prt_port_assignment.transport` | MC-0310 | `bos.puerto.transporte` |
| `bos.rel_release_event.channel` | MC-0311 | `bos.release.channel` |
| `bos.rel_release_event.operation` | MC-0312 | `bos.release.operacion` |
| `bos.rel_release_event.result` | MC-0313 | `bos.release.resultado` |
| `bos.rel_release_event.triggered_by` | MC-0314 | `bos.release.disparado_por` |
| `bos.rel_release_manifest.channel` | MC-0311 | `bos.release.channel` |
| `bos.wdg_watchdog_event.action_result` | MC-0318 | `bos.watchdog.resultado_accion` |
| `bos.wdg_watchdog_event.action_taken` | MC-0315 | `bos.watchdog.accion_tomada` |
| `bos.wdg_watchdog_event.check_layer` | MC-0316 | `bos.watchdog.capa_verificacion` |
| `bos.wdg_watchdog_event.resource_type` | MC-0317 | `bos.watchdog.tipo_recurso` |
| `bos.wdg_watchdog_event.severity` | MC-0319 | `bos.watchdog.severidad` |

---

## Estadísticas

| Concepto | Cantidad |
|----------|----------|
| ENUMs formales (PARTE A) | 58 |
| CHECKs implícitos (PARTE B) | 261 |
| **Total menús MC** | **319** |
| Columnas mapeadas (índice inverso) | 433 |
| Tablas sin T-code (pendiente A.65.02) | ~12 (`—` en T-ref) |

---
*Generado automáticamente desde `pg_catalog.pg_enum` y `pg_catalog.pg_constraint` de SBOSDB.*
*Seeds: `bglobal_T060__menu_context.sql` (ENUMs) · `bglobal_T061__menu_context_checks.sql` (CHECKs)*
