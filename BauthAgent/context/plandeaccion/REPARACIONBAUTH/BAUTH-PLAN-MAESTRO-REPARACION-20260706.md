# BAUTH — Plan Maestro de Reparación Quirúrgica
**Versión:** 2.0 · **Fecha:** 2026-07-06 · **Autor:** bauth-developer
**Estado:** ACTIVO — documento de referencia para toda la fase de reparación
**Cambios v2.0:** Corrección fundamental de ruta de archivos (DDLs/ compartido),
corrección de enfoque (editar DDL in-situ, no ALTER TABLE en desarrollo),
y adición de Sección 10: Requisitos bNotify en dominios bAuth.

---

## ⚠️ CORRECCIONES FUNDAMENTALES (leer ANTES que el resto)

Las siguientes reglas ANULAN cualquier instrucción contraria en el cuerpo del documento:

### CF-1 — Los archivos DDL van en el proyecto compartido, NO en BauthAgent

**MAL (v1.0 decía):** `BauthAgent/db/migrations/`
**CORRECTO:** `/opt/skull/orquestador/proyectos/SBOS/DDLs/migrations/` y `DDLs/seeds/`

El proyecto SBOS tiene un único repositorio de DDLs y seeds compartido.
Ningún agente crea archivos DDL/seed "donde quiera". Todo entra por `DDLs/`.
Regla documentada en `DDLs/ddls.yml` — custodiada por el Bibliotecario.

### CF-2 — En fase de DESARROLLO: editar la DDL original, nunca ALTER TABLE

**MAL (v1.0 decía):** Crear `007_alter_idn_role_template.sql` con `ALTER TABLE ADD COLUMN`
**CORRECTO:** Editar el `CREATE TABLE idn_role_template` directamente en `sbos_00__esquema_base.sql`

`ddls.yml` es explícito:
> "En desarrollo se CORRIGE la MISMA DDL. PROHIBIDO ALTER TABLE para corregir
> el esquema. La corrección va dentro del CREATE TABLE original."

La única excepción: la migración `bauth_10__d00_identidad_organizacional.sql`
ya usa ALTER TABLE y está escrita — se respeta como está (ya fue aprobada).

### CF-3 — Convención de nombres en DDLs/

Migraciones: `bauth_NN__descripcion.sql` (doble guion bajo)
Seeds:        `bauth_NN__tabla.sql` (doble guion bajo)
**NO usar** `NNN_descripcion.sql` (convención Flyway solo usada en `BnotifyAgent/src/migrations/`)

Número siguiente disponible:
- Seeds:       bauth_71__ (último: bauth_70__compliance_qa.sql)
- Migraciones: bauth_40__ (últimas en DDLs/migrations/: bauth_10/20/30)

### CF-4 — Las tablas de bNotify van en schema `bnotify`, no en `bauth`

bNotify tiene su propio schema (`bnotify`) y sus propios archivos DDL.
bAuth solo necesita exponer VISTAS de solo lectura para que bNotify las consuma.
Ver §10 para los requisitos completos.

### CF-5 — D5 Biométrico sigue el patrón de dominio — NO tablas monolíticas

**MAL (v2.0 en T2.4):** Crear tablas separadas `bio_method`, `bio_enrollment_policy`, `bio_gdpr_config`
**CORRECTO:** `ath_config_d5` y `ath_policy_d5` YA EXISTEN con el patrón correcto del proyecto:
- `ath_config_d5`: `config_key TEXT, config_value JSONB` (parámetros operativos con `_sources`)
- `ath_policy_d5`: `policy_code TEXT, config JSONB` (reglas y compliance con `_source` inline)

El problema era de **CONTENIDO**, no de estructura. La corrección es:
- **T2.4a** → Reescribir `DDLs/seeds/bauth_20__ath_config_d5.sql` con 9 configs biométricas ISO/IEC 19794
- **T2.4b** → Enriquecer `DDLs/seeds/bauth_32__ath_policy_d5.sql` con 10 políticas (5 originales + 5 nuevas)

Ambos seeds ya fueron reescritos con valores trazados a norma hasta 2026.

`BIOMETRIC_ENROLLMENT_HYBRID` permanece en `ath_policy_d2` — correcto:
D2 = proceso de acceso físico que USA biometría · D5 = estándares de LA biometría misma.

### CF-6 — idn_atributo: columnas canónicas de BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md

**MAL (v2.0 en T1.3):** Usó columnas `atributo_id`, `entidad_tipo='TENANT'/'EMPRESA'`, etc.
Luego §10.3 intentó cambiar a `user_id`, `atributo_tipo`, `activo`, `verificado` siguiendo la vista bNotify.

**CORRECTO — columnas canónicas:**
```
id UUID, entidad_tipo TEXT, entidad_id UUID,
atom_code INT, category TEXT, attr_key TEXT, attr_subtype TEXT,
value_text TEXT, value_data JSONB, display_format TEXT, validation_policy JSONB,
is_primary BOOLEAN, is_verified BOOLEAN, verified_at TIMESTAMPTZ, verified_by TEXT,
sort_order SMALLINT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```
**entidad_tipo CHECK:** `'tenant' | 'bdomain' | 'bsubdomain' | 'pos' | 'actor'`
(minúsculas; bdomain=empresa, bsubdomain=sucursal, actor=persona/usuario)

**Elementos físicos (chapas, puertas, cámaras, cajas POS):** NO son `entidad_tipo` nuevo.
Pertenecen a `fis_location` (D2, `location_type = DEVICE`) y `fis_device`.
bAuth decide el acceso (BitMask D2); bNexus ejecuta el hardware.

**Vista bNotify `v_bauth_user_channel`:** escrita contra diseño ANTERIOR de idn_atributo.
Usa columnas que no coinciden con el diseño canónico.
**La vista debe actualizarse** para usar las columnas canónicas — NO al revés.

### CF-7 — ctx_id: formato completo con prefijo interno/externo

Formato canónico (SBOS-049 §5.3 + migration `bauth_10__d00_identidad_organizacional.sql`):
```
[interno|externo]/{tenant_id}/{bdomain_id}/{bsubdomain_id}/user/{user_id}/pos/{pos_id}
```
- `interno` → `idn_tenant.is_internal = true` (tenant interno del ecosistema)
- `externo` → `idn_tenant.is_internal = false` (tenant cliente externo)
- W3C Baggage: `ctx.id=ctx-XXXX,tenant.id=skull,empresa.id=maya,sucursal.id=lapaz,...`
- BOS crea el ctx_id. bAuth lo promueve de pre-auth → post-auth (agrega claims del JWT).

---

---

## DECLARACIÓN DE INTENCIÓN

Esta reparación se ejecuta en **ventana única e irrepetible**.
La base de datos está en entorno de pruebas — aún podemos hacer cambios
invasivos sin afectar producción. Una vez que el sistema entre en producción,
toda intervención será **quirúrgica menor** (additive-only, sin DROP, sin RENAME).

**Este documento es el plano completo.** Cualquier agente que lo lea debe poder
ejecutar la reparación en el orden indicado, sin ambigüedad, sin adivinar.

---

## PRINCIPIOS QUIRÚRGICOS — INVARIANTES DE ESTA FASE

> **Quien ejecuta lee este bloque primero. Sin excepción.**

| # | Principio | Razón |
|---|---|---|
| P1 | **Nunca DROP en producción** — solo aquí en pruebas | Riesgo de pérdida de datos irreversible |
| P2 | **Nunca modificar átomos existentes** — solo AGREGAR a partir de posición 5809 | El código Rust tiene posiciones hardcodeadas en compilación |
| P3 | **Todo cambio de constraint o tipo de columna requiere HITL** | Puede romper código Rust que ya lee esa columna |
| P4 | **Un migration = un objeto o grupo de objetos relacionados** | Rollback independiente por migración |
| P5 | **Seeds separados del DDL** — nunca mezclar en el mismo archivo | DDL es estructura; seeds son datos; se ejecutan independientemente |
| P6 | **Cada migración tiene su verificación SQL** — incluida en el mismo PR | Sin evidencia = rechazado por Revisor (C12) |
| P7 | **Primero la estructura, luego los datos, luego el código** | Evitar código apuntando a tablas inexistentes |
| P8 | **Ningún campo eliminado, solo marcado `is_active=false` o `deprecated=true`** | El código Rust puede leer ese campo en algún módulo |
| P9 | **Convención de nombres: inglés para tokens SQL, español en comentarios** | Norma Fundacional del proyecto (SCIM 2.0 + DOC-SBOS-001) |
| P10 | **Todo cambio a DDLs/ requiere aprobación de Iván (HITL)** | Recurso compartido del proyecto SBOS |

---

## ESTADO VERIFICADO EN VPS — SBOS_db (2026-07-06)

### Base de datos: `SBOS_db` · Pod: `postgresql-0` · Namespace: `sbos-data`

```
Schemas: bauth (172 tablas) · bcalendar (9 tablas) · bglobal (6 tablas)
         bos · bos_privilege · bos_blockchain

Core BitMask:
  privilege_domain:   12 registros (D1-D12) — D0 AUSENTE por CHECK constraint
  privilege_atom:  5.808 átomos (formato MONOLÍTICO antiguo — debe coexistir)
  privilege_verb:     50 verbos
  privilege_application: 12 aplicaciones
  privilege_group:    48 grupos
  CHECK constraint:   domain_code >= 1 AND <= 15 → BLOQUEA D0

Identidad:
  idn_role_template:  31 templates de roles
  idn_user_template:   9 templates de usuarios
  idn_tier_policy:     9 tiers
  idn_tenant:          1 tenant activo
  org_empresa:         1 empresa registrada
  org_sucursal:        1 sucursal registrada
  org_pos_logico:      0 (vacía)
```

