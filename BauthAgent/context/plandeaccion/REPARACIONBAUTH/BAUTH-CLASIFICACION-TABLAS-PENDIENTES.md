# BAUTH-CLASIFICACION-TABLAS-PENDIENTES.md — Qué Migrar y Qué Descartar

**Fecha:** 2026-06-24
**Objetivo:** Clasificar las 83 tablas del DDL antiguo en 4 categorías para no migrar lastre.

---

## CATEGORÍAS

| Símbolo | Significado |
|:---:|---|
| ✅ | **Ya migrada** — Existe en DDL test, no hacer nada |
| 🎯 | **Esencial** — Bloquea funcionalidad del Template v6.0. Migrar. |
| 📦 | **Útil** — Soporta el ecosistema pero no bloquea templates. Migrar después. |
| 🗑️ | **Innecesaria** — Legacy, duplicada, fuera de alcance. NO migrar. |

---

## 🗑️ DUPLICADAS — Ya migradas al DDL test (28 tablas)

Estas NO se tocan. Ya están en `DDL_skSBOS_db_test.sql` con esquema normalizado.

| Tabla en pendientes | Ya migrada como | Schema actual |
|------|------|------|
| `bos_auth_method` | `ath__method` | bauth |
| `bos_auth_policy` | `ath__policy` | bauth |
| `bos_auth_config` | `ath__config` | bauth |
| `bos_tier_policy` | `idn_tier_policy` | bauth |
| `bos_rol_template` | `idn_role_template` | bauth |
| `bos_rol_template_history` | `bos_rol_template_history` | bauth |
| `bos_zona_logica` | `log_zone` | bauth |
| `bos_permiso_logico` | `bos_permiso_logico` | bauth |
| `bos_application` | `privilege_application` | bauth |
| `bos_domain` | `privilege_domain` | bauth |
| `bos_group` | `privilege_group` | bauth |
| `bos_verb` | `privilege_verb` | bauth |
| `bos_role` | `privilege_role` | bauth |
| `bos_role_atom` | `privilege_role_atom` | bauth |
| `bos_atom_catalog` | `privilege_atom` | bauth |
| `bos_atom_policy` | `privilege_atom_policy` | bauth |
| `bos_atom_audit` | `privilege_atom_audit` | bauth |
| `bos_financial_tipo_transaccion` | `fin_transaction_type` | bauth |
| `bos_financial_limit` | `fin_limit` | bauth |
| `bos_financial_approval` | `fin_approval` | bauth |
| `bos_financial_role_permission` | `fin_role_permission` | bauth |
| `bos_financial_document_operation` | `fin_document_operation` | bauth |
| `bos_dispositivo_fisico` | `fis_device` | bauth |
| `bos_area_fisica` | `fis_area_config` | bauth |
| `bos_crypto_algorithm` | `bos_crypto_algorithm` | bauth |
| `bos_edificio` | `fis_location` (absorbido) | bauth |
| `bos_piso` | `fis_location` (absorbido) | bauth |
| `bos_schedule` | `cal_schedule` | bcalendar |
| `bos_gestion_calendario` | `cal_calendar` | bcalendar |

**Acción: NINGUNA. Ya están migradas.**

---

## 🎯 ESENCIALES — Bloquean el Template v6.0 (38 tablas)

### Dominio D1 — Lógico (3)
| # | Tabla pendientes | Nueva ubicación | Qué aporta al template |
|---|------|------|------|
| 1 | `bos_zone_application_map` | `bauth.zone_application_map` | Zonas → Apps con modules, scopes. ESENCIAL para D1.5 zones |
| 2 | `bos_rol_closure` | `bauth.idn_role_closure` | Closure table DAG. ESENCIAL para herencia H-RBAC |
| 3 | `bos_global_config` | `bauth.global_config` | Parámetros centrales. ESENCIAL para defaults del sistema |

### Dominio D3 — Financiero (2)
| 4 | `bos_sod_conflict_matrix` | `bauth.fin_sod_rule` | SoD formal con bits, risk_level, rationale. ESENCIAL para D3+D14 |
| 5 | `bos_financial_decision_matrix` | `bauth.fin_decision_matrix` | Aprobación en cascada 3 niveles. ESENCIAL para D3 approval_chain |

