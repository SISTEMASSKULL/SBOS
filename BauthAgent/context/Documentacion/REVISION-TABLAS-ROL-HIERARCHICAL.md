# Revisión y Propuesta de Reparación — Clúster `idn_roles_rol_*`

**Fecha:** 2026-07-24  
**Estado:** BORRADOR DE REVISIÓN — aprobación pendiente antes de aplicar al DDL  
**Normas aplicadas:** SCIM RFC 7643 · NIST SP 800-53 Rev.5 · ISO 24760-2:2025 · INCITS 359-2012 R2022 · IGA best practices (SailPoint, Saviynt, Omada)

---

## 1. Propósito del clúster

El clúster `idn_roles_rol_*` es el **subsistema de identidad de roles** de bAuth. Sus tablas forman una unidad funcional cohesiva: definen qué roles existen, qué tipo de cuenta representan, qué nivel de seguridad requieren, cómo se heredan entre sí y a qué categoría de gobernanza pertenecen.

**`idn_roles_rol_hierarchical` (T-041) es la tabla maestra del clúster.** Registra los roles reales por tenant — el QUIÉN del sistema de identidad. Todas las demás tablas del clúster existen para alimentarla, clasificarla o materializar sus relaciones:

```
                    ┌─────────────────────────────────┐
T-040 rol_type ────►│                                 │
T-042 rol_tier ────►│  T-041  rol_hierarchical        │◄──── T-162 roles_template
T-191 rol_category ►│  (tabla maestra — per tenant)   │         (árbol de políticas)
                    └────────────────┬────────────────┘
                                     │ mantiene
                                     ▼
                            T-063 rol_closure
                        (DAG herencia OR materializado)
```

| Tabla | Rol en el clúster | Tipo |
|-------|-------------------|------|
| **T-041** `idn_roles_rol_hierarchical` | **Tabla maestra** — registra los 548 roles reales por tenant con jerarquía, tier, estado, versión y metadatos | Datos per-tenant |
| T-040 `idn_roles_rol_type` | Catálogo de tipos de cuenta — 10 tipos que clasifican todo rol (INDIVIDUAL, M2M, SYSTEM…) | Catálogo global |
| T-042 `idn_roles_rol_tier` | Catálogo de parámetros de seguridad por tier — LoA, MFA, sesiones, PAM | Catálogo global |
| T-063 `idn_roles_rol_closure` | Closure table DAG — materializa todas las rutas ancestro→descendiente para herencia OR en O(1) | Derivado per-tenant |
| T-191 `idn_roles_iga_category` | **NUEVA** — catálogo de categorías de gobernanza IGA — determina ciclo de revisión y controles PAM | Catálogo global |

---

## 2. Convención JSONB de traducción

**Regla del clúster:** Todo campo de texto visible para el usuario (nombre, descripción, justificación) se almacena como `JSONB` con las claves `"es"` y `"en"` como mínimo obligatorio.

```json
{ "es": "Texto en español", "en": "Text in English" }
```

Campos que **no** se traducen (no son texto visible): códigos técnicos, booleanos, enteros, timestamps, UUIDs, enums de sistema.

La siguiente tabla registra todos los campos del clúster que requieren corrección o que se proponen como JSONB:

| Tabla | Campo | Estado actual | Corrección |
|-------|-------|---------------|------------|
| T-040 | `name` | JSONB ✅ | Ya correcto |
| T-040 | `description` | TEXT ❌ | Cambiar a JSONB |
| T-042 | `display_name` | JSONB ✅ | Ya correcto |
| T-042 | `description` | TEXT ❌ | Cambiar a JSONB |
| T-041 | `name` | JSONB ✅ | Ya correcto |
| T-041 | `description` | TEXT ❌ | Cambiar a JSONB |
| T-041 | `business_justification` | (nuevo) | Proponer como JSONB |
| T-191 | `name` | (nuevo) | Proponer como JSONB |
| T-191 | `description` | (nuevo) | Proponer como JSONB |
| T-063 | — | Sin texto visible | Sin cambios |

