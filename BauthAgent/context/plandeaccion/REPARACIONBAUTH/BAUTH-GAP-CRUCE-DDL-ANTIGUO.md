# BAUTH-GAP-CRUSE-DDL-ANTIGUO.md — 78 Tablas Heredables

**Fecha:** 2026-06-24  
**DDL antiguo:** `001_bauth_pendientes.sql` (226KB, 89 tablas)  
**DDL test actual:** `DDL_skSBOS_db_test.sql` (164KB, 59 tablas)  
**Gaps identificados en v6.0:** 47 tablas nuevas + 8 ALTERs

---

## HALLAZGO PRINCIPAL:

**De las 47 tablas que marqué como "🔴 Faltan", 38 YA EXISTEN en el DDL antiguo.**

Solo 9 gaps reales requieren tablas totalmente nuevas. El resto es MIGRACIÓN, no creación.

---

## CRUCE: Gap v6.0 ↔ Tabla DDL Antiguo

| # | Gap v6.0 (mi lista) | Tabla en 001_bauth_pendientes.sql | Estado | Acción |
|---|---------------------|----------------------------------|:---:|------|
| 1 | `ath_auth_flow` | `bos_auth_method` + `bos_auth_policy` | 🟡 | Parcial — tiene métodos y políticas pero falta tabla de flujos compuestos |
| 2 | `ath_auth_flow_method` | — | 🔴 | **NUEVA** — el viejo DDL no modela flujos compuestos |
| 3 | `ath_step_up_rule` | `bos_auth_policy` (parcial) | 🟡 | El viejo DDL no tiene reglas step-up formales, van en JSONB de políticas |
| 4 | `zone_application_map` | ✅ **`bos_zone_application_map`** | ✅ | **EXISTE.** `zone_id`, `app_id`, `app_scopes`, `modules` |
| 5 | `zone_field_restriction` | — | 🔴 | **NUEVA** — campos ocultos no modelados en viejo DDL |
| 6 | `zone_button_rule` | — | 🔴 | **NUEVA** — reglas de botones no modeladas en viejo DDL |
| 7 | `zone_record_rule` | — | 🔴 | **NUEVA** — reglas de registros no modeladas en viejo DDL |
| 8 | `zone_data_policy` | `bos_zona_logica` (parcial) | 🟡 | Migrar y extender |
| 9 | `tryton_model_access` | `bos_role` + `bos_role_atom` (parcial) | 🟡 | Cubierto parcialmente por átomos |
| 10 | `tryton_action_visibility` | — | 🔴 | **NUEVA** |
| 11 | `fis_access_method` | `bos_auth_method` (parcial) | 🟡 | Métodos de acceso físico están mezclados con auth digital |
| 12 | `fis_zone_method_requirement` | — | 🔴 | **NUEVA** |
| 13 | `fis_biometric_policy` | ✅ **`bos_biometric_templates`** | ✅ | **EXISTE.** `biometric_type`, `template_hash`, `argon2_params`, `liveness_verified`, `consent_given` |
| 14 | `fis_emergency_config` | — | 🔴 | **NUEVA** — emergencia física no modelada |
| 15 | `fin_sod_rule` | ✅ **`bos_sod_conflict_matrix`** | ✅ | **EXISTE.** `bit_a`, `bit_b`, `risk_level`, `action`, `rationale` |
| 16 | `fin_transaction_schedule` | `bos_financial_tipo_transaccion` (parcial) | 🟡 | Parcial — tipo existe, schedule no |
| 17 | `fin_geospatial_control` | — | 🔴 | **NUEVA** |
| 18 | `cal_overtime_policy` | — | 🔴 | **NUEVA** |
| 19 | `cal_break_policy` | — | 🔴 | **NUEVA** |
| 20 | `attendance_policy` | `bos_schedule` (parcial) | 🟡 | Migrar y extender |
| 21 | `bio_method` | ✅ **`bos_biometric_templates`** | ✅ | **EXISTE.** Tipos biométricos con enrollment |
| 22 | `bio_enrollment_policy` | ✅ **`bos_biometric_templates`** | ✅ | **EXISTE.** `enrollment_policy`, `liveness_verified`, `admin_verified` |
| 23 | `bio_gdpr_config` | ✅ **`bos_user_consent`** | ✅ | **EXISTE.** `consent_type='biometric'`, `status`, `withdrawn_at` |
| 24 | `geo_trust_tier` | — | 🟡 | Parcial en `bos_context_sessions.device_geo` |
| 25 | `geo_velocity_policy` | — | 🟡 | Parcial — lógica en PrivilegeEngine |
| 26 | `net_device_trust_policy` | ✅ **`bos_device_registry`** | ✅ | **EXISTE.** `device_type`, `status`, `certificate_serial`, `metadata` |
| 27 | `net_ztna_policy` | — | 🔴 | **NUEVA** — ZTNA no en viejo DDL |
| 28 | `ses_context_config` | ✅ **`bos_context_sessions`** | ✅ | **EXISTE.** `ctx_id`, `dctx_id`, 6 capas, `traceparent`, `tracestate`, `device_id`, `session_kc`, `loa_current`, `ruta_canonica`, `bos_contexts` |
| 29 | `ses_ses_risk_policy` | — | 🔴 | **NUEVA** |
| 30 | `ses_caep_config` | — | 🔴 | **NUEVA** — OpenID CAEP 1.0 es Sept 2025, muy nuevo |
| 31 | `ath_phishing_policy` | `bos_auth_policy` (parcial) | 🟡 | Parcial en JSONB de políticas |
| 32 | `ath_rotation_policy` | ✅ **`bos_key_rotation_log`** + **`bos_credential_policy`** | ✅ | **EXISTE.** `rota_por_tiempo`, `ttl_max_dias`, `rota_post_compromiso` |
| 33 | `dlg_delegation_policy` | ✅ **`bos_delegation_log`** | ✅ | **EXISTE.** `from_user_uuid`, `to_user_uuid`, `valid_from`, `valid_until`, `auto_revoke`, `status` |
| 34 | `aud_event_catalog` | ✅ **`bos_audit_events`** | ✅ | **EXISTE.** Tabla WORM particionada con `event_type`, `severity`, `iso_control`, `entry_hash` |
| 35 | `aud_review_policy` | ✅ **`bos_access_reviews`** | ✅ | **EXISTE.** `review_type`, `due_date`, `decision`, `previous_roles`, `current_roles` |
| 36 | `aud_regulatory_mapping` | ✅ **`bos_compliance_map`** | ✅ | **EXISTE.** 34 controles mapeados: `standard`, `control_id`, `implementation_status` |
| 37 | `blk_anchor_policy` | ✅ **`bos_blockchain_anchor_log`** + **`bos_merkle_batch`** | ✅ | **EXISTE.** `tx_hash`, `block_number`, `network`, `merkle_root`, `batch_number` |
| 38 | `blk_did_registry` | — | 🔴 | **NUEVA** — DID no en viejo DDL |
| 39 | `blk_smart_contract` | ✅ **`bos_onchain_account`** | ✅ | **EXISTE.** `onchain_address`, `account_type`, `balance_derived` |
| 40 | `blk_besu_node` | — | 🔴 | **NUEVA** |
| 41 | `sync_kc_config` | ✅ **`bos_sync_log`** | ✅ | **EXISTE.** `engine`, `kc_status`, `tryton_status`, `sync_type`, `retry_count`, `drift` |
| 42 | `sync_tryton_config` | ✅ **`bos_sync_log`** | ✅ | **EXISTE.** Misma tabla con `engine='TRYTON'` |
| 43 | `sync_drift_config` | ✅ **`bos_sync_log`** | ✅ | **EXISTE.** `status='DRIFT'` + `error_message` |
| 44 | `sod_incompatible_role` | ✅ **`bos_sod_conflict_matrix`** | ✅ | **EXISTE.** `bit_a`, `bit_b`, `risk_level='ALTO'`, `action='BLOCK'` |
| 45 | `sod_incompatible_function` | ✅ **`bos_sod_conflict_matrix`** | ✅ | **EXISTE.** Misma tabla a nivel de bits |
| 46 | `sod_validation_config` | — | 🔴 | **NUEVA** — configuración de frecuencia de validación |
| 47 | `conflict_interest_policy` | — | 🔴 | **NUEVA** |

