# ARQUITECTURA — SBOS Nexus Agent (banexus)

## Stack Tecnologico

| Componente | Tecnologia | Justificacion |
|---|---|---|
| Lenguaje | Rust 1.85+ MUSL | Seguridad de memoria, zero-cost abstractions, binario estatico |
| Async runtime | tokio | Concurrencia I/O para multiples lectores y WebSocket cliente |
| WebSocket | tokio-tungstenite | Cliente mTLS reconectable |
| Input Hooking | rusb (libusb binding) + udev | Captura USB en crudo antes de evdev |
| Shell Sentinel | PAM module (pam_banexus.so) | Interceptacion de comandos sensibles en auth phase |
| Cache local | AES-256-GCM (aes-gcm crate) | Cifrado de BitMasks en disco, clave derivada de cert mTLS |
| Actuadores | serialport-rs | Control de reles via puerto serie |

## Arquitectura Interna

```
banexus (Rust binary MUSL)
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| WebSocket Client (mTLS)                                  |
| +-- Conexion permanente con bhnexus:9444               |
| +-- Reconexion backoff: 1s->5s->15s->30s->60s          |
| +-- Heartbeat cada 15s                                  |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| Input Hooking Manager                                    |
| +-- udev monitor (insercion/remocion de lectores)      |
| +-- libusb bulk transfer (QR: endpoint 0x01, 512 bytes) |
| +-- NFC ISO 14443A/B                                    |
| +-- Captura antes de evdev (anti-inyeccion)             |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| Shell Sentinel (PAM)                                     |
| +-- pam_banexus.so en auth phase                        |
| +-- Detecta: apt-get, dnf, systemctl, rm -rf, sudo     |
| +-- Consulta bhnexus via WebSocket                      |
| +-- Timeout -> fail-open + cache local                  |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| Policy Cache Manager    |  Actuator Controller           |
| AES-256-GCM en disco    |  Control de reles via serial  |
| TTL 4h max offline      |  Auto-close con time.AfterFunc|
| Invalida al reconectar  |  Soporta OPEN/CLOSE/TOGGLE    |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
```

## Pipeline de Captura de Credencial

```
Lector USB detecta QR
  |
  v
udev: regla 99-banexus -> grupo banexus, permisos 0660
  |
  v
libusb: bulk transfer endpoint 0x01 -> buffer 512 bytes
  |
  v
banexus: parsea payload -> extrae sbos:// URI o raw data
  |
  v
banexus: construye Credential con Type, Raw, Parsed, Hash
  |
  v
banexus: firma payload HMAC -> construye auth_request
  |
  v
WebSocket: envia a bhnexus
```

## Configuracion (banexus.toml)

```toml
[agent]
node_id = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert = "/etc/banexus/tls/agent.crt"
tls_key = "/etc/banexus/tls/agent.key"
ca_cert = "/etc/banexus/tls/ca.crt"

[input]
intercept_usb = true
reader_devices = ["/dev/banexus/reader-*"]

[shell_sentinel]
sensitive_commands = ["apt-get","dnf","systemctl","rm -rf"]

[actuators]
relay_port = "/dev/ttyUSB0"
```

## Seguridad en Capas

```
1. FISICA: Input hooking antes de evdev (anti-keylogger)
2. TRANSPORTE: WebSocket mTLS (cifrado + auth mutua)
3. FIRMA: HMAC en payload de auth_request
4. CACHE: AES-256-GCM con clave derivada de cert mTLS
5. EJECUCION: Shell Sentinel via PAM (control de comandos)
6. OFFLINE: Fail-secure (DENY si no hay conexion + no hay cache)
```

---

## Seccion 2: Decisiones de Arquitectura (ADRs)

### ADR-001: Input Hooking via libusb antes de evdev (Anti-Inyeccion)
**Contexto:** Los lectores USB de credenciales (QR, NFC) generan eventos que el kernel expone como dispositivos de entrada HID. Un atacante con acceso local puede inyectar eventos HID falsos via evdev, simulando credenciales legítimas.
**Decision:** Capturar el dispositivo USB en crudo via libusb antes de que el kernel lo asigne a un driver HID (evdev). La regla udev 99-banexus asigna el dispositivo al grupo banexus con permisos 0660, impidiendo que evdev reciba los eventos. banexus lee el bulk transfer endpoint directamente (512 bytes para QR, ISO 14443A/B para NFC).
**Consecuencias:** Imposible inyectar eventos de lector falsos via evdev. USB Rubber Ducky y ataques similares son detectados porque el patron de bulk transfer no coincide con un lector real. Requiere udev rule y grupo dedicado. Compatible con la mayoria de lectores del mercado (ZKTeco, HID, Suprema).

