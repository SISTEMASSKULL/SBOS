# Anexo A.14 — Propuesta DDL: Tablas Faltantes del Schema `bos`
## Análisis de gaps entre el DDL actual, los manuales y el código Go — 5 tablas propuestas

**Versión:** 1.0.0 — PROPUESTA PENDIENTE DE APROBACIÓN HITL
**Fecha:** 2026-07-30
**Autor:** bos-developer — SBOS
**Estado:** 🔴 BORRADOR — no commitear sin aprobación del humano
**Referencia:** `1.01_MANUAL-IAM-INSTALLER.md §3.7` · `3.01_MANUAL-SERVER-FICHAS.md` · `2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md` · `DDLs/bos_01__control_plane.sql`

---

## 1. Contexto y metodología

### 1.1 Punto de partida

El archivo `DDLs/bos_01__control_plane.sql` contiene actualmente **8 tablas** que cubren
el Motor ④ Context Plane completo (T-395..T-402):

| Tabla actual | Motor | Estado |
|---|---|---|
| `bos.ctx_registered_device` (T-395) | ④ Context Plane | ✅ completo |
| `bos.ctx_context_session` (T-396) | ④ Context Plane | ✅ completo |
| `bos.ctx_context_audit` (T-397) 🔒 | ④ Context Plane | ✅ completo |
| `bos.ctx_context_switch_log` (T-398) 🔒 | ④ Context Plane | ✅ completo |
| `bos.ctx_context_policy` (T-399) | ④ Context Plane | ✅ completo |
| `bos.ctx_device_heartbeat` (T-400) | ④ Context Plane | ✅ completo |
| `bos.ctx_context_transfer` (T-401) 🔒 | ④ Context Plane | ✅ completo |
| `bos.ctx_context_emergency` (T-402) 🔒 | ④ Context Plane | ✅ completo |

### 1.2 Gap identificado

El manual `1.01_MANUAL-IAM-INSTALLER.md §3.7` declara que el schema `bos` debe contener
**7 tablas** cubriendo todos los motores del BOS. El análisis cruzado de manuales y código
Go revela que los **Motores ② y ③** no tienen persistencia en BD:

- **Motor ③ Server FICHAS** — estado y eventos de las fichas viven en `.sbos_state.json`
  (file-lock, no consultable por SQL, no distribuido, no forense).
- **Motor ② SO Observable** — las métricas de capacidad (30+ cada 60s) no tienen tabla.
- **Motor ① IAM Installer** — los eventos de bootstrap (6 capas, verificaciones C-01..C-09)
  no tienen registro persistente en BD.

### 1.3 Fuentes cruzadas

| Tabla propuesta | Fuente en manual | Fuente en código Go |
|---|---|---|
| `bos.ficha_state` | `1.01 §3.7`, `3.01 §3`, `0.00 R3` | `internal/state/types.go:Ficha` |
| `bos.ficha_event` | `0.00 R4`, `3.01`, `2.04` | `internal/ficha/lifecycle.go` |
| `bos.bootstrap_event` | `1.01 §3.7`, `1.01 §4`, `1.02` | `internal/bootstrap/` |
| `bos.cap_snapshot` | `2.02 M5.1`, `0.00 R5`, `1.01 §3.7` | `internal/capacity/` (sin código) |
| `bos.cap_estimate` | `2.02 M5.3`, `1.01 §3.7` | `internal/capacity/` (sin código) |

---

## 2. Propuesta T-NEW-1: `bos.ficha_state`

### 2.1 Propósito

Tabla de estado actual de cada ficha desplegada. Es la fuente de verdad en BD de la
máquina de 18 estados (ADR-021). Reemplaza el rol que hoy cumple `.sbos_state.json`
para consultas, auditoría y reconciliación multi-nodo.

**Por qué BD y no solo JSON:** el JSON funciona en un solo nodo. Cuando BOS tenga que
gestionar múltiples servidores, la consulta de estado de 112+ fichas requiere SQL.
Además, el JSON no es consultable para alertas, dashboards ni auditoría forense.

### 2.2 DDL propuesto

