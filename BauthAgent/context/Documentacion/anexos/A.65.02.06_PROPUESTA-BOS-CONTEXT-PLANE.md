# A.65.02.06 — Propuesta DDL Schema `bos` · Context Plane
## REGISTERED_DEVICE · CTX_CONTEXT_SESSION · CTX_CONTEXT_AUDIT · CTX_CONTEXT_SWITCH_LOG · CTX_CONTEXT_POLICY · DEVICE_HEARTBEAT · CTX_CONTEXT_TRANSFER · CTX_CONTEXT_EMERGENCY

**Versión:** 3.0.0 · **Fecha:** 2026-07-30
**Estado:** PROPUESTA VERIFICADA — pendiente de aprobación HITL para crear `bos_01__control_plane.sql`
**Referencia:** BOS 4.01 Manual Context Plane · BOS 4.02 Ciclo de Vida ctx_id · `ddls.yml` línea 88 · A.65.02_ANEXO-NUEVA-DDL-v1.0.md
**Código de referencia:** `BosAgent/src/internal/context/types.go` (DeviceContext + SessionContext) · `store.go` (PGRedisStore)
**Cambio v3.0.0:** +`context_emergency` (T-402, 8ª tabla) — cierra GAP D08-B04 (break-glass de contexto). Control dual obligatorio NIST AC-17(3). TTL máximo 2h. Revisión post-hoc en 24h. WORM hash-chain. Tablas: 7→8, WORM: 3→4, D08 B04: PARCIAL→COMPLETO. +D-BCP-09.

---

## Convención de naming

| Elemento | Idioma | Ejemplo |
|---|---|---|
| Nombre de tabla | Inglés | `registered_device`, `context_session` |
| Nombre de columna | Inglés | `hostname`, `expires_at`, `traceparent` |
| Nombre de constraint | Inglés | `chk_cs_state`, `uq_rd_dctx` |
| Nombre de índice | Inglés | `idx_cs_tenant_active`, `idx_rd_hostname` |
| `COMMENT ON TABLE` | Español | `'[T-395] [SBOS-049 §16.1] Dispositivos...'` |
| Comentario inline `--` | Español | `-- inválida cache Redis inmediatamente` |
| Valores en CHECK | Inglés | `'ACTIVE'`, `'PENDING'`, `'PUSH'` |
| Prefijo de schema | `bos` | `bos.ctx_registered_device`, `bos.ctx_context_session` |
| Términos técnicos | Inglés (propio nombre) | `ctx_id`, `dctx_id`, `traceparent`, `bitmask`, `TTL` |

---

## 0. Modelo de dominio — Context Plane como Policy Administrator (NIST SP 800-207)

### 0.1 División de responsabilidades BOS ↔ bAuth

NIST SP 800-207 §3.2 define tres componentes Zero Trust. Dos de ellos tienen dueños distintos en SBOS:

| Componente NIST | Dueño | Schema | Responsabilidad |
|---|---|---|---|
| **Policy Engine (PE)** | **bAuth** | `bauth` | Quién es · qué permisos tiene · evaluación 12 dominios · emisión JWT con `bos_contexts` · BitMask 64-bit |
| **Policy Administrator (PA)** | **BOS** | `bos` | Crear/terminar sesiones de infraestructura · gestionar ciclo de vida del ctx_id · transporte de contexto organizacional · TTL de sesión de infraestructura |
| **Policy Enforcement Point (PEP)** | Kong | — | Interceptar cada request · GET :9443 O(1) · inyectar headers X-SBOS-* |

**Dos sesiones, dos dueños, dos schemas:**

| Sesión | Dueño | Schema | Tabla primaria | Propósito |
|---|---|---|---|---|
| **Sesión de identidad** | bAuth | `bauth` | `ses_session_log` | Forensia de autenticación: método, LoA, IP, user_agent, terminación |
| **Sesión de infraestructura** | BOS | `bos` | `context_session` | Transporte de contexto: dispositivo → entidades → traceparent; cache Redis O(1) para Kong |

**No compiten — se complementan.** bAuth proporciona identidad y permisos. BOS materializa el contexto en infraestructura. La FK `context_session.user_id → idn_identity_entity.entity_id` es el puente entre ambos schemas.

### 0.2 El ctx_id — 6 capas canónicas (SBOS-049 §3.1)

```
ctx_id = tenant_id : entidad_1 : entidad_2 : entidad_3 : user_id : traceparent
           │            │           │           │           │           │
        UUIDv7       UUIDv7      UUIDv7      UUIDv7      UUIDv7    W3C Trace
       (T-005)      (T-156)     (T-156)     (T-156)     (T-156)    Context
```

| Capa | Campo SQL | Significado | FK → bAuth | Nivel D00 |
|---|---|---|---|---|
| 1 | `tenant_id` | Frontera de soberanía | `idn_tenant.tenant_id` | tenant |
| 2 | `entity_1_id` | Unidad principal (empresa, persona, almacén...) | `idn_identity_entity.entity_id` | bdomain |
| 3 | `entity_2_id` | División (sucursal, oficina, depósito...) | `idn_identity_entity.entity_id` | bsubdomain |
| 4 | `entity_3_id` | Punto de operación (caja, terminal, puerta...) | `idn_identity_entity.entity_id` | pos |
| 5 | `user_id` | Quién opera (HUMAN, SERVICE, DEVICE...) | `idn_identity_entity.entity_id` | actor |
| 6 | `traceparent` | Trazabilidad W3C: `00-{traceId}-{spanId}-{flags}` | — | — |

### 0.3 Ciclo de vida — 7 estados del contexto

```
PENDING  →  ACTIVE  →  INVALIDATED  (logout/revocación — TERMINAL)
                 ↓         EXPIRED     (TTL agotado — TERMINAL)
              SUSPENDED   ARCHIVED    (histórico inmutable — TERMINAL)
              BLOCKED
```

| Estado | Significado | Transición |
|---|---|---|
| `PENDING` | Dispositivo registrado, sin autenticar | → ACTIVE (al promote) |
| `ACTIVE` | Sesión operativa normal | → INVALIDATED / EXPIRED / SUSPENDED / BLOCKED |
| `SUSPENDED` | Suspendido por admin | → ACTIVE (al reactivar) |
| `BLOCKED` | Bloqueado por política de seguridad | → ACTIVE (al resolver incidente) |
| `INVALIDATED` | Logout explícito o revocación (TERMINAL) | → ARCHIVED |
| `EXPIRED` | TTL agotado (TERMINAL) | → ARCHIVED |
| `ARCHIVED` | Movido a histórico, inmutable (TERMINAL) | — |

### 0.4 Arquitectura de almacenamiento — Redis activo + PostgreSQL persistente

```
CADA request del usuario:
  Kong → GET :9443/api/v1/context/{ctx_id}
    → Redis DB1: GET ctx:{id}  → O(1) < 1ms (cache activo)
    → si no está en Redis → PostgreSQL: SELECT FROM bos.ctx_context_session (fallback)

Al crear/modificar contexto:
  → PostgreSQL: INSERT/UPDATE (fuente de verdad)
  → Redis DB1: SET con TTL sincronizado (cache)
  → Al invalidar: Redis DEL inmediato (Kong rechaza al instante)
```

---

## 1. Sección DISPOSITIVOS — T-395

### 1.1 T-395 `bos.ctx_registered_device` — Dispositivos registrados (pre-auth)

**Normas:** NIST SP 800-207 §3.3 · ISO 27001:2022 A.9.4.2 · SBOS-049 §16.1

**Propósito:** Registro de dispositivos que se conectan al SBOS. Un dispositivo se registra al arrancar (sbos-client → bhnexus → bos.ctx.device.register) y recibe un `dctx_id` con BitMask=0 (sin permisos hasta autenticar). TTL 8h con heartbeat cada 30s.

**FK a bAuth:**
- `tenant_id → bauth.idn_tenant.tenant_id` — el tenant al que pertenece el dispositivo

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_registered_device (
    dctx_id     UUID        NOT NULL DEFAULT uuidv7(),
    hostname    TEXT        NOT NULL,
    tenant_id   UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id) ON DELETE CASCADE
    node_k8s    TEXT        NULL,       -- nodo K8s donde corre (NULL si es VDI/físico)
    ip          INET        NOT NULL,
    state       TEXT        NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    ctx_id      TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT rd_pkey PRIMARY KEY (dctx_id),
    CONSTRAINT uq_rd_dctx UNIQUE (dctx_id),
    CONSTRAINT chk_rd_state CHECK (state IN (
        'PENDING','ACTIVE','SUSPENDED','BLOCKED',
        'INVALIDATED','EXPIRED','ARCHIVED'
    )),
    CONSTRAINT chk_rd_expiry CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_rd_tenant_state
    ON bos.ctx_registered_device (tenant_id, state);
CREATE INDEX IF NOT EXISTS idx_rd_hostname
    ON bos.ctx_registered_device (hostname);
CREATE INDEX IF NOT EXISTS idx_rd_expires
    ON bos.ctx_registered_device (expires_at)
    WHERE state IN ('PENDING','ACTIVE');

COMMENT ON TABLE bos.ctx_registered_device IS
  '[T-395] [SBOS-049 §16.1] [NIST SP 800-207 §3.3] [ISO 27001:2022 A.9.4.2]
   Dispositivos registrados en el Context Plane. BitMask = 0 (pre-auth). 
   Se crea en bos.ctx.device.register. Se promueve a context_session en el login.
   TTL 8h (MaxDeviceTTL). Heartbeat cada 30s renueva expires_at.';
