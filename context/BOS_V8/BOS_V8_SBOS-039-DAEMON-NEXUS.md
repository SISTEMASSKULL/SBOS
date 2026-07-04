# SBOS-039-DAEMON-NEXUS
## SBOS Nexus: Host + Agent — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

### Nexus Host (bhnexus)

| Campo | Valor |
|---|---|
| Daemon | `bhnexus` |
| Servicio | `bhnexus.service` (systemd en host) |
| Lenguaje | Go (alta concurrencia WebSocket) |
| Puerto WebSocket | 9444 (mTLS) |
| Puerto métricas | 9445 (Prometheus) |
| Función | Proxy de Hardware Universal — traduce evento físico en consulta de autorización |

### Nexus Agent (banexus)

| Campo | Valor |
|---|---|
| Daemon | `banexus` |
| Servicio | `banexus.service` (systemd --user en Fedora) |
| Lenguaje | Go (concurrencia I/O + WebSocket) |
| Comunicación | WebSocket mTLS exclusivo con bhnexus |
| Función | Edge Sentinel — intercepta inputs, congela shell, controla actuadores |

## 2. Arquitectura Host (bhnexus)

```
bhnexus (Go)
├── WebSocket Manager    — 10,000+ conexiones concurrentes con agentes
├── Hardware Bridge      — OSDP, MQTT, ONVIF, Wiegand normalización
├── Request Router       — identifica nodo + tipo solicitud
├── Auth Cache           — in-memory BitMasks (TTL 30s configurable)
├── bauth Client         — consulta via Unix socket (cache miss)
└── Response Dispatcher  — BitMask a agente + actuator commands a hardware
```

Lo que NO hace: lógica de negocio, almacenar biometría, autenticación primaria (eso es KC).

## 3. Protocolo WebSocket bhnexus ↔ banexus

### Conexión (mTLS)
```
banexus → bhnexus: WSS upgrade + headers (X-Node-ID, X-Agent-Version, X-Agent-Cert-Fingerprint)
bhnexus verifica: certificado mTLS válido + Node-ID registrado + versión compatible
OK → conexión, agente en Agents[]  |  FAIL → 403 + log
```

### Frames
```json
// auth_request (banexus→bhnexus)
{"type":"auth_request","node_id":"Ventas-01","input_type":"qr","payload":"sbos://auth/..."}

// auth_response (bhnexus→banexus)
{"type":"auth_response","status":"granted","bitmask":"0x000000000003E627",
 "actuator_commands":[{"target":"RELAY_01","action":"OPEN","duration_ms":3000}]}

// policy_update (bhnexus→banexus, push)
{"type":"policy_update","reason":"roltemplate_changed","affected_users":["uuid-1"],"action":"invalidate_cache"}

// heartbeat (banexus→bhnexus)
{"type":"heartbeat","node_id":"Ventas-01","uptime_seconds":86400,"active_sessions":3}
```

Reconexión: exponential backoff 1s→5s→15s→30s→60s. Durante desconexión: policy cache efímero.

## 4. Device Fichas (Hardware Bridge)

```yaml
# /etc/bos/blibs/bhnexus/devices/puerta-principal.yml
device:
  id: "AP-PUERTA-01"
  name: "Puerta Principal — Piso de Ventas"
  type: "access_point"
  protocol: "osdp"         # osdp | mqtt | onvif | wiegand | http
  connection: { host: "192.168.1.50", port: 9600 }
  zone: "ZONE-VENTAS"
  actuators:
    - id: "RELAY_01"
      type: "door_lock"
      action_on_grant: "OPEN"
      open_duration_ms: 3000
  health: { check_interval_seconds: 30, check_command: "osdp_poll" }
```

## 5. Nexus Agent (banexus) — Edge

### Input Hooking (udev + libusb)
```bash
# /etc/udev/rules.d/99-banexus-intercept.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="<vid>", ATTR{idProduct}=="<pid>", MODE="0660", GROUP="banexus"
```
Captura datos de QR/NFC/barcode ANTES de que evdev los pase a Fedora.

### Shell Sentinel (PAM + polkit)
```
Comando sensible → pam_banexus.so intercepta → consulta bhnexus
  GRANTED (bit SHELL_UNLOCK) → liberar
  DENIED → bloquear + notificar
  TIMEOUT → consultar policy cache local
```

