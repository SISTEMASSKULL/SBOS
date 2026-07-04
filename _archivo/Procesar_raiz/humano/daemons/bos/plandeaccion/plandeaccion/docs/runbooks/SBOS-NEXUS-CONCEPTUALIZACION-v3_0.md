# SBOS — NEXUS: Sovereign Connectivity Broker & Edge Sentinel
## Conceptualización Definitiva · bhnexus + banexus
### SKULL · SBOS — Sovereign Business Operating System
### v3.0 · Abril 2026

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-NEXUS-CONCEPTUALIZACION |
| **Versión** | 3.0 (definitiva — reemplaza v1.0, v2.0) |
| **Estado** | ACTIVO |
| **Daemons** | `bhnexus` (host) + `banexus` (agente) |
| **Lenguaje** | Go 1.22+ (ambos) |
| **Documentos base** | SBOS-035-NEXUS-HOST-v1_0, SBOS-036-NEXUS-AGENT-v1_0 |

**Reemplaza:** SBOS-NEXUS-CONCEPTUALIZACION v1.0 y v2.0.
**Integra:** árbol físico de 11 niveles, HAL multi-protocolo, decisiones R-P4, R-Gap6, todas las decisiones de sesión Febrero–Abril 2026.

---

## TABLA DE CONTENIDOS

1. El Par NEXUS como Unidad Soberana
2. Definición Canónica de bhnexus
3. Definición Canónica de banexus
4. La Topología Invariable
5. El Flujo Soberano Completo
6. Arquitectura Interna de bhnexus
7. Arquitectura Interna de banexus
8. El Protocolo WebSocket bhnexus ↔ banexus
9. La HAL — Hardware Abstraction Layer
10. El Árbol Jerárquico de Ubicaciones Físicas
11. Las Device Fichas
12. El Cache de bhnexus y el Cache Efímero de banexus
13. Comportamiento Offline y Fail-Secure
14. Flujos por Tipo de Credencial
15. Flujo de Política: Cuando el RolTemplate Cambia
16. Monitoreo, Alertas y Auto-Recuperación
17. Configuración (bhnexus.toml y banexus.toml)
18. Lo que NEXUS ES y NO ES
19. Posicionamiento en los 8 Daemons Soberanos

---

## 1. EL PAR NEXUS COMO UNIDAD SOBERANA

NEXUS no es un solo daemon — es una **unidad compuesta de dos daemons** que operan como una sola entidad funcional: el Sovereign Connectivity Broker (bhnexus, en el host) y el Edge Sentinel (banexus, en cada nodo Fedora o controlador de puerta).

```
┌─────────────────────────────────────────────────────────────┐
│                  NEXUS como unidad                           │
│                                                             │
│  ┌──────────────────────┐   mTLS   ┌────────────────────┐  │
│  │       banexus        │◄────────►│      bhnexus       │  │
│  │   (Edge Sentinel)    │ WebSocket │ (Connectivity      │  │
│  │                      │          │  Broker)           │  │
│  │  • Intercepta USB    │          │  • Router central  │  │
│  │  • Shell sentinel    │          │  • Auth cache      │  │
│  │  • Activa actuadores │          │  • Hardware Bridge │  │
│  │  • Cache efímero     │          │  • Consulta bAuth  │  │
│  └──────────────────────┘          └────────┬───────────┘  │
│         (nodo Fedora)                        │ Unix socket  │
│                                             ▼              │
│                                    ┌────────────────────┐  │
│                                    │       bAuth        │  │
│                                    │  (fuente de verdad │  │
│                                    │   de identidad)    │  │
│                                    └────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**La misión conjunta:** interceptar TODO evento de credencial física antes de que el SO lo procese, resolverlo contra bAuth, y ejecutar las acciones autorizadas (liberar shell, activar actuadores) de forma atómica y en menos de 50ms.

---

## 2. DEFINICIÓN CANÓNICA DE BHNEXUS

**Nombre formal:** SBOS Nexus Host — Sovereign Connectivity Broker & Multiprotocol Gateway

**Daemon:** `bhnexus` — servicio de sistema en el host Ubuntu 24.04 LTS

**Lenguaje:** Go 1.22+ (10.000+ conexiones WebSocket concurrentes con ~20–40 MB RAM)

### Lo que bhnexus PUEDE hacer

- **Router central:** todo tráfico de credenciales físicas del SBOS pasa por bhnexus. Es el único componente autorizado a consultar bAuth sobre eventos de acceso físico.
- **Auth Cache:** SAM-128 en memoria con TTL 30s. Cache hit = respuesta a banexus sin consultar bAuth. Cache miss = consulta Unix socket a bAuth.
- **Hardware Bridge:** traduce protocolos industriales (OSDP v2, MQTT, ONVIF, HTTP) a CredentialEvent normalizado. No modifica firmware de dispositivos.
- **Multi-destino:** envía el SAM-128 al shell de Fedora Y los comandos de actuación (OPEN_RELAY) a las controladoras de puertas simultáneamente, en el mismo frame de respuesta.
- **Distribuidor de políticas:** cuando bAuth actualiza un RolTemplate, bhnexus recibe el push y propaga la invalidación de cache a todos los banexus afectados.

### Lo que bhnexus NO PUEDE hacer

```
✗ Procesar lógica de negocio (impuestos, inventarios, contabilidad)
✗ Almacenar templates biométricos (es un negociador de tránsito)
✗ Autenticación primaria (eso es Keycloak — bhnexus solo verifica privilegios)
✗ Comunicarse directamente con Keycloak o Tryton
✗ Crear o modificar RolTemplates o UserTemplates
✗ Operar sin bAuth (si bAuth está caído, opera con cache hasta expiración TTL)
```

---

## 3. DEFINICIÓN CANÓNICA DE BANEXUS

**Nombre formal:** SBOS Nexus Agent — Edge Sentinel & Multi-Input Interceptor

**Daemon:** `banexus.service` — systemd --user en cada nodo Fedora

**Lenguaje:** Go 1.22+ binario estático (sin dependencias de runtime en el contenedor)

**Carácter:** monogámico — ignora todo tráfico que no provenga del bhnexus verificado por certificado mTLS.

### Lo que banexus PUEDE hacer

- **Input Hooking:** captura señales USB/serial (QR, NFC, código de barras) a nivel de bus vía udev rules + libusb, ANTES de que el dato llegue al sistema de input de Fedora.
- **Shell Sentinel:** intercepta comandos shell sensibles vía PAM module (`pam_banexus.so`), congela la ejecución, consulta a bhnexus, y libera o bloquea según la respuesta.
- **Control de Actuadores:** ejecuta apertura de relés (puertas, cajones) via serial/GPIO tras recibir orden firmada de bhnexus.
- **Cache Efímero:** almacena copia AES-256-GCM de la última política recibida para operar durante desconexiones temporales.
- **Auto-Verificación de Integridad:** calcula SHA-256 de su propio binario cada 5 minutos. Si hay discrepancia → alerta crítica a bhnexus + auto-shutdown.

### Lo que banexus NO PUEDE hacer

```
✗ Gestión de identidad (SSO) — sin contacto con Keycloak
✗ Crear permisos nuevos — solo valida los recibidos
✗ Comunicarse directamente con bAuth — siempre vía bhnexus
✗ Almacenar datos biométricos — solo captura y reenvía el hash
✗ Comunicarse con más de un bhnexus — monogámica por diseño
```

---

## 4. LA TOPOLOGÍA INVARIABLE

```
                    banexus
                       │
                 WebSocket mTLS
                       │
                    bhnexus
                       │
                  Unix socket
                       │
                     bAuth

