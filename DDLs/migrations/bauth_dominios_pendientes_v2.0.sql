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
    admin_role            TEXT        NOT NULL CHECK (admin_role IN ('SUPER_ADMIN','SECURITY_ADMIN','AUDIT_ADMIN','SUPPORT_ADMIN')),  -- [MC-0222] → A.65.04
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
    algorithm_family      TEXT    NOT NULL CHECK (algorithm_family IN ('SYMMETRIC','ASYMMETRIC','HASH','KDF','KEM','SIGNATURE','MAC')),  -- [MC-0224] → A.65.04
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
    notification_type TEXT   NOT NULL CHECK (notification_type IN ('SECURITY_ALERT','CRYPTO_EXPIRY','CERT_EXPIRY','COMPLIANCE_WARNING','MAINTENANCE','INCIDENT','POLICY_CHANGE','CAPACITY_ALERT')),  -- [MC-0228] → A.65.04
    severity         TEXT    NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),  -- [MC-0229] → A.65.04
    title            TEXT    NOT NULL,
    message          TEXT    NOT NULL,
    target_scope     TEXT    NOT NULL DEFAULT 'ALL' CHECK (target_scope IN ('ALL','TENANT','ADMIN')),  -- [MC-0230] → A.65.04
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
    exception_type           TEXT    NOT NULL CHECK (exception_type IN ('PROHIBITED_ALGO','POLICY_OVERRIDE','EMERGENCY_ACCESS','CRYPTO_DOWNGRADE','COMPLIANCE_BREACH','AI_DECISION_REVIEWED')),  -- [MC-0226] → A.65.04
    description              TEXT    NOT NULL CHECK (length(description) >= 50),
    business_justification   TEXT    NOT NULL CHECK (length(business_justification) >= 100),
    requester_id             UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    approver_id              UUID    REFERENCES bauth.idn_global_admin(id),
    status                   TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED','REVOKED')),  -- [MC-0227] → A.65.04
    approved_at              TIMESTAMPTZ,
    valid_from               TIMESTAMPTZ,
    valid_until              TIMESTAMPTZ NOT NULL,
    review_at                TIMESTAMPTZ,  -- calculado por app: valid_until - 7 días
    affected_entity_type     TEXT    NOT NULL CHECK (affected_entity_type IN ('ALGORITHM','POLICY','TENANT','USER','ROLE','CERT')),  -- [MC-0225] → A.65.04
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
    status            TEXT    NOT NULL DEFAULT 'IMPLEMENTED' CHECK (status IN ('IMPLEMENTED','PARTIAL','PLANNED','NOT_APPLICABLE','GAP')),  -- [MC-0223] → A.65.04
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
    component_type  TEXT    NOT NULL CHECK (component_type IN ('LIBRARY','FRAMEWORK','DAEMON','TOOL','OS_PACKAGE','CONTAINER')),  -- [MC-0231] → A.65.04
    version         TEXT    NOT NULL,
    language        TEXT,
    license         TEXT,
    package_url     TEXT,
    cve_known       TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    risk_level      TEXT    NOT NULL DEFAULT 'LOW' CHECK (risk_level IN ('CRITICAL','HIGH','MEDIUM','LOW','NONE')),  -- [MC-0232] → A.65.04
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
    min_tls_version   TEXT    NOT NULL DEFAULT 'TLS_1_3' CHECK (min_tls_version IN ('TLS_1_2','TLS_1_3')),  -- [MC-0163] → A.65.04
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
    alg         TEXT    NOT NULL DEFAULT 'ES256' CHECK (alg IN ('ES256','ES384','RS256','PS256','EdDSA')),  -- [MC-0166] → A.65.04
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
    scope               TEXT    NOT NULL CHECK (scope IN ('GLOBAL','TENANT','CLIENT','USER','IP')),  -- [MC-0169] → A.65.04
    scope_ref           UUID,
    endpoint_pattern    TEXT,
    requests_per_second INTEGER NOT NULL CHECK (requests_per_second > 0),
    burst_size          INTEGER NOT NULL CHECK (burst_size > 0),
    window_seconds      INTEGER NOT NULL DEFAULT 60,
    action_on_exceed    TEXT    NOT NULL DEFAULT 'THROTTLE' CHECK (action_on_exceed IN ('THROTTLE','BLOCK','NOTIFY')),  -- [MC-0168] → A.65.04
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
    action_on_fail           TEXT    NOT NULL DEFAULT 'STEP_UP' CHECK (action_on_fail IN ('DENY','STEP_UP','NOTIFY','CHALLENGE')),  -- [MC-0167] → A.65.04
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
    segment_type    TEXT    NOT NULL CHECK (segment_type IN ('DMZ','INTERNAL','TRUSTED','ISOLATED','QUARANTINE')),  -- [MC-0170] → A.65.04
    cidr_ranges     INET[]  NOT NULL,
    trust_level     TEXT    NOT NULL DEFAULT 'UNTRUSTED' CHECK (trust_level IN ('TRUSTED','CONDITIONALLY_TRUSTED','UNTRUSTED')),  -- [MC-0171] → A.65.04
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
    action_on_match       TEXT    NOT NULL DEFAULT 'LOG' CHECK (action_on_match IN ('LOG','BLOCK','REDACT','QUARANTINE')),  -- [MC-0165] → A.65.04
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
    propagation_format TEXT    NOT NULL DEFAULT 'W3C_TRACEPARENT' CHECK (propagation_format IN ('W3C_TRACEPARENT','W3C_BAGGAGE','SBOS_CTX_HEADER','OTEL_BAGGAGE')),  -- [MC-0164] → A.65.04
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
    token_type       TEXT    NOT NULL CHECK (token_type IN ('ACCESS','REFRESH','ID','EXCHANGE','DEVICE')),  -- [MC-0174] → A.65.04
    client_id        TEXT    NOT NULL,
    scopes           TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
    dpop_jkt         TEXT,                      -- thumbprint JWK si DPoP-bound (RFC 9449)
    dpop_binding_id  UUID    REFERENCES bauth.idn_network_dpop_binding(id),
    issued_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ,
    revocation_reason TEXT   CHECK (revocation_reason IN ('USER_LOGOUT','ADMIN_REVOKE','CREDENTIAL_CHANGE','SESSION_EXPIRED','SUSPICIOUS_ACTIVITY')),  -- [MC-0173] → A.65.04
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
    credential_type        TEXT    NOT NULL CHECK (credential_type IN ('RFID','SMARTCARD','PIV','BIOMETRIC','PIN','NFC','QR')),  -- [MC-0118] → A.65.04
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
    location_type    TEXT    NOT NULL CHECK (location_type IN ('BUILDING','FLOOR','ROOM','DATACENTER','WAREHOUSE','PERIMETER','VEHICLE_ACCESS')),  -- [MC-0124] → A.65.04
    address          TEXT,
    country_iso      TEXT    NOT NULL DEFAULT 'BO',
    city             TEXT,
    security_level   INTEGER NOT NULL DEFAULT 1 CHECK (security_level BETWEEN 1 AND 5),
    requires_escort  BOOLEAN NOT NULL DEFAULT false,
    max_capacity     INTEGER CHECK (max_capacity > 0),
    parent_id        UUID    REFERENCES bauth.idn_physical_access_location(id),
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE')),  -- [MC-0125] → A.65.04
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
    reader_type      TEXT    NOT NULL CHECK (reader_type IN ('RFID','SMARTCARD','BIOMETRIC','PIN','MULTIFACTOR','OSDP')),  -- [MC-0128] → A.65.04
    protocol         TEXT    NOT NULL DEFAULT 'OSDP_V2' CHECK (protocol IN ('WIEGAND','OSDP_V1','OSDP_V2','OSDP_V2_2')),  -- [MC-0127] → A.65.04
    osdp_address     INTEGER CHECK (osdp_address BETWEEN 0 AND 127),
    physical_location TEXT   NOT NULL,   -- descripción de ubicación en el edificio
    direction        TEXT    NOT NULL CHECK (direction IN ('ENTRY','EXIT','BIDIRECTIONAL')),  -- [MC-0126] → A.65.04
    is_online        BOOLEAN NOT NULL DEFAULT true,
    last_heartbeat   TIMESTAMPTZ,
    firmware_version TEXT,
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','OFFLINE','MAINTENANCE','DISABLED')),  -- [MC-0129] → A.65.04
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
    event_type     TEXT    NOT NULL CHECK (event_type IN ('ENTRY','EXIT','DENIED','ALARM','FORCED','ANTIPASSBACK')),  -- [MC-0122] → A.65.04
    credential_type TEXT   CHECK (credential_type IN ('RFID','SMARTCARD','BIOMETRIC','PIN','MULTIFACTOR')),  -- [MC-0121] → A.65.04
    credential_id  UUID    REFERENCES bauth.idn_physical_access_credential(id) DEFERRABLE INITIALLY DEFERRED,
    outcome        TEXT    NOT NULL CHECK (outcome IN ('GRANTED','DENIED','ALARM','TIMEOUT')),  -- [MC-0123] → A.65.04
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
    status           TEXT    NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED','ACTIVE','COMPLETED','CANCELLED','NO_SHOW')),  -- [MC-0130] → A.65.04
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
    emergency_type   TEXT    NOT NULL CHECK (emergency_type IN ('FIRE','INTRUSION','MEDICAL','EVACUATION','POWER_FAILURE','OTHER')),  -- [MC-0120] → A.65.04
    activated_by     UUID    REFERENCES bauth.idn_user(user_id),
    activated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at   TIMESTAMPTZ,
    deactivated_by   UUID    REFERENCES bauth.idn_user(user_id),
    door_mode        TEXT    NOT NULL DEFAULT 'NORMAL' CHECK (door_mode IN ('NORMAL','FAIL_SAFE','FAIL_SECURE','MANUAL_OVERRIDE')),  -- [MC-0119] → A.65.04
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
    scope                    TEXT        NOT NULL CHECK (scope IN ('ROLE','USER','ENTITY','CLIENT')),  -- [MC-0137] → A.65.04
    scope_ref                UUID        NOT NULL,
    operation_type           TEXT        NOT NULL CHECK (operation_type IN ('PAYMENT','TRANSFER','APPROVAL','ISSUANCE','ACCOUNTING','GENERAL')),  -- [MC-0136] → A.65.04
    currency                 TEXT        NOT NULL DEFAULT 'BOB',
    limit_amount             NUMERIC(20,4) NOT NULL CHECK (limit_amount > 0),
    daily_limit              NUMERIC(20,4) CHECK (daily_limit > 0),
    monthly_limit            NUMERIC(20,4) CHECK (monthly_limit > 0),
    requires_dual_approval   BOOLEAN     NOT NULL DEFAULT false,
    dual_approval_threshold  NUMERIC(20,4),
    status                   TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED','DRAFT')),  -- [MC-0138] → A.65.04
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
    operation_type      TEXT        NOT NULL CHECK (operation_type IN ('PAYMENT','TRANSFER','APPROVAL','ISSUANCE','ACCOUNTING')),  -- [MC-0131] → A.65.04
    amount              NUMERIC(20,4) NOT NULL CHECK (amount > 0),
    currency            TEXT        NOT NULL DEFAULT 'BOB',
    description         TEXT        NOT NULL CHECK (length(description) >= 10),
    external_reference  TEXT,
    status              TEXT        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED')),  -- [MC-0046] → A.65.04
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
    decision     TEXT    NOT NULL CHECK (decision IN ('APPROVE','REJECT','ABSTAIN')),  -- [MC-0132] → A.65.04
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
    conflict_type  TEXT    NOT NULL CHECK (conflict_type IN ('MUTUALLY_EXCLUSIVE','REQUIRES_APPROVAL','SEQUENTIAL_ONLY')),  -- [MC-0143] → A.65.04
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
    sin_status      TEXT    NOT NULL DEFAULT 'PENDING' CHECK (sin_status IN ('PENDING','AUTHORIZED','REJECTED','CANCELLED','CONTINGENCY')),  -- [MC-0135] → A.65.04
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
    report_type  TEXT    NOT NULL CHECK (report_type IN ('SOX_302','SOX_404','PCI_DSS','QUARTERLY','ANNUAL','INCIDENT','AUDIT')),  -- [MC-0141] → A.65.04
    period_from  DATE    NOT NULL,
    period_until DATE    NOT NULL,
    generated_by UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    approved_by  UUID    REFERENCES bauth.idn_user(user_id),
    file_ref     TEXT,
    hash_sha256  TEXT,
    status       TEXT    NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','PUBLISHED','ARCHIVED')),  -- [MC-0142] → A.65.04
    ctx_id       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- T-245: Alertas de fraude financiero — PCI DSS 4.0 Req 10.7 · ISO 37001 §8.6
