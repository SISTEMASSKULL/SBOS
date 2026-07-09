# BAUTH-IDN-ROLE-TEMPLATE-DELTA-DDL
## Registro de Cambios Acumulados — idn_role_template · v1.0 · 2026-07-09 · SKULL

> **Propósito:** documento de control que registra TODOS los cambios aplicados en la
> VPS (PostgreSQL 18.4) sobre `bauth.idn_role_template` e `idn_role_closure` que
> **aún no están reflejados en la DDL** (`sbos_00__esquema_base.sql`).
>
> **Regla de uso:** este documento es la fuente de verdad de la deuda técnica DDL.
> Cuando se decida corregir la DDL completa, se aplican TODOS los deltas de este
> documento de una sola vez y se archiva.
>
> **No tocar la DDL** hasta que se resuelvan los gaps del template de rol y se
> decida hacer el corte definitivo.

---

## 1. Estado actual en VPS (fuente de verdad)

### 1.1 `bauth.idn_role_template` — columnas reales en DB

```
role_name          TEXT        NOT NULL UNIQUE           ← "segunda llave" natural
type_id            TEXT        NULL
tier               TEXT        NOT NULL
hierarchy_level    INTEGER     NOT NULL DEFAULT 5
path_ids           TEXT[]      DEFAULT '{}'
status             TEXT        NOT NULL DEFAULT 'DEFINIDO'
loa_required       INTEGER     NOT NULL DEFAULT 1
mfa_required       BOOLEAN     NOT NULL DEFAULT false
step_up_enabled    BOOLEAN     NOT NULL DEFAULT false
sod_group          TEXT        NULL
max_sessions       INTEGER     DEFAULT 1
session_timeout    INTEGER     DEFAULT 28800
audit_level        TEXT        NOT NULL DEFAULT 'basic'
start_time         TIMESTAMPTZ NOT NULL DEFAULT now()
expiry_time        TIMESTAMPTZ NULL
template_id        TEXT        NULL                      ← pendiente renombrar + poblar
created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
created_by         TEXT        NOT NULL
template           JSONB       NOT NULL                  ← JSONB 14 bloques RolTemplate v6.0
template_version   TEXT        NOT NULL DEFAULT '6.0'
scope              TEXT        NULL
risk_level         TEXT        NOT NULL DEFAULT 'BAJO'
review_period_days INTEGER     NOT NULL DEFAULT 90
role_type          TEXT        NOT NULL DEFAULT 'OPERATIVO'
applies_to_size    TEXT        NOT NULL DEFAULT 'TODAS'
is_collaborative   BOOLEAN     NOT NULL DEFAULT false
role_template_name JSONB       NOT NULL DEFAULT '{}'     ← JSONB bilingüe {es, en}
id                 UUID        NOT NULL DEFAULT uuidv7() ← PRIMARY KEY (antes TEXT)
parent_id          UUID        NULL                      ← FK → id (antes TEXT → role_name)
```

### 1.2 `bauth.idn_role_closure` — columnas reales en DB

```
closure_id      UUID        NOT NULL DEFAULT gen_random_uuid()  PRIMARY KEY
ancestro_id     UUID        NOT NULL REFERENCES idn_role_template(id) ON DELETE CASCADE
descendiente_id UUID        NOT NULL REFERENCES idn_role_template(id) ON DELETE CASCADE
profundidad     INTEGER     NOT NULL
ctx_id          TEXT        NOT NULL
created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
UNIQUE (ancestro_id, descendiente_id)
```

### 1.3 Datos actuales en VPS

| Indicador | Valor |
|-----------|-------|
| Total roles | **548** |
| Roles con parent_id | **175** |
| Roles raíz (sin parent) | **6** (GERENTE-GENERAL, DIRECTOR-COLEGIO, GERENTE-BANCO, GERENTE-HOTEL, ADMIN-ESTANCIA, EXT-EMPLEADOR-DOMESTICO) |
| Aristas closure directas | **164** (22 sectores CAEB) |
| Aristas transitivas | **255** |
| Total closure | **419** |
| Profundidad máxima DAG | **5 niveles** |
| Campos traducidos al inglés | **todos** (548 × {name, description, scope, type_id, role_name, role_type, classification}) |

---

## 2. Delta DDL — qué difiere entre DDL y DB

### 2.1 Columnas que el DDL tiene pero la DB ya NO tiene (eliminadas)