NUNCA:
  banexus → bAuth          (saltar bhnexus = perder routing y cache)
  dispositivo → bhnexus    (saltar banexus = perder interceptación soberana)
  dispositivo → bAuth      (saltar ambos = perder todo el control)
  banexus → KC             (no existe este canal)
  banexus → Tryton         (no existe este canal)
```

**Justificación de la topología:** Sin banexus no hay interceptación del evento USB/serial antes del SO. Sin bhnexus no hay cache, routing, ni distribución del SAM. Si cualquier dispositivo pudiera hablar directamente con bAuth, se rompe la cadena de custodia del evento de autenticación física.

---

## 5. EL FLUJO SOBERANO COMPLETO

El "Flujo Soberano" es el caso de uso estrella que demuestra la coordinación de los 3 daemons (banexus + bhnexus + bAuth) y la ejecución física atómica en menos de 50ms.

### Flujo 1 — QR en terminal Fedora (vendedor abre caja)

```
T+0.000s  Vendedor presenta QR al lector USB de la terminal Fedora

T+0.001s  banexus: udev intercepta datos del bus USB
          ANTES de que evdev los pase al sistema de input de Fedora
          banexus firma el payload: HMAC-SHA256(secret, payload+timestamp)

T+0.002s  banexus → bhnexus (WebSocket mTLS):
          {
            "type": "auth_request",
            "request_id": "uuid-req",
            "node_id": "Ventas-01",
            "input_type": "qr",
            "payload": "sbos://auth/user-uuid/1713000000/hmac...",
            "timestamp": "2026-04-15T10:30:00Z"
          }

T+0.005s  bhnexus: identifica nodo "Ventas-01"
          Verifica estructura del QR: sbos://auth/{user_id}/{ts}/{hmac}
          Verifica: timestamp < 30s ago AND HMAC válido

T+0.006s  bhnexus: ¿SAM-128 en cache para user-uuid @ Ventas-01?
          SÍ (TTL no expirado) → T+0.007s: SAM del cache
          NO → consulta bAuth via Unix socket

T+0.008s  bhnexus → bAuth (Unix socket):
          {
            "user_id": "user-uuid",
            "node_id": "Ventas-01",
            "query_type": "bitmask"
          }

T+0.010s  bAuth evalúa (RolTemplate del usuario):
          Dominio lógico:    red 10.0.1.45 ∈ 10.0.1.0/24 ✓
                             hora 10:30 ∈ 08:00-18:00 ✓
                             LoA 2 (pwd+OTP) suficiente ✓
          Dominio físico:    nodo "Ventas-01" ∈ zone_ventas ✓
                             security_level=2 OK ✓
          Dominio financiero: limit_tier=2 (10.000 BOB) ✓

T+0.012s  bAuth retorna SAM-128:
          {
            "granted": true,
            "sam128": "0x0000010900000300 0001001700010052",
            "ttl_seconds": 28800,
            "actuator_commands": [
              {"target": "RELAY_01", "action": "OPEN", "duration_ms": 5000}
            ]
          }

T+0.013s  bhnexus: almacena SAM en cache (TTL 30s)

T+0.014s  bhnexus → banexus (WebSocket):
          {
            "type": "auth_response",
            "request_id": "uuid-req",
            "status": "granted",
            "sam128": "0x0000010900000300 0001001700010052",
            "user_name": "Ivan Cajero",
            "ttl_seconds": 28800,
            "actuator_commands": [
              {"target": "RELAY_01", "action": "OPEN", "duration_ms": 5000}
            ]
          }

