# A.61 — Diseño de Base de Datos del Motor de Roles
## Tablas, índices, patrones de consulta y arquitectura de almacenamiento para átomos y asignaciones

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [1.03 Átomos](../1.03_MANUAL-ATOMOS-v1.0.md) · [1.04 BitMask](../1.04_MANUAL-BITMASK-v1.0.md)
**Fuentes:** Manual 1.03 §2-§8 · Manual 1.04 §3-§10 · Manual 1.09 §9-§14 · A.58 (absorbido)
**Normas base:** OASIS XACML 3.0 · ANSI INCITS 359-2004 (RBAC) · ISO 27001:2022 A.8.15

---

## §1 Propósito

Documenta el diseño completo de la base de datos para el Motor de Roles: tablas existentes
que se conservan, tablas nuevas, índices, patrones de consulta y estrategia de almacenamiento.
Es el análogo de A.56 para el dominio de roles. Absorbe A.58 (tablas del motor de roles).

---

## §2 Tablas existentes (se conservan)

| Tabla | Filas actuales | PK | Rol en el Motor de Roles |
|---|---|---|---|
| `privilege_atom` | 1,059 (6,000 diseñadas) | `(app_code, group_code, atom_code)` | Catálogo. El motor consulta y atomc actualiza. |
| `privilege_role_atom` | Variable | `(role_id, atom_code)` | Asignación átomo→rol. El motor lee y escribe. |
| `privilege_user_atom` | Variable | — | Sobrescrituras usuario→átomo (excepciones). |
| `idn_role_template` | 548 | `(id)` | Roles. El motor lee y escribe (CRUD). |
| `idn_role_closure` | 1,673 | `(ancestro_id, descendiente_id)` | Herencia DAG. El motor consulta. |
| `idn_user_role` | Variable | `(assignment_id)` | Asignación usuario→rol. El motor lee y escribe. |
| `privilege_atom_compiled` | 0 (L0) | `(compiled_id)` | IR compilado. atomc escribe. El motor consulta. |

**Total: 7 tablas existentes.** El Motor de Roles opera sobre todas ellas.

---

## §3 Tablas nuevas (idn_rolestpl_*)

Tres tablas nuevas, análogas a las del Motor de Identidad (A.56 §3):

| Tabla | Análogo en Identidad | Propósito |
|---|---|---|
| `idn_rolestpl_atom_config` | `idn_identidad_atributo` | Atributos extensibles de átomos (norma, severidad, compilación) |
| `idn_rolestpl_atom_history` | `idn_identidad_atributo_history` | Trazabilidad de cambios (append-only, particionado por mes) |
| `idn_rolestpl_requisito` | `idn_identidad_requisito` | Completitud mínima por dominio y nivel |

### 3.1 `idn_rolestpl_atom_config`

```sql
CREATE TABLE bauth.idn_rolestpl_atom_config (
    id            BIGSERIAL PRIMARY KEY,
    atom_code     INT NOT NULL REFERENCES bauth.privilege_atom(atom_code),
    category      TEXT NOT NULL,
    attr_key      TEXT NOT NULL,
    type          TEXT,
    value_text    TEXT,
    value_data    JSONB,
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ix_rolestpl_config_atom ON bauth.idn_rolestpl_atom_config (atom_code);
```

**Escala estimada:** 6,000 átomos × ~5 atributos de configuración cada uno = **~30,000 filas**.
Tabla pequeña. No necesita particionamiento.

### 3.2 `idn_rolestpl_atom_history`

```sql
CREATE TABLE bauth.idn_rolestpl_atom_history (
    history_id    BIGSERIAL,
    atom_code     INT NOT NULL,
    change_type   TEXT NOT NULL CHECK (change_type IN ('COMPILE','ASSIGN','REVOKE','ACTIVATE','DEACTIVATE')),
    old_state     JSONB,
    new_state     JSONB,
    changed_by    UUID NOT NULL,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id        TEXT NOT NULL,
    PRIMARY KEY (history_id, changed_at)
) PARTITION BY RANGE (changed_at);
CREATE INDEX ix_rolestpl_history_atom ON bauth.idn_rolestpl_atom_history (atom_code, changed_at DESC);
```

**Escala estimada:** cada compilación de atomc + cada asignación/revocación genera una fila.
~10,000 cambios/año para 6,000 átomos. Particionado por mes. ~50MB/año.

