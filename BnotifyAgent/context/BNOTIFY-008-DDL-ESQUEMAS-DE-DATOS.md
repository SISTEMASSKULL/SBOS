---
codigo: BNOTIFY-008
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000, BNOTIFY-002]
doctrina_que_ejerce: [D14, D18]
criterio_implementado: >
  La migración 0001_bnotify_core.sql se aplica sin errores con sqlx migrate run.
  Los cuatro schemas (bauth, bnotify, bchat, correo) existen en la base SBOS_db.
  El usuario bnotify_rw puede INSERT en bnotify.notification_event y SELECT en
  bnotify.v_bauth_user_channel. El usuario bauth_rw NO puede INSERT en bnotify.*
  (prueba de aislamiento). Todo lo anterior verificado con verificar_afirmacion.sh.
---

# BNOTIFY-008 — DDL Esquemas de Datos
## Contrato de datos del clúster PostgreSQL compartido (D18)

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.7c, §4.3, ADR-006 · BNOTIFY-002 (claims bAuth) · BNOTIFY-004 (taxonomía eventos)

**D18 — La regla absoluta de este documento:**
> Un clúster PostgreSQL, esquemas separados por dueño.
> **Solo el dueño escribe en su esquema.** Lectura cruzada: solo por vistas con GRANTs exactos.
> No existen tablas sin dueño. No existen GRANTs amplios. No existen JOINs directos entre schemas sin vista.

---

## 1. Arquitectura del clúster

```
Base de datos: SBOS_db
Clúster: PostgreSQL 17.x (K8s StatefulSet — servidor S02-dataserver)

Schemas:
  bauth     ← dueño: bauth_rw          (identidades, roles, auditoría)
  bnotify   ← dueño: bnotify_rw        (notificaciones, perfiles, plantillas)
  bchat     ← dueño: bchat_rw          (salas, mensajes — creado en G2)
  correo    ← dueño: correo_rw         (buzones — creado en G4)
  shared    ← dueño: sbos_admin        (tipos comunes, enums — solo lectura)
```

Roles PostgreSQL:
- `bauth_rw` — DML solo en schema `bauth`
- `bnotify_rw` — DML solo en schema `bnotify`
- `bchat_rw` — DML solo en schema `bchat`
- `bauth_ro` — SELECT en vistas publicadas de `bauth`
- `bnotify_ro` — SELECT en vistas publicadas de `bnotify`
- `sbos_admin` — superuser restringido a migraciones, sin acceso desde aplicaciones

---

## 2. Convenciones canónicas

### 2.1 Identificadores

| Campo | Tipo | Convención |
|-------|------|-----------|
| PK de toda tabla | `UUID` | `gen_random_uuid()` como default — nunca SERIAL |
| FK hacia usuario bAuth | `UUID` → alias `bauth_user_id` | El UUID que bAuth emite en el claim `sub` del JWT |
| `ctx_id` | `UUID NOT NULL` | SBOS-049 — toda fila tiene ctx_id de la operación que la creó |
| `tenant_id` | `TEXT NOT NULL` | Slug del tenant (ej: `empresa-abc`) |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | Zona UTC siempre |
| `updated_at` | `TIMESTAMPTZ` | NULL si la tabla no admite updates (tablas WORM) |

### 2.2 Nomenclatura

- Tablas: `snake_case`, singular (`notification_event`, no `notification_events`)
- Índices: `idx_{tabla}_{campo(s)}` (ej: `idx_notification_event_ctx_id`)
- Vistas cruzadas: prefijo `v_` + schema fuente + sufijo descripción (ej: `bnotify.v_bauth_user_channel`)
- Migraciones: `{NNNN}_{descripcion_corta}.sql` — correlativo estricto, sin gaps

### 2.3 Particionado

Las tablas de alto volumen usan `PARTITION BY RANGE (created_at)` con particiones mensuales.
El nombre de la partición: `{tabla}_y{YYYY}m{MM}` (ej: `notification_event_y2026m07`).
Las particiones se crean automáticamente mediante el job `partition_maintenance`.