CREATE TABLE IF NOT EXISTS bauth.idn_financial_fraud_alert (
    id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    entity_id        UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    alert_type       TEXT    NOT NULL CHECK (alert_type IN ('UNUSUAL_AMOUNT','TIME_PATTERN','ANOMALOUS_LOCATION','SOD_VIOLATION','MULTIPLE_REJECTIONS','VELOCITY_CHECK')),  -- [MC-0133] → A.65.04
    severity         TEXT    NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    description      TEXT    NOT NULL,
    reference_amount NUMERIC(20,4),
    is_investigated  BOOLEAN NOT NULL DEFAULT false,
    result           TEXT    CHECK (result IN ('FRAUD_CONFIRMED','FALSE_POSITIVE','PENDING','ESCALATED')),  -- [MC-0134] → A.65.04
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
    reconciliation_type TEXT    NOT NULL CHECK (reconciliation_type IN ('DAILY','MONTHLY','QUARTERLY','ANNUAL')),  -- [MC-0139] → A.65.04
    source_system       TEXT    NOT NULL,
    target_system       TEXT    NOT NULL,
    source_records      INTEGER NOT NULL,
    target_records      INTEGER NOT NULL,
    differences         INTEGER NOT NULL DEFAULT 0,
    difference_amount   NUMERIC(20,4) NOT NULL DEFAULT 0,
    status              TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','WITH_DIFFERENCES','APPROVED')),  -- [MC-0140] → A.65.04
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
    revoked_by      TEXT    CHECK (revoked_by IN ('USER','ADMIN','TPP','REGULATOR','EXPIRED')),  -- [MC-0145] → A.65.04
    dpop_required   BOOLEAN NOT NULL DEFAULT true,
    fapi_profile    TEXT    NOT NULL DEFAULT 'FAPI_2_0' CHECK (fapi_profile IN ('FAPI_1_0','FAPI_2_0')),  -- [MC-0144] → A.65.04
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
    window_type  TEXT    NOT NULL CHECK (window_type IN ('TIME_OF_DAY','DAILY','WEEKLY','MONTHLY','CUSTOM')),  -- [MC-0148] → A.65.04
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
    rotation_type  TEXT    NOT NULL DEFAULT 'FIXED' CHECK (rotation_type IN ('FIXED','ROTATING','FLEXIBLE','GUARD')),  -- [MC-0147] → A.65.04
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
    exception_type     TEXT    NOT NULL CHECK (exception_type IN ('EXTENSION','REDUCTION','BLOCK','ADDITIONAL_GUARD')),  -- [MC-0146] → A.65.04
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
    biometric_type      TEXT    NOT NULL CHECK (biometric_type IN ('FINGERPRINT','IRIS','FACE','VOICE','RETINA','PALM','VEIN')),  -- [MC-0149] → A.65.04
    sample_quality      NUMERIC(5,2) NOT NULL CHECK (sample_quality BETWEEN 0 AND 100),
    algorithm           TEXT    NOT NULL,
    vault_template_path TEXT    NOT NULL,   -- ruta en Vault — NUNCA el template en BD
    ial_achieved        INTEGER NOT NULL DEFAULT 2 CHECK (ial_achieved BETWEEN 2 AND 3),
    liveness_check      BOOLEAN NOT NULL DEFAULT true,
    liveness_score      NUMERIC(5,2) CHECK (liveness_score BETWEEN 0 AND 100),
    enrolled_by         UUID    NOT NULL REFERENCES bauth.idn_user(user_id),
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),  -- [MC-0150] → A.65.04
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
    outcome        TEXT    NOT NULL CHECK (outcome IN ('MATCH','NO_MATCH','LIVENESS_FAIL','QUALITY_FAIL','ERROR','TIMEOUT')),  -- [MC-0156] → A.65.04
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
    pad_level           TEXT    NOT NULL DEFAULT 'LEVEL_2' CHECK (pad_level IN ('LEVEL_1','LEVEL_2','LEVEL_3')),  -- [MC-0153] → A.65.04
    liveness_threshold  NUMERIC(5,2) NOT NULL DEFAULT 80.0 CHECK (liveness_threshold BETWEEN 0 AND 100),
    pad_algorithm       TEXT    NOT NULL,
    pad_block_attempts  INTEGER NOT NULL DEFAULT 3,
    fail_action         TEXT    NOT NULL DEFAULT 'DENY' CHECK (fail_action IN ('DENY','STEP_UP','LOG_AND_ALLOW','QUARANTINE')),  -- [MC-0152] → A.65.04
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),  -- [MC-0154] → A.65.04
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
    result          TEXT    NOT NULL CHECK (result IN ('IDENTIFIED','NOT_IDENTIFIED','MULTIPLE_MATCH','ERROR')),  -- [MC-0151] → A.65.04
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
    revocation_reason     TEXT    NOT NULL CHECK (revocation_reason IN ('COMPROMISE','USER_REQUEST','ADMIN','EXPIRATION','QUALITY_DEGRADED','INCIDENT')),  -- [MC-0155] → A.65.04
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
    fence_type      TEXT    NOT NULL CHECK (fence_type IN ('CIRCLE','POLYGON','COUNTRY','REGION','CITY')),  -- [MC-0161] → A.65.04
    center_lat      NUMERIC(10,7),
    center_lon      NUMERIC(10,7),
    radius_km       NUMERIC(8,3)  CHECK (radius_km > 0),
    geojson         JSONB,                  -- para tipos POLYGON/COUNTRY/REGION
    action_outside  TEXT    NOT NULL DEFAULT 'DENY'  CHECK (action_outside IN ('DENY','STEP_UP','LOG','NOTIFY')),  -- [MC-0160] → A.65.04
    action_inside   TEXT    NOT NULL DEFAULT 'ALLOW' CHECK (action_inside  IN ('ALLOW','STEP_UP','LOG','NOTIFY')),  -- [MC-0159] → A.65.04
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
    location_source TEXT    NOT NULL CHECK (location_source IN ('GPS','WIFI','IP_GEOIP','CELL','MANUAL','BEACON')),  -- [MC-0162] → A.65.04
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
    apply_to              TEXT    NOT NULL DEFAULT 'ALL' CHECK (apply_to IN ('ALL','DATA_RESIDENCY','AUTH_ONLY','STORAGE')),  -- [MC-0157] → A.65.04
    violation_action      TEXT    NOT NULL DEFAULT 'DENY' CHECK (violation_action IN ('DENY','LOG','NOTIFY','QUARANTINE')),  -- [MC-0158] → A.65.04
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
    delegation_type  TEXT    NOT NULL DEFAULT 'IMPERSONATION' CHECK (delegation_type IN ('IMPERSONATION','AGENT','PROXY','TOKEN_EXCHANGE')),  -- [MC-0175] → A.65.04
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
    restriction_type TEXT    NOT NULL CHECK (restriction_type IN ('SCOPE_LIMIT','IP_WHITELIST','HOURS_ONLY','RESOURCE_LIMIT','APPROVAL_REQUIRED')),  -- [MC-0177] → A.65.04
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
    outcome     TEXT    NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR')),  -- [MC-0178] → A.65.04
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
    status                TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED')),  -- [MC-0176] → A.65.04
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
    expiration_action    TEXT    NOT NULL DEFAULT 'ARCHIVE' CHECK (expiration_action IN ('DELETE','ARCHIVE','ANONYMIZE','KEEP')),  -- [MC-0182] → A.65.04
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
    protocol_type TEXT    NOT NULL CHECK (protocol_type IN ('SYSLOG_UDP','SYSLOG_TCP','SYSLOG_TLS','HTTP_WEBHOOK','KAFKA','ELASTIC')),  -- [MC-0184] → A.65.04
    endpoint      TEXT    NOT NULL,
    port          INTEGER CHECK (port BETWEEN 1 AND 65535),
    tls_enabled   BOOLEAN NOT NULL DEFAULT false,
    log_format    TEXT    NOT NULL DEFAULT 'CEF' CHECK (log_format IN ('CEF','LEEF','JSON','SYSLOG_RFC5424','WAZUH')),  -- [MC-0183] → A.65.04
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
    domain_code TEXT    NOT NULL CHECK (domain_code IN ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','D10','D11','D12','D13','D14','D15','D98','D99')),  -- [MC-0179] → A.65.04
    event_type  TEXT    NOT NULL,
    subject_id  UUID,
    subject_type TEXT   CHECK (subject_type IN ('USER','ENTITY','NHI','SYSTEM')),  -- [MC-0181] → A.65.04
    action      TEXT    NOT NULL,
    resource    TEXT,
    outcome     TEXT    NOT NULL CHECK (outcome IN ('PERMIT','DENY','ERROR','PARTIAL')),  -- [MC-0180] → A.65.04
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
    source_event_type        TEXT    NOT NULL CHECK (source_event_type IN ('PRIVILEGE_GRANT','AUDIT_BATCH','DIGITAL_SIGNATURE','VC_ISSUED','SOD_VIOLATION')),  -- [MC-0185] → A.65.04
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
    tx_type      TEXT    NOT NULL CHECK (tx_type IN ('SETTLE','FREEZE','UNFREEZE','REVERT','DEPLOY','CALL')),  -- [MC-0188] → A.65.04
    from_address TEXT    NOT NULL,
    to_address   TEXT,
    value_wei    NUMERIC(30,0),
    gas_used     BIGINT,
    status       TEXT    NOT NULL CHECK (status IN ('PENDING','CONFIRMED','FAILED','REVERTED')),  -- [MC-0187] → A.65.04
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
    chain             TEXT    NOT NULL DEFAULT 'BESU_QBFT' CHECK (chain IN ('BESU_QBFT','ARBITRUM')),  -- [MC-0189] → A.65.04
    address           TEXT    NOT NULL UNIQUE,
    vault_key_path    TEXT    NOT NULL,   -- clave privada NUNCA en BD — siempre en Vault
    hd_path           TEXT,              -- BIP-44 derivation path
    balance_wei       NUMERIC(30,0) NOT NULL DEFAULT 0,
    balance_updated_at TIMESTAMPTZ,
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','DECOMMISSIONED')),  -- [MC-0190] → A.65.04
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
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SYNCING','OFFLINE','DECOMMISSIONED')),  -- [MC-0186] → A.65.04
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
    document_type      TEXT    NOT NULL CHECK (document_type IN ('PDF','XML','JSON','INVOICE_SIN','VC','JWT','CONTRACT')),  -- [MC-0193] → A.65.04
    signature_format   TEXT    NOT NULL DEFAULT 'PADES_B' CHECK (signature_format IN ('PADES_B','PADES_T','PADES_LT','PADES_LTA','CADES_B','XADES_B','JADES')),  -- [MC-0195] → A.65.04
    engine             TEXT    NOT NULL CHECK (engine IN ('INTERNAL_ED25519','EXTERNAL_ADSIB','DUAL')),  -- [MC-0194] → A.65.04
    document_hash      TEXT    NOT NULL,   -- SHA-256 del documento
    vault_key_path     TEXT,              -- ruta en Vault para motor interno
    cert_id            UUID    REFERENCES bauth.sig_certificate(cert_id),
    status             TEXT    NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SIGNING','SIGNED','FAILED','CANCELLED')),  -- [MC-0196] → A.65.04
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
    ca_type            TEXT    NOT NULL CHECK (ca_type IN ('ROOT_CA','INTERMEDIATE_CA','ISSUING_CA','ADSIB','VAULT_PKI')),  -- [MC-0191] → A.65.04
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
    outcome        TEXT    NOT NULL CHECK (outcome IN ('VALID','INVALID','EXPIRED','REVOKED','UNKNOWN','ERROR')),  -- [MC-0200] → A.65.04
    cert_status    TEXT    CHECK (cert_status IN ('VALID','REVOKED','EXPIRED','UNKNOWN')),  -- [MC-0199] → A.65.04
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
    status             TEXT    NOT NULL CHECK (status IN ('GOOD','REVOKED','UNKNOWN')),  -- [MC-0198] → A.65.04
    this_update        TIMESTAMPTZ NOT NULL,
    next_update        TIMESTAMPTZ NOT NULL,
    revoked_at         TIMESTAMPTZ,
    revocation_reason  TEXT,
    check_source       TEXT    NOT NULL CHECK (check_source IN ('OCSP','CRL','VAULT','MANUAL')),  -- [MC-0197] → A.65.04
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
    status            TEXT    NOT NULL DEFAULT 'LINKED' CHECK (status IN ('LINKED','SUSPENDED','REVOKED','PENDING')),  -- [MC-0192] → A.65.04
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
    storage_type      TEXT    NOT NULL DEFAULT 'MINIO' CHECK (storage_type IN ('MINIO','S3','LOCAL','NFS')),  -- [MC-0212] → A.65.04
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
    nhi_type        TEXT    NOT NULL CHECK (nhi_type IN ('SERVICE_ACCOUNT','CI_CD','DAEMON','BOT','AGENT_IA','API_KEY')),  -- [MC-0214] → A.65.04
    rotation_days   INTEGER NOT NULL CHECK (rotation_days BETWEEN 1 AND 365),
    rotate_on_use   BOOLEAN NOT NULL DEFAULT false,  -- ON_USE pattern para CI/CD
    pre_notice_days INTEGER NOT NULL DEFAULT 7,
    auto_rotate     BOOLEAN NOT NULL DEFAULT true,
    fail_action     TEXT    NOT NULL DEFAULT 'NOTIFY' CHECK (fail_action IN ('NOTIFY','SUSPEND_NHI','ALERT_ADMIN')),  -- [MC-0213] → A.65.04
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
    svid_type        TEXT    NOT NULL DEFAULT 'X509' CHECK (svid_type IN ('X509','JWT')),  -- [MC-0216] → A.65.04
    trust_domain     TEXT    NOT NULL,
    cert_fingerprint TEXT,
    serial_number    TEXT,
    issued_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at       TIMESTAMPTZ NOT NULL,
    rotated_at       TIMESTAMPTZ,
    vault_path       TEXT    NOT NULL,           -- cert SVID en Vault — NUNCA en BD
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ROTATED','REVOKED','EXPIRED')),  -- [MC-0215] → A.65.04
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
    category         TEXT    NOT NULL CHECK (category IN ('IDENTITY','CONTACT','LEGAL','BIOMETRIC','FINANCIAL','SYSTEM','CUSTOM')),  -- [MC-0279] → A.65.04
    data_type        TEXT    NOT NULL CHECK (data_type IN ('TEXT','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','JSON','BINARY','UUID')),  -- [MC-0281] → A.65.04
    mutability       TEXT    NOT NULL DEFAULT 'READ_WRITE' CHECK (mutability IN ('READ_ONLY','READ_WRITE','WRITE_ONCE')),  -- [MC-0282] → A.65.04
    returned         TEXT    NOT NULL DEFAULT 'DEFAULT' CHECK (returned IN ('ALWAYS','DEFAULT','NEVER','REQUEST')),
    required         BOOLEAN NOT NULL DEFAULT false,
    multi_valued     BOOLEAN NOT NULL DEFAULT false,
    min_ial          INTEGER NOT NULL DEFAULT 1 CHECK (min_ial BETWEEN 1 AND 3),
    source           TEXT    NOT NULL DEFAULT 'USER' CHECK (source IN ('USER','SYSTEM','PROOFING','IMPORT','DERIVED')),  -- [MC-0283] → A.65.04
    classification   TEXT    NOT NULL DEFAULT 'INTERNAL' CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','SECRET')),  -- [MC-0280] → A.65.04
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

-- ===========================================================================
-- SECCIÓN 19: DOCUMENTACIÓN ESTRATIFICADA — COMMENT ON TABLE
-- Estándar 6 elementos (§3.1 PROPUESTA-DOCUMENTACION-ESTRATIFICADA.md):
--   [1] ÁREA | Propósito  [2] Fuente:  [3] Administración:
--   [4] WORM: sí/no  [5] Particionada: sí/no  [6] Estándar: ... T-NNN
-- Estado: [DOC:REVIEW] — escrito en SQL; pendiente verificación en SBOSDB_copia
-- ===========================================================================

-- ── D99 ADMIN GLOBAL ────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_admin IS
'META-REGISTRO (D99) | Registro de administradores globales del sistema con AAL3 obligatorio y control granular de capacidades (super, seguridad, auditoría, soporte).
Fuente: seed inicial SUPER_ADMIN; altas posteriores vía RPC bauth.admin.create con HITL y doble firma por SUPER_ADMIN activo.
Administración: solo SUPER_ADMIN puede otorgar/revocar; cambios requieren aprobación dual y ctx_id; revisión trimestral obligatoria según ISO 27001 A.8.2; máximo 5 admins activos por tenant.
WORM: no — status y last_auth_at se actualizan; revocaciones quedan en idn_audit_event_log.
Particionada: no.
Estándar: ISO 27001 A.8.2, NIST AC-2(7), NIST AC-6(5), RFC 9449, OWASP ASVS 5.0 §2.2. T-510.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_crypto_params IS
'META-REGISTRO (D99) | Catálogo global de algoritmos criptográficos con estado de aprobación, equivalente del NIST CAVP para el ecosistema SBOS — define qué algoritmos están aprobados, deprecados o prohibidos.
Fuente: seed de despliegue con algoritmos NIST/FIPS vigentes; actualizaciones solo vía migración DDL con HITL cuando NIST publica nuevas directrices (FIPS 203/204/205 PQC agosto 2024).
Administración: tabla de referencia inmutable en producción — ningún código de aplicación modifica estas filas directamente; cambios de estado requieren migración explícita y revisión de seguridad; algoritmos PROHIBITED causan DENY inmediato.
WORM: no (actualizaciones de estado de algoritmos son necesarias al cambiar normativa).
Particionada: no.
Estándar: NIST SP 800-131A R2, FIPS 140-3, FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), FIPS 205 (SLH-DSA), NIST SP 800-227. T-513.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_notification IS
'META-REGISTRO (D99) | Cola de notificaciones de sistema dirigidas a administradores globales o tenants: alertas de seguridad, vencimientos de certificados, avisos de compliance y alertas de capacidad.
Fuente: daemons bAuth/bos y jobs crontab insertan al detectar condiciones de alerta; RPC bauth.notify.create permite inserción manual con privilegio SECURITY_ADMIN.
Administración: registros se marcan is_read=true tras lectura; expirados depurados por job diario; los de severity=CRITICAL se conservan 30 días post-lectura incluso si expirados.
WORM: no.
Particionada: no.
Estándar: ISO 27001 A.6.8, NIST IR-6 (Incident Response Reporting), NIST AU-6. T-511.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_hitl_exception IS
'META-REGISTRO (D99) | Registro HITL de excepciones a políticas prohibidas (algoritmos deprecados, acceso de emergencia, downgrades de cripto). Toda excepción requiere justificación ≥100 chars y aprobador SECURITY_ADMIN con AAL3.
Fuente: solicitud humana vía RPC bauth.hitl.request; el aprobador responde vía RPC bauth.hitl.approve con AAL3 obligatorio.
Administración: excepciones aprobadas se revisan automáticamente en review_at (valid_until - 7 días); vencidas cambian a EXPIRED por job; ninguna excepción se elimina (registro histórico permanente).
WORM: no (cambios de estado necesarios para la gobernanza del ciclo de vida).
Particionada: no.
Estándar: NIST SP 800-53 CA-3, ISO 27001 A.5.31, NIST AI RMF 1.0 §3.6. T-512.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_compliance_control IS
'META-REGISTRO (D99) | Mapa de controles de cumplimiento normativo activos: ISO 27001, SOX, GDPR, PCI DSS, NIST — permite auditorías de gap y generación de evidencia exportable para auditores externos.
Fuente: seed inicial con controles del stack tecnológico; actualización manual por AUDIT_ADMIN tras cada auditoría externa o cambio normativo; status=GAP activa alerta automática.
Administración: revisión anual obligatoria (next_review_at); el propietario de cada control es un idn_global_admin activo; el campo evidence_location apunta a artefactos verificables.
WORM: no.
Particionada: no.
Estándar: ISO 27001:2022 A.5.35-36, SOX §302/§404, GDPR Art. 24, PCI DSS 4.0 §12.3. T-514.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_global_sbom IS
'META-REGISTRO (D99) | Software Bill of Materials — inventario de componentes del ecosistema SBOS con estado de vulnerabilidades CVE y nivel de riesgo; requisito EU Cyber Resilience Act y NTIA SBOM 2021.
Fuente: pipeline CI/CD actualiza vía RPC tras cada build; escaneos de seguridad semanales insertan/actualizan CVEs detectados con syft/grype.
Administración: job semanal de seguridad actualiza last_scanned_at y risk_level; componentes con risk_level=CRITICAL generan notificación idn_global_notification automática y bloquean el despliegue.
WORM: no.
Particionada: no.
Estándar: NTIA SBOM 2021, EU Cyber Resilience Act (CRA) Art. 13, NIST SSDF SP 800-218. T-515.';

