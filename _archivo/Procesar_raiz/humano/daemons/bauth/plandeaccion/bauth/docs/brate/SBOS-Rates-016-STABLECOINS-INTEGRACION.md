# USDT y USDC — Integración Completa — SBOS SmartRates
## Investigación de mercado · APIs verificadas · Implementación Laravel 13

---

## Por qué USDT y USDC son cotizaciones de negocio, no solo cripto

En Bolivia 2026, USDT y USDC no son instrumentos especulativos — son el **dólar digital de facto**. Las diferencias entre ambas:

### USDT — Tether (la más usada en Bolivia)

- Diseñado con transparencia y seguridad, USDC tiene más de $70 billones en circulación — USDT supera los $144 billones en capitalización.
- **En Bolivia:** Banco Bisa lanza custodia USDT Oct-2024. Banco de Crédito lanza cuentas USDT 2025. Toyota, BYD, Yamaha aceptan USDT. Menus en USDT en restaurantes urbanos.
- **Red preferida en Bolivia:** TRC20 (Tron) — en 2026 una transferencia TRC20 típica se liquida en 3 segundos por $1.00-$3.50 de TRX, razón por la que aproximadamente la mitad de todo el suministro de USDT ahora vive en Tron.
- **Emisor:** Tether Ltd. — reservas en efectivo y bonos del Tesoro USA
- **Auditorías:** cuatrimestrales (menos frecuentes que USDC — punto de debate)

### USDC — Circle (la más regulada, creciendo en empresas)

- USDC está completamente respaldado por activos líquidos en dólares, incluyendo bonos del Tesoro USA a corto plazo, y sus reservas son validadas mensualmente por una firma Big Four.
- **Redes disponibles:** USDC tiene soporte nativo en 28 redes blockchain incluyendo Ethereum, Solana, Avalanche, Polygon, Base, y más. Para Bolivia: **Solana** y **Base** son las más económicas.
- **En Bolivia empresas:** Bitso soporta USDT y USDC con presencia creciente en Bolivia. Mural Pay usa USDC para pagos B2B. Empresas importadoras prefieren USDC por sus auditorías mensuales.
- **Capitalización 2026:** ~$76 billones (segunda stablecoin del mundo)
- **Emisor:** Circle Internet Group — Circle planea expandir infraestructura a lo largo de 2026 para impulsar mayor adopción entre empresas e instituciones.

### Diferencia práctica para SmartRates

| Aspecto | USDT | USDC |
|---|---|---|
| Adopción Bolivia | Dominante — mercado masivo | Creciente — empresas/instituciones |
| Red más usada en Bolivia | TRC20 (Tron) | Solana / Base |
| Precio vs BOB | ~Bs 10.05 (mediana P2P) | ~Bs 10.02 (ligeramente menor) |
| Liquidez en Binance P2P BOB | Muy alta | Media |
| Confianza corporativa | Alta | Muy alta (auditorías mensuales) |
| Uso en SBOS | Pagos cotidianos, remesas | Pagos B2B, facturas internacionales |

---

## API CriptoYa — Fuente oficial verificada

La API pública de CriptoYa se actualiza cada 1 minuto con un límite de 120 requests por minuto. La base URL es `https://criptoya.com/api`.

### Endpoints verificados para Bolivia

```
# Cotización general — todos los exchanges de una vez
GET https://criptoya.com/api/USDT/BOB/1
GET https://criptoya.com/api/USDC/BOB/1

# Por exchange específico
GET https://criptoya.com/api/{exchange}/USDT/BOB/1
GET https://criptoya.com/api/{exchange}/USDC/BOB/1
```

Los exchanges disponibles para Bolivia son: `coinexp2p`, `bitgetp2p`, `binancep2p`, `mexcp2p`, `bybitp2p`, `saldo`, `eldoradop2p`, `xapo`.

### Respuesta de la API CriptoYa

```json
{
  "ask": 10.08,
  "totalAsk": 10080.00,
  "bid": 9.82,
  "totalBid": 9820.00,
  "time": 1748044800
}
```

- `ask` → precio de venta (para comprar USDT con BOB — más caro)
- `bid` → precio de compra (para vender USDT por BOB — más barato)
- `time` → Unix timestamp de la última actualización

