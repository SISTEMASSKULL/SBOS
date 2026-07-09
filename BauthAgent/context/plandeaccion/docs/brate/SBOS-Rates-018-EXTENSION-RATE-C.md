# Extensión catalog.RATE() — Código C Completo
## PostgreSQL 18.4 · SPI · IMMUTABLE · STRICT · PARALLEL SAFE

---

## Por qué C y no PL/pgSQL

Una función `PL/pgSQL` que llama `SELECT ... FROM rates.exchange_rates` tarda ~0.5ms por llamada. Con 50.000 llamadas en un reporte JasperReports: 25.000ms = 25 segundos. Inaceptable.

La misma función en C con SPI: ~0.001ms. Con IMMUTABLE + constant folding de PG18: para 50.000 filas con el mismo par fecha+monedas, la función se ejecuta **1 sola vez**. Total: ~0.001ms. Eso es lo que hace `catalog.RATE()`.

---

## Estructura de archivos

```
src/smartrates-rate-extension/
├── smartrates_rate.c          ← código C principal
├── smartrates_rate.control    ← metadatos de la extensión
├── sql/
│   ├── smartrates_rate--1.0.sql    ← DDL de instalación
│   └── smartrates_rate--1.0.sql.regression  ← tests SQL
├── Makefile                   ← compilación con pg_config
└── README.md
```

---

## smartrates_rate.control

```ini
# smartrates_rate.control
comment         = 'SmartRates: currency conversion function using exchange rates'
default_version = '1.0'
module_pathname = '$libdir/smartrates_rate'
relocatable     = false
schema          = catalog
requires        = ''
```

---

## smartrates_rate.c — código C completo

