# Ticker — Widget Universal del Ecosistema SBOS
## SmartRates Ticker · Web Component + Flutter Package · Todas las 4 cotizaciones

---

## El Ticker no es un componente de SmartRates — es un servicio del SBOS

El Ticker es una **banda horizontal de información cambiaria** que cualquier aplicación del ecosistema SBOS puede incluir con 2 líneas de código. Su propósito es garantizar que en **cualquier formulario donde se opera con dinero**, el operador tenga siempre a la vista los tipos de cambio relevantes sin necesidad de abrir otra app.

**Aplicaciones SBOS que DEBEN integrar el Ticker:**

| Aplicación | Por qué lo necesita |
|---|---|
| Tryton (ERP) | Formularios de facturas, órdenes de compra, contabilidad multicurrency |
| SmartTax | Declaraciones en moneda extranjera — el SIN exige el tipo del día |
| Saleor (e-commerce) | Catálogo con precios en múltiples monedas |
| SmartReport | Reportes multimoneda — el operador confirma el tipo usado |
| Cualquier app nueva | Por defecto: incluir el Ticker en el header/footer de cualquier formulario financiero |

---

## Las cuatro referencias que muestra el Ticker

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ 🇧🇴 USD/BOB oficial 6.96 BCB │ 📊 Ref. BCB 9.15 │ 🔵 USDT 10.05 P2P │ 🔵 USDC 10.02 │
│ 🇪🇺 EUR/BOB 11.28 │ 🇧🇷 BRL/BOB 1.95 │ 🇵🇪 PEN/BOB 1.86 │ 🇦🇷 ARS/BOB 0.0097 │
│ ⚠️  Spread USDT/oficial: 45% — sobre el promedio histórico (25%)                        │
└──────────────────────────────────────────────────────────────────────────────────────────┘
altura: 34px · scroll continuo derecha → izquierda · actualización SSE tiempo real
```

**Colores diferenciados por tipo:**

| Tipo | Color fondo | Color texto | Icono |
|---|---|---|---|
| Oficial BCB | `#1a1a2e` | `#e0e0e0` blanco suave | 🇧🇴 |
| Referencial BCB | `#0d2137` azul oscuro | `#4fc3f7` azul claro | 📊 |
| USDT P2P | `#1a1a2e` | `#ce93d8` morado | 🔵 |
| USDC P2P | `#1a1a2e` | `#b39ddb` morado claro | 🔵 |
| Alerta spread >40% | `#7f1d1d` rojo | `#fca5a5` rojo claro | ⚠️ |
| Alerta crítica >60% | `#7f1d1d` pulsante | `#ff0000` rojo vivo | 🚨 |
| Institucional | `#1a1a2e` | `#ffd700` dorado | 📢 |
| Hora Bolivia | `#1a1a2e` | `#a855f7` lila | 🕐 |

---

## Web Component — implementación completa

### Archivo: `smartrates-ticker.js` (~8KB minificado, zero dependencias)

