# Decisiones Técnicas — SBOS SmartRates

---

## Stack tecnológico

| Capa | Tecnología | Versión | Motivo |
|---|---|---|---|
| Backend API | Laravel | 13 | Framework del ecosistema SKULL. Eloquent ORM, Horizon, Reverb, Sanctum incluidos. PHP 8.3. |
| Base de datos principal | PostgreSQL | 18.3 | Mismo cluster del SBOS. uuidv7, WITHOUT OVERLAPS, columnas VIRTUAL, BRIN indexes, particionamiento, io_uring AIO. |
| Cache / Queue / Pub-Sub | Redis | 7.x | Cache de cotizaciones, sessions, jobs de Horizon, pub/sub para Reverb. |
| WebSockets (broadcast) | Laravel Reverb | 1.x | Broadcast en tiempo real de `rates.updated`, `sync.completed`, `adjustment.required`. Incluido en Laravel 13. |
| Queue Workers | Laravel Horizon | 5.x | Gestión de jobs de sincronización y backfill. Dashboard de monitoreo incluido. |
| Streaming servidor→cliente | SSE (EventSource nativo) | HTTP/2 | Ticker — unidireccional puro. Reconexión automática. Sin configuración de proxy especial. |
| Frontend | Flutter | 3.x + Impeller | Una sola codebase: Web (Chrome/Firefox/Safari), Android, iOS, Desktop (Windows/macOS/Linux). BLoC pattern. |
| Ticker Web Component | Vanilla JS | ES2022 | Sin dependencias. ~8KB minificado. Funciona en cualquier framework. |
| Autenticación desarrollo | Laravel Sanctum | 4.x | Token personal en BD. Sin fricción. Activado con `AUTH_DRIVER=sanctum`. |
| Autenticación producción | Keycloak | 24.x (Apache 2.0) | SSO del ecosistema SBOS. JWT con BitMask. Activado con `AUTH_DRIVER=keycloak`. |
| Extensión DB | PostgreSQL C extension | PG18 | `catalog.RATE()` compilada como `.so` nativo. IMMUTABLE, STRICT, PARALLEL SAFE, COST 1. |
| Documentación API | L5-Swagger (OpenAPI 3.0) | 8.x | Auto-generada desde anotaciones PHP. UI interactiva en `/api/documentation`. |
| Contenedor | Docker + Kubernetes | — | Desarrollo: Docker Compose. Producción: K8s en el stack SBOS. |

---

## Modos de operación

### Auth Switch

```env
AUTH_DRIVER=sanctum    # Modo Standalone — desarrollo, sin SBOS
AUTH_DRIVER=keycloak   # Modo SBOS — producción
```

El cambio no requiere modificar código. Solo reiniciar el servicio.

### Sync Mode

```env
SYNC_MODE=internal   # Jobs de Laravel Horizon llaman APIs externas directamente
SYNC_MODE=biedata    # Cajas biedata del SBOS ejecutan las sincronizaciones
```

En modo `biedata`, los jobs de Horizon siguen existiendo pero no corren en horario — están disponibles para ejecución manual o para modo standalone.

### DB Mode

```env
DB_MODE=local      # PostgreSQL en Docker local (desarrollo)
DB_MODE=external   # PostgreSQL Patroni HA del cluster SBOS (producción)
```

### Keycloak Mode

```env
KEYCLOAK_MODE=local     # Keycloak en Docker local
KEYCLOAK_MODE=external  # Keycloak del cluster SBOS
```

---

## Matriz de configuración por entorno

| Variable | local dev | dev + Keycloak | staging | producción SBOS |
|---|---|---|---|---|
| `AUTH_DRIVER` | sanctum | keycloak | keycloak | keycloak |
| `SYNC_MODE` | internal | internal | internal | biedata |
| `DB_MODE` | local | local | local | external |
| `KEYCLOAK_MODE` | — | local | external | external |
| `APP_DEBUG` | true | true | false | false |
| `LOG_LEVEL` | debug | debug | info | info |
| `BACKFILL_ENABLED` | false | false | true | true |

---

