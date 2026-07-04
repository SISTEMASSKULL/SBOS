-- ============================================================
-- bauth_db DDL — FASE 3: Funciones, Triggers, RLS, Permisos
-- build_ddl.sh v9 · 2026-06-23T03:50:42Z
-- Se ejecuta DESPUÉS de FASE 1 y FASE 2
-- ============================================================


-- Funciones
CREATE OR REPLACE FUNCTION bauth.compute_entry_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.entry_hash := encode(
        sha256((COALESCE(NEW.prev_hash,'') || NEW.rol_id || NEW.version || NEW.changed_at::text || NEW.template_snap::text)::bytea),
        'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION bauth.cleanup_password_history()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM bauth.bos_password_history
    WHERE user_uuid = NEW.user_uuid
      AND id NOT IN (
          SELECT id FROM bauth.bos_password_history
          WHERE user_uuid = NEW.user_uuid ORDER BY created_at DESC LIMIT 10
      );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION bauth.compute_audit_entry_hash()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_hash TEXT;
BEGIN
    SELECT entry_hash INTO v_prev_hash
    FROM bauth.bos_audit_events
    WHERE event_id = NEW.event_id - 1
    ORDER BY created_at DESC LIMIT 1;
    NEW.prev_hash := v_prev_hash;
    NEW.entry_hash := encode(
        sha256((COALESCE(v_prev_hash,'0x0000') || NEW.ctx_id || NEW.event_type ||
                NEW.outcome || NEW.created_at::text || COALESCE(NEW.details::text,'{}'))::bytea),
        'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION bos_privilege.sync_atom_position()
RETURNS TRIGGER AS $$
BEGIN
    SELECT atom_position INTO NEW.atom_position
    FROM bos_privilege.bos_atom_catalog
    WHERE app_code = NEW.app_code
      AND group_code = NEW.group_code
      AND atom_code = NEW.atom_code;
    IF NEW.atom_position IS NULL THEN
        RAISE EXCEPTION 'átomo no encontrado en bos_atom_catalog: app=% group=% atom=%',
            NEW.app_code, NEW.group_code, NEW.atom_code;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION bos_blockchain.merkle_root_from_batch(p_batch_id UUID)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_hashes VARCHAR(66)[];
    v_level INTEGER;
    v_i INTEGER;
    v_hash VARCHAR(66);
BEGIN
    SELECT array_agg(event_hash ORDER BY leaf_index)
    INTO v_hashes
    FROM bos_blockchain.bos_merkle_leaf
    WHERE batch_id = p_batch_id;
    IF v_hashes IS NULL OR array_length(v_hashes, 1) = 0 THEN RETURN NULL; END IF;
    WHILE array_length(v_hashes, 1) > 1 LOOP
        v_level := array_length(v_hashes, 1);
        FOR v_i IN 1..v_level BY 2 LOOP
            IF v_i + 1 <= v_level THEN
                v_hash := encode(digest(
                    decode(ltrim(v_hashes[v_i], '0x'), 'hex') ||
                    decode(ltrim(v_hashes[v_i+1], '0x'), 'hex'),
                    'keccak256'), 'hex');
            ELSE
                v_hash := encode(digest(
                    decode(ltrim(v_hashes[v_i], '0x'), 'hex') ||
                    decode(ltrim(v_hashes[v_i], '0x'), 'hex'),
                    'keccak256'), 'hex');
            END IF;
            v_hashes[(v_i + 1) / 2] := '0x' || v_hash;
        END LOOP;
        v_hashes := v_hashes[1:(v_level + 1) / 2];
    END LOOP;
    RETURN v_hashes[1];
END;
$$;

-- Triggers y Constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bauth') THEN
        CREATE ROLE bauth WITH LOGIN PASSWORD 'bauth_initial_password_change_me';
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS bauth;
ALTER SCHEMA bauth OWNER TO bauth;

-- ============================================================
-- 1. TENANT — Dominio técnico operado por SKULL
-- ============================================================
-- Un tenant es el CONTENEDOR TÉCNICO que aloja múltiples empresas.
-- SKULL es el tenant dueño de la plataforma. SKULL también opera
-- como empresa dentro de su propio tenant (primera empresa creada).
-- Cada tenant tiene su propio realm Keycloak, namespace K8s, BD,
-- y espacio Vault. Las empresas dentro del tenant comparten esta
-- infraestructura pero con aislamiento total de datos.
-- Referencia: SBOS-049 §4, §15

CREATE TABLE IF NOT EXISTS bauth.bos_tenant (
    -- === IDENTIDAD CENTRAL ===
    tenant_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'skull', 'acme', 'inka'
    nombre          TEXT        NOT NULL,                 -- Nombre descriptivo del tenant
    tenant_type     TEXT        NOT NULL DEFAULT 'STANDARD',-- STANDARD|REGULATED|HIGH_SENSITIVITY
    status          TEXT        NOT NULL DEFAULT 'PENDING_VERIFICATION',
    verification_status TEXT    NOT NULL DEFAULT 'UNVERIFIED',-- UNVERIFIED|IN_PROGRESS|VERIFIED|REJECTED
    verified_at     TIMESTAMPTZ,
    verified_by     TEXT,

    -- === DATOS LEGALES / ORGANIZACIONALES (del operador del tenant) ===
    legal_name      TEXT,                                 -- Razón social legal del operador
    tax_id          TEXT,                                 -- NIT / Tax ID (SIN Bolivia)
    registration_number TEXT,                             -- Registro de comercio
    country         TEXT        NOT NULL DEFAULT 'BO',    -- País de operación (ISO 3166-2)
    jurisdiction    TEXT,                                 -- Jurisdicción legal
    legal_representative TEXT,                            -- Representante legal
    legal_contact_email TEXT,

    -- === CONFIGURACIÓN TÉCNICA ===
    realm_kc        TEXT        NOT NULL UNIQUE,          -- tenant-{tenant_id}
    realm_kc_ext    TEXT        NOT NULL UNIQUE,          -- tenant-{tenant_id}-ext
    namespace_k8s   TEXT        NOT NULL UNIQUE,          -- namespace en Kubernetes
    database_name   TEXT,                                 -- BD dedicada (si DB_PER_TENANT)
    database_schema TEXT,                                 -- Schema dedicado (si SCHEMA_PER_TENANT)
    vault_path      TEXT,                                 -- secret/tenants/{tenant_id}/
    kong_consumer_id TEXT,                                -- Consumidor Kong
    domain          TEXT,                                 -- {tenant}.sbos.skull.bo

    -- === PERFIL DE SEGURIDAD (ISO 27001 A.9) ===
    isolation_level TEXT        NOT NULL DEFAULT 'SCHEMA_PER_TENANT',
                                                          -- ROW_LEVEL|SCHEMA_PER_TENANT|DB_PER_TENANT
    mfa_required    BOOLEAN     NOT NULL DEFAULT false,   -- MFA obligatorio global
    password_policy TEXT        NOT NULL DEFAULT 'length(12)_argon2id_t3_m64',
    session_ttl_max INTEGER     NOT NULL DEFAULT 28800,   -- 8h (max 24h)
    token_ttl_seconds INTEGER  NOT NULL DEFAULT 3600,    -- Access token TTL
    refresh_token_ttl_days INTEGER DEFAULT 30,
    ip_whitelist    INET[],                               -- Rangos IP permitidos
    audit_level     TEXT        NOT NULL DEFAULT 'basic', -- basic|full
    data_residency  TEXT        DEFAULT 'BO',             -- País de residencia de datos
    encryption_at_rest TEXT     NOT NULL DEFAULT 'AES-256-GCM',
    backup_frequency TEXT       NOT NULL DEFAULT 'daily',
    backup_retention_days INTEGER DEFAULT 90,

    -- === PLAN / SUSCRIPCIÓN ===
    plan_tier       TEXT        NOT NULL DEFAULT 'BASIC', -- BASIC|PRO|ENTERPRISE
    max_empresas    INTEGER     DEFAULT 5,
    max_usuarios    INTEGER     DEFAULT 50,
    max_sucursales  INTEGER     DEFAULT 25,
    max_pos         INTEGER     DEFAULT 100,
    subscription_status TEXT    NOT NULL DEFAULT 'TRIAL', -- TRIAL|ACTIVE|PAST_DUE|CANCELLED
    billing_cycle   TEXT        DEFAULT 'MONTHLY',
    trial_ends_at   TIMESTAMPTZ,

    -- === CUMPLIMIENTO NORMATIVO ===
    compliance_iso_27001   BOOLEAN DEFAULT false,
    compliance_pci_dss     BOOLEAN DEFAULT false,
    compliance_gdpr        BOOLEAN DEFAULT false,
    compliance_sin_bolivia BOOLEAN DEFAULT true,          -- Facturación electrónica SIN
    audit_retention_years  INTEGER  DEFAULT 10,
    data_retention_days    INTEGER  DEFAULT 2555,         -- 7 años

    -- === FEDERACIÓN Y CONFIANZA (NIST SP 800-63C) ===
    trusted_issuers   TEXT[],                             -- IdPs externos confiables
    federation_config JSONB,                              -- SAML/OIDC metadata
    cross_tenant_sharing BOOLEAN DEFAULT false,           -- Compartir datos entre tenants
    api_rate_limit   INTEGER     DEFAULT 100,             -- req/s por tenant

    -- === CONTACTOS ADMINISTRATIVOS ===
    admin_user_uuid UUID,                                 -- S016 Admin Tenant
    admin_email     TEXT        NOT NULL,
    admin_phone     TEXT,
    technical_contact_email TEXT,
    billing_contact_email   TEXT,
    notification_channels TEXT[] DEFAULT '{email}',

    -- === CICLO DE VIDA ===
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    suspended_at    TIMESTAMPTZ,
    suspended_reason TEXT,
    terminated_at   TIMESTAMPTZ,
    terminated_reason TEXT,

    CONSTRAINT chk_tenant_status      CHECK (status IN ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','TERMINATED'),
    CONSTRAINT chk_tenant_verif       CHECK (verification_status IN ('UNVERIFIED','IN_PROGRESS','VERIFIED','REJECTED'),
    CONSTRAINT chk_tenant_type        CHECK (tenant_type IN ('STANDARD','REGULATED','HIGH_SENSITIVITY'),
    CONSTRAINT chk_isolation          CHECK (isolation_level IN ('ROW_LEVEL','SCHEMA_PER_TENANT','DB_PER_TENANT'),
    CONSTRAINT chk_plan_tier          CHECK (plan_tier IN ('BASIC','PRO','ENTERPRISE'),
    CONSTRAINT chk_subscription       CHECK (subscription_status IN ('TRIAL','ACTIVE','PAST_DUE','CANCELLED'),
    CONSTRAINT chk_audit_tenant       CHECK (audit_level IN ('basic','full'),
    CONSTRAINT chk_billing            CHECK (billing_cycle IN ('MONTHLY','ANNUAL'))
);

CREATE INDEX IF NOT EXISTS idx_tenant_status     ON bauth.bos_tenant(status);
CREATE INDEX IF NOT EXISTS idx_tenant_verif      ON bauth.bos_tenant(verification_status);
CREATE INDEX IF NOT EXISTS idx_tenant_type       ON bauth.bos_tenant(tenant_type);
CREATE INDEX IF NOT EXISTS idx_tenant_sub        ON bauth.bos_tenant(subscription_status);

COMMENT ON TABLE bauth.bos_tenant IS 'Perfil completo de identidad, validación, seguridad y cumplimiento del tenant. ISO 27001 A.9, NIST 800-63B/207, GDPR Art.25/32.';
COMMENT ON COLUMN bauth.bos_tenant.tenant_type IS 'Clasificación de riesgo: STANDARD (básico), REGULATED (cumplimiento reforzado), HIGH_SENSITIVITY (aislamiento máximo).';
COMMENT ON COLUMN bauth.bos_tenant.isolation_level IS 'Aislamiento de datos: ROW_LEVEL (filtro tenant_id), SCHEMA_PER_TENANT (schema), DB_PER_TENANT (BD dedicada).';
COMMENT ON COLUMN bauth.bos_tenant.verification_status IS 'Verificación de identidad del tenant. Requiere 5 pasos (bos_tenant_verification) para pasar a VERIFIED.';

-- ============================================================
-- 1-B. TENANT VERIFICATION — 5 pasos de onboarding validado
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_verification (
    verification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    step            TEXT        NOT NULL,                  -- IDENTITY_CHECK|LEGAL_CHECK|TECHNICAL_SETUP|SECURITY_REVIEW|FINAL_APPROVAL
    status          TEXT        NOT NULL DEFAULT 'PENDING',-- PENDING|IN_PROGRESS|PASSED|FAILED
    verified_by     TEXT,
    verified_at     TIMESTAMPTZ,
    comments        TEXT,
    evidence        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_verif_step   CHECK (step IN ('IDENTITY_CHECK','LEGAL_CHECK','TECHNICAL_SETUP','SECURITY_REVIEW','FINAL_APPROVAL'),
    CONSTRAINT chk_verif_status CHECK (status IN ('PENDING','IN_PROGRESS','PASSED','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_btv_tenant ON bauth.bos_tenant_verification(tenant_id, step);

COMMENT ON TABLE bauth.bos_tenant_verification IS '5 pasos de verificación requeridos para activar un tenant. Auditoría ISO 27001. Onboarding documentado.';

-- ============================================================
-- 1-C. TABLAS DE REFERENCIA — Catálogos ISO normalizados
-- ============================================================
-- Propósito: Datos normalizados según estándares internacionales.
--            NO hardcodear valores. El usuario selecciona de estas
--            tablas; el sistema valida contra ellas.
--            Se actualizan cuando los estándares cambian (ej: nuevo
--            país, moneda retirada, cambio de zona horaria).
-- Referencia: ISO 3166 (países) · ISO 4217 (monedas) · IANA TZ Database
--             BCP 47 / RFC 5646 (idiomas) · Unicode CLDR (locales)

-- ============================================================
-- 1-C1. PAÍSES — ISO 3166-1
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_pais (
    codice_iso_alfa2  CHAR(2)     PRIMARY KEY,              -- BO, US, CN, AR, BR
    codice_iso_alfa3  CHAR(3)     NOT NULL UNIQUE,          -- BOL, USA, CHN, ARG, BRA
    codice_iso_num    SMALLINT    NOT NULL UNIQUE,          -- 068, 840, 156, 032, 076
    nombre_es         TEXT        NOT NULL,                 -- 'Bolivia', 'Estados Unidos', 'China'
    nombre_en         TEXT        NOT NULL,                 -- 'Bolivia', 'United States', 'China'
    nombre_nativo     TEXT,                                 -- 'Bolivia', 'United States', '中国'
    capital           TEXT,
    continente        TEXT,                                  -- 'América del Sur', 'Asia', 'Europa'
    region            TEXT,                                  -- 'LATAM', 'APAC', 'EMEA'
    flag_emoji        TEXT,                                  -- 🇧🇴 🇺🇸 🇨🇳
    codigo_telefonico TEXT,                                  -- +591, +1, +86
    activo            BOOLEAN     NOT NULL DEFAULT true
);

COMMENT ON TABLE bauth.bos_pais IS 'Catálogo de países ISO 3166-1. Fuente: mantenido por ISO, actualizado cuando hay cambios geopolíticos.';

-- ============================================================
-- 1-C1b. CIUDADES — División administrativa
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_ciudad (
    ciudad_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pais_iso        CHAR(2)     NOT NULL REFERENCES bauth.bos_pais(codice_iso_alfa2),
    nombre          TEXT        NOT NULL,
    codigo_postal   TEXT,
    region_estado   TEXT,                                  -- Departamento, Estado, Provincia
    latitud         NUMERIC(9,6),
    longitud        NUMERIC(9,6),
    timezone_id UUID        REFERENCES bauth.bos_timezone(timezone_id),
    activo          BOOLEAN     NOT NULL DEFAULT true,
    UNIQUE (pais_iso, nombre, region_estado)
);

CREATE INDEX IF NOT EXISTS idx_ciudad_pais ON bauth.bos_ciudad(pais_iso);

COMMENT ON TABLE bauth.bos_ciudad IS 'Ciudades y divisiones administrativas. Relacionado con país y zona horaria.';

-- ============================================================
-- 1-C2. MONEDAS — ISO 4217
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_moneda (
    codice_iso       CHAR(3)     PRIMARY KEY,               -- BOB, USD, EUR, CNY, BRL, ARS
    codice_num       SMALLINT    NOT NULL UNIQUE,           -- 068, 840, 978, 156, 986, 032
    nombre_es        TEXT        NOT NULL,                  -- 'Boliviano', 'Dólar estadounidense'
    nombre_en        TEXT        NOT NULL,                  -- 'Bolivian Boliviano', 'US Dollar'
    simbolo          TEXT        NOT NULL,                  -- Bs., $, €, ¥, R$, ARS$
    simbolo_int      TEXT,                                  -- BOB, USD, EUR, CNY (código internacional)
    precision        SMALLINT    NOT NULL DEFAULT 2,        -- Decimales: 2 (BOB), 0 (JPY), 3 (BHD)
    pais_emisor      CHAR(2)     REFERENCES bauth.bos_pais(codice_iso_alfa2),
    activo           BOOLEAN     NOT NULL DEFAULT true,
    es_criptomoneda  BOOLEAN     NOT NULL DEFAULT false,
    tipo_cambio_api  TEXT                                  -- URL API BCB/REUTERS para tasa de cambio
);

COMMENT ON TABLE bauth.bos_moneda IS 'Catálogo de monedas ISO 4217. Códigos mantenidos por SIX Interbank Clearing en nombre de ISO.';

-- ============================================================
-- 1-C3. IDIOMAS — ISO 639 / BCP 47
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_idioma (
    locale UUID PRIMARY KEY DEFAULT gen_random_uuid(),               -- es-BO, en-US, zh-CN, pt-BR, qu-BO
    codice_iso_639_1 CHAR(2),                               -- es, en, zh, pt, qu
    codice_iso_639_2 CHAR(3),                               -- spa, eng, zho, por, que
    nombre_nativo    TEXT        NOT NULL,                  -- 'Español', 'English', '中文', 'Português'
    nombre_es        TEXT        NOT NULL,                  -- 'Español', 'Inglés', 'Chino', 'Portugués'
    direccion_texto  TEXT        DEFAULT 'LTR',             -- LTR|RTL (árabe, hebreo)
    juegos_caracteres TEXT      DEFAULT 'UTF-8',
    flag_emoji       TEXT,                                  -- 🇧🇴 🇺🇸 🇨🇳
    activo           BOOLEAN     NOT NULL DEFAULT true
);

COMMENT ON TABLE bauth.bos_idioma IS 'Catálogo de idiomas BCP 47 / RFC 5646. Mantenido por IANA Language Subtag Registry + Unicode CLDR.';

-- ============================================================
-- i18n CAPABILITIES — Más allá de las traducciones
-- ============================================================
-- bAuth integra ICU4X 2.0 (Rust) + Fluent para capacidades i18n completas.
-- No es solo traducir textos — es formatear, adaptar y contextualizar
-- cada salida del sistema según el locale activo del usuario.
--
-- CAPACIDADES i18n QUE bAuth APROVECHA:
--
-- 1. FORMATO DE FECHAS Y HORAS (icu::datetime):
--    es-BO: 20/06/2026 14:30   en-US: 06/20/2026 2:30 PM   zh-CN: 2026年6月20日 14:30
--    Formato configurable por tenant/empresa en bos_tenant_config (date_format, time_format)
--
-- 2. FORMATO DE NÚMEROS Y MONEDAS (icu::decimal, icu::fixed_decimal):
--    es-BO: Bs. 1.234.567,89   en-US: BOB 1,234,567.89   zh-CN: 123万4567.89元
--    Símbolo, posición, separadores según locale. Moneda desde bos_moneda (ISO 4217)
--
-- 3. PLURALES (icu::plurals — cardinal + ordinal):
--    es-BO: 1 producto, 2 productos, cientos de productos
--    en-US: 1 product, 2 products
--    zh-CN: 1个产品, 2个产品 (chino no distingue plural)
--    Ordinales: 1er lugar (es), 1st place (en), 第1名 (zh)
--
-- 4. GÉNERO Y CONCORDANCIA (Fluent selectors):
--    "Estimado {nombre}" (masculino) vs "Estimada {nombre}" (femenino) — español
--    "Dear {name}" — inglés (sin género gramatical)
--    "{gender, select, male {Bienvenido} female {Bienvenida} other {Bienvenid@}}"
--
-- 5. ORDENACIÓN / COLLATION (icu::collator):
--    Español: ñ después de n, ch después de c, ll después de l
--    Alemán: ü = ue para ordenación
--    Chino: por radical + trazos, o por pinyin
--
-- 6. TIEMPO RELATIVO (icu::relativetime):
--    "hace 5 minutos" (es), "5 minutes ago" (en), "5分钟前" (zh)
--    "dentro de 3 horas" (es), "in 3 hours" (en), "3小时后" (zh)
--
-- 7. FORMATO DE LISTAS (icu::list):
--    "Juan, María y Pedro" (es) — conjunción "y", coma antes del último
--    "Juan, María, and Pedro" (en) — coma Oxford
--    "Juan、María和Pedro" (zh) — separador especial、y conjunción 和
--
-- 8. UNIDADES DE MEDIDA (icu::units / ICU4X 2.0 experimental):
--    "5 km" vs "3.1 mi", "25°C" vs "77°F"
--    "1.000 g" vs "2.2 lb", "1 L" vs "0.26 gal"
--
-- 9. PRIMER DÍA DE LA SEMANA (CLDR):
--    Bolivia: lunes (1), EEUU: domingo (7), Medio Oriente: sábado (6)
--    Configurado en bos_tenant_config.first_day_of_week
--
-- 10. NEGOCIACIÓN DE IDIOMA (fluent-langneg / ICU4X locale negotiation):
--     El sistema detecta el mejor locale para el usuario basado en:
--     - Accept-Language header del navegador
--     - Configuración del tenant (supported_locales)
--     - Configuración de la empresa (locales_extra)
--     - Preferencia del usuario (si existe)
--     Algoritmo: lookup → best_match → fallback_chain
--
-- 11. TEXTOS RICOS CON INLINE TAGS (Fluent):
--     "<b>Hola <i>{nombre}</i>!</b> Tu saldo es <b>{monto}</b>."
--     Permite HTML/XML en traducciones sin romper la estructura
--
-- 12. ASIMETRÍA DE TRADUCCIÓN (Fluent):
--     Cada locale puede tener diferentes niveles de completitud
--     bos_tenant_language.translation_status: COMPLETE|PARTIAL|MACHINE_TRANSLATED
--     Si falta una traducción → fallback al siguiente locale en cadena
--
-- REFERENCIAS TÉCNICAS:
--   Rust: ICU4X 2.0 (icu + icu_datetime + icu_decimal + icu_plurals + icu_collator)
--   Rust: Fluent (fluent + fluent-langneg + fluent-fallback)
--   Datos: Unicode CLDR 46 + IANA Language Subtag Registry
--   Estándares: BCP 47 (RFC 5646), ISO 639, ISO 4217, ISO 8601, IANA TZ';

-- ============================================================
-- 1-C4. ZONAS HORARIAS — IANA Time Zone Database
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_timezone (
    timezone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),               -- 'America/La_Paz', 'Asia/Shanghai'
    nombre_es        TEXT        NOT NULL,                  -- 'Bolivia (La Paz)', 'China (Shanghái)'
    utc_offset       TEXT        NOT NULL,                  -- '-04:00', '+08:00'
    utc_offset_min   SMALLINT    NOT NULL,                  -- -240, 480 (minutos desde UTC)
    observa_dst      BOOLEAN     NOT NULL DEFAULT false,
    pais             CHAR(2)     REFERENCES bauth.bos_pais(codice_iso_alfa2),
    ciudad_principal TEXT,                                  -- 'La Paz', 'Shanghái'
    activo           BOOLEAN     NOT NULL DEFAULT true
);

COMMENT ON TABLE bauth.bos_timezone IS 'Catálogo de zonas horarias IANA TZ Database. Actualizado cuando hay cambios en políticas DST o nuevas zonas.';

-- ============================================================
-- 1-D. TENANT CONFIG — Configuración regional del tenant
-- ============================================================
-- Propósito: Configuración regional, idioma, moneda, zona horaria
--            y preferencias del tenant. Estos valores son heredados
--            por las empresas dentro del tenant (cascada hacia abajo).
--            Las empresas y sucursales pueden sobrescribir selectivamente.
-- Regla de herencia: empresa hereda de tenant, sucursal hereda de
-- empresa, POS hereda de sucursal. Un valor NULL = "heredar del padre".
-- Referencia: ISO 8601 (fechas) · ISO 4217 (monedas) · IANA TZ Database
--             Unicode CLDR (locales) · RFC 5646 (language tags)

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_config (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid() REFERENCES bauth.bos_tenant(tenant_id),

    -- === IDIOMA POR DEFECTO + SOPORTADOS ===
    locale_default UUID        NOT NULL DEFAULT NULL REFERENCES bauth.bos_idioma(locale),
    supported_locales TEXT[]   DEFAULT '{es-BO,en-US,pt-BR}',
    fallback_locales TEXT[]    DEFAULT '{es,en}',
    date_format     TEXT        NOT NULL DEFAULT 'DD/MM/YYYY',
    time_format     TEXT        NOT NULL DEFAULT 'HH:mm:ss',
    number_format   TEXT        NOT NULL DEFAULT '1.234,56',
    first_day_of_week INTEGER  NOT NULL DEFAULT 1,

    -- === ZONA HORARIA POR DEFECTO + SOPORTADAS ===
    timezone_default UUID      NOT NULL DEFAULT NULL REFERENCES bauth.bos_timezone(timezone_id),
    timezones       TEXT[]     DEFAULT '{America/La_Paz,America/Argentina/Buenos_Aires,America/Santiago,America/Lima}',

    -- === MONEDA POR DEFECTO ===
    currency_default TEXT      NOT NULL DEFAULT 'BOB' REFERENCES bauth.bos_moneda(codice_iso),
    multicurrency   BOOLEAN     NOT NULL DEFAULT false,

    -- === MULTIGESTIÓN / CALENDARIO FISCAL ===
    -- Bolivia SIN: gestión = año fiscal (1 enero - 31 diciembre)
    -- Multigestión permite operar en múltiples años simultáneamente:
    --   - Año corriente (transacciones del día a día)
    --   - Años anteriores abiertos (correcciones, ajustes, auditoría)
    --   - Año siguiente en preparación (presupuesto, planificación)
    multigestion_enabled BOOLEAN NOT NULL DEFAULT true,
    max_gestiones_abiertas INTEGER DEFAULT 3,             -- Máximo de gestiones simultáneas abiertas
    fiscal_year_start_month INTEGER NOT NULL DEFAULT 1,    -- 1 = Enero (Bolivia)
    fiscal_year_start_day   INTEGER NOT NULL DEFAULT 1,
    first_fiscal_year       INTEGER,                       -- Año de inicio de operaciones del tenant

    -- === MULTI-THEME / APARIENCIA ===
    theme_default   TEXT        NOT NULL DEFAULT 'light',   -- Tema por defecto
    themes_disponibles TEXT[]  DEFAULT '{light,dark}',      -- Temas habilitados
    logo_url        TEXT,
    favicon_url     TEXT,
    primary_color   TEXT        DEFAULT '#1a73e8',
    secondary_color TEXT        DEFAULT '#34a853',
    font_family     TEXT        DEFAULT 'Inter, system-ui, sans-serif',

    -- === PREFERENCIAS DE NOTIFICACIÓN ===
    notification_locale TEXT   DEFAULT 'es-BO',    -- Idioma de notificaciones
    email_footer_template  TEXT,                            -- Plantilla de footer para emails

    -- === METADATOS ===
    metadata        JSONB       DEFAULT '{}',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Reconciliación: columnas que pueden faltar en VPS antiguas
ALTER TABLE bauth.bos_tenant_config ADD COLUMN IF NOT EXISTS locale TEXT DEFAULT 'es-BO';
ALTER TABLE bauth.bos_tenant_config ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'America/La_Paz';
ALTER TABLE bauth.bos_tenant_config ADD COLUMN IF NOT EXISTS currency_default TEXT DEFAULT 'BOB';
ALTER TABLE bauth.bos_tenant_config ADD COLUMN IF NOT EXISTS supported_locales TEXT[] DEFAULT '{es-BO}';

COMMENT ON TABLE bauth.bos_tenant_config IS 'Configuración regional y preferencias del tenant. Raíz de la jerarquía de herencia → empresa → sucursal → POS. Valores NULL en niveles inferiores = heredar.';
COMMENT ON COLUMN bauth.bos_tenant_config.locale IS 'Código IETF BCP 47 (RFC 5646). Define formato de fechas, números, ordenación, y traducciones. Ej: es-BO, en-US, pt-BR.';
COMMENT ON COLUMN bauth.bos_tenant_config.timezone IS 'Zona horaria IANA (TZ Database). Ej: America/La_Paz, America/Argentina/Buenos_Aires.';
COMMENT ON COLUMN bauth.bos_tenant_config.currency_default IS 'Código ISO 4217 de moneda por defecto. BOB=068, USD=840, EUR=978, BRL=986.';
COMMENT ON COLUMN bauth.bos_tenant_config.supported_locales IS 'Todos los locales soportados por este tenant. La UI se traduce a cada uno. El orden define la preferencia.';

-- ============================================================
-- 1-D. TENANT DOMAINS — Dominios y subdominios del tenant
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_domain (
    domain_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    domain          TEXT        NOT NULL UNIQUE,           -- ej: 'skull.sbos.bo', 'acme.com.bo'
    subdomain       TEXT,                                  -- ej: 'admin', 'api', 'pos'
    fqdn            TEXT        NOT NULL UNIQUE,           -- FQDN completo: admin.skull.sbos.bo
    tipo            TEXT        NOT NULL DEFAULT 'WEB',    -- WEB|API|POS|ADMIN|PORTAL
    ssl_cert_arn    TEXT,                                  -- ARN del certificado SSL/TLS
    ssl_provider    TEXT        DEFAULT 'letsencrypt',     -- letsencrypt|digicert|custom
    active          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_domain_tipo CHECK (tipo IN ('WEB','API','POS','ADMIN','PORTAL','STATIC','MAIL'))
);

CREATE INDEX IF NOT EXISTS idx_btd_tenant ON bauth.bos_tenant_domain(tenant_id);

-- Reconciliación: columna active para índice condicional
ALTER TABLE bauth.bos_tenant_domain ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_btd_active ON bauth.bos_tenant_domain(active) WHERE active = true;

COMMENT ON TABLE bauth.bos_tenant_domain IS 'Dominios y subdominios asignados al tenant. Cada tenant puede tener múltiples FQDN por tipo de servicio.';

-- ============================================================
-- 1-E. TENANT NETWORKS — Rangos IP y redes del tenant
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_network (
    network_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                  -- 'Red Principal La Paz', 'VPN Corporativa'
    tipo            TEXT        NOT NULL DEFAULT 'LAN',    -- LAN|WAN|VPN|DMZ|GUEST
    cidr            CIDR        NOT NULL,                  -- 10.0.1.0/24
    gateway         INET,
    dns_servers     INET[],
    vlan_id         INTEGER,
    active          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_net_tipo CHECK (tipo IN ('LAN','WAN','VPN','DMZ','GUEST','MANAGEMENT'))
);

CREATE INDEX IF NOT EXISTS idx_btn_tenant ON bauth.bos_tenant_network(tenant_id);

COMMENT ON TABLE bauth.bos_tenant_network IS 'Rangos de red y configuración de conectividad del tenant. Usado para geolocalización, Zero Trust, y políticas de acceso.';

-- ============================================================
-- 1-F. TENANT CURRENCIES — Monedas habilitadas + tasas de cambio
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_currency (
    currency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    codice_iso      CHAR(3)     NOT NULL REFERENCES bauth.bos_moneda(codice_iso),
    es_default      BOOLEAN     NOT NULL DEFAULT false,
    exchange_rate_to_default NUMERIC(12,6),                -- Tasa de cambio respecto a la moneda default del tenant
    exchange_source TEXT       DEFAULT 'BCB',              -- BCB (Banco Central), REUTERS, MANUAL, CUSTOM
    exchange_updated_at TIMESTAMPTZ,
    active          BOOLEAN     NOT NULL DEFAULT true,
    UNIQUE (tenant_id, codice_iso)
);

CREATE INDEX IF NOT EXISTS idx_btc_tenant ON bauth.bos_tenant_currency(tenant_id);

COMMENT ON TABLE bauth.bos_tenant_currency IS 'Monedas habilitadas para el tenant. FK a bos_moneda (ISO 4217). Una debe ser es_default=true. Tasas de cambio configurables por tenant.';

-- ============================================================
-- 1-G. TENANT LANGUAGES — Idiomas disponibles con datos de traducción
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tenant_language (
    lang_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    locale UUID        NOT NULL REFERENCES bauth.bos_idioma(locale),
    es_default      BOOLEAN     NOT NULL DEFAULT false,
    translation_provider TEXT DEFAULT 'sbos_i18n',        -- sbos_i18n|external_api|custom_file
    translation_status TEXT  DEFAULT 'COMPLETE',           -- COMPLETE|PARTIAL|MACHINE_TRANSLATED
    active          BOOLEAN     NOT NULL DEFAULT true,
    UNIQUE (tenant_id, locale)
);

CREATE INDEX IF NOT EXISTS idx_btl_tenant ON bauth.bos_tenant_language(tenant_id);

COMMENT ON TABLE bauth.bos_tenant_language IS 'Idiomas habilitados para el tenant. FK a bos_idioma (BCP 47). El orden de fallback lo define tenant_config.fallback_locales.';

-- ============================================================
-- 1-H. TENANT GESTIONES — Años fiscales y períodos contables
-- ============================================================
-- Propósito: Gestión multigestión — permite operar en múltiples
--            años fiscales simultáneamente. Una gestión es un
--            año fiscal con sus períodos mensuales. Bolivia SIN
--            requiere cierre anual pero permite correcciones a
--            gestiones anteriores (notas de crédito/débito).
-- Referencia: SIN Bolivia · NIC 1 (Presentación EEFF) · NIC 8 (Políticas contables)

CREATE TABLE IF NOT EXISTS bauth.bos_tenant_gestion (
    gestion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id), -- NULL = global tenant
    ano_fiscal      INTEGER     NOT NULL,                  -- 2025, 2026, 2027
    nombre          TEXT        NOT NULL,                  -- 'Gestión 2026'
    estado          TEXT        NOT NULL DEFAULT 'ABIERTA',-- ABIERTA|CERRADA|CERRADA_CON_AJUSTES|ARCHIVADA
    fecha_inicio    DATE        NOT NULL,
    fecha_cierre    DATE,
    cerrada_por     TEXT,
    cerrada_en      TIMESTAMPTZ,
    -- Períodos contables dentro de la gestión
    periodos        JSONB       NOT NULL DEFAULT '[
        {"mes":1,"nombre":"Enero","estado":"ABIERTO"},
        {"mes":2,"nombre":"Febrero","estado":"ABIERTO"},
        {"mes":3,"nombre":"Marzo","estado":"ABIERTO"},
        {"mes":4,"nombre":"Abril","estado":"ABIERTO"},
        {"mes":5,"nombre":"Mayo","estado":"ABIERTO"},
        {"mes":6,"nombre":"Junio","estado":"ABIERTO"},
        {"mes":7,"nombre":"Julio","estado":"ABIERTO"},
        {"mes":8,"nombre":"Agosto","estado":"ABIERTO"},
        {"mes":9,"nombre":"Septiembre","estado":"ABIERTO"},
        {"mes":10,"nombre":"Octubre","estado":"ABIERTO"},
        {"mes":11,"nombre":"Noviembre","estado":"ABIERTO"},
        {"mes":12,"nombre":"Diciembre","estado":"ABIERTO"}
    ]',
    -- Cierre y apertura
    es_gestion_corriente BOOLEAN DEFAULT false,           -- Solo una por tenant/empresa
    permite_ajustes_anteriores BOOLEAN DEFAULT true,      -- Permitir NC/ND en gestiones cerradas
    ajustes_max_meses_atras INTEGER DEFAULT 12,            -- Máximo meses hacia atrás para ajustes
    -- Auditoría
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, empresa_id, ano_fiscal)
);

CREATE INDEX IF NOT EXISTS idx_btg_tenant   ON bauth.bos_tenant_gestion(tenant_id);
CREATE INDEX IF NOT EXISTS idx_btg_empresa  ON bauth.bos_tenant_gestion(empresa_id);
CREATE INDEX IF NOT EXISTS idx_btg_corriente ON bauth.bos_tenant_gestion(tenant_id, empresa_id) WHERE es_gestion_corriente = true;
CREATE INDEX IF NOT EXISTS idx_btg_estado   ON bauth.bos_tenant_gestion(estado);

COMMENT ON TABLE bauth.bos_tenant_gestion IS 'Gestión multigestión — años fiscales con períodos contables. Permite operar en múltiples gestiones simultáneas. SIN Bolivia: cierre anual, ajustes permitidos en gestiones cerradas (NC/ND).';
COMMENT ON COLUMN bauth.bos_tenant_gestion.estado IS 'ABIERTA (operando) → CERRADA (cierre anual SIN) → CERRADA_CON_AJUSTES (NC/ND posteriores) → ARCHIVADA (solo lectura, 8 años).';
COMMENT ON COLUMN bauth.bos_tenant_gestion.periodos IS '12 períodos mensuales con estado individual. Cada período puede cerrarse independientemente (cierre mensual).';
COMMENT ON COLUMN bauth.bos_tenant_gestion.es_gestion_corriente IS 'Solo UNA gestión corriente por tenant/empresa. Las transacciones nuevas van a la gestión corriente.';

-- ============================================================
-- 1-I. GESTION CALENDAR — Calendario de eventos, feriados y cierres
-- ============================================================
-- Propósito: Cada gestión tiene su propio calendario con eventos
--            que afectan la operación: feriados nacionales/regionales,
--            cierres fiscales SIN, períodos de mantenimiento, fechas
--            límite de declaraciones juradas, etc.
--            Los niveles inferiores (empresa, sucursal) heredan el
--            calendario del tenant y pueden sobrescribir o agregar.
-- Referencia: SIN Bolivia (calendario fiscal) · Ley General del Trabajo
--             (feriados) · ISO 8601 (fechas) · RRHH (vacaciones colectivas)

CREATE TABLE IF NOT EXISTS bauth.bos_gestion_calendario (
    evento_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gestion_id      UUID        NOT NULL REFERENCES bauth.bos_tenant_gestion(gestion_id),
    tenant_id       TEXT        NOT NULL,
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id), -- NULL = global tenant
    sucursal_id     UUID        REFERENCES bauth.bos_sucursal(sucursal_id), -- NULL = toda la empresa

    -- === IDENTIFICACIÓN DEL EVENTO ===
    nombre          TEXT        NOT NULL,                 -- 'Feriado Nacional — Día del Trabajo'
    tipo            TEXT        NOT NULL,                 -- FERIADO_NACIONAL|FERIADO_REGIONAL|CIERRE_FISCAL
                                                          -- |VACACION_COLECTIVA|MANTENIMIENTO|DDJJ_LIMITE
                                                          -- |CIERRE_MENSUAL|CIERRE_ANUAL|EVENTO_CORPORATIVO
    categoria       TEXT        DEFAULT 'LABORAL',       -- LABORAL|FISCAL|OPERATIVO|RRHH|ADUANERO
    ambito          TEXT        NOT NULL DEFAULT 'TODOS',-- TODOS|TENANT|EMPRESA|SUCURSAL

    -- === FECHA Y RECURRENCIA ===
    fecha_inicio    DATE        NOT NULL,
    fecha_fin       DATE,                                  -- NULL = un solo día
    es_recurrente   BOOLEAN     NOT NULL DEFAULT false,   -- Se repite cada año en la misma fecha
    regla_recurrencia TEXT,                                -- RRULE (RFC 5545): 'FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=1'

    -- === IMPACTO OPERATIVO ===
    dia_no_laborable BOOLEAN   NOT NULL DEFAULT false,    -- true = no se trabaja (feriado)
    bloquea_operaciones BOOLEAN NOT NULL DEFAULT false,   -- true = sistema bloqueado (cierre)
    afecta_facturacion BOOLEAN NOT NULL DEFAULT false,    -- true = no se emiten facturas SIN
    afecta_inventario BOOLEAN  NOT NULL DEFAULT false,    -- true = no se mueve inventario
    horario_especial  JSONB,                               -- {apertura:"10:00", cierre:"14:00"}

    -- === NOTIFICACIONES ===
    notificar_antes_dias INTEGER DEFAULT 7,               -- Alertar N días antes
    notificar_a       TEXT[],                              -- Roles o usuarios a notificar
    mensaje_notificacion TEXT,

    -- === METADATOS ===
    metadata        JSONB       DEFAULT '{}',
    created_by      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_cal_tipo CHECK (tipo IN (
        'FERIADO_NACIONAL','FERIADO_REGIONAL','FERIADO_LOCAL',
        'CIERRE_FISCAL','CIERRE_MENSUAL','CIERRE_ANUAL',
        'VACACION_COLECTIVA','MANTENIMIENTO','DDJJ_LIMITE',
        'EVENTO_CORPORATIVO','SUSPENSION_SIN','ADUANA_CIERRE'
    ),
    CONSTRAINT chk_cal_categoria CHECK (categoria IN ('LABORAL','FISCAL','OPERATIVO','RRHH','ADUANERO'),
    CONSTRAINT chk_cal_ambito CHECK (ambito IN ('TODOS','TENANT','EMPRESA','SUCURSAL'))
);

CREATE INDEX IF NOT EXISTS idx_bgc_gestion ON bauth.bos_gestion_calendario(gestion_id, fecha_inicio);
CREATE INDEX IF NOT EXISTS idx_bgc_empresa ON bauth.bos_gestion_calendario(empresa_id);
CREATE INDEX IF NOT EXISTS idx_bgc_tipo    ON bauth.bos_gestion_calendario(tipo, fecha_inicio);
CREATE INDEX IF NOT EXISTS idx_bgc_fecha   ON bauth.bos_gestion_calendario(fecha_inicio) WHERE fecha_inicio >= CURRENT_DATE;

COMMENT ON TABLE bauth.bos_gestion_calendario IS 'Calendario de eventos por gestión fiscal. Feriados, cierres SIN, DDJJ límites, vacaciones colectivas. Heredable: tenant→empresa→sucursal.';
COMMENT ON COLUMN bauth.bos_gestion_calendario.tipo IS 'Tipo de evento. FERIADO_NACIONAL (Ley Gral del Trabajo), CIERRE_FISCAL (SIN), DDJJ_LIMITE (fecha límite declaración), MANTENIMIENTO (ventana técnica).';
COMMENT ON COLUMN bauth.bos_gestion_calendario.bloquea_operaciones IS 'Si true, el sistema bloquea TODAS las operaciones durante este evento (cierre anual SIN, mantenimiento programado).';

-- ============================================================
-- 1-J. TENANT SCHEDULE — Horarios de operación por tenant/empresa/sucursal
-- ============================================================
-- Propósito: Definir los horarios de operación estándar en cada nivel
--            de la jerarquía. La sucursal hereda de empresa, que hereda
--            de tenant. NULL = heredar del nivel superior.
--            Los horarios se usan para:
--            - Control de acceso temporal (TemporalDomain)
--            - Validación de operaciones (no facturar fuera de horario)
--            - Planificación de tareas automáticas (fuera de horario)
--            - Cálculo de jornada laboral (RRHH, nómina)
-- Referencia: Ley General del Trabajo Bolivia · ISO 8601

CREATE TABLE IF NOT EXISTS bauth.bos_schedule (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id),   -- NULL = nivel tenant
    sucursal_id     UUID        REFERENCES bauth.bos_sucursal(sucursal_id), -- NULL = nivel empresa/tenant
    nombre          TEXT        NOT NULL,                 -- 'Horario Estándar', 'Turno Mañana'

    -- === DÍAS DE OPERACIÓN ===
    lunes           BOOLEAN     NOT NULL DEFAULT true,
    martes          BOOLEAN     NOT NULL DEFAULT true,
    miercoles       BOOLEAN     NOT NULL DEFAULT true,
    jueves          BOOLEAN     NOT NULL DEFAULT true,
    viernes         BOOLEAN     NOT NULL DEFAULT true,
    sabado          BOOLEAN     NOT NULL DEFAULT false,
    domingo         BOOLEAN     NOT NULL DEFAULT false,

    -- === HORARIOS ===
    hora_apertura   TIME        NOT NULL DEFAULT '08:00',
    hora_cierre     TIME        NOT NULL DEFAULT '18:00',
    -- Jornada continua o partida
    tipo_jornada    TEXT        NOT NULL DEFAULT 'CONTINUA', -- CONTINUA|PARTIDA|FLEXIBLE|TURNOS
    -- Si es partida: pausa de mediodía
    pausa_inicio    TIME,                                  -- 12:00
    pausa_fin       TIME,                                  -- 14:00
    -- Si es turnos: múltiples franjas horarias
    turnos          JSONB,                                  -- [{"nombre":"Mañana","inicio":"06:00","fin":"14:00"},{"nombre":"Tarde","inicio":"14:00","fin":"22:00"}]

    -- === HORAS EXTRAS Y LÍMITES ===
    horas_max_diarias   INTEGER DEFAULT 8,
    horas_max_semanales INTEGER DEFAULT 48,                -- Bolivia: 48h semanales (Ley Gral del Trabajo)
    permite_horas_extra BOOLEAN DEFAULT false,
    max_horas_extra_diarias INTEGER DEFAULT 2,

    -- === CONTROL DE ACCESO ===
    -- Franja de tolerancia para entrada/salida
    tolerancia_entrada_min INTEGER DEFAULT 15,             -- Minutos de gracia al entrar
    tolerancia_salida_min  INTEGER DEFAULT 15,             -- Minutos de gracia al salir
    -- Fuera de horario
    acceso_fuera_horario    TEXT    DEFAULT 'BLOQUEADO',   -- BLOQUEADO|PERMITIDO|REQUIERE_APROBACION|SOLO_LECTURA
    requiere_aprobacion_fuera_horario BOOLEAN DEFAULT true,

    -- === ZONA HORARIA ===
    timezone        TEXT,                                  -- NULL = heredar. IANA TZ: 'America/La_Paz'

    -- === ESTADO ===
    es_default      BOOLEAN     NOT NULL DEFAULT false,   -- Horario por defecto del nivel
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_jornada CHECK (tipo_jornada IN ('CONTINUA','PARTIDA','FLEXIBLE','TURNOS'),
    CONSTRAINT chk_fuera_horario CHECK (acceso_fuera_horario IN ('BLOQUEADO','PERMITIDO','REQUIERE_APROBACION','SOLO_LECTURA'))
);

CREATE INDEX IF NOT EXISTS idx_bsch_tenant   ON bauth.bos_schedule(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bsch_empresa  ON bauth.bos_schedule(empresa_id);
CREATE INDEX IF NOT EXISTS idx_bsch_sucursal ON bauth.bos_schedule(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_bsch_default  ON bauth.bos_schedule(tenant_id, empresa_id, sucursal_id) WHERE es_default = true;

COMMENT ON TABLE bauth.bos_schedule IS 'Horarios de operación jerárquicos: tenant→empresa→sucursal. NULL = heredar del padre. Define días laborables, jornada, turnos, horas extra, y control de acceso fuera de horario.';
COMMENT ON COLUMN bauth.bos_schedule.turnos IS 'Para tipo_jornada=TURNOS: array JSON con múltiples franjas horarias [{nombre, inicio, fin}]. Ej: turno mañana 06:00-14:00, tarde 14:00-22:00, noche 22:00-06:00.';
COMMENT ON COLUMN bauth.bos_schedule.acceso_fuera_horario IS 'BLOQUEADO (denegar acceso), PERMITIDO (sin restricción), REQUIERE_APROBACION (step-up MFA), SOLO_LECTURA (consultas sin modificaciones).';

-- ============================================================
-- 1-K. DOMINIO FÍSICO — Jerarquía de ubicaciones y dispositivos
-- ============================================================
-- Propósito: Modelar la jerarquía completa del dominio físico desde
--           país hasta dispositivo individual. Basado en:
--   BS 5979:2007 (UK) — 5 zonas de seguridad física
--   BSI IT-Grundschutz S 1.79 — 4 zonas (0=pública → 3=alta seguridad)
--   NZ PSR Framework — 5 zonas (Public→Work→Restricted→Security→High)
--   CPTED / ASIS International — 4 zonas en capas
--   IEC 60839-11-5:2020 — OSDP (Open Supervised Device Protocol)
--   SIA OSDP v2.2.2 — Control de acceso físico estándar
--
-- JERARQUÍA:
--   País → Ciudad → Sitio → Edificio → Piso → Área/Zona → Dispositivo
--
--   Cada nivel hereda la clasificación de seguridad de su padre.
--   Un dispositivo solo puede estar en UN área.
--   Las zonas definen el nivel de seguridad requerido para acceder.

-- ============================================================
-- 1-K1. SITIO FÍSICO — Terreno, propiedad, campus
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_sitio_fisico (
    sitio_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'SITIO-LAPAZ-CENTRO'
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Campus Central La Paz'
    pais_iso        CHAR(2)     NOT NULL REFERENCES bauth.bos_pais(codice_iso_alfa2),
    ciudad_id UUID      REFERENCES bauth.bos_ciudad(ciudad_id),
    direccion       TEXT,                                 -- 'Av. Camacho 1234'
    codigo_postal   TEXT,
    latitud         NUMERIC(9,6),
    longitud        NUMERIC(9,6),
    geo_fence_radius_m INTEGER  DEFAULT 100,              -- Radio del geo-fence en metros
    tipo            TEXT        NOT NULL DEFAULT 'COMERCIAL', -- COMERCIAL|INDUSTRIAL|RESIDENCIAL|GUBERNAMENTAL|MILITAR
    zona_seguridad  TEXT        NOT NULL DEFAULT 'ZONA_2',-- ZONA_0 (pública) → ZONA_5 (máxima seguridad)
    perimetro_tipo  TEXT        DEFAULT 'CERCO',          -- CERCO|MURO|BARRERA_VEHICULAR|NINGUNO
    iluminacion_perimetral BOOLEAN DEFAULT false,
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_sitio_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5'))
);

CREATE INDEX IF NOT EXISTS idx_sf_tenant ON bauth.bos_sitio_fisico(tenant_id);

COMMENT ON TABLE bauth.bos_sitio_fisico IS 'Sitio físico: terreno, propiedad, campus. Primer nivel de la jerarquía física. BS 5979 Zone 0-1.';
COMMENT ON COLUMN bauth.bos_sitio_fisico.zona_seguridad IS 'ZONA_0 (pública, sin control) → ZONA_5 (máxima, bóveda/data center). Define el nivel base de seguridad del sitio.';

-- ============================================================
-- 1-K2. EDIFICIO — Construcción dentro de un sitio
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_edificio (
    edificio_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'EDIF-A', 'EDIF-PRINCIPAL'
    sitio_id UUID        NOT NULL REFERENCES bauth.bos_sitio_fisico(sitio_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Edificio Administrativo'
    tipo            TEXT        NOT NULL DEFAULT 'OFICINA',-- OFICINA|ALMACEN|FABRICA|DATA_CENTER|TIENDA|ESTACIONAMIENTO
    pisos_total     INTEGER     DEFAULT 1,
    sotanos         INTEGER     DEFAULT 0,
    zona_seguridad  TEXT        NOT NULL DEFAULT 'ZONA_2',
    construccion_clase TEXT     DEFAULT 'CLASE_C',        -- CLASE_A (reforzado) → CLASE_D (liviano, no seguro)
    acceso_principal TEXT,                                -- 'Puerta Principal — Lado Norte'
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_edif_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5'),
    CONSTRAINT chk_edif_clase CHECK (construccion_clase IN ('CLASE_A','CLASE_B','CLASE_C','CLASE_D'))
);

CREATE INDEX IF NOT EXISTS idx_edif_sitio ON bauth.bos_edificio(sitio_id);

COMMENT ON TABLE bauth.bos_edificio IS 'Edificio dentro de un sitio. BS 5979 Zone 2-3. Construcción clase según resistencia física.';
COMMENT ON COLUMN bauth.bos_edificio.construccion_clase IS 'CLASE_A (reforzado, ballistico) → CLASE_D (liviano, no es barrera efectiva). BS 5979.';

-- ============================================================
-- 1-K3. PISO / NIVEL — Planta dentro de un edificio
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_piso (
    piso_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'EDIF-A-PB', 'EDIF-A-P1'
    edificio_id UUID        NOT NULL REFERENCES bauth.bos_edificio(edificio_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Planta Baja', 'Piso 1', 'Sótano 1'
    numero          INTEGER     NOT NULL,                 -- 0=PB, 1=P1, -1=S1
    zona_seguridad  TEXT        NOT NULL DEFAULT 'ZONA_2',
    tiene_control_acceso BOOLEAN DEFAULT false,           -- Punto de control en acceso al piso
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (edificio_id, numero),
    CONSTRAINT chk_piso_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5'))
);

CREATE INDEX IF NOT EXISTS idx_piso_edif ON bauth.bos_piso(edificio_id);

COMMENT ON TABLE bauth.bos_piso IS 'Piso/nivel dentro de un edificio. Control de acceso vertical (escaleras, ascensores).';

-- ============================================================
-- 1-K4. ÁREA FÍSICA — Oficina, sala, pasillo, zona dentro de un piso
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_area_fisica (
    area_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'AREA-SERVIDORES', 'AREA-CAJAS'
    piso_id UUID        NOT NULL REFERENCES bauth.bos_piso(piso_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Sala de Servidores', 'Oficina Gerencia', 'Área de Cajas'
    tipo            TEXT        NOT NULL DEFAULT 'OFICINA',-- OFICINA|SALA_REUNIONES|SERVIDORES|CAJAS|ALMACEN|BAÑO|COCINA|PASILLO|VESTIBULO|BOVEDA
    zona_seguridad  TEXT        NOT NULL DEFAULT 'ZONA_2',
    requiere_escolta BOOLEAN    DEFAULT false,            -- Visitantes deben ir acompañados
    requiere_2_personas BOOLEAN DEFAULT false,            -- Regla de dos personas (bóvedas, data centers)
    capacidad_max   INTEGER,                              -- Máximo de personas simultáneas
    tiene_mantrap   BOOLEAN     DEFAULT false,            -- Esclusa de seguridad entre dos puertas
    tiene_cctv      BOOLEAN     DEFAULT false,
    tiene_biometrico BOOLEAN    DEFAULT false,
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_area_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5'),
    CONSTRAINT chk_area_tipo CHECK (tipo IN ('OFICINA','SALA_REUNIONES','SERVIDORES','CAJAS','ALMACEN','BAÑO','COCINA','PASILLO','VESTIBULO','BOVEDA','ARCHIVO','ESTACIONAMIENTO','RECEPCION'))
);

CREATE INDEX IF NOT EXISTS idx_area_piso ON bauth.bos_area_fisica(piso_id);

COMMENT ON TABLE bauth.bos_area_fisica IS 'Área física dentro de un piso. Nivel donde se asocian dispositivos. Define reglas de acceso: escolta, dos personas, mantrap.';
COMMENT ON COLUMN bauth.bos_area_fisica.tipo IS 'Tipo de área. Define comportamiento: BOVEDA requiere 2 personas, SERVIDORES requiere biométrico + CCTV.';

-- ============================================================
-- 1-K5. DISPOSITIVO FÍSICO — Puertas, cámaras, sensores, actuadores
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_dispositivo_fisico (
    dispositivo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'PUERTA-001', 'CAM-023', 'CAJA-POS-10'
    area_id UUID        NOT NULL REFERENCES bauth.bos_area_fisica(area_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Puerta Principal Acceso Norte'
    tipo            TEXT        NOT NULL,                 -- PUERTA|CHAPA_ELECTROMAGNETICA|CERROJO_INTELIGENTE|TURNIQUETE
                                                          -- |CAMARA_IP|CAMARA_TERMICA|SENSOR_MOVIMIENTO|SENSOR_APERTURA
                                                          -- |SENSOR_TEMPERATURA|SENSOR_HUMO|ALARMA_INCENDIO
                                                          -- |CAJA_REGISTRADORA|TERMINAL_POS|LECTOR_QR|LECTOR_NFC
                                                          -- |LECTOR_HUELLA|LECTOR_FACIAL|PANEL_CONTROL|ACTUADOR
    fabricante      TEXT,                                 -- 'Hikvision', 'Bosch', 'ZKTeco', 'Dell'
    modelo          TEXT,                                 -- 'DS-2CD2047G2-L', 'GNET G1 Pro'
    numero_serie    TEXT,
    firmware_version TEXT,
    -- Comunicación
    protocolo       TEXT        NOT NULL DEFAULT 'OSDP',  -- OSDP|Wiegand|MQTT|ONVIF|HTTP|Modbus|BACnet|Zigbee
    direccion_com   TEXT,                                 -- OSDP address, IP:puerto, MQTT topic
    -- Seguridad
    zona_seguridad  TEXT        NOT NULL DEFAULT 'ZONA_2',
    nivel_autenticacion INTEGER DEFAULT 1,                -- 1=solo tarjeta, 2=tarjeta+PIN, 3=biométrico, 4=doble factor físico
    cifrado         TEXT        DEFAULT 'AES-128',        -- OSDP secure channel
    -- Estado
    estado          TEXT        NOT NULL DEFAULT 'ACTIVO',-- ACTIVO|INACTIVO|MANTENIMIENTO|ALARMA|FALLO
    ultimo_heartbeat TIMESTAMPTZ,
    ultimo_evento   JSONB,                                -- Último evento registrado: {tipo, timestamp, usuario, resultado}
    -- Asociación con POS lógico (si es caja registradora/terminal)
    pos_logico_id UUID        REFERENCES bauth.bos_pos_logico(pos_id),
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_disp_zona  CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5'),
    CONSTRAINT chk_disp_tipo  CHECK (tipo IN (
        'PUERTA','CHAPA_ELECTROMAGNETICA','CERROJO_INTELIGENTE','TURNIQUETE','BARRERA_VEHICULAR',
        'CAMARA_IP','CAMARA_TERMICA','CAMARA_360',
        'SENSOR_MOVIMIENTO','SENSOR_APERTURA','SENSOR_TEMPERATURA','SENSOR_HUMO','SENSOR_INUNDACION',
        'ALARMA_INCENDIO','SIRENA','PANEL_CONTROL','TECLADO_PIN',
        'CAJA_REGISTRADORA','TERMINAL_POS','LECTOR_QR','LECTOR_NFC','LECTOR_BARRAS',
        'LECTOR_HUELLA','LECTOR_FACIAL','LECTOR_IRIS','LECTOR_VOZ',
        'ACTUADOR','RELE','CONTROLADOR_ILUMINACION','TERMOSTATO'
    ),
    CONSTRAINT chk_disp_proto CHECK (protocolo IN ('OSDP','Wiegand','MQTT','ONVIF','HTTP','Modbus','BACnet','Zigbee','Z-Wave','LoRaWAN'))
);

CREATE INDEX IF NOT EXISTS idx_df_area     ON bauth.bos_dispositivo_fisico(area_id);
CREATE INDEX IF NOT EXISTS idx_df_tipo     ON bauth.bos_dispositivo_fisico(tipo);
CREATE INDEX IF NOT EXISTS idx_df_proto    ON bauth.bos_dispositivo_fisico(protocolo);
CREATE INDEX IF NOT EXISTS idx_df_pos      ON bauth.bos_dispositivo_fisico(pos_logico_id) WHERE pos_logico_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_df_estado   ON bauth.bos_dispositivo_fisico(estado) WHERE estado IN ('ALARMA','FALLO');

COMMENT ON TABLE bauth.bos_dispositivo_fisico IS 'Dispositivo físico dentro de un área. Puertas, cámaras, sensores, lectores, cajas registradoras. Controlado por NEXUS (bhnexus/banexus). Protocolo principal: OSDP (IEC 60839-11-5).';
COMMENT ON COLUMN bauth.bos_dispositivo_fisico.protocolo IS 'Protocolo de comunicación: OSDP (puertas, lectores), ONVIF (cámaras), MQTT (sensores IoT), Modbus/BACnet (actuadores industriales).';
COMMENT ON COLUMN bauth.bos_dispositivo_fisico.nivel_autenticacion IS '1=tarjeta, 2=tarjeta+PIN, 3=biométrico, 4=doble factor físico. Define qué métodos de autenticación requiere este dispositivo.';

-- ============================================================
-- 1-L. DOMINIO FINANCIERO — Control de transacciones y decisiones
-- ============================================================
-- Propósito: Controlar TODO el flujo financiero del ecosistema:
--           límites de transacción, flujos de aprobación, matriz
--           de decisión, tipos de documentos financieros, y
--           auditoría financiera reforzada.
--
-- ESTÁNDARES:
--   SOX §302/§404 (Sarbanes-Oxley) — controles financieros documentados
--   COSO Internal Control Framework — ambiente de control, evaluación de riesgo
--   PCI DSS 4.0 Req.7 — privilegio mínimo en sistemas financieros
--   PCI DSS 4.0 Req.10 — auditoría completa de operaciones financieras
--   ISO 27001:2022 A.5.3 — segregación de funciones (SoD)
--   ISO 27001:2022 A.8.2 — acceso privilegiado
--   NIC 1 (Presentación EEFF) / NIC 8 (Políticas contables)
--   ISACA COBIT 2019 — gobierno de TI financiero

-- ============================================================
-- 1-L1. TIPO DE TRANSACCIÓN FINANCIERA
-- ============================================================
    tipo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- 'FAC_EMITIR', 'PAGO_APROBAR', 'NC_EMITIR'
    nombre          TEXT        NOT NULL,                 -- 'Emitir Factura', 'Aprobar Pago'
    categoria       TEXT        NOT NULL,                 -- VENTAS|COMPRAS|PAGOS|COBROS|NOMINA|INVENTARIO|TRIBUTARIO
    riesgo          TEXT        NOT NULL DEFAULT 'MEDIO', -- BAJO|MEDIO|ALTO|CRITICO
    requiere_dual_control BOOLEAN DEFAULT false,          -- SOX: transacciones críticas requieren 2 personas
    requiere_evidencia BOOLEAN  DEFAULT true,             -- Documento soporte obligatorio
    afecta_libros_contables BOOLEAN DEFAULT true,         -- Impacta mayor contable
    notificacion_sin BOOLEAN    DEFAULT false,            -- Requiere notificación a entidad reguladora SIN
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ftt_riesgo CHECK (riesgo IN ('BAJO','MEDIO','ALTO','CRITICO'),
    CONSTRAINT chk_ftt_categoria CHECK (categoria IN ('VENTAS','COMPRAS','PAGOS','COBROS','NOMINA','INVENTARIO','TRIBUTARIO','BANCARIO','ACTIVOS_FIJOS','IMPORTACION','EXPORTACION'))
);


-- ============================================================
-- 1-L2. LÍMITES DE TRANSACCIÓN FINANCIERA
-- ============================================================
-- ============================================================
-- 1-L1. TIPOS DE TRANSACCIÓN FINANCIERA
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_tipo_transaccion (
    tipo_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre          TEXT        NOT NULL,
    categoria       TEXT        NOT NULL,
    riesgo          TEXT        NOT NULL DEFAULT 'MEDIO',
    requiere_dual_control BOOLEAN DEFAULT false,
    requiere_evidencia BOOLEAN  DEFAULT true,
    afecta_libros_contables BOOLEAN DEFAULT true,
    notificacion_sin BOOLEAN    DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT,
    CONSTRAINT chk_ftt_riesgo CHECK (riesgo IN ('BAJO','MEDIO','ALTO','CRITICO'),
    CONSTRAINT chk_ftt_categoria CHECK (categoria IN ('VENTAS','COMPRAS','PAGOS','COBROS','NOMINA','INVENTARIO','TRIBUTARIO','BANCARIO','ACTIVOS_FIJOS','IMPORTACION','EXPORTACION'))
);

COMMENT ON TABLE bauth.bos_financial_tipo_transaccion IS 'Tipos de transacciones financieras con clasificación de riesgo y requisitos de control. SOX §302. [ISO 20022] [FATF 16]';

CREATE TABLE IF NOT EXISTS bauth.bos_financial_limit (
    limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id), -- NULL = aplica a todo el tenant
    rol_id UUID        REFERENCES bauth.bos_rol_template(id),    -- NULL = aplica a todos los roles
    tipo_transaccion UUID       REFERENCES bauth.bos_financial_tipo_transaccion(tipo_id), -- NULL = todas
    moneda          CHAR(3)     REFERENCES bauth.bos_moneda(codice_iso),

    -- Límites por período
    limite_por_operacion NUMERIC(16,2),                  -- Máximo por transacción individual
    limite_diario   NUMERIC(16,2),                        -- Máximo acumulado diario
    limite_semanal  NUMERIC(16,2),                        -- Máximo acumulado semanal
    limite_mensual  NUMERIC(16,2),                        -- Máximo acumulado mensual
    limite_anual    NUMERIC(16,2),                        -- Máximo acumulado anual

    -- Por período de gestión
    limite_por_gestion NUMERIC(16,2),                     -- Máximo por gestión fiscal

    -- Contadores actuales (resetean según el período)
    acumulado_diario   NUMERIC(16,2) DEFAULT 0,
    acumulado_mensual  NUMERIC(16,2) DEFAULT 0,
    acumulado_anual    NUMERIC(16,2) DEFAULT 0,
    ultimo_reset_diario   DATE,
    ultimo_reset_mensual  DATE,

    -- Jerarquía de aprobación cuando se excede el límite
    excede_limite_accion TEXT  DEFAULT 'BLOQUEAR',       -- BLOQUEAR|REQUIERE_APROBACION|REQUIERE_DUAL_CONTROL|NOTIFICAR
    excede_limite_aprobador_1 TEXT,                       -- Rol requerido para aprobar (primer nivel)
    excede_limite_aprobador_2 TEXT,                       -- Rol requerido para aprobar (segundo nivel, dual control)

    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fl_accion CHECK (excede_limite_accion IN ('BLOQUEAR','REQUIERE_APROBACION','REQUIERE_DUAL_CONTROL','NOTIFICAR'))
);

CREATE INDEX IF NOT EXISTS idx_fl_rol ON bauth.bos_financial_limit(tenant_id, rol_id);
CREATE INDEX IF NOT EXISTS idx_fl_empresa ON bauth.bos_financial_limit(empresa_id);

COMMENT ON TABLE bauth.bos_financial_limit IS 'Límites de transacción financiera por tenant/empresa/rol/tipo. COSO: control de actividades. SOX §404: controles documentados.';
COMMENT ON COLUMN bauth.bos_financial_limit.excede_limite_accion IS 'BLOQUEAR (rechazar), REQUIERE_APROBACION (un aprobador), REQUIERE_DUAL_CONTROL (dos aprobadores SOX), NOTIFICAR (permitir pero alertar).';
COMMENT ON COLUMN bauth.bos_financial_limit.limite_por_gestion IS 'Límite máximo por gestión fiscal. Útil para presupuestos anuales y control de gasto.';

-- ============================================================
-- 1-L3. MATRIZ DE DECISIÓN FINANCIERA
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_decision_matrix (
    decision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id),
    nombre          TEXT        NOT NULL,                 -- 'Aprobación de Ventas — Nivel 1'
    tipo_transaccion UUID      NOT NULL REFERENCES bauth.bos_financial_tipo_transaccion(tipo_id),
    moneda          CHAR(3)     REFERENCES bauth.bos_moneda(codice_iso),

    -- Niveles de decisión en cascada
    nivel_1_rol UUID        REFERENCES bauth.bos_rol_template(id), -- Primer nivel de aprobación
    nivel_1_monto_max NUMERIC(16,2),                  -- Hasta qué monto puede aprobar este nivel
    nivel_1_puede_delegar BOOLEAN DEFAULT false,

    nivel_2_rol UUID        REFERENCES bauth.bos_rol_template(id), -- Segundo nivel (escala)
    nivel_2_monto_max NUMERIC(16,2),                  -- Hasta qué monto puede aprobar
    nivel_2_puede_delegar BOOLEAN DEFAULT false,

    nivel_3_rol UUID        REFERENCES bauth.bos_rol_template(id), -- Tercer nivel (alta dirección)
    nivel_3_monto_max NUMERIC(16,2),                  -- NULL = sin límite superior

    -- Condiciones especiales
    requiere_comite BOOLEAN     DEFAULT false,           -- Requiere aprobación de comité (ej: inversiones > $1M)
    requiere_evidencia_adjunta BOOLEAN DEFAULT false,    -- Documento soporte obligatorio
    tiempo_max_aprobacion_horas INTEGER DEFAULT 48,      -- SLA de aprobación
    escala_automatica_si_no_respuesta BOOLEAN DEFAULT true, -- Si no aprueba en SLA, escala al siguiente nivel

    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdm_empresa ON bauth.bos_financial_decision_matrix(empresa_id);

COMMENT ON TABLE bauth.bos_financial_decision_matrix IS 'Matriz de decisión financiera en cascada. Define qué rol puede aprobar qué monto para cada tipo de transacción. COSO + SOX compliant.';
COMMENT ON COLUMN bauth.bos_financial_decision_matrix.nivel_1_monto_max IS 'Monto máximo que puede aprobar el primer nivel. Si se excede → escala automática al nivel 2.';
COMMENT ON COLUMN bauth.bos_financial_decision_matrix.escala_automatica_si_no_respuesta IS 'Si true y el aprobador no responde en SLA → escala al siguiente nivel automáticamente.';

-- ============================================================
-- 1-L4. APROBACIÓN FINANCIERA — Registro de cada decisión
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_approval (
    approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id),
    tipo_transaccion UUID      NOT NULL REFERENCES bauth.bos_financial_tipo_transaccion(tipo_id),
    referencia      TEXT        NOT NULL,                 -- ID de la factura, pago, NC: 'FAC-12345'
    monto           NUMERIC(16,2) NOT NULL,
    moneda          CHAR(3)     REFERENCES bauth.bos_moneda(codice_iso),

    -- Solicitante
    solicitante_uuid UUID       NOT NULL REFERENCES bauth.bos_user_template(uuid),
    solicitud_fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    solicitud_motivo TEXT,

    -- Niveles de aprobación recorridos
    nivel_actual    INTEGER     NOT NULL DEFAULT 1,      -- 1, 2, 3
    nivel_total     INTEGER     NOT NULL DEFAULT 1,      -- Cuántos niveles requiere esta transacción

    -- Aprobación efectiva
    aprobador_uuid  UUID        REFERENCES bauth.bos_user_template(uuid),
    decision        TEXT,                                  -- APROBADO|RECHAZADO|DEVUELTO|ESCALADO
    decision_fecha  TIMESTAMPTZ,
    decision_comentario TEXT,
    evidencia_adjunta JSONB,                              -- URLs a documentos soporte

    -- Escalamiento
    escalado_a_uuid UUID       REFERENCES bauth.bos_user_template(uuid),
    escalado_fecha  TIMESTAMPTZ,
    escalado_motivo TEXT,

    estado          TEXT        NOT NULL DEFAULT 'PENDIENTE',-- PENDIENTE|EN_REVISION|APROBADO|RECHAZADO|ESCALADO|CANCELADO
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fa_decision CHECK (decision IS NULL OR decision IN ('APROBADO','RECHAZADO','DEVUELTO','ESCALADO'),
    CONSTRAINT chk_fa_estado CHECK (estado IN ('PENDIENTE','EN_REVISION','APROBADO','RECHAZADO','ESCALADO','CANCELADO'))
);

CREATE INDEX IF NOT EXISTS idx_fa_empresa   ON bauth.bos_financial_approval(empresa_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fa_solicitud ON bauth.bos_financial_approval(solicitante_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fa_pendiente ON bauth.bos_financial_approval(estado) WHERE estado IN ('PENDIENTE','EN_REVISION','ESCALADO');
CREATE INDEX IF NOT EXISTS idx_fa_referencia ON bauth.bos_financial_approval(referencia);

COMMENT ON TABLE bauth.bos_financial_approval IS 'Registro de cada decisión de aprobación financiera. SOX §404: evidencia de control. Auditoría completa con trazabilidad de escalamiento.';
COMMENT ON COLUMN bauth.bos_financial_approval.nivel_actual IS 'Nivel actual en la cascada de aprobación. Avanza 1→2→3 según la matriz de decisión.';
COMMENT ON COLUMN bauth.bos_financial_approval.evidencia_adjunta IS 'URLs a documentos soporte requeridos por SOX: cotizaciones, contratos, análisis de riesgo.';

-- ============================================================
-- 1-L5. OPERACIÓN SOBRE DOCUMENTO FINANCIERO
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_document_operation (
    operacion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- 'FAC_EMITIR', 'FAC_ANULAR', 'NC_CREAR'
    tipo_documento  TEXT        NOT NULL,                 -- FACTURA|NOTA_CREDITO|NOTA_DEBITO|PAGO|COBRO|ASIENTO
    verbo           TEXT        NOT NULL,                 -- CREATE|READ|UPDATE|DELETE|ANULAR|APROBAR|RECHAZAR|REIMPRIMIR
    descripcion     TEXT        NOT NULL,
    afecta_dosificacion BOOLEAN DEFAULT false,            -- Consume número de factura (SIN)
    requiere_firma_digital BOOLEAN DEFAULT false,          -- Requiere firma ADSIB
    notifica_sin    BOOLEAN     DEFAULT false,            -- Notifica al SIN en tiempo real
    activo          BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT chk_fdo_doc CHECK (tipo_documento IN ('FACTURA','NOTA_CREDITO','NOTA_DEBITO','PAGO','COBRO','ASIENTO','RETENCION','PERCEPCION','GUIA_REMISION','ORDEN_COMPRA','CONTRATO','GASTO'),
    CONSTRAINT chk_fdo_verbo CHECK (verbo IN ('CREATE','READ','UPDATE','DELETE','ANULAR','APROBAR','RECHAZAR','REIMPRIMIR','EXPORTAR','CERRAR','REABRIR'))
);

COMMENT ON TABLE bauth.bos_financial_document_operation IS 'Catálogo de operaciones posibles sobre cada tipo de documento financiero. Matriz documento × verbo.';
COMMENT ON COLUMN bauth.bos_financial_document_operation.afecta_dosificacion IS 'Si consume numeración SIN. ANULAR una factura NO libera el número.';

-- ============================================================
-- 1-L6. PERMISOS FINANCIEROS POR ROL — Quién puede hacer qué
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_role_permission (
    permiso_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID        NOT NULL REFERENCES bauth.bos_rol_template(id),
    operacion_id UUID        NOT NULL REFERENCES bauth.bos_financial_document_operation(operacion_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id), -- NULL = global tenant

    -- Restricciones
    monto_max_por_operacion NUMERIC(16,2),              -- NULL = hereda del límite financiero
    requiere_dual_control   BOOLEAN DEFAULT false,       -- SOX: necesita segundo aprobador
    requiere_step_up        BOOLEAN DEFAULT false,       -- Requiere elevación LoA (RFC 9470)
    step_up_loa             INTEGER DEFAULT 2,           -- Nivel LoA requerido para step-up
    horario_restringido     BOOLEAN DEFAULT false,        -- Solo en horario laboral

    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rol_id, operacion_id, tenant_id, empresa_id)
);

CREATE INDEX IF NOT EXISTS idx_frp_rol ON bauth.bos_financial_role_permission(rol_id);

COMMENT ON TABLE bauth.bos_financial_role_permission IS 'Permisos financieros granulares por rol × operación. Matriz de control de acceso financiero. SOX §404.';
COMMENT ON COLUMN bauth.bos_financial_role_permission.requiere_dual_control IS 'SOX: para operaciones críticas, se necesita un segundo aprobador independiente.';
COMMENT ON COLUMN bauth.bos_financial_role_permission.requiere_step_up IS 'RFC 9470: elevar temporalmente el LoA para aprobar operaciones sensibles.';

-- ============================================================
-- 1-M. DOMINIO LÓGICO — Zonas de negocio, verbos y permisos
-- ============================================================
-- Propósito: Controlar el acceso a las zonas lógicas de negocio
--           (ventas, contabilidad, inventario, RRHH, etc.) con
--           verbos estándar (CRUD + APPROVE + EXPORT + etc.).
--           Basado en el patrón ZRB (Zoned Role-Based Access Control)
--           y OASIS XACML 3.0.
--
-- ESTÁNDARES:
--   ZRB (Zoned Role-Based) — Wang 2024, Springer SEDE
--   OASIS XACML 3.0 — arquitectura de políticas de acceso
--   NIST RBAC §4 — roles + permisos + sesiones
--   OWASP ASVS v5.0 V4 — control de acceso

-- ============================================================
-- 1-M1. ZONA DE NEGOCIO — Área funcional lógica
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_zona_logica (
    zona_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- 'VENTAS', 'CONTABILIDAD', 'INVENTARIO'
    nombre          TEXT        NOT NULL,                 -- 'Ventas y Facturación'
    descripcion     TEXT,
    categoria       TEXT        NOT NULL DEFAULT 'OPERATIVA',-- OPERATIVA|ADMINISTRATIVA|FINANCIERA|RRHH|TECNICA|DIRECTIVA
    ambito          TEXT        NOT NULL DEFAULT 'TENANT',-- TENANT|EMPRESA|SUCURSAL
    es_critica      BOOLEAN     NOT NULL DEFAULT false,   -- Zonas críticas requieren auditoría completa
    requiere_segregacion BOOLEAN DEFAULT false,           -- SoD: no se puede tener permisos en zonas conflictivas
    zona_conflicto  TEXT[],                                -- Zonas SoD: ['COMPRAS','AUDITORIA']
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_zl_categoria CHECK (categoria IN ('OPERATIVA','ADMINISTRATIVA','FINANCIERA','RRHH','TECNICA','DIRECTIVA','FISCAL','COMERCIAL'),
    CONSTRAINT chk_zl_ambito CHECK (ambito IN ('TENANT','EMPRESA','SUCURSAL'))
);

COMMENT ON TABLE bauth.bos_zona_logica IS 'Zona de negocio lógica. Área funcional abstracta independiente de la implementación. Patrón ZRB (Zoned Role-Based).';
COMMENT ON COLUMN bauth.bos_zona_logica.zona_conflicto IS 'Zonas conflictivas para SoD. Ej: COMPRAS no puede coexistir con AUDITORIA en el mismo usuario.';

-- ============================================================
-- 1-M2. VERBOS — Suprimido. Reemplazado por bos_privilege.bos_verb (§20.4)
-- ============================================================
-- El catálogo global de verbos está en bos_privilege.bos_verb
-- (verb_code SMALLINT, verb_name, verb_slug). Label encoding.
-- La tabla bauth.bos_verbo fue eliminada (huérfana, 0 registros).
-- ============================================================

-- ============================================================
-- 1-M3. PERMISO LÓGICO — Zona × Verbo × Rol
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_permiso_logico (
    permiso_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID        NOT NULL REFERENCES bauth.bos_rol_template(id),
    zona_id UUID        NOT NULL REFERENCES bauth.bos_zona_logica(zona_id),
    verbo_id        SMALLINT    NOT NULL,                    -- FK → bos_privilege.bos_verb(verb_code)
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    empresa_id      UUID        REFERENCES bauth.bos_empresa(empresa_id),

    -- Restricciones
    scope           TEXT        NOT NULL DEFAULT 'EMPRESA',-- GLOBAL|EMPRESA|SUCURSAL|PERSONAL
    limit_registros INTEGER,                               -- Máximo de registros por consulta
    requiere_step_up BOOLEAN    DEFAULT false,             -- Elevación LoA requerida
    clasificacion_datos TEXT   DEFAULT 'INTERNAL',         -- PUBLIC|INTERNAL|CONFIDENTIAL|RESTRICTED
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rol_id, zona_id, verbo_id, tenant_id, empresa_id),
    CONSTRAINT fk_permiso_verbo FOREIGN KEY (verbo_id) REFERENCES bos_privilege.bos_verb(verb_code),
    CONSTRAINT chk_pl_scope CHECK (scope IN ('GLOBAL','EMPRESA','SUCURSAL','PERSONAL'),
    CONSTRAINT chk_pl_clasif CHECK (clasificacion_datos IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED'))
);

CREATE INDEX IF NOT EXISTS idx_pl_rol  ON bauth.bos_permiso_logico(rol_id);
CREATE INDEX IF NOT EXISTS idx_pl_zona ON bauth.bos_permiso_logico(zona_id);

COMMENT ON TABLE bauth.bos_permiso_logico IS 'Permiso granular: zona lógica × verbo × rol. NIST RBAC §4. Patrón ZRB. Controla qué puede hacer cada rol en cada zona de negocio.';
COMMENT ON COLUMN bauth.bos_permiso_logico.verbo_id IS 'Verbo de la operación. FK → bos_privilege.bos_verb.verb_code (SMALLINT: 1=create, 2=read, 3=update, 4=delete). Label encoding, NUNCA bitwise.';
COMMENT ON COLUMN bauth.bos_permiso_logico.scope IS 'GLOBAL (todo el tenant), EMPRESA (solo su empresa), SUCURSAL (solo su sucursal), PERSONAL (solo sus propios registros).';

-- ============================================================
-- 1-N. POLÍTICA DE ACTUALIZACIÓN DE CLAVES Y CREDENCIALES
-- ============================================================
-- Propósito: Gestionar el ciclo de vida completo de credenciales:
--           creación, rotación, expiración, compromiso, y
--           políticas diferenciadas por tipo de credencial.
--           NIST SP 800-63B Rev.4: sin rotación forzada sin
--           evidencia de compromiso. NIST SP 800-57 para claves
--           criptográficas.

CREATE TABLE IF NOT EXISTS bauth.bos_credential_policy (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- 'PASSWORDS', 'MFA_TOTP', 'M2M_CERTS', 'OAUTH_SECRETS'
    nombre          TEXT        NOT NULL,
    credential_type TEXT        NOT NULL,                 -- PASSWORD|TOTP|WEBAUTHN|X509_CERT|OAUTH_SECRET|API_KEY|ENCRYPTION_KEY|SIGNING_KEY
    -- Creación
    min_strength_bits INTEGER   NOT NULL DEFAULT 256,     -- Entropía mínima (NIST: ≥256 bits para CSPRNG)
    requiere_csprng  BOOLEAN    NOT NULL DEFAULT true,    -- Obligatorio: generador criptográfico
    formato_diceware BOOLEAN    DEFAULT false,            -- Usar palabras diceware para legibilidad humana

    -- Rotación (NIST SP 800-63B Rev.4: solo por compromiso para passwords)
    rota_por_tiempo  BOOLEAN    NOT NULL DEFAULT false,   -- false = NIST 800-63B Rev.4 (solo compromiso)
    ttl_max_dias     INTEGER,                             -- NULL = no expira. Solo para M2M y API keys
    rota_post_compromiso BOOLEAN NOT NULL DEFAULT true,   -- Rotación inmediata si se detecta compromiso
    rota_post_evento     BOOLEAN NOT NULL DEFAULT false,  -- Rotación tras evento (SU break-glass, incidente)

    -- Verificación y screening
    requiere_breach_screening BOOLEAN DEFAULT false,       -- Verificar contra HIBP (passwords)
    bloquea_tras_intentos INTEGER DEFAULT 10,             -- Bloquear cuenta tras N intentos fallidos
    periodo_bloqueo_minutos INTEGER DEFAULT 15,            -- Tiempo de bloqueo temporal

    -- Historial
    historial_retencion INTEGER DEFAULT 10,               -- Últimas N credenciales que no se pueden reutilizar
    notifica_cambio    BOOLEAN DEFAULT true,              -- Email/SMS al usuario tras cambio

    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_cp_type CHECK (credential_type IN ('PASSWORD','TOTP','WEBAUTHN','X509_CERT','OAUTH_SECRET','API_KEY','ENCRYPTION_KEY','SIGNING_KEY'))
);

COMMENT ON TABLE bauth.bos_credential_policy IS 'Política de ciclo de vida de credenciales. NIST SP 800-63B Rev.4: sin rotación forzada para passwords. NIST SP 800-57: rotación periódica para claves criptográficas.';
COMMENT ON COLUMN bauth.bos_credential_policy.rota_por_tiempo IS 'false para passwords (NIST 800-63B Rev.4). true para M2M certs (TTL 24h), OAuth secrets (90d), signing keys (180d).';
COMMENT ON COLUMN bauth.bos_credential_policy.rota_post_compromiso IS 'Rotación inmediata si se detecta en HIBP, breach database, o actividad sospechosa. Automático.';

-- ============================================================
-- 1-N1. CREDENTIAL ROTATION LOG — Auditoría de cambios de credenciales
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_credential_rotation_log (
    rotation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uuid       UUID        REFERENCES bauth.bos_user_template(uuid),
    credential_type TEXT        NOT NULL,
    motivo          TEXT        NOT NULL,                 -- COMPROMISO_DETECTADO|TTL_EXPIRADO|MANUAL|POST_EVENTO|PERIODICO
    origen_deteccion TEXT,                                -- HIBP|breach_db|siem_alert|user_report|admin_action
    rotado_por      TEXT        NOT NULL,                 -- 'auto' (sistema) o user_uuid (manual)
    rotado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    anterior_hash   TEXT,                                 -- Hash de la credencial anterior (para auditoría)
    nuevo_hash      TEXT,                                 -- Hash de la nueva credencial
    ttl_asignado    INTERVAL,                             -- Nuevo TTL (si aplica)
    notificado_al_usuario BOOLEAN DEFAULT false,
    evidencias      JSONB       DEFAULT '{}',
    CONSTRAINT chk_crl_motivo CHECK (motivo IN ('COMPROMISO_DETECTADO','TTL_EXPIRADO','MANUAL','POST_EVENTO','PERIODICO','CREACION'))
);

CREATE INDEX IF NOT EXISTS idx_crl_user ON bauth.bos_credential_rotation_log(user_uuid, rotado_en DESC);
CREATE INDEX IF NOT EXISTS idx_crl_tipo ON bauth.bos_credential_rotation_log(credential_type, rotado_en DESC);

COMMENT ON TABLE bauth.bos_credential_rotation_log IS 'Auditoría de cada cambio de credencial. Trazabilidad completa: quién, cuándo, por qué, origen de detección.';

-- ============================================================
-- 2. EMPRESA — Entidad legal con NIT propio + config regional
-- ============================================================
-- Una empresa es una entidad LEGAL independiente. La primera empresa
-- creada en el tenant es el propio SKULL (dueño de la plataforma).
-- Las empresas cliente (ACME, MAYA, etc.) son independientes:
-- cada una tiene su propio NIT, sus propias sucursales, sus propios
-- usuarios y roles. Los datos de una empresa NUNCA son visibles para otra.
-- La facturación electrónica SIN se emite a nombre de la empresa (NIT).
-- Referencia: SBOS-049 §4 (dimensión empresa)

CREATE TABLE IF NOT EXISTS bauth.bos_empresa (
    empresa_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'skull', 'acme', 'maya'
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    razon_social    TEXT        NOT NULL,                 -- Razón social legal
    nit             TEXT        NOT NULL,                 -- NIT boliviano (SIN)
    regimen_fiscal  TEXT        NOT NULL DEFAULT 'GENERAL',-- GENERAL|SIMPLIFICADO|AGROPECUARIO
    es_operador     BOOLEAN     NOT NULL DEFAULT false,   -- true = SKULL (dueño plataforma)

    -- === CONFIGURACIÓN REGIONAL (hereda del tenant, puede sobrescribir y extender) ===
    -- Principio MULTI: cada empresa puede tener N idiomas, N monedas, N timezones, N dominios.
    -- Los valores NULL heredan del tenant. Los valores definidos sobrescriben.
    -- Una empresa boliviana que vende a China necesita: es-BO (interno) + zh-CN (clientes chinos) + en-US (internacional).

    -- Idiomas activos de la empresa (extiende los del tenant)
    locale_default UUID        REFERENCES bauth.bos_idioma(locale), -- NULL = locale_default del tenant
    locales_extra   TEXT[],                                -- Idiomas ADICIONALES: '{zh-CN,en-US}' (FK implícito a bos_idioma)
    -- Ejemplo: tenant tiene {es-BO, pt-BR}. Empresa agrega {zh-CN, en-US}.
    -- Resultado efectivo: {es-BO, pt-BR, zh-CN, en-US}. Default: es-BO.

    -- Zonas horarias de interés (donde opera o tiene clientes)
    timezone_default TEXT,                                 -- NULL = timezone_default del tenant
    timezones_extra  TEXT[],                               -- Zonas ADICIONALES: '{Asia/Shanghai,America/New_York}'

    -- Monedas activas (extiende las del tenant)
    moneda_default  TEXT,                                  -- NULL = currency_default del tenant
    monedas_extra   JSONB,                                 -- Monedas ADICIONALES con datos:
                                                           -- [{"code":"CNY","symbol":"¥","nombre":"Yuan","precision":2,"exchange_to_default":1.45}]

    -- Monedas de la empresa
    currency_symbol TEXT        DEFAULT 'Bs.',
    date_format     TEXT,                                  -- NULL = heredar del tenant
    number_format   TEXT,                                  -- NULL = heredar del tenant

    -- Gestión
    multigestion_enabled BOOLEAN,                          -- NULL = hereda del tenant
    max_gestiones_abiertas INTEGER,
    fiscal_year_start_month INTEGER,

    -- Apariencia
    logo_url        TEXT,                                  -- Logo de la empresa (sobrescribe al tenant)
    theme_default   TEXT,                                  -- NULL = heredar del tenant
    -- Dirección y contacto
    direccion       TEXT,
    ciudad          TEXT,
    telefono        TEXT,
    email           TEXT,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',-- ACTIVE|SUSPENDED|TERMINATED
    max_sucursales  INTEGER     DEFAULT 5,
    max_usuarios    INTEGER     DEFAULT 50,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, nit),
    CONSTRAINT chk_empresa_status CHECK (status IN ('ACTIVE','SUSPENDED','TERMINATED'))
);

CREATE INDEX IF NOT EXISTS idx_empresa_tenant ON bauth.bos_empresa(tenant_id);
CREATE INDEX IF NOT EXISTS idx_empresa_nit    ON bauth.bos_empresa(nit);

COMMENT ON TABLE bauth.bos_empresa IS 'Entidad legal con NIT propio dentro del tenant. La primera empresa es SKULL (es_operador=true). Las demás son clientes independientes.';
COMMENT ON COLUMN bauth.bos_empresa.es_operador IS 'true = SKULL (dueño de la plataforma, puede crear otras empresas). false = empresa cliente (independiente, no puede crear otras empresas).';

-- ============================================================
-- 3. SUCURSAL — Ubicación física de una empresa
-- ============================================================
-- Una sucursal es una ubicación física (oficina, tienda, almacén)
-- de una empresa. Es la dimensión donde se aplican controles de
-- acceso físico (PhysicalDomain) y geoespaciales (GeospatialDomain).
-- Un Admin Sucursal (S017) gestiona el personal y los POS de su sucursal.
-- Referencia: SBOS-049 §4 (dimensión sucursal)

CREATE TABLE IF NOT EXISTS bauth.bos_sucursal (
    sucursal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'skull-lapaz', 'acme-central'
    empresa_id UUID        NOT NULL REFERENCES bauth.bos_empresa(empresa_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,
    direccion       TEXT,
    ciudad          TEXT,
    zona            TEXT,                                  -- Zona geográfica/fiscal
    -- Configuración regional (hereda de empresa si NULL)
    timezone        TEXT,                                  -- NULL = heredar de empresa
    horario_apertura TIME,                                 -- 08:00
    horario_cierre   TIME,                                 -- 18:00
    dias_operacion  TEXT[] DEFAULT '{MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY}',
    admin_user_uuid UUID,                                  -- S017 Admin Sucursal
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',-- ACTIVE|INACTIVE|CLOSED
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (empresa_id, sucursal_id)
);

CREATE INDEX IF NOT EXISTS idx_sucursal_empresa ON bauth.bos_sucursal(empresa_id);
CREATE INDEX IF NOT EXISTS idx_sucursal_tenant  ON bauth.bos_sucursal(tenant_id);

COMMENT ON TABLE bauth.bos_sucursal IS 'Ubicación física de una empresa. Control de acceso físico, geolocalización, y ámbito de operación de POS lógicos.';

-- ============================================================
-- 3-B. POS LÓGICO / PUNTO DE VENTA SIN — Registro fiscal Bolivia
-- ============================================================
-- Propósito: Un Punto de Venta (POS) registrado ante el SIN de Bolivia
--           para la emisión de facturas electrónicas/computarizadas.
--           Cada punto de venta tiene su propia dosificación, CUFD,
--           y configuración fiscal independiente por sucursal.
--
-- REGULACIÓN SIN BOLIVIA:
--   RND 10.0021.16 (Sistema de Facturación Virtual - SFV)
--   RND 102100000011 (Facturación Electrónica en Línea)
--   Artículo 16 — Dosificación por punto de venta/sucursal
--   Artículo 4 — Modalidades: Electrónica, Computarizada, Portal Web
--
-- CAMPOS FISCALES OBLIGATORIOS:
--   - NIT del contribuyente (en empresa)
--   - Código de sucursal registrado en SIN
--   - Número de punto de venta (dosificado por SIN)
--   - CUIS (Código Único de Iniciación de Sistemas)
--   - CUFD (Código Único de Facturación Diaria) — rota cada 24h
--   - CAFC (Código de Autorización de Facturación Computarizada)
--   - Leyenda obligatoria SIN
--   - Leyenda Derechos del Consumidor (Ley N° 453)
--   - Código QR en representación impresa
--
-- Referencia: SBOS-049 §6 · SIN SFV · RND 10.0021.16

CREATE TABLE IF NOT EXISTS bauth.bos_pos_logico (
    pos_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'POS-23', 'CAJA-01'
    sucursal_id UUID        NOT NULL REFERENCES bauth.bos_sucursal(sucursal_id),
    empresa_id UUID        NOT NULL REFERENCES bauth.bos_empresa(empresa_id),
    tenant_id       UUID        NOT NULL REFERENCES bauth.bos_tenant(tenant_id),
    nombre          TEXT        NOT NULL,                 -- 'Caja Norte', 'Terminal Almacén'

    -- === REGISTRO SIN ===
    codigo_sucursal_sin TEXT,                             -- Código de sucursal registrado en Padrón SIN
    numero_punto_venta  INTEGER NOT NULL DEFAULT 1,       -- Número de punto de venta (1, 2, 3... por sucursal)
    modalidad_facturacion TEXT NOT NULL DEFAULT 'COMPUTARIZADA_EN_LINEA',
                                                          -- ELECTRONICA_EN_LINEA|COMPUTARIZADA_EN_LINEA|PORTAL_WEB
    ambiente_sin        TEXT    NOT NULL DEFAULT 'PRODUCCION', -- PRUEBAS|PRODUCCION
    tipo_factura        TEXT    NOT NULL DEFAULT 'FACTURA_CREDITO_FISCAL',
                                                          -- FACTURA_CREDITO_FISCAL|FACTURA_SIN_CREDITO|NOTA_CREDITO_DEBITO
                                                          -- |FACTURA_EXPORTACION|FACTURA_SERVICIOS_BASICOS|etc. (27 tipos)

    -- === DOSIFICACIÓN SIN (Art. 16 RND 10.0021.16) ===
    numero_autorizacion  TEXT,                            -- Número de autorización de dosificación otorgado por SIN
    tipo_dosificacion    TEXT    DEFAULT 'POR_TIEMPO',    -- POR_TIEMPO|POR_CANTIDAD
    fecha_limite_emision DATE,                            -- Fecha límite para emitir facturas de esta dosificación
    rango_inicio         BIGINT,                          -- Número de factura inicial del rango autorizado
    rango_fin            BIGINT,                          -- Número de factura final del rango autorizado
    numero_actual         BIGINT  DEFAULT 0,              -- Último número de factura emitido (contador)
    fecha_solicitud_dosif TIMESTAMPTZ,                    -- Fecha de solicitud de dosificación
    fecha_activacion_dosif TIMESTAMPTZ,                   -- Fecha de activación de la dosificación
    estado_dosificacion   TEXT    DEFAULT 'PENDIENTE',    -- PENDIENTE|ACTIVA|VENCIDA|AGOTADA|REVOCADA

    -- === CÓDIGOS FISCALES ===
    cuis            TEXT,                                 -- Código Único de Iniciación de Sistemas (vincula contribuyente ↔ sistema)
    cuis_otorgado_en TIMESTAMPTZ,                         -- Fecha de obtención del CUIS
    cufd            TEXT,                                 -- Código Único de Facturación Diaria (rota cada 24h. SIN lo renueva automáticamente)
    cufd_otorgado_en TIMESTAMPTZ,                         -- Fecha/hora de obtención del CUFD
    cufd_vigencia   TIMESTAMPTZ,                          -- Vigencia del CUFD (24h desde otorgamiento)
    cafc            TEXT,                                 -- Código de Autorización de Facturación Computarizada (solo modalidad Computarizada)
    cafc_vigencia   DATE,                                 -- Fecha de vigencia del CAFC

    -- === LEYENDAS OBLIGATORIAS (generadas por SIN) ===
    leyenda_sin     TEXT    NOT NULL DEFAULT 'ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAÍS. EL USO ILÍCITO DE ÉSTA SERÁ SANCIONADO DE ACUERDO A LEY',
    leyenda_derechos_consumidor TEXT,                     -- Asignada por SIN en cada dosificación (Ley N° 453)
    leyenda_representacion TEXT DEFAULT 'Este documento es una representación visual de un documento digital emitido en una modalidad de facturación en línea',
    leyenda_credito_fiscal  TEXT,                         -- Solo estaciones de servicio: "Importe base para crédito fiscal, Ley Nº 317"

    -- === ACTIVIDAD ECONÓMICA ===
    caeb_codigo     TEXT,                                 -- Código CAEB (Clasificador de Actividades Económicas de Bolivia)
    caeb_descripcion TEXT,                                -- Descripción de la actividad económica principal

    -- === CONEXIÓN CON SIN (WebService) ===
    sin_wsdl_url        TEXT,                             -- URL del WebService SIN (cambia entre pruebas/producción)
    sin_token           TEXT,                             -- Token de autenticación para el WebService SIN
    sin_certificado_id  TEXT,                             -- FK al certificado digital ADSIB usado para firmar
    ultimo_heartbeat_sin TIMESTAMPTZ,                     -- Última comunicación exitosa con SIN
    sin_error_count     INTEGER DEFAULT 0,                -- Contador de errores consecutivos de comunicación

    -- === ASOCIACIÓN FÍSICA ===
    device_id       TEXT,                                 -- Hardware asignado (DEVICE-991)
    hostname        TEXT,
    ip              INET,
    mac             MACADDR,
    nodo_k8s        TEXT,
    geo             TEXT,                                 -- 'La Paz, Bolivia'
    vinculado_en    TIMESTAMPTZ,                          -- Fecha de asociación lógico↔físico

    -- === ESTADO ===
    estado          TEXT        NOT NULL DEFAULT 'ACTIVO',-- ACTIVO|INACTIVO|MANTENIMIENTO|BLOQUEADO_SIN
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (sucursal_id, pos_id),
    UNIQUE (empresa_id, sucursal_id, numero_punto_venta),
    CONSTRAINT chk_modalidad CHECK (modalidad_facturacion IN ('ELECTRONICA_EN_LINEA','COMPUTARIZADA_EN_LINEA','PORTAL_WEB'),
    CONSTRAINT chk_ambiente_sin CHECK (ambiente_sin IN ('PRUEBAS','PRODUCCION'),
    CONSTRAINT chk_estado_dosif CHECK (estado_dosificacion IN ('PENDIENTE','ACTIVA','VENCIDA','AGOTADA','REVOCADA'),
    CONSTRAINT chk_pos_estado CHECK (estado IN ('ACTIVO','INACTIVO','MANTENIMIENTO','BLOQUEADO_SIN'))
);

CREATE INDEX IF NOT EXISTS idx_pos_sucursal    ON bauth.bos_pos_logico(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_pos_empresa     ON bauth.bos_pos_logico(empresa_id);
CREATE INDEX IF NOT EXISTS idx_pos_tenant      ON bauth.bos_pos_logico(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pos_device      ON bauth.bos_pos_logico(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pos_sin_estado  ON bauth.bos_pos_logico(estado_dosificacion) WHERE estado_dosificacion IN ('ACTIVA','VENCIDA');
CREATE INDEX IF NOT EXISTS idx_pos_cufd        ON bauth.bos_pos_logico(cufd_vigencia) WHERE cufd IS NOT NULL;

COMMENT ON TABLE bauth.bos_pos_logico IS 'Punto de Venta registrado ante SIN Bolivia (SFV). Dosificación, CUFD, CUIS, CAFC, leyendas obligatorias. Cumple RND 10.0021.16 y RND 102100000011.';
COMMENT ON COLUMN bauth.bos_pos_logico.codigo_sucursal_sin IS 'Código de sucursal registrado en el Padrón Nacional de Contribuyentes del SIN.';
COMMENT ON COLUMN bauth.bos_pos_logico.modalidad_facturacion IS 'ELECTRONICA_EN_LINEA (certificado ADSIB), COMPUTARIZADA_EN_LINEA (credenciales SIN), PORTAL_WEB (manual). Asignado por SIN según perfil del contribuyente.';
COMMENT ON COLUMN bauth.bos_pos_logico.cufd IS 'Código Único de Facturación Diaria. Vigencia 24h. bAuth debe renovarlo automáticamente cada día via WebService SIN.';
COMMENT ON COLUMN bauth.bos_pos_logico.cuis IS 'Código Único de Iniciación de Sistemas. Vincula el NIT del contribuyente con su sistema de facturación. Se obtiene UNA vez por sistema.';
COMMENT ON COLUMN bauth.bos_pos_logico.cafc IS 'Código de Autorización de Facturación Computarizada. Solo aplica a modalidad COMPUTARIZADA_EN_LINEA.';
COMMENT ON COLUMN bauth.bos_pos_logico.leyenda_derechos_consumidor IS 'Leyenda asignada por SIN en cada dosificación. Ley N° 453 de Derechos del Consumidor.';
COMMENT ON COLUMN bauth.bos_pos_logico.sin_wsdl_url IS 'URL del WebService SIN para comunicación. Diferente entre ambiente PRUEBAS y PRODUCCION.';
COMMENT ON COLUMN bauth.bos_pos_logico.sin_certificado_id IS 'Referencia al certificado digital ADSIB en Vault usado para firmar facturas de este POS.';

-- ============================================================
-- 4. ROL TEMPLATE — Fuente de verdad de cada tipo de rol
-- ============================================================
-- Cada registro define lo que PUEDE HACER un tipo de rol.
-- Roles sistémicos (SU, SYS) tienen tenant_id='*' (global).
-- Roles de negocio tienen tenant_id y empresa_id específicos.
-- 368 roles definidos: 48 sistémicos + 174 internos + 146 externos.
-- Referencia: SBOS-ROLTEMPLATE-v6_0.md · Catálogo v2.0

CREATE TABLE IF NOT EXISTS bauth.bos_rol_template (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),              -- ej: 'ROL-CAJERO', 'ROL-SYS-ADMIN-BAUTH'
    tenant_id       UUID        DEFAULT NULL,     -- '*' = global, tenant_id = específico
    empresa_id      TEXT        DEFAULT NULL,     -- '*' = global
    parent_id UUID        CONSTRAINT fk_rt_parent REFERENCES bauth.bos_rol_template(id) ON DELETE SET NULL,
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
    mask_own_hex    TEXT        NOT NULL DEFAULT '0x0000000000000000',
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
    owner_tenant    TEXT        DEFAULT NULL,
    start_time      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expiry_time     TIMESTAMPTZ,
    template_id     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT        NOT NULL,
    template        JSONB       NOT NULL,
    template_version TEXT      NOT NULL DEFAULT '6.0',
    CONSTRAINT chk_brt_status CHECK (status IN ('DEFINIDO','DESARROLLADO','REVISADO','AUTORIZADO','PUBLICADO','DEPRECADO','RETIRADO'),
    CONSTRAINT chk_brt_sync   CHECK (sync_status IN ('PENDING','SYNCING','SYNCED','ERROR','DRIFT'),
    CONSTRAINT chk_brt_tier   CHECK (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3','BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE'),
    CONSTRAINT chk_brt_loa    CHECK (loa_required BETWEEN 1 AND 4),
    CONSTRAINT chk_brt_audit  CHECK (audit_level IN ('none','basic','full'))
);

CREATE INDEX IF NOT EXISTS idx_brt_tenant      ON bauth.bos_rol_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_brt_parent      ON bauth.bos_rol_template(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_brt_status      ON bauth.bos_rol_template(status);
CREATE INDEX IF NOT EXISTS idx_brt_tier        ON bauth.bos_rol_template(tier);
CREATE INDEX IF NOT EXISTS idx_brt_template_gin ON bauth.bos_rol_template USING GIN(template);

COMMENT ON TABLE bauth.bos_rol_template IS 'Fuente de verdad del sistema de roles del SBOS. Define qué PUEDE HACER un tipo de rol. 14 bloques JSONB en columna template. 7 estados de ciclo de vida: DEFINIDO→DESARROLLADO→REVISADO→AUTORIZADO→PUBLICADO→DEPRECADO→RETIRADO. Referencia: SBOS-ROLTEMPLATE-v6_0.md · ISO 24760-2:2025.';
COMMENT ON COLUMN bauth.bos_rol_template.id IS 'Identificador canónico inmutable. Formato: {SIGLA}-{ID} (ej: ROL-CAJERO, ROL-SYS-ADMIN-BAUTH). Este mismo ID se usa como Composite Role en Keycloak y Group en Tryton.';
COMMENT ON COLUMN bauth.bos_rol_template.tenant_id IS 'Tenant propietario. ''*'' = global (plantilla base visible para todos). UUID = tenant específico (rol oficial privado).';
COMMENT ON COLUMN bauth.bos_rol_template.empresa_id IS 'Empresa propietaria dentro del tenant. ''*'' = global. Permite roles específicos por empresa en tenants multi-empresa.';
COMMENT ON COLUMN bauth.bos_rol_template.parent_id IS 'RolTemplate padre para herencia H-RBAC. La herencia usa AND NOT: hijo = padre &^ bits_removidos. NUNCA circular (bAuth valida DAG antes de guardar). ANSI INCITS 359 §2.';
COMMENT ON COLUMN bauth.bos_rol_template.type_id IS 'Clasificación funcional: TYPE-OPERATIVO, TYPE-SUPERVISOR, TYPE-GERENCIA-MEDIA, TYPE-DIRECCION, TYPE-ADMIN-SISTEMA, TYPE-AUDITORIA.';
COMMENT ON COLUMN bauth.bos_rol_template.tier IS 'Nivel de seguridad y criticidad. SU=Superusuario(PAM), SYS=Admin Sistema, BIZ_N5=Dirección, BIZ_N4=Gerencia, BIZ_N3=Supervisión, BIZ_N2=Calificado, BIZ_N1=Operativo, EXT_N0=Externo, M2M=Machine-to-Machine, VISITANTE=Temporal. NIST 800-63B-4.';
COMMENT ON COLUMN bauth.bos_rol_template.hierarchy_level IS 'Nivel en la jerarquía organizacional: 1=C-Level/Dirección, 2=Gerencia regional, 3=Supervisor, 4=Operativo calificado, 5=Operativo estándar.';
COMMENT ON COLUMN bauth.bos_rol_template.path_ids IS 'Cadena completa de ancestros desde raíz hasta este rol. Calculado automáticamente desde bos_rol_closure. Solo lectura.';
COMMENT ON COLUMN bauth.bos_rol_template.status IS 'Estado del ciclo de vida: DEFINIDO(en diseño)→DESARROLLADO(átomos asignados)→REVISADO(validado)→AUTORIZADO(aprobado+sync)→PUBLICADO(asignable)→DEPRECADO(no nuevos usuarios)→RETIRADO(desactivado). ISO 24760-2:2025 §8.3.1.';
COMMENT ON COLUMN bauth.bos_rol_template.version IS 'Versión semántica del contrato de este rol: MAJOR.MINOR.PATCH. MAJOR=breaking change en permisos.';
COMMENT ON COLUMN bauth.bos_rol_template.sync_status IS 'Estado de sincronización con Keycloak y Tryton: PENDING(no sync)→SYNCING(en progreso)→SYNCED(consistente)→ERROR(fallo sync)→DRIFT(inconsistencia detectada).';
COMMENT ON COLUMN bauth.bos_rol_template.sync_error IS 'Mensaje de error del último sync fallido. NULL si sync_status != ERROR.';
COMMENT ON COLUMN bauth.bos_rol_template.last_sync_at IS 'Timestamp del último sync exitoso a Keycloak y Tryton.';
COMMENT ON COLUMN bauth.bos_rol_template.mask_own_hex IS 'Máscara de permisos propia del rol en hexadecimal (64 bits). BitMask Dual v3.0. Se recalcula al modificar átomos en bos_role_atom.';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_physical IS 'Máscara SAM-128 del dominio físico. Calculada por PrivilegeEngine. Controla acceso a puertas, zonas, hardware, biometría.';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_logical IS 'Máscara SAM-128 del dominio lógico. Calculada por PrivilegeEngine. Controla verbos (CRUD) sobre zonas de negocio.';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_financial IS 'Máscara SAM-128 del dominio financiero. Calculada por PrivilegeEngine. Controla límites, dual-approval, SoD financiero.';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_governance IS 'Máscara SAM-128 del dominio de gobernanza. Calculada por PrivilegeEngine. Controla auditoría, compliance, delegación.';
COMMENT ON COLUMN bauth.bos_rol_template.loa_required IS 'Level of Assurance requerido: 1(básico) a 4(máximo). SU≥3, SYS≥2, BIZ≥1. NIST 800-63B-4 AAL.';
COMMENT ON COLUMN bauth.bos_rol_template.mfa_required IS 'TRUE si el rol requiere autenticación multi-factor. Obligatorio para SU/SYS/BIZ_N3_N5. NIST 800-63B-4 §5.1.';
COMMENT ON COLUMN bauth.bos_rol_template.step_up_enabled IS 'TRUE si permite elevación temporal de LoA (ej: Cajero AAL2→AAL3 para arqueo). Max 15min. RFC 9470.';
COMMENT ON COLUMN bauth.bos_rol_template.sod_group IS 'Grupo de Separación de Deberes. Dos roles en mismo sod_group no pueden asignarse al mismo usuario. NIST AC-5.';
COMMENT ON COLUMN bauth.bos_rol_template.max_sessions IS 'Número máximo de sesiones concurrentes permitidas. Default 1. SU puede tener ilimitado.';
COMMENT ON COLUMN bauth.bos_rol_template.session_timeout IS 'Timeout de sesión en segundos. Default 28800 (8h). Max 43200 (12h). NIST 800-63B-4 §7.';
COMMENT ON COLUMN bauth.bos_rol_template.audit_level IS 'Nivel de auditoría: none(sin registro), basic(cambios de estado), full(toda operación). SU/SYS→full. ISO 27001 A.8.15.';
COMMENT ON COLUMN bauth.bos_rol_template.issuer IS 'Entidad que emitió el RolTemplate. Default: ''bAuth''. ISO 24760-2:2025 §5.4.';
COMMENT ON COLUMN bauth.bos_rol_template.owner_tenant IS 'Tenant dueño del rol oficial. NULL para plantillas base (is_template=true). Obligatorio para roles oficiales.';
COMMENT ON COLUMN bauth.bos_rol_template.start_time IS 'Fecha de inicio de vigencia del rol. Default: now().';
COMMENT ON COLUMN bauth.bos_rol_template.expiry_time IS 'Fecha de expiración. NULL = sin caducidad (INDEFINITE). Al expirar → sync_status=EXPIRED, KC desactiva el rol. ISO 24760-2:2025 §8.3.7.';
COMMENT ON COLUMN bauth.bos_rol_template.template_id IS 'ID de la plantilla base de la que fue clonado este rol. NULL si fue creado desde cero.';
COMMENT ON COLUMN bauth.bos_rol_template.created_by IS 'Admin que creó el RolTemplate. Trazabilidad ISO 27001 A.8.15.';
COMMENT ON COLUMN bauth.bos_rol_template.template IS 'Documento JSONB completo con los 14 bloques del RolTemplate (identidad, vigencia, bitmask, financiero, temporal, geográfico, red, delegación, SoD, auditoría, sync, encriptación, firma, metadatos). Schema v6.0.';
COMMENT ON COLUMN bauth.bos_rol_template.template_version IS 'Versión del schema JSONB del template. Actual: ''6.0''. Permite migración de schemas sin ALTER TABLE.';
COMMENT ON COLUMN bauth.bos_rol_template.loa_required IS '3NF: DEFAULT del tier (bos_tier_policy). Sobrescribible si override_loa=TRUE. NIST 800-63B-4 AAL.';
COMMENT ON COLUMN bauth.bos_rol_template.mfa_required IS '3NF: DEFAULT del tier (bos_tier_policy). Sobrescribible si override_mfa=TRUE.';
COMMENT ON COLUMN bauth.bos_rol_template.session_timeout IS '3NF: DEFAULT del tier (bos_tier_policy). Sobrescribible si override_session=TRUE. NIST 800-63B-4 §7.';
COMMENT ON COLUMN bauth.bos_rol_template.audit_level IS '3NF: DEFAULT del tier (bos_tier_policy). Sobrescribible si override_audit=TRUE. ISO 27001 A.8.15.';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_physical IS '3NF: Columna cache calculada por PrivilegeEngine desde mask_own_hex. Desnormalización aceptada por rendimiento (<0.5ns).';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_logical IS '3NF: Columna cache calculada por PrivilegeEngine desde mask_own_hex. Desnormalización aceptada por rendimiento (<0.5ns).';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_financial IS '3NF: Columna cache calculada por PrivilegeEngine desde mask_own_hex. Desnormalización aceptada por rendimiento (<0.5ns).';
COMMENT ON COLUMN bauth.bos_rol_template.sam128_governance IS '3NF: Columna cache calculada por PrivilegeEngine desde mask_own_hex. Desnormalización aceptada por rendimiento (<0.5ns).';
COMMENT ON COLUMN bauth.bos_rol_template.sync_error IS '3NF: Columna de diagnóstico. Depende de sync_status (NULL si != ERROR). Desnormalización aceptada por trazabilidad.';

-- ============================================================
-- 4b. TIER POLICY — Resuelve dependencia transitiva 3NF
-- ============================================================
-- NORMALIZACIÓN 3NF: tier → loa_required, tier → mfa_required,
-- tier → session_timeout, tier → audit_level son atributos
-- del TIER, no del rol. Esta tabla es la fuente de verdad.
-- bos_rol_template hereda los defaults y permite override.
-- Referencia: NIST 800-63B-4 AAL · ISO 24760-2:2025 §5.3
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_tier_policy (
    tier UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    CONSTRAINT chk_tp_audit CHECK (audit_default IN ('none','basic','full'),
    CONSTRAINT chk_tp_tier CHECK (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3','BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE'))
);
COMMENT ON TABLE bauth.bos_tier_policy IS '3NF: Políticas por tier — fuente de verdad para LoA, MFA, sesión y auditoría. Elimina dependencia transitiva tier→atributos en bos_rol_template. NIST 800-63B-4.';
COMMENT ON COLUMN bauth.bos_tier_policy.loa_default IS 'LoA por defecto para este tier: SU=3, SYS=2, BIZ_N5=2, BIZ_N4=2, BIZ_N3=2, BIZ_N2=1, BIZ_N1=1, EXT_N0=1, M2M=0, VISITANTE=1.';
COMMENT ON COLUMN bauth.bos_tier_policy.mfa_default IS 'MFA por defecto: TRUE para SU/SYS/BIZ_N3_N5. FALSE para EXT_N0/VISITANTE.';
COMMENT ON COLUMN bauth.bos_tier_policy.session_timeout_secs IS 'Timeout de sesión por defecto: SU=14400(4h), SYS=28800(8h), BIZ=28800(8h), EXT_N0=86400(24h).';

-- Seed de tiers (idempotente)
INSERT INTO bauth.bos_tier_policy (tier, tier_name, loa_default, mfa_default, mfa_methods, session_timeout_secs, max_sessions, audit_default, step_up_allowed, delegation_allowed, nist_aal_ref) VALUES
('SU',        'Superusuario PAM',        3, TRUE,  '{FIDO2,WebAuthn}',               14400,  0, 'full',   TRUE,  FALSE, 'AAL3'),
('SYS',       'Administrador de Sistema', 2, TRUE,  '{TOTP,FIDO2,WebAuthn}',          28800,  3, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N5',    'Dirección General',        2, TRUE,  '{TOTP,WebAuthn_2FA}',            28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N4',    'Gerencia',                 2, TRUE,  '{TOTP,WebAuthn_2FA}',            28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N3',    'Supervisión',              2, TRUE,  '{TOTP}',                         28800,  2, 'full',   TRUE,  TRUE,  'AAL2'),
('BIZ_N2',    'Operativo Calificado',     1, FALSE, '{TOTP}',                         28800,  1, 'basic',  TRUE,  FALSE, 'AAL1-AAL2'),
('BIZ_N1',    'Operativo Estándar',       1, FALSE, '{TOTP}',                         28800,  1, 'basic',  FALSE, FALSE, 'AAL1'),
('EXT_N0',    'Externo / Cliente',        1, FALSE, '{Passkey,Email_OTP}',            86400,  1, 'none',   FALSE, FALSE, 'AAL1'),
('M2M',       'Machine-to-Machine',       0, FALSE, '{mTLS}',                          86400, 10, 'basic',  FALSE, FALSE, 'n/a'),
('VISITANTE', 'Visitante Temporal',       1, FALSE, '{Email_OTP}',                    3600,   1, 'basic',  FALSE, FALSE, 'AAL1')
ON CONFLICT (tier) DO NOTHING;

-- ============================================================
-- 5. ROL TEMPLATE HISTORY — WORM inmutable (SHA-256 chain)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_rol_template_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID        NOT NULL REFERENCES bauth.bos_rol_template(id),
    tenant_id     TEXT        NOT NULL,
    version       TEXT        NOT NULL,
    template_snap JSONB       NOT NULL,
    changed_by    TEXT        NOT NULL,
    approved_by   TEXT,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_reason TEXT,
    changes       TEXT[]
    security_impact TEXT     NOT NULL DEFAULT 'LOW',
    prev_hash     TEXT,
    entry_hash    TEXT        NOT NULL
);

CREATE OR REPLACE FUNCTION bauth.compute_entry_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.entry_hash := encode(
        sha256((COALESCE(NEW.prev_hash,'') || NEW.rol_id || NEW.version || NEW.changed_at::text || NEW.template_snap::text)::bytea),
        'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_brth_entry_hash') THEN
        CREATE TRIGGER trg_brth_entry_hash
            BEFORE INSERT ON bauth.bos_rol_template_history
            FOR EACH ROW EXECUTE FUNCTION bauth.compute_entry_hash();
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_password_history_cleanup') THEN
        CREATE TRIGGER trg_password_history_cleanup
            AFTER INSERT ON bauth.bos_password_history
            FOR EACH ROW EXECUTE FUNCTION bauth.cleanup_password_history();
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_entry_hash') THEN
        CREATE TRIGGER trg_audit_entry_hash
            BEFORE INSERT ON bauth.bos_audit_events
            FOR EACH ROW EXECUTE FUNCTION bauth.compute_audit_entry_hash();
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_role_atom_position') THEN
        CREATE TRIGGER trg_role_atom_position
            BEFORE INSERT OR UPDATE OF app_code, group_code, atom_code
            ON bos_privilege.bos_role_atom
            FOR EACH ROW EXECUTE FUNCTION bos_privilege.sync_atom_position();
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_delegation_criticality') THEN
        ALTER TABLE bauth.bos_delegation_log
            ADD CONSTRAINT chk_delegation_criticality CHECK (criticality IN ('NORMAL','HIGH','CRITICAL'));
    END IF;
END $$;
DO $$
BEGIN
    -- Role de escritura: SOLO INSERT
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bauth_audit_writer') THEN
        CREATE ROLE bauth_audit_writer NOLOGIN NOINHERIT;
    END IF;

    -- Role de lectura: SOLO SELECT (para Loki, Wazuh, forense)
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bauth_audit_reader') THEN
        CREATE ROLE bauth_audit_reader NOLOGIN NOINHERIT;
    END IF;
END
$$;

-- Otorgar permisos mínimos
GRANT INSERT ON bauth.bos_audit_events TO bauth_audit_writer;
GRANT SELECT ON bauth.bos_audit_events TO bauth_audit_reader;
-- NOTA: NO se otorga UPDATE ni DELETE a ningún role de aplicación

-- Row-Level Security: bauth_audit_writer no puede leer lo que escribe
ALTER TABLE bauth.bos_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bauth.bos_audit_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_insert_only ON bauth.bos_audit_events;
CREATE POLICY audit_insert_only ON bauth.bos_audit_events
    FOR INSERT TO bauth_audit_writer WITH CHECK (true);
-- Sin política SELECT para bauth_audit_writer = no puede leer sus propios inserts

-- GRANT a la aplicación bAuth para usar el role writer
GRANT bauth_audit_writer TO bauth;

COMMENT ON TABLE bauth.bos_audit_events IS 'WORM inmutable. Particionado por mes. ctx_id obligatorio. RLS activo: solo INSERT para aplicación, SELECT solo para audit_reader. PCI DSS 4.0 Req.10.3.2.';

-- ============================================================
-- VERIFICACIÓN POST-DEPLOY
-- ============================================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'bauth' ORDER BY table_name;
-- -- Esperado: 36 tablas (32 funcionales + 4 catálogos ISO)
-- -- Catálogos poblados: bos_pais (15), bos_moneda (12), bos_idioma (11), bos_timezone (13)
-- -- Jerarquía correcta: bos_tenant → bos_empresa → bos_sucursal → bos_user_template

-- Permisos WORM (REVOKE UPDATE/DELETE)
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_rol_template_history TO bauth;
REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_audit_events TO bauth;
REVOKE UPDATE, DELETE ON bauth.bos_sync_log FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_sync_log FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_sync_log TO bauth;
GRANT USAGE ON SCHEMA bauth TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bauth TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bauth TO bauth;
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM bauth;
REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM bauth;
GRANT USAGE ON SCHEMA bos_privilege TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bos_privilege TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bos_privilege TO bauth;
REVOKE UPDATE, DELETE ON bos_privilege.bos_atom_audit FROM bauth;
GRANT USAGE ON SCHEMA bos_blockchain TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bos_blockchain TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bos_blockchain TO bauth;
GRANT EXECUTE ON FUNCTION gen_random_uuid() TO bauth;
GRANT EXECUTE ON FUNCTION sha256(bytea) TO bauth;
GRANT INSERT ON bauth.bos_audit_events TO bauth_audit_writer;
GRANT SELECT ON bauth.bos_audit_events TO bauth_audit_reader;
GRANT bauth_audit_writer TO bauth;

-- Row Level Security
ALTER TABLE bauth.bos_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bauth.bos_audit_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_insert_only ON bauth.bos_audit_events;
CREATE POLICY audit_insert_only ON bauth.bos_audit_events