-- ── D07 RED / ZTA ────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_connection_policy IS
'DOMINIOS CONTROL (D07) | Política de conexión TLS/mTLS/DPoP/PKCE por tenant — define versión mínima TLS, rangos IP permitidos/bloqueados, cipher suites y rate limit para conexiones entrantes al plano de identidad.
Fuente: creada por SECURITY_ADMIN del tenant vía RPC bauth.network.policy.create; seed con política restrictiva por defecto (TLS 1.3, PKCE obligatorio) para cada nuevo tenant.
Administración: políticas ACTIVE aplicadas en Kong PEP; cambios requieren ctx_id y recargan caché de Kong en <30s; políticas DRAFT no se aplican; solo una política ACTIVE por tenant.
WORM: no.
Particionada: no.
Estándar: RFC 8705 (mTLS), NIST SP 800-52 R2 (TLS), RFC 9449 (DPoP), FAPI 2.0 §5. T-195.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_dpop_binding IS
'DOMINIOS CONTROL (D07) | Bindings DPoP sender-constrained — registra cada proof de posesión de clave pública (JWK thumbprint) vinculado a un access token, haciendo el token no-transferible a otro cliente.
Fuente: insertado por el motor de emisión de tokens en bAuth cada vez que el cliente presenta un DPoP proof válido (RFC 9449 §4); nunca actualizado — INSERT-only por diseño.
Administración: tabla WORM; bindings usados (is_used=true) se archivan por job diario; los expirados con is_used=false se eliminan tras 24h; el JTI es único globalmente (constraint).
WORM: sí — un binding de un solo uso no puede modificarse; hacerlo permitiría ataques de replay.
Particionada: no.
Estándar: RFC 9449 §4 (DPoP), FAPI 2.0 §5.3.2, OWASP ASVS 5.0 §13.2.5. T-196.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_rate_policy IS
'DOMINIOS CONTROL (D07) | Políticas de rate limiting por scope (global/tenant/cliente/usuario/IP) aplicadas en Kong PEP — define ventana deslizante, burst y acción al exceder el límite (THROTTLE, BLOCK, NOTIFY).
Fuente: creada por SECURITY_ADMIN vía RPC bauth.network.rate.create; seed con políticas globales conservadoras aplicables a todos los tenants.
Administración: políticas ACTIVE leídas por Kong al iniciar; cambios requieren recarga en Kong; endpoint_pattern acepta glob patterns; el scope IP aplica por hash de IP (GDPR).
WORM: no.
Particionada: no.
Estándar: OWASP API Security 2023 API6 (Unrestricted Resource Consumption), NIST SI-10, RFC 6585. T-197.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_posture_policy IS
'DOMINIOS CONTROL (D07) | Política de postura de dispositivo Zero Trust — define si el dispositivo debe estar gestionado (MDM), su score de riesgo máximo permitido, y si se permite BYOD antes de autorizar una sesión.
Fuente: creada por SECURITY_ADMIN del tenant; evaluada por el motor PDP de bAuth en cada solicitud de sesión; una política por tenant (constraint UNIQUE).
Administración: la postura se re-evalúa tras posture_ttl_minutes; dispositivos que no cumplen reciben la acción definida (DENY, STEP_UP, CHALLENGE); DRAFT no se evalúa.
WORM: no.
Particionada: no.
Estándar: NIST SP 800-207 §3.3 (ZTA device trust), NIST SP 800-124 R2 (MDM), CIS Controls v8 §4. T-198.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_segment IS
'DOMINIOS CONTROL (D07) | Catálogo de segmentos de red con nivel de confianza ZTA — mapea rangos CIDR a zonas (DMZ, interna, confiable, aislada, cuarentena) para tomar decisiones de acceso basadas en el origen.
Fuente: configurado por SECURITY_ADMIN del tenant al definir la topología de red; actualizado cuando la arquitectura de red cambia o se añaden nuevos segmentos.
Administración: segmentos TRUSTED requieren mTLS; los de QUARANTINE bloquean todas las operaciones excepto remediation; revisión semestral del mapa de segmentos recomendada.
WORM: no.
Particionada: no.
Estándar: NIST SP 800-207 §2.1 (ZTA), ISO 27001 A.8.22 (Segregación de redes). T-199.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_dlp_policy IS
'DOMINIOS CONTROL (D07) | Política de Data Loss Prevention — define reglas de inspección de payload y headers para detectar patrones sensibles (NIT, tarjetas, datos biométricos) y tomar acción (LOG, BLOCK, REDACT, QUARANTINE).
Fuente: creada por SECURITY_ADMIN del tenant; los patrones de sensitive_patterns son expresiones regulares aplicadas por Kong PEP en tránsito.
Administración: políticas ACTIVE leídas por Kong; REDACT ofusca en tránsito sin almacenar; QUARANTINE retiene la request para revisión manual por AUDIT_ADMIN.
WORM: no.
Particionada: no.
Estándar: NIST SP 800-53 R5 SI-3/SI-12, ISO 27001 A.8.12, GDPR Art. 25. T-200.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_network_context_propagation IS
'DOMINIOS CONTROL (D07) | Configuración de propagación del ctx_id entre servicios SBOS — define el formato de header (W3C traceparent, SBOS custom, OTEL baggage) y los campos incluidos para cada par origen→destino.
Fuente: configurado en el despliegue por bos al instalar un nuevo servicio; seed con configuraciones estándar W3C para cada par de daemons del ecosistema.
Administración: leído en el arranque de cada daemon; cambios requieren reinicio del servicio destino; el campo encrypt_payload está reservado para datos sensibles en tránsito entre servicios.
WORM: no.
Particionada: no.
Estándar: SBOS-049 (Context Plane), W3C Trace Context v2, OTEL Baggage v1.0, RFC 9232. T-201.';

