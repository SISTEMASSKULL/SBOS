# INTEGRACIONES — SBOS Nexus Host (bhnexus)

## Seccion 1: Tabla de Integraciones

| Sistema/Daemon | Tipo | Protocolo | Endpoint/Stream | Formato | Timeout | Retries | Direccion |
|---|---|---|---|---|---|---|---|
| SBOS Nexus Agent (banexus) | Bidireccional | WebSocket mTLS | `wss://<host>:9444/ws` | JSON frames (TLV) | Write: 10s, Read: 30s | Reconexion backoff (1s, 5s, 15s, 30s, 60s) | banexus <-> bhnexus |
| SBOS Auth Enforce (bauth) | Salida | Unix Socket | `/run/bos/bauth.sock` | JSON TLV (4B len + payload) | 1000ms | 0 (bhnexus reintenta del lado cliente) | bhnexus -> bauth |
| SBOS IAM Installer (bos) | Entrada | Filesystem YAML | `/etc/bos/blibs/bhnexus/devices/` | YAML v1.2 (device fichas) | N/A (lectura local) | 0 | bos -> filesystem -> bhnexus |
| SBOS IAM Installer (bos) | Entrada | Filesystem YAML | `/etc/bos/blibs/bhnexus/rights/` | YAML v1.2 (rights fichas) | N/A (lectura local) | 0 | bos -> filesystem -> bhnexus |
| SBOS Data Kernel (bkernel) | Salida | PostgreSQL WAL | Logical Replication Slot `bkernel_audit` | WAL pgoutput eventos | N/A (escritura async) | 0 | bhnexus -> PostgreSQL WAL |
| SBOS Data RAG (bsearch) | Salida | HTTP REST | `POST http://bsearch:9220/v1/index/event` | JSON | 5s | 2 (1s, 3s) | bhnexus -> bsearch |
| Dispositivos OSDP | Salida | RS-485 serial | `/dev/ttyOSDP{0-15}` (puerto serie) | OSDP v2.2 (IEC 60839-11-5) | 500ms (comando) | 2 (100ms, 300ms) | bhnexus -> OSDP devices |
| Broker MQTT | Bidireccional | MQTT v3.1.1/v5 | `tcp://localhost:1883` | MQTT pub/sub | 5s | 2 (1s, 3s) | bhnexus <-> MQTT |
| Camaras ONVIF | Salida | ONVIF Profile C | IP/Ethernet (configurable por device) | SOAP/XML + RTSP | 10s | 2 (2s, 5s) | bhnexus -> ONVIF devices |
| Lectores Wiegand | Entrada | GPIO | GPIO pins (configurable via device.yml) | Wiegand 26/34/37 bits | N/A (interrupcion HW) | 0 | Wiegand -> bhnexus |
| Dispositivos USB HID | Entrada | USB HID (libusb) | `/dev/bus/usb/` (raw USB) | HID reports | N/A (evento) | 0 | USB HID -> bhnexus (via banexus) |
| Dispositivos HTTP | Salida | HTTP REST | Configurable por device.yml | JSON | 10s | 2 (1s, 5s) | bhnexus -> HTTP device |
| Prometheus | Salida | HTTP | `0.0.0.0:9445/metrics` | Text (OpenMetrics) | N/A | 0 | bhnexus -> Prometheus scraper |
| Wazuh | Salida | Syslog/UDP | `localhost:514` | Syslog RFC 5424 | N/A | 0 | bhnexus -> Wazuh |
| PostgreSQL (bhnexus_db) | Bidireccional | SQL (pgx) | `postgres://bhnexus@localhost:5432/bhnexus_db` | SQL | 10s | 2 (1s, 5s) | bhnexus <-> bhnexus_db |

## Seccion 2: Contratos de Integracion

### INT-BHNEXUS-001: WebSocket con banexus (agentes edge)

**Endpoint:** `wss://<host>:9444/ws`
**Protocolo:** WebSocket sobre TLS mutuo (mTLS). Certificados firmados por CA SBOS interna.
**Timeouts:** Write deadline 10s, Read deadline 30s, Ping/Pong cada 15s.

**Estados de conexion:**
1. CONNECTING: banexus inicia handshake WSS con mTLS
2. AUTHENTICATING: bhnexus verifica SPIFFE ID del certificado cliente contra device.yml
3. CONNECTED: frames normales (auth_request, heartbeat, etc.)
4. RECONNECTING: bhnexus mantiene sesion 60s tras desconexion, permite reconexion con mismo node_id
5. CLOSED: expirado plazo de reconexion, cierra sesion