```javascript
// Distribuido desde: https://smartrates.bo/widget/ticker.js
// Internamente en K8s: http://smartrates-ui.svc.cluster.local/ticker.js

class SmartRatesTicker extends HTMLElement {

    static get observedAttributes() {
        return [
            'currencies',     // "USD,USDT,USDC,EUR,BRL" — monedas a mostrar
            'show-official',  // true (default) — tipo oficial BCB
            'show-ref',       // true (default) — referencial BCB
            'show-usdt',      // true (default) — USDT P2P paralelo
            'show-usdc',      // false (default) — USDC P2P
            'theme',          // light / dark / auto (default: auto)
            'lang',           // es (default) / en
            'speed',          // px/s — default: 30
            'show-flags',     // true (default)
            'show-variation', // true (default) — variación % vs ayer
            'show-spread',    // true (default) — alerta de spread
            'pause-on-hover', // true (default)
            'position',       // top (default) / bottom
            'compact',        // false (default) — true = solo código+valor
            'api-url',        // URL del endpoint SSE (default: /api/v1/rates/stream)
            'api-key',        // Bearer token para acceso autenticado
            'height',         // px — default: 34
        ];
    }

    connectedCallback() {
        this._render();
        this._connectSSE();
        this._setupPauseOnHover();
    }

    _render() {
        const height = this.getAttribute('height') || '34';
        this.style.cssText = `
            display: block;
            height: ${height}px;
            overflow: hidden;
            position: relative;
            background: var(--smartrates-bg, #1a1a2e);
            font-family: 'SF Mono', 'Fira Code', 'Courier New', monospace;
            font-size: 12px;
            line-height: ${height}px;
            white-space: nowrap;
        `;
        this.innerHTML = `<div class="sr-track" style="
            display: inline-block;
            animation: sr-scroll linear infinite;
            animation-duration: ${this._getScrollDuration()}s;
        "><span class="sr-loading">Cargando cotizaciones...</span></div>`;
        this._injectStyles();
    }

    _connectSSE() {
        const apiUrl   = this.getAttribute('api-url') || '/api/v1/rates/stream';
        const apiKey   = this.getAttribute('api-key') || '';
        const showUsdt = this.getAttribute('show-usdt') !== 'false';
        const showUsdc = this.getAttribute('show-usdc') === 'true';
        const showRef  = this.getAttribute('show-ref') !== 'false';

        const params = new URLSearchParams({
            currencies: this.getAttribute('currencies') || 'USD,EUR,BRL,PEN,ARS',
            show_usdt: showUsdt,
            show_usdc: showUsdc,
            show_ref:  showRef,
            lang:      this.getAttribute('lang') || 'es',
        });

        if (apiKey) params.set('api_key', apiKey);

        this._sse = new EventSource(`${apiUrl}?${params}`);

        this._sse.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this._updateTrack(data);
        };

        // EventSource reconecta automáticamente — no necesita código adicional
        this._sse.onerror = () => {
            this._showStatus('Reconectando...');
        };
    }

    _updateTrack(data) {
        const items   = this._buildItems(data);
        const track   = this.querySelector('.sr-track');
        if (track) {
            // Duplicar para scroll continuo sin saltos
            const html  = items.map(i => this._renderItem(i)).join(' &nbsp;&nbsp;│&nbsp;&nbsp; ');
            track.innerHTML = html + ' &nbsp;&nbsp;&nbsp;&nbsp; ' + html;
        }
    }

    _buildItems(data) {
        const lang     = this.getAttribute('lang') || 'es';
        const compact  = this.getAttribute('compact') === 'true';
        const showVar  = this.getAttribute('show-variation') !== 'false';
        const items    = [];

        // 1. Oficial BCB
        if (data.oficial && this.getAttribute('show-official') !== 'false') {
            items.push({
                type:       'official',
                icon:       '🇧🇴',
                label:      compact ? 'USD/BOB' : (lang === 'es' ? 'USD/BOB oficial BCB' : 'USD/BOB official BCB'),
                buy:        data.oficial.buy,
                sell:       data.oficial.sell,
                color:      '#e0e0e0',
            });
        }

        // 2. Referencial BCB
        if (data.referencial && this.getAttribute('show-ref') !== 'false') {
            items.push({
                type:  'referencial',
                icon:  '📊',
                label: compact ? 'Ref.BCB' : (lang === 'es' ? 'Ref. BCB' : 'BCB Ref.'),
                buy:   data.referencial.buy,
                sell:  data.referencial.sell,
                color: '#4fc3f7',
            });
        }

        // 3. USDT P2P
        if (data.usdt && this.getAttribute('show-usdt') !== 'false') {
            items.push({
                type:    'usdt',
                icon:    '🔵',
                label:   'USDT',
                buy:     data.usdt.bid,
                sell:    data.usdt.ask,
                color:   '#ce93d8',
                network: 'TRC20',
            });
        }

        // 4. USDC P2P
        if (data.usdc && this.getAttribute('show-usdc') === 'true') {
            items.push({
                type:    'usdc',
                icon:    '🔵',
                label:   'USDC',
                buy:     data.usdc.bid,
                sell:    data.usdc.ask,
                color:   '#b39ddb',
                network: 'SOL',
            });
        }

        // 5. Otras monedas configuradas
        if (data.rates) {
            const currencies = (this.getAttribute('currencies') || '').split(',')
                .filter(c => !['USD', 'UST', 'USC'].includes(c.trim()));

            for (const curr of currencies) {
                const rate = data.rates[curr.trim()];
                if (rate) {
                    items.push({
                        type:       'rate',
                        icon:       rate.flag_emoji || '',
                        label:      `${curr.trim()}/BOB`,
                        mid:        rate.mid,
                        variation:  showVar ? rate.variation_pct : null,
                        color:      '#e0e0e0',
                    });
                }
            }
        }

        // 6. Alerta de spread si aplica
        if (data.spread_alert) {
            items.unshift({
                type:  'alert',
                icon:  data.spread_alert.level === 'critical' ? '🚨' : '⚠️',
                label: data.spread_alert.message,
                color: data.spread_alert.level === 'critical' ? '#ff4444' : '#ffd700',
            });
        }

        return items;
    }

    _renderItem(item) {
        const style = `color: ${item.color}; font-weight: 600;`;
        if (item.type === 'alert') {
            const bg = item.icon === '🚨'
                ? 'background: #7f1d1d; padding: 0 8px; animation: sr-pulse 1s infinite;'
                : 'background: #4a3800; padding: 0 8px;';
            return `<span style="${style} ${bg}">${item.icon} ${item.label}</span>`;
        }
        if (item.buy && item.sell) {
            return `<span style="${style}">${item.icon} ${item.label} · C:${item.buy} V:${item.sell}</span>`;
        }
        if (item.mid) {
            const varStr = item.variation
                ? (item.variation > 0 ? ` ▲${item.variation}%` : ` ▼${Math.abs(item.variation)}%`)
                : '';
            return `<span style="${style}">${item.icon} ${item.label} · ${item.mid}${varStr}</span>`;
        }
        return `<span style="${style}">${item.icon} ${item.label}</span>`;
    }

    _injectStyles() {
        if (document.getElementById('sr-ticker-styles')) return;
        const style = document.createElement('style');
        style.id = 'sr-ticker-styles';
        style.textContent = `
            @keyframes sr-scroll {
                from { transform: translateX(0); }
                to   { transform: translateX(-50%); }
            }
            @keyframes sr-pulse {
                0%, 100% { opacity: 1; }
                50%       { opacity: 0.6; }
            }
        `;
        document.head.appendChild(style);
    }

    _getScrollDuration() {
        const speed = parseFloat(this.getAttribute('speed') || '30');
        return Math.max(10, 300 / speed);  // velocidad en segundos por ciclo
    }

    _setupPauseOnHover() {
        if (this.getAttribute('pause-on-hover') === 'false') return;
        const track = this.querySelector('.sr-track');
        if (!track) return;
        this.addEventListener('mouseenter', () => track.style.animationPlayState = 'paused');
        this.addEventListener('mouseleave', () => track.style.animationPlayState = 'running');
        this.addEventListener('touchstart', () => track.style.animationPlayState = 'paused');
        this.addEventListener('touchend',   () => track.style.animationPlayState = 'running');
    }

    _showStatus(msg) {
        const track = this.querySelector('.sr-track');
        if (track) track.innerHTML = `<span style="color:#888">${msg}</span>`;
    }

    disconnectedCallback() {
        if (this._sse) this._sse.close();
    }
}