### Dominio D8 — Contexto (3)
| 6 | `bos_context_sessions` | `bauth.ses_context` | ctx_id 6-capas, traceparent, device. ESENCIAL para D8 ctx_id_compliance |
| 7 | `bos_context_switches` | `bauth.ses_context_switch` | Historial de cambio de contexto. ESENCIAL para D8 context_switching |
| 8 | `bos_superuser_contexts` | `bauth.ses_superuser_context` | Break-glass SU. ESENCIAL para D8 force_logout_on |

### Dominio D9 — Credenciales (14)
| 9 | `bos_credential_policy` | `bauth.ath_credential_policy` | Políticas: rotación, HIBP, fortaleza. ESENCIAL para D9 password_policy |
| 10 | `bos_password_history` | `bauth.ath_password_history` | Historial Argon2id. ESENCIAL para D9 history_check |
| 11 | `bos_password_screening_log` | `bauth.ath_password_screening` | Cribado HIBP k-anonymity. ESENCIAL para D9 hibp_check |
| 12 | `bos_mfa_enrollments` | `bauth.ath_mfa_enrollment` | Dispositivos MFA del usuario. ESENCIAL para D9 methods |
| 13 | `bos_recovery_method` | `bauth.ath_recovery_method` | Recuperación verificada. ESENCIAL para D9 recovery_policy |
| 14 | `bos_recovery_challenge` | `bauth.ath_recovery_challenge` | Preguntas hash Argon2id. ESENCIAL para D9 recovery_policy |
| 15 | `bos_authenticator_binding` | `bauth.ath_binding` | Vínculo authenticator↔user NIST 800-63B-4. ESENCIAL |
| 16 | `bos_authenticator_revocation` | `bauth.ath_revocation` | Revocación WORM. ESENCIAL |
| 17 | `bos_login_attempt` | `bauth.ath_login_attempt` | Intentos login particionado. ESENCIAL para D9 lockout_policy |
| 18 | `bos_user_consent` | `bauth.ath_consent` | Consentimientos GDPR. ESENCIAL para D5+D9 |
| 19 | `bos_credential_rotation_log` | `bauth.ath_rotation_log` | Rotaciones registradas. ESENCIAL para D9 credential_rotation |
| 20 | `bos_token_delivery_log` | `bauth.ath_token_delivery` | Trazabilidad de entrega. ÚTIL para auditoría |
| 21 | `bos_auth_method_enrollment_log` | `bauth.ath_enrollment_log` | Enrolamiento paso a paso. ÚTIL |
| 22 | `bos_federation_protocol` | `bauth.ath_federation_protocol` | Protocolos de federación. ESENCIAL para D1 availableMethods |

### Dominio D10 — Delegación (1)
| 23 | `bos_delegation_log` | `bauth.dlg_delegation` | Delegaciones temporales. ESENCIAL para D10 |

### Dominio D11 — Auditoría (7)
| 24 | `bos_audit_events` | `bauth.aud_event` | WORM particionado con hash-chain. ESENCIAL |
| 25 | `bos_access_reviews` | `bauth.aud_review` | Recertificación ISO 27001. ESENCIAL |
| 26 | `bos_ghost_accounts` | `bauth.aud_ghost_account` | Cuentas huérfanas. ESENCIAL |
| 27 | `bos_policy_audit` | `bauth.aud_policy_change` | Cambios de políticas WORM. ESENCIAL |
| 28 | `bos_policy_history` | `bauth.aud_policy_version` | Historial versionado. ESENCIAL |
| 29 | `bos_compliance_map` | `bauth.aud_compliance_map` | 34 controles. ESENCIAL para D11 regulatory_frameworks |
| 30 | (particiones audit_events) | Particiones mensuales | ESENCIAL |

### Dominio D12 — Blockchain (5)
| 31 | `bos_blockchain_anchor_log` | `bauth.blk_anchor` | Anclajes L2. ESENCIAL para D12 |
| 32 | `bos_merkle_batch` | `bauth.blk_merkle_batch` | Lotes Merkle. ESENCIAL |
| 33 | `bos_merkle_leaf` | `bauth.blk_merkle_leaf` | Hojas Merkle con proof. ESENCIAL |
| 34 | `bos_onchain_account` | `bauth.blk_account` | Cuentas on-chain. ESENCIAL |
| 35 | `bos_anchor_reconciliation_log` | `bauth.blk_reconciliation` | Reconciliación cross-chain. ESENCIAL |

### Dominio D13 — Sync (1)
| 36 | `bos_sync_log` | `bauth.sync_log` | Sync KC+Tryton con drift detection. ESENCIAL |

