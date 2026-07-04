# Modelo de Dominio — SBOS SmartRates

---

## Glosario obligatorio

| Término | Definición precisa | Sinónimos en el negocio |
|---|---|---|
| **Tipo de cambio** | Precio de una moneda expresado en términos de otra. Siempre es un par: base/cotizada. | Cotización, tasa de cambio, cambio |
| **Moneda base** (`base_currency`) | La moneda que se compra o vende. En los pares del sistema, siempre USD. Ejemplo: en USD/BOB la base es USD | Moneda de referencia |
| **Moneda cotizada** (`quote_currency`) | La moneda con la que se paga la base. En USD/BOB la cotizada es BOB: cuántos bolivianos cuesta un dólar | Moneda precio |
| **Moneda doméstica** (`domestic_currency`) | La moneda del país donde opera la empresa. Para Bolivia: BOB. Es la unidad de cuenta interna — todos los precios se almacenan en esta moneda | Moneda local |
| **Moneda puente** (`bridge_currency`) | Moneda intermediaria para conversiones internacionales. Por defecto USD. Toda conversión entre dos monedas no-USD pasa por la puente: BOB→USD→PEN | Moneda pivot, moneda intermediaria |
| **Mid-rate** (`rate_mid`) | Promedio matemático de compra y venta: `(rate_buy + rate_sell) / 2`. Columna VIRTUAL en PostgreSQL 18 — calculada en consulta, no almacenada | Tipo medio, tasa media |
| **Rate oficial** (`rate_official`) | Tipo de cambio publicado por la fuente oficial para la fecha. Para BOB es el BCB. Para otras monedas, fawazahmed0 o FMI | Cotización oficial |
| **Rate buy / Rate sell** (`rate_buy`, `rate_sell`) | Precio de compra y venta desde la perspectiva del banco/casa de cambio. El banco compra a rate_buy (más bajo) y vende a rate_sell (más alto) | Compra / Venta, bid / ask |
| **Ajuste** (`adjustment`) | Valor numérico que se suma al rate_official para obtener el rate del mercado alternativo. Configurado manualmente por el operador cada día hábil | Ajuste manual, diferencial |
| **Black rate** | Tipo de cambio del mercado alternativo (no oficial). En Bolivia: mercado paralelo. En Argentina: dólar blue. El nombre varía por país | Mercado paralelo, dólar blue, dólar informal |
| **Black rate name** (`black_rate_name`) | Nombre local del mercado alternativo según el país. Propiedad del país, no de la moneda | "mercado paralelo" (Bolivia), "dólar blue" (Argentina) |
| **Carried forward** | Cuando no hay dato para una fecha (fin de semana, feriado), se propaga el último dato disponible. `data_type='carried_forward'` | Dato propagado, último disponible |
| **Weekend estimate** | Estimación para días de fin de semana usando interpolación linear entre el viernes y el lunes. `data_type='weekend_estimate'` | Estimación fin de semana |
| **Interpolated** | Dato estimado matemáticamente cuando faltan datos entre dos fechas conocidas. `data_type='interpolated'` | Dato interpolado |
| **Data quality** | Clasificación de confiabilidad del dato: `high` (oficial diario), `medium` (mensual/interpolado), `low` (histórico/estimado) | Calidad del dato |
| **Cross-rate** | Conversión entre dos monedas que no tienen cotización directa entre sí, calculada mediante una moneda puente. BOB→PEN = BOB→USD→PEN | Tasa cruzada, conversión cruzada |
| **Backfill** | Proceso de recuperación histórica: descarga datos de fechas pasadas de forma progresiva y silenciosa, en ventana nocturna | Relleno histórico, recuperación histórica |
| **Circuit breaker** | Mecanismo que deja de intentar llamar a una fuente externa cuando esta falla repetidamente, evitando cascadas de errores. Se reactiva automáticamente | Cortacircuitos, disyuntor |
| **Fuente primaria** | fawazahmed0 — descarga diaria de todas las monedas. Primera fuente intentada en el flujo de sincronización | Fuente principal |
| **Fuente de respaldo** | Frankfurter (BCE) — 32 monedas principales. Se activa cuando fawazahmed0 no está disponible | Fallback |
| **Fuente oficial Bolivia** | BCB — Banco Central de Bolivia. Excel diario con compra/venta de todas las divisas oficiales. Solo lunes a viernes | BCB, banco central |
| **Fuente histórica oficial** | FMI SDMX API 3.0 — 179 países, datos mensuales desde 1924. Para backfill de largo plazo | FMI, fondo monetario |
| **SDMX** | Statistical Data and Metadata eXchange — estándar internacional para intercambio de datos estadísticos financieros. El FMI publica su API en SDMX 3.0 | — |
| **ISO 4217** | Estándar internacional de códigos de monedas. USD, BOB, EUR, BRL. 3 letras alfabético, 3 dígitos numérico | Código de moneda |
| **ISO 3166-1** | Estándar internacional de códigos de países. BO (Bolivia), US (Estados Unidos). Alfa-2 y alfa-3 | Código de país |
| **Bloque económico** | Grupo de países con acuerdos comerciales o financieros. G7, BRICS, Mercosur, OPEC, OPEC+, Europa | Bloque regional |
| **Función RATE()** | Extensión C nativa de PostgreSQL 18 que convierte monedas en nanosegundos consultando `rates.exchange_rates` via SPI (Server Programming Interface), sin red | `catalog.RATE()` |
| **SPI** | Server Programming Interface — mecanismo de PostgreSQL para que funciones C ejecuten SQL directamente en shared memory del servidor, sin TCP | — |
| **IMMUTABLE** | Declaración PostgreSQL que indica que una función siempre retorna el mismo resultado para los mismos parámetros. Activa constant folding: si 30.000 filas usan el mismo par fecha+monedas, la función se ejecuta una sola vez | Constante, determinista |
| **Ticker** | Cinta horizontal de información continua que muestra tipos de cambio en scroll. Implementado como Web Component SSE | Cinta informativa, band de cotizaciones |
| **SSE** | Server-Sent Events — protocolo HTTP unidireccional (servidor→cliente) para streaming de datos en tiempo real. Ideal para el Ticker: el servidor envía, el cliente recibe | EventSource |
| **Web Component** | Estándar del W3C para crear elementos HTML reutilizables. `<smartrates-ticker>` funciona en cualquier framework (Vue, React, Blade, JSP) sin dependencias | Custom element |
| **Auth Switch** | Mecanismo de SmartRates para cambiar entre autenticación Sanctum (standalone) y Keycloak (SBOS) con una sola variable de entorno. Sin cambios de código | — |