```sql
-- =============================================================================
-- T-NEW-1 — bos.ficha_state
-- Estado actual de cada ficha desplegada (18 estados ADR-021).
-- Fuente de verdad para reconciliación, alertas y Dashboard.
-- ADR-021 · SBOS-BOS-FICHA-001 · ISO 27001:2022 A.8.9
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ficha_state (
    ficha_id      UUID        NOT NULL DEFAULT uuidv7(),
    ficha_name    TEXT        NOT NULL,
    server_id     TEXT        NOT NULL,
    version       TEXT        NOT NULL DEFAULT '0.0.0',
    state         TEXT        NOT NULL DEFAULT 'PENDIENTE',
    category      INTEGER     NOT NULL DEFAULT 1,
    criticality   BOOLEAN     NOT NULL DEFAULT false,
    backend       TEXT        NOT NULL DEFAULT 'bash',
    installed_at  TIMESTAMPTZ NULL,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    health_status TEXT        NULL,
    hashes        JSONB       NOT NULL DEFAULT '{}',
    tenant_id     UUID        NULL REFERENCES bauth.idn_tenant(tenant_id),
    ctx_id        TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT fs_pkey PRIMARY KEY (ficha_id),
    CONSTRAINT uq_fs_name_tenant UNIQUE (ficha_name, tenant_id),
    CONSTRAINT chk_fs_state CHECK (state IN (
        'PENDIENTE','LISTA','INSTALANDO','INSTALADA',
        'ACTUALIZACION_DISPONIBLE','ACTUALIZACION_APROBADA','ACTUALIZANDO',
        'DEGRADADA','ERROR_FISICO','ERROR_LOGICO','REPARANDO',
        'ERROR_NO_CORREGIBLE','FALLA_INSTALACION','FALLA_ACTUALIZACION',
        'ROLLBACK','LIMPIEZA','PAUSADA','DESINSTALADA'
    )),
    CONSTRAINT chk_fs_backend CHECK (backend IN ('bash','k8s','binary','python')),
    CONSTRAINT chk_fs_category CHECK (category BETWEEN 1 AND 5),
    CONSTRAINT chk_fs_server CHECK (length(server_id) > 0)
);

CREATE INDEX IF NOT EXISTS idx_fs_state      ON bos.ficha_state (state);
CREATE INDEX IF NOT EXISTS idx_fs_tenant     ON bos.ficha_state (tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fs_server     ON bos.ficha_state (server_id);
CREATE INDEX IF NOT EXISTS idx_fs_criticidad ON bos.ficha_state (criticality) WHERE criticality = true;
CREATE INDEX IF NOT EXISTS idx_fs_updated    ON bos.ficha_state (updated_at DESC);
```

### 2.3 Correspondencia con struct Go

| Columna SQL | Campo Go (`state/types.go:Ficha`) | Notas |
|---|---|---|
| `ficha_name` | `Name` | identificador único de la ficha |
| `server_id` | `Server` | S01, S-HOST, S03... |
| `version` | `Version` | versión del manifest.yml |
| `state` | `State` (FichaState) | 18 valores del ENUM Go |
| `category` | `Category` | clasificación 1-5 |
| `criticality` | `Criticality` | bool |
| `backend` | `Backend` | bash/k8s/binary |
| `installed_at` | `InstalledAt` | nullable |
| `updated_at` | `UpdatedAt` | timestamp |
| `health_status` | `HealthStatus` | último resultado del probe |
| `hashes` | `Hashes map[string]string` | SHA-256 por archivo |
| `tenant_id` | *(no existe)* | **nuevo** — fichas del sistema = NULL |

### 2.4 Preguntas abiertas para HITL

- **Q1:** ¿`tenant_id NULL` para fichas del sistema (postgresql, redis, kong) y UUID para fichas de aplicación de un tenant específico? ¿O todas las fichas son del sistema y no tienen tenant?
- **Q2:** ¿Se necesita `namespace_k8s TEXT` para poder consultar fichas por namespace?

---

## 3. Propuesta T-NEW-2: `bos.ficha_event` 🔒 WORM

### 3.1 Propósito

Historial inmutable (append-only) de toda operación sobre una ficha: install, update,
repair, remove, health check, drift detection. Es la evidencia forense ISO 27001 A.8.15
exigida por el manual `0.00 R4`:

