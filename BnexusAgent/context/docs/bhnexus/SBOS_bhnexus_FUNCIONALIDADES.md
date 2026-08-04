# FUNCIONALIDADES — SBOS Nexus Host (bhnexus)

**Identidad:** `spiffe://sbos.skull/daemon/bhnexus`
**Puertos:** 9444 (WebSocket mTLS), 9445 (Metrcas Prometheus)
**Base de datos:** PostgreSQL 17+ (bhnexus_db: dispositivos, agentes, policy cache)
**Cache in-memory:** AuthCache con sync.Map, TTL 30s, LRU 100,000 entradas (~15MB RAM)
**Propagacion W3C:** `traceparent` + `baggage` en headers de toda request REST y frames WebSocket
**Protocolo de identificacion:** SPIFFE/SPIRE para mTLS + certificados de nodo

---

## Seccion 1: Tabla de Capacidades

| ID | Capacidad | Tipo | Protocolo | Endpoint/Stream | Consumidores |
|---|---|---|---|---|---|
| F-001 | Gestion de Conexiones WebSocket mTLS | Interna/Servidor | WSS (gorilla/websocket) | `wss://bhnexus:9444/ws` | banexus agentes (10000+ conexiones) |
| F-002 | Procesamiento de auth_requests | API/Interna | Frame WebSocket + Unix socket | Frame tipo `auth_request` + Unix socket a bauth | banexus agentes |
| F-003 | Hardware Bridge (6 Drivers) | Interna/Traductor | OSDP / MQTT / ONVIF / Wiegand / USB HID / HTTP | Drivers de hardware interno | CredentialEvent normalizado |
| F-004 | Auth Cache | Interna/In-Memory | sync.Map + LRU | Cache interna (TTL 30s, 100K entradas) | F-002 (auth_request cache lookup) |
| F-005 | Envio de policy_updates | API/Evento | Frame WebSocket `policy_update` | Frame tipo `policy_update` a agentes afectados | banexus agentes |
| F-006 | Monitoreo de Salud de Dispositivos | Interna/Schedule | Health check periodico | Check cada `health.check_interval_seconds` | bhnexus interno |
| F-007 | Metrcas y Alertas | API/Exposicion | HTTP + Prometheus + Wazuh | `GET /metrics` puerto 9445 + eventos Wazuh | Prometheus, Wazuh, Grafana |

---

## Seccion 2: Especificacion de Cada Capacidad

### F-001: Gestion de Conexiones WebSocket mTLS

- **Proposito:** Mantener hasta 10,000+ conexiones WebSocket simultaneas con agentes banexus, con handshake mutuamente autenticado y deteccion de desconexion en menos de 30s.
- **Trigger:** Inicio de conexion WSS desde banexus a `wss://bhnexus:9444/ws`.
- **Protocolo:** WSS (WebSocket Secure) con gorilla/websocket. mTLS obligatorio con certificados firmados por CA SBOS interna.
- **Handshake:**
  1. banexus inicia conexion WSS a bhnexus:9444
  2. Headers requeridos: `X-Node-ID`, `X-Agent-Version`, `X-Agent-Cert-Fingerprint`
  3. bhnexus verifica: certificado mTLS valido (CA SBOS) + Node-ID existe en bhnexus_db.devices + version compatible (semver match)
  4. OK -> conexion establecida, agente agregado a Agents[] con estado `connected`
  5. FAIL -> 403 Forbidden + log de auditoria + evento Wazuh (`NEXUS-001`)
- **Estados del agente:**
  | Estado | Descripcion | Accion del host |
  |---|---|---|
  | `connected` | Conexion activa y funcional | Enrutar requests normalmente |
  | `disconnected` | Desconexion detectada por timeout | Cache efimero TTL 300s, cola de eventos offline (max 1000) |
  | `suspended` | Host suspendido por policy (bauth) | No enviar request, mantener conexion activa |
  | `terminated` | Agente dado de baja | Eliminar de agents map, notificar admin, evento Wazuh |
- **Control de conexion:**
  - Ping/Pong cada 15s (configurable)
  - Write deadline: 10s
  - Read deadline: 30s
  - Max message size: 1MB
