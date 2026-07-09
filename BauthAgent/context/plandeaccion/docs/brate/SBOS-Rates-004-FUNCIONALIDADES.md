# Funcionalidades — SBOS SmartRates

---

## Módulo 1 — Cotizaciones

### F-001: Cotizaciones del día
**Como** cualquier usuario autenticado  
**Quiero** ver todas las cotizaciones del día en una sola consulta  
**Para** saber el estado cambiario actual sin buscar en múltiples fuentes

**Criterios de aceptación:**
- [ ] `GET /api/v1/rates/today` retorna todas las monedas activas con cotización del día
- [ ] La respuesta incluye: `base_currency`, `quote_currency`, `rate_buy`, `rate_sell`, `rate_mid` (calculado), `rate_official`, `rate_date`, `source`, `type_code`, `quality`
- [ ] Si `adjustment > 0`, incluye además: `rate_black_buy`, `rate_black_sell`, `black_rate_name`
- [ ] Si el día es festivo o fin de semana, retorna el dato más reciente con `type_code='carried_forward'`
- [ ] Respuesta cacheada en Redis con TTL de 5 minutos para endpoints no-admin
- [ ] La respuesta incluye ETag (RFC 7232) para cache del cliente
- [ ] Tiempo de respuesta p95 < 200ms (desde cache Redis)

**Reglas de negocio aplicables:** RN-004, RN-005, RN-006

---

### F-002: Cotizaciones por fecha
**Como** cualquier usuario autenticado  
**Quiero** consultar las cotizaciones de cualquier fecha pasada  
**Para** validar documentos, facturas o transacciones históricas

**Criterios de aceptación:**
- [ ] `GET /api/v1/rates/{date}` acepta formato `YYYY-MM-DD` y `DD-MM-YYYY`
- [ ] Retorna las mismas columnas que F-001 para la fecha solicitada
- [ ] Si se solicita una fecha futura, retorna error `SR-422` con mensaje claro
- [ ] Si se solicita una fecha anterior a los datos disponibles, retorna `SR-404` con la fecha más antigua disponible
- [ ] El historial disponible para BOB es desde 1990-01-01

**Reglas de negocio aplicables:** RN-003, RN-006

---

### F-003: Par de monedas específico
**Como** cualquier usuario autenticado  
**Quiero** consultar el tipo de cambio de un par específico (ej: USD/BOB)  
**Para** obtener exactamente los datos que necesito sin procesar toda la lista

**Criterios de aceptación:**
- [ ] `GET /api/v1/rates/{base}/{quote}` retorna el par solicitado para hoy
- [ ] Si el par no tiene cotización directa, calcula via cross-rate y lo indica en `calculated_via`
- [ ] Si alguna de las monedas no existe, retorna `SR-404` con lista de monedas válidas

---

### F-004: Serie temporal
**Como** operador o desarrollador  
**Quiero** obtener la evolución de un par de monedas en un rango de fechas  
**Para** construir gráficos de tendencia y análisis histórico

**Criterios de aceptación:**
- [ ] `GET /api/v1/rates/range?from=YYYY-MM-DD&to=YYYY-MM-DD&base=USD&currencies=BOB,EUR,BRL`
- [ ] Máximo 365 días por request — si supera, retorna `SR-422` con sugerencia de división
- [ ] Respuesta paginada si hay más de 1.000 registros
- [ ] Incluye la variación porcentual día a día en el campo `variation_pct`
- [ ] Tiempo de respuesta p95 < 500ms

---

## Módulo 2 — Conversión

### F-005: Conversión simple
**Como** cualquier usuario autenticado  
**Quiero** convertir un monto de una moneda a otra  
**Para** saber cuánto vale algo en otra moneda con el tipo de cambio del día

