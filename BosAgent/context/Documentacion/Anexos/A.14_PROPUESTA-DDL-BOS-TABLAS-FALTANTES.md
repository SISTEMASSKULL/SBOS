# Anexo A.14 — Propuesta DDL: Grupos de Tablas del Schema `bos`
## Clasificación por grupo funcional + 5 tablas faltantes — pendiente aprobación HITL

**Versión:** 5.0.0 — ✅ TODAS LAS PREGUNTAS HITL CERRADAS — LISTO PARA COMMIT
**Fecha:** 2026-07-31
**Autor:** bos-developer — SBOS
**Estado:** 🟡 APROBADO POR HITL — pendiente commit a `DDLs/bos_01__control_plane.sql`
**Referencia:** `1.01_MANUAL-IAM-INSTALLER.md §3.7` · `3.01_MANUAL-SERVER-FICHAS.md`
· `2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md` · `DDLs/bos_01__control_plane.sql`
· `DDLs/SBOS_db_V2_DDL.sql` · bAuth `A.65.02`, `A.65.02.06`, `5.01_MANUAL-AUDITORIA-TRAZABILIDAD`

**Cambios v5.0.0 (respecto v4.0.0):**
- Q7 cerrada: fallback de políticas = fila del tenant raíz (sembrada en seed junto al tenant raíz, empresa master y sucursal master). DDL sin cambios.
- Q8 cerrada: `entity_1_id UUID NOT NULL FK` se mantiene. Empresa master sembrada en seed antes de cualquier sesión BOS. DDL sin cambios.
- Pie de página actualizado a v5.0.0

**Resumen de seed obligatorio (consecuencia de Q3, Q7, Q8):**
```
Orden de inserción en el seed de creación de SBOS_db:
  1. bauth.idn_tenant            → tenant raíz (UUID fijo, superadmin de tenants)
  2. bauth.idn_identity_entity   → empresa master  (entity_1_id de ctx_context_session)
  3. bauth.idn_identity_entity   → sucursal master (entity_2_id opcional)
  4. bos.cap_tenant_politica     → política de capacidad del tenant raíz (defaults globales)
```

---

## 1. Principio de clasificación

El schema `bos` organiza sus tablas en **grupos funcionales** identificados por un
prefijo de 3 letras que corresponde al motor BOS que las posee:

```
bos.<GRUPO>_<ENTIDAD>_<objeto>
     ───┬───  ───┬───  ───┬───
        │        │        └── qué tipo de registro (state, event, snapshot, politica…)
        │        └── la cosa concreta que se almacena (context, device, ficha, bootstrap…)
        └── grupo de 3 letras = motor dueño

     CTX  Motor ④ Context Plane        (8 tablas — ya en DDL) ← referencia
     FCH  Motor ③ Server FICHAS         (2 tablas — propuestas)
     INS  Motor ① IAM Installer         (1 tabla  — propuesta)
     CAP  Motor ② SO Observable/Cap.   (2 tablas — propuestas)
```

**Regla:** una tabla nunca mezcla responsabilidades de dos grupos.
Si cruza motores, es evidencia de que el diseño está mal — separar.

**Ejemplo del patrón (CTX como referencia):**

| Tabla existente | GRUPO | ENTIDAD | objeto |
|---|:---:|:---:|:---:|
| `bos.ctx_context_session` | ctx | context | session |
| `bos.ctx_device_heartbeat` | ctx | device | heartbeat |
| `bos.ctx_context_audit` | ctx | context | audit |

Las tablas propuestas siguen el mismo patrón.

---

## 2. Grupo CTX — Motor ④ Context Plane

**Prefijo:** `bos.ctx_*`
**Propietario:** `bos.ctx.*` (JSON-RPC)
**Estado:** ✅ completo en `bos_01__control_plane.sql`

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.ctx_registered_device` | T-395 | — | Dispositivos pre-auth (dctx_id, BitMask=0, TTL 8h) |
| `bos.ctx_context_session` | T-396 | — | Sesiones post-auth (ctx_id, BitMask>0, TTL 12h) |
| `bos.ctx_context_audit` | T-397 | 🔒 | Auditoría WORM de toda operación del Context Plane |
| `bos.ctx_context_switch_log` | T-398 | 🔒 | Historial WORM de cambios de contexto sin reautenticación |
| `bos.ctx_context_policy` | T-399 | — | Políticas TTL/seguridad por tenant |
| `bos.ctx_device_heartbeat` | T-400 | — | Heartbeats de dispositivos (alta escritura, 24h retención) |
| `bos.ctx_context_transfer` | T-401 | 🔒 | Transferencia de contexto entre dispositivos |
| `bos.ctx_context_emergency` | T-402 | 🔒 | Break-glass (control dual, TTL 2h, revisión 24h) |

> **No se propone cambio alguno a este grupo.** Las 8 tablas están correctamente
> diseñadas y nombradas. Son la referencia de patrón para los grupos nuevos.

> **Nota sobre `actor_id` y `ip_address`:** `bos.ctx_context_audit` (T-397) ya incluye
> `actor_id UUID NULL REFERENCES bauth.idn_identity_entity(entity_id)` (línea 210) e
> `ip_address INET NULL` (línea 214). Este patrón se replica en T-NEW-2 y T-NEW-3.

---

## 3. Grupo FCH — Motor ③ Server FICHAS

**Prefijo:** `bos.fch_*`
**Propietario:** `bos.ficha.*` (JSON-RPC)
**Estado:** ❌ ausente en DDL — tablas propuestas abajo

### 3.1 Por qué faltan

El motor ③ gestiona 112+ fichas con una máquina de 18 estados (ADR-021). Hoy su
estado vive en `.sbos_state.json` (file-lock, un nodo, no consultable por SQL). Eso
impide: alertas por estado, dashboards SQL, auditoría forense de operaciones de fichas,
y escalabilidad a múltiples nodos.

El manual `0.00 R4` exige explícitamente:
> *"Cada discrepancia queda registrada en `bos.ficha_event` con `ctx_id`
> — evidencia ISO 27001 A.8.15."*

**Principio arquitectónico (Decisión Q1 — v4.0.0):**

> **Las fichas son componentes de plataforma, no instancias por tenant.**

Una ficha (`postgresql`, `redis`, `bauth`, `kong`, `erp`) se instala **una sola vez**
y sirve a **todos los tenants, todas las empresas y todas las sucursales** del sistema.
La multi-tenancy vive como **datos** dentro de las aplicaciones — no como infraestructura
duplicada. Crear una instancia de cada ficha por tenant con 100+ aplicaciones y N tenants
genera una explosión de recursos imposible de administrar.

```
CORRECTO — escala vertical:
  postgresql ←── todos los tenants (schemas/RLS)
  bauth      ←── todas las empresas (modelo 18 dominios)
  kong       ←── todos los tenants (plugins por ruta)

INCORRECTO — explosión horizontal:
  postgresql-abc, postgresql-xyz, postgresql-N...  (N bases de datos)
  bauth-abc, bauth-xyz, bauth-N...                 (N daemons de identidad)
