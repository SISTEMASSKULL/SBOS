# FUNCIONALIDADES — SBOS Nexus Agent (banexus)

**Identidad:** `spiffe://sbos.skull/daemon/banexus`
**Puertos:** No expone puertos de red (solo Unix socket local `/run/banexus/agent.sock`)
**Lenguaje:** Go (runtime minimo, ~15MB RAM base)
**Conexion:** WSS hacia bhnexus:9444 (mTLS)
**Almacenamiento local:** AES-256-GCM en `/var/lib/banexus/cache.db` (policy cache cifrado)
**Propagacion W3C:** `traceparent` + `baggage` en frames WebSocket hacia bhnexus

---

## Seccion 1: Tabla de Capacidades

| ID | Capacidad | Tipo | Protocolo | Endpoint/Stream | Consumidores |
|---|---|---|---|---|---|
| F-001 | Input Hooking (udev + libusb) | Interna/Hardware | udev + libusb bulk transfer | Dispositivos USB (QR, NFC, barcode) | banexus Auth Engine interno |
| F-002 | Shell Sentinel (PAM + polkit) | Interna/API | PAM module + polkit action | `/lib/security/pam_banexus.so` + D-Bus polkit | Kernel PAM, polkit daemon |
| F-003 | Policy Cache Efimero | Interna/In-Memory | AES-256-GCM local | `/var/lib/banexus/cache.db` (cifrado) | banexus Auth Engine (modo offline) |
| F-004 | Control de Actuadores | Interna/Hardware | Serial (RS-232) + GPIO | Puerto serial configurable + pines GPIO | Cerraduras, reles, alarmas, barreras |
| F-005 | Heartbeat y Monitoreo | Interna/Schedule | Frame WebSocket | Frame tipo `heartbeat` cada 15s a bhnexus | bhnexus (F-006 monitoreo) |

---

## Seccion 2: Especificacion de Cada Capacidad

### F-001: Input Hooking (udev + libusb)

- **Proposito:** Capturar datos de lectores USB (QR, NFC, barcode) a nivel de dispositivo, antes de que el kernel genere eventos de teclado (evdev), previniendo inyeccion de eventos maliciosos.
- **Trigger:** Insercion de lector USB detectada por udev + comando de lectura del lector (QR escaneado, NFC detectado, barcode leido).
- **Protocolo:** udev rule + libusb bulk transfer. Lectura directa del endpoint de entrada del dispositivo USB.
- **Regla udev:**
  ```bash
  # /etc/udev/rules.d/99-banexus-intercept.rules
  SUBSYSTEM=="usb", ATTR{idVendor}=="<vid>", ATTR{idProduct}=="<pid>", MODE="0660", GROUP="banexus"
  ```
- **Flujo de captura:**
  1. udev detecta insercion de lector QR/NFC y aplica regla `99-banexus-intercept.rules`
  2. Grupo cambiado a `banexus`, permisos 0660
  3. banexus abre el dispositivo via libusb
  4. Para QR: bulk transfer endpoint 0x01 -> buffer 512 bytes
  5. Para NFC: ISO 14443A/B (NFC Type A/B) -> UID de 4-7 bytes + datos de aplicación si existen
  6. Datos capturados ANTES de que evdev genere eventos de teclado
- **CredentialHash generado:**
  ```go
  credentialHash := sha256.Sum256(append([]byte(inputType), rawData...))
  // inputType: "qr_code", "nfc_card", "barcode"
  ```
- **Criterios de Aceptacion:**
  - DADO un lector QR conectado via USB CUANDO se escanea un codigo QR ENTONCES banexus captura los datos via libusb bulk transfer en menos de 1ms desde que el lector recibe el dato, ANTES de que evdev genere eventos de teclado.
  - DADO un intento de inyeccion de teclado malicioso via `/dev/input/*` CUANDO se simula escritura de teclado ENTONCES banexus NO captura esos eventos (solo captura via libusb directo, no via input subsystem).
  - DADO que se conecta un lector NFC CUANDO se detecta via udev ENTONCES banexus configura el dispositivo para modo ISO 14443A y comienza a leer UIDs de tarjetas en menos de 100ms.
  - DADO que el dispositivo USB se desconecta CUANDO banexus detecta error de lectura ENTONCES cierra el handler, espera reconexion via udev, y se re-configura automaticamente.