| Columna DDL | Razón de eliminación |
|-------------|----------------------|
| `tenant_id TEXT NOT NULL DEFAULT '*'` | Movida a `template` JSONB (campo de configuración, no clave) |
| `empresa_id TEXT NOT NULL DEFAULT '*'` | Ídem — era redundante con tenant_id |
| `version TEXT NOT NULL DEFAULT '1.0.0'` | Movida a `template.v` |
| `sync_status TEXT NOT NULL DEFAULT 'PENDING'` | Movida a `template.sync_status` |
| `sync_error TEXT` | Movida a `template.sync_error` |
| `last_sync_at TIMESTAMPTZ` | Movida a `template.last_sync_at` |
| `rol_bitmask_base64 TEXT NOT NULL DEFAULT ''` | Movida a `template.rol_bitmask_base64` |
| `sam128_physical NUMERIC(20)` | Movida a `template.sam128_physical` |
| `sam128_logical NUMERIC(20)` | Movida a `template.sam128_logical` |
| `sam128_financial NUMERIC(20)` | Movida a `template.sam128_financial` |
| `sam128_governance NUMERIC(20)` | Movida a `template.sam128_governance` |
| `issuer TEXT NOT NULL` | Movida a `template.issuer` |
| `owner_tenant TEXT NOT NULL DEFAULT '*'` | Movida a `template.issuer` / redundante |

**Decisión de diseño:** estos campos son datos de sincronización y runtime, no
atributos identitarios del rol. El JSONB `template` los agrupa como metadatos
operacionales. Se eliminan de la fila plana para reducir la anchura de la tabla.

### 2.2 Columnas que la DB tiene pero el DDL NO tiene (agregadas)

| Columna DB | Tipo | Descripción |
|------------|------|-------------|
| `role_name` | `TEXT NOT NULL UNIQUE` | Segunda llave natural (antes era el `id`). Identificador legible estable. |
| `role_template_name` | `JSONB NOT NULL DEFAULT '{}'` | Nombres y descripciones bilingües `{es:{name,desc}, en:{name,desc}, scope:{es,en}, type_id:{es,en}, role_name:{es,en}, role_type:{es,en}, classification:{es,en}}` |
| `scope` | `TEXT NULL` | Sector o ámbito de aplicación del rol (texto libre, sin traducción directa — ya incluido en `role_template_name.scope`) |
| `risk_level` | `TEXT NOT NULL DEFAULT 'BAJO'` | Nivel de riesgo: BAJO / MEDIO / ALTO / CRITICO |
| `review_period_days` | `INTEGER NOT NULL DEFAULT 90` | Cada cuántos días revisar el privilegio (ISO 27001 A.5.18) |
| `role_type` | `TEXT NOT NULL DEFAULT 'OPERATIVO'` | Tipo funcional del rol (SISTEMA, EJECUTIVO, DIRECTIVO, GERENCIAL, TECNICO_PROFESIONAL, OPERATIVO, ASESOR, CONSULTOR, EXTERNO, FAMILIAR, HOGAR, FISICO, MAQUINA, VISITANTE) |
| `applies_to_size` | `TEXT NOT NULL DEFAULT 'TODAS'` | Tamaño de empresa aplicable (TODAS, MULTINACIONAL, GRANDE, MEDIANA, PEQUENA, MICRO) |
| `is_collaborative` | `BOOLEAN NOT NULL DEFAULT false` | True si el rol requiere coordinación con otro rol (ej. aprobación dual) |

### 2.3 Cambios de tipo en columnas existentes

| Columna | DDL actual | DB real | Impacto |
|---------|-----------|---------|---------|
| `id` | `TEXT PRIMARY KEY` | `UUID NOT NULL DEFAULT uuidv7()` | PK cambió de TEXT a UUID v7. Todas las FK que apuntaban a `id` como TEXT deben actualizarse. |
| `parent_id` | `TEXT REFERENCES idn_role_template(id)` | `UUID REFERENCES idn_role_template(id)` | FK ahora apunta al UUID PK, no al TEXT |

### 2.4 Cambios en `idn_role_closure`

| Aspecto | DDL actual | DB real |
|---------|-----------|---------|
| `ancestro_id` | `TEXT NOT NULL REFERENCES idn_role_template(id)` | `UUID NOT NULL REFERENCES idn_role_template(id)` |
| `descendiente_id` | `TEXT NOT NULL REFERENCES idn_role_template(id)` | `UUID NOT NULL REFERENCES idn_role_template(id)` |
| UNIQUE | no definido en DDL | `UNIQUE (ancestro_id, descendiente_id)` — requerido para ON CONFLICT |

### 2.5 Constraints nuevos que el DDL debe incluir