> *"Cada discrepancia queda registrada en `bos.ficha_event` con `ctx_id` — evidencia ISO 27001 A.8.15."*

Hoy esta evidencia se escribe en archivos de log (`/var/log/bos/fichas/`), que no son
consultables por SQL, no tienen hash-chain WORM y pueden ser truncados.

### 3.2 DDL propuesto

```sql
-- =============================================================================
-- T-NEW-2 — bos.ficha_event 🔒 WORM
-- Historial inmutable de toda operación sobre una ficha.
-- Hash-chain SHA-256. REVOKE UPDATE/DELETE.
-- ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-12 · ADR-021 · 0.00 R4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ficha_event (
    event_id    UUID        NOT NULL DEFAULT uuidv7(),
    ficha_id    UUID        NOT NULL REFERENCES bos.ficha_state(ficha_id),
    ficha_name  TEXT        NOT NULL,
    tenant_id   UUID        NULL REFERENCES bauth.idn_tenant(tenant_id),
    operation   TEXT        NOT NULL,
    from_state  TEXT        NULL,
    to_state    TEXT        NOT NULL,
    result      TEXT        NOT NULL DEFAULT 'OK',
    duration_ms INTEGER     NULL,
    details     JSONB       NOT NULL DEFAULT '{}',
    saga_id     UUID        NULL,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash   TEXT        NULL,
    ctx_id      TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT fe_pkey PRIMARY KEY (event_id),
    CONSTRAINT chk_fe_operation CHECK (operation IN (
        'INSTALL','UPDATE','REPAIR','REMOVE',
        'HEALTH_CHECK','DRIFT_DETECTED','DRIFT_RESOLVED',
        'SCALE','PAUSE','RESUME',
        'ROLLBACK','CLEANUP','STATE_TRANSITION'
    )),
    CONSTRAINT chk_fe_result CHECK (result IN ('OK','FAIL','PARTIAL','SKIPPED')),
    CONSTRAINT chk_fe_to_state CHECK (to_state IN (
        'PENDIENTE','LISTA','INSTALANDO','INSTALADA',
        'ACTUALIZACION_DISPONIBLE','ACTUALIZACION_APROBADA','ACTUALIZANDO',
        'DEGRADADA','ERROR_FISICO','ERROR_LOGICO','REPARANDO',
        'ERROR_NO_CORREGIBLE','FALLA_INSTALACION','FALLA_ACTUALIZACION',
        'ROLLBACK','LIMPIEZA','PAUSADA','DESINSTALADA'
    ))
);

REVOKE UPDATE, DELETE ON bos.ficha_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_fe_ficha      ON bos.ficha_event (ficha_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fe_tenant_op  ON bos.ficha_event (tenant_id, operation, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fe_saga       ON bos.ficha_event (saga_id) WHERE saga_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fe_executed   ON bos.ficha_event (executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fe_result     ON bos.ficha_event (result) WHERE result = 'FAIL';
```

### 3.3 Campos clave explicados

| Campo | Por qué importa |
|---|---|
| `ficha_name` | Denormalizado para queries sin JOIN cuando `ficha_state` se archiva |
| `from_state → to_state` | Cada transición de la máquina de 18 estados queda registrada |
| `details JSONB` | Contiene: steps completados, logs de error, tiempo por step, causa de falla |
| `saga_id` | Correlaciona todos los eventos de una misma ejecución de saga |
| `prev_hash` | SHA-256 de la fila anterior — cadena WORM verificable |

### 3.4 Preguntas abiertas para HITL

- **Q3:** ¿`from_state` necesita CHECK constraint también, o NULL es válido (primera instalación)?
- **Q4:** ¿Se necesita `actor_id UUID` para saber si fue BOS automático vs comando manual del operador?

---

## 4. Propuesta T-NEW-3: `bos.bootstrap_event` 🔒 WORM

### 4.1 Propósito

Registro forense del proceso de bootstrap day-0 (6 capas progresivas, ADR-040).
Cada verificación C-01..C-09 y cada paso de instalación de las capas 0-5 queda
registrado en BD con hash-chain.

