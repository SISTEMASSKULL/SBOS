# A.75 — Etapa 2: Refactor por Capas

**Versión:** 1.0.0 · **Fecha:** 2026-08-02 · **Prerrequisito:** A.74 §3 decisiones todas resueltas

**Filosofía:** cada archivo se trabaja en dos pasos: (1) **ELIMINAR** todo código que use tablas phantom — sin excepciones, sin wrappers de compatibilidad; (2) **REESCRIBIR** la funcionalidad válida contra el DDL canónico, modularizada (función ≤ 50 líneas, módulo ≤ 800 líneas, parámetros tipados explícitamente).

**DONE cuando:** `cargo check` verde + 0 referencias a las 36 tablas phantom en `src/`.

---

## Orden de ejecución (de adentro hacia afuera)

```
Capa 1 → Capa 2 → Capa 3
db/     domain/   handlers/
        bitmask/
        saga/
        sync/
```

Cada capa termina con `cargo check` verde antes de iniciar la siguiente.

---

## §1 Capa 1 — `db/` (4 archivos)

**Objetivo:** la capa de acceso a datos usa solo nombres canónicos.

| Archivo | Tablas legacy que contiene | Acción |
|---------|---------------------------|--------|
| `db/mod.rs` | `idn_role_template`, `idn_user_template`, `ses_context` | Renombrar + ajustar structs |
| `db/approval.rs` | `privilege_role`, `aud_event` | Renombrar + resolver D02 |
| `db/version_store.rs` | `idn_roles_ver_b*` | Mapear a tablas `_b01_`/`_b03_` |
| `db/versioning.rs` | `idn_roles_ver_b*`, `idn_role_template` | Renombrar + ajustar structs |

**Criterio DONE Capa 1:**
```bash
grep -rn "idn_role_template\|idn_user_template\|ses_context\|privilege_role\|aud_event\|ver_b\b" \
  src/db/ --include="*.rs"
# → 0 resultados
cargo check 2>&1 | grep -c "error"
# → 0
```

---

## §2 Capa 2 — `domain/` + `bitmask/` + `saga/` + `sync/` (20 archivos)

**Objetivo:** la lógica de dominio no contiene SQL con nombres legacy.

### Subcapa 2A — `bitmask/` (2 archivos, ~10 refs)

| Archivo | Tablas legacy | Acción |
|---------|--------------|--------|
| `bitmask/closure.rs` | `idn_role_closure`, `privilege_atom` | → `idn_roles_rol_closure`, `privilege_resource_atom` |
| `bitmask/conflict.rs` | `privilege_atom_policy`, `fin_sod_rule` | → D05 + `privilege_verb_conflict` |

### Subcapa 2B — `domain/policy/` + `domain/` (8 archivos, ~60 refs)

| Archivo | Tablas legacy | Acción |
|---------|--------------|--------|
| `domain/policy/ath_loader.rs` | `ath_policy_d` (24 refs) | → resolver D01 |
| `domain/policy_chain.rs` | `ath_policy`, `ses_context` | → `auth_policy`, D06 |
| `domain/rule_engine.rs` | `cfg_validation_rule` | → `cfg_policy_library` |
| `domain/audit_domain.rs` | `aud_event`, `aud_policy_change` | → D02 |
| `domain/startup.rs` | `idn_role_template`, `privilege_domain` | → D05 + canónico |
| `domain/merge.rs` | `idn_role_template` | → `idn_roles_rol_hierarchical` |
| `domain/calendar_alarm.rs` | `ses_context` | → D06 |
| `domain/user_notify.rs` | `org_empresa`, `org_sucursal` | → D04 |

### Subcapa 2C — `saga/` + `sync/` (4 archivos, ~20 refs)

| Archivo | Tablas legacy | Acción |
|---------|--------------|--------|
| `saga/actions/login.rs` | `ath_login_attempt`, `ses_context` | → `auth_attempt_log`, D06 |
| `saga/registry.rs` | `idn_role_template`, `privilege_atom` | → canónicos |
| `sync/mod.rs` | `idn_user_template`, `sync_log` | → D03 |
| `sync/retention.rs` | `sync_log`, `org_empresa` | → D04 |

**Criterio DONE Capa 2:**
```bash
grep -rn "ath_policy\|idn_role_template\|privilege_atom\b\|ses_context\|aud_event\|org_empresa" \
  src/domain/ src/bitmask/ src/saga/ src/sync/ --include="*.rs"
# → 0 resultados
cargo check 2>&1 | grep -c "error"
# → 0
```

---

## §3 Capa 3 — `server/handlers/` (40 archivos)

**Objetivo:** todos los handlers usan tablas canónicas.

Agrupados por volumen de cambio:

### Alto impacto (>5 refs legacy cada uno)

| Archivo | Tablas legacy principales |
|---------|--------------------------|
| `handlers/domain_crud.rs` | `privilege_domain`, `idn_role_template` |
| `handlers/policy_admin.rs` | `ath_policy_d`, `ath_policy` |
| `handlers/policy_domain.rs` | `ath_policy_d`, `privilege_domain` |
| `handlers/access_evaluate.rs` | `privilege_atom`, `ses_context` |
| `handlers/role_template.rs` | `idn_role_template`, `idn_user_template` |
| `handlers/identidad_crud.rs` | `idn_user_template`, `org_empresa` |
| `handlers/org_crud.rs` | `org_empresa`, `org_sucursal`, `org_pos_logico` |
| `handlers/org_structure.rs` | `org_empresa`, `org_sucursal`, `org_pos_logico` |

### Medio impacto (2-5 refs legacy)

`handlers/inheritance_evaluate.rs` · `handlers/domain_audit.rs` · `handlers/sod_check.rs`
· `handlers/user_template.rs` · `handlers/user_list.rs` · `handlers/tenant_list.rs`
· `handlers/framework_crud.rs` · `handlers/sync_reconcile.rs` · `handlers/scim_server.rs`

### Bajo impacto (1 ref legacy)

`handlers/domain_biometric.rs` · `handlers/device_identity.rs` · `handlers/context_plane.rs`
· `handlers/token_issue.rs` · `handlers/idp_external.rs` · `handlers/oidc_provider.rs`
_(+10 handlers con 1 referencia cada uno)_

**Criterio DONE Capa 3 (= DONE total):**
```bash
# 0 tablas phantom en todo el código
for t in ath_policy idn_role_template idn_user_template ses_context privilege_atom\  
         aud_event org_empresa org_sucursal privilege_domain idn_role_closure; do
  n=$(grep -rn "$t" src/ --include="*.rs" | wc -l)
  echo "$t: $n"
done
# → todo 0
cargo check 2>&1 | grep -c "error"
# → 0
```

---

## §4 Checklist de cierre por capa

| Capa | cargo check | 0 refs legacy | Commit |
|------|:-----------:|:-------------:|--------|
| 1 — db/ | ⬜ | ⬜ | `refactor(bauth-db): capa db/ alineada con DDL canónico` |
| 2A — bitmask/ | ⬜ | ⬜ | `refactor(bauth-bitmask): tablas canónicas` |
| 2B — domain/ | ⬜ | ⬜ | `refactor(bauth-domain): tablas canónicas` |
| 2C — saga/sync/ | ⬜ | ⬜ | `refactor(bauth-saga): tablas canónicas` |
| 3 — handlers/ | ⬜ | ⬜ | `refactor(bauth-handlers): tablas canónicas + structs` |

---

*A.75 v1.0.0 · Refactor Etapa 2 · bAuth · 2026-08-02*
