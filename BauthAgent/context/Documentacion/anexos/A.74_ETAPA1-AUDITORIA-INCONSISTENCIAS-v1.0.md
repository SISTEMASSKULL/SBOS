# A.74 — Etapa 1: Auditoría de Inconsistencias DDL ↔ Código

**Versión:** 1.0.0 · **Fecha:** 2026-08-02 · **Fuente:** grep en `src/` vs `SBOS_db_V2_DDL.sql`

**Filosofía:** NO se preserva código legacy. Para cada tabla phantom: si la funcionalidad pertenece al nuevo sistema → **reescribir** contra el DDL canónico; si la funcionalidad no tiene lugar en el nuevo sistema → **eliminar** el código. No hay migración ni compatibilidad hacia atrás.

**DONE cuando:** todas las filas de §2 tienen decisión `REESCRIBIR` o `ELIMINAR` tomada, y el archivo de destino identificado.

---

## §1 Resumen ejecutivo

| Categoría | Tablas | Refs SQL |
|-----------|:------:|:--------:|
| Tablas phantom (en código, NO en DDL) | **36** | **~250** |
| Tablas ya alineadas (en código Y en DDL) | 12 | ~47 |
| **Total archivos con SQL** | — | **64 archivos** |

---

## §2 Mapa legacy → canónico

Leyenda de estado: ✅ Mapeado con certeza · ❓ Requiere decisión humana · 🔴 Sin equivalente conocido

### Grupo A — Autenticación (`ath_*` → `auth_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.ath_login_attempt` | 5 | `bauth.auth_attempt_log` | ✅ |
| `bauth.ath_method` | 2 | `bauth.auth_method` | ✅ |
| `bauth.ath_config` | 1 | `bauth.auth_config` | ✅ |
| `bauth.ath_federation_protocol` | 1 | `bauth.auth_federation_protocol` | ✅ |
| `bauth.ath_recovery_method` | 1 | `bauth.idn_user_recovery` | ✅ |
| `bauth.ath_mfa_enrollment` | 2 | `bauth.auth_credential` | ✅ |
| `bauth.ath_password_history` | 2 | `bauth.auth_credential_secret` | ✅ |
| `bauth.ath_policy` | 1 | `bauth.auth_policy` | ✅ |
| `bauth.ath_policy_d` | 24 | ❓ `bauth.auth_policy` + dominio? | ❓ |

> **Decisión A.74-D01:** ¿`ath_policy_d` es `auth_policy` filtrado por dominio, o necesita nueva tabla?

### Grupo B — Auditoría (`aud_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.aud_event` | 9 | 🔴 No hay equivalente directo en DDL | 🔴 |
| `bauth.aud_compliance_map` | 1 | `bauth.auth_compliance_map` | ✅ |
| `bauth.aud_policy_change` | 4 | ❓ `bauth.privilege_atom_audit`? | ❓ |

> **Decisión A.74-D02:** ¿`aud_event` se mapea a `bauth.ses_caep_event_log` o a nueva tabla?

### Grupo C — Roles/Identidad (`idn_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.idn_role_template` | 13 | `bauth.idn_roles_rol_hierarchical` | ✅ |
| `bauth.idn_role_closure` | 5 | `bauth.idn_roles_rol_closure` | ✅ |
| `bauth.idn_role_template_history` | 2 | `bauth.idn_roles_template_history` | ✅ |
| `bauth.idn_user_template` | 27 | ❓ `bauth.idn_user`? ¿nueva tabla? | ❓ |
| `bauth.idn_user_role` | 3 | ❓ `bauth.privilege_grant`? | ❓ |
| `bauth.idn_roles_ver_b` | 20 | `bauth.idn_roles_ver_b01_audit_log` + `_b03_approval_queue` | ✅ parcial |

> **Decisión A.74-D03:** ¿`idn_user_template` es `idn_user` con columnas extra, o tabla separada?

### Grupo D — Organización (`org_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.org_empresa` | 8 | ❓ `bauth.idn_identity_entity`? | ❓ |
| `bauth.org_sucursal` | 7 | ❓ `bauth.idn_identity_entity` (subtipo)? | ❓ |
| `bauth.org_pos_logico` | 6 | ❓ `bauth.idn_identity_entity` (subtipo)? | ❓ |

> **Decisión A.74-D04:** ¿Las 3 tablas `org_*` colapsan a `idn_identity_entity` con campo `type`, o tienen tablas propias en DDL?

