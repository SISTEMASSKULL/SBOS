-- =============================================================================
-- bAuth Dominios Pendientes v1.0
-- T-codes corregidos vs. A.65.02 (conflictos resueltos):
--   D07 → T-195..T-201 (T-320..T-326 tomados por USUARIOS)
--   D09 pwd_history → T-202 (T-360 tomado por sig_document_hash)
--   D10 → T-415..T-420 (T-380..T-385 tomados por BILLETERA+AUTH)
--   D11 → T-421..T-424 (T-400..T-403 tomados por CONTEXT PLANE+BOS)
--   D12 extra → T-425..T-429
-- Idempotente: CREATE TABLE/INDEX IF NOT EXISTS
-- =============================================================================

SET search_path = bauth, public;

-- ===========================================================================
-- D99 — Admin Global Soberano (T-510..T-515)
-- Primero: son prerequisito de otras tablas (FK admin_id)
-- ===========================================================================

-- T-510: Administradores globales del sistema (separación admin-tenant vs. super-admin)
CREATE TABLE IF NOT EXISTS bauth.idn_global_admin (
    id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_id     UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id       UUID        NOT NULL REFERENCES bauth.idn_user(user_id),
    admin_role    TEXT        NOT NULL CHECK (admin_role IN ('SUPER_ADMIN','SECURITY_ADMIN','AUDIT_ADMIN','SUPPORT_ADMIN')),
    can_manage_tenants  BOOLEAN NOT NULL DEFAULT false,
    can_manage_crypto   BOOLEAN NOT NULL DEFAULT false,
    can_read_audit_all  BOOLEAN NOT NULL DEFAULT false,
    required_aal  INTEGER     NOT NULL DEFAULT 3 CHECK (required_aal = 3),
    status        TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),
    activated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_auth_at  TIMESTAMPTZ,
    deactivated_at TIMESTAMPTZ,
    deactivated_by UUID       REFERENCES bauth.idn_user(user_id),
    reason        TEXT,
    ctx_id        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iga_user UNIQUE (user_id)
);
CREATE INDEX IF NOT EXISTS idx_iga_status ON bauth.idn_global_admin (status);

-- T-513: Catálogo de parámetros criptográficos — gobierno del stack cripto (NIST SP 800-131A R2)
CREATE TABLE IF NOT EXISTS bauth.idn_global_crypto_params (
    id                  UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    algorithm_name      TEXT  NOT NULL UNIQUE,
    algorithm_family    TEXT  NOT NULL CHECK (algorithm_family IN ('SYMMETRIC','ASYMMETRIC','HASH','KDF','KEM','SIGNATURE','MAC')),
    key_size_bits       INTEGER,
    is_pqc              BOOLEAN NOT NULL DEFAULT false,
    is_approved         BOOLEAN NOT NULL DEFAULT true,
    is_deprecated       BOOLEAN NOT NULL DEFAULT false,
    is_prohibited       BOOLEAN NOT NULL DEFAULT false,
    fips_standard       TEXT,
    nist_standard       TEXT,
    migration_deadline  DATE,
    replacement_algorithm TEXT,
    use_cases           TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_igcp_not_both CHECK (NOT (is_approved AND is_prohibited))
);
CREATE INDEX IF NOT EXISTS idx_igcp_approved ON bauth.idn_global_crypto_params (is_approved, algorithm_family);
CREATE INDEX IF NOT EXISTS idx_igcp_pqc ON bauth.idn_global_crypto_params (is_pqc) WHERE is_pqc = true;
CREATE INDEX IF NOT EXISTS idx_igcp_prohibited ON bauth.idn_global_crypto_params (is_prohibited) WHERE is_prohibited = true;

-- T-511: Notificaciones globales del sistema
CREATE TABLE IF NOT EXISTS bauth.idn_global_notificacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('SECURITY_ALERT','CRYPTO_EXPIRY','CERT_EXPIRY','COMPLIANCE_WARNING','MAINTENANCE','INCIDENT','POLICY_CHANGE','CAPACITY_ALERT')),
    severity        TEXT  NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),
    titulo          TEXT  NOT NULL,
    mensaje         TEXT  NOT NULL,
    target_scope    TEXT  NOT NULL DEFAULT 'ALL' CHECK (target_scope IN ('ALL','TENANT','ADMIN')),
    target_tenant_id UUID REFERENCES bauth.idn_tenant(tenant_id),
    target_admin_id  UUID REFERENCES bauth.idn_global_admin(id),
    leido           BOOLEAN NOT NULL DEFAULT false,
    leido_at        TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ign_unread ON bauth.idn_global_notificacion (leido, severity, created_at DESC) WHERE leido = false;

