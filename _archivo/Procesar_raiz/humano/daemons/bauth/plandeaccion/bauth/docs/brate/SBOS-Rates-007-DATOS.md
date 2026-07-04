# Modelo de Datos — SBOS SmartRates

---

## Bases de datos

| Base de datos | Nombre convención SBOS | Propósito |
|---|---|---|
| Principal | `smartrates_db` | Fuente de verdad de cotizaciones, catálogos, configuración de empresa |
| Validación | `smartrates_db (schema validation)` | Datos BCB Bolivia, cruces de validación, histórico referencial |

---

## smartrates_db — 8 Schemas

### Schema catalog — Datos maestros ISO

**Propósito:** Catálogos de referencia. Cambian raramente (solo con nuevas monedas o países). Datos poblados una sola vez al instalar el sistema.

---

**catalog.currencies — 200+ monedas ISO 4217**

**Qué representa:** El catálogo completo de monedas reconocidas. Cada moneda tiene su código, nombre en español e inglés, formato de presentación y país emisor.

**Ciclo de vida:** Se inserta al instalar el sistema. Se agrega si el FMI incorpora una nueva moneda. Nunca se elimina — solo se desactiva (`is_active = false`).

**Retención:** Permanente.  
**Sensibilidad:** Pública.

**Atributos clave:**

| Atributo | Tipo | Descripción |
|---|---|---|
| `currency_code` | CHAR(3) PK | ISO 4217 alfabético: BOB, USD, EUR |
| `currency_numeric` | CHAR(3) UK | ISO 4217 numérico: 068, 840, 978 |
| `currency_minor_unit` | SMALLINT | Decimales oficiales: JPY=0, USD=2, KWD=3 |
| `name_es_singular` | VARCHAR(100) | boliviano, dólar, euro |
| `name_es_plural` | VARCHAR(100) | bolivianos, dólares, euros |
| `name_en_singular` | VARCHAR(100) | boliviano, dollar, euro |
| `symbol` | VARCHAR(10) | Bs., $, € |
| `symbol_position` | VARCHAR(15) | before, after, space_before, space_after |
| `decimal_separator` | CHAR(1) | '.' (USD/BOB) o ',' (EUR/BRL) |
| `thousands_separator` | CHAR(1) | ',' (USD) o '.' (EUR) o ' ' (NOK) |
| `country_code_alpha2` | CHAR(2) | País emisor principal. FK NOT ENFORCED para EUR, XAU, XAG |
| `flag_emoji` | VARCHAR(10) | Solo para supranacionales: 🇪🇺, 🥇 |
| `is_active` | BOOLEAN | false para monedas descontinuadas |
| `is_crypto` | BOOLEAN | Siempre false — solo monedas fiat |

**Feature PG18 usada:** FK `NOT ENFORCED` para monedas supranacionales (EUR, XAU, XAG, XDR) que no tienen un país único emisor.

---

**catalog.countries — 249 países ISO 3166-1**

| Atributo | Tipo | Descripción |
|---|---|---|
| `country_code_alpha2` | CHAR(2) PK | BO, US, BR, AR |
| `country_code_alpha3` | CHAR(3) UK | BOL, USA, BRA, ARG |
| `country_code_numeric` | CHAR(3) UK | 068, 840, 076, 032 |
| `name_es` | VARCHAR(150) | Bolivia, Estados Unidos, Brasil |
| `name_en` | VARCHAR(150) | Bolivia, United States, Brazil |
| `flag_emoji` | VARCHAR(10) | 🇧🇴, 🇺🇸, 🇧🇷 |
| `primary_currency_code` | CHAR(3) FK | BOB, USD, BRL |
| `is_active` | BOOLEAN | false para territorios sin moneda propia |

---

**catalog.currency_groups — 14 bloques económicos**

| Atributo | Tipo | Descripción |
|---|---|---|
| `group_code` | VARCHAR(20) PK | G7, BRICS, MERCOSUR, OPEC, OPEC_PLUS, EUROPA, LATAM, etc. |
| `name_es` | VARCHAR(100) | Grupo de los 7, BRICS, Mercosur |
| `description_es` | TEXT | Qué es el bloque y por qué existe |
| `is_active` | BOOLEAN | — |

