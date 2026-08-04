# INTEGRACIONES — SBOS Nexus Agent (banexus)

## Seccion 1: Tabla de Integraciones

| Sistema/Daemon | Tipo | Protocolo | Endpoint/Stream | Formato | Timeout | Retries | Direccion |
|---|---|---|---|---|---|---|---|
| SBOS Nexus Host (bhnexus) | Bidireccional | WebSocket mTLS | `wss://<host>:9444/ws` | JSON frames (TLV) | Write: 10s, Read: 30s | Reconexion backoff (1s, 5s, 15s, 30s, 60s) | banexus <-> bhnexus |
| SBOS Auth Enforce (bauth) | Indirecta | Via bhnexus (Unix socket) | `/run/bos/bauth.sock` (via bhnexus) | JSON (BitMaskBundle) | 20ms (via bhnexus cache) | 0 | banexus -> bhnexus -> bauth (indirecto) |
| SBOS IAM Installer (bos) | Entrada | Filesystem | `/etc/bos/blibs/bhnexus/devices/<node_id>.yml` | YAML v1.2 | N/A (lectura local) | 0 | bos -> filesystem -> banexus |
| SBOS Data Kernel (bkernel) | Salida | PostgreSQL WAL | Tabla audit_events en bhnexus_db | WAL pgoutput | N/A (async) | 0 | banexus -> PostgreSQL -> bkernel WAL |
| Lectores USB QR/NFC | Entrada | USB HID (libusb) | `/dev/bus/usb/` (raw bulk transfer) | HID reports (endpoint 0x01, 512B) | 1000ms (lectura) | 0 | USB reader -> banexus |
| NFC (ISO 14443A/B) | Entrada | NFC (libnfc) | `/dev/bus/usb/` (lector NFC) | ISO 14443A/B frames | 2000ms (lectura) | 3 (500ms, 1000ms, 2000ms) | NFC reader -> banexus |
| Escaners biometricos | Entrada | USB HID | `/dev/bus/usb/` (raw) | HID reports propietarios | 5000ms (lectura) | 2 (1000ms, 3000ms) | Biometric -> banexus |
| Teclados PIN | Entrada | USB HID | `/dev/input/event*` (evdev) | HID keyboard reports | 30000ms (lectura) | 0 | PIN pad -> banexus |
| Reles/Actuadores | Salida | RS-232 serial | `/dev/ttyUSB0` | Comandos raw (OPEN/CLOSE/TOGGLE) | 1000ms | 2 (100ms, 500ms) | banexus -> relay |
| PAM (Linux-PAM) | Entrada | PAM module | `/etc/pam.d/sudo` (auth phase) | PAM conversation | 5000ms | 0 | sudo -> pam_banexus.so -> banexus |
| udev | Entrada | Netlink socket | `udev` monitor | uevent (kernel) | N/A | 0 | udev -> banexus |

## Seccion 2: Contratos de Integracion

### INT-BANEXUS-001: Conexion WebSocket con bhnexus

**Endpoint:** `wss://<host>:9444/ws`
**Protocolo:** WebSocket sobre mTLS. Certificado cliente firmado por CA SBOS interna.
**Reconexion:** Backoff progresivo: 1s, 5s, 15s, 30s, 60s (max).
**Heartbeat:** cada 15s desde banexus.

**Flujo de conexion:**
1. banexus lee config de `/etc/bos/blibs/bhnexus/devices/<node_id>.yml`
2. Resuelve `host_url` del device.yml (ej: `wss://sbos-server:9444`)
3. Carga certificado TLS desde `/etc/banexus/tls/agent.crt` y key
4. Inicia handshake WSS con mTLS (verificacion mutua de certificados)
5. bhnexus verifica SPIFFE ID del certificado contra device.yml
6. Conexion establecida: estado CONNECTED
7. Inicia envio de heartbeats cada 15s
8. Si desconexion: backoff reconexion, mantiene cache local para operacion offline

