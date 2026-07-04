# Integraciones y Dependencias — SBOS SmartRates

---

## Fuentes externas de datos (entrada)

### Integración 1 — fawazahmed0 / currency-api

**Tipo:** API HTTP GET (CDN jsDelivr)  
**Dirección:** SmartRates llama a la fuente externa  
**Rol:** Fuente primaria de cotizaciones diarias — 200+ monedas  
**Frecuencia:** Diaria a las 06:00, más backfill nocturno (hasta 100 req/noche)

**URLs verificadas y funcionales:**
```
Principal: https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json
Por fecha:  https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{YYYY-MM-DD}/v1/currencies/usd.min.json
Respaldo:  https://latest.currency-api.pages.dev/v1/currencies/usd.min.json
```

**Estructura de respuesta:**
```json
{
  "date": "2026-05-23",
  "usd": {
    "bob": 6.91,
    "eur": 0.918,
    "brl": 5.72,
    "pen": 3.72,
    "ars": 1065.50
  }
}
```

**Características:**
- Gratuito, sin registro, sin API key
- Un solo request = todas las monedas del día
- Cobertura: G7, BRICS, Mercosur, LATAM, Europa, OPEC, OPEC+
- Licencia MIT — redistribución permitida con atribución
- Repositorio: github.com/fawazahmed0/exchange-api
- Dato: mid-rate interbancario oficial de mercado

**Manejo de fallos:**
- Circuit breaker: 3 fallos consecutivos → estado OPEN → espera 10 min → retry
- Fallback automático a URL de respaldo (`currency-api.pages.dev`)
- Si ambas URLs fallan → activar Frankfurter como fuente secundaria
- Política de reintentos: exponential backoff 1s, 2s, 4s, 8s

**Estado:** ✅ Disponible y verificado

---

### Integración 2 — FMI SDMX API 3.0

**Tipo:** API HTTP GET con header de autenticación  
**Dirección:** SmartRates llama al FMI  
**Rol:** Fuente histórica oficial — 179 países miembro FMI, datos desde 1924  
**Frecuencia:** Mensual el día 5 de cada mes + backfill nocturno (hasta 100 req/noche)

**URL base:** `https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.STA/ER/+/{KEY}`

**Autenticación:**
```
Header: Ocp-Apim-Subscription-Key: c2800287220f4bc18e147ad8dba321ab
Producto: IMF Data SDMX API (SBOS)
Fecha creación: 2026-03-17
```

**Formato de KEY (dimensiones en orden obligatorio):**
```
Posición 0: COUNTRY              → BOL, BRA, ARG, MEX, PER, PRY, CHL, URY, USA, GBR...
Posición 1: INDICATOR            → XDC_USD (unidades locales por USD)
Posición 2: TYPE_OF_TRANSFORMATION → PA_RT (promedio período), EOP_RT (fin período)
Posición 3: FREQUENCY            → M (mensual), A (anual), Q (trimestral)
```

**Ejemplo — Bolivia mensual vs USD:**
```
KEY: BOL.XDC_USD.PA_RT.M
URL: https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.STA/ER/%2B/BOL.XDC_USD.PA_RT.M
     ?c%5BTIME_PERIOD%5D=ge%3A2025-01%2Ble%3A2026-02
     &dimensionAtObservation=TIME_PERIOD
```

**Ejemplo — múltiples países un año completo (estrategia de backfill):**
```
KEY: BOL+BRA+ARG+MEX+PER+PRY+CHL+URY.XDC_USD.PA_RT.M
URL param: c[TIME_PERIOD]=ge:2020-01+le:2020-12
→ Un solo request = todos los países LATAM durante 2020
```

**Datos disponibles:**
- Bolivia (BOL): desde 1940
- Brasil, Argentina, México: desde 1960
- Mayoría de países: desde 1980-2000
- Frecuencia disponible: mensual (M), trimestral (Q), anual (A)

**Estado:** ✅ Disponible, key registrada y verificada

---

### Integración 3 — BCB Bolivia (Banco Central de Bolivia)

**Tipo:** Descarga de Excel via HTTP GET  
**Dirección:** SmartRates descarga el archivo del portal BCB  
**Rol:** Cotización oficial BOB — compra y venta del día — datos para validación  
**Frecuencia:** Lunes a viernes a las 06:30 + backfill histórico (hasta 50 req/noche)

**URL de descarga:**
```
https://www.bcb.gob.bo/librerias/indicadores/otras/otras_imprimir2XLS.php?qdd={d}&qmm={m}&qaa={a}
```
Donde `{d}` = día (1-31), `{m}` = mes (1-12), `{a}` = año (YYYY)