**Caso de uso crítico:** si el bootstrap falla en Capa 3 (Kong) a las 3 AM, el
operador puede consultar `SELECT * FROM bos.bootstrap_event WHERE layer = 3 AND result = 'FAIL'`
y ver exactamente qué falló, con qué mensaje, en cuánto tiempo. Hoy esa información
está en archivos de log dispersos.

### 4.2 DDL propuesto

```sql
-- =============================================================================
-- T-NEW-3 — bos.bootstrap_event 🔒 WORM
-- Registro de eventos de bootstrap (6 capas ADR-040). WORM. Hash-chain SHA-256.
-- ISO 27001:2022 A.8.15 · ADR-040 · 1.01 §4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.bootstrap_event (
    event_id          UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id         UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    layer             INTEGER     NOT NULL,
    ficha_name        TEXT        NOT NULL,
    step              TEXT        NOT NULL,
    state             TEXT        NOT NULL,
    verification_code TEXT        NULL,
    result            TEXT        NOT NULL DEFAULT 'OK',
    details           JSONB       NOT NULL DEFAULT '{}',
    duration_ms       INTEGER     NULL,
    executed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash         TEXT        NULL,
    ctx_id            TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT be_pkey PRIMARY KEY (event_id),
    CONSTRAINT chk_be_layer CHECK (layer BETWEEN 0 AND 5),
    CONSTRAINT chk_be_state CHECK (state IN (
        'STARTED','COMPLETED','FAILED','SKIPPED','RETRYING'
    )),
    CONSTRAINT chk_be_result CHECK (result IN ('OK','FAIL','PARTIAL','SKIPPED')),
    CONSTRAINT chk_be_vcode CHECK (
        verification_code IS NULL OR
        verification_code ~ '^C-[0-9]{2}$'
    )
);

REVOKE UPDATE, DELETE ON bos.bootstrap_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_be_tenant_layer ON bos.bootstrap_event (tenant_id, layer, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_be_ficha        ON bos.bootstrap_event (ficha_name, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_be_vcode        ON bos.bootstrap_event (verification_code) WHERE verification_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_be_failures     ON bos.bootstrap_event (result, layer) WHERE result = 'FAIL';
CREATE INDEX IF NOT EXISTS idx_be_executed     ON bos.bootstrap_event (executed_at DESC);
```

### 4.3 Correspondencia con las 6 capas (ADR-040)

| `layer` | Nombre | Fichas principales | Verificación |
|:---:|---|---|:---:|
| 0 | S-HOST OS | `bos-preflight`, `sbos-bootstrap-os` | C-01 |
| 1 | S-HOST K8s mínimo | `sbos-bootstrap-k8s`, `sbos-bootstrap-cni`, `sbos-bootstrap-storage` | C-02, C-03 |
| 2 | S01 Datos | `postgresql`, `redis`, `minio` | C-04, C-05 |
| 3 | S02-S03 Identidad+Gateway | `vault`, `keycloak`, `kong` | C-06, C-07, C-08 |
| 4 | S06 Notificaciones | `sbos-notifier` | C-09 |
| 5 | S-HOST Hardening | `sbos-bootstrap-hard`, pasada 2 de datos e identidad | — |

### 4.4 Preguntas abiertas para HITL

- **Q5:** ¿`tenant_id NOT NULL` es correcto para las capas 0-1 (son del sistema, no de un tenant)?
  Alternativa: `tenant_id UUID NULL` con NULL para capas 0-2 (sistema) y UUID para capas 3-5 (tenant-scoped).
- **Q6:** ¿Se necesita una columna `bootstrap_run_id UUID` para agrupar todos los eventos de un mismo intento de bootstrap end-to-end?

---

## 5. Propuesta T-NEW-4: `bos.cap_snapshot`

### 5.1 Propósito

Almacena las instantáneas periódicas (~30 métricas, cada 60s) que recolecta el Motor
Observación (M5.1) del Autómata de Capacidad (SBOS-BOS-CAP-001). Sin esta tabla, el
Motor Proyección (M5.2) no tiene datos históricos para hacer regresión lineal a 7/30/90 días,
y el Motor Acción (M5.4) no puede detectar tendencias de saturación.

**Retención sugerida:** 90 días. Filas más antiguas → eliminar con job o particionar por mes.