---

## 3. Schema `bnotify` — tablas propias

### 3.1 `bnotify.notification_event`

Registro de cada intent despachado. Es la fuente de verdad del estado de entrega.
Tabla append-only (sin UPDATE salvo el campo `status` y `delivered_at`).

```sql
CREATE TABLE bnotify.notification_event (
    -- Identificadores
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    intent_id       UUID        NOT NULL,          -- ID del emisor (idempotencia)
    delivery_id     UUID        NOT NULL UNIQUE,   -- ID interno de seguimiento
    ctx_id          UUID        NOT NULL,          -- SBOS-049

    -- Origen
    tenant_id       TEXT        NOT NULL,
    emitter         TEXT        NOT NULL,          -- Ej: "bauth", "bpay"
    event_type      TEXT        NOT NULL,          -- Taxonomía BNOTIFY-004

    -- Destino resuelto
    recipient_user_id   UUID    NULL,              -- UUID bAuth (NULL si no resuelto)
    destination_type    TEXT    NOT NULL,          -- 'user', 'role', 'audience', 'room'
    destination_id      TEXT    NOT NULL,          -- ID del destino original

    -- Estado
    status          TEXT        NOT NULL DEFAULT 'PENDING',  -- PENDING|IN_FLIGHT|DELIVERED|FAILED_RETRYING|FAILED_PERMANENT
    priority        TEXT        NOT NULL,          -- 'A', 'B', 'C'
    channel_used    TEXT        NULL,              -- Canal que completó la entrega
    attempt_count   SMALLINT    NOT NULL DEFAULT 0,
    last_error      TEXT        NULL,

    -- Tiempos
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at    TIMESTAMPTZ NULL,
    expires_at      TIMESTAMPTZ NULL,              -- NULL = sin expiración (clase A)

    -- Auditoría
    audit_class     CHAR(1)     NOT NULL           -- 'A', 'B', 'C' (de aud_compliance_map)
) PARTITION BY RANGE (created_at);

-- Índices en la tabla padre (heredados por particiones)
CREATE INDEX idx_notification_event_ctx_id
    ON bnotify.notification_event (ctx_id);
CREATE INDEX idx_notification_event_recipient
    ON bnotify.notification_event (recipient_user_id, tenant_id)
    WHERE recipient_user_id IS NOT NULL;
CREATE INDEX idx_notification_event_intent_id
    ON bnotify.notification_event (intent_id);
CREATE INDEX idx_notification_event_status
    ON bnotify.notification_event (status, priority)
    WHERE status IN ('PENDING', 'FAILED_RETRYING');

-- Partición inicial
CREATE TABLE bnotify.notification_event_y2026m07
    PARTITION OF bnotify.notification_event
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
```

### 3.2 `bnotify.notification_profile`

Preferencias de notificación por usuario. Es legítimamente de bNotify — es
configuración del plano de notificaciones, no identidad (bAuth no la gestiona).

```sql
CREATE TABLE bnotify.notification_profile (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    bauth_user_id   UUID        NOT NULL UNIQUE,   -- FK lógica hacia bauth.identity
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    -- Preferencias
    preferred_channels  TEXT[]  NOT NULL DEFAULT '{}',  -- Orden de preferencia
    quiet_hours_start   TIME    NULL,              -- Inicio de modo silencioso (UTC)
    quiet_hours_end     TIME    NULL,
    timezone            TEXT    NOT NULL DEFAULT 'UTC',
    locale              TEXT    NOT NULL DEFAULT 'es',

    -- Opt-out por tipo de evento (solo clases B y C — clase A no se puede suprimir)
    opted_out_event_types   TEXT[]  NOT NULL DEFAULT '{}',

    -- Topes de frecuencia
    max_per_hour    SMALLINT    NOT NULL DEFAULT 20,
    max_per_day     SMALLINT    NOT NULL DEFAULT 100,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_profile_bauth_user
    ON bnotify.notification_profile (bauth_user_id);
```