### Respuesta general (todos los exchanges)

```json
{
  "binancep2p": {"ask": 10.12, "totalAsk": 10120.00, "bid": 9.78, "totalBid": 9780.00, "time": 1748044800},
  "bitgetp2p":  {"ask": 10.15, "totalAsk": 10150.00, "bid": 9.80, "totalBid": 9800.00, "time": 1748044750},
  "bybitp2p":   {"ask": 10.10, "totalAsk": 10100.00, "bid": 9.81, "totalBid": 9810.00, "time": 1748044790},
  "eldoradop2p":{"ask": 10.18, "totalAsk": 10180.00, "bid": 9.75, "totalBid": 9750.00, "time": 1748044760}
}
```

**Mediana calculada por SmartRates** = mediana de todos los `ask` y mediana de todos los `bid`

---

## Modelo de datos — cambios requeridos

### 1. Nuevas columnas en catalog.currencies

```sql
-- Agregar a la tabla existente
ALTER TABLE catalog.currencies
    ADD COLUMN is_stablecoin    BOOLEAN      NOT NULL DEFAULT false,
    ADD COLUMN crypto_network   VARCHAR(50)  NOT NULL DEFAULT '',
    ADD COLUMN peg_to           CHAR(3)      NOT NULL DEFAULT '',
    ADD COLUMN crypto_issuer    VARCHAR(100) NOT NULL DEFAULT '';

-- USDT — Tether
INSERT INTO catalog.currencies (
    currency_code, currency_numeric, currency_minor_unit,
    name_es_singular, name_es_plural, name_en_singular, name_en_plural,
    name_es_country, name_en_country,
    symbol, symbol_native, symbol_position,
    decimal_separator, thousands_separator,
    country_code_alpha2, flag_emoji, flag_unicode,
    is_active, is_stablecoin, crypto_network, peg_to, crypto_issuer
) VALUES (
    'UST', '900', 2,
    'Tether USD', 'Tether USD', 'Tether USD', 'Tether USD',
    'Tether USD (USDT)', 'Tether USD (USDT)',
    'USDT', 'USDT', 'before',
    '.', ',',
    NULL, '🔵', 'U+1F535',
    true, true, 'TRC20,ERC20,BEP20,SOL', 'USD', 'Tether Ltd.'
);

-- USDC — Circle
INSERT INTO catalog.currencies (
    currency_code, currency_numeric, currency_minor_unit,
    name_es_singular, name_es_plural, name_en_singular, name_en_plural,
    name_es_country, name_en_country,
    symbol, symbol_native, symbol_position,
    decimal_separator, thousands_separator,
    country_code_alpha2, flag_emoji, flag_unicode,
    is_active, is_stablecoin, crypto_network, peg_to, crypto_issuer
) VALUES (
    'USC', '901', 2,
    'USD Coin', 'USD Coin', 'USD Coin', 'USD Coin',
    'USD Coin (USDC)', 'USD Coin (USDC)',
    'USDC', 'USDC', 'before',
    '.', ',',
    NULL, '🔵', 'U+1F535',
    true, true, 'ETH,SOL,BASE,MATIC,AVAX', 'USD', 'Circle Internet Group'
);
```

### 2. Nueva fuente en rates.data_sources

```sql
INSERT INTO rates.data_sources VALUES
    ('criptoya_p2p',    'CriptoYa P2P Bolivia',       'https://criptoya.com/api', 'public', true,  1),
    ('bcb_referencial', 'BCB Valor Referencial (VRD)', 'https://www.bcb.gob.bo',  'public', true,  1),
    ('binance_p2p',     'Binance P2P Bolivia',         'https://p2p.binance.com', 'public', false, 2);

-- bcb_referencial: el nuevo VRD/VRV publicado desde dic 2025
-- criptoya_p2p: mediana de todos los exchanges P2P en BOB
-- binance_p2p: fuente primaria (Binance lidera volumen en Bolivia)
```

### 3. Nuevo tipo de dato en rates.data_types

```sql
INSERT INTO rates.data_types VALUES
    ('parallel_daily',   'Mercado paralelo P2P — mediana diaria',   'medium'),
    ('parallel_hourly',  'Mercado paralelo P2P — mediana horaria',  'medium'),
    ('referential_daily','BCB Valor Referencial — operaciones EIF',  'high');
```