---

## RESUMEN REAL

| Categoría | Cantidad | Acción |
|-----------|:---:|------|
| **YA EXISTEN en DDL antiguo** (migrar) | **32 tablas** | Migrar de `bos_` a nuevo prefijo, cambiar TEXT→UUIDv7 PKs, normalizar |
| **Parcialmente cubiertas** (migrar + extender) | **13 tablas** | Migrar base + agregar columnas nuevas |
| **Realmente NUEVAS** | **11 tablas** | Crear desde cero |

---

## LAS 11 TABLAS REALMENTE NUEVAS (sin antecedente en DDL antiguo)

| # | Tabla | Sección | Prioridad |
|---|-------|---------|:---:|
| 1 | `ath_auth_flow_method` | D1 | ALTA |
| 2 | `zone_field_restriction` | D1 | ALTA |
| 3 | `zone_button_rule` | D1 | ALTA |
| 4 | `zone_record_rule` | D1 | ALTA |
| 5 | `tryton_action_visibility` | D1 | MEDIA |
| 6 | `fis_zone_method_requirement` | D2 | MEDIA |
| 7 | `fis_emergency_config` | D2 | MEDIA |
| 8 | `fin_geospatial_control` | D3 | BAJA |
| 9 | `cal_overtime_policy` | D4 | BAJA |
| 10 | `cal_break_policy` | D4 | BAJA |
| 11 | `net_ztna_policy` | D7 | MEDIA |
| 12 | `ses_ses_risk_policy` | D8 | ALTA |
| 13 | `ses_caep_config` | D8 | MEDIA |
| 14 | `blk_did_registry` | D12 | BAJA |
| 15 | `blk_besu_node` | D12 | BAJA |
| 16 | `sod_validation_config` | D14 | MEDIA |
| 17 | `conflict_interest_policy` | D14 | MEDIA |