### ADR-002: Shell Sentinel via PAM Module para Control de Comandos
**Contexto:** banexus corre en la estacion de trabajo del usuario (ej: punto de venta). Un usuario con acceso shell puede ejecutar comandos destructivos (apt-get remove, systemctl stop, rm -rf). El historico de bash no es confiable (puede borrarse).
**Decision:** Implementar modulo PAM (`pam_banexus.so`) que se ejecuta en la fase `auth` de PAM. Intercepta comandos sensibles configurados en banexus.toml. Consulta a bhnexus via WebSocket para verificar si el usuario tiene permiso para ejecutar ese comando. Si no hay conexion, usa cache local (fail-open por diseno — no bloquear al usuario legitimo sin red).
**Consecuencias:** Comandos destructivos requieren autorizacion incluso con sudo. El modulo PAM es independiente del shell (funciona con bash, zsh, sh). fail-open con cache evita bloqueos por perdida de red. El tiempo de autenticacion PAM se extiende ~50ms (despreciable).

### ADR-003: Cache Local AES-256-GCM para Operacion Offline
**Contexto:** banexus opera en estaciones de trabajo que pueden perder conectividad de red. Sin cache local, la autenticacion de usuarios fallaria completamente durante una caida de red, incluso para usuarios autorizados.
**Decision:** Cache local en disco cifrado con AES-256-GCM. La clave de cifrado se deriva del certificado mTLS del agente (PBKDF2 con 100,000 iteraciones). TTL maximo de 4h para entradas de BitMask. El cache se invalida completamente al reconectar con bhnexus (se descarga una copia fresca).
**Consecuencias:** Operacion offline hasta 4h. La clave de cifrado es unica por agente (derivada de su identidad mTLS). Si el disco es robado, el cache es ilegible sin el certificado. El TTL de 4h es un balance entre seguridad y disponibilidad.

### ADR-004: mTLS WebSocket como Unico Canal de Comunicacion
**Contexto:** banexus necesita un canal de comunicacion bidireccional, cifrado y mutuamente autenticado con bhnexus. Usar REST + WebSocket (para push) duplica la logica de conexion y autenticacion.
**Decision:** WebSocket con mTLS como unico canal de comunicacion. El handshake TLS presenta certificados mutuos (SVID de SPIRE). Una vez establecido, todo el trafico (eventos de credenciales, comandos de actuadores, heartbeat, consultas de shell sentinel) viaja por el mismo WebSocket.
**Consecuencias:** Una sola conexion gestiona todos los tipos de mensaje. Reconexion unica (no reconectar REST + WebSocket por separado). bhnexus puede identificar al agente por el SPIFFE ID del certificado mTLS. Sin overhead de HTTP por mensaje.

### ADR-005: Fail-Secure en Modo Offline (DENY si no hay cache + no hay conexion)
**Contexto:** banexus puede perder conectividad con bhnexus en dos escenarios: (1) caida de red temporal (cache disponible), (2) primer arranque sin conexion jamas establecida (sin cache).
**Decision:** Implementar politica fail-secure: si no hay conexion con bhnexus Y no hay cache local valida, DENY toda operacion. Si hay cache valida (con TTL dentro de 4h), permitir operacion offline. Al reconectar, invalidar cache y obtener decisiones frescas.
**Consecuencias:** Un agente recien instalado sin conexion no permite acceso fisico hasta que se conecte al menos una vez. Esto es intencional: la primera conexion establece confianza. En emergencias, bos puede precargar un cache inicial via bosctl.

---

## Seccion 3: Patrones de Arquitectura Aplicados

| Patron | Como lo implementa | Referencia |
|---|---|---|
| **mTLS + SPIFFE** | Conexion WebSocket con certificados mutuos SVID. banexus se identifica como `spiffe://sbos.skull/agent/banexus/{node_id}` | SPIFFE/SPIRE, Investigation §2 |
| **Cache Local Cifrado (AES-256-GCM)** | Cache en disco con clave derivada del cert mTLS. TTL 4h offline. Invalida al reconectar | — |
| **PAM Module** | `pam_banexus.so` intercepta comandos sensibles en auth phase. Fail-open con cache | PAM (Pluggable Authentication Modules) |
| **Input Hooking con libusb** | Captura USB antes de evdev para anti-inyeccion. Anti-Rubber Ducky | libusb, udev, Investigation §10 |
| **HMAC Payload Signing** | Todo auth_request firmado con HMAC-SHA256 antes de enviar por WebSocket. Previene tampering en la estacion de trabajo | — |
| **W3C Trace Context** | banexus inyecta traceparent en cada auth_request. El ctx_id viaja como baggage para trazabilidad extremo a extremo | W3C Trace Context, Investigation §1 |
| **SPIFFE Workload Identity** | SPIFFE ID del agente con node_id: `spiffe://sbos.skull/agent/banexus/{node_id}`. SVID para mTLS | SPIFFE/SPIRE, Investigation §2 |
| **Fail-Open vs Fail-Secure** | Fail-secure (DENY) si no hay cache + no hay conexion. Fail-open (permitir con cache) si hay cache valida <= 4h | — |