-- ── D09 CREDENCIALES ─────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_credential_password_history IS
'AUTENTICACIÓN | Historial inmutable de hashes de contraseñas anteriores por usuario — permite verificar que una nueva contraseña no repite las últimas N (NIST 800-63B-4 §5.1.1.2: mínimo 5 anteriores).
Fuente: insertado automáticamente por el motor de cambio de contraseña en bAuth cada vez que el usuario cambia su contraseña con éxito; nunca actualizado.
Administración: tabla WORM — solo INSERT; depuración trimestral elimina registros más antiguos que la política del tenant (por defecto 12 meses), conservando siempre los últimos 5 por usuario.
WORM: sí — el historial de contraseñas es evidencia de cumplimiento NIST; modificarlo falsificaría el registro de reutilización.
Particionada: no.
Estándar: NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS 5.0 §2.1.7. T-202.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_credential_token_issued IS
'SESIÓN | Registro de todos los tokens emitidos por bAuth (ACCESS, REFRESH, ID, EXCHANGE, DEVICE) con ciclo de vida completo, binding DPoP y nivel de aseguramiento (LoA 1-3).
Fuente: insertado por el motor de emisión de tokens en bAuth en cada grant exitoso; la revocación actualiza revoked_at y revocation_reason (no se elimina el registro).
Administración: particionada mensualmente para retención eficiente; particiones antiguas archivadas/eliminadas según idn_audit_retention_policy; el jti debe verificarse aquí antes de aceptar cualquier token.
WORM: no (revocación requiere UPDATE de revoked_at).
Particionada: sí — por issued_at, mensual; nueva partición creada por job al inicio de cada mes.
Estándar: RFC 6749 §4 (Access Token), RFC 9449 (DPoP binding), NIST SP 800-63B-4 §7.1. T-363.';

-- ── D02 ACCESO FÍSICO ────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_credential IS
'DOMINIOS CONTROL (D02) | Credenciales físicas de acceso (RFID, PIV, biométricas, NFC) vinculadas a identidades digitales — es el puente entre el mundo físico y el plano IAM de bAuth.
Fuente: emitida por SECURITY_ADMIN del tenant vía RPC bauth.physical.credential.issue; requiere entity_id existente con verificación IAL2+ completada.
Administración: credenciales ACTIVE permiten acceso en allowed_location_ids; revocación efectiva en <5 minutos por invalidación de caché en lectores OSDP; EXPIRED rechazadas automáticamente.
WORM: no (ciclo de vida: ACTIVE→SUSPENDED→REVOKED).
Particionada: no.
Estándar: NIST SP 800-116 R2, FIPS 201-3 (PIV), ISO 24727-3, SIA OSDP v2.2.2. T-228.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_location IS
'DOMINIOS CONTROL (D02) | Catálogo jerárquico de instalaciones físicas con nivel de seguridad (1-5) — soporta árbol edificio→piso→sala→datacenter para modelar la topología física de la organización.
Fuente: configurado por SECURITY_ADMIN del tenant al definir la planta física; actualizado cuando la topología cambia (nuevas sedes, remodelaciones, cambios de nivel de seguridad).
Administración: árbol construido con parent_id (auto-referencia); max_capacity gestiona anti-passback; locations MAINTENANCE rechazan nuevas entradas pero permiten salida.
WORM: no.
Particionada: no.
Estándar: ISO 27001 A.7.1 (Perímetros de seguridad física), IEC 60839-11-5. T-220.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_reader IS
'DOMINIOS CONTROL (D02) | Registro de lectores de acceso físico con protocolo (OSDP v2, Wiegand), dirección y estado de conectividad — permite detectar lectores offline y gestionar firmware remotamente.
Fuente: registrado por el instalador vía RPC bauth.physical.reader.register al integrar el hardware; el lector envía heartbeats periódicos actualizando last_heartbeat e is_online.
Administración: lectores OFFLINE generan alerta en idn_global_notification; firmware_version actualizado tras cada actualización OTA; readers MAINTENANCE aceptan heartbeats pero rechazan credenciales.
WORM: no.
Particionada: no.
Estándar: SIA OSDP v2.2.2 §6, IEC 60839-11-5 §6, ISO 27001 A.7.2. T-221.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_presence IS
'DOMINIOS CONTROL (D02) | Estado de presencia actual (dentro/fuera) de cada entidad por instalación — tabla mutable que se actualiza en cada evento de entrada/salida para soportar anti-passback y control de aforo.
Fuente: actualizada automáticamente por el motor de control de acceso en bAuth al procesar eventos de idn_physical_access_event_log; nunca insertada directamente por la aplicación cliente.
Administración: el trigger garantiza no-presencias-fantasma; max_capacity de la location se comprueba antes de registrar ENTRY; emergencias activan override de anti-passback.
WORM: no (estado mutable por diseño del control de aforo).
Particionada: no.
Estándar: NIST SP 800-116 R2 §4.2 (control de aforo), IEC 60839-11-1 §5.6. T-222.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_event_log IS
'DOMINIOS CONTROL (D02) | Log forense de todos los eventos de acceso físico (ENTRY, EXIT, DENIED, ALARM, FORCED, ANTIPASSBACK) con resultado y ctx_id para trazabilidad IAM completa.
Fuente: insertado por el motor de control de acceso en bAuth al procesar cada señal de un lector OSDP; el lector envía el evento y bAuth lo registra con contexto de identidad.
Administración: particionada mensualmente; particiones antiguas archivadas por job de retención; entradas FORCED y ALARM generan alerta de seguridad inmediata en idn_global_notification.
WORM: no.
Particionada: sí — por logged_at, mensual; nueva partición al inicio de cada mes.
Estándar: IEC 60839-11-1 §6.4, ISO 27001 A.7.2, NIST SP 800-116 R2 §4. T-223.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_visit IS
'DOMINIOS CONTROL (D02) | Registro de visitas de personas externas — vincula visitante a anfitrión, instalación y rango horario; datos post-visita se anonimizan a los 30 días cumpliendo GDPR minimización.
Fuente: creada por el anfitrión (host_id) vía RPC bauth.physical.visit.schedule; actual_entry_at/actual_exit_at actualizados automáticamente al pasar por los lectores con el badge_number temporal.
Administración: visitas COMPLETED se anonimizan a los 30 días post-salida (GDPR Art. 5(1)(c)); badge_number es temporal e invalido al salir; NO_SHOW se registra si scheduled_until pasa sin entrada.
WORM: no.
Particionada: no.
Estándar: ISO 27001 A.7.2, GDPR Art. 5(1)(c) (minimización), NIST SP 800-116 R2. T-224.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_emergency IS
'DOMINIOS CONTROL (D02) | Registro de activaciones de modo de emergencia física (incendio, intrusión, médica, evacuación) que cambian el modo de operación de puertas afectadas (FAIL_SAFE/FAIL_SECURE).
Fuente: activada por personal autorizado vía RPC bauth.physical.emergency.activate o por sensor automático integrado; desactivación requiere confirmación de personal de seguridad con AAL2.
Administración: mientras emergency activa (deactivated_at IS NULL), las puertas operan en door_mode definido; FAIL_SAFE abre puertas (evacuación), FAIL_SECURE las cierra (intrusión).
WORM: no (se actualiza al desactivar).
Particionada: no.
Estándar: NIST SP 800-116 R2 §5.4, NFPA 101:2021 §7.7. T-225.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_physical_access_evacuation IS
'DOMINIOS CONTROL (D02) | Registro de mustering (confirmación de evacuación) — anota si cada entidad fue confirmada en el punto de reunión; es evidencia forense de rendición de cuentas en emergencias.
Fuente: insertado automáticamente por bAuth al activar una emergency_id para cada entidad con presencia activa en la instalación; actualizado cuando el personal de seguridad confirma físicamente la presencia.
Administración: tabla de evidencia forense — ningún registro se elimina; entidades no confirmadas tras 30 min generan alerta CRITICAL en idn_global_notification.
WORM: sí — evidencia de mustering de emergencia; nunca se modifica ni elimina (trazabilidad forense y responsabilidad legal).
Particionada: no.
Estándar: ISO 27001 A.7.4, NFPA 101:2021 §7.7, NIST SP 800-116 R2 §5.4. T-226.';

-- ── D03 FINANCIERO ────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_limit IS
'DOMINIOS CONTROL (D03) | Límites transaccionales por actor/rol/cliente — define montos máximos, límites diarios/mensuales y si se requiere doble aprobación para operaciones financieras autorizadas por bAuth.
Fuente: creado por FINANCE_ADMIN del tenant vía RPC bauth.financial.limit.create; revisado y actualizado anualmente o al cambiar políticas de control interno.
Administración: evaluado por el PDP de bAuth en cada solicitud de operación financiera; si amount excede dual_approval_threshold, se crea automáticamente una idn_financial_approval; límites DRAFT no se evalúan.
WORM: no.
Particionada: no.
Estándar: PCI DSS 4.0 Req 8.2, NIST AC-2(6), COSO 2013 CC6.3. T-240.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_approval IS
'DOMINIOS CONTROL (D03) | Solicitud de aprobación dual para operaciones financieras que superan el límite configurado — implementa quorum de aprobadores (≥2) con ventana de expiración de 24h.
Fuente: creada automáticamente por bAuth cuando una operación supera dual_approval_threshold; también vía RPC bauth.financial.approval.create para operaciones que requieren aprobación explícita.
Administración: quorum verificado contra idn_financial_approval_vote; al alcanzar required_quorum el status pasa a APPROVED automáticamente; job depura EXPIRED sin votos suficientes.
WORM: no.
Particionada: no.
Estándar: SOX §302/§404, COSO 2013 CC6.3, ISO 37001 §8.4 (Anti-bribery). T-241.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_approval_vote IS
'DOMINIOS CONTROL (D03) | Votos individuales de los aprobadores en una solicitud de aprobación dual — cada fila es la decisión de un aprobador con su razón y timestamp; constraint UNIQUE (approval_id, approver_id) previene doble voto.
Fuente: insertado por cada aprobador vía RPC bauth.financial.vote.submit con AAL2 mínimo; un aprobador no puede votar su propia solicitud (SoD aplicada por el motor).
Administración: al completarse el quorum, bAuth cierra la idn_financial_approval automáticamente; votos ABSTAIN pueden reconsiderarse antes del cierre de la solicitud.
WORM: no.
Particionada: no.
Estándar: SOX §302, COSO 2013 CC6.3, NIST AC-5 (Separation of Duties). T-248.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_sod_rule IS
'DOMINIOS CONTROL (D03) | Reglas estáticas de Separación de Deberes financiero — define pares de operaciones que un mismo actor no puede ejecutar (MUTUALLY_EXCLUSIVE) o que requieren secuencia u aprobación adicional.
Fuente: configurado por AUDIT_ADMIN del tenant; reglas mantenidas en código fuente y cargadas vía seed para asegurar consistencia entre entornos y auditoría reproducible.
Administración: evaluado por el motor SoD de bAuth antes de cualquier operación financiera; conflictos generan DENY con código SoD en el audit log con trazabilidad completa.
WORM: no.
Particionada: no.
Estándar: NIST AC-5 (Separation of Duties), SOX §404, COSO 2013 CC6.3, ISACA COBIT 2019. T-242.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_invoice_auth IS
'DOMINIOS CONTROL (D03) | Registro de autorizaciones de facturas electrónicas SIN (Bolivia) — vincula el CUF/CUFD con la operación de firma digital correspondiente para trazabilidad fiscal completa.
Fuente: creado por el módulo de facturación integrado vía RPC bauth.financial.invoice.authorize al emitir una factura al SIN; signature_op_id vincula con sig_operation_log.
Administración: los CUF son únicos por régimen/emisor/número; status CONTINGENCY activa modo offline del SIN; facturas REJECTED deben anularse con nueva emisión; retención 10 años según Ley 2492.
WORM: no.
Particionada: no.
Estándar: SIN RND 102100000011, Ley 164 Bolivia Art. 9-11, DS 4583 Bolivia. T-243.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_report IS
'DOMINIOS CONTROL (D03) | Registro de reportes financieros de control (SOX 302/404, PCI DSS, informes de incidentes) con hash SHA-256 del archivo para verificación de integridad.
Fuente: generado por el módulo de reportes de bAuth o importado desde sistemas externos vía RPC bauth.financial.report.register; hash calculado al momento de importar.
Administración: reportes APPROVED son inmutables post-aprobación; los ARCHIVED se conservan según SOX §802 (7 años mínimo); un reporte no se modifica — se crea una nueva versión.
WORM: no (ciclo DRAFT→REVIEW→APPROVED→PUBLISHED→ARCHIVED es necesario).
Particionada: no.
Estándar: SOX §302/§404, IFRS 7, PCI DSS 4.0 §12.3, ISO 19600. T-244.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_fraud_alert IS
'DOMINIOS CONTROL (D03) | Alertas de anomalía financiera detectadas por el motor de análisis de bAuth (montos inusuales, patrones temporales, violaciones SoD) que requieren investigación humana asignada.
Fuente: generado automáticamente por el motor de detección de fraude al analizar transacciones; también por el motor SoD al detectar conflictos no resueltos en idn_financial_sod_rule.
Administración: alertas CRITICAL generan notificación inmediata; investigador asignado cierra la alerta con result; sin investigar tras 72h escala automáticamente a nivel superior.
WORM: no (se actualiza durante la investigación).
Particionada: no.
Estándar: PCI DSS 4.0 Req 10.7, ISO 37001 §8.6, NIST SP 800-53 SI-4. T-245.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_reconciliation IS
'DOMINIOS CONTROL (D03) | Registro de conciliaciones financieras periódicas entre dos sistemas — documenta discrepancias contables detectadas y su resolución para cumplimiento SOX y auditoría interna.
Fuente: creado por el job de conciliación de bAuth (diaria/mensual/trimestral/anual) o manualmente por FINANCE_ADMIN vía RPC bauth.financial.reconcile.run.
Administración: diferencias > 0 cambian status a WITH_DIFFERENCES y generan alerta; status APPROVED valida que las diferencias fueron investigadas y justificadas por el responsable.
WORM: no.
Particionada: no.
Estándar: ISO 20022 §5, COSO 2013 CC6.6, SOX §404. T-246.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_financial_tpp_consent IS
'DOMINIOS CONTROL (D03) | Consentimientos a terceros proveedores de pago (TPP) para acceder a datos financieros del usuario — implementa flujo FAPI 2.0 con DPoP obligatorio y alcances granulares por operación.
Fuente: creado por el flujo de autorización OAuth 2.0 / FAPI 2.0 cuando el usuario consiente a una aplicación TPP desde el portal de identidad; dpop_required=true por defecto (no negociable).
Administración: consentimientos activos evaluados por el PDP antes de emitir tokens al TPP; expirados rechazados automáticamente; el usuario puede revocar en cualquier momento vía autogestión en el portal.
WORM: no.
Particionada: no.
Estándar: PSD2 Art. 98, FAPI 2.0 §5, RFC 9449 (DPoP), Open Banking UK §7. T-247.';