**Frame type: auth_request (banexus -> bhnexus):**
```json
{
  "type": "auth_request",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "payload": "sbos://auth/0123456789ABCDEF",
  "hmac": "sha256-hex-de-payload-con-clave-compartida",
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

**Cache offline local:**
- Algoritmo: AES-256-GCM sobre disco local
- Clave: derivada del certificado mTLS (HMAC-SHA256(cert_der, "banexus-cache-key"))
- TTL maximo offline: 4 horas
- Al reconectar: bhnexus envia policy_update para invalidar usuarios modificados
- En caso de denegacion por cache expirado + sin conexion: DENY (fail-secure)

### INT-BANEXUS-002: Captura USB HID (Input Hooking Manager)

**Dispositivos soportados:**

| Tipo | Interfaz | Buffer | Formato de payload |
|---|---|---|---|
| QR | USB HID (keyboard wedge) | 512 bytes (endpoint 0x01) | String plano o URI `sbos://auth/...` |
| NFC (ISO 14443A) | USB CCID / libnfc | 256 bytes (APDU) | UID de tarjeta (hex) |
| NFC (ISO 14443B) | USB CCID / libnfc | 256 bytes (APDU) | UID de tarjeta (hex) |
| Biometrico | USB HID propietario | 1024 bytes | Template miner (propietario) |
| PIN pad | USB HID keyboard | 8 bytes (tecla a tecla) | PIN cifrado (Dukpt o similar) |

**Flujo de captura QR:**
1. udev detecta insercion de lector USB en `/dev/bus/usb/`
2. Regla `99-banexus.rules` asigna grupo `banexus`, permisos 0660
3. banexus Input Hooking Manager abre dispositivo via libusb
4. Claim interface, detach kernel driver (si aplica)
5. Bulk transfer en endpoint 0x01 -> buffer 512 bytes
6. Parse payload: extrae URI `sbos://auth/{token}` o raw data
7. Construye struct `Credential { Type, Raw, Parsed, Hash }`
8. Si es QR: parsea payload como URI `sbos://auth/...` y extrae token
9. Construye auth_request con input_type="qr" y payload extraido
10. Firma mensaje con HMAC (clave derivada de cert mTLS)
11. Envia a bhnexus via WebSocket

**Captura ANTES de evdev:** banexus usa libusb para capturar el raw USB antes de que
el kernel lo convierta en evento de teclado (evdev). Esto previene:
- Keyloggers del sistema operativo
- Inyeccion de teclado maliciosa
- Intercepcion por procesos no autorizados

### INT-BANEXUS-003: Shell Sentinel via PAM

**Modulo:** `pam_banexus.so`
**Fase:** `auth` (se ejecuta ANTES de la verificacion de contrasena)
**Ubicacion:** `/etc/pam.d/sudo`, `/etc/pam.d/login`

```bash
# /etc/pam.d/sudo
auth       requisite    pam_banexus.so
auth       include      system-auth
account    include      system-auth
session    include      system-auth
```

**Comandos sensibles interceptados:**
- `apt-get`, `dnf`, `yum`, `apk` (instalacion de paquetes)
- `systemctl start/stop/restart` (gestion de servicios)
- `rm -rf /*`, `rm -rf /`, `rm -rf /etc` (destruccion del sistema)
- `sudo su`, `sudo -i`, `su -` (escalada de privilegios)
- `chmod 777`, `chown -R` (cambio masivo de permisos)
- `passwd root`, `passwd <usuario>` (cambio de contrasenas)
- `ufw disable`, `iptables -F`, `nft flush ruleset` (desactivar firewall)

**Flujo de decision:**
1. Usuario ejecuta `sudo apt-get install nginx`
2. PAM invoca `pam_banexus.so` en fase auth (configurado como `requisite`)
3. pam_banexus.so extrae el comando del entorno PAM
4. Si el comando esta en lista de sensibles: continua, si no: OK (delegar a system-auth)
5. pam_banexus.so envia consulta a banexus daemon via D-Bus o Unix socket local
6. banexus construye auth_request con input_type="shell_sentinel"
7. banexus envia a bhnexus via WebSocket, bhnexus consulta bauth
8. bhnexus responde: si BitMask tiene bit SHELL_SENTINEL_PASS -> permitir, si no -> denegar
9. Cache local: si timeout o sin conexion -> DENY (fail-secure), a menos que cache local tenga permiso vigente
10. pam_banexus.so retorna PAM_SUCCESS o PAM_AUTH_ERR

**Timeout PAM:** 5000ms. Si no hay respuesta en 5s -> DENY.

### INT-BANEXUS-004: Control de Actuadores (Reles/RS-232)

**Puerto:** `/dev/ttyUSB0` (configurable en banexus.toml)
**Protocolo:** RS-232 serial, 9600 baud, 8N1.
**Timeout:** 1000ms por comando.