---

## MAPA COMPLETO DE TAREAS DE REPARACIÓN

Cada tarea tiene: ID · tipo · HITL requerido · impacto en Rust · dependencias.

```
FASE 0 — Pre-cirugía (sin HITL, ejecutable ahora)
  T0.1  Corregir run_all_seeds.sql (contadores incorrectos)
  T0.2  Corregir seed idn_user_template (camelCase → snake_case, versión 6.0.0)
  T0.3  Corregir seed idn_role_template (7 nombres de bloque JSONB incorrectos)
  T0.4  Verificar foreign keys y referencias cruzadas en seeds
  T0.5  Auditar ath_config_d5 — documentar content misassignment

FASE 1 — Reparación core de identidad (HITL requerido)
  T1.1  [HITL] Modificar CHECK constraint privilege_domain → D0 permitido
  T1.2  [HITL] Insertar D0 en privilege_domain
  T1.3  [HITL] Crear tabla idn_atributo (EAV para identidad organizacional)
  T1.4  [HITL] Decidir numeración D4/D5 del catálogo de átomos
  T1.5  [HITL] Renombrar bos_rol_template_history → idn_role_template_history

FASE 2 — Correcciones por dominio (HITL por cada ALTER TABLE)
  T2.1  [HITL] ALTER idn_role_template — 5 columnas faltantes
  T2.2  [HITL] ALTER ath_method — 7 columnas faltantes
  T2.3  [HITL] Reasignar contenido ath_config_d5 a ath_config_d9
  T2.4  [HITL] Crear bio_method, bio_enrollment_policy, bio_gdpr_config (D5 real)
  T2.5  [HITL] Crear fis_access_method, fis_biometric_policy (D2 restantes)
  T2.6  [HITL] Crear ath_phishing_policy (D9 — ALTA prioridad AAL2+)
  T2.7  [HITL] Crear sod_incompatible_role, sod_incompatible_function (SoD)
  T2.8  [HITL] Crear tryton_model_access (D1 — Tryton 5 capas)
  T2.9  [HITL] Crear net_device_trust_policy (D7)
  T2.10 [HITL] Crear dlg_delegation_policy (D10)
  T2.11 [HITL] Crear sync_kc_config, sync_tryton_config, sync_drift_config
  T2.12 [HITL] Crear aud_event_catalog, aud_review_policy (D11)
  T2.13 [HITL] Crear blk_did_registry, blk_smart_contract, blk_besu_node (D12)
  T2.14 [HITL] Crear fin_transaction_schedule, fin_geospatial_control (D3)
  T2.15 [HITL] Crear attendance_policy, ath_rotation_policy

FASE 3 — Nuevo modelo atómico D.A.M.V. (aditivo — no rompe nada)
  T3.1  [HITL] Insertar D0 con 108 átomos CRUD (posiciones 5809-5916)
  T3.2  [HITL] Decidir estrategia coexistencia modelo viejo / nuevo
  T3.3  Insertar átomos D.A.M.V. nuevos para D1-D12 (pos 5917+)

FASE 4 — Seeds y datos
  T4.1  Poblar bio_method (4 tipos ISO/IEC 19794)
  T4.2  Poblar bio_enrollment_policy (Argon2id, FMR 1:10000)
  T4.3  Poblar ath_phishing_policy (NIST 800-63B-4)
  T4.4  Poblar sod_incompatible_role (reglas SoD institucionales)
  T4.5  Poblar sync_kc_config, sync_tryton_config
  T4.6  Poblar fin_transaction_type (20 tipos — actualmente vacía)
  T4.7  Poblar fin_approval_chain y fin_approval_level
  T4.8  Poblar fis_* tablas (zonas físicas, métodos de acceso)
  T4.9  Poblar idn_atributo con datos de org_empresa y org_sucursal existentes

FASE 5 — Adaptación del código Rust
  T5.1  Actualizar domain/bitmask.rs para soportar D0
  T5.2  Actualizar db/postgres.rs para nuevas tablas y columnas
  T5.3  Actualizar catalog/loader.rs para nuevo formato D.A.M.V.
  T5.4  Agregar módulos bio_*, sync_* a domain/
  T5.5  Actualizar engine/tryton_engine.rs con tryton_model_access
```

---

## FASE 0 — PRE-CIRUGÍA (Sin HITL)

### T0.1 — Corregir run_all_seeds.sql

**Archivo:** `BauthAgent/db/seeds/run_all_seeds.sql`
**Problema verificado:** El archivo dice "49 seeds" pero ejecuta 81+ `\ir`. Falta `seed_compliance_results.sql`.
**Acción:** Actualizar contadores y agregar los seeds faltantes.
**HITL:** No — es corrección de seeds, no DDL.
**Impacto en Rust:** Ninguno.

### T0.2 — Corregir seed idn_user_template

**Archivo:** `BauthAgent/db/seeds/064_idn_user_template_data.sql`
**Problemas verificados:**
- 14 claves en camelCase → deben ser snake_case
- Versión `'3.0'` → debe ser `'6.0.0'`
- Columna inexistente `mask_eff_hex` → debe ser `rol_bitmask_base64`

**Acción:** Corrección directa en el archivo de seed.
**HITL:** No.
**Impacto en Rust:** Ninguno (seed de datos, no estructura).

### T0.3 — Corregir nombres de bloques JSONB en seed_idn_role_template_data.sql

**Archivo:** `BauthAgent/db/seeds/seed_idn_role_template_data.sql`
**Problema:** 7 nombres de bloque JSONB no coinciden con RolTemplate v6.0.
**Acción:** Mapear nombres incorrectos a canónicos del SBOS-ROLTEMPLATE-v5_0.md.
**HITL:** No.
**Impacto en Rust:** Ninguno.

### T0.4 — Auditoría de referencias cruzadas en seeds

**Descripción:** Verificar que los seeds no referencien tablas/columnas que no existen.
**Método:** `grep -r "INSERT INTO\|UPDATE\|FROM" db/seeds/ | grep -v "^#"` y contrastar con tablas reales en VPS.
**HITL:** No.

### T0.5 — Documentar misassignment de ath_config_d5

**Descripción:** Los 20 registros de `ath_config_d5` contienen config FIDO2/WebAuthn/passkeys
(pertenece a D9 Credenciales, no a D5 Biométrico). Documentar antes de reasignar.
**Acción:** Crear archivo `BAUTH-AUDITORIA-ATH-CONFIG-D5-20260706.md` con el contenido
actual para referencia histórica antes de la corrección (Fase 2 T2.3).
**HITL:** No.

---

## FASE 1 — REPARACIÓN CORE DE IDENTIDAD (HITL requerido)

### T1.1 — [HITL] Modificar CHECK constraint de privilege_domain

**Problema confirmado en VPS:**
```sql
-- Constraint actual (bloquea D0):
CHECK (((domain_code >= 1) AND (domain_code <= 15)))
```

**DDL propuesto:**
```sql
-- Migración: 004_fix_domain_constraint.sql
BEGIN;

ALTER TABLE bauth.privilege_domain
  DROP CONSTRAINT ck_domain_code;

ALTER TABLE bauth.privilege_domain
  ADD CONSTRAINT ck_domain_code
  CHECK (domain_code >= 0 AND domain_code <= 15);

-- Verificación:
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'bauth.privilege_domain'::regclass
  AND conname = 'ck_domain_code';
-- Debe retornar: CHECK ((domain_code >= 0) AND (domain_code <= 15))

COMMIT;
```

**Impacto en Rust:** El código que valida `domain_code` debe actualizarse para aceptar 0.
Buscar: `grep -r "domain_code" src/ | grep -E ">=|<=|>|<"`.
**HITL:** Iván aprueba el DDL antes de ejecutar en VPS.
**Norma:** NIST SP 800-53 AC-2 — gestión de cuentas requiere dominio base de identidad.

---

### T1.2 — [HITL] Insertar D0 en privilege_domain

**Dependencia:** T1.1 debe estar completo.

**DDL propuesto:**
```sql
-- Parte de la misma migración 004 o migración 005
INSERT INTO bauth.privilege_domain
  (domain_code, domain_name, requires_policy, description)
VALUES
  (0, 'Identidad Organizacional',
   true,
   'D00: Jerarquía tenant → empresa → sucursal → pos_logico. '
   'Identidad y atributos base. Precondición de todos los dominios.');

-- Verificación:
SELECT domain_code, domain_name FROM bauth.privilege_domain ORDER BY domain_code;
-- D0 debe aparecer como primer registro.
```

**HITL:** Incluido en la aprobación de T1.1.

---

### T1.3 — [HITL] Crear tabla idn_atributo

**Contexto:** El diseño de `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` define `idn_atributo`
como tabla EAV (Entity-Attribute-Value) genérica para almacenar 1:N atributos de identidad.
Esto reemplaza el esquema rígido de columnas por entidad y permite extensibilidad sin DDL.

**DDL propuesto (migración: bauth_40__idn_atributo.sql):**

> ⚠️ CF-6: Columnas canónicas de `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`.
> NO usar nombres de la vista bNotify (user_id, atributo_tipo, activo, verificado).
> La vista bNotify debe actualizarse para usar estas columnas.