**catalog.country_groups** (relación M:N países ↔ grupos)

**catalog.black_rate_types** — nombres del mercado alternativo por país

| Atributo | Tipo | Descripción |
|---|---|---|
| `country_code` | CHAR(2) PK | BO, AR, VE |
| `black_rate_name_es` | VARCHAR(100) | "mercado paralelo" (Bolivia), "dólar blue" (Argentina) |
| `black_rate_description` | TEXT | Contexto legal y económico del mercado alternativo en ese país |
| `is_active` | BOOLEAN | Si ese país actualmente tiene un mercado alternativo reconocido |

---

### Schema rates — Cotizaciones

**Propósito:** Alta escritura (sync diaria + backfill), alta lectura (toda consulta de cotización). Particionado por año.

---

**rates.exchange_rates — tabla principal (particionada por año)**

**Qué representa:** El corazón del sistema. Cada registro es el tipo de cambio de una moneda vs USD para una fecha específica, proveniente de una fuente específica.

**Ciclo de vida:** Se crea en cada sincronización diaria (por `SyncJob` o por `biedata`). Nunca se modifica (inmutable). Las correcciones son nuevos registros con `type_code='correction'`. Se particiona por año para purgas eficientes.

**Retención:** 10 años mínimo (requisito normativo boliviano).  
**Sensibilidad:** Interna — son datos financieros.

| Atributo | Tipo | PG18 | Descripción |
|---|---|---|---|
| `id` | UUID PK | uuidv7() | PK ordenada temporalmente |
| `base_currency` | CHAR(3) FK | — | Siempre 'USD' |
| `quote_currency` | CHAR(3) FK | — | BOB, EUR, BRL... |
| `rate_official` | NUMERIC(20,8) | — | Rate publicado por la fuente |
| `rate_buy` | NUMERIC(20,8) | — | Precio de compra del banco |
| `rate_sell` | NUMERIC(20,8) | — | Precio de venta del banco |
| `rate_mid` | NUMERIC(20,8) | VIRTUAL GENERATED ALWAYS AS (rate_buy+rate_sell)/2 | No ocupa disco. Siempre consistente |
| `adjustment` | NUMERIC(20,8) | — | Ajuste del mercado alternativo. 0 si no aplica |
| `rate_black_buy` | NUMERIC(20,8) | VIRTUAL GENERATED ALWAYS AS rate_official+adjustment | No ocupa disco |
| `rate_black_sell` | NUMERIC(20,8) | VIRTUAL GENERATED ALWAYS AS rate_official+adjustment+spread | No ocupa disco |
| `rate_date` | DATE | — | Fecha del dato |
| `source_code` | VARCHAR(30) FK | — | 'fawazahmed0', 'bcb_bolivia', 'imf_sdmx', 'frankfurter' |
| `type_code` | VARCHAR(30) FK | — | 'official_daily', 'official_monthly', 'carried_forward', 'interpolated', 'weekend_estimate', 'correction' |
| `quality` | CHAR(6) | — | 'high', 'medium', 'low' |
| `created_at` | TIMESTAMPTZ | — | Timestamp con timezone |

**Constraint:**
```sql
UNIQUE (base_currency, quote_currency, rate_date, source_code)
```

**Particionamiento PG18:**
```sql
PARTITION BY RANGE (rate_date)
-- Particiones anuales: y1990, y1991, ..., y2026, y2027_default
```

**Índices:**
- BRIN en `rate_date` (series de tiempo — 100× más pequeño que B-tree)
- B-tree en `(base_currency, quote_currency, rate_date)` — consulta más frecuente
- B-tree en `(quote_currency, rate_date)` — para series históricas por moneda

---

**rates.data_sources** — catálogo de fuentes normalizadas  
**rates.data_types** — catálogo de tipos de dato normalizados

---

### Schema company — Configuración multi-tenant

---