### 4. Tabla rates.stablecoin_rates (alta frecuencia horaria)

```sql
CREATE TABLE rates.stablecoin_rates (
    id                  UUID            NOT NULL DEFAULT uuidv7(),
    coin_code           CHAR(3)         NOT NULL,  -- 'XUT' (USDT) o 'XUC' (USDC)
    fiat_code           CHAR(3)         NOT NULL,  -- 'BOB'
    rate_ask            NUMERIC(20,8)   NOT NULL DEFAULT 0.00000000,  -- precio compra (más caro)
    rate_bid            NUMERIC(20,8)   NOT NULL DEFAULT 0.00000000,  -- precio venta (más barato)
    rate_mid            NUMERIC(20,8)   GENERATED ALWAYS AS ((rate_ask + rate_bid) / 2) VIRTUAL,
    spread_pct          NUMERIC(8,4)    GENERATED ALWAYS AS
                            (CASE WHEN rate_bid > 0
                             THEN ROUND(((rate_ask / rate_bid) - 1) * 100, 4)
                             ELSE 0 END) VIRTUAL,
    source_code         VARCHAR(30)     NOT NULL DEFAULT 'criptoya_p2p',
    exchanges_sampled   INTEGER         NOT NULL DEFAULT 0,
    sampled_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_stablecoin_rates PRIMARY KEY (id),
    CONSTRAINT uq_stablecoin_rates UNIQUE (coin_code, fiat_code, source_code, sampled_at)
) PARTITION BY RANGE (sampled_at);

-- Particiones mensuales (alta frecuencia — muchos registros/mes)
CREATE TABLE rates.stablecoin_rates_y2026m05
    PARTITION OF rates.stablecoin_rates
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
-- ... se crean con MonthlyPartitionCreateJob
```

### 5. Tabla rates.parallel_spread_log

```sql
CREATE TABLE rates.parallel_spread_log (
    id                      UUID         NOT NULL DEFAULT uuidv7(),
    log_date                DATE         NOT NULL,
    log_hour                SMALLINT     NOT NULL DEFAULT 0,
    official_mid            NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    referencial_bid         NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    referencial_ask         NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    usdt_bid                NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    usdt_ask                NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    usdc_bid                NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    usdc_ask                NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    spread_official_usdt    NUMERIC(8,4)  GENERATED ALWAYS AS
                                (CASE WHEN official_mid > 0
                                 THEN ROUND(((usdt_ask / official_mid) - 1) * 100, 4)
                                 ELSE 0 END) VIRTUAL,
    spread_ref_usdt         NUMERIC(8,4)  GENERATED ALWAYS AS
                                (CASE WHEN referencial_ask > 0
                                 THEN ROUND(((usdt_ask / referencial_ask) - 1) * 100, 4)
                                 ELSE 0 END) VIRTUAL,
    alert_level             VARCHAR(10)   NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_spread_log PRIMARY KEY (id),
    CONSTRAINT uq_spread_log UNIQUE (log_date, log_hour)
) PARTITION BY RANGE (log_date);
```

---

## Jobs de sincronización — implementación Laravel 13

### DailySyncUsdtP2pJob