- **Criterios de Aceptacion:**
  - DADO un banexus con certificado mTLS valido, Node-ID existente y version compatible CUANDO inicia conexion WSS ENTONCES el handshake completo en menos de 500ms y el agente queda en estado `connected`.
  - DADO un banexus con certificado mTLS invalido CUANDO intenta conectar ENTONCES recibe 403 Forbidden, la conexion se rechaza, y se genera evento Wazuh `NEXUS-001`.
  - DADO un agente en estado `connected` CUANDO no responde a 2 pings consecutivos (30s sin respuesta) ENTONCES el host marca el agente como `disconnected`, activa cache efimero TTL 300s, y encola eventos offline.
  - DADO que bhnexus recibe un frame de un agente en estado `disconnected` CUANDO el agente se reconecta ENTONCES se retoma el estado `connected` y se entrega la cola de eventos offline acumulada.
  - DADO que la capacidad de 10,000+ conexiones simultaneas se alcanza CUANDO un nuevo agente intenta conectar ENTONCES el host aplica backpressure (rechaza con 503) y registra alerta de capacidad.
- **Manejo de Errores:** Write deadline 10s: si un frame no se puede enviar en 10s, la conexion se cierra. Read deadline 30s: si no se recibe nada en 30s, la conexion se cierra. Si el buffer de escritura del agente se llena (backpressure), el host cierra la conexion con codigo 1009 (Message Too Big).
- **Propagacion de Contexto:** Cada conexion tiene un `trace_id` generado al establecer el handshake. El `traceparent` se transmite como primer frame del handshake. El `baggage` transporta `bos_tenant`, `bos_node_id`.
- **Idempotencia:** Si un agente se reconecta con el mismo Node-ID, la conexion anterior (si existe) se cierra y se reemplaza por la nueva. Las operaciones en curso de la conexion anterior se cancelan.
- **Dependencias:** bhnexus_db (dispositivos registrados), CA SBOS interna (certificados mTLS), Wazuh (eventos de seguridad).

### F-002: Procesamiento de auth_requests

- **Proposito:** Recibir solicitudes de autenticacion de agentes banexus (credencial biometrica, tarjeta RFID, comando shell) y resolverlas contra cache o bauth.
- **Trigger:** Frame WebSocket de tipo `auth_request` recibido desde banexus.
- **Protocolo:** Interno. Primero cache in-memory (F-004), luego Unix socket a bauth si cache miss.
- **Flujo completo:**
  1. Recibe frame `auth_request` con node_id, input_type, payload
  2. Normaliza el evento de hardware a CredentialEvent (via F-003 si es necesario)
  3. Consulta Auth Cache por (node_id + input_type + credential_hash)
  4. Cache HIT -> respuesta inmediata (sub-5ms)
  5. Cache MISS -> consulta bauth via Unix socket `/run/bauth/bauth.sock`
  6. Almacena resultado en cache con TTL 30s
  7. Envia `auth_response` al agente con BitMask + actuator_commands
- **Frame de request:**
  ```json
  {
    "type": "auth_request",
    "node_id": "Ventas-01",
    "input_type": "rfid_card",
    "payload": {"credential": "050012ABCDEF", "reader_id": "R01"},
    "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
  }
  ```
- **Frame de response:**
  ```json
  {
    "type": "auth_response",
    "request_id": "req-1717200000-a1b2",
    "result": "GRANTED",
    "bitmask": {"high": 0xFFFFFFFF, "low": 0xFFFFFFFF},
    "actuator_commands": [
      {"actuator_id": "door_01", "command": "OPEN", "duration_ms": 5000}
    ],
    "cache_used": true,
    "evaluation_time_ms": 2.3
  }
  ```
