# A.76 — Etapa 3: Validación en VPS (SBOSDB)

**Versión:** 1.1.0 · **Fecha:** 2026-08-02 · **Prerrequisito:** A.75 Capa 3 completada

**DONE cuando:** cada query de §2 ejecuta sin error en SBOSDB y retorna resultado coherente.

**Acceso VPS:** `ssh root@13.140.128.230` · DSN: `postgres://postgres:postgres@localhost:15432/SBOSDB`

---

## §1 Verificación de tablas canónicas en SBOSDB

### §1a — Tablas legacy deben estar AUSENTES

```sql
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
```

**Resultado esperado:** 0 filas  
**Resultado VPS (2026-08-02):** ✅ `(0 rows)` — ninguna tabla legacy existe

---

### §1b — Tablas canónicas deben estar PRESENTES (20)

```sql
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
```

**Resultado esperado:** 20 filas  
**Resultado VPS (2026-08-02):** ✅ `(20 rows)` — todas presentes

---

## §2 Queries de validación por capa

> **NOTA sobre columnas:** Las columnas usadas abajo son las **reales** del DDL v2.12.0 en SBOSDB,
> verificadas con `\d` el 2026-08-02. Las columnas de la versión v1.0.0 de este documento
> contenían nombres asumidos que no coincidían con el DDL real.

### Capa 1 — db/

```sql
-- idn_roles_rol_hierarchical (reemplaza idn_role_template)
-- Columnas reales: id, name JSONB, tier (enum), status (enum), depth
SELECT id AS role_id, name->>'es' AS role_name, tier::text, status::text
FROM bauth.idn_roles_rol_hierarchical LIMIT 5;

-- idn_roles_ver_b01_audit_log
-- Columnas reales: id (PK), entity_id, changed_by, ctx_id, sys_period (tstzrange)
-- NOTA: no tiene 'log_id' ni 'changed_at' — usa 'id' y 'sys_period'
SELECT id, changed_by, ctx_id FROM bauth.idn_roles_ver_b01_audit_log LIMIT 3;

-- idn_roles_ver_b03_approval_queue
-- Columnas reales: id (PK), entity_id, status (ver_proposal_status_enum), created_at
-- NOTA: no tiene 'proposal_id' — usa 'id'
SELECT id, status FROM bauth.idn_roles_ver_b03_approval_queue LIMIT 3;
```

**Resultado VPS (2026-08-02):**
- `idn_roles_rol_hierarchical` ✅ — 5 roles: Asegurado/Titular, Analista RRHH, Consignatario, Supervisor Tienda, Beneficiario Cooperación Internacional
- `idn_roles_ver_b01_audit_log` ✅ — 0 filas (tabla vacía, sin cambios auditados aún)
- `idn_roles_ver_b03_approval_queue` ✅ — 0 filas (sin propuestas pendientes)

---

### Capa 2 — domain/ + bitmask/

```sql
-- idn_roles_rol_closure (reemplaza idn_role_closure)
SELECT ancestor_id, descendant_id, depth FROM bauth.idn_roles_rol_closure LIMIT 5;

-- cfg_policy_library
-- Columnas reales: section_id, section_name, json_path, node_type, source, content JSONB
-- NOTA: no tiene 'policy_key'/'policy_value' — usa 'section_name'/'json_path'/'content'
SELECT section_id, section_name, json_path, node_type FROM bauth.cfg_policy_library LIMIT 5;

-- auth_policy (reemplaza ath_policy_dN)
-- Columnas reales: policy_id, name, loa_required, active
SELECT policy_id, name AS policy_name, loa_required, active FROM bauth.auth_policy LIMIT 5;

-- auth_attempt_log (reemplaza ath_login_attempt)
-- Columnas reales: attempt_id, user_id, outcome, attempted_at
SELECT attempt_id, user_id, outcome AS result, attempted_at FROM bauth.auth_attempt_log LIMIT 5;
```

**Resultado VPS (2026-08-02):**
- `idn_roles_rol_closure` ✅ — 0 filas (closure sin poblar, esperable sin roles asignados)
- `cfg_policy_library` ✅ — 5 secciones: authenticationFramework, PoliciesAuthenticationFramework, password_policy_rev4, fido2_ctap_2_2, nist_pqc_standardization
- `auth_policy` ✅ — 0 filas (sin políticas cargadas aún)
- `auth_attempt_log` ✅ — 0 filas (sin intentos registrados aún)

---

### Capa 3 — handlers/