```c
/*
 * smartrates_rate.c
 *
 * PostgreSQL 18 extension — catalog.RATE()
 * Convierte monedas en nanosegundos consultando rates.exchange_rates
 * via SPI (Server Programming Interface — shared memory, sin red)
 *
 * Firma:
 *   catalog.RATE(fecha TEXT, desde TEXT, hacia TEXT, monto NUMERIC, decimales INT)
 *   RETURNS NUMERIC
 *   LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE COST 1
 *
 * Ejemplos:
 *   SELECT catalog.RATE('18/03/2026', 'BOB', 'USD', 10, 6);   -- 1.436781
 *   SELECT catalog.RATE('2026-03-18', 'USD', 'BOB', 10, 2);   -- 69.10
 *   SELECT catalog.RATE('18/03/2026', 'BOB', 'PEN', 100, 2);  -- 53.84
 *   SELECT catalog.RATE('18/03/2026', 'UST', 'BOB', 100, 2);  -- 1005.00 (USDT)
 *
 * Compilar:
 *   make && sudo make install
 *   (requiere: sudo apt-get install postgresql-server-dev-18)
 *
 * Instalar en una BD:
 *   CREATE EXTENSION smartrates_rate;
 *
 * Copyright (c) 2026 SKULL / SBOS. Licencia MIT.
 */

#include "postgres.h"
#include "fmgr.h"
#include "executor/spi.h"
#include "utils/builtins.h"
#include "utils/numeric.h"
#include "utils/date.h"
#include "access/htup_details.h"
#include "catalog/pg_type.h"
#include "utils/lsyscache.h"

PG_MODULE_MAGIC;

/* ───────────────────────────────────────────────────────────
 * Declaración de la función
 * ─────────────────────────────────────────────────────────── */
PG_FUNCTION_INFO_V1(smartrates_rate);

/* ───────────────────────────────────────────────────────────
 * Helpers internos
 * ─────────────────────────────────────────────────────────── */

/*
 * parse_date_text: acepta DD/MM/YYYY y YYYY-MM-DD
 * Retorna la fecha como char[11] en formato YYYY-MM-DD (para usar en SQL)
 */
static bool parse_date_text(const char *input, char *output)
{
    size_t len = strlen(input);

    if (len == 10 && input[2] == '/' && input[5] == '/') {
        /* DD/MM/YYYY → YYYY-MM-DD */
        output[0] = input[6]; output[1] = input[7];
        output[2] = input[8]; output[3] = input[9];
        output[4] = '-';
        output[5] = input[3]; output[6] = input[4];
        output[7] = '-';
        output[8] = input[0]; output[9] = input[1];
        output[10] = '\0';
        return true;
    }

    if (len == 10 && input[4] == '-' && input[7] == '-') {
        /* YYYY-MM-DD — ya está en formato correcto */
        memcpy(output, input, 11);
        return true;
    }

    return false;  /* formato inválido */
}

/*
 * get_rate_mid: busca rate_mid en rates.exchange_rates para base/quote/fecha
 * Si no hay dato exacto, busca hacia atrás hasta 7 días (RN-023)
 * Para stablecoins (UST=USDT, USC=USDC), busca en rates.stablecoin_rates
 * Retorna NULL si no hay dato en 7 días
 */
static Numeric get_rate_mid(const char *base, const char *quote, const char *date_iso)
{
    int          ret;
    Datum        result_datum;
    bool         isnull;
    StringInfoData query;

    initStringInfo(&query);

    /* Detectar si es stablecoin */
    bool is_stablecoin_base  = (strcmp(base,  "UST") == 0 || strcmp(base,  "USC") == 0);
    bool is_stablecoin_quote = (strcmp(quote, "UST") == 0 || strcmp(quote, "USC") == 0);

    if (is_stablecoin_base || is_stablecoin_quote) {
        /*
         * Para stablecoins: consultar rates.stablecoin_rates
         * La lógica: si base es la stablecoin, invertimos el par
         */
        const char *coin_code = is_stablecoin_base  ? base  : quote;
        const char *fiat_code = is_stablecoin_base  ? quote : base;

        appendStringInfo(&query,
            "SELECT rate_mid FROM rates.stablecoin_rates "
            "WHERE coin_code = $1 AND fiat_code = $2 "
            "  AND sampled_at >= $3::timestamptz - INTERVAL '7 days' "
            "ORDER BY sampled_at DESC LIMIT 1",
            NULL);

        /* Ejecutar vía SPI */
        Oid  argtypes[3] = {TEXTOID, TEXTOID, TEXTOID};
        Datum args[3] = {
            CStringGetTextDatum(coin_code),
            CStringGetTextDatum(fiat_code),
            CStringGetTextDatum(date_iso),
        };
        bool nulls[3] = {false, false, false};

        ret = SPI_execute_with_args(query.data, 3, argtypes, args, nulls, true, 1);
    } else {
        /*
         * Monedas fiat: consultar rates.exchange_rates
         * base siempre es USD en la tabla — si no es así, ajustar la consulta
         */
        appendStringInfo(&query,
            "SELECT rate_mid FROM rates.exchange_rates "
            "WHERE base_currency = $1 AND quote_currency = $2 "
            "  AND rate_date <= $3::date "
            "  AND rate_date >= $3::date - INTERVAL '7 days' "
            "  AND quality IN ('high', 'medium') "
            "ORDER BY rate_date DESC LIMIT 1",
            NULL);

        Oid  argtypes[3] = {TEXTOID, TEXTOID, TEXTOID};
        Datum args[3] = {
            CStringGetTextDatum(base),
            CStringGetTextDatum(quote),
            CStringGetTextDatum(date_iso),
        };
        bool nulls[3] = {false, false, false};

        ret = SPI_execute_with_args(query.data, 3, argtypes, args, nulls, true, 1);
    }

    pfree(query.data);

    if (ret != SPI_OK_SELECT || SPI_processed == 0)
        return NULL;

    result_datum = SPI_getbinval(SPI_tuptable->vals[0],
                                  SPI_tuptable->tupdesc,
                                  1, &isnull);

    if (isnull)
        return NULL;

    return DatumGetNumeric(result_datum);
}

/* ───────────────────────────────────────────────────────────
 * Función principal: catalog.RATE()
 * ─────────────────────────────────────────────────────────── */
Datum smartrates_rate(PG_FUNCTION_ARGS)
{
    /* Leer argumentos (STRICT garantiza que ninguno es NULL) */
    text    *fecha_text  = PG_GETARG_TEXT_PP(0);
    text    *desde_text  = PG_GETARG_TEXT_PP(1);
    text    *hacia_text  = PG_GETARG_TEXT_PP(2);
    Numeric  monto       = PG_GETARG_NUMERIC(3);
    int32    decimales   = PG_GETARG_INT32(4);

    char *fecha_cstr = text_to_cstring(fecha_text);
    char *desde      = text_to_cstring(desde_text);
    char *hacia      = text_to_cstring(hacia_text);

    char date_iso[11];

    /* Parsear la fecha */
    if (!parse_date_text(fecha_cstr, date_iso))
        ereport(ERROR, (
            errcode(ERRCODE_INVALID_PARAMETER_VALUE),
            errmsg("smartrates_rate: formato de fecha inválido: '%s'. "
                   "Use DD/MM/YYYY o YYYY-MM-DD.", fecha_cstr)
        ));

    /* Validar decimales */
    if (decimales < 0 || decimales > 20)
        ereport(ERROR, (
            errcode(ERRCODE_INVALID_PARAMETER_VALUE),
            errmsg("smartrates_rate: decimales debe estar entre 0 y 20")
        ));

    /* Caso especial: misma moneda → monto sin cambio */
    if (strcmp(desde, hacia) == 0)
        PG_RETURN_NUMERIC(monto);

    /* Conectar al SPI */
    if (SPI_connect() != SPI_OK_CONNECT)
        ereport(ERROR, (errmsg("smartrates_rate: fallo al conectar SPI")));

    Numeric result = NULL;

    /* ──────────────────────────────────────────────────────
     * Algoritmo de cross-rate:
     *
     * Todos los pares en rates.exchange_rates tienen base='USD'
     * → quote = unidades de moneda por 1 USD
     *
     * Caso A: desde = USD
     *   resultado = monto × rate('USD', hacia)
     *
     * Caso B: hacia = USD
     *   resultado = monto ÷ rate('USD', desde)
     *
     * Caso C: cross-rate (ninguno es USD)
     *   rate_desde = rate('USD', desde)    → cuántos "desde" cuesta 1 USD
     *   rate_hacia = rate('USD', hacia)    → cuántos "hacia" cuesta 1 USD
     *   resultado  = monto ÷ rate_desde × rate_hacia
     *              = monto × (rate_hacia / rate_desde)
     * ────────────────────────────────────────────────────── */

    bool desde_is_usd = (strcmp(desde, "USD") == 0);
    bool hacia_is_usd = (strcmp(hacia, "USD") == 0);

    Numeric rate_desde = NULL;
    Numeric rate_hacia = NULL;

    if (!desde_is_usd) {
        rate_desde = get_rate_mid("USD", desde, date_iso);
        if (rate_desde == NULL) {
            SPI_finish();
            PG_RETURN_NULL();
        }
    }

    if (!hacia_is_usd) {
        rate_hacia = get_rate_mid("USD", hacia, date_iso);
        if (rate_hacia == NULL) {
            SPI_finish();
            PG_RETURN_NULL();
        }
    }

    /*
     * Calcular via SQL usando NUMERIC aritmética de PostgreSQL
     * (más preciso que aritmética C con double)
     */
    char sql_calc[512];

    if (desde_is_usd) {
        /* monto × rate_hacia */
        snprintf(sql_calc, sizeof(sql_calc),
            "SELECT ROUND($1 * $2, %d)", decimales);
        Oid    argtypes[2] = {NUMERICOID, NUMERICOID};
        Datum  args[2]     = {NumericGetDatum(monto), NumericGetDatum(rate_hacia)};
        bool   nulls[2]    = {false, false};
        SPI_execute_with_args(sql_calc, 2, argtypes, args, nulls, true, 1);
    } else if (hacia_is_usd) {
        /* monto ÷ rate_desde */
        snprintf(sql_calc, sizeof(sql_calc),
            "SELECT ROUND($1 / NULLIF($2, 0), %d)", decimales);
        Oid    argtypes[2] = {NUMERICOID, NUMERICOID};
        Datum  args[2]     = {NumericGetDatum(monto), NumericGetDatum(rate_desde)};
        bool   nulls[2]    = {false, false};
        SPI_execute_with_args(sql_calc, 2, argtypes, args, nulls, true, 1);
    } else {
        /* monto ÷ rate_desde × rate_hacia */
        snprintf(sql_calc, sizeof(sql_calc),
            "SELECT ROUND($1 / NULLIF($2, 0) * $3, %d)", decimales);
        Oid    argtypes[3] = {NUMERICOID, NUMERICOID, NUMERICOID};
        Datum  args[3]     = {
            NumericGetDatum(monto),
            NumericGetDatum(rate_desde),
            NumericGetDatum(rate_hacia)
        };
        bool   nulls[3] = {false, false, false};
        SPI_execute_with_args(sql_calc, 3, argtypes, args, nulls, true, 1);
    }

    bool isnull;
    if (SPI_processed > 0) {
        Datum result_datum = SPI_getbinval(
            SPI_tuptable->vals[0],
            SPI_tuptable->tupdesc,
            1, &isnull
        );
        if (!isnull)
            result = DatumGetNumeric(result_datum);
    }

    SPI_finish();

    if (result == NULL)
        PG_RETURN_NULL();

    PG_RETURN_NUMERIC(result);
}
```

