-- ======================================================================
-- SBOS_db_V2_DDL.sql — bAuth Identity Governance Platform
-- Base de datos: SBOS_db · Schema principal: bauth, bglobal, bcalendar
-- PostgreSQL 18.4 · UUIDv7 nativo · WITHOUT OVERLAPS (temporal)
-- Versión: 2.0.0 · Fecha: 2026-07-21
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
-- SCHEMAS
-- ══════════════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS bauth;       -- Núcleo de identidad (idn_, ses_, aud_, risk_, pam_)
CREATE SCHEMA IF NOT EXISTS bglobal;     -- Catálogos ISO globales (global_, geo_, menu_)
CREATE SCHEMA IF NOT EXISTS bcalendar;   -- Calendario fiscal (cal_)

-- ══════════════════════════════════════════════════════════════════════
-- EXTENSIONES
-- ══════════════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ══════════════════════════════════════════════════════════════════════
-- ENUM TYPES — Dominios controlados (guard de idempotencia)
-- ══════════════════════════════════════════════════════════════════════

-- --- GLOBAL / IDIOMA ---
DO $$ BEGIN CREATE TYPE language_scope_enum    AS ENUM ('individual','macrolanguage','special','collection'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE language_type_enum     AS ENUM ('living','extinct','ancient','constructed','historic'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE text_direction_enum    AS ENUM ('ltr','rtl','ttb'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE translation_status_enum AS ENUM ('COMPLETE','PARTIAL','MACHINE_TRANSLATED','NOT_TRANSLATED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE menu_type_enum         AS ENUM ('HIERARCHICAL','CONTEXTUAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE global_param_scope_enum AS ENUM ('global','security','calendar','auth','policy','billing'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE global_param_type_enum  AS ENUM ('TEXT','INTEGER','BOOLEAN','JSON','DECIMAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- TENANT ---
DO $$ BEGIN CREATE TYPE tenant_status_enum       AS ENUM ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','MAINTENANCE','SOFT_DELETED','TERMINATED','PURGED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE tenant_type_enum         AS ENUM ('STANDARD','REGULATED','HIGH_SENSITIVITY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE isolation_level_enum     AS ENUM ('ROW_LEVEL','SCHEMA_PER_TENANT','DB_PER_TENANT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE subscription_status_enum AS ENUM ('TRIAL','ACTIVE','PAST_DUE','CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE plan_tier_enum           AS ENUM ('BASIC','PRO','ENTERPRISE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE provisioning_status_enum AS ENUM ('PENDING','INFRA_PROVISIONING','SCHEMA_CREATED','IDP_CONFIGURED','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE audit_level_enum         AS ENUM ('basic','full'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE verification_step_enum   AS ENUM ('IDENTITY_CHECK','LEGAL_CHECK','TECHNICAL_SETUP','SECURITY_REVIEW','FINAL_APPROVAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE verification_status_enum AS ENUM ('PENDING','IN_PROGRESS','PASSED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE domain_type_enum         AS ENUM ('WEB','API','POS','ADMIN','PORTAL','STATIC','MAIL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE domain_status_enum       AS ENUM ('PENDING','VERIFIED','FAILED','DEPLOYING','DEPLOYED','HEALTHY','DEGRADED','UNHEALTHY','UNKNOWN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE network_type_enum        AS ENUM ('LAN','WAN','VPN','DMZ','GUEST','MANAGEMENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_owner_type_enum AS ENUM ('TENANT','COMPANY','BRANCH','USER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_role_enum       AS ENUM ('OWNER','EDITOR','VIEWER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- CALENDARIO ---
DO $$ BEGIN CREATE TYPE fiscal_year_status_enum  AS ENUM ('OPEN','CLOSED','CLOSED_WITH_ADJUSTMENTS','ARCHIVED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_type_enum       AS ENUM ('WORK','FISCAL','PROCESS','COMPLIANCE','HOLIDAY','MAINTENANCE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE alarm_channel_enum       AS ENUM ('EMAIL','SMS','WHATSAPP','PUSH','CHAT','UI'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE schedule_status_enum     AS ENUM ('OPEN','CLOSED','LUNCH','BREAK','OVERTIME'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- ROLES ---
DO $$ BEGIN CREATE TYPE rol_tier_enum            AS ENUM ('SU','T0','T1','BIZ_N1','BIZ_N2','BIZ_N3','BIZ_N4','BIZ_N5','EXT_N0','M2M','VISITANTE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE rol_status_enum          AS ENUM ('ACTIVE','INACTIVE','DEPRECATED','ARCHIVED','SUSPENDED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE rol_account_type_enum    AS ENUM ('INDIVIDUAL','M2M','SYSTEM','GROUP','TEMPLATE','VIRTUAL','BOT','DEVICE','SERVICE','EMERGENCY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE ial_level_enum           AS ENUM ('IAL1','IAL2','IAL3'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- ÁRBOL DE POLÍTICAS ---
-- NOTA: template_node_type_enum, template_effect_enum, verb_conflict_type_enum ELIMINADOS.
-- T-162 usa tipo TEXT + CHECK(9 tipos en español). T-162/T-170 usan effect BOOLEAN.
-- T-175 usa tipo TEXT + CHECK('SOD_ESTATICO','SOD_DINAMICO','AFINIDAD').

-- --- IDENTIDAD D00 ---
DO $$ BEGIN CREATE TYPE entidad_nivel_enum       AS ENUM ('tenant','bdomain','bsubdomain','pos','actor'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE nhi_type_enum            AS ENUM ('DAEMON','PIPELINE','BOT','SERVICE_ACCOUNT','AGENT_AI','DEVICE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE nhi_status_enum          AS ENUM ('ACTIVE','SUSPENDED','DECOMMISSIONED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE nhi_event_type_enum      AS ENUM ('PROVISIONED','CERTIFIED','ROTATED','SUSPENDED','REACTIVATED','DECOMMISSIONED','OWNER_CHANGED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE nhi_cert_decision_enum   AS ENUM ('CERTIFY','DECOMMISSION','REDUCE_SCOPE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- PRIVILEGIOS ---
DO $$ BEGIN CREATE TYPE grant_type_enum          AS ENUM ('STANDARD','JIT','BREAKGLASS'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE grant_status_enum        AS ENUM ('ACTIVE','INACTIVE','REVOKED','EXPIRED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- NOTA: override_type_enum, assurance_outcome_enum, sod_exception_type_enum ELIMINADOS.
-- T-173 usa override_type TEXT + CHECK('DENY_TO_PERMIT','PERMIT_TO_DENY').
-- T-176 usa outcome TEXT + CHECK('PERMIT','STEP_UP_REQUIRED','DENIED').
-- privilege_sod_exception eliminada — SoD se enforcea via trigger en T-170.

-- --- SESIÓN / CAEP ---
DO $$ BEGIN CREATE TYPE caep_event_type_enum     AS ENUM ('credential_change','token_claims_change','session_revoked','assurance_level_change','ip_change','risk_score_change'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE caep_proc_status_enum    AS ENUM ('RECEIVED','PROCESSING','APPLIED','FAILED','IGNORED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE ssf_delivery_method_enum AS ENUM ('PUSH','POLL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE ssf_delivery_status_enum AS ENUM ('SUCCESS','FAILED','RETRYING','ABANDONED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- AUDITORÍA ---
DO $$ BEGIN CREATE TYPE campaign_scope_enum      AS ENUM ('TENANT','USER','ROLE','ATOM'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE campaign_type_enum       AS ENUM ('QUARTERLY','ANNUAL','OFFBOARDING','INCIDENT','SOD_REVIEW'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE campaign_status_enum     AS ENUM ('ACTIVE','COMPLETED','CANCELLED','OVERDUE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE review_decision_enum     AS ENUM ('CERTIFY','REVOKE','ESCALATE','DEFER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- RIESGO / ITDR ---
DO $$ BEGIN CREATE TYPE risk_action_enum         AS ENUM ('STEP_UP','REVOKE','SUSPEND','NOTIFY','REQUIRE_MFA'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- --- PAM ---
DO $$ BEGIN CREATE TYPE jit_status_enum          AS ENUM ('PENDING','APPROVED','ACTIVE','EXPIRED','REVOKED','REJECTED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE breakglass_status_enum   AS ENUM ('PENDING_APPROVAL','ACTIVE','DEACTIVATED','REVIEWED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE pam_access_type_enum     AS ENUM ('SSH','RDP','API','CONSOLE','DB','CLI','VAULT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE credential_ref_type_enum AS ENUM ('PASSWORD','API_KEY','CERTIFICATE','SSH_KEY','SERVICE_TOKEN','OAUTH_TOKEN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE credential_owner_type_enum AS ENUM ('HUMAN','NHI'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE proposal_status_enum     AS ENUM ('DRAFT','PENDING_QUORUM','APPROVED','REJECTED','EXPIRED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

RESET lock_timeout;
RESET client_min_messages;

-- ══════════════════════════════════════════════════════════════════════
-- SEQUENCE — Posiciones de bit para átomos del árbol de políticas
-- ══════════════════════════════════════════════════════════════════════
-- Cada nodo EVALUATION en T-162 (idn_roles_template) recibe un atom_position
-- único e irrevocable desde esta secuencia. Es la base del BitMask 64-bit.
-- Una vez asignada, la posición no cambia aunque el nodo se desactive.
CREATE SEQUENCE IF NOT EXISTS bauth.roles_atom_position_sequentialuential
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 1;

COMMENT ON SEQUENCE bauth.roles_atom_position_sequentialuential IS
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
  '[BCP 47] [RFC 5646] [ISO 639-1/2/3] [ISO 15924] [IANA Language Subtag Registry] [Unicode CLDR 46]
   Catálogo canónico de idiomas para todo el ecosistema SBOS.
   PK: language_id UUIDv7. Natural key: locale UNIQUE NOT NULL.
   Referenciado por: idn_tenant_languages(locale), idn_tenant_config(locale_default).';

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
    country_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    iso_alpha2       CHAR(2)     UNIQUE NOT NULL,
    iso_alpha3       CHAR(3)     UNIQUE NOT NULL,
    iso_numeric      CHAR(3)     UNIQUE NOT NULL,
    name             JSONB       NOT NULL,
    official_name    JSONB,
    region           TEXT,
    subregion        TEXT,
    capital          TEXT,
    flag_emoji       TEXT,
    phone_prefix     TEXT,
    tld              TEXT,
    currency_code    CHAR(3),
    timezone_primary TEXT,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gcty_alpha2   ON bglobal.global_country(iso_alpha2);
CREATE UNIQUE INDEX IF NOT EXISTS idx_gcty_alpha3   ON bglobal.global_country(iso_alpha3);
CREATE INDEX IF NOT EXISTS idx_gcty_region          ON bglobal.global_country(region, iso_alpha2);
CREATE INDEX IF NOT EXISTS idx_gcty_name            ON bglobal.global_country USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bglobal.global_country IS
  '[ISO 3166-1:2020] Catálogo canónico de países. PK: country_id UUIDv7. Natural key: iso_alpha2 UNIQUE.
   Referenciado por: idn_tenant(country), global_currency(issuer_country), geo_timezone(country_code).';

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
  '[ISO 4217:2015] Catálogo de monedas. PK: currency_id UUIDv7. Natural key: currency_code CHAR(3).
   Referenciado por: idn_tenant_currencies(currency_code), idn_tenant_config(currency_default).';

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
  '[IANA TZ Database] [ISO 6709] Catálogo de zonas horarias. PK: timezone_uuid UUIDv7. Natural key: timezone_id.
   Referenciado por: idn_tenant_config(timezone_default), bcalendar.cal_calendar(timezone).';

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
  '[A.65.02 T-059] Árbol de ítems de menú. parent_id self-referencing (adjacency list).
   code = identificador único del ítem: dashboard.home, iam.roles.list.
   label = JSONB multi-idioma: {"es":"Roles","en":"Roles"}.
   Referenciado por: menu_context, menu_item_atom.';

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
  '[A.65.02 T-114] [NIST SP 800-53 CM-6] Parámetros globales cross-daemon del sistema SBOS.
   Es el SUELO del PIP @bauth_config_param: el Motor de Identidad (PDP) busca primero en
   idn_tenant_config (T-009, parámetros del tenant); si no encuentra, cae aquí.
   is_overridable=true: el tenant puede sobrescribir este parámetro en T-009.
   is_overridable=false: el parámetro es un piso de seguridad no modificable por el tenant.
   Catálogo de ~20 parámetros documentado en A.48.';

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
  '[ISO 27001 A.8.2] [NIST 800-53 AC-2] [SBOS-049 §4] [GDPR Art.32]
   Ancla de gobernanza del sistema multi-tenant SBOS. TODA FK de la DDL arranca desde tenant_id.
   El Motor de Identidad (D00) crea una fila aquí al registrar un nuevo tenant.
   REPARACIONES ADR-010: realm_kc/realm_kc_ext, namespace_k8s, kong_consumer_id,
   database_name/database_schema eliminados — infra KC/K8s pertenece a BOS, no a bauth.
   vault_path: única referencia de infra que permanece (Vault PKI es nativo de bauth).';

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
  '[ISO 4217] Monedas habilitadas por tenant con tasa de cambio.
   Natural key: (tenant_id, currency_code) UNIQUE. exchange_source: BCB, ECB, MANUAL.';

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
  '[BCP 47] [RFC 5646] [Unicode CLDR] Idiomas habilitados por tenant.
   translation_provider: sbos_i18n (bi18n daemon), external_api, custom_file.';


-- ======================================================================
-- T-008 — bauth.idn_tenant_verification
-- Verificación KYC/IAL del tenant. 5 pasos → IAL alcanzado.
-- REPARACIÓN: agregado ial_achieved para registrar nivel IAL resultante.
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
  '[NIST SP 800-63A IAL1-3] [ISO 27001 A.8.2]
   Verificación KYC del tenant. 5 pasos secuenciales; al completar FINAL_APPROVAL
   el tenant alcanza un nivel IAL que queda registrado en ial_achieved.
   REPARACIÓN v2: +ial_achieved (IAL1/IAL2/IAL3 alcanzado), +expires_at (documentos con vencimiento).';

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
  '[BCP 47] [ISO 4217] [IANA TZ] [ISO 8601] [SBOS-049]
   Configuración regional y parámetros PIP del tenant. Relación 1:1 con idn_tenant.
   params_policy: fuente de verdad de @bauth_config_param.* del árbol de políticas (T-162).
   El PDP resuelve la referencia: idn_tenant_config (tenant) → bglobal.global_config (sistema).
   REPARACIÓN v2: +params_policy JSONB para soportar el PIP del Motor de Identidad.';

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
  '[RFC 952/1123] [RFC 8446/8555] [SBOS-049 §3.1]
   Dominios DNS del tenant. El dominio primary es la capa 1 del ctx_id (SBOS-049).
   ctx_prefix: segmento que este dominio aporta al ctx_id: skull.sbos.bo.
   REPARACIONES ADR-010/v2: nginx_config, k8s_hpa_config, health_config eliminados
   (configuración de infraestructura K8s/NGINX pertenece a BOS, no a bauth).';

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
  '[RFC 4632] [RFC 1918] [NIST 800-207 ZTA]
   Redes y CIDRs autorizados por tenant. Validados por el PEP (Kong) en D7.
   El Motor de Identidad verifica que el IP del request esté en al menos un CIDR activo.';

COMMENT ON COLUMN bauth.idn_tenant_network.cidr IS '[RFC 4632] Rango CIDR: 10.0.1.0/24, 192.168.0.0/16. GIST index para inet_ops.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║              NIVEL 2 — CALENDARIO (bcalendar + bridge)              ║
-- ║   bcalendar.cal_* · bauth.idn_calendar_assignment                  ║
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
  '[SIN Bolivia] [NIC 1/IAS 1] [NIC 8/IAS 8]
   Años fiscales con 12 períodos contables mensuales (JSONB).
   Multi-gestión: permite operar corriente + anteriores simultáneamente.
   Ley 2492 Bolivia: cierre anual obligatorio; ajustes retroactivos hasta max_adjustment_months_back.';

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
  '[RFC 4791 VCALENDAR] Colecciones de calendarios por tenant.
   is_system=true = predefinido por SBOS; no puede eliminarse.
   timezone: IANA TZ ID; las ocurrencias de cal_event se expanden en esta zona.';


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
  '[RFC 5545 VEVENT] Evento maestro. Una serie = 1 fila con rrule TEXT.
   Las ocurrencias se materializan on-demand vía rrule_plpgsql.
   D4/B2 del árbol de políticas consulta este calendario para validez temporal de roles.';

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
  '[RFC 5545 VALARM] Disparador de notificación. Puente entre calendario y bNotify.
   trigger_seconds negativo = antes del dtstart: -900=15min antes, -86400=1día antes.
   next_trigger_at: calculado por rrule_plpgsql. Job polling: WHERE next_trigger_at <= NOW().';


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
  '[ISO 27001 A.8.15] [WORM] Registro inmutable de notificaciones enviadas por bNotify.
   REVOKE UPDATE/DELETE — solo INSERT. ctx_id obligatorio (SBOS-049).';


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
  'Feriados por país/tenant. is_recurring=true = se repite cada año (Navidad 12-25, Año Nuevo 01-01).
   Bolivia: feriados nacionales (Ley 26 días) + feriados departamentales + propios del tenant.
   D3/D4 del árbol de políticas consultan esta tabla para días hábiles reales.';


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
  '[RFC 7953 VAVAILABILITY] Horarios de trabajo por tenant.
   access_outside_schedule: BLOCKED (denegar acceso), PERMITTED, REQUIRES_APPROVAL, READ_ONLY.
   days_of_week: {1=lunes,...,7=domingo}. D3 del árbol de políticas valida ventanas de operación.';

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
  '[A.65.02 T-124] Políticas de horas extra. Define si el acceso fuera del horario normal
   requiere override de emergencia (D3 del árbol de políticas) y qué aprobaciones activa.
   loa_required_for_override: el PDP exige este LoA mínimo para autorizar el override.
   applies_to_tiers: tiers a los que aplica esta política (los tiers SU/T0 no están restringidos).';

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
  '[A.65.02 T-125] Políticas de pausa (almuerzo, descanso).
   suspend_active_sessions: si true, el daemon suspende sesiones activas al inicio de la pausa.
   resume_requires_reauth: si true, el usuario debe re-autenticarse al retomar (D1 gestión de sesión).
   Soporte de D4 temporal: el PDP consulta esta tabla para validar si el acceso está en pausa.';

COMMENT ON COLUMN bcalendar.cal_break_policy.suspend_active_sessions IS 'true = bAuth suspende sesiones activas al inicio del break (NIST 800-63B-4 §7.2).';
COMMENT ON COLUMN bcalendar.cal_break_policy.resume_requires_reauth  IS 'true = el usuario debe re-autenticarse al volver de pausa.';


-- ======================================================================
-- T-013 — bauth.idn_calendar_assignment
-- Puente: asigna calendarios bcalendar a entidades bauth.
-- REPARACIÓN: FK real a bcalendar.cal_calendar + tenant_id para validación.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_calendar_assignment (
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

CREATE INDEX IF NOT EXISTS idx_ica_tenant   ON bauth.idn_calendar_assignment(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ica_calendar ON bauth.idn_calendar_assignment(calendar_id);
CREATE INDEX IF NOT EXISTS idx_ica_owner    ON bauth.idn_calendar_assignment(owner_type, owner_id);

COMMENT ON TABLE bauth.idn_calendar_assignment IS
  '[A.65.02 T-013] Tabla puente: asigna calendarios bcalendar a entidades bauth.
   owner_type: TENANT, COMPANY, BRANCH, USER. owner_id: el UUID de la entidad.
   Herencia jerárquica: tenant asigna → empresa hereda (is_inherited=true) → sucursal hereda.
   REPARACIÓN v2: +FK real a bcalendar.cal_calendar (antes era UUID huérfano), +tenant_id FK.';

COMMENT ON COLUMN bauth.idn_calendar_assignment.role IS '[ENUM] OWNER (gestiona el calendario), EDITOR (modifica eventos), VIEWER (solo lectura).';
COMMENT ON COLUMN bauth.idn_calendar_assignment.is_inherited IS 'true = asignación heredada del nivel superior (no directa).';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                NIVEL 3 — ROLES (bauth)                              ║
-- ║   Catálogo + tipo + jerarquía + closure table DAG                   ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-040 — bauth.idn_roles_rol_type
-- Clasificación de cuentas: INDIVIDUAL, M2M, SYSTEM, BOT, DEVICE, etc.
-- Catálogo controlado — 10 tipos definidos en A.65.02.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_type (
    type_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    code         TEXT        UNIQUE NOT NULL,
    name         JSONB       NOT NULL,
    description  TEXT,
    is_active    BOOLEAN     NOT NULL DEFAULT true,
    sort_order   INTEGER     NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.idn_roles_rol_type IS
  '[NIST RBAC N3] [ANSI INCITS 359] [A.65.02 T-040]
   Clasificación del tipo de cuenta para TODOS los roles en SBOS.
   10 tipos canónicos: INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE, EMERGENCY.
   Permite aplicar políticas diferenciadas según el tipo de identidad que porta el rol.';

COMMENT ON COLUMN bauth.idn_roles_rol_type.code IS 'INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE, EMERGENCY.';
COMMENT ON COLUMN bauth.idn_roles_rol_type.name IS '[JSONB] {"es":"Individual","en":"Individual"}.';

-- Seeds del catálogo de tipos
INSERT INTO bauth.idn_roles_rol_type (code, name, sort_order) VALUES
    ('INDIVIDUAL',  '{"es":"Individual","en":"Individual"}',  1),
    ('M2M',         '{"es":"Máquina a Máquina","en":"Machine to Machine"}', 2),
    ('SYSTEM',      '{"es":"Sistema","en":"System"}',         3),
    ('GROUP',       '{"es":"Grupo","en":"Group"}',            4),
    ('TEMPLATE',    '{"es":"Plantilla","en":"Template"}',     5),
    ('VIRTUAL',     '{"es":"Virtual","en":"Virtual"}',        6),
    ('BOT',         '{"es":"Bot","en":"Bot"}',                7),
    ('DEVICE',      '{"es":"Dispositivo","en":"Device"}',     8),
    ('SERVICE',     '{"es":"Servicio","en":"Service"}',       9),
    ('EMERGENCY',   '{"es":"Emergencia","en":"Emergency"}',   10)
ON CONFLICT (code) DO NOTHING;


-- ======================================================================
-- T-042 — bauth.idn_roles_rol_tier
-- Parámetros de seguridad por tier (SU, T0, T1, BIZ_N1..N5, EXT_N0, M2M, VISITANTE).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_tier (
    tier_id                  UUID        PRIMARY KEY DEFAULT uuidv7(),
    tier                     rol_tier_enum UNIQUE NOT NULL,
    display_name             JSONB       NOT NULL,
    loa_required             INTEGER     NOT NULL CHECK (loa_required BETWEEN 1 AND 3),
    session_timeout_minutes  INTEGER     NOT NULL DEFAULT 480,
    max_sessions             INTEGER     NOT NULL DEFAULT 3,
    step_up_loa              INTEGER     CHECK (step_up_loa BETWEEN 1 AND 3),
    mfa_required             BOOLEAN     NOT NULL DEFAULT false,
    mfa_methods_allowed      TEXT[]      DEFAULT '{}',
    rate_limit_override      INTEGER,
    nist_aal_reference       TEXT,
    description              TEXT,
    sort_order               INTEGER     NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_irtier_tier ON bauth.idn_roles_rol_tier(tier);

COMMENT ON TABLE bauth.idn_roles_rol_tier IS
  '[NIST SP 800-63B-4 §4] [ISO 27001 A.5.15] [A.65.02 T-042]
   Parámetros de seguridad por tier. Define el LoA requerido, timeout de sesión, MFA, y step-up.
   11 tiers: SU (superusuario, LoA3), T0 (técnico raíz), T1 (técnico tenant),
   BIZ_N1..N5 (negocio por jerarquía), EXT_N0 (externo), M2M (máquina), VISITANTE.';

COMMENT ON COLUMN bauth.idn_roles_rol_tier.loa_required IS '[NIST 800-63B-4] Nivel de aseguramiento mínimo: 1=AAL1, 2=AAL2, 3=AAL3.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.step_up_loa  IS '[RFC 9470] LoA requerido para step-up por contexto de riesgo.';
COMMENT ON COLUMN bauth.idn_roles_rol_tier.mfa_methods_allowed IS 'NULL=todos, ["TOTP","WEBAUTHN"]=restricción por tier.';

-- Seeds del catálogo de tiers
INSERT INTO bauth.idn_roles_rol_tier (tier, display_name, loa_required, session_timeout_minutes, max_sessions, mfa_required, sort_order) VALUES
    ('SU',       '{"es":"Superusuario","en":"Superuser"}',           3, 60,  1, true,  1),
    ('T0',       '{"es":"Técnico Raíz","en":"Root Technician"}',     3, 120, 1, true,  2),
    ('T1',       '{"es":"Técnico Tenant","en":"Tenant Technician"}', 2, 240, 2, true,  3),
    ('BIZ_N1',   '{"es":"Negocio N1","en":"Business N1"}',          2, 480, 3, true,  4),
    ('BIZ_N2',   '{"es":"Negocio N2","en":"Business N2"}',          2, 480, 5, false, 5),
    ('BIZ_N3',   '{"es":"Negocio N3","en":"Business N3"}',          1, 480, 5, false, 6),
    ('BIZ_N4',   '{"es":"Negocio N4","en":"Business N4"}',          1, 480, 5, false, 7),
    ('BIZ_N5',   '{"es":"Negocio N5","en":"Business N5"}',          1, 480, 5, false, 8),
    ('EXT_N0',   '{"es":"Externo N0","en":"External N0"}',          1, 60,  1, false, 9),
    ('M2M',      '{"es":"Máquina a Máquina","en":"Machine to Machine"}', 2, 3600, 10, false, 10),
    ('VISITANTE','{"es":"Visitante","en":"Visitor"}',                1, 30,  1, false, 11)
ON CONFLICT (tier) DO NOTHING;


-- ======================================================================
-- T-041 — bauth.idn_roles_rol_hierarchical
-- Árbol de roles del tenant (adjacency list). FK a T-040 (type), T-042 (tier), T-162 (template).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_hierarchical (
    id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id        UUID        REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE RESTRICT,
    type_id          UUID        NOT NULL REFERENCES bauth.idn_roles_rol_type(type_id),
    tier             rol_tier_enum NOT NULL DEFAULT 'BIZ_N3',
    code             TEXT        NOT NULL,
    name             JSONB       NOT NULL,
    description      TEXT,
    depth            INTEGER     NOT NULL DEFAULT 0,
    is_inheritable   BOOLEAN     NOT NULL DEFAULT true,
    status           rol_status_enum NOT NULL DEFAULT 'ACTIVE',
    version          TEXT        NOT NULL DEFAULT '1.0',
    sector_caeb      TEXT,
    ial_min          ial_level_enum DEFAULT 'IAL1',
    metadata_b1      JSONB       DEFAULT '{}',
    template_id      UUID,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_irrh_tenant    ON bauth.idn_roles_rol_hierarchical(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_irrh_parent    ON bauth.idn_roles_rol_hierarchical(parent_id);
CREATE INDEX IF NOT EXISTS idx_irrh_tier      ON bauth.idn_roles_rol_hierarchical(tenant_id, tier);
CREATE INDEX IF NOT EXISTS idx_irrh_type      ON bauth.idn_roles_rol_hierarchical(type_id);
CREATE INDEX IF NOT EXISTS idx_irrh_template  ON bauth.idn_roles_rol_hierarchical(template_id) WHERE template_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irrh_name      ON bauth.idn_roles_rol_hierarchical USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bauth.idn_roles_rol_hierarchical IS
  '[NIST RBAC N3] [ANSI INCITS 359] [A.65.02 T-041]
   Árbol de roles por tenant (adjacency list). Complementado por T-063 (closure table) para
   consultas eficientes de herencia DAG-OR. template_id: FK DEFERRED a idn_roles_template
   (árbol de políticas, T-162) — relaciona el rol con su nodo en el árbol de políticas compartido.
   sector_caeb: sector CAEB SIN Bolivia que aplica (21 sectores: CAEB-A, CAEB-B, ..., CAEB-U).';

COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.tier       IS '[ENUM] SU, T0, T1, BIZ_N1..N5, EXT_N0, M2M, VISITANTE.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.is_inheritable IS 'true = sus privilegios se heredan a roles hijos en el DAG.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.template_id IS 'FK DEFERRED a bauth.idn_roles_template(id) — nodo DOMAIN del árbol de políticas que rige este rol.';
COMMENT ON COLUMN bauth.idn_roles_rol_hierarchical.metadata_b1 IS '[B1 de SBOS-ROLTEMPLATE-v6_0] Metadatos del bloque 1: {nist_rbac_level, caeb_code, description_long}.';

-- FK deferida al árbol de políticas: se agrega en sección T-162 (después de crear idn_roles_template)


-- ======================================================================
-- T-063 — bauth.idn_roles_rol_closure
-- Closure table para herencia DAG-OR de roles. O(1) consulta de ancestros/descendientes.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_rol_closure (
    ancestor_id   UUID        NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE CASCADE,
    descendant_id UUID        NOT NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE CASCADE,
    depth         INTEGER     NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_irclo_desc  ON bauth.idn_roles_rol_closure(descendant_id, depth);
CREATE INDEX IF NOT EXISTS idx_irclo_anc   ON bauth.idn_roles_rol_closure(ancestor_id, depth);
CREATE INDEX IF NOT EXISTS idx_irclo_depth ON bauth.idn_roles_rol_closure(depth);

COMMENT ON TABLE bauth.idn_roles_rol_closure IS
  '[NIST RBAC N3 §2.3] [Tropashko closure tables] [A.65.02 T-063]
   Closure table para herencia DAG-OR de roles. Una fila = (ancestor, descendant, depth).
   depth=0: rol es ancestro de sí mismo (reflexividad). depth=1: hijo directo. depth>1: transitivo.
   Mantenida por triggers en idn_roles_rol_hierarchical (INSERT/UPDATE parent_id).
   Consulta de todos los roles heredados de un rol: WHERE ancestor_id=rol_id.
   Consulta de todos los roles que heredan de un rol: WHERE descendant_id=rol_id.
   Tiempo de evaluación BitMask: O(1) con JOIN en el motor (evaluación < 0.5ns).';

COMMENT ON COLUMN bauth.idn_roles_rol_closure.ancestor_id   IS 'Rol ancestro en la jerarquía.';
COMMENT ON COLUMN bauth.idn_roles_rol_closure.descendant_id IS 'Rol descendiente (hereda del ancestor).';
COMMENT ON COLUMN bauth.idn_roles_rol_closure.depth         IS '0=self, 1=hijo directo, N=N niveles de herencia.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║            NIVEL 4 — VERSIONADO (bauth)                            ║
-- ║   WITH WITHOUT OVERLAPS — Temporal constraints PG18                ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-152 — bauth.idn_rol_hierarchical_ver_history  [STUB — diseño pendiente]
-- Historia WORM de definiciones gobernadas de roles.
-- Responde "¿cómo era el rol X el día Y?" con delta por bloque normado.
-- Fotografía ancla en versiones MAJOR; no-solapamiento WITHOUT OVERLAPS (PG18).
-- ======================================================================
-- TODO: implementar estructura canónica con EXCLUDE USING GIST + PG18 temporal constraints.
-- Depende de T-042 (idn_roles_rol_hierarchical).


-- ======================================================================
-- T-154 — bauth.idn_roles_rol_ver_retention_schedule  [STUB — diseño pendiente]
-- Calendario de retención legal por categoría de artefacto.
-- Plazos mínimos: Ley 843 (10 años), PCI DSS (1 año), ISO 27001 (3 años).
-- CHECK impide plazos bajo el piso del dominio D99 (archivo legal).
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe el Motor MVU 1.13.


-- ======================================================================
-- T-155 — bauth.idn_roles_template_ver_changelog  [STUB — diseño pendiente]
-- Changelog estructural del contrato RolTemplate entre versiones (v5.0→v6.0).
-- Registra: bloques agregados/removidos, normas que entran/salen, compatibilidad BREAKING/COMPATIBLE.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe el Motor MVU 1.13.
-- Depende de T-162 (idn_roles_template).


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
    descripcion TEXT        NOT NULL,
    activo      BOOLEAN     NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  TEXT        NOT NULL,
    CONSTRAINT privilege_verb_pkey   PRIMARY KEY (verb_id),
    -- snake_case obligatorio: letras minúsculas, números, guion bajo
    CONSTRAINT chk_pv_verb_id_format CHECK (verb_id ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE bauth.privilege_verb IS
  '[NIST SP 800-53 AC-5] [XACML 3.0 §4.3] [G-03] [A.65.02 T-174]
   Catálogo de verbos atómicos del sistema. LISTA DE VALIDACIÓN ÚNICAMENTE.
   NO participa en la construcción del RolBitMask ni en el PDP en runtime de autenticación.
   Consultada solo en CRUD de idn_roles_template (FK verb_id) y privilege_verb_conflict.
   Verbos base canónicos: create, read, update, delete, validate, approve, execute, export,
     archive, assign, delegate, certify, sign, audit, report, config, manage, reassess.
   PK = verb_id TEXT snake_case: leíble, estable, auto-documentado.';

COMMENT ON COLUMN bauth.privilege_verb.verb_id     IS 'PK texto snake_case: [a-z][a-z0-9_]*. Ej: create, approve, sign_document.';
COMMENT ON COLUMN bauth.privilege_verb.activo       IS 'Los verbos nunca se eliminan — se desactivan (activo=false) para trazabilidad histórica.';


-- ======================================================================
-- T-175 — bauth.privilege_verb_conflict
-- Matriz SoD entre verbos. PK compuesta (verb_a, verb_b) en orden alfabético.
-- LISTA DE VALIDACIÓN — consultada por trigger fn_check_sod_on_grant en T-170.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_verb_conflict (
    verb_a      TEXT        NOT NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE CASCADE,
    verb_b      TEXT        NOT NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE CASCADE,
    tipo        TEXT        NOT NULL,
    descripcion TEXT        NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  TEXT        NOT NULL,
    CONSTRAINT privilege_verb_conflict_pkey  PRIMARY KEY (verb_a, verb_b),
    -- Un verbo no puede conflictuar consigo mismo
    CONSTRAINT chk_pvc_no_self_conflict      CHECK (verb_a <> verb_b),
    -- Almacenar siempre en orden alfabético: elimina duplicados (A,B) y (B,A)
    CONSTRAINT chk_pvc_orden_alfabetico      CHECK (verb_a < verb_b),
    CONSTRAINT chk_pvc_tipo                  CHECK (tipo IN ('SOD_ESTATICO','SOD_DINAMICO','AFINIDAD'))
);

CREATE INDEX IF NOT EXISTS idx_pvc_verba ON bauth.privilege_verb_conflict(verb_a);
CREATE INDEX IF NOT EXISTS idx_pvc_verbb ON bauth.privilege_verb_conflict(verb_b);
CREATE INDEX IF NOT EXISTS idx_pvc_tipo  ON bauth.privilege_verb_conflict(tipo);

COMMENT ON TABLE bauth.privilege_verb_conflict IS
  '[NIST SP 800-53 AC-5] [ISO 27001 A.6.1.2] [G-03] [A.65.02 T-175]
   Matriz de conflictos SoD entre verbos. LISTA DE VALIDACIÓN ÚNICAMENTE.
   NO participa en BitMask ni en PDP en runtime. Su único rol: responder
   "¿pueden coexistir estos dos verbos para el mismo usuario?"
   SOD_ESTATICO: conflicto siempre prohibido (ej: crear + aprobar).
   SOD_DINAMICO: prohibido solo en el mismo objeto/instancia.
   AFINIDAD: verbos complementarios (no genera rechazo, solo sugerencia).
   PK (verb_a, verb_b) con verb_a < verb_b: cada par almacenado una sola vez.
   El trigger fn_check_sod_on_grant consulta en ambas direcciones.';

COMMENT ON COLUMN bauth.privilege_verb_conflict.tipo IS '[TEXT] SOD_ESTATICO | SOD_DINAMICO | AFINIDAD.';


-- ======================================================================
-- T-162 — bauth.idn_roles_template
-- Árbol de políticas PER-TENANT (G-06). Cada tenant tiene su propio árbol.
-- 9 tipos de nodo en español: dominio|bloque|objeto|lista|politica|regla|
--   evaluacion|atributo|enumerado. (diagnostico = solo Dart, nunca en BD — G-11)
-- atom_position: asignado por trigger desde roles_atom_position_sequential
--   SOLO para nodos tipo='evaluacion'. Inmutable una vez asignado.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_roles_template (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- tenant_id NOT NULL (G-06 §"árbol per-tenant"): cada empresa tiene su árbol propio.
    -- Bootstrap: se copia la estructura del tenant-plantilla (tipos ≠ evaluacion).
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id      UUID        REFERENCES bauth.idn_roles_template(id) ON DELETE RESTRICT,
    tipo           TEXT        NOT NULL,
    clave          TEXT        NOT NULL,
    name           JSONB       NOT NULL,
    valor          TEXT        NULL,
    help           TEXT        NULL,
    opciones       TEXT[]      NOT NULL DEFAULT '{}',
    description    TEXT,
    -- verb_id: FK textual a privilege_verb (catálogo global G-03). Solo para tipo='evaluacion'.
    verb_id        TEXT        NULL REFERENCES bauth.privilege_verb(verb_id) ON DELETE RESTRICT,
    atom_position  BIGINT      UNIQUE,
    -- effect: boolean (true=PERMIT, false=DENY). Sincronizado a T-170 por trigger (G-12 CAMBIO 8).
    effect         BOOLEAN     NOT NULL DEFAULT false,
    condition_expr JSONB,
    domain_number  INTEGER,
    depth          INTEGER     NOT NULL DEFAULT 0,
    orden          INTEGER     NOT NULL DEFAULT 0,
    path           TEXT        UNIQUE NOT NULL,
    activo         BOOLEAN     NOT NULL DEFAULT true,
    version        TEXT        NOT NULL DEFAULT '1.0',
    valid_from     DATE        NOT NULL DEFAULT CURRENT_DATE,
    valid_until    DATE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- 9 tipos canónicos en español (G-11 §2). diagnostico NO se persiste.
    CONSTRAINT chk_irt_tipo CHECK (
        tipo IN ('dominio','bloque','objeto','lista','politica','regla',
                 'evaluacion','atributo','enumerado')
    ),
    -- verb_id obligatorio SOLO para evaluacion (G-03 · G-11 §4)
    CONSTRAINT chk_irt_verb_solo_evaluacion CHECK (
        (tipo = 'evaluacion' AND verb_id IS NOT NULL)
        OR (tipo <> 'evaluacion' AND verb_id IS NULL)
    ),
    -- domain_number obligatorio SOLO para dominio
    CONSTRAINT chk_irt_domain_number CHECK (
        (tipo = 'dominio' AND domain_number IS NOT NULL)
        OR (tipo <> 'dominio')
    ),
    -- valid_until posterior a valid_from
    CONSTRAINT chk_irt_valid_range CHECK (
        valid_until IS NULL OR valid_until > valid_from
    ),
    -- atom_position SOLO para evaluacion — asignado por trigger (G-11 §4)
    CONSTRAINT chk_irt_atom_pos_solo_evaluacion CHECK (
        (tipo = 'evaluacion' AND atom_position IS NOT NULL)
        OR (tipo <> 'evaluacion' AND atom_position IS NULL)
    ),
    -- Unicidad per-tenant (G-06): (tenant_id, parent_id, clave)
    CONSTRAINT uq_irt_tenant_parent_clave UNIQUE (tenant_id, parent_id, clave),
    -- Unicidad compuesta para soportar FK compuesta desde T-170/T-173 (G-12 · A.65.02.01 §6.6)
    CONSTRAINT uq_irt_id_atom_position UNIQUE (id, atom_position)
);

CREATE INDEX IF NOT EXISTS idx_irt_tenant    ON bauth.idn_roles_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_irt_parent    ON bauth.idn_roles_template(parent_id);
CREATE INDEX IF NOT EXISTS idx_irt_tipo      ON bauth.idn_roles_template(tipo, activo);
CREATE INDEX IF NOT EXISTS idx_irt_path      ON bauth.idn_roles_template(path);
CREATE INDEX IF NOT EXISTS idx_irt_atom_pos  ON bauth.idn_roles_template(atom_position) WHERE atom_position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_domain    ON bauth.idn_roles_template(domain_number) WHERE domain_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_verb      ON bauth.idn_roles_template(verb_id) WHERE verb_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_irt_activo    ON bauth.idn_roles_template(activo, tipo);
CREATE INDEX IF NOT EXISTS idx_irt_name      ON bauth.idn_roles_template USING GIN (name jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_irt_cond      ON bauth.idn_roles_template USING GIN (condition_expr jsonb_path_ops) WHERE condition_expr IS NOT NULL;

-- FK deferida: idn_roles_rol_hierarchical.template_id → idn_roles_template.id
-- Se declara aquí porque idn_roles_template se crea en este punto (T-162 precede a T-041 en el DDL)
ALTER TABLE bauth.idn_roles_rol_hierarchical
    ADD CONSTRAINT fk_irrh_template
    FOREIGN KEY (template_id)
    REFERENCES bauth.idn_roles_template(id)
    ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

COMMENT ON TABLE bauth.idn_roles_template IS
  '[XACML 3.0] [NIST RBAC N3] [ISO 27001 A.5.15] [G-06] [G-11] [A.65.02 T-162]
   Árbol de políticas PER-TENANT de bAuth. Cada tenant tiene su propio árbol (G-06).
   Estructura: dominio (raíz, D01-D37) > bloque > objeto/lista > politica > regla > evaluacion.
   Bootstrap: al crear tenant se copia la estructura (todos los tipos EXCEPTO evaluacion)
     del tenant-plantilla. Las zonas de negocio llegan vacías de átomos; la empresa los define.
   atom_position: BIGINT único desde roles_atom_position_sequential — SOLO para tipo=evaluacion.
     Posición del bit en el BitMask del dominio. Asignada por trg_irt_atom_position; inmutable.
   effect: boolean (true=PERMIT, false=DENY). Sincronizado automáticamente a privilege_atom_grant
     por trigger trg_t162_sync_effect_to_grants (G-12 CAMBIO 8).
   path: camino materializado único: D01.B1.P001.E001. Base de lookup eficiente.
   condition_expr: JSON AST compilado por AtomLang — evaluado por el Motor de Identidad (PDP).';

COMMENT ON COLUMN bauth.idn_roles_template.tenant_id     IS '[G-06] FK a idn_tenant. El árbol es per-tenant — cada empresa tiene el suyo.';
COMMENT ON COLUMN bauth.idn_roles_template.tipo          IS '[TEXT] 9 tipos: dominio|bloque|objeto|lista|politica|regla|evaluacion|atributo|enumerado (G-11).';
COMMENT ON COLUMN bauth.idn_roles_template.clave         IS 'Identificador del nodo dentro de su padre. Parte de la UNIQUE (tenant_id, parent_id, clave).';
COMMENT ON COLUMN bauth.idn_roles_template.atom_position IS 'Posición de bit en BitMask del dominio. BIGINT único, asignado por trigger. SOLO para evaluacion. Inmutable.';
COMMENT ON COLUMN bauth.idn_roles_template.effect        IS '[G-12] boolean: true=PERMIT, false=DENY. Sincronizado a privilege_atom_grant por trigger.';
COMMENT ON COLUMN bauth.idn_roles_template.path          IS 'Camino materializado: D01.B1.P001.E001. UNIQUE. Base de lookup eficiente.';
COMMENT ON COLUMN bauth.idn_roles_template.condition_expr IS '[AtomLang] JSON AST de la condición compilada: {"op":"AND","left":{...},"right":{...}}.';
COMMENT ON COLUMN bauth.idn_roles_template.domain_number IS 'Número del dominio para nodos tipo=dominio: D01=1, D12=12, D13=13 (biedata), ...D37.';
COMMENT ON COLUMN bauth.idn_roles_template.verb_id       IS '[G-03] FK textual a privilege_verb. Solo nodos tipo=evaluacion tienen verb_id. Global (sin tenant_id).';

-- Trigger: asignar atom_position desde secuencia SOLO a nodos tipo='evaluacion'
CREATE OR REPLACE FUNCTION bauth.fn_irt_assign_atom_position()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tipo = 'evaluacion' AND NEW.atom_position IS NULL THEN
        NEW.atom_position := nextval('bauth.roles_atom_position_sequential');
    ELSIF NEW.tipo <> 'evaluacion' AND NEW.atom_position IS NOT NULL THEN
        RAISE EXCEPTION '[T-162] atom_position solo válida para nodos tipo=evaluacion. tipo=%', NEW.tipo;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_irt_atom_position
    BEFORE INSERT ON bauth.idn_roles_template
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_irt_assign_atom_position();

COMMENT ON FUNCTION bauth.fn_irt_assign_atom_position() IS
  '[A.65.02 T-162] Asigna atom_position desde roles_atom_position_sequential para tipo=evaluacion.
   Inmutable: atom_position no puede cambiarse una vez asignado (posición de bit estable — NIST RBAC N3).
   Nodos no-evaluacion rechazan atom_position explícito.';

-- Trigger G-12 CAMBIO 8: sincronizar effect de T-162 → T-170 (privilege_atom_grant)
-- Cuando el árbol cambia el effect de un nodo evaluacion, todos los grants activos
-- de ese átomo actualizan automáticamente su columna effect (espejo).
CREATE OR REPLACE FUNCTION bauth.fn_sync_effect_from_tree()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.effect IS DISTINCT FROM NEW.effect AND NEW.tipo = 'evaluacion' THEN
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

CREATE TRIGGER trg_t162_sync_effect_to_grants
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
  '[ISO 27001 A.8.15] [NIST SP 800-53 AU-9] [WORM] [A.65.02 T-163]
   Registro inmutable de cambios al árbol de políticas. REVOKE UPDATE/DELETE.
   hash_chain = SHA-256(prev_hash || node_id || operation || after_row::text || created_at).
   Convención uniforme con T-170b: before_row/after_row, hash_chain BYTEA, prev_hash BYTEA.';


-- ======================================================================
-- T-153 — bauth.idn_roles_rol_ver_proposal  [STUB — diseño pendiente]
-- Propuestas de cambio MAJOR pendientes de quórum B3 (N-de-M aprobadores).
-- La definición propuesta espera aquí mientras el quórum se completa;
-- la versión vigente sigue rigiendo durante la espera.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe el Motor MVU 1.13.
-- Depende de T-162 (idn_roles_template) y del workflow de aprobación JIT (T-182).


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║           NIVEL 6 — IDENTIDAD D00 (bauth)                          ║
-- ║   D00: Jerarquía de entidades + NHI (Non-Human Identities)         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-156 — bauth.idn_identidad_entidad
-- Raíz del modelo de identidad D00. Toda entidad: tenant, bdomain, bsubdomain, pos, actor.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_entidad (
    entidad_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id        UUID        REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE RESTRICT,
    nivel            entidad_nivel_enum NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_iie_tenant  ON bauth.idn_identidad_entidad(tenant_id, nivel);
CREATE INDEX IF NOT EXISTS idx_iie_parent  ON bauth.idn_identidad_entidad(parent_id);
CREATE INDEX IF NOT EXISTS idx_iie_status  ON bauth.idn_identidad_entidad(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_iie_name    ON bauth.idn_identidad_entidad USING GIN (name jsonb_path_ops);

COMMENT ON TABLE bauth.idn_identidad_entidad IS
  '[ISO 24760-2:2025] [NIST SP 800-63A] [A.65.02 T-156] [D00 Motor de Identidad]
   Raíz del modelo D00. Toda identidad en SBOS es una entidad aquí: tenant, bdomain, bsubdomain, pos, actor.
   Jerarquía de 5 niveles: tenant > bdomain (empresa) > bsubdomain (sucursal) > pos (punto de venta) > actor.
   El actor es el nodo hoja — la identidad humana o no-humana que porta credenciales.';

COMMENT ON COLUMN bauth.idn_identidad_entidad.nivel IS '[ENUM] tenant, bdomain, bsubdomain, pos, actor. 5 niveles de la jerarquía D00.';
COMMENT ON COLUMN bauth.idn_identidad_entidad.path  IS 'Camino materializado: tenant.company.branch.pos.actor. Recalculado por trigger.';


-- ======================================================================
-- T-157 — bauth.idn_identidad_atributo
-- Atributos de identidad por entidad. JSONB abierto + campos de metadato ISO.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_identidad_atributo (
    atributo_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    entidad_id       UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE CASCADE,
    attr_namespace   TEXT        NOT NULL DEFAULT 'core',
    attr_key         TEXT        NOT NULL,
    attr_value       JSONB       NOT NULL,
    attr_type        TEXT        NOT NULL DEFAULT 'TEXT',
    verified         BOOLEAN     NOT NULL DEFAULT false,
    verified_at      TIMESTAMPTZ,
    verified_by      UUID,
    source           TEXT        NOT NULL DEFAULT 'self',
    valid_from       TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until      TIMESTAMPTZ,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    ctx_id           TEXT        NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entidad_id, attr_namespace, attr_key)
);

CREATE INDEX IF NOT EXISTS idx_iiattr_entidad ON bauth.idn_identidad_atributo(entidad_id, attr_namespace);
CREATE INDEX IF NOT EXISTS idx_iiattr_key     ON bauth.idn_identidad_atributo(attr_key, attr_namespace);
CREATE INDEX IF NOT EXISTS idx_iiattr_value   ON bauth.idn_identidad_atributo USING GIN (attr_value jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_iiattr_active  ON bauth.idn_identidad_atributo(entidad_id, is_active) WHERE is_active = true;

COMMENT ON TABLE bauth.idn_identidad_atributo IS
  '[ISO 11179 §8] [ISO 24760-1 §5.3] [NIST SP 800-63A IAL1-3] [A.65.02 T-157]
   Atributos de identidad por entidad. Modelo EAV controlado: attr_namespace.attr_key = valor.
   attr_namespace: core (básico), professional (laboral), verification (IAL), security (acceso).
   verified: true = atributo verificado contra fuente externa (IAL2/IAL3 requieren verified=true).
   source: self, document, biometric, employer, government, blockchain.';

COMMENT ON COLUMN bauth.idn_identidad_atributo.attr_namespace IS 'core, professional, verification, security, contact, fiscal.';
COMMENT ON COLUMN bauth.idn_identidad_atributo.source IS '[NIST 800-63A] self=autoreportado, document=cédula verificada, biometric, employer, government.';


-- ======================================================================
-- T-158 — bauth.idn_identidad_atributo_history  [STUB — diseño pendiente]
-- Historial WORM de cambios en idn_identidad_atributo. Particionado por mes.
-- ISO 27001:2022 A.8.15 · PCI DSS 10.3.2 · GDPR Art. 30.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe la sección IDENTIDAD completa.
-- La tabla referencia a T-157 (idn_identidad_atributo) y lleva hash-chain para integridad WORM.

-- ======================================================================
-- T-159 — bauth.idn_identidad_requisito  [STUB — diseño pendiente]
-- Completitud mínima por tipo de entidad y nivel IAL (IAL1/IAL2/IAL3).
-- Define qué atributos son obligatorios antes de crear una entidad.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe la sección IDENTIDAD completa.
-- Validada por el Motor de Identidad antes de cualquier INSERT en idn_identidad_entidad.

-- ======================================================================
-- T-160 — bauth.idn_identidad_sinonimo  [STUB — diseño pendiente]
-- Sinónimos y abreviaturas para búsqueda difusa. Fuente de verdad para archivos .syn de PG.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe la sección IDENTIDAD completa.
-- Administrable desde el dashboard; alimenta al motor de búsqueda D93 (bsearch).

-- ======================================================================
-- T-161 — bauth.idn_identidad_sinonimo_sync  [STUB — diseño pendiente]
-- Control de sincronización de diccionarios .syn. Evita recarga innecesaria.
-- ======================================================================
-- TODO: implementar estructura canónica cuando se diseñe la sección IDENTIDAD completa.
-- Registra cuándo se regeneraron los archivos .syn desde T-160.


-- ======================================================================
-- T-186 — bauth.idn_non_human_identity
-- Entidad raíz de toda identidad máquina: daemons, bots, pipelines, service accounts, agentes IA.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_non_human_identity (
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
    CONSTRAINT idn_non_human_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_nhi_system_ref UNIQUE (tenant_id, system_ref),
    CONSTRAINT chk_inhi_type CHECK (
        nhi_type IN ('SERVICE_ACCOUNT','WORKLOAD','AGENT','BOT','API_CLIENT','CI_CD_PIPELINE')
    ),
    CONSTRAINT chk_inhi_status CHECK (
        status IN ('ACTIVE','DORMANT','DECOMMISSIONED','SUSPENDED')
    )
);

CREATE INDEX IF NOT EXISTS idx_inhi_owner   ON bauth.idn_non_human_identity (owner_id);
CREATE INDEX IF NOT EXISTS idx_inhi_review  ON bauth.idn_non_human_identity (review_at) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_inhi_dormant ON bauth.idn_non_human_identity (last_used_at) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.idn_non_human_identity IS
  '[NIST SP 800-53 IA-2/AC-2] [ISO 27001:2022 A.5.16] [Gartner IGA 2025] [A.65.02 T-186] ✅ G-21
   Entidad raíz de toda identidad máquina gobernada del ecosistema SBOS.
   system_ref: identificador único del NHI en el tenant (ej: bkernel:sync-worker-01).
   owner_id: persona humana responsable — accountable si el NHI actúa incorrectamente.
   last_used_at: actualizado en cada autenticación exitosa; detecta dormancia >90 días.
   review_at: cuándo debe revisarse este NHI (30d para CI/CD; 90d para service accounts).
   Seeds IAM Installer: una fila por daemon SBOS (bkernel, biedata, bnotify, bsearch, bnexus).';

-- ======================================================================
-- T-187 — bauth.idn_nhi_lifecycle_event
-- Log WORM de eventos del ciclo de vida de un NHI. Append-only. ISO 27001 A.8.15.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_lifecycle_event (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id          UUID        NOT NULL REFERENCES bauth.idn_non_human_identity(id),
    event_type      TEXT        NOT NULL,
    actor_id        UUID        NOT NULL,
    event_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes           TEXT        NULL,
    metadata        JSONB       NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT idn_nhi_lifecycle_event_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inle_type CHECK (
        event_type IN (
            'PROVISIONED','CERTIFIED','ROTATED','SUSPENDED',
            'REACTIVATED','DECOMMISSIONED','OWNER_CHANGED','REVIEW_SCHEDULED'
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_inle_nhi ON bauth.idn_nhi_lifecycle_event (nhi_id, event_at DESC);

REVOKE UPDATE, DELETE ON bauth.idn_nhi_lifecycle_event FROM bauth_app_role;

COMMENT ON TABLE bauth.idn_nhi_lifecycle_event IS
  '[NIST SP 800-53 IA-5(4)] [ISO 27001:2022 A.8.2/A.8.15] [A.65.02 T-187] ✅ G-22
   Log WORM append-only del ciclo de vida de cada NHI. Trigger automático en T-186 por cambio de estado.
   PROVISIONED → CERTIFIED → ROTATED / SUSPENDED → REACTIVATED → DECOMMISSIONED.
   REVOKE UPDATE/DELETE desde bauth_app_role: solo INSERT desde el daemon.';

-- ======================================================================
-- T-188 — bauth.idn_nhi_certification
-- Certificación periódica mensual de NHI por el propietario técnico.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_certification (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id          UUID        NOT NULL REFERENCES bauth.idn_non_human_identity(id),
    reviewer_id     UUID        NOT NULL,
    period_start    TIMESTAMPTZ NOT NULL,
    period_end      TIMESTAMPTZ NOT NULL,
    last_used_at    TIMESTAMPTZ NULL,
    access_count    INTEGER     NULL,
    decision        TEXT        NOT NULL,
    justification   TEXT        NULL,
    reviewed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT idn_nhi_certification_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inc_decision CHECK (
        decision IN ('CERTIFY','DECOMMISSION','REDUCE_SCOPE','ESCALATE')
    )
);

CREATE INDEX IF NOT EXISTS idx_inc_nhi ON bauth.idn_nhi_certification (nhi_id, reviewed_at DESC);

COMMENT ON TABLE bauth.idn_nhi_certification IS
  '[NIST SP 800-53 AC-2(7)] [ISO 27001:2022 A.5.16] [CIS Benchmark §Service Accounts] [A.65.02 T-188] ✅ G-22
   Certificación periódica mensual de NHI. El propietario técnico decide: CERTIFY/DECOMMISSION/REDUCE_SCOPE/ESCALATE.
   access_count=0 en el período es el indicador más fuerte para descomisionar.
   Cadencia mensual (más frecuente que certificación humana trimestral — NHI cambian más rápido).';

-- ======================================================================
-- T-190 — bauth.idn_agent_identity
-- Especialización de NHI para agentes IA autónomos con permisos acotados.
-- ⚠️ PENDIENTE decisión HITL: ¿herencia de permisos padre→hijo o permisos propios?
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_agent_identity (
    id                   UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id               UUID        NOT NULL REFERENCES bauth.idn_non_human_identity(id),
    agent_framework      TEXT        NOT NULL,
    orchestrator_id      UUID        NULL REFERENCES bauth.idn_agent_identity(id),
    max_permission_scope TEXT[]      NOT NULL DEFAULT '{}',
    session_type         TEXT        NOT NULL DEFAULT 'EPHEMERAL',
    can_spawn_agents     BOOLEAN     NOT NULL DEFAULT false,
    max_spawn_depth      INTEGER     NOT NULL DEFAULT 0,
    CONSTRAINT idn_agent_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_iai_nhi UNIQUE (nhi_id),
    CONSTRAINT chk_iai_session CHECK (session_type IN ('EPHEMERAL','PERSISTENT')),
    CONSTRAINT chk_iai_spawn CHECK (
        (can_spawn_agents = false AND max_spawn_depth = 0)
        OR (can_spawn_agents = true AND max_spawn_depth > 0)
    )
);

COMMENT ON TABLE bauth.idn_agent_identity IS
  '[NIST AI RMF 1.0] [CSA NHI Governance 2025] [ISO 42001:2023] [A.65.02 T-190] ✅ G-24
   Especialización de idn_non_human_identity para agentes IA autónomos.
   max_permission_scope limita qué dominios puede usar el agente aunque su NHI padre tenga más acceso.
   can_spawn_agents=false por defecto; solo orquestradores pueden crear sub-agentes con max_spawn_depth>0.
   orchestrator_id: árbol de orquestación padre → hijo para forensia de acciones de agente.
   ⚠️ Pendiente HITL: decisión sobre si el hijo hereda permisos del padre o tiene permisos propios.';


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
    user_id       UUID        NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE CASCADE,
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

ALTER TABLE bauth.privilege_atom_grant REPLICA IDENTITY FULL;

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

COMMENT ON TABLE bauth.privilege_atom_grant IS
  '[XACML 3.0 §5.29] [NIST RBAC N3] [ISO 27001 A.5.18] [G-12] [A.65.02 T-170]
   Grant de átomos de privilegio por usuario (modelo per-user, no por rol genérico — G-09).
   Modelo 5 columnas G-12: effect (espejo árbol) + general (precedencia) + local (derivado) +
     access (override) + reassess (elegibilidad CAEP). Ver G-12 §1 para semántica completa.
   FK compuesta (id_atom, atom_position) DEFERRABLE: garantiza coherencia atómica con T-162.
   REPLICA IDENTITY FULL: bauth-reactor recibe todos los cambios via WAL → actualiza Redis.';

COMMENT ON COLUMN bauth.privilege_atom_grant.id_atom       IS 'FK a idn_roles_template(id). Nodo DEBE ser tipo=evaluacion (tiene atom_position).';
COMMENT ON COLUMN bauth.privilege_atom_grant.atom_position IS 'Copia de idn_roles_template.atom_position. Garantizado por FK compuesta DEFERRABLE.';
COMMENT ON COLUMN bauth.privilege_atom_grant.bitmask_value IS 'Valor del bit en el RolBitMask. Precomputado al insertar para reconstruir BitMask sin JOIN.';
COMMENT ON COLUMN bauth.privilege_atom_grant.effect        IS '[G-12] Espejo del Effect del árbol T-162. true=PERMIT, false=DENY. NUNCA editar directamente.';
COMMENT ON COLUMN bauth.privilege_atom_grant.general       IS '[G-12] true=árbol manda (effect prevalece). false=grant manda (access prevalece). Nace true.';
COMMENT ON COLUMN bauth.privilege_atom_grant.local         IS '[G-12] Derivado: NOT general. Columna GENERATED. Solo para legibilidad visual.';
COMMENT ON COLUMN bauth.privilege_atom_grant.access        IS '[G-12] Override del grant. Forzado a true por trigger cuando general=true. Editable con general=false.';
COMMENT ON COLUMN bauth.privilege_atom_grant.reassess      IS '[G-12][RFC 8935] Elegibilidad CAEP. NULL=default tenant. true=elegible. false=inmune (break-glass).';
COMMENT ON COLUMN bauth.privilege_atom_grant.grant_type    IS '[ENUM] STANDARD=normal, JIT=just-in-time con valid_until, BREAKGLASS=emergencia dual-control.';

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

CREATE TRIGGER trg_t170_sync_access_general
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
    WHERE id = NEW.id_atom AND tipo = 'evaluacion';

    IF v_verb_nuevo IS NULL THEN
        RETURN NEW;
    END IF;

    -- Buscar si el usuario ya tiene activo un átomo cuyo verbo conflictúe
    SELECT irt.verb_id, irt.clave
    INTO v_verb_existente, v_atom_existente
    FROM bauth.privilege_atom_grant pag
    JOIN bauth.idn_roles_template irt ON irt.id = pag.id_atom
    WHERE pag.user_id   = NEW.user_id
      AND pag.tenant_id = NEW.tenant_id
      AND pag.access    = true
      AND pag.status    = 'ACTIVE'
      AND irt.tipo      = 'evaluacion'
      AND irt.verb_id IS NOT NULL
      AND EXISTS (
          SELECT 1 FROM bauth.privilege_verb_conflict pvc
          WHERE tipo IN ('SOD_ESTATICO','SOD_DINAMICO')
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
   Si el verbo del nuevo átomo conflictúa (SOD_ESTATICO/DINAMICO) con verbos activos
   del usuario → ROLLBACK con mensaje descriptivo. No actúa en DENY (access=false).';

CREATE TRIGGER trg_t170_sod_check
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
      FROM bauth.idn_role_template rt
      JOIN bauth.idn_role_type     rty ON rty.id = rt.type_id
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

CREATE TRIGGER trg_validate_breakglass_grant
    BEFORE INSERT OR UPDATE OF grant_type, status
    ON bauth.privilege_atom_grant
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_validate_breakglass_grant();


-- ======================================================================
-- T-170b — bauth.privilege_atom_audit  [WORM + hash-chain pgcrypto]
-- Registro inmutable de cambios en grants. INSERT-only con hash-chain SHA-256.
-- before_row/after_row (no old_data/new_data). hash_chain BYTEA (no TEXT).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit (
    audit_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
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
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- WORM: solo el rol del daemon bauth puede escribir; nadie puede borrar ni actualizar
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM bauth_app_role;

CREATE INDEX IF NOT EXISTS idx_paa_grant  ON bauth.privilege_atom_audit(grant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_paa_tenant ON bauth.privilege_atom_audit(tenant_id, created_at DESC);

COMMENT ON TABLE bauth.privilege_atom_audit IS
  '[ISO 27001 A.8.15] [NIST SP 800-53 AU-9] [WORM] [G-01] [A.65.02 T-170b]
   Registro inmutable de cambios en grants. INSERT-only (WORM).
   before_row/after_row: snapshot del grant antes y después del cambio.
   hash_chain BYTEA: SHA-256(prev_hash||grant_id||operation||after_row||created_at).
   prev_hash BYTEA NULL: enlace a la fila anterior — forma cadena de hash verificable.
   Particionada por mes para alta volumetría. Poblada por trg_t170_worm (G-01).';

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

CREATE TRIGGER trg_t170_worm
    AFTER INSERT OR UPDATE ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_worm_append();


-- ======================================================================
-- T-171 — bauth.privilege_resource_atom  [PAP para Kong PEP]
-- Mapeo (tipo_protocolo + recurso + operacion) → id_atom por tenant.
-- Kong carga esta tabla al arrancar. G-04: columna obligation JSONB NULL.
-- G-06: tenant_id NOT NULL — el mismo endpoint puede mapear a átomos distintos por tenant.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_resource_atom (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- tenant_id NOT NULL (G-06): mapeo per-tenant — cada tenant tiene su árbol T-162 propio.
    tenant_id      UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    tipo_protocolo TEXT        NOT NULL,   -- WS_RPC / JSON_RPC / GRPC / UNIX_SOCKET / HTTP_EXT
    recurso        TEXT        NOT NULL,   -- Ej: "bauth.token.validate", "/api/v1/auth"
    operacion      TEXT        NOT NULL,   -- Ej: nombre del método, verbo HTTP
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
    CONSTRAINT chk_pra_tipo_protocolo CHECK (
        tipo_protocolo IN ('WS_RPC','JSON_RPC','GRPC','UNIX_SOCKET','HTTP_EXT')
    ),
    CONSTRAINT chk_pra_eval_path CHECK (
        evaluation_path IN ('FAST','POLICY','EXTERNAL','PRECONDITION')
    ),
    CONSTRAINT chk_pra_tenant_scope CHECK (
        tenant_scope IN ('GLOBAL','TENANT_SPECIFIC')
    ),
    CONSTRAINT chk_pra_status CHECK (status IN ('ACTIVE','INACTIVE','DEPRECATED')),
    -- G-06: unicidad per-tenant — el mismo recurso+operación puede existir en dos tenants
    CONSTRAINT uq_pra_tenant_resource UNIQUE (tenant_id, tipo_protocolo, recurso, operacion)
);

CREATE INDEX IF NOT EXISTS idx_pra_tenant   ON bauth.privilege_resource_atom(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_pra_atom     ON bauth.privilege_resource_atom(id_atom);
CREATE INDEX IF NOT EXISTS idx_pra_domain   ON bauth.privilege_resource_atom(domain_code, evaluation_path);

COMMENT ON TABLE bauth.privilege_resource_atom IS
  '[XACML 3.0 PAP] [NIST SP 800-207 §3.3] [G-04] [G-06] [A.65.02 T-171 §8]
   Tabla PAP (Policy Administration Point) para Kong PEP.
   Permite a Kong resolver (tipo_protocolo + recurso + operacion) → id_atom sin consultar bAuth.
   Kong carga esta tabla al arrancar; recarga via CAEP catalog_change sobre Unix socket.
   domain_code D01-D12 → FastPath (< 0.5ns). D13-D37 → PolicyPath (consulta bAuth PDP).
   obligation NOT NULL → Kong verifica required_loa contra sesión en Redis ANTES de PERMIT.
   Sin mapeo en esta tabla = DENY por defecto (NIST SP 800-207: sin política explícita = denegado).';

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
    assignee_id  UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE CASCADE,
    -- Admin que autorizó — trazabilidad de quién tomó la decisión
    assigned_by  UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id),
    -- Justificación obligatoria: sin motivo no hay asignación válida
    reason       TEXT        NOT NULL,
    -- Período informativo: la vigencia real está en los átomos del rol en T-170
    valid_from   TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until  TIMESTAMPTZ NOT NULL,
    status       TEXT        NOT NULL DEFAULT 'ACTIVE',
    ctx_id       TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_pd_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
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
  '[G-08] [A.65.02.01 §6.5] [NIST SP 800-53 AC-2] [ISO 27001 A.8.2]
   Registro de auditoría de asignaciones de rol temporal (delegaciones D10 runtime).
   SOLO AUDITORÍA: no modificar para agregar validaciones.
   Las validaciones viven en T-170 (privilege_atom_grant) y en merge_roles Rust.
   La vigencia real está en los átomos del rol en T-170 — aquí es solo referencial.
   Flujo atómico: INSERT privilege_delegation + INSERT privilege_atom_grant en una sola TX.';


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
    user_id        UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE CASCADE,
    -- DENY_TO_PERMIT: acceso excepcional temporal | PERMIT_TO_DENY: bloqueo temporal (ej: incidente)
    override_type  TEXT        NOT NULL,
    -- Aprobador con autoridad registrada (quórum mínimo = 1)
    approver_id    UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id),
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
    CONSTRAINT chk_po_override_type CHECK (override_type IN ('DENY_TO_PERMIT','PERMIT_TO_DENY'))
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
  '[A.65.02.01 §6.6] [ISO 27001 A.8.2] [NIST SP 800-53 AC-5]
   Excepciones de acceso aprobadas con quórum y acotadas en tiempo.
   DENY_TO_PERMIT: el usuario tenía DENY (o sin grant), se le concede acceso excepcional.
   PERMIT_TO_DENY: el usuario tenía PERMIT, se le bloquea temporalmente (ej: incidente de seguridad).
   FK compuesta (id_atom, atom_position) DEFERRABLE garantiza referencia a átomo real.
   Un solo override activo del mismo tipo por combinación (tenant, átomo, usuario).
   Jobs de expiración actualizan status a EXPIRED cuando valid_until < now().';


-- ======================================================================
-- T-176 — bauth.privilege_assurance_audit
-- Auditoría de evaluaciones de obligación LoA realizadas por Kong (PEP).
-- Esta tabla NO la escribe bAuth. Kong inserta una fila por cada request
-- cuyo recurso en T-171 tenga obligation IS NOT NULL.
-- [G-04] [RFC 9470] [NIST SP 800-63B-4] [A.65.02.01 §DDL-T-176]
-- ======================================================================
-- Separación de responsabilidades respecto a T-170b (privilege_atom_audit):
--   T-170b audita QUÉ SE OTORGÓ y cuándo cambió el grant (bAuth escribe).
--   T-176 audita CÓMO SE EJERCIÓ lo otorgado en runtime (Kong escribe).
-- Volumen: crece con cada request evaluado → candidata a particionamiento por fecha.
CREATE TABLE IF NOT EXISTS bauth.privilege_assurance_audit (
    id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- Grant que se está evaluando — correlación con T-170 y T-170b en forensia
    grant_id       UUID        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    -- Identificador del recurso protegido (ruta, endpoint, objeto)
    resource_id    TEXT        NOT NULL,
    -- LoA exigido por la obligación del recurso (T-171.obligation)
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
CREATE INDEX IF NOT EXISTS idx_paa_grant   ON bauth.privilege_assurance_audit (grant_id);
-- Índice por session_id: reconstruir timeline de step-up de una sesión
CREATE INDEX IF NOT EXISTS idx_paa_session ON bauth.privilege_assurance_audit (session_id);
-- Índice por fecha: soportar particionamiento y retención
CREATE INDEX IF NOT EXISTS idx_paa_created ON bauth.privilege_assurance_audit (created_at);

-- Kong solo inserta — no puede modificar ni borrar registros de auditoría
REVOKE UPDATE, DELETE ON bauth.privilege_assurance_audit FROM bauth_app_role;

COMMENT ON TABLE bauth.privilege_assurance_audit IS
  '[G-04] [RFC 9470] [NIST SP 800-63B-4] [A.65.02.01 §DDL-T-176]
   Auditoría de evaluaciones de obligación LoA realizada por Kong PEP.
   Crece con cada request — separada de T-170b que crece solo al cambiar un grant.
   La evaluación de LoA usa current_loa desde Redis (keyed por session_id), nunca desde el JWT.
   Candidata a particionamiento por fecha (PARTITION BY RANGE created_at) con retención propia.
   REVOKE UPDATE/DELETE: Kong solo puede insertar, nunca modificar el registro.';


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
    approved_by     UUID        NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id),
    approved_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Fecha de expiración obligatoria — no hay excepciones permanentes
    valid_until     TIMESTAMPTZ NOT NULL,
    -- Fecha de revisión intermedia (≤ valid_until)
    review_at       TIMESTAMPTZ NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    revoked_at      TIMESTAMPTZ NULL,
    revoked_by      UUID        NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT chk_per_type   CHECK (exception_type IN ('SOD_EXCEPTION','TIER_EXCEPTION','SCOPE_EXCEPTION','OTHER')),
    CONSTRAINT chk_per_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_per_dates  CHECK (valid_until > approved_at AND review_at <= valid_until),
    CONSTRAINT chk_per_reason CHECK (length(business_reason) >= 50)
);

-- Consulta principal del trigger SoD: excepciones activas por tenant
CREATE INDEX IF NOT EXISTS idx_per_tenant_active
    ON bauth.privilege_exception_record (tenant_id, valid_until)
    WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.privilege_exception_record IS
  '[A.65.02 T-179] [G-14] [ISO 27001 A.8.2] [NIST SP 800-53 AC-5]
   Gobernanza de excepciones a políticas: documenta el CONTEXTO de aprobación detrás de un
   override en T-173. Política violada, tipo, justificación (≥ 50 chars), aprobador,
   valid_until y review_at son obligatorios — ISO 27001 exige toda excepción documentada.
   El trigger SoD en T-170 consulta esta tabla antes de rechazar un INSERT por conflicto.
   Job diario marca EXPIRED y revoca el override asociado en T-173 cuando valid_until < now().';


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
    CONSTRAINT chk_ssl_reason CHECK (
        termination_reason IS NULL
        OR termination_reason IN ('LOGOUT','TIMEOUT','CAEP_REVOKE','ADMIN_REVOKE','EXPIRY')
    )
);

CREATE INDEX IF NOT EXISTS idx_ssl_user_tenant ON bauth.ses_session_log (user_id, tenant_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_ssl_active      ON bauth.ses_session_log (tenant_id, last_active_at)
    WHERE terminated_at IS NULL;

COMMENT ON TABLE bauth.ses_session_log IS
  '[NIST SP 800-63B-4 §7] [NIST SP 800-53 AU-12] [ISO 27001:2022 A.8.15] [PCI DSS 4.0 Req 10.2.1] [A.65.02 T-181] ✅ G-16
   Esqueleto persistente mínimo de sesión para forensia post-incidente y cumplimiento normativo.
   Redis es la fuente de sesión activa (sub-ms). Esta tabla responde preguntas de forensia
   que Redis no puede responder después de un reinicio o failover.
   loa_initial: LoA al inicio; loa_peak: LoA máximo alcanzado (step-up RFC 9470).
   termination_reason=CAEP_REVOKE: escrito por el daemon cuando CAEP receiver procesa session-revoked.';


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
    CONSTRAINT chk_scel_event_type CHECK (
        event_type IN (
            'session-revoked','token-claims-change','credential-change',
            'assurance-level-change','device-compliance-change','risk-level-change'
        )
    ),
    CONSTRAINT chk_scel_subject_type CHECK (
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
  '[RFC 8935] [RFC 9493] [NIST SP 800-53 AU-12] [ISO 27001:2022 A.8.15] [A.65.02 T-191] ✅ G-25
   Log WORM append-only de cada evento CAEP recibido por el receptor bAuth.
   grants_affected: UUIDs de T-170 (privilege_atom_grant) suspendidos/revocados por el evento.
   Conecta la señal de revocación con la acción concreta del PDP — imprescindible para forensia.
   idx_scel_pending alimenta el job de reintento para eventos RECEIVED/PROCESSING/FAILED.';


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
    CONSTRAINT chk_sss_status   CHECK (status IN ('ACTIVE','PAUSED','TERMINATED','ERROR'))
);

COMMENT ON TABLE bauth.ses_ssf_stream IS
  '[OpenID SSF 1.0 Final] [CAEP 1.0 §3] [A.65.02 T-192] ✅ G-26
   Configuración de streams SSF para transmisión de eventos CAEP a receivers externos.
   auth_vault_path: ruta en Vault del token de autenticación para ese receiver (nunca el valor).
   El daemon carga esta tabla al arrancar y recarga vía CAEP sobre Unix socket.
   Permite agregar un nuevo receiver (SIEM, Kong) sin recompilar ni reiniciar el daemon.';

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
  '[OpenID SSF 1.0 Final] [A.65.02 T-193] ✅ G-26
   Log WORM append-only de intentos de entrega por stream SSF. Una fila por intento.
   Permite al admin saber si un receiver está caído (delivery_status=FAILED, retry_count alto).
   idx_ssdl_failing alimenta el job de reintento con backoff exponencial.';




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
  '[NIST SP 800-53 AC-2(4)] [ISO 27001 A.5.18 / A.8.2] [PCI DSS 4.0 Req 7.2] [A.65.02 T-177] ✅ G-13
   Cabecera de campaña de certificación de accesos IGA.
   Define alcance (TENANT/USER/ROLE/ATOM), tipo (QUARTERLY/ANNUAL/OFFBOARDING/INCIDENT/SOD_REVIEW),
   ventana (started_at → due_date) y responsable.
   WORM: INSERT only; cierre → UPDATE status=COMPLETED.
   Job cron la crea trimestralmente para todos los tenants activos. Fuente que dispara revisiones en T-178.';


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
  '[NIST SP 800-53 AC-2(7)] [ISO 27001 A.5.18 / A.8.2] [PCI DSS 4.0 Req 7.2] [A.65.02 T-178] ✅ G-13
   Evidencia auditable de revisión IGA — una fila por (campaña, grant).
   decision=REVOKE escribe revocation_at y dispara UPDATE en T-170 status=REVOKED (trigger o daemon).
   Esta tabla es la que presenta el auditor ISO 27001 como prueba de revisión periódica de accesos (A.8.2).
   justification obligatoria cuando decision IN (REVOKE, ESCALATE).';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          NIVEL 10 — RIESGO / ITDR (bauth)                          ║
-- ║   Identity Threat Detection and Response                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- T-180 — bauth.risk_policy
-- Reglas de política de riesgo adaptativo por tenant.
-- El PDP consulta esta tabla al recibir un evento CAEP para decidir qué acción tomar.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.risk_policy (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    tier_id         TEXT        NULL,
    trigger_event   TEXT        NOT NULL,
    condition       JSONB       NOT NULL,
    action          TEXT        NOT NULL,
    required_loa    TEXT        NULL,
    priority        INTEGER     NOT NULL DEFAULT 100,
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_by      UUID        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT risk_policy_pkey PRIMARY KEY (id),
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
    ON bauth.risk_policy (tenant_id, trigger_event, priority)
    WHERE activo = true;

COMMENT ON TABLE bauth.risk_policy IS
  '[NIST SP 800-207 §3.3] [NIST SP 800-53 AC-25] [CAEP 1.0 §5] [A.65.02 T-180] ✅ G-15
   Reglas de política de riesgo adaptativo por tenant. Define QUÉ HACE el PDP al recibir un evento CAEP.
   condition JSONB: expresión evaluada contra el payload del evento ({risk_score: {gte: 70}}).
   priority: el PDP evalúa en orden ASC y aplica la primera regla que coincide (menor = mayor prioridad).
   Reemplaza reglas hardcodeadas en el daemon — editable en runtime sin recompilar.
   Seeds por defecto: REVOKE en score≥85, STEP_UP AAL2 en score≥70, SUSPEND en device incompliant.';


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
  '[NIST SP 800-53 AC-6(9)] [ISO 27001 A.5.18] [PCI DSS 4.0 Req 7.2.6] [A.65.02 T-182] ✅ G-17
   Solicitud de acceso temporal privilegiado (Zero Standing Privilege). Cabecera del workflow JIT.
   justification >= 50 chars obligatorio. requested_duration <= max_duration del tier.
   niveles_requeridos: cuántos niveles de aprobación secuencial exige el tier del acceso solicitado.
   Al completar todos los niveles en T-182b → daemon crea grant en T-170 con valid_from/valid_until.
   Job de expiración revisa cada 60s filas status=ACTIVE con valid_until < now().';


-- ======================================================================
-- T-182b — bauth.pam_jit_approval
-- Aprobación secuencial multi-nivel de solicitudes JIT.
-- Una fila por nivel de aprobación. Nivel N+1 se notifica solo cuando Nivel N aprueba.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_jit_approval (
    id              UUID        NOT NULL DEFAULT uuidv7(),
    request_id      UUID        NOT NULL REFERENCES bauth.pam_jit_request(id),
    nivel           INTEGER     NOT NULL,
    required_role   TEXT        NOT NULL,
    approver_id     UUID        NULL,
    decision        TEXT        NULL,
    notified_at     TIMESTAMPTZ NULL,
    decision_at     TIMESTAMPTZ NULL,
    notes           TEXT        NULL,
    ctx_id          TEXT        NOT NULL,
    CONSTRAINT pam_jit_approval_pkey    PRIMARY KEY (id),
    CONSTRAINT uq_pja_request_nivel     UNIQUE (request_id, nivel),
    CONSTRAINT chk_pja_decision CHECK (
        decision IS NULL OR decision IN ('APPROVED','REJECTED')
    ),
    CONSTRAINT chk_pja_nivel CHECK (nivel BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_pja_pending
    ON bauth.pam_jit_approval (request_id, nivel)
    WHERE decision IS NULL;
CREATE INDEX IF NOT EXISTS idx_pja_approver_pending
    ON bauth.pam_jit_approval (approver_id, notified_at)
    WHERE decision IS NULL AND notified_at IS NOT NULL;

COMMENT ON TABLE bauth.pam_jit_approval IS
  '[NIST SP 800-53 AC-6(9)] [ISO 27001 A.5.18] [A.65.02 T-182b] ✅ G-17
   Aprobación secuencial multi-nivel de solicitudes JIT. Una fila por nivel.
   Nivel N+1 se notifica (notified_at=now()) solo cuando Nivel N tiene decision=APPROVED.
   Cualquier nivel con decision=REJECTED → solicitud queda REJECTED; niveles superiores no son notificados.
   required_role: qué rol puede decidir en ese nivel (ej. GERENTE_IT para nivel 1, CISO para nivel 2).
   Permite 1, 2 o N aprobadores sin cambiar el DDL — solo se agrega una fila de nivel.';


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
    CONSTRAINT chk_pbga_auth_method CHECK (
        auth_method IN ('MTLS_X509','WEBAUTHN_ROAMING','WEBAUTHN_PLATFORM')
    ),
    CONSTRAINT chk_pbga_auth_loa CHECK (auth_loa IN (2,3)),
    CONSTRAINT chk_pbga_review_due CHECK (post_review_due_at > activated_at),
    CONSTRAINT chk_pbga_deactivation CHECK (
        (status IN ('DEACTIVATED','REVIEWED') AND deactivated_at IS NOT NULL)
        OR status IN ('PENDING_APPROVAL','ACTIVE')
    ),
    CONSTRAINT chk_pbga_dual_control CHECK (
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
  '[NIST SP 800-53 AC-2(4) / AC-5 / AC-6(9)] [ISO 27001 A.5.18] [SOX §302] [A.65.02 T-185] ✅ G-20
   Ciclo de vida de activaciones break-glass. Estados: PENDING_APPROVAL → ACTIVE → DEACTIVATED → REVIEWED.
   Dual control (chk_pbga_dual_control): status=ACTIVE solo alcanzable cuando un segundo SU aprueba.
   auth_method debe ser AAL3: MTLS_X509, WEBAUTHN_ROAMING, WEBAUTHN_PLATFORM.
   post_review_due_at = activated_at + 24h (NIST AC-2(4)). TTL de activación: 4h (job breakglass_expiry.rs).
   grant_id referencia grant con grant_type=BREAKGLASS en T-170 (invariante D1 de G-20).';


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
    CONSTRAINT chk_psr_status CHECK (
        status IN ('ACTIVE','ENDED','TERMINATED','ERROR')
    )
);

CREATE INDEX IF NOT EXISTS idx_psr_session ON bauth.pam_session_record (session_id);
CREATE INDEX IF NOT EXISTS idx_psr_user    ON bauth.pam_session_record (user_id, tenant_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_psr_active  ON bauth.pam_session_record (tenant_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_psr_jit     ON bauth.pam_session_record (jit_request_id)
    WHERE jit_request_id IS NOT NULL;

COMMENT ON TABLE bauth.pam_session_record IS
  '[NIST SP 800-53 AU-14] [ISO 27001 A.8.15] [PCI DSS 4.0 Req 10.2.1.3] [A.65.02 T-184] ✅ G-19
   Metadatos de sesión de acceso privilegiado — registra CÓMO se ejerció el privilegio otorgado.
   Separación: T-170b audita QUÉ se otorgó; esta tabla audita CÓMO se ejerció.
   duration_seconds: GENERATED ALWAYS — calculado automáticamente al escribirse ended_at.
   recording_ref: referencia al archivo de grabación en MinIO/S3 (valor = path, nunca el binario).
   jit_request_id → trazabilidad completa: evento → justificación → aprobación → sesión → comandos.';


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
    CONSTRAINT chk_pcref_type  CHECK (
        credential_type IN ('PASSWORD','SSH_KEY','API_KEY','CERT','TOKEN','OAUTH_CLIENT')
    ),
    CONSTRAINT chk_pcref_owner CHECK (owner_type IN ('HUMAN','NHI')),
    CONSTRAINT chk_pcref_rot   CHECK (
        rotation_policy IN ('MANUAL','AUTO_7D','AUTO_30D','AUTO_90D','AUTO_1Y')
    ),
    CONSTRAINT chk_pcref_status CHECK (
        status IN ('ACTIVE','ROTATING','REVOKED','EXPIRED')
    )
);

CREATE INDEX IF NOT EXISTS idx_pcref_rotation ON bauth.pam_credential_ref (next_rotation_at)
    WHERE status = 'ACTIVE' AND next_rotation_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pcref_owner ON bauth.pam_credential_ref (owner_id, owner_type);

COMMENT ON TABLE bauth.pam_credential_ref IS
  '[NIST SP 800-53 IA-5(1)] [CIS § Credential Management] [PCI DSS 4.0 Req 8.3] [A.65.02 T-183] ✅ G-18
   Inventario de credenciales privilegiadas. Solo metadatos y ruta en Vault (vault_path).
   El valor real vive en Vault; esta tabla es el panel de control de la rotación.
   owner_type=NHI conecta con T-186 idn_non_human_identity — los daemons también tienen credenciales.
   Job de rotación usa idx_pcref_rotation para ejecutar rotación en Vault cuando next_rotation_at <= now().
   NUNCA almacena el valor de la credencial.';


-- ======================================================================
-- T-189 — bauth.pam_nhi_secret_ref
-- Referencias a secretos de NHI en Vault — alta frecuencia de rotación (7-30 días).
-- NUNCA almacena el valor del secreto; solo la ruta en Vault.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pam_nhi_secret_ref (
    id                  UUID        NOT NULL DEFAULT uuidv7(),
    nhi_id              UUID        NOT NULL REFERENCES bauth.idn_non_human_identity(id),
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
    CONSTRAINT chk_pnsr_rotation CHECK (
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
  '[NIST SP 800-53 IA-5(1)] [CIS API Keys] [A.65.02 T-189] ✅ G-23
   Referencias a secretos de NHI en Vault. Alta frecuencia de rotación (7-30 días vs 90 días de T-183).
   rotation_policy=ON_USE: rota en cada uso — patrón recomendado para pipelines CI/CD.
   Al descomisionar un NHI todos sus secretos pasan a status=REVOKED automáticamente.
   NUNCA almacena el valor del secreto: solo la ruta (vault_path) y metadatos de rotación.';


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
  '[A.65.02 T-060] Contextos de menú que definen el tipo de menú y su posición en la UI.
   code: sidebar, toolbar, contextual, quick-actions, breadcrumb.
   Un ítem de menú se vincula a contextos vía la tabla menu_context (T-060).';


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
  '[A.65.02 T-061] Puente entre ítems de menú (B7 CAPA 2) y el motor BitMask.
   atom_code: código del átomo en el árbol de políticas T-162 (ej. "D1.admin.usuarios.listar").
   El PEP del dashboard verifica que el usuario tenga PERMIT en atom_code antes de renderizar el ítem.
   required_effect=PERMIT: el ítem aparece si el átomo tiene efecto PERMIT en el BitmaskBundle del usuario.';


-- ======================================================================
-- ÍNDICES COMPLEMENTARIOS — Relaciones clave entre schemas
-- ======================================================================
-- Índice para lookup de grants activos por átomo (id_atom = columna canónica)
CREATE INDEX IF NOT EXISTS idx_pag_id_atom
    ON bauth.privilege_atom_grant(id_atom)
    WHERE status = 'ACTIVE';

-- Índice de búsqueda rápida de nodos evaluación activos por posición de bit
CREATE INDEX IF NOT EXISTS idx_irt_eval_active
    ON bauth.idn_roles_template(atom_position, verb_id)
    WHERE tipo = 'evaluacion' AND activo = true;


-- ======================================================================
-- FIN DDL — SBOS_db_V2_DDL.sql
-- ======================================================================
-- Resumen de tablas creadas (alineado con A.65.02_ANEXO-NUEVA-DDL v1.3):
--
--   bglobal (T-001..T-004 · T-059..T-061 · T-114):
--               global_language, global_country, global_currency, geo_timezone,
--               menu_item, menu_context, menu_item_atom, global_config (8)
--
--   bauth TENANT (T-005..T-013):
--               idn_tenant, idn_tenant_currencies, idn_tenant_languages,
--               idn_tenant_verification, idn_tenant_config, idn_tenant_domain,
--               idn_tenant_network, idn_calendar_assignment (8)
--
--   bauth VERSIONADO (T-152..T-155) [STUBS — solo comentarios, sin CREATE TABLE]:
--               idn_rol_hierarchical_ver_history, idn_roles_rol_ver_proposal,
--               idn_roles_rol_ver_retention_schedule, idn_roles_template_ver_changelog (0 tablas activas)
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
--   bauth IDENTIDAD (T-156..T-157 · T-158..T-161 stubs · T-186..T-188 · T-190):
--               idn_identidad_entidad, idn_identidad_atributo,
--               idn_non_human_identity, idn_nhi_lifecycle_event,
--               idn_nhi_certification, idn_agent_identity (6)
--               [T-158..T-161: stubs sin CREATE TABLE — diseño pendiente]
--
--   bauth SESIÓN (T-181 · T-191..T-193):
--               ses_session_log, ses_caep_event_log,
--               ses_ssf_stream, ses_ssf_delivery_log (4)
--
--   bauth AUDITORÍA IGA (T-177..T-178):
--               aud_certification_campaign, aud_certification_review (2)
--
--   bauth RIESGO (T-180):
--               risk_policy (1)
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
-- TOTAL: 59 tablas base + 3 particiones de privilege_atom_audit = 62 CREATE TABLE activos
-- Stubs (sin CREATE TABLE): T-152..T-155, T-158..T-161 (8 stubs como comentarios)
-- Total en plan A.65.02: 67 = 59 activos + 8 stubs ✅
-- Secuencias: bauth.roles_atom_position_sequential (1)
-- Triggers:   bauth.trg_irt_atom_position → fn_irt_assign_atom_position() (1)
-- Seeds:      idn_roles_rol_type (10 tipos) · idn_roles_rol_tier (11 tiers)
-- ======================================================================
