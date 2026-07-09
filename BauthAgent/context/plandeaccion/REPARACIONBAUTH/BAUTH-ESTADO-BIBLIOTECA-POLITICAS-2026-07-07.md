# BAUTH — Estado de la Biblioteca de Políticas
**Versión:** 1.0 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Propósito:** Registro de lo que se hizo, las herramientas que existen, y el impacto en el DDL

---

## 1. QUÉ SE HIZO — Resumen ejecutivo

Se transformó la tabla `cfg_policy_library` de un almacén plano de nodos en un
**árbol jerárquico semántico completo** que sirve como catálogo normativo de ingredientes
para componer roles y usuarios en bAuth.

### Fuentes de datos analizadas
| Archivo | Tamaño | Contenido |
|---|---|---|
| `Policies_Authentication_Framework.json` | 104 KB | Marco de políticas de autenticación v3.0.0 |
| `Authentication_Framework.json` | 603 KB | Framework de autenticación v2.0.0 — 36 grupos |

Ambos archivos usan formato JSON5 (con comentarios `/* */` y `//`).
Se parsearon con la biblioteca `json5` de Python y se analizaron 2,821 nodos atómicos.

### Migraciones ejecutadas en VPS (sbos-data/postgresql-0 · SBOS_db)

| Migración | Qué hizo | Resultado |
|---|---|---|
| `bauth_40__cfg_policy_library_ltree.sql` | Agregó columna `path ltree` · 6 columnas operacionales · 4 índices | 9,184 filas con path normalizado |
| `bauth_41__cfg_policy_library_level_type.sql` | Agregó `level_type` · clasificó todos los nodos · corrigió `value_type` · pobló `default_value` | 9,184 nodos clasificados |
| `bauth_42__policy_set_split_and_compose.sql` | Separó POLICY_SET vs POLICY (XACML 3.0) · creó funciones de composición · creó vista | 651 POLICY_SET + 559 POLICY separados |

---

## 2. ESTADO ACTUAL DE cfg_policy_library

### Jerarquía (alineada con XACML 3.0 · NIST SP 800-207)

```
FRAMEWORK  →  DOMAIN  →  POLICY_SET  →  POLICY  →  RULE[]  →  PROPERTY[]
```

| level_type | Nodos | Descripción |
|---|---|---|
| FRAMEWORK | 58 | Raíces de árbol (authenticationFramework, PoliciesAuthenticationFramework) |
| DOMAIN | 145 | Agrupaciones temáticas — depth ≤ 2 |
| POLICY_SET | 651 | Contenedor de sub-políticas (XACML PolicySet) |
| POLICY | 559 | Política evaluable — contiene solo RULE directamente |
| RULE | 2,275 | Regla atómica: condición + efecto |
| PROPERTY | 5,496 | Atributo con valor: tipo + default + opciones |
| **Total** | **9,184** | |

### PROPERTY — distribución de tipos de valor

| value_type | Count | Widget UI |
|---|---|---|
| TEXT | 3,443 | TextInput |
| BOOLEAN | 1,568 | Toggle |
| INTEGER | 366 | NumberInput |
| FLOAT | 119 | NumberInput (decimal) |

### Dominios clasificados (domain_map — índice GIN)

| Dominio | Nodos | BitMask | Descripción |
|---|---|---|---|
| D1–D12 | varía | ✅ evaluado | Dominios funcionales por rol/usuario |
| **D99** | **447** | ❌ excluido | Dominio Administrativo Global — políticas que gobiernan todo el sistema |

**D99** = criptografía global, resistencia cuántica, gestión de claves, auditoría base, metadatos.
No entra al BitMask. Es configuración del sistema — no permiso de usuario.
Ver: `BAUTH-D99-DOMINIO-GLOBAL.md`

---

## 3. HERRAMIENTAS DISPONIBLES EN LA BASE DE DATOS

### Funciones PostgreSQL