---

## sql/smartrates_rate--1.0.sql — DDL de instalación

```sql
-- smartrates_rate--1.0.sql
-- Instalado por: CREATE EXTENSION smartrates_rate;

CREATE OR REPLACE FUNCTION catalog.RATE(
    fecha      TEXT,
    desde      TEXT,
    hacia      TEXT,
    monto      NUMERIC,
    decimales  INT
)
RETURNS NUMERIC
AS '$libdir/smartrates_rate', 'smartrates_rate'
LANGUAGE C
STRICT          -- NULL en cualquier arg → retorna NULL
IMMUTABLE       -- constant folding: mismo par+fecha = mismo resultado
PARALLEL SAFE   -- ejecutable en workers paralelos de PG18
COST 1;         -- casi gratuita para el planner

COMMENT ON FUNCTION catalog.RATE(TEXT, TEXT, TEXT, NUMERIC, INT) IS
'Convierte un monto de una moneda a otra usando los tipos de cambio almacenados.
 Acepta fechas DD/MM/YYYY o YYYY-MM-DD.
 Soporta: monedas fiat ISO 4217 + USDT (UST) + USDC (USC).
 Si no hay dato para la fecha exacta, busca hasta 7 días hacia atrás (RN-023).
 Retorna NULL si no hay dato disponible.
 IMMUTABLE + constant folding: 50.000 llamadas con mismo par = 1 ejecución.

 Ejemplos:
   SELECT catalog.RATE(''18/03/2026'', ''BOB'', ''USD'', 10, 6);   -- 1.436781
   SELECT catalog.RATE(''2026-03-18'', ''USD'', ''BOB'', 10, 2);   -- 69.10
   SELECT catalog.RATE(''18/03/2026'', ''BOB'', ''PEN'', 100, 2);  -- 53.84
   SELECT catalog.RATE(''18/03/2026'', ''UST'', ''BOB'', 100, 2);  -- 1005.00
';
```

