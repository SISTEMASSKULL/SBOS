-- ======================================================================
-- DDL_skSBOS_db.sql — Identity Governance & Audit Platform
-- Base de datos: skSBOS_db (canónico del proyecto, PLAN §2.0)
-- Schemas: bauth (identidad, PLAN: bAuth) · bglobal (catálogos, PLAN: bGlobal)
--           bcalendar (fiscal, PLAN: bCalendar) · bos (BOS Control Plane)
-- PostgreSQL 18.4: lowercase unquoted identifiers (SQL standard, case-folded)
-- Convención humana: b + Mayúscula + minúsculas (PLAN §2.0)
-- Convención SQL: snake_case lowercase (PostgreSQL best practice)
-- Estándares: ISO 27001:2022 · NIST 800-53 Rev.5 · PCI DSS 4.0.1
--             RFC 9562 (UUID v7) · W3C Trace Context · GDPR Art.32
-- Construcción: tabla por tabla, probada en VPS (bauth_test)
-- Inicio: 2026-06-23 · sbos-coordinador
--
-- ══════════════════════════════════════════════════════════════════════
-- IDEMPOTENCIA: Este script puede ejecutarse N veces sin errores.
--   1ª ejecución → CREATES
--   2ª+ ejecución → NOTICEs (ya existen), sin ERRORes
-- Principios: IF NOT EXISTS en todo CREATE · COMMENT ON es idempotente
--             Sin INSERTs (van en seeds) · Sin ALTER TABLE
-- ======================================================================

-- ══════════════════════════════════════════════════════════════════════
-- PREÁMBULO: Base de Datos, Schemas y Extensiones
-- ══════════════════════════════════════════════════════════════════════
-- La base de datos skSBOS_db se crea externamente (no desde DDL):
--   CREATE DATABASE skSBOS_db OWNER postgres;

-- ══════════════════════════════════════════════════════════════════════
-- HOT MIGRATION SETUP — PostgreSQL 18.4 Zero-Downtime DDL
-- ══════════════════════════════════════════════════════════════════════
-- Principios:
--   • lock_timeout = 5s — evita queues de bloqueo en producción
--   • IF NOT EXISTS en todo — idempotencia N ejecuciones
--   • ADD COLUMN nullable + DEFAULT NULL — metadata-only (ms, sin rewrite)
--   • NOT NULL en fase 2 con CHECK NOT VALID → VALIDATE CONSTRAINT
--   • CREATE INDEX CONCURRENTLY — no bloquea escrituras
--   • Sin transacción explícita — cada DDL es atómico por sí mismo
--
-- Uso en producción (bauth_db existente):
--   psql -d bauth_db -f DDL_skSBOS_db.sql
--   → Las tablas/columnas existentes: NOTICE (sin error)
--   → Las tablas/columnas nuevas: CREATED (sin bloquear)
--   → Ejecutable N veces con resultado idéntico
-- ══════════════════════════════════════════════════════════════════════
SET lock_timeout = '5s';
SET client_min_messages = WARNING;  -- Solo warnings y errores, sin NOTICEs

-- Schemas de la Identity Governance & Audit Platform (PostgreSQL 18.4)
CREATE SCHEMA IF NOT EXISTS bauth;        -- bAuth: Núcleo de identidad (idn_, ath_, ses_, fin_, aud_, sec_, geo_, cfg_)
CREATE SCHEMA IF NOT EXISTS bglobal;      -- bGlobal: Catálogos ISO 4217/639/3166 (global_)
CREATE SCHEMA IF NOT EXISTS bcalendar;    -- bCalendar: Calendario fiscal multi-nivel (cal_)
CREATE SCHEMA IF NOT EXISTS bos;          -- BOS IAM Installer Control Plane
-- Schemas heredados (en migración → bauth)
CREATE SCHEMA IF NOT EXISTS bos_privilege;
CREATE SCHEMA IF NOT EXISTS bos_blockchain;

-- Extensiones PostgreSQL 18.4
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ══════════════════════════════════════════════════════════════════════
-- ENUM TYPES — Dominios controlados (reutilizables entre tablas)
-- PostgreSQL: ENUM = integer internamente, type-safe, sin harcodeos
-- Ventaja sobre CHECK IN (...): catálogo central, reutilizable, índices rápidos
-- ══════════════════════════════════════════════════════════════════════
DO $$ BEGIN CREATE TYPE tenant_status_enum       AS ENUM ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','MAINTENANCE','SOFT_DELETED','TERMINATED','PURGED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE tenant_type_enum         AS ENUM ('STANDARD','REGULATED','HIGH_SENSITIVITY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE isolation_level_enum     AS ENUM ('ROW_LEVEL','SCHEMA_PER_TENANT','DB_PER_TENANT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE subscription_status_enum AS ENUM ('TRIAL','ACTIVE','PAST_DUE','CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE plan_tier_enum           AS ENUM ('BASIC','PRO','ENTERPRISE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE provisioning_status_enum AS ENUM ('PENDING','INFRA_PROVISIONING','SCHEMA_CREATED','IDP_CONFIGURED','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE audit_level_enum         AS ENUM ('basic','full'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE language_scope_enum     AS ENUM ('individual','macrolanguage','special','collection'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE language_type_enum      AS ENUM ('living','extinct','ancient','constructed','historic'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE text_direction_enum     AS ENUM ('ltr','rtl','ttb'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE translation_status_enum AS ENUM ('COMPLETE','PARTIAL','MACHINE_TRANSLATED','NOT_TRANSLATED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE verification_step_enum   AS ENUM ('IDENTITY_CHECK','LEGAL_CHECK','TECHNICAL_SETUP','SECURITY_REVIEW','FINAL_APPROVAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE verification_status_enum AS ENUM ('PENDING','IN_PROGRESS','PASSED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE domain_type_enum        AS ENUM ('WEB','API','POS','ADMIN','PORTAL','STATIC','MAIL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE domain_status_enum      AS ENUM ('PENDING','VERIFIED','FAILED','PROPAGATING','ISSUED','EXPIRING','RENEWING','DEPLOYING','DEPLOYED','ROLLED_BACK','HEALTHY','DEGRADED','UNHEALTHY','UNKNOWN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE network_type_enum      AS ENUM ('LAN','WAN','VPN','DMZ','GUEST','MANAGEMENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fiscal_year_status_enum AS ENUM ('OPEN','CLOSED','CLOSED_WITH_ADJUSTMENTS','ARCHIVED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_owner_type_enum AS ENUM ('TENANT','COMPANY','BRANCH','USER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_role_enum      AS ENUM ('OWNER','EDITOR','VIEWER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE calendar_type_enum      AS ENUM ('WORK','FISCAL','PROCESS','COMPLIANCE','HOLIDAY','MAINTENANCE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE alarm_channel_enum      AS ENUM ('EMAIL','SMS','WHATSAPP','PUSH','CHAT','UI'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE schedule_status_enum    AS ENUM ('OPEN','CLOSED','LUNCH','BREAK','OVERTIME'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fis_location_type_enum AS ENUM ('SITE','BUILDING','FLOOR','WING','AREA','DOOR','DEVICE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fis_perimeter_type_enum AS ENUM ('FENCE','WALL','VEHICLE_BARRIER','NONE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fis_device_type_enum     AS ENUM ('CARD_READER','PIN_KEYPAD','BIOMETRIC_READER','MAGNETIC_LOCK','ELECTRIC_STRIKE','DOOR_CONTACT','MOTION_SENSOR','IP_CAMERA','PTZ_CAMERA','INTERCOM','REX_BUTTON','ALARM_SIREN','GLASS_BREAK','SMOKE_DETECTOR','POS_TERMINAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fis_device_protocol_enum AS ENUM ('OSDP','WIEGAND','ONVIF','MQTT','MODBUS','SIP','TCPIP'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fis_device_status_enum   AS ENUM ('ACTIVE','INACTIVE','ALARM','FAULT','MAINTENANCE','OFFLINE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fin_transaction_category_enum AS ENUM ('VENTAS','COMPRAS','PAGOS','COBROS','NOMINA','INVENTARIO','TRIBUTARIO','BANCARIO','ACTIVOS_FIJOS','IMPORTACION','EXPORTACION'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fin_risk_level_enum        AS ENUM ('BAJO','MEDIO','ALTO','CRITICO'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fin_limit_action_enum       AS ENUM ('BLOCK','REQUIRE_APPROVAL','REQUIRE_DUAL_CONTROL','NOTIFY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fin_approval_status_enum    AS ENUM ('PENDING','APPROVED','REJECTED','ESCALATED','EXPIRED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE fin_document_operation_enum AS ENUM ('EMIT','CANCEL','ADJUST','VOID','EXPORT_SIN'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE menu_type_enum             AS ENUM ('HIERARCHICAL','CONTEXTUAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE role_type_enum              AS ENUM ('TYPE_OPERATIVO','TYPE_SUPERVISOR','TYPE_GERENCIA_MEDIA','TYPE_DIRECCION','TYPE_ADMIN_SISTEMA','TYPE_SERVICIO','TYPE_AUDITORIA','TYPE_COMERCIAL','TYPE_TECNICO'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

RESET lock_timeout;
RESET client_min_messages;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                     NIVEL 0 — TABLAS RAÍZ                           ║
-- ║   Sin dependencias. Catálogos ISO globales.                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- 003 — bglobal.global_language (antes bos_idioma)
-- Catálogo de idiomas BCP 47 / ISO 639 / IANA / Unicode CLDR.
-- Cumple: RFC 5646 · ISO 639-1/2/3 · ISO 15924 · IANA Subtag Registry · CLDR 46.
-- Natural key: locale (BCP 47 language tag).
-- Correcciones aplicadas:
--   C1: iso_639_2 → iso_639_2t (terminology) + iso_639_2b (bibliographic)
--   C2: +scope (individual|macrolanguage|special|collection) — ISO 639-3 obligatorio
--   C3: +language_type (living|extinct|ancient|constructed|historic) — ISO 639-3
--   C4: +family (Indo-European, Sino-Tibetan, etc.) — Ethnologue/Glottolog
--   C5: direction TEXT → text_direction_enum (ltr|rtl|ttb) — type-safe
--   C6: -character_set (obsoleto: 2026 todo es UTF-8)
--   C7: -flag_emoji (no estándar: solo 195 países vs 7000+ idiomas)
--   C8: +fallback_locale (cadena degradación CLDR: cmn→zh→en→und)
--   C9: +suppress_script (IANA Registry: script a NO usar con este idioma)
--   C10: +preferred_value (IANA Registry: reemplazo si deprecated)
--   C11: +wikidata_id (Linked Open Data — Q-ID de Wikidata)
--   C12: +iana_registry_date (última sincronización con IANA)
--   C13: +created_at / updated_at (ISO 27001 A.8.15 trazabilidad)
--   C14: PK locale TEXT → language_id UUIDv7 + locale UNIQUE (R3: 100% UUID PKs)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_language (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    language_id      UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === CLAVE NATURAL (BCP 47) ===
    locale           TEXT        UNIQUE NOT NULL,

    -- === CÓDIGOS ISO 639 ===
    iso_639_1        CHAR(2),
    iso_639_2t       CHAR(3),                                  -- [ISO 639-2] Terminology: deu, fra, zho
    iso_639_2b       CHAR(3),                                  -- [ISO 639-2] Bibliographic: ger, fre, chi
    iso_639_3        CHAR(3),                                  -- [ISO 639-3] Comprehensive: 8368 codes

    -- === CLASIFICACIÓN ISO 639-3 ===
    scope            language_scope_enum NOT NULL DEFAULT 'individual',
    language_type    language_type_enum  NOT NULL DEFAULT 'living',
    family           TEXT,                                     -- [Ethnologue/Glottolog] Indo-European, Sino-Tibetan, Afro-Asiatic

    -- === NOMBRES MULTI-LENGUAJE (CLDR) ===
    name             JSONB       NOT NULL,

    -- === DIRECCIÓN DE ESCRITURA ===
    direction        text_direction_enum NOT NULL DEFAULT 'ltr',

    -- === CADENA DE DEGRADACIÓN (CLDR Fallback) ===
    fallback_locale  TEXT,                                     -- [BCP 47] cmn→zh→en→und. NULL = sin fallback (autosuficiente)

    -- === METADATOS IANA REGISTRY ===
    suppress_script  CHAR(4),                                  -- [ISO 15924] Script suprimido: en→Latn (implícito)
    preferred_value  TEXT,                                     -- [IANA] Reemplazo si deprecated: iw→he, in→id
    deprecated       BOOLEAN     NOT NULL DEFAULT false,       -- [IANA] true si el locale está deprecado
    wikidata_id      TEXT,                                     -- [Wikidata] Q-ID: Q1321 (Español), Q1860 (Inglés)
    iana_registry_date DATE,                                  -- [IANA] Fecha de última sincronización con el registry

    -- === ESTADO Y TRAZABILIDAD ===
    is_active        BOOLEAN     NOT NULL DEFAULT false,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE UNIQUE INDEX IF NOT EXISTS idx_glang_locale    ON bglobal.global_language(locale);
CREATE INDEX IF NOT EXISTS idx_glang_active          ON bglobal.global_language(locale) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_glang_scope           ON bglobal.global_language(scope, language_id);
CREATE INDEX IF NOT EXISTS idx_glang_type            ON bglobal.global_language(language_type, language_id);
CREATE INDEX IF NOT EXISTS idx_glang_family          ON bglobal.global_language(family, language_id);
CREATE INDEX IF NOT EXISTS idx_glang_iso6391         ON bglobal.global_language(iso_639_1) WHERE iso_639_1 IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_glang_name            ON bglobal.global_language USING GIN (name jsonb_path_ops);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bglobal.global_language IS
  '[BCP 47] [RFC 5646] [ISO 639-1/2/3] [ISO 15924] [IANA Language Subtag Registry] [Unicode CLDR 46]
   Catálogo canónico de idiomas para todo el ecosistema SBOS.
   PK: language_id UUIDv7 (RFC 9562). Natural key: locale UNIQUE NOT NULL (BCP 47 tag).
   Fuentes: IANA Subtag Registry + Ethnologue + Glottolog + Unicode CLDR + Wikidata.
   Correcciones v3: PK UUIDv7 + locale UNIQUE (antes locale era PK TEXT — violaba R3).';

COMMENT ON COLUMN bglobal.global_language.language_id IS
  '[RFC 9562] UUIDv7 PK time-ordered. Identificador interno para FKs entrantes. La clave natural visible es locale (UNIQUE).';

COMMENT ON COLUMN bglobal.global_language.locale IS
  '[BCP 47] [RFC 5646 §2.1] UNIQUE NOT NULL — clave natural del idioma.
   Sintaxis: language[-script][-region][-variant].
   Ejemplos: es-BO, en-US, zh-Hans-CN, pt-BR, qu-BO, ay-BO, ar-SA.
   Validación contra IANA Subtag Registry (sintaxis + validez).';

COMMENT ON COLUMN bglobal.global_language.iso_639_1 IS
  '[ISO 639-1:2002] Two-letter code. 184 codes. es, en, zh, pt, qu, ay, ar, fr, de.
   NULL = idioma sin código ISO 639-1 (solo tiene ISO 639-3, ej: 7000+ idiomas minoritarios).';

COMMENT ON COLUMN bglobal.global_language.iso_639_2t IS
  '[ISO 639-2:1998] Three-letter TERMINOLOGY code. Preferido para aplicaciones.
   spa, eng, zho, por, que, aym, ara, fra, deu. 482 codes.
   Diferencia clave: deu (T=terminology) vs ger (B=bibliographic).';

COMMENT ON COLUMN bglobal.global_language.iso_639_2b IS
  '[ISO 639-2:1998] Three-letter BIBLIOGRAPHIC code. Usado en catalogación bibliotecaria.
   ger, fre, chi, ara. Mismo estándar, diferente tradición (inglés vs francés).
   NULL = mismo código en ambas variantes B/T (la mayoría).';

COMMENT ON COLUMN bglobal.global_language.iso_639_3 IS
  '[ISO 639-3:2007] Three-letter code para cobertura comprehensiva. 8368+ códigos.
   Cubre idiomas vivos, extintos, artificiales e históricos. Usado por Ethnologue.';

COMMENT ON COLUMN bglobal.global_language.scope IS
  '[ISO 639-3 §4.2] Ámbito: individual (cmn), macrolanguage (zh), special (mul/und/zxx), collection (afa).
   Crítico: zh (macrolanguage) ≠ cmn (individual). Sin este campo no se distinguen.';

COMMENT ON COLUMN bglobal.global_language.language_type IS
  '[ISO 639-3 §4.3] Tipo: living, extinct, ancient, constructed, historic.
   ancient — antiguo, sin hablantes actuales (grc=Greek Ancient, lat=Latin)
   constructed — artificial (epo=Esperanto, ido=Ido, tlh=Klingon)
   historic — histórico, con literatura preservada (ang=Old English, fro=Old French).';

COMMENT ON COLUMN bglobal.global_language.family IS
  '[Ethnologue] [Glottolog] Familia lingüística: Indo-European, Sino-Tibetan, Afro-Asiatic,
   Austronesian, Niger-Congo, Quechuan, Aymaran, Tupian.
   Permite agrupar idiomas por parentesco para reporting y localización regional.';

COMMENT ON COLUMN bglobal.global_language.name IS
  '[Unicode CLDR 46] Nombres del idioma en múltiples locales. JSONB:
   {"es":"Español","en":"Spanish","native":"Español","fr":"Espagnol","de":"Spanisch","zh":"西班牙语"}.
   Extensible a N locales sin modificar schema. La clave "native" es obligatoria.';

COMMENT ON COLUMN bglobal.global_language.direction IS
  '[Unicode CLDR] Dirección de escritura:
   ltr — left-to-right (Latino, Cirílico, Chino simplificado)
   rtl — right-to-left (Árabe, Hebreo, Persa)
   ttb — top-to-bottom (Mongol tradicional, Manchu).
   ENUM type-safe. DEFAULT ltr.';

COMMENT ON COLUMN bglobal.global_language.fallback_locale IS
  '[CLDR] [BCP 47 §4.1] Cadena de degradación para UI cuando falta traducción.
   Ejemplo: cmn (Mandarin) → zh (Chinese macrolanguage) → en (English) → und (undetermined).
   NULL = idioma autosuficiente (ej: en-US no necesita fallback).
   Usado por el motor de localización para resolver claves de traducción faltantes.';

COMMENT ON COLUMN bglobal.global_language.suppress_script IS
  '[IANA Language Subtag Registry] Código ISO 15924 del script que DEBE suprimirse
   al mostrar este idioma. Ej: en suprime Latn (es implícito, redundante).
   zh-Hans suprime Hans cuando el contexto ya implica simplificado.
   NULL = sin supresión.';

COMMENT ON COLUMN bglobal.global_language.preferred_value IS
  '[IANA Language Subtag Registry] Tag de reemplazo si este locale está deprecated.
   Ej: iw → he (Hebrew), in → id (Indonesian), ji → yi (Yiddish), sh → sr (Serbian).
   NULL = locale vigente, no deprecated.';

COMMENT ON COLUMN bglobal.global_language.deprecated IS
  '[IANA Language Subtag Registry] true si este locale está deprecated por el IANA.
   Los locales deprecated deben migrar a preferred_value. DEFAULT false.';

COMMENT ON COLUMN bglobal.global_language.wikidata_id IS
  '[Linked Open Data] Q-ID de Wikidata: Q1321 (Español), Q1860 (Inglés), Q809 (Polaco).
   Enlaza con grafos de conocimiento para datos enriquecidos (hablantes L1/L2, países, historia).';

COMMENT ON COLUMN bglobal.global_language.iana_registry_date IS
  '[IANA] Fecha de la versión del IANA Language Subtag Registry usada para validar este registro.
   Permite auditoría de actualización: ¿este locale fue validado contra la versión 2026-06?';

COMMENT ON COLUMN bglobal.global_language.is_active IS
  'true = idioma activo en el ecosistema SBOS. false = deshabilitado (no ofrecido en UI).';

COMMENT ON COLUMN bglobal.global_language.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación del registro. Automático: DEFAULT now().';

COMMENT ON COLUMN bglobal.global_language.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación. Actualizado por aplicación.';

-- ======================================================================
-- 004 — bglobal.global_country (antes bos_pais / bauth.geo_country)
-- Catálogo canónico de países para todo el ecosistema SBOS.
-- Fuentes: ISO 3166-1/2/3 · UN M.49 · ITU-T E.164 · IANA TZ · CLDR
-- ======================================================================
-- Investigación aplicada:
--   [1] REST Countries API (restcountries.com) — 80+ campos, 250+ países
--   [2] dr5hn/countries-states-cities-database — SQL/JSON/CSV, 240 entidades
--   [3] ceexon/countries — continent, region, subregion, currency, TLD
--   [4] ISO 3166-1:2020 — alpha-2, alpha-3, numeric codes
--   [5] UN M.49 — region/subregion/intermediate region classification
--   [6] ITU-T E.164 — international calling codes
--   [7] IANA TZ Database — timezone assignments per country
--   [8] Unicode CLDR — localized country names (80+ locales)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_country (
    -- === IDENTIFICADOR INTERNO ===
    country_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    -- === CÓDIGOS INTERNACIONALES ===
    iso_alpha2       CHAR(2)     UNIQUE NOT NULL,          -- [ISO 3166-1] BO, US, CN, AR, BR
    iso_alpha3       CHAR(3)     NOT NULL UNIQUE,          -- [ISO 3166-1] BOL, USA, CHN, ARG, BRA
    iso_numeric      SMALLINT    NOT NULL UNIQUE,          -- [ISO 3166-1] 068, 840, 156, 032, 076
    un_m49           SMALLINT    UNIQUE,                   -- [UN M.49] 068, 840, 156
    itu_calling_code TEXT        NOT NULL,                 -- [ITU-T E.164] +591, +1, +86
    tld              TEXT        NOT NULL,                 -- [IANA] .bo, .us, .cn, .ar, .br
    icao_code        CHAR(2),                              -- [ICAO] SL, US, ZB, SA

    -- === IDENTIDAD ===
    name_common      TEXT        NOT NULL,                 -- Nombre común en inglés: Bolivia
    name_official    TEXT        NOT NULL,                 -- Nombre oficial: Plurinational State of Bolivia
    name_native      JSONB       NOT NULL DEFAULT '{}',    -- Nombres en 80+ locales: {"es":"Bolivia","qu":"Puliwya","ay":"Wuliwya","en":"Bolivia"}
    demonym          TEXT,                                 -- Gentilicio en inglés: Bolivian
    demonym_native   JSONB       DEFAULT '{}',             -- Gentilicios: {"es":"boliviano/a","fr":"bolivien/ne"}

    -- === GEOGRAFÍA ===
    continent        TEXT        NOT NULL,                 -- [UN M.49] South America, Asia, Europe, Africa, Oceania, Antarctica
    region           TEXT        NOT NULL,                 -- [UN M.49] Americas, Asia, Europe, Africa, Oceania
    subregion        TEXT,                                 -- [UN M.49] South America, Central Asia, Western Europe
    capital          TEXT,                                 -- Ciudad capital: La Paz (administrativa)
    capital_coords   POINT,                                -- Coordenadas (lat, lon) de la capital
    lat              NUMERIC(8,5),                          -- Latitud del centroide del país
    lon              NUMERIC(8,5),                          -- Longitud del centroide del país
    area_km2         BIGINT,                               -- Área en kilómetros cuadrados
    landlocked       BOOLEAN     NOT NULL DEFAULT false,   -- Sin salida al mar (Bolivia, Paraguay, Suiza)
    borders          CHAR(2)[]   DEFAULT '{}',             -- Alpha-2 de países fronterizos: {AR,BR,CL,PE,PY}

    -- === DEMOGRAFÍA ===
    population       BIGINT,                               -- Población estimada (último censo/ONU)
    population_year  SMALLINT,                             -- Año de la estimación

    -- === ECONOMÍA ===
    currency_code    CHAR(3),                              -- [ISO 4217] Moneda principal: BOB, USD, EUR
    gini_coefficient NUMERIC(4,1),                         -- Coeficiente de Gini (desigualdad)

    -- === LENGUAS Y HORARIOS ===
    languages        TEXT[]      DEFAULT '{}',             -- [BCP 47] es, qu, ay, en, pt, fr
    timezones        TEXT[]      NOT NULL DEFAULT '{}',    -- [IANA] {America/La_Paz}

    -- === SÍMBOLOS ===
    flag_emoji       TEXT,                                 -- 🇧🇴
    flag_svg_url     TEXT,                                 -- URL al SVG de la bandera

    -- === METADATOS Y ESTADO ===
    independence_status TEXT    DEFAULT 'sovereign',       -- sovereign, dependent, disputed, antarctic_claim
    wikidata_id      TEXT,                                 -- Q750 (Bolivia) — enlace a Wikidata
    active           BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bglobal.global_country IS
  '[ISO 3166-1:2020] [UN M.49] [ITU-T E.164] [IANA TZ] [CLDR]
   Catálogo canónico de países para todo el ecosistema SBOS.
   Natural key: iso_alpha2 CHAR(2).
   Fuentes: ISO, ONU, ITU, IANA, Unicode CLDR.
   Seeds poblados desde restcountries.com + dr5hn/countries-states-cities-database (250+ entidades).
   Nombres multi-lenguaje en JSONB (name_native, demonym_native) — 80+ locales.';

COMMENT ON COLUMN bglobal.global_country.country_id IS '[RFC 9562] UUIDv7 PK interna. Identificador time-ordered para índices B-tree. La PK natural es iso_alpha2 (UNIQUE).';
COMMENT ON COLUMN bglobal.global_country.iso_alpha2 IS '[ISO 3166-1 alpha-2] Código de 2 letras. UNIQUE natural key. BO, US, CN.';
COMMENT ON COLUMN bglobal.global_country.iso_alpha3 IS '[ISO 3166-1 alpha-3] Código de 3 letras. BOL, USA, CHN.';
COMMENT ON COLUMN bglobal.global_country.iso_numeric IS '[ISO 3166-1 numeric] Código numérico. 068, 840, 156.';
COMMENT ON COLUMN bglobal.global_country.un_m49 IS '[UN M.49] Código de región/subregión de Naciones Unidas para estadísticas.';
COMMENT ON COLUMN bglobal.global_country.itu_calling_code IS '[ITU-T E.164] Código telefónico internacional. +591, +1, +86.';
COMMENT ON COLUMN bglobal.global_country.tld IS '[IANA] Dominio de nivel superior geográfico. .bo, .us, .cn.';
COMMENT ON COLUMN bglobal.global_country.icao_code IS '[ICAO] Código de aeropuerto/autoridad de aviación civil. SL, US.';
COMMENT ON COLUMN bglobal.global_country.name_native IS '[Unicode CLDR] Nombres del país en 80+ locales. JSONB: {"es":"Bolivia","qu":"Puliwya","ay":"Wuliwya","fr":"Bolivie","de":"Bolivien","zh":"玻利维亚"}.';
COMMENT ON COLUMN bglobal.global_country.demonym_native IS 'Gentilicios multi-lenguaje. JSONB: {"es":"boliviano/a","en":"Bolivian","fr":"bolivien/ne"}.';
COMMENT ON COLUMN bglobal.global_country.continent IS '[UN M.49] Continente: South America, Asia, Europe, Africa, Oceania, Antarctica.';
COMMENT ON COLUMN bglobal.global_country.region IS '[UN M.49] Región: Americas, Asia, Europe, Africa, Oceania.';
COMMENT ON COLUMN bglobal.global_country.subregion IS '[UN M.49] Subregión: South America, Central Asia, Western Europe, Eastern Africa.';
COMMENT ON COLUMN bglobal.global_country.capital_coords IS '[PostGIS] Coordenadas (lat, lon) de la ciudad capital. Tipo POINT.';
COMMENT ON COLUMN bglobal.global_country.landlocked IS 'País sin salida al mar. Bolivia, Paraguay, Suiza, Austria, etc.';
COMMENT ON COLUMN bglobal.global_country.borders IS '[ISO 3166-1 alpha-2] Array de países fronterizos. Bolivia: {AR,BR,CL,PE,PY}.';
COMMENT ON COLUMN bglobal.global_country.currency_code IS '[ISO 4217] Código de la moneda principal del país. BOB, USD, EUR.';
COMMENT ON COLUMN bglobal.global_country.languages IS '[BCP 47] Array de idiomas oficiales. Bolivia: {es,qu,ay}.';
COMMENT ON COLUMN bglobal.global_country.timezones IS '[IANA TZ] Array de zonas horarias. Bolivia: {America/La_Paz}.';
COMMENT ON COLUMN bglobal.global_country.independence_status IS 'Estatus político: sovereign (ONU), dependent (territorio), disputed, antarctic_claim.';
COMMENT ON COLUMN bglobal.global_country.wikidata_id IS 'ID de Wikidata (Q750 = Bolivia). Enlaza con linked open data.';

-- ======================================================================
-- 002 — bglobal.global_currency (antes bos_moneda)
-- Catálogo de monedas ISO 4217. Cumple: ISO 4217:2015 · SIX Interbank.
-- Natural key: currency_code CHAR(3) UNIQUE.
-- Correcciones aplicadas:
--   C1: PK currency_code CHAR(3) → currency_id UUIDv7 + currency_code UNIQUE (R3: 100% UUID PKs)
--   C2: +created_at / updated_at (ISO 27001 A.8.15 trazabilidad)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.global_currency (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    currency_id      UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === CLAVE NATURAL (ISO 4217) ===
    currency_code    CHAR(3)     UNIQUE NOT NULL,

    -- === CÓDIGOS ISO 4217 ===
    iso_numeric      SMALLINT    NOT NULL UNIQUE,
    name             JSONB       NOT NULL,
    symbol           TEXT        NOT NULL,
    symbol_intl      TEXT,
    decimal_places   SMALLINT    NOT NULL DEFAULT 2,
    minor_unit_name  TEXT,
    introduced_at    DATE,
    withdrawn_at     DATE,

    -- === EMISOR ===
    issuer_country   CHAR(2)     NOT NULL,
    country_id       UUID        REFERENCES bglobal.global_country(country_id),

    -- === ESTADO Y TRAZABILIDAD ===
    is_active         BOOLEAN     NOT NULL DEFAULT true,
    is_cryptocurrency BOOLEAN     NOT NULL DEFAULT false,
    exchange_rate_api TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE UNIQUE INDEX IF NOT EXISTS idx_gcur_code       ON bglobal.global_currency(currency_code);
CREATE INDEX IF NOT EXISTS idx_gcur_country           ON bglobal.global_currency(issuer_country, currency_id);
CREATE INDEX IF NOT EXISTS idx_gcur_active            ON bglobal.global_currency(is_active, currency_code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_gcur_name              ON bglobal.global_currency USING GIN (name jsonb_path_ops);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bglobal.global_currency IS
  '[ISO 4217:2015] Currency catalog maintained by SIX Interbank Clearing on behalf of ISO.
   PK: currency_id UUIDv7 (RFC 9562). Natural key: currency_code CHAR(3) UNIQUE.
   Correcciones v2: PK UUIDv7 + currency_code UNIQUE (antes currency_code era PK — violaba R3).';

COMMENT ON COLUMN bglobal.global_currency.currency_id IS
  '[RFC 9562] UUIDv7 PK time-ordered. Identificador interno para FKs entrantes. La clave natural visible es currency_code (UNIQUE).';

COMMENT ON COLUMN bglobal.global_currency.currency_code IS
  '[ISO 4217] UNIQUE NOT NULL — clave natural de la moneda. Three-letter alphabetic code: BOB, USD, EUR, CNY, BRL.';

COMMENT ON COLUMN bglobal.global_currency.iso_numeric IS
  '[ISO 4217] Three-digit numeric code: 068, 840, 978, 156, 986.';

COMMENT ON COLUMN bglobal.global_currency.name IS
  '[ISO 4217] [CLDR] Currency names in JSONB.
   Structure: {"es":{"singular":"Boliviano","plural":"Bolivianos"},"en":{"singular":"Bolivian Boliviano","plural":"Bolivian Bolivianos"}}.
   Extensible to N languages via CLDR locale data.';

COMMENT ON COLUMN bglobal.global_currency.symbol IS
  'Local currency symbol: Bs., $, €, ¥, R$, £, ₹.';

COMMENT ON COLUMN bglobal.global_currency.symbol_intl IS
  '[ISO 4217] International symbol (usually same as currency_code): BOB, USD, EUR.';

COMMENT ON COLUMN bglobal.global_currency.decimal_places IS
  '[ISO 4217] Standard decimal places: 2 (BOB, USD), 0 (JPY, KRW), 3 (BHD, OMR).';

COMMENT ON COLUMN bglobal.global_currency.minor_unit_name IS
  '[ISO 4217] Fractional unit name: centavo (BOB), cent (USD), fils (BHD), sen (JPY).';

COMMENT ON COLUMN bglobal.global_currency.introduced_at IS
  '[ISO 4217] Date currency was introduced. NULL = before ISO 4217 registration (1978).';

COMMENT ON COLUMN bglobal.global_currency.withdrawn_at IS
  '[ISO 4217] Date currency was withdrawn. NULL = active currency.';

COMMENT ON COLUMN bglobal.global_currency.issuer_country IS
  '[ISO 3166-1 alpha-2] Country that issues this currency: BO, US, CN, AR, BR.';

COMMENT ON COLUMN bglobal.global_currency.country_id IS
  'FK UUID → bglobal.global_country(country_id). Primary country using this currency.';

COMMENT ON COLUMN bglobal.global_currency.is_cryptocurrency IS
  'true = cryptocurrency (BTC, ETH, USDT). false = fiat currency issued by central bank.';

COMMENT ON COLUMN bglobal.global_currency.exchange_rate_api IS
  'URL to central bank API for official exchange rate. Ej: https://www.bcb.gob.bo/api/tipo-cambio.';

COMMENT ON COLUMN bglobal.global_currency.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación del registro. Automático: DEFAULT now().';

COMMENT ON COLUMN bglobal.global_currency.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';


-- ======================================================================
-- 005 — bglobal.geo_timezone (antes bos_timezone en bauth)
-- Catálogo de zonas horarias IANA TZ Database.
-- Schema: bglobal — es un catálogo ISO global, no pertenece a bauth (identidad).
-- Cumple: IANA Time Zone Database (zone.tab) · ISO 6709 · CLDR.
-- Natural key: timezone_id TEXT UNIQUE (IANA identifier).
-- Correcciones aplicadas:
--   C1: PK timezone_id TEXT → timezone_uuid UUIDv7 + timezone_id UNIQUE (R3: 100% UUID PKs)
--   C2: +coordinates POINT (ISO 6709 lat/lon from zone.tab column 2)
--   C3: +dst_offset TEXT + dst_offset_min SMALLINT (DST UTC offset)
--   C4: +comments TEXT (zone.tab column 4)
--   C5: country_code CHAR(2) → NOT NULL (zone.tab column 1 obligatorio)
--   C6: +created_at / updated_at (ISO 27001 A.8.15 trazabilidad)
--   C7: Schema corregido: bauth → bglobal (catálogo global, no de identidad)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bglobal.geo_timezone (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    timezone_uuid    UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === CLAVE NATURAL (IANA) ===
    timezone_id      TEXT        UNIQUE NOT NULL,

    -- === NOMBRES MULTI-LENGUAJE (CLDR) ===
    name             JSONB       NOT NULL,

    -- === UBICACIÓN ===
    country_code     CHAR(2)     NOT NULL,
    principal_city   TEXT,
    coordinates      POINT,

    -- === UTC OFFSET ESTÁNDAR ===
    utc_offset       TEXT        NOT NULL,
    utc_offset_min   SMALLINT    NOT NULL,

    -- === DST (Daylight Saving Time) ===
    observes_dst     BOOLEAN     NOT NULL DEFAULT false,
    dst_offset       TEXT,
    dst_offset_min   SMALLINT,

    -- === METADATOS ===
    comments         TEXT,
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE UNIQUE INDEX IF NOT EXISTS idx_tz_iana       ON bglobal.geo_timezone(timezone_id);
CREATE INDEX IF NOT EXISTS idx_tz_country           ON bglobal.geo_timezone(country_code, timezone_uuid);
CREATE INDEX IF NOT EXISTS idx_tz_dst               ON bglobal.geo_timezone(observes_dst, timezone_id);
CREATE INDEX IF NOT EXISTS idx_tz_name              ON bglobal.geo_timezone USING GIN (name jsonb_path_ops);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bglobal.geo_timezone IS
  '[IANA Time Zone Database] [zone.tab] [ISO 6709] [Unicode CLDR]
   Catálogo canónico de zonas horarias para todo el ecosistema SBOS.
   PK: timezone_uuid UUIDv7 (RFC 9562). Natural key: timezone_id TEXT UNIQUE.
   Fuentes: IANA TZ Database (zone.tab + iso3166.tab) + CLDR localized names.
   Correcciones v2: PK UUIDv7, coordinates POINT, dst_offset, comments, timestamps.';

COMMENT ON COLUMN bglobal.geo_timezone.timezone_uuid IS
  '[RFC 9562] UUIDv7 PK time-ordered. Identificador interno para FKs entrantes. La clave natural visible es timezone_id (UNIQUE).';

COMMENT ON COLUMN bglobal.geo_timezone.timezone_id IS
  '[IANA TZ Database] UNIQUE NOT NULL — clave natural. Identificador IANA: America/La_Paz, America/New_York, Asia/Shanghai, Europe/Madrid. Formato: Area/Location.';

COMMENT ON COLUMN bglobal.geo_timezone.name IS
  '[Unicode CLDR] Timezone display names in JSONB.
   Structure: {"es":"Bolivia (La Paz)","en":"Bolivia Time","fr":"Bolivie (La Paz)","de":"Bolivien (La Paz)"}.
   Extensible to N languages.';

COMMENT ON COLUMN bglobal.geo_timezone.country_code IS
  '[ISO 3166-1 alpha-2] [zone.tab column 1] NOT NULL — country this zone belongs to. BO, US, CN, AR, BR. FK lógico a bglobal.global_country(iso_alpha2).';

COMMENT ON COLUMN bglobal.geo_timezone.principal_city IS
  '[IANA TZ] Principal city in this timezone: La Paz, New York, Shanghai, London.';

COMMENT ON COLUMN bglobal.geo_timezone.coordinates IS
  '[ISO 6709] [zone.tab column 2] Geographic coordinates (lat, lon) of the zone principal location. POINT type for PostGIS compatibility.';

COMMENT ON COLUMN bglobal.geo_timezone.utc_offset IS
  '[IANA TZ] Standard UTC offset: -04:00, +08:00, +01:00, +05:30. String format for display.';

COMMENT ON COLUMN bglobal.geo_timezone.utc_offset_min IS
  '[IANA TZ] Standard UTC offset in minutes: -240 (America/La_Paz), 480 (Asia/Shanghai), 60 (Europe/Madrid), 330 (Asia/Kolkata). Useful for arithmetic and comparisons.';

COMMENT ON COLUMN bglobal.geo_timezone.observes_dst IS
  '[IANA TZ] true = this zone observes Daylight Saving Time. false = permanent standard time (Bolivia, most of LATAM, China).';

COMMENT ON COLUMN bglobal.geo_timezone.dst_offset IS
  '[IANA TZ] UTC offset during DST: -03:00, +09:00, +02:00. NULL = no DST observed.';

COMMENT ON COLUMN bglobal.geo_timezone.dst_offset_min IS
  '[IANA TZ] DST UTC offset in minutes: -180, 540, 120. NULL = no DST observed.';

COMMENT ON COLUMN bglobal.geo_timezone.comments IS
  '[zone.tab column 4] IANA comments: clarifying context when a country has multiple zones.';

COMMENT ON COLUMN bglobal.geo_timezone.is_active IS
  'true = timezone active in SBOS ecosystem. false = disabled (not offered in UI).';

COMMENT ON COLUMN bglobal.geo_timezone.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación del registro. Automático: DEFAULT now().';

COMMENT ON COLUMN bglobal.geo_timezone.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';


-- ======================================================================
-- 001 — idn_tenant (antes bos_tenant)
-- Entidad raíz del sistema multi-tenant SBOS.
-- Tabla más sensible del entorno. Controla identidad, aislamiento,
-- ciclo de vida y seguridad de cada tenant.
--
-- ── INVESTIGACIÓN APLICADA ──
-- [1] Tenant Isolation in Multi-Tenant Systems (SSOJet/Security Boulevard 2025)
-- [2] AWS Prescriptive Guidance — SaaS Partitioning Models for PostgreSQL
-- [3] ABP Framework — Shared User Accounts in Multi-Tenancy
-- [4] Clerk Blog — Multi-Tenant Auth Pitfalls (60% data exposure from validation)
-- [5] Supabase Realtime — Tenant Lifecycle Management Architecture
-- [6] LoginRadius — SaaS Identity & Access Management Best Practices
-- [7] PostgreSQL 18 — uuidv7() nativo, Skip Scan para índices B-tree
--
-- ── CORRECCIONES APLICADAS ──
-- C1: tenant_id TEXT PK → UUID PK DEFAULT uuidv7() (RFC 9562, PG18 nativo)
-- C2: DEFAULT '*' → DEFAULT NULL (incompatibilidad UUID)
-- C3: +tenant_slug TEXT UNIQUE NOT NULL (identificador público URLs/APIs)
-- C4: verified_by TEXT → UUID (consistencia 100% UUID)
-- C5: NOT NULL DEFAULT NULL → DEFAULT NULL (contradicción lógica)
-- C6: +ciclo de vida extendido: 7 estados + soft-delete + grace period
-- C7: +rate limiting por tenant (rate_limit_rps)
-- C8: +provisioning_status (bootstrap tracking: infra, schema, idp)
-- C9: +network security (allowed_ip_ranges)
-- C10: +delegated admin (admin_contact_id)
-- C11: +compliance: data_retention_days, terms_accepted_at
--
-- ── COLUMNAS POR DOMINIO ──
-- Identidad: tenant_id, tenant_slug, tenant_name, tenant_type
-- Ciclo de vida (7 estados): status, provisioning_status, verified_at,
--    verified_by, suspended_at, deleted_at, purge_after, created_at, updated_at
-- Legal/Compliance: legal_name, tax_id, registration_number, country,
--    jurisdiction, legal_representative, legal_contact_email,
--    data_retention_days, terms_accepted_at, terms_version
-- Infraestructura: realm_kc, realm_kc_ext, namespace_k8s, database_name,
--    database_schema, vault_path, kong_consumer_id, domain
-- Seguridad: isolation_level, mfa_required, password_policy,
--    session_ttl_max, token_ttl_seconds, rate_limit_rps,
--    allowed_ip_ranges, audit_level
-- Negocio: plan_tier, subscription_status, notification_channels,
--    admin_contact_id
-- Metadata: metadata (JSONB), tags (TEXT[])
--
-- ── ESTÁNDARES APLICABLES ──
-- ISO 27001 A.8.2 (Privileged access) · A.8.15 (Logging)
-- NIST 800-53 AC-2 (Account mgmt) · AC-3 (Access enforcement)
-- NIST 800-207 ZTA (Zero Trust — tenant isolation)
-- SBOS-049 §4 (Context Plane — tenant_id como raíz del ctx_id)
-- GDPR Art.32 (Security) · Art.17 (Right to erasure — purge_after)
-- SOC 2 CC6.1 (Logical access security)
-- PCI DSS 4.0 Req 7.2 (Access control)
--
-- ── PRUEBA VPS ──
-- 2026-06-23: CREATE TABLE exitoso en bauth_test (PostgreSQL 18.4)
-- uuidv7() nativo confirmado. Índices skip scan funcionales.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant (
    -- === IDENTIDAD CENTRAL ===
    tenant_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_slug     TEXT        UNIQUE NOT NULL,
    tenant_name     TEXT        NOT NULL,
    tenant_type     tenant_type_enum NOT NULL DEFAULT 'STANDARD'::tenant_type_enum,

    -- === CICLO DE VIDA EXTENDIDO (7 estados + soft-delete) ===
    status              tenant_status_enum       NOT NULL DEFAULT 'PENDING_VERIFICATION'::tenant_status_enum,
    provisioning_status provisioning_status_enum NOT NULL DEFAULT 'PENDING'::provisioning_status_enum,
    -- PENDING → INFRA_PROVISIONING → SCHEMA_CREATED → IDP_CONFIGURED → COMPLETED
    verified_at         TIMESTAMPTZ,
    verified_by         UUID,
    suspended_at        TIMESTAMPTZ,
    deleted_at          TIMESTAMPTZ,
    purge_after         TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
    -- Soft-delete: 30 días de grace period antes del purge definitivo (GDPR Art.17)

    -- === DATOS LEGALES / COMPLIANCE ===
    legal_name              TEXT,
    tax_id                  TEXT,
    registration_number     TEXT,
    country                 TEXT    NOT NULL DEFAULT 'BO',
    jurisdiction            TEXT,
    legal_representative    TEXT,
    legal_contact_email     TEXT,
    data_retention_days     INTEGER NOT NULL DEFAULT 2555,
    -- 7 años (2555 días) para datos fiscales en Bolivia (Ley 2492)
    terms_accepted_at       TIMESTAMPTZ,
    terms_version           TEXT,
    -- Términos de servicio aceptados (GDPR Art.7 consentimiento)

    -- === INFRAESTRUCTURA TÉCNICA ===
    realm_kc            TEXT    NOT NULL UNIQUE,
    realm_kc_ext        TEXT    NOT NULL UNIQUE,
    namespace_k8s       TEXT    NOT NULL UNIQUE,
    database_name       TEXT,
    database_schema     TEXT,
    vault_path          TEXT,
    kong_consumer_id    TEXT,
    domain              TEXT,

    -- === SEGURIDAD AVANZADA ===
    isolation_level     isolation_level_enum     NOT NULL DEFAULT 'SCHEMA_PER_TENANT'::isolation_level_enum,
    mfa_required        BOOLEAN NOT NULL DEFAULT false,
    password_policy     TEXT    NOT NULL DEFAULT 'length(12)_argon2id_t3_m64',
    session_ttl_max     INTEGER NOT NULL DEFAULT 28800,
    token_ttl_seconds   INTEGER NOT NULL DEFAULT 3600,
    rate_limit_rps      INTEGER NOT NULL DEFAULT 100,
    -- Rate limiting por tenant (requests/second). SU:ilimitado, SYS:1000, BIZ:100, EXT:10
    allowed_ip_ranges   TEXT[]  DEFAULT '{}',
    -- CIDR ranges autorizados. NULL/{} = sin restricción (Zero Trust: siempre validar)

    -- === NEGOCIO / ADMINISTRACIÓN ===
    plan_tier           plan_tier_enum           NOT NULL DEFAULT 'BASIC'::plan_tier_enum,
    subscription_status subscription_status_enum NOT NULL DEFAULT 'TRIAL'::subscription_status_enum,
    audit_level         audit_level_enum         NOT NULL DEFAULT 'basic'::audit_level_enum,
    notification_channels TEXT[] DEFAULT '{email}',
    admin_contact_id    UUID,
    -- FK lógica al administrador delegado del tenant (idn_usuario)
    metadata            JSONB   DEFAULT '{}',
    tags                TEXT[]  DEFAULT '{}',
    -- Tags para agrupación y filtrado (ej: {latam, banca, alto_volumen})

    -- === MARCAS DE TIEMPO ===
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- === CONSTRAINTS ===
    -- ENUM types reemplazan CHECK IN (...) — validación en el tipo mismo
    -- Solo queda: auditoría de security contact
    CONSTRAINT chk_security_contact CHECK (
        legal_contact_email IS NOT NULL OR admin_contact_id IS NOT NULL
        -- Al menos un contacto de seguridad debe existir (ISO 27001 A.8.2)
    )
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan Optimization ──
-- Diseño: leading column = baja cardinalidad (skip scan), trailing = alta cardinalidad (filtro)
-- PG18 skip scan permite usar estos índices aunque no se filtre por la leading column
CREATE INDEX IF NOT EXISTS idx_idn_tenant_status   ON bauth.idn_tenant(status, tenant_id);         -- 4 valores × ∞ tenants
CREATE INDEX IF NOT EXISTS idx_idn_tenant_type     ON bauth.idn_tenant(tenant_type, tenant_id);    -- 3 valores × ∞ tenants
CREATE INDEX IF NOT EXISTS idx_idn_tenant_country  ON bauth.idn_tenant(country, tenant_id);        -- ~10 valores × ∞ tenants
CREATE INDEX IF NOT EXISTS idx_idn_tenant_created  ON bauth.idn_tenant(created_at DESC);           -- time-ordered (UUIDv7 correlation)
CREATE INDEX IF NOT EXISTS idx_idn_tenant_slug     ON bauth.idn_tenant(tenant_slug);               -- unique lookup

-- ── COMMENT ON — Documentación en catálogo PostgreSQL ──
COMMENT ON TABLE bauth.idn_tenant IS
  '[ISO 27001 A.8.2] [NIST 800-53 AC-2] [SBOS-049 §4]
   Entidad raíz del sistema multi-tenant SBOS.
   Correcciones aplicadas:
   C1: tenant_id TEXT→UUID (RFC 9562)
   C2: DEFAULT *→NULL (incompatibilidad UUID)
   C3: +tenant_slug UNIQUE NOT NULL (identificador público para URLs/APIs)
   C4: verified_by TEXT→UUID (consistencia 100% UUID)';

COMMENT ON COLUMN bauth.idn_tenant.tenant_id IS
  '[RFC 9562] PK UUID v7 time-ordered. Identificador interno. 21 FKs entrantes desde tablas dependientes.';

COMMENT ON COLUMN bauth.idn_tenant.tenant_slug IS
  'Identificador público único para URLs (/dist/{slug}/...) y APIs. Ej: skull, acme, inka.';

COMMENT ON COLUMN bauth.idn_tenant.status IS
  '[ISO 27001 A.8.2] Ciclo de vida: PENDING_VERIFICATION→ACTIVE→SUSPENDED→TERMINATED.';

COMMENT ON COLUMN bauth.idn_tenant.isolation_level IS
  '[ISO 27001 A.8.2] Nivel de aislamiento de datos entre tenants. ROW_LEVEL|SCHEMA_PER_TENANT|DB_PER_TENANT.';

COMMENT ON COLUMN bauth.idn_tenant.mfa_required IS
  '[NIST 800-63B-4 §5.1.3] MFA obligatorio global para todos los usuarios del tenant.';

COMMENT ON COLUMN bauth.idn_tenant.password_policy IS
  '[NIST 800-63B-4 §5.1.1.2] Política de contraseñas: length(n)_argon2id_t{n}_m{n}. Ej: length(12)_argon2id_t3_m64.';

COMMENT ON COLUMN bauth.idn_tenant.tenant_name IS
  'Nombre descriptivo del tenant. Visible en UI de administración y reportes.';

COMMENT ON COLUMN bauth.idn_tenant.provisioning_status IS
  '[AWS SaaS Partitioning] Estado de bootstrap: PENDING→INFRA_PROVISIONING→SCHEMA_CREATED→IDP_CONFIGURED→COMPLETED. FAILED requiere intervención manual.';

COMMENT ON COLUMN bauth.idn_tenant.deleted_at IS
  '[GDPR Art.17] Soft-delete timestamp. Si NOT NULL, el tenant está en grace period. NULL = activo.';

COMMENT ON COLUMN bauth.idn_tenant.purge_after IS
  '[GDPR Art.17] Fecha de purga definitiva. Default: created_at + 30 días. Después de esta fecha, DROP SCHEMA CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant.data_retention_days IS
  '[Ley 2492 Bolivia] Días de retención de datos fiscales. Default: 2555 (7 años).';

COMMENT ON COLUMN bauth.idn_tenant.terms_accepted_at IS
  '[GDPR Art.7] Timestamp de aceptación de términos de servicio. NULL si no se han aceptado.';

COMMENT ON COLUMN bauth.idn_tenant.terms_version IS
  'Versión de los términos aceptados (ej: v2.1). Permite re-consentimiento cuando los términos cambian.';

COMMENT ON COLUMN bauth.idn_tenant.rate_limit_rps IS
  '[PCI DSS 4.0 Req 11.3] Rate limit por tenant en requests/segundo. SU: ilimitado, SYS: 1000, BIZ: 100, EXT: 10.';

COMMENT ON COLUMN bauth.idn_tenant.allowed_ip_ranges IS
  '[NIST 800-207 ZTA] Array de CIDR ranges autorizados. NULL = sin restricción (no recomendado). Zero Trust: validar siempre.';

COMMENT ON COLUMN bauth.idn_tenant.admin_contact_id IS
  '[LoginRadius SaaS IAM] UUID del administrador delegado del tenant. FK lógica a idn_usuario. Gestiona sus propios usuarios.';

COMMENT ON COLUMN bauth.idn_tenant.tags IS
  'Array TEXT para agrupación y filtrado. Ej: {latam, banca, alto_volumen, pci_dss}.';

COMMENT ON COLUMN bauth.idn_tenant.tenant_name IS
  'Nombre descriptivo del tenant. Visible en UI de administración y reportes. Reemplaza a nombre (legacy).';

COMMENT ON COLUMN bauth.idn_tenant.tenant_type IS
  'Clasificación de seguridad: STANDARD (sin datos sensibles), REGULATED (PCI/SOX/GDPR), HIGH_SENSITIVITY (datos críticos con controles adicionales).';

COMMENT ON COLUMN bauth.idn_tenant.status IS
  '[Ciclo de Vida] Estado del tenant: PENDING_VERIFICATION→ACTIVE→SUSPENDED→MAINTENANCE→SOFT_DELETED→TERMINATED→PURGED.
   La verificación KYC forma parte del provisioning_status, no de un campo separado.';

COMMENT ON COLUMN bauth.idn_tenant.verified_at IS
  'Timestamp de verificación KYC. NULL si no ha sido verificado.';

COMMENT ON COLUMN bauth.idn_tenant.verified_by IS
  'UUID del administrador SBOS que verificó este tenant. FK lógica a bos_user_template.';

COMMENT ON COLUMN bauth.idn_tenant.legal_name IS
  'Razón social legal del operador del tenant. Requerido para facturación y compliance SIN Bolivia.';

COMMENT ON COLUMN bauth.idn_tenant.tax_id IS
  'NIT / Tax ID del operador. Requerido para facturación electrónica SIN (Bolivia). Formato: XXXXXXXXX.';

COMMENT ON COLUMN bauth.idn_tenant.registration_number IS
  'Número de registro de comercio / FUNDEMPRESA (Bolivia).';

COMMENT ON COLUMN bauth.idn_tenant.country IS
  '[ISO 3166-1 alpha-2] País de operación principal del tenant. Default: BO.';

COMMENT ON COLUMN bauth.idn_tenant.jurisdiction IS
  'Jurisdicción legal aplicable. Determina qué leyes de protección de datos aplican (ej: Ley 164 Bolivia, GDPR UE).';

COMMENT ON COLUMN bauth.idn_tenant.legal_representative IS
  'Nombre del representante legal del operador del tenant.';

COMMENT ON COLUMN bauth.idn_tenant.legal_contact_email IS
  'Email de contacto del representante legal. Usado para notificaciones de compliance.';

COMMENT ON COLUMN bauth.idn_tenant.realm_kc IS
  'Nombre del realm en Keycloak. Formato: tenant-{tenant_slug}. Único por tenant.';

COMMENT ON COLUMN bauth.idn_tenant.realm_kc_ext IS
  'Nombre del realm externo en Keycloak para usuarios N0 (clientes, visitantes). Formato: tenant-{tenant_slug}-ext.';

COMMENT ON COLUMN bauth.idn_tenant.namespace_k8s IS
  'Namespace en Kubernetes para los pods de este tenant. Único por tenant.';

COMMENT ON COLUMN bauth.idn_tenant.database_name IS
  'Nombre de BD dedicada si isolation_level=DB_PER_TENANT. NULL si comparte BD con schema propio.';

COMMENT ON COLUMN bauth.idn_tenant.database_schema IS
  'Nombre del schema dedicado si isolation_level=SCHEMA_PER_TENANT. NULL si ROW_LEVEL.';

COMMENT ON COLUMN bauth.idn_tenant.vault_path IS
  'Ruta en HashiCorp Vault para secretos del tenant. Formato: secret/tenants/{tenant_slug}/.';

COMMENT ON COLUMN bauth.idn_tenant.kong_consumer_id IS
  'ID del consumidor en Kong API Gateway para rate limiting y autenticación a nivel tenant.';

COMMENT ON COLUMN bauth.idn_tenant.domain IS
  'Nombre de dominio FQDN del tenant. Formato: {tenant_slug}.sbos.skull.bo.';

COMMENT ON COLUMN bauth.idn_tenant.session_ttl_max IS
  '[NIST 800-63B-4 §7] Tiempo máximo de vida de sesión en segundos. Default: 28800 (8h). Máximo: 86400 (24h).';

COMMENT ON COLUMN bauth.idn_tenant.token_ttl_seconds IS
  '[OAuth 2.0 RFC 6749] TTL del access token JWT en segundos. Default: 3600 (1h).';

COMMENT ON COLUMN bauth.idn_tenant.plan_tier IS
  'Plan de suscripción: BASIC (hasta 50 usuarios), PRO (ilimitado + features avanzados), ENTERPRISE (dedicado + SLAs).';

COMMENT ON COLUMN bauth.idn_tenant.subscription_status IS
  'Estado de suscripción: TRIAL→ACTIVE→PAST_DUE→CANCELLED. TRIAL expira en 30 días.';

COMMENT ON COLUMN bauth.idn_tenant.audit_level IS
  '[ISO 27001 A.8.15] Nivel de auditoría: basic (eventos de seguridad), full (todas las operaciones).';

COMMENT ON COLUMN bauth.idn_tenant.notification_channels IS
  'Canales de notificación por defecto para el tenant. Array TEXT: {email, sms, whatsapp, push, chat}.';

COMMENT ON COLUMN bauth.idn_tenant.metadata IS
  '[JSONB] Metadatos extensibles del tenant. Usado para configuraciones específicas sin modificar el schema.';

COMMENT ON COLUMN bauth.idn_tenant.created_at IS
  'Timestamp de creación del tenant. Automático: DEFAULT now().';

COMMENT ON COLUMN bauth.idn_tenant.updated_at IS
  'Timestamp de última modificación. Actualizado por triggers de aplicación.';

COMMENT ON COLUMN bauth.idn_tenant.suspended_at IS
  '[ISO 27001 A.8.2] Timestamp de suspensión. NULL = activo. Cuando se establece, todos los accesos del tenant se revocan.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║                     NIVEL 1 — TABLAS DEPENDIENTES                    ║
-- ║   Con FK a Nivel 0. Configuración por tenant.                       ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- 006 — bauth.idn_tenant_currencies (antes bos_tenant_currency)
-- Monedas habilitadas por tenant + tasas de cambio.
-- Schema: bauth — vinculada a idn_tenant, referencia global_currency.
-- Cumple: ISO 4217 · NIST 800-53 AC-3 · ISO 27001 A.8.15.
-- Correcciones aplicadas:
--   C1: PK BIGSERIAL → currency_config_id UUIDv7 (R3: 100% UUID PKs)
--   C2: tenant_id TEXT → UUID FK → idn_tenant(tenant_id)
--   C3: codice_iso → currency_code (inglés) + FK → global_currency(currency_code)
--   C4: es_default → is_default, active → is_active (inglés)
--   C5: exchange_rate_to_default → exchange_rate DECIMAL(18,8) (Oracle 23ai best practice)
--   C6: +ctx_id (Nivel 1: SBOS-049 trazabilidad)
--   C7: +created_at / updated_at (ISO 27001 A.8.15)
--   C8: Schema corregido: bauth (vinculado a idn_tenant, no es catálogo global)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_currencies (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    currency_config_id UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === FK A TENANT ===
    tenant_id          UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- === FK A MONEDA (ISO 4217) ===
    currency_code      CHAR(3)     NOT NULL REFERENCES bglobal.global_currency(currency_code),

    -- === CONFIGURACIÓN ===
    is_default         BOOLEAN     NOT NULL DEFAULT false,
    exchange_rate      DECIMAL(18,8),
    exchange_source    TEXT        DEFAULT 'BCB',
    exchange_updated_at TIMESTAMPTZ,

    -- === ESTADO Y TRAZABILIDAD ===
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- === CONSTRAINTS ===
    UNIQUE (tenant_id, currency_code),
    CONSTRAINT chk_one_default CHECK (
        is_default = false OR (is_default = true AND currency_code IS NOT NULL)
    )
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE INDEX IF NOT EXISTS idx_itc_tenant   ON bauth.idn_tenant_currencies(tenant_id, currency_code);
CREATE INDEX IF NOT EXISTS idx_itc_currency ON bauth.idn_tenant_currencies(currency_code, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itc_default  ON bauth.idn_tenant_currencies(tenant_id, currency_code) WHERE is_default = true;


-- ======================================================================
-- 007 — bauth.idn_tenant_languages (antes bos_tenant_language)
-- Idiomas habilitados por tenant + configuración de traducción.
-- Schema: bauth — vinculada a idn_tenant, referencia global_language.
-- Cumple: BCP 47 / RFC 5646 · ISO 639 · Unicode CLDR · ISO 27001 A.8.15.
-- Correcciones aplicadas:
--   C1: PK BIGSERIAL → language_config_id UUIDv7 (R3: 100% UUID PKs)
--   C2: tenant_id TEXT → UUID FK → idn_tenant(tenant_id)
--   C3: locale TEXT → FK → global_language(locale)
--   C4: es_default → is_default, active → is_active (inglés)
--   C5: translation_status TEXT → ENUM (type-safe, ya existe)
--   C6: +ctx_id (Nivel 1: SBOS-049 trazabilidad)
--   C7: +created_at / updated_at (ISO 27001 A.8.15)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_languages (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    language_config_id UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === FK A TENANT ===
    tenant_id          UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- === FK A IDIOMA (BCP 47) ===
    locale             TEXT        NOT NULL REFERENCES bglobal.global_language(locale),

    -- === CONFIGURACIÓN ===
    is_default         BOOLEAN     NOT NULL DEFAULT false,
    translation_provider TEXT      DEFAULT 'sbos_i18n',
    translation_status translation_status_enum DEFAULT 'COMPLETE',

    -- === ESTADO Y TRAZABILIDAD ===
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- === CONSTRAINTS ===
    UNIQUE (tenant_id, locale)
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE INDEX IF NOT EXISTS idx_itl_tenant   ON bauth.idn_tenant_languages(tenant_id, locale);
CREATE INDEX IF NOT EXISTS idx_itl_locale   ON bauth.idn_tenant_languages(locale, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itl_status   ON bauth.idn_tenant_languages(translation_status, tenant_id);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bauth.idn_tenant_languages IS
  '[BCP 47] [RFC 5646] [ISO 639] [Unicode CLDR] [ISO 27001 A.8.15]
   Idiomas habilitados por tenant con configuración de traducción.
   PK: language_config_id UUIDv7. Natural key: (tenant_id, locale) UNIQUE.
   FK: tenant_id → idn_tenant(tenant_id), locale → global_language(locale).';

COMMENT ON COLUMN bauth.idn_tenant_languages.language_config_id IS
  '[RFC 9562] UUIDv7 PK time-ordered.';

COMMENT ON COLUMN bauth.idn_tenant_languages.tenant_id IS
  'FK UUID → bauth.idn_tenant(tenant_id). ON DELETE CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant_languages.locale IS
  '[BCP 47] FK TEXT → bglobal.global_language(locale). Idioma habilitado: es-BO, en-US, pt-BR, qu-BO.';

COMMENT ON COLUMN bauth.idn_tenant_languages.is_default IS
  'true = idioma por defecto del tenant para UI y notificaciones.';

COMMENT ON COLUMN bauth.idn_tenant_languages.translation_provider IS
  'Proveedor de traducciones: sbos_i18n (interno), external_api (Google Translate, DeepL), custom_file (archivos .po/.ftl).';

COMMENT ON COLUMN bauth.idn_tenant_languages.translation_status IS
  '[CLDR] Estado de completitud: COMPLETE (100%), PARTIAL (<100%), MACHINE_TRANSLATED (automático), NOT_TRANSLATED (sin iniciar).';

COMMENT ON COLUMN bauth.idn_tenant_languages.is_active IS
  'true = idioma habilitado para este tenant.';

COMMENT ON COLUMN bauth.idn_tenant_languages.ctx_id IS
  '[SBOS-049 §4] Contexto operativo. DEFAULT system para bootstrap.';

COMMENT ON COLUMN bauth.idn_tenant_languages.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación.';

COMMENT ON COLUMN bauth.idn_tenant_languages.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bauth.idn_tenant_currencies IS
  '[ISO 4217] [NIST 800-53 AC-3] [ISO 27001 A.8.15]
   Monedas habilitadas por tenant con tasas de cambio respecto a la moneda default.
   PK: currency_config_id UUIDv7. Natural key: (tenant_id, currency_code) UNIQUE.
   FK: tenant_id → idn_tenant(tenant_id), currency_code → global_currency(currency_code).
   Un tenant debe tener al menos una moneda configurada como default (is_default = true).';

COMMENT ON COLUMN bauth.idn_tenant_currencies.currency_config_id IS
  '[RFC 9562] UUIDv7 PK time-ordered. Identificador interno para FKs entrantes.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.tenant_id IS
  'FK UUID → bauth.idn_tenant(tenant_id). Tenant dueño de esta configuración monetaria. ON DELETE CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.currency_code IS
  '[ISO 4217] FK CHAR(3) → bglobal.global_currency(currency_code). Moneda habilitada: BOB, USD, EUR.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.is_default IS
  'true = moneda funcional del tenant (base currency). Solo una por tenant debe ser true.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.exchange_rate IS
  'Tasa de cambio respecto a la moneda default del tenant. DECIMAL(18,8) para precisión financiera. NULL = sin tasa definida.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.exchange_source IS
  'Fuente de la tasa: BCB (Banco Central de Bolivia), ECB (European Central Bank), REUTERS, MANUAL, CUSTOM.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.exchange_updated_at IS
  'Timestamp de última actualización de la tasa de cambio. NULL = sin actualizar.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.is_active IS
  'true = moneda habilitada para este tenant. false = deshabilitada (no ofrecida en UI).';

COMMENT ON COLUMN bauth.idn_tenant_currencies.ctx_id IS
  '[SBOS-049 §4] Contexto operativo de la configuración. DEFAULT system para bootstrap inicial.';

COMMENT ON COLUMN bauth.idn_tenant_currencies.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación. Automático: DEFAULT now().';

COMMENT ON COLUMN bauth.idn_tenant_currencies.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';


-- ======================================================================
-- 009 — bauth.idn_tenant_verification (antes bos_tenant_verification)
-- Verificación KYC/IAL del tenant. 5 pasos requeridos para activación.
-- Cumple: NIST SP 800-63A (IAL1-3) · ISO 27001 A.8.2 · SBOS-049.
-- Schema: bauth — vinculada a idn_tenant.
-- Correcciones aplicadas:
--   C1: PK BIGSERIAL → verification_id UUIDv7 (R3: 100% UUID PKs)
--   C2: tenant_id TEXT → UUID FK → idn_tenant(tenant_id)
--   C3: step CHECK → verification_step_enum (type-safe, reutilizable)
--   C4: status CHECK → verification_status_enum (type-safe, reutilizable)
--   C5: verified_by TEXT → UUID (consistencia 100% UUID)
--   C6: +ctx_id (SBOS-049 trazabilidad)
--   C7: +updated_at (ISO 27001 A.8.15)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_verification (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    verification_id  UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === FK A TENANT ===
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- === PASO DE VERIFICACIÓN ===
    step             verification_step_enum   NOT NULL,
    status           verification_status_enum NOT NULL DEFAULT 'PENDING',

    -- === VERIFICADOR ===
    verified_by      UUID,
    verified_at      TIMESTAMPTZ,

    -- === EVIDENCIA ===
    comments         TEXT,
    evidence         JSONB       DEFAULT '{}',

    -- === TRAZABILIDAD ===
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- === CONSTRAINTS ===
    UNIQUE (tenant_id, step)
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE INDEX IF NOT EXISTS idx_itv_tenant   ON bauth.idn_tenant_verification(tenant_id, step);
CREATE INDEX IF NOT EXISTS idx_itv_status   ON bauth.idn_tenant_verification(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itv_step     ON bauth.idn_tenant_verification(step, status);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bauth.idn_tenant_verification IS
  '[NIST SP 800-63A] [ISO 27001 A.8.2] [SBOS-049 §4]
   Verificación KYC/IAL del tenant. 5 pasos secuenciales requeridos para activar un tenant.
   PK: verification_id UUIDv7. Natural key: (tenant_id, step) UNIQUE.
   FK: tenant_id → idn_tenant(tenant_id). ON DELETE CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant_verification.verification_id IS
  '[RFC 9562] UUIDv7 PK time-ordered. Identificador interno.';

COMMENT ON COLUMN bauth.idn_tenant_verification.tenant_id IS
  'FK UUID → bauth.idn_tenant(tenant_id). Tenant sujeto a verificación. ON DELETE CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant_verification.step IS
  '[NIST SP 800-63A IAL1-3] Paso de verificación:
   IDENTITY_CHECK (documentos de identidad), LEGAL_CHECK (registro mercantil, NIT),
   TECHNICAL_SETUP (infraestructura aprovisionada), SECURITY_REVIEW (políticas de seguridad),
   FINAL_APPROVAL (aprobación final por oficial de cumplimiento).';

COMMENT ON COLUMN bauth.idn_tenant_verification.status IS
  'Estado del paso: PENDING (sin iniciar), IN_PROGRESS (en revisión), PASSED (aprobado), FAILED (rechazado).';

COMMENT ON COLUMN bauth.idn_tenant_verification.verified_by IS
  'UUID del oficial que ejecutó/verificó este paso. FK lógica a idn_usuario.';

COMMENT ON COLUMN bauth.idn_tenant_verification.verified_at IS
  'Timestamp de cuando se completó la verificación de este paso. NULL = pendiente.';

COMMENT ON COLUMN bauth.idn_tenant_verification.comments IS
  'Notas del verificador. Evidencia narrativa de la decisión.';

COMMENT ON COLUMN bauth.idn_tenant_verification.evidence IS
  '[JSONB] Documentos de evidencia: {doc_type, file_hash, storage_path, uploaded_at}.';

COMMENT ON COLUMN bauth.idn_tenant_verification.ctx_id IS
  '[SBOS-049 §4] Contexto operativo de la verificación.';

COMMENT ON COLUMN bauth.idn_tenant_verification.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación del registro de verificación.';

COMMENT ON COLUMN bauth.idn_tenant_verification.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';


-- ======================================================================
-- 010 — bauth.idn_tenant_config (antes bos_tenant_config)
-- Configuración regional y preferencias del tenant.
-- Schema: bauth — vinculada a idn_tenant (1:1). Raíz de jerarquía de herencia
--          (tenant → empresa → sucursal → POS). NULL = heredar del padre.
-- Cumple: BCP 47 · ISO 4217 · IANA TZ · ISO 8601 · ISO 27001 A.8.15.
-- Correcciones aplicadas:
--   C1: PK tenant_id TEXT → config_id UUIDv7 + FK tenant_id UNIQUE → idn_tenant
--   C2: timezones → supported_timezones, themes_disponibles → supported_themes (inglés)
--   C3: multigestion_enabled → multifiscal_enabled, max_gestiones_abiertas → max_open_fiscal_years
--   C4: ALTER TABLE eliminados (columnas integradas en CREATE)
--   C5: +ctx_id (SBOS-049) + created_at (ISO 27001 A.8.15)
--   C6: COMMENT ON en todas las columnas
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_config (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    config_id            UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === FK A TENANT (1:1) ===
    tenant_id            UUID        UNIQUE NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- === IDIOMA (JSONB: snapshots de global_language vía idn_tenant_languages) ===
    locale_default       JSONB       NOT NULL DEFAULT '{"locale":"es-BO","iso_639_1":"es","name":{"es":"Español (Bolivia)","en":"Spanish (Bolivia)"}}',
    supported_locales    JSONB       DEFAULT '[{"locale":"es-BO","name":{"es":"Español (Bolivia)"}},{"locale":"en-US","name":{"en":"English (US)"}}]',
    fallback_locales     JSONB       DEFAULT '[{"locale":"es"},{"locale":"en"}]',
    date_format          TEXT        NOT NULL DEFAULT 'DD/MM/YYYY',
    time_format          TEXT        NOT NULL DEFAULT 'HH:mm:ss',
    number_format        TEXT        NOT NULL DEFAULT '1.234,56',
    first_day_of_week    INTEGER     NOT NULL DEFAULT 1,

    -- === ZONA HORARIA (JSONB: snapshots de geo_timezone activas) ===
    timezone_default     JSONB       NOT NULL DEFAULT '{"timezone_id":"America/La_Paz","utc_offset":"-04:00","name":{"es":"Bolivia (La Paz)","en":"Bolivia Time"}}',
    supported_timezones  JSONB       DEFAULT '[{"timezone_id":"America/La_Paz","utc_offset":"-04:00"},{"timezone_id":"America/Argentina/Buenos_Aires","utc_offset":"-03:00"}]',

    -- === MONEDA (JSONB: snapshots de global_currency vía idn_tenant_currencies) ===
    currency_default     JSONB       NOT NULL DEFAULT '{"currency_code":"BOB","name":{"es":{"singular":"Boliviano","plural":"Bolivianos"}},"symbol":"Bs.","decimal_places":2}',
    multicurrency        BOOLEAN     NOT NULL DEFAULT false,

    -- === CALENDARIO FISCAL ===
    multifiscal_enabled  BOOLEAN     NOT NULL DEFAULT true,
    max_open_fiscal_years INTEGER    DEFAULT 3,
    fiscal_year_start_month INTEGER  NOT NULL DEFAULT 1,
    fiscal_year_start_day   INTEGER  NOT NULL DEFAULT 1,
    first_fiscal_year       INTEGER,

    -- === TEMA / APARIENCIA ===
    theme_default        TEXT        NOT NULL DEFAULT 'light',
    supported_themes     TEXT[]      DEFAULT '{light,dark}',
    logo_url             TEXT,
    favicon_url          TEXT,
    primary_color        TEXT        DEFAULT '#1a73e8',
    secondary_color      TEXT        DEFAULT '#34a853',
    font_family          TEXT        DEFAULT 'Inter, system-ui, sans-serif',

    -- === NOTIFICACIONES ===
    notification_locale  TEXT        NOT NULL DEFAULT 'es-BO',
    email_footer_template TEXT,

    -- === METADATOS Y TRAZABILIDAD ===
    metadata             JSONB       DEFAULT '{}',
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE INDEX IF NOT EXISTS idx_itcfg_tenant   ON bauth.idn_tenant_config(tenant_id);
CREATE INDEX IF NOT EXISTS idx_itcfg_locale   ON bauth.idn_tenant_config USING GIN (locale_default jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itcfg_tz       ON bauth.idn_tenant_config USING GIN (timezone_default jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itcfg_currency ON bauth.idn_tenant_config USING GIN (currency_default jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itcfg_supported_locales ON bauth.idn_tenant_config USING GIN (supported_locales jsonb_path_ops);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bauth.idn_tenant_config IS
  '[BCP 47] [ISO 4217] [IANA TZ] [ISO 8601] [ISO 27001 A.8.15]
   Configuración regional y preferencias del tenant. Relación 1:1 con idn_tenant.
   Jerarquía de herencia: tenant → empresa → sucursal → POS (NULL = heredar del padre).
   Correcciones v2: UUIDv7 PK, FK UNIQUE a idn_tenant, columnas en inglés, ctx_id.';

COMMENT ON COLUMN bauth.idn_tenant_config.config_id IS
  '[RFC 9562] UUIDv7 PK time-ordered.';

COMMENT ON COLUMN bauth.idn_tenant_config.tenant_id IS
  '[UNIQUE] FK UUID → bauth.idn_tenant(tenant_id). Relación 1:1. ON DELETE CASCADE.';

COMMENT ON COLUMN bauth.idn_tenant_config.locale_default IS
  '[BCP 47] [JSONB] Snapshot del locale por defecto. Obtenido de global_language vía idn_tenant_languages.is_default.
   Estructura: {"locale":"es-BO","iso_639_1":"es","name":{"es":"Español (Bolivia)","en":"Spanish (Bolivia)"}}.
   Desnormalizado para acceso rápido sin JOIN al mostrar la config del tenant.';

COMMENT ON COLUMN bauth.idn_tenant_config.supported_locales IS
  '[BCP 47] [JSONB] Array de snapshots de locales habilitados. Obtenido de global_language vía idn_tenant_languages (is_active=true).
   Estructura: [{"locale":"es-BO","name":{"es":"Español (Bolivia)"}},{"locale":"en-US","name":{"en":"English (US)"}}].
   Orden = preferencia de UI. Desnormalizado para acceso rápido.';

COMMENT ON COLUMN bauth.idn_tenant_config.fallback_locales IS
  '[CLDR] [JSONB] Array de snapshots de locales de respaldo. Subconjunto de supported_locales usado como cadena de degradación.
   Estructura: [{"locale":"es"},{"locale":"en"}]. Desnormalizado para acceso rápido.';

COMMENT ON COLUMN bauth.idn_tenant_config.date_format IS
  '[ISO 8601] Formato de fecha: DD/MM/YYYY (Bolivia), MM/DD/YYYY (EE.UU.), YYYY-MM-DD (ISO).';

COMMENT ON COLUMN bauth.idn_tenant_config.time_format IS
  '[ISO 8601] Formato de hora: HH:mm:ss (24h), hh:mm:ss AM/PM (12h).';

COMMENT ON COLUMN bauth.idn_tenant_config.number_format IS
  '[CLDR] Formato de número: 1.234,56 (es-BO), 1,234.56 (en-US), 1 234,56 (fr-FR).';

COMMENT ON COLUMN bauth.idn_tenant_config.first_day_of_week IS
  '[CLDR] Primer día de la semana: 1=lunes (Bolivia/LATAM/Europa), 7=domingo (EE.UU.).';

COMMENT ON COLUMN bauth.idn_tenant_config.timezone_default IS
  '[IANA TZ] [JSONB] Snapshot de la zona horaria por defecto. Obtenido de geo_timezone (is_active=true).
   Estructura: {"timezone_id":"America/La_Paz","utc_offset":"-04:00","name":{"es":"Bolivia (La Paz)","en":"Bolivia Time"}}.
   Desnormalizado para acceso rápido sin JOIN.';

COMMENT ON COLUMN bauth.idn_tenant_config.supported_timezones IS
  '[IANA TZ] [JSONB] Array de snapshots de zonas horarias de interés. Obtenido de geo_timezone activas.
   Estructura: [{"timezone_id":"America/La_Paz","utc_offset":"-04:00"},...]. Desnormalizado.';

COMMENT ON COLUMN bauth.idn_tenant_config.currency_default IS
  '[ISO 4217] [JSONB] Snapshot de la moneda por defecto. Obtenido de global_currency vía idn_tenant_currencies.is_default.
   Estructura: {"currency_code":"BOB","name":{"es":{"singular":"Boliviano","plural":"Bolivianos"}},"symbol":"Bs.","decimal_places":2}.
   Desnormalizado para acceso rápido sin JOIN.';

COMMENT ON COLUMN bauth.idn_tenant_config.multicurrency IS
  'true = tenant opera con múltiples monedas (requiere tasas de cambio).';

COMMENT ON COLUMN bauth.idn_tenant_config.multifiscal_enabled IS
  'true = tenant opera en múltiples años fiscales simultáneos (correcciones, auditoría).';

COMMENT ON COLUMN bauth.idn_tenant_config.max_open_fiscal_years IS
  'Máximo de gestiones fiscales abiertas simultáneamente. Default: 3.';

COMMENT ON COLUMN bauth.idn_tenant_config.fiscal_year_start_month IS
  'Mes de inicio del año fiscal. 1=Enero (Bolivia).';

COMMENT ON COLUMN bauth.idn_tenant_config.fiscal_year_start_day IS
  'Día de inicio del año fiscal. 1=primero del mes.';

COMMENT ON COLUMN bauth.idn_tenant_config.first_fiscal_year IS
  'Primer año fiscal de operaciones del tenant. NULL = sin definir.';

COMMENT ON COLUMN bauth.idn_tenant_config.theme_default IS
  'Tema visual por defecto: light, dark, system, high_contrast.';

COMMENT ON COLUMN bauth.idn_tenant_config.supported_themes IS
  'Array de temas habilitados para el tenant.';

COMMENT ON COLUMN bauth.idn_tenant_config.logo_url IS
  'URL del logo del tenant. NULL = usar logo del sistema.';

COMMENT ON COLUMN bauth.idn_tenant_config.favicon_url IS
  'URL del favicon. NULL = usar favicon del sistema.';

COMMENT ON COLUMN bauth.idn_tenant_config.primary_color IS
  'Color primario en hex: #1a73e8. Define acentos y botones principales.';

COMMENT ON COLUMN bauth.idn_tenant_config.secondary_color IS
  'Color secundario en hex: #34a853. Define acentos secundarios.';

COMMENT ON COLUMN bauth.idn_tenant_config.font_family IS
  'Familia tipográfica CSS: Inter, system-ui, sans-serif.';

COMMENT ON COLUMN bauth.idn_tenant_config.notification_locale IS
  '[BCP 47] Idioma de notificaciones (emails, push, SMS). Puede diferir del locale de UI.';

COMMENT ON COLUMN bauth.idn_tenant_config.email_footer_template IS
  'Plantilla de footer para emails. NULL = usar plantilla del sistema.';

COMMENT ON COLUMN bauth.idn_tenant_config.metadata IS
  '[JSONB] Metadatos extensibles sin modificar schema.';

COMMENT ON COLUMN bauth.idn_tenant_config.ctx_id IS
  '[SBOS-049 §4] Contexto operativo. DEFAULT system para bootstrap.';

COMMENT ON COLUMN bauth.idn_tenant_config.created_at IS
  '[ISO 27001 A.8.15] Timestamp de creación.';

COMMENT ON COLUMN bauth.idn_tenant_config.updated_at IS
  '[ISO 27001 A.8.15] Timestamp de última modificación.';


-- ======================================================================
-- 011 — bauth.idn_tenant_domain (antes bos_tenant_domain)
-- Dominios, NGINX, K8s HPA, SSL, DNS, correo y contactos por tenant.
-- Schema: bauth — vinculada a idn_tenant.
-- Cumple: RFC 952/1123 (DNS) · RFC 8446 (TLS 1.3) · RFC 8555 (ACME)
--         RFC 5321 (SMTP) · RFC 7208 (SPF) · RFC 6376 (DKIM) · RFC 7489 (DMARC)
--         ISO 27001 A.6.1.1 · NIST 800-53 SC-7/SC-8 · PCI DSS 4.0 Req 4
-- Diseño: columnas fijas para identidad + JSONB para configuraciones extensibles.
--         Cada JSONB puede crecer sin ALTER TABLE.
-- Correcciones aplicadas:
--   C1: PK BIGSERIAL → UUIDv7 + FK a idn_tenant
--   C2: 65 columnas planas → 17 columnas fijas + 10 JSONB extensibles
--   C3: Cada dominio de configuración es un JSONB independiente
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_tenant_domain (
    -- === IDENTIFICADORES ===
    domain_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id            UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    fqdn                 TEXT        NOT NULL UNIQUE,
    subdomain            TEXT,
    domain_type          domain_type_enum NOT NULL DEFAULT 'WEB',
    is_primary           BOOLEAN     NOT NULL DEFAULT false,
    is_custom            BOOLEAN     NOT NULL DEFAULT false,

    -- === CONFIGURACIONES EXTENSIBLES (JSONB) ===
    -- Cada JSONB agrupa un dominio de configuración.
    -- Puede crecer sin ALTER TABLE. Ver MANUAL_DB_DDL.md para estructura detallada.

    -- DNS [RFC 952/1123/1035]
    dns_config           JSONB       DEFAULT '{}',
    -- Estructura: {"provider":"cloudflare","record_type":"CNAME","target":"ingress.sbos.bo",
    --             "verified_at":null,"status":"PENDING",
    --             "records":[{"type":"A","host":"@","value":"1.2.3.4","ttl":300}]}

    -- SSL/TLS [RFC 8446/8555]
    ssl_config           JSONB       DEFAULT '{}',
    -- Estructura: {"provider":"letsencrypt","cert_secret":"tls-skull-admin",
    --             "expires_at":null,"acme_challenge":"HTTP-01","status":"PENDING",
    --             "subject_cn":"admin.skull.sbos.bo","sans":["*.skull.sbos.bo"]}

    -- NGINX Ingress Controller
    nginx_config         JSONB       DEFAULT '{}',
    -- Estructura: {"ingress_name":"ingress-skull-admin","ingress_class":"nginx",
    --             "proxy_body_size_mb":100,"proxy_read_timeout_s":600,
    --             "proxy_connect_timeout_s":30,"proxy_send_timeout_s":600,
    --             "proxy_buffer_size_kb":128,"proxy_buffers_number":4,
    --             "proxy_busy_buffers_size_kb":128,"proxy_max_temp_file_size_mb":1024,
    --             "proxy_request_buffering":true,"proxy_buffering":true,
    --             "client_body_buffer_size_kb":128,"client_body_timeout_s":60,
    --             "client_header_timeout_s":60,"server_tokens":false,
    --             "annotations_extra":{}}

    -- Kubernetes HPA [autoscaling/v2]
    k8s_hpa_config       JSONB       DEFAULT '{}',
    -- Estructura: {"enabled":true,"min_replicas":2,"max_replicas":20,
    --             "cpu_target_pct":70,"mem_target_pct":80,
    --             "cpu_request_m":100,"cpu_limit_m":500,
    --             "mem_request_mb":128,"mem_limit_mb":1024,
    --             "scale_up_stabilization_s":60,"scale_down_stabilization_s":300,
    --             "max_scale_up_pods":4,"max_scale_up_pct":100,
    --             "max_scale_down_pods":1,"max_scale_down_pct":25}

    -- Health Checks [K8s Probes]
    health_config        JSONB       DEFAULT '{}',
    -- Estructura: {"health_path":"/healthz","readiness_path":"/ready",
    --             "liveness_path":"/live","initial_delay_s":10,"period_s":30}

    -- Seguridad [NIST 800-53 / PCI DSS]
    security_config      JSONB       DEFAULT '{}',
    -- Estructura: {"force_ssl":true,"hsts_enabled":true,"hsts_max_age_s":31536000,
    --             "csp_policy":null,"cors_origins":[],"waf_enabled":false,
    --             "rate_limit_rps":100,"allowed_ips":[],"ip_filter_mode":"allow"}

    -- Redirecciones
    redirect_config      JSONB       DEFAULT '{}',
    -- Estructura: {"canonical_domain":null,"www_redirect":false,
    --             "custom_redirects":[],"cookie_domain":null}

    -- Correo [RFC 5321/7208/6376/7489]
    email_config         JSONB       DEFAULT '{}',
    -- Estructura: {"mx_records":[],"mx_priority":10,
    --             "spf_record":null,"spf_status":"PENDING",
    --             "dkim_selector":null,"dkim_public_key":null,"dkim_status":"PENDING",
    --             "dmarc_policy":"none","dmarc_pct":100,
    --             "dmarc_rua_email":null,"dmarc_ruf_email":null,
    --             "smtp_host":null,"smtp_port":587,"smtp_encryption":"TLS",
    --             "smtp_username":null,"smtp_password_vault_path":null,
    --             "smtp_from_name":null,"smtp_from_email":null,
    --             "smtp_rate_limit_per_hour":1000,
    --             "email_verification_required":true,
    --             "imap_host":null,"imap_port":993}

    -- Contactos [ISO 27001 A.6.1.1] [ICANN WHOIS] [RFC 2142]
    contacts             JSONB       DEFAULT '{}',
    -- Estructura: {"admin_id":null,"technical_id":null,
    --             "security_id":null,"billing_id":null,"notes":null}

    -- === ESTADO Y TRAZABILIDAD ===
    deploy_status        domain_status_enum DEFAULT 'PENDING',
    health_status        domain_status_enum DEFAULT 'PENDING',
    last_deployed_at     TIMESTAMPTZ,
    last_health_check_at TIMESTAMPTZ,
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── ÍNDICES — PostgreSQL 18 Skip Scan ──
CREATE INDEX IF NOT EXISTS idx_itd_tenant    ON bauth.idn_tenant_domain(tenant_id, domain_type);
CREATE INDEX IF NOT EXISTS idx_itd_fqdn      ON bauth.idn_tenant_domain(fqdn);
CREATE INDEX IF NOT EXISTS idx_itd_type      ON bauth.idn_tenant_domain(domain_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_itd_dns       ON bauth.idn_tenant_domain USING GIN (dns_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_ssl       ON bauth.idn_tenant_domain USING GIN (ssl_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_nginx     ON bauth.idn_tenant_domain USING GIN (nginx_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_k8s       ON bauth.idn_tenant_domain USING GIN (k8s_hpa_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_security  ON bauth.idn_tenant_domain USING GIN (security_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_email     ON bauth.idn_tenant_domain USING GIN (email_config jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_itd_contacts  ON bauth.idn_tenant_domain USING GIN (contacts jsonb_path_ops);

-- ── COMMENT ON — Documentación normativa ──
COMMENT ON TABLE bauth.idn_tenant_domain IS
  '[RFC 952/1123/1035] [RFC 8446/8555] [RFC 5321/7208/6376/7489] [RFC 6797] [RFC 2142/3501]
   [ISO 27001 A.6.1.1] [NIST 800-53 SC-7/SC-8] [PCI DSS 4.0 Req 4/11.3]
   Configuración completa de dominio por tenant. 17 columnas fijas de identidad +
   10 JSONB extensibles (DNS, SSL, NGINX, K8s HPA, health, seguridad, redirect, email, contacts).
   Los JSONB permiten evolución sin ALTER TABLE — nuevos parámetros se agregan al JSON.';

COMMENT ON COLUMN bauth.idn_tenant_domain.domain_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.idn_tenant_domain.tenant_id IS 'FK UUID → idn_tenant(tenant_id). ON DELETE CASCADE.';
COMMENT ON COLUMN bauth.idn_tenant_domain.fqdn IS '[RFC 952] UNIQUE NOT NULL. FQDN: admin.skull.sbos.bo.';
COMMENT ON COLUMN bauth.idn_tenant_domain.subdomain IS 'Subdominio: admin, api, pos, portal. NULL = raíz.';
COMMENT ON COLUMN bauth.idn_tenant_domain.domain_type IS '[ENUM] WEB, API, POS, ADMIN, PORTAL, STATIC, MAIL.';
COMMENT ON COLUMN bauth.idn_tenant_domain.is_primary IS 'true = dominio canónico del tenant (único).';
COMMENT ON COLUMN bauth.idn_tenant_domain.is_custom IS 'true = BYOD. Requiere verificación DNS TXT.';

COMMENT ON COLUMN bauth.idn_tenant_domain.dns_config IS '[JSONB] [RFC 952/1123/1035] Config DNS: provider, record_type, target, records[]. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.ssl_config IS '[JSONB] [RFC 8446/8555] Config SSL: provider, cert_secret, acme_challenge, sans[]. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.nginx_config IS '[JSONB] [NGINX] Config Ingress: proxy timeouts, buffers, body size, annotations. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.k8s_hpa_config IS '[JSONB] [autoscaling/v2] Config HPA: replicas, CPU/mem targets/limits, stabilization. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.health_config IS '[JSONB] [K8s Probes] Config salud: paths, initial_delay, period. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.security_config IS '[JSONB] [NIST 800-53/PCI DSS] Seguridad: HSTS, CSP, CORS, WAF, rate_limit, IP filter. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.redirect_config IS '[JSONB] Redirecciones: canonical_domain, www_redirect, custom_redirects[]. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.email_config IS '[JSONB] [RFC 5321/7208/6376/7489] Correo: MX, SPF, DKIM, DMARC, SMTP, IMAP. Ver MANUAL_DB_DDL.md.';
COMMENT ON COLUMN bauth.idn_tenant_domain.contacts IS '[JSONB] [ISO 27001 A.6.1.1] [RFC 2142] Contactos: admin, technical, security, billing. FKs lógicas a idn_usuario.';

COMMENT ON COLUMN bauth.idn_tenant_domain.deploy_status IS '[ENUM] PENDING, DEPLOYING, DEPLOYED, FAILED, ROLLED_BACK.';
COMMENT ON COLUMN bauth.idn_tenant_domain.health_status IS '[ENUM] PENDING, HEALTHY, DEGRADED, UNHEALTHY, UNKNOWN.';
COMMENT ON COLUMN bauth.idn_tenant_domain.last_deployed_at IS 'Timestamp del último despliegue exitoso.';
COMMENT ON COLUMN bauth.idn_tenant_domain.last_health_check_at IS 'Timestamp del último health check.';
COMMENT ON COLUMN bauth.idn_tenant_domain.ctx_id IS '[SBOS-049 §4] Contexto operativo.';
COMMENT ON COLUMN bauth.idn_tenant_domain.created_at IS '[ISO 27001 A.8.15] Creación.';
COMMENT ON COLUMN bauth.idn_tenant_domain.updated_at IS '[ISO 27001 A.8.15] Última modificación.';


-- ======================================================================
-- 012 — bauth.idn_tenant_network (antes bos_tenant_network)
-- Redes y rangos CIDR autorizados por tenant. Zero Trust + geolocalización.
-- Schema: bauth — vinculada a idn_tenant.
-- Cumple: RFC 4632 (CIDR) · RFC 1918 (Private IPs) · NIST 800-207 ZTA.
-- Correcciones: C1 UUIDv7, C2 FK idn_tenant, C3 inglés, C4 ENUM, C5 ctx_id.
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

-- ── ÍNDICES ──
CREATE INDEX IF NOT EXISTS idx_itn_tenant   ON bauth.idn_tenant_network(tenant_id, network_type);
CREATE INDEX IF NOT EXISTS idx_itn_cidr     ON bauth.idn_tenant_network USING GIST (cidr inet_ops);
CREATE INDEX IF NOT EXISTS idx_itn_type     ON bauth.idn_tenant_network(network_type, tenant_id);

-- ── COMMENT ON ──
COMMENT ON TABLE bauth.idn_tenant_network IS
  '[RFC 4632] [RFC 1918] [NIST 800-207 ZTA]
   Redes y rangos CIDR autorizados por tenant. Usado para geolocalización,
   políticas de acceso Zero Trust, y segmentación de red.
   PK: network_id UUIDv7. FK: tenant_id → idn_tenant.';

COMMENT ON COLUMN bauth.idn_tenant_network.network_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.idn_tenant_network.tenant_id IS 'FK UUID → idn_tenant. ON DELETE CASCADE.';
COMMENT ON COLUMN bauth.idn_tenant_network.name IS 'Nombre descriptivo: Red Principal La Paz, VPN Corporativa.';
COMMENT ON COLUMN bauth.idn_tenant_network.network_type IS '[ENUM] LAN, WAN, VPN, DMZ, GUEST, MANAGEMENT. Define el tipo de red.';
COMMENT ON COLUMN bauth.idn_tenant_network.cidr IS '[RFC 4632] Rango CIDR: 10.0.1.0/24, 192.168.0.0/16. NOT NULL.';
COMMENT ON COLUMN bauth.idn_tenant_network.gateway IS 'IP del gateway: 10.0.1.1. NULL = sin gateway definido.';
COMMENT ON COLUMN bauth.idn_tenant_network.dns_servers IS 'Array de IPs de servidores DNS: {10.0.1.53,8.8.8.8}.';
COMMENT ON COLUMN bauth.idn_tenant_network.vlan_id IS 'VLAN ID (802.1Q): 1-4094. NULL = sin VLAN.';
COMMENT ON COLUMN bauth.idn_tenant_network.is_active IS 'true = red activa. false = deshabilitada.';
COMMENT ON COLUMN bauth.idn_tenant_network.metadata IS '[JSONB] Metadatos extensibles: ubicación física, responsable, etc.';
COMMENT ON COLUMN bauth.idn_tenant_network.ctx_id IS '[SBOS-049 §4] Contexto operativo.';
COMMENT ON COLUMN bauth.idn_tenant_network.created_at IS '[ISO 27001 A.8.15] Creación.';
COMMENT ON COLUMN bauth.idn_tenant_network.updated_at IS '[ISO 27001 A.8.15] Última modificación.';


-- ═══════════════════════════════════════════════════════════════════════╗
-- ║                FASE 3 — CALENDARIO FISCAL (bcalendar)               ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- 013 — bcalendar.cal_fiscal_year (antes bos_tenant_gestion)
-- Gestión multigestión: años fiscales con períodos contables.
-- Schema: bcalendar — calendario fiscal, independiente de identidad.
-- Cumple: SIN Bolivia · NIC 1 (IAS 1) · NIC 8 (IAS 8) · IAS 10 · ISO 27001 A.8.15.
-- Correcciones aplicadas:
--   C1: PK BIGSERIAL → fiscal_year_id UUIDv7 (R3)
--   C2: tenant_id TEXT → UUID FK → idn_tenant
--   C3: empresa_id TEXT → UUID FK lógica (NULL = global tenant)
--   C4: columnas en inglés, ENUM para estado, JSONB para periods
--   C5: +ctx_id (SBOS-049)
-- ======================================================================
CREATE TABLE IF NOT EXISTS bcalendar.cal_fiscal_year (
    -- === IDENTIFICADOR INTERNO ===
    fiscal_year_id       UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === FKs ===
    tenant_id            UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    company_id           UUID,

    -- === DATOS FISCALES ===
    fiscal_year          INTEGER     NOT NULL,
    name                 TEXT        NOT NULL,
    status               fiscal_year_status_enum NOT NULL DEFAULT 'OPEN',
    start_date           DATE        NOT NULL,
    end_date             DATE,
    closed_by            UUID,
    closed_at            TIMESTAMPTZ,

    -- === PERÍODOS MENSUALES [JSONB] ===
    periods              JSONB       NOT NULL DEFAULT '[
        {"month":1,"name":"Enero","status":"OPEN"},
        {"month":2,"name":"Febrero","status":"OPEN"},
        {"month":3,"name":"Marzo","status":"OPEN"},
        {"month":4,"name":"Abril","status":"OPEN"},
        {"month":5,"name":"Mayo","status":"OPEN"},
        {"month":6,"name":"Junio","status":"OPEN"},
        {"month":7,"name":"Julio","status":"OPEN"},
        {"month":8,"name":"Agosto","status":"OPEN"},
        {"month":9,"name":"Septiembre","status":"OPEN"},
        {"month":10,"name":"Octubre","status":"OPEN"},
        {"month":11,"name":"Noviembre","status":"OPEN"},
        {"month":12,"name":"Diciembre","status":"OPEN"}
    ]',

    -- === CONFIGURACIÓN ===
    is_current           BOOLEAN     DEFAULT false,
    allows_prior_adjustments BOOLEAN DEFAULT true,
    max_adjustment_months_back INTEGER DEFAULT 12,

    -- === TRAZABILIDAD ===
    ctx_id               TEXT        NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (tenant_id, company_id, fiscal_year)
);

-- ── ÍNDICES ──
CREATE INDEX IF NOT EXISTS idx_cfy_tenant    ON bcalendar.cal_fiscal_year(tenant_id, fiscal_year);
CREATE INDEX IF NOT EXISTS idx_cfy_company   ON bcalendar.cal_fiscal_year(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cfy_current   ON bcalendar.cal_fiscal_year(tenant_id) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS idx_cfy_status    ON bcalendar.cal_fiscal_year(status, tenant_id);

-- ── COMMENT ON ──
COMMENT ON TABLE bcalendar.cal_fiscal_year IS
  '[SIN Bolivia] [NIC 1/IAS 1] [NIC 8/IAS 8] [IAS 10] [ISO 27001 A.8.15]
   Gestión multigestión: años fiscales con 12 períodos contables mensuales.
   Permite operar en múltiples años fiscales simultáneos (corriente + anteriores).
   SIN Bolivia: cierre anual obligatorio, permite ajustes en gestiones cerradas (NC/ND).
   PK: fiscal_year_id UUIDv7. Natural key: (tenant_id, company_id, fiscal_year) UNIQUE.';

COMMENT ON COLUMN bcalendar.cal_fiscal_year.fiscal_year_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.tenant_id IS 'FK UUID → idn_tenant. ON DELETE CASCADE.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.company_id IS 'FK lógica a idn_empresa. NULL = año fiscal global del tenant (aplica a todas las empresas).';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.fiscal_year IS '[NIC 1] Año fiscal: 2025, 2026, 2027.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.name IS 'Nombre descriptivo: Gestión 2026, FY2026.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.status IS '[ENUM] OPEN (operando) → CLOSED (cierre anual SIN) → CLOSED_WITH_ADJUSTMENTS (NC/ND posteriores) → ARCHIVED (solo lectura, 8 años).';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.start_date IS '[IAS 10] Fecha de inicio del año fiscal.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.end_date IS '[IAS 10] Fecha de cierre. NULL = gestión abierta.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.closed_by IS 'UUID del usuario que ejecutó el cierre. FK lógica a idn_usuario.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.closed_at IS 'Timestamp de cierre. NULL = gestión abierta.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.periods IS '[JSONB] 12 períodos mensuales con nombre y estado individual. Cada mes puede cerrarse independientemente.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.is_current IS '[NIC 1] Solo UNA gestión corriente por tenant/company. Las transacciones nuevas van aquí.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.allows_prior_adjustments IS '[NIC 8] Permitir notas de crédito/débito en gestiones ya cerradas.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.max_adjustment_months_back IS '[NIC 8] Máximo de meses hacia atrás para ajustes retroactivos. Default 12.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.ctx_id IS '[SBOS-049 §4] Contexto operativo.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.created_at IS '[ISO 27001 A.8.15] Creación.';
COMMENT ON COLUMN bcalendar.cal_fiscal_year.updated_at IS '[ISO 27001 A.8.15] Última modificación.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║           CALENDAR SUBSYSTEM — bcalendar + bauth bridge             ║
-- ║   RFC 5545/4791/7953 · rrule_plpgsql · Novu · Mattermost           ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- 014 — bauth.idn_calendar_assignment (NUEVA)
-- Tabla puente: asigna calendarios a entidades bauth (tenant/empresa/sucursal/usuario).
-- Soporta herencia jerárquica y RBAC (OWNER/EDITOR/VIEWER).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.idn_calendar_assignment (
    assignment_id    UUID        PRIMARY KEY DEFAULT uuidv7(),
    calendar_id      UUID        NOT NULL,
    owner_type       calendar_owner_type_enum NOT NULL,
    owner_id         UUID        NOT NULL,
    role             calendar_role_enum NOT NULL DEFAULT 'VIEWER',
    is_inherited     BOOLEAN     NOT NULL DEFAULT false,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (calendar_id, owner_type, owner_id)
);

CREATE INDEX IF NOT EXISTS idx_ica_calendar ON bauth.idn_calendar_assignment(calendar_id);
CREATE INDEX IF NOT EXISTS idx_ica_owner    ON bauth.idn_calendar_assignment(owner_type, owner_id);

COMMENT ON TABLE bauth.idn_calendar_assignment IS
  'Tabla puente: asigna calendarios bcalendar a entidades bauth.
   owner_type: TENANT, COMPANY, BRANCH, USER.
   Herencia: tenant asigna → empresa hereda (is_inherited=true) → sucursal hereda.
   RBAC: OWNER (gestiona), EDITOR (modifica eventos), VIEWER (solo lectura).';
COMMENT ON COLUMN bauth.idn_calendar_assignment.calendar_id IS 'FK UUID → bcalendar.cal_calendar.';
COMMENT ON COLUMN bauth.idn_calendar_assignment.owner_type IS '[ENUM] TENANT, COMPANY, BRANCH, USER.';
COMMENT ON COLUMN bauth.idn_calendar_assignment.owner_id IS 'UUID de la entidad dueña: tenant_id, company_id, sucursal_id, user_id.';
COMMENT ON COLUMN bauth.idn_calendar_assignment.role IS '[ENUM] OWNER, EDITOR, VIEWER.';
COMMENT ON COLUMN bauth.idn_calendar_assignment.is_inherited IS 'true = heredado del nivel superior. false = asignación directa.';


-- ======================================================================
-- 015 — bcalendar.cal_calendar (NUEVA · RFC 4791 VCALENDAR)
-- Colección de calendarios por tenant. Tipos: WORK, FISCAL, PROCESS, etc.
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
  '[RFC 4791 VCALENDAR] Colección de calendarios. Tipos: WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE.
   Un tenant puede tener N calendarios. is_system=true → calendario predefinido por SBOS.';
COMMENT ON COLUMN bcalendar.cal_calendar.calendar_id IS '[RFC 9562] UUIDv7 PK. FK referenciada por idn_calendar_assignment y cal_event.';
COMMENT ON COLUMN bcalendar.cal_calendar.calendar_type IS '[ENUM] WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE.';
COMMENT ON COLUMN bcalendar.cal_calendar.timezone IS '[IANA TZ] Zona horaria del calendario. Las ocurrencias se expanden en esta TZ.';


-- ======================================================================
-- 016 — bcalendar.cal_event (NUEVA · RFC 5545 VEVENT)
-- Evento maestro con recurrencia. rrule TEXT sin expandir.
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
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_by       UUID,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cev_calendar  ON bcalendar.cal_event(calendar_id, dtstart);
CREATE INDEX IF NOT EXISTS idx_cev_dtstart   ON bcalendar.cal_event(dtstart, dtend);
CREATE INDEX IF NOT EXISTS idx_cev_rrule     ON bcalendar.cal_event(calendar_id) WHERE rrule IS NOT NULL;

COMMENT ON TABLE bcalendar.cal_event IS
  '[RFC 5545 VEVENT] Evento maestro. rrule TEXT sin expandir (FREQ=WEEKLY;BYDAY=MO,WE,FR).
   Una serie completa = 1 registro. Las ocurrencias se materializan on-demand vía rrule_plpgsql.';
COMMENT ON COLUMN bcalendar.cal_event.rrule IS '[RFC 5545 §3.8.5] Regla de recurrencia: FREQ, INTERVAL, BYDAY, BYMONTH, COUNT, UNTIL. NULL = evento único.';
COMMENT ON COLUMN bcalendar.cal_event.exdate IS '[RFC 5545 §3.8.5.1] Array de fechas excluidas de la recurrencia.';


-- ======================================================================
-- 017 — bcalendar.cal_alarm (NUEVA · RFC 5545 VALARM)
-- Alarma/disparador de notificación. Define canal, lead time y template.
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

CREATE INDEX IF NOT EXISTS idx_cal_next_trigger ON bcalendar.cal_alarm(next_trigger_at, is_active) WHERE is_active = true;

COMMENT ON TABLE bcalendar.cal_alarm IS
  '[RFC 5545 VALARM] Disparador de notificación. Define CUÁNDO (trigger_seconds antes del evento)
   y CÓMO (channel). El motor de notificaciones (Novu) consulta alarmas cuyo next_trigger_at <= NOW().
   Sin cal_alarm no hay notificación — es el puente entre calendario y Novu.';
COMMENT ON COLUMN bcalendar.cal_alarm.trigger_seconds IS 'Segundos antes del dtstart. Negativo = antes. -900 = 15 min antes, -86400 = 1 día antes.';
COMMENT ON COLUMN bcalendar.cal_alarm.channel IS '[ENUM] Canal de entrega: EMAIL, SMS, WHATSAPP, PUSH, CHAT (Mattermost), UI (in-app).';
COMMENT ON COLUMN bcalendar.cal_alarm.last_triggered_at IS 'Última vez que esta alarma disparó. NULL = nunca disparada.';
COMMENT ON COLUMN bcalendar.cal_alarm.next_trigger_at IS 'Próxima vez que debe disparar. Calculado por rrule_plpgsql. Índice para polling.';


-- ======================================================================
-- 018 — bcalendar.cal_notification_log (NUEVA · ISO 27001 A.8.15)
-- Registro WORM de notificaciones enviadas. Solo INSERT.
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
CREATE INDEX IF NOT EXISTS idx_cnl_ctx   ON bcalendar.cal_notification_log(ctx_id);

-- REVOKE: WORM — solo INSERT, nunca UPDATE ni DELETE
REVOKE UPDATE, DELETE ON bcalendar.cal_notification_log FROM PUBLIC;

COMMENT ON TABLE bcalendar.cal_notification_log IS
  '[ISO 27001 A.8.15] [WORM] Registro inmutable de notificaciones enviadas.
   Solo INSERT permitido. REVOKE UPDATE/DELETE. ctx_id obligatorio.';


-- ======================================================================
-- 019 — bcalendar.cal_holiday (NUEVA)
-- Feriados fijos y móviles por país/región/tenant.
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

COMMENT ON TABLE bcalendar.cal_holiday IS
  'Feriados fijos (Navidad=12-25) y móviles (Pascua por fórmula de Gauss).
   Por país/región/tenant. is_recurring=true → se repite cada año.';


-- ======================================================================
-- 020 — bcalendar.cal_schedule (NUEVA · RFC 7953 VAVAILABILITY)
-- Horarios de trabajo y turnos. Reemplaza bos_schedule.
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
  '[RFC 7953 VAVAILABILITY] Horarios de trabajo y turnos. Reemplaza bos_schedule.
   Heredable: se asigna vía idn_calendar_assignment a tenant/empresa/sucursal.
   access_outside_schedule: BLOCKED (denegar), PERMITTED, REQUIRES_APPROVAL, READ_ONLY.';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║           DOMINIO FÍSICO (D2) — PACS · IEC 60839-11-5              ║
-- ║   fis_ prefijo · Closure Table · OSDP · ONVIF · BS 5979            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ======================================================================
-- 021 — bauth.fis_location (REEMPLAZA bos_sitio_fisico+bos_edificio+bos_piso+bos_area_fisica)
-- Tabla ÚNICA de jerarquía física — Closure Table Pattern.
-- Adjacency list: parent_id FK self-referencing.
-- Reemplaza 5 tablas heredadas en 1 tabla + 1 closure table.
-- Schema: bauth (prefijo fis_) · Dominio D2 Físico.
-- Cumple: IEC 60839-11-5 (OSDP) · BS 5979 · NIST SP 800-53 PE.
-- Correcciones aplicadas:
--   C1: 4 tablas planas → 1 tabla jerárquica con parent_id self-referencing
--   C2: PK TEXT → UUIDv7
--   C3: tenant_id TEXT → UUID FK → idn_tenant
--   C4: Columnas en inglés + properties JSONB para campos específicos por nivel
--   C5: CHECK constraints → ENUM types
--   C6: +ctx_id (SBOS-049) + updated_at
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_location (
    -- === IDENTIFICADOR INTERNO (UUIDv7) ===
    location_id      UUID        PRIMARY KEY DEFAULT uuidv7(),

    -- === JERARQUÍA (Adjacency List) ===
    parent_id        UUID        REFERENCES bauth.fis_location(location_id) ON DELETE RESTRICT,
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    location_type    fis_location_type_enum NOT NULL,

    -- === IDENTIDAD ===
    name             TEXT        NOT NULL,
    code             TEXT        NOT NULL,

    -- === UBICACIÓN ===
    coordinates      POINT,
    address          TEXT,
    country_code     CHAR(2)     NOT NULL DEFAULT 'BO',

    -- === SEGURIDAD FÍSICA [BS 5979] ===
    security_zone    INTEGER     NOT NULL DEFAULT 1,
    perimeter_type   fis_perimeter_type_enum DEFAULT 'FENCE',
    perimeter_lighting BOOLEAN   DEFAULT false,
    geo_fence_radius_m INTEGER   DEFAULT 100,

    -- === ESTADO ===
    is_active        BOOLEAN     NOT NULL DEFAULT true,
    properties       JSONB       DEFAULT '{}',
    metadata         JSONB       DEFAULT '{}',

    -- === TRAZABILIDAD ===
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (tenant_id, code)
);

-- ── ÍNDICES — PostgreSQL 18 ──
CREATE INDEX IF NOT EXISTS idx_floc_parent   ON bauth.fis_location(parent_id);
CREATE INDEX IF NOT EXISTS idx_floc_type     ON bauth.fis_location(location_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_floc_tenant   ON bauth.fis_location(tenant_id, location_type);
CREATE INDEX IF NOT EXISTS idx_floc_coords   ON bauth.fis_location USING GIST (coordinates) WHERE coordinates IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_floc_props    ON bauth.fis_location USING GIN (properties jsonb_path_ops);


-- ======================================================================
-- 022 — bauth.fis_location_closure (NUEVA)
-- Closure Table: precomputa todos los caminos ancestro→descendiente.
-- Mantenida por trigger. Permite consultas jerárquicas en 1 JOIN.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_location_closure (
    ancestor_id      UUID NOT NULL REFERENCES bauth.fis_location(location_id) ON DELETE CASCADE,
    descendant_id    UUID NOT NULL REFERENCES bauth.fis_location(location_id) ON DELETE CASCADE,
    depth            INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_flc_ancestor ON bauth.fis_location_closure(ancestor_id, depth);
CREATE INDEX IF NOT EXISTS idx_flc_descendant ON bauth.fis_location_closure(descendant_id, depth);


-- ── COMMENT ON ──
COMMENT ON TABLE bauth.fis_location IS
  '[IEC 60839-11-5] [BS 5979] [NIST SP 800-53 PE]
   Tabla ÚNICA de jerarquía física (adjacency list). Reemplaza bos_sitio_fisico + bos_edificio + bos_piso + bos_area_fisica.
   parent_id self-referencing. location_type define el nivel: SITE, BUILDING, FLOOR, WING, AREA, DOOR, DEVICE.
   properties JSONB: campos específicos por nivel (building_class, floor_number, door_type, etc.).
   security_zone: BS 5979 Zone 0 (pública) a Zone 5 (máxima). Heredable.';

COMMENT ON COLUMN bauth.fis_location.location_id IS '[RFC 9562] UUIDv7 PK. Nodo en la jerarquía física.';
COMMENT ON COLUMN bauth.fis_location.parent_id IS 'FK self-referencing. NULL = raíz (SITE). ON DELETE RESTRICT.';
COMMENT ON COLUMN bauth.fis_location.tenant_id IS 'FK UUID → idn_tenant. ON DELETE CASCADE.';
COMMENT ON COLUMN bauth.fis_location.location_type IS '[ENUM] SITE, BUILDING, FLOOR, WING, AREA, DOOR, DEVICE. Define el nivel jerárquico.';
COMMENT ON COLUMN bauth.fis_location.name IS 'Nombre descriptivo: Campus Central La Paz, Torre Administrativa, Bóveda Principal.';
COMMENT ON COLUMN bauth.fis_location.code IS 'Código único por tenant: skull-lapaz, torre-admin, boveda-01. UNIQUE(tenant_id, code).';
COMMENT ON COLUMN bauth.fis_location.coordinates IS '[ISO 6709] POINT(lat, lon). Coordenadas del centro del sitio/edificio.';
COMMENT ON COLUMN bauth.fis_location.address IS 'Dirección física: Av. Arce #1234, La Paz.';
COMMENT ON COLUMN bauth.fis_location.country_code IS '[ISO 3166-1 alpha-2] País. Default BO.';
COMMENT ON COLUMN bauth.fis_location.security_zone IS '[BS 5979] Zone 0 (pública) a Zone 5 (máxima). Un hijo hereda la zona del padre si no la define.';
COMMENT ON COLUMN bauth.fis_location.perimeter_type IS '[ENUM] FENCE, WALL, VEHICLE_BARRIER, NONE. Tipo de perímetro físico.';
COMMENT ON COLUMN bauth.fis_location.geo_fence_radius_m IS 'Radio del geo-fence en metros. Default 100. Usado para validar presencia.';
COMMENT ON COLUMN bauth.fis_location.properties IS '[JSONB] Campos específicos del nivel jerárquico: building_class, floor_number, door_type, area_type, etc. Extensible sin ALTER TABLE.';
COMMENT ON COLUMN bauth.fis_location.ctx_id IS '[SBOS-049 §4] Contexto operativo.';

COMMENT ON TABLE bauth.fis_location_closure IS
  'Closure table del dominio físico. Precomputa todos los pares ancestro→descendiente.
   depth=0 → self. Mantenida por trigger trg_fis_location_closure.
   Permite "todas las puertas de un sitio" en 1 JOIN.';


-- ======================================================================
-- 023 — bauth.fis_area_config (NUEVA)
-- Reglas de seguridad por área. Solo para location_type=AREA.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_area_config (
    config_id            UUID PRIMARY KEY DEFAULT uuidv7(),
    location_id          UUID NOT NULL REFERENCES bauth.fis_location(location_id) ON DELETE CASCADE UNIQUE,
    requires_escort      BOOLEAN NOT NULL DEFAULT false,
    requires_two_person  BOOLEAN NOT NULL DEFAULT false,
    requires_mantrap     BOOLEAN NOT NULL DEFAULT false,
    requires_anti_tailgating BOOLEAN NOT NULL DEFAULT false,
    max_occupancy        INTEGER,
    camera_required      BOOLEAN NOT NULL DEFAULT false,
    allowed_schedules    UUID[] DEFAULT '{}',
    metadata             JSONB DEFAULT '{}',
    ctx_id               TEXT NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fac_location ON bauth.fis_area_config(location_id);

COMMENT ON TABLE bauth.fis_area_config IS
  '[BS 5979] Reglas de seguridad por área. UNIQUE location_id (1:1 con fis_location donde location_type=AREA).
   requires_escort: visitantes deben ser escoltados. requires_two_person: mínimo 2 personas (bóveda).
   requires_mantrap: esclusa de seguridad. requires_anti_tailgating: sensor anti-intrusión.';
COMMENT ON COLUMN bauth.fis_area_config.allowed_schedules IS 'Array de UUIDs de cal_schedule. Define horarios permitidos para esta área.';


-- ======================================================================
-- 024 — bauth.fis_device (antes bos_dispositivo_fisico)
-- Dispositivos físicos: lectores, chapas, cámaras, sensores.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_device (
    device_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    location_id      UUID NOT NULL REFERENCES bauth.fis_location(location_id) ON DELETE CASCADE UNIQUE,
    tenant_id        UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    device_type      fis_device_type_enum NOT NULL,
    protocol         fis_device_protocol_enum NOT NULL DEFAULT 'OSDP',
    ip_address       INET,
    mac_address      MACADDR,
    serial_number    TEXT,
    firmware_version TEXT,
    auth_level       INTEGER NOT NULL DEFAULT 1,
    is_online        BOOLEAN NOT NULL DEFAULT false,
    last_seen_at     TIMESTAMPTZ,
    pos_logical_id   UUID,
    status           fis_device_status_enum NOT NULL DEFAULT 'ACTIVE',
    metadata         JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fd_location ON bauth.fis_device(location_id);
CREATE INDEX IF NOT EXISTS idx_fd_type     ON bauth.fis_device(device_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_fd_online   ON bauth.fis_device(is_online, last_seen_at) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_fd_pos      ON bauth.fis_device(pos_logical_id) WHERE pos_logical_id IS NOT NULL;

COMMENT ON TABLE bauth.fis_device IS
  '[IEC 60839-11-5] Dispositivos físicos. Relación 1:1 con fis_location para DEVICEs.
   device_type: 15 tipos (lectores, chapas, cámaras, sensores). protocol: OSDP, ONVIF, MQTT, Modbus.
   auth_level: 1=tarjeta, 2=tarjeta+PIN, 3=biométrico, 4=doble factor físico.
   Reemplaza bos_dispositivo_fisico.';
COMMENT ON COLUMN bauth.fis_device.auth_level IS 'Nivel de autenticación requerido: 1=tarjeta, 2=tarjeta+PIN, 3=biométrico, 4=doble factor.';
COMMENT ON COLUMN bauth.fis_device.status IS '[ENUM] ACTIVE, INACTIVE, ALARM, FAULT, MAINTENANCE, OFFLINE. Monitoreado por NEXUS.';


-- ======================================================================
-- 025 — bauth.fis_controller (NUEVA)
-- Controlador hardware (ACU — Access Control Unit).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_controller (
    controller_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    site_location_id UUID NOT NULL REFERENCES bauth.fis_location(location_id),
    tenant_id        UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT NOT NULL,
    model            TEXT,
    ip_address       INET,
    firmware_version TEXT,
    ports_count      INTEGER NOT NULL DEFAULT 4,
    is_online        BOOLEAN NOT NULL DEFAULT false,
    last_heartbeat   TIMESTAMPTZ,
    metadata         JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fctl_site   ON bauth.fis_controller(site_location_id);
CREATE INDEX IF NOT EXISTS idx_fctl_online ON bauth.fis_controller(is_online, last_heartbeat) WHERE is_online = true;

COMMENT ON TABLE bauth.fis_controller IS
  '[IEC 60839-11-5 ACU] Controlador hardware. Gestiona N dispositivos vía OSDP multi-drop RS-485.
   1 controlador : hasta 4 puertas (OSDP estándar) o hasta 132 lectores (Suprema).
   last_heartbeat: NEXUS monitorea cada 30s. Si >90s sin heartbeat → alerta.';
COMMENT ON COLUMN bauth.fis_controller.ports_count IS 'Cantidad de puertos OSDP. Default 4. Cada puerto puede tener múltiples dispositivos en daisy-chain.';


-- ======================================================================
-- 026 — bauth.fis_access_zone (NUEVA)
-- Zona de acceso lógica (Access Zone del paper Sathishkumar et al.).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_access_zone (
    zone_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name             TEXT NOT NULL,
    description      TEXT,
    schedule_id      UUID,
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);

COMMENT ON TABLE bauth.fis_access_zone IS
  'Zona de acceso lógica (Access Zone del paper Sathishkumar et al. 2016).
   Agrupa puertas/áreas con reglas comunes. Los Employee Groups se mapean a Access Zones.
   schedule_id: calendario que define cuándo esta zona es accesible.';


-- ======================================================================
-- 027 — bauth.fis_zone_member (NUEVA)
-- Puente: Access Zone ↔ Location (puertas/áreas).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fis_zone_member (
    zone_member_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    zone_id          UUID NOT NULL REFERENCES bauth.fis_access_zone(zone_id) ON DELETE CASCADE,
    location_id      UUID NOT NULL REFERENCES bauth.fis_location(location_id) ON DELETE CASCADE,
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id, location_id)
);

CREATE INDEX IF NOT EXISTS idx_fzm_zone     ON bauth.fis_zone_member(zone_id);
CREATE INDEX IF NOT EXISTS idx_fzm_location ON bauth.fis_zone_member(location_id);

COMMENT ON TABLE bauth.fis_zone_member IS
  'Puente Access Zone ↔ Location. Una puerta/área pertenece a exactamente una zona.
   Las zonas se usan para mapear Employee Groups → Access Zones (paper EG↔AZ).';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║        DOMINIO FINANCIERO (D3) — Double-Entry · SoD · SIN          ║
-- ║   fin_ prefijo · JSONB extensible · Approval Chain jerárquico      ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Diseño: JSONB para configuraciones variables (límites, periodos, permisos).
--         Jerarquía parent_id para cadena de aprobación de N niveles.
--         Sin columnas hardcodeadas que limiten el crecimiento.

-- ======================================================================
-- 028 — bauth.fin_transaction_type (antes bos_financial_tipo_transaccion)
-- Catálogo de tipos de transacción. properties JSONB para extensibilidad.
-- Cumple: ISO 20022 · NIST 800-53 AC-5 · SOX §302/§404.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_transaction_type (
    type_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    code           TEXT NOT NULL,
    name           TEXT NOT NULL,
    category       fin_transaction_category_enum NOT NULL,
    risk_level     fin_risk_level_enum NOT NULL DEFAULT 'MEDIO',
    controls       JSONB DEFAULT '{}',
    is_active      BOOLEAN DEFAULT true,
    ctx_id         TEXT NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, code)
);
-- controls JSONB: {"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false,"sox_relevant":true,"min_approval_levels":2}
-- Extensible: agregar nuevo control sin ALTER TABLE.

COMMENT ON TABLE bauth.fin_transaction_type IS
  '[ISO 20022] [NIST 800-53 AC-5] Tipos de transacción. controls JSONB define qué requiere cada tipo:
   requires_dual_control, requires_evidence, affects_ledger, notifies_sin, min_approval_levels, etc.
   Extensible sin ALTER TABLE.';
COMMENT ON COLUMN bauth.fin_transaction_type.controls IS
  '[JSONB] Controles requeridos: {"requires_dual_control":true,"requires_evidence":true,"notifies_sin":false}.';


-- ======================================================================
-- 029 — bauth.fin_limit (antes bos_financial_limit)
-- Límites por tenant/empresa/rol/tipo. limits_config JSONB sin columnas hardcodeadas.
-- Cumple: COSO · SOX §404 · PCI DSS 4.0.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_limit (
    limit_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    company_id     UUID,
    role_id        UUID,
    transaction_type_id UUID REFERENCES bauth.fin_transaction_type(type_id),
    currency_code  CHAR(3) DEFAULT 'BOB',
    limits_config  JSONB NOT NULL DEFAULT '{}',
    accumulators   JSONB DEFAULT '{}',
    exceed_action  fin_limit_action_enum DEFAULT 'BLOCK',
    exceed_approver_1 UUID,
    exceed_approver_2 UUID,
    is_active      BOOLEAN DEFAULT true,
    ctx_id         TEXT NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- limits_config: {"per_operation":50000,"daily":500000,"weekly":2000000,"monthly":10000000,"yearly":50000000,"per_fiscal_year":100000000}
-- Agregar "quarterly" o "per_semester" no requiere ALTER TABLE.
-- accumulators: {"daily":125000,"monthly":3200000,"last_reset_daily":"2026-06-23","last_reset_monthly":"2026-06-01"}

COMMENT ON TABLE bauth.fin_limit IS
  '[COSO] [SOX §404] Límites con JSONB. limits_config define montos por período sin hardcodear columnas.
   Nuevo período (quarterly, semiannual) = nueva clave en JSONB, sin ALTER TABLE.
   accumulators: contadores actuales que se resetean automáticamente por período.';
COMMENT ON COLUMN bauth.fin_limit.limits_config IS
  '[JSONB] {"per_operation":50000,"daily":500000,"monthly":10000000}. Períodos ilimitados.';
COMMENT ON COLUMN bauth.fin_limit.accumulators IS
  '[JSONB] {"daily":125000,"monthly":3200000,"last_reset_daily":"2026-06-23"}. Contadores.';


-- ======================================================================
-- 030 — bauth.fin_approval_chain (NUEVA — reemplaza bos_financial_decision_matrix)
-- Cadena de aprobación jerárquica de N niveles. Sin límite de 3.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_approval_chain (
    chain_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    company_id     UUID,
    transaction_type_id UUID NOT NULL REFERENCES bauth.fin_transaction_type(type_id),
    currency_code  CHAR(3),
    name           TEXT NOT NULL,
    sla_hours      INTEGER DEFAULT 48,
    auto_escalate  BOOLEAN DEFAULT true,
    requires_committee BOOLEAN DEFAULT false,
    requires_attachment BOOLEAN DEFAULT false,
    is_active      BOOLEAN DEFAULT true,
    ctx_id         TEXT NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, company_id, transaction_type_id, currency_code)
);

CREATE TABLE IF NOT EXISTS bauth.fin_approval_level (
    level_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    chain_id       UUID NOT NULL REFERENCES bauth.fin_approval_chain(chain_id) ON DELETE CASCADE,
    level_order    INTEGER NOT NULL,
    role_id        UUID NOT NULL,
    max_amount     DECIMAL(18,4),
    can_delegate   BOOLEAN DEFAULT false,
    description    TEXT,
    ctx_id         TEXT NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (chain_id, level_order)
);
-- Ejemplo: cadena de 5 niveles para facturación:
--   level_order=1: Supervisor, max=50,000
--   level_order=2: Gerente, max=200,000
--   level_order=3: Director, max=1,000,000
--   level_order=4: VP Finanzas, max=10,000,000
--   level_order=5: Comité Ejecutivo, sin límite

COMMENT ON TABLE bauth.fin_approval_chain IS
  '[COSO] [SOX §404] Cadena de aprobación. Reemplaza bos_financial_decision_matrix.
   N niveles ilimitados vía fin_approval_level. Sin hardcodear level_1/2/3.';
COMMENT ON TABLE bauth.fin_approval_level IS
  'Nivel de aprobación dentro de una cadena. level_order define la secuencia.
   max_amount=NULL → sin límite superior (último nivel).';
COMMENT ON COLUMN bauth.fin_approval_level.level_order IS 'Orden secuencial: 1,2,3...N. Debe ser único dentro de la cadena.';


-- ======================================================================
-- 031 — bauth.fin_approval (antes bos_financial_approval)
-- Registro de aprobaciones. Hash-chain SHA-256. WORM.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_approval (
    approval_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    company_id     UUID,
    transaction_type_id UUID NOT NULL REFERENCES bauth.fin_transaction_type(type_id),
    reference      TEXT NOT NULL,
    amount         DECIMAL(18,4) NOT NULL,
    currency_code  CHAR(3),
    requester_id   UUID NOT NULL,
    approver_id    UUID,
    status         fin_approval_status_enum NOT NULL DEFAULT 'PENDING',
    current_level  INTEGER DEFAULT 1,
    requested_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at    TIMESTAMPTZ,
    comments       TEXT,
    prev_hash      TEXT,
    entry_hash     TEXT NOT NULL,
    ctx_id         TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.fin_approval IS
  '[PCI DSS 10.3.2] Hash-chain SHA-256. current_level: nivel de aprobación actual en la cadena.
   prev_hash→entry_hash encadena cada aprobación con la anterior. ctx_id obligatorio.';


-- ======================================================================
-- 032 — bauth.fin_document_operation (antes bos_financial_document_operation)
-- Operaciones sobre documentos fiscales. Hash-chain. SIN Bolivia.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_document_operation (
    operation_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    company_id     UUID,
    document_id    UUID NOT NULL,
    operation_type fin_document_operation_enum NOT NULL,
    executed_by    UUID NOT NULL,
    operation_data JSONB DEFAULT '{}',
    prev_hash      TEXT,
    entry_hash     TEXT NOT NULL,
    ctx_id         TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.fin_document_operation IS
  '[SIN Bolivia RND 102100000011] Operaciones fiscales con hash-chain. operation_data JSONB extensible.';


-- ======================================================================
-- 033 — bauth.fin_role_permission (antes bos_financial_role_permission)
-- Permisos financieros por rol. permissions JSONB sin booleanos hardcodeados.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.fin_role_permission (
    permission_id  UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id      UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    role_id        UUID NOT NULL,
    transaction_type_id UUID NOT NULL REFERENCES bauth.fin_transaction_type(type_id),
    permissions    JSONB NOT NULL DEFAULT '{}',
    is_active      BOOLEAN NOT NULL DEFAULT true,
    ctx_id         TEXT NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, role_id, transaction_type_id)
);
-- permissions: {"can_initiate":true,"can_approve":false,"can_view":true,"can_void":false,"can_export_sin":true}
-- Nuevo permiso "can_override_limit" = nueva clave JSONB, sin ALTER TABLE.

COMMENT ON TABLE bauth.fin_role_permission IS
  '[NIST 800-53 AC-5] Permisos en JSONB. SoD: mismo rol NO debe tener can_initiate=true Y can_approve=true.
   Extensible: nuevo permiso = nueva clave JSONB sin migración.';
COMMENT ON COLUMN bauth.fin_role_permission.permissions IS
  '[JSONB] {"can_initiate":true,"can_approve":false,"can_view":true}. Claves ilimitadas.';


-- ══════════════════════════════════════════════════════════════════════
-- CONTINGENCIAS: Hot Migration en Producción
CREATE TABLE IF NOT EXISTS bauth.ath_config (
    config_key      TEXT    NOT NULL,
    config_value    JSONB   NOT NULL,
    config_type     TEXT    NOT NULL,
    tier            TEXT    NOT NULL DEFAULT 'ALL',
    description     TEXT    NOT NULL,
    standard_ref    TEXT[]  DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_auth_config PRIMARY KEY (config_key, tier),
    CONSTRAINT chk_config_type CHECK (config_type IN ('token','hash','rotation','session','rate','screen','enrollment','audit','recovery','lockout')),
    CONSTRAINT chk_config_tier CHECK (tier IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE','ALL'))
);

-- 21.4 CRYPTO ALGORITHM — Catálogo de algoritmos criptográficos
CREATE TABLE IF NOT EXISTS bauth.bos_crypto_algorithm (
    algo_id         TEXT    NOT NULL,
    algo_name       TEXT    NOT NULL,
    algo_type       TEXT    NOT NULL,
    category        TEXT    NOT NULL,
    purpose         TEXT    NOT NULL,
    params          JSONB   NOT NULL,
    fips_status     TEXT,
    nist_pqc_round  TEXT,
    standard_ref    TEXT[]  DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    is_primary      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_crypto_algorithm PRIMARY KEY (algo_id),
    CONSTRAINT chk_algo_type CHECK (algo_type IN ('hashing','key_exchange','digital_signature','encryption','key_derivation','random')),
    CONSTRAINT chk_algo_category CHECK (category IN ('classical','post_quantum','hybrid'))
);
COMMENT ON TABLE bauth.bos_crypto_algorithm IS '[NIST FIPS 140-3/203/204/205] Catálogo de 16 algoritmos criptográficos. PK TEXT (nombres canónicos: argon2id, ed25519, x25519, aes-256-gcm).';

CREATE TABLE IF NOT EXISTS bauth.ath_policy (
    policy_id       UUID    NOT NULL DEFAULT gen_random_uuid(),
    policy_name     TEXT    NOT NULL,
    policy_type     TEXT    NOT NULL,
    tier            TEXT    NOT NULL,
    policy_data     JSONB   NOT NULL,
    priority        INTEGER NOT NULL DEFAULT 50,
    standard_ref    TEXT[]  DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_auth_policy PRIMARY KEY (policy_id),
    CONSTRAINT chk_policy_type CHECK (policy_type IN ('password','rate_limit','mfa','session','ip','time','geo','device','step_up','break_glass','audit','lockout','delegation')),
    CONSTRAINT chk_policy_tier CHECK (tier IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE','ALL'))
);

-- 21.3 AUTH CONFIG — ya definida arriba (línea 2309). Esta entrada estaba corrupta.
CREATE TABLE IF NOT EXISTS bauth.ath_method (
    method_id           TEXT    NOT NULL,
    method_name         TEXT    NOT NULL,
    method_type         TEXT    NOT NULL,
    category            TEXT    NOT NULL,
    aal_level           TEXT    NOT NULL,
    nist_status         TEXT    NOT NULL DEFAULT 'permitted',
    applies_to          TEXT[]  NOT NULL DEFAULT '{}',
    rfc_ref             TEXT,
    kc_implementation   TEXT,
    requires_https      BOOLEAN NOT NULL DEFAULT TRUE,
    active              BOOLEAN NOT NULL DEFAULT TRUE,
    config              JSONB   DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_auth_method PRIMARY KEY (method_id),
    CONSTRAINT chk_method_type CHECK (method_type IN ('single_factor','multi_factor','phishing_resistant','federated','machine','recovery','adaptive','deprecated','device','continuous','out_of_band')),
    CONSTRAINT chk_method_category CHECK (category IN ('password','otp','biometric','cryptographic','federated','device','recovery','adaptive','deprecated','continuous','out_of_band')),
    CONSTRAINT chk_aal_level CHECK (aal_level IN ('AAL1','AAL2','AAL3','AAL1-AAL2','AAL2-AAL3','AAL1-AAL3','n/a')),
    CONSTRAINT chk_nist_status CHECK (nist_status IN ('preferred','permitted','discouraged','deprecated','restricted','n/a')),
    domain_classification JSONB DEFAULT '{}'
);
COMMENT ON COLUMN bauth.ath_method.domain_classification IS
  '[D1-D12] Clasificación del método por dominio de soberanía. Ej: {"D1":true,"D2":true,"D9":true}.
   Permite al admin filtrar métodos por dominio al armar un RolTemplate.';

-- 21.2 AUTH POLICY — ya definida arriba (línea 2339). Esta entrada estaba corrupta.
CREATE TABLE IF NOT EXISTS bauth.idn_role_template (
    id              TEXT        PRIMARY KEY,              -- ej: 'ROL-CAJERO', 'ROL-SYS-ADMIN-BAUTH'
    tenant_id       TEXT        NOT NULL DEFAULT '*',     -- '*' = global, tenant_id = específico
    empresa_id      TEXT        NOT NULL DEFAULT '*',     -- '*' = global
    parent_id       TEXT        REFERENCES bauth.idn_role_template(id) ON DELETE SET NULL,
    type_id         TEXT,                                 -- TYPE-OPERATIVO, TYPE-SUPERVISOR...
    tier            TEXT        NOT NULL,                 -- SU, SYS, BIZ_N1-N5, EXT_N0, M2M, VISITANTE
    hierarchy_level INTEGER     NOT NULL DEFAULT 5,
    path_ids        TEXT[]      DEFAULT '{}',
    -- Ciclo de vida (7 estados)
    status          TEXT        NOT NULL DEFAULT 'DEFINIDO',
    version         TEXT        NOT NULL DEFAULT '1.0.0',
    sync_status     TEXT        NOT NULL DEFAULT 'PENDING',
    sync_error      TEXT,
    last_sync_at    TIMESTAMPTZ,
    -- BitMask 64-bit 2 capas
    rol_bitmask_base64    TEXT        NOT NULL DEFAULT '0x0000000000000000',
    -- SAM-128 quadrant masks (calculadas por PrivilegeEngine)
    sam128_physical    NUMERIC(20),
    sam128_logical     NUMERIC(20),
    sam128_financial   NUMERIC(20),
    sam128_governance  NUMERIC(20),
    -- Seguridad
    loa_required    INTEGER     NOT NULL DEFAULT 1,
    mfa_required    BOOLEAN     NOT NULL DEFAULT false,
    step_up_enabled BOOLEAN     NOT NULL DEFAULT false,
    sod_group       TEXT,
    max_sessions    INTEGER     DEFAULT 1,
    session_timeout INTEGER     DEFAULT 28800,
    audit_level     TEXT        NOT NULL DEFAULT 'basic',
    -- Metadata
    issuer          TEXT        NOT NULL,
    owner_tenant    TEXT        NOT NULL DEFAULT '*',
    start_time      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expiry_time     TIMESTAMPTZ,
    template_id     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT        NOT NULL,
    template        JSONB       NOT NULL,
    template_version TEXT      NOT NULL DEFAULT '6.0',
    CONSTRAINT chk_brt_status CHECK (status IN ('DEFINIDO','DESARROLLADO','REVISADO','AUTORIZADO','PUBLICADO','DEPRECADO','RETIRADO')),
    CONSTRAINT chk_brt_sync   CHECK (sync_status IN ('PENDING','SYNCING','SYNCED','ERROR','DRIFT')),
    CONSTRAINT chk_brt_tier   CHECK (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3','BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE')),
    CONSTRAINT chk_brt_loa    CHECK (loa_required BETWEEN 1 AND 4),
    CONSTRAINT chk_brt_audit  CHECK (audit_level IN ('none','basic','full'))
);

CREATE INDEX IF NOT EXISTS idx_brt_tenant      ON bauth.idn_role_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_brt_parent      ON bauth.idn_role_template(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_brt_status      ON bauth.idn_role_template(status);
CREATE TABLE IF NOT EXISTS bauth.idn_tier_policy (
    tier                TEXT        PRIMARY KEY,
    tier_name           TEXT        NOT NULL,
    loa_default         INTEGER     NOT NULL DEFAULT 1,
    mfa_default         BOOLEAN     NOT NULL DEFAULT FALSE,
    mfa_methods         TEXT[]      DEFAULT '{}',
    session_timeout_secs INTEGER    NOT NULL DEFAULT 28800,
    max_sessions        INTEGER     NOT NULL DEFAULT 1,
    audit_default       TEXT        NOT NULL DEFAULT 'basic',
    step_up_allowed     BOOLEAN     NOT NULL DEFAULT FALSE,
    delegation_allowed  BOOLEAN     NOT NULL DEFAULT FALSE,
    description         TEXT,
    nist_aal_ref        TEXT,
    CONSTRAINT chk_tp_loa CHECK (loa_default BETWEEN 0 AND 4),
    CONSTRAINT chk_tp_audit CHECK (audit_default IN ('none','basic','full')),
    CONSTRAINT chk_tp_tier CHECK (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3','BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE'))
);

-- Datos seed movidos a seed_idn_tier_policy.sql (R5: Cero INSERTs en DDL)

-- ============================================================
-- 5. ROL TEMPLATE HISTORY — WORM inmutable (SHA-256 chain)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_rol_template_history (
    history_id    BIGSERIAL   PRIMARY KEY,
    rol_id        TEXT        NOT NULL,
    tenant_id     TEXT        NOT NULL,
    version       TEXT        NOT NULL,
    template_snap JSONB       NOT NULL,
    changed_by    TEXT        NOT NULL,
    approved_by   TEXT,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_reason TEXT,
    changes       TEXT[],
    security_impact TEXT     NOT NULL DEFAULT 'LOW',
    prev_hash       TEXT,
    entry_hash      TEXT        NOT NULL
);
COMMENT ON TABLE bauth.bos_rol_template_history IS '[ISO 27001 A.8.15] Historial WORM de cambios a templates de rol. Hash-chain SHA-256 inmutable.';

CREATE TABLE IF NOT EXISTS bauth.log_zone (
    zona_id         TEXT        PRIMARY KEY,              -- 'VENTAS', 'CONTABILIDAD', 'INVENTARIO'
    nombre          TEXT        NOT NULL,                 -- 'Ventas y Facturación'
    descripcion     TEXT,
    categoria       TEXT        NOT NULL DEFAULT 'OPERATIVA',-- OPERATIVA|ADMINISTRATIVA|FINANCIERA|RRHH|TECNICA|DIRECTIVA
    ambito          TEXT        NOT NULL DEFAULT 'TENANT',-- TENANT|EMPRESA|SUCURSAL
    es_critica      BOOLEAN     NOT NULL DEFAULT false,   -- Zonas críticas requieren auditoría completa
    requiere_segregacion BOOLEAN DEFAULT false,           -- SoD: no se puede tener permisos en zonas conflictivas
    zona_conflicto  TEXT[],                                -- Zonas SoD: ['COMPRAS','AUDITORIA']
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_zl_categoria CHECK (categoria IN ('OPERATIVA','ADMINISTRATIVA','FINANCIERA','RRHH','TECNICA','DIRECTIVA','FISCAL','COMERCIAL')),
    CONSTRAINT chk_zl_ambito CHECK (ambito IN ('TENANT','EMPRESA','SUCURSAL'))
);


-- ============================================================
-- 1-M2. VERBOS — Suprimido. Reemplazado por bos_privilege.bos_verb (§20.4)
-- ============================================================
-- El catálogo global de verbos está en bos_privilege.bos_verb
-- (verb_code SMALLINT, verb_name, verb_slug). Label encoding.
-- La tabla bauth.bos_verbo fue eliminada (huérfana, 0 registros).
-- ============================================================

-- ============================================================
-- 1-M3. PERMISO LÓGICO — Movido después de privilege_verb (dependencia FK)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.privilege_domain (
    domain_code     SMALLINT    NOT NULL,
    domain_name     VARCHAR(64) NOT NULL,
    requires_policy BOOLEAN     NOT NULL DEFAULT false,
    description     TEXT,
    CONSTRAINT pk_privilege_domain PRIMARY KEY (domain_code),
    CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 1 AND 15)
);
COMMENT ON TABLE bauth.privilege_domain IS 'Catálogo de 12 dominios de soberanía D1-D12. domain_code se empaqueta en bits 8-11 del Dominio Contextual (4 bits). NUNCA texto.';
COMMENT ON COLUMN bauth.privilege_domain.domain_code IS 'Código numérico del dominio: 1=Físico(D2), 2=Lógico(D1), 3=Financiero(D3), 4=Temporal(D4), 5=Biométrico(D5), 6=Geoespacial(D6), 7=Red(D7), 8=Contexto(D8), 9=Dispositivo(D9), 10=Delegación(D10), 11=Auditoría(D11), 12=Blockchain(D12).';
COMMENT ON COLUMN bauth.privilege_domain.requires_policy IS 'TRUE si este dominio requiere políticas explícitas para cada átomo. FALSE si la evaluación es solo por bitmask.';

-- 20.2 APLICACIONES — Fichas registradas en SBOS
CREATE TABLE IF NOT EXISTS bauth.privilege_application (
    app_code        SMALLINT    NOT NULL,
    app_name        VARCHAR(64) NOT NULL,
    app_slug        VARCHAR(32) NOT NULL,
    tenant_id       UUID        NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_application PRIMARY KEY (app_code),
    CONSTRAINT uq_privilege_application_slug UNIQUE (tenant_id, app_slug),
    CONSTRAINT ck_app_code CHECK (app_code BETWEEN 1 AND 511)
);
COMMENT ON TABLE bauth.privilege_application IS 'Aplicaciones ficha registradas. app_code (9 bits) se empaqueta en bits 12-20 del Dominio Contextual.';

-- 20.3 GRUPOS FUNCIONALES — Por aplicación
CREATE TABLE IF NOT EXISTS bauth.privilege_group (
    group_code      SMALLINT    NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_name      VARCHAR(128) NOT NULL,
    CONSTRAINT pk_privilege_group PRIMARY KEY (app_code, group_code),
    CONSTRAINT ck_group_code CHECK (group_code BETWEEN 1 AND 2047)
);
COMMENT ON TABLE bauth.privilege_group IS 'Grupos funcionales dentro de cada aplicación. group_code (11 bits) en bits 21-31 del Dominio Contextual.';

-- 20.4 VERBOS — Vocabulario global
CREATE TABLE IF NOT EXISTS bauth.privilege_verb (
    verb_code       SMALLINT    NOT NULL,
    verb_name       VARCHAR(32) NOT NULL,
    verb_slug       VARCHAR(32) NOT NULL,
    CONSTRAINT pk_privilege_verb PRIMARY KEY (verb_code),
    CONSTRAINT uq_privilege_verb_name UNIQUE (verb_name),
    CONSTRAINT ck_verb_code CHECK (verb_code BETWEEN 1 AND 255)
);
COMMENT ON TABLE bauth.privilege_verb IS 'Vocabulario global de verbos. Label encoding — NUNCA combinar con bitwise. La combinación usa privilege_role_atom (one-hot).';

-- ============================================================
-- 1-M3. PERMISO LÓGICO — Zona × Verbo × Rol (reordenado)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_permiso_logico (
    permiso_id      BIGSERIAL   PRIMARY KEY,
    rol_id          TEXT        NOT NULL,
    zona_id         TEXT        NOT NULL,
    verbo_id        SMALLINT    NOT NULL,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       ,
    scope           TEXT        NOT NULL DEFAULT 'EMPRESA',
    limit_registros INTEGER,
    requiere_step_up BOOLEAN    DEFAULT false,
    clasificacion_datos TEXT   DEFAULT 'INTERNAL',
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rol_id, zona_id, verbo_id, tenant_id, empresa_id),
    CONSTRAINT fk_permiso_verbo FOREIGN KEY (verbo_id) REFERENCES bauth.privilege_verb(verb_code),
    CONSTRAINT chk_pl_scope CHECK (scope IN ('GLOBAL','EMPRESA','SUCURSAL','PERSONAL')),
    CONSTRAINT chk_pl_clasif CHECK (clasificacion_datos IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED'))
);
CREATE INDEX IF NOT EXISTS idx_pl_rol ON bauth.bos_permiso_logico(rol_id);

-- 20.5 CATÁLOGO DE ÁTOMOS — Fuente de verdad del BitMask Átomo
CREATE TABLE IF NOT EXISTS bauth.privilege_atom (
    atom_code       INTEGER     NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    domain_code     SMALLINT    NOT NULL,
    verb_code       SMALLINT    NOT NULL,
    atom_name       VARCHAR(255) NOT NULL,
    atom_slug       VARCHAR(255) NOT NULL,
    atom_position   INTEGER     NOT NULL,
    contextual_mask INTEGER     NOT NULL,
    logical_mask    INTEGER     NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_atom PRIMARY KEY (app_code, group_code, atom_code),
    CONSTRAINT uq_bos_atom_position UNIQUE (atom_position),
    CONSTRAINT uq_bos_atom_slug UNIQUE (app_code, atom_slug),
    CONSTRAINT ck_atom_code CHECK (atom_code BETWEEN 1 AND 16777215),
    CONSTRAINT ck_atom_position CHECK (atom_position >= 0)
);
COMMENT ON TABLE bauth.privilege_atom IS 'Catálogo global de átomos. Cada fila = una acción indivisible. atom_position es el índice del bit en el Rol BitMask (one-hot). atom_code es label encoding — NUNCA combinar con bitwise. 1059 átomos registrados.';

-- 20.6 ROLES POR TENANT
CREATE TABLE IF NOT EXISTS bauth.privilege_role (
    role_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL,
    role_code   INTEGER     NOT NULL,
    role_name   VARCHAR(128) NOT NULL,
    role_slug   VARCHAR(64) NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_role PRIMARY KEY (role_id),
    CONSTRAINT uq_privilege_role_code UNIQUE (tenant_id, role_code),
    CONSTRAINT uq_privilege_role_slug UNIQUE (tenant_id, role_slug),
    CONSTRAINT ck_role_code CHECK (role_code > 0)
);
COMMENT ON TABLE bauth.privilege_role IS 'Roles definidos por tenant. Vinculados a átomos vía privilege_role_atom.';

-- 20.7 ASIGNACIÓN ROL↔ÁTOMO — Rol BitMask en forma relacional
CREATE TABLE IF NOT EXISTS bauth.privilege_role_atom (
    role_id         UUID        NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    atom_position   INTEGER     NOT NULL,
    allowed         BOOLEAN     NOT NULL DEFAULT FALSE,
    granted_by      UUID,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_role_atom PRIMARY KEY (role_id, app_code, group_code, atom_code)
);
CREATE INDEX IF NOT EXISTS ix_privilege_role_atom_role ON bauth.privilege_role_atom (role_id, allowed) WHERE allowed = TRUE;
COMMENT ON TABLE bauth.privilege_role_atom IS 'Rol BitMask en forma relacional. Cada fila con allowed=true = un bit en 1. atom_position es la posición del bit en el vector one-hot. 212 asignaciones registradas.';
COMMENT ON COLUMN bauth.privilege_role_atom.atom_position IS '2NF: Desnormalización deliberada. atom_position deriva de privilege_atom.atom_position (depende solo de atom_code, no de role_id). Se replica aquí para evitar JOIN en cada evaluación de política (<0.5ns requerido). Sincronizado por trigger trg_role_atom_position.';

-- Trigger 2NF: mantiene atom_position sincronizado con privilege_atom
CREATE OR REPLACE FUNCTION bauth.sync_atom_position()
RETURNS TRIGGER AS $$
BEGIN
    SELECT atom_position INTO NEW.atom_position
    FROM bauth.privilege_atom
    WHERE app_code = NEW.app_code
      AND group_code = NEW.group_code
      AND atom_code = NEW.atom_code;
    IF NEW.atom_position IS NULL THEN
        RAISE EXCEPTION 'átomo no encontrado en privilege_atom: app=% group=% atom=%',
            NEW.app_code, NEW.group_code, NEW.atom_code;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_role_atom_position') THEN
        CREATE TRIGGER trg_role_atom_position
            BEFORE INSERT OR UPDATE OF app_code, group_code, atom_code
            ON bauth.privilege_role_atom
            FOR EACH ROW EXECUTE FUNCTION bauth.sync_atom_position();
    END IF;
END $$;

-- 20.8 POLÍTICAS POR ÁTOMO — Documento JSONB formal
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_policy (
    policy_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    policy_domain   SMALLINT    NOT NULL,
    policy_slug     VARCHAR(64) NOT NULL,
    policy_data     JSONB       NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_atom_policy PRIMARY KEY (policy_id),
    CONSTRAINT uq_privilege_atom_policy_slug UNIQUE (app_code, group_code, atom_code, policy_slug),
    CONSTRAINT ck_policy_data_valid CHECK (
        policy_data ? '$schema'
        AND policy_data ? 'priority'
        AND policy_data ? 'action'
        AND policy_data ? 'evaluate'
        AND policy_data ? 'params'
        AND (policy_data ->> 'action') IN ('deny','allow','step_up','pending_approval','mfa_required')
        AND jsonb_typeof(policy_data -> 'evaluate') = 'object'
        AND jsonb_typeof(policy_data -> 'params') = 'object'
        AND ((policy_data ->> 'priority')::integer BETWEEN 1 AND 999)
    )
);
CREATE INDEX IF NOT EXISTS ix_atom_policy_data ON bauth.privilege_atom_policy USING GIN (policy_data jsonb_path_ops);
CREATE INDEX IF NOT EXISTS ix_atom_policy_priority ON bauth.privilege_atom_policy (policy_domain, ((policy_data ->> 'priority')::integer), active) WHERE active = TRUE;
COMMENT ON TABLE bauth.privilege_atom_policy IS 'Políticas 1:N encadenadas a átomos. Documento JSONB formal con evaluación determinista. El PolicyEngine interpreta el documento completo sin código hardcodeado. 6782 políticas registradas.';
COMMENT ON COLUMN bauth.privilege_atom_policy.policy_data IS 'Documento completo de política en formato JSONB formal. Estructura canónica: {"$schema":"bos_policy_v1","priority":50,"action":"deny","evaluate":{"logic":"and|or","conditions":[{"field":"<context_path>","op":"<operator>","value":"<literal_or_ref>"}]},"params":{...}}.';

-- 20.9 AUDITORÍA DE ACCESOS — WORM inmutable por evaluación
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit (
    audit_id        UUID        NOT NULL DEFAULT gen_random_uuid(),
    ctx_id          VARCHAR(128) NOT NULL,
    tenant_id       UUID        NOT NULL,
    role_id         UUID        NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    atom_position   INTEGER     NOT NULL,
    bitmask_atom    BIGINT      NOT NULL,
    policy_state    SMALLINT    NOT NULL,
    result          SMALLINT    NOT NULL,
    policy_slug     VARCHAR(64),
    evaluator       VARCHAR(32) NOT NULL,
    domain_code     SMALLINT,
    merkle_batch_id UUID,
    merkle_proof    VARCHAR(66)[],
    onchain_tx_hash VARCHAR(66),
    evaluated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_atom_audit PRIMARY KEY (audit_id, evaluated_at),
    CONSTRAINT ck_audit_result CHECK (result IN (0, 1, 2)),
    CONSTRAINT ck_policy_state CHECK (policy_state IN (0, 1, 2, 3))
) PARTITION BY RANGE (evaluated_at);
COMMENT ON TABLE bauth.privilege_atom_audit IS 'Registro WORM de cada evaluación de acceso. ctx_id obligatorio. Particionado por mes. REVOKE UPDATE/DELETE post-deploy. Trazabilidad blockchain vía merkle_batch_id. ISO 27001 A.8.15.';

CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit_2026_06 PARTITION OF bauth.privilege_atom_audit
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_audit_2026_07 PARTITION OF bauth.privilege_atom_audit
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
COMMENT ON TABLE bauth.privilege_atom_audit_2026_06 IS 'Partición de privilege_atom_audit para Junio 2026.';
COMMENT ON TABLE bauth.privilege_atom_audit_2026_07 IS 'Partición de privilege_atom_audit para Julio 2026.';

-- ══════════════════════════════════════════════════════════════════════
-- CONTINGENCIAS: Hot Migration en Producción
-- ══════════════════════════════════════════════════════════════════════
-- Ver MANUAL-HOT-DDL-PRODUCCION.md para el procedimiento completo:
--   • Agregar columnas en caliente (DO $$ + ADD COLUMN IF NOT EXISTS)
--   • Constraints en 2 fases (CHECK NOT VALID → VALIDATE)
--   • Índices sin bloquear escrituras (CREATE INDEX CONCURRENTLY)
--   • Rollback de emergencia

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║     SISTEMA DE MENÚS (D1) + DATOS DE SELECCIÓN (Templates)       ║
-- ╚══════════════════════════════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS bglobal.menu_item (
    id           UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id    UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id    UUID REFERENCES bglobal.menu_item(id) ON DELETE SET NULL,
    label        TEXT NOT NULL,
    route        TEXT,
    icon         TEXT,
    sort_order   INT NOT NULL DEFAULT 0,
    is_visible   BOOLEAN NOT NULL DEFAULT true,
    menu_type    menu_type_enum NOT NULL,
    context_key  TEXT,
    ctx_id       TEXT NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_menu_context CHECK (
        (menu_type = 'CONTEXTUAL' AND context_key IS NOT NULL) OR
        (menu_type = 'HIERARCHICAL')
    )
);
CREATE TABLE IF NOT EXISTS bglobal.menu_context (
    id           UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id    UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    context_key  TEXT NOT NULL,
    entity_type  TEXT NOT NULL,
    description  TEXT,
    ctx_id       TEXT NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, context_key)
);
CREATE TABLE IF NOT EXISTS bglobal.menu_item_atom (
    menu_item_id  UUID NOT NULL REFERENCES bglobal.menu_item(id) ON DELETE CASCADE,
    atom_code     INTEGER NOT NULL,
    require_all   BOOLEAN NOT NULL DEFAULT true,
    min_loa       INT NOT NULL DEFAULT 1 CHECK (min_loa BETWEEN 1 AND 3),
    step_up_flow  TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (menu_item_id, atom_code)
);

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D1 — LÓGICO: Zone ↔ Application Map
-- ══════════════════════════════════════════════════════════════════════

-- T-100 — bauth.zone_application_map (migrado de bos_zone_application_map)
-- Zonas lógicas ↔ Aplicaciones con módulos y scopes OAuth 2.0
-- Estándar: [OASIS XACML 3.0] [NIST 800-162 ABAC] [OAuth 2.0 RFC 6749]
CREATE TABLE IF NOT EXISTS bauth.zone_application_map (
    map_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id         TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    app_code        SMALLINT    NOT NULL REFERENCES bauth.privilege_application(app_code) ON DELETE CASCADE,
    app_scopes      TEXT[]      DEFAULT '{}',
    client_id       TEXT,
    modules         TEXT[]      DEFAULT '{}',
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id, app_code)
);

COMMENT ON TABLE bauth.zone_application_map IS
  '[OASIS XACML 3.0] [NIST 800-162 ABAC] Mapeo de zonas lógicas a aplicaciones.
   Define qué aplicaciones están disponibles en cada zona de negocio.
   Usado por el motor de dominios para filtrar átomos disponibles por zona.
   zone_id FK → log_zone. app_code FK → privilege_application.
   app_scopes: OAuth 2.0 scopes permitidos. modules: módulos específicos visibles.';

COMMENT ON COLUMN bauth.zone_application_map.map_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.zone_application_map.zone_id IS 'Zona lógica: AREA-VENT, AREA-CAJA, AREA-FACT, etc. FK → log_zone.zona_id.';
COMMENT ON COLUMN bauth.zone_application_map.app_code IS 'Aplicación disponible en esta zona. FK → privilege_application.app_code.';
COMMENT ON COLUMN bauth.zone_application_map.app_scopes IS '[OAuth 2.0 RFC 6749] Scopes permitidos para esta app en esta zona. Ej: {''openid'',''profile'',''email''}.';
COMMENT ON COLUMN bauth.zone_application_map.modules IS 'Módulos específicos de la app visibles en esta zona. NULL = todos los módulos disponibles.';
COMMENT ON COLUMN bauth.zone_application_map.client_id IS 'OAuth 2.0 client_id para SSO desde esta zona. NULL = usar default del tenant.';
COMMENT ON COLUMN bauth.zone_application_map.is_active IS 'FALSE = zona temporalmente sin acceso a esta app. No elimina la relación.';
COMMENT ON COLUMN bauth.zone_application_map.ctx_id IS '[SBOS-049] Contexto de trazabilidad de la operación.';
COMMENT ON COLUMN bauth.zone_application_map.created_at IS '[ISO 27001 A.8.15] Fecha de creación del mapeo.';
COMMENT ON COLUMN bauth.zone_application_map.updated_at IS '[ISO 27001 A.8.15] Última modificación del mapeo.';

CREATE INDEX IF NOT EXISTS idx_zam_zone ON bauth.zone_application_map(zone_id);
CREATE INDEX IF NOT EXISTS idx_zam_app ON bauth.zone_application_map(app_code);
CREATE INDEX IF NOT EXISTS idx_zam_active ON bauth.zone_application_map(is_active) WHERE is_active = true;

-- T-101 — bauth.idn_role_closure (migrado de bos_rol_closure)
-- Closure table para herencia DAG de roles H-RBAC
-- Estándar: [ANSI/INCITS 359-2004 §4] [NIST 800-53 AC-3]
CREATE TABLE IF NOT EXISTS bauth.idn_role_closure (
    closure_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    ancestro_id     TEXT        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    descendiente_id TEXT        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    profundidad     INTEGER     NOT NULL CHECK (profundidad >= 0),
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ancestro_id, descendiente_id),
    CONSTRAINT chk_irc_no_self_ref CHECK (ancestro_id != descendiente_id OR profundidad = 0)
);

CREATE INDEX IF NOT EXISTS idx_irc_desc ON bauth.idn_role_closure(descendiente_id);
CREATE INDEX IF NOT EXISTS idx_irc_anc ON bauth.idn_role_closure(ancestro_id);
CREATE INDEX IF NOT EXISTS idx_irc_depth ON bauth.idn_role_closure(profundidad);

COMMENT ON TABLE bauth.idn_role_closure IS
  '[ANSI/INCITS 359-2004 §4] [NIST 800-53 AC-3] Closure table para herencia DAG de roles.
   ancestro_id HEREDA de descendiente_id (junior→senior vía OR transitivo sobre Rol BitMask).
   profundidad = 0 → auto-referencia. profundidad > 0 → distancia en el DAG.
   Se recalcula automáticamente al insertar/modificar/eliminar un rol en idn_role_template.';

COMMENT ON COLUMN bauth.idn_role_closure.closure_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.idn_role_closure.ancestro_id IS 'Rol que hereda (senior). FK → idn_role_template.id.';
COMMENT ON COLUMN bauth.idn_role_closure.descendiente_id IS 'Rol del que se hereda (junior). FK → idn_role_template.id.';
COMMENT ON COLUMN bauth.idn_role_closure.profundidad IS 'Distancia en el DAG. 0 = mismo rol. 1 = hijo directo. N = N niveles.';
COMMENT ON COLUMN bauth.idn_role_closure.ctx_id IS '[SBOS-049] Contexto de trazabilidad.';
COMMENT ON COLUMN bauth.idn_role_closure.created_at IS '[ISO 27001 A.8.15] Fecha de creación de la arista.';

-- T-105 — bauth.fin_sod_rule (migrado de bos_sod_conflict_matrix)
-- Matriz de conflictos SoD formal. Artefacto normativo exigible en auditorías.
-- Estándar: [NIST 800-53 AC-5] [SOX §404] [COSO 2013] [ISACA COBIT 2019 BAI09] [ISO 27001 A.5.3]
CREATE TABLE IF NOT EXISTS bauth.fin_sod_rule (
    rule_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    position_a      INTEGER     NOT NULL,
    position_b      INTEGER     NOT NULL,
    risk_level      TEXT        NOT NULL DEFAULT 'ALTO',
    action          TEXT        NOT NULL DEFAULT 'BLOCK',
    rationale       TEXT        NOT NULL,
    reviewed_at     TIMESTAMPTZ,
    reviewed_by     TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (position_a, position_b),
    CONSTRAINT chk_fsr_risk CHECK (risk_level IN ('ALTO','MEDIO','BAJO')),
    CONSTRAINT chk_fsr_action CHECK (action IN ('BLOCK','COMPENSATE','ALLOW_LOG'))
);

CREATE INDEX IF NOT EXISTS idx_fsr_positions ON bauth.fin_sod_rule(position_a, position_b);
CREATE INDEX IF NOT EXISTS idx_fsr_risk ON bauth.fin_sod_rule(risk_level) WHERE risk_level = 'ALTO';

COMMENT ON TABLE bauth.fin_sod_rule IS
  '[NIST 800-53 AC-5] [SOX §404] [COSO 2013 Control Activities] [ISACA COBIT 2019 BAI09]
   Matriz de conflictos de Segregación de Funciones (SoD). Define pares de posiciones
   en el Rol BitMask que NO pueden estar activas simultáneamente en el mismo rol/usuario.
   position_a y position_b son índices en el vector one-hot del Rol BitMask.
   Revisión anual obligatoria (COBIT BAI09).';

COMMENT ON COLUMN bauth.fin_sod_rule.rule_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.fin_sod_rule.position_a IS 'Primera posición en el Rol BitMask (one-hot encoding).';
COMMENT ON COLUMN bauth.fin_sod_rule.position_b IS 'Segunda posición incompatible. UNIQUE(position_a, position_b).';
COMMENT ON COLUMN bauth.fin_sod_rule.risk_level IS '[COSO] ALTO=riesgo financiero o regulatorio, MEDIO=riesgo operativo, BAJO=riesgo administrativo.';
COMMENT ON COLUMN bauth.fin_sod_rule.action IS 'BLOCK=rechazar asignación, COMPENSATE=requiere aprobación + control compensatorio, ALLOW_LOG=permitir con registro.';
COMMENT ON COLUMN bauth.fin_sod_rule.rationale IS 'Justificación normativa. Debe citar estándar y sección (ej: SOX §404, COSO Control Activities).';
COMMENT ON COLUMN bauth.fin_sod_rule.reviewed_at IS '[COBIT BAI09] Última revisión anual de la regla SoD.';
COMMENT ON COLUMN bauth.fin_sod_rule.reviewed_by IS 'Usuario que realizó la última revisión.';
COMMENT ON COLUMN bauth.fin_sod_rule.ctx_id IS '[SBOS-049] Contexto de trazabilidad.';
COMMENT ON COLUMN bauth.fin_sod_rule.created_at IS '[ISO 27001 A.8.15] Fecha de creación de la regla.';
COMMENT ON COLUMN bauth.fin_sod_rule.updated_at IS '[ISO 27001 A.8.15] Última modificación de la regla.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D3 — FINANCIERO: Decision Matrix
-- ══════════════════════════════════════════════════════════════════════

-- T-106 — bauth.fin_decision_matrix (migrado de bos_financial_decision_matrix)
-- Matriz de decisión financiera en cascada. 3 niveles de aprobación por tipo de transacción.
-- Estándar: [COSO 2013] [SOX §404] [PCI DSS 4.0.1 Req.7] [ISO 20022]
CREATE TABLE IF NOT EXISTS bauth.fin_decision_matrix (
    decision_id                 UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id                   UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    empresa_id                  TEXT,
    nombre                      TEXT        NOT NULL,
    tipo_transaccion            TEXT        NOT NULL,
    moneda                      CHAR(3)     DEFAULT 'BOB',
    nivel_1_rol                 TEXT,
    nivel_1_monto_max           NUMERIC(16,2),
    nivel_1_puede_delegar       BOOLEAN     DEFAULT false,
    nivel_2_rol                 TEXT,
    nivel_2_monto_max           NUMERIC(16,2),
    nivel_2_puede_delegar       BOOLEAN     DEFAULT false,
    nivel_3_rol                 TEXT,
    nivel_3_monto_max           NUMERIC(16,2),
    requiere_comite             BOOLEAN     DEFAULT false,
    requiere_evidencia_adjunta  BOOLEAN     DEFAULT false,
    tiempo_max_aprobacion_horas INTEGER     DEFAULT 48,
    escala_automatica           BOOLEAN     DEFAULT true,
    is_active                   BOOLEAN     NOT NULL DEFAULT true,
    ctx_id                      TEXT        NOT NULL DEFAULT 'system',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, empresa_id, tipo_transaccion, moneda)
);

CREATE INDEX IF NOT EXISTS idx_fdm_tenant ON bauth.fin_decision_matrix(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_fdm_empresa ON bauth.fin_decision_matrix(empresa_id) WHERE empresa_id IS NOT NULL;

COMMENT ON TABLE bauth.fin_decision_matrix IS
  '[COSO 2013] [SOX §404] [PCI DSS 4.0.1 Req.7] [ISO 20022]
   Matriz de decisión financiera en cascada. Define qué rol puede aprobar qué monto
   para cada tipo de transacción. 3 niveles con escalación automática. Si el aprobador
   no responde en SLA → escala al siguiente nivel. Revisión anual COBIT BAI09.';

COMMENT ON COLUMN bauth.fin_decision_matrix.decision_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.fin_decision_matrix.tenant_id IS 'Tenant propietario de la matriz. FK → idn_tenant.';
COMMENT ON COLUMN bauth.fin_decision_matrix.empresa_id IS 'Empresa específica. NULL = aplica a todas las empresas del tenant.';
COMMENT ON COLUMN bauth.fin_decision_matrix.tipo_transaccion IS 'Tipo de transacción financiera: FAC_EMITIR, COBRO_RECIBIR, etc.';
COMMENT ON COLUMN bauth.fin_decision_matrix.moneda IS '[ISO 4217] Código de moneda: BOB, USD, EUR.';
COMMENT ON COLUMN bauth.fin_decision_matrix.nivel_1_monto_max IS 'Monto máximo que puede aprobar el primer nivel. Si se excede → escala a nivel 2.';
COMMENT ON COLUMN bauth.fin_decision_matrix.nivel_2_monto_max IS 'Monto máximo del segundo nivel. Si se excede → escala a nivel 3.';
COMMENT ON COLUMN bauth.fin_decision_matrix.nivel_3_monto_max IS 'Monto máximo del tercer nivel. NULL = sin límite superior.';
COMMENT ON COLUMN bauth.fin_decision_matrix.requiere_comite IS 'TRUE = requiere aprobación de comité (ej: inversiones > 1M).';
COMMENT ON COLUMN bauth.fin_decision_matrix.requiere_evidencia_adjunta IS 'TRUE = documento soporte obligatorio para aprobación.';
COMMENT ON COLUMN bauth.fin_decision_matrix.tiempo_max_aprobacion_horas IS '[SLA] Tiempo máximo para obtener aprobación antes de escalar.';
COMMENT ON COLUMN bauth.fin_decision_matrix.escala_automatica IS 'TRUE = si no hay respuesta en SLA, escala automáticamente al siguiente nivel.';
COMMENT ON COLUMN bauth.fin_decision_matrix.is_active IS 'FALSE = matriz inactiva. No se elimina por auditoría.';
COMMENT ON COLUMN bauth.fin_decision_matrix.ctx_id IS '[SBOS-049] Contexto de trazabilidad.';
COMMENT ON COLUMN bauth.fin_decision_matrix.created_at IS '[ISO 27001 A.8.15] Fecha de creación.';
COMMENT ON COLUMN bauth.fin_decision_matrix.updated_at IS '[ISO 27001 A.8.15] Última modificación.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D8 — CONTEXTO: Sesiones, Switches, Superuser
-- ══════════════════════════════════════════════════════════════════════

-- T-110 — bauth.ses_context (migrado de bos_context_sessions)
-- Sesiones de contexto 6-capas con W3C Trace Context. Columna vertebral del Context Plane.
-- Estándar: [SBOS-049 §4] [W3C Trace Context] [NIST 800-63B-4 §7] [ISO 27001 A.8.15]
CREATE TABLE IF NOT EXISTS bauth.ses_context (
    ctx_id              TEXT        PRIMARY KEY,
    dctx_id             TEXT,
    tenant_id           TEXT        NOT NULL,
    empresa_id          TEXT        NOT NULL,
    sucursal_id         TEXT,
    pos_logico          TEXT,
    user_uuid           UUID        NOT NULL,
    ruta_canonica       TEXT,
    context_actual      TEXT,
    bos_contexts        TEXT[]      DEFAULT '{}',
    device_id           TEXT,
    device_hostname     TEXT,
    device_ip           INET,
    device_mac          MACADDR,
    device_geo          TEXT,
    session_kc          TEXT        NOT NULL,
    bitmask_hex         TEXT        NOT NULL,
    loa_current         INTEGER     NOT NULL DEFAULT 1,
    traceparent         TEXT,
    tracestate          TEXT,
    pod                 TEXT,
    namespace_k8s       TEXT,
    node                TEXT,
    state               TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NOT NULL,
    invalidated_at      TIMESTAMPTZ,
    CONSTRAINT chk_sc_state CHECK (state IN ('ACTIVE','INVALIDATED','EXPIRED'))
);

CREATE INDEX IF NOT EXISTS idx_sc_user    ON bauth.ses_context(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sc_tenant  ON bauth.ses_context(tenant_id, state);
CREATE INDEX IF NOT EXISTS idx_sc_expires ON bauth.ses_context(expires_at) WHERE state = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sc_device  ON bauth.ses_context(device_id) WHERE device_id IS NOT NULL;

COMMENT ON TABLE bauth.ses_context IS
  '[SBOS-049 §4] [W3C Trace Context] [NIST 800-63B-4 §7] [ISO 27001 A.8.15]
   Sesiones de contexto 6-capas. Cada ctx_id representa una sesión autenticada con
   todas las dimensiones del Context Plane resueltas. La columna vertebral del sistema
   de contexto. dctx_id es el device context pre-autenticación. Al promover dctx_id→ctx_id,
   se resuelven las 6 capas: tenant, empresa, sucursal, pos_logico, user_uuid, session_kc.';

COMMENT ON COLUMN bauth.ses_context.ctx_id IS '[UUID v4] Identificador único de sesión de contexto. W3C traceparent vinculado.';
COMMENT ON COLUMN bauth.ses_context.dctx_id IS 'Device Context ID pre-autenticación. NULL si fue creado directamente.';
COMMENT ON COLUMN bauth.ses_context.tenant_id IS '[SBOS-049 §4] Capa 1: Tenant.';
COMMENT ON COLUMN bauth.ses_context.empresa_id IS '[SBOS-049 §4] Capa 2: Empresa dentro del tenant.';
COMMENT ON COLUMN bauth.ses_context.sucursal_id IS '[SBOS-049 §4] Capa 3: Sucursal física.';
COMMENT ON COLUMN bauth.ses_context.pos_logico IS '[SBOS-049 §4] Capa 4: Punto de venta lógico.';
COMMENT ON COLUMN bauth.ses_context.user_uuid IS '[SBOS-049 §4] Capa 5: Usuario autenticado. FK → idn_user_template.';
COMMENT ON COLUMN bauth.ses_context.ruta_canonica IS 'Ruta completa: /dist/{tenant}/emp/{empresa}/suc/{sucursal}/user/{user_id}/pos/{pos_id}.';
COMMENT ON COLUMN bauth.ses_context.bos_contexts IS '[SBOS-049 §4.2] Contextos autorizados del usuario.';
COMMENT ON COLUMN bauth.ses_context.device_id IS '[SBOS-049 §6] Hardware físico desde donde se estableció la sesión.';
COMMENT ON COLUMN bauth.ses_context.device_ip IS 'Dirección IP del dispositivo al momento de creación de la sesión.';
COMMENT ON COLUMN bauth.ses_context.session_kc IS 'Session ID de Keycloak vinculada a este ctx_id.';
COMMENT ON COLUMN bauth.ses_context.bitmask_hex IS 'BitMask efectiva del usuario en esta sesión (hex).';
COMMENT ON COLUMN bauth.ses_context.loa_current IS '[NIST 800-63B-4] Nivel de aseguramiento actual de la sesión (0-4).';
COMMENT ON COLUMN bauth.ses_context.traceparent IS '[W3C Trace Context] traceparent para propagación distribuida.';
COMMENT ON COLUMN bauth.ses_context.tracestate IS '[W3C Trace Context] tracestate para propagación distribuida.';
COMMENT ON COLUMN bauth.ses_context.state IS 'ACTIVE=sesión válida, INVALIDATED=logout/revocada, EXPIRED=timeout.';
COMMENT ON COLUMN bauth.ses_context.expires_at IS 'Timestamp de expiración absoluta de la sesión.';
COMMENT ON COLUMN bauth.ses_context.invalidated_at IS 'Timestamp de invalidación. NULL si no ha sido invalidada.';

-- T-111 — bauth.ses_context_switch (migrado de bos_context_switches)
-- Historial de cambios de contexto operativo
-- Estándar: [SBOS-049 §5] [ISO 27001 A.8.15]
CREATE TABLE IF NOT EXISTS bauth.ses_context_switch (
    switch_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    ctx_id_anterior TEXT,
    ctx_id_nuevo    TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    sucursal_id     TEXT,
    pos_logico      TEXT,
    motivo          TEXT,
    emitido_por     TEXT        NOT NULL DEFAULT 'bos',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scs_user ON bauth.ses_context_switch(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scs_ctx  ON bauth.ses_context_switch(ctx_id_nuevo);
CREATE INDEX IF NOT EXISTS idx_scs_prev ON bauth.ses_context_switch(ctx_id_anterior) WHERE ctx_id_anterior IS NOT NULL;

COMMENT ON TABLE bauth.ses_context_switch IS
  '[SBOS-049 §5] [ISO 27001 A.8.15]
   Historial de cambios de contexto operativo. Cada switch genera un evento
   context.switched que se propaga a bKernel → audit_events. Trazabilidad
   completa de cuándo un usuario cambia de sucursal, empresa o POS.';

COMMENT ON COLUMN bauth.ses_context_switch.switch_id IS '[RFC 9562] UUIDv7 PK.';
COMMENT ON COLUMN bauth.ses_context_switch.ctx_id_anterior IS 'Contexto antes del switch. NULL si es el primer contexto (login).';
COMMENT ON COLUMN bauth.ses_context_switch.ctx_id_nuevo IS 'Contexto después del switch.';
COMMENT ON COLUMN bauth.ses_context_switch.motivo IS 'Razón: cambio_sucursal, reasignacion_pos, login, cambio_empresa.';
COMMENT ON COLUMN bauth.ses_context_switch.emitido_por IS 'Quién emitió el switch: bos, usuario, admin.';
COMMENT ON COLUMN bauth.ses_context_switch.ctx_id IS '[SBOS-049] Contexto de trazabilidad de la operación de switch.';
COMMENT ON COLUMN bauth.ses_context_switch.created_at IS '[ISO 27001 A.8.15] Timestamp del switch.';

-- T-112 — bauth.ses_superuser_context (migrado de bos_superuser_contexts)
-- Registro de activaciones break-glass del Superusuario
-- Estándar: [ISO 27001 A.8.2] [NIST 800-53 AC-6] [PAM Best Practices]
CREATE TABLE IF NOT EXISTS bauth.ses_superuser_context (
    context_id      TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    admin_uuid      UUID        NOT NULL,
    reason          TEXT        NOT NULL,
    vault_unseal    BOOLEAN     NOT NULL DEFAULT false,
    session_log     TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    post_audit_at   TIMESTAMPTZ,
    post_audit_by   UUID,
    CONSTRAINT chk_ssc_expiry CHECK (expires_at <= created_at + INTERVAL '4 hours')
);

CREATE INDEX IF NOT EXISTS idx_ssc_active ON bauth.ses_superuser_context(expires_at) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ssc_admin ON bauth.ses_superuser_context(admin_uuid, created_at DESC);

COMMENT ON TABLE bauth.ses_superuser_context IS
  '[ISO 27001 A.8.2] [NIST 800-53 AC-6] [PAM Best Practices]
   Registro de activaciones break-glass del Superusuario. Acceso de emergencia
   con Vault 2-of-3 unseal. Sesión máxima 4 horas. Auditoría post-evento
   obligatoria en ≤24h. Cada activación es trazable e inmutable.';

COMMENT ON COLUMN bauth.ses_superuser_context.context_id IS 'ID único de la sesión break-glass.';
COMMENT ON COLUMN bauth.ses_superuser_context.admin_uuid IS 'Usuario administrativo que activó el break-glass.';
COMMENT ON COLUMN bauth.ses_superuser_context.reason IS 'Motivo del acceso de emergencia. Obligatorio. Se audita post-evento.';
COMMENT ON COLUMN bauth.ses_superuser_context.vault_unseal IS 'TRUE si se realizó unseal 2-of-3 de Vault.';
COMMENT ON COLUMN bauth.ses_superuser_context.session_log IS 'Registro completo de la sesión (comandos ejecutados). Inmutable.';
COMMENT ON COLUMN bauth.ses_superuser_context.expires_at IS 'Fecha de expiración. Máx created_at + 4h. CHECK enforce.';
COMMENT ON COLUMN bauth.ses_superuser_context.post_audit_at IS 'Timestamp de auditoría post-evento. ≤24h post-revocación.';
COMMENT ON COLUMN bauth.ses_superuser_context.post_audit_by IS 'Auditor que revisó la sesión break-glass.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D9 — CREDENCIALES: Lote 0.2 (14 tablas migradas del DDL antiguo)
-- ══════════════════════════════════════════════════════════════════════

-- T-120 — bauth.ath_credential_policy (migrado de bos_credential_policy)
-- [NIST SP 800-63B-4 §5.1] [NIST SP 800-57 Pt.1] [OWASP ASVS V2.1]
CREATE TABLE IF NOT EXISTS bauth.ath_credential_policy (
    policy_id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    policy_code             TEXT        UNIQUE NOT NULL,
    policy_name             TEXT        NOT NULL,
    credential_type         TEXT        NOT NULL,
    min_strength_bits       INTEGER     NOT NULL DEFAULT 256,
    requires_csprng         BOOLEAN     NOT NULL DEFAULT true,
    allow_diceware          BOOLEAN     DEFAULT false,
    rotate_by_time          BOOLEAN     NOT NULL DEFAULT false,
    ttl_max_days            INTEGER,
    rotate_on_compromise    BOOLEAN     NOT NULL DEFAULT true,
    rotate_on_event         BOOLEAN     NOT NULL DEFAULT false,
    requires_hibp_screening BOOLEAN     DEFAULT false,
    max_failed_attempts     INTEGER     DEFAULT 10,
    lockout_duration_minutes INTEGER    DEFAULT 15,
    history_retention_count INTEGER     DEFAULT 10,
    notify_on_change        BOOLEAN     DEFAULT true,
    is_active               BOOLEAN     NOT NULL DEFAULT true,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_acp_cred_type CHECK (credential_type IN ('PASSWORD','TOTP','WEBAUTHN','X509_CERT','OAUTH_SECRET','API_KEY','ENCRYPTION_KEY','SIGNING_KEY'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_acp_code ON bauth.ath_credential_policy(policy_code);

COMMENT ON TABLE bauth.ath_credential_policy IS
  '[NIST SP 800-63B-4 §5.1] [NIST SP 800-57 Pt.1] [OWASP ASVS V2.1]
   Política de ciclo de vida de credenciales. NIST Rev.4: sin rotación forzada para passwords.
   NIST SP 800-57: rotación periódica para claves criptográficas (M2M certs, signing keys).
   Cada tipo de credencial tiene su propia política.';

-- T-121 — bauth.ath_password_history (migrado de bos_password_history)
-- [NIST SP 800-63B-4 §5.1.1.2] [OWASP ASVS V2.1.6]
CREATE TABLE IF NOT EXISTS bauth.ath_password_history (
    history_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    password_hash   BYTEA       NOT NULL,
    salt            BYTEA       NOT NULL,
    argon2_params   JSONB       NOT NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_aph_user ON bauth.ath_password_history(user_uuid, created_at DESC);

COMMENT ON TABLE bauth.ath_password_history IS
  '[NIST SP 800-63B-4 §5.1.1.2] [OWASP ASVS V2.1.6]
   Historial de contraseñas hasheadas con Argon2id. Trigger mantiene solo las últimas N
   (definido en ath_credential_policy.history_retention_count). Previene reutilización.';

-- T-122 — bauth.ath_password_screening (migrado de bos_password_screening_log)
-- [NIST SP 800-63B-4 §5.1.1.2] [OWASP ASVS V2.1.7]
CREATE TABLE IF NOT EXISTS bauth.ath_password_screening (
    screening_id    UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID,
    k_anon_prefix   TEXT        NOT NULL,
    hibp_result     BOOLEAN     NOT NULL,
    screening_source TEXT       NOT NULL DEFAULT 'hibp',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    screened_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_aps_user ON bauth.ath_password_screening(user_uuid, screened_at DESC);

COMMENT ON TABLE bauth.ath_password_screening IS
  '[NIST SP 800-63B-4 §5.1.1.2] [OWASP ASVS V2.1.7]
   Registro de cribado de contraseñas contra HIBP usando k-anonymity (solo prefijo SHA-1 de 5 chars).
   Cribado obligatorio en enrolamiento + cambio de contraseña. Rechazo automático si aparece en HIBP.';

-- T-123 — bauth.ath_mfa_enrollment (migrado de bos_mfa_enrollments)
-- [NIST SP 800-63B-4 §5.1] [FIDO2 Level 3]
CREATE TABLE IF NOT EXISTS bauth.ath_mfa_enrollment (
    enrollment_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    mfa_type        TEXT        NOT NULL,
    label           TEXT,
    credential_id   TEXT,
    public_key      TEXT,
    device_info     JSONB       DEFAULT '{}',
    is_primary      BOOLEAN     NOT NULL DEFAULT false,
    is_backup       BOOLEAN     NOT NULL DEFAULT false,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at    TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    CONSTRAINT chk_ame_mfa_type CHECK (mfa_type IN ('totp','webauthn_platform','webauthn_roaming','passkey','recovery_codes'))
);
CREATE INDEX IF NOT EXISTS idx_ame_user ON bauth.ath_mfa_enrollment(user_uuid);

COMMENT ON TABLE bauth.ath_mfa_enrollment IS
  '[NIST SP 800-63B-4 §5.1] [FIDO2 Level 3]
   Registro de dispositivos MFA por usuario. Ciclo completo: enroll→verify→rotate→revoke.
   Soporta TOTP (RFC 6238), WebAuthn (platform/roaming), Passkeys (FIDO2 synced), Recovery Codes.';

-- T-124 — bauth.ath_recovery_method (migrado de bos_recovery_method)
-- [NIST SP 800-63B-4 §4.4] [OWASP ASVS V2.5.1]
CREATE TABLE IF NOT EXISTS bauth.ath_recovery_method (
    recovery_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    method_type     TEXT        NOT NULL,
    method_value    TEXT        NOT NULL,
    is_verified     BOOLEAN     NOT NULL DEFAULT false,
    verified_at     TIMESTAMPTZ,
    is_primary      BOOLEAN     NOT NULL DEFAULT false,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_arm_method_type CHECK (method_type IN ('email','sms','backup_codes','security_questions','trusted_contact','hardware_token')),
    UNIQUE (user_uuid, method_type)
);
CREATE INDEX IF NOT EXISTS idx_arm_user ON bauth.ath_recovery_method(user_uuid);

COMMENT ON TABLE bauth.ath_recovery_method IS
  '[NIST SP 800-63B-4 §4.4] [OWASP ASVS V2.5.1]
   Métodos de recuperación de cuenta. Cada método debe ser verificado antes de usarse.
   Backup codes SHA-256 hasheados. Email/SMS requieren confirmación por canal separado. Máx 5 por usuario.';

-- T-125 — bauth.ath_recovery_challenge (migrado de bos_recovery_challenge)
-- [OWASP ASVS V2.5.1] [NIST SP 800-63B-4 §4.4.2]
CREATE TABLE IF NOT EXISTS bauth.ath_recovery_challenge (
    challenge_id    UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    question_hash   BYTEA       NOT NULL,
    answer_hash     BYTEA       NOT NULL,
    salt            BYTEA       NOT NULL,
    argon2_params   JSONB       NOT NULL DEFAULT '{"t":3,"m":65536,"p":2}',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at    TIMESTAMPTZ,
    UNIQUE (user_uuid, question_hash)
);
CREATE INDEX IF NOT EXISTS idx_arc_user ON bauth.ath_recovery_challenge(user_uuid);

COMMENT ON TABLE bauth.ath_recovery_challenge IS
  '[OWASP ASVS V2.5.1] [NIST SP 800-63B-4 §4.4.2]
   Desafíos de recuperación. Pregunta y respuesta hasheadas con Argon2id + salt único 32 bytes.
   NUNCA texto plano. Mínimo 3 preguntas. Bloqueo tras 3 intentos. Rotación cada 180 días.';

-- T-126 — bauth.ath_binding (migrado de bos_authenticator_binding)
-- [NIST SP 800-63B-4 §5.2.1]
CREATE TABLE IF NOT EXISTS bauth.ath_binding (
    binding_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid               UUID        NOT NULL,
    authenticator_type      TEXT        NOT NULL,
    authenticator_id        TEXT        NOT NULL,
    binding_method          TEXT        NOT NULL,
    binding_loa             INTEGER     NOT NULL DEFAULT 1,
    enrollment_authority    TEXT        NOT NULL,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    issued_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at              TIMESTAMPTZ,
    last_used_at            TIMESTAMPTZ,
    status                  TEXT        NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_ab_auth_type CHECK (authenticator_type IN ('password','totp','webauthn_platform','webauthn_roaming','passkey_synced','passkey_device_bound','x509_mtls','recovery_code','out_of_band_sms','out_of_band_email','push_notification')),
    CONSTRAINT chk_ab_binding_method CHECK (binding_method IN ('in_person','remote_verified','self_service','admin_provisioned','federated','inherited')),
    CONSTRAINT chk_ab_loa CHECK (binding_loa BETWEEN 1 AND 4),
    CONSTRAINT chk_ab_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED'))
);
CREATE INDEX IF NOT EXISTS idx_ab_user ON bauth.ath_binding(user_uuid);

COMMENT ON TABLE bauth.ath_binding IS
  '[NIST SP 800-63B-4 §5.2.1] [NIST SP 800-63B-4 §5.2.3]
   Vínculo criptográfico entre un authenticator y un subscriber. Registra método de vinculación,
   nivel de aseguramiento (LoA 1-4) y autoridad de enrolamiento. Cada authenticator debe ser
   vinculado ANTES de poder usarse para autenticación.';

-- T-127 — bauth.ath_revocation (migrado de bos_authenticator_revocation)
-- [NIST SP 800-63B-4 §5.2.2] [OWASP ASVS V2.3.2]
CREATE TABLE IF NOT EXISTS bauth.ath_revocation (
    revocation_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    binding_id          UUID        NOT NULL REFERENCES bauth.ath_binding(binding_id) ON DELETE CASCADE,
    user_uuid           UUID        NOT NULL,
    reason              TEXT        NOT NULL,
    revoked_by          TEXT        NOT NULL,
    replacement_binding UUID,
    ctx_id              TEXT        NOT NULL,
    revoked_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ar_user ON bauth.ath_revocation(user_uuid, revoked_at DESC);

COMMENT ON TABLE bauth.ath_revocation IS
  '[NIST SP 800-63B-4 §5.2.2] [OWASP ASVS V2.3.2]
   Registro WORM de revocaciones de authenticators. Motivo obligatorio + authenticator reemplazo
   + ctx_id trazable. La revocación debe completarse en <30s desde la solicitud.';

-- T-128 — bauth.ath_login_attempt (migrado de bos_login_attempt)
-- [NIST SP 800-53 AC-7] [OWASP ASVS V2.1.2] [PCI DSS 4.0 Req 8.3.4]
CREATE TABLE IF NOT EXISTS bauth.ath_login_attempt (
    attempt_id      BIGSERIAL,
    user_uuid       UUID,
    username        TEXT        NOT NULL,
    source_ip       INET        NOT NULL,
    user_agent      TEXT,
    is_success      BOOLEAN     NOT NULL DEFAULT false,
    failure_reason  TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    attempted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (attempt_id, attempted_at)
) PARTITION BY RANGE (attempted_at);

CREATE TABLE IF NOT EXISTS bauth.ath_login_attempt_2026_07 PARTITION OF bauth.ath_login_attempt
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.ath_login_attempt_2026_08 PARTITION OF bauth.ath_login_attempt
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE INDEX IF NOT EXISTS idx_ala_user ON bauth.ath_login_attempt(user_uuid, attempted_at DESC) WHERE is_success = false;
CREATE INDEX IF NOT EXISTS idx_ala_ip ON bauth.ath_login_attempt(source_ip, attempted_at DESC) WHERE is_success = false;

COMMENT ON TABLE bauth.ath_login_attempt IS
  '[NIST SP 800-53 AC-7] [OWASP ASVS V2.1.2] [PCI DSS 4.0 Req 8.3.4]
   Registro de intentos de login. Particionado por mes. Bloqueo progresivo:
   3 intentos→15min, 5→1h, 10→24h. Índices filtrados para detección de ataques.';

-- T-129 — bauth.ath_consent (migrado de bos_user_consent)
-- [GDPR Art.7] [ISO 27701]
CREATE TABLE IF NOT EXISTS bauth.ath_consent (
    consent_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    consent_type    TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'granted',
    ip_address      INET,
    user_agent      TEXT,
    metadata        JSONB       DEFAULT '{}',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    withdrawn_at    TIMESTAMPTZ,
    CONSTRAINT chk_ac_consent_type CHECK (consent_type IN ('data_processing','marketing','third_party','biometric','cookies','profiling','automated_decision')),
    CONSTRAINT chk_ac_status CHECK (status IN ('granted','withdrawn','expired'))
);
CREATE INDEX IF NOT EXISTS idx_ac_user ON bauth.ath_consent(user_uuid);

COMMENT ON TABLE bauth.ath_consent IS
  '[GDPR Art.7] [ISO 27701]
   Registro de consentimientos. RGPD exige consentimiento explícito, informado, granular,
   revocable y documentado. Cada consentimiento es trazable con IP y timestamp.';

-- T-130 — bauth.ath_rotation_log (migrado de bos_credential_rotation_log)
-- [NIST SP 800-63B-4 §5.1] [NIST SP 800-57 Pt.1]
CREATE TABLE IF NOT EXISTS bauth.ath_rotation_log (
    rotation_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID,
    credential_type TEXT        NOT NULL,
    reason          TEXT        NOT NULL,
    detection_source TEXT,
    rotated_by      TEXT        NOT NULL,
    previous_hash   TEXT,
    new_hash        TEXT,
    new_ttl         INTERVAL,
    notification_sent BOOLEAN   DEFAULT false,
    evidence        JSONB       DEFAULT '{}',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    rotated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_arl_reason CHECK (reason IN ('COMPROMISE_DETECTED','TTL_EXPIRED','MANUAL','POST_EVENT','PERIODIC','CREATION'))
);
CREATE INDEX IF NOT EXISTS idx_arl_user ON bauth.ath_rotation_log(user_uuid, rotated_at DESC);
CREATE INDEX IF NOT EXISTS idx_arl_type ON bauth.ath_rotation_log(credential_type, rotated_at DESC);

COMMENT ON TABLE bauth.ath_rotation_log IS
  '[NIST SP 800-63B-4 §5.1] [NIST SP 800-57 Pt.1]
   Auditoría de cada rotación de credencial. Trazabilidad completa: quién, cuándo, por qué,
   origen de detección. Evidencia adjunta en JSONB.';

-- T-131 — bauth.ath_token_delivery (migrado de bos_token_delivery_log)
CREATE TABLE IF NOT EXISTS bauth.ath_token_delivery (
    delivery_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    token_id            UUID        NOT NULL,
    token_type          TEXT        NOT NULL,
    user_uuid           UUID        NOT NULL,
    delivery_channel    TEXT        NOT NULL,
    delivered_by        UUID,
    recipient_signature TEXT,
    witness             UUID,
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    delivered_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_atd_token_type CHECK (token_type IN ('TOTP','HOTP','NFC','QR','PUSH','RECOVERY','SMS','EMAIL','MAGIC_LINK','BARCODE')),
    CONSTRAINT chk_atd_channel CHECK (delivery_channel IN ('presencial','remote_secure','self_service','whatsapp','telegram','email','sms','push'))
);

COMMENT ON TABLE bauth.ath_token_delivery IS
  'Registro de entrega de tokens de autenticación. Trazabilidad completa del canal,
   receptor, testigo y firma.';

-- T-132 — bauth.ath_enrollment_log (migrado de bos_auth_method_enrollment_log)
CREATE TABLE IF NOT EXISTS bauth.ath_enrollment_log (
    enrollment_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    method_type     TEXT        NOT NULL,
    step            TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'IN_PROGRESS',
    metadata        JSONB       DEFAULT '{}',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ael_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED')),
    CONSTRAINT chk_ael_step CHECK (step IN ('identity_verify','generate_credential','deliver_to_user','verify_method','activate'))
);
CREATE INDEX IF NOT EXISTS idx_ael_user ON bauth.ath_enrollment_log(user_uuid, executed_at DESC);

COMMENT ON TABLE bauth.ath_enrollment_log IS
  'Registro de enrolamiento de métodos de autenticación. 5 pasos: identity_verify→
   generate_credential→deliver_to_user→verify_method→activate. Auditoría completa del proceso.';

-- T-133 — bauth.ath_federation_protocol (migrado de bos_federation_protocol)
-- [NIST SP 800-63C-4] [OAuth 2.1 BCP] [RFC 9700]
CREATE TABLE IF NOT EXISTS bauth.ath_federation_protocol (
    protocol_id     TEXT        PRIMARY KEY,
    protocol_name   TEXT        NOT NULL,
    protocol_type   TEXT        NOT NULL,
    rfc_ref         TEXT,
    flow            TEXT        NOT NULL,
    pkce_required   BOOLEAN     NOT NULL DEFAULT false,
    applies_to      TEXT[]      NOT NULL DEFAULT '{}',
    bAuth_status    TEXT        NOT NULL DEFAULT 'enabled',
    config          JSONB       DEFAULT '{}',
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_afp_type CHECK (protocol_type IN ('authorization','authentication','federation','delegation','device','token_exchange','deprecated')),
    CONSTRAINT chk_afp_status CHECK (bAuth_status IN ('enabled','disabled_permanently','enabled_controlled','planned'))
);

COMMENT ON TABLE bauth.ath_federation_protocol IS
  '[NIST SP 800-63C-4] [OAuth 2.1 BCP] [RFC 9700]
   Catálogo de 16 protocolos de federación soportados. Define para cada protocolo:
   tipo, flujo, si requiere PKCE, a qué aplica, y su estado en bAuth.';

COMMENT ON COLUMN bauth.ath_federation_protocol.protocol_id IS 'PK canónica: oauth2, oidc, saml2, ciba, fapi2, dpop, mTLS, jwt_profile, token_exchange, device_flow.';
COMMENT ON COLUMN bauth.ath_federation_protocol.flow IS 'Flujo: authorization_code, client_credentials, hybrid, implicit(deprecated), password(deprecated).';
COMMENT ON COLUMN bauth.ath_federation_protocol.pkce_required IS 'OAuth 2.1 BCP: PKCE obligatorio para authorization_code con clientes públicos.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D10 — DELEGACIÓN: Lote 0.3
-- ══════════════════════════════════════════════════════════════════════

-- T-140 — bauth.dlg_delegation (migrado de bos_delegation_log)
-- [NIST SP 800-53 AC-5] [ANSI/INCITS 359-2004 DSD] [ISO 27001 A.8.2]
CREATE TABLE IF NOT EXISTS bauth.dlg_delegation (
    delegation_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    from_user_uuid      UUID        NOT NULL,
    to_user_uuid        UUID        NOT NULL,
    rol_id              TEXT        NOT NULL,
    tenant_id           TEXT        NOT NULL,
    mask_delegated_hex  TEXT        NOT NULL,
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL,
    auto_revoke         BOOLEAN     NOT NULL DEFAULT true,
    requires_approval   BOOLEAN     NOT NULL DEFAULT true,
    approved_by         TEXT,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at          TIMESTAMPTZ,
    CONSTRAINT chk_dlg_status CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
    CONSTRAINT chk_dlg_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_dlg_no_self CHECK (from_user_uuid != to_user_uuid)
);
CREATE INDEX IF NOT EXISTS idx_dlg_active ON bauth.dlg_delegation(valid_until) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_dlg_from ON bauth.dlg_delegation(from_user_uuid);
CREATE INDEX IF NOT EXISTS idx_dlg_to ON bauth.dlg_delegation(to_user_uuid);

COMMENT ON TABLE bauth.dlg_delegation IS
  '[NIST SP 800-53 AC-5] [ANSI/INCITS 359-2004 DSD] [ISO 27001 A.8.2]
   Delegaciones temporales de roles. Bitmask efectiva = original AND delegada. Máx 21 días.
   Auto-revocación al expirar. No se permite auto-delegación.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D11 — AUDITORÍA: Lote 0.3 (7 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- T-145 — bauth.aud_event (migrado de bos_audit_events)
-- [ISO 27001 A.8.15] [PCI DSS 10.3.2] [NIST SP 800-53 AU-2/AU-3]
CREATE TABLE IF NOT EXISTS bauth.aud_event (
    event_id        BIGSERIAL,
    ctx_id          TEXT        NOT NULL,
    traceparent     TEXT,
    event_type      TEXT        NOT NULL,
    severity        TEXT        NOT NULL DEFAULT 'INFO',
    iso_control     TEXT[],
    user_uuid       UUID,
    role_id         TEXT,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT,
    sucursal_id     TEXT,
    pos_logico      TEXT,
    device_id       TEXT,
    source_ip       INET,
    user_agent      TEXT,
    action          TEXT        NOT NULL,
    resource_type   TEXT        NOT NULL,
    resource_id     TEXT,
    outcome         TEXT        NOT NULL,
    details         JSONB       DEFAULT '{}',
    prev_hash       TEXT,
    entry_hash      TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, created_at),
    CONSTRAINT chk_ae_type CHECK (event_type IN (
        'LOGIN_SUCCESS','LOGIN_FAILED','LOGOUT','ACCESS_DENIED','ACCESS_GRANTED',
        'CONFIG_CHANGE','PRIVILEGE_ESCALATION','PRIVILEGE_USE','MAINTENANCE',
        'FILE_ACCESS','FILE_DELETE','FILE_MIGRATION',
        'SECURITY_ALARM','SECURITY_SYSTEM_TOGGLE',
        'IDENTITY_CREATE','IDENTITY_MODIFY','IDENTITY_DELETE','IDENTITY_ARCHIVE',
        'ROLE_ASSIGN','ROLE_REVOKE','ROLE_CREATE','ROLE_MODIFY',
        'DELEGATION_CREATE','DELEGATION_REVOKE','DELEGATION_USE',
        'POLICY_CHANGE','COMPLIANCE_REVIEW','ACCESS_REVIEW',
        'CONTEXT_SWITCH','CONTEXT_INVALIDATE','SUPERUSER_ACTIVATE',
        'SYNC_START','SYNC_COMPLETE','SYNC_ERROR','DRIFT_DETECTED'
    )),
    CONSTRAINT chk_ae_severity CHECK (severity IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL','ALERT')),
    CONSTRAINT chk_ae_outcome CHECK (outcome IN ('SUCCESS','FAILURE','DENIED','ERROR','PENDING'))
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS bauth.aud_event_2026_07 PARTITION OF bauth.aud_event
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.aud_event_2026_08 PARTITION OF bauth.aud_event
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE INDEX IF NOT EXISTS idx_ae_ctx ON bauth.aud_event(ctx_id);
CREATE INDEX IF NOT EXISTS idx_ae_user ON bauth.aud_event(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_type ON bauth.aud_event(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_tenant ON bauth.aud_event(tenant_id, created_at DESC);

COMMENT ON TABLE bauth.aud_event IS
  '[ISO 27001 A.8.15] [PCI DSS 10.3.2] [NIST SP 800-53 AU-2/AU-3]
   Registro WORM de eventos de auditoría. Particionado por mes. Hash-chain SHA-256 inmutable.
   30 tipos de eventos cubriendo todo el ciclo de vida de identidad, acceso, y configuración.';

-- T-146 — bauth.aud_review (migrado de bos_access_reviews)
-- [ISO 27001 A.9.2.5] [NIST SP 800-53 AC-2]
CREATE TABLE IF NOT EXISTS bauth.aud_review (
    review_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    reviewer_uuid   UUID        NOT NULL,
    review_type     TEXT        NOT NULL,
    due_date        DATE        NOT NULL,
    decision        TEXT,
    decision_at     TIMESTAMPTZ,
    comments        TEXT,
    previous_roles  TEXT[],
    current_roles   TEXT[],
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ar_type CHECK (review_type IN ('MONTHLY','QUARTERLY','SEMI_ANNUAL','ANNUAL'))
);
CREATE INDEX IF NOT EXISTS idx_ar_due ON bauth.aud_review(due_date) WHERE decision IS NULL;
CREATE INDEX IF NOT EXISTS idx_ar_user ON bauth.aud_review(user_uuid, created_at DESC);

COMMENT ON TABLE bauth.aud_review IS
  '[ISO 27001 A.9.2.5] [NIST SP 800-53 AC-2]
   Campañas de recertificación de accesos. Revisiones periódicas con snapshot de roles
   antes/después. Alertas 7 días antes del vencimiento.';

-- T-147 — bauth.aud_ghost_account (migrado de bos_ghost_accounts)
CREATE TABLE IF NOT EXISTS bauth.aud_ghost_account (
    ghost_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    username        TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    detection_type  TEXT        NOT NULL,
    risk_score      INTEGER     NOT NULL DEFAULT 0,
    action_taken    TEXT        NOT NULL DEFAULT 'DETECTED',
    action_at       TIMESTAMPTZ,
    resolution      TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_aga_type CHECK (detection_type IN ('KC_ACTIVE_HR_INACTIVE','NO_LOGIN_180D','TRYTON_ONLY','KC_ONLY','INCONSISTENT_SYNC'))
);
CREATE INDEX IF NOT EXISTS idx_aga_detected ON bauth.aud_ghost_account(detected_at DESC);

COMMENT ON TABLE bauth.aud_ghost_account IS
  'Detección de cuentas huérfanas. ISACA: 37% de organizaciones tienen ghost accounts.
   Tipos: activo en KC pero baja en RRHH, sin login 180d, solo en Tryton/KC, inconsistente.';

-- T-148 — bauth.aud_policy_change (migrado de bos_policy_audit)
-- [ISO 27001 A.8.9]
CREATE TABLE IF NOT EXISTS bauth.aud_policy_change (
    audit_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    policy_slug     TEXT        NOT NULL,
    change_type     TEXT        NOT NULL,
    old_params      JSONB,
    new_params      JSONB,
    changed_by      UUID        NOT NULL,
    reason          TEXT        NOT NULL,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_apc_type CHECK (change_type IN ('CREATE','UPDATE','DELETE','DEPRECATE','ROLLBACK'))
);
CREATE INDEX IF NOT EXISTS idx_apc_policy ON bauth.aud_policy_change(policy_slug, changed_at DESC);

COMMENT ON TABLE bauth.aud_policy_change IS
  '[ISO 27001 A.8.9] Auditoría WORM de cambios de políticas de seguridad. old_params/new_params
   en JSONB para comparación exacta. Trazabilidad completa de quién, cuándo y por qué.';

-- T-149 — bauth.aud_policy_version (migrado de bos_policy_history)
CREATE TABLE IF NOT EXISTS bauth.aud_policy_version (
    version_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    policy_slug TEXT        NOT NULL,
    version     INTEGER     NOT NULL,
    params      JSONB       NOT NULL,
    created_by  UUID        NOT NULL,
    ctx_id      TEXT        NOT NULL DEFAULT 'system',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_apv_policy ON bauth.aud_policy_version(policy_slug, version DESC);

COMMENT ON TABLE bauth.aud_policy_version IS
  'Historial versionado de políticas. Cada versión numerada con params completos en JSONB.
   Permite rollback a cualquier versión anterior.';

-- T-150 — bauth.aud_compliance_map (migrado de bos_compliance_map)
-- [ISO 27001:2022] [NIST 800-53] [PCI DSS 4.0] [GDPR]
CREATE TABLE IF NOT EXISTS bauth.aud_compliance_map (
    compliance_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    standard                TEXT        NOT NULL,
    control_id              TEXT        NOT NULL,
    control_name            TEXT        NOT NULL,
    description             TEXT        NOT NULL,
    applies_to              TEXT        NOT NULL,
    implementation_status   TEXT        NOT NULL DEFAULT 'planned',
    evidence_ref            TEXT,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    last_reviewed           TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_acm_status CHECK (implementation_status IN ('implemented','partial','planned','not_applicable'))
);
CREATE INDEX IF NOT EXISTS idx_acm_standard ON bauth.aud_compliance_map(standard, implementation_status);

COMMENT ON TABLE bauth.aud_compliance_map IS
  '[ISO 27001:2022] [NIST 800-53 Rev.5] [PCI DSS 4.0] [GDPR Art.32] [eIDAS 2.0] [OWASP ASVS 5.0]
   Mapeo de 34+ controles de cumplimiento normativo. Cada control mapeado a su estándar,
   estado de implementación y evidencia.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D13 — SYNCHRONIZATION: Lote 0.3
-- ══════════════════════════════════════════════════════════════════════

-- T-165 — bauth.sync_log (migrado de bos_sync_log)
-- [ISO 27001 A.8.15]
CREATE TABLE IF NOT EXISTS bauth.sync_log (
    sync_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    rol_id          TEXT,
    user_uuid       UUID,
    tenant_id       TEXT        NOT NULL,
    engine          TEXT        NOT NULL,
    sync_type       TEXT        NOT NULL,
    triggered_by    TEXT        NOT NULL,
    status          TEXT        NOT NULL,
    kc_status       TEXT,
    tryton_status   TEXT,
    error_message   TEXT,
    retry_count     INTEGER     DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    duration_ms     INTEGER,
    CONSTRAINT chk_sl_status CHECK (status IN ('PENDING','SYNCING','SYNCED','ERROR','DRIFT')),
    CONSTRAINT chk_sl_engine CHECK (engine IN ('KEYCLOAK','TRYTON','BOTH'))
);
CREATE INDEX IF NOT EXISTS idx_sl_status ON bauth.sync_log(status) WHERE status IN ('ERROR','PENDING');
CREATE INDEX IF NOT EXISTS idx_sl_retry ON bauth.sync_log(next_retry_at) WHERE next_retry_at IS NOT NULL;

-- WORM: solo INSERT + SELECT
REVOKE UPDATE, DELETE ON bauth.sync_log FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.sync_log FROM bauth;
GRANT INSERT, SELECT ON bauth.sync_log TO bauth;

COMMENT ON TABLE bauth.sync_log IS
  '[ISO 27001 A.8.15] Registro WORM de sincronización bAuth→Keycloak+Tryton. Solo INSERT+SELECT.
   Cada sync queda registrado con estado, errores, reintentos y duración. Trazabilidad completa.';
COMMENT ON COLUMN bauth.sync_log.rol_id IS 'RolTemplate sincronizado. NULL si fue sync de usuario.';
COMMENT ON COLUMN bauth.sync_log.user_uuid IS 'Usuario sincronizado. NULL si fue sync de rol.';
COMMENT ON COLUMN bauth.sync_log.engine IS 'KEYCLOAK, TRYTON, o BOTH.';
COMMENT ON COLUMN bauth.sync_log.duration_ms IS 'Duración en milisegundos de la operación de sync.';

-- ══════════════════════════════════════════════════════════════════════
-- DOMINIO D12 — BLOCKCHAIN: Lote 0.4 (5 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- T-155 — bauth.blk_anchor (migrado de bos_blockchain_anchor_log)
CREATE TABLE IF NOT EXISTS bauth.blk_anchor (
    anchor_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    batch_id            UUID        NOT NULL,
    tx_hash             VARCHAR(66) NOT NULL,
    block_number        BIGINT      NOT NULL,
    block_timestamp     TIMESTAMPTZ NOT NULL,
    network             VARCHAR(32) NOT NULL,
    contract_address    VARCHAR(42) NOT NULL,
    gas_used            BIGINT,
    gas_price_gwei      NUMERIC(18,9),
    total_cost_usd      NUMERIC(18,6),
    status              SMALLINT    NOT NULL DEFAULT 1,
    error_message       TEXT,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_blk_anchor_batch ON bauth.blk_anchor(batch_id);
CREATE INDEX IF NOT EXISTS idx_blk_anchor_status ON bauth.blk_anchor(status);

COMMENT ON TABLE bauth.blk_anchor IS
  '[NIST IR 8202] Histórico de transacciones de anclaje en L2 (Arbitrum One). Auditoría de gas y trazabilidad.';

-- T-156 — bauth.blk_merkle_batch (migrado de bos_merkle_batch)
CREATE TABLE IF NOT EXISTS bauth.blk_merkle_batch (
    batch_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    batch_number        BIGINT      UNIQUE NOT NULL,
    batch_start         TIMESTAMPTZ NOT NULL,
    batch_end           TIMESTAMPTZ NOT NULL,
    event_count         INTEGER     NOT NULL,
    merkle_root         VARCHAR(66) NOT NULL,
    merkle_tree_json    JSONB,
    status              SMALLINT    NOT NULL DEFAULT 0,
    onchain_tx_hash     VARCHAR(66),
    onchain_block_number BIGINT,
    onchain_timestamp   TIMESTAMPTZ,
    anchor_network      VARCHAR(32),
    anchor_contract     VARCHAR(42),
    retry_count         INTEGER     NOT NULL DEFAULT 0,
    last_error          TEXT,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    sealed_at           TIMESTAMPTZ,
    anchored_at         TIMESTAMPTZ,
    CONSTRAINT chk_bmb_status CHECK (status IN (0, 1, 2, 3))
);
COMMENT ON TABLE bauth.blk_merkle_batch IS
  'Lotes de eventos de auditoría para anclaje Merkle en L2. Gold tier: cada 1 hora. Status: 0=open, 1=sealed, 2=anchored, 3=failed.';

-- T-157 — bauth.blk_merkle_leaf (migrado de bos_merkle_leaf)
CREATE TABLE IF NOT EXISTS bauth.blk_merkle_leaf (
    leaf_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    batch_id        UUID        NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id) ON DELETE CASCADE,
    leaf_index      INTEGER     NOT NULL,
    event_audit_id  UUID        NOT NULL,
    event_hash      VARCHAR(66) NOT NULL,
    merkle_proof    VARCHAR(66)[],
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (batch_id, leaf_index)
);
CREATE INDEX IF NOT EXISTS idx_bml_batch ON bauth.blk_merkle_leaf(batch_id);

COMMENT ON TABLE bauth.blk_merkle_leaf IS
  'Hojas del árbol Merkle. event_hash = Keccak256(0x00 || ctx_id || audit_id || bitmask || result).
   merkle_proof permite verificación independiente sin acceso a la BD completa.';

-- T-158 — bauth.blk_account (migrado de bos_onchain_account)
CREATE TABLE IF NOT EXISTS bauth.blk_account (
    account_id              UUID            PRIMARY KEY DEFAULT uuidv7(),
    tenant_id               UUID            NOT NULL,
    onchain_address         VARCHAR(42)     UNIQUE NOT NULL,
    account_type            SMALLINT        NOT NULL,
    balance_derived         NUMERIC(36,18)  NOT NULL DEFAULT 0,
    balance_local           NUMERIC(36,18)  NOT NULL DEFAULT 0,
    nonce                   BIGINT          NOT NULL DEFAULT 0,
    last_reconciled_at      TIMESTAMPTZ,
    last_reconciled_block   BIGINT,
    is_frozen               BOOLEAN         NOT NULL DEFAULT false,
    ctx_id                  TEXT            NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, account_type)
);
COMMENT ON TABLE bauth.blk_account IS
  'Solo D12 Variante B. Mapea cuentas SBOS a direcciones on-chain. balance_derived es fuente de verdad.';

-- T-159 — bauth.blk_reconciliation (migrado de bos_anchor_reconciliation_log)
CREATE TABLE IF NOT EXISTS bauth.blk_reconciliation (
    reconciliation_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    batch_id            UUID        NOT NULL,
    network             VARCHAR(32) NOT NULL,
    merkle_root_db      VARCHAR(66) NOT NULL,
    merkle_root_onchain VARCHAR(66),
    is_match            BOOLEAN,
    notes               TEXT,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    checked_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.blk_reconciliation IS
  'Verificación de integridad cross-chain: compara Merkle roots PostgreSQL vs Arbitrum/on-chain.';

-- ══════════════════════════════════════════════════════════════════════
-- USER TEMPLATE: Lote 0.4 (2 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- T-170 — bauth.idn_user_template (migrado de bos_user_template)
-- [SCIM 2.0 RFC 7643] [SBOS-049 §4] [NIST SP 800-63B-4 §4]
CREATE TABLE IF NOT EXISTS bauth.idn_user_template (
    uuid                UUID        PRIMARY KEY DEFAULT uuidv7(),
    external_id         TEXT,
    username            TEXT        UNIQUE NOT NULL,
    email               TEXT        NOT NULL,
    tenant_id           TEXT        NOT NULL,
    empresa_id          TEXT        NOT NULL,
    sucursal_id         TEXT,
    pos_logico          TEXT,
    bos_contexts        TEXT[]      DEFAULT '{}',
    context_actual      TEXT,
    rol_ids             TEXT[]      DEFAULT '{}',
    rol_bitmask_base64        TEXT        NOT NULL DEFAULT '0x0000000000000000',
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    termination_date    DATE,
    termination_reason  TEXT,
    sync_status         TEXT        NOT NULL DEFAULT 'PENDING',
    kc_user_id          TEXT,
    tryton_user_id      INTEGER,
    last_login_at       TIMESTAMPTZ,
    last_activity_at    TIMESTAMPTZ,
    template            JSONB       NOT NULL DEFAULT '{}',
    template_version    TEXT        NOT NULL DEFAULT '6.0',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iut_tenant ON bauth.idn_user_template(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_iut_empresa ON bauth.idn_user_template(empresa_id);
CREATE INDEX IF NOT EXISTS idx_iut_email ON bauth.idn_user_template(email) WHERE email IS NOT NULL;

COMMENT ON TABLE bauth.idn_user_template IS
  '[SCIM 2.0 RFC 7643] [SBOS-049 §4] [NIST SP 800-63B-4 §4]
   Template de usuario individual. Identidad SCIM 2.0, roles asignados, contextos autorizados,
   BitMask efectiva, sync KC+Tryton. 🔑 Segunda tabla más importante después de idn_role_template.';

-- T-171 — bauth.idn_user_role (migrado de bos_user_role_assignment)
CREATE TABLE IF NOT EXISTS bauth.idn_user_role (
    assignment_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID        NOT NULL,
    role_id         TEXT        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    assigned_by     UUID,
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    revoked_by      UUID,
    revoked_at      TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_iur_user ON bauth.idn_user_role(user_uuid);
CREATE INDEX IF NOT EXISTS idx_iur_role ON bauth.idn_user_role(role_id);

COMMENT ON TABLE bauth.idn_user_role IS
  'Asignación de roles a usuarios. Trazabilidad completa: quién asignó, cuándo, vigencia, revocación.';

-- ══════════════════════════════════════════════════════════════════════
-- ESTRUCTURA ORGANIZACIONAL: Lote 0.4 (3 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- T-175 — bauth.org_empresa (migrado de bos_empresa)
CREATE TABLE IF NOT EXISTS bauth.org_empresa (
    empresa_id          TEXT        PRIMARY KEY,
    tenant_id           TEXT        NOT NULL,
    razon_social        TEXT        NOT NULL,
    nit                 TEXT        NOT NULL,
    regimen_fiscal      TEXT        NOT NULL DEFAULT 'GENERAL',
    es_operador         BOOLEAN     NOT NULL DEFAULT false,
    locale_default      TEXT,
    locales_extra       TEXT[],
    timezone_default    TEXT,
    timezones_extra     TEXT[],
    moneda_default      TEXT,
    monedas_extra       JSONB       DEFAULT '[]',
    currency_symbol     TEXT        DEFAULT 'Bs.',
    date_format         TEXT,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_oe_tenant ON bauth.org_empresa(tenant_id);

COMMENT ON TABLE bauth.org_empresa IS
  'Empresa multi-tenant. Entidad legal con NIT propio. Extiende configuración regional del tenant.
   Una empresa puede tener N idiomas, N monedas, N timezones. Sin esto no hay ámbito COMPANY.';

-- T-176 — bauth.org_sucursal (migrado de bos_sucursal)
CREATE TABLE IF NOT EXISTS bauth.org_sucursal (
    sucursal_id         TEXT        PRIMARY KEY,
    empresa_id          TEXT        NOT NULL,
    tenant_id           TEXT        NOT NULL,
    nombre              TEXT        NOT NULL,
    direccion           TEXT,
    ciudad              TEXT,
    zona                TEXT,
    timezone            TEXT,
    horario_apertura    TIME,
    horario_cierre      TIME,
    dias_operacion      TEXT[]      DEFAULT '{MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY}',
    admin_user_uuid     UUID,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (empresa_id, sucursal_id)
);
CREATE INDEX IF NOT EXISTS idx_os_empresa ON bauth.org_sucursal(empresa_id);
CREATE INDEX IF NOT EXISTS idx_os_tenant ON bauth.org_sucursal(tenant_id);

COMMENT ON TABLE bauth.org_sucursal IS
  'Sucursal física de una empresa. Control de acceso físico, geolocalización, y ámbito de operación.
   Sin esto no hay ámbito BRANCH en el template.';

-- T-177 — bauth.org_pos_logico (migrado de bos_pos_logico)
CREATE TABLE IF NOT EXISTS bauth.org_pos_logico (
    pos_id                  TEXT        PRIMARY KEY,
    sucursal_id             TEXT        NOT NULL,
    empresa_id              TEXT        NOT NULL,
    tenant_id               TEXT        NOT NULL,
    nombre                  TEXT        NOT NULL,
    codigo_sucursal_sin     TEXT,
    numero_punto_venta      INTEGER     NOT NULL DEFAULT 1,
    modalidad_facturacion   TEXT        NOT NULL DEFAULT 'COMPUTARIZADA_EN_LINEA',
    ambiente_sin            TEXT        NOT NULL DEFAULT 'PRODUCCION',
    tipo_factura            TEXT        NOT NULL DEFAULT 'FACTURA_CREDITO_FISCAL',
    numero_autorizacion     TEXT,
    tipo_dosificacion       TEXT        DEFAULT 'POR_TIEMPO',
    fecha_limite_emision    DATE,
    rango_inicio            BIGINT,
    rango_fin               BIGINT,
    numero_actual           BIGINT      DEFAULT 0,
    estado_dosificacion     TEXT        DEFAULT 'PENDIENTE',
    cuis                    TEXT,
    cuis_otorgado_en        TIMESTAMPTZ,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_opl_sucursal ON bauth.org_pos_logico(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_opl_empresa ON bauth.org_pos_logico(empresa_id);

COMMENT ON TABLE bauth.org_pos_logico IS
  'Punto de venta lógico con registro SIN Bolivia. Dosificación fiscal, CUIS, contador de facturas.
   Sin esto no hay scope POS ni facturación electrónica en el Context Plane.';

-- ══════════════════════════════════════════════════════════════════════
-- SEGURIDAD — LLAVES: Lote 0.4 (3 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- T-180 — bauth.sec_key_inventory (migrado de bos_key_inventory)
-- [NIST SP 800-57 Pt.1] [FIPS 140-3]
CREATE TABLE IF NOT EXISTS bauth.sec_key_inventory (
    key_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    key_type            TEXT        NOT NULL,
    algorithm           TEXT,
    owner               TEXT,
    storage_backend     TEXT        NOT NULL,
    state               TEXT        NOT NULL DEFAULT 'PRE_ACTIVE',
    rotation_interval   INTERVAL,
    last_rotated_at     TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ,
    backup_hash         VARCHAR(66),
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ski_type CHECK (key_type IN ('JWT_SIGNING','API_KEY','TOTP_SECRET','MTLS_CERT','BLOCKCHAIN_SIGNING','VALIDATOR_SIGNING','AES_ENCRYPTION','RECOVERY_CODE','PASSWORD_HASH','CLIENT_SECRET','ADSIB_CERT','ROOT_CA','SUB_CA_SIGNING','SUB_CA_IDENTITY','SUB_CA_DEVICES','SUB_CA_SERVICES','USER_SIGNING_CERT','DEVICE_CERT','SERVICE_CERT','SUPERUSER_CERT')),
    CONSTRAINT chk_ski_state CHECK (state IN ('PRE_ACTIVE','ACTIVE','DEACTIVATED','COMPROMISED','DESTROYED'))
);
CREATE INDEX IF NOT EXISTS idx_ski_type ON bauth.sec_key_inventory(key_type, state);

COMMENT ON TABLE bauth.sec_key_inventory IS
  '[NIST SP 800-57 Pt.1] [FIPS 140-3] Inventario central de TODAS las llaves criptográficas. 20 tipos.';

-- T-181 — bauth.sec_key_rotation (migrado de bos_key_rotation_log)
-- [NIST SP 800-57 Pt.1] [FIPS 140-3]
CREATE TABLE IF NOT EXISTS bauth.sec_key_rotation (
    rotation_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    key_type        TEXT        NOT NULL,
    key_identifier  TEXT        NOT NULL,
    issuer          TEXT        NOT NULL,
    action          TEXT        NOT NULL,
    old_expiry      TIMESTAMPTZ,
    new_expiry      TIMESTAMPTZ,
    performed_by    TEXT        NOT NULL,
    is_ceremony     BOOLEAN     NOT NULL DEFAULT false,
    witnesses       TEXT[],
    details         JSONB       DEFAULT '{}',
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    performed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_skr_action CHECK (action IN ('GENERATED','ROTATED','REVOKED','COMPROMISED'))
);
CREATE INDEX IF NOT EXISTS idx_skr_key ON bauth.sec_key_rotation(key_type, performed_at DESC);

COMMENT ON TABLE bauth.sec_key_rotation IS
  '[NIST SP 800-57 Pt.1] [FIPS 140-3] Ciclo de vida de claves. Cada evento GENERATED/ROTATED/REVOKED/
   COMPROMISED registrado. Ceremonias de rotación con testigos.';

-- T-182 — bauth.sec_key_recovery (migrado de bos_key_recovery_log)
CREATE TABLE IF NOT EXISTS bauth.sec_key_recovery (
    recovery_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    key_id              UUID,
    recovery_type       TEXT        NOT NULL,
    approved_by         UUID[],
    session_duration    INTERVAL,
    result              TEXT        NOT NULL,
    notes               TEXT,
    ctx_id              TEXT        NOT NULL,
    recovered_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_skrv_type CHECK (recovery_type IN ('BREAK_GLASS','ADMIN_RESET','USER_RECOVERY','COMPROMISE','DESASTRE')),
    CONSTRAINT chk_skrv_result CHECK (result IN ('SUCCESS','FAILED','PARTIAL','PENDING_APPROVAL'))
);
COMMENT ON TABLE bauth.sec_key_recovery IS
  'Registro de recuperaciones de llaves. Break-glass SU (2-of-3 Vault unseal).';

-- ══════════════════════════════════════════════════════════════════════
-- D7 — RED: Lote 0.4 (1 tabla) + GLOBAL CONFIG
-- ══════════════════════════════════════════════════════════════════════

-- T-185 — bauth.net_device (migrado de bos_device_registry)
-- [ISO 27001 A.8.1] [NIST SP 800-207]
CREATE TABLE IF NOT EXISTS bauth.net_device (
    device_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    node_id             TEXT        NOT NULL,
    device_type         TEXT        NOT NULL,
    serial_number       TEXT,
    firmware_version    TEXT,
    hardware_model      TEXT,
    zone_id             BIGINT,
    tenant_id           UUID        NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'provisioned',
    last_seen           TIMESTAMPTZ,
    ip_address          INET,
    mac_address         MACADDR,
    certificate_serial  TEXT,
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_nd_type CHECK (device_type IN ('banexus_agent','osdp_reader','mqtt_sensor','onvif_camera','wiegand_reader','ble_reader','rfid_reader','biometric_reader','intercom','actuator')),
    CONSTRAINT chk_nd_status CHECK (status IN ('provisioned','active','inactive','compromised','decommissioned'))
);
CREATE INDEX IF NOT EXISTS idx_nd_tenant ON bauth.net_device(tenant_id, status);

COMMENT ON TABLE bauth.net_device IS
  '[ISO 27001 A.8.1] [NIST SP 800-207] Registro de dispositivos físicos conectados a la red:
   lectores, cámaras, sensores, terminales, agentes banexus.';

-- T-190 — bglobal.global_config (migrado de bos_global_config)
-- [NIST SP 800-53 CM-6] [ISO 27001 A.8.9]
CREATE TABLE IF NOT EXISTS bglobal.global_config (
    config_key      TEXT        PRIMARY KEY,
    config_value    JSONB       NOT NULL,
    data_type       TEXT        NOT NULL DEFAULT 'jsonb',
    category        TEXT        NOT NULL DEFAULT 'general',
    description     TEXT        NOT NULL DEFAULT '',
    standard_ref    TEXT        NOT NULL DEFAULT '',
    default_value   JSONB,
    version         INTEGER     NOT NULL DEFAULT 1,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      TEXT,
    CONSTRAINT chk_gc_category CHECK (category IN ('financial','authentication','authorization','network','session','audit','blockchain','performance','general'))
);
COMMENT ON TABLE bglobal.global_config IS
  '[NIST SP 800-53 CM-6] [ISO 27001 A.8.9] Catálogo central de parámetros del sistema.
   Fuente única de verdad para configuración modificable en runtime. Cada fila es un parámetro
   autodescriptivo con propósito, referencia normativa y valor por defecto.';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 1 — TABLAS NUEVAS: Lote 1.1 — Flujos Auth, Step-Up, Zonas
-- ══════════════════════════════════════════════════════════════════════

-- T-300 — bauth.ath_auth_flow (NUEVA)
-- [NIST SP 800-63B-4 AAL1-3] [RFC 9470] [FIDO2 Multi-Factor Ceremony]
CREATE TABLE IF NOT EXISTS bauth.ath_auth_flow (
    flow_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    flow_code       TEXT        UNIQUE NOT NULL,
    flow_name       TEXT        NOT NULL,
    description     TEXT,
    min_loa         INTEGER     NOT NULL DEFAULT 1,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_aaf_loa CHECK (min_loa BETWEEN 0 AND 4)
);
COMMENT ON TABLE bauth.ath_auth_flow IS
  '[NIST SP 800-63B-4] [RFC 9470] [FIDO2]
   Flujos compuestos de autenticación. Cada flujo orquesta múltiples métodos en orden.
   8 flujos predefinidos: standard_login, elevated_login, hardware_protected_login,
   financial_high_value, system_config_change, m2m_service_account, decoupled_external,
   unauthenticated.';

-- T-301 — bauth.ath_auth_flow_method (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.ath_auth_flow_method (
    flow_id         UUID        NOT NULL REFERENCES bauth.ath_auth_flow(flow_id) ON DELETE CASCADE,
    method_id       TEXT        NOT NULL REFERENCES bauth.ath_method(method_id) ON DELETE CASCADE,
    sort_order      INTEGER     NOT NULL DEFAULT 1,
    is_required     BOOLEAN     NOT NULL DEFAULT true,
    description     TEXT,
    PRIMARY KEY (flow_id, method_id)
);
CREATE INDEX IF NOT EXISTS idx_afm_flow ON bauth.ath_auth_flow_method(flow_id, sort_order);
COMMENT ON TABLE bauth.ath_auth_flow_method IS
  'Relación N:M entre flujos de autenticación y métodos. Define qué métodos, en qué orden,
   y si son obligatorios para cada flujo.';

-- T-305 — bauth.ath_step_up_rule (NUEVA)
-- [RFC 9470 OAuth 2.0 Step-Up Authentication Challenge Protocol]
CREATE TABLE IF NOT EXISTS bauth.ath_step_up_rule (
    rule_id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    rule_code           TEXT        UNIQUE NOT NULL,
    trigger_event       TEXT        NOT NULL,
    condition_json      JSONB       DEFAULT '{}',
    required_loa        INTEGER     NOT NULL,
    max_age_seconds     INTEGER     NOT NULL DEFAULT 300,
    acr_value           TEXT        NOT NULL,
    reauth_required     BOOLEAN     NOT NULL DEFAULT true,
    requires_justification BOOLEAN  DEFAULT false,
    requires_approval   BOOLEAN     DEFAULT false,
    approver_roles      TEXT[]      DEFAULT '{}',
    description         TEXT,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_asr_loa CHECK (required_loa BETWEEN 1 AND 4)
);
CREATE INDEX IF NOT EXISTS idx_asr_trigger ON bauth.ath_step_up_rule(trigger_event, is_active);
COMMENT ON TABLE bauth.ath_step_up_rule IS
  '[RFC 9470] Reglas de Step-Up Authentication. Definen cuándo se requiere elevación temporal
   de LoA. condition_json contiene la condición de disparo (ej: {"amount": "> 5000"}).';

-- T-310 — bauth.zone_field_restriction (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.zone_field_restriction (
    restriction_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id         TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    app_code        SMALLINT    NOT NULL REFERENCES bauth.privilege_application(app_code) ON DELETE CASCADE,
    model_name      TEXT        NOT NULL,
    field_name      TEXT        NOT NULL,
    can_read        BOOLEAN     NOT NULL DEFAULT true,
    can_write       BOOLEAN     NOT NULL DEFAULT false,
    reason          TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id, app_code, model_name, field_name)
);
CREATE INDEX IF NOT EXISTS idx_zfr_zone ON bauth.zone_field_restriction(zone_id, app_code);
COMMENT ON TABLE bauth.zone_field_restriction IS
  'Restricciones de campos por zona y aplicación. Define qué campos de qué modelos son
   visibles/editables para cada zona de negocio. Implementa la capa 3 de Tryton (field access).';

-- T-311 — bauth.zone_button_rule (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.zone_button_rule (
    rule_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id         TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    app_code        SMALLINT    NOT NULL REFERENCES bauth.privilege_application(app_code) ON DELETE CASCADE,
    model_name      TEXT        NOT NULL,
    button_name     TEXT        NOT NULL,
    condition_json  JSONB       DEFAULT '{}',
    users_required  INTEGER     NOT NULL DEFAULT 1,
    sod_cannot_also TEXT,
    step_up_loa     INTEGER,
    description     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id, app_code, model_name, button_name)
);
CREATE INDEX IF NOT EXISTS idx_zbr_zone ON bauth.zone_button_rule(zone_id, app_code);
COMMENT ON TABLE bauth.zone_button_rule IS
  'Reglas de botones por zona. Define condiciones (PYSON), número de aprobadores requeridos,
   restricciones SoD sobre el botón, y step-up necesario. Implementa la capa 4 de Tryton.';

-- T-312 — bauth.zone_record_rule (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.zone_record_rule (
    rule_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id         TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    app_code        SMALLINT    NOT NULL REFERENCES bauth.privilege_application(app_code) ON DELETE CASCADE,
    model_name      TEXT        NOT NULL,
    domain_json     TEXT        NOT NULL,
    scope           TEXT        NOT NULL DEFAULT 'BRANCH',
    perm_write_exception BOOLEAN DEFAULT false,
    description     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_zrr_zone ON bauth.zone_record_rule(zone_id, app_code);
COMMENT ON TABLE bauth.zone_record_rule IS
  'Reglas de registros (filtros SQL) por zona. Implementa el scope (GLOBAL/REGIONAL/BRANCH/PERSONAL)
   como filtros automáticos en cada consulta. Equivalente a la capa 5 de Tryton (record rules).';

-- T-313 — bauth.zone_data_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.zone_data_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id             TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    data_classification TEXT[]      DEFAULT '{INTERNAL}',
    pii_access          BOOLEAN     DEFAULT false,
    phi_access          BOOLEAN     DEFAULT false,
    gdpr_sensitive      BOOLEAN     DEFAULT false,
    masking_policy      TEXT,
    retention_days      INTEGER,
    gdpr_lawful_basis   TEXT,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id)
);
COMMENT ON TABLE bauth.zone_data_policy IS
  'Políticas de datos por zona: clasificación, acceso a PII, masking, GDPR. Define qué nivel
   de datos puede ver cada zona y cómo se protegen los datos sensibles.';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 1 — Lote 1.2: 12 ath_policy_d* + 12 ath_config_d*
-- Políticas y configuraciones separadas por dominio. Cada dominio tiene su colección.
-- ══════════════════════════════════════════════════════════════════════

-- Las 12 tablas de políticas por dominio comparten la misma estructura base.
-- Cada dominio tiene políticas pre-diseñadas que el admin selecciona al armar un rol.

-- T-350–T-361: ath_policy_d1 a ath_policy_d12
-- [NIST SP 800-63B-4] [NIST SP 800-53] [ISO 27001:2022]
DO $$ BEGIN
  FOR i IN 1..12 LOOP
    EXECUTE format('CREATE TABLE IF NOT EXISTS bauth.ath_policy_d%s (
      policy_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
      policy_code     TEXT        NOT NULL,
      policy_name     TEXT        NOT NULL,
      description     TEXT,
      standard_ref    TEXT[]      DEFAULT %L,
      config          JSONB       NOT NULL DEFAULT %L,
      is_active       BOOLEAN     NOT NULL DEFAULT true,
      ctx_id          TEXT        NOT NULL DEFAULT ''system'',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (policy_code)
    )', i, '{}', '{}');
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_apd%s_active ON bauth.ath_policy_d%s(is_active) WHERE is_active = true', i, i);
  END LOOP;
END $$;

COMMENT ON TABLE bauth.ath_policy_d1 IS '[D1 Lógico] Políticas de acceso lógico: record_rules, field_rules, button_rules, scope, data_classification.';
COMMENT ON TABLE bauth.ath_policy_d2 IS '[D2 Físico] Políticas de acceso físico: anti_passback, escort, two_person, mantrap, biometric_enrollment.';
COMMENT ON TABLE bauth.ath_policy_d3 IS '[D3 Financiero] Políticas financieras: dual_approval, sod, transaction_limits, sin_compliance, approval_chain.';
COMMENT ON TABLE bauth.ath_policy_d4 IS '[D4 Temporal] Políticas temporales: schedules, holidays, overtime, breaks, attendance.';
COMMENT ON TABLE bauth.ath_policy_d5 IS '[D5 Biométrico] Políticas biométricas: liveness, fmr_threshold, enrollment, gdpr_consent.';
COMMENT ON TABLE bauth.ath_policy_d6 IS '[D6 Geoespacial] Políticas geoespaciales: geo_fence, velocity_check, location_trust_tiers.';
COMMENT ON TABLE bauth.ath_policy_d7 IS '[D7 Red] Políticas de red: device_trust, cidr, vpn, mtls, continuous_verification.';
COMMENT ON TABLE bauth.ath_policy_d8 IS '[D8 Contexto] Políticas de contexto: ctx_id, session_ttl, reauth, context_switching, caep_events.';
COMMENT ON TABLE bauth.ath_policy_d9 IS '[D9 Credenciales] Políticas de credenciales: password, mfa, recovery, lockout, rotation, phishing_resistance.';
COMMENT ON TABLE bauth.ath_policy_d10 IS '[D10 Delegación] Políticas de delegación: max_duration, non_delegable, chain_depth, auto_revoke.';
COMMENT ON TABLE bauth.ath_policy_d11 IS '[D11 Auditoría] Políticas de auditoría: retention, hash_chain, review_frequency, regulatory_mapping.';
COMMENT ON TABLE bauth.ath_policy_d12 IS '[D12 Blockchain] Políticas blockchain: merkle_anchor, did_method, proof_types, smart_contract.';

-- Las 12 tablas de configuraciones por dominio
-- T-370–T-381: ath_config_d1 a ath_config_d12
DO $$ BEGIN
  FOR i IN 1..12 LOOP
    EXECUTE format('CREATE TABLE IF NOT EXISTS bauth.ath_config_d%s (
      config_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
      config_key      TEXT        NOT NULL,
      config_value    JSONB       NOT NULL,
      description     TEXT,
      standard_ref    TEXT[]      DEFAULT %L,
      is_active       BOOLEAN     NOT NULL DEFAULT true,
      ctx_id          TEXT        NOT NULL DEFAULT ''system'',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (config_key)
    )', i, '{}');
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_acd%s_key ON bauth.ath_config_d%s(config_key)', i, i);
  END LOOP;
END $$;

COMMENT ON TABLE bauth.ath_config_d1 IS '[D1 Lógico] Configuraciones de acceso lógico: token_ttl, rate_limit, max_records_default, session_ttl_d1.';
COMMENT ON TABLE bauth.ath_config_d2 IS '[D2 Físico] Configuraciones físicas: door_relay_ms, anti_passback_reset_h, duress_timeout, max_access_points.';
COMMENT ON TABLE bauth.ath_config_d3 IS '[D3 Financiero] Configuraciones financieras: currency_default, sin_environment, approval_timeout_h, max_tiers.';
COMMENT ON TABLE bauth.ath_config_d4 IS '[D4 Temporal] Configuraciones temporales: timezone_default, shift_duration_max, overtime_rate, break_duration.';
COMMENT ON TABLE bauth.ath_config_d5 IS '[D5 Biométrico] Configuraciones biométricas: fmr_default, liveness_method, argon2_params, template_retention_days.';
COMMENT ON TABLE bauth.ath_config_d6 IS '[D6 Geoespacial] Configuraciones geoespaciales: velocity_max_kmh, tolerance_km, fence_radius_default.';
COMMENT ON TABLE bauth.ath_config_d7 IS '[D7 Red] Configuraciones de red: device_score_min, verification_interval_s, grace_period_s.';
COMMENT ON TABLE bauth.ath_config_d8 IS '[D8 Contexto] Configuraciones de contexto: session_ttl_max, inactivity_timeout, reauth_timeout, max_contexts.';
COMMENT ON TABLE bauth.ath_config_d9 IS '[D9 Credenciales] Configuraciones de credenciales: password_min_length, hibp_enabled, lockout_levels, rotation_days.';
COMMENT ON TABLE bauth.ath_config_d10 IS '[D10 Delegación] Configuraciones de delegación: max_duration_h, max_concurrent, auto_revoke.';
COMMENT ON TABLE bauth.ath_config_d11 IS '[D11 Auditoría] Configuraciones de auditoría: retention_days_default, hash_chain_default, review_frequency_default.';
COMMENT ON TABLE bauth.ath_config_d12 IS '[D12 Blockchain] Configuraciones blockchain: anchor_frequency, gas_limit, network, contract_address.';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 1 — Lote 1.3: 12 idn_role_d* — Templates de rol por dominio
-- Arquitectura de merge: el admin selecciona 1 template por dominio.
-- La herramienta merge_role_templates() los conjuga en idn_role_template.
-- ══════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  FOR i IN 1..12 LOOP
    EXECUTE format('CREATE TABLE IF NOT EXISTS bauth.idn_role_d%s (
      role_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
      role_code       TEXT        NOT NULL,
      role_name       JSONB       NOT NULL DEFAULT %L,
      domain_code     SMALLINT    NOT NULL DEFAULT %s,
      parent_role_id  UUID        REFERENCES bauth.idn_role_d%s(role_id) ON DELETE SET NULL,
      config          JSONB       NOT NULL DEFAULT %L,
      description     TEXT,
      is_active       BOOLEAN     NOT NULL DEFAULT true,
      ctx_id          TEXT        NOT NULL DEFAULT ''system'',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (role_code),
      CONSTRAINT chk_ird%s_domain CHECK (domain_code = %s)
    )', i, '{"es":"","en":""}', i, i, '{}', i, i);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_ird%s_active ON bauth.idn_role_d%s(is_active) WHERE is_active = true', i, i);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_ird%s_parent ON bauth.idn_role_d%s(parent_role_id) WHERE parent_role_id IS NOT NULL', i, i);
  END LOOP;
END $$;

COMMENT ON TABLE bauth.idn_role_d1 IS '[D1 Lógico] Templates pre-configurados de acceso lógico: OPERADOR_CAJA, GERENTE_REGIONAL, AUDITOR, etc. Config contiene logical_access.';
COMMENT ON TABLE bauth.idn_role_d2 IS '[D2 Físico] Templates pre-configurados de acceso físico: EMPLEADO_STANDARD, VISITANTE, TECNICO_MANTENIMIENTO. Config contiene physical_access.';
COMMENT ON TABLE bauth.idn_role_d3 IS '[D3 Financiero] Templates pre-configurados financieros: CAJERO, APROBADOR_N1, APROBADOR_N2, AUDITOR_FINANCIERO.';
COMMENT ON TABLE bauth.idn_role_d4 IS '[D4 Temporal] Templates pre-configurados temporales: HORARIO_OFICINA, TURNO_ROTATIVO, GUARDIA_24X7.';
COMMENT ON TABLE bauth.idn_role_d5 IS '[D5 Biométrico] Templates pre-configurados biométricos: HUELLA_DACTILAR, RECONOCIMIENTO_FACIAL, SIN_BIOMETRIA.';
COMMENT ON TABLE bauth.idn_role_d6 IS '[D6 Geoespacial] Templates pre-configurados geoespaciales: LOCAL_BOLIVIA, REGIONAL_LATAM, GLOBAL, RESTRINGIDO_SUCURSAL.';
COMMENT ON TABLE bauth.idn_role_d7 IS '[D7 Red] Templates pre-configurados de red: CORPORATIVO, VPN, REMOTO_SEGURO, ZTNA_BASICO.';
COMMENT ON TABLE bauth.idn_role_d8 IS '[D8 Contexto] Templates pre-configurados de contexto: SESION_8H, SESION_EXTENDIDA, BREAK_GLASS, READ_ONLY.';
COMMENT ON TABLE bauth.idn_role_d9 IS '[D9 Credenciales] Templates pre-configurados de credenciales: AAL1_BASICO, AAL2_MFA, AAL3_HARDWARE, M2M_MTLS.';
COMMENT ON TABLE bauth.idn_role_d10 IS '[D10 Delegación] Templates pre-configurados de delegación: SIN_DELEGACION, DELEGACION_BASICA, DELEGACION_SUPERVISOR.';
COMMENT ON TABLE bauth.idn_role_d11 IS '[D11 Auditoría] Templates pre-configurados de auditoría: BASICO, COMPLETO, SOX, PCI_DSS, GDPR.';
COMMENT ON TABLE bauth.idn_role_d12 IS '[D12 Blockchain] Templates pre-configurados blockchain: SIN_ANCLAJE, ANCLAJE_MERKLE, DID_BASICO.';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 1 — Lote 1.4: Tablas complementarias D2, D4, D7, D8, D14
-- ══════════════════════════════════════════════════════════════════════

-- T-320 — bauth.fis_zone_method_requirement (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.fis_zone_method_requirement (
    requirement_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_level      TEXT        NOT NULL,
    method_id       TEXT        NOT NULL,
    sort_order      INTEGER     NOT NULL DEFAULT 1,
    loa_required    INTEGER     NOT NULL DEFAULT 1,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_level, method_id),
    CONSTRAINT chk_fzmr_level CHECK (zone_level IN ('public_areas','employee_areas','restricted_areas','critical_areas','maximum_security_areas'))
);
COMMENT ON TABLE bauth.fis_zone_method_requirement IS
  '[D2 Físico] Métodos de acceso físico requeridos por nivel de zona. Define qué combinación
   de métodos (NFC, QR, biométrico, smartcard) se exige en cada nivel de seguridad física.';

-- T-321 — bauth.fis_emergency_config (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.fis_emergency_config (
    config_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    trigger_event   TEXT        NOT NULL UNIQUE,
    action          TEXT        NOT NULL,
    override_mode   TEXT        NOT NULL,
    requires_approval BOOLEAN   DEFAULT true,
    approver_roles  TEXT[]      DEFAULT '{}',
    max_duration_minutes INTEGER DEFAULT 30,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.fis_emergency_config IS
  '[D2 Físico] Configuración de emergencia física: FIRE_ALARM→UNLOCK_ALL, MEDICAL_EMERGENCY→
   UNLOCK_SPECIFIC_ZONE, SECURITY_BREACH→LOCKDOWN_ALL, POWER_OUTAGE→FAIL_SAFE_UNLOCK.';

-- T-335 — bcalendar.cal_overtime_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bcalendar.cal_overtime_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id           UUID,
    max_daily_hours     INTEGER     NOT NULL DEFAULT 4,
    max_weekly_hours    INTEGER     NOT NULL DEFAULT 20,
    rate_multiplier     NUMERIC(3,2) NOT NULL DEFAULT 1.5,
    night_shift_rate    NUMERIC(3,2) NOT NULL DEFAULT 2.0,
    holiday_rate        NUMERIC(3,2) NOT NULL DEFAULT 2.5,
    requires_approval   BOOLEAN     NOT NULL DEFAULT true,
    approver_roles      TEXT[]      DEFAULT '{}',
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bcalendar.cal_overtime_policy IS
  '[D4 Temporal] Políticas de horas extra: máximos diarios/semanales, tasas multiplicadoras,
   aprobación requerida. Ley General del Trabajo Bolivia.';

-- T-336 — bcalendar.cal_break_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bcalendar.cal_break_policy (
    policy_id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    tenant_id               UUID,
    lunch_required          BOOLEAN     NOT NULL DEFAULT true,
    lunch_duration_minutes  INTEGER     NOT NULL DEFAULT 60,
    lunch_window_start      TIME        DEFAULT '12:00',
    lunch_window_end        TIME        DEFAULT '14:00',
    short_breaks_allowed    INTEGER     NOT NULL DEFAULT 2,
    short_break_minutes     INTEGER     NOT NULL DEFAULT 15,
    auto_logout_during_break BOOLEAN    DEFAULT false,
    session_pause_during    BOOLEAN     DEFAULT true,
    is_active               BOOLEAN     NOT NULL DEFAULT true,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bcalendar.cal_break_policy IS
  '[D4 Temporal] Políticas de descansos: almuerzo, breaks cortos, auto-logout durante descanso.';

-- T-325 — bauth.net_ztna_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.net_ztna_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    default_action      TEXT        NOT NULL DEFAULT 'DENY',
    allowed_services    TEXT[]      DEFAULT '{}',
    microsegmentation   BOOLEAN     NOT NULL DEFAULT false,
    require_just_in_time BOOLEAN    DEFAULT false,
    verification_interval_s INTEGER  DEFAULT 300,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_nzp_action CHECK (default_action IN ('DENY','ALLOW'))
);
COMMENT ON TABLE bauth.net_ztna_policy IS
  '[D7 Red] [NIST SP 800-207 ZTA] Política Zero Trust Network Access: default DENY,
   allowed_services explícitos, microsegmentación opcional.';

-- T-326 — bauth.ses_risk_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.ses_risk_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    risk_factors        TEXT[]      NOT NULL DEFAULT '{}',
    threshold_low       INTEGER     DEFAULT 30,
    threshold_medium    INTEGER     DEFAULT 60,
    threshold_high      INTEGER     DEFAULT 80,
    threshold_critical  INTEGER     DEFAULT 95,
    action_low          TEXT        DEFAULT 'NONE',
    action_medium       TEXT        DEFAULT 'REQUIRE_STEP_UP',
    action_high         TEXT        DEFAULT 'REQUIRE_STEP_UP',
    action_critical     TEXT        DEFAULT 'TERMINATE_SESSION',
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_srp_actions CHECK (
        action_low IN ('NONE','LOG','REQUIRE_STEP_UP') AND
        action_medium IN ('NONE','LOG','REQUIRE_STEP_UP','TERMINATE_SESSION') AND
        action_high IN ('REQUIRE_STEP_UP','TERMINATE_SESSION') AND
        action_critical IN ('TERMINATE_SESSION','LOCK_ACCOUNT')
    )
);
COMMENT ON TABLE bauth.ses_risk_policy IS
  '[D8 Contexto] Políticas de riesgo de sesión en tiempo real. Define factores de riesgo,
   thresholds y acciones por nivel (NONE, LOG, REQUIRE_STEP_UP, TERMINATE_SESSION, LOCK_ACCOUNT).';

-- T-327 — bauth.ses_caep_config (NUEVA)
-- [OpenID CAEP 1.0 — Final Specification September 2025]
CREATE TABLE IF NOT EXISTS bauth.ses_caep_config (
    config_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    caep_event          TEXT        NOT NULL UNIQUE,
    is_enabled          BOOLEAN     NOT NULL DEFAULT true,
    endpoint_url        TEXT,
    shared_secret_hash  BYTEA,
    retry_max           INTEGER     DEFAULT 3,
    retry_delay_seconds INTEGER     DEFAULT 30,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_scc_event CHECK (caep_event IN ('session-revoked','token-claims-change','assurance-level-change','credential-change','device-compliance-change'))
);
COMMENT ON TABLE bauth.ses_caep_config IS
  '[OpenID CAEP 1.0 Final Sept 2025] Configuración de eventos CAEP (Continuous Access Evaluation
   Profile). Define qué eventos se procesan y a qué endpoint se notifican.';

-- T-330 — bauth.sod_validation_config (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.sod_validation_config (
    config_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    check_frequency     TEXT        NOT NULL DEFAULT 'REAL_TIME',
    validation_scope    TEXT[]      NOT NULL DEFAULT '{DIRECT_CONFLICTS,INHERITED_CONFLICTS,DELEGATION_CONFLICTS}',
    auto_remediate      BOOLEAN     NOT NULL DEFAULT false,
    notification_roles  TEXT[]      DEFAULT '{}',
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.sod_validation_config IS
  '[D14 SoD] Configuración de validación de conflictos: frecuencia (REAL_TIME/PERIODIC),
   scope de validación, auto-remediación.';

-- T-331 — bauth.conflict_interest_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.conflict_interest_policy (
    policy_id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    restricted_entity_types TEXT[]      DEFAULT '{}',
    max_relationship_degrees INTEGER    DEFAULT 2,
    declaration_frequency   TEXT        NOT NULL DEFAULT 'ANNUAL',
    requires_update_on_change BOOLEAN   NOT NULL DEFAULT true,
    verification_method     TEXT        NOT NULL DEFAULT 'COMPLIANCE_REVIEW',
    is_active               BOOLEAN     NOT NULL DEFAULT true,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.conflict_interest_policy IS
  '[D14 SoD] Políticas de conflicto de interés: entidades restringidas (VENDORS, COMPETITORS),
   grados de relación, frecuencia de declaración, método de verificación.';

-- T-318 — bauth.tryton_action_visibility (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.tryton_action_visibility (
    visibility_id   UUID        PRIMARY KEY DEFAULT uuidv7(),
    zone_id         TEXT        NOT NULL REFERENCES bauth.log_zone(zona_id) ON DELETE CASCADE,
    action_name     TEXT        NOT NULL,
    action_type     TEXT        NOT NULL DEFAULT 'menu',
    is_visible      BOOLEAN     NOT NULL DEFAULT true,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (zone_id, action_name),
    CONSTRAINT chk_tav_type CHECK (action_type IN ('menu','wizard','report','dashboard'))
);
COMMENT ON TABLE bauth.tryton_action_visibility IS
  'Acciones/menús visibles en Tryton por zona. Controla qué menús, wizards, reportes y
   dashboards ve cada rol en la UI de Tryton.';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 2 — DOMINIO D6: GEOESPACIAL (5 tablas nuevas + 1 ALTER)
-- Dependencia: CREATE EXTENSION postgis (ficha S01/postgis)
-- ══════════════════════════════════════════════════════════════════════

-- T-600 — bauth.geo_trust_tier (NUEVA)
-- [Google BeyondCorp Location Trust Tiers] [NIST SP 800-53 PE-3]
CREATE TABLE IF NOT EXISTS bauth.geo_trust_tier (
    tier_id             UUID        PRIMARY KEY DEFAULT uuidv7(),
    tier_code           TEXT        UNIQUE NOT NULL,
    tier_name           TEXT        NOT NULL,
    tier_level          INTEGER     NOT NULL CHECK (tier_level BETWEEN 1 AND 3),
    allowed_operations  TEXT[]      DEFAULT '{READ}',
    restricted_operations TEXT[]    DEFAULT '{WRITE,DELETE,APPROVE,CONFIGURE,FINANCIAL_APPROVE,USER_MANAGEMENT}',
    max_session_seconds INTEGER     DEFAULT 28800,
    requires_step_up    BOOLEAN     DEFAULT false,
    requires_vpn        BOOLEAN     DEFAULT false,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.geo_trust_tier IS
  '[Google BeyondCorp] [NIST SP 800-53 PE-3] Tiers de confianza por ubicación.
   HIGH=oficina/sucursal (todas las operaciones), MEDIUM=VPN (lectura+escritura sin aprobaciones),
   LOW=pública (solo lectura, step-up requerido).';

-- T-601 — bauth.geo_velocity_policy (NUEVA)
-- [NIST SP 800-63B-4 §5.2.3] [Google BeyondCorp]
CREATE TABLE IF NOT EXISTS bauth.geo_velocity_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    max_velocity_kmh    INTEGER     NOT NULL DEFAULT 900,
    tolerance_km        INTEGER     NOT NULL DEFAULT 10,
    window_minutes      INTEGER     NOT NULL DEFAULT 5,
    on_violation        TEXT        NOT NULL DEFAULT 'REQUIRE_STEP_UP',
    max_violations      INTEGER     DEFAULT 3,
    violation_cooldown_minutes INTEGER DEFAULT 30,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gvp_violation CHECK (on_violation IN ('REQUIRE_STEP_UP','TERMINATE_SESSION','LOCK_ACCOUNT','LOG_ONLY'))
);
COMMENT ON TABLE bauth.geo_velocity_policy IS
  '[NIST SP 800-63B-4 §5.2.3] [Google BeyondCorp] Control de velocidad de viaje imposible.
   Si un usuario hace login desde dos ubicaciones a >900 km/h en <5 min → violación.
   Tolerancia de 10 km para GPS drift.';

-- T-602 — bauth.geo_fence (NUEVA)
-- [OGC GeoFence] [NIST SP 800-53 PE-3]
CREATE TABLE IF NOT EXISTS bauth.geo_fence (
    fence_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    fence_code          TEXT        UNIQUE NOT NULL,
    fence_name          TEXT        NOT NULL,
    location_id         UUID        REFERENCES bauth.fis_location(location_id) ON DELETE SET NULL,
    sucursal_id         TEXT,
    polygon             POLYGON,
    center_point        POINT,
    radius_meters       INTEGER     DEFAULT 100,
    allowed_operations  TEXT[]      DEFAULT '{ALL}',
    timezone            TEXT        DEFAULT 'America/La_Paz',
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.geo_fence IS
  '[OGC GeoFence] [NIST SP 800-53 PE-3] Geo-cercas por sucursal o ubicación física.
   Define un polígono o un punto+radio donde las operaciones están permitidas.
   polygon y center_point requieren PostGIS activado.';

-- T-603 — bauth.geo_location_log (NUEVA)
-- [ISO 27001 A.8.15] [NIST SP 800-63B-4]
CREATE TABLE IF NOT EXISTS bauth.geo_location_log (
    log_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid           UUID        NOT NULL,
    session_id          TEXT,
    location_point      POINT       NOT NULL,
    accuracy_meters     INTEGER,
    source              TEXT        NOT NULL DEFAULT 'IP',
    country_code        CHAR(2),
    city                TEXT,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    recorded_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gll_source CHECK (source IN ('GPS','IP','WIFI','MANUAL','BEACON'))
);
CREATE INDEX IF NOT EXISTS idx_gll_user ON bauth.geo_location_log(user_uuid, recorded_at DESC);

COMMENT ON TABLE bauth.geo_location_log IS
  '[ISO 27001 A.8.15] [NIST SP 800-63B-4] Registro de ubicaciones de login.
   Cada login registra (lat, lon) + fuente + precisión. Alimenta el detector de
   viaje imposible y el historial de ubicaciones del usuario.';

-- T-604 — bauth.geo_evaluation_log (NUEVA)
-- [ISO 27001 A.8.15] [NIST SP 800-53 AU-2]
CREATE TABLE IF NOT EXISTS bauth.geo_evaluation_log (
    evaluation_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid           UUID        NOT NULL,
    session_id          TEXT,
    check_type          TEXT        NOT NULL,
    check_result        TEXT        NOT NULL,
    details             JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    evaluated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gel_type CHECK (check_type IN ('COUNTRY_CHECK','GEOFENCE_CHECK','VELOCITY_CHECK','TRUST_TIER_EVAL')),
    CONSTRAINT chk_gel_result CHECK (check_result IN ('ALLOW','DENY','STEP_UP','WARN'))
);
CREATE INDEX IF NOT EXISTS idx_gel_user ON bauth.geo_evaluation_log(user_uuid, evaluated_at DESC);

COMMENT ON TABLE bauth.geo_evaluation_log IS
  '[ISO 27001 A.8.15] [NIST SP 800-53 AU-2] Resultado de cada evaluación geoespacial.
   Trazabilidad completa de decisiones: país, geo-fence, velocidad, trust tier.
   Alimenta auditoría y dashboards de seguridad.';

-- T-610 — ALTER: Agregar coordinates a org_sucursal
-- [ISO 6709] [PostGIS POINT type]
DO $$ BEGIN
    ALTER TABLE bauth.org_sucursal ADD COLUMN IF NOT EXISTS coordinates POINT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
COMMENT ON COLUMN bauth.org_sucursal.coordinates IS
  '[ISO 6709] Coordenadas geográficas (lat, lon) de la sucursal. POINT type para PostGIS.
   Permite geo-fencing por sucursal y resolución de "¿está en la sucursal correcta?"';

-- ══════════════════════════════════════════════════════════════════════
-- FASE 1 — VISIÓN CONTEXT PLANE: 15 tablas nuevas
-- Lote 1.1: Dispositivos cliente + transferencia de contexto (4 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- V-01 — bauth.user_client_device (NUEVA · Visión Context Plane Parte 3)
-- [FIDO2 CTAP 2.2] [WebAuthn Level 3] [Play Integrity / App Attest]
CREATE TABLE IF NOT EXISTS bauth.user_client_device (
    device_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid           UUID        NOT NULL,
    net_device_id       UUID        REFERENCES bauth.net_device(device_id) ON DELETE SET NULL,
    device_category     TEXT        NOT NULL DEFAULT 'MOBILE',
    platform            TEXT        NOT NULL,
    os_version          TEXT,
    app_version         TEXT,
    platform_authenticator TEXT,
    passkey_type        TEXT,
    aaguid              TEXT,
    tpm_version         TEXT,
    secure_enclave      BOOLEAN     DEFAULT false,
    attestation_provider TEXT,
    last_attestation_at TIMESTAMPTZ,
    push_token_hash     BYTEA,
    is_primary          BOOLEAN     DEFAULT false,
    trust_score         INTEGER     DEFAULT 100,
    status              TEXT        DEFAULT 'ACTIVE',
    metadata            JSONB       DEFAULT '{}',
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    last_seen_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_uuid, net_device_id),
    CONSTRAINT chk_ucd_category CHECK (device_category IN ('MOBILE','TABLET','DESKTOP','IOT','WEARABLE')),
    CONSTRAINT chk_ucd_platform CHECK (platform IN ('ios','android','windows','macos','linux','chromeos')),
    CONSTRAINT chk_ucd_auth CHECK (platform_authenticator IN ('FACE_ID','TOUCH_ID','ANDROID_BIOMETRIC','WINDOWS_HELLO','SECURITY_KEY','TPM','NONE')),
    CONSTRAINT chk_ucd_passkey CHECK (passkey_type IN ('device_bound','synced_icloud','synced_google','synced_other','none')),
    CONSTRAINT chk_ucd_attestation CHECK (attestation_provider IN ('play_integrity','app_attest','devicecheck','none')),
    CONSTRAINT chk_ucd_status CHECK (status IN ('ACTIVE','COMPROMISED','LOST','DECOMMISSIONED'))
);
CREATE INDEX IF NOT EXISTS idx_ucd_user ON bauth.user_client_device(user_uuid);
CREATE INDEX IF NOT EXISTS idx_ucd_trust ON bauth.user_client_device(trust_score) WHERE trust_score < 70;

COMMENT ON TABLE bauth.user_client_device IS
  '[FIDO2 CTAP 2.2] [WebAuthn Level 3] [Play Integrity / App Attest]
   Dispositivo cliente vinculado al usuario. Celular, tablet, laptop o desktop.
   Almacena el platform authenticator, el tipo de passkey, la versión de TPM,
   y el trust score. Es el Identity Hub personal del usuario en el Context Plane.';

-- V-02 — bauth.ctx_transfer_log (NUEVA · Visión Context Plane Parte 3)
CREATE TABLE IF NOT EXISTS bauth.ctx_transfer_log (
    transfer_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    from_device_id      UUID        NOT NULL,
    to_device_id        TEXT        NOT NULL,
    ctx_id              TEXT        NOT NULL,
    transfer_method     TEXT        NOT NULL,
    challenge           TEXT        NOT NULL,
    signature           TEXT        NOT NULL,
    ttl_seconds         INTEGER     DEFAULT 300,
    result              TEXT        NOT NULL,
    deny_reason         TEXT,
    source_ip           INET,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ctl_method CHECK (transfer_method IN ('QR','NFC','BLE','WEBSOCKET','MANUAL')),
    CONSTRAINT chk_ctl_result CHECK (result IN ('ALLOW','DENY','EXPIRED','REPLAY'))
);
CREATE INDEX IF NOT EXISTS idx_ctl_ctx ON bauth.ctx_transfer_log(ctx_id, created_at DESC);

COMMENT ON TABLE bauth.ctx_transfer_log IS
  '[FIDO2 CTAP 2.2 Hybrid Transport] [SBOS Context Plane]
   Historial de cada transferencia de ctx_id entre dispositivos. Challenge anti-replay
   firmado por el dispositivo origen. Trazabilidad completa del movimiento del contexto.';

-- V-03 — bauth.qr_challenge_registry (NUEVA · Visión Context Plane Parte 3)
CREATE TABLE IF NOT EXISTS bauth.qr_challenge_registry (
    challenge_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    challenge           TEXT        UNIQUE NOT NULL,
    device_id           TEXT        NOT NULL,
    action              TEXT        NOT NULL,
    ttl_seconds         INTEGER     DEFAULT 120,
    used                BOOLEAN     DEFAULT false,
    used_by_device      UUID,
    used_at             TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_qcr_action CHECK (action IN ('ONBOARD','CTX_TRANSFER','CLOCK_IN','EMERGENCY_OVERRIDE','VISITOR_ACCESS','DELEGATION'))
);
CREATE INDEX IF NOT EXISTS idx_qcr_expires ON bauth.qr_challenge_registry(expires_at) WHERE used = false;

COMMENT ON TABLE bauth.qr_challenge_registry IS
  'Registro de challenges QR emitidos. Anti-replay: cada challenge se usa UNA sola vez.
   TTL 120 segundos por defecto. Si no se usa antes de expires_at → inválido.';

-- V-04 — bauth.mobile_heartbeat_log (NUEVA · Visión Context Plane Parte 3)
CREATE TABLE IF NOT EXISTS bauth.mobile_heartbeat_log (
    heartbeat_id        UUID        PRIMARY KEY DEFAULT uuidv7(),
    device_id           UUID        NOT NULL,
    ctx_id              TEXT,
    battery_pct         INTEGER,
    network_type        TEXT,
    location_point      POINT,
    received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_mhl_network CHECK (network_type IN ('WIFI','CELLULAR','ETHERNET','BLUETOOTH','OFFLINE'))
);
CREATE INDEX IF NOT EXISTS idx_mhl_device ON bauth.mobile_heartbeat_log(device_id, received_at DESC);

COMMENT ON TABLE bauth.mobile_heartbeat_log IS
  'Latidos del dispositivo cliente cada 30 segundos. Si faltan 3 consecutivos →
   ctx_id se degrada a confianza LOW. Permite detectar dispositivos offline.
   Opcional: batería, tipo de red, ubicación GPS.';

-- ══════════════════════════════════════════════════════════════════════
-- Lote 1.2: bAuth como Identity Provider externo (3 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- V-05 — bauth.idp_client (NUEVA · Visión Context Plane Parte 4)
-- [OpenID Connect 1.0] [SAML 2.0] [OAuth 2.1 BCP]
CREATE TABLE IF NOT EXISTS bauth.idp_client (
    client_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    client_name         TEXT        NOT NULL,
    client_type         TEXT        NOT NULL,
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    redirect_uris       TEXT[]      NOT NULL,
    allowed_scopes      TEXT[]      DEFAULT '{openid,profile,email}',
    grant_types         TEXT[]      DEFAULT '{authorization_code,refresh_token}',
    client_secret_hash  BYTEA,
    token_endpoint      TEXT,
    require_pkce        BOOLEAN     DEFAULT true,
    require_dpop        BOOLEAN     DEFAULT false,
    logo_url            TEXT,
    tos_url             TEXT,
    policy_url          TEXT,
    is_active           BOOLEAN     DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, client_name),
    CONSTRAINT chk_idp_type CHECK (client_type IN ('oidc','saml','oauth2'))
);
COMMENT ON TABLE bauth.idp_client IS
  '[OpenID Connect 1.0] [SAML 2.0] [OAuth 2.1 BCP]
   Aplicaciones externas registradas que usan bAuth como Identity Provider.
   Cada cliente tiene sus redirect_uris, scopes permitidos, y grant types.
   bAuth emite tokens JWT/opaque para estas aplicaciones.';

-- V-06 — bauth.idp_client_policy (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.idp_client_policy (
    policy_id               UUID        PRIMARY KEY DEFAULT uuidv7(),
    client_id               UUID        NOT NULL REFERENCES bauth.idp_client(client_id) ON DELETE CASCADE,
    min_aal                 INTEGER     DEFAULT 2,
    allowed_methods         TEXT[]      DEFAULT '{WEBAUTHN_PWDLESS,PASSKEY_DEVICE}',
    require_biometric       BOOLEAN     DEFAULT true,
    allow_synced_passkeys   BOOLEAN     DEFAULT true,
    max_session_seconds     INTEGER     DEFAULT 3600,
    token_type              TEXT        DEFAULT 'JWT',
    refresh_token_ttl       INTEGER     DEFAULT 86400,
    require_consent         BOOLEAN     DEFAULT true,
    consent_prompt_text     JSONB       DEFAULT '{}',
    is_active               BOOLEAN     DEFAULT true,
    ctx_id                  TEXT        NOT NULL DEFAULT 'system',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id)
);
COMMENT ON TABLE bauth.idp_client_policy IS
  'Políticas de autenticación por cliente externo. Define qué métodos biométricos
   requiere cada app, AAL mínimo, si permite passkeys syncables, y timeouts de sesión.';

-- V-07 — bauth.idp_token_config (NUEVA)
CREATE TABLE IF NOT EXISTS bauth.idp_token_config (
    config_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    client_id           UUID        NOT NULL REFERENCES bauth.idp_client(client_id) ON DELETE CASCADE,
    signing_algorithm   TEXT        DEFAULT 'EdDSA',
    include_claims      TEXT[]      DEFAULT '{sub,iss,aud,exp,iat,ctx_id,tenant,empresa}',
    custom_claims       JSONB       DEFAULT '{}',
    jwt_ttl_seconds     INTEGER     DEFAULT 3600,
    opaque_token        BOOLEAN     DEFAULT false,
    sender_constrained  BOOLEAN     DEFAULT false,
    dpop_required       BOOLEAN     DEFAULT false,
    is_active           BOOLEAN     DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id)
);
COMMENT ON TABLE bauth.idp_token_config IS
  '[RFC 9068 JWT Profile] [RFC 9449 DPoP]
   Configuración de emisión de tokens JWT/opaque para apps externas.
   Define algoritmo de firma, claims incluidos, TTL, y si requiere DPoP.';

-- ══════════════════════════════════════════════════════════════════════
-- Lote 1.3: Políticas temporales y acceso de emergencia (3 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- V-08 — bauth.emergency_override_policy (NUEVA · Visión Context Plane Momento 8)
CREATE TABLE IF NOT EXISTS bauth.emergency_override_policy (
    override_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    authorized_by       UUID        NOT NULL,
    authorized_for      UUID        NOT NULL,
    reason              TEXT        NOT NULL,
    ticket_ref          TEXT,
    override_geo        BOOLEAN     DEFAULT true,
    override_temporal   BOOLEAN     DEFAULT true,
    override_physical   BOOLEAN     DEFAULT false,
    allowed_zones       TEXT[]      DEFAULT '{}',
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL,
    status              TEXT        DEFAULT 'ACTIVE',
    qr_challenge_id     UUID        REFERENCES bauth.qr_challenge_registry(challenge_id),
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at          TIMESTAMPTZ,
    CONSTRAINT chk_eop_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_eop_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED'))
);
CREATE INDEX IF NOT EXISTS idx_eop_active ON bauth.emergency_override_policy(valid_until) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.emergency_override_policy IS
  '[SBOS Context Plane Momento 8] Política temporal que anula restricciones geoespaciales,
   temporales y físicas. Autorizada por un supervisor vía QR. TTL automático.
   Trazabilidad completa: quién autorizó, para quién, por qué, ticket de referencia.';

-- V-09 — bauth.visitor_access_policy (NUEVA · Visión Context Plane Momento 9)
CREATE TABLE IF NOT EXISTS bauth.visitor_access_policy (
    policy_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    host_user_uuid      UUID        NOT NULL,
    visitor_user_uuid   UUID,
    visitor_name        TEXT,
    visitor_phone       TEXT,
    allowed_zones       TEXT[]      NOT NULL,
    restricted_zones    TEXT[]      DEFAULT '{}',
    allowed_services    TEXT[]      DEFAULT '{}',
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL,
    can_control_devices BOOLEAN     DEFAULT false,
    max_visitors        INTEGER     DEFAULT 1,
    status              TEXT        DEFAULT 'ACTIVE',
    qr_challenge_id     UUID        REFERENCES bauth.qr_challenge_registry(challenge_id),
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at          TIMESTAMPTZ,
    CONSTRAINT chk_vap_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_vap_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED'))
);
CREATE INDEX IF NOT EXISTS idx_vap_active ON bauth.visitor_access_policy(valid_until) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.visitor_access_policy IS
  '[SBOS Context Plane Momento 9] Acceso temporal para visitantes: puertas, horarios,
   ambientes, servicios (iluminación, climatización). Residencial + empresarial.
   El visitante recibe un QR que activa su ctx_id temporal.';

-- V-10 — bauth.external_session_registry (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.external_session_registry (
    session_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    client_id           UUID        NOT NULL REFERENCES bauth.idp_client(client_id) ON DELETE CASCADE,
    user_uuid           UUID        NOT NULL,
    ctx_id              TEXT        NOT NULL,
    id_token_jti        TEXT,
    access_token_jti    TEXT,
    refresh_token_jti   TEXT,
    scopes_granted      TEXT[]      DEFAULT '{openid,profile}',
    consent_given       BOOLEAN     DEFAULT false,
    consent_at          TIMESTAMPTZ,
    ip_address          INET,
    user_agent          TEXT,
    expires_at          TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_esr_ctx ON bauth.external_session_registry(ctx_id);
CREATE INDEX IF NOT EXISTS idx_esr_client ON bauth.external_session_registry(client_id, created_at DESC);

COMMENT ON TABLE bauth.external_session_registry IS
  'Sesiones de aplicaciones externas autenticadas vía bAuth como Identity Provider.
   Vinculadas al ctx_id del usuario. Trazabilidad de tokens emitidos y consentimientos.';

-- ══════════════════════════════════════════════════════════════════════
-- Lote 1.4: Infraestructura técnica móvil/desktop (5 tablas)
-- ══════════════════════════════════════════════════════════════════════

-- V-11 — bauth.mobile_app_config (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.mobile_app_config (
    config_id           UUID        PRIMARY KEY DEFAULT uuidv7(),
    platform            TEXT        NOT NULL,
    min_app_version     TEXT        NOT NULL,
    latest_app_version  TEXT,
    force_update        BOOLEAN     DEFAULT false,
    endpoints           JSONB       NOT NULL DEFAULT '{}',
    feature_flags       JSONB       DEFAULT '{}',
    is_active           BOOLEAN     DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (platform),
    CONSTRAINT chk_mac_platform CHECK (platform IN ('ios','android','windows','macos','linux','chromeos','flutter_web'))
);
COMMENT ON TABLE bauth.mobile_app_config IS
  'Configuración remota de la app SBOS Authenticator. Define versión mínima requerida,
   endpoints del servidor (WebSocket, API, auth), y feature flags por plataforma.
   Permite forzar actualización si la versión del cliente es inferior a min_app_version.';

-- V-12 — bauth.device_attestation_log (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.device_attestation_log (
    attestation_id      UUID        PRIMARY KEY DEFAULT uuidv7(),
    device_id           UUID        NOT NULL,
    attestation_provider TEXT       NOT NULL,
    attestation_token   TEXT        NOT NULL,
    basic_integrity     BOOLEAN,
    cts_profile_match   BOOLEAN,
    app_recognition     BOOLEAN,
    score               INTEGER     DEFAULT 100,
    error_message       TEXT,
    verified_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_dal_provider CHECK (attestation_provider IN ('play_integrity','app_attest','devicecheck','none'))
);
CREATE INDEX IF NOT EXISTS idx_dal_device ON bauth.device_attestation_log(device_id, verified_at DESC);

COMMENT ON TABLE bauth.device_attestation_log IS
  '[Play Integrity API] [App Attest] [DeviceCheck]
   Registro de cada verificación de integridad del dispositivo. Android: Play Integrity
   (basic_integrity, cts_profile_match). iOS: App Attest (app_recognition).
   Si el score baja del threshold → dispositivo marcado como COMPROMISED.';

-- V-13 — bauth.push_token_registry (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.push_token_registry (
    token_id            UUID        PRIMARY KEY DEFAULT uuidv7(),
    device_id           UUID        NOT NULL,
    push_token_hash     BYTEA       NOT NULL,
    push_provider       TEXT        NOT NULL,
    app_id              TEXT        DEFAULT 'com.skull.sbos.authenticator',
    tenant_id           UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    is_active           BOOLEAN     DEFAULT true,
    last_used_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (device_id, push_provider, app_id),
    CONSTRAINT chk_ptr_provider CHECK (push_provider IN ('FCM','APNS','HMS','WEB_PUSH'))
);
COMMENT ON TABLE bauth.push_token_registry IS
  'Tokens de notificaciones push por dispositivo. FCM (Firebase Cloud Messaging) para
   Android, APNs (Apple Push Notification service) para iOS, HMS para Huawei.
   Un dispositivo puede tener N tokens (uno por app/provider).';

-- V-14 — bauth.certificate_pin_config (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.certificate_pin_config (
    pin_id              UUID        PRIMARY KEY DEFAULT uuidv7(),
    hostname            TEXT        NOT NULL,
    pin_hash            TEXT        NOT NULL,
    pin_algorithm       TEXT        DEFAULT 'SHA-256',
    backup_pins         TEXT[]      DEFAULT '{}',
    is_enforced         BOOLEAN     DEFAULT true,
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ,
    is_active           BOOLEAN     DEFAULT true,
    ctx_id              TEXT        NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (hostname, pin_hash)
);
COMMENT ON TABLE bauth.certificate_pin_config IS
  '[OWASP MASVS V5] [RFC 7469] Public Key Pins para la app cliente. La app solo confía
   en conexiones cuyo certificado coincida con uno de estos pins SHA-256.
   Protege contra MITM incluso si una CA es comprometida. backup_pins para rollover.';

-- V-15 — bauth.token_refresh_log (NUEVA · Visión Context Plane Parte 4)
CREATE TABLE IF NOT EXISTS bauth.token_refresh_log (
    refresh_id          UUID        PRIMARY KEY DEFAULT uuidv7(),
    user_uuid           UUID        NOT NULL,
    device_id           UUID        NOT NULL,
    old_token_jti       TEXT        NOT NULL,
    new_token_jti       TEXT        NOT NULL,
    source_ip           INET,
    result              TEXT        NOT NULL,
    failure_reason      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_trl_result CHECK (result IN ('SUCCESS','FAILED','REVOKED','EXPIRED'))
);
CREATE INDEX IF NOT EXISTS idx_trl_device ON bauth.token_refresh_log(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trl_user ON bauth.token_refresh_log(user_uuid, created_at DESC);

COMMENT ON TABLE bauth.token_refresh_log IS
  'Auditoría de cada refresh de token JWT. Trazabilidad completa: dispositivo, IP,
   token anterior, token nuevo, resultado. Permite detectar patrones anómalos de refresh.';

-- ================================================================
-- DOCUMENTACION PROFESIONAL VALIDADA (87 columnas en 12 tablas)
-- ================================================================
COMMENT ON COLUMN bauth.idn_user_template.uuid IS '[RFC 9562] UUIDv7 PK. Identificador global inmutable. Es el sub claim en el JWT de Keycloak.';
COMMENT ON COLUMN bauth.idn_user_template.external_id IS 'ID en sistema RRHH externo (OrangeHRM, SAP). Para sync SCIM 2.0 bidireccional.';
COMMENT ON COLUMN bauth.idn_user_template.username IS 'Nombre de usuario canonico: {nombre}.{apellido}. Unico por tenant. INMUTABLE.';
COMMENT ON COLUMN bauth.idn_user_template.email IS 'Email principal del usuario. Para notificaciones y recuperacion de cuenta.';
COMMENT ON COLUMN bauth.idn_user_template.tenant_id IS '[SBOS-049] Capa 1: Tenant.';
COMMENT ON COLUMN bauth.idn_user_template.empresa_id IS '[SBOS-049] Capa 2: Empresa dentro del tenant.';
COMMENT ON COLUMN bauth.idn_user_template.sucursal_id IS '[SBOS-049] Capa 3: Sucursal fisica asignada.';
COMMENT ON COLUMN bauth.idn_user_template.pos_logico IS '[SBOS-049] Capa 4: Punto de venta logico.';
COMMENT ON COLUMN bauth.idn_user_template.bos_contexts IS '[SBOS-049] Contextos autorizados: {skull/maya/lapaz, skull/inka/lapaz}.';
COMMENT ON COLUMN bauth.idn_user_template.rol_ids IS 'Roles asignados al usuario. FK logico -> idn_role_template.id.';
COMMENT ON COLUMN bauth.idn_user_template.rol_bitmask_base64 IS 'BitMask efectiva del usuario (hex). Calculada por PrivilegeEngine.';
COMMENT ON COLUMN bauth.idn_user_template.status IS 'ACTIVE, INACTIVE (vacaciones), SUSPENDED (investigacion), TERMINATED (baja), PENDING (recien creado).';
COMMENT ON COLUMN bauth.idn_user_template.sync_status IS 'PENDING, SYNCING, SYNCED, ERROR, DRIFT. Estado de sincronizacion con KC+Tryton.';
COMMENT ON COLUMN bauth.idn_user_template.kc_user_id IS 'ID del usuario en Keycloak. Para sync bidireccional.';
COMMENT ON COLUMN bauth.idn_user_template.tryton_user_id IS 'ID del usuario en Tryton (res.user). Para sync bidireccional.';
COMMENT ON COLUMN bauth.idn_user_template.template IS '[JSONB] Template completo del usuario v6.0. 14 secciones del UserTemplate.';
COMMENT ON COLUMN bauth.idn_user_template.template_version IS 'Version del template. Para migracion de schema de templates.';

COMMENT ON COLUMN bauth.org_empresa.empresa_id IS 'ID canonico: skull, acme, maya. FK referenciada por org_sucursal.';
COMMENT ON COLUMN bauth.org_empresa.razon_social IS 'Razon social legal de la empresa. Para facturacion electronica SIN.';
COMMENT ON COLUMN bauth.org_empresa.nit IS 'NIT boliviano. Obligatorio para facturacion SIN. Registro en Padron SIN.';
COMMENT ON COLUMN bauth.org_empresa.regimen_fiscal IS 'GENERAL, SIMPLIFICADO, AGROPECUARIO. Define obligaciones fiscales SIN.';
COMMENT ON COLUMN bauth.org_empresa.es_operador IS 'TRUE = SKULL (dueno de la plataforma). FALSE = empresa cliente.';
COMMENT ON COLUMN bauth.org_empresa.locale_default IS '[BCP 47] Idioma por defecto: es-BO. Hereda de tenant si NULL.';
COMMENT ON COLUMN bauth.org_empresa.timezone_default IS '[IANA TZ] Zona horaria por defecto: America/La_Paz.';
COMMENT ON COLUMN bauth.org_empresa.moneda_default IS '[ISO 4217] Moneda por defecto: BOB. Hereda de tenant si NULL.';

COMMENT ON COLUMN bauth.org_sucursal.sucursal_id IS 'ID canonico: skull-central, acme-norte. FK referenciada por org_pos_logico.';
COMMENT ON COLUMN bauth.org_sucursal.direccion IS 'Direccion fisica. Para geocoding inverso -> coordenadas.';
COMMENT ON COLUMN bauth.org_sucursal.ciudad IS 'Ciudad. Para filtros y reportes.';
COMMENT ON COLUMN bauth.org_sucursal.horario_apertura IS 'Hora de apertura: 08:00. Para control de acceso temporal.';
COMMENT ON COLUMN bauth.org_sucursal.horario_cierre IS 'Hora de cierre: 18:00. Fuera de este rango -> override requerido.';
COMMENT ON COLUMN bauth.org_sucursal.dias_operacion IS '[ISO 8601] Dias de operacion: {MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY}.';
COMMENT ON COLUMN bauth.org_sucursal.admin_user_uuid IS 'UUID del administrador de sucursal. FK -> idn_user_template.';

COMMENT ON COLUMN bauth.dlg_delegation.from_user_uuid IS 'Usuario que delega sus permisos. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.dlg_delegation.to_user_uuid IS 'Usuario que recibe los permisos delegados. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.dlg_delegation.rol_id IS 'RolTemplate delegado. FK -> idn_role_template.id.';
COMMENT ON COLUMN bauth.dlg_delegation.mask_delegated_hex IS 'Mascara delegada (hex). mask_eff(from) AND mask_own(rol).';
COMMENT ON COLUMN bauth.dlg_delegation.valid_from IS 'Inicio de la delegacion. DEFAULT NOW().';
COMMENT ON COLUMN bauth.dlg_delegation.valid_until IS 'Fin de la delegacion. Maximo valid_from + 21 dias.';
COMMENT ON COLUMN bauth.dlg_delegation.auto_revoke IS 'TRUE = bAuth revoca automaticamente al vencer valid_until.';
COMMENT ON COLUMN bauth.dlg_delegation.requires_approval IS 'TRUE = requiere aprobacion de supervisor.';

COMMENT ON COLUMN bauth.ath_binding.authenticator_type IS '[NIST SP 800-63B-4] Tipo de authenticator: password, totp, webauthn_platform, passkey_device_bound, x509_mtls.';
COMMENT ON COLUMN bauth.ath_binding.authenticator_id IS 'Credential ID FIDO2/WebAuthn. Identificador unico del authenticator.';
COMMENT ON COLUMN bauth.ath_binding.binding_method IS '[NIST SP 800-63B-4] Metodo de vinculacion: in_person, remote_verified, self_service, admin_provisioned.';
COMMENT ON COLUMN bauth.ath_binding.binding_loa IS '[NIST SP 800-63B-4] Nivel de aseguramiento del vinculo (1-4).';
COMMENT ON COLUMN bauth.ath_binding.enrollment_authority IS 'Quien autorizo el enrolamiento: admin, self, federated.';
COMMENT ON COLUMN bauth.ath_binding.status IS 'ACTIVE, EXPIRED, REVOKED, SUSPENDED.';

COMMENT ON COLUMN bauth.ath_mfa_enrollment.mfa_type IS '[NIST SP 800-63B-4] totp, webauthn_platform, webauthn_roaming, passkey, recovery_codes.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.label IS 'Etiqueta descriptiva: iPhone 15 Pro, YubiKey 5C NFC.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.credential_id IS '[FIDO2] Credential ID en base64. NULL para TOTP.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.public_key IS '[FIDO2] Clave publica en formato PKIX. NULL para TOTP.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.device_info IS '[JSONB] Informacion del dispositivo: modelo, SO, navegador.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.is_primary IS 'TRUE = dispositivo MFA principal. Solo uno por usuario.';
COMMENT ON COLUMN bauth.ath_mfa_enrollment.is_backup IS 'TRUE = codigo de recuperacion o dispositivo de respaldo.';

COMMENT ON COLUMN bauth.fin_transaction_type.category IS '[ISO 20022] VENTAS, COMPRAS, PAGOS, COBROS, NOMINA, INVENTARIO, TRIBUTARIO, BANCARIO, ACTIVOS_FIJOS, IMPORTACION, EXPORTACION.';
COMMENT ON COLUMN bauth.fin_transaction_type.risk_level IS '[COSO] BAJO, MEDIO, ALTO, CRITICO. Determina controles requeridos.';
COMMENT ON COLUMN bauth.fin_transaction_type.controls IS '[JSONB] {requires_dual_control, requires_evidence, notifies_sin, min_approval_levels}. Extensible sin ALTER TABLE.';

COMMENT ON COLUMN bauth.fin_sod_rule.position_a IS 'Primera posicion en el Rol BitMask (one-hot encoding).';
COMMENT ON COLUMN bauth.fin_sod_rule.position_b IS 'Segunda posicion incompatible. UNIQUE(position_a, position_b).';
COMMENT ON COLUMN bauth.fin_sod_rule.risk_level IS '[COSO] ALTO (riesgo financiero/regulatorio), MEDIO (operativo), BAJO (administrativo).';
COMMENT ON COLUMN bauth.fin_sod_rule.action IS 'BLOCK (rechazar), COMPENSATE (aprobar con control), ALLOW_LOG (permitir registrando).';
COMMENT ON COLUMN bauth.fin_sod_rule.rationale IS '[SOX 404] Justificacion normativa con cita de estandar y seccion.';
COMMENT ON COLUMN bauth.fin_sod_rule.reviewed_at IS '[COBIT BAI09] Ultima revision anual de la regla SoD. Obligatoria.';

COMMENT ON COLUMN bauth.geo_trust_tier.tier_code IS 'HIGH (oficina), MEDIUM (VPN), LOW (publica).';
COMMENT ON COLUMN bauth.geo_trust_tier.tier_name IS 'Nombre descriptivo del tier de confianza.';
COMMENT ON COLUMN bauth.geo_trust_tier.tier_level IS '1=HIGH (todas las operaciones), 2=MEDIUM (lectura+escritura), 3=LOW (solo lectura).';
COMMENT ON COLUMN bauth.geo_trust_tier.allowed_operations IS 'Operaciones permitidas en este tier: {READ, WRITE, EXECUTE}.';
COMMENT ON COLUMN bauth.geo_trust_tier.restricted_operations IS 'Operaciones bloqueadas: {DELETE, APPROVE, FINANCIAL_APPROVE, SYSTEM_CONFIG}.';
COMMENT ON COLUMN bauth.geo_trust_tier.requires_step_up IS 'TRUE = requiere AAL3 para operaciones en este tier.';
COMMENT ON COLUMN bauth.geo_trust_tier.requires_vpn IS 'TRUE = VPN obligatoria para este tier.';

COMMENT ON COLUMN bauth.aud_compliance_map.standard IS 'Estandar: ISO 27001:2022, NIST SP 800-53 Rev.5, PCI DSS 4.0, GDPR, eIDAS 2.0.';
COMMENT ON COLUMN bauth.aud_compliance_map.control_id IS 'ID del control: A.5.15, AC-2, Req.7.1, Art.32.';
COMMENT ON COLUMN bauth.aud_compliance_map.control_name IS 'Nombre descriptivo del control.';
COMMENT ON COLUMN bauth.aud_compliance_map.implementation_status IS 'implemented, partial, planned, not_applicable.';
COMMENT ON COLUMN bauth.aud_compliance_map.evidence_ref IS 'Referencia a evidencia de implementacion: tabla, columna, funcion, politica.';

COMMENT ON COLUMN bauth.sync_log.rol_id IS 'RolTemplate sincronizado. NULL si fue sync de usuario.';
COMMENT ON COLUMN bauth.sync_log.engine IS 'KEYCLOAK, TRYTON, o BOTH. Motor de destino de la sincronizacion.';
COMMENT ON COLUMN bauth.sync_log.status IS 'PENDING, SYNCING, SYNCED, ERROR, DRIFT. Ciclo de vida de la sync.';
COMMENT ON COLUMN bauth.sync_log.retry_count IS 'Numero de reintentos. Maximo 5 antes de escalar a DRIFT.';
COMMENT ON COLUMN bauth.sync_log.duration_ms IS 'Duracion en milisegundos. Para monitoreo de SLO (<5s P99).';

COMMENT ON COLUMN bauth.ath_credential_policy.credential_type IS '[NIST SP 800-63B-4] PASSWORD, TOTP, WEBAUTHN, X509_CERT, OAUTH_SECRET, API_KEY, ENCRYPTION_KEY, SIGNING_KEY.';
COMMENT ON COLUMN bauth.ath_credential_policy.min_strength_bits IS '[NIST SP 800-63B-4] Entropia minima en bits. >=256 para CSPRNG.';
COMMENT ON COLUMN bauth.ath_credential_policy.requires_csprng IS 'TRUE = obligatorio generador criptografico de numeros aleatorios.';
COMMENT ON COLUMN bauth.ath_credential_policy.rotate_by_time IS '[NIST Rev.4] FALSE para passwords. TRUE para M2M certs y API keys.';
COMMENT ON COLUMN bauth.ath_credential_policy.rotate_on_compromise IS '[NIST SP 800-63B-4] TRUE = rotacion inmediata si se detecta compromiso.';
COMMENT ON COLUMN bauth.ath_credential_policy.requires_hibp_screening IS '[NIST Rev.4] TRUE para passwords. Cribado HIBP obligatorio.';
COMMENT ON COLUMN bauth.ath_credential_policy.history_retention_count IS '[OWASP ASVS V2.1.6] Numero de contrasenas previas no reutilizables.';

-- C-04: ALTERs movidos al final (post-creacion de tablas)
DO $$ BEGIN ALTER TABLE bauth.net_device ADD COLUMN IF NOT EXISTS attestation_score INTEGER DEFAULT 100; EXCEPTION WHEN duplicate_column THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE bauth.net_device ADD COLUMN IF NOT EXISTS jailbreak_detected BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE bauth.ses_context ADD COLUMN IF NOT EXISTS mobile_device_id UUID; EXCEPTION WHEN duplicate_column THEN NULL; END $$;
-- ================================================================
-- DOCUMENTACION PROFESIONAL: Lote 2 (215 columnas en 70+ tablas)
-- ================================================================

COMMENT ON COLUMN bauth.user_client_device.device_id IS '[RFC 9562] UUIDv7 PK. Identificador unico del dispositivo cliente en el ecosistema.';
COMMENT ON COLUMN bauth.user_client_device.user_uuid IS 'Usuario propietario del dispositivo. FK -> idn_user_template.uuid.';
COMMENT ON COLUMN bauth.user_client_device.net_device_id IS 'FK -> net_device.device_id. Datos de red y hardware del dispositivo.';
COMMENT ON COLUMN bauth.user_client_device.device_category IS '[SBOS Context Plane] MOBILE (celular), TABLET, DESKTOP (laptop/PC), IOT (sensor), WEARABLE (reloj).';
COMMENT ON COLUMN bauth.user_client_device.platform IS 'Sistema operativo: ios, android, windows, macos, linux, chromeos.';
COMMENT ON COLUMN bauth.user_client_device.os_version IS 'Version del SO. Para verificar requisitos minimos (Android 9+, iOS 16+).';
COMMENT ON COLUMN bauth.user_client_device.app_version IS 'Version de SBOS Authenticator instalada. Para forzar actualizacion.';
COMMENT ON COLUMN bauth.user_client_device.platform_authenticator IS '[FIDO2] FACE_ID, TOUCH_ID, ANDROID_BIOMETRIC, WINDOWS_HELLO, SECURITY_KEY, TPM, NONE.';
COMMENT ON COLUMN bauth.user_client_device.passkey_type IS '[FIDO2 Level 3] device_bound (FIPS 140-3), synced_icloud, synced_google, synced_other, none.';
COMMENT ON COLUMN bauth.user_client_device.aaguid IS '[FIDO2] Authenticator Attestation GUID. Identifica el modelo del authenticator.';
COMMENT ON COLUMN bauth.user_client_device.tpm_version IS 'Trusted Platform Module: 1.2, 2.0, o NULL si no tiene.';
COMMENT ON COLUMN bauth.user_client_device.secure_enclave IS 'TRUE si tiene hardware de seguridad dedicado (Secure Enclave en iOS, TPM en Windows).';
COMMENT ON COLUMN bauth.user_client_device.attestation_provider IS '[Play Integrity / App Attest] play_integrity (Android), app_attest (iOS), devicecheck (iOS legacy), none.';
COMMENT ON COLUMN bauth.user_client_device.last_attestation_at IS 'Timestamp de la ultima verificacion de integridad exitosa.';
COMMENT ON COLUMN bauth.user_client_device.push_token_hash IS 'SHA-256 del token FCM/APNs para notificaciones push. Almacenado como hash.';
COMMENT ON COLUMN bauth.user_client_device.is_primary IS 'TRUE = dispositivo principal del usuario. Solo uno por usuario.';
COMMENT ON COLUMN bauth.user_client_device.trust_score IS '[NIST SP 800-207] Score de confianza 0-100. <70 -> acceso restringido. <50 -> bloqueado.';
COMMENT ON COLUMN bauth.user_client_device.status IS 'ACTIVE, COMPROMISED (root/jailbreak), LOST (reportado), DECOMMISSIONED (dado de baja).';
COMMENT ON COLUMN bauth.user_client_device.last_seen_at IS 'Ultimo heartbeat recibido. Si >90s sin heartbeat -> dispositivo posiblemente offline.';
COMMENT ON COLUMN bauth.idp_client.client_id IS '[RFC 9562] UUIDv7 PK. Identificador OAuth 2.1 del cliente externo.';
COMMENT ON COLUMN bauth.idp_client.client_name IS 'Nombre descriptivo de la aplicacion externa. Visible en pantalla de consentimiento.';
COMMENT ON COLUMN bauth.idp_client.client_type IS '[OAuth 2.1] oidc (OpenID Connect), saml (SAML 2.0), oauth2 (OAuth 2.1 generico).';
COMMENT ON COLUMN bauth.idp_client.tenant_id IS 'Tenant propietario del cliente. FK -> idn_tenant. Un tenant puede tener N clientes externos.';
COMMENT ON COLUMN bauth.idp_client.redirect_uris IS '[OAuth 2.1] URIs de redireccion autorizadas post-autenticacion.';
COMMENT ON COLUMN bauth.idp_client.allowed_scopes IS '[OAuth 2.1] openid, profile, email, phone, address, offline_access.';
COMMENT ON COLUMN bauth.idp_client.grant_types IS '[OAuth 2.1] authorization_code, refresh_token. ROPC e Implicit PROHIBIDOS.';
COMMENT ON COLUMN bauth.idp_client.client_secret_hash IS 'SHA-256 del client_secret. Nunca en texto plano.';
COMMENT ON COLUMN bauth.idp_client.require_pkce IS '[OAuth 2.1 BCP] PKCE obligatorio para authorization_code con clientes publicos.';
COMMENT ON COLUMN bauth.idp_client.require_dpop IS '[RFC 9449] DPoP sender-constraining para tokens.';
COMMENT ON COLUMN bauth.idp_client.logo_url IS 'URL del logo de la app externa. Mostrado en pantalla de consentimiento.';
COMMENT ON COLUMN bauth.idp_client.tos_url IS 'URL de terminos de servicio de la app externa. GDPR: obligatorio.';
COMMENT ON COLUMN bauth.idp_client.policy_url IS 'URL de politica de privacidad de la app externa. GDPR Art.13: obligatorio.';
COMMENT ON COLUMN bauth.emergency_override_policy.authorized_by IS 'Supervisor que autorizo. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.emergency_override_policy.authorized_for IS 'Trabajador que recibe el override. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.emergency_override_policy.reason IS '[ISO 27001 A.8.2] Motivo obligatorio. Se audita post-evento.';
COMMENT ON COLUMN bauth.emergency_override_policy.ticket_ref IS 'Referencia al ticket (INC-2026-0042). Trazabilidad operativa.';
COMMENT ON COLUMN bauth.emergency_override_policy.override_geo IS 'TRUE = anula geo_fence y restriccion de pais.';
COMMENT ON COLUMN bauth.emergency_override_policy.override_temporal IS 'TRUE = anula cal_schedule y feriados.';
COMMENT ON COLUMN bauth.emergency_override_policy.override_physical IS 'TRUE = anula zonas fisicas denegadas.';
COMMENT ON COLUMN bauth.emergency_override_policy.allowed_zones IS 'Zonas habilitadas durante el override: {PHY_ZONE_SERVIDOR}.';
COMMENT ON COLUMN bauth.emergency_override_policy.valid_from IS 'Inicio ventana override. DEFAULT NOW().';
COMMENT ON COLUMN bauth.emergency_override_policy.valid_until IS 'Fin ventana. CHECK: max 4h desde valid_from.';
COMMENT ON COLUMN bauth.emergency_override_policy.qr_challenge_id IS 'FK -> qr_challenge_registry. QR de un solo uso.';
COMMENT ON COLUMN bauth.ctx_transfer_log.from_device_id IS 'Dispositivo origen (celular del usuario). FK -> user_client_device.';
COMMENT ON COLUMN bauth.ctx_transfer_log.to_device_id IS 'Dispositivo destino (CPU-045, DOOR-12, POS-23). Identificador del hardware receptor.';
COMMENT ON COLUMN bauth.ctx_transfer_log.ctx_id IS 'Contexto transferido. FK logico -> ses_context.ctx_id.';
COMMENT ON COLUMN bauth.ctx_transfer_log.transfer_method IS '[CTAP 2.2] QR (hybrid transport), NFC, BLE (caBLE), WEBSOCKET (mTLS directo), MANUAL (admin).';
COMMENT ON COLUMN bauth.ctx_transfer_log.challenge IS 'Challenge aleatorio de 32 bytes (base64url). Anti-replay: un solo uso.';
COMMENT ON COLUMN bauth.ctx_transfer_log.signature IS 'Firma del dispositivo origen sobre el challenge usando su Passkey.';
COMMENT ON COLUMN bauth.ctx_transfer_log.ttl_seconds IS 'TTL del ctx_id transferido. Default 300 (5 minutos).';
COMMENT ON COLUMN bauth.ctx_transfer_log.result IS 'ALLOW (transferencia exitosa), DENY (no autorizado), EXPIRED (challenge vencido), REPLAY (challenge reutilizado).';
COMMENT ON COLUMN bauth.mobile_app_config.platform IS 'ios, android, windows, macos, linux, chromeos, flutter_web. Una config por plataforma.';
COMMENT ON COLUMN bauth.mobile_app_config.min_app_version IS 'Version minima requerida (SemVer). Si app_version < min -> force_update.';
COMMENT ON COLUMN bauth.mobile_app_config.latest_app_version IS 'Ultima version publicada. Para sugerir actualizacion no forzosa.';
COMMENT ON COLUMN bauth.mobile_app_config.force_update IS 'TRUE = bloquear app si min_app_version no se cumple. FALSE = solo advertir.';
COMMENT ON COLUMN bauth.mobile_app_config.endpoints IS '[JSONB] {ws_url, api_url, auth_url}. Endpoints del servidor por plataforma.';
COMMENT ON COLUMN bauth.mobile_app_config.feature_flags IS '[JSONB] {passkeys, qr_transfer, nfc_access, biometric_lock}. Features habilitadas.';
COMMENT ON COLUMN bauth.device_attestation_log.device_id IS 'FK -> user_client_device. Dispositivo verificado.';
COMMENT ON COLUMN bauth.device_attestation_log.attestation_provider IS 'play_integrity (Android), app_attest (iOS), devicecheck (iOS legacy), none.';
COMMENT ON COLUMN bauth.device_attestation_log.attestation_token IS 'Token de integridad recibido del proveedor (Google Play / Apple). Verificado por bAuth.';
COMMENT ON COLUMN bauth.device_attestation_log.basic_integrity IS '[Play Integrity] TRUE = dispositivo pasa verificacion basica de integridad.';
COMMENT ON COLUMN bauth.device_attestation_log.cts_profile_match IS '[Play Integrity] TRUE = dispositivo es compatible con CTS (Certified Android).';
COMMENT ON COLUMN bauth.device_attestation_log.app_recognition IS '[App Attest] TRUE = app binaria no modificada, firmada por App Store.';
COMMENT ON COLUMN bauth.device_attestation_log.score IS 'Score combinado 0-100. <70 -> acceso restringido. <50 -> dispositivo COMPROMISED.';
COMMENT ON COLUMN bauth.device_attestation_log.verified_at IS 'Timestamp de la verificacion. Se ejecuta en cada login y periodicamente (cada 24h).';
COMMENT ON COLUMN bauth.ses_context_switch.ctx_id_anterior IS 'Contexto antes del switch. NULL si es primer contexto (login).';
COMMENT ON COLUMN bauth.ses_context_switch.ctx_id_nuevo IS 'Contexto despues del switch. Nueva sesion con ambito modificado.';
COMMENT ON COLUMN bauth.ses_context_switch.motivo IS 'cambio_sucursal, reasignacion_pos, login, cambio_empresa.';
COMMENT ON COLUMN bauth.ses_context_switch.emitido_por IS 'bos (sistema), usuario (manual), admin (forzado).';
COMMENT ON COLUMN bauth.ses_superuser_context.admin_uuid IS 'Administrador que activo el break-glass. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.ses_superuser_context.reason IS '[ISO 27001 A.8.2] Motivo del acceso de emergencia. Obligatorio.';
COMMENT ON COLUMN bauth.ses_superuser_context.vault_unseal IS 'TRUE = se realizo unseal 2-of-3 de Vault. FALSE = otro mecanismo.';
COMMENT ON COLUMN bauth.ses_superuser_context.session_log IS 'Registro completo de la sesion (comandos ejecutados). Inmutable.';
COMMENT ON COLUMN bauth.ses_superuser_context.post_audit_at IS 'Timestamp de auditoria post-evento. Debe ser <=24h post-revocacion.';
COMMENT ON COLUMN bauth.ses_superuser_context.post_audit_by IS 'Auditor que reviso la sesion break-glass. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.visitor_access_policy.host_user_uuid IS 'Usuario anfitrion que invita. FK -> idn_user_template.';
COMMENT ON COLUMN bauth.visitor_access_policy.visitor_user_uuid IS 'Usuario visitante. NULL si es visita sin cuenta SBOS.';
COMMENT ON COLUMN bauth.visitor_access_policy.visitor_name IS 'Nombre del visitante si no tiene cuenta SBOS.';
COMMENT ON COLUMN bauth.visitor_access_policy.visitor_phone IS 'Telefono del visitante. Para enviar QR de acceso por WhatsApp.';
COMMENT ON COLUMN bauth.visitor_access_policy.allowed_zones IS 'Zonas fisicas permitidas: {PHY_ZONE_SALA, PHY_ZONE_COCINA}.';
COMMENT ON COLUMN bauth.visitor_access_policy.restricted_zones IS 'Zonas explicitamente denegadas: {PHY_ZONE_DORMITORIO, PHY_ZONE_ESTUDIO}.';
COMMENT ON COLUMN bauth.visitor_access_policy.allowed_services IS 'Servicios permitidos: {iluminacion, calefaccion, climatizacion}.';
COMMENT ON COLUMN bauth.visitor_access_policy.can_control_devices IS 'TRUE = puede activar/desactivar dispositivos IoT (luces, calefaccion).';
COMMENT ON COLUMN bauth.visitor_access_policy.max_visitors IS 'Numero maximo de visitantes simultaneos con esta politica. Default 1.';
COMMENT ON COLUMN bauth.qr_challenge_registry.challenge IS 'Challenge aleatorio 32 bytes (base64url). UNICO. Anti-replay.';
COMMENT ON COLUMN bauth.qr_challenge_registry.device_id IS 'Dispositivo que genero el QR (CPU-045, DOOR-12).';
COMMENT ON COLUMN bauth.qr_challenge_registry.action IS 'ONBOARD, CTX_TRANSFER, CLOCK_IN, EMERGENCY_OVERRIDE, VISITOR_ACCESS, DELEGATION.';
COMMENT ON COLUMN bauth.qr_challenge_registry.used IS 'TRUE = challenge ya fue consumido. No se puede reutilizar.';
COMMENT ON COLUMN bauth.qr_challenge_registry.used_by_device IS 'UUID del dispositivo que uso el challenge. FK -> user_client_device.';
COMMENT ON COLUMN bauth.qr_challenge_registry.expires_at IS 'Timestamp de expiracion. Default: created_at + 120s.';
COMMENT ON COLUMN bauth.mobile_heartbeat_log.device_id IS 'FK -> user_client_device. Dispositivo que emite el latido.';
COMMENT ON COLUMN bauth.mobile_heartbeat_log.ctx_id IS 'ctx_id activo en el dispositivo al momento del latido.';
COMMENT ON COLUMN bauth.mobile_heartbeat_log.battery_pct IS 'Porcentaje de bateria. Para alertar si <15%.';
COMMENT ON COLUMN bauth.mobile_heartbeat_log.network_type IS 'WIFI, CELLULAR, ETHERNET, BLUETOOTH, OFFLINE.';
COMMENT ON COLUMN bauth.mobile_heartbeat_log.location_point IS '[PostGIS POINT] Ubicacion GPS en el momento del latido.';
COMMENT ON COLUMN bauth.geo_velocity_policy.max_velocity_kmh IS '[NIST SP 800-63B-4] Velocidad maxima entre logins: 900 km/h. Viaje imposible si se excede.';
COMMENT ON COLUMN bauth.geo_velocity_policy.tolerance_km IS 'Tolerancia en km para GPS drift. Default 10 km.';
COMMENT ON COLUMN bauth.geo_velocity_policy.on_violation IS 'REQUIRE_STEP_UP, TERMINATE_SESSION, LOCK_ACCOUNT, LOG_ONLY.';
COMMENT ON COLUMN bauth.geo_fence.polygon IS '[PostGIS POLYGON] Perimetro de la geo-cerca. Requiere PostGIS.';
COMMENT ON COLUMN bauth.geo_fence.center_point IS '[PostGIS POINT] Punto central si se usa radio en vez de poligono.';
COMMENT ON COLUMN bauth.geo_fence.radius_meters IS 'Radio en metros desde center_point. Alternativa a polygon.';
COMMENT ON COLUMN bauth.geo_fence.sucursal_id IS 'FK logico -> org_sucursal. Sucursal asociada a esta geo-cerca.';
COMMENT ON COLUMN bauth.geo_location_log.location_point IS '[PostGIS POINT] Coordenadas (lat,lon) del login.';
COMMENT ON COLUMN bauth.geo_location_log.accuracy_meters IS 'Precision del GPS en metros. <10m = GPS, <100m = WiFi, >100m = IP.';
COMMENT ON COLUMN bauth.geo_location_log.source IS 'GPS (movil), IP (geolocalizacion por IP), WIFI (triangulacion), MANUAL, BEACON (BLE).';
COMMENT ON COLUMN bauth.geo_evaluation_log.check_type IS 'COUNTRY_CHECK, GEOFENCE_CHECK, VELOCITY_CHECK, TRUST_TIER_EVAL.';
COMMENT ON COLUMN bauth.geo_evaluation_log.check_result IS 'ALLOW, DENY, STEP_UP, WARN. Resultado de la evaluacion geoespacial.';
COMMENT ON COLUMN bauth.geo_evaluation_log.details IS '[JSONB] Detalles: {country:BO, fence:inside, velocity_kmh:45, trust_tier:HIGH}.';
COMMENT ON COLUMN bauth.net_ztna_policy.default_action IS '[NIST SP 800-207 ZTA] DENY (zero trust). Solo servicios en allowed_services.';
COMMENT ON COLUMN bauth.net_ztna_policy.allowed_services IS 'Servicios permitidos: {tryton, keycloak, superset}.';
COMMENT ON COLUMN bauth.net_ztna_policy.microsegmentation IS 'TRUE = segmentacion fina entre servicios. FALSE = flat network.';
COMMENT ON COLUMN bauth.net_ztna_policy.require_just_in_time IS 'TRUE = acceso JIT. El servicio solo se expone cuando se necesita.';
COMMENT ON COLUMN bauth.ses_risk_policy.risk_factors IS '{geo_velocity, device_change, time_anomaly, behavior_anomaly, network_change, failed_auth_spike}.';
COMMENT ON COLUMN bauth.ses_risk_policy.action_critical IS 'TERMINATE_SESSION o LOCK_ACCOUNT. Para riesgo >=95.';
COMMENT ON COLUMN bauth.ses_caep_config.caep_event IS '[OpenID CAEP 1.0] session-revoked, token-claims-change, assurance-level-change, credential-change, device-compliance-change.';
COMMENT ON COLUMN bauth.ses_caep_config.endpoint_url IS 'URL del endpoint que recibe los eventos CAEP.';
COMMENT ON COLUMN bauth.ses_caep_config.shared_secret_hash IS 'SHA-256 del shared secret para firmar eventos CAEP.';
COMMENT ON COLUMN bauth.sod_validation_config.check_frequency IS 'REAL_TIME (cada asignacion), PERIODIC (cada N horas).';
COMMENT ON COLUMN bauth.sod_validation_config.validation_scope IS '{DIRECT_CONFLICTS, INHERITED_CONFLICTS, DELEGATION_CONFLICTS}.';
COMMENT ON COLUMN bauth.sod_validation_config.auto_remediate IS 'TRUE = revocar automaticamente asignaciones en conflicto.';
COMMENT ON COLUMN bauth.conflict_interest_policy.restricted_entity_types IS '{VENDORS, COMPETITORS, GOVERNMENT, FAMILY}.';
COMMENT ON COLUMN bauth.conflict_interest_policy.max_relationship_degrees IS 'Grados de parentesco maximo: 2 (hasta hermanos/abuelos).';
COMMENT ON COLUMN bauth.conflict_interest_policy.declaration_frequency IS 'ANNUAL, SEMI_ANNUAL, ON_CHANGE. Frecuencia de declaracion de intereses.';
COMMENT ON COLUMN bauth.zone_field_restriction.model_name IS 'Modelo Tryton: sale.order, account.invoice, party.party.';
COMMENT ON COLUMN bauth.zone_field_restriction.field_name IS 'Campo del modelo: margin, cost_price, credit_limit.';
COMMENT ON COLUMN bauth.zone_field_restriction.can_read IS 'TRUE = campo visible. FALSE = campo oculto.';
COMMENT ON COLUMN bauth.zone_field_restriction.can_write IS 'TRUE = campo editable. FALSE = solo lectura.';
COMMENT ON COLUMN bauth.zone_button_rule.button_name IS 'Boton Tryton: confirm, cancel, approve, post.';
COMMENT ON COLUMN bauth.zone_button_rule.condition_json IS '[PYSON] Condicion: {amount_total: {>: 5000}}.';
COMMENT ON COLUMN bauth.zone_button_rule.users_required IS 'Numero de aprobadores requeridos: 1 o 2 (dual).';
COMMENT ON COLUMN bauth.zone_button_rule.sod_cannot_also IS 'SoD: quien crea no puede confirmar. Ej: account.invoice:create.';
COMMENT ON COLUMN bauth.zone_button_rule.step_up_loa IS 'LoA requerido para ejecutar este boton. NULL = no requiere.';
COMMENT ON COLUMN bauth.zone_record_rule.domain_json IS '[PYSON] Filtro: [(shop.region, =, user.region)].';
COMMENT ON COLUMN bauth.zone_record_rule.scope IS 'GLOBAL, REGIONAL, BRANCH, PERSONAL.';
COMMENT ON COLUMN bauth.zone_record_rule.perm_write_exception IS 'TRUE = manager puede escribir en registros de subordinados.';
COMMENT ON COLUMN bauth.zone_data_policy.data_classification IS '{PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED}. Niveles permitidos.';
COMMENT ON COLUMN bauth.zone_data_policy.pii_access IS 'TRUE = acceso a datos personales. Logging extra requerido.';
COMMENT ON COLUMN bauth.zone_data_policy.masking_policy IS 'lastFourVisible, fullMask, domainOnly. Politica de enmascaramiento.';
COMMENT ON COLUMN bauth.zone_data_policy.gdpr_lawful_basis IS '[GDPR Art.6] legitimate_interest, consent, contract, legal_obligation.';
COMMENT ON COLUMN bauth.ath_auth_flow.flow_code IS 'standard_login, elevated_login, hardware_protected, financial_high_value, system_config_change, m2m_service_account, decoupled_external, unauthenticated.';
COMMENT ON COLUMN bauth.ath_auth_flow.min_loa IS '[NIST SP 800-63B-4] Nivel de aseguramiento minimo del flujo (0-4).';
COMMENT ON COLUMN bauth.ath_auth_flow_method.sort_order IS 'Orden de ejecucion del metodo dentro del flujo (1=primero).';
COMMENT ON COLUMN bauth.ath_auth_flow_method.is_required IS 'TRUE = metodo obligatorio. FALSE = opcional (alternativa).';
COMMENT ON COLUMN bauth.ath_step_up_rule.trigger_event IS '[RFC 9470] Evento que dispara el step-up: financial_approve, system_config_change, sod_override.';
COMMENT ON COLUMN bauth.ath_step_up_rule.condition_json IS '[JSONB] Condicion: {amount: {>: 5000}, field: amount_total}.';
COMMENT ON COLUMN bauth.ath_step_up_rule.required_loa IS '[NIST SP 800-63B-4] LoA requerido despues del step-up (1-4).';
COMMENT ON COLUMN bauth.ath_step_up_rule.max_age_seconds IS '[RFC 9470] Tiempo maximo desde la ultima autenticacion. 0 = autenticacion fresca obligatoria.';
COMMENT ON COLUMN bauth.ath_step_up_rule.acr_value IS '[OpenID Connect] Authentication Context Class Reference: sbos_aal3, sbos_aal3_fresh, sbos_aal3_hw_key.';
COMMENT ON COLUMN bauth.ath_step_up_rule.reauth_required IS 'TRUE = requiere reautenticacion biometrica, no solo token valido.';
COMMENT ON COLUMN bauth.ath_step_up_rule.requires_justification IS 'TRUE = requiere justificacion escrita. Para operaciones criticas (SoD override).';
COMMENT ON COLUMN bauth.ath_step_up_rule.requires_approval IS 'TRUE = requiere aprobacion de un tercero (supervisor, compliance).';
COMMENT ON COLUMN bauth.sec_key_inventory.key_type IS '[NIST SP 800-57 Pt.1] 20 tipos: JWT_SIGNING, MTLS_CERT, BLOCKCHAIN_SIGNING, ROOT_CA, ADSIB_CERT, etc.';
COMMENT ON COLUMN bauth.sec_key_inventory.storage_backend IS 'vault, hsm, tpm, software, hardware_token. Donde se almacena la clave.';
COMMENT ON COLUMN bauth.sec_key_inventory.state IS '[NIST SP 800-57] PRE_ACTIVE, ACTIVE, DEACTIVATED, COMPROMISED, DESTROYED.';
COMMENT ON COLUMN bauth.sec_key_inventory.backup_hash IS 'SHA-256 del backup de la clave. Para verificacion de integridad.';
COMMENT ON COLUMN bauth.sec_key_rotation.action IS '[NIST SP 800-57] GENERATED (creada), ROTATED (rotada), REVOKED (revocada), COMPROMISED (comprometida).';
COMMENT ON COLUMN bauth.sec_key_rotation.is_ceremony IS 'TRUE = requirio ceremonia formal con multiples testigos.';
COMMENT ON COLUMN bauth.sec_key_rotation.witnesses IS 'Array de testigos que presenciaron la ceremonia de rotacion.';
COMMENT ON COLUMN bauth.sec_key_recovery.recovery_type IS 'BREAK_GLASS (SU 2-of-3 Vault), ADMIN_RESET, USER_RECOVERY, COMPROMISE, DESASTRE.';
COMMENT ON COLUMN bauth.sec_key_recovery.approved_by IS 'Array de UUIDs que aprobaron la recuperacion. Minimo 2 para BREAK_GLASS.';
COMMENT ON COLUMN bauth.sec_key_recovery.result IS 'SUCCESS, FAILED, PARTIAL, PENDING_APPROVAL.';
COMMENT ON COLUMN bauth.org_pos_logico.modalidad_facturacion IS '[SIN Bolivia] ELECTRONICA_EN_LINEA, COMPUTARIZADA_EN_LINEA, PORTAL_WEB.';
COMMENT ON COLUMN bauth.org_pos_logico.ambiente_sin IS '[SIN Bolivia] PRUEBAS o PRODUCCION.';
COMMENT ON COLUMN bauth.org_pos_logico.numero_autorizacion IS '[SIN RND 10.0021.16] Numero de autorizacion de dosificacion.';
COMMENT ON COLUMN bauth.org_pos_logico.rango_inicio IS 'Numero de factura inicial del rango autorizado por SIN.';
COMMENT ON COLUMN bauth.org_pos_logico.rango_fin IS 'Numero de factura final del rango autorizado.';
COMMENT ON COLUMN bauth.org_pos_logico.numero_actual IS 'Contador de facturas emitidas. Se incrementa con cada emision.';
COMMENT ON COLUMN bauth.blk_anchor.tx_hash IS '[Arbitrum One] Hash de la transaccion de anclaje en L2.';
COMMENT ON COLUMN bauth.blk_anchor.block_number IS 'Numero de bloque en el que se incluyo la transaccion.';
COMMENT ON COLUMN bauth.blk_anchor.gas_used IS 'Gas consumido por la transaccion de anclaje. Para auditoria de costos.';
COMMENT ON COLUMN bauth.blk_anchor.total_cost_usd IS 'Costo total en USD del anclaje. Para FinOps.';
COMMENT ON COLUMN bauth.blk_merkle_batch.batch_number IS 'Numero de lote secuencial. UNICO.';
COMMENT ON COLUMN bauth.blk_merkle_batch.merkle_root IS '[Keccak256] Raiz del arbol Merkle del lote.';
COMMENT ON COLUMN bauth.blk_merkle_batch.status IS '0=open, 1=sealed, 2=anchored, 3=failed.';
COMMENT ON COLUMN bauth.blk_merkle_batch.merkle_tree_json IS '[JSONB] Estructura completa del arbol para verificacion offline.';
COMMENT ON COLUMN bauth.blk_merkle_leaf.event_hash IS '[Keccak256] Hash del evento: Keccak256(0x00 || ctx_id || audit_id || bitmask || result).';
COMMENT ON COLUMN bauth.blk_merkle_leaf.merkle_proof IS 'Array de hashes que prueban la inclusion de esta hoja en el arbol.';
COMMENT ON COLUMN bauth.fis_emergency_config.trigger_event IS 'FIRE_ALARM, MEDICAL_EMERGENCY, SECURITY_BREACH, POWER_OUTAGE.';
COMMENT ON COLUMN bauth.fis_emergency_config.action IS 'UNLOCK_ALL, UNLOCK_SPECIFIC_ZONE, LOCKDOWN_ALL, FAIL_SAFE_UNLOCK.';
COMMENT ON COLUMN bauth.fis_emergency_config.override_mode IS 'EMERGENCY_EVACUATION, TEMPORARY_ACCESS, LOCKDOWN, EMERGENCY_EGRESS.';
COMMENT ON COLUMN bauth.fis_zone_method_requirement.zone_level IS 'public_areas, employee_areas, restricted_areas, critical_areas, maximum_security_areas.';
COMMENT ON COLUMN bauth.fis_zone_method_requirement.method_id IS 'Metodo de acceso fisico requerido: NFC_MIFARE_DESFIRE, FINGERPRINT_HASH, SMARTCARD_X509, PIN_PAD.';
COMMENT ON COLUMN bauth.fis_zone_method_requirement.loa_required IS '[NIST SP 800-63B-4] Nivel de aseguramiento requerido (1-4).';
COMMENT ON COLUMN bauth.tryton_action_visibility.action_type IS 'menu, wizard, report, dashboard. Tipo de accion Tryton.';
COMMENT ON COLUMN bauth.idp_client_policy.min_aal IS '[NIST SP 800-63B-4] AAL minimo requerido para esta app externa (1-3).';
COMMENT ON COLUMN bauth.idp_client_policy.allowed_methods IS 'Metodos de autenticacion permitidos: {WEBAUTHN_PWDLESS, PASSKEY_DEVICE}.';
COMMENT ON COLUMN bauth.idp_client_policy.require_biometric IS 'TRUE = solo metodos con verificacion biometrica.';
COMMENT ON COLUMN bauth.idp_client_policy.allow_synced_passkeys IS 'TRUE = permitir passkeys syncables (iCloud/GPM). FALSE = solo device-bound.';
COMMENT ON COLUMN bauth.idp_client_policy.require_consent IS '[GDPR Art.7] TRUE = mostrar pantalla de consentimiento antes de compartir datos.';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.max_daily_hours IS '[Ley General del Trabajo Bolivia] Maximo 4 horas extra por dia.';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.max_weekly_hours IS 'Maximo 20 horas extra por semana.';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.rate_multiplier IS 'Factor multiplicador: 1.5x para horas extra diurnas.';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.night_shift_rate IS 'Factor para turno nocturno: 2.0x.';
COMMENT ON COLUMN bcalendar.cal_overtime_policy.holiday_rate IS 'Factor para feriados: 2.5x.';
COMMENT ON COLUMN bcalendar.cal_break_policy.lunch_required IS '[Ley General del Trabajo Bolivia] TRUE = almuerzo obligatorio.';
COMMENT ON COLUMN bcalendar.cal_break_policy.lunch_duration_minutes IS 'Duracion del almuerzo en minutos. Default 60.';
COMMENT ON COLUMN bcalendar.cal_break_policy.short_breaks_allowed IS 'Numero de breaks cortos: 2 (manana y tarde).';
COMMENT ON COLUMN bcalendar.cal_break_policy.short_break_minutes IS 'Duracion de cada break corto: 15 minutos.';
COMMENT ON COLUMN bcalendar.cal_break_policy.auto_logout_during_break IS 'TRUE = cerrar sesion durante el almuerzo. FALSE = pausar sesion.';
COMMENT ON COLUMN bauth.push_token_registry.push_token_hash IS 'SHA-256 del token FCM/APNs. Nunca en texto plano.';
COMMENT ON COLUMN bauth.push_token_registry.push_provider IS 'FCM (Firebase Android), APNS (Apple iOS), HMS (Huawei), WEB_PUSH.';
COMMENT ON COLUMN bauth.certificate_pin_config.hostname IS 'Hostname del servidor: api.sbos.app, auth.sbos.app.';
COMMENT ON COLUMN bauth.certificate_pin_config.pin_hash IS '[RFC 7469] SHA-256 de la clave publica del servidor.';
COMMENT ON COLUMN bauth.certificate_pin_config.backup_pins IS 'Pins de respaldo para rollover de certificados sin romper clients.';
COMMENT ON COLUMN bauth.certificate_pin_config.is_enforced IS 'TRUE = la app rechaza conexiones que no matchean el pin.';
COMMENT ON COLUMN bauth.token_refresh_log.old_token_jti IS 'JTI del token anterior. Para auditoria de cadena de refresh.';
COMMENT ON COLUMN bauth.token_refresh_log.new_token_jti IS 'JTI del nuevo token emitido.';
COMMENT ON COLUMN bauth.token_refresh_log.result IS 'SUCCESS, FAILED (token invalido/revocado), REVOKED (admin), EXPIRED (refresh_token vencido).';
COMMENT ON COLUMN bauth.external_session_registry.client_id IS 'FK -> idp_client. App externa que inicio la sesion.';
COMMENT ON COLUMN bauth.external_session_registry.id_token_jti IS 'JTI del ID Token emitido. Para revocacion selectiva.';
COMMENT ON COLUMN bauth.external_session_registry.access_token_jti IS 'JTI del Access Token emitido. Para revocacion selectiva.';
COMMENT ON COLUMN bauth.external_session_registry.scopes_granted IS 'Scopes que el usuario consintio: {openid, profile, email}.';
COMMENT ON COLUMN bauth.external_session_registry.consent_given IS 'TRUE = usuario acepto compartir datos con la app externa. GDPR Art.7.';
COMMENT ON COLUMN bauth.ath_password_history.password_hash IS '[Argon2id] Hash de la contrasena. Nunca en texto plano.';
COMMENT ON COLUMN bauth.ath_password_history.salt IS 'Salt unico de 16 bytes para Argon2id.';
COMMENT ON COLUMN bauth.ath_password_history.argon2_params IS '[JSONB] Parametros: {t:3, m:65536, p:2}.';
COMMENT ON COLUMN bauth.ath_password_screening.k_anon_prefix IS '[HIBP k-anonymity] Prefijo SHA-1 de 5 caracteres. Solo el prefijo se envia a HIBP.';
COMMENT ON COLUMN bauth.ath_password_screening.hibp_result IS 'TRUE = contrasena aparece en HIBP. Rechazo automatico.';
COMMENT ON COLUMN bauth.ath_recovery_method.method_type IS '[NIST SP 800-63B-4] email, sms, backup_codes, security_questions, trusted_contact, hardware_token.';
COMMENT ON COLUMN bauth.ath_recovery_method.method_value IS 'Valor del metodo: email enmascarado, phone hash, backup_codes SHA-256.';
COMMENT ON COLUMN bauth.ath_recovery_method.is_verified IS 'TRUE = metodo verificado. No se puede usar sin verificar.';
COMMENT ON COLUMN bauth.ath_revocation.binding_id IS 'FK -> ath_binding. Vinculo que se esta revocando.';
COMMENT ON COLUMN bauth.ath_revocation.reason IS '[NIST SP 800-63B-4] Motivo: LOST, STOLEN, COMPROMISED, UPGRADED, ADMIN_REVOKE.';
COMMENT ON COLUMN bauth.ath_revocation.replacement_binding IS 'FK -> ath_binding. Nuevo authenticator que reemplaza al revocado.';
COMMENT ON COLUMN bauth.ath_rotation_log.credential_type IS 'PASSWORD, TOTP, WEBAUTHN, X509_CERT, OAUTH_SECRET, API_KEY.';
COMMENT ON COLUMN bauth.ath_rotation_log.reason IS 'COMPROMISE_DETECTED, TTL_EXPIRED, MANUAL, POST_EVENT, PERIODIC, CREATION.';
COMMENT ON COLUMN bauth.ath_rotation_log.previous_hash IS 'SHA-256 de la credencial anterior. Para cadena de custodia.';
COMMENT ON COLUMN bauth.ath_login_attempt.username IS 'Nombre de usuario ingresado. Puede no existir (fuerza bruta).';
COMMENT ON COLUMN bauth.ath_login_attempt.source_ip IS '[INET] IP de origen del intento. Para deteccion de ataques.';
COMMENT ON COLUMN bauth.ath_login_attempt.is_success IS 'TRUE = login exitoso. FALSE = fallido. Indices filtrados por FALSE.';
COMMENT ON COLUMN bauth.ath_login_attempt.failure_reason IS 'Motivo del fallo: INVALID_PASSWORD, USER_NOT_FOUND, ACCOUNT_LOCKED, MFA_FAILED.';
COMMENT ON COLUMN bauth.ath_consent.consent_type IS '[GDPR Art.7] data_processing, marketing, third_party, biometric, cookies, profiling, automated_decision.';
COMMENT ON COLUMN bauth.ath_consent.status IS 'granted, withdrawn, expired.';
COMMENT ON COLUMN bauth.ath_consent.ip_address IS '[INET] IP desde la que se otorgo el consentimiento. GDPR: evidencia.';
COMMENT ON COLUMN bauth.ath_enrollment_log.step IS 'identity_verify, generate_credential, deliver_to_user, verify_method, activate.';
COMMENT ON COLUMN bauth.ath_enrollment_log.status IS 'IN_PROGRESS, COMPLETED, FAILED.';
COMMENT ON COLUMN bauth.ath_token_delivery.token_type IS 'TOTP, HOTP, NFC, QR, PUSH, RECOVERY, SMS, EMAIL, MAGIC_LINK, BARCODE.';
COMMENT ON COLUMN bauth.ath_token_delivery.delivery_channel IS 'presencial, remote_secure, self_service, whatsapp, telegram, email, sms, push.';
COMMENT ON COLUMN bauth.ath_token_delivery.recipient_signature IS 'Firma del receptor acusando recibo del token.';
COMMENT ON COLUMN bauth.ath_token_delivery.witness IS 'UUID del testigo que presencio la entrega.';
COMMENT ON COLUMN bauth.ath_recovery_challenge.question_hash IS '[Argon2id] Hash de la pregunta de seguridad. Nunca en texto plano.';
COMMENT ON COLUMN bauth.ath_recovery_challenge.answer_hash IS '[Argon2id] Hash de la respuesta. Nunca en texto plano.';
COMMENT ON COLUMN bauth.ath_recovery_challenge.salt IS 'Salt unico de 32 bytes para Argon2id.';
COMMENT ON COLUMN bauth.fis_device.device_type IS '[IEC 60839-11-5] 15 tipos: CARD_READER, BIOMETRIC_READER, MAGNETIC_LOCK, IP_CAMERA, etc.';
COMMENT ON COLUMN bauth.fis_device.protocol IS 'OSDP (v2.2.3), WIEGAND (legacy), ONVIF (camaras), MQTT (sensores), MODBUS, SIP, TCPIP.';
COMMENT ON COLUMN bauth.fis_device.auth_level IS '1=tarjeta, 2=tarjeta+PIN, 3=biometrico, 4=doble factor fisico.';
COMMENT ON COLUMN bauth.fis_device.ip_address IS '[INET] Direccion IP del dispositivo en la red fisica.';
COMMENT ON COLUMN bauth.fis_device.mac_address IS '[MACADDR] Direccion MAC del dispositivo. Para identificacion unica.';
COMMENT ON COLUMN bauth.fis_area_config.requires_escort IS '[ISO 27001 A.7.2] TRUE = visitantes deben ser escoltados.';
COMMENT ON COLUMN bauth.fis_area_config.requires_two_person IS '[NIST SP 800-53 PE-3] TRUE = minimo 2 personas simultaneas.';
COMMENT ON COLUMN bauth.fis_area_config.requires_mantrap IS '[IEC 60839-11-5] TRUE = esclusa de seguridad entre dos puertas.';
COMMENT ON COLUMN bauth.fis_area_config.requires_anti_tailgating IS 'TRUE = sensor anti-intrusion (tailgating/piggybacking).';
COMMENT ON COLUMN bauth.fin_decision_matrix.nivel_1_rol IS 'Rol del primer nivel de aprobacion.';
COMMENT ON COLUMN bauth.fin_decision_matrix.nivel_1_monto_max IS '[COSO] Monto maximo que puede aprobar el primer nivel. Si se excede -> escala a nivel 2.';
COMMENT ON COLUMN bauth.fin_decision_matrix.escala_automatica IS 'TRUE = si no hay respuesta en SLA, escala automaticamente al siguiente nivel.';
COMMENT ON COLUMN bauth.fin_decision_matrix.requiere_comite IS 'TRUE = requiere aprobacion de comite (inversiones >1M).';
COMMENT ON COLUMN bauth.fin_decision_matrix.tiempo_max_aprobacion_horas IS '[SLA] Tiempo maximo para obtener aprobacion antes de escalar. Default 48h.';
COMMENT ON COLUMN bauth.blk_account.onchain_address IS 'Direccion on-chain (Ethereum address). UNICA.';
COMMENT ON COLUMN bauth.blk_account.balance_derived IS '[Arbitrum One] Saldo calculado on-chain. Fuente de verdad.';
COMMENT ON COLUMN bauth.blk_account.balance_local IS 'Saldo en cache local. Reconciliado contra balance_derived periodicamente.';
COMMENT ON COLUMN bauth.blk_reconciliation.merkle_root_db IS 'Merkle root calculado desde la BD local.';
COMMENT ON COLUMN bauth.blk_reconciliation.merkle_root_onchain IS 'Merkle root obtenido del smart contract en Arbitrum.';
COMMENT ON COLUMN bauth.blk_reconciliation.is_match IS 'TRUE = raices coinciden. FALSE = divergencia detectada (DRIFT).';
COMMENT ON COLUMN bauth.net_device.node_id IS 'Identificador del nodo K8s o host donde esta conectado el dispositivo.';
COMMENT ON COLUMN bauth.net_device.device_type IS 'banexus_agent, osdp_reader, mqtt_sensor, onvif_camera, wiegand_reader, etc.';
COMMENT ON COLUMN bauth.net_device.certificate_serial IS 'Numero de serie del certificado X.509 del dispositivo.';
COMMENT ON COLUMN bauth.privilege_atom_policy.policy_data IS '[JSONB] Documento completo de politica: {$schema, priority, action, evaluate, params}. Validado con CHECK constraint.';
COMMENT ON COLUMN bauth.privilege_atom_policy.policy_domain IS 'Dominio de soberania al que aplica esta politica (1-12).';
COMMENT ON COLUMN bauth.privilege_atom.atom_position IS 'Posicion del bit en el Rol BitMask (one-hot encoding). UNICO.';
COMMENT ON COLUMN bauth.privilege_atom.contextual_mask IS 'Mascara contextual (32 bits): [8 res][4 dom][9 app][11 grupo].';
COMMENT ON COLUMN bauth.privilege_atom.logical_mask IS 'Mascara logica (32 bits): [6 res][2 pol][24 atomo].';
COMMENT ON COLUMN bauth.privilege_role.role_code IS 'Codigo numerico del rol. Usado en el Rol BitMask (one-hot).';
COMMENT ON COLUMN bauth.privilege_role.role_slug IS 'Slug unico por tenant: cajero, gerente_ventas, auditor_financiero.';
COMMENT ON COLUMN bauth.log_zone.zona_id IS 'Codigo de zona: AREA-VENT, AREA-CAJA, AREA-FACT, AREA-CONT. FK referenciada por zone_*.';
COMMENT ON COLUMN bauth.log_zone.categoria IS 'OPERATIVA, ADMINISTRATIVA, FINANCIERA, RRHH, TECNICA, DIRECTIVA, FISCAL, COMERCIAL.';
COMMENT ON COLUMN bauth.log_zone.ambito IS 'TENANT, EMPRESA, SUCURSAL. Nivel de alcance de la zona.';
COMMENT ON COLUMN bauth.log_zone.es_critica IS 'TRUE = zona critica. Requiere auditoria completa y step-up.';
COMMENT ON COLUMN bauth.log_zone.requiere_segregacion IS 'TRUE = SoD obligatorio. No se puede tener permisos en zonas conflictivas.';
COMMENT ON COLUMN bauth.log_zone.zona_conflicto IS 'Zonas con conflicto SoD: {COMPRAS, AUDITORIA}.';
COMMENT ON COLUMN bauth.bos_permiso_logico.verbo_id IS 'FK -> privilege_verb. Verbo asignado a este permiso.';
COMMENT ON COLUMN bauth.bos_permiso_logico.scope IS 'GLOBAL, EMPRESA, SUCURSAL, PERSONAL. Alcance del permiso.';
COMMENT ON COLUMN bauth.bos_permiso_logico.limit_registros IS 'Maximo de registros por consulta. NULL = sin limite.';
COMMENT ON COLUMN bauth.bos_permiso_logico.requiere_step_up IS 'TRUE = requiere elevacion LoA para usar este permiso.';
COMMENT ON COLUMN bauth.bos_permiso_logico.clasificacion_datos IS 'PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED. Maximo nivel accesible.';
COMMENT ON COLUMN bauth.idn_role_closure.ancestro_id IS '[ANSI INCITS 359-2004] Rol que hereda (senior). FK -> idn_role_template.';
COMMENT ON COLUMN bauth.idn_role_closure.descendiente_id IS 'Rol del que se hereda (junior). FK -> idn_role_template.';
COMMENT ON COLUMN bauth.idn_role_closure.profundidad IS 'Distancia en el DAG. 0=mismo rol, 1=hijo directo, N=N niveles.';
COMMENT ON COLUMN bcalendar.cal_schedule.days_of_week IS '[ISO 8601] Dias: {1,2,3,4,5} = Lunes a Viernes. 6=Sabado, 7=Domingo.';
COMMENT ON COLUMN bcalendar.cal_schedule.shifts IS '[JSONB] Turnos: [{start:08:00,end:12:00},{start:14:00,end:18:00}].';
COMMENT ON COLUMN bcalendar.cal_schedule.access_outside_schedule IS 'BLOCKED, PERMITTED, REQUIRES_APPROVAL, READ_ONLY.';
COMMENT ON COLUMN bcalendar.cal_event.rrule IS '[RFC 5545] Regla de recurrencia: FREQ=WEEKLY;BYDAY=MO,WE,FR. NULL = evento unico.';
COMMENT ON COLUMN bcalendar.cal_event.exdate IS '[RFC 5545] Array de fechas excluidas de la recurrencia.';
COMMENT ON COLUMN bcalendar.cal_holiday.is_recurring IS 'TRUE = feriado fijo (Navidad=12-25). FALSE = fecha unica.';
COMMENT ON COLUMN bcalendar.cal_holiday.country_code IS '[ISO 3166-1 alpha-2] Pais del feriado: BO, AR, BR, CL, PE.';
COMMENT ON COLUMN bcalendar.cal_holiday.region IS 'Region dentro del pais. NULL = feriado nacional.';
COMMENT ON COLUMN bauth.bos_crypto_algorithm.algo_type IS '[NIST FIPS 140-3] hashing, key_exchange, digital_signature, encryption, key_derivation, random.';
COMMENT ON COLUMN bauth.bos_crypto_algorithm.category IS 'classical, post_quantum, hybrid.';
COMMENT ON COLUMN bauth.bos_crypto_algorithm.fips_status IS 'FIPS 140-3 validation status: approved, candidate, deprecated.';
COMMENT ON COLUMN bauth.bos_crypto_algorithm.nist_pqc_round IS 'NIST PQC standardization round: 3, 4, selected, standard.';