---

## Entidades principales del negocio

### Moneda (`catalog.currencies`)

**Qué es:** Unidad de intercambio reconocida internacionalmente según ISO 4217. El catálogo cubre 200+ monedas fiat. No incluye criptomonedas.

**Atributos clave:** código alfabético (BOB, USD, EUR), código numérico (068, 840, 978), decimales oficiales (JPY=0, USD=2, KWD=3), símbolo (Bs., $, €), formato de número (separador decimal y de miles varía por moneda), bandera emoji (para supranacionales como 🇪🇺), país emisor principal.

**Reglas de negocio aplicables:** RN-001, RN-002

**Particularidades:** monedas supranacionales (EUR, XAU, XAG, XDR) no tienen país único — FK a países es `NOT ENFORCED` en PG18. El oro (XAU) y la plata (XAG) son ISO 4217 y SmartRates las cubre.

---

### Tipo de Cambio (`rates.exchange_rates`)

**Qué es:** El precio de una moneda en términos de otra para una fecha específica. Es la entidad central del sistema. Toda consulta y toda conversión parte de esta tabla.

**Ciclo de vida:** es creado por el proceso de sincronización (fawazahmed0, FMI, BCB) o por el backfill. Nunca se modifica ni elimina — es un registro histórico inmutable. Si hay una corrección, se inserta un nuevo registro con `data_type='correction'`.

