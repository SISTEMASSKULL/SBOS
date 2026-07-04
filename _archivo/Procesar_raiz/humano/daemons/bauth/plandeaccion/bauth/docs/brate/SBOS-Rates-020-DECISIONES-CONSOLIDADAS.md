# Decisiones Consolidadas Post-Simulación — SBOS SmartRates
## Respuestas del humano · Correcciones aplicadas · Ambigüedades resueltas

**Fecha:** 2026-05-23  
**Origen:** Informe de Simulación Interna v1.0 + respuestas del humano  
**Impacto:** 7 correcciones aplicadas a los documentos del proyecto  

---

## PRINCIPIO ARQUITECTÓNICO FUNDAMENTAL (nuevo, clarificado)

> **SmartRates es un servicio general del ecosistema SBOS.**  
> Las cotizaciones oficiales (oficial BCB, referencial BCB, USDT P2P, USDC P2P) son **globales** — iguales para todo el tenant, sin distinción de empresa.  
> Los **ajustes** (black rate, diferencial USDT, diferencial USDC) son **por empresa** — cada empresa configura los suyos según su propia realidad operativa.

Este es el patrón correcto para un servicio financiero compartido: datos de mercado centralizados, políticas de empresa descentralizadas.

---

## DECISIÓN 1 — SmartRates: servicio global con ajustes por empresa

**Pregunta resuelta:** ¿Es multi-empresa o mono-empresa?

**Respuesta del humano:** SmartRates es un servicio general compartido por todas las empresas del tenant. Las cotizaciones oficiales son globales. Lo único que varía por empresa son los **ajustes** sobre esas cotizaciones.

**Impacto en el diseño:**

```
GET /api/v1/rates/today
→ Retorna cotizaciones GLOBALES (oficial BCB, referencial BCB, USDT P2P, USDC P2P)
→ SIEMPRE las mismas independientemente de quién consulta
→ Sin ajuste aplicado

GET /api/v1/rates/today?include_company_adjustments=true
→ Igual que el anterior + agrega los ajustes de la empresa del usuario logueado
→ El endpoint usa el X-SBOS-Empresa del JWT para saber qué empresa
→ Si el request viene sin JWT (service account público): solo devuelve lo global

GET /api/v1/company/adjustment/current
→ Retorna el ajuste confirmado de HOY para la empresa del usuario logueado
→ Requiere autenticación con X-SBOS-Empresa en el JWT
```

**Qué queda en `company.*`:**
- `company.rate_config` → política de empresa (disabled/reference/national)  
- `company.adjustment_daily` → ajuste confirmado diario por empresa  
- `company.stablecoin_adjustment` → *(tabla nueva)* ajuste USDT/USDC por empresa  

**Qué está en `rates.*` (global, sin empresa):**
- `rates.exchange_rates` → cotizaciones oficiales fiat  
- `rates.stablecoin_rates` → cotizaciones USDT/USDC del mercado P2P  
- `rates.parallel_spread_log` → log de spread global  

---

## DECISIÓN 2 — Ajuste diario: por empresa, nivel global (no por sucursal)

**Respuesta del humano:** El ajuste es a nivel global del SBOS por empresa. Todas las sucursales de una empresa usan el mismo ajuste. `X-SBOS-Sucursal` no afecta al ajuste.

**Impacto:** La clave única de `company.adjustment_daily` queda como está:
```sql
UNIQUE (company_id, currency_code, rate_date)
-- NO incluye sucursal_id
```

---

## DECISIÓN 3 — USDT/USDC con política 'national': mismo flujo que USD

**Respuesta del humano:** USDT y USDC siguen exactamente la misma lógica que el black rate de USD. Los bancos bolivianos están usando el dólar paralelo oficial para aplicar el cambio USDT/USDC. Son lo mismo semánticamente.

**Impacto en el diseño:**

La política `use_black_rate` se extiende para cubrir también stablecoins:

```
use_black_rate = 'disabled'  → oficial BCB para USD, USD para USDT/USDC (peg 1:1)
use_black_rate = 'reference' → muestra black rate y P2P como referencia, no lo aplica
use_black_rate = 'national'  → aplica black rate TANTO para USD como para USDT/USDC
                               El black rate de USDT = black rate USD (misma referencia)
```

Nueva tabla para ajuste de stablecoins por empresa:

```sql
CREATE TABLE company.stablecoin_adjustment (
    id              UUID         NOT NULL DEFAULT uuidv7(),
    company_id      UUID         NOT NULL,
    coin_code       CHAR(3)      NOT NULL,  -- 'XUT' (USDT) o 'XUC' (USDC)
    fiat_code       CHAR(3)      NOT NULL,  -- 'BOB'
    rate_date       DATE         NOT NULL,
    confirmed       BOOLEAN      NOT NULL DEFAULT false,
    confirmed_by    UUID         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at    TIMESTAMPTZ  NOT NULL DEFAULT '1900-01-01 00:00:00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes           TEXT         NOT NULL DEFAULT '',
    CONSTRAINT pk_stablecoin_adj PRIMARY KEY (id),
    CONSTRAINT uq_stablecoin_adj UNIQUE (company_id, coin_code, fiat_code, rate_date)
);
-- La empresa puede ajustar el USDT/USDC de forma independiente al USD black rate
-- o dejar adjustment_value=0 para usar directamente el P2P de CriptoYa
```

---

## DECISIÓN 4 — Timeout 17:00: Opción A con UUID_SYSTEM

**Respuesta del humano:** Opción A — crea el registro provisional con el valor de ayer.

**Implementación sin violar RN-003 (NULL prohibido):**

```sql
-- En los seeds: usuario sistema predefinido
INSERT INTO users (id, name, email, role) VALUES (
    '00000000-0000-7777-0000-000000000000',  -- UUID fijo, conocido
    'SISTEMA SmartRates',
    'system@smartrates.internal',
    'system'
);
-- Este UUID es la constante UUID_SYSTEM en toda la codebase

-- Al timeout 17:00, AdjustmentTimeoutJob crea:
INSERT INTO company.adjustment_daily (
    company_id, currency_code, rate_date,
    confirmed,     -- false (no fue confirmado por humano)
    confirmed_by,  -- UUID_SYSTEM = '00000000-0000-7777-0000-000000000000'
    confirmed_at,  -- now() (timestamp del job)
    adjustment_value, -- valor del día anterior
    notes          -- 'PROVISIONAL-TIMEOUT: ajuste del día anterior aplicado automáticamente a las 17:00'
) VALUES (...);
```

**Regla de negocio nueva RN-026:**
> Cuando `confirmed_by = UUID_SYSTEM`, el ajuste es provisional y fue aplicado automáticamente por timeout. El operador PUEDE sobrescribirlo confirmando manualmente antes de las 20:00. Después de las 20:00, el provisional queda como definitivo para el día.

---

## DECISIÓN 5 — Ajuste manual = USDT P2P: son la misma referencia

**Respuesta del humano:** Son lo mismo. El operador confirma el ajuste MIRANDO el precio del USDT en Binance P2P.

**Impacto en la pantalla de ajuste (Flutter):**

La pantalla `AdjustmentScreen` DEBE mostrar el USDT P2P actual como referencia visual en tiempo real mientras el operador ingresa el ajuste:

```
┌────────────────────────────────────────────────────────────────┐
│  Confirmación de ajuste — Lunes 25/05/2026                     │
├────────────────────────────────────────────────────────────────┤
│  Tipo oficial BCB:   Compra 6.86 · Venta 6.96 · Mid 6.91      │
│  Referencial BCB:    Compra 8.83 · Venta 9.15                  │
│                                                                │
│  ── Referencia de mercado (actualización automática) ──        │
│  🔵 USDT/BOB ahora:  Compra 9.82 · Venta 10.08  ← LIVE SSE    │
│  📊 Spread vs oficial: 45.9% (promedio histórico: 25%)         │
│                                                                │
│  Ajuste sugerido basado en P2P:  +3.17  (10.08 - 6.91)        │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  Ajuste confirmado:  [ +0.50 ]  BOB   ← editable      │     │
│  └───────────────────────────────────────────────────────┘     │
│  Día anterior: +0.50  │  Resultado: Compra 7.36 · Venta 7.56  │
│                                                                │
│  Nota (opcional): _________________________                    │
│                                                                │
│           [Cancelar]      [✓ Confirmar ajuste]                │
└────────────────────────────────────────────────────────────────┘
```

El operador **ve** el USDT P2P en tiempo real pero decide libremente el ajuste. El sistema sugiere pero no fuerza.

---

## DECISIÓN 6 — Ticker: datos públicos + black rate de empresa si autenticado

**Regla definida:**