```sql
-- idn_identity_entity (org_crud.rs — D04)
-- Columnas reales: entity_id, level (entidad_nivel_enum), name JSONB, status
-- NOTA: no tiene 'entity_type' ni 'display_name' — usa 'level' y 'name'
SELECT entity_id, level::text, name->>'es' AS nombre FROM bauth.idn_identity_entity LIMIT 5;

-- privilege_resource_atom (access_evaluate.rs)
-- Columnas reales: id, resource, operation, domain_code (smallint), evaluation_path
-- NOTA: no tiene 'atom_id' ni 'atom_slug' — usa 'id', 'resource', 'operation'
SELECT id AS pra_id, resource, operation, domain_code FROM bauth.privilege_resource_atom LIMIT 5;

-- idn_roles_rol_hierarchical (role_template.rs — handlers)
SELECT id AS role_id, name->>'es' AS role_name, depth FROM bauth.idn_roles_rol_hierarchical LIMIT 5;

-- idn_user (identidad_crud.rs — D03)
-- Columnas reales: user_id, username, status
SELECT user_id, username, status FROM bauth.idn_user LIMIT 5;

-- ses_caep_event_log (domain_audit.rs — D02)
-- Columnas reales: id (PK), event_type, received_at
-- NOTA: no tiene 'event_id' — usa 'id'
SELECT id AS event_id, event_type, received_at FROM bauth.ses_caep_event_log LIMIT 3;
```

**Resultado VPS (2026-08-02):**
- `idn_identity_entity` ✅ — 1 fila: `actor | Sistema bAuth (actor interno)`
- `privilege_resource_atom` ✅ — 0 filas (sin mapeos recurso→átomo cargados)
- `idn_roles_rol_hierarchical (handlers)` ✅ — 5 roles (igual que Capa 1)
- `idn_user` ✅ — 0 filas (sin usuarios cargados aún)
- `ses_caep_event_log` ✅ — 0 filas (sin eventos CAEP recibidos)

---

## §3 Checklist de validación — COMPLETADO

| Query | Ejecuta sin error | Resultado coherente | Observaciones |
|-------|:-----------------:|:-------------------:|---------------|
| §1a — tablas legacy inexistentes (0 filas) | ✅ | ✅ | 0 filas confirmado |
| §1b — tablas canónicas presentes (20 filas) | ✅ | ✅ | 20/20 presentes |
| Capa 1 — idn_roles_rol_hierarchical | ✅ | ✅ | 5 roles activos |
| Capa 1 — idn_roles_ver_b01_audit_log | ✅ | ✅ | 0 filas (vacía, OK) |
| Capa 1 — idn_roles_ver_b03_approval_queue | ✅ | ✅ | 0 filas (vacía, OK) |
| Capa 2 — idn_roles_rol_closure | ✅ | ✅ | 0 filas (sin asignaciones) |
| Capa 2 — cfg_policy_library | ✅ | ✅ | 5 secciones de política |
| Capa 2 — auth_policy | ✅ | ✅ | 0 filas (sin políticas aún) |
| Capa 2 — auth_attempt_log | ✅ | ✅ | 0 filas (sin intentos) |
| Capa 3 — idn_identity_entity | ✅ | ✅ | 1 actor interno del sistema |
| Capa 3 — privilege_resource_atom | ✅ | ✅ | 0 filas (sin mapeos) |
| Capa 3 — idn_roles_rol_hierarchical (handlers) | ✅ | ✅ | 5 roles activos |
| Capa 3 — idn_user | ✅ | ✅ | 0 filas (sin usuarios) |
| Capa 3 — ses_caep_event_log | ✅ | ✅ | 0 filas (sin eventos CAEP) |

**ESTADO: 14/14 ✅ — A.76 COMPLETADO**

---

## §4 Correcciones de columnas detectadas (vs v1.0.0)

Los siguientes nombres de columna en la v1.0.0 de este documento eran incorrectos.
Corregidos en v1.1.0 con los nombres reales verificados en SBOSDB:

| Tabla | Columna v1.0.0 (incorrecta) | Columna real DDL v2.12.0 |
|---|---|---|
| `idn_roles_ver_b01_audit_log` | `log_id` | `id` |
| `idn_roles_ver_b01_audit_log` | `changed_at` | `sys_period` (tstzrange) |
| `idn_roles_ver_b03_approval_queue` | `proposal_id` | `id` |
| `cfg_policy_library` | `policy_key` | `section_name` / `json_path` |
| `cfg_policy_library` | `policy_value` | `content` (JSONB) |
| `idn_identity_entity` | `entity_type` | `level` (entidad_nivel_enum) |
| `idn_identity_entity` | `display_name` | `name` (JSONB → `name->>'es'`) |
| `privilege_resource_atom` | `atom_id` | `id` |
| `privilege_resource_atom` | `atom_slug` | `resource` + `operation` |
| `ses_caep_event_log` | `event_id` | `id` |

---

## §5 Criterio de falla y retroceso

Si una query falla en SBOSDB:
1. Anotar el error exacto en esta tabla
2. Verificar si la tabla canónica tiene las columnas esperadas (`\d bauth.<tabla>`)
3. Si faltan columnas: proponer ALTER TABLE → escalar al humano (HITL) antes de ejecutar
4. Si la tabla no existe: revisar si la decisión D0X fue aplicada al DDL

---

*A.76 v1.1.0 · Validación Etapa 3 COMPLETADA · bAuth · 2026-08-02*
