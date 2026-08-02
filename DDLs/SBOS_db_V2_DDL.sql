-- ======================================================================
-- SBOS_db_V2_DDL.sql — bAuth Identity Governance Platform
-- Base de datos: SBOS_db · Schema principal: bauth, bglobal, bcalendar
-- PostgreSQL 18.4 · UUIDv7 nativo · WITHOUT OVERLAPS (temporal)
-- Versión: 2.1.0 · Fecha: 2026-07-30 · Renombrado: identificadores SQL español→inglés
--
-- ALCANCE: 67 tablas definidas en A.65.02 v1.3 (9 secciones con diseño aprobado)
--   GLOBAL · TENANT · ROLES · VERSIONADO · IDENTIDAD · CALENDARIO
--   SESIÓN · PRIVILEGIOS · AUDITORÍA · RIESGO/ITDR · PAM
--   Pendiente: USUARIOS · AUTENTICACIÓN · FIRMA DIGITAL · FEDERACIÓN/OIDC · DISPOSITIVOS
--
-- DISEÑO: Construido según A.65.02 v1.3 desde cero.
--   Tablas GLOBAL/TENANT/CALENDARIO: adaptadas de sbos_00 con reparaciones (ADR-010).
--   Tablas ROLES/PRIVILEGIOS/IDENTIDAD/SESIÓN/PAM: diseño nuevo.
--
-- IDEMPOTENCIA: Ejecutable N veces.
--   IF NOT EXISTS en todo CREATE · COMMENT ON es idempotente
--   ENUMs con guard EXCEPTION WHEN duplicate_object
--
-- REPARACIONES vs sbos_00 (ADR-010 — bAuth autosuficiente):
--   ✗ realm_kc / realm_kc_ext — Keycloak eliminado
--   ✗ namespace_k8s — infra K8s pertenece a BOS
--   ✗ database_name / database_schema — infra pertenece a BOS
--   ✗ kong_consumer_id — Kong PEP config pertenece a BOS
--   ✗ nginx_config / k8s_hpa_config / health_config — infra BOS
--
-- Ejecución:
--   psql -U postgres -d SBOS_db -f SBOS_db_V2_DDL.sql
-- ======================================================================

SET lock_timeout         = '5s';
SET client_min_messages  = WARNING;

-- ══════════════════════════════════════════════════════════════════════
-- ROLES DE BASE DE DATOS — deben existir antes de los REVOKE/GRANT
-- ══════════════════════════════════════════════════════════════════════
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bauth_app_role') THEN
        CREATE ROLE bauth_app_role;
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════
-- SCHEMAS
-- ══════════════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS bauth;       -- Núcleo de identidad (idn_, ses_, aud_, risk_, pam_)
CREATE SCHEMA IF NOT EXISTS bglobal;     -- Catálogos ISO globales (global_, geo_, menu_)
CREATE SCHEMA IF NOT EXISTS bcalendar;   -- Calendario fiscal (cal_)

-- ══════════════════════════════════════════════════════════════════════
-- EXTENSIONES
-- ══════════════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- is_required por WITHOUT OVERLAPS (PG18) en T-152

-- ══════════════════════════════════════════════════════════════════════
-- ENUM TYPES — Dominios controlados (guard de idempotencia)
-- ══════════════════════════════════════════════════════════════════════

-- --- GLOBAL / IDIOMA ---
DO $$ BEGIN CREATE TYPE language_scope_enum    AS ENUM ('individual','macrolanguage','special','collection'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0020] → A.65.04
DO $$ BEGIN CREATE TYPE language_type_enum     AS ENUM ('living','extinct','ancient','constructed','historic'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0021] → A.65.04
DO $$ BEGIN CREATE TYPE text_direction_enum    AS ENUM ('ltr','rtl','ttb'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0022] → A.65.04
DO $$ BEGIN CREATE TYPE translation_status_enum AS ENUM ('COMPLETE','PARTIAL','MACHINE_TRANSLATED','NOT_TRANSLATED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0023] → A.65.04
DO $$ BEGIN CREATE TYPE menu_type_enum         AS ENUM ('HIERARCHICAL','CONTEXTUAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0056] → A.65.04
DO $$ BEGIN CREATE TYPE global_param_scope_enum AS ENUM ('global','security','calendar','auth','policy','billing'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0048] → A.65.04
DO $$ BEGIN CREATE TYPE global_param_type_enum  AS ENUM ('TEXT','INTEGER','BOOLEAN','JSON','DECIMAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0049] → A.65.04

-- --- TENANT ---
DO $$ BEGIN CREATE TYPE tenant_status_enum       AS ENUM ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','MAINTENANCE','SOFT_DELETED','TERMINATED','PURGED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0010] → A.65.04
DO $$ BEGIN CREATE TYPE tenant_type_enum         AS ENUM ('STANDARD','REGULATED','HIGH_SENSITIVITY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0011] → A.65.04
DO $$ BEGIN CREATE TYPE isolation_level_enum     AS ENUM ('ROW_LEVEL','SCHEMA_PER_TENANT','DB_PER_TENANT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0007] → A.65.04
DO $$ BEGIN CREATE TYPE subscription_status_enum AS ENUM ('TRIAL','ACTIVE','PAST_DUE','CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0009] → A.65.04
DO $$ BEGIN CREATE TYPE plan_tier_enum           AS ENUM ('BASIC','PRO','ENTERPRISE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0008] → A.65.04
DO $$ BEGIN CREATE TYPE provisioning_status_enum AS ENUM ('PENDING','INFRA_PROVISIONING','SCHEMA_CREATED','IDP_CONFIGURED','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0012] → A.65.04
DO $$ BEGIN CREATE TYPE audit_level_enum         AS ENUM ('basic','full'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0006] → A.65.04
DO $$ BEGIN CREATE TYPE verification_step_enum   AS ENUM ('IDENTITY_CHECK','LEGAL_CHECK','TECHNICAL_SETUP','SECURITY_REVIEW','FINAL_APPROVAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0019] → A.65.04
DO $$ BEGIN CREATE TYPE verification_status_enum AS ENUM ('PENDING','IN_PROGRESS','PASSED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0018] → A.65.04
DO $$ BEGIN CREATE TYPE domain_type_enum         AS ENUM ('WEB','API','POS','ADMIN','PORTAL','STATIC','MAIL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0014] → A.65.04
DO $$ BEGIN CREATE TYPE domain_status_enum       AS ENUM ('PENDING','VERIFIED','FAILED','DEPLOYING','DEPLOYED','HEALTHY','DEGRADED','UNHEALTHY','UNKNOWN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0013] → A.65.04
DO $$ BEGIN CREATE TYPE network_type_enum        AS ENUM ('LAN','WAN','VPN','DMZ','GUEST','MANAGEMENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0015] → A.65.04
DO $$ BEGIN CREATE TYPE calendar_owner_type_enum AS ENUM ('TENANT','COMPANY','BRANCH','USER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0052] → A.65.04
DO $$ BEGIN CREATE TYPE calendar_role_enum       AS ENUM ('OWNER','EDITOR','VIEWER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0051] → A.65.04

-- --- CALENDARIO ---
DO $$ BEGIN CREATE TYPE fiscal_year_status_enum  AS ENUM ('OPEN','CLOSED','CLOSED_WITH_ADJUSTMENTS','ARCHIVED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0053] → A.65.04
DO $$ BEGIN CREATE TYPE calendar_type_enum       AS ENUM ('WORK','FISCAL','PROCESS','COMPLIANCE','HOLIDAY','MAINTENANCE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0050] → A.65.04
DO $$ BEGIN CREATE TYPE alarm_channel_enum       AS ENUM ('EMAIL','SMS','WHATSAPP','PUSH','CHAT','UI'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0055] → A.65.04
DO $$ BEGIN CREATE TYPE schedule_status_enum     AS ENUM ('OPEN','CLOSED','LUNCH','BREAK','OVERTIME'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0054] → A.65.04

-- --- ROLES ---
DO $$ BEGIN CREATE TYPE rol_tier_enum            AS ENUM ('SU','T0','T1','BIZ_N1','BIZ_N2','BIZ_N3','BIZ_N4','BIZ_N5','EXT_N0','M2M','VISITOR'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0025] → A.65.04
DO $$ BEGIN CREATE TYPE rol_status_enum          AS ENUM ('ACTIVE','INACTIVE','DEPRECATED','ARCHIVED','SUSPENDED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0024] → A.65.04
-- B02 §lifecycle — agregar IN_REVIEW (NIST AC-2 revisión periódica IGA)
ALTER TYPE rol_status_enum ADD VALUE IF NOT EXISTS 'IN_REVIEW' AFTER 'SUSPENDED';
DO $$ BEGIN CREATE TYPE rol_account_type_enum    AS ENUM ('INDIVIDUAL','M2M','SYSTEM','GROUP','TEMPLATE','VIRTUAL','BOT','DEVICE','SERVICE','EMERGENCY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0026] → A.65.04
-- B02 §validity_period.type — 5 tipos de vigencia de negocio (NIST AC-2(d) · ISO A.5.18)
DO $$ BEGIN
    CREATE TYPE bauth.role_validity_type AS ENUM (  -- [MC-0005] → A.65.04
        'INDEFINITE',    -- estructurales; sin fin fijo; auto-extensión si hay usuarios activos
        'FIXED',         -- fin contractual; humano establece valid_until
        'PROJECT_BASED', -- fin por hito; notificación 30d antes; solo humano decide extensión
        'TEMPORARY',     -- fin = valid_from + duration_interval; NO extensible
        'EMERGENCY'      -- fin = created_at + 72h fijas (NIST AC-2(2)); NO extensible
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN CREATE TYPE ial_level_enum           AS ENUM ('IAL1','IAL2','IAL3'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0017] → A.65.04
DO $$ BEGIN CREATE TYPE risk_level_enum          AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0028] → A.65.04
DO $$ BEGIN CREATE TYPE sensitivity_label_enum   AS ENUM ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED','SECRET'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0027] → A.65.04

-- --- ÁRBOL DE POLÍTICAS ---
-- NOTA: template_node_type_enum, template_effect_enum, verb_conflict_type_enum ELIMINADOS.
-- T-162 usa tipo TEXT + CHECK(9 tipos en español). T-162/T-170 usan effect BOOLEAN.
-- T-175 usa tipo TEXT + CHECK('STATIC_SOD','DYNAMIC_SOD','AFFINITY').

-- --- IDENTIDAD D00 ---
DO $$ BEGIN CREATE TYPE entidad_nivel_enum       AS ENUM ('tenant','bdomain','bsubdomain','pos','actor'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0016] → A.65.04
DO $$ BEGIN CREATE TYPE nhi_type_enum            AS ENUM ('DAEMON','PIPELINE','BOT','SERVICE_ACCOUNT','AGENT_AI','DEVICE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0039] → A.65.04
DO $$ BEGIN CREATE TYPE nhi_status_enum          AS ENUM ('ACTIVE','SUSPENDED','DECOMMISSIONED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0038] → A.65.04
DO $$ BEGIN CREATE TYPE nhi_event_type_enum      AS ENUM ('PROVISIONED','CERTIFIED','ROTATED','SUSPENDED','REACTIVATED','DECOMMISSIONED','OWNER_CHANGED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0041] → A.65.04
DO $$ BEGIN CREATE TYPE nhi_cert_decision_enum   AS ENUM ('CERTIFY','DECOMMISSION','REDUCE_SCOPE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0040] → A.65.04

-- --- PRIVILEGIOS ---
DO $$ BEGIN CREATE TYPE grant_type_enum          AS ENUM ('STANDARD','JIT','BREAKGLASS'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0030] → A.65.04
DO $$ BEGIN CREATE TYPE grant_status_enum        AS ENUM ('ACTIVE','INACTIVE','REVOKED','EXPIRED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0029] → A.65.04
-- NOTA: override_type_enum, assurance_outcome_enum, sod_exception_type_enum ELIMINADOS.
-- T-173 usa override_type TEXT + CHECK('DENY_TO_PERMIT','PERMIT_TO_DENY').
-- T-176 usa outcome TEXT + CHECK('PERMIT','STEP_UP_REQUIRED','DENIED').
-- privilege_sod_exception eliminada — SoD se enforcea via trigger en T-170.

-- --- SESIÓN / CAEP ---
DO $$ BEGIN CREATE TYPE caep_event_type_enum     AS ENUM ('credential_change','token_claims_change','session_revoked','assurance_level_change','ip_change','risk_score_change'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0042] → A.65.04
DO $$ BEGIN CREATE TYPE caep_proc_status_enum    AS ENUM ('RECEIVED','PROCESSING','APPLIED','FAILED','IGNORED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0043] → A.65.04
DO $$ BEGIN CREATE TYPE ssf_delivery_method_enum AS ENUM ('PUSH','POLL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0057] → A.65.04
DO $$ BEGIN CREATE TYPE ssf_delivery_status_enum AS ENUM ('SUCCESS','FAILED','RETRYING','ABANDONED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0058] → A.65.04

-- --- AUDITORÍA ---
DO $$ BEGIN CREATE TYPE campaign_scope_enum      AS ENUM ('TENANT','USER','ROLE','ATOM'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0031] → A.65.04
DO $$ BEGIN CREATE TYPE campaign_type_enum       AS ENUM ('QUARTERLY','ANNUAL','OFFBOARDING','INCIDENT','SOD_REVIEW'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0033] → A.65.04
DO $$ BEGIN CREATE TYPE campaign_status_enum     AS ENUM ('ACTIVE','COMPLETED','CANCELLED','OVERDUE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0032] → A.65.04
DO $$ BEGIN CREATE TYPE review_decision_enum     AS ENUM ('CERTIFY','REVOKE','ESCALATE','DEFER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0034] → A.65.04

-- --- RIESGO / ITDR ---
DO $$ BEGIN CREATE TYPE risk_action_enum         AS ENUM ('STEP_UP','REVOKE','SUSPEND','NOTIFY','REQUIRE_MFA'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0047] → A.65.04

-- --- PAM ---
DO $$ BEGIN CREATE TYPE jit_status_enum          AS ENUM ('PENDING','APPROVED','ACTIVE','EXPIRED','REVOKED','REJECTED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0036] → A.65.04
DO $$ BEGIN CREATE TYPE breakglass_status_enum   AS ENUM ('PENDING_APPROVAL','ACTIVE','DEACTIVATED','REVIEWED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0035] → A.65.04
DO $$ BEGIN CREATE TYPE pam_access_type_enum     AS ENUM ('SSH','RDP','API','CONSOLE','DB','CLI','VAULT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0037] → A.65.04
DO $$ BEGIN CREATE TYPE credential_ref_type_enum AS ENUM ('PASSWORD','API_KEY','CERTIFICATE','SSH_KEY','SERVICE_TOKEN','OAUTH_TOKEN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0045] → A.65.04
DO $$ BEGIN CREATE TYPE credential_owner_type_enum AS ENUM ('HUMAN','NHI'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0044] → A.65.04
DO $$ BEGIN CREATE TYPE proposal_status_enum     AS ENUM ('DRAFT','PENDING_QUORUM','APPROVED','REJECTED','EXPIRED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0046] → A.65.04

RESET lock_timeout;
RESET client_min_messages;

-- ══════════════════════════════════════════════════════════════════════
-- SEQUENCE — Posiciones de bit para átomos del árbol de políticas
-- ══════════════════════════════════════════════════════════════════════
-- Cada nodo EVALUATION en T-162 (idn_roles_template) recibe un atom_position
-- único e irrevocable desde esta secuencia. Es la base del BitMask 64-bit.
-- Una vez asignada, la posición no cambia aunque el nodo se desactive.
CREATE SEQUENCE IF NOT EXISTS bauth.roles_atom_position_sequential
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 1;

COMMENT ON SEQUENCE bauth.roles_atom_position_sequential IS
  '[A.65.02 §PRIVILEGIOS] Secuencia única global para atom_position en idn_roles_template.
   Solo los nodos tipo EVALUATION consumen esta secuencia (via trigger trg_irt_atom_position).
   Inmutable: una posición asignada nunca se reutiliza (NIST RBAC N3 — posición de bit estable).';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                NIVEL 0 — CATÁLOGOS GLOBALES (bglobal)               ║
-- ║   Sin dependencias. Catálogos ISO compartidos por todo SBOS.        ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-001 — bglobal.global_language
-- Catálogo canónico ISO 639-1/3 · BCP 47 · IANA Language Subtag Registry.
-- Natural key: locale TEXT UNIQUE (BCP 47 tag: es-BO, en-US, qu-BO).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_language (
    language_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    locale           TEXT        UNIQUE NOT NULL,
    iso_639_1        CHAR(2),
    iso_639_2t       CHAR(3),
    iso_639_2b       CHAR(3),
    iso_639_3        CHAR(3),
    scope            language_scope_enum  NOT NULL DEFAULT 'individual',
    language_type    language_type_enum   NOT NULL DEFAULT 'living',
    family           TEXT,
    name             JSONB       NOT NULL,
    direction        text_direction_enum  NOT NULL DEFAULT 'ltr',
    fallback_locale  TEXT,
    suppress_script  CHAR(4),
    preferred_value  TEXT,
    deprecated       BOOLEAN     NOT NULL DEFAULT false,
    wikidata_id      TEXT,
    iana_registry_date DATE,
    is_active        BOOLEAN     NOT NULL DEFAULT false,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_glang_locale   ON bglobal.global_language(locale);
CREATE INDEX IF NOT EXISTS idx_glang_active          ON bglobal.global_language(locale) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_glang_iso6391         ON bglobal.global_language(iso_639_1) WHERE iso_639_1 IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_glang_scope           ON bglobal.global_language(scope, language_id);
CREATE INDEX IF NOT EXISTS idx_glang_name            ON bglobal.global_language USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bglobal.global_language IS
'GLOBAL | Catálogo canónico de idiomas BCP 47 para todo el ecosistema SBOS — fuente única de locales válidos (es-BO, en-US, qu-BO, ay-BO), con metadatos IANA, CLDR y direccionalidad de escritura.
Fuente: seed inicial (2800+ idiomas de IANA Language Subtag Registry + CLDR 46); actualización vía migración DDL cuando IANA publica nuevas versiones; no se insertan idiomas en runtime.
Administración: tabla de referencia global — ningún daemon modifica filas en producción; cambios requieren migración con HITL; is_active=true para los 6 locales activos iniciales del SBOS.
WORM: no (is_active se actualiza al activar/desactivar un idioma).
Particionada: no.
Seed: DDLs/seeds/bglobal_T001__global_language.sql — idempotente ON CONFLICT.
Estándar: BCP 47 (RFC 5646), ISO 639-1/2/3, ISO 15924, IANA Language Subtag Registry, Unicode CLDR 46. T-001.';

COMMENT ON COLUMN bglobal.global_language.locale      IS '[BCP 47] Tag canónico: es-BO, en-US, zh-Hans-CN, qu-BO, ay-BO.';
COMMENT ON COLUMN bglobal.global_language.name        IS '[CLDR 46] JSONB nombres multi-locale: {"es":"Español","en":"Spanish","native":"Español"}.';
COMMENT ON COLUMN bglobal.global_language.scope       IS '[ISO 639-3 §4.2] individual, macrolanguage, special, collection.';
COMMENT ON COLUMN bglobal.global_language.fallback_locale IS '[CLDR] Cadena de degradación: cmn→zh→en→und. NULL = autosuficiente.';
COMMENT ON COLUMN bglobal.global_language.preferred_value IS '[IANA] Reemplazo si deprecated: iw→he, in→id.';


-- ======================================================================
-- T-002 — bglobal.global_country
-- Catálogo ISO 3166-1. Natural key: iso_alpha2 CHAR(2) UNIQUE.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_country (
    country_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    iso_alpha2          CHAR(2)     UNIQUE NOT NULL,
    iso_alpha3          CHAR(3)     UNIQUE NOT NULL,
    iso_numeric         CHAR(3)     UNIQUE NOT NULL,
    name                JSONB,
    official_name       JSONB,
    name_common         TEXT,
    name_official       TEXT,
    name_native         TEXT,
    demonym             TEXT,
    demonym_native      TEXT,
    un_m49              INTEGER,
    itu_calling_code    TEXT,
    icao_code           TEXT,
    continent           TEXT,
    region              TEXT,
    subregion           TEXT,
    capital             TEXT,
    capital_coords      TEXT,
    lat                 NUMERIC,
    lon                 NUMERIC,
    area_km2            NUMERIC,
    landlocked          BOOLEAN,
    borders             TEXT[],
    population          BIGINT,
    population_year     INTEGER,
    gini_coefficient    NUMERIC,
    languages           TEXT[],
    timezones           TEXT[],
    flag_emoji          TEXT,
    independence_status TEXT,
    wikidata_id         TEXT,
    phone_prefix        TEXT,
    tld                 TEXT,
    currency_code       CHAR(3),
    timezone_primary    TEXT,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gcty_alpha2   ON bglobal.global_country(iso_alpha2);
CREATE UNIQUE INDEX IF NOT EXISTS idx_gcty_alpha3   ON bglobal.global_country(iso_alpha3);
CREATE INDEX IF NOT EXISTS idx_gcty_region          ON bglobal.global_country(region, iso_alpha2);
CREATE INDEX IF NOT EXISTS idx_gcty_name            ON bglobal.global_country USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bglobal.global_country IS
'GLOBAL | Catálogo canónico de países ISO 3166-1 — define cada país con códigos alpha-2/alpha-3/numérico, coordenadas geográficas, moneda, zona horaria y metadatos demográficos para formularios, GDPR y cumplimiento de residencia de datos.
Fuente: seed inicial (249 países ISO 3166-1 activos + territorios dependientes); actualización vía migración DDL cuando ISO publica revisiones anuales; BO es el país default del sistema.
Administración: tabla de referencia global — ningún daemon modifica filas en producción; is_active=false para países sancionados o sin soporte; referenciada por idn_tenant(country) y global_currency.
WORM: no (is_active puede actualizarse al aplicar sanciones o activar nuevos territorios).
Particionada: no.
Seed: DDLs/seeds/bglobal_T002__global_country.sql — idempotente ON CONFLICT.
Estándar: ISO 3166-1:2020, ISO 3166-2:2020, UN M.49 (regiones estadísticas), GDPR Art. 44 (transferencias internacionales). T-002.';

COMMENT ON COLUMN bglobal.global_country.iso_alpha2 IS '[ISO 3166-1 alpha-2] BO, US, AR, BR, CL, PE.';
COMMENT ON COLUMN bglobal.global_country.name       IS '[CLDR] JSONB: {"es":"Bolivia","en":"Bolivia","native":"Bolivia"}.';
COMMENT ON COLUMN bglobal.global_country.region     IS '[UN M.49] Americas, Europe, Asia, Africa, Oceania.';


-- ======================================================================
-- T-003 — bglobal.global_currency
-- Catálogo ISO 4217. Natural key: currency_code CHAR(3) UNIQUE.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_currency (
    currency_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    currency_code    CHAR(3)     UNIQUE NOT NULL,
    iso_numeric      SMALLINT    UNIQUE NOT NULL,
    name             JSONB       NOT NULL,
    symbol           TEXT        NOT NULL,
    symbol_intl      TEXT,
    decimal_places   SMALLINT    NOT NULL DEFAULT 2,
    minor_unit_name  TEXT,
    issuer_country   CHAR(2)     NOT NULL,
    country_id       UUID        REFERENCES bglobal.global_country(country_id),
    introduced_at    DATE,
    withdrawn_at     DATE,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    is_cryptocurrency BOOLEAN    NOT NULL DEFAULT false,
    exchange_rate_api TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gcur_code     ON bglobal.global_currency(currency_code);
CREATE INDEX IF NOT EXISTS idx_gcur_active          ON bglobal.global_currency(is_active, currency_code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_gcur_country         ON bglobal.global_currency(issuer_country, currency_id);
CREATE INDEX IF NOT EXISTS idx_gcur_name            ON bglobal.global_currency USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bglobal.global_currency IS
'GLOBAL | Catálogo de monedas ISO 4217 — define el código, símbolo, décimales y país emisor de cada moneda; es la fuente canónica para idn_tenant_currencies y determina la precisión aritmética en módulos financieros y facturación SIN.
Fuente: seed inicial (180 monedas ISO 4217 activas + criptomonedas) al despliegue; actualización vía migración DDL cuando ISO publica revisiones o cuando el BCB publica nuevos tipos de cambio de referencia.
Administración: tabla de referencia global — ningún daemon modifica filas en runtime; withdrawn_at marca monedas retiradas (ej: EUR pre-adopción); exchange_rate_api apunta a la API del BCB para consultas de tipo de cambio.
WORM: no (is_active se actualiza al retirar o activar monedas).
Particionada: no.
Estándar: ISO 4217:2015, NIC 21/IAS 21 (conversión de moneda extranjera), BCB Bolivia (tipos de cambio oficiales). T-003.';

COMMENT ON COLUMN bglobal.global_currency.currency_code  IS '[ISO 4217] BOB, USD, EUR, ARS, BRL.';
COMMENT ON COLUMN bglobal.global_currency.name           IS '[CLDR] {"es":{"singular":"Boliviano","plural":"Bolivianos"},"en":{"singular":"Bolivian Boliviano"}}.';
COMMENT ON COLUMN bglobal.global_currency.decimal_places IS '[ISO 4217] 2=BOB/USD/EUR, 0=JPY/KRW, 3=BHD/OMR.';
COMMENT ON COLUMN bglobal.global_currency.exchange_rate_api IS 'URL API tipo de cambio oficial: https://www.bcb.gob.bo/api/.';


-- ======================================================================
-- T-004 — bglobal.geo_timezone
-- Catálogo IANA TZ Database. Natural key: timezone_id TEXT UNIQUE.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.geo_timezone (
    timezone_uuid    UUID        PRIMARY KEY DEFAULT uuidv7(),
    timezone_id      TEXT        UNIQUE NOT NULL,
    name             JSONB       NOT NULL,
    country_code     CHAR(2)     NOT NULL,
    principal_city   TEXT,
    coordinates      POINT,
    utc_offset       TEXT        NOT NULL,
    utc_offset_min   SMALLINT    NOT NULL,
    observes_dst     BOOLEAN     NOT NULL DEFAULT false,
    dst_offset       TEXT,
    dst_offset_min   SMALLINT,
    comments         TEXT,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tz_iana     ON bglobal.geo_timezone(timezone_id);
CREATE INDEX IF NOT EXISTS idx_tz_country         ON bglobal.geo_timezone(country_code, timezone_uuid);
CREATE INDEX IF NOT EXISTS idx_tz_dst             ON bglobal.geo_timezone(observes_dst, timezone_id);
CREATE INDEX IF NOT EXISTS idx_tz_name            ON bglobal.geo_timezone USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bglobal.geo_timezone IS
'GLOBAL | Catálogo IANA de zonas horarias — define cada zona con su offset UTC, observancia de DST y ciudad principal; es la fuente canónica para bcalendar y el evaluador temporal GTRBAC (D04) al calcular ventanas de acceso.
Fuente: seed inicial (600+ entradas de la IANA TZ Database 2024e); actualización vía migración DDL al publicar nuevas versiones IANA (1-4 veces/año); America/La_Paz es la zona default del SBOS.
Administración: tabla de referencia global — ningún daemon modifica filas en runtime; observes_dst=true requiere que el evaluador temporal aplique el offset DST en períodos correspondientes.
WORM: no (is_active y utc_offset_min se actualizan cuando IANA cambia una zona).
Particionada: no.
Seed: DDLs/seeds/bglobal_T004__geo_timezone.sql — idempotente ON CONFLICT.
Estándar: IANA TZ Database (tzdata), ISO 6709:2022 (notación geográfica), RFC 5545 VTIMEZONE §3.6.5. T-004.';

COMMENT ON COLUMN bglobal.geo_timezone.timezone_id IS '[IANA] America/La_Paz, America/New_York, Asia/Shanghai, Europe/Madrid.';
COMMENT ON COLUMN bglobal.geo_timezone.utc_offset_min IS '[IANA] Offset en minutos: -240 (La_Paz), 480 (Shanghai). Útil para aritmética.';


-- ======================================================================
-- T-059 — bglobal.menu_item
-- Ítems de menú del dashboard por módulo. Árbol con parent_id self-ref.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.menu_item (
    item_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    parent_id        UUID        REFERENCES bglobal.menu_item(item_id) ON DELETE SET NULL,
    code             TEXT        UNIQUE NOT NULL,
    label            JSONB       NOT NULL,
    route            TEXT,
    icon             TEXT,
    sort_order       INT         NOT NULL DEFAULT 0,
    depth            INT         NOT NULL DEFAULT 0,
    is_leaf          BOOLEAN     NOT NULL DEFAULT true,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    metadata         JSONB       DEFAULT '{}',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mitem_parent    ON bglobal.menu_item(parent_id);
CREATE INDEX IF NOT EXISTS idx_mitem_code      ON bglobal.menu_item(code);
CREATE INDEX IF NOT EXISTS idx_mitem_sort      ON bglobal.menu_item(depth, sort_order);

COMMENT ON TABLE bglobal.menu_item IS
'GLOBAL | Árbol de ítems de menú del dashboard SBOS con estructura adjacency list (parent_id self-referencing) — define la jerarquía completa de navegación con rutas, íconos y visibilidad por módulo IAM.
Fuente: seed inicial con el árbol de menú del sistema SBOS (dashboard, iam.roles, iam.users, config); nuevos módulos añaden ítems vía migración DDL con HITL; ningún dato insertado en runtime por usuarios.
Administración: tabla de referencia — code es el identificador técnico estable (ej: iam.roles.create); label JSONB multi-idioma vía bi18n; is_active=false oculta el ítem del menú sin eliminar sus asignaciones de átomo.
WORM: no (is_active y sort_order actualizables al reorganizar la navegación).
Particionada: no.
Seed: DDLs/seeds/bglobal_T0XX__menu_item.sql — PENDIENTE — estructura de menú a diseñar
Estándar: ISO 9241-11:2018 (usabilidad), WCAG 2.2 (accesibilidad de menús), ARIA roles navigation. T-059.';

COMMENT ON COLUMN bglobal.menu_item.code  IS 'Identificador único del ítem: dashboard.home, iam.roles.create.';
COMMENT ON COLUMN bglobal.menu_item.label IS '[JSONB] {"es":"Inicio","en":"Home"}. Multi-idioma vía bi18n.';
COMMENT ON COLUMN bglobal.menu_item.route IS 'Ruta frontend: /dashboard, /iam/roles. NULL = nodo de agrupación sin ruta.';


-- ======================================================================
-- T-114 — bglobal.global_config
-- Parámetros globales del sistema — fuente de suelo del PIP @bauth_config_param.
-- Un parámetro global puede ser sobrescrito por idn_tenant_config (T-009).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_config (
    config_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    param_key        TEXT        UNIQUE NOT NULL,
    param_value      TEXT        NOT NULL,
    value_type       global_param_type_enum NOT NULL DEFAULT 'TEXT',
    scope            global_param_scope_enum NOT NULL DEFAULT 'global',
    description      TEXT,
    is_overridable   BOOLEAN     NOT NULL DEFAULT true,
    default_value    TEXT,
    min_value        TEXT,
    max_value        TEXT,
    standard_ref     TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gcfg_scope  ON bglobal.global_config(scope, param_key);
CREATE INDEX IF NOT EXISTS idx_gcfg_key    ON bglobal.global_config(param_key);

COMMENT ON TABLE bglobal.global_config IS
'GLOBAL | Parámetros globales cross-daemon del sistema SBOS — es el SUELO del PIP @bauth_config_param; el Motor de Identidad (PDP) busca primero en idn_tenant_config (T-009) y cae aquí si la clave no está definida por el tenant.
Fuente: seed inicial con ~20 parámetros canónicos (max_sessions, loa_default, argon2id_t, session_ttl_max) documentados en A.48; cambios solo vía migración DDL con HITL por SECURITY_ADMIN.
Administración: is_overridable=true = tenant puede sobrescribir en idn_tenant_config (T-009); is_overridable=false = piso de seguridad inviolable que el tenant no puede rebajar; ningún daemon escribe aquí en runtime.
WORM: no (param_value actualizable al cambiar parámetros globales de seguridad con HITL).
Particionada: no.
Seed: DDLs/seeds/bglobal_T0XX__global_config.sql — PENDIENTE — parámetros globales por definir
Estándar: NIST SP 800-53 CM-6 (Configuration Settings), NIST SP 800-53 CM-7 (Least Functionality). T-114.';

COMMENT ON COLUMN bglobal.global_config.param_key      IS 'Clave del parámetro: max_sessions, loa_default, argon2id_t, session_ttl_max.';
COMMENT ON COLUMN bglobal.global_config.param_value    IS 'Valor como TEXT. El Motor de Identidad convierte según value_type.';
COMMENT ON COLUMN bglobal.global_config.value_type     IS '[ENUM] TEXT, INTEGER, BOOLEAN, JSON, DECIMAL.';
COMMENT ON COLUMN bglobal.global_config.scope          IS '[ENUM] global, security, calendar, auth, policy, billing.';
COMMENT ON COLUMN bglobal.global_config.is_overridable IS 'true = idn_tenant_config puede sobrescribir. false = piso de seguridad inviolable.';
COMMENT ON COLUMN bglobal.global_config.standard_ref   IS 'Norma que impone este parámetro: [NIST 800-63B-4 §5.1.1] etc.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                NIVEL 1 — TENANT (bauth)                             ║
-- ║   Infraestructura multi-tenancy. Piso mínimo para nuevo tenant.     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-005 — bauth.idn_tenant
-- Ancla de gobernanza del sistema. Todo FK arranca desde tenant_id.
-- REPARACIONES ADR-010: eliminados realm_kc, namespace_k8s, kong_consumer_id,
-- database_name, database_schema (infra KC/K8s pertenece a BOS, no a bauth).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant (
    -- === IDENTIDAD ===
    tenant_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_slug          TEXT        UNIQUE NOT NULL,
    tenant_name          TEXT        NOT NULL,
    tenant_type          tenant_type_enum  NOT NULL DEFAULT 'STANDARD',
    -- [A.65.01 §17][N] Distingue tenant de infraestructura SKULL/SBOS (true) de tenant cliente (false).
    -- true = no facturado, puede alojar tiers SU/SYS reservados. false = organización cliente (DEFAULT).
    is_internal          BOOLEAN           NOT NULL DEFAULT false,

    -- === CICLO DE VIDA (7 estados) ===
    status               tenant_status_enum       NOT NULL DEFAULT 'PENDING_VERIFICATION',
    provisioning_status  provisioning_status_enum NOT NULL DEFAULT 'PENDING',
    verified_at          TIMESTAMPTZ,
    verified_by          UUID,
    suspended_at         TIMESTAMPTZ,
    deleted_at           TIMESTAMPTZ,
    purge_after          TIMESTAMPTZ             DEFAULT (now() + INTERVAL '30 days'),

    -- === DATOS LEGALES ===
    legal_name           TEXT,
    tax_id               TEXT,
    registration_number  TEXT,
    country              CHAR(2)     NOT NULL DEFAULT 'BO',
    jurisdiction         TEXT,
    legal_representative TEXT,
    legal_contact_email  TEXT,
    data_retention_days  INTEGER     NOT NULL DEFAULT 2555,
    terms_accepted_at    TIMESTAMPTZ,
    terms_version        TEXT,

    -- === INFRAESTRUCTURA SOBERANA (solo referencias, sin config infra) ===
    vault_path           TEXT,

    -- === SEGURIDAD ===
    isolation_level      isolation_level_enum     NOT NULL DEFAULT 'SCHEMA_PER_TENANT',
    mfa_required         BOOLEAN     NOT NULL DEFAULT false,
    password_policy      TEXT        NOT NULL DEFAULT 'length(12)_argon2id_t3_m64',
    session_ttl_max      INTEGER     NOT NULL DEFAULT 28800,
    token_ttl_seconds    INTEGER     NOT NULL DEFAULT 3600,
    rate_limit_rps       INTEGER     NOT NULL DEFAULT 100,
    allowed_ip_ranges    TEXT[]      DEFAULT '{}',

    -- === NEGOCIO ===
    plan_tier            plan_tier_enum           NOT NULL DEFAULT 'BASIC',
    subscription_status  subscription_status_enum NOT NULL DEFAULT 'TRIAL',
    audit_level          audit_level_enum         NOT NULL DEFAULT 'basic',
    notification_channels TEXT[]     DEFAULT '{email}',
    admin_contact_id     UUID,
    metadata             JSONB       DEFAULT '{}',
    tags                 TEXT[]      DEFAULT '{}',

    -- === TRAZABILIDAD ===
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_tenant_security_contact CHECK (
        legal_contact_email IS NOT NULL OR admin_contact_id IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_itnt_status   ON bauth.idn_tenant(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itnt_type     ON bauth.idn_tenant(tenant_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itnt_country  ON bauth.idn_tenant(country, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itnt_slug     ON bauth.idn_tenant(tenant_slug);
CREATE INDEX IF NOT EXISTS idx_itnt_created  ON bauth.idn_tenant(created_at DESC);

COMMENT ON TABLE bauth.idn_tenant IS
'TENANT | Ancla de gobernanza del sistema multi-tenant SBOS — TODA FK de la DDL arranca desde tenant_id; define el ciclo de vida de cada organización cliente (7 estados), su nivel de aislamiento y políticas de seguridad propias.
Fuente: creado por BOS (Instalador IAM) vía RPC bos.tenant.create durante el proceso de onboarding; bAuth registra el tenant_id en su plano de identidad al confirmar la instalación; el seed crea el tenant SKULL interno (is_internal=true) al inicializar SBOS.
Administración: solo bOS puede crear tenants; bAuth suspende/activa; purge_after controla el borrado definitivo tras SOFT_DELETED (30 días por defecto); TERMINATED es irreversible y no puede volverse ACTIVE; mfa_required se evalúa en cada autenticación; revisión trimestral de tenants según ISO 27001 A.8.2.
WORM: no (ciclo de vida de 7 estados requiere actualización de status y timestamps).
Particionada: no.
Seed: DDLs/seeds/bauth_T005__idn_tenant.sql — idempotente ON CONFLICT.
Estándar: ISO 27001 A.8.2 (clasificación de activos), NIST SP 800-53 AC-2 (gestión de cuentas), SBOS-049 §4, GDPR Art. 32 (seguridad por diseño). T-005.';

COMMENT ON COLUMN bauth.idn_tenant.tenant_id           IS '[RFC 9562] PK UUIDv7. 20+ FKs entrantes.';
COMMENT ON COLUMN bauth.idn_tenant.tenant_slug         IS 'Identificador público para URLs/APIs: skull, acme, inka. UNIQUE.';
COMMENT ON COLUMN bauth.idn_tenant.status              IS '[ISO 27001 A.8.2] PENDING_VERIFICATION→ACTIVE→SUSPENDED→TERMINATED→PURGED.';
COMMENT ON COLUMN bauth.idn_tenant.provisioning_status IS 'Bootstrap: PENDING→INFRA_PROVISIONING→SCHEMA_CREATED→IDP_CONFIGURED→COMPLETED.';
COMMENT ON COLUMN bauth.idn_tenant.vault_path          IS 'Ruta en Vault para secretos del tenant: secret/tenants/{slug}/. Única referencia de infra en bauth.';
COMMENT ON COLUMN bauth.idn_tenant.isolation_level     IS '[ISO 27001] ROW_LEVEL | SCHEMA_PER_TENANT | DB_PER_TENANT.';
COMMENT ON COLUMN bauth.idn_tenant.password_policy     IS '[NIST 800-63B-4 §5.1.1.2] Política: length(12)_argon2id_t3_m64.';
COMMENT ON COLUMN bauth.idn_tenant.data_retention_days IS '[Ley 2492 Bolivia] Default 2555 días (7 años, datos fiscales).';
COMMENT ON COLUMN bauth.idn_tenant.deleted_at          IS '[GDPR Art.17] Soft-delete. NULL=activo. Grace period hasta purge_after.';
COMMENT ON COLUMN bauth.idn_tenant.allowed_ip_ranges   IS '[NIST 800-207 ZTA] CIDRs autorizados. {}=sin restricción.';


-- ======================================================================
-- T-006 — bauth.idn_tenant_currencies
-- Monedas habilitadas por tenant. FK real a global_currency(currency_code).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_currencies (
    currency_config_id UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id          UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    currency_code      CHAR(3)     NOT NULL REFERENCES bglobal.global_currency(currency_code),
    is_default         BOOLEAN     NOT NULL DEFAULT false,
    exchange_rate      DECIMAL(18,8),
    exchange_source    TEXT        DEFAULT 'BCB',
    exchange_updated_at TIMESTAMPTZ,
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, currency_code)
);

CREATE INDEX IF NOT EXISTS idx_itcu_tenant   ON bauth.idn_tenant_currencies(tenant_id, currency_code);
CREATE INDEX IF NOT EXISTS idx_itcu_default  ON bauth.idn_tenant_currencies(tenant_id) WHERE is_default = true;

COMMENT ON TABLE bauth.idn_tenant_currencies IS
'TENANT | Monedas habilitadas por tenant con tasa de cambio actualizable — define la moneda funcional del tenant (is_default=true) y las adicionales para facturación multi-moneda; la tasa se sincroniza con el BCB u otras fuentes.
Fuente: creado automáticamente por bAuth al onboarding del tenant (moneda default=BOB para Bolivia); FINANCE_ADMIN añade monedas adicionales vía RPC bauth.tenant.currency.enable.
Administración: solo una moneda default por tenant (constraint UNIQUE + is_default); exchange_rate actualizado por job diario desde BCB; exchange_source: BCB (oficial), ECB (Europa), MANUAL (fixed); is_active=false desactiva sin eliminar el histórico.
WORM: no (exchange_rate y exchange_updated_at se actualizan periódicamente).
Particionada: no.
Estándar: ISO 4217:2015, NIC 21/IAS 21 §8 (moneda funcional), BCB Bolivia Resolución Directorio 142/2023. T-006.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.exchange_rate IS 'DECIMAL(18,8) — precisión financiera. Tasa vs moneda default del tenant.';
COMMENT ON COLUMN bauth.idn_tenant_currencies.ctx_id        IS '[SBOS-049 §4] Contexto operativo.';


-- ======================================================================
-- T-007 — bauth.idn_tenant_languages
-- Idiomas habilitados por tenant. FK real a global_language(locale).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_languages (
    language_config_id UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id          UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    locale             TEXT        NOT NULL REFERENCES bglobal.global_language(locale),
    is_default         BOOLEAN     NOT NULL DEFAULT false,
    translation_provider TEXT      DEFAULT 'sbos_i18n',
    translation_status translation_status_enum DEFAULT 'COMPLETE',
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, locale)
);

CREATE INDEX IF NOT EXISTS idx_itla_tenant  ON bauth.idn_tenant_languages(tenant_id, locale);
CREATE INDEX IF NOT EXISTS idx_itla_default ON bauth.idn_tenant_languages(tenant_id) WHERE is_default = true;

COMMENT ON TABLE bauth.idn_tenant_languages IS
'TENANT | Idiomas habilitados por tenant con su estado de traducción — define el idioma default (is_default=true) y los idiomas activos para la interfaz multi-idioma; referencia FK real a global_language(locale) validando cada locale.
Fuente: creado automáticamente al onboarding del tenant (es-BO como idioma default); ADMIN del tenant añade idiomas adicionales vía RPC bauth.tenant.language.enable.
Administración: solo un idioma default por tenant (constraint); translation_status=COMPLETE garantiza que bi18n daemon puede servir todas las cadenas; PARTIAL activa fallback a es-BO; is_active=false quita el idioma del selector.
WORM: no (is_active y translation_status se actualizan cuando las traducciones cambian).
Particionada: no.
Estándar: BCP 47 (RFC 5646), Unicode CLDR 46, ISO 639-3. T-007.';


-- ======================================================================
-- T-008 — bauth.idn_tenant_verification
-- Verificación KYC/IAL del tenant. 5 pasos → IAL alcanzado.
-- REPARACIÓN: agregado ial_achieved para registrar level IAL resultante.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_verification (
    verification_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    step             verification_step_enum   NOT NULL,
    status           verification_status_enum NOT NULL DEFAULT 'PENDING',
    ial_achieved     ial_level_enum,
    verified_by      UUID,
    verified_at      TIMESTAMPTZ,
    expires_at       TIMESTAMPTZ,
    comments         TEXT,
    evidence         JSONB       DEFAULT '{}',
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, step)
);

CREATE INDEX IF NOT EXISTS idx_itvr_tenant  ON bauth.idn_tenant_verification(tenant_id, step);
CREATE INDEX IF NOT EXISTS idx_itvr_status  ON bauth.idn_tenant_verification(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itvr_expires ON bauth.idn_tenant_verification(expires_at) WHERE expires_at IS NOT NULL;

COMMENT ON TABLE bauth.idn_tenant_verification IS
'TENANT | Verificación KYC/IAL del tenant con 5 pasos secuenciales — documenta el proceso de proofing (IDENTITY_CHECK→LEGAL_CHECK→TECHNICAL_SETUP→SECURITY_REVIEW→FINAL_APPROVAL) y el nivel IAL alcanzado al completarlo.
Fuente: creado automáticamente por bAuth al registrar un nuevo tenant con PENDING_VERIFICATION; BOS orquesta los 5 pasos en orden; cada paso actualiza status y registra evidencia en el campo evidence JSONB.
Administración: UNIQUE (tenant_id, step) — un registro por paso; al completar FINAL_APPROVAL bAuth actualiza idn_tenant.status=ACTIVE y registra ial_achieved; evidencias con vencimiento (documentos KYC) alertadas antes de expires_at.
WORM: no (status de cada paso se actualiza durante el proceso KYC).
Particionada: no.
Estándar: NIST SP 800-63A IAL1-3 (identity assurance levels), ISO 27001 A.8.2, GDPR Art. 6(1)(b). T-008.';

COMMENT ON COLUMN bauth.idn_tenant_verification.step           IS '[NIST 800-63A] IDENTITY_CHECK → LEGAL_CHECK → TECHNICAL_SETUP → SECURITY_REVIEW → FINAL_APPROVAL.';
COMMENT ON COLUMN bauth.idn_tenant_verification.ial_achieved   IS '[NIST 800-63A] IAL1 (declarativo), IAL2 (remoto), IAL3 (presencial). NULL = aún no alcanzado.';
COMMENT ON COLUMN bauth.idn_tenant_verification.expires_at     IS 'Vencimiento de los documentos de evidencia. Job de alerta 30 días antes.';
COMMENT ON COLUMN bauth.idn_tenant_verification.evidence       IS '[JSONB] {doc_type, file_hash, storage_path, uploaded_at, issuer}.';


-- ======================================================================
-- T-009 — bauth.idn_tenant_config
-- Configuración regional + parámetros PIP para @bauth_config_param.*.
-- REPARACIÓN: +params_policy JSONB — fuente de parámetros de política del tenant.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_config (
    config_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id            UUID        UNIQUE NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- === IDIOMA Y REGIÓN ===
    locale_default       JSONB       NOT NULL DEFAULT '{"locale":"es-BO","name":{"es":"Español (Bolivia)"}}',
    supported_locales    JSONB       DEFAULT '[{"locale":"es-BO"},{"locale":"en-US"}]',
    fallback_locales     JSONB       DEFAULT '[{"locale":"es"},{"locale":"en"}]',
    date_format          TEXT        NOT NULL DEFAULT 'DD/MM/YYYY',
    time_format          TEXT        NOT NULL DEFAULT 'HH:mm:ss',
    number_format        TEXT        NOT NULL DEFAULT '1.234,56',
    first_day_of_week    INTEGER     NOT NULL DEFAULT 1,

    -- === ZONA HORARIA ===
    timezone_default     JSONB       NOT NULL DEFAULT '{"timezone_id":"America/La_Paz","utc_offset":"-04:00"}',
    supported_timezones  JSONB       DEFAULT '[{"timezone_id":"America/La_Paz"}]',

    -- === MONEDA ===
    currency_default     JSONB       NOT NULL DEFAULT '{"currency_code":"BOB","symbol":"Bs.","decimal_places":2}',
    multicurrency        BOOLEAN     NOT NULL DEFAULT false,

    -- === CALENDARIO FISCAL ===
    multifiscal_enabled  BOOLEAN     NOT NULL DEFAULT true,
    max_open_fiscal_years INTEGER    DEFAULT 3,
    fiscal_year_start_month INTEGER  NOT NULL DEFAULT 1,
    fiscal_year_start_day   INTEGER  NOT NULL DEFAULT 1,

    -- === APARIENCIA ===
    theme_default        TEXT        NOT NULL DEFAULT 'light',
    supported_themes     TEXT[]      DEFAULT '{light,dark}',
    logo_url             TEXT,
    primary_color        TEXT        DEFAULT '#1a73e8',

    -- === NOTIFICACIONES ===
    notification_locale  TEXT        NOT NULL DEFAULT 'es-BO',
    email_footer_template TEXT,

    -- === PARÁMETROS PIP (@bauth_config_param.*) ===
    -- El Motor de Identidad (PDP) resuelve @bauth_config_param.<clave> buscando aquí primero,
    -- y luego en bglobal.global_config. JSONB abierto: {max_sessions:5, loa_default:2, ...}
    params_policy        JSONB       NOT NULL DEFAULT '{}',

    -- === TRAZABILIDAD ===
    metadata             JSONB       DEFAULT '{}',
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itcfg_tenant   ON bauth.idn_tenant_config(tenant_id);
CREATE INDEX IF NOT EXISTS idx_itcfg_locale   ON bauth.idn_tenant_config USING GIN (locale_default jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itcfg_params   ON bauth.idn_tenant_config USING GIN (params_policy jsonb_path_ops);

COMMENT ON TABLE bauth.idn_tenant_config IS
'TENANT | Configuración regional y parámetros PIP del tenant — relación 1:1 con idn_tenant; define locale, zona horaria, moneda, formato de fecha/hora, tema visual y el JSONB de parámetros que el PDP usa al evaluar @bauth_config_param.*.
Fuente: creado automáticamente al registrar un nuevo tenant con los defaults de Bolivia (es-BO, America/La_Paz, BOB); el ADMIN del tenant actualiza sus preferencias regionales vía portal de configuración.
Administración: UNIQUE tenant_id (1:1 con idn_tenant); params_policy JSONB es leído por el PDP en cada evaluación del árbol T-162; el PDP busca primero aquí y cae a bglobal.global_config (piso del sistema) si la clave no existe.
WORM: no (configuración regional actualizable libremente por el tenant).
Particionada: no.
Estándar: BCP 47 (RFC 5646), ISO 4217:2015, IANA TZ Database, ISO 8601:2019, SBOS-049 §4. T-009.';

COMMENT ON COLUMN bauth.idn_tenant_config.params_policy IS
  '[SBOS-049] [A.48] JSONB de parámetros de política del tenant.
   El PDP lo consulta al evaluar @bauth_config_param.<clave> en el árbol de políticas T-162.
   Ejemplo: {"max_sessions":5,"loa_default":2,"session_idle_timeout":900,"mfa_grace_minutes":0}.
   Si la clave no está aquí → el PDP cae a bglobal.global_config (piso del sistema).';

COMMENT ON COLUMN bauth.idn_tenant_config.locale_default IS '[BCP 47] Snapshot JSONB del locale por defecto del tenant.';
COMMENT ON COLUMN bauth.idn_tenant_config.timezone_default IS '[IANA TZ] Snapshot JSONB de la zona horaria del tenant.';
COMMENT ON COLUMN bauth.idn_tenant_config.currency_default IS '[ISO 4217] Snapshot JSONB de la moneda funcional del tenant.';


-- ======================================================================
-- T-010 — bauth.idn_tenant_domain
-- Dominios DNS del tenant — prefijo del ctx_id (SBOS-049 capa 1).
-- REPARACIONES: nginx_config, k8s_hpa_config, health_config eliminados (infra BOS).
-- Agregado: ctx_prefix — el segmento que este dominio aporta al ctx_id.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_domain (
    domain_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    fqdn             TEXT        UNIQUE NOT NULL,
    subdomain        TEXT,
    domain_type      domain_type_enum NOT NULL DEFAULT 'WEB',
    is_primary       BOOLEAN     NOT NULL DEFAULT false,
    is_custom        BOOLEAN     NOT NULL DEFAULT false,
    ctx_prefix       TEXT,

    -- === CONFIGURACIONES DE DOMINIO (JSONB) ===
    dns_config       JSONB       DEFAULT '{}',
    ssl_config       JSONB       DEFAULT '{}',
    security_config  JSONB       DEFAULT '{}',
    redirect_config  JSONB       DEFAULT '{}',
    email_config     JSONB       DEFAULT '{}',
    contacts         JSONB       DEFAULT '{}',

    -- === ESTADO ===
    deploy_status    domain_status_enum DEFAULT 'PENDING',
    health_status    domain_status_enum DEFAULT 'PENDING',
    last_deployed_at TIMESTAMPTZ,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itdo_tenant   ON bauth.idn_tenant_domain(tenant_id, domain_type);
CREATE INDEX IF NOT EXISTS idx_itdo_fqdn     ON bauth.idn_tenant_domain(fqdn);
CREATE INDEX IF NOT EXISTS idx_itdo_primary  ON bauth.idn_tenant_domain(tenant_id) WHERE is_primary = true;
CREATE INDEX IF NOT EXISTS idx_itdo_dns      ON bauth.idn_tenant_domain USING GIN (dns_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itdo_security ON bauth.idn_tenant_domain USING GIN (security_config jsonb_path_ops);

COMMENT ON TABLE bauth.idn_tenant_domain IS
'TENANT | Dominios DNS del tenant — el dominio primary define la capa 1 del ctx_id (SBOS-049) y el prefijo ctx_prefix que identifica el tenant en toda trazabilidad del Context Plane; soporta múltiples dominios (web, API, admin, correo).
Fuente: creado por bOS al configurar el dominio del tenant durante el onboarding; el ADMIN del tenant puede añadir dominios adicionales vía RPC bauth.tenant.domain.register; el dominio primary no puede eliminarse.
Administración: solo un dominio is_primary por tenant (constraint); deploy_status y health_status actualizados por bOS al desplegar; dns_config y ssl_config contienen toda la configuración DNS/TLS en JSONB versionado.
WORM: no (deploy_status y health_status se actualizan en ciclo de vida normal de despliegue).
Particionada: no.
Estándar: RFC 952/1123 (nomenclatura DNS), RFC 8446 (TLS 1.3), RFC 8555 (ACME/Let''s Encrypt), SBOS-049 §3.1. T-010.';

COMMENT ON COLUMN bauth.idn_tenant_domain.ctx_prefix   IS '[SBOS-049 §3.1] Prefijo de ctx_id para este dominio: skull.sbos.bo. Capa 1 del Context Plane.';
COMMENT ON COLUMN bauth.idn_tenant_domain.dns_config   IS '[JSONB] [RFC 1035] {provider, record_type, target, records[], verified_at}.';
COMMENT ON COLUMN bauth.idn_tenant_domain.ssl_config   IS '[JSONB] [RFC 8446/8555] {provider, cert_secret, expires_at, acme_challenge, sans[]}.';
COMMENT ON COLUMN bauth.idn_tenant_domain.security_config IS '[JSONB] [NIST 800-53 SC-8] {force_ssl, hsts, csp, cors_origins[], waf_enabled, rate_limit}.';
COMMENT ON COLUMN bauth.idn_tenant_domain.email_config IS '[JSONB] [RFC 5321/7208/6376/7489] {mx, spf, dkim, dmarc, smtp, imap}.';
COMMENT ON COLUMN bauth.idn_tenant_domain.contacts     IS '[JSONB] [ISO 27001 A.6.1.1] {admin_id, technical_id, security_id, billing_id}.';


-- ======================================================================
-- T-011 — bauth.idn_tenant_network
-- Redes CIDR autorizadas por tenant. Zero Trust geolocalización.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_network (
    network_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT        NOT NULL,
    network_type     network_type_enum NOT NULL DEFAULT 'LAN',
    cidr             CIDR        NOT NULL,
    gateway          INET,
    dns_servers      INET[],
    vlan_id          INTEGER,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    metadata         JSONB       DEFAULT '{}',
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itnw_tenant  ON bauth.idn_tenant_network(tenant_id, network_type);
CREATE INDEX IF NOT EXISTS idx_itnw_cidr    ON bauth.idn_tenant_network USING GIST (cidr inet_ops);

COMMENT ON TABLE bauth.idn_tenant_network IS
'TENANT | Redes y CIDRs autorizados por tenant para control de acceso Zero Trust — el PEP (Kong) valida en D07 que la IP del request pertenezca a al menos un CIDR activo del tenant antes de autorizar la operación.
Fuente: configurado por SECURITY_ADMIN del tenant durante el onboarding; puede actualizarse al agregar nuevas sedes, VPNs o redes de acceso remoto; {}=sin restricción de red (solo para tenants en modo desarrollo).
Administración: el índice GIST (inet_ops) optimiza la búsqueda de CIDRs; redes de tipo MANAGEMENT solo accesibles desde is_internal=true; VPN requiere que el gateway sea el endpoint de salida de la VPN soberana SBOS.
WORM: no (is_active y vlan_id actualizables al reorganizar la topología de red).
Particionada: no.
Estándar: RFC 4632 (CIDR), RFC 1918 (direcciones privadas), NIST SP 800-207 §2.1 (Zero Trust network access). T-011.';

COMMENT ON COLUMN bauth.idn_tenant_network.cidr IS '[RFC 4632] Rango CIDR: 10.0.1.0/24, 192.168.0.0/16. GIST index para inet_ops.';

-- T-168 — bauth.idn_tenant_fal_config
-- [NIST SP 800-63-4 §5] [OpenID Connect Core 1.0] [RFC 9449 (DPoP)] [RFC 8705 (mTLS)] [D00-B09]
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_fal_config (
    fal_config_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id)
                        ON DELETE CASCADE,
    rp_client_id        TEXT        NOT NULL,
    rp_name             JSONB       NOT NULL DEFAULT '{"es":"Sin nombre","en":"Unnamed"}',
    rp_description      TEXT        NULL,
    fal_level           TEXT        NOT NULL DEFAULT 'FAL1',
    CONSTRAINT chk_ifal_level CHECK (fal_level IN ('FAL1','FAL2','FAL3')),
    allowed_protocols   TEXT[]      NOT NULL DEFAULT '{OIDC}',
    require_pkce        BOOLEAN     NOT NULL DEFAULT true,
    require_dpop        BOOLEAN     NOT NULL DEFAULT false,
    require_mtls        BOOLEAN     NOT NULL DEFAULT false,
    assertion_ttl_sec   INTEGER     NOT NULL DEFAULT 3600,
    refresh_ttl_sec     INTEGER     NULL DEFAULT 86400,
    max_clock_skew_sec  SMALLINT    NOT NULL DEFAULT 30,
    allowed_redirect_uris TEXT[]    NOT NULL DEFAULT '{}',
    allowed_claims      TEXT[]      NULL,
    require_auth_time   BOOLEAN     NOT NULL DEFAULT false,
    require_acr_values  TEXT[]      NULL,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ifal_tenant_rp UNIQUE (tenant_id, rp_client_id),
    CONSTRAINT chk_ifal_fal2_dpop CHECK (
        fal_level NOT IN ('FAL2','FAL3') OR require_dpop = true OR require_mtls = true
    ),
    CONSTRAINT chk_ifal_fal3_mtls CHECK (
        fal_level != 'FAL3' OR require_mtls = true
    )
);

CREATE INDEX IF NOT EXISTS idx_ifal_tenant
    ON bauth.idn_tenant_fal_config(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_ifal_client
    ON bauth.idn_tenant_fal_config(rp_client_id)
    WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ifal_level
    ON bauth.idn_tenant_fal_config(fal_level, tenant_id)
    WHERE is_active = true;

COMMENT ON TABLE bauth.idn_tenant_fal_config IS
'TENANT | Configuración del Federation Assurance Level (FAL) por Relying Party registrada en bAuth como IdP — FAL1: aserción firmada, FAL2: token bound a canal (DPoP), FAL3: hardware-binding (mTLS); los CHECKs garantizan coherencia criptográfica.
Fuente: registrado por el ADMIN del tenant al integrar una nueva aplicación RP vía RPC bauth.federation.rp.register; dpop_required y mtls_required se configuran según el nivel de aseguramiento requerido por la RP.
Administración: UNIQUE (tenant_id, rp_client_id); cambios de FAL level requieren re-aprobación de SECURITY_ADMIN; is_active=false desactiva la integración sin revocar el historial de tokens emitidos; max_clock_skew_sec controla la tolerancia de reloj entre bAuth y la RP.
WORM: no (is_active y nivel FAL actualizables durante el ciclo de vida de la integración).
Particionada: no.
Seed: DDLs/seeds/bauth_T168__idn_tenant_fal_config.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-63-4 §5 (FAL), OpenID Connect Core 1.0 §3.3, RFC 9449 (DPoP), RFC 8705 (mTLS). T-168.';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.fal_level IS '[NIST SP 800-63-4 §5] FAL1=signed assertion · FAL2=bound assertion (DPoP) · FAL3=holder-of-key (mTLS+hardware).';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.require_pkce IS '[RFC 7636] FAL1+: PKCE previene authorization code interception. S256 obligatorio.';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.require_dpop IS '[RFC 9449] FAL2+: DPoP vincula el access token al par de claves del cliente.';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.require_mtls IS '[RFC 8705] FAL3: certificate-bound access tokens.';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.assertion_ttl_sec IS 'FAL1: hasta 3600s · FAL2: ≤900s recomendado · FAL3: ≤300s.';
COMMENT ON COLUMN bauth.idn_tenant_fal_config.allowed_redirect_uris IS '[RFC 6749 §3.1.2] FAL2+: registro estricto sin wildcards.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║              NIVEL 2 — CALENDARIO (bcalendar + bridge)              ║
-- ║   bcalendar.cal_* · bauth.idn_tenant_calendar_assignment                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-012 — bcalendar.cal_fiscal_year
-- Años fiscales con 12 períodos mensuales. Multi-gestión.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_fiscal_year (
    fiscal_year_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id             UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    company_id            UUID,
    fiscal_year           INTEGER     NOT NULL,
    name                  TEXT        NOT NULL,
    status                fiscal_year_status_enum NOT NULL DEFAULT 'OPEN',
    start_date            DATE        NOT NULL,
    end_date              DATE,
    closed_by             UUID,
    closed_at             TIMESTAMPTZ,
    periods               JSONB       NOT NULL DEFAULT '[
        {"month":1,"name":"Enero","status":"OPEN"},{"month":2,"name":"Febrero","status":"OPEN"},
        {"month":3,"name":"Marzo","status":"OPEN"},{"month":4,"name":"Abril","status":"OPEN"},
        {"month":5,"name":"Mayo","status":"OPEN"},{"month":6,"name":"Junio","status":"OPEN"},
        {"month":7,"name":"Julio","status":"OPEN"},{"month":8,"name":"Agosto","status":"OPEN"},
        {"month":9,"name":"Septiembre","status":"OPEN"},{"month":10,"name":"Octubre","status":"OPEN"},
        {"month":11,"name":"Noviembre","status":"OPEN"},{"month":12,"name":"Diciembre","status":"OPEN"}
    ]',
    is_current            BOOLEAN     DEFAULT false,
    allows_prior_adjustments BOOLEAN  DEFAULT true,
    max_adjustment_months_back INTEGER DEFAULT 12,
    ctx_id                TEXT        NOT NULL DEFAULT 'system',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, company_id, fiscal_year)
);

CREATE INDEX IF NOT EXISTS idx_cfy_tenant   ON bcalendar.cal_fiscal_year(tenant_id, fiscal_year);
CREATE INDEX IF NOT EXISTS idx_cfy_current  ON bcalendar.cal_fiscal_year(tenant_id) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS idx_cfy_status   ON bcalendar.cal_fiscal_year(status, tenant_id);

COMMENT ON TABLE bcalendar.cal_fiscal_year IS
'CALENDARIO | Años fiscales con 12 períodos contables mensuales (JSONB) — permite operar la gestión corriente y anteriores simultáneamente; cada período puede cerrarse independientemente. Soporte multi-empresa y multi-gestión.
Fuente: creado por FINANCE_ADMIN del tenant al iniciar cada ejercicio fiscal; el seed inicial crea la gestión corriente del año de activación con is_current=true.
Administración: solo UNA gestión corriente activa por (tenant, company) — constraint enforced; el cierre de año actualiza is_current=false y crea la gestión siguiente; ajustes retroactivos limitados a max_adjustment_months_back.
WORM: no (status y periods se actualizan durante el ciclo de vida fiscal).
Particionada: no.
Estándar: NIC 1/IAS 1 §36-40 (períodos de reporte), NIC 8/IAS 8 §42 (cambios contables), SIN Bolivia Ley 2492 (cierre anual obligatorio), NIIF 1. T-013.';



COMMENT ON COLUMN bcalendar.cal_fiscal_year.periods IS '[JSONB] 12 períodos: {month, name, status}. Cada mes puede cerrarse independiente.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.is_current IS '[NIC 1] Solo UNA gestión corriente activa por (tenant, company). Transacciones nuevas van aquí.';


-- ======================================================================
-- T-014 — bcalendar.cal_calendar
-- Colecciones de calendarios por tenant. Tipos: WORK, FISCAL, etc.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_calendar (
    calendar_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT        NOT NULL,
    calendar_type    calendar_type_enum NOT NULL DEFAULT 'WORK',
    description      TEXT,
    color            TEXT        DEFAULT '#1a73e8',
    timezone         TEXT        NOT NULL DEFAULT 'America/La_Paz',
    is_system        BOOLEAN     NOT NULL DEFAULT false,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    metadata         JSONB       DEFAULT '{}',
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_ccal_tenant ON bcalendar.cal_calendar(tenant_id, calendar_type);

COMMENT ON TABLE bcalendar.cal_calendar IS
'CALENDARIO | Colección de calendarios por tenant — cada calendario es un contenedor de eventos con un tipo (WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE), zona horaria IANA y color para la UI.
Fuente: creado automáticamente al onboarding del tenant con los calendarios de sistema (WORK y HOLIDAY predefinidos con is_system=true); el ADMIN del tenant puede crear calendarios adicionales vía RPC bauth.calendar.create.
Administración: is_system=true = predefinido por SBOS, no puede eliminarse ni cambiarse el tipo; is_active=false desactiva sin borrar; timezone IANA determina cómo se expanden las ocurrencias de eventos recurrentes (cal_event).
WORM: no.
Particionada: no.
Seed: DDLs/seeds/bcalendar_T012__cal_calendar.sql — idempotente ON CONFLICT.
Estándar: RFC 4791 §4 (CalDAV VCALENDAR), RFC 5545 §3.6 (iCalendar), ISO 8601:2019. T-014.';


-- ======================================================================
-- T-015 — bcalendar.cal_event
-- Evento maestro con recurrencia RFC 5545. rrule sin expandir.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_event (
    event_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    calendar_id      UUID        NOT NULL REFERENCES bcalendar.cal_calendar(calendar_id) ON DELETE CASCADE,
    title            TEXT        NOT NULL,
    description      TEXT,
    dtstart          TIMESTAMPTZ NOT NULL,
    dtend            TIMESTAMPTZ,
    duration_minutes INTEGER,
    is_all_day       BOOLEAN     NOT NULL DEFAULT false,
    rrule            TEXT,
    exdate           TIMESTAMPTZ[] DEFAULT '{}',
    until_date       TIMESTAMPTZ,
    count_occurrences INTEGER,
    location         TEXT,
    status           TEXT        NOT NULL DEFAULT 'CONFIRMED',
    priority         INTEGER     DEFAULT 0,
    created_by       UUID,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cev_calendar ON bcalendar.cal_event(calendar_id, dtstart);
CREATE INDEX IF NOT EXISTS idx_cev_dtstart  ON bcalendar.cal_event(dtstart, dtend);
CREATE INDEX IF NOT EXISTS idx_cev_rrule    ON bcalendar.cal_event(calendar_id) WHERE rrule IS NOT NULL;

COMMENT ON TABLE bcalendar.cal_event IS
'CALENDARIO | Evento maestro con soporte de recurrencia RFC 5545 — una serie recurrente se almacena como una sola fila con el rrule TEXT; las ocurrencias se materializan on-demand; el evaluador temporal D04 consulta esta tabla para validar ventanas de acceso.
Fuente: creado por el ADMIN del tenant o el usuario propietario del calendario vía RPC bauth.calendar.event.create; eventos de sistema (mantenimiento, vencimientos) insertados automáticamente por bAuth.
Administración: status CONFIRMED es el estado operativo; TENTATIVE bloquea el slot sin confirmar; CANCELLED mantiene el registro histórico; el evaluador D04 solo considera eventos CONFIRMED en calendario WORK activo.
WORM: no.
Particionada: no.
Estándar: RFC 5545 §3.6.1 (VEVENT), RFC 7953 §3.2 (VAVAILABILITY), ISO 8601:2019. T-015.';

COMMENT ON COLUMN bcalendar.cal_event.rrule  IS '[RFC 5545 §3.8.5] FREQ=WEEKLY;BYDAY=MO,WE,FR. NULL=evento único.';
COMMENT ON COLUMN bcalendar.cal_event.exdate IS '[RFC 5545 §3.8.5.1] Fechas excluidas de la recurrencia.';


-- ======================================================================
-- T-016 — bcalendar.cal_alarm
-- Alarma/disparador de notificación vía bNotify.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_alarm (
    alarm_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    event_id         UUID        NOT NULL REFERENCES bcalendar.cal_event(event_id) ON DELETE CASCADE,
    trigger_seconds  INTEGER     NOT NULL DEFAULT -900,
    channel          alarm_channel_enum NOT NULL DEFAULT 'CHAT',
    template_ref     TEXT,
    recipient_id     UUID,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    last_triggered_at TIMESTAMPTZ,
    next_trigger_at  TIMESTAMPTZ,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_calrm_next ON bcalendar.cal_alarm(next_trigger_at, is_active) WHERE is_active = true;

COMMENT ON TABLE bcalendar.cal_alarm IS
'CALENDARIO | Alarmas/disparadores de notificación vinculados a eventos del calendario — puente entre bcalendar y bNotify; cada alarma define cuándo y por qué canal notificar antes o después del dtstart del evento.
Fuente: creado por el usuario al configurar recordatorios de un evento vía RPC bauth.calendar.alarm.create; alarmas de sistema (vencimiento de certificados, revisiones IGA) insertadas automáticamente por bAuth.
Administración: trigger_seconds negativo = antes del dtstart (-900=15min antes); next_trigger_at calculado por el job de calendario al procesar el rrule; job polling: WHERE next_trigger_at <= NOW() AND is_active = true.
WORM: no (last_triggered_at y next_trigger_at se actualizan tras cada disparo).
Particionada: no.
Estándar: RFC 5545 §3.6.6 (VALARM), RFC 4791 §7.4 (CalDAV alarmas). T-016.';


-- ======================================================================
-- T-017 — bcalendar.cal_notification_log  [WORM]
-- Registro inmutable de notificaciones enviadas.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_notification_log (
    notification_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    alarm_id         UUID        NOT NULL,
    event_id         UUID        NOT NULL,
    channel          alarm_channel_enum NOT NULL,
    recipient_id     UUID,
    template_used    TEXT,
    outcome          TEXT        NOT NULL DEFAULT 'SENT',
    error_message    TEXT,
    sent_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id           TEXT        NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_cnl_alarm ON bcalendar.cal_notification_log(alarm_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_cnl_event ON bcalendar.cal_notification_log(event_id, sent_at DESC);

REVOKE UPDATE, DELETE ON bcalendar.cal_notification_log FROM PUBLIC;

COMMENT ON TABLE bcalendar.cal_notification_log IS
'CALENDARIO | Log WORM de notificaciones de calendario enviadas vía bNotify — registra cada intento de envío (SENT, FAILED, RETRY) con el canal, plantilla usada y resultado; evidencia de auditoría de comunicaciones del sistema.
Fuente: insertado automáticamente por el job de alarmas de bAuth al disparar cada cal_alarm; la inserción registra el resultado inmediato (SENT o FAILED con error_message).
Administración: REVOKE UPDATE/DELETE — append-only; los FAILED generan reintento por el job de alarmas hasta max_retries; ctx_id obligatorio (SBOS-049) para trazabilidad; no se borran registros — solo se archivan por retención.
WORM: sí — el log de notificaciones es evidencia de comunicación del sistema; modificarlo falsificaría el registro de alertas enviadas.
Particionada: no.
Estándar: ISO 27001 A.8.15, SBOS-049 §4 (ctx_id). T-017.';


-- ======================================================================
-- T-018 — bcalendar.cal_holiday
-- Feriados fijos y móviles por país/tenant.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_holiday (
    holiday_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT        NOT NULL,
    holiday_date     DATE        NOT NULL,
    is_recurring     BOOLEAN     NOT NULL DEFAULT true,
    country_code     CHAR(2)     NOT NULL DEFAULT 'BO',
    region           TEXT,
    description      TEXT,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, holiday_date, country_code)
);

CREATE INDEX IF NOT EXISTS idx_chol_tenant ON bcalendar.cal_holiday(tenant_id, holiday_date);
CREATE INDEX IF NOT EXISTS idx_chol_date   ON bcalendar.cal_holiday(holiday_date, country_code);

COMMENT ON TABLE bcalendar.cal_holiday IS
'CALENDARIO | Catálogo de feriados fijos y móviles por país y tenant — define los días no hábiles para GTRBAC y el evaluador temporal de roles; incluye feriados nacionales, departamentales y propios del tenant.
Fuente: seed inicial con feriados nacionales bolivianos (26 días Ley), departamentales Cochabamba/La Paz/Santa Cruz, y Navidad/Año Nuevo; ADMIN del tenant añade feriados propios vía RPC bauth.calendar.holiday.create.
Administración: is_recurring=true = se repite cada año automáticamente (feriado fijo); UNIQUE (tenant_id, holiday_date, country_code) previene duplicados; el evaluador D04 consulta esta tabla para determinar si una ventana de tiempo aplica hoy.
WORM: no.
Particionada: no.
Seed: DDLs/seeds/bcalendar_T015__cal_holiday_complete.sql — idempotente ON CONFLICT.
Estándar: ISO 8601:2019 (fechas), ILO Working Time Instruments §4 (días no laborables), GTRBAC §4.1 (calendarios de trabajo). T-018.';




-- ======================================================================
-- T-019 — bcalendar.cal_schedule
-- Horarios de trabajo y turnos. RFC 7953 VAVAILABILITY.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_schedule (
    schedule_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT        NOT NULL,
    days_of_week     INTEGER[]   NOT NULL DEFAULT '{1,2,3,4,5}',
    start_time       TIME        NOT NULL DEFAULT '08:00',
    end_time         TIME        NOT NULL DEFAULT '18:00',
    schedule_type    TEXT        NOT NULL DEFAULT 'REGULAR',
    shifts           JSONB,
    access_outside_schedule TEXT DEFAULT 'BLOCKED',
    is_default       BOOLEAN     NOT NULL DEFAULT false,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_csch_tenant ON bcalendar.cal_schedule(tenant_id);

COMMENT ON TABLE bcalendar.cal_schedule IS
'CALENDARIO | Horarios de trabajo y disponibilidad por tenant — define las ventanas operativas normales (días de semana + hora inicio/fin) que el evaluador temporal D04 usa para controlar el acceso dentro de horario vs. fuera de horario.
Fuente: configurado por HR_ADMIN o SECURITY_ADMIN del tenant al definir los horarios de trabajo; el seed crea un horario REGULAR por defecto (L-V 08:00-18:00) al onboarding del tenant.
Administración: access_outside_schedule define la política al detectar acceso fuera de horario (BLOCKED, PERMITTED, REQUIRES_APPROVAL, READ_ONLY); shifts JSONB permite modelar turnos en el mismo horario; is_default=true es el horario base evaluado sin asignación explícita.
WORM: no.
Particionada: no.
Seed: DDLs/seeds/bcalendar_T014__cal_schedule.sql — idempotente ON CONFLICT.
Estándar: RFC 7953 (VAVAILABILITY), ISO 8601:2019, GTRBAC §3.1 (Generalized Temporal RBAC). T-019.';

COMMENT ON COLUMN bcalendar.cal_schedule.shifts IS '[JSONB] Turnos: [{name:"Mañana",start:"06:00",end:"14:00"},{name:"Tarde",...}].';


-- ======================================================================
-- T-124 — bcalendar.cal_overtime_policy  [NUEVA]
-- Políticas de horas extra — acceso fuera de horario.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_overtime_policy (
    policy_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    schedule_id      UUID        REFERENCES bcalendar.cal_schedule(schedule_id) ON DELETE SET NULL,
    name             TEXT        NOT NULL,
    max_overtime_hours_daily    DECIMAL(5,2) NOT NULL DEFAULT 2.0,
    max_overtime_hours_weekly   DECIMAL(5,2) NOT NULL DEFAULT 10.0,
    requires_override_request   BOOLEAN     NOT NULL DEFAULT true,
    requires_manager_approval   BOOLEAN     NOT NULL DEFAULT true,
    loa_required_for_override   INTEGER     DEFAULT 2,
    applies_to_tiers            TEXT[]      DEFAULT '{BIZ_N1,BIZ_N2,BIZ_N3}',
    notification_roles          TEXT[]      DEFAULT '{}',
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cotp_tenant   ON bcalendar.cal_overtime_policy(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cotp_schedule ON bcalendar.cal_overtime_policy(schedule_id) WHERE schedule_id IS NOT NULL;

COMMENT ON TABLE bcalendar.cal_overtime_policy IS
'CALENDARIO | Políticas de horas extra — define los límites de overtime diario/semanal y si el acceso fuera del horario normal requiere override con aprobación de manager y LoA elevado (D04 árbol de políticas).
Fuente: configurado por HR_ADMIN del tenant; el seed crea una política de overtime conservadora por defecto (2h diarias, 10h semanales, requiere aprobación); SECURITY_ADMIN puede ajustar el loa_required_for_override.
Administración: el evaluador temporal D04 consulta esta tabla para determinar si el acceso fuera de horario está permitido o requiere workflow de aprobación; applies_to_tiers excluye SU y T0 que no tienen restricción de horario.
WORM: no.
Particionada: no.
Estándar: ILO Working Time Instruments §6 (horas extra), GTRBAC §6 (excepciones temporales), NIST AC-17(1). T-124.';

COMMENT ON COLUMN bcalendar.cal_overtime_policy.loa_required_for_override IS 'LoA mínimo (1/2/3) para solicitar acceso en overtime. Default 2 (AAL2).';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.applies_to_tiers IS 'Tiers sujetos a esta política: {BIZ_N1,BIZ_N2,...}. SU y T0 no restringidos.';


-- ======================================================================
-- T-125 — bcalendar.cal_break_policy  [NUEVA]
-- Políticas de pausa — ventanas de suspensión de sesión.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_break_policy (
    policy_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    schedule_id      UUID        REFERENCES bcalendar.cal_schedule(schedule_id) ON DELETE SET NULL,
    name             TEXT        NOT NULL,
    break_start      TIME        NOT NULL,
    break_end        TIME        NOT NULL,
    suspend_active_sessions BOOLEAN NOT NULL DEFAULT false,
    allow_session_resume    BOOLEAN NOT NULL DEFAULT true,
    resume_requires_reauth  BOOLEAN NOT NULL DEFAULT false,
    applies_to_tiers        TEXT[]  DEFAULT '{BIZ_N1,BIZ_N2,BIZ_N3,BIZ_N4,BIZ_N5}',
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_cbp_times CHECK (break_end > break_start)
);

CREATE INDEX IF NOT EXISTS idx_cbkp_tenant   ON bcalendar.cal_break_policy(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cbkp_schedule ON bcalendar.cal_break_policy(schedule_id) WHERE schedule_id IS NOT NULL;

COMMENT ON TABLE bcalendar.cal_break_policy IS
'CALENDARIO | Políticas de pausa (almuerzo, descanso) — define ventanas horarias en que las sesiones pueden suspenderse automáticamente y si se requiere re-autenticación al reanudar; el evaluador D04 la consulta para gestión de sesiones.
Fuente: configurado por HR_ADMIN del tenant al definir los descansos obligatorios; el seed puede crear una política de almuerzo por defecto (12:00-13:00) vinculada al horario REGULAR.
Administración: el job del evaluador temporal D04 aplica suspend_active_sessions al inicio de break_start; resume_requires_reauth fuerza re-autenticación al volver; applies_to_tiers excluye SU y T0.
WORM: no.
Particionada: no.
Estándar: ILO Working Time Instruments §8 (períodos de descanso), NIST SP 800-63B-4 §7.2 (reauthentication), GTRBAC §6. T-125.';

COMMENT ON COLUMN bcalendar.cal_break_policy.suspend_active_sessions IS 'true = bAuth suspende sesiones activas al inicio del break (NIST 800-63B-4 §7.2).';
COMMENT ON COLUMN bcalendar.cal_break_policy.resume_requires_reauth  IS 'true = el usuario debe re-autenticarse al volver de pausa.';


-- ======================================================================
-- T-013 — bauth.idn_tenant_calendar_assignment
-- Puente: asigna calendarios bcalendar a entidades bauth.
-- REPARACIÓN: FK real a bcalendar.cal_calendar + tenant_id para validación.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_calendar_assignment (
    assignment_id    UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    calendar_id      UUID        NOT NULL REFERENCES bcalendar.cal_calendar(calendar_id) ON DELETE CASCADE,
    owner_type       calendar_owner_type_enum NOT NULL,
    owner_id         UUID        NOT NULL,
    role             calendar_role_enum NOT NULL DEFAULT 'VIEWER',
    is_inherited     BOOLEAN     NOT NULL DEFAULT false,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (calendar_id, owner_type, owner_id)
);

CREATE INDEX IF NOT EXISTS idx_ica_tenant   ON bauth.idn_tenant_calendar_assignment(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ica_calendar ON bauth.idn_tenant_calendar_assignment(calendar_id);
CREATE INDEX IF NOT EXISTS idx_ica_owner    ON bauth.idn_tenant_calendar_assignment(owner_type, owner_id);

COMMENT ON TABLE bauth.idn_tenant_calendar_assignment IS
'CALENDARIO | Tabla puente que asigna calendarios bcalendar a entidades bauth (tenant, empresa, sucursal, usuario) — implementa herencia jerárquica: el tenant asigna y sus subentidades heredan con is_inherited=true.
Fuente: creado automáticamente por bAuth al onboarding para asignar el calendario WORK y HOLIDAY del sistema al tenant; el ADMIN puede asignar calendarios adicionales vía RPC bauth.calendar.assign.
Administración: UNIQUE (calendar_id, owner_type, owner_id) — una asignación por entidad por calendario; role=OWNER gestiona el calendario; VIEWER solo lectura; herencia se propaga al crear subentidades.
WORM: no.
Particionada: no.
Estándar: RFC 4791 §6.2 (ACL CalDAV), NIST AC-2(3) (Disable Inactive Accounts). T-013.';

COMMENT ON COLUMN bauth.idn_tenant_calendar_assignment.role IS '[ENUM] OWNER (gestiona el calendario), EDITOR (modifica eventos), VIEWER (solo lectura).';
COMMENT ON COLUMN bauth.idn_tenant_calendar_assignment.is_inherited IS 'true = asignación heredada del level superior (no directa).';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                NIVEL 3 — ROLES (bauth)                              ║
-- ║   Catálogo + tipo + jerarquía + closure table DAG                   ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-191 — bauth.idn_roles_iga_category
-- Categorías IGA para gobernanza de ciclo de vida de roles.
-- Agrupa roles por función (BUSINESS, IT_INFRASTRUCTURE, APPLICATION,
-- PRIVILEGED, EMERGENCY, SERVICE, STANDARD) con ciclo de revisión propio.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_iga_category (
    category_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    code               TEXT        UNIQUE NOT NULL,
    name               JSONB       NOT NULL,
    description        JSONB,
    is_privileged      BOOLEAN     NOT NULL DEFAULT false,
    review_cycle_days  INTEGER     NOT NULL DEFAULT 365 CHECK (review_cycle_days > 0),
    sort_order         INTEGER     NOT NULL DEFAULT 0,
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.idn_roles_iga_category IS
'ROLES | Categorías IGA (Identity Governance & Administration) para la gobernanza del ciclo de vida de roles — agrupa roles por función (BUSINESS, IT, APPLICATION, PRIVILEGED, EMERGENCY, SERVICE) con ciclo de revisión propio por categoría.
Fuente: seed inicial con 7 categorías canónicas del estándar SBOS al despliegue; nuevas categorías solo vía migración DDL con HITL al necesitar un tipo de rol no contemplado.
Administración: review_cycle_days determina la frecuencia de certificación IGA (PRIVILEGED=90d, EMERGENCY=30d, BUSINESS=365d); is_privileged=true activa campaña de revisión trimestral obligatoria (NIST AC-2(7)); is_active=false archiva la categoría sin eliminar roles existentes.
WORM: no.
Particionada: no.
Seed: DDLs/seeds/bauth_T194__idn_roles_iga_category.sql — idempotente ON CONFLICT.
Estándar: IGA best practices, NIST SP 800-53 AC-2(7), ISO 24760-2:2025 §5. T-191.';



-- ======================================================================
-- T-040 — bauth.idn_roles_rol_type
-- Clasificación de cuentas: INDIVIDUAL, M2M, SYSTEM, BOT, DEVICE, etc.
-- Catálogo controlado — 10 tipos definidos en A.65.02.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_type (
    type_id                          UUID        PRIMARY KEY DEFAULT uuidv7(),
    code                             TEXT        UNIQUE NOT NULL,
    name                             JSONB       NOT NULL,
    description                      JSONB,
    is_privileged                    BOOLEAN     NOT NULL DEFAULT false,
    requires_human_owner             BOOLEAN     NOT NULL DEFAULT false,
    default_certification_cycle_days INTEGER     NOT NULL DEFAULT 365,
    is_active                        BOOLEAN     NOT NULL DEFAULT true,
    sort_order                       INTEGER     NOT NULL DEFAULT 0,
    created_at                       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.idn_roles_rol_type IS
'ROLES | Catálogo controlado de 10 tipos de cuenta para todos los roles del ecosistema SBOS:
INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE, EMERGENCY.
Gobierna si el rol es privilegiado (revisión trimestral IGA), si requiere propietario humano
(cuentas NHI — NIST AC-2(7)), y el ciclo de certificación de acceso IGA por tipo.
Fuente: seed de despliegue con los 10 tipos canónicos; altas nuevas requieren migración DDL con HITL.
Administración: catálogo de referencia inmutable en operación normal; solo actualizable vía migración
aprobada por HITL. is_active=false desactiva sin borrar para trazabilidad histórica.
WORM: no — is_active puede actualizarse; pero no se eliminan filas.
Particionada: no.
Seed: DDLs/seeds/bauth_T040__idn_roles_rol_type.sql — idempotente ON CONFLICT.
Estándar: NIST RBAC N3, ANSI INCITS 359-2004, SCIM RFC 7643, NIST AC-2(7), ISO 27001 A.5.15. T-040.';

COMMENT ON COLUMN bauth.idn_roles_rol_type.code        IS 'INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE, EMERGENCY.';
COMMENT ON COLUMN bauth.idn_roles_rol_type.name        IS '[JSONB] {"es":"Individual","en":"Individual"}.';
COMMENT ON COLUMN bauth.idn_roles_rol_type.description IS '[JSONB] Descripción bilingüe del tipo de cuenta.';
COMMENT ON COLUMN bauth.idn_roles_rol_type.is_privileged IS '[NIST AC-2(7)] true = acceso privilegiado, revisión trimestral.';
COMMENT ON COLUMN bauth.idn_roles_rol_type.requires_human_owner IS '[NIST AC-2(7)] true = toda cuenta de este tipo requiere propietario humano designado.';



-- ======================================================================
-- T-042 — bauth.idn_roles_rol_tier
-- Parámetros de seguridad por tier (SU, T0, T1, BIZ_N1..N5, EXT_N0, M2M, VISITOR).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_tier (
    tier_id                      UUID        PRIMARY KEY DEFAULT uuidv7(),
    tier                         rol_tier_enum UNIQUE NOT NULL,
    display_name                 JSONB       NOT NULL,
    description                  JSONB,
    loa_required                 INTEGER     NOT NULL CHECK (loa_required BETWEEN 1 AND 3),
    session_timeout_minutes      INTEGER     NOT NULL DEFAULT 480,
    max_sessions                 INTEGER     NOT NULL DEFAULT 3,
    step_up_loa                  INTEGER     CHECK (step_up_loa BETWEEN 1 AND 3),
    mfa_required                 BOOLEAN     NOT NULL DEFAULT false,
    mfa_methods_allowed          TEXT[]      DEFAULT '{}',
    rate_limit_override          INTEGER,
    nist_aal_reference           TEXT,
    is_privileged_tier           BOOLEAN     NOT NULL DEFAULT false,
    requires_pam                 BOOLEAN     NOT NULL DEFAULT false,
    certification_cycle_days     INTEGER     NOT NULL DEFAULT 365,
    inactivity_lockout_days      INTEGER     NOT NULL DEFAULT 90,
    requires_use_justification   BOOLEAN     NOT NULL DEFAULT false,
    sort_order                   INTEGER     NOT NULL DEFAULT 0,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_irtier_tier ON bauth.idn_roles_rol_tier(tier);

COMMENT ON TABLE bauth.idn_roles_rol_tier IS
'ROLES | Catálogo de parámetros de seguridad por tier (jerarquía de privilegio) para los 11 niveles
del ecosistema: SU (LoA3, PAM obligatorio), T0, T1, BIZ_N1..N5, EXT_N0, M2M y VISITANTE.
Cada fila define: loa_required, session_timeout_minutes, mfa_required, step_up_loa, certification_
cycle_days e inactivity_lockout_days. Controla qué tiers requieren PAM y justificación de uso.
Fuente: seed de despliegue con los 11 tiers canónicos; los parámetros son ajustables por HITL.
Administración: los valores de seguridad (timeouts, MFA) se ajustan mediante migración DDL aprobada;
no se crean ni eliminan tiers en operación — son el vocabulario fijo del sistema de roles.
WORM: no — los parámetros de seguridad deben poder ajustarse vía migración controlada.
Particionada: no.
Seed: DDLs/seeds/bauth_T042__idn_roles_rol_tier.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-63B-4 §4, ISO 27001 A.5.15, NIST AC-5, RFC 9470 (Step-Up). T-042.';

COMMENT ON COLUMN bauth.idn_roles_rol_tier.loa_required               IS '[NIST 800-63B-4] Nivel de aseguramiento mínimo: 1=AAL1, 2=AAL2, 3=AAL3.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.step_up_loa                IS '[RFC 9470] LoA is_required para step-up por contexto de riesgo.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.mfa_methods_allowed        IS 'NULL=todos, ["TOTP","WEBAUTHN"]=restricción por tier.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.is_privileged_tier         IS '[NIST AC-2(7)] true = tier privilegiado, campaña IGA trimestral.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.requires_pam               IS 'true = requiere PAM (CyberArk/Vault) — solo SU y T0.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.certification_cycle_days   IS '[IGA] Ciclo de certificación de acceso en días.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.inactivity_lockout_days    IS '[ISO 27001 A.5.15] Días de inactividad antes de bloqueo automático.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.requires_use_justification IS '[NIST AC-2(7)] true = justificación obligatoria en cada uso (SU y T0).';



-- ======================================================================
-- T-041 — bauth.idn_roles_rol_hierarchical
-- Árbol de roles del tenant (adjacency list). FK a T-040 (type), T-042 (tier), T-162 (template).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_hierarchical (
    id                       UUID                 PRIMARY KEY DEFAULT uuidv7(),
    tenant_id                UUID                 NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id                UUID                 REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE RESTRICT,
    type_id                  UUID                 NOT NULL REFERENCES bauth.idn_roles_rol_type(type_id),
    tier                     rol_tier_enum        NOT NULL DEFAULT 'BIZ_N3',
    code                     TEXT                 NOT NULL,
    name                     JSONB                NOT NULL,
    description              JSONB,
    depth                    INTEGER              NOT NULL DEFAULT 0,
    is_inheritable           BOOLEAN              NOT NULL DEFAULT true,
    status                   rol_status_enum      NOT NULL DEFAULT 'ACTIVE',
    version                  TEXT                 NOT NULL DEFAULT '1.0',
    ial_min                  ial_level_enum       DEFAULT 'IAL1',
    metadata_b1              JSONB                NOT NULL DEFAULT '{
      "nist_rbac_level":         null,
      "caeb_code":               null,
      "description_long":        null,
      "department":              null,
      "cost_center":             null,
      "region":                  null,
      "territory_code":          null,
      "job_family":              null,
      "job_level":               null,
      "max_subordinates":        null,
      "required_certifications": [],
      "reporting_line":          null
    }'::jsonb,
    template_id              UUID,
    role_owner_id            UUID                 REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    category_id              UUID                 REFERENCES bauth.idn_roles_iga_category(category_id),
    risk_classification      risk_level_enum      NOT NULL DEFAULT 'MEDIUM',
    sensitivity_label        sensitivity_label_enum NOT NULL DEFAULT 'INTERNAL',
    business_justification   JSONB,
    max_simultaneous_holders INTEGER              CHECK (max_simultaneous_holders > 0),
    last_reviewed_at         TIMESTAMPTZ,
    next_review_at           TIMESTAMPTZ,
    approval_required        BOOLEAN              NOT NULL DEFAULT false,
    -- B01 §audit (G-B01-06/07) — trazabilidad del artefacto
    created_by               UUID                 REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    updated_by               UUID                 REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    version_number           INTEGER              NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ          NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ          NOT NULL DEFAULT now(),
    -- B01 §digital_signature (G-B01-08) — firma del contrato del rol (motor pendiente)
    digital_signature        JSONB                NOT NULL DEFAULT '{
        "algorithm":            "EdDSA_Ed25519",
        "signature":            null,
        "signed_at":            null,
        "signed_by":            null,
        "certificate_id":       null,
        "post_quantum_planned": true
    }'::jsonb,
    -- B02 §validity_period — NIST AC-2(d) · ISO 27001 A.5.18
    validity_type            bauth.role_validity_type NOT NULL DEFAULT 'INDEFINITE',
    valid_from               DATE                     NOT NULL DEFAULT CURRENT_DATE,
    valid_until              DATE,
    duration_interval        INTERVAL,
    max_renewals             SMALLINT CHECK (max_renewals IS NULL OR max_renewals > 0),
    renewal_count            SMALLINT NOT NULL DEFAULT 0,
    -- MVU — Motor de Versionado Universal
    sys_since                TIMESTAMPTZ            NOT NULL DEFAULT now(),
    change_channel           bauth.ver_channel_enum NOT NULL DEFAULT 'BOOTSTRAP',
    change_reason            TEXT,
    security_impact          risk_level_enum,
    approved_by              UUID REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    approved_at              TIMESTAMPTZ,
    UNIQUE (tenant_id, code),
    CONSTRAINT chk_irrh_b02_validity CHECK (
        (validity_type = 'FIXED'
            AND valid_until IS NOT NULL)
        OR
        (validity_type IN ('TEMPORARY','EMERGENCY')
            AND duration_interval IS NOT NULL
            AND valid_until IS NULL)
        OR
        (validity_type IN ('INDEFINITE','PROJECT_BASED'))
    )
);

CREATE INDEX IF NOT EXISTS idx_irrh_tenant     ON bauth.idn_roles_rol_hierarchical(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_irrh_parent     ON bauth.idn_roles_rol_hierarchical(parent_id);
CREATE INDEX IF NOT EXISTS idx_irrh_tier       ON bauth.idn_roles_rol_hierarchical(tenant_id, tier);
CREATE INDEX IF NOT EXISTS idx_irrh_type       ON bauth.idn_roles_rol_hierarchical(type_id);
CREATE INDEX IF NOT EXISTS idx_irrh_template   ON bauth.idn_roles_rol_hierarchical(template_id)    WHERE template_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irrh_name       ON bauth.idn_roles_rol_hierarchical USING GIN (name jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_irrh_owner      ON bauth.idn_roles_rol_hierarchical(role_owner_id)  WHERE role_owner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irrh_risk       ON bauth.idn_roles_rol_hierarchical(tenant_id, risk_classification);
CREATE INDEX IF NOT EXISTS idx_irrh_category   ON bauth.idn_roles_rol_hierarchical(category_id);
CREATE INDEX IF NOT EXISTS idx_irrh_review     ON bauth.idn_roles_rol_hierarchical(next_review_at) WHERE next_review_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irrh_label      ON bauth.idn_roles_rol_hierarchical(tenant_id, sensitivity_label);
CREATE INDEX IF NOT EXISTS idx_irrh_created_by ON bauth.idn_roles_rol_hierarchical(created_by)     WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irrh_updated_by ON bauth.idn_roles_rol_hierarchical(updated_by)     WHERE updated_by IS NOT NULL;

-- Trigger B01 G-B01-06: auto-incrementa version_number en cada UPDATE real
CREATE OR REPLACE FUNCTION bauth.fn_irrh_version_bump()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.version_number := OLD.version_number + 1;
    NEW.updated_at     := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_irrh_version_bump ON bauth.idn_roles_rol_hierarchical;
CREATE TRIGGER trg_irrh_version_bump
    BEFORE UPDATE ON bauth.idn_roles_rol_hierarchical
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION bauth.fn_irrh_version_bump();

COMMENT ON TABLE bauth.idn_roles_rol_hierarchical IS
'ROLES | Catálogo maestro de roles por tenant en estructura adjacency-list (árbol DAG-OR).
Es el corazón del motor NIST RBAC N3: cada fila es un rol con tier, tipo, política de vigencia
(B02), metadatos organizacionales (B01/metadata_b1), riesgo y etiqueta de confidencialidad.
Complementado por T-063 (closure table) para consultas O(1) de herencia; por T-152 (historial WORM
de versiones); por T-162 (árbol de políticas). Textos visibles al usuario en JSONB bilingüe.
Fuente: seed inicial de plantillas base 66 roles; altas de tenant vía RPC bauth.role.create.
Administración: solo ROLE_ADMIN y superior pueden crear/modificar; cambios de tier y tipo requieren
aprobación dual (NIST AC-5); expiración automática gestionada por trg_irrh_b02_validity y el
reconcile loop fn_b02_reconcile_expiry. Motor de Versionado (T-152) registra cada cambio MAJOR.
WORM: no — la tabla es mutable; el historial inmutable vive en T-152.
Particionada: no (la tabla principal no se particiona; T-152 puede particionarse si crece).
Estándar: NIST RBAC N3, ANSI INCITS 359-2004, SCIM RFC 7643, ISO 27001 A.5.15, NIST AC-2(7). T-041.';

COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.tier                   IS '[ENUM] SU, T0, T1, BIZ_N1..N5, EXT_N0, M2M, VISITOR.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.description            IS '[JSONB] {"es":"...","en":"..."} — descripción bilingüe del rol.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.is_inheritable         IS 'true = sus privilegios se heredan a roles hijos en el DAG.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.template_id            IS 'FK DEFERRED a bauth.idn_roles_template(id) — nodo DOMAIN que rige este rol.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.metadata_b1            IS
  '[B1 de SBOS-ROLTEMPLATE-v6_0] Metadatos organizacionales del rol — estructura canónica única
   (no duplicar en columnas separadas). Keys:
     nist_rbac_level         INTEGER   — level IAL del rol (1=IAL1, 2=IAL2, 3=IAL3) · NIST SP 800-63-4
     caeb_code               TEXT      — sector CAEB SIN Bolivia (ej: "CAEB-J") · único punto de verdad
     description_long        JSONB     — descripción extendida {"es":"...","en":"..."} — más detallada que description
     department              TEXT      — departamento organizacional del tenant
     cost_center             TEXT      — centro de costo del tenant
     region                  TEXT      — región geográfica (ej: "BO-LP")
     territory_code          TEXT      — código de territorio
     job_family              TEXT      — familia de puesto (ej: "technology", "finance")
     job_level               TEXT      — level de puesto (I1-I5 individual / M1-M5 manager / D1-D3 director)
     max_subordinates        INTEGER   — máximo de subordinados directos en el org chart
     required_certifications JSONB[]   — certificaciones requeridas para portar este rol
     reporting_line          TEXT      — rol al que reporta (code del rol superior en el org chart)
   Los keys con null se completan durante el onboarding del tenant.
   caeb_code y nist_rbac_level se derivan automáticamente al crear el rol.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.role_owner_id          IS '[NIST AC-2(7)] Propietario humano del rol — obligatorio para roles privilegiados.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.category_id            IS '[IGA] FK a T-191 — categoría de gobernanza (BUSINESS, PRIVILEGED, SERVICE, etc.).';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.risk_classification    IS '[NIST RA-3] [ISO 27005] Clasificación de riesgo del rol: LOW, MEDIUM, HIGH, CRITICAL.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.sensitivity_label      IS '[ISO 27001 A.5.12] [NIST AC-16] Etiqueta de confidencialidad: PUBLIC → SECRET.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.business_justification IS '[IGA] Justificación de negocio para la existencia del rol (JSONB bilingüe).';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.max_simultaneous_holders IS '[NIST AC-5] [PCI DSS 7.2] Máximo de titulares simultáneos — NULL=sin límite.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.next_review_at         IS '[IGA access review] Fecha del próximo ciclo de certificación de acceso.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.approval_required      IS '[PCI DSS 7.1] true = requiere aprobación formal antes de asignación.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.created_by             IS '[B01 §audit G-B01-07] [ISO 27001 A.8.15] Entidad que creó este rol — FK a idn_identity_entity.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.updated_by             IS '[B01 §audit G-B01-07] [ISO 27001 A.8.15] Última entidad que modificó este rol.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.version_number         IS '[B01 §audit G-B01-06] Contador de UPDATEs — auto-incrementado por trg_irrh_version_bump. Usado por el Motor de Versionado (T-152) para detectar cambios MAJOR/MINOR.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.digital_signature      IS '[B01 §digital_signature G-B01-08] [Ley 164 Bolivia] [EdDSA Ed25519 NIST SP 800-186 §3.2.1] Firma del contrato del rol. El Motor de Firma Dual (MANUAL-FIRMA) la popula al certificar el rol. Estructura: {algorithm, signature, signed_at, signed_by, certificate_id, post_quantum_planned}. NULL hasta que el motor esté operativo.';

-- FK deferida al árbol de políticas: se agrega en sección T-162 (después de crear idn_roles_template)

-- Índice parcial para rol de expiración (reconcile loop / job de vencimiento)
CREATE INDEX IF NOT EXISTS idx_irrh_b02_expiry
    ON bauth.idn_roles_rol_hierarchical (valid_until, status)
    WHERE valid_until IS NOT NULL AND status = 'ACTIVE';

COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.validity_type     IS '[B02 G-B02-01] [NIST AC-2(d)] Tipo de vigencia: INDEFINITE/FIXED/PROJECT_BASED/TEMPORARY/EMERGENCY.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.valid_from        IS '[B02 G-B02-02] [ISO A.5.18 §c] Inicio de vigencia de negocio. Automático al crear (DEFAULT CURRENT_DATE).';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.valid_until       IS '[B02 G-B02-02] Fin de vigencia. FIXED: humano lo fija. TEMPORARY/EMERGENCY: lo calcula trg_irrh_b02_validity. INDEFINITE/PROJECT_BASED: NULL=sin fecha fija.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.duration_interval IS '[B02 G-B02-02] [NIST AC-2(2)] Duración. Solo TEMPORARY/EMERGENCY. Ej: INTERVAL ''30 days'', INTERVAL ''72 hours''. Trigger calcula valid_until = valid_from + duration_interval.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.max_renewals      IS '[B02 G-B02-04] [PCI DSS 7.2.4] Máximo de renovaciones permitidas (anti privilege-creep). NULL=sin límite.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.renewal_count     IS '[B02 G-B02-04] Contador de renovaciones efectuadas. Se compara con max_renewals antes de extender.';

-- P5 — Trigger de vigencia B02: calcula valid_until + detecta auto-expiración
CREATE OR REPLACE FUNCTION bauth.fn_irrh_b02_validity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Paso 1: calcular valid_until según tipo
    IF NEW.validity_type = 'TEMPORARY' AND NEW.duration_interval IS NOT NULL THEN
        NEW.valid_until := NEW.valid_from + NEW.duration_interval;
    ELSIF NEW.validity_type = 'EMERGENCY' THEN
        NEW.valid_until := NEW.created_at + INTERVAL '72 hours';
    END IF;

    -- Paso 2: auto-expiración al escribir si valid_until ya pasó
    IF NEW.validity_type IN ('TEMPORARY','EMERGENCY')
       AND NEW.valid_until IS NOT NULL
       AND NEW.valid_until <= CURRENT_TIMESTAMP
       AND NEW.status = 'ACTIVE' THEN
        NEW.status := 'DEPRECATED';
        INSERT INTO bauth.idn_roles_rol_lifecycle_event
            (role_id, from_status, to_status, trigger_type, reason, ctx_id)
        VALUES (
            NEW.id,
            CASE WHEN TG_OP = 'UPDATE' THEN OLD.status ELSE 'ACTIVE'::rol_status_enum END,
            'DEPRECATED',
            'AUTO_EXPIRY',
            'Vigencia expirada: ' || NEW.validity_type::text || ' valid_until=' || NEW.valid_until::text,
            'system.b02.expiry'
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_irrh_b02_validity ON bauth.idn_roles_rol_hierarchical;
CREATE TRIGGER trg_irrh_b02_validity
    BEFORE INSERT OR UPDATE OF validity_type, valid_from, valid_until, duration_interval, status
    ON bauth.idn_roles_rol_hierarchical
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_irrh_b02_validity();

-- ======================================================================
-- T-B02L — bauth.idn_roles_rol_lifecycle_event  [WORM]
-- Log inmutable de transiciones de estado del rol. Equivalente a T-160 para NHI.
-- ANSI INCITS 359-2004 §4.3 · ISO 27001 A.8.15 · NIST AU-9
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_lifecycle_event (
    id               UUID             NOT NULL DEFAULT uuidv7(),
    role_id          UUID             NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE RESTRICT,
    from_status      rol_status_enum,
    to_status        rol_status_enum  NOT NULL,
    trigger_type     TEXT             NOT NULL,
    actor_id         UUID             REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    reason           TEXT,
    validity_snapshot JSONB,
    ctx_id           TEXT             NOT NULL,
    occurred_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    prev_hash        TEXT,
    entry_hash       TEXT             NOT NULL,
    CONSTRAINT idn_roles_rol_lifecycle_event_pkey PRIMARY KEY (id),
    CONSTRAINT fk_irle_role FOREIGN KEY (role_id) REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE RESTRICT,
    CONSTRAINT chk_irle_trigger CHECK (  -- [MC-0271] → A.65.04
        trigger_type IN ('MANUAL','AUTO_EXPIRY','RECONCILE','IGA_REVIEW','BREAKGLASS','BOOTSTRAP')
    )
);

CREATE INDEX IF NOT EXISTS idx_irle_role    ON bauth.idn_roles_rol_lifecycle_event (role_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_irle_status  ON bauth.idn_roles_rol_lifecycle_event (to_status, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_irle_expiry  ON bauth.idn_roles_rol_lifecycle_event (occurred_at DESC) WHERE trigger_type = 'AUTO_EXPIRY';

REVOKE UPDATE, DELETE ON bauth.idn_roles_rol_lifecycle_event FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.idn_roles_rol_lifecycle_event FROM bauth_app_role;

-- Hash-chain WORM T-B02L (bauth_44)
CREATE OR REPLACE FUNCTION bauth.fn_irle_worm_hash()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_prev_hash TEXT;
BEGIN
    SELECT entry_hash INTO v_prev_hash
    FROM bauth.idn_roles_rol_lifecycle_event
    ORDER BY occurred_at DESC, id DESC
    LIMIT 1;

    NEW.prev_hash  := v_prev_hash;
    NEW.entry_hash := encode(
        sha256(convert_to(
            coalesce(NEW.id::text,          '') ||
            coalesce(NEW.role_id::text,     '') ||
            coalesce(NEW.from_status::text, '') ||
            coalesce(NEW.to_status::text,   '') ||
            coalesce(NEW.trigger_type,      '') ||
            coalesce(NEW.actor_id::text,    '') ||
            coalesce(NEW.ctx_id,            '') ||
            coalesce(NEW.occurred_at::text, '') ||
            coalesce(NEW.prev_hash,         ''),
            'UTF8'
        )),
        'hex'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_irle_worm ON bauth.idn_roles_rol_lifecycle_event;
CREATE TRIGGER trg_irle_worm
    BEFORE INSERT ON bauth.idn_roles_rol_lifecycle_event
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_irle_worm_hash();

-- ======================================================================
-- B02 — Reconcile loop: fn_b02_reconcile_expiry
-- Detecta roles con valid_until <= CURRENT_DATE y los depreca.
-- Cubre el gap entre escrituras cuando el daemon está caído.
-- Llamado por: K8s CronJob bauth-b02-reconcile en sbos-security (cada 5 min)
-- NIST AC-2(2) · ISO 27001 A.5.18 §c
-- ======================================================================
DROP FUNCTION IF EXISTS bauth.fn_b02_reconcile_expiry;
CREATE OR REPLACE FUNCTION bauth.fn_b02_reconcile_expiry(
    p_ctx_id TEXT DEFAULT 'system.b02.reconcile'
)
RETURNS TABLE (
    role_id          UUID,
    previous_status  rol_status_enum,
    expiration_date  DATE,
    processed_at     TIMESTAMPTZ
)
LANGUAGE plpgsql AS $$
DECLARE
    v_row     RECORD;
    v_updated INT;
BEGIN
    FOR v_row IN
        SELECT id,
               status,
               r.valid_until   AS vu,
               validity_type,
               valid_from,
               duration_interval
        FROM bauth.idn_roles_rol_hierarchical r
        WHERE r.valid_until IS NOT NULL
          AND r.valid_until <= CURRENT_DATE
          AND r.status NOT IN ('DEPRECATED', 'ARCHIVED', 'INACTIVE')
        ORDER BY r.valid_until
        FOR UPDATE SKIP LOCKED
    LOOP
        UPDATE bauth.idn_roles_rol_hierarchical
            SET status = 'DEPRECATED'
        WHERE id = v_row.id
          AND status = v_row.status;

        GET DIAGNOSTICS v_updated = ROW_COUNT;

        IF v_updated > 0 THEN
            INSERT INTO bauth.idn_roles_rol_lifecycle_event
                (role_id, from_status, to_status, trigger_type,
                 reason, validity_snapshot, ctx_id)
            VALUES (
                v_row.id,
                v_row.status,
                'DEPRECATED',
                'RECONCILE',
                'Vigencia expirada detectada por reconcile loop. valid_until=' || v_row.vu::text,
                jsonb_build_object(
                    'validity_type',     v_row.validity_type,
                    'valid_from',        v_row.valid_from,
                    'valid_until',       v_row.vu,
                    'duration_interval', v_row.duration_interval,
                    'detected_at',       now()
                ),
                p_ctx_id
            );

            role_id          := v_row.id;
            previous_status  := v_row.status;
            expiration_date  := v_row.vu;
            processed_at     := now();
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION bauth.fn_b02_reconcile_expiry(TEXT) IS
'[B02 §lifecycle] [NIST AC-2(2)] [ISO 27001 A.5.18 §c]
 Reconcile loop: depreca roles con valid_until <= CURRENT_DATE que trg_irrh_b02_validity
 no procesó (daemon caído, roles sin actividad). FOR UPDATE SKIP LOCKED evita
 colisión con inserts concurrentes. Idempotente. Llamado por K8s CronJob.';

COMMENT ON TABLE bauth.idn_roles_rol_lifecycle_event IS
'ROLES | Log append-only (WORM) de todas las transiciones de estado de los roles (7 estados formales:
DEFINIDO→ACTIVO→SUSPENDIDO→DEPRECADO→ARCHIVADO y vías de revisión IGA). Cada fila es inmutable:
registra role_id, from_status, to_status, trigger_type (MANUAL/AUTO_EXPIRY/RECONCILE/IGA_REVIEW/
BREAKGLASS/BOOTSTRAP), actor_id, validity_snapshot y hash-chain SHA-256 (bauth_44).
Fuente: creado por el daemon via trg_irrh_b02_validity (expiración automática) o RPC bauth.role.
transition; también por el reconcile loop fn_b02_reconcile_expiry (daemon caído).
Administración: REVOKE UPDATE, DELETE — solo INSERT permitido. Solo bauth_app_role puede insertar.
Trigger trg_irle_worm calcula prev_hash + entry_hash en cada INSERT para garantizar inmutabilidad.
WORM: sí — REVOKE UPDATE/DELETE aplicado; hash-chain implementado.
Particionada: no (candidata a particionarse por occurred_at si el volumen es alto).
Estándar: ANSI INCITS 359-2004 §4.3, ISO 27001 A.8.15, NIST AU-9, NIST AU-10. T-B02L.';

COMMENT ON COLUMN bauth.idn_roles_rol_lifecycle_event.from_status      IS 'NULL en creación inicial (el rol nace en estado to_status).';
COMMENT ON COLUMN bauth.idn_roles_rol_lifecycle_event.validity_snapshot IS 'JSON de {validity_type, valid_from, valid_until, duration_interval} al momento del evento.';
COMMENT ON COLUMN bauth.idn_roles_rol_lifecycle_event.trigger_type      IS 'MANUAL=operador · AUTO_EXPIRY=trigger · RECONCILE=loop · IGA_REVIEW=campaña · BREAKGLASS=emergencia · BOOTSTRAP=instalación inicial.';


-- ======================================================================
-- T-063 — bauth.idn_roles_rol_closure
-- Closure table para herencia DAG-OR de roles. O(1) consulta de ancestros/descendientes.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_closure (
    ancestor_id   UUID        NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE CASCADE,
    descendant_id UUID        NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE CASCADE,
    depth         INTEGER     NOT NULL CHECK (depth >= 0),
    is_active     BOOLEAN     NOT NULL DEFAULT true,
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_irclo_desc  ON bauth.idn_roles_rol_closure(descendant_id, depth);
CREATE INDEX IF NOT EXISTS idx_irclo_anc   ON bauth.idn_roles_rol_closure(ancestor_id, depth);
CREATE INDEX IF NOT EXISTS idx_irclo_depth ON bauth.idn_roles_rol_closure(depth);

COMMENT ON TABLE bauth.idn_roles_rol_closure IS
'ROLES | Closure table de la jerarquía DAG-OR de roles (patrón Tropashko). Cada fila representa
un par (ancestor, descendant) con la profundidad: depth=0 reflexivo (rol consigo mismo),
depth=1 hijo directo, depth>1 transitivo. Permite evaluar herencia de privilegios en O(1) con
un simple WHERE ancestor_id=rol_id, sin recursión CTE. BitMask se computa con JOIN en < 0.5ns.
Fuente: mantenida automáticamente por triggers en idn_roles_rol_hierarchical al INSERT/UPDATE
parent_id. No se inserta manualmente — es una proyección derivada del árbol principal.
Administración: mantenida solo por el Motor de Roles (triggers) y el reconcile loop. No editar
directamente; los cambios en parent_id de T-041 se propagan por trigger a esta tabla.
WORM: no — se actualiza en cascada cuando cambia la estructura del DAG (ON DELETE CASCADE).
Particionada: no.
Estándar: NIST RBAC N3 §2.3, ANSI INCITS 359-2004. T-063.';

COMMENT ON COLUMN bauth.idn_roles_rol_closure.ancestor_id   IS 'Rol ancestro en la jerarquía.';
COMMENT ON COLUMN bauth.idn_roles_rol_closure.descendant_id IS 'Rol descendiente (hereda del ancestor).';
COMMENT ON COLUMN bauth.idn_roles_rol_closure.depth         IS '0=self, 1=hijo directo, N=N niveles de herencia.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║            NIVEL 4 — VERSIONADO (bauth)                            ║
-- ║   WITH WITHOUT OVERLAPS — Temporal constraints PG18                ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║      MOTOR DE VERSIONADO F2 — bauth.idn_roles_ver_*                ║
-- ║  B01 §audit.change_history[] + B03 §approval_workflow              ║
-- ║  Manual: 1.13_MANUAL-MOTOR-VERSIONADO-v1.0.md §8-§10              ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ENUMs del subsistema ver_
DO $$ BEGIN CREATE TYPE bauth.ver_semver_change_enum   AS ENUM ('MAJOR','MINOR','PATCH');                          EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0004] → A.65.04
DO $$ BEGIN CREATE TYPE bauth.ver_channel_enum          AS ENUM ('API','CLI','BOOTSTRAP','RECONCILE');             EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0001] → A.65.04
DO $$ BEGIN CREATE TYPE bauth.ver_proposal_status_enum  AS ENUM ('PENDING','APPROVED','REJECTED','EXPIRED','CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0003] → A.65.04
DO $$ BEGIN CREATE TYPE bauth.ver_compaction_enum       AS ENUM ('KEEP_ALL','KEEP_ANCHORS','KEEP_LAST_N');        EXCEPTION WHEN duplicate_object THEN NULL; END $$;  -- [MC-0002] → A.65.04

-- ======================================================================
-- T-152 — bauth.idn_roles_ver_b01_audit_log
-- [B01 §audit.change_history[]] WORM de versiones cerradas de T-041.
-- WITHOUT OVERLAPS (PG18 + btree_gist): no-solape garantizado por el motor de BD.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_ver_b01_audit_log (
    id               UUID                         NOT NULL DEFAULT uuidv7(),
    entity_id        UUID                         NOT NULL,
    sys_period       TSTZRANGE                    NOT NULL,
    version_number   INTEGER                      NOT NULL,
    template_version TEXT                         NOT NULL,
    blocks_touched   TEXT[]                       NOT NULL DEFAULT '{}',
    standard_ref     TEXT[]                       NOT NULL DEFAULT '{}',
    fields_changed   JSONB                        NOT NULL DEFAULT '{}',
    snapshot         JSONB,
    is_anchor        BOOLEAN                      NOT NULL DEFAULT false,
    change_type      bauth.ver_semver_change_enum  NOT NULL,
    change_reason    TEXT,
    security_impact  risk_level_enum,
    change_channel   bauth.ver_channel_enum        NOT NULL,
    changed_by       UUID,
    approved_by      UUID,
    approved_at      TIMESTAMPTZ,
    ctx_id           TEXT                          NOT NULL,
    prev_hash        TEXT,
    entry_hash       TEXT                          NOT NULL,
    CONSTRAINT pk_irvb01al           PRIMARY KEY (id),
    CONSTRAINT fk_irvb01al_entity    FOREIGN KEY (entity_id)   REFERENCES bauth.idn_roles_rol_hierarchical(id)     ON DELETE RESTRICT,
    CONSTRAINT fk_irvb01al_changed   FOREIGN KEY (changed_by)  REFERENCES bauth.idn_identity_entity(entity_id)  ON DELETE SET NULL,
    CONSTRAINT fk_irvb01al_approved  FOREIGN KEY (approved_by) REFERENCES bauth.idn_identity_entity(entity_id)  ON DELETE SET NULL,
    CONSTRAINT uq_irvb01al_temporal  UNIQUE (entity_id, sys_period WITHOUT OVERLAPS),
    CONSTRAINT chk_irvb01al_closed   CHECK (NOT upper_inf(sys_period)),
    CONSTRAINT chk_irvb01al_ver      CHECK (version_number >= 0),
    CONSTRAINT chk_irvb01al_mjr_rsn  CHECK (change_type <> 'MAJOR' OR change_reason IS NOT NULL),
    CONSTRAINT chk_irvb01al_mjr_anc  CHECK (change_type <> 'MAJOR' OR is_anchor),
    CONSTRAINT chk_irvb01al_anc_snap CHECK (NOT is_anchor OR snapshot IS NOT NULL),
    CONSTRAINT chk_irvb01al_approval CHECK (approved_by IS NULL OR approved_at IS NOT NULL)
);
REVOKE UPDATE, DELETE ON bauth.idn_roles_ver_b01_audit_log FROM PUBLIC;

-- Hash-chain WORM T-152 (bauth_44)
CREATE OR REPLACE FUNCTION bauth.fn_irvb01al_worm_hash()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_prev_hash TEXT;
BEGIN
    SELECT entry_hash INTO v_prev_hash
    FROM bauth.idn_roles_ver_b01_audit_log
    ORDER BY upper(sys_period) DESC NULLS LAST, id DESC
    LIMIT 1;

    NEW.prev_hash  := v_prev_hash;
    NEW.entry_hash := encode(
        sha256(convert_to(
            coalesce(NEW.id::text,         '') ||
            coalesce(NEW.entity_id::text,  '') ||
            coalesce(NEW.sys_period::text, '') ||
            coalesce(NEW.snapshot::text,   '') ||
            coalesce(array_to_string(NEW.blocks_touched, ','), '') ||
            coalesce(NEW.change_type::text,'') ||
            coalesce(NEW.ctx_id,           '') ||
            coalesce(NEW.prev_hash,        ''),
            'UTF8'
        )),
        'hex'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_irvb01al_worm ON bauth.idn_roles_ver_b01_audit_log;
CREATE TRIGGER trg_irvb01al_worm
    BEFORE INSERT ON bauth.idn_roles_ver_b01_audit_log
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_irvb01al_worm_hash();

CREATE INDEX IF NOT EXISTS idx_irvb01al_entity  ON bauth.idn_roles_ver_b01_audit_log (entity_id);
CREATE INDEX IF NOT EXISTS idx_irvb01al_period  ON bauth.idn_roles_ver_b01_audit_log USING gist (sys_period);
CREATE INDEX IF NOT EXISTS idx_irvb01al_blocks  ON bauth.idn_roles_ver_b01_audit_log USING gin  (blocks_touched);
CREATE INDEX IF NOT EXISTS idx_irvb01al_norms   ON bauth.idn_roles_ver_b01_audit_log USING gin  (standard_ref);
CREATE INDEX IF NOT EXISTS idx_irvb01al_channel ON bauth.idn_roles_ver_b01_audit_log (change_channel);
COMMENT ON TABLE bauth.idn_roles_ver_b01_audit_log IS
'VERSIONADO | Historial WORM de versiones cerradas de idn_roles_rol_hierarchical (T-041). Cada fila
es un snapshot inmutable del estado del rol al cierre de un período temporal (sys_period TSTZRANGE
WITHOUT OVERLAPS). Permite consultas as-of ("¿cómo era este rol el 2026-03-01?"). MAJOR: ancla
con snapshot completo + change_reason obligatorio + aprobación dual. MINOR: solo fields_changed.
Fuente: creado por el Motor de Versionado (T-152) al cerrar una versión en T-041; nunca por INSERT
directo. El trigger trg_irvb01al_worm calcula hash-chain SHA-256 en cada inserción.
Administración: REVOKE UPDATE/DELETE — solo INSERT. Solo bauth_app_role puede insertar.
Hash-chain impide alteración retroactiva; la columna approved_by es FOR UPDATE SKIP LOCKED.
WORM: sí — REVOKE UPDATE/DELETE aplicado; hash-chain SHA-256 sobre cada entrada.
Particionada: candidata por upper(sys_period) si el volumen histórico supera 10M filas.
Estándar: ISO 27001 A.5.33, NIST AU-9, NIST AU-11, PCI DSS Req 10.5, SOX-404. T-152.';

-- ======================================================================
-- T-153 — bauth.idn_roles_ver_b03_approval_queue
-- [B03 §approval_workflow] Cola de cambios MAJOR pendientes de quórum N-de-M.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_ver_b03_approval_queue (
    id                  UUID                            NOT NULL DEFAULT uuidv7(),
    entity_id           UUID                            NOT NULL,
    proposed_state      JSONB                           NOT NULL,
    blocks_touched      TEXT[]                          NOT NULL,
    standard_ref        TEXT[]                          NOT NULL DEFAULT '{}',
    change_type         bauth.ver_semver_change_enum    NOT NULL DEFAULT 'MAJOR',
    change_reason       TEXT                            NOT NULL,
    security_impact     risk_level_enum                 NOT NULL,
    proposed_by         UUID                            NOT NULL,
    required_approvers  INTEGER                         NOT NULL,
    approver_roles      TEXT[]                          NOT NULL,
    approvals           JSONB                           NOT NULL DEFAULT '[]',
    sla_deadline        TIMESTAMPTZ                     NOT NULL,
    escalated           BOOLEAN                         NOT NULL DEFAULT false,
    status              bauth.ver_proposal_status_enum  NOT NULL DEFAULT 'PENDING',
    resolved_by         UUID,
    resolved_at         TIMESTAMPTZ,
    resolution_note     TEXT,
    ctx_id              TEXT                            NOT NULL,
    created_at          TIMESTAMPTZ                     NOT NULL DEFAULT now(),
    CONSTRAINT pk_irvb03aq             PRIMARY KEY (id),
    CONSTRAINT fk_irvb03aq_entity      FOREIGN KEY (entity_id)    REFERENCES bauth.idn_roles_rol_hierarchical(id)    ON DELETE RESTRICT,
    CONSTRAINT fk_irvb03aq_proposed_by FOREIGN KEY (proposed_by)  REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    CONSTRAINT fk_irvb03aq_resolved_by FOREIGN KEY (resolved_by)  REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    CONSTRAINT chk_irvb03aq_only_major CHECK (change_type = 'MAJOR'),
    -- Control dual AC-5: solo APPROVED/REJECTED requieren resolver ≠ proposer
    CONSTRAINT chk_irvb03aq_dual_ctrl  CHECK (
        (status IN ('PENDING','CANCELLED','EXPIRED'))
        OR (resolved_by IS NULL)
        OR (resolved_by <> proposed_by)
    ),
    CONSTRAINT chk_irvb03aq_quorum     CHECK (required_approvers >= 1 AND required_approvers <= cardinality(approver_roles)),
    -- PENDING: sin resolución · CANCELLED/EXPIRED: sistema (sin resolver_by) · APPROVED/REJECTED: control dual
    CONSTRAINT chk_irvb03aq_resolved   CHECK (
        (status = 'PENDING'                    AND resolved_by IS NULL     AND resolved_at IS NULL) OR
        (status IN ('CANCELLED','EXPIRED')     AND resolved_by IS NULL     AND resolved_at IS NOT NULL) OR
        (status IN ('APPROVED','REJECTED')     AND resolved_by IS NOT NULL AND resolved_at IS NOT NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_irvb03aq_entity   ON bauth.idn_roles_ver_b03_approval_queue (entity_id);
CREATE INDEX IF NOT EXISTS idx_irvb03aq_pending  ON bauth.idn_roles_ver_b03_approval_queue (status) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_irvb03aq_deadline ON bauth.idn_roles_ver_b03_approval_queue (sla_deadline) WHERE status = 'PENDING';
COMMENT ON TABLE bauth.idn_roles_ver_b03_approval_queue IS
'VERSIONADO | Cola de aprobación de cambios MAJOR en roles (B03 §approval_workflow). Cada fila
es una propuesta de cambio de tier, plantilla o política de un rol que requiere quórum N-de-M
(NIST CM-3, NIST AC-5 dual control): required_approvers aprobadores de los roles en approver_roles
deben firmar dentro de sla_deadline o la propuesta expira. proposed_state: snapshot JSONB del
estado propuesto. approvals: array JSONB de firmas acumuladas.
Fuente: creada por el Motor de Versionado al detectar un cambio MAJOR; nunca manual.
Administración: proposed_by ≠ resolved_by (control dual garantizado por chk_irvb03aq_dual_ctrl).
El daemon bAuth evalúa el quórum en cada aprobación; al alcanzarlo aplica el cambio en T-041.
WORM: no — el estado cambia (PENDING→APPROVED/REJECTED/EXPIRED); los votos se acumulan en approvals.
Particionada: no.
Estándar: NIST AC-5, NIST CM-3 (Change Control Board), ISO 27001 A.5.18, PCI DSS 6.4.2. T-153.';

-- ======================================================================
-- T-154 — bauth.idn_roles_ver_b01_retention_policy
-- [B01 §audit gobernanza] Política de retención legal por entidad C1.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_ver_b01_retention_policy (
    id                UUID                        NOT NULL DEFAULT uuidv7(),
    entity_name       TEXT                        NOT NULL,
    info_class        TEXT                        NOT NULL,
    hot_window        INTERVAL                    NOT NULL DEFAULT INTERVAL '2 years',
    compaction_policy bauth.ver_compaction_enum   NOT NULL DEFAULT 'KEEP_ANCHORS',
    retention_total   INTERVAL                    NOT NULL,
    legal_basis       TEXT                        NOT NULL,
    standard_ref      TEXT[]                      NOT NULL,
    legal_hold        BOOLEAN                     NOT NULL DEFAULT false,
    ctx_id            TEXT                        NOT NULL,
    created_at        TIMESTAMPTZ                 NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ                 NOT NULL DEFAULT now(),
    CONSTRAINT pk_irvb01rp           PRIMARY KEY (id),
    CONSTRAINT uq_irvb01rp_entity    UNIQUE (entity_name),
    CONSTRAINT chk_irvb01rp_class    CHECK (info_class IN ('C1','C2','C3','C4')),  -- [MC-0273] → A.65.04
    CONSTRAINT chk_irvb01rp_piso_d99 CHECK (retention_total >= INTERVAL '365 days')
);
COMMENT ON TABLE bauth.idn_roles_ver_b01_retention_policy IS
'VERSIONADO | Tabla de políticas de retención legal del historial de versiones (T-152) por entidad.
Define: ventana caliente (hot_window), política de compactación (KEEP_ALL/KEEP_ANCHORS/KEEP_LAST_N),
retención total (retention_total), y base legal (legal_basis). Piso mínimo D99 = 365 días.
legal_hold=true suspende toda purga automática mientras dure la medida cautelar.
Fuente: seed de despliegue con política para idn_roles_rol_hierarchical (C1, 10 años, Ley 843 Art.44);
altas para nuevas entidades vía migración DDL con HITL.
Administración: el reconcile loop de retención lee esta tabla para decidir qué filas de T-152 purgar;
solo SUPER_ADMIN puede actualizar retention_total o activar legal_hold.
WORM: no — legal_hold y hot_window son ajustables operacionalmente.
Particionada: no.
Seed: DDLs/seeds/bauth_T154__idn_roles_ver_b01_retention_policy.sql — idempotente ON CONFLICT.
Estándar: ISO 27001 A.5.33, NIST AU-11, PCI DSS Req 10.5, SOX-404, Ley 843 Bolivia Art.44. T-154.';

-- ======================================================================
-- T-155 — bauth.idn_roles_ver_contract_revision_log
-- [Plano A] Changelog estructural del contrato RolTemplate entre versiones.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_ver_contract_revision_log (
    id                UUID        NOT NULL DEFAULT uuidv7(),
    contract_name     TEXT        NOT NULL,
    version_from      TEXT        NOT NULL,
    version_to        TEXT        NOT NULL,
    blocks_changed    TEXT[]      NOT NULL DEFAULT '{}',
    fields_added      TEXT[]      NOT NULL DEFAULT '{}',
    fields_removed    TEXT[]      NOT NULL DEFAULT '{}',
    fields_modified   JSONB       NOT NULL DEFAULT '{}',
    standards_affected TEXT[]     NOT NULL DEFAULT '{}',
    compatibility     TEXT        NOT NULL,
    migration_ref     TEXT,
    change_reason     TEXT        NOT NULL,
    approved_by       UUID        NOT NULL,
    ctx_id            TEXT        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_irvcrl            PRIMARY KEY (id),
    CONSTRAINT fk_irvcrl_approved   FOREIGN KEY (approved_by) REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    CONSTRAINT uq_irvcrl_transition UNIQUE (contract_name, version_from, version_to),
    CONSTRAINT chk_irvcrl_compat    CHECK (compatibility IN ('COMPATIBLE','BREAKING')),  -- [MC-0274] → A.65.04
    CONSTRAINT chk_irvcrl_diff_ver  CHECK (version_to <> version_from)
);
CREATE INDEX IF NOT EXISTS idx_irvcrl_contract ON bauth.idn_roles_ver_contract_revision_log (contract_name);
CREATE INDEX IF NOT EXISTS idx_irvcrl_compat   ON bauth.idn_roles_ver_contract_revision_log (compatibility);
COMMENT ON TABLE bauth.idn_roles_ver_contract_revision_log IS
'VERSIONADO | Changelog estructural del contrato RolTemplate entre versiones. Registra cada
transición (version_from → version_to) del contrato de bloques B01-B14, indicando bloques
modificados, campos añadidos/eliminados/cambiados y compatibilidad BREAKING/COMPATIBLE.
migration_ref apunta al script de migración aplicado. No almacena instancias de roles — solo el
diff del contrato estructural. Es el ADR técnico de cada cambio de esquema del RolTemplate.
Fuente: creada por HITL al aprobar un cambio de contrato; aprobación formal por approved_by.
Administración: solo SUPER_ADMIN + arquitecto de dominio pueden insertar entradas; la restricción
UNIQUE (contract_name, version_from, version_to) impide duplicados. Solo INSERT permitido
operacionalmente (el changelog es una bitácora, no un estado editable).
WORM: no formalmente (sin REVOKE), pero solo se insertan — nunca se modifica una entrada pasada.
Particionada: no.
Estándar: ISO 27001 A.5.33, NIST CM-3, NIST CM-9. T-155.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║           NIVEL 5 — ÁRBOL DE POLÍTICAS (bauth)                     ║
-- ║   T-162 idn_roles_template + T-163 + T-174 + T-175                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-174 — bauth.privilege_verb
-- Catálogo de verbos válidos. LISTA DE VALIDACIÓN — no participa en BitMask ni PDP.
-- PK = verb_id TEXT snake_case. Catálogo global (sin tenant_id — G-06 §Por qué no).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_verb (
    verb_id     TEXT        NOT NULL,
    description TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  TEXT        NOT NULL,
    CONSTRAINT privilege_verb_pkey   PRIMARY KEY (verb_id),
    -- snake_case obligatorio: letras minúsculas, números, guion bajo
    CONSTRAINT chk_pv_verb_id_format CHECK (verb_id ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE bauth.privilege_verb IS
'PRIVILEGIOS | Catálogo de verbos atómicos del sistema. LISTA DE VALIDACIÓN ÚNICAMENTE — no
participa en la construcción del RolBitMask ni en la evaluación PDP en runtime. Solo es
consultada al crear/modificar nodos en idn_roles_template (FK verb_id) y en la matriz SoD T-175.
18 verbos canónicos: create, read, update, delete, validate, approve, execute, export, archive,
assign, delegate, certify, sign, audit, report, config, manage, reassess. PK TEXT snake_case.
Fuente: seed de despliegue con los 18 verbos canónicos; altas nuevas vía migración DDL con HITL.
Administración: catálogo global sin tenant_id (G-06 §Por qué no). Los verbos nunca se eliminan:
is_active=false los desactiva preservando trazabilidad histórica de FKs en idn_roles_template.
Nuevos verbos requieren análisis de impacto en la matriz SoD (T-175) antes de ser registrados.
WORM: no — is_active puede actualizarse; verbos se desactivan, no se borran.
Particionada: no.
Seed: DDLs/seeds/bauth_T174__privilege_verb.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-53 AC-5, XACML 3.0 §4.3, ISO 27001 A.6.1.2, OWASP ASVS 6.1. T-174.';

COMMENT ON COLUMN bauth.privilege_verb.verb_id     IS 'PK texto snake_case: [a-z][a-z0-9_]*. Ej: create, approve, sign_document.';
COMMENT ON COLUMN bauth.privilege_verb.is_active    IS 'Los verbos nunca se eliminan — se desactivan (activo=false) para trazabilidad histórica.';


-- ======================================================================
-- T-175 — bauth.privilege_verb_conflict
-- Matriz SoD entre verbos. PK compuesta (verb_a, verb_b) en orden alfabético.
-- LISTA DE VALIDACIÓN — consultada por trigger fn_check_sod_on_grant en T-170.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_verb_conflict (
    verb_a      TEXT        NOT NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE CASCADE,
    verb_b      TEXT        NOT NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE CASCADE,
    conflict_type TEXT       NOT NULL,
    description TEXT        NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  TEXT        NOT NULL,
    CONSTRAINT privilege_verb_conflict_pkey  PRIMARY KEY (verb_a, verb_b),
    -- Un verbo no puede conflictuar consigo mismo
    CONSTRAINT chk_pvc_no_self_conflict      CHECK (verb_a <> verb_b),
    -- Almacenar siempre en orden alfabético: elimina duplicados (A,B) y (B,A)
    CONSTRAINT chk_pvc_alphabetic_order      CHECK (verb_a < verb_b),
    CONSTRAINT chk_pvc_conflict_type         CHECK (conflict_type IN ('STATIC_SOD','DYNAMIC_SOD','AFFINITY'))  -- [MC-0242] → A.65.04
);

CREATE INDEX IF NOT EXISTS idx_pvc_verba ON bauth.privilege_verb_conflict(verb_a);
CREATE INDEX IF NOT EXISTS idx_pvc_verbb ON bauth.privilege_verb_conflict(verb_b);
CREATE INDEX IF NOT EXISTS idx_pvc_conflict_type ON bauth.privilege_verb_conflict(conflict_type);

COMMENT ON TABLE bauth.privilege_verb_conflict IS
'PRIVILEGIOS | Matriz de conflictos SoD (Separation of Duties) entre verbos atómicos.
LISTA DE VALIDACIÓN ÚNICAMENTE — no participa en BitMask ni en PDP en runtime. Su único
rol en tiempo de ejecución: responder "¿pueden coexistir estos dos verbos para el mismo usuario?"
cuando se intenta asignar un átomo. Tres tipos: STATIC_SOD (siempre prohibido, ej: create+approve),
DYNAMIC_SOD (prohibido solo sobre el mismo objeto/instancia), AFINIDAD (sugerencia, no rechazo).
PK (verb_a, verb_b) con verb_a < verb_b alfabéticamente: cada par se almacena una sola vez.
Fuente: seed de despliegue con los conflictos SoD canónicos (create+approve, sign+approve, etc.);
altas nuevas requieren análisis de impacto y migración DDL con HITL.
Administración: consultada por el trigger fn_check_sod_on_grant en T-170 (privilege_atom_grant).
Solo INSERT/DELETE vía migración; si un verbo en verb_a/verb_b es desactivado en T-174, el
conflicto queda huérfano (ON DELETE CASCADE — la FK lo elimina automáticamente).
WORM: no — pares pueden eliminarse si se retira un verbo de T-174.
Particionada: no.
Seed: DDLs/seeds/bauth_T175__privilege_verb_conflict.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-53 AC-5, ISO 27001 A.6.1.2, NIST SP 800-53 AC-6(7). T-175.';

COMMENT ON COLUMN bauth.privilege_verb_conflict.conflict_type IS '[TEXT] STATIC_SOD | DYNAMIC_SOD | AFINIDAD.';

-- ======================================================================
-- SEEDS — bauth.privilege_verb (T-174) + bauth.privilege_verb_conflict (T-175)
-- Catálogo canónico de 50 verbos de negocio + matriz de conflictos SoD.
-- Fuente: 1.02_MANUAL-VERBOS-v1.0.md · GAPS-DDL-PRIVILEGIOS.md G-03
-- Idempotente: ON CONFLICT DO NOTHING
-- ======================================================================

-- ── T-174: Verbos canónicos ────────────────────────────────────────────────────

-- ── T-175: Matriz de conflictos SoD — verb_a < verb_b (orden alfabético) ─────
-- Fuente: NIST SP 800-53 AC-5 · ISO 27001 A.6.1.2 · GAPS-DDL-PRIVILEGIOS.md G-03

-- ======================================================================
-- T-161b — bauth.idn_policy_node_type
-- Catálogo de tipos de nodo del árbol de políticas idn_roles_template.
-- Fuente única de verdad para badge/abbreviation, nombres y descripciones
-- bilingüe. FK canónica que reemplaza el CHECK chk_irt_tipo.
-- diagnostico: solo existe en Dart (inyectado por el linter), NUNCA en BD.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_policy_node_type (
    code             TEXT        PRIMARY KEY,
    abbreviation        TEXT        NOT NULL,
    name_es          TEXT        NOT NULL,
    name_en          TEXT        NOT NULL,
    description_es     TEXT        NOT NULL,
    description_en     TEXT        NOT NULL,
    -- ── Presentación visual (consumida por el cliente Flutter) ───────────────
    -- color_key: slot de paleta del badge y acento. Valores: primary | foreground |
    --   muted | amber | teal | violet | red | green | destructive
    color_key          TEXT        NOT NULL DEFAULT 'muted',
    -- color_key_valor: slot para el texto del campo 'valor' del nodo.
    -- Puede diferir del badge (ej. atomo: badge=teal, valor=teal; regla: badge=amber, valor=muted).
    color_key_valor    TEXT        NOT NULL DEFAULT 'muted',
    -- font_weight: peso tipográfico (400=normal, 500=medium, 600=semibold, 700=bold).
    font_weight        INTEGER     NOT NULL DEFAULT 600
                       CHECK (font_weight IN (400, 500, 600, 700)),
    -- font_size_token: token de tamaño relativo. El cliente resuelve: xs=10, sm=11, base=11.5, md=12.
    font_size_token    TEXT        NOT NULL DEFAULT 'base'
                       CHECK (font_size_token IN ('xs','sm','base','md')),
    -- monospace: usar fuente monoespaciada para la clave del nodo.
    monospace          BOOLEAN     NOT NULL DEFAULT FALSE,
    -- letter_spacing: multiplicador de letter-spacing (0 = sin espaciado adicional).
    letter_spacing    NUMERIC(4,2) NOT NULL DEFAULT 0,
    -- show_badge: si el nodo muestra su badge de tipo en el árbol.
    show_badge      BOOLEAN     NOT NULL DEFAULT TRUE,
    -- expanded_default: si el nodo se expande automáticamente al cargar el árbol.
    expanded_default  BOOLEAN     NOT NULL DEFAULT FALSE,
    -- ─────────────────────────────────────────────────────────────────────────
    is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
    sort_order         INTEGER     NOT NULL DEFAULT 0
);

COMMENT ON TABLE bauth.idn_policy_node_type IS
'ÁRBOL DE POLÍTICAS | Catálogo de tipos de nodo del árbol de políticas (FK canónica para
idn_roles_template.node_type). Define para cada tipo: badge, abreviatura, nombre/descripción
bilingüe, paleta de color, tipografía y comportamiento visual — el cliente Flutter renderiza
el árbol sin hardcoding consultando este catálogo. Reemplaza el CHECK chk_irt_tipo.
El tipo "diagnostico" es virtual (inyectado solo por el linter Dart) — NUNCA persiste en BD.
Fuente: seed de despliegue con los 12 tipos canónicos (tenant, domain, block, object, list,
set_politicas, policy, rule, atom, attribute, enum, event); altas nuevas vía migración DDL.
Administración: ON CONFLICT DO UPDATE — los campos de presentación (color, fuente, badge)
son actualizables sin migración destructiva; code y abbreviation son estables (son FK vivas).
WORM: no — parámetros de presentación se actualizan vía ON CONFLICT DO UPDATE.
Particionada: no.
Seed: DDLs/seeds/bauth_T161b__idn_policy_node_type.sql — idempotente ON CONFLICT.
Estándar: XACML 3.0 §4.3, NIST RBAC N3. T-161b.';

-- Seed: tipos canónicos del árbol de políticas bAuth
-- Columnas de presentación (color_key, color_key_valor, font_weight, font_size_token,
--   monospace, letter_spacing, show_badge, expanded_default) permiten que el
--   cliente Flutter renderice el árbol SIN hardcoding — todo viene de esta tabla.
-- Paleta de color_key: primary | foreground | muted | amber | teal | violet | red | green

-- T-162 — bauth.idn_roles_template
-- Árbol de políticas PER-TENANT (G-06). Cada tenant tiene su propio árbol.
-- Tipos de nodo (FK a idn_policy_node_type): tenant|dominio|bloque|objeto|lista|
--   set_politicas|politica|regla|atomo|atributo|enum|evento.
-- diagnostico = solo Dart (linter), NUNCA persiste en BD (G-11).
-- atom_position: asignado por trigger desde roles_atom_position_sequential
--   SOLO para nodos tipo='atom'. Inmutable una vez asignado.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_template (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- tenant_id NOT NULL (G-06 §"árbol per-tenant"): cada empresa tiene su árbol propio.
    -- Bootstrap: se copia la estructura del tenant-plantilla (tipos ≠ evaluacion).
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id      UUID        REFERENCES bauth.idn_roles_template(id) ON DELETE RESTRICT,
    -- tipo: FK a idn_policy_node_type (catálogo T-161b). Reemplaza el CHECK chk_irt_tipo.
    node_type      TEXT        NOT NULL REFERENCES bauth.idn_policy_node_type(code) ON UPDATE CASCADE,
    -- clave: nombre de visualización i18n {"es": "Nombre", "en": "Name"}
    label          JSONB       NOT NULL,
    -- name: descripción técnica i18n {"es": "Descripción", "en": "Description"}
    name           JSONB       NOT NULL,
    value          TEXT        NULL,
    -- help: ayuda técnica bilingüe {"es": "Ayuda ES...", "en": "English help..."}
    help           JSONB       NULL,
    options        TEXT[]      NOT NULL DEFAULT '{}',
    description    TEXT,
    -- verb_id: FK textual a privilege_verb (catálogo global G-03). Solo para tipo='atom'.
    verb_id        TEXT        NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE RESTRICT,
    atom_position  BIGINT      UNIQUE,
    -- effect: boolean (true=PERMIT, false=DENY). Sincronizado a T-170 por trigger (G-12 CAMBIO 8).
    effect         BOOLEAN     NOT NULL DEFAULT false,
    condition_expr JSONB,
    domain_number  INTEGER,
    depth          INTEGER     NOT NULL DEFAULT 0,
    order_idx      INTEGER     NOT NULL DEFAULT 0,
    -- sort_order: orden de presentación entre hermanos (10, 20, 30... por posición en el dominio)
    sort_order     INTEGER     NOT NULL DEFAULT 0,
    -- alias: slug técnico para AtomLang (ej: authorization, business_zone) — distinto de clave (UI)
    alias          TEXT        NULL,
    -- block_code: código canónico del bloque dentro del dominio (B01-B10, derivado de sort_order/10)
    block_code     VARCHAR(10) NULL,
    path           TEXT        UNIQUE NOT NULL,
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    version        TEXT        NOT NULL DEFAULT '1.0',
    valid_from     DATE        NOT NULL DEFAULT CURRENT_DATE,
    valid_until    DATE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- verb_id obligatorio SOLO para atomo (G-03 · G-11 §4)
    CONSTRAINT chk_irt_verb_solo_atomo CHECK (
        (node_type = 'atom' AND verb_id IS NOT NULL)
        OR (node_type <> 'atom' AND verb_id IS NULL)
    ),
    -- domain_number obligatorio SOLO para dominio
    CONSTRAINT chk_irt_domain_number CHECK (
        (node_type = 'domain' AND domain_number IS NOT NULL)
        OR (node_type <> 'domain')
    ),
    -- valid_until posterior a valid_from
    CONSTRAINT chk_irt_valid_range CHECK (
        valid_until IS NULL OR valid_until > valid_from
    ),
    -- atom_position SOLO para atomo — asignado por trigger (G-11 §4)
    CONSTRAINT chk_irt_atom_pos_solo_atomo CHECK (
        (node_type = 'atom' AND atom_position IS NOT NULL)
        OR (node_type <> 'atom' AND atom_position IS NULL)
    ),
    -- Unicidad per-tenant (G-06): (tenant_id, parent_id, clave->>'es')
    -- Nota: índice de expresión fuera de la tabla (clave es JSONB, no comparable en UNIQUE directo)
    -- Unicidad compuesta para soportar FK compuesta desde T-170/T-173 (G-12 · A.65.02.01 §6.6)
    CONSTRAINT uq_irt_id_atom_position UNIQUE (id, atom_position)
);

CREATE INDEX IF NOT EXISTS idx_irt_tenant    ON bauth.idn_roles_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_irt_parent    ON bauth.idn_roles_template(parent_id);
CREATE INDEX IF NOT EXISTS idx_irt_node_type ON bauth.idn_roles_template(node_type, is_active);
CREATE INDEX IF NOT EXISTS idx_irt_path      ON bauth.idn_roles_template(path);
CREATE INDEX IF NOT EXISTS idx_irt_atom_pos  ON bauth.idn_roles_template(atom_position) WHERE atom_position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_domain    ON bauth.idn_roles_template(domain_number) WHERE domain_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_verb      ON bauth.idn_roles_template(verb_id) WHERE verb_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_is_active  ON bauth.idn_roles_template(is_active, node_type);
CREATE INDEX IF NOT EXISTS idx_irt_sort       ON bauth.idn_roles_template(parent_id, sort_order);
-- Unicidad per-tenant sobre clave->>'es' (clave es JSONB i18n)
CREATE UNIQUE INDEX IF NOT EXISTS uq_irt_tenant_parent_label
    ON bauth.idn_roles_template(tenant_id, parent_id, (label->>'es'));
CREATE INDEX IF NOT EXISTS idx_irt_alias      ON bauth.idn_roles_template(alias) WHERE alias IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_block_code ON bauth.idn_roles_template(block_code) WHERE block_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_name       ON bauth.idn_roles_template USING GIN (name jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_irt_cond       ON bauth.idn_roles_template USING GIN (condition_expr jsonb_path_ops) WHERE condition_expr IS NOT NULL;

-- FK deferida: idn_roles_rol_hierarchical.template_id → idn_roles_template.id
-- Se declara aquí porque idn_roles_template se crea en este punto (T-162 precede a T-041 en el DDL)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_irrh_template' AND conrelid = 'bauth.idn_roles_rol_hierarchical'::regclass) THEN
        ALTER TABLE bauth.idn_roles_rol_hierarchical
            ADD CONSTRAINT fk_irrh_template
            FOREIGN KEY (template_id)
            REFERENCES bauth.idn_roles_template(id)
            ON DELETE SET NULL
            DEFERRABLE INITIALLY DEFERRED;
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE bauth.idn_roles_template IS
'ÁRBOL DE POLÍTICAS | Árbol de políticas PER-TENANT (G-06): cada tenant tiene su propio árbol
con la estructura domain > block > object/list > policy > rule > atom. Nodo atom = un permiso
atómico con atom_position (bit en el BitMask), verb_id y effect (PERMIT/DENY).
Bootstrap: al crear un tenant se copia la estructura del tenant-plantilla (todos los tipos
EXCEPTO atom — las zonas de negocio llegan vacías y la empresa define sus propios átomos).
atom_position: BIGINT único asignado por trigger trg_irt_atom_position desde la secuencia
roles_atom_position_sequential. Solo para node_type=atom. INMUTABLE una vez asignado.
effect se sincroniza automáticamente a privilege_atom_grant por trg_t162_sync_effect_to_grants.
condition_expr: JSON AST compilado por AtomLang — evaluado por el Motor de Identidad (PDP).
Fuente: bootstrap por IAM Installer desde el árbol plantilla del tenant; átomos nuevos vía
RPC bauth.policy.atom.create con aprobación dual si el árbol ya tiene grants activos.
Administración: el Motor de Políticas (Rust) es el único escritor; el cliente Flutter y
biedata son lectores. Cambios en path/node_type de átomos activos requieren revisión de impacto
en BitMask (atom_position inmutable). Historial de cambios en T-163 (WORM).
WORM: no — el árbol es mutable; el historial inmutable vive en T-163.
Particionada: no.
Seed: DDLs/seeds/bauth_T162__idn_roles_template.sql — idempotente ON CONFLICT.
Estándar: XACML 3.0, NIST RBAC N3, ISO 27001 A.5.15, OWASP ASVS 6.1. T-162.';

COMMENT ON COLUMN bauth.idn_roles_template.tenant_id     IS '[G-06] FK a idn_tenant. El árbol es per-tenant — cada empresa tiene el suyo.';
COMMENT ON COLUMN bauth.idn_roles_template.node_type     IS '[FK→idn_policy_node_type] Tipos: tenant|dominio|bloque|objeto|lista|set_politicas|politica|regla|atomo|atributo|enum|evento (G-11). diagnostico solo en Dart.';
COMMENT ON COLUMN bauth.idn_roles_template.label         IS 'Identificador del nodo dentro de su padre. Parte de la UNIQUE (tenant_id, parent_id, clave).';
COMMENT ON COLUMN bauth.idn_roles_template.atom_position IS 'Posición de bit en BitMask del dominio. BIGINT único, asignado por trigger. SOLO para tipo=atomo. Inmutable.';
COMMENT ON COLUMN bauth.idn_roles_template.effect        IS '[G-12] boolean: true=PERMIT, false=DENY. Sincronizado a privilege_atom_grant por trigger.';
COMMENT ON COLUMN bauth.idn_roles_template.path          IS 'Camino materializado: D01.B1.P001.E001. UNIQUE. Base de lookup eficiente.';
COMMENT ON COLUMN bauth.idn_roles_template.condition_expr IS '[AtomLang] JSON AST de la condición compilada: {"op":"AND","left":{...},"right":{...}}.';
COMMENT ON COLUMN bauth.idn_roles_template.domain_number IS 'Número del dominio para nodos tipo=dominio: D01=1, D12=12, D13=13 (biedata), ...D37.';
COMMENT ON COLUMN bauth.idn_roles_template.verb_id       IS '[G-03] FK textual a privilege_verb. Solo nodos tipo=atomo tienen verb_id. Global (sin tenant_id).';

-- Trigger: asignar atom_position desde secuencia SOLO a nodos tipo='atom'
CREATE OR REPLACE FUNCTION bauth.fn_irt_assign_atom_position()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.node_type = 'atom' AND NEW.atom_position IS NULL THEN
        NEW.atom_position := nextval('bauth.roles_atom_position_sequential');
    ELSIF NEW.node_type <> 'atom' AND NEW.atom_position IS NOT NULL THEN
        RAISE EXCEPTION '[T-162] atom_position solo válida para nodos node_type=atom. node_type=%', NEW.node_type;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_irt_atom_position
    BEFORE INSERT ON bauth.idn_roles_template
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_irt_assign_atom_position();

COMMENT ON FUNCTION bauth.fn_irt_assign_atom_position() IS
  '[A.65.02 T-162] Asigna atom_position desde roles_atom_position_sequential para tipo=atomo.
   Inmutable: atom_position no puede cambiarse una vez asignado (posición de bit estable — NIST RBAC N3).
   Nodos no-atomo rechazan atom_position explícito.';

-- Trigger G-12 CAMBIO 8: sincronizar effect de T-162 → T-170 (privilege_atom_grant)
-- Cuando el árbol cambia el effect de un nodo atomo, todos los grants activos
-- de ese átomo actualizan automáticamente su columna effect (espejo).
CREATE OR REPLACE FUNCTION bauth.fn_sync_effect_from_tree()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.effect IS DISTINCT FROM NEW.effect AND NEW.node_type = 'atom' THEN
        UPDATE bauth.privilege_atom_grant
           SET effect = NEW.effect
         WHERE id_atom = NEW.id
           AND status IN ('ACTIVE', 'SUSPENDED');
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_sync_effect_from_tree() IS
  '[G-12 CAMBIO 8] Sincroniza effect de idn_roles_template → privilege_atom_grant.
   Mantiene effect en T-170 sincronizado sin JOIN adicional en el PDP.
   Solo actúa sobre grants ACTIVE/SUSPENDED del átomo modificado.';

CREATE OR REPLACE TRIGGER trg_t162_sync_effect_to_grants
    AFTER UPDATE ON bauth.idn_roles_template
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_sync_effect_from_tree();


-- ======================================================================
-- T-163 — bauth.idn_roles_template_history  [WORM]
-- Registro inmutable de cambios al árbol de políticas T-162.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_template_history (
    audit_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    node_id         UUID        NOT NULL,
    operation       TEXT        NOT NULL CHECK (operation IN ('INSERT','UPDATE','DEACTIVATE')),
    -- Convención WORM: before_row/after_row (no old_data/new_data)
    before_row      JSONB,
    after_row       JSONB,
    changed_by      UUID        NOT NULL,
    change_reason   TEXT        NOT NULL,
    -- Hash SHA-256 en binario (pgcrypto digest()) — no TEXT (patrón WORM uniforme)
    prev_hash       BYTEA       NULL,
    hash_chain      BYTEA       NOT NULL,
    ctx_id          TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irta_node    ON bauth.idn_roles_template_history(node_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_irta_op      ON bauth.idn_roles_template_history(operation, created_at DESC);

REVOKE UPDATE, DELETE ON bauth.idn_roles_template_history FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.idn_roles_template_history FROM bauth_app_role;

COMMENT ON TABLE bauth.idn_roles_template_history IS
'ÁRBOL DE POLÍTICAS | Registro WORM inmutable de todos los cambios al árbol de políticas T-162.
Cada fila captura: node_id, operation (INSERT/UPDATE/DEACTIVATE), before_row y after_row como
JSONB, changed_by, change_reason y hash_chain SHA-256 que encadena cada entrada a la anterior.
Permite forensia completa: qué nodo cambió, quién, cuándo y por qué; y verificar la integridad
de la cadena de evidencia sin requerir fuentes externas.
Fuente: creado exclusivamente por el trigger del Motor de Políticas (Rust) al modificar T-162;
nunca por INSERT directo. REVOKE UPDATE/DELETE garantiza inmutabilidad desde el motor de BD.
Administración: solo INSERT permitido. Solo bauth_app_role puede insertar. Antes de desactivar
un nodo en T-162, el Motor escribe la entrada DEACTIVATE aquí con before_row y change_reason.
hash_chain = SHA-256(prev_hash || node_id || operation || after_row::text || created_at).
WORM: sí — REVOKE UPDATE/DELETE desde PUBLIC y bauth_app_role.
Particionada: no (candidata por created_at si el volumen supera 5M cambios).
Estándar: ISO 27001 A.8.15, NIST SP 800-53 AU-9, NIST AU-10. T-163.';


-- T-153 implementado como bauth.idn_roles_ver_b03_approval_queue — ver bloque MOTOR DE VERSIONADO F2 arriba.


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║           NIVEL 6 — IDENTIDAD D00 (bauth)                          ║
-- ║   D00: Jerarquía de entidades + NHI (Non-Human Identities)         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-156 — bauth.idn_identity_entity
-- Raíz del modelo de identidad D00. Toda entidad: tenant, bdomain, bsubdomain, pos, actor.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_entity (
    entity_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id        UUID        REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    level            entidad_nivel_enum NOT NULL,
    code             TEXT        NOT NULL,
    name             JSONB       NOT NULL,
    description      TEXT,
    depth            INTEGER     NOT NULL DEFAULT 0,
    path             TEXT,
    ial_min          ial_level_enum DEFAULT 'IAL1',
    status           TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','ARCHIVED')),
    metadata         JSONB       DEFAULT '{}',
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_iie_tenant  ON bauth.idn_identity_entity(tenant_id, level);
CREATE INDEX IF NOT EXISTS idx_iie_parent  ON bauth.idn_identity_entity(parent_id);
CREATE INDEX IF NOT EXISTS idx_iie_status  ON bauth.idn_identity_entity(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_iie_name    ON bauth.idn_identity_entity USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bauth.idn_identity_entity IS
'IDENTIDAD D00 | Raíz del modelo de identidad SBOS. Toda entidad del ecosistema (tenant,
empresa, sucursal, punto de venta, persona) es un nodo en esta tabla. Jerarquía 5 niveles:
tenant > bdomain (empresa) > bsubdomain (sucursal) > pos (punto de venta) > actor (hoja).
El actor es el nodo final que porta credenciales, roles y atributos verificados (IAL1-3).
ial_min: nivel IAL mínimo requerido para operar este nodo. path: camino materializado
(tenant.company.branch.pos.actor) recalculado por trigger al cambiar parent_id.
Fuente: creada por el IAM Installer al desplegar el tenant raíz; actores vía RPC
bauth.identity.entity.create con IAL mínimo IAL1.
Administración: el Motor de Identidad es el único escritor; biedata y otros daemons son
lectores por contrato. Cambiar parent_id requiere recalcular paths descendientes (trigger).
Eliminar un nodo (ON DELETE CASCADE) elimina toda su jerarquía — requiere HITL.
WORM: no — status y metadata son actualizables (SUSPENDED/ARCHIVED es el flujo de baja).
Particionada: no.
Seed: DDLs/seeds/bauth_T156__idn_identity_entity.sql — idempotente ON CONFLICT.
Estándar: ISO 24760-2:2025, NIST SP 800-63A IAL1-3, ISO 27001 A.5.16. T-156.';

COMMENT ON COLUMN bauth.idn_identity_entity.level  IS '[ENUM] Nivel jerárquico: tenant (raíz del ecosistema del cliente), bdomain (empresa/organización), bsubdomain (sucursal/departamento), pos (punto de servicio/venta), actor (entidad hoja — persona, sistema, bot que porta credenciales y roles).';
COMMENT ON COLUMN bauth.idn_identity_entity.path   IS 'Camino materializado en formato UUID.UUID.UUID — ej. <tenant_id>.<company_id>.<actor_id>. Recalculado automáticamente por trigger al cambiar parent_id. Usado para consultas de árbol completo eficientes (path LIKE prefix%).';
COMMENT ON COLUMN bauth.idn_identity_entity.ial_min IS 'Identity Assurance Level mínimo requerido para que una identidad pueda operar en este nodo: IAL1 (autodeclarado), IAL2 (remoto verificado), IAL3 (presencial verificado). El Motor de Identidad rechaza vínculos con identidades de IAL inferior.';
COMMENT ON COLUMN bauth.idn_identity_entity.metadata IS 'Metadatos libres del nodo en JSONB — datos propios del nivel (ej. para bdomain: nit, razón social; para pos: dirección física, coordenadas GPS; para actor: cargo, contacto). Schema libre por diseño; validación en capa de aplicación.';


-- ======================================================================
-- T-157 — bauth.idn_identity_attribute
-- Atributos de identidad por entidad. JSONB abierto + campos de metadato ISO.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute (
    attribute_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    entity_id         UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    attr_namespace    TEXT        NOT NULL DEFAULT 'core',
    attr_key          TEXT        NOT NULL,
    attr_value        JSONB       NOT NULL,
    attr_type         TEXT        NOT NULL DEFAULT 'TEXT',
    verified          BOOLEAN     NOT NULL DEFAULT false,
    verified_at       TIMESTAMPTZ,
    verified_by       UUID,
    source            TEXT        NOT NULL DEFAULT 'self',
    valid_from        TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until       TIMESTAMPTZ,
    is_active         BOOLEAN     NOT NULL DEFAULT true,
    pii_category      TEXT        NULL
        CHECK (pii_category IN ('EMAIL','PHONE','NID','BIOMETRIC','FINANCIAL','ADDRESS','NAME','DATE_OF_BIRTH','NONE')),
    legal_basis       TEXT        NULL
        CHECK (legal_basis IN ('CONTRACT','LEGAL_OBLIGATION','LEGITIMATE_INTEREST','CONSENT','VITAL_INTEREST')),
    ctx_id            TEXT        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_iiattr_entity_ns_key UNIQUE (entity_id, attr_namespace, attr_key),
    -- [ISO 27001 A.5.12+A.5.13] Namespaces sensibles deben declarar pii_category y legal_basis. T-BACKLOG-008+002.
    CONSTRAINT chk_attr_pii_metadata_completa CHECK (
        attr_namespace NOT IN ('biometric','identification','fiscal','verification')
        OR (pii_category IS NOT NULL AND legal_basis IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_iiattr_entidad ON bauth.idn_identity_attribute(entity_id, attr_namespace);
CREATE INDEX IF NOT EXISTS idx_iiattr_key     ON bauth.idn_identity_attribute(attr_key, attr_namespace);
CREATE INDEX IF NOT EXISTS idx_iiattr_value   ON bauth.idn_identity_attribute USING GIN (attr_value jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_iiattr_active  ON bauth.idn_identity_attribute(entity_id, is_active) WHERE is_active = true;

COMMENT ON TABLE bauth.idn_identity_attribute IS
'IDENTIDAD D00 | Atributos de identidad por entidad (modelo EAV controlado). Cada fila es
un par (attr_namespace, attr_key) = attr_value JSONB para una entidad T-156. Namespaces:
core (nombre, CI, fecha_nacimiento), contact (email, teléfono), professional (cargo, empresa),
verification (IAL ref, biometric_ref), security (MFA, recovery), fiscal (NIT, CUCE).
verified=true significa el atributo fue verificado contra fuente externa (IAL2/IAL3 lo requieren).
source: self=autoreportado, document=cédula verificada, biometric, employer, government, blockchain.
Historial WORM de cambios en T-158 (particionado mensual).
Fuente: creados por el Motor de Identidad al registrar o elevar el IAL de un actor; también
vía RPC bauth.identity.attribute.upsert (incluye verificación de fuente IAL si aplica).
Administración: el Motor de Identidad controla quién puede actualizar cada attr_namespace;
is_active=false en vez de DELETE para mantener trazabilidad. El historial WORM en T-158 permite
reconstruir el estado en cualquier fecha (as-of queries). valid_until controla vigencia del atributo.
WORM: no — la tabla principal es mutable; el historial WORM está en T-158.
Particionada: no.
Estándar: ISO 11179 §8, ISO 24760-1 §5.3, NIST SP 800-63A IAL1-3. T-157.';

COMMENT ON COLUMN bauth.idn_identity_attribute.attr_namespace    IS 'core, professional, verification, security, contact, fiscal, biometric, identification.';
COMMENT ON COLUMN bauth.idn_identity_attribute.source            IS '[NIST 800-63A] self=autoreportado, document=cédula verificada, biometric, employer, government.';
COMMENT ON COLUMN bauth.idn_identity_attribute.pii_category      IS '[ISO 27001 A.5.34] Categoría formal de PII. NULL = atributo no-PII. Usado por bi18n para mask_method y por Motor de Identidad para controles de privacidad diferenciados.';
COMMENT ON COLUMN bauth.idn_identity_attribute.legal_basis        IS '[ISO 27001 A.5.34][GDPR Art.6] Base legal de procesamiento por atributo individual. NULL = no-PII. Complementa T-154 (retención a nivel de tabla) con granularidad por atributo.';


-- ======================================================================
-- T-158 — bauth.idn_identity_attribute_history
-- Historial WORM de cambios en idn_identity_attribute. Particionado por mes.
-- Hash-chain por (entity_id, attr_namespace, attr_key): detecta manipulación retroactiva.
-- ISO 27001:2022 A.8.15 · PCI DSS 4.0.1 Req 10.3.2 · GDPR Art. 30 · NIST AU-9.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history (
    history_id      UUID        NOT NULL DEFAULT uuidv7(),

    -- FK al atributo modificado (RESTRICT: evidencia forense, no borrar aunque el atributo se elimine)
    attribute_id     UUID        NOT NULL
                    REFERENCES bauth.idn_identity_attribute(attribute_id) ON DELETE RESTRICT,

    -- Copia desnormalizada para forensia completa sin JOIN
    entity_id      UUID        NOT NULL,
    attr_namespace  TEXT        NOT NULL,
    attr_key        TEXT        NOT NULL,

    -- Delta del cambio
    attr_value_old  JSONB       NULL,       -- NULL en INSERT (sin valor anterior)
    attr_value_new  JSONB       NOT NULL,

    -- Quién realizó el cambio y por qué
    changed_by      UUID        NOT NULL
                    REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    change_reason   TEXT        NULL,

    -- Tipo de operación
    operation       TEXT        NOT NULL,
    CONSTRAINT chk_iah_operation CHECK (operation IN ('INSERT', 'UPDATE', 'SOFT_DELETE')),  -- [MC-0100] → A.65.04

    -- Hash-chain WORM (NIST AU-9)
    -- prev_hash: SHA-256 de la fila anterior para (entity_id, attr_namespace, attr_key)
    -- NULL en la primera fila de esa clave — marca inicio de cadena
    prev_hash       TEXT        NULL,

    -- row_hash: SHA-256(history_id || attribute_id || attr_key || attr_value_new::text || changed_at::text || COALESCE(prev_hash,''))
    -- Calculado por trigger antes del INSERT — no editable
    row_hash        TEXT        NOT NULL,

    -- Contexto y timestamp de particionado
    ctx_id          TEXT        NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- PK compuesta requerida por particionado RANGE en changed_at
    CONSTRAINT idn_identity_attribute_history_pkey
        PRIMARY KEY (history_id, changed_at)

) PARTITION BY RANGE (changed_at);

-- ─── Particiones iniciales ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_07
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_08
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_09
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_10
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_11
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE IF NOT EXISTS bauth.idn_identity_attribute_history_2026_12
    PARTITION OF bauth.idn_identity_attribute_history
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- ─── Índices (heredados por todas las particiones) ────────────────────
CREATE INDEX IF NOT EXISTS idx_iah_atributo
    ON bauth.idn_identity_attribute_history(attribute_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_iah_entidad_key
    ON bauth.idn_identity_attribute_history(entity_id, attr_namespace, attr_key, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_iah_changed_by
    ON bauth.idn_identity_attribute_history(changed_by, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_iah_operation
    ON bauth.idn_identity_attribute_history(operation, changed_at DESC);

-- ─── WORM: revocar UPDATE y DELETE ───────────────────────────────────
REVOKE UPDATE, DELETE ON bauth.idn_identity_attribute_history FROM bauth_app_role;

-- ─── COMMENTs normativos ──────────────────────────────────────────────
COMMENT ON TABLE bauth.idn_identity_attribute_history IS
'IDENTIDAD D00 | Historial WORM append-only de cada cambio en idn_identity_attribute (T-157).
Particionado mensual por changed_at. Hash-chain SHA-256 por (entity_id, attr_namespace, attr_key):
encadena cada fila a la anterior — prev_hash=NULL solo en la primera fila de esa clave.
row_hash = SHA-256(history_id||attribute_id||attr_key||attr_value_new||changed_at||COALESCE(prev_hash,""")).
Captura: attr_value_old (NULL en INSERT), attr_value_new, operation (INSERT/UPDATE/SOFT_DELETE),
changed_by y change_reason. Permite as-of queries y detección de manipulación retroactiva.
Fuente: creada exclusivamente por el trigger del Motor de Identidad al modificar T-157;
nunca por INSERT directo. Job mensual: crea partición del mes siguiente el día 1 de cada mes.
Administración: REVOKE UPDATE/DELETE desde bauth_app_role: solo INSERT desde el daemon.
Solo el Motor de Identidad puede escribir; lectura libre para el Testeador y el Documentador.
WORM: sí — REVOKE UPDATE/DELETE aplicado; hash-chain por clave de atributo.
Particionada: sí — PARTITION BY RANGE (changed_at), granularidad mensual.
Estándar: ISO 27001 A.8.15, PCI DSS 4.0.1 Req 10.3.2, GDPR Art.30, NIST AU-9. T-158.';

COMMENT ON COLUMN bauth.idn_identity_attribute_history.attribute_id    IS 'FK RESTRICT a idn_identity_attribute. El historial persiste aunque el atributo se elimine logicamente.';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.attr_value_old IS 'NULL en INSERT (sin valor previo). Copia del valor anterior para forensia sin JOIN a T-157.';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.attr_value_new IS 'Valor nuevo del atributo despues del cambio. Siempre presente.';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.operation      IS 'INSERT=nuevo atributo · UPDATE=modificacion de valor · SOFT_DELETE=is_active puesto a false.';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.prev_hash      IS '[NIST AU-9] Hash SHA-256 de la fila anterior de esta misma clave. NULL = primera fila de la cadena.';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.row_hash       IS '[NIST AU-9] SHA-256 del contenido de esta fila. Verificado por bauth.fn_verify_attr_hash_chain(attribute_id).';
COMMENT ON COLUMN bauth.idn_identity_attribute_history.changed_at     IS 'Timestamp de la modificacion. Columna de particionado — inmutable post-INSERT.';

-- ======================================================================
-- T-159 — bauth.idn_identity_requirement
-- Requisitos de completitud de atributos por (entity_type, ial_level).
-- NIST SP 800-63A-4 §4 · ISO/IEC 24760-2:2025 §5 · ISO 11179-3:2023.
-- Validada por el Motor de Identidad antes de elevar el ial_achieved de un actor.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_requirement (
    requirement_id        UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- Alcance: NULL = global (sistema); NOT NULL = override del tenant
    tenant_id           UUID        NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- A qué tipo de entidad aplica y a qué level IAL
    entity_type         entidad_nivel_enum NOT NULL,
    ial_level           ial_level_enum     NOT NULL,

    -- Qué atributo es is_required
    attr_namespace      TEXT        NOT NULL,
    attr_key            TEXT        NOT NULL,

    -- Restricciones del atributo
    is_required         BOOLEAN     NOT NULL DEFAULT true,
    must_be_verified    BOOLEAN     NOT NULL DEFAULT false,
    accepted_sources    TEXT[]      NOT NULL DEFAULT '{self}',
    -- Valores válidos: 'self','document','biometric','employer','government','blockchain'

    validation_regex    TEXT        NULL,
    max_age_days        INTEGER     NULL,
    -- Antigüedad máxima del atributo para considerarlo vigente (NULL = sin límite)

    error_message       JSONB       NOT NULL
                        DEFAULT '{"es":"Atributo is_required","en":"Required attribute"}',

    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_ir_requisito
        UNIQUE (tenant_id, entity_type, ial_level, attr_namespace, attr_key)
);

CREATE INDEX IF NOT EXISTS idx_ir_entity_ial
    ON bauth.idn_identity_requirement(entity_type, ial_level)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_ir_tenant
    ON bauth.idn_identity_requirement(tenant_id, entity_type)
    WHERE tenant_id IS NOT NULL AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_ir_namespace
    ON bauth.idn_identity_requirement(attr_namespace, attr_key);

COMMENT ON TABLE bauth.idn_identity_requirement IS
'IDENTIDAD D00 | Esquema formal de completitud de identidad: define qué atributos son
obligatorios por combinación (entity_type, ial_level). El Motor de Identidad consulta esta
tabla ANTES de elevar el ial_achieved de un actor. Si algún atributo requerido falta o no
está verified, el motor devuelve error con el campo error_message bilingüe.
Patrón override en dos capas: tenant_id=NULL = regla global (base del sistema); tenant_id
NOT NULL = override del tenant que sobreescribe la regla global para esa clave específica.
Seeds: requisitos IAL1 (nombre+email autoreportados), IAL2 (CI verificada, email verificado),
IAL3 (CI + biometría, fuentes government/biometric).
Fuente: seed de despliegue con requisitos IAL1/IAL2/IAL3 globales; overrides del tenant
vía RPC bauth.identity.requirement.override con HITL (cambia umbrales de seguridad).
Administración: solo SUPER_ADMIN y TENANT_ADMIN pueden configurar overrides; is_active=false
en vez de DELETE — mantiene historicidad de qué se requería en cada período. El campo
accepted_sources controla las fuentes válidas de verificación por tier IAL.
WORM: no — is_active es editable; el override de un tenant se actualiza vía UPSERT.
Particionada: no.
Seed: DDLs/seeds/bauth_T159__idn_identity_requirement.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-63A-4 §4, ISO 24760-2:2025 §5, ISO 11179-3:2023. T-159.';

COMMENT ON COLUMN bauth.idn_identity_requirement.tenant_id        IS 'NULL = global (aplica a todos los tenants). NOT NULL = override específico del tenant.';
COMMENT ON COLUMN bauth.idn_identity_requirement.entity_type      IS '[ENUM entidad_nivel] actor es el caso principal; también aplica a bdomain/bsubdomain/pos.';
COMMENT ON COLUMN bauth.idn_identity_requirement.ial_level         IS '[NIST 800-63A-4] IAL1=autoafirmado · IAL2=verificado remoto · IAL3=verificado presencial.';
COMMENT ON COLUMN bauth.idn_identity_requirement.must_be_verified  IS '[NIST 800-63A-4 §5] true = atributo.verified=true obligatorio. IAL2+: CI, email, phone deben estar verified.';
COMMENT ON COLUMN bauth.idn_identity_requirement.accepted_sources  IS '[NIST 800-63A-4 §5.1] Fuentes de verificación aceptadas. IAL3 solo acepta government/biometric.';
COMMENT ON COLUMN bauth.idn_identity_requirement.validation_regex  IS 'Regex de validación del valor. Ej: CI boliviana → ''^\\d{7,8}$''. NULL = sin validación de formato.';
COMMENT ON COLUMN bauth.idn_identity_requirement.max_age_days      IS 'Antigüedad máxima del atributo. IAL2: típicamente 365 días. NULL = sin límite de antigüedad.';
COMMENT ON COLUMN bauth.idn_identity_requirement.error_message     IS 'Mensaje de error bilingüe {es, en} devuelto por el Motor de Identidad al frontend cuando falla la validación.';

-- ─── Seeds base: requisitos globales del sistema ───────────────────────



-- ======================================================================
-- T-160 — bauth.idn_identity_synonym
-- Sinónimos y abreviaturas para búsqueda difusa de identidades.
-- Fuente de verdad de archivos .syn de PostgreSQL para D93 (bsearch).
-- NIST SP 800-63A-4 §4.2 · Administrable desde el dashboard.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_synonym (
    synonym_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID        NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    canonical_form  TEXT        NOT NULL,
    synonym_text    TEXT        NOT NULL,
    language_code   TEXT        NOT NULL DEFAULT 'es',
    synonym_type    TEXT        NOT NULL DEFAULT 'ABBREVIATION'
                    CHECK (synonym_type IN ('ABBREVIATION','ALIAS','COLLOQUIAL','FORMAL','LEGAL')),
    source          TEXT        NOT NULL DEFAULT 'MANUAL',
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_idsyn_canonical_synonym UNIQUE (tenant_id, canonical_form, synonym_text, language_code)
);
CREATE INDEX IF NOT EXISTS idx_idsyn_canonical ON bauth.idn_identity_synonym (canonical_form);
CREATE INDEX IF NOT EXISTS idx_idsyn_tenant    ON bauth.idn_identity_synonym (tenant_id, is_active);
COMMENT ON TABLE bauth.idn_identity_synonym IS
'IDENTIDAD | Sinónimos y abreviaturas para búsqueda difusa de identidades — fuente de verdad de
los archivos .syn de PostgreSQL consumidos por el motor de búsqueda D93 (bsearch). Cada fila
asocia un sinónimo al texto canónico: "empresa"→"organización", "RUT"→"NIT", etc.
tenant_id=NULL = sinónimo global válido en todos los tenants. El daemon bAuth regenera los
archivos .syn cuando cambia esta tabla (estado coordinado con T-161 idn_identity_synonym_sync).
Estándar: NIST SP 800-63A-4 §4.2. T-160.';

-- ======================================================================
-- T-161 — bauth.idn_identity_synonym_sync
-- Control de sincronización de diccionarios .syn de PostgreSQL.
-- Registra cuándo se regeneraron desde T-160; evita recarga innecesaria.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identity_synonym_sync (
    sync_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    entity_type     TEXT        NOT NULL
                    CHECK (entity_type IN ('PERSON','ORGANIZATION','LOCATION','ROLE','ATTRIBUTE')),
    language_code   TEXT        NOT NULL DEFAULT 'es',
    last_sync_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_hash     TEXT        NOT NULL,
    syn_file_path   TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'SYNCED'
                    CHECK (status IN ('SYNCED','PENDING','FAILED','BUILDING')),
    row_count       INTEGER     NOT NULL DEFAULT 0 CHECK (row_count >= 0),
    error_detail    TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    CONSTRAINT uq_idss_entity_lang UNIQUE (entity_type, language_code)
);
COMMENT ON TABLE bauth.idn_identity_synonym_sync IS
'IDENTIDAD | Control de sincronización de diccionarios .syn para búsqueda difusa. Registra el
estado de cada archivo .syn generado desde T-160 (idn_identity_synonym): cuándo fue la última
regeneración (last_sync_at), hash del contenido fuente (source_hash — para detectar cambios
sin releer T-160 completo), ruta en disco (syn_file_path) y estado (SYNCED/PENDING/FAILED).
El daemon bAuth consulta esta tabla antes de regenerar un archivo: si source_hash no cambió
desde last_sync_at, omite la regeneración. UNIQUE por (entity_type, language_code).
Estándar: PostgreSQL Full-Text Search Dictionary Management §12.6. T-161.';


-- ======================================================================
-- T-186 — bauth.idn_roles_nhi_identity
-- Entidad raíz de toda identidad máquina: daemons, bots, pipelines, service accounts, agentes IA.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_nhi_identity (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nhi_type        TEXT        NOT NULL,
    display_name    TEXT        NOT NULL,
    system_ref      TEXT        NOT NULL,
    owner_id        UUID        NOT NULL,
    backup_owner_id UUID        NULL,
    description     TEXT        NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID        NOT NULL,
    last_used_at    TIMESTAMPTZ NULL,
    review_at       TIMESTAMPTZ NOT NULL,
    decommission_at TIMESTAMPTZ NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT idn_roles_nhi_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_nhi_system_ref UNIQUE (tenant_id, system_ref),
    CONSTRAINT chk_inhi_type CHECK (  -- [MC-0220] → A.65.04
        nhi_type IN ('SERVICE_ACCOUNT','WORKLOAD','AGENT','BOT','API_CLIENT','CI_CD_PIPELINE')
    ),
    CONSTRAINT chk_inhi_status CHECK (  -- [MC-0219] → A.65.04
        status IN ('ACTIVE','DORMANT','DECOMMISSIONED','SUSPENDED')
    )
);

CREATE INDEX IF NOT EXISTS idx_inhi_owner   ON bauth.idn_roles_nhi_identity (owner_id);
CREATE INDEX IF NOT EXISTS idx_inhi_review  ON bauth.idn_roles_nhi_identity (review_at) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_inhi_dormant ON bauth.idn_roles_nhi_identity (last_used_at) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.idn_roles_nhi_identity IS
'IDENTIDAD NHI | Entidad raíz de toda identidad máquina gobernada: SERVICE_ACCOUNT, WORKLOAD,
AGENT, BOT, API_CLIENT, CI_CD_PIPELINE. Registro único por (tenant_id, system_ref). Cada NHI
tiene owner_id obligatorio (persona humana accountable — NIST AC-2(7)) y backup_owner_id
opcional. last_used_at se actualiza en cada autenticación exitosa; dormancia > 90 días alerta.
review_at: fecha del próximo ciclo de revisión (30d CI/CD, 90d service accounts). El reconcile
loop de NHI detecta vencimientos y genera eventos en T-187.
Fuente: seed IAM Installer crea una fila por daemon SBOS (bkernel, biedata, bnotify, bsearch,
bnexus); actores externos vía RPC bauth.identity.nhi.provision con aprobación HITL.
Administración: solo SUPER_ADMIN y TENANT_ADMIN pueden crear/descomisionar NHI. El cambio
de owner_id genera evento OWNER_CHANGED en T-187. decommission_at activa baja programada.
WORM: no — status y last_used_at son actualizables (DORMANT/DECOMMISSIONED es el flujo de baja).
Particionada: no.
Estándar: NIST SP 800-53 IA-2, NIST AC-2(7), ISO 27001 A.5.16, Gartner IGA 2025. T-186.';

-- ======================================================================
-- T-187 — bauth.idn_roles_nhi_lifecycle_event
-- Log WORM de eventos del ciclo de vida de un NHI. Append-only. ISO 27001 A.8.15.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_nhi_lifecycle_event (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id          UUID        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    event_type      TEXT        NOT NULL,
    actor_id        UUID        NOT NULL,
    event_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes           TEXT        NULL,
    metadata        JSONB       NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT idn_roles_nhi_lifecycle_event_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inle_type CHECK (  -- [MC-0221] → A.65.04
        event_type IN (
            'PROVISIONED','CERTIFIED','ROTATED','SUSPENDED',
            'REACTIVATED','DECOMMISSIONED','OWNER_CHANGED','REVIEW_SCHEDULED'
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_inle_nhi ON bauth.idn_roles_nhi_lifecycle_event (nhi_id, event_at DESC);

REVOKE UPDATE, DELETE ON bauth.idn_roles_nhi_lifecycle_event FROM bauth_app_role;

COMMENT ON TABLE bauth.idn_roles_nhi_lifecycle_event IS
'IDENTIDAD NHI | Log WORM append-only del ciclo de vida de cada identidad máquina (T-186).
Registra transiciones: PROVISIONED→CERTIFIED→ROTATED/SUSPENDED→REACTIVATED→DECOMMISSIONED
y eventos administrativos: OWNER_CHANGED, REVIEW_SCHEDULED. event_type está verificado por
constraint chk_inle_type. metadata JSONB captura contexto adicional (ej: certificado rotado,
antiguo propietario). Trigger automático en T-186: cada cambio de status genera entrada aquí.
Fuente: creado por el trigger del Motor de Identidad (Rust) al cambiar el estado de un NHI
o por el reconcile loop de NHI al detectar dormancia/vencimiento. Nunca por INSERT directo.
Administración: REVOKE UPDATE/DELETE desde bauth_app_role: solo INSERT desde el daemon.
Solo el Motor de Identidad puede escribir; lectura disponible para auditorías y el Testeador.
WORM: sí — REVOKE UPDATE/DELETE aplicado.
Particionada: no (candidata por event_at si el volumen de NHI es alto).
Estándar: NIST SP 800-53 IA-5(4), ISO 27001 A.8.2, ISO 27001 A.8.15. T-187.';

-- ======================================================================
-- T-188 — bauth.idn_roles_nhi_certification
-- Certificación periódica mensual de NHI por el propietario técnico.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_nhi_certification (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id          UUID        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    reviewer_id     UUID        NOT NULL,
    period_start    TIMESTAMPTZ NOT NULL,
    period_end      TIMESTAMPTZ NOT NULL,
    last_used_at    TIMESTAMPTZ NULL,
    access_count    INTEGER     NULL,
    decision        TEXT        NOT NULL,
    justification   TEXT        NULL,
    reviewed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT idn_roles_nhi_certification_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inc_decision CHECK (  -- [MC-0218] → A.65.04
        decision IN ('CERTIFY','DECOMMISSION','REDUCE_SCOPE','ESCALATE')
    )
);

CREATE INDEX IF NOT EXISTS idx_inc_nhi ON bauth.idn_roles_nhi_certification (nhi_id, reviewed_at DESC);

COMMENT ON TABLE bauth.idn_roles_nhi_certification IS
'IDENTIDAD NHI | Registro de certificaciones periódicas de identidades máquina (T-186). El
propietario técnico (reviewer_id) decide por cada NHI y período: CERTIFY (continúa), DECOMMISSION
(baja), REDUCE_SCOPE (restringe permisos) o ESCALATE (escala al TENANT_ADMIN). access_count=0
en el período es el indicador más fuerte para recomendar DECOMMISSION (NHI dormido).
Cadencia mensual (más corta que la certificación humana trimestral — los NHI cambian más rápido
y sus credenciales se rotan con mayor frecuencia).
Fuente: creada por la campaña de certificación IGA iniciada por el reconcile loop de NHI
o por el job bauth-nhi-certification; nunca por INSERT directo del usuario.
Administración: solo el propietario técnico (reviewer_id) del NHI puede certificar. El daemon
valida que reviewer_id sea efectivamente el owner_id del NHI antes de aceptar la decisión.
WORM: no — la certificación es un estado de decisión, no una bitácora de eventos.
Particionada: no.
Estándar: NIST SP 800-53 AC-2(7), ISO 27001 A.5.16, CIS Benchmark §Service Accounts. T-188.';

-- ======================================================================
-- T-190 — bauth.idn_roles_nhi_agent_identity
-- Especialización de NHI para agentes IA autónomos con permisos acotados.
-- ⚠️ PENDIENTE decisión HITL: ¿herencia de permisos padre→hijo o permisos propios?
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_nhi_agent_identity (
    id                   UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id               UUID        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    agent_framework      TEXT        NOT NULL,
    orchestrator_id      UUID        NULL REFERENCES bauth.idn_roles_nhi_agent_identity(id),
    max_permission_scope TEXT[]      NOT NULL DEFAULT '{}',
    session_type         TEXT        NOT NULL DEFAULT 'EPHEMERAL',
    can_spawn_agents     BOOLEAN     NOT NULL DEFAULT false,
    max_spawn_depth      INTEGER     NOT NULL DEFAULT 0,
    CONSTRAINT idn_roles_nhi_agent_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_iai_nhi UNIQUE (nhi_id),
    CONSTRAINT chk_iai_session CHECK (session_type IN ('EPHEMERAL','PERSISTENT')),  -- [MC-0217] → A.65.04
    CONSTRAINT chk_iai_spawn CHECK (
        (can_spawn_agents = false AND max_spawn_depth = 0)
        OR (can_spawn_agents = true AND max_spawn_depth > 0)
    )
);

COMMENT ON TABLE bauth.idn_roles_nhi_agent_identity IS
'IDENTIDAD NHI | Especialización de idn_roles_nhi_identity (T-186) para agentes IA autónomos
del ecosistema SBOS (ORQUESTA, BauthAgent, etc.). Extiende el NHI con capacidades específicas
de IA: max_permission_scope restringe qué dominios puede usar el agente aunque su NHI padre
tenga más acceso; session_type (EPHEMERAL/PERSISTENT) controla la duración de la sesión;
orchestrator_id construye el árbol padre→hijo de orquestación para forensia de acciones;
can_spawn_agents y max_spawn_depth controlan si puede crear sub-agentes y hasta qué profundidad.
Fuente: creada por el IAM Installer al registrar los agentes de la fábrica ORQUESTA;
agentes ad-hoc vía RPC bauth.identity.nhi.agent.register con HITL obligatorio.
Administración: solo SUPER_ADMIN puede crear filas; max_permission_scope es la guardia de
mínimo privilegio del agente — NUNCA puede exceder los permisos del NHI padre.
⚠️ Pendiente HITL: decisión sobre herencia de permisos padre→hijo vs. permisos propios independientes.
WORM: no — max_permission_scope y session_type son ajustables operacionalmente.
Particionada: no.
Estándar: NIST AI RMF 1.0, ISO 42001:2023, CSA NHI Governance 2025. T-190.';


-- ======================================================================
-- T-187 — bauth.idn_scim_attribute_map
-- Mapeo bidireccional entre atributos SCIM 2.0 (RFC 7643/7644) y los atributos
-- locales de bAuth. Permite a bAuth exponer y consumir identidades via SCIM
-- sin acoplar el esquema externo al modelo interno. GAP-D00-08.
-- tenant_id=NULL = regla global; NOT NULL = override del tenant.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_scim_attribute_map (
    map_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    scim_resource    TEXT        NOT NULL,
    scim_attr        TEXT        NOT NULL,
    local_namespace  TEXT        NOT NULL,
    local_attr_key   TEXT        NOT NULL,
    local_table      TEXT        NOT NULL DEFAULT 'idn_identidad_atributo',
    scim_mutability  TEXT        NOT NULL DEFAULT 'readWrite',
    scim_returned    TEXT        NOT NULL DEFAULT 'default',
    transform_expr   TEXT        NULL,
    activo           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_isam_tenant_resource_attr UNIQUE (tenant_id, scim_resource, scim_attr),
    CONSTRAINT chk_isam_resource CHECK (  -- [MC-0115] → A.65.04
        scim_resource IN ('User','Group','EnterpriseUser','ServiceAccount','CustomResource')
    ),
    CONSTRAINT chk_isam_mutability CHECK (  -- [MC-0114] → A.65.04
        scim_mutability IN ('readOnly','readWrite','immutable','writeOnly')
    ),
    CONSTRAINT chk_isam_returned CHECK (  -- [MC-0116] → A.65.04
        scim_returned IN ('always','never','default','request')
    ),
    CONSTRAINT chk_isam_table CHECK (  -- [MC-0117] → A.65.04
        local_table IN ('idn_identidad_atributo','idn_identidad_entidad','idn_identidad_proofing','idn_identidad_vc')
    )
);

CREATE INDEX IF NOT EXISTS idx_isam_resource ON bauth.idn_scim_attribute_map (scim_resource);
CREATE INDEX IF NOT EXISTS idx_isam_local    ON bauth.idn_scim_attribute_map (local_namespace, local_attr_key);
CREATE INDEX IF NOT EXISTS idx_isam_tenant   ON bauth.idn_scim_attribute_map (tenant_id) WHERE tenant_id IS NOT NULL;

COMMENT ON TABLE bauth.idn_scim_attribute_map IS
'IDENTIDAD SCIM D00 | Mapeo bidireccional SCIM 2.0 ↔ atributos locales bAuth (GAP-D00-08).
Permite que bAuth actúe como SCIM server (RFC 7644) y cliente (provisioning) sin acoplar el
esquema externo al modelo interno. Cada fila describe cómo un atributo SCIM se mapea a un
atributo local (local_namespace + local_attr_key en la tabla local_table).
Patrón override en dos capas: tenant_id=NULL = regla global del sistema; tenant_id NOT NULL
= override del tenant que sobreescribe la regla global para ese atributo específico.
transform_expr: expresión opcional para transformar el valor SCIM→local (SQL/JSONPath).
Fuente: seed de despliegue con los atributos SCIM User/Group estándar (RFC 7643 §4.1-4.2);
overrides del tenant vía RPC bauth.identity.scim.map.override con HITL.
Administración: solo SUPER_ADMIN y TENANT_ADMIN pueden configurar overrides. activo=false
desactiva el mapeo sin eliminarlo (trazabilidad histórica). Revisión al actualizar schema SCIM.
WORM: no — activo y transform_expr son editables vía UPSERT controlado.
Particionada: no.
Seed: DDLs/seeds/bauth_T187__idn_scim_attribute_map.sql — idempotente ON CONFLICT.
Estándar: RFC 7643, RFC 7644, NIST SP 800-63A-4 §4, ISO 24760-2:2025 §5. T-187.';

COMMENT ON COLUMN bauth.idn_scim_attribute_map.tenant_id       IS 'NULL = global (aplica a todos los tenants). NOT NULL = override específico del tenant para este atributo SCIM.';
COMMENT ON COLUMN bauth.idn_scim_attribute_map.scim_resource   IS '[ENUM] Tipo de recurso SCIM: User (RFC 7643 §4.1), Group (§4.2), EnterpriseUser (§4.3), ServiceAccount, CustomResource.';
COMMENT ON COLUMN bauth.idn_scim_attribute_map.scim_attr       IS 'Ruta del atributo SCIM en notación de punto. Ej: userName, name.givenName, emails[type=work].value.';
COMMENT ON COLUMN bauth.idn_scim_attribute_map.local_namespace IS 'Namespace del atributo en el modelo local: identity, contact, hr, organization, etc.';
COMMENT ON COLUMN bauth.idn_scim_attribute_map.scim_mutability IS '[RFC 7643 §7] readOnly/readWrite/immutable/writeOnly — controla si el atributo puede ser actualizado por el cliente SCIM.';
COMMENT ON COLUMN bauth.idn_scim_attribute_map.transform_expr  IS 'Expresión opcional de transformación valor SCIM→local (JSONPath o SQL). NULL = mapeo directo sin transformación.';


-- T-165 — bauth.idn_identity_proofing
-- [NIST SP 800-63A-4 §4-6] [ISO/IEC 29115:2013] [ISO 24760-2:2025 §7.2] [eIDAS 2.0 Art. 24] [D00-B06]
CREATE TABLE IF NOT EXISTS bauth.idn_identity_proofing (
    proofing_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    entity_id      UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)
                    ON DELETE CASCADE,
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id)
                    ON DELETE CASCADE,
    ial_achieved    ial_level_enum NOT NULL,
    proofing_type   TEXT        NOT NULL,
    CONSTRAINT chk_ip_type CHECK (proofing_type IN (  -- [MC-0107] → A.65.04
        'SELF_ASSERTED','REMOTE_UNATTENDED','REMOTE_ATTENDED','IN_PERSON','TRUSTED_REFEREE'
    )),
    evidence        JSONB       NOT NULL DEFAULT '{}',
    evidence_count  SMALLINT    NOT NULL GENERATED ALWAYS AS (
        jsonb_array_length(COALESCE(evidence->'FAIR', '[]'::jsonb)) +
        jsonb_array_length(COALESCE(evidence->'STRONG', '[]'::jsonb)) +
        jsonb_array_length(COALESCE(evidence->'SUPERIOR', '[]'::jsonb))
    ) STORED,
    reviewer_id     UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id)
                    ON DELETE SET NULL,
    status          TEXT        NOT NULL DEFAULT 'PENDING',
    CONSTRAINT chk_ip_status CHECK (status IN (  -- [MC-0106] → A.65.04
        'PENDING','IN_PROGRESS','PASSED','FAILED','EXPIRED'
    )),
    failure_reason  TEXT        NULL,
    initiated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    proofed_at      TIMESTAMPTZ NULL,
    expires_at      TIMESTAMPTZ NULL,
    reproofing_at   TIMESTAMPTZ NULL,
    ctx_id          TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iip_entidad
    ON bauth.idn_identity_proofing(entity_id, status);
CREATE INDEX IF NOT EXISTS idx_iip_tenant_status
    ON bauth.idn_identity_proofing(tenant_id, status, ial_achieved);
CREATE INDEX IF NOT EXISTS idx_iip_reproofing
    ON bauth.idn_identity_proofing(reproofing_at)
    WHERE status = 'PASSED' AND reproofing_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iip_expires
    ON bauth.idn_identity_proofing(expires_at)
    WHERE status = 'PASSED' AND expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iip_reviewer
    ON bauth.idn_identity_proofing(reviewer_id)
    WHERE reviewer_id IS NOT NULL;

COMMENT ON TABLE bauth.idn_identity_proofing IS
'IDENTIDAD D00 | Registro del proceso de verificación de identidad (identity proofing) por actor.
Cada fila representa un ciclo de proofing con su tipo (SELF_ASSERTED, REMOTE_UNATTENDED,
REMOTE_ATTENDED, IN_PERSON, TRUSTED_REFEREE), evidencias (FAIR/STRONG/SUPERIOR en JSONB),
status (PENDING→IN_PROGRESS→PASSED/FAILED/EXPIRED) y el reviewer_id obligatorio para IAL3.
El Motor de Identidad consulta la fila más reciente con status=PASSED para determinar el IAL
vigente del actor. evidence_count es columna generada (no editable).
Fuente: creada por el Motor de Identidad al iniciar un ciclo de proofing desde la app del tenant;
para IAL3 se crea una fila PENDING que es revisada por el reviewer (empleado SBOS habilitado).
Administración: el Motor de Identidad es el único escritor. El Testeador puede leer para
verificar el IAL vigente. Jobs automáticos: 30 días antes de expires_at → alerta via bNotify
+ crear nueva fila PENDING para mantener el IAL sin interrupción.
WORM: no — status cambia durante el ciclo de vida (PENDING→PASSED/FAILED).
Particionada: no.
Estándar: NIST SP 800-63A-4 §4-6, ISO/IEC 29115:2013, ISO 24760-2:2025 §7.2, eIDAS 2.0. T-165.';
COMMENT ON COLUMN bauth.idn_identity_proofing.ial_achieved IS '[NIST 800-63A-4] IAL alcanzado en ESTE proofing. Diferente del ial_min is_required.';
COMMENT ON COLUMN bauth.idn_identity_proofing.proofing_type IS '[NIST 800-63A-4 §5] SELF_ASSERTED=IAL1 · REMOTE=IAL2 · IN_PERSON/TRUSTED_REFEREE=IAL3.';
COMMENT ON COLUMN bauth.idn_identity_proofing.evidence IS '[NIST 800-63A-4 §5.2] FAIR: doc débil · STRONG: doc oficial · SUPERIOR: biometría+doc.';
COMMENT ON COLUMN bauth.idn_identity_proofing.reviewer_id IS '[NIST 800-63A-4 §6.3] Obligatorio para IN_PERSON y TRUSTED_REFEREE (IAL3).';
COMMENT ON COLUMN bauth.idn_identity_proofing.expires_at IS 'IAL2: típicamente 365 días · IAL3: 180-730 días según política del tenant.';
COMMENT ON COLUMN bauth.idn_identity_proofing.reproofing_at IS 'Cuándo iniciar el re-proofing. Job: WHERE reproofing_at <= NOW() AND status=PASSED → notificar via bNotify.';

-- T-166 — bauth.idn_identity_consent
-- [GDPR Art. 6-7] [ISO/IEC 29184:2020] [Ley 1174 Bolivia Art. 12-15] [D00-B07]
CREATE TABLE IF NOT EXISTS bauth.idn_identity_consent (
    consent_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    entity_id          UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)
                        ON DELETE RESTRICT,
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id)
                        ON DELETE RESTRICT,
    policy_version      TEXT        NOT NULL,
    processing_scope    TEXT[]      NOT NULL,
    legal_basis         TEXT        NOT NULL,
    CONSTRAINT chk_ic_legal_basis CHECK (legal_basis IN (  -- [MC-0102] → A.65.04
        'CONSENT','CONTRACT','LEGAL_OBLIGATION','VITAL_INTEREST','PUBLIC_TASK','LEGITIMATE_INTEREST'
    )),
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_via         TEXT        NOT NULL,
    CONSTRAINT chk_ic_granted_via CHECK (granted_via IN (  -- [MC-0101] → A.65.04
        'WEB','API','APP','IN_PERSON','EMAIL'
    )),
    ip_address          INET        NULL,
    user_agent          TEXT        NULL,
    withdrawn_at        TIMESTAMPTZ NULL,
    withdrawal_reason   TEXT        NULL,
    withdrawn_via       TEXT        NULL,
    CONSTRAINT chk_ic_withdrawn_via CHECK (  -- [MC-0103] → A.65.04
        withdrawn_via IS NULL OR withdrawn_via IN ('WEB','API','APP','IN_PERSON','EMAIL','ADMIN')
    ),
    is_active           BOOLEAN     NOT NULL GENERATED ALWAYS AS (withdrawn_at IS NULL) STORED,
    ctx_id              TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ic_entidad_active
    ON bauth.idn_identity_consent(entity_id, is_active)
    WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ic_tenant_policy
    ON bauth.idn_identity_consent(tenant_id, policy_version);
CREATE INDEX IF NOT EXISTS idx_ic_legal_basis
    ON bauth.idn_identity_consent(tenant_id, legal_basis, is_active);
CREATE INDEX IF NOT EXISTS idx_ic_withdrawn
    ON bauth.idn_identity_consent(withdrawn_at)
    WHERE withdrawn_at IS NOT NULL;

REVOKE DELETE ON bauth.idn_identity_consent FROM bauth_app_role;

COMMENT ON TABLE bauth.idn_identity_consent IS
'IDENTIDAD D00 | Registro del consentimiento de privacidad por sujeto de datos (D00-B07).
Cada fila documenta: policy_version vigente, processing_scope (qué datos y para qué),
legal_basis (CONSENT/CONTRACT/LEGAL_OBLIGATION/etc.), granted_via (WEB/APP/IN_PERSON) e
ip_address + user_agent para evidencia forense. is_active es columna generada (NOT DELETE —
withdrawn_at IS NULL). La retirada (GDPR Art. 7.3) solo actualiza withdrawn_at y withdrawal_reason;
nunca se borra el registro de consentimiento.
Fuente: creado por el Motor de Identidad al registrar un actor o en cada actualización de
la política de privacidad del tenant que requiere nuevo consentimiento explícito.
Administración: REVOKE DELETE — solo INSERT y UPDATE de la columna withdrawn_at (retirada).
Solo bAuth puede crear consentimientos; el propio sujeto puede retirarlos vía su dashboard.
El campo legal_basis=CONSENT requiere consentimiento explícito activo para procesar los datos.
WORM: semi-WORM — REVOKE DELETE aplicado; withdrawn_at es el único UPDATE permitido operacionalmente.
Particionada: no.
Estándar: GDPR Art. 6-7, ISO/IEC 29184:2020, Ley 1174 Bolivia Art. 12-15, NIST SP 800-63-4. T-166.';
COMMENT ON COLUMN bauth.idn_identity_consent.policy_version IS '[GDPR Art. 7.1] Versión de política vigente al momento del consentimiento.';
COMMENT ON COLUMN bauth.idn_identity_consent.processing_scope IS '[ISO 29184] Alcances: analytics, marketing, third_party_sharing.';
COMMENT ON COLUMN bauth.idn_identity_consent.legal_basis IS '[GDPR Art. 6] Base legal. CONSENT solo cuando is_required — CONTRACT para empleados.';
COMMENT ON COLUMN bauth.idn_identity_consent.withdrawn_at IS '[GDPR Art. 7.3] Fecha de retirada. NULL = vigente. Único UPDATE permitido.';
COMMENT ON COLUMN bauth.idn_identity_consent.is_active IS 'Generado: true = withdrawn_at IS NULL.';

-- T-167 — bauth.idn_identity_vc
-- [W3C VC Data Model 2.0 Rec mayo 2025] [eIDAS 2.0 Reglamento UE 2024/1183 Art. 45] [D00-B08]
CREATE TABLE IF NOT EXISTS bauth.idn_identity_vc (
    vc_id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    entity_id          UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id)
                        ON DELETE RESTRICT,
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id)
                        ON DELETE CASCADE,
    vc_uri              TEXT        UNIQUE NOT NULL,
    vc_type             TEXT[]      NOT NULL,
    vc_format           TEXT        NOT NULL DEFAULT 'VC_DATA_MODEL_2_0',
    CONSTRAINT chk_ivc_format CHECK (vc_format IN (  -- [MC-0109] → A.65.04
        'VC_DATA_MODEL_1_1','VC_DATA_MODEL_2_0','SD_JWT_VC'
    )),
    issuer_did          TEXT        NOT NULL,
    subject_did         TEXT        NULL,
    credential_subject  JSONB       NOT NULL,
    proof               JSONB       NOT NULL DEFAULT '{}',
    issuance_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    expiration_date     TIMESTAMPTZ NULL,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_ivc_status CHECK (status IN (
        'ACTIVE','REVOKED','SUSPENDED','EXPIRED'
    )),
    revocation_reason   TEXT        NULL,
    revoked_at          TIMESTAMPTZ NULL,
    status_list_url     TEXT        NULL,
    status_list_index   BIGINT      NULL,
    proofing_id         UUID        NULL REFERENCES bauth.idn_identity_proofing(proofing_id)
                        ON DELETE SET NULL,
    ctx_id              TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ivc_entidad
    ON bauth.idn_identity_vc(entity_id, status);
CREATE INDEX IF NOT EXISTS idx_ivc_uri
    ON bauth.idn_identity_vc(vc_uri);
CREATE INDEX IF NOT EXISTS idx_ivc_issuer
    ON bauth.idn_identity_vc(issuer_did, status);
CREATE INDEX IF NOT EXISTS idx_ivc_subject
    ON bauth.idn_identity_vc(subject_did)
    WHERE subject_did IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ivc_type
    ON bauth.idn_identity_vc USING GIN (vc_type);
CREATE INDEX IF NOT EXISTS idx_ivc_expiry
    ON bauth.idn_identity_vc(expiration_date)
    WHERE status = 'ACTIVE' AND expiration_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ivc_subject_claims
    ON bauth.idn_identity_vc USING GIN (credential_subject jsonb_path_ops);

COMMENT ON TABLE bauth.idn_identity_vc IS
'IDENTIDAD D00 | Ciclo de vida de Verifiable Credentials (VC) emitidas o recibidas por bAuth
(D00-B08). bAuth actúa como Issuer: emite VCs de IAL verificado, roles certificados y atributos
con firma Ed25519 (Vault). Tres formatos: VC_DATA_MODEL_1_1, VC_DATA_MODEL_2_0, SD_JWT_VC
(selective disclosure — el sujeto revela solo los claims necesarios para cada verificador).
vc_uri: URI único de la VC (UNIQUE). issuer_did: DID del emisor (bAuth). subject_did: DID del
sujeto (opcional). credential_subject: claims JSONB — no almacenar PII en texto plano (usar
referencias). proof: DataIntegrityProof con eddsa-rdfc-2022 (Ed25519) vía Vault.
status_list_url/index: soporte para W3C VC Status List 2021 (revocación escalable sin consultar bAuth).
Fuente: emitidas por el Motor de Identidad al completar un proofing IAL o certificar un rol;
recibidas desde emisores externos y verificadas en el flujo de autenticación OIDC.
Administración: el Motor de Identidad (bAuth Issuer) es el único escritor. La revocación
actualiza status=REVOKED + revocation_reason + revoked_at. Nunca se borran — solo REVOKED.
WORM: no formalmente; pero status y campos de revocación son el único UPDATE esperado.
Particionada: no.
Estándar: W3C VC Data Model 2.0 (2025), eIDAS 2.0 Reglamento UE 2024/1183 Art.45, NIST SP 800-63-4. T-167.';
COMMENT ON COLUMN bauth.idn_identity_vc.vc_uri IS '[W3C VCDM 2.0 §4.1] Identificador único. UNIQUE.';
COMMENT ON COLUMN bauth.idn_identity_vc.vc_type IS '[W3C VCDM 2.0 §4.1] Siempre incluye "VerifiableCredential".';
COMMENT ON COLUMN bauth.idn_identity_vc.credential_subject IS '[W3C VCDM 2.0 §4.1] Claims sobre el sujeto. No almacenar PII en texto plano.';
COMMENT ON COLUMN bauth.idn_identity_vc.proof IS '[W3C VCDM 2.0 §4.8] DataIntegrityProof con eddsa-rdfc-2022 (Ed25519) vía Vault.';
COMMENT ON COLUMN bauth.idn_identity_vc.vc_format IS 'SD_JWT_VC: selective disclosure.';
COMMENT ON COLUMN bauth.idn_identity_vc.status_list_url IS '[W3C VC Status List 2021] Revocación escalable sin consultar bAuth.';


-- ======================================================================
-- T-500 — bauth.idn_attribute_schema
-- PIP: esquema canónico de atributos de identidad. D98-B01.
-- SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5 · NIST SP 800-162 §3.3
-- Permite que idn_identity_attribute (T-157, D00) sea extensible sin hardcode.
-- GAP-D01-01: classification + display_mask habilitan acceso a level de campo.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_attribute_schema (
    schema_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    attr_name       TEXT NOT NULL,
    scim_urn        TEXT NULL,
    display_name    JSONB NOT NULL,
    data_type       TEXT NOT NULL DEFAULT 'STRING'
        CONSTRAINT chk_idras_data_type CHECK (data_type IN (
            'STRING','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','UUID','JSON','BINARY')),
    is_required       BOOLEAN NOT NULL DEFAULT FALSE,
    is_multi_value     BOOLEAN NOT NULL DEFAULT FALSE,
    max_length    INTEGER NULL,
    regex_pattern    TEXT NULL,
    classification   TEXT NOT NULL DEFAULT 'INTERNAL'
        CONSTRAINT chk_idras_classification CHECK (classification IN (
            'PUBLIC','INTERNAL','CONFIDENTIAL','PII','SENSITIVE_PII')),
    mutability     TEXT NOT NULL DEFAULT 'READ_WRITE'
        CONSTRAINT chk_idras_mutability CHECK (mutability IN (
            'READ_ONLY','READ_WRITE','WRITE_ONLY','IMMUTABLE')),
    returned        TEXT NOT NULL DEFAULT 'DEFAULT'
        CONSTRAINT chk_idras_ret CHECK (returned IN ('ALWAYS','NEVER','DEFAULT','REQUEST')),  -- [MC-0277] → A.65.04
    display_mask    TEXT NULL,
    standard_ref    TEXT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, attr_name)
);

COMMENT ON TABLE bauth.idn_attribute_schema IS
'PIP D98 | Policy Information Point: esquema canónico de todos los atributos de identidad del
ecosistema (D98-B01). Permite que idn_identity_attribute (T-157) sea extensible sin hardcode:
cada atributo válido se define aquí con su tipo, mutabilidad, retorno, clasificación de datos
y máscara de visualización. Patrón override: tenant_id=NULL = esquema global; tenant_id NOT NULL
= override/extensión del tenant para ese atributo. classification=PII/SENSITIVE_PII activa
el field-level access control (GAP-D01-01). display_mask enmascara valores sensibles (ej: CI).
Fuente: seed de despliegue con los atributos canónicos de identidad (core, contact, professional,
verification, security, fiscal); extensiones del tenant vía RPC bauth.attribute.schema.define.
Administración: solo SUPER_ADMIN y SCHEMA_ADMIN pueden definir nuevos atributos globales.
Los tenants pueden extender (tenant_id NOT NULL) sin afectar el esquema global.
is_active=false desactiva un atributo sin borrar la FK histórica en T-157.
WORM: no — is_active y mutability son editables vía migración controlada.
Particionada: no.
Estándar: SCIM 2.0 RFC 7643 §4, ISO/IEC 24760-1:2019 §5, NIST SP 800-162 §3.3. T-500.';

-- ======================================================================
-- T-201 — bauth.idn_access_contract
-- Contrato de acceso: registro de gobernanza D01-B05.
-- ISO 27001:2022 A.9.2.2 · NIST SP 800-53 R5 AC-2 · PCI DSS 4.0 Req 7.2 · SOX §404
-- WORM parcial: campos de gobernanza inmutables una vez estado != 'DRAFT'.
-- FK inversa: privilege_atom_grant.contract_id apunta aquí (no array anti-patrón).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_access_contract (
    contract_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id            UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    access_type          TEXT NOT NULL CONSTRAINT chk_iac_access_type CHECK (access_type IN (  -- [MC-0094] → A.65.04
        'ROLE_ACCESS','ATOM_ACCESS','TEMPORAL_ACCESS','EMERGENCY_ACCESS','DELEGATED_ACCESS')),
    beneficiary_id      UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    role_id              UUID NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE SET NULL,
    id_atom              UUID NULL REFERENCES bauth.idn_roles_template(id) ON DELETE SET NULL,
    CONSTRAINT chk_iac_subject CHECK (role_id IS NOT NULL OR id_atom IS NOT NULL),
    status               TEXT NOT NULL DEFAULT 'DRAFT' CONSTRAINT chk_iac_status CHECK (status IN (  -- [MC-0095] → A.65.04
        'DRAFT','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
    business_justification TEXT NOT NULL,
    policy_ref         TEXT NULL,
    requester_id       UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    approver_id         UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    approved_at          TIMESTAMPTZ NULL,
    valid_from           TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until          TIMESTAMPTZ NULL,
    next_review_at     TIMESTAMPTZ NULL,
    reviewer_id           UUID NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,
    version_number       INTEGER NOT NULL DEFAULT 1,
    prev_hash        TEXT NULL,
    ctx_id               TEXT NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iac_tenant    ON bauth.idn_access_contract(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_iac_beneficiary  ON bauth.idn_access_contract(beneficiary_id, status);
CREATE INDEX IF NOT EXISTS idx_iac_requester   ON bauth.idn_access_contract(requester_id);
CREATE INDEX IF NOT EXISTS idx_iac_approver ON bauth.idn_access_contract(approver_id);
CREATE INDEX IF NOT EXISTS idx_iac_valid     ON bauth.idn_access_contract(valid_from, valid_until)
    WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_iac_next_review  ON bauth.idn_access_contract(next_review_at)
    WHERE next_review_at IS NOT NULL AND status = 'ACTIVE';

COMMENT ON TABLE bauth.idn_access_contract IS
'PRIVILEGIOS D01 | Contrato de acceso: registro de gobernanza que documenta QUÉ acceso se
otorgó, POR QUÉ (business_justification) y QUIÉN aprobó (approver_id ≠ requester_id — NIST AC-5
dual control). Tipos: ROLE_ACCESS, ATOM_ACCESS, TEMPORAL_ACCESS, EMERGENCY_ACCESS, DELEGATED_ACCESS.
Sujeto del acceso: role_id XOR id_atom (chk_iac_subject garantiza al menos uno definido).
Los grants en privilege_atom_grant.contract_id apuntan aquí como FK inversa (no array — anti-patrón).
WORM parcial: trigger trg_iac_protect_active bloquea edición de access_type, beneficiary_id,
requester_id, approver_id, approved_at y business_justification una vez status != DRAFT.
Fuente: creado por el Motor de Políticas (Rust) al procesar una solicitud de acceso formal;
contratos EMERGENCY_ACCESS pueden crearse en < 30s (NIST AC-2(j) revocación rápida).
Administración: requester_id ≠ approver_id siempre. Solo status y next_review_at son actualizables
post-aprobación. La revocación actualiza status=REVOKED y no borra el contrato (trazabilidad).
WORM: parcial — campos de gobernanza bloqueados por trigger post-aprobación.
Particionada: no.
Estándar: ISO 27001 A.9.2.2, NIST SP 800-53 R5 AC-2, PCI DSS 4.0 Req 7.2, SOX §404. T-201.';

CREATE OR REPLACE FUNCTION bauth.fn_iac_protect_active()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status != 'DRAFT' THEN
        IF (
            NEW.access_type              IS DISTINCT FROM OLD.access_type
            OR NEW.beneficiary_id       IS DISTINCT FROM OLD.beneficiary_id
            OR NEW.role_id               IS DISTINCT FROM OLD.role_id
            OR NEW.id_atom               IS DISTINCT FROM OLD.id_atom
            OR NEW.business_justification IS DISTINCT FROM OLD.business_justification
            OR NEW.policy_ref          IS DISTINCT FROM OLD.policy_ref
            OR NEW.requester_id        IS DISTINCT FROM OLD.requester_id
            OR NEW.approver_id          IS DISTINCT FROM OLD.approver_id
            OR NEW.approved_at           IS DISTINCT FROM OLD.approved_at
            OR NEW.valid_from            IS DISTINCT FROM OLD.valid_from
        ) THEN
            RAISE EXCEPTION
                'WORM: campos de gobernanza de contract_id=% son inmutables (status=%)',
                OLD.contract_id, OLD.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    NEW.version_number := OLD.version_number + 1;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_iac_protect_active() IS
  '[T-201] [ISO 27001 A.8.15] WORM parcial: bloquea edición de campos de gobernanza una vez
   estado != BORRADOR. Incrementa version_number en cada UPDATE para trazabilidad.';

CREATE OR REPLACE TRIGGER trg_iac_protect_active
    BEFORE UPDATE ON bauth.idn_access_contract
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_iac_protect_active();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 7 — PRIVILEGIOS (bauth)                              ║
-- ║   Grants + overrides + evaluaciones + SoD + auditoría WORM         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-170 — bauth.privilege_atom_grant
-- Grant de átomos por usuario. REPLICA IDENTITY FULL para WAL → Redis.
-- Modelo 5 columnas G-12: effect (espejo árbol) + general/local + access + reassess.
-- FK compuesta (id_atom, atom_position) garantiza coherencia con T-162 (A.65.02.01 §7).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_grant (
    id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id     UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- user_id NULL: solo para átomos tier SU/EMERGENCY cross-tenant (G-09 §corrección)
    user_id       UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    -- role_id NULL: contexto de asignación — no es FK operativa del motor BitMask
    role_id       UUID        NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE SET NULL,
    -- id_atom + atom_position: FK compuesta DEFERRABLE garantiza atom_position = el de T-162
    id_atom       UUID        NOT NULL,
    atom_position BIGINT      NOT NULL,
    -- bitmask_value: precomputado — evita JOIN a T-162 al reconstruir RolBitMask
    bitmask_value BIGINT      NOT NULL,
    -- ─── MODELO 5 COLUMNAS G-12 ───────────────────────────────────────────
    -- effect: espejo del nodo evaluacion en T-162. NUNCA editar directamente.
    --   true=PERMIT, false=DENY. Sincronizado por trg_t162_sync_effect_to_grants.
    effect        BOOLEAN     NOT NULL DEFAULT false,
    -- general: controlador de precedencia.
    --   true (default al crear) → árbol manda: effect prevalece sobre access.
    --   false → grant manda: access prevalece sobre effect.
    general       BOOLEAN     NOT NULL DEFAULT true,
    -- local: derivado de general (PostgreSQL GENERATED). Solo para legibilidad visual.
    local         BOOLEAN     GENERATED ALWAYS AS (NOT general) STORED,
    -- access: override del grant. Forzado a true por trigger cuando general=true.
    --   Editable libremente solo cuando general=false.
    access        BOOLEAN     NOT NULL DEFAULT true,
    -- reassess: elegibilidad CAEP reactiva.
    --   NULL=hereda default del tenant (idn_tier_policy). true=elegible. false=inmune.
    reassess      BOOLEAN     NULL,
    -- ──────────────────────────────────────────────────────────────────────
    grant_type    grant_type_enum   NOT NULL DEFAULT 'STANDARD',
    status        grant_status_enum NOT NULL DEFAULT 'ACTIVE',
    valid_from    TIMESTAMPTZ NULL,
    valid_until   TIMESTAMPTZ NULL,
    granted_by    UUID        NOT NULL,
    reason        TEXT,
    -- Contrato de gobernanza opcional: FK a T-201 (D01-B05, ISO 27001 A.9.2.2)
    contract_id   UUID        NULL REFERENCES bauth.idn_access_contract(contract_id) ON DELETE SET NULL,
    ctx_id        TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- FK compuesta DEFERRABLE: atom_position del grant DEBE coincidir con el de T-162 (A.65.02.01 §7)
    CONSTRAINT fk_pag_atom_position
        FOREIGN KEY (id_atom, atom_position)
        REFERENCES bauth.idn_roles_template(id, atom_position)
        DEFERRABLE INITIALLY DEFERRED,
    -- valid_until posterior a valid_from (G-07)
    CONSTRAINT chk_pag_valid_range CHECK (
        valid_from IS NULL OR valid_until IS NULL OR valid_from < valid_until
    ),
    -- Incoherencia prohibida: DENY explícito del operador + elegible para reassess (G-12 §4 fila inválida)
    CONSTRAINT chk_pag_reassess_coherencia CHECK (
        NOT (access = false AND reassess = true)
    )
);

-- REPLICA IDENTITY FULL para CDC/WAL. Idempotente: solo si no está ya configurado.
DO $$ BEGIN
    IF (SELECT relreplident FROM pg_class WHERE relname = 'privilege_atom_grant' AND relnamespace = 'bauth'::regnamespace) <> 'f' THEN
        ALTER TABLE bauth.privilege_atom_grant REPLICA IDENTITY FULL;
    END IF;
END $$;

-- Índices G-09 (4 direcciones IGA) + G-12 (reassess elegibles)
CREATE INDEX IF NOT EXISTS idx_pag_user       ON bauth.privilege_atom_grant(user_id, status);
CREATE INDEX IF NOT EXISTS idx_pag_tenant     ON bauth.privilege_atom_grant(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_pag_atom       ON bauth.privilege_atom_grant(id_atom, status);
CREATE INDEX IF NOT EXISTS idx_pag_type       ON bauth.privilege_atom_grant(grant_type, tenant_id);
-- G-09 Dirección 2: usuario → todos sus átomos activos (atom_position incluida para RolBitMask sin JOIN)
CREATE INDEX IF NOT EXISTS idx_pag_user_entitlement
    ON bauth.privilege_atom_grant(user_id, atom_position)
    WHERE access = true AND status = 'ACTIVE';
-- G-09 Dirección 3: tenant → todos sus grants activos (campaña de certificación)
CREATE INDEX IF NOT EXISTS idx_pag_tenant_sweep
    ON bauth.privilege_atom_grant(tenant_id, user_id)
    WHERE access = true AND status = 'ACTIVE';
-- G-09 Dirección 4: grants temporales próximos a vencer (NIST AC-2(6))
CREATE INDEX IF NOT EXISTS idx_pag_valid_until
    ON bauth.privilege_atom_grant(valid_until)
    WHERE valid_until IS NOT NULL AND status = 'ACTIVE';
-- G-12 §9: grants elegibles para reevaluación reactiva CAEP/risk/scheduler
CREATE INDEX IF NOT EXISTS idx_pag_reassess_eligible
    ON bauth.privilege_atom_grant(tenant_id, user_id)
    WHERE reassess = true
      AND status   = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );
-- D01-B05: trazabilidad de grant hacia contrato de gobernanza T-201
CREATE INDEX IF NOT EXISTS idx_pag_contrato
    ON bauth.privilege_atom_grant(contract_id)
    WHERE contract_id IS NOT NULL;

COMMENT ON TABLE bauth.privilege_atom_grant IS
'PRIVILEGIOS | Grant de átomos de privilegio por usuario (modelo per-user — G-09). Cada fila
es la asignación de un átomo (id_atom de T-162) a un usuario específico en un tenant.
Modelo 5 columnas G-12: effect (espejo del árbol T-162, sincronizado por trigger), general
(true=árbol manda/false=grant manda), local (NOT general, GENERATED), access (override del
grant) y reassess (elegibilidad CAEP reactiva — NULL hereda del tenant). La evaluación del
PDP consulta esta tabla: si general=true → effect decide; si general=false → access decide.
FK compuesta (id_atom, atom_position) DEFERRABLE: garantiza que atom_position del grant sea
exactamente el de T-162 al completar la transacción (coherencia atómica con el BitMask).
bitmask_value precomputado: reconstruye el RolBitMask sin JOIN a T-162 (< 0.5ns).
REPLICA IDENTITY FULL: bauth-reactor recibe todos los cambios vía WAL → Redis Streams.
Fuente: creado por el Motor de Roles al procesar un contrato de acceso (T-201) o una
solicitud directa vía RPC bauth.privilege.grant; seeds iniciales de plantilla en bootstrap.
Administración: solo el Motor de Roles puede INSERT/UPDATE; revocación actualiza status=REVOKED
o valid_until al momento actual (< 30s NIST AC-2(j)). SoD verificado por trigger en INSERT.
WORM: no — el grant es mutable (status, valid_until, access cambian a lo largo del ciclo).
Particionada: no.
Estándar: XACML 3.0 §5.29, NIST RBAC N3, ISO 27001 A.5.18, RFC 8935 (CAEP). T-170.';

COMMENT ON COLUMN bauth.privilege_atom_grant.id_atom       IS 'FK a idn_roles_template(id). Nodo DEBE ser tipo=atomo (tiene atom_position).';
COMMENT ON COLUMN bauth.privilege_atom_grant.atom_position IS 'Copia de idn_roles_template.atom_position. Garantizado por FK compuesta DEFERRABLE.';
COMMENT ON COLUMN bauth.privilege_atom_grant.bitmask_value IS 'Valor del bit en el RolBitMask. Precomputado al insertar para reconstruir BitMask sin JOIN.';
COMMENT ON COLUMN bauth.privilege_atom_grant.effect        IS '[G-12] Espejo del Effect del árbol T-162. true=PERMIT, false=DENY. NUNCA editar directamente.';
COMMENT ON COLUMN bauth.privilege_atom_grant.general       IS '[G-12] true=árbol manda (effect prevalece). false=grant manda (access prevalece). Nace true.';
COMMENT ON COLUMN bauth.privilege_atom_grant.local         IS '[G-12] Derivado: NOT general. Columna GENERATED. Solo para legibilidad visual.';
COMMENT ON COLUMN bauth.privilege_atom_grant.access        IS '[G-12] Override del grant. Forzado a true por trigger cuando general=true. Editable con general=false.';
COMMENT ON COLUMN bauth.privilege_atom_grant.reassess      IS '[G-12][RFC 8935] Elegibilidad CAEP. NULL=default tenant. true=elegible. false=inmune (break-glass).';
COMMENT ON COLUMN bauth.privilege_atom_grant.grant_type    IS '[ENUM] STANDARD=asignación normal (permanente hasta revocación), JIT=just-in-time con ventana temporal válida (valid_from/valid_until), BREAKGLASS=emergencia de acceso dual-control que requiere aprobador_id obligatorio.';
COMMENT ON COLUMN bauth.privilege_atom_grant.role_id       IS 'FK de contexto al rol conceptual de donde proviene este átomo — permite trazar de qué rol fue otorgado. NULL para átomos de asignación directa (sin rol intermediario). NO es la fuente de verdad del PDP — el PDP evalúa átomos, no roles.';
COMMENT ON COLUMN bauth.privilege_atom_grant.contract_id   IS 'FK a T-201 idn_access_contract — el contrato de gobernanza que autorizó este grant (ISO 27001 A.9.2.2). NULL para grants de bootstrap o asignaciones sin contrato formal. Permite auditar la trazabilidad de autorización: quién autorizó, qué justificación, cuándo expira el contrato.';

-- ── G-12 CAMBIO 7: Trigger — forzar access=true cuando general=true ───────────────
-- Garantiza consistencia visual: cuando el árbol manda, access=true indica
-- "no vetando nada". Previene que access=false sea un falso visual de DENY.
CREATE OR REPLACE FUNCTION bauth.fn_sync_access_to_general()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.general = true THEN
        NEW.access := true;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_sync_access_to_general() IS
  '[G-12 CAMBIO 7] Fuerza access=true cuando general=true.
   Previene access=false como falso visual de DENY cuando el árbol tiene el control.
   Invariante: access=false solo puede ocurrir cuando general=false.';

CREATE OR REPLACE TRIGGER trg_t170_sync_access_general
    BEFORE INSERT OR UPDATE ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_sync_access_to_general();

-- ── G-03: Trigger SoD — verificar conflicto en INSERT ─────────────────────────────
-- Cuando se intenta asignar un átomo a un usuario, verifica que el verbo del nuevo
-- átomo no conflictúe con verbos que el usuario ya tiene asignados y activos.
CREATE OR REPLACE FUNCTION bauth.fn_check_sod_on_grant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_verb_nuevo     TEXT;
    v_verb_existente TEXT;
    v_atom_existente TEXT;
BEGIN
    -- Solo verificar asignaciones PERMIT activas con usuario específico
    IF NEW.access = false OR NEW.user_id IS NULL OR NEW.status <> 'ACTIVE' THEN
        RETURN NEW;
    END IF;

    -- Obtener el verbo del átomo que se está asignando
    SELECT verb_id INTO v_verb_nuevo
    FROM bauth.idn_roles_template
    WHERE id = NEW.id_atom AND node_type = 'atom';

    IF v_verb_nuevo IS NULL THEN
        RETURN NEW;
    END IF;

    -- Buscar si el usuario ya tiene activo un átomo cuyo verbo conflictúe
    SELECT irt.verb_id, irt.label
    INTO v_verb_existente, v_atom_existente
    FROM bauth.privilege_atom_grant pag
    JOIN bauth.idn_roles_template irt ON irt.id = pag.id_atom
    WHERE pag.user_id   = NEW.user_id
      AND pag.tenant_id = NEW.tenant_id
      AND pag.access    = true
      AND pag.status    = 'ACTIVE'
      AND irt.node_type = 'atom'
      AND irt.verb_id IS NOT NULL
      AND EXISTS (
          SELECT 1 FROM bauth.privilege_verb_conflict pvc
          WHERE conflict_type IN ('STATIC_SOD','DYNAMIC_SOD')
            AND (
                pvc.verb_a = LEAST(v_verb_nuevo, irt.verb_id)
                AND pvc.verb_b = GREATEST(v_verb_nuevo, irt.verb_id)
            )
      )
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION
            'Violación SoD: el verbo "%" conflictúa con el verbo "%" del átomo "%" activo. '
            'Revise privilege_verb_conflict.',
            v_verb_nuevo, v_verb_existente, v_atom_existente;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_check_sod_on_grant() IS
  '[G-03] Verifica SoD en INSERT de privilege_atom_grant.
   Si el verbo del nuevo átomo conflictúa (STATIC_SOD/DINAMICO) con verbos activos
   del usuario → ROLLBACK con mensaje descriptivo. No actúa en DENY (access=false).';

CREATE OR REPLACE TRIGGER trg_t170_sod_check
    BEFORE INSERT ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_check_sod_on_grant();

-- ── G-20 D1/D2/D3: Validación de grants BREAKGLASS ────────────────────────────────────────────
-- D1: fuerza reassess=false (grants BREAKGLASS son inmunes a señales CAEP — RFC 9396).
-- D2: solo roles de tier SU o tipo EMERGENCY pueden recibir grants BREAKGLASS (NIST AC-2(2)).
-- D3: máximo 2 grants BREAKGLASS activos por tenant (1 primario + 1 respaldo).
CREATE OR REPLACE FUNCTION bauth.fn_validate_breakglass_grant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_role_tier  text;
    v_role_type  text;
    v_bg_count   int;
BEGIN
    IF NEW.grant_type::text != 'BREAKGLASS' THEN
        RETURN NEW;
    END IF;

    -- D2: verificar tier y tipo del rol
    SELECT rt.tier::text, rty.code
      INTO v_role_tier, v_role_type
      FROM bauth.idn_roles_rol_hierarchical rt
      JOIN bauth.idn_roles_rol_type         rty ON rty.type_id = rt.type_id
     WHERE rt.id = NEW.role_id;

    IF v_role_tier IS DISTINCT FROM 'SU' AND v_role_type IS DISTINCT FROM 'EMERGENCY' THEN
        RAISE EXCEPTION
            'BREAKGLASS_TIER_VIOLATION: grant BREAKGLASS solo permitido para tier SU o '
            'tipo de cuenta EMERGENCY. Rol actual — tier: %, tipo: %',
            v_role_tier, v_role_type;
    END IF;

    -- D3: máximo 2 grants BREAKGLASS activos por tenant
    SELECT COUNT(*) INTO v_bg_count
      FROM bauth.privilege_atom_grant
     WHERE tenant_id  = NEW.tenant_id
       AND grant_type::text = 'BREAKGLASS'
       AND status::text IN ('ACTIVE', 'INACTIVE')
       AND id != COALESCE(OLD.id, '00000000-0000-0000-0000-000000000000'::uuid);

    IF v_bg_count >= 2 THEN
        RAISE EXCEPTION
            'BREAKGLASS_LIMIT_EXCEEDED: el tenant ya cuenta con 2 grants BREAKGLASS activos '
            '(1 primario + 1 de respaldo). Revoque o archive un grant existente antes de crear uno nuevo.';
    END IF;

    -- D1: BREAKGLASS siempre inmune a reevaluación CAEP
    NEW.reassess := false;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_validate_breakglass_grant() IS
  '[G-20 D1/D2/D3] Valida invariantes de grants BREAKGLASS antes de INSERT/UPDATE:
   D1: fuerza reassess=false (inmune a señales CAEP — RFC 9396).
   D2: solo tier SU o tipo EMERGENCY pueden recibir grants BREAKGLASS (NIST AC-2(2)).
   D3: máximo 2 grants BREAKGLASS activos por tenant.';

CREATE OR REPLACE TRIGGER trg_validate_breakglass_grant
    BEFORE INSERT OR UPDATE OF grant_type, status
    ON bauth.privilege_atom_grant
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_validate_breakglass_grant();


-- ======================================================================
-- T-170b — bauth.privilege_atom_audit  [WORM + hash-chain pgcrypto]
-- Registro inmutable de cambios en grants. INSERT-only con hash-chain SHA-256.
-- before_row/after_row (no old_data/new_data). hash_chain BYTEA (no TEXT).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit (
    audit_id     UUID        NOT NULL DEFAULT uuidv7(),
    grant_id     UUID        NOT NULL,
    tenant_id    UUID        NOT NULL,
    user_id      UUID        NULL,
    id_atom      UUID        NOT NULL,
    operation    TEXT        NOT NULL CHECK (operation IN ('GRANTED','REVOKED','EXPIRED','MODIFIED','STEP_UP','BREAKGLASS')),
    before_row   JSONB,
    after_row    JSONB,
    performed_by UUID        NOT NULL,
    reason       TEXT,
    prev_hash    BYTEA       NULL,
    hash_chain   BYTEA       NOT NULL,
    ctx_id       TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- PK compuesta: en tablas particionadas por RANGE(created_at) el PK debe incluir la columna de partición
    CONSTRAINT privilege_atom_audit_pkey PRIMARY KEY (audit_id, created_at)
) PARTITION BY RANGE (created_at);

-- WORM: solo el rol del daemon bauth puede escribir; nadie puede borrar ni actualizar
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM bauth_app_role;

CREATE INDEX IF NOT EXISTS idx_paa_grant  ON bauth.privilege_atom_audit(grant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_paa_tenant ON bauth.privilege_atom_audit(tenant_id, created_at DESC);

COMMENT ON TABLE bauth.privilege_atom_audit IS
'PRIVILEGIOS | Registro WORM de todos los cambios en grants de átomos (T-170). Cada fila captura
la operación (GRANTED/REVOKED/EXPIRED/MODIFIED/STEP_UP/BREAKGLASS), el before_row y after_row
como JSONB, el performed_by, reason y hash_chain SHA-256 encadenado (bauth_44). Permite
reconstruir la historia completa de cualquier grant sin JOIN adicional a T-170.
Complemento de T-176 (privilege_assurance_audit): T-170b registra qué se otorgó/cambió;
T-176 registra cómo se ejerció en cada request en runtime.
Fuente: creado exclusivamente por el trigger trg_t170_worm (G-01) en cada INSERT/UPDATE de T-170;
nunca por INSERT directo. Particionada mensual — job mensual crea partición del mes siguiente.
Administración: REVOKE UPDATE/DELETE desde PUBLIC y bauth_app_role. Solo el trigger puede escribir.
hash_chain = SHA-256(prev_hash||grant_id||operation||after_row||created_at), calculado en TX.
WORM: sí — REVOKE UPDATE/DELETE aplicado; hash-chain por grant_id.
Particionada: sí — PARTITION BY RANGE (created_at), granularidad mensual.
Estándar: ISO 27001 A.8.15, NIST SP 800-53 AU-9. T-170b.';

-- Particiones iniciales (3 meses)
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit_2026_07
    PARTITION OF bauth.privilege_atom_audit
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit_2026_08
    PARTITION OF bauth.privilege_atom_audit
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit_2026_09
    PARTITION OF bauth.privilege_atom_audit
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

-- Trigger WORM: poblar T-170b en cada cambio de T-170 con hash-chain SHA-256
-- Requiere extensión pgcrypto (CREATE EXTENSION IF NOT EXISTS pgcrypto).
CREATE OR REPLACE FUNCTION bauth.fn_worm_append()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_prev_hash  BYTEA;
    v_new_hash   BYTEA;
    v_after_row  JSONB;
    v_before_row JSONB;
    v_operation  TEXT;
BEGIN
    -- Determinar la operación
    IF TG_OP = 'INSERT' THEN
        v_operation  := 'GRANTED';
        v_before_row := NULL;
        v_after_row  := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_operation  := 'MODIFIED';
        IF NEW.status = 'REVOKED' THEN v_operation := 'REVOKED';
        ELSIF NEW.status = 'EXPIRED' THEN v_operation := 'EXPIRED';
        END IF;
        v_before_row := to_jsonb(OLD);
        v_after_row  := to_jsonb(NEW);
    END IF;

    -- Obtener el hash de la fila anterior del mismo grant (enlace de cadena)
    SELECT hash_chain INTO v_prev_hash
    FROM bauth.privilege_atom_audit
    WHERE grant_id = NEW.id
    ORDER BY created_at DESC
    LIMIT 1;

    -- Calcular hash_chain = SHA-256(prev_hash || grant_id || operation || after_row || now())
    v_new_hash := digest(
        COALESCE(v_prev_hash, ''::bytea)
        || NEW.id::text::bytea
        || v_operation::bytea
        || COALESCE(v_after_row::text, '')::bytea
        || now()::text::bytea,
        'sha256'
    );

    -- Bloqueo advisory por grant: serializa escrituras concurrentes del mismo grant
    PERFORM pg_advisory_xact_lock(hashtext(NEW.id::text));

    INSERT INTO bauth.privilege_atom_audit (
        grant_id, tenant_id, user_id, id_atom,
        operation, before_row, after_row,
        performed_by, reason, prev_hash, hash_chain, ctx_id
    ) VALUES (
        NEW.id, NEW.tenant_id, NEW.user_id, NEW.id_atom,
        v_operation, v_before_row, v_after_row,
        NEW.granted_by, NEW.reason, v_prev_hash, v_new_hash, NEW.ctx_id
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_worm_append() IS
  '[G-01] Trigger WORM para privilege_atom_grant → privilege_atom_audit.
   Calcula hash_chain = SHA-256(prev_hash||grant_id||operation||after_row||now()).
   pg_advisory_xact_lock serializa escrituras concurrentes del mismo grant.
   Si la transacción hace ROLLBACK, el audit también — nunca quedan desincronizados.';

CREATE OR REPLACE TRIGGER trg_t170_worm
    AFTER INSERT OR UPDATE ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_worm_append();


-- ======================================================================
-- T-171 — bauth.privilege_resource_atom  [PAP para Kong PEP]
-- Mapeo (protocol_type + resource + operation) → id_atom por tenant.
-- Kong carga esta tabla al arrancar. G-04: columna obligation JSONB NULL.
-- G-06: tenant_id NOT NULL — el mismo endpoint puede mapear a átomos distintos por tenant.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_resource_atom (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- tenant_id NOT NULL (G-06): mapeo per-tenant — cada tenant tiene su árbol T-162 propio.
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    protocol_type TEXT        NOT NULL,   -- WS_RPC / JSON_RPC / GRPC / UNIX_SOCKET / HTTP_EXT
    resource        TEXT        NOT NULL,   -- Ej: "bauth.token.validate", "/api/v1/auth"
    operation      TEXT        NOT NULL,   -- Ej: nombre del método, verbo HTTP
    id_atom        UUID        NOT NULL REFERENCES bauth.idn_roles_template(id) ON DELETE RESTRICT,
    domain_code    SMALLINT    NOT NULL,   -- D01-D37: determina FastPath o PolicyPath en Kong
    evaluation_path TEXT       NOT NULL,   -- FAST / POLICY / EXTERNAL / PRECONDITION
    tenant_scope   TEXT        NOT NULL DEFAULT 'TENANT_SPECIFIC',
    status         TEXT        NOT NULL DEFAULT 'ACTIVE',
    -- G-04: obligación de contexto. NULL=sin obligación (bit=1 suficiente).
    -- NOT NULL=Kong verifica required_loa contra sesión activa ANTES de conceder acceso.
    -- Estructura válida: {"required_loa": "AAL1"|"AAL2"|"AAL3"}
    obligation     JSONB       NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- G-04: validación del schema de obligation
    CONSTRAINT chk_pra_obligation_schema CHECK (
        obligation IS NULL
        OR (
            jsonb_typeof(obligation) = 'object'
            AND obligation ? 'required_loa'
            AND (obligation->>'required_loa') IN ('AAL1','AAL2','AAL3')
        )
    ),
    CONSTRAINT chk_pra_protocol_type CHECK (
        protocol_type IN ('WS_RPC','JSON_RPC','GRPC','UNIX_SOCKET','HTTP_EXT')
    ),
    CONSTRAINT chk_pra_eval_path CHECK (  -- [MC-0238] → A.65.04
        evaluation_path IN ('FAST','POLICY','EXTERNAL','PRECONDITION')
    ),
    CONSTRAINT chk_pra_tenant_scope CHECK (  -- [MC-0240] → A.65.04
        tenant_scope IN ('GLOBAL','TENANT_SPECIFIC')
    ),
    CONSTRAINT chk_pra_status CHECK (status IN ('ACTIVE','INACTIVE','DEPRECATED')),  -- [MC-0239] → A.65.04
    -- G-06: unicidad per-tenant — el mismo resource+operación puede existir en dos tenants
    CONSTRAINT uq_pra_tenant_resource UNIQUE (tenant_id, protocol_type, resource, operation)
);

CREATE INDEX IF NOT EXISTS idx_pra_tenant   ON bauth.privilege_resource_atom(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_pra_atom     ON bauth.privilege_resource_atom(id_atom);
CREATE INDEX IF NOT EXISTS idx_pra_domain   ON bauth.privilege_resource_atom(domain_code, evaluation_path);

COMMENT ON TABLE bauth.privilege_resource_atom IS
'PRIVILEGIOS | PAP (Policy Administration Point) para Kong PEP: resuelve la tupla
(protocol_type, resource, operation) → id_atom de T-162 sin consultar bAuth en runtime.
Permite a Kong decidir PERMIT/DENY/STEP_UP evaluando solo el BitMask del usuario en Redis +
el obligation (LoA requerida) de esta tabla. domain_code determina el camino de evaluación:
D01-D12 → FastPath (< 0.5ns, solo BitMask). D13-D37 → PolicyPath (consulta bAuth PDP).
obligation NOT NULL → Kong verifica current_loa de la sesión Redis ANTES de PERMIT (RFC 9470).
Sin mapeo en esta tabla = DENY por defecto (sin política explícita = denegado — NIST SP 800-207).
Fuente: seed de despliegue con los endpoints canónicos de cada daemon; altas nuevas vía
migración DDL con HITL (añadir un endpoint sin autorización es una brecha de seguridad).
Administración: Kong carga esta tabla al arrancar y la recarga vía evento CAEP catalog_change
sobre Unix socket (sin reinicio). Cambios en id_atom requieren revisión de impacto en BitMask.
WORM: no — status y obligation son actualizables para gestión de ciclo de vida del endpoint.
Particionada: no.
Estándar: XACML 3.0 PAP, NIST SP 800-207 §3.3, RFC 9470, ISO 27001 A.5.15. T-171.';

COMMENT ON COLUMN bauth.privilege_resource_atom.obligation IS
  '[G-04] NULL=bit=1 en JWT suficiente. NOT NULL=Kong evalúa LoA antes de PERMIT.
   Estructura: {"required_loa": "AAL1"|"AAL2"|"AAL3"}. Ver SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md.';


-- ======================================================================
-- T-172 — bauth.privilege_delegation
-- Registro de auditoría de asignaciones de rol temporal. G-08.
-- SOLO AUDITORÍA — la validación real vive en T-170 (grants) y merge_roles Rust.
-- Responde: "¿por qué tiene este usuario este rol temporal y quién lo autorizó?"
-- [NIST SP 800-53 AC-2] [ISO 27001 A.8.2] [A.65.02.01 §6.5]
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_delegation (
    id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- Delegación siempre dentro de un tenant (G-06)
    tenant_id    UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Rol auxiliar asignado temporalmente (mismo tier o adyacente en el catálogo)
    role_id      UUID        NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE RESTRICT,
    -- Usuario que recibe la asignación temporal
    assignee_id  UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    -- Admin que autorizó — trazabilidad de quién tomó la decisión
    assigned_by  UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- Justificación obligatoria: sin motivo no hay asignación válida
    reason       TEXT        NOT NULL,
    -- Período informativo: la vigencia real está en los átomos del rol en T-170
    valid_from   TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until  TIMESTAMPTZ NOT NULL,
    status       TEXT        NOT NULL DEFAULT 'ACTIVE',
    ctx_id       TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_pd_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),  -- [MC-0235] → A.65.04
    CONSTRAINT chk_pd_valid  CHECK (valid_from < valid_until)
);

-- Consultas por usuario: "¿qué asignaciones temporales tiene activas este usuario?"
CREATE INDEX IF NOT EXISTS idx_pd_assignee
    ON bauth.privilege_delegation (assignee_id, tenant_id)
    WHERE status = 'ACTIVE';

-- Job de expiración: asignaciones próximas a vencer
CREATE INDEX IF NOT EXISTS idx_pd_valid_until
    ON bauth.privilege_delegation (valid_until)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.privilege_delegation IS
'PRIVILEGIOS D10 | Registro de auditoría de asignaciones de rol temporal entre usuarios.
SOLO AUDITORÍA — no contiene validaciones: las validaciones de acceso viven en T-170
(privilege_atom_grant) y en merge_roles Rust. La vigencia real de los átomos está en los
grants de T-170; valid_from/valid_until aquí son solo referencia documental.
Responde: "¿por qué tiene este usuario ese rol temporal y quién lo autorizó?". role_id,
assignee_id, assigned_by, reason, valid_from, valid_until y status son todos obligatorios.
Flujo atómico: INSERT privilege_delegation + INSERT privilege_atom_grant en una sola TX.
Fuente: creado por el Motor de Privilegios (Rust) al procesar una solicitud de delegación;
nunca por INSERT directo del usuario. El job de expiración actualiza status=EXPIRED cuando
valid_until < now() y revoca los grants correspondientes en T-170.
Administración: solo ROLE_ADMIN y superior pueden crear delegaciones; assigned_by es el admin
que tomó la decisión y queda como responsable de la delegación.
WORM: no — status puede actualizarse a EXPIRED o REVOKED por el reconcile loop.
Particionada: no.
Estándar: NIST SP 800-53 AC-2, ISO 27001 A.8.2, NIST AC-6(7). T-172.';


-- ======================================================================
-- T-173 — bauth.privilege_override
-- Excepciones DENY→PERMIT (o PERMIT→DENY) con quórum de aprobación.
-- Para emergencias documentadas — no para gestión ordinaria de accesos.
-- [A.65.02.01 §6.6] [ISO 27001 A.8.2] [NIST SP 800-53 AC-5]
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_override (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- Override siempre dentro de un tenant (G-06)
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Átomo sobre el que aplica el override — FK compuesta con T-162
    id_atom        UUID        NOT NULL,
    atom_position  BIGINT      NOT NULL,
    -- Usuario afectado por el override
    user_id        UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    -- DENY_TO_PERMIT: acceso excepcional temporal | PERMIT_TO_DENY: bloqueo temporal (ej: incidente)
    override_type  TEXT        NOT NULL,
    -- Aprobador con autoridad registrada (quórum mínimo = 1)
    approver_id    UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- Justificación obligatoria — trazabilidad forense ISO 27001
    reason         TEXT        NOT NULL,
    -- Referencia cruzada al evento de auditoría de la aprobación
    audit_event_id UUID        NULL,
    -- Override siempre temporal — el acceso de emergencia no puede ser indefinido
    valid_from     TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until    TIMESTAMPTZ NOT NULL,
    status         TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_by     TEXT        NOT NULL,
    ctx_id         TEXT        NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- FK compuesta deferida: garantiza que el override referencia un átomo existente con posición
    CONSTRAINT fk_po_atom_position
        FOREIGN KEY (id_atom, atom_position)
        REFERENCES bauth.idn_roles_template(id, atom_position)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_po_status        CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_po_valid         CHECK (valid_from < valid_until),
    CONSTRAINT chk_po_override_type CHECK (override_type IN ('DENY_TO_PERMIT','PERMIT_TO_DENY'))  -- [MC-0237] → A.65.04
);

-- Un solo override activo del mismo tipo por (tenant, átomo, usuario)
CREATE UNIQUE INDEX IF NOT EXISTS uq_po_active_override
    ON bauth.privilege_override (tenant_id, id_atom, user_id, override_type)
    WHERE status = 'ACTIVE';

-- Consultas por usuario: "¿qué overrides activos tiene este usuario?"
CREATE INDEX IF NOT EXISTS idx_po_user
    ON bauth.privilege_override (user_id, tenant_id)
    WHERE status = 'ACTIVE';

-- Job de expiración: overrides próximos a vencer
CREATE INDEX IF NOT EXISTS idx_po_valid_until
    ON bauth.privilege_override (valid_until)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.privilege_override IS
'PRIVILEGIOS | Excepciones de acceso temporales aprobadas con quórum para situaciones que
requieren desviarse de la política normal. Dos tipos: DENY_TO_PERMIT (el usuario tenía DENY
o sin grant — se le concede acceso excepcional temporal) y PERMIT_TO_DENY (el usuario tenía
PERMIT — se le bloquea por un incidente de seguridad o sanción temporal). FK compuesta
(id_atom, atom_position) DEFERRABLE garantiza coherencia con el átomo en T-162. UNIQUE
parcial impide más de un override activo del mismo tipo por (tenant, átomo, usuario).
Fuente: creado por el Motor de Privilegios (Rust) al procesar una solicitud de excepción
aprobada por HITL; nunca por INSERT directo del usuario. approver_id es el autorizador.
Administración: requiere aprobación formal documentada en T-179 (privilege_exception_record).
El job diario actualiza status=EXPIRED cuando valid_until < now() y revoca el override.
WORM: no — status puede actualizarse (EXPIRED/REVOKED); valid_until no cambia post-creación.
Particionada: no.
Estándar: ISO 27001 A.8.2, NIST SP 800-53 AC-5, NIST AC-2(7). T-173.';


-- ======================================================================
-- T-176 — bauth.privilege_assurance_audit
-- Auditoría de evaluaciones de obligación LoA realizadas por Kong (PEP).
-- Esta tabla NO la escribe bAuth. Kong inserta una fila por cada request
-- cuyo resource en T-171 tenga obligation IS NOT NULL.
-- [G-04] [RFC 9470] [NIST SP 800-63B-4] [A.65.02.01 §DDL-T-176]
-- ======================================================================
-- Separación de responsabilidades respecto a T-170b (privilege_atom_audit):
--   T-170b audita QUÉ SE OTORGÓ y cuándo cambió el grant (bAuth escribe).
--   T-176 audita CÓMO SE EJERCIÓ lo otorgado en runtime (Kong escribe).
-- Volumen: crece con cada request evaluado → candidata a particionamiento por fecha.
CREATE TABLE IF NOT EXISTS bauth.privilege_assurance_audit (
    id             UUID        NOT NULL DEFAULT uuidv7(),
    -- Grant que se está evaluando — correlación con T-170 y T-170b en forensia
    grant_id       UUID        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    -- Identificador del resource protegido (ruta, endpoint, objeto)
    resource_id    TEXT        NOT NULL,
    -- LoA exigido por la obligación del resource (T-171.obligation)
    required_loa   TEXT        NOT NULL CHECK (required_loa IN ('AAL1','AAL2','AAL3')),
    -- LoA que presentó la sesión activa del usuario (desde Redis, no del JWT)
    presented_loa  TEXT        NOT NULL CHECK (presented_loa IN ('AAL1','AAL2','AAL3')),
    -- Resultado de la evaluación (RFC 9470 step-up)
    outcome        TEXT        NOT NULL CHECK (outcome IN ('PERMIT','STEP_UP_REQUIRED','DENIED')),
    -- Sesión activa donde ocurrió la evaluación
    session_id     UUID        NOT NULL,
    -- Componente que evaluó (PEP de Kong por defecto)
    evaluated_by   TEXT        NOT NULL DEFAULT 'kong-pep',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT privilege_assurance_audit_pkey PRIMARY KEY (id)
);

-- Índice por grant_id: correlacionar con T-170 y T-170b en forensia
CREATE INDEX IF NOT EXISTS idx_priv_assurance_grant ON bauth.privilege_assurance_audit (grant_id);
-- Índice por session_id: reconstruir timeline de step-up de una sesión
CREATE INDEX IF NOT EXISTS idx_paa_session ON bauth.privilege_assurance_audit (session_id);
-- Índice por fecha: soportar particionamiento y retención
CREATE INDEX IF NOT EXISTS idx_paa_created ON bauth.privilege_assurance_audit (created_at);

-- Kong solo inserta — no puede modificar ni borrar registros de auditoría
REVOKE UPDATE, DELETE ON bauth.privilege_assurance_audit FROM bauth_app_role;

COMMENT ON TABLE bauth.privilege_assurance_audit IS
'PRIVILEGIOS | Auditoría de evaluaciones de obligación LoA realizadas por Kong PEP. Cada
fila es una evaluación: el grant_id que se está ejerciendo, el resource_id protegido,
required_loa (de T-171.obligation), presented_loa (de la sesión Redis, no del JWT),
outcome (PERMIT/STEP_UP_REQUIRED/DENIED) y la sesión donde ocurrió.
Complemento de T-170b: T-170b registra QUÉ se otorgó/cambió; T-176 registra CÓMO se
ejerció cada grant en runtime. Crece con cada request evaluado → distinto ciclo de retención.
Fuente: creada por Kong PEP en cada request cuyo resource en T-171 tenga obligation IS NOT NULL;
nunca por bAuth directamente.
Administración: REVOKE UPDATE/DELETE desde bauth_app_role — Kong solo puede insertar.
La evaluación de LoA usa current_loa desde Redis (keyed por session_id), nunca desde el JWT.
WORM: semi-WORM — REVOKE UPDATE/DELETE aplicado.
Particionada: no (candidata a PARTITION BY RANGE created_at por alta volumetría).
Estándar: RFC 9470 (Step-Up Auth), NIST SP 800-63B-4, ISO 27001 A.8.15. T-176.';


-- ======================================================================
-- T-179 — bauth.privilege_exception_record
-- Gobernanza de excepciones a políticas. Documenta el CONTEXTO de aprobación
-- detrás de un override en T-173. El trigger SoD en T-170 consulta esta tabla
-- antes de rechazar — si hay excepción activa para (usuario, átomo), permite el grant.
-- [A.65.02 T-179] [G-14] [ISO 27001 A.8.2] [NIST SP 800-53 AC-5]
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_exception_record (
    id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Override que motivó esta excepción (opcional: puede no haber un T-173 asociado)
    override_id     UUID        NULL REFERENCES bauth.privilege_override(id),
    -- Grant temporal beneficiado por la excepción
    grant_id        UUID        NULL REFERENCES bauth.privilege_atom_grant(id),
    -- Política violada: nombre descriptivo de la regla que se está exceptuando
    policy_violated TEXT        NOT NULL,
    -- Tipo de excepción
    exception_type  TEXT        NOT NULL,
    -- Justificación de negocio real (mínimo 50 chars — garantiza que no es texto vacío)
    business_reason TEXT        NOT NULL,
    -- Aprobador con autoridad registrada
    approved_by     UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    approved_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Fecha de expiración obligatoria — no hay excepciones permanentes
    valid_until     TIMESTAMPTZ NOT NULL,
    -- Fecha de revisión intermedia (≤ valid_until)
    review_at       TIMESTAMPTZ NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    revoked_at      TIMESTAMPTZ NULL,
    revoked_by      UUID        NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT chk_per_type   CHECK (exception_type IN ('SOD_EXCEPTION','TIER_EXCEPTION','SCOPE_EXCEPTION','OTHER')),  -- [MC-0236] → A.65.04
    CONSTRAINT chk_per_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_per_dates  CHECK (valid_until > approved_at AND review_at <= valid_until),
    CONSTRAINT chk_per_reason CHECK (length(business_reason) >= 50)
);

-- Consulta principal del trigger SoD: excepciones activas por tenant
CREATE INDEX IF NOT EXISTS idx_per_tenant_active
    ON bauth.privilege_exception_record (tenant_id, valid_until)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.privilege_exception_record IS
'PRIVILEGIOS | Registro de gobernanza de excepciones a políticas (D01 excepción formal).
Documenta el CONTEXTO de aprobación detrás de un override en T-173: qué política se violó
(policy_violated), el tipo de excepción (SOD_EXCEPTION/TIER_EXCEPTION/SCOPE_EXCEPTION/OTHER),
la justificación de negocio (≥ 50 chars obligatorios — evita textos vacíos), el aprobador
y las fechas de vigencia y revisión. ISO 27001 exige toda excepción documentada con aprobación.
El trigger SoD en T-170 (fn_check_sod_on_grant) consulta esta tabla ANTES de rechazar un
INSERT por conflicto SoD: si hay excepción activa para (usuario, átomo, tipo), permite el grant.
Fuente: creada por el Motor de Privilegios al aprobar una excepción SoD mediante HITL;
nunca por INSERT directo del usuario. override_id y grant_id son referencias opcionales.
Administración: solo SUPER_ADMIN puede crear excepciones SOD_EXCEPTION; los demás tipos
requieren TENANT_ADMIN con justificación. Job diario expira y revoca en T-173 cuando due.
WORM: no — status puede actualizarse (EXPIRED/REVOKED por el reconcile loop).
Particionada: no.
Estándar: ISO 27001 A.8.2, NIST SP 800-53 AC-5, PCI DSS 7.2.4. T-179.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 8 — SESIÓN (bauth)                                   ║
-- ║   ses_session_log + ses_caep_event_log + ses_ssf_stream             ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-181 — bauth.ses_session_log
-- Esqueleto persistente mínimo de sesión en PostgreSQL para forensia.
-- Redis es el store de sesión activa. Esta tabla complementa con historia
-- que sobrevive a reinicios y failovers. NIST SP 800-53 AU-12.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.ses_session_log (
    session_id          UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    user_id             UUID        NOT NULL,
    auth_method         TEXT        NOT NULL,
    loa_initial         TEXT        NOT NULL,
    loa_peak            TEXT        NOT NULL,
    ip_address          INET        NULL,
    user_agent          TEXT        NULL,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_active_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    terminated_at       TIMESTAMPTZ NULL,
    termination_reason  TEXT        NULL,
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT ses_session_log_pkey PRIMARY KEY (session_id),
    CONSTRAINT chk_ssl_loa_i  CHECK (loa_initial IN ('AAL1','AAL2','AAL3')),
    CONSTRAINT chk_ssl_loa_p  CHECK (loa_peak    IN ('AAL1','AAL2','AAL3')),
    CONSTRAINT chk_ssl_reason CHECK (  -- [MC-0245] → A.65.04
        termination_reason IS NULL
        OR termination_reason IN ('LOGOUT','TIMEOUT','CAEP_REVOKE','ADMIN_REVOKE','EXPIRY')
    )
);

CREATE INDEX IF NOT EXISTS idx_ssl_user_tenant ON bauth.ses_session_log (user_id, tenant_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_ssl_active      ON bauth.ses_session_log (tenant_id, last_active_at)
    WHERE terminated_at IS NULL;

COMMENT ON TABLE bauth.ses_session_log IS
'SESIÓN | Esqueleto persistente mínimo de sesión para forensia post-incidente y cumplimiento.
Redis es la fuente de autoridad de sesión activa (< 1ms). Esta tabla complementa Redis con
historia que sobrevive reinicios y failovers. Captura: user_id, tenant_id, auth_method,
loa_initial (LoA al inicio de la sesión), loa_peak (LoA máximo alcanzado por step-up RFC 9470),
ip_address, user_agent, started_at, last_active_at y termination_reason.
termination_reason=CAEP_REVOKE: escrito por el daemon cuando el CAEP receiver procesa el
evento session-revoked — conecta el evento CAEP con la sesión terminada para forensia.
Fuente: creada por el Motor de Sesiones (Rust) al iniciar una sesión autenticada; actualizada
en cada step-up y al terminar. Nunca por INSERT directo del usuario.
Administración: solo el Motor de Sesiones puede escribir. Auditoría IGA puede leer.
La sesión en Redis y el esqueleto en esta tabla se crean en la misma TX (ACID).
WORM: no — last_active_at, loa_peak y terminated_at se actualizan durante la sesión.
Particionada: no (candidata por started_at si el volumen de sesiones es muy alto).
Estándar: NIST SP 800-63B-4 §7, NIST SP 800-53 AU-12, ISO 27001 A.8.15, PCI DSS Req 10.2.1. T-181.';
COMMENT ON COLUMN bauth.ses_session_log.loa_initial        IS 'Level of Assurance al inicio de la sesión — refleja el AAL del método de autenticación usado para abrirla (AAL1/AAL2/AAL3). Immutable: fijado al crear la sesión y no cambia aunque haya step-up posterior.';
COMMENT ON COLUMN bauth.ses_session_log.loa_peak           IS 'LoA máximo alcanzado durante la sesión tras step-up (RFC 9470). Inicia igual a loa_initial; el Motor de Sesiones lo actualiza si el usuario completa un step-up exitoso. El PDP puede requerir loa_peak=AAL3 para operaciones críticas.';
COMMENT ON COLUMN bauth.ses_session_log.termination_reason IS 'Razón de fin de sesión: USER_LOGOUT (cierre voluntario), ADMIN_REVOKE (cierre administrativo), TIMEOUT (inactividad), CAEP_REVOKE (señal de revocación CAEP recibida), STEP_UP_FAILED (fallo de elevación forzada), CONCURRENT_LIMIT (límite de sesiones concurrentes superado).';
COMMENT ON COLUMN bauth.ses_session_log.auth_method        IS 'Código del método de autenticación usado para iniciar la sesión — corresponde a un código de T-335 auth_method (ej. WEBAUTHN_PASSWORDLESS, TOTP). Determina el loa_initial. El step-up posterior no cambia este campo.';


-- ======================================================================
-- T-191 — bauth.ses_caep_event_log
-- Log WORM de eventos CAEP entrantes. Append-only. RFC 8935 + RFC 9493.
-- Conecta evento → acción PDP vía grants_affected[].
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.ses_caep_event_log (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    event_type          TEXT        NOT NULL,
    subject_id          TEXT        NOT NULL,
    subject_type        TEXT        NOT NULL,
    transmitter_id      TEXT        NOT NULL,
    received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at        TIMESTAMPTZ NULL,
    processing_status   TEXT        NOT NULL DEFAULT 'RECEIVED',
    event_payload       JSONB       NOT NULL,
    grants_affected     UUID[]      NULL,
    error_message       TEXT        NULL,
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT ses_caep_event_log_pkey PRIMARY KEY (id),
    CONSTRAINT chk_scel_event_type CHECK (  -- [MC-0243] → A.65.04
        event_type IN (
            'session-revoked','token-claims-change','credential-change',
            'assurance-level-change','device-compliance-change','risk-level-change'
        )
    ),
    CONSTRAINT chk_scel_subject_type CHECK (  -- [MC-0244] → A.65.04
        subject_type IN ('session','user','device','token','oauth_client')
    ),
    CONSTRAINT chk_scel_status CHECK (
        processing_status IN ('RECEIVED','PROCESSING','APPLIED','FAILED','IGNORED')
    )
);

CREATE INDEX IF NOT EXISTS idx_scel_received ON bauth.ses_caep_event_log (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_scel_pending  ON bauth.ses_caep_event_log (processing_status)
    WHERE processing_status IN ('RECEIVED','PROCESSING','FAILED');
CREATE INDEX IF NOT EXISTS idx_scel_subject  ON bauth.ses_caep_event_log (subject_id, event_type);

REVOKE UPDATE, DELETE ON bauth.ses_caep_event_log FROM bauth_app_role;

COMMENT ON TABLE bauth.ses_caep_event_log IS
'SESIÓN | Log WORM append-only de cada evento CAEP recibido por el receptor bAuth (SSF Receiver).
Captura: event_type (session-revoked, credential-change, risk-level-change, etc.), subject_id,
transmitter_id, event_payload completo, processing_status (RECEIVED→PROCESSING→APPLIED/FAILED/IGNORED)
y grants_affected (UUIDs de T-170 suspendidos/revocados como consecuencia del evento).
grants_affected conecta la señal de revocación externa con la acción concreta del PDP —
sin esta columna sería imposible forensiar qué grants fueron afectados por una señal CAEP.
Fuente: creada por el CAEP Receiver (Rust) al recibir un JWT de evento sobre Unix socket;
nunca por INSERT directo. El procesador async lee events con idx_scel_pending.
Administración: REVOKE UPDATE/DELETE — solo el CAEP Receiver puede insertar. El Motor de Políticas
actualiza processing_status al procesar (RECEIVED → APPLIED/FAILED). processed_at se llena al procesar.
WORM: sí — REVOKE UPDATE/DELETE aplicado desde bauth_app_role.
Particionada: no (candidata por received_at si el volumen de eventos CAEP es alto).
Estándar: RFC 8935, RFC 9493 (CAEP), NIST SP 800-53 AU-12, ISO 27001 A.8.15. T-191.';
COMMENT ON COLUMN bauth.ses_caep_event_log.grants_affected  IS 'Array de UUIDs de T-170 privilege_atom_grant suspendidos o revocados como consecuencia de este evento CAEP. NULL mientras el evento está en estado RECEIVED/PROCESSING. Permite auditar qué accesos concretos fueron impactados por cada señal de revocación externa.';
COMMENT ON COLUMN bauth.ses_caep_event_log.processing_status IS 'Estado del procesamiento del evento por el Motor de Políticas: RECEIVED (recibido, en cola), PROCESSING (siendo evaluado), APPLIED (política aplicada — acción tomada), FAILED (error en procesamiento — event en cola de reintentos), IGNORED (evento recibido pero ninguna política T-180 aplicó).';


-- ======================================================================
-- T-192 — bauth.ses_ssf_stream
-- Configuración de streams SSF para transmisión de eventos CAEP.
-- bAuth actúa como SSF Transmitter. Config editable en runtime (no TOML hardcodeado).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.ses_ssf_stream (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    receiver_name       TEXT        NOT NULL,
    receiver_endpoint   TEXT        NOT NULL,
    delivery_method     TEXT        NOT NULL DEFAULT 'PUSH',
    event_types         TEXT[]      NOT NULL,
    auth_vault_path     TEXT        NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_delivered_at   TIMESTAMPTZ NULL,
    error_count         INTEGER     NOT NULL DEFAULT 0,
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT ses_ssf_stream_pkey PRIMARY KEY (id),
    CONSTRAINT chk_sss_delivery CHECK (delivery_method IN ('PUSH','POLL')),
    CONSTRAINT chk_sss_status   CHECK (status IN ('ACTIVE','PAUSED','TERMINATED','ERROR'))  -- [MC-0246] → A.65.04
);

COMMENT ON TABLE bauth.ses_ssf_stream IS
'SESIÓN | Configuración de streams SSF (Shared Signals Framework) para transmisión de eventos
CAEP a receivers externos. bAuth actúa como SSF Transmitter: publica eventos de sesión,
credencial y riesgo a SIEM (Wazuh), Kong PEP y otros receptores configurados aquí.
Campos clave: receiver_endpoint (URL/socket del receptor), delivery_method (PUSH/POLL),
event_types (filtro de tipos de evento), auth_vault_path (ruta en Vault del token — nunca el
valor directamente en la BD), error_count y last_delivered_at para diagnóstico operativo.
Fuente: creado por HITL al registrar un nuevo receptor SSF (SIEM, Kong); el daemon carga
esta tabla al arrancar y recarga vía evento CAEP catalog_change sobre Unix socket.
Administración: solo SUPER_ADMIN puede crear/eliminar streams. El daemon bAuth es el
único writer de last_delivered_at y error_count. Permite agregar un receptor sin recompilar.
WORM: no — status, error_count y last_delivered_at son actualizables operacionalmente.
Particionada: no.
Estándar: OpenID SSF 1.0 Final, CAEP 1.0 §3, RFC 8935. T-192.';

-- ======================================================================
-- T-193 — bauth.ses_ssf_delivery_log
-- Log WORM de intentos de entrega por stream SSF. Append-only.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.ses_ssf_delivery_log (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    stream_id       UUID        NOT NULL REFERENCES bauth.ses_ssf_stream(id),
    caep_event_id   UUID        NULL,
    event_type      TEXT        NOT NULL,
    delivered_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivery_status TEXT        NOT NULL,
    http_status     INTEGER     NULL,
    retry_count     INTEGER     NOT NULL DEFAULT 0,
    error_message   TEXT        NULL,
    CONSTRAINT ses_ssf_delivery_log_pkey PRIMARY KEY (id),
    CONSTRAINT chk_ssdl_status CHECK (
        delivery_status IN ('SUCCESS','FAILED','RETRYING','ABANDONED')
    )
);

CREATE INDEX IF NOT EXISTS idx_ssdl_stream
    ON bauth.ses_ssf_delivery_log (stream_id, delivery_status, delivered_at DESC);
CREATE INDEX IF NOT EXISTS idx_ssdl_failing
    ON bauth.ses_ssf_delivery_log (stream_id)
    WHERE delivery_status IN ('FAILED','RETRYING');

REVOKE UPDATE, DELETE ON bauth.ses_ssf_delivery_log FROM bauth_app_role;

COMMENT ON TABLE bauth.ses_ssf_delivery_log IS
'SESIÓN | Log WORM append-only de cada intento de entrega de un evento CAEP a un stream SSF
(T-192). Una fila por intento: stream_id, caep_event_id (FK al evento original en T-191),
event_type, delivered_at, delivery_status (SUCCESS/FAILED/RETRYING/ABANDONED), http_status
y retry_count. retry_count alto + FAILED indica un receiver caído o con credenciales incorrectas.
ABANDONED: el evento superó el máximo de reintentos — operador debe investigar.
Fuente: creada por el SSF Transmitter (bAuth, Rust) en cada intento de entrega; nunca por
INSERT directo del usuario. El job de reintentos lee idx_ssdl_failing con backoff exponencial.
Administración: REVOKE UPDATE/DELETE — solo el SSF Transmitter puede insertar. El administrador
puede leer para diagnosticar fallos; idx_ssdl_failing alimenta el dashboard de streams.
WORM: sí — REVOKE UPDATE/DELETE aplicado.
Particionada: no (candidata por delivered_at si el volumen de entregas es muy alto).
Estándar: OpenID SSF 1.0 Final, RFC 8935. T-193.';




-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 9 — AUDITORÍA ACCESS REVIEW (bauth)                 ║
-- ║   Campañas de revisión periódica de accesos (certification)        ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-177 — bauth.aud_certification_campaign
-- Cabecera de campaña de certificación de accesos IGA.
-- WORM: INSERT only en producción; cierre → status='COMPLETED'.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.aud_certification_campaign (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    campaign_type   TEXT        NOT NULL,
    scope_type      TEXT        NOT NULL,
    scope_id        UUID        NULL,
    initiated_by    UUID        NOT NULL,
    description     TEXT        NULL,
    due_date        TIMESTAMPTZ NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at       TIMESTAMPTZ NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT aud_certification_campaign_pkey PRIMARY KEY (id),
    CONSTRAINT chk_acc_type CHECK (
        campaign_type IN ('QUARTERLY','ANNUAL','OFFBOARDING','INCIDENT','SOD_REVIEW')
    ),
    CONSTRAINT chk_acc_scope CHECK (
        scope_type IN ('TENANT','USER','ROLE','ATOM')
    ),
    CONSTRAINT chk_acc_status CHECK (
        status IN ('ACTIVE','COMPLETED','CANCELLED','OVERDUE')
    ),
    CONSTRAINT chk_acc_dates CHECK (
        closed_at IS NULL OR closed_at > started_at
    )
);

CREATE INDEX IF NOT EXISTS idx_acc_tenant_active
    ON bauth.aud_certification_campaign (tenant_id, status)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.aud_certification_campaign IS
'AUDITORÍA IGA | Cabecera de campaña de certificación periódica de accesos (Identity Governance &
Administration). Una fila por campaña: define tipo (QUARTERLY/ANNUAL/OFFBOARDING/INCIDENT/SOD_REVIEW),
alcance (TENANT/USER/ROLE/ATOM con scope_id opcional), ventana de revisión (started_at → due_date),
responsable (initiated_by) y estado (ACTIVE/COMPLETED/CANCELLED/OVERDUE). Es la cabecera del
workflow IGA: cada campaña genera N filas en T-178 (una por grant bajo revisión). Una campaña
SOD_REVIEW la dispara el detector de conflictos cuando detecta drift en la matriz SoD.
Fuente: el job cron bAuth (fn_launch_quarterly_campaign) la crea automáticamente para todos los
tenants activos; también puede crearse vía RPC bauth.iga.campaign.create por SECURITY_ADMIN.
Administración: solo SECURITY_ADMIN y SUPER_ADMIN pueden crear/cancelar campañas; el cierre
automático (status=COMPLETED) lo ejecuta el daemon al recibir la última decisión de T-178;
status=OVERDUE lo escribe el job de expiración cuando due_date < now() y status=ACTIVE.
WORM: no — status es mutable operacionalmente (ACTIVE→COMPLETED/CANCELLED/OVERDUE); la evidencia
inmutable de cada decisión vive en T-178.
Particionada: no (candidata por started_at si los tenants son muy numerosos).
Estándar: NIST SP 800-53 AC-2(4)/AC-11, ISO 27001 A.5.18/A.8.2, PCI DSS 4.0 Req 7.2. T-177.';


-- ======================================================================
-- T-178 — bauth.aud_certification_review
-- Evidencia auditable de revisión IGA — una fila por (campaña, grant).
-- ES la prueba que presenta el auditor ISO 27001 (A.8.2).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.aud_certification_review (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    campaign_id     UUID        NOT NULL REFERENCES bauth.aud_certification_campaign(id),
    grant_id        UUID        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    reviewer_id     UUID        NOT NULL,
    reviewer_role   TEXT        NOT NULL,
    decision        TEXT        NULL,
    justification   TEXT        NULL,
    reviewed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    revocation_at   TIMESTAMPTZ NULL,
    escalated_to    UUID        NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT aud_certification_review_pkey PRIMARY KEY (id),
    CONSTRAINT chk_acr_decision CHECK (
        decision IS NULL OR decision IN ('CERTIFY','REVOKE','ESCALATE','DEFER')
    ),
    CONSTRAINT chk_acr_justification CHECK (
        decision NOT IN ('REVOKE','ESCALATE') OR justification IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_acr_campaign ON bauth.aud_certification_review (campaign_id);
CREATE INDEX IF NOT EXISTS idx_acr_reviewer ON bauth.aud_certification_review (reviewer_id, reviewed_at DESC);

COMMENT ON TABLE bauth.aud_certification_review IS
'AUDITORÍA IGA | Evidencia auditable de revisión de accesos — una fila por (campaña, grant) revisado.
Para cada grant del alcance de la campaña (T-177), el revisor registra su decisión: CERTIFY (acceso
válido), REVOKE (eliminar acceso), ESCALATE (subir a aprobador superior con escalated_to) o DEFER
(postponer con nueva fecha). decision=REVOKE escribe revocation_at y dispara el daemon que actualiza
T-170 privilege_atom_grant a status=REVOKED < 24h. justification es obligatoria para REVOKE y
ESCALATE (constraint chk_acr_justification). Esta tabla ES la prueba que presenta el CISO al auditor
ISO 27001 para demostrar revisión periódica de accesos (A.8.2 Access Rights Review).
Fuente: generada automáticamente al abrirse una campaña en T-177: el daemon crea una fila por cada
grant activo en el alcance; la fila nace con decision=NULL y se actualiza cuando el revisor decide.
Administración: los revisores escriben decision, justification y reviewed_at vía RPC
bauth.iga.review.decide; solo SECURITY_ADMIN puede reasignar reviewer_id; las filas con
decision=REVOKE son inmutables una vez procesadas (el revocador registra un hash WORM en T-152).
WORM: no formalmente, pero las filas con decision son inmutables de facto por contrato de auditoría.
Particionada: no (candidata por campaign_id si los grants son masivos).
Estándar: NIST SP 800-53 AC-2(7)/AC-11, ISO 27001 A.5.18/A.8.2, PCI DSS 4.0 Req 7.2, SOX §302. T-178.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 10 — RIESGO / ITDR (bauth)                          ║
-- ║   Identity Threat Detection and Response                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-180 — bauth.ses_risk_policy
-- Reglas de política de riesgo adaptativo por tenant.
-- El PDP consulta esta tabla al recibir un evento CAEP para decidir qué acción tomar.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.ses_risk_policy (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    tier_id         TEXT        NULL,
    trigger_event   TEXT        NOT NULL,
    condition       JSONB       NOT NULL,
    action          TEXT        NOT NULL,
    required_loa    TEXT        NULL,
    priority        INTEGER     NOT NULL DEFAULT 100,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    created_by      UUID        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT ses_risk_policy_pkey PRIMARY KEY (id),
    CONSTRAINT chk_rp_event CHECK (
        trigger_event IN (
            'session-revoked','token-claims-change','credential-change',
            'assurance-level-change','device-compliance-change','risk-level-change'
        )
    ),
    CONSTRAINT chk_rp_action CHECK (
        action IN ('STEP_UP','REVOKE','SUSPEND','NOTIFY','REQUIRE_MFA')
    ),
    CONSTRAINT chk_rp_loa CHECK (
        (action = 'STEP_UP' AND required_loa IS NOT NULL)
        OR action <> 'STEP_UP'
    )
);

CREATE INDEX IF NOT EXISTS idx_rp_tenant_event
    ON bauth.ses_risk_policy (tenant_id, trigger_event, priority)
    WHERE is_active = true;

COMMENT ON TABLE bauth.ses_risk_policy IS
'RIESGO ADAPTATIVO | Reglas de política de respuesta a eventos CAEP por tenant — tabla de decisión del PDP
para Identity Threat Detection and Response (ITDR). Cada fila define: qué evento CAEP dispara la regla
(trigger_event), bajo qué condición (condition JSONB evaluada contra el payload), qué acción tomar
(action: STEP_UP/REVOKE/SUSPEND/NOTIFY/REQUIRE_MFA), y si la acción es STEP_UP cuál es el LoA
requerido (required_loa). El PDP evalúa las reglas del tenant en orden ASC de priority y aplica la
primera que coincide ("first-match"). Esta tabla reemplaza las reglas hardcodeadas en el daemon — es
editable en runtime por SECURITY_ADMIN sin recompilar, lo que permite ajustar la respuesta al riesgo
sin despliegues. condition JSONB: expresión tipo {risk_score: {gte: 70}} evaluada en Rust por el motor
de expresiones ITDR (evalúa vs el payload del evento CAEP recibido en T-191).
Fuente: seed de despliegue con 3 reglas por defecto para todos los tenants (REVOKE en score≥85,
STEP_UP AAL2 en score≥70, SUSPEND en device_compliance=false); SECURITY_ADMIN puede agregar/pausar
reglas personalizadas vía RPC bauth.itdr.policy.create.
Administración: solo SECURITY_ADMIN y SUPER_ADMIN pueden crear/modificar/pausar reglas (is_active);
el PDP carga la tabla al arrancar y la recarga por señal al detectar cambios; updated_at trackea la
última modificación para invalidación de cache del PDP.
WORM: no — is_active y condition son mutables (administración de políticas en runtime).
Particionada: no.
Estándar: NIST SP 800-207 §3.3, NIST SP 800-53 AC-25, RFC 8935/RFC 9493 CAEP, ISO 27001 A.8.16. T-180.';
COMMENT ON COLUMN bauth.ses_risk_policy.condition      IS 'Expresión JSONB evaluada contra el payload del evento CAEP recibido. Sintaxis: {campo: {operador: valor}} — ej. {risk_score: {gte: 70}}, {device_compliance: {eq: false}}. Evaluada por el motor de expresiones ITDR en Rust.';
COMMENT ON COLUMN bauth.ses_risk_policy.priority       IS 'Orden de evaluación: el PDP evalúa las reglas del tenant ASC por priority y aplica la primera que coincide. Menor número = mayor prioridad. Las reglas globales (tier_id NULL) tienen priority 1000 por convención.';
COMMENT ON COLUMN bauth.ses_risk_policy.required_loa   IS 'LoA requerido para el step-up (AAL1/AAL2/AAL3). Solo presente cuando action=STEP_UP; NULL si la acción no requiere elevación (constraint chk_rp_loa). Determina qué saga de step-up se activa.';
COMMENT ON COLUMN bauth.ses_risk_policy.trigger_event  IS 'Tipo de evento CAEP que activa la evaluación de esta regla — debe coincidir exactamente con el event_type recibido en T-191 ses_caep_event_log.';
COMMENT ON COLUMN bauth.ses_risk_policy.tier_id        IS 'Tier de rol al que aplica esta regla (ej. SYS, BIZ_N1). NULL = aplica a todos los tiers del tenant. Permite reglas más estrictas para tiers de mayor privilegio.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 11 — PAM · JIT · BREAKGLASS · VAULT (bauth)         ║
-- ║   Privileged Access Management                                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-182 — bauth.pam_jit_request
-- Solicitud de acceso temporal privilegiado (Zero Standing Privilege).
-- Cabecera del workflow JIT. WORM por diseño: INSERT only en producción.
-- La aprobación vive íntegramente en T-182b (pam_jit_approval).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_jit_request (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    requester_id        UUID        NOT NULL,
    target_role_id      UUID        NOT NULL,
    target_atoms        UUID[]      NULL,
    justification       TEXT        NOT NULL,
    requested_duration  INTERVAL    NOT NULL,
    max_duration        INTERVAL    NOT NULL,
    niveles_requeridos  INTEGER     NOT NULL DEFAULT 1,
    requested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    status              TEXT        NOT NULL DEFAULT 'PENDING',
    rejection_reason    TEXT        NULL,
    grant_id            UUID        NULL REFERENCES bauth.privilege_atom_grant(id),
    activated_at        TIMESTAMPTZ NULL,
    valid_from          TIMESTAMPTZ NULL,
    valid_until         TIMESTAMPTZ NULL,
    expired_at          TIMESTAMPTZ NULL,
    revoked_at          TIMESTAMPTZ NULL,
    revoked_by          UUID        NULL,
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pam_jit_request_pkey  PRIMARY KEY (id),
    CONSTRAINT chk_pjr_status CHECK (
        status IN ('PENDING','APPROVED','REJECTED','ACTIVE','EXPIRED','REVOKED')
    ),
    CONSTRAINT chk_pjr_duration      CHECK (requested_duration <= max_duration),
    CONSTRAINT chk_pjr_justification CHECK (length(justification) >= 50),
    CONSTRAINT chk_pjr_niveles       CHECK (niveles_requeridos BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_pjr_tenant_status
    ON bauth.pam_jit_request (tenant_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_pjr_active_expiry
    ON bauth.pam_jit_request (valid_until)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.pam_jit_request IS
'PAM JIT | Cabecera de solicitud de acceso temporal privilegiado (Zero Standing Privilege). Implementa
el patrón PAM JIT donde el usuario no tiene privilegios de forma permanente — los solicita, justifica,
y los obtiene por tiempo limitado tras aprobación multi-nivel. Una fila por solicitud con el ciclo de
vida completo: PENDING → APPROVED → ACTIVE → EXPIRED/REVOKED (o REJECTED desde PENDING).
Campos clave: target_role_id (qué rol temporal), target_atoms (lista opcional de átomos específicos),
justification (mínimo 50 chars — constraint chk_pjr_justification), requested_duration (no puede
exceder max_duration del tier — constraint chk_pjr_duration), niveles_requeridos (cuántas aprobaciones
secuenciales en T-182b requiere este tier), grant_id (FK a T-170 creada al aprobar), valid_from/
valid_until (ventana de acceso activo). El job de expiración en Rust revisa cada 60s las filas
status=ACTIVE con valid_until < now() y escribe expired_at + revoca el grant en T-170.
Fuente: solo vía RPC bauth.jit.request.create por el requester autenticado; nunca por INSERT directo.
El daemon valida tier, duración máxima y SoD antes de insertar; crea las N filas en T-182b
(una por nivel requerido) y notifica al aprobador de nivel 1.
Administración: el requester solo puede crear y leer sus propias solicitudes; los aprobadores de cada
nivel escriben en T-182b; solo PAM_ADMIN puede revocar manualmente (revoked_by + revoked_at).
WORM: no — el campo status es mutable a lo largo del ciclo de vida; el historial completo de
transiciones de estado se registra en T-170b (privilege_grant_audit_log).
Particionada: no (candidata por requested_at si el volumen JIT es alto en entornos enterprise).
Estándar: NIST SP 800-53 AC-6(9)/AC-2(6), ISO 27001 A.5.18/A.8.2, PCI DSS 4.0 Req 7.2.6. T-182.';
COMMENT ON COLUMN bauth.pam_jit_request.target_atoms       IS 'Array opcional de UUIDs de átomos específicos a solicitar dentro de target_role_id. NULL = solicita el rol completo. Permite JIT granular: solo los átomos necesarios.';
COMMENT ON COLUMN bauth.pam_jit_request.niveles_requeridos IS 'Cuántos niveles de aprobación secuencial exige el tier del acceso solicitado (1-5). El daemon crea esta cantidad de filas en T-182b pam_jit_approval al insertar la solicitud.';
COMMENT ON COLUMN bauth.pam_jit_request.max_duration       IS 'Duración máxima permitida por la política del tier del rol solicitado. La constraint chk_pjr_duration verifica requested_duration ≤ max_duration al crear la solicitud.';
COMMENT ON COLUMN bauth.pam_jit_request.grant_id           IS 'FK a T-170 privilege_atom_grant creada al aprobar todos los niveles. NULL mientras status IN (PENDING, APPROVED, REJECTED). El grant tiene valid_from/valid_until de la ventana aprobada.';
COMMENT ON COLUMN bauth.pam_jit_request.justification      IS 'Justificación obligatoria del acceso — mínimo 50 caracteres (constraint chk_pjr_justification). Es la evidencia forense del por qué se necesitó el acceso privilegiado.';


-- ======================================================================
-- T-182b — bauth.pam_jit_approval
-- Aprobación secuencial multi-level de solicitudes JIT.
-- Una fila por level de aprobación. Nivel N+1 se notifica solo cuando Nivel N aprueba.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_jit_approval (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    request_id      UUID        NOT NULL REFERENCES bauth.pam_jit_request(id),
    level           INTEGER     NOT NULL,
    required_role   TEXT        NOT NULL,
    approver_id     UUID        NULL,
    decision        TEXT        NULL,
    notified_at     TIMESTAMPTZ NULL,
    decision_at     TIMESTAMPTZ NULL,
    notes           TEXT        NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT pam_jit_approval_pkey    PRIMARY KEY (id),
    CONSTRAINT uq_pja_request_level     UNIQUE (request_id, level),
    CONSTRAINT chk_pja_decision CHECK (  -- [MC-0209] → A.65.04
        decision IS NULL OR decision IN ('APPROVED','REJECTED')
    ),
    CONSTRAINT chk_pja_level CHECK (level BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_pja_pending
    ON bauth.pam_jit_approval (request_id, level)
    WHERE decision IS NULL;
CREATE INDEX IF NOT EXISTS idx_pja_approver_pending
    ON bauth.pam_jit_approval (approver_id, notified_at)
    WHERE decision IS NULL AND notified_at IS NOT NULL;

COMMENT ON TABLE bauth.pam_jit_approval IS
'PAM JIT | Aprobaciones secuenciales multi-nivel de una solicitud JIT (T-182). Una fila por nivel de
aprobación por solicitud (UNIQUE request_id + level). Implementa la cadena de aprobación: el Nivel 1
se notifica (notified_at) al crear la solicitud; el Nivel N+1 se notifica solo cuando el Nivel N
registra decision=APPROVED — garantizando que los aprobadores no reciban notificaciones prematuras.
Si cualquier nivel registra decision=REJECTED: la solicitud pasa a REJECTED y ningún nivel superior
es notificado ni puede decidir. Campos clave: required_role (qué rol puede aprobar en este nivel —
ej. GERENTE_IT en level 1, CISO en level 2), approver_id (quién decidió realmente — puede diferir
de required_role si hay delegación), notes (justificación opcional del aprobador). La cantidad de
niveles se configura por tier en T-182 (niveles_requeridos) — el DDL no necesita cambiar para
agregar un nivel nuevo, solo insertar una fila adicional con el level siguiente.
Fuente: creadas automáticamente por el daemon al crear la solicitud en T-182 — una fila por nivel
requerido, con decision=NULL y notified_at=NULL (excepto nivel 1 que recibe notificación inmediata).
Administración: el aprobador autorizado escribe decision + approver_id + decision_at vía RPC
bauth.jit.approval.decide; PAM_ADMIN puede reasignar approver_id si el aprobador no está disponible.
WORM: no — decision es NULL hasta que el aprobador actúa; una vez registrada no debe modificarse
(integridad del proceso de aprobación), pero el DDL permite actualización para correcciones HITL.
Particionada: no.
Estándar: NIST SP 800-53 AC-6(9)/AC-5, ISO 27001 A.5.18, NIST SP 800-53 AR-4. T-182b.';
COMMENT ON COLUMN bauth.pam_jit_approval.level         IS 'Número de nivel secuencial (1-N). El nivel 1 es el primer aprobador en la cadena; niveles superiores solo son notificados cuando todos los inferiores aprueban. El total de niveles se define en T-182 pam_jit_request.niveles_requeridos.';
COMMENT ON COLUMN bauth.pam_jit_approval.required_role IS 'Código del rol que tiene autoridad para aprobar en este nivel — ej. GERENTE_IT (level 1), CISO (level 2). El motor valida que approver_id tenga este rol activo antes de aceptar la decisión. No es FK física para permitir delegación temporal.';
COMMENT ON COLUMN bauth.pam_jit_approval.decision      IS 'Decisión del aprobador: APPROVED (concede paso al siguiente nivel) o REJECTED (cancela la solicitud completa y notifica). NULL = pendiente de decisión. Una vez escrita, el daemon no la sobreescribe — solo PAM_ADMIN puede corregir vía HITL.';
COMMENT ON COLUMN bauth.pam_jit_approval.notified_at   IS 'Cuándo fue notificado el aprobador requerido de este nivel. NULL = aún no notificado (este nivel espera aprobación de niveles previos). El nivel 1 se notifica al crear la solicitud; niveles N+1 al aprobar el nivel N.';


-- ======================================================================
-- T-185 — bauth.pam_breakglass_activation
-- Ciclo de vida completo de activaciones break-glass (grants BREAKGLASS en T-170).
-- Dual control obligatorio: status=ACTIVE solo con aprobador registrado.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_breakglass_activation (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    activated_by        UUID        NOT NULL,
    approver_id         UUID        NULL,
    approved_at         TIMESTAMPTZ NULL,
    grant_id            UUID        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    incident_ref        TEXT        NULL,
    justification       TEXT        NOT NULL,
    auth_method         TEXT        NOT NULL,
    auth_loa            INTEGER     NOT NULL DEFAULT 3,
    activated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    deactivated_at      TIMESTAMPTZ NULL,
    deactivated_by      UUID        NULL,
    post_review_due_at  TIMESTAMPTZ NOT NULL,
    post_review_at      TIMESTAMPTZ NULL,
    post_reviewer_id    UUID        NULL,
    post_review_notes   TEXT        NULL,
    status              TEXT        NOT NULL DEFAULT 'PENDING_APPROVAL',
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pam_breakglass_activation_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pbga_status CHECK (
        status IN ('PENDING_APPROVAL','ACTIVE','DEACTIVATED','REVIEWED')
    ),
    CONSTRAINT chk_pbga_auth_method CHECK (  -- [MC-0201] → A.65.04
        auth_method IN ('MTLS_X509','WEBAUTHN_ROAMING','WEBAUTHN_PLATFORM')
    ),
    CONSTRAINT chk_pbga_auth_loa CHECK (auth_loa IN (2,3)),
    CONSTRAINT chk_pbga_review_due CHECK (post_review_due_at > activated_at),
    CONSTRAINT chk_pbga_deactivation CHECK (  -- [MC-0202] → A.65.04
        (status IN ('DEACTIVATED','REVIEWED') AND deactivated_at IS NOT NULL)
        OR status IN ('PENDING_APPROVAL','ACTIVE')
    ),
    CONSTRAINT chk_pbga_dual_control CHECK (  -- [MC-0203] → A.65.04
        (status = 'ACTIVE' AND approver_id IS NOT NULL AND approved_at IS NOT NULL)
        OR status IN ('PENDING_APPROVAL','DEACTIVATED','REVIEWED')
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pbga_active_grant
    ON bauth.pam_breakglass_activation (tenant_id, grant_id)
    WHERE status IN ('PENDING_APPROVAL','ACTIVE');

CREATE INDEX IF NOT EXISTS idx_pbga_tenant_active
    ON bauth.pam_breakglass_activation (tenant_id, activated_at DESC)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_pbga_review_pending
    ON bauth.pam_breakglass_activation (post_review_due_at)
    WHERE post_review_at IS NULL;

COMMENT ON TABLE bauth.pam_breakglass_activation IS
'PAM BREAKGLASS | Ciclo de vida completo de activaciones de acceso de emergencia (break-glass). Cuando
un incidente crítico requiere acceso de superusuario inmediato fuera del workflow JIT normal, este
mecanismo permite la activación con dual control obligatorio y revisión post-incidente.
Estados: PENDING_APPROVAL → ACTIVE → DEACTIVATED → REVIEWED. Invariantes de seguridad:
(1) chk_pbga_dual_control: status=ACTIVE solo alcanzable con approver_id ≠ NULL y approved_at ≠ NULL
— nadie puede auto-aprobarse su propio break-glass; (2) auth_method limitado a AAL3 obligatorio:
MTLS_X509, WEBAUTHN_ROAMING, WEBAUTHN_PLATFORM — nunca password sola; (3) auth_loa ∈ {2,3}
(chk_pbga_auth_loa); (4) post_review_due_at = activated_at + 24h (chk_pbga_review_due); el CISO
debe revisar el incidente en 24h. TTL de activación: 4h forzado por job breakglass_expiry.rs
(escribe deactivated_at + revoca el grant BREAKGLASS en T-170). Cada activación genera alerta SIEM
(Wazuh) instantánea via T-191 (evento CAEP session-revoked no esperado). incident_ref enlaza al
ticket del sistema de gestión de incidentes externo para correlación.
Fuente: solo vía RPC bauth.pam.breakglass.activate por el usuario con rol BREAKGLASS_USER;
el daemon valida que no exista ya una activación activa para el mismo tenant+grant (uq_pbga_active_grant).
Administración: el daemon escribe approved_at al recibir confirmación del segundo SU; post_review_at
y post_review_notes los escribe el CISO en la revisión post-incidente vía bauth.pam.breakglass.review.
WORM: no — el ciclo de vida requiere mutabilidad de status; el registro completo de acciones ejercidas
vive en T-184 pam_session_record como evidencia forense inmutable.
Particionada: no.
Estándar: NIST SP 800-53 AC-2(4)/AC-5/AC-6(9), ISO 27001 A.5.18/A.9.4.2, SOX §302, PCI DSS Req 8.7. T-185.';


-- ======================================================================
-- T-183 — bauth.pam_credential_ref
-- Inventario de credenciales privilegiadas — solo metadatos y ruta Vault.
-- El valor de la credencial NUNCA se almacena aquí.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_credential_ref (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    owner_id            UUID        NOT NULL,
    owner_type          TEXT        NOT NULL,
    credential_type     TEXT        NOT NULL,
    vault_path          TEXT        NOT NULL,
    target_system       TEXT        NOT NULL,
    rotation_policy     TEXT        NOT NULL DEFAULT 'AUTO_90D',
    last_rotated_at     TIMESTAMPTZ NULL,
    next_rotation_at    TIMESTAMPTZ NULL,
    rotation_count      INTEGER     NOT NULL DEFAULT 0,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pam_credential_ref_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pcref_type  CHECK (  -- [MC-0206] → A.65.04
        credential_type IN ('PASSWORD','SSH_KEY','API_KEY','CERT','TOKEN','OAUTH_CLIENT')
    ),
    CONSTRAINT chk_pcref_owner CHECK (owner_type IN ('HUMAN','NHI')),
    CONSTRAINT chk_pcref_rot   CHECK (  -- [MC-0204] → A.65.04
        rotation_policy IN ('MANUAL','AUTO_7D','AUTO_30D','AUTO_90D','AUTO_1Y')
    ),
    CONSTRAINT chk_pcref_status CHECK (  -- [MC-0205] → A.65.04
        status IN ('ACTIVE','ROTATING','REVOKED','EXPIRED')
    )
);

CREATE INDEX IF NOT EXISTS idx_pcref_rotation ON bauth.pam_credential_ref (next_rotation_at)
    WHERE status = 'ACTIVE' AND next_rotation_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pcref_owner ON bauth.pam_credential_ref (owner_id, owner_type);

COMMENT ON TABLE bauth.pam_credential_ref IS
'PAM | Inventario de credenciales privilegiadas — panel de control de rotación, NO almacén de secretos.
El valor real de la credencial reside SIEMPRE en Vault (vault_path es la ruta al secret en Vault, nunca
el valor). Esta tabla almacena solo metadatos de gestión: tipo de credencial (PASSWORD/SSH_KEY/API_KEY/
CERT/TOKEN/OAUTH_CLIENT), owner (humano T-320 u NHI T-186 según owner_type), sistema destino
(target_system: servidor, servicio, BD), política de rotación (rotation_policy: MANUAL/AUTO_7D/
AUTO_30D/AUTO_90D/AUTO_1Y) y estado del ciclo de vida (ACTIVE/ROTATING/REVOKED/EXPIRED).
El job de rotación lee idx_pcref_rotation (next_rotation_at IS NOT NULL AND status=ACTIVE AND
next_rotation_at <= now()), obtiene la ruta Vault, genera la nueva credencial, la escribe en Vault,
actualiza last_rotated_at + next_rotation_at + rotation_count, y notifica al sistema destino.
Fuente: creada vía RPC bauth.pam.credential.register por PAM_ADMIN al registrar una credencial
privilegiada nueva; también automáticamente al crear una NHI (T-186) si tiene secretos en Vault.
Administración: PAM_ADMIN y SUPER_ADMIN pueden registrar/revocar credenciales; el job de rotación
automatizado actualiza rotation fields; el valor NUNCA es accesible desde SQL — solo via Vault API
con token de corta duración y auditoría de acceso. REVOCACIÓN: status=REVOKED + invalidación en Vault.
WORM: no — status y rotation fields son mutables (ciclo de vida de credenciales).
Particionada: no.
Estándar: NIST SP 800-53 IA-5(1)/IA-5(6), CIS Control 5.4, PCI DSS 4.0 Req 8.3.6, ISO 27001 A.5.17. T-183.';


-- ======================================================================
-- T-184 — bauth.pam_session_record
-- Metadatos de sesión de acceso privilegiado — CÓMO se ejerció el privilegio.
-- Grabación real en MinIO; esta tabla almacena metadatos y referencia.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_session_record (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    session_id          UUID        NOT NULL REFERENCES bauth.ses_session_log(session_id),
    user_id             UUID        NOT NULL,
    grant_id            UUID        NULL REFERENCES bauth.privilege_atom_grant(id),
    jit_request_id      UUID        NULL REFERENCES bauth.pam_jit_request(id),
    target_resource     TEXT        NOT NULL,
    access_type         TEXT        NOT NULL,
    credential_ref_id   UUID        NULL REFERENCES bauth.pam_credential_ref(id),
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at            TIMESTAMPTZ NULL,
    duration_seconds    INTEGER     NULL GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::integer
    ) STORED,
    commands_count      INTEGER     NOT NULL DEFAULT 0,
    recording_ref       TEXT        NULL,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pam_session_record_pkey PRIMARY KEY (id),
    CONSTRAINT chk_psr_access_type CHECK (
        access_type IN ('SSH','RDP','API','CONSOLE','DB','CLI','VAULT')
    ),
    CONSTRAINT chk_psr_status CHECK (  -- [MC-0211] → A.65.04
        status IN ('ACTIVE','ENDED','TERMINATED','ERROR')
    )
);

CREATE INDEX IF NOT EXISTS idx_psr_session ON bauth.pam_session_record (session_id);
CREATE INDEX IF NOT EXISTS idx_psr_user    ON bauth.pam_session_record (user_id, tenant_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_psr_active  ON bauth.pam_session_record (tenant_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_psr_jit     ON bauth.pam_session_record (jit_request_id)
    WHERE jit_request_id IS NOT NULL;

COMMENT ON TABLE bauth.pam_session_record IS
'PAM | Metadatos de sesión de acceso privilegiado — registra CÓMO se ejerció el privilegio, no QUIÉN
lo tiene. Separación de responsabilidades: T-170 (privilege_atom_grant) audita QUÉ acceso fue otorgado;
T-184 (esta tabla) audita CÓMO se ejerció — qué sesión, qué recurso destino, qué tipo de acceso
(SSH/RDP/API/CONSOLE/DB/CLI/VAULT), cuántos comandos se ejecutaron (commands_count) y la referencia
al archivo de grabación de sesión en MinIO (recording_ref — path del archivo, nunca el binario).
Trazabilidad completa de auditoría PAM: jit_request_id → T-182 (justificación) → T-182b (aprobación)
→ session_id T-151 (sesión SSO) → T-184 (esta fila: qué hizo) → recording_ref (evidencia forense).
duration_seconds: GENERATED ALWAYS AS calculado automáticamente por PostgreSQL al escribirse ended_at,
sin lógica de aplicación — campo calculado almacenado (STORED) para consultas de análisis forense.
Fuente: creada por el proxy PAM de bAuth al abrir cada sesión privilegiada; el proxy actualiza
commands_count en streaming y escribe ended_at + recording_ref al cerrar la sesión.
Administración: solo el daemon PAM de bAuth escribe; PAM_ADMIN y AUDITOR pueden leer;
recording_ref en MinIO requiere credenciales adicionales con TTL de acceso corto (no acceso directo SQL).
WORM: no — ended_at y recording_ref se escriben al cerrar la sesión (no al abrir).
Particionada: no (candidata por started_at si el volumen de sesiones PAM es alto).
Estándar: NIST SP 800-53 AU-14/AU-9, ISO 27001 A.8.15, PCI DSS 4.0 Req 10.2.1.3. T-184.';


-- ======================================================================
-- T-189 — bauth.pam_nhi_secret_ref
-- Referencias a secretos de NHI en Vault — alta frecuencia de rotación (7-30 días).
-- NUNCA almacena el valor del secreto; solo la ruta en Vault.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_nhi_secret_ref (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id              UUID        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    secret_type         TEXT        NOT NULL,
    vault_path          TEXT        NOT NULL,
    rotation_policy     TEXT        NOT NULL DEFAULT 'AUTO_30D',
    last_rotated_at     TIMESTAMPTZ NULL,
    next_rotation_at    TIMESTAMPTZ NULL,
    rotation_count      INTEGER     NOT NULL DEFAULT 0,
    expires_at          TIMESTAMPTZ NULL,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pam_nhi_secret_ref_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pnsr_type CHECK (
        secret_type IN ('API_KEY','OAUTH_CLIENT','CERT','TOKEN','SSH_KEY','PASSWORD')
    ),
    CONSTRAINT chk_pnsr_rotation CHECK (  -- [MC-0210] → A.65.04
        rotation_policy IN ('AUTO_7D','AUTO_30D','AUTO_90D','MANUAL','ON_USE')
    ),
    CONSTRAINT chk_pnsr_status CHECK (
        status IN ('ACTIVE','ROTATING','REVOKED','EXPIRED')
    )
);

CREATE INDEX IF NOT EXISTS idx_pnsr_nhi ON bauth.pam_nhi_secret_ref (nhi_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_pnsr_rotation ON bauth.pam_nhi_secret_ref (next_rotation_at)
    WHERE status = 'ACTIVE' AND next_rotation_at IS NOT NULL;

COMMENT ON TABLE bauth.pam_nhi_secret_ref IS
'PAM NHI | Referencias a secretos de identidades no humanas (daemons, bots, pipelines, agentes) en Vault.
Complementa T-183 (pam_credential_ref para humanos) con rotación más frecuente y el patrón ON_USE
específico para NHI (rotate-on-every-use — patrón recomendado para pipelines CI/CD). Una fila por
secreto de cada NHI (T-186 idn_roles_nhi_identity): API_KEY, OAUTH_CLIENT, CERT, TOKEN, SSH_KEY
o PASSWORD. vault_path: ruta al secret en Vault — el valor NUNCA se almacena en PostgreSQL.
Políticas de rotación: AUTO_7D (alta rotación para bots externos), AUTO_30D (daemons internos),
AUTO_90D (certificados de larga duración), MANUAL (solo bajo HITL explícito), ON_USE (se regenera en
cada uso — máxima seguridad para pipelines con acceso a datos sensibles).
Al descomisionar un NHI (T-186 status=DECOMMISSIONED): todos sus secretos pasan automáticamente a
status=REVOKED y se invalidan en Vault en una transacción atómica — garantizando que ningún proceso
antiguo puede autenticarse con credenciales de un daemon desactivado.
Fuente: creadas automáticamente al registrar un NHI en T-186 y aprobar sus secretos en Vault;
también por migración cuando un daemon existente adopta el ciclo de vida NHI.
Administración: NHI_ADMIN y SUPER_ADMIN pueden registrar/revocar; el job de rotación automatizado
usa idx_pnsr_rotation; el daemon solo lee la ruta para obtener el secreto de Vault en cada auth.
WORM: no — rotation fields y status son mutables por diseño.
Particionada: no.
Estándar: NIST SP 800-53 IA-5(1), CIS Control 5.4 (API Keys), NIST SP 800-207 §3.1 NHI. T-189.';
COMMENT ON COLUMN bauth.pam_nhi_secret_ref.vault_path      IS 'Ruta canónica al secret en Vault KV v2 — ej. "secret/data/bauth/nhi/<nhi_id>/api_key". El valor del secreto NUNCA se almacena en PostgreSQL. El daemon obtiene el secreto directamente de Vault en cada autenticación usando esta ruta.';
COMMENT ON COLUMN bauth.pam_nhi_secret_ref.rotation_policy IS 'Política de rotación del secreto: AUTO_7D (bots externos, alta rotación), AUTO_30D (daemons internos — por defecto), AUTO_90D (certificados de larga duración), MANUAL (solo con HITL explícito), ON_USE (se regenera en cada uso — máxima seguridad para pipelines CI/CD con acceso a datos sensibles).';
COMMENT ON COLUMN bauth.pam_nhi_secret_ref.rotation_count  IS 'Contador acumulado de rotaciones exitosas desde la creación del NHI. Útil para auditorías de cumplimiento que exigen demostrar rotación periódica. El job de rotación lo incrementa en cada rotación exitosa.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║        MENÚ — Contextos y ligas adicionales (bglobal)               ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-060 — bglobal.menu_context
-- Contextos de menú (sidebar, toolbar, contextual, quick-actions).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.menu_context (
    context_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    code             TEXT        UNIQUE NOT NULL,
    name             JSONB       NOT NULL,
    menu_type        menu_type_enum NOT NULL DEFAULT 'HIERARCHICAL',
    description      TEXT,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    sort_order       INTEGER     NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bglobal.menu_context IS
'MENÚ | Catálogo de contextos de menú — define los tipos de contenedor de navegación de la UI del
ecosistema SBOS. Cada fila es un contexto en el que pueden existir ítems de menú (T-059 menu_item):
sidebar (menú lateral principal), toolbar (barra de herramientas superior), contextual (menú de clic
derecho), quick-actions (acciones rápidas flotantes), breadcrumb (migas de pan). Permite que la UI
del dashboard pregunte "qué ítems van en el sidebar del tenant X" sin hardcodear la lista de contextos
en el frontend — el frontend lee los contextos activos (is_active=true) y los ítems vinculados.
name JSONB bilingüe para internacionalización vía bi18n. menu_type_enum: HIERARCHICAL (árbol) vs FLAT.
Fuente: seed de despliegue con los 5 contextos estándar de SBOS; HITL para agregar contextos nuevos
(cambio de UI que requiere aprobación de diseño y arquitectura).
Administración: solo SUPER_ADMIN y UI_ADMIN pueden crear/desactivar contextos; el frontend carga esta
tabla al arrancar y la cachea en Redis; cambios de is_active se propagán por señal CAEP catalog_change.
WORM: no — is_active y sort_order son mutables para ajustes de UX.
Particionada: no.
Seed: DDLs/seeds/bglobal_T060__menu_context.sql — idempotente ON CONFLICT.
Estándar: WCAG 2.2 (navegación accesible), SBOS ADR-020 (Interface Dual). T-060.';


-- ======================================================================
-- T-061 — bglobal.menu_item_atom
-- Relación ítem↔átomo de privilegio — puente entre visibilidad de menú y motor BitMask.
-- Un ítem de menú es visible solo si el usuario tiene el átomo correspondiente en su BitmaskBundle.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.menu_item_atom (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    item_id          UUID        NOT NULL REFERENCES bglobal.menu_item(item_id) ON DELETE CASCADE,
    atom_code        TEXT        NOT NULL,
    required_effect  TEXT        NOT NULL DEFAULT 'PERMIT' CHECK (required_effect IN ('PERMIT','DENY')),
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (item_id, atom_code)
);

CREATE INDEX IF NOT EXISTS idx_mia_item ON bglobal.menu_item_atom(item_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_mia_atom ON bglobal.menu_item_atom(atom_code) WHERE is_active = true;

COMMENT ON TABLE bglobal.menu_item_atom IS
'MENÚ | Puente entre ítems de menú (T-059 menu_item) y el motor BitMask de privilegios — implementa
la visibilidad de menú basada en privilegios: un ítem solo aparece en la UI si el usuario tiene el
átomo correspondiente con el efecto requerido en su BitmaskBundle. Una fila por (ítem, átomo): un
ítem puede requerir múltiples átomos (INSERT varias filas con el mismo item_id y distintos atom_code).
atom_code: código canónico del átomo en el árbol de políticas T-162 (ej. "D01.admin.usuarios.listar").
required_effect=PERMIT: el ítem es visible si el usuario tiene PERMIT en ese átomo (regla normal).
required_effect=DENY: el ítem se oculta si el usuario tiene DENY (para ítems que solo ve el superusuario).
El PEP del dashboard (Kong o frontend) evalúa: SELECT atom_code FROM menu_item_atom WHERE item_id=?
AND is_active=true → verifica cada atom_code contra el BitmaskBundle cacheado del usuario en Redis.
Fuente: seed de despliegue con los átomos de visibilidad de cada ítem del menú SBOS; UI_ADMIN puede
agregar nuevas ligaduras ítem↔átomo vía HITL para ítems de módulos nuevos.
Administración: solo UI_ADMIN y SUPER_ADMIN pueden modificar; is_active=false desactiva la verificación
del átomo (el ítem se vuelve visible para todos — usar con precaución); cambios se propagan al frontend
por señal de invalidación de cache.
WORM: no — is_active es mutable para gestión operacional de visibilidad.
Particionada: no.
Seed: DDLs/seeds/bglobal_T0XX__menu_item_atom.sql — PENDIENTE — depende de menu_item
Estándar: NIST SP 800-53 AC-3(9) (dynamic access control), SBOS ADR-020, OWASP ASVS 5.0 §4.1. T-061.';


-- ======================================================================
-- NIVEL 18 — S14 catálogos MethodRegistry (T-384..T-386)
-- Ref: A.65.02 v1.8 · A.65.02.04 v2.2.0 §2.6
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.auth_federation_protocol (
    protocol_id           UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code                  TEXT    NOT NULL UNIQUE,
    name                  JSONB   NOT NULL DEFAULT '{}',
    spec_url              TEXT    NOT NULL,
    aal_max               TEXT    NOT NULL CONSTRAINT chk_afp_aal CHECK (aal_max IN ('AAL1','AAL2','AAL3')),
    fal_supported         TEXT[]  NOT NULL DEFAULT '{}',
    is_phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    supports_logout       BOOLEAN NOT NULL DEFAULT FALSE,
    supports_backchannel  BOOLEAN NOT NULL DEFAULT FALSE,
    status                TEXT    NOT NULL DEFAULT 'SUPPORTED'
                                   CONSTRAINT chk_afp_status CHECK (status IN ('SUPPORTED','DEPRECATED','PLANNED')),  -- [MC-0077] → A.65.04
    sort_order            INT     NOT NULL DEFAULT 0
);
COMMENT ON TABLE bauth.auth_federation_protocol IS
'AUTENTICACIÓN | Catálogo de protocolos de federación de identidad soportados por el MethodRegistry de
bAuth — define las capacidades técnicas de cada protocolo: AAL máximo alcanzable (aal_max), niveles
de aseguramiento de federación soportados (fal_supported), resistencia a phishing (is_phishing_resistant),
soporte de logout federado (supports_logout) y backchannel (supports_backchannel). Los 8 protocolos
seed son: SAML_2_0, OIDC_CORE_1_0, OAUTH2_PKCE, OAUTH2_DEVICE, OAUTH2_TOKEN_EXCHANGE, CIBA, FAPI_2_0
y CAEP_RFC9396. is_phishing_resistant=TRUE solo en FAPI_2_0 (máxima seguridad bancaria/financiera).
El motor de federación de bAuth consulta esta tabla para validar que el protocolo negociado por un
cliente externo (fed_client T-396) es compatible con el nivel de aseguramiento requerido.
Fuente: seed fijo de despliegue con los 8 protocolos canónicos; nuevos protocolos requieren migración
DDL con HITL (cambio arquitectónico que impacta el motor de federación en Rust).
Administración: tabla de referencia inmutable en operación normal; solo HITL de arquitectura agrega
protocolos; status=DEPRECATED mantiene historial de protocolos retirados sin eliminar datos.
WORM: no — status es mutable para el ciclo de vida de protocolos (SUPPORTED→DEPRECATED).
Particionada: no.
Seed: DDLs/seeds/bauth_T384__auth_federation_protocol.sql — idempotente ON CONFLICT.
Estándar: RFC 7591 (OIDC), RFC 8705 (mTLS), FAPI 2.0, RFC 9493 (CAEP), SAML 2.0 OASIS. T-384.';


CREATE TABLE IF NOT EXISTS bauth.auth_saga_catalog (
    saga_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code            TEXT    NOT NULL UNIQUE,
    name            JSONB   NOT NULL DEFAULT '{}',
    description     JSONB   NOT NULL DEFAULT '{}',
    steps           JSONB   NOT NULL DEFAULT '[]',
    aal_required    TEXT    NOT NULL CONSTRAINT chk_asc_aal_req CHECK (aal_required IN ('AAL1','AAL2','AAL3')),
    aal_produced    TEXT    NOT NULL CONSTRAINT chk_asc_aal_pro CHECK (aal_produced IN ('AAL1','AAL2','AAL3')),
    timeout_seconds INT     NOT NULL DEFAULT 300,
    is_emergency    BOOLEAN NOT NULL DEFAULT FALSE,
    requires_mfa    BOOLEAN NOT NULL DEFAULT FALSE,
    status          TEXT    NOT NULL DEFAULT 'ACTIVE'
                             CONSTRAINT chk_asc_status CHECK (status IN ('ACTIVE','DEPRECATED','PLANNED')),  -- [MC-0080] → A.65.04
    sort_order      INT     NOT NULL DEFAULT 0
);
COMMENT ON TABLE bauth.auth_saga_catalog IS
'AUTENTICACIÓN | Catálogo de las 12 sagas de autenticación multi-paso del MethodRegistry — cada saga define la secuencia de pasos, el AAL requerido para iniciarla, el AAL producido al completarla, y si requiere MFA o es de emergencia.
Fuente: seed de despliegue con las 12 sagas canónicas (PASSWORD_MFA, PASSWORDLESS_FIDO2, SOCIAL_BROKER, SAML_SSO, DEVICE_AUTH, STEP_UP, BREAKGLASS, RECOVERY_FLOW, CIBA_PUSH, TOKEN_EXCHANGE, CLIENT_CREDENTIALS, M2M_MTLS); no se crean sagas en runtime.
Administración: tabla de referencia; cambios solo vía migración DDL con HITL; el motor de autenticación de bAuth selecciona la saga según el método solicitado y el AAL de la sesión actual; DEPRECATED conserva histórico.
WORM: no (status DEPRECATED necesario para el ciclo de vida de las sagas).
Particionada: no.
Seed: DDLs/seeds/bauth_T385__auth_saga_catalog.sql — idempotente ON CONFLICT.
Estándar: RFC 9470 (Step-Up Auth), RFC 8628 (Device Auth), RFC 8693 (Token Exchange), NIST SP 800-63B-4 §7, OWASP ASVS 5.0 §2.2. T-385.';



CREATE TABLE IF NOT EXISTS bauth.auth_compliance_map (
    map_id              UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    standard            TEXT    NOT NULL,
    control_id          TEXT    NOT NULL,
    control_description TEXT    NOT NULL,
    method_codes        TEXT[]  NOT NULL DEFAULT '{}',
    saga_codes          TEXT[]  NOT NULL DEFAULT '{}',
    coverage_level      TEXT    NOT NULL DEFAULT 'FULL'
                                 CONSTRAINT chk_acm_cov CHECK (coverage_level IN ('FULL','PARTIAL','NOT_COVERED')),  -- [MC-0060] → A.65.04
    notes               TEXT    NULL,
    CONSTRAINT uq_acm_standard_control UNIQUE (standard, control_id)
);
COMMENT ON TABLE bauth.auth_compliance_map IS
'AUTENTICACIÓN | Mapa de cumplimiento normativo del motor de autenticación — vincula cada control de estándar (NIST, PCI DSS, OWASP, ISO, FIPS) con los métodos y sagas que cubren ese control, permitiendo generación de evidencia para auditorías externas.
Fuente: seed de despliegue con 14 controles de los 5 estándares más relevantes del stack; actualizable por AUDIT_ADMIN vía migración al añadir nuevos métodos o estándares.
Administración: tabla de referencia documental — UNIQUE (standard, control_id); cobertura PARTIAL genera alerta de gap en idn_global_compliance_control; no_covered bloquea certificaciones que requieran ese control.
WORM: no.
Particionada: no.
Seed: DDLs/seeds/bauth_T386__auth_compliance_map.sql — idempotente ON CONFLICT.
Estándar: NIST SP 800-63B-4, PCI DSS 4.0, OWASP ASVS 5.0, ISO 27001:2022, FIPS 140-3. T-386.';




-- ======================================================================
-- NIVEL 19 — S18 DISPOSITIVOS (T-390..T-392)
-- Ref: A.65.02 v1.8 · NIST SP 800-207 ZTA §4.2 · FIDO2 W3C · OSDP v2.2 SIA
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.auth_device (
    device_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id     UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    user_id       UUID    NULL REFERENCES bauth.idn_user(user_id) ON DELETE SET NULL,
    device_key    TEXT    NOT NULL UNIQUE,
    name          TEXT    NOT NULL,
    category      TEXT    NOT NULL CONSTRAINT chk_ad_cat CHECK (category IN (  -- [MC-0068] → A.65.04
                      'DESKTOP','MOBILE','TABLET','SERVER','IOT',
                      'SECURITY_KEY','SMART_CARD','OSDP_READER','NFC_READER')),
    platform      TEXT    NOT NULL CONSTRAINT chk_ad_plat CHECK (platform IN (  -- [MC-0070] → A.65.04
                      'WINDOWS','LINUX','MACOS','ANDROID','IOS',
                      'EMBEDDED','FIDO2_HW','OSDP_HW','UNKNOWN')),
    os_version    TEXT    NULL,
    hardware_id   TEXT    NULL,
    aaguid        UUID    NULL,
    trust_level   TEXT    NOT NULL DEFAULT 'UNTRUSTED'
                          CONSTRAINT chk_ad_trust CHECK (trust_level IN (  -- [MC-0072] → A.65.04
                              'TRUSTED','CONDITIONALLY_TRUSTED','UNTRUSTED','QUARANTINE')),
    is_managed    BOOLEAN NOT NULL DEFAULT FALSE,
    mdm_device_id TEXT    NULL,
    is_osdp       BOOLEAN NOT NULL DEFAULT FALSE,
    osdp_address  TEXT    NULL,
    osdp_version  TEXT    NULL CONSTRAINT chk_ad_osdp CHECK (osdp_version IN ('v1.0','v2.1','v2.2') OR osdp_version IS NULL),  -- [MC-0069] → A.65.04
    status        TEXT    NOT NULL DEFAULT 'PENDING'
                          CONSTRAINT chk_ad_status CHECK (status IN (  -- [MC-0071] → A.65.04
                              'PENDING','ACTIVE','SUSPENDED','REVOKED','LOST','DECOMMISSIONED')),
    last_seen_at  TIMESTAMPTZ NULL,
    last_seen_ip  INET    NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id        TEXT    NOT NULL DEFAULT 'system',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ad_tenant_status ON bauth.auth_device (tenant_id, status) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ad_user          ON bauth.auth_device (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ad_trust         ON bauth.auth_device (trust_level) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ad_osdp          ON bauth.auth_device (tenant_id, osdp_address) WHERE is_osdp = TRUE;
COMMENT ON TABLE bauth.auth_device IS
'DISPOSITIVOS ZTA | Registro central de dispositivos del ecosistema SBOS — implementa el componente
Device Trust de Zero Trust Architecture. Cubre 9 categorías: equipos de usuario (DESKTOP/MOBILE/
TABLET), servidores (SERVER/IOT), hardware de autenticación física (SECURITY_KEY/SMART_CARD) y
lectores de control de acceso físico (OSDP_READER/NFC_READER). Campos clave: device_key (identidad
única del dispositivo), aaguid (UUID del modelo de autenticador FIDO2 — permite verificar en la
FIDO MDS si el modelo es certificado), trust_level (TRUSTED/CONDITIONALLY_TRUSTED/UNTRUSTED/
QUARANTINE — alimenta el PIP de riesgo), is_managed + mdm_device_id (para integración MDM), is_osdp
+ osdp_address + osdp_version (para lectores de acceso físico OSDP v2.2). user_id puede ser NULL
para servidores y dispositivos compartidos. El PDP de ZTA verifica trust_level antes de autorizar:
UNTRUSTED solo accede a recursos básicos; QUARANTINE bloquea todo acceso hasta resolución.
Fuente: registrado vía RPC bauth.device.register al enrolar un dispositivo; lectores OSDP registrados
automáticamente por el driver bnexus al detectarlos en el bus.
Administración: DEVICE_ADMIN registra/suspende/revoca dispositivos; el PDP actualiza last_seen_at e
last_seen_ip en cada autenticación exitosa; status=LOST bloquea el dispositivo inmediatamente.
WORM: no — trust_level, status y last_seen_at son mutables por diseño.
Particionada: no.
Estándar: NIST SP 800-207 §4.2 (ZTA Device Component), FIDO2 W3C L3 §4.1 (AAGUID), OSDP v2.2 SIA, NIST SP 800-63B-4 §5.1.9. T-390.';
COMMENT ON COLUMN bauth.auth_device.aaguid         IS 'AAGUID del modelo de autenticador FIDO2 (UUID asignado por el fabricante al modelo). Permite verificar en FIDO MDS3 si el modelo tiene certificación L1/L2/L3 y si no aparece en la lista de revocaciones. NULL para dispositivos no-FIDO2 (SMART_CARD, OSDP_READER, IOT).';
COMMENT ON COLUMN bauth.auth_device.trust_level     IS 'Nivel de confianza asignado por el PDP de ZTA: TRUSTED (administrado + postura OK + certificado), CONDITIONALLY_TRUSTED (alguna condición débil), UNTRUSTED (no administrado, solo acceso básico), QUARANTINE (señales de compromiso — acceso bloqueado hasta resolución).';
COMMENT ON COLUMN bauth.auth_device.mdm_device_id  IS 'ID del dispositivo en el sistema MDM (Microsoft Intune, Jamf, etc.). NULL si no está gestionado por MDM. Permite correlacionar con T-391 auth_device_posture.mdm_compliance para decidir trust_level.';
COMMENT ON COLUMN bauth.auth_device.osdp_address   IS 'Dirección de bus OSDP del lector de control de acceso físico (0-127). Solo presente cuando is_osdp=TRUE. El daemon bnexus usa esta dirección para enrutar comandos al lector correcto en el bus RS-485.';
COMMENT ON COLUMN bauth.auth_device.is_osdp        IS 'TRUE = es un lector de control de acceso físico comunicado por OSDP v2.2 (Open Supervised Device Protocol). Los lectores OSDP tienen semántica diferente: no están ligados a un user_id fijo sino a una ubicación física (osdp_address).';

CREATE TABLE IF NOT EXISTS bauth.auth_device_posture (
    posture_id          UUID     NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    device_id           UUID     NOT NULL REFERENCES bauth.auth_device(device_id) ON DELETE CASCADE,
    tenant_id           UUID     NOT NULL,
    disk_encrypted      BOOLEAN  NOT NULL DEFAULT FALSE,
    screen_lock_enabled BOOLEAN  NOT NULL DEFAULT FALSE,
    antivirus_active    BOOLEAN  NOT NULL DEFAULT FALSE,
    os_patches_current  BOOLEAN  NOT NULL DEFAULT FALSE,
    is_jailbroken       BOOLEAN  NOT NULL DEFAULT FALSE,
    mdm_enrolled        BOOLEAN  NOT NULL DEFAULT FALSE,
    mdm_provider        TEXT     NULL,
    mdm_compliance      TEXT     NOT NULL DEFAULT 'UNKNOWN'
                                 CONSTRAINT chk_adp_mdm CHECK (mdm_compliance IN ('COMPLIANT','NON_COMPLIANT','UNKNOWN')),  -- [MC-0075] → A.65.04
    risk_score          SMALLINT NOT NULL DEFAULT 50
                                 CONSTRAINT chk_adp_risk CHECK (risk_score BETWEEN 0 AND 100),
    compliance_status   TEXT     NOT NULL DEFAULT 'UNKNOWN'
                                 CONSTRAINT chk_adp_comp CHECK (compliance_status IN ('COMPLIANT','NON_COMPLIANT','UNKNOWN','EXEMPTED')),  -- [MC-0074] → A.65.04
    posture_source      TEXT     NOT NULL DEFAULT 'SELF_REPORTED'
                                 CONSTRAINT chk_adp_src CHECK (posture_source IN ('MDM','EDR','AGENT','SELF_REPORTED','MANUAL')),  -- [MC-0076] → A.65.04
    raw_report          JSONB    NULL,
    evaluated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '4 hours'),
    ctx_id              TEXT     NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_adp_device       ON bauth.auth_device_posture (device_id, evaluated_at DESC);
CREATE INDEX IF NOT EXISTS idx_adp_valid        ON bauth.auth_device_posture (device_id, valid_until) WHERE compliance_status = 'COMPLIANT';
CREATE INDEX IF NOT EXISTS idx_adp_noncompliant ON bauth.auth_device_posture (tenant_id, evaluated_at DESC) WHERE compliance_status = 'NON_COMPLIANT';
COMMENT ON TABLE bauth.auth_device_posture IS
'DISPOSITIVOS ZTA | Snapshot de postura de seguridad del dispositivo — evaluación periódica de
cumplimiento de controles de seguridad del endpoint. Fuente de decisión para el PDP de Zero Trust:
si valid_until < now() el PDP rechaza acceso aunque el dispositivo esté TRUSTED, forzando una
reevaluación de postura. Controles evaluados: disk_encrypted, screen_lock_enabled, antivirus_active,
os_patches_current, is_jailbroken (positivo = no cumple), mdm_enrolled + mdm_provider + mdm_compliance.
posture_source: MDM (Microsoft Intune/Jamf), EDR (Crowdstrike/SentinelOne), AGENT (agente bAuth),
SELF_REPORTED (declarado por el propio dispositivo — menor confianza) o MANUAL (admin).
risk_score (0-100): calculado por el motor ITDR de bAuth ponderando los controles evaluados — alimenta
el PIP de riesgo del Context Plane y puede disparar reglas en T-180 (ses_risk_policy). valid_until:
TTL de 4h — la postura expira y debe reevaluarse periódicamente para garantizar Zero Trust continuo.
compliance_status=EXEMPTED: dispositivos con exención temporal aprobada por SECURITY_ADMIN (ej.
dispositivos industriales que no soportan cifrado de disco).
Fuente: insertada por el agente MDM/EDR externo vía webhook, por el agente bAuth en el dispositivo,
o por el evaluador de postura del daemon al recibir la conexión mTLS del dispositivo.
Administración: el motor ITDR de bAuth evalúa automáticamente; SECURITY_ADMIN puede forzar una
reevaluación manual o marcar EXEMPTED con justificación.
WORM: no — cada snapshot es una fila nueva; la antigua queda histórica (sin DELETE).
Particionada: no (candidata por evaluated_at en entornos con muchos dispositivos).
Estándar: NIST SP 800-207 §3.3.1 (Device Policy), NIST SP 800-53 SC-28 (At-Rest Encryption). T-391.';
COMMENT ON COLUMN bauth.auth_device_posture.risk_score        IS 'Puntuación de riesgo 0-100 calculada por el motor ITDR ponderando los controles evaluados (0=sin riesgo, 100=compromiso total). Alimenta T-180 ses_risk_policy: si supera umbral configurable, dispara step-up o revocación de sesión.';
COMMENT ON COLUMN bauth.auth_device_posture.compliance_status IS 'Estado de cumplimiento consolidado: COMPLIANT (todos los controles OK), NON_COMPLIANT (al menos un control falla), UNKNOWN (aún no evaluado), EXEMPTED (exención aprobada por SECURITY_ADMIN — requiere justificación en raw_report).';
COMMENT ON COLUMN bauth.auth_device_posture.posture_source    IS 'Fuente de la evaluación de postura — determina la confianza del snapshot: MDM (autoridad externa, máxima confianza), EDR (telemetría de seguridad), AGENT (agente bAuth en el dispositivo), SELF_REPORTED (declarado por el dispositivo — menor confianza), MANUAL (admin con justificación).';
COMMENT ON COLUMN bauth.auth_device_posture.valid_until       IS 'TTL de esta evaluación de postura — por defecto now()+4h. El PDP rechaza acceso si valid_until < now() aunque compliance_status=COMPLIANT, forzando reevaluación periódica (principio Zero Trust de verificación continua, no solo al login).';

CREATE TABLE IF NOT EXISTS bauth.auth_device_credential_binding (
    binding_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    device_id     UUID    NOT NULL REFERENCES bauth.auth_device(device_id) ON DELETE CASCADE,
    credential_id UUID    NOT NULL REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    binding_type  TEXT    NOT NULL CONSTRAINT chk_adcb_type CHECK (binding_type IN (  -- [MC-0073] → A.65.04
                              'FIDO2_RESIDENT','FIDO2_CROSS_PLATFORM','X509_MTLS',
                              'SOFT_TOTP','PUSH_NOTIFICATION','OSDP_CARD')),
    is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
    bound_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at    TIMESTAMPTZ NULL,
    ctx_id        TEXT    NOT NULL DEFAULT 'system',
    CONSTRAINT uq_adcb_device_cred UNIQUE (device_id, credential_id)
);
REVOKE UPDATE, DELETE ON bauth.auth_device_credential_binding FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_adcb_device     ON bauth.auth_device_credential_binding (device_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_adcb_credential ON bauth.auth_device_credential_binding (credential_id) WHERE revoked_at IS NULL;
COMMENT ON TABLE bauth.auth_device_credential_binding IS
'DISPOSITIVOS ZTA | Registro WORM de la ligadura entre un dispositivo (T-390) y un autenticador
(T-330 auth_credential). Implementa el concepto "bound credential" de NIST SP 800-63B-4: una
credencial ligada a un dispositivo solo puede usarse desde ese dispositivo — protección fundamental
contra phishing de credenciales y robo de autenticadores portátiles. Tipos de binding: FIDO2_RESIDENT
(passkey nativa almacenada en el autenticador hardware), FIDO2_CROSS_PLATFORM (llave de seguridad
portátil FIDO2), X509_MTLS (certificado cliente ligado al TPM del dispositivo), SOFT_TOTP (semilla
TOTP instalada en el dispositivo), PUSH_NOTIFICATION (notificación push al dispositivo registrado),
OSDP_CARD (tarjeta OSDP ligada al lector físico). is_primary=TRUE: credencial de autenticación
principal del dispositivo — solo uno por dispositivo. revoked_at: marca la desligadura sin eliminar
el registro (trazabilidad forense de qué autenticador estuvo ligado a qué dispositivo y cuándo).
Fuente: creada por bAuth al completar el enrollment de un autenticador en un dispositivo (WebAuthn
registration, mTLS binding, TOTP provisioning); nunca por INSERT directo.
Administración: REVOKE UPDATE/DELETE aplicado; el daemon bAuth solo puede insertar; un admin con
DEVICE_ADMIN puede revocar (escribe revoked_at); la clave UNIQUE (device_id, credential_id) impide
duplicar el binding del mismo par dispositivo+credencial.
WORM: sí — REVOKE UPDATE/DELETE aplicado; el historial de bindings es evidencia de acceso físico.
Particionada: no.
Estándar: NIST SP 800-63B-4 §5.1.9 (bound authenticators), FIDO2 W3C L3 §7.3, RFC 8705 §4. T-392.';


-- ======================================================================
-- ÍNDICES COMPLEMENTARIOS — Relaciones clave entre schemas
-- ======================================================================
-- Índice para lookup de grants activos por átomo (id_atom = columna canónica)
CREATE INDEX IF NOT EXISTS idx_pag_id_atom
    ON bauth.privilege_atom_grant(id_atom)
    WHERE status = 'ACTIVE';

-- Índice de búsqueda rápida de nodos átomo activos por posición de bit
CREATE INDEX IF NOT EXISTS idx_irt_eval_active
    ON bauth.idn_roles_template(atom_position, verb_id)
    WHERE node_type = 'atom' AND is_active = true;


-- ======================================================================
-- NIVEL 12 — S13 USUARIOS (T-320..T-322)
-- Ref: A.65.02.04 v2.2.0 §1 · NIST SP 800-63-4 §3 · SCIM 2.0 RFC 7643/7644
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.idn_user (
    user_id              UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id            UUID         NOT NULL
                                      REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    entity_id            UUID         NOT NULL
                                      REFERENCES bauth.idn_identity_entity(entity_id),
    username             TEXT         NOT NULL,
    status               TEXT         NOT NULL DEFAULT 'PENDING_ACTIVATION'
                                      CONSTRAINT chk_iu_status CHECK (status IN (  -- [MC-0111] → A.65.04
                                          'PENDING_ACTIVATION','ACTIVE','LOCKED',
                                          'SUSPENDED','DEACTIVATED','ARCHIVED')),
    registration_method  TEXT         NOT NULL DEFAULT 'ADMIN'
                                      CONSTRAINT chk_iu_reg_method CHECK (registration_method IN (  -- [MC-0110] → A.65.04
                                          'ADMIN','SELF_SERVICE','PROVISIONED','FEDERATED')),
    ial_achieved         TEXT         NULL
                                      CONSTRAINT chk_iu_ial CHECK (ial_achieved IN ('IAL1','IAL2','IAL3')),
    loa_min              TEXT         NOT NULL DEFAULT 'AAL1'
                                      CONSTRAINT chk_iu_loa CHECK (loa_min IN ('AAL1','AAL2','AAL3')),
    failed_attempts      INT          NOT NULL DEFAULT 0,
    lockout_until        TIMESTAMPTZ  NULL,
    password_changed_at  TIMESTAMPTZ  NULL,
    must_change_password BOOLEAN      NOT NULL DEFAULT FALSE,
    last_login_at        TIMESTAMPTZ  NULL,
    last_login_ip        INET         NULL,
    scim_external_id     TEXT         NULL,
    wallet_id            UUID         NULL,
    ctx_id               TEXT         NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_iu_username_tenant UNIQUE (tenant_id, username),
    CONSTRAINT uq_iu_entity_tenant   UNIQUE (tenant_id, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_iu_status  ON bauth.idn_user (tenant_id, status) WHERE status IN ('ACTIVE','LOCKED');
CREATE INDEX IF NOT EXISTS idx_iu_entity  ON bauth.idn_user (entity_id);
CREATE INDEX IF NOT EXISTS idx_iu_lockout ON bauth.idn_user (lockout_until) WHERE lockout_until IS NOT NULL;
COMMENT ON TABLE bauth.idn_user IS
'USUARIOS | Subscriber Account (NIST SP 800-63-4 §3.1) — Capa 2 del modelo de identidad en capas:
la cuenta de login digital del tenant. Separada por diseño de: (1) identidad organizacional T-156
idn_identidad (quién es la persona), (2) autenticadores T-330 auth_credential (cómo se autentica),
y (3) privilegios T-041 idn_roles_rol_hierarchical (qué puede hacer). Esta separación permite que
una entidad tenga cuentas en múltiples tenants (un_contratista que accede a varios clientes SBOS)
sin duplicar su identidad base. Campos clave: username (único por tenant — UNIQUE tenant_id+username),
status (PENDING_ACTIVATION→ACTIVE→LOCKED/SUSPENDED→DEACTIVATED→ARCHIVED), ial_achieved (nivel
de proofing verificado: IAL1/IAL2/IAL3), loa_min (LoA mínimo que esta cuenta debe presentar para
autenticarse — overridable por política de recurso), failed_attempts + lockout_until (lockout
progresivo NIST 800-63B-4 §5.2.2), must_change_password (fuerza cambio en próximo login),
scim_external_id (ID en IdP externo para provisioning SCIM 2.0), wallet_id (referencia a billetera
blockchain si el tenant tiene dominio financiero D14).
Fuente: creada por el motor de registro de bAuth (vía ADMIN, SELF_SERVICE, PROVISIONED SCIM, o
FEDERATED por bróker OIDC/SAML); entity_id debe existir en T-156 antes de crear la cuenta.
Administración: USER_ADMIN gestiona ciclo de vida; el daemon bAuth actualiza failed_attempts,
lockout_until y last_login_at en cada intento; status=ARCHIVED es el estado final irreversible.
WORM: no — el historial de cambios vive en T-321 idn_user_history (hash-chain WORM).
Particionada: no.
Estándar: NIST SP 800-63-4 §3.1 (Subscriber Account), SCIM 2.0 RFC 7643, ISO 24760-2:2025. T-320.';
COMMENT ON COLUMN bauth.idn_user.ial_achieved        IS 'Identity Assurance Level verificado: IAL1 (autodeclarado), IAL2 (remoto verificado), IAL3 (presencial). NULL = proofing no realizado.';
COMMENT ON COLUMN bauth.idn_user.loa_min             IS 'Level of Assurance mínimo que esta cuenta debe presentar (AAL1/AAL2/AAL3). Overrideable por política del recurso destino.';
COMMENT ON COLUMN bauth.idn_user.registration_method IS 'Cómo fue creada la cuenta: ADMIN (por administrador), SELF_SERVICE (autoregistro), PROVISIONED (SCIM 2.0 de IdP externo), FEDERATED (bróker OIDC/SAML).';
COMMENT ON COLUMN bauth.idn_user.must_change_password IS 'Si TRUE, el motor de autenticación obliga al usuario a cambiar su contraseña en el próximo login antes de emitir el token de acceso.';
COMMENT ON COLUMN bauth.idn_user.scim_external_id    IS 'ID del usuario en el IdP externo que lo provisionó vía SCIM 2.0. NULL si no fue provisionado por SCIM.';
COMMENT ON COLUMN bauth.idn_user.wallet_id           IS 'FK a bauth.wallet — billetera digital del usuario para credenciales verificables (D17). NULL si el tenant no tiene dominio blockchain activo.';
COMMENT ON COLUMN bauth.idn_user.lockout_until       IS 'Hasta cuándo el usuario está bloqueado por fallos consecutivos. NULL = no bloqueado. Calculado: now() + lockout_minutes de T-337 auth_config.';
COMMENT ON COLUMN bauth.idn_user.failed_attempts     IS 'Contador de intentos fallidos consecutivos. Se resetea a 0 en cada autenticación exitosa. Lockout cuando supera el umbral de T-337 auth_config.';

CREATE TABLE IF NOT EXISTS bauth.idn_user_history (
    history_id  UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id   UUID         NOT NULL,
    field       TEXT         NOT NULL,
    old_value   JSONB        NULL,
    new_value   JSONB        NOT NULL,
    changed_by  UUID         NULL,
    reason      TEXT         NULL,
    ctx_id      TEXT         NOT NULL DEFAULT 'system',
    changed_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    prev_hash   TEXT         NULL
);
REVOKE UPDATE, DELETE ON bauth.idn_user_history FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_iuh_user ON bauth.idn_user_history (user_id, changed_at DESC);
COMMENT ON TABLE bauth.idn_user_history IS
'USUARIOS | Historial WORM hash-chain de todos los cambios en cuentas de usuario (T-320). Cada
modificación de cualquier campo de idn_user genera una fila aquí con: field (qué campo cambió),
old_value JSONB (valor anterior), new_value JSONB (valor nuevo), changed_by (quién cambió) y
prev_hash (SHA-256 de la fila anterior — forma la cadena de integridad). La hash-chain garantiza
que ningún registro puede modificarse silenciosamente: cualquier alteración rompe el hash del
siguiente eslabón, permitiendo detección forense de manipulación de auditoría.
Fuente: insertada por trigger de auditoría de bAuth en cada UPDATE a T-320 idn_user; también en
operaciones de ciclo de vida (suspensión, revocación, archivado) invocadas vía RPC.
Administración: REVOKE UPDATE/DELETE — solo el trigger del daemon bAuth puede insertar; el auditor
puede leer; el sistema de hash-chain verifica la integridad de toda la cadena de una cuenta con la
función fn_verify_user_history_chain(user_id) que recalcula los hashes secuencialmente.
WORM: sí — REVOKE UPDATE/DELETE aplicado; la integridad de la cadena es evidencia forense.
Particionada: no (candidata por changed_at en entornos con muchos usuarios y alta actividad).
Estándar: ISO 27001:2022 A.8.15, NIST SP 800-53 AU-9 (protection of audit info), GDPR Art. 30. T-321.';
COMMENT ON COLUMN bauth.idn_user_history.field      IS 'Nombre del campo de T-320 idn_user que fue modificado — ej. "email", "status", "loa_min". Permite filtrar el historial por campo específico y construir diff granular de la cuenta.';
COMMENT ON COLUMN bauth.idn_user_history.old_value  IS 'Valor anterior del campo en formato JSONB. JSONB permite almacenar cualquier tipo (texto, booleano, UUID, timestamp) sin pérdida de tipo. NULL si el campo no tenía valor previo (campo recién poblado).';
COMMENT ON COLUMN bauth.idn_user_history.new_value  IS 'Valor nuevo del campo en formato JSONB. NULL si el campo fue vaciado (ej. lockout_until cleared). La comparación old_value vs new_value reconstruye el cambio exacto aplicado.';
COMMENT ON COLUMN bauth.idn_user_history.prev_hash  IS 'SHA-256 de la fila anterior de esta cuenta en la hash-chain (hex). La primera fila de un user_id tiene prev_hash = SHA-256("genesis:"+user_id). Cualquier alteración a una fila previa rompe este hash, detectable con fn_verify_user_history_chain(user_id).';

CREATE TABLE IF NOT EXISTS bauth.idn_user_recovery (
    recovery_id UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id   UUID         NOT NULL,
    type        TEXT         NOT NULL
                             CONSTRAINT chk_iur_type CHECK (type IN (  -- [MC-0113] → A.65.04
                                 'BACKUP_EMAIL','BACKUP_PHONE','TRUSTED_CONTACT','ADMIN_OVERRIDE')),
    value_hash  TEXT         NULL,
    status      TEXT         NOT NULL DEFAULT 'ACTIVE'
                             CONSTRAINT chk_iur_status CHECK (status IN ('ACTIVE','USED','REVOKED')),  -- [MC-0112] → A.65.04
    valid_until TIMESTAMPTZ  NULL,
    used_at     TIMESTAMPTZ  NULL,
    ctx_id      TEXT         NOT NULL DEFAULT 'system',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iur_user_active ON bauth.idn_user_recovery (user_id, type) WHERE status = 'ACTIVE';
COMMENT ON TABLE bauth.idn_user_recovery IS
'USUARIOS | Métodos de recuperación de cuenta — alternativas de verificación de identidad cuando el
usuario pierde acceso a su autenticador principal. Tipos: BACKUP_EMAIL (correo secundario verificado),
BACKUP_PHONE (teléfono de respaldo verificado), TRUSTED_CONTACT (contacto de confianza designado),
ADMIN_OVERRIDE (restablecimiento manual por administrador con registro de auditoría). value_hash:
SHA-256 del valor del método de recuperación (dirección de correo, número de teléfono) — NUNCA el
valor en claro; el motor de bAuth verifica comparando el hash del valor presentado con value_hash.
valid_until: fecha de expiración del método de recuperación — los métodos expirados se excluyen del
flujo de recuperación. used_at: fecha en que se usó para recuperar la cuenta (status→USED).
OWASP ASVS 5.0 §2.5.4 prohíbe preguntas de seguridad como método de recuperación — esta tabla
implementa métodos conformes (backup email, backup phone, trusted contact), no preguntas.
Fuente: registrada por el usuario durante el onboarding o autogestión de cuenta vía RPC bauth.user.
recovery.add; ADMIN_OVERRIDE creado por USER_ADMIN con aprobación dual registrada en T-178.
Administración: el usuario puede agregar/revocar sus propios métodos de recuperación; un método
usado pasa a status=USED automáticamente (no se reutiliza); ADMIN_OVERRIDE requiere aprobación dual.
WORM: no — status es mutable (ACTIVE→USED/REVOKED) por diseño del flujo de recuperación.
Particionada: no.
Estándar: OWASP ASVS 5.0 §2.5 (account recovery), NIST SP 800-63B-4 §6.1.2. T-322.';


-- ======================================================================
-- NIVEL 13 — S14 AUTENTICACIÓN (T-330..T-338)
-- Ref: A.65.02.04 v2.2.0 §2 · NIST SP 800-63B-4 · FIDO2 W3C L3 · RFC 9470
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.auth_credential (
    credential_id         UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id               UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id             UUID         NOT NULL,
    method_code           TEXT         NOT NULL,
    status                TEXT         NOT NULL DEFAULT 'ACTIVE'
                                        CONSTRAINT chk_ac_status CHECK (status IN (  -- [MC-0062] → A.65.04
                                            'PENDING_ACTIVATION','ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    loa_provided          TEXT         NOT NULL
                                        CONSTRAINT chk_ac_loa CHECK (loa_provided IN ('AAL1','AAL2','AAL3')),  -- [MC-0061] → A.65.04
    is_primary            BOOLEAN      NOT NULL DEFAULT FALSE,
    is_phishing_resistant BOOLEAN      NOT NULL DEFAULT FALSE,
    enrolled_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    valid_from            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    valid_until           TIMESTAMPTZ  NULL,
    last_used_at          TIMESTAMPTZ  NULL,
    revoked_at            TIMESTAMPTZ  NULL,
    revocation_reason     TEXT         NULL,
    ctx_id                TEXT         NOT NULL DEFAULT 'system',
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ac_user_active ON bauth.auth_credential (user_id, method_code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ac_valid_until ON bauth.auth_credential (valid_until) WHERE valid_until IS NOT NULL AND status = 'ACTIVE';
COMMENT ON TABLE bauth.auth_credential IS
'AUTENTICACIÓN | Capa 3 — Authenticator binding (NIST SP 800-63-4 §5.1): registro del vínculo entre
un autenticador y la cuenta de usuario (T-320 idn_user). No contiene secretos — es el directorio
de qué autenticadores tiene enrollados cada usuario. Los secretos viven en tablas especializadas:
T-331 auth_credential_secret (password hash Argon2id, semilla TOTP/HOTP cifrada en Vault),
T-332 auth_credential_fido2 (clave pública COSE del autenticador FIDO2), T-333 auth_credential_x509
(certificado X.509 del cliente mTLS). Campos clave: method_code (código del método del MethodRegistry
T-335), loa_provided (qué AAL provee este autenticador: AAL1/AAL2/AAL3), is_primary (el autenticador
principal de la cuenta — solo uno por método), is_phishing_resistant (para decisiones de acceso a
recursos de alta seguridad), valid_from/valid_until (ventana de validez), revoked_at + revocation_reason
(auditoría de revocación). Una cuenta puede tener múltiples credenciales de distintos métodos;
el motor de autenticación selecciona la apropiada según la política de autenticación del recurso.
Fuente: creada por el motor de enrollment de bAuth al completar el registro de un nuevo autenticador;
nunca por INSERT directo (el enrollment verifica el autenticador antes de registrarlo).
Administración: el usuario puede ver sus propias credenciales; USER_ADMIN puede revocar; el job de
expiración escribe status=EXPIRED cuando valid_until < now(); revoked_at se escribe al revocar.
WORM: no — status, last_used_at y revoked_at son mutables por diseño del ciclo de vida.
Particionada: no.
Estándar: NIST SP 800-63-4 §5.1 (Authenticator types), FIDO2 W3C L3, RFC 6238 (TOTP), RFC 8705 (mTLS). T-330.';
COMMENT ON COLUMN bauth.auth_credential.method_code           IS 'Código del método de autenticación — referencia lógica al catálogo T-335 auth_method (ej. PASSWORD, TOTP, WEBAUTHN_PASSWORDLESS). No es FK física para evitar CASCADE.';
COMMENT ON COLUMN bauth.auth_credential.loa_provided          IS 'Level of Assurance que provee este autenticador al presentarlo exitosamente: AAL1 (knowledge), AAL2 (possession+knowledge), AAL3 (hardware resistente a phishing).';
COMMENT ON COLUMN bauth.auth_credential.is_phishing_resistant IS 'TRUE solo para WEBAUTHN_PASSWORDLESS, PASSKEY, X509_MTLS — métodos que no pueden ser capturados por phishing. El PDP lo verifica para acceso a recursos de alta seguridad (AAL3).';
COMMENT ON COLUMN bauth.auth_credential.is_primary            IS 'Solo un credential puede ser primario por método por usuario. El PDP selecciona el primary para el flujo de autenticación normal; los no-primary son de respaldo.';
COMMENT ON COLUMN bauth.auth_credential.valid_until           IS 'Fecha de expiración del autenticador. NULL = no expira. El job de expiración escribe status=EXPIRED cuando valid_until < now() y notifica al usuario.';
COMMENT ON COLUMN bauth.auth_credential.revocation_reason     IS 'Motivo de revocación en texto libre — requerido cuando revoked_at IS NOT NULL. Opciones típicas: COMPROMISED, LOST_DEVICE, USER_REQUEST, ROTATION.';

CREATE TABLE IF NOT EXISTS bauth.auth_credential_secret (
    secret_id           UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id       UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    type                TEXT    NOT NULL CONSTRAINT chk_acs_type CHECK (type IN (  -- [MC-0064] → A.65.04
                                 'ARGON2ID_HASH','TOTP_SEED_ENC','HOTP_SEED_ENC',
                                 'RECOVERY_CODE_HASH','PUSH_PUBKEY_ED25519')),
    secret              TEXT    NOT NULL,
    algorithm           TEXT    NOT NULL,
    params              JSONB   NOT NULL DEFAULT '{}',
    vault_key_version   INT     NOT NULL DEFAULT 1,
    rotated_at          TIMESTAMPTZ NULL,
    -- Verificación de contraseña comprometida — NIST SP 800-63B-4 §5.1.1.2
    -- Solo aplica a type=ARGON2ID_HASH; NULL en todos los demás tipos.
    -- El CHECK fuerza que toda contraseña haya pasado la verificación HIBP antes de guardarse.
    -- Implementación soberana: corpus HIBP local con k-Anonymity (SHA-1 prefix) — sin llamadas externas.
    hibp_checked_at     TIMESTAMPTZ NULL,
    hibp_pwned_count    INT         NULL,           -- 0 = no comprometida; >0 = rechazar
    hibp_is_compromised BOOLEAN     NOT NULL DEFAULT false,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_acs_hibp CHECK (
        type != 'ARGON2ID_HASH'
        OR (hibp_checked_at IS NOT NULL AND hibp_pwned_count IS NOT NULL)
    )
);
REVOKE UPDATE (secret) ON bauth.auth_credential_secret FROM bauth_app_role;
COMMENT ON TABLE bauth.auth_credential_secret IS
'AUTENTICACIÓN | Secretos cifrados de credenciales de conocimiento — almacena hashes y semillas
cifradas NUNCA en claro. Tipos: ARGON2ID_HASH (hash de contraseña con Argon2id m=64MB t=3 p=4,
parámetros mínimos NIST SP 800-63B-4 §5.1.1.2), TOTP_SEED_ENC (semilla TOTP cifrada con transit
encryption de Vault), HOTP_SEED_ENC (semilla HOTP cifrada), RECOVERY_CODE_HASH (hash de códigos
de recuperación de un solo uso), PUSH_PUBKEY_ED25519 (clave pública Ed25519 del dispositivo push).
secret: el valor cifrado o hasheado — NUNCA el valor en claro. algorithm: nombre del algoritmo
aplicado (ARGON2ID, AES-256-GCM-VAULT-TRANSIT). params JSONB: parámetros del algoritmo para que
el motor de verificación pueda reproducir la operación (ej. {m:65536, t:3, p:4, salt:"..."}).
vault_key_version: versión de la clave de cifrado en Vault transit — permite re-cifrado al rotar
la clave maestra sin invalidar todos los secretos. La columna secret tiene REVOKE UPDATE: no puede
modificarse directamente — el cambio de contraseña crea una fila nueva y elimina la anterior.
HIBP (Compromised credential lookup — NIST SP 800-63B-4 §5.1.1.2): hibp_checked_at registra
cuándo se verificó la contraseña contra el corpus local HIBP; hibp_pwned_count es el número de
apariciones en brechas (0 = limpia, >0 = rechazar); hibp_is_compromised resume el resultado.
El CHECK chk_acs_hibp fuerza que toda contraseña (ARGON2ID_HASH) haya pasado la verificación
antes de ser insertada — cumplimiento a nivel BD, no solo por convención de código. Verificación
soberana: corpus HIBP local con k-Anonymity (SHA-1 prefix 5 chars) — sin llamadas externas.
Fuente: creada por el motor de enrollment de bAuth al registrar una contraseña u OTP seed; el hash
se calcula en el daemon Rust (nunca en BD) antes de almacenar.
Administración: REVOKE UPDATE (secret) aplicado — el daemon solo puede INSERT o DELETE, nunca UPDATE
del secreto; rotación de clave Vault: el job de re-key lee con vault_key_version < current y re-cifra.
WORM: no formalmente — INSERT+DELETE para cambio de contraseña (nunca UPDATE del valor).
Particionada: no.
Estándar: NIST SP 800-63B-4 §5.1.1.2 (Argon2id + HIBP), NIST SP 800-132 (KDF), FIPS 140-3. T-331.';
COMMENT ON COLUMN bauth.auth_credential_secret.secret              IS 'El secreto protegido — NUNCA el valor en claro. Contiene el hash Argon2id (contraseñas), la semilla cifrada con Vault transit (TOTP/HOTP), o el hash de código de recuperación. La columna tiene REVOKE UPDATE: el daemon solo puede INSERT o DELETE, nunca modificar en sitio.';
COMMENT ON COLUMN bauth.auth_credential_secret.vault_key_version   IS 'Versión de la clave de cifrado en Vault KV transit usada para cifrar este secreto. Permite re-cifrado progresivo: el job de re-key busca filas con vault_key_version < current y las re-cifra sin interrumpir el servicio.';
COMMENT ON COLUMN bauth.auth_credential_secret.params              IS 'Parámetros del algoritmo de protección en JSONB. Para ARGON2ID: {m: 65536, t: 3, p: 4, salt: "<hex>"}. Para AES-256-GCM-VAULT-TRANSIT: {key_name: "bauth-credentials", version: N}. El motor de verificación los lee para reproducir la operación correctamente.';
COMMENT ON COLUMN bauth.auth_credential_secret.hibp_checked_at     IS '[NIST 800-63B-4 §5.1.1.2] Timestamp de la última verificación HIBP. NULL para tipos distintos de ARGON2ID_HASH. El CHECK chk_acs_hibp fuerza NOT NULL al insertar una contraseña.';
COMMENT ON COLUMN bauth.auth_credential_secret.hibp_pwned_count    IS '[NIST 800-63B-4 §5.1.1.2] Número de veces que la contraseña aparece en el corpus HIBP local. 0 = limpia (aceptar). >0 = comprometida (rechazar antes de insertar). NULL para tipos distintos de ARGON2ID_HASH.';
COMMENT ON COLUMN bauth.auth_credential_secret.hibp_is_compromised IS '[NIST 800-63B-4 §5.1.1.2] TRUE si hibp_pwned_count > 0. Una fila con TRUE indica que se intentó registrar una contraseña comprometida — el daemon debe rechazarla antes de INSERT; este registro permanece como evidencia forense de la verificación.';

CREATE TABLE IF NOT EXISTS bauth.auth_credential_fido2 (
    fido2_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id        UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    credential_id_bytes  BYTEA   NOT NULL,
    public_key_cose      BYTEA   NOT NULL,
    aaguid               UUID    NOT NULL,
    attestation_fmt      TEXT    NOT NULL CONSTRAINT chk_af2_fmt CHECK (attestation_fmt IN (  -- [MC-0063] → A.65.04
                                     'packed','tpm','fido-u2f','none','apple',
                                     'android-safetynet','android-key')),
    attestation_data     JSONB   NOT NULL DEFAULT '{}',
    sign_count           BIGINT  NOT NULL DEFAULT 0,
    is_discoverable      BOOLEAN NOT NULL DEFAULT FALSE,
    is_cross_platform    BOOLEAN NOT NULL DEFAULT FALSE,
    backup_eligible      BOOLEAN NOT NULL DEFAULT FALSE,
    backup_state         BOOLEAN NOT NULL DEFAULT FALSE,
    transports           TEXT[]  NOT NULL DEFAULT '{}',
    device_name          TEXT    NULL,
    ctx_id               TEXT    NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.auth_credential_fido2 IS
'AUTENTICACIÓN | Credenciales FIDO2/Passkey — datos del autenticador WebAuthn necesarios para
verificar las aserciones de autenticación del dispositivo. Una fila por credential enrollada.
Campos clave: credential_id_bytes (ID de la credencial en formato binario, asignado por el
autenticador), public_key_cose (clave pública COSE del par ECDSA/EdDSA — la clave privada nunca
sale del autenticador), aaguid (GUID del modelo de autenticador, verificable en la FIDO Metadata
Service para confirmar que el modelo es certificado L2/L3), attestation_fmt (formato de atestación
del fabricante), sign_count (contador anti-replay — cada uso incrementa en ≥ 1; WebAuthn §6.1 exige
rechazar aserciones con sign_count ≤ el registrado para detectar clonado del autenticador),
is_discoverable (passkey residente — puede autenticar sin username), is_cross_platform (llave de
seguridad externa, no TPM del dispositivo), backup_eligible + backup_state (sync en nube de la
passkey — importante para política: backupable=menor garantía de binding físico), transports
(BLE/USB/NFC/INTERNAL — cómo se comunica el autenticador con el cliente).
Fuente: creada por el motor de WebAuthn registration de bAuth al completar el ceremony de enrollment
(parseando el attestationObject del cliente); nunca por INSERT directo.
Administración: no modificable después del enrollment (la clave pública es inmutable); sign_count
se actualiza en cada autenticación exitosa; la credencial se elimina al revocar el auth_credential T-330.
WORM: no (sign_count debe actualizarse en cada uso).
Particionada: no.
Estándar: W3C WebAuthn L3 §6.1 (sign_count), FIDO2 CTAP 2.2, FIDO Alliance MDS3. T-332.';
COMMENT ON COLUMN bauth.auth_credential_fido2.aaguid            IS 'AAGUID del modelo de autenticador (UUID del fabricante/modelo). Verificable en FIDO MDS3 para confirmar nivel de certificación (L1/L2/L3). NULL para autenticadores none-attestation.';
COMMENT ON COLUMN bauth.auth_credential_fido2.sign_count        IS 'Contador monótonamente creciente. WebAuthn §6.1: el motor RECHAZA la aserción si sign_count ≤ al registrado, detectando clonado del autenticador. 0 indica autenticador que no soporta el contador.';
COMMENT ON COLUMN bauth.auth_credential_fido2.is_discoverable   IS 'TRUE = passkey residente (almacenada en el autenticador — puede autenticar sin username). FALSE = no residente (requiere username primero).';
COMMENT ON COLUMN bauth.auth_credential_fido2.backup_eligible   IS 'TRUE = la credencial puede sincronizarse en la nube del proveedor. Implica menor garantía de binding físico — el PDP puede requerir step-up para recursos AAL3 si backup_eligible=TRUE.';
COMMENT ON COLUMN bauth.auth_credential_fido2.backup_state      IS 'TRUE = la credencial está actualmente sincronizada en nube. Combinado con backup_eligible para evaluar el nivel de confianza del autenticador.';
COMMENT ON COLUMN bauth.auth_credential_fido2.credential_id_bytes IS 'ID de la credencial en bytes — asignado por el autenticador, único por origen. Se presenta en cada solicitud de autenticación para que el servidor ubique la credencial.';
COMMENT ON COLUMN bauth.auth_credential_fido2.public_key_cose   IS 'Clave pública en formato COSE (CBOR Object Signing and Encryption) — la clave privada NUNCA sale del autenticador. El motor verifica la firma de la aserción usando esta clave.';

CREATE TABLE IF NOT EXISTS bauth.auth_credential_x509 (
    x509_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id       UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    origin              TEXT    NOT NULL CONSTRAINT chk_ax509_origin CHECK (origin IN (  -- [MC-0065] → A.65.04
                                    'VAULT_INTERNAL','ADSIB_EXTERNA','ENTERPRISE_PKI','SELF_SIGNED')),
    subject_dn          TEXT    NOT NULL,
    issuer_dn           TEXT    NOT NULL,
    serial_number       TEXT    NOT NULL,
    fingerprint_sha256  TEXT    NOT NULL UNIQUE,
    not_before          TIMESTAMPTZ NOT NULL,
    not_after           TIMESTAMPTZ NOT NULL,
    san                 TEXT[]  NULL,
    key_usage           TEXT[]  NOT NULL DEFAULT '{}',
    extended_key_usage  TEXT[]  NOT NULL DEFAULT '{}',
    oid_adsib           TEXT    NULL,
    is_adsib_qualified  BOOLEAN NOT NULL DEFAULT FALSE,
    vault_path          TEXT    NULL,
    ocsp_url            TEXT    NULL,
    revoked_by_ca_at    TIMESTAMPTZ NULL,
    revocation_reason   TEXT    NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ax509_fingerprint ON bauth.auth_credential_x509 (fingerprint_sha256);
CREATE INDEX IF NOT EXISTS idx_ax509_not_after   ON bauth.auth_credential_x509 (not_after) WHERE revoked_by_ca_at IS NULL;
COMMENT ON TABLE bauth.auth_credential_x509 IS
'AUTENTICACIÓN | Metadatos de certificados X.509 para autenticación mTLS y firma digital calificada.
Almacena el certificado público y sus metadatos de verificación — la clave privada reside SIEMPRE en
el dispositivo (TPM) o en Vault (vault_path). Orígenes: VAULT_INTERNAL (CA interna SBOS, emitida por
el motor PKI de bAuth), ADSIB_EXTERNA (CA calificada boliviana, única con validez legal según Ley 164
para firma de documentos con efectos jurídicos), ENTERPRISE_PKI (CA empresarial del cliente importada),
SELF_SIGNED (solo para dev/test — rechazada en producción por política). Campos clave: fingerprint_sha256
(UNIQUE — identifica inequívocamente cualquier certificado), san (Subject Alternative Names — para
verificación de identidad del servidor/cliente), oid_adsib + is_adsib_qualified (OID del certificado
ADSIB y si tiene el nivel de calificación legal), ocsp_url (endpoint para verificación de revocación
en tiempo real — bAuth verifica OCSP antes de aceptar un certificado mTLS), revoked_by_ca_at
(fecha de revocación por el CA externo — detectada por el job de descarga de CRL/OCSP).
Fuente: creada por el motor de enrollment mTLS de bAuth al procesar el CSR y recibir el certificado
del CA; también al importar un certificado ADSIB externo.
Administración: not_after genera alerta a los 30 días de expiración; OCSP verificado periódicamente;
revoked_by_ca_at se escribe al detectar el certificado en la CRL de T-352.
WORM: no — revoked_by_ca_at y status son mutables por ciclo de vida del certificado.
Particionada: no.
Estándar: RFC 5280 §4 (X.509 v3), RFC 8705 (mTLS binding), Ley 164 Bolivia Art. 20, RFC 6960 (OCSP). T-333.';

CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log (
    attempt_id       UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id        UUID         NOT NULL,
    user_id          UUID         NULL,
    username_tried   TEXT         NULL,
    method_code      TEXT         NOT NULL,
    outcome          TEXT         NOT NULL CONSTRAINT chk_aal_outcome CHECK (outcome IN (  -- [MC-0059] → A.65.04
                                      'SUCCESS','FAILURE','LOCKED','STEP_UP_REQUIRED',
                                      'EXPIRED','INVALID_USER','REVOKED_CREDENTIAL')),
    failure_reason   TEXT         NULL,
    loa_requested    TEXT         NULL,
    loa_achieved     TEXT         NULL,
    ip_address       INET         NOT NULL,
    user_agent       TEXT         NULL,
    device_id        UUID         NULL,
    session_id       UUID         NULL,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    traceparent      TEXT         NULL,
    attempted_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
) PARTITION BY RANGE (attempted_at);
CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log_2026_07 PARTITION OF bauth.auth_attempt_log FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log_2026_08 PARTITION OF bauth.auth_attempt_log FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log_2026_09 PARTITION OF bauth.auth_attempt_log FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
REVOKE UPDATE, DELETE ON bauth.auth_attempt_log FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_aal_ip_failed   ON bauth.auth_attempt_log (ip_address, attempted_at DESC) WHERE outcome IN ('FAILURE','INVALID_USER');
CREATE INDEX IF NOT EXISTS idx_aal_user_failed ON bauth.auth_attempt_log (user_id, attempted_at DESC) WHERE outcome = 'FAILURE';
COMMENT ON TABLE bauth.auth_attempt_log IS
'AUTENTICACIÓN | Log WORM append-only particionado de todos los intentos de autenticación — fuente
de verdad para ITDR (brute-force, credential stuffing, account takeover) y requisito PCI DSS.
Una fila por intento: outcome (SUCCESS/FAILURE/LOCKED/STEP_UP_REQUIRED/EXPIRED/INVALID_USER/
REVOKED_CREDENTIAL), loa_requested vs loa_achieved (detecta downgrade attacks), ip_address
(detección de geografía anómala), user_agent (fingerprinting de cliente), device_id (correlación
ZTA), traceparent (W3C Trace Context para correlación con OpenTelemetry). username_tried: el username
presentado — NULL si no llegó a resolverse a un user_id (intentos con usernames inexistentes).
El motor ITDR de bAuth lee idx_aal_ip_failed para detectar N fallos desde la misma IP en ventana
deslizante (brute-force) y idx_aal_user_failed para detectar ataques de account takeover sobre un
usuario específico. failure_reason registra el motivo específico del fallo para diagnóstico.
Fuente: insertada por el motor de autenticación de bAuth en cada intento, exitoso o no;
REVOKE UPDATE/DELETE — nunca se modifican ni borran intentos de auditoría.
Administración: REVOKE UPDATE/DELETE aplicado — append-only; el job de particionado crea particiones
mensuales automáticamente (auth_attempt_log_YYYY_MM); job de retención archiva particiones > 12 meses.
WORM: sí — REVOKE UPDATE/DELETE aplicado; la tabla es evidencia forense de autenticación.
Particionada: sí — PARTITION BY RANGE(attempted_at), particiones mensuales.
Estándar: PCI DSS 4.0 Req 8.2.8 (log de intentos), NIST SP 800-53 AU-12, ISO 27001 A.8.15. T-334.';
COMMENT ON COLUMN bauth.auth_attempt_log.outcome       IS 'Resultado del intento: SUCCESS (autenticado), FAILURE (credencial incorrecta), LOCKED (cuenta bloqueada — lockout activo), STEP_UP_REQUIRED (LoA insuficiente para el recurso solicitado), EXPIRED (credencial caducada), INVALID_USER (username inexistente), REVOKED_CREDENTIAL (credencial revocada).';
COMMENT ON COLUMN bauth.auth_attempt_log.loa_requested IS 'Level of Assurance que exigía el recurso destino al momento del intento. Comparar con loa_achieved permite detectar downgrade attacks: si loa_requested=AAL3 y loa_achieved=AAL1, el PDP debería haber bloqueado (indica posible bug).';
COMMENT ON COLUMN bauth.auth_attempt_log.loa_achieved  IS 'Level of Assurance realmente alcanzado en este intento. NULL si outcome=FAILURE (no se completó la autenticación). Comparar con loa_requested para verificar que el PDP no aceptó un LoA inferior al requerido.';
COMMENT ON COLUMN bauth.auth_attempt_log.username_tried IS 'Username tal como fue presentado en el intento — antes de resolución a user_id. NULL si el request no llegó a la fase de resolución. Útil para detectar enumeration attacks: muchos INVALID_USER con patrones similares desde la misma IP.';
COMMENT ON COLUMN bauth.auth_attempt_log.failure_reason IS 'Motivo técnico del fallo — complementa outcome para diagnóstico ITDR: WRONG_PASSWORD, EXPIRED_TOTP, INVALID_OTP_CODE, WEBAUTHN_SIGNATURE_FAILED, ACCOUNT_SUSPENDED, MAX_ATTEMPTS_EXCEEDED, etc. Texto libre del motor de autenticación.';

-- MethodRegistry declarativo (T-335..T-338)
CREATE TABLE IF NOT EXISTS bauth.auth_method (
    method_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code                  TEXT    NOT NULL UNIQUE,
    category              TEXT    NOT NULL CONSTRAINT chk_am_cat CHECK (category IN ('A','B','C','D','E','F')),  -- [MC-0078] → A.65.04
    name                  JSONB   NOT NULL,
    description           JSONB   NOT NULL,
    loa_provided          TEXT    NOT NULL CONSTRAINT chk_am_loa CHECK (loa_provided IN ('AAL1','AAL2','AAL3')),
    is_phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    is_mfa_component      BOOLEAN NOT NULL DEFAULT FALSE,
    status                TEXT    NOT NULL DEFAULT 'PLANNED'
                                   CONSTRAINT chk_am_status CHECK (status IN ('IMPLEMENTED','PLANNED','DEPRECATED','REMOVED')),  -- [MC-0079] → A.65.04
    standards             TEXT[]  NOT NULL DEFAULT '{}',
    sort_order            INT     NOT NULL DEFAULT 0
);
COMMENT ON TABLE bauth.auth_method IS
'AUTENTICACIÓN | Catálogo declarativo del MethodRegistry — define los 47 métodos de autenticación en 6 categorías (A-F) con su nivel de aseguramiento (LoA), resistencia a phishing, componente MFA y estado de implementación.
Fuente: seed de despliegue con los 47 métodos canónicos del Authentication Framework v3.0.0; el motor de bAuth consulta esta tabla al validar el método presentado por el cliente.
Administración: tabla de referencia — cambios solo vía migración con HITL; status=REMOVED significa que el código Rust fue eliminado; status=PLANNED es el estado previo a la implementación; métodos DEPRECATED no se ofrecen al cliente pero aún se validan para sesiones históricas.
WORM: no (status evoluciona durante el ciclo de vida del método).
Particionada: no.
Seed: DDLs/seeds/bauth_T335__auth_method.sql — idempotente ON CONFLICT (code).
Estándar: NIST SP 800-63B-4 §5 (tipos de autenticadores), FIDO2/WebAuthn W3C §8, RFC 6238 (TOTP), RFC 4226 (HOTP), RFC 9470 (Step-Up). T-335.';


CREATE TABLE IF NOT EXISTS bauth.auth_policy (
    policy_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),
    name             TEXT    NOT NULL,
    description      TEXT    NOT NULL,
    loa_required     TEXT    NOT NULL CONSTRAINT chk_ap_loa CHECK (loa_required IN ('AAL1','AAL2','AAL3')),
    allowed_methods  TEXT[]  NOT NULL DEFAULT '{}',
    required_methods TEXT[]  NOT NULL DEFAULT '{}',
    max_session_secs INT     NULL,
    step_up_trigger  JSONB   NULL,
    active           BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.auth_policy IS
'AUTENTICACIÓN | Políticas de autenticación por contexto — define el LoA mínimo requerido, los métodos permitidos y requeridos, el TTL de sesión y las condiciones de step-up para cada contexto de autenticación (global o por tenant).
Fuente: seed con políticas globales por defecto; políticas de tenant creadas por SECURITY_ADMIN vía RPC bauth.auth.policy.create al onboarding; tenant_id=NULL es la política global base.
Administración: el PDP de bAuth evalúa la política más específica (tenant_id) antes que la global; allowed_methods vacío significa cualquier método del catálogo; step_up_trigger JSONB define condiciones de elevación RFC 9470.
WORM: no.
Particionada: no.
Estándar: NIST SP 800-63B-4 §4 (AAL selection), RFC 9470 (Step-Up Authentication), FAPI 2.0 §4.3, ISO 27001 A.5.18. T-336.';


CREATE TABLE IF NOT EXISTS bauth.auth_config (
    config_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id    UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),
    key          TEXT    NOT NULL,
    value        JSONB   NOT NULL,
    description  TEXT    NOT NULL,
    effective_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    CONSTRAINT uq_auth_config_key UNIQUE (tenant_id, key)
);
COMMENT ON TABLE bauth.auth_config IS
'AUTENTICACIÓN | Parámetros técnicos del motor de autenticación sin hardcode — almacena todos los valores configurables de bAuth en pares clave-valor JSONB con vigencia desde effective_at, permitiendo cambio en runtime sin redespliegue.
Fuente: seed con parámetros iniciales seguros (lockout_attempts=5, lockout_minutes=15, argon2id_memory=65536, etc.); SECURITY_ADMIN puede actualizar vía RPC bauth.config.set con ctx_id y privilegio CONFIG_ADMIN.
Administración: UNIQUE (tenant_id, key) — una entrada por clave por tenant; tenant_id=NULL es el valor global; el motor bAuth recarga en caché Redis cada 5 minutos; cambios de seguridad críticos (KDF params) requieren HITL.
WORM: no (actualizaciones de parámetros son el propósito de esta tabla).
Particionada: no.
Estándar: NIST SP 800-63B-4 §5.1 (parámetros de contraseña), OWASP ASVS 5.0 §2.1 (account security), PCI DSS 4.0 Req 8.2. T-337.';


CREATE TABLE IF NOT EXISTS bauth.auth_crypto_algorithm (
    algo_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code           TEXT    NOT NULL UNIQUE,
    type           TEXT    NOT NULL CONSTRAINT chk_aca_type CHECK (type IN (  -- [MC-0067] → A.65.04
                               'KDF','SYMMETRIC','ASYMMETRIC_SIG','ASYMMETRIC_KEM','HASH','PQC')),
    is_pqc         BOOLEAN NOT NULL DEFAULT FALSE,
    default_params JSONB   NOT NULL DEFAULT '{}',
    status         TEXT    NOT NULL DEFAULT 'APPROVED'
                            CONSTRAINT chk_aca_status CHECK (status IN ('APPROVED','DEPRECATED','FORBIDDEN')),  -- [MC-0066] → A.65.04
    nist_ref       TEXT    NULL,
    deprecated_at  TIMESTAMPTZ NULL
);
COMMENT ON TABLE bauth.auth_crypto_algorithm IS
'AUTENTICACIÓN | Registro de algoritmos criptográficos con estado de aprobación NIST — catálogo local CAVP que define qué algoritmos están APPROVED (seguros), DEPRECATED (en transición) o FORBIDDEN (prohibidos) para el motor de bAuth.
Fuente: seed con algoritmos vigentes al despliegue (APPROVED: ARGON2ID, AES-256-GCM, ED25519, ML-KEM-768/FIPS-203, ML-DSA-65/FIPS-204; FORBIDDEN: MD5, SHA-1, RSA-1024, DES, 3DES); actualización solo vía migración DDL con HITL al publicarse nuevos FIPS.
Administración: tabla de referencia inmutable en runtime — status=FORBIDDEN rechaza operaciones en el motor Rust antes de ejecutarlas; is_pqc=true marca algoritmos post-cuánticos FIPS 203/204/205; nist_ref apunta al documento FIPS o SP correspondiente.
WORM: no (status se actualiza al cambiar normativa NIST).
Particionada: no.
Estándar: NIST FIPS 140-3, FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), FIPS 205 (SLH-DSA), NIST SP 800-131A R2, NIST SP 800-227. T-338.';



-- ======================================================================
-- NIVEL 14 — S15 FIRMA DIGITAL D13 (T-350..T-357)
-- Ref: A.65.02.04 v2.2.0 §3 · Ley 164 Bolivia · eIDAS 2.0 · RFC 5280
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.sig_key (
    key_id              UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id           UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    engine              TEXT    NOT NULL CONSTRAINT chk_sk_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB')),
    vault_path          TEXT    NOT NULL,
    vault_key_version   INT     NOT NULL DEFAULT 1,
    algorithm           TEXT    NOT NULL,
    purpose             TEXT    NOT NULL CONSTRAINT chk_sk_purpose CHECK (purpose IN (  -- [MC-0254] → A.65.04
                            'JWT_SIGNING','DOCUMENT_SIGNING','CODE_SIGNING',
                            'TLS_CLIENT','ADSIB_BILLING','ADSIB_CONTRACTS')),
    root_ca_fingerprint TEXT    NULL,
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_sk_status CHECK (  -- [MC-0255] → A.65.04
                            status IN ('ACTIVE','ROTATING','SUSPENDED','REVOKED')),
    active_since        TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NULL,
    next_rotation       TIMESTAMPTZ NULL,
    rotated_at          TIMESTAMPTZ NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sk_tenant_active ON bauth.sig_key (tenant_id, engine, purpose) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sk_rotation      ON bauth.sig_key (next_rotation) WHERE status = 'ACTIVE' AND next_rotation IS NOT NULL;
COMMENT ON TABLE bauth.sig_key IS
'FIRMA DIGITAL | Referencias a llaves criptográficas almacenadas en Vault — NUNCA contiene claves privadas en BD; solo la ruta Vault (vault_path) y metadatos de propósito, algoritmo y estado de rotación. Motor doble: Ed25519 interno + RSA externo ADSIB.
Fuente: creado por el motor de inicialización PKI de bAuth al generar una nueva llave en Vault; también al importar un certificado ADSIB externo; la clave privada nunca sale de Vault.
Administración: rotación automática controlada por next_rotation; status=ROTATING durante el proceso de rotación; REVOKED tras compromiso; un job diario alerta sobre llaves cuyo expires_at está dentro de 30 días.
WORM: no (status y next_rotation se actualizan durante el ciclo de vida de la llave).
Particionada: no.
Estándar: Ley 164 Bolivia Art. 9-11 (firma digital), ADSIB-FD-POLT-015 v2.3, NIST SP 800-57 Pt1 R5 §5.3 (clave privada en HSM/Vault). T-350.';


CREATE TABLE IF NOT EXISTS bauth.sig_certificate (
    cert_id            UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    key_id             UUID    NOT NULL REFERENCES bauth.sig_key(key_id) ON DELETE CASCADE,
    tenant_id          UUID    NOT NULL,
    engine             TEXT    NOT NULL CONSTRAINT chk_sc_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB','ENTERPRISE_PKI')),  -- [MC-0249] → A.65.04
    subject_dn         TEXT    NOT NULL,
    issuer_dn          TEXT    NOT NULL,
    serial_number      TEXT    NOT NULL,
    fingerprint_sha256 TEXT    NOT NULL UNIQUE,
    not_before         TIMESTAMPTZ NOT NULL,
    not_after          TIMESTAMPTZ NOT NULL,
    san                TEXT[]  NULL,
    key_usage          TEXT[]  NOT NULL DEFAULT '{}',
    cert_pem           TEXT    NOT NULL,
    adsib_type         TEXT    NULL CONSTRAINT chk_sc_adsib CHECK (adsib_type IN ('PERSONA_NATURAL','PERSONA_JURIDICA','FIRMA_AUTOMATICA')),  -- [MC-0248] → A.65.04
    issuer_nit         TEXT    NULL,
    status             TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_sc_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    revoked_by_ca_at   TIMESTAMPTZ NULL,
    ocsp_url           TEXT    NULL,
    ocsp_verified_at   TIMESTAMPTZ NULL,
    ctx_id             TEXT    NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sc_tenant_active ON bauth.sig_certificate (tenant_id, engine) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sc_expiry        ON bauth.sig_certificate (not_after) WHERE status = 'ACTIVE';
COMMENT ON TABLE bauth.sig_certificate IS
'FIRMA DIGITAL | Catálogo X.509 de certificados públicos — almacena el PEM del certificado público (nunca la clave privada); cubre SBOS Root CA, ADSIB CA (cadena ATT→ADSIB→Persona), y certificados de empresa/TLS.
Fuente: insertado automáticamente por el motor PKI de bAuth al emitir o renovar un certificado; los ADSIB son importados al contratar el servicio de firma calificada con ADSIB Bolivia.
Administración: job diario verifica not_after y alerta con 30 días de anticipación; OCSP verificado periódicamente (ocsp_verified_at); REVOKED tras notificación del CA; fingerprint_sha256 es UNIQUE para identificar inequívocamente cualquier certificado.
WORM: no (status y revoked_by_ca_at se actualizan durante el ciclo de vida).
Particionada: no.
Estándar: RFC 5280 §6 (X.509 v3), Ley 164 Bolivia Art. 20, ADSIB-FD-POLT-015 v2.3, RFC 6960 (OCSP). T-351.';


CREATE TABLE IF NOT EXISTS bauth.sig_crl (
    crl_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    issuer_dn     TEXT    NOT NULL,
    engine        TEXT    NOT NULL CONSTRAINT chk_scrl_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB')),  -- [MC-0250] → A.65.04
    crl_der       BYTEA   NOT NULL,
    next_update   TIMESTAMPTZ NOT NULL,
    downloaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id        TEXT    NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_scrl_next_update ON bauth.sig_crl (next_update);
COMMENT ON TABLE bauth.sig_crl IS
'FIRMA DIGITAL | Certificate Revocation Lists (CRL) activas descargadas de los CAs del sistema —
permite verificar la revocación de certificados X.509 sin consultar OCSP en tiempo real para cada
autenticación. Una fila por CRL vigente de cada CA: INTERNAL_VAULT (CA interna SBOS, descargada
cada 24h) y EXTERNAL_ADSIB (CA boliviana calificada, descargada cada hora por su mayor frecuencia
de actualización). crl_der: CRL en formato DER (binario ASN.1 — formato estándar RFC 5280 §5).
next_update: fecha hasta la que la CRL es válida según el CA — el job de descarga refresca antes
de next_update. El motor de verificación mTLS de bAuth consulta esta tabla para revocaciones offline;
la verificación OCSP en línea (sig_certificate.ocsp_url) es el mecanismo primario, la CRL es el
fallback cuando OCSP no está disponible. Una CRL desactualizada (next_update < now()) genera alerta.
Fuente: descargada automáticamente por el job de revocación de bAuth (crl_refresh_job.rs) desde los
CRL distribution points de cada CA; no se inserta manualmente.
Administración: el job de descarga inserta filas nuevas y elimina CRLs expiradas; PKI_ADMIN puede
forzar una descarga manual vía RPC bauth.pki.crl.refresh para respuesta a incidentes de compromiso.
WORM: no — filas CRL expiradas se reemplazan por las nuevas.
Particionada: no.
Estándar: RFC 5280 §5 (CRL), Ley 164 Bolivia Art. 20, ADSIB-FD-POLT-015 v2.3, RFC 6960 (OCSP). T-352.';

CREATE TABLE IF NOT EXISTS bauth.sig_timestamp (
    timestamp_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tsa_url          TEXT    NOT NULL,
    document_hash    TEXT    NOT NULL,
    tsa_response_der BYTEA   NOT NULL,
    tsa_serial       TEXT    NOT NULL,
    gen_time         TIMESTAMPTZ NOT NULL,
    policy_oid       TEXT    NULL,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON bauth.sig_timestamp FROM bauth_app_role;
COMMENT ON TABLE bauth.sig_timestamp IS
'FIRMA DIGITAL | Timestamps calificados (RFC 3161) obtenidos de Autoridades de Sellado de Tiempo
(TSA) acreditadas — proveen prueba criptográfica irrefutable de que un documento existía en un
momento específico (non-repudiation temporal). Una fila por timestamp emitido: tsa_url (URL del
servicio TSA ADSIB o interno), document_hash (SHA-256 del documento sobre el que se emite el
sello — nunca el documento en claro), tsa_response_der (respuesta binaria DER del TSA que contiene
el sello con firma del TSA), tsa_serial (número de serie único del TSA para trazabilidad), gen_time
(momento exacto del sello según el TSA — certificado por el CA acreditado). policy_oid: identifica
la política de sellado del TSA (ej. para facturas SIN Bolivia el OID determina la validez jurídica).
Los timestamps son referenciados desde sig_document_hash (T-354) para anclar documentos firmados
con sellado temporal calificado, requerido por ETSI EN 319 102-1 para firma PAdES-LTA y XAdES-LTA.
Fuente: obtenido por el motor de firma de bAuth al completar una firma que requiere sellado temporal;
el TSA nunca recibe el documento, solo su hash (privacidad garantizada por RFC 3161 §2.4.1).
Administración: REVOKE UPDATE/DELETE — solo el motor de firma de bAuth puede insertar; el auditor
puede leer para verificación forense; los timestamps no expiran (son evidencia permanente).
WORM: sí — REVOKE UPDATE/DELETE aplicado; el sello temporal es evidencia jurídica irrevocable.
Particionada: no.
Estándar: RFC 3161 (TSP), ETSI EN 319 421 (TSA Policy), Ley 164 Bolivia, ETSI EN 319 102-1. T-355.';

CREATE TABLE IF NOT EXISTS bauth.sig_operation_log (
    operation_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID    NOT NULL,
    key_id           UUID    NOT NULL REFERENCES bauth.sig_key(key_id),
    cert_id          UUID    NULL     REFERENCES bauth.sig_certificate(cert_id),
    engine           TEXT    NOT NULL CONSTRAINT chk_sol_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB')),
    document_hash    TEXT    NOT NULL,
    document_type    TEXT    NOT NULL,
    signature_format TEXT    NOT NULL,
    signed_by        UUID    NOT NULL,
    signer_type      TEXT    NOT NULL CONSTRAINT chk_sol_stype CHECK (signer_type IN ('HUMAN','NHI','DAEMON')),  -- [MC-0257] → A.65.04
    purpose          TEXT    NOT NULL,
    outcome          TEXT    NOT NULL CONSTRAINT chk_sol_outcome CHECK (outcome IN ('SUCCESS','FAILURE','CERT_EXPIRED','CERT_REVOKED')),  -- [MC-0256] → A.65.04
    signature_ref    TEXT    NULL,
    error_msg        TEXT    NULL,
    merkle_batch_id  UUID    NULL,
    onchain_tx_hash  TEXT    NULL,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    traceparent      TEXT    NULL,
    signed_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON bauth.sig_operation_log FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_sol_tenant_at ON bauth.sig_operation_log (tenant_id, signed_at DESC);
CREATE INDEX IF NOT EXISTS idx_sol_doc_hash  ON bauth.sig_operation_log (document_hash);
COMMENT ON TABLE bauth.sig_operation_log IS
'FIRMA DIGITAL | Log WORM forense de cada acto de firma digital — registra qué se firmó (hash SHA-256), quién firmó (signed_by), con qué llave y motor, el formato resultante, y el ancla blockchain opcional para trazabilidad legal completa.
Fuente: insertado automáticamente por el motor de firma de bAuth al completar cada operación de firma (exitosa o fallida); el documento en claro NUNCA llega a bAuth — solo su hash SHA-256.
Administración: REVOKE UPDATE/DELETE — append-only; el job de anclaje blockchain lee las operaciones recientes para incluirlas en el árbol Merkle; FAILURE registra el motivo en error_msg para forensia.
WORM: sí — el log de firma es evidencia legal del acto de firma según Ley 164; modificarlo invalidaría la trazabilidad forense requerida por el reglamento boliviano.
Particionada: no.
Estándar: Ley 164 Bolivia Art. 9 (no repudio), ETSI EN 319 102-1 §5, ISO 27001 A.8.15. T-353.';


CREATE TABLE IF NOT EXISTS bauth.sig_document_hash (
    document_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id           UUID    NOT NULL,
    operation_id        UUID    NOT NULL REFERENCES bauth.sig_operation_log(operation_id),
    hash_sha256         TEXT    NOT NULL UNIQUE,
    hash_sha3_256       TEXT    NULL,
    document_type       TEXT    NOT NULL,
    title               TEXT    NULL,
    signature_format    TEXT    NOT NULL,
    timestamp_id        UUID    NULL REFERENCES bauth.sig_timestamp(timestamp_id),
    blockchain_anchored BOOLEAN NOT NULL DEFAULT FALSE,
    merkle_batch_id     UUID    NULL,
    onchain_tx_hash     TEXT    NULL,
    retention_years     INT     NOT NULL DEFAULT 7,
    purge_after         TIMESTAMPTZ NOT NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    signed_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON bauth.sig_document_hash FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_sdh_hash  ON bauth.sig_document_hash (hash_sha256);
CREATE INDEX IF NOT EXISTS idx_sdh_purge ON bauth.sig_document_hash (purge_after);
COMMENT ON TABLE bauth.sig_document_hash IS
'FIRMA DIGITAL | Registro WORM de hashes SHA-256 (y SHA3-256 opcional) de documentos firmados — permite verificar la integridad del documento en cualquier punto del período de retención sin almacenar el documento en BD; las facturas SIN tienen retención de 8 años.
Fuente: insertado automáticamente por el motor de firma de bAuth al completar una firma exitosa; el purge_after se calcula desde retention_years al momento de insertar; el documento en claro vive fuera de la BD (almacenamiento documental).
Administración: REVOKE UPDATE/DELETE — append-only; job de purga comprueba purge_after y marca (no borra) registros elegibles para archivo; los anclados en blockchain no se purgan hasta cumplir retención legal mínima.
WORM: sí — los hashes de documentos firmados son evidencia de integridad post-firma; modificarlos rompería la cadena de custodia legal requerida por Ley 164 Bolivia.
Particionada: no.
Estándar: Ley 164 Bolivia Art. 9 + DS 1793 §18 (retención 8 años facturas SIN), ETSI EN 319 132 (PAdES), SHA-256/SHA3-256 FIPS 180-4/202. T-354.';


CREATE TABLE IF NOT EXISTS bauth.sig_adsib_lifecycle (
    lifecycle_id   UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    cert_id        UUID    NOT NULL REFERENCES bauth.sig_certificate(cert_id),
    event          TEXT    NOT NULL CONSTRAINT chk_sal_event CHECK (event IN (  -- [MC-0247] → A.65.04
                       'ISSUED','ACTIVATED','ALERT_30D','ALERT_15D','ALERT_7D',
                       'RENEWAL_CSR','RENEWED','EXPIRED','REVOKED_BY_CA','REISSUED')),
    description    TEXT    NULL,
    reissue_number INT     NULL CHECK (reissue_number <= 4),
    ctx_id         TEXT    NOT NULL DEFAULT 'system',
    event_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON bauth.sig_adsib_lifecycle FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_sal_tenant ON bauth.sig_adsib_lifecycle (tenant_id, event_at DESC);
COMMENT ON TABLE bauth.sig_adsib_lifecycle IS
'FIRMA DIGITAL | Log WORM del ciclo de vida de certificados ADSIB — registra cada evento (emisión, alertas de vencimiento, renovación, reemisión, revocación) con su fecha; máximo 4 reemisiones por certificado según normativa ADSIB Bolivia.
Fuente: insertado por el motor de gestión de certificados ADSIB de bAuth al ocurrir cada evento; los eventos ALERT_30D/15D/7D los genera el job diario de monitoreo de certificados.
Administración: REVOKE UPDATE/DELETE — append-only; reissue_number≤4 enforced por CHECK; el evento REVOKED_BY_CA requiere notificación inmediata al SECURITY_ADMIN del tenant; este log es la evidencia para auditorías ADSIB y Ley 164.
WORM: sí — el historial de eventos del certificado ADSIB es evidencia de cumplimiento del ciclo de vida normativo; modificarlo invalidaría el registro ante ADSIB.
Particionada: no.
Estándar: ADSIB-FD-POLT-015 v2.3 §5 (ciclo de vida), Ley 164 Bolivia Art. 18-20, RFC 5280 §4.2.1.13 (revocación). T-356.';


CREATE TABLE IF NOT EXISTS bauth.sig_document_policy (
    policy_id                  UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id                  UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),
    document_type              TEXT    NOT NULL,
    engine_required            TEXT    NOT NULL CONSTRAINT chk_sdp_eng CHECK (engine_required IN ('INTERNAL_VAULT','EXTERNAL_ADSIB','BOTH')),  -- [MC-0251] → A.65.04
    legal_basis                TEXT    NOT NULL,
    internal_profile           TEXT    NULL CONSTRAINT chk_sdp_int CHECK (internal_profile IN ('JWS','INT-B','INT-T','INT-LT')),  -- [MC-0253] → A.65.04
    external_profile           TEXT    NULL CONSTRAINT chk_sdp_ext CHECK (external_profile IN ('XAdES-BES','EXT-B','EXT-T','EXT-LT','EXT-LTA')),  -- [MC-0252] → A.65.04
    min_retention_years        INT     NOT NULL DEFAULT 7,
    requires_timestamp         BOOLEAN NOT NULL DEFAULT FALSE,
    requires_blockchain_anchor BOOLEAN NOT NULL DEFAULT FALSE,
    active                     BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id                     TEXT    NOT NULL DEFAULT 'system',
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_sdp_type_tenant UNIQUE (tenant_id, document_type)
);
CREATE INDEX IF NOT EXISTS idx_sdp_active ON bauth.sig_document_policy (document_type) WHERE active = TRUE;
COMMENT ON TABLE bauth.sig_document_policy IS
'FIRMA DIGITAL | Política del motor de firma por tipo de documento — define si se requiere el motor interno (Vault Ed25519), el externo (ADSIB RSA), o ambos; el perfil de firma (JWS/PAdES/CAdES/XAdES), la retención mínima y si requiere timestamp calificado o ancla blockchain.
Fuente: seed con políticas por tipo de documento (FACTURA_SIN: EXTERNAL_ADSIB+EXT-LTA+8 años, CONTRATO: BOTH+EXT-LT+10 años, JWT: INTERNAL_VAULT+JWS+1 año); configurable por SECURITY_ADMIN del tenant.
Administración: UNIQUE (tenant_id, document_type); evaluada por el motor de firma al recibir una solicitud; active=false desactiva el tipo sin borrarlo; legal_basis documenta la norma que exige cada requisito.
WORM: no.
Particionada: no.
Estándar: Ley 164 Bolivia Art. 82 (tipos de documentos digitales), ETSI EN 319 132 (PAdES), ETSI EN 319 122 (CAdES), ETSI EN 319 132-3 (XAdES). T-357.';



-- ======================================================================
-- NIVEL 15 — D12 BLOCKCHAIN (T-358..T-362)
-- Ref: A.65.02.04 v2.2.0 §4 · RFC 6962 · FIPS 202 · QBFT/IBFT 2.0
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.blk_merkle_batch (
    batch_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    merkle_root  TEXT    NULL,
    event_from   UUID    NOT NULL,
    event_to     UUID    NOT NULL,
    total_leaves INT     NOT NULL,
    status       TEXT    NOT NULL DEFAULT 'OPEN' CONSTRAINT chk_bmb_status CHECK (  -- [MC-0261] → A.65.04
                     status IN ('OPEN','CLOSED','COMPUTING','ANCHORED','FAILED')),
    closed_at    TIMESTAMPTZ NULL,
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.blk_merkle_batch IS
'BLOCKCHAIN | Lote (batch) de eventos de auditoría para procesamiento del árbol Merkle — agrupa hasta
1 millón de event_ids (hojas del árbol) antes de calcular la raíz Merkle Keccak-256 y anclarla en
blockchain. Una fila por batch: event_from/event_to delimitan el rango de eventos incluidos,
total_leaves cuenta las hojas del árbol, merkle_root es el hash raíz calculado por el motor Merkle,
y status controla el ciclo de vida (OPEN: acumulando eventos → CLOSED: listo para procesar →
COMPUTING: calculando raíz → ANCHORED: raíz enviada a blockchain en T-358 blk_anchor → FAILED:
error en cálculo o anclaje). El job de Merkle crea un batch nuevo cada hora (o cada 100k eventos si
el volumen es alto), cierra el batch activo y dispara el cálculo del árbol antes de anclar.
Fuente: creado automáticamente por el job merkle_batch_job.rs de bAuth al iniciar cada ciclo de
agrupación; nunca creado manualmente. event_from/event_to son UUIDs v7 de audit events para
delimitar el rango sin necesidad de timestamps (UUIDs v7 son monotónicos).
Administración: PKI_ADMIN puede inspeccionar batches FAILED para diagnóstico; un batch FAILED no se
reintenta automáticamente — requiere HITL para decidir si re-anclar o descartar (operación crítica).
WORM: no — status es mutable durante el ciclo de vida del batch.
Particionada: no.
Estándar: RFC 6962 §2 (Merkle Hash Tree), NIST SP 800-208 §3, Keccak-256 FIPS 202. T-359.';

CREATE TABLE IF NOT EXISTS bauth.blk_anchor (
    anchor_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    batch_id     UUID    NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id),
    merkle_root  TEXT    NOT NULL,
    chain        TEXT    NOT NULL CONSTRAINT chk_ba_chain CHECK (chain IN ('ARBITRUM_ONE','BESU_QBFT')),  -- [MC-0259] → A.65.04
    tx_hash      TEXT    NULL,
    block_number BIGINT  NULL,
    status       TEXT    NOT NULL DEFAULT 'PENDING' CONSTRAINT chk_ba_status CHECK (status IN ('PENDING','SENT','ANCHORED','FAILED')),  -- [MC-0260] → A.65.04
    gas_used     BIGINT  NULL,
    error_msg    TEXT    NULL,
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    anchored_at  TIMESTAMPTZ NULL
);
REVOKE UPDATE, DELETE ON bauth.blk_anchor FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_ba_pending ON bauth.blk_anchor (status, created_at) WHERE status IN ('PENDING','SENT');
COMMENT ON TABLE bauth.blk_anchor IS
'BLOCKCHAIN | Registro WORM de anclajes Merkle on-chain — cada fila documenta un anclaje de la raíz Merkle de un batch de eventos en una red blockchain (Arbitrum L2 para escala, Besu QBFT privado para soberanía), con tx_hash y block_number para verificación pública.
Fuente: creado por el job de anclaje blockchain de bAuth al cerrar un blk_merkle_batch y enviar la TX a la red; el job actualiza status a ANCHORED cuando la TX confirma.
Administración: REVOKE UPDATE/DELETE — append-only; PENDING sin confirmar en >5min generan alerta; el tx_hash permite verificación pública en el explorador de la red; FAILED requiere re-anclaje del mismo batch.
WORM: sí — un ancla blockchain es la prueba de existencia del batch en la cadena; modificar la fila invalidaría la verificabilidad externa de la integridad del batch.
Particionada: no.
Estándar: RFC 6962 §2 (Merkle Tree), Hyperledger Besu §4 (QBFT), NIST SP 800-208 §3 (hash-based signatures). T-358.';


CREATE TABLE IF NOT EXISTS bauth.blk_merkle_leaf (
    leaf_id      UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    batch_id     UUID    NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id),
    leaf_index   INT     NOT NULL,
    event_id     UUID    NOT NULL,
    leaf_hash    TEXT    NOT NULL,
    merkle_proof TEXT[]  NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_bml_batch_index ON bauth.blk_merkle_leaf (batch_id, leaf_index);
CREATE INDEX        IF NOT EXISTS idx_bml_event       ON bauth.blk_merkle_leaf (event_id);
REVOKE UPDATE, DELETE ON bauth.blk_merkle_leaf FROM bauth_app_role;
COMMENT ON TABLE bauth.blk_merkle_leaf IS
'BLOCKCHAIN | Hojas WORM del árbol Merkle — cada fila es un evento de auditoría (event_id) incluido en un batch, con su hash de hoja (Keccak-256) y la prueba de inclusión (merkle_proof[]) que permite verificar la pertenencia al árbol sin acceder al resto del batch.
Fuente: insertado por el motor Merkle de bAuth al procesar un batch (blk_merkle_batch); leaf_index determina la posición en el árbol; merkle_proof se calcula al cerrar el batch y anclar.
Administración: REVOKE UPDATE/DELETE — append-only; UNIQUE (batch_id, leaf_index) garantiza posición única en el árbol; la herramienta bos-verify usa leaf_hash + merkle_proof para verificar off-line; nunca se eliminan hojas de batches anclados.
WORM: sí — las hojas del árbol Merkle son la base matemática de la prueba de integridad; modificarlas rompería la verificabilidad Merkle del ancla blockchain.
Particionada: no.
Estándar: RFC 6962 §2.1 (Merkle Hash Tree), NIST SP 800-208 §3, Keccak-256 FIPS 202. T-360.';


CREATE TABLE IF NOT EXISTS bauth.blk_account (
    account_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id     UUID    NOT NULL,
    entity_id     UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    eth_address   TEXT    NOT NULL UNIQUE,
    status        TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_bac_status CHECK (status IN ('ACTIVE','FROZEN','CLOSED')),  -- [MC-0258] → A.65.04
    balance_cache NUMERIC(20,8) NULL,
    cache_at      TIMESTAMPTZ NULL,
    ctx_id        TEXT    NOT NULL DEFAULT 'system',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.blk_account IS
'BLOCKCHAIN | Registro de cuentas blockchain Besu QBFT vinculadas a entidades SBOS — una fila por
dirección Ethereum (eth_address UNIQUE) perteneciente a una entidad (entity_id T-157). Actúa como el
directorio de cuentas blockchain del ecosistema: conecta la identidad SBOS (entity_id) con la cuenta
on-chain (eth_address), permitiendo al motor de facturación SIN y al motor de pagos emitir y verificar
transacciones sabiendo a quién pertenece cada dirección. balance_cache: saldo en token SBOS
consultado del contrato SettlementEngine.sol y cacheado en PostgreSQL para consultas rápidas sin
llamar a la red Besu en cada request; cache_at indica cuándo fue la última actualización del cache.
El job de reconciliación (T-362 blk_reconciliation) verifica cada 15 minutos que balance_cache
coincide con el saldo on-chain real y genera alerta si hay discrepancia. eth_address es UNIQUE global
— una dirección Ethereum no puede pertenecer a dos entidades distintas en el ecosistema.
Fuente: creada automáticamente por bAuth al registrar una entidad con dominio blockchain (D14);
la dirección Ethereum se genera off-chain con la clave del wallet Vault del tenant.
Administración: BLOCKCHAIN_ADMIN puede congelar cuentas (status=FROZEN) ante incidentes; CLOSED
es el estado final de una cuenta descomisionada; balance_cache se actualiza por el job de reconciliación.
WORM: no — status y balance_cache son mutables operacionalmente.
Particionada: no.
Estándar: Hyperledger Besu §4 (QBFT), EIP-20 (tokens), ISO 20022 §5 (cuenta financiera digital). T-361.';

CREATE TABLE IF NOT EXISTS bauth.blk_reconciliation (
    rec_id          UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    account_id      UUID    NOT NULL REFERENCES bauth.blk_account(account_id),
    balance_onchain NUMERIC(20,8) NOT NULL,
    balance_prev    NUMERIC(20,8) NULL,
    delta           NUMERIC(20,8) NOT NULL,
    status          TEXT    NOT NULL CONSTRAINT chk_br_status CHECK (status IN ('OK','DISCREPANCY','CORRECTED')),  -- [MC-0262] → A.65.04
    ctx_id          TEXT    NOT NULL DEFAULT 'system',
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.blk_reconciliation IS
'BLOCKCHAIN | Registro de conciliaciones periódicas on-chain ↔ PostgreSQL — verifica que el saldo de cada cuenta Besu en la red coincide con el balance_cache de blk_account, y documenta discrepancias y su resolución.
Fuente: insertado automáticamente por el job de reconciliación de bAuth (cada 15 minutos) al consultar el SettlementEngine.sol en Besu y comparar con blk_account.balance_cache; nunca insertado manualmente.
Administración: status=DISCREPANCY genera alerta inmediata a SECURITY_ADMIN del tenant; CORRECTED indica que la discrepancia fue investigada y el cache actualizado; balance_prev permite calcular la tendencia de drift.
WORM: no (una discrepancia puede corregirse y el registro se actualiza con CORRECTED).
Particionada: no.
Estándar: Hyperledger Besu §4 (estado de contratos), ISO 20022 §5 (conciliación financiera), COSO 2013 CC6.6. T-362.';



-- ======================================================================
-- NIVEL 16 — S16 FEDERACIÓN / OIDC (T-365..T-367)
-- Ref: A.65.02.04 v2.2.0 §5 · RFC 6749 · RFC 9449 DPoP · FAPI 2.0
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.fed_client (
    client_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    client_key        TEXT    NOT NULL UNIQUE,
    name              TEXT    NOT NULL,
    type              TEXT    NOT NULL CONSTRAINT chk_fc_type CHECK (type IN ('CONFIDENTIAL','PUBLIC','M2M')),  -- [MC-0083] → A.65.04
    redirect_uris     TEXT[]  NOT NULL DEFAULT '{}',
    allowed_scopes    TEXT[]  NOT NULL DEFAULT '{}',
    grant_types       TEXT[]  NOT NULL DEFAULT '{}',
    pkce_required     BOOLEAN NOT NULL DEFAULT TRUE,
    dpop_required     BOOLEAN NOT NULL DEFAULT FALSE,
    mtls_required     BOOLEAN NOT NULL DEFAULT FALSE,
    fapi_profile      TEXT    NULL CONSTRAINT chk_fc_fapi CHECK (fapi_profile IN ('BASELINE','ADVANCED','FAPI2')),  -- [MC-0081] → A.65.04
    par_required      BOOLEAN NOT NULL DEFAULT FALSE,  -- RFC 9126: TRUE = cliente solo acepta PAR; obligatorio para FAPI2/ADVANCED
    at_ttl_seconds    INT     NOT NULL DEFAULT 3600,
    rt_ttl_seconds    INT     NULL,
    id_token_ttl      INT     NOT NULL DEFAULT 600,
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_fc_status CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),  -- [MC-0082] → A.65.04
    vault_secret_path TEXT    NULL,
    ctx_id            TEXT    NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fc_client_key ON bauth.fed_client (client_key);
COMMENT ON TABLE bauth.fed_client IS
'FEDERACIÓN OIDC | Registro de clientes OAuth2/OIDC — cada aplicación o servicio que delega
autenticación en bAuth tiene una fila aquí (client_key UNIQUE). Tipos: CONFIDENTIAL (SPA/backend que
puede guardar un secreto), PUBLIC (SPA/mobile sin secreto — PKCE obligatorio), M2M (daemon-a-daemon
sin usuario). client_secret NUNCA se almacena en PostgreSQL — solo la ruta Vault (vault_secret_path)
donde vive el secreto cifrado; bAuth lo recupera de Vault cuando necesita verificar client_credentials.
Campos de seguridad: pkce_required (PKCE RFC 7636 — TRUE por defecto, previene CSRF), dpop_required
(DPoP RFC 9449 — vincula el access token a la clave pública del cliente, previene token replay),
mtls_required (mTLS RFC 8705 — el token está bound al certificado del cliente), fapi_profile
(FAPI 2.0 para banca/fintech — la máxima seguridad disponible), par_required (RFC 9126 — TRUE
obliga al cliente a usar PAR; el daemon rechaza authorization requests directos si TRUE;
obligatorio para fapi_profile IN (ADVANCED, FAPI2)). TTL configurable por cliente:
at_ttl_seconds (access token), rt_ttl_seconds (refresh token — NULL = sin refresh), id_token_ttl.
Fuente: creado por OAUTH_ADMIN vía RPC bauth.oidc.client.register al onboarding de una app nueva;
nunca por INSERT directo (el proceso de registro valida redirect_uris y allowed_scopes).
Administración: status=SUSPENDED bloquea emisión de nuevos tokens manteniendo los existentes válidos;
status=REVOKED invalida todos los tokens activos del cliente de forma inmediata.
WORM: no — at_ttl_seconds y dpop_required son ajustables en runtime por OAUTH_ADMIN.
Particionada: no.
Estándar: RFC 6749 (OAuth 2.0), RFC 7636 (PKCE), RFC 9449 (DPoP), RFC 8705 (mTLS), RFC 9126 (PAR), FAPI 2.0. T-365.';

-- =============================================================================
-- T-566 — bauth.fed_par_request (RFC 9126 — Pushed Authorization Requests)
-- Almacena authorization requests pre-autorizados. El cliente EMPUJA el request
-- al endpoint PAR y recibe un request_uri de un solo uso con TTL corto (60-600s).
-- Luego usa ese request_uri en el authorization endpoint estándar.
-- FAPI 2.0 Advanced exige PAR para todos los flujos de autorización.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.fed_par_request (
    par_id                UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    request_uri           TEXT        NOT NULL UNIQUE,  -- urn:ietf:params:oauth:request_uri:<random>
    client_id             UUID        NOT NULL REFERENCES bauth.fed_client(client_id) ON DELETE CASCADE,
    tenant_id             UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    request_payload       JSONB       NOT NULL,          -- parámetros del authorization request
    code_challenge        TEXT        NULL,              -- PKCE code_challenge (S256 obligatorio en FAPI)
    code_challenge_method TEXT        NOT NULL DEFAULT 'S256' CONSTRAINT chk_fpar_method CHECK (
                                           code_challenge_method IN ('S256','plain')),
    used                  BOOLEAN     NOT NULL DEFAULT false,
    used_at               TIMESTAMPTZ NULL,
    expires_at            TIMESTAMPTZ NOT NULL,          -- TTL: 60-600s (RFC 9126 §2.1)
    ctx_id                TEXT        NOT NULL DEFAULT 'system',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fpar_used_at CHECK (used = false OR used_at IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_fpar_expires ON bauth.fed_par_request (expires_at) WHERE used = false;
CREATE INDEX IF NOT EXISTS idx_fpar_client  ON bauth.fed_par_request (client_id, created_at DESC);
COMMENT ON TABLE bauth.fed_par_request IS
'FEDERACIÓN OIDC | Pushed Authorization Requests — RFC 9126. El cliente envía los parámetros
de autorización al endpoint PAR (/oauth/par) y recibe un request_uri opaco de un solo uso
con TTL 60-600 segundos. El authorization endpoint estándar acepta request_uri en lugar de
los parámetros inline — los parámetros nunca viajan en la URL del navegador.
Ventajas FAPI: (1) los parámetros están firmados y autenticados desde el inicio (el cliente
se autentifica al llamar al endpoint PAR); (2) el navegador nunca ve los parámetros reales
(protección contra open redirectors y referer leakage); (3) el servidor puede validar los
parámetros antes de mostrar la UI de autorización.
used: true = el request_uri fue consumido (un solo uso — chk_fpar_used_at fuerza used_at).
code_challenge: correlaciona PAR con PKCE — FAPI 2.0 Advanced exige PKCE+PAR combinados.
Limpieza: job diario elimina filas expired (expires_at < now()); idx_fpar_expires optimiza.
WORM: no — used y used_at se actualizan al consumir el request_uri.
Particionada: no (volumen bajo — TTL corto limita acumulación).
Estándar: RFC 9126 (PAR), FAPI 2.0 Advanced Security Profile §4.3.1.1. T-566.';

CREATE TABLE IF NOT EXISTS bauth.fed_provider_ext (
    provider_id       UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name              TEXT    NOT NULL,
    protocol          TEXT    NOT NULL CONSTRAINT chk_fpe_proto CHECK (protocol IN (  -- [MC-0085] → A.65.04
                          'OIDC','SAML2','GOOGLE','GITHUB','LINKEDIN','MICROSOFT_ENTRA')),
    issuer_url        TEXT    NULL,
    discovery_url     TEXT    NULL,
    jwks_uri          TEXT    NULL,
    metadata_url      TEXT    NULL,
    entity_id         TEXT    NULL,
    sso_url           TEXT    NULL,
    attr_mapping      JSONB   NOT NULL DEFAULT '{}',
    fal               TEXT    NOT NULL DEFAULT 'FAL1' CONSTRAINT chk_fpe_fal CHECK (fal IN ('FAL1','FAL2','FAL3')),  -- [MC-0084] → A.65.04
    status            TEXT    NOT NULL DEFAULT 'ACTIVE',
    vault_secret_path TEXT    NULL,
    ctx_id            TEXT    NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.fed_provider_ext IS
'FEDERACIÓN | Catálogo de proveedores de identidad externos (IdPs) configurados por cada tenant —
permite a los usuarios autenticarse con una cuenta externa (Google Workspace, Microsoft Entra ID,
GitHub, LinkedIn) o con un IdP empresarial (SAML 2.0, OIDC). Protocolos soportados: OIDC, SAML2,
GOOGLE, GITHUB, LINKEDIN, MICROSOFT_ENTRA. Campos clave: issuer_url + discovery_url + jwks_uri
(para OIDC — bAuth descarga automáticamente el JWKS del IdP para verificar tokens), entity_id +
sso_url + metadata_url (para SAML2 — referencia al IdP del SP), attr_mapping JSONB (cómo mapear
claims del IdP externo a atributos SBOS — ej. {sub: entity_id, email: email_principal}), fal (nivel
de aseguramiento de federación del IdP externo: FAL1/FAL2/FAL3 según NIST SP 800-63-4 §6).
vault_secret_path: ruta del client_secret del proveedor social en Vault (NUNCA almacenado en BD).
El bróker de federación de bAuth redirige al IdP externo, procesa el callback, mapea los atributos
y crea/vincula la cuenta local (FEDERATED en idn_user).
Fuente: creada por SECURITY_ADMIN vía RPC bauth.fed.provider.register al habilitar un IdP externo
para el tenant; requiere verificación del proveedor (test de connection) antes de activar.
Administración: status=ACTIVE/INACTIVE; vault_secret_path se rota periódicamente; attr_mapping
ajustable en runtime por SECURITY_ADMIN sin redespliegue.
WORM: no — attr_mapping y status son mutables por administración normal.
Particionada: no.
Estándar: NIST SP 800-63-4 §6 (FAL), RFC 6749 (OIDC), SAML 2.0 OASIS, OpenID Connect Core 1.0. T-366.';

-- PK compuesto (token_id, issued_at) requerido por particionamiento
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued (
    token_id          UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id         UUID         NOT NULL,
    client_id         UUID         NOT NULL REFERENCES bauth.fed_client(client_id),
    user_id           UUID         NULL REFERENCES bauth.idn_user(user_id),
    type              TEXT         NOT NULL CONSTRAINT chk_fti_type CHECK (type IN (  -- [MC-0086] → A.65.04
                                       'ACCESS_TOKEN','REFRESH_TOKEN','ID_TOKEN','EXCHANGE_TOKEN')),
    token_hash        TEXT         NOT NULL,
    scopes            TEXT[]       NOT NULL DEFAULT '{}',
    loa_at_issuance   TEXT         NULL CONSTRAINT chk_fti_loa CHECK (loa_at_issuance IN ('AAL1','AAL2','AAL3')),
    dpop_jkt          TEXT         NULL,
    mtls_cert_fp      TEXT         NULL,
    issued_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at        TIMESTAMPTZ  NOT NULL,
    revoked_at        TIMESTAMPTZ  NULL,
    revocation_reason TEXT         NULL,
    session_id        UUID         NULL,
    ctx_id            TEXT         NOT NULL DEFAULT 'system',
    PRIMARY KEY (token_id, issued_at)
) PARTITION BY RANGE (issued_at);
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued_2026_07 PARTITION OF bauth.fed_token_issued FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued_2026_08 PARTITION OF bauth.fed_token_issued FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued_2026_09 PARTITION OF bauth.fed_token_issued FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE UNIQUE INDEX IF NOT EXISTS idx_fti_hash    ON bauth.fed_token_issued (token_hash, issued_at);
CREATE INDEX        IF NOT EXISTS idx_fti_expires ON bauth.fed_token_issued (expires_at) WHERE revoked_at IS NULL;
COMMENT ON TABLE bauth.fed_token_issued IS
'FEDERACIÓN OIDC | Log particionado de tokens emitidos por el OIDC Provider de bAuth — una fila por
token emitido (ACCESS_TOKEN, REFRESH_TOKEN, ID_TOKEN, EXCHANGE_TOKEN). token_hash: SHA-256 del token
en claro — el valor real del token NUNCA se almacena en BD (si un atacante accede a la BD no obtiene
tokens válidos). Binding de seguridad: dpop_jkt (JSON Key Thumbprint del par DPoP RFC 9449 — el
resource server verifica que el cliente presenta la misma clave privada usada al obtener el token),
mtls_cert_fp (fingerprint del certificado mTLS RFC 8705 — vincula el token al certificado del cliente).
loa_at_issuance: nivel de aseguramiento al momento de la emisión — crucial para tokens de step-up
donde el resource server verifica que el token fue emitido con AAL3. revoked_at registra la revocación
inline para introspección sin consultar T-364 (optimización para el flujo caliente de introspección).
PK compuesto (token_id, issued_at) requerido por el particionamiento RANGE en issued_at.
Fuente: insertada por el OIDC Provider de bAuth al completar cada flujo de emisión exitoso (authorization
code, client_credentials, token_exchange, refresh_token); nunca por INSERT directo.
Administración: tokens expirados se detectan por idx_fti_expires (job de purga por partición mensual);
revoked_at se actualiza al revocar un token (introspección, logout, CAEP event).
WORM: no — revoked_at es mutable por diseño del ciclo de vida del token.
Particionada: sí — PARTITION BY RANGE(issued_at), particiones mensuales.
Estándar: RFC 6749 (OAuth 2.0), RFC 9449 (DPoP), RFC 8705 (mTLS), RFC 7519 (JWT), FAPI 2.0. T-367.';
COMMENT ON COLUMN bauth.fed_token_issued.token_hash      IS 'SHA-256 del valor en claro del token (hex). El token real NUNCA se almacena en BD — solo su huella. El motor de introspección recalcula SHA-256 del token presentado y busca esta columna. Si una BD es exfiltrada, los hashes son inútiles sin la pre-imagen (el token).';
COMMENT ON COLUMN bauth.fed_token_issued.dpop_jkt        IS 'JSON Key Thumbprint (RFC 9449 §6) del par de claves DPoP del cliente — huella de la clave pública Ed25519/ES256 presentada al obtener el token. El resource server verifica que el cliente presenta prueba de posesión de la clave privada correspondiente en cada request.';
COMMENT ON COLUMN bauth.fed_token_issued.mtls_cert_fp    IS 'SHA-256 del certificado mTLS del cliente (RFC 8705 §3) — fingerprint en hex. El resource server verifica que el certificado del canal TLS coincide con este fingerprint, vinculando el token al cliente que lo obtuvo. Presente solo cuando el flujo usó mTLS sender-constrained.';
COMMENT ON COLUMN bauth.fed_token_issued.loa_at_issuance IS 'Level of Assurance en el momento de emisión del token: AAL1, AAL2 o AAL3. El resource server puede requerir loa_at_issuance=AAL3 para operaciones de alto riesgo (FAPI 2.0 security profile). Immutable — refleja el LoA del acto de autenticación original.';


-- ======================================================================
-- NIVEL 17 — S17 BILLETERA DIGITAL (T-380..T-383)
-- Ref: A.65.02.04 v2.2.0 §6 · W3C VCDM 2.0 · OID4VP · OpenID4VCI · eIDAS 2.0
-- ======================================================================

CREATE TABLE IF NOT EXISTS bauth.wallet (
    wallet_id            UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id            UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    entity_id            UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    did                  TEXT    NOT NULL UNIQUE,
    status               TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_w_status CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','ARCHIVED')),  -- [MC-0264] → A.65.04
    backup_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
    backup_method        TEXT    NULL CONSTRAINT chk_w_backup CHECK (backup_method IN ('NONE','ENCRYPTED_CLOUD')),  -- [MC-0263] → A.65.04
    did_anchored         BOOLEAN NOT NULL DEFAULT FALSE,
    did_tx_hash          TEXT    NULL,
    total_presentations  INT     NOT NULL DEFAULT 0,
    last_presentation_at TIMESTAMPTZ NULL,
    ctx_id               TEXT    NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_wallet_entity_tenant UNIQUE (tenant_id, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_w_entity ON bauth.wallet (entity_id);
CREATE INDEX IF NOT EXISTS idx_w_did    ON bauth.wallet (did);
COMMENT ON TABLE bauth.wallet IS
'WALLET | Billetera digital soberana por entidad — contenedor de credenciales verificables (VCs), certificados FIDO2/X.509 y documentos digitales con DID propio (did:sbos:{tenant}:{entity}); implementa EUDI Wallet (eIDAS 2.0 Art. 5a) para interoperabilidad transfronteriza.
Fuente: creada automáticamente por bAuth al registrar una nueva entidad (entity_id) con requisito de wallet; el DID se ancla en Besu QBFT al activar did_anchored=true.
Administración: UNIQUE (tenant_id, entity_id); status SUSPENDED bloquea presentaciones sin revocar ítems; backup_enabled cifra en ENCRYPTED_CLOUD si el tenant lo activa; total_presentations y last_presentation_at se actualizan en cada presentación VP.
WORM: no (status y contadores de presentaciones se actualizan normalmente).
Particionada: no.
Estándar: EU 2024/1183 (eIDAS 2.0 Art. 5a), W3C DID Core 1.0, OpenID4VP §4, W3C VC Data Model 2.0. T-380.';


CREATE TABLE IF NOT EXISTS bauth.wallet_item (
    item_id       UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    wallet_id     UUID    NOT NULL REFERENCES bauth.wallet(wallet_id) ON DELETE CASCADE,
    tenant_id     UUID    NOT NULL,
    type          TEXT    NOT NULL CONSTRAINT chk_wi_type CHECK (type IN (  -- [MC-0268] → A.65.04
                      'VC','FIDO2','X509_CERT','DID_DOC','SIG_CERT','NATIONAL_ID','LICENSE','PHYSICAL_PASS')),
    ref_id        UUID    NOT NULL,
    display_name  TEXT    NOT NULL,
    status        TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_wi_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','HIDDEN')),  -- [MC-0267] → A.65.04
    sd_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    public_attrs  TEXT[]  NULL,
    added_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until   TIMESTAMPTZ NULL,
    ctx_id        TEXT    NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_wi_wallet ON bauth.wallet_item (wallet_id, type);
CREATE INDEX IF NOT EXISTS idx_wi_ref    ON bauth.wallet_item (ref_id);
COMMENT ON TABLE bauth.wallet_item IS
'WALLET | Ítem individual en la billetera digital — cada documento o credencial que el usuario
tiene disponible en su wallet. Una fila por ítem. Tipos: VC (Verifiable Credential W3C VCDM 2.0),
FIDO2 (autenticador hardware registrado), X509_CERT (certificado de identidad digital), DID_DOC
(documento DID), SIG_CERT (certificado de firma ADSIB), NATIONAL_ID (cédula de identidad digital),
LICENSE (licencia de conducir u otra), PHYSICAL_PASS (pase físico OSDP). ref_id: FK a la tabla
fuente del ítem — NUNCA duplica los datos (el ítem apunta a la SSOT; VC → idn_identity_vc T-167,
FIDO2 → auth_credential_fido2 T-332, etc.). sd_enabled: si el ítem soporta Selective Disclosure
(SD-JWT — el usuario puede presentar solo un subconjunto de atributos). public_attrs: lista de
atributos que el usuario marcó como siempre visibles (sin SD); atributos no listados requieren
consentimiento explícito en cada presentación VP. status=HIDDEN: el usuario ocultó el ítem de la
UI pero no fue revocado.
Fuente: creada por el motor de wallet de bAuth al agregar un ítem nuevo (emisión de VC, enrollment
FIDO2, importación de certificado); nunca por INSERT directo del usuario.
Administración: el usuario puede ocultar (HIDDEN) o ver ítems; status=REVOKED lo marca el emisor
cuando la credencial subyacente es revocada; valid_until expira el ítem según la vigencia del ref_id.
WORM: no — status es mutable (el ciclo de vida del ítem depende de la credencial subyacente).
Particionada: no.
Estándar: W3C VC Data Model 2.0, SD-JWT §4 (Selective Disclosure), EU 2024/1183 (eIDAS 2.0). T-381.';
COMMENT ON COLUMN bauth.wallet_item.type         IS 'Tipo de ítem en la billetera: VC (Verifiable Credential W3C VCDM 2.0), FIDO2 (autenticador hardware), X509_CERT (certificado de identidad), DID_DOC (documento DID), SIG_CERT (certificado ADSIB para firma con Ley 164), NATIONAL_ID (cédula digital), LICENSE, PHYSICAL_PASS (pase OSDP). El tipo determina la tabla fuente de ref_id.';
COMMENT ON COLUMN bauth.wallet_item.ref_id       IS 'FK lógica (sin constraint física) al registro fuente del ítem en su tabla de origen: VC → T-167 idn_identity_vc, FIDO2 → T-332 auth_credential_fido2, X509_CERT → T-345 auth_pki_cert, NATIONAL_ID → T-321 idn_user. El ítem NO duplica datos — es un puntero a la SSOT.';
COMMENT ON COLUMN bauth.wallet_item.sd_enabled   IS 'TRUE = el ítem soporta Selective Disclosure (SD-JWT §4): el usuario puede presentar solo algunos atributos sin revelar los demás. FALSE = el ítem siempre se presenta completo. Aplica solo para VC y documentos de identidad con claims individuales.';
COMMENT ON COLUMN bauth.wallet_item.public_attrs IS 'Array de nombres de atributos que el usuario marcó como públicos (siempre visibles sin consentimiento adicional). Atributos no listados requieren consentimiento explícito en cada presentación VP. NULL si sd_enabled=FALSE (no hay distinción público/privado).';

-- PK compuesto (presentation_id, presented_at) requerido por particionamiento
CREATE TABLE IF NOT EXISTS bauth.wallet_presentation_log (
    presentation_id    UUID    NOT NULL DEFAULT uuidv7(),
    wallet_id          UUID    NOT NULL REFERENCES bauth.wallet(wallet_id),
    tenant_id          UUID    NOT NULL,
    presented_items    UUID[]  NOT NULL,
    verifier_client_id UUID    NULL REFERENCES bauth.fed_client(client_id),
    verifier_name      TEXT    NOT NULL,
    verifier_did       TEXT    NULL,
    protocol           TEXT    NOT NULL CONSTRAINT chk_wpl_proto CHECK (protocol IN ('OPENID4VP','SAML_ASSERTION','DIRECT_API')),  -- [MC-0270] → A.65.04
    revealed_attrs     TEXT[]  NULL,
    outcome            TEXT    NOT NULL CONSTRAINT chk_wpl_outcome CHECK (outcome IN ('ACCEPTED','REJECTED','PARTIAL')),  -- [MC-0269] → A.65.04
    rejection_reason   TEXT    NULL,
    ctx_id             TEXT    NOT NULL DEFAULT 'system',
    traceparent        TEXT    NULL,
    presented_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (presentation_id, presented_at)
) PARTITION BY RANGE (presented_at);
CREATE TABLE IF NOT EXISTS bauth.wallet_presentation_log_2026_07 PARTITION OF bauth.wallet_presentation_log FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.wallet_presentation_log_2026_08 PARTITION OF bauth.wallet_presentation_log FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
REVOKE UPDATE, DELETE ON bauth.wallet_presentation_log FROM bauth_app_role;
COMMENT ON TABLE bauth.wallet_presentation_log IS
'WALLET | Log WORM particionado de presentaciones de Verifiable Presentations (VP) — registra cada
vez que el usuario presenta su wallet a un verificador. Una fila por presentación: presented_items
(UUIDs de los wallet_item presentados), verifier_client_id (cliente OIDC del verificador, si registrado
en T-365), verifier_did (DID del verificador para verificación descentralizada), protocol (protocolo
de presentación: OPENID4VP/SAML_ASSERTION/DIRECT_API), revealed_attrs (atributos efectivamente
revelados si SD está activo — controla qué vio el verificador), outcome (ACCEPTED/REJECTED/PARTIAL).
GDPR Art. 7.3: el log permite al usuario ver qué datos compartió con quién y cuándo — requisito de
transparencia. El motor de wallet actualiza wallet.total_presentations y last_presentation_at en
la misma transacción. PK compuesto (presentation_id, presented_at) requerido por particionamiento.
traceparent: W3C Trace Context para correlación con el log de autenticación de la sesión asociada.
Fuente: insertada por el motor de wallet de bAuth al completar cada flujo de presentación VP,
exitoso o rechazado; nunca por INSERT directo.
Administración: REVOKE UPDATE/DELETE — append-only; el usuario puede leer su propio historial de
presentaciones; AUDITOR puede leer todas para forensia; particiones mensuales se archivan tras 12 meses.
WORM: sí — REVOKE UPDATE/DELETE aplicado; el log de presentaciones es evidencia de consentimiento.
Particionada: sí — PARTITION BY RANGE(presented_at), particiones mensuales.
Estándar: OpenID4VP §4, W3C VC Data Model 2.0, GDPR Art. 7.3, EU 2024/1183 (eIDAS 2.0 Art. 5a). T-382.';

CREATE TABLE IF NOT EXISTS bauth.wallet_issuance_log (
    issuance_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    wallet_id       UUID    NOT NULL REFERENCES bauth.wallet(wallet_id),
    tenant_id       UUID    NOT NULL,
    vc_id           UUID    NOT NULL REFERENCES bauth.idn_identity_vc(vc_id),
    issuer_did      TEXT    NOT NULL,
    credential_type TEXT    NOT NULL,
    protocol        TEXT    NOT NULL CONSTRAINT chk_wil_proto CHECK (protocol IN ('OPENID4VCI','DIRECT_ISSUE','IMPORTED')),  -- [MC-0266] → A.65.04
    outcome         TEXT    NOT NULL CONSTRAINT chk_wil_outcome CHECK (outcome IN ('ISSUED','REJECTED','PENDING')),  -- [MC-0265] → A.65.04
    ctx_id          TEXT    NOT NULL DEFAULT 'system',
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON bauth.wallet_issuance_log FROM bauth_app_role;
COMMENT ON TABLE bauth.wallet_issuance_log IS
'WALLET | Log WORM de emisión de Verifiable Credentials a wallets — registra cada issuance de una VC (via OpenID4VCI, emisión directa o importación) con el DID del emisor, el tipo de credencial y el resultado, vinculado a la fuente canónica idn_identity_vc (T-167).
Fuente: insertado por el motor de emisión de VCs de bAuth al completar cada flujo de emisión (exitoso, rechazado o pendiente); el vc_id referencia la VC en idn_identity_vc que es la SSOT de la credencial.
Administración: REVOKE UPDATE/DELETE — append-only; REJECTED con motivo auditable; PENDING expiran por job si el flujo OID4VCI no se completa; evidencia forense de quién emitió qué credencial en qué momento.
WORM: sí — el log de emisión de VCs es evidencia irrefutable del proceso de issuance; modificarlo implicaría falsificar el registro de cuándo y cómo fue emitida una credencial digital.
Particionada: no.
Estándar: OpenID4VCI §4 (credencial issuance), W3C VC Data Model 2.0, EU 2024/1183 (eIDAS 2.0 Art. 5a). T-383.';



-- ======================================================================
-- ÍNDICES COMPLEMENTARIOS — Relaciones clave entre schemas
-- ======================================================================
-- Índice para lookup de grants activos por átomo (id_atom = columna canónica)
CREATE INDEX IF NOT EXISTS idx_pag_id_atom
    ON bauth.privilege_atom_grant(id_atom)
    WHERE status = 'ACTIVE';

-- Índice de búsqueda rápida de nodos átomo activos por posición de bit
CREATE INDEX IF NOT EXISTS idx_irt_eval_active
    ON bauth.idn_roles_template(atom_position, verb_id)
    WHERE node_type = 'atom' AND is_active = true;


-- ======================================================================
-- FIN DDL — SBOS_db_V2_DDL.sql
-- ======================================================================
-- Resumen de tablas creadas (alineado con A.65.02_ANEXO-NUEVA-DDL v1.7):
--
--   bglobal (T-001..T-004 · T-059..T-061 · T-114):
--               global_language, global_country, global_currency, geo_timezone,
--               menu_item, menu_context, menu_item_atom, global_config (8)
--
--   bauth TENANT (T-005..T-013):
--               idn_tenant, idn_tenant_currencies, idn_tenant_languages,
--               idn_tenant_verification, idn_tenant_config, idn_tenant_domain,
--               idn_tenant_network, idn_tenant_calendar_assignment (8)
--
--   bauth VERSIONADO (T-152..T-155):
--               idn_roles_ver_b01_audit_log, idn_roles_ver_b03_approval_queue,
--               idn_roles_ver_b01_retention_policy, idn_roles_ver_contract_revision_log (4)
--
--   bauth ROLES (T-040..T-042 · T-063 · T-162..T-163):
--               idn_roles_rol_type, idn_roles_rol_tier, idn_roles_rol_hierarchical,
--               idn_roles_rol_closure, idn_roles_template (+trigger),
--               idn_roles_template_history (6)
--
--   bauth PRIVILEGIOS (T-170 · T-170b · T-171..T-176 · T-179):
--               privilege_verb, privilege_verb_conflict,
--               privilege_atom_grant, privilege_atom_audit (particionada 2026-07/08/09),
--               privilege_resource_atom, privilege_delegation, privilege_override,
--               privilege_assurance_audit, privilege_exception_record (9)
--
--   bauth IDENTIDAD (T-156..T-157 · T-186..T-188 · T-190):
--               idn_identity_entity, idn_identity_attribute,
--               idn_roles_nhi_identity, idn_roles_nhi_lifecycle_event,
--               idn_roles_nhi_certification, idn_roles_nhi_agent_identity (6)
--               [T-158..T-161: stubs sin CREATE TABLE]
--
--   bauth SESIÓN (T-181 · T-191..T-193):
--               ses_session_log, ses_caep_event_log,
--               ses_ssf_stream, ses_ssf_delivery_log (4)
--
--   bauth AUDITORÍA IGA (T-177..T-178):
--               aud_certification_campaign, aud_certification_review (2)
--
--   bauth RIESGO (T-180):
--               ses_risk_policy (1)
--
--   bauth PAM (T-182 · T-182b · T-183..T-185 · T-189):
--               pam_jit_request, pam_jit_approval, pam_breakglass_activation,
--               pam_session_record, pam_credential_ref, pam_nhi_secret_ref (6)
--
--   bcalendar CALENDARIO (T-012 · T-014..T-019 · T-124..T-125):
--               cal_fiscal_year, cal_calendar, cal_event, cal_alarm,
--               cal_notification_log, cal_holiday, cal_schedule,
--               cal_overtime_policy, cal_break_policy (9)
--
--   bauth USUARIOS S13 (T-320..T-322):
--               idn_user, idn_user_history (WORM), idn_user_recovery (3)
--
--   bauth AUTENTICACIÓN S14 (T-330..T-338):
--               auth_credential, auth_credential_secret, auth_credential_fido2,
--               auth_credential_x509, auth_attempt_log (WORM particionada),
--               auth_method, auth_policy, auth_config, auth_crypto_algorithm (9)
--
--   bauth FIRMA DIGITAL D13 S15 (T-350..T-357):
--               sig_key, sig_certificate, sig_crl,
--               sig_timestamp (WORM), sig_operation_log (WORM),
--               sig_document_hash (WORM), sig_adsib_lifecycle (WORM),
--               sig_document_policy (8)
--
--   bauth BLOCKCHAIN D12 (T-358..T-362):
--               blk_merkle_batch, blk_anchor (WORM),
--               blk_merkle_leaf (WORM), blk_account, blk_reconciliation (5)
--
--   bauth FEDERACIÓN S16 (T-365..T-367):
--               fed_client, fed_provider_ext,
--               fed_token_issued (particionada 2026-07/08/09) (3)
--
--   bauth BILLETERA S17 (T-380..T-383):
--               wallet, wallet_item,
--               wallet_presentation_log (WORM particionada),
--               wallet_issuance_log (WORM) (4)
--
--   bauth AUTENTICACIÓN catálogos S14 (T-384..T-386):
--               auth_federation_protocol (8 seeds), auth_saga_catalog (12 seeds),
--               auth_compliance_map (14 seeds) (3)
--
--   bauth DISPOSITIVOS S18 (T-390..T-392):
--               auth_device, auth_device_posture,
--               auth_device_credential_binding (WORM) (3)
--
-- TOTAL tablas base (padres + no-particionadas): 112
-- Particiones hijas: idn_identity_attribute_history×6 · privilege_atom_audit×3 ·
--                    auth_attempt_log×3 · fed_token_issued×3 · wallet_presentation_log×2 = 17
-- TOTAL CREATE TABLE: 129
-- Stubs (sin CREATE TABLE): T-158..T-161 (4)
-- Secuencias: bauth.roles_atom_position_sequential (1)
-- Triggers:   bauth.trg_irt_atom_position → fn_irt_assign_atom_position() (1)
-- Seeds:      idn_roles_rol_type (10) · idn_roles_rol_tier (11)
--             privilege_verb (50) · privilege_verb_conflict (36 pares SoD)
--             auth_federation_protocol (8) · auth_saga_catalog (12) · auth_compliance_map (14)
-- ======================================================================


-- =============================================================================
-- T-999 — bauth.cfg_policy_library
-- Biblioteca de Referencia de Políticas, Reglas y Átomos.
-- ÚNICO PROPÓSITO: consulta. SOLO LECTURA. Sin lógica de negocio.
-- 16 fuentes de normas (NIST, ISO, FIDO2, OAuth, PCI DSS, SOC2, etc.).
-- 13 dominios D1-D12+SEC. Clasificación jerárquica con CTE recursivo.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.cfg_policy_library (
    section_id          serial PRIMARY KEY,
    section_name        text NOT NULL,
    parent_path         text,
    json_path           text NOT NULL,
    depth               integer DEFAULT 1 NOT NULL CHECK (depth >= 1),
    order_index         integer DEFAULT 1 NOT NULL CHECK (order_index >= 1),
    array_index         bigint DEFAULT 0 CHECK (array_index >= 0),
    node_type           text NOT NULL CHECK (node_type IN ('section','group','policy','config')),
    semantic_type       text CHECK (semantic_type IN ('policy','configuration','method','standard','guideline','group')),
    domain_map          text[],
    source              text NOT NULL,
    standard_ref        text,
    industry_source     text,
    compliance_ref      text[],
    content             jsonb NOT NULL,
    content_en          jsonb NOT NULL,
    content_es          jsonb NOT NULL,
    help_text           jsonb,
    description         text,
    enforcement         text CHECK (enforcement IN ('mandatory','recommended','optional')),
    risk_level          text CHECK (risk_level IN ('critical','high','medium','low')),
    lifecycle           text CHECK (lifecycle IN ('active','deprecated','draft','proposed')),
    applicability       text[],
    assurance_level     text CHECK (assurance_level IN ('AAL1','AAL2','AAL3')),
    auth_factor         text CHECK (auth_factor IN ('knowledge','possession','inherence','context','multi')),
    phishing_resistant  boolean,
    session_timeout     integer,
    mfa_required        boolean,
    created_at          timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_json_path ON bauth.cfg_policy_library (json_path);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_section_parent_source ON bauth.cfg_policy_library (section_name, COALESCE(parent_path, ''), source);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_json_path_source ON bauth.cfg_policy_library (json_path, source);
CREATE INDEX IF NOT EXISTS idx_cfg_library_parent ON bauth.cfg_policy_library (parent_path, source);
CREATE INDEX IF NOT EXISTS idx_cfg_library_node_type ON bauth.cfg_policy_library (node_type);
CREATE INDEX IF NOT EXISTS idx_cfg_library_source ON bauth.cfg_policy_library (source);
CREATE INDEX IF NOT EXISTS idx_cfg_library_domain ON bauth.cfg_policy_library USING gin (domain_map);
CREATE INDEX IF NOT EXISTS idx_cfg_library_semantic ON bauth.cfg_policy_library (semantic_type);
CREATE INDEX IF NOT EXISTS idx_cfg_library_enforcement ON bauth.cfg_policy_library (enforcement);
CREATE INDEX IF NOT EXISTS idx_cfg_library_risk ON bauth.cfg_policy_library (risk_level);
CREATE INDEX IF NOT EXISTS idx_cfg_library_assurance ON bauth.cfg_policy_library (assurance_level);
CREATE INDEX IF NOT EXISTS idx_cfg_library_lifecycle ON bauth.cfg_policy_library (lifecycle);

REVOKE UPDATE, DELETE ON bauth.cfg_policy_library FROM PUBLIC;

COMMENT ON TABLE bauth.cfg_policy_library IS
'CONFIGURACIÓN | LIBRERÍA DE REFERENCIA DOCUMENTAL — NO FUNCIONAL EN RUNTIME.
Esta tabla no participa en ningún flujo operacional de bAuth: no interviene en autenticación,
evaluación de acceso, emisión de tokens ni ningún proceso del motor de identidad. Es
exclusivamente una biblioteca de consulta estática que normaliza 16 fuentes normativas IAM
(NIST, ISO 27001, FIDO2, PCI DSS, OWASP, RFC 9449, etc.) en un árbol jerárquico plano.
Consumidores válidos: (1) dashboard — UI renderiza formularios y etiquetas sin hardcodear texto;
(2) agentes IA — contexto normativo para qex/búsqueda semántica; (3) programadores — referencia
durante el desarrollo. NO la consulte desde el motor de autenticación ni desde el PDP.
Estructura: node_type (section→group→policy/config), semantic_type (policy/configuration/method/
standard/guideline), domain_map (D1-D12+SEC, array GIN), campos i18n content/content_en/content_es,
enforcement (mandatory/recommended/optional), risk_level (critical/high/medium/low).
Fuente: seed DDLs/seeds/bauth_T999__cfg_policy_library.sql — datos exportados y normalizados
desde SBOS_db; cargados directamente por el seed.
Administración: REVOKE UPDATE/DELETE FROM PUBLIC — inmutable en runtime; solo el proceso de
inicialización inserta; recargable con HITL al actualizar fuentes normativas.
WORM: no formalmente — REVOKE UPDATE/DELETE es operacional; repoblable en nuevo despliegue.
Particionada: no.
Estándar: NIST SP 800-63B-4, PCI DSS 4.0, OWASP ASVS 5.0, ISO 27001:2022, FIDO2, RFC 9449. T-999.';

COMMENT ON COLUMN bauth.cfg_policy_library.json_path      IS 'Ruta completa en el JSON fuente. Identificador único global.';
COMMENT ON COLUMN bauth.cfg_policy_library.node_type      IS 'Estructura JSON: section, group, policy, config.';
COMMENT ON COLUMN bauth.cfg_policy_library.semantic_type  IS 'Significado de negocio: policy, configuration, method, standard, guideline, group.';
COMMENT ON COLUMN bauth.cfg_policy_library.domain_map     IS 'Dominios D1-D12+SEC. Array texto para indexación GIN.';
COMMENT ON COLUMN bauth.cfg_policy_library.source         IS 'Fuente normativa: nist_sp_800_63b_rev4, iso_27001_2022, fido2_ctap_2.2, etc.';
COMMENT ON COLUMN bauth.cfg_policy_library.compliance_ref IS 'IDs de controles: PCI DSS 4.0 Req 7.2.4, ISO 27001:2022 A.8.5, NIST 800-53 AC-2.';
COMMENT ON COLUMN bauth.cfg_policy_library.content        IS 'JSONB original de la política/regla/configuración.';
COMMENT ON COLUMN bauth.cfg_policy_library.content_en     IS 'JSONB con claves en inglés.';
COMMENT ON COLUMN bauth.cfg_policy_library.content_es     IS 'JSONB con claves traducidas al español (pre-calculado en la carga del seed).';
COMMENT ON COLUMN bauth.cfg_policy_library.help_text      IS 'Ayuda contextual multilingüe generada automáticamente.';
COMMENT ON COLUMN bauth.cfg_policy_library.enforcement    IS 'Nivel de exigencia: mandatory, recommended, optional.';
COMMENT ON COLUMN bauth.cfg_policy_library.risk_level     IS 'Nivel de riesgo NIST RMF: critical, high, medium, low.';
COMMENT ON COLUMN bauth.cfg_policy_library.lifecycle      IS 'Ciclo de vida IAM: active, deprecated, draft, proposed.';


-- ======================================================================
-- T-999b — bauth.framework_raw
-- Tabla fuente de los 16 JSON normativos para el CTE recursivo de T-999.
-- Una fila por fuente normativa con content JSONB original sin procesar.
-- ISO 27001:2022 A.5.1 · NIST SP 800-53 PM-9.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.framework_raw (
    raw_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    source_name     TEXT        NOT NULL UNIQUE,
    source_version  TEXT        NOT NULL,
    source_type     TEXT        NOT NULL DEFAULT 'NORMATIVE'
                    CHECK (source_type IN ('NORMATIVE','STANDARD','FRAMEWORK','GUIDELINE','REGULATION')),
    domain_scope    TEXT[],
    content         JSONB       NOT NULL,
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    checksum_sha256 TEXT        NOT NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT true
);
CREATE INDEX IF NOT EXISTS idx_fwraw_source  ON bauth.framework_raw (source_name, source_version);
CREATE INDEX IF NOT EXISTS idx_fwraw_content ON bauth.framework_raw USING GIN (content jsonb_path_ops);
COMMENT ON TABLE bauth.framework_raw IS
'BIBLIOTECA | Tabla fuente para el CTE recursivo que pobla bauth.cfg_policy_library (T-999).
Almacena los JSON originales (sin procesar) de 16 fuentes normativas: NIST SP 800-63B-4,
ISO 27001:2022, FIDO2/CTAP 2.2, OAuth 2.0 (RFC 6749/8705/9449), OWASP ASVS 5.0, PCI DSS 4.0,
SOC2 TSC 2023, NIST SP 800-207 (Zero Trust), ISO 24760-2:2025, Ley 164 Bolivia, entre otras.
Una fila por fuente. El seed bauth_T999__cfg_policy_library.sql carga esta tabla y luego ejecuta
el CTE que descompone cada JSONB en filas de cfg_policy_library (T-999).
checksum_sha256 permite detectar actualizaciones de los frameworks fuente.
Estándar: ISO 27001:2022 A.5.1 (políticas de seguridad de la información). T-999b.';

-- ======================================================================
-- T-999c — bauth.cfg_key_translation
-- Diccionario de ~221 claves inglés→español para translate_keys_en_es().
-- Precalcula content_es en cfg_policy_library (T-999) durante la carga.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.cfg_key_translation (
    translation_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    key_en          TEXT        NOT NULL UNIQUE,
    key_es          TEXT        NOT NULL,
    context         TEXT        NOT NULL DEFAULT 'GENERAL'
                    CHECK (context IN ('GENERAL','POLICY','AUTH','IDENTITY','ROLES','FINANCIAL','AUDIT','SECURITY')),
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cfgkt_key_en ON bauth.cfg_key_translation (key_en) WHERE is_active;
COMMENT ON TABLE bauth.cfg_key_translation IS
'BIBLIOTECA | Diccionario de traducción inglés→español para la función translate_keys_en_es(jsonb).
Contiene ~221 mapeos de claves JSON técnicas: "authMethod"→"metodo_autenticacion",
"sessionTimeout"→"tiempo_sesion", etc. La función usa esta tabla para generar la columna
content_es de cfg_policy_library (T-999) durante la carga del seed.
Soporte: camelCase decomposition y snake_case decomposition para variantes de clave.
Estándar: ISO 24760-2:2025 §3 (terminología IAM multilingüe). T-999c.';

-- Función de traducción de claves JSONB (requiere T-999c cargada)
CREATE OR REPLACE FUNCTION bauth.translate_keys_en_es(p_jsonb JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_result   JSONB := '{}';
    v_key      TEXT;
    v_key_es   TEXT;
    v_value    JSONB;
BEGIN
    IF p_jsonb IS NULL OR jsonb_typeof(p_jsonb) <> 'object' THEN
        RETURN p_jsonb;
    END IF;
    FOR v_key, v_value IN SELECT key, value FROM jsonb_each(p_jsonb) LOOP
        SELECT key_es INTO v_key_es
        FROM bauth.cfg_key_translation
        WHERE key_en = v_key AND is_active;
        v_key_es := COALESCE(v_key_es, v_key);
        IF jsonb_typeof(v_value) = 'object' THEN
            v_value := bauth.translate_keys_en_es(v_value);
        END IF;
        v_result := v_result || jsonb_build_object(v_key_es, v_value);
    END LOOP;
    RETURN v_result;
END;
$$;
COMMENT ON FUNCTION bauth.translate_keys_en_es(JSONB) IS
'Traduce claves de un JSONB recursivamente de inglés a español usando cfg_key_translation (T-999c).
STABLE: lee la tabla de traducción. Precalcula content_es en cfg_policy_library. T-999c.';


-- =============================================================================
-- T-364 — bauth.idn_credencial_revocacion (D09-B05)
-- Catálogo persistente de credenciales revocadas. Failsafe ante reinicio de Redis.
-- NIST SP 800-63B-4 §5.2.6 · PCI DSS 4.0 Req 8.2.8 · ISO 27001:2022 A.5.17
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_revocacion (
    revocacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    credential_id   UUID NOT NULL REFERENCES bauth.auth_credential(credential_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    motivo          TEXT NOT NULL,
    revocado_por    UUID REFERENCES bauth.idn_identity_entity(entity_id),
    revocado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    caep_event_id   UUID REFERENCES bauth.ses_caep_event_log(id),
    jti_invalidados UUID[] NOT NULL DEFAULT '{}',
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    CONSTRAINT chk_idcr_motivo CHECK (motivo IN (  -- [MC-0172] → A.65.04
        'COMPROMISED','LOST_DEVICE','USER_REQUEST','ADMIN_REVOKE','EXPIRED','ROTATION'))
);
CREATE INDEX IF NOT EXISTS idx_idcr_credential ON bauth.idn_credencial_revocacion(credential_id, revocado_at DESC);
CREATE INDEX IF NOT EXISTS idx_idcr_tenant    ON bauth.idn_credencial_revocacion(tenant_id, revocado_at DESC);
COMMENT ON TABLE bauth.idn_credencial_revocacion IS
'AUTENTICACIÓN | Catálogo persistente de credenciales revocadas — failsafe ante reinicio de Redis.
El flujo normal de revocación escribe en Redis (lista negra O(1) consultada por Kong PEP y el motor
de introspección de bAuth); esta tabla es el respaldo duradero: si Redis se reinicia y pierde la
lista negra, el daemon bAuth repuebla Redis leyendo esta tabla al arrancar, garantizando que ninguna
credencial revocada pueda usarse tras un reinicio del cache. Campos clave: motivo (COMPROMISED/
LOST_DEVICE/USER_REQUEST/ADMIN_REVOKE/EXPIRED/ROTATION — auditoría de por qué fue revocada),
jti_invalidados (array de JWT IDs emitidos con esta credencial que se invalidan simultáneamente —
un único acto de revocación puede invalidar múltiples tokens activos), caep_event_id (FK a T-191
si la revocación fue disparada por un evento CAEP externo — trazabilidad ITDR completa),
revocado_por (quién ejecutó la revocación — NULL si fue automática por expiración).
Fuente: insertada por el motor de revocación de bAuth al procesar cualquier solicitud de revocación
(usuario, admin, CAEP event, rotación automática); simultáneamente escribe en Redis TTL.
Administración: solo el daemon bAuth puede insertar (vía trigger/RPC); el job de purga elimina
entradas con motivo=EXPIRED o ROTATION tras 90 días (los revocados por COMPROMISED se retienen
indefinidamente para forensia).
WORM: no — filas de revocación expiradas pueden purgarse con retención controlada.
Particionada: no.
Estándar: NIST SP 800-63B-4 §5.2.6 (revocación credencial), PCI DSS 4.0 Req 8.2.8, ISO 27001:2022 A.5.17. T-364.';
COMMENT ON COLUMN bauth.idn_credencial_revocacion.jti_invalidados IS 'Array de UUID v4 de JWT IDs (jti claim) emitidos con esta credencial que se invalidan simultáneamente. Múltiples tokens activos de la misma credencial se invalidan en un solo acto de revocación.';
COMMENT ON COLUMN bauth.idn_credencial_revocacion.caep_event_id  IS 'FK a T-191 ses_caep_event_log — presente si la revocación fue disparada por un evento CAEP externo (ITDR). NULL si fue una revocación manual o por expiración.';
COMMENT ON COLUMN bauth.idn_credencial_revocacion.motivo         IS 'Razón de la revocación: COMPROMISED (seguridad), LOST_DEVICE (dispositivo perdido), USER_REQUEST (solicitud del usuario), ADMIN_REVOKE (administrativo), EXPIRED (caducó), ROTATION (rotación programada).';
COMMENT ON COLUMN bauth.idn_credencial_revocacion.revocado_por   IS 'FK a idn_identity_entity — quién ejecutó la revocación. NULL si fue automática (expiración, rotación del job) sin intervención humana.';


-- =============================================================================
-- T-368 — bauth.idn_credencial_introspeccion (D09-B09)
-- Log de introspecciones de token. RFC 7662 §2. Auditoría forense.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_introspeccion (
    introspection_id UUID PRIMARY KEY DEFAULT uuidv7(),
    token_jti        TEXT NOT NULL,
    credential_id    UUID REFERENCES bauth.auth_credential(credential_id),
    tenant_id        UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    client_id        UUID REFERENCES bauth.fed_client(client_id),
    scope_solicitado TEXT[],
    resultado        JSONB NOT NULL,
    consulta_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_origen        INET,
    ctx_id           TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_idci_token ON bauth.idn_credencial_introspeccion(token_jti, consulta_at DESC);
CREATE INDEX IF NOT EXISTS idx_idci_tenant ON bauth.idn_credencial_introspeccion(tenant_id, consulta_at DESC);
COMMENT ON TABLE bauth.idn_credencial_introspeccion IS
'AUTENTICACIÓN | Log de introspecciones de token según RFC 7662 — registra cada vez que un resource
server consulta a bAuth si un token (JWT) está activo y cuáles son sus claims actuales. Una fila
por consulta. token_jti: el JWT ID del token inspeccionado (no el token completo — nunca se almacena
el bearer token). resultado JSONB: la respuesta de introspección completa ({active:true/false,
scope: [...], sub: ..., exp: ...}). scope_solicitado: los scopes que el resource server verificó.
client_id: qué cliente OIDC realizó la introspección (FK a T-365). ip_origen: IP del resource server.
Este log permite forensia de qué services accedieron a qué tokens en qué momento — crítico cuando un
token es comprometido: se puede reconstruir qué resource servers lo usaron (blast radius del compromiso).
También permite detectar patrones de uso anómalo: un resource server que hace introspección del mismo
token cientos de veces es señal de mal uso del endpoint (debería cachear la respuesta de introspección).
Fuente: insertada automáticamente por el endpoint de introspección de bAuth (/oauth2/introspect RFC 7662)
en cada llamada; nunca por INSERT directo.
Administración: el endpoint de introspección solo acepta llamadas de clientes OIDC registrados (fed_client
T-365); rate limiting por client_id + ip_origen para prevenir abuso; el log es de solo lectura para auditor.
WORM: no (partición por consulta_at para retención; purga tras 30 días por volumen).
Particionada: no (candidata por consulta_at si el volumen es muy alto).
Estándar: RFC 7662 §2 (Token Introspection), NIST SP 800-63B-4 §7, OAuth 2.0 RFC 6749. T-368.';


-- =============================================================================
-- T-460 — bauth.pam_cuenta_privilegiada (D14-B01)
-- Inventario maestro de cuentas privilegiadas. CIS Controls v8 §5.1.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_cuenta_privilegiada (
    cuenta_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id   UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo        TEXT NOT NULL,
    nombre      TEXT NOT NULL,
    sistema     TEXT NOT NULL,
    owner_id    UUID REFERENCES bauth.idn_identity_entity(entity_id),
    criticidad  TEXT NOT NULL DEFAULT 'MEDIUM',
    ultima_rotacion TIMESTAMPTZ,
    estado      TEXT NOT NULL DEFAULT 'ACTIVE',
    ctx_id      TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id, nombre, sistema),
    CONSTRAINT chk_pcp_tipo CHECK (tipo IN (  -- [MC-0208] → A.65.04
        'LOCAL_ADMIN','DOMAIN_ADMIN','SERVICE_ACCOUNT','SHARED','ROOT',
        'API_KEY','CERTIFICATE','SSH_KEY','DATABASE_DBA','CLOUD_ADMIN')),
    CONSTRAINT chk_pcp_criticidad CHECK (criticidad IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    CONSTRAINT chk_pcp_estado CHECK (estado IN ('ACTIVE','INACTIVE','DECOMMISSIONED'))  -- [MC-0207] → A.65.04
);
COMMENT ON TABLE bauth.pam_cuenta_privilegiada IS
'PAM | Inventario maestro de cuentas privilegiadas del tenant — catálogo de referencia que lista
todas las cuentas con privilegios elevados del sistema, desde cuentas de dominio (LOCAL_ADMIN/
DOMAIN_ADMIN) hasta claves API (API_KEY), certificados, llaves SSH y cuentas de base de datos (DATABASE_DBA).
Una fila por cuenta privilegiada: tipo (10 tipos — LOCAL_ADMIN/DOMAIN_ADMIN/SERVICE_ACCOUNT/SHARED/
ROOT/API_KEY/CERTIFICATE/SSH_KEY/DATABASE_DBA/CLOUD_ADMIN), nombre, sistema destino, owner_id
(entidad responsable), criticidad (LOW/MEDIUM/HIGH/CRITICAL — determina la frecuencia de revisión
y el nivel de monitoreo), ultima_rotacion (fecha del último cambio de contraseña/credencial). UNIQUE
(tenant_id, nombre, sistema) garantiza que no se duplique la misma cuenta privilegiada.
Este inventario es el prerequisito del workflow JIT (T-182): solo las cuentas registradas aquí pueden
ser objetivo de una solicitud JIT. Permite también el análisis de cuentas huérfanas (owner_id NULL
→ cuenta sin responsable asignado), que generan alerta de governance.
Fuente: creada por PAM_ADMIN al registrar una cuenta privilegiada nueva; también vía descubrimiento
automático del scanner PAM de bAuth que detecta cuentas privilegiadas en sistemas locales.
Administración: criticidad CRITICAL requiere revisión mensual forzada (job IGA); ultima_rotacion
actualizada por el job de rotación de T-183 pam_credential_ref; estado DECOMMISSIONED es el estado
final (no se borra para mantener historial).
WORM: no — estado, criticidad y ultima_rotacion son mutables operacionalmente.
Particionada: no.
Estándar: NIST SP 800-53 R5 AC-2(7)/AC-6(9), CIS Controls v8 §5.1 (inventario cuentas privilegiadas), ISO 27001:2022 A.8.2. T-460.';


-- ======================================================================
-- T-546 — bauth.idn_nhi_identity (D15 NHI Governance)
-- Registro canónico de Identidades No Humanas en el plano de identidad.
-- Complementa T-186 (idn_roles_nhi_identity) en el plano de roles.
-- Cubre: M2M, bots, API clients, daemons, scripts, pipelines, dispositivos.
-- NIST SP 800-53 IA-2(7)/AC-2(7) · ISO 27001 A.5.16 · CSA NHI Governance 2025.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_identity (
    nhi_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nhi_type        TEXT        NOT NULL
                    CHECK (nhi_type IN ('M2M','BOT','API_CLIENT','DAEMON','SCRIPT','PIPELINE','DEVICE')),
    display_name    TEXT        NOT NULL,
    system_ref      TEXT        NOT NULL,
    description     TEXT,
    owner_id        UUID        REFERENCES bauth.idn_identity_entity(entity_id),
    parent_nhi_id   UUID        REFERENCES bauth.idn_nhi_identity(nhi_id),
    role_nhi_ref    UUID        REFERENCES bauth.idn_roles_nhi_identity(id),
    status          TEXT        NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','SUSPENDED','DECOMMISSIONED','PENDING_REVIEW')),
    risk_level      TEXT        NOT NULL DEFAULT 'MEDIUM'
                    CHECK (risk_level IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    last_activity   TIMESTAMPTZ,
    certified_at    TIMESTAMPTZ,
    review_due_at   TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_inhi546_tenant_ref UNIQUE (tenant_id, system_ref)
);
CREATE INDEX IF NOT EXISTS idx_inhi546_status ON bauth.idn_nhi_identity (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_inhi546_owner  ON bauth.idn_nhi_identity (owner_id);
CREATE INDEX IF NOT EXISTS idx_inhi546_review ON bauth.idn_nhi_identity (review_due_at) WHERE status = 'ACTIVE';
COMMENT ON TABLE bauth.idn_nhi_identity IS
'IDENTIDAD NHI | Registro canónico de Identidades No Humanas en el plano de identidad (D15
NHI Governance). Complementa T-186 (idn_roles_nhi_identity) que opera en el plano de roles.
Cubre: M2M (Machine-to-Machine), bots, API clients, daemons del ecosistema, scripts autónomos,
pipelines CI/CD y dispositivos IoT. Cada NHI tiene un tenant propietario, tipo funcional,
referencia de sistema única (system_ref), propietario humano responsable (owner_id) y nivel
de riesgo que determina la frecuencia de certificación (CRITICAL=30d, HIGH=90d, MEDIUM=180d).
role_nhi_ref vincula al registro de roles en T-186 cuando el NHI tiene asignaciones RBAC.
parent_nhi_id permite jerarquías de NHI (daemon padre → subprocesos hijos).
Estándar: NIST SP 800-53 IA-2(7)/AC-2(7), ISO 27001 A.5.16, CSA NHI Governance 2025. T-546.';


-- =============================================================================
-- T-189 addendum — columnas de rotación NHI (D15-B05)
-- last_rotated_at + next_rotation_at + rotation_count ya existen en DDL y VPS.
-- =============================================================================
ALTER TABLE bauth.pam_nhi_secret_ref
    ADD COLUMN IF NOT EXISTS rotation_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_rotation_status TEXT;
COMMENT ON COLUMN bauth.pam_nhi_secret_ref.rotation_attempts IS '[D15-B05] Contador de intentos de rotación — éxito y fallo.';
COMMENT ON COLUMN bauth.pam_nhi_secret_ref.last_rotation_status IS '[D15-B05] SUCCESS/FAILED/SKIPPED — resultado del último intento.';


-- =============================================================================
-- mv_audit_dashboard — Dashboard de Monitoreo Unificado (D11-B04)
-- VIEW materializada. Refresh cada 5 min.
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS bauth.mv_audit_dashboard AS
SELECT 'active_sessions' as metric, count(*) as cnt, count(DISTINCT user_id) as users
FROM bauth.ses_session_log WHERE terminated_at IS NULL
UNION ALL
SELECT 'caep_events_24h', count(*), count(DISTINCT subject_id)
FROM bauth.ses_caep_event_log WHERE received_at > now() - INTERVAL '24 hours'
UNION ALL
SELECT 'context_switches_24h', count(*), count(DISTINCT user_id)
FROM bos.ctx_context_switch_log WHERE switched_at > now() - INTERVAL '24 hours'
UNION ALL
SELECT 'emergency_active', count(*), 0
FROM bos.ctx_context_emergency WHERE state = 'ACTIVATED'
UNION ALL
SELECT 'revocations_24h', count(*), count(DISTINCT credential_id)
FROM bauth.idn_credencial_revocacion WHERE revocado_at > now() - INTERVAL '24 hours';
COMMENT ON MATERIALIZED VIEW bauth.mv_audit_dashboard IS
  '[D11-B04] Dashboard unificado de monitoreo. 5 métricas: sesiones activas, CAEP 24h, switches 24h, emergencias activas, revocaciones 24h. Refresh: 5 min.';


-- =============================================================================
-- ISO 27001:2022 BACKLOG — Implementación de gaps D-05..D-18
-- T-520 a T-529 — Módulos: incidentes, retención, amenazas, vulnerabilidades
-- =============================================================================

-- =============================================================================
-- T-520 — bauth.inc_incident (A.5.27 — aprendizaje de incidentes)
-- Cabecera del incidente de seguridad. Base del módulo inc_*.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.inc_incident (
    inc_id         UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    incident_type  TEXT        NOT NULL,
    severity       TEXT        NOT NULL,
    detected_at    TIMESTAMPTZ NOT NULL,
    resolved_at    TIMESTAMPTZ NULL,
    caep_event_ref UUID        NULL,   -- referencia blanda a ses_caep_event_log.event_id
    aud_event_ref  UUID        NULL,   -- referencia blanda a aud_event_log.event_id
    summary        TEXT        NOT NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_inc_severity     CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    CONSTRAINT chk_inc_type         CHECK (incident_type IN (
        'CREDENTIAL_BREACH','UNAUTHORIZED_ACCESS','PRIVILEGE_ESCALATION',
        'DATA_EXFILTRATION','ACCOUNT_TAKEOVER','MFA_BYPASS','IOC_DETECTED',
        'POLICY_VIOLATION','INSIDER_THREAT','CONFIGURATION_ERROR','OTHER'
    ))
);
CREATE INDEX IF NOT EXISTS idx_inc_tenant  ON bauth.inc_incident(tenant_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_inc_open    ON bauth.inc_incident(detected_at) WHERE resolved_at IS NULL;
COMMENT ON TABLE bauth.inc_incident IS
'INCIDENTES | Cabecera del incidente de seguridad. Base del módulo inc_*.
Vincula al tenant afectado, clasifica por tipo y severidad, y referencia
(en modo blando) la evidencia cruda de ses_caep_event_log o aud_event_log.
Estándar: ISO 27001:2022 A.5.27, NIST SP 800-61 Rev.3, SOC 2 CC7.4. T-520.';

-- =============================================================================
-- T-521 — bauth.inc_root_cause (A.5.27 — análisis de causa raíz)
-- Una por incidente. Captura causa principal y factores secundarios.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.inc_root_cause (
    cause_id             UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    cause_category       TEXT        NOT NULL,
    description          TEXT        NOT NULL,
    contributing_factors JSONB       NULL,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_rc_incident UNIQUE (inc_id),   -- una causa raíz por incidente
    CONSTRAINT chk_rc_category CHECK (cause_category IN (
        'MISCONFIGURATION','MISSING_CONTROL','HUMAN_ERROR','SOFTWARE_BUG',
        'SOCIAL_ENGINEERING','EXTERNAL_ATTACK','POLICY_GAP','UNKNOWN'
    ))
);
COMMENT ON TABLE bauth.inc_root_cause IS
'INCIDENTES | Análisis de causa raíz por incidente (uno por inc_incident).
Captura categoría de causa, descripción y factores secundarios en JSONB.
Estándar: ISO 27001:2022 A.5.27, NIST SP 800-61 Rev.3. T-521.';

-- =============================================================================
-- T-522 — bauth.inc_corrective_action (A.5.26 + A.5.27)
-- Medidas correctivas. action_phase distingue A.5.26 (respuesta activa)
-- de A.5.27 (post-incidente). Varias por incidente, secuenciadas.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.inc_corrective_action (
    action_id            UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    sequence_nr          INTEGER     NOT NULL DEFAULT 1,
    action_type          TEXT        NOT NULL,
    action_phase         TEXT        NOT NULL DEFAULT 'CORRECTIVE',
    target_table         TEXT        NULL,
    target_record_id     UUID        NULL,
    description          TEXT        NOT NULL,
    implemented_by       UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    implemented_at       TIMESTAMPTZ NULL,
    status               TEXT        NOT NULL DEFAULT 'PENDING',
    linked_revocation_id UUID        NULL REFERENCES bauth.idn_credencial_revocacion(revocacion_id),
    linked_thi_id        UUID        NULL,   -- referencia blanda a thi_indicator (evita dep. circular)
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ica_phase  CHECK (action_phase IN (
        'CONTAINMENT',    -- A.5.26: detener avance — revocar, bloquear
        'ERADICATION',    -- A.5.26: eliminar amenaza — purgar tokens, limpiar config
        'RECOVERY',       -- A.5.26: restaurar operación
        'CORRECTIVE',     -- A.5.27: cambio de política post-incidente
        'TRAINING'        -- A.5.27: capacitación derivada del incidente
    )),
    CONSTRAINT chk_ica_status CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','CANCELLED')),
    CONSTRAINT chk_ica_type   CHECK (action_type IN (
        'REVOKE_CREDENTIAL','BLOCK_IP','SUSPEND_ACCOUNT','PATCH_SYSTEM',
        'UPDATE_POLICY','CHANGE_CONFIG','NOTIFY_STAKEHOLDERS','TRAIN_USERS',
        'REVIEW_ACCESS','RESET_MFA','OTHER'
    ))
);
CREATE INDEX IF NOT EXISTS idx_ica_incident ON bauth.inc_corrective_action(inc_id, sequence_nr);
CREATE INDEX IF NOT EXISTS idx_ica_phase    ON bauth.inc_corrective_action(action_phase, status);
COMMENT ON TABLE bauth.inc_corrective_action IS
'INCIDENTES | Medidas correctivas por incidente. action_phase distingue:
  A.5.26: CONTAINMENT / ERADICATION / RECOVERY (respuesta activa durante incidente).
  A.5.27: CORRECTIVE / TRAINING (post-incidente, mejora continua).
linked_revocation_id vincula a acciones de revocación de credenciales.
Estándar: ISO 27001:2022 A.5.26+A.5.27, NIST SP 800-61 Rev.3. T-522.';

-- =============================================================================
-- T-523 — bauth.inc_effectiveness_review (A.5.27 — ciclo PDCA Check)
-- Revisión de efectividad de medidas correctivas. Una o más por incidente.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.inc_effectiveness_review (
    review_id            UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    inc_id               UUID        NOT NULL REFERENCES bauth.inc_incident(inc_id),
    review_date          TIMESTAMPTZ NOT NULL,
    reviewer_id          UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    reincidence_detected BOOLEAN     NOT NULL DEFAULT false,
    verdict              TEXT        NOT NULL DEFAULT 'PENDING',
    findings             TEXT        NULL,
    next_review_date     DATE        NULL,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ier_verdict CHECK (verdict IN ('EFFECTIVE','PARTIALLY_EFFECTIVE','INEFFECTIVE','PENDING'))
);
COMMENT ON TABLE bauth.inc_effectiveness_review IS
'INCIDENTES | Revisión de efectividad de medidas correctivas (ciclo PDCA — fase Check).
reincidence_detected=true dispara nueva revisión o reapertura del incidente.
Estándar: ISO 27001:2022 A.5.27, SOC 2 CC7.4, ITIL 4 Problem Management. T-523.';

-- =============================================================================
-- T-524 — bauth.cfg_retention_policy (A.8.10 — eliminación de información)
-- Política de retención y purga por tipo de dato. Leída por el reconcile loop.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.cfg_retention_policy (
    policy_id      UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    table_name     TEXT        NOT NULL,
    column_name    TEXT        NULL,        -- NULL = aplica a la tabla completa
    retention_days INTEGER     NOT NULL CHECK (retention_days > 0),
    purge_action   TEXT        NOT NULL,
    exemption      TEXT        NULL,        -- 'WORM' → tabla inviolable, no purgar
    legal_basis    TEXT        NOT NULL,    -- Ley 164, GDPR Art.17, Ley 843 Bolivia, etc.
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_rp_accion   CHECK (purge_action IN ('DELETE','ANONYMIZE','ARCHIVE'))
);
-- Índice UNIQUE expresional: COALESCE no puede usarse en UNIQUE constraint de tabla
CREATE UNIQUE INDEX IF NOT EXISTS uq_rp_tabla_col
    ON bauth.cfg_retention_policy (table_name, COALESCE(column_name, '__all__'));
COMMENT ON TABLE bauth.cfg_retention_policy IS
'CICLO DE VIDA | Política de retención y eliminación programada por tabla/columna.
El reconcile loop lee esta tabla y ejecuta purgas en datos NO-WORM vencidos.
Toda purga queda registrada en aud_event_log con action_type=''DATA_PURGE''.
purge_action: DELETE (eliminar fila), ANONYMIZE (NULL PII), ARCHIVE (mover).
Estándar: ISO 27001:2022 A.8.10, GDPR Art.17, Ley 164 Bolivia, Ley 843 Art.44. T-524.';

-- Seeds de retención iniciales
INSERT INTO bauth.cfg_retention_policy
    (table_name, column_name, retention_days, purge_action, exemption, legal_basis, ctx_id)
VALUES
    ('bauth.idn_identity_attribute', NULL,           365*7, 'ANONYMIZE', NULL,   'Ley 843 Bolivia Art.44 — 7 años retención datos laborales', 'system'),
    ('bauth.ses_session_log',         NULL,           365,   'DELETE',    NULL,   'ISO 27001 A.8.10 — sesiones expiradas >1 año', 'system'),
    ('bauth.auth_attempt_log',        NULL,           365,   'DELETE',    'WORM', 'ISO 27001 A.8.15 — audit log retención mínima 1 año', 'system'),
    ('bauth.pam_breakglass_activation',NULL,          365*3, 'ARCHIVE',   NULL,   'ISO 27001 A.8.10 + PCI DSS 4.0 Req 10.7 — 3 años', 'system')
ON CONFLICT (table_name, COALESCE(column_name, '__all__')) DO NOTHING;

-- =============================================================================
-- T-525 — bauth.thi_indicator (A.5.7 — inteligencia de amenazas)
-- Catálogo de IOCs consultado en el pipeline de autenticación.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.thi_indicator (
    indicator_id    UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    indicator_type  TEXT        NOT NULL,
    indicator_value TEXT        NOT NULL,
    source          TEXT        NOT NULL,
    confidence      TEXT        NOT NULL,
    category        TEXT        NOT NULL,
    action          TEXT        NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    notes           TEXT        NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_thi_indicator   UNIQUE (indicator_type, indicator_value, source),
    CONSTRAINT chk_thi_type       CHECK (indicator_type IN (
        'IPv4','IPv4_RANGE','DOMAIN','EMAIL_DOMAIN','HASH_SHA256','USER_AGENT'
    )),
    CONSTRAINT chk_thi_source     CHECK (source IN (
        'CISA','STIX_TAXII','ISAC','INTERNAL','MANUAL'
    )),
    CONSTRAINT chk_thi_confidence CHECK (confidence IN ('HIGH','MEDIUM','LOW')),
    CONSTRAINT chk_thi_category   CHECK (category IN (
        'TOR_EXIT','CREDENTIAL_STUFFING','PHISHING','BOTNET','BRUTE_FORCE'
    )),
    CONSTRAINT chk_thi_action     CHECK (action IN (
        'BLOCK','REQUIRE_STEP_UP','MONITOR','ALERT_ONLY'
    ))
);
CREATE INDEX IF NOT EXISTS idx_thi_active  ON bauth.thi_indicator(indicator_type, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_thi_expiry  ON bauth.thi_indicator(valid_until)               WHERE valid_until IS NOT NULL AND is_active = true;
COMMENT ON TABLE bauth.thi_indicator IS
'AMENAZAS | Catálogo de IOCs (Indicators of Compromise) para inteligencia proactiva.
Consultado en el pipeline de autenticación: si la IP/dominio/email coincide con un IOC
activo, bAuth aplica la acción configurada (BLOCK / REQUIRE_STEP_UP / MONITOR / ALERT_ONLY).
A diferencia de CAEP (reactivo), los IOCs son indicadores conocidos de antemano.
Estándar: ISO 27001:2022 A.5.7, NIST SP 800-150, STIX/TAXII. T-564.';

-- =============================================================================
-- T-526 — bauth.thi_correlation_log (A.5.7 — log de correlaciones IOC)
-- Registro de cada coincidencia IOC detectada en el pipeline auth.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.thi_correlation_log (
    corr_id          UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    indicator_id     UUID        NOT NULL REFERENCES bauth.thi_indicator(indicator_id),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    auth_attempt_ref UUID        NULL,   -- referencia blanda a auth_attempt_log (particionada)
    matched_value    TEXT        NOT NULL,
    action_taken     TEXT        NOT NULL,
    entity_id        UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    detected_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_tcl_action CHECK (action_taken IN ('BLOCKED','STEP_UP_FORCED','MONITORED','ALERTED'))
);
CREATE INDEX IF NOT EXISTS idx_tcl_indicator ON bauth.thi_correlation_log(indicator_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_tcl_tenant    ON bauth.thi_correlation_log(tenant_id, detected_at DESC);
REVOKE UPDATE, DELETE ON bauth.thi_correlation_log FROM bauth_app_role;
COMMENT ON TABLE bauth.thi_correlation_log IS
'AMENAZAS | Log append-only de correlaciones IOC detectadas en el pipeline auth.
Cada fila = un IOC activado: qué indicador coincidió, contra qué tenant/entidad,
qué valor exacto, y qué acción tomó bAuth. Trazabilidad completa de amenazas detectadas.
auth_attempt_ref es referencia blanda (sin FK) porque auth_attempt_log es particionada.
WORM: REVOKE UPDATE/DELETE — evidencia forense inviolable.
Estándar: ISO 27001:2022 A.5.7, NIST SP 800-150. T-526.';

-- =============================================================================
-- T-527 — bauth.vul_component (A.8.8 — inventario stack auth)
-- Inventario de crates Rust y librerías del stack de autenticación bAuth.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.vul_component (
    component_id   UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    name           TEXT        NOT NULL,
    component_type TEXT        NOT NULL,
    version        TEXT        NOT NULL,
    source         TEXT        NOT NULL DEFAULT 'Cargo.toml',
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    last_scanned   TIMESTAMPTZ NULL,
    scan_tool      TEXT        NULL,
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_vul_component  UNIQUE (name, version),
    CONSTRAINT chk_vul_comp_type CHECK (component_type IN (
        'RUST_CRATE','SYSTEM_LIB','BINARY','CONFIG','PROTOCOL'
    ))
);
COMMENT ON TABLE bauth.vul_component IS
'VULNERABILIDADES | Inventario de componentes del stack de autenticación bAuth.
Cubre: crates Rust (jsonwebtoken, ring, rustls, webauthn-rs...), librerías del sistema,
binarios y protocolos. Complementa bos.vul_infra_component (infraestructura).
last_scanned actualizado por cargo-audit/trivy en cada CI run.
Estándar: ISO 27001:2022 A.8.8, NIST SP 800-53 SI-2. T-527.';

-- =============================================================================
-- T-528 — bauth.vul_auth_impact (A.8.8 — impacto CVE en métodos auth)
-- Evaluación de impacto de CVEs sobre los 18 métodos de autenticación.
-- SLA: CRITICAL=24h · HIGH=7d · MEDIUM=30d · LOW=90d
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.vul_auth_impact (
    impact_id        UUID         NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    cve_id           TEXT         NOT NULL,   -- "CVE-2026-12345" — referencia a bos.vul_cve_registry
    component_id     UUID         NOT NULL REFERENCES bauth.vul_component(component_id),
    affected_methods TEXT[]       NOT NULL DEFAULT '{}',
    severity         TEXT         NOT NULL,
    cvss_score       NUMERIC(3,1) NULL CHECK (cvss_score BETWEEN 0.0 AND 10.0),
    impact_desc      TEXT         NOT NULL,
    mitigation       TEXT         NULL,
    action_taken     TEXT         NULL,
    disabled_methods TEXT[]       NOT NULL DEFAULT '{}',
    sla_deadline     TIMESTAMPTZ  NULL,   -- detected_at + SLA(severity)
    resolved_at      TIMESTAMPTZ  NULL,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_vai_severity CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')),
    CONSTRAINT chk_vai_action   CHECK (
        action_taken IS NULL OR
        action_taken IN ('DISABLED_METHOD','PATCHED','MITIGATED','ACCEPTED','PENDING')
    )
);
CREATE INDEX IF NOT EXISTS idx_vai_sla_open ON bauth.vul_auth_impact(sla_deadline) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_vai_cve      ON bauth.vul_auth_impact(cve_id);
COMMENT ON TABLE bauth.vul_auth_impact IS
'VULNERABILIDADES | Evaluación de impacto de CVEs sobre los 18 métodos de autenticación.
Recibe notificación de bos (bauth.vulnerability.notify JSON-RPC) cuando cargo-audit/Trivy
detecta un CVE en un componente del stack auth.
SLAs: CRITICAL=24h, HIGH=7d, MEDIUM=30d, LOW=90d.
Si severity=CRITICAL/HIGH y action_taken=DISABLED_METHOD: el daemon desactiva el método
afectado y registra en aud_event_log. Cierre del loop: bos actualiza vul_cve_registry.
Estándar: ISO 27001:2022 A.8.8, CVSS v3.1, NIST SP 800-53 SI-2. T-528.';

-- =============================================================================
-- T-529 — bauth.inc_security_event (A.5.25 — triaje de eventos)
-- Decisión formal de triaje: analista evalúa evento sospechoso y decide.
-- Depende de T-520 (inc_incident) para el FK incident_id.
-- =============================================================================
CREATE TABLE IF NOT EXISTS bauth.inc_security_event (
    event_id       UUID        NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    source_table   TEXT        NOT NULL,
    source_ref     UUID        NULL,   -- ID del registro origen (nullable si reporte manual)
    description    TEXT        NOT NULL,
    assessed_by    UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    assessed_at    TIMESTAMPTZ NULL,
    decision       TEXT        NULL,
    severity       TEXT        NULL,
    decision_notes TEXT        NULL,
    incident_id    UUID        NULL REFERENCES bauth.inc_incident(inc_id),
    ctx_id         TEXT        NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ise_source   CHECK (source_table IN (
        'ses_caep_event_log','auth_attempt_log','aud_event_log','thi_correlation_log','MANUAL'
    )),
    CONSTRAINT chk_ise_decision CHECK (
        decision IS NULL OR
        decision IN ('CONFIRMED','FALSE_POSITIVE','MONITORING','ESCALATED')
    ),
    CONSTRAINT chk_ise_severity CHECK (
        severity IS NULL OR
        severity IN ('CRITICAL','HIGH','MEDIUM','LOW')
    )
);
CREATE INDEX IF NOT EXISTS idx_ise_tenant    ON bauth.inc_security_event(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ise_pending   ON bauth.inc_security_event(created_at) WHERE decision IS NULL;
COMMENT ON TABLE bauth.inc_security_event IS
'INCIDENTES | Triaje de eventos de seguridad — registra la decisión formal del analista.
[A.5.25] Posición: ANTES de inc_incident (T-520). Flujo:
  evento crudo (auth_attempt_log / ses_caep_event_log / aud_event_log / thi_correlation_log)
  → inc_security_event (analista evalúa y decide)
  → si decision=CONFIRMED → crea inc_incident (T-520)
assessed_by + assessed_at + decision + decision_notes = registro forense del triaje.
Sin triaje documentado, A.5.25 queda sin evidencia de proceso de decisión humana.
Estándar: ISO 27001:2022 A.5.25, NIST SP 800-61 Rev.3 §3.2. T-565.';

-- =============================================================================
-- §WORM — WORM ENFORCEMENT TRIGGERS (append-only a nivel BD)
-- Cierra: GAP-OP-02 / GAP-PCI-01 (A.73 v1.2.0)
-- Normas: ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-9 · PCI DSS 4.0 Req 10.3.2
-- Tablas excluidas (hash-chain ya en DDL base):
--   idn_roles_rol_lifecycle_event   → trg_irle_worm
--   idn_roles_ver_b01_audit_log     → trg_irvb01al_worm
-- Idempotente: DROP TRIGGER IF EXISTS + CREATE TRIGGER.
-- Usar FOR EACH STATEMENT para rechazar incluso en tablas vacías o WHERE FALSE.
-- =============================================================================

CREATE OR REPLACE FUNCTION bauth.fn_worm_enforce()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'WORM_VIOLATION: %.% es una tabla de solo inserción (append-only). '
        'Operación % rechazada por enforcer activo. '
        'Norma: ISO 27001:2022 A.8.15 · NIST AU-9 · PCI DSS 10.3.2. '
        'Si necesita corregir un registro, contacte al DBA con justificación auditada.',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP;
END;
$$;

COMMENT ON FUNCTION bauth.fn_worm_enforce() IS
'Función WORM compartida (schemas bauth/bcalendar/bos). Rechaza UPDATE y DELETE en
tablas append-only con RAISE EXCEPTION prefijado WORM_VIOLATION.
ISO 27001:2022 A.8.15 — protección de registros de auditoría. NIST AU-9. PCI DSS 10.3.2.';

-- schema bauth — 27 tablas
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

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_user_history;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_user_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_identity_attribute_history;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_identity_attribute_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_identity_consent;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_identity_consent
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_roles_template_history;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_roles_template_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_roles_nhi_lifecycle_event;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.idn_roles_nhi_lifecycle_event
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.privilege_atom_audit;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.privilege_atom_audit
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.auth_device_credential_binding;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.auth_device_credential_binding
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.auth_attempt_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.auth_attempt_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.ses_caep_event_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.ses_caep_event_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.ses_ssf_delivery_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.ses_ssf_delivery_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_timestamp;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.sig_timestamp
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_operation_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.sig_operation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_document_hash;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.sig_document_hash
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_adsib_lifecycle;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.sig_adsib_lifecycle
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.blk_anchor;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.blk_anchor
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.blk_merkle_leaf;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.blk_merkle_leaf
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.thi_correlation_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.thi_correlation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.wallet_presentation_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.wallet_presentation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

DROP TRIGGER IF EXISTS trg_worm ON bauth.wallet_issuance_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bauth.wallet_issuance_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- schema bcalendar — 1 tabla
DROP TRIGGER IF EXISTS trg_worm ON bcalendar.cal_notification_log;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bcalendar.cal_notification_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- schema bos — 1 tabla
DROP TRIGGER IF EXISTS trg_worm ON bos.ctx_context_audit;
CREATE TRIGGER trg_worm BEFORE UPDATE OR DELETE ON bos.ctx_context_audit
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