```
Sin autenticación (público):
  Ticker muestra: oficial BCB + referencial BCB + USDT P2P + USDC P2P
  
Con autenticación (usuario con empresa):
  Ticker muestra: lo anterior + black rate de la empresa (7.36/7.56)
  El black rate de empresa se muestra en color dorado diferenciado
  Atributo del Web Component: show-company-rate="true" (requiere api-key)
```

---

## DECISIÓN 7 — Stablecoins: solo BOB en v1.0, LATAM en backlog

**Respuesta implícita en el contexto:** v1.0 cubre Bolivia (BOB). CriptoYa soporta ARS, BRL, PEN, etc. — se activan en versiones futuras agregando monedas a la lista de seguimiento sin cambios de arquitectura.

---

## DECISIÓN 8 — Códigos de stablecoins: XUT y XUC (convención X-prefix)

**Investigación ISO 4217 confirmó:**
- ISO 4217 reserva el prefijo X para activos no nacionales — fondos, metales, el DEG del FMI, y el placeholder XXX.
- No hay código ISO 4217 oficial para Bitcoin, Ether ni ninguna criptomoneda. ISO/TC 68/SC 8 ha discutido un estándar para activos digitales pero a 2026 nada fue ratificado.
- La industria usa XBT para Bitcoin siguiendo la convención X-prefix.

**Decisión para SmartRates:**
Usar la convención X-prefix de ISO 4217 para stablecoins:

```
XUT → USDT (Tether USD)      X + UT = eXternal Unstated Tether
XUC → USDC (USD Coin)        X + UC = eXternal Unstated Coin
```

Estos códigos:
- Siguen la convención ISO X-prefix para no-nacionales
- No colisionan con ningún código ISO 4217 actual ni histórico
- Son autodescriptivos en el sistema
- Se documentan explícitamente como **códigos internos SmartRates** (no ISO estándar)

```sql
-- Columna correcta: is_stablecoin (no is_crypto)
-- USDT
currency_code = 'XUT', is_stablecoin = true, peg_to = 'USD', crypto_ticker = 'USDT'

-- USDC  
currency_code = 'XUC', is_stablecoin = true, peg_to = 'USD', crypto_ticker = 'USDC'
```

---

## DECISIÓN 9 — Una sola base de datos: smartrates_db

**Respuesta del humano:** Todo en una sola BD exclusiva para el manejo de rates.

**Impacto — reestructuración de schemas:**

```
smartrates_db (única BD)
├── catalog/      → monedas, países, bloques, tipos de black rate
├── rates/        → exchange_rates, stablecoin_rates, spread_log, fuentes, tipos
├── company/      → configuración por empresa, ajuste_daily, stablecoin_adjustment
├── sync/         → circuit_breaker, sync_log, backfill_progress
├── security/     → audit_log, error_catalog
├── validation/   → bcb_cotizaciones, bcb_vs_oficial, currency_mapping (ANTES era BD separada)
├── historical/   → bcb_rates 1990-2015 (ANTES era BD separada)
└── broadcast/    → messages para el Ticker
```

**Se eliminan:**
- `smartrates_db (schema validation)` — sus datos pasan al schema `validation` dentro de `smartrates_db`

**Ventaja:** `catalog.RATE()` accede a todo en el mismo cluster sin cross-DB queries. El SPI de la extensión C trabaja dentro de una sola base de datos.

---

## Nuevas reglas de negocio (RN-026 a RN-030)

**RN-026:** Cuando `company.adjustment_daily.confirmed_by = UUID_SYSTEM`, el ajuste es provisional por timeout. El operador puede sobrescribirlo hasta las 20:00.

**RN-027:** Las cotizaciones globales (`rates.exchange_rates`, `rates.stablecoin_rates`) son de solo lectura para todas las empresas — ninguna empresa puede modificar los datos de mercado.

**RN-028:** Los ajustes por empresa (`company.adjustment_daily`, `company.stablecoin_adjustment`) solo afectan a los cálculos de esa empresa. Nunca modifican los datos globales.

**RN-029:** USDT (XUT) y USDC (XUC) siguen la misma política `use_black_rate` que el USD para las empresas con política `national`. El black rate de USDT = black rate de USD de la empresa.

**RN-030:** El Ticker muestra datos globales sin autenticación. Con autenticación y `show-company-rate="true"`, agrega el black rate de la empresa en color dorado.

---
_SKULL · SBOS · SmartRates · 020-DECISIONES-CONSOLIDADAS · v1.0 · 2026-05-23_