### 3.3 `bnotify.template`

Plantillas de mensajes por tipo de evento, canal e idioma.

```sql
CREATE TABLE bnotify.template (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    event_type      TEXT        NOT NULL,    -- Taxonomía BNOTIFY-004
    channel         TEXT        NOT NULL,    -- 'chat', 'email', 'sms', 'push'
    locale          TEXT        NOT NULL DEFAULT 'es',
    tenant_id       TEXT        NULL,        -- NULL = plantilla global del sistema

    subject         TEXT        NULL,        -- Para email/push
    body            TEXT        NOT NULL,    -- Plantilla con {{variables}}
    version         SMALLINT    NOT NULL DEFAULT 1,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (event_type, channel, locale, tenant_id, version)
);
```

### 3.4 `bnotify.audience`

Listas de suscripción propias de bNotify — distintas de los roles de bAuth.

```sql
CREATE TABLE bnotify.audience (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    name            TEXT        NOT NULL,
    description     TEXT        NULL,
    ctx_id          UUID        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, name)
);

CREATE TABLE bnotify.audience_member (
    audience_id     UUID        NOT NULL REFERENCES bnotify.audience(id) ON DELETE CASCADE,
    bauth_user_id   UUID        NOT NULL,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ctx_id          UUID        NOT NULL,
    PRIMARY KEY (audience_id, bauth_user_id)
);
```

### 3.5 `bnotify.device_token`

Tokens de dispositivo para push notifications (FCM/APNs/UnifiedPush).
Registrados por bNotify cuando el cliente móvil se conecta y presenta token.

```sql
CREATE TABLE bnotify.device_token (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    bauth_user_id   UUID        NOT NULL,
    ctx_id          UUID        NOT NULL,           -- ctx_id de la sesión que registró el token
    tenant_id       TEXT        NOT NULL,

    platform        TEXT        NOT NULL,           -- 'android', 'ios', 'unified_push'
    provider        TEXT        NOT NULL,           -- 'fcm', 'apns', 'ntfy'
    token           TEXT        NOT NULL,
    endpoint_url    TEXT        NULL,               -- Para UnifiedPush

    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    last_used_at    TIMESTAMPTZ NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (bauth_user_id, platform, provider)
);
```

---

## 4. Vistas cruzadas con GRANTs exactos

### 4.1 `bnotify.v_bauth_user_channel`

bNotify necesita resolver `bauth_user_id` → email, teléfono para despachar
notificaciones. Esta vista expone exactamente esos campos — sin exponer roles,
contraseñas, ni ningún otro atributo de identidad.

```sql
-- Creada en schema bnotify, sobre tabla de bauth
-- GRANTs: bnotify_rw tiene SELECT. Ningún otro.
CREATE VIEW bnotify.v_bauth_user_channel AS
SELECT
    u.id            AS bauth_user_id,
    u.tenant_id,
    a_email.valor   AS email,
    a_phone.valor   AS phone_number,   -- NULL si no tiene teléfono verificado
    a_name.valor    AS display_name
FROM bauth.bos_user_template u
LEFT JOIN bauth.idn_atributo a_email
    ON a_email.user_id = u.id AND a_email.atributo_tipo = 'EMAIL' AND a_email.activo = TRUE
LEFT JOIN bauth.idn_atributo a_phone
    ON a_phone.user_id = u.id AND a_phone.atributo_tipo = 'PHONE' AND a_phone.verificado = TRUE
LEFT JOIN bauth.idn_atributo a_name
    ON a_name.user_id = u.id AND a_name.atributo_tipo = 'DISPLAY_NAME' AND a_name.activo = TRUE;

-- GRANTs exactos
GRANT SELECT ON bnotify.v_bauth_user_channel TO bnotify_rw;
-- Ningún GRANT a bchat_rw, correo_rw, ni a usuarios de aplicación directamente
```

### 4.2 `bnotify.v_audit_class`

