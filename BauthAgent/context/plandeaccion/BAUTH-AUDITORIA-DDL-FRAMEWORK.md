# BAUTH-AUDITORIA-DDL-FRAMEWORK — Análisis del Ecosistema de Tablas bAuth
## Schema `bauth` exclusivamente · 2026-06-30

**Alcance:** Solo schema `bauth`. Schema `bos_privilege` pertenece al daemon BOS (excluido).
Schema `bglobal` es del ecosistema SBOS completo (compartido, no específico de bAuth).
Schema `bcalendar` es subsistema de calendario (compartido).

---

## 1. EL "FRAMEWORK" DE BAUTH — 3 tablas

El framework de bAuth son **3 tablas** en schema `bauth` definidas en `DDL_framework_unified.sql`:

### 1.1 `bauth.framework_raw` — Fuente JSON (16 documentos)

```sql
CREATE TABLE bauth.framework_raw (
    id          serial PRIMARY KEY,
    source_name text NOT NULL UNIQUE,    -- ej: 'Policies_Authentication_Framework_v4.json'
    content     jsonb NOT NULL,          -- JSON completo del documento fuente
    loaded_at   timestamptz DEFAULT now()
);
```

**Rol:** Almacena los 16 documentos JSON fuente (NIST, ISO, PCI DSS, FIDO2, OAuth, SOC2, etc.).
Se cargan UNA vez. No se modifican en runtime.

### 1.2 `bauth.cfg_policy_library` — Biblioteca Unificada (9,142 entradas)

```sql
CREATE TABLE bauth.cfg_policy_library (
    section_id      serial PRIMARY KEY,
    section_name    text NOT NULL,
    node_type       text NOT NULL CHECK (node_type IN ('section','group','policy','config')),
    semantic_type   text CHECK (semantic_type IN ('policy','configuration','method','standard','guideline','group')),
    domain_map      text[],              -- D1-D12+SEC
    source          text NOT NULL,       -- documento origen
    standard_ref    text,                -- ej: 'NIST SP 800-63B §5.1.1'
    enforcement     text CHECK (enforcement IN ('mandatory','recommended','optional')),
    risk_level      text CHECK (risk_level IN ('critical','high','medium','low')),
    assurance_level text CHECK (assurance_level IN ('AAL1','AAL2','AAL3')),
    phishing_resistant boolean,
    mfa_required    boolean,
    content         jsonb NOT NULL,      -- estructura completa
    content_en      jsonb NOT NULL,      -- inglés
    content_es      jsonb NOT NULL,      -- español
    ...
);
```

**Rol:** Biblioteca de referencia. **NO se evalúa en runtime.** Es la fuente de verdad
normativa. Sus 9,142 entradas se generan desde `framework_raw` mediante un CTE recursivo
que descompone cada JSON en nodos jerárquicos.

**Cómo se usa:**
1. Seeds SQL leen `cfg_policy_library` → pueblan `ath_policy_d*`, `ath_config_d*`, `idn_role_d*`
2. `bauth.policy.library.search` → consulta administrativa (NO runtime)
3. Reconcile loop (`sync/mod.rs:34`) → verifica drift: `cfg_policy_library` vs `ath_policy_d*`
4. `template_validate.rs` → referencia estándares aplicables

### 1.3 `bauth.cfg_key_translation` — Traducción (221+ claves)

```sql
CREATE TABLE bauth.cfg_key_translation (
    key_en  text PRIMARY KEY,   -- clave en inglés
    key_es  text NOT NULL       -- traducción al español
);
```

**Rol:** Mapeo de claves JSON inglés→español para `content_es` en `cfg_policy_library`.

---

## 2. FLUJO COMPLETO DEL FRAMEWORK

