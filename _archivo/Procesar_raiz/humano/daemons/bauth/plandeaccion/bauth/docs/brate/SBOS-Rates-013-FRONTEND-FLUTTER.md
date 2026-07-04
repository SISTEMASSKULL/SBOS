# SmartRatesUI — Frontend Flutter — SBOS SmartRates

---

## Una codebase, cuatro plataformas

```
SmartRatesUI (Flutter 3.x + Impeller)
│
├── Web           → Acceso desde navegador — office desktop
├── Android       → App móvil — operadores en campo, Android 9+
├── iOS           → App móvil — misma codebase, iOS 14+
└── Desktop       → Windows 10+, macOS 12+ — uso interno empresa
```

**Por qué Flutter:** Una sola codebase reduce el costo de mantenimiento a 1/4 vs mantener 4 apps. Impeller garantiza 60fps en todos los targets. BLoC es el patrón estándar del ecosistema SKULL para state management.

---

## Responsive design — Breakpoints adaptativos

| Ancho del viewport | Layout | Navegación | Uso principal |
|---|---|---|---|
| < 600px | Single column — una sección a la vez | Bottom navigation bar (5 ítems) | Móvil en campo |
| 600–1024px | Two column — lista + detalle | Side navigation rail (iconos) | Tablet, web móvil |
| > 1024px | Three column — sidebar + lista + detalle | Sidebar expandida con labels | Desktop, web office |

---

## Arquitectura de la app

```
lib/
│
├── core/
│   ├── api/
│   │   ├── smart_rates_api_client.dart    # Cliente HTTP (Dio) con interceptor JWT
│   │   ├── api_endpoints.dart             # Constantes de todos los endpoints
│   │   └── api_exception_handler.dart     # Mapeo SR-XXX → mensajes de usuario
│   │
│   ├── realtime/
│   │   ├── reverb_client.dart             # WebSocket (Reverb/Pusher protocol)
│   │   └── reverb_events.dart             # Eventos: RatesUpdated, AdjustmentRequired
│   │
│   ├── cache/
│   │   └── local_cache.dart               # Hive — cotizaciones offline
│   │
│   ├── auth/
│   │   ├── sanctum_auth_service.dart      # Modo standalone
│   │   └── keycloak_auth_service.dart     # Modo SBOS
│   │
│   └── theme/
│       ├── smart_rates_theme.dart         # Design tokens
│       └── color_scheme.dart              # Colores del sistema
│
├── features/
│   ├── dashboard/
│   │   ├── bloc/  rate_dashboard_bloc.dart
│   │   └── view/  rate_dashboard_screen.dart
│   │
│   ├── converter/
│   │   ├── bloc/  converter_bloc.dart
│   │   └── view/  converter_screen.dart
│   │
│   ├── rates/
│   │   ├── bloc/  rates_bloc.dart
│   │   └── view/  rates_screen.dart
│   │
│   ├── explorer/
│   │   ├── bloc/  explorer_bloc.dart
│   │   └── view/  explorer_screen.dart
│   │
│   ├── adjustment/
│   │   ├── bloc/  adjustment_bloc.dart
│   │   └── view/  adjustment_screen.dart
│   │
│   ├── sync/
│   │   ├── bloc/  sync_status_bloc.dart
│   │   └── view/  sync_status_screen.dart
│   │
│   └── settings/
│       ├── bloc/  settings_bloc.dart
│       └── view/  settings_screen.dart
│
└── shared/
    ├── widgets/
    │   ├── currency_card.dart
    │   ├── rate_display_widget.dart      # Muestra official + black si adjustment>0
    │   ├── adjustment_modal.dart         # Modal de confirmación del ajuste diario
    │   ├── sync_status_indicator.dart    # Indicador de estado de fuentes
    │   ├── data_quality_badge.dart       # high/medium/low con tooltip
    │   ├── currency_selector.dart        # Selector con bandera y búsqueda
    │   └── rate_chart_widget.dart        # Gráfico de tendencia (fl_chart)
    │
    ├── models/                            # DTOs de la API (generados con json_serializable)
    └── utils/
        └── currency_formatter.dart       # Usa catalog.currencies para formato correcto
```

---

## Pantalla 1 — Dashboard

**Quién la usa:** Todos los usuarios — es la pantalla de inicio

**Qué muestra:**
- Fecha y hora actual Bolivia (UTC-4) — actualizada en tiempo real
- Cotizaciones del día para las monedas configuradas por la empresa, en tarjetas (CurrencyCard)
- Indicador de variación vs ayer: ▲ verde / ▼ rojo / — neutral
- Indicador de black rate si `adjustment > 0` para alguna moneda
- Badge de calidad del dato (high/medium/low) con tooltip
- Badge de estado de sincronización: "Actualizado hoy 06:00" o "Última sync: ayer"
- Notificación banner amarillo si el ajuste del día no fue confirmado (solo para operadores)