### Grupo E — Privilegios (`privilege_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.privilege_atom` | 29 | `bauth.privilege_resource_atom` | ✅ |
| `bauth.privilege_role` | 11 | ❓ `bauth.privilege_assurance_audit`? | ❓ |
| `bauth.privilege_role_atom` | 6 | ❓ `bauth.privilege_grant`? | ❓ |
| `bauth.privilege_domain` | 8 | 🔴 Sin equivalente en DDL actual | 🔴 |
| `bauth.privilege_atom_policy` | 7 | 🔴 Sin equivalente en DDL actual | 🔴 |
| `bauth.fin_sod_rule` | 2 | `bauth.privilege_verb_conflict` | ✅ |

> **Decisión A.74-D05:** ¿`privilege_domain` y `privilege_atom_policy` se crean como nuevas tablas o colapsan a existentes?

### Grupo F — Sesión (`ses_*`)

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.ses_context` | 12 | ❓ `bauth.ses_session_log`? esquema diferente | ❓ |

> **Decisión A.74-D06:** ¿`ses_context` = `ses_session_log` (renombrar) o son dos tablas distintas?

### Grupo G — Varios

| Tabla legacy | Refs | Tabla canónica (DDL) | Estado |
|---|:---:|---|:---:|
| `bauth.bos_crypto_algorithm` | 1 | `bauth.auth_crypto_algorithm` | ✅ |
| `bauth.cfg_validation_rule` | 2 | `bauth.cfg_policy_library` | ✅ |
| `bauth.sec_key_inventory` | 1 | `bauth.sig_key` | ✅ |
| `bauth.user_client_device` | 3 | `bauth.auth_device` | ✅ |
| `bauth.net_device` | 1 | `bauth.auth_device` | ✅ |
| `bauth.device_attestation_log` | 1 | `bauth.auth_device_posture` | ✅ |
| `bauth.ctx_transfer_log` | 1 | `bauth.ses_caep_event_log` | ✅ |
| `bauth.sync_log` | 3 | 🔴 Sin equivalente (operacional) | 🔴 |

---

## §3 Decisiones pendientes (bloquean el refactor)

| ID | Tabla(s) | Pregunta | Bloqueado en capa |
|----|----------|----------|-------------------|
| D01 | `ath_policy_d` | ¿mapeo a `auth_policy` o nueva tabla? | 2B domain/ |
| D02 | `aud_event` | ¿`ses_caep_event_log` o nueva `aud_event`? | 2B domain/ |
| D03 | `idn_user_template` | ¿`idn_user` o tabla nueva? | 2C handlers/ |
| D04 | `org_*` (3 tablas) | ¿colapsan a `idn_identity_entity`? | 2C handlers/ |
| D05 | `privilege_domain`, `privilege_atom_policy` | ¿nuevas tablas o colapso? | 2C handlers/ |
| D06 | `ses_context` | ¿`ses_session_log` o tabla propia? | 2B domain/ |

---

## §4 Tablas ya alineadas (no requieren cambio)

`blk_account` · `blk_merkle_batch` · `blk_merkle_leaf` · `blk_reconciliation` · `cfg_policy_library`
· `idn_identity_attribute` · `idn_roles_rol_hierarchical` · `idn_roles_rol_lifecycle_event`
· `idn_tenant` · `idn_tenant_domain` · `privilege_atom_audit` · `privilege_verb`

---

## §5 Archivos por capa (input para A.75)

### Capa 1 — `db/` (4 archivos, ~40 refs)
`db/mod.rs` · `db/approval.rs` · `db/version_store.rs` · `db/versioning.rs`

### Capa 2 — `domain/` + `bitmask/` + `saga/` + `sync/` (20 archivos, ~110 refs)
`domain/policy/ath_loader.rs` · `domain/policy_chain.rs` · `domain/rule_engine.rs`
· `domain/audit_domain.rs` · `domain/startup.rs` · `domain/merge.rs`
· `bitmask/closure.rs` · `bitmask/conflict.rs`
· `saga/actions/login.rs` · `saga/registry.rs`
· `sync/mod.rs` · `sync/retention.rs`
_(+8 archivos domain/ con 1-3 refs cada uno)_

### Capa 3 — `server/handlers/` (40 archivos, ~100 refs)
_(listado completo en A.75 §3)_

---

*A.74 v1.0.0 · Auditoría Etapa 1 · bAuth · 2026-08-02*