### Policy Cache Efímero
BitMask almacenada AES-256-GCM (clave derivada del cert mTLS). Conexión perdida → cache con TTL. TTL expirado → DENY todo. Reconexión → invalidar cache + refresh + resumen offline.

### Control de Actuadores (Go)
```go
func executeActuatorCommand(cmd ActuatorCommand) error {
    port, _ := serial.Open(config.RelayPort, &serial.Mode{BaudRate: 9600})
    port.Write([]byte{0x01, 0x01})  // OPEN
    time.AfterFunc(cmd.DurationMs, func() { port.Write([]byte{0x01, 0x00}) })  // CLOSE
}
```

## 6. Flujo Soberano Completo (latencia ~15ms)

```
T+0.000  Usuario presenta QR al lector USB
T+0.001  banexus intercepta datos bus USB
T+0.002  banexus firma payload HMAC → envía bhnexus (WebSocket)
T+0.005  bhnexus recibe, identifica nodo
T+0.006  Auth cache hit? SÍ→T+0.007 | NO→consulta bauth Unix socket
T+0.010  bauth evalúa: UserTemplate + RolTemplate (lógico+físico+financiero)
T+0.012  BitMask: 0x000000000003E627
T+0.013  bhnexus almacena cache (TTL 30s)
T+0.014  bhnexus envía: BitMask + actuator_commands[RELAY_01:OPEN]
T+0.015  banexus ejecuta en paralelo:
           1. SHELL_UNLOCK (bit 1)
           2. DRAWER_OPEN (bit 5)
           3. RELAY_01 OPEN via serial
TOTAL: ~15ms (objetivo < 50ms)
```

## 7. Configuración

### bhnexus.toml
```toml
[server]
websocket_port = 9444
tls_cert/key/ca = "/etc/bos/tls/..."
[auth]
bauth_socket = "/run/bos/bauth.sock"
cache_ttl_seconds = 30
[hardware]
devices_path = "/etc/bos/blibs/bhnexus/devices/"
osdp_enabled = true
mqtt_broker = "localhost:1883"
```

### banexus.toml
```toml
[agent]
node_id = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert/key/ca = "/etc/banexus/tls/..."
[input]
intercept_usb = true
reader_devices = ["/dev/banexus/reader-*"]
[shell_sentinel]
sensitive_commands = ["apt-get","dnf","systemctl","rm -rf"]
[actuators]
relay_port = "/dev/ttyUSB0"
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 Host | SBOS-035 v1.0 | §1-§2 (identidad, arquitectura interna) |
| §3 Protocolo | SBOS-035 v1.0 | §3 completo (conexión mTLS, 4 tipos frame, reconexión) |
| §4 Devices | SBOS-035 v1.0 | §4 (device ficha YAML, OSDP/MQTT) |
| §5 Agent | SBOS-036 v1.0 | §1-§4 completo (input hooking, shell sentinel, cache, actuadores) |
| §6 Flujo | SBOS-035 v1.0 | §5 (flujo completo con latencias) |
| §7 Config | SBOS-035 + 036 v1.0 | §6 + §5 (bhnexus.toml + banexus.toml) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-039-DAEMON-NEXUS

## V5 — Enriquecimiento desde BOS_V5_SBOS-035-NEXUS-HOST-v1_0 + SBOS-036-NEXUS-AGENT-v1_0

### V5 §1 — Arquitectura Expandida del Nexus Host

**Componentes internos de bhnexus (Go):**
```
bhnexus (Go binary, ~15MB estático)
┌─────────────────────────────────────────────────────────┐
│ WebSocket Manager                                        │
│ ├── gorilla/websocket (hasta 10,000 conexiones)          │
│ ├── Write deadline: 10s, Read deadline: 30s              │
│ ├── Ping/Pong cada 15s (desconexión detectada en < 30s)  │
│ └── Reconexión: backoff exponencial 1s→5s→15s→30s→60s   │
├─────────────────────────────────────────────────────────┤
│ Hardware Bridge                                           │
│ ├── OSDP: Security Industry Association (SIA) OSDP v2.2  │
│ ├── MQTT: Mosquitto bridge (pub/sub sobre TCP/1883)      │
│ ├── ONVIF: ONVIF Profile C (control de acceso)           │
│ ├── Wiegand: Decodificación de 26/34/37 bits             │
│ └── HTTP: REST API para dispositivos no estándar         │
├─────────────────────────────────────────────────────────┤
│ Auth Cache                                                │
│ ├── sync.Map (concurrente, sin locks explícitos)          │
│ ├── TTL: 30s (configurable en bhnexus.toml)              │
│ ├── Capacidad: 100,000 entradas (~15MB RAM)              │
│ └── Evicción: LRU cuando supera capacidad                 │
└─────────────────────────────────────────────────────────┘
```

### V5 §2 — Protocolo WebSocket Expandido

**Handshake de conexión detallado:**
```
1. banexus inicia conexión WSS a bhnexus:9444
2. banexus envía headers:
   X-Node-ID: "Ventas-01"
   X-Agent-Version: "1.0.0"
   X-Agent-Cert-Fingerprint: "SHA256:...del-certificado-mTLS"