-- ── D04 TEMPORAL (GTRBAC) ────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_window IS
'DOMINIOS CONTROL (D04) | Ventanas de tiempo de acceso GTRBAC — define intervalos horarios en que un rol está activo, con soporte de días de semana y zona horaria, implementando control de acceso sensible al tiempo.
Fuente: creado por SECURITY_ADMIN del tenant vía RPC bauth.temporal.window.create; asociado a períodos, turnos y excepciones mediante tablas relacionadas.
Administración: evaluado por el evaluador temporal del PDP de bAuth en cada solicitud; zona horaria obligatoria (defecto: America/La_Paz); ventanas is_active=false no se evalúan.
WORM: no.
Particionada: no.
Estándar: GTRBAC §3.2 (Generalized Temporal RBAC), NIST AC-3(7), ISO 27001 A.5.18. T-260.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_period IS
'DOMINIOS CONTROL (D04) | Períodos de activación temporal de roles — vincula un actor a una ventana de tiempo y un role_id para un rango de fechas concreto, implementando acceso Just-In-Time (JIT).
Fuente: creado por SECURITY_ADMIN al asignar acceso temporal; auto_activate=true activa el rol automáticamente al entrar en el período sin intervención manual.
Administración: el job de activación/desactivación evalúa valid_from/valid_until periódicamente; períodos vencidos se conservan como histórico de acceso JIT para auditoría.
WORM: no.
Particionada: no.
Estándar: GTRBAC §4, NIST AC-3(7) (RBAC con tiempo), ISO 27001 A.5.18. T-261.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_calendar IS
'DOMINIOS CONTROL (D04) | Asociación entre ventanas de tiempo y calendarios bcalendar — permite que una ventana excluya automáticamente feriados nacionales o weekends del calendario fiscal.
Fuente: creado por SECURITY_ADMIN al vincular una ventana a un calendario; un calendario puede estar vinculado a múltiples ventanas.
Administración: el evaluador temporal de bAuth consulta bcalendar.cal_holiday al evaluar si el día actual es hábil; si exclude_holidays=true y hoy es feriado, la ventana no aplica.
WORM: no.
Particionada: no.
Estándar: GTRBAC §4.1 (calendarios de trabajo), ISO 8601:2019. T-262.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_shift IS
'DOMINIOS CONTROL (D04) | Catálogo de turnos de trabajo con tipo de rotación y duración — permite modelar guardias fijas, rotativas o flexibles vinculadas a ventanas de tiempo del módulo GTRBAC.
Fuente: configurado por HR_ADMIN del tenant al definir los turnos de la organización; usado como plantilla para asignaciones individuales en idn_temporal_shift_assignment.
Administración: turnos is_active=false no se evalúan; rotation_type GUARD es para seguridad física con cobertura 24h sin gaps; ROTATING incluye lógica de alternancia automática.
WORM: no.
Particionada: no.
Estándar: GTRBAC §5, NIST AC-2(2) (Temporary Access), ISO 27001 A.5.18. T-263.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_shift_assignment IS
'DOMINIOS CONTROL (D04) | Asignación de un turno concreto a un actor específico con rango de fechas de validez — materializa la asociación entre el horario corporativo y la identidad del empleado.
Fuente: creado por HR_ADMIN o SECURITY_ADMIN vía RPC bauth.temporal.shift.assign; el assigned_by debe tener privilegio de administración de turnos del tenant.
Administración: registros vencidos (valid_until < NOW()) no se evalúan por el PDP; histórico conservado para auditoría de asignaciones JIT; entity_id puede ser humano o NHI.
WORM: no.
Particionada: no.
Estándar: GTRBAC §5, NIST AC-2(2), ISO 27001 A.5.18. T-264.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_temporal_exception IS
'DOMINIOS CONTROL (D04) | Excepciones temporales aprobadas que modifican (extienden, reducen, bloquean o añaden guardia) la ventana de acceso normal de un actor — requieren justificación ≥20 chars y aprobador AAL2.
Fuente: creado por el actor o su supervisor vía RPC bauth.temporal.exception.request; el aprobador confirma vía RPC con AAL2 antes de que sea evaluada por el motor.
Administración: evaluadas como override sobre la ventana original; vencidas no se evalúan pero se conservan como histórico de decisiones de excepción de acceso.
WORM: no.
Particionada: no.
Estándar: NIST AC-17(1) (acceso remoto fuera de horario), ISO 27001 A.5.18, GTRBAC §6. T-265.';

-- ── D05 BIOMÉTRICO ────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_enrollment IS
'DOMINIOS CONTROL (D05) | Registro de enrolamientos biométricos por actor y modalidad — almacena la ruta Vault al template (NUNCA el template en BD), calidad y liveness de la muestra, y estado del enrolamiento.
Fuente: creado por el proceso de enrolamiento IAL2/IAL3 en bAuth; la muestra se captura, evalúa con el algoritmo de calidad, el template se almacena en Vault y solo la ruta queda aquí.
Administración: un actor puede tener múltiples enrolamientos por modalidad; solo status=ACTIVE es considerado por el PDP; revocación activa limpieza del template en Vault (confirmada en idn_biometric_revocation).
WORM: no (ciclo de vida: ACTIVE→SUSPENDED→REVOKED→EXPIRED).
Particionada: no.
Estándar: NIST SP 800-76-2 §4, ISO/IEC 30107-1:2023, ISO/IEC 24745:2022. T-280.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_verification_log IS
'DOMINIOS CONTROL (D05) | Log de verificaciones biométricas 1:1 (match contra template enrolado) con scores de match y liveness — permite análisis de tendencia y detección de ataques de presentación (PAD).
Fuente: insertado por el motor de verificación biométrica de bAuth en cada autenticación biométrica; la IP se anonimiza en ingesta (GDPR Art. 5(1)(c)); nunca se almacena el template.
Administración: particionada mensualmente; retención según idn_audit_retention_policy tipo BIOMETRIC (365 días + anonimización); scores NO_MATCH repetidos activan alerta PAD automática.
WORM: no.
Particionada: sí — por verified_at, mensual; nueva partición al inicio de cada mes.
Estándar: ISO/IEC 30107-3:2023, NIST SP 800-76-2 §5, GDPR Art. 5(1)(c). T-281.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_pad_policy IS
'DOMINIOS CONTROL (D05) | Política de detección de ataques de presentación (PAD) por modalidad — define umbral de liveness, número de intentos antes de bloqueo y acción ante fallo (DENY/STEP_UP/QUARANTINE).
Fuente: seed con políticas por defecto por modalidad; actualizable por SECURITY_ADMIN del tenant vía RPC bauth.biometric.pad.update; una política por tenant+modalidad (constraint UNIQUE).
Administración: evaluada en cada verificación biométrica; LEVEL_3 requiere algoritmo anti-spoofing certificado ISO/IEC 30107-3; QUARANTINE retiene request para análisis forense.
WORM: no.
Particionada: no.
Estándar: ISO/IEC 30107-3:2023 §5, FIDO2 §8.8 (Authenticator Attestation), NIST SP 800-76-2 §6. T-282.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_identification_log IS
'DOMINIOS CONTROL (D05) | Log de búsquedas biométricas 1:N (identificación — quién es esta persona) — separado del log de verificación 1:1 por mayor impacto de privacidad; uso restringido a roles IAL3.
Fuente: insertado por el motor de identificación de bAuth en flujos de acceso físico sin credencial o de investigación forense; uso restringido a personal de seguridad con privilegio explícito.
Administración: particionada; búsquedas 1:N tienen implicaciones GDPR mayores (dato biométrico = categoría especial Art. 9); resultado MULTIPLE_MATCH requiere resolución humana obligatoria.
WORM: no.
Particionada: sí — por searched_at, mensual.
Estándar: ISO/IEC 19794-2:2011 §6, GDPR Art. 9 (categoría especial), NIST SP 800-76-2. T-283.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_quality_policy IS
'DOMINIOS CONTROL (D05) | Política de calidad mínima de muestra biométrica por modalidad y tenant — define el umbral mínimo de calidad y máximo de intentos de captura antes de rechazar el enrolamiento.
Fuente: seed con valores mínimos del estándar por modalidad; el SECURITY_ADMIN del tenant puede elevar (no reducir) los umbrales vía RPC bauth.biometric.quality.update.
Administración: evaluada durante el enrolamiento y cada verificación; muestras bajo min_quality son rechazadas incluso si el match score es alto (defensa en profundidad).
WORM: no.
Particionada: no.
Estándar: ISO/IEC 29794-1:2024 §5, NIST SP 800-76-2 §3, ISO/IEC 30107-3:2023. T-284.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_biometric_revocation IS
'DOMINIOS CONTROL (D05) | Registro de revocaciones de templates biométricos con confirmación explícita del borrado en Vault — garantiza que el template (categoría especial GDPR Art. 9) se elimina físicamente al revocar.
Fuente: creado por el proceso de revocación de bAuth al revocar un enrolamiento; vault_wipe_confirmed se actualiza a true cuando Vault confirma el borrado del template.
Administración: sin vault_wipe_confirmed=true la revocación no está completa (riesgo GDPR Art. 17); job nocturno detecta revocaciones sin confirmación y las escala a SECURITY_ADMIN.
WORM: no (vault_wipe_confirmed y vault_wipe_at requieren actualización post-borrado en Vault).
Particionada: no.
Estándar: ISO/IEC 24745:2022 §6, GDPR Art. 17 (derecho al olvido), NIST SP 800-76-2 §6. T-285.';