### User Template (3)
| 37 | `bos_user_template` | `bauth.idn_user_template` | Template de usuario. ESENCIAL |
| 38 | `bos_user_role_assignment` | `bauth.idn_user_role` | Asignación roles→usuarios. ESENCIAL |

### Estructura organizacional (3)
| 39 | `bos_empresa` | `bauth.org_empresa` | Empresa multi-tenant. ESENCIAL |
| 40 | `bos_sucursal` | `bauth.org_sucursal` | Sucursal física. ESENCIAL |
| 41 | `bos_pos_logico` | `bauth.org_pos_logico` | Punto de venta + SIN. ESENCIAL |

### Seguridad — Llaves criptográficas (3)
| 42 | `bos_key_inventory` | `bauth.sec_key_inventory` | Inventario 20 tipos llaves. ESENCIAL |
| 43 | `bos_key_rotation_log` | `bauth.sec_key_rotation` | Rotación de llaves. ESENCIAL |
| 44 | `bos_key_recovery_log` | `bauth.sec_key_recovery` | Recuperación de llaves. ESENCIAL |

### Red y Dispositivos (2)
| 45 | `bos_device_registry` | `bauth.net_device` | Dispositivos de red. ESENCIAL para D7 |
| 46 | `bos_domain_config` | `bauth.cfg_domain_config` | Config por dominio. ÚTIL |

---

## 📦 ÚTILES — No bloquean templates, migrar en Fase 2 (2)

| # | Tabla pendientes | Motivo |
|---|------|------|
| 47 | `bos_framework_version` | Versionado del framework. Metadata, no funcional. |
| 48 | `bos_vdi_profiles` | Perfiles VDI. Dominio de banexus, no de bAuth templates. |

---

## 🗑️ INNECESARIAS — NO migrar (6)

| # | Tabla pendientes | Motivo |
|---|------|------|
| 49 | `bos_saga_catalog` | Sagas de autenticación. Pertenece a BOS/orquestación, no a bAuth. |
| 50 | `bos_saga_execution` | Ejecución de sagas. Idem. |
| 51 | `bos_saga_step` | Pasos de saga. Idem. |
| 52 | `bos_backup_log` | Log de backups. Infraestructura/operaciones. |
| 53 | `bos_reconciliation_log` | Reconciliación de datos. BOS, no bAuth. |
| 54 | `bos_onchain_settlement` | Liquidación on-chain Variante B. Futuro lejano, no necesario ahora. |

---

## RESUMEN FINAL

| Clasificación | Cantidad | Acción |
|------|:---:|------|
| ✅ Ya migradas | **28** | No hacer nada |
| 🎯 Esenciales (migrar AHORA) | **46** | Extraer del DDL antiguo, normalizar, insertar en DDL test |
| 📦 Útiles (migrar DESPUÉS) | **2** | Dejar en pendientes, prioridad baja |
| 🗑️ Innecesarias (NO migrar) | **6** | Descartar — son ruido |
| 🔴 Nuevas (sin antecedente, del análisis anterior) | **17** | Crear desde cero |

---

## PLAN CORREGIDO

```
FASE 0 — MIGRAR 46 ESENCIALES (prioridad máxima):
  Día 1: D1 (3) + D3 (2) + D8 (3) = 8 tablas
  Día 2: D9 (14) = 14 tablas
  Día 3: D10 (1) + D11 (7) + D13 (1) = 9 tablas
  Día 4: D12 (5) + User (3) + Org (3) + Sec (3) + Red (2) = 16 tablas
  
  Para cada tabla:
    1. Extraer CREATE TABLE de 001_bauth_pendientes.sql
    2. Normalizar: bos_ → bauth., TEXT PK → UUIDv7
    3. Agregar ctx_id, created_at, updated_at
    4. Traducir columnas español → inglés
    5. Agregar COMMENT ON [ISO/NIST/RFC]
    6. Insertar en DDL_skSBOS_db_test.sql

FASE 1 — CREAR 17 NUEVAS (del análisis de gaps):
  Las que no tienen antecedente en el DDL antiguo

FASE 2 — 8 ALTERS a tablas existentes:
  Columnas faltantes en ath_method, idn_role_template, etc.

FASE 3 — RE-EVALUAR completitud del template:
  Con las 46+17 tablas migradas, verificar cobertura total
```

---

*Clasificación generada 2026-06-24. De 83 tablas en el DDL antiguo: 28 ya migradas, 46 esenciales, 2 útiles, 6 innecesarias.*
*Las 46 esenciales son el inventario real de trabajo inmediato.*