3. bhnexus recibe y verifica:
   a. Certificado mTLS válido (no expirado, firma OK)
   b. Node-ID existe en devices registry
   c. Versión del agente es compatible (major version match)
4. Si OK: conexión establecida, agente añadido a Agents[]
5. Si FAIL: 403 Forbidden + log de auditoría + evento Wazuh
```

**Estados de la conexión del agente:**
| Estado | Descripción | Acción por parte del host |
|---|---|---|
| connected | Conexión activa y funcional | Enrutar requests normalmente |
| disconnected | Desconexión detectada por timeout | Cache efímero TTL, cola de eventos offline |
| suspended | Host suspendió al agente por policy | No enviar request, mantener conexión |
| terminated | Agente dado de baja | Eliminar de agents map, notificar admin |

### V5 §3 — Nexus Agent Edge Expandido

**Input Hooking con udev + libusb (detalle):**
```
Captura de eventos USB:
1. udev detecta inserción de lector QR/NFC y aplica regla 99-banexus.rules
   → cambia grupo a banexus, permisos 0660
2. banexus abre el dispositivo vía libusb
3. Para QR: bulk transfer endpoint 0x01 → buffer 512 bytes
4. Para NFC: ISO 14443A/B (NFC Type A/B)
5. Datos en crudo antes de que evdev genere eventos de teclado
   → Evita inyección de eventos maliciosos via /dev/input/*
```

**Shell Sentinel con PAM (detalle):**
```
Sensitive command interception via PAM:
1. Usuario ejecuta: sudo rm -rf /etc/bos/
2. PAM module pam_banexus.so se ejecuta en auth phase
3. pam_banexus.so extrae:
   - username del usuario actual
   - comando detectado (del entorno o de audit.log)
   - terminal desde donde ejecuta
4. Envía request a banexus local via Unix socket
5. banexus consulta bhnexus via WebSocket:
   {"type":"auth_request","node_id":"Ventas-01",
    "input_type":"shell","payload":{"user":"admin","command":"rm -rf /etc/bos/"}}
6. bhnexus evalúa BitMask SHELL_UNLOCK:
   - GRANTED: PAM retorna PAM_SUCCESS → comando ejecuta
   - DENIED: PAM retorna PAM_PERM_DENIED → comando bloqueado
   - TIMEOUT: PAM retorna PAM_SUCCESS (fail-open bloqueante) → cache local
```

---

## V7 — Enriquecimiento desde BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0

### V7 §1 — HAL (Hardware Abstraction Layer) Interface

El NEXUS Host implementa una capa de abstracción de hardware (HAL) que estandariza todos los protocolos físicos bajo una interfaz común:

```go
// DeviceDriver — interfaz que todo driver de hardware debe implementar
type DeviceDriver interface {
    Init(config DeviceConfig) error
    ReadEvent(ctx context.Context) (CredentialEvent, error)
    WriteCommand(cmd ActuatorCommand) error
    Health() HealthStatus
    Close() error
}

// CredentialEvent — evento normalizado de cualquier lector
type CredentialEvent struct {
    SourceID      string       // ID del dispositivo físico
    Credential    Credential   // Credencial normalizada
    CapturedAt    time.Time    // Timestamp de captura local
    FirmwareVer   string       // Versión del firmware del lector
}

// Credential — 10 tipos de credenciales soportados
type Credential struct {
    Type   CredentialType   // qr | nfc | barcode | fingerprint | pin | smartcard | face | voice | ble | usb
    Raw    []byte           // Datos crudos del lector
    Parsed string           // Interpretación (ej: "sbos://auth/user/uuid")
    Hash   [32]byte         // SHA-256 del raw (para integridad)
}
```

### V7 §2 — Jerarquía de 11 Niveles de Ubicación Física

```
NIVEL  0 — PLANETA (Tierra) — solo referencia continental
NIVEL  1 — PAÍS (ej: Bolivia) — límite legal/regulatorio
NIVEL  2 — CIUDAD (ej: La Paz) — ubicación administrativa
NIVEL  3 — SUCURSAL (ej: Sucursal Central) — unidad de negocio
NIVEL  4 — PISO (ej: Piso 3) — nivel dentro del edificio
NIVEL  5 — ZONA (ej: Zona Ventas) — área funcional
NIVEL  6 — PUESTO (ej: Caja-01) — punto de operación individual
NIVEL  7 — DISPOSITIVO (ej: Lector QR-01) — hardware específico
NIVEL  8 — SUBDISPOSITIVO (ej: Relé-01) — componente del hardware
NIVEL  9 — SENSOR (ej: Contacto magnético) — sensor individual
NIVEL 10 — ACTUADOR (ej: Cerradura eléctrica) — actuador final
```

Implementación en bhnexus: cada device.yml declara su ubicación completa:
```yaml
device:
  id: "LAPAZ-SUC1-P3-VENTAS-CAJA1-LECTOR01"
  location:
    pais: "BO"
    ciudad: "La Paz"
    sucursal: "Sucursal Central"
    piso: 3
    zona: "Ventas"
    puesto: "Caja-01"
```

### V7 §3 — Tipos de Credenciales Soportados (10 tipos)

| # | Tipo | Tecnología | Uso típico |
|---|---|---|---|
| 1 | QR | Código QR dinámico | Acceso a puesto, autenticación rápida |
| 2 | NFC | ISO 14443A/B | Tarjeta de empleado, tag de activo |
| 3 | Barcode | Código de barras 1D/2D | Documentos, inventario |
| 4 | Fingerprint | Escáner biométrico capacitivo/óptico | Autenticación fuerte |
| 5 | PIN | Teclado numérico | Backup, modo offline |
| 6 | Smartcard | PKCS#11/PIV | Firma digital, acceso privilegiado |
| 7 | Face | Cámara RGB/IR | Control de acceso sin contacto |
| 8 | Voice | Micrófono + liveness detection | Autenticación por voz (future) |
| 9 | BLE | Bluetooth Low Energy | Proximidad, beacon |
| 10 | USB | HID bulk transfer | Conexión directa de hardware |

### V7 §4 — Drivers de Hardware Soportados (6 protocolos)

| Driver | Protocolo | Estándar | Conexión típica |
|---|---|---|---|
| `driver_osdp` | OSDP v2.2 | SIA OSDP | RS-485 serial |
| `driver_wiegand` | Wiegand 26/34/37 bits | De facto industria | Cableado directo GPIO |
| `driver_mqtt` | MQTT v3.1.1/v5 | OASIS | TCP/IP a broker |
| `driver_onvif` | ONVIF Profile C/A | ONVIF | IP/ethernet |
| `driver_usbhid` | USB HID | USB-IF | USB directo |
| `driver_http` | REST API | Propietario | TCP/IP |

### V7 §5 — Offline Fail-Secure Behavior

Cuando un agente banexus pierde conexión con el host bhnexus:

```
1. DETECCIÓN: No recibe PONG en 30s → disconnected state
2. CACHE LOCAL:
   - BitMasks almacenadas localmente con AES-256-GCM
   - TTL máximo offline: 4 horas (configurable)
   - TTL de cada BitMask: lo que restaba del TTL original (máx 30s)
3. MODO DEGRADADO:
   - Para cada auth_request:
     a. Buscar en cache local
     b. Cache hit AND TTL válido → GRANTED (con cache_used=true)
     c. Cache miss OR TTL expirado → DENIED (fail-secure)
4. RECONEXIÓN:
   - backoff exponencial 1s → 5s → 15s → 30s → 60s (máximo)
   - Al reconectar: invalidar cache local, recibir resumen offline
5. RESUMEN OFFLINE:
   - bhnexus envía buffer de eventos perdidos durante desconexión
   - banexus registra en log local
   - No se re-evalúan decisiones offline (ya fueron en fail-secure)
```

**Regla de seguridad:** En modo offline, TODAS las decisiones no cacheadas son DENIED. No existe "fail-open" en NEXUS. La compensación es que los TTL de cache pueden ajustarse por zona (ej: 30s para caja, 5 min para office).

### V7 §6 — Métricas Prometheus y Alertas Wazuh

**Métricas Prometheus expuestas por bhnexus (puerto 9445):**

| Métrica | Tipo | Descripción |
|---|---|---|
| `nexus_agents_connected_total` | Gauge | Agentes actualmente conectados |
| `nexus_auth_requests_total` | Counter | Total de solicitudes de autenticación |
| `nexus_auth_requests_duration_seconds` | Histogram | Duración de evaluación (buckets 1ms-100ms) |
| `nexus_auth_results_granted_total` | Counter | Autenticaciones concedidas |
| `nexus_auth_results_denied_total` | Counter | Autenticaciones denegadas |
| `nexus_auth_cache_hit_ratio` | Gauge | Ratio de aciertos de cache (0.0-1.0) |
| `nexus_hardware_errors_total` | Counter | Errores de comunicación con hardware |
| `nexus_offline_sessions_seconds` | Gauge | Tiempo acumulado offline por agente |
| `nexus_actuator_commands_total` | Counter | Comandos de actuador ejecutados |

**Alertas Wazuh para eventos NEXUS:**

| Regla | Descripción | Severidad |
|---|---|---|
| `NEXUS-001` | Múltiples denied desde mismo agente (rate > 10/min) | Alta |
| `NEXUS-002` | Conexión agente perdida > 30 min | Media |
| `NEXUS-003` | Intento de auth con certificado inválido | Alta |
| `NEXUS-004` | Error de hardware persistente (> 5 en 5 min) | Alta |
| `NEXUS-005` | Offline fail-secure activo para zona crítica | Crítica |
| `NEXUS-006` | Versión de agente desactualizada | Baja |
| `NEXUS-007` | Heartbeat de agente muestra anomalías (uptime reiniciado sospechosamente) | Media |
| `NEXUS-008` | Actuador ejecutado sin auth_request previo | Crítica |

### V7 §7 — Posicionamiento entre los 8 Daemons Soberanos

```
Daemon              Rol                        Comunicación con NEXUS
─────────────────────────────────────────────────────────────────────
bos (IAM Installer)  Control plane              Crea device fichas, recibe health
bkernel              Data plane                 Lee audit_events desde WAL
biedata              Integration plane           — (no se comunica)
bcompass             Intelligence plane          — (no se comunica)
bsearch              Search plane                Indexa eventos de autenticación
bauth                Identity plane              Evalúa BitMask via Unix socket (directo)
banexus              Edge plane (cliente)        WebSocket mTLS (conecta a bhnexus)
bhnexus              Connectivity plane          Broker central de todos los agentes
```

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-039-DAEMON-NEXUS.md` | Documento completo (185 líneas) |
| V5 Nexus Host | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-035-NEXUS-HOST-v1_0.md` | §1 Arquitectura interna expandida, §2 Protocolo WebSocket handshake detallado, §3 Estados de conexión |
| V5 Nexus Agent | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-036-NEXUS-AGENT-v1_0.md` | §1 Input hooking udev+libusb detalle, §2 Shell Sentinel PAM, §3 Policy cache, §4 Actuadores Go |
| V7 Nexus Conceptualización | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md` | §1 HAL DeviceDriver interface, §2 11-level ubicación física, §3 10 credenciales, §4 6 drivers hardware, §5 Offline fail-secure, §6 Prometheus + Wazuh métricas/alertas, §7 Posicionamiento 8 daemons |

---

_SKULL · SBOS · SBOS-039-DAEMON-NEXUS · V8 (V6+V5+V7) · Mayo 2026_