T+0.015s  banexus ejecuta en PARALELO (atómico):
          1. LOG_SHELL_UNLOCK (bit 17) = 1
             → PAM libera el login de Fedora
             → KDE Plasma aparece con perfil del usuario
          2. FIN_CAJA_OPEN via RELAY_01
             → Serial: envía comando OPEN al relé
             → Cajón de dinero se abre físicamente
          3. banexus almacena SAM en cache efímero (AES-256-GCM)

LATENCIA TOTAL: ~15ms
OBJETIVO: < 50ms
```

### Flujo 2 — Huella dactilar en puerta sala de servidores

```
T+0.000s  Técnico de TI presenta dedo en lector OSDP v2

T+0.001s  Lector OSDP (Biometric Profile):
          → Sensor captura imagen dactilar
          → Template extraído LOCALMENTE en el chip del lector
          → Template convertido a hash LOCALMENTE
          → Hash enviado por canal OSDP Secure (AES) al controlador

T+0.002s  bhnexus (OSDP driver): recibe paquete OSDP
          → Normaliza a CredentialEvent:
          {
            "type": "auth_request",
            "input_type": "fingerprint_hash",
            "payload": "<hash_cifrado>",
            "device_id": "PHY_DEV_FP_SALA_SERV",
            "location_id": "PHY_AP_SALA_SERV_PUERTA"
          }

T+0.006s  bhnexus → bAuth (Unix socket):
          {
            "query_type": "biometric",
            "payload_hash": "<hash>",
            "device_id": "PHY_DEV_FP_SALA_SERV"
          }

T+0.008s  bAuth:
          → Descifra payload con clave de Vault
          → Verifica hash contra bauth_biometric_templates
          → Match: user_id = "tech-uuid"
          → Evalúa RolTemplate:
            security_level requerido por PHY_SALA_SERV = 3 (restringido)
            GOV_LOA_LEVEL = 0100 (LoA 3, biométrico) ✓
            PHY_ZONE_D activo (sala servidores) ✓
            Horario 10:05 ∈ 08:00-18:00 ✓

T+0.010s  bAuth retorna SAM con GOV_LOA_LEVEL = LoA 3
          + actuator: LOCK_SALA_SERV: OPEN (5 segundos)

T+0.011s  bhnexus → OSDP driver:
          SendCommand(LOCK_SALA_SERV, OPEN, 5000ms)

T+0.012s  Puerta sala servidores se abre

LATENCIA TOTAL: ~12ms
NINGÚN DATO BIOMÉTRICO salió del chip del lector hacia ningún servidor.
Solo el HASH viajó. RGPD compliant.
```

### Flujo 3 — Shell Sentinel (comando sensible en terminal)

```
Técnico intenta ejecutar: sudo dnf install <paquete>

PAM module pam_banexus.so intercepta:
  → banexus recibe: {type: "shell_auth", command: "dnf install", user: "ivan"}
  → banexus → bhnexus → bAuth (consulta LOG_EXECUTE bit 4)
  → bAuth: LOG_EXECUTE = 0 para este usuario en este nodo

bhnexus → banexus: {status: "denied", reason: "insufficient_privileges"}

PAM module:
  → Bloquea el comando
  → Notifica al usuario: "Acción no autorizada. Contacte al administrador."
  → Log en bkernel_db.audit_events

Si LOG_EXECUTE = 1 (técnico de TI con permisos):
  → PAM libera el comando → ejecuta normalmente
```

---

## 6. ARQUITECTURA INTERNA DE BHNEXUS

```
┌──────────────────────────────────────────────────────────────┐
│                     bhnexus (Go)                             │
│                                                              │
│  ┌─────────────────┐  ┌──────────────────────────────────┐  │
│  │  WebSocket       │  │      Hardware Bridge             │  │
│  │  Manager         │  │                                  │  │
│  │                  │  │  ┌──────────┐  ┌──────────────┐  │  │
│  │  Agents[]        │  │  │ OSDP v2  │  │ MQTT 5.0     │  │  │
│  │  (banexus nodes) │  │  │ Driver   │  │ Driver       │  │  │
│  │                  │  │  └──────────┘  └──────────────┘  │  │
│  │  10.000+         │  │  ┌──────────┐  ┌──────────────┐  │  │
│  │  conexiones WS   │  │  │ ONVIF    │  │ HTTP/REST    │  │  │
│  └────────┬─────────┘  │  │ Driver   │  │ Driver       │  │  │
│           │            │  └──────────┘  └──────────────┘  │  │
│           │            │  ┌──────────┐                     │  │
│           │            │  │ Wiegand  │  DeviceFichas[]     │  │
│           │            │  │ Adapter  │  (YAML en /etc/)    │  │
│           │            │  └──────────┘                     │  │
│           │            └──────────────────────────────────┘  │
│           │                           │                      │
│  ┌────────▼───────────────────────────▼────────────────────┐ │
│  │              Request Router                              │ │
│  │   Identifica nodo + tipo de solicitud + device_id        │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                                 │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              Auth Cache (in-memory)                      │ │
│  │   SAM-128 por (user_id, node_id)                        │ │
│  │   TTL: 30s configurable │ Max entries: 10.000            │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                      cache miss │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              bAuth Client                                │ │
│  │   Unix socket /run/bos/bauth.sock                       │ │
│  │   Latencia < 5ms │ Timeout: 1s │ Retry: 3 intentos       │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                                 │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              Response Dispatcher                         │ │
│  │   → SAM-128 + user_name al agente banexus                │ │
│  │   → actuator_commands al driver de hardware              │ │
│  │   → Ambos enviados en el mismo frame (atomicidad)        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Policy Dispatcher                           │ │
│  │   Recibe policy_update de bAuth                         │ │
│  │   Invalida cache de SAM afectados                       │ │
│  │   Envía invalidación a banexus afectados                │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. ARQUITECTURA INTERNA DE BANEXUS

