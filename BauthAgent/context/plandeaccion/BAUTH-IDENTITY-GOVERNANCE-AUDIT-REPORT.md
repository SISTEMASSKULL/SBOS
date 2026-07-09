# BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT — Informe de Auditoría DDL

**Versión:** 1.0.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Auditado:** `BauthAgent/db/migrations/001_bauth_init.sql.bak` (103 tablas, 113 REFERENCES)
**Contra:** `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0.0 · `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` v2.0.0
**Estándares:** ISO 27001:2022 · NIST 800-53 Rev.5 · PCI DSS 4.0.1 · OWASP ASVS 5.0 · GDPR/RGPD · SOC 2 Type II · W3C Trace Context

---

## 0. Compliance Score: 39%

| Estado | Conteo | Significado |
|--------|--------|-------------|
| ✅ **PASA** | 5/18 | Cumple el estándar de la plataforma |
| ⚠️ **PARCIAL** | 4/18 | Cumple parcialmente, mejorable |
| ❌ **FALLA** | 9/18 | No cumple — requiere acción correctiva |

---

## 1. Auditoría por Pilar

### PILAR 1: Identity Audit (Secure Audit Logs) — 25%

| # | Control | Estado | Actual | Requerido |
|---|---------|--------|--------|-----------|
| 1.1 | Cobertura `ctx_id` | ❌ | 25/103 tablas (24.3%) | ≥ 45 tablas (≥ 44%) |
| 1.2 | Hash-chains SHA-256 | ❌ | 2 tablas | ≥ 8 tablas |
| 1.3 | Tablas WORM (REVOKE) | ✅ | 9 tablas | ≥ 8 tablas |
| 1.4 | Particiones por mes | ❌ | 3 tablas | ≥ 10 tablas |

**Detalle 1.1 — ctx_id coverage (25/103 = 24.3%):**

- ✅ Con ctx_id: `aud_event`, `context_sessions`, `context_switches`, `sync_log`, `policy_audit`, `authenticator_revocation`, `token_delivery_log`, `rol_template_history`, `financial_approval`, `compliance_map`, `saga_execution`, `privilege_audit`, `key_inventory`, `key_recovery_log`, `atom_audit`, y 10 más.
- ❌ Sin ctx_id (críticos): `login_attempt`, `delegation_log`, `superuser_contexts`, `backup_log`, `device_registry`, `access_reviews`, `ghost_accounts`, `key_rotation_log`, `credential_rotation_log`, `mfa_enrollments`, `password_screening_log`, `recovery_challenge`, `authenticator_binding`, `user_consent`, `financial_decision_matrix`

**Detalle 1.2 — Hash-chains (2/8):**

- ✅ Con hash-chain: `bos_audit_events` (SHA-256, trigger `compute_audit_entry_hash`), `bos_rol_template_history` (SHA-256)
- ❌ Sin hash-chain: `bos_sync_log`, `bos_policy_audit`, `bos_superuser_contexts`, `bos_atom_audit`, `bos_authenticator_revocation`, `bos_login_attempt`

**Detalle 1.4 — Particiones (3/10):**

- ✅ Particionadas: `bos_audit_events`, `bos_login_attempt`, `bos_atom_audit`
- ❌ Sin particionar (de alto volumen): `bos_sync_log`, `bos_policy_audit`, `bos_superuser_contexts`, `bos_key_rotation_log`, `bos_access_reviews`, `bos_ghost_accounts`, `bos_context_switches`

---

### PILAR 2: Identity Governance (Access Certification) — 100%

| # | Control | Estado |
|---|---------|--------|
| 2.1 | `bos_access_reviews` (recertificación periódica) | ✅ |
| 2.2 | `bos_sod_conflict_matrix` (Separación de Deberes) | ✅ |
| 2.3 | `bos_delegation_log` con `auto_revoke` | ✅ |
| 2.4 | `bos_user_role_assignment` (asignación usuario↔rol con vigencia) | ✅ |

**Bien.** El núcleo de Access Certification está completo y bien diseñado:
- Recertificación periódica con `review_type` (MONTHLY/QUARTERLY/SEMI_ANNUAL/ANNUAL)
- SoD con 8 pares estáticos + 2 dinámicos en `sod_conflict_matrix`
- Delegación temporal con `valid_until`, `auto_revoke`, y CHECK `chk_no_self_delegation`

---

### PILAR 3: Access Alerting (ITDR) — 0%

| # | Control | Estado |
|---|---------|--------|
| 3.1 | `cfg_notification_policy` (políticas de alerta) | ❌ INEXISTENTE |
| 3.2 | `cfg_domain_channel` (mapeo dominio→canal) | ❌ INEXISTENTE |
| 3.3 | `aud_notification` (espejo local de alertas) | ❌ INEXISTENTE |
| 3.4 | 76 event_types en CHECK constraint | ❌ Solo 38 genéricos (faltan 38 específicos) |
| 3.5 | Columnas de alerta en `aud_event` | ❌ 1/6 (solo `notification_channels`) |

**Crítico.** Sin estas 3 tablas, bAuth no puede:
- Disparar notificaciones basadas en políticas por tenant/dominio
- Mapear eventos a canales Mattermost
- Auditar localmente las notificaciones enviadas (depende 100% de Novu)

**Columnas faltantes en `aud_event`:**
```sql
notification_sent    BOOLEAN   DEFAULT FALSE,  -- ❌
acknowledged_at      TIMESTAMPTZ,              -- ❌
acknowledged_by      UUID,                     -- ❌
escalated_at         TIMESTAMPTZ,              -- ❌
escalated_to         UUID                      -- ❌
```

---

### PILAR 4: Identity Lineage — 75%

| # | Control | Estado |
|---|---------|--------|
| 4.1 | `approved_by` en `delegation_log` | ✅ |
| 4.2 | `granted_by` en `bRates.currency_access` | ✅ |
| 4.3 | `bos_user_role_assignment` con `assigned_at` + `assigned_by` | ✅ |
| 4.4 | `bos_context_switches` con `emitido_por` | ✅ |
| 4.5 | 8/10 tablas críticas sin `ctx_id` | ❌ |

**Bien en estructura, mal en cobertura.** Las tablas de lineage existen pero 8 de 10 tablas operativas carecen de `ctx_id`, rompiendo la cadena de trazabilidad.

---

### PILAR 5: Comprehensive Framework (Compliance) — 88%

| # | Control | Estado | Conteo |
|---|---------|--------|--------|
| 5.1 | ISO 27001:2022 | ✅ | 29 referencias |
| 5.2 | NIST 800-53 Rev.5 | ✅ | 28 referencias |
| 5.3 | PCI DSS 4.0.1 | ✅ | 14 referencias |
| 5.4 | GDPR/RGPD | ✅ | 9 referencias |
| 5.5 | W3C Trace Context | ⚠️ | 5 referencias. `ctx_id` es UUID no traceparent |

**Excelente documentación normativa.** La DDL tiene COMMENT ON con referencias precisas a estándares en las tablas principales. El punto débil es W3C Trace Context: `ctx_id` es `TEXT NOT NULL` pero no se valida contra el formato `traceparent` (55 caracteres, `00-{trace-id}-{parent-id}-00`).

---

## 2. Verificaciones Técnicas

| # | Control | Estado | Actual | Requerido |
|---|---------|--------|--------|-----------|
| V1 | UUID PKs | ⚠️ | 48/103 (47%) | 103 (100%) |
| V2 | SERIAL/BIGSERIAL residuales | ⚠️ | 2 tablas | 0 |
| V3 | REFERENCES | ✅ | 113 (supera 104 esperadas) | ≥ 104 |
| V4 | ALTER TABLE residuales | ❌ | 73 | 0 (solo RLS) |
| V5 | Bug sintaxis PK `superuser_contexts` | ❌ | 1 bug | 0 |
| V6 | Índices GIN sobre JSONB | ❌ | 4 | ≥ 8 |
| V7 | Retention policy explícita | ❌ | 0 | 1 tabla + 1 función |

**Detalle V2 — SERIAL/BIGSERIAL residuales:**
- `bos_audit_events.event_id BIGSERIAL` — debe migrar a `UUID DEFAULT gen_random_uuid()`
- `bos_login_attempt.attempt_id BIGSERIAL` — debe migrar a `UUID DEFAULT gen_random_uuid()`

**Detalle V5 — Bug sintaxis:**
```sql
-- ACTUAL (ROTO):
context_id UUID PRIMARY KEY DEFAULT gen_random_uuid() DEFAULT gen_random_uuid()::text,
-- Doble DEFAULT + ::text sobre UUID inválido.

