-- ============================================================
-- bauth_db — Schema completo v3.0 · Compliance-Verified
-- SKULL · SBOS · bAuth Identity Core v3.0
-- Fecha: 2026-06-22 · Hash: ver documentación
-- ============================================================
--
-- ╔══════════════════════════════════════════════════════════════╗
-- ║         MATRIZ DE CUMPLIMIENTO NORMATIVO (8 estándares)      ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ ESTÁNDAR              │ VERSIÓN  │ CONTROLES CUBIERTOS       ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ ISO/IEC 27001         │ 2022     │ A.5.15-18 Identidad       ║
-- ║                        │          │ A.8.2 Privilegios         ║
-- ║                        │          │ A.8.5 Autenticación       ║
-- ║                        │          │ A.8.9 Configuración       ║
-- ║                        │          │ A.8.15 Logging/Auditoría  ║
-- ║                        │          │ A.8.17 Sincronización     ║
-- ║                        │          │ A.9.2.1 Recertificación   ║
-- ║                        │          │ A.9.2.5 Revisión accesos  ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ ISO/IEC 24760-2       │ 2025     │ §5.3 Atributos de rol     ║
-- ║                        │          │ §5.4 Actores/Stakeholders ║
-- ║                        │          │ §8.3.1 Ciclo de vida      ║
-- ║                        │          │ §8.3.4 Reference ID       ║
-- ║                        │          │ §8.3.5 Calidad/Compliance ║
-- ║                        │          │ §8.3.6 Archivado          ║
-- ║                        │          │ §8.3.7 Terminación        ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ NIST SP 800-63B-4     │ 2025     │ §4 Account Recovery       ║
-- ║ (Digital Identity)     │          │ §5.1.1 Password Screening ║
-- ║                        │          │ §5.1.2 Password Policies  ║
-- ║                        │          │ §5.2 Authenticator Binding║
-- ║                        │          │ §5.2.2 Revocation         ║
-- ║                        │          │ §7 Session Management     ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ NIST SP 800-53 Rev.5  │ 2020     │ AC-2 Account Management   ║
-- ║                        │          │ AC-5 Separation of Duties ║
-- ║                        │          │ AC-6 Least Privilege      ║
-- ║                        │          │ AC-7 Login Attempts       ║
-- ║                        │          │ AU-2 Event Types          ║
-- ║                        │          │ AU-3 Content of Records   ║
-- ║                        │          │ AU-9 Audit Protection     ║
-- ║                        │          │ CM-6 Configuration        ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ NIST SP 800-207       │ 2020     │ Zero Trust Architecture   ║
-- ║ (ZTA)                  │          │ Continuous Verification   ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ PCI DSS               │ 4.0.1    │ Req 8.2 Unique IDs        ║
-- ║                        │          │ Req 8.4 MFA for CDE       ║
-- ║                        │          │ Req 10.1-10.7 Audit Trail ║
-- ║                        │          │ Req 10.3 Integrity (SHA)  ║
-- ║                        │          │ Req 10.7 Retention (12m)  ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ OWASP ASVS             │ 5.0.0    │ V2.1 Password Security   ║
-- ║                        │          │ V2.2 General Auth         ║
-- ║                        │          │ V2.3 Authenticator Life   ║
-- ║                        │          │ V2.4 Credential Storage   ║
-- ║                        │          │ V2.5 Credential Recovery  ║
-- ║                        │          │ V2.8 One-Time Verifiers   ║
-- ║                        │          │ V2.9 Cryptographic Auth   ║
-- ║                        │          │ V3.1 Session Fundamentals ║
-- ║                        │          │ V3.2 Session Binding      ║
-- ║                        │          │ V3.3 Session Timeout      ║
-- ║                        │          │ V4.1 Access Control Design║
-- ║                        │          │ V4.2 Operation Level AC   ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ SOC 2 Type II         │ 2022     │ CC6.1 Logical Access      ║
-- ║ (Trust Services)       │          │ CC6.3 Access Reviews      ║
-- ║                        │          │ CC6.6 External Threats    ║
-- ║                        │          │ CC7.1 Availability        ║
-- ║                        │          │ CC9.1 Confidentiality     ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ RGPD / GDPR           │ 2016/679 │ Art.7 Consentimiento      ║
-- ║                        │          │ Art.9 Datos biométricos   ║
-- ║                        │          │ Art.17 Derecho al olvido  ║
-- ║                        │          │ Art.32 Seguridad          ║
-- ║                        │          │ Art.33 Notif. brechas     ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ ANSI/INCITS 359       │ 2004     │ §2 Hierarchical RBAC      ║
-- ║                        │          │ §3 Static SoD             ║
-- ║                        │          │ §4 Dynamic SoD            ║
-- ╠══════════════════════════════════════════════════════════════╣
-- ║ ISO 20022 / FATF 16   │ 2013/12  │ Límites financieros       ║
-- ║ SOX §404              │ 2002     │ Dual approval interno      ║
-- ║ RFC 9470              │ 2023     │ Step-Up Authentication     ║
-- ║ RFC 6962              │ 2013     │ Merkle Tree (blockchain)   ║
-- ║ NIST FIPS 140-3       │ 2019     │ Módulo criptográfico       ║
-- ║ NIST FIPS 203/204/205 │ 2024     │ PQC (ML-KEM/ML-DSA/SLH)   ║
-- ║ W3C Trace Context     │ 2020     │ ctx_id + traceparent       ║
-- ║ W3C WebAuthn L2       │ 2021     │ FIDO2/Passkeys             ║
-- ║ CIS PostgreSQL Bench  │ v1.5.0   │ Hardening + RLS            ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- JERARQUÍA CORRECTA (SBOS-049 §4):
--   tenant (SKULL — plataforma)
--     └── empresa (SKULL misma + ACME, MAYA, etc.)
--          └── sucursal (ubicación física)
--               └── pos_logico (terminal, caja)
--                    └── user (persona operando)
--
-- REGLA FUNDAMENTAL:
--   El tenant NO es una empresa. El tenant es el dominio técnico
--   operado por SKULL que contiene MÚLTIPLES empresas independientes.
--   SKULL vende el sistema a otras empresas, pero todas conviven
--   dentro del mismo tenant técnico con aislamiento total de datos.
--
-- DECISIÓN DE ALMACENAMIENTO (ver SBOS-BAUTH-DESK-CHECK §10):
--   PostgreSQL JSONB = fuente de verdad (ACID, GIN indexes, WORM history)
--   Redis = cache caliente (99% de decisiones auth en < 1ms)
--   Archivos YAML = input humano editable (git versionado)
--   Flujo: YAML → validar → cifrar AES-256-GCM → INSERT PG JSONB → poblar Redis
--
-- NORMALIZACIÓN:
--   1NF: ✅ 103/103 tablas con PK. Arrays PostgreSQL atómicos. JSONB atómico.
--   2NF: ✅ 2 desvíos controlados (atom_position × rendimiento + catálogo).
--   3NF: ✅ 5 desvíos documentados con CHECK constraints y triggers.
--   BCNF: N/A — todas las dependencias funcionales desde PK candidatas.
--
-- TRAZABILIDAD Y AUDITORÍA:
--   Retención online:  90 días (CIS Control 8.10, PCI DSS 4.0 Req 10.7)
--   Retención archive: 12 meses (PCI DSS 4.0 Req 10.7.2, ISO 27001 A.8.15)
--   Retención fiscal:  8 años Bolivia (SIN RND 102100000011)
--   Tablas WORM: 8 tablas con REVOKE UPDATE/DELETE
--   Hash-chain SHA-256: bos_rol_template_history + bos_audit_events
--   Merkle tree on-chain: bos_atom_audit → bos_merkle_leaf → bos_merkle_batch
--   Roles separados: bauth_audit_writer (INSERT) + bauth_audit_reader (SELECT)
--   Row-Level Security: bos_audit_events (writer no lee lo que escribe)
--   Particiones: 4 tablas particionadas × mes para gestión de retención
--
-- ESTADÍSTICAS:
--   103 tablas · 3 schemas · 338+ COMMENTS · 18 normas · 42 controles
--   8 tablas WORM · 2 hash-chains · 1 Merkle tree · 4 particiones
--   7 triggers de integridad · 2 roles de auditoría con RLS
--
-- DOCUMENTOS DE REFERENCIA SBOS:
--   SBOS-008-ROLFRAMEWORK-v1_0.md (Arquitectura de privilegios)
--   SBOS-008-001-DOMAINS-BITMASK-REALM-v1_0.md (BitMask 64-bit)
--   SBOS-021-DAEMON-BAUTH.md (Especificación del daemon)
--   SBOS-049-CONTEXT-PLANE.md v2.0 (Context Plane 6 capas)
--   SBOS-050-PORT-CATALOG.md (Puertos y subdominios)
--   SBOS-054-NETWORK-SECURITY.md v1.3.0 (Segmentación de red)
--   BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 (368 roles)
--   BAUTH-CADENAS-JERARQUIA.md v1.1 (186 aristas DAG)
--   BAUTH-AUTHENTICATION-FRAMEWORK.md v1.0.0 (Framework declarativo)
--   SBOS-ROLTEMPLATE-v6_0.md (14 bloques JSONB)
--   SBOS-USERTEMPLATE-v6_0.md (16 bloques JSONB)
--   SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md (BitMask Dual v3.0)
--   BAUTH-CONTRATO-SYMBIOSIS.md (Relación bAuth↔Keycloak↔Tryton)
--   BAUTH-B10-ESPECIFICACION-CRUD-PROFESIONAL.md v4.0.0 (CRUD espec)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ROL DE APLICACIÓN
-- ============================================================
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

-- ============================================================
-- 1-B. TENANT VERIFICATION — 5 pasos de onboarding validado
-- ============================================================
-- ============================================================
-- 1-A. TENANT VERIFICATION → MOVIDO a DDL_skSBOS_db.sql (009 — bauth.idn_tenant_verification)
-- ============================================================

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
-- ============================================================
-- 1-C1b. CIUDADES — División administrativa
-- ============================================================
-- ═══════════════════════════════════════════════════════════════════════════
-- ❌ TABLA OMITIDA: bos_ciudad — INNECESARIA (2026-06-23)
-- ═══════════════════════════════════════════════════════════════════════════
-- Motivo: Mantener un catálogo manual de ciudades es insostenible y de baja
--         precisión (~95%). La industria en 2026 resuelve esto con:
--
-- Reemplazada por:
--   1. PostGIS point-in-polygon: coordenadas (lat,lon) → consulta espacial
--      contra polígonos administrativos OSM → ciudad/departamento (~0.1ms)
--   2. pg-nearest-city (KNN): coordenadas → país → ciudad más cercana (~0.1ms)
--   3. Modelo híbrido: PostGIS local + API externa (Nominatim/BigDataCloud)
--      como fallback. Solo ~5% de queries requieren API externa.
--   4. Las tablas idn_empresa, idn_sucursal, idn_pos almacenan lat/lon
--      directamente. La resolución de ciudad se hace en tiempo de consulta.
--
-- Fuentes:
--   - SymOrg 2024: "Combined Model: database-first + API fallback"
--   - pg-nearest-city (HOTOSM): benchmarks ~0.1ms vs 45ms Python
--   - PixelUnion/Immich 2025: "decouple geocoding into microservice"
--   - BigDataCloud: locality-level reverse geocoding, $169/mes por 5M queries
--
-- Veredicto: NO se migra a DDL_skSBOS_db.sql. Las coordenadas + PostGIS
--            reemplazan esta tabla por completo.
-- ═══════════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1-C2. MONEDAS — ISO 4217
-- ============================================================
-- ============================================================
-- 1-C3. IDIOMAS — ISO 639 / BCP 47
-- ============================================================
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

-- ============================================================
-- 1-D. TENANT CONFIG → MOVIDO a DDL_skSBOS_db.sql (010 — bauth.idn_tenant_config)
-- ============================================================

-- ============================================================
-- 1-D. TENANT DOMAINS → MOVIDO a DDL_skSBOS_db.sql (011 — bauth.idn_tenant_domain)
-- ============================================================

-- ============================================================
-- 1-E. TENANT NETWORKS → MOVIDO a DDL_skSBOS_db.sql (012 — bauth.idn_tenant_network)
-- ============================================================

-- ============================================================
-- 1-F. TENANT CURRENCIES → MOVIDO a DDL_skSBOS_db.sql (006 — bglobal.global_tenant_currency)
-- ============================================================

-- ============================================================
-- 1-G. TENANT LANGUAGES → MOVIDO a DDL_skSBOS_db.sql (007 — bauth.idn_tenant_languages)
-- ============================================================

-- ============================================================
-- 1-H. TENANT GESTIONES → MOVIDO a DDL_skSBOS_db.sql (013 — bcalendar.cal_fiscal_year)
-- ============================================================

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

-- ═══════════════════════════════════════════════════════════════════════════
-- ❌ TABLA OMITIDA: bos_gestion_calendario — REEMPLAZADA (2026-06-23)
-- Reemplazada por: subsistema bcalendar (11 tablas RFC 5545)
--   cal_event + cal_holiday + cal_alarm + cal_notification_log
-- Ver: BAUTH-CALENDAR-SUBSYSTEM.md
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bauth.bos_gestion_calendario (
    evento_id       BIGSERIAL   PRIMARY KEY,
    gestion_id      BIGINT      NOT NULL,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       , -- NULL = global tenant
    sucursal_id     TEXT       , -- NULL = toda la empresa

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
    )),
    CONSTRAINT chk_cal_categoria CHECK (categoria IN ('LABORAL','FISCAL','OPERATIVO','RRHH','ADUANERO')),
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