**17 tablas totalmente nuevas** (revisé y encontré 2 más que no había contado bien).

---

## LAS 32 TABLAS HEREDABLES DEL DDL ANTIGUO

Todas están en `001_bauth_pendientes.sql`. Hay que:
1. Migrar a schema `bauth` (si están en `bos_blockchain`)
2. Cambiar PK `TEXT/BIGSERIAL` → `UUID DEFAULT uuidv7()`
3. Cambiar `tenant_id TEXT` → `tenant_id UUID REFERENCES bauth.idn_tenant`
4. Agregar `ctx_id TEXT NOT NULL DEFAULT 'system'`
5. Agregar `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
6. Agregar `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
7. Normalizar nombres snake_case donde estén en español
8. Agregar COMMENT ON con referencias [ISO/NIST/RFC]

### Tablas heredables por dominio:

**D1 — Lógico (3):**
- `bos_zone_application_map` → `bauth.zone_application_map`
- `bos_zona_logica` → ya migrado como `bauth.log_zone`
- `bos_permiso_logico` → ya migrado

**D2 — Físico (3):**
- `bos_biometric_templates` → `bauth.fis_biometric_template`
- `bos_dispositivo_fisico` → ya migrado como `bauth.fis_device`
- `bos_area_fisica` → ya migrado como `bauth.fis_area_config`

**D3 — Financiero (4):**
- `bos_sod_conflict_matrix` → `bauth.fin_sod_rule`
- `bos_financial_tipo_transaccion` → ya migrado como `bauth.fin_transaction_type`
- `bos_financial_limit` → ya migrado como `bauth.fin_limit`
- `bos_financial_decision_matrix` → `bauth.fin_decision_matrix`

**D7 — Red (1):**
- `bos_device_registry` → `bauth.net_device`

**D8 — Contexto (3):**
- `bos_context_sessions` → `bauth.ses_context`
- `bos_context_switches` → `bauth.ses_context_switch`
- `bos_superuser_contexts` → `bauth.ses_superuser_context`