**company.companies**

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `tenant_id` | VARCHAR(50) | ID del tenant SBOS (ej: 'skull') |
| `company_code` | VARCHAR(50) | Código interno de la empresa |
| `name` | VARCHAR(200) | Nombre de la empresa |
| `operating_country` | CHAR(2) FK | País de operación principal |
| `is_active` | BOOLEAN | — |

---

**company.system_config — moneda doméstica y puente**

**Qué representa:** La configuración base del sistema para una empresa. Define la moneda en la que opera (BOB para Bolivia) y la moneda puente para conversiones internacionales (USD por defecto).

**Feature PG18 clave:** `WITHOUT OVERLAPS` — garantiza que no haya dos configuraciones activas para la misma empresa en el mismo momento. Sin triggers. Sin validación de aplicación. El motor lo enforza.

```sql
PRIMARY KEY (company_id, valid_period WITHOUT OVERLAPS)
```

| Atributo | Tipo | Descripción |
|---|---|---|
| `company_id` | UUID FK | — |
| `domestic_currency` | CHAR(3) FK | BOB para Bolivia |
| `bridge_currency` | CHAR(3) FK | USD por defecto (configurable a CNY, EUR) |
| `operating_country` | CHAR(2) FK | BO |
| `conversion_policy` | TEXT | Descripción en lenguaje natural de la política |
| `valid_period` | DATERANGE | Rango de fechas de vigencia |

---

**company.rate_config — política de mercado alternativo**

**Feature PG18:** `WITHOUT OVERLAPS` — sin solapamiento de vigencias por empresa+moneda.

| Atributo | Tipo | Descripción |
|---|---|---|
| `company_id` | UUID FK | — |
| `currency_code` | CHAR(3) FK | Moneda a la que aplica la política |
| `use_black_rate` | VARCHAR(20) | 'disabled', 'reference', 'national' |
| `international_currency` | CHAR(3) FK | Moneda para transacciones internacionales (cuando use_black_rate='national') |
| `spread` | NUMERIC(20,8) | Diferencial entre black buy y black sell |
| `notes` | TEXT | Justificación de la política |
| `valid_period` | DATERANGE | Rango de vigencia |
| `created_by` | UUID FK | Usuario que creó la configuración |

---

**company.adjustment_daily — confirmación manual del ajuste**

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `company_id` | UUID FK | — |
| `currency_code` | CHAR(3) FK | BOB (o la moneda que aplique) |
| `rate_date` | DATE | Fecha del ajuste |
| `confirmed` | BOOLEAN | false hasta que el operador confirma |
| `confirmed_by` | UUID FK | user_id del operador que confirmó |
| `confirmed_at` | TIMESTAMPTZ | Timestamp exacto de la confirmación |
| `adjustment_value` | NUMERIC(20,8) | El diferencial ingresado por el operador |
| `notes` | TEXT | Nota opcional del operador |

---

### Schema sync — Control de sincronización

**sync.circuit_breaker_state**

| Atributo | Tipo | Descripción |
|---|---|---|
| `source_code` | VARCHAR(30) PK | 'fawazahmed0', 'bcb_bolivia', etc. |
| `state` | VARCHAR(10) | 'CLOSED' (normal), 'OPEN' (fallando), 'HALF_OPEN' (probando) |
| `failure_count` | INTEGER | Fallos consecutivos |
| `last_failure_at` | TIMESTAMPTZ | Último fallo |
| `next_retry_at` | TIMESTAMPTZ | Próximo intento permitido |

**sync.sync_log** — log particionado por trimestre, cada sincronización que se ejecuta

**sync.backfill_progress** — control del backfill histórico de 3 fases

| Atributo | Tipo | Descripción |
|---|---|---|
| `phase` | INTEGER | 1 (fawazahmed0), 2 (FMI), 3 (BCB histórico) |
| `current_date` | DATE | Última fecha procesada |
| `target_date_from` | DATE | Fecha objetivo inicio de la fase |
| `target_date_to` | DATE | Fecha objetivo fin de la fase |
| `requests_tonight` | INTEGER | Requests enviados esta noche |
| `status` | VARCHAR(20) | 'active', 'paused', 'completed', 'error' |
| `last_run_at` | TIMESTAMPTZ | Última ejecución |
| `error_message` | TEXT | Último error si status='error' |

