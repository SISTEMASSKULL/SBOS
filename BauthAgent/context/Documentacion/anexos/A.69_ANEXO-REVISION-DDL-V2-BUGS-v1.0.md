# A.69 — Revisión DDL V2: Bugs e Inconsistencias
**Tipo:** C (análisis de decisión técnica + hallazgos de revisión)
**Versión:** 1.2.0 · **Fecha:** 2026-07-22
**Respalda a:** `DDLs/SBOS_db_V2_DDL.sql` · `A.65.02.01` · `A.65.01`
**Fuentes revisadas:** DDL V2 completa (3360 líneas) · Manual V2 (1199 líneas) · A.65 · A.65.01 · A.65.02.01 · A.65.02.02 · A.65.02.03

---

## §1 Propósito

Este anexo registra los hallazgos obtenidos tras la lectura completa de la DDL V2 y sus documentos de respaldo. Contiene:
- Tres bugs confirmados en `SBOS_db_V2_DDL.sql` (requieren corrección in-situ, regla desarrollo)
- Inconsistencias entre la documentación A.65.01 y la DDL real
- Novedades arquitectónicas relevantes que el desarrollador debe conocer

**Estado de correcciones:** COMPLETO — todos los gaps resueltos. DOC-1/DOC-2 en A.65.01 v2.10.0. BUG-1/BUG-2/BUG-3 en DDL V2 (2026-07-22).

---

## §2 Mapa de cobertura — qué se leyó

| Documento | Líneas | Estado lectura |
|-----------|--------|----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | 3360 | ✅ Completo (bloques 1-450, 450-1250, 1250-2149, 2149-3049, 3049-3360) |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | 1199 | ✅ Completo |
| `A.65_ANEXO-INVENTARIO-TABLAS-DDL-v1.0.md` | 417 | ✅ Completo |
| `A.65.01_ANEXO-GUIA-DESARROLLO-TABLAS-DDL-v1.0.md` | 2096 | ✅ Completo (bloques 1-1102, 1103-2096) |
| `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` | 1002 | ✅ Completo |
| `A.65.02.02_ATOMLANG-EXTENSION-USER-SUBJECT.md` | 407 | ✅ Completo |
| `A.65.02.03_ATOMLANG-MODELO-DIRECCIONAMIENTO-ATOMO-v1.0.md` | 727 | ✅ Completo |

---

## §3 Mapa de la DDL V2 — 67 tablas declaradas

**59 tablas con CREATE TABLE activo + 8 stubs (solo comentarios TODO) = 67 declaradas**

| Nivel | Schema | Tablas activas | Stubs |
|-------|--------|----------------|-------|
| Global | bglobal | 8 (T-001..T-004, T-059..T-061, T-114) | 0 |
| Tenant | bauth | 8 (T-005..T-013) | 0 |
| Roles | bauth | 6 (T-040..T-042, T-063, T-162, T-163) | 0 |
| Versionado | bauth | 0 | **4** (T-152..T-155) |
| Privilegios | bauth | 9 (T-170, T-170b×3 particiones, T-171..T-176, T-179) | 0 |
| Identidad D00 | bauth | 6 (T-156..T-157, T-186..T-188, T-190) | **4** (T-158..T-161) |
| Sesión | bauth | 4 (T-181, T-191..T-193) | 0 |
| Auditoría IGA | bauth | 2 (T-177..T-178) | 0 |
| Riesgo | bauth | 1 (T-180) | 0 |
| PAM | bauth | 6 (T-182, T-182b, T-183..T-185, T-189) | 0 |
| Calendario | bcalendar | 9 (T-012, T-014..T-019, T-124..T-125) | 0 |
| **TOTAL** | | **59** | **8** |

Las 3 particiones de `privilege_atom_audit` (2026-07/08/09) son tablas hijo de T-170b.

---

## §4 BUG-1 — Typo en nombre de SEQUENCE

**Severidad:** 🔴 CRÍTICO — rompe en runtime al primer INSERT de nodo `tipo='evaluacion'`
**Ubicación:** `SBOS_db_V2_DDL.sql` línea 148
**Descubierto:** comparación entre el nombre en la declaración y el nombre en el trigger `fn_irt_assign_atom_position`

### Evidencia

**Línea 148 — declaración (incorrecto):**
```sql
CREATE SEQUENCE IF NOT EXISTS bauth.roles_atom_position_sequentialuential
    START WITH 1 INCREMENT BY 1 NO CYCLE;
```

**Línea 1627 — trigger que la consume (nombre correcto):**
```sql
NEW.atom_position := nextval('bauth.roles_atom_position_sequential');
```