```
┌──────────────────────────────────────────────────────────────┐
│              banexus (Go — systemd --user en Fedora)          │
│                                                              │
│  ┌────────────────────────┐  ┌─────────────────────────────┐ │
│  │  WebSocket Client       │  │  Input Interceptor           │ │
│  │  (mTLS a bhnexus)       │  │                             │ │
│  │                         │  │  udev rules → /dev/banexus/ │ │
│  │  Reconexión:            │  │  libusb → captura raw data  │ │
│  │  backoff exp.           │  │  ANTES de evdev             │ │
│  │  1→5→15→30→60s max      │  └─────────────┬───────────────┘ │
│  └────────────┬────────────┘                │               │
│               │                             │               │
│  ┌────────────▼─────────────────────────────▼─────────────┐ │
│  │              Event Normalizer                          │ │
│  │   Raw USB/serial → CredentialEvent{type, payload}      │ │
│  └──────────────────────────────┬──────────────────────────┘ │
│                                 │                            │
│  ┌──────────────────────────────▼──────────────────────────┐ │
│  │              Policy Cache (efímero)                     │ │
│  │   AES-256-GCM con clave derivada del certificado mTLS   │ │
│  │   TTL igual al SAM recibido de bhnexus                  │ │
│  │   Si TTL expirado → DENY todo (fail-secure)             │ │
│  └──────────────────────────────┬──────────────────────────┘ │
│                                 │                            │
│  ┌────────────────┬─────────────┘                            │
│  │                │                                          │
│  ▼                ▼                                          │
│  Shell Sentinel   Actuator Controller                        │
│  PAM module       serial/GPIO                                │
│  freeze→consult   RELAY_ON/OFF                               │
│  →release/deny    timer auto-close                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Integrity Monitor                           │ │
│  │   SHA-256(/opt/banexus/banexus) cada 5 min              │ │
│  │   vs /etc/banexus/banexus.sha256                        │ │
│  │   Discrepancia → alerta crítica + auto-shutdown          │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. EL PROTOCOLO WEBSOCKET BHNEXUS ↔ BANEXUS

### Conexión (mTLS obligatorio)

```
banexus → bhnexus: WSS upgrade
  Headers:
    X-Node-ID: "Ventas-01"
    X-Agent-Version: "1.0.0"
    X-Agent-Cert-Fingerprint: "sha256:abc123..."

bhnexus verifica:
  1. Certificado mTLS válido (CA interna del SBOS)
  2. Node-ID registrado en nodes.yml
  3. Versión del agente compatible (semver)
  4. Cert fingerprint contra registro de nodos

SI OK  → conexión establecida, agente en Agents[]
SI FAIL → 403 Forbidden + log de intento + alerta Wazuh
```

### Frames de Comunicación

```json
// banexus → bhnexus: solicitud de autorización
{
  "type": "auth_request",
  "request_id": "uuid-v4",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "payload": "sbos://auth/user-uuid/1713000000/hmac...",
  "device_id": "PHY_DEV_QR_ZV_PUERTA_PRIN",
  "timestamp": "2026-04-15T10:30:00Z"
}

// bhnexus → banexus: respuesta autorizada
{
  "type": "auth_response",
  "request_id": "uuid-v4",
  "status": "granted",
  "sam128": "0x0000010900000300 0001001700010052",
  "user_id": "user-uuid",
  "user_name": "Ivan Cajero",
  "ttl_seconds": 28800,
  "actuator_commands": [
    { "target": "RELAY_01", "action": "OPEN", "duration_ms": 5000 }
  ],
  "timestamp": "2026-04-15T10:30:00.015Z"
}

// bhnexus → banexus: respuesta denegada
{
  "type": "auth_response",
  "request_id": "uuid-v4",
  "status": "denied",
  "reason": "outside_schedule",
  "message": "Acceso fuera de horario autorizado (08:00–18:00)",
  "timestamp": "2026-04-15T20:15:00Z"
}

// bhnexus → banexus: push de invalidación de política
{
  "type": "policy_update",
  "reason": "roltemplate_changed",
  "affected_users": ["user-uuid-1", "user-uuid-2"],
  "action": "invalidate_cache",
  "timestamp": "2026-04-15T11:00:00Z"
}

// banexus → bhnexus: heartbeat (cada 30s)
{
  "type": "heartbeat",
  "node_id": "Ventas-01",
  "uptime_seconds": 86400,
  "active_sessions": 2,
  "cache_entries": 3,
  "last_auth_ts": "2026-04-15T10:30:00Z",
  "integrity_ok": true
}

// banexus → bhnexus: solicitud shell sentinel
{
  "type": "shell_auth",
  "node_id": "Ventas-01",
  "user": "ivan.cajero",
  "command": "apt-get install vim",
  "timestamp": "2026-04-15T10:35:00Z"
}
```

### Reconexión con Backoff Exponencial

```
Si WebSocket pierde conexión:
  banexus intenta reconectar:
    1s → 5s → 15s → 30s → 60s (máximo, repite cada 60s)

Durante desconexión:
  banexus opera con cache efímero
  Si SAM en cache y TTL vigente → responde localmente
  Si TTL expirado → DENY todo (fail-secure)

Al reconectar:
  banexus envía heartbeat con actividad offline
  bhnexus envía policy_update si hubo cambios
  banexus invalida cache y recibe SAM fresco