**Frame type: auth_request (banexus -> bhnexus):**
```json
{
  "type": "auth_request",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "payload": "sbos://auth/0123456789ABCDEF",
  "hmac": "sha256-hex-of-payload-with-shared-key",
  "timestamp": "2026-05-27T10:00:00.000Z",
  "ctx_id": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
}
```

**Frame type: auth_response (bhnexus -> banexus):**
```json
{
  "type": "auth_response",
  "request_id": "uuid-que-coincide-con-auth_request",
  "status": "granted",
  "bitmask_bundle": {
    "physical": "0x0000000003E60053",
    "logical": "0x0000000000000303",
    "financial": "0x0000000000506011"
  },
  "actuator_commands": [
    {"target": "RELAY_01", "action": "OPEN", "duration_ms": 3000},
    {"target": "DRAWER_01", "action": "OPEN", "duration_ms": 5000}
  ],
  "traceparent": "00-0af7651916cd43dd8448eb211c80319c-9e8d7c6b5a4f3e2d-01"
}
```

**Frame type: policy_update (bhnexus -> banexus, push):**
```json
{
  "type": "policy_update",
  "reason": "roltemplate_changed",
  "affected_users": ["uuid-cajero"],
  "action": "invalidate_cache",
  "timestamp": "2026-05-27T10:00:00.000Z"
}
```

**Frame type: heartbeat (banexus -> bhnexus, cada 15s):**
```json
{
  "type": "heartbeat",
  "node_id": "Ventas-01",
  "uptime_seconds": 86400,
  "active_sessions": 3,
  "reader_status": "online",
  "queue_depth": 0
}
```

### INT-BHNEXUS-002: Consulta BitMask a bauth (Unix Socket)

**Socket:** `/run/bos/bauth.sock` (owner: bauth, group: bauth, permisos: 0660)
**Protocolo:** Frame TLV: `[4 bytes uint32 BE: payload length][N bytes JSON UTF-8]`
**Timeout:** 1000ms. Max conexiones simultaneas: 100.

**Request (bhnexus -> bauth):**
```json
{
  "type": "bitmask_request",
  "user_id": "uuid-cajero",
  "node_id": "Ventas-01",
  "timestamp": "2026-05-27T10:00:00.000Z",
  "ctx_id": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
}
```

**Response (bauth -> bhnexus):**
```json
{
  "type": "bitmask_response",
  "status": "granted",
  "bitmask_bundle": {
    "physical": "0x0000000003E60053",
    "logical": "0x0000000000000303",
    "financial": "0x0000000000506011"
  },
  "evaluation_time_ms": 4,
  "actuator_hints": {
    "allowed_relays": ["RELAY_01", "RELAY_02"],
    "max_open_duration_ms": 3000
  }
}
```

**Flujo completo de resolucion de BitMask (~15ms):**
```
T+0.000  banexus envia auth_request
T+0.003  bhnexus recibe, identifica nodo, busca device.yml
T+0.005  Auth cache hit? SI -> T+0.006 | NO -> consulta bauth Unix socket
         Cache: sync.Map, TTL 30s, max 100,000 entradas (~15MB RAM)
T+0.009  bauth evalua UserTemplate + RolTemplate
T+0.011  BitMask resultante
T+0.012  bhnexus almacena en cache (TTL 30s)
T+0.013  bhnexus construye auth_response con actuator_commands
T+0.015  banexus recibe, ejecuta en paralelo: RELAY_01, DRAWER_01
```

### INT-BHNEXUS-003: Drivers de Hardware (HAL)

La HAL expone 6 drivers que implementan la interfaz `DeviceDriver`:

```go
type DeviceDriver interface {
    Init(config DeviceConfig) error
    ReadEvent(ctx context.Context) (CredentialEvent, error)
    WriteCommand(cmd ActuatorCommand) error
    Health() HealthStatus
    Close() error
}
```

| Driver | Protocolo | Conexion | Dispositivos tipicos |
|---|---|---|---|
| `driver_osdp.go` | OSDP v2.2 (IEC 60839-11-5) | RS-485 serial `/dev/ttyOSDP{0-15}` | Cerraduras electricas, torniquetes, portones |
| `driver_wiegand.go` | Wiegand 26/34/37 bits | GPIO (pines configurados en device.yml) | Lectores de proximidad legacy |
| `driver_mqtt.go` | MQTT v3.1.1/v5 | TCP `localhost:1883` | Sensores IoT, alarmas, actuadores |
| `driver_onvif.go` | ONVIF Profile C/A | IP/Ethernet | Camaras IP con control de acceso |
| `driver_usbhid.go` | USB HID raw | USB `/dev/bus/usb/` | Lectores QR, NFC, codigo de barras |
| `driver_http.go` | REST API propietaria | HTTP configurable | Hardware propietario no estandar |