**Criterios de aceptación:**
- [ ] `GET /api/v1/convert?from=BOB&to=USD&amount=100`
- [ ] Retorna el resultado con el desglose del cross-rate si aplica (BOB→USD→PEN)
- [ ] El desglose muestra cada paso: `steps: [{from:'BOB', to:'USD', rate:6.91, result:14.47}, ...]`
- [ ] Muestra la fuente y calidad del dato usado
- [ ] Acepta parámetro opcional `date=YYYY-MM-DD` para conversión histórica

**Reglas de negocio aplicables:** RN-021, RN-022, RN-023

---

### F-006: Conversión a múltiples monedas simultáneas
**Como** vendedor que exporta  
**Quiero** ver cuánto vale un precio en BOB en los principales países de destino simultáneamente  
**Para** presentar precios en moneda local a cada comprador sin calcular uno por uno

**Criterios de aceptación:**
- [ ] `GET /api/v1/convert/multi?from=BOB&amount=100&to=USD,EUR,BRL,PEN,ARS,CLP`
- [ ] Retorna todos los destinos en una sola respuesta JSON
- [ ] Máximo 20 monedas de destino por request
- [ ] Tiempo de respuesta p95 < 300ms independientemente del número de destinos

---

### F-007: Conversión en lote
**Como** sistema consumidor (Tryton, SmartTax)  
**Quiero** enviar múltiples conversiones en un solo request  
**Para** evitar llamadas HTTP individuales en procesamiento masivo

**Criterios de aceptación:**
- [ ] `POST /api/v1/convert/batch` acepta hasta 100 conversiones por request
- [ ] Body: `[{"from":"BOB","to":"USD","amount":10,"date":"2026-05-23"}, ...]`
- [ ] Retorna array de resultados en el mismo orden del input
- [ ] Si alguna conversión falla (moneda no existe, fecha fuera de rango), retorna el error solo en ese elemento — las demás se procesan
- [ ] Tiempo de respuesta p95 < 1.000ms para 100 conversiones

---

### F-008: Variación en rango de fechas
**Como** analista financiero  
**Quiero** saber cuánto varió un tipo de cambio en un período  
**Para** analizar tendencias y tomar decisiones de timing en operaciones internacionales

**Criterios de aceptación:**
- [ ] `GET /api/v1/convert/fluctuation?from=BOB&to=USD&start_date=2026-01-01&end_date=2026-05-23`
- [ ] Retorna: variación absoluta, variación porcentual, máximo, mínimo, promedio del período
- [ ] Incluye las fechas del máximo y del mínimo

---

## Módulo 3 — Catálogos

### F-009: Catálogo de monedas
**Como** desarrollador o usuario  
**Quiero** consultar el catálogo completo de monedas con toda su información  
**Para** poblar selectores, validar códigos y obtener formatos de presentación

**Criterios de aceptación:**
- [ ] `GET /api/v1/currencies` retorna todas las monedas activas
- [ ] Cada moneda incluye: código ISO, nombre en español e inglés, símbolo, separadores, bandera emoji, país emisor
- [ ] `GET /api/v1/currencies/{code}` retorna el detalle de una moneda con su configuración de black rate si aplica
- [ ] `GET /api/v1/currencies/groups` retorna agrupadas por bloque económico (G7, BRICS, Mercosur, OPEC, Europa)
- [ ] El catálogo está cacheado indefinidamente — solo cambia con migraciones

---

### F-010: Catálogo de países
**Como** desarrollador  
**Quiero** consultar los países con sus monedas asociadas  
**Para** implementar selectores de país que automáticamente eligen la moneda correcta

**Criterios de aceptación:**
- [ ] `GET /api/v1/countries` retorna todos los países ISO 3166
- [ ] `GET /api/v1/countries/by-block?block=mercosur` filtra por bloque económico
- [ ] Cada país incluye: código alfa-2, alfa-3, nombre en español e inglés, bandera emoji, moneda principal

---

## Módulo 4 — Mercado Alternativo y Ajuste

### F-011: Confirmación del ajuste diario
**Como** operador financiero  
**Quiero** confirmar el monto del ajuste del mercado alternativo para el día  
**Para** que todas las aplicaciones del ecosistema usen el rate correcto en las transacciones nacionales del día