```
┌──────────────────────────────────────────────────────────────────────┐
│  FASE 1 — CARGA (build time, una sola vez)                           │
│                                                                      │
│  16 documentos JSON fuente                                           │
│  (Policies_Authentication_Framework_v4.json,                         │
│   Authentication_Framework_v3.json, NIST_SP_800-63B.json,            │
│   ISO_27001_2022.json, PCI_DSS_4.0.json, ...)                        │
│       │                                                              │
│       └── INSERT INTO bauth.framework_raw (source_name, content)     │
│                │                                                     │
│                └── CTE recursivo (jsonb_explode)                     │
│                     │                                                │
│                     └── 9,142 filas en bauth.cfg_policy_library      │
│                          clasificadas por: node_type, semantic_type, │
│                          domain_map, enforcement, risk_level, etc.   │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  FASE 2 — GENERACIÓN DE SEEDS (build time)                           │
│                                                                      │
│  Seeds SQL consultan cfg_policy_library con filtros:                 │
│                                                                      │
│  seed_ath_policy_d3.sql:                                             │
│    WHERE semantic_type='policy' AND domain_map @> '{D3}'             │
│    → puebla bauth.ath_policy_d3 (10 políticas financieras)           │
│                                                                      │
│  seed_ath_config_d9.sql:                                             │
│    WHERE semantic_type='configuration' AND domain_map @> '{D9}'      │
│    → puebla bauth.ath_config_d9 (configs de credenciales)            │
│                                                                      │
│  seed_idn_role_d1.sql:                                               │
│    WHERE node_type='group' AND domain_map @> '{D1}'                  │
│    → puebla bauth.idn_role_d1 (4 roles lógicos)                     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  FASE 3 — RUNTIME (evaluación de acceso)                             │
│                                                                      │
│  CAPA A — XACML 3.0                   CAPA B — Reglas operativas     │
│  bauth.privilege_atom_policy           bauth.ath_policy_d1..d12      │
│  (6,782 políticas por átomo)          (~100 políticas por dominio)   │
│       │                                     │                        │
│       ├── bauth.policy.evaluate             ├── bauth.policy.domain  │
│       └── bauth.access.evaluate                   .evaluate          │
│                                                                      │
│  NOTA: cfg_policy_library NO se consulta en esta fase.               │
│        Solo las tablas operativas (privilege_atom_policy y           │
│        ath_policy_d*) son evaluadas en runtime.                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. DUPLICACIONES Y SOLAPAMIENTOS (schema `bauth`)

### 🔴 DUPLICACIÓN 1: `ath_config` vs `ath_config_d*` — DOS sistemas de configuración

| Tabla | Formato | ¿Runtime? | Handler |
|-------|---------|:---:|---------|
| `bauth.ath_config` | `(config_key, config_value, tier)` — 10 tipos: token, hash, rotation, session, rate, screen, enrollment, audit, recovery, lockout | ✅ | `framework_crud.rs:56` (`bauth.config.list`) |
| `bauth.ath_config_d1..d12` | `(config_key, config_value)` JSONB por dominio | ❌ | Sin handler activo |

**Problema:** Ambas almacenan configuración. `ath_config` tiene handler activo. `ath_config_d*` solo se puebla vía seeds pero no se consulta en runtime.

**Recomendación:** Unificar. Mantener `ath_config_d*` para config por dominio y migrar datos de `ath_config` a `bglobal.global_config` (que es la que el código Rust realmente consulta vía `load_global_config()`).

### 🟠 DUPLICACIÓN 2: `privilege_atom_policy` (Capa A) vs `ath_policy_d*` (Capa B)

| Capa | Tabla | Formato | Registros | Handler |
|------|-------|---------|:---:|---------|
| A — XACML | `bauth.privilege_atom_policy` | JSONB `bos_policy_v1` (target + condition + effect + obligations) | 6,782 | `bauth.policy.evaluate` |
| B — Operativa | `bauth.ath_policy_d1..d12` | JSONB `{"rule":"X",...}`  | ~100 | `bauth.policy.domain.evaluate` |

**No hay duplicación de datos.** Son dos capas distintas con formatos y propósitos diferentes:
- Capa A: políticas complejas con condiciones XACML por átomo
- Capa B: reglas operativas simples por dominio

Pero **conceptualmente** se solapan. Una misma regla de negocio ("transacción > $500 requiere aprobación dual") podría expresarse en ambas capas. No hay reglas de precedencia documentadas.

### 🟡 DUPLICACIÓN 3: `ath_policy` — Tabla legacy sin uso

```sql
CREATE TABLE bauth.ath_policy (
    policy_id   UUID PRIMARY KEY,
    policy_type text,    -- password, rate_limit, mfa, session...
    policy_data jsonb,
    tier        text,
    ...
);
```

**Estado:** VACÍA (0 registros). Sin handler activo. Completamente reemplazada por `ath_policy_d*` y `privilege_atom_policy`.

### 🟡 DUPLICACIÓN 4: `ath_credential_policy` vs `ath_policy_d9`

| Tabla | Formato | Qué cubre |
|-------|---------|-----------|
| `bauth.ath_credential_policy` | Columnas fijas SQL | 8 políticas: PASSWORD, TOTP, WEBAUTHN, X509_CERT, OAUTH_SECRET, API_KEY, ENCRYPTION_KEY, SIGNING_KEY |
| `bauth.ath_policy_d9` | JSONB flexible | 11 políticas: password, mfa, recovery, lockout, rotation, phishing_resistance, step_up, m2m_credentials, ciba, token_binding, auth_flow |

**Solapamiento:** PASSWORD aparece en ambas con campos diferentes. `ath_credential_policy` usa columnas fijas (`min_length`, `max_age_days`). `ath_policy_d9` usa JSONB (`password_min_length`, `rotation_days`).

### 🟡 DUPLICACIÓN 5: Tablas con prefijo `bos_` en schema `bauth`

| Tabla | Debería llamarse | Motivo |
|-------|-----------------|--------|
| `bauth.bos_permiso_logico` | Eliminar | Legacy del schema antiguo. Reemplazado por `privilege_role_atom`. |
| `bauth.bos_crypto_algorithm` | `bauth.sec_crypto_algorithm` | Prefijo `bos_` es confuso (no es schema bos). |
| `bauth.bos_rol_template_history` | `bauth.idn_role_template_history` | Consistencia con `idn_role_template`. |

---

## 4. BUG ENCONTRADO: Referencia a schema inexistente

**Archivo:** `src/server/handlers/dashboard_panels.rs:128-130`
```rust
let total: i64 = sqlx::query_scalar(
    "SELECT count(*) FROM bos_privilege.privilege_atom WHERE is_active=true"
).fetch_one(pg).await?;