- **Criterios de Aceptacion:**
  - DADO una credencial RFID previamente cacheadas CUANDO se recibe un `auth_request` con el mismo (node_id + input_type + credential_hash) ENTONCES se retorna `auth_response` desde cache en menos de 5ms.
  - DADO una credencial NUNCA antes vista (cache miss) CUANDO se recibe el `auth_request` ENTONCES se consulta bauth via Unix socket y se retorna respuesta en menos de 15ms total (incluyendo ida/vuelta a bauth).
  - DADO un auth_request con resultado DENIED CUANDO se envia la respuesta al agente ENTONCES el frame incluye `result: "DENIED"` con actuator_commands vacio.
  - DADO que bauth no responde en 10s CUANDO se consulta via Unix socket ENTONCES se retorna DENIED al agente (fail-secure) y se registra alerta.
- **Manejo de Errores:** Timeout Unix socket: 10s. Si bauth no responde, fail-secure -> DENIED. Si el frame del agente esta malformado, responder con `result: "ERROR"` y descripcion.
- **Propagacion de Contexto:** El `traceparent` del frame WebSocket se pasa a bauth via header en la llamada Unix socket. El `baggage` se extrae y se pasa como metadata.
- **Idempotencia:** El mismo (node_id + input_type + credential_hash + timestamp_segment) dentro de una ventana de 5s retorna el mismo resultado (cache). Esto evita procesamiento duplicado si el agente re-envia por timeout.
- **Dependencias:** bauth (F-004/F-005 via Unix socket), Auth Cache (F-004), banexus agente (remitente del frame).

### F-003: Hardware Bridge (6 Drivers)

- **Proposito:** Traducir eventos de 6 protocolos fisicos heterogeneos a un unico formato CredentialEvent normalizado para procesamiento uniforme.
- **Trigger:** Evento de hardware entrante desde un dispositivo fisico.
- **Protocolo:** Drivers internos por tipo de dispositivo.
- **Drivers soportados:**
  | Driver | Protocolo | Medio fisico | Dispositivos tipicos | Latencia tipica |
  |---|---|---|---|---|
  | OSDP | OSDP v2.2 | RS-485 serial | Lectores biometricos, teclados | < 5ms |
  | MQTT | MQTT 3.1.1 | TCP/1883 | Sensores IoT, cerraduras IP | < 10ms |
  | ONVIF | ONVIF Profile C | IP/ethernet | Camaras con control de acceso | < 20ms |
  | Wiegand | 26/34/37 bits | Cableado directo GPIO | Lector de tarjetas legacy | < 2ms |
  | USB HID | USB HID protocol | USB directo | QR, NFC, barcode | < 1ms |
  | HTTP | REST API | IP/ethernet | Dispositivos propietarios | < 50ms |
- **CredentialEvent normalizado:**
  ```go
  type CredentialEvent struct {
      NodeID        string    `json:"node_id"`
      InputType     string    `json:"input_type"`     // "rfid_card", "fingerprint", "face", "qr", "shell", "pin"
      Credential    string    `json:"credential"`      // Datos en crudo del lector
      ReaderID      string    `json:"reader_id,omitempty"`
      DeviceType    string    `json:"device_type"`     // "osdp", "mqtt", "onvif", "wiegand", "usb_hid", "http"
      DeviceHealth  string    `json:"device_health"`   // "ok", "degraded", "failed"
      Timestamp     time.Time `json:"timestamp"`
  }
  ```
- **Criterios de Aceptacion:**
  - DADO un evento de lector OSDP sobre RS-485 CUANDO el driver OSDP recibe el mensaje ENTONCES lo traduce a CredentialEvent en menos de 2ms y lo pasa al procesador de auth_requests (F-002).
  - DADO un lector Wiegand con cableado defectuoso CUANDO el driver detecta timeout de pulso ENTONCES genera un evento `device_error` con codigo de dispositivo y tipo de fallo, sin interrumpir el procesamiento de otros lectores.
  - DADO un dispositivo USB HID CUANDO se conecta ENTONCES el driver lo detecta via udev, abre el dispositivo, y comienza a capturar eventos en menos de 100ms.
- **Manejo de Errores:** Timeout por driver: configurable (default OSDP 500ms, MQTT 2s, HTTP 5s). Fallo de hardware se reporta como evento de error con codigo de dispositivo. Si un driver falla repetidamente, se desactiva automaticamente por 60s y se notifica.
- **Propagacion de Contexto:** El trace_id del evento se genera en el driver. Cada evento de hardware lleva su propio traceparent que se propaga a F-002.
- **Idempotencia:** Un mismo evento de hardware (identificado por reader_id + timestamp + credential_hash) dentro de una ventana de 100ms se descarta como bounce.
- **Dependencias:** Hardware fisico (lectores, camaras, sensores), GPIO, RS-485, USB.