**A.65.02.01 §DDL-T-162 — nombre canónico documentado:**
```
bauth.roles_atom_position_sequential
```

### Consecuencia

La SEQUENCE creada se llama `roles_atom_position_sequentialuential` (con `uential` sobrante). El trigger llama `nextval('bauth.roles_atom_position_sequential')`. PostgreSQL lanzará:

```
ERROR: relation "bauth.roles_atom_position_sequential" does not exist
```

en todo INSERT de un nodo `tipo='evaluacion'` en T-162. El árbol de políticas nunca podrá tener átomos.

### Corrección propuesta

```sql
-- ANTES (línea 148):
CREATE SEQUENCE IF NOT EXISTS bauth.roles_atom_position_sequentialuential

-- DESPUÉS:
CREATE SEQUENCE IF NOT EXISTS bauth.roles_atom_position_sequential
```

---

## §5 BUG-2 — Nombres de tabla incorrectos en trigger `fn_validate_breakglass_grant`

**Severidad:** 🔴 CRÍTICO — el trigger falla en runtime con `relation does not exist`
**Ubicación:** `SBOS_db_V2_DDL.sql` líneas ~2183–2188
**Descubierto:** comparación entre los nombres usados en el trigger y los nombres reales declarados en la DDL

### Evidencia

**Bloque actual del trigger (incorrecto):**
```sql
    -- D2: verificar tier y tipo del rol
    SELECT rt.tier::text, rty.code
      INTO v_role_tier, v_role_type
      FROM bauth.idn_role_template rt
      JOIN bauth.idn_role_type     rty ON rty.id = rt.type_id
     WHERE rt.id = NEW.role_id;
```

**Nombres reales en la DDL:**

| Nombre usado en trigger | Nombre real (DDL) | Línea de declaración |
|------------------------|-------------------|---------------------|
| `bauth.idn_role_template` | `bauth.idn_roles_rol_hierarchical` | 1184 |
| `bauth.idn_roles_rol_type` | `bauth.idn_roles_rol_type` | 1097 |
| `rty.id` (PK de tipo) | `rty.type_id` | 1098 |

**Estructura real de `idn_roles_rol_hierarchical` (T-041, líneas 1184–1204):**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_hierarchical (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL ...,
    type_id          UUID        NOT NULL REFERENCES bauth.idn_roles_rol_type(type_id),
    tier             rol_tier_enum NOT NULL DEFAULT 'BIZ_N3',  -- ENUM directo, no FK separada
    ...
);
```

**Clave:** `tier` es un campo ENUM directo en `idn_roles_rol_hierarchical`, no una FK a otra tabla. `idn_roles_rol_type` tiene PK `type_id` (no `id`).

### Consecuencia

Todo INSERT o UPDATE de `grant_type = 'BREAKGLASS'` en T-170 dispara el trigger, que falla con:

```
ERROR: relation "bauth.idn_role_template" does not exist
```

El protocolo de break-glass completo queda inoperativo.

### Corrección propuesta

```sql
    -- D2: verificar tier y tipo del rol
    SELECT irh.tier::text, rty.code
      INTO v_role_tier, v_role_type
      FROM bauth.idn_roles_rol_hierarchical irh
      JOIN bauth.idn_roles_rol_type         rty ON rty.type_id = irh.type_id
     WHERE irh.id = NEW.role_id;
```

**Cambios:**
1. `bauth.idn_role_template rt` → `bauth.idn_roles_rol_hierarchical irh` (alias `irh`)
2. `JOIN bauth.idn_role_type rty ON rty.id = rt.type_id` → `JOIN bauth.idn_roles_rol_type rty ON rty.type_id = irh.type_id`
3. `rt.tier::text` → `irh.tier::text`
4. `rt.id = NEW.role_id` → `irh.id = NEW.role_id`

**Lógica D2 después de la corrección:**
- `irh.tier::text` producirá `'SU'`, `'T0'`, `'BIZ_N1'`, etc. (cast del ENUM)
- `rty.code` producirá `'EMERGENCY'`, `'INDIVIDUAL'`, etc.
- La condición `v_role_tier IS DISTINCT FROM 'SU' AND v_role_type IS DISTINCT FROM 'EMERGENCY'` continúa correcta: rechaza si tier ≠ SU Y tipo ≠ EMERGENCY

---

## §6 BUG-3 — Nombre de índice duplicado entre T-170b y T-176

**Severidad:** 🟠 MEDIO — el segundo `CREATE INDEX` falla con `relation already exists`
**Ubicación:** `SBOS_db_V2_DDL.sql` líneas 2257 y 2562
**Descubierto:** mismo nombre de índice (`idx_paa_grant`) definido para dos tablas distintas dentro del mismo schema `bauth`

### Evidencia

**Línea 2257 — índice para T-170b `privilege_atom_audit`:**
```sql
CREATE INDEX IF NOT EXISTS idx_paa_grant
    ON bauth.privilege_atom_audit(grant_id, created_at DESC);