**Atributos clave:** `base_currency` (siempre USD), `quote_currency`, `rate_official`, `rate_buy`, `rate_sell`, `rate_mid` (VIRTUAL), `adjustment`, `rate_black_buy`, `rate_black_sell`, `rate_date`, `source_code`, `type_code`, `quality`.

**Retención:** 10 años mínimo (requisito normativo). Datos históricos de Bolivia desde 1990.

**Reglas de negocio aplicables:** RN-003, RN-004, RN-005, RN-006

---

### Configuración de Empresa (`company.rate_config`)

**Qué es:** La política cambiaria de una empresa específica para una moneda específica durante un período de tiempo. Define cómo esa empresa quiere que funcione el mercado alternativo.

**Tres modos de política (`use_black_rate`):**
- `disabled` → usa exclusivamente el tipo oficial para todas las operaciones
- `reference` → muestra el black rate como dato informativo pero no lo usa en cálculos
- `national` → usa el black rate para transacciones nacionales; OBLIGA a usar `international_currency` (generalmente USD) para transacciones internacionales. Esta es una política de protección económica legal en Bolivia.

**Vigencia temporal:** usa `WITHOUT OVERLAPS` de PostgreSQL 18 — garantiza que no haya solapamiento de períodos para la misma empresa+moneda. La tabla tiene cobertura temporal completa sin gaps ni overlaps.

**Reglas de negocio aplicables:** RN-007, RN-008, RN-009

---

### Ajuste Diario (`company.adjustment_daily`)

**Qué es:** El monto de ajuste confirmado por el operador para una empresa, moneda y fecha específica. Representa el diferencial que la empresa aplica al rate oficial para obtener sus rates operativos del día.

**Flujo de confirmación:** el sistema detecta automáticamente que el primer usuario del día abre la app → emite el evento WebSocket `adjustment.required` → el operador ve la pantalla de confirmación → ingresa el monto de ajuste → confirma → el sistema almacena con quién confirmó, cuándo y el valor exacto.

**Audit trail:** cada confirmación queda registrada con `confirmed_by` (user_id) y `confirmed_at` (timestamp). No se puede modificar — solo confirmar el del día.

**Reglas de negocio aplicables:** RN-010, RN-011, RN-012

---

### Configuración de Sistema (`company.system_config`)

**Qué es:** La configuración general del sistema para una empresa: moneda doméstica, moneda puente, país de operación, y política de conversión. Define el contexto de todas las conversiones.

**Vigencia temporal:** también usa `WITHOUT OVERLAPS` — permite cambiar la configuración a futuro sin afectar el pasado.

**Reglas de negocio aplicables:** RN-013, RN-014

---

### Fuente de Datos (`rates.data_sources`)

**Qué es:** Catálogo normalizado de las fuentes externas que proveen cotizaciones. Cada tipo de cambio referencia su fuente. Permite saber exactamente de dónde viene cada dato.

**Fuentes activas:** `fawazahmed0`, `imf_sdmx`, `bcb_bolivia`, `frankfurter`, `manual` (ajuste manual por operador), `interpolated` (calculado por el sistema).

---

### Datos BCB Bolivia (`validation.bcb_cotizaciones`)

**Qué es:** Los datos oficiales del Banco Central de Bolivia, descargados de su portal como Excel diario (lunes a viernes). Se almacenan en una base de datos separada (`smartrates_db (schema validation)`) para validación cruzada.

**Propósito:** validar que los datos de fawazahmed0 para BOB coincidan con los datos oficiales del BCB. Si la diferencia supera el umbral configurado, se genera una alerta.

**Reglas de negocio aplicables:** RN-015, RN-016

---

## Reglas de negocio