**Formato de device.yml:**
```yaml
# /etc/bos/blibs/bhnexus/devices/Ventas-01.yml
device:
  id: "DEV-AC-001"
  type: "osdp_reader"
  driver: "osdp"
  connection:
    serial_port: "/dev/ttyOSDP0"
    baud_rate: 9600
    data_bits: 8
    stop_bits: 1
    parity: "none"
  osdp:
    address: 1
    secure_channel: true
    scbk_key: "base64-key"  # derivado de bos tenant secret
  actuators:
    - relay: "RELAY_01"
      default_duration_ms: 3000
    - relay: "RELAY_02"
      default_duration_ms: 5000
```

### INT-BHNEXUS-004: Indexacion de Eventos Auth en bSearch

**Endpoint:** `POST http://bsearch:9220/v1/index/event`
**Ver contrato completo en:** INT-BSEARCH-004

Se indexan los siguientes tipos de eventos de autenticacion:
- `auth_granted`: autenticacion exitosa
- `auth_denied`: autenticacion rechazada (credencial invalida, bitmask insuficiente)
- `auth_timeout`: timeout en lectura de credencial
- `device_error`: error de hardware (lector desconectado, tamper detectado)
- `policy_update`: cambio de politicas aplicado

Cada evento se envia a bsearch asincronicamente (no bloquea el flujo de auth).

## Seccion 3: Matriz de Dependencias

| Dependencia | Criticidad | Sin esto... |
|---|---|---|
| banexus | OBLIGATORIO | Sin agentes edge. bhnexus no tiene proposito como broker |
| bauth (Unix socket) | OBLIGATORIO | Sin evaluacion BitMask. Auth cache eventualmente vacio |
| Filesystem device fichas | OBLIGATORIO | Sin configuracion de dispositivos. No sabe que hardware gestionar |
| PostgreSQL (bhnexus_db) | OBLIGATORIO | Sin persistencia de eventos auth, configuracion de nodos |
| bsearch | OPCIONAL | Sin indexacion de eventos auth. Auditoria solo via Wazuh/logs |
| OSDP devices | OPCIONAL | Sin control de acceso fisico. Resto de funcionalidad intacta |
| MQTT broker | OPCIONAL | Sin sensores IoT. Drivers OSDP/ONVIF operan independientemente |
| Camaras ONVIF | OPCIONAL | Sin video. Drivers de acceso fisico operan sin camaras |
| Wazuh | OPCIONAL | Sin alertas de seguridad centralizadas. Logs locales disponibles |
| Prometheus | OPCIONAL | Sin metricas |

## Seccion 4: Propagacion de Contexto

bhnexus recibe ctx_id de:
1. **WebSocket** (banexus): campo `ctx_id` en el frame `auth_request`
2. **Interno**: genera trace_id para eventos de hardware (OSDP, MQTT, ONVIF) que no llevan contexto

bhnexus propaga el ctx_id a:
- **bauth** (Unix socket): campo `ctx_id` en frame JSON
- **bsearch** (indexacion): header `X-Ctx-Id` en `POST /v1/index/event`
- **PostgreSQL WAL** (bkernel): como campo `ctx_id` en la escritura de audit_events
- **Wazuh**: como campo `bos_ctx_id` en el mensaje Syslog
- **Mensajes MQTT**: como campo `ctx_id` en el payload de eventos publicados
- **bhnexus_db**: columna `ctx_id` en tabla `auth_events`
- **Logs**: campo `trace_id`

**Formato:** W3C Trace Context (`00-{trace_id}-{span_id}-{flags}`).
Para eventos de hardware sin ctx_id (OSDP, Wiegand), bhnexus genera un trace_id
basado en UUID v7 con span_id del driver que genero el evento.

**Cache de autorizacion y trazabilidad:**
La cache `sync.Map` de bhnexus asocia `(user_id, node_id) -> (bitmask_bundle, ctx_id, timestamp)`.
Cuando un auth_response se entrega a banexus, el ctx_id queda vinculado al cache entry
para trazabilidad completa de decisiones de autorizacion aceleradas por cache.

---

*Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS2-3, V5-SS1-2, V7-SS1, V7-SS6-7. Investigation SS10 — OSDP v2.2, SS1 — W3C Trace Context.*