---

### Schema security — Auditoría

**security.audit_log** — particionado por trimestre

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `ctx_id` | VARCHAR(50) | Session ID del SBOS (vacío en modo standalone) |
| `request_id` | UUID | ID único del request HTTP |
| `user_id` | UUID | Usuario que realizó la acción |
| `endpoint` | VARCHAR(200) | ej: 'GET /api/v1/rates/today' |
| `method` | CHAR(6) | GET, POST, PUT, DELETE |
| `ip_address` | INET | IPv4 o IPv6 (tipo nativo PG18) |
| `user_agent` | VARCHAR(500) | — |
| `request_params` | JSONB | Parámetros de la solicitud (indexable) |
| `response_code` | SMALLINT | 200, 401, 403, 404, 429, 500 |
| `response_ms` | INTEGER | Tiempo de respuesta |
| `created_at` | TIMESTAMPTZ | — |

**security.error_catalog** — catálogo de errores SR-XXX con descripción y acción correctiva

---

### Schema validation — Datos BCB Bolivia

(En `smartrates_db (schema validation)`)

**validation.bcb_cotizaciones** — datos crudos del BCB procesados

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `rate_date` | DATE | Fecha del dato BCB |
| `currency_code_bcb` | VARCHAR(10) | Código BCB original (puede diferir de ISO) |
| `currency_code_iso` | CHAR(3) | Código ISO 4217 mapeado |
| `rate_buy` | NUMERIC(20,8) | Precio de compra BCB |
| `rate_sell` | NUMERIC(20,8) | Precio de venta BCB |
| `rate_referencial` | NUMERIC(20,8) | Valor referencial de mercado (desde dic 2025) |
| `source_file_date` | DATE | Fecha del archivo Excel descargado |
| `created_at` | TIMESTAMPTZ | — |

**validation.bcb_vs_oficial** — cruce BCB vs fawazahmed0 con alertas  
**validation.currency_mapping** — mapeo de códigos BCB a ISO 4217 (CNH→CNY, VEB→VES, etc.)

---

### Schema historical — Referencia histórica BCB 1990-2015

(En `smartrates_db (schema validation)`)

**historical.bcb_rates** — solo lectura, datos históricos del BCB

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `rate_date` | DATE | Fecha (primer día hábil del mes como representante mensual) |
| `currency_code` | CHAR(3) | Código ISO 4217 |
| `rate_buy` | NUMERIC(20,8) | — |
| `rate_sell` | NUMERIC(20,8) | — |
| `rate_mid` | NUMERIC(20,8) | VIRTUAL GENERATED |
| `quality` | CHAR(6) | Siempre 'low' — son datos históricos referenciales |
| `data_type` | VARCHAR(30) | 'historical_ref' |

---

### Schema broadcast — Cola de mensajes para el Ticker

**broadcast.messages** — mensajes a mostrar en la cinta informativa

| Atributo | Tipo | Descripción |
|---|---|---|
| `id` | UUID PK uuidv7() | — |
| `type` | VARCHAR(20) | 'rate', 'alert', 'warning', 'institutional', 'weather', 'time' |
| `priority` | SMALLINT | 1=alerta crítica, 2=advertencia, 3=institucional, 4=cotización, 5=clima, 6=hora |
| `content` | JSONB | Datos del mensaje según el tipo |
| `active_from` | TIMESTAMPTZ | Inicio de vigencia |
| `active_until` | TIMESTAMPTZ | Fin de vigencia ('9999-12-31...' = permanente) |
| `created_by_system` | VARCHAR(50) | Sistema que generó el mensaje |

---

## Convención de datos: NO NULL, siempre valor explícito

| Tipo de campo | Valor explícito obligatorio |
|---|---|
| NUMERIC / DECIMAL | `0.00000000` |
| VARCHAR / TEXT | `''` (cadena vacía) o código estándar 'N/A' |
| DATE vigencia abierta | `'9999-12-31'` |
| TIMESTAMP sin valor aún | `'1900-01-01 00:00:00'` |
| BOOLEAN no confirmado | `false` |
| UUID referencia sin asignar | UUID cero: `'00000000-0000-0000-0000-000000000000'` |