```

---

## 9. LA HAL — HARDWARE ABSTRACTION LAYER

### El Principio

**Agregar un dispositivo al SBOS es declarativo — no requiere código.**

Si el protocolo del dispositivo ya está soportado → solo necesita una device ficha YAML.
Si el protocolo es nuevo → se agrega un driver Go (.so) sin modificar el núcleo de bhnexus.

### La Interfaz DeviceDriver

```go
// Interfaz que todo driver implementa
type DeviceDriver interface {
    Protocol()    string                              // "osdp_v2", "mqtt", etc.
    Connect(params ConnectionParams) error
    Listen(ctx context.Context, out chan<- CredentialEvent) error
    SendCommand(cmd ActuatorCommand) error
    HealthCheck() DeviceHealth
    Disconnect() error
}

// CredentialEvent — el lenguaje universal de la HAL
// Todos los drivers producen este tipo, sin excepción
type CredentialEvent struct {
    EventID        string         // UUID único
    Timestamp      time.Time
    DeviceID       string         // "PHY_DEV_QR_ZV_PUERTA_PRIN"
    LocationID     string         // "PHY_AP_ZV_PUERTA_PRIN"
    NodeID         string         // "Ventas-01"
    CredentialType CredentialType // QR_DYNAMIC|NFC_MIFARE_DESFIRE|FINGERPRINT_HASH|...
    Payload        []byte         // cifrado con clave de Vault
    Direction      string         // "ENTRY" | "EXIT"
    RawProtocol    string         // para audit: "osdp_v2", "wiegand", etc.
}
```

### Drivers Incluidos en bhnexus v1.0

| Driver | Protocolo | Dispositivos típicos | Seguridad |
|---|---|---|---|
| `osdp_driver.go` | OSDP v2.2.2 (SIA/IEC 60839-11-5) | Lectores NFC, RFID, biométrico, teclados | ✅ AES cifrado, bidireccional |
| `wiegand_adapter.go` | Wiegand 26/34/37-bit | Lectores legacy (40+ años) | ⚠️ Sin cifrado — solo legacy |
| `mqtt_driver.go` | MQTT 5.0 | IoT, sensores, actuadores industriales | ✅ TLS, QoS configurable |
| `onvif_driver.go` | ONVIF Profile S/T | Cámaras IP de seguridad | ✅ HTTPS, auth digest |
| `usb_hid_driver.go` | USB HID (en banexus) | Lectores QR USB, NFC USB (ACR122U) | ✅ Local a banexus |
| `http_driver.go` | REST HTTPS | Terminales POS, interfonos IP, kioskos | ✅ TLS, flexible |

### Tipos de Credencial Soportadas

| Tipo | Protocolo habitual | Seguridad | LoA otorgado |
|---|---|---|---|
| `QR_DYNAMIC` | USB HID / OSDP Basic | Alto (HMAC-SHA256, TTL 30s) | 1–2 |
| `NFC_MIFARE_DESFIRE` | OSDP Smart Card | Alto (AES-128) | 2 |
| `NFC_MIFARE_CLASSIC` | RFID 13.56 MHz | Medio (clonable) | 1 |
| `RFID_125KHZ` | Wiegand / RS-485 | Bajo (muy clonable) | 1 |
| `FINGERPRINT_HASH` | OSDP Biometric | Muy alto (hash local en chip) | 3 |
| `FACE_HASH` | OSDP Biometric / ONVIF | Muy alto | 3 |
| `IRIS_HASH` | OSDP Biometric | Máximo | 3–4 |
| `SMARTCARD_X509` | OSDP Smart Card / CCID | Máximo (PKI) | 3–4 |
| `BLE_TOKEN` | BLE 5.x | Alto (emparejamiento seguro) | 2 |
| `PIN_HASH` | OSDP Basic | Bajo (sin posesión) | 1 |

---

## 10. EL ÁRBOL JERÁRQUICO DE UBICACIONES FÍSICAS

11 niveles. Administrado desde Core UI (interfaz de bAuth). Almacenado en PostgreSQL. Sincronizado con bhnexus como location fichas YAML en `/etc/bos/blibs/bhnexus/locations/`.

```
NIVEL 0  TENANT
  → El servidor SBOS de la empresa. Límite de soberanía. No es zona física.

NIVEL 1  REGIÓN / PAÍS
  → Bolivia | Argentina | México
  → Governa: timezone, normativa fiscal, retención de logs
  → Ejemplo ID: PHY_REGION_BO

NIVEL 2  CIUDAD / MUNICIPIO
  → La Paz | Cochabamba | Santa Cruz de la Sierra
  → Ejemplo ID: PHY_CITY_LPZ

NIVEL 3  SITIO / CAMPUS
  → Dirección física específica (puede haber múltiples por ciudad)
  → Ejemplo: "PHY_SITE_LPZ_001 — Av. Camacho 1234, La Paz"
  → Governa: schedule_default, horario base del sitio

NIVEL 4  EDIFICIO / ESTRUCTURA
  → Edificio dentro del sitio
  → Ejemplo: PHY_BLDG_A, PHY_BLDG_ALMACEN, PHY_BLDG_TORRE

NIVEL 5  PLANTA / PISO     ← primer nivel con device fichas
  → Nivel vertical dentro del edificio
  → Ejemplo: PHY_FLOOR_PB (Planta Baja), PHY_FLOOR_1 (Piso 1)

NIVEL 6  ZONA / ÁREA
  → Área funcional dentro de la planta
  → Ejemplo: PHY_ZONE_VENTAS, PHY_ZONE_PROD, PHY_ZONE_ADMIN