**Interacciones:**
- Tap en una tarjeta → navega al detalle de esa moneda (pantalla Rates)
- Pull to refresh → fuerza recarga de cotizaciones desde la API
- Al recibir evento WebSocket `rates.updated` → las tarjetas se actualizan con animación suave

**Estado offline:**
- Si no hay conexión, muestra los últimos datos disponibles del cache Hive con banner "Sin conexión — mostrando datos del {fecha}"

---

## Pantalla 2 — Conversor

**Quién la usa:** Todos los usuarios — la más usada en móvil

**Qué muestra:**
```
┌──────────────────────────────────────────────────┐
│                                                  │
│   Tengo        [100]        🇧🇴 Boliviano BOB ▼  │
│                                                  │
│   ⇄                                              │
│                                                  │
│   Quiero                   🇺🇸 Dólar USD ▼       │
│                                                  │
│   ══════════════════════════════════════════════  │
│                                                  │
│   100 BOB =  14.47 USD                           │
│   Tipo de cambio: 6.91 BOB/USD                   │
│   Fuente: BCB Bolivia · 23/05/2026               │
│                                                  │
│   Cómo se calculó:                               │
│   100 BOB ÷ 6.91 = 14.47 USD                     │
│                                                  │
│   [¿Y hace 1 año?]  [¿Y hace 5 años?]            │
│                                                  │
│   Otros destinos rápidos:                        │
│   🇧🇷 BRL  82.23    🇵🇪 PEN  53.84               │
│   🇦🇷 ARS  153.847  🇺🇾 UYU  567.21              │
└──────────────────────────────────────────────────┘
```

**Interacciones:**
- Typing en el monto → conversión en tiempo real (debounce 300ms)
- Botón ⇄ → swap: intercambia moneda origen y destino, recalcula
- Selector de moneda → bottom sheet con lista buscable, banderas, 200+ opciones
- "¿Y hace 1 año?" → navega a conversión histórica con comparación
- "Otros destinos rápidos" → conversión multi simultánea a monedas LATAM

---

## Pantalla 3 — Cotizaciones

**Quién la usa:** Todos los usuarios — vista de detalle y análisis

**Modos de vista:**
- **Vista tabla:** todas las monedas del día con código, nombre, compra, venta, mid, variación
- **Vista por bloques:** G7, BRICS, Mercosur, OPEC, Europa — agrupadas con subheaders
- **Vista detalle:** al seleccionar una moneda, gráfico de línea de los últimos 30/90/365 días

**Filtros:**
- Buscador por código o nombre (BOB, dólar, euro, sol...)
- Filtro por bloque económico
- Filtro: "Solo monedas con ajuste activo"

**Gráfico de tendencia (fl_chart):**
- Línea de `rate_mid` por defecto
- Opción de superponer `rate_black_buy` si hay ajuste histórico
- Pinch-to-zoom para ampliar rangos
- Tap en un punto → tooltip con fecha, valor, fuente, calidad del dato

---

## Pantalla 4 — Ajuste del Día (solo operadores y admins)

**Quién la usa:** Operador Financiero, Administrador

**Flujo normal (llegada al trabajo):**
1. El operador abre la app → detecta que es el primer acceso del día
2. Aparece el banner: "El ajuste del día aún no fue confirmado"
3. Al tocar el banner → abre el modal de confirmación

**El modal de confirmación:**
```
┌───────────────────────────────────────────────┐
│  Confirmación de ajuste — Viernes 23/05/2026  │
├───────────────────────────────────────────────┤
│                                               │
│  Tipo de cambio oficial hoy:                  │
│  Compra BCB:  6.86 BOB/USD                    │
│  Venta BCB:   6.96 BOB/USD                    │
│  Mid:         6.91 BOB/USD                    │
│                                               │
│  Ajuste del día anterior: +0.50               │
│  (Resultaba en: Compra 7.41 · Venta 7.51)     │
│                                               │
│  ┌───────────────────────────────────────┐    │
│  │  Ajuste de hoy:  [ 0.50 ]  BOB        │    │
│  └───────────────────────────────────────┘    │
│                                               │
│  Con este ajuste:                             │
│  Compra: 7.41 BOB/USD                         │
│  Venta:  7.51 BOB/USD                         │
│                                               │
│  Nota (opcional): _______________             │
│                                               │
│  [Cancelar]          [Confirmar ajuste]       │
└───────────────────────────────────────────────┘
```

**Después de confirmar:**
- Toast: "Ajuste confirmado · 06:47am · por: María López"
- El dashboard actualiza las tarjetas de BOB con el nuevo black rate
- El evento WebSocket `adjustment.confirmed` se emite a todos los usuarios conectados

---

## Pantalla 5 — Estado de Sincronización (solo admins)

