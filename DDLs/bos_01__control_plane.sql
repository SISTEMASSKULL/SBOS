-- =============================================================================
-- bos_01__control_plane.sql — BOS IAM Installer · Context Plane
-- Schema: bos · Base de datos: SBOS_db · PostgreSQL 18+ · UUIDv7 RFC 9562
--
-- PROPÓSITO: Tablas del Policy Administrator (NIST SP 800-207 §3.2).
-- El schema bos gobierna la sesión de INFRAESTRUCTURA: dispositivos,
-- contexto organizacional, TTL, heartbeats, auditoría y break-glass.
-- Complementa —no duplica— las tablas de sesión de IDENTIDAD (bauth.ses_*).
--
-- ARQUITECTURA: Redis DB1 es el store activo (O(1) para Kong PEP).
-- PostgreSQL es fuente de verdad persistente y fallback forense.
-- Cada INSERT/UPDATE en bos.* invalida o actualiza la cache Redis.
--
-- CONVENCIÓN (ddls.yml): inglés para SQL (tablas, columnas, constraints,
-- índices, valores CHECK). Español para comentarios y COMMENTS.
--
-- DEPENDENCIAS DE CARGA: este archivo se carga DESPUÉS del DDL unificado
-- (SBOS_db_V2_DDL.sql) porque sus FKs apuntan a bauth.idn_tenant y
-- bauth.idn_identity_entity. Sin el unificado cargado primero, las FKs fallan.
--
-- IDEMPOTENCIA: todo usa IF NOT EXISTS. Cargar dos veces = mismo resultado.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS bos;