customElements.define('smartrates-ticker', SmartRatesTicker);
```

---

## Integración en todas las aplicaciones del SBOS

### Tryton — formulario de factura

```html
<!-- En el layout base de Tryton (Genshi template) -->
<!-- Archivo: tryton/modules/account_invoice/view/invoice_form.xml -->
<script src="http://smartrates-ui.svc.cluster.local/ticker.js" defer></script>

<!-- Header del formulario de factura -->
<smartrates-ticker
    currencies="USD,EUR,BRL"
    show-official="true"
    show-ref="true"
    show-usdt="true"
    show-usdc="false"
    theme="dark"
    lang="es"
    position="top"
    compact="false"
    api-url="http://smartrates-api.svc.cluster.local/api/v1/rates/stream">
</smartrates-ticker>
```

### SmartTax — declaración de impuestos

```html
<!-- SmartTax necesita mostrar el tipo oficial BCB para el SIN -->
<smartrates-ticker
    currencies="USD"
    show-official="true"
    show-ref="true"
    show-usdt="false"
    theme="light"
    lang="es"
    compact="true"
    height="28">
</smartrates-ticker>
```

### Saleor — e-commerce admin

```html
<!-- Dashboard de administración de Saleor -->
<smartrates-ticker
    currencies="USD,EUR,BRL,ARS,PEN,CLP"
    show-official="true"
    show-ref="false"
    show-usdt="true"
    show-usdc="true"
    theme="dark"
    show-variation="true">