```sql
-- =============================================================================
-- bauth_40__idn_atributo.sql — Tabla EAV de atributos extensibles de identidad
-- Norma: ISO 24760-2:2025 §6.3 identity attribute management
--        SCIM 2.0 RFC 7643 §3.1 (extensibilidad de esquema)
--        SBOS-ORQUESTA: BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md
-- =============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS bauth.idn_atributo (
  id               UUID         NOT NULL DEFAULT gen_random_uuid(),

  -- Qué entidad posee este atributo
  entidad_tipo     TEXT         NOT NULL,  -- 'tenant'|'bdomain'|'bsubdomain'|'pos'|'actor'
  entidad_id       UUID         NOT NULL,  -- FK al ID de la entidad (ej: tenant_id, actor_id)

  -- Atom de privilegio asociado (opcional — para atributos controlados por BitMask)
  atom_code        INT          REFERENCES bauth.privilege_atom(atom_code),

  -- Clasificación del atributo
  category         TEXT         NOT NULL,  -- 'contacto'|'legal'|'laboral'|'localizacion'
  attr_key         TEXT         NOT NULL,  -- 'email'|'nit'|'telefono'|'cargo'
  attr_subtype     TEXT,                   -- 'corporativo'|'personal'|'principal'

  -- Valor del atributo (solo uno activo por fila)
  value_text       TEXT,                   -- valor escalar
  value_data       JSONB,                  -- valor estructurado (múltiples campos)

  -- Presentación y validación
  display_format   TEXT,                   -- ej: '+591 ### ### ####' para telefono BO
  validation_policy JSONB,                 -- regex, rangos, lista de valores permitidos

  -- Estado de verificación
  is_primary       BOOLEAN      NOT NULL DEFAULT false,
  is_verified      BOOLEAN      NOT NULL DEFAULT false,
  verified_at      TIMESTAMPTZ,
  verified_by      TEXT,                   -- 'SIN'|'SENASIR'|'ADSIB'|'MANUAL'

  -- Orden de presentación
  sort_order       SMALLINT     NOT NULL DEFAULT 0,

  -- Auditoría
  ctx_id           TEXT         NOT NULL DEFAULT 'seed',
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_idn_atributo PRIMARY KEY (id),
  CONSTRAINT ck_entidad_tipo CHECK (
    entidad_tipo IN ('tenant','bdomain','bsubdomain','pos','actor')
  )
);

-- Índices para búsqueda eficiente
CREATE INDEX idx_idn_atributo_entidad
  ON bauth.idn_atributo (entidad_tipo, entidad_id, tenant_id);

CREATE INDEX idx_idn_atributo_codigo
  ON bauth.idn_atributo (atributo_codigo, tenant_id);

CREATE INDEX idx_idn_atributo_valor
  ON bauth.idn_atributo (atributo_valor, atributo_codigo)
  WHERE is_active = true;

-- Unicidad: un atributo primario por entidad y tipo
CREATE UNIQUE INDEX uq_idn_atributo_primary
  ON bauth.idn_atributo (entidad_tipo, entidad_id, atributo_codigo, tenant_id)
  WHERE is_primary = true AND is_active = true;

COMMENT ON TABLE bauth.idn_atributo IS
  'D00 — Atributos extensibles de identidad organizacional. '
  'Patrón EAV. Almacena 1:N atributos por entidad (TENANT/EMPRESA/SUCURSAL/POS). '
  'Reemplaza columnas rígidas por extensibilidad sin DDL. '
  'Norma: ISO 24760-2:2025 §6.3 identity attribute management.';

-- Verificación:
SELECT COUNT(*) FROM information_schema.columns
WHERE table_schema='bauth' AND table_name='idn_atributo';
-- Debe retornar 20+

COMMIT;
```

**HITL:** Iván aprueba diseño EAV y DDL.
**Norma:** ISO 24760-2:2025 §6.3 · SCIM 2.0 RFC 7643 (extensibilidad de atributos).

---

### T1.4 — [HITL] Decisión sobre numeración D4/D5 en catálogo de átomos

**Conflicto documentado en §8.1:**

| Doc | D4 | D5 |
|---|---|---|
| Arquitectura + otros docs | Temporal (cal_) | Biométrico |
| BAUTH-CATALOGO-ATOMOS-D4-D12.md | ACCESO FÍSICO (pacs.*) | DISPOSITIVOS (device.*) |

**Opciones:**
- **Opción A (recomendada):** Corregir el catálogo de átomos para alinear con la arquitectura.
  D4 = Temporal · D2 = Acceso Físico. El catálogo fue escrito con numeración incorrecta.
- **Opción B:** Cambiar la arquitectura. Implica también cambiar privilege_domain, seeds y docs.

**Impacto de Opción A:** Solo editar BAUTH-CATALOGO-ATOMOS-D4-D12.md.
**Impacto de Opción B:** Cambiar privilege_domain (requiere migración), todos los seeds,
y todos los documentos que referencian D2/D4.

**HITL:** Iván decide. Se recomienda Opción A por menor impacto.

---

### T1.5 — [HITL] Renombrar bos_rol_template_history

**Problema:** La tabla `bauth.bos_rol_template_history` usa el prefijo `bos_` que está
marcado como OBSOLETO ("lo antiguo ya no sobrevive"). Debe ser `idn_role_template_history`.

**DDL propuesto:**
```sql
-- Migración: 006_rename_legacy_tables.sql
BEGIN;

ALTER TABLE bauth.bos_rol_template_history
  RENAME TO idn_role_template_history;

-- Renombrar constraint si existe
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname LIKE 'bos_rol_template%'
  ) THEN
    ALTER TABLE bauth.idn_role_template_history
      RENAME CONSTRAINT pk_bos_rol_template_history TO pk_idn_role_template_history;
  END IF;
END$$;

COMMIT;
```

**Impacto en Rust:** Buscar `grep -r "bos_rol_template_history" src/` — actualizar referencias.
**HITL:** Iván aprueba.

---

## FASE 2 — CORRECCIONES POR DOMINIO

### T2.1 — [HITL] ALTER idn_role_template — columnas faltantes

**Verificado en VPS:** Las 5 columnas siguientes NO EXISTEN en `idn_role_template`.

```sql
-- Migración: 007_alter_idn_role_template.sql
BEGIN;

ALTER TABLE bauth.idn_role_template
  ADD COLUMN IF NOT EXISTS timezone               text DEFAULT 'America/La_Paz',
  ADD COLUMN IF NOT EXISTS inactivity_timeout_s   integer DEFAULT 900,
  ADD COLUMN IF NOT EXISTS force_logout_at_shift_end boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS reauth_interval_s      integer DEFAULT 14400,
  ADD COLUMN IF NOT EXISTS audit_retention_days   integer DEFAULT 2555;

COMMENT ON COLUMN bauth.idn_role_template.timezone IS
  'Zona horaria del rol. IANA tz database. Norma: RFC 5545 iCalendar, ISO 8601.';
COMMENT ON COLUMN bauth.idn_role_template.inactivity_timeout_s IS
  'Timeout de inactividad en segundos. Default: 900s (15 min). '
  'Norma: NIST SP 800-63B-4 §7.1 session management.';
COMMENT ON COLUMN bauth.idn_role_template.force_logout_at_shift_end IS
  'Forzar cierre de sesión al terminar el turno. Norma: NIST SP 800-53 AC-12.';
COMMENT ON COLUMN bauth.idn_role_template.reauth_interval_s IS
  'Intervalo de reautenticación en segundos. Default: 14400s (4h). '
  'Norma: NIST SP 800-63B-4 §7.2.';
COMMENT ON COLUMN bauth.idn_role_template.audit_retention_days IS
  'Retención de auditoría en días. Default: 2555 (7 años). '
  'Norma: PCI DSS 4.0.1 Req.10.7, SOX §404.';

COMMIT;
```

**Impacto en Rust:** Actualizar `db/postgres.rs` → struct `RoleTemplate` para incluir campos nuevos.
**HITL:** Iván aprueba las columnas y sus defaults.

---

### T2.2 — [HITL] ALTER ath_method — columnas faltantes

**Verificado en VPS:** Las siguientes 7 columnas NO EXISTEN como columnas propias.
No están en el JSONB config. Deben ser columnas para permitir índices y queries eficientes.

```sql
-- Migración: 008_alter_ath_method.sql
BEGIN;

ALTER TABLE bauth.ath_method
  ADD COLUMN IF NOT EXISTS is_phishing_resistant  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_device_bound        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_syncable            boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS max_aal                text,
  ADD COLUMN IF NOT EXISTS can_be_primary         boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_be_fallback        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recovery_eligible      boolean NOT NULL DEFAULT false;

-- Poblar según NIST SP 800-63B-4 conocidos
UPDATE bauth.ath_method SET
  is_phishing_resistant = true,
  is_device_bound = true,
  is_syncable = false,
  max_aal = 'AAL3'
WHERE method_id IN ('WEBAUTHN_PWDLESS','PASSKEY_DEVICE','SMARTCARD_X509','FIDO2_HARDWARE');

UPDATE bauth.ath_method SET
  is_phishing_resistant = true,
  is_device_bound = false,
  is_syncable = true,
  max_aal = 'AAL2'
WHERE method_id IN ('PASSKEY_SYNCED','PASSKEY_PLATFORM');

UPDATE bauth.ath_method SET
  is_phishing_resistant = false,
  max_aal = 'AAL2'
WHERE method_id IN ('TOTP','HOTP');

UPDATE bauth.ath_method SET
  is_phishing_resistant = false,
  max_aal = 'AAL1',
  recovery_eligible = true
WHERE method_id IN ('BACKUP_CODES','EMAIL_OTP');

COMMENT ON COLUMN bauth.ath_method.is_phishing_resistant IS
  'True si el método es resistente a phishing (FIDO2, passkeys, X.509). '
  'Norma: NIST SP 800-63B-4 §4.2.2 — obligatorio para AAL2+ en nuevos despliegues.';

COMMIT;
```