- **Manejo de Errores:** Si libusb devuelve LIBUSB_ERROR_NO_DEVICE, el dispositivo se marca como desconectado. Timeout de bulk transfer: 500ms. Si 3 lecturas consecutivas fallan, el dispositivo se marca como `degraded` y se notifica a bhnexus via heartbeat status.
- **Propagacion de Contexto:** Cada captura genera un nuevo `trace_id`. El `traceparent` se incluye en el frame `auth_request` que se envia a bhnexus. El `baggage` incluye `bos_node_id`, `bos_reader_id`.
- **Idempotencia:** Si se captura el mismo codigo QR dos veces en menos de 1s se considera rebote y se descarta (anti-bounce). El anti-bounce es configurable por dispositivo.
- **Dependencias:** udev (reglas de dispositivos), libusb (biblioteca de usuario USB), kernel Linux (USB subsystem).

### F-002: Shell Sentinel (PAM + polkit)

- **Proposito:** Interceptar comandos sensibles en el shell del sistema operativo y consultar autorizacion antes de permitir su ejecucion, mediante modulo PAM y reglas polkit.
- **Trigger:** Ejecucion de comando sensible por parte del usuario (sudo, su, cambios de configuracion del sistema).
- **Protocolo:** PAM module `pam_banexus.so` se ejecuta en auth phase. Polkit action `org.sbos.banexus.shell-execute` para aplicaciones graficas.
- **Flujo PAM:**
  1. Usuario ejecuta: `sudo rm -rf /etc/bos/`
  2. PAM module `pam_banexus.so` se ejecuta en auth phase
  3. Extrae: username, comando detectado (entorno/audit.log), terminal, timestamp
  4. Envia request a banexus local via Unix socket `/run/banexus/agent.sock`
  5. banexus consulta bhnexus via WebSocket:
     ```json
     {
       "type": "auth_request",
       "node_id": "Ventas-01",
       "input_type": "shell",
       "payload": {
         "user": "admin",
         "command": "rm -rf /etc/bos/",
         "terminal": "/dev/pts/2",
         "working_dir": "/root",
         "timestamp": "2026-05-27T10:30:00.123Z"
       },
       "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
     }
     ```
  6. bhnexus evalua BitMask SHELL_UNLOCK:
     - GRANTED: PAM retorna PAM_SUCCESS -> comando ejecuta
     - DENIED: PAM retorna PAM_PERM_DENIED -> comando bloqueado, mensaje: "Accion denegada por politica de seguridad"
     - TIMEOUT: PAM retorna PAM_SUCCESS + consulta cache local (fail-open controlado, registrado en log)
- **Comandos interceptados (configuracion en `/etc/banexus/shell_commands.yml`):**
  ```yaml
  sensitive_commands:
    - pattern: "rm -rf"
      severity: CRITICAL
      action: ENFORCE
    - pattern: "chmod 777"
      severity: HIGH
      action: ENFORCE
    - pattern: "systemctl stop bos*"
      severity: CRITICAL
      action: ENFORCE
  ```
- **Criterios de Aceptacion:**
  - DADO que un usuario ejecuta `sudo rm -rf /etc/bos/` CUANDO el PAM module intercepta el comando ENTONCES banexus envia `auth_request` a bhnexus, y si la respuesta es DENIED, PAM retorna PAM_PERM_DENIED y el comando NO se ejecuta, en menos de 50ms total.
  - DADO que bhnexus no responde en 5s (timeout) CUANDO se evalua un comando ENTONCES PAM retorna PAM_SUCCESS (fail-open controlado) y el comando se ejecuta, pero se registra en log como "TIMEOUT - fail-open" con alerta de auditoria.
  - DADO que el comando no esta en la lista de comandos sensibles CUANDO el usuario lo ejecuta ENTONCES PAM retorna PAM_IGNORE (no intercepta comandos no sensibles).
  - DADO que la evaluacion retorna GRANTED CUANDO se consulta bhnexus ENTONCES el resultado se almacena en cache local (F-003) con TTL de 60s para comandos repetidos del mismo usuario.
