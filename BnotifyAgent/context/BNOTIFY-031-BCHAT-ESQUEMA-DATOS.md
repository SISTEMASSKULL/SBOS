---
codigo: BNOTIFY-031
version: 1.0.0
estado: BORRADOR
gate: G2
depende_de: [BNOTIFY-030]
doctrina_que_ejerce: [D14, D18]
criterio_implementado: >
  La migración 0001_bchat_core.sql se aplica sin errores en SBOS_db.
  El schema bchat contiene las tablas room, message, room_member, y message_attachment.
  INSERT de un mensaje y SELECT del mismo por sequence retorna datos correctos.
  La vista bchat.v_room_members es accesible por bnotify_rw.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-031 — bChat Esquema de Datos
## PostgreSQL: salas, mensajes, membresías, particionado, FTS, retención

**Versión:** 1.0.0 · **Gate:** G2 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-030 (protocolo — los números de secuencia), BNOTIFY-008 (DDL convenciones), ADR-006 (clúster compartido)

---

## 1. Principios del esquema bChat

- **Dueño exclusivo:** solo `bchat_rw` escribe en el schema `bchat`
- **Secuencias por sala:** cada sala tiene su propio contador de secuencia (`bigserial`) para evitar gaps
- **Append-only messages:** `bchat.message` es de solo append — no hay UPDATE ni DELETE de filas; los borrados lógicos usan `deleted_at`
- **Particionado temporal:** `bchat.message` se particiona por mes para mantener consultas rápidas con historial largo
- **FTS incluido:** `pg_trgm` + `tsvector` en español para búsqueda de texto completo (no motor externo hasta C2)

---

## 2. Tablas principales

### 2.1 `bchat.room`

```sql
CREATE TABLE bchat.room (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    name            TEXT        NULL,       -- NULL para DMs
    type            TEXT        NOT NULL,   -- 'direct', 'group', 'channel', 'broadcast'
    creator_id      UUID        NOT NULL,   -- bauth_user_id
    description     TEXT        NULL,
    avatar_media_id UUID        NULL,       -- FK bchat.media_object

    -- Estado
    archived        BOOLEAN     NOT NULL DEFAULT FALSE,
    archived_at     TIMESTAMPTZ NULL,
    archived_by     UUID        NULL,

    -- Secuencia de mensajes (el corazón de BNOTIFY-030 §4.3)
    last_sequence   BIGINT      NOT NULL DEFAULT 0,

    -- Retención
    retention_days  SMALLINT    NULL,       -- NULL = retención indefinida

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_room_tenant ON bchat.room (tenant_id);
CREATE INDEX idx_room_creator ON bchat.room (creator_id);
```

### 2.2 `bchat.room_member`

```sql
CREATE TABLE bchat.room_member (
    room_id         UUID        NOT NULL REFERENCES bchat.room(id) ON DELETE CASCADE,
    bauth_user_id   UUID        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    role            TEXT        NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member', 'guest'
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at         TIMESTAMPTZ NULL,   -- NULL = sigue en la sala
    active          BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Cursor de lectura por dispositivo (cuánto leyó este usuario)
    last_read_sequence  BIGINT  NOT NULL DEFAULT 0,

    PRIMARY KEY (room_id, bauth_user_id)
);

CREATE INDEX idx_room_member_user ON bchat.room_member (bauth_user_id, active)
    WHERE active = TRUE;
```

### 2.3 `bchat.message` (particionada)