**HITL:** Iván aprueba columnas y values de UPDATE.

---

### T2.3 — [HITL] Reasignar contenido de ath_config_d5 a ath_config_d9

**Problema confirmado:** `ath_config_d5` tiene 20 registros de config FIDO2/WebAuthn/passkeys
que pertenecen a D9 (Credenciales), no a D5 (Biométrico).

**Método:**
```sql
-- Migración: 009_fix_ath_config_d5.sql
BEGIN;

-- Paso 1: Mover registros de D5 a D9 (verificar que no existan ya)
INSERT INTO bauth.ath_config_d9 (config_id, config_key, config_value, description,
                                   standard_ref, is_active, ctx_id, created_at, updated_at)
SELECT config_id, config_key, config_value, description || ' [migrado desde D5]',
       standard_ref, is_active, ctx_id, created_at, updated_at
FROM bauth.ath_config_d5
WHERE config_key IN (
  'fido2_ctap_2_2','webauthn_level_3','enterprise_attestation',
  'passkey_adoption_2026','credential_exchange_protocol',
  'password_policy_rev4','mfa_requirements',
  'enterprise_authentication_practices_2026',
  'ctap_2_2_features','google_beyondcorp','microsoft_entra_id',
  'sdk_support','minimum_length','password_expiration',
  'aal1','blocklist_screening','composition_rules',
  'deepfake_controls','risk_framework','verifiable_credentials'
)
ON CONFLICT (config_id) DO NOTHING;

-- Paso 2: Limpiar D5 de contenido D9
DELETE FROM bauth.ath_config_d5
WHERE config_key IN (
  'fido2_ctap_2_2','webauthn_level_3','enterprise_attestation',
  'passkey_adoption_2026','credential_exchange_protocol',
  'password_policy_rev4','mfa_requirements',
  'enterprise_authentication_practices_2026',
  'ctap_2_2_features','google_beyondcorp','microsoft_entra_id',
  'sdk_support','minimum_length','password_expiration',
  'aal1','blocklist_screening','composition_rules',
  'deepfake_controls','risk_framework','verifiable_credentials'
);

-- Verificación:
SELECT COUNT(*) FROM bauth.ath_config_d5;
-- Debe retornar 0 (todos movidos a D9)

COMMIT;
```

**HITL:** Iván aprueba antes de ejecutar el DELETE.

---

### T2.4 — [HITL] Corregir contenido de seeds D5 biométrico

**CORRECCIÓN v3.0 (CF-5):** NO se crean tablas nuevas. `ath_config_d5` y `ath_policy_d5`
ya existen con el patrón JSONB correcto del proyecto. El problema era de contenido.

**T2.4a — Corregir seed `bauth_20__ath_config_d5.sql`**

| Antes (v2.0) | Ahora (v3.0) |
|---|---|
| `SELECT dinámico FROM cfg_policy_library WHERE domain_map @> ARRAY['D5']` | 9 INSERT explícitos de config biométrica ISO/IEC 19794 |
| 20 filas de config FIDO2/WebAuthn (pertenece a D9) | `fingerprint_capture`, `face_recognition`, `iris_recognition`, `voice_verification`, `template_storage`, `liveness_detection`, `quality_threshold`, `enrollment_process`, `biometric_system` |

Seed ya escrito: `DDLs/seeds/bauth_20__ath_config_d5.sql` (v3.0, 2026-07-06)
Cada valor incluye campo `_sources` con la norma exacta que lo respalda.

**T2.4b — Enriquecer seed `bauth_32__ath_policy_d5.sql`**

| Antes (v2.0) | Ahora (v3.0) |
|---|---|
| 5 políticas biométricas básicas | 10 políticas completas |

Políticas nuevas añadidas (6-10):
- `BIOMETRIC_MULTIMODAL_OPTIONAL` — ISO 30107-3:2023 §4.3, NIST SP 800-63B-4 §5.2.3
- `BIOMETRIC_TEMPLATE_REVOCATION` — ISO/IEC 24745:2022 §7.4, NIST SP 800-53 AC-2(2)
- `BIOMETRIC_QUALITY_MINIMUM` — ISO/IEC 29794-1:2024, NIST IR 8382
- `BIOMETRIC_SPOOFING_MANDATORY_AAL3` — ISO 30107-3:2023 §7, NIST SP 800-63B-4 §5.2.3
- `BIOMETRIC_RETENTION_LIMIT` — GDPR Art.5/17, NIST SP 800-88r2 §2.5

Seed ya escrito: `DDLs/seeds/bauth_32__ath_policy_d5.sql` (v3.0, 2026-07-06)
Cada política incluye campos `_source_*` con la norma exacta.

**HITL:** Iván revisa el contenido de ambos seeds antes de ejecutar TRUNCATE+INSERT en VPS.
**Normas:** ISO/IEC 19794 series · ISO 30107-3:2023 · NIST SP 800-63B-4 §5.2.3 · GDPR Art.9 · NIST SP 800-88r2

---

### T2.5 — [HITL] Crear fis_access_method (D2 Físico)

```sql
-- Migración: 011_fis_access_method.sql
CREATE TABLE IF NOT EXISTS bauth.fis_access_method (
  method_id         text PRIMARY KEY,
  method_name       text NOT NULL,
  loa_level         integer NOT NULL,
  standard_ref      text NOT NULL,
  tech_protocol     text,                 -- 'ISO 14443-A' | 'Wiegand' | 'OSDP v2' ...
  is_legacy         boolean NOT NULL DEFAULT false,
  is_active         boolean NOT NULL DEFAULT true,
  description       text
);
-- Seeds: qr_dynamic, nfc_mifare_desfire, nfc_mifare_classic,
--        rfid_125khz, fingerprint_hash, face_hash, smartcard_x509, pin_pad
```

**HITL:** Iván aprueba.

---

### T2.6 — [HITL] Crear ath_phishing_policy (D9 — ALTA prioridad)

**Norma:** NIST SP 800-63B-4 Final Julio 2025 — phishing-resistant obligatorio AAL2+

```sql
-- Migración: 012_ath_phishing_policy.sql
CREATE TABLE IF NOT EXISTS bauth.ath_phishing_policy (
  policy_id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id              text NOT NULL,
  phishing_resistant_required boolean NOT NULL DEFAULT true,  -- NIST 800-63B-4 §4.2.2
  allowed_methods        text[] NOT NULL DEFAULT
    ARRAY['WEBAUTHN_PWDLESS','PASSKEY_DEVICE','SMARTCARD_X509'],
  syncable_passkeys_allowed boolean NOT NULL DEFAULT true,
  syncable_max_aal       text NOT NULL DEFAULT 'AAL2',         -- syncable = máximo AAL2
  device_bound_required_for_aal3 boolean NOT NULL DEFAULT true,
  min_aal_for_privileged text NOT NULL DEFAULT 'AAL3',
  is_active              boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);
```

**HITL:** Iván aprueba.

---

### T2.7 — [HITL] Crear sod_incompatible_role y sod_incompatible_function

**Norma:** NIST SP 800-53 Rev.5 AC-5 · ANSI/INCITS 359-2004 · ISO 27001:2022 A.5.18

```sql
-- Migración: 013_sod_tables.sql
BEGIN;

CREATE TABLE IF NOT EXISTS bauth.sod_incompatible_role (
  rule_id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  role_code_a          text NOT NULL,
  role_code_b          text NOT NULL,
  severity             text NOT NULL DEFAULT 'critical',   -- 'critical' | 'high' | 'medium'
  mitigation           text NOT NULL DEFAULT 'DENY',       -- 'DENY' | 'WARN' | 'APPROVE'
  description          text NOT NULL,
  standard_ref         text,
  tenant_scope         text NOT NULL DEFAULT 'ALL',        -- 'ALL' | tenant_id específico
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sod_roles UNIQUE (role_code_a, role_code_b)
);

CREATE TABLE IF NOT EXISTS bauth.sod_incompatible_function (
  rule_id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  atom_slug_a          text NOT NULL,       -- átomo que no puede coexistir con...
  atom_slug_b          text NOT NULL,       -- ...este átomo
  severity             text NOT NULL DEFAULT 'critical',
  mitigation           text NOT NULL DEFAULT 'DENY',
  description          text NOT NULL,
  standard_ref         text,
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sod_functions UNIQUE (atom_slug_a, atom_slug_b)
);

COMMIT;
```

**HITL:** Iván aprueba.

---

### T2.8 — [HITL] Crear tryton_model_access

```sql
-- Migración: 014_tryton_model_access.sql
CREATE TABLE IF NOT EXISTS bauth.tryton_model_access (
  access_id    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  role_id      text NOT NULL,
  model_name   text NOT NULL,         -- 'sale.order' | 'account.invoice' ...
  perm_read    boolean NOT NULL DEFAULT false,
  perm_write   boolean NOT NULL DEFAULT false,
  perm_create  boolean NOT NULL DEFAULT false,
  perm_delete  boolean NOT NULL DEFAULT false,
  ir_field_id  text,                  -- ir.model.access.field_id en Tryton
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_tryton_model_access UNIQUE (role_id, model_name)
);
```

**HITL:** Iván aprueba.

---

### T2.9 — T2.15: Tablas restantes