NIVEL 7  ESPACIO / HABITACIÓN / SALA
  → Espacio delimitado dentro de una zona
  → Ejemplo: PHY_ROOM_JUNTAS, PHY_ROOM_SERVIDOR, PHY_ROOM_BOVEDA
  → security_level 3–4 para espacios críticos

NIVEL 8  PUNTO DE ACCESO
  → Apertura física entre espacios (puerta, ventana)
  → Ejemplo: PHY_AP_VENTAS_PUERTA_PRIN

NIVEL 9  CERRADURA / CONTROL
  → Mecanismo que controla el punto de acceso
  → mode: fail_secure (cierra sin poder) | fail_safe (abre sin poder)
  → REGLA: puertas de emergencia/escape SIEMPRE son fail_safe (ley)

NIVEL 10 DISPOSITIVO / LECTOR
  → El hardware que captura la credencial
  → Referencia al driver en la HAL (protocolo, connection params)
  → Ejemplo: PHY_DEV_QR_ZV_PUERTA_PRIN (lector QR OSDP v2)
```

### Herencia de Permisos en el Árbol

```
PHY_SITE_LPZ_001 (acceso al sitio completo)
  └── PHY_BLDG_A
        ├── PHY_FLOOR_P1
        │     ├── PHY_ZONE_VENTAS     ← ROL_CAJERO (security_level=2)
        │     └── PHY_ZONE_ADMIN      ← ROL_ADMIN  (security_level=2)
        └── PHY_FLOOR_P2
              └── PHY_ROOM_SERVIDORES ← ROL_IT     (security_level=3)
```

**Regla:** permiso en nivel superior cubre todos los sub-nodos. Una restricción explícita en un nivel inferior prevalece.

**SAM-128 Q2:** los bits representan `security_level` (1=público, 2=empleados, 3=restringido, 4=crítico). La location ficha resuelve `zone_id → security_level`. banexus evalúa O(1) sin conocer la semántica de la jerarquía.

---

## 11. LAS DEVICE FICHAS

```yaml
# /etc/bos/blibs/bhnexus/devices/{tenant}/{device_id}.yml
# Patrón universal para cualquier dispositivo

device:
  id:          "PHY_DEV_QR_ZV_PUERTA_PRIN"
  name:        "Lector QR — Puerta Principal Zona Ventas"
  location_id: "PHY_AP_ZV_PUERTA_PRIN"   # nodo en el árbol
  type:        "reader"                   # reader|actuator|sensor|camera|combo

  protocol:    "osdp_v2"
  connection:
    transport:    "serial"               # serial|tcp|mqtt|http|usb
    host:         "192.168.1.50"
    baud_rate:    9600
    osdp_address: 1
    osdp_security: true                  # OSDP Secure Channel (AES)

  credential_types:
    - type: "qr_dynamic"
      min_loa: 1
    - type: "nfc_mifare_desfire"
      min_loa: 2

  actuators:
    - id:              "PHY_LOCK_ZV_PUERTA_PRIN"
      type:            "door_lock"
      mode:            "fail_secure"
      open_duration_ms: 5000

  anti_passback:
    enabled: true
    mode:    "hard"           # hard (deny) | soft (alert)
    reset_hours: 24

  two_person_rule:
    enabled: false            # true para bóvedas, data centers

  mantrap:
    enabled: false            # true para zonas de altísima seguridad

  health:
    check_interval_seconds: 30
    check_command: "osdp_poll"
    offline_policy: "fail_secure"

  enabled: true
```

### Cómo Agregar un Dispositivo Nuevo

```
CASO 1: Protocolo ya soportado (OSDP, Wiegand, MQTT, ONVIF, USB, HTTP)
  1. Crear location ficha (YAML) — nodo en el árbol
  2. Crear device ficha (YAML) — protocolo + connection params
  3. bos recarga configuración: bhnexus SIGHUP
  4. Dispositivo activo en < 30 segundos
  → SIN código, SIN compilación, SIN reinicio

CASO 2: Protocolo nuevo no soportado
  1. Implementar driver Go que implemente DeviceDriver interface
  2. Compilar como plugin Go (.so)
  3. Copiar a /etc/bos/blibs/bhnexus/drivers/
  4. Crear device ficha con el nuevo protocolo
  5. bhnexus carga driver dinámicamente
  → Código del driver, pero sin modificar el núcleo de bhnexus
```

---

## 12. EL CACHE DE BHNEXUS Y EL CACHE EFÍMERO DE BANEXUS

### bhnexus — Auth Cache (in-memory)

```
Estructura: map[(user_id, node_id)] → {SAM128, actuator_commands, expires_at}
TTL:        30 segundos (configurable por tipo de operación)
Max entries: 10.000 entradas
Eviction:   LRU al llegar al límite

Cache hit:  bhnexus responde a banexus en < 2ms (sin consultar bAuth)
Cache miss: bhnexus → bAuth (Unix socket) → respuesta en < 8ms total

Invalidación:
  - Cuando bAuth envía policy_update (RolTemplate cambiado)
  - Cuando TTL expira (automático)
  - Cuando banexus reporta evento de cierre de sesión
```

### banexus — Policy Cache Efímero

```go
type PolicyCache struct {
    UserID     string
    SAM128     SAM128
    ReceivedAt time.Time
    TTL        time.Duration
    Encrypted  []byte    // AES-256-GCM con clave derivada del cert mTLS
}