```php
<?php
// app/Jobs/Sync/DailySyncUsdtP2pJob.php

namespace App\Jobs\Sync;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Http;
use App\Models\Rates\StablecoinRate;
use App\Models\Rates\ParallelSpreadLog;
use App\Events\Rates\StablecoinRatesUpdated;

class DailySyncUsdtP2pJob implements ShouldQueue
{
    use Queueable;

    // Corre cada hora via scheduler
    // SYNC_MODE=internal: llama CriptoYa directamente
    // SYNC_MODE=biedata: esta job no corre — biedata ejecuta la caja

    private const CRIPTOYA_BASE = 'https://criptoya.com/api';
    private const COINS         = ['USDT', 'USDC'];  // ambas stablecoins
    private const FIAT          = 'BOB';
    private const VOLUME        = '1';

    public function handle(): void
    {
        if (config('smartrates.sync_mode') === 'biedata') {
            return; // biedata gestiona esto en producción SBOS
        }

        foreach (self::COINS as $coin) {
            $this->syncCoin($coin);
        }

        // Actualizar el log de spread después de tener USDT y USDC
        $this->updateSpreadLog();

        // Emitir evento WebSocket a SmartRatesUI (Reverb)
        broadcast(new StablecoinRatesUpdated());

        // pg_notify → SSE → Ticker se actualiza en tiempo real
        \DB::statement("SELECT pg_notify('rates_channel', '{}')");
    }

    private function syncCoin(string $coin): void
    {
        // Obtener mediana de todos los exchanges de una vez
        $url      = self::CRIPTOYA_BASE . "/{$coin}/" . self::FIAT . '/' . self::VOLUME;
        $coinCode = $coin === 'USDT' ? 'UST' : 'USC';

        $response = Http::timeout(15)
            ->retry(3, 2000)
            ->get($url);

        if (! $response->successful()) {
            \Log::warning("CriptoYa sync failed for {$coin}", [
                'status' => $response->status(),
                'ctx_id' => '',
            ]);
            return;
        }

        $data = $response->json();

        // Calcular mediana de ask y bid entre todos los exchanges
        $asks = array_filter(array_column($data, 'ask'));
        $bids = array_filter(array_column($data, 'bid'));

        if (empty($asks) || empty($bids)) {
            return;
        }

        sort($asks);
        sort($bids);

        $medianAsk = $this->median($asks);
        $medianBid = $this->median($bids);

        StablecoinRate::upsert([
            'coin_code'        => $coinCode,
            'fiat_code'        => 'BOB',
            'rate_ask'         => round($medianAsk, 8),
            'rate_bid'         => round($medianBid, 8),
            'source_code'      => 'criptoya_p2p',
            'exchanges_sampled'=> count($asks),
            'sampled_at'       => now()->startOfHour(), // agrupa por hora
        ], ['coin_code', 'fiat_code', 'source_code', 'sampled_at'],
           ['rate_ask', 'rate_bid', 'exchanges_sampled']);
    }

    private function updateSpreadLog(): void
    {
        $official   = \DB::selectOne("
            SELECT rate_mid FROM rates.exchange_rates
            WHERE base_currency='USD' AND quote_currency='BOB'
              AND source_code='bcb_bolivia'
              AND rate_date = CURRENT_DATE
            ORDER BY created_at DESC LIMIT 1
        ");
        $referencial = \DB::selectOne("
            SELECT rate_buy, rate_sell FROM validation.bcb_cotizaciones
            WHERE rate_date = CURRENT_DATE
              AND currency_code_iso = 'BOB'
              AND data_type = 'referential'
            ORDER BY created_at DESC LIMIT 1
        ");
        $usdt = StablecoinRate::where('coin_code', 'UST')
            ->where('fiat_code', 'BOB')
            ->where('sampled_at', now()->startOfHour())
            ->first();
        $usdc = StablecoinRate::where('coin_code', 'USC')
            ->where('fiat_code', 'BOB')
            ->where('sampled_at', now()->startOfHour())
            ->first();

        if (! $official || ! $usdt) {
            return;
        }

        $spreadOfficialUsdt = $official->rate_mid > 0
            ? round((($usdt->rate_ask / $official->rate_mid) - 1) * 100, 4)
            : 0;

        $alertLevel = match (true) {
            $spreadOfficialUsdt > 60 => 'critical',
            $spreadOfficialUsdt > 40 => 'warning',
            default                  => '',
        };

        ParallelSpreadLog::upsert([
            'log_date'       => now()->toDateString(),
            'log_hour'       => (int) now()->format('G'),
            'official_mid'   => $official->rate_mid ?? '0.00000000',
            'referencial_bid'=> $referencial->rate_buy ?? '0.00000000',
            'referencial_ask'=> $referencial->rate_sell ?? '0.00000000',
            'usdt_bid'       => $usdt->rate_bid ?? '0.00000000',
            'usdt_ask'       => $usdt->rate_ask ?? '0.00000000',
            'usdc_bid'       => $usdc?->rate_bid ?? '0.00000000',
            'usdc_ask'       => $usdc?->rate_ask ?? '0.00000000',
            'alert_level'    => $alertLevel,
        ], ['log_date', 'log_hour'],
           ['official_mid', 'referencial_bid', 'referencial_ask',
            'usdt_bid', 'usdt_ask', 'usdc_bid', 'usdc_ask', 'alert_level']);

        if ($alertLevel !== '') {
            $this->broadcastSpreadAlert($alertLevel, $spreadOfficialUsdt);
        }
    }

    private function median(array $sorted): float
    {
        $count = count($sorted);
        if ($count === 0) return 0.0;
        $mid = (int) floor($count / 2);
        return ($count % 2 === 0)
            ? ($sorted[$mid - 1] + $sorted[$mid]) / 2
            : $sorted[$mid];
    }

    private function broadcastSpreadAlert(string $level, float $spread): void
    {
        \DB::table('broadcast.messages')->insert([
            'id'           => \Str::uuid7(),
            'type'         => $level === 'critical' ? 'alert' : 'warning',
            'priority'     => $level === 'critical' ? 1 : 2,
            'content'      => json_encode([
                'text'     => "⚠️ Spread USD paralelo/oficial: {$spread}% (histórico: 25%)",
                'severity' => $level,
            ]),
            'active_from'  => now(),
            'active_until' => now()->addHours(2),
            'created_by_system' => 'DailySyncUsdtP2pJob',
        ]);
    }
}
```