**Criterios de aceptación:**
- [ ] El sistema detecta automáticamente el primer acceso del día y emite el evento `adjustment.required` por WebSocket
- [ ] El frontend abre automáticamente la pantalla de confirmación en ese evento
- [ ] `POST /api/v1/company/adjustment/confirm` recibe `{currency_code, rate_date, adjustment_value, notes}`
- [ ] Al confirmar, el sistema calcula `rate_black_buy = rate_official + adjustment`, `rate_black_sell = rate_official + adjustment + spread`
- [ ] `GET /api/v1/company/adjustment/status` indica si el ajuste del día fue confirmado, quién lo confirmó y cuándo
- [ ] Si no se confirma antes de las 17:00, el sistema aplica el ajuste del día anterior como provisional y emite alerta WARN

**Reglas de negocio aplicables:** RN-010, RN-011, RN-012

---

### F-012: Configuración de política de mercado alternativo
**Como** administrador  
**Quiero** configurar cómo la empresa maneja el mercado alternativo  
**Para** que el sistema refleje exactamente la política cambiaria que aplica la empresa

**Criterios de aceptación:**
- [ ] `PUT /api/v1/company/rate-config` acepta `{currency_code, use_black_rate, international_currency, valid_from, notes}`
- [ ] Los tres valores de `use_black_rate`: `disabled`, `reference`, `national` — descripción clara de cada uno en la respuesta
- [ ] Al activar `national`, el campo `international_currency` es obligatorio
- [ ] La nueva configuración tiene `valid_from` que no puede ser una fecha pasada
- [ ] `GET /api/v1/company/rate-config` retorna la configuración actual y el historial de cambios

**Reglas de negocio aplicables:** RN-007, RN-008, RN-009

---

## Módulo 5 — Sincronización

### F-013: Sincronización diaria automática
**Como** sistema  
**Quiero** sincronizar automáticamente los tipos de cambio cada mañana  
**Para** tener datos actualizados antes de que comience la operación del día

**Criterios de aceptación:**
- [ ] `DailySyncFawazahmedJob` corre a las 06:00 todos los días
- [ ] `DailySyncBcbJob` corre a las 06:30 lunes a viernes
- [ ] `DailySyncFrankfurterJob` corre a las 07:00 días hábiles (como respaldo)
- [ ] `MonthlySyncImfJob` corre el día 5 de cada mes a las 08:00
- [ ] Si fawazahmed0 falla, el circuit breaker activa automáticamente Frankfurter como fallback
- [ ] Al completar la sincronización, emite el evento WebSocket `sync.completed`
- [ ] Al fallar, emite `sync.failed` con detalle del error

**Reglas de negocio aplicables:** RN-018, RN-019, RN-020

---

### F-014: Manejo de fines de semana y feriados
**Como** sistema  
**Quiero** manejar correctamente los días sin datos del BCB  
**Para** que el historial nunca tenga huecos y las aplicaciones siempre tengan un dato disponible

**Criterios de aceptación:**
- [ ] El lunes, el sistema descarga sábado + domingo + lunes en ese orden
- [ ] Si BCB no tiene datos para un día (feriado o fin de semana), almacena `carried_forward` del último día hábil
- [ ] fawazahmed0 opera 7 días — esos datos se almacenan como `official_daily` incluso en fines de semana
- [ ] Al retornar cotizaciones, siempre hay un dato disponible para cualquier fecha desde 1990

**Reglas de negocio aplicables:** RN-005, RN-020

---

### F-015: Monitoreo de fuentes externas
**Como** administrador  
**Quiero** ver en tiempo real el estado de cada fuente externa  
**Para** detectar y resolver problemas de sincronización antes de que afecten la operación

