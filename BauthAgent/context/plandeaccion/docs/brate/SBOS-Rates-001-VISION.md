# Visión del Proyecto — SBOS SmartRates
## Exchange Rate Management System

---

## El problema que resuelve

### Problema 1 — La empresa boliviana opera en un contexto cambiario complejo y sin herramientas

Bolivia opera con un tipo de cambio oficial del BCB históricamente fijo en 6.86/6.96 BOB/USD, pero desde 2023 enfrenta una transición hacia flexibilidad cambiaria. Desde diciembre de 2025, el BCB publica un "valor referencial del dólar" basado en operaciones reales del sistema financiero, creando efectivamente **dos cotizaciones distintas**: la oficial y la referencial de mercado. A esto se suman los mercados alternativos que las empresas usan para operaciones cotidianas.

Una empresa boliviana que importa, exporta o tiene proveedores internacionales necesita saber en tiempo real: el tipo de cambio oficial del BCB, el valor referencial del mercado, y cuál aplica a cada tipo de transacción según su política interna. Hoy lo resuelve con planillas Excel, actualizaciones manuales y cálculos propensos a error.

### Problema 2 — Los ERP y sistemas de facturación no tienen una fuente de verdad de tipos de cambio

Tryton (ERP del ecosistema SBOS), Saleor (e-commerce), SmartTax (facturación electrónica) y cualquier sistema que opere con múltiples monedas necesitan convertir precios. Hoy cada sistema tiene su propia lógica de conversión, sus propias fuentes, sus propias tablas de históricos — o peor, hardcodean valores. Cuando el tipo de cambio cambia, hay que actualizar en múltiples lugares.

### Problema 3 — Los reportes masivos multimoneda son lentos o directamente inviables

Un reporte JasperReports de inventario con 50.000 productos que necesita precios en USD, EUR y BRL por fila implica 150.000 llamadas de conversión. Con cualquier solución basada en HTTP REST eso tarda entre 25 minutos y 4 horas. El resultado: los reportes multimoneda simplemente no se hacen, o se hacen con datos de días anteriores.

### Problema 4 — No existe una solución específica para Bolivia y LATAM

Las herramientas globales (XE.com, Open Exchange Rates, Fixer.io, Bloomberg Terminal) no tienen datos oficiales del BCB, no manejan el concepto de mercado alternativo con ajuste manual auditable, no tienen historial de Bolivia desde 1990, y no ofrecen una función de conversión embebible en la base de datos. Son herramientas para traders globales, no para PYMEs latinoamericanas.

---

## La solución propuesta

SmartRates es el **sistema de gestión de tipos de cambio** del ecosistema SBOS. Es la fuente de verdad centralizada para cotizaciones de 200+ monedas, con cobertura especial de Bolivia y LATAM, que provee:

**Para las aplicaciones del ecosistema:** una función nativa `catalog.RATE()` compilada en C que corre directamente en PostgreSQL. Convierte monedas en nanosegundos, sin red, sin latencia. 50.000 conversiones en 50ms. Los reportes multimoneda pasan de inviables a instantáneos.

**Para los operadores de la empresa:** una interfaz Flutter multiPlataforma (web, móvil, desktop) donde ven las cotizaciones del día, confirman el ajuste del mercado alternativo, monitorizan la sincronización de fuentes y configuran la política cambiaria de la empresa.

**Para cualquier aplicación externa:** una API REST enterprise con 30+ endpoints, documentación Swagger interactiva, WebSockets para tiempo real, y un Ticker (cinta informativa) embebible en 2 líneas en cualquier sistema.

**Para Bolivia específicamente:** datos del BCB oficiales (compra/venta/referencial), historial desde 1990, manejo auditado del mercado alternativo con triple política (deshabilitado / referencia / operativo), y validación cruzada BCB vs fuentes internacionales.

---

## El éxito se ve así

**Éxito para el operador financiero:** llega por la mañana, abre SmartRates, ve en 5 segundos el tipo de cambio del día, confirma el ajuste si es necesario, y el sistema ya está propagado a todos los sistemas del ecosistema.

**Éxito para el sistema SBOS:** Tryton calcula facturas en USD usando `catalog.RATE()` directamente en SQL, sin llamadas HTTP, sin dependencias externas. El reporte de ventas mensual multimoneda se genera en segundos.

**Éxito para el ecosistema completo:** cualquier aplicación nueva del SBOS que necesite tipos de cambio simplemente instala la extensión `smartrates_rate` en su base de datos y llama `catalog.RATE()`. Un minuto de integración, no una semana.

---

## Alcance — qué SÍ hace SmartRates