### DailySyncBcbReferencialJob

```php
<?php
// app/Jobs/Sync/DailySyncBcbReferencialJob.php
// Fuente: BCB portal — VRD/VRV publicado desde dic-2025
// Horario: lunes a viernes 11:00 (el BCB publica el referencial al mediodía)
// Descarga el mismo Excel del BCB pero extrae la columna VRD y VRV
// que están disponibles desde el 1 de diciembre de 2025

class DailySyncBcbReferencialJob implements ShouldQueue
{
    public function handle(): void
    {
        $today = now()->format('j');  // día sin cero inicial (requerido por BCB)
        $month = now()->format('n');
        $year  = now()->year;

        $url = "https://www.bcb.gob.bo/librerias/indicadores/otras/otras_imprimir2XLS.php"
             . "?qdd={$today}&qmm={$month}&qaa={$year}";

        $response = Http::timeout(30)->get($url);

        if (! $response->successful()) {
            // Circuit breaker maneja esto
            return;
        }

        $parser = new BcbExcelParser($response->body());

        // Extraer tipo oficial (siempre)
        $official = $parser->getOfficialRate('USD');

        // Extraer referencial (disponible desde dic-2025)
        $referencial = $parser->getReferencialRate('USD');

        // Guardar oficial en rates.exchange_rates
        if ($official) {
            \DB::table('rates.exchange_rates')->upsert([
                'base_currency' => 'USD',
                'quote_currency'=> 'BOB',
                'rate_official' => $official['mid'],
                'rate_buy'      => $official['buy'],
                'rate_sell'     => $official['sell'],
                'rate_date'     => now()->toDateString(),
                'source_code'   => 'bcb_bolivia',
                'type_code'     => 'official_daily',
                'quality'       => 'high',
            ], ['base_currency', 'quote_currency', 'rate_date', 'source_code'],
               ['rate_official', 'rate_buy', 'rate_sell']);
        }

        // Guardar referencial en validation.bcb_cotizaciones
        if ($referencial) {
            \DB::table('validation.bcb_cotizaciones')->upsert([
                'rate_date'          => now()->toDateString(),
                'currency_code_bcb'  => 'USD',
                'currency_code_iso'  => 'BOB',
                'rate_buy'           => $referencial['buy'],
                'rate_sell'          => $referencial['sell'],
                'rate_referencial'   => $referencial['mid'],
                'data_type'          => 'referential',
                'source_file_date'   => now()->toDateString(),
            ], ['rate_date', 'currency_code_iso', 'data_type'],
               ['rate_buy', 'rate_sell', 'rate_referencial']);
        }
    }
}
```

---

## Endpoints de la API — USDT y USDC

### Nuevos endpoints

```
GET /api/v1/rates/stablecoins           → USDT/BOB y USDC/BOB actuales
GET /api/v1/rates/stablecoins/history   → serie horaria (max 30 días)
GET /api/v1/rates/spread/bob            → las 4 cotizaciones del dólar en Bolivia
GET /api/v1/rates/referencial           → VRD/VRV del BCB
```