---

## Features PG18 utilizadas — resumen

| Feature | Dónde se usa | Beneficio concreto |
|---|---|---|
| `uuidv7()` PKs | Todas las tablas UUID | PKs ordenadas temporalmente. Mejor rendimiento INSERT en B-tree. Sin fragmentación. |
| `GENERATED ALWAYS AS VIRTUAL` | `rate_mid`, `rate_black_buy`, `rate_black_sell`, `rate_mid` en historical | No ocupa espacio en disco. Siempre matemáticamente consistente. Sin triggers de actualización. |
| `WITHOUT OVERLAPS` en UNIQUE/PK | `company.system_config`, `company.rate_config` | El motor enforza vigencias temporales sin solapamiento. Sin triggers. Sin validación de aplicación. |
| `PARTITION BY RANGE` | `rates.exchange_rates`, `sync.sync_log`, `security.audit_log` | Purga instantánea por `DROP PARTITION`. Queries en rangos de fecha solo tocan las particiones relevantes. |
| BRIN indexes | `rates.exchange_rates`, `security.audit_log` | Para columnas de series de tiempo: 100× más pequeño que B-tree. Ideal para `rate_date` y `created_at`. |
| `INET` | `security.audit_log.ip_address` | Tipo nativo IPv4/IPv6 con operadores de red. Sin VARCHAR ni conversiones. |
| `JSONB` | `security.audit_log.request_params`, `broadcast.messages.content` | JSON indexable con GIN index. Consultas por campos internos sin extraer. |
| `NOT ENFORCED` FK | `currencies.country_code_alpha2` | Monedas supranacionales (EUR, XAU, XAG) sin país único emisor. FK declarativa para documentación sin enforcement. |
| `io_uring` AIO | `postgresql.conf` | Hasta 3× mejora en lectura secuencial en Linux (scans de series históricas largas). |
| `pg_notify` | Trigger en `rates.exchange_rates` | Pub/Sub nativo sin intermediario. Al insertar una cotización, notifica inmediatamente al stream SSE → Ticker. |

---
_SKULL · SBOS · SmartRates · 007-DATOS · v1.0 · 2026-05-23_

---

## Actualizaciones post-simulación (2026-05-23)

### Una sola base de datos: smartrates_db

Los schemas `validation` e `historical` que antes se pensaban en una BD separada, ahora están dentro de `smartrates_db`. Esto simplifica el acceso desde la extensión C `catalog.RATE()` y elimina cross-DB queries.

```
smartrates_db (única BD)
├── schema catalog    → monedas, países, bloques económicos, tipos black rate
├── schema rates      → exchange_rates, stablecoin_rates, spread_log, fuentes, tipos
├── schema company    → configuración, adjustment_daily, stablecoin_adjustment (NUEVA)
├── schema sync       → circuit_breaker, sync_log, backfill_progress
├── schema security   → audit_log, error_catalog
├── schema validation → bcb_cotizaciones, bcb_vs_oficial, currency_mapping (antes BD separada)
├── schema historical → bcb_rates 1990-2015 (antes BD separada)
└── schema broadcast  → messages para el Ticker
```

### Nueva tabla: company.stablecoin_adjustment

Permite que cada empresa ajuste USDT/USDC de forma independiente.  
`adjustment_value = 0` significa "usar el P2P de CriptoYa directamente sin ajuste".

```sql
CREATE TABLE company.stablecoin_adjustment (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    company_id       UUID          NOT NULL REFERENCES company.companies(id),
    coin_code        CHAR(3)       NOT NULL,  -- 'XUT' o 'XUC'
    fiat_code        CHAR(3)       NOT NULL,  -- 'BOB'
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    CONSTRAINT pk_stablecoin_adj PRIMARY KEY (id),
    CONSTRAINT uq_stablecoin_adj UNIQUE (company_id, coin_code, fiat_code, rate_date)
);
```