### 5.2 DDL propuesto

```sql
-- =============================================================================
-- T-NEW-4 — bos.cap_snapshot
-- Instantáneas periódicas de ~30 métricas del sistema (Motor Observación M5.1).
-- ~60s entre snapshots. Retención 90 días.
-- SBOS-BOS-CAP-001 · 2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md M5.1
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_snapshot (
    snapshot_id           UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id             UUID         NULL REFERENCES bauth.idn_tenant(tenant_id),
    captured_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- ── Context Plane ────────────────────────────────────────────────
    ctx_sessions_active   INTEGER      NULL,
    ctx_devices_active    INTEGER      NULL,

    -- ── Redis (cache + ctx DB1) ──────────────────────────────────────
    redis_memory_pct      NUMERIC(5,2) NULL,
    redis_keys_count      BIGINT       NULL,
    redis_ops_per_sec     NUMERIC(10,2) NULL,

    -- ── PostgreSQL ───────────────────────────────────────────────────
    pg_connections_active INTEGER      NULL,
    pg_connections_max    INTEGER      NULL,
    pg_db_size_bytes      BIGINT       NULL,
    pg_tps                NUMERIC(10,2) NULL,

    -- ── Kong (API Gateway) ───────────────────────────────────────────
    kong_rps              NUMERIC(10,2) NULL,
    kong_latency_p99_ms   NUMERIC(10,2) NULL,
    kong_error_rate_pct   NUMERIC(5,2)  NULL,

    -- ── bAuth ────────────────────────────────────────────────────────
    bauth_cache_miss_pct  NUMERIC(5,2) NULL,
    bauth_token_ops_sec   NUMERIC(10,2) NULL,

    -- ── bKernel (WAL CDC) ────────────────────────────────────────────
    bkernel_lag_ms        NUMERIC(10,2) NULL,
    bkernel_events_sec    NUMERIC(10,2) NULL,

    -- ── Kubernetes ───────────────────────────────────────────────────
    k8s_nodes_ready       INTEGER      NULL,
    k8s_nodes_total       INTEGER      NULL,
    k8s_pods_running      INTEGER      NULL,
    k8s_pods_total        INTEGER      NULL,
    k8s_cpu_used_pct      NUMERIC(5,2) NULL,
    k8s_mem_used_pct      NUMERIC(5,2) NULL,

    -- ── Host Ubuntu ──────────────────────────────────────────────────
    host_cpu_pct          NUMERIC(5,2) NULL,
    host_mem_pct          NUMERIC(5,2) NULL,
    host_disk_pct         NUMERIC(5,2) NULL,
    host_load_avg_1m      NUMERIC(6,2) NULL,

    -- ── Fichas ───────────────────────────────────────────────────────
    fichas_healthy        INTEGER      NULL,
    fichas_degraded       INTEGER      NULL,
    fichas_error          INTEGER      NULL,
    fichas_total          INTEGER      NULL,

    -- ── Extensible ───────────────────────────────────────────────────
    extras                JSONB        NOT NULL DEFAULT '{}',

    CONSTRAINT cs_pkey PRIMARY KEY (snapshot_id),
    CONSTRAINT chk_cs_pcts CHECK (
        (redis_memory_pct IS NULL OR redis_memory_pct BETWEEN 0 AND 100) AND
        (k8s_cpu_used_pct IS NULL OR k8s_cpu_used_pct BETWEEN 0 AND 100) AND
        (host_cpu_pct IS NULL OR host_cpu_pct BETWEEN 0 AND 100) AND
        (host_mem_pct IS NULL OR host_mem_pct BETWEEN 0 AND 100) AND
        (host_disk_pct IS NULL OR host_disk_pct BETWEEN 0 AND 100)
    )
);

CREATE INDEX IF NOT EXISTS idx_cs_tenant_time  ON bos.cap_snapshot (tenant_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_captured     ON bos.cap_snapshot (captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_degraded     ON bos.cap_snapshot (fichas_degraded, captured_at DESC)
    WHERE fichas_degraded > 0;
```

### 5.3 Notas de diseño