```

**Línea 2562 — índice para T-176 `privilege_assurance_audit` (conflicto):**
```sql
CREATE INDEX IF NOT EXISTS idx_paa_grant
    ON bauth.privilege_assurance_audit (grant_id);
```

Los índices en PostgreSQL son únicos por schema. `bauth.idx_paa_grant` ya existe tras la línea 2257. La línea 2562 lanza:

```
ERROR: relation "idx_paa_grant" already exists
```

Resultado: `privilege_assurance_audit` **queda sin índice en `grant_id`**, aunque la cláusula `IF NOT EXISTS` silencia el error de forma engañosa — parece que tuvo éxito pero el índice apunta a la tabla equivocada.

### Convención de nombres para corregir

Los nombres actuales en T-170b usan prefijo `idx_paa_` (de `privilege_atom_audit`). Para T-176 (`privilege_assurance_audit`) se sugiere `idx_paaa_` (una `a` adicional):

| Índice | Tabla | Nombre actual | Nombre propuesto |
|--------|-------|---------------|-----------------|
| grant_id | privilege_atom_audit (T-170b) | `idx_paa_grant` | sin cambio (primero) |
| grant_id | privilege_assurance_audit (T-176) | `idx_paa_grant` ← **duplicado** | `idx_paaa_grant` |
| session_id | privilege_assurance_audit (T-176) | `idx_paa_session` | `idx_paaa_session` |
| created_at | privilege_assurance_audit (T-176) | `idx_paa_created` | `idx_paaa_created` |

Se propone renombrar los **tres** índices de T-176 (`idx_paa_*` → `idx_paaa_*`) para consistencia.

### Corrección propuesta (líneas 2562–2566)

```sql
-- ANTES:
CREATE INDEX IF NOT EXISTS idx_paa_grant   ON bauth.privilege_assurance_audit (grant_id);
CREATE INDEX IF NOT EXISTS idx_paa_session ON bauth.privilege_assurance_audit (session_id);
CREATE INDEX IF NOT EXISTS idx_paa_created ON bauth.privilege_assurance_audit (created_at);