// Decisión en modo offline:
func (c *PolicyCache) Decide(bit int) (bool, error) {
    if time.Now().After(c.ReceivedAt.Add(c.TTL)) {
        return false, ErrCacheExpired  // fail-secure: DENY si TTL expirado
    }
    key := c.deriveKey()  // derivada del certificado mTLS del agente
    sam, err := c.decrypt(key)
    if err != nil { return false, err }
    return sam.HasPermission(bit), nil
}
```

---

## 13. COMPORTAMIENTO OFFLINE Y FAIL-SECURE

```
ESCENARIO: banexus pierde conexión con bhnexus

DURANTE DESCONEXIÓN:
  banexus intenta reconectar (backoff exponencial)
  Para cada evento de credencial:
    → Consulta policy cache efímero
    → Si SAM en cache Y TTL vigente → responde localmente
    → Si TTL expirado → DENY (fail-secure)

  Shell Sentinel durante desconexión:
    → Permite solo apps en offline_allowed list (okular, etc.)
    → Bloquea apps sensibles (configuración, instalación, etc.)

  Actuadores durante desconexión:
    → Puertas permanecen en último estado
    → Si lock en fail_secure → cerrada
    → Si lock en fail_safe → abierta (emergencia)

AL RECONECTAR:
  1. banexus envía heartbeat con actividad offline
  2. bhnexus: envía policy_update si hubo cambios de RolTemplate
  3. banexus: invalida todo su cache efímero
  4. banexus: solicita SAM fresco para usuarios con sesión activa

ESCENARIO: bAuth caído (bhnexus opera sin bAuth)
  bhnexus: opera con su auth cache (TTL 30s)
  Cache hit: responde normalmente
  Cache miss: error "auth_service_unavailable"
  banexus: recibe error → consulta su cache efímero → fail-secure si vencido
```

---

## 14. FLUJOS POR TIPO DE CREDENCIAL

### QR Dinámico (bAuth como emisor)

```
bAuth genera: sbos://auth/{user_uuid}/{timestamp_unix}/{HMAC-SHA256}
              HMAC calculado con: hmac_key_de_vault + user_uuid + timestamp
              TTL: 30 segundos (configurable en RolTemplate)
              Renovación: Core UI puede generar uno nuevo en cualquier momento

Validación por bhnexus:
  1. Extraer user_uuid, timestamp, hmac del URI
  2. Verificar: now() - timestamp < 30s (dentro del TTL)
  3. Recalcular HMAC con clave de Vault
  4. Comparar HMAC calculado vs HMAC recibido
  5. Si OK → consultar bAuth con user_uuid → SAM-128
```

### NFC / RFID

```
Tag NFC DESFire:
  - user_uuid cifrado con AES-128 (clave rotada cada 90 días en Vault)
  - banexus lee tag → payload cifrado → bhnexus descifra → user_uuid
  - bhnexus → bAuth: SAM-128 para user_uuid

RFID 125kHz legacy:
  - Solo card_number sin cifrado (Wiegand)
  - bhnexus busca card_number en tabla de mapeo → user_uuid
  - bhnexus → bAuth: SAM-128 para user_uuid
  - Nivel de seguridad bajo — usar solo si no hay alternativa
```

### Biométrico (hash)

```
Lector OSDP Biometric:
  1. Sensor captura imagen biométrica localmente
  2. Template extraído en el chip (enclave seguro)
  3. Hash PBKDF2-SHA256 calculado localmente
  4. Hash transmitido por OSDP Secure Channel (AES) a bhnexus
  5. bhnexus → bAuth: {query_type: "biometric", hash: "<hash>"}
  6. bAuth: compara hash vs bauth_biometric_templates
  7. Match → user_uuid → SAM-128 con GOV_LOA_LEVEL = LoA 3

INVARIANTE: raw biometric NUNCA sale del chip del lector.
            Solo el hash viaja. RGPD compliant.
```

---

## 15. FLUJO DE POLÍTICA: CUANDO EL ROLTEMPLATE CAMBIA

```
Admin modifica RolTemplate en Core UI
  ↓
bAuth sincroniza KC + Tryton (< 5 segundos)
  ↓
bAuth → bhnexus (Unix socket):
  { "type": "policy_update",
    "affected_roles": ["ROL_CAJERO"],
    "affected_users": ["user-uuid-1", "user-uuid-2"],
    "action": "invalidate_cache" }
  ↓
bhnexus:
  → Invalida SAM-128 en cache para los usuarios afectados
  → Para cada banexus que tenga usuarios afectados conectados:
      Envía: { "type": "policy_update", "affected_users": [...] }
  ↓
banexus:
  → Invalida su cache efímero para usuarios afectados
  → Próximo evento de credencial → consulta fresca a bhnexus → bAuth

TIEMPO TOTAL DESDE GUARDAR ROLTEMPLATE HASTA INVALIDACIÓN EN BANEXUS:
  < 5 segundos (objetivo)
  < 10 segundos (garantía con carga normal)
```

---

## 16. MONITOREO, ALERTAS Y AUTO-RECUPERACIÓN

### Métricas de bhnexus (Prometheus)

```
bhnexus_agents_connected         → agentes banexus conectados actualmente
bhnexus_auth_requests_total      → total de solicitudes de autorización
bhnexus_auth_cache_hits_ratio    → ratio cache hit/miss
bhnexus_bauth_latency_ms         → latencia de consultas a bAuth (p50, p95, p99)
bhnexus_hardware_devices_online  → dispositivos físicos online por protocolo
bhnexus_policy_updates_sent      → invalidaciones de cache enviadas a agentes
```

### Alertas Wazuh

| Evento | Severidad | Acción automática |
|---|---|---|
| Agente banexus desconectado > 5 min | MEDIUM | Notificar admin |
| Dispositivo físico offline > 2 min | HIGH | Notificar admin + log |
| Múltiples auth failures del mismo nodo | HIGH | Alertar + revisar |
| bAuth no responde > 3 intentos | CRITICAL | Operar con cache |
| Integridad de binario banexus comprometida | CRITICAL | Auto-shutdown + alerta |
| Auth negada a usuario con acceso previo | MEDIUM | Log para auditoría |
| Cache SAM-128 expirado en modo offline | HIGH | Notificar admin |

---

## 17. CONFIGURACIÓN

### bhnexus.toml

```toml
[server]
websocket_port = 9444
metrics_port   = 9445
tls_cert = "/etc/bos/tls/bhnexus.crt"
tls_key  = "/etc/bos/tls/bhnexus.key"
tls_ca   = "/etc/bos/tls/ca.crt"