-- ── D06 GEOESPACIAL ──────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_geofence IS
'DOMINIOS CONTROL (D06) | Geocercas de control de acceso — define zonas geográficas (círculo, polígono, país, región) con la acción a tomar según si el actor está dentro o fuera al hacer una solicitud.
Fuente: creado por SECURITY_ADMIN del tenant vía RPC bauth.geo.fence.create; el geojson se valida como RFC 7946 válido al insertar; estado DRAFT no se evalúa.
Administración: geocercas ACTIVE evaluadas por el PDP en cada solicitud de autenticación con contexto de ubicación; evaluación sincrónica <5ms; DISABLED suspende sin borrar.
WORM: no.
Particionada: no.
Estándar: RFC 7946 §3.1 (GeoJSON), OGC GeoSPARQL 1.1, NIST AC-3(11) (Location-based Access). T-300.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_location_log IS
'DOMINIOS CONTROL (D06) | Log de ubicaciones geoespaciales de actores durante sesiones autenticadas — la IP siempre se almacena anonimizada (ip_hash) cumpliendo GDPR Art. 5(1)(c) minimización de datos.
Fuente: insertado por el motor de sesión de bAuth cuando el cliente envía su ubicación GPS/WiFi/IP-GeoIP; también por el sistema de acceso físico al registrar presencia en instalación.
Administración: particionada mensualmente; retención 90 días para análisis de viaje imposible; anonimización completa a los 7 días post-retención; nunca se almacena la IP en claro.
WORM: no.
Particionada: sí — por captured_at, mensual.
Estándar: RFC 7946 §3, NIST AC-3(11), GDPR Art. 5(1)(c). T-301.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_velocity_policy IS
'DOMINIOS CONTROL (D06) | Política de detección de viaje imposible por tenant — define la velocidad máxima de desplazamiento geográfico permitida entre dos autenticaciones consecutivas (defecto 900 km/h para incluir vuelos).
Fuente: seed con política conservadora por defecto; configurable por SECURITY_ADMIN del tenant; exactamente una política por tenant (constraint UNIQUE).
Administración: evaluada por el motor geoespacial de bAuth entre cada par de ubicaciones consecutivas; violaciones generan idn_geospatial_velocity_event y aplican la acción definida.
WORM: no.
Particionada: no.
Estándar: NIST SI-4(13) (análisis de comportamiento), OWASP ASVS 5.0 §2.2.9. T-302.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_velocity_event IS
'DOMINIOS CONTROL (D06) | Eventos de viaje imposible detectados — registra casos donde la velocidad calculada entre dos ubicaciones del mismo actor supera el máximo configurado; evidencia forense de posible compromiso de credenciales.
Fuente: insertado automáticamente por el motor geoespacial de bAuth al detectar una violación; referencia los dos location_log.id (sin FK directa por ser tabla particionada).
Administración: eventos sin investigar tras 24h escalan a CRITICAL; el investigador marca is_investigated=true con el resultado determinado (falso positivo o compromiso real).
WORM: no (se actualiza durante investigación).
Particionada: no.
Estándar: NIST SI-4(13), OWASP ASVS 5.0 §2.2.9. T-303.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_data_residency IS
'DOMINIOS CONTROL (D06) | Política de soberanía y residencia de datos geográfica por tenant — define países permitidos/bloqueados para autenticación y procesamiento, cumpliendo GDPR transferencias internacionales y Ley 1174 Bolivia.
Fuente: configurado durante el onboarding del tenant; exactamente una política por tenant (constraint UNIQUE); cambios requieren HITL por impacto en usuarios en tránsito internacional.
Administración: evaluada por el PDP en cada solicitud; violaciones aplican violation_action; requires_sovereign_vpn fuerza el uso de la VPN soberana; exempt_entity_ids para usuarios exentos justificados.
WORM: no.
Particionada: no.
Estándar: GDPR Art. 44-49 (transferencias internacionales), Ley 1174 Bolivia, NIST SP 800-53 SA-9(5). T-304.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_geospatial_device_fleet IS
'DOMINIOS CONTROL (D06) | Flota de dispositivos móviles con trazabilidad geoespacial — vincula cada dispositivo a su última ubicación conocida y la geocerca asignada para logística y seguridad de activos físicos.
Fuente: registrado por el sistema MDM al inscribir un nuevo dispositivo; la ubicación se actualiza en cada heartbeat del agente de dispositivo instalado en el equipo.
Administración: dispositivos sin heartbeat en 48h se marcan INACTIVE automáticamente; inside_geofence recalculado en cada actualización de ubicación; usado por PAM para validar ubicación aprobada del operador.
WORM: no.
Particionada: no.
Estándar: ISO 6709:2022 (notación geográfica), NIST SP 800-124 R2 (MDM), NIST AC-3(11). T-305.';

-- ── D10 DELEGACIÓN ────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_grant IS
'DOMINIOS CONTROL (D10) | Delegaciones de identidad entre actores — permite que un actor (grantor) otorgue a otro (grantee) capacidad de actuar en su nombre mediante impersonación, agencia, proxy o intercambio de tokens con validez temporal.
Fuente: creado por el grantor vía RPC bauth.delegation.grant con AAL2; el sistema verifica SoD (grantee no puede recibir lo que el grantor no tiene); auto-prohibición de self-grant por CHECK constraint.
Administración: evaluada por el PDP en cada solicitud del grantee; revocación efectiva en <30s por invalidación de caché; grants vencidos se conservan como histórico de delegaciones para auditoría SOX.
WORM: no (status evoluciona durante el ciclo de vida).
Particionada: no.
Estándar: RFC 8693 §3 (Token Exchange), NIST AC-2(5), ANSI INCITS 359-2004 §4.5. T-415.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_renewal IS
'DOMINIOS CONTROL (D10) | Registro de renovaciones de delegaciones — documenta cada extensión de validez de un grant con el aprobador y la nueva fecha límite, respetando el máximo de renovaciones (max_renewals).
Fuente: creado por el proceso de renovación vía RPC bauth.delegation.renew, verificando que renewals_used < max_renewals antes de insertar; actualiza valid_until en idn_delegation_grant.
Administración: cada renovación incrementa renewals_used en el grant; grants con max_renewals=0 no pueden renovarse; el histórico de renovaciones es evidencia de uso extendido de delegaciones.
WORM: no.
Particionada: no.
Estándar: RFC 8693 §4.2 (Token Refresh Delegation), NIST AC-2(5). T-416.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_restriction IS
'DOMINIOS CONTROL (D10) | Restricciones adicionales sobre el alcance de una delegación — permite limitar IP permitidas, horas, recursos específicos o requerir aprobación adicional más allá del grant base.
Fuente: creadas opcionalmente por el grantor al crear el grant; los parámetros JSONB definen los valores concretos por tipo de restricción (ej: IP whitelist, ventana horaria, resource limit).
Administración: evaluadas por el PDP en cada uso del grant delegado; SCOPE_LIMIT restringe el subconjunto de scopes del grant original; APPROVAL_REQUIRED fuerza un flujo adicional de confirmación.
WORM: no.
Particionada: no.
Estándar: NIST AC-5 (SoD en delegaciones), ISO 27001 A.5.3, RFC 9396 (RAR). T-417.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_chain IS
'DOMINIOS CONTROL (D10) | Cadena de delegaciones transitivas — registra el árbol de re-delegaciones (hasta depth=5) para detectar y prevenir ciclos de delegación que crearían escaladas de privilegio.
Fuente: actualizado automáticamente por el motor de delegación de bAuth al crear un grant derivado de otro grant existente; root_grant_id apunta siempre al grant original de la cadena.
Administración: depth > 5 es rechazado por CHECK constraint; el motor verifica la cadena completa al evaluar un token delegado; útil en investigaciones forenses de uso transitivo de permisos.
WORM: no.
Particionada: no.
Estándar: RFC 8693 §2 (cadenas de delegación), ANSI INCITS 359-2004 §4.5. T-418.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_usage_log IS
'DOMINIOS CONTROL (D10) | Log WORM de uso de delegaciones activas — registra cada acción ejecutada por el grantee usando un grant delegado, con resultado PERMIT/DENY e IP anonimizada.
Fuente: insertado por el PDP de bAuth en cada evaluación de acceso que involucra un token delegado; la IP se anonimiza en ingesta cumpliendo GDPR.
Administración: tabla WORM particionada mensualmente; retención según política de auditoría; evidencia forense para demostrar uso apropiado de delegaciones en auditorías SOX y GDPR.
WORM: sí — el log de uso de delegaciones no puede modificarse; es evidencia forense del comportamiento del grantee.
Particionada: sí — por logged_at, mensual.
Estándar: ISO 27001 A.8.15, NIST AU-2, SOX §302. T-419.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_delegation_rar_request IS
'DOMINIOS CONTROL (D10) | Solicitudes de autorización enriquecida (Rich Authorization Request RFC 9396) — permite que un cliente especifique con detalle el tipo, acción y recurso exactos a los que solicita acceso delegado.
Fuente: insertado por el motor de autorización de bAuth al procesar una solicitud OAuth 2.0 con parámetro authorization_details; expira en 10 minutos si no se aprueba.
Administración: el authorization_details JSONB se valida contra el schema del tipo declarado; status APPROVED emite el token con claims RAR incluidos; REJECTED con razón en audit log.
WORM: no.
Particionada: no.
Estándar: RFC 9396 §3 (RAR), OAuth 2.0 RFC 6749, FAPI 2.0. T-420.';

-- ── D11 AUDITORÍA Y SIEM ─────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_audit_retention_policy IS
'AUDITORÍA IGA | Políticas de retención de logs de auditoría por tipo de evento y tenant — define cuántos días se conservan los registros, la base legal y la acción al vencer (DELETE, ARCHIVE, ANONYMIZE, KEEP).
Fuente: seed con políticas globales por defecto (SOX=7 años, GDPR=30 días, AUTH=180 días); tenants pueden crear políticas más restrictivas pero no menos que la global (tenant_id=NULL).
Administración: el job nightly de purga consulta esta tabla antes de eliminar/archivar cualquier log; tenant_id=NULL es la política global que aplica cuando no hay política específica del tenant.
WORM: no.
Particionada: no.
Estándar: SOX §802, GDPR Art. 5(1)(e) (limitación de almacenamiento), NIST AU-11. T-421.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_audit_alert_rule IS
'AUDITORÍA IGA | Reglas de alerta sobre el flujo de eventos de auditoría — define condiciones (umbral de eventos en ventana de tiempo) que disparan notificaciones a canales SIEM o bNotify al detectar anomalías.
Fuente: seed con reglas estándar (X intentos fallidos en Y minutos, elevación de privilegio, etc.); añadibles por AUDIT_ADMIN vía RPC bauth.audit.alert.create.
Administración: reglas ACTIVE evaluadas en tiempo real por el motor de análisis de logs; false_positive_threshold suprime alertas repetidas del mismo origen; reglas inactivas no consumen recursos.
WORM: no.
Particionada: no.
Estándar: NIST AU-6 (análisis de auditoría), ISO 27001 A.8.16 (monitoreo de actividades). T-422.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_audit_siem_target IS
'AUDITORÍA IGA | Destinos SIEM configurados — define los endpoints (Wazuh, Elastic, Kafka, webhooks) a los que bAuth envía eventos de auditoría en tiempo real con el formato y filtros correspondientes.
Fuente: seed con Wazuh local (UDP 514, formato WAZUH) por defecto; SIEM externos configurados por AUDIT_ADMIN vía RPC bauth.audit.siem.register.
Administración: destinos ACTIVE reciben todos los eventos del event_filter (vacío = todos); last_sent_at actualizado tras cada envío exitoso; fallos de entrega generan alerta local inmediata.
WORM: no.
Particionada: no.
Estándar: NIST AU-9(2) (protección de auditoría remota), ISO 27001 A.8.15, CEF/LEEF standards. T-423.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_audit_event_log IS
'AUDITORÍA IGA | Log de auditoría unificado multi-dominio WORM con hash chain — registra todos los eventos de los 18 dominios (D00-D99) con hash SHA-256 encadenado que garantiza integridad forense.
Fuente: insertado por cada subsistema de bAuth al procesar una operación; hash_actual calculado por trigger a partir del evento + prev_hash; la IP siempre llega anonimizada (ip_hash).
Administración: tabla particionada mensualmente WORM (REVOKE UPDATE DELETE); el hash chain hace detectable cualquier alteración forense; archivado según idn_audit_retention_policy al vencer cada período.
WORM: sí — append-only con hash chain SHA-256; modificar una fila rompe todos los hashes posteriores, siendo evidencia irrefutable de manipulación.
Particionada: sí — por logged_at, mensual.
Estándar: ISO 27001 A.8.15, GDPR Art. 5(1)(f), NIST AU-2, SOX §802. T-424.';