- **Manejo de Errores:** Timeout PAM: 5s configurable. Si el Unix socket de banexus no responde, PAM retorna PAM_SUCCESS (fail-open controlado) + evento de seguridad. Si bhnexus retorna TIMEOUT, PAM retorna PAM_SUCCESS + consulta cache local.
- **Propagacion de Contexto:** El `traceparent` se genera al recibir la llamada PAM. Se propaga a bhnexus via frame WebSocket. El `baggage` lleva `bos_user`, `bos_node_id`, `bos_command_hash`.
- **Idempotencia:** El mismo comando del mismo usuario en la misma terminal dentro de 60s retorna el mismo resultado (cache local). La clave de cache es `{user}:{command_hash}:{terminal}`.
- **Dependencias:** PAM (Linux Pluggable Authentication Modules), polkit (PolicyKit), bhnexus (evaluacion remota), cache local (F-003).

### F-003: Policy Cache Efimero

- **Proposito:** Mantener BitMasks cacheadas localmente con cifrado AES-256-GCM para operacion offline segura del agente banexus.
- **Trigger:** Resultado de `auth_request` desde bhnexus (F-002) o precarga al iniciar sesion.
- **Protocolo:** Almacenamiento local cifrado en `/var/lib/banexus/cache.db`. Clave derivada del certificado mTLS via HKDF.
- **Estructura de cache:**
  ```go
  type CacheEntry struct {
      BitMaskHigh   uint64    `json:"bm_high"`
      BitMaskLow    uint64    `json:"bm_low"`
      ExpiresAt     time.Time `json:"expires_at"`
      NodeID        string    `json:"node_id"`
      CredentialHash [32]byte `json:"credential_hash"`
  }
  ```
- **Almacenamiento:**
  - Archivo: `/var/lib/banexus/cache.db` (SQLite cifrado con AES-256-GCM)
  - Clave: derivada del certificado mTLS (SPIFFE SVID) via HKDF-SHA256
  - Autenticacion: Poly1305 tag (GCM mode)
- **Comportamiento offline:**
  1. Conexion perdida -> estado `disconnected`
  2. Para cada auth_request:
     a. Buscar en cache local por (node_id + input_type + credential_hash)
     b. Cache hit AND TTL valido -> GRANTED (con `cache_used=true`)
     c. Cache miss OR TTL expirado -> DENIED (fail-secure)
  3. Reconexion -> invalidar cache local, recibir resumen offline de bhnexus
- **Criterios de Aceptacion:**
  - DADO una entrada valida en cache local CUANDO se consulta con la misma (credential_hash) ENTONCES se retorna GRANTED en menos de 1ms (lectura in-memory, sin I/O a disco).
  - DADO que la conexion con bhnexus se pierde CUANDO se recibe un auth_request sin cache local ENTONCES se retorna DENIED (fail-secure: sin conexion y sin cache, denegar acceso).
  - DADO que se intenta leer el archivo cache.db sin el certificado mTLS original CUANDO se accede ENTONCES el descifrado falla (Poly1305 tag mismatch) y el contenido no es legible.
  - DADO que la conexion con bhnexus se restablece CUANDO el agente se reconecta ENTONCES el cache local se invalida completamente y se recibe un resumen offline con las entradas validas actualizadas.
  - DADO una entrada con TTL expirado CUANDO se consulta ENTONCES se trata como cache miss y se retorna DENIED.
- **Manejo de Errores:** Si el archivo cache.db esta corrupto (tag mismatch), se elimina y se crea uno nuevo vacio. No hay fallback a cache sin cifrar por razones de seguridad.
- **Propagacion de Contexto:** No aplica (cache local).
- **Idempotencia:** Cada entrada de cache tiene (credential_hash + node_id) como clave unica. Upsert en cache local.
- **Dependencias:** Certificado mTLS (SPIFFE SVID), bhnexus (fuente de verdad), filesystem (`/var/lib/banexus/`).