```sql
-- Componer un subárbol como JSONB anidado (para presentación, diff, exportación)
SELECT bauth.fn_compose_tree(
    'policiesAuthenticationFramework.PoliciesAuthenticationFramework.modern_authentication_policies.webauthn_fido2'::ltree,
    NULL  -- max_depth opcional
);

-- Descomponer JSONB anidado → filas en cfg_policy_library (para importar políticas nuevas)
SELECT bauth.fn_decompose_tree(
    '{"nueva_politica": {"enabled": {"_type": "BOOLEAN", "_value": "true"}}}'::jsonb,
    'policiesAuthenticationFramework.PoliciesAuthenticationFramework.mi_dominio'::ltree,
    'manual_import_v1'
);
```

### Vista de navegación

```sql
-- Árbol indentado — ORDER BY path preserva el orden DFS del JSON original
SELECT * FROM bauth.v_policy_tree
WHERE path <@ 'policiesAuthenticationFramework'::ltree;
```

### Queries por dominio (índice GIN — eficiente)

```sql
-- Todos los nodos de un dominio
SELECT repeat('  ', depth-1) || section_name AS nodo, level_type, value_type, default_value
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D7']
ORDER BY path;

-- Solo nodos evaluables de D99 (configuración global)
SELECT * FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D99']
  AND level_type IN ('RULE', 'PROPERTY')
ORDER BY path;
```

---

## 4. NUEVO MÉTODO JSON-RPC — bauth.config.global_get

bAuth actúa como **PAP + PIP** (NIST SP 800-207): emite y distribuye las políticas D99
a todos los daemons del ecosistema SBOS.

### Especificación del método

| Atributo | Valor |
|---|---|
| Namespace | `bauth.config` |
| Método | `global_get` |
| Socket | `/run/bos/bauth.sock` (ADR-020 Interface Dual) |
| Handler Rust | `server/jsonrpc.rs` → `handle_config_global_get()` |
| Fuente de datos | `bauth.cfg_policy_library WHERE domain_map @> ARRAY['D99']` |

### Request
```json
{
    "jsonrpc": "2.0",
    "method": "bauth.config.global_get",
    "params": {
        "ctx_id": "<uuid-v7>",
        "caller": "bkernel",
        "filter": ["cryptography", "key_management"]
    },
    "id": 1
}
```

### Response — árbol D99 compuesto con fn_compose_tree()
```json
{
    "jsonrpc": "2.0",
    "result": {
        "domain": "D99",
        "version": "2.0.0",
        "effective_from": "2026-07-07T00:00:00Z",
        "config": { ... }
    },
    "id": 1
}
```

### Quién lo consume — contratos pendientes de formalizar

| Daemon | Qué toma de D99 |
|---|---|
| **bkernel** | Algoritmos de integridad para WAL · retención de logs |
| **biedata** | Algoritmos de cifrado para datos en tránsito |
| **bsearch** | Políticas de retención de índices |
| **bnexus** | Configuración TLS mínima · cipher suites permitidos |
| **bnotify** | Algoritmos de firma para tokens de notificación |

**Tarea pendiente:** Formalizar un contrato `BAUTH-SBOS-GLOBAL-CONFIG-CONTRATO.md`
en `context/contracts/` para cada daemon receptor.

---

## 5. IMPACTO EN EL DDL — TABLAS POTENCIALMENTE AFECTADAS

### El problema

Antes de `cfg_policy_library` existían 24 tablas estáticas de políticas y configuraciones
(12 `ath_config_dN` + 12 `ath_policy_dN`). Estas tablas tienen esquemas fijos hardcodeados
por dominio. `cfg_policy_library` ahora provee exactamente el mismo dato de forma dinámica,
jerárquica y normalizada.

### Análisis de redundancia

| Grupo | Tablas | Registros actuales | Relación con cfg_policy_library |
|---|---|---|---|
| `ath_config_d1..d12` | 12 tablas | 14–20 por tabla | ⚠️ **SUPERADAS** — cfg_policy_library ya contiene su contenido con mejor estructura |
| `ath_policy_d1..d12` | 12 tablas | 48–302 por tabla | ⚠️ **SUPERADAS** — cfg_policy_library + fn_compose_tree() proveen lo mismo y más |
| `ath_config` | 1 tabla | 0 registros | ⚠️ **VACÍA Y SUPERADA** |
| `ath_policy` | 1 tabla | 0 registros | ⚠️ **VACÍA Y SUPERADA** |