**Criterios de aceptación:**
- [ ] `GET /api/v1/sync/sources` retorna para cada fuente: estado del circuit breaker, última sincronización exitosa, última sincronización fallida, tiempo de respuesta promedio
- [ ] `GET /api/v1/sync/status` retorna el resumen de la última sincronización completa
- [ ] `POST /api/v1/sync/trigger` fuerza una sincronización inmediata (solo admin)
- [ ] Circuit breaker implementado: después de 3 fallos consecutivos, marca la fuente como `OPEN` y espera 10 minutos antes de reintentar

---

## Módulo 6 — Backfill Histórico

### F-016: Backfill en tres fases
**Como** sistema (en la noche)  
**Quiero** recuperar el historial completo de cotizaciones en segundo plano  
**Para** tener datos disponibles desde 1990 sin interrumpir la operación diaria

**Criterios de aceptación:**
- [ ] Fase 1 (fawazahmed0): datos diarios 2022-hoy, 100 req/noche, ~15 noches
- [ ] Fase 2 (FMI): datos mensuales 2016-2021, 12-48 req total, 1 noche
- [ ] Fase 3 (BCB histórico): referencia 1990-2015, 50 req/noche, ~7 noches
- [ ] `backfill_progress` registra el avance exacto — si se interrumpe, retoma donde quedó
- [ ] Solo corre entre las 01:00 y las 04:00 — se autodetiene fuera de esa ventana
- [ ] `POST /api/v1/sync/backfill` inicia o reanuda el backfill (solo admin)

**Reglas de negocio aplicables:** RN-017

---

## Módulo 7 — Validación BCB

### F-017: Validación cruzada BCB vs oficial
**Como** sistema  
**Quiero** comparar los datos del BCB con los de fawazahmed0 para BOB/USD  
**Para** detectar discrepancias que indiquen un problema en los datos

**Criterios de aceptación:**
- [ ] `BcbCrossValidationJob` corre a las 07:30 lunes a viernes (después de que ambos syncs completan)
- [ ] Compara `bcb_cotizaciones.rate_buy` y `rate_sell` con `exchange_rates.rate_buy` y `rate_sell` para BOB/USD
- [ ] Si la diferencia supera el umbral configurado (default: 0.05 BOB), genera entrada en `bcb_vs_oficial` con `alert=true`
- [ ] Las alertas son visibles en el panel del administrador con nivel WARN

**Reglas de negocio aplicables:** RN-015, RN-016

---

## Módulo 8 — Ticker

### F-018: Cinta informativa (Ticker)
**Como** cualquier aplicación del ecosistema o cliente externo  
**Quiero** mostrar los tipos de cambio del día en tiempo real en mi interfaz  
**Para** que mis usuarios tengan información cambiaria siempre visible sin salir de mi aplicación

**Criterios de aceptación:**
- [ ] Web Component `<smartrates-ticker>` funciona con una línea de `<script>` y una línea de `<smartrates-ticker>`
- [ ] Funciona en HTML puro, Laravel Blade, Vue 3, React, JSP, JasperReports Web Component
- [ ] Se actualiza en tiempo real via SSE sin polling
- [ ] Al desconectarse, EventSource reconecta automáticamente con backoff
- [ ] Atributos configurables: `currencies`, `theme` (light/dark/auto), `lang` (es/en), `speed`, `show-flags`, `show-variation`
- [ ] 34px de alto, 100% del ancho del contenedor — no interfiere con el layout
- [ ] Se pausa al pasar el mouse, se reanuda al salir
- [ ] Muestra tipos: cotización (blanco), alerta crítica (rojo pulsante), advertencia (ámbar), institucional (dorado), hora (lila), clima (amarillo)

---

## Módulo 9 — Función catalog.RATE()

### F-019: Función de conversión nativa PostgreSQL
**Como** desarrollador integrador o sistema consumidor  
**Quiero** una función SQL que convierta monedas sin latencia de red  
**Para** usar en queries masivos y reportes sin degradar el rendimiento

