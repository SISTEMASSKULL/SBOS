# BAUTH-TAREAS-PENDIENTES.md — Lista de Tareas por Completar

**Fecha:** 2026-06-24 · **Estado general:** 85% completado
**Referencia:** `BAUTH-INVENTARIO-TABLAS-DECISION.md` v3.1

---

## RESUMEN

| Indicador | Completado | Pendiente | Total |
|-----------|:---:|:---:|:---:|
| Tablas en DDL | 162 | 0 | 162 |
| Errores DDL | — | — | 0 |
| Seeds creados | 33 | **82 sin seed** | 115 |
| Dominios cubiertos | 12 | 0 | 12 |

---

## 1. SEEDS PENDIENTES (82 tablas sin seed)

De las 115 tablas en schema `bauth`, solo 33 tienen seed. Las 82 restantes se dividen en:

### 1.1 — NO NECESITAN SEED (runtime / WORM / logs) — ~50 tablas

Estas tablas se pueblan en runtime por los daemons. No requieren seed:

`ath_login_attempt*`, `ath_enrollment_log`, `ath_token_delivery`, `ath_rotation_log`,
`ath_revocation`, `ath_password_history`, `ath_password_screening`, `ath_mfa_enrollment`,
`ath_recovery_challenge`, `ath_recovery_method`, `ath_binding`, `ath_consent`,
`aud_event*`, `aud_review`, `aud_ghost_account`, `aud_policy_change`, `aud_policy_version`,
`blk_anchor`, `blk_merkle_batch`, `blk_merkle_leaf`, `blk_reconciliation`, `blk_account`,
`dlg_delegation`, `ses_context`, `ses_context_switch`, `ses_superuser_context`,
`geo_location_log`, `geo_evaluation_log`, `sync_log`,
`privilege_atom_audit*`, `bos_rol_template_history`

### 1.2 — NECESITAN SEED (catálogos / políticas / configs) — ~32 tablas

| Prioridad | Tabla | Tipo | ¿Qué datos? |
|:---:|-------|------|------------|
| 🔴 | `ath_credential_policy` | Política D9 | 8 políticas de credenciales (PASSWORD, TOTP, WEBAUTHN...) |
| 🔴 | `ath_federation_protocol` | Catálogo D9 | 16 protocolos de federación (OAuth2, OIDC, SAML, CIBA...) |
| 🔴 | `ath_config_d1` a `ath_config_d12` | Configs | Valores default por dominio (12 tablas) |
| 🟠 | `ath_policy_d2` | Políticas D2 | anti_passback, escort, two_person, mantrap |
| 🟠 | `ath_policy_d4` | Políticas D4 | schedules, holidays, overtime, breaks |
| 🟠 | `ath_policy_d5` | Políticas D5 | liveness, fmr, enrollment, gdpr |
| 🟠 | `ath_policy_d6` | Políticas D6 | geo_fence, velocity, trust_tiers |
| 🟠 | `ath_policy_d7` | Políticas D7 | device_trust, vpn, mtls, ztna |
| 🟠 | `ath_policy_d8` | Políticas D8 | ctx_id, session_ttl, reauth, caep |
| 🟠 | `ath_policy_d10` | Políticas D10 | max_duration, non_delegable, chain |
| 🟠 | `ath_policy_d11` | Políticas D11 | retention, review_freq, hash_chain |
| 🟠 | `ath_policy_d12` | Políticas D12 | merkle, did, proof_types |
| 🟡 | `idn_role_d1` a `idn_role_d12` | Templates | Roles pre-configurados por dominio (12 tablas, solo D9 tiene seed) |
| 🟡 | `aud_compliance_map` | Catálogo D11 | 34 controles ISO+NIST+PCI+GDPR |
| 🟡 | `idn_user_template` | Template | Usuario bootstrap del sistema |
| 🟡 | `org_empresa` | Org | Empresa SKULL bootstrap |
| 🟡 | `org_sucursal` | Org | Sucursal Central bootstrap |
| ⚪ | `geo_velocity_policy` | Config D6 | Default: 900 km/h, 10 km tolerancia |
| ⚪ | `geo_fence` | Datos D6 | Geo-cerca de sucursal central |