### F-004: Auth Cache

- **Proposito:** Cache in-memory de resultados de autenticacion para respuesta sub-5ms sin consultar a bauth en cada request.
- **Protocolo:** Interno. sync.Map de Go + LRU cuando supera capacidad.
- **Estructura:**
  ```go
  type AuthCache struct {
      store sync.Map             // concurrente, sin locks explicitos
      ttl   time.Duration        // 30s configurable
      cap   int                  // 100,000 entradas (~15MB RAM)
  }
  ```
- **Clave de cache:** `{node_id}:{input_type}:{credential_hash_sha256[:16]}`
- **Valor:** `{result, bitmask_high, bitmask_low, actuator_commands, cached_at}`
- **Politica de eviccion:**
  - LRU cuando se supera `cap` (100,000 entradas)
  - TTL expirado (30s) -> refresh on next access
  - No hay invalidacion global (cada entrada expira individualmente)
- **Criterios de Aceptacion:**
  - DADO una entrada en cache con TTL vigente CUANDO se consulta la misma clave ENTONCES se retorna el resultado almacenado en menos de 1ms (sync.Map read).
  - DADO una entrada en cache con TTL expirado CUANDO se consulta ENTONCES se trata como cache miss y se consulta a bauth (F-002 paso 5).
  - DADO que la cache supera 100,000 entradas CUANDO se agrega una nueva ENTONCES la entrada LRU se evicciona sin bloquear lecturas concurrentes.
  - DADO que se busca una entrada que no existe CUANDO se consulta ENTONCES retorna miss en menos de 1ms.
- **Manejo de Errores:** Si la cache se corrompe (caso extremo), se reinicia con store nuevo. No hay persistencia de cache entre reinicios de bhnexus.
- **Propagacion de Contexto:** No aplica (cache interna).
- **Idempotencia:** La cache es puramente una optimizacion. No almacena decisiones de autorizacion que no puedan re-obtenerse de bauth.
- **Dependencias:** bauth (fuente de verdad para cache miss).

### F-005: Envio de policy_updates

- **Proposito:** Notificar a agentes banexus afectados cuando cambia una politica (RolTemplate, UserTemplate, suspension de tenant) para invalidar cache local.
- **Trigger:** Evento `authz.policy_updated` desde bauth via bKernel WAL, o evento `tenant.suspended` desde bos.
- **Protocolo:** Frame WebSocket `policy_update` enviado a agentes afectados via conexion persistente.
- **Frame de policy_update:**
  ```json
  {
    "type": "policy_update",
    "reason": "roltemplate_changed",
    "affected_users": ["uuid-1", "uuid-2", "uuid-3"],
    "action": "invalidate_cache",
    "timestamp": "2026-05-27T10:30:00.123Z",
    "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
  }
  ```
- **Criterios de Aceptacion:**
  - DADO un cambio en RolTemplate que afecta a 3 usuarios CUANDO bauth notifica el cambio ENTONCES bhnexus envia un frame `policy_update` a TODOS los agentes que tienen al menos uno de los usuarios afectados en menos de 500ms desde la notificacion.
  - DADO un agente en estado `disconnected` CUANDO hay un policy_update pendiente ENTONCES el mensaje se encola (max 50 eventos offline) y se entrega cuando el agente se reconecta.
  - DADO un agente en estado `suspended` CUANDO se recibe un policy_update ENTONCES el mensaje se descarta (el agente suspendido no necesita actualizacion).
- **Manejo de Errores:** Si un agente no confirma recepcion del policy_update en 5s, reintentar 2 veces. Si persiste, registrar en log.
- **Propagacion de Contexto:** El `traceparent` del evento origen se propaga al frame WebSocket. Cada policy_update es un span hijo del evento que lo origino.
- **Idempotencia:** Cada policy_update tiene un `update_id` unico. Si un agente recibe el mismo update_id dos veces, lo ignora.
- **Dependencias:** bauth (via bKernel WAL), bos (via bKernel WAL), banexus agentes.

