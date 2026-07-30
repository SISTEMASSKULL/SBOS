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
  '[T-399] [ISO 27001:2022 A.9.4.2] [NIST SP 800-207 §3.3] [SBOS-049 §8]
   Políticas de TTL y seguridad del Context Plane. CAPA DE INFRAESTRUCTURA.
   NO duplica bauth.idn_tenant.session_ttl_max (TTL de identidad). UNIQUE por tenant.';
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
-- T-NEW-1 — bos.fch_ficha_state
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
    state                TEXT        NOT NULL DEFAULT 'PENDIENTE',
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
        'PENDIENTE','LISTA','INSTALANDO','INSTALADA',
        'ACTUALIZACION_DISPONIBLE','ACTUALIZACION_APROBADA','ACTUALIZANDO',
        'DEGRADADA','ERROR_FISICO','ERROR_LOGICO','REPARANDO',
        'ERROR_NO_CORREGIBLE','FALLA_INSTALACION','FALLA_ACTUALIZACION',
        'ROLLBACK','LIMPIEZA','PAUSADA','DESINSTALADA'
    )),
    CONSTRAINT chk_fch_s_backend    CHECK (backend IN ('bash','k8s','binary','python')),
    CONSTRAINT chk_fch_s_category   CHECK (category BETWEEN 1 AND 5),
    CONSTRAINT chk_fch_s_hashes     CHECK (jsonb_typeof(hashes) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_fch_s_server   ON bos.fch_ficha_state (server_id);
CREATE INDEX IF NOT EXISTS idx_fch_s_state    ON bos.fch_ficha_state (state);
CREATE INDEX IF NOT EXISTS idx_fch_s_degraded ON bos.fch_ficha_state (state)
    WHERE state IN ('DEGRADADA','ERROR_FISICO','ERROR_LOGICO','ERROR_NO_CORREGIBLE');

COMMENT ON TABLE bos.fch_ficha_state IS
  '[T-NEW-1] [SBOS-019] [3.01 máquina 18 estados] [ISO 27001:2022 A.8.9] [NIST CM-8]
   Estado actual de cada ficha declarativa. Máquina de 18 estados (ADR-021).
   Sin tenant_id: las fichas son componentes de plataforma compartidos (Motor ③).
   Multi-tenancy = concepto de datos (discriminadores, RLS), no de infraestructura.
   Clave natural: (ficha_name, server_id) — una ficha por servidor lógico.
   hashes: SHA-256 de manifest.yml, yaml_engine.yml y task_catalog.sh para drift detection.
   installed_by / updated_by: trazabilidad NIST AU-3 / ISO A.8.9.';

-- =============================================================================
-- T-NEW-2 — bos.fch_ficha_event
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
  '[T-NEW-2] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-2, AU-3, AU-12]
   Historial WORM de todos los cambios de estado de fichas. REVOKE UPDATE/DELETE.
   Hash-chain SHA-256 (prev_hash) para inmutabilidad verificable.
   tenant_id: tenant que DISPARÓ el evento (origen de auditoría), no dueño de la ficha.
   actor_id + ip_address: quién y desde dónde — requisito NIST AU-3, ISO A.8.15.
   saga_id: agrupa todos los eventos de una misma saga install/update/repair/remove.
   operation: nombre del paso en la saga (ej. "install.preflight", "repair.verify").';

-- =============================================================================
-- T-NEW-3 — bos.ins_bootstrap_event
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
  '[T-NEW-3] [ISO 27001:2022 A.8.15] [NIST SP 800-53 AU-3, CM-8] [ADR-040] [1.01 §4]
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
-- T-NEW-4 — bos.cap_sistema_snapshot
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

    fichas_healthy        INTEGER      NULL,
    fichas_degraded       INTEGER      NULL,
    fichas_error          INTEGER      NULL,
    fichas_total          INTEGER      NULL,

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
CREATE INDEX IF NOT EXISTS idx_cap_sn_degraded    ON bos.cap_sistema_snapshot (fichas_degraded, captured_at DESC)
    WHERE fichas_degraded > 0;

COMMENT ON TABLE bos.cap_sistema_snapshot IS
  '[T-NEW-4] [SBOS-BOS-CAP-001] [2.02 M5.1] [ISO 27001:2022 A.12.4]
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
-- T-NEW-5 — bos.cap_tenant_politica
-- Políticas de capacidad por tenant (Motor ② M5.3).
-- Fallback: si el tenant no tiene fila, Motor M5.3 usa la fila del tenant raíz.
-- El tenant raíz y su política se siembran en el seed de creación de SBOS_db.
-- GRUPO=cap · ENTIDAD=tenant · OBJETO=politica
-- SBOS-BOS-CAP-001 · 2.02 M5.3 · ISO 27001:2022 A.8.9 · NIST SP 800-53 CA-7
-- =============================================================================
CREATE TABLE IF NOT EXISTS bos.cap_tenant_politica (
    politica_id              UUID         NOT NULL DEFAULT uuidv7(),
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

    CONSTRAINT cap_tp_pkey              PRIMARY KEY (politica_id),
    CONSTRAINT uq_cap_tp_tenant         UNIQUE (tenant_id),
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

CREATE INDEX IF NOT EXISTS idx_cap_tp_mode  ON bos.cap_tenant_politica (policy_mode);
CREATE INDEX IF NOT EXISTS idx_cap_tp_actor ON bos.cap_tenant_politica (updated_by) WHERE updated_by IS NOT NULL;

COMMENT ON TABLE bos.cap_tenant_politica IS
  '[T-NEW-5] [SBOS-BOS-CAP-001] [2.02 M5.3] [ISO 27001:2022 A.8.9] [NIST SP 800-53 CA-7]
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
COMMENT ON COLUMN bos.cap_tenant_politica.policy_mode IS
  'autonomous=BOS actúa solo · recommend=HITL aprueba · block_and_alert=bloquea · emergency=protocolo completo.';
COMMENT ON COLUMN bos.cap_tenant_politica.kong_tenant_rps_cap IS
  'Cap total de RPS del tenant en Kong PEP. Capa de infraestructura. Ver ctx_context_policy.rate_limit_rps para capa Context API.';

-- =============================================================================
-- RESUMEN — 13 tablas · 6 WORM · schema bos · 4 grupos funcionales
-- =============================================================================
-- GRUPO CTX — Motor ④ Context Plane                          8 tablas ✅
-- T-395  bos.ctx_registered_device       Dispositivos pre-auth (BitMask=0, TTL 8h)
-- T-396  bos.ctx_context_session         Sesiones post-auth (ctx_id 6 capas, TTL 12h)
-- T-397  bos.ctx_context_audit           Auditoría WORM 🔒 (hash-chain SHA-256)
-- T-398  bos.ctx_context_switch_log      Historial WORM de cambios de contexto 🔒
-- T-399  bos.ctx_context_policy          Políticas TTL/seguridad por tenant
-- T-400  bos.ctx_device_heartbeat        Heartbeats (24h retención, alta escritura)
-- T-401  bos.ctx_context_transfer        Transferencia entre dispositivos WORM 🔒
-- T-402  bos.ctx_context_emergency       Break-glass de contexto (control dual) WORM 🔒
--
-- GRUPO FCH — Motor ③ Server FICHAS                          2 tablas ✅
-- T-NEW-1  bos.fch_ficha_state           Estado actual fichas (18 estados, sin tenant_id)
-- T-NEW-2  bos.fch_ficha_event           Historial WORM de eventos de fichas 🔒
--
-- GRUPO INS — Motor ① IAM Installer                          1 tabla  ✅
-- T-NEW-3  bos.ins_bootstrap_event       Bootstrap 6 capas WORM 🔒 (tenant raíz = capas 0-2)
--
-- GRUPO CAP — Motor ② SO Observable / Capacidad             2 tablas ✅
-- T-NEW-4  bos.cap_sistema_snapshot      30+ métricas cada 60s (particionado mensual)
-- T-NEW-5  bos.cap_tenant_politica       Políticas por tenant (fallback = tenant raíz)
--
-- FKs a bauth: idn_tenant(tenant_id) · idn_identity_entity(entity_id)
-- FKs intra-bos: fch_ficha_event → fch_ficha_state
--               ctx_registered_device → ctx_context_session → audit/switch/transfer/emergency
-- SEED obligatorio (orden): idn_tenant raíz → idn_identity_entity empresa master
--   → idn_identity_entity sucursal master → cap_tenant_politica raíz
-- =============================================================================