**Quién la usa:** Administrador

**Qué muestra:**
- Estado de cada fuente con indicador semafórico (verde/amarillo/rojo)
- Última sincronización exitosa de cada fuente con timestamp
- Estado del circuit breaker por fuente
- Estado del backfill histórico con barra de progreso por fase
- Log de las últimas 20 sincronizaciones

**Acciones disponibles:**
- "Forzar sincronización" por fuente → POST /sync/trigger
- "Pausar backfill" / "Reanudar backfill"
- "Ver log completo" → lista scrollable de todos los sync_logs

---

## Pantalla 6 — Explorador (Playground)

**Quién la usa:** Todos — especialmente desarrolladores y usuarios no técnicos que quieren descubrir

**Conceptualmente:** No es una pantalla funcional — es una experiencia de descubrimiento. El usuario elige qué quiere saber y el sistema se lo muestra con animaciones y context.

**Modos:**
1. **¿Cuánto vale?** → conversión simple con desglose visual del cross-rate
2. **¿Cómo ha cambiado?** → gráfico histórico interactivo de una moneda
3. **¿Cuánto cuesta en el mundo?** → un precio en BOB en 10 países simultáneamente
4. **¿Qué se apreció más?** → comparativa de dos monedas en el tiempo
5. **Cotizaciones de hoy** → tabla completa filtrada por bloques

**Sección "Para desarrolladores"** (siempre visible, discreta):
- El endpoint REST exacto que generó el resultado mostrado
- Botón "Copiar" que copia el URL completo con parámetros
- Transición natural a consumidor técnico de la API

---

## Ticker embebido en la app Flutter

La app Flutter tiene su propia implementación del Ticker como widget nativo (no el Web Component), usando el cliente WebSocket de Reverb directamente:

```dart
// lib/shared/widgets/rates_ticker_widget.dart
class RatesTickerWidget extends StatelessWidget {
  // Altura fija: 34px
  // Scroll continuo de derecha a izquierda
  // Datos desde el BLoC de dashboard (ya conectado a Reverb)
  // Se pausa al tocar y se reanuda al soltar
}
```

---

## Conectividad y modo offline

```dart
// lib/core/api/smart_rates_api_client.dart

class SmartRatesApiClient {
  Future<RatesResponse> getRatesToday() async {
    try {
      // 1. Intentar desde la API
      final response = await _dio.get('/rates/today');
      // 2. Guardar en cache Hive
      await _cache.save('rates_today', response.data);
      return RatesResponse.fromJson(response.data);
    } on DioException catch (e) {
      // 3. Si falla → cargar desde cache Hive
      final cached = await _cache.get('rates_today');
      if (cached != null) {
        return RatesResponse.fromJson(cached)..fromCache = true;
      }
      throw ApiException.fromDioError(e);
    }
  }
}
```

---

## Formateo de monedas — CurrencyFormatter

El formatter usa los datos de `catalog.currencies` para formatear correctamente según la moneda:

```dart
// lib/shared/utils/currency_formatter.dart

String format(double amount, String currencyCode, Currency currency) {
  // JPY, CLP, PYG: 0 decimales
  // USD, BOB, EUR: 2 decimales
  // KWD, BHD, OMR: 3 decimales
  final decimals = currency.currencyMinorUnit;

  // USD: 1,234.56 → separador de miles: coma, decimal: punto
  // EUR: 1.234,56 → separador de miles: punto, decimal: coma
  // NOK: 1 234,56 → separador de miles: espacio
  final formatted = NumberFormat(
    currency.decimalSeparator == ',' ? '#.###,##' : '#,###.##',
  ).format(amount.toStringAsFixed(decimals));

  // Símbolo antes o después según symbol_position
  return currency.symbolPosition == 'before'
      ? '${currency.symbol} $formatted'
      : '$formatted ${currency.symbol}';
}
```

---

## Dependencias Flutter principales

```yaml
# pubspec.yaml

dependencies:
  flutter_bloc: ^8.x       # State management
  dio: ^5.x                # HTTP client
  hive_flutter: ^1.x       # Cache offline
  fl_chart: ^0.x           # Gráficos
  web_socket_channel: ^3.x # WebSocket Reverb
  json_annotation: ^4.x    # DTOs
  intl: ^0.x               # Internacionalización y formateo de números
  go_router: ^14.x         # Navegación declarativa
  shimmer: ^3.x            # Loading skeletons

dev_dependencies:
  flutter_test:
  bloc_test: ^9.x          # Testing de BLoCs
  build_runner: ^2.x       # Generación de código
  json_serializable: ^6.x  # DTOs
  mockito: ^5.x            # Mocks para tests
```

---
_SKULL · SBOS · SmartRates · 013-FRONTEND-FLUTTER · v1.0 · 2026-05-23_