Las siguientes tablas siguen el mismo patrón de aprobación individual:

| Tarea | Tabla | Prioridad | Norma clave |
|---|---|:---:|---|
| T2.9 | `net_device_trust_policy` | MEDIA | NIST SP 800-207 ZTA, CISA ZTMM v2 |
| T2.10 | `dlg_delegation_policy` | MEDIA | ANSI/INCITS 359-2004 DSD, NIST AC-5 |
| T2.11a | `sync_kc_config` | MEDIA | OpenID Connect, Keycloak Admin REST API |
| T2.11b | `sync_tryton_config` | MEDIA | Tryton JSON-RPC 2.0 |
| T2.11c | `sync_drift_config` | MEDIA | reconcile loop SBOS (60s interval) |
| T2.12a | `aud_event_catalog` | MEDIA | ISO 27001:2022 A.8.15, NIST AU-2 |
| T2.12b | `aud_review_policy` | MEDIA | ISO 27001 A.5.15, PCI DSS Req.7 |
| T2.13a | `blk_did_registry` | BAJA | W3C DID Core, NIST IR 8202 |
| T2.13b | `blk_smart_contract` | BAJA | EIP-725/735, Hyperledger Besu QBFT |
| T2.13c | `blk_besu_node` | BAJA | Hyperledger Besu, QBFT consensus |
| T2.14a | `fin_transaction_schedule` | BAJA | PCI DSS 4.0.1 Req.10.3.2 |
| T2.14b | `fin_geospatial_control` | BAJA | PCI DSS Req.7, NIST PE-3 |
| T2.15a | `attendance_policy` | BAJA | Ley General del Trabajo Bolivia |
| T2.15b | `ath_rotation_policy` | BAJA | NIST SP 800-63B-4 §5.2.7 |

**Cada una requiere HITL individual antes de ejecutar en VPS.**

---

## FASE 3 — NUEVO MODELO ATÓMICO D.A.M.V. (Aditivo)

### Principio de coexistencia

Los 5.808 átomos existentes NO se tocan. El código Rust los usa.
Los nuevos átomos D.A.M.V. se insertan a partir de la posición **5.809**.

```
Posiciones reservadas (nuevo modelo):
  D00 CRUD:    5809 – 5916  (108 átomos — ver BAUTH-CATALOGO-ATOMOS-D00-CRUD.md)
  D1  CRUD:    5917 – 6400  (máx 484 por dominio)
  D2  CRUD:    6401 – 6884
  D3  CRUD:    6885 – 7368
  D4  CRUD:    7369 – 7852  (D4 = Temporal — una vez resuelto T1.4)
  D5  CRUD:    7853 – 8336  (D5 = Biométrico — usando nueva nomenclatura)
  ...
```

### T3.1 — [HITL] Insertar D0 con 108 átomos CRUD

**Dependencias:** T1.1, T1.2, T1.4 (decisión de numeración), T1.3 (tabla idn_atributo).

**Fuente:** `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` — 108 átomos verificados,
Diseño B (CRUD por campo) confirmado.

**DDL:** `db/migrations/003_d00_identidad_organizacional_CRUD.sql` ya existe (574 líneas).
Revisar y adaptar según resultado de T1.4 antes de aplicar.

**HITL:** Iván aprueba el DDL revisado.

### T3.2 — [HITL] Estrategia de coexistencia modelo viejo / nuevo

**Pregunta para Iván:** ¿El nuevo modelo D.A.M.V. reemplaza al monolítico en el mismo
`privilege_atom` con posiciones más altas, o se crea una tabla separada `privilege_atom_v2`?

**Recomendación:** Misma tabla, posiciones 5809+. El código Rust puede detectar
el formato por el `atom_slug` (nuevo: contiene puntos `D5.device.register.C` vs
viejo: contiene app.grupo.dominio.verbo `tryton.g1.d5.nuevo`).

**HITL:** Decisión de Iván.

---

## FASE 4 — SEEDS Y DATOS

### Tablas críticas a poblar (actualmente vacías)

| Tabla | Registros sugeridos | Fuente de datos |
|---|:---:|---|
| `fin_transaction_type` | 20 tipos | `BAUTH-DDL-DOMINIO-FINANCIERO.md` + SIN Bolivia |
| `fin_approval_chain` | 4 cadenas | Niveles estándar Bolivia |
| `fin_approval_level` | 12 niveles | Tiers 2000/10000/50000/ilimitado |
| `bio_enrollment_policy` | 1 política default | Argon2id, FMR 1:10000 |
| `bio_gdpr_config` | 1 por tenant | GDPR Art.9 |
| `ath_phishing_policy` | 1 por tenant | NIST 800-63B-4 |
| `sod_incompatible_role` | 10+ reglas | PCI DSS, SOX §404 |
| `sod_incompatible_function` | 5+ reglas | Emisión ≠ Aprobación, Pago ≠ Conciliación |
| `sync_kc_config` | 1 por realm | Keycloak config |
| `sync_tryton_config` | 1 | Tryton JSON-RPC |
| `fis_access_zone` | 5+ zonas | Área estándar SBOS |
| `fis_access_method` | 8 métodos | QR, NFC, RFID, Smartcard, Biométrico, PIN |
| `idn_atributo` | Migrar desde org_* | Migración T4.9 |

### T4.9 — Migración de org_empresa y org_sucursal a idn_atributo

```sql
-- Poblar idn_atributo con datos de org_empresa (1 fila existente)
INSERT INTO bauth.idn_atributo
  (entidad_tipo, entidad_id, tenant_id, domain_code,
   atributo_codigo, atributo_valor, is_primary, is_active, ctx_id)
SELECT
  'EMPRESA', empresa_id, tenant_id, 0,
  'RAZON_SOCIAL', razon_social, true, true, ctx_id
FROM bauth.org_empresa
UNION ALL
SELECT 'EMPRESA', empresa_id, tenant_id, 0,
  'NIT', nit, true, true, ctx_id
FROM bauth.org_empresa
UNION ALL
SELECT 'EMPRESA', empresa_id, tenant_id, 0,
  'REGIMEN_FISCAL', regimen_fiscal, true, true, ctx_id
FROM bauth.org_empresa;
-- ... repetir para cada campo relevante de org_empresa y org_sucursal
```

---

## FASE 5 — ADAPTACIÓN DEL CÓDIGO RUST

### Archivos que necesitan cambios (en orden de impacto)

| Módulo Rust | Cambio requerido | Tareas que lo activan |
|---|---|---|
| `domain/bitmask.rs` | Soportar domain_code = 0 en validación | T1.1, T1.2 |
| `db/postgres.rs` | Struct `RoleTemplate` += 5 nuevos campos | T2.1 |
| `db/postgres.rs` | Struct `AuthMethod` += 7 campos | T2.2 |
| `catalog/loader.rs` | Reconocer formato slug D.A.M.V. vs monolítico | T3.2 |
| Nuevo: `domain/bio_policy.rs` | Leer bio_method, bio_enrollment_policy | T2.4 |
| Nuevo: `sync/kc_config.rs` | Leer sync_kc_config | T2.11 |
| Nuevo: `sync/tryton_config.rs` | Leer sync_tryton_config | T2.11 |
| `engine/tryton_engine.rs` | Usar tryton_model_access | T2.8 |
| `domain/sod.rs` | Leer sod_incompatible_role/function | T2.7 |

**Regla P7:** El código Rust se modifica DESPUÉS de que las tablas existan en VPS.
Nunca escribir Rust que apunte a tablas que aún no se han creado.

---

## CRITERIOS DE CIERRE — DEFINICIÓN DE "REPARACIÓN COMPLETA"

La reparación está completa cuando TODOS los siguientes criterios son verdaderos:

```
☐ 1. privilege_domain tiene D0 registrado (domain_code = 0)
☐ 2. CHECK constraint acepta domain_code = 0
☐ 3. idn_atributo existe y tiene datos de org_empresa/org_sucursal migrados
☐ 4. Los 108 átomos D00 existen en privilege_atom (posiciones 5809-5916)
☐ 5. ath_config_d5 contiene SOLO configuración biométrica (no FIDO2/passkeys)
☐ 6. bio_method, bio_enrollment_policy, bio_gdpr_config existen y tienen datos
☐ 7. ath_method tiene columnas is_phishing_resistant, is_device_bound, etc.
☐ 8. idn_role_template tiene columnas timezone, inactivity_timeout, etc.
☐ 9. bos_rol_template_history renombrada a idn_role_template_history
☐ 10. sod_incompatible_role y sod_incompatible_function existen con reglas core
☐ 11. ath_phishing_policy existe y tiene política NIST 800-63B-4 para el tenant
☐ 12. sync_kc_config y sync_tryton_config existen con configuración activa
☐ 13. fin_transaction_type tiene los 20 tipos SIN Bolivia
☐ 14. tryton_model_access existe con mappings para los 25 modelos de Tryton
☐ 15. Código Rust compila sin errores: cargo check --workspace
☐ 16. Tests de dominio pasan: cargo test domain::
☐ 17. Reconcile loop ejecuta sin errores en VPS por 1 ciclo (60s)
☐ 18. Testeador certifica: VERDADERO en VPS para cada criterio 1-17
```

---

## HITL CHECKPOINT — Resumen de decisiones que Iván debe tomar