### F-004: Control de Actuadores

- **Proposito:** Ejecutar comandos sobre actuadores fisicos conectados a la estacion de trabajo: cerraduras electromagneticas, reles, alarmas, barreras vehiculares, y otros dispositivos de control de acceso.
- **Trigger:** Frame `auth_response` con `actuator_commands` desde bhnexus (F-002 respuesta).
- **Protocolo:** Serial RS-232 (COM) para reles/cerraduras, GPIO para alarmas, HTTP para actuadores IP.
- **Comandos soportados:**
  | Tipo de actuador | Protocolo | Comando | Duracion |
  |---|---|---|---|
  | Cerradura electrica | RS-232 (byte 0x01) | `OPEN` (0x01) / `CLOSE` (0x00) | configurable (default 5s) |
  | Rele auxiliar | RS-232 (byte 0x02) | `OPEN` (0x01) / `CLOSE` (0x00) | configurable |
  | Alarma | GPIO pin alto/bajo | `ACTIVATE` (high) / `DEACTIVATE` (low) | hasta comando contrario |
  | Barrera vehicular | HTTP REST | `POST /control?action=raise` / `lower` | hasta comando contrario |
- **Implementacion:**
  ```go
  func executeActuatorCommand(cmd ActuatorCommand) error {
      port, _ := serial.Open(config.RelayPort, &serial.Mode{BaudRate: 9600})
      port.Write([]byte{0x01, cmd.RelayID, 0x01})  // OPEN
      time.AfterFunc(cmd.DurationMs, func() {
          port.Write([]byte{0x01, cmd.RelayID, 0x00})  // CLOSE
      })
      return nil
  }
  ```
- **Criterios de Aceptacion:**
  - DADO un frame `auth_response` con `actuator_commands: [{"actuator_id": "door_01", "command": "OPEN", "duration_ms": 5000}]` CUANDO se recibe ENTONCES se envia el comando OPEN al puerto serial en menos de 2ms y se programa el comando CLOSE automaticamente a los 5000ms exactos.
  - DADO que el puerto serial no esta disponible (desconectado) CUANDO se intenta enviar un comando ENTONCES se retorna error y se registra en log, sin afectar otros actuadores.
  - DADO un comando CLOSE para un actuador que ya fue cerrado CUANDO se ejecuta ENTONCES no se envia duplicado (idempotente).
  - DADO que el tiempo de duracion del comando OPEN expira CUANDO se ejecuta el auto-close ENTONCES el cierre se ejecuta exactamente al tiempo especificado sin desviacion perceptible.
- **Manejo de Errores:** Timeout serial write: 500ms. Si 3 comandos consecutivos al mismo actuador fallan, se notifica en heartbeat a bhnexus. Error de GPIO: se registra y se reintenta una vez.
- **Propagacion de Contexto:** El `traceparent` del `auth_response` se propaga a la operacion del actuador. Cada actuador genera un span hijo.
- **Idempotencia:** Un actuador en estado `open` que recibe otro comando `OPEN` no hace nada (comando duplicado ignorado). El estado del actuador se trackea en memoria para evitar comandos redundantes.
- **Dependencias:** Puerto serial (RS-232), GPIO (sysfs /sys/class/gpio o libgpiod), HTTP (actuadores IP), bhnexus (comandos origen).

### F-005: Heartbeat y Monitoreo

- **Proposito:** Enviar estado de salud de la estacion a bhnexus periodicamente para monitoreo de conectividad y deteccion de fallos.
- **Trigger:** Timer interno cada 15s (configurable).
- **Protocolo:** Frame WebSocket tipo `heartbeat` enviado a bhnexus.
- **Frame de heartbeat:**
  ```json
  {
    "type": "heartbeat",
    "node_id": "Ventas-01",
    "uptime_seconds": 86400,
    "version": "2.4.1",
    "active_sessions": 3,
    "device_status": {
      "reader_qr": "ok",
      "reader_nfc": "ok",
      "door_01": "open",
      "alarm": "disarmed",
      "relay_01": "closed"
    },
    "last_auth_request_ms": 12,
    "cache_entries": 45,
    "errors_since_last_heartbeat": 0,
    "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
  }
  ```