| Decisión | Razón |
|---|---|
| Todas las métricas `NULL`able | Una fuente puede no estar disponible (Redis down = métrica NULL, no falla el snapshot) |
| `tenant_id NULL` | Los snapshots globales (host, K8s) son del sistema. Los de bAuth/ctx son por tenant |
| `extras JSONB` | Métricas futuras sin migración de esquema |
| Sin `ctx_id` | Es metadata de sistema, no una operación de usuario |

### 5.4 Preguntas abiertas para HITL

- **Q7:** ¿Retención de 90 días manejada por un job de limpieza en BOS, o por particionado por mes (`PARTITION BY RANGE (captured_at)`)?
- **Q8:** ¿`tenant_id NULL` para métricas globales es suficiente, o se necesita una columna `scope TEXT` con valores `GLOBAL|TENANT|FICHA`?

---

## 6. Propuesta T-NEW-5: `bos.cap_estimate`

### 6.1 Propósito

Almacena la configuración declarativa de capacidad por tenant: umbrales de alerta,
modo de política (autónomo vs recomendar vs bloquear vs emergencia) y parámetros
para el Motor Proyección (M5.2). Es el equivalente en BD del YAML declarativo del
Motor Políticas (M5.3).

**Relación con `bos.ctx_context_policy` (T-399):** son tablas complementarias.
`ctx_context_policy` almacena TTL y seguridad del Context Plane. `cap_estimate`
almacena umbrales de capacidad de recursos del sistema. Un tenant tiene una fila
en cada una.

### 6.2 DDL propuesto

```sql
-- =============================================================================
-- T-NEW-5 — bos.cap_estimate
-- Políticas de capacidad declaradas por tenant (Motor Políticas M5.3).
-- SBOS-BOS-CAP-001 · 2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md M5.3
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_estimate (
    estimate_id              UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id                UUID         NOT NULL REFERENCES bauth.idn_tenant(tenant_id),

    -- ── Modo de política ─────────────────────────────────────────────
    policy_mode              TEXT         NOT NULL DEFAULT 'recommend',

    -- ── Umbrales de recursos del sistema (% antes de acción) ─────────
    cpu_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    mem_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 85.0,
    disk_limit_pct           NUMERIC(5,2) NOT NULL DEFAULT 90.0,
    redis_mem_limit_pct      NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    pg_conn_limit_pct        NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    kong_rps_limit           INTEGER      NOT NULL DEFAULT 10000,
    ctx_sessions_max         INTEGER      NOT NULL DEFAULT 50000,
    pg_db_size_limit_bytes   BIGINT       NOT NULL DEFAULT 107374182400, -- 100 GiB

    -- ── Motor Proyección (M5.2) ───────────────────────────────────────
    projection_horizon_days  INTEGER      NOT NULL DEFAULT 30,
    projection_confidence    NUMERIC(4,3) NOT NULL DEFAULT 0.95,

    -- ── Notificaciones ───────────────────────────────────────────────
    alert_webhook_url        TEXT         NULL,
    alert_email              TEXT         NULL,

    -- ── Auditoría ────────────────────────────────────────────────────
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ctx_id                   TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT ce_pkey     PRIMARY KEY (estimate_id),
    CONSTRAINT uq_ce_tenant UNIQUE (tenant_id),
    CONSTRAINT chk_ce_mode CHECK (policy_mode IN (
        'autonomous','recommend','block_and_alert','emergency'
    )),
    CONSTRAINT chk_ce_pcts CHECK (
        cpu_limit_pct BETWEEN 1 AND 100 AND
        mem_limit_pct BETWEEN 1 AND 100 AND
        disk_limit_pct BETWEEN 1 AND 100 AND
        redis_mem_limit_pct BETWEEN 1 AND 100 AND
        pg_conn_limit_pct BETWEEN 1 AND 100
    ),
    CONSTRAINT chk_ce_rps CHECK (kong_rps_limit > 0),
    CONSTRAINT chk_ce_sessions CHECK (ctx_sessions_max > 0),
    CONSTRAINT chk_ce_horizon CHECK (projection_horizon_days BETWEEN 1 AND 365),
    CONSTRAINT chk_ce_confidence CHECK (projection_confidence BETWEEN 0.5 AND 0.999)
);

CREATE INDEX IF NOT EXISTS idx_ce_tenant ON bos.cap_estimate (tenant_id);
CREATE INDEX IF NOT EXISTS idx_ce_mode   ON bos.cap_estimate (policy_mode);
```

