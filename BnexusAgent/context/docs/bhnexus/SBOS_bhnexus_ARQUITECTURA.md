# ARQUITECTURA — SBOS Nexus Host (bhnexus)

## Stack Tecnologico

| Componente | Tecnologia | Justificacion |
|---|---|---|
| Lenguaje | Rust 1.85+ MUSL | Seguridad de memoria, zero-cost abstractions, binario estatico ~5MB |
| Async runtime | tokio | Alta concurrencia WebSocket, 10,000+ tareas con minimo overhead |
| WebSocket | tokio-tungstenite | WebSocket async nativo sobre tokio |
| Cache | DashMap | Concurrent HashMap sin locks explicitos, 100,000 entradas |
| TLS | rustls + tokio-rustls | mTLS obligatorio, sin OpenSSL, memory-safe |
| Serial | serialport-rs | Comunicacion RS-485 con dispositivos OSDP |
| Metricas | prometheus (rust) | 9 metricas en puerto 9445 |
| Auditoria | Wazuh | 8 reglas de alerta para eventos de seguridad |

## Arquitectura Interna

```
bhnexus (Rust binary MUSL, ~5MB estatico)
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| WebSocket Manager (tokio-tungstenite)                    |
| +-- tokio tasks (hasta 10,000 conexiones concurrentes)   |
| +-- Write deadline: 10s, Read deadline: 30s              |
| +-- Ping/Pong cada 15s (desconexion < 30s)              |
| +-- Reconexion: backoff 1s->5s->15s->30s->60s           |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| HAL (Hardware Abstraction Layer)                          |
| +-- OSDP: SIA OSDP v2.2 sobre RS-485 serial             |
| +-- MQTT: Mosquitto bridge (pub/sub sobre TCP/1883)     |
| +-- ONVIF: ONVIF Profile C (control de acceso)          |
| +-- Wiegand: Decodificacion de 26/34/37 bits            |
| +-- HTTP: REST API para dispositivos no estandar        |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| Request Router         |  Auth Cache                      |
| identifica nodo + tipo | sync.Map, TTL 30s               |
| solicitud              | 100,000 entradas (~15MB RAM)    |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| bauth Client (Unix socket)  |  Response Dispatcher       |
| consulta BitMask (cache miss)| BitMask + actuator_commands|
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
```

## HAL (Hardware Abstraction Layer)

```go
type DeviceDriver interface {
    Init(config DeviceConfig) error
    ReadEvent(ctx context.Context) (CredentialEvent, error)
    WriteCommand(cmd ActuatorCommand) error
    Health() HealthStatus
    Close() error
}

Implementaciones:
  driver_osdp.go   -> OSDP v2.2 sobre RS-485
  driver_wiegand.go -> Wiegand 26/34/37 bits GPIO
  driver_mqtt.go    -> MQTT v3.1.1/v5
  driver_onvif.go   -> ONVIF Profile C/A
  driver_usbhid.go  -> USB HID
  driver_http.go    -> REST API propietario
```

## Flujo Completo de Autenticacion (~15ms)

```
T+0.000  Usuario presenta QR al lector USB
T+0.001  banexus intercepta datos bus USB
T+0.002  banexus firma payload HMAC -> WebSocket a bhnexus
T+0.005  bhnexus recibe, identifica nodo
T+0.006  Auth cache hit? SI -> T+0.007 | NO -> consulta bauth Unix socket
T+0.010  bauth evalua: UserTemplate + RolTemplate
T+0.012  BitMask resultante
T+0.013  bhnexus almacena cache (TTL 30s)
T+0.014  bhnexus envia: BitMask + actuator_commands[RELAY_01:OPEN]
T+0.015  banexus ejecuta en paralelo: SHELL_UNLOCK, DRAWER_OPEN, RELAY_01
TOTAL: ~15ms (objetivo < 50ms)
```

## Configuracion (bhnexus.toml)

```toml
[server]
websocket_port = 9444
tls_cert = "/etc/bos/tls/bhnexus.crt"
tls_key = "/etc/bos/tls/bhnexus.key"
ca_cert = "/etc/bos/tls/ca.crt"

[auth]
bauth_socket = "/run/bos/bauth.sock"
cache_ttl_seconds = 30
cache_capacity = 100000

[hardware]
devices_path = "/etc/bos/blibs/bhnexus/devices/"
osdp_enabled = true
mqtt_broker = "localhost:1883"
```

---

## Seccion 2: Decisiones de Arquitectura (ADRs)

### ADR-001: HAL (Hardware Abstraction Layer) para Drivers de Dispositivos
**Contexto:** bhnexus debe soportar 6 protocolos de hardware diferentes (OSDP, Wiegand, MQTT, ONVIF, USB HID, HTTP) y posiblemente mas en el futuro. Sin una abstraccion, el nucleo del daemon se acopla a cada protocolo.
**Decision:** Disenar una interfaz `DeviceDriver` en Go con metodos `Init`, `ReadEvent`, `WriteCommand`, `Health`, `Close`. Cada protocolo implementa esta interfaz. El Request Router identifica el tipo de dispositivo y delega al driver correspondiente. Agregar un nuevo protocolo = implementar la interfaz, sin tocar el nucleo.
**Consecuencias:** Desacoplamiento total entre logica de negocio y protocolos de hardware. Los drivers se testean independientemente con mocks. Agregar soporte para un nuevo lector biometrico requiere solo un nuevo archivo `driver_biometric.go`.