-- CORRECTO:
context_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
```

---

## 3. Resumen de Acciones por Prioridad

### 🔴 CRÍTICAS (9) — Deben resolverse antes del deploy en producción

| # | Gap | Acción | Archivo(s) afectado(s) |
|---|-----|--------|----------------------|
| C1 | 3 tablas ITDR inexistentes | Crear `cfg_notification_policy`, `cfg_domain_channel`, `aud_notification` | `001_bauth_init.sql` |
| C2 | 38 identity events faltantes | Expandir CHECK constraint de 38 a 76 valores | `001_bauth_init.sql` §aud_events |
| C3 | 20 tablas sin `ctx_id` | Agregar `ctx_id TEXT NOT NULL` | 20 CREATE TABLEs |
| C4 | 6 hash-chains faltantes | Agregar `prev_hash` + `entry_hash` + trigger | 6 CREATE TABLEs |
| C5 | 7 tablas sin particionar | Agregar `PARTITION BY RANGE` | 7 CREATE TABLEs |
| C6 | 73 ALTER TABLE residuales | Integrar en sus CREATE TABLE | 16 tablas principales |
| C7 | Bug PK `superuser_contexts` | Corregir sintaxis (doble DEFAULT) | 1 tabla |
| C8 | 2 SERIAL/BIGSERIAL residuales | Migrar a UUID | `audit_events`, `login_attempt` |
| C9 | Sin retention policy | Crear `cfg_retention_policy` + función | 1 tabla + 1 función |

### 🟠 ALTAS (8) — Después de críticas

| # | Gap | Acción |
|---|-----|--------|
| A1 | 4 columnas de alerta faltantes en `aud_event` | Agregar `notification_sent`, `acknowledged_at`, `acknowledged_by`, `escalated_at` |
| A2 | 4 índices GIN faltantes | Agregar `USING GIN (details jsonb_path_ops)` |
| A3 | Sin validación W3C traceparent | Agregar CHECK constraint formato 55 caracteres |
| A4 | `bos_login_attempt` sin columnas NIST AC-7 | Agregar `lockout_level`, `lockout_expires_at` |
| A5 | Tabla `audit_evidence` inexistente | Crear para adjuntos de evidencia |
| A6 | `bos_key_rotation_log` sin verificación criptográfica | Agregar `witness_1`, `witness_2`, `key_fingerprint_*` |
| A7 | Sin tabla `cfg_event_compliance` | Crear mapeo event_type→estándar |
| A8 | 4 tablas GIN adicionales | `policy_audit`, `atom_audit`, `compliance_map` |

### 🟡 MEDIAS (4) — Post-DDL

| # | Gap | Acción |
|---|-----|--------|
| M1 | `bos_context_sessions` — ctx_id UUID vs traceparent TEXT | Renombrar PK a `session_id`, traceparent como `w3c_traceparent UNIQUE` |
| M2 | `login_attempt` sin ctx_id | Agregar columna |
| M3 | `recovery_challenge` + `password_screening_log` sin ctx_id | Agregar columna |
| M4 | `ghost_accounts` + `access_reviews` sin ctx_id | Agregar columna |

---

## 4. Veredicto

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   IDENTITY GOVERNANCE & AUDIT PLATFORM                        ║
║   DDL Compliance Audit                                        ║
║                                                               ║
║   Score: 39% — NO APTO para producción                        ║
║                                                               ║
║   Fundamentos sólidos:                                        ║
║   ✅ WORM 9/8 tablas                                         ║
║   ✅ REFERENCES 113/104                                      ║
║   ✅ 109 referencias a estándares en COMMENTs                 ║
║   ✅ Access Certification completo                            ║
║                                                               ║
║   Brechas críticas:                                           ║
║   ❌ ITDR inexistente (0/3 tablas)                            ║
║   ❌ ctx_id en solo 24% de tablas                             ║
║   ❌ 73 ALTER TABLE sin integrar                              ║
║   ❌ Hash-chains en solo 2/8+ tablas WORM                     ║
║                                                               ║
║   REQUIERE: 9 correcciones críticas antes de producción       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

*Informe generado 2026-06-23. La DDL tiene fundamentos sólidos de Identity Governance (WORM, REFERENCES, estándares documentados) pero carece de los componentes de Access Alerting (ITDR) y tiene cobertura insuficiente de ctx_id (Identity Lineage). Las 9 acciones críticas deben ejecutarse en la FASE 2 de reconstrucción.*