**Cotizaciones actuales (referencia mayo 2026):**
- Compra BCB: 6.86 BOB/USD (tipo de cambio oficial histórico fijo)
- Venta BCB: 6.96 BOB/USD (tipo de cambio oficial histórico fijo)
- Valor referencial (desde dic 2025): variable, basado en operaciones reales del sistema financiero

**Contexto crítico (noviembre 2025 - 2026):**
El BCB inició una transición hacia un tipo de cambio más flexible. Desde diciembre de 2025 publica el "valor referencial del dólar" calculado sobre operaciones reales de las entidades financieras. Esto crea dos referencias:
1. Tipo de cambio oficial fijo (histórico)
2. Valor referencial de mercado (nuevo desde dic 2025)

SmartRates debe capturar **ambos** valores cuando el BCB los publique y almacenarlos diferenciados.

**Parseo del Excel:**
- Librería: `Maatwebsite/Laravel-Excel` o `Box/Spout` (sin carga completa en RAM)
- `ReadFilter`: leer solo las filas con datos de cotizaciones, no el Excel completo
- Mapeo de códigos BCB a ISO 4217 en tabla `validation.currency_mapping` (CNH→CNY, VEB→VES, etc.)

**Disponibilidad:** Solo lunes a viernes. Fines de semana y feriados bolivianos: archivo vacío o no disponible.

**Estado:** ✅ Disponible y verificado

---

### Integración 4 — Frankfurter (Banco Central Europeo)

**Tipo:** API HTTP GET  
**Dirección:** SmartRates llama a la instancia local Docker  
**Rol:** Fuente de respaldo para 32 monedas principales cuando fawazahmed0 falla  
**Frecuencia:** Diaria a las 07:00 (modo respaldo) + auto-activación cuando fawazahmed0 falla

**URL (instancia Docker local):**
```
http://frankfurter:8080/latest?from=USD
http://frankfurter:8080/{YYYY-MM-DD}?from=USD
```

**Características:**
- Licencia MIT — open source, auto-alojable con Docker
- 32 monedas principales: EUR, GBP, JPY, CHF, CAD, SEK, NOK, DKK, etc.
- Actualización: días hábiles a las 16:00 CET (datos del BCE)
- Historial desde 04/01/1999
- No requiere API key ni registro

**Docker Compose:**
```yaml
frankfurter:
  image: ghcr.io/hakanensari/frankfurter:latest
  ports: ["8080:8080"]
  restart: unless-stopped
```

**Cuándo se activa como respaldo:**
- Circuit breaker de fawazahmed0 en estado OPEN
- fawazahmed0 devuelve datos incompletos (menos del 80% de monedas esperadas)
- Timeout de fawazahmed0 > 30 segundos

**Limitación:** solo 32 monedas. Para las 200+ monedas se depende de fawazahmed0.

**Estado:** ✅ Disponible — requiere instancia Docker en el stack

---

## Integraciones internas — Ecosistema SBOS

### Integración 5 — Kong API Gateway

**Tipo:** Infraestructura interna SBOS  
**Rol:** Todo el tráfico externo a SmartRatesAPI pasa por Kong en modo SBOS  
**Headers que Kong inyecta en cada request:**
```
X-SBOS-CtxId:     ctx-88291-a4f9
X-SBOS-Tenant:    skull
X-SBOS-Empresa:   maya
X-SBOS-Sucursal:  lapaz
X-SBOS-User:      3397708
X-SBOS-BitMask:   0x00000000000A3F21
```
**Solo en modo AUTH_DRIVER=keycloak.** En modo standalone, no hay Kong.

---

### Integración 6 — Keycloak (autenticación producción)

**Tipo:** OAuth2/OIDC — autenticación delegada  
**Rol:** Autenticación SSO en modo SBOS. SmartRates no tiene login propio en producción.  
**Configuración requerida:**
```
Realm:        {tenant} (ej: skull)
Client ID:    smartrates-api
Client Type:  confidential
Roles a crear: smartrates.admin, smartrates.operator, smartrates.readonly, smartrates.api
```
**Solo activo cuando:** `AUTH_DRIVER=keycloak`

---

### Integración 7 — Laravel Sanctum (autenticación desarrollo)

**Tipo:** Token personal en BD local  
**Rol:** Autenticación en modo standalone y desarrollo  
**Solo activo cuando:** `AUTH_DRIVER=sanctum`  
**Tabla:** `personal_access_tokens` en la BD local