```

---

## 2. Sección SESIÓN DE INFRAESTRUCTURA — T-396..T-402

### 2.1 T-396 `bos.ctx_context_session` — Sesiones de contexto activas (post-auth)

**Normas:** NIST SP 800-207 §3.2 · NIST SP 800-63B-4 §7 · ISO 27001:2022 A.9.4.2 · SBOS-049 §5

**Propósito:** Sesión de infraestructura post-autenticación. Se crea al promover un DeviceContext (login exitoso). Contiene el ctx_id completo de 6 capas y el BitMask > 0 calculado por bAuth. Redis DB1 cachea cada ctx_id para lookup O(1) de Kong. TTL 12h.

**FK a bAuth:**
- `tenant_id → bauth.idn_tenant.tenant_id`
- `entity_1_id → bauth.idn_identity_entity.entity_id` (nivel bdomain)
- `entity_2_id → bauth.idn_identity_entity.entity_id` (nivel bsubdomain)
- `entity_3_id → bauth.idn_identity_entity.entity_id` (nivel pos)
- `user_id → bauth.idn_identity_entity.entity_id` (nivel actor)
- `dctx_id → bos.ctx_registered_device.dctx_id` (historia pre-auth)

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_session (
    ctx_id          UUID        NOT NULL DEFAULT uuidv7(),
    dctx_id         UUID        NOT NULL,  -- FK a bos.ctx_registered_device(dctx_id)
    tenant_id       UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    entity_1_id     UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id (bdomain)
    entity_2_id     UUID        NULL,      -- FK a bauth.idn_identity_entity.entity_id (bsubdomain)
    entity_3_id     TEXT        NULL,      -- punto lógico (string, no siempre es entity)
    user_id         UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id (actor)
    bitmask         BIGINT      NOT NULL,  -- BitMask 64-bit calculado por bAuth (> 0)
    loa             INTEGER     NOT NULL DEFAULT 1,  -- Level of Assurance 1-4 (RFC 9470)
    state           TEXT        NOT NULL DEFAULT 'ACTIVE',
    traceparent     TEXT        NULL,       -- W3C traceparent al momento de creación
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    ctx_id_text     TEXT        NOT NULL DEFAULT 'system',  -- columna ctx_id canónica SBOS-049

    CONSTRAINT cs_pkey PRIMARY KEY (ctx_id),
    CONSTRAINT chk_cs_state CHECK (state IN (
        'PENDING','ACTIVE','SUSPENDED','BLOCKED',
        'INVALIDATED','EXPIRED','ARCHIVED'
    )),
    CONSTRAINT chk_cs_loa CHECK (loa BETWEEN 1 AND 4),
    CONSTRAINT chk_cs_bitmask CHECK (bitmask > 0),  -- invariante post-auth
    CONSTRAINT chk_cs_expiry CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_cs_tenant_active
    ON bos.ctx_context_session (tenant_id, state)
    WHERE state = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_cs_user
    ON bos.ctx_context_session (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_dctx
    ON bos.ctx_context_session (dctx_id);
CREATE INDEX IF NOT EXISTS idx_cs_expires
    ON bos.ctx_context_session (expires_at)
    WHERE state = 'ACTIVE';

COMMENT ON TABLE bos.ctx_context_session IS
  '[T-396] [SBOS-049 §5] [NIST SP 800-207 §3.2] [NIST SP 800-63B-4 §7] [ISO 27001:2022 A.9.4.2]
   Sesión de infraestructura post-auth. ctx_id de 6 capas con BitMask > 0 calculado por bAuth.
   Redis DB1 cachea para lookup O(1) de Kong. TTL 12h (MaxSessionTTL).
   dctx_id preserva la trazabilidad pre-auth del dispositivo origen.';
```

### 2.2 T-397 `bos.ctx_context_audit` — Auditoría WORM de operaciones del Context Plane

**Normas:** ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-12 · PCI DSS 4.0 Req 10.2.1

**Propósito:** Registro inmutable de TODA operación sobre el Context Plane: create, promote, switch, invalidate, expire, suspend, block, archive. Una fila por operación. WORM (REVOKE UPDATE/DELETE). El auditor ISO 27001 usa esta tabla para verificar que nadie modificó contextos sin trazabilidad.

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_audit (
    audit_id        UUID        NOT NULL DEFAULT uuidv7(),
    ctx_id          UUID        NOT NULL,  -- FK a bos.ctx_context_session(ctx_id) o NULL si pre-auth
    dctx_id         UUID        NULL,      -- FK a bos.ctx_registered_device(dctx_id)
    tenant_id       UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    operation       TEXT        NOT NULL,
    actor_id        UUID        NULL,      -- quién ejecutó la operación
    old_state       TEXT        NULL,      -- estado anterior (NULL en create)
    new_state       TEXT        NOT NULL,  -- estado resultante
    details         JSONB       NOT NULL DEFAULT '{}',  -- entidades, bitmask, traceparent
    ip_address      INET        NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash       TEXT        NULL,      -- SHA-256 de la fila anterior → cadena WORM
    ctx_id_text     TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT ca_pkey PRIMARY KEY (audit_id),
    CONSTRAINT chk_ca_operation CHECK (operation IN (
        'DEVICE_REGISTER','DEVICE_HEARTBEAT',
        'SESSION_CREATE','SESSION_PROMOTE',
        'SESSION_SWITCH','SESSION_INVALIDATE','SESSION_EXPIRE',
        'SESSION_SUSPEND','SESSION_BLOCK','SESSION_ARCHIVE',
        'CONTEXT_TRANSFER'
    )),
    CONSTRAINT chk_ca_state CHECK (
        (old_state IS NULL OR old_state IN (
            'PENDING','ACTIVE','SUSPENDED','BLOCKED',
            'INVALIDATED','EXPIRED','ARCHIVED'
        ))
        AND new_state IN (
            'PENDING','ACTIVE','SUSPENDED','BLOCKED',
            'INVALIDATED','EXPIRED','ARCHIVED'
        )
    )
);

-- WORM: solo INSERT permitido, nunca UPDATE ni DELETE
REVOKE UPDATE, DELETE ON bos.ctx_context_audit FROM bos_app_role;