### Distinción importante — NO todo es redundante

```
cfg_policy_library  =  CATÁLOGO (qué CAN configurarse — normativo, inmutable para SU)
ath_config_dN       =  CONFIGURACIÓN ACTIVA (qué IS configurado para este tenant)
ath_policy_dN       =  POLÍTICA EVALUADA (qué rule SE APLICA en runtime)
```

La arquitectura correcta con `cfg_policy_library` debería ser:

```
cfg_policy_library (biblioteca)
        │
        │  el SU selecciona RULES de aquí
        ▼
cfg_tenant_config (nueva tabla — composición del tenant)   ← REEMPLAZA ath_config_dN
        │
        │  bAuth evalúa en runtime
        ▼
cfg_rule_evaluation (nueva tabla — caché de evaluación)    ← REEMPLAZA ath_policy_dN
```

### Recomendación — HITL requerido

**Propuesta para el humano:** Deprecar las 25 tablas (`ath_config_d1..d12`, `ath_policy_d1..d12`,
`ath_config`, `ath_policy`) y reemplazarlas por:

1. `cfg_tenant_config` — composición activa del tenant: referencia a nodos de `cfg_policy_library`
   con los valores seleccionados por el SU
2. `cfg_rule_evaluation` — caché de evaluación runtime para PDP (no persistente, solo caché)

Esto elimina 25 tablas estáticas con esquema fijo y deja una sola tabla dinámica
que puede evolucionar sin migraciones estructurales.

**Esta decisión requiere aprobación del humano antes de ejecutar.**

---

## 6. PRÓXIMOS PASOS

| Prioridad | Tarea | Depende de |
|---|---|---|
| 1 | **HITL:** Aprobar o rechazar la deprecación de ath_config_dN + ath_policy_dN | Humano |
| 2 | Diseñar `cfg_tenant_config` — tabla de composición del tenant | Aprobación HITL |
| 3 | Diseñar `cfg_rule_evaluation` — caché PDP | Aprobación HITL |
| 4 | Implementar handler Rust `handle_config_global_get()` | cfg_policy_library lista ✅ |
| 5 | Formalizar contrato `BAUTH-SBOS-GLOBAL-CONFIG-CONTRATO.md` en `context/contracts/` | Aprobación HITL |
| 6 | Conectar `bos_rol_template` e `idn_user_template` a `cfg_policy_library` | cfg_tenant_config lista |

---

## 7. CONEXIÓN CON EL PLAN MAESTRO

Este trabajo corresponde a las **FASES 1–2** del `PLAN-ACCION-REDISEÑO.md`:

- FASE 1 (DDL D00 + idn_atributo) → ahora incluye decisión sobre ath_config_dN
- FASE 2 (DDL D4-D12 átomos) → ahora incluye decisión sobre ath_policy_dN
- FASE 0.S (Auditoría Seeds) → los seeds de ath_config_dN y ath_policy_dN quedan en
  revisión hasta que se resuelva el HITL de deprecación

Los seeds `bauth_16__ath_config_d1.sql` .. `bauth_27__ath_config_d12.sql` y
`bauth_28__ath_policy_d1.sql` .. `bauth_39__ath_policy_d12.sql` (24 archivos)
están en revisión pendiente de la decisión arquitectónica.

---

## 8. ARQUITECTURA DE COMPOSICIÓN — Rol y Usuario como árboles ltree

**Fecha:** 2026-07-07 · **Estado:** DISEÑO APROBADO — pendiente migración DDL

### Principio fundamental

El SU construye roles y usuarios **seleccionando nodos de `cfg_policy_library`**, filtrando
por dominio. El resultado es un árbol ltree que espeja exactamente la estructura de la biblioteca.