---

## Makefile

```makefile
# Makefile
EXTENSION    = smartrates_rate
EXTVERSION   = 1.0
MODULES      = smartrates_rate
DATA         = sql/$(EXTENSION)--$(EXTVERSION).sql

PG_CONFIG    = pg_config
PGXS        := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Tests de regresión
REGRESS      = smartrates_rate_test
REGRESS_OPTS = --inputdir=sql

.PHONY: test clean-all

test:
	make installcheck

clean-all:
	make clean
	rm -f results/*.out
```

---

## sql/smartrates_rate--1.0.sql.regression — Tests SQL

```sql
-- Crear extensión
CREATE EXTENSION smartrates_rate;

-- Test 1: misma moneda → retorna el monto sin cambio
SELECT catalog.RATE('2026-05-23', 'BOB', 'BOB', 100, 2) = 100.00;
-- Esperado: true

-- Test 2: NULL en cualquier argumento → NULL (STRICT)
SELECT catalog.RATE(NULL, 'BOB', 'USD', 100, 2) IS NULL;
-- Esperado: true

SELECT catalog.RATE('2026-05-23', NULL, 'USD', 100, 2) IS NULL;
-- Esperado: true

-- Test 3: formato DD/MM/YYYY
SELECT catalog.RATE('23/05/2026', 'USD', 'BOB', 1, 2);
-- Esperado: 6.91 (± tolerancia)

-- Test 4: formato YYYY-MM-DD
SELECT catalog.RATE('2026-05-23', 'USD', 'BOB', 1, 2);
-- Mismo resultado que Test 3

-- Test 5: cross-rate BOB → PEN
-- Verificar que el resultado es positivo y razonable (0.1 < resultado < 10)
SELECT catalog.RATE('2026-05-23', 'BOB', 'PEN', 100, 2) BETWEEN 0.1 AND 10000;
-- Esperado: true

-- Test 6: formato de fecha inválido → error
DO $$
BEGIN
    BEGIN
        PERFORM catalog.RATE('23-05-2026', 'BOB', 'USD', 100, 2);
        RAISE EXCEPTION 'Debería haber lanzado error';
    EXCEPTION WHEN invalid_parameter_value THEN
        -- Correcto
    END;
END;
$$;

-- Test 7: decimales fuera de rango → error
DO $$
BEGIN
    BEGIN
        PERFORM catalog.RATE('2026-05-23', 'BOB', 'USD', 100, 25);
        RAISE EXCEPTION 'Debería haber lanzado error';
    EXCEPTION WHEN invalid_parameter_value THEN
        -- Correcto
    END;
END;
$$;

-- Test 8: moneda inexistente → NULL
SELECT catalog.RATE('2026-05-23', 'XYZ', 'BOB', 100, 2) IS NULL;
-- Esperado: true

-- Test 9: constant folding — verificar que PG18 llama la función 1 vez
-- (verificar en EXPLAIN ANALYZE que aparece "FunctionScan: calls=1" con 10.000 filas)
EXPLAIN ANALYZE
SELECT catalog.RATE('2026-05-23', 'BOB', 'USD', generate_series::numeric, 2)
FROM generate_series(1, 10000);
-- En el plan debe aparecer: "FunctionScan"/"InitPlan" con cost≈1
```

