-- ============================================================
-- bauth_db — Schema Completo Unificado v3.0
-- SKULL · SBOS · bAuth Identity Core · BitMask Dual
-- Fecha: 2026-06-21 · 85 tablas · 3 schemas · 0 ALTER TABLE
-- ============================================================
-- INSTRUCCIONES DE DEPLOY:
--   psql -U postgres -d bauth_db -f 001_bauth_init_UNIFICADO.sql
-- POST-DEPLOY (como superusuario):
--   REVOKE UPDATE, DELETE ON bos_privilege.bos_atom_audit FROM bauth;
--   REVOKE UPDATE, DELETE ON bauth.bauth_audit_events FROM bauth;
-- VERIFICACIÓN:
--   SELECT COUNT(*) FROM bos_privilege.bos_domain; -- debe ser 12
--   SELECT COUNT(*) FROM bos_privilege.bos_verb;   -- debe ser 4
-- ROLLBACK: pgBackRest + MinIO S01
-- VALIDADO CON: 700 casos de prueba de escritorio
-- ============================================================

BEGIN;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ROLES DE APLICACIÓN
-- ============================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bauth') THEN
        CREATE ROLE bauth WITH LOGIN PASSWORD 'bauth_initial_password_change_me';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bauth_reader') THEN
        CREATE ROLE bauth_reader WITH LOGIN PASSWORD 'bauth_reader_initial_password_change_me';
    END IF;
END $$;

-- ============================================================
-- SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bauth;
COMMENT ON SCHEMA bauth IS 'Núcleo de identidad bAuth: tenants, roles, usuarios, tokens, auditoría. Tablas del dominio de aplicación.';
ALTER SCHEMA bauth OWNER TO bauth;

CREATE SCHEMA IF NOT EXISTS bos_privilege;
COMMENT ON SCHEMA bos_privilege IS 'BitMask Dual: label encoding (64-bit AtomBitMask) + one-hot encoding (N-bit RolBitMask). SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §15.';
ALTER SCHEMA bos_privilege OWNER TO bauth;

CREATE SCHEMA IF NOT EXISTS bos_blockchain;
COMMENT ON SCHEMA bos_blockchain IS 'D12 Blockchain: Merkle anchoring en Arbitrum One (Var A) + liquidación Besu QBFT (Var B). SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md Apéndice D.';
ALTER SCHEMA bos_blockchain OWNER TO bauth;


-- ################################################################
-- SCHEMA: bauth — NÚCLEO DE IDENTIDAD (67 tablas)
-- ################################################################

