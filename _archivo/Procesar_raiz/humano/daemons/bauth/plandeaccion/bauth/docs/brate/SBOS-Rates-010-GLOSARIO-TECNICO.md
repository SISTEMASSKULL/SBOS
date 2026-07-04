# Glosario Técnico — SBOS SmartRates

---

## Términos del stack técnico

| Término | Definición en el contexto de SmartRates |
|---|---|
| **uuidv7** | Versión 7 de UUID, nativa en PostgreSQL 18. Contiene el timestamp de creación en los primeros bits — los registros se insertan en orden cronológico en el B-tree, eliminando fragmentación. Todos los UUIDs del sistema son v7. |
| **VIRTUAL column (PG18)** | Columna calculada que no ocupa espacio en disco. Se evalúa en cada query que la referencia. Ejemplos: `rate_mid = (rate_buy + rate_sell) / 2`. Garantiza consistencia matemática sin triggers. |
| **WITHOUT OVERLAPS (PG18)** | Constraint de PG18 que garantiza que rangos temporales no se solapen en una restricción UNIQUE o PRIMARY KEY. Ejemplo: no puede haber dos configuraciones de política activas para la misma empresa+moneda en el mismo período. El motor lo enforza a nivel de índice. |
| **PARTITION BY RANGE** | Particionamiento nativo de PostgreSQL. Las tablas de alta escritura (exchange_rates, sync_log, audit_log) están particionadas por año o trimestre. Permite purgar datos antiguos con `DROP PARTITION` en milisegundos sin afectar la tabla principal. |
| **BRIN index** | Block Range INdex — índice para columnas donde los valores están correlacionados con su posición física en el archivo (como fechas en series de tiempo). 100× más pequeño que un B-tree equivalente. Ideal para `rate_date` en exchange_rates. |
| **io_uring** | Interfaz de I/O asíncrono de Linux activada en PG18. Hasta 3× de mejora en lecturas secuenciales. Configurable en `postgresql.conf` con `io_uring = on`. |
| **SPI (Server Programming Interface)** | Mecanismo de PostgreSQL para que funciones C ejecuten SQL directamente en la memoria compartida del servidor, sin abrir una nueva conexión TCP. La función `catalog.RATE()` usa SPI para consultar `rates.exchange_rates` en nanosegundos. |
| **IMMUTABLE (PostgreSQL)** | Declaración que indica que una función siempre retorna el mismo resultado para los mismos parámetros de entrada. Activa **constant folding**: si 30.000 filas de un query usan el mismo par fecha+monedas, PG ejecuta la función una sola vez y reutiliza el resultado. |
| **STRICT (PostgreSQL)** | Declaración que indica que si cualquier argumento de entrada es NULL, la función retorna NULL inmediatamente sin ejecutarse. Evita la necesidad de validar NULLs dentro del código C. |
| **PARALLEL SAFE (PostgreSQL)** | Declaración que indica que la función puede ejecutarse en workers paralelos de PostgreSQL. Con esta declaración, PG18 puede paralelizar queries que llaman a `catalog.RATE()`. |
| **COST 1 (PostgreSQL)** | Estimación de costo para el planeador de queries. `COST 1` indica que la función es prácticamente gratis de ejecutar — el planeador la tratará como una constante en la optimización. |
| **pg_notify** | Función de PostgreSQL para enviar notificaciones asíncronas a través del canal de pub/sub nativo del servidor. En SmartRates, un trigger en `rates.exchange_rates` llama `pg_notify('rates_channel', payload)` al insertar una cotización nueva, lo que notifica inmediatamente al stream SSE del servidor Laravel. |
| **SSE (Server-Sent Events)** | Protocolo estándar HTTP/EventSource para streaming unidireccional servidor → cliente. El browser abre una conexión HTTP que el servidor mantiene abierta y va enviando datos. Reconexión automática. No requiere configuración especial en proxies. Usado por el Ticker. |
| **Web Component** | Estándar W3C para crear elementos HTML personalizados (`customElements.define('smartrates-ticker', ...)`). Funciona nativamente en cualquier browser moderno sin dependencias de frameworks. El Ticker `<smartrates-ticker>` es un Web Component. |
| **EventSource** | API JavaScript del browser para consumir SSE. Se instancia con `new EventSource(url)` y reconecta automáticamente con backoff exponencial. El Ticker usa EventSource para recibir actualizaciones de cotizaciones. |
| **Laravel Reverb** | Servidor WebSocket de primera parte incluido en Laravel 12. Implementa el protocolo de canales de Pusher. Permite broadcast de eventos a múltiples clientes conectados. SmartRatesUI Flutter lo usa para eventos bidireccionales. |
| **Laravel Horizon** | Dashboard y gestor de colas para Laravel. Supervisa todos los jobs en Redis y proporciona visibilidad del throughput, tiempos de ejecución y fallos. Todos los sync jobs y el backfill corren en Horizon. |
| **BLoC pattern** | Business Logic Component — patrón de gestión de estado en Flutter. Separa la lógica de negocio de la UI. Cada feature de SmartRatesUI tiene su propio BLoC: `RatesBloc`, `ConvertBloc`, `AdjustmentBloc`, etc. |
| **Impeller** | Motor de renderizado de Flutter (desde Flutter 3.x, reemplaza a Skia). Precompila los shaders al instalar la app → animaciones fluidas desde el primer frame. Mejora notablemente la experiencia en el dashboard con gráficos animados. |
| **Dio** | Cliente HTTP para Dart/Flutter. Se usa en SmartRatesUI para las llamadas a SmartRatesAPI. Incluye interceptores para agregar el JWT automáticamente a cada request. |
| **Hive** | Base de datos NoSQL local para Flutter. Se usa para cache offline en SmartRatesUI — el último dato de cotizaciones disponible se guarda localmente para que la app funcione sin conexión con el dato de la última consulta. |
| **ctx_id** | Context ID del ecosistema SBOS. Identificador único de la sesión que propaga Kong como header `X-SBOS-CtxId` en cada request. SmartRates lo captura y lo incluye en todos sus logs para permitir la trazabilidad cruzada en el audit trail del SBOS. En modo standalone, este campo es siempre `''`. |
| **BitMask** | Máscara de bits de 64 bits incluida en el JWT de Keycloak para codificar permisos específicos. Los bits 20-22 de la AppsMask controlan los permisos en SmartRates. Más eficiente que una lista de roles para verificaciones de alta frecuencia. |
| **Kong** | API Gateway del ecosistema SBOS. Valida los JWTs de Keycloak, inyecta los headers SBOS, aplica rate limiting y enruta el tráfico a los servicios. En modo standalone no existe — SmartRatesAPI recibe el tráfico directamente. |
| **bKernel** | Daemon del SBOS que escucha el WAL de PostgreSQL y registra todos los cambios en `audit_events` con el `ctx_id` de la sesión que los originó. SmartRates no necesita hacer nada especial — bKernel lo captura transparentemente. |
| **biedata** | Daemon del SBOS para integración de datos externos. En modo `SYNC_MODE=biedata`, biedata ejecuta las cajas de sincronización (fawazahmed0, FMI, BCB) en lugar de los jobs de Laravel Horizon. |
| **Caja biedata** | Unidad atómica de integración en biedata. Define VALIDATE → AUTHENTICATE → EXTRACT → TRANSFORM → LOAD → AUDIT para una fuente específica. SmartRates requiere 4 cajas: `fawazahmed0_daily`, `imf_sdmx_monthly`, `bcb_bolivia_daily`, `frankfurter_fallback`. |
| **Vault** | Gestor de secrets (HashiCorp Vault) del ecosistema SBOS. En producción, ninguna credencial vive en `.env` — todo se lee de Vault. SmartRates declara sus paths en `manifest.yml`. |
| **Patroni** | Gestor de alta disponibilidad para PostgreSQL. El cluster SBOS usa Patroni HA con failover automático. SmartRatesAPI se conecta al endpoint virtual que Patroni mantiene apuntando siempre al primario activo. |
| **Linkerd** | Service mesh del ecosistema SBOS. Inyecta sidecars que agregan mTLS automáticamente entre todos los servicios. SmartRatesAPI no necesita configurar TLS explícitamente entre servicios — Linkerd lo gestiona transparentemente. |
| **NetworkPolicy Calico** | Política de red del cluster K8s del SBOS. Default deny-all. SmartRatesAPI solo puede recibir tráfico de Kong y bKernel, y solo puede conectarse a PostgreSQL y Redis. Ningún otro servicio puede comunicarse con SmartRates sin una política explícita. |
| **SDMX 3.0** | Statistical Data and Metadata eXchange versión 3.0. Estándar del FMI para publicar datos estadísticos financieros. La API del FMI usa SDMX 3.0 con dimensiones como KEY = `BOL.XDC_USD.PA_RT.M` que codifican país, indicador, tipo de transformación y frecuencia. |
| **XDC_USD** | Indicador FMI SDMX para "unidades de moneda local por USD" (Exchange Rate, Domestic Currency per US Dollar). Es el indicador correcto para obtener tipos de cambio históricos del FMI. |
| **PA_RT** | Tipo de transformación FMI: Period Average Rate (promedio del período). Alternativa: `EOP_RT` (End of Period Rate = cotización al último día del período). SmartRates usa `PA_RT` para datos mensuales históricos. |
| **ReadFilter (Excel)** | Técnica de Maatwebsite/Laravel-Excel para leer solo las filas necesarias de un Excel sin cargarlo completo en RAM. Esencial para el Excel del BCB que tiene muchas columnas y filas de cabecera. |
| **Backoff exponencial** | Estrategia de reintentos donde el tiempo de espera entre intentos se duplica: 1s → 2s → 4s → 8s → 16s. Evita saturar una fuente que ya está bajo presión. SmartRates lo implementa en todos los reintentos a fuentes externas. |
| **Constant folding** | Optimización del planeador de PostgreSQL que reconoce que una función IMMUTABLE con los mismos argumentos siempre retorna el mismo resultado. Si 30.000 filas usan `catalog.RATE('2026-03-18', 'BOB', 'USD', precio, 2)`, PG ejecuta la función una sola vez y usa el resultado para todas las filas. |
| **OpenAPI 3.0** | Especificación estándar para documentación de APIs REST. L5-Swagger genera automáticamente la documentación OpenAPI 3.0 a partir de anotaciones PHP en los controladores de SmartRates. Disponible en `/api/documentation`. |
| **RFC 9457** | RFC que define el formato estándar para respuestas de error en APIs HTTP: `{"error_code", "error_type", "message", "documentation_url"}`. SmartRates sigue este formato en todos sus errores. |
| **ETag (RFC 7232)** | Header HTTP para validación de cache. SmartRates incluye ETag en responses de cotizaciones — el cliente puede hacer requests condicionales con `If-None-Match` para evitar re-descargar datos que no cambiaron. |
| **PITR** | Point-In-Time Recovery — capacidad de restaurar la base de datos a cualquier momento específico del pasado usando los archivos WAL archivados. El cluster Patroni del SBOS soporta PITR hasta el minuto. |
| **Impeller (Flutter)** | Motor de rendering de Flutter que precompila shaders en build time. Garantiza animaciones a 60fps/120fps desde el primer frame, eliminando el jank inicial de Skia. |

---
_SKULL · SBOS · SmartRates · 010-GLOSARIO-TECNICO · v1.0 · 2026-05-23_