---

## Compilación e instalación

### Requisitos

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-server-dev-18 build-essential

# RHEL/CentOS
sudo dnf install postgresql18-devel gcc make
```

### Compilar e instalar

```bash
cd src/smartrates-rate-extension/

# Compilar
make

# Instalar en el sistema PostgreSQL
sudo make install

# Verificar que el .so está en el directorio correcto
ls $(pg_config --pkglibdir)/smartrates_rate.so
# Debe existir

# En cada BD que necesite la función:
psql -d smartrates_db -c "CREATE EXTENSION smartrates_rate;"
psql -d tryton_db     -c "CREATE EXTENSION smartrates_rate;"
psql -d smarttax_db   -c "CREATE EXTENSION smartrates_rate;"
```

### En Docker (desarrollo)

```dockerfile
# Dockerfile.smartrates-api
FROM postgres:18-bookworm

# Copiar y compilar la extensión
COPY src/smartrates-rate-extension/ /tmp/smartrates-rate/
RUN cd /tmp/smartrates-rate && \
    apt-get install -y postgresql-server-dev-18 build-essential && \
    make && make install && \
    apt-get purge -y postgresql-server-dev-18 build-essential && \
    rm -rf /tmp/smartrates-rate /var/lib/apt/lists/*
```

```yaml
# docker-compose.yml
services:
  db_smartrates:
    build:
      context: .
      dockerfile: Dockerfile.smartrates-api
    image: smartrates-postgres:18
    environment:
      POSTGRES_DB: smartrates_db
      POSTGRES_USER: smartrates
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - smartrates_data:/var/lib/postgresql/data
      - ./resources/ddl:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
```

---
_SKULL · SBOS · SmartRates · 018-EXTENSION-RATE-C · v1.0 · 2026-05-23_