### ADR-002: WebSocket como Transporte Principal (no REST)
**Contexto:** banexus necesita comunicacion bidireccional en tiempo real con bhnexus para eventos de credenciales y comandos de actuadores. REST requeria polling constante (latencia alta) o conexiones HTTP largas (complejidad).
**Decision:** WebSocket (gorilla/websocket) como transporte unico entre bhnexus y banexus. El handshake inicial usa mTLS. Ping/Pong cada 15s con deteccion de desconexion en < 30s. Reconexion con backoff exponencial: 1s, 5s, 15s, 30s, 60s.
**Consecuencias:** Comunicacion full-duplex. Sin overhead de HTTP headers por mensaje. Reconexion automatica desde banexus. bhnexus puede enviar comandos a banexus sin esperar request (push de actuadores).

### ADR-003: OSDP v2.2 como Estandar para Control de Acceso Fisico
**Contexto:** El estandar Wiegand (unidireccional, texto plano) aun se usa en dispositivos legacy, pero no cumple requisitos de seguridad modernos. bhnexus necesita un estandar moderno para nuevos despliegues.
**Decision:** OSDP (IEC 60839-11-5) v2.2 como estandar principal para nuevos lectores, con soporte legacy para Wiegand. OSDP ofrece: bidireccionalidad, AES-128 encryption, multidrop RS-485 (hasta 32 dispositivos), monitoreo de tamper. Wiegand se mantiene para compatibilidad con instalaciones existentes.
**Consecuencias:** Nuevas instalaciones usan OSDP. Las existentes migran cuando reemplacen lectores. bhnexus implementa OSDP via serial RS-485 (serialport-rs). La HAL abstrae la diferencia entre OSDP y Wiegand.

### ADR-004: Rust para WebSocket I/O-Bound con Alta Concurrencia
**Contexto:** bhnexus debe manejar hasta 10,000 conexiones WebSocket concurrentes desde multiples agentes banexus. La carga es I/O-bound (esperar eventos de hardware y red).
**Decision:** Rust 1.85+ con tokio + tokio-tungstenite. Las tokio tasks son eficientes para miles de conexiones simultaneas (~few KB por task). DashMap para cache concurrente lock-free. rustls para mTLS sin dependencia de OpenSSL (memory-safe). Consistente con el stack de bAuth (Rust).
**Consecuencias:** 10,000 conexiones con huella de RAM minima (~5-8MB total binario). Sin GC — latencias deterministas. Seguridad de memoria garantizada por el compilador. Mismo stack que bAuth facilita compartir tipos y contratos.

### ADR-005: Auth Cache con TTL para Autenticacion Sub-50ms
**Contexto:** El flujo de autenticacion debe completarse en < 50ms total (objetivo 15ms). Consultar a bauth via Unix socket toma ~5ms, pero si cada request fisico requiere esa consulta, la latencia acumulada es alta para multiples accesos simultaneos (ej: hora pico).
**Decision:** Cache de autorizacion en bhnexus con DashMap (concurrente, lock-free reads). TTL de 30s para entradas de BitMask. Capacidad maxima de 100,000 entradas (~8MB RAM). Si hay cache hit, la autenticacion se resuelve en < 1ms sin consultar a bauth. El cache se invalida al reconectar banexus o al recibir evento de cambio de permisos desde bauth.
**Consecuencias:** 99% de requests fisicos se resuelven en cache hit (~1ms). El TTL de 30s garantiza que cambios de permisos se reflejan en maximo 30s. Eventos de invalidation desde bauth reducen la ventana a < 1s. banexus puede operar offline con cache local hasta 4h.

---

## Seccion 3: Patrones de Arquitectura Aplicados

| Patron | Como lo implementa | Referencia |
|---|---|---|
| **HAL (Hardware Abstraction Layer)** | Interfaz `DeviceDriver` con 6 implementaciones: OSDP, Wiegand, MQTT, ONVIF, USB HID, HTTP. Nucleo desacoplado del protocolo | OSDP IEC 60839-11-5, Investigation §10 |
| **WebSocket Full-Duplex** | Transporte unico entre bhnexus y banexus. Push de comandos, eventos en tiempo real. Reconexion con backoff exponencial | RFC 6455 |
| **Auth Cache con TTL** | sync.Map con TTL 30s, 100,000 entradas. Cache hit resuelve en < 1ms sin consultar bauth | — |
| **W3C Trace Context** | bhnexus inyecta traceparent en eventos de auditoria. El ctx_id se propaga desde banexus como baggage | W3C Trace Context, Investigation §1 |
| **SPIFFE Workload Identity** | SPIFFE ID: `spiffe://sbos.skull/daemon/bhnexus`. SVID para mTLS con banexus | SPIFFE/SPIRE, Investigation §2 |
| **mTLS obligatorio** | Todas las conexiones WebSocket usan mTLS. banexus presenta SVID, bhnexus valida contra CA de SPIRE | Investigation §2 |
| **OSDP v2.2** | Estandar principal para control de acceso fisico. AES-128, bidireccional, multidrop RS-485, monitoreo de tamper | IEC 60839-11-5, Investigation §10 |