### F-006: Monitoreo de Salud de Dispositivos

- **Proposito:** Health checks periodicos contra cada dispositivo registrado segun su `health.check_interval_seconds`, con deteccion de fallos persistentes.
- **Trigger:** Schedule interno cada `health.check_interval_seconds` por dispositivo (default: 60s).
- **Protocolo:** Interno. Ejecuta check especifico del driver (OSDP ping, MQTT ping, HTTP health endpoint).
- **Estados de salud:**
  | Estado | Descripcion | Accion |
  |---|---|---|
  | `ok` | Funcionando normalmente | Continuar monitoreo normal |
  | `degraded` | 3 health checks fallaron consecutivamente | Notificar, reducir polling |
  | `failed` | 5 health checks fallaron consecutivamente | Evento `NEXUS-004`, notificar admin |
  | `recovered` | Dispositivo responde nuevamente | Reanudar operacion normal, notificar |
- **Criterios de Aceptacion:**
  - DADO un dispositivo que falla 5 health checks consecutivos CUANDO se detecta ENTONCES se genera evento `NEXUS-004` (Error de hardware persistente) y se notifica al administrador.
  - DADO un dispositivo en estado `failed` CUANDO el siguiente health check es exitoso ENTONCES el dispositivo transiciona a `recovered` y reanuda operacion normal automaticamente.
  - DADO un dispositivo configurado con `health.check_interval_seconds: 60` CUANDO pasa el tiempo ENTONCES el health check se ejecuta exactamente cada 60 segundos.
- **Manejo de Errores:** Si el health check timeout (default 5s), se cuenta como fallo. Si el driver del dispositivo no esta disponible, se ignora el check (el dispositivo se marca como `unknown`).
- **Propagacion de Contexto:** Cada health check genera un trace_id propio con span por dispositivo.
- **Idempotencia:** Los health checks son puros (solo lectura). No tienen efectos secundarios.
- **Dependencias:** bhnexus_db (configuracion de dispositivos), Drivers de hardware (F-003).

### F-007: Metrcas y Alertas

- **Proposito:** Exponer 9 metricas Prometheus en puerto 9445 y generar 8 tipos de eventos Wazuh para monitoreo y auditoria.
- **Trigger:** Exposicion continua via endpoint HTTP. Eventos Wazuh generados sincronamente al ocurrir la condicion.
- **Protocolo:** HTTP GET `/metrics` (formato OpenMetrics) para Prometheus. Eventos Wazuh via syslog/CEF.
- **Metricas Prometheus expuestas:**
  | Metrica | Tipo | Descripcion |
  |---|---|---|
  | `bhnexus_agents_connected` | Gauge | Numero de agentes conectados actualmente |
  | `bhnexus_auth_requests_total` | Counter | Total de auth_requests procesados |
  | `bhnexus_auth_cache_hits_total` | Counter | Total de cache hits en auth_cache |
  | `bhnexus_auth_cache_misses_total` | Counter | Total de cache misses |
  | `bhnexus_auth_latency_ms` | Histogram | Latencia de auth_requests (cache hit y miss) |
  | `bhnexus_ws_errors_total` | Counter | Total de errores WebSocket |
  | `bhnexus_policy_updates_sent_total` | Counter | Total de policy_updates enviados |
  | `bhnexus_device_health` | Gauge | Estado de salud por dispositivo (0=ok, 1=degraded, 2=failed) |
  | `bhnexus_model_level` | Gauge | Nivel de fallback actual (solo bcompass, no aplica a bhnexus) |
- **Eventos Wazuh generados:**
  | Evento | Condicion |
  |---|---|
  | `NEXUS-001` | Conexion rechazada por certificado invalido |
  | `NEXUS-002` | auth_request DENIED |
  | `NEXUS-003` | Conexion de agente establecida/terminada |
  | `NEXUS-004` | Error de hardware persistente (5 fallos) |
  | `NEXUS-005` | agente desconectado inesperadamente |
  | `NEXUS-006` | policy_update enviado |
  | `NEXUS-007` | Capacidad de conexion cercana al limite (>9000) |
  | `NEXUS-008` | Cache de autenticacion corrupta (reset) |