| # | Decisión | Impacto si no se decide | Bloquea |
|---|---|---|---|
| H1 | Numeración D4/D5 en catálogo de átomos (Opción A o B) | Átomos con posiciones incorrectas | T3.1, T3.3 |
| H2 | Aprobar CHECK constraint D0 (T1.1) | D0 bloqueado para siempre en esta BD | T1.2, T3.1 |
| H3 | Aprobar diseño idn_atributo (T1.3) | D00 sin tabla EAV | T4.9 |
| H4 | Renombrar bos_rol_template_history (T1.5) | Nombre legacy permanece | T5.x |
| H5 | Aprobar 5 columnas idn_role_template (T2.1) | Template incompleto | T5.2 |
| H6 | Aprobar 7 columnas ath_method (T2.2) | NIST 800-63B-4 no satisfecho | T5.2 |
| H7 | Aprobar migración contenido D5→D9 (T2.3) | D5 con contenido erróneo indefinidamente | T2.4 |
| H8 | Aprobar contenido seeds ath_config_d5 (9 configs) + ath_policy_d5 (10 políticas) — T2.4a/b | D5 con contenido FIDO2 erróneo indefinidamente | T2.3 |
| H9 | Aprobar sod_incompatible_role / function (T2.7) | SoD sin enforcement | T5.x |
| H10 | Estrategia coexistencia modelo viejo / nuevo (T3.2) | Ambigüedad en código Rust | T3.3, T5.4 |

---

## CONVENCIONES CORREGIDAS DE ARCHIVOS DDL (v2.0)

> Ver CF-1, CF-2, CF-3 al inicio de este documento.

### Ubicación de archivos

```
CORRECTO:
  DDLs compartido:  /opt/skull/orquestador/proyectos/SBOS/DDLs/
    ├── migrations/   ← DDL de estructura (CREATE TABLE, ALTER en migración oficial D00)
    └── seeds/        ← Datos (INSERT, seeds de configuración)

  Archivo núcleo:   DDLs/migrations/sbos_00__esquema_base.sql
    → Contiene los CREATE TABLE de privilege_domain, ath_method, idn_role_template
    → En desarrollo: EDITAR ESTE ARCHIVO para agregar columnas

INCORRECTO (no usar):
  BauthAgent/db/migrations/  (archivos de referencia local, no la fuente canónica)
```

### Archivos existentes en DDLs/migrations/ de bauth

```
sbos_00__esquema_base.sql         ← NÚCLEO — editar para columnas faltantes
bauth_10__d00_identidad_organizacional.sql  ← D00: ALTER CHECK + is_internal (ya escrito)
bauth_20__framework_politicas.sql  ← Framework de políticas
bauth_30__compliance_qa.sql        ← QA de cumplimiento
```

### Archivos existentes relevantes en DDLs/seeds/ de bauth

```
bauth_14__ath_method.sql          ← Seed de métodos de autenticación (modificar)
bauth_20__ath_config_d5.sql       ← Seed config D5 (corregir contenido)
bauth_24__ath_config_d9.sql       ← Seed config D9 (agregar tipos FIDO2 de D5)
bauth_48__idn_role_template.sql   ← DDL de idn_role_template (EDITAR para cols faltantes)
bauth_65__mobile_app_config.sql   ← Config CONSUMER_MOBILE (revisar para OIDC)
bauth_69__aud_compliance_map.sql  ← Seed compliance map (agregar eventos bNotify)
bauth_70__compliance_qa.sql       ← Último seed bauth (próximo número: 71)
```

### Archivos a CREAR en esta fase de reparación

**Migraciones nuevas (DDLs/migrations/) — estructura:**
```
bauth_40__idn_atributo.sql        → T1.3: tabla EAV para identidad organizacional
bauth_41__bio_tables.sql          → T2.4: bio_method, bio_enrollment_policy, bio_gdpr_config
bauth_42__ath_phishing_policy.sql → T2.6: política phishing D9
bauth_43__sod_tables.sql          → T2.7: SoD incompatibilidades
bauth_44__tryton_model_access.sql → T2.8: mapping Tryton
bauth_45__ath_oidc_client.sql     → T10.1: registro OIDC para bNotify/bRocket/bChat
bauth_46__aud_caep_config.sql     → T10.2: tabla config emisión CAEP hacia bNotify
bauth_47__fis_access_method.sql   → T2.5: métodos acceso físico D2
bauth_48__net_device_trust.sql    → T2.9: confianza de dispositivos D7
bauth_49__dlg_delegation.sql      → T2.10: delegación D10
bauth_50__sync_config.sql         → T2.11: config KC/Tryton/drift
bauth_51__aud_review_policy.sql   → T2.12: política revisión auditoría
bauth_52__blk_tables.sql          → T2.13: blockchain D12
bauth_53__fin_schedule_geo.sql    → T2.14: finanzas D3 restantes
bauth_54__attendance_rotation.sql → T2.15: asistencia y rotación
```

**Ediciones a archivos existentes en sbos_00__esquema_base.sql:**
```
[T2.1] Agregar 5 columnas a CREATE TABLE idn_role_template:
       timezone, inactivity_timeout_s, force_logout_at_shift_end,
       reauth_interval_s, audit_retention_days

[T2.2] Agregar 7 columnas a CREATE TABLE ath_method:
       is_phishing_resistant, is_device_bound, is_syncable,
       max_aal, can_be_primary, can_be_fallback, recovery_eligible
```

**Seeds nuevos (DDLs/seeds/):**
```
bauth_71__bio_method.sql          → T4.1: 4 tipos biometría ISO/IEC 19794
bauth_72__bio_enrollment_policy.sql → T4.2: política enrolamiento biométrico
bauth_73__ath_phishing_policy.sql → T4.3: política phishing NIST 800-63B-4
bauth_74__sod_incompatible_role.sql → T4.4: reglas SoD rol
bauth_75__ath_oidc_client.sql     → T10.3: seed cliente OIDC bRocket/bChat
bauth_76__aud_compliance_map_bnotify.sql → T10.5: event_types chat/identity/notify
```

### Encabezado obligatorio de cada archivo nuevo

```sql
-- =============================================================================
-- bauth_NN__nombre.sql — [descripción del objeto]
-- =============================================================================
-- Propósito  : [qué hace]
-- Normas     : [estándares aplicables]
-- Fase       : Reparación v2.0 — [nombre de tarea T.X.X]
-- HITL       : Aprobado por Iván [fecha] / Pendiente aprobación
-- Idempotente: Sí — IF NOT EXISTS / ON CONFLICT DO NOTHING
-- =============================================================================
BEGIN;
-- ... contenido ...
-- Verificación:
-- SELECT ... (confirma el cambio)
COMMIT;
```

---

## SECCIÓN 10 — REQUISITOS DE bNotify EN DOMINIOS bAuth

> Origen: análisis de documentos BNOTIFY-002, BNOTIFY-004, BNOTIFY-008.
> bNotify depende de que bAuth provea estas tablas, vistas y datos exactos.

### 10.1 — [HITL] T10.1: Tabla `ath_oidc_client` (D9 Credenciales)

**Necesidad:** bNotify y bRocket/bChat necesitan registrar clientes OIDC en bAuth.
La vista `v_bauth_user_channel` de bNotify hace login vía OIDC usando `client_id`
del tipo `rocketchat-{tenant_id}`. Este registro debe vivir en una tabla.

**Archivo a crear:** `DDLs/migrations/bauth_45__ath_oidc_client.sql`

```sql
CREATE TABLE IF NOT EXISTS bauth.ath_oidc_client (
  client_id          text PRIMARY KEY,   -- 'rocketchat-{tenant_id}' | 'bchat-{tenant_id}'
  tenant_id          text NOT NULL,
  client_type        text NOT NULL,      -- 'CONFIDENTIAL' | 'PUBLIC'
  redirect_uris      text[] NOT NULL DEFAULT '{}',
  grant_types        text[] NOT NULL DEFAULT ARRAY['authorization_code','refresh_token'],
  response_types     text[] NOT NULL DEFAULT ARRAY['code'],
  scopes_allowed     text[] NOT NULL DEFAULT ARRAY['openid','profile','email','sbos_roles'],
  token_endpoint_auth_method text NOT NULL DEFAULT 'client_secret_post',
  id_token_alg       text NOT NULL DEFAULT 'EdDSA',    -- Firma Ed25519 bAuth
  vault_path         text,               -- Ruta en Vault donde está el client_secret
  app_type           text NOT NULL,      -- 'BROCKET' | 'BCHAT' | 'TRYTON' | 'CUSTOM'
  is_active          boolean NOT NULL DEFAULT true,
  ctx_id             text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.ath_oidc_client IS
  'D9 — Registro de clientes OIDC autorizados para usar bAuth como Identity Provider. '
  'Un registro por tenant×aplicación. client_secret almacenado en Vault (nunca en BD). '
  'Norma: RFC 6749 §2, RFC 7591 Dynamic Client Registration.';
```

**HITL:** Iván aprueba diseño antes de aplicar.
**Norma:** OAuth 2.0 RFC 6749 §2, RFC 7591, OpenID Connect Core §2.

---

### 10.2 — [HITL] T10.2: Tabla `aud_caep_config` (D8/D9 — CAEP hacia bNotify)

**Necesidad:** bAuth actúa como SSF Transmitter (Shared Signals Framework RFC 8935).
Debe emitir eventos CAEP (`session-revoked`, `credential-change`, etc.) hacia bNotify.
Necesita una tabla de configuración que registre los receptores (SSF Receivers).

**Archivo a crear:** `DDLs/migrations/bauth_46__aud_caep_config.sql`