```

La excepción (tenant con aislamiento físico dedicado por requisito regulatorio) es un
**caso explícito documentado**, no el diseño base. En ese caso extremo sí existiría
una ficha con alcance de tenant, pero es la minoría — no la regla que guía el schema.

Por lo tanto: **`fch_ficha_state` no tiene `tenant_id`**. La ficha existe en el sistema,
punto. El `tenant_id` aparece en los **eventos** (`fch_ficha_event`) únicamente para
registrar en auditoría qué operación de qué tenant provocó un cambio en la ficha
compartida — no para indicar propiedad.

**Verificación anti-redundancia:**
- `bauth.auth_device` (T-390, DDL línea 4775): identidad de dispositivos. Dominio distinto.
- `bauth.idn_roles_nhi_identity` (T-186): identidad no-humana. No cubre estado de instalación.
- **Veredicto:** `fch_ficha_state` y `fch_ficha_event` son 100% dominio BOS. Sin redundancia.

### 3.2 Tabla T-NEW-1: `bos.fch_ficha_state`  [FCH · ficha · state]

Estado actual de cada ficha desplegada. Una fila por ficha viva.

```sql
-- =============================================================================
-- T-NEW-1 — bos.fch_ficha_state
-- Estado actual de cada ficha (18 estados ADR-021). Una fila por ficha.
-- GRUPO=fch · ENTIDAD=ficha · OBJETO=state
-- ADR-021 · SBOS-BOS-FICHA-001 · ISO 27001:2022 A.8.9 · NIST SP 800-53 CM-8
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.fch_ficha_state (
    ficha_id              UUID        NOT NULL DEFAULT uuidv7(),
    ficha_name            TEXT        NOT NULL,
    server_id             TEXT        NOT NULL,
    version               TEXT        NOT NULL DEFAULT '0.0.0',
    state                 TEXT        NOT NULL DEFAULT 'PENDIENTE',
    category              INTEGER     NOT NULL DEFAULT 1,
    criticality           BOOLEAN     NOT NULL DEFAULT false,
    backend               TEXT        NOT NULL DEFAULT 'bash',
    installed_at          TIMESTAMPTZ NULL,
    installed_by          UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by            UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    last_health_check_at  TIMESTAMPTZ NULL,
    health_status         TEXT        NULL,
    hashes                JSONB       NOT NULL DEFAULT '{}',
    ctx_id                TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT fch_s_pkey            PRIMARY KEY (ficha_id),
    CONSTRAINT uq_fch_s_name_server  UNIQUE (ficha_name, server_id),
    CONSTRAINT chk_fch_s_state       CHECK (state IN (
        'PENDIENTE','LISTA','INSTALANDO','INSTALADA',
        'ACTUALIZACION_DISPONIBLE','ACTUALIZACION_APROBADA','ACTUALIZANDO',
        'DEGRADADA','ERROR_FISICO','ERROR_LOGICO','REPARANDO',
        'ERROR_NO_CORREGIBLE','FALLA_INSTALACION','FALLA_ACTUALIZACION',
        'ROLLBACK','LIMPIEZA','PAUSADA','DESINSTALADA'
    )),
    CONSTRAINT chk_fch_s_backend     CHECK (backend IN ('bash','k8s','binary','python')),
    CONSTRAINT chk_fch_s_category    CHECK (category BETWEEN 1 AND 5),
    CONSTRAINT chk_fch_s_hashes      CHECK (jsonb_typeof(hashes) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_fch_s_state      ON bos.fch_ficha_state (state);
CREATE INDEX IF NOT EXISTS idx_fch_s_server     ON bos.fch_ficha_state (server_id);
CREATE INDEX IF NOT EXISTS idx_fch_s_criticidad ON bos.fch_ficha_state (criticality) WHERE criticality = true;
CREATE INDEX IF NOT EXISTS idx_fch_s_updated    ON bos.fch_ficha_state (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fch_s_health_ts  ON bos.fch_ficha_state (last_health_check_at DESC) WHERE last_health_check_at IS NOT NULL;

COMMENT ON TABLE bos.fch_ficha_state IS
  '[T-NEW-1] [ADR-021] [SBOS-BOS-FICHA-001] [ISO 27001:2022 A.8.9] [NIST SP 800-53 CM-8]
   Estado actual de cada ficha desplegada. Máquina de 18 estados.
   PRINCIPIO: las fichas son componentes de plataforma compartidos por todos los tenants.
   No existe tenant_id aquí — la ficha no pertenece a ningún tenant, sirve a todos.
   La unicidad se garantiza por (ficha_name, server_id): una ficha por nombre en cada
   servidor lógico (S01, S-HOST, etc.).
   installed_by / updated_by: FK a bauth.idn_identity_entity — quién realizó la acción.
   NULL cuando BOS actúa de forma autónoma sin sesión de operador humano.
   last_health_check_at: freshness del inventario — NIST SP 800-53 CM-8.';
```

**Correspondencia Go (`internal/state/types.go:Ficha`):**

| Columna | Campo Go | Notas |
|---|---|---|
| `ficha_name` | `Name string` | id único de la ficha |
| `server_id` | `Server string` | S01, S-HOST... |
| `version` | `Version string` | del manifest.yml |
| `state` | `State FichaState` | 18 valores |
| `category` | `Category int` | 1-5 |
| `criticality` | `Criticality bool` | |
| `backend` | `Backend string` | bash/k8s/binary |
| `installed_at` | `InstalledAt time.Time` | nullable |
| `health_status` | `HealthStatus string` | último probe |
| `hashes` | `Hashes map[string]string` | SHA-256 por archivo |
| `installed_by` | *(nuevo)* | UUID actor que instaló — NIST CM-8 |
| `updated_by` | *(nuevo)* | UUID actor que actualizó — NIST CM-8 |
| `last_health_check_at` | *(nuevo)* | freshness del inventario — NIST CM-8 |
| ~~`tenant_id`~~ | *(eliminado)* | Las fichas son de plataforma — no tienen tenant dueño |

---

### 3.3 Tabla T-NEW-2: `bos.fch_ficha_event` 🔒 WORM  [FCH · ficha · event]

Historial inmutable de toda operación sobre una ficha.

**Brechas corregidas en v3.0.0:**
- `actor_id UUID NULL FK` — requerido por NIST SP 800-53 AU-3 e ISO 27001:2022 A.8.15.
  Patrón tomado de `bos.ctx_context_audit` línea 210 de `bos_01__control_plane.sql`.
  NO es opcional — sin atribución, el log no cumple AU-3.
- `ip_address INET NULL` — requerido por NIST SP 800-53 AU-3 (origen de la operación).
  Patrón tomado de `bos.ctx_context_audit` línea 214 y `bauth.ses_session_log` línea 4032.

```sql
-- =============================================================================
-- T-NEW-2 — bos.fch_ficha_event 🔒 WORM
-- Historial inmutable de operaciones sobre fichas. Hash-chain SHA-256.
-- GRUPO=fch · ENTIDAD=ficha · OBJETO=event
-- ISO 27001:2022 A.8.15 · A.5.33 · NIST SP 800-53 AU-2, AU-3, AU-12 · ADR-021 · 0.00 R4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.fch_ficha_event (
    event_id    UUID        NOT NULL DEFAULT uuidv7(),
    ficha_id    UUID        NOT NULL REFERENCES bos.fch_ficha_state(ficha_id),
    ficha_name  TEXT        NOT NULL,
    tenant_id   UUID        NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id    UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ip_address  INET        NULL,
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

    CONSTRAINT fch_e_pkey        PRIMARY KEY (event_id),
    CONSTRAINT chk_fch_e_op      CHECK (operation IN (
        'INSTALL','UPDATE','REPAIR','REMOVE',
        'HEALTH_CHECK','DRIFT_DETECTED','DRIFT_RESOLVED',
        'SCALE','PAUSE','RESUME','ROLLBACK','CLEANUP','STATE_TRANSITION'
    )),
    CONSTRAINT chk_fch_e_result  CHECK (result IN ('OK','FAIL','PARTIAL','SKIPPED')),
    CONSTRAINT chk_fch_e_state   CHECK (to_state IN (
        'PENDIENTE','LISTA','INSTALANDO','INSTALADA',
        'ACTUALIZACION_DISPONIBLE','ACTUALIZACION_APROBADA','ACTUALIZANDO',
        'DEGRADADA','ERROR_FISICO','ERROR_LOGICO','REPARANDO',
        'ERROR_NO_CORREGIBLE','FALLA_INSTALACION','FALLA_ACTUALIZACION',
        'ROLLBACK','LIMPIEZA','PAUSADA','DESINSTALADA'
    ))
);

REVOKE UPDATE, DELETE ON bos.fch_ficha_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_fch_e_ficha      ON bos.fch_ficha_event (ficha_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fch_e_tenant_op  ON bos.fch_ficha_event (tenant_id, operation, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fch_e_actor      ON bos.fch_ficha_event (actor_id, executed_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fch_e_saga       ON bos.fch_ficha_event (saga_id) WHERE saga_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fch_e_executed   ON bos.fch_ficha_event (executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fch_e_fallas     ON bos.fch_ficha_event (result) WHERE result = 'FAIL';

COMMENT ON TABLE bos.fch_ficha_event IS
  '[T-NEW-2] [ISO 27001:2022 A.8.15] [ISO 27001:2022 A.5.33] [NIST SP 800-53 AU-2, AU-3, AU-12] [ADR-021] [0.00 R4]
   Historial WORM de toda operación sobre una ficha. Hash-chain SHA-256.
   PRINCIPIO: la ficha es de plataforma (compartida). tenant_id en este evento NO indica
   quién dueño de la ficha — indica qué operación de qué tenant provocó el evento.
   Ejemplo: si el operador del tenant "acme" ejecuta bosctl ficha repair postgresql,
   el evento registra tenant_id=acme aunque postgresql sirva a todos los tenants.
   Esto es auditoría de origen, no de propiedad.
   ficha_name denormalizado para queries forenses sin JOIN cuando fch_ficha_state se archiva.
   actor_id: quién ordenó la operación (operador o daemon). NULL si BOS actúa autónomamente.
   Requerido por NIST AU-3 — el registro debe incluir la identidad del responsable.
   ip_address: origen de la solicitud. NULL para operaciones internas del daemon.
   Requerido por NIST AU-3 — origen de la operación en el registro de auditoría.
   REVOKE UPDATE/DELETE garantiza inmutabilidad conforme ISO 27001:2022 A.5.33.';
COMMENT ON COLUMN bos.fch_ficha_event.details IS
  'Contiene steps completados, logs de error, tiempo por step y causa de falla.';
COMMENT ON COLUMN bos.fch_ficha_event.saga_id IS
  'UUID de la saga que originó el evento. NULL si fue operación directa.';
```

**Preguntas HITL — Grupo FCH:**

| # | Pregunta | Estado |
|:---:|---|:---:|
| Q1 | ¿`tenant_id NULL` para fichas de sistema (postgresql, redis, kong)? | ⏳ abierta |
| ~~Q2~~ | ~~¿Se necesita `actor_id UUID`?~~ | ✅ CERRADA — es obligatorio por NIST SP 800-53 AU-3. Añadido en v3.0.0. |

---

## 4. Grupo INS — Motor ① IAM Installer

**Prefijo:** `bos.ins_*`
**Propietario:** `bos.bootstrap.*` (JSON-RPC)
**Estado:** ❌ ausente en DDL — tabla propuesta abajo

### 4.1 Por qué falta

El bootstrap day-0 tiene 6 capas progresivas (ADR-040) con verificaciones C-01..C-09.
Hoy esos eventos se escriben en archivos de log dispersos. No hay forma de consultar
SQL: "¿en qué paso falló el bootstrap del tenant X el 2026-07-29?" ni de crear un
dashboard de progreso de instalación.

**Verificación anti-redundancia (análisis v3.0.0):**
- `bauth.idn_tenant.provisioning_status` (DDL línea 439): estado de alto nivel del
  bootstrap (`PENDING`,`INFRA_PROVISIONING`,`SCHEMA_CREATED`,`IDP_CONFIGURED`,
  `COMPLETED`,`FAILED`). Es un **campo único mutable** — no tiene historial, ni
  granularidad por step, ni `verification_code`, ni `duration_ms`, ni `ficha_name`.
- **Veredicto:** Son complementarios. `provisioning_status` = estado actual del tenant
  (para polling). `ins_bootstrap_event` = historial WORM de cada step.
  BOS escribe en `ins_bootstrap_event` y **notifica a bAuth vía API** para que bAuth
  actualice `provisioning_status`. BOS no escribe directamente en `bauth.idn_tenant`
  (violación de schema-per-service — `1.05_MANUAL-DDL-SEEDS-v1.0.md §2`).

### 4.2 Tabla T-NEW-3: `bos.ins_bootstrap_event` 🔒 WORM  [INS · bootstrap · event]

**Brechas corregidas en v3.0.0:**
- `actor_id UUID NULL FK` — NIST SP 800-53 AU-3. En capas 3-5 puede haber un operador
  humano que dispare el bootstrap manualmente (HITL). Sin `actor_id` no hay atribución.
- `node_id TEXT NULL` — NIST SP 800-53 CM-8 (inventario de componentes del sistema).
  Relevante cuando el bootstrap corre en clusters multi-nodo.

```sql
-- =============================================================================
-- T-NEW-3 — bos.ins_bootstrap_event 🔒 WORM
-- Registro de eventos del bootstrap progresivo (6 capas ADR-040). WORM.
-- GRUPO=ins · ENTIDAD=bootstrap · OBJETO=event
-- ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-3, CM-8 · ADR-040 · 1.01 §4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ins_bootstrap_event (
    event_id          UUID        NOT NULL DEFAULT uuidv7(),
    bootstrap_run_id  UUID        NOT NULL,
    tenant_id         UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id          UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    node_id           TEXT        NULL,
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

    CONSTRAINT ins_be_pkey       PRIMARY KEY (event_id),
    CONSTRAINT chk_ins_be_layer  CHECK (layer BETWEEN 0 AND 5),
    CONSTRAINT chk_ins_be_state  CHECK (state IN (
        'STARTED','COMPLETED','FAILED','SKIPPED','RETRYING'
    )),
    CONSTRAINT chk_ins_be_result CHECK (result IN ('OK','FAIL','PARTIAL','SKIPPED')),
    CONSTRAINT chk_ins_be_vcode  CHECK (
        verification_code IS NULL OR
        verification_code ~ '^C-[0-9]{2}$'
    )
);

REVOKE UPDATE, DELETE ON bos.ins_bootstrap_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_ins_be_run        ON bos.ins_bootstrap_event (bootstrap_run_id, executed_at);
CREATE INDEX IF NOT EXISTS idx_ins_be_tenant     ON bos.ins_bootstrap_event (tenant_id, layer, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ins_be_actor      ON bos.ins_bootstrap_event (actor_id, executed_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_be_ficha      ON bos.ins_bootstrap_event (ficha_name, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ins_be_vcode      ON bos.ins_bootstrap_event (verification_code) WHERE verification_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_be_failures   ON bos.ins_bootstrap_event (result, layer) WHERE result = 'FAIL';

COMMENT ON TABLE bos.ins_bootstrap_event IS
  '[T-NEW-3] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-3, CM-8] [ADR-040] [1.01 §4]
   Registro WORM del bootstrap progresivo. 6 capas (0=OS → 5=Hardening).
   tenant_id NUNCA es NULL — el tenant raíz (registro #1, seed de BD) siempre existe
   y está disponible desde antes que cualquier otra operación de bootstrap comience.
   Capas 0-2 (sistema): tenant_id = UUID del tenant raíz (superadministrador de tenants).
   Capas 3-5 (tenant específico): tenant_id = UUID del tenant que se está instalando.
   El tenant raíz gobierna a todos los demás tenants y provee contexto a las operaciones
   de plataforma que ocurren antes de que exista ningún tenant de cliente.
   bootstrap_run_id agrupa todos los eventos de un mismo intento end-to-end.
   Generado por BOS al iniciar el proceso (UUIDv7 propio).
   actor_id: quién inició el bootstrap. NULL si fue automático. NIST AU-3.
   node_id: nodo físico/VM donde corrió el step. NIST CM-8.
   Protocolo de coordinación: BOS notifica a bAuth vía API para actualizar
   bauth.idn_tenant.provisioning_status. BOS NO escribe directamente en bauth.*
   (schema-per-service — 1.05_MANUAL-DDL-SEEDS-v1.0.md §2).';
COMMENT ON COLUMN bos.ins_bootstrap_event.bootstrap_run_id IS
  'UUID generado al inicio de cada intento de bootstrap. Agrupa todos sus eventos.';
COMMENT ON COLUMN bos.ins_bootstrap_event.verification_code IS
  'C-01..C-09 — código de verificación de capa completada. NULL si es step intermedio.';
```

**Capas y verificaciones (referencia ADR-040):**

| `layer` | Nombre | Fichas | `verification_code` |
|:---:|---|---|:---:|
| 0 | S-HOST OS | `bos-preflight`, `sbos-bootstrap-os` | C-01 |
| 1 | S-HOST K8s | `sbos-bootstrap-k8s`, `sbos-bootstrap-cni`, `sbos-bootstrap-storage` | C-02, C-03 |
| 2 | S01 Datos | `postgresql`, `redis`, `minio` | C-04, C-05 |
| 3 | S02-S03 Identidad+GW | `vault`, `keycloak`, `kong` | C-06, C-07, C-08 |
| 4 | S06 Notificaciones | `sbos-notifier` | C-09 |
| 5 | S-HOST Hardening | `sbos-bootstrap-hard`, pasadas 2 | — |

**Decisiones HITL — Grupo INS:**

| # | Pregunta | Estado |
|:---:|---|:---:|
| ~~Q3~~ | ~~¿`tenant_id NULL` para capas 0-2?~~ | ✅ CERRADA — `tenant_id NOT NULL` siempre. Capas 0-2 usan el tenant raíz (seed #1). |
| ~~Q4~~ | ~~¿`bootstrap_run_id` lo genera BOS o del ctx_id?~~ | ✅ CERRADA — UUIDv7 propio. |

---

## 5. Grupo CAP — Motor ② SO Observable / Capacidad

**Prefijo:** `bos.cap_*`
**Propietario:** `bos.capacity.*` (JSON-RPC)
**Estado:** ❌ ausente en DDL — tablas propuestas abajo

### 5.1 Por qué faltan

El Autómata de Capacidad (SBOS-BOS-CAP-001) tiene 4 motores (M5.1-M5.4) que corren
cada 60s. Sin `bos.cap_sistema_snapshot` no hay datos históricos y el Motor Proyección
(M5.2) no puede hacer regresión lineal a 7/30/90 días. Sin `bos.cap_tenant_politica`
no hay políticas configurables por tenant — BOS usaría umbrales hardcodeados.

Patrón de nombres: `bos.cap_<ENTIDAD>_<objeto>` — `sistema` para métricas del host/K8s, `tenant` para políticas por tenant.

**Verificación anti-redundancia (análisis v3.0.0):**
- `bauth.auth_device_posture` (T-391, DDL línea 4816): postura de seguridad de
  dispositivos individuales (MDM compliance, `disk_encrypted`, `risk_score`). Sin
  campos de capacidad de infraestructura.
- `bauth.ses_risk_policy` (T-180, DDL línea 4275): reglas de respuesta a riesgo de
  sesión. Sin métricas de recursos.
- **Veredicto para T-NEW-4:** 100% dominio BOS, sin solapamiento.
- **Para T-NEW-5:** Solapamiento parcial confirmado pero de capas distintas (ver §5.3).

### 5.2 Tabla T-NEW-4: `bos.cap_sistema_snapshot`  [CAP · sistema · snapshot]

Instantáneas periódicas de ~30 métricas del sistema.

**Cambios v4.0.0:** Particionado mensual `PARTITION BY RANGE (captured_at)` + cron de
eliminación de particiones legacy. Q5 cerrada.

```sql
-- =============================================================================
-- T-NEW-4 — bos.cap_sistema_snapshot
-- Instantáneas de ~30 métricas del sistema cada 60s (Motor Observación M5.1).
-- NO WORM: datos de observabilidad operativa, no de auditoría de acceso.
-- Retención 90 días — particiones mensuales + cron de eliminación de legacy.
-- GRUPO=cap · ENTIDAD=sistema · OBJETO=snapshot
-- SBOS-BOS-CAP-001 · 2.02 M5.1 · ISO 27001:2022 A.12.4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_sistema_snapshot (
    snapshot_id           UUID         NOT NULL DEFAULT uuidv7(),
    scope                 TEXT         NOT NULL DEFAULT 'GLOBAL',
    tenant_id             UUID         NULL REFERENCES bauth.idn_tenant(tenant_id),
    captured_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- ── Context Plane ────────────────────────────────────────────────
    ctx_sessions_active   INTEGER      NULL,
    ctx_devices_active    INTEGER      NULL,

    -- ── Redis ────────────────────────────────────────────────────────
    redis_memory_pct      NUMERIC(5,2) NULL,
    redis_keys_count      BIGINT       NULL,
    redis_ops_per_sec     NUMERIC(10,2) NULL,

    -- ── PostgreSQL ───────────────────────────────────────────────────
    pg_connections_active INTEGER      NULL,
    pg_connections_max    INTEGER      NULL,
    pg_db_size_bytes      BIGINT       NULL,
    pg_tps                NUMERIC(10,2) NULL,

    -- ── Kong ─────────────────────────────────────────────────────────
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

    CONSTRAINT chk_cap_sn_scope CHECK (scope IN ('GLOBAL','TENANT')),
    CONSTRAINT chk_cap_sn_scope_tenant CHECK (
        (scope = 'GLOBAL' AND tenant_id IS NULL) OR
        (scope = 'TENANT' AND tenant_id IS NOT NULL)
    ),
    CONSTRAINT chk_cap_sn_pcts CHECK (
        (redis_memory_pct    IS NULL OR redis_memory_pct    BETWEEN 0 AND 100) AND
        (k8s_cpu_used_pct    IS NULL OR k8s_cpu_used_pct    BETWEEN 0 AND 100) AND
        (k8s_mem_used_pct    IS NULL OR k8s_mem_used_pct    BETWEEN 0 AND 100) AND
        (host_cpu_pct        IS NULL OR host_cpu_pct        BETWEEN 0 AND 100) AND
        (host_mem_pct        IS NULL OR host_mem_pct        BETWEEN 0 AND 100) AND
        (host_disk_pct       IS NULL OR host_disk_pct       BETWEEN 0 AND 100) AND
        (kong_error_rate_pct IS NULL OR kong_error_rate_pct BETWEEN 0 AND 100)
    )
) PARTITION BY RANGE (captured_at);

-- Partición inicial — mes de instalación (ejemplo julio 2026).
-- BOS crea la partición del mes siguiente el día 25 de cada mes (cron interno).
CREATE TABLE IF NOT EXISTS bos.cap_sistema_snapshot_2026_07
    PARTITION OF bos.cap_sistema_snapshot
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- Los índices se crean sobre la tabla padre; PostgreSQL los propaga a cada partición.
CREATE INDEX IF NOT EXISTS idx_cap_sn_scope_time  ON bos.cap_sistema_snapshot (scope, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_cap_sn_tenant_time ON bos.cap_sistema_snapshot (tenant_id, captured_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cap_sn_degraded    ON bos.cap_sistema_snapshot (fichas_degraded, captured_at DESC)
    WHERE fichas_degraded > 0;

COMMENT ON TABLE bos.cap_sistema_snapshot IS
  '[T-NEW-4] [SBOS-BOS-CAP-001] [2.02 M5.1] [ISO 27001:2022 A.12.4]
   Instantáneas periódicas (~60s) de 30+ métricas del sistema.
   NO WORM: datos de observabilidad operativa. No aplica REVOKE UPDATE/DELETE.
   PARTICIONADO MENSUAL (PARTITION BY RANGE captured_at):
     — Una partición por mes: bos.cap_sistema_snapshot_YYYY_MM
     — BOS crea la partición del mes siguiente el día 25 de cada mes (cron interno)
     — Cron de eliminación ejecuta DROP TABLE sobre particiones > 90 días
       (equivale a DROP TABLE bos.cap_sistema_snapshot_YYYY_MM): sin contención,
       sin recorrer filas, instantáneo.
   NOTA: PRIMARY KEY no se declara en la tabla padre particionada — cada partición
   tiene su propio índice implícito sobre snapshot_id.
   scope=GLOBAL → tenant_id NULL · scope=TENANT → tenant_id NOT NULL.
   Todas las métricas NULLable: una fuente caída no invalida el snapshot completo.';
```

**Decisiones HITL — Grupo CAP (T-NEW-4):**

| # | Pregunta | Estado |
|:---:|---|:---:|
| ~~Q5~~ | ~~¿Retención por job o partición mensual?~~ | ✅ CERRADA — ambas: partición mensual + cron DROP legacy. |
| ~~Q6~~ | ~~¿`scope` o `tenant_id NULL`?~~ | ✅ CERRADA — columna `scope` con CHECK. |

---

### 5.3 Tabla T-NEW-5: `bos.cap_tenant_politica`  [CAP · tenant · politica]

Políticas de capacidad declaradas por tenant.

**Cambios v3.0.0:**
- Renombrado `kong_rps_limit` → `kong_tenant_rps_cap` para distinguir de las dos
  columnas homólogas de capas distintas: `ctx_context_policy.rate_limit_rps` (rate limit
  del Context API de BOS) y `bauth.idn_tenant.rate_limit_rps` (rate limit IAM de bAuth).
  Las tres son semánticamente distintas — nombrarlas diferente evita confusión.
- Eliminados `alert_webhook_url` y `alert_email` — las notificaciones se delegan a
  bnotify. Almacenarlos aquí crea acoplamiento espurio entre capacidad y delivery de
  notificaciones. Referencia: `bauth.idn_tenant.notification_channels TEXT[]` (DDL
  línea 474) demuestra que el canal ya está en bAuth.
- Añadidos `updated_by UUID NULL FK`, `effective_from TIMESTAMPTZ NOT NULL` para
  cumplimiento NIST SP 800-53 AU-3 e ISO 27001:2022 A.8.9 (trazabilidad de cambios de política).

**Solapamientos identificados y resueltos (análisis v3.0.0):**

| Campo | Solapamiento con | Diferencia semántica | Resolución |
|---|---|---|---|
| `kong_tenant_rps_cap` (este) | `ctx_context_policy.rate_limit_rps` | Este = cap total del tenant en Kong PEP (infraestructura). Ese = rate limit del Context API de BOS. | Capas distintas. Mantener los dos, nombres distintos. |
| `kong_tenant_rps_cap` (este) | `bauth.idn_tenant.rate_limit_rps` | Este = cap de infraestructura Kong. Ese = rate limit desde perspectiva IAM. | Capas distintas. Mantener los dos. |
| `ctx_sessions_max` (este) | `ctx_context_policy.max_sessions_per_user` | Este = techo AGREGADO del tenant. Ese = límite per-user. Relación: `N×per_user ≤ ctx_sessions_max`. | Complementarios. Mantener los dos. |

```sql
-- =============================================================================
-- T-NEW-5 — bos.cap_tenant_politica
-- Políticas de capacidad declaradas por tenant (Motor Políticas M5.3).
-- UNIQUE por tenant. Lee el Motor Proyección para forecast.
-- GRUPO=cap · ENTIDAD=tenant · OBJETO=politica
-- SBOS-BOS-CAP-001 · 2.02 M5.3 · ISO 27001:2022 A.8.9 · NIST SP 800-53 AU-3, CA-7
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_tenant_politica (
    politica_id              UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id                UUID         NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    updated_by               UUID         NULL REFERENCES bauth.idn_identity_entity(entity_id),
    effective_from           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- ── Modo de política ─────────────────────────────────────────────
    policy_mode              TEXT         NOT NULL DEFAULT 'recommend',

    -- ── Umbrales de recursos ─────────────────────────────────────────
    cpu_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    mem_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 85.0,
    disk_limit_pct           NUMERIC(5,2) NOT NULL DEFAULT 90.0,
    redis_mem_limit_pct      NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    pg_conn_limit_pct        NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    kong_tenant_rps_cap      INTEGER      NOT NULL DEFAULT 10000,
    ctx_sessions_max         INTEGER      NOT NULL DEFAULT 50000,
    pg_db_size_limit_bytes   BIGINT       NOT NULL DEFAULT 107374182400,

    -- ── Motor Proyección (M5.2) ───────────────────────────────────────
    projection_horizon_days  INTEGER      NOT NULL DEFAULT 30,
    projection_confidence    NUMERIC(4,3) NOT NULL DEFAULT 0.950,

    -- ── Auditoría ────────────────────────────────────────────────────
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ctx_id                   TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT cap_tp_pkey       PRIMARY KEY (politica_id),
    CONSTRAINT uq_cap_tp_tenant  UNIQUE (tenant_id),
    CONSTRAINT chk_cap_tp_mode   CHECK (policy_mode IN (
        'autonomous','recommend','block_and_alert','emergency'
    )),
    CONSTRAINT chk_cap_tp_pcts   CHECK (
        cpu_limit_pct       BETWEEN 1 AND 100 AND
        mem_limit_pct       BETWEEN 1 AND 100 AND
        disk_limit_pct      BETWEEN 1 AND 100 AND
        redis_mem_limit_pct BETWEEN 1 AND 100 AND
        pg_conn_limit_pct   BETWEEN 1 AND 100
    ),
    CONSTRAINT chk_cap_tp_rps      CHECK (kong_tenant_rps_cap > 0),
    CONSTRAINT chk_cap_tp_sess     CHECK (ctx_sessions_max > 0),
    CONSTRAINT chk_cap_tp_horizon  CHECK (projection_horizon_days BETWEEN 1 AND 365),
    CONSTRAINT chk_cap_tp_conf     CHECK (projection_confidence BETWEEN 0.5 AND 0.999)
);

CREATE INDEX IF NOT EXISTS idx_cap_tp_tenant ON bos.cap_tenant_politica (tenant_id);
CREATE INDEX IF NOT EXISTS idx_cap_tp_mode   ON bos.cap_tenant_politica (policy_mode);
CREATE INDEX IF NOT EXISTS idx_cap_tp_actor  ON bos.cap_tenant_politica (updated_by) WHERE updated_by IS NOT NULL;

COMMENT ON TABLE bos.cap_tenant_politica IS
  '[T-NEW-5] [SBOS-BOS-CAP-001] [2.02 M5.3] [ISO 27001:2022 A.8.9] [NIST SP 800-53 AU-3, CA-7]
   Políticas de capacidad declaradas por tenant. UNIQUE por tenant.
   policy_mode: autonomous=BOS actúa solo · recommend=HITL aprueba ·
   block_and_alert=bloquea admisión · emergency=protocolo completo.
   kong_tenant_rps_cap = cap TOTAL del tenant en Kong PEP (infraestructura). Distinto de:
     ctx_context_policy.rate_limit_rps = rate limit del Context API de BOS (per-tenant),
     bauth.idn_tenant.rate_limit_rps = rate limit desde perspectiva IAM.
   ctx_sessions_max = techo AGREGADO del tenant. Distinto de ctx_context_policy.max_sessions_per_user (per-user).
   Notificaciones: delegadas a bnotify — NO almacenar webhook_url/email aquí.
   updated_by: quién cambió la política — requerido por NIST AU-3 e ISO A.8.9.
   effective_from: cuándo entró en vigor — ISO A.8.9 (gestión de cambios).
   Relación con ctx_context_policy (T-399): T-399 governa TTL/seguridad del contexto.
   Esta tabla governa umbrales de recursos de infraestructura.';
COMMENT ON COLUMN bos.cap_tenant_politica.policy_mode IS
  'autonomous=BOS actúa solo · recommend=HITL aprueba · block_and_alert=bloquea admisión · emergency=protocolo completo.';
```

**Preguntas HITL — Grupo CAP (T-NEW-5):**

| # | Pregunta | Estado |
|:---:|---|:---:|
| Q7 | ¿`cap_tenant_politica` necesita fila con `tenant_id = NULL` como defaults globales (fallback cuando un tenant no tiene política)? | ⏳ abierta — requiere cambiar `tenant_id NOT NULL` a `tenant_id NULL` si se acepta |

---

## 6. Decisión de diseño — T-396 `entity_1_id` vs `empresa_slug`

Esta decisión afecta una tabla **existente** en el DDL (Grupo CTX), no una nueva.
Se registra aquí porque surgió del mismo análisis.

### 6.1 El conflicto

T-396 (`bos.ctx_context_session`) define:
```sql
entity_1_id UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)  -- empresa/dominio
entity_2_id UUID NULL     REFERENCES bauth.idn_identity_entity(entity_id)   -- sucursal
entity_3_id TEXT NULL                                                         -- pos_logico
```

Durante el bootstrap **Capas 0-2**, Keycloak y el modelo de identidad bAuth aún no están
instalados. Si se usa FK UUID, BOS no puede crear contextos de infraestructura en esas capas.

### 6.2 Opciones

| Opción | Diseño | Ventaja | Restricción |
|---|---|---|---|
| **A — DDL actual** | `entity_1_id UUID NOT NULL FK` | Integridad referencial fuerte | bAuth debe existir antes que cualquier sesión BOS |
| **B — TEXT operativo** | `empresa_id TEXT NOT NULL` | BOS opera autónomo en bootstrap | Sin FK; empresa/sucursal no verificadas contra bAuth |
| **C — Híbrido** | `entity_1_id UUID NULL FK` + `empresa_slug TEXT NOT NULL` | Funciona en Capa 0-2 (NULL) y en Capa 3+ (UUID) | Dos columnas; lógica de NULL en la app |

**Pregunta HITL Q8:** ¿Opción A, B o C?

---

## 7. Tablas bAuth que BOS necesita conocer

Del análisis del DDL canónico (`SBOS_db_V2_DDL.sql`):

| Tabla bAuth | PK | Rol en A.14 | Columnas de interés para BOS |
|---|---|---|---|
| `bauth.idn_tenant` (T-005, línea 427) | `tenant_id UUID` | FK en T-NEW-1..5 | `tenant_id`, `tenant_type`, `status`, `provisioning_status`, `session_ttl_max`, `rate_limit_rps` |
| `bauth.idn_identity_entity` (T-156, línea 2579) | `entity_id UUID` | FK `actor_id`/`installed_by`/`updated_by` en T-NEW-1, 2, 3, 5 | `entity_id`, `level`, `status` |

**Tablas bAuth con relación lógica (sin FK en DDL, por diseño):**
- `bauth.auth_device` (T-390) — BOS lee `trust_level` para mapear con `ctx_registered_device.hostname`. Sin FK directa (documentado en `A.65.02.06 §D-BCP-08`).
- `bauth.ses_risk_policy` (T-180) — BOS recibe señales CAEP y correlaciona con `ctx_context_audit`.

---

## 8. Resumen consolidado

### 8.1 Cuadro completo — 13 tablas en 4 grupos

```
schema bos — 13 tablas · 4 grupos · 6 tablas WORM
─────────────────────────────────────────────────────────────────────────
GRUPO CTX — Motor ④ Context Plane                         8 tablas ✅
─────────────────────────────────────────────────────────────────────────
  bos.ctx_registered_device    T-395  — Dispositivos pre-auth
  bos.ctx_context_session      T-396  — Sesiones post-auth              ← Q8
  bos.ctx_context_audit        T-397  — Auditoría WORM 🔒
  bos.ctx_context_switch_log   T-398  — Switches WORM 🔒
  bos.ctx_context_policy       T-399  — Políticas TTL/seg. por tenant
  bos.ctx_device_heartbeat     T-400  — Heartbeats (24h retención)
  bos.ctx_context_transfer     T-401  — Transferencias WORM 🔒
  bos.ctx_context_emergency    T-402  — Break-glass WORM 🔒

GRUPO FCH — Motor ③ Server FICHAS                         2 tablas ❌
─────────────────────────────────────────────────────────────────────────
  bos.fch_ficha_state          T-NEW-1 — Estado actual 18 estados      ← Q1
  bos.fch_ficha_event          T-NEW-2 — Historial WORM 🔒

GRUPO INS — Motor ① IAM Installer                         1 tabla  ❌
─────────────────────────────────────────────────────────────────────────
  bos.ins_bootstrap_event      T-NEW-3 — Bootstrap 6 capas WORM 🔒    ← Q3

GRUPO CAP — Motor ② SO Observable / Capacidad            2 tablas ❌
─────────────────────────────────────────────────────────────────────────
  bos.cap_sistema_snapshot     T-NEW-4 — 30+ métricas cada 60s        ← Q5
  bos.cap_tenant_politica      T-NEW-5 — Políticas por tenant          ← Q7
─────────────────────────────────────────────────────────────────────────
```

### 8.2 Veredicto de redundancia

| Tabla | ¿Existe en bAuth? | ¿Redundante? | Dominio |
|---|:---:|:---:|---|
| `bos.fch_ficha_state` | NO | NO | BOS puro |
| `bos.fch_ficha_event` | NO | NO | BOS puro |
| `bos.ins_bootstrap_event` | NO (complementa `provisioning_status`) | NO | BOS con coordinación API hacia bAuth |
| `bos.cap_sistema_snapshot` | NO | NO | BOS puro |
| `bos.cap_tenant_politica` | Solapamiento menor (capas distintas) | NO | BOS puro |

### 8.3 Orden de carga en `bos_01__control_plane.sql`

Una vez aprobado, las 5 tablas nuevas se añaden al final del archivo en este orden:

```
[existentes T-395..T-402 sin cambio]
↓
bos.fch_ficha_state              (sin FKs a tablas bos.*)
bos.fch_ficha_event              (FK → bos.fch_ficha_state)
bos.ins_bootstrap_event          (FK → bauth.idn_tenant nullable, bauth.idn_identity_entity nullable)
bos.cap_sistema_snapshot         (FK → bauth.idn_tenant nullable)
bos.cap_tenant_politica          (FK → bauth.idn_tenant, bauth.idn_identity_entity nullable)
```

---

## 9. Registro de decisiones HITL

Este registro contiene las decisiones de diseño que el humano debe tomar antes de que
el DDL pueda commitearse. Cada entrada documenta el contexto, las opciones y sus
consecuencias. El agente aplicará los cambios al DDL inmediatamente después de recibir
cada decisión.

**Estado general:**

| # | Afecta | Estado | Decidido |
|:---:|---|:---:|---|
| Q1 | `fch_ficha_state` | ✅ CERRADA | 2026-07-31 |
| Q3 | `ins_bootstrap_event` | ✅ CERRADA | 2026-07-31 |
| Q5 | `cap_sistema_snapshot` | ✅ CERRADA | 2026-07-31 |
| Q7 | `cap_tenant_politica` | ✅ CERRADA | 2026-07-31 |
| Q8 | `ctx_context_session` (existente) | ✅ CERRADA | 2026-07-31 |

---

### Q1 — ¿Las fichas de infraestructura pertenecen a un tenant o al sistema?

**Afecta:** `bos.fch_ficha_state` (T-NEW-1)
**Estado:** ✅ CERRADA — 2026-07-31

#### Contexto

SBOS instala fichas de dos tipos completamente distintos:

- **Fichas de infraestructura** — se instalan una sola vez para todo el sistema.
  Ejemplos: `postgresql`, `redis`, `kong`, `keycloak`, `vault`. Ningún tenant
  las "posee" — son la plataforma sobre la que corren todos los tenants.

- **Fichas de aplicación** — se instalan una vez por cada tenant.
  Ejemplos: `erp-tenant-abc`, `crm-tenant-xyz`. Cada tenant tiene las suyas.

En la tabla `fch_ficha_state`, la columna `tenant_id` identifica a qué tenant
pertenece la ficha. Para las fichas de aplicación esto es claro. Para las fichas
de infraestructura, la pregunta es: ¿qué valor tiene `tenant_id`?

#### El problema técnico

PostgreSQL tiene un comportamiento especial con valores `NULL` en constraints
de unicidad: **trata cada `NULL` como un valor distinto**. Eso significa que
si ponemos `tenant_id = NULL` para las fichas de infraestructura, el constraint
`UNIQUE(ficha_name, tenant_id)` fallaría en su propósito: permitiría registrar
`postgresql` dos veces con `tenant_id = NULL` sin dar ningún error.

```
ficha_name='postgresql', tenant_id=NULL  ← se inserta
ficha_name='postgresql', tenant_id=NULL  ← se inserta otra vez sin error ← BUG
```

#### Opciones

**Opción A — `tenant_id NULL` + índice parcial adicional**

Las fichas de infraestructura llevan `tenant_id = NULL`. Se añade un segundo
índice que sí garantiza la unicidad para ese caso:

```sql
-- Para fichas de infraestructura (tenant_id IS NULL): un solo registro por nombre
CREATE UNIQUE INDEX uq_fch_s_nombre_sistema
    ON bos.fch_ficha_state (ficha_name)
    WHERE tenant_id IS NULL;

-- Para fichas de aplicación (tenant_id NOT NULL): un registro por nombre+tenant
-- (ya cubierto por el UNIQUE existente)
```

*Ventaja:* `tenant_id NULL` es semánticamente preciso — la ficha no pertenece
a ningún tenant porque es compartida por todos.
*Consecuencia:* Dos constraints separados en vez de uno. El código Go debe
tratar `tenant_id = nil` como caso especial "infraestructura".

**Opción B — Tenant centinela `system`**

Se crea un tenant especial con UUID fijo conocido que representa al sistema
(ej. `00000000-0000-0000-0000-000000000001`). Todas las fichas de infraestructura
llevan ese UUID como `tenant_id`. El constraint `UNIQUE(ficha_name, tenant_id)`
funciona solo sin necesidad de índice extra.

```sql
-- El UNIQUE compuesto ya evita duplicados:
-- ficha_name='postgresql', tenant_id='00000000-...-0001' → OK
-- ficha_name='postgresql', tenant_id='00000000-...-0001' → ERROR (duplicado)
```

*Ventaja:* Un solo constraint. Todas las fichas tienen `tenant_id NOT NULL`.
*Consecuencia:* El tenant `system` debe existir en `bauth.idn_tenant` antes de
que BOS pueda registrar cualquier ficha de infraestructura. Durante el bootstrap
de capas 0-2 (antes de que bAuth exista), eso no es posible.

#### Relación con otras preguntas

Esta pregunta está relacionada con **Q3** y **Q8**: las tres tocan el mismo
problema arquitectónico — ¿puede BOS registrar información en su propia BD
antes de que bAuth exista? Si en Q8 se elige la opción que requiere que bAuth
exista primero, Q1 debería seguir la misma lógica y viceversa.

#### Cambio que se aplicará al DDL según la decisión

| Decisión | Cambio en `fch_ficha_state` |
|---|---|
| **Opción A** | Mantener `tenant_id NULL` permitido. Añadir `CREATE UNIQUE INDEX uq_fch_s_nombre_sistema ON bos.fch_ficha_state(ficha_name) WHERE tenant_id IS NULL;` |
| **Opción B** | Cambiar `tenant_id NULL REFERENCES` a `tenant_id UUID NOT NULL`. Definir UUID centinela del tenant sistema. Documentar en seeds. |

#### DECISIÓN APLICADA

```
Opción elegida: NINGUNA DE LAS ANTERIORES — la pregunta estaba mal planteada.

Decisión real: las fichas NO tienen tenant_id porque son componentes de plataforma
compartidos por todos los tenants. La multi-tenancy es un concepto de datos, no de
infraestructura. Crear instancias de fichas por tenant genera una explosión de recursos
imposible de administrar (100 apps × N tenants = N×100 fichas y bases de datos).

Cambios aplicados en v4.0.0:
  - Eliminado tenant_id de fch_ficha_state
  - UNIQUE(ficha_name, tenant_id) → UNIQUE(ficha_name, server_id)
  - Eliminado índice idx_fch_s_tenant
  - tenant_id en fch_ficha_event reencuadrado como dato de auditoría de origen
    (quién disparó el evento), no como indicador de propiedad de la ficha

Aprobado por: SKULL    Fecha: 2026-07-31
```

---

### Q3 — ¿Qué significa `tenant_id` en los eventos de bootstrap?

**Afecta:** `bos.ins_bootstrap_event` (T-NEW-3)
**Estado:** ✅ CERRADA — 2026-07-31

#### Contexto

Con la decisión Q1 aplicada, ya sabemos que las fichas son de plataforma y no
tienen dueño por tenant. La pregunta de Q3 cambia: ya no es "¿a quién pertenece
el evento?" sino **"¿qué operación de qué tenant disparó este paso del bootstrap?"**
— exactamente el mismo reencuadre que se aplicó a `fch_ficha_event`.

El bootstrap tiene 6 capas progresivas:

```
Capa 0 — Ubuntu OS y herramientas del host
Capa 1 — Kubernetes (kubeadm, Calico, Storage)
Capa 2 — Datos (PostgreSQL, Redis, MinIO)
──────────────────────────────────────────
  ↑ capas de sistema — no hay ningún tenant aún
──────────────────────────────────────────
Capa 3 — Identidad (Vault, Keycloak, Kong)  ← bAuth entra en operación
Capa 4 — Notificaciones (bNotify)
Capa 5 — Hardening final
```

En capas 0-2 se instala la plataforma base. No hay ningún tenant involucrado.
En capas 3-5 puede haber un operador humano (HITL) que disparó el proceso.

#### La pregunta real

¿El `tenant_id` en `ins_bootstrap_event` debe ser:

**Opción A — Siempre `NULL` en capas 0-2, UUID del tenant en capas 3-5**

`tenant_id = NULL` significa "evento de sistema sin tenant asociado". A partir
de capa 3, si el bootstrap está instalando la plataforma para un cliente
específico, `tenant_id = UUID` de ese cliente.

*Ventaja:* Preciso — en capa 0 realmente no hay tenant.
*Consecuencia:* Queries que buscan "todo el bootstrap del cliente X" no
incluirán las capas 0-2 automáticamente. Se necesita `bootstrap_run_id`
para agrupar todas las capas de un mismo intento (ya existe en la tabla).

**Opción B — `tenant_id NULL` siempre (bootstrap es siempre de sistema)**

El bootstrap instala la plataforma, no un tenant. Siempre `NULL`.
El `bootstrap_run_id` es el identificador de quién pidió el bootstrap.

*Ventaja:* Consistente con el principio Q1 — el bootstrap es de plataforma.
*Consecuencia:* No hay forma directa de saber "este bootstrap fue para el
cliente acme". Esa información viviría en otra tabla (ej. saga de instalación).

#### Cambio que se aplicará al DDL según la decisión

| Decisión | Cambio en `ins_bootstrap_event` |
|---|---|
| **Opción A** | Sin cambio. `tenant_id NULL` ya está en el DDL. Documentar en COMMENT que NULL = sistema. |
| **Opción B** | Cambiar COMMENT para aclarar que `tenant_id` es siempre NULL. Evaluar si la columna es necesaria o se elimina. |

#### DECISIÓN APLICADA

```
Opción elegida: NINGUNA DE LAS ANTERIORES — la premisa era incorrecta.

Decisión real: tenant_id es NOT NULL siempre. El tenant raíz (superadministrador
de tenants, registro #1) se carga mediante seed al crear la base de datos, antes
que cualquier otra operación. Siempre está disponible.

Comportamiento:
  - Capas 0-2 (sistema): tenant_id = UUID del tenant raíz
  - Capas 3-5 (cliente): tenant_id = UUID del tenant específico que se instala

El tenant raíz gobierna a todos los demás tenants. Provee el contexto de
auditoría para todas las operaciones de plataforma que ocurren antes de que
exista ningún tenant de cliente.

Cambios aplicados en v4.0.0:
  - tenant_id UUID NULL → tenant_id UUID NOT NULL en ins_bootstrap_event
  - COMMENT actualizado para documentar el comportamiento por capa

Aprobado por: SKULL    Fecha: 2026-07-31
```

---

### Q5 — ¿Cómo se elimina el historial antiguo de métricas de capacidad?

**Afecta:** `bos.cap_sistema_snapshot` (T-NEW-4)
**Estado:** ✅ CERRADA — 2026-07-31

#### Contexto

`cap_sistema_snapshot` recibe una fila cada 60 segundos. Con una retención de
90 días eso son aproximadamente **130.000 filas** (solo para el scope GLOBAL).
Si hay múltiples tenants con scope TENANT, el número se multiplica.

Sin una estrategia de eliminación, la tabla crece indefinidamente y las queries
del Motor Proyección (M5.2) se vuelven cada vez más lentas.

La retención de 90 días no es un capricho: es un requisito de la norma
ISO 27001:2022 A.12.4 (logging y monitoreo — retención definida y aplicada).

#### Opciones

**Opción A — Job de purga periódico en BOS**

El daemon BOS ejecuta una tarea programada que borra filas antiguas:

```sql
DELETE FROM bos.cap_sistema_snapshot
WHERE captured_at < now() - interval '90 days';
```

*Ventaja:* La tabla se define de forma simple, sin cambios estructurales.
El período de retención es configurable en `cap_tenant_politica` sin tocar
el schema.
*Consecuencia:* El `DELETE` sobre 130.000 filas a la vez puede generar
contención en la BD. Se mitiga con un job que borre por lotes pequeños.

**Opción B — Particionado mensual (`PARTITION BY RANGE`)**

La tabla se define con particiones automáticas por mes. Eliminar datos
antiguos es tan rápido como `DROP TABLE partition_name` — no toca ninguna
fila individualmente.

```sql
CREATE TABLE bos.cap_sistema_snapshot (...)
PARTITION BY RANGE (captured_at);

-- Se crea una partición por mes:
CREATE TABLE bos.cap_sistema_snapshot_2026_07
    PARTITION OF bos.cap_sistema_snapshot
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
```

*Ventaja:* Purga en milisegundos. Sin contención. Estándar en tablas de
alta escritura.
*Consecuencia:* La definición `CREATE TABLE` cambia significativamente.
Requiere un proceso que cree la partición del mes siguiente antes de que
llegue (se puede automatizar en BOS). Más complejo de mantener al inicio.

#### Cambio que se aplicará al DDL según la decisión

| Decisión | Cambio en `cap_sistema_snapshot` |
|---|---|
| **Opción A** | Sin cambio en el DDL. BOS implementa job de purga en `internal/capacity/`. |
| **Opción B** | Añadir `PARTITION BY RANGE (captured_at)` al `CREATE TABLE`. Añadir creación de particiones en el proceso de instalación del daemon. |

#### DECISIÓN APLICADA

```
Opción elegida: AMBAS — particionado mensual + cron de eliminación de particiones legacy.

Decisión real:
  - PARTITION BY RANGE (captured_at): la tabla está particionada mensualmente.
    Una partición por mes (bos.cap_sistema_snapshot_YYYY_MM).
  - BOS crea la partición del mes siguiente el día 25 de cada mes (cron interno).
  - Cron de purga: DROP TABLE sobre particiones cuyo rango termine hace más de
    90 días. DROP TABLE en una partición es instantáneo (sin contención, sin
    recorrer filas), a diferencia de DELETE que bloquea la tabla completa.

Por qué ambas:
  Las particiones resuelven el rendimiento de las queries (el planificador
  de PG elimina particiones no relevantes sin scan). El cron resuelve el
  crecimiento: sin él la tabla crece igualmente aunque esté particionada.
  Son complementarias, no excluyentes.

Cambios aplicados en v4.0.0:
  - PARTITION BY RANGE (captured_at) añadido al CREATE TABLE
  - PRIMARY KEY eliminada de la tabla padre (PG no lo permite en tablas
    particionadas con PK que no incluya la clave de partición)
  - Partición inicial bos.cap_sistema_snapshot_2026_07 añadida como ejemplo
  - Índices creados sobre la tabla padre (PG los propaga a particiones)
  - COMMENT ampliado con el protocolo de particionado y purga

Aprobado por: SKULL    Fecha: 2026-07-31
```

---

### Q7 — ¿Existe una política de capacidad por defecto para tenants sin configurar?

**Afecta:** `bos.cap_tenant_politica` (T-NEW-5)
**Estado:** ✅ CERRADA — 2026-07-31

#### Contexto

Cuando se crea un tenant nuevo, no tiene ninguna fila en `cap_tenant_politica`.
El Motor Políticas (M5.3) necesita saber qué umbrales aplicar antes de que el
operador configure la política del tenant.

#### DECISIÓN APLICADA

```
Opción elegida: VARIANTE de Opción B — fila del tenant raíz como fallback global.

Decisión real: el seed de creación de BD inserta tres registros maestros
simultáneamente:
  1. Tenant raíz (bauth.idn_tenant, tenant_id = UUID fijo, rol de superadmin)
  2. Empresa master (bauth.idn_identity_entity, nivel empresa)
  3. Sucursal master (bauth.idn_identity_entity, nivel sucursal)

Y junto a ellos se siembra también la política de capacidad del tenant raíz:
  INSERT INTO bos.cap_tenant_politica (tenant_id, ...) VALUES (<uuid_tenant_raiz>, ...)

El Motor M5.3 aplica este fallback:
  1. Buscar fila del tenant específico en cap_tenant_politica
  2. Si no existe → usar la fila del tenant raíz como plantilla global
  3. Ambas filas siempre existen (seed garantizado)

Ventaja sobre la Opción B original: tenant_id NOT NULL se mantiene sin excepciones.
Sin filas NULL, sin índices parciales. La política del tenant raíz es configurable
en caliente desde bosctl sin redespliegue (actualizar la fila del tenant raíz).

Cambios en el DDL: NINGUNO — cap_tenant_politica no cambia.
Cambios en el seed: añadir INSERT de política raíz junto al seed del tenant raíz.
Cambios en código Go: Motor M5.3 hace fallback al tenant raíz, no a NULL.

Aprobado por: SKULL    Fecha: 2026-07-31
```

---

### Q8 — ¿Las sesiones BOS referencian a bAuth por UUID o por slug de empresa?

**Afecta:** `bos.ctx_context_session` (T-396 — tabla EXISTENTE en el DDL)
**Estado:** ⏳ PENDIENTE

#### Contexto

La tabla `ctx_context_session` registra cada sesión activa de BOS. Una sesión
siempre pertenece a una empresa (organización cliente). Hoy el DDL define:

```sql
entity_1_id UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)
```

Esto significa que para crear una sesión, la empresa ya debe estar registrada
en bAuth como una `idn_identity_entity`.

El problema: durante el bootstrap de capas 0-2, BOS necesita contexto de
operación (sesión interna para trazabilidad), pero bAuth todavía no existe.
Si la FK es `NOT NULL`, BOS no puede crear ninguna sesión antes de que bAuth
esté operativo.

#### Opciones

**Opción A — Mantener el DDL actual (`entity_1_id UUID NOT NULL FK`)**

No se cambia nada. BOS sencillamente no crea sesiones durante las capas 0-2
del bootstrap — opera en "modo preflight" sin sesión de contexto. Solo a
partir de la capa 3 (cuando bAuth está operativo) BOS crea sesiones.

*Ventaja:* Integridad referencial fuerte. Sin ambigüedad en la BD.
*Consecuencia:* BOS no puede usar `ctx_id` en los eventos de las capas 0-2.
Esos eventos van con `ctx_id = 'system'` (texto fijo, sin sesión real).
La trazabilidad en las capas 0-2 es más limitada.

**Opción B — Cambiar a `empresa_slug TEXT NOT NULL` (sin FK)**

En lugar de referenciar a bAuth por UUID, se usa el slug de la empresa
(ej. `"acme-corp"`). No hay FK — el slug es solo un texto identificador.

*Ventaja:* BOS opera completamente autónomo. Puede crear sesiones en capa 0.
*Consecuencia:* Sin integridad referencial. La BD no garantiza que el slug
corresponda a una empresa real en bAuth. Pueden quedar sesiones huérfanas
si el slug cambia en bAuth.

**Opción C — Híbrido: `entity_1_id UUID NULL FK` + `empresa_slug TEXT NOT NULL`**

Se mantiene la FK pero se hace nullable. Se añade `empresa_slug TEXT NOT NULL`
que siempre tiene valor. Durante capas 0-2: `entity_1_id = NULL`,
`empresa_slug = "sistema"`. A partir de capa 3: ambos campos tienen valor.

*Ventaja:* BOS puede crear sesiones en cualquier capa. En capa 3+ hay
integridad referencial fuerte. El slug permite trazabilidad desde el día 0.
*Consecuencia:* Dos columnas para representar la misma entidad en distintas
fases del ciclo de vida. La lógica de la app debe mantener la coherencia
entre ambas.

#### Cambio que se aplicará al DDL según la decisión

| Decisión | Cambio en `ctx_context_session` |
|---|---|
| **Opción A** | Sin cambio en el DDL. Cambio de comportamiento en el código Go (no crear sesión en capas 0-2). |
| **Opción B** | Eliminar `entity_1_id UUID NOT NULL FK`. Añadir `empresa_slug TEXT NOT NULL`. Eliminar también `entity_2_id UUID NULL FK`. |
| **Opción C** | `entity_1_id UUID NOT NULL FK` → `entity_1_id UUID NULL`. Añadir `empresa_slug TEXT NOT NULL DEFAULT 'sistema'`. |

#### DECISIÓN APLICADA

```
Opción elegida: Opción A — mantener el DDL actual sin cambios.

Decisión real: el seed de creación de BD siembra la empresa master y la
sucursal master como entidades en bauth.idn_identity_entity ANTES de que
comience cualquier operación de BOS. Esto hace que entity_1_id UUID NOT NULL
sea siempre satisfacible:

  Seed inicial (orden garantizado):
    1. bauth.idn_tenant            ← tenant raíz (superadmin de tenants)
    2. bauth.idn_identity_entity   ← empresa master  (entity_1_id de sesiones)
    3. bauth.idn_identity_entity   ← sucursal master (entity_2_id opcional)
    4. bos.cap_tenant_politica     ← política del tenant raíz (ver Q7)

  Las sesiones de BOS durante capas 0-2 usan entity_1_id = UUID de la empresa
  master (siempre disponible desde el seed). No hay período sin empresa.

Por qué no Opción C (híbrido): innecesario. La empresa master siempre existe.
Añadir empresa_slug como segunda columna duplicaría la identidad y crearía
coherencia adicional que mantener.

Cambios en el DDL: NINGUNO — ctx_context_session no cambia.
Cambios en el seed: la empresa master y sucursal master deben ser los primeros
registros de bauth.idn_identity_entity, sembrados en el mismo script de
creación de BD que el tenant raíz.

Aprobado por: SKULL    Fecha: 2026-07-31
```

---

*SKULL · SBOS · BosAgent — Propuesta DDL v5.0.0 · Julio 2026 · ✅ TODAS LAS PREGUNTAS HITL CERRADAS*