- **Criterios de Aceptacion:**
  - DADO una request a `GET /metrics` en puerto 9445 CUANDO se recibe ENTONCES se retorna texto plano en formato OpenMetrics con todas las 9 metricas, incluyendo labels de dispositivo cuando corresponde.
  - DADO que se rechaza una conexion por certificado invalido CUANDO ocurre ENTONCES se genera evento Wazuh `NEXUS-001` en menos de 1 segundo.
  - DADO un auth_request con resultado DENIED CUANDO se procesa ENTONCES se incrementa el counter `bhnexus_auth_requests_total` con label `result="denied"`.
- **Manejo de Errores:** Si Prometheus scrape timeout (5s), las metricas se retornan parciales. Si Wazuh no esta disponible, los eventos se encolan en buffer local (max 1000) y se reintentan cada 30s.
- **Propagacion de Contexto:** Cada metrica lleva labels: `tenant`, `realm`, `node_id` (cuando aplica).
- **Idempotencia:** Las metricas Counter son acumulativas (idempotentes por definicion en Prometheus). Los eventos Wazuh tienen UUID para dedup en el SIEM.
- **Dependencias:** Prometheus (scraping), Wazuh (agente syslog), Grafana (dashboard).

---

## Seccion 3: Matriz Funcionalidad ↔ Daemon

| Funcionalidad | Consumida por | Protocolo de acceso |
|---|---|---|
| F-001 (WebSocket mTLS) | banexus agentes (conexion persistente) | WSS `wss://bhnexus:9444/ws` |
| F-002 (auth_requests) | banexus agentes (frames WebSocket) | Frame `auth_request` / `auth_response` |
| F-003 (Hardware Bridge) | Interno (traduce eventos a CredentialEvent) | Drivers internos |
| F-004 (Auth Cache) | F-002 (cache lookup interno) | sync.Map interno |
| F-005 (policy_updates) | banexus agentes (frames WebSocket) | Frame `policy_update` |
| F-006 (Monitoreo Salud) | bhnexus_db, Admin Core UI | Interno + Notificaciones |
| F-007 (Metrcas y Alertas) | Prometheus, Wazuh, Grafana | HTTP /metrics + Syslog CEF |

**Servicios que bhnexus consume:**
- bauth -> Unix socket `/run/bauth/bauth.sock` (F-002 cache miss, F-005 policy notifications)
- bKernel -> WAL (eventos de politica, suspension de tenants)
- bos -> WAL (registro inicial de dispositivos)

**Redis Streams que bhnexus consume (via bKernel WAL):**
- `bkernel:stream:bauth.policy_updates` -> cambios de politica
- eventos de bos -> suspension/alta de tenants

---

## Seccion 4: SLAs por Funcionalidad

| Funcionalidad | Latencia P99 | Throughput | Disponibilidad |
|---|---|---|---|
| F-001 (WebSocket mTLS) | 500ms (handshake) | 10,000+ conexiones simultaneas | 99.99% |
| F-002 (auth_requests) | 5ms (cache hit) / 15ms (bauth miss) | 1000 req/s | 99.99% |
| F-003 (Hardware Bridge) | 2ms (normalizacion) | Matching dispositivos fisicos | 99.99% |
| F-004 (Auth Cache) | 1ms (lookup) | Matching F-002 throughput | 100% (in-memory) |
| F-005 (policy_updates) | 500ms (envio a todos los afectados) | 100 eventos/s | 99.95% |
| F-006 (Monitoreo Salud) | 5s (deteccion de 5 fallos consecutivos) | 1000 dispositivos | 99.99% |
| F-007 (Metrcas y Alertas) | 100ms (endpoint /metrics) | 100 scrapes/s | 99.99% |

---

*Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS2-4, V5-SS1-2, V7-SS6 · Estandares: W3C Trace Context, SPIFFE, OSDP v2.2, ONVIF Profile C, OWASP, ISO 27001, OpenMetrics*