let domains: Vec<(String,i64)> = sqlx::query_as(
    "SELECT d.domain_slug, count(*) FROM bos_privilege.privilege_atom a
     JOIN bos_privilege.privilege_domain d ON d.domain_id=a.domain_id
     WHERE a.is_active=true GROUP BY 1 ORDER BY 2 DESC"
).fetch_all(pg).await?;
```

**Problema:** Las queries referencian `bos_privilege.privilege_atom` pero la tabla real está en `bauth.privilege_atom`. El schema `bos_privilege` no existe en el DDL actual. Esto causará error en runtime.

**Fix:** Cambiar `bos_privilege` → `bauth` en ambas queries.

---

## 5. TABLAS POR FUNCIÓN REAL (schema `bauth`)

### 5.1 Políticas — 2 capas activas + 1 legacy

| Tabla | Capa | Runtime | Handler |
|-------|------|:---:|---------|
| `privilege_atom_policy` | A — XACML 3.0 | ✅ | `bauth.policy.evaluate` |
| `ath_policy_d1..d12` | B — Operativa | ✅ | `bauth.policy.domain.evaluate` |
| `ath_policy` | Legacy | ❌ | Ninguno |

### 5.2 Configuración — 2 activas + 1 sin handler

| Tabla | Runtime | Handler |
|-------|:---:|---------|
| `ath_config` | ✅ | `bauth.config.list` (`framework_crud.rs`) |
| `ath_config_d1..d12` | ❌ | Sin handler (solo seeds) |
| `global_config` (bglobal) | ✅ | `load_global_config()` en `db.rs` |

### 5.3 Framework — Biblioteca de referencia

| Tabla | Runtime | Handler |
|-------|:---:|---------|
| `framework_raw` | ❌ | Solo carga inicial |
| `cfg_policy_library` | ❌ | `bauth.policy.library.search` (admin) |
| `cfg_key_translation` | ❌ | Solo traducción automática |

### 5.4 Validación — RuleEngine

| Tabla | Runtime | Handler |
|-------|:---:|---------|
| `cfg_validation_rule` | ✅ | `rule_engine.rs` + `template_validate.rs` |
| `cfg_validation_log` | ✅ | WORM, INSERT en validaciones fallidas |

### 5.5 Dominios D1-D12 (tablas operativas)

| Prefijo | Cuenta | Dominio | Ejemplos |
|---------|:---:|---------|---------|
| `ath_*` | 22 | D9 (credenciales) | ath_method, ath_mfa_enrollment, ath_login_attempt, ath_binding, ath_revocation... |
| `fin_*` | 8 | D3 (financiero) | fin_transaction_type, fin_sod_rule, fin_limit, fin_decision_matrix, fin_approval_chain... |
| `fis_*` | 7 | D2 (físico) | fis_access_zone, fis_controller, fis_device, fis_location, fis_zone_method_requirement... |
| `geo_*` | 5 | D6 (geoespacial) | geo_fence, geo_trust_tier, geo_velocity_policy, geo_location_log... |
| `ses_*` | 5 | D8 (contexto) | ses_context, ses_context_switch, ses_risk_policy, ses_caep_config, ses_superuser_context |
| `aud_*` | 6 | D11 (auditoría) | aud_event, aud_review, aud_ghost_account, aud_policy_change, aud_compliance_map... |
| `blk_*` | 5 | D12 (blockchain) | blk_anchor, blk_merkle_batch, blk_merkle_leaf, blk_account, blk_reconciliation |
| `dlg_*` | 1 | D10 (delegación) | dlg_delegation |
| `net_*` | 2 | D7 (red) | net_device, net_ztna_policy |
| `zone_*` | 5 | D1 (lógico) | zone_application_map, zone_button_rule, zone_field_restriction, zone_record_rule, zone_data_policy |
| `idn_*` | 14 | Identidad | idn_role_template, idn_user_template, idn_tenant, idn_role_closure, idn_tier_policy... |
| `privilege_*` | 9 | Privilegios | privilege_atom, privilege_domain, privilege_role, privilege_role_atom, privilege_atom_policy... |
| `org_*` | 3 | Organización | org_empresa, org_sucursal, org_pos_logico |
| `sec_*` | 3 | Seguridad | sec_key_inventory, sec_key_rotation, sec_key_recovery |

---

## 6. CORRECCIONES RECOMENDADAS

### Fase 1 — Inmediato (bugs)
- [ ] **BUG:** Corregir `dashboard_panels.rs` — cambiar `bos_privilege` → `bauth` (2 queries)
- [ ] **BUG:** Corregir comentarios en `parser.rs:4` y `rule.rs:5` — `bos_atom_policy` → `privilege_atom_policy`

### Fase 2 — Documentar
- [ ] Documentar las DOS capas de políticas (A: XACML, B: Operativa) en MANUAL_DB_DDL.md
- [ ] Documentar que `cfg_policy_library` es SOLO referencia, no runtime
- [ ] Agregar `COMMENT ON TABLE ... IS '[DEPRECADO]'` en `ath_policy` y `bos_permiso_logico`

### Fase 3 — Unificar
- [ ] Decidir: ¿`ath_config` o `ath_config_d*` o `bglobal.global_config`? Unificar en UNO
- [ ] Migrar `ath_credential_policy` (columnas fijas) → `ath_policy_d9` (JSONB)
- [ ] Renombrar `bos_crypto_algorithm` → `sec_crypto_algorithm`
- [ ] Renombrar `bos_rol_template_history` → `idn_role_template_history`

### Fase 4 — Limpiar
- [ ] Eliminar `ath_policy` (tabla vacía, sin handler)
- [ ] Eliminar `bos_permiso_logico` (legacy, sin handler)
- [ ] Eliminar `ath_config_d*` si se decide usar solo `bglobal.global_config`

---

*BAUTH-AUDITORIA-DDL-FRAMEWORK.md v1.0 · 2026-06-30*