## Arquitectura de componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                    SBOS SmartRates — Componentes                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ SmartRatesUI │    │   Ticker     │    │   Playground     │  │
│  │  (Flutter)   │    │(Web Component│    │   (Explorer)     │  │
│  │  Web/Mobile/ │    │    SSE)      │    │   /explorer      │  │
│  │  Desktop     │    │              │    │                  │  │
│  └──────┬───────┘    └──────┬───────┘    └────────┬─────────┘  │
│         │                   │                     │            │
│         └─────────────────── ↓ ──────────────────┘            │
│                    ┌──────────────────┐                        │
│                    │  Kong API Gateway │  ← solo modo SBOS     │
│                    │  (modo SBOS)     │                        │
│                    └────────┬─────────┘                        │
│                             │                                  │
│              ┌──────────────↓──────────────┐                   │
│              │      SmartRatesAPI           │                   │
│              │      (Laravel 13)            │                   │
│              │                              │                   │
│              │  Controllers: Rates, Convert │                   │
│              │  Currencies, Countries       │                   │
│              │  Sync, Company, Health       │                   │
│              │                              │                   │
│              │  Middleware: AuthSwitch      │                   │
│              │             BitMaskAuthorize │                   │
│              │             SBOSContext      │                   │
│              │             SecurityHeaders  │                   │
│              │             RateLimit        │                   │
│              │                              │                   │
│              │  Jobs (Horizon):             │                   │
│              │    DailySyncFawazahmed       │                   │
│              │    DailySyncBcb              │                   │
│              │    DailySyncFrankfurter      │                   │
│              │    MonthlySyncImf            │                   │
│              │    BackfillJob (3 fases)     │                   │
│              │    BcbCrossValidationJob     │                   │
│              │                              │                   │
│              │  Events (Reverb):            │                   │
│              │    RatesUpdated              │                   │
│              │    SyncCompleted/Failed      │                   │
│              │    AdjustmentRequired        │                   │
│              └──────────────┬───────────────┘                   │
│                    ┌────────┴────────┐                         │
│                    │                 │                         │
│           ┌────────↓──────┐  ┌──────↓────────┐               │
│           │  PostgreSQL 18 │  │   Redis 7     │               │
│           │               │  │               │               │
│           │  smartrates_db│  │  DB0: cache   │               │
│           │  8 schemas    │  │  DB1: sessions│               │
│           │               │  │  DB2: queue   │               │
│           │  validation_db│  │               │               │
│           │  2 schemas    │  └───────────────┘               │
│           │               │                                  │
│           │  catalog.RATE()│ ← extensión C .so               │
│           │  pg_notify    │ ← Trigger → SSE → Ticker         │
│           └───────────────┘                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Flujo de datos — Sincronización diaria

```
06:00 — DailySyncFawazahmedJob
  ① HTTP GET cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/...
  ② Si falla → retry exponencial → si sigue fallando → activar Frankfurter
  ③ Parsear JSON: {"date":"2026-05-23","usd":{"bob":6.91,"eur":0.918,...}}
  ④ UPSERT masivo en rates.exchange_rates (500 registros por batch)
  ⑤ pg_notify('rates_channel', payload) → Laravel escucha → SSE → Ticker
  ⑥ Evento WebSocket: broadcast RatesUpdated → SmartRatesUI actualiza UI

06:30 — DailySyncBcbJob (lunes a viernes)
  ① HTTP GET bcb.gob.bo/...?qdd={d}&qmm={m}&qaa={a} → descarga Excel
  ② ReadFilter: leer solo filas de cotizaciones (no cargar todo en RAM)
  ③ Mapear códigos BCB a ISO 4217 via validation.currency_mapping
  ④ UPSERT en validation.bcb_cotizaciones

07:30 — BcbCrossValidationJob
  ① JOIN bcb_cotizaciones con exchange_rates para BOB/USD
  ② Si diferencia > 0.05 BOB → alerta WARN en validation.bcb_vs_oficial

01:00-04:00 — BackfillJob (solo si hay fases pendientes)
  ① Lee backfill_progress para saber dónde continuar
  ② Procesa hasta 100 requests de la fase activa con pausa de 30s entre cada uno
  ③ Actualiza backfill_progress con el avance
  ④ Se autodetiene a las 04:00
```

---

## Flujo de datos — Función catalog.RATE()

```
Query SQL en cualquier DB del cluster:
  SELECT catalog.RATE('18/03/2026', 'BOB', 'USD', 10, 6)

PostgreSQL 18 ejecuta la extensión C:
  1. Parsea la fecha (acepta DD/MM/YYYY y YYYY-MM-DD)
  2. SPI_connect() — acceso a shared memory del postmaster
  3. SELECT rate_mid FROM smartrates_db.rates.exchange_rates
     WHERE base='USD' AND quote='BOB' AND rate_date <= '2026-03-18'
     ORDER BY rate_date DESC LIMIT 1
     -- Cero red — shared memory del mismo cluster
  4. SELECT rate_mid ... WHERE quote='USD'  (rate_mid USD/USD = 1)
  5. resultado = 10 × (1.0 / 6.91) = 1.4472... → ROUND(1.4472, 6) = 1.447249
  6. IMMUTABLE: si 30.000 filas usan el mismo par+fecha → constant folding → 1 sola ejecución

Retorna: 1.436781
Tiempo:  ~0.001ms por llamada → 50.000 llamadas = ~50ms total
```