### 6.3 Modos de política (M5.3)

| `policy_mode` | Comportamiento | Cuándo usar |
|---|---|---|
| `autonomous` | BOS actúa solo: escala, reinicia, redistribuye | Ambientes maduros, confianza total en BOS |
| `recommend` | BOS genera recomendación → operador aprueba (HITL) | **Default** — control humano |
| `block_and_alert` | BOS bloquea admisión de nuevas sesiones + alerta | Saturación inminente |
| `emergency` | BOS activa protocolo de emergencia, notifica cadena completa | Sistemas críticos |

### 6.4 Preguntas abiertas para HITL

- **Q9:** ¿Se necesita una fila DEFAULT para el sistema (`tenant_id = NULL`) que sirva como
  política base cuando un tenant no tiene `cap_estimate`?
- **Q10:** ¿`alert_email` debe validarse con CHECK o se deja TEXT libre?

---

## 7. Decisión de diseño pendiente — T-396 entity_1_id vs empresa_id

### 7.1 El conflicto

La tabla T-396 (`bos.ctx_context_session`) en el DDL actual usa:
```sql
entity_1_id UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)  -- empresa/dominio
entity_2_id UUID NULL REFERENCES bauth.idn_identity_entity(entity_id)       -- sucursal
entity_3_id TEXT NULL                                                         -- pos_logico
```

El código Go (legacy) usaba:
```go
EmpresaID  string  // TEXT — slug o nombre libre
SucursalID string  // TEXT — slug o nombre libre
PosLogico  string  // TEXT
```

### 7.2 Las dos opciones

**Opción A — Mantener UUID FK (como está el DDL actual):**

- `entity_1_id` FK → `bauth.idn_identity_entity`: empresa/dominio como entidad bAuth registrada
- `entity_2_id` FK → `bauth.idn_identity_entity`: sucursal como entidad bAuth registrada
- **Ventaja:** integridad referencial fuerte, consistente con el modelo de identidad bAuth
- **Restricción:** empresa y sucursal deben existir en bAuth antes de crear la sesión; BOS no puede crear contextos de infraestructura sin que bAuth haya registrado las entidades

**Opción B — Cambiar a TEXT operativo:**

- `empresa_id TEXT NOT NULL`: slug/nombre de la empresa (ej: `"skull-corp"`)
- `sucursal_id TEXT NOT NULL`: slug/nombre de la sucursal (ej: `"bogota-norte"`)
- **Ventaja:** BOS puede operar de forma autónoma en bootstrapping (Capa 0-2) sin depender de bAuth
- **Restricción:** pierde integridad referencial; empresa/sucursal no verificadas contra el modelo de identidad

### 7.3 Recomendación técnica

> **Para el bootstrapping day-0 (Motor ①)**, la empresa y la sucursal aún no existen
> como entidades bAuth (Keycloak se instala en Capa 3). Si usamos UUID FK, BOS no puede
> crear contextos de infraestructura durante las Capas 0-2.
>
> **Propuesta:** columna `entity_1_id UUID NULL` + columna `empresa_slug TEXT NOT NULL`.
> En Capas 0-2: `entity_1_id = NULL`, `empresa_slug = 'system'`.
> Post-Capa 3: `entity_1_id = <uuid_de_bauth>`, `empresa_slug = <slug_real>`.

**⬛ Decisión requerida (HITL Q11):** ¿Opción A, B, o la híbrida propuesta?

---

## 8. Resumen — cuadro comparativo final

### 8.1 Tablas propuestas vs tablas actuales