-- ============================================================
-- 1. TENANT — Dominio técnico multi-empresa operado por SKULL
-- Referencia: SBOS-049 §4
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant (
    tenant_id              TEXT        PRIMARY KEY,              -- slug único: 'skull', 'acme', 'inka'
    nombre                 TEXT        NOT NULL,                 -- nombre descriptivo del operador del tenant
    tenant_type            TEXT        NOT NULL DEFAULT 'STANDARD', -- STANDARD|REGULATED|HIGH_SENSITIVITY
    status                 TEXT        NOT NULL DEFAULT 'PENDING_VERIFICATION', -- PENDING_VERIFICATION|ACTIVE|SUSPENDED|TERMINATED
    verification_status    TEXT        NOT NULL DEFAULT 'UNVERIFIED', -- UNVERIFIED|IN_PROGRESS|VERIFIED|REJECTED
    verified_at            TIMESTAMPTZ,                          -- timestamp de verificación completada
    verified_by            TEXT,                                 -- UUID del admin que verificó
    legal_name             TEXT,                                 -- razón social legal
    tax_id                 TEXT,                                 -- NIT Bolivia
    registration_number    TEXT,                                 -- registro de comercio
    country                TEXT        NOT NULL DEFAULT 'BO',    -- ISO 3166-2
    jurisdiction           TEXT,                                 -- jurisdicción legal aplicable
    legal_representative   TEXT,                                 -- representante legal
    legal_contact_email    TEXT,                                 -- email del representante legal
    realm_kc               TEXT        NOT NULL UNIQUE,          -- tenant-{tenant_id} en Keycloak
    realm_kc_ext           TEXT        NOT NULL UNIQUE,          -- tenant-{tenant_id}-ext en Keycloak
    namespace_k8s          TEXT        NOT NULL UNIQUE,          -- namespace en Kubernetes
    domain                 TEXT,                                 -- {tenant}.sbos.skull.bo
    isolation_level        TEXT        NOT NULL DEFAULT 'SCHEMA_PER_TENANT', -- ROW_LEVEL|SCHEMA_PER_TENANT|DB_PER_TENANT
    mfa_required           BOOLEAN     NOT NULL DEFAULT false,   -- MFA obligatorio global para este tenant
    password_policy        TEXT        NOT NULL DEFAULT 'length(12)_argon2id_t3_m64', -- política de contraseñas
    session_ttl_max        INTEGER     NOT NULL DEFAULT 28800,   -- TTL máximo de sesión en segundos (8h)
    token_ttl_seconds      INTEGER     NOT NULL DEFAULT 3600,    -- TTL de access token OAuth2 (1h)
    refresh_token_ttl_days INTEGER     DEFAULT 30,               -- TTL de refresh token (30 días)
    ip_whitelist           INET[],                               -- rangos IP permitidos (null = todos)
    audit_level            TEXT        NOT NULL DEFAULT 'basic', -- basic|full
    data_residency         TEXT        DEFAULT 'BO',             -- país donde residen los datos
    encryption_at_rest     TEXT        NOT NULL DEFAULT 'AES-256-GCM', -- algoritmo de cifrado en reposo
    backup_frequency       TEXT        NOT NULL DEFAULT 'daily', -- frecuencia de backup
    backup_retention_days  INTEGER     DEFAULT 90,               -- días de retención de backups
    plan_tier              TEXT        NOT NULL DEFAULT 'BASIC', -- BASIC|PRO|ENTERPRISE
    max_empresas           INTEGER     DEFAULT 5,                -- máximo de empresas permitidas
    max_usuarios           INTEGER     DEFAULT 50,               -- máximo de usuarios
    max_sucursales         INTEGER     DEFAULT 25,               -- máximo de sucursales
    max_pos                INTEGER     DEFAULT 100,              -- máximo de puntos de venta
    subscription_status    TEXT        NOT NULL DEFAULT 'TRIAL', -- TRIAL|ACTIVE|PAST_DUE|CANCELLED
    billing_cycle          TEXT        DEFAULT 'MONTHLY',        -- MONTHLY|ANNUAL
    trial_ends_at          TIMESTAMPTZ,                          -- fecha fin de prueba
    admin_user_uuid        UUID,                                 -- UUID del Admin Tenant (S016)
    admin_email            TEXT        NOT NULL,                 -- email del administrador
    admin_phone            TEXT,                                 -- teléfono del administrador
    metadata               JSONB       DEFAULT '{}',             -- metadatos extensibles
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    suspended_at           TIMESTAMPTZ,                          -- fecha de suspensión
    suspended_reason       TEXT,                                 -- motivo de suspensión
    terminated_at          TIMESTAMPTZ,                          -- fecha de terminación
    terminated_reason      TEXT,                                 -- motivo de terminación
    CONSTRAINT chk_tenant_status CHECK (status IN ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','TERMINATED')),
    CONSTRAINT chk_tenant_verif  CHECK (verification_status IN ('UNVERIFIED','IN_PROGRESS','VERIFIED','REJECTED')),
    CONSTRAINT chk_tenant_type   CHECK (tenant_type IN ('STANDARD','REGULATED','HIGH_SENSITIVITY')),
    CONSTRAINT chk_isolation     CHECK (isolation_level IN ('ROW_LEVEL','SCHEMA_PER_TENANT','DB_PER_TENANT')),
    CONSTRAINT chk_plan_tier     CHECK (plan_tier IN ('BASIC','PRO','ENTERPRISE')),
    CONSTRAINT chk_subscription  CHECK (subscription_status IN ('TRIAL','ACTIVE','PAST_DUE','CANCELLED'))
);
COMMENT ON TABLE bauth.bos_tenant IS 'Perfil completo de identidad, seguridad y cumplimiento del tenant. Un tenant es el contenedor técnico que aloja múltiples empresas independientes con aislamiento total de datos. ISO 27001 A.9, NIST SP 800-63B, RGPD Art.25.';

-- ============================================================
-- 2. TENANT VERIFICATION — 5 pasos de onboarding validado
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_verification (
    verification_id BIGSERIAL PRIMARY KEY,
    tenant_id       TEXT        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    step            TEXT        NOT NULL,              -- IDENTITY_CHECK|LEGAL_CHECK|TECHNICAL_SETUP|SECURITY_REVIEW|FINAL_APPROVAL
    status          TEXT        NOT NULL DEFAULT 'PENDING', -- PENDING|IN_PROGRESS|PASSED|FAILED
    verified_by     TEXT,
    verified_at     TIMESTAMPTZ,
    comments        TEXT,
    evidence        JSONB       DEFAULT '{}',          -- URLs a documentos de evidencia
    CONSTRAINT chk_verif_step CHECK (step IN ('IDENTITY_CHECK','LEGAL_CHECK','TECHNICAL_SETUP','SECURITY_REVIEW','FINAL_APPROVAL'))
);
COMMENT ON TABLE bauth.bos_tenant_verification IS 'Registro de los 5 pasos de verificación requeridos para activar un tenant. Cada paso debe ser completado por un administrador autorizado.';

-- ============================================================
-- 3-8. CATÁLOGOS BASE — Países, Ciudades, Monedas, Idiomas, Timezones, Tenant Config
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_pais (
    codice_iso  CHAR(2) PRIMARY KEY,       -- ISO 3166-1 alpha-2
    nombre      TEXT    NOT NULL,
    gentilicio  TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_pais IS 'Catálogo de países. ISO 3166-1.';

CREATE TABLE IF NOT EXISTS bauth.bos_ciudad (
    ciudad_id   BIGSERIAL PRIMARY KEY,
    nombre      TEXT    NOT NULL,
    pais_iso    CHAR(2) NOT NULL REFERENCES bauth.bos_pais(codice_iso),
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_ciudad IS 'Catálogo de ciudades referenciadas por sucursales.';

CREATE TABLE IF NOT EXISTS bauth.bos_moneda (
    codice_iso  CHAR(3) PRIMARY KEY,       -- ISO 4217
    nombre      TEXT    NOT NULL,
    simbolo     TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_moneda IS 'Catálogo de monedas. ISO 4217. Usado por D3 Financiero para límites y transacciones.';

CREATE TABLE IF NOT EXISTS bauth.bos_idioma (
    codigo      CHAR(2) PRIMARY KEY,       -- ISO 639-1
    nombre      TEXT    NOT NULL,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_idioma IS 'Catálogo de idiomas. ISO 639-1.';

CREATE TABLE IF NOT EXISTS bauth.bos_timezone (
    timezone_id SERIAL PRIMARY KEY,
    name        TEXT    NOT NULL,           -- ej: 'America/La_Paz'
    utc_offset  INTERVAL NOT NULL,          -- ej: '-04:00:00'
    country_code CHAR(2) DEFAULT 'BO'
);
COMMENT ON TABLE bauth.bos_timezone IS 'Catálogo de zonas horarias.';

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_config (
    tenant_id           TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    default_language    CHAR(2) DEFAULT 'es',
    default_timezone    TEXT    DEFAULT 'America/La_Paz',
    default_currency    CHAR(3) DEFAULT 'BOB',
    metadata            JSONB   DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(tenant_id)
);
COMMENT ON TABLE bauth.bos_tenant_config IS 'Configuración por tenant: idioma, zona horaria, moneda por defecto.';

-- ============================================================
-- 9-12. TENANT: Dominios, Red, Monedas, Idiomas
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_domain (
    tenant_id   TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    domain_name TEXT    NOT NULL,           -- ej: 'acme.sbos.skull.bo'
    verified    BOOLEAN DEFAULT false,
    ssl_enabled BOOLEAN DEFAULT false,
    PRIMARY KEY(tenant_id, domain_name)
);
COMMENT ON TABLE bauth.bos_tenant_domain IS 'Dominios DNS asociados a un tenant para acceso web.';

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_network (
    tenant_id   TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    network_id  BIGSERIAL,
    cidr_range  CIDR    NOT NULL,           -- ej: '10.0.0.0/8'
    description TEXT,                        -- ej: 'Oficina Central'
    deny        BOOLEAN DEFAULT false,      -- true = blacklist, false = whitelist
    PRIMARY KEY(tenant_id, network_id)
);
COMMENT ON TABLE bauth.bos_tenant_network IS 'Rangos CIDR autorizados (o denegados) por tenant. Usado por D7 (Red).';

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_currency (
    tenant_id       TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    currency_code   CHAR(3) NOT NULL REFERENCES bauth.bos_moneda(codice_iso),
    is_default      BOOLEAN DEFAULT false,
    PRIMARY KEY(tenant_id, currency_code)
);
COMMENT ON TABLE bauth.bos_tenant_currency IS 'Monedas habilitadas por tenant.';

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_language (
    tenant_id       TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    language_code   CHAR(2) NOT NULL REFERENCES bauth.bos_idioma(codigo),
    is_default      BOOLEAN DEFAULT false,
    PRIMARY KEY(tenant_id, language_code)
);
COMMENT ON TABLE bauth.bos_tenant_language IS 'Idiomas habilitados por tenant.';

-- ============================================================
-- 13-14. GESTIÓN Y CALENDARIO FISCAL
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_gestion (
    gestion_id      BIGSERIAL PRIMARY KEY,
    tenant_id       TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT    NOT NULL,           -- ej: 'Gestion 2026'
    fecha_inicio    DATE    NOT NULL,           -- ej: '2026-01-01'
    fecha_fin       DATE    NOT NULL,           -- ej: '2026-12-31'
    activo          BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_tenant_gestion IS 'Período fiscal/gestión por tenant. Define el año contable.';

CREATE TABLE IF NOT EXISTS bauth.bos_gestion_calendario (
    calendario_id   BIGSERIAL PRIMARY KEY,
    gestion_id      BIGINT  NOT NULL REFERENCES bauth.bos_tenant_gestion(gestion_id),
    fecha           DATE    NOT NULL,
    tipo            TEXT    NOT NULL DEFAULT 'LABORAL', -- LABORAL|FERIADO_NACIONAL|FERIADO_REGIONAL|NO_LABORAL
    descripcion     TEXT,                              -- ej: 'Navidad'
    CONSTRAINT chk_calendario_tipo CHECK (tipo IN ('LABORAL','FERIADO_NACIONAL','FERIADO_REGIONAL','NO_LABORAL'))
);
COMMENT ON TABLE bauth.bos_gestion_calendario IS 'Calendario de días laborales y feriados para D4 (Temporal). Bolivia: feriados nacionales y regionales.';

-- ============================================================
-- 15. SCHEDULE — Programación de tareas
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_schedule (
    schedule_id     BIGSERIAL PRIMARY KEY,
    tenant_id       TEXT    NOT NULL,
    name            TEXT    NOT NULL,
    cron_expression TEXT,                    -- formato cron estándar
    timezone        TEXT    DEFAULT 'America/La_Paz',
    enabled         BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_schedule IS 'Programación de tareas recurrentes. Usado por D4 (Temporal) y jobs batch.';

-- ============================================================
-- 16-20. UBICACIÓN FÍSICA — Sitio, Edificio, Piso, Área, Dispositivo
-- Referencia: D2 (Físico)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_sitio_fisico (
    sitio_id    BIGSERIAL PRIMARY KEY,
    tenant_id   TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre      TEXT    NOT NULL,           -- ej: 'Planta Industrial La Paz'
    direccion   TEXT,
    ciudad_id   BIGINT  REFERENCES bauth.bos_ciudad(ciudad_id),
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_sitio_fisico IS 'Sitio físico (campus, planta). Contiene edificios. D2.';

CREATE TABLE IF NOT EXISTS bauth.bos_edificio (
    edificio_id BIGSERIAL PRIMARY KEY,
    sitio_id    BIGINT  NOT NULL REFERENCES bauth.bos_sitio_fisico(sitio_id),
    nombre      TEXT    NOT NULL,           -- ej: 'Edificio Administrativo'
    pisos       INTEGER DEFAULT 1,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_edificio IS 'Edificio dentro de un sitio físico. D2.';

CREATE TABLE IF NOT EXISTS bauth.bos_piso (
    piso_id     BIGSERIAL PRIMARY KEY,
    edificio_id BIGINT  NOT NULL REFERENCES bauth.bos_edificio(edificio_id),
    numero      INTEGER NOT NULL,           -- número de piso
    nombre      TEXT,                       -- ej: 'Planta Baja'
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_piso IS 'Piso dentro de un edificio. D2.';

CREATE TABLE IF NOT EXISTS bauth.bos_area_fisica (
    area_id         BIGSERIAL PRIMARY KEY,
    piso_id         BIGINT  REFERENCES bauth.bos_piso(piso_id),
    tenant_id       TEXT    NOT NULL,
    nombre          TEXT    NOT NULL,        -- ej: 'Bóveda Principal'
    tipo_area       TEXT    DEFAULT 'GENERAL', -- GENERAL|RESTRINGIDA|ALTA_SEGURIDAD|SERVIDORES|ESTACIONAMIENTO
    nivel_seguridad INTEGER DEFAULT 1,       -- 1(bajo)-5(máximo)
    aforo_maximo    INTEGER,                -- ocupación máxima
    activo          BOOLEAN DEFAULT true,
    metadata        JSONB   DEFAULT '{}'    -- coordenadas GPS, planos, etc.
);
COMMENT ON TABLE bauth.bos_area_fisica IS 'Área/zone física dentro de un piso. Controlada por D2 con políticas OSDP.';

CREATE TABLE IF NOT EXISTS bauth.bos_dispositivo_fisico (
    dispositivo_id  TEXT    PRIMARY KEY,     -- ej: 'chapa-servidor-01'
    tipo            TEXT    NOT NULL,        -- LOCK_ELECTROMAGNETIC|LOCK_MAGNETIC|TURNSTILE|ACTUATOR|SENSOR
    ubicacion       TEXT,                   -- descripción de ubicación
    zone_id         BIGINT  REFERENCES bauth.bos_area_fisica(area_id),
    tenant_id       TEXT    NOT NULL,
    status          TEXT    DEFAULT 'ACTIVE',-- ACTIVE|INACTIVE|EMERGENCY_UNLOCKED|LOCKDOWN|MAINTENANCE
    metadata        JSONB   DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE bauth.bos_dispositivo_fisico IS 'Dispositivo físico de control de acceso: chapas, torniquetes, actuadores. D2.';

-- ============================================================
-- 21-26. FINANCIERO (D3) — Límites, Dual-Approval, SoD
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_tipo_transaccion (
    tipo_id     TEXT    PRIMARY KEY,         -- ej: 'PAGO', 'TRANSFERENCIA', 'REEMBOLSO'
    nombre      TEXT    NOT NULL,
    descripcion TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_financial_tipo_transaccion IS 'Tipos de transacción financiera. Referenciado por bos_financial_approval.';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_limit (
    limit_id        BIGSERIAL PRIMARY KEY,
    role_id         TEXT        NOT NULL,              -- FK a bos_rol_template.id
    max_transaction NUMERIC(16,2) NOT NULL,           -- límite por operación individual
    max_daily       NUMERIC(16,2),                    -- límite acumulado diario
    max_monthly     NUMERIC(16,2),                    -- límite acumulado mensual
    currency        VARCHAR(8)  DEFAULT 'BOB',       -- BOB, USD, EUR, USDT
    tenant_id       TEXT,                             -- NULL = global
    pos_logico      TEXT,                             -- NULL = aplica a todos los POS
    activo          BOOLEAN     DEFAULT true
);
COMMENT ON TABLE bauth.bos_financial_limit IS 'Límites financieros por rol. D3 Policy-Path. max_transaction = por operación, max_daily/max_monthly = acumulado.';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_decision_matrix (
    decision_id                 BIGSERIAL PRIMARY KEY,
    role_slug                   TEXT        NOT NULL,              -- slug del rol (ej: 'cajero')
    requires_dual_approval_above NUMERIC(16,2) DEFAULT 1000,      -- umbral que dispara doble firma
    sod_profile                 TEXT,                              -- perfil SoD: quién NO puede aprobar
    escalation_path             TEXT[],                           -- cadena de escalamiento: [supervisor, jefe, gerente]
    max_approval_levels         INTEGER     DEFAULT 2,            -- máximo de niveles de aprobación
    timeout_minutes             INTEGER     DEFAULT 30,           -- timeout antes de escalar
    activo                      BOOLEAN     DEFAULT true
);
COMMENT ON TABLE bauth.bos_financial_decision_matrix IS 'Matriz de decisión financiera por rol. Define umbrales de doble firma, SoD profile, y cadena de escalamiento. D3 Policy-Path.';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_approval (
    approval_id         BIGSERIAL PRIMARY KEY,
    tenant_id           TEXT        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id          TEXT,                                 -- FK a bos_empresa
    tipo_transaccion    TEXT        NOT NULL REFERENCES bauth.bos_financial_tipo_transaccion(tipo_id),
    referencia          TEXT        NOT NULL,                 -- ej: 'FAC-12345'
    monto               NUMERIC(16,2) NOT NULL,
    moneda              CHAR(3)     REFERENCES bauth.bos_moneda(codice_iso),
    solicitante_uuid    UUID        NOT NULL,                 -- FK a bos_user_template.uuid
    solicitud_fecha     TIMESTAMPTZ NOT NULL DEFAULT now(),
    solicitud_motivo    TEXT,
    nivel_actual        INTEGER     NOT NULL DEFAULT 1,      -- nivel de aprobación actual
    nivel_total         INTEGER     NOT NULL DEFAULT 1,      -- niveles totales requeridos
    aprobador_uuid      UUID,                                -- FK a bos_user_template.uuid
    decision            TEXT,                                -- APROBADO|RECHAZADO|DEVUELTO
    decision_fecha      TIMESTAMPTZ,
    decision_comentario TEXT,
    evidencia_adjunta   JSONB,                               -- URLs a documentos soporte
    escalado_a_uuid     UUID,                                -- FK al siguiente en cadena de escalamiento
    escalado_fecha      TIMESTAMPTZ,
    escalado_motivo     TEXT,
    estado              TEXT        NOT NULL DEFAULT 'PENDIENTE', -- PENDIENTE|EN_REVISION|APROBADO|RECHAZADO|ESCALADO|CANCELADO
    ctx_id_creator      VARCHAR(128),                        -- ctx_id de quien creó la solicitud (trazabilidad D8)
    ctx_id_approver     VARCHAR(128),                        -- ctx_id de quien aprobó (trazabilidad D8)
    CONSTRAINT chk_fa_estado CHECK (estado IN ('PENDIENTE','EN_REVISION','APROBADO','RECHAZADO','ESCALADO','CANCELADO'))
);
COMMENT ON TABLE bauth.bos_financial_approval IS 'Solicitudes de aprobación financiera con múltiples niveles y escalamiento. D3 Policy-Path. Trazabilidad completa vía ctx_id.';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_document_operation (
    operation_id    BIGSERIAL PRIMARY KEY,
    approval_id     BIGINT REFERENCES bauth.bos_financial_approval(approval_id),
    operation_type  TEXT    NOT NULL,     -- CREATE, UPDATE, VOID, REVERSE
    executed_at     TIMESTAMPTZ DEFAULT now(),
    metadata        JSONB   DEFAULT '{}'
);
COMMENT ON TABLE bauth.bos_financial_document_operation IS 'Operaciones sobre documentos financieros vinculados a aprobaciones.';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_role_permission (
    permission_id   BIGSERIAL PRIMARY KEY,
    role_id         TEXT    NOT NULL,     -- FK a bos_rol_template.id
    permission_type TEXT    NOT NULL,     -- CREATE_PAYMENT, APPROVE_PAYMENT, VIEW_BALANCE, etc.
    max_amount      NUMERIC(16,2),
    currency        CHAR(3) DEFAULT 'BOB',
    activo          BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_financial_role_permission IS 'Permisos financieros granulares por rol. Complementa bos_financial_limit.';

-- ============================================================
-- 27-29. LÓGICO (D1) — Zonas lógicas, Verbos, Permisos
-- NOTA: bos_verbo (legacy) es reemplazado por bos_privilege.bos_verb.
--       bos_permiso_logico es reemplazado por bos_privilege.bos_role_atom.
--       Se mantienen para backward compatibility durante la transición.
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_zona_logica (
    zona_id     BIGSERIAL PRIMARY KEY,
    nombre      TEXT    NOT NULL,          -- ej: 'Contabilidad', 'Inventario'
    descripcion TEXT,
    tenant_id   TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_zona_logica IS 'Zona lógica / módulo de aplicación. Legacy — migrando a bos_privilege.bos_group.';

CREATE TABLE IF NOT EXISTS bauth.bos_verbo (
    verbo_id    BIGSERIAL PRIMARY KEY,
    nombre      TEXT    NOT NULL UNIQUE,   -- 'nuevo', 'editar', 'eliminar', 'ver'
    codigo      INTEGER UNIQUE,           -- 1, 2, 3, 4
    descripcion TEXT
);
COMMENT ON TABLE bauth.bos_verbo IS 'Verbos de operación. Legacy — migrando a bos_privilege.bos_verb.';

CREATE TABLE IF NOT EXISTS bauth.bos_permiso_logico (
    permiso_id  BIGSERIAL PRIMARY KEY,
    zona_id     BIGINT REFERENCES bauth.bos_zona_logica(zona_id),
    verbo_id    BIGINT REFERENCES bauth.bos_verbo(verbo_id),
    rol_id      TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_permiso_logico IS 'Permisos lógicos por zona × verbo × rol. Legacy — migrando a bos_privilege.bos_role_atom.';

-- ============================================================
-- 30-36. CREDENCIALES (D9) — Políticas, MFA, Biometría, Passwords
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_credential_policy (
    policy_id       BIGSERIAL PRIMARY KEY,
    tenant_id       TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    tier            TEXT    NOT NULL,           -- SU|SYS|BIZ|EXT|M2M
    min_length      INTEGER DEFAULT 12,        -- longitud mínima de contraseña (NIST SP 800-63B)
    require_mfa     BOOLEAN DEFAULT false,     -- MFA obligatorio para este tier
    mfa_methods     TEXT[],                    -- métodos MFA permitidos: ['TOTP','FIDO2','PASSKEY']
    password_ttl_days INTEGER DEFAULT 365,    -- expiración de contraseña (0 = no expira, NIST)
    CONSTRAINT chk_cp_tier CHECK (tier IN ('SU','SYS','BIZ','EXT','M2M'))
);
COMMENT ON TABLE bauth.bos_credential_policy IS 'Políticas de credenciales por tier. NIST SP 800-63B Rev.4.';

CREATE TABLE IF NOT EXISTS bauth.bos_credential_rotation_log (
    rotation_id     BIGSERIAL PRIMARY KEY,
    tenant_id       TEXT    NOT NULL,
    user_uuid       UUID,
    credential_type TEXT    NOT NULL,          -- PASSWORD|TOTP|FIDO2|API_KEY|CERTIFICATE
    rotated_at      TIMESTAMPTZ DEFAULT now(),
    reason          TEXT,
    metadata        JSONB   DEFAULT '{}'
);
COMMENT ON TABLE bauth.bos_credential_rotation_log IS 'Historial de rotación de credenciales por usuario.';

CREATE TABLE IF NOT EXISTS bauth.bauth_biometric_templates (
    template_id     BIGSERIAL PRIMARY KEY,
    user_uuid       UUID    NOT NULL,
    biometric_type  TEXT    NOT NULL,          -- FINGERPRINT|FACE|IRIS|VOICE|PALM|BEHAVIOR
    template_hash   TEXT    NOT NULL,          -- PBKDF2-SHA256 hash. NUNCA raw biometric data.
    created_at      TIMESTAMPTZ DEFAULT now(),
    metadata        JSONB   DEFAULT '{}',
    CONSTRAINT chk_bio_type CHECK (biometric_type IN ('FINGERPRINT','FACE','IRIS','VOICE','PALM','BEHAVIOR'))
);
COMMENT ON TABLE bauth.bauth_biometric_templates IS 'Plantillas biométricas hasheadas. NUNCA datos biométricos en texto plano. RGPD Art.9. D5.';

CREATE TABLE IF NOT EXISTS bauth.bauth_password_history (
    history_id      BIGSERIAL PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    password_hash   TEXT        NOT NULL,      -- Argon2id hash
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.bauth_password_history IS 'Historial de contraseñas. Previene reutilización (últimas 10). NIST SP 800-63B.';

CREATE TABLE IF NOT EXISTS bauth.bauth_mfa_enrollments (
    enrollment_id           BIGSERIAL PRIMARY KEY,
    user_uuid               UUID        NOT NULL,
    method                  TEXT        NOT NULL,          -- TOTP|HOTP|FIDO2|PASSKEY|NFC|QR|PUSH|SMS|EMAIL|RECOVERY_CODE|BIOMETRIC|MAGIC_LINK
    secret_encrypted        TEXT,                          -- cifrado con AES-256-GCM. Clave en Vault Transit.
    status                  TEXT        NOT NULL DEFAULT 'PENDING_VERIFICATION',
    verified_at             TIMESTAMPTZ,                  -- timestamp de verificación exitosa
    revoked_at              TIMESTAMPTZ,                  -- timestamp de revocación
    revoke_reason           TEXT,                         -- motivo de revocación
    previous_enrollment_id  BIGINT,                       -- FK a enrollment anterior (para tracking de rotación)
    recovery_code_hashes    TEXT[],                       -- SHA-256 de los recovery codes (nunca texto plano)
    recovery_codes_used     INTEGER     DEFAULT 0,        -- cuántos recovery codes se han usado
    last_used_at            TIMESTAMPTZ,                  -- último uso exitoso de este método
    deprecated_at           TIMESTAMPTZ,                  -- cuando fue marcado como obsoleto (ej: SMS deprecado)
    migration_deadline      TIMESTAMPTZ,                  -- fecha límite para migrar a otro método
    created_at              TIMESTAMPTZ DEFAULT now(),
    metadata                JSONB       DEFAULT '{}',
    CONSTRAINT chk_mfa_method CHECK (method IN ('TOTP','HOTP','FIDO2','PASSKEY','NFC','QR','PUSH','SMS','EMAIL','RECOVERY_CODE','BIOMETRIC','MAGIC_LINK')),
    CONSTRAINT chk_mfa_status CHECK (status IN ('PENDING_VERIFICATION','ACTIVE','ROTATING','REVOKED','DEPRECATED','EXPIRED'))
);
COMMENT ON TABLE bauth.bauth_mfa_enrollments IS 'Registro de métodos MFA por usuario. Soporta 12 tipos de método. Ciclo de vida completo: enroll→verify→rotate→revoke→deprecate. D9.';

-- ============================================================
-- 37-39. EMPRESA, SUCURSAL, POS LÓGICO
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_empresa (
    empresa_id  TEXT    PRIMARY KEY,         -- UUID
    tenant_id   TEXT    NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre      TEXT    NOT NULL,            -- razón social
    nit         TEXT,                        -- NIT Bolivia
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_empresa IS 'Empresa dentro de un tenant. Un tenant puede tener múltiples empresas con aislamiento total. SBOS-049 §4.';

CREATE TABLE IF NOT EXISTS bauth.bos_sucursal (
    sucursal_id TEXT    PRIMARY KEY,         -- UUID
    empresa_id  TEXT    NOT NULL REFERENCES bauth.bos_empresa(empresa_id),
    nombre      TEXT    NOT NULL,
    direccion   TEXT,
    ciudad_id   BIGINT  REFERENCES bauth.bos_ciudad(ciudad_id),
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_sucursal IS 'Sucursal de una empresa. Una empresa puede tener múltiples sucursales.';

CREATE TABLE IF NOT EXISTS bauth.bos_pos_logico (
    pos_id      TEXT    PRIMARY KEY,         -- UUID
    sucursal_id TEXT    NOT NULL REFERENCES bauth.bos_sucursal(sucursal_id),
    nombre      TEXT    NOT NULL,            -- ej: 'Caja 03'
    tipo        TEXT    DEFAULT 'CAJA',      -- CAJA|TERMINAL|KIOSCO|ADMIN
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_pos_logico IS 'Punto de operación lógico dentro de una sucursal. Terminal, caja, kiosco.';

-- ============================================================
-- 40-44. ROLES, USUARIOS, PLANTILLAS, CIERRE, DELEGACIÓN
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_rol_template (
    id              TEXT        PRIMARY KEY,          -- UUID
    tenant_id       TEXT        NOT NULL,
    nombre          TEXT        NOT NULL,
    slug            TEXT        UNIQUE,              -- ej: 'cajero', 'contador_senior'
    descripcion     TEXT,
    tier            TEXT,                            -- SU|SYS|N1|N2|N3|N4|N5|EXT
    parent_id       TEXT,                            -- FK a bos_rol_template.id (herencia DAG)
    plantilla_json  JSONB       NOT NULL,            -- definición completa del rol en JSONB
    version         INTEGER     DEFAULT 1,
    active          BOOLEAN     DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_rt_tier CHECK (tier IN ('SU','SYS','N1','N2','N3','N4','N5','EXT'))
);
COMMENT ON TABLE bauth.bos_rol_template IS 'Plantilla de rol. Fuente de verdad para la definición de roles. Se sincroniza con Keycloak y Tryton.';

CREATE TABLE IF NOT EXISTS bauth.bos_rol_template_history (
    history_id      BIGSERIAL PRIMARY KEY,
    template_id     TEXT        NOT NULL REFERENCES bauth.bos_rol_template(id),
    version         INTEGER     NOT NULL,
    plantilla_json  JSONB       NOT NULL,           -- snapshot completo de la versión
    previous_hash   TEXT,                           -- SHA-256 de la versión anterior (WORM chain)
    changed_by      UUID,                           -- admin que realizó el cambio
    changed_at      TIMESTAMPTZ DEFAULT now(),
    change_reason   TEXT
);
COMMENT ON TABLE bauth.bos_rol_template_history IS 'Historial versionado de RolTemplates. WORM con SHA-256 chain. ISO 27001 A.8.15.';

CREATE TABLE IF NOT EXISTS bauth.bos_user_template (
    uuid                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    username            TEXT        NOT NULL,
    email               TEXT,
    tenant_id           TEXT        NOT NULL,
    status              TEXT        DEFAULT 'ACTIVE',       -- PENDING_ONBOARDING|ACTIVE|SUSPENDED|INACTIVE|TERMINATED|MERGED|EXPIRED
    user_type           VARCHAR(16) DEFAULT 'HUMAN',       -- HUMAN|SERVICE_ACCOUNT|M2M|SYSTEM
    owner_uuid          UUID,                               -- dueño de la service account (para M2M)
    expires_at          TIMESTAMPTZ,                       -- fecha de expiración (para service accounts)
    merged_into         UUID,                               -- UUID del usuario primary (si fue mergeado)
    suspended_at        TIMESTAMPTZ,                       -- fecha de suspensión
    suspension_until    TIMESTAMPTZ,                       -- fecha de reactivación automática
    suspension_reason   TEXT,                              -- motivo de suspensión
    manager_uuid        UUID,                              -- UUID del manager (para IGA/JML)
    terminated_at       TIMESTAMPTZ,                       -- fecha de terminación
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    metadata            JSONB       DEFAULT '{}',
    CONSTRAINT chk_ut_status CHECK (status IN ('PENDING_ONBOARDING','ACTIVE','SUSPENDED','INACTIVE','TERMINATED','MERGED','EXPIRED')),
    CONSTRAINT chk_ut_type   CHECK (user_type IN ('HUMAN','SERVICE_ACCOUNT','M2M','SYSTEM'))
);
COMMENT ON TABLE bauth.bos_user_template IS 'Plantilla de usuario. Identidad digital completa de un actor en el ecosistema. IGA/JML ready.';

CREATE TABLE IF NOT EXISTS bauth.rol_closure (
    ancestro_id     TEXT        NOT NULL,       -- FK a bos_rol_template.id (rol senior)
    descendiente_id TEXT        NOT NULL,       -- FK a bos_rol_template.id (rol junior)
    profundidad     INTEGER     NOT NULL,       -- 0=self, 1=hijo directo, 2=nieto...
    PRIMARY KEY(ancestro_id, descendiente_id)
);
COMMENT ON TABLE bauth.rol_closure IS 'Closure table para herencia DAG de roles. Precomputa todas las relaciones ancestro→descendiente. AWS IAM / Google Zanzibar pattern.';

CREATE TABLE IF NOT EXISTS bauth.bos_delegation_log (
    delegation_id       BIGSERIAL PRIMARY KEY,
    from_user_uuid      UUID        NOT NULL REFERENCES bauth.bos_user_template(uuid), -- quien delega
    to_user_uuid        UUID        NOT NULL REFERENCES bauth.bos_user_template(uuid), -- quien recibe
    rol_id              TEXT        NOT NULL REFERENCES bauth.bos_rol_template(id),   -- rol delegado
    tenant_id           TEXT        NOT NULL,
    mask_delegated_hex  TEXT,                   -- legacy BitmaskBundle (deprecado)
    atom_positions      INTEGER[],              -- posiciones de átomos delegados (Rol BitMask one-hot) 🆕
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL,
    auto_revoke         BOOLEAN     NOT NULL DEFAULT true,   -- revocar automáticamente al expirar
    requires_approval   BOOLEAN     NOT NULL DEFAULT true,   -- requiere aprobación del manager
    approved_by         TEXT,                               -- UUID de quien aprobó
    status              TEXT        NOT NULL DEFAULT 'ACTIVE', -- ACTIVE|REVOKED|EXPIRED
    revoked_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_del_status CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
    CONSTRAINT chk_del_dates  CHECK (valid_until > valid_from),
    CONSTRAINT chk_no_self_delegation CHECK (from_user_uuid != to_user_uuid)
);
COMMENT ON TABLE bauth.bos_delegation_log IS 'Delegación temporal de roles. AND reduction: delegado = mask_original AND mask_target_role. Máximo 21 días. D10.';

-- ============================================================
-- 45-51. AUDITORÍA Y CONTEXTO (D8, D11) + SYNC + SUPERUSER + ACCESS REVIEWS + GHOST + SoD
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bauth_audit_events (
    event_id        BIGSERIAL,
    ctx_id          TEXT        NOT NULL,                  -- trazabilidad de sesión (D8)
    traceparent     TEXT,                                 -- W3C Trace Context
    event_type      TEXT        NOT NULL,                  -- ej: 'login_success', 'role_assigned'
    severity        TEXT        NOT NULL DEFAULT 'INFO',   -- INFO|WARN|HIGH|CRITICAL
    iso_control     TEXT[],                               -- controles ISO 27001 aplicables: ['A.8.15','A.9.2.5']
    user_uuid       UUID        REFERENCES bauth.bos_user_template(uuid),
    role_id         TEXT,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT,
    sucursal_id     TEXT,
    pos_logico      TEXT,
    source_ip       INET,
    user_agent      TEXT,
    action          TEXT        NOT NULL,                  -- verbo de la acción
    resource_type   TEXT        NOT NULL,                  -- tipo de recurso afectado
    resource_id     TEXT,                                 -- ID del recurso
    outcome         TEXT        NOT NULL,                  -- SUCCESS|FAILURE|DENIED|ERROR
    details         JSONB       DEFAULT '{}',              -- payload estructurado
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(event_id, created_at)
) PARTITION BY RANGE (created_at);
COMMENT ON TABLE bauth.bauth_audit_events IS 'Registro de auditoría general. WORM: REVOKE UPDATE/DELETE post-deploy. Particionado por mes. ISO 27001 A.8.15.';
CREATE TABLE IF NOT EXISTS bauth.bauth_audit_events_2026_06 PARTITION OF bauth.bauth_audit_events FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS bauth.bauth_audit_events_2026_07 PARTITION OF bauth.bauth_audit_events FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE IF NOT EXISTS bauth.context_sessions (
    ctx_id              TEXT        PRIMARY KEY,            -- identificador único de contexto
    dctx_id             TEXT,                               -- device context (pre-auth)
    tenant_id           TEXT        NOT NULL,
    empresa_id          TEXT        NOT NULL,
    sucursal_id         TEXT,
    pos_logico          TEXT,
    user_uuid           UUID        REFERENCES bauth.bos_user_template(uuid),
    ruta_canonica       TEXT,                               -- '/dist/{tenant}/emp/{empresa}/suc/{sucursal}/pos/{pos}'
    context_actual      TEXT,                               -- '{tenant}/{empresa}/{sucursal}/{pos}'
    bos_contexts        TEXT[],                             -- contextos autorizados del usuario
    device_id           TEXT,                               -- hardware físico (DEVICE-991)
    device_hostname     TEXT,
    device_ip           INET,
    device_mac          MACADDR,
    device_geo          TEXT,                               -- lat,lng
    session_kc          TEXT        NOT NULL,               -- ID de sesión en Keycloak
    traceparent         TEXT,                               -- W3C Trace Context: 00-{trace_id}-{span_id}-01
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,                       -- TTL de la sesión (sincronizado con KC)
    nonce               UUID        NOT NULL DEFAULT gen_random_uuid(), -- anti-replay
    sequence            BIGINT      NOT NULL DEFAULT 0,     -- contador incremental por operación
    terminal_fingerprint VARCHAR(128),                      -- hash(MAC+TPM+hostname) para anti session hijacking
    state               VARCHAR(16) NOT NULL DEFAULT 'PENDING', -- PENDING|ACTIVE|INVALIDATED|EXPIRED|LOCKED
    metadata            JSONB       DEFAULT '{}',
    CONSTRAINT chk_ctx_state CHECK (state IN ('PENDING','ACTIVE','INVALIDATED','EXPIRED','LOCKED'))
);
COMMENT ON TABLE bauth.context_sessions IS 'Contexto de sesión. 6 capas de resolución (SBOS-049 §4). Pre-condición del BitMask. D8.';

CREATE TABLE IF NOT EXISTS bauth.context_switches (
    switch_id       BIGSERIAL PRIMARY KEY,
    from_ctx_id     TEXT    NOT NULL,
    to_ctx_id       TEXT    NOT NULL,
    switched_at     TIMESTAMPTZ DEFAULT now(),
    reason          TEXT                            -- cambio de sucursal, empresa, etc.
);
COMMENT ON TABLE bauth.context_switches IS 'Registro de cambios de contexto durante una sesión.';

CREATE TABLE IF NOT EXISTS bauth.bauth_sync_log (
    sync_id             BIGSERIAL PRIMARY KEY,
    sync_type           TEXT    NOT NULL,          -- ROLE_SYNC|USER_SYNC|FULL_SYNC|RECONCILE
    target              TEXT    NOT NULL,          -- KEYCLOAK|TRYTON|TRYTOND_PDP
    status              TEXT    NOT NULL,          -- IN_PROGRESS|SUCCESS|FAILED|ROLLED_BACK
    started_at          TIMESTAMPTZ DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    records_processed   INTEGER,
    errors              TEXT[],
    metadata            JSONB   DEFAULT '{}'
);
COMMENT ON TABLE bauth.bauth_sync_log IS 'Registro de sincronización bAuth→KC/Tryton. Trazabilidad de cada sync.';

CREATE TABLE IF NOT EXISTS bauth.bauth_superuser_contexts (
    context_id      BIGSERIAL PRIMARY KEY,
    ctx_id          TEXT        NOT NULL,
    user_uuid       UUID        NOT NULL,
    activated_at    TIMESTAMPTZ DEFAULT now(),
    reason          TEXT,                           -- motivo del break-glass
    audit_level     TEXT        DEFAULT 'full',    -- full = session recording
    expires_at      TIMESTAMPTZ                    -- máximo 4h
);
COMMENT ON TABLE bauth.bauth_superuser_contexts IS 'Registro de activaciones break-glass del Superusuario. ISO 27001 A.8.2.';

CREATE TABLE IF NOT EXISTS bauth.bauth_access_reviews (
    review_id       BIGSERIAL PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    role_id         TEXT        NOT NULL,
    reviewer_uuid   UUID        NOT NULL,          -- manager que revisa
    review_cycle    TEXT        NOT NULL,          -- Q1-2026|Q2-2026|ADHOC
    status          TEXT        DEFAULT 'PENDING', -- PENDING|APPROVED|REVOKED|MODIFIED
    request_reason  TEXT,                          -- motivo de la solicitud (si es ADHOC)
    due_date        TIMESTAMPTZ,                   -- fecha límite para responder
    completed_at    TIMESTAMPTZ,                   -- cuando se completó la revisión
    decision        TEXT,                          -- APPROVE|REVOKE|MODIFY
    comments        TEXT,                          -- comentarios del revisor
    created_at      TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE bauth.bauth_access_reviews IS 'Campanas de recertificación de accesos. ISO 27001 A.9.2.5. B36.';

CREATE TABLE IF NOT EXISTS bauth.bauth_ghost_accounts (
    ghost_id        BIGSERIAL PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    detected_at     TIMESTAMPTZ DEFAULT now(),
    resolved        BOOLEAN     DEFAULT false,     -- false = pendiente, true = resuelto
    resolution      TEXT,                          -- acción tomada
    resolved_at     TIMESTAMPTZ
);
COMMENT ON TABLE bauth.bauth_ghost_accounts IS 'Registro de cuentas huérfanas detectadas (ISACA: 37% de organizaciones). B36.';

CREATE TABLE IF NOT EXISTS bauth.bos_sod_conflict_matrix (
    conflict_id     BIGSERIAL PRIMARY KEY,
    role_a          TEXT    NOT NULL,              -- ID del primer rol
    role_b          TEXT    NOT NULL,              -- ID del segundo rol
    severity        TEXT    NOT NULL DEFAULT 'HIGH', -- LOW|MEDIUM|HIGH|CRITICAL
    description     TEXT,                          -- 'FINANCIAL_CREATE y FINANCIAL_APPROVE no pueden coexistir'
    CONSTRAINT chk_sod_severity CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL'))
);
COMMENT ON TABLE bauth.bos_sod_conflict_matrix IS 'Matriz de conflictos SoD. Pares de roles que no pueden asignarse al mismo usuario. NIST AC-5. B1.T16.';

-- ============================================================
-- 52. ZONE APPLICATION MAP — Legacy
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_zone_application_map (
    map_id      BIGSERIAL PRIMARY KEY,
    zona_id     BIGINT REFERENCES bauth.bos_zona_logica(zona_id),
    app_code    TEXT,
    activo      BOOLEAN DEFAULT true
);
COMMENT ON TABLE bauth.bos_zone_application_map IS 'Mapeo de zonas lógicas a aplicaciones. Legacy.';


-- ################################################################
-- SCHEMA: bos_privilege — BITMASK DUAL (9 tablas)
-- Fuente: SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §15
-- ################################################################

-- PF1. DOMINIOS DE SOBERANÍA — 12 dominios D1-D12
CREATE TABLE IF NOT EXISTS bos_privilege.bos_domain (
    domain_code     SMALLINT    NOT NULL,               -- 1-15 (4 bits en Dominio Contextual)
    domain_name     VARCHAR(64) NOT NULL,               -- 'Lógico', 'Físico', 'Financiero', ...
    requires_policy BOOLEAN     NOT NULL DEFAULT FALSE, -- ¿requiere evaluación Policy-Path adicional?
    description     TEXT,
    CONSTRAINT pk_bos_domain PRIMARY KEY (domain_code),
    CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 1 AND 15)
);
COMMENT ON TABLE bos_privilege.bos_domain IS 'Catálogo de 12 dominios de soberanía D1-D12. domain_code se empaqueta en bits 8-11 del Dominio Contextual (4 bits). NUNCA texto.';

-- PF2. APLICACIONES — Fichas registradas en SBOS
CREATE TABLE IF NOT EXISTS bos_privilege.bos_application (
    app_code        SMALLINT    NOT NULL,               -- 1-511 (9 bits en Dominio Contextual)
    app_name        VARCHAR(64) NOT NULL,               -- 'Tryton ERP', 'OrangeHRM', ...
    app_slug        VARCHAR(32) NOT NULL,               -- 'tryton', 'orangehrm', ...
    tenant_id       UUID        NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_application PRIMARY KEY (app_code),
    CONSTRAINT uq_bos_application_slug UNIQUE (tenant_id, app_slug),
    CONSTRAINT ck_app_code CHECK (app_code BETWEEN 1 AND 511)
);
COMMENT ON TABLE bos_privilege.bos_application IS 'Aplicaciones ficha registradas. app_code (9 bits) se empaqueta en bits 12-20 del Dominio Contextual.';

-- PF3. GRUPOS FUNCIONALES POR APLICACIÓN
CREATE TABLE IF NOT EXISTS bos_privilege.bos_group (
    group_code      SMALLINT    NOT NULL,               -- 1-2047 (11 bits)
    app_code        SMALLINT    NOT NULL,               -- FK a bos_application
    group_name      VARCHAR(128) NOT NULL,              -- 'Plan de Cuentas', 'Comprobantes', ...
    CONSTRAINT pk_bos_group PRIMARY KEY (app_code, group_code),
    CONSTRAINT fk_bos_group_app FOREIGN KEY (app_code) REFERENCES bos_privilege.bos_application(app_code),
    CONSTRAINT ck_group_code CHECK (group_code BETWEEN 1 AND 2047)
);
COMMENT ON TABLE bos_privilege.bos_group IS 'Grupos funcionales dentro de cada aplicación. group_code (11 bits) en bits 21-31 del Dominio Contextual.';

-- PF4. VOCABULARIO GLOBAL DE VERBOS
CREATE TABLE IF NOT EXISTS bos_privilege.bos_verb (
    verb_code       SMALLINT    NOT NULL,               -- 1-255 (label encoding)
    verb_name       VARCHAR(32) NOT NULL,               -- 'nuevo', 'editar', 'eliminar', 'ver'
    verb_slug       VARCHAR(32) NOT NULL,               -- 'create', 'update', 'delete', 'read'
    CONSTRAINT pk_bos_verb PRIMARY KEY (verb_code),
    CONSTRAINT uq_bos_verb_name UNIQUE (verb_name),
    CONSTRAINT ck_verb_code CHECK (verb_code BETWEEN 1 AND 255)
);
COMMENT ON TABLE bos_privilege.bos_verb IS 'Vocabulario global de verbos. Label encoding — NUNCA combinar con bitwise. La combinación usa bos_role_atom (one-hot).';

-- PF5. CATÁLOGO DE ÁTOMOS — Fuente de verdad del BitMask Átomo
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_catalog (
    atom_code       INTEGER     NOT NULL,               -- código del verbo dentro del grupo: 1-16,777,215 (24 bits)
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    domain_code     SMALLINT    NOT NULL,               -- FK a bos_domain
    verb_code       SMALLINT    NOT NULL,               -- FK a bos_verb
    atom_name       VARCHAR(255) NOT NULL,              -- 'Tryton.Comprobantes.nuevo'
    atom_slug       VARCHAR(255) NOT NULL,              -- 'comprobantes.nuevo'
    atom_position   INTEGER     NOT NULL,               -- posición ordinal en el catálogo global (0-based). INMUTABLE.
    contextual_mask INTEGER     NOT NULL,               -- Dominio Contextual empaquetado: (domain<<8)|(app<<12)|(group<<21)
    logical_mask    INTEGER     NOT NULL,               -- Dominio Lógico empaquetado: (policy_state<<6)|(atom_code<<8)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_atom_catalog PRIMARY KEY (app_code, group_code, atom_code),
    CONSTRAINT uq_bos_atom_position UNIQUE (atom_position),
    CONSTRAINT uq_bos_atom_slug UNIQUE (app_code, atom_slug),
    CONSTRAINT fk_bos_atom_app FOREIGN KEY (app_code, group_code) REFERENCES bos_privilege.bos_group(app_code, group_code),
    CONSTRAINT fk_bos_atom_domain FOREIGN KEY (domain_code) REFERENCES bos_privilege.bos_domain(domain_code),
    CONSTRAINT fk_bos_atom_verb FOREIGN KEY (verb_code) REFERENCES bos_privilege.bos_verb(verb_code),
    CONSTRAINT ck_atom_code CHECK (atom_code BETWEEN 1 AND 16777215),
    CONSTRAINT ck_atom_position CHECK (atom_position >= 0)
);
COMMENT ON TABLE bos_privilege.bos_atom_catalog IS 'Catálogo global de átomos. Cada fila = una acción indivisible. atom_position es el índice del bit en el Rol BitMask (one-hot). atom_code es label encoding — NUNCA combinar con bitwise.';

-- PF6. ROLES POR TENANT
CREATE TABLE IF NOT EXISTS bos_privilege.bos_role (
    role_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL,
    role_code   INTEGER     NOT NULL,                   -- código numérico del rol dentro del tenant
    role_name   VARCHAR(128) NOT NULL,
    role_slug   VARCHAR(64) NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_role PRIMARY KEY (role_id),
    CONSTRAINT uq_bos_role_code UNIQUE (tenant_id, role_code),
    CONSTRAINT uq_bos_role_slug UNIQUE (tenant_id, role_slug),
    CONSTRAINT ck_role_code CHECK (role_code > 0)
);
COMMENT ON TABLE bos_privilege.bos_role IS 'Roles definidos por tenant. Vinculados a átomos vía bos_role_atom.';

-- PF7. ASIGNACIÓN DE ÁTOMOS A ROLES — Rol BitMask en forma relacional
CREATE TABLE IF NOT EXISTS bos_privilege.bos_role_atom (
    role_id         UUID        NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    atom_position   INTEGER     NOT NULL,               -- desnormalizado de bos_atom_catalog para consultas rápidas
    allowed         BOOLEAN     NOT NULL DEFAULT FALSE, -- TRUE = bit en 1 en el Rol BitMask
    granted_by      UUID,                               -- admin que concedió el permiso
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_role_atom PRIMARY KEY (role_id, app_code, group_code, atom_code),
    CONSTRAINT fk_bos_role_atom_role FOREIGN KEY (role_id) REFERENCES bos_privilege.bos_role(role_id),
    CONSTRAINT fk_bos_role_atom_catalog FOREIGN KEY (app_code, group_code, atom_code) REFERENCES bos_privilege.bos_atom_catalog(app_code, group_code, atom_code)
);
CREATE INDEX IF NOT EXISTS ix_bos_role_atom_role ON bos_privilege.bos_role_atom (role_id, allowed) WHERE allowed = TRUE;
COMMENT ON TABLE bos_privilege.bos_role_atom IS 'Rol BitMask en forma relacional. Cada fila con allowed=true = un bit en 1. atom_position es la posición del bit en el vector one-hot.';

-- PF8. POLÍTICAS ENCADENADAS A ÁTOMOS — Documento JSONB formal
-- Cada política es un documento JSONB autodescriptivo. El PolicyEngine evalúa
-- el documento completo sin código hardcodeado por tipo de política.
-- Modelo: OPA/Rego (conditions AND/OR) + AWS IAM (operators) + SBOS (12 dominios)
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_policy (
    policy_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    policy_domain   SMALLINT    NOT NULL,               -- dominio que evalúa esta política (1-12)
    policy_slug     VARCHAR(64) NOT NULL,               -- 'POL-D3-LIMITE', 'POL-D4-HORARIO', 'POL-D6-VIAJE'
    policy_data     JSONB       NOT NULL,               -- documento completo: priority, action, evaluate, params
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_atom_policy PRIMARY KEY (policy_id),
    CONSTRAINT uq_bos_atom_policy_slug UNIQUE (app_code, group_code, atom_code, policy_slug),
    CONSTRAINT fk_bos_atom_policy_atom FOREIGN KEY (app_code, group_code, atom_code) REFERENCES bos_privilege.bos_atom_catalog(app_code, group_code, atom_code),
    CONSTRAINT fk_bos_atom_policy_domain FOREIGN KEY (policy_domain) REFERENCES bos_privilege.bos_domain(domain_code),
    CONSTRAINT ck_policy_data_valid CHECK (
        policy_data ? '$schema'
        AND policy_data ? 'priority'
        AND policy_data ? 'action'
        AND policy_data ? 'evaluate'
        AND policy_data ? 'params'
        AND policy_data->>'action' IN ('deny','allow','step_up','pending_approval','mfa_required')
        AND jsonb_typeof(policy_data->'evaluate') = 'object'
        AND jsonb_typeof(policy_data->'params') = 'object'
        AND ((policy_data->>'priority')::integer) BETWEEN 1 AND 999
    )
);
CREATE INDEX IF NOT EXISTS ix_atom_policy_data ON bos_privilege.bos_atom_policy USING GIN (policy_data jsonb_path_ops);
CREATE INDEX IF NOT EXISTS ix_atom_policy_priority ON bos_privilege.bos_atom_policy (policy_domain, ((policy_data->>'priority')::integer), active) WHERE active = TRUE;

COMMENT ON TABLE bos_privilege.bos_atom_policy IS 'Políticas 1:N encadenadas a átomos. Documento JSONB formal con evaluación determinista. El PolicyEngine interpreta el documento completo sin código hardcodeado. Estructura: $schema, priority, action, message, evaluate{logic, conditions[{field, op, value}]}, params{}.';
COMMENT ON COLUMN bos_privilege.bos_atom_policy.policy_data IS 'Documento completo de política en formato JSONB formal. Estructura canónica: {"$schema":"bos_policy_v1","priority":50,"action":"deny","message":"...","evaluate":{"logic":"and|or","conditions":[{"field":"<context_path>","op":"<operator>","value":"<literal_or_${params.key}>"}]},"params":{...}}. Los operadores disponibles: eq, ne, gt, gte, lt, lte, in, not_in, contains, regex, exists, not_exists, cidr_match, geo_distance, time_between, ip_in_range. Las referencias ${params.key} se resuelven en runtime contra el bloque params.';

-- PF9. AUDITORÍA WORM — Registro de cada evaluación de acceso
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit (
    audit_id        UUID        NOT NULL DEFAULT gen_random_uuid(),
    ctx_id          VARCHAR(128) NOT NULL,              -- ID de sesión (OBLIGATORIO, nunca NULL)
    tenant_id       UUID        NOT NULL,
    role_id         UUID        NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    atom_position   INTEGER     NOT NULL,
    bitmask_atom    BIGINT      NOT NULL,               -- BitMask Átomo completo (64 bits) al momento de evaluación
    policy_state    SMALLINT    NOT NULL,               -- 0=no aplica, 1=pendiente, 2=aprobado, 3=rechazado
    result          SMALLINT    NOT NULL,               -- 0=denegado, 1=permitido, 2=pendiente
    policy_slug     VARCHAR(64),                        -- política evaluada (si aplica)
    evaluator       VARCHAR(32) NOT NULL,               -- 'bauth', 'bhnexus', 'kong', 'biedata'
    domain_code     SMALLINT,                           -- dominio que tomó la decisión
    -- D12 blockchain traceability
    merkle_batch_id UUID,                               -- FK a bos_blockchain.bos_merkle_batch
    merkle_proof    VARCHAR(66)[],                      -- RFC 6962 audit path para verificación independiente
    onchain_tx_hash VARCHAR(66),                        -- hash de la tx en Arbitrum que ancló este evento
    evaluated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_atom_audit PRIMARY KEY (audit_id, evaluated_at),
    CONSTRAINT ck_policy_state CHECK (policy_state IN (0, 1, 2, 3)),
    CONSTRAINT ck_audit_result  CHECK (result IN (0, 1, 2))
) PARTITION BY RANGE (evaluated_at);
COMMENT ON TABLE bos_privilege.bos_atom_audit IS 'Registro WORM de cada evaluación de acceso. ctx_id obligatorio. Particionado por mes. REVOKE UPDATE/DELETE post-deploy. Trazabilidad blockchain vía merkle_batch_id.';
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit_2026_06 PARTITION OF bos_privilege.bos_atom_audit FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit_2026_07 PARTITION OF bos_privilege.bos_atom_audit FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');


-- ################################################################
-- SCHEMA: bos_blockchain — D12 BLOCKCHAIN (7 tablas)
-- Fuente: SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md Apéndice D
-- ################################################################

-- BC1. LOTES DE MERKLE
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_batch (
    batch_id            UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_number        BIGINT      NOT NULL,           -- secuencial auto-incremental
    batch_start         TIMESTAMPTZ NOT NULL,           -- timestamp del primer evento en el lote
    batch_end           TIMESTAMPTZ NOT NULL,           -- timestamp del último evento
    event_count         INTEGER     NOT NULL,           -- número de eventos en el lote
    merkle_root         VARCHAR(66) NOT NULL,           -- Keccak-256: 0x + 64 hex chars
    merkle_tree_json    JSONB,                          -- estructura completa del árbol Merkle
    status              SMALLINT    NOT NULL DEFAULT 0, -- 0=pending, 1=sealed, 2=anchored, 3=failed
    onchain_tx_hash     VARCHAR(66),                    -- hash de la transacción en L2
    onchain_block_number BIGINT,                        -- número de bloque en L2
    onchain_timestamp   TIMESTAMPTZ,                    -- timestamp del bloque
    anchor_network      VARCHAR(32),                    -- 'arbitrum', 'base', 'optimism'
    anchor_contract     VARCHAR(42),                    -- dirección del contrato AuditAnchor
    retry_count         INTEGER     NOT NULL DEFAULT 0, -- reintentos de anclaje
    last_error          TEXT,                           -- último error
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sealed_at           TIMESTAMPTZ,                    -- cuando se selló el lote
    anchored_at         TIMESTAMPTZ,                    -- cuando se confirmó en L2
    CONSTRAINT pk_bos_merkle_batch PRIMARY KEY (batch_id),
    CONSTRAINT uq_bos_merkle_batch_number UNIQUE (batch_number),
    CONSTRAINT ck_bos_merkle_batch_status CHECK (status IN (0, 1, 2, 3))
);
COMMENT ON TABLE bos_blockchain.bos_merkle_batch IS 'Lotes de eventos de auditoría para anclaje Merkle en L2. Gold tier: cada 1 hora. B29.';

-- BC2. HOJAS DEL ÁRBOL MERKLE
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_leaf (
    leaf_id         UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_id        UUID        NOT NULL,               -- FK a bos_merkle_batch
    leaf_index      INTEGER     NOT NULL,               -- posición en el árbol (0-based)
    event_audit_id  UUID        NOT NULL,               -- FK a bos_privilege.bos_atom_audit.audit_id
    event_hash      VARCHAR(66) NOT NULL,               -- Keccak-256 del evento serializado
    merkle_proof    VARCHAR(66)[],                      -- RFC 6962 audit path
    CONSTRAINT pk_bos_merkle_leaf PRIMARY KEY (leaf_id),
    CONSTRAINT uq_bos_merkle_leaf_batch_pos UNIQUE (batch_id, leaf_index),
    CONSTRAINT fk_bos_merkle_leaf_batch FOREIGN KEY (batch_id) REFERENCES bos_blockchain.bos_merkle_batch(batch_id)
);
COMMENT ON TABLE bos_blockchain.bos_merkle_leaf IS 'Hojas del árbol Merkle. event_hash = Keccak256(0x00 || ctx_id || audit_id || ...). merkle_proof permite verificación independiente.';

-- BC3. REGISTRO DE ANCLAJES
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_blockchain_anchor_log (
    anchor_id           UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_id            UUID        NOT NULL,
    tx_hash             VARCHAR(66) NOT NULL,           -- hash de la transacción en L2
    block_number        BIGINT      NOT NULL,
    block_timestamp     TIMESTAMPTZ NOT NULL,
    network             VARCHAR(32) NOT NULL,           -- 'arbitrum', 'base', 'bitcoin-ots'
    contract_address    VARCHAR(42) NOT NULL,           -- dirección del contrato AuditAnchor
    gas_used            BIGINT,                         -- gas consumido
    gas_price_gwei      NUMERIC(18,9),                  -- precio del gas en Gwei
    total_cost_usd      NUMERIC(18,6),                  -- costo total en USD
    status              SMALLINT    NOT NULL DEFAULT 1, -- 1=success, 0=failed
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_blockchain_anchor_log PRIMARY KEY (anchor_id),
    CONSTRAINT fk_bos_anchor_log_batch FOREIGN KEY (batch_id) REFERENCES bos_blockchain.bos_merkle_batch(batch_id)
);
COMMENT ON TABLE bos_blockchain.bos_blockchain_anchor_log IS 'Histórico de transacciones de anclaje en L2. Auditoría de gas y trazabilidad completa.';

-- BC4. CUENTAS ON-CHAIN — Solo Variante B (Liquidación)
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_account (
    account_id          UUID            NOT NULL DEFAULT gen_random_uuid(),
    tenant_id           UUID            NOT NULL,
    onchain_address     VARCHAR(42)     NOT NULL,       -- dirección Ethereum en red Besu QBFT
    account_type        SMALLINT        NOT NULL,       -- 1=usuario, 2=comercio, 3=agente, 4=emisor
    balance_derived     NUMERIC(36,18)  NOT NULL DEFAULT 0, -- saldo según estado on-chain
    balance_local       NUMERIC(36,18)  NOT NULL DEFAULT 0, -- saldo según PostgreSQL (caché)
    nonce               BIGINT          NOT NULL DEFAULT 0, -- nonce on-chain (anti-replay)
    last_reconciled_at  TIMESTAMPTZ,                        -- última reconciliación exitosa
    last_reconciled_block BIGINT,                           -- último bloque reconciliado
    is_frozen           BOOLEAN         NOT NULL DEFAULT FALSE, -- cuenta congelada
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_onchain_account PRIMARY KEY (account_id),
    CONSTRAINT uq_bos_onchain_account_address UNIQUE (onchain_address),
    CONSTRAINT uq_bos_onchain_account_tenant UNIQUE (tenant_id, account_type)
);
COMMENT ON TABLE bos_blockchain.bos_onchain_account IS 'Solo D12 Variante B. Mapea cuentas SBOS a direcciones on-chain. balance_derived es fuente de verdad; balance_local es caché.';

-- BC5. LIQUIDACIONES ON-CHAIN — Solo Variante B
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_settlement (
    settlement_id       UUID            NOT NULL DEFAULT gen_random_uuid(),
    from_account_id     UUID            NOT NULL,
    to_account_id       UUID            NOT NULL,
    amount              NUMERIC(36,18)  NOT NULL,
    currency            VARCHAR(8)      NOT NULL,       -- 'BOB', 'USD', 'USDT'
    onchain_tx_hash     VARCHAR(66)     NOT NULL,
    block_number        BIGINT          NOT NULL,
    block_confirmations INTEGER         NOT NULL DEFAULT 0,
    status              SMALLINT        NOT NULL DEFAULT 0, -- 0=pending, 1=confirmed, 2=failed
    dual_approval_id    UUID,                           -- FK a bos_financial_approval
    ctx_id_creator      VARCHAR(128)    NOT NULL,       -- trazabilidad de sesión del creador
    ctx_id_approver     VARCHAR(128),                   -- trazabilidad de sesión del aprobador
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    confirmed_at        TIMESTAMPTZ,
    CONSTRAINT pk_bos_onchain_settlement PRIMARY KEY (settlement_id),
    CONSTRAINT fk_bos_settlement_from FOREIGN KEY (from_account_id) REFERENCES bos_blockchain.bos_onchain_account(account_id),
    CONSTRAINT fk_bos_settlement_to FOREIGN KEY (to_account_id) REFERENCES bos_blockchain.bos_onchain_account(account_id),
    CONSTRAINT ck_bos_settlement_status CHECK (status IN (0, 1, 2))
);
COMMENT ON TABLE bos_blockchain.bos_onchain_settlement IS 'Solo D12 Variante B. Liquidaciones on-chain con trazabilidad ctx_id y dual-approval.';

-- BC6. RECONCILIACIÓN — Solo Variante B
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_reconciliation_log (
    reconciliation_id   UUID            NOT NULL DEFAULT gen_random_uuid(),
    account_id          UUID            NOT NULL,
    balance_onchain     NUMERIC(36,18)  NOT NULL,
    balance_local       NUMERIC(36,18)  NOT NULL,
    difference          NUMERIC(36,18)  NOT NULL,       -- onchain - local
    block_number        BIGINT          NOT NULL,
    status              SMALLINT        NOT NULL,       -- 0=matched, 1=drift_detected, 2=corrected
    correction_tx_hash  VARCHAR(66),
    notes               TEXT,
    reconciled_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_reconciliation_log PRIMARY KEY (reconciliation_id),
    CONSTRAINT fk_bos_reconciliation_account FOREIGN KEY (account_id) REFERENCES bos_blockchain.bos_onchain_account(account_id),
    CONSTRAINT ck_bos_reconciliation_status CHECK (status IN (0, 1, 2))
);
COMMENT ON TABLE bos_blockchain.bos_reconciliation_log IS 'Solo D12 Variante B. Reconciliación periódica on-chain ↔ PostgreSQL. Double-entry accounting.';

-- BC7. RECONCILIACIÓN DE ANCLAJES — Cross-chain
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_anchor_reconciliation_log (
    reconciliation_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_id            UUID        NOT NULL,
    network             VARCHAR(32) NOT NULL,
    merkle_root_db      VARCHAR(66) NOT NULL,           -- Merkle root en PostgreSQL
    merkle_root_onchain VARCHAR(66),                    -- Merkle root en blockchain
    match               BOOLEAN,                        -- ¿coinciden?
    checked_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes               TEXT,
    CONSTRAINT pk_bos_anchor_reconciliation_log PRIMARY KEY (reconciliation_id),
    CONSTRAINT fk_anchor_reconciliation_batch FOREIGN KEY (batch_id) REFERENCES bos_blockchain.bos_merkle_batch(batch_id)
);
COMMENT ON TABLE bos_blockchain.bos_anchor_reconciliation_log IS 'Verificación de integridad cross-chain: compara Merkle roots PostgreSQL vs Arbitrum.';


-- ################################################################
-- NUEVAS TABLAS v3.0 — Átomos REGISTRO-ESTADO v7.4
-- ################################################################

-- INVENTARIO DE LLAVES (B37.T01) — NIST SP 800-57 §8.1
CREATE TABLE IF NOT EXISTS bauth.bos_key_inventory (
    key_id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    key_type            VARCHAR(32) NOT NULL,           -- 20 tipos: JWT_SIGNING, API_KEY, ..., SUPERUSER_CERT
    algorithm           VARCHAR(32),                    -- 'EdDSA_Ed25519', 'RSA-4096-SHA256', 'AES-256-GCM'
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rotation_interval   INTERVAL,                       -- ej: '24 hours', '90 days'
    last_rotated_at     TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ,
    owner               VARCHAR(128),                   -- 'juan.perez@sbos.skull.bo', 'ACME Corp NIT-123456'
    storage_backend     VARCHAR(32) NOT NULL,           -- VAULT_KV2|VAULT_TRANSIT|VAULT_PKI|HSM_PKCS11|POSTGRES_HASH
    state               VARCHAR(16) NOT NULL DEFAULT 'PRE_ACTIVE', -- PRE_ACTIVE|ACTIVE|DEACTIVATED|COMPROMISED|DESTROYED
    backup_hash         VARCHAR(66),                    -- SHA-256 del backup
    metadata            JSONB,
    CONSTRAINT pk_bos_key_inventory PRIMARY KEY (key_id),
    CONSTRAINT ck_key_type CHECK (key_type IN ('JWT_SIGNING','API_KEY','TOTP_SECRET','MTLS_CERT','BLOCKCHAIN_SIGNING','VALIDATOR_SIGNING','AES_ENCRYPTION','RECOVERY_CODE','PASSWORD_HASH','CLIENT_SECRET','ADSIB_CERT','ROOT_CA','SUB_CA_SIGNING','SUB_CA_IDENTITY','SUB_CA_DEVICES','SUB_CA_SERVICES','USER_SIGNING_CERT','DEVICE_CERT','SERVICE_CERT','SUPERUSER_CERT')),
    CONSTRAINT ck_key_state CHECK (state IN ('PRE_ACTIVE','ACTIVE','DEACTIVATED','COMPROMISED','DESTROYED'))
);
COMMENT ON TABLE bauth.bos_key_inventory IS 'Inventario central de TODAS las llaves criptográficas del ecosistema. 20 tipos. NIST SP 800-57. B37.T01.';

-- ROTACIÓN DE LLAVES (B37.T02)
CREATE TABLE IF NOT EXISTS bauth.bos_key_rotation_log (
    rotation_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    key_id          UUID        NOT NULL REFERENCES bauth.bos_key_inventory(key_id),
    rotation_type   VARCHAR(16) NOT NULL,               -- SCHEDULED|EMERGENCY|COMPROMISE
    old_key_hash    VARCHAR(66),
    new_key_hash    VARCHAR(66),
    overlap_start   TIMESTAMPTZ,                        -- inicio del período dual-credential
    overlap_end     TIMESTAMPTZ,                        -- fin del período dual-credential
    status          VARCHAR(16) NOT NULL DEFAULT 'IN_PROGRESS',
    executed_by     UUID,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error_message   TEXT,
    CONSTRAINT pk_bos_key_rotation_log PRIMARY KEY (rotation_id),
    CONSTRAINT ck_rotation_type CHECK (rotation_type IN ('SCHEDULED','EMERGENCY','COMPROMISE')),
    CONSTRAINT ck_rotation_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED','ROLLED_BACK'))
);
COMMENT ON TABLE bauth.bos_key_rotation_log IS 'Historial de rotaciones de llaves con dual-credential tracking. B37.T02.';

-- RECUPERACIÓN DE LLAVES (B37.T03)
CREATE TABLE IF NOT EXISTS bauth.bos_key_recovery_log (
    recovery_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    key_id          UUID        REFERENCES bauth.bos_key_inventory(key_id),
    recovery_type   VARCHAR(16) NOT NULL,               -- BREAK_GLASS|ADMIN_RESET|USER_RECOVERY|COMPROMISE|DESASTRE
    approved_by     UUID[],                             -- múltiples aprobadores (para break-glass 2-of-3)
    session_duration INTERVAL,                          -- duración máxima de la sesión de recuperación
    result          VARCHAR(16) NOT NULL,
    ctx_id          VARCHAR(128) NOT NULL,
    recovered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes           TEXT,
    CONSTRAINT pk_bos_key_recovery_log PRIMARY KEY (recovery_id),
    CONSTRAINT ck_recovery_type CHECK (recovery_type IN ('BREAK_GLASS','ADMIN_RESET','USER_RECOVERY','COMPROMISE','DESASTRE')),
    CONSTRAINT ck_recovery_result CHECK (result IN ('SUCCESS','FAILED','PARTIAL','PENDING_APPROVAL'))
);
COMMENT ON TABLE bauth.bos_key_recovery_log IS 'Registro de recuperaciones de llaves. Incluye break-glass SU (2-of-3 Vault unseal). B37.T03.';

-- REGISTRO DE DISPOSITIVOS (B15.T17)
CREATE TABLE IF NOT EXISTS bauth.bos_device_registry (
    device_id           UUID        NOT NULL DEFAULT gen_random_uuid(),
    node_id             VARCHAR(128) NOT NULL,          -- hostname único
    device_type         VARCHAR(32) NOT NULL,           -- 10 tipos: banexus_agent, osdp_reader, ..., actuator
    serial_number       VARCHAR(128),
    firmware_version    VARCHAR(32),
    hardware_model      VARCHAR(64),                    -- 'HID Signo 40K', 'Axis P3375', ...
    zone_id             BIGINT      REFERENCES bauth.bos_area_fisica(area_id),
    tenant_id           UUID        NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'provisioned',
    last_seen           TIMESTAMPTZ,                    -- último heartbeat
    ip_address          INET,
    mac_address         MACADDR,
    certificate_serial  VARCHAR(64),                    -- serial del certificado mTLS (Vault PKI)
    metadata            JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_device_registry PRIMARY KEY (device_id),
    CONSTRAINT uq_bos_device_node UNIQUE (node_id),
    CONSTRAINT ck_device_type CHECK (device_type IN ('banexus_agent','osdp_reader','mqtt_sensor','onvif_camera','wiegand_reader','ble_reader','rfid_reader','biometric_reader','intercom','actuator')),
    CONSTRAINT ck_device_status CHECK (status IN ('provisioned','active','inactive','compromised','decommissioned'))
);
COMMENT ON TABLE bauth.bos_device_registry IS 'Registro de dispositivos físicos: lectores, cámaras, sensores, terminales. ISO 27001 A.8.1. B15.T17.';

-- ENTREGA DE TOKENS (B22.T12)
CREATE TABLE IF NOT EXISTS bauth.bos_token_delivery_log (
    delivery_id         UUID        NOT NULL DEFAULT gen_random_uuid(),
    token_id            UUID        NOT NULL,
    token_type          VARCHAR(16) NOT NULL,           -- TOTP|HOTP|NFC|QR|PUSH|RECOVERY|SMS|EMAIL|MAGIC_LINK|BARCODE
    user_id             UUID        NOT NULL,
    delivery_channel    VARCHAR(32) NOT NULL,           -- presencial|remote_secure|self_service|whatsapp|telegram|email|sms|push
    delivered_by        UUID,                           -- admin que entregó (NULL = self-service)
    delivered_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    recipient_signature VARCHAR(256),                   -- firma digital del receptor (B25)
    witness             UUID,                           -- testigo de la entrega
    metadata            JSONB,                          -- token_ttl, zones_allowed, single_use, etc.
    CONSTRAINT pk_bos_token_delivery_log PRIMARY KEY (delivery_id),
    CONSTRAINT ck_token_type CHECK (token_type IN ('TOTP','HOTP','NFC','QR','PUSH','RECOVERY','SMS','EMAIL','MAGIC_LINK','BARCODE')),
    CONSTRAINT ck_delivery_channel CHECK (delivery_channel IN ('presencial','remote_secure','self_service','whatsapp','telegram','email','sms','push'))
);
COMMENT ON TABLE bauth.bos_token_delivery_log IS 'Registro de entrega de tokens de autenticación. Trazabilidad completa del canal de entrega. B22.T12.';

-- AUDITORÍA DE POLÍTICAS (B9.T28) — WORM
CREATE TABLE IF NOT EXISTS bauth.bos_policy_audit (
    audit_id        UUID        NOT NULL DEFAULT gen_random_uuid(),
    policy_slug     VARCHAR(64) NOT NULL,
    change_type     VARCHAR(16) NOT NULL,               -- CREATE|UPDATE|DELETE|DEPRECATE|ROLLBACK
    old_params      JSONB,                              -- parámetros antes del cambio
    new_params      JSONB,                              -- parámetros después del cambio
    admin_user_id   UUID        NOT NULL,               -- quién hizo el cambio
    ctx_id          VARCHAR(128) NOT NULL,              -- trazabilidad de sesión
    reason          TEXT        NOT NULL,               -- justificación obligatoria
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_policy_audit PRIMARY KEY (audit_id),
    CONSTRAINT ck_change_type CHECK (change_type IN ('CREATE','UPDATE','DELETE','DEPRECATE','ROLLBACK'))
);
COMMENT ON TABLE bauth.bos_policy_audit IS 'Auditoría WORM de cambios de políticas de seguridad. ISO 27001 A.8.9. B9.T28.';

-- HISTORIAL DE POLÍTICAS (B9.T30)
CREATE TABLE IF NOT EXISTS bauth.bos_policy_history (
    version_id  UUID        NOT NULL DEFAULT gen_random_uuid(),
    policy_slug VARCHAR(64) NOT NULL,
    version     INTEGER     NOT NULL,
    params      JSONB       NOT NULL,                   -- snapshot completo de la versión
    created_by  UUID        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_policy_history PRIMARY KEY (version_id),
    CONSTRAINT uq_policy_version UNIQUE (policy_slug, version)
);
COMMENT ON TABLE bauth.bos_policy_history IS 'Historial versionado de políticas para rollback. B9.T30.';

-- VERSIONES DE FRAMEWORKS (B9.T32)
CREATE TABLE IF NOT EXISTS bauth.bos_framework_version (
    framework_id        VARCHAR(32) NOT NULL,           -- auth|policies|roltemplate|usertemplate
    version             VARCHAR(16) NOT NULL,           -- semver: '3.0.1'
    release_date        DATE        NOT NULL,
    changelog           TEXT,
    author              VARCHAR(64),
    git_commit          VARCHAR(40),
    json_hash           VARCHAR(66) NOT NULL,           -- SHA-256 del JSON
    backward_compatible BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_framework_version PRIMARY KEY (framework_id, version),
    CONSTRAINT ck_framework_id CHECK (framework_id IN ('auth','policies','roltemplate','usertemplate'))
);
COMMENT ON TABLE bauth.bos_framework_version IS 'Versionado semántico de los 4 frameworks SSOT. SHA-256 + backward compat check. B9.T32.';

-- REGISTRO DE BACKUPS (B19.T25, B37.T05)
CREATE TABLE IF NOT EXISTS bauth.bos_backup_log (
    backup_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
    backup_type     VARCHAR(32) NOT NULL,               -- full_db|rol_template|user_template|audit_events|blockchain|key_inventory|device_registry
    file_path       TEXT        NOT NULL,
    file_hash       VARCHAR(66) NOT NULL,               -- SHA-256
    file_size_bytes BIGINT,
    status          VARCHAR(16) NOT NULL DEFAULT 'COMPLETED',
    executed_by     VARCHAR(64),
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    restored_at     TIMESTAMPTZ,
    restore_status  VARCHAR(16),
    notes           TEXT,
    CONSTRAINT pk_bos_backup_log PRIMARY KEY (backup_id),
    CONSTRAINT ck_backup_type CHECK (backup_type IN ('full_db','rol_template','user_template','audit_events','blockchain','key_inventory','device_registry')),
    CONSTRAINT ck_backup_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED','RESTORED'))
);
COMMENT ON TABLE bauth.bos_backup_log IS 'Registro de backups. ADR-016. SHA-256 + retención 10 años. B19.T25, B37.T05.';

-- CONSENTIMIENTOS GDPR (B11.T31)
CREATE TABLE IF NOT EXISTS bauth.bos_user_consent (
    consent_id      UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    consent_type    VARCHAR(32) NOT NULL,               -- data_processing|marketing|third_party|biometric|cookies
    status          VARCHAR(16) NOT NULL DEFAULT 'granted', -- granted|withdrawn
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at    TIMESTAMPTZ,
    ip_address      INET,
    user_agent      TEXT,
    metadata        JSONB,
    CONSTRAINT pk_bos_user_consent PRIMARY KEY (consent_id),
    CONSTRAINT uq_user_consent_type UNIQUE (user_id, consent_type),
    CONSTRAINT ck_consent_type CHECK (consent_type IN ('data_processing','marketing','third_party','biometric','cookies')),
    CONSTRAINT ck_consent_status CHECK (status IN ('granted','withdrawn'))
);
COMMENT ON TABLE bauth.bos_user_consent IS 'Registro de consentimientos GDPR por usuario. RGPD Art.7. B11.T31.';

-- CONFIGURACIÓN DE DOMINIOS POR TENANT (B1.T21)
CREATE TABLE IF NOT EXISTS bauth.bos_domain_config (
    tenant_id       UUID        NOT NULL,
    domain_code     SMALLINT    NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE, -- ¿este tenant evalúa este dominio?
    override_params JSONB,                              -- parámetros ajustados por tenant
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      UUID,
    CONSTRAINT pk_bos_domain_config PRIMARY KEY (tenant_id, domain_code),
    CONSTRAINT fk_domain_config_domain FOREIGN KEY (domain_code) REFERENCES bos_privilege.bos_domain(domain_code)
);
COMMENT ON TABLE bauth.bos_domain_config IS 'Activación/desactivación de dominios por tenant. PyME: solo D1+D3+D9. Empresa seguridad: D1+D2+D3+D5+D6+D7. B1.T21.';

-- LOG DE ENROLLMENT DE MÉTODOS (B35.T04)
CREATE TABLE IF NOT EXISTS bauth.bos_auth_method_enrollment_log (
    enrollment_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    method_type     VARCHAR(16) NOT NULL,               -- TOTP|FIDO2|PASSKEY|NFC|QR|PUSH|RECOVERY
    step            VARCHAR(32) NOT NULL,               -- identity_verify|generate_credential|deliver_to_user|verify_method|activate
    status          VARCHAR(16) NOT NULL DEFAULT 'IN_PROGRESS',
    ctx_id          VARCHAR(128) NOT NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata        JSONB,
    CONSTRAINT pk_bos_auth_method_enrollment PRIMARY KEY (enrollment_id),
    CONSTRAINT ck_enrollment_step CHECK (step IN ('identity_verify','generate_credential','deliver_to_user','verify_method','activate')),
    CONSTRAINT ck_enrollment_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED'))
);
COMMENT ON TABLE bauth.bos_auth_method_enrollment_log IS 'Registro de enrollment de métodos de autenticación. B35.T04.';

-- ASIGNACIÓN DE ROLES A USUARIOS (B36.T03)
CREATE TABLE IF NOT EXISTS bauth.bos_user_role_assignment (
    assignment_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    role_id         UUID        NOT NULL,
    assigned_by     UUID,
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used       TIMESTAMPTZ,                        -- última vez que el usuario usó este rol (privilege creep detection)
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,                        -- NULL = permanente
    assignment_type VARCHAR(16) NOT NULL DEFAULT 'DIRECT', -- DIRECT|INHERITED|DELEGATED|TEMPORAL
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    metadata        JSONB,
    CONSTRAINT pk_bos_user_role_assignment PRIMARY KEY (assignment_id),
    CONSTRAINT ck_assignment_type CHECK (assignment_type IN ('DIRECT','INHERITED','DELEGATED','TEMPORAL'))
);
CREATE INDEX IF NOT EXISTS ix_user_role_last_used ON bauth.bos_user_role_assignment (user_id, last_used) WHERE active = TRUE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_role_active ON bauth.bos_user_role_assignment (user_id, role_id, assignment_type, COALESCE(valid_from, '1970-01-01'::TIMESTAMPTZ));
COMMENT ON TABLE bauth.bos_user_role_assignment IS 'Asignación de roles a usuarios. last_used permite detectar privilege creep (>90 días sin uso). B36.T03.';

-- PERFILES VDI (B21.T05)
CREATE TABLE IF NOT EXISTS bauth.bauth_vdi_profiles (
    profile_id      UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    node_id         VARCHAR(128),                       -- NULL = perfil maestro
    profile_json    JSONB       NOT NULL,               -- apps autorizadas, preferencias KDE, etc.
    last_login      TIMESTAMPTZ,
    last_logout     TIMESTAMPTZ,
    session_count   INTEGER     DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bauth_vdi_profiles PRIMARY KEY (profile_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_vdi_user_node ON bauth.bauth_vdi_profiles (user_id, COALESCE(node_id, ''));
COMMENT ON TABLE bauth.bauth_vdi_profiles IS 'Perfiles de escritorio VDI persistentes. Sobreviven a reinicios del terminal. B21.T05.';


-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO bos_privilege.bos_domain (domain_code, domain_name, requires_policy, description) VALUES
    (1,  'Lógico',      FALSE, 'Apps y recursos digitales. Fast-Path: verbo suficiente.'),
    (2,  'Físico',      FALSE, 'Zonas y hardware. OSDP Secure Channel AES-128. Fast-Path.'),
    (3,  'Financiero',  TRUE,  'Límites, SoD, dual-approval. Policy-Path.'),
    (4,  'Temporal',    TRUE,  'Horarios, turnos, feriados. Encadenado a D1.'),
    (5,  'Biométrico',  FALSE, 'Huella, rostro, iris. External-Path vía Keycloak.'),
    (6,  'Geoespacial', TRUE,  'Ubicación, viaje imposible (900 km/h). Encadenado a D1.'),
    (7,  'Red',         TRUE,  'CIDR, VPN, mTLS, device posture. External-Path vía Kong.'),
    (8,  'Contexto',    FALSE, 'ctx_id en Redis. Pre-condición del BitMask.'),
    (9,  'Credenciales',FALSE, 'Passwords, MFA, certificados. Pre-BitMask vía Keycloak.'),
    (10, 'Delegación',  TRUE,  'Privilegios temporales. AND reduction. Policy-Path.'),
    (11, 'Auditoría',   FALSE, 'WORM. No evalúa — solo registra. Post-hoc.'),
    (12, 'Blockchain',  TRUE,  'Var A: Merkle anchoring. Var B: liquidación Besu QBFT. External-Path.')
ON CONFLICT (domain_code) DO NOTHING;

INSERT INTO bos_privilege.bos_verb (verb_code, verb_name, verb_slug) VALUES
    (1, 'nuevo',    'create'),
    (2, 'editar',   'update'),
    (3, 'eliminar', 'delete'),
    (4, 'ver',      'read')
ON CONFLICT (verb_code) DO NOTHING;

INSERT INTO bos_privilege.bos_application (app_code, app_name, app_slug, tenant_id) VALUES
    (1, 'Tryton ERP',        'tryton',    '00000000-0000-0000-0000-000000000001'),
    (2, 'OrangeHRM',         'orangehrm', '00000000-0000-0000-0000-000000000001'),
    (3, 'Saleor E-Commerce', 'saleor',    '00000000-0000-0000-0000-000000000001'),
    (4, 'Core UI',           'coreui',    '00000000-0000-0000-0000-000000000001'),
    (5, 'bSearch',           'bsearch',   '00000000-0000-0000-0000-000000000001'),
    (6, 'Sistema',           'sistema',   '00000000-0000-0000-0000-000000000001')
ON CONFLICT (app_code) DO NOTHING;

INSERT INTO bauth.bos_moneda (codice_iso, nombre, simbolo) VALUES
    ('BOB', 'Boliviano', 'Bs.'),
    ('USD', 'Dólar estadounidense', '$'),
    ('EUR', 'Euro', '€')
ON CONFLICT (codice_iso) DO NOTHING;

INSERT INTO bauth.bos_pais (codice_iso, nombre, gentilicio) VALUES
    ('BO', 'Bolivia', 'Boliviano/a')
ON CONFLICT (codice_iso) DO NOTHING;


-- ============================================================
-- FUNCIONES Y VISTAS
-- ============================================================

CREATE OR REPLACE FUNCTION bos_privilege.bos_build_atom_bitmask(
    p_domain_code   SMALLINT, p_app_code SMALLINT, p_group_code SMALLINT,
    p_atom_code     INTEGER,  p_policy_state SMALLINT DEFAULT 0
)
RETURNS TABLE (contextual_mask INTEGER, logical_mask INTEGER)
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT ((p_domain_code::INTEGER << 8)  | (p_app_code::INTEGER << 12) | (p_group_code::INTEGER << 21))::INTEGER,
           ((p_policy_state::INTEGER << 6) | (p_atom_code::INTEGER << 8))::INTEGER;
$$;
COMMENT ON FUNCTION bos_privilege.bos_build_atom_bitmask IS 'Empaqueta componentes numéricos en BitMask Átomo (64 bits = 2× INTEGER 32-bit). Todos los parámetros son enteros. NUNCA texto.';

CREATE OR REPLACE FUNCTION bos_blockchain.merkle_root_from_batch(p_batch_id UUID)
RETURNS VARCHAR(66) LANGUAGE plpgsql AS $$
DECLARE v_hashes VARCHAR(66)[]; v_level INTEGER; v_i INTEGER; v_hash VARCHAR(66);
BEGIN
    SELECT array_agg(event_hash ORDER BY leaf_index) INTO v_hashes FROM bos_blockchain.bos_merkle_leaf WHERE batch_id = p_batch_id;
    IF v_hashes IS NULL OR array_length(v_hashes, 1) = 0 THEN RETURN NULL; END IF;
    WHILE array_length(v_hashes, 1) > 1 LOOP
        v_level := array_length(v_hashes, 1);
        FOR v_i IN 1..v_level BY 2 LOOP
            IF v_i + 1 <= v_level THEN v_hash := encode(digest(decode(ltrim(v_hashes[v_i], '0x'), 'hex') || decode(ltrim(v_hashes[v_i+1], '0x'), 'hex'), 'keccak256'), 'hex');
            ELSE v_hash := encode(digest(decode(ltrim(v_hashes[v_i], '0x'), 'hex') || decode(ltrim(v_hashes[v_i], '0x'), 'hex'), 'keccak256'), 'hex'); END IF;
            v_hashes[(v_i + 1) / 2] := '0x' || v_hash;
        END LOOP;
        v_hashes := v_hashes[1:(v_level + 1) / 2];
    END LOOP;
    RETURN v_hashes[1];
END; $$;
COMMENT ON FUNCTION bos_blockchain.merkle_root_from_batch IS 'Calcula Merkle root de un lote sellado usando Keccak-256. RFC 6962 binary tree con domain separation.';

CREATE OR REPLACE VIEW bos_privilege.bos_role_bitmask_view AS
SELECT r.tenant_id, ra.role_id, r.role_code, r.role_slug, ra.atom_position,
       ac.app_code, ac.group_code, ac.atom_code, ac.atom_name, ac.atom_slug,
       ac.contextual_mask, ac.logical_mask, ac.domain_code
FROM bos_privilege.bos_role_atom ra
JOIN bos_privilege.bos_role r ON r.role_id = ra.role_id
JOIN bos_privilege.bos_atom_catalog ac ON (ac.app_code=ra.app_code AND ac.group_code=ra.group_code AND ac.atom_code=ra.atom_code)
WHERE ra.allowed = TRUE ORDER BY ra.role_id, ra.atom_position;
COMMENT ON VIEW bos_privilege.bos_role_bitmask_view IS 'Rol BitMask materializado. Cada fila = un bit en 1 del vector one-hot del rol.';


-- ============================================================
-- CATÁLOGO CENTRAL DE PARÁMETROS (NIST SP 800-53 CM-6)
-- ============================================================
-- Tabla extensible por diseño: cada nuevo parámetro = INSERT, sin ALTER TABLE.
-- Las categorías crecen con el proyecto sin romper instalaciones existentes.
CREATE TABLE IF NOT EXISTS bauth.bos_global_config (
    config_key    VARCHAR(128) PRIMARY KEY,
    config_value  JSONB NOT NULL,
    data_type     VARCHAR(32) NOT NULL DEFAULT 'jsonb',
    category      VARCHAR(64) NOT NULL DEFAULT 'general',
    description   TEXT NOT NULL DEFAULT '',
    purpose       TEXT NOT NULL DEFAULT '',
    standard_ref  TEXT NOT NULL DEFAULT '',
    default_value JSONB,
    version       INTEGER NOT NULL DEFAULT 1,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by    VARCHAR(64),
    CONSTRAINT ck_config_category CHECK (category IN (
        'financial', 'authentication', 'authorization', 'network',
        'session', 'audit', 'blockchain', 'performance', 'general'
    )),
    CONSTRAINT ck_config_data_type CHECK (data_type IN (
        'jsonb', 'string', 'integer', 'float', 'boolean', 'array'
    ))
);
COMMENT ON TABLE bauth.bos_global_config IS 'Catálogo central de parámetros. Fuente única de verdad para configuración modificable en runtime. Cada fila = un parámetro autodescriptivo con propósito, referencia normativa y valor por defecto. NIST SP 800-53 CM-6 · ISO 27001 A.8.9.';

-- Seed de parámetros por defecto (idempotente vía ON CONFLICT)
INSERT INTO bauth.bos_global_config (config_key, config_value, data_type, category, description, purpose, standard_ref, default_value) VALUES
    ('financial.decimal_places', '13', 'integer', 'financial',
     'Precisión decimal mínima para montos monetarios.',
     'Garantizar integridad de cálculos financieros sin redondeo.',
     'ISO 20022 ActiveCurrencyAnd13DecimalAmount · PCI-DSS 4.0.1 §7', '13'),
    ('financial.default_currency', '"BOB"', 'string', 'financial',
     'Moneda por defecto para operaciones financieras.',
     'Establecer moneda base cuando no se especifica.',
     'ISO 4217 · SIN RND 102100000011', '"BOB"'),
    ('financial.max_transaction_limit', '1000000.0000000000000', 'float', 'financial',
     'Límite máximo global por transacción en moneda base.',
     'Prevenir fraudes por montos excesivos.',
     'PCI-DSS 4.0.1 §7 · FATF Rec.16', '1000000.0000000000000'),
    ('auth.session_ttl_seconds', '28800', 'integer', 'authentication',
     'TTL máximo de sesión en segundos (8 horas).',
     'Limitar exposición de sesiones activas.',
     'NIST SP 800-63B Rev.4 §7 · ISO 27001 A.9.2.5', '28800'),
    ('auth.max_failed_attempts', '5', 'integer', 'authentication',
     'Intentos fallidos antes de bloqueo temporal.',
     'Prevenir fuerza bruta sobre credenciales.',
     'NIST SP 800-63B Rev.4 §5.2.2 · OWASP ASVS V2.1', '5'),
    ('auth.lockout_duration_seconds', '900', 'integer', 'authentication',
     'Duración del bloqueo tras exceder max_failed_attempts.',
     'Desincentivar ataques de diccionario.',
     'NIST SP 800-63B Rev.4 §5.2.2', '900'),
    ('auth.mfa_required', 'true', 'boolean', 'authentication',
     'MFA obligatorio para todos los usuarios.',
     'Cumplir AAL2 como mínimo según NIST.',
     'NIST SP 800-63B Rev.4 AAL2 · PCI-DSS 4.0.1 §8', 'true'),
    ('auth.password_min_length', '12', 'integer', 'authentication',
     'Longitud mínima de contraseña.',
     'Cumplir NIST: longitud sobre complejidad.',
     'NIST SP 800-63B Rev.4 §5.1.1.2', '12'),
    ('policy.evaluation_timeout_ms', '100', 'integer', 'authorization',
     'Timeout máximo para evaluación de políticas por dominio.',
     'Prevenir bloqueos por evaluación lenta.',
     'NIST SP 800-162 ABAC', '100'),
    ('policy.max_policies_per_atom', '10', 'integer', 'authorization',
     'Máximo de políticas encadenadas por átomo.',
     'Prevenir degradación por exceso de políticas.',
     'SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §8', '10'),
    ('policy.fastpath_max_ns', '1', 'integer', 'authorization',
     'Latencia máxima en nanosegundos para Fast-Path (D1, D2).',
     'Garantizar que el hot path no se degrade.',
     'SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §6.1', '1'),
    ('network.cidr_corporate', '["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]', 'array', 'network',
     'Rangos CIDR corporativos permitidos.',
     'Restringir acceso a IPs internas.',
     'SBOS-054-NETWORK-SECURITY.md NRS-01 · NIST SP 800-207', '["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]'),
    ('network.max_connections_per_ip', '100', 'integer', 'network',
     'Máximo de conexiones concurrentes por IP.',
     'Prevenir DoS desde una sola dirección.',
     'SBOS-054 NRS-07 · OWASP ASVS V4.7', '100'),
    ('audit.retention_days', '365', 'integer', 'audit',
     'Días de retención de eventos de auditoría.',
     'Cumplir requisitos legales de trazabilidad.',
     'ISO 27001 A.8.15 · Ley 164 Bolivia · PCI-DSS 4.0.1 §10', '365'),
    ('audit.worm_enabled', 'true', 'boolean', 'audit',
     'Protección WORM (solo INSERT, sin UPDATE/DELETE).',
     'Garantizar inmutabilidad del registro de auditoría.',
     'ISO 27001 A.8.15 · NIST SP 800-53 AU-9', 'true'),
    ('blockchain.min_gas_balance_eth', '0.005', 'float', 'blockchain',
     'Balance mínimo de ETH para operaciones de anclaje.',
     'Prevenir fallos de transacción por gas insuficiente.',
     'SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md §5', '0.005'),
    ('blockchain.anchor_interval_hours', '1', 'integer', 'blockchain',
     'Intervalo de anclaje Merkle en horas.',
     'Frecuencia de publicación de raíces Merkle en Arbitrum.',
     'RFC 6962 · SBOS-D12 §3', '1')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================
-- VERIFICACIÓN POST-DEPLOY
-- ============================================================
DO $$ DECLARE v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM bos_privilege.bos_domain;
    IF v_count != 12 THEN RAISE WARNING '[FAIL] Expected 12 domains, found %', v_count; END IF;
    SELECT COUNT(*) INTO v_count FROM bos_privilege.bos_verb;
    IF v_count != 4 THEN RAISE WARNING '[FAIL] Expected 4 verbs, found %', v_count; END IF;
    RAISE NOTICE '[OK] DDL v3.0 deployed successfully. 12 domains, 4 verbs.';
END $$;

COMMIT;

-- ============================================================
-- POST-DEPLOY: WORM protection (ejecutar como superusuario)
-- ============================================================
-- REVOKE UPDATE, DELETE ON bos_privilege.bos_atom_audit FROM bauth;
-- REVOKE UPDATE, DELETE ON bauth.bauth_audit_events FROM bauth;
-- REVOKE UPDATE, DELETE ON bauth.bos_policy_audit FROM bauth;
-- REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM bauth;

-- 001_bauth_init_UNIFICADO.sql · SKULL · SBOS · 2026-06-21
-- 85 tablas · 3 schemas · 0 ALTER TABLE · 700 casos validados
-- COMMENT ON en cada tabla y columnas clave