---

## Seccion 4: Modelo de Concurrencia

banexus maneja multiples fuentes de eventos concurrentes en una sola maquina:

- **Input Hooking (libusb):** Hilo dedicado con `libusb_handle_events` en bucle. Timeout de 100ms para no bloquear. Detecta insercion/remocion de lectores via udev monitor en goroutine separada.
- **WebSocket Client:** Goroutine de lectura (eventos entrantes de bhnexus: comandos de actuadores, respuesta de auth) y goroutine de escritura (eventos salientes: auth_requests, heartbeat). Buffer de escritura de 64KB.
- **Shell Sentinel (PAM):** El modulo PAM se ejecuta sincronicamente en el proceso del usuario. No bloquea a banexus (es un modulo separado .so). banexus expone un Unix socket local para consultas del modulo PAM.
- **Actuator Controller:** Goroutine separada que recibe comandos del WebSocket Client y los ejecuta en el puerto serie. Soporta OPEN/CLOSE/TOGGLE. Auto-close con `time.AfterFunc` configurable (default 5s).

Backpressure: Si el buffer de escritura del WebSocket excede 64KB, los nuevos eventos se descartan con log WARN. La prioridad es: auth_request > heartbeat > shell_sentinel > log.

---

## Seccion 5: Observabilidad

### Logs Estructurados (zerolog JSON)

```json
{"level":"info","time":"2026-05-27T10:00:00Z","module":"AUTH","event":"credential_captured","node_id":"Ventas-01","credential_type":"QR","reader":"ZKTeco-SB1000","duration_us":2340,"trace_id":"00-abc123-def456-01"}
```

### Metricas Prometheus (puerto 9106)

| Metrica | Tipo | Descripcion |
|---|---|---|
| `banexus_credentials_captured_total{type}` | Counter | Credenciales capturadas por tipo |
| `banexus_auth_requests_sent_total{result}` | Counter | Auth requests enviados a bhnexus |
| `banexus_websocket_reconnections_total` | Counter | Reconexiones WebSocket |
| `banexus_shell_sentinel_checks_total{result}` | Counter | Verificaciones de shell sentinel |
| `banexus_cache_age_seconds` | Gauge | Edad del cache local en segundos |
| `banexus_actuator_commands_total{actuator}` | Counter | Comandos de actuador ejecutados |
| `banexus_uptime_seconds` | Gauge | Tiempo de actividad del agente |

### RED Metrics

- **Rate:** `banexus_credentials_captured_total` por segundo
- **Errors:** `banexus_websocket_reconnections_total` / uptime (alta frecuencia indica problemas de red)
- **Duration:** Latencia de captura de credencial (desde interrupcion USB hasta envio WebSocket)

---

## Seccion 6: SPIFFE Workload Identity

| Atributo | Valor |
|---|---|
| SPIFFE ID | `spiffe://sbos.skull/agent/banexus/{node_id}` (ej: `spiffe://sbos.skull/agent/banexus/Ventas-01`) |
| Metodo de obtencion | SPIRE Agent via Unix socket `/run/spire/agent.sock` o SVID precargado por bos durante instalacion |
| Renovacion | SVID con TTL 1h, renovacion cada 30min |
| Uso de SVID | mTLS con bhnexus (WebSocket), firma de auth_requests |

### Identidad Jerarquica

El SPIFFE ID de banexus incluye el node_id, permitiendo a bhnexus identificar inequivocamente que agente solicita autenticacion:

- `spiffe://sbos.skull/agent/banexus/Ventas-01` — Agente en punto de venta 1
- `spiffe://sbos.skull/agent/banexus/Acceso-Principal` — Agente en puerta principal
- `spiffe://sbos.skull/agent/banexus/Servidor-Rack-01` — Agente en servidor

Esto permite a bhnexus aplicar politicas por ubicacion (ej: el agente de acceso principal tiene permisos de apertura 24/7, el de ventas solo en horario comercial).

### Autenticacion con bhnexus

1. banexus obtiene SVID de SPIRE Agent local
2. Inicia conexion WebSocket a bhnexus:9444 con mTLS
3. Presenta SVID X.509 como certificado cliente
4. bhnexus valida cadena de certificados contra CA de SPIRE
5. Extrae SPIFFE ID y node_id del certificado
6. Asocia la conexion al node_id para toda la sesion

### Cache de Identidad

Para entornos sin SPIRE Agent disponible, banexus puede operar con SVID precargado por bos durante instalacion (cifrado con clave de hardware TPM si disponible). Esta modalidad requiere que bos configure la rotacion manual del SVID.

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS5; INVESTIGACION_NORMAS_ESTANDARES.md §1 (Trace Context), §2 (SPIFFE/mTLS), §10 (OSDP, Input Hooking)_