### 3.3 `idn_rolestpl_requisito`

```sql
CREATE TABLE bauth.idn_rolestpl_requisito (
    id            BIGSERIAL PRIMARY KEY,
    dominio       TEXT NOT NULL,
    nivel         INT NOT NULL DEFAULT 1,
    attr_key      TEXT NOT NULL,
    requerido     BOOLEAN NOT NULL DEFAULT true,
    UNIQUE (dominio, nivel, attr_key)
);
```

**Escala fija:** ~40 filas (4 dominios × 2 niveles × ~5 atributos cada uno).
No necesita índice adicional.

---

## §4 Patrones de consulta del Motor de Roles

### 4.1 Consulta más frecuente: átomos de un rol

```sql
SELECT a.atom_slug, a.atom_code, a.atom_position, a.domain_code, ra.allowed
FROM bauth.privilege_role_atom ra
JOIN bauth.privilege_atom a ON ra.atom_code = a.atom_code
WHERE ra.role_id = 'cajero' AND ra.allowed = true;
```

**Índice utilizado:** PK de `privilege_role_atom (role_id, atom_code)`. <1ms para cualquier rol.

### 4.2 Usuarios de un rol (vía herencia DAG)

```sql
SELECT u.uuid, u.username, ur.role_id
FROM bauth.idn_user_role ur
JOIN bauth.idn_user_template u ON ur.user_uuid = u.uuid
WHERE ur.role_id = 'cajero'
  AND ur.is_active = true
  AND ur.valid_from <= now()
  AND (ur.valid_until IS NULL OR ur.valid_until > now());
```

### 4.3 Átomos efectivos de un usuario (merge OR + herencia)

```sql
-- 1. Obtener todos los roles activos del usuario (incluyendo temporales)
-- 2. Para cada rol, obtener sus átomos + átomos de ancestros (closure table)
-- 3. OR de todos los atom_code → UserBitMask
```

Esta consulta se ejecuta UNA VEZ al promover sesión (ctx.promote) y se cachea en Redis.
No se ejecuta en cada request. El FastPath (<0.5ns) opera sobre el UserBitMask cacheado.

### 4.4 Auditoría: historial de cambios de un rol

```sql
SELECT * FROM bauth.idn_rolestpl_atom_history
WHERE atom_code IN (SELECT atom_code FROM bauth.privilege_role_atom WHERE role_id = 'cajero')
ORDER BY changed_at DESC;
```

Particionado por mes. Solo toca la partición del período consultado.

---

## §5 Comparación con el Motor de Identidad

| | Motor de Identidad (A.56) | Motor de Roles (este anexo) |
|---|---|---|
| **Tabla principal** | `idn_identidad_entidad` + `idn_identidad_atributo` | `privilege_atom` + `privilege_role_atom` (existentes) |
| **Atributos extensibles** | `idn_identidad_atributo` (EAV) | `idn_rolestpl_atom_config` (EAV) |
| **Trazabilidad** | `idn_identidad_atributo_history` | `idn_rolestpl_atom_history` |
| **Completitud mínima** | `idn_identidad_requisito` | `idn_rolestpl_requisito` |
| **Escala de datos** | 165M filas (1,000 empresas × 5,500 items × 30 campos) | ~3.3M filas (548 roles × 6,000 átomos) |
| **Particionamiento** | HASH(tenant_id) en atributos, RANGE mensual en history | RANGE mensual en history. Config no necesita partición. |
| **Índices GIN** | Sí (value_normalized, value_search) | No necesita (consultas por PK compuesta, no fuzzy) |

El Motor de Roles es **dos órdenes de magnitud más pequeño** que el Motor de Identidad.
No necesita índices GIN ni columnas generadas. Sus consultas son por PK compuesta o
por closure table. La escala máxima (~3.3M filas en privilege_role_atom) es manejable
con índices B-tree estándar.

---

## §6 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §2 (tablas existentes) | 1.03 §2-§6 · 2.17 §4 |
| §3 (tablas nuevas) | 2.17 §4.1-§4.3 |
| §4 (patrones de consulta) | 2.17 §3-§4 |
| §5 (comparación con Identidad) | A.56 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Absorbe A.58. 7 tablas existentes + 3 nuevas. Patrones de consulta. Comparación con Motor de Identidad (~3.3M vs 165M filas). |