</smartrates-ticker>
```

### Laravel Blade (cualquier app del ecosistema)

```blade
{{-- resources/views/layouts/app.blade.php --}}
@push('scripts')
    <script src="{{ config('smartrates.ticker_url') }}/ticker.js" defer></script>
@endpush

@if(config('smartrates.show_ticker'))
<smartrates-ticker
    currencies="{{ implode(',', config('smartrates.currencies')) }}"
    show-usdt="{{ config('smartrates.show_usdt') ? 'true' : 'false' }}"
    show-ref="true"
    theme="{{ config('smartrates.ticker_theme', 'auto') }}"
    lang="{{ app()->getLocale() }}">
</smartrates-ticker>
@endif
```

### iframe para apps legacy o JasperReports

```html
<!-- Sistemas que no soportan Web Components (JSP legacy, etc.) -->
<iframe
    src="http://smartrates-ui.svc.cluster.local/ticker?currencies=USD,USDT&theme=dark&lang=es&compact=true&height=34"
    height="34"
    width="100%"
    scrolling="no"
    frameborder="0"
    style="border:none; display:block;">
</iframe>
```

---

## Flutter Package — `sbos_smartrates_ticker`

### Publicado en el registry privado del SBOS

```yaml
# pubspec.yaml — cualquier app Flutter del ecosistema
dependencies:
  sbos_smartrates_ticker:
    git:
      url: https://gitlab.skull.bo/sbos/packages/sbos_smartrates_ticker.git
      ref: v1.0.0
```

### Uso en SmartTax (Flutter)

```dart
// Agregar en cualquier pantalla con datos financieros
import 'package:sbos_smartrates_ticker/sbos_smartrates_ticker.dart';

class InvoiceFormScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Factura'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(34),
          child: SmartRatesTickerWidget(
            config: TickerConfig(
              currencies: ['USD', 'EUR'],
              showOfficial: true,
              showReferencial: true,
              showUsdt: true,
              showUsdc: false,
              theme: TickerTheme.dark,
              apiUrl: 'http://smartrates-api.svc.cluster.local',
            ),
          ),
        ),
      ),
      body: _buildForm(),
    );
  }
}
```

### API del Flutter package

```dart
// Configuración
TickerConfig({
  required List<String> currencies,  // monedas a mostrar
  bool showOfficial   = true,
  bool showReferencial = true,
  bool showUsdt       = true,
  bool showUsdc       = false,
  TickerTheme theme   = TickerTheme.auto,
  String lang         = 'es',
  double speed        = 30.0,        // px/s
  bool showFlags      = true,
  bool showVariation  = true,
  bool showSpreadAlert= true,
  bool compact        = false,
  double height       = 34.0,
  required String apiUrl,
  String? apiKey,
})
```

---

## Endpoint SSE de SmartRatesAPI para el Ticker

```php
// app/Http/Controllers/Api/V1/RatesController.php