**Criterios de aceptación:**
- [ ] `catalog.RATE(fecha TEXT, desde TEXT, hacia TEXT, monto NUMERIC, decimales INT) RETURNS NUMERIC`
- [ ] Acepta fechas en formato `DD/MM/YYYY` y `YYYY-MM-DD`
- [ ] Ejemplo: `SELECT catalog.RATE('18/03/2026', 'BOB', 'USD', 10, 6)` → `1.436781`
- [ ] 50.000 llamadas con mismo par fecha+monedas: constant folding → ≈50ms total
- [ ] Declarada `IMMUTABLE STRICT PARALLEL SAFE COST 1`
- [ ] Si no hay dato para la fecha exacta, busca hacia atrás hasta 7 días
- [ ] Si no hay dato en 7 días, retorna NULL (por la cláusula STRICT)
- [ ] Instalable en cualquier BD del mismo cluster: `CREATE EXTENSION smartrates_rate`
- [ ] Disponible en Tryton, SmartTax, Saleor, JasperReports sin ninguna librería adicional

**Reglas de negocio aplicables:** RN-021, RN-022, RN-023

---

## Módulo 10 — Observabilidad y Salud

### F-020: Endpoints de salud del sistema
**Como** Kubernetes o cualquier orquestador  
**Quiero** endpoints de liveness y readiness  
**Para** gestionar el ciclo de vida del contenedor automáticamente

**Criterios de aceptación:**
- [ ] `GET /api/health` (liveness): responde `{"status":"ok"}` siempre que el proceso esté vivo. No verifica dependencias.
- [ ] `GET /api/ready` (readiness): verifica DB, Redis, fuentes externas. Retorna `{"status":"ready"}` o `{"status":"degraded","details":{...}}`
- [ ] `GET /api/status` (detallado): estado completo del sistema con métricas actuales, estado de cada fuente, última sincronización
- [ ] `GET /metrics` (Prometheus): expone SRE Golden Signals + métricas de negocio (cotizaciones procesadas, cache hit rate, latencia de fuentes)

---

### F-021: Logging estructurado con ctx_id
**Como** plataforma SBOS  
**Quiero** que todos los logs de SmartRates incluyan el ctx_id de la sesión  
**Para** poder correlacionar eventos de SmartRates con el resto del ecosistema en el audit trail

**Criterios de aceptación:**
- [ ] Todos los logs son JSON estructurado (nunca texto libre)
- [ ] Campos obligatorios: `timestamp`, `level`, `service`, `version`, `request_id`, `ctx_id` (vacío en modo standalone), `user_id`, `endpoint`, `response_code`, `response_ms`
- [ ] El `ctx_id` viene del header `X-SBOS-CtxId` inyectado por Kong en modo SBOS
- [ ] En modo standalone, `ctx_id` es siempre `''` (string vacío — no NULL)
- [ ] Nivel de log configurable por variable de entorno: `LOG_LEVEL=debug|info|warn|error`

---

## Módulo 11 — Explorador (Playground)

### F-022: Playground interactivo
**Como** desarrollador o usuario no técnico  
**Quiero** explorar qué puede hacer SmartRates de forma visual y lúdica  
**Para** entender las capacidades del sistema antes de integrarlo o usarlo

**Criterios de aceptación:**
- [ ] Disponible en `/explorer` sin autenticación (demo con datos reales públicos)
- [ ] Modo Monto: convertir un valor entre dos monedas, ver el desglose cross-rate paso a paso
- [ ] Modo Histórico: gráfico interactivo de la evolución de un par en el tiempo
- [ ] Modo Precio en varios países: ingresar precio en BOB, ver simultáneamente en 10 países
- [ ] Modo Comparativa: dos monedas en el mismo gráfico durante un período
- [ ] Modo Tabla del día: todas las cotizaciones del día filtradas por bloque económico
- [ ] Cada resultado muestra el endpoint REST exacto que se ejecutó, con botón "Copiar"
- [ ] La sección "Para desarrolladores" es discreta pero siempre visible

---
_SKULL · SBOS · SmartRates · 004-FUNCIONALIDADES · v1.0 · 2026-05-23_