-- ── D12 BLOCKCHAIN ────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_blockchain_anchor_ext IS
'BLOCKCHAIN | Extensión del ancla blockchain (blk_anchor T-358) — agrega contexto semántico al ancla: tipo del evento fuente (PRIVILEGE_GRANT, AUDIT_BATCH, etc.) y prueba de inclusión Merkle en el batch.
Fuente: creado automáticamente por el job de anclaje blockchain de bAuth al anclar un batch de eventos; referencia siempre un blk_anchor existente.
Administración: tabla WORM — las extensiones de anclas blockchain son evidencia forense inmutable; external_verification_url permite verificación pública en el explorador de red Besu.
WORM: sí — la extensión de un ancla blockchain no puede modificarse; refleja la inmutabilidad del registro distribuido en la BD local.
Particionada: no.
Estándar: Hyperledger Besu §6, RFC 6962 §2 (Certificate Transparency), NIST SP 800-208 §3. T-425.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_blockchain_transaction IS
'BLOCKCHAIN | Registro de transacciones en la red Besu QBFT privada — documenta cada llamada a contrato inteligente (liquidación, freeze, deploy) con tx_hash, gas consumido y estado de confirmación.
Fuente: insertado por el motor blockchain de bAuth al enviar una transacción a Besu; status CONFIRMED actualizado por el listener de bloques cuando la TX alcanza finalidad QBFT.
Administración: transacciones PENDING sin confirmar tras 5 minutos generan alerta; REVERTED indica fallo en contrato inteligente; el job de reconciliación detecta inconsistencias entre BD y la red.
WORM: no (status y block_number se actualizan al confirmar).
Particionada: no.
Estándar: Hyperledger Besu §4, EIP-712 (Structured Data Signing), QBFT RFC 8812. T-426.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_blockchain_wallet IS
'BLOCKCHAIN | Wallet blockchain por tenant — almacena la dirección Besu/EVM y el path en Vault de la clave privada (NUNCA la clave en BD), con el saldo actual para operaciones de settlement.
Fuente: creado automáticamente por bAuth al incorporar un nuevo tenant con funcionalidad blockchain; la clave privada generada en Vault nunca sale de Vault (vault_key_path = referencia solo).
Administración: un wallet por tenant (UNIQUE tenant_id); balance_wei actualizado por el listener de bloques; wallets FROZEN no pueden enviar TX; DECOMMISSIONED es estado terminal irreversible.
WORM: no (balance y status se actualizan en ciclo de vida normal).
Particionada: no.
Estándar: BIP-32 (HD wallets), BIP-39 (mnemonics), BIP-44 (derivation paths), EIP-712. T-427.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_blockchain_merkle_proof IS
'BLOCKCHAIN | Pruebas de inclusión Merkle para eventos incluidos en un batch blockchain — permite demostrar criptográficamente que un evento específico está en una raíz Merkle anclada on-chain sin revelar otros eventos.
Fuente: generado por el motor de Merkle de bAuth al crear cada batch; cada leaf corresponde a un evento de idn_audit_event_log hash-encadenado.
Administración: la verificación se ejecuta con leaf_hash + proof_path + proof_directions → root_hash; is_verified se marca true al verificar exitosamente; son la base de demostración forense de integridad.
WORM: no (is_verified se actualiza post-verificación).
Particionada: no.
Estándar: RFC 6962 §2.1.1 (Merkle Trees), NIST SP 800-208 §3. T-428.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_blockchain_node IS
'BLOCKCHAIN | Nodos de la red Besu QBFT privada del ecosistema SBOS — registra estado, dirección Ethereum, conectividad y si el nodo es validador activo del consenso tolerante a fallos.
Fuente: registrado por bos al desplegar un nuevo nodo en la red; el heartbeat (last_heartbeat, last_block_number, peers_count) es actualizado por el monitor de nodos de bAuth periódicamente.
Administración: nodos OFFLINE >5 minutos generan alerta CRITICAL; un validador OFFLINE reduce la tolerancia a fallos QBFT (f=(n-1)/3); se requieren ≥4 validadores para tolerancia f≥1.
WORM: no.
Particionada: no.
Estándar: Hyperledger Besu §4, EIP-225 (Clique/QBFT), Istanbul BFT RFC 8812. T-429.';

-- ── D13 FIRMA DIGITAL ─────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_request IS
'FIRMA DIGITAL | Solicitud de firma digital — orquesta la firma de un documento mediante el motor interno (Ed25519/Vault) o externo (ADSIB RSA-SHA256) con el formato solicitado (PAdES/CAdES/XAdES/JAdES) y soporte de timestamp calificado.
Fuente: creada por la aplicación solicitante vía RPC bauth.signature.request con el hash SHA-256 del documento; bAuth nunca recibe el documento en claro, solo su hash SHA-256.
Administración: solicitudes PENDING procesadas por el motor de firma en orden; requires_timestamp=true dispara contacto con TSA; FAILED requiere re-solicitud con nuevo ctx_id.
WORM: no (status evoluciona: PENDING→SIGNING→SIGNED/FAILED/CANCELLED).
Particionada: no.
Estándar: PAdES EN 319 132, Ley 164 Bolivia Art. 9, ETSI EN 319 102-1. T-440.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_ca_chain IS
'FIRMA DIGITAL | Cadena de certificación CA de confianza — registra los certificados CA (root, intermediate, issuing, ADSIB, Vault PKI) con fingerprint, validez y ruta en Vault (NUNCA el PEM en BD).
Fuente: cargado por bAuth al configurar un motor de firma; certificados ADSIB importados al contratar el servicio; los de Vault PKI generados automáticamente al inicializar el PKI.
Administración: job diario verifica not_after de todos los CAs activos y alerta con 90/30/7 días de anticipación; is_trusted=false deshabilita la CA sin eliminarla (histórico de validación PKI).
WORM: no.
Particionada: no.
Estándar: RFC 5280 §6 (X.509 Path Validation), ADSIB-FD-POLT-015 v2.3. T-441.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_timestamp IS
'FIRMA DIGITAL | Timestamp calificado RFC 3161 de una Autoridad de Sellado de Tiempo (TSA) — acredita que el documento existía en el momento del sellado; esencial para validez legal a largo plazo (PAdES-T).
Fuente: obtenido automáticamente por bAuth del TSA configurado durante el proceso de firma cuando requires_timestamp=true; el token_base64 es el TSTInfo original de la TSA.
Administración: token_base64 es inmutable; el job de verificación periódico confirma que el certificado del TSA no está revocado; es prerrequisito para generar idn_signature_ltv_evidence.
WORM: no.
Particionada: no.
Estándar: RFC 3161 §2 (Time-Stamp Protocol), Ley 164 Bolivia Art. 20, ETSI EN 319 421. T-442.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_verification_log IS
'FIRMA DIGITAL | Log WORM de verificaciones de firma — registra cada comprobación de validez de firma (VALID, INVALID, EXPIRED, REVOKED) con estado de certificado, cadena y timestamp para auditoría forense.
Fuente: insertado por el motor de verificación de bAuth cada vez que se verifica una firma, sea por la aplicación o por el job de verificación periódica de firmas en custodia.
Administración: tabla WORM; verificaciones INVALID escaladas automáticamente; este log es la evidencia de que la firma fue válida en un momento específico (crítico para LTV post-expiración del cert).
WORM: sí — el log de verificaciones de firma es evidencia forense de validez en el tiempo; modificarlo falsificaría la historia de validación.
Particionada: no.
Estándar: ETSI EN 319 102-1 §5, RFC 5280 (Certificate Validation), PAdES EN 319 132. T-443.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_revocation_cache IS
'FIRMA DIGITAL | Cache de estado de revocación de certificados OCSP/CRL — evita consultar OCSP/CRL en cada verificación almacenando el estado en BD con TTL (next_update), mejorando disponibilidad del sistema.
Fuente: actualizado por el motor de verificación de bAuth tras cada consulta OCSP/CRL exitosa; el status se invalida automáticamente cuando se supera next_update.
Administración: el job de pre-fetch nocturno actualiza el cache de los certificados activos antes de que expire; REVOKED nunca se re-verifica como GOOD; check_source identifica origen del estado.
WORM: no (status se actualiza cuando cambia la revocación).
Particionada: no.
Estándar: RFC 6960 (OCSP), RFC 5280 §5 (CRL Distribution Points), ETSI EN 319 102-1 §5.2. T-444.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_ltv_evidence IS
'FIRMA DIGITAL | Evidencia LTV (Long-Term Validation) WORM — captura el estado completo de validación (cadena de certs, respuestas OCSP, CRLs) en el momento de la firma, permitiendo validar la firma décadas después aunque los certs hayan expirado.
Fuente: generado automáticamente por bAuth cuando requires_lts=true en la solicitud de firma, tras obtener el timestamp calificado; es una fotografía forense inmutable del estado PKI al momento de la firma.
Administración: tabla WORM; valid_until estima cuándo re-archivar la evidencia (antes de que expire el último timestamp); firmas PAdES-LTA re-archivan automáticamente según ETSI EN 319 102-2 §5.6.
WORM: sí — la evidencia LTV es una foto del estado PKI en un instante; modificarla invalidaría la capacidad de validación a largo plazo de la firma digital.
Particionada: no.
Estándar: ETSI EN 319 102-2 §5.6 (LTV), RFC 3161 §3, PAdES-LT/LTA. T-445.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_signature_eudi_wallet IS
'FIRMA DIGITAL | Integración con EUDI Wallet (eIDAS 2.0) — vincula la identidad digital del sistema con una cartera de identidad europea, permitiendo usar credenciales verificables (VCs) del EUDI para firmas y autenticaciones transfronterizas.
Fuente: creado cuando el usuario vincula su EUDI Wallet mediante el flujo de vinculación eIDAS 2.0 en el portal de identidad de bAuth.
Administración: un entity_id puede tener una wallet por proveedor (UNIQUE entity_id+wallet_provider); SUSPENDED bloquea el uso sin revocar la vinculación; PENDING durante la verificación de la wallet.
WORM: no.
Particionada: no.
Estándar: EU 2024/1183 (eIDAS 2.0 Regulation), ARF 1.4 (Architecture Reference Framework), ETSI EN 319 411. T-446.';

-- ── D14 PAM ───────────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.pam_session_recording IS
'PAM | Referencia trazable a grabaciones de sesiones privilegiadas — almacena el path de almacenamiento (MinIO/S3/NFS) y el hash SHA-256 del archivo de grabación; el video nunca se almacena en BD.
Fuente: creado automáticamente por el motor PAM de bAuth al iniciar la grabación de una sesión privilegiada; el hash se calcula al cerrar la grabación y se almacena aquí junto con la ruta.
Administración: el archivo de grabación está en el storage externo (is_encrypted=true obligatorio); retain_until define cuándo puede eliminarse según la política (SOX: 7 años para sesiones de alto privilegio).
WORM: no (el hash se actualiza cuando la grabación se completa y cifra en el storage).
Particionada: no.
Estándar: NIST AU-14 (Session Audit), CIS Controls v8 §8.11, PCI DSS 4.0 Req 10.2. T-461.';

-- ── D15 NHI ───────────────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_nhi_rotation_policy IS
'DOMINIOS CONTROL (D15) | Política de rotación de secretos de identidades no-humanas (NHI) por tipo — define la frecuencia de rotación, el patrón ON_USE para CI/CD, y la acción ante fallo de rotación automática.
Fuente: seed con políticas por defecto por tipo de NHI; actualizable por SECURITY_ADMIN del tenant vía RPC bauth.nhi.rotation.policy.update; una política por tenant+tipo (UNIQUE).
Administración: el job de rotación automática de bAuth consulta esta tabla para determinar qué NHIs rotar; pre_notice_days genera alerta anticipada; fail_action=SUSPEND_NHI es la más segura pero puede impactar en producción.
WORM: no.
Particionada: no.
Estándar: NIST SP 800-57 Pt1 R5 §5.3, CIS Controls v8 §4.4, OWASP ASVS 5.0 §2.10. T-480.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_nhi_svid IS
'DOMINIOS CONTROL (D15) | SPIFFE SVID (Verifiable Identity Document) para daemons SBOS — almacena el SPIFFE ID y el path Vault del certificado X.509 o JWT SVID (NUNCA el certificado en BD).
Fuente: generado automáticamente por el motor SPIFFE de bAuth al registrar un nuevo daemon; el SVID X.509 se emite por el PKI de Vault y se almacena allí; solo la ruta queda en BD.
Administración: los SVIDs se rotan automáticamente según idn_nhi_rotation_policy; status ROTATED indica SVID reemplazado pero conservado para auditoría; REVOKED indica compromiso del daemon.
WORM: no (status evoluciona en el ciclo de vida del SVID).
Particionada: no.
Estándar: SPIFFE Spec v1.0 §8 (SVID), NIST SP 800-204A §4, X.509 RFC 5280. T-481.';

-- ── D98 META-REGISTRO ────────────────────────────────────────────────────────

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_registry_attribute_schema IS
'META-REGISTRO (D98) | Schema registry de atributos EAV — define el catálogo de atributos de identidad permitidos con su tipo, mutabilidad, IAL mínimo requerido y reglas de privacidad (mask_display, retention_days).
Fuente: seed con atributos estándar SCIM (nombre, email, teléfono, NIT, etc.); operador puede registrar atributos personalizados (category=CUSTOM) con aprobación HITL del Bibliotecario.
Administración: WRITE_ONCE no se modifican post-registro (ej: fecha de nacimiento IAL3); mask_display=true ofusca en respuestas SCIM; is_active=false depreca el atributo sin eliminar datos existentes.
WORM: no.
Particionada: no.
Estándar: SCIM 2.0 RFC 7643 §4, ISO/IEC 24760-1:2019 §5. T-500.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_registry_atom_catalog IS
'META-REGISTRO (D98) | Catálogo de átomos del motor BitMask — cada fila es un átomo de permiso con su posición en el BitMask 64-bit, dominio de pertenencia y estado de implementación; fuente de verdad del espacio de permisos.
Fuente: auto-poblado por trigger en idn_roles_template (H-06) cuando se registra un nuevo átomo; la bit_position es asignada automáticamente preservando la alineación del BitMask.
Administración: is_implemented=false indica átomo planificado sin código Rust correspondiente; deprecated_at marca el retiro del átomo (roles con ese bit quedan con bit inactivo); NUNCA se elimina un átomo registrado (rompe BitMask histórico).
WORM: no (is_implemented y deprecated_at se actualizan durante el ciclo de vida del átomo).
Particionada: no.
Estándar: NIST SP 800-162 §4.2 (ABAC), ANSI INCITS 359-2004 (RBAC Standard). T-501.';