---

## 3. Nuevos ENUMs requeridos

Dos tipos que no existen en el DDL actual y que necesitan declararse antes de las tablas:

```sql
-- [NIST RA-3 / ISO 27005 / IGA] Nivel de riesgo del rol
DO $$ BEGIN
    CREATE TYPE risk_level_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- [ISO 27001 A.5.12 / NIST AC-16 / NIST SP 800-60 Vol.1]
-- Clasificación de sensibilidad de la información que el rol puede acceder
DO $$ BEGIN
    CREATE TYPE sensitivity_label_enum AS ENUM ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED', 'SECRET');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

---

## 4. T-040 — `bauth.idn_roles_rol_type`

**Propósito:** Catálogo global controlado de tipos de cuenta. Clasifica todo rol del sistema en una de las 10 categorías canónicas. T-041 referencia esta tabla mediante `type_id`.

### 4.1 Columnas actuales

| Columna | Tipo actual | Estado |
|---------|-------------|--------|
| type_id | UUID PK DEFAULT uuidv7() | ✅ |
| code | TEXT UNIQUE NOT NULL | ✅ |
| name | JSONB NOT NULL | ✅ |
| description | TEXT | ⚠️ debe ser JSONB |
| is_active | BOOLEAN NOT NULL DEFAULT true | ✅ |
| sort_order | INTEGER NOT NULL DEFAULT 0 | ✅ |
| created_at | TIMESTAMPTZ NOT NULL DEFAULT now() | ✅ |

### 4.2 Corrección a aplicar en columnas existentes

| Campo | De | A |
|-------|----|---|
| `description` | `TEXT` | `JSONB` con `{"es":"...", "en":"..."}` |

### 4.3 Columnas nuevas propuestas

| Campo | Tipo | DEFAULT | Norma | Justificación |
|-------|------|---------|-------|---------------|
| `is_privileged` | BOOLEAN NOT NULL | false | NIST AC-2(7), CIS Controls 6.8 | M2M, SYSTEM, BOT, DEVICE, SERVICE y EMERGENCY son cuentas privilegiadas. Activa controles PAM y monitoreo reforzado en todo rol de ese tipo |
| `requires_human_owner` | BOOLEAN NOT NULL | false | NIST AC-2, NIST IR 8062, CIS 6.8 | Las cuentas no-humanas (M2M, BOT, DEVICE, SERVICE) deben tener un propietario humano responsable. Base del ciclo de gobernanza NHI |
| `default_certification_cycle_days` | INTEGER NOT NULL | 365 | NIST AC-2(j), IGA best practice | Ciclo base de revisión IGA por tipo de cuenta. Alimenta `next_review_at` en T-041 al crear un rol |

### 4.4 Seeds actualizados (nuevos campos)

| code | is_privileged | requires_human_owner | default_certification_cycle_days |
|------|:---:|:---:|:---:|
| INDIVIDUAL | false | false | 365 |
| M2M | true | true | 90 |
| SYSTEM | true | true | 90 |
| GROUP | false | false | 365 |
| TEMPLATE | false | false | 365 |
| VIRTUAL | false | false | 365 |
| BOT | true | true | 90 |
| DEVICE | true | true | 90 |
| SERVICE | true | true | 90 |
| EMERGENCY | true | false | 30 |

---

## 5. T-042 — `bauth.idn_roles_rol_tier`

**Propósito:** Catálogo global de parámetros de seguridad por tier. Define el LoA requerido, timeout de sesión, MFA y step-up para cada uno de los 11 tiers del sistema. T-041 referencia el tier directamente como enum. Esta tabla es el PIP del PDP al evaluar dominios D1 y D9.

### 5.1 Columnas actuales

| Columna | Tipo actual | Estado |
|---------|-------------|--------|
| tier_id | UUID PK | ✅ |
| tier | rol_tier_enum UNIQUE NOT NULL | ✅ |
| display_name | JSONB NOT NULL | ✅ |
| loa_required | INTEGER NOT NULL CHECK (1-3) | ✅ |
| session_timeout_minutes | INTEGER NOT NULL DEFAULT 480 | ✅ |
| max_sessions | INTEGER NOT NULL DEFAULT 3 | ✅ |
| step_up_loa | INTEGER CHECK (1-3) | ✅ RFC 9470 |
| mfa_required | BOOLEAN NOT NULL DEFAULT false | ✅ |
| mfa_methods_allowed | TEXT[] DEFAULT '{}' | ✅ |
| rate_limit_override | INTEGER | ✅ |
| nist_aal_reference | TEXT | ✅ |
| description | TEXT | ⚠️ debe ser JSONB |
| sort_order | INTEGER NOT NULL DEFAULT 0 | ✅ |
| created_at | TIMESTAMPTZ NOT NULL DEFAULT now() | ✅ |

La tabla cubre bien la capa de autenticación. **Le falta toda la capa de PAM y ciclo de vida IGA.**

### 5.2 Corrección a aplicar en columnas existentes

| Campo | De | A |
|-------|----|---|
| `description` | `TEXT` | `JSONB` con `{"es":"...", "en":"..."}` |

### 5.3 Columnas nuevas propuestas

| Campo | Tipo | DEFAULT | Norma | Justificación |
|-------|------|---------|-------|---------------|
| `is_privileged_tier` | BOOLEAN NOT NULL | false | NIST AC-2(7), PCI DSS 8.2.2 | SU, T0, T1 son tiers privilegiados. Activa PAM session recording y monitoreo reforzado para todos los roles de ese tier |
| `requires_pam` | BOOLEAN NOT NULL | false | NIST AC-17(3), PCI DSS 8.6.1 | SU y T0 deben pasar obligatoriamente por bóveda PAM. T1 según configuración del tenant |
| `certification_cycle_days` | INTEGER NOT NULL | 365 | NIST AC-2(j), PCI DSS 7.2.5.1 | Ciclo base de revisión IGA por tier. Combinado con `default_certification_cycle_days` de T-040 (el menor de los dos gana) |
| `inactivity_lockout_days` | INTEGER NOT NULL | 90 | NIST AC-2(3), ISO 27001 A.5.17 | Auto-bloqueo por inactividad. El Motor de Identidad evalúa en D1 y suspende el rol si supera el umbral |
| `requires_use_justification` | BOOLEAN NOT NULL | false | PCI DSS 8.6.3, IGA L3+ | SU, T0 y EMERGENCY requieren justificación de negocio en cada activación. Genera registro forense en auditoría |

### 5.4 Seeds actualizados (todos los campos nuevos)

| tier | is_privileged_tier | requires_pam | certification_cycle_days | inactivity_lockout_days | requires_use_justification |
|------|:---:|:---:|:---:|:---:|:---:|
| SU | true | true | 30 | 30 | true |
| T0 | true | true | 90 | 30 | true |
| T1 | true | false | 90 | 60 | false |
| BIZ_N1 | false | false | 180 | 90 | false |
| BIZ_N2 | false | false | 365 | 90 | false |
| BIZ_N3 | false | false | 365 | 90 | false |
| BIZ_N4 | false | false | 365 | 90 | false |
| BIZ_N5 | false | false | 365 | 90 | false |
| EXT_N0 | false | false | 180 | 30 | false |
| M2M | true | false | 90 | 30 | false |
| VISITANTE | false | false | 365 | 7 | false |

---

## 6. T-041 — `bauth.idn_roles_rol_hierarchical` (tabla maestra)

**Propósito:** Registro de identidad de roles por tenant. Es la tabla maestra del clúster — el QUIÉN del sistema. Cada fila es un rol concreto (Cajero, Gerente, SU, bot-facturación, etc.) con su jerarquía parent/child, tier, estado del ciclo de vida, versión y metadatos del bloque B1 del RolTemplate. Complementada por T-063 para consultas de herencia en O(1) y enlazada a T-162 (árbol de políticas) mediante `template_id`.

### 6.1 Columnas actuales

| Columna | Tipo actual | Estado |
|---------|-------------|--------|
| id | UUID PK DEFAULT uuidv7() | ✅ |
| tenant_id | UUID NOT NULL FK → idn_tenant | ✅ |
| parent_id | UUID FK → self (ON DELETE RESTRICT) | ✅ |
| type_id | UUID NOT NULL FK → T-040 | ✅ |
| tier | rol_tier_enum NOT NULL DEFAULT 'BIZ_N3' | ✅ |
| code | TEXT NOT NULL — UNIQUE (tenant_id, code) | ✅ |
| name | JSONB NOT NULL | ✅ |
| description | TEXT | ⚠️ debe ser JSONB |
| depth | INTEGER NOT NULL DEFAULT 0 | ✅ |
| is_inheritable | BOOLEAN NOT NULL DEFAULT true | ✅ |
| status | rol_status_enum NOT NULL DEFAULT 'ACTIVE' | ✅ |
| version | TEXT NOT NULL DEFAULT '1.0' | ✅ SCIM RFC 7643 §3.14 |
| sector_caeb | TEXT | ✅ código técnico, no traduce |
| ial_min | ial_level_enum DEFAULT 'IAL1' | ✅ |
| metadata_b1 | JSONB DEFAULT '{}' | ✅ {nist_rbac_level, caeb_code, description_long} |
| template_id | UUID (FK deferred → T-162) | ✅ |
| created_at | TIMESTAMPTZ NOT NULL | ✅ |
| updated_at | TIMESTAMPTZ NOT NULL | ✅ |

### 6.2 Corrección a aplicar en columnas existentes

| Campo | De | A | Nota adicional |
|-------|----|---|----------------|
| `description` | `TEXT` | `JSONB {"es":"...", "en":"..."}` | Campo visible en UI y APIs |
| `metadata_b1` | `JSONB {nist_rbac_level, caeb_code, description_long}` | `JSONB {nist_rbac_level, caeb_code}` | `description_long` queda redundante con `description JSONB` |

### 6.3 Columnas nuevas propuestas

| # | Campo | Tipo | DEFAULT | Norma | Justificación |
|---|-------|------|---------|-------|---------------|
| G1 | `role_owner_id` | UUID — FK → idn_identity_entity(id) ON DELETE SET NULL | NULL | NIST AC-2(7), IGA certification | Propietario del rol — entidad responsable de certificar quién lo porta. Sin propietario no hay campaña IGA posible |
| G2 | `risk_classification` | risk_level_enum NOT NULL | 'MEDIUM' | NIST RA-3, ISO 27005, IGA | LOW / MEDIUM / HIGH / CRITICAL. Determina frecuencia de revisión IGA y umbrales de alerta PAM |
| G3 | `business_justification` | **JSONB** | NULL | IGA maturity L3+, SailPoint/Saviynt | `{"es":"...", "en":"..."}`. Obligatoria para roles de categoría PRIVILEGED y EMERGENCY. Previene role sprawl |
| G4 | `category_id` | UUID — FK → T-191 rol_category(category_id) | NULL | NIST AC-6, IGA governance | Categoría de gobernanza. Determina ciclo de revisión real (combinado con T-040 y T-042) |
| G5 | `description` | **JSONB** | NULL | SCIM RFC 7643 §4.2 | ✅ ya existe como TEXT — se corrige a JSONB (ver §6.2) |
| G6 | `sensitivity_label` | sensitivity_label_enum NOT NULL | 'INTERNAL' | ISO 27001 A.5.12, NIST AC-16 | PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED / SECRET. Clasifica la información que este rol puede acceder |
| G7 | `version` | TEXT NOT NULL | '1.0' | SCIM RFC 7643 §3.14 | ✅ ya existe |
| G8 | `max_simultaneous_holders` | INTEGER CHECK (> 0) | NULL | NIST AC-5, PCI DSS 4.0.1 §7.2 | Máximo de titulares simultáneos del rol. NULL = ilimitado. Enforcement automático de SoD |
| + | `last_reviewed_at` | TIMESTAMPTZ | NULL | NIST AC-2(j), PCI DSS 7.2.5.1 | Fecha de la última revisión IGA completada. Actualizada por el Motor de Certificación |
| + | `next_review_at` | TIMESTAMPTZ | NULL | NIST AC-2(j), ISO 27001 A.5.18 | Próxima revisión programada. Calculada automáticamente al crear o revisar el rol usando el ciclo de T-191 |
| + | `approval_required` | BOOLEAN NOT NULL | false | PCI DSS 7.1, IGA L3+ | El rol requiere flujo de aprobación formal antes de poder asignarse a un usuario |

### 6.4 Índices nuevos

```sql
-- Búsqueda de roles por propietario (campañas de certificación IGA)
CREATE INDEX IF NOT EXISTS idx_irrh_owner
    ON bauth.idn_roles_rol_hierarchical(role_owner_id)
    WHERE role_owner_id IS NOT NULL;