- Descarga y almacena cotizaciones diarias de 200+ monedas desde fawazahmed0 (fuente primaria), FMI SDMX API (histórico oficial), BCB Bolivia (oficial local), y Frankfurter/BCE (respaldo)
- Provee conversión instantánea con motor cross-rate via moneda puente configurable (USD por defecto, configurable a CNY o EUR)
- Gestiona el mercado alternativo (Bolivia: paralelo, Argentina: blue, etc.) con ajuste manual diario, auditoría de confirmaciones y triple política por empresa
- Mantiene historial de Bolivia (BOB) desde 1990 y de 179 países FMI desde 1924
- Rellena automáticamente fines de semana y feriados con `carried_forward` sin silencio de datos
- Ejecuta backfill histórico silencioso en ventana nocturna (01:00-04:00) a máximo 100 requests/noche por fuente
- Expone API REST enterprise (30+ endpoints), WebSocket broadcast en tiempo real, SSE para el Ticker
- Provee Ticker (cinta informativa) como Web Component embebible en cualquier plataforma con 2 líneas
- Provee función `catalog.RATE()` como extensión C nativa de PostgreSQL 18 — disponible en todo el cluster
- Provee Playground ("Explorador SmartRates") para exploración visual de la API sin conocimiento técnico
- Funciona en modo standalone (desarrollo, cliente sin SBOS) y en modo acoplado al SBOS (producción)
- Valida cruzadamente datos BCB vs fuentes internacionales y alerta cuando la diferencia supera umbral

## Alcance — qué NO hace SmartRates

- **No procesa pagos ni transacciones financieras** — solo provee los tipos de cambio que otros sistemas usan
- **No implementa contabilidad multicurrency** — eso es Tryton
- **No calcula impuestos sobre diferencias cambiarias** — eso es SmartTax
- **No gestiona usuarios** — en producción SBOS eso es Keycloak/bAuth; en standalone usa Sanctum con tabla local
- **No almacena criptomonedas** — solo monedas fiat ISO 4217
- **No conecta a bolsas de valores ni datos de trading** — no es Bloomberg Terminal
- **No genera facturas ni documentos tributarios** — es un proveedor de datos de precios
- **No tiene información de tasas de interés ni instrumentos financieros** — solo tipos de cambio
- **No expone datos BCB crudos como servicio público** — son para validación interna

---

## Restricciones no negociables

- **Presupuesto de APIs externas:** todas las fuentes primarias son gratuitas; la única con key es la FMI SDMX API (gratuita, ya registrada: `c2800287220f4bc18e147ad8dba321ab`)
- **Stack:** Laravel 13 + PostgreSQL 18 + Redis + Flutter — no negociable, es el stack del ecosistema SKULL
- **Licencias:** 100% OSI-approved — Laravel MIT, PostgreSQL License, Redis BSD, Flutter BSD, Keycloak Apache 2.0
- **NULL prohibido:** ningún campo de ninguna tabla puede ser NULL — siempre valor explícito
- **Modo dual:** el sistema DEBE funcionar sin SBOS (desarrollo, standalone) y con SBOS (producción) — un solo cambio de variable de entorno, sin modificar código
- **Backfill silencioso:** máximo 100 requests por noche por fuente — nunca en horas de operación (01:00-04:00)
- **Función RATE():** implementada como extensión C `.so` — no PL/pgSQL, no HTTP, no procedimiento almacenado regular
- **Retención histórica:** 10 años mínimo de datos de cotizaciones — requisito de cumplimiento normativo boliviano
- **Fecha de entrega v1.0:** Septiembre 2026 (alineado con GA del SBOS)

---

## Contexto de mercado (investigación 2026)

El mercado de APIs de tipos de cambio en 2026 está dominado por herramientas para developers globales (Open Exchange Rates, Fixer.io, CurrencyLayer, ExchangeRate-API). Ninguna combina:
- Datos oficiales de banco central latinoamericano (BCB Bolivia)
- Gestión de mercado alternativo/paralelo con política configurable por empresa
- Función embebida en base de datos para cálculos masivos
- Historial específico de Bolivia desde 1990
- Ticker embebible universal como Web Component

SmartRates no compite con estas herramientas — las complementa para el contexto boliviano y latinoamericano, y las supera en el contexto del ecosistema SBOS gracias a la integración nativa via `catalog.RATE()`.

La transición del BCB hacia un tipo de cambio más flexible (diciembre 2025) convierte a SmartRates en una herramienta **más crítica**, no menos: ahora hay dos referencias oficiales (fijo histórico + valor referencial de mercado) y las empresas necesitan gestionar cuál aplica a cada tipo de operación.

---
_SKULL · SBOS · SmartRates · 001-VISION · v1.0 · 2026-05-23_