-- [DOC:REVIEW]
COMMENT ON TABLE bauth.idn_registry_bitmask_version IS
'META-REGISTRO (D98) | Snapshots diarios del árbol BitMask completo — cada fila es una fotografía del estado del espacio de permisos en un momento dado, permitiendo reconstrucción forense de privilegios en cualquier fecha pasada.
Fuente: generado automáticamente por el job diario de bAuth (DAILY_JOB) que toma snapshot del catálogo de átomos y calcula el hash SHA-256 del estado completo del árbol.
Administración: los snapshots se conservan según idn_audit_retention_policy; version_tag sigue formato ISO 8601 de la fecha del snapshot; domain_counts almacena conteo de átomos activos por dominio en JSONB.
WORM: no (cada snapshot es un nuevo INSERT; una vez insertado no se modifica).
Particionada: no.
Estándar: ISO 9001:2015 §7.5 (registros controlados), ISO/IEC 24760-2:2025. T-502.';

-- =============================================================================
-- SECCIÓN 20 — Tablas recuperadas desde VPS (existían en BD sin DDL local)
-- T-169 idn_did_document · T-188 idn_dpia_registro · T-186b idn_identidad_lifecycle_event
-- =============================================================================

-- ======================================================================
-- T-169 — bauth.idn_did_document
-- Caché de documentos DID resueltos (W3C DID Core v1.1).
-- Permite resolver DIDs sin llamada externa en cada operación.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_did_document (
    did_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    did             TEXT        NOT NULL UNIQUE,
    did_method      TEXT        NOT NULL,
    document        JSONB       NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    tenant_id       UUID        NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE SET NULL,
    entidad_id      UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    resolved_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NULL,
    deactivated_at  TIMESTAMPTZ NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_idd_status CHECK (status IN ('ACTIVE','DEACTIVATED','INVALID','EXPIRED')),
    CONSTRAINT chk_idd_did_format CHECK (did ~* '^did:[a-z0-9]+:.+$')
);

CREATE INDEX IF NOT EXISTS idx_idd_tenant   ON bauth.idn_did_document (tenant_id)   WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_idd_entidad  ON bauth.idn_did_document (entidad_id)  WHERE entidad_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_idd_method   ON bauth.idn_did_document (did_method);
CREATE INDEX IF NOT EXISTS idx_idd_status   ON bauth.idn_did_document (status)      WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_idd_expires  ON bauth.idn_did_document (expires_at)  WHERE expires_at IS NOT NULL;

COMMENT ON TABLE bauth.idn_did_document IS
'IDENTIDAD D00 | Caché de documentos DID resueltos (GAP-D00-05). Permite que bAuth resuelva
DIDs (did:web, did:key, did:ion, did:peer) sin llamada externa en cada operación. El resolver
actualiza esta tabla cuando el documento DID caduca (expires_at) o es deactivated.
Fuente: poblada por el resolver DID de bAuth al procesar operaciones de firma/verificación
o al registrar credenciales DID de un actor; los DIDs estáticos (did:key) no expiran.
Administración: el job de expiración marca status=EXPIRED cuando expires_at < now(); solo
el resolver DID puede insertar/actualizar; la aplicación solo lee.
WORM: no — status y expires_at se actualizan por el resolver.
Particionada: no.
Estándar: W3C DID Core v1.1 CR mar-2026, W3C VC Data Model 2.0, ISO 18013-5:2021. T-169.';

COMMENT ON COLUMN bauth.idn_did_document.did         IS 'Decentralized Identifier en formato canónico W3C. Ej: did:web:example.com · did:key:z6Mk...';
COMMENT ON COLUMN bauth.idn_did_document.did_method  IS 'Método DID: web, key, ion, peer, ethr. Determina el resolver a usar.';
COMMENT ON COLUMN bauth.idn_did_document.document    IS 'Documento DID resuelto en JSON-LD. Incluye verificationMethod, authentication, assertionMethod.';
COMMENT ON COLUMN bauth.idn_did_document.expires_at  IS 'TTL de caché. NULL = sin expiración (DIDs estáticos como did:key). El resolver refresca cuando expires_at < now().';


-- ======================================================================
-- T-188 — bauth.idn_dpia_registro
-- Evaluaciones de Impacto relativas a la Protección de Datos (GDPR Art. 35).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_dpia_registro (
    dpia_id                UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id              UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    titulo                 JSONB       NOT NULL,
    descripcion            JSONB       NOT NULL,
    finalidad              TEXT        NOT NULL,
    categorias_datos       TEXT[]      NOT NULL DEFAULT '{}',
    datos_especiales       BOOLEAN     NOT NULL DEFAULT false,
    riesgos                JSONB       NOT NULL DEFAULT '[]',
    riesgo_residual        TEXT        NOT NULL DEFAULT 'MEDIUM',
    medidas_mitigacion     JSONB       NOT NULL DEFAULT '[]',
    estado                 TEXT        NOT NULL DEFAULT 'DRAFT',
    requiere_consulta_previa BOOLEAN   NOT NULL DEFAULT false,
    dpa_notificado         BOOLEAN     NOT NULL DEFAULT false,
    dpa_notificado_at      TIMESTAMPTZ NULL,
    responsable_id         UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    dpo_id                 UUID        NULL     REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    aprobado_at            TIMESTAMPTZ NULL,
    proxima_revision       TIMESTAMPTZ NULL,
    documento_ref          TEXT        NULL,
    ctx_id                 TEXT        NOT NULL DEFAULT 'system',
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_idpia_estado   CHECK (estado IN ('DRAFT','IN_REVIEW','APPROVED','REJECTED','ARCHIVED','REQUIRES_DPA')),
    CONSTRAINT chk_idpia_riesgo   CHECK (riesgo_residual IN ('LOW','MEDIUM','HIGH','VERY_HIGH'))
);

CREATE INDEX IF NOT EXISTS idx_idpia_tenant      ON bauth.idn_dpia_registro (tenant_id);
CREATE INDEX IF NOT EXISTS idx_idpia_estado      ON bauth.idn_dpia_registro (estado);
CREATE INDEX IF NOT EXISTS idx_idpia_responsable ON bauth.idn_dpia_registro (responsable_id);
CREATE INDEX IF NOT EXISTS idx_idpia_revision    ON bauth.idn_dpia_registro (proxima_revision) WHERE proxima_revision IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_idpia_especiales  ON bauth.idn_dpia_registro (tenant_id) WHERE datos_especiales = true;

COMMENT ON TABLE bauth.idn_dpia_registro IS
'PRIVACIDAD D00 | Registro de Evaluaciones de Impacto relativas a la Protección de Datos
(GAP-D00-10). GDPR Art. 35 obliga a realizar DPIA para tratamientos de alto riesgo (datos
biométricos, datos de menores, vigilancia sistemática, perfilado). Incluye inventario de riesgos,
medidas de mitigación y estado de aprobación del DPO.
Fuente: creada por el DPO o PRIVACY_ADMIN vía RPC; obligatoria antes de activar módulos
biométricos, geoespaciales o de delegación financiera en un tenant.
Administración: solo PRIVACY_ADMIN y DPO pueden crear y aprobar; estado=REQUIRES_DPA genera
notificación a la autoridad de control; proxima_revision activa recordatorio automático.
WORM: no — el estado y las medidas evolucionan durante el proceso de revisión.
Particionada: no.
Estándar: GDPR Art. 35 (Reg UE 2016/679), WP248 rev01 (WP29), Guía AEPD 2023. T-188.';

COMMENT ON COLUMN bauth.idn_dpia_registro.categorias_datos      IS 'Categorías de datos tratados: personal, biometric, financial, health, location, behavioral.';
COMMENT ON COLUMN bauth.idn_dpia_registro.datos_especiales       IS 'TRUE = incluye categorías especiales GDPR Art.9 (salud, biometría, origen racial, etc.).';
COMMENT ON COLUMN bauth.idn_dpia_registro.riesgo_residual        IS 'Nivel de riesgo residual tras aplicar medidas: LOW/MEDIUM/HIGH/VERY_HIGH.';
COMMENT ON COLUMN bauth.idn_dpia_registro.requiere_consulta_previa IS 'TRUE = riesgo alto sin mitigación suficiente → consulta previa al organismo de control obligatoria.';
COMMENT ON COLUMN bauth.idn_dpia_registro.dpa_notificado         IS 'TRUE = autoridad de control notificada (Art. 36 GDPR).';


-- ======================================================================
-- T-186b — bauth.idn_identidad_lifecycle_event
-- Eventos JML (Joiner/Mover/Leaver) del ciclo de vida de identidad.
-- NIST SP 800-63-3 §4 · SCIM 2.0 RFC 7644 §3.4.3
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_lifecycle_event (
    event_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    entidad_id      UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    event_type      TEXT        NOT NULL,
    effective_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    triggered_by    UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    policy_snapshot JSONB       NULL,
    notes           TEXT        NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ile_event_type CHECK (
        event_type IN ('HIRED','TRANSFERRED','PROMOTED','ON_LEAVE','RETURNED','TERMINATED','REACTIVATED')
    )
);

CREATE INDEX IF NOT EXISTS idx_ile_entidad     ON bauth.idn_identidad_lifecycle_event (entidad_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_ile_tenant_type ON bauth.idn_identidad_lifecycle_event (tenant_id, event_type, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_ile_triggered   ON bauth.idn_identidad_lifecycle_event (triggered_by);

COMMENT ON TABLE bauth.idn_identidad_lifecycle_event IS
'IDENTIDAD JML D00 | Registro de eventos de ciclo de vida de identidad (GAP-D00-02).
Joiner (HIRED/REACTIVATED) · Mover (TRANSFERRED/PROMOTED/ON_LEAVE/RETURNED) ·
Leaver (TERMINATED). Fuente de verdad para auditar transiciones laborales y disparar el
ajuste automático de privilegios (privilege creep detection).
Fuente: insertada por el IAM Installer al provisionar actores; por RRHH/supervisor vía RPC
bauth.identity.lifecycle.event.create; por el reconcile loop al detectar cambios en RRHH.
Administración: APPEND-ONLY — ningún evento se modifica; policy_snapshot captura el estado
exacto de grants y roles al momento del evento (evidencia forense pre-cambio).
WORM: sí operacional — REVOKE UPDATE, DELETE en producción.
Particionada: no (volumen bajo — un evento por transición laboral).
Estándar: NIST SP 800-63-3 §4 (JML), ISO 27001 A.6.1 (incorporación/baja), SCIM 2.0 RFC 7644. T-186b.';

COMMENT ON COLUMN bauth.idn_identidad_lifecycle_event.triggered_by    IS '[ISO 27001 A.5.18] FK a idn_identity_entity. Quién activó el evento: RRHH, supervisor, sistema bAuth.';
COMMENT ON COLUMN bauth.idn_identidad_lifecycle_event.policy_snapshot IS '[NIST AC-2] Snapshot JSONB de los grants y roles activos al momento del evento. Evidencia forense del estado pre-cambio.';

REVOKE UPDATE, DELETE ON bauth.idn_identidad_lifecycle_event FROM PUBLIC;

-- =============================================================================
-- SECCIÓN 21 — WORM ENFORCEMENT TRIGGERS (tablas definidas en esta migration)
-- Cierra: GAP-OP-02 (bauth_dominios_pendientes_v2.0.sql)
-- Norma: ISO 27001:2022 A.8.15 · NIST AU-9 · PCI DSS 10.3.2
-- Requiere: bauth.fn_worm_enforce() definida en SBOS_db_V2_DDL.sql (§WORM).
-- Idempotente: DROP TRIGGER IF EXISTS + CREATE TRIGGER.
-- FOR EACH STATEMENT: rechaza incluso en tablas vacías (no requiere filas).
-- =============================================================================

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_network_dpop_binding;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_network_dpop_binding
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_credential_password_history;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_credential_password_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_physical_access_evacuation;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_physical_access_evacuation
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_delegation_usage_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_delegation_usage_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_audit_event_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_audit_event_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_blockchain_anchor_ext;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_blockchain_anchor_ext
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_signature_verification_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_signature_verification_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_signature_ltv_evidence;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_signature_ltv_evidence
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_identidad_lifecycle_event;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_identidad_lifecycle_event
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- =============================================================================
-- FIN: bAuth Dominios Pendientes v2.0 — tablas y columnas en inglés
-- Comentarios SQL y documentación en español (regla SBOS)
-- SECCIÓN 19 — Documentación estratificada de 78 tablas padre añadida.
-- SECCIÓN 20 — T-169, T-188, T-186b recuperadas desde VPS (2026-08-01).
-- SECCIÓN 21 — WORM triggers para las 9 tablas append-only de esta migration (2026-08-02).
-- Estado: [DOC:REVIEW] — pendiente verificación en SBOSDB_copia con verificar_documentacion.sh
-- =============================================================================
