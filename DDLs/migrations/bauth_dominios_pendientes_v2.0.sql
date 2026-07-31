-- =============================================================================
-- bAuth Dominios Pendientes v2.0
-- Reescritura completa con nombres de tablas y columnas en inglés.
-- Los comentarios SQL y la documentación permanecen en español.
-- Regla: tabla/columna/CHECK values = inglés · comentarios = español
--
-- T-codes (sin cambios vs v1.0):
--   D99 Admin Global    → T-510..T-515
--   D07 Red/ZTA         → T-195..T-201
--   D09 Credenciales    → T-202, T-363
--   D02 Acceso Físico   → T-220..T-228
--   D03 Financiero      → T-240..T-248
--   D04 Temporal        → T-260..T-265
--   D05 Biométrico      → T-280..T-285
--   D06 Geoespacial     → T-300..T-305
--   D10 Delegación      → T-415..T-420
--   D11 Auditoría       → T-421..T-424
--   D12 Blockchain ext  → T-425..T-429
--   D13 Firma Digital   → T-440..T-446
--   D14 PAM gap         → T-461
--   D15 NHI gaps        → T-480..T-481
--   D98 Meta-Registro   → T-500..T-502
-- Idempotente: sección DROP + CREATE TABLE IF NOT EXISTS
-- =============================================================================

SET search_path = bauth, public;

-- ===========================================================================
-- SECCIÓN 1: DROP — elimina las tablas v1.0 (nombres en español)
-- CASCADE elimina particiones e índices automáticamente
-- Orden inverso a dependencias (hijas primero)
-- ===========================================================================

-- D98 Meta-Registro (sin dependencias externas, sí son referenciadas)
DROP TABLE IF EXISTS bauth.idn_registro_arbol_version    CASCADE;
DROP TABLE IF EXISTS bauth.idn_registro_atomo_catalogo   CASCADE;
DROP TABLE IF EXISTS bauth.idn_registro_atributo_schema  CASCADE;

-- D15 NHI
DROP TABLE IF EXISTS bauth.idn_nhi_rotacion_policy       CASCADE;
-- idn_nhi_svid: columna nhi_id y spiffe_id ya en inglés → DROP+recrear igualmente
DROP TABLE IF EXISTS bauth.idn_nhi_svid                  CASCADE;

-- D14 PAM
DROP TABLE IF EXISTS bauth.pam_grabacion_ref             CASCADE;

-- D13 Firma Digital (hijas primero)
DROP TABLE IF EXISTS bauth.idn_firma_eudi_wallet         CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_ltv_evidencia       CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_revocacion_cache    CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_verificacion_log    CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_timestamp           CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_cadena_ca           CASCADE;
DROP TABLE IF EXISTS bauth.idn_firma_solicitud           CASCADE;

-- D12 Blockchain extra
DROP TABLE IF EXISTS bauth.idn_blockchain_nodo           CASCADE;
DROP TABLE IF EXISTS bauth.idn_blockchain_merkle_proof   CASCADE;
DROP TABLE IF EXISTS bauth.idn_blockchain_wallet         CASCADE;
DROP TABLE IF EXISTS bauth.idn_blockchain_transaccion    CASCADE;
DROP TABLE IF EXISTS bauth.idn_blockchain_anclaje        CASCADE;

-- D11 Auditoría (particionada — CASCADE elimina particiones)
DROP TABLE IF EXISTS bauth.idn_auditoria_evento          CASCADE;
DROP TABLE IF EXISTS bauth.idn_auditoria_siem_destino    CASCADE;
DROP TABLE IF EXISTS bauth.idn_auditoria_regla_alerta    CASCADE;
DROP TABLE IF EXISTS bauth.idn_auditoria_retencion       CASCADE;

-- D10 Delegación (particionada idn_delegacion_uso_log)
DROP TABLE IF EXISTS bauth.idn_delegacion_rar_request    CASCADE;
DROP TABLE IF EXISTS bauth.idn_delegacion_uso_log        CASCADE;
DROP TABLE IF EXISTS bauth.idn_delegacion_cadena         CASCADE;
DROP TABLE IF EXISTS bauth.idn_delegacion_restriccion    CASCADE;
DROP TABLE IF EXISTS bauth.idn_delegacion_renovacion     CASCADE;
DROP TABLE IF EXISTS bauth.idn_delegacion_identidad      CASCADE;

-- D06 Geoespacial (particionada idn_geoespacial_ubicacion_log)
DROP TABLE IF EXISTS bauth.idn_geoespacial_dispositivo_flota CASCADE;
DROP TABLE IF EXISTS bauth.idn_geoespacial_residencia        CASCADE;
DROP TABLE IF EXISTS bauth.idn_geoespacial_velocidad_evento  CASCADE;
DROP TABLE IF EXISTS bauth.idn_geoespacial_velocidad_policy  CASCADE;
DROP TABLE IF EXISTS bauth.idn_geoespacial_ubicacion_log     CASCADE;
DROP TABLE IF EXISTS bauth.idn_geoespacial_geocerca          CASCADE;

-- D05 Biométrico (particionadas)
DROP TABLE IF EXISTS bauth.idn_biometrico_revocacion          CASCADE;
DROP TABLE IF EXISTS bauth.idn_biometrico_calidad_policy      CASCADE;
DROP TABLE IF EXISTS bauth.idn_biometrico_identificacion_log  CASCADE;
DROP TABLE IF EXISTS bauth.idn_biometrico_pad_policy          CASCADE;
DROP TABLE IF EXISTS bauth.idn_biometrico_verificacion_log    CASCADE;
DROP TABLE IF EXISTS bauth.idn_biometrico_enrolamiento        CASCADE;

-- D04 Temporal
DROP TABLE IF EXISTS bauth.idn_temporal_excepcion         CASCADE;
DROP TABLE IF EXISTS bauth.idn_temporal_turno_asignacion  CASCADE;
DROP TABLE IF EXISTS bauth.idn_temporal_turno             CASCADE;
DROP TABLE IF EXISTS bauth.idn_temporal_calendario        CASCADE;
DROP TABLE IF EXISTS bauth.idn_temporal_periodo           CASCADE;
DROP TABLE IF EXISTS bauth.idn_temporal_ventana           CASCADE;

-- D03 Financiero
DROP TABLE IF EXISTS bauth.idn_financiero_tpp_consentimiento   CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_conciliacion         CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_alerta_fraude        CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_reporte              CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_factura_autorizacion CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_sod_regla            CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_aprobacion_voto      CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_aprobacion           CASCADE;
DROP TABLE IF EXISTS bauth.idn_financiero_limite               CASCADE;

-- D02 Acceso Físico (particionada idn_acceso_fisico_presencia_log)
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_evacuacion     CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_emergencia     CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_visita         CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_presencia_log  CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_presencia      CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_lector         CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_instalacion    CASCADE;
DROP TABLE IF EXISTS bauth.idn_acceso_fisico_credencial     CASCADE;

-- D09 Credenciales (particionada idn_credencial_token_emitido)
DROP TABLE IF EXISTS bauth.idn_credencial_token_emitido     CASCADE;
-- idn_credencial_password_history: columnas ya en inglés → DROP+recrear
DROP TABLE IF EXISTS bauth.idn_credencial_password_history  CASCADE;

-- D07 Red/ZTA
DROP TABLE IF EXISTS bauth.idn_red_contexto_propagacion  CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_dlp_policy            CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_segmento              CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_postura_policy        CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_rate_policy           CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_dpop_binding          CASCADE;
DROP TABLE IF EXISTS bauth.idn_red_conexion_policy       CASCADE;

-- D99 Admin Global (con columnas en español)
DROP TABLE IF EXISTS bauth.idn_global_hitl_excepcion     CASCADE;
DROP TABLE IF EXISTS bauth.idn_global_notificacion       CASCADE;
-- idn_global_admin, idn_global_crypto_params, idn_global_compliance_control, idn_global_sbom
-- ya tienen columnas en inglés → DROP+recrear para mantener consistencia de script
DROP TABLE IF EXISTS bauth.idn_global_sbom               CASCADE;
DROP TABLE IF EXISTS bauth.idn_global_compliance_control CASCADE;
DROP TABLE IF EXISTS bauth.idn_global_admin              CASCADE;
DROP TABLE IF EXISTS bauth.idn_global_crypto_params      CASCADE;

-- ===========================================================================
-- SECCIÓN 2: D99 — Admin Global Soberano (T-510..T-515)
-- Prerequisito de otras tablas que referencian admin_id
-- ===========================================================================

-- T-510: Administradores globales del sistema
CREATE TABLE IF NOT EXISTS bauth.idn_global_admin (
    id                    UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_id             UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id               UUID        NOT NULL REFERENCES bauth.idn_user(user_id),
    admin_role            TEXT        NOT NULL CHECK (admin_role IN ('SUPER_ADMIN','SECURITY_ADMIN','AUDIT_ADMIN','SUPPORT_ADMIN')),
    can_manage_tenants    BOOLEAN     NOT NULL DEFAULT false,
    can_manage_crypto     BOOLEAN     NOT NULL DEFAULT false,
    can_read_audit_all    BOOLEAN     NOT NULL DEFAULT false,
    required_aal          INTEGER     NOT NULL DEFAULT 3 CHECK (required_aal = 3),
    status                TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),
    activated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_auth_at          TIMESTAMPTZ,
    deactivated_at        TIMESTAMPTZ,
    deactivated_by        UUID        REFERENCES bauth.idn_user(user_id),
    reason                TEXT,
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iga_user UNIQUE (user_id)
);
CREATE INDEX IF NOT EXISTS idx_iga_status ON bauth.idn_global_admin (status);

-- T-513: Catálogo de parámetros criptográficos (NIST SP 800-131A R2 + PQC FIPS 203/204/205)
CREATE TABLE IF NOT EXISTS bauth.idn_global_crypto_params (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    algorithm_name        TEXT    NOT NULL UNIQUE,
    algorithm_family      TEXT    NOT NULL CHECK (algorithm_family IN ('SYMMETRIC','ASYMMETRIC','HASH','KDF','KEM','SIGNATURE','MAC')),
    key_size_bits         INTEGER,
    is_pqc                BOOLEAN NOT NULL DEFAULT false,
    is_approved           BOOLEAN NOT NULL DEFAULT true,
    is_deprecated         BOOLEAN NOT NULL DEFAULT false,
    is_prohibited         BOOLEAN NOT NULL DEFAULT false,
    fips_standard         TEXT,
    nist_standard         TEXT,
    migration_deadline    DATE,
    replacement_algorithm TEXT,
    use_cases             TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_igcp_not_both CHECK (NOT (is_approved AND is_prohibited))
);
CREATE INDEX IF NOT EXISTS idx_igcp_approved   ON bauth.idn_global_crypto_params (is_approved, algorithm_family);
CREATE INDEX IF NOT EXISTS idx_igcp_pqc        ON bauth.idn_global_crypto_params (is_pqc)        WHERE is_pqc = true;
CREATE INDEX IF NOT EXISTS idx_igcp_prohibited ON bauth.idn_global_crypto_params (is_prohibited) WHERE is_prohibited = true;

-- T-511: Notificaciones globales del sistema
CREATE TABLE IF NOT EXISTS bauth.idn_global_notification (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_type TEXT   NOT NULL CHECK (notification_type IN ('SECURITY_ALERT','CRYPTO_EXPIRY','CERT_EXPIRY','COMPLIANCE_WARNING','MAINTENANCE','INCIDENT','POLICY_CHANGE','CAPACITY_ALERT')),
    severity         TEXT    NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),
    title            TEXT    NOT NULL,
    message          TEXT    NOT NULL,
    target_scope     TEXT    NOT NULL DEFAULT 'ALL' CHECK (target_scope IN ('ALL','TENANT','ADMIN')),
    target_tenant_id UUID    REFERENCES bauth.idn_tenant(tenant_id),
    target_admin_id  UUID    REFERENCES bauth.idn_global_admin(id),
    is_read          BOOLEAN NOT NULL DEFAULT false,
    read_at          TIMESTAMPTZ,
    expires_at       TIMESTAMPTZ,
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ign_unread ON bauth.idn_global_notification (is_read, severity, created_at DESC) WHERE is_read = false;