### Respuesta de /rates/spread/bob

```json
{
  "date": "2026-05-23",
  "hour": "10:00",
  "bob_usd": {
    "oficial_bcb": {
      "buy": "6.86",
      "sell": "6.96",
      "mid": "6.91",
      "source": "bcb_bolivia",
      "description": "Tipo de cambio oficial fijo BCB (desde 2011)"
    },
    "referencial_bcb": {
      "buy": "8.83",
      "sell": "9.15",
      "mid": "8.99",
      "source": "bcb_referencial",
      "description": "Valor Referencial BCB — operaciones reales EIF (desde dic-2025)"
    },
    "usdt_p2p": {
      "buy": "9.82",
      "sell": "10.08",
      "mid": "9.95",
      "source": "criptoya_p2p",
      "exchanges_sampled": 7,
      "network": "TRC20",
      "description": "USDT mediana de Binance/Bybit/Bitget P2P"
    },
    "usdc_p2p": {
      "buy": "9.78",
      "sell": "10.02",
      "mid": "9.90",
      "source": "criptoya_p2p",
      "exchanges_sampled": 5,
      "network": "SOL,BASE",
      "description": "USDC mediana Binance/Bybit P2P"
    }
  },
  "spreads": {
    "oficial_vs_usdt_pct": "44.7",
    "referencial_vs_usdt_pct": "10.8",
    "alert_level": "warning",
    "historical_avg_spread_pct": "25.0"
  }
}
```

---

## Scheduler — nuevos jobs

```php
// routes/console.php (Laravel 13 — Schedule en archivo de rutas)

Schedule::job(DailySyncUsdtP2pJob::class)
    ->hourly()
    ->withoutOverlapping()
    ->onOneServer()
    ->name('sync-stablecoins-p2p');

Schedule::job(DailySyncBcbReferencialJob::class)
    ->weekdays()
    ->at('11:00')
    ->timezone('America/La_Paz')
    ->name('sync-bcb-referencial');
```

---

## Caja biedata para SYNC_MODE=biedata

```yaml
# boxes/import/usdt_usdc_p2p_hourly/box.yml
name: usdt_usdc_p2p_hourly
description: "Cotización horaria USDT/BOB y USDC/BOB desde CriptoYa P2P"
schedule: "0 * * * *"  # cada hora

VALIDATE:
  - query: "SELECT COUNT(*) FROM rates.stablecoin_rates WHERE coin_code IN ('UST','USC') AND sampled_at = date_trunc('hour', NOW())"
  - condition: count == 0  # si ya existe, abortar

AUTHENTICATE:
  - none  # API pública, sin credenciales

EXTRACT:
  - url: "https://criptoya.com/api/USDT/BOB/1"
    variable: usdt_data
  - url: "https://criptoya.com/api/USDC/BOB/1"
    variable: usdc_data

TRANSFORM:
  - median_ask_usdt: median(usdt_data.*.ask)
  - median_bid_usdt: median(usdt_data.*.bid)
  - median_ask_usdc: median(usdc_data.*.ask)
  - median_bid_usdc: median(usdc_data.*.bid)

LOAD:
  - table: rates.stablecoin_rates
    upsert_key: [coin_code, fiat_code, source_code, sampled_at]

AUDIT:
  - table: sync.sync_log
    fields: [source_code, records_inserted, ctx_id]
```

---

## USDT/USDC en catalog.RATE()

La función `catalog.RATE()` maneja stablecoins de forma natural:

```sql
-- Conversión BOB → USDT (mercado paralelo)
SELECT catalog.RATE('23/05/2026', 'BOB', 'UST', 1000, 2);
-- Internamente: busca en rates.stablecoin_rates, no en rates.exchange_rates
-- Resultado: ~99.50 USDT (1000 ÷ 10.05)

-- Conversión USDT → BOB
SELECT catalog.RATE('23/05/2026', 'UST', 'BOB', 100, 2);
-- Resultado: ~1005.00 BOB (100 × 10.05)

-- La función detecta automáticamente si el par es stablecoin
-- y usa rates.stablecoin_rates en lugar de rates.exchange_rates
```

---
_SKULL · SBOS · SmartRates · 016-STABLECOINS-INTEGRACION · v1.0 · 2026-05-23_