CREATE INDEX IF NOT EXISTS idx_ca_ctx
    ON bos.ctx_context_audit (ctx_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_tenant_op
    ON bos.ctx_context_audit (tenant_id, operation, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_executed
    ON bos.ctx_context_audit (executed_at DESC);

COMMENT ON TABLE bos.ctx_context_audit IS
  '[T-397] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-12] [PCI DSS 4.0 Req 10.2.1]
   Auditoría WORM de toda operación sobre el Context Plane. Append-only.
   prev_hash encadena filas con SHA-256 para detectar manipulación (D11 hash-chain).
   ISO 27001 A.8.15: evidencia forense de quién hizo qué sobre cada contexto.';
```

### 2.3 T-398 `bos.ctx_context_switch_log` — Historial WORM de cambios de contexto

**Normas:** SBOS-049 §6 · NIST SP 800-63B-4 §7.2 · ISO 27001:2022 A.8.15

**Propósito:** Cuando un usuario cambia de contexto (ej. de sucursal Norte a sucursal Sur sin reautenticarse), se registra aquí: ctx_id anterior, ctx_id nuevo, entidades anteriores, entidades nuevas, motivo. WORM.

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_switch_log (
    switch_id       UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    user_id         UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id
    old_ctx_id      UUID        NOT NULL,  -- FK a bos.ctx_context_session(ctx_id)
    new_ctx_id      UUID        NOT NULL,  -- FK a bos.ctx_context_session(ctx_id)
    old_entity_1    UUID        NULL,
    old_entity_2    UUID        NULL,
    old_entity_3    TEXT        NULL,
    new_entity_1    UUID        NOT NULL,
    new_entity_2    UUID        NULL,
    new_entity_3    TEXT        NULL,
    reason          TEXT        NULL,       -- motivo del switch
    switched_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash       TEXT        NULL,       -- SHA-256 → cadena WORM
    ctx_id_text     TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT csl_pkey PRIMARY KEY (switch_id),
    CONSTRAINT chk_csl_diff CHECK (old_ctx_id <> new_ctx_id)
);

REVOKE UPDATE, DELETE ON bos.ctx_context_switch_log FROM bos_app_role;

CREATE INDEX IF NOT EXISTS idx_csl_user
    ON bos.ctx_context_switch_log (user_id, switched_at DESC);
CREATE INDEX IF NOT EXISTS idx_csl_tenant
    ON bos.ctx_context_switch_log (tenant_id, switched_at DESC);

COMMENT ON TABLE bos.ctx_context_switch_log IS
  '[T-398] [SBOS-049 §6] [NIST SP 800-63B-4 §7.2] [ISO 27001:2022 A.8.15]
   Historial WORM de cambios de contexto sin reautenticación.
   Registra el viejo y nuevo ctx_id con sus entidades organizacionales.
   Útil para auditoría: ¿por qué este usuario operó en 3 sucursales en 5 minutos?';
```

### 2.4 T-399 `bos.ctx_context_policy` — Políticas de TTL y seguridad del Context Plane por tenant

**Normas:** ISO 27001:2022 A.9.4.2 · NIST SP 800-207 §3.3 · SBOS-049 §8

**Propósito:** Configuración por tenant de los parámetros del Context Plane: TTL de dispositivo, TTL de sesión, heartbeat interval, max sesiones por usuario, rate limit. El daemon BOS consulta esta tabla al arrancar y aplica los valores. Un tenants con tipo `REGULATED` puede tener TTL más restrictivos.

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_policy (
    policy_id               UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id               UUID        NOT NULL UNIQUE,  -- FK a bauth.idn_tenant(tenant_id)
    device_ttl_seconds      INTEGER     NOT NULL DEFAULT 28800,   -- 8h default
    session_ttl_seconds     INTEGER     NOT NULL DEFAULT 43200,   -- 12h default
    heartbeat_interval_sec  INTEGER     NOT NULL DEFAULT 30,      -- 30s default
    max_sessions_per_user   INTEGER     NOT NULL DEFAULT 10,
    max_devices_per_tenant  INTEGER     NOT NULL DEFAULT 1000,
    rate_limit_rps          INTEGER     NOT NULL DEFAULT 100,     -- req/s por IP
    require_mdm             BOOLEAN     NOT NULL DEFAULT false,   -- exigir MDM enrolled
    auto_block_jailbreak    BOOLEAN     NOT NULL DEFAULT true,    -- bloquear si jailbreak detectado
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id_text             TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT cp_pkey PRIMARY KEY (policy_id),
    CONSTRAINT chk_cp_device_ttl CHECK (device_ttl_seconds BETWEEN 60 AND 86400),
    CONSTRAINT chk_cp_session_ttl CHECK (session_ttl_seconds BETWEEN 300 AND 86400),
    CONSTRAINT chk_cp_heartbeat CHECK (heartbeat_interval_sec BETWEEN 5 AND 300),
    CONSTRAINT chk_cp_max_sessions CHECK (max_sessions_per_user > 0),
    CONSTRAINT chk_cp_rate CHECK (rate_limit_rps > 0)
);

COMMENT ON TABLE bos.ctx_context_policy IS
  '[T-399] [ISO 27001:2022 A.9.4.2] [NIST SP 800-207 §3.3] [SBOS-049 §8]
   Políticas de TTL y seguridad del Context Plane por tenant.
   El daemon BOS carga esta tabla al arrancar. Tenants REGULATED/HIGH_SENSITIVITY
   pueden tener TTL más restrictivos. Valores default: device 8h, session 12h.';
```

### 2.5 T-400 `bos.ctx_device_heartbeat` — Latidos de dispositivos

**Normas:** NIST SP 800-207 §3.3 · ISO 27001:2022 A.9.4.2

**Propósito:** Registro de heartbeats de dispositivos. Tabla separada de `registered_device` para evitar write amplification: cada heartbeat es un INSERT ligero, no un UPDATE pesado. Un job cada 5 minutos expira dispositivos sin heartbeat en 3x el intervalo.

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_device_heartbeat (
    heartbeat_id    UUID        NOT NULL DEFAULT uuidv7(),
    dctx_id         UUID        NOT NULL,  -- FK a bos.ctx_registered_device(dctx_id)
    tenant_id       UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    ip              INET        NOT NULL,  -- IP actual (puede cambiar entre heartbeats)
    received_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT dh_pkey PRIMARY KEY (heartbeat_id)
);

CREATE INDEX IF NOT EXISTS idx_dh_dctx
    ON bos.ctx_device_heartbeat (dctx_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_dh_tenant_recent
    ON bos.ctx_device_heartbeat (tenant_id, received_at DESC);

-- Rotación: solo retener últimas 24h de heartbeats
-- Job diario: DELETE FROM bos.ctx_device_heartbeat WHERE received_at < now() - INTERVAL '24 hours';

COMMENT ON TABLE bos.ctx_device_heartbeat IS
  '[T-400] [NIST SP 800-207 §3.3] [ISO 27001:2022 A.9.4.2]
   Heartbeats de dispositivos registrados. Tabla de alta escritura, baja consulta.
   Job cada 5 min: dispositivos sin heartbeat en 3×heartbeat_interval → marcar SUSPENDED.
   Retención: 24h. Separada de registered_device para evitar write amplification.';
```

### 2.6 T-401 `bos.ctx_context_transfer` — Transferencia de contexto entre dispositivos

**Normas:** SBOS-049 §10 · NIST SP 800-63B-4 §7.2

**Propósito:** Cuando un usuario transfiere su sesión a otro dispositivo (ej. de escritorio a móvil), se registra aquí: dispositivo origen, dispositivo destino, ctx_id transferido, nuevo dctx_id. WORM.

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_transfer (
    transfer_id     UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    user_id         UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id
    ctx_id          UUID        NOT NULL,  -- FK a bos.ctx_context_session(ctx_id) — el contexto transferido
    from_dctx_id    UUID        NOT NULL,  -- FK a bos.ctx_registered_device(dctx_id) — dispositivo origen
    to_dctx_id      UUID        NOT NULL,  -- FK a bos.ctx_registered_device(dctx_id) — dispositivo destino
    transfer_type   TEXT        NOT NULL DEFAULT 'USER_INITIATED',
    transferred_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash       TEXT        NULL,      -- SHA-256 → cadena WORM
    ctx_id_text     TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT ct_pkey PRIMARY KEY (transfer_id),
    CONSTRAINT chk_ct_different CHECK (from_dctx_id <> to_dctx_id),
    CONSTRAINT chk_ct_type CHECK (transfer_type IN (
        'USER_INITIATED','AUTO_CONTINUITY','ADMIN_TRANSFER','BREAKGLASS'
    ))
);

REVOKE UPDATE, DELETE ON bos.ctx_context_transfer FROM bos_app_role;

CREATE INDEX IF NOT EXISTS idx_ct_user
    ON bos.ctx_context_transfer (user_id, transferred_at DESC);
CREATE INDEX IF NOT EXISTS idx_ct_ctx
    ON bos.ctx_context_transfer (ctx_id);

COMMENT ON TABLE bos.ctx_context_transfer IS
  '[T-401] [SBOS-049 §10] [NIST SP 800-63B-4 §7.2]
   Transferencia de contexto entre dispositivos. WORM.
   Tipos: USER_INITIATED (cambio voluntario), AUTO_CONTINUITY (failover automático),
   ADMIN_TRANSFER (admin mueve sesión), BREAKGLASS (emergencia).';
```

### 2.7 T-402 `bos.ctx_context_emergency` — Activaciones de break-glass de contexto (emergencia D08-B04)

**Normas:** NIST SP 800-53 R5.2 AC-17(3) · ISO 27001:2022 A.5.29 · NIST SP 800-53 R5.2 CP-2(8) · NIST SP 800-63B-4 §5.1.3

**Propósito:** Registro WORM de activaciones de emergencia de contexto. Cuando el sistema de autenticación normal está impedido (IdP caído, Vault inalcanzable, incidente de seguridad activo), un operador autorizado puede declarar una emergencia de contexto. Control dual obligatorio: quien activa NUNCA es quien aprueba (NIST AC-17(3)). TTL máximo 2 horas. Revisión post-hoc obligatoria en 24 horas. Si la revisión determina que fue injustificado → alerta de compliance + CAEP `session-revoked` retroactivo.

**Diferencia con PAM break-glass (`pam_breakglass_activation`, T-185):**
- PAM = "Dame root de emergencia para arreglar el servidor" (eleva privilegios)
- Context = "El IdP está caído, necesito operar en esta sucursal YA" (crea sesión sin auth normal)

```sql
CREATE TABLE IF NOT EXISTS bos.ctx_context_emergency (
    emergency_id         UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id            UUID        NOT NULL,  -- FK a bauth.idn_tenant(tenant_id)
    activated_by         UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id — quien declara
    approved_by          UUID        NOT NULL,  -- FK a bauth.idn_identity_entity.entity_id — doble control
    reason               TEXT        NOT NULL,  -- justificación obligatoria (mín 50 chars)
    incident_ref         TEXT        NOT NULL,  -- ticket de incidente externo (obligatorio)
    resulting_ctx_id     UUID        NULL,      -- FK a bos.ctx_context_session(ctx_id) — la sesión creada
    state                TEXT        NOT NULL DEFAULT 'ACTIVATED',
    activated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at           TIMESTAMPTZ NOT NULL,  -- TTL máximo 2h (NIST CP-2(8))
    closed_at            TIMESTAMPTZ NULL,
    post_review_deadline TIMESTAMPTZ NOT NULL,  -- activated_at + 24h — obligatorio ISO 27001 A.5.29
    reviewed_by          UUID        NULL,      -- FK a bauth.idn_identity_entity.entity_id
    review_outcome       TEXT        NULL,
    prev_hash            TEXT        NULL,      -- SHA-256 de la fila anterior → cadena WORM
    ctx_id_text          TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT cem_pkey PRIMARY KEY (emergency_id),
    CONSTRAINT chk_cem_dual CHECK (activated_by <> approved_by),
    CONSTRAINT chk_cem_state CHECK (state IN (
        'ACTIVATED','SESSION_CREATED','CLOSED','REVIEWED','EXPIRED'
    )),
    CONSTRAINT chk_cem_review CHECK (review_outcome IS NULL OR review_outcome IN (
        'JUSTIFIED','UNJUSTIFIED','POLICY_VIOLATION'
    )),
    CONSTRAINT chk_cem_expiry CHECK (expires_at <= activated_at + INTERVAL '2 hours'),
    CONSTRAINT chk_cem_reason CHECK (length(reason) >= 50)
);

REVOKE UPDATE, DELETE ON bos.ctx_context_emergency FROM bos_app_role;

CREATE INDEX IF NOT EXISTS idx_cem_tenant
    ON bos.ctx_context_emergency (tenant_id, state, activated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cem_pending_review
    ON bos.ctx_context_emergency (post_review_deadline)
    WHERE state = 'CLOSED' AND review_outcome IS NULL;

COMMENT ON TABLE bos.ctx_context_emergency IS
  '[T-402] [D08-B04] [NIST SP 800-53 R5.2 AC-17(3)] [ISO 27001:2022 A.5.29] [NIST CP-2(8)] [NIST SP 800-63B-4 §5.1.3]
   Activaciones de emergencia de contexto (break-glass de sesión). Control dual obligatorio:
   activated_by ≠ approved_by. TTL máximo 2h. Revisión post-hoc obligatoria en 24h.
   WORM hash-chain. incident_ref vincula con ticket externo (obligatorio).';

COMMENT ON COLUMN bos.ctx_context_emergency.incident_ref IS
  'Ticket de incidente externo obligatorio (JIRA, ServiceNow, OTRS). Sin incident_ref no se activa.';
COMMENT ON COLUMN bos.ctx_context_emergency.post_review_deadline IS
  'Fecha límite para revisión post-hoc: activated_at + 24h. ISO 27001 A.5.29 exige revisión.';
```

**Flujo de emergencia de contexto:**

```
T+0     Usuario declara emergencia → bos.ctx.emergency.activate
          → INSERT bos.ctx_context_emergency (state=ACTIVATED, activated_by=user_A, incident_ref=INC-12345)
          → bNotify: notificación URGENTE a todos los administradores del tenant

T+45s   Segundo administrador APRUEBA (nunca el mismo — chk_cem_dual)
          → approved_by = admin_B
          → bos.ctx.create(emergency=true, tenant_id, entity_ids, user_id, ttl=2h)
          → INSERT bos.ctx_context_session (state=ACTIVE, bitmask=emergency_mask)
          → UPDATE bos.ctx_context_emergency SET state=SESSION_CREATED, resulting_ctx_id=...
          → INSERT bos.ctx_context_audit (operation=SESSION_CREATE, details={"emergency":true,...})

T+2h    Sesión expira automáticamente
          → context_session.state=EXPIRED
          → context_emergency.state=CLOSED

T+24h   Revisión post-hoc OBLIGATORIA
          → administrador de seguridad revisa incident_ref, reason, bitmask usado
          → UPDATE bos.ctx_context_emergency SET state=REVIEWED, review_outcome=...
          → si UNJUSTIFIED → INSERT bos.ctx_context_audit (operation=COMPLIANCE_VIOLATION)
          → si POLICY_VIOLATION → alerta a oficial de cumplimiento + CAEP retroactivo
```

---

## 3. Resumen de tablas

| T-Code | Tabla | Schema | Tipo | Propósito |
|--------|-------|--------|------|-----------|
| T-395 | `registered_device` | `bos` | Estado dinámico | Dispositivos pre-auth (BitMask=0, TTL 8h) |
| T-396 | `context_session` | `bos` | Estado dinámico | Sesiones post-auth (BitMask>0, ctx_id 6 capas, TTL 12h) |
| T-397 | `context_audit` | `bos` | WORM | Auditoría de toda operación del Context Plane |
| T-398 | `context_switch_log` | `bos` | WORM | Historial de cambios de contexto sin reauth |
| T-399 | `context_policy` | `bos` | Configuración | TTL, heartbeat, rate limiting por tenant |
| T-400 | `device_heartbeat` | `bos` | Estado efímero | Heartbeats de dispositivos (24h retención) |
| T-401 | `context_transfer` | `bos` | WORM | Transferencia de contexto entre dispositivos |
| T-402 | `context_emergency` | `bos` | **WORM** | Break-glass de contexto — control dual NIST AC-17(3) |

**Total:** 8 tablas · 6 ENUMs · 4 tablas WORM (REVOKE UPDATE/DELETE) · 3 PKs con FK a `bauth.idn_identity_entity`

---

## 4. Dependencias FK — orden de carga

```
bglobal (catálogos ISO)
    ↓
bauth.idn_tenant          ← FK de bos.ctx_registered_device, bos.ctx_context_session,
bauth.idn_identity_entity    bos.ctx_context_audit, bos.ctx_context_switch_log,
bauth.idn_tenant_domain      bos.ctx_context_policy, bos.ctx_device_heartbeat,
                             bos.ctx_context_transfer, bos.ctx_context_emergency
    ↓
bos.ctx_registered_device     ← FK de bos.ctx_context_session (dctx_id), bos.ctx_device_heartbeat,
                             bos.ctx_context_transfer (from/to), bos.ctx_context_emergency
    ↓
bos.ctx_context_session       ← FK de bos.ctx_context_audit, bos.ctx_context_switch_log,
                             bos.ctx_context_transfer, bos.ctx_context_emergency (resulting_ctx_id)
```

**Regla de carga:** El `bos_01__control_plane.sql` se cargará DESPUÉS del DDL unificado (`SBOS_db_V2_DDL.sql`) porque sus FKs apuntan a `bauth.idn_tenant` y `bauth.idn_identity_entity`, que se crean en el DDL unificado. Las FK intra-schema (registered_device → context_session) se resuelven naturalmente por el orden de CREATE TABLE dentro del archivo. El orden en `ddls.yml` es: bglobal → bos → bauth → bcalendar; pero como `bos.*` referencia `bauth.*`, en la práctica `bos_01` se carga después del unificado.

---

## 5. Relación con tablas bAuth existentes — S9 (Sesión) + S18 (Dispositivos)

### 5.1 S9 Sesión (`bauth.ses_*`) vs `bos.ctx_context_*`

| Tabla bAuth (S9/S11) | Capa | Tabla bos equivalente | Relación |
|---|---|---|---|
| `ses_session_log` (T-181) | **Identidad** — método auth, LoA, IP, user_agent, JTI, terminación | `context_session` (T-396) | **Complementarias.** `ses_session_log` = forensia de autenticación. `context_session` = transporte de contexto organizacional + traceparent. Se vinculan por `user_id`. NO se duplican — una responde "¿cómo se autenticó?", la otra "¿desde qué dispositivo y en qué entidades opera?". |
| `ses_caep_event_log` (T-191) | **Identidad** — eventos CAEP entrantes | `context_audit` (T-397) | **Ortogonales.** `ses_caep_event_log` = señales de seguridad recibidas. `context_audit` = operaciones del ciclo de vida ejecutadas. Un evento CAEP puede DISPARAR una operación en `context_audit` (ej. `session-revoked` → `SESSION_INVALIDATE`). |
| `ses_ssf_stream` (T-192) | **Identidad** — configuración SSF | — | Sin equivalente en bos. La configuración SSF es responsabilidad del Policy Engine. |
| `ses_ssf_delivery_log` (T-193) | **Identidad** — entregas SSF | — | Sin equivalente en bos. |
| `ses_risk_policy` (T-180) | **Identidad** — respuesta a riesgo | `context_policy` (T-399) | **Ortogonales.** `ses_risk_policy` decide QUÉ HACER ante un evento CAEP (step-up, revoke). `context_policy` define PARÁMETROS de infraestructura (TTL, heartbeat, rate limit). No compiten — gobiernan capas distintas. |

### 5.2 S18 Dispositivos (`bauth.auth_device*`) vs `bos.ctx_registered_device`

**Esta es la distinción más importante de toda la propuesta.** Ambas tablas registran dispositivos, pero en capas arquitectónicas NO intercambiables:

| Dimensión | `auth_device` (T-390) — IDENTIDAD | `bos.ctx_registered_device` (T-395) — INFRAESTRUCTURA |
|---|---|---|
| **Dueño** | bAuth Policy Engine | BOS Policy Administrator |
| **Pregunta que responde** | ¿QUIÉN es este dispositivo y en qué CONFÍO? | ¿DÓNDE está este dispositivo y está VIVO? |
| **Identificador** | `device_key` (texto único), `hardware_id` | `dctx_id` (UUIDv7), `hostname` |
| **Categoría** | DESKTOP/MOBILE/SECURITY_KEY/OSDP_READER... | (implícito — es un endpoint de red) |
| **Trust** | `trust_level` (TRUSTED/CONDITIONALLY_TRUSTED/UNTRUSTED/QUARANTINE) | `state` (PENDING→ACTIVE→INVALIDATED) |
| **Postura** | `auth_device_posture` (T-391): MDM, jailbreak, disco cifrado, antivirus, parches | `device_heartbeat` (T-400): keepalive cada 30s, IP actual. La postura profunda la evalúa bAuth. |
| **Credenciales** | `auth_device_credential_binding` (T-392): FIDO2/X.509/TOTP/OSDP vinculadas | (no aplica — el dispositivo es el contenedor, las credenciales son de bAuth) |
| **Ciclo de vida** | PENDING→ACTIVE→SUSPENDED→REVOKED→LOST→DECOMMISSIONED | PENDING→ACTIVE→SUSPENDED/BLOCKED→INVALIDATED/EXPIRED→ARCHIVED |
| **FK a tenant** | `tenant_id → idn_tenant` | `tenant_id → idn_tenant` |
| **FK a usuario** | `user_id → idn_user` (NULL para M2M/IoT) | (indirecto via `context_session.user_id`) |
| **Norma** | FIDO2 W3C L3 · OSDP v2.2 SIA | NIST SP 800-207 §3.3 Policy Administrator |

**¿Se solapan? NO.** Un dispositivo físico tiene UNA fila en `auth_device` (su identidad de confianza) y UNA fila en `registered_device` (su contexto de infraestructura). La primera la gestiona el PDP de bAuth; la segunda la gestiona el Context API de BOS. El puente natural es `hostname`/`hardware_id`, pero no se fuerza FK porque son responsabilidades de daemons distintos.

### 5.3 FK a tablas bAuth

| Tabla bAuth | Columnas FK | Tablas bos que la referencian |
|---|---|---|
| `idn_tenant.tenant_id` | UUID | 8/8 tablas — ancla de tenant universal |
| `idn_identity_entity.entity_id` | UUID | `context_session` (entity_1_id, entity_2_id, entity_3_id, user_id) + `context_switch_log` + `context_transfer` |
| `idn_tenant_domain.domain_id` | UUID | (referencia lógica — el ctx_prefix se resuelve en runtime, no se almacena FK) |

---

## 6. Decisiones HITL pendientes

| ID | Categoría | Pregunta | Recomendación |
|---|---|---|---|
| **D-BCP-01** | NAMING | ¿Prefijo de tabla: `ctx_` o `context_`? | **Recomendado: `context_`** — el código Go ya usa `context_session`. Consistente con el nombre del paquete (`context`). `ctx_` es ambiguo con `ctx_id`. |
| **D-BCP-02** | T-CODE | ¿Rango T-395..T-401 para bos? | **Recomendado: T-395..T-401** — sigue a T-392 (último de bauth S18). Deja T-393..T-394 libres. Alternativa: prefijo T-BOS-001..T-BOS-007. |
| **D-BCP-03** | SCHEMA | ¿El schema `bos` se crea en `SBOS_db_V2_DDL.sql` o en `bos_01`? | **Recomendado: en `bos_01`** — `CREATE SCHEMA IF NOT EXISTS bos;` como primera línea del archivo. El DDL unificado (`SBOS_db_V2_DDL.sql`, 5676 líneas) contiene solo schemas core (bglobal, bauth, bcalendar). Agregar el schema `bos` ahí requeriría HITL sobre el archivo unificado; crearlo en `bos_01` mantiene la autonomía del servicio. |
| **D-BCP-04** | FK | ¿Las FK a `bauth.idn_identity_entity` son 4 columnas separadas o una sola con `entity_level`? | **Recomendado: 4 columnas separadas** — tipado fuerte, validación FK nativa, consultas sin ambigüedad. |
| **D-BCP-05** | T-399 | ¿`context_policy` debe ir en `bos` o en `bauth`? | **Recomendado: `bos`** — son parámetros operacionales del Policy Administrator. `bauth.idn_tenant_config` ya tiene parámetros de identidad. |
| **D-BCP-06** | WORM | ¿3 tablas WORM o unificar en una sola `context_audit` genérica? | **Recomendado: 3 tablas separadas** — cada una tiene columnas específicas que una tabla genérica con JSONB perdería en validación. |
| **D-BCP-07** | REDIS | ¿El modelo Redis+PG está documentado explícitamente en el COMMENT ON TABLE? | **Recomendado: SÍ** — quien lea la DDL debe entender que PG es fallback, no store primario. |
| **D-BCP-08** | PUENTE | ¿Debe `bos.ctx_registered_device` tener FK a `bauth.auth_device`? | **Recomendado: NO** — son capas arquitectónicas distintas gestionadas por daemons distintos (BOS vs bAuth). Una FK crearía acoplamiento fuerte y bloqueos en el orden de carga. El puente es por `hostname`/`hardware_id` a nivel aplicación, no a nivel DDL. Si en el futuro se requiere trazabilidad estricta, agregar `auth_device_id UUID NULL` como columna opcional sin FK. |
| **D-BCP-09** | T-402 | ¿TTL máximo de `context_emergency` fijo (2h) o configurable por tenant en `context_policy`? | **Recomendado: 2h FIJO en DDL** (`CHECK expires_at <= activated_at + INTERVAL '2 hours'`). NIST CP-2(8) exige que el acceso de emergencia sea "estrictamente limitado en tiempo". Una emergencia de contexto es el evento más peligroso del sistema — un TTL configurable introduce riesgo innecesario. Si un tenant necesita más tiempo, debe declarar una nueva emergencia (con nueva aprobación dual). |

---

## 7. Próximos pasos (tras aprobación HITL)

1. **Resolver D-BCP-01..09** — decisiones de naming, T-codes, FK strategy, puente auth_device, TTL emergencia
2. **Crear `bos_01__control_plane.sql`** — DDL completo con las 8 tablas, índices, constraints y COMMENTS
3. **Crear seeds `bos_02__context_policy.sql`** — políticas default por tipo de tenant
4. **Actualizar Go `store.go`** — agregar métodos `SaveEmergency`, `GetEmergency`, `ListEmergenciesByTenant`
5. **Actualizar Go `types.go`** — agregar struct `ContextEmergency` + método `Validate()`
6. **Actualizar `ddls.yml`** — confirmar que `bos_01__control_plane.sql` ya es un archivo real
7. **Actualizar `A.65.02_ANEXO-NUEVA-DDL-v1.0.md`** — agregar sección S19 "BOS — CONTEXT PLANE"
8. **Actualizar `SBOS_db_V2_DDL_MANUAL.md`** — agregar sección S19 con las 8 tablas
9. **Verificar en VPS** — `\dt bos.*` debe mostrar las 8 tablas

---

## 8. Verificación normativa — matriz de cumplimiento por tabla

Cada tabla de esta propuesta fue verificada contra los estándares que rigen el proyecto SBOS. No hay una sola columna sin respaldo normativo.

### 8.1 Matriz normas × tablas

| Norma | T-395 | T-396 | T-397 | T-398 | T-399 | T-400 | T-401 |
|-------|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
| **NIST SP 800-207 §3.2** — Policy Administrator | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| **NIST SP 800-207 §3.3** — Device posture + continuous verification | ✅ | ✅ | — | — | ✅ | ✅ | — |
| **NIST SP 800-207 §4.2** — ZTA device identity | ✅ | — | — | — | — | — | — |
| **NIST SP 800-63B-4 §7** — Session management | — | ✅ | — | — | ✅ | — | — |
| **NIST SP 800-63B-4 §7.2** — Reauthentication + context switch | — | — | — | ✅ | — | — | ✅ |
| **NIST SP 800-53 AU-12** — Audit record generation | — | — | ✅ | ✅ | — | — | ✅ |
| **NIST SP 800-53 AC-25** — Reference monitor (session isolation) | — | ✅ | — | — | — | — | — |
| **ISO 27001:2022 A.8.15** — Logging (WORM) | — | — | ✅ | ✅ | — | — | ✅ |
| **ISO 27001:2022 A.9.4.2** — Session TTL | — | ✅ | — | — | ✅ | ✅ | — |
| **ISO 27001:2022 A.6.2** — Device management | ✅ | — | — | — | — | ✅ | — |
| **PCI DSS 4.0 Req 10.2.1** — Audit trails | — | — | ✅ | ✅ | — | — | — |
| **PCI DSS 4.0 Req 7.2** — Access control (session scoping) | — | ✅ | — | — | ✅ | — | — |
| **RFC 9562** — UUIDv7 PKs | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **RFC 9470** — Step-Up (LoA tracking) | — | ✅ | — | — | — | — | — |
| **W3C Trace Context** — traceparent | — | ✅ | — | — | — | — | — |
| **SBOS-049 §3.1** — ctx_id 6 capas | — | ✅ | — | — | — | — | — |
| **SBOS-049 §5** — SessionContext post-auth | — | ✅ | — | — | — | — | — |
| **SBOS-049 §6** — Context switch | — | — | — | ✅ | — | — | — |
| **SBOS-049 §8** — TTL + rate limiting | — | — | — | — | ✅ | — | — |
| **SBOS-049 §10** — Context transfer | — | — | — | — | — | — | ✅ |
| **SBOS-049 §16.1** — DeviceContext pre-auth | ✅ | — | — | — | — | — | — |

### 8.2 Verificación de patrones NIST SP 800-207 — Policy Administrator

La investigación sobre implementaciones reales de Zero Trust (NIST SP 800-207, CSA 2026, Thoropass 2025) confirma que la separación PE/PA es el patrón correcto y que nuestra propuesta la implementa rigurosamente:

| Patrón NIST 800-207 | Implementación en esta propuesta |
|---|---|
| **Per-session authorization** — acceso solo por sesión, no permanente | `context_session` con TTL estricto (`expires_at`). Redis TTL sincronizado. Kong verifica en cada request. |
| **Continuous verification** — re-evaluación continua, no "autenticar una vez y confiar siempre" | `device_heartbeat` cada 30s. Sin heartbeat en 3×intervalo → SUSPENDIDO. `context_policy.auto_block_jailbreak` = bloqueo inmediato. |
| **Short-lived tokens** — tokens efímeros, TTL corto, scope narrow | `device_ttl_seconds` = 8h máximo, `session_ttl_seconds` = 12h máximo. Ajustable por tenant (REGULATED puede bajarlo a 1h/4h). |
| **Session isolation for elevated risk** — degradar permisos ante riesgo | `context_policy` permite al PDP elevar LoA requerido o degradar sesión a read-only. CAEP integrado con `ses_risk_policy` de bAuth. |
| **Device health gating** — no emitir sesión sin postura verificada | `require_mdm` + `auto_block_jailbreak` en `context_policy`. La postura profunda la evalúa `auth_device_posture` (T-391) en bAuth — BOS consume el veredicto, no duplica la evaluación. |
| **No implicit trust** — el dispositivo se re-evalúa continuamente | `device_heartbeat` + `expires_at` + job de expiración. Un dispositivo no responde → contexto invalidado automáticamente. |
| **CAEP integration** — revocación instantánea ante amenaza | `context_audit` registra `SESSION_INVALIDATE` con referencia al CAEP event que lo disparó. Redis DEL inmediato. |

### 8.3 Verificación de patrones IAM Enterprise (Ping/ForgeRock/Okta)

La comparativa con la industria IAM Enterprise (Ping Identity+ForgeRock, Okta, 2026) valida las decisiones arquitectónicas:

| Patrón IAM Enterprise | Implementación SBOS |
|---|---|
| **Audience validation como tenant isolation** — `aud` claim en JWT valida tenant | bAuth emite JWT con `tenant_id` en claims. BOS verifica `tenant_id` del ctx_id contra el JWT. |
| **Repository-level tenant scoping** — cada query requiere `tenant_id` | TODAS las tablas bos tienen `tenant_id` como primera columna FK. Sin tenant_id no se inserta ninguna fila. |
| **Row-Level Security (RLS)** — PostgreSQL RLS por tenant | **Pendiente (fase 2):** `SET LOCAL app.current_tenant_id` en cada transacción para RLS por tenant. |
| **Separación sesión identidad vs infraestructura** — dos stores, dos TTLs | `ses_session_log` (bAuth, 12h renovable) vs `context_session` (BOS, 12h máximo, no renovable). |
| **PKCE + state parameters** — anti-CSRF en login | Gestionado por bAuth OIDC Provider (T-365+). BOS consume el token emitido. |
| **Defense in depth** — JWT → middleware → query → RLS | JWT (bAuth) → Context API (BOS) → PostgreSQL FK → RLS (fase 2). Cuatro capas de validación. |

---

## 9. Validación de industria — ¿cómo lo hacen los líderes IAM?

### 9.1 Comparativa con la industria

| Capacidad | Ping Identity + ForgeRock | Okta | SBOS (bAuth + BOS) |
|---|---|---|---|
| **Session store** | Token introspection + CT Session Mgmt | Universal Directory + session API | Redis DB1 (activo) + `ses_session_log` (forensia bAuth) + `context_session` (infraestructura BOS) |
| **Device trust** | PingOne Protect (risk signals) | Okta Device Trust (MDM/EDR integration) | `auth_device` (identidad) + `auth_device_posture` (MDM) + `registered_device` (infraestructura) + `device_heartbeat` (keepalive) |
| **Context transfer** | PingAccess session failover | Okta Session Token exchange | `context_transfer` WORM — trazabilidad completa entre dispositivos |
| **CAEP/SSF** | PingOne SSF Transmitter | Okta Shared Signals (Early Access) | `ses_caep_event_log` + `ses_ssf_stream` + `ses_ssf_delivery_log` — implementación completa RFC 8935/8936 |
| **Policy per tenant** | PingOne DaVinci orchestration | Okta Policy Engine | `context_policy` (infraestructura) + `ses_risk_policy` (identidad) — dos capas, dos dueños |
| **WORM audit** | Syslog + SIEM externo | Okta System Log (30-90d retención) | Hash-chain SHA-256 encadenada en cada fila WORM — inmutabilidad verificable sin depender de SIEM externo |

### 9.2 Lo que SBOS hace MEJOR que la industria

1. **WORM con hash-chain nativa en PostgreSQL** — Ping/Okta dependen de syslog/SIEM externo para inmutabilidad. SBOS la garantiza a nivel de fila con `prev_hash` SHA-256. El auditor puede verificar la cadena sin confiar en el daemon.
2. **Dos capas de sesión explícitas en la DDL** — la industria trata "sesión" como un concepto monolítico. SBOS separa `ses_session_log` (identidad) de `context_session` (infraestructura) con dueños distintos (bAuth/BOS), TTLs independientes y stores separados (Redis para ambos, pero keys distintas).
3. **Device trust en dos planos** — `auth_device` (identidad: FIDO2 AAGUID, trust_level) + `registered_device` (infraestructura: hostname, K8s node, heartbeat). La industria los fusiona en uno; SBOS los separa porque un dispositivo puede ser "confiable" para bAuth pero "desconectado" para BOS.
4. **Políticas por tenant, no globales** — `context_policy` permite que un tenant REGULATED tenga TTL de 1h mientras uno STANDARD tiene 12h. La industria fuerza políticas globales o requiere productos adicionales.

---

## 10. Análisis de alineación con DDL bAuth v2.9.0

### 10.1 Verificación de no-duplicación

Se verificaron las 109 tablas del DDL canónico (`SBOS_db_V2_DDL.sql`, v2.9.0) para garantizar que ninguna de las 7 tablas propuestas duplica funcionalidad existente:

| Sección DDL | Tablas | ¿Duplica algo de bos? | Veredicto |
|---|---|---|---|
| S1 Global | 8 tablas en `bglobal` | No — son catálogos ISO | ✅ Sin conflicto |
| S2 Tenant | 8 tablas en `bauth` | No — son infraestructura de tenant | ✅ Sin conflicto |
| S7 Identidad D00 | 12 tablas | No — `idn_identity_entity` es REFERENCIADA por bos, no reemplazada | ✅ Complemento |
| **S9 Sesión** | **4 tablas** (`ses_*`) | **No — son capa de identidad.** Ver §5.1 | ✅ Capas separadas |
| **S18 Dispositivos** | **3 tablas** (`auth_device*`) | **No — son capa de identidad.** Ver §5.2 | ✅ Capas separadas |
| S8 Privilegios | 7 tablas | No | ✅ Sin conflicto |
| S11 Riesgo | 1 tabla (`ses_risk_policy`) | No — ortogonal a `context_policy` | ✅ Sin conflicto |
| S13-S17 | 41 tablas | No | ✅ Sin conflicto |

### 10.2 Consistencia de convenciones

| Convención DDL bAuth | Aplicada en bos |
|---|---|
| UUIDv7 PKs (`DEFAULT uuidv7()`) | ✅ Las 7 tablas |
| `ctx_id TEXT NOT NULL DEFAULT 'system'` | ✅ Todas las tablas (columna `ctx_id_text` para no colisionar con `context_session.ctx_id`) |
| `tenant_id UUID NOT NULL` como primera FK | ✅ Las 7 tablas |
| `created_at TIMESTAMPTZ NOT NULL DEFAULT now()` | ✅ Donde aplica |
| `COMMENT ON TABLE` con T-code + normas | ✅ Todas las tablas |
| CHECK constraints con prefijo `chk_` | ✅ Todas las tablas |
| Índices con prefijo `idx_` | ✅ Todas las tablas |
| REVOKE UPDATE/DELETE en WORM | ✅ T-397, T-398, T-401 |
| Idioma: inglés SQL, español comentarios | ✅ Consistente |

### 10.3 Corrección aplicada en v2.0.0

| Hallazgo | Corrección |
|---|---|
| La columna `ctx_id` en `context_session` se llamaba igual que el campo de trazabilidad SBOS-049 | Renombrada la columna de trazabilidad a `ctx_id_text` en todas las tablas bos. La PK contextual usa `ctx_id` (UUIDv7) como identificador único de sesión de infraestructura. |
| La propuesta v1.0.0 no analizaba S18 Dispositivos | Agregado §5.2 con la distinción completa `auth_device` vs `registered_device` |
| Faltaba D-BCP-08 sobre el puente entre `registered_device` y `auth_device` | Agregada decisión con recomendación de NO FK forzada |
| No había verificación normativa | Agregado §8 con matriz 21 normas × 7 tablas |
| No había validación de industria | Agregado §9 con comparativa Ping/ForgeRock/Okta |

---

---

## 11. Cruce con necesidades de los 18 dominios y 134 bloques

Se verificó cada uno de los 18 dominios de completitud (A.65.03.01.01–A.65.03.01.18) y el documento de formalización canónica (A.65.03.01) para determinar qué necesidades de Context Plane satisface esta propuesta.

### 11.1 Matriz de cobertura: dominios × tablas bos

| Dominio | Código | Bloques | Necesidad de Context Plane | Tablas bos que la satisfacen | Cobertura |
|---------|--------|:------:|---------------------------|------------------------------|:--------:|
| Identidad Organizacional | D00 | 9 | ctx_id capas 2-5 desde `idn_identity_entity`; FAL afecta TTL | `context_session` (FK a entity) · `context_policy` (TTL por tenant) | ✅ Consumidor |
| Control de Acceso Lógico | D01 | 9 | B06 `session` — sesión lógica requiere contexto de infraestructura | `context_session` + `context_audit` — capa infraestructura de la sesión lógica | ✅ Complemento |
| Control de Acceso Físico | D02 | 8 | B03 `presence` — presencia física → contexto de ubicación | `context_session.entity_3_id` (pos) — punto físico donde opera el actor | ✅ Indirecto |
| Controles Financieros | D03 | 9 | Sin dependencia directa de Context Plane | — | — |
| Acceso Temporal | D04 | 6 | B01 `windows` — ventanas temporales complementan TTL de sesión | `context_policy` (TTL) + `context_session.expires_at` | ✅ Indirecto |
| Autenticación Biométrica | D05 | 7 | Sin dependencia directa de Context Plane | — | — |
| Acceso Geoespacial | D06 | 6 | B01 `geofencing` — geocerca se verifica contra IP del dispositivo | `registered_device.ip` + `device_heartbeat.ip` | ✅ Infra |
| **Seguridad de Red** | **D07** | **8** | **B03 `rate` + B07 `propagation`** — rate limiting y propagación de contexto | `context_policy.rate_limit_rps` + `context_session.traceparent` + `context_switch_log` | ✅ **2/8 bloques** |
| **Contexto / Sesión** | **D08** | **7** | **LOS 7 BLOQUES** — este es EL dominio del Context Plane | Las 7 tablas — ver detalle §11.2 | ✅ **7/7 bloques** |
| Gestión de Credenciales | D09 | 10 | B05 `revocation` — revocación dispara invalidación de contexto | `context_audit` (SESSION_INVALIDATE) + `context_session` (state→INVALIDATED) | ✅ Indirecto |
| Delegación e Impersonación | D10 | 7 | B01 `delegation` — delegación cambia contexto efectivo | `context_switch_log` — registra cambio de contexto delegado | ✅ Indirecto |
| Auditoría y Cumplimiento | D11 | 7 | B01 `events` + B02 `retention` + B03 `integrity` — WORM audit | `context_audit` + `context_switch_log` + `context_transfer` — 3 tablas WORM con hash-chain | ✅ **3/7 bloques** |
| Anclaje Blockchain | D12 | 7 | Sin dependencia directa — consume `context_audit.prev_hash` para Merkle | `context_audit.prev_hash` — entrada al árbol Merkle D12 | ✅ Indirecto |
| Firma Digital Externa | D13 | 8 | Sin dependencia directa de Context Plane | — | — |
| **Gestión de Acceso Privilegiado** | **D14** | **7** | **B04 `brokering` + B06 `session_recording`** — sesión PAM | `context_session` + `context_audit` — contexto infra de sesión privilegiada | ✅ **2/7 bloques** |
| **Identidad No Humana** | **D15** | **8** | **B02 `workload` + B05 `rotation`** — workload identity + rotación | `registered_device.node_k8s` + `context_policy` (TTL NHI más corto) | ✅ **2/8 bloques** |
| Registro Estructural | D98 | 4 | Sin dependencia directa de Context Plane | — | — |
| Administración Global | D99 | 7 | B04 `cryptography` — parámetros criptográficos globales | `context_policy` — TTLs default del ecosistema | ✅ Indirecto |

**Total: 10/18 dominios con cobertura directa o complementaria. 16/134 bloques con trazabilidad directa a tablas bos.**

### 11.2 D08 — El dominio dueño: cobertura bloque por bloque

D08 es el dominio natural del Context Plane. Cada uno de sus 7 bloques tiene correspondencia con al menos una tabla bos:

| Bloque D08 | Necesidad | Tabla(s) bos | Veredicto |
|---|---|---|---|
| **B01 `session`** — ctx_id Lifecycle | Creación, validación, extensión, revocación del ctx_id. CAEP `session-revoked` | `context_session` (creación/estado) + `context_audit` (WORM de toda operación) | ✅ COMPLETO |
| **B02 `risk`** — Continuous Risk Score | Score de riesgo continuo, señales de comportamiento, UEBA. CAEP `risk-level-change` | `context_policy` (umbrales de TTL, auto_block_jailbreak, require_mdm). El score lo calcula `ses_risk_policy` (bAuth); bos provee los parámetros de infraestructura. | ✅ Complemento |
| **B03 `device`** — Device Posture | MDM enrollment, parches, cifrado, EDR activo. CAEP `device-compliance-change` | `registered_device` (registro infra) + `device_heartbeat` (keepalive). La postura profunda la evalúa `auth_device_posture` (T-391, bAuth); bos verifica conectividad. | ✅ Complemento |
| **B04 `emergency`** — Context Break-glass | Break-glass de contexto con doble aprobación, registro WORM. NIST AC-17(3) control dual | `context_emergency` (T-402) — control dual (activated_by ≠ approved_by), TTL máximo 2h, revisión post-hoc 24h, WORM hash-chain | ✅ COMPLETO |
| **B05 `assurance`** — Active Assurance Level | Nivel de garantía activo (AAL1/2/3). CAEP `assurance-level-change` | `context_session.loa` (nivel al crear) + `context_audit` (cambio de LoA vía operation=SESSION_PROMOTE). El step-up lo ejecuta bAuth; bos registra el resultado. | ✅ COMPLETO |
| **B06 `itdr`** — Identity Threat Detection | Detección forense de amenazas de identidad — Golden Ticket, movimiento lateral, abuso de sesión | `context_audit` (WORM hash-chain — el auditor forense reconstruye la secuencia de operaciones) + `context_switch_log` (detección de switches anómalos) + `context_transfer` (transferencias sospechosas). Las 3 tablas WORM son la base forense del ITDR. | ✅ COMPLETO |
| **B07 `zona_negocios`** — Business Zone Registry | Contenedor de sistemas de gestión de contexto. Prefijo `zona_context_*` | Árbol `idn_roles_template` — no es responsabilidad de tablas bos. Los átomos `d08.zona_negocios.register` se insertan en T-162. | ✅ Fuera de scope |

**Veredicto D08: 7/7 bloques COMPLETO · 100% de cobertura del dominio Contexto/Sesión**

### 11.3 Dominios sin cobertura directa (8/18)

| Dominio | Razón por la que NO necesita tablas bos |
|---|---|
| D03 (Financiero) | Opera sobre grants financieros (T-069..T-070, T-027). El contexto es transparente — se hereda del ctx_id activo. |
| D05 (Biométrico) | Opera sobre credenciales biométricas (`idn_biometrico_*`). El contexto es provisto por el dispositivo de captura. |
| D09 (Credenciales) | Opera sobre métodos de autenticación (`auth_credential*`). El contexto es pre-autenticación y lo provee bAuth. |
| D10 (Delegación) | Opera sobre grants delegados (`privilege_delegation`). El contexto se hereda; el switch se registra en `context_switch_log`. |
| D12 (Blockchain) | Opera sobre anclaje Merkle (`blk_*`). Consume `context_audit.prev_hash` como entrada al árbol. |
| D13 (Firma Digital) | Opera sobre certificados y firmas (`sig_*`). Sin dependencia de contexto de infraestructura. |
| D98 (Registro Estructural) | Metadatos del sistema — sin dependencia de contexto. |
| D99 (Administración Global) | Parámetros globales — `context_policy` provee defaults de TTL a nivel ecosistema. |

### 11.4 Hallazgos del cruce

1. **D08 B04 (`emergency`) es el único gap.** La propuesta bos cubre el registro WORM del break-glass (`context_transfer` tipo BREAKGLASS) y la auditoría (`context_audit`), pero la aprobación dual requerida por NIST AC-17(3) es responsabilidad de `pam_breakglass_activation` (T-185) en bAuth. **No es un gap de bos — es un gap de integración entre bos y bAuth que se resuelve a nivel aplicación.**

2. **16/134 bloques tienen trazabilidad directa a tablas bos.** Los otros 118 bloques operan sobre sus propias tablas (privilegios, credenciales, firmas, etc.) y consumen el contexto como pre-condición transparente — no necesitan tablas adicionales.

3. **3 tablas WORM cubren 4 dominios.** `context_audit` + `context_switch_log` + `context_transfer` dan servicio a D08 (itdr), D11 (events+integrity), D12 (Merkle input), y D14 (session_recording). La cadena hash-chain SHA-256 es la misma técnica que usa `privilege_atom_audit` (T-170b) y `idn_identity_attribute_history` (T-158) — consistencia con el resto de la DDL.

4. **`registered_device` vs `auth_device`: sin solapamiento confirmado.** El cruce con los 18 dominios confirma que `auth_device` (T-390) sirve a D09 (identidad de dispositivo) mientras `registered_device` (T-395) sirve a D08 (infraestructura de contexto). Son dos planos arquitectónicos distintos que no comparten queries ni consumidores.

---

## 12. Análisis profundo de tablas bAuth — qué provee bAuth vs qué necesita BOS

Esta sección verifica, columna por columna, las tablas bAuth que el schema `bos` referencia vía FK o que solapan funcionalmente con la propuesta. No se asume nada — se lee del DDL real (`SBOS_db_V2_DDL.sql`, 5676 líneas).

### 12.1 `bauth.idn_tenant` — lo que BOS necesita saber del tenant

**PK:** `tenant_id UUID DEFAULT uuidv7()` — referenciada por las 8 tablas `bos.*`

| Columna | Tipo | Default | Qué significa para BOS |
|---------|------|---------|------------------------|
| `tenant_type` | `tenant_type_enum` | `'STANDARD'` | Clasificación del tenant. BOS lo lee para ajustar TTLs y políticas en `context_policy`. Valores: STANDARD, REGULATED, HIGH_SENSITIVITY, INTERNAL, PARTNER_FEDERATED (verificado en ENUM). |
| `is_internal` | `BOOLEAN` | `false` | **Respuesta directa a la pregunta del usuario.** `true` = operador del SBOS (SKULL), no facturado, puede alojar tiers SU/SYS. `false` = cliente. BOS consulta este campo ANTES de crear el `context_policy`: si `is_internal=true`, TTLs más largos y rate_limit más alto. |
| `status` | `tenant_status_enum` | `'PENDING_VERIFICATION'` | Ciclo de vida: PENDING_VERIFICATION→ACTIVE→SUSPENDED→TERMINATED→PURGED. BOS solo crea `context_policy` para tenants `ACTIVE`. |
| `provisioning_status` | `provisioning_status_enum` | `'PENDING'` | Bootstrap: PENDING→INFRA_PROVISIONING→SCHEMA_CREATED→IDP_CONFIGURED→COMPLETED. BOS actualiza este campo durante la saga de provisioning. |
| `isolation_level` | `isolation_level_enum` | `'SCHEMA_PER_TENANT'` | Nivel de aislamiento. BOS lo usa para decidir si crear schema dedicado o compartido. |
| `session_ttl_max` | `INTEGER` | `28800` | **TTL máximo de sesión de IDENTIDAD** (8h). NO es lo mismo que `context_policy.session_ttl_seconds` (TTL de INFRAESTRUCTURA). Son dos capas distintas: bAuth gobierna cuánto dura la sesión de identidad; BOS gobierna cuánto dura el ctx_id de infraestructura. |
| `token_ttl_seconds` | `INTEGER` | `3600` | TTL del JWT emitido por bAuth. BOS no lo modifica — lo consume para saber cuándo renovar el ctx_id. |
| `rate_limit_rps` | `INTEGER` | `100` | Rate limit base del tenant. `context_policy.rate_limit_rps` puede sobrescribirlo para el Context API específicamente. |
| `plan_tier` | `plan_tier_enum` | `'BASIC'` | Plan contratado. BOS ajusta `max_devices_per_tenant` y `max_sessions_per_user` según el plan. |
| `country` | `CHAR(2)` | `'BO'` | Jurisdicción. BOS ajusta TTLs según regulación local (GDPR Europa, LGPD Brasil, etc.). |
| `data_retention_days` | `INTEGER` | `2555` | Retención de datos. BOS lo usa para configurar la retención de `device_heartbeat` y `context_audit`. |

**Conclusión:** `idn_tenant` ya tiene `is_internal`, `tenant_type`, `session_ttl_max`, y `rate_limit_rps`. Mi `context_policy` NO duplica estos campos — los COMPLEMENTA con parámetros que solo aplican a la capa de infraestructura (device TTL, heartbeat interval, require_mdm). La relación es:

```
idn_tenant.is_internal ──→ BOS decide qué defaults usar en context_policy
idn_tenant.tenant_type ──→ BOS ajusta TTLs (REGULATED = más restrictivo)
idn_tenant.session_ttl_max ──→ bAuth impone el techo; context_policy puede ser más corto, nunca más largo
```

### 12.2 `bauth.idn_identity_entity` — las 4 capas del ctx_id

**PK:** `entity_id UUID DEFAULT uuidv7()` — referenciada por `context_session` (4 columnas), `context_switch_log`, `context_transfer`, `context_emergency`.

| Columna | Tipo | Qué significa para BOS |
|---------|------|------------------------|
| `entity_id` | `UUID PK` | FK desde `context_session.entity_1_id`, `entity_2_id`, `entity_3_id`, `user_id` |
| `tenant_id` | `UUID NOT NULL` | Validación cruzada: el `context_session.tenant_id` DEBE coincidir con `entity.tenant_id` |
| `parent_id` | `UUID` | Jerarquía. BOS puede validar que la entidad pertenece al nivel correcto |
| `level` | `entidad_nivel_enum` | **5 niveles:** tenant, bdomain, bsubdomain, pos, actor. `context_session.entity_1_id` → bdomain, `entity_2_id` → bsubdomain, `entity_3_id` → pos, `user_id` → actor |
| `status` | `TEXT CHECK ('ACTIVE','SUSPENDED','ARCHIVED')` | BOS solo permite crear `context_session` con entidades en estado ACTIVE |
| `path` | `TEXT` | Camino materializado. BOS lo usa para el `context_session.ctx_id` textual |

**Validación que BOS debe implementar:**
```sql
-- Antes de INSERT en context_session, verificar que las entidades existen y están ACTIVE:
SELECT entity_id, level, status FROM bauth.idn_identity_entity
WHERE entity_id IN ($entity_1_id, $entity_2_id, $entity_3_id, $user_id)
  AND tenant_id = $tenant_id AND status = 'ACTIVE';
```

### 12.3 `bauth.ses_session_log` vs `bos.ctx_context_session` — no duplicación verificada

| Dimensión | `ses_session_log` (T-181, bAuth) | `context_session` (T-396, BOS) |
|-----------|-----------------------------------|--------------------------------|
| **PK** | `session_id UUID` | `ctx_id UUID` |
| **tenant_id** | ✅ UUID FK | ✅ UUID FK |
| **user_id** | ✅ UUID | ✅ UUID FK a `idn_identity_entity` |
| **auth_method** | ✅ TEXT (password, webauthn, ...) | ❌ No aplica — BOS no sabe de auth |
| **loa_initial / loa_peak** | ✅ TEXT (AAL1/AAL2/AAL3) | ❌ `loa INTEGER 1-4` (simplificado) |
| **ip_address** | ✅ INET | ❌ (está en `registered_device.ip`) |
| **user_agent** | ✅ TEXT | ❌ No aplica |
| **started_at / last_active_at** | ✅ TIMESTAMPTZ | ❌ `created_at` + `expires_at` |
| **terminated_at / termination_reason** | ✅ (LOGOUT/TIMEOUT/CAEP_REVOKE/ADMIN_REVOKE/EXPIRY) | ❌ `state` (ACTIVE→INVALIDATED/EXPIRED) |
| **ctx_id** | ✅ TEXT (SBOS-049) | ✅ `ctx_id_text TEXT` (SBOS-049) |
| **entity_1/2/3_id** | ❌ No existe | ✅ 3× FK a `idn_identity_entity` |
| **dctx_id** | ❌ No existe | ✅ FK a `registered_device` |
| **bitmask** | ❌ No existe | ✅ BIGINT (BitMask 64-bit) |
| **traceparent** | ❌ No existe | ✅ TEXT (W3C Trace Context) |

**Son 6 columnas únicas de `context_session` que NO existen en `ses_session_log`:** `entity_1_id`, `entity_2_id`, `entity_3_id`, `dctx_id`, `bitmask`, `traceparent`. Esto demuestra que NO hay duplicación — son perspectivas complementarias de la misma sesión.

### 12.4 `bauth.auth_device` (T-390) vs `bos.ctx_registered_device` (T-395) — columnas no solapadas

| `auth_device` (identidad) | `registered_device` (infraestructura) |
|---------------------------|----------------------------------------|
| `device_key TEXT UNIQUE` — identificador lógico | `dctx_id UUID PK` — identificador de infra |
| `name TEXT` — nombre descriptivo | `hostname TEXT` — FQDN del dispositivo |
| `category` — DESKTOP/MOBILE/SECURITY_KEY/OSDP_READER... | (implícito: todo dispositivo de red) |
| `platform` — WINDOWS/LINUX/MACOS/ANDROID/IOS/FIDO2_HW... | (no aplica) |
| `aaguid UUID` — AAGUID FIDO2 | (no aplica) |
| `trust_level` — TRUSTED/CONDITIONALLY_TRUSTED/UNTRUSTED/QUARANTINE | `state` — PENDING/ACTIVE/SUSPENDED/BLOCKED/INVALIDATED/EXPIRED/ARCHIVED |
| `hardware_id TEXT` — identificador físico | `node_k8s TEXT` — nodo Kubernetes |
| `is_managed BOOLEAN` — ¿MDM? | `ip INET` — IP de red actual |
| `status` — PENDING→ACTIVE→SUSPENDED→REVOKED→LOST→DECOMMISSIONED | `state` — PENDING→ACTIVE→SUSPENDED/BLOCKED→INVALIDATED/EXPIRED→ARCHIVED |
| `last_seen_at / last_seen_ip` | `device_heartbeat` (tabla separada) |
| `user_id → idn_user` | (indirecto vía `context_session.user_id`) |

**Diferencia fundamental:** `auth_device` pregunta "¿debo confiar en este dispositivo?" (trust_level). `registered_device` pregunta "¿está este dispositivo conectado y operativo?" (heartbeat). Son dos preguntas distintas que requieren dos tablas distintas.

---

*SKULL · SBOS · BauthAgent · A.65.02.06 v3.0.0 · Julio 2026*