bNotify consulta esta vista para saber la clase de auditoría de un event_type
antes de persistir el registro. El clasificador nunca accede directamente a `bauth.*`.

```sql
CREATE VIEW bnotify.v_audit_class AS
SELECT
    event_type,
    audit_class    -- 'A', 'B', o 'C'
FROM bauth.aud_compliance_map
WHERE active = TRUE;

GRANT SELECT ON bnotify.v_audit_class TO bnotify_rw;
```

### 4.3 Vista para el adaptador de chat (futuro — cuando exista schema `bchat`)

Esta vista se creará en G2 cuando el schema `bchat` exista. Se documenta aquí
para reservar el slot y no sorprender a futuros agentes.

```sql
-- Creada en G2:
-- CREATE VIEW bnotify.v_bchat_room_members AS
-- SELECT room_id, bauth_user_id FROM bchat.room_member WHERE active = TRUE;
-- GRANT SELECT ON bnotify.v_bchat_room_members TO bnotify_rw;
```

---

## 5. Schema `bauth` — tablas de auditoría (referencia para bNotify)

Estas tablas son propiedad de bAuth. bNotify no escribe en ellas — las consume
a través de las vistas §4. Se documentan aquí como referencia para el clasificador.

| Tabla | Descripción |
|-------|-------------|
| `bauth.aud_event` | Eventos WORM clase A. PK uuid, hash-chain, event_type, ctx_id, payload JSONB |
| `bauth.aud_compliance_map` | event_type → audit_class. La tabla que alimenta `v_audit_class` |
| `bauth.blk_merkle_batch` | Manifesto de cada lote Merkle clase B: raíz, conteo de hojas, rango temporal |

El DDL completo de `bauth.*` está en el repositorio de bAuth (REPARACIONBAUTH —
migraciones de Fase 1 y Fase 7.X).

---

## 6. Migraciones — convención

Las migraciones de `bnotify` usan sqlx-cli con el directorio `migrations/` en el
repositorio de bNotify:

```
BnotifyAgent/src/migrations/
├── 0001_bnotify_core.sql           -- Crea schema bnotify, roles, tablas §3
├── 0002_bnotify_views.sql          -- Vistas cruzadas §4 (depende de bauth schema)
├── 0003_bnotify_partition_jul2026.sql -- Primera partición de notification_event
└── ...
```

**Reglas de migración:**
1. Cada migración es idempotente (usa `IF NOT EXISTS`, `CREATE OR REPLACE VIEW`)
2. La numeración es correlativa y nunca tiene gaps ni retrocesos
3. Un cambio en una vista existente = nueva migración `DROP VIEW + CREATE VIEW`, no edición in-situ
4. Las migraciones de `bnotify` nunca modifican schemas ajenos (`bauth`, `bchat`, `correo`)
5. `sqlx migrate run` se ejecuta como parte del startup del daemon antes de aceptar conexiones

---

## 7. Aislamiento — verificación obligatoria en staging

Antes de considerar BNOTIFY-008 implementado, verificar con `psql`:

```sql
-- bnotify_rw NO puede escribir en bauth.*
SET ROLE bnotify_rw;
INSERT INTO bauth.aud_event (id, event_type) VALUES (gen_random_uuid(), 'test');
-- Debe retornar: ERROR: permission denied for table aud_event

-- bauth_rw NO puede escribir en bnotify.*
SET ROLE bauth_rw;
INSERT INTO bnotify.notification_event (intent_id, delivery_id, ctx_id, ...) VALUES (...);
-- Debe retornar: ERROR: permission denied for table notification_event

-- bnotify_rw SÍ puede leer la vista cruzada
SET ROLE bnotify_rw;
SELECT COUNT(*) FROM bnotify.v_bauth_user_channel;
-- Debe retornar: un número (no error de permisos)
```

---

*BNOTIFY-008 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Un schema por dueño no es burocracia: es la única forma de que un clúster compartido no se convierta en un monolito de datos.*