**RN-001:** El código de moneda siempre es exactamente 3 letras mayúsculas según ISO 4217. No se aceptan variaciones.

**RN-002:** El número de decimales de una moneda determina la precisión de todos los cálculos. JPY y CLP tienen 0 decimales (no se muestran centavos). KWD tiene 3 decimales. El sistema respeta `currency_minor_unit` en todos los formateos.

**RN-003:** NULL está prohibido en todos los campos. Valores por defecto obligatorios: NUMERIC → `0.00000000`, VARCHAR → `''`, fecha abierta → `'9999-12-31'`, timestamp sin valor → `'1900-01-01 00:00:00'`, BOOLEAN → `false`.

**RN-004:** La base de todos los pares almacenados es USD. No se almacenan pares BOB/EUR directamente — se calculan via cross-rate en consulta. Excepción: datos BCB que tienen compra/venta BOB/USD directos.

**RN-005:** Para fechas sin dato (fines de semana, feriados), se almacena el último dato disponible con `type_code='carried_forward'`. El sistema nunca deja una fecha sin registro una vez que el backfill activo alcanza esa fecha.

**RN-006:** Los datos interpolados entre dos fechas conocidas se almacenan con `type_code='interpolated'` y `quality='medium'`. Los datos oficial daily son `quality='high'`. Los datos históricos pre-2022 son `quality='low'`.

**RN-007:** La política `use_black_rate='national'` es irreversible intradiariamente — una vez confirmado el ajuste del día con esta política, todas las transacciones nacionales del día ya registradas se validan con ese rate.

**RN-008:** La política `use_black_rate='national'` **obliga** a que todas las transacciones internacionales se realicen en `international_currency`. No es opcional ni configurable por transacción — es una regla del período de vigencia.

**RN-009:** Solo puede existir una configuración de política activa por empresa+moneda en un momento dado. `WITHOUT OVERLAPS` en PostgreSQL 18 lo enforza a nivel de base de datos — no es solo validación de aplicación.

**RN-010:** El ajuste diario debe ser confirmado por un usuario con rol `smartrates.operator` o `smartrates.admin`. No puede ser autoconfirmado por el sistema.

**RN-011:** Si el operador no confirma el ajuste del día antes de las 12:00, el sistema envía una notificación de recordatorio. Si no se confirma antes de las 17:00, el sistema aplica el ajuste del día anterior como valor provisional y genera una alerta de nivel WARN.

**RN-012:** El ajuste diario confirmado es inmutable. Si el operador se equivocó, debe ingresar una nota de corrección en el campo `notes` y el sistema registra la corrección con timestamp — pero el valor confirmado original se preserva en el audit trail.

**RN-013:** La moneda doméstica y la moneda puente no pueden ser la misma.

**RN-014:** El cambio de moneda puente tiene efecto solo desde la fecha de inicio de la nueva configuración — no afecta retroactivamente los cálculos históricos.

**RN-015:** La diferencia tolerada entre el dato BCB y el dato de fawazahmed0 para BOB/USD es configurable. El umbral por defecto es 0.05 BOB (≈ 0.7% al tipo de cambio actual). Si la diferencia supera el umbral, se genera una alerta de nivel WARN en el sistema.

**RN-016:** Los datos del BCB se almacenan siempre — incluso cuando coinciden exactamente con fawazahmed0. El propósito es tener evidencia documental del dato oficial para cumplimiento normativo.

**RN-017:** El backfill nunca se ejecuta durante el horario de operación (06:00-22:00). Solo corre en la ventana 01:00-04:00. Si se interrumpe, retoma desde el último punto registrado en `sync.backfill_progress` — no empieza de cero.

**RN-018:** Cada fuente externa tiene su propio circuit breaker. Un fallo de fawazahmed0 no afecta la disponibilidad de los datos ya almacenados ni activa el circuit breaker de las otras fuentes.