- **Criterios de Aceptacion:**
  - DADO que el agente esta en estado `connected` CUANDO pasan 15s desde el ultimo heartbeat ENTONCES se envia un nuevo heartbeat a bhnexus con el estado actual de todos los dispositivos y actuadores.
  - DADO que un dispositivo (ej: lector QR) esta en estado `failed` CUANDO se envia el heartbeat ENTONCES el campo `device_status.reader_qr` refleja `failed` con timestamp del fallo.
  - DADO que bhnexus no recibe 2 heartbeats consecutivos (30s sin heartbeat) CUANDO se evalua desde bhnexus ENTONCES el agente se marca como `disconnected`.
  - DADO que la conexion WebSocket se pierde CUANDO el heartbeat no puede enviarse ENTONCES se reintenta la conexion con backoff exponencial (1s, 5s, 15s, 30s, max 60s) hasta reconectar.
- **Manejo de Errores:** Si el envio del heartbeat falla (conexion perdida), se almacena localmente en buffer circular (max 10 heartbeats) y se envian cuando la conexion se restablece (resumen offline). Timeout de envio: 5s.
- **Propagacion de Contexto:** Cada heartbeat lleva su propio `traceparent`. Los spans de heartbeat permiten medir latencia de conexion end-to-end.
- **Idempotencia:** Los heartbeats son acumulativos. Si bhnexus recibe 2 heartbeats con el mismo timestamp, el ultimo reemplaza al anterior.
- **Dependencias:** bhnexus (destino del heartbeat), banexus interno (recopilacion de estado de dispositivos).

---

## Seccion 3: Matriz Funcionalidad ↔ Daemon

| Funcionalidad | Consumida por | Protocolo de acceso |
|---|---|---|
| F-001 (Input Hooking) | banexus Auth Engine (interno) | libusb + udev |
| F-002 (Shell Sentinel) | PAM subsystem de Linux (todos los usuarios del sistema) | PAM module / polkit |
| F-003 (Policy Cache) | banexus Auth Engine (modo offline) | Archivo cifrado local |
| F-004 (Control Actuadores) | Cerraduras, reles, alarmas, barreras fisicas | Serial RS-232, GPIO, HTTP |
| F-005 (Heartbeat) | bhnexus (F-006 monitoreo de agentes) | Frame WebSocket |

**Servicios que banexus consume:**
- bhnexus -> WSS `wss://bhnexus:9444/ws` (canal de comunicacion bidireccional)
- bauth -> indirectamente via bhnexus (para evaluacion de auth_requests)
- Kernel Linux -> libusb (captura de dispositivos USB), udev (deteccion de dispositivos)
- PAM -> modulo pam_banexus.so (interceptacion de comandos)

**Canales de comunicacion:**
```
banexus <--WSS/mTLS--> bhnexus <--Unix socket--> bauth
                          |
                     bKernel WAL (eventos)
```

---

## Seccion 4: SLAs por Funcionalidad

| Funcionalidad | Latencia P99 | Throughput | Disponibilidad |
|---|---|---|---|
| F-001 (Input Hooking) | 1ms (captura desde lector) | 100 lecturas/s | 99.99% |
| F-002 (Shell Sentinel) | 50ms (interceptacion + respuesta) | 50 comandos/s | 99.99% |
| F-003 (Policy Cache) | 1ms (lectura in-memory) | Matching F-002 throughput | 100% (in-memory con persistencia cifrada) |
| F-004 (Control Actuadores) | 2ms (envio comando serial) | 10 comandos/s | 99.99% |
| F-005 (Heartbeat) | 500ms (envio + confirmacion) | 1 cada 15s por agente | 99.99% |

---

*Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS3, V7-SS5 · Estandares: W3C Trace Context, SPIFFE, FHS 3.0, PAM, libusb, ISO 27001, AES-256-GCM, OWASP*
