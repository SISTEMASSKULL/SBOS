# A.76 — Etapa 3: Validación en VPS (SBOSDB)

**Versión:** 1.0.0 · **Fecha:** 2026-08-02 · **Prerrequisito:** A.75 Capa 3 completada

**DONE cuando:** cada query de §2 ejecuta sin error en SBOSDB y retorna resultado coherente.

**Acceso VPS:** `ssh root@13.140.128.230` · DSN: `postgres://postgres:postgres@localhost:15432/SBOSDB`

---

## §1 Verificación de tablas canónicas en SBOSDB

Ejecutar antes de iniciar las queries de §2:

```sql
-- Confirmar que las 36 tablas legacy ya NO existen
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'bauth'
  AND table_name IN (
    'idn_role_template','idn_role_closure','idn_user_template',
    'idn_user_role','ath_policy','ath_policy_d','ath_login_attempt',
    'ath_method','ath_config','ath_mfa_enrollment','ath_password_history',
    'aud_event','aud_policy_change','org_empresa','org_sucursal',
    'org_pos_logico','privilege_atom','privilege_role','privilege_role_atom',
    'privilege_domain','privilege_atom_policy','ses_context','sync_log'
  );
-- Esperado: 0 filas
```

```sql
-- Confirmar que las tablas canónicas de destino existen
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'bauth'
  AND table_name IN (
    'idn_roles_rol_hierarchical','idn_roles_rol_closure','idn_user',
    'auth_policy','auth_attempt_log','auth_method','auth_config',
    'auth_credential','auth_credential_secret','auth_compliance_map',
    'idn_roles_template_history','privilege_resource_atom','privilege_verb_conflict',
    'ses_session_log','ses_caep_event_log','auth_crypto_algorithm',
    'sig_key','auth_device','auth_device_posture','cfg_policy_library'
  )
ORDER BY table_name;
-- Esperado: 20 filas
```

---

## §2 Queries de validación por capa

### Capa 1 — db/

```sql
-- Equivalente a lo que hacía db/mod.rs con idn_role_template
SELECT role_id, role_name, tier, status FROM bauth.idn_roles_rol_hierarchical LIMIT 5;

-- Equivalente a db/versioning.rs con idn_roles_ver_b*
SELECT log_id, changed_by, changed_at FROM bauth.idn_roles_ver_b01_audit_log LIMIT 3;
SELECT proposal_id, status FROM bauth.idn_roles_ver_b03_approval_queue LIMIT 3;
```

### Capa 2 — domain/ + bitmask/

```sql
-- Equivalente a bitmask/closure.rs con idn_role_closure
SELECT ancestor_id, descendant_id, depth FROM bauth.idn_roles_rol_closure LIMIT 5;

-- Equivalente a domain/rule_engine.rs con cfg_validation_rule
SELECT policy_key, policy_value FROM bauth.cfg_policy_library LIMIT 5;

-- Equivalente a domain/policy/ath_loader.rs (resultado de D01)
SELECT policy_id, policy_type, domain_code FROM bauth.auth_policy LIMIT 5;

-- Equivalente a saga/actions/login.rs con ath_login_attempt
SELECT attempt_id, user_id, result, attempted_at FROM bauth.auth_attempt_log LIMIT 5;
```

### Capa 3 — handlers/

```sql
-- org_crud.rs — resultado de D04
SELECT entity_id, entity_type, display_name FROM bauth.idn_identity_entity LIMIT 5;

-- access_evaluate.rs
SELECT atom_id, atom_slug, domain_code FROM bauth.privilege_resource_atom LIMIT 5;

-- role_template.rs
SELECT role_id, role_name, depth FROM bauth.idn_roles_rol_hierarchical LIMIT 5;

-- identidad_crud.rs — resultado de D03
SELECT user_id, username, status FROM bauth.idn_user LIMIT 5;

-- domain_audit.rs — resultado de D02
SELECT event_id, event_type, occurred_at FROM bauth.ses_caep_event_log LIMIT 3;
```

---

## §3 Checklist de validación

| Query | Ejecuta sin error | Resultado coherente | Observaciones |
|-------|:-----------------:|:-------------------:|---------------|
| §1 — tablas legacy inexistentes (0 filas) | ⬜ | ⬜ | |
| §1 — tablas canónicas presentes (20 filas) | ⬜ | ⬜ | |
| Capa 1 — idn_roles_rol_hierarchical | ⬜ | ⬜ | |
| Capa 1 — idn_roles_ver_b01/b03 | ⬜ | ⬜ | |
| Capa 2 — idn_roles_rol_closure | ⬜ | ⬜ | |
| Capa 2 — cfg_policy_library | ⬜ | ⬜ | |
| Capa 2 — auth_policy | ⬜ | ⬜ | |
| Capa 2 — auth_attempt_log | ⬜ | ⬜ | |
| Capa 3 — idn_identity_entity | ⬜ | ⬜ | |
| Capa 3 — privilege_resource_atom | ⬜ | ⬜ | |
| Capa 3 — idn_roles_rol_hierarchical (handlers) | ⬜ | ⬜ | |
| Capa 3 — idn_user | ⬜ | ⬜ | |
| Capa 3 — ses_caep_event_log | ⬜ | ⬜ | |

**DONE:** todos los ⬜ → ✅

---

## §4 Criterio de falla y retroceso

Si una query falla en SBOSDB:
1. Anotar el error exacto en esta tabla
2. Verificar si la tabla canónica tiene las columnas esperadas (`\d bauth.<tabla>`)
3. Si faltan columnas: proponer ALTER TABLE → escalar al humano (HITL) antes de ejecutar
4. Si la tabla no existe: revisar si la decisión D0X fue aplicada al DDL

---

*A.76 v1.0.0 · Validación Etapa 3 · bAuth · 2026-08-02*