```sql
-- Constraints de check en nuevas columnas
CONSTRAINT chk_brt_risk_level   CHECK (risk_level IN ('BAJO','MEDIO','ALTO','CRITICO')),
CONSTRAINT chk_brt_role_type    CHECK (role_type IN ('SISTEMA','EJECUTIVO','DIRECTIVO','GERENCIAL',
    'TECNICO_PROFESIONAL','OPERATIVO','ASESOR','CONSULTOR','EXTERNO','FAMILIAR','HOGAR','FISICO',
    'MAQUINA','VISITANTE')),
CONSTRAINT chk_brt_applies_size CHECK (applies_to_size IN ('TODAS','MULTINACIONAL','GRANDE',
    'MEDIANA','PEQUENA','MICRO')),

-- Unique en role_name (segunda llave)
CONSTRAINT uq_idn_role_template_role_name UNIQUE (role_name),

-- Unique en closure (para ON CONFLICT)
CONSTRAINT uq_idn_role_closure_pair UNIQUE (ancestro_id, descendiente_id)
```

### 2.6 Índices nuevos que el DDL debe incluir

```sql
-- En idn_role_template
CREATE INDEX IF NOT EXISTS idx_brt_role_name    ON bauth.idn_role_template(role_name);
CREATE INDEX IF NOT EXISTS idx_brt_risk_level   ON bauth.idn_role_template(risk_level);
CREATE INDEX IF NOT EXISTS idx_brt_role_type    ON bauth.idn_role_template(role_type);
CREATE INDEX IF NOT EXISTS idx_brt_tier_status  ON bauth.idn_role_template(tier, status);

-- En idn_role_closure
CREATE INDEX IF NOT EXISTS idx_irc_anc_desc     ON bauth.idn_role_closure(ancestro_id, descendiente_id);
```

### 2.7 FK externas afectadas por el cambio de `id TEXT → UUID`

Estas tablas referencian `idn_role_template(id)` y deben migrar su columna FK de TEXT a UUID:

| Tabla | Columna FK | Acción DDL pendiente |
|-------|-----------|----------------------|
| `bauth.idn_role_closure` | `ancestro_id`, `descendiente_id` | ✅ Ya migrada en VPS |
| `bauth.idn_user_role` | `role_id TEXT` | ⏳ Pendiente migrar a UUID |
| `bauth.dlg_delegation` | `rol_id TEXT` | ⏳ Pendiente migrar a UUID |
| (otras que referencien id) | — | ⏳ Verificar al hacer corte |

---

## 3. Pendiente: Gap del campo `template_id` (→ `rol_template_id`)

El campo `template_id` en la DB está actualmente poblado con `'bauth-bootstrap'` en
todos los roles. Debe:

1. **Renombrarse** a `rol_template_id` (convenio de nombres del proyecto)
2. **Poblarse** con el identificador del RolTemplate v6.0 al que pertenece cada rol,
   según `SBOS-ROLTEMPLATE-v6_0.md` y `Authentication_Framework_v3.json`

Esto es el "gap del template de rol" que se resuelve en la siguiente fase. Los 548
roles ya tienen toda la información necesaria (JSONB bilingüe, jerarquía, sector)
para asignar correctamente el template.

### 3.1 Templates v6.0 que deben asignarse

Cada rol del catálogo pertenece a uno (o varios) de los 14 bloques del RolTemplate:

| Bloque | Descripción |
|--------|-------------|
| T01 | Identidad y Autenticación |
| T02 | Autorización y Permisos |
| T03 | Sincronización KC + Tryton |
| T04 | Auditoría y Trazabilidad |
| T05 | Seguridad y Criptografía |
| T06 | Integración y APIs |
| T07 | Ciclo de Vida de Credenciales |
| T08 | Contexto y Sesión |
| T09 | Notificaciones |
| T10 | Firma Digital |
| T11 | Facturación Electrónica |
| T12 | Hardware y Biometría |
| T13 | Blockchain |
| T14 | Multi-tenant |

---

## 4. Resumen: DDL corregida (qué debe quedar)