### UUID_SYSTEM — usuario predefinido en seeds

```sql
-- Seed obligatorio: usuario sistema para ajustes provisionales (timeout 17:00)
INSERT INTO users (
    id, name, email, role, created_at
) VALUES (
    '00000000-0000-7777-0000-000000000000',
    'SISTEMA SmartRates',
    'system@smartrates.internal',
    'system',
    '2026-01-01 00:00:00+00'
);
-- Este UUID es la constante UUID_SYSTEM en toda la codebase
-- Cuando confirmed_by = UUID_SYSTEM: el ajuste es PROVISIONAL (timeout automático)
```

### Columna is_stablecoin en catalog.currencies

La columna se llama `is_stablecoin` (no `is_crypto`). Solo USDT (XUT) y USDC (XUC) tienen `is_stablecoin = true`.

```sql
ALTER TABLE catalog.currencies
    ADD COLUMN is_stablecoin   BOOLEAN      NOT NULL DEFAULT false,
    ADD COLUMN crypto_ticker   VARCHAR(10)  NOT NULL DEFAULT '',
    ADD COLUMN peg_to          CHAR(3)      NOT NULL DEFAULT '',
    ADD COLUMN crypto_issuer   VARCHAR(100) NOT NULL DEFAULT '',
    ADD COLUMN crypto_network  VARCHAR(100) NOT NULL DEFAULT '';

-- Tether USD
INSERT INTO catalog.currencies (..., currency_code, is_stablecoin, crypto_ticker, peg_to, crypto_issuer)
VALUES (..., 'XUT', true, 'USDT', 'USD', 'Tether Ltd.', 'TRC20,ERC20,BEP20,SOL');

-- USD Coin
INSERT INTO catalog.currencies (..., currency_code, is_stablecoin, crypto_ticker, peg_to, crypto_issuer)
VALUES (..., 'XUC', true, 'USDC', 'USD', 'Circle Internet Group', 'ETH,SOL,BASE,MATIC,AVAX');
```


---

## Nuevas tablas del modelo de dos niveles (post-simulación v3)

### company.adjustment_global — Ajuste global del SBOS

```sql
CREATE TABLE company.adjustment_global (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    tenant_id        VARCHAR(50)   NOT NULL DEFAULT '',
    currency_code    CHAR(3)       NOT NULL DEFAULT '',
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    is_provisional   BOOLEAN       NOT NULL DEFAULT false,
    CONSTRAINT pk_adjustment_global PRIMARY KEY (id),
    CONSTRAINT uq_adjustment_global UNIQUE (tenant_id, currency_code, rate_date)
);
```

### company.stablecoin_adjustment_global — Ajuste global XUT/XUC

```sql
CREATE TABLE company.stablecoin_adjustment_global (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    tenant_id        VARCHAR(50)   NOT NULL DEFAULT '',
    coin_code        CHAR(3)       NOT NULL DEFAULT '',
    fiat_code        CHAR(3)       NOT NULL DEFAULT '',
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    is_provisional   BOOLEAN       NOT NULL DEFAULT false,
    CONSTRAINT pk_sc_adj_global PRIMARY KEY (id),
    CONSTRAINT uq_sc_adj_global UNIQUE (tenant_id, coin_code, fiat_code, rate_date)
);
```

### Columna nueva en company.adjustment_daily

```sql
-- overrides_global=true  → empresa configuró su propio valor (sobrescribe global)
-- overrides_global=false → registro de trazabilidad (hereda del global, no sobrescribe)
ALTER TABLE company.adjustment_daily
    ADD COLUMN overrides_global BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN is_provisional   BOOLEAN NOT NULL DEFAULT false;
```

### Lógica de resolución — prioridad del ajuste

```
AdjustmentResolver.resolve(company_id, currency, date):
  1. adjustment_daily WHERE company_id=X AND overrides_global=true → empresa propia
  2. adjustment_global WHERE tenant_id=T AND confirmed=true         → global confirmado
  3. adjustment_global del día anterior                            → global fallback
  4. 0.00                                                           → sin datos
```

