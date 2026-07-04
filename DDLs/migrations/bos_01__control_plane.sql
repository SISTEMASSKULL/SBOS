-- ======================================================================
-- DDL_bos_schema.sql — BOS IAM Installer: Control Plane Tables
-- Schema: bos (declarado en DDL_skSBOS_db.sql línea 53)
-- Base de datos: skSBOS_db
-- PostgreSQL 18.4 · UUIDv7 PKs · Idempotente N ejecuciones
--
-- Tablas:
--   bos.registered_device  — Context Plane: dispositivos pre-auth (SBOS-049)
--   bos.context_session     — Context Plane: sesiones post-auth (SBOS-049)
--   bos.ficha_state         — Estado actual de cada ficha (ADR-021, 18 estados)
--   bos.ficha_event         — Historial inmutable de eventos por ficha
--   bos.bootstrap_event     — Registro de eventos de bootstrap
--   bos.cap_snapshot        — Instantáneas de métricas de capacidad (M5.1)
--   bos.cap_estimate        — Configuración de capacidad declarada por tenant
--
-- Estándares: SBOS-049 (Context Plane) · ADR-021 (18 estados ficha)
--             ADR-019/020 (Interface Dual) · ISO 27001:2022 A.8.15
--             NIST 800-207 ZTA · RFC 9562 (UUIDv7) · RFC 9470 (LoA)
--
-- IDEMPOTENCIA: ejecutable N veces sin errores.
--   1ª ejecución → CREATES
--   2ª+ ejecución → NOTICEs suprimidos por client_min_messages = WARNING
--
-- Nota de migración: las tablas `registered_devices` y `context_sessions`
--   creadas por bos.ctx.auto_migrate en public/sbos_db son la versión
--   provisional. Este DDL es la versión formal en schema bos.
--   El código Go debe migrar de queries sin schema a bos.<tabla>.
-- ======================================================================

SET lock_timeout = '5s';
SET client_min_messages = WARNING;
-- search_path incluye bos para que COMMENT ON INDEX encuentre los índices del schema
SET search_path TO bos, public;

-- ══════════════════════════════════════════════════════════════════════
-- ENUM TYPES — Dominios controlados del BOS Control Plane
-- ══════════════════════════════════════════════════════════════════════