```
SELECCIÓN (SU filtra por dominio)
  cfg_policy_library
       │  dominio D1..D12
       ▼
cfg_role_composition    ← árbol del rol (nodos seleccionados)
       │  herencia + overrides individuales
       ▼
cfg_user_composition    ← árbol del usuario (rol + adiciones)
       │
       ▼
v_user_effective_policy ← vista PDP: política efectiva final
```

**Granularidad de selección:** el SU puede seleccionar a cualquier nivel:
- **POLICY_SET** → incluye automáticamente todos sus POLICY + RULE + PROPERTY hijos
- **POLICY** → incluye sus RULE + PROPERTY hijos
- **RULE** → incluye sus PROPERTY hijos
- **PROPERTY** → nodo individual con valor (puede sobreescribir el `default_value` de la biblioteca)

### Estructura del `composition_path` (ltree)

El path de composición espeja la biblioteca bajo un prefijo de entidad:

| Entidad | Prefijo | Ejemplo de path |
|---|---|---|
| Rol `ROL-ORG-CFO` | `rol_org_cfo` | `rol_org_cfo.sbosSeeds.D3.policy.dual_approval_above_5000` |
| Usuario UUID `4c697f66` | `usr_4c697f66` | `usr_4c697f66.sbosSeeds.D1.policy.scope_branch` |

Reglas ltree: solo `[a-zA-Z0-9_]` por label → guiones `-` → `_`, lowercase.

### Tablas DDL propuestas (migración `bauth_77__cfg_role_user_composition.sql`)

```sql
-- TABLA 1: Composición del rol — nodos seleccionados de la biblioteca
CREATE TABLE bauth.cfg_role_composition (
    id                      BIGSERIAL PRIMARY KEY,
    role_id                 TEXT NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    library_path            ltree NOT NULL,   -- FK lógico a cfg_policy_library.path
    level_type              TEXT NOT NULL CHECK (level_type IN ('POLICY_SET','POLICY','RULE','PROPERTY')),
    domain_map              TEXT[],            -- copiado de biblioteca (índice GIN)
    composition_path        ltree NOT NULL,    -- rol_org_cfo.sbosSeeds.D3.policy.dual_approval...
    parent_composition_path ltree,
    depth                   INTEGER NOT NULL,
    effective_value         TEXT,              -- PROPERTY: valor elegido (NULL = usar default biblioteca)
    use_library_default     BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id                  UUID NOT NULL,
    added_by                TEXT,
    added_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    notes                   TEXT,
    UNIQUE (role_id, library_path)
);

-- Índices
CREATE INDEX idx_role_comp_role   ON bauth.cfg_role_composition(role_id);
CREATE INDEX idx_role_comp_lib    ON bauth.cfg_role_composition USING GIST (library_path);
CREATE INDEX idx_role_comp_path   ON bauth.cfg_role_composition USING GIST (composition_path);
CREATE INDEX idx_role_comp_domain ON bauth.cfg_role_composition USING GIN (domain_map);
CREATE INDEX idx_role_comp_level  ON bauth.cfg_role_composition(role_id, level_type);

-- TABLA 2: Composición del usuario = rol heredado + nodos adicionales + overrides
CREATE TABLE bauth.cfg_user_composition (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 UUID NOT NULL REFERENCES bauth.idn_user_template(uuid) ON DELETE CASCADE,
    source                  TEXT NOT NULL CHECK (source IN (
                                'role_inherited',  -- viene del rol asignado
                                'user_added',      -- SU lo agregó solo al usuario
                                'user_override'    -- SU sobreescribió valor del rol
                            )),
    source_role_id          TEXT REFERENCES bauth.idn_role_template(id),
    library_path            ltree NOT NULL,
    level_type              TEXT NOT NULL CHECK (level_type IN ('POLICY_SET','POLICY','RULE','PROPERTY')),
    domain_map              TEXT[],
    composition_path        ltree NOT NULL,
    parent_composition_path ltree,
    depth                   INTEGER NOT NULL,
    effective_value         TEXT,              -- PROPERTY: valor del usuario
    role_value              TEXT,              -- PROPERTY: valor del rol (para auditoría override)
    use_library_default     BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id                  UUID NOT NULL,
    added_by                TEXT,
    added_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    notes                   TEXT,
    UNIQUE (user_id, library_path, source)
);

CREATE INDEX idx_user_comp_user   ON bauth.cfg_user_composition(user_id);
CREATE INDEX idx_user_comp_lib    ON bauth.cfg_user_composition USING GIST (library_path);
CREATE INDEX idx_user_comp_path   ON bauth.cfg_user_composition USING GIST (composition_path);
CREATE INDEX idx_user_comp_domain ON bauth.cfg_user_composition USING GIN (domain_map);

-- VISTA: política efectiva del usuario (PDP la consulta en runtime)
CREATE VIEW bauth.v_user_effective_policy AS
SELECT
    uc.user_id,
    uc.library_path,
    uc.level_type,
    uc.domain_map,
    uc.composition_path,
    uc.source,
    uc.source_role_id,
    CASE
        WHEN uc.source = 'user_override'    THEN uc.effective_value
        WHEN NOT uc.use_library_default     THEN uc.effective_value
        ELSE pl.default_value
    END AS effective_value,
    pl.section_name,
    pl.value_type,
    pl.enum_options,
    pl.standard_ref
FROM bauth.cfg_user_composition uc
JOIN bauth.cfg_policy_library pl ON pl.path = uc.library_path
WHERE uc.is_active = TRUE;
```