---

## Seccion 4: Modelo de Concurrencia

bhnexus maneja miles de conexiones WebSocket concurrentes con el siguiente modelo:

- **WebSocket Manager (principal):** Una goroutine por conexion (hasta 10,000). Cada goroutine maneja el loop read/write del WebSocket. Lectura con `SetReadDeadline` de 30s. Escritura con `SetWriteDeadline` de 10s. Ping/Pong handler automatico cada 15s.
- **Request Router:** Canal tokio-style (channel Go) para enrutar requests desde los WebSocket al handler correspondiente. Buffer de 10,000 requests.
- **Auth Cache sync.Map:** Lock-free reads concurrentes desde todas las goroutines. Escrituras sincronizadas (mutex interno de sync.Map).
- **bauth Client (Unix socket):** Pool de 10 conexiones al socket de bauth. Timeout por request: 1000ms. Max 100 requests concurrentes a bauth.

Backpressure: Si la cola interna de requests supera 5,000 items, nuevos mensajes WebSocket se rechazan con close code 1013 (Try Again Later). El cliente (banexus) debe reconectar con backoff.

Para drivers de hardware: cada driver ejecuta en su propia goroutine con context.Context para cancelacion. Los drivers seriales (OSDP) usan `SetReadDeadline` de 100ms para no bloquear el event loop.

---

## Seccion 5: Observabilidad

### Logs Estructurados (zerolog JSON)

```json
{"level":"info","time":"2026-05-27T10:00:00Z","module":"AUTH","event":"auth_request","node_id":"Ventas-01","credential_type":"QR","auth_result":"allowed","cache_hit":true,"duration_us":850,"trace_id":"00-abc123-def456-01"}
```

### Metricas Prometheus (puerto 9445)

| Metrica | Tipo | Descripcion |
|---|---|---|
| `bhnexus_auth_requests_total{result}` | Counter | Requests de autenticacion por resultado |
| `bhnexus_auth_duration_microseconds` | Histogram | Duracion de autenticacion en microsegundos |
| `bhnexus_auth_cache_hit_ratio` | Gauge | Ratio de aciertos de cache de auth |
| `bhnexus_websocket_connections_active` | Gauge | Conexiones WebSocket activas |
| `bhnexus_websocket_errors_total{type}` | Counter | Errores WebSocket por tipo (timeout, disconnect, protocol) |
| `bhnexus_hardware_events_total{driver}` | Counter | Eventos de hardware por driver |
| `bhnexus_actuator_commands_total{actuator}` | Counter | Comandos de actuador ejecutados |

### RED Metrics

- **Rate:** `bhnexus_auth_requests_total` por segundo
- **Errors:** `bhnexus_websocket_errors_total` / total conexiones
- **Duration:** `bhnexus_auth_duration_microseconds` p50, p95, p99

### Auditoria Wazuh

Eventos de riesgo elevados a Wazuh (8 reglas):
- Auth reject consecutivo (5 en 60s)
- Tamper detection en lector OSDP
- Desconexion de banexus no programada
- Cache corruption detectada

---

## Seccion 6: SPIFFE Workload Identity

| Atributo | Valor |
|---|---|
| SPIFFE ID | `spiffe://sbos.skull/daemon/bhnexus` |
| Metodo de obtencion | SPIRE Agent via Unix socket `/run/spire/agent.sock` |
| Renovacion | SVID con TTL 1h, renovacion cada 30min |
| Uso de SVID | mTLS con banexus (WebSocket), autenticacion con bauth (Unix socket) |

### mTLS con banexus

1. banexus inicia conexion WebSocket presentando SVID X.509
2. bhnexus valida cadena de certificados contra CA de SPIRE
3. Extrae SPIFFE ID del certificado: `spiffe://sbos.skull/agent/banexus/Ventas-01`
4. Verifica que el SPIFFE ID esta autorizado en la whitelist de nodos
5. Asocia la conexion al node_id para futuras decisiones de enrutamiento

### Autenticacion con bauth

La comunicacion con bauth es via Unix socket (bajo latencia). La autenticacion es a nivel OS (permisos de socket). Para requests que requieren autorizacion, bhnexus incluye su SPIFFE ID en el payload JSON.

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS2, V5-SS1, V7-SS1, V7-SS6; INVESTIGACION_NORMAS_ESTANDARES.md §1 (Trace Context), §2 (SPIFFE/mTLS), §10 (OSDP)_