public function stream(Request $request): StreamedResponse
{
    $currencies   = explode(',', $request->input('currencies', 'USD,EUR,BRL'));
    $showUsdt     = $request->boolean('show_usdt', true);
    $showUsdc     = $request->boolean('show_usdc', false);
    $showRef      = $request->boolean('show_ref', true);
    $lang         = $request->input('lang', 'es');

    return response()->stream(function () use ($currencies, $showUsdt, $showUsdc, $showRef) {

        // Enviar datos iniciales inmediatamente
        $payload = $this->buildTickerPayload($currencies, $showUsdt, $showUsdc, $showRef);
        echo "data: " . json_encode($payload) . "\n\n";
        ob_flush(); flush();

        // Escuchar pg_notify (cualquier inserción en exchange_rates o stablecoin_rates)
        $pdo = \DB::connection()->getPdo();
        $pdo->exec("LISTEN rates_channel");

        $lastHeartbeat = time();

        while (true) {
            // Esperar notificación de PostgreSQL (non-blocking, timeout 25s)
            $result = $pdo->query("SELECT pg_try_recv_notify()");
            $notify = $result->fetchColumn();

            if ($notify) {
                $payload = $this->buildTickerPayload($currencies, $showUsdt, $showUsdc, $showRef);
                echo "data: " . json_encode($payload) . "\n\n";
                ob_flush(); flush();
            }

            // Heartbeat cada 25s para mantener la conexión viva
            if (time() - $lastHeartbeat > 25) {
                echo ": heartbeat\n\n";
                ob_flush(); flush();
                $lastHeartbeat = time();
            }

            if (connection_aborted()) break;
            usleep(500_000); // poll cada 500ms
        }
    }, 200, [
        'Content-Type'      => 'text/event-stream',
        'Cache-Control'     => 'no-cache, no-store',
        'X-Accel-Buffering' => 'no',       // para Nginx
        'Access-Control-Allow-Origin' => '*',
    ]);
}

private function buildTickerPayload(array $currencies, bool $showUsdt, bool $showUsdc, bool $showRef): array
{
    $payload = [];

    // Oficial BCB
    $payload['oficial'] = \DB::selectOne("
        SELECT rate_buy::text AS buy, rate_sell::text AS sell, rate_mid::text AS mid
        FROM rates.exchange_rates
        WHERE base_currency='USD' AND quote_currency='BOB'
          AND source_code='bcb_bolivia' AND rate_date = CURRENT_DATE
        ORDER BY created_at DESC LIMIT 1
    ");

    // Referencial BCB
    if ($showRef) {
        $payload['referencial'] = \DB::selectOne("
            SELECT rate_buy::text AS buy, rate_sell::text AS sell, rate_referencial::text AS mid
            FROM validation.bcb_cotizaciones
            WHERE currency_code_iso='BOB' AND data_type='referential'
              AND rate_date = CURRENT_DATE
            LIMIT 1
        ");
    }

    // USDT
    if ($showUsdt) {
        $payload['usdt'] = \DB::selectOne("
            SELECT rate_bid::text AS bid, rate_ask::text AS ask, rate_mid::text AS mid
            FROM rates.stablecoin_rates
            WHERE coin_code='XUT' AND fiat_code='BOB'
            ORDER BY sampled_at DESC LIMIT 1
        ");
    }

    // USDC
    if ($showUsdc) {
        $payload['usdc'] = \DB::selectOne("
            SELECT rate_bid::text AS bid, rate_ask::text AS ask, rate_mid::text AS mid
            FROM rates.stablecoin_rates
            WHERE coin_code='XUC' AND fiat_code='BOB'
            ORDER BY sampled_at DESC LIMIT 1
        ");
    }

    // Otras monedas
    if (! empty($currencies)) {
        $payload['rates'] = [];
        foreach ($currencies as $currency) {
            if (in_array($currency, ['USD', 'UST', 'USC'])) continue;
            $rate = \DB::selectOne("
                SELECT rate_mid::text AS mid,
                       ROUND(((rate_mid - lag(rate_mid) OVER (ORDER BY rate_date)) /
                               lag(rate_mid) OVER (ORDER BY rate_date)) * 100, 2)::text AS variation_pct
                FROM rates.exchange_rates
                WHERE base_currency='USD' AND quote_currency=?
                ORDER BY rate_date DESC LIMIT 1
            ", [$currency]);
            if ($rate) $payload['rates'][$currency] = $rate;
        }
    }

    // Alerta de spread
    $spread = \DB::selectOne("
        SELECT spread_official_usdt::text AS spread, alert_level
        FROM rates.parallel_spread_log
        WHERE log_date = CURRENT_DATE
        ORDER BY log_hour DESC LIMIT 1
    ");
    if ($spread && $spread->alert_level !== '') {
        $payload['spread_alert'] = [
            'level'   => $spread->alert_level,
            'spread'  => $spread->spread,
            'message' => "Spread USD paralelo/oficial: {$spread->spread}% (histórico: 25%)",
        ];
    }

    return $payload;
}
```

---
_SKULL · SBOS · SmartRates · 017-TICKER-WIDGET-SBOS · v1.0 · 2026-05-23_