---

## 2. `ath_method` — Clasificación por dominio

**Código:** T-065 · **Estado:** 🔴 PENDIENTE

La tabla `ath_method` (32 métodos) no tiene columna `domain_classification JSONB`.
Cada método debe etiquetarse con los dominios donde aplica:

| Tarea | Descripción |
|-------|------------|
| 2.1 | `ALTER TABLE bauth.ath_method ADD COLUMN domain_classification JSONB DEFAULT '{}'` |
| 2.2 | Actualizar `seed_ath_method.sql` con `domain_classification` para los 32 métodos |
| 2.3 | Ejemplo: `PASSWORD` → `{"D1":true,"D2":true,"D9":true}`, `WEBAUTHN_PWDLESS` → `{"D1":true,"D2":true,"D9":true}`, `CLIENT_CREDENTIALS` → `{"D7":true,"D9":true}` |

---

## 3. Menú → `bglobal`

**Código:** T-090, T-091, T-092 · **Estado:** 🔴 PENDIENTE

| Tarea | Descripción |
|-------|------------|
| 3.1 | Mover `bauth.menu_item` → `bglobal.menu_item` |
| 3.2 | Mover `bauth.menu_context` → `bglobal.menu_context` |
| 3.3 | Mover `bauth.menu_item_atom` → `bglobal.menu_item_atom` |
| 3.4 | Actualizar FKs que referencien estas tablas |
| 3.5 | Actualizar seeds correspondientes |

---

## 4. Organización de la DDL por dominio

**Estado:** 🔴 PENDIENTE

El archivo `DDL_skSBOS_db.sql` (~4500 líneas) no está organizado por dominio.
Las tablas están en orden de migración, no en orden de dominio.

| Tarea | Descripción |
|-------|------------|
| 4.1 | Reorganizar en 18 secciones con separadores de dominio (según estructura definida en inventario §ESTRUCTURA FINAL DE LA DDL POR DOMINIO) |
| 4.2 | Cada sección debe tener: separador visible, COMMENT ON con estándares, tablas agrupadas |

---

## 5. Idempotencia ×3 en VPS

**Estado:** 🔴 PENDIENTE

| Tarea | Descripción |
|-------|------------|
| 5.1 | Ejecutar DDL + seeds ×3 en VPS, verificar mismo resultado, 0 errores |

---

## 6. Plantilla de usuario (`idn_user_template`)

**Estado:** 🟡 PARCIAL

| Tarea | Descripción |
|-------|------------|
| 6.1 | Crear `seed_idn_user_template.sql` con usuario bootstrap |
| 6.2 | El template JSONB debe incluir las 14 secciones del UserTemplate v6.0 |

---

## RESUMEN DE PRIORIDADES

| # | Tarea | Tipo | Prioridad | Esfuerzo |
|---|-------|------|:---:|:---:|
| 1 | Seeds de políticas D1-D12 (11 tablas) | Seeds | 🔴 | 4h |
| 2 | `ath_method.domain_classification` ALTER + seed | DDL + Seed | 🔴 | 2h |
| 3 | `ath_federation_protocol` seed (16 protocolos) | Seed | 🔴 | 1h |
| 4 | `ath_credential_policy` seed (8 políticas) | Seed | 🔴 | 1h |
| 5 | Mover `menu_*` de bauth a bglobal | DDL | 🟠 | 2h |
| 6 | Seeds `idn_role_d*` (11 dominios sin seed) | Seeds | 🟠 | 4h |
| 7 | `aud_compliance_map` seed (34 controles) | Seed | 🟡 | 2h |
| 8 | `org_empresa` + `org_sucursal` seeds | Seed | 🟡 | 1h |
| 9 | `idn_user_template` seed | Seed | 🟡 | 2h |
| 10 | Organizar DDL por dominio | Orden | ⚪ | 2h |
| 11 | Idempotencia ×3 en VPS | Testing | 🔴 | 1h |
| **TOTAL** | | | | **~22h** |

---

*Documento generado 2026-06-24. 11 tareas pendientes. ~22h estimadas para completar el 100%.*