---

### Integración 8 — Redis (cache y pub/sub)

**Tipo:** Redis 7 — cache + pub/sub  
**Propósito:**
- Cache de cotizaciones del día (TTL 5 minutos para endpoints cacheados)
- Sessions de Sanctum
- Queue de Laravel Horizon (backfill jobs, sync jobs)
- Pub/sub para broadcast de eventos a través de Laravel Reverb

**Databases Redis en modo SBOS:**
```
DB0: Cache de SmartRates (cotizaciones, responses)
DB1: Sessions
DB2: Queue (Horizon)
```
En modo standalone, todo en DB0 con prefijos.

---

### Integración 9 — bKernel / biedata (producción SBOS)

**Tipo:** Integración pasiva (bKernel escucha el WAL) + activa (biedata ejecuta sync)  
**Rol:**
- bKernel escucha el WAL de PostgreSQL y registra todo en `audit_events` con `ctx_id`
- En modo `SYNC_MODE=biedata`, las sincronizaciones externas son activadas por biedata en lugar de los jobs de Horizon
- SmartRates no necesita hacer nada — es transparente

**Solo activo cuando:** `SYNC_MODE=biedata` (modo producción SBOS)

---

### Integración 10 — PostgreSQL 18 (cluster SBOS)

**Tipo:** Misma instancia PostgreSQL 18 del cluster  
**Rol en producción:** SmartRatesAPI se conecta al PostgreSQL del cluster SBOS (Patroni HA)  
**Rol en desarrollo:** PostgreSQL local en Docker  
**Tabla especial:** La extensión `smartrates_rate` instalada en el cluster permite que **cualquier otra BD del mismo cluster** llame `catalog.RATE()` directamente, accediendo a `rates.exchange_rates` via shared memory del postmaster.

---

### Integración 11 — Tryton ERP (consumidor)

**Tipo:** Consumidor de datos — llama `catalog.RATE()` en queries SQL  
**Rol:** Tryton usa SmartRates para:
- Contabilidad multicurrency: valorar activos y pasivos en USD/EUR
- Facturas en moneda extranjera: calcular el equivalente en BOB para el SIAT
- Reportes de balance en múltiples monedas

**Forma de integración:**
```sql
-- En la BD de Tryton (mismo cluster PostgreSQL 18):
CREATE EXTENSION smartrates_rate;
-- Ahora Tryton puede usar catalog.RATE() directamente en sus queries
```

---

### Integración 12 — SmartTax (consumidor)

**Tipo:** Consumidor de datos — API REST o `catalog.RATE()`  
**Rol:** SmartTax necesita el tipo de cambio oficial del BCB para:
- Calcular el valor en BOB de facturas emitidas en moneda extranjera (requerimiento legal boliviano)
- El SIAT exige que el monto en BOB use el tipo de cambio oficial del día de emisión

**Endpoint específico:** `GET /api/v1/rates/{date}?currencies=BOB&source=bcb` para obtener el dato certificado del BCB.

---

## Estado de integraciones

| Sistema | Tipo | Modo | Estado | Documentación |
|---|---|---|---|---|
| fawazahmed0 | HTTP GET CDN | Standalone + SBOS | ✅ Activo | github.com/fawazahmed0/exchange-api |
| FMI SDMX 3.0 | HTTP GET con key | Standalone + SBOS | ✅ Activo, key registrada | portal.api.imf.org |
| BCB Bolivia | HTTP GET Excel | Standalone + SBOS | ✅ Activo | www.bcb.gob.bo |
| Frankfurter | HTTP GET Docker | Standalone + SBOS | ✅ Activo (auto-alojado) | github.com/hakanensari/frankfurter |
| Kong | Proxy gateway | Solo SBOS | ✅ Parte del stack | SBOS-MANUAL §15 |
| Keycloak | OIDC | Solo SBOS | ✅ Parte del stack | SBOS-MANUAL §8 |
| Redis | Cache/Queue | Standalone + SBOS | ✅ Docker local / externo | — |
| bKernel/biedata | WAL/cajas | Solo SBOS | 🔵 Diseñado, pendiente cajas | SBOS-MANUAL §12-14 |
| Tryton | catalog.RATE() | Solo SBOS | 🔵 Diseñado | — |
| SmartTax | REST API | Standalone + SBOS | 🔵 Diseñado | — |

---
_SKULL · SBOS · SmartRates · 005-INTEGRACIONES · v1.0 · 2026-05-23_