Cuando se haga el corte definitivo, el DDL de `idn_role_template` debe:

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_role_template (
    -- Claves
    id              UUID        NOT NULL DEFAULT uuidv7(),      -- PK UUID v7
    role_name       TEXT        NOT NULL,                       -- segunda llave natural

    -- Clasificación
    type_id         TEXT,
    tier            TEXT        NOT NULL,
    hierarchy_level INTEGER     NOT NULL DEFAULT 5,
    path_ids        TEXT[]      DEFAULT '{}',
    role_type       TEXT        NOT NULL DEFAULT 'OPERATIVO',
    applies_to_size TEXT        NOT NULL DEFAULT 'TODAS',
    is_collaborative BOOLEAN    NOT NULL DEFAULT false,
    risk_level      TEXT        NOT NULL DEFAULT 'BAJO',
    review_period_days INTEGER  NOT NULL DEFAULT 90,

    -- Jerarquía DAG
    parent_id       UUID        REFERENCES bauth.idn_role_template(id) ON DELETE SET NULL,

    -- Ciclo de vida
    status          TEXT        NOT NULL DEFAULT 'DEFINIDO',
    start_time      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expiry_time     TIMESTAMPTZ,

    -- Seguridad
    loa_required    INTEGER     NOT NULL DEFAULT 1,
    mfa_required    BOOLEAN     NOT NULL DEFAULT false,
    step_up_enabled BOOLEAN     NOT NULL DEFAULT false,
    sod_group       TEXT,
    max_sessions    INTEGER     DEFAULT 1,
    session_timeout INTEGER     DEFAULT 28800,
    audit_level     TEXT        NOT NULL DEFAULT 'basic',

    -- Nombres bilingües
    scope               TEXT,
    role_template_name  JSONB   NOT NULL DEFAULT '{}',

    -- Template RolTemplate v6.0 (14 bloques JSONB)
    rol_template_id TEXT,
    template        JSONB       NOT NULL,
    template_version TEXT       NOT NULL DEFAULT '6.0',

    -- Metadata
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT        NOT NULL,

    -- Constraints
    CONSTRAINT idn_role_template_pkey          PRIMARY KEY (id),
    CONSTRAINT uq_idn_role_template_role_name  UNIQUE (role_name),
    CONSTRAINT chk_brt_status   CHECK (status IN ('DEFINIDO','DESARROLLADO','REVISADO','AUTORIZADO','PUBLICADO','DEPRECADO','RETIRADO')),
    CONSTRAINT chk_brt_tier     CHECK (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3','BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE')),
    CONSTRAINT chk_brt_loa      CHECK (loa_required BETWEEN 1 AND 4),
    CONSTRAINT chk_brt_audit    CHECK (audit_level IN ('none','basic','full')),
    CONSTRAINT chk_brt_risk     CHECK (risk_level IN ('BAJO','MEDIO','ALTO','CRITICO')),
    CONSTRAINT chk_brt_roltype  CHECK (role_type IN ('SISTEMA','EJECUTIVO','DIRECTIVO','GERENCIAL','TECNICO_PROFESIONAL','OPERATIVO','ASESOR','CONSULTOR','EXTERNO','FAMILIAR','HOGAR','FISICO','MAQUINA','VISITANTE')),
    CONSTRAINT chk_brt_appsize  CHECK (applies_to_size IN ('TODAS','MULTINACIONAL','GRANDE','MEDIANA','PEQUENA','MICRO'))
);
```

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_role_closure (
    closure_id      UUID        NOT NULL DEFAULT uuidv7(),
    ancestro_id     UUID        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    descendiente_id UUID        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    profundidad     INTEGER     NOT NULL,
    ctx_id          TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT idn_role_closure_pkey    PRIMARY KEY (closure_id),
    CONSTRAINT uq_irc_pair              UNIQUE (ancestro_id, descendiente_id),
    CONSTRAINT chk_irc_no_self_ref      CHECK (ancestro_id <> descendiente_id),
    CONSTRAINT chk_irc_profundidad      CHECK (profundidad >= 1)
);
```

---

## 5. Orden de ejecución del corte DDL (cuando se decida)

```
1. ALTER TABLE idn_role_template — drop columnas eliminadas (tenant_id, empresa_id, etc.)
2. ALTER TABLE idn_role_template — change id TEXT → UUID
3. ALTER TABLE idn_role_template — change parent_id TEXT → UUID
4. ALTER TABLE idn_role_template — add role_name, role_template_name, risk_level,
   review_period_days, role_type, applies_to_size, is_collaborative
5. ALTER TABLE idn_role_template — rename template_id → rol_template_id
6. ALTER TABLE idn_role_closure — change ancestro_id / descendiente_id TEXT → UUID
7. ALTER TABLE idn_role_closure — add UNIQUE (ancestro_id, descendiente_id)
8. ALTER TABLE idn_user_role — change role_id TEXT → UUID (si existe)
9. ALTER TABLE dlg_delegation — change rol_id TEXT → UUID (si existe)
10. Correr seeds bauth_48 + bauth_62 para repoblar
11. Archivar este documento en _procesados/
```

---

## 6. Seeds actualizados (commit 8cd3462 — 2026-07-09)

| Archivo | Estado | Descripción |
|---------|--------|-------------|
| `DDLs/seeds/bauth_48__idn_role_template.sql` | ✅ Actualizado | 548 roles, ON CONFLICT por role_name, wiring parent_id, 750 KB |
| `DDLs/seeds/bauth_62__idn_role_closure.sql` | ✅ Actualizado | 164 aristas + cierre transitivo WITH RECURSIVE, DELETE + rebuild |
| `DDLs/seeds/bauth_49__idn_role_template_data.sql` | ⏳ Pendiente | Actualizar con nuevas columnas (role_type, risk_level, etc.) |