[auth]
bauth_socket      = "/run/bos/bauth.sock"
bauth_timeout_ms  = 1000
bauth_retry_count = 3
cache_ttl_seconds = 30
cache_max_entries = 10000

[hardware]
devices_path  = "/etc/bos/blibs/bhnexus/devices/"
locations_path = "/etc/bos/blibs/bhnexus/locations/"
osdp_enabled  = true
mqtt_enabled  = true
mqtt_broker   = "localhost:1883"
onvif_enabled = false

[agents]
nodes_path                = "/etc/bos/blibs/bhnexus/nodes/"
heartbeat_interval_seconds = 30
max_idle_seconds          = 300

[metrics]
prometheus_enabled = true
```

### banexus.toml

```toml
[agent]
node_id  = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert = "/etc/banexus/tls/agent.crt"
tls_key  = "/etc/banexus/tls/agent.key"
tls_ca   = "/etc/banexus/tls/ca.crt"

[input]
intercept_usb     = true
reader_devices    = ["/dev/banexus/reader-*"]
input_timeout_seconds = 30

[shell_sentinel]
enabled           = true
sensitive_commands = ["apt-get", "dnf", "systemctl", "rm -rf", "dd"]
pam_module        = "/usr/lib64/security/pam_banexus.so"
deny_timeout_ms   = 5000

[actuators]
relay_port      = "/dev/ttyUSB0"
relay_baud_rate = 9600

[cache]
enabled                = true
max_entries            = 100
encryption_key_source  = "mtls_cert"

[offline]
default_action         = "deny_all"
offline_allowed_apps   = ["okular", "libreoffice-writer"]
reconnect_backoff_seconds = [1, 5, 15, 30, 60]

[integrity]
check_interval_seconds = 300
binary_hash_file       = "/etc/banexus/banexus.sha256"
```

---

## 18. LO QUE NEXUS ES Y NO ES

| NEXUS ES | NEXUS NO ES |
|---|---|
| El broker central de conectividad física | Un sistema de gestión de acceso físico (PACS) standalone |
| El interceptor soberano de eventos de credencial | Un sistema de vigilancia o CCTV |
| El distribuidor del SAM-128 a los nodos | Un reemplazo de Keycloak |
| El normalizador de protocolos heterogéneos (HAL) | Un almacén de templates biométricos |
| El ejecutor atómico de acciones físicas + digitales | Un sistema con lógica de negocio |
| El centinela de integridad del borde | Un sistema que toma decisiones de identidad |

---

## 19. POSICIONAMIENTO EN LOS 8 DAEMONS SOBERANOS

```
bos      → Infrastructure Provisioning & Lifecycle Orchestrator
bkernel  → Reactive Data Orchestration Engine
biedata  → Federated Batch & Compliance Exchange
bcompass → Collaborative & Federated Intelligence
bsearch  → Sovereign Federated Intelligent Search (RAG)
bauth    → Unified Identity & Permissions Orchestrator
bhnexus  → Sovereign Connectivity Broker & Multiprotocol Gateway  ← ESTE DOC
banexus  → Edge Sentinel & Multi-Input Interceptor                ← ESTE DOC

Meta-patrón SBOS:
  bos:     escuchar filesystem → detectar cambios → actuar sobre K8s
  bkernel: escuchar WAL        → detectar eventos  → actuar sobre datos
  bhnexus: escuchar agentes    → routear eventos    → actuar via bAuth
  banexus: escuchar hardware   → interceptar input  → ejecutar actuadores
```

### El Ciclo Completo de Vida de un Acceso Físico

```
RolTemplate (admin en Core UI)
  → bAuth (calcula SAM-128)
  → KC + Tryton (sincronización)
  → JWT con bos_context (login del usuario)
  → bhnexus (recibe push de política)
  → banexus (recibe invalidación de cache)
  → Usuario presenta credencial (QR/NFC/huella)
  → banexus (intercepta evento USB)
  → bhnexus (cachea SAM-128 / consulta bAuth)
  → bAuth (valida RolTemplate en tiempo real)
  → banexus (ejecuta: shell unlock + actuador)
  → bkernel (registra en audit_events)
```

---

*SKULL · SBOS · SBOS-NEXUS-CONCEPTUALIZACION · v3.0 · Abril 2026*
*Reemplaza: v1.0, v2.0*
*Integra: SBOS-035-NEXUS-HOST-v1_0, SBOS-036-NEXUS-AGENT-v1_0,*
*árbol de ubicaciones físicas, HAL multi-protocolo, todas las decisiones de sesión*
*Estándares: SIA OSDP v2.2.2 (IEC 60839-11-5), MQTT 5.0 (OASIS),*
*ONVIF Profile S/T, WebSocket RFC 6455, mTLS RFC 8446,*
*NIST SP 800-207 Device Agent/Gateway model, ISO/IEC 27001:2022 A.7*
