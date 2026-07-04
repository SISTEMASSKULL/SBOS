-- ============================================================================
-- bglobal — Catálogos globales (ISO 4217/639/3166, timezone, menús)
-- REFERENCIA DE LECTURA — ESTE ARCHIVO NO CREA NADA (solo comentarios).
-- ============================================================================
-- Catálogos base del ecosistema: países, monedas, idiomas, zonas horarias y menús.
--
-- Las 8 tablas del schema 'bglobal' NO se declaran aquí: están declaradas
-- en la DDL principal UNIDA  →  migrations/sbos_00__esquema_base.sql
--
-- ¿POR QUÉ no están separadas en este archivo?
-- Porque bglobal, bcalendar y bauth tienen CLAVES FORÁNEAS CIRCULARES entre sí:
--   · bcalendar.cal_*  y  bglobal.menu_*   →  REFERENCES bauth.idn_tenant
--   · bauth.*                              →  REFERENCES bglobal.global_country
-- No existe un orden 'un schema completo, luego el siguiente' que satisfaga el
-- ciclo: siempre queda una FK apuntando a un schema aún no creado. Separarlas
-- físicamente produjo 60 errores (verificado en BD auxiliar). Por eso la DDL
-- principal se mantiene UNIDA, con el orden entrelazado que sí resuelve las FK.
--
-- Este archivo cumple la convención (un archivo por servicio) como PUNTERO de
-- lectura: dónde está cada tabla, qué contiene, cuántos registros y un ejemplo
-- real. Cargarlo con inicializar_sbos_db.sh no ejecuta nada (todo es comentario).
-- ============================================================================

-- ── bglobal.geo_timezone ───────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 495
--   Propósito:     [IANA Time Zone Database] [zone.tab] [ISO 6709] [Unicode CLDR] Catálogo canónico de zonas horarias para todo el ecosistema SBOS. PK: timezone_uuid UUIDv7 (RFC 9…
--   Registros (BD real):  319
--   Columnas (15): timezone_uuid, timezone_id, name, country_code, principal_city, coordinates, utc_offset, utc_offset_min, observes_dst, dst_offset, dst_offset_min, comments…
--   Índices (4): idx_tz_country, idx_tz_dst, idx_tz_iana, idx_tz_name
--   Ejemplo real:  {"timezone_uuid":"019f1333-...","timezone_id":"Africa/Nairobi","name":{"en":"Kenya (Nairobi)","es":"Kenia (Nairobi)"},"country_code":"KE","principal_city":"Nairobi","coordinates":"(-1.28,36.82)","utc_offset":"+03:00",…}

-- ── bglobal.global_config ──────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 4094
--   Propósito:     [NIST SP 800-53 CM-6] [ISO 27001 A.8.9] Catálogo central de parámetros del sistema. Fuente única de verdad para configuración modificable en runtime. Cada fila …
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (12): config_key, config_value, data_type, category, description, standard_ref, default_value, version, ctx_id, created_at, updated_at, updated_by

-- ── bglobal.global_country ─────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 295
--   Propósito:     [ISO 3166-1:2020] [UN M.49] [ITU-T E.164] [IANA TZ] [CLDR] Catálogo canónico de países para todo el ecosistema SBOS. Natural key: iso_alpha2 CHAR(2). Fuentes: I…
--   Registros (BD real):  196
--   Columnas (36): country_id, iso_alpha2, iso_alpha3, iso_numeric, un_m49, itu_calling_code, tld, icao_code, name_common, name_official, name_native, demonym…
--   Ejemplo real:  {"country_id":"019f1333-...","iso_alpha2":"BO","iso_alpha3":"BOL","iso_numeric":68,"un_m49":68,"itu_calling_code":"+591","tld":".bo","name_common":"Bolivia","name_official":"Plurinational State of Bolivia",…}

-- ── bglobal.global_currency ────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 388
--   Propósito:     [ISO 4217:2015] Currency catalog maintained by SIX Interbank Clearing on behalf of ISO. PK: currency_id UUIDv7 (RFC 9562). Natural key: currency_code CHAR(3) UN…
--   Registros (BD real):  143
--   Columnas (17): currency_id, currency_code, iso_numeric, name, symbol, symbol_intl, decimal_places, minor_unit_name, introduced_at, withdrawn_at, issuer_country, country_id…
--   Índices (4): idx_gcur_active, idx_gcur_code, idx_gcur_country, idx_gcur_name
--   Ejemplo real:  {"currency_id":"019f1333-...","currency_code":"USD","iso_numeric":840,"name":{"en":{"singular":"United States Dollar","plural":"United States Dollars"}},…}

-- ── bglobal.global_language ────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 131
--   Propósito:     [BCP 47] [RFC 5646] [ISO 639-1/2/3] [ISO 15924] [IANA Language Subtag Registry] [Unicode CLDR 46] Catálogo canónico de idiomas para todo el ecosistema SBOS. PK:…
--   Registros (BD real):  125
--   Columnas (20): language_id, locale, iso_639_1, iso_639_2t, iso_639_2b, iso_639_3, scope, language_type, family, name, direction, fallback_locale…
--   Índices (7): idx_glang_active, idx_glang_family, idx_glang_iso6391, idx_glang_locale, idx_glang_name, idx_glang_scope…
--   Ejemplo real:  {"language_id":"019f1333-...","locale":"de","iso_639_1":"de","iso_639_3":"deu","scope":"individual","language_type":"living","family":"Indo-European",…}

-- ── bglobal.menu_context ───────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 2812
--   Registros (BD real):  99
--   Columnas (7): id, tenant_id, context_key, entity_type, description, ctx_id, created_at
--   Ejemplo real:  {"id":"019f1333-...","tenant_id":"019f1333-...","context_key":"transaccion","entity_type":"Transaccion","description":"Operaciones sobre transacciones financieras","ctx_id":"system",…}

-- ── bglobal.menu_item ──────────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 2793
--   Registros (BD real):  147
--   Columnas (13): id, tenant_id, parent_id, label, route, icon, sort_order, is_visible, menu_type, context_key, ctx_id, created_at…
--   Ejemplo real:  {"id":"019f1333-...","tenant_id":"019f1333-...","parent_id":null,"label":"Dashboard","route":"/dashboard","icon":"dashboard","sort_order":1,"is_visible":true,"menu_type":"HIERARCHICAL",…}

-- ── bglobal.menu_item_atom ─────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 2822
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (6): menu_item_id, atom_code, require_all, min_loa, step_up_flow, created_at