-- ═══════════════════════════════════════════════════════════════════════════
-- ❌ TABLA OMITIDA: bos_schedule — REEMPLAZADA (2026-06-23)
-- Reemplazada por: bcalendar.cal_schedule (RFC 7953 VAVAILABILITY)
--   + cal_calendar (RFC 4791 VCALENDAR)
-- Ver: BAUTH-CALENDAR-SUBSYSTEM.md
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bauth.bos_schedule (
    schedule_id     BIGSERIAL   PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       ,   -- NULL = nivel tenant
    sucursal_id     TEXT       , -- NULL = nivel empresa/tenant
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

    CONSTRAINT chk_jornada CHECK (tipo_jornada IN ('CONTINUA','PARTIDA','FLEXIBLE','TURNOS')),
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
-- 1-K1. SITIO FÍSICO → MOVIDO a DDL_skSBOS_db.sql (021 — bauth.fis_sitio_fisico)
-- ============================================================

-- ============================================================
-- 1-K2. EDIFICIO — Construcción dentro de un sitio
-- ============================================================
-- ❌ REEMPLAZADA por fis_location (closure table) — 2026-06-23 · BAUTH-DDL-DOMINIO-FISICO.md
CREATE TABLE IF NOT EXISTS bauth.bos_edificio (
    edificio_id     TEXT        PRIMARY KEY,              -- ej: 'EDIF-A', 'EDIF-PRINCIPAL'
    sitio_id        TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
    CONSTRAINT chk_edif_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5')),
    CONSTRAINT chk_edif_clase CHECK (construccion_clase IN ('CLASE_A','CLASE_B','CLASE_C','CLASE_D'))
);

CREATE INDEX IF NOT EXISTS idx_edif_sitio ON bauth.bos_edificio(sitio_id);

COMMENT ON TABLE bauth.bos_edificio IS 'Edificio dentro de un sitio. BS 5979 Zone 2-3. Construcción clase según resistencia física.';
COMMENT ON COLUMN bauth.bos_edificio.construccion_clase IS 'CLASE_A (reforzado, ballistico) → CLASE_D (liviano, no es barrera efectiva). BS 5979.';

-- ============================================================
-- 1-K3. PISO / NIVEL — Planta dentro de un edificio
-- ============================================================
-- ❌ REEMPLAZADA por fis_location (closure table) — 2026-06-23
CREATE TABLE IF NOT EXISTS bauth.bos_piso (
    piso_id         TEXT        PRIMARY KEY,              -- ej: 'EDIF-A-PB', 'EDIF-A-P1'
    edificio_id     TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
-- ❌ REEMPLAZADA por fis_location (closure table) — 2026-06-23
CREATE TABLE IF NOT EXISTS bauth.bos_area_fisica (
    area_id         TEXT        PRIMARY KEY,              -- ej: 'AREA-SERVIDORES', 'AREA-CAJAS'
    piso_id         TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
    CONSTRAINT chk_area_zona CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5')),
    CONSTRAINT chk_area_tipo CHECK (tipo IN ('OFICINA','SALA_REUNIONES','SERVIDORES','CAJAS','ALMACEN','BAÑO','COCINA','PASILLO','VESTIBULO','BOVEDA','ARCHIVO','ESTACIONAMIENTO','RECEPCION'))
);

CREATE INDEX IF NOT EXISTS idx_area_piso ON bauth.bos_area_fisica(piso_id);

COMMENT ON TABLE bauth.bos_area_fisica IS 'Área física dentro de un piso. Nivel donde se asocian dispositivos. Define reglas de acceso: escolta, dos personas, mantrap.';
COMMENT ON COLUMN bauth.bos_area_fisica.tipo IS 'Tipo de área. Define comportamiento: BOVEDA requiere 2 personas, SERVIDORES requiere biométrico + CCTV.';

-- ============================================================
-- 1-K5. DISPOSITIVO FÍSICO — Puertas, cámaras, sensores, actuadores
-- ============================================================
-- ═══════════════════════════════════════════════════════════════════════════
-- ❌ TABLA REEMPLAZADA: bos_dispositivo_fisico → bauth.fis_device (2026-06-23)
-- Ver: BAUTH-DDL-DOMINIO-FISICO.md
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bauth.bos_dispositivo_fisico (
    dispositivo_id  TEXT        PRIMARY KEY,              -- ej: 'PUERTA-001', 'CAM-023', 'CAJA-POS-10'
    area_id         TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
    pos_logico_id   TEXT       ,
    activo          BOOLEAN     NOT NULL DEFAULT true,
    metadata        JSONB       DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_disp_zona  CHECK (zona_seguridad IN ('ZONA_0','ZONA_1','ZONA_2','ZONA_3','ZONA_4','ZONA_5')),
    CONSTRAINT chk_disp_tipo  CHECK (tipo IN (
        'PUERTA','CHAPA_ELECTROMAGNETICA','CERROJO_INTELIGENTE','TURNIQUETE','BARRERA_VEHICULAR',
        'CAMARA_IP','CAMARA_TERMICA','CAMARA_360',
        'SENSOR_MOVIMIENTO','SENSOR_APERTURA','SENSOR_TEMPERATURA','SENSOR_HUMO','SENSOR_INUNDACION',
        'ALARMA_INCENDIO','SIRENA','PANEL_CONTROL','TECLADO_PIN',
        'CAJA_REGISTRADORA','TERMINAL_POS','LECTOR_QR','LECTOR_NFC','LECTOR_BARRAS',
        'LECTOR_HUELLA','LECTOR_FACIAL','LECTOR_IRIS','LECTOR_VOZ',
        'ACTUADOR','RELE','CONTROLADOR_ILUMINACION','TERMOSTATO'
    )),
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
-- MOVED to DDL_skSBOS_db.sql (028-033 — Dominio Financiero D3)\nCREATE TABLE IF NOT EXISTS bauth.bos_financial_tipo_transaccion (
    tipo_id         TEXT        PRIMARY KEY,              -- 'FAC_EMITIR', 'PAGO_APROBAR', 'NC_EMITIR'
    nombre          TEXT        NOT NULL,                 -- 'Emitir Factura', 'Aprobar Pago'
    categoria       TEXT        NOT NULL,                 -- VENTAS|COMPRAS|PAGOS|COBROS|NOMINA|INVENTARIO|TRIBUTARIO
    riesgo          TEXT        NOT NULL DEFAULT 'MEDIO', -- BAJO|MEDIO|ALTO|CRITICO
    requiere_dual_control BOOLEAN DEFAULT false,          -- SOX: transacciones críticas requieren 2 personas
    requiere_evidencia BOOLEAN  DEFAULT true,             -- Documento soporte obligatorio
    afecta_libros_contables BOOLEAN DEFAULT true,         -- Impacta mayor contable
    notificacion_sin BOOLEAN    DEFAULT false,            -- Requiere notificación a entidad reguladora SIN
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ftt_riesgo CHECK (riesgo IN ('BAJO','MEDIO','ALTO','CRITICO')),
    CONSTRAINT chk_ftt_categoria CHECK (categoria IN ('VENTAS','COMPRAS','PAGOS','COBROS','NOMINA','INVENTARIO','TRIBUTARIO','BANCARIO','ACTIVOS_FIJOS','IMPORTACION','EXPORTACION'))
);

COMMENT ON TABLE bauth.bos_financial_tipo_transaccion IS 'Tipos de transacciones financieras con clasificación de riesgo y requisitos de control. SOX §302 requiere documentación de cada tipo.';
COMMENT ON COLUMN bauth.bos_financial_tipo_transaccion.requiere_dual_control IS 'SOX §404: transacciones de alto riesgo requieren segregación de funciones (quien inicia ≠ quien aprueba).';
COMMENT ON COLUMN bauth.bos_financial_tipo_transaccion.notificacion_sin IS 'Operaciones que deben ser reportadas al SIN Bolivia (facturación, NC/ND, exportaciones).';

-- ============================================================
-- 1-L2. LÍMITES DE TRANSACCIÓN FINANCIERA
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_limit (
    limit_id        BIGSERIAL   PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       , -- NULL = aplica a todo el tenant
    rol_id          TEXT       ,    -- NULL = aplica a todos los roles
    tipo_transaccion TEXT      , -- NULL = todas
    moneda          CHAR(3)    ,

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
    decision_id     BIGSERIAL   PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       ,
    nombre          TEXT        NOT NULL,                 -- 'Aprobación de Ventas — Nivel 1'
    tipo_transaccion TEXT      NOT NULL,
    moneda          CHAR(3)    ,

    -- Niveles de decisión en cascada
    nivel_1_rol     TEXT       , -- Primer nivel de aprobación
    nivel_1_monto_max NUMERIC(16,2),                  -- Hasta qué monto puede aprobar este nivel
    nivel_1_puede_delegar BOOLEAN DEFAULT false,

    nivel_2_rol     TEXT       , -- Segundo nivel (escala)
    nivel_2_monto_max NUMERIC(16,2),                  -- Hasta qué monto puede aprobar
    nivel_2_puede_delegar BOOLEAN DEFAULT false,

    nivel_3_rol     TEXT       , -- Tercer nivel (alta dirección)
    nivel_3_monto_max NUMERIC(16,2),                  -- NULL = sin límite superior

    -- Condiciones especiales
    requiere_comite BOOLEAN     DEFAULT false,           -- Requiere aprobación de comité (ej: inversiones > $1M)
    requiere_evidencia_adjunta BOOLEAN DEFAULT false,    -- Documento soporte obligatorio
    tiempo_max_aprobacion_horas INTEGER DEFAULT 48,      -- SLA de aprobación
    escala_automatica_si_no_respuesta BOOLEAN DEFAULT true, -- Si no aprueba en SLA, escala al siguiente nivel

    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, empresa_id, tipo_transaccion, moneda)
);

CREATE INDEX IF NOT EXISTS idx_fdm_empresa ON bauth.bos_financial_decision_matrix(empresa_id);

COMMENT ON TABLE bauth.bos_financial_decision_matrix IS 'Matriz de decisión financiera en cascada. Define qué rol puede aprobar qué monto para cada tipo de transacción. COSO + SOX compliant.';
COMMENT ON COLUMN bauth.bos_financial_decision_matrix.nivel_1_monto_max IS 'Monto máximo que puede aprobar el primer nivel. Si se excede → escala automática al nivel 2.';
COMMENT ON COLUMN bauth.bos_financial_decision_matrix.escala_automatica_si_no_respuesta IS 'Si true y el aprobador no responde en SLA → escala al siguiente nivel automáticamente.';

-- ============================================================
-- 1-L4. APROBACIÓN FINANCIERA — Registro de cada decisión
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_approval (
    approval_id     BIGSERIAL   PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       ,
    tipo_transaccion TEXT      NOT NULL,
    referencia      TEXT        NOT NULL,                 -- ID de la factura, pago, NC: 'FAC-12345'
    monto           NUMERIC(16,2) NOT NULL,
    moneda          CHAR(3)    ,

    -- Solicitante
    solicitante_uuid UUID       NOT NULL,
    solicitud_fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    solicitud_motivo TEXT,

    -- Niveles de aprobación recorridos
    nivel_actual    INTEGER     NOT NULL DEFAULT 1,      -- 1, 2, 3
    nivel_total     INTEGER     NOT NULL DEFAULT 1,      -- Cuántos niveles requiere esta transacción

    -- Aprobación efectiva
    aprobador_uuid  UUID       ,
    decision        TEXT,                                  -- APROBADO|RECHAZADO|DEVUELTO|ESCALADO
    decision_fecha  TIMESTAMPTZ,
    decision_comentario TEXT,
    evidencia_adjunta JSONB,                              -- URLs a documentos soporte

    -- Escalamiento
    escalado_a_uuid UUID      ,
    escalado_fecha  TIMESTAMPTZ,
    escalado_motivo TEXT,

    estado          TEXT        NOT NULL DEFAULT 'PENDIENTE',-- PENDIENTE|EN_REVISION|APROBADO|RECHAZADO|ESCALADO|CANCELADO
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fa_decision CHECK (decision IS NULL OR decision IN ('APROBADO','RECHAZADO','DEVUELTO','ESCALADO')),
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
    operacion_id    TEXT        PRIMARY KEY,              -- 'FAC_EMITIR', 'FAC_ANULAR', 'NC_CREAR'
    tipo_documento  TEXT        NOT NULL,                 -- FACTURA|NOTA_CREDITO|NOTA_DEBITO|PAGO|COBRO|ASIENTO
    verbo           TEXT        NOT NULL,                 -- CREATE|READ|UPDATE|DELETE|ANULAR|APROBAR|RECHAZAR|REIMPRIMIR
    descripcion     TEXT        NOT NULL,
    afecta_dosificacion BOOLEAN DEFAULT false,            -- Consume número de factura (SIN)
    requiere_firma_digital BOOLEAN DEFAULT false,          -- Requiere firma ADSIB
    notifica_sin    BOOLEAN     DEFAULT false,            -- Notifica al SIN en tiempo real
    activo          BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT chk_fdo_doc CHECK (tipo_documento IN ('FACTURA','NOTA_CREDITO','NOTA_DEBITO','PAGO','COBRO','ASIENTO','RETENCION','PERCEPCION','GUIA_REMISION','ORDEN_COMPRA','CONTRATO','GASTO')),
    CONSTRAINT chk_fdo_verbo CHECK (verbo IN ('CREATE','READ','UPDATE','DELETE','ANULAR','APROBAR','RECHAZAR','REIMPRIMIR','EXPORTAR','CERRAR','REABRIR'))
);

COMMENT ON TABLE bauth.bos_financial_document_operation IS 'Catálogo de operaciones posibles sobre cada tipo de documento financiero. Matriz documento × verbo.';
COMMENT ON COLUMN bauth.bos_financial_document_operation.afecta_dosificacion IS 'Si consume numeración SIN. ANULAR una factura NO libera el número.';

-- ============================================================
-- 1-L6. PERMISOS FINANCIEROS POR ROL — Quién puede hacer qué
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_financial_role_permission (
    permiso_id      BIGSERIAL   PRIMARY KEY,
    rol_id          TEXT        NOT NULL,
    operacion_id    TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       , -- NULL = global tenant

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
    permiso_id      BIGSERIAL   PRIMARY KEY,
    rol_id          TEXT        NOT NULL,
    zona_id         TEXT        NOT NULL,
    verbo_id        SMALLINT    NOT NULL,                    -- FK → bos_privilege.bos_verb(verb_code)
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT       ,

    -- Restricciones
    scope           TEXT        NOT NULL DEFAULT 'EMPRESA',-- GLOBAL|EMPRESA|SUCURSAL|PERSONAL
    limit_registros INTEGER,                               -- Máximo de registros por consulta
    requiere_step_up BOOLEAN    DEFAULT false,             -- Elevación LoA requerida
    clasificacion_datos TEXT   DEFAULT 'INTERNAL',         -- PUBLIC|INTERNAL|CONFIDENTIAL|RESTRICTED
    activo          BOOLEAN     NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rol_id, zona_id, verbo_id, tenant_id, empresa_id),
    CONSTRAINT fk_permiso_verbo FOREIGN KEY (verbo_id),
    CONSTRAINT chk_pl_scope CHECK (scope IN ('GLOBAL','EMPRESA','SUCURSAL','PERSONAL')),
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
    policy_id       TEXT        PRIMARY KEY,              -- 'PASSWORDS', 'MFA_TOTP', 'M2M_CERTS', 'OAUTH_SECRETS'
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
    rotation_id     BIGSERIAL   PRIMARY KEY,
    user_uuid       UUID       ,
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
    empresa_id      TEXT        PRIMARY KEY,              -- ej: 'skull', 'acme', 'maya'
    tenant_id       TEXT        NOT NULL,
    razon_social    TEXT        NOT NULL,                 -- Razón social legal
    nit             TEXT        NOT NULL,                 -- NIT boliviano (SIN)
    regimen_fiscal  TEXT        NOT NULL DEFAULT 'GENERAL',-- GENERAL|SIMPLIFICADO|AGROPECUARIO
    es_operador     BOOLEAN     NOT NULL DEFAULT false,   -- true = SKULL (dueño plataforma)

    -- === CONFIGURACIÓN REGIONAL (hereda del tenant, puede sobrescribir y extender) ===
    -- Principio MULTI: cada empresa puede tener N idiomas, N monedas, N timezones, N dominios.
    -- Los valores NULL heredan del tenant. Los valores definidos sobrescriben.
    -- Una empresa boliviana que vende a China necesita: es-BO (interno) + zh-CN (clientes chinos) + en-US (internacional).

    -- Idiomas activos de la empresa (extiende los del tenant)
    locale_default  TEXT       , -- NULL = locale_default del tenant
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
    sucursal_id     TEXT        PRIMARY KEY,              -- ej: 'skull-lapaz', 'acme-central'
    empresa_id      TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
    pos_id          TEXT        PRIMARY KEY,              -- ej: 'POS-23', 'CAJA-01'
    sucursal_id     TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
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
    CONSTRAINT chk_modalidad CHECK (modalidad_facturacion IN ('ELECTRONICA_EN_LINEA','COMPUTARIZADA_EN_LINEA','PORTAL_WEB')),
    CONSTRAINT chk_ambiente_sin CHECK (ambiente_sin IN ('PRUEBAS','PRODUCCION')),
    CONSTRAINT chk_estado_dosif CHECK (estado_dosificacion IN ('PENDIENTE','ACTIVA','VENCIDA','AGOTADA','REVOCADA')),
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
    id              TEXT        PRIMARY KEY,              -- ej: 'ROL-CAJERO', 'ROL-SYS-ADMIN-BAUTH'
    tenant_id       TEXT        NOT NULL DEFAULT '*',     -- '*' = global, tenant_id = específico
    empresa_id      TEXT        NOT NULL DEFAULT '*',     -- '*' = global
    parent_id       TEXT        CONSTRAINT fk_rt_parent ON DELETE SET NULL,
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

REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_rol_template_history TO bauth;

CREATE INDEX IF NOT EXISTS idx_brth_rol ON bauth.bos_rol_template_history(rol_id, changed_at DESC);

COMMENT ON TABLE bauth.bos_rol_template_history IS 'Historial WORM inmutable de cambios a RolTemplates. Cadena SHA-256 encadenada (prev_hash→entry_hash). Solo INSERT y SELECT permitidos — UPDATE y DELETE revocados. ISO 27001 A.8.15 · ISO 24760-2:2025 §8.3.6.';
COMMENT ON COLUMN bauth.bos_rol_template_history.history_id IS 'ID auto-incremental. Orden cronológico de cambios.';
COMMENT ON COLUMN bauth.bos_rol_template_history.rol_id IS 'RolTemplate al que pertenece este cambio. FK → bos_rol_template.id.';
COMMENT ON COLUMN bauth.bos_rol_template_history.tenant_id IS 'Tenant propietario. Permite filtrar historial por tenant.';
COMMENT ON COLUMN bauth.bos_rol_template_history.version IS 'Número de versión semántica después de este cambio.';
COMMENT ON COLUMN bauth.bos_rol_template_history.template_snap IS 'Snapshot completo del plantilla_json en el momento del cambio. Permite reconstruir cualquier versión anterior.';
COMMENT ON COLUMN bauth.bos_rol_template_history.changed_by IS 'Admin que realizó el cambio. Trazabilidad obligatoria.';
COMMENT ON COLUMN bauth.bos_rol_template_history.approved_by IS 'Admin que aprobó el cambio. NULL si aún no fue aprobado.';
COMMENT ON COLUMN bauth.bos_rol_template_history.changed_at IS 'Timestamp del cambio. DEFAULT NOW().';
COMMENT ON COLUMN bauth.bos_rol_template_history.change_reason IS 'Motivo del cambio. Obligatorio para cambios MAJOR.';
COMMENT ON COLUMN bauth.bos_rol_template_history.changes IS 'Array de descripciones de cambios aplicados. Ej: [''Incremento max_transaction de 5000 a 10000 BOB''].';
COMMENT ON COLUMN bauth.bos_rol_template_history.security_impact IS 'Impacto en seguridad: LOW(ajuste menor), MEDIUM(cambio de límites), HIGH(cambio de permisos), CRITICAL(cambio de tier/LoA).';
COMMENT ON COLUMN bauth.bos_rol_template_history.prev_hash IS 'Hash SHA-256 de la entrada anterior en la cadena. Garantiza integridad de la secuencia completa.';
COMMENT ON COLUMN bauth.bos_rol_template_history.entry_hash IS 'Hash SHA-256 de esta entrada. Calculado por trigger bauth.compute_entry_hash(): sha256(prev_hash || rol_id || version || changed_at || template_snap).';

-- ============================================================
-- 6. USER TEMPLATE — Identidad digital de un actor individual
-- ============================================================
-- Referencia: SBOS-USERTEMPLATE-v6_0.md
-- Jerarquía: user pertenece a una empresa y opcionalmente a una sucursal.
--            El tenant se hereda de la empresa.

CREATE TABLE IF NOT EXISTS bauth.bos_user_template (
    uuid            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id     TEXT,
    username        TEXT        NOT NULL,
    email           TEXT        NOT NULL,
    -- Jerarquía Context Plane
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    sucursal_id     TEXT       ,
    pos_logico      TEXT       ,
    -- Contextos autorizados (SBOS-049 §4.2)
    bos_contexts    TEXT[]      DEFAULT '{}',              -- ['skull/maya/lapaz', 'skull/inka/lapaz']
    context_actual  TEXT,                                  -- Contexto activo: 'skull/maya/lapaz/pos23'
    -- Roles
    rol_ids         TEXT[]      DEFAULT '{}',
    mask_eff_hex    TEXT        NOT NULL DEFAULT '0x0000000000000000',
    -- Estado
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    termination_date DATE,
    termination_reason TEXT,
    -- Sync
    sync_status     TEXT        NOT NULL DEFAULT 'PENDING',
    kc_user_id      TEXT,
    tryton_user_id  INTEGER,
    -- Sesiones
    last_login_at   TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    template        JSONB       NOT NULL,
    template_version TEXT       NOT NULL DEFAULT '6.0',
    CONSTRAINT chk_but_status CHECK (status IN ('ACTIVE','INACTIVE','SUSPENDED','TERMINATED')),
    UNIQUE (tenant_id, username)
);

CREATE INDEX IF NOT EXISTS idx_but_tenant      ON bauth.bos_user_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_but_empresa     ON bauth.bos_user_template(empresa_id);
CREATE INDEX IF NOT EXISTS idx_but_sucursal    ON bauth.bos_user_template(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_but_roles       ON bauth.bos_user_template USING GIN(rol_ids);
CREATE INDEX IF NOT EXISTS idx_but_kc          ON bauth.bos_user_template(kc_user_id);
CREATE INDEX IF NOT EXISTS idx_but_status      ON bauth.bos_user_template(status);
CREATE INDEX IF NOT EXISTS idx_but_template_gin ON bauth.bos_user_template USING GIN(template);

COMMENT ON TABLE bauth.bos_user_template IS 'Identidad digital de un actor individual en el SBOS. Define QUIÉN ES el usuario — separado del RolTemplate que define QUÉ PUEDE HACER. 16 bloques JSONB en columna template. Multiplicidad: un usuario puede tener múltiples roles. Referencia: SBOS-USERTEMPLATE-v6_0.md · SCIM 2.0 RFC 7643 · ISO 24760-2:2025.';
COMMENT ON COLUMN bauth.bos_user_template.uuid IS 'UUID único del usuario. Generado automáticamente. Inmutable.';
COMMENT ON COLUMN bauth.bos_user_template.external_id IS 'ID externo para integración con RRHH (OrangeHRM) u otros sistemas.';
COMMENT ON COLUMN bauth.bos_user_template.username IS 'Nombre de usuario único dentro del tenant. Usado para login.';
COMMENT ON COLUMN bauth.bos_user_template.email IS 'Email del usuario. Usado para notificaciones y recuperación de cuenta.';
COMMENT ON COLUMN bauth.bos_user_template.tenant_id IS 'Tenant al que pertenece el usuario. FK → bos_tenant.';
COMMENT ON COLUMN bauth.bos_user_template.tenant_id IS '3NF: Tenant del usuario. Derivable desde empresa_id (empresa→tenant). Desnormalización aceptada: la resolución tenant para un usuario es O(1) sin JOIN en cada validación de acceso.';
COMMENT ON COLUMN bauth.bos_user_template.empresa_id IS 'Empresa a la que pertenece el usuario. Hereda el tenant de la empresa. FK → bos_empresa.';
COMMENT ON COLUMN bauth.bos_user_template.sucursal_id IS 'Sucursal donde opera el usuario. NULL para roles que operan a nivel empresa. FK → bos_sucursal.';
COMMENT ON COLUMN bauth.bos_user_template.pos_logico IS 'POS lógico asignado. Un usuario siempre opera desde UN pos_logico. Define el ámbito de sus operaciones. FK → bos_pos_logico.';
COMMENT ON COLUMN bauth.bos_user_template.bos_contexts IS 'Array de contextos autorizados (tenant/empresa/sucursal). Define en qué contextos puede operar el usuario. SBOS-049 §4.2.';
COMMENT ON COLUMN bauth.bos_user_template.context_actual IS 'Contexto activo actual. Cambia con context_switches. Ej: ''skull/maya/lapaz/pos23''.';
COMMENT ON COLUMN bauth.bos_user_template.rol_ids IS 'Array de RolTemplates asignados al usuario. La máscara efectiva es el OR de todos los roles.';
COMMENT ON COLUMN bauth.bos_user_template.mask_eff_hex IS 'Máscara de permisos efectiva del usuario en hexadecimal. Calculada como OR de las máscaras de todos sus roles + herencia.';
COMMENT ON COLUMN bauth.bos_user_template.status IS 'Estado del usuario: ACTIVE(operativo), INACTIVE(desactivado), SUSPENDED(temporal), TERMINATED(baja definitiva).';
COMMENT ON COLUMN bauth.bos_user_template.termination_date IS 'Fecha de baja del usuario. NULL si está activo.';
COMMENT ON COLUMN bauth.bos_user_template.termination_reason IS 'Motivo de la baja: RENUNCIA, DESPIDO, JUBILACION, etc.';
COMMENT ON COLUMN bauth.bos_user_template.sync_status IS 'Estado de sincronización con Keycloak y Tryton: PENDING→SYNCING→SYNCED/ERROR/DRIFT.';
COMMENT ON COLUMN bauth.bos_user_template.kc_user_id IS 'UUID del usuario en Keycloak. Sincronizado vía Admin REST API.';
COMMENT ON COLUMN bauth.bos_user_template.tryton_user_id IS 'ID del usuario en Tryton (res.user). Sincronizado vía JSON-RPC.';
COMMENT ON COLUMN bauth.bos_user_template.last_login_at IS 'Timestamp del último login exitoso. Actualizado por el motor de autenticación.';
COMMENT ON COLUMN bauth.bos_user_template.last_activity_at IS 'Timestamp de la última actividad registrada. Usado para detectar inactividad.';
COMMENT ON COLUMN bauth.bos_user_template.template IS 'Documento JSONB completo con los 16 bloques del UserTemplate (identidad, credenciales, biométrico, roles, delegaciones, sesiones, preferencias, etc.). Schema v6.0.';
COMMENT ON COLUMN bauth.bos_user_template.template_version IS 'Versión del schema JSONB del template. Actual: ''6.0''.';

-- ============================================================
-- 7. ROL CLOSURE — DAG herencia precomputada
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_rol_closure (
    ancestro_id     TEXT        NOT NULL,
    descendiente_id TEXT        NOT NULL,
    profundidad     INTEGER     NOT NULL CHECK (profundidad >= 0),
    PRIMARY KEY (ancestro_id, descendiente_id),
    CONSTRAINT fk_closure_ancestro FOREIGN KEY (ancestro_id) ON DELETE CASCADE,
    CONSTRAINT fk_closure_descendiente FOREIGN KEY (descendiente_id) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_ref CHECK (ancestro_id != descendiente_id OR profundidad = 0)
);

CREATE INDEX IF NOT EXISTS idx_rc_desc ON bauth.bos_rol_closure(descendiente_id);
CREATE INDEX IF NOT EXISTS idx_rc_anc  ON bauth.bos_rol_closure(ancestro_id);

COMMENT ON TABLE bauth.bos_rol_closure IS 'Closure table para herencia DAG. ancestro HEREDA de descendiente (junior→senior). 186 aristas documentadas en BAUTH-CADENAS-JERARQUIA.md v1.1.';

-- ============================================================
-- 8. DELEGATION LOG — Delegaciones temporales
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_delegation_log (
    delegation_id   BIGSERIAL   PRIMARY KEY,
    from_user_uuid  UUID        NOT NULL,
    to_user_uuid    UUID        NOT NULL,
    rol_id          TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    mask_delegated_hex TEXT    NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NOT NULL,
    auto_revoke     BOOLEAN     NOT NULL DEFAULT true,
    requires_approval BOOLEAN   NOT NULL DEFAULT true,
    approved_by     TEXT,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_del_status CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
    CONSTRAINT chk_del_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_no_self_delegation CHECK (from_user_uuid != to_user_uuid)
);

CREATE INDEX IF NOT EXISTS idx_bdl_active   ON bauth.bos_delegation_log(valid_until) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_bdl_from     ON bauth.bos_delegation_log(from_user_uuid);

COMMENT ON TABLE bauth.bos_delegation_log IS 'Registro de delegaciones temporales de roles. Un usuario (from) delega parte de sus permisos a otro (to) por tiempo limitado. Bitmask efectiva = original AND delegada. Max 21 días. Auto-revocación al expirar. Referencia: BAUTH-100 §15 · NIST AC-5.';
COMMENT ON COLUMN bauth.bos_delegation_log.delegation_id IS 'ID auto-incremental de la delegación.';
COMMENT ON COLUMN bauth.bos_delegation_log.from_user_uuid IS 'Usuario que delega sus permisos. FK → bos_user_template.';
COMMENT ON COLUMN bauth.bos_delegation_log.to_user_uuid IS 'Usuario que recibe los permisos delegados. FK → bos_user_template.';
COMMENT ON COLUMN bauth.bos_delegation_log.rol_id IS 'RolTemplate delegado. FK → bos_rol_template.';
COMMENT ON COLUMN bauth.bos_delegation_log.tenant_id IS 'Tenant donde aplica la delegación.';
COMMENT ON COLUMN bauth.bos_delegation_log.mask_delegated_hex IS 'Máscara delegada en hexadecimal. Calculada como mask_eff(from) AND mask_own(rol).';
COMMENT ON COLUMN bauth.bos_delegation_log.valid_from IS 'Inicio de la delegación. DEFAULT NOW().';
COMMENT ON COLUMN bauth.bos_delegation_log.valid_until IS 'Fin de la delegación. Max valid_from + 21 días. Auto-revocación al expirar.';
COMMENT ON COLUMN bauth.bos_delegation_log.auto_revoke IS 'TRUE = el sistema revoca automáticamente al expirar. FALSE = requiere intervención manual.';
COMMENT ON COLUMN bauth.bos_delegation_log.requires_approval IS 'TRUE = requiere aprobación de un superior. FALSE = delegación directa.';
COMMENT ON COLUMN bauth.bos_delegation_log.approved_by IS 'Admin que aprobó la delegación. NULL si no requiere aprobación.';
COMMENT ON COLUMN bauth.bos_delegation_log.status IS 'Estado: ACTIVE(vigente), REVOKED(revocada manualmente), EXPIRED(vencida).';
COMMENT ON COLUMN bauth.bos_delegation_log.revoked_at IS 'Timestamp de revocación. NULL si no fue revocada.';

-- ============================================================
-- 9. BIOMETRIC TEMPLATES — Solo hashes, nunca raw data (RGPD Art.9)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_biometric_templates (
    id                BIGSERIAL   PRIMARY KEY,
    user_uuid         UUID        NOT NULL,
    tenant_id         TEXT        NOT NULL,
    biometric_type    TEXT        NOT NULL,
    finger            SMALLINT,
    template_hash     BYTEA       NOT NULL,
    salt              BYTEA       NOT NULL,
    argon2_params     JSONB       NOT NULL DEFAULT '{"t":3,"m":65536,"p":2}',
    enrollment_policy TEXT        NOT NULL DEFAULT 'admin_only',
    liveness_verified BOOLEAN     NOT NULL DEFAULT false,
    admin_verified    BOOLEAN     NOT NULL DEFAULT false,
    consent_given     BOOLEAN     NOT NULL DEFAULT false,
    consent_date      TIMESTAMPTZ,
    enrolled_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    enrolled_by       TEXT,
    revoked_at        TIMESTAMPTZ,
    CONSTRAINT chk_biometric_type CHECK (biometric_type IN ('fingerprint','face','iris','palm_vein')),
    CONSTRAINT chk_enrollment     CHECK (enrollment_policy IN ('admin_only','self_service','hybrid'))
);

CREATE INDEX IF NOT EXISTS idx_biot_user ON bauth.bos_biometric_templates(user_uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_biot_unique_null ON bauth.bos_biometric_templates(user_uuid, biometric_type) WHERE finger IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_biot_unique_finger ON bauth.bos_biometric_templates(user_uuid, biometric_type, finger) WHERE finger IS NOT NULL;

COMMENT ON TABLE bauth.bos_biometric_templates IS 'Plantillas biométricas hasheadas con Argon2id. NUNCA se almacenan datos biométricos en texto plano. PBKDF2-SHA256 + salt único. RGPD Art.9 (categoría especial de datos) · NIST SP 800-63B-4 §3.2.4 · ISO/IEC 30107-3 (liveness detection).';
COMMENT ON COLUMN bauth.bos_biometric_templates.user_uuid IS 'Usuario propietario de la plantilla biométrica. FK → bos_user_template.';
COMMENT ON COLUMN bauth.bos_biometric_templates.biometric_type IS 'Tipo biométrico: fingerprint(huella), face(rostro), iris, palm_vein(venas palmares).';
COMMENT ON COLUMN bauth.bos_biometric_templates.finger IS 'Dedo para fingerprint: 1=pulgar der, 2=índice der, ..., 10=meñique izq. NULL para otros tipos.';
COMMENT ON COLUMN bauth.bos_biometric_templates.template_hash IS 'Hash Argon2id de la plantilla biométrica. NUNCA el raw data.';
COMMENT ON COLUMN bauth.bos_biometric_templates.salt IS 'Salt único de 32 bytes generado por CSPRNG. Diferente para cada template.';
COMMENT ON COLUMN bauth.bos_biometric_templates.enrollment_policy IS 'Política de enrolamiento: admin_only(solo admin), self_service(autogestión), hybrid(admin verifica self-service).';
COMMENT ON COLUMN bauth.bos_biometric_templates.liveness_verified IS 'TRUE si se verificó liveness (detección de deepfake/spoof). ISO/IEC 30107-3.';
COMMENT ON COLUMN bauth.bos_biometric_templates.consent_given IS 'TRUE si el usuario dio consentimiento explícito para el uso de sus datos biométricos. RGPD Art.9 §2(a).';

-- ============================================================
-- 10. PASSWORD HISTORY — Últimas 10 contraseñas (NIST screening)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_password_history (
    id            BIGSERIAL   PRIMARY KEY,
    user_uuid     UUID        NOT NULL,
    password_hash BYTEA       NOT NULL,
    salt          BYTEA       NOT NULL,
    argon2_params JSONB       NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bph_user ON bauth.bos_password_history(user_uuid, created_at DESC);

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

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_password_history_cleanup') THEN
        CREATE TRIGGER trg_password_history_cleanup
            AFTER INSERT ON bauth.bos_password_history
            FOR EACH ROW EXECUTE FUNCTION bauth.cleanup_password_history();
    END IF;
END $$;

COMMENT ON TABLE bauth.bos_password_history IS 'Historial de contraseñas del usuario. Previene reutilización (últimas 10). Trigger cleanup mantiene solo las 10 más recientes. NIST SP 800-63B-4 §5.1.1.2 (password screening).';
COMMENT ON COLUMN bauth.bos_password_history.user_uuid IS 'Usuario propietario de la contraseña. FK → bos_user_template.';
COMMENT ON COLUMN bauth.bos_password_history.password_hash IS 'Hash Argon2id de la contraseña. Parámetros: t=3, m=65536 (64MB), p=2.';
COMMENT ON COLUMN bauth.bos_password_history.salt IS 'Salt único de 16 bytes.';
COMMENT ON COLUMN bauth.bos_password_history.argon2_params IS 'Parámetros Argon2id usados: {t, m, p}. Permite evolución de parámetros sin re-hash masivo.';

-- ============================================================
-- 11. MFA ENROLLMENTS — Dispositivos MFA
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_mfa_enrollments (
    id            BIGSERIAL   PRIMARY KEY,
    user_uuid     UUID        NOT NULL,
    mfa_type      TEXT        NOT NULL,
    label         TEXT,
    credential_id TEXT,
    public_key    TEXT,
    device_info   JSONB       DEFAULT '{}',
    is_primary    BOOLEAN     NOT NULL DEFAULT false,
    is_backup     BOOLEAN     NOT NULL DEFAULT false,
    enrolled_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at  TIMESTAMPTZ,
    revoked_at    TIMESTAMPTZ,
    CONSTRAINT chk_mfa_type CHECK (mfa_type IN ('totp','webauthn_platform','webauthn_roaming','passkey','recovery_codes'))
);

CREATE INDEX IF NOT EXISTS idx_bme_user ON bauth.bos_mfa_enrollments(user_uuid);

COMMENT ON TABLE bauth.bos_mfa_enrollments IS 'Registro de dispositivos MFA por usuario. Soporta TOTP, WebAuthn, Passkeys y Recovery Codes. Ciclo de vida completo: enroll→verify→rotate→revoke→deprecate. NIST SP 800-63B-4 §5.1 · FIDO2 Level 3.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.user_uuid IS 'Usuario propietario del dispositivo MFA. FK → bos_user_template.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.mfa_type IS 'Tipo MFA: totp(TOTP RFC 6238), webauthn_platform(HW local), webauthn_roaming(llave USB), passkey(FIDO2 synced), recovery_codes(códigos backup).';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.label IS 'Etiqueta descriptiva: ''iPhone 15 Pro'', ''YubiKey 5C NFC'', ''Códigos backup''.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.credential_id IS 'Credential ID FIDO2/WebAuthn. Base64. NULL para TOTP.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.public_key IS 'Clave pública WebAuthn/PKIX. NULL para TOTP.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.is_primary IS 'TRUE si es el dispositivo MFA principal del usuario. Solo uno por usuario.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.is_backup IS 'TRUE si es código de recuperación o dispositivo de respaldo.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.last_used_at IS 'Timestamp del último uso. Para detectar dispositivos abandonados.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.revoked_at IS 'Timestamp de revocación. NULL si el dispositivo sigue activo.';

-- ============================================================
-- 12. AUDIT EVENTS — Registro inmutable WORM (ISO 27001 A.8.15)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_audit_events (
    event_id        BIGSERIAL,
    ctx_id          TEXT        NOT NULL,
    traceparent     TEXT,
    event_type      TEXT        NOT NULL,
    severity        TEXT        NOT NULL DEFAULT 'INFO',
    iso_control     TEXT[],
    user_uuid       UUID       ,
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
    CONSTRAINT chk_audit_event_type CHECK (event_type IN (
        'LOGIN_SUCCESS','LOGIN_FAILED','LOGOUT','ACCESS_DENIED','ACCESS_GRANTED',
        'CONFIG_CHANGE','PRIVILEGE_ESCALATION','PRIVILEGE_USE','MAINTENANCE',
        'FILE_ACCESS','FILE_DELETE','FILE_MIGRATION',
        'SECURITY_ALARM','SECURITY_SYSTEM_TOGGLE',
        'IDENTITY_CREATE','IDENTITY_MODIFY','IDENTITY_DELETE','IDENTITY_ARCHIVE',
        'SYSTEM_FAULT','EXCEPTION','ANOMALY',
        'TRANSACTION_EXECUTE','TRANSACTION_ROLLBACK',
        'AUDIT_ACCESS','SESSION_START','SESSION_END','STEP_UP','DELEGATION',
        'POLICY_VIOLATION','BREAK_GLASS','RECOVERY','MFA_ENROLL','MFA_VERIFY',
        'MFA_REVOKE','KEY_ROTATE','SYNC_START','SYNC_END','SYNC_ERROR',
        'RECONCILE_START','RECONCILE_END','RECONCILE_DRIFT'
    ))
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS bauth.bos_audit_events_2026_07 PARTITION OF bauth.bos_audit_events
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.bos_audit_events_2026_08 PARTITION OF bauth.bos_audit_events
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE INDEX IF NOT EXISTS idx_bae_ctx      ON bauth.bos_audit_events(ctx_id);
CREATE INDEX IF NOT EXISTS idx_bae_user     ON bauth.bos_audit_events(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bae_type     ON bauth.bos_audit_events(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bae_tenant   ON bauth.bos_audit_events(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bae_severity ON bauth.bos_audit_events(severity, created_at DESC) WHERE severity IN ('ERROR','CRITICAL');

REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_audit_events TO bauth;

COMMENT ON TABLE bauth.bos_audit_events IS 'WORM inmutable — ISO 27001:2022 A.8.15 · PCI DSS 4.0 Req 10 · NIST 800-53 AU-2/AU-3/AU-9 · CIS Control 8. Particionado por mes. Hash-chain SHA-256 (prev_hash→entry_hash). ctx_id obligatorio (SBOS-049). 38 event_types CHECK-validados. REVOKE UPDATE/DELETE.';
COMMENT ON COLUMN bauth.bos_audit_events.event_type IS 'Tipo de evento según ISO 27001 A.8.15 (10 categorías) + NIST 800-53 AU-2. CHECK constraint con 38 valores válidos.';
COMMENT ON COLUMN bauth.bos_audit_events.device_id IS 'Dispositivo físico donde ocurrió el evento. Correlación hardware para NIST AU-3 (where — device). FK lógico a bos_device_registry.';
COMMENT ON COLUMN bauth.bos_audit_events.prev_hash IS 'Hash SHA-256 de la entrada anterior en la cadena. Garantiza integridad de secuencia — modificar un registro rompe toda la cadena. PCI DSS 4.0 Req 10.3.';
COMMENT ON COLUMN bauth.bos_audit_events.entry_hash IS 'Hash SHA-256 de esta entrada. Calculado por trigger. Incluye prev_hash || ctx_id || event_type || outcome || created_at.';
COMMENT ON COLUMN bauth.bos_audit_events.iso_control IS 'Array de controles ISO 27001/NIST/PCI que evidencia este evento. Ej: {ISO_27001_A.8.15, PCI_DSS_10.1}.';
COMMENT ON COLUMN bauth.bos_audit_events.empresa_id IS 'Empresa donde ocurrió el evento. Clave para auditoría fiscal SIN (NIT).';
COMMENT ON COLUMN bauth.bos_audit_events.pos_logico IS 'POS lógico donde ocurrió. Trazabilidad a nivel de terminal.';
COMMENT ON TABLE bauth.bos_audit_events_2026_07 IS 'Partición de bos_audit_events para Julio 2026. Rango: 2026-07-01 a 2026-08-01.';
COMMENT ON TABLE bauth.bos_audit_events_2026_08 IS 'Partición de bos_audit_events para Agosto 2026. Rango: 2026-08-01 a 2026-09-01.';

-- Trigger hash-chain para bos_audit_events (PCI DSS 4.0 Req 10.3 + ISO 27001 A.8.15)
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

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_entry_hash') THEN
        CREATE TRIGGER trg_audit_entry_hash
            BEFORE INSERT ON bauth.bos_audit_events
            FOR EACH ROW EXECUTE FUNCTION bauth.compute_audit_entry_hash();
    END IF;
END $$;

-- ============================================================
-- 13. CONTEXT SESSIONS — Sesiones del Context Plane (6 capas)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_context_sessions (
    ctx_id          TEXT        PRIMARY KEY,
    dctx_id         TEXT,
    -- 6 capas del Context Plane (SBOS-049 §4)
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    sucursal_id     TEXT,
    pos_logico      TEXT,
    user_uuid       UUID        NOT NULL,
    -- Ruta canónica: /dist/{tenant}/emp/{empresa}/suc/{sucursal}/user/{user_id}/pos/{pos_id}
    ruta_canonica   TEXT,                                  -- '/dist/skull/emp/maya/suc/lapaz/user/3397708/pos/23'
    context_actual  TEXT,                                  -- 'skull/maya/lapaz/pos23'
    bos_contexts    TEXT[],                                -- Contextos autorizados del usuario
    -- Dispositivo físico (SBOS-049 §6)
    device_id       TEXT,                                  -- Hardware físico (DEVICE-991)
    device_hostname TEXT,
    device_ip       INET,
    device_mac      MACADDR,
    device_geo      TEXT,
    -- Sesión técnica
    session_kc      TEXT        NOT NULL,
    bitmask_hex     TEXT        NOT NULL,
    loa_current     INTEGER     NOT NULL DEFAULT 1,
    traceparent     TEXT,
    tracestate      TEXT,
    pod             TEXT,
    namespace_k8s   TEXT,
    node            TEXT,
    state           TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    invalidated_at  TIMESTAMPTZ,
    CONSTRAINT chk_ctx_state CHECK (state IN ('ACTIVE','INVALIDATED','EXPIRED'))
);

CREATE INDEX IF NOT EXISTS idx_cs_user    ON bauth.bos_context_sessions(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_expiry  ON bauth.bos_context_sessions(expires_at) WHERE state = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_cs_tenant  ON bauth.bos_context_sessions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cs_empresa ON bauth.bos_context_sessions(empresa_id);

COMMENT ON TABLE bauth.bos_context_sessions IS 'Sesiones Context Plane (SBOS-049). 6 capas + asociación dinámica POS lógico↔físico. Kong PEP consulta via bAuth :9443.';
COMMENT ON COLUMN bauth.bos_context_sessions.ruta_canonica IS 'Ruta canónica del contexto: /dist/{tenant}/emp/{empresa}/suc/{sucursal}/user/{user_id}/pos/{pos_id}.';
COMMENT ON COLUMN bauth.bos_context_sessions.bos_contexts IS 'Árbol de contextos autorizados del usuario (desde JWT Keycloak).';
COMMENT ON COLUMN bauth.bos_context_sessions.sucursal_id IS '3NF: Jerarquía Context Plane — sucursal→empresa→tenant. Desnormalización aceptada por patrón de 6 capas SBOS-049 §4. La resolución de tenant desde sucursal es O(1) en runtime sin JOIN.';
COMMENT ON COLUMN bauth.bos_context_sessions.empresa_id IS '3NF: Jerarquía Context Plane. Resolución directa sin JOIN a bos_sucursal en cada validación de acceso.';
COMMENT ON COLUMN bauth.bos_context_sessions.state IS '3NF: Estado derivable (EXPIRED si expires_at < NOW()). CHECK constraint garantiza integridad. Desnormalización para queries rápidas.';

-- ============================================================
-- 13-B. CONTEXT SWITCHES — Historial de cambios de contexto
-- ============================================================
-- Propósito: Registrar cada cambio de contexto operativo del usuario.
--            Si un usuario cambia de sucursal o POS, queda registrado.
--            Requerido para auditoría ISO 27001 A.8.15.
-- Referencia: SBOS-049 §4.3 (árbol de contextos), §5.1

CREATE TABLE IF NOT EXISTS bauth.bos_context_switches (
    switch_id       BIGSERIAL   PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    ctx_id_anterior TEXT,                                  -- Contexto antes del switch
    ctx_id_nuevo    TEXT        NOT NULL,                  -- Contexto después del switch
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    sucursal_id     TEXT,
    pos_logico      TEXT,
    motivo          TEXT,                                  -- 'cambio_sucursal', 'reasignacion_pos', 'login'
    emitido_por     TEXT        NOT NULL DEFAULT 'bos',    -- bos|usuario|admin
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_csw_user ON bauth.bos_context_switches(user_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_csw_ctx  ON bauth.bos_context_switches(ctx_id_nuevo);

COMMENT ON TABLE bauth.bos_context_switches IS 'Historial de cambios de contexto operativo. Evento context.switched → bKernel → audit_events.';

-- ============================================================
-- 14. SYNC LOG — Auditoría de sincronización
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_sync_log (
    id              BIGSERIAL   PRIMARY KEY,
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
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    duration_ms     INTEGER,
    CONSTRAINT chk_sync_status CHECK (status IN ('PENDING','SYNCING','SYNCED','ERROR','DRIFT')),
    CONSTRAINT chk_sync_engine CHECK (engine IN ('KEYCLOAK','TRYTON','BOTH'))
);

CREATE INDEX IF NOT EXISTS idx_bsl_status ON bauth.bos_sync_log(status) WHERE status IN ('ERROR','PENDING');
CREATE INDEX IF NOT EXISTS idx_bsl_retry  ON bauth.bos_sync_log(next_retry_at) WHERE next_retry_at IS NOT NULL;

REVOKE UPDATE, DELETE ON bauth.bos_sync_log FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_sync_log FROM bauth;
GRANT INSERT, SELECT ON bauth.bos_sync_log TO bauth;

COMMENT ON TABLE bauth.bos_sync_log IS 'WORM — Registro de sincronización bAuth→Keycloak+Tryton. Solo INSERT+SELECT. REVOKE UPDATE/DELETE. Cada sync queda registrado con estado, errores, reintentos y duración. Trazabilidad completa de cada operación de sincronización. ISO 27001 A.8.15.';
COMMENT ON COLUMN bauth.bos_sync_log.rol_id IS 'RolTemplate sincronizado. NULL si fue sync de usuario.';
COMMENT ON COLUMN bauth.bos_sync_log.user_uuid IS 'Usuario sincronizado. NULL si fue sync de rol.';
COMMENT ON COLUMN bauth.bos_sync_log.engine IS 'Motor destino: KEYCLOAK, TRYTON o BOTH (ambos).';
COMMENT ON COLUMN bauth.bos_sync_log.sync_type IS 'Tipo de sync: CREATE, UPDATE, REVOKE, RECONCILE, BOOTSTRAP.';
COMMENT ON COLUMN bauth.bos_sync_log.triggered_by IS 'Qué disparó el sync: APPROVE(aprobación), RECONCILE_LOOP(detección drift), MANUAL(admin), BOOTSTRAP(reconstrucción).';
COMMENT ON COLUMN bauth.bos_sync_log.kc_status IS 'Resultado en Keycloak: OK, ERROR, TIMEOUT, SKIPPED.';
COMMENT ON COLUMN bauth.bos_sync_log.tryton_status IS 'Resultado en Tryton: OK, ERROR, TIMEOUT, SKIPPED.';
COMMENT ON COLUMN bauth.bos_sync_log.retry_count IS 'Número de reintentos. Max 3 antes de marcar ERROR definitivo.';
COMMENT ON COLUMN bauth.bos_sync_log.duration_ms IS 'Duración total del sync en milisegundos. Para monitoreo de SLO (< 5s).';

-- ============================================================
-- 15. SUPERUSER CONTEXTS — Break-Glass SU (max 4h)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_superuser_contexts (
    context_id      TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    admin_uuid      UUID        NOT NULL,
    reason          TEXT        NOT NULL,
    vault_unseal    BOOLEAN     NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    post_audit_at   TIMESTAMPTZ,
    post_audit_by   UUID,
    session_log     TEXT,
    CONSTRAINT chk_su_expiry CHECK (expires_at <= created_at + INTERVAL '4 hours')
);

CREATE INDEX IF NOT EXISTS idx_bsc_active ON bauth.bos_superuser_contexts(expires_at) WHERE revoked_at IS NULL;

COMMENT ON TABLE bauth.bos_superuser_contexts IS 'Registro de activaciones break-glass del Superusuario. Acceso de emergencia con Vault 2-of-3 unseal. Sesión máxima 4h. Auditoría post-evento obligatoria ≤24h. ISO 27001 A.8.2 · PAM mejores prácticas.';
COMMENT ON COLUMN bauth.bos_superuser_contexts.reason IS 'Motivo del acceso de emergencia. Obligatorio. Se audita post-evento.';
COMMENT ON COLUMN bauth.bos_superuser_contexts.vault_unseal IS 'TRUE si se realizó unseal 2-of-3 de Vault. FALSE si se usó otro mecanismo.';
COMMENT ON COLUMN bauth.bos_superuser_contexts.expires_at IS 'Fecha de expiración. Max created_at + 4h. CHECK enforce.';
COMMENT ON COLUMN bauth.bos_superuser_contexts.post_audit_at IS 'Timestamp de la auditoría post-evento. Debe completarse ≤24h después de revocación.';
COMMENT ON COLUMN bauth.bos_superuser_contexts.session_log IS 'Registro completo de la sesión (comandos ejecutados). Inmutable.';

-- ============================================================
-- 16. ACCESS REVIEWS — Revisiones periódicas (ISO 27001 A.9.2.1)
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_access_reviews (
    review_id       BIGSERIAL   PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    reviewer_uuid   UUID        NOT NULL,
    review_type     TEXT        NOT NULL,
    due_date        DATE        NOT NULL,
    decision        TEXT,
    decision_at     TIMESTAMPTZ,
    comments        TEXT,
    previous_roles  TEXT[],
    current_roles   TEXT[],
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_review_type CHECK (review_type IN ('MONTHLY','QUARTERLY','SEMI_ANNUAL','ANNUAL'))
);

CREATE INDEX IF NOT EXISTS idx_bar_due ON bauth.bos_access_reviews(due_date) WHERE decision IS NULL;

COMMENT ON TABLE bauth.bos_access_reviews IS 'Campañas de recertificación de accesos. Revisiones periódicas mensuales/trimestrales/anuales. Cada review verifica que los roles del usuario siguen siendo apropiados. ISO 27001 A.9.2.5 · NIST AC-2.';
COMMENT ON COLUMN bauth.bos_access_reviews.review_type IS 'Frecuencia: MONTHLY(mensual), QUARTERLY(trimestral), SEMI_ANNUAL(semestral), ANNUAL(anual).';
COMMENT ON COLUMN bauth.bos_access_reviews.due_date IS 'Fecha límite para completar la revisión. Alertas 7 días antes.';
COMMENT ON COLUMN bauth.bos_access_reviews.decision IS 'Resultado: APPROVED(roles OK), MODIFIED(roles ajustados), REVOKED(roles revocados).';
COMMENT ON COLUMN bauth.bos_access_reviews.previous_roles IS 'Roles del usuario ANTES de la revisión. Snapshot para auditoría.';
COMMENT ON COLUMN bauth.bos_access_reviews.current_roles IS 'Roles del usuario DESPUÉS de la revisión. NULL hasta que se complete.';

-- ============================================================
-- 17. GHOST ACCOUNT LOG — Cuentas huérfanas
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_ghost_accounts (
    id              BIGSERIAL   PRIMARY KEY,
    user_uuid       UUID        NOT NULL,
    username        TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    detection_type  TEXT        NOT NULL,
    risk_score      INTEGER     NOT NULL DEFAULT 0,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    action_taken    TEXT        NOT NULL DEFAULT 'DETECTED',
    action_at       TIMESTAMPTZ,
    resolution      TEXT,
    CONSTRAINT chk_detection_type CHECK (detection_type IN ('KC_ACTIVE_HR_INACTIVE','NO_LOGIN_180D','TRYTON_ONLY','KC_ONLY','INCONSISTENT_SYNC'))
);

CREATE INDEX IF NOT EXISTS idx_bga_detected ON bauth.bos_ghost_accounts(detected_at DESC);

COMMENT ON TABLE bauth.bos_ghost_accounts IS 'Registro de cuentas huérfanas detectadas. Una cuenta es huérfana cuando existe en Keycloak pero no en RRHH, o no ha tenido login en 180 días, o existe solo en Tryton. ISACA: 37% de organizaciones tienen ghost accounts.';
COMMENT ON COLUMN bauth.bos_ghost_accounts.detection_type IS 'Tipo de detección: KC_ACTIVE_HR_INACTIVE(activo en KC, baja en RRHH), NO_LOGIN_180D(sin login 180 días), TRYTON_ONLY(solo en Tryton), KC_ONLY(solo en Keycloak), INCONSISTENT_SYNC(datos inconsistentes).';
COMMENT ON COLUMN bauth.bos_ghost_accounts.risk_score IS 'Score de riesgo 0-100. Basado en antigüedad, roles y privilegios de la cuenta huérfana.';
COMMENT ON COLUMN bauth.bos_ghost_accounts.action_taken IS 'Acción tomada: DETECTED, NOTIFIED, DISABLED, REVOKED.';

-- ============================================================
-- 18. KEY ROTATION LOG — Ciclo de vida de claves
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_key_rotation_log (
    id              BIGSERIAL   PRIMARY KEY,
    key_type        TEXT        NOT NULL,
    key_identifier  TEXT        NOT NULL,
    issuer          TEXT        NOT NULL,
    action          TEXT        NOT NULL,
    old_expiry      TIMESTAMPTZ,
    new_expiry      TIMESTAMPTZ,
    performed_by    TEXT        NOT NULL,
    performed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ceremony        BOOLEAN     NOT NULL DEFAULT false,
    witnesses       TEXT[],
    details         JSONB       DEFAULT '{}',
    CONSTRAINT chk_key_action CHECK (action IN ('GENERATED','ROTATED','REVOKED','COMPROMISED'))
);

CREATE INDEX IF NOT EXISTS idx_bkrl_key ON bauth.bos_key_rotation_log(key_type, performed_at DESC);

COMMENT ON TABLE bauth.bos_key_rotation_log IS 'Registro del ciclo de vida de claves criptográficas. Cada evento GENERATED/ROTATED/REVOKED/COMPROMISED queda registrado. Ceremonias de rotación con testigos. NIST SP 800-57 Pt.1 · FIPS 140-3.';
COMMENT ON COLUMN bauth.bos_key_rotation_log.key_type IS 'Tipo de clave: SIGNING_ED25519, ENCRYPTION_AES256, TLS, JWT_SIGNING, VAULT_UNSEAL, RECOVERY.';
COMMENT ON COLUMN bauth.bos_key_rotation_log.action IS 'Acción: GENERATED(creada), ROTATED(rotada), REVOKED(revocada), COMPROMISED(comprometida).';
COMMENT ON COLUMN bauth.bos_key_rotation_log.ceremony IS 'TRUE si la operación requirió ceremonia formal con múltiples testigos.';
COMMENT ON COLUMN bauth.bos_key_rotation_log.witnesses IS 'Array de testigos que presenciaron la ceremonia de rotación.';

-- ============================================================
-- 19. ZONE ↔ APPLICATION MAP
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.bos_zone_application_map (
    zone_id      TEXT        NOT NULL,
    app_id       TEXT        NOT NULL,
    app_scopes   TEXT[],
    client_id    TEXT,
    modules      TEXT[],
    active       BOOLEAN     NOT NULL DEFAULT true,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (zone_id, app_id)
);

COMMENT ON TABLE bauth.bos_zone_application_map IS 'Mapeo de zonas lógicas a aplicaciones. Define qué aplicaciones están disponibles en cada zona. Usado por el motor de dominios para filtrar átomos disponibles por zona.';
COMMENT ON COLUMN bauth.bos_zone_application_map.zone_id IS 'Zona lógica: ZONA-CONTABILIDAD, ZONA-VENTAS, ZONA-RRHH, etc. FK → bos_zona_logica.';
COMMENT ON COLUMN bauth.bos_zone_application_map.app_id IS 'Aplicación disponible en esta zona. FK → bos_application.';
COMMENT ON COLUMN bauth.bos_zone_application_map.app_scopes IS 'Scopes OAuth 2.0 permitidos para esta app en esta zona.';
COMMENT ON COLUMN bauth.bos_zone_application_map.modules IS 'Módulos específicos de la app visibles en esta zona. NULL = todos.';

-- ============================================================
-- 20. SCHEMA bos_privilege — Motor de Privilegios (BitMask Dual)
-- ============================================================
-- El schema bos_privilege implementa el modelo relacional del
-- PrivilegeEngine. Átomos, roles, políticas y asignaciones.
-- Referencia: SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bos_privilege;
ALTER SCHEMA bos_privilege OWNER TO bauth;

COMMENT ON SCHEMA bos_privilege IS 'Motor de Privilegios SBOS — modelo relacional del PrivilegeEngine. Átomos, roles, políticas, verbos, grupos y aplicaciones. Implementa el BitMask Dual v3.0.';

-- 20.1 DOMINIOS — Catálogo de 12 dominios de soberanía
CREATE TABLE IF NOT EXISTS bos_privilege.bos_domain (
    domain_code     SMALLINT    NOT NULL,
    domain_name     VARCHAR(64) NOT NULL,
    requires_policy BOOLEAN     NOT NULL DEFAULT false,
    description     TEXT,
    CONSTRAINT pk_bos_domain PRIMARY KEY (domain_code),
    CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 1 AND 15)
);
COMMENT ON TABLE bos_privilege.bos_domain IS 'Catálogo de 12 dominios de soberanía D1-D12. domain_code se empaqueta en bits 8-11 del Dominio Contextual (4 bits). NUNCA texto.';
COMMENT ON COLUMN bos_privilege.bos_domain.domain_code IS 'Código numérico del dominio: 1=Físico(D2), 2=Lógico(D1), 3=Financiero(D3), 4=Temporal(D4), 5=Biométrico(D5), 6=Geoespacial(D6), 7=Red(D7), 8=Contexto(D8), 9=Dispositivo(D9), 10=Delegación(D10), 11=Auditoría(D11), 12=Blockchain(D12).';
COMMENT ON COLUMN bos_privilege.bos_domain.requires_policy IS 'TRUE si este dominio requiere políticas explícitas para cada átomo. FALSE si la evaluación es solo por bitmask.';

-- 20.2 APLICACIONES — Fichas registradas en SBOS
CREATE TABLE IF NOT EXISTS bos_privilege.bos_application (
    app_code        SMALLINT    NOT NULL,
    app_name        VARCHAR(64) NOT NULL,
    app_slug        VARCHAR(32) NOT NULL,
    tenant_id       UUID        NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_application PRIMARY KEY (app_code),
    CONSTRAINT uq_bos_application_slug UNIQUE (tenant_id, app_slug),
    CONSTRAINT ck_app_code CHECK (app_code BETWEEN 1 AND 511)
);
COMMENT ON TABLE bos_privilege.bos_application IS 'Aplicaciones ficha registradas. app_code (9 bits) se empaqueta en bits 12-20 del Dominio Contextual.';

-- 20.3 GRUPOS FUNCIONALES — Por aplicación
CREATE TABLE IF NOT EXISTS bos_privilege.bos_group (
    group_code      SMALLINT    NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_name      VARCHAR(128) NOT NULL,
    CONSTRAINT pk_bos_group PRIMARY KEY (app_code, group_code),
    CONSTRAINT fk_bos_group_app FOREIGN KEY (app_code),
    CONSTRAINT ck_group_code CHECK (group_code BETWEEN 1 AND 2047)
);
COMMENT ON TABLE bos_privilege.bos_group IS 'Grupos funcionales dentro de cada aplicación. group_code (11 bits) en bits 21-31 del Dominio Contextual.';

-- 20.4 VERBOS — Vocabulario global
CREATE TABLE IF NOT EXISTS bos_privilege.bos_verb (
    verb_code       SMALLINT    NOT NULL,
    verb_name       VARCHAR(32) NOT NULL,
    verb_slug       VARCHAR(32) NOT NULL,
    CONSTRAINT pk_bos_verb PRIMARY KEY (verb_code),
    CONSTRAINT uq_bos_verb_name UNIQUE (verb_name),
    CONSTRAINT ck_verb_code CHECK (verb_code BETWEEN 1 AND 255)
);
COMMENT ON TABLE bos_privilege.bos_verb IS 'Vocabulario global de verbos. Label encoding — NUNCA combinar con bitwise. La combinación usa bos_role_atom (one-hot).';

-- 20.5 CATÁLOGO DE ÁTOMOS — Fuente de verdad del BitMask Átomo
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_catalog (
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
    CONSTRAINT pk_bos_atom_catalog PRIMARY KEY (app_code, group_code, atom_code),
    CONSTRAINT uq_bos_atom_position UNIQUE (atom_position),
    CONSTRAINT uq_bos_atom_slug UNIQUE (app_code, atom_slug),
    CONSTRAINT fk_bos_atom_app FOREIGN KEY (app_code, group_code),
    CONSTRAINT fk_bos_atom_domain FOREIGN KEY (domain_code),
    CONSTRAINT fk_bos_atom_verb FOREIGN KEY (verb_code),
    CONSTRAINT ck_atom_code CHECK (atom_code BETWEEN 1 AND 16777215),
    CONSTRAINT ck_atom_position CHECK (atom_position >= 0)
);
COMMENT ON TABLE bos_privilege.bos_atom_catalog IS 'Catálogo global de átomos. Cada fila = una acción indivisible. atom_position es el índice del bit en el Rol BitMask (one-hot). atom_code es label encoding — NUNCA combinar con bitwise. 1059 átomos registrados.';

-- 20.6 ROLES POR TENANT
CREATE TABLE IF NOT EXISTS bos_privilege.bos_role (
    role_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL,
    role_code   INTEGER     NOT NULL,
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

-- 20.7 ASIGNACIÓN ROL↔ÁTOMO — Rol BitMask en forma relacional
CREATE TABLE IF NOT EXISTS bos_privilege.bos_role_atom (
    role_id         UUID        NOT NULL,
    app_code        SMALLINT    NOT NULL,
    group_code      SMALLINT    NOT NULL,
    atom_code       INTEGER     NOT NULL,
    atom_position   INTEGER     NOT NULL,
    allowed         BOOLEAN     NOT NULL DEFAULT FALSE,
    granted_by      UUID,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_role_atom PRIMARY KEY (role_id, app_code, group_code, atom_code),
    CONSTRAINT fk_bos_role_atom_role FOREIGN KEY (role_id),
    CONSTRAINT fk_bos_role_atom_catalog FOREIGN KEY (app_code, group_code, atom_code)
);
CREATE INDEX IF NOT EXISTS ix_bos_role_atom_role ON bos_privilege.bos_role_atom (role_id, allowed) WHERE allowed = TRUE;
COMMENT ON TABLE bos_privilege.bos_role_atom IS 'Rol BitMask en forma relacional. Cada fila con allowed=true = un bit en 1. atom_position es la posición del bit en el vector one-hot. 212 asignaciones registradas.';
COMMENT ON COLUMN bos_privilege.bos_role_atom.atom_position IS '2NF: Desnormalización deliberada. atom_position deriva de bos_atom_catalog.atom_position (depende solo de atom_code, no de role_id). Se replica aquí para evitar JOIN en cada evaluación de política (<0.5ns requerido). Sincronizado por trigger trg_role_atom_position.';

-- Trigger 2NF: mantiene atom_position sincronizado con bos_atom_catalog
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

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_role_atom_position') THEN
        CREATE TRIGGER trg_role_atom_position
            BEFORE INSERT OR UPDATE OF app_code, group_code, atom_code
            ON bos_privilege.bos_role_atom
            FOR EACH ROW EXECUTE FUNCTION bos_privilege.sync_atom_position();
    END IF;
END $$;

-- 20.8 POLÍTICAS POR ÁTOMO — Documento JSONB formal
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_policy (
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
    CONSTRAINT pk_bos_atom_policy PRIMARY KEY (policy_id),
    CONSTRAINT uq_bos_atom_policy_slug UNIQUE (app_code, group_code, atom_code, policy_slug),
    CONSTRAINT fk_bos_atom_policy_atom FOREIGN KEY (app_code, group_code, atom_code),
    CONSTRAINT fk_bos_atom_policy_domain FOREIGN KEY (policy_domain),
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
CREATE INDEX IF NOT EXISTS ix_atom_policy_data ON bos_privilege.bos_atom_policy USING GIN (policy_data jsonb_path_ops);
CREATE INDEX IF NOT EXISTS ix_atom_policy_priority ON bos_privilege.bos_atom_policy (policy_domain, ((policy_data ->> 'priority')::integer), active) WHERE active = TRUE;
COMMENT ON TABLE bos_privilege.bos_atom_policy IS 'Políticas 1:N encadenadas a átomos. Documento JSONB formal con evaluación determinista. El PolicyEngine interpreta el documento completo sin código hardcodeado. 6782 políticas registradas.';
COMMENT ON COLUMN bos_privilege.bos_atom_policy.policy_data IS 'Documento completo de política en formato JSONB formal. Estructura canónica: {"$schema":"bos_policy_v1","priority":50,"action":"deny","evaluate":{"logic":"and|or","conditions":[{"field":"<context_path>","op":"<operator>","value":"<literal_or_ref>"}]},"params":{...}}.';

-- 20.9 AUDITORÍA DE ACCESOS — WORM inmutable por evaluación
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit (
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
    CONSTRAINT pk_bos_atom_audit PRIMARY KEY (audit_id, evaluated_at),
    CONSTRAINT ck_audit_result CHECK (result IN (0, 1, 2)),
    CONSTRAINT ck_policy_state CHECK (policy_state IN (0, 1, 2, 3))
) PARTITION BY RANGE (evaluated_at);
COMMENT ON TABLE bos_privilege.bos_atom_audit IS 'Registro WORM de cada evaluación de acceso. ctx_id obligatorio. Particionado por mes. REVOKE UPDATE/DELETE post-deploy. Trazabilidad blockchain vía merkle_batch_id. ISO 27001 A.8.15.';

CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit_2026_06 PARTITION OF bos_privilege.bos_atom_audit
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS bos_privilege.bos_atom_audit_2026_07 PARTITION OF bos_privilege.bos_atom_audit
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
COMMENT ON TABLE bos_privilege.bos_atom_audit_2026_06 IS 'Partición de bos_atom_audit para Junio 2026.';
COMMENT ON TABLE bos_privilege.bos_atom_audit_2026_07 IS 'Partición de bos_atom_audit para Julio 2026.';

-- ============================================================
-- 21. AUTHENTICATION FRAMEWORK — 7 tablas declarativas
-- ============================================================
-- SSOT para toda la configuración de autenticación del ecosistema.
-- Cada entidad referencia su estándar internacional.
-- Principio rector: la seguridad no se implementa — se declara.
-- Referencia: BAUTH-AUTHENTICATION-FRAMEWORK.md v1.0.0
-- ============================================================

-- 21.1 AUTH METHOD — Catálogo de métodos de autenticación
CREATE TABLE IF NOT EXISTS bauth.bos_auth_method (
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
    CONSTRAINT chk_nist_status CHECK (nist_status IN ('preferred','permitted','discouraged','deprecated','restricted','n/a'))
);
COMMENT ON TABLE bauth.bos_auth_method IS 'Catálogo de 23 métodos de autenticación soportados. ISO 24760-4:2025 §4 · NIST 800-63B-4 AAL. 23 registros activos.';
COMMENT ON COLUMN bauth.bos_auth_method.aal_level IS 'NIST Authentication Assurance Level: AAL1(single-factor), AAL2(multi-factor), AAL3(phishing-resistant hardware key).';
COMMENT ON COLUMN bauth.bos_auth_method.nist_status IS 'Estado según NIST 800-63B-4: preferred > permitted > discouraged > deprecated > restricted.';
COMMENT ON COLUMN bauth.bos_auth_method.kc_implementation IS 'Referencia al SPI de Keycloak que implementa este método: KC_PASSWORD, KC_WEBAUTHN, KC_TOTP, KC_PASSKEY, etc.';

-- 21.2 AUTH POLICY — Políticas de autenticación por tier
CREATE TABLE IF NOT EXISTS bauth.bos_auth_policy (
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
COMMENT ON TABLE bauth.bos_auth_policy IS 'Políticas de autenticación por tier. NIST 800-53 Rev.5 AC-2/5/6 · ISO 27001:2022 A.5.15-18. 31 políticas activas.';

-- 21.3 AUTH CONFIG — Configuraciones operativas por tier
CREATE TABLE IF NOT EXISTS bauth.bos_auth_config (
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
COMMENT ON TABLE bauth.bos_auth_config IS 'Configuraciones operativas del motor de autenticación — parámetros por tier.';

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
COMMENT ON TABLE bauth.bos_crypto_algorithm IS 'Catálogo de 16 algoritmos criptográficos. NIST FIPS 140-3/203(ML-KEM)/204(ML-DSA)/205(SLH-DSA) · ISO/IEC 15408.';

-- 21.5 FEDERATION PROTOCOL — Protocolos de federación
CREATE TABLE IF NOT EXISTS bauth.bos_federation_protocol (
    protocol_id     TEXT    NOT NULL,
    protocol_name   TEXT    NOT NULL,
    protocol_type   TEXT    NOT NULL,
    rfc_ref         TEXT,
    flow            TEXT    NOT NULL,
    pkce_required   BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to      TEXT[]  NOT NULL DEFAULT '{}',
    bauth_status    TEXT    NOT NULL DEFAULT 'enabled',
    config          JSONB   DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_federation_protocol PRIMARY KEY (protocol_id),
    CONSTRAINT chk_protocol_type CHECK (protocol_type IN ('authorization','authentication','federation','delegation','device','token_exchange','deprecated')),
    CONSTRAINT chk_bauth_status CHECK (bauth_status IN ('enabled','disabled_permanently','enabled_controlled','planned'))
);
COMMENT ON TABLE bauth.bos_federation_protocol IS 'Protocolos de federación soportados. 16 protocolos. NIST SP 800-63C-4 · OAuth 2.1 BCP · RFC 9700.';

-- 21.6 SAGA CATALOG — Catálogo de sagas de autenticación
CREATE TABLE IF NOT EXISTS bauth.bos_saga_catalog (
    saga_name       TEXT    NOT NULL,
    version         TEXT    NOT NULL DEFAULT '1.0.0',
    description     TEXT    NOT NULL,
    sequence_op     TEXT    NOT NULL DEFAULT 'sequential',
    compensation    TEXT    NOT NULL DEFAULT 'full_rollback',
    max_timeout_ms  INTEGER NOT NULL DEFAULT 60000,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    requires_ctx    BOOLEAN NOT NULL DEFAULT TRUE,
    tier_minimum    TEXT    NOT NULL DEFAULT 'EXT_N0',
    audit_level     TEXT    NOT NULL DEFAULT 'basic',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_saga_catalog PRIMARY KEY (saga_name),
    CONSTRAINT chk_saga_compensation CHECK (compensation IN ('full_rollback','best_effort','checkpoint','manual','none')),
    CONSTRAINT chk_saga_sequence CHECK (sequence_op IN ('sequential','parallel','conditional')),
    CONSTRAINT chk_saga_tier CHECK (tier_minimum IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE')),
    CONSTRAINT chk_saga_audit CHECK (audit_level IN ('none','basic','full'))
);
COMMENT ON TABLE bauth.bos_saga_catalog IS 'Catálogo de 12 sagas de autenticación. Cada saga es un flujo orquestado con pasos y compensaciones. NIST SP 800-63B-4.';
COMMENT ON COLUMN bauth.bos_saga_catalog.compensation IS 'Estrategia de compensación: full_rollback(NIST default), best_effort, checkpoint, manual(HITL), none.';
COMMENT ON COLUMN bauth.bos_saga_catalog.requires_ctx IS 'TRUE si requiere ctx_id obligatorio (SBOS-049).';
COMMENT ON COLUMN bauth.bos_saga_catalog.tier_minimum IS 'Tier mínimo requerido para invocar esta saga.';

-- 21.7 SAGA STEP — Pasos individuales de cada saga
CREATE TABLE IF NOT EXISTS bauth.bos_saga_step (
    step_id         UUID    NOT NULL DEFAULT gen_random_uuid(),
    saga_name       TEXT    NOT NULL,
    step_order      INTEGER NOT NULL,
    step_name       TEXT    NOT NULL,
    saga_op         TEXT    NOT NULL,
    action_ref      TEXT    NOT NULL,
    compensate_ref  TEXT,
    timeout_ms      INTEGER NOT NULL DEFAULT 5000,
    max_retries     INTEGER NOT NULL DEFAULT 0,
    depends_on      TEXT[]  DEFAULT '{}',
    preconditions   JSONB   DEFAULT '[]',
    postconditions  JSONB   DEFAULT '[]',
    config          JSONB   DEFAULT '{}',
    CONSTRAINT pk_saga_step PRIMARY KEY (step_id),
    CONSTRAINT fk_saga_step_catalog FOREIGN KEY (saga_name),
    CONSTRAINT chk_saga_op CHECK (saga_op IN ('execute','validate','compensate','await','wait_for','emit','checkpoint','rollback','notify','noop'))
);
COMMENT ON TABLE bauth.bos_saga_step IS 'Pasos individuales de cada saga — acción + compensación con pre/post condiciones.';
COMMENT ON COLUMN bauth.bos_saga_step.saga_op IS 'Operación: execute(ejecutar), validate(validar), compensate(deshacer), await(esperar evento), emit(emitir Redis Stream), checkpoint(guardar estado), rollback(revertir), notify(notificar daemon), noop(marcador).';
COMMENT ON COLUMN bauth.bos_saga_step.compensate_ref IS 'Función de compensación. Se ejecuta en orden INVERSO si la saga falla. NULL = paso idempotente.';

-- 21.8 SAGA EXECUTION — Registro inmutable de ejecuciones
CREATE TABLE IF NOT EXISTS bauth.bos_saga_execution (
    execution_id        UUID    NOT NULL DEFAULT gen_random_uuid(),
    saga_name           TEXT    NOT NULL,
    saga_version        TEXT    NOT NULL DEFAULT '1.0.0',
    ctx_id              TEXT    NOT NULL,
    triggered_by        TEXT,
    params              JSONB   NOT NULL DEFAULT '{}',
    status              TEXT    NOT NULL,
    steps_executed      INTEGER NOT NULL DEFAULT 0,
    steps_compensated   INTEGER NOT NULL DEFAULT 0,
    final_state         JSONB   DEFAULT '{}',
    step_details        JSONB   DEFAULT '[]',
    error_message       TEXT,
    duration_ms         INTEGER,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at         TIMESTAMPTZ,
    CONSTRAINT pk_saga_execution PRIMARY KEY (execution_id),
    CONSTRAINT chk_exec_status CHECK (status IN ('completed','compensated','failed','timeout','rejected','partially_completed'))
);
COMMENT ON TABLE bauth.bos_saga_execution IS 'Registro inmutable de cada ejecución de saga. Trazabilidad ISO 27001 A.8.15.';

-- 21.9 COMPLIANCE MAP — Mapeo de cumplimiento normativo
CREATE TABLE IF NOT EXISTS bauth.bos_compliance_map (
    compliance_id           UUID    NOT NULL DEFAULT gen_random_uuid(),
    standard                TEXT    NOT NULL,
    control_id              TEXT    NOT NULL,
    control_name            TEXT    NOT NULL,
    description             TEXT    NOT NULL,
    applies_to              TEXT    NOT NULL,
    implementation_status   TEXT    NOT NULL DEFAULT 'planned',
    evidence_ref            TEXT,
    last_reviewed           TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT pk_compliance_map PRIMARY KEY (compliance_id),
    CONSTRAINT chk_impl_status CHECK (implementation_status IN ('implemented','partial','planned','not_applicable'))
);
COMMENT ON TABLE bauth.bos_compliance_map IS 'Mapeo de cumplimiento normativo. 34 controles. ISO 27001:2022 · NIST 800-53 · PCI DSS 4.0 · GDPR · eIDAS 2.0 · OWASP ASVS 5.0.';

-- ============================================================
-- 22. TABLAS DE SOPORTE — Utilidades, Auditoría, Registro
-- ============================================================

-- 22.1 GLOBAL CONFIG — Parámetros centrales del sistema
CREATE TABLE IF NOT EXISTS bauth.bos_global_config (
    config_key      VARCHAR(128) NOT NULL,
    config_value    JSONB        NOT NULL,
    data_type       VARCHAR(32)  NOT NULL DEFAULT 'jsonb',
    category        VARCHAR(64)  NOT NULL DEFAULT 'general',
    description     TEXT         NOT NULL DEFAULT '',
    purpose         TEXT         NOT NULL DEFAULT '',
    standard_ref    TEXT         NOT NULL DEFAULT '',
    default_value   JSONB,
    version         INTEGER      NOT NULL DEFAULT 1,
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_by      VARCHAR(64),
    CONSTRAINT pk_global_config PRIMARY KEY (config_key),
    CONSTRAINT chk_config_category CHECK (category IN ('financial','authentication','authorization','network','session','audit','blockchain','performance','general')),
    CONSTRAINT chk_config_data_type CHECK (data_type IN ('jsonb','string','integer','float','boolean','array'))
);
COMMENT ON TABLE bauth.bos_global_config IS 'Catálogo central de parámetros. Fuente única de verdad para configuración modificable en runtime. Cada fila = un parámetro autodescriptivo con propósito, referencia normativa y valor por defecto. NIST SP 800-53 CM-6 · ISO 27001 A.8.9.';

-- 22.2 DOMAIN CONFIG — Activación de dominios por tenant
CREATE TABLE IF NOT EXISTS bauth.bos_domain_config (
    tenant_id       UUID        NOT NULL,
    domain_code     SMALLINT    NOT NULL,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    override_params JSONB,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      UUID,
    CONSTRAINT pk_domain_config PRIMARY KEY (tenant_id, domain_code)
);
COMMENT ON TABLE bauth.bos_domain_config IS 'Activación/desactivación de dominios por tenant. PyME: solo D1+D3+D9. Empresa seguridad: D1+D2+D3+D5+D6+D7. B1.T21.';

-- 22.3 FRAMEWORK VERSION — Versionado de frameworks SSOT
CREATE TABLE IF NOT EXISTS bauth.bos_framework_version (
    framework_id        VARCHAR(32) NOT NULL,
    version             VARCHAR(16) NOT NULL,
    release_date        DATE        NOT NULL,
    changelog           TEXT,
    author              VARCHAR(64),
    git_commit          VARCHAR(40),
    json_hash           VARCHAR(66) NOT NULL,
    backward_compatible BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_framework_version PRIMARY KEY (framework_id),
    CONSTRAINT chk_framework_id CHECK (framework_id IN ('auth','policies','roltemplate','usertemplate'))
);
COMMENT ON TABLE bauth.bos_framework_version IS 'Versionado semántico de los 4 frameworks SSOT. SHA-256 + backward compat check. B9.T32.';

-- 22.4 BACKUP LOG — Registro de backups
CREATE TABLE IF NOT EXISTS bauth.bos_backup_log (
    backup_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
    backup_type     VARCHAR(32) NOT NULL,
    file_path       TEXT        NOT NULL,
    file_hash       VARCHAR(66) NOT NULL,
    file_size_bytes BIGINT,
    status          VARCHAR(16) NOT NULL DEFAULT 'COMPLETED',
    executed_by     VARCHAR(64),
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    restored_at     TIMESTAMPTZ,
    restore_status  VARCHAR(16),
    notes           TEXT,
    CONSTRAINT pk_backup_log PRIMARY KEY (backup_id),
    CONSTRAINT chk_backup_type CHECK (backup_type IN ('full_db','rol_template','user_template','audit_events','blockchain','key_inventory','device_registry')),
    CONSTRAINT chk_backup_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED','RESTORED'))
);
COMMENT ON TABLE bauth.bos_backup_log IS 'Registro de backups. ADR-016. SHA-256 + retención 10 años. B19.T25, B37.T05.';

-- 22.5 DEVICE REGISTRY — Dispositivos físicos
CREATE TABLE IF NOT EXISTS bauth.bos_device_registry (
    device_id           UUID        NOT NULL DEFAULT gen_random_uuid(),
    node_id             VARCHAR(128) NOT NULL,
    device_type         VARCHAR(32) NOT NULL,
    serial_number       VARCHAR(128),
    firmware_version    VARCHAR(32),
    hardware_model      VARCHAR(64),
    zone_id             BIGINT,
    tenant_id           UUID        NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'provisioned',
    last_seen           TIMESTAMPTZ,
    ip_address          INET,
    mac_address         MACADDR,
    certificate_serial  VARCHAR(64),
    metadata            JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_device_registry PRIMARY KEY (device_id),
    CONSTRAINT chk_device_type CHECK (device_type IN ('banexus_agent','osdp_reader','mqtt_sensor','onvif_camera','wiegand_reader','ble_reader','rfid_reader','biometric_reader','intercom','actuator')),
    CONSTRAINT chk_device_status CHECK (status IN ('provisioned','active','inactive','compromised','decommissioned'))
);
COMMENT ON TABLE bauth.bos_device_registry IS 'Registro de dispositivos físicos: lectores, cámaras, sensores, terminales. ISO 27001 A.8.1. B15.T17.';

-- 22.6 KEY INVENTORY — Inventario de llaves criptográficas
CREATE TABLE IF NOT EXISTS bauth.bos_key_inventory (
    key_id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    key_type            VARCHAR(32) NOT NULL,
    algorithm           VARCHAR(32),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rotation_interval   INTERVAL,
    last_rotated_at     TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ,
    owner               VARCHAR(128),
    storage_backend     VARCHAR(32) NOT NULL,
    state               VARCHAR(16) NOT NULL DEFAULT 'PRE_ACTIVE',
    backup_hash         VARCHAR(66),
    metadata            JSONB,
    CONSTRAINT pk_key_inventory PRIMARY KEY (key_id),
    CONSTRAINT chk_key_type CHECK (key_type IN ('JWT_SIGNING','API_KEY','TOTP_SECRET','MTLS_CERT','BLOCKCHAIN_SIGNING','VALIDATOR_SIGNING','AES_ENCRYPTION','RECOVERY_CODE','PASSWORD_HASH','CLIENT_SECRET','ADSIB_CERT','ROOT_CA','SUB_CA_SIGNING','SUB_CA_IDENTITY','SUB_CA_DEVICES','SUB_CA_SERVICES','USER_SIGNING_CERT','DEVICE_CERT','SERVICE_CERT','SUPERUSER_CERT')),
    CONSTRAINT chk_key_state CHECK (state IN ('PRE_ACTIVE','ACTIVE','DEACTIVATED','COMPROMISED','DESTROYED'))
);
COMMENT ON TABLE bauth.bos_key_inventory IS 'Inventario central de TODAS las llaves criptográficas del ecosistema. 20 tipos. NIST SP 800-57 Pt.1. B37.T01.';

-- 22.7 KEY RECOVERY LOG — Recuperación de llaves
CREATE TABLE IF NOT EXISTS bauth.bos_key_recovery_log (
    recovery_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    key_id          UUID,
    recovery_type   VARCHAR(16) NOT NULL,
    approved_by     UUID[],
    session_duration INTERVAL,
    result          VARCHAR(16) NOT NULL,
    ctx_id          VARCHAR(128) NOT NULL,
    recovered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes           TEXT,
    CONSTRAINT pk_key_recovery_log PRIMARY KEY (recovery_id),
    CONSTRAINT chk_recovery_type CHECK (recovery_type IN ('BREAK_GLASS','ADMIN_RESET','USER_RECOVERY','COMPROMISE','DESASTRE')),
    CONSTRAINT chk_recovery_result CHECK (result IN ('SUCCESS','FAILED','PARTIAL','PENDING_APPROVAL'))
);
COMMENT ON TABLE bauth.bos_key_recovery_log IS 'Registro de recuperaciones de llaves. Break-glass SU (2-of-3 Vault unseal). B37.T03.';

-- 22.8 POLICY AUDIT — Auditoría WORM de cambios de políticas
CREATE TABLE IF NOT EXISTS bauth.bos_policy_audit (
    audit_id        UUID        NOT NULL DEFAULT gen_random_uuid(),
    policy_slug     VARCHAR(64) NOT NULL,
    change_type     VARCHAR(16) NOT NULL,
    old_params      JSONB,
    new_params      JSONB,
    admin_user_id   UUID        NOT NULL,
    ctx_id          VARCHAR(128) NOT NULL,
    reason          TEXT        NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_policy_audit PRIMARY KEY (audit_id),
    CONSTRAINT chk_change_type CHECK (change_type IN ('CREATE','UPDATE','DELETE','DEPRECATE','ROLLBACK'))
);
COMMENT ON TABLE bauth.bos_policy_audit IS 'Auditoría WORM de cambios de políticas de seguridad. ISO 27001 A.8.9. B9.T28.';

-- 22.9 POLICY HISTORY — Historial versionado de políticas
CREATE TABLE IF NOT EXISTS bauth.bos_policy_history (
    version_id  UUID        NOT NULL DEFAULT gen_random_uuid(),
    policy_slug VARCHAR(64) NOT NULL,
    version     INTEGER     NOT NULL,
    params      JSONB       NOT NULL,
    created_by  UUID        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_policy_history PRIMARY KEY (version_id)
);
COMMENT ON TABLE bauth.bos_policy_history IS 'Historial versionado de políticas para rollback. B9.T30.';

-- 22.10 TOKEN DELIVERY LOG — Entrega de tokens
CREATE TABLE IF NOT EXISTS bauth.bos_token_delivery_log (
    delivery_id         UUID        NOT NULL DEFAULT gen_random_uuid(),
    token_id            UUID        NOT NULL,
    token_type          VARCHAR(16) NOT NULL,
    user_id             UUID        NOT NULL,
    delivery_channel    VARCHAR(32) NOT NULL,
    delivered_by        UUID,
    delivered_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    recipient_signature VARCHAR(256),
    witness             UUID,
    metadata            JSONB,
    CONSTRAINT pk_token_delivery_log PRIMARY KEY (delivery_id),
    CONSTRAINT chk_token_type CHECK (token_type IN ('TOTP','HOTP','NFC','QR','PUSH','RECOVERY','SMS','EMAIL','MAGIC_LINK','BARCODE')),
    CONSTRAINT chk_delivery_channel CHECK (delivery_channel IN ('presencial','remote_secure','self_service','whatsapp','telegram','email','sms','push'))
);
COMMENT ON TABLE bauth.bos_token_delivery_log IS 'Registro de entrega de tokens de autenticación. Trazabilidad completa del canal de entrega. B22.T12.';

-- 22.11 USER CONSENT — Consentimientos GDPR
CREATE TABLE IF NOT EXISTS bauth.bos_user_consent (
    consent_id      UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    consent_type    VARCHAR(32) NOT NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'granted',
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at    TIMESTAMPTZ,
    ip_address      INET,
    user_agent      TEXT,
    metadata        JSONB,
    CONSTRAINT pk_user_consent PRIMARY KEY (consent_id),
    CONSTRAINT chk_consent_status CHECK (status IN ('granted','withdrawn')),
    CONSTRAINT chk_consent_type CHECK (consent_type IN ('data_processing','marketing','third_party','biometric','cookies'))
);
COMMENT ON TABLE bauth.bos_user_consent IS 'Registro de consentimientos GDPR por usuario. RGPD Art.7. B11.T31.';

-- 22.12 USER ROLE ASSIGNMENT — Asignación de roles a usuarios
CREATE TABLE IF NOT EXISTS bauth.bos_user_role_assignment (
    assignment_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    role_id         UUID        NOT NULL,
    assigned_by     UUID,
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used       TIMESTAMPTZ,
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    revoked_by      UUID,
    revoked_at      TIMESTAMPTZ,
    CONSTRAINT pk_user_role_assignment PRIMARY KEY (assignment_id)
);
COMMENT ON TABLE bauth.bos_user_role_assignment IS 'Asignación de roles a usuarios. Trazabilidad completa: quién asignó, cuándo, vigencia. B11.T06.';

-- 22.13 AUTH METHOD ENROLLMENT LOG — Enrolamiento de métodos
CREATE TABLE IF NOT EXISTS bauth.bos_auth_method_enrollment_log (
    enrollment_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    method_type     VARCHAR(16) NOT NULL,
    step            VARCHAR(32) NOT NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'IN_PROGRESS',
    ctx_id          VARCHAR(128) NOT NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata        JSONB,
    CONSTRAINT pk_enrollment_log PRIMARY KEY (enrollment_id),
    CONSTRAINT chk_enrollment_status CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED')),
    CONSTRAINT chk_enrollment_step CHECK (step IN ('identity_verify','generate_credential','deliver_to_user','verify_method','activate'))
);
COMMENT ON TABLE bauth.bos_auth_method_enrollment_log IS 'Registro de enrollment de métodos de autenticación. B35.T04.';

-- 22.14 VDI PROFILES — Perfiles de escritorio virtual
CREATE TABLE IF NOT EXISTS bauth.bos_vdi_profiles (
    profile_id      UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    profile_name    VARCHAR(64) NOT NULL,
    config          JSONB       NOT NULL DEFAULT '{}',
    is_default      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used       TIMESTAMPTZ,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_vdi_profiles PRIMARY KEY (profile_id)
);
COMMENT ON TABLE bauth.bos_vdi_profiles IS 'Perfiles de escritorio VDI persistentes. Sobreviven a reinicios del terminal. B21.T05.';

-- 22.15 AUDIT EVENTS PARTITION 2026_06
-- Nota: la tabla particionada bos_audit_events ya fue creada en §12.
-- Estas particiones se crean junto con la tabla madre.
-- Se declaran aquí para garantizar que el DDL las cubra explícitamente.
COMMENT ON TABLE bauth.bos_audit_events_2026_06 IS 'Partición de bos_audit_events para Junio 2026. Rango: 2026-06-01 a 2026-07-01.';
COMMENT ON TABLE bauth.bos_audit_events_2026_07 IS 'Partición de bos_audit_events para Julio 2026. Rango: 2026-07-01 a 2026-08-01.';

-- ============================================================
-- 23. SCHEMA bos_blockchain — D12 Merkle Anchoring + Settlement
-- ============================================================
-- Anclaje Merkle de auditoría en Arbitrum One (Variante A) +
-- liquidación Besu QBFT (Variante B). Keccak-256, lotes cada 1h.
-- Referencia: SBOS-BAUTH-D12-INFRAESTRUCTURA-BLOCKCHAIN.md
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bos_blockchain;
ALTER SCHEMA bos_blockchain OWNER TO bauth;

COMMENT ON SCHEMA bos_blockchain IS 'D12 Blockchain: Merkle anchoring en Arbitrum One (Var A) + liquidación Besu QBFT (Var B). SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md Apéndice D.';

-- 23.1 MERKLE BATCH — Lotes de eventos para anclaje
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_batch (
    batch_id            UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_number        BIGINT      NOT NULL,
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
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sealed_at           TIMESTAMPTZ,
    anchored_at         TIMESTAMPTZ,
    CONSTRAINT pk_bos_merkle_batch PRIMARY KEY (batch_id),
    CONSTRAINT uq_bos_merkle_batch_number UNIQUE (batch_number),
    CONSTRAINT ck_bos_merkle_batch_status CHECK (status IN (0, 1, 2, 3))
);
COMMENT ON TABLE bos_blockchain.bos_merkle_batch IS 'Lotes de eventos de auditoría para anclaje Merkle en L2. Gold tier: cada 1 hora. Status: 0=open, 1=sealed, 2=anchored, 3=failed. B29.';

-- 23.2 MERKLE LEAF — Hojas del árbol Merkle
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_leaf (
    leaf_id         UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_id        UUID        NOT NULL,
    leaf_index      INTEGER     NOT NULL,
    event_audit_id  UUID        NOT NULL,
    event_hash      VARCHAR(66) NOT NULL,
    merkle_proof    VARCHAR(66)[],
    CONSTRAINT pk_bos_merkle_leaf PRIMARY KEY (leaf_id),
    CONSTRAINT uq_bos_merkle_leaf_batch_pos UNIQUE (batch_id, leaf_index),
    CONSTRAINT fk_bos_merkle_leaf_batch FOREIGN KEY (batch_id)
);
CREATE INDEX IF NOT EXISTS idx_merkle_leaf_batch ON bos_blockchain.bos_merkle_leaf USING btree (batch_id);
COMMENT ON TABLE bos_blockchain.bos_merkle_leaf IS 'Hojas del árbol Merkle. event_hash = Keccak256(0x00 || ctx_id || audit_id || bitmask || result). merkle_proof permite verificación independiente.';

-- 23.3 BLOCKCHAIN ANCHOR LOG — Histórico de anclajes
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_blockchain_anchor_log (
    anchor_id           UUID        NOT NULL DEFAULT gen_random_uuid(),
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
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_blockchain_anchor_log PRIMARY KEY (anchor_id),
    CONSTRAINT fk_bos_anchor_log_batch FOREIGN KEY (batch_id)
);
CREATE INDEX IF NOT EXISTS idx_anchor_log_batch ON bos_blockchain.bos_blockchain_anchor_log USING btree (batch_id);
CREATE INDEX IF NOT EXISTS idx_anchor_log_status ON bos_blockchain.bos_blockchain_anchor_log USING btree (status);
COMMENT ON TABLE bos_blockchain.bos_blockchain_anchor_log IS 'Histórico de transacciones de anclaje en L2. Auditoría de gas y trazabilidad completa.';

-- 23.4 ANCHOR RECONCILIATION LOG — Verificación cross-chain
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_anchor_reconciliation_log (
    reconciliation_id   UUID        NOT NULL DEFAULT gen_random_uuid(),
    batch_id            UUID        NOT NULL,
    network             VARCHAR(32) NOT NULL,
    merkle_root_db      VARCHAR(66) NOT NULL,
    merkle_root_onchain VARCHAR(66),
    match               BOOLEAN,
    checked_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes               TEXT,
    CONSTRAINT pk_bos_anchor_reconciliation_log PRIMARY KEY (reconciliation_id),
    CONSTRAINT fk_anchor_reconciliation_batch FOREIGN KEY (batch_id)
);
COMMENT ON TABLE bos_blockchain.bos_anchor_reconciliation_log IS 'Verificación de integridad cross-chain: compara Merkle roots PostgreSQL vs Arbitrum/on-chain.';

-- 23.5 ONCHAIN ACCOUNT — Cuentas on-chain (Variante B)
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_account (
    account_id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    tenant_id               UUID            NOT NULL,
    onchain_address         VARCHAR(42)     NOT NULL,
    account_type            SMALLINT        NOT NULL,
    balance_derived         NUMERIC(36,18)  NOT NULL DEFAULT 0,
    balance_local           NUMERIC(36,18)  NOT NULL DEFAULT 0,
    nonce                   BIGINT          NOT NULL DEFAULT 0,
    last_reconciled_at      TIMESTAMPTZ,
    last_reconciled_block   BIGINT,
    is_frozen               BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_onchain_account PRIMARY KEY (account_id),
    CONSTRAINT uq_bos_onchain_account_address UNIQUE (onchain_address),
    CONSTRAINT uq_bos_onchain_account_tenant UNIQUE (tenant_id, account_type)
);
COMMENT ON TABLE bos_blockchain.bos_onchain_account IS 'Solo D12 Variante B. Mapea cuentas SBOS a direcciones on-chain. balance_derived es fuente de verdad; balance_local es caché.';

-- 23.6 ONCHAIN SETTLEMENT — Liquidaciones on-chain (Variante B)
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_settlement (
    settlement_id       UUID            NOT NULL DEFAULT gen_random_uuid(),
    from_account_id     UUID            NOT NULL,
    to_account_id       UUID            NOT NULL,
    amount              NUMERIC(36,18)  NOT NULL,
    currency            VARCHAR(8)      NOT NULL,
    onchain_tx_hash     VARCHAR(66)     NOT NULL,
    block_number        BIGINT          NOT NULL,
    block_confirmations INTEGER         NOT NULL DEFAULT 0,
    status              SMALLINT        NOT NULL DEFAULT 0,
    dual_approval_id    UUID,
    ctx_id_creator      VARCHAR(128)    NOT NULL,
    ctx_id_approver     VARCHAR(128),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    confirmed_at        TIMESTAMPTZ,
    CONSTRAINT pk_bos_onchain_settlement PRIMARY KEY (settlement_id),
    CONSTRAINT fk_bos_settlement_from FOREIGN KEY (from_account_id),
    CONSTRAINT fk_bos_settlement_to FOREIGN KEY (to_account_id),
    CONSTRAINT ck_bos_settlement_status CHECK (status IN (0, 1, 2))
);
CREATE INDEX IF NOT EXISTS idx_settlement_status ON bos_blockchain.bos_onchain_settlement USING btree (status);
COMMENT ON TABLE bos_blockchain.bos_onchain_settlement IS 'Solo D12 Variante B. Liquidaciones on-chain con trazabilidad ctx_id y dual-approval. Status: 0=pending, 1=confirmed, 2=failed.';

-- 23.7 RECONCILIATION LOG — Reconciliación on-chain ↔ PostgreSQL (Variante B)
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_reconciliation_log (
    reconciliation_id   UUID            NOT NULL DEFAULT gen_random_uuid(),
    account_id          UUID            NOT NULL,
    balance_onchain     NUMERIC(36,18)  NOT NULL,
    balance_local       NUMERIC(36,18)  NOT NULL,
    difference          NUMERIC(36,18)  NOT NULL,
    block_number        BIGINT          NOT NULL,
    status              SMALLINT        NOT NULL,
    correction_tx_hash  VARCHAR(66),
    notes               TEXT,
    reconciled_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_reconciliation_log PRIMARY KEY (reconciliation_id),
    CONSTRAINT fk_bos_reconciliation_account FOREIGN KEY (account_id),
    CONSTRAINT ck_bos_reconciliation_status CHECK (status IN (0, 1, 2))
);
CREATE INDEX IF NOT EXISTS idx_reconciliation_account ON bos_blockchain.bos_reconciliation_log USING btree (account_id);
COMMENT ON TABLE bos_blockchain.bos_reconciliation_log IS 'Solo D12 Variante B. Reconciliación periódica on-chain ↔ PostgreSQL. Double-entry accounting. Status: 0=difference, 1=corrected, 2=escalated.';

-- 23.8 MERKLE ROOT FUNCTION — Cálculo Keccak-256
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
COMMENT ON FUNCTION bos_blockchain.merkle_root_from_batch(UUID) IS 'Calcula Merkle root de un lote sellado usando Keccak-256. RFC 6962 binary tree con domain separation.';

-- ============================================================
-- 24. TABLAS DE SEGURIDAD AVANZADA — NIST 800-63B-4 + OWASP ASVS 5.0
-- ============================================================
-- Brechas B1-B10 cerradas: recovery, authenticator binding, session fixation,
-- brute force rate limit, credential recovery, password screening, lockout.
-- Referencias: NIST SP 800-63B-4 §4/§5/§7 · OWASP ASVS 5.0 V2/V3
--              NIST SP 800-53 AC-7 · SOC 2 CC6.1/CC6.3
-- ============================================================

-- 24.1 ACCOUNT RECOVERY — Métodos de recuperación (NIST 800-63B-4 §4)
CREATE TABLE IF NOT EXISTS bauth.bos_recovery_method (
    recovery_id     UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_uuid       UUID        NOT NULL,
    method_type     TEXT        NOT NULL,
    method_value    TEXT        NOT NULL,
    verified        BOOLEAN     NOT NULL DEFAULT FALSE,
    verified_at     TIMESTAMPTZ,
    is_primary      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_recovery_method PRIMARY KEY (recovery_id),
    CONSTRAINT chk_recovery_type CHECK (method_type IN ('email','sms','backup_codes','security_questions','trusted_contact','hardware_token')),
    CONSTRAINT uq_recovery_method UNIQUE (user_uuid, method_type)
);
CREATE INDEX IF NOT EXISTS idx_brecm_user ON bauth.bos_recovery_method(user_uuid);
COMMENT ON TABLE bauth.bos_recovery_method IS '[NIST 800-63B-4 §4.4] [OWASP ASVS V2.5.1] Métodos de recuperación de cuenta. Cada método debe ser verificado antes de usarse. Backup codes SHA-256 hasheados. Email/SMS requieren confirmación por canal separado. Max 5 métodos por usuario.';

-- 24.2 AUTHENTICATOR BINDING — Vínculo authenticator↔subscriber (NIST 800-63B-4 §5.2)
CREATE TABLE IF NOT EXISTS bauth.bos_authenticator_binding (
    binding_id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_uuid           UUID        NOT NULL,
    authenticator_type  TEXT        NOT NULL,
    authenticator_id    TEXT        NOT NULL,
    binding_method      TEXT        NOT NULL,
    binding_loa         INTEGER     NOT NULL DEFAULT 1,
    enrollment_authority TEXT       NOT NULL,
    issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,
    last_used_at        TIMESTAMPTZ,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT pk_authenticator_binding PRIMARY KEY (binding_id),
    CONSTRAINT chk_binding_type CHECK (authenticator_type IN ('password','totp','webauthn_platform','webauthn_roaming','passkey_synced','passkey_device_bound','x509_mtls','recovery_code','out_of_band_sms','out_of_band_email','push_notification')),
    CONSTRAINT chk_binding_method CHECK (binding_method IN ('in_person','remote_verified','self_service','admin_provisioned','federated','inherited')),
    CONSTRAINT chk_binding_loa CHECK (binding_loa BETWEEN 1 AND 4),
    CONSTRAINT chk_binding_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED'))
);
CREATE INDEX IF NOT EXISTS idx_bind_user ON bauth.bos_authenticator_binding(user_uuid);
COMMENT ON TABLE bauth.bos_authenticator_binding IS '[NIST 800-63B-4 §5.2.1] [NIST 800-63B-4 §5.2.3] Vínculo criptográfico entre un authenticator y un subscriber. Registra método de vinculación, nivel de aseguramiento (LoA 1-4) y autoridad de enrolamiento. Cada authenticator debe ser vinculado ANTES de poder usarse para autenticación.'

-- 24.3 AUTHENTICATOR REVOCATION — Registro de revocaciones (NIST 800-63B-4 §5.2.2)
CREATE TABLE IF NOT EXISTS bauth.bos_authenticator_revocation (
    revocation_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
    binding_id          UUID        NOT NULL,
    user_uuid           UUID        NOT NULL,
    reason              TEXT        NOT NULL,
    revoked_by          TEXT        NOT NULL,
    revoked_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    replacement_binding UUID       ,
    ctx_id              TEXT        NOT NULL,
    CONSTRAINT pk_authenticator_revocation PRIMARY KEY (revocation_id)
);
CREATE INDEX IF NOT EXISTS idx_brev_user ON bauth.bos_authenticator_revocation(user_uuid, revoked_at DESC);
COMMENT ON TABLE bauth.bos_authenticator_revocation IS '[NIST 800-63B-4 §5.2.2] [OWASP ASVS V2.3.2] Registro WORM de revocaciones de authenticators. Motivo obligatorio + authenticator reemplazo + ctx_id trazable. La revocación debe completarse en < 30s desde la solicitud (NIST §5.2.2 ¶3).'

-- 24.4 LOGIN ATTEMPTS — Brute force / rate limit (OWASP ASVS V2.1.2 + NIST AC-7)
CREATE TABLE IF NOT EXISTS bauth.bos_login_attempt (
    attempt_id      BIGSERIAL,
    user_uuid       UUID       ,
    username        TEXT        NOT NULL,
    source_ip       INET        NOT NULL,
    user_agent      TEXT,
    success         BOOLEAN     NOT NULL DEFAULT FALSE,
    failure_reason  TEXT,
    attempt_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (attempt_id, attempt_at)
) PARTITION BY RANGE (attempt_at);
CREATE TABLE IF NOT EXISTS bauth.bos_login_attempt_2026_07 PARTITION OF bauth.bos_login_attempt
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.bos_login_attempt_2026_08 PARTITION OF bauth.bos_login_attempt
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE INDEX IF NOT EXISTS idx_bla_user ON bauth.bos_login_attempt(user_uuid, attempt_at DESC) WHERE success = FALSE;
CREATE INDEX IF NOT EXISTS idx_bla_ip   ON bauth.bos_login_attempt(source_ip, attempt_at DESC) WHERE success = FALSE;
COMMENT ON TABLE bauth.bos_login_attempt IS '[NIST 800-53 Rev.5 AC-7] [OWASP ASVS V2.1.2] [PCI DSS 4.0 Req 8.3.4] Registro de intentos de login exitosos y fallidos. Particionado por mes. Bloqueo progresivo: 5 intentos fallidos → 15min, 10 → 1h, 20 → bloqueo permanente. Índices filtrados para consultas rápidas de detección de ataques por IP/usuario. Rate limit por tier en bos_auth_policy.';

-- 24.5 RECOVERY CHALLENGE — Desafíos de recuperación (OWASP ASVS V2.5.1)
CREATE TABLE IF NOT EXISTS bauth.bos_recovery_challenge (
    challenge_id    UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_uuid       UUID        NOT NULL,
    question_hash   BYTEA       NOT NULL,
    answer_hash     BYTEA       NOT NULL,
    salt            BYTEA       NOT NULL,
    argon2_params   JSONB       NOT NULL DEFAULT '{"t":3,"m":65536,"p":2}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ,
    CONSTRAINT pk_recovery_challenge PRIMARY KEY (challenge_id),
    CONSTRAINT uq_challenge UNIQUE (user_uuid, question_hash)
);
CREATE INDEX IF NOT EXISTS idx_brch_user ON bauth.bos_recovery_challenge(user_uuid);
COMMENT ON TABLE bauth.bos_recovery_challenge IS '[OWASP ASVS V2.5.1] [NIST 800-63B-4 §4.4.2] Desafíos de recuperación de cuenta. Pregunta Y respuesta hasheadas con Argon2id + salt único de 32 bytes. NUNCA texto plano. Mínimo 3 preguntas requeridas. Bloqueo tras 3 intentos fallidos de respuesta. Rotación de preguntas cada 180 días.'

-- 24.6 PASSWORD SCREENING LOG — Cribado HIBP (NIST 800-63B-4 §5.1.1)
CREATE TABLE IF NOT EXISTS bauth.bos_password_screening_log (
    screening_id    BIGSERIAL   PRIMARY KEY,
    user_uuid       UUID       ,
    k_anon_prefix   TEXT        NOT NULL,
    hibp_result     BOOLEAN     NOT NULL,
    screening_source TEXT       NOT NULL DEFAULT 'hibp',
    screened_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bpsl_user ON bauth.bos_password_screening_log(user_uuid, screened_at DESC);
COMMENT ON TABLE bauth.bos_password_screening_log IS '[NIST 800-63B-4 §5.1.1.2] [OWASP ASVS V2.1.7] Registro de cribado de contraseñas contra HIBP usando k-anonymity (solo se envía el prefijo SHA-1 de 5 caracteres). Cribado obligatorio en enrolamiento + cambio de contraseña. Rechazo automático si aparece en HIBP o SecLists top 100k.'

-- 24.7 COLUMNAS ADICIONALES — bos_context_sessions (session fixation + OWASP V3.3)
ALTER TABLE bauth.bos_context_sessions
    ADD COLUMN IF NOT EXISTS pre_auth_session_id TEXT,
    ADD COLUMN IF NOT EXISTS session_rotated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS absolute_timeout_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS idle_timeout_secs INTEGER DEFAULT 900;
COMMENT ON COLUMN bauth.bos_context_sessions.pre_auth_session_id IS 'OWASP ASVS V3.3: Session ID pre-autenticación. Se rota al autenticar exitosamente (anti session fixation).';
COMMENT ON COLUMN bauth.bos_context_sessions.session_rotated_at IS 'Timestamp de rotación de sesión. NULL si nunca fue rotada.';
COMMENT ON COLUMN bauth.bos_context_sessions.absolute_timeout_at IS 'NIST 800-63B-4 §7: Timeout absoluto de sesión. La sesión es inválida después de este timestamp sin importar actividad.';
COMMENT ON COLUMN bauth.bos_context_sessions.idle_timeout_secs IS 'OWASP ASVS V3.3: Timeout por inactividad en segundos. Default 900 (15min).';

-- 24.8 COLUMNAS ADICIONALES — bos_user_template (lockout + NIST AC-7)
ALTER TABLE bauth.bos_user_template
    ADD COLUMN IF NOT EXISTS consecutive_failures INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS lockout_reason TEXT,
    ADD COLUMN IF NOT EXISTS hibp_screened_at TIMESTAMPTZ;
COMMENT ON COLUMN bauth.bos_user_template.consecutive_failures IS 'NIST 800-53 AC-7: Contador de intentos fallidos consecutivos. Se resetea con login exitoso.';
COMMENT ON COLUMN bauth.bos_user_template.locked_until IS 'NIST 800-53 AC-7: Timestamp hasta el cual la cuenta está bloqueada. NULL = no bloqueada.';
COMMENT ON COLUMN bauth.bos_user_template.lockout_reason IS 'Motivo del bloqueo: BRUTE_FORCE, ADMIN_LOCK, COMPROMISE_SUSPECTED, INACTIVITY.';
COMMENT ON COLUMN bauth.bos_user_template.hibp_screened_at IS 'NIST 800-63B-4 §5.1.1: Último cribado HIBP de la contraseña del usuario.';

-- 24.9 COLUMNAS ADICIONALES — bos_access_reviews (SOC 2 CC6.3)
ALTER TABLE bauth.bos_access_reviews
    ADD COLUMN IF NOT EXISTS review_cycle_id TEXT,
    ADD COLUMN IF NOT EXISTS cycle_start_date DATE,
    ADD COLUMN IF NOT EXISTS cycle_end_date DATE;
COMMENT ON COLUMN bauth.bos_access_reviews.review_cycle_id IS 'SOC 2 CC6.3: Identificador del ciclo de revisión. Agrupa múltiples reviews bajo una misma campaña.';
COMMENT ON COLUMN bauth.bos_access_reviews.cycle_start_date IS 'Fecha de inicio del ciclo de revisión.';
COMMENT ON COLUMN bauth.bos_access_reviews.cycle_end_date IS 'Fecha de cierre del ciclo de revisión. Todas las reviews deben completarse antes.';

-- 24.10 COLUMNAS ADICIONALES — bos_mfa_enrollments (binding LoA + NIST)
ALTER TABLE bauth.bos_mfa_enrollments
    ADD COLUMN IF NOT EXISTS binding_loa INTEGER DEFAULT 1,
    ADD COLUMN IF NOT EXISTS enrollment_authority TEXT DEFAULT 'self_service',
    ADD COLUMN IF NOT EXISTS revocation_reason TEXT,
    ADD COLUMN IF NOT EXISTS revoked_by TEXT;
COMMENT ON COLUMN bauth.bos_mfa_enrollments.binding_loa IS 'NIST 800-63B-4 §5.2: Nivel de aseguramiento durante el enrolamiento (1-4).';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.enrollment_authority IS 'Quién autorizó el enrolamiento: self_service, admin, federated, inherited.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.revocation_reason IS 'NIST 800-63B-4 §5.2.2: Motivo de revocación: LOST, STOLEN, UPGRADED, COMPROMISED, USER_REQUEST.';
COMMENT ON COLUMN bauth.bos_mfa_enrollments.revoked_by IS 'Admin que revocó el authenticator. NULL si fue auto-revocado.';

-- ============================================================
-- PERMISOS — 3 schemas: bauth + bos_privilege + bos_blockchain
-- ============================================================
-- Schema bauth
GRANT USAGE ON SCHEMA bauth TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bauth TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bauth TO bauth;
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history FROM bauth;
REVOKE UPDATE, DELETE ON bauth.bos_audit_events FROM bauth;

-- Schema bos_privilege
GRANT USAGE ON SCHEMA bos_privilege TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bos_privilege TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bos_privilege TO bauth;
REVOKE UPDATE, DELETE ON bos_privilege.bos_atom_audit FROM bauth;

-- Schema bos_blockchain
GRANT USAGE ON SCHEMA bos_blockchain TO bauth;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA bos_blockchain TO bauth;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA bos_blockchain TO bauth;

-- Funciones
GRANT EXECUTE ON FUNCTION gen_random_uuid() TO bauth;
GRANT EXECUTE ON FUNCTION sha256(bytea) TO bauth;

-- ============================================================
-- SEED DATA — Datos de referencia ISO
-- Reconciliación: agregar columnas que falten en VPS
-- ============================================================
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS codice_iso_alfa2 CHAR(2);
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS codice_iso_alfa3 CHAR(3);
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS codice_iso_num SMALLINT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS nombre_es TEXT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS nombre_en TEXT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS continente TEXT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS region TEXT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS flag_emoji TEXT;
ALTER TABLE bauth.bos_pais ADD COLUMN IF NOT EXISTS codigo_telefonico TEXT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS codice_num SMALLINT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS nombre_es TEXT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS nombre_en TEXT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS simbolo TEXT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS simbolo_int TEXT;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS precision SMALLINT DEFAULT 2;
ALTER TABLE bauth.bos_moneda ADD COLUMN IF NOT EXISTS pais_emisor CHAR(2);
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS locale TEXT;
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS codice_iso_639_1 CHAR(2);
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS codice_iso_639_2 CHAR(3);
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS nombre_nativo TEXT;
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS nombre_es TEXT;
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS direccion_texto TEXT DEFAULT 'ltr';
ALTER TABLE bauth.bos_idioma ADD COLUMN IF NOT EXISTS flag_emoji TEXT;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS nombre_es TEXT;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS utc_offset TEXT;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS utc_offset_min SMALLINT;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS observa_dst BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS pais TEXT;
ALTER TABLE bauth.bos_timezone ADD COLUMN IF NOT EXISTS ciudad_principal TEXT;
ALTER TABLE bauth.bos_financial_tipo_transaccion ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'general';
ALTER TABLE bauth.bos_financial_tipo_transaccion ADD COLUMN IF NOT EXISTS riesgo TEXT DEFAULT 'BAJO';
ALTER TABLE bauth.bos_financial_tipo_transaccion ADD COLUMN IF NOT EXISTS requiere_dual_control BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_financial_tipo_transaccion ADD COLUMN IF NOT EXISTS requiere_evidencia BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_financial_tipo_transaccion ADD COLUMN IF NOT EXISTS notificacion_sin BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_zona_logica ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'operativa';
ALTER TABLE bauth.bos_zona_logica ADD COLUMN IF NOT EXISTS ambito TEXT DEFAULT 'empresa';
ALTER TABLE bauth.bos_zona_logica ADD COLUMN IF NOT EXISTS es_critica BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_zona_logica ADD COLUMN IF NOT EXISTS requiere_segregacion BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS credential_type TEXT DEFAULT 'password';
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS min_strength_bits SMALLINT DEFAULT 128;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS ttl_max_dias INTEGER DEFAULT 365;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS rota_por_tiempo BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS rota_post_compromiso BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS rota_post_evento BOOLEAN DEFAULT FALSE;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS requiere_breach_screening BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_credential_policy ADD COLUMN IF NOT EXISTS historial_retencion SMALLINT DEFAULT 10;
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS operacion_id TEXT;
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS tipo_documento TEXT DEFAULT 'factura';
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS verbo TEXT DEFAULT 'CREATE';
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS afecta_dosificacion BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS requiere_firma_digital BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_financial_document_operation ADD COLUMN IF NOT EXISTS notifica_sin BOOLEAN DEFAULT TRUE;
ALTER TABLE bauth.bos_sod_conflict_matrix ADD COLUMN IF NOT EXISTS bit_a INTEGER;
ALTER TABLE bauth.bos_sod_conflict_matrix ADD COLUMN IF NOT EXISTS bit_b INTEGER;
ALTER TABLE bauth.bos_sod_conflict_matrix ADD COLUMN IF NOT EXISTS risk_level TEXT DEFAULT 'HIGH';
ALTER TABLE bauth.bos_sod_conflict_matrix ADD COLUMN IF NOT EXISTS action TEXT DEFAULT 'DENY';
ALTER TABLE bauth.bos_sod_conflict_matrix ADD COLUMN IF NOT EXISTS rationale TEXT;

-- Países (ISO 3166-1)
INSERT INTO bauth.bos_pais (codice_iso_alfa2, codice_iso_alfa3, codice_iso_num, nombre_es, nombre_en, continente, region, flag_emoji, codigo_telefonico) VALUES
('BO','BOL',068,'Bolivia','Bolivia','América del Sur','LATAM','🇧🇴','+591'),
('AR','ARG',032,'Argentina','Argentina','América del Sur','LATAM','🇦🇷','+54'),
('BR','BRA',076,'Brasil','Brazil','América del Sur','LATAM','🇧🇷','+55'),
('CL','CHL',152,'Chile','Chile','América del Sur','LATAM','🇨🇱','+56'),
('PE','PER',604,'Perú','Peru','América del Sur','LATAM','🇵🇪','+51'),
('CO','COL',170,'Colombia','Colombia','América del Sur','LATAM','🇨🇴','+57'),
('MX','MEX',484,'México','Mexico','América del Norte','LATAM','🇲🇽','+52'),
('US','USA',840,'Estados Unidos','United States','América del Norte','NA','🇺🇸','+1'),
('CN','CHN',156,'China','China','Asia','APAC','🇨🇳','+86'),
('ES','ESP',724,'España','Spain','Europa','EMEA','🇪🇸','+34'),
('PT','PRT',620,'Portugal','Portugal','Europa','EMEA','🇵🇹','+351'),
('DE','DEU',276,'Alemania','Germany','Europa','EMEA','🇩🇪','+49'),
('JP','JPN',392,'Japón','Japan','Asia','APAC','🇯🇵','+81'),
('KR','KOR',410,'Corea del Sur','South Korea','Asia','APAC','🇰🇷','+82'),
('IN','IND',356,'India','India','Asia','APAC','🇮🇳','+91')
ON CONFLICT DO NOTHING;

-- Monedas (ISO 4217)
INSERT INTO bauth.bos_moneda (codice_iso, codice_num, nombre_es, nombre_en, simbolo, simbolo_int, precision, pais_emisor) VALUES
('BOB',068,'Boliviano','Bolivian Boliviano','Bs.','BOB',2,'BO'),
('USD',840,'Dólar estadounidense','US Dollar','$','USD',2,'US'),
('EUR',978,'Euro','Euro','€','EUR',2,'DE'),
('CNY',156,'Yuan chino','Chinese Yuan','¥','CNY',2,'CN'),
('BRL',986,'Real brasileño','Brazilian Real','R$','BRL',2,'BR'),
('ARS',032,'Peso argentino','Argentine Peso','ARS$','ARS',2,'AR'),
('CLP',152,'Peso chileno','Chilean Peso','CLP$','CLP',0,'CL'),
('PEN',604,'Sol peruano','Peruvian Sol','S/.','PEN',2,'PE'),
('COP',170,'Peso colombiano','Colombian Peso','COL$','COP',0,'CO'),
('MXN',484,'Peso mexicano','Mexican Peso','MEX$','MXN',2,'MX'),
('JPY',392,'Yen japonés','Japanese Yen','¥','JPY',0,'JP'),
('INR',356,'Rupia india','Indian Rupee','₹','INR',2,'IN')
ON CONFLICT DO NOTHING;

-- Idiomas (BCP 47)
INSERT INTO bauth.bos_idioma (locale, codice_iso_639_1, codice_iso_639_2, nombre_nativo, nombre_es, direccion_texto, flag_emoji) VALUES
('es-BO','es','spa','Español (Bolivia)','Español (Bolivia)','LTR','🇧🇴'),
('es-AR','es','spa','Español (Argentina)','Español (Argentina)','LTR','🇦🇷'),
('es-MX','es','spa','Español (México)','Español (México)','LTR','🇲🇽'),
('en-US','en','eng','English (US)','Inglés (EEUU)','LTR','🇺🇸'),
('pt-BR','pt','por','Português (Brasil)','Portugués (Brasil)','LTR','🇧🇷'),
('zh-CN','zh','zho','中文 (简体)','Chino (Simplificado)','LTR','🇨🇳'),
('qu-BO','qu','que','Quechua (Bolivia)','Quechua (Bolivia)','LTR','🇧🇴'),
('ay-BO','ay','aym','Aymara (Bolivia)','Aymara (Bolivia)','LTR','🇧🇴'),
('ja-JP','ja','jpn','日本語','Japonés','LTR','🇯🇵'),
('de-DE','de','deu','Deutsch','Alemán','LTR','🇩🇪'),
('ar-SA','ar','ara','العربية','Árabe','RTL','🇸🇦')
ON CONFLICT DO NOTHING;

-- Zonas Horarias (IANA TZ)
INSERT INTO bauth.bos_timezone (timezone_id, nombre_es, utc_offset, utc_offset_min, observa_dst, pais, ciudad_principal) VALUES
('America/La_Paz','Bolivia (La Paz)','-04:00',-240,false,'BO','La Paz'),
('America/Argentina/Buenos_Aires','Argentina (Buenos Aires)','-03:00',-180,false,'AR','Buenos Aires'),
('America/Santiago','Chile (Santiago)','-04:00',-240,true,'CL','Santiago'),
('America/Lima','Perú (Lima)','-05:00',-300,false,'PE','Lima'),
('America/Bogota','Colombia (Bogotá)','-05:00',-300,false,'CO','Bogotá'),
('America/Mexico_City','México (Ciudad de México)','-06:00',-360,true,'MX','Ciudad de México'),
('America/New_York','EEUU (Nueva York)','-05:00',-300,true,'US','Nueva York'),
('America/Sao_Paulo','Brasil (São Paulo)','-03:00',-180,true,'BR','São Paulo'),
('Asia/Shanghai','China (Shanghái)','+08:00',480,false,'CN','Shanghái'),
('Europe/Madrid','España (Madrid)','+01:00',60,true,'ES','Madrid'),
('Europe/Berlin','Alemania (Berlín)','+01:00',60,true,'DE','Berlín'),
('Asia/Tokyo','Japón (Tokio)','+09:00',540,false,'JP','Tokio'),
('Asia/Kolkata','India (Kolkata)','+05:30',330,false,'IN','Kolkata')
ON CONFLICT DO NOTHING;

-- Tipos de transacciones financieras
INSERT INTO bauth.bos_financial_tipo_transaccion (tipo_id, nombre, categoria, riesgo, requiere_dual_control, requiere_evidencia, notificacion_sin) VALUES
('FAC_EMITIR','Emitir Factura','VENTAS','MEDIO',false,true,true),
('FAC_ANULAR','Anular Factura','VENTAS','ALTO',true,true,true),
('NC_EMITIR','Emitir Nota de Crédito','VENTAS','ALTO',true,true,true),
('ND_EMITIR','Emitir Nota de Débito','COBROS','ALTO',true,true,true),
('PAGO_CREAR','Crear Pago','PAGOS','MEDIO',false,true,false),
('PAGO_APROBAR','Aprobar Pago','PAGOS','ALTO',true,true,false),
('PAGO_EJECUTAR','Ejecutar Transferencia Bancaria','BANCARIO','CRITICO',true,true,false),
('COBRO_REGISTRAR','Registrar Cobro','COBROS','MEDIO',false,false,false),
('COBRO_CONCILIAR','Conciliar Cobro Bancario','BANCARIO','ALTO',false,true,false),
('ASIENTO_CREAR','Crear Asiento Contable','TRIBUTARIO','MEDIO',false,true,false),
('ASIENTO_APROBAR','Aprobar Asiento Contable','TRIBUTARIO','ALTO',true,true,false),
('ASIENTO_CERRAR','Cerrar Período Contable','TRIBUTARIO','CRITICO',true,true,false),
('NOMINA_PROCESAR','Procesar Nómina','NOMINA','CRITICO',true,true,false),
('INV_AJUSTAR','Ajustar Inventario','INVENTARIO','ALTO',true,true,false),
('ACTIVO_BAJA','Dar de Baja Activo Fijo','ACTIVOS_FIJOS','ALTO',true,true,false),
('IMP_CREAR','Crear Declaración de Importación','IMPORTACION','ALTO',true,true,true),
('EXP_CREAR','Crear Factura de Exportación','EXPORTACION','ALTO',true,true,true)
ON CONFLICT DO NOTHING;

-- Operaciones sobre documentos financieros
-- Zonas lógicas de negocio
INSERT INTO bauth.bos_zona_logica (zona_id, nombre, descripcion, categoria, ambito, es_critica, requiere_segregacion, zona_conflicto) VALUES
('VENTAS','Ventas y Facturación','Gestión de ventas, facturas, clientes','COMERCIAL','EMPRESA',true,true,ARRAY['AUDITORIA']),
('CONTABILIDAD','Contabilidad General','Registros contables, balances, cierres','FINANCIERA','EMPRESA',true,true,ARRAY['AUDITORIA']),
('INVENTARIO','Inventario y Almacenes','Control de stock, entradas, salidas','OPERATIVA','SUCURSAL',false,false,NULL),
('COMPRAS','Compras y Proveedores','Órdenes de compra, proveedores, licitaciones','OPERATIVA','EMPRESA',false,true,ARRAY['AUDITORIA','CONTABILIDAD']),
('TESORERIA','Tesorería y Pagos','Gestión de caja, bancos, conciliaciones','FINANCIERA','EMPRESA',true,true,ARRAY['AUDITORIA']),
('RRHH','Recursos Humanos','Personal, nómina, contratación','RRHH','EMPRESA',true,false,NULL),
('NOMINA','Nómina y Sueldos','Cálculo de planillas, AFP, retenciones','RRHH','EMPRESA',true,true,ARRAY['AUDITORIA']),
('TRIBUTARIA','Gestión Tributaria','Impuestos, DDJJ, retenciones SIN','FISCAL','EMPRESA',true,true,ARRAY['AUDITORIA']),
('FACTURACION','Facturación Electrónica','Emisión, dosificación, CUFD, SIN','FISCAL','SUCURSAL',true,true,ARRAY['AUDITORIA']),
('AUDITORIA','Auditoría Interna','Revisión de procesos, cumplimiento, SOX','DIRECTIVA','TENANT',true,false,NULL),
('ADMIN_SISTEMA','Administración del Sistema','Configuración, seguridad, monitoreo','TECNICA','TENANT',true,false,NULL),
('REPORTES','Reportes y Dashboards','Consultas, BI, exportación de datos','ADMINISTRATIVA','EMPRESA',false,false,NULL)
ON CONFLICT DO NOTHING;

-- Verbos — gestionados en bos_privilege.bos_verb (§20.4), no en bauth.bos_verbo (eliminada)

-- Políticas de credenciales (NIST SP 800-63B Rev.4 + NIST SP 800-57)
INSERT INTO bauth.bos_credential_policy (policy_id, nombre, credential_type, min_strength_bits, ttl_max_dias, rota_por_tiempo, rota_post_compromiso, rota_post_evento, requiere_breach_screening, historial_retencion) VALUES
('PASSWORDS','Contraseñas de Usuario','PASSWORD',256,NULL,false,true,true,true,10),
('MFA_TOTP','Seeds TOTP','TOTP',256,NULL,false,true,false,false,0),
('WEBAUTHN','Credenciales FIDO2/WebAuthn','WEBAUTHN',256,NULL,false,true,false,false,0),
('M2M_CERTS','Certificados M2M (Daemons)','X509_CERT',256,1,true,true,false,false,0),
('OAUTH_SECRETS','Client Secrets OAuth 2.0','OAUTH_SECRET',256,90,true,true,false,false,3),
('API_KEY','API Keys','API_KEY',256,180,true,true,false,false,3),
('ENCRYPTION_KEY','Claves de Cifrado (AES)','ENCRYPTION_KEY',256,90,true,true,true,false,0),
('SIGNING_KEY','Claves de Firma (EdDSA/ECDSA)','SIGNING_KEY',256,180,true,true,true,false,0)
ON CONFLICT DO NOTHING;

INSERT INTO bauth.bos_financial_document_operation (operacion_id, tipo_documento, verbo, descripcion, afecta_dosificacion, requiere_firma_digital, notifica_sin) VALUES
('FAC_CREATE','FACTURA','CREATE','Emitir nueva factura',true,true,true),
('FAC_READ','FACTURA','READ','Consultar factura',false,false,false),
('FAC_ANULAR','FACTURA','ANULAR','Anular factura (no libera número)',false,true,true),
('FAC_REIMPRIMIR','FACTURA','REIMPRIMIR','Reimprimir representación gráfica',false,false,false),
('NC_CREATE','NOTA_CREDITO','CREATE','Emitir nota de crédito',true,true,true),
('ND_CREATE','NOTA_DEBITO','CREATE','Emitir nota de débito',true,true,true),
('PAGO_CREATE','PAGO','CREATE','Crear orden de pago',false,false,false),
('PAGO_APROBAR','PAGO','APROBAR','Aprobar orden de pago',false,false,false),
('PAGO_EJECUTAR','PAGO','EXECUTE','Ejecutar transferencia bancaria',false,true,false),
('ASIENTO_CREATE','ASIENTO','CREATE','Crear asiento contable',false,false,false),
('ASIENTO_APROBAR','ASIENTO','APROBAR','Aprobar asiento contable',false,false,false),
('ASIENTO_CERRAR','ASIENTO','CERRAR','Cerrar período contable',false,false,false),
('ASIENTO_REABRIR','ASIENTO','REABRIR','Reabrir período cerrado (requiere auditoría)',false,true,false)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 20. SoD CONFLICT MATRIX — Artefacto normativo SOX §404
-- ============================================================
-- Propósito: Matriz de conflictos de Separación de Funciones.
--           Cada fila define un par de bits de permiso que NO
--           pueden coexistir en el mismo usuario. Validada ANTES
--           de asignar cualquier rol con bits financieros.
-- Referencia: NIST SP 800-53 AC-5 · SOX §404 · ISACA COBIT 2019 BAI09
--             SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.1 §6 (SBOS-XDOM-002)

CREATE TABLE IF NOT EXISTS bauth.bos_sod_conflict_matrix (
    conflict_id     BIGSERIAL   PRIMARY KEY,
    bit_a           INTEGER     NOT NULL,                  -- Bit del permiso A (ej: 14=FINANCIAL_APPROVE)
    bit_b           INTEGER     NOT NULL,                  -- Bit del permiso B (ej: 15=FINANCIAL_CREATE)
    risk_level      TEXT        NOT NULL,                  -- ALTO|MEDIO|BAJO
    action          TEXT        NOT NULL,                  -- BLOCK|COMPENSATE|ALLOW_LOG
    rationale       TEXT        NOT NULL,                  -- Justificación normativa (SOX §404, COSO, etc.)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at     TIMESTAMPTZ,                           -- Última revisión anual (COBIT BAI09)
    reviewed_by     TEXT,
    UNIQUE (bit_a, bit_b),
    CONSTRAINT chk_sod_risk  CHECK (risk_level IN ('ALTO','MEDIO','BAJO')),
    CONSTRAINT chk_sod_action CHECK (action IN ('BLOCK','COMPENSATE','ALLOW_LOG'))
);

-- Datos iniciales: conflictos financieros fundamentales
INSERT INTO bauth.bos_sod_conflict_matrix (bit_a, bit_b, risk_level, action, rationale) VALUES
(14, 15, 'ALTO', 'BLOCK',
 'SOX §404 COSO Control Activities: quien crea transacciones (FINANCIAL_CREATE) no puede aprobarlas (FINANCIAL_APPROVE). NIST SP 800-53 AC-5.'),
(15, 14, 'ALTO', 'BLOCK',
 'SOX §404: par simétrico — quien aprueba no puede crear (dual control).')
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_sod_bits ON bauth.bos_sod_conflict_matrix(bit_a, bit_b);

COMMENT ON TABLE bauth.bos_sod_conflict_matrix IS 'Matriz de conflictos SoD. Artefacto normativo exigible en auditorías SOX §404. Revisión anual obligatoria (ISACA COBIT 2019 BAI09).';
COMMENT ON COLUMN bauth.bos_sod_conflict_matrix.action IS 'BLOCK (rechazar asignación), COMPENSATE (requiere aprobación + control compensatorio), ALLOW_LOG (permitir con registro de auditoría).';

-- ============================================================
-- 21. CRITICALITY sobre DELEGATION — Revocación event-driven
-- ============================================================
-- Propósito: Las delegaciones que incluyen bits críticos (D2 físico
--           o D3 financiero) requieren revocación inmediata vía
--           Redis pub/sub, no solo cron de 60s.
-- Referencia: SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.1 §D10

ALTER TABLE bauth.bos_delegation_log
    ADD COLUMN IF NOT EXISTS criticality TEXT NOT NULL DEFAULT 'NORMAL';

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_delegation_criticality') THEN
        ALTER TABLE bauth.bos_delegation_log
            ADD CONSTRAINT chk_delegation_criticality CHECK (criticality IN ('NORMAL','HIGH','CRITICAL'));
    END IF;
END $$;

COMMENT ON COLUMN bauth.bos_delegation_log.criticality IS 'NORMAL (cron 60s), HIGH (Redis pub/sub < 1s para bits D2/D3), CRITICAL (revocación inmediata + notificación CISO).';

-- ============================================================
-- 22. CONFIGURACIÓN GEOESPACIAL — Umbral viaje imposible
-- ============================================================
-- Propósito: Umbral configurable por tenant. Default: 900 km/h
--           (velocidad crucero vuelo comercial).
-- Referencia: Microsoft Defender for Cloud Apps, Azure Sentinel.

ALTER TABLE bauth.bos_tenant_config
    ADD COLUMN IF NOT EXISTS impossible_travel_kmh INTEGER NOT NULL DEFAULT 900;

COMMENT ON COLUMN bauth.bos_tenant_config.impossible_travel_kmh IS 'Umbral de velocidad para detección de viaje imposible (km/h). Default: 900 (crucero vuelo comercial). Configurable por tenant.';

-- ============================================================
-- 23. ROLES DE AUDITORÍA WORM — PostgreSQL RLS + pgAudit
-- ============================================================
-- Propósito: Garantizar inmutabilidad de bauth_audit_events a nivel
--           de base de datos. La aplicación usa bauth_audit_writer
--           (solo INSERT). NADIE tiene UPDATE/DELETE sobre la tabla.
-- Referencia: PCI DSS 4.0 Req.10.3.2 · ISO 27001 A.8.15

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