-- =============================================================================
-- T-395 — bos.ctx_registered_device
-- Dispositivos registrados en el Context Plane (pre-auth).
-- BitMask = 0 invariante. TTL 8h. Heartbeat cada 30s.
-- NIST SP 800-207 §3.3 · §4.2 · ISO 27001:2022 A.9.4.2 · SBOS-049 §16.1
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_registered_device (
    dctx_id     UUID        NOT NULL DEFAULT uuidv7(),
    hostname    TEXT        NOT NULL,
    tenant_id   UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    node_k8s    TEXT        NULL,
    ip          INET        NOT NULL,
    state       TEXT        NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    ctx_id      TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT rd_pkey PRIMARY KEY (dctx_id),
    CONSTRAINT chk_rd_state CHECK (state IN (
        'PENDING','ACTIVE','SUSPENDED','BLOCKED',
        'INVALIDATED','EXPIRED','ARCHIVED'
    )),
    CONSTRAINT chk_rd_expiry CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_rd_tenant_state ON bos.ctx_registered_device (tenant_id, state);
CREATE INDEX IF NOT EXISTS idx_rd_hostname     ON bos.ctx_registered_device (hostname);
CREATE INDEX IF NOT EXISTS idx_rd_expires      ON bos.ctx_registered_device (expires_at) WHERE state IN ('PENDING','ACTIVE');

COMMENT ON TABLE bos.ctx_registered_device IS
  '[T-395] [SBOS-049 §16.1] [NIST SP 800-207 §3.3] [ISO 27001:2022 A.9.4.2]
   Dispositivos registrados en el Context Plane. Capa de INFRAESTRUCTURA.
   BitMask = 0 invariante (pre-auth). TTL 8h. Heartbeat cada 30s → ctx_device_heartbeat (T-400).';
COMMENT ON COLUMN bos.ctx_registered_device.dctx_id    IS '[RFC 9562] PK UUIDv7. Identificador de dispositivo en infraestructura.';
COMMENT ON COLUMN bos.ctx_registered_device.hostname   IS 'FQDN del dispositivo. Puente con auth_device.hardware_id a nivel aplicación.';
COMMENT ON COLUMN bos.ctx_registered_device.tenant_id  IS 'FK → bauth.idn_tenant(tenant_id). Ancla de tenant.';
COMMENT ON COLUMN bos.ctx_registered_device.node_k8s   IS 'Nodo K8s donde corre el workload. NULL si es VDI/físico.';
COMMENT ON COLUMN bos.ctx_registered_device.ip         IS 'INET. IP del dispositivo en el momento del registro.';
COMMENT ON COLUMN bos.ctx_registered_device.state      IS 'PENDING→ACTIVE→SUSPENDED/BLOCKED→INVALIDATED/EXPIRED→ARCHIVED.';
COMMENT ON COLUMN bos.ctx_registered_device.expires_at IS 'TTL 8h desde created_at. Sin heartbeat → vence.';
COMMENT ON COLUMN bos.ctx_registered_device.ctx_id     IS '[SBOS-049 §4] Trazabilidad de contexto operativo.';


-- =============================================================================
-- T-400 — bos.ctx_device_heartbeat
-- Heartbeats de dispositivos. Tabla de alta escritura, 24h retención.
-- NIST SP 800-207 §3.3 · ISO 27001:2022 A.9.4.2
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_device_heartbeat (
    heartbeat_id UUID        NOT NULL DEFAULT uuidv7(),
    dctx_id      UUID        NOT NULL REFERENCES bos.ctx_registered_device(dctx_id),
    tenant_id    UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    ip           INET        NOT NULL,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT dh_pkey PRIMARY KEY (heartbeat_id)
);

CREATE INDEX IF NOT EXISTS idx_dh_dctx         ON bos.ctx_device_heartbeat (dctx_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_dh_tenant_recent ON bos.ctx_device_heartbeat (tenant_id, received_at DESC);

COMMENT ON TABLE bos.ctx_device_heartbeat IS
  '[T-400] [NIST SP 800-207 §3.3] [ISO 27001:2022 A.9.4.2]
   Heartbeats de dispositivos. Alta escritura, baja consulta. Retención: 24h.';
COMMENT ON COLUMN bos.ctx_device_heartbeat.dctx_id     IS 'FK → bos.ctx_registered_device(dctx_id).';
COMMENT ON COLUMN bos.ctx_device_heartbeat.tenant_id   IS 'FK → bauth.idn_tenant(tenant_id).';
COMMENT ON COLUMN bos.ctx_device_heartbeat.ip          IS 'INET. IP actual del dispositivo en este heartbeat.';
COMMENT ON COLUMN bos.ctx_device_heartbeat.received_at IS 'Timestamp de recepción. Job expira tras 3×heartbeat_interval sin señal.';


-- =============================================================================
-- T-399 — bos.ctx_context_policy
-- Políticas de TTL y seguridad del Context Plane por tenant.
-- Complementa —no duplica— bauth.idn_tenant (parámetros de identidad).
-- ISO 27001:2022 A.9.4.2 · NIST SP 800-207 §3.3 · SBOS-049 §8
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_policy (
    policy_id              UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id              UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    device_ttl_seconds     INTEGER     NOT NULL DEFAULT 28800,
    session_ttl_seconds    INTEGER     NOT NULL DEFAULT 43200,
    heartbeat_interval_sec INTEGER     NOT NULL DEFAULT 30,
    max_sessions_per_user  INTEGER     NOT NULL DEFAULT 10,
    max_devices_per_tenant INTEGER     NOT NULL DEFAULT 1000,
    rate_limit_rps         INTEGER     NOT NULL DEFAULT 100,
    require_mdm            BOOLEAN     NOT NULL DEFAULT false,
    auto_block_jailbreak   BOOLEAN     NOT NULL DEFAULT true,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id                 TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT cp_pkey PRIMARY KEY (policy_id),
    CONSTRAINT uq_cp_tenant UNIQUE (tenant_id),
    CONSTRAINT chk_cp_device_ttl CHECK (device_ttl_seconds BETWEEN 60 AND 86400),
    CONSTRAINT chk_cp_session_ttl CHECK (session_ttl_seconds BETWEEN 300 AND 86400),
    CONSTRAINT chk_cp_heartbeat CHECK (heartbeat_interval_sec BETWEEN 5 AND 300),
    CONSTRAINT chk_cp_max_sessions CHECK (max_sessions_per_user > 0),
    CONSTRAINT chk_cp_rate CHECK (rate_limit_rps > 0)
);

CREATE INDEX IF NOT EXISTS idx_cp_tenant ON bos.ctx_context_policy (tenant_id);

COMMENT ON TABLE bos.ctx_context_policy IS
  'CONTEXT PLANE | Políticas de TTL y seguridad del Context Plane por tenant (SBOS-049 §8).
   Define los tiempos máximos de dispositivo (device_ttl_seconds) y sesión (session_ttl_seconds),
   el intervalo de heartbeat, y las políticas de seguridad (MDM, jailbreak, rate limit).
   CAPA DE INFRAESTRUCTURA — NO duplica bauth.idn_tenant.session_ttl_max (TTL de identidad).
   UNIQUE por tenant_id: cada tenant tiene exactamente una configuración de Context Plane.
   Fuente: insertada por el IAM Installer al provisionar cada tenant; editable por SUPER_ADMIN
   y TENANT_ADMIN vía RPC bos.ctx.policy.update.
   Administración: BOS la consulta en cada evaluación de sesión; cambios requieren revalidación
   de sesiones activas en Redis. Historial de cambios en logs de auditoría (ctx_audit_log).
   WORM: no — los TTLs son configurables operacionalmente por el TENANT_ADMIN.
   Particionada: no.
   Seed: DDLs/seeds/bos_T399__ctx_context_policy.sql — idempotente ON CONFLICT.
   Estándar: ISO 27001:2022 A.9.4.2, NIST SP 800-207 §3.3, SBOS-049 §8. T-399.';
COMMENT ON COLUMN bos.ctx_context_policy.tenant_id              IS 'FK → bauth.idn_tenant(tenant_id). UNIQUE.';
COMMENT ON COLUMN bos.ctx_context_policy.device_ttl_seconds     IS 'TTL máximo de dispositivo pre-auth. Default 8h (28800s).';
COMMENT ON COLUMN bos.ctx_context_policy.session_ttl_seconds    IS 'TTL máximo de sesión post-auth. Default 12h (43200s).';
COMMENT ON COLUMN bos.ctx_context_policy.heartbeat_interval_sec IS 'Intervalo entre heartbeats. Default 30s.';
COMMENT ON COLUMN bos.ctx_context_policy.require_mdm            IS 'Exigir MDM enrolled para registrar dispositivo.';
COMMENT ON COLUMN bos.ctx_context_policy.auto_block_jailbreak   IS 'Bloquear automáticamente dispositivo con jailbreak/root detectado.';


-- =============================================================================
-- T-396 — bos.ctx_context_session
-- Sesiones de contexto activas (post-auth). ctx_id de 6 capas SBOS-049 §3.1.
-- BitMask > 0 invariante. Redis DB1 cachea para lookup O(1) de Kong PEP.
-- Complementa —no duplica— bauth.ses_session_log (T-181, capa de identidad).
-- NIST SP 800-207 §3.2 · NIST SP 800-63B-4 §7 · ISO 27001:2022 A.9.4.2 · SBOS-049 §5
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_session (
    ctx_id      UUID        NOT NULL DEFAULT uuidv7(),
    dctx_id     UUID        NOT NULL REFERENCES bos.ctx_registered_device(dctx_id),
    tenant_id   UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_1_id UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    entity_2_id UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    entity_3_id TEXT        NULL,
    user_id     UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    bitmask     BIGINT      NOT NULL,
    loa         INTEGER     NOT NULL DEFAULT 1,
    state       TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    traceparent TEXT        NULL,
    ctx_id_text TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT cs_pkey PRIMARY KEY (ctx_id),
    CONSTRAINT chk_cs_state CHECK (state IN (
        'PENDING','ACTIVE','SUSPENDED','BLOCKED',
        'INVALIDATED','EXPIRED','ARCHIVED'
    )),
    CONSTRAINT chk_cs_loa CHECK (loa BETWEEN 1 AND 4),
    CONSTRAINT chk_cs_bitmask CHECK (bitmask > 0),
    CONSTRAINT chk_cs_expiry CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_cs_tenant_active ON bos.ctx_context_session (tenant_id, state) WHERE state = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_cs_user          ON bos.ctx_context_session (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_dctx          ON bos.ctx_context_session (dctx_id);
CREATE INDEX IF NOT EXISTS idx_cs_expires       ON bos.ctx_context_session (expires_at) WHERE state = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_cs_entity_1      ON bos.ctx_context_session (entity_1_id);
CREATE INDEX IF NOT EXISTS idx_cs_traceparent   ON bos.ctx_context_session (traceparent) WHERE traceparent IS NOT NULL;

COMMENT ON TABLE bos.ctx_context_session IS
  '[T-396] [SBOS-049 §5] [NIST SP 800-207 §3.2] [NIST SP 800-63B-4 §7] [RFC 9470]
   Sesión de infraestructura post-auth. ctx_id 6 capas con BitMask > 0.
   CAPA DE INFRAESTRUCTURA — complementa bauth.ses_session_log (T-181). Redis DB1 O(1) Kong PEP.';
COMMENT ON COLUMN bos.ctx_context_session.ctx_id      IS '[RFC 9562] PK UUIDv7. Sesión de infraestructura.';
COMMENT ON COLUMN bos.ctx_context_session.dctx_id     IS 'FK → bos.ctx_registered_device(dctx_id). Dispositivo origen.';
COMMENT ON COLUMN bos.ctx_context_session.tenant_id   IS 'FK → bauth.idn_tenant(tenant_id). CAPA 1 ctx_id.';
COMMENT ON COLUMN bos.ctx_context_session.entity_1_id IS 'FK → bauth.idn_identity_entity. CAPA 2 (bdomain).';
COMMENT ON COLUMN bos.ctx_context_session.entity_2_id IS 'FK → bauth.idn_identity_entity. CAPA 3 (bsubdomain). NULLable.';
COMMENT ON COLUMN bos.ctx_context_session.entity_3_id IS 'CAPA 4 (pos). TEXT — no siempre es entity (ej: "CAJA-01").';
COMMENT ON COLUMN bos.ctx_context_session.user_id     IS 'FK → bauth.idn_identity_entity. CAPA 5 (actor).';
COMMENT ON COLUMN bos.ctx_context_session.bitmask     IS 'BIGINT. BitMask 64-bit > 0 calculado por bAuth.';
COMMENT ON COLUMN bos.ctx_context_session.loa         IS 'INTEGER 1–4. Level of Assurance (RFC 9470).';
COMMENT ON COLUMN bos.ctx_context_session.state       IS 'PENDING→ACTIVE→SUSPENDED/BLOCKED→INVALIDATED/EXPIRED→ARCHIVED.';
COMMENT ON COLUMN bos.ctx_context_session.traceparent IS 'W3C Trace Context v2: 00-{traceId}-{spanId}-{flags}.';
COMMENT ON COLUMN bos.ctx_context_session.ctx_id_text IS '[SBOS-049] Trazabilidad. Nombre distinto a PK para evitar colisión.';


-- =============================================================================
-- T-397 — bos.ctx_context_audit 🔒 WORM
-- Auditoría WORM de toda operación del Context Plane. Hash-chain SHA-256.
-- ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-12 · PCI DSS 4.0 Req 10.2.1
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_audit (
    audit_id    UUID        NOT NULL DEFAULT uuidv7(),
    ctx_id      UUID        NULL REFERENCES bos.ctx_context_session(ctx_id),
    dctx_id     UUID        NULL REFERENCES bos.ctx_registered_device(dctx_id),
    tenant_id   UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    operation   TEXT        NOT NULL,
    actor_id    UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    old_state   TEXT        NULL,
    new_state   TEXT        NOT NULL,
    details     JSONB       NOT NULL DEFAULT '{}',
    ip_address  INET        NULL,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash   TEXT        NULL,
    ctx_id_text TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT ca_pkey PRIMARY KEY (audit_id),
    CONSTRAINT chk_ca_operation CHECK (operation IN (
        'DEVICE_REGISTER','DEVICE_HEARTBEAT',
        'SESSION_CREATE','SESSION_PROMOTE',
        'SESSION_SWITCH','SESSION_INVALIDATE','SESSION_EXPIRE',
        'SESSION_SUSPEND','SESSION_BLOCK','SESSION_ARCHIVE',
        'CONTEXT_TRANSFER','EMERGENCY_ACTIVATE','EMERGENCY_APPROVE',
        'COMPLIANCE_VIOLATION','ADMIN_OVERRIDE'
    )),
    CONSTRAINT chk_ca_state CHECK (
        (old_state IS NULL OR old_state IN (
            'PENDING','ACTIVE','SUSPENDED','BLOCKED','INVALIDATED','EXPIRED','ARCHIVED'))
        AND new_state IN (
            'PENDING','ACTIVE','SUSPENDED','BLOCKED','INVALIDATED','EXPIRED','ARCHIVED')
    )
);

REVOKE UPDATE, DELETE ON bos.ctx_context_audit FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_ca_ctx       ON bos.ctx_context_audit (ctx_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_tenant_op ON bos.ctx_context_audit (tenant_id, operation, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_executed  ON bos.ctx_context_audit (executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_actor     ON bos.ctx_context_audit (actor_id, executed_at DESC) WHERE actor_id IS NOT NULL;

COMMENT ON TABLE bos.ctx_context_audit IS
  '[T-397] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-12] [PCI DSS 4.0 Req 10.2.1]
   Auditoría WORM de toda operación del Context Plane. Hash-chain SHA-256. REVOKE UPDATE/DELETE.';
COMMENT ON COLUMN bos.ctx_context_audit.operation IS '16 tipos: DEVICE_REGISTER a ADMIN_OVERRIDE.';
COMMENT ON COLUMN bos.ctx_context_audit.prev_hash IS 'SHA-256 de la fila anterior. Cadena WORM verificable.';


-- =============================================================================
-- T-398 — bos.ctx_context_switch_log 🔒 WORM
-- Historial WORM de cambios de contexto sin reautenticación. ITDR forense.
-- SBOS-049 §6 · NIST SP 800-63B-4 §7.2 · ISO 27001:2022 A.8.15
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_switch_log (
    switch_id    UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id    UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    user_id      UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    old_ctx_id   UUID        NOT NULL REFERENCES bos.ctx_context_session(ctx_id),
    new_ctx_id   UUID        NOT NULL REFERENCES bos.ctx_context_session(ctx_id),
    old_entity_1 UUID        NULL,
    old_entity_2 UUID        NULL,
    old_entity_3 TEXT        NULL,
    new_entity_1 UUID        NOT NULL,
    new_entity_2 UUID        NULL,
    new_entity_3 TEXT        NULL,
    reason       TEXT        NULL,
    switched_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash    TEXT        NULL,
    ctx_id       TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT csl_pkey PRIMARY KEY (switch_id),
    CONSTRAINT chk_csl_diff CHECK (old_ctx_id <> new_ctx_id)
);

REVOKE UPDATE, DELETE ON bos.ctx_context_switch_log FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_csl_user    ON bos.ctx_context_switch_log (user_id, switched_at DESC);
CREATE INDEX IF NOT EXISTS idx_csl_tenant  ON bos.ctx_context_switch_log (tenant_id, switched_at DESC);
CREATE INDEX IF NOT EXISTS idx_csl_old_ctx ON bos.ctx_context_switch_log (old_ctx_id);

COMMENT ON TABLE bos.ctx_context_switch_log IS
  '[T-398] [SBOS-049 §6] [NIST SP 800-63B-4 §7.2] [ISO 27001:2022 A.8.15]
   Historial WORM de cambios de contexto sin reautenticación. Forensia ITDR.';
COMMENT ON COLUMN bos.ctx_context_switch_log.old_ctx_id IS 'FK → bos.ctx_context_session. Contexto antes del switch.';
COMMENT ON COLUMN bos.ctx_context_switch_log.new_ctx_id IS 'FK → bos.ctx_context_session. Nuevo contexto.';


-- =============================================================================
-- T-401 — bos.ctx_context_transfer 🔒 WORM
-- Transferencia de contexto entre dispositivos.
-- SBOS-049 §10 · NIST SP 800-63B-4 §7.2
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_transfer (
    transfer_id   UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id     UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    user_id       UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id        UUID        NOT NULL REFERENCES bos.ctx_context_session(ctx_id),
    from_dctx_id  UUID        NOT NULL REFERENCES bos.ctx_registered_device(dctx_id),
    to_dctx_id    UUID        NOT NULL REFERENCES bos.ctx_registered_device(dctx_id),
    transfer_type TEXT        NOT NULL DEFAULT 'USER_INITIATED',
    transferred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash     TEXT        NULL,
    ctx_id_text   TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT ct_pkey PRIMARY KEY (transfer_id),
    CONSTRAINT chk_ct_different CHECK (from_dctx_id <> to_dctx_id),
    CONSTRAINT chk_ct_type CHECK (transfer_type IN (
        'USER_INITIATED','AUTO_CONTINUITY','ADMIN_TRANSFER','BREAKGLASS'
    ))
);

REVOKE UPDATE, DELETE ON bos.ctx_context_transfer FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_ct_user        ON bos.ctx_context_transfer (user_id, transferred_at DESC);
CREATE INDEX IF NOT EXISTS idx_ct_ctx         ON bos.ctx_context_transfer (ctx_id);
CREATE INDEX IF NOT EXISTS idx_ct_from_device ON bos.ctx_context_transfer (from_dctx_id, transferred_at DESC);

COMMENT ON TABLE bos.ctx_context_transfer IS
  '[T-401] [SBOS-049 §10] [NIST SP 800-63B-4 §7.2]
   Transferencia de contexto entre dispositivos. WORM.
   Tipos: USER_INITIATED, AUTO_CONTINUITY, ADMIN_TRANSFER, BREAKGLASS.';
COMMENT ON COLUMN bos.ctx_context_transfer.from_dctx_id IS 'FK → bos.ctx_registered_device. Dispositivo origen.';
COMMENT ON COLUMN bos.ctx_context_transfer.to_dctx_id   IS 'FK → bos.ctx_registered_device. Dispositivo destino.';


-- =============================================================================
-- T-402 — bos.ctx_context_emergency 🔒 WORM
-- Break-glass de contexto (D08-B04). Control dual NIST AC-17(3).
-- TTL máximo 2h fijo. Revisión post-hoc 24h obligatoria.
-- NIST SP 800-53 R5.2 AC-17(3) · ISO 27001:2022 A.5.29 · NIST CP-2(8)
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ctx_context_emergency (
    emergency_id         UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id            UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    activated_by         UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    approved_by          UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    reason               TEXT        NOT NULL,
    incident_ref         TEXT        NOT NULL,
    resulting_ctx_id     UUID        NULL REFERENCES bos.ctx_context_session(ctx_id),
    state                TEXT        NOT NULL DEFAULT 'ACTIVATED',
    activated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at           TIMESTAMPTZ NOT NULL,
    closed_at            TIMESTAMPTZ NULL,
    post_review_deadline TIMESTAMPTZ NOT NULL,
    reviewed_by          UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    review_outcome       TEXT        NULL,
    prev_hash            TEXT        NULL,
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
    CONSTRAINT chk_cem_reason CHECK (length(reason) >= 50),
    CONSTRAINT chk_cem_incident CHECK (length(incident_ref) >= 1)
);

REVOKE UPDATE, DELETE ON bos.ctx_context_emergency FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_cem_tenant        ON bos.ctx_context_emergency (tenant_id, state, activated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cem_pending_review ON bos.ctx_context_emergency (post_review_deadline) WHERE state = 'CLOSED' AND review_outcome IS NULL;
CREATE INDEX IF NOT EXISTS idx_cem_activated_by   ON bos.ctx_context_emergency (activated_by, activated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cem_resulting_ctx  ON bos.ctx_context_emergency (resulting_ctx_id) WHERE resulting_ctx_id IS NOT NULL;

COMMENT ON TABLE bos.ctx_context_emergency IS
  '[T-402] [D08-B04] [NIST SP 800-53 R5.2 AC-17(3)] [ISO 27001:2022 A.5.29] [NIST CP-2(8)]
   Break-glass de contexto. Control dual: activated_by ≠ approved_by. TTL 2h fijo. Revisión 24h. WORM.';
COMMENT ON COLUMN bos.ctx_context_emergency.activated_by         IS 'FK → bauth.idn_identity_entity. Quien declara la emergencia.';
COMMENT ON COLUMN bos.ctx_context_emergency.approved_by          IS 'FK → bauth.idn_identity_entity. Quien aprueba (≠ activated_by).';
COMMENT ON COLUMN bos.ctx_context_emergency.reason               IS 'Justificación obligatoria ≥ 50 caracteres.';
COMMENT ON COLUMN bos.ctx_context_emergency.incident_ref         IS 'Ticket externo obligatorio.';
COMMENT ON COLUMN bos.ctx_context_emergency.resulting_ctx_id     IS 'FK → bos.ctx_context_session. Sesión creada por la emergencia.';
COMMENT ON COLUMN bos.ctx_context_emergency.expires_at           IS 'TTL máximo 2h desde activated_at. CHECK enforce en DDL.';
COMMENT ON COLUMN bos.ctx_context_emergency.post_review_deadline IS 'activated_at + 24h. Revisión post-hoc obligatoria.';
COMMENT ON COLUMN bos.ctx_context_emergency.review_outcome       IS 'JUSTIFIED | UNJUSTIFIED | POLICY_VIOLATION.';


-- =============================================================================
-- T-403 — bos.fch_ficha_state
-- Estado actual de cada ficha declarativa (máquina de 18 estados, ADR-021).
-- Fichas = componentes de plataforma compartidos por todos los tenants.
-- Sin tenant_id: la multi-tenancy es un concepto de datos, no de infraestructura.
-- GRUPO=fch · ENTIDAD=ficha · OBJETO=state
-- SBOS-019 · 3.01 máquina 18 estados · ISO 27001:2022 A.8.9 (gestión de activos)
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.fch_ficha_state (
    ficha_id             UUID        NOT NULL DEFAULT uuidv7(),
    ficha_name           TEXT        NOT NULL,
    server_id            TEXT        NOT NULL,
    version              TEXT        NOT NULL DEFAULT '0.0.0',
    state                TEXT        NOT NULL DEFAULT 'PENDING',
    category             INTEGER     NOT NULL DEFAULT 1,
    criticality          BOOLEAN     NOT NULL DEFAULT false,
    backend              TEXT        NOT NULL DEFAULT 'bash',
    installed_at         TIMESTAMPTZ NULL,
    installed_by         UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by           UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    last_health_check_at TIMESTAMPTZ NULL,
    health_status        TEXT        NULL,
    hashes               JSONB       NOT NULL DEFAULT '{}',
    ctx_id               TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT fch_s_pkey           PRIMARY KEY (ficha_id),
    CONSTRAINT uq_fch_s_name_server UNIQUE (ficha_name, server_id),
    CONSTRAINT chk_fch_s_state      CHECK (state IN (
        'PENDING','READY','INSTALLING','INSTALLED',
        'UPDATE_AVAILABLE','UPDATE_APPROVED','UPDATING',
        'DEGRADED','PHYSICAL_ERROR','LOGICAL_ERROR','REPAIRING',
        'UNRECOVERABLE','INSTALL_FAILED','UPDATE_FAILED',
        'ROLLBACK','CLEANUP','PAUSED','UNINSTALLED'
    )),
    CONSTRAINT chk_fch_s_backend    CHECK (backend IN ('bash','k8s','binary','python')),
    CONSTRAINT chk_fch_s_category   CHECK (category BETWEEN 1 AND 5),
    CONSTRAINT chk_fch_s_hashes     CHECK (jsonb_typeof(hashes) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_fch_s_server   ON bos.fch_ficha_state (server_id);
CREATE INDEX IF NOT EXISTS idx_fch_s_state    ON bos.fch_ficha_state (state);
CREATE INDEX IF NOT EXISTS idx_fch_s_degraded ON bos.fch_ficha_state (state)
    WHERE state IN ('DEGRADED','PHYSICAL_ERROR','LOGICAL_ERROR','UNRECOVERABLE');

COMMENT ON TABLE bos.fch_ficha_state IS
  '[T-403] [SBOS-019] [3.01 máquina 18 estados] [ISO 27001:2022 A.8.9] [NIST CM-8]
   Estado actual de cada ficha declarativa. Máquina de 18 estados (ADR-021).
   Sin tenant_id: las fichas son componentes de plataforma compartidos (Motor ③).
   Multi-tenancy = concepto de datos (discriminadores, RLS), no de infraestructura.
   Clave natural: (ficha_name, server_id) — una ficha por servidor lógico.
   hashes: SHA-256 de manifest.yml, yaml_engine.yml y task_catalog.sh para drift detection.
   installed_by / updated_by: trazabilidad NIST AU-3 / ISO A.8.9.';

-- =============================================================================
-- T-404 — bos.fch_ficha_event
-- Historial WORM de todos los cambios de estado de fichas.
-- WORM: REVOKE UPDATE, DELETE. Hash-chain SHA-256 para inmutabilidad.
-- tenant_id = tenant que disparó el evento (auditoría), no dueño de la ficha.
-- GRUPO=fch · ENTIDAD=ficha · OBJETO=event
-- ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-2, AU-3, AU-12
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.fch_ficha_event (
    event_id    UUID        NOT NULL DEFAULT uuidv7(),
    ficha_id    UUID        NOT NULL REFERENCES bos.fch_ficha_state(ficha_id),
    ficha_name  TEXT        NOT NULL,
    tenant_id   UUID        NULL     REFERENCES bauth.idn_tenant(tenant_id),
    actor_id    UUID        NULL     REFERENCES bauth.idn_identity_entity(entity_id),
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

    CONSTRAINT fch_e_pkey          PRIMARY KEY (event_id),
    CONSTRAINT chk_fch_e_result    CHECK (result IN ('OK','FAIL','PARTIAL','SKIPPED')),
    CONSTRAINT chk_fch_e_details   CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT chk_fch_e_duration  CHECK (duration_ms IS NULL OR duration_ms >= 0)
);

REVOKE UPDATE, DELETE ON bos.fch_ficha_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_fch_e_ficha    ON bos.fch_ficha_event (ficha_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fch_e_tenant   ON bos.fch_ficha_event (tenant_id, executed_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fch_e_actor    ON bos.fch_ficha_event (actor_id, executed_at DESC)  WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fch_e_saga     ON bos.fch_ficha_event (saga_id)                     WHERE saga_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fch_e_failures ON bos.fch_ficha_event (ficha_name, executed_at DESC) WHERE result = 'FAIL';

COMMENT ON TABLE bos.fch_ficha_event IS
  '[T-404] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-2, AU-3, AU-12]
   Historial WORM de todos los cambios de estado de fichas. REVOKE UPDATE/DELETE.
   Hash-chain SHA-256 (prev_hash) para inmutabilidad verificable.
   tenant_id: tenant que DISPARÓ el evento (origen de auditoría), no dueño de la ficha.
   actor_id + ip_address: quién y desde dónde — requisito NIST AU-3, ISO A.8.15.
   saga_id: agrupa todos los eventos de una misma saga install/update/repair/remove.
   operation: nombre del paso en la saga (ej. "install.preflight", "repair.verify").';

-- =============================================================================
-- T-405 — bos.ins_bootstrap_event
-- Historial WORM del bootstrap progresivo de 6 capas (Motor ① IAM Installer).
-- WORM: REVOKE UPDATE, DELETE. Hash-chain SHA-256.
-- tenant_id NOT NULL: el tenant raíz siempre existe (seed de BD).
-- Capas 0-2: tenant raíz. Capas 3-5: tenant específico del cliente.
-- GRUPO=ins · ENTIDAD=bootstrap · OBJETO=event
-- ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-3, CM-8 · ADR-040
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ins_bootstrap_event (
    event_id          UUID        NOT NULL DEFAULT uuidv7(),
    bootstrap_run_id  UUID        NOT NULL,
    tenant_id         UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id          UUID        NULL     REFERENCES bauth.idn_identity_entity(entity_id),
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
        verification_code IS NULL OR verification_code ~ '^C-[0-9]{2}$'
    )
);

REVOKE UPDATE, DELETE ON bos.ins_bootstrap_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_ins_be_run      ON bos.ins_bootstrap_event (bootstrap_run_id, executed_at);
CREATE INDEX IF NOT EXISTS idx_ins_be_tenant   ON bos.ins_bootstrap_event (tenant_id, layer, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ins_be_actor    ON bos.ins_bootstrap_event (actor_id, executed_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_be_ficha    ON bos.ins_bootstrap_event (ficha_name, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ins_be_vcode    ON bos.ins_bootstrap_event (verification_code) WHERE verification_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_be_failures ON bos.ins_bootstrap_event (result, layer) WHERE result = 'FAIL';

COMMENT ON TABLE bos.ins_bootstrap_event IS
  '[T-405] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-3, CM-8] [ADR-040] [1.01 §4]
   Registro WORM del bootstrap progresivo. 6 capas (0=OS → 5=Hardening).
   tenant_id NUNCA es NULL: el tenant raíz (seed #1) existe desde la creación de la BD
   y gobierna a todos los demás tenants. Provee el contexto de plataforma en capas 0-2.
   Capas 0-2 (sistema): tenant_id = UUID del tenant raíz.
   Capas 3-5 (cliente): tenant_id = UUID del tenant que se está instalando.
   bootstrap_run_id agrupa todos los eventos de un mismo intento end-to-end.
   actor_id: quién inició el bootstrap (NULL si automático). NIST AU-3.
   node_id: nodo físico/VM donde corrió el step. NIST CM-8.
   BOS notifica a bAuth vía API para actualizar bauth.idn_tenant.provisioning_status.
   BOS NO escribe directamente en bauth.* (schema-per-service).';
COMMENT ON COLUMN bos.ins_bootstrap_event.bootstrap_run_id  IS 'UUID generado al inicio de cada intento. Agrupa todos sus eventos.';
COMMENT ON COLUMN bos.ins_bootstrap_event.verification_code IS 'C-01..C-09: código de verificación de capa completada. NULL si es step intermedio.';

-- =============================================================================
-- T-406 — bos.cap_sistema_snapshot
-- Instantáneas periódicas (~60s) de 30+ métricas del sistema (Motor ② M5.1).
-- NO WORM: datos de observabilidad operativa, no de auditoría de acceso.
-- Particionado mensual PARTITION BY RANGE (captured_at).
-- Retención 90 días: cron DROP TABLE sobre particiones legacy (instantáneo).
-- GRUPO=cap · ENTIDAD=sistema · OBJETO=snapshot
-- SBOS-BOS-CAP-001 · 2.02 M5.1 · ISO 27001:2022 A.12.4
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_sistema_snapshot (
    snapshot_id           UUID         NOT NULL DEFAULT uuidv7(),
    scope                 TEXT         NOT NULL DEFAULT 'GLOBAL',
    tenant_id             UUID         NULL     REFERENCES bauth.idn_tenant(tenant_id),
    captured_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    ctx_sessions_active   INTEGER      NULL,
    ctx_devices_active    INTEGER      NULL,

    redis_memory_pct      NUMERIC(5,2) NULL,
    redis_keys_count      BIGINT       NULL,
    redis_ops_per_sec     NUMERIC(10,2) NULL,

    pg_connections_active INTEGER      NULL,
    pg_connections_max    INTEGER      NULL,
    pg_db_size_bytes      BIGINT       NULL,
    pg_tps                NUMERIC(10,2) NULL,

    kong_rps              NUMERIC(10,2) NULL,
    kong_latency_p99_ms   NUMERIC(10,2) NULL,
    kong_error_rate_pct   NUMERIC(5,2)  NULL,

    bauth_cache_miss_pct  NUMERIC(5,2) NULL,
    bauth_token_ops_sec   NUMERIC(10,2) NULL,

    bkernel_lag_ms        NUMERIC(10,2) NULL,
    bkernel_events_sec    NUMERIC(10,2) NULL,

    k8s_nodes_ready       INTEGER      NULL,
    k8s_nodes_total       INTEGER      NULL,
    k8s_pods_running      INTEGER      NULL,
    k8s_pods_total        INTEGER      NULL,
    k8s_cpu_used_pct      NUMERIC(5,2) NULL,
    k8s_mem_used_pct      NUMERIC(5,2) NULL,

    host_cpu_pct          NUMERIC(5,2) NULL,
    host_mem_pct          NUMERIC(5,2) NULL,
    host_disk_pct         NUMERIC(5,2) NULL,
    host_load_avg_1m      NUMERIC(6,2) NULL,

    units_healthy         INTEGER      NULL,
    units_degraded        INTEGER      NULL,
    units_error           INTEGER      NULL,
    units_total           INTEGER      NULL,

    extras                JSONB        NOT NULL DEFAULT '{}',

    -- PK incluye captured_at por requisito de PostgreSQL en tablas particionadas
    CONSTRAINT cap_sn_pkey             PRIMARY KEY (snapshot_id, captured_at),
    CONSTRAINT chk_cap_sn_scope        CHECK (scope IN ('GLOBAL','TENANT')),
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

-- Partición inicial: mes de puesta en producción.
-- BOS crea la partición del mes siguiente el día 25 de cada mes (cron interno).
-- Purga: DROP TABLE bos.cap_sistema_snapshot_YYYY_MM para particiones > 90 días.
CREATE TABLE IF NOT EXISTS bos.cap_sistema_snapshot_2026_07
    PARTITION OF bos.cap_sistema_snapshot
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE INDEX IF NOT EXISTS idx_cap_sn_scope_time  ON bos.cap_sistema_snapshot (scope, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_cap_sn_tenant_time ON bos.cap_sistema_snapshot (tenant_id, captured_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cap_sn_degraded    ON bos.cap_sistema_snapshot (units_degraded, captured_at DESC)
    WHERE units_degraded > 0;

COMMENT ON TABLE bos.cap_sistema_snapshot IS
  '[T-406] [SBOS-BOS-CAP-001] [2.02 M5.1] [ISO 27001:2022 A.12.4]
   Instantáneas periódicas (~60s) de 30+ métricas del sistema. NO WORM.
   PARTICIONADO MENSUAL (PARTITION BY RANGE captured_at):
     · bos.cap_sistema_snapshot_YYYY_MM — una partición por mes
     · BOS crea la partición del mes siguiente el día 25 de cada mes
     · Purga: DROP TABLE sobre particiones cuyo rango termine hace > 90 días
       (instantáneo, sin contención, sin recorrer filas)
   PK compuesta (snapshot_id, captured_at): requerido por PostgreSQL en tablas
   particionadas (la PK debe incluir la clave de partición).
   scope=GLOBAL → tenant_id NULL · scope=TENANT → tenant_id NOT NULL.
   Todas las métricas son NULLable: fuente caída no invalida el snapshot.';

-- =============================================================================
-- T-407 — bos.cap_tenant_policy
-- Políticas de capacidad por tenant (Motor ② M5.3).
-- Fallback: si el tenant no tiene fila, Motor M5.3 usa la fila del tenant raíz.
-- El tenant raíz y su política se siembran en el seed de creación de SBOS_db.
-- GRUPO=cap · ENTIDAD=tenant · OBJETO=policy
-- SBOS-BOS-CAP-001 · 2.02 M5.3 · ISO 27001:2022 A.8.9 · NIST SP 800-53 CA-7
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_tenant_policy (
    policy_id                UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id                UUID         NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    updated_by               UUID         NULL     REFERENCES bauth.idn_identity_entity(entity_id),
    effective_from           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    policy_mode              TEXT         NOT NULL DEFAULT 'recommend',

    cpu_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    mem_limit_pct            NUMERIC(5,2) NOT NULL DEFAULT 85.0,
    disk_limit_pct           NUMERIC(5,2) NOT NULL DEFAULT 90.0,
    redis_mem_limit_pct      NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    pg_conn_limit_pct        NUMERIC(5,2) NOT NULL DEFAULT 80.0,
    kong_tenant_rps_cap      INTEGER      NOT NULL DEFAULT 10000,
    ctx_sessions_max         INTEGER      NOT NULL DEFAULT 50000,
    pg_db_size_limit_bytes   BIGINT       NOT NULL DEFAULT 107374182400,
    projection_horizon_days  INTEGER      NOT NULL DEFAULT 30,
    projection_confidence    NUMERIC(4,3) NOT NULL DEFAULT 0.950,

    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ctx_id                   TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT cap_pol_pkey             PRIMARY KEY (policy_id),
    CONSTRAINT uq_cap_pol_tenant        UNIQUE (tenant_id),
    CONSTRAINT chk_cap_tp_mode          CHECK (policy_mode IN (
        'autonomous','recommend','block_and_alert','emergency'
    )),
    CONSTRAINT chk_cap_tp_pcts          CHECK (
        cpu_limit_pct           BETWEEN 0 AND 100 AND
        mem_limit_pct           BETWEEN 0 AND 100 AND
        disk_limit_pct          BETWEEN 0 AND 100 AND
        redis_mem_limit_pct     BETWEEN 0 AND 100 AND
        pg_conn_limit_pct       BETWEEN 0 AND 100
    ),
    CONSTRAINT chk_cap_tp_rps           CHECK (kong_tenant_rps_cap > 0),
    CONSTRAINT chk_cap_tp_sessions      CHECK (ctx_sessions_max > 0),
    CONSTRAINT chk_cap_tp_horizon       CHECK (projection_horizon_days BETWEEN 1 AND 365),
    CONSTRAINT chk_cap_tp_confidence    CHECK (projection_confidence BETWEEN 0 AND 1)
);

CREATE INDEX IF NOT EXISTS idx_cap_pol_mode  ON bos.cap_tenant_policy (policy_mode);
CREATE INDEX IF NOT EXISTS idx_cap_pol_actor ON bos.cap_tenant_policy (updated_by) WHERE updated_by IS NOT NULL;

COMMENT ON TABLE bos.cap_tenant_policy IS
  '[T-407] [SBOS-BOS-CAP-001] [2.02 M5.3] [ISO 27001:2022 A.8.9] [NIST SP 800-53 CA-7]
   Políticas de capacidad declaradas por tenant. UNIQUE por tenant.
   FALLBACK: si un tenant no tiene fila, Motor M5.3 usa la fila del tenant raíz
   (tenant_id = UUID del tenant raíz, sembrado en seed de SBOS_db junto a
   la empresa master, sucursal master y política de capacidad raíz).
   policy_mode: autonomous=BOS actúa solo · recommend=HITL aprueba ·
     block_and_alert=bloquea admisión · emergency=protocolo completo.
   kong_tenant_rps_cap: cap TOTAL del tenant en Kong PEP (infraestructura).
     Distinto de ctx_context_policy.rate_limit_rps (Context API BOS per-tenant)
     y bauth.idn_tenant.rate_limit_rps (perspectiva IAM).
   ctx_sessions_max: techo AGREGADO del tenant (distinto de max_sessions_per_user).
   Notificaciones: delegadas a bnotify — no almacenar webhook_url/email aquí.
   updated_by + effective_from: trazabilidad NIST AU-3 / ISO A.8.9.';
COMMENT ON COLUMN bos.cap_tenant_policy.policy_mode IS
  'autonomous=BOS actúa solo · recommend=HITL aprueba · block_and_alert=bloquea · emergency=protocolo completo.';
COMMENT ON COLUMN bos.cap_tenant_policy.kong_tenant_rps_cap IS
  'Cap total de RPS del tenant en Kong PEP. Capa de infraestructura. Ver ctx_context_policy.rate_limit_rps para capa Context API.';

-- =============================================================================
-- T-408 — bos.prt_port_assignment
-- Kardex de asignaciones de puertos — implementación RFC 6335 (BCP 165) dentro de SBOS.
-- Inventario de activos de red ISO 27001 A.8.20 / NIST CM-8.
-- Inmutabilidad lógica: filas nunca se borran — transicionan asignado→liberado→revocado.
-- No WORM técnico (UPDATE de estado permitido). Integridad referencial RFC 6335 §8.
-- GRUPO=prt · ENTIDAD=port · OBJETO=assignment
-- A.12 §6.5 · RFC 6335 · ISO 27001 A.8.20 · NIST SP 800-53 CM-8, CM-8(3)
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.prt_port_assignment (
    port_id            UUID         NOT NULL DEFAULT uuidv7(),

    -- Campos RFC 6335 obligatorios (§5 — los 8 campos del registro)
    service_name       TEXT         NOT NULL, -- "sbos-keycloak-http" (1-15 chars RFC 6335 §5.1)
    port               INTEGER      NOT NULL, -- 8200
    transport          TEXT         NOT NULL, -- TCP|UDP|SCTP|DCCP
    assigned_by        TEXT         NOT NULL, -- "bos.ficha.install" (RFC 6335 field 3)
    ficha_id           TEXT         NOT NULL, -- Contact: ficha responsable (RFC 6335 field 4)
    description        TEXT         NOT NULL, -- Description (RFC 6335 field 5)
    doc_reference      TEXT         NOT NULL, -- Reference (RFC 6335 field 6)

    -- Clasificación SBOS
    port_type          TEXT         NOT NULL, -- HOST_PHYSICAL|HOST_LOGICAL|K8S_NODE_PORT|K8S_CLUSTER_IP|K8S_LOAD_BALANCER
    logical_server     TEXT         NOT NULL, -- S00..S16, S-HOST
    namespace          TEXT         NULL,     -- namespace K8s (NULL para host/daemon)
    container_port     INTEGER      NULL,     -- puerto canónico del contenedor
    port_role          SMALLINT     NOT NULL DEFAULT 0, -- 0=HTTP,1=HTTPS,2=metrics,3=health,4=admin,6=WS

    -- Identidad de red estable (capa Service — no Pods, que son efímeros)
    cluster_ip         TEXT         NULL,     -- IP del K8s Service (ClusterIP/LoadBalancer)
    external_ip        TEXT         NULL,     -- IP externa si aplica (MetalLB VIP, WireGuard)
    dns_name           TEXT         NULL,     -- FQDN (keycloak.sbos-identity.svc.cluster.local)

    -- Activo asociado — ISO 27001 A.8.20 (inventario de activos de red)
    asset_type         TEXT         NOT NULL DEFAULT 'ficha',
    asset_id           TEXT         NULL,     -- ID del activo (ficha_id, nodo nombre, daemon nombre)
    asset_owner        TEXT         NULL,     -- Responsable (tenant, sistema)
    labels             JSONB        NULL,     -- {"hpa":"enabled","replicas":"2-20","critical":true}

    -- Exposición exterior
    subdomain          TEXT         NULL,     -- auth.cliente.sbos.app
    kong_route         TEXT         NULL,     -- /auth → 8200

    -- Motor de asignación
    algorithm          TEXT         NOT NULL DEFAULT 'A',   -- A | A+N2 | B | hitl

    -- Estado — RFC 6335 §8 (ciclo de vida: nunca borrar, solo cambiar estado)
    status             TEXT         NOT NULL DEFAULT 'assigned',
    assigned_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    released_at        TIMESTAMPTZ  NULL,
    last_validated_at  TIMESTAMPTZ  NULL,     -- última vez que portman.validate confirmó el registro
    notes              TEXT         NULL,     -- notas libres del operador
    ctx_id             TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT prt_pa_pkey              PRIMARY KEY (port_id),
    -- Un puerto+tipo+namespace no puede asignarse dos veces simultáneamente
    CONSTRAINT uq_prt_pa_port_ns        UNIQUE (port, port_type, namespace),
    CONSTRAINT chk_prt_pa_transport     CHECK (transport IN ('TCP','UDP','SCTP','DCCP')),
    CONSTRAINT chk_prt_pa_port_type     CHECK (port_type IN (
        'HOST_PHYSICAL','HOST_LOGICAL','K8S_NODE_PORT','K8S_CLUSTER_IP','K8S_LOAD_BALANCER'
    )),
    CONSTRAINT chk_prt_pa_asset         CHECK (asset_type IN (
        'ficha','daemon','logical_server','k8s_node','k8s_service','kong_route'
    )),
    CONSTRAINT chk_prt_pa_status        CHECK (status IN ('assigned','released','revoked','conflict')),
    CONSTRAINT chk_prt_pa_port_range    CHECK (port BETWEEN 1024 AND 49151),
    CONSTRAINT chk_prt_pa_port_role     CHECK (port_role BETWEEN 0 AND 9),
    CONSTRAINT chk_prt_pa_release_state CHECK (
        (status = 'released' AND released_at IS NOT NULL) OR
        (status != 'released' AND released_at IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_prt_pa_ficha     ON bos.prt_port_assignment (ficha_id);
CREATE INDEX IF NOT EXISTS idx_prt_pa_server    ON bos.prt_port_assignment (logical_server);
CREATE INDEX IF NOT EXISTS idx_prt_pa_status    ON bos.prt_port_assignment (status) WHERE status = 'assigned';
CREATE INDEX IF NOT EXISTS idx_prt_pa_service   ON bos.prt_port_assignment (service_name);
CREATE INDEX IF NOT EXISTS idx_prt_pa_asset     ON bos.prt_port_assignment (asset_type, asset_id);
CREATE INDEX IF NOT EXISTS idx_prt_pa_subdomain ON bos.prt_port_assignment (subdomain) WHERE subdomain IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_prt_pa_labels    ON bos.prt_port_assignment USING GIN (labels) WHERE labels IS NOT NULL;

COMMENT ON TABLE bos.prt_port_assignment IS
  '[T-408] [A.12 §6.5] [RFC 6335 BCP 165] [ISO 27001:2022 A.8.20] [NIST CM-8, CM-8(3)]
   Kardex de asignaciones de puertos — lo que IANA hace para internet, este Kardex lo hace
   para el SBOS (RFC 6335 §1). Inventario de activos de red ISO 27001 A.8.20.
   INMUTABILIDAD LÓGICA: filas nunca se borran (RFC 6335 §8 "De-Assignment").
   Solo cambian de estado: asignado→liberado→revocado. liberado_en registra la fecha.
   Dos capas de identidad de red (A.12 §6.1):
     · Service (estable): ClusterIP + port — guardado en Kardex.
     · Pod (efímero): Pod IP + containerPort — consultado en tiempo real vía K8s API.
   Algoritmo A: BASE_SERVIDOR + (ficha_index×10) + port_role (determinístico).
   Algoritmo B: SHA256(ficha_id:port_type:clash) % RANGO (hash fallback si bloque agotado).
   portman.validate (cada 300s) compara Kardex vs kubectl get svc → detecta drift.
   port: rango 1024-49151 (User Ports RFC 6335). 0-1023 y 49152-65535 prohibidos.';
COMMENT ON COLUMN bos.prt_port_assignment.service_name IS
  'Service Name RFC 6335 §5.1: "sbos-<ficha>-<role>", 1-15 chars, sin guiones adyacentes.';
COMMENT ON COLUMN bos.prt_port_assignment.port_role IS
  '0=HTTP, 1=HTTPS, 2=metrics, 3=healthcheck, 4=admin, 5=grpc, 6=WebSocket, 7=debug, 8=backup, 9=other.';

-- =============================================================================
-- T-409 — bos.rel_release_manifest
-- Catálogo de releases disponibles por canal (canary→early→stable).
-- Pull-only desde SKULL Release Server. Firma Ed25519 + SHA-256.
-- No WORM: un manifest puede ser promovido a otro canal (UPDATE de channel).
-- GRUPO=rel · ENTIDAD=release · OBJETO=manifest
-- SBOS-RELEASE-001 · ISO 27001 A.8.32 · NIST CM-3 · ITIL 4 Change Enablement
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.rel_release_manifest (
    manifest_id         UUID         NOT NULL DEFAULT uuidv7(),
    daemon_name         TEXT         NOT NULL, -- bos, bauth, bkernel, biedata, bsearch, bnexus, bnotify
    version             TEXT         NOT NULL, -- SemVer MAJOR.MINOR.PATCH
    channel             TEXT         NOT NULL, -- canary|early|stable
    artifact_url        TEXT         NOT NULL, -- URL del binario en SKULL Release Server
    artifact_sha256     TEXT         NOT NULL, -- SHA-256 del artefacto descargado
    signature_ed25519   TEXT         NOT NULL, -- Firma Ed25519 del release server (verifica autenticidad)
    min_bos_version     TEXT         NULL,     -- versión mínima de BOS requerida para instalar
    release_notes       TEXT         NULL,     -- resumen de cambios
    is_rollback_target  BOOLEAN      NOT NULL DEFAULT false,  -- si este release es válido para rollback
    published_at        TIMESTAMPTZ  NOT NULL, -- cuándo el release server lo publicó
    pulled_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),  -- cuándo BOS lo descubrió
    ctx_id              TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT rel_rm_pkey              PRIMARY KEY (manifest_id),
    CONSTRAINT uq_rel_rm_daemon_ver_ch  UNIQUE (daemon_name, version, channel),
    CONSTRAINT chk_rel_rm_channel       CHECK (channel IN ('canary','early','stable')),
    CONSTRAINT chk_rel_rm_sha256        CHECK (artifact_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT chk_rel_rm_semver        CHECK (version ~ '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$')
);

CREATE INDEX IF NOT EXISTS idx_rel_rm_daemon   ON bos.rel_release_manifest (daemon_name, channel, pulled_at DESC);
CREATE INDEX IF NOT EXISTS idx_rel_rm_channel  ON bos.rel_release_manifest (channel, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_rel_rm_rollback ON bos.rel_release_manifest (daemon_name, is_rollback_target) WHERE is_rollback_target = true;

COMMENT ON TABLE bos.rel_release_manifest IS
  '[T-409] [SBOS-RELEASE-001] [ISO 27001:2022 A.8.32] [NIST CM-3] [ITIL 4 Change Enablement]
   Catálogo de releases disponibles por canal. Pull-only desde SKULL Release Server.
   El Release Plane (subsistema 10 de run_normal.go) consulta esta tabla para decidir
   si hay actualizaciones disponibles en el canal asignado al daemon.
   Canales: canary (primero, menos estable) → early → stable (producción).
   signature_ed25519: verificada con la clave pública del release server antes de instalar.
   artifact_sha256: verificado tras la descarga para garantizar integridad.
   is_rollback_target: true = el watchdog puede usar este release para rollback automático.
   Pull-only: BOS nunca empuja al release server. Conexión unidireccional (soberanía).';
COMMENT ON COLUMN bos.rel_release_manifest.channel IS
  'canary=primero (puede ser inestable) · early=probado parcialmente · stable=producción garantizada.';

-- =============================================================================
-- T-410 — bos.rel_release_event
-- Historial WORM de todas las actualizaciones y rollbacks de daemons.
-- WORM: REVOKE UPDATE, DELETE. Hash-chain SHA-256.
-- GRUPO=rel · ENTIDAD=release · OBJETO=event
-- ISO 27001 A.8.32 (Change Management) · NIST CM-3 · ITIL 4 Change Enablement
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.rel_release_event (
    event_id       UUID        NOT NULL DEFAULT uuidv7(),
    manifest_id    UUID        NOT NULL REFERENCES bos.rel_release_manifest(manifest_id),
    daemon_name    TEXT        NOT NULL,
    from_version   TEXT        NULL,      -- NULL si es primera instalación
    to_version     TEXT        NOT NULL,
    channel        TEXT        NOT NULL,
    operation      TEXT        NOT NULL,  -- INSTALL|UPDATE|ROLLBACK
    triggered_by   TEXT        NOT NULL DEFAULT 'scheduler', -- scheduler|watchdog|human
    actor_id       UUID        NULL       REFERENCES bauth.idn_identity_entity(entity_id),
    ip_address     INET        NULL,
    result         TEXT        NOT NULL DEFAULT 'OK',
    rollback_reason TEXT       NULL,      -- motivo si es ROLLBACK (e.g., "health_fail_60s")
    duration_ms    INTEGER     NULL,
    details        JSONB       NOT NULL DEFAULT '{}',
    executed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_hash      TEXT        NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT rel_re_pkey         PRIMARY KEY (event_id),
    CONSTRAINT chk_rel_re_op       CHECK (operation IN ('INSTALL','UPDATE','ROLLBACK')),
    CONSTRAINT chk_rel_re_trigger  CHECK (triggered_by IN ('scheduler','watchdog','human')),
    CONSTRAINT chk_rel_re_result   CHECK (result IN ('OK','FAIL','PARTIAL')),
    CONSTRAINT chk_rel_re_channel  CHECK (channel IN ('canary','early','stable')),
    CONSTRAINT chk_rel_re_details  CHECK (jsonb_typeof(details) = 'object')
);

REVOKE UPDATE, DELETE ON bos.rel_release_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_rel_re_daemon  ON bos.rel_release_event (daemon_name, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_rel_re_op      ON bos.rel_release_event (operation, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_rel_re_actor   ON bos.rel_release_event (actor_id, executed_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_rel_re_fail    ON bos.rel_release_event (daemon_name, result) WHERE result != 'OK';

COMMENT ON TABLE bos.rel_release_event IS
  '[T-410] [ISO 27001:2022 A.8.32] [NIST CM-3] [ITIL 4 Change Enablement] WORM 🔒
   Historial inmutable de todas las actualizaciones y rollbacks de daemons SBOS.
   triggered_by: scheduler=poll automático · watchdog=rollback automático (60s) · human=HITL.
   rollback_reason: causa del rollback automático (e.g., "health_fail_60s", "crash_loop").
   El watchdog (subsistema 9) ejecuta rollback si el daemon nuevo falla en 60s — este evento
   registra tanto el intento de actualización (result=FAIL) como el rollback subsecuente.
   prev_hash + REVOKE garantizan inmutabilidad forense para auditorías de cambio.';

-- =============================================================================
-- T-411 — bos.wdg_watchdog_event
-- Historial WORM del Watchdog Unificado — 3 capas cada 30s (Motor ② SO Observable).
-- WORM: REVOKE UPDATE, DELETE. Hash-chain SHA-256.
-- Capa 1: Ubuntu host (disco, RAM). Capa 2: K8s (nodos, pods). Capa 3: fichas BOS.
-- GRUPO=wdg · ENTIDAD=watchdog · OBJETO=event
-- ISO 27001 A.8.16 (Monitoring) · NIST AU-2, AU-12 · ITIL 4 Incident Management
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.wdg_watchdog_event (
    event_id       UUID        NOT NULL DEFAULT uuidv7(),
    check_layer    TEXT        NOT NULL,  -- ubuntu_host|k8s_cluster|bos_fichas
    severity       TEXT        NOT NULL,  -- INFO|WARN|ERROR|CRITICAL
    resource_type  TEXT        NOT NULL,  -- host|node|pod|ficha|daemon
    resource_id    TEXT        NULL,      -- nombre del recurso afectado
    tenant_id      UUID        NULL       REFERENCES bauth.idn_tenant(tenant_id),
    condition      TEXT        NOT NULL,  -- qué se detectó: disk_high, node_not_ready, ficha_degraded…
    metric_value   NUMERIC(10,4) NULL,    -- valor medido (e.g., 87.3 para disco al 87.3%)
    threshold      NUMERIC(10,4) NULL,    -- umbral que se superó
    action_taken   TEXT        NULL,      -- auto_repair|hitl_escalated|daemon_restart|rollback|none
    action_result  TEXT        NULL,      -- OK|FAIL|PENDING
    details        JSONB       NOT NULL DEFAULT '{}',
    detected_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at    TIMESTAMPTZ NULL,      -- NULL si sigue activo
    prev_hash      TEXT        NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT wdg_we_pkey          PRIMARY KEY (event_id),
    CONSTRAINT chk_wdg_we_layer     CHECK (check_layer IN ('ubuntu_host','k8s_cluster','bos_fichas')),
    CONSTRAINT chk_wdg_we_severity  CHECK (severity IN ('INFO','WARN','ERROR','CRITICAL')),
    CONSTRAINT chk_wdg_we_resource  CHECK (resource_type IN ('host','node','pod','ficha','daemon')),
    CONSTRAINT chk_wdg_we_action    CHECK (action_taken IN (
        'auto_repair','hitl_escalated','daemon_restart','rollback','none'
    ) OR action_taken IS NULL),
    CONSTRAINT chk_wdg_we_result    CHECK (action_result IN ('OK','FAIL','PENDING') OR action_result IS NULL),
    CONSTRAINT chk_wdg_we_details   CHECK (jsonb_typeof(details) = 'object')
);

REVOKE UPDATE, DELETE ON bos.wdg_watchdog_event FROM PUBLIC;

CREATE INDEX IF NOT EXISTS idx_wdg_we_layer     ON bos.wdg_watchdog_event (check_layer, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_wdg_we_severity  ON bos.wdg_watchdog_event (severity, detected_at DESC)
    WHERE severity IN ('ERROR','CRITICAL');
CREATE INDEX IF NOT EXISTS idx_wdg_we_resource  ON bos.wdg_watchdog_event (resource_id, detected_at DESC) WHERE resource_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wdg_we_tenant    ON bos.wdg_watchdog_event (tenant_id, detected_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wdg_we_activos   ON bos.wdg_watchdog_event (detected_at DESC) WHERE resolved_at IS NULL;

COMMENT ON TABLE bos.wdg_watchdog_event IS
  '[T-411] [ISO 27001:2022 A.8.16] [NIST AU-2, AU-12] [ITIL 4 Incident Management] WORM 🔒
   Historial inmutable del Watchdog Unificado (internal/watchdog/unified_watchdog.go).
   3 capas verificadas cada 30s:
     Capa 1 ubuntu_host: disco > 80%, RAM > 85%, load avg, swap
     Capa 2 k8s_cluster: nodos NotReady, pods CrashLoop/OOMKilled, PVCs pendientes
     Capa 3 bos_fichas: fichas en DEGRADADA/ERROR_*, health checks fallidos
   action_taken: lo que el watchdog hizo (auto_repair → llama bos.query.repair, rollback → Release Plane).
   resolved_at: cuándo el watchdog confirmó que el problema desapareció (NULL = aún activo).
   Los eventos CRITICAL sin resolved_at son la señal de HITL al operador.
   ISO 27001 A.8.16: monitoreo continuo de actividades + registro de alertas.';
COMMENT ON COLUMN bos.wdg_watchdog_event.condition IS
  'Condición detectada: disk_high, ram_high, load_high, node_not_ready, pod_crash_loop, pod_oom, ficha_degraded, ficha_error, daemon_unresponsive, etc.';

-- =============================================================================
-- T-412 — bos.ins_saga_execution
-- Tracking mutable de sagas generales (install/update/repair/remove/deploy_tenant).
-- No aplica a bootstrap (que usa ins_bootstrap_event).
-- Mutable: state cambia durante la ejecución. No WORM.
-- Los pasos individuales y sus compensaciones se registran en fch_ficha_event (saga_id FK).
-- GRUPO=ins · ENTIDAD=saga · OBJETO=execution
-- ISO 27001 A.8.32 (Change Management) · ITIL 4 Change Enablement · SRE (Google)
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.ins_saga_execution (
    saga_id           UUID        NOT NULL DEFAULT uuidv7(),
    saga_type         TEXT        NOT NULL,  -- install|update|repair|remove|deploy_tenant|remove_tenant
    ficha_name        TEXT        NULL,      -- NULL si es saga a nivel tenant (deploy_tenant)
    server_id         TEXT        NULL,      -- servidor lógico donde se ejecuta la saga
    tenant_id         UUID        NULL       REFERENCES bauth.idn_tenant(tenant_id),
    actor_id          UUID        NULL       REFERENCES bauth.idn_identity_entity(entity_id),
    ip_address        INET        NULL,
    from_version      TEXT        NULL,      -- versión antes del cambio (NULL si es install)
    to_version        TEXT        NULL,      -- versión objetivo (NULL si es remove)
    state             TEXT        NOT NULL DEFAULT 'RUNNING',
    current_step      SMALLINT    NULL,      -- paso actual (1-based)
    total_steps       SMALLINT    NULL,      -- total de pasos de la saga
    started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at      TIMESTAMPTZ NULL,
    duration_ms       INTEGER     NULL,      -- calculado al completar
    error_step        SMALLINT    NULL,      -- en qué paso falló (NULL si OK)
    error_message     TEXT        NULL,
    compensated_steps JSONB       NULL,      -- ["step3","step2","step1"] orden de compensación
    details           JSONB       NOT NULL DEFAULT '{}',
    ctx_id            TEXT        NOT NULL DEFAULT 'system',

    CONSTRAINT ins_se_pkey         PRIMARY KEY (saga_id),
    CONSTRAINT chk_ins_se_type     CHECK (saga_type IN (
        'install','update','repair','remove','deploy_tenant','remove_tenant','suspend_tenant'
    )),
    CONSTRAINT chk_ins_se_state    CHECK (state IN (
        'RUNNING','COMPLETED','FAILED','COMPENSATING','COMPENSATED'
    )),
    CONSTRAINT chk_ins_se_steps    CHECK (
        current_step IS NULL OR (current_step >= 1 AND current_step <= total_steps)
    ),
    CONSTRAINT chk_ins_se_details  CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT chk_ins_se_compen   CHECK (compensated_steps IS NULL OR jsonb_typeof(compensated_steps) = 'array')
);

CREATE INDEX IF NOT EXISTS idx_ins_se_ficha    ON bos.ins_saga_execution (ficha_name, started_at DESC) WHERE ficha_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_se_tenant   ON bos.ins_saga_execution (tenant_id, started_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_se_actor    ON bos.ins_saga_execution (actor_id, started_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ins_se_state    ON bos.ins_saga_execution (state, started_at DESC) WHERE state IN ('RUNNING','COMPENSATING');
CREATE INDEX IF NOT EXISTS idx_ins_se_type     ON bos.ins_saga_execution (saga_type, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_ins_se_failed   ON bos.ins_saga_execution (saga_type, error_step) WHERE state IN ('FAILED','COMPENSATED');

COMMENT ON TABLE bos.ins_saga_execution IS
  '[T-412] [ISO 27001:2022 A.8.32] [ITIL 4 Change Enablement] [Google SRE]
   Tracking de sagas generales del IAM Installer. No aplica a bootstrap (usa ins_bootstrap_event).
   Sagas cubiertas: install/update/repair/remove de fichas + deploy_tenant/remove_tenant/suspend_tenant.
   MUTABLE: state se actualiza a medida que la saga progresa. La decisión de no hacerlo WORM
   es intencional — el estado en curso necesita actualizarse (RUNNING→COMPLETED/FAILED/COMPENSATING).
   Trazabilidad de pasos: fch_ficha_event.saga_id FK referencia a este saga_id para agrupar
   todos los eventos de ficha generados por esta saga.
   compensated_steps: array JSON de steps revertidos en orden ["step3","step2","step1"].
   error_step: qué paso falló (para diagnóstico y reintentos selectivos).
   Los estados RUNNING y COMPENSATING que llevan > 2h sin completed_at son candidatos a HITL.';
COMMENT ON COLUMN bos.ins_saga_execution.saga_type IS
  'install/update/repair/remove=saga de ficha · deploy_tenant/remove_tenant/suspend_tenant=saga de tenant.';

-- =============================================================================
-- T-413 — bos.net_cert_inventory
-- Kardex de certificados TLS — ISO 27001:2022 A.8.24 (inventario de claves y certs).
-- Un registro por certificado activo: daemons host, fichas K8s, SVIDs SPIFFE, externos.
-- Inmutabilidad lógica: filas nunca se borran — transicionan active→expiring_soon→expired→revoked.
-- GRUPO=net · ENTIDAD=cert · OBJETO=inventory
-- A.15 §2.7 · RFC 8555 (ACME) · ISO 27001 A.8.24 · NIST SP 800-53 SC-12
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.net_cert_inventory (
    cert_id            UUID         NOT NULL DEFAULT uuidv7(),

    -- Identidad del certificado
    subject_cn         TEXT         NOT NULL,                        -- Common Name
    subject_san        TEXT[]       NOT NULL DEFAULT '{}',           -- Subject Alternative Names
    issuer             TEXT         NOT NULL,                        -- Nombre del emisor (CA)
    serial_number      TEXT         NULL,                            -- RFC 5280 §4.1.2.2 — para OCSP
    fingerprint_sha256 TEXT         NOT NULL,                        -- SHA-256 del certificado DER

    -- Vigencia
    valid_from         TIMESTAMPTZ  NOT NULL,
    valid_until        TIMESTAMPTZ  NOT NULL,
    -- days_remaining: calculado en queries como EXTRACT(DAY FROM (valid_until - NOW()))::INTEGER
    --                 NO se almacena — NOW() no es IMMUTABLE en PostgreSQL GENERATED columns.

    -- Clasificación
    cert_type          TEXT         NOT NULL,                        -- ver CHECK
    key_algorithm      TEXT         NOT NULL DEFAULT 'ECDSA',        -- ECDSA|RSA
    key_size           SMALLINT     NOT NULL DEFAULT 256,            -- bits: 256|384|2048|4096

    -- Ubicación del certificado
    service_name       TEXT         NULL,                            -- ficha o daemon al que sirve
    namespace          TEXT         NULL,                            -- namespace K8s (NULL=host)
    ficha_id           TEXT         NULL,                            -- ficha asociada
    secret_name        TEXT         NULL,                            -- K8s Secret con el cert
    host_path          TEXT         NULL,                            -- ruta en el host (/etc/bos/tls/)

    -- Motor de emisión
    issuer_engine      TEXT         NOT NULL,                        -- ver CHECK
    auto_renew         BOOLEAN      NOT NULL DEFAULT TRUE,
    renew_before_days  SMALLINT     NOT NULL DEFAULT 30,

    -- Estado — ciclo de vida
    status             TEXT         NOT NULL DEFAULT 'active',       -- ver CHECK
    issued_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),          -- cuándo fue emitido (≠ valid_from)
    revoked_at         TIMESTAMPTZ  NULL,
    revocation_reason  TEXT         NULL,
    last_renewed_at    TIMESTAMPTZ  NULL,                            -- última renovación exitosa
    last_checked_at    TIMESTAMPTZ  NULL,
    ctx_id             TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT net_ci_pkey              PRIMARY KEY (cert_id),
    CONSTRAINT uq_net_ci_fingerprint    UNIQUE (fingerprint_sha256),
    CONSTRAINT chk_net_ci_cert_type     CHECK (cert_type IN (
        'daemon_host','ficha_k8s','spiffe_svid','external_wildcard','kong_tls','ca_internal'
    )),
    CONSTRAINT chk_net_ci_issuer_engine CHECK (issuer_engine IN (
        'vault_pki','cert_manager','spire','acme_le','manual'
    )),
    CONSTRAINT chk_net_ci_key_algo      CHECK (key_algorithm IN ('ECDSA','RSA','Ed25519')),
    CONSTRAINT chk_net_ci_status        CHECK (status IN (
        'active','expiring_soon','expired','revoked','superseded'
    )),
    CONSTRAINT chk_net_ci_validity      CHECK (valid_until > valid_from),
    CONSTRAINT chk_net_ci_revoke_state  CHECK (
        (status = 'revoked' AND revoked_at IS NOT NULL) OR
        (status != 'revoked' AND revoked_at IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_net_ci_status    ON bos.net_cert_inventory (status)
    WHERE status IN ('active','expiring_soon');
CREATE INDEX IF NOT EXISTS idx_net_ci_expiry    ON bos.net_cert_inventory (valid_until)
    WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_net_ci_ficha     ON bos.net_cert_inventory (ficha_id)
    WHERE ficha_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_net_ci_engine    ON bos.net_cert_inventory (issuer_engine);
CREATE INDEX IF NOT EXISTS idx_net_ci_type      ON bos.net_cert_inventory (cert_type);

COMMENT ON TABLE bos.net_cert_inventory IS
  '[T-413] [A.15 §2.7] [RFC 8555] [ISO 27001:2022 A.8.24] [NIST SC-12]
   Kardex de certificados TLS del entorno SBOS — daemons host, fichas K8s,
   SVIDs SPIFFE/SPIRE y certs externos. Inventario de claves ISO 27001 A.8.24.
   days_remaining es columna generada — siempre actualizada sin trigger.
   INMUTABILIDAD LÓGICA: filas nunca se borran — transicionan active→revoked.';

COMMENT ON COLUMN bos.net_cert_inventory.cert_type IS
  'daemon_host=cert de daemon BOS en el host (Vault PKI 90d) |
   ficha_k8s=cert de ficha en K8s (cert-manager 90d) |
   spiffe_svid=identidad de workload SPIFFE/SPIRE (24h) |
   external_wildcard=cert externo Let''s Encrypt (acme.sh 90d) |
   ca_internal=CA interna SBOS (3 años o 10 años para Root CA)';

COMMENT ON COLUMN bos.net_cert_inventory.issuer_engine IS
  'vault_pki=Vault PKI secrets engine (daemons host) |
   cert_manager=cert-manager K8s CRD (fichas K8s) |
   spire=SPIRE Server SVID (mTLS entre pods) |
   acme_le=acme.sh + Let''s Encrypt (certs externos) |
   manual=cert creado manualmente (solo en emergencia, requiere HITL)';

-- =============================================================================
-- T-414 — bos.net_security_events
-- Log de eventos de seguridad de red — ISO 27001 A.8.21 / NIST SP 800-41.
-- Alta escritura (miles de eventos/día en producción). Retención: 90 días.
-- Fuentes: PORTMAN · CERTMAN · FWMAN · IPS · CrowdSec · fail2ban · psad.
-- GRUPO=net · ENTIDAD=security · OBJETO=events
-- A.15 §4.3 · ISO 27001 A.8.21 · NIST SP 800-41 · CIS K8s Benchmark v1.10
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.net_security_events (
    event_id     UUID         NOT NULL DEFAULT uuidv7(),
    event_time   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    event_type   TEXT         NOT NULL,   -- ver CHECK
    severity     TEXT         NOT NULL DEFAULT 'info',  -- ver CHECK
    source       TEXT         NOT NULL,   -- 'portman'|'certman'|'fwman'|'ips'|'crowdsec'|'fail2ban'|'psad'

    -- Contexto de la ficha / servicio afectado
    ficha_id     TEXT         NULL,
    service_name TEXT         NULL,
    namespace    TEXT         NULL,

    -- Red
    src_ip       INET         NULL,       -- IP origen (para eventos IPS/firewall)
    dst_port     INTEGER      NULL,       -- puerto destino

    -- Detalles del evento
    details      JSONB        NULL,       -- payload libre por event_type
    ctx_id       TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT net_se_pkey          PRIMARY KEY (event_id),
    CONSTRAINT chk_net_se_type      CHECK (event_type IN (
        -- PORTMAN
        'port_assigned','port_released','port_conflict','port_validated',
        -- CERTMAN
        'cert_issued','cert_renewed','cert_expiring','cert_revoked',
        -- FWMAN
        'fw_rule_added','fw_rule_removed','netpol_synced','fw_drift_detected',
        -- IPS
        'ips_block','ips_unblock','port_scan_detected',
        'crowdsec_ban','crowdsec_unban','fail2ban_ban','fail2ban_unban',
        'ddos_detected','brute_force_detected','replay_detected'
    )),
    CONSTRAINT chk_net_se_severity  CHECK (severity IN ('info','warn','high','critical')),
    CONSTRAINT chk_net_se_source    CHECK (source IN (
        'portman','certman','fwman','ips','crowdsec','fail2ban','psad','bos_daemon'
    ))
) PARTITION BY RANGE (event_time);

-- Partición inicial — el daemon BOS crea particiones mensuales automáticamente
CREATE TABLE IF NOT EXISTS bos.net_security_events_default
    PARTITION OF bos.net_security_events DEFAULT;

CREATE INDEX IF NOT EXISTS idx_net_se_time     ON bos.net_security_events (event_time DESC);
CREATE INDEX IF NOT EXISTS idx_net_se_type     ON bos.net_security_events (event_type);
CREATE INDEX IF NOT EXISTS idx_net_se_severity ON bos.net_security_events (severity)
    WHERE severity IN ('high','critical');
CREATE INDEX IF NOT EXISTS idx_net_se_src_ip   ON bos.net_security_events (src_ip)
    WHERE src_ip IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_net_se_ficha    ON bos.net_security_events (ficha_id)
    WHERE ficha_id IS NOT NULL;

COMMENT ON TABLE bos.net_security_events IS
  '[T-414] [A.15 §4.3] [ISO 27001:2022 A.8.21] [NIST SP 800-41] [CIS K8s v1.10]
   Log de eventos de seguridad de red de todos los motores NetMan.
   Alta escritura — particionado mensual por event_time (RANGE).
   Retención: 90 días. El daemon BOS crea particiones mensuales y elimina las vencidas.
   src_ip usa tipo INET (PostgreSQL nativo) para búsquedas por red.';

-- =============================================================================
-- RESUMEN — 20 tablas · 8 WORM · schema bos · 8 grupos funcionales
-- =============================================================================
-- GRUPO CTX — Motor ④ Context Plane                          8 tablas ✅
-- T-395    bos.ctx_registered_device     Dispositivos pre-auth (BitMask=0, TTL 8h)
-- T-396    bos.ctx_context_session       Sesiones post-auth (ctx_id 6 capas, TTL 12h)
-- T-397    bos.ctx_context_audit         Auditoría WORM 🔒 (hash-chain SHA-256)
-- T-398    bos.ctx_context_switch_log    Historial WORM de cambios de contexto 🔒
-- T-399    bos.ctx_context_policy        Políticas TTL/seguridad por tenant
-- T-400    bos.ctx_device_heartbeat      Heartbeats (24h retención, alta escritura)
-- T-401    bos.ctx_context_transfer      Transferencia entre dispositivos WORM 🔒
-- T-402    bos.ctx_context_emergency     Break-glass de contexto (control dual) WORM 🔒
--
-- GRUPO FCH — Motor ③ Server FICHAS                          2 tablas ✅
-- T-403  bos.fch_ficha_state           Estado actual fichas (18 estados, sin tenant_id)
-- T-404  bos.fch_ficha_event           Historial WORM de eventos de fichas 🔒
--
-- GRUPO INS — Motor ① IAM Installer                          3 tablas ✅
-- T-405  bos.ins_bootstrap_event       Bootstrap 6 capas WORM 🔒 (capas 0-2: sin tenant aún)
-- T-412 bos.ins_saga_execution        Tracking mutable de sagas generales (install/update/repair/remove/tenant)
--          [T-405 cubre bootstrap · T-412 cubre el resto de las sagas del Installer]
--
-- GRUPO CAP — Motor ② SO Observable / Capacidad             2 tablas ✅
-- T-406  bos.cap_sistema_snapshot      30+ métricas cada 60s (particionado mensual + cron DROP)
-- T-407  bos.cap_tenant_policy         Políticas por tenant (fallback = fila del tenant raíz)
--
-- GRUPO PRT — Port Manager (A.12 / RFC 6335 BCP 165)        1 tabla  ✅
-- T-408  bos.prt_port_assignment       Kardex de puertos (inmutabilidad lógica, RFC 6335 §8)
--
-- GRUPO NET — Network Security Manager (A.15)               2 tablas ✅
-- T-413  bos.net_cert_inventory        Kardex de certificados TLS (ISO 27001 A.8.24)
-- T-414  bos.net_security_events       Log de eventos de seguridad de red (particionado mensual)
--
-- GRUPO REL — Release Plane (SBOS-RELEASE-001)              2 tablas ✅
-- T-409  bos.rel_release_manifest      Catálogo de releases por canal (canary→early→stable)
-- T-410  bos.rel_release_event         Historial WORM de actualizaciones y rollbacks 🔒
--
-- GRUPO WDG — Motor ② SO Observable / Watchdog              1 tabla  ✅
-- T-411  bos.wdg_watchdog_event        Watchdog 3 capas WORM 🔒 (host|k8s|fichas)
--
-- FKs a bauth: idn_tenant(tenant_id) · idn_identity_entity(entity_id)
-- FKs intra-bos: fch_ficha_event → fch_ficha_state
--               ctx_registered_device → ctx_context_session → audit/switch/transfer/emergency
--               rel_release_event → rel_release_manifest
-- SEED obligatorio (orden): idn_tenant raíz → idn_identity_entity empresa master
--   → idn_identity_entity sucursal master → cap_tenant_politica raíz
-- =============================================================================