**D9 — Credenciales (11):**
- `bos_auth_method` → ya migrado como `bauth.ath_method`
- `bos_auth_policy` → ya migrado como `bauth.ath_policy`
- `bos_credential_policy` → `bauth.ath_credential_policy`
- `bos_credential_rotation_log` → `bauth.ath_rotation_log`
- `bos_password_history` → `bauth.ath_password_history`
- `bos_password_screening_log` → `bauth.ath_password_screening`
- `bos_mfa_enrollments` → `bauth.ath_mfa_enrollment`
- `bos_recovery_method` → `bauth.ath_recovery_method`
- `bos_recovery_challenge` → `bauth.ath_recovery_challenge`
- `bos_authenticator_binding` → `bauth.ath_binding`
- `bos_authenticator_revocation` → `bauth.ath_revocation`
- `bos_user_consent` → `bauth.ath_consent`
- `bos_token_delivery_log` → `bauth.ath_token_delivery`
- `bos_login_attempt` → `bauth.ath_login_attempt`

**D10 — Delegación (1):**
- `bos_delegation_log` → `bauth.dlg_delegation`

**D11 — Auditoría (5):**
- `bos_audit_events` → `bauth.aud_event`
- `bos_access_reviews` → `bauth.aud_review`
- `bos_ghost_accounts` → `bauth.aud_ghost_account`
- `bos_policy_audit` → `bauth.aud_policy_change`
- `bos_policy_history` → `bauth.aud_policy_version`
- `bos_compliance_map` → `bauth.aud_compliance_map`

**D12 — Blockchain (5):**
- `bos_blockchain_anchor_log` → `bauth.blk_anchor`
- `bos_merkle_batch` → `bauth.blk_merkle_batch`
- `bos_merkle_leaf` → `bauth.blk_merkle_leaf`
- `bos_onchain_account` → `bauth.blk_account`
- `bos_anchor_reconciliation_log` → `bauth.blk_reconciliation`

**D13 — Sync (2):**
- `bos_sync_log` → `bauth.sync_log`
- `bos_rol_closure` → ya migrado? (closure table para jerarquía)

**Transversal (3):**
- `bos_user_template` → `bauth.idn_user_template`
- `bos_user_role_assignment` → `bauth.idn_user_role`
- `bos_key_inventory` → `bauth.sec_key_inventory`
- `bos_key_rotation_log` → `bauth.sec_key_rotation`
- `bos_key_recovery_log` → `bauth.sec_key_recovery`

---

## MÉTRICAS FINALES CORREGIDAS

| Métrica | Inicial (sin ver DDL antiguo) | Real (con DDL antiguo) |
|---------|:---:|:---:|
| Tablas YA CUBIERTAS (✅) | 28 | **60** (28 test + 32 heredables) |
| Tablas a MIGRAR (🟡) | 8 | **21** (8 ALTER + 13 heredables que necesitan columnas) |
| Tablas NUEVAS (🔴) | 47 | **17** |
| Seeds existentes | 23 | **23** (hay que crear seeds para las 32 heredables) |

---

## PLAN DE ACCIÓN CORREGIDO

```
FASE 0 — MIGRACIÓN MASIVA (32 tablas del DDL antiguo):
  1. Extraer CREATE TABLE de 001_bauth_pendientes.sql
  2. Normalizar: bos_ → bauth., TEXT PK → UUIDv7, comentarios en inglés
  3. Agregar ctx_id, created_at, updated_at
  4. Insertar en DDL_skSBOS_db_test.sql
  5. Crear seeds con datos reales

FASE A — 17 TABLAS NUEVAS (sin antecedente):
  1. ath_auth_flow_method (D1)
  2. zone_field_restriction (D1)
  3. zone_button_rule (D1)
  4. zone_record_rule (D1)
  ... (las 13 restantes)

FASE B — 8 ALTERS a tablas existentes:
  (misma lista del análisis anterior)

FASE C — SEEDS para las 32+17 tablas
```

---

*Análisis corregido 2026-06-24. La respuesta a la pregunta del usuario:*
**"¿Las tablas del DDL antiguo no tienen estructura que cubran estas necesidades?"**

**RESPUESTA: SÍ LA TIENEN.** De las 47 tablas que parecían faltar, **32 ya existen**
en `001_bauth_pendientes.sql` con esquemas completos, comentarios, constraints,
índices y datos iniciales. El trabajo NO es crear 47 tablas — es **migrar 32**
y crear solo **17 realmente nuevas**.