```sql
CREATE TABLE IF NOT EXISTS bauth.aud_caep_config (
  config_id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  receiver_daemon    text NOT NULL,      -- 'bnotify' | 'bnexus' | futuro
  grpc_endpoint      text NOT NULL,      -- 'unix:///run/bos/bnotify.sock'
  event_types        text[] NOT NULL,    -- ['session-revoked','credential-change',...]
  is_active          boolean NOT NULL DEFAULT true,
  retry_max          integer NOT NULL DEFAULT 3,
  retry_backoff_ms   integer NOT NULL DEFAULT 500,
  ctx_id             text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.aud_caep_config IS
  'D8/D9 — Configuración de emisión CAEP (Continuous Access Evaluation Protocol). '
  'bAuth es SSF Transmitter (RFC 8935). Cada fila es un receptor registrado. '
  'Norma: RFC 8935 (SSF), CAEP draft-ietf-secevent-caep.';
```

**Seed inicial** (`DDLs/seeds/bauth_75__aud_caep_config.sql`):
```sql
INSERT INTO bauth.aud_caep_config
  (receiver_daemon, grpc_endpoint, event_types, is_active, ctx_id)
VALUES
  ('bnotify',
   'unix:///run/bos/bnotify.sock',
   ARRAY['session-revoked','credential-change','assurance-level-change',
         'device-compliance-change','risk-level-change'],
   true,
   'seed-init-caep')
ON CONFLICT DO NOTHING;
```

**HITL:** Iván aprueba.
**Norma:** RFC 8935 (SSF), draft CAEP, NIST SP 800-63B-4 §6 (CAEP).

---

### 10.3 — Conflicto columnas `idn_atributo` — vista bNotify debe actualizarse

**CORRECCIÓN v3.0 (CF-6):**
La §10.3 anterior cometió un error: intentó cambiar el diseño CANÓNICO de `idn_atributo`
para adaptarse a la vista de bNotify. Esto está al revés — la vista bNotify fue escrita
contra un diseño **anterior e incorrecto** de idn_atributo.

**Diseño canónico (fuente de verdad):** `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`
```
entidad_tipo: 'tenant'|'bdomain'|'bsubdomain'|'pos'|'actor'
category + attr_key: clasifican el atributo (no 'atributo_tipo')
value_text / value_data: el valor (no 'valor')
is_verified (no 'verificado')  ·  is_primary (no 'activo' para ese concepto)
```

**Vista bNotify que debe actualizarse:**
`bnotify.v_bauth_user_channel` en `BNOTIFY-008 §4.1` usa columnas obsoletas:
- `a_email.user_id` → debe ser `a_email.entidad_id` (cuando entidad_tipo='actor')
- `a_email.atributo_tipo = 'EMAIL'` → debe ser `a_email.attr_key = 'email'`
- `a_email.activo = TRUE` → debe ser `a_email.is_primary = true` (o condición apropiada)
- `a_email.verificado = TRUE` → debe ser `a_email.is_verified = true`
- `bos_user_template` → debe ser `bauth.idn_actor_template` o nombre canónico

**Tarea:** Cuando se cree `idn_atributo` (T1.3 aprobado por Iván), coordinar con bNotify
para actualizar `v_bauth_user_channel` usando las columnas canónicas.
Contrato bilateral → documentar en `context/contracts/BOS-BAUTH-CONTRATOS.md`.

**HITL:** Iván aprueba el diseño canónico de idn_atributo (CF-6) antes de crear la tabla.
La actualización de la vista bNotify se coordina en la misma ventana.

---

### 10.4 — Complementar seed `aud_compliance_map` con eventos bNotify

**Archivo existente:** `DDLs/seeds/bauth_69__aud_compliance_map.sql`
**Problema:** El seed actual carga desde `cfg_policy_library` (normas NIST/ISO/etc.)
pero NO incluye los event_types de la taxonomía bNotify (chat.*, identity.*, notify.*).

BNOTIFY-004 requiere que `aud_compliance_map` tenga columna `event_type → audit_class`
para que bNotify pueda clasificar cada evento antes de persistirlo.

**Verificar:** si `aud_compliance_map` tiene columnas `event_type` y `audit_class`.
Si no, la tabla necesita ser corregida (editar su CREATE TABLE en sbos_00__).

**Seed a crear:** `DDLs/seeds/bauth_76__aud_compliance_map_bnotify.sql`

```sql
-- Eventos bNotify — clasificación A/B/C según BNOTIFY-004
INSERT INTO bauth.aud_compliance_map (event_type, audit_class, active)
VALUES
  -- Familia chat.*
  ('chat.room.created',            'B', true),
  ('chat.message.sent',            'B', true),
  ('chat.message.deleted_any',     'A', true),
  ('chat.moderation.user_banned',  'A', true),
  ('chat.moderation.report_filed', 'A', true),
  ('chat.moderation.reported_content_viewed', 'A', true),
  ('chat.abuse.rate_limited',      'A', true),
  ('chat.media.uploaded',          'B', true),
  -- Familia identity.*
  ('identity.self_registered',     'A', true),
  ('identity.phone_verified',      'A', true),
  ('identity.tier_promoted',       'A', true),
  ('identity.device_bound',        'A', true),
  ('identity.session_revoked',     'A', true),
  ('identity.credential_changed',  'A', true),
  ('identity.account_deleted',     'A', true),
  -- Familia notify.*
  ('notify.delivery.dlq',          'A', true),
  ('notify.intent.rejected',       'B', true),
  ('notify.delivery.completed',    'C', true),
  ('notify.caep.session_revoked',  'A', true)
ON CONFLICT (event_type) DO UPDATE SET audit_class = EXCLUDED.audit_class;
```

**HITL:** Verificar estructura de `aud_compliance_map` antes de escribir seed.

---

### 10.5 — `mobile_app_config` — verificar CONSUMER_MOBILE para bNotify/bChat

**Archivo existente:** `DDLs/seeds/bauth_65__mobile_app_config.sql`
**Tarea:** Verificar que el seed contiene las configuraciones OIDC que bNotify necesita:
- `access_token_ttl_s = 3600` (1h) para CONSUMER_MOBILE
- `refresh_token_ttl_s = 2592000` (30d) para CONSUMER_MOBILE
- `max_concurrent_sessions = 5` para CONSUMER_MOBILE

Si faltan, agregar al seed existente (edición in-place).

**Fuente:** BNOTIFY-002 §5 "Perfil de sesión CONSUMER_MOBILE".

---

### 10.6 — Resumen de impacto bNotify en tabla de tareas

| Tarea | Archivo DDL/seeds | Depende de |
|---|---|---|
| T10.1 ath_oidc_client | bauth_45__ath_oidc_client.sql | T1.1 (D0) |
| T10.2 aud_caep_config | bauth_46__aud_caep_config.sql | T1.1 |
| T10.3 idn_atributo corr. | Corrección en bauth_40__idn_atributo.sql | T1.3 |
| T10.4 aud_compliance_map | bauth_76__aud_compliance_map_bnotify.sql | T2.12 |
| T10.5 mobile_app_config | bauth_65__ (editar) | Ninguna |
| T10.6 OIDC seed | bauth_75__aud_caep_config.sql | T10.2 |

**Adición al HITL CHECKPOINT:**
| H11 | Aprobar columnas idn_atributo (CF-4 §10.3) — user_id vs entidad_id | Vista bNotify rota | T10.3, T1.3 |
| H12 | Aprobar ath_oidc_client (§10.1) | OIDC bRocket/bChat imposible | T10.1 |
| H13 | Confirmar estructura aud_compliance_map para event_type (§10.4) | bNotify no clasifica | T10.4 |

---

## CRITERIOS DE CIERRE ACTUALIZADOS (v2.0)

La reparación está completa cuando TODOS los siguientes criterios son verdaderos:

```
Estructura DDL (verificar en sbos_00__esquema_base.sql):
☐ 1.  privilege_domain CHECK acepta domain_code = 0
☐ 2.  idn_role_template tiene 5 columnas adicionales (timezone, etc.)
☐ 3.  ath_method tiene 7 columnas adicionales (is_phishing_resistant, etc.)

Datos en VPS (verificar con SELECT):
☐ 4.  privilege_domain tiene D0 registrado (domain_code = 0)
☐ 5.  Los 108 átomos D00 existen en privilege_atom (posiciones 5809-5916)
☐ 6.  ath_config_d5 tiene 9 configs biométricas ISO/IEC 19794 (CERO filas FIDO2/passkeys)
☐ 7.  ath_policy_d5 tiene 10 políticas biométricas con JSONB config + _sources norma (CF-5)
☐ 8.  sod_incompatible_role y sod_incompatible_function con reglas core
☐ 9.  ath_phishing_policy con política NIST 800-63B-4
☐ 10. sync_kc_config y sync_tryton_config con configuración activa
☐ 11. fin_transaction_type tiene los 20 tipos SIN Bolivia

Requisitos bNotify:
☐ 12. ath_oidc_client existe con registro para bRocket del tenant activo
☐ 13. aud_caep_config tiene entrada para bnotify con 5 event types CAEP
☐ 14. idn_atributo tiene columnas canónicas: entidad_tipo/entidad_id/category/attr_key/is_verified (CF-6)
☐ 15. aud_compliance_map tiene los 19 event_types de bNotify con clase A/B/C
☐ 16. bos_rol_template_history renombrada a idn_role_template_history

Código Rust:
☐ 17. cargo check --workspace pasa sin errores
☐ 18. cargo test domain:: pasa
☐ 19. Reconcile loop ejecuta sin errores en VPS por 1 ciclo (60s)
☐ 20. Testeador certifica: VERDADERO en VPS para cada criterio 1-19
```