-- 7 estados del ciclo de vida de contexto (SBOS-049 §16.1)
DO $$ BEGIN
  CREATE TYPE bos_context_state_enum AS ENUM (
    'PENDIENTE',   -- registrado, aún no validado
    'ACTIVO',      -- validado, operativo (estado normal de sesión)
    'SUSPENDIDO',  -- suspendido por administración (tenant o usuario)
    'BLOQUEADO',   -- bloqueado por política de seguridad
    'INVALIDADO',  -- terminal — logout explícito o revocación
    'EXPIRADO',    -- terminal — TTL agotado
    'ARCHIVADO'    -- terminal — movido a histórico, inmutable
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 18 estados del ciclo de vida de una ficha (ADR-021)
DO $$ BEGIN
  CREATE TYPE bos_ficha_state_enum AS ENUM (
    'PENDIENTE',                 -- declarada, dependencias verificándose
    'LISTA',                     -- dependencias OK, esperando DAG topológico
    'INSTALANDO',                -- saga install en progreso (timeout 30min)
    'INSTALADA',                 -- pod Running + health OK + hashes registrados
    'ACTUALIZACION_DISPONIBLE',  -- nueva versión detectada, sin evaluar
    'ACTUALIZACION_APROBADA',    -- tests OK, sin degradación, pendiente update
    'ACTUALIZANDO',              -- saga update en progreso (timeout 15min)
    'DEGRADADA',                 -- funciona con capacidad reducida
    'ERROR_FISICO',              -- disco, red, CPU, memoria — causa externa
    'ERROR_LOGICO',              -- config, deps, schema drift — causa interna
    'REPARANDO',                 -- diagnóstico + repair en progreso (timeout 10min)
    'ERROR_NO_CORREGIBLE',       -- crítico — agotados reintentos, requiere HITL
    'FALLA_INSTALACION',         -- saga install falló, evaluar rollback
    'FALLA_ACTUALIZACION',       -- saga update falló, evaluar rollback
    'ROLLBACK',                  -- restaurando versión anterior estable
    'LIMPIEZA',                  -- eliminando artefactos de operación fallida
    'PAUSADA',                   -- suspendida por admin (mantenimiento)
    'DESINSTALADA'               -- removida del sistema
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Etapas del bootstrap por capas (SBOS-BOOTSTRAP-MANUAL.md — 6 capas)
DO $$ BEGIN
  CREATE TYPE bos_bootstrap_stage_enum AS ENUM (
    'PREFLIGHT',     -- Capa 0: verificaciones previas (C-01..C-08)
    'K8S_INIT',      -- Capa 1a: inicialización kubeadm
    'CALICO',        -- Capa 1b: CNI Calico 3.32.0
    'POSTGRESQL',    -- Capa 2a: PostgreSQL 18.4
    'REDIS',         -- Capa 2b: Redis 8.6.2
    'KEYCLOAK',      -- Capa 3: Keycloak 26.6.2
    'VAULT',         -- Capa 4: Vault 2.0.1
    'KONG',          -- Capa 5: Kong 3.9.x LTS
    'VERIFY',        -- Verificación post-instalación
    'COMPLETED',     -- Bootstrap completado exitosamente
    'FAILED'         -- Bootstrap fallido
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Resultado de cada evento de bootstrap
DO $$ BEGIN
  CREATE TYPE bos_bootstrap_result_enum AS ENUM (
    'RUNNING',  -- en progreso
    'OK',       -- exitoso
    'WARN',     -- advertencia (continúa)
    'FAIL',     -- fallo (puede abortar)
    'SKIP'      -- omitido (ya estaba completo)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 1: bos.registered_device
-- Propósito: DeviceContext pre-autenticación (SBOS-049 §16.1).
--   Registra dispositivos (terminales, nodos K8s, VDI) que solicitan
--   identidad en el ecosistema SBOS. Un dispositivo recibe dctx_id
--   al encenderse (pre-auth, BitMask == 0) y es promovido a
--   context_session en el primer login de usuario.
-- Dueño: BOS Control Plane (bos.ctx.device.register)
-- Estándares: SBOS-049, ISO 27001:2022 A.9.4.2 (TTL 8h)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.registered_device (
    device_id    UUID                    PRIMARY KEY DEFAULT uuidv7(),
    dctx_id      VARCHAR(64)             NOT NULL,
    hostname     VARCHAR(255)            NOT NULL,
    tenant_id    VARCHAR(64)             NOT NULL,
    node_k8s     VARCHAR(255),
    ip           INET,
    state        bos_context_state_enum  NOT NULL DEFAULT 'PENDIENTE',
    created_at   TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ             NOT NULL,

    CONSTRAINT uq_registered_device_dctx_id UNIQUE (dctx_id)
);

COMMENT ON TABLE  bos.registered_device IS '[SBOS-049 §16.1] DeviceContext pre-autenticación. Un dispositivo registrado recibe dctx_id (pre-auth, BitMask==0) y es promovido a context_session en el primer login. TTL máximo: 8h (ISO 27001:2022 A.9.4.2).';
COMMENT ON COLUMN bos.registered_device.device_id   IS '[RFC 9562] PK interna UUIDv7. Generada automáticamente.';
COMMENT ON COLUMN bos.registered_device.dctx_id     IS '[SBOS-049] Clave natural del dispositivo. Formato: dctx-{8-bytes-hex}. UNIQUE. Generada por BOS en RegisterDevice.';
COMMENT ON COLUMN bos.registered_device.hostname     IS 'FQDN o hostname del dispositivo. Ejemplo: caja-01.skull.local, node-01.k8s.skull.bo.';
COMMENT ON COLUMN bos.registered_device.tenant_id   IS 'Tenant al que pertenece el dispositivo. FK lógica a bauth.idn_tenant(tenant_slug).';
COMMENT ON COLUMN bos.registered_device.node_k8s    IS 'Nodo K8s donde corre el workload. NULL si es dispositivo físico (VDI, POS, caja).';
COMMENT ON COLUMN bos.registered_device.ip          IS '[INET] IP del dispositivo al registrarse. Puede cambiar (DHCP) — se actualiza en cada registro.';
COMMENT ON COLUMN bos.registered_device.state       IS '[SBOS-049] Ciclo de vida: PENDIENTE→ACTIVO→(SUSPENDIDO|BLOQUEADO|INVALIDADO|EXPIRADO|ARCHIVADO). DeviceContext solo llega a ACTIVO tras primer Promote.';
COMMENT ON COLUMN bos.registered_device.created_at  IS '[ISO 27001:2022 A.8.15] Timestamp de creación del registro.';
COMMENT ON COLUMN bos.registered_device.updated_at  IS '[ISO 27001:2022 A.8.15] Timestamp de última modificación.';
COMMENT ON COLUMN bos.registered_device.expires_at  IS '[ISO 27001:2022 A.9.4.2] TTL máximo del DeviceContext: NOW() + 8h. Pasado este tiempo, state→EXPIRADO.';

CREATE INDEX IF NOT EXISTS idx_bos_registered_device_tenant_state
    ON bos.registered_device (tenant_id, state);
COMMENT ON INDEX idx_bos_registered_device_tenant_state IS 'Lookup de dispositivos por tenant y estado. Leading: tenant_id (baja cardinalidad por tenant).';

CREATE INDEX IF NOT EXISTS idx_bos_registered_device_expires
    ON bos.registered_device (expires_at)
    WHERE state NOT IN ('INVALIDADO', 'EXPIRADO', 'ARCHIVADO');
COMMENT ON INDEX idx_bos_registered_device_expires IS 'Índice parcial para limpieza de dispositivos expirados. Solo filas activas.';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 2: bos.context_session
-- Propósito: SessionContext post-autenticación (SBOS-049 §5).
--   Se crea al hacer login (Promote o Create); se destruye al logout
--   (Invalidate) o por TTL. Vincula dctx_id para preservar historia
--   pre-auth. Contiene BitMask > 0 (invariante post-auth).
-- Dueño: BOS Control Plane (bos.ctx.promote, bos.ctx.create)
-- Estándares: SBOS-049, RFC 9470 (LoA 1-4), W3C Trace Context
--             ISO 27001:2022 A.9.4.2 (TTL 12h)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.context_session (
    session_id   UUID                    PRIMARY KEY DEFAULT uuidv7(),
    ctx_id       VARCHAR(64)             NOT NULL,
    dctx_id      VARCHAR(64),
    tenant_id    VARCHAR(64)             NOT NULL,
    empresa_id   VARCHAR(64),
    sucursal_id  VARCHAR(64),
    pos_logico   VARCHAR(64),
    user_id      VARCHAR(128)            NOT NULL,
    bitmask      BIGINT                  NOT NULL DEFAULT 0,
    loa          SMALLINT                NOT NULL DEFAULT 1,
    state        bos_context_state_enum  NOT NULL DEFAULT 'ACTIVO',
    traceparent  VARCHAR(128),
    created_at   TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ             NOT NULL,

    CONSTRAINT uq_context_session_ctx_id UNIQUE (ctx_id),
    CONSTRAINT chk_context_session_loa   CHECK (loa BETWEEN 1 AND 4),
    CONSTRAINT fk_context_session_device FOREIGN KEY (dctx_id)
        REFERENCES bos.registered_device (dctx_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

COMMENT ON TABLE  bos.context_session IS '[SBOS-049 §5] SessionContext post-autenticación. BitMask > 0 (invariante post-auth). TTL máximo: 12h (ISO 27001:2022 A.9.4.2). Se invalida por logout o TTL. Referencia al dctx_id origen para trazabilidad pre-auth.';
COMMENT ON COLUMN bos.context_session.session_id   IS '[RFC 9562] PK interna UUIDv7. Generada automáticamente.';
COMMENT ON COLUMN bos.context_session.ctx_id       IS '[SBOS-049] Clave natural de la sesión. Formato: ctx-{8-bytes-hex}. UNIQUE. Propagado como header ctx_id en todas las operaciones del ecosistema.';
COMMENT ON COLUMN bos.context_session.dctx_id      IS '[SBOS-049] Dispositivo origen. FK a registered_device.dctx_id. NULL si la sesión fue creada directamente (bos.ctx.create sin Promote).';
COMMENT ON COLUMN bos.context_session.tenant_id    IS 'Tenant de la sesión. FK lógica a bauth.idn_tenant(tenant_slug).';
COMMENT ON COLUMN bos.context_session.empresa_id   IS 'Empresa activa en la sesión. Puede cambiar con bos.ctx.switch.';
COMMENT ON COLUMN bos.context_session.sucursal_id  IS 'Sucursal activa en la sesión.';
COMMENT ON COLUMN bos.context_session.pos_logico   IS 'Punto de operación lógico (POS, caja, workstation).';
COMMENT ON COLUMN bos.context_session.user_id      IS 'Usuario autenticado. UUID o slug de bAuth.';
COMMENT ON COLUMN bos.context_session.bitmask      IS '[SBOS-021] BitMask 64-bit calculado por bAuth. > 0 en toda SessionContext (invariante post-auth). Codifica permisos de roles.';
COMMENT ON COLUMN bos.context_session.loa          IS '[RFC 9470] Level of Assurance 1-4. 1=password, 2=MFA, 3=biométrico, 4=hardware key.';
COMMENT ON COLUMN bos.context_session.state        IS '[SBOS-049] Ciclo de vida. ACTIVO es el estado inicial. Terminal: INVALIDADO, EXPIRADO, ARCHIVADO.';
COMMENT ON COLUMN bos.context_session.traceparent  IS '[W3C Trace Context] Header traceparent al momento de creación. Formato: 00-{traceId}-{parentId}-{flags}.';
COMMENT ON COLUMN bos.context_session.created_at   IS '[ISO 27001:2022 A.8.15] Timestamp de creación de la sesión.';
COMMENT ON COLUMN bos.context_session.expires_at   IS '[ISO 27001:2022 A.9.4.2] TTL máximo: NOW() + 12h. Pasado este tiempo, state→EXPIRADO.';

CREATE INDEX IF NOT EXISTS idx_bos_context_session_tenant_state
    ON bos.context_session (tenant_id, state);
COMMENT ON INDEX idx_bos_context_session_tenant_state IS 'Lookup de sesiones activas por tenant (bos.ctx.list, Kong plugin).';

CREATE INDEX IF NOT EXISTS idx_bos_context_session_dctx
    ON bos.context_session (dctx_id)
    WHERE dctx_id IS NOT NULL;
COMMENT ON INDEX idx_bos_context_session_dctx IS 'Índice parcial para buscar sesiones de un dispositivo (Promote, diagnóstico).';

CREATE INDEX IF NOT EXISTS idx_bos_context_session_user
    ON bos.context_session (tenant_id, user_id, state);
COMMENT ON INDEX idx_bos_context_session_user IS 'Sesiones activas de un usuario en un tenant (logout masivo, seguridad).';

CREATE INDEX IF NOT EXISTS idx_bos_context_session_expires
    ON bos.context_session (expires_at)
    WHERE state = 'ACTIVO';
COMMENT ON INDEX idx_bos_context_session_expires IS 'Índice parcial para monitor de TTL y limpieza de sesiones expiradas.';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 3: bos.ficha_state
-- Propósito: Estado actual de cada ficha gestionada por BOS.
--   Una fila por ficha — representa el snapshot de estado presente.
--   El historial de transiciones va en bos.ficha_event.
-- Dueño: BOS Control Plane (saga install/update/repair/remove)
-- Estándares: ADR-021 (18 estados), SBOS-019 (fichas declarativas)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.ficha_state (
    ficha_state_id      UUID                  PRIMARY KEY DEFAULT uuidv7(),
    ficha_id            TEXT                  NOT NULL,
    server_id           TEXT                  NOT NULL,
    state               bos_ficha_state_enum  NOT NULL DEFAULT 'PENDIENTE',
    version_installed   TEXT,
    version_available   TEXT,
    install_attempts    SMALLINT              NOT NULL DEFAULT 0,
    last_error          TEXT,
    installed_at        TIMESTAMPTZ,
    last_health_check   TIMESTAMPTZ,
    ctx_id              TEXT                  NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_ficha_state_ficha_id UNIQUE (ficha_id),
    CONSTRAINT chk_ficha_state_attempts CHECK (install_attempts >= 0)
);

COMMENT ON TABLE  bos.ficha_state IS '[ADR-021] Estado actual de cada ficha en el sistema BOS. Una fila por ficha. Los 18 estados definen su ciclo de vida completo. El historial de transiciones está en bos.ficha_event.';
COMMENT ON COLUMN bos.ficha_state.ficha_state_id    IS '[RFC 9562] PK interna UUIDv7.';
COMMENT ON COLUMN bos.ficha_state.ficha_id          IS '[SBOS-019] Clave natural de la ficha. Nombre/slug único. Ejemplo: postgresql, redis, keycloak, bos-preflight. UNIQUE.';
COMMENT ON COLUMN bos.ficha_state.server_id         IS 'Servidor lógico donde reside la ficha. Ejemplo: S01, S03, S-HOST. Ver PORT-CATALOG §5.';
COMMENT ON COLUMN bos.ficha_state.state             IS '[ADR-021] Estado actual del ciclo de vida. 18 valores posibles. Iniciado en PENDIENTE.';
COMMENT ON COLUMN bos.ficha_state.version_installed IS 'Versión instalada actualmente. Formato: vX.Y.Z. NULL si no está instalada.';
COMMENT ON COLUMN bos.ficha_state.version_available IS 'Última versión disponible en el canal de release. NULL si no hay actualización detectada.';
COMMENT ON COLUMN bos.ficha_state.install_attempts  IS 'Contador de intentos de instalación en el ciclo actual. Reinicia a 0 en nueva saga.';
COMMENT ON COLUMN bos.ficha_state.last_error        IS 'Último mensaje de error. NULL si el estado es exitoso. Persiste hasta corrección o nueva instalación.';
COMMENT ON COLUMN bos.ficha_state.installed_at      IS 'Timestamp de la última instalación exitosa (state→INSTALADA).';
COMMENT ON COLUMN bos.ficha_state.last_health_check IS 'Timestamp del último health check ejecutado por BOS.';
COMMENT ON COLUMN bos.ficha_state.ctx_id            IS '[SBOS-049] Contexto operativo de la última operación. DEFAULT system para bootstrapping.';
COMMENT ON COLUMN bos.ficha_state.created_at        IS '[ISO 27001:2022 A.8.15] Timestamp de creación del registro.';
COMMENT ON COLUMN bos.ficha_state.updated_at        IS '[ISO 27001:2022 A.8.15] Timestamp de última modificación.';

CREATE INDEX IF NOT EXISTS idx_bos_ficha_state_server_state
    ON bos.ficha_state (server_id, state);
COMMENT ON INDEX idx_bos_ficha_state_server_state IS 'Fichas agrupadas por servidor y estado. Para dashboards de salud por servidor.';

CREATE INDEX IF NOT EXISTS idx_bos_ficha_state_error
    ON bos.ficha_state (state)
    WHERE state IN ('ERROR_FISICO', 'ERROR_LOGICO', 'ERROR_NO_CORREGIBLE', 'DEGRADADA');
COMMENT ON INDEX idx_bos_ficha_state_error IS 'Índice parcial para alertas rápidas de fichas en estado de error.';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 4: bos.ficha_event
-- Propósito: Log inmutable de eventos del ciclo de vida de fichas.
--   Append-only. Cada transición de estado, cada operación de saga,
--   cada health check queda registrado permanentemente.
--   Permite auditoría, diagnóstico y reconstrucción de historial.
-- Dueño: BOS Control Plane (inmutable — solo INSERT)
-- Estándares: ISO 27001:2022 A.8.15, ADR-021
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.ficha_event (
    ficha_event_id   UUID                  PRIMARY KEY DEFAULT uuidv7(),
    ficha_id         TEXT                  NOT NULL,
    from_state       bos_ficha_state_enum,
    to_state         bos_ficha_state_enum  NOT NULL,
    event_type       TEXT                  NOT NULL,
    operator         TEXT                  NOT NULL DEFAULT 'system',
    details          JSONB,
    duration_ms      INTEGER,
    ctx_id           TEXT                  NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_ficha_event_ficha FOREIGN KEY (ficha_id)
        REFERENCES bos.ficha_state (ficha_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMENT ON TABLE  bos.ficha_event IS '[ADR-021][ISO 27001:2022 A.8.15] Log inmutable de eventos del ciclo de vida de fichas. Append-only. Registra toda transición de estado, saga y health check. No tiene updated_at — es inmutable por diseño.';
COMMENT ON COLUMN bos.ficha_event.ficha_event_id IS '[RFC 9562] PK interna UUIDv7.';
COMMENT ON COLUMN bos.ficha_event.ficha_id       IS 'Ficha que generó el evento. FK a ficha_state.ficha_id.';
COMMENT ON COLUMN bos.ficha_event.from_state     IS '[ADR-021] Estado anterior. NULL en el primer evento (creación de la ficha).';
COMMENT ON COLUMN bos.ficha_event.to_state       IS '[ADR-021] Estado nuevo tras el evento.';
COMMENT ON COLUMN bos.ficha_event.event_type     IS 'Tipo de evento. Valores: INSTALL_START, INSTALL_OK, INSTALL_FAIL, UPDATE_START, UPDATE_OK, UPDATE_FAIL, REPAIR_START, REPAIR_OK, REPAIR_FAIL, ROLLBACK_START, ROLLBACK_OK, ROLLBACK_FAIL, HEALTH_OK, HEALTH_FAIL, REMOVE, PAUSE, RESUME, CLEANUP.';
COMMENT ON COLUMN bos.ficha_event.operator       IS 'Quién disparó el evento. system=BOS automático, bosctl=CLI, api=Core UI, saga=compensación automática.';
COMMENT ON COLUMN bos.ficha_event.details        IS 'Detalles adicionales del evento. Estructura varía por event_type. Ejemplo: {pod_name, namespace, exit_code, stdout_tail}.';
COMMENT ON COLUMN bos.ficha_event.duration_ms    IS 'Duración de la operación en milisegundos. NULL para eventos instantáneos.';
COMMENT ON COLUMN bos.ficha_event.ctx_id         IS '[SBOS-049] Contexto operativo del evento. DEFAULT system para operaciones de BOS.';
COMMENT ON COLUMN bos.ficha_event.created_at     IS '[ISO 27001:2022 A.8.15] Timestamp de creación del evento. Inmutable.';

CREATE INDEX IF NOT EXISTS idx_bos_ficha_event_ficha_time
    ON bos.ficha_event (ficha_id, created_at DESC);
COMMENT ON INDEX idx_bos_ficha_event_ficha_time IS 'Historial de eventos de una ficha ordenado por tiempo (más reciente primero).';

CREATE INDEX IF NOT EXISTS idx_bos_ficha_event_type_time
    ON bos.ficha_event (event_type, created_at DESC);
COMMENT ON INDEX idx_bos_ficha_event_type_time IS 'Búsqueda de eventos por tipo a través de todas las fichas (análisis de fallos).';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 5: bos.bootstrap_event
-- Propósito: Registro de eventos del proceso de bootstrap.
--   Append-only. Cada etapa del bootstrap (preflight, k8s, postgresql,
--   etc.) genera eventos que quedan permanentemente registrados.
--   Permite diagnóstico post-mortem y métricas de tiempo de bootstrap.
-- Dueño: BOS Bootstrap Engine (inmutable — solo INSERT)
-- Estándares: ISO 27001:2022 A.8.15, SBOS-BOOTSTRAP-MANUAL.md
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.bootstrap_event (
    bootstrap_event_id   UUID                        PRIMARY KEY DEFAULT uuidv7(),
    run_id               TEXT                        NOT NULL,
    stage                bos_bootstrap_stage_enum    NOT NULL,
    result               bos_bootstrap_result_enum   NOT NULL DEFAULT 'RUNNING',
    layer                SMALLINT                    NOT NULL,
    message              TEXT,
    details              JSONB,
    duration_ms          INTEGER,
    criterion_id         TEXT,
    ctx_id               TEXT                        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_bootstrap_event_layer CHECK (layer BETWEEN 0 AND 5)
);

COMMENT ON TABLE  bos.bootstrap_event IS '[SBOS-BOOTSTRAP-MANUAL.md][ISO 27001:2022 A.8.15] Registro inmutable de eventos del proceso de bootstrap. Append-only. Agrupa eventos por run_id. 6 capas (0=preflight, 1=k8s, 2=data, 3=identity, 4=secrets, 5=gateway).';
COMMENT ON COLUMN bos.bootstrap_event.bootstrap_event_id IS '[RFC 9562] PK interna UUIDv7.';
COMMENT ON COLUMN bos.bootstrap_event.run_id             IS 'Agrupa todos los eventos de una ejecución de bootstrap. Formato: boot-{timestamp}-{hex}. Permite filtrar un bootstrap específico.';
COMMENT ON COLUMN bos.bootstrap_event.stage              IS 'Etapa del bootstrap que generó este evento. Sigue el orden cronológico del SBOS-BOOTSTRAP-MANUAL.md.';
COMMENT ON COLUMN bos.bootstrap_event.result             IS 'Resultado del evento: RUNNING (en progreso), OK (exitoso), WARN (advertencia), FAIL (fallo), SKIP (ya existía).';
COMMENT ON COLUMN bos.bootstrap_event.layer              IS 'Capa del bootstrap: 0=preflight, 1=k8s+calico, 2=postgresql+redis, 3=keycloak, 4=vault, 5=kong.';
COMMENT ON COLUMN bos.bootstrap_event.message            IS 'Mensaje legible por humanos del evento. Ejemplo: "PostgreSQL 18.4 Running — pod ready".';
COMMENT ON COLUMN bos.bootstrap_event.details            IS 'Detalles técnicos del evento. Ejemplo: {pod_name, namespace, exit_code, k8s_events, helm_chart_version}.';
COMMENT ON COLUMN bos.bootstrap_event.duration_ms        IS 'Duración de la etapa en milisegundos. NULL si aún RUNNING.';
COMMENT ON COLUMN bos.bootstrap_event.criterion_id       IS 'ID del criterio de verificación. Ejemplo: C-01, C-02, ..., C-08. NULL si no es un criterio.';
COMMENT ON COLUMN bos.bootstrap_event.ctx_id             IS '[SBOS-049] Contexto operativo. DEFAULT system durante bootstrap inicial.';
COMMENT ON COLUMN bos.bootstrap_event.created_at         IS '[ISO 27001:2022 A.8.15] Timestamp del evento. Inmutable.';

CREATE INDEX IF NOT EXISTS idx_bos_bootstrap_event_run_layer
    ON bos.bootstrap_event (run_id, layer, created_at);
COMMENT ON INDEX idx_bos_bootstrap_event_run_layer IS 'Recupera todos los eventos de un bootstrap ordenados por capa y tiempo.';

CREATE INDEX IF NOT EXISTS idx_bos_bootstrap_event_stage_result
    ON bos.bootstrap_event (stage, result);
COMMENT ON INDEX idx_bos_bootstrap_event_stage_result IS 'Análisis de fallos por etapa de bootstrap a través de múltiples runs.';

CREATE INDEX IF NOT EXISTS idx_bos_bootstrap_event_criterion
    ON bos.bootstrap_event (criterion_id)
    WHERE criterion_id IS NOT NULL;
COMMENT ON INDEX idx_bos_bootstrap_event_criterion IS 'Índice parcial para buscar resultados de criterios C-01..C-08 rápidamente.';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 6: bos.cap_snapshot
-- Propósito: Instantáneas de métricas del Motor de Observación (M5.1).
--   Append-only. BOS recoge ~30 métricas cada 60s y las inserta aquí.
--   Permite análisis de tendencias, alertas y proyecciones de capacidad.
--   Retención recomendada: 90 días inline, archivado a MinIO S-HOST.
-- Dueño: BOS Motor de Observación (internal/capacity/collector.go)
-- Estándares: ISO 27001:2022 A.8.15, M5.1 Plan Maestro v3
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.cap_snapshot (
    snapshot_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id                TEXT        NOT NULL,

    -- Métricas de host (CPU / RAM / Disco)
    cpu_pct                  NUMERIC(5,2),
    ram_used_mb              INTEGER,
    ram_total_mb             INTEGER,
    disk_used_gb             NUMERIC(10,2),
    disk_total_gb            NUMERIC(10,2),

    -- PostgreSQL 18.4
    pg_connections_active    SMALLINT,
    pg_connections_max       SMALLINT,
    pg_db_size_mb            INTEGER,
    pg_replication_lag_ms    INTEGER,

    -- Redis 8.6.2
    redis_mem_used_mb        INTEGER,
    redis_mem_peak_mb        INTEGER,
    redis_keys_count         INTEGER,
    redis_ops_per_sec        INTEGER,

    -- Kubernetes (fichas K8s)
    k8s_pod_count            SMALLINT,
    k8s_pod_running          SMALLINT,
    k8s_pod_failed           SMALLINT,
    k8s_pod_pending          SMALLINT,
    k8s_node_count           SMALLINT,
    k8s_node_ready           SMALLINT,

    -- Context Plane (SBOS-049)
    ctx_sessions_active      INTEGER,
    ctx_sessions_total       INTEGER,
    ctx_devices_registered   INTEGER,
    ctx_devices_active       SMALLINT,

    -- BOS Fichas
    fichas_installed         SMALLINT,
    fichas_healthy           SMALLINT,
    fichas_degraded          SMALLINT,
    fichas_error             SMALLINT,
    fichas_updating          SMALLINT,

    -- Extensible
    extra_metrics            JSONB,

    ctx_id                   TEXT        NOT NULL DEFAULT 'system',
    captured_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  bos.cap_snapshot IS '[M5.1 Motor Observación] Instantáneas de métricas del cluster. ~30 métricas cada 60s. Append-only. Retención: 90 días inline. Permite proyecciones lineales de capacidad (M5.2) y alertas por política (M5.3).';
COMMENT ON COLUMN bos.cap_snapshot.snapshot_id           IS '[RFC 9562] PK interna UUIDv7.';
COMMENT ON COLUMN bos.cap_snapshot.tenant_id             IS 'Tenant para el que se tomó la instantánea. system=métricas globales del cluster.';
COMMENT ON COLUMN bos.cap_snapshot.cpu_pct               IS 'Uso de CPU del host en porcentaje. Promedio de todos los cores.';
COMMENT ON COLUMN bos.cap_snapshot.ram_used_mb           IS 'RAM usada en MB (excluyendo cache de OS).';
COMMENT ON COLUMN bos.cap_snapshot.ram_total_mb          IS 'RAM total del host en MB.';
COMMENT ON COLUMN bos.cap_snapshot.disk_used_gb          IS 'Espacio de disco usado en GB (partición SBOS).';
COMMENT ON COLUMN bos.cap_snapshot.disk_total_gb         IS 'Espacio de disco total en GB.';
COMMENT ON COLUMN bos.cap_snapshot.pg_connections_active IS 'Conexiones PostgreSQL activas al momento del snapshot.';
COMMENT ON COLUMN bos.cap_snapshot.pg_connections_max    IS 'max_connections configurado en PostgreSQL.';
COMMENT ON COLUMN bos.cap_snapshot.pg_db_size_mb         IS 'Tamaño de sbos_db en MB.';
COMMENT ON COLUMN bos.cap_snapshot.pg_replication_lag_ms IS 'Lag de replicación PostgreSQL en ms. NULL si no hay réplica.';
COMMENT ON COLUMN bos.cap_snapshot.redis_mem_used_mb     IS 'Memoria Redis usada en MB (used_memory).';
COMMENT ON COLUMN bos.cap_snapshot.redis_mem_peak_mb     IS 'Pico de memoria Redis en MB (used_memory_peak).';
COMMENT ON COLUMN bos.cap_snapshot.redis_keys_count      IS 'Total de keys en Redis (todas las DBs).';
COMMENT ON COLUMN bos.cap_snapshot.redis_ops_per_sec     IS 'Operaciones Redis por segundo (instantaneous_ops_per_sec).';
COMMENT ON COLUMN bos.cap_snapshot.k8s_pod_count         IS 'Total de pods en el namespace SBOS.';
COMMENT ON COLUMN bos.cap_snapshot.k8s_pod_running       IS 'Pods en estado Running.';
COMMENT ON COLUMN bos.cap_snapshot.k8s_pod_failed        IS 'Pods en estado Failed o CrashLoopBackOff.';
COMMENT ON COLUMN bos.cap_snapshot.k8s_pod_pending       IS 'Pods en estado Pending (esperando scheduling).';
COMMENT ON COLUMN bos.cap_snapshot.k8s_node_count        IS 'Total de nodos K8s en el cluster.';
COMMENT ON COLUMN bos.cap_snapshot.k8s_node_ready        IS 'Nodos K8s en estado Ready.';
COMMENT ON COLUMN bos.cap_snapshot.ctx_sessions_active   IS 'Sesiones del Context Plane en estado ACTIVO.';
COMMENT ON COLUMN bos.cap_snapshot.ctx_sessions_total    IS 'Total de sesiones (todos los estados) en la ventana de retención.';
COMMENT ON COLUMN bos.cap_snapshot.ctx_devices_registered IS 'Dispositivos registrados en registered_device (no expirados).';
COMMENT ON COLUMN bos.cap_snapshot.ctx_devices_active    IS 'Dispositivos con state=ACTIVO.';
COMMENT ON COLUMN bos.cap_snapshot.fichas_installed      IS 'Fichas en estado INSTALADA.';
COMMENT ON COLUMN bos.cap_snapshot.fichas_healthy        IS 'Fichas que pasan el último health check.';
COMMENT ON COLUMN bos.cap_snapshot.fichas_degraded       IS 'Fichas en estado DEGRADADA.';
COMMENT ON COLUMN bos.cap_snapshot.fichas_error          IS 'Fichas en algún estado de error (ERROR_FISICO, ERROR_LOGICO, ERROR_NO_CORREGIBLE).';
COMMENT ON COLUMN bos.cap_snapshot.fichas_updating       IS 'Fichas en proceso de actualización (ACTUALIZANDO).';
COMMENT ON COLUMN bos.cap_snapshot.extra_metrics         IS 'Métricas adicionales no capturadas por columnas fijas. Para extensión sin migración de schema.';
COMMENT ON COLUMN bos.cap_snapshot.ctx_id               IS '[SBOS-049] Contexto operativo del collector.';
COMMENT ON COLUMN bos.cap_snapshot.captured_at          IS '[ISO 27001:2022 A.8.15] Timestamp de la instantánea. Precisión: 1s (collector corre cada 60s).';

CREATE INDEX IF NOT EXISTS idx_bos_cap_snapshot_tenant_time
    ON bos.cap_snapshot (tenant_id, captured_at DESC);
COMMENT ON INDEX idx_bos_cap_snapshot_tenant_time IS 'Series temporales por tenant. Columna líder: tenant_id (low cardinality). Para proyecciones M5.2.';

CREATE INDEX IF NOT EXISTS idx_bos_cap_snapshot_time
    ON bos.cap_snapshot (captured_at DESC);
COMMENT ON INDEX idx_bos_cap_snapshot_time IS 'Snapshots globales ordenados por tiempo. Para queries de retención y purge.';

-- ══════════════════════════════════════════════════════════════════════
-- TABLA 7: bos.cap_estimate
-- Propósito: Configuración de capacidad declarada por tenant.
--   Persiste el mismo contrato de capacity.yaml en la base de datos.
--   Una fila por tenant. Usada por Motor de Observación (M5.3) para
--   evaluar si el cluster tiene capacidad para una operación.
-- Dueño: BOS Wizard (bosctl setup P3B) y bos.capacity.* RPC
-- Estándares: M5.1, internal/capacity/model.go (Estimate struct)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bos.cap_estimate (
    estimate_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id                TEXT        NOT NULL,

    -- Parámetros de estimación (del Estimate struct en capacity/model.go)
    tenants                  SMALLINT    NOT NULL DEFAULT 1,
    companies_per_tenant     SMALLINT    NOT NULL DEFAULT 3,
    branches_per_company     SMALLINT    NOT NULL DEFAULT 5,
    users_per_branch         SMALLINT    NOT NULL DEFAULT 100,

    -- Requerimientos calculados por capacity/calculator.go
    ram_required_gb          NUMERIC(8,2),
    disk_required_gb         NUMERIC(8,2),
    cpu_required_cores       SMALLINT,
    redis_required_mb        INTEGER,
    pg_required_mb           INTEGER,

    -- Control
    is_active                BOOLEAN     NOT NULL DEFAULT TRUE,
    notes                    TEXT,

    ctx_id                   TEXT        NOT NULL DEFAULT 'system',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_cap_estimate_tenant UNIQUE (tenant_id),
    CONSTRAINT chk_cap_estimate_tenants  CHECK (tenants >= 1),
    CONSTRAINT chk_cap_estimate_companies CHECK (companies_per_tenant >= 1),
    CONSTRAINT chk_cap_estimate_branches  CHECK (branches_per_company >= 1),
    CONSTRAINT chk_cap_estimate_users     CHECK (users_per_branch >= 1)
);

COMMENT ON TABLE  bos.cap_estimate IS '[M5.1][internal/capacity/model.go] Configuración de capacidad declarada por tenant. Persiste el contrato de capacity.yaml en BD. Una fila activa por tenant. El Motor de Observación usa esta estimación para evaluar admisión de operaciones (M5.3 CheckAdmission).';
COMMENT ON COLUMN bos.cap_estimate.estimate_id          IS '[RFC 9562] PK interna UUIDv7.';
COMMENT ON COLUMN bos.cap_estimate.tenant_id            IS 'Tenant dueño de esta estimación. UNIQUE — una estimación activa por tenant.';
COMMENT ON COLUMN bos.cap_estimate.tenants              IS 'Número de tenants del cluster. Parámetro Estimate.Tenants.';
COMMENT ON COLUMN bos.cap_estimate.companies_per_tenant IS 'Empresas promedio por tenant. Parámetro Estimate.CompaniesPerTenant.';
COMMENT ON COLUMN bos.cap_estimate.branches_per_company IS 'Sucursales promedio por empresa. Parámetro Estimate.BranchesPerCompany.';
COMMENT ON COLUMN bos.cap_estimate.users_per_branch     IS 'Usuarios promedio por sucursal. Parámetro Estimate.UsersPerBranch.';
COMMENT ON COLUMN bos.cap_estimate.ram_required_gb      IS 'RAM requerida calculada por capacity/calculator.go. NULL si no calculado aún.';
COMMENT ON COLUMN bos.cap_estimate.disk_required_gb     IS 'Disco requerido calculado. NULL si no calculado aún.';
COMMENT ON COLUMN bos.cap_estimate.cpu_required_cores   IS 'Cores de CPU requeridos calculados. NULL si no calculado aún.';
COMMENT ON COLUMN bos.cap_estimate.redis_required_mb    IS 'Memoria Redis requerida calculada en MB. NULL si no calculado aún.';
COMMENT ON COLUMN bos.cap_estimate.pg_required_mb       IS 'Espacio PostgreSQL requerido calculado en MB. NULL si no calculado aún.';
COMMENT ON COLUMN bos.cap_estimate.is_active            IS 'TRUE = estimación vigente. Para historial, se puede desactivar sin borrar.';
COMMENT ON COLUMN bos.cap_estimate.notes                IS 'Notas del operador sobre esta estimación. Libre.';
COMMENT ON COLUMN bos.cap_estimate.ctx_id               IS '[SBOS-049] Contexto operativo de la última actualización.';
COMMENT ON COLUMN bos.cap_estimate.created_at           IS '[ISO 27001:2022 A.8.15] Timestamp de creación.';
COMMENT ON COLUMN bos.cap_estimate.updated_at           IS '[ISO 27001:2022 A.8.15] Timestamp de última modificación.';