-- Filtrado por riesgo dentro del tenant (IGA prioritization)
CREATE INDEX IF NOT EXISTS idx_irrh_risk
    ON bauth.idn_roles_rol_hierarchical(tenant_id, risk_classification);

-- Filtrado por categoría de gobernanza
CREATE INDEX IF NOT EXISTS idx_irrh_category
    ON bauth.idn_roles_rol_hierarchical(category_id);

-- Agenda de revisiones IGA (todos los roles con revisión pendiente)
CREATE INDEX IF NOT EXISTS idx_irrh_review
    ON bauth.idn_roles_rol_hierarchical(next_review_at)
    WHERE next_review_at IS NOT NULL;

-- Filtrado por etiqueta de sensibilidad dentro del tenant
CREATE INDEX IF NOT EXISTS idx_irrh_label
    ON bauth.idn_roles_rol_hierarchical(tenant_id, sensitivity_label);
```

---

## 7. T-063 — `bauth.idn_roles_rol_closure`

**Propósito:** Closure table del DAG de herencia OR de roles. Materializa todas las rutas ancestro→descendiente del árbol T-041. Permite al motor BitMask calcular la máscara acumulada de privilegios heredados sin traversal recursivo (O(1) con JOIN). Mantenida automáticamente por triggers en T-041 en cada INSERT/UPDATE de `parent_id`.

### 7.1 Columnas actuales

| Columna | Tipo actual | Estado |
|---------|-------------|--------|
| ancestor_id | UUID NOT NULL FK → T-041 ON DELETE CASCADE | ✅ |
| descendant_id | UUID NOT NULL FK → T-041 ON DELETE CASCADE | ✅ |
| depth | INTEGER NOT NULL CHECK (>= 0) | ✅ |
| PRIMARY KEY | (ancestor_id, descendant_id) | ✅ |

Estructuralmente correcta como closure table. Un solo gap operacional:

### 7.2 Columna nueva propuesta

| Campo | Tipo | DEFAULT | Norma | Justificación |
|-------|------|---------|-------|---------------|
| `is_active` | BOOLEAN NOT NULL | true | NIST AC-2(3), operacional | Cuando un rol pasa a `SUSPENDED` en T-041, sus paths de herencia no deben eliminarse (son históricos y necesarios para auditoría) sino desactivarse lógicamente. Sin este campo, suspender un rol obliga a borrar filas de closure (destructivo) o a ignorar el status en la capa de aplicación (frágil y propenso a errores). Un trigger en T-041 propaga `is_active=false` a todas las filas de T-063 donde `ancestor_id` o `descendant_id` es el rol suspendido |

> **Nota sobre `inherited_mask`:** El campo `inherited_mask BIGINT` (máscara BitMask pre-calculada por path) sería una optimización de rendimiento válida, pero la cache de máscaras ya vive en Redis (RolBitMask). Incorporarlo en T-063 añadiría complejidad de mantenimiento sin beneficio neto. Se descarta como gap — es una decisión de arquitectura separada.

---

## 8. T-191 — `bauth.idn_roles_iga_category` (NUEVA)

**Propósito:** Catálogo global de categorías de gobernanza para roles. Define el ciclo de revisión IGA por categoría y si la categoría implica controles privilegiados (PAM, certificación acelerada). T-041 referencia esta tabla mediante `category_id`. Es la tabla que permite al Motor de Certificación calcular `next_review_at` de forma automática y coherente.

### 8.1 Por qué tabla y no ENUM

La categoría necesita almacenar `review_cycle_days` — un dato operativo numérico que el Motor de Identidad usa para calcular `next_review_at` en cada rol. Un ENUM no puede almacenar datos asociados. Una tabla catálogo es extensible sin `ALTER TYPE` en producción.

### 8.2 Diseño propuesto

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_roles_iga_category (
    category_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    code               TEXT        UNIQUE NOT NULL,
    name               JSONB       NOT NULL,          -- {"es":"...", "en":"..."}
    description        JSONB,                         -- {"es":"...", "en":"..."}
    is_privileged      BOOLEAN     NOT NULL DEFAULT false,
    review_cycle_days  INTEGER     NOT NULL DEFAULT 365
                       CHECK (review_cycle_days > 0),
    sort_order         INTEGER     NOT NULL DEFAULT 0,
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 8.3 Seeds

| code | name (es / en) | is_privileged | review_cycle_days |
|------|----------------|:---:|:---:|
| BUSINESS | Negocio / Business | false | 365 |
| IT_INFRASTRUCTURE | Infraestructura TI / IT Infrastructure | true | 90 |
| APPLICATION | Aplicación / Application | false | 365 |
| PRIVILEGED | Privilegiado / Privileged | true | 90 |
| EMERGENCY | Emergencia / Emergency | true | 30 |
| SERVICE | Servicio / Service | true | 90 |
| STANDARD | Estándar / Standard | false | 365 |

---

## 9. Resumen consolidado de cambios

### 9.1 Correcciones (campos existentes)

| Tabla | Campo | Cambio |
|-------|-------|--------|
| T-040 | `description` | TEXT → JSONB |
| T-042 | `description` | TEXT → JSONB |
| T-041 | `description` | TEXT → JSONB |
| T-041 | `metadata_b1` | Eliminar `description_long` del JSONB (queda redundante) |

### 9.2 Columnas nuevas

| Tabla | Campo nuevo | Total |
|-------|-------------|:-----:|
| T-040 | `is_privileged`, `requires_human_owner`, `default_certification_cycle_days` | 3 |
| T-042 | `is_privileged_tier`, `requires_pam`, `certification_cycle_days`, `inactivity_lockout_days`, `requires_use_justification` | 5 |
| T-041 | `role_owner_id`, `category_id`, `risk_classification`, `sensitivity_label`, `business_justification`, `max_simultaneous_holders`, `last_reviewed_at`, `next_review_at`, `approval_required` | 9 |
| T-063 | `is_active` | 1 |
| **Total** | | **18** |

### 9.3 Nuevos objetos de BD

| Objeto | Tipo | Código |
|--------|------|--------|
| `risk_level_enum` | ENUM | — |
| `sensitivity_label_enum` | ENUM | — |
| `bauth.idn_roles_iga_category` | Tabla catálogo | T-191 |
| 5 índices en T-041 | INDEX | — |

### 9.4 Seeds que requieren actualización

| Tabla | Campos afectados en seeds |
|-------|--------------------------|
| T-040 | `description` (JSONB), `is_privileged`, `requires_human_owner`, `default_certification_cycle_days` |
| T-042 | `description` (JSONB), `is_privileged_tier`, `requires_pam`, `certification_cycle_days`, `inactivity_lockout_days`, `requires_use_justification` |

---

*Una vez aprobado este documento, los cambios se aplican en `DDLs/SBOS_db_V2_DDL.sql` y T-191 se registra en `A.65.02_ANEXO-NUEVA-DDL-v1.0.md`.*