-- T-512: Excepciones HITL (Human-In-The-Loop) — NIST AI RMF 1.0 §3.6
CREATE TABLE IF NOT EXISTS bauth.idn_global_hitl_excepcion (
    id                    UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tipo_excepcion        TEXT  NOT NULL CHECK (tipo_excepcion IN ('ALGO_PROHIBIDO','POLITICA_SOBRERIDADA','ACCESO_EMERGENCIA','CRYPTO_DOWNGRADE','NORMA_INCUMPLIDA','AI_DECISION_REVISADA')),
    descripcion           TEXT  NOT NULL CHECK (length(descripcion) >= 50),
    justificacion_negocio TEXT  NOT NULL CHECK (length(justificacion_negocio) >= 100),
    solicitante_id        UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    aprobador_id          UUID  REFERENCES bauth.idn_global_admin(id),
    status                TEXT  NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED','REVOKED')),
    approved_at           TIMESTAMPTZ,
    valid_from            TIMESTAMPTZ,
    valid_until           TIMESTAMPTZ NOT NULL,
    review_at             TIMESTAMPTZ,  -- calculado por app: valid_until - 7 días
    affected_entity_type  TEXT  NOT NULL CHECK (affected_entity_type IN ('ALGORITHM','POLICY','TENANT','USER','ROLE','CERT')),
    affected_entity_ref   TEXT  NOT NULL,
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ighe_pending ON bauth.idn_global_hitl_excepcion (status, review_at) WHERE status = 'APPROVED';

-- T-514: Mapa de controles de cumplimiento normativo global
CREATE TABLE IF NOT EXISTS bauth.idn_global_compliance_control (
    id                UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    standard_name     TEXT  NOT NULL,
    control_id        TEXT  NOT NULL,
    control_title     TEXT  NOT NULL,
    control_desc      TEXT  NOT NULL,
    status            TEXT  NOT NULL DEFAULT 'IMPLEMENTED' CHECK (status IN ('IMPLEMENTED','PARTIAL','PLANNED','NOT_APPLICABLE','GAP')),
    evidence_type     TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    evidence_location TEXT,
    last_reviewed_at  TIMESTAMPTZ,
    next_review_at    TIMESTAMPTZ,
    owner_admin_id    UUID  REFERENCES bauth.idn_global_admin(id),
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igcc_standard_ctrl UNIQUE (standard_name, control_id)
);
CREATE INDEX IF NOT EXISTS idx_igcc_status ON bauth.idn_global_compliance_control (status, standard_name);

-- T-515: SBOM — Software Bill of Materials (NTIA SBOM 2021 · EU Cyber Resilience Act)
CREATE TABLE IF NOT EXISTS bauth.idn_global_sbom (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    component_name  TEXT  NOT NULL,
    component_type  TEXT  NOT NULL CHECK (component_type IN ('LIBRARY','FRAMEWORK','DAEMON','TOOL','OS_PACKAGE','CONTAINER')),
    version         TEXT  NOT NULL,
    language        TEXT,
    license         TEXT,
    package_url     TEXT,
    cve_known       TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    risk_level      TEXT  NOT NULL DEFAULT 'LOW' CHECK (risk_level IN ('CRITICAL','HIGH','MEDIUM','LOW','NONE')),
    last_scanned_at TIMESTAMPTZ,
    is_direct_dep   BOOLEAN NOT NULL DEFAULT true,
    daemon_name     TEXT  NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igs_comp_ver_daemon UNIQUE (component_name, version, daemon_name)
);
CREATE INDEX IF NOT EXISTS idx_igs_risk ON bauth.idn_global_sbom (risk_level, daemon_name) WHERE risk_level IN ('CRITICAL','HIGH');

-- ===========================================================================
-- D07 — Control de Red / ZTA (T-195..T-201)
-- T-codes CORREGIDOS: audit doc usó T-320..T-326 (tomados por USUARIOS)
-- ===========================================================================

-- T-195: Política de conexión (TLS, mTLS, DPoP, PKCE) — RFC 8705 · NIST SP 800-52 R2
CREATE TABLE IF NOT EXISTS bauth.idn_red_conexion_policy (
    id                    UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id             UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name           TEXT  NOT NULL,
    min_tls_version       TEXT  NOT NULL DEFAULT 'TLS_1_3' CHECK (min_tls_version IN ('TLS_1_2','TLS_1_3')),
    require_mtls          BOOLEAN NOT NULL DEFAULT false,
    require_dpop          BOOLEAN NOT NULL DEFAULT false,
    require_pkce          BOOLEAN NOT NULL DEFAULT true,
    cipher_suites         TEXT[] NOT NULL DEFAULT ARRAY['TLS_AES_256_GCM_SHA384','TLS_CHACHA20_POLY1305_SHA256'],
    allowed_ip_ranges     INET[],
    blocked_ip_ranges     INET[],
    rate_limit_rps        INTEGER CHECK (rate_limit_rps > 0),
    max_conn_per_ip       INTEGER CHECK (max_conn_per_ip > 0),
    status                TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    notes                 TEXT,
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ircp_tenant_name UNIQUE (tenant_id, policy_name)
);
CREATE INDEX IF NOT EXISTS idx_ircp_tenant_status ON bauth.idn_red_conexion_policy (tenant_id, status);

-- T-196: DPoP binding — sender-constraining de tokens (RFC 9449 §4) · FAPI 2.0
-- WORM: solo INSERT (los bindings son de un solo uso)
CREATE TABLE IF NOT EXISTS bauth.idn_red_dpop_binding (
    id            UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id     UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    jti           TEXT  NOT NULL,       -- JWT ID único del DPoP proof
    token_jti     TEXT  NOT NULL,       -- JTI del access token asociado
    dpop_jkt      TEXT  NOT NULL,       -- JWK thumbprint SHA-256 clave pública
    http_method   TEXT  NOT NULL,
    http_uri      TEXT  NOT NULL,
    alg           TEXT  NOT NULL DEFAULT 'ES256' CHECK (alg IN ('ES256','ES384','RS256','PS256','EdDSA')),
    ath           TEXT,                 -- hash del access token (RFC 9449 §4.2)
    nonce         TEXT,                 -- server nonce para replay prevention
    issued_at     TIMESTAMPTZ NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    used          BOOLEAN NOT NULL DEFAULT false,
    client_ip     INET,
    ctx_id        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irdb_jti UNIQUE (jti),
    CONSTRAINT chk_irdb_expiry CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS idx_irdb_token ON bauth.idn_red_dpop_binding (token_jti, used);
CREATE INDEX IF NOT EXISTS idx_irdb_expires ON bauth.idn_red_dpop_binding (expires_at) WHERE used = false;
CREATE INDEX IF NOT EXISTS idx_irdb_tenant ON bauth.idn_red_dpop_binding (tenant_id, created_at DESC);

-- T-197: Política de rate limiting — OWASP API Security 2023 §6
CREATE TABLE IF NOT EXISTS bauth.idn_red_rate_policy (
    id                  UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    scope               TEXT  NOT NULL CHECK (scope IN ('GLOBAL','TENANT','CLIENT','USER','IP')),
    scope_ref           UUID,
    endpoint_pattern    TEXT,
    requests_per_second INTEGER NOT NULL CHECK (requests_per_second > 0),
    burst_size          INTEGER NOT NULL CHECK (burst_size > 0),
    window_seconds      INTEGER NOT NULL DEFAULT 60,
    action_on_exceed    TEXT  NOT NULL DEFAULT 'THROTTLE' CHECK (action_on_exceed IN ('THROTTLE','BLOCK','NOTIFY')),
    status              TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_irrp_tenant_scope ON bauth.idn_red_rate_policy (tenant_id, scope, status);

-- T-198: Política de postura de dispositivo ZTA — NIST SP 800-207 §3.3
CREATE TABLE IF NOT EXISTS bauth.idn_red_postura_policy (
    id                      UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id               UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name             TEXT  NOT NULL,
    require_compliant_device BOOLEAN NOT NULL DEFAULT false,
    require_managed_device  BOOLEAN NOT NULL DEFAULT false,
    min_risk_score          INTEGER NOT NULL DEFAULT 0 CHECK (min_risk_score BETWEEN 0 AND 100),
    max_risk_score          INTEGER NOT NULL DEFAULT 100 CHECK (max_risk_score BETWEEN 0 AND 100),
    require_mdm_enrolled    BOOLEAN NOT NULL DEFAULT false,
    allow_byod              BOOLEAN NOT NULL DEFAULT true,
    posture_ttl_minutes     INTEGER NOT NULL DEFAULT 240,
    action_on_fail          TEXT  NOT NULL DEFAULT 'STEP_UP' CHECK (action_on_fail IN ('DENY','STEP_UP','NOTIFY','CHALLENGE')),
    status                  TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id                  TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irpp_tenant_name UNIQUE (tenant_id, policy_name)
);

-- T-199: Segmentos de red — NIST SP 800-207 §2.1 · ISO 27001 A.8.22
CREATE TABLE IF NOT EXISTS bauth.idn_red_segmento (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    segmento_nombre TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('DMZ','INTERNA','CONFIABLE','AISLADA','CUARENTENA')),
    cidr_ranges     INET[] NOT NULL,
    trust_level     TEXT  NOT NULL DEFAULT 'UNTRUSTED' CHECK (trust_level IN ('TRUSTED','CONDITIONALLY_TRUSTED','UNTRUSTED')),
    requiere_mtls   BOOLEAN NOT NULL DEFAULT false,
    requiere_vpn    BOOLEAN NOT NULL DEFAULT false,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    notas           TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irs_tenant_nombre UNIQUE (tenant_id, segmento_nombre)
);

-- T-200: Política DLP de inspección — NIST SP 800-53 R5 SI-3 · ISO 27001 A.8.12
CREATE TABLE IF NOT EXISTS bauth.idn_red_dlp_policy (
    id                       UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id                UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name              TEXT  NOT NULL,
    inspeccion_payload       BOOLEAN NOT NULL DEFAULT false,
    inspeccion_headers       BOOLEAN NOT NULL DEFAULT true,
    max_payload_bytes        INTEGER CHECK (max_payload_bytes > 0),
    content_types_permitidos TEXT[],
    patrones_sensibles       TEXT[],
    accion                   TEXT  NOT NULL DEFAULT 'LOG' CHECK (accion IN ('LOG','BLOCK','REDACT','QUARANTINE')),
    status                   TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id                   TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irdlp_tenant_name UNIQUE (tenant_id, policy_name)
);

-- T-201: Configuración de propagación del ctx_id — SBOS-049 · W3C Trace Context v2
CREATE TABLE IF NOT EXISTS bauth.idn_red_contexto_propagacion (
    id                  UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    servicio_origen     TEXT  NOT NULL,
    servicio_destino    TEXT  NOT NULL,
    formato_propagacion TEXT  NOT NULL DEFAULT 'W3C_TRACEPARENT' CHECK (formato_propagacion IN ('W3C_TRACEPARENT','W3C_BAGGAGE','SBOS_CTX_HEADER','OTEL_BAGGAGE')),
    header_nombre       TEXT  NOT NULL DEFAULT 'X-SBOS-CTX-ID',
    campos_incluidos    TEXT[] NOT NULL DEFAULT ARRAY['tenant_id','user_id','traceparent'],
    cifrar_payload      BOOLEAN NOT NULL DEFAULT false,
    status              TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ircp2_origen_destino UNIQUE (tenant_id, servicio_origen, servicio_destino)
);

-- ===========================================================================
-- D09 — Gaps de Credenciales (T-202, T-363)
-- ===========================================================================

-- T-202: Historial de contraseñas — NIST SP 800-63B-4 §5.1.1.2 · OWASP ASVS 5.0 §2.1.7
-- T-code CORREGIDO: audit doc usó T-360 (tomado por sig_document_hash)
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_password_history (
    id             UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id        UUID  NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id      UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    password_hash  TEXT  NOT NULL CHECK (length(password_hash) > 0),
    hash_algorithm TEXT  NOT NULL DEFAULT 'ARGON2ID',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_icph_user_history ON bauth.idn_credencial_password_history (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_icph_tenant ON bauth.idn_credencial_password_history (tenant_id, user_id);

-- T-363: Registro de tokens emitidos por el motor de credenciales bAuth
-- Complementa fed_token_issued (T-367) con ciclo de vida completo y DPoP binding
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    user_id         UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    jti             TEXT  NOT NULL,
    token_type      TEXT  NOT NULL CHECK (token_type IN ('ACCESS','REFRESH','ID','EXCHANGE','DEVICE')),
    client_id       TEXT  NOT NULL,
    scopes          TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    dpop_jkt        TEXT,                      -- thumbprint JWK si DPoP-bound (RFC 9449)
    dpop_binding_id UUID  REFERENCES bauth.idn_red_dpop_binding(id),
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    revocation_reason TEXT CHECK (revocation_reason IN ('USER_LOGOUT','ADMIN_REVOKE','CREDENTIAL_CHANGE','SESSION_EXPIRED','SUSPICIOUS_ACTIVITY')),
    loa_issued      INTEGER NOT NULL DEFAULT 1 CHECK (loa_issued BETWEEN 1 AND 3),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_icte_expiry CHECK (expires_at > issued_at),
    PRIMARY KEY (id, issued_at)  -- PG18: partition key must be in PK
) PARTITION BY RANGE (issued_at);

CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido_2026_07
    PARTITION OF bauth.idn_credencial_token_emitido
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido_2026_08
    PARTITION OF bauth.idn_credencial_token_emitido
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido_2026_09
    PARTITION OF bauth.idn_credencial_token_emitido
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido_default
    PARTITION OF bauth.idn_credencial_token_emitido DEFAULT;

CREATE INDEX IF NOT EXISTS idx_icte_user_active ON bauth.idn_credencial_token_emitido (user_id, revoked_at, expires_at) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_icte_jti ON bauth.idn_credencial_token_emitido (jti);
CREATE INDEX IF NOT EXISTS idx_icte_dpop ON bauth.idn_credencial_token_emitido (dpop_jkt) WHERE dpop_jkt IS NOT NULL;

-- ===========================================================================
-- D02 — Control de Acceso Físico (T-220..T-228)
-- Orden: T-228 primero (sin deps internas), luego T-220..T-226 en cascada
-- ===========================================================================

-- T-228: Credenciales físicas vinculadas a identidad digital — NIST SP 800-116 R2 §3 · FIPS 201-3
-- (T-227 reservado para expansión futura) — va PRIMERO porque T-223 la referencia
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_credencial (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id         UUID  REFERENCES bauth.idn_user(user_id),
    tipo            TEXT  NOT NULL CHECK (tipo IN ('RFID','SMARTCARD','PIV','BIOMETRICO','PIN','NFC','QR')),
    credencial_id   TEXT  NOT NULL,                -- número de badge / UUID de tarjeta
    facility_code   TEXT,
    emitida_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expira_at       TIMESTAMPTZ,
    revocada_at     TIMESTAMPTZ,
    revocada_por    UUID  REFERENCES bauth.idn_user(user_id),
    motivo_revocacion TEXT,
    instalaciones_permitidas UUID[],               -- array de instalacion_id permitidas
    nivel_acceso    INTEGER NOT NULL DEFAULT 1 CHECK (nivel_acceso BETWEEN 1 AND 5),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iafc_credencial UNIQUE (tenant_id, credencial_id)
);
CREATE INDEX IF NOT EXISTS idx_iafc_entity ON bauth.idn_acceso_fisico_credencial (entity_id, status);
CREATE INDEX IF NOT EXISTS idx_iafc_active ON bauth.idn_acceso_fisico_credencial (tenant_id, status) WHERE status = 'ACTIVE';

-- T-220: Catálogo de instalaciones físicas — ISO 27001 A.7.1 · IEC 60839-11-5
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_instalacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('EDIFICIO','PISO','SALA','DATACENTER','ALMACEN','PERIMETRO','ACCESO_VEHICULAR')),
    direccion       TEXT,
    pais            TEXT  NOT NULL DEFAULT 'BO',
    ciudad          TEXT,
    nivel_seguridad INTEGER NOT NULL DEFAULT 1 CHECK (nivel_seguridad BETWEEN 1 AND 5),
    requiere_escolta BOOLEAN NOT NULL DEFAULT false,
    capacidad_maxima INTEGER CHECK (capacidad_maxima > 0),
    parent_id       UUID  REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE')),
    notas           TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iafi_tenant_nombre UNIQUE (tenant_id, nombre)
);
CREATE INDEX IF NOT EXISTS idx_iafi_tenant ON bauth.idn_acceso_fisico_instalacion (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_iafi_parent ON bauth.idn_acceso_fisico_instalacion (parent_id) WHERE parent_id IS NOT NULL;

-- T-221: Lectores de acceso físico — SIA OSDP v2.2.2 · IEC 60839-11-5 §6
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_lector (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    instalacion_id  UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('RFID','SMARTCARD','BIOMETRICO','PIN','MULTIFACTOR','OSDP')),
    protocolo       TEXT  NOT NULL DEFAULT 'OSDP_V2' CHECK (protocolo IN ('WIEGAND','OSDP_V1','OSDP_V2','OSDP_V2_2')),
    osdp_address    INTEGER CHECK (osdp_address BETWEEN 0 AND 127),
    direccion_fisca TEXT  NOT NULL,   -- ubicación en el edificio
    sentido         TEXT  NOT NULL CHECK (sentido IN ('ENTRADA','SALIDA','BIDIRECCIONAL')),
    online          BOOLEAN NOT NULL DEFAULT true,
    last_heartbeat  TIMESTAMPTZ,
    firmware_version TEXT,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','OFFLINE','MAINTENANCE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iafl_instalacion ON bauth.idn_acceso_fisico_lector (instalacion_id, status);
CREATE INDEX IF NOT EXISTS idx_iafl_offline ON bauth.idn_acceso_fisico_lector (online, last_heartbeat) WHERE online = false;

-- T-222: Estado de presencia actual por actor+instalación — NIST SP 800-116 R2 §4.2
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    instalacion_id  UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    dentro          BOOLEAN NOT NULL DEFAULT false,
    entered_at      TIMESTAMPTZ,
    entered_via     UUID  REFERENCES bauth.idn_acceso_fisico_lector(id),
    ctx_id          TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iafp_entity_instalacion UNIQUE (tenant_id, entity_id, instalacion_id)
);
CREATE INDEX IF NOT EXISTS idx_iafp_dentro ON bauth.idn_acceso_fisico_presencia (instalacion_id, dentro) WHERE dentro = true;

-- T-223: Log de eventos de acceso físico (anti-passback) — IEC 60839-11-1 §6.4
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia_log (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    lector_id       UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_lector(id),
    instalacion_id  UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    evento          TEXT  NOT NULL CHECK (evento IN ('ENTRADA','SALIDA','DENEGADO','ALARMA','FORZADO','ANTIPASSBACK')),
    credencial_tipo TEXT  CHECK (credencial_tipo IN ('RFID','SMARTCARD','BIOMETRICO','PIN','MULTIFACTOR')),
    credencial_ref  UUID  REFERENCES bauth.idn_acceso_fisico_credencial(id) DEFERRABLE INITIALLY DEFERRED,
    outcome         TEXT  NOT NULL CHECK (outcome IN ('GRANTED','DENIED','ALARM','TIMEOUT')),
    denial_reason   TEXT,
    ctx_id          TEXT,
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia_log_2026_07
    PARTITION OF bauth.idn_acceso_fisico_presencia_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia_log_2026_08
    PARTITION OF bauth.idn_acceso_fisico_presencia_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia_log_default
    PARTITION OF bauth.idn_acceso_fisico_presencia_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_iafpl_entity_time ON bauth.idn_acceso_fisico_presencia_log (entity_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_iafpl_lector ON bauth.idn_acceso_fisico_presencia_log (lector_id, logged_at DESC);

-- T-224: Registro de visitas — ISO 27001 A.7.2 · GDPR Art. 5(1)(c)
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_visita (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    instalacion_id  UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    visitante_nombre TEXT NOT NULL,
    visitante_doc   TEXT,
    visitante_empresa TEXT,
    anfitrion_id    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    motivo          TEXT  NOT NULL,
    programada_desde TIMESTAMPTZ NOT NULL,
    programada_hasta TIMESTAMPTZ NOT NULL,
    entrada_real    TIMESTAMPTZ,
    salida_real     TIMESTAMPTZ,
    badge_numero    TEXT,
    escolta_id      UUID  REFERENCES bauth.idn_user(user_id),
    status          TEXT  NOT NULL DEFAULT 'PROGRAMADA' CHECK (status IN ('PROGRAMADA','ACTIVA','COMPLETADA','CANCELADA','NO_PRESENTADA')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_iafv_fechas CHECK (programada_hasta > programada_desde)
);
CREATE INDEX IF NOT EXISTS idx_iafv_anfitrion ON bauth.idn_acceso_fisico_visita (anfitrion_id, programada_desde);
CREATE INDEX IF NOT EXISTS idx_iafv_activas ON bauth.idn_acceso_fisico_visita (status, instalacion_id) WHERE status IN ('PROGRAMADA','ACTIVA');

-- T-225: Acceso de emergencia físico — NIST SP 800-116 R2 §5.4
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_emergencia (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    instalacion_id  UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    tipo            TEXT  NOT NULL CHECK (tipo IN ('INCENDIO','INTRUSION','MEDICA','EVACUACION','FALLA_ENERGIA','OTRO')),
    activado_por    UUID  REFERENCES bauth.idn_user(user_id),
    activado_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    desactivado_at  TIMESTAMPTZ,
    desactivado_por UUID  REFERENCES bauth.idn_user(user_id),
    modo_apertura   TEXT  NOT NULL DEFAULT 'NORMAL' CHECK (modo_apertura IN ('NORMAL','FAIL_SAFE','FAIL_SECURE','MANUAL_OVERRIDE')),
    puertas_afectadas TEXT[],
    incidente_ref   TEXT,
    notas           TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iafe_activas ON bauth.idn_acceso_fisico_emergencia (instalacion_id, desactivado_at) WHERE desactivado_at IS NULL;

-- T-226: Evacuación y mustering — ISO 27001 A.7.4 · NFPA 101:2021 §7.7
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_evacuacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    emergencia_id   UUID  NOT NULL REFERENCES bauth.idn_acceso_fisico_emergencia(id),
    punto_reunion   TEXT  NOT NULL,
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    confirmado      BOOLEAN NOT NULL DEFAULT false,
    confirmado_at   TIMESTAMPTZ,
    confirmado_por  UUID  REFERENCES bauth.idn_user(user_id),
    ultima_ubicacion_id UUID REFERENCES bauth.idn_acceso_fisico_instalacion(id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iafev_emergencia ON bauth.idn_acceso_fisico_evacuacion (emergencia_id, confirmado);

-- ===========================================================================
-- D03 — Control Financiero (T-240..T-248)
-- ===========================================================================

-- T-240: Límites transaccionales por rol/actor — PCI DSS 4.0 Req 8.2 · NIST AC-2(6)
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_limite (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    scope           TEXT  NOT NULL CHECK (scope IN ('ROLE','USER','ENTITY','CLIENT')),
    scope_ref       UUID  NOT NULL,
    operacion       TEXT  NOT NULL CHECK (operacion IN ('PAGO','TRANSFERENCIA','APROBACION','EMISION','CONTABILIDAD','GENERAL')),
    moneda          TEXT  NOT NULL DEFAULT 'BOB',
    limite_monto    NUMERIC(20,4) NOT NULL CHECK (limite_monto > 0),
    limite_diario   NUMERIC(20,4) CHECK (limite_diario > 0),
    limite_mensual  NUMERIC(20,4) CHECK (limite_mensual > 0),
    requiere_aprobacion_dual BOOLEAN NOT NULL DEFAULT false,
    umbral_aprobacion_dual   NUMERIC(20,4),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    vigente_desde   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    vigente_hasta   TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifl_scope ON bauth.idn_financiero_limite (tenant_id, scope, scope_ref, status);

-- T-241: Solicitud de aprobación dual financiera — COSO 2013 CC6.3 · SOX §302
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_aprobacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    solicitante_id  UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    operacion_tipo  TEXT  NOT NULL CHECK (operacion_tipo IN ('PAGO','TRANSFERENCIA','APROBACION','EMISION','CONTABILIDAD')),
    monto           NUMERIC(20,4) NOT NULL CHECK (monto > 0),
    moneda          TEXT  NOT NULL DEFAULT 'BOB',
    descripcion     TEXT  NOT NULL CHECK (length(descripcion) >= 10),
    referencia_externa TEXT,
    status          TEXT  NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED')),
    quorum_requerido INTEGER NOT NULL DEFAULT 2 CHECK (quorum_requerido >= 2),
    quorum_alcanzado INTEGER NOT NULL DEFAULT 0,
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifa_pending ON bauth.idn_financiero_aprobacion (tenant_id, status, expires_at) WHERE status = 'PENDING';

-- T-248 (= voto individual de aprobación dual) — desglosado del T-241 por claridad DDL
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_aprobacion_voto (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    aprobacion_id   UUID  NOT NULL REFERENCES bauth.idn_financiero_aprobacion(id),
    aprobador_id    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    decision        TEXT  NOT NULL CHECK (decision IN ('APPROVE','REJECT','ABSTAIN')),
    motivo          TEXT,
    ctx_id          TEXT,
    voted_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ifav_aprobacion_aprobador UNIQUE (aprobacion_id, aprobador_id)
);
CREATE INDEX IF NOT EXISTS idx_ifav_aprobacion ON bauth.idn_financiero_aprobacion_voto (aprobacion_id, decision);

-- T-242: Reglas SoD financiero — NIST AC-5 · SOX §404 · COSO CC6.3
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_sod_regla (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    operacion_a     TEXT  NOT NULL,
    operacion_b     TEXT  NOT NULL,
    tipo_conflicto  TEXT  NOT NULL CHECK (tipo_conflicto IN ('MUTUALLY_EXCLUSIVE','REQUIRES_APPROVAL','SEQUENTIAL_ONLY')),
    descripcion     TEXT  NOT NULL,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifsr_tenant ON bauth.idn_financiero_sod_regla (tenant_id, status);

-- T-243: Autorización de factura electrónica SIN — SIN RND 102100000011 · Ley 164 Bolivia
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_factura_autorizacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    solicitante_id  UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    nit_emisor      TEXT  NOT NULL,
    nit_receptor    TEXT,
    numero_factura  TEXT  NOT NULL,
    monto_total     NUMERIC(20,4) NOT NULL,
    moneda          TEXT  NOT NULL DEFAULT 'BOB',
    fecha_emision   DATE  NOT NULL,
    cuf             TEXT,                  -- Código Único de Factura SIN
    cufd            TEXT,                  -- Código Único de Facturación Diaria
    firma_digital_ref UUID,                -- FK a sig_operation_log
    estado_sin      TEXT  NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_sin IN ('PENDIENTE','AUTORIZADA','RECHAZADA','ANULADA','CONTINGENCIA')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iffa_nit ON bauth.idn_financiero_factura_autorizacion (nit_emisor, fecha_emision);
CREATE INDEX IF NOT EXISTS idx_iffa_estado ON bauth.idn_financiero_factura_autorizacion (tenant_id, estado_sin);

-- T-244: Reportes financieros de control — SOX §302/§404 · IFRS 7
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_reporte (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT  NOT NULL CHECK (tipo IN ('SOX_302','SOX_404','PCI_DSS','TRIMESTRAL','ANUAL','INCIDENTE','AUDITORIA')),
    periodo_desde   DATE  NOT NULL,
    periodo_hasta   DATE  NOT NULL,
    generado_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    aprobado_por    UUID  REFERENCES bauth.idn_user(user_id),
    archivo_ref     TEXT,
    hash_sha256     TEXT,
    status          TEXT  NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','PUBLISHED','ARCHIVED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- T-245: Alertas de fraude financiero — PCI DSS 4.0 Req 10.7 · ISO 37001 §8.6
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_alerta_fraude (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo_alerta     TEXT  NOT NULL CHECK (tipo_alerta IN ('MONTO_INUSUAL','PATRON_HORARIO','UBICACION_ANOMALA','SoD_VIOLATION','MULTIPLE_RECHAZOS','VELOCITY_CHECK')),
    severity        TEXT  NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    descripcion     TEXT  NOT NULL,
    monto_referencia NUMERIC(20,4),
    investigado     BOOLEAN NOT NULL DEFAULT false,
    resultado       TEXT  CHECK (resultado IN ('FRAUDE_CONFIRMADO','FALSO_POSITIVO','PENDIENTE','ESCALADO')),
    investigador_id UUID  REFERENCES bauth.idn_user(user_id),
    ctx_id          TEXT,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ifaf_unresolved ON bauth.idn_financiero_alerta_fraude (tenant_id, investigado, severity) WHERE investigado = false;

-- T-246: Conciliación financiera — ISO 20022 §5 · COSO 2013 CC6.6
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_conciliacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    periodo         DATE  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('DIARIA','MENSUAL','TRIMESTRAL','ANUAL')),
    sistema_origen  TEXT  NOT NULL,
    sistema_destino TEXT  NOT NULL,
    registros_origen INTEGER NOT NULL,
    registros_destino INTEGER NOT NULL,
    diferencias     INTEGER NOT NULL DEFAULT 0,
    monto_diferencia NUMERIC(20,4) NOT NULL DEFAULT 0,
    status          TEXT  NOT NULL DEFAULT 'PENDIENTE' CHECK (status IN ('PENDIENTE','EN_PROCESO','COMPLETADA','CON_DIFERENCIAS','APROBADA')),
    ejecutado_por   UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifc_tenant_periodo ON bauth.idn_financiero_conciliacion (tenant_id, periodo);

-- T-247: Consentimiento TPP / Open Banking — FAPI 2.0 · RFC 9449 DPoP · PSD2 Art. 98
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_tpp_consentimiento (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tpp_client_id   TEXT  NOT NULL,
    tpp_nombre      TEXT  NOT NULL,
    scopes_otorgados TEXT[] NOT NULL,
    monto_limite    NUMERIC(20,4),
    valido_desde    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valido_hasta    TIMESTAMPTZ NOT NULL,
    revocado_at     TIMESTAMPTZ,
    revocado_por    TEXT  CHECK (revocado_por IN ('USUARIO','ADMIN','TPP','REGULADOR','EXPIRADO')),
    dpop_required   BOOLEAN NOT NULL DEFAULT true,
    fapi_profile    TEXT  NOT NULL DEFAULT 'FAPI_2_0' CHECK (fapi_profile IN ('FAPI_1_0','FAPI_2_0')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_iftc_vigencia CHECK (valido_hasta > valido_desde)
);
CREATE INDEX IF NOT EXISTS idx_iftc_entity_active ON bauth.idn_financiero_tpp_consentimiento (entity_id, revocado_at) WHERE revocado_at IS NULL;

-- ===========================================================================
-- D04 — Control Temporal GTRBAC (T-260..T-265)
-- ===========================================================================

-- T-260: Ventanas de tiempo de acceso — GTRBAC §3.2 · NIST AC-3(7)
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_ventana (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('HORARIO','DIARIO','SEMANAL','MENSUAL','CUSTOM')),
    hora_inicio     TIME  NOT NULL,
    hora_fin        TIME  NOT NULL,
    dias_semana     INTEGER[] CHECK (array_length(dias_semana, 1) > 0),  -- 1=lun..7=dom
    zona_horaria    TEXT  NOT NULL DEFAULT 'America/La_Paz',
    activo          BOOLEAN NOT NULL DEFAULT true,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_itv_tenant_nombre UNIQUE (tenant_id, nombre),
    CONSTRAINT chk_itv_horario CHECK (hora_fin > hora_inicio)
);

-- T-261: Períodos temporales con constraints PG18 — GTRBAC §4 · ISO 8601:2019
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_periodo (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ventana_id      UUID  NOT NULL REFERENCES bauth.idn_temporal_ventana(id),
    valido_desde    TIMESTAMPTZ NOT NULL,
    valido_hasta    TIMESTAMPTZ NOT NULL,
    rol_id          TEXT  NOT NULL,
    activacion_automatica BOOLEAN NOT NULL DEFAULT true,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_itp_periodo CHECK (valido_hasta > valido_desde)
);
CREATE INDEX IF NOT EXISTS idx_itp_entity_active ON bauth.idn_temporal_periodo (entity_id, valido_desde, valido_hasta);
CREATE INDEX IF NOT EXISTS idx_itp_vigente ON bauth.idn_temporal_periodo (tenant_id, valido_hasta);

-- T-262: Asociación de calendarios a ventanas (FK a bcalendar, sin duplicar datos)
-- Nota H-01: usa FK a bcalendar.cal_calendar en vez de duplicar datos
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_calendario (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    ventana_id      UUID  NOT NULL REFERENCES bauth.idn_temporal_ventana(id),
    calendar_id     UUID  NOT NULL REFERENCES bcalendar.cal_calendar(calendar_id),
    excluye_feriados BOOLEAN NOT NULL DEFAULT true,
    excluye_fines_semana BOOLEAN NOT NULL DEFAULT false,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_itc_ventana_calendar UNIQUE (ventana_id, calendar_id)
);

-- T-263: Turnos de trabajo — NIST AC-2(2) · GTRBAC §5
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_turno (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    ventana_id      UUID  NOT NULL REFERENCES bauth.idn_temporal_ventana(id),
    tipo_rotacion   TEXT  NOT NULL DEFAULT 'FIJO' CHECK (tipo_rotacion IN ('FIJO','ROTATIVO','FLEXIBLE','GUARDIA')),
    duracion_horas  NUMERIC(4,1) NOT NULL CHECK (duracion_horas BETWEEN 1 AND 24),
    activo          BOOLEAN NOT NULL DEFAULT true,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_itt_tenant_nombre UNIQUE (tenant_id, nombre)
);

-- T-264: Asignación de turno a actor
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_turno_asignacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    turno_id        UUID  NOT NULL REFERENCES bauth.idn_temporal_turno(id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id         UUID  REFERENCES bauth.idn_user(user_id),
    valido_desde    TIMESTAMPTZ NOT NULL,
    valido_hasta    TIMESTAMPTZ,
    asignado_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_itta_entity ON bauth.idn_temporal_turno_asignacion (entity_id, valido_desde);

-- T-265: Excepciones temporales — NIST AC-17(1) · ISO 27001 A.5.18
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_excepcion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo            TEXT  NOT NULL CHECK (tipo IN ('EXTENSION','REDUCCION','BLOQUEO','GUARDIA_ADICIONAL')),
    motivo          TEXT  NOT NULL CHECK (length(motivo) >= 20),
    ventana_original UUID NOT NULL REFERENCES bauth.idn_temporal_ventana(id),
    valido_desde    TIMESTAMPTZ NOT NULL,
    valido_hasta    TIMESTAMPTZ NOT NULL,
    aprobado_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ite_vigencia CHECK (valido_hasta > valido_desde)
);

-- ===========================================================================
-- D05 — Control Biométrico (T-280..T-285)
-- ===========================================================================

-- T-280: Enrolamiento biométrico — NIST SP 800-76-2 §4 · ISO/IEC 30107-1:2023
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_enrolamiento (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id         UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    modalidad       TEXT  NOT NULL CHECK (modalidad IN ('HUELLA','IRIS','ROSTRO','VOZ','RETINA','PALMA','VENA')),
    calidad_muestra NUMERIC(5,2) NOT NULL CHECK (calidad_muestra BETWEEN 0 AND 100),
    algoritmo       TEXT  NOT NULL,
    vault_template_path TEXT NOT NULL,         -- ruta en Vault — NUNCA el template en BD
    ial_alcanzado   INTEGER NOT NULL DEFAULT 2 CHECK (ial_alcanzado BETWEEN 2 AND 3),
    liveness_check  BOOLEAN NOT NULL DEFAULT true,
    liveness_score  NUMERIC(5,2) CHECK (liveness_score BETWEEN 0 AND 100),
    enrolado_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    revocado_at     TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibe_entity_modalidad ON bauth.idn_biometrico_enrolamiento (entity_id, modalidad, status);

-- T-281: Log de verificaciones biométricas — particionada por mes
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    enrolamiento_id UUID  NOT NULL REFERENCES bauth.idn_biometrico_enrolamiento(id),
    modalidad       TEXT  NOT NULL,
    outcome         TEXT  NOT NULL CHECK (outcome IN ('MATCH','NO_MATCH','LIVENESS_FAIL','QUALITY_FAIL','ERROR','TIMEOUT')),
    score_match     NUMERIC(5,2),
    score_liveness  NUMERIC(5,2),
    loa_alcanzado   INTEGER CHECK (loa_alcanzado BETWEEN 1 AND 3),
    ip_hash         TEXT,
    device_id       UUID,
    ctx_id          TEXT,
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, verified_at)
) PARTITION BY RANGE (verified_at);

CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log_2026_07
    PARTITION OF bauth.idn_biometrico_verificacion_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log_2026_08
    PARTITION OF bauth.idn_biometrico_verificacion_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log_default
    PARTITION OF bauth.idn_biometrico_verificacion_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_ibvl_enrolamiento ON bauth.idn_biometrico_verificacion_log (enrolamiento_id, verified_at DESC);

-- T-282: Política PAD (Presentation Attack Detection) — ISO/IEC 30107-3:2023 §5 · FIDO2 §8.8
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_pad_policy (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    modalidad       TEXT  NOT NULL CHECK (modalidad IN ('HUELLA','IRIS','ROSTRO','VOZ','RETINA','PALMA','VENA')),
    nivel_pad       TEXT  NOT NULL DEFAULT 'LEVEL_2' CHECK (nivel_pad IN ('LEVEL_1','LEVEL_2','LEVEL_3')),
    umbral_liveness NUMERIC(5,2) NOT NULL DEFAULT 80.0 CHECK (umbral_liveness BETWEEN 0 AND 100),
    algoritmo_pad   TEXT  NOT NULL,
    bloqueo_intentos_pad INTEGER NOT NULL DEFAULT 3,
    accion_falla    TEXT  NOT NULL DEFAULT 'DENY' CHECK (accion_falla IN ('DENY','STEP_UP','LOG_AND_ALLOW','QUARANTINE')),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibpp_tenant_modalidad UNIQUE (tenant_id, modalidad)
);

-- T-283: Log de identificación 1:N — ISO/IEC 19794-2:2011 §6
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_identificacion_log (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    modalidad       TEXT  NOT NULL,
    candidatos      INTEGER NOT NULL,
    mejor_score     NUMERIC(5,2),
    resultado       TEXT  NOT NULL CHECK (resultado IN ('IDENTIFICADO','NO_IDENTIFICADO','MULTIPLE_MATCH','ERROR')),
    entity_id_match UUID  REFERENCES bauth.idn_identity_entity(entity_id),
    threshold_usado NUMERIC(5,2) NOT NULL,
    ctx_id          TEXT,
    searched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, searched_at)
) PARTITION BY RANGE (searched_at);

CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_identificacion_log_default
    PARTITION OF bauth.idn_biometrico_identificacion_log DEFAULT;

-- T-284: Política de calidad de muestra — ISO/IEC 29794-1:2024 §5 · NIST SP 800-76-2 §3
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_calidad_policy (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    modalidad       TEXT  NOT NULL CHECK (modalidad IN ('HUELLA','IRIS','ROSTRO','VOZ','RETINA','PALMA','VENA')),
    calidad_minima  NUMERIC(5,2) NOT NULL DEFAULT 70.0 CHECK (calidad_minima BETWEEN 0 AND 100),
    intentos_maximos INTEGER NOT NULL DEFAULT 3,
    reintentar_con_liveness BOOLEAN NOT NULL DEFAULT true,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibcp_tenant_modalidad UNIQUE (tenant_id, modalidad)
);

-- T-285: Revocación de template biométrico — ISO/IEC 24745:2022 §6 · NIST SP 800-76-2 §6
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_revocacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    enrolamiento_id UUID  NOT NULL REFERENCES bauth.idn_biometrico_enrolamiento(id),
    motivo          TEXT  NOT NULL CHECK (motivo IN ('COMPROMISO','SOLICITUD_USUARIO','ADMIN','EXPIRACION','CALIDAD_DEGRADADA','INCIDENTE')),
    revocado_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    vault_wipe_confirmed BOOLEAN NOT NULL DEFAULT false,  -- confirmación de borrado del vault
    vault_wipe_at   TIMESTAMPTZ,
    reemplazo_id    UUID  REFERENCES bauth.idn_biometrico_enrolamiento(id),
    ctx_id          TEXT,
    revocado_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibr_enrolamiento ON bauth.idn_biometrico_revocacion (enrolamiento_id);

-- ===========================================================================
-- D06 — Control Geoespacial (T-300..T-305)
-- ===========================================================================

-- T-300: Geocercas — RFC 7946 §3.1 · OGC GeoSPARQL 1.1
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_geocerca (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('CIRCULO','POLIGONO','PAIS','REGION','CIUDAD')),
    -- Para tipo CIRCULO: lat_centro, lon_centro, radio_km
    lat_centro      NUMERIC(10,7),
    lon_centro      NUMERIC(10,7),
    radio_km        NUMERIC(8,3) CHECK (radio_km > 0),
    -- Para tipo POLIGONO/PAIS/REGION: GeoJSON
    geojson         JSONB,
    -- Acción cuando un actor está FUERA
    accion_fuera    TEXT  NOT NULL DEFAULT 'DENY' CHECK (accion_fuera IN ('DENY','STEP_UP','LOG','NOTIFY')),
    -- Acción cuando un actor está DENTRO
    accion_dentro   TEXT  NOT NULL DEFAULT 'ALLOW' CHECK (accion_dentro IN ('ALLOW','STEP_UP','LOG','NOTIFY')),
    pais_iso        TEXT,                  -- ISO 3166-1 alpha-2
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igg_tenant_nombre UNIQUE (tenant_id, nombre)
);
CREATE INDEX IF NOT EXISTS idx_igg_tenant_active ON bauth.idn_geoespacial_geocerca (tenant_id, status);

-- T-301: Log de ubicaciones — RFC 7946 §3 · NIST AC-3(11) · GDPR Art. 5(1)(c)
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    latitud         NUMERIC(10,7) NOT NULL,
    longitud        NUMERIC(10,7) NOT NULL,
    precision_metros NUMERIC(8,2),
    fuente          TEXT  NOT NULL CHECK (fuente IN ('GPS','WIFI','IP_GEOIP','CELL','MANUAL','BEACON')),
    geocerca_id     UUID  REFERENCES bauth.idn_geoespacial_geocerca(id),
    dentro_geocerca BOOLEAN,
    ip_hash         TEXT,                  -- GDPR: IP anonimizada
    session_id      UUID,
    ctx_id          TEXT,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, captured_at)
) PARTITION BY RANGE (captured_at);

CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log_2026_07
    PARTITION OF bauth.idn_geoespacial_ubicacion_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log_2026_08
    PARTITION OF bauth.idn_geoespacial_ubicacion_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log_default
    PARTITION OF bauth.idn_geoespacial_ubicacion_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_igul_entity ON bauth.idn_geoespacial_ubicacion_log (entity_id, captured_at DESC);

-- T-302: Política de velocidad geográfica (viaje imposible) — NIST SI-4(13)
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_velocidad_policy (
    id                  UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    velocidad_max_kmh   NUMERIC(8,2) NOT NULL DEFAULT 900.0 CHECK (velocidad_max_kmh > 0),
    ventana_analisis_min INTEGER NOT NULL DEFAULT 60,
    accion              TEXT  NOT NULL DEFAULT 'STEP_UP' CHECK (accion IN ('DENY','STEP_UP','NOTIFY','LOG')),
    severity            TEXT  NOT NULL DEFAULT 'HIGH' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    status              TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igvp_tenant UNIQUE (tenant_id)
);

-- T-303: Eventos de viaje imposible detectados
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_velocidad_evento (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ubicacion_a_id  UUID  NOT NULL,  -- ref: idn_geoespacial_ubicacion_log.id (FK no viable en partitioned)
    ubicacion_b_id  UUID  NOT NULL,  -- ref: idn_geoespacial_ubicacion_log.id (FK no viable en partitioned)
    velocidad_calculada_kmh NUMERIC(10,2) NOT NULL,
    distancia_km    NUMERIC(10,2) NOT NULL,
    tiempo_minutos  NUMERIC(10,2) NOT NULL,
    accion_tomada   TEXT  NOT NULL,
    investigado     BOOLEAN NOT NULL DEFAULT false,
    ctx_id          TEXT,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_igve_unresolved ON bauth.idn_geoespacial_velocidad_evento (tenant_id, investigado, detected_at DESC) WHERE investigado = false;

-- T-304: Residencia de datos y soberanía geográfica — GDPR Art. 44-49 · Ley 1174 Bolivia
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_residencia (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    paises_permitidos TEXT[] NOT NULL,      -- ISO 3166-1 alpha-2
    paises_bloqueados TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    aplicar_a       TEXT  NOT NULL DEFAULT 'ALL' CHECK (aplicar_a IN ('ALL','DATA_RESIDENCY','AUTH_ONLY','STORAGE')),
    accion_violacion TEXT  NOT NULL DEFAULT 'DENY' CHECK (accion_violacion IN ('DENY','LOG','NOTIFY','QUARANTINE')),
    requiere_vpn_soberana BOOLEAN NOT NULL DEFAULT false,
    exentos         UUID[],                 -- entity_ids exentos de la política
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igr_tenant UNIQUE (tenant_id)
);

-- T-305: Flota de dispositivos móviles con trazabilidad geoespacial — ISO 6709:2022
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_dispositivo_flota (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    device_id       UUID  NOT NULL REFERENCES bauth.auth_device(device_id),
    nombre_flota    TEXT  NOT NULL,
    geocerca_asignada UUID REFERENCES bauth.idn_geoespacial_geocerca(id),
    dentro_geocerca BOOLEAN NOT NULL DEFAULT false,
    ultima_lat      NUMERIC(10,7),
    ultima_lon      NUMERIC(10,7),
    ultima_ubicacion_at TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igdf_device UNIQUE (device_id)
);

-- ===========================================================================
-- D10 — Delegación de Identidad (T-415..T-420)
-- T-codes CORREGIDOS: audit doc usó T-380..T-385 (tomados por BILLETERA+AUTH)
-- ===========================================================================

-- T-415: Delegación de identidad base — RFC 8693 §3 · NIST AC-2(5)
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_identidad (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    delegante_id    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),    -- quien delega
    delegado_id     UUID  NOT NULL REFERENCES bauth.idn_user(user_id),    -- quien recibe
    proposito       TEXT  NOT NULL CHECK (length(proposito) >= 20),
    tipo            TEXT  NOT NULL DEFAULT 'IMPERSONATION' CHECK (tipo IN ('IMPERSONATION','AGENT','PROXY','TOKEN_EXCHANGE')),
    scopes          TEXT[] NOT NULL,
    monto_limite    NUMERIC(20,4),
    valido_desde    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valido_hasta    TIMESTAMPTZ NOT NULL,
    max_renovaciones INTEGER NOT NULL DEFAULT 0,
    renovaciones_usadas INTEGER NOT NULL DEFAULT 0,
    revocado_at     TIMESTAMPTZ,
    revocado_por    UUID  REFERENCES bauth.idn_user(user_id),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_idi_vigencia CHECK (valido_hasta > valido_desde),
    CONSTRAINT chk_idi_auto_delegacion CHECK (delegante_id <> delegado_id)
);
CREATE INDEX IF NOT EXISTS idx_idi_delegado ON bauth.idn_delegacion_identidad (delegado_id, status, valido_hasta);
CREATE INDEX IF NOT EXISTS idx_idi_delegante ON bauth.idn_delegacion_identidad (delegante_id, status);

-- T-416: Renovación de delegación — RFC 8693 §4.2
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_renovacion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    delegacion_id   UUID  NOT NULL REFERENCES bauth.idn_delegacion_identidad(id),
    renovada_por    UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    nueva_hasta     TIMESTAMPTZ NOT NULL,
    motivo          TEXT,
    ctx_id          TEXT,
    renovada_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idr_delegacion ON bauth.idn_delegacion_renovacion (delegacion_id, renovada_at DESC);

-- T-417: Restricciones sobre el scope delegado — NIST AC-5 · ISO 27001 A.5.3
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_restriccion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    delegacion_id   UUID  NOT NULL REFERENCES bauth.idn_delegacion_identidad(id),
    tipo_restriccion TEXT NOT NULL CHECK (tipo_restriccion IN ('SCOPE_LIMIT','IP_WHITELIST','HOURS_ONLY','RESOURCE_LIMIT','APPROVAL_REQUIRED')),
    parametros      JSONB NOT NULL DEFAULT '{}'::jsonb,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idrestr_delegacion ON bauth.idn_delegacion_restriccion (delegacion_id);

-- T-418: Cadena de delegación (delegated→sub-delegated) — RFC 8693 §2 · ANSI INCITS 359-2004 §4.5
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_cadena (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    delegacion_raiz UUID  NOT NULL REFERENCES bauth.idn_delegacion_identidad(id),
    delegacion_id   UUID  NOT NULL REFERENCES bauth.idn_delegacion_identidad(id),
    profundidad     INTEGER NOT NULL DEFAULT 1 CHECK (profundidad BETWEEN 1 AND 5),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_idc_chain UNIQUE (delegacion_raiz, delegacion_id)
);

-- T-419: Log de uso de delegaciones — particionada · ISO 27001 A.8.15 · NIST AU-2
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    delegacion_id   UUID  NOT NULL REFERENCES bauth.idn_delegacion_identidad(id),
    accion          TEXT  NOT NULL,
    recurso         TEXT,
    outcome         TEXT  NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR')),
    ip_hash         TEXT,
    ctx_id          TEXT,
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log_2026_07
    PARTITION OF bauth.idn_delegacion_uso_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log_2026_08
    PARTITION OF bauth.idn_delegacion_uso_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log_default
    PARTITION OF bauth.idn_delegacion_uso_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_idul_delegacion ON bauth.idn_delegacion_uso_log (delegacion_id, logged_at DESC);

-- T-420: Rich Authorization Request — RFC 9396 §3 · OAuth 2.0
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_rar_request (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    delegacion_id   UUID  REFERENCES bauth.idn_delegacion_identidad(id),
    client_id       TEXT  NOT NULL,
    authorization_details JSONB NOT NULL,   -- RFC 9396 §2: array de objetos tipados
    status          TEXT  NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED')),
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '10 minutes',
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idrr_client ON bauth.idn_delegacion_rar_request (client_id, status, expires_at);

-- ===========================================================================
-- D11 — Gaps de Auditoría y SIEM (T-421..T-424)
-- T-codes CORREGIDOS: audit doc usó T-400..T-403 (tomados por CONTEXT PLANE+BOS)
-- ===========================================================================

-- T-421: Política de retención de logs — SOX §802 · GDPR Art. 5(1)(e) · NIST AU-11
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_retencion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = política global
    tipo_evento     TEXT  NOT NULL,         -- auth, privilege, financial, biometric, ALL
    retencion_dias  INTEGER NOT NULL CHECK (retencion_dias > 0),
    retencion_legal_dias INTEGER,           -- SOX §802 = 2555 días (7 años)
    base_legal      TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    accion_expiracion TEXT NOT NULL DEFAULT 'ARCHIVE' CHECK (accion_expiracion IN ('DELETE','ARCHIVE','ANONYMIZE','KEEP')),
    archivo_destino TEXT,
    activo          BOOLEAN NOT NULL DEFAULT true,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iar_tenant_tipo UNIQUE (tenant_id, tipo_evento)
);
CREATE INDEX IF NOT EXISTS idx_iar_active ON bauth.idn_auditoria_retencion (activo, tipo_evento) WHERE activo = true;

-- T-422: Reglas de alerta de auditoría — NIST AU-6 · ISO 27001 A.8.16
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_regla_alerta (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    descripcion     TEXT  NOT NULL,
    condicion       JSONB NOT NULL,         -- {event_type, threshold, window_minutes, ...}
    severity        TEXT  NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    canales_notif   TEXT[] NOT NULL DEFAULT ARRAY['SIEM'],
    umbral_falsos_positivos INTEGER DEFAULT 0,
    activa          BOOLEAN NOT NULL DEFAULT true,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iara_tenant_nombre UNIQUE (tenant_id, nombre)
);

-- T-423: Destinos SIEM — NIST AU-9(2) · ISO 27001 A.8.15 (Wazuh por defecto)
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_siem_destino (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('SYSLOG_UDP','SYSLOG_TCP','SYSLOG_TLS','HTTP_WEBHOOK','KAFKA','ELASTIC')),
    endpoint        TEXT  NOT NULL,
    puerto          INTEGER CHECK (puerto BETWEEN 1 AND 65535),
    tls_enabled     BOOLEAN NOT NULL DEFAULT false,
    formato         TEXT  NOT NULL DEFAULT 'CEF' CHECK (formato IN ('CEF','LEEF','JSON','SYSLOG_RFC5424','WAZUH')),
    filtro_eventos  TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],  -- vacío = todos
    activo          BOOLEAN NOT NULL DEFAULT true,
    ultimo_envio    TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iasd_tenant_nombre UNIQUE (tenant_id, nombre)
);

-- T-424: Evento de auditoría unificado multi-dominio — particionado por mes
-- ISO 27001 A.8.15 · GDPR Art. 5(1)(f) · NIST AU-2
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento (
    id              UUID  DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    dominio         TEXT  NOT NULL CHECK (dominio IN ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','D10','D11','D12','D13','D14','D15','D98','D99')),
    tipo_evento     TEXT  NOT NULL,
    subject_id      UUID,
    subject_type    TEXT  CHECK (subject_type IN ('USER','ENTITY','NHI','SYSTEM')),
    action          TEXT  NOT NULL,
    resource        TEXT,
    outcome         TEXT  NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR','PARTIAL')),
    ip_hash         TEXT,
    ctx_id          TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    hash_anterior   TEXT,
    hash_actual     TEXT,  -- SHA-256 calculado por trigger: tenant+dominio+tipo+action+outcome+ctx+prev_hash
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento_2026_07
    PARTITION OF bauth.idn_auditoria_evento
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento_2026_08
    PARTITION OF bauth.idn_auditoria_evento
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento_2026_09
    PARTITION OF bauth.idn_auditoria_evento
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento_default
    PARTITION OF bauth.idn_auditoria_evento DEFAULT;

CREATE INDEX IF NOT EXISTS idx_iae_dominio ON bauth.idn_auditoria_evento (dominio, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_iae_subject ON bauth.idn_auditoria_evento (subject_id, logged_at DESC) WHERE subject_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iae_outcome ON bauth.idn_auditoria_evento (outcome, logged_at DESC) WHERE outcome = 'DENY';

-- ===========================================================================
-- D12 — Blockchain extra (T-425..T-429)
-- T-codes CORREGIDOS: audit doc usó T-420..T-424 (solapaban con D10)
-- Las 5 tablas blk_* existentes cubren ancla/merkle; estas son el motor completo
-- ===========================================================================

-- T-425: Extensión de anclaje blockchain (complementa blk_anchor T-358)
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_anclaje (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    blk_anchor_id   UUID  NOT NULL REFERENCES bauth.blk_anchor(anchor_id),
    tipo_evento_origen TEXT NOT NULL CHECK (tipo_evento_origen IN ('PRIVILEGE_GRANT','AUDIT_BATCH','FIRMA_DIGITAL','VC_ISSUED','SoD_VIOLATION')),
    evento_origen_id UUID NOT NULL,
    merkle_proof    TEXT[],                -- prueba de inclusión
    verificacion_externa_url TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iba_origen ON bauth.idn_blockchain_anclaje (tipo_evento_origen, evento_origen_id);

-- T-426: Registro de transacciones Besu QBFT — Hyperledger Besu §6
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_transaccion (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    account_id      UUID  NOT NULL REFERENCES bauth.blk_account(account_id),
    tx_hash         TEXT  NOT NULL UNIQUE,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('SETTLE','FREEZE','UNFREEZE','REVERT','DEPLOY','CALL')),
    from_address    TEXT  NOT NULL,
    to_address      TEXT,
    valor_wei       NUMERIC(30,0),
    gas_used        BIGINT,
    status          TEXT  NOT NULL CHECK (status IN ('PENDING','CONFIRMED','FAILED','REVERTED')),
    block_number    BIGINT,
    confirmed_at    TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibt_account ON bauth.idn_blockchain_transaccion (account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ibt_status ON bauth.idn_blockchain_transaccion (status) WHERE status = 'PENDING';

-- T-427: Wallet blockchain por tenant — BIP-32/39/44 · EIP-712
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_wallet (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id) UNIQUE,
    chain           TEXT  NOT NULL DEFAULT 'BESU_QBFT' CHECK (chain IN ('BESU_QBFT','ARBITRUM')),
    address         TEXT  NOT NULL UNIQUE,
    vault_key_path  TEXT  NOT NULL,        -- clave privada en Vault — NUNCA en BD
    hd_path         TEXT,                  -- BIP-44 derivation path
    balance_wei     NUMERIC(30,0) NOT NULL DEFAULT 0,
    balance_updated_at TIMESTAMPTZ,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','DECOMMISSIONED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- T-428: Pruebas de inclusión Merkle — RFC 6962 §2.1.1 · NIST SP 800-208 §3
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_merkle_proof (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    batch_id        UUID  NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id),
    leaf_hash       TEXT  NOT NULL,
    proof_path      TEXT[] NOT NULL,       -- sibling hashes
    proof_directions INTEGER[] NOT NULL,   -- 0=left, 1=right
    root_hash       TEXT  NOT NULL,
    verificado      BOOLEAN NOT NULL DEFAULT false,
    verificado_at   TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibmp_batch_leaf UNIQUE (batch_id, leaf_hash)
);

-- T-429: Nodos del consenso Besu QBFT — Hyperledger Besu §4 · EIP-225
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_nodo (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    enode_url       TEXT  NOT NULL UNIQUE,
    address         TEXT  NOT NULL UNIQUE,
    es_validador    BOOLEAN NOT NULL DEFAULT false,
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SYNCING','OFFLINE','DECOMMISSIONED')),
    ultimo_bloque   BIGINT,
    peers_count     INTEGER,
    last_heartbeat  TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===========================================================================
-- D13 — Firma Digital (gaps, T-440..T-446)
-- ===========================================================================

-- T-440: Solicitud de firma digital — PAdES EN 319 132 · Ley 164 Bolivia Art. 9
CREATE TABLE IF NOT EXISTS bauth.idn_firma_solicitud (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    solicitante_id  UUID  NOT NULL REFERENCES bauth.idn_user(user_id),
    tipo_documento  TEXT  NOT NULL CHECK (tipo_documento IN ('PDF','XML','JSON','FACTURA_SIN','VC','JWT','CONTRATO')),
    formato_firma   TEXT  NOT NULL DEFAULT 'PADES_B' CHECK (formato_firma IN ('PADES_B','PADES_T','PADES_LT','PADES_LTA','CADES_B','XADES_B','JADES')),
    motor           TEXT  NOT NULL CHECK (motor IN ('INTERNAL_ED25519','EXTERNAL_ADSIB','DUAL')),
    documento_hash  TEXT  NOT NULL,        -- SHA-256 del documento
    vault_key_path  TEXT,                  -- ruta en Vault para motor interno
    cert_id         UUID  REFERENCES bauth.sig_certificate(cert_id),
    status          TEXT  NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SIGNING','SIGNED','FAILED','CANCELLED')),
    requiere_timestamp BOOLEAN NOT NULL DEFAULT false,
    requiere_lts    BOOLEAN NOT NULL DEFAULT false,
    operacion_id    UUID  REFERENCES bauth.sig_operation_log(operation_id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifs_pending ON bauth.idn_firma_solicitud (tenant_id, status, created_at) WHERE status IN ('PENDING','SIGNING');

-- T-441: Cadena de certificación CA — RFC 5280 §6 · ADSIB-FD-POLT-015 v2.3
CREATE TABLE IF NOT EXISTS bauth.idn_firma_cadena_ca (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = global
    nombre          TEXT  NOT NULL,
    tipo            TEXT  NOT NULL CHECK (tipo IN ('ROOT_CA','INTERMEDIATE_CA','ISSUING_CA','ADSIB','VAULT_PKI')),
    subject_dn      TEXT  NOT NULL,
    issuer_dn       TEXT  NOT NULL,
    fingerprint_sha256 TEXT NOT NULL UNIQUE,
    not_before      TIMESTAMPTZ NOT NULL,
    not_after       TIMESTAMPTZ NOT NULL,
    cert_pem_vault  TEXT  NOT NULL,        -- ruta Vault — NUNCA el PEM en BD
    ocsp_url        TEXT,
    crl_url         TEXT,
    es_confiable    BOOLEAN NOT NULL DEFAULT true,
    parent_id       UUID  REFERENCES bauth.idn_firma_cadena_ca(id),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifcc_fingerprint ON bauth.idn_firma_cadena_ca (fingerprint_sha256);
CREATE INDEX IF NOT EXISTS idx_ifcc_active ON bauth.idn_firma_cadena_ca (es_confiable, not_after) WHERE es_confiable = true;

-- T-442: Timestamp calificado de firma — RFC 3161 §2 · Ley 164 Bolivia Art. 20
CREATE TABLE IF NOT EXISTS bauth.idn_firma_timestamp (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    solicitud_id    UUID  NOT NULL REFERENCES bauth.idn_firma_solicitud(id),
    tsa_url         TEXT  NOT NULL,
    tsa_nombre      TEXT  NOT NULL,
    token_base64    TEXT  NOT NULL,        -- RFC 3161 TSTInfo
    serial_number   TEXT  NOT NULL,
    hash_algoritmo  TEXT  NOT NULL DEFAULT 'SHA-256',
    message_imprint TEXT  NOT NULL,        -- hash del documento al momento del TS
    gen_time        TIMESTAMPTZ NOT NULL,
    accuracy_micros INTEGER,
    nonce           TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ift_solicitud ON bauth.idn_firma_timestamp (solicitud_id);

-- T-443: Log de verificaciones de firma — ETSI EN 319 102-1 §5 · RFC 5280
CREATE TABLE IF NOT EXISTS bauth.idn_firma_verificacion_log (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    verificador_id  UUID  REFERENCES bauth.idn_user(user_id),
    documento_hash  TEXT  NOT NULL,
    tipo_firma      TEXT  NOT NULL,
    outcome         TEXT  NOT NULL CHECK (outcome IN ('VALID','INVALID','EXPIRED','REVOKED','UNKNOWN','ERROR')),
    cert_status     TEXT  CHECK (cert_status IN ('VALID','REVOKED','EXPIRED','UNKNOWN')),
    chain_valid     BOOLEAN,
    timestamp_valid BOOLEAN,
    ltv_valid       BOOLEAN,
    detalle         JSONB NOT NULL DEFAULT '{}'::jsonb,
    ctx_id          TEXT,
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifvl_outcome ON bauth.idn_firma_verificacion_log (outcome, verified_at DESC) WHERE outcome != 'VALID';

-- T-444: Cache de estado de revocación OCSP/CRL — RFC 6960 OCSP · RFC 5280 §5
CREATE TABLE IF NOT EXISTS bauth.idn_firma_revocacion_cache (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    cert_fingerprint TEXT NOT NULL UNIQUE,
    issuer_fingerprint TEXT NOT NULL,
    status          TEXT  NOT NULL CHECK (status IN ('GOOD','REVOKED','UNKNOWN')),
    this_update     TIMESTAMPTZ NOT NULL,
    next_update     TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    revocation_reason TEXT,
    fuente          TEXT  NOT NULL CHECK (fuente IN ('OCSP','CRL','VAULT','MANUAL')),
    ctx_id          TEXT,
    cached_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifrc_expiry ON bauth.idn_firma_revocacion_cache (next_update) WHERE status = 'GOOD';

-- T-445: Evidencia LTV (Long-Term Validation) — ETSI EN 319 102-2 §5.6 · RFC 3161 §3
CREATE TABLE IF NOT EXISTS bauth.idn_firma_ltv_evidencia (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    solicitud_id    UUID  NOT NULL REFERENCES bauth.idn_firma_solicitud(id),
    timestamp_id    UUID  NOT NULL REFERENCES bauth.idn_firma_timestamp(id),
    certificados_chain TEXT[] NOT NULL,     -- fingerprints SHA-256 de la cadena al momento
    ocsp_responses  JSONB NOT NULL DEFAULT '[]'::jsonb,
    crls_hash       TEXT[],
    archivado_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valido_hasta    TIMESTAMPTZ,           -- estimado de cuándo debe re-archivarse
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifle_solicitud ON bauth.idn_firma_ltv_evidencia (solicitud_id);

-- T-446: Integración EUDI Wallet — UE 2024/1183 eIDAS 2.0 · ARF 1.4
CREATE TABLE IF NOT EXISTS bauth.idn_firma_eudi_wallet (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID  NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    wallet_provider TEXT  NOT NULL,
    wallet_did      TEXT,
    pid_credential_id TEXT,               -- Personal ID credential del EUDI
    status          TEXT  NOT NULL DEFAULT 'LINKED' CHECK (status IN ('LINKED','SUSPENDED','REVOKED','PENDING')),
    linked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ifew_entity UNIQUE (entity_id, wallet_provider)
);

-- ===========================================================================
-- D14 — PAM: Referencia de grabación de sesiones (T-461)
-- ===========================================================================

-- T-461: Referencia trazable a grabaciones de sesiones privilegiadas — NIST AU-14
CREATE TABLE IF NOT EXISTS bauth.pam_grabacion_ref (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    session_record_id UUID NOT NULL REFERENCES bauth.pam_session_record(id),
    archivo_nombre  TEXT  NOT NULL,
    archivo_hash_sha256 TEXT NOT NULL,
    storage_tipo    TEXT  NOT NULL DEFAULT 'MINIO' CHECK (storage_tipo IN ('MINIO','S3','LOCAL','NFS')),
    storage_bucket  TEXT  NOT NULL,
    storage_path    TEXT  NOT NULL,
    tamano_bytes    BIGINT,
    duracion_segundos INTEGER,
    cifrado         BOOLEAN NOT NULL DEFAULT true,
    vault_key_path  TEXT,                  -- clave de cifrado en Vault
    retencion_hasta DATE  NOT NULL,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pgr_session ON bauth.pam_grabacion_ref (session_record_id);
CREATE INDEX IF NOT EXISTS idx_pgr_retencion ON bauth.pam_grabacion_ref (retencion_hasta);

-- ===========================================================================
-- D15 — NHI: Gaps (T-480..T-481)
-- ===========================================================================

-- T-480: Política de rotación de secretos NHI — NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §4.4
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_rotacion_policy (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_nhi        TEXT  NOT NULL CHECK (tipo_nhi IN ('SERVICE_ACCOUNT','CI_CD','DAEMON','BOT','AGENT_IA','API_KEY')),
    rotacion_dias   INTEGER NOT NULL CHECK (rotacion_dias BETWEEN 1 AND 365),
    rotacion_en_uso BOOLEAN NOT NULL DEFAULT false,  -- ON_USE pattern para CI/CD
    pre_aviso_dias  INTEGER NOT NULL DEFAULT 7,
    auto_rotar      BOOLEAN NOT NULL DEFAULT true,
    accion_si_falla TEXT  NOT NULL DEFAULT 'NOTIFY' CHECK (accion_si_falla IN ('NOTIFY','SUSPEND_NHI','ALERT_ADMIN')),
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_inrp_tenant_tipo UNIQUE (tenant_id, tipo_nhi)
);

-- T-481: SPIFFE SVID para daemons SBOS — SPIFFE Spec v1.0 §8 · NIST SP 800-204A §4
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_svid (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID  REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = sistema
    nhi_id          UUID  NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    spiffe_id       TEXT  NOT NULL,            -- spiffe://trust-domain/path
    svid_type       TEXT  NOT NULL DEFAULT 'X509' CHECK (svid_type IN ('X509','JWT')),
    trust_domain    TEXT  NOT NULL,
    cert_fingerprint TEXT,
    serial_number   TEXT,
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    rotated_at      TIMESTAMPTZ,
    vault_path      TEXT  NOT NULL,            -- cert SVID en Vault — NUNCA en BD
    status          TEXT  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ROTATED','REVOKED','EXPIRED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ins_nhi_domain UNIQUE (nhi_id, spiffe_id),
    CONSTRAINT chk_ins_expiry CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS idx_ins_active ON bauth.idn_nhi_svid (trust_domain, status, expires_at) WHERE status = 'ACTIVE';

-- ===========================================================================
-- D98 — Meta-Registro (T-500..T-502)
-- ===========================================================================

-- T-500: Schema registry de atributos EAV — SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5
CREATE TABLE IF NOT EXISTS bauth.idn_registro_atributo_schema (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    attr_key        TEXT  NOT NULL UNIQUE,  -- clave canónica: 'nit_bo', 'telefono_movil'
    category        TEXT  NOT NULL CHECK (category IN ('IDENTITY','CONTACT','LEGAL','BIOMETRIC','FINANCIAL','SYSTEM','CUSTOM')),
    data_type       TEXT  NOT NULL CHECK (data_type IN ('TEXT','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','JSON','BINARY','UUID')),
    mutability      TEXT  NOT NULL DEFAULT 'READ_WRITE' CHECK (mutability IN ('READ_ONLY','READ_WRITE','WRITE_ONCE')),
    returned        TEXT  NOT NULL DEFAULT 'DEFAULT' CHECK (returned IN ('ALWAYS','DEFAULT','NEVER','REQUEST')),
    required        BOOLEAN NOT NULL DEFAULT false,
    multi_valued    BOOLEAN NOT NULL DEFAULT false,
    min_ial         INTEGER NOT NULL DEFAULT 1 CHECK (min_ial BETWEEN 1 AND 3),
    source          TEXT  NOT NULL DEFAULT 'USER' CHECK (source IN ('USER','SYSTEM','PROOFING','IMPORT','DERIVED')),
    classification  TEXT  NOT NULL DEFAULT 'INTERNAL' CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','SECRET')),
    mask_display    BOOLEAN NOT NULL DEFAULT false,
    retention_days  INTEGER CHECK (retention_days > 0),
    validation_regex TEXT,
    descripcion     TEXT  NOT NULL,
    activo          BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iras_category ON bauth.idn_registro_atributo_schema (category, activo);

-- T-501: Catálogo de átomos del motor BitMask — NIST SP 800-162 §4.2
-- Auto-poblado por trigger en idn_roles_template (H-06)
CREATE TABLE IF NOT EXISTS bauth.idn_registro_atomo_catalogo (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    atom_code       TEXT  NOT NULL UNIQUE,
    template_id     UUID  NOT NULL REFERENCES bauth.idn_roles_template(id),
    dominio         TEXT  NOT NULL CHECK (dominio IN ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','D10','D11','D12','D13','D14','D15','D98','D99')),
    bit_position    INTEGER,               -- posición en el BitMask
    descripcion     TEXT  NOT NULL,
    implementado    BOOLEAN NOT NULL DEFAULT false,
    deprecado_at    TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_irac_dominio ON bauth.idn_registro_atomo_catalogo (dominio, implementado);
CREATE INDEX IF NOT EXISTS idx_irac_bit ON bauth.idn_registro_atomo_catalogo (bit_position) WHERE bit_position IS NOT NULL;

-- T-502: Versiones del árbol BitMask — ISO 9001:2015 §7.5 · ISO/IEC 24760-2:2025
-- Job diario toma snapshot del árbol para auditoria forense
CREATE TABLE IF NOT EXISTS bauth.idn_registro_arbol_version (
    id              UUID  DEFAULT gen_random_uuid() PRIMARY KEY,
    version_tag     TEXT  NOT NULL,
    snapshot_hash   TEXT  NOT NULL,        -- SHA-256 del estado completo del árbol
    total_atomos    INTEGER NOT NULL,
    atomos_activos  INTEGER NOT NULL,
    dominio_counts  JSONB NOT NULL DEFAULT '{}'::jsonb,
    generado_por    TEXT  NOT NULL DEFAULT 'JOB_DIARIO',
    ctx_id          TEXT,
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irav_version UNIQUE (version_tag)
);
CREATE INDEX IF NOT EXISTS idx_irav_generated ON bauth.idn_registro_arbol_version (generated_at DESC);

-- ===========================================================================
-- WORM enforcement (REVOKE UPDATE/DELETE)
-- Tablas append-only por norma ISO 27001 A.8.15
-- ===========================================================================

DO $$
DECLARE
    r TEXT;
    worm_tables TEXT[] := ARRAY[
        'idn_red_dpop_binding',          -- T-196: bindings de un solo uso
        'idn_credencial_password_history', -- T-202: historial inmutable
        'idn_acceso_fisico_evacuacion',  -- T-226: evidencia forense
        'idn_delegacion_uso_log',        -- T-419: log de uso
        'idn_auditoria_evento',          -- T-424: log multi-dominio
        'idn_blockchain_anclaje',        -- T-425: anclas Blockchain
        'idn_firma_verificacion_log',    -- T-443: verificaciones
        'idn_firma_ltv_evidencia'        -- T-445: evidencia LTV
    ];
BEGIN
    FOREACH r IN ARRAY worm_tables LOOP
        BEGIN
            EXECUTE format('REVOKE UPDATE, DELETE ON bauth.%I FROM bauth_app_role', r);
        EXCEPTION WHEN undefined_object THEN
            NULL;  -- rol no existe aún
        END;
    END LOOP;
END $$;

-- ===========================================================================
-- SEEDS CRÍTICOS
-- ===========================================================================

-- T-513: Algoritmos criptográficos (NIST SP 800-131A R2 + PQC FIPS 203/204/205)
INSERT INTO bauth.idn_global_crypto_params
    (algorithm_name, algorithm_family, key_size_bits, is_pqc, is_approved, is_deprecated, is_prohibited, fips_standard, nist_standard, use_cases, notes)
VALUES
    -- Algoritmos aprobados activos
    ('Ed25519',      'SIGNATURE', 256, false, true, false, false, 'FIPS 186-5', 'SP 800-186',     ARRAY['JWT','SIGNING'], 'Motor interno bAuth'),
    ('ECDSA-P256',   'SIGNATURE', 256, false, true, false, false, 'FIPS 186-5', 'SP 800-186',     ARRAY['TLS','JWT'],     'TLS 1.3'),
    ('ECDSA-P384',   'SIGNATURE', 384, false, true, false, false, 'FIPS 186-5', 'SP 800-186',     ARRAY['TLS','JWT'],     'TLS 1.3 alto nivel'),
    ('RSA-SHA256',   'SIGNATURE', 2048, false, true, false, false, NULL,        'SP 800-131A R2', ARRAY['ADSIB','TLS'],   'Motor externo ADSIB'),
    ('RSA-SHA256-4096','SIGNATURE',4096,false, true, false, false, NULL,        'SP 800-131A R2', ARRAY['ADSIB'],         'ADSIB alta seguridad'),
    ('AES-256-GCM',  'SYMMETRIC', 256, false, true, false, false, 'FIPS 197',  'SP 800-38D',     ARRAY['STORAGE','VAULT'],'Cifrado en reposo'),
    ('ARGON2ID',     'KDF',       NULL, false, true, false, false, NULL,        'SP 800-63B-4',   ARRAY['PASSWORDS'],     'Hash contraseñas m=64MB t=3 p=4'),
    ('PBKDF2-SHA512','KDF',       NULL, false, true, false, false, 'FIPS 198-1','SP 800-132',     ARRAY['PASSWORDS'],     'Alternativa ARGON2ID'),
    ('SHA-256',      'HASH',      256, false, true, false, false, 'FIPS 180-4', 'SP 800-107',     ARRAY['HASH','TLS'],    'Hash documentos y tokens'),
    ('SHA-384',      'HASH',      384, false, true, false, false, 'FIPS 180-4', 'SP 800-107',     ARRAY['HASH','TLS'],    'Hash alto nivel'),
    ('ChaCha20-Poly1305','SYMMETRIC',256,false,true, false, false, NULL,        'RFC 8439',       ARRAY['TLS'],           'TLS 1.3 suite alternativa'),
    -- PQC — NIST finalizado agosto 2024
    ('ML-KEM-768',   'KEM',       NULL, true, true, false, false, 'FIPS 203',  'SP 800-227',     ARRAY['TLS','KEM'],     'PQC: Module-Lattice KEM. Antiguo: Kyber-768'),
    ('ML-KEM-1024',  'KEM',       NULL, true, true, false, false, 'FIPS 203',  'SP 800-227',     ARRAY['KEM'],           'PQC: ML-KEM nivel más alto'),
    ('ML-DSA-44',    'SIGNATURE', NULL, true, true, false, false, 'FIPS 204',  'SP 800-227',     ARRAY['SIGNING'],       'PQC: Module-Lattice DSA. Antiguo: Dilithium2'),
    ('ML-DSA-65',    'SIGNATURE', NULL, true, true, false, false, 'FIPS 204',  'SP 800-227',     ARRAY['SIGNING'],       'PQC: ML-DSA nivel medio'),
    ('SLH-DSA-SHA2-128s','SIGNATURE',NULL,true,true, false, false, 'FIPS 205', 'SP 800-227',     ARRAY['SIGNING'],       'PQC: Stateless Hash-Based. Antiguo: SPHINCS+'),
    -- Deprecados (usar solo en sistemas legacy)
    ('RSA-SHA1',     'SIGNATURE', 2048, false, false, true, false, NULL,        'SP 800-131A R2', ARRAY[]::TEXT[],        'DEPRECADO: SHA-1 débil — deadline migración 2025'),
    -- Prohibidos (NIST SP 800-131A R2)
    ('MD5',          'HASH',      128, false, false, false, true,  NULL,        'SP 800-131A R2', ARRAY[]::TEXT[],        'PROHIBIDO: colisiones conocidas'),
    ('SHA-1',        'HASH',      160, false, false, false, true,  NULL,        'SP 800-131A R2', ARRAY[]::TEXT[],        'PROHIBIDO: colisiones prácticas (SHAttered 2017)'),
    ('DES',          'SYMMETRIC', 56,  false, false, false, true,  NULL,        'SP 800-131A R2', ARRAY[]::TEXT[],        'PROHIBIDO: longitud clave insuficiente'),
    ('3DES',         'SYMMETRIC', 168, false, false, false, true,  NULL,        'SP 800-131A R2', ARRAY[]::TEXT[],        'PROHIBIDO: SWEET32 attack (2016), retirado 2023'),
    ('RC4',          'SYMMETRIC', NULL, false, false, false, true,  NULL,       'SP 800-131A R2', ARRAY[]::TEXT[],        'PROHIBIDO: vulnerabilidades estructurales')
ON CONFLICT (algorithm_name) DO NOTHING;

-- T-510: Super-admin del sistema BAUTH_SYSTEM (si existe la entidad base)
-- Nota: requiere que exista idn_identity_entity con nombre 'BAUTH_SYSTEM' e idn_user correspondiente
-- Este seed se ejecuta solo si existen los registros base
DO $$
DECLARE
    v_entity_id UUID;
    v_user_id   UUID;
BEGIN
    SELECT entity_id INTO v_entity_id FROM bauth.idn_identity_entity
    WHERE code = 'BAUTH_SYSTEM' LIMIT 1;

    IF v_entity_id IS NOT NULL THEN
        SELECT user_id INTO v_user_id FROM bauth.idn_user
        WHERE entity_id = v_entity_id LIMIT 1;

        IF v_user_id IS NOT NULL THEN
            INSERT INTO bauth.idn_global_admin
                (entity_id, user_id, admin_role, can_manage_tenants, can_manage_crypto, can_read_audit_all)
            VALUES
                (v_entity_id, v_user_id, 'SUPER_ADMIN', true, true, true)
            ON CONFLICT (user_id) DO NOTHING;
        END IF;
    END IF;
END $$;

-- T-421: Políticas de retención base (GDPR + SOX)
INSERT INTO bauth.idn_auditoria_retencion
    (tenant_id, tipo_evento, retencion_dias, retencion_legal_dias, base_legal, accion_expiracion)
VALUES
    (NULL, 'AUTH',        365,  NULL, ARRAY['GDPR Art. 5(1)(e)','ISO 27001 A.8.15'], 'ARCHIVE'),
    (NULL, 'PRIVILEGE',   2555, 2555, ARRAY['SOX §802','GDPR Art. 5(1)(e)'],        'ARCHIVE'),
    (NULL, 'FINANCIAL',   2555, 2555, ARRAY['SOX §802','PCI DSS 4.0 Req 10.7'],    'ARCHIVE'),
    (NULL, 'BIOMETRIC',   365,  NULL, ARRAY['GDPR Art. 5(1)(e)','ISO/IEC 24745:2022'],'DELETE'),
    (NULL, 'GEOSPATIAL',  180,  NULL, ARRAY['GDPR Art. 5(1)(c)','Ley 1174 Bolivia'],'ANONYMIZE'),
    (NULL, 'AUDIT',       365,  NULL, ARRAY['ISO 27001 A.8.15','NIST AU-11'],       'ARCHIVE'),
    (NULL, 'ALL',         365,  NULL, ARRAY['ISO 27001 A.8.15'],                    'ARCHIVE')
ON CONFLICT (tenant_id, tipo_evento) DO NOTHING;

-- T-423: Destino SIEM Wazuh por defecto
INSERT INTO bauth.idn_auditoria_siem_destino
    (tenant_id, nombre, tipo, endpoint, puerto, formato, filtro_eventos)
VALUES
    (NULL, 'Wazuh-SBOS', 'SYSLOG_UDP', '127.0.0.1', 514, 'WAZUH', ARRAY[]::TEXT[])
ON CONFLICT (tenant_id, nombre) DO NOTHING;

-- ===========================================================================
-- FIN
-- ===========================================================================