---

## SECCIÓN 11 — BIBLIOTECA DE POLÍTICAS cfg_policy_library (2026-07-07)

> Esta sección registra las decisiones y el trabajo ejecutado en la sesión del 2026-07-07.
> El trabajo fue aprobado por el humano en tiempo real durante la sesión.
> Documento de referencia: `BAUTH-ESTADO-BIBLIOTECA-POLITICAS-2026-07-07.md`

### 11.1 — Qué se hizo y qué herramientas existen

Se transformó `bauth.cfg_policy_library` en el **catálogo normativo de ingredientes** de bAuth.
La tabla ya existía con 9,184 nodos. Se le agregó jerarquía semántica completa.

**Fuentes analizadas:**
- `Policies_Authentication_Framework.json` (104 KB, JSON5) — políticas v3.0.0
- `Authentication_Framework.json` (603 KB, JSON5) — framework v2.0.0, 36 grupos

**Migraciones ejecutadas en VPS (sbos-data · SBOS_db) — COMPLETADAS ✅:**

| Migración | Resultado |
|---|---|
| `bauth_40__cfg_policy_library_ltree.sql` | path ltree + 6 columnas operacionales + 4 índices — 9,184 filas |
| `bauth_41__cfg_policy_library_level_type.sql` | level_type clasificado · value_type corregido · default_value poblado |
| `bauth_42__policy_set_split_and_compose.sql` | POLICY_SET vs POLICY separados (XACML 3.0) · funciones de composición · vista |

**Jerarquía final (alineada con XACML 3.0 · NIST SP 800-207):**

```
FRAMEWORK (58) → DOMAIN (145) → POLICY_SET (651) → POLICY (559) → RULE (2275) → PROPERTY (5496)
Total: 9,184 nodos
```

**Herramientas disponibles en la BD:**

```sql
-- Componer subárbol → JSONB anidado (presentación, diff, exportación, verificación)
SELECT bauth.fn_compose_tree('path.ltree.del.nodo'::ltree, NULL);

-- Descomponer JSONB → filas (importar políticas nuevas — solo SKULL/migraciones)
SELECT bauth.fn_decompose_tree('{"nodo": {...}}'::jsonb, 'path.padre'::ltree, 'fuente');

-- Vista de navegación indentada (ORDER BY path = orden DFS del JSON original)
SELECT * FROM bauth.v_policy_tree WHERE path <@ 'dominio'::ltree;

-- Query por dominio (índice GIN — eficiente)
SELECT * FROM bauth.cfg_policy_library WHERE domain_map @> ARRAY['D7'] ORDER BY path;
```

---

### 11.2 — D99: Dominio Administrativo Global — DECISIÓN ADOPTADA ✅

**Decisión tomada (aprobada por el humano 2026-07-07):**
Los 447 nodos clasificados como `{SEC}` se renombraron a `{D99}`.

**D99 = Dominio Administrativo Global:**
- Contiene: criptografía global, resistencia cuántica, gestión de claves, auditoría base, metadatos del framework
- **NO entra al BitMask 64-bit** — no es permiso de usuario, es configuración del sistema
- Solo cambia por migración HITL aprobada — nunca desde la UI ni por runtime JSON-RPC
- En NIST SP 800-207: **Control Plane Policies** · En NIST SP 800-53: **PM Controls** · En ISO 27001: **Baseline Controls Annex A §8**

**Migración ejecutada:**
```sql
UPDATE bauth.cfg_policy_library
SET domain_map = ARRAY(SELECT CASE WHEN d = 'SEC' THEN 'D99' ELSE d END FROM unnest(domain_map) d)
WHERE domain_map @> ARRAY['SEC'];
-- UPDATE 447
```

**Documento de referencia:** `BAUTH-D99-DOMINIO-GLOBAL.md`

---

### 11.3 — Nuevo método JSON-RPC: bauth.config.global_get — PENDIENTE IMPLEMENTACIÓN

bAuth actúa como **PAP + PIP** (NIST SP 800-207): es la autoridad que emite las políticas D99
y todos los daemons SBOS deben adoptarlas como reglas irrenunciables de operación.

**Especificación:**

| Atributo | Valor |
|---|---|
| Método JSON-RPC | `bauth.config.global_get` |
| Socket | `/run/bos/bauth.sock` (ADR-020) |
| Fuente de datos | `bauth.cfg_policy_library WHERE domain_map @> ARRAY['D99']` + `fn_compose_tree()` |
| Handler Rust a crear | `server/jsonrpc.rs` → `handle_config_global_get()` |

**Flujo de distribución:**
1. Al arrancar, cada daemon SBOS llama `bauth.config.global_get` y carga D99
2. bAuth notifica cambios en D99 vía bkernel CDC (WAL → Redis Streams)
3. Los daemons escuchan el stream y recargan sin reiniciar

**Tarea pendiente:** `T11.3` — implementar handler Rust + contrato en `context/contracts/`
**Bloquea:** integración de bkernel, biedata, bsearch, bnexus, bnotify con configuración global

---

### 11.4 — Impacto en DDL: tablas potencialmente supersedidas — HITL REQUERIDO

`cfg_policy_library` ahora cubre el mismo dato que 25 tablas estáticas, pero con mejor estructura.

**Diferencia conceptual (NO son exactamente lo mismo):**

```
cfg_policy_library  =  CATÁLOGO (qué PUEDE configurarse — normativo, inmutable para SU)
ath_config_dN       =  CONFIGURACIÓN ACTIVA del tenant (qué IS configurado)
ath_policy_dN       =  POLÍTICA EVALUADA en runtime (qué rule SE APLICA)
```

**Tablas afectadas y su estado actual:**

| Grupo | Tablas | Filas aprox. | Estado |
|---|---|---|---|
| `ath_config_d1..d12` | 12 tablas | 14–20 c/u | ⚠️ Supersedidas por cfg_policy_library como catálogo |
| `ath_policy_d1..d12` | 12 tablas | 48–302 c/u | ⚠️ Supersedidas por cfg_policy_library + fn_compose_tree |
| `ath_config` | 1 tabla | 0 | ⚠️ Vacía y supersedida |
| `ath_policy` | 1 tabla | 0 | ⚠️ Vacía y supersedida |

**Propuesta arquitectónica para reemplazarlas (requiere H14):**

```
cfg_policy_library (catálogo — ya existe ✅)
    │  SU selecciona RULES de aquí
    ▼
cfg_tenant_config (NUEVA — composición activa del tenant)   ← reemplaza ath_config_dN
    │  bAuth evalúa en runtime (PDP)
    ▼
cfg_rule_evaluation (NUEVA — caché PDP, no persistente)     ← reemplaza ath_policy_dN
```

Esto elimina 25 tablas estáticas con esquema fijo y deja una arquitectura dinámica
que evoluciona sin migraciones estructurales de esquema.

**HITL requerido: H14** — ver sección HITL CHECKPOINT más abajo.

---

### 11.5 — Actualización del HITL CHECKPOINT

Agregar a la tabla de decisiones pendientes:

| # | Decisión | Impacto si no se decide | Bloquea |
|---|---|---|---|
| H14 | Aprobar deprecación de `ath_config_d1..d12` + `ath_policy_d1..d12` (25 tablas) y su reemplazo por `cfg_tenant_config` + `cfg_rule_evaluation` | Arquitectura dual confusa: catálogo nuevo + tablas estáticas antiguas coexisten sin rol claro | T11.x |
| H15 | Aprobar diseño de `cfg_tenant_config` (cómo referencia nodos de cfg_policy_library) | SU no puede componer roles/usuarios desde la biblioteca | Templates, FASE 4 |
| H16 | Aprobar contrato `BAUTH-SBOS-GLOBAL-CONFIG-CONTRATO.md` en `context/contracts/` para distribución D99 | Daemons no saben que deben consumir D99 desde bAuth | T11.3, integración bkernel |

---

### 11.6 — Actualización de CRITERIOS DE CIERRE

Agregar a la lista de criterios:

```
Biblioteca de políticas (cfg_policy_library):
☐ 21. cfg_policy_library tiene 9,184 nodos con level_type clasificado (FRAMEWORK/DOMAIN/POLICY_SET/POLICY/RULE/PROPERTY)
☐ 22. Todos los nodos PROPERTY tienen value_type (BOOLEAN/INTEGER/FLOAT/TEXT) y default_value
☐ 23. D99 tiene 447 nodos — ninguno tiene {SEC} en domain_map
☐ 24. fn_compose_tree() devuelve JSONB válido para cualquier path del árbol
☐ 25. bauth.config.global_get implementado en Rust y responde a daemons consumidores
☐ 26. Decisión H14 tomada: ath_config_dN y ath_policy_dN deprecadas O plan de coexistencia documentado
```

---

*Plan Maestro v4.0 · bauth-developer · 2026-07-07*
*v1.0 → v2.0: ruta DDLs/ compartida + edición in-situ + Sección 10 bNotify*
*v2.0 → v3.0: CF-5 (D5 patrón dominio) · CF-6 (idn_atributo canónico) · CF-7 (ctx_id prefijo)*
*v3.0 → v4.0: Sección 11 — cfg_policy_library transformada en catálogo normativo jerárquico.*
*             D99 Dominio Administrativo Global adoptado (447 nodos, no entra a BitMask).*
*             bauth.config.global_get especificado (bAuth como PAP+PIP NIST SP 800-207).*
*             25 tablas ath_config/policy_dN identificadas como candidatas a deprecación (HITL H14).*