---

## Flujo de datos — Ticker SSE

```
1. PostgreSQL: INSERT en rates.exchange_rates
   ↓
2. Trigger trg_notify_rate_change → pg_notify('rates_channel', payload_json)
   ↓
3. PHP (SmartRatesAPI) escucha pg_notify con poll cada 30s
   ↓
4. Al recibir notificación → response()->stream() envía:
   "data: {base:'USD',quote:'BOB',rate_mid:6.91,...}\n\n"
   ↓
5. EventSource en el browser recibe el evento
   ↓
6. Web Component <smartrates-ticker> actualiza el DOM
   Animación: fade-in del nuevo valor, color verde (subió) o rojo (bajó)
```

---

## Decisiones de diseño tomadas (ADR)

### ADR-SR-001: NULL prohibido en todos los campos
**Decisión:** Todos los campos tienen `NOT NULL` con `DEFAULT` explícito. No existe un solo campo nullable en el schema.  
**Razón:** NULL representa ignorancia. Los datos financieros no pueden ser ignorados — si no hay dato, hay un valor explícito que lo indique (0.00, '', '9999-12-31', 'carried_forward'). Los análisis históricos con NULLs son irrecuperables.

### ADR-SR-002: Base de datos siempre USD
**Decisión:** Todos los pares se almacenan con `base_currency='USD'`. No se almacenan pares directos BOB/EUR, BOB/PEN, etc.  
**Razón:** Normalización. Si hay 200 monedas y se almacenan todos los pares posibles, son 200×199 = 39.800 registros por día. Con base USD, son 200 registros por día y cualquier cross-rate se calcula en microsegundos via la moneda puente.

### ADR-SR-003: catalog.RATE() como extensión C, no PL/pgSQL
**Decisión:** La función de conversión está implementada en C como extensión `.so`, no como procedimiento PL/pgSQL.  
**Razón:** 0.001ms vs 0.5ms por llamada. Para 50.000 llamadas: 50ms vs 25.000ms. Los reportes JasperReports con inventario completo son el caso de uso que justifica la decisión. IMMUTABLE + constant folding de PG18 amplifica aún más la ventaja.

### ADR-SR-004: SSE para Ticker, WebSocket para SmartRatesUI
**Decisión:** La cinta informativa usa SSE (EventSource). La app Flutter usa WebSocket (Reverb).  
**Razón:** SSE es unidireccional — exactamente lo que necesita la cinta. No requiere configuración especial de proxies, reconecta automáticamente, funciona en cualquier CDN. WebSocket es bidireccional — necesario para la app Flutter que también envía (confirmar ajuste, forzar sync).

### ADR-SR-005: Backfill a máximo 100 requests/noche por fuente
**Decisión:** El backfill nunca supera 100 requests nocturnos a ninguna fuente.  
**Razón:** Evitar ser bloqueado o identificado como abusivo. El backfill es un proceso sin urgencia — puede tomar 23 noches y está bien. Lo que importa es que termine, no cuándo.

### ADR-SR-006: Particionamiento de exchange_rates por año
**Decisión:** La tabla `rates.exchange_rates` está particionada por año (`PARTITION BY RANGE (rate_date)`).  
**Razón:** El sistema tendrá datos desde 1990. Sin particionamiento, una tabla con 36 años × 365 días × 200 monedas = 2.6 millones de registros haría las purgas lentas. Con particionamiento: `DROP PARTITION y2000` elimina un año entero en milisegundos.

### ADR-SR-007: Validación de BCB en base de datos separada
**Decisión:** Los datos del BCB van a `smartrates_db (schema validation)`, no a `smartrates_db`.  
**Razón:** Los datos BCB son de validación y referencia, no de operación. Tenerlos en una BD separada garantiza que un problema en la validación (ej: formato de Excel cambia) no afecta la operación del sistema principal.

---

## Restricciones técnicas

- El sistema DEBE funcionar sin SBOS — `AUTH_DRIVER=sanctum` y `SYNC_MODE=internal` deben ser completamente funcionales
- La función `catalog.RATE()` es un `.so` compilado — requiere PostgreSQL 18 en el mismo servidor donde se instala
- `WITHOUT OVERLAPS` es una feature de PostgreSQL 18 — no compatible con PG17 o anterior
- `uuidv7()` es una función nativa de PostgreSQL 18 — no disponible en versiones anteriores
- El backfill NUNCA corre fuera de la ventana 01:00-04:00 — es un requisito de comportamiento del sistema
- Los tipos de cambio históricos son **inmutables** — no se modifican, solo se agregan correcciones como registros nuevos

---
_SKULL · SBOS · SmartRates · 006-ARQUITECTURA · v1.0 · 2026-05-23_