### Flujo del SU (interfaz de composición)

```
1. SU abre editor de rol → elige "ROL-ORG-CFO"
2. Filtra biblioteca por dominio → "D3 Financiero"
   Ve árbol en v_policy_tree:
     sbosSeeds.D3
     ├── policy.dual_approval_above_5000
     │     ├── PROPERTY: approvers_required  (INTEGER · default: 2)
     │     ├── PROPERTY: threshold           (INTEGER · default: 5000)
     │     └── PROPERTY: currency            (ENUM · [BOB, USD, EUR])
     └── policy.sod_creator_approver
           └── PROPERTY: rule               (TEXT · default: creator_neq_approver)
3. SU selecciona "dual_approval_above_5000" completo
4. Para PROPERTY threshold → override: 10000 BOB (más restrictivo)
5. INSERT en cfg_role_composition:
     (role_id='ROL-ORG-CFO',
      library_path='sbosSeeds.D3.policy.dual_approval_above_5000',
      level_type='POLICY', composition_path='rol_org_cfo.sbosSeeds.D3.policy.dual_approval_above_5000')
     (role_id='ROL-ORG-CFO',
      library_path='sbosSeeds.D3.policy.dual_approval_above_5000.threshold',
      level_type='PROPERTY', effective_value='10000', use_library_default=false)

6. SU asigna rol a usuario JUAN PÉREZ
7. Sistema copia filas del rol → cfg_user_composition (source='role_inherited')
8. SU puede agregar regla solo al usuario:
     INSERT (user_id=..., source='user_added',
             library_path='sbosSeeds.D6.policy.country_restrict_bo', ...)
9. PDP consulta v_user_effective_policy(user_id) → árbol efectivo completo
```

### Documentos de especificación completa

- `SBOS-ROLTEMPLATE-COMPOSICION-v7_0.md` — árbol de composición del rol por los 12 dominios
- `SBOS-USERTEMPLATE-COMPOSICION-v7_0.md` — árbol de composición del usuario por los 12 dominios
- Migración DDL: `DDLs/migrations/bauth_77__cfg_role_user_composition.sql` (pendiente HITL)

### Pendiente HITL

| ID | Decisión | Estado |
|---|---|---|
| H17 | Aprobar DDL de `cfg_role_composition` + `cfg_user_composition` + vista | **PENDIENTE** |
| H18 | Definir UI de composición: árbol interactivo vs formulario por dominio | **PENDIENTE** |
| H14 | Deprecar `ath_config_dN` / `ath_policy_dN` → se decide junto con H17 | Pendiente |