**RN-019:** El sistema nunca llama a APIs externas directamente en producción SBOS — solo via cajas biedata. En modo standalone, los jobs de Laravel Horizon pueden llamar directamente. El modo se controla con `SYNC_MODE=internal|biedata`.

**RN-020:** Los tipos de cambio de fines de semana para monedas que sí operan en fines de semana (fawazahmed0 cubre 7 días) se almacenan con `type_code='official_daily'`. Solo los fines de semana del BCB (que no publica) se marcan como `carried_forward`.

**RN-021:** La función `catalog.RATE()` usa `STRICT` — si cualquier parámetro es NULL, retorna NULL. El caller debe garantizar que no pasa NULLs.

**RN-022:** `catalog.RATE()` acepta fechas en dos formatos: `DD/MM/YYYY` (formato boliviano) y `YYYY-MM-DD` (ISO 8601). Cualquier otro formato genera un error de PostgreSQL.

**RN-023:** Si no existe dato para la fecha exacta solicitada en `catalog.RATE()`, la función busca el dato más reciente disponible hacia atrás, con un máximo de 7 días. Si no hay dato en 7 días, retorna NULL.

**RN-024:** La cinta Ticker (Web Component `<smartrates-ticker>`) no requiere autenticación para acceso público. Para acceder al ajuste del día y datos de empresa, requiere `api-key`.

**RN-025:** Todos los datos del sistema son de **solo lectura para aplicaciones cliente**. Únicamente el proceso de sincronización (SyncJob / biedata) puede escribir en `rates.exchange_rates`. Los operadores pueden escribir en `company.*`. Ninguna aplicación externa puede modificar cotizaciones históricas.

---
_SKULL · SBOS · SmartRates · 002-DOMINIO · v1.0 · 2026-05-23_

---

## Actualizaciones post-simulación (2026-05-23)

### Clarificación fundamental del modelo

**SmartRates = servicio global + ajustes por empresa**

Los datos de mercado son **globales** (todos ven lo mismo):
- Cotización oficial BCB
- Valor referencial BCB (VRD/VRV)
- USDT/BOB del mercado P2P
- USDC/BOB del mercado P2P
- Todas las cotizaciones ISO de 200+ monedas

Los **ajustes** son **por empresa** (cada empresa configura los suyos):
- Ajuste del black rate (cuánto suma al oficial para sus transacciones nacionales)
- Ajuste sobre USDT (por defecto = 0, usa el P2P directo)
- Ajuste sobre USDC (por defecto = 0, usa el P2P directo)
- Política `use_black_rate` (disabled / reference / national)

### Códigos de stablecoins (convención X-prefix ISO 4217)

ISO 4217 reserva el prefijo **X** para activos no nacionales. SmartRates adopta esta convención:

| Stablecoin | Código interno SmartRates | Ticker de mercado | Nota |
|---|---|---|---|
| Tether USD | `XUT` | USDT | X-prefix + UT de Unstated Tether |
| USD Coin | `XUC` | USDC | X-prefix + UC de Unstated Coin |

Estos **NO son códigos ISO 4217 oficiales** — son convención interna del sistema, siguiendo el espíritu del X-prefix. Se documenta explícitamente en el catálogo de monedas.

### Nuevas reglas de negocio

**RN-026:** Ajuste provisional por timeout — `confirmed_by = UUID_SYSTEM` ('00000000-0000-7777-0000-000000000000'). El operador puede sobrescribir hasta las 20:00.

**RN-027:** Cotizaciones globales son inmutables para las empresas — ninguna empresa puede modificar datos de mercado.

**RN-028:** Ajustes por empresa nunca modifican cotizaciones globales.

**RN-029:** USDT (XUT) y USDC (XUC) siguen la misma política `use_black_rate` que USD cuando la política es `national`.

**RN-030:** Ticker sin auth = datos públicos globales. Con auth + `show-company-rate="true"` = agrega black rate de empresa en dorado.