**Comandos soportados:**
| Comando | Payload | Efecto |
|---|---|---|
| `OPEN` | `RELAY_01` | Activar rele por duracion configurada |
| `CLOSE` | `RELAY_01` | Desactivar rele inmediatamente |
| `TOGGLE` | `RELAY_01` | Invertir estado del rele |
| `STATUS` | `RELAY_01` | Consultar estado del rele |
| `OPEN_TIMED` | `RELAY_01:5000` | Activar rele por 5000ms, luego auto-close |

**Ejecucion segura:**
- Todo `OPEN` tiene auto-close via `time.AfterFunc` en Go
- Si el relay no se cierra en el tiempo especificado, banexus envia CLOSE forzado
- En caso de error de puerto serie: reintentar 2 veces (100ms, 500ms), si falla -> log CRITICAL

## Seccion 3: Matriz de Dependencias

| Dependencia | Criticidad | Sin esto... |
|---|---|---|
| bhnexus (WebSocket) | OBLIGATORIO | Sin comunicacion con el host central. Operacion offline limitada a cache local |
| Filesystem device config | OBLIGATORIO | Sin configuracion de nodo. banexus no sabe que es ni a donde conectarse |
| Certificados TLS (mTLS) | OBLIGATORIO | Sin autenticacion mutua. No puede conectar con bhnexus |
| Lectores USB | OBLIGATORIO | Sin captura de credenciales. banexus no tiene proposito primario |
| Reles/Actuadores | OBLIGATORIO | Sin ejecucion fisica. Autenticacion sin apertura de puertas |
| udev | OBLIGATORIO | Sin deteccion de dispositivos. No sabe cuando se conecta/desconecta un lector |
| PAM module | OPCIONAL | Sin Shell Sentinel. Proteccion de comandos no disponible |
| Teclados PIN | OPCIONAL | Sin autenticacion backup. QR/NFC disponibles |
| Escaners biometricos | OPCIONAL | Sin autenticacion biometrica. QR/PIN disponibles |
| bhnexus cache | OPCIONAL | Las decisiones se toman en bauth en vez de cache. Latencia ~15ms en vez de ~1ms |
| PostgreSQL | INDIRECTO | banexus no escribe directamente. Lo hace via WAL de bhnexus_db |

## Seccion 4: Propagacion de Contexto

banexus recibe ctx_id de:
1. **Interno (generado)**: banexus genera un ctx_id (UUID v7) para cada evento de autenticacion
   que inicia. El ctx_id nace en el momento en que el usuario presenta una credencial al lector.
2. **Indirecto**: cuando Shell Sentinel intercepta un comando, el ctx_id lo genera banexus.

banexus propaga el ctx_id a:
- **bhnexus** (WebSocket): campo `ctx_id` en el frame `auth_request`
- **Cache local**: asociado al entry de cache como `(user_id, ctx_id, bitmask, timestamp)`
- **Logs locales**: campo `ctx_id` en syslog y log de eventos
- **PAM module**: devuelve el ctx_id como variable de entorno `BOS_CTX_ID` al proceso pam_exec

**Formato:** `UUID v7` plano (generado localmente) o W3C Trace Context si se recibe de una
fuente externa (ej: Core UI inicia una autenticacion con ctx_id preexistente).

**Ciclo de vida del ctx_id en una autenticacion fisica:**
```
1. Usuario presenta QR al lector USB
2. banexus genera ctx_id = UUID v7
3. banexus construye auth_request con ctx_id
4. banexus -> WebSocket -> bhnexus
5. bhnexus -> Unix socket -> bauth (con ctx_id)
6. bauth evalua, propaga ctx_id a Keycloak (X-Ctx-Id)
7. bhnexus responde auth_response con traceparent W3C
8. banexus ejecuta actuator_commands
9. banexus registra en log: { "event": "auth_granted", "ctx_id": "...", "user": "...", "node": "..." }
```

**Registro de eventos de auditoria:**
```json
{
  "event": "auth_request",
  "timestamp": "2026-05-27T10:00:00.000Z",
  "ctx_id": "0195f8a5-1234-7000-b000-000000000001",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "credential_hash": "sha256-de-la-credencial",
  "result": "granted",
  "latency_ms": 15
}
```

---

*Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS3, SS5-6, V5-SS2-3, V7-SS5, V7-SS7. Investigation SS10 — OSDP v2.2, SS1 — W3C Trace Context.*