| # | Tabla | Motor | WORM | FKs externas | Estado actual |
|:---:|---|---|:---:|---|---|
| T-395 | `bos.ctx_registered_device` | ④ Context | — | `bauth.idn_tenant` | ✅ en DDL |
| T-396 | `bos.ctx_context_session` | ④ Context | — | `bauth.idn_tenant` + `bauth.idn_identity_entity` | ✅ en DDL (Q11 pendiente) |
| T-397 | `bos.ctx_context_audit` | ④ Context | 🔒 | `bauth.idn_tenant` + `bauth.idn_identity_entity` | ✅ en DDL |
| T-398 | `bos.ctx_context_switch_log` | ④ Context | 🔒 | `bauth.idn_tenant` + `bauth.idn_identity_entity` | ✅ en DDL |
| T-399 | `bos.ctx_context_policy` | ④ Context | — | `bauth.idn_tenant` | ✅ en DDL |
| T-400 | `bos.ctx_device_heartbeat` | ④ Context | — | `bauth.idn_tenant` | ✅ en DDL |
| T-401 | `bos.ctx_context_transfer` | ④ Context | 🔒 | `bauth.idn_tenant` + `bauth.idn_identity_entity` | ✅ en DDL |
| T-402 | `bos.ctx_context_emergency` | ④ Context | 🔒 | `bauth.idn_tenant` + `bauth.idn_identity_entity` | ✅ en DDL |
| T-NEW-1 | `bos.ficha_state` | ③ Fichas | — | `bauth.idn_tenant` (opcional) | ❌ **PROPUESTA** |
| T-NEW-2 | `bos.ficha_event` | ③ Fichas | 🔒 | `bauth.idn_tenant` (opcional) | ❌ **PROPUESTA** |
| T-NEW-3 | `bos.bootstrap_event` | ① Installer | 🔒 | `bauth.idn_tenant` | ❌ **PROPUESTA** |
| T-NEW-4 | `bos.cap_snapshot` | ② Observable | — | `bauth.idn_tenant` (opcional) | ❌ **PROPUESTA** |
| T-NEW-5 | `bos.cap_estimate` | ② Observable | — | `bauth.idn_tenant` | ❌ **PROPUESTA** |

**Total propuesto: 13 tablas** (8 actuales + 5 nuevas)

### 8.2 Preguntas HITL abiertas (resumen)

| # | Pregunta | Tabla | Decisión requerida |
|:---:|---|---|---|
| Q1 | ¿`tenant_id NULL` para fichas del sistema? | `ficha_state` | Null/UUID |
| Q2 | ¿Agregar `namespace_k8s TEXT`? | `ficha_state` | Sí/No |
| Q3 | ¿CHECK en `from_state` o NULL permitido? | `ficha_event` | Con/Sin CHECK |
| Q4 | ¿Columna `actor_id UUID`? | `ficha_event` | Sí/No |
| Q5 | ¿`tenant_id NOT NULL` en Capas 0-2? | `bootstrap_event` | NULL/NOT NULL |
| Q6 | ¿Columna `bootstrap_run_id UUID`? | `bootstrap_event` | Sí/No |
| Q7 | ¿Retención 90 días por job o por partición? | `cap_snapshot` | Job/Partición |
| Q8 | ¿Columna `scope TEXT` (GLOBAL/TENANT/FICHA)? | `cap_snapshot` | Sí/No |
| Q9 | ¿Fila DEFAULT del sistema sin tenant? | `cap_estimate` | Sí/No |
| Q10 | ¿Validar `alert_email` con CHECK? | `cap_estimate` | Sí/No |
| Q11 | ¿entity_1_id UUID, empresa_slug TEXT, o híbrido? | `ctx_context_session` | A/B/Híbrido |

---

## 9. Orden de carga recomendado

Una vez aprobado, estas tablas se agregan al archivo `DDLs/bos_01__control_plane.sql`
en este orden (respetando las FKs):

```
1. bos.ficha_state     (no depende de otras tablas bos.*)
2. bos.ficha_event     (FK → bos.ficha_state)
3. bos.bootstrap_event (FK → bauth.idn_tenant)
4. bos.cap_snapshot    (FK → bauth.idn_tenant, opcional)
5. bos.cap_estimate    (FK → bauth.idn_tenant)
```

Las 5 tablas nuevas van DESPUÉS de las 8 existentes en el archivo, ya que algunas de
las existentes (T-395, T-396) son potencialmente referenciadas por `ficha_event` vía `ctx_id`.

---

*SKULL · SBOS · BosAgent — Propuesta DDL Julio 2026 — PENDIENTE APROBACIÓN HITL*