-- T-512: Excepciones HITL (Human-In-The-Loop) — NIST AI RMF 1.0 §3.6
CREATE TABLE IF NOT EXISTS bauth.idn_global_hitl_exception (
    id                       UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    exception_type           TEXT    NOT NULL CHECK (exception_type IN ('PROHIBITED_ALGO','POLICY_OVERRIDE','EMERGENCY_ACCESS','CRYPTO_DOWNGRADE','COMPLIANCE_BREACH','AI_DECISION_REVIEWED')),
    description              TEXT    NOT NULL CHECK (length(description) >= 50),
    business_justification   TEXT    NOT NULL CHECK (length(business_justification) >= 100),
    requester_id             UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    approver_id              UUID    REFERENCES bauth.idn_global_admin(id),
    status                   TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED','REVOKED')),
    approved_at              TIMESTAMPTZ,
    valid_from               TIMESTAMPTZ,
    valid_until              TIMESTAMPTZ NOT NULL,
    review_at                TIMESTAMPTZ,  -- calculado por app: valid_until - 7 días
    affected_entity_type     TEXT    NOT NULL CHECK (affected_entity_type IN ('ALGORITHM','POLICY','TENANT','USER','ROLE','CERT')),
    affected_entity_ref      TEXT    NOT NULL,
    ctx_id                   TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ighe_pending ON bauth.idn_global_hitl_exception (status, review_at) WHERE status = 'APPROVED';

-- T-514: Mapa de controles de cumplimiento normativo global
CREATE TABLE IF NOT EXISTS bauth.idn_global_compliance_control (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    standard_name     TEXT    NOT NULL,
    control_id        TEXT    NOT NULL,
    control_title     TEXT    NOT NULL,
    control_desc      TEXT    NOT NULL,
    status            TEXT    NOT NULL DEFAULT 'IMPLEMENTED' CHECK (status IN ('IMPLEMENTED','PARTIAL','PLANNED','NOT_APPLICABLE','GAP')),
    evidence_type     TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    evidence_location TEXT,
    last_reviewed_at  TIMESTAMPTZ,
    next_review_at    TIMESTAMPTZ,
    owner_admin_id    UUID    REFERENCES bauth.idn_global_admin(id),
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igcc_standard_ctrl UNIQUE (standard_name, control_id)
);
CREATE INDEX IF NOT EXISTS idx_igcc_status ON bauth.idn_global_compliance_control (status, standard_name);

-- T-515: SBOM — Software Bill of Materials (NTIA SBOM 2021 · EU Cyber Resilience Act)
CREATE TABLE IF NOT EXISTS bauth.idn_global_sbom (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    component_name  TEXT    NOT NULL,
    component_type  TEXT    NOT NULL CHECK (component_type IN ('LIBRARY','FRAMEWORK','DAEMON','TOOL','OS_PACKAGE','CONTAINER')),
    version         TEXT    NOT NULL,
    language        TEXT,
    license         TEXT,
    package_url     TEXT,
    cve_known       TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    risk_level      TEXT    NOT NULL DEFAULT 'LOW' CHECK (risk_level IN ('CRITICAL','HIGH','MEDIUM','LOW','NONE')),
    last_scanned_at TIMESTAMPTZ,
    is_direct_dep   BOOLEAN NOT NULL DEFAULT true,
    daemon_name     TEXT    NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igs_comp_ver_daemon UNIQUE (component_name, version, daemon_name)
);
CREATE INDEX IF NOT EXISTS idx_igs_risk ON bauth.idn_global_sbom (risk_level, daemon_name) WHERE risk_level IN ('CRITICAL','HIGH');

-- ===========================================================================
-- SECCIÓN 3: D07 — Control de Red / ZTA (T-195..T-201)
-- ===========================================================================

-- T-195: Política de conexión (TLS, mTLS, DPoP, PKCE) — RFC 8705 · NIST SP 800-52 R2
CREATE TABLE IF NOT EXISTS bauth.idn_network_connection_policy (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name       TEXT    NOT NULL,
    min_tls_version   TEXT    NOT NULL DEFAULT 'TLS_1_3' CHECK (min_tls_version IN ('TLS_1_2','TLS_1_3')),
    require_mtls      BOOLEAN NOT NULL DEFAULT false,
    require_dpop      BOOLEAN NOT NULL DEFAULT false,
    require_pkce      BOOLEAN NOT NULL DEFAULT true,
    cipher_suites     TEXT[]  NOT NULL DEFAULT ARRAY['TLS_AES_256_GCM_SHA384','TLS_CHACHA20_POLY1305_SHA256'],
    allowed_ip_ranges INET[],
    blocked_ip_ranges INET[],
    rate_limit_rps    INTEGER CHECK (rate_limit_rps > 0),
    max_conn_per_ip   INTEGER CHECK (max_conn_per_ip > 0),
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    notes             TEXT,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_incp_tenant_name UNIQUE (tenant_id, policy_name)
);
CREATE INDEX IF NOT EXISTS idx_incp_tenant_status ON bauth.idn_network_connection_policy (tenant_id, status);

-- T-196: DPoP binding — sender-constraining de tokens (RFC 9449 §4) · FAPI 2.0
-- WORM: solo INSERT (los bindings son de un solo uso)
CREATE TABLE IF NOT EXISTS bauth.idn_network_dpop_binding (
    id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id   UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    jti         TEXT    NOT NULL,       -- JWT ID único del DPoP proof
    token_jti   TEXT    NOT NULL,       -- JTI del access token asociado
    dpop_jkt    TEXT    NOT NULL,       -- JWK thumbprint SHA-256 clave pública
    http_method TEXT    NOT NULL,
    http_uri    TEXT    NOT NULL,
    alg         TEXT    NOT NULL DEFAULT 'ES256' CHECK (alg IN ('ES256','ES384','RS256','PS256','EdDSA')),
    ath         TEXT,                   -- hash del access token (RFC 9449 §4.2)
    nonce       TEXT,                   -- server nonce para replay prevention
    issued_at   TIMESTAMPTZ NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    is_used     BOOLEAN NOT NULL DEFAULT false,
    client_ip   INET,
    ctx_id      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_indb_jti UNIQUE (jti),
    CONSTRAINT chk_indb_expiry CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS idx_indb_token   ON bauth.idn_network_dpop_binding (token_jti, is_used);
CREATE INDEX IF NOT EXISTS idx_indb_expires ON bauth.idn_network_dpop_binding (expires_at) WHERE is_used = false;
CREATE INDEX IF NOT EXISTS idx_indb_tenant  ON bauth.idn_network_dpop_binding (tenant_id, created_at DESC);

-- T-197: Política de rate limiting — OWASP API Security 2023 §6
CREATE TABLE IF NOT EXISTS bauth.idn_network_rate_policy (
    id                  UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    scope               TEXT    NOT NULL CHECK (scope IN ('GLOBAL','TENANT','CLIENT','USER','IP')),
    scope_ref           UUID,
    endpoint_pattern    TEXT,
    requests_per_second INTEGER NOT NULL CHECK (requests_per_second > 0),
    burst_size          INTEGER NOT NULL CHECK (burst_size > 0),
    window_seconds      INTEGER NOT NULL DEFAULT 60,
    action_on_exceed    TEXT    NOT NULL DEFAULT 'THROTTLE' CHECK (action_on_exceed IN ('THROTTLE','BLOCK','NOTIFY')),
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_inrp_tenant_scope ON bauth.idn_network_rate_policy (tenant_id, scope, status);

-- T-198: Política de postura de dispositivo ZTA — NIST SP 800-207 §3.3
CREATE TABLE IF NOT EXISTS bauth.idn_network_posture_policy (
    id                       UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id                UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name              TEXT    NOT NULL,
    require_compliant_device BOOLEAN NOT NULL DEFAULT false,
    require_managed_device   BOOLEAN NOT NULL DEFAULT false,
    min_risk_score           INTEGER NOT NULL DEFAULT 0   CHECK (min_risk_score BETWEEN 0 AND 100),
    max_risk_score           INTEGER NOT NULL DEFAULT 100 CHECK (max_risk_score BETWEEN 0 AND 100),
    require_mdm_enrolled     BOOLEAN NOT NULL DEFAULT false,
    allow_byod               BOOLEAN NOT NULL DEFAULT true,
    posture_ttl_minutes      INTEGER NOT NULL DEFAULT 240,
    action_on_fail           TEXT    NOT NULL DEFAULT 'STEP_UP' CHECK (action_on_fail IN ('DENY','STEP_UP','NOTIFY','CHALLENGE')),
    status                   TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id                   TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_inpp_tenant_name UNIQUE (tenant_id, policy_name)
);

-- T-199: Segmentos de red — NIST SP 800-207 §2.1 · ISO 27001 A.8.22
CREATE TABLE IF NOT EXISTS bauth.idn_network_segment (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    segment_name    TEXT    NOT NULL,
    segment_type    TEXT    NOT NULL CHECK (segment_type IN ('DMZ','INTERNAL','TRUSTED','ISOLATED','QUARANTINE')),
    cidr_ranges     INET[]  NOT NULL,
    trust_level     TEXT    NOT NULL DEFAULT 'UNTRUSTED' CHECK (trust_level IN ('TRUSTED','CONDITIONALLY_TRUSTED','UNTRUSTED')),
    require_mtls    BOOLEAN NOT NULL DEFAULT false,
    require_vpn     BOOLEAN NOT NULL DEFAULT false,
    status          TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    notes           TEXT,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ins_tenant_name UNIQUE (tenant_id, segment_name)
);

-- T-200: Política DLP de inspección — NIST SP 800-53 R5 SI-3 · ISO 27001 A.8.12
CREATE TABLE IF NOT EXISTS bauth.idn_network_dlp_policy (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id             UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    policy_name           TEXT    NOT NULL,
    inspect_payload       BOOLEAN NOT NULL DEFAULT false,
    inspect_headers       BOOLEAN NOT NULL DEFAULT true,
    max_payload_bytes     INTEGER CHECK (max_payload_bytes > 0),
    allowed_content_types TEXT[],
    sensitive_patterns    TEXT[],
    action_on_match       TEXT    NOT NULL DEFAULT 'LOG' CHECK (action_on_match IN ('LOG','BLOCK','REDACT','QUARANTINE')),
    status                TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_indlp_tenant_name UNIQUE (tenant_id, policy_name)
);

-- T-201: Configuración de propagación del ctx_id — SBOS-049 · W3C Trace Context v2
CREATE TABLE IF NOT EXISTS bauth.idn_network_context_propagation (
    id                 UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id          UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    source_service     TEXT    NOT NULL,
    target_service     TEXT    NOT NULL,
    propagation_format TEXT    NOT NULL DEFAULT 'W3C_TRACEPARENT' CHECK (propagation_format IN ('W3C_TRACEPARENT','W3C_BAGGAGE','SBOS_CTX_HEADER','OTEL_BAGGAGE')),
    header_name        TEXT    NOT NULL DEFAULT 'X-SBOS-CTX-ID',
    included_fields    TEXT[]  NOT NULL DEFAULT ARRAY['tenant_id','user_id','traceparent'],
    encrypt_payload    BOOLEAN NOT NULL DEFAULT false,
    status             TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id             TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_incp2_origin_target UNIQUE (tenant_id, source_service, target_service)
);

-- ===========================================================================
-- SECCIÓN 4: D09 — Gaps de Credenciales (T-202, T-363)
-- ===========================================================================

-- T-202: Historial de contraseñas — NIST SP 800-63B-4 §5.1.1.2 · OWASP ASVS 5.0 §2.1.7
CREATE TABLE IF NOT EXISTS bauth.idn_credential_password_history (
    id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id        UUID    NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    password_hash  TEXT    NOT NULL CHECK (length(password_hash) > 0),
    hash_algorithm TEXT    NOT NULL DEFAULT 'ARGON2ID',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_icph_user_history ON bauth.idn_credential_password_history (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_icph_tenant       ON bauth.idn_credential_password_history (tenant_id, user_id);

-- T-363: Tokens emitidos por bAuth con ciclo de vida completo y DPoP binding
-- Particionada por mes — PG18: PK debe incluir partition key
CREATE TABLE IF NOT EXISTS bauth.idn_credential_token_issued (
    id               UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    user_id          UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    jti              TEXT    NOT NULL,
    token_type       TEXT    NOT NULL CHECK (token_type IN ('ACCESS','REFRESH','ID','EXCHANGE','DEVICE')),
    client_id        TEXT    NOT NULL,
    scopes           TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    dpop_jkt         TEXT,                      -- thumbprint JWK si DPoP-bound (RFC 9449)
    dpop_binding_id  UUID    REFERENCES bauth.idn_network_dpop_binding(id),
    issued_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ,
    revocation_reason TEXT   CHECK (revocation_reason IN ('USER_LOGOUT','ADMIN_REVOKE','CREDENTIAL_CHANGE','SESSION_EXPIRED','SUSPICIOUS_ACTIVITY')),
    loa_issued       INTEGER NOT NULL DEFAULT 1 CHECK (loa_issued BETWEEN 1 AND 3),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_icti_expiry CHECK (expires_at > issued_at),
    PRIMARY KEY (id, issued_at)   -- PG18: partition key en PK
) PARTITION BY RANGE (issued_at);

CREATE TABLE IF NOT EXISTS bauth.idn_credential_token_issued_2026_07
    PARTITION OF bauth.idn_credential_token_issued
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credential_token_issued_2026_08
    PARTITION OF bauth.idn_credential_token_issued
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credential_token_issued_2026_09
    PARTITION OF bauth.idn_credential_token_issued
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS bauth.idn_credential_token_issued_default
    PARTITION OF bauth.idn_credential_token_issued DEFAULT;

CREATE INDEX IF NOT EXISTS idx_icti_user_active ON bauth.idn_credential_token_issued (user_id, revoked_at, expires_at) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_icti_jti         ON bauth.idn_credential_token_issued (jti);
CREATE INDEX IF NOT EXISTS idx_icti_dpop        ON bauth.idn_credential_token_issued (dpop_jkt) WHERE dpop_jkt IS NOT NULL;

-- ===========================================================================
-- SECCIÓN 5: D02 — Control de Acceso Físico (T-220..T-228)
-- T-228 primero: idn_physical_access_presence la referencia
-- ===========================================================================

-- T-228: Credenciales físicas vinculadas a identidad digital — NIST SP 800-116 R2 §3 · FIPS 201-3
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_credential (
    id                     UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id              UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id              UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id                UUID    REFERENCES bauth.idn_user(user_id),
    credential_type        TEXT    NOT NULL CHECK (credential_type IN ('RFID','SMARTCARD','PIV','BIOMETRIC','PIN','NFC','QR')),
    credential_code        TEXT    NOT NULL,   -- número de badge / UUID de tarjeta
    facility_code          TEXT,
    issued_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at             TIMESTAMPTZ,
    revoked_at             TIMESTAMPTZ,
    revoked_by             UUID    REFERENCES bauth.idn_user(user_id),
    revocation_reason      TEXT,
    allowed_location_ids   UUID[],            -- array de location_id permitidos
    access_level           INTEGER NOT NULL DEFAULT 1 CHECK (access_level BETWEEN 1 AND 5),
    status                 TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    ctx_id                 TEXT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ipac_credential UNIQUE (tenant_id, credential_code)
);
CREATE INDEX IF NOT EXISTS idx_ipac_entity ON bauth.idn_physical_access_credential (entity_id, status);
CREATE INDEX IF NOT EXISTS idx_ipac_active ON bauth.idn_physical_access_credential (tenant_id, status) WHERE status = 'ACTIVE';

-- T-220: Catálogo de instalaciones físicas — ISO 27001 A.7.1 · IEC 60839-11-5
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_location (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    location_name    TEXT    NOT NULL,
    location_type    TEXT    NOT NULL CHECK (location_type IN ('BUILDING','FLOOR','ROOM','DATACENTER','WAREHOUSE','PERIMETER','VEHICLE_ACCESS')),
    address          TEXT,
    country_iso      TEXT    NOT NULL DEFAULT 'BO',
    city             TEXT,
    security_level   INTEGER NOT NULL DEFAULT 1 CHECK (security_level BETWEEN 1 AND 5),
    requires_escort  BOOLEAN NOT NULL DEFAULT false,
    max_capacity     INTEGER CHECK (max_capacity > 0),
    parent_id        UUID    REFERENCES bauth.idn_physical_access_location(id),
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE')),
    notes            TEXT,
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ipal_tenant_name UNIQUE (tenant_id, location_name)
);
CREATE INDEX IF NOT EXISTS idx_ipal_tenant ON bauth.idn_physical_access_location (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_ipal_parent ON bauth.idn_physical_access_location (parent_id) WHERE parent_id IS NOT NULL;

-- T-221: Lectores de acceso físico — SIA OSDP v2.2.2 · IEC 60839-11-5 §6
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_reader (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    location_id      UUID    NOT NULL REFERENCES bauth.idn_physical_access_location(id),
    reader_name      TEXT    NOT NULL,
    reader_type      TEXT    NOT NULL CHECK (reader_type IN ('RFID','SMARTCARD','BIOMETRIC','PIN','MULTIFACTOR','OSDP')),
    protocol         TEXT    NOT NULL DEFAULT 'OSDP_V2' CHECK (protocol IN ('WIEGAND','OSDP_V1','OSDP_V2','OSDP_V2_2')),
    osdp_address     INTEGER CHECK (osdp_address BETWEEN 0 AND 127),
    physical_location TEXT   NOT NULL,   -- descripción de ubicación en el edificio
    direction        TEXT    NOT NULL CHECK (direction IN ('ENTRY','EXIT','BIDIRECTIONAL')),
    is_online        BOOLEAN NOT NULL DEFAULT true,
    last_heartbeat   TIMESTAMPTZ,
    firmware_version TEXT,
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','OFFLINE','MAINTENANCE','DISABLED')),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ipar_location ON bauth.idn_physical_access_reader (location_id, status);
CREATE INDEX IF NOT EXISTS idx_ipar_offline  ON bauth.idn_physical_access_reader (is_online, last_heartbeat) WHERE is_online = false;

-- T-222: Estado de presencia actual por actor+instalación — NIST SP 800-116 R2 §4.2
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_presence (
    id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id    UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id    UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    location_id  UUID    NOT NULL REFERENCES bauth.idn_physical_access_location(id),
    is_inside    BOOLEAN NOT NULL DEFAULT false,
    entered_at   TIMESTAMPTZ,
    entered_via  UUID    REFERENCES bauth.idn_physical_access_reader(id),
    ctx_id       TEXT,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ipap_entity_location UNIQUE (tenant_id, entity_id, location_id)
);
CREATE INDEX IF NOT EXISTS idx_ipap_inside ON bauth.idn_physical_access_presence (location_id, is_inside) WHERE is_inside = true;

-- T-223: Log de eventos de acceso físico (anti-passback) — IEC 60839-11-1 §6.4
-- Particionada por mes
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_event_log (
    id             UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id      UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    reader_id      UUID    NOT NULL REFERENCES bauth.idn_physical_access_reader(id),
    location_id    UUID    NOT NULL REFERENCES bauth.idn_physical_access_location(id),
    event_type     TEXT    NOT NULL CHECK (event_type IN ('ENTRY','EXIT','DENIED','ALARM','FORCED','ANTIPASSBACK')),
    credential_type TEXT   CHECK (credential_type IN ('RFID','SMARTCARD','BIOMETRIC','PIN','MULTIFACTOR')),
    credential_id  UUID    REFERENCES bauth.idn_physical_access_credential(id) DEFERRABLE INITIALLY DEFERRED,
    outcome        TEXT    NOT NULL CHECK (outcome IN ('GRANTED','DENIED','ALARM','TIMEOUT')),
    denial_reason  TEXT,
    ctx_id         TEXT,
    logged_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_event_log_2026_07
    PARTITION OF bauth.idn_physical_access_event_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_event_log_2026_08
    PARTITION OF bauth.idn_physical_access_event_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_event_log_default
    PARTITION OF bauth.idn_physical_access_event_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_ipael_entity ON bauth.idn_physical_access_event_log (entity_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_ipael_reader ON bauth.idn_physical_access_event_log (reader_id, logged_at DESC);

-- T-224: Registro de visitas — ISO 27001 A.7.2 · GDPR Art. 5(1)(c)
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_visit (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    location_id      UUID    NOT NULL REFERENCES bauth.idn_physical_access_location(id),
    visitor_name     TEXT    NOT NULL,
    visitor_doc      TEXT,
    visitor_company  TEXT,
    host_id          UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    purpose          TEXT    NOT NULL,
    scheduled_from   TIMESTAMPTZ NOT NULL,
    scheduled_until  TIMESTAMPTZ NOT NULL,
    actual_entry_at  TIMESTAMPTZ,
    actual_exit_at   TIMESTAMPTZ,
    badge_number     TEXT,
    escort_id        UUID    REFERENCES bauth.idn_user(user_id),
    status           TEXT    NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED','ACTIVE','COMPLETED','CANCELLED','NO_SHOW')),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ipav_dates CHECK (scheduled_until > scheduled_from)
);
CREATE INDEX IF NOT EXISTS idx_ipav_host    ON bauth.idn_physical_access_visit (host_id, scheduled_from);
CREATE INDEX IF NOT EXISTS idx_ipav_active  ON bauth.idn_physical_access_visit (status, location_id) WHERE status IN ('SCHEDULED','ACTIVE');

-- T-225: Acceso de emergencia físico — NIST SP 800-116 R2 §5.4
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_emergency (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    location_id      UUID    NOT NULL REFERENCES bauth.idn_physical_access_location(id),
    emergency_type   TEXT    NOT NULL CHECK (emergency_type IN ('FIRE','INTRUSION','MEDICAL','EVACUATION','POWER_FAILURE','OTHER')),
    activated_by     UUID    REFERENCES bauth.idn_user(user_id),
    activated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at   TIMESTAMPTZ,
    deactivated_by   UUID    REFERENCES bauth.idn_user(user_id),
    door_mode        TEXT    NOT NULL DEFAULT 'NORMAL' CHECK (door_mode IN ('NORMAL','FAIL_SAFE','FAIL_SECURE','MANUAL_OVERRIDE')),
    affected_doors   TEXT[],
    incident_ref     TEXT,
    notes            TEXT,
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ipae_active ON bauth.idn_physical_access_emergency (location_id, deactivated_at) WHERE deactivated_at IS NULL;

-- T-226: Evacuación y mustering — ISO 27001 A.7.4 · NFPA 101:2021 §7.7
CREATE TABLE IF NOT EXISTS bauth.idn_physical_access_evacuation (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    emergency_id     UUID    NOT NULL REFERENCES bauth.idn_physical_access_emergency(id),
    muster_point     TEXT    NOT NULL,
    entity_id        UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    is_confirmed     BOOLEAN NOT NULL DEFAULT false,
    confirmed_at     TIMESTAMPTZ,
    confirmed_by     UUID    REFERENCES bauth.idn_user(user_id),
    last_location_id UUID    REFERENCES bauth.idn_physical_access_location(id),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ipaev_emergency ON bauth.idn_physical_access_evacuation (emergency_id, is_confirmed);

-- ===========================================================================
-- SECCIÓN 6: D03 — Control Financiero (T-240..T-248)
-- ===========================================================================

-- T-240: Límites transaccionales por rol/actor — PCI DSS 4.0 Req 8.2 · NIST AC-2(6)
CREATE TABLE IF NOT EXISTS bauth.idn_financial_limit (
    id                       UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id                UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    scope                    TEXT        NOT NULL CHECK (scope IN ('ROLE','USER','ENTITY','CLIENT')),
    scope_ref                UUID        NOT NULL,
    operation_type           TEXT        NOT NULL CHECK (operation_type IN ('PAYMENT','TRANSFER','APPROVAL','ISSUANCE','ACCOUNTING','GENERAL')),
    currency                 TEXT        NOT NULL DEFAULT 'BOB',
    limit_amount             NUMERIC(20,4) NOT NULL CHECK (limit_amount > 0),
    daily_limit              NUMERIC(20,4) CHECK (daily_limit > 0),
    monthly_limit            NUMERIC(20,4) CHECK (monthly_limit > 0),
    requires_dual_approval   BOOLEAN     NOT NULL DEFAULT false,
    dual_approval_threshold  NUMERIC(20,4),
    status                   TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    valid_from               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until              TIMESTAMPTZ,
    ctx_id                   TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifl_scope ON bauth.idn_financial_limit (tenant_id, scope, scope_ref, status);

-- T-241: Solicitud de aprobación dual financiera — COSO 2013 CC6.3 · SOX §302
CREATE TABLE IF NOT EXISTS bauth.idn_financial_approval (
    id                  UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    requester_id        UUID        NOT NULL REFERENCES bauth.idn_user(user_id),
    operation_type      TEXT        NOT NULL CHECK (operation_type IN ('PAYMENT','TRANSFER','APPROVAL','ISSUANCE','ACCOUNTING')),
    amount              NUMERIC(20,4) NOT NULL CHECK (amount > 0),
    currency            TEXT        NOT NULL DEFAULT 'BOB',
    description         TEXT        NOT NULL CHECK (length(description) >= 10),
    external_reference  TEXT,
    status              TEXT        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED')),
    required_quorum     INTEGER     NOT NULL DEFAULT 2 CHECK (required_quorum >= 2),
    achieved_quorum     INTEGER     NOT NULL DEFAULT 0,
    expires_at          TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifa_pending ON bauth.idn_financial_approval (tenant_id, status, expires_at) WHERE status = 'PENDING';

-- T-248: Voto individual de aprobación dual — desglosado de T-241
CREATE TABLE IF NOT EXISTS bauth.idn_financial_approval_vote (
    id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    approval_id  UUID    NOT NULL REFERENCES bauth.idn_financial_approval(id),
    approver_id  UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    decision     TEXT    NOT NULL CHECK (decision IN ('APPROVE','REJECT','ABSTAIN')),
    reason       TEXT,
    ctx_id       TEXT,
    voted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ifav_approval_approver UNIQUE (approval_id, approver_id)
);
CREATE INDEX IF NOT EXISTS idx_ifav_approval ON bauth.idn_financial_approval_vote (approval_id, decision);

-- T-242: Reglas SoD financiero — NIST AC-5 · SOX §404 · COSO CC6.3
CREATE TABLE IF NOT EXISTS bauth.idn_financial_sod_rule (
    id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    rule_name      TEXT    NOT NULL,
    operation_a    TEXT    NOT NULL,
    operation_b    TEXT    NOT NULL,
    conflict_type  TEXT    NOT NULL CHECK (conflict_type IN ('MUTUALLY_EXCLUSIVE','REQUIRES_APPROVAL','SEQUENTIAL_ONLY')),
    description    TEXT    NOT NULL,
    status         TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id         TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifsr_tenant ON bauth.idn_financial_sod_rule (tenant_id, status);

-- T-243: Autorización de factura electrónica SIN — SIN RND 102100000011 · Ley 164 Bolivia
CREATE TABLE IF NOT EXISTS bauth.idn_financial_invoice_auth (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    requester_id    UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    issuer_nit      TEXT    NOT NULL,
    receiver_nit    TEXT,
    invoice_number  TEXT    NOT NULL,
    total_amount    NUMERIC(20,4) NOT NULL,
    currency        TEXT    NOT NULL DEFAULT 'BOB',
    issue_date      DATE    NOT NULL,
    cuf             TEXT,                  -- Código Único de Factura SIN
    cufd            TEXT,                  -- Código Único de Facturación Diaria
    signature_op_id UUID,                  -- ref: sig_operation_log (sin FK por PK compuesta)
    sin_status      TEXT    NOT NULL DEFAULT 'PENDING' CHECK (sin_status IN ('PENDING','AUTHORIZED','REJECTED','CANCELLED','CONTINGENCY')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifia_nit    ON bauth.idn_financial_invoice_auth (issuer_nit, issue_date);
CREATE INDEX IF NOT EXISTS idx_ifia_status ON bauth.idn_financial_invoice_auth (tenant_id, sin_status);

-- T-244: Reportes financieros de control — SOX §302/§404 · IFRS 7
CREATE TABLE IF NOT EXISTS bauth.idn_financial_report (
    id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id    UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    report_type  TEXT    NOT NULL CHECK (report_type IN ('SOX_302','SOX_404','PCI_DSS','QUARTERLY','ANNUAL','INCIDENT','AUDIT')),
    period_from  DATE    NOT NULL,
    period_until DATE    NOT NULL,
    generated_by UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    approved_by  UUID    REFERENCES bauth.idn_user(user_id),
    file_ref     TEXT,
    hash_sha256  TEXT,
    status       TEXT    NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','PUBLISHED','ARCHIVED')),
    ctx_id       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- T-245: Alertas de fraude financiero — PCI DSS 4.0 Req 10.7 · ISO 37001 §8.6
CREATE TABLE IF NOT EXISTS bauth.idn_financial_fraud_alert (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id        UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    alert_type       TEXT    NOT NULL CHECK (alert_type IN ('UNUSUAL_AMOUNT','TIME_PATTERN','ANOMALOUS_LOCATION','SOD_VIOLATION','MULTIPLE_REJECTIONS','VELOCITY_CHECK')),
    severity         TEXT    NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    description      TEXT    NOT NULL,
    reference_amount NUMERIC(20,4),
    is_investigated  BOOLEAN NOT NULL DEFAULT false,
    result           TEXT    CHECK (result IN ('FRAUD_CONFIRMED','FALSE_POSITIVE','PENDING','ESCALATED')),
    investigator_id  UUID    REFERENCES bauth.idn_user(user_id),
    ctx_id           TEXT,
    detected_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_iffa_unresolved ON bauth.idn_financial_fraud_alert (tenant_id, is_investigated, severity) WHERE is_investigated = false;

-- T-246: Conciliación financiera — ISO 20022 §5 · COSO 2013 CC6.6
CREATE TABLE IF NOT EXISTS bauth.idn_financial_reconciliation (
    id                  UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    period              DATE    NOT NULL,
    reconciliation_type TEXT    NOT NULL CHECK (reconciliation_type IN ('DAILY','MONTHLY','QUARTERLY','ANNUAL')),
    source_system       TEXT    NOT NULL,
    target_system       TEXT    NOT NULL,
    source_records      INTEGER NOT NULL,
    target_records      INTEGER NOT NULL,
    differences         INTEGER NOT NULL DEFAULT 0,
    difference_amount   NUMERIC(20,4) NOT NULL DEFAULT 0,
    status              TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','WITH_DIFFERENCES','APPROVED')),
    executed_by         UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ifr_tenant_period ON bauth.idn_financial_reconciliation (tenant_id, period);

-- T-247: Consentimiento TPP / Open Banking — FAPI 2.0 · RFC 9449 DPoP · PSD2 Art. 98
CREATE TABLE IF NOT EXISTS bauth.idn_financial_tpp_consent (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tpp_client_id   TEXT    NOT NULL,
    tpp_name        TEXT    NOT NULL,
    granted_scopes  TEXT[]  NOT NULL,
    amount_limit    NUMERIC(20,4),
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until     TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    revoked_by      TEXT    CHECK (revoked_by IN ('USER','ADMIN','TPP','REGULATOR','EXPIRED')),
    dpop_required   BOOLEAN NOT NULL DEFAULT true,
    fapi_profile    TEXT    NOT NULL DEFAULT 'FAPI_2_0' CHECK (fapi_profile IN ('FAPI_1_0','FAPI_2_0')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_iftc_validity CHECK (valid_until > valid_from)
);
CREATE INDEX IF NOT EXISTS idx_iftc_entity_active ON bauth.idn_financial_tpp_consent (entity_id, revoked_at) WHERE revoked_at IS NULL;

-- ===========================================================================
-- SECCIÓN 7: D04 — Control Temporal GTRBAC (T-260..T-265)
-- ===========================================================================

-- T-260: Ventanas de tiempo de acceso — GTRBAC §3.2 · NIST AC-3(7)
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_window (
    id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id    UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    window_name  TEXT    NOT NULL,
    window_type  TEXT    NOT NULL CHECK (window_type IN ('TIME_OF_DAY','DAILY','WEEKLY','MONTHLY','CUSTOM')),
    start_time   TIME    NOT NULL,
    end_time     TIME    NOT NULL,
    week_days    INTEGER[] CHECK (array_length(week_days, 1) > 0),  -- 1=lun..7=dom
    timezone     TEXT    NOT NULL DEFAULT 'America/La_Paz',
    is_active    BOOLEAN NOT NULL DEFAULT true,
    ctx_id       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_itw_tenant_name UNIQUE (tenant_id, window_name),
    CONSTRAINT chk_itw_schedule   CHECK (end_time > start_time)
);

-- T-261: Períodos temporales — GTRBAC §4 · ISO 8601:2019
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_period (
    id            UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id     UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id     UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    window_id     UUID    NOT NULL REFERENCES bauth.idn_temporal_window(id),
    valid_from    TIMESTAMPTZ NOT NULL,
    valid_until   TIMESTAMPTZ NOT NULL,
    role_id       TEXT    NOT NULL,
    auto_activate BOOLEAN NOT NULL DEFAULT true,
    ctx_id        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_itp_period CHECK (valid_until > valid_from)
);
CREATE INDEX IF NOT EXISTS idx_itp_entity_active ON bauth.idn_temporal_period (entity_id, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_itp_valid          ON bauth.idn_temporal_period (tenant_id, valid_until);

-- T-262: Asociación de calendarios a ventanas (FK a bcalendar)
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_calendar (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    window_id         UUID    NOT NULL REFERENCES bauth.idn_temporal_window(id),
    calendar_id       UUID    NOT NULL REFERENCES bcalendar.cal_calendar(calendar_id),
    exclude_holidays  BOOLEAN NOT NULL DEFAULT true,
    exclude_weekends  BOOLEAN NOT NULL DEFAULT false,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_itc_window_calendar UNIQUE (window_id, calendar_id)
);

-- T-263: Turnos de trabajo — NIST AC-2(2) · GTRBAC §5
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_shift (
    id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    shift_name     TEXT    NOT NULL,
    window_id      UUID    NOT NULL REFERENCES bauth.idn_temporal_window(id),
    rotation_type  TEXT    NOT NULL DEFAULT 'FIXED' CHECK (rotation_type IN ('FIXED','ROTATING','FLEXIBLE','GUARD')),
    duration_hours NUMERIC(4,1) NOT NULL CHECK (duration_hours BETWEEN 1 AND 24),
    is_active      BOOLEAN NOT NULL DEFAULT true,
    ctx_id         TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_its_tenant_name UNIQUE (tenant_id, shift_name)
);

-- T-264: Asignación de turno a actor
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_shift_assignment (
    id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id   UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    shift_id    UUID    NOT NULL REFERENCES bauth.idn_temporal_shift(id),
    entity_id   UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id     UUID    REFERENCES bauth.idn_user(user_id),
    valid_from  TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ,
    assigned_by UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_itsa_entity ON bauth.idn_temporal_shift_assignment (entity_id, valid_from);

-- T-265: Excepciones temporales — NIST AC-17(1) · ISO 27001 A.5.18
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_exception (
    id                 UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id          UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id          UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    exception_type     TEXT    NOT NULL CHECK (exception_type IN ('EXTENSION','REDUCTION','BLOCK','ADDITIONAL_GUARD')),
    reason             TEXT    NOT NULL CHECK (length(reason) >= 20),
    original_window_id UUID    NOT NULL REFERENCES bauth.idn_temporal_window(id),
    valid_from         TIMESTAMPTZ NOT NULL,
    valid_until        TIMESTAMPTZ NOT NULL,
    approved_by        UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    ctx_id             TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ite_validity CHECK (valid_until > valid_from)
);

-- ===========================================================================
-- SECCIÓN 8: D05 — Control Biométrico (T-280..T-285)
-- ===========================================================================

-- T-280: Enrolamiento biométrico — NIST SP 800-76-2 §4 · ISO/IEC 30107-1:2023
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_enrollment (
    id                  UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id           UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    user_id             UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    biometric_type      TEXT    NOT NULL CHECK (biometric_type IN ('FINGERPRINT','IRIS','FACE','VOICE','RETINA','PALM','VEIN')),
    sample_quality      NUMERIC(5,2) NOT NULL CHECK (sample_quality BETWEEN 0 AND 100),
    algorithm           TEXT    NOT NULL,
    vault_template_path TEXT    NOT NULL,   -- ruta en Vault — NUNCA el template en BD
    ial_achieved        INTEGER NOT NULL DEFAULT 2 CHECK (ial_achieved BETWEEN 2 AND 3),
    liveness_check      BOOLEAN NOT NULL DEFAULT true,
    liveness_score      NUMERIC(5,2) CHECK (liveness_score BETWEEN 0 AND 100),
    enrolled_by         UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    enrolled_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,
    revoked_at          TIMESTAMPTZ,
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibe_entity_type ON bauth.idn_biometric_enrollment (entity_id, biometric_type, status);

-- T-281: Log de verificaciones biométricas — particionada por mes
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_verification_log (
    id             UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    enrollment_id  UUID    NOT NULL REFERENCES bauth.idn_biometric_enrollment(id),
    biometric_type TEXT    NOT NULL,
    outcome        TEXT    NOT NULL CHECK (outcome IN ('MATCH','NO_MATCH','LIVENESS_FAIL','QUALITY_FAIL','ERROR','TIMEOUT')),
    score_match    NUMERIC(5,2),
    score_liveness NUMERIC(5,2),
    loa_achieved   INTEGER CHECK (loa_achieved BETWEEN 1 AND 3),
    ip_hash        TEXT,   -- GDPR: IP anonimizada
    device_id      UUID,
    ctx_id         TEXT,
    verified_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, verified_at)
) PARTITION BY RANGE (verified_at);

CREATE TABLE IF NOT EXISTS bauth.idn_biometric_verification_log_2026_07
    PARTITION OF bauth.idn_biometric_verification_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_verification_log_2026_08
    PARTITION OF bauth.idn_biometric_verification_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_verification_log_default
    PARTITION OF bauth.idn_biometric_verification_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_ibvl_enrollment ON bauth.idn_biometric_verification_log (enrollment_id, verified_at DESC);

-- T-282: Política PAD (Presentation Attack Detection) — ISO/IEC 30107-3:2023 §5 · FIDO2 §8.8
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_pad_policy (
    id                  UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id           UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    biometric_type      TEXT    NOT NULL CHECK (biometric_type IN ('FINGERPRINT','IRIS','FACE','VOICE','RETINA','PALM','VEIN')),
    pad_level           TEXT    NOT NULL DEFAULT 'LEVEL_2' CHECK (pad_level IN ('LEVEL_1','LEVEL_2','LEVEL_3')),
    liveness_threshold  NUMERIC(5,2) NOT NULL DEFAULT 80.0 CHECK (liveness_threshold BETWEEN 0 AND 100),
    pad_algorithm       TEXT    NOT NULL,
    pad_block_attempts  INTEGER NOT NULL DEFAULT 3,
    fail_action         TEXT    NOT NULL DEFAULT 'DENY' CHECK (fail_action IN ('DENY','STEP_UP','LOG_AND_ALLOW','QUARANTINE')),
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibpp_tenant_type UNIQUE (tenant_id, biometric_type)
);

-- T-283: Log de identificación 1:N — ISO/IEC 19794-2:2011 §6
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_identification_log (
    id              UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    biometric_type  TEXT    NOT NULL,
    candidate_count INTEGER NOT NULL,
    best_score      NUMERIC(5,2),
    result          TEXT    NOT NULL CHECK (result IN ('IDENTIFIED','NOT_IDENTIFIED','MULTIPLE_MATCH','ERROR')),
    entity_id_match UUID    REFERENCES bauth.idn_identity_entity(entity_id),
    threshold_used  NUMERIC(5,2) NOT NULL,
    ctx_id          TEXT,
    searched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, searched_at)
) PARTITION BY RANGE (searched_at);

CREATE TABLE IF NOT EXISTS bauth.idn_biometric_identification_log_default
    PARTITION OF bauth.idn_biometric_identification_log DEFAULT;

-- T-284: Política de calidad de muestra — ISO/IEC 29794-1:2024 §5 · NIST SP 800-76-2 §3
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_quality_policy (
    id                   UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id            UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    biometric_type       TEXT    NOT NULL CHECK (biometric_type IN ('FINGERPRINT','IRIS','FACE','VOICE','RETINA','PALM','VEIN')),
    min_quality          NUMERIC(5,2) NOT NULL DEFAULT 70.0 CHECK (min_quality BETWEEN 0 AND 100),
    max_attempts         INTEGER NOT NULL DEFAULT 3,
    retry_with_liveness  BOOLEAN NOT NULL DEFAULT true,
    status               TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibqp_tenant_type UNIQUE (tenant_id, biometric_type)
);

-- T-285: Revocación de template biométrico — ISO/IEC 24745:2022 §6 · NIST SP 800-76-2 §6
CREATE TABLE IF NOT EXISTS bauth.idn_biometric_revocation (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id             UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    enrollment_id         UUID    NOT NULL REFERENCES bauth.idn_biometric_enrollment(id),
    revocation_reason     TEXT    NOT NULL CHECK (revocation_reason IN ('COMPROMISE','USER_REQUEST','ADMIN','EXPIRATION','QUALITY_DEGRADED','INCIDENT')),
    revoked_by            UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    vault_wipe_confirmed  BOOLEAN NOT NULL DEFAULT false,  -- confirmación de borrado en Vault
    vault_wipe_at         TIMESTAMPTZ,
    replacement_id        UUID    REFERENCES bauth.idn_biometric_enrollment(id),
    ctx_id                TEXT,
    revoked_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibr_enrollment ON bauth.idn_biometric_revocation (enrollment_id);

-- ===========================================================================
-- SECCIÓN 9: D06 — Control Geoespacial (T-300..T-305)
-- ===========================================================================

-- T-300: Geocercas — RFC 7946 §3.1 · OGC GeoSPARQL 1.1
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_geofence (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    fence_name      TEXT    NOT NULL,
    fence_type      TEXT    NOT NULL CHECK (fence_type IN ('CIRCLE','POLYGON','COUNTRY','REGION','CITY')),
    center_lat      NUMERIC(10,7),
    center_lon      NUMERIC(10,7),
    radius_km       NUMERIC(8,3)  CHECK (radius_km > 0),
    geojson         JSONB,                  -- para tipos POLYGON/COUNTRY/REGION
    action_outside  TEXT    NOT NULL DEFAULT 'DENY'  CHECK (action_outside IN ('DENY','STEP_UP','LOG','NOTIFY')),
    action_inside   TEXT    NOT NULL DEFAULT 'ALLOW' CHECK (action_inside  IN ('ALLOW','STEP_UP','LOG','NOTIFY')),
    country_iso     TEXT,                   -- ISO 3166-1 alpha-2
    status          TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igg_tenant_name UNIQUE (tenant_id, fence_name)
);
CREATE INDEX IF NOT EXISTS idx_igg_tenant_active ON bauth.idn_geospatial_geofence (tenant_id, status);

-- T-301: Log de ubicaciones — RFC 7946 §3 · NIST AC-3(11) · GDPR Art. 5(1)(c)
-- Particionada por mes · IP anonimizada (GDPR)
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_location_log (
    id              UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id       UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    latitude        NUMERIC(10,7) NOT NULL,
    longitude       NUMERIC(10,7) NOT NULL,
    accuracy_meters NUMERIC(8,2),
    location_source TEXT    NOT NULL CHECK (location_source IN ('GPS','WIFI','IP_GEOIP','CELL','MANUAL','BEACON')),
    geofence_id     UUID    REFERENCES bauth.idn_geospatial_geofence(id),
    inside_geofence BOOLEAN,
    ip_hash         TEXT,                   -- GDPR: IP anonimizada
    session_id      UUID,
    ctx_id          TEXT,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, captured_at)
) PARTITION BY RANGE (captured_at);

CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_location_log_2026_07
    PARTITION OF bauth.idn_geospatial_location_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_location_log_2026_08
    PARTITION OF bauth.idn_geospatial_location_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_location_log_default
    PARTITION OF bauth.idn_geospatial_location_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_igll_entity ON bauth.idn_geospatial_location_log (entity_id, captured_at DESC);

-- T-302: Política de velocidad geográfica (viaje imposible) — NIST SI-4(13)
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_velocity_policy (
    id                   UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id            UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    max_velocity_kmh     NUMERIC(8,2) NOT NULL DEFAULT 900.0 CHECK (max_velocity_kmh > 0),
    analysis_window_min  INTEGER NOT NULL DEFAULT 60,
    action               TEXT    NOT NULL DEFAULT 'STEP_UP' CHECK (action IN ('DENY','STEP_UP','NOTIFY','LOG')),
    severity             TEXT    NOT NULL DEFAULT 'HIGH' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    status               TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igvp_tenant UNIQUE (tenant_id)
);

-- T-303: Eventos de viaje imposible detectados
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_velocity_event (
    id                       UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id                UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id                UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    location_a_id            UUID    NOT NULL,  -- ref: idn_geospatial_location_log.id (sin FK en partitioned)
    location_b_id            UUID    NOT NULL,  -- ref: idn_geospatial_location_log.id (sin FK en partitioned)
    calculated_velocity_kmh  NUMERIC(10,2) NOT NULL,
    distance_km              NUMERIC(10,2) NOT NULL,
    time_minutes             NUMERIC(10,2) NOT NULL,
    action_taken             TEXT    NOT NULL,
    is_investigated          BOOLEAN NOT NULL DEFAULT false,
    ctx_id                   TEXT,
    detected_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_igve_unresolved ON bauth.idn_geospatial_velocity_event (tenant_id, is_investigated, detected_at DESC) WHERE is_investigated = false;

-- T-304: Residencia de datos y soberanía geográfica — GDPR Art. 44-49 · Ley 1174 Bolivia
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_data_residency (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id             UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    allowed_countries     TEXT[]  NOT NULL,         -- ISO 3166-1 alpha-2
    blocked_countries     TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    apply_to              TEXT    NOT NULL DEFAULT 'ALL' CHECK (apply_to IN ('ALL','DATA_RESIDENCY','AUTH_ONLY','STORAGE')),
    violation_action      TEXT    NOT NULL DEFAULT 'DENY' CHECK (violation_action IN ('DENY','LOG','NOTIFY','QUARANTINE')),
    requires_sovereign_vpn BOOLEAN NOT NULL DEFAULT false,
    exempt_entity_ids     UUID[],                   -- entity_ids exentos de la política
    status                TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igdr_tenant UNIQUE (tenant_id)
);

-- T-305: Flota de dispositivos móviles con trazabilidad geoespacial — ISO 6709:2022
CREATE TABLE IF NOT EXISTS bauth.idn_geospatial_device_fleet (
    id                   UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id            UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    device_id            UUID    NOT NULL REFERENCES bauth.auth_device(device_id),
    fleet_name           TEXT    NOT NULL,
    assigned_geofence_id UUID    REFERENCES bauth.idn_geospatial_geofence(id),
    inside_geofence      BOOLEAN NOT NULL DEFAULT false,
    last_lat             NUMERIC(10,7),
    last_lon             NUMERIC(10,7),
    last_location_at     TIMESTAMPTZ,
    ctx_id               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_igdf_device UNIQUE (device_id)
);

-- ===========================================================================
-- SECCIÓN 10: D10 — Delegación de Identidad (T-415..T-420)
-- ===========================================================================

-- T-415: Delegación de identidad base — RFC 8693 §3 · NIST AC-2(5)
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_grant (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    grantor_id       UUID    NOT NULL REFERENCES bauth.idn_user(user_id),    -- quien delega
    grantee_id       UUID    NOT NULL REFERENCES bauth.idn_user(user_id),    -- quien recibe
    purpose          TEXT    NOT NULL CHECK (length(purpose) >= 20),
    delegation_type  TEXT    NOT NULL DEFAULT 'IMPERSONATION' CHECK (delegation_type IN ('IMPERSONATION','AGENT','PROXY','TOKEN_EXCHANGE')),
    scopes           TEXT[]  NOT NULL,
    amount_limit     NUMERIC(20,4),
    valid_from       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until      TIMESTAMPTZ NOT NULL,
    max_renewals     INTEGER NOT NULL DEFAULT 0,
    renewals_used    INTEGER NOT NULL DEFAULT 0,
    revoked_at       TIMESTAMPTZ,
    revoked_by       UUID    REFERENCES bauth.idn_user(user_id),
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_idg_validity   CHECK (valid_until > valid_from),
    CONSTRAINT chk_idg_self_grant CHECK (grantor_id <> grantee_id)
);
CREATE INDEX IF NOT EXISTS idx_idg_grantee ON bauth.idn_delegation_grant (grantee_id, status, valid_until);
CREATE INDEX IF NOT EXISTS idx_idg_grantor ON bauth.idn_delegation_grant (grantor_id, status);

-- T-416: Renovación de delegación — RFC 8693 §4.2
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_renewal (
    id         UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    grant_id   UUID    NOT NULL REFERENCES bauth.idn_delegation_grant(id),
    renewed_by UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    new_until  TIMESTAMPTZ NOT NULL,
    reason     TEXT,
    ctx_id     TEXT,
    renewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idr_grant ON bauth.idn_delegation_renewal (grant_id, renewed_at DESC);

-- T-417: Restricciones sobre el scope delegado — NIST AC-5 · ISO 27001 A.5.3
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_restriction (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    grant_id         UUID    NOT NULL REFERENCES bauth.idn_delegation_grant(id),
    restriction_type TEXT    NOT NULL CHECK (restriction_type IN ('SCOPE_LIMIT','IP_WHITELIST','HOURS_ONLY','RESOURCE_LIMIT','APPROVAL_REQUIRED')),
    parameters       JSONB   NOT NULL DEFAULT '{}'::jsonb,
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idrestr_grant ON bauth.idn_delegation_restriction (grant_id);

-- T-418: Cadena de delegación — RFC 8693 §2 · ANSI INCITS 359-2004 §4.5
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_chain (
    id            UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    root_grant_id UUID    NOT NULL REFERENCES bauth.idn_delegation_grant(id),
    grant_id      UUID    NOT NULL REFERENCES bauth.idn_delegation_grant(id),
    depth         INTEGER NOT NULL DEFAULT 1 CHECK (depth BETWEEN 1 AND 5),
    ctx_id        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_idc_chain UNIQUE (root_grant_id, grant_id)
);

-- T-419: Log de uso de delegaciones — particionada · ISO 27001 A.8.15 · NIST AU-2
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_usage_log (
    id          UUID    DEFAULT gen_random_uuid() NOT NULL,
    grant_id    UUID    NOT NULL REFERENCES bauth.idn_delegation_grant(id),
    action_name TEXT    NOT NULL,
    resource    TEXT,
    outcome     TEXT    NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR')),
    ip_hash     TEXT,
    ctx_id      TEXT,
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_delegation_usage_log_2026_07
    PARTITION OF bauth.idn_delegation_usage_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_usage_log_2026_08
    PARTITION OF bauth.idn_delegation_usage_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_usage_log_default
    PARTITION OF bauth.idn_delegation_usage_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_idul_grant ON bauth.idn_delegation_usage_log (grant_id, logged_at DESC);

-- T-420: Rich Authorization Request — RFC 9396 §3 · OAuth 2.0
CREATE TABLE IF NOT EXISTS bauth.idn_delegation_rar_request (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id             UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    grant_id              UUID    REFERENCES bauth.idn_delegation_grant(id),
    client_id             TEXT    NOT NULL,
    authorization_details JSONB   NOT NULL,  -- RFC 9396 §2: array de objetos tipados
    status                TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED')),
    expires_at            TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '10 minutes',
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_idrr_client ON bauth.idn_delegation_rar_request (client_id, status, expires_at);

-- ===========================================================================
-- SECCIÓN 11: D11 — Auditoría y SIEM (T-421..T-424)
-- ===========================================================================

-- T-421: Política de retención de logs — SOX §802 · GDPR Art. 5(1)(e) · NIST AU-11
CREATE TABLE IF NOT EXISTS bauth.idn_audit_retention_policy (
    id                   UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id            UUID    REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = política global
    event_type           TEXT    NOT NULL,    -- auth, privilege, financial, biometric, ALL
    retention_days       INTEGER NOT NULL CHECK (retention_days > 0),
    legal_retention_days INTEGER,             -- SOX §802 = 2555 días (7 años)
    legal_basis          TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    expiration_action    TEXT    NOT NULL DEFAULT 'ARCHIVE' CHECK (expiration_action IN ('DELETE','ARCHIVE','ANONYMIZE','KEEP')),
    archive_destination  TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    ctx_id               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iarp_tenant_type UNIQUE (tenant_id, event_type)
);
CREATE INDEX IF NOT EXISTS idx_iarp_active ON bauth.idn_audit_retention_policy (is_active, event_type) WHERE is_active = true;

-- T-422: Reglas de alerta de auditoría — NIST AU-6 · ISO 27001 A.8.16
CREATE TABLE IF NOT EXISTS bauth.idn_audit_alert_rule (
    id                      UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id               UUID    REFERENCES bauth.idn_tenant(tenant_id),
    rule_name               TEXT    NOT NULL,
    description             TEXT    NOT NULL,
    condition_spec          JSONB   NOT NULL,  -- {event_type, threshold, window_minutes, ...}
    severity                TEXT    NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    notification_channels   TEXT[]  NOT NULL DEFAULT ARRAY['SIEM'],
    false_positive_threshold INTEGER DEFAULT 0,
    is_active               BOOLEAN NOT NULL DEFAULT true,
    ctx_id                  TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iaar_tenant_name UNIQUE (tenant_id, rule_name)
);

-- T-423: Destinos SIEM — NIST AU-9(2) · ISO 27001 A.8.15 (Wazuh por defecto)
CREATE TABLE IF NOT EXISTS bauth.idn_audit_siem_target (
    id            UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id     UUID    REFERENCES bauth.idn_tenant(tenant_id),
    target_name   TEXT    NOT NULL,
    protocol_type TEXT    NOT NULL CHECK (protocol_type IN ('SYSLOG_UDP','SYSLOG_TCP','SYSLOG_TLS','HTTP_WEBHOOK','KAFKA','ELASTIC')),
    endpoint      TEXT    NOT NULL,
    port          INTEGER CHECK (port BETWEEN 1 AND 65535),
    tls_enabled   BOOLEAN NOT NULL DEFAULT false,
    log_format    TEXT    NOT NULL DEFAULT 'CEF' CHECK (log_format IN ('CEF','LEEF','JSON','SYSLOG_RFC5424','WAZUH')),
    event_filter  TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],  -- vacío = todos los eventos
    is_active     BOOLEAN NOT NULL DEFAULT true,
    last_sent_at  TIMESTAMPTZ,
    ctx_id        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_iast_tenant_name UNIQUE (tenant_id, target_name)
);

-- T-424: Evento de auditoría unificado multi-dominio — particionado por mes
-- ISO 27001 A.8.15 · GDPR Art. 5(1)(f) · NIST AU-2 · hash chain WORM
CREATE TABLE IF NOT EXISTS bauth.idn_audit_event_log (
    id          UUID    DEFAULT gen_random_uuid() NOT NULL,
    tenant_id   UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    domain_code TEXT    NOT NULL CHECK (domain_code IN ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','D10','D11','D12','D13','D14','D15','D98','D99')),
    event_type  TEXT    NOT NULL,
    subject_id  UUID,
    subject_type TEXT   CHECK (subject_type IN ('USER','ENTITY','NHI','SYSTEM')),
    action      TEXT    NOT NULL,
    resource    TEXT,
    outcome     TEXT    NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR','PARTIAL')),
    ip_hash     TEXT,
    ctx_id      TEXT,
    metadata    JSONB   NOT NULL DEFAULT '{}'::jsonb,
    prev_hash   TEXT,
    hash_actual TEXT,   -- SHA-256 calculado por trigger: tenant+domain+event_type+action+outcome+ctx+prev_hash
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

CREATE TABLE IF NOT EXISTS bauth.idn_audit_event_log_2026_07
    PARTITION OF bauth.idn_audit_event_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.idn_audit_event_log_2026_08
    PARTITION OF bauth.idn_audit_event_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.idn_audit_event_log_2026_09
    PARTITION OF bauth.idn_audit_event_log
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS bauth.idn_audit_event_log_default
    PARTITION OF bauth.idn_audit_event_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_iael_domain  ON bauth.idn_audit_event_log (domain_code, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_iael_subject ON bauth.idn_audit_event_log (subject_id, logged_at DESC) WHERE subject_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iael_denied  ON bauth.idn_audit_event_log (outcome, logged_at DESC) WHERE outcome = 'DENY';

-- ===========================================================================
-- SECCIÓN 12: D12 — Blockchain extra (T-425..T-429)
-- ===========================================================================

-- T-425: Extensión de anclaje blockchain (complementa blk_anchor T-358)
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_anchor_ext (
    id                       UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    blk_anchor_id            UUID    NOT NULL REFERENCES bauth.blk_anchor(anchor_id),
    source_event_type        TEXT    NOT NULL CHECK (source_event_type IN ('PRIVILEGE_GRANT','AUDIT_BATCH','DIGITAL_SIGNATURE','VC_ISSUED','SOD_VIOLATION')),
    source_event_id          UUID    NOT NULL,
    merkle_proof_path        TEXT[],                    -- prueba de inclusión
    external_verification_url TEXT,
    ctx_id                   TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibae_source ON bauth.idn_blockchain_anchor_ext (source_event_type, source_event_id);

-- T-426: Registro de transacciones Besu QBFT — Hyperledger Besu §6
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_transaction (
    id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id    UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    account_id   UUID    NOT NULL REFERENCES bauth.blk_account(account_id),
    tx_hash      TEXT    NOT NULL UNIQUE,
    tx_type      TEXT    NOT NULL CHECK (tx_type IN ('SETTLE','FREEZE','UNFREEZE','REVERT','DEPLOY','CALL')),
    from_address TEXT    NOT NULL,
    to_address   TEXT,
    value_wei    NUMERIC(30,0),
    gas_used     BIGINT,
    status       TEXT    NOT NULL CHECK (status IN ('PENDING','CONFIRMED','FAILED','REVERTED')),
    block_number BIGINT,
    confirmed_at TIMESTAMPTZ,
    ctx_id       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ibt_account ON bauth.idn_blockchain_transaction (account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ibt_status  ON bauth.idn_blockchain_transaction (status) WHERE status = 'PENDING';

-- T-427: Wallet blockchain por tenant — BIP-32/39/44 · EIP-712
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_wallet (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) UNIQUE,
    chain             TEXT    NOT NULL DEFAULT 'BESU_QBFT' CHECK (chain IN ('BESU_QBFT','ARBITRUM')),
    address           TEXT    NOT NULL UNIQUE,
    vault_key_path    TEXT    NOT NULL,   -- clave privada NUNCA en BD — siempre en Vault
    hd_path           TEXT,              -- BIP-44 derivation path
    balance_wei       NUMERIC(30,0) NOT NULL DEFAULT 0,
    balance_updated_at TIMESTAMPTZ,
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','DECOMMISSIONED')),
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- T-428: Pruebas de inclusión Merkle — RFC 6962 §2.1.1 · NIST SP 800-208 §3
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_merkle_proof (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    batch_id          UUID    NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id),
    leaf_hash         TEXT    NOT NULL,
    proof_path        TEXT[]  NOT NULL,     -- sibling hashes
    proof_directions  INTEGER[] NOT NULL,   -- 0=left, 1=right
    root_hash         TEXT    NOT NULL,
    is_verified       BOOLEAN NOT NULL DEFAULT false,
    verified_at       TIMESTAMPTZ,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ibmp_batch_leaf UNIQUE (batch_id, leaf_hash)
);

-- T-429: Nodos del consenso Besu QBFT — Hyperledger Besu §4 · EIP-225
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_node (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    enode_url         TEXT    NOT NULL UNIQUE,
    address           TEXT    NOT NULL UNIQUE,
    is_validator      BOOLEAN NOT NULL DEFAULT false,
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SYNCING','OFFLINE','DECOMMISSIONED')),
    last_block_number BIGINT,
    peers_count       INTEGER,
    last_heartbeat    TIMESTAMPTZ,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===========================================================================
-- SECCIÓN 13: D13 — Firma Digital (T-440..T-446)
-- ===========================================================================

-- T-440: Solicitud de firma digital — PAdES EN 319 132 · Ley 164 Bolivia Art. 9
CREATE TABLE IF NOT EXISTS bauth.idn_signature_request (
    id                 UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id          UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    requester_id       UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    document_type      TEXT    NOT NULL CHECK (document_type IN ('PDF','XML','JSON','INVOICE_SIN','VC','JWT','CONTRACT')),
    signature_format   TEXT    NOT NULL DEFAULT 'PADES_B' CHECK (signature_format IN ('PADES_B','PADES_T','PADES_LT','PADES_LTA','CADES_B','XADES_B','JADES')),
    engine             TEXT    NOT NULL CHECK (engine IN ('INTERNAL_ED25519','EXTERNAL_ADSIB','DUAL')),
    document_hash      TEXT    NOT NULL,   -- SHA-256 del documento
    vault_key_path     TEXT,              -- ruta en Vault para motor interno
    cert_id            UUID    REFERENCES bauth.sig_certificate(cert_id),
    status             TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SIGNING','SIGNED','FAILED','CANCELLED')),
    requires_timestamp BOOLEAN NOT NULL DEFAULT false,
    requires_lts       BOOLEAN NOT NULL DEFAULT false,
    operation_id       UUID    REFERENCES bauth.sig_operation_log(operation_id),
    ctx_id             TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_isr_pending ON bauth.idn_signature_request (tenant_id, status, created_at) WHERE status IN ('PENDING','SIGNING');

-- T-441: Cadena de certificación CA — RFC 5280 §6 · ADSIB-FD-POLT-015 v2.3
CREATE TABLE IF NOT EXISTS bauth.idn_signature_ca_chain (
    id                 UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id          UUID    REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = global
    ca_name            TEXT    NOT NULL,
    ca_type            TEXT    NOT NULL CHECK (ca_type IN ('ROOT_CA','INTERMEDIATE_CA','ISSUING_CA','ADSIB','VAULT_PKI')),
    subject_dn         TEXT    NOT NULL,
    issuer_dn          TEXT    NOT NULL,
    fingerprint_sha256 TEXT    NOT NULL UNIQUE,
    not_before         TIMESTAMPTZ NOT NULL,
    not_after          TIMESTAMPTZ NOT NULL,
    vault_cert_path    TEXT    NOT NULL,   -- ruta Vault — NUNCA el PEM en BD
    ocsp_url           TEXT,
    crl_url            TEXT,
    is_trusted         BOOLEAN NOT NULL DEFAULT true,
    parent_id          UUID    REFERENCES bauth.idn_signature_ca_chain(id),
    ctx_id             TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iscc_fingerprint ON bauth.idn_signature_ca_chain (fingerprint_sha256);
CREATE INDEX IF NOT EXISTS idx_iscc_active       ON bauth.idn_signature_ca_chain (is_trusted, not_after) WHERE is_trusted = true;

-- T-442: Timestamp calificado de firma — RFC 3161 §2 · Ley 164 Bolivia Art. 20
CREATE TABLE IF NOT EXISTS bauth.idn_signature_timestamp (
    id                    UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    signature_request_id  UUID    NOT NULL REFERENCES bauth.idn_signature_request(id),
    tsa_url               TEXT    NOT NULL,
    tsa_name              TEXT    NOT NULL,
    token_base64          TEXT    NOT NULL,   -- RFC 3161 TSTInfo en Base64
    serial_number         TEXT    NOT NULL,
    hash_algorithm        TEXT    NOT NULL DEFAULT 'SHA-256',
    message_imprint       TEXT    NOT NULL,   -- hash del documento al momento del TS
    gen_time              TIMESTAMPTZ NOT NULL,
    accuracy_micros       INTEGER,
    nonce                 TEXT,
    ctx_id                TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ist_request ON bauth.idn_signature_timestamp (signature_request_id);

-- T-443: Log de verificaciones de firma — ETSI EN 319 102-1 §5 · RFC 5280
CREATE TABLE IF NOT EXISTS bauth.idn_signature_verification_log (
    id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    verifier_id    UUID    REFERENCES bauth.idn_user(user_id),
    document_hash  TEXT    NOT NULL,
    signature_type TEXT    NOT NULL,
    outcome        TEXT    NOT NULL CHECK (outcome IN ('VALID','INVALID','EXPIRED','REVOKED','UNKNOWN','ERROR')),
    cert_status    TEXT    CHECK (cert_status IN ('VALID','REVOKED','EXPIRED','UNKNOWN')),
    chain_valid    BOOLEAN,
    timestamp_valid BOOLEAN,
    ltv_valid      BOOLEAN,
    detail         JSONB   NOT NULL DEFAULT '{}'::jsonb,
    ctx_id         TEXT,
    verified_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_isvl_outcome ON bauth.idn_signature_verification_log (outcome, verified_at DESC) WHERE outcome != 'VALID';

-- T-444: Cache de estado de revocación OCSP/CRL — RFC 6960 · RFC 5280 §5
CREATE TABLE IF NOT EXISTS bauth.idn_signature_revocation_cache (
    id                 UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    cert_fingerprint   TEXT    NOT NULL UNIQUE,
    issuer_fingerprint TEXT    NOT NULL,
    status             TEXT    NOT NULL CHECK (status IN ('GOOD','REVOKED','UNKNOWN')),
    this_update        TIMESTAMPTZ NOT NULL,
    next_update        TIMESTAMPTZ NOT NULL,
    revoked_at         TIMESTAMPTZ,
    revocation_reason  TEXT,
    check_source       TEXT    NOT NULL CHECK (check_source IN ('OCSP','CRL','VAULT','MANUAL')),
    ctx_id             TEXT,
    cached_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_isrc_expiry ON bauth.idn_signature_revocation_cache (next_update) WHERE status = 'GOOD';

-- T-445: Evidencia LTV (Long-Term Validation) — ETSI EN 319 102-2 §5.6 · RFC 3161 §3
CREATE TABLE IF NOT EXISTS bauth.idn_signature_ltv_evidence (
    id                   UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    signature_request_id UUID    NOT NULL REFERENCES bauth.idn_signature_request(id),
    timestamp_id         UUID    NOT NULL REFERENCES bauth.idn_signature_timestamp(id),
    certificate_chain    TEXT[]  NOT NULL,   -- fingerprints SHA-256 de la cadena al momento
    ocsp_responses       JSONB   NOT NULL DEFAULT '[]'::jsonb,
    crls_hash            TEXT[],
    archived_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until          TIMESTAMPTZ,        -- estimado de cuándo debe re-archivarse
    ctx_id               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_isle_request ON bauth.idn_signature_ltv_evidence (signature_request_id);

-- T-446: Integración EUDI Wallet — UE 2024/1183 eIDAS 2.0 · ARF 1.4
CREATE TABLE IF NOT EXISTS bauth.idn_signature_eudi_wallet (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id         UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    wallet_provider   TEXT    NOT NULL,
    wallet_did        TEXT,
    pid_credential_id TEXT,               -- Personal ID credential del EUDI
    status            TEXT    NOT NULL DEFAULT 'LINKED' CHECK (status IN ('LINKED','SUSPENDED','REVOKED','PENDING')),
    linked_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at      TIMESTAMPTZ,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_isew_entity UNIQUE (entity_id, wallet_provider)
);

-- ===========================================================================
-- SECCIÓN 14: D14 — PAM: Referencia de grabación de sesiones (T-461)
-- ===========================================================================

-- T-461: Referencia trazable a grabaciones de sesiones privilegiadas — NIST AU-14
CREATE TABLE IF NOT EXISTS bauth.pam_session_recording (
    id                UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    session_record_id UUID    NOT NULL REFERENCES bauth.pam_session_record(id),
    file_name         TEXT    NOT NULL,
    file_hash_sha256  TEXT    NOT NULL,
    storage_type      TEXT    NOT NULL DEFAULT 'MINIO' CHECK (storage_type IN ('MINIO','S3','LOCAL','NFS')),
    storage_bucket    TEXT    NOT NULL,
    storage_path      TEXT    NOT NULL,
    size_bytes        BIGINT,
    duration_seconds  INTEGER,
    is_encrypted      BOOLEAN NOT NULL DEFAULT true,
    vault_key_path    TEXT,               -- clave de cifrado en Vault
    retain_until      DATE    NOT NULL,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_psr_session   ON bauth.pam_session_recording (session_record_id);
CREATE INDEX IF NOT EXISTS idx_psr_retention ON bauth.pam_session_recording (retain_until);

-- ===========================================================================
-- SECCIÓN 15: D15 — NHI: Gaps (T-480..T-481)
-- ===========================================================================

-- T-480: Política de rotación de secretos NHI — NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §4.4
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_rotation_policy (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nhi_type        TEXT    NOT NULL CHECK (nhi_type IN ('SERVICE_ACCOUNT','CI_CD','DAEMON','BOT','AGENT_IA','API_KEY')),
    rotation_days   INTEGER NOT NULL CHECK (rotation_days BETWEEN 1 AND 365),
    rotate_on_use   BOOLEAN NOT NULL DEFAULT false,  -- ON_USE pattern para CI/CD
    pre_notice_days INTEGER NOT NULL DEFAULT 7,
    auto_rotate     BOOLEAN NOT NULL DEFAULT true,
    fail_action     TEXT    NOT NULL DEFAULT 'NOTIFY' CHECK (fail_action IN ('NOTIFY','SUSPEND_NHI','ALERT_ADMIN')),
    status          TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_inrp_tenant_type UNIQUE (tenant_id, nhi_type)
);

-- T-481: SPIFFE SVID para daemons SBOS — SPIFFE Spec v1.0 §8 · NIST SP 800-204A §4
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_svid (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = sistema
    nhi_id           UUID    NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    spiffe_id        TEXT    NOT NULL,           -- spiffe://trust-domain/path
    svid_type        TEXT    NOT NULL DEFAULT 'X509' CHECK (svid_type IN ('X509','JWT')),
    trust_domain     TEXT    NOT NULL,
    cert_fingerprint TEXT,
    serial_number    TEXT,
    issued_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at       TIMESTAMPTZ NOT NULL,
    rotated_at       TIMESTAMPTZ,
    vault_path       TEXT    NOT NULL,           -- cert SVID en Vault — NUNCA en BD
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ROTATED','REVOKED','EXPIRED')),
    ctx_id           TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_ins_nhi_spiffe UNIQUE (nhi_id, spiffe_id),
    CONSTRAINT chk_ins_expiry    CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS idx_ins_active ON bauth.idn_nhi_svid (trust_domain, status, expires_at) WHERE status = 'ACTIVE';

-- ===========================================================================
-- SECCIÓN 16: D98 — Meta-Registro (T-500..T-502)
-- ===========================================================================

-- T-500: Schema registry de atributos EAV — SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5
CREATE TABLE IF NOT EXISTS bauth.idn_registry_attribute_schema (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    attr_key         TEXT    NOT NULL UNIQUE,  -- clave canónica: 'nit_bo', 'phone_mobile'
    category         TEXT    NOT NULL CHECK (category IN ('IDENTITY','CONTACT','LEGAL','BIOMETRIC','FINANCIAL','SYSTEM','CUSTOM')),
    data_type        TEXT    NOT NULL CHECK (data_type IN ('TEXT','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','JSON','BINARY','UUID')),
    mutability       TEXT    NOT NULL DEFAULT 'READ_WRITE' CHECK (mutability IN ('READ_ONLY','READ_WRITE','WRITE_ONCE')),
    returned         TEXT    NOT NULL DEFAULT 'DEFAULT' CHECK (returned IN ('ALWAYS','DEFAULT','NEVER','REQUEST')),
    required         BOOLEAN NOT NULL DEFAULT false,
    multi_valued     BOOLEAN NOT NULL DEFAULT false,
    min_ial          INTEGER NOT NULL DEFAULT 1 CHECK (min_ial BETWEEN 1 AND 3),
    source           TEXT    NOT NULL DEFAULT 'USER' CHECK (source IN ('USER','SYSTEM','PROOFING','IMPORT','DERIVED')),
    classification   TEXT    NOT NULL DEFAULT 'INTERNAL' CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','SECRET')),
    mask_display     BOOLEAN NOT NULL DEFAULT false,
    retention_days   INTEGER CHECK (retention_days > 0),
    validation_regex TEXT,
    description      TEXT    NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_iras_category ON bauth.idn_registry_attribute_schema (category, is_active);

-- T-501: Catálogo de átomos del motor BitMask — NIST SP 800-162 §4.2
-- Auto-poblado por trigger en idn_roles_template (H-06)
CREATE TABLE IF NOT EXISTS bauth.idn_registry_atom_catalog (
    id              UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    atom_code       TEXT    NOT NULL UNIQUE,
    template_id     UUID    NOT NULL REFERENCES bauth.idn_roles_template(id),
    domain_code     TEXT    NOT NULL CHECK (domain_code IN ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','D10','D11','D12','D13','D14','D15','D98','D99')),
    bit_position    INTEGER,               -- posición en el BitMask 64-bit
    description     TEXT    NOT NULL,
    is_implemented  BOOLEAN NOT NULL DEFAULT false,
    deprecated_at   TIMESTAMPTZ,
    ctx_id          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_irac_domain ON bauth.idn_registry_atom_catalog (domain_code, is_implemented);
CREATE INDEX IF NOT EXISTS idx_irac_bit    ON bauth.idn_registry_atom_catalog (bit_position) WHERE bit_position IS NOT NULL;

-- T-502: Versiones del árbol BitMask — ISO 9001:2015 §7.5 · ISO/IEC 24760-2:2025
-- Job diario toma snapshot del árbol para auditoría forense
CREATE TABLE IF NOT EXISTS bauth.idn_registry_bitmask_version (
    id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    version_tag    TEXT    NOT NULL,
    snapshot_hash  TEXT    NOT NULL,   -- SHA-256 del estado completo del árbol
    total_atoms    INTEGER NOT NULL,
    active_atoms   INTEGER NOT NULL,
    domain_counts  JSONB   NOT NULL DEFAULT '{}'::jsonb,
    generated_by   TEXT    NOT NULL DEFAULT 'DAILY_JOB',
    ctx_id         TEXT,
    generated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_irbv_version UNIQUE (version_tag)
);
CREATE INDEX IF NOT EXISTS idx_irbv_generated ON bauth.idn_registry_bitmask_version (generated_at DESC);

-- ===========================================================================
-- SECCIÓN 17: WORM enforcement (REVOKE UPDATE/DELETE)
-- Tablas append-only por norma ISO 27001 A.8.15
-- ===========================================================================

DO $$
DECLARE
    r TEXT;
    worm_tables TEXT[] := ARRAY[
        'idn_network_dpop_binding',        -- T-196: bindings de un solo uso
        'idn_credential_password_history', -- T-202: historial inmutable
        'idn_physical_access_evacuation',  -- T-226: evidencia forense
        'idn_delegation_usage_log',        -- T-419: log de uso de delegaciones
        'idn_audit_event_log',             -- T-424: log multi-dominio WORM
        'idn_blockchain_anchor_ext',       -- T-425: anclas blockchain
        'idn_signature_verification_log',  -- T-443: verificaciones de firma
        'idn_signature_ltv_evidence'       -- T-445: evidencia LTV
    ];
BEGIN
    FOREACH r IN ARRAY worm_tables LOOP
        BEGIN
            EXECUTE format('REVOKE UPDATE, DELETE ON bauth.%I FROM bauth_app_role', r);
        EXCEPTION WHEN undefined_object THEN
            NULL;  -- rol no existe aún en este entorno
        END;
    END LOOP;
END $$;

-- ===========================================================================
-- SECCIÓN 18: SEEDS CRÍTICOS
-- ===========================================================================

-- T-513: Algoritmos criptográficos (NIST SP 800-131A R2 + PQC FIPS 203/204/205)
INSERT INTO bauth.idn_global_crypto_params
    (algorithm_name, algorithm_family, key_size_bits, is_pqc, is_approved, is_deprecated, is_prohibited, fips_standard, nist_standard, use_cases, notes)
VALUES
    -- Algoritmos aprobados activos
    ('Ed25519',           'SIGNATURE', 256,  false, true,  false, false, 'FIPS 186-5',   'SP 800-186',     ARRAY['JWT','SIGNING'],       'Motor interno bAuth'),
    ('ECDSA-P256',        'SIGNATURE', 256,  false, true,  false, false, 'FIPS 186-5',   'SP 800-186',     ARRAY['TLS','JWT'],            'TLS 1.3'),
    ('ECDSA-P384',        'SIGNATURE', 384,  false, true,  false, false, 'FIPS 186-5',   'SP 800-186',     ARRAY['TLS','JWT'],            'TLS 1.3 alto nivel'),
    ('RSA-SHA256',        'SIGNATURE', 2048, false, true,  false, false, NULL,           'SP 800-131A R2', ARRAY['ADSIB','TLS'],          'Motor externo ADSIB'),
    ('RSA-SHA256-4096',   'SIGNATURE', 4096, false, true,  false, false, NULL,           'SP 800-131A R2', ARRAY['ADSIB'],                'ADSIB alta seguridad'),
    ('AES-256-GCM',       'SYMMETRIC', 256,  false, true,  false, false, 'FIPS 197',     'SP 800-38D',     ARRAY['STORAGE','VAULT'],      'Cifrado en reposo'),
    ('ARGON2ID',          'KDF',       NULL, false, true,  false, false, NULL,           'SP 800-63B-4',   ARRAY['PASSWORDS'],            'Hash contraseñas m=64MB t=3 p=4'),
    ('PBKDF2-SHA512',     'KDF',       NULL, false, true,  false, false, 'FIPS 198-1',   'SP 800-132',     ARRAY['PASSWORDS'],            'Alternativa ARGON2ID'),
    ('SHA-256',           'HASH',      256,  false, true,  false, false, 'FIPS 180-4',   'SP 800-107',     ARRAY['HASH','TLS'],           'Hash documentos y tokens'),
    ('SHA-384',           'HASH',      384,  false, true,  false, false, 'FIPS 180-4',   'SP 800-107',     ARRAY['HASH','TLS'],           'Hash alto nivel'),
    ('ChaCha20-Poly1305', 'SYMMETRIC', 256,  false, true,  false, false, NULL,           'RFC 8439',       ARRAY['TLS'],                  'TLS 1.3 suite alternativa'),
    -- PQC — NIST finalizado agosto 2024 (FIPS 203/204/205)
    ('ML-KEM-768',        'KEM',       NULL, true,  true,  false, false, 'FIPS 203',     'SP 800-227',     ARRAY['TLS','KEM'],            'PQC: Module-Lattice KEM. Antiguo: Kyber-768'),
    ('ML-KEM-1024',       'KEM',       NULL, true,  true,  false, false, 'FIPS 203',     'SP 800-227',     ARRAY['KEM'],                  'PQC: ML-KEM nivel más alto'),
    ('ML-DSA-44',         'SIGNATURE', NULL, true,  true,  false, false, 'FIPS 204',     'SP 800-227',     ARRAY['SIGNING'],              'PQC: Module-Lattice DSA. Antiguo: Dilithium2'),
    ('ML-DSA-65',         'SIGNATURE', NULL, true,  true,  false, false, 'FIPS 204',     'SP 800-227',     ARRAY['SIGNING'],              'PQC: ML-DSA nivel medio'),
    ('SLH-DSA-SHA2-128s', 'SIGNATURE', NULL, true,  true,  false, false, 'FIPS 205',     'SP 800-227',     ARRAY['SIGNING'],              'PQC: Stateless Hash-Based. Antiguo: SPHINCS+'),
    -- Deprecados (solo sistemas legacy)
    ('RSA-SHA1',          'SIGNATURE', 2048, false, false, true,  false, NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'DEPRECADO: SHA-1 débil — deadline migración 2025'),
    -- Prohibidos (NIST SP 800-131A R2)
    ('MD5',               'HASH',      128,  false, false, false, true,  NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'PROHIBIDO: colisiones conocidas'),
    ('SHA-1',             'HASH',      160,  false, false, false, true,  NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'PROHIBIDO: colisiones prácticas (SHAttered 2017)'),
    ('DES',               'SYMMETRIC', 56,   false, false, false, true,  NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'PROHIBIDO: longitud clave insuficiente'),
    ('3DES',              'SYMMETRIC', 168,  false, false, false, true,  NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'PROHIBIDO: SWEET32 attack (2016), retirado 2023'),
    ('RC4',               'SYMMETRIC', NULL, false, false, false, true,  NULL,           'SP 800-131A R2', ARRAY[]::TEXT[],               'PROHIBIDO: vulnerabilidades estructurales')
ON CONFLICT (algorithm_name) DO NOTHING;

-- T-423: Destino SIEM por defecto — Wazuh UDP 514
INSERT INTO bauth.idn_audit_siem_target
    (target_name, protocol_type, endpoint, port, tls_enabled, log_format, event_filter, is_active)
VALUES
    ('Wazuh-Default', 'SYSLOG_UDP', '127.0.0.1', 514, false, 'WAZUH', ARRAY[]::TEXT[], true)
ON CONFLICT (tenant_id, target_name) DO NOTHING;

-- T-421: Políticas de retención por estándar normativo
INSERT INTO bauth.idn_audit_retention_policy
    (tenant_id, event_type, retention_days, legal_retention_days, legal_basis, expiration_action, is_active)
VALUES
    (NULL, 'ALL',        365,  NULL, ARRAY['ISO 27001 A.8.15'],              'ARCHIVE',    true),
    (NULL, 'FINANCIAL',  2555, 2555, ARRAY['SOX §802','PCI DSS 4.0 Req 10'],'ARCHIVE',    true),
    (NULL, 'AUTH',       180,  NULL, ARRAY['NIST AU-11','OWASP ASVS'],       'ARCHIVE',    true),
    (NULL, 'BIOMETRIC',  365,  NULL, ARRAY['GDPR Art. 5(1)(e)','ISO 24745'], 'ANONYMIZE',  true),
    (NULL, 'GDPR_ACCESS',30,   NULL, ARRAY['GDPR Art. 15'],                  'DELETE',     true),
    (NULL, 'PRIVILEGE',  2555, 2555, ARRAY['SOX §404','NIST AU-11'],         'ARCHIVE',    true),
    (NULL, 'INCIDENT',   2555, NULL, ARRAY['ISO 27001 A.8.15','NIS2'],       'KEEP',       true)
ON CONFLICT (tenant_id, event_type) DO NOTHING;

-- T-510: Super-admin del sistema BAUTH_SYSTEM (si existe la entidad base)
DO $$
DECLARE
    v_entity_id UUID;
    v_user_id   UUID;
BEGIN
    SELECT entity_id INTO v_entity_id FROM bauth.idn_identity_entity
    WHERE code = 'BAUTH_SYSTEM' LIMIT 1;

    IF v_entity_id IS NULL THEN
        RETURN;  -- entidad base no existe aún, seed omitido
    END IF;

    SELECT user_id INTO v_user_id FROM bauth.idn_user
    WHERE entity_id = v_entity_id LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN;  -- usuario base no existe aún, seed omitido
    END IF;

    INSERT INTO bauth.idn_global_admin
        (entity_id, user_id, admin_role, can_manage_tenants, can_manage_crypto, can_read_audit_all, status)
    VALUES
        (v_entity_id, v_user_id, 'SUPER_ADMIN', true, true, true, 'ACTIVE')
    ON CONFLICT (user_id) DO NOTHING;
END $$;

-- =============================================================================
-- FIN: bAuth Dominios Pendientes v2.0 — tablas y columnas en inglés
-- Comentarios SQL y documentación en español (regla SBOS)
-- =============================================================================