-- DESPUÉS:
CREATE INDEX IF NOT EXISTS idx_paaa_grant   ON bauth.privilege_assurance_audit (grant_id);
CREATE INDEX IF NOT EXISTS idx_paaa_session ON bauth.privilege_assurance_audit (session_id);
CREATE INDEX IF NOT EXISTS idx_paaa_created ON bauth.privilege_assurance_audit (created_at);
```

---

## §7 Inconsistencias entre A.65.01 y la DDL real

Estos no son bugs de la DDL — son errores en los ejemplos SQL de la guía de desarrollo (A.65.01). No rompen nada en producción pero confunden al desarrollador que copie los ejemplos.

### 7.1 Nombre de tabla incorrecto en múltiples secciones ✅ RESUELTO — A.65.01 v2.10.0

A.65.01 usaba nombres de tabla que no coincidían con el DDL V2 canónico. El alcance fue mayor al estimado originalmente (7 ejemplos): se encontraron ~60 ocurrencias distribuidas en §4, §11, §13, §15, §18, §21, §22, §23, §26, §33, §35, §37. Todos corregidos el 2026-07-22.

| Nombre incorrecto | Nombre correcto DDL V2 | Tabla | Contexto |
|-------------------|----------------------|-------|----------|
| `idn_role_template` | `idn_roles_rol_hierarchical` | T-041 | §4 MVU, §11, §13, §18.2, §18.3 JOIN, §18.8 |
| `idn_role_template` | `idn_roles_template` | T-162 | §15, §21, §22, §23, §26, §33, §35, §37 |
| `idn_roles_templates` (plural) | `idn_roles_template` | T-162 | §18.3 CREATE TABLE, indexes, queries |
| `idn_rolestpl_contrato` | `idn_roles_template` | T-162 | §18.1, §11 comparativa |
| `idn_role_type` | `idn_roles_rol_type` | T-040 | §18 todos los contextos |
| `idn_tier_policy` | `idn_roles_rol_tier` | T-042 | §4 C1 list, §18 CONSERVAR |
| `idn_role_closure` | `idn_roles_rol_closure` | T-063 | §18.6 header, DDL ref, SQL |

**Nota de distinción clave:** `idn_role_template` aparecía en DOS contextos semánticamente distintos — T-041 (registro de identidad del rol: id/slug/tier/name) y T-162 (árbol de políticas: node_type/node_key/node_value). La corrección fue sensible al contexto para cada ocurrencia.

### 7.2 Nombre de campo incorrecto en §24 IDENTIDAD D00 ✅ RESUELTO — A.65.01 v2.10.0

En A.65.01 §24.3 las consultas usaban `e.nombre` como alias de columna. La DDL T-156 (línea 1731) declara `name JSONB NOT NULL`. Corregido `e.nombre` → `e.name` en 4 ocurrencias (líneas 1332, 1371, 1438, 1447).

### 7.3 Estado final

DOC-1 y DOC-2 aplicados a A.65.01. La DDL V2 en sí es consistente en sus nombres de tabla — los 3 bugs pendientes (BUG-1, BUG-2, BUG-3) son errores en el SQL de la DDL, no en la documentación.

---

## §8 Novedades arquitectónicas confirmadas en la lectura

Información nueva o confirmada que no estaba documentada en los anexos previos:

### 8.1 T-179 `privilege_exception_record` — SoD consultable por trigger

El trigger `fn_check_sod_on_grant` (T-170) incluye lógica implícita: si hay una excepción activa en T-179 para el par (usuario, átomo), el INSERT de grant se permite incluso cuando hay conflicto SoD. Esta lógica **no está implementada en el trigger de la DDL actual** — el trigger actual solo rechaza, no consulta T-179. Brecha documentada para implementación posterior.

### 8.2 T-190 `idn_roles_nhi_agent_identity` — agentes IA con FK self-referencial

Tabla nueva para agentes IA autónomos. Campo `orchestrator_id UUID NULL REFERENCES bauth.idn_roles_nhi_agent_identity(id)` crea un árbol de orquestación padre→hijo. `can_spawn_agents BOOLEAN DEFAULT false` y `max_spawn_depth INTEGER DEFAULT 0`. Constraint: si `can_spawn_agents = false` entonces `max_spawn_depth = 0` (y viceversa). Decisión PENDIENTE HITL: ¿el agente hijo hereda permisos del padre o tiene permisos propios?

### 8.3 T-180 `ses_risk_policy` — las reglas de riesgo SÍ son una tabla

Contrario a lo que sugiere A.65.01 §23.5 (que las reglas de riesgo viven solo en el árbol D8/B17), la DDL implementa `ses_risk_policy` como tabla editable en runtime. El árbol define los umbrales de referencia; esta tabla define las reglas accionables por tenant. Son capas complementarias, no duplicadas.

### 8.4 `menu_item_atom` (T-061) — puente BitMask↔menú en bglobal

El enlace entre ítems de menú y el motor BitMask vive en `bglobal.menu_item_atom`, no en bauth. El campo `atom_code TEXT` es un string (no UUID FK) que referencia la `clave` del árbol T-162. El PEP del dashboard evalúa el BitMask por este code antes de renderizar el ítem.

### 8.5 Particiones de T-170b — PK compuesta obligatoria

`privilege_atom_audit` está particionada por `RANGE(created_at)`. Su PK es compuesta: `PRIMARY KEY (audit_id, created_at)`. Esto es un requisito de PostgreSQL para tablas particionadas — la columna de partición debe estar incluida en la PK. Las particiones iniciales cubren 2026-07, 2026-08 y 2026-09. Se requiere un job que cree la partición del mes siguiente antes de que comience.

### 8.6 Trigger `fn_sync_effect_from_tree` — sincronización árbol→grants

Cuando cambia `effect` en un nodo `tipo='evaluacion'` de T-162, el trigger `trg_t162_sync_effect_to_grants` actualiza automáticamente `effect` en todos los grants `ACTIVE/SUSPENDED` de ese átomo en T-170. Esto garantiza que el árbol siempre manda en el campo `effect` sin requerir JOIN adicional en el PDP.

### 8.7 Tipos NHI confirmados — 6 tipos

`idn_roles_nhi_identity.nhi_type` acepta exactamente: `SERVICE_ACCOUNT`, `WORKLOAD`, `AGENT`, `BOT`, `API_CLIENT`, `CI_CD_PIPELINE`. El tipo `AGENT` es el que vincula con T-190.

### 8.8 Trigger `fn_validate_breakglass_grant` — lógica D1/D2/D3 confirmada

- **D1:** fuerza `reassess := false` en todo grant BREAKGLASS (inmune a CAEP)
- **D2:** solo tier `SU` o type `EMERGENCY` pueden recibir grants BREAKGLASS
- **D3:** máximo 2 grants BREAKGLASS activos por tenant (1 primario + 1 respaldo) — cuenta `status IN ('ACTIVE', 'INACTIVE')`

### 8.9 `pam_breakglass_activation` — auth_loa mínimo 2

El constraint `chk_pbga_auth_loa` acepta solo `2` o `3` (no 1). Los métodos aceptados son únicamente `MTLS_X509`, `WEBAUTHN_ROAMING`, `WEBAUTHN_PLATFORM`. Cualquier otro método de auth rechaza el INSERT. Break-glass requiere al menos AAL2.

### 8.10 `pam_session_record.duration_seconds` — GENERATED ALWAYS

Campo `duration_seconds INTEGER GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (ended_at - started_at))::integer) STORED`. Se calcula automáticamente al escribirse `ended_at`. No se puede escribir manualmente.

---

## §9 Stubs pendientes de diseño

8 tablas declaradas como comentarios TODO sin CREATE TABLE. Bloquean funcionalidades específicas:

| Tabla (stub) | Bloquea | Depende de |
|-------------|---------|------------|
| T-152 `idn_rol_hierarchical_ver_history` | Motor MVU F1 — "¿cómo era el rol X el día Y?" | T-042 |
| T-153 `idn_roles_rol_ver_proposal` | Quórum MAJOR — cambios de versión con aprobación N-de-M | T-162 + JIT T-182 |
| T-154 `idn_roles_rol_ver_retention_schedule` | Calendario de retención legal (Ley 843, PCI, ISO) | Motor MVU 1.13 |
| T-155 `idn_roles_template_ver_changelog` | Trazabilidad de transiciones v5→v6 del contrato | T-162 |
| T-158 `idn_identity_attribute_history` | WORM de cambios de atributos — trazabilidad ISO 27001 A.8.15 | T-157 |
| T-159 `idn_identity_requirement` | Completitud mínima IAL por tipo de entidad | Motor D93 |
| T-160 `idn_identity_synonym` | Búsqueda semántica con archivos `.syn` de PG | Motor D93 |
| T-161 `idn_identity_synonym_sync` | Control de sincronización de diccionarios `.syn` | T-160 |

---

## §10 Resumen ejecutivo de acciones

| ID | Severidad | Qué | Archivo | Línea(s) | Estado |
|----|-----------|-----|---------|----------|--------|
| BUG-1 | 🔴 Crítico | Typo en nombre SEQUENCE (`sequentialuential`) | `SBOS_db_V2_DDL.sql` | 148+155 | ✅ Resuelto 2026-07-22 |
| BUG-2 | 🔴 Crítico | Nombres de tabla incorrectos en trigger BREAKGLASS | `SBOS_db_V2_DDL.sql` | 2185-2186 | ✅ Resuelto 2026-07-22 |
| BUG-3 | 🟠 Medio | Índice duplicado `idx_paa_grant` (T-170b y T-176) | `SBOS_db_V2_DDL.sql` | 2562 | ✅ Resuelto 2026-07-22 |
| DOC-1 | 🟡 Bajo | Nombres incorrectos en ~60 ocurrencias (7 mapeos distintos) | `A.65.01` | múltiples | ✅ Resuelto 2026-07-22 |
| DOC-2 | 🟡 Bajo | `e.nombre` → `e.name` (columna JSONB) en 4 consultas §24 | `A.65.01` | §24.3-§24.5 | ✅ Resuelto 2026-07-22 |

---

## §11 Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-22 | Versión inicial — lectura completa DDL V2 + 7 documentos 65.*. 3 bugs DDL, 2 inconsistencias docs, 10 novedades arquitectónicas, 8 stubs catalogados. |
| 1.1.0 | 2026-07-22 | DOC-1 y DOC-2 resueltos: corrección sistémica de nombres de tabla en A.65.01 v2.10.0. ~60 ocurrencias, 7 mapeos distintos. BUG-1/BUG-2/BUG-3 siguen pendientes de aprobación humana para cambios en DDL. Quedan 3 gaps abiertos (todos DDL). |
| 1.2.0 | 2026-07-22 | BUG-1/BUG-2/BUG-3 resueltos en DDL V2. BUG-1: typo corregido en CREATE SEQUENCE y COMMENT ON SEQUENCE (líneas 148+155). BUG-2: trigger BREAKGLASS corregido — `idn_role_template` → `idn_roles_rol_hierarchical`, `idn_role_type` → `idn_roles_rol_type`, FK `rty.id` → `rty.type_id`. BUG-3: índice duplicado renombrado `idx_paa_grant` → `idx_priv_assurance_grant` en T-176. **0 gaps abiertos.** |