```sql
CREATE TABLE bchat.message (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    room_id         UUID        NOT NULL REFERENCES bchat.room(id),
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    sender_id       UUID        NOT NULL,   -- bauth_user_id
    sequence        BIGINT      NOT NULL,   -- Secuencia dentro de la sala (ver §3)

    -- Contenido
    type            TEXT        NOT NULL DEFAULT 'text',  -- 'text', 'media', 'forwarded', 'system'
    text            TEXT        NULL,       -- Solo texto plano — nunca almacenar metadata de E2EE
    reply_to_id     UUID        NULL,       -- message_id del mensaje al que responde
    forwarded_from  UUID        NULL,       -- message_id original si es reenvío

    -- Borrado lógico (append-only)
    deleted_at      TIMESTAMPTZ NULL,       -- NULL = no borrado
    deleted_by      UUID        NULL,       -- bauth_user_id del que borró

    -- FTS (solo para texto no E2EE)
    search_vector   TSVECTOR    NULL,       -- Generado por trigger

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, created_at)   -- PK compuesta para particionado
) PARTITION BY RANGE (created_at);

-- Índices en la tabla padre
CREATE INDEX idx_message_room_seq   ON bchat.message (room_id, sequence DESC);
CREATE INDEX idx_message_sender     ON bchat.message (sender_id);
CREATE INDEX idx_message_fts        ON bchat.message USING GIN (search_vector)
    WHERE deleted_at IS NULL AND search_vector IS NOT NULL;

-- Trigger FTS
CREATE OR REPLACE FUNCTION bchat.update_message_search_vector()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.text IS NOT NULL AND NEW.type = 'text' THEN
        NEW.search_vector := to_tsvector('spanish', NEW.text);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_message_search
    BEFORE INSERT ON bchat.message
    FOR EACH ROW EXECUTE FUNCTION bchat.update_message_search_vector();

-- Partición inicial
CREATE TABLE bchat.message_y2026m07
    PARTITION OF bchat.message
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
```

### 2.4 `bchat.message_attachment`

```sql
CREATE TABLE bchat.message_attachment (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id      UUID        NOT NULL,
    room_id         UUID        NOT NULL,   -- Redundante para facilitar JOINs
    tenant_id       TEXT        NOT NULL,

    media_id        UUID        NOT NULL REFERENCES bchat.media_object(id),
    attachment_type TEXT        NOT NULL,   -- 'image', 'video', 'audio', 'document', 'voice'
    filename        TEXT        NULL,
    size_bytes      BIGINT      NOT NULL,
    mime_type       TEXT        NOT NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.5 `bchat.media_object`

```sql
CREATE TABLE bchat.media_object (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    uploader_id     UUID        NOT NULL,   -- bauth_user_id
    ctx_id          UUID        NOT NULL,

    s3_key          TEXT        NOT NULL UNIQUE,  -- Ruta en S3/MinIO
    s3_bucket       TEXT        NOT NULL DEFAULT 'bchat-media',
    size_bytes      BIGINT      NOT NULL,
    mime_type       TEXT        NOT NULL,
    thumbnail_key   TEXT        NULL,       -- Solo para imagen/video

    -- Acceso
    public          BOOLEAN     NOT NULL DEFAULT FALSE,
    expires_at      TIMESTAMPTZ NULL,       -- NULL = sin expiración

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 3. Secuencia por sala (mecanismo anti-gap)

El `sequence` de cada mensaje debe ser atómico y sin gaps dentro de la sala.
Se implementa con una función PostgreSQL que hace `UPDATE ... RETURNING`:

```sql
CREATE OR REPLACE FUNCTION bchat.next_sequence(p_room_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    v_seq BIGINT;
BEGIN
    UPDATE bchat.room
    SET last_sequence = last_sequence + 1
    WHERE id = p_room_id
    RETURNING last_sequence INTO v_seq;
    RETURN v_seq;
END;
$$;

-- Uso en INSERT de mensaje:
-- INSERT INTO bchat.message (room_id, sequence, ...) VALUES ($1, bchat.next_sequence($1), ...)
```

---

## 4. Vistas cruzadas publicadas

### 4.1 `bnotify.v_bchat_room_members`

Vista que bNotify usa para expandir destino tipo `DESTINATION_CHANNEL_ROOM`:

```sql
-- Creada en schema bnotify (al crear el schema bchat)
CREATE VIEW bnotify.v_bchat_room_members AS
SELECT room_id, bauth_user_id, tenant_id
FROM bchat.room_member
WHERE active = TRUE;

GRANT SELECT ON bnotify.v_bchat_room_members TO bnotify_rw;
```

---

## 5. Política de retención y archivado

| Tipo de sala | Retención por defecto | Comportamiento al vencer |
|-------------|:--------------------:|--------------------------|
| Direct (DM) | 1 año | `deleted_at = NOW()` lógico; S3 expira en 30 días extra |
| Grupo | 2 años | Idem |
| Canal | Indefinida | Solo retención manual por admin |
| Broadcast | 90 días | Purga automática |

Los mensajes con `deleted_at` no nulo se purgan físicamente del almacenamiento tras
`retention_days + 30 días de gracia`. Las particiones antiguas se `DETACH` y archivan.

---

*BNOTIFY-031 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Los números de secuencia son la clave de todo. Sin ellos, no hay cola offline ni reconciliación fiable.*
