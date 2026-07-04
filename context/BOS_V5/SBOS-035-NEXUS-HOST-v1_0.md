# SBOS-035-NEXUS-HOST
## SBOS Nexus Host: Sovereign Connectivity Broker & Multiprotocol Gateway
### Daemon bhnexus.service · Lenguaje: Go

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

| Campo | Valor |
|-------|-------|
| **Nombre** | SBOS Nexus Host |
| **Nombre conceptual** | Sovereign Connectivity Broker & Multiprotocol Gateway |
| **Daemon** | `bhnexus` |
| **Servicio systemd** | `bhnexus.service` |
| **Lenguaje** | Go (alta concurrencia WebSocket, sin latencia crítica de CDC) |
| **Puerto WebSocket** | 9444 (mTLS) |
| **Puerto métricas** | 9445 (Prometheus) |

---

## 1. Definición Ejecutiva

### ¿Qué es?

Es el punto de terminación de comunicaciones y el negociador de enlace del ecosistema soberano. Actúa como un Proxy de Hardware Universal que centraliza señales de dispositivos industriales (lectores de huellas, chapas, cámaras) y las traduce al lenguaje de los contratos de identidad. Es el único componente que traduce un evento físico (pulso Wiegand, paquete MQTT, lectura QR) en una consulta de autorización para bauth.

### Lo que puede hacer

- **Gestión de Conexiones Persistentes (WebSocket):** Mantiene canales bidireccionales de baja latencia con cientos de agentes simultáneos. Respuesta inmediata ante cambios de permisos sin reconexiones.
- **Traductor de Eficiencia (BitMask Packaging):** Transforma políticas complejas de bauth en BitMasks de 64 bits optimizadas. Reduce ancho de banda y acelera la toma de decisiones en el edge.
- **Seguridad de Transporte (mTLS):** Exige autenticación mutua mediante certificados. Solo agentes legítimos pueden conectar.
- **Caché de Autorización Dinámica:** Almacena validaciones frecuentes en memoria para respuestas en microsegundos. TTL configurable por tipo de operación.
- **Hardware Bridge:** Escucha y normaliza protocolos industriales (OSDP, MQTT, ONVIF, SDKs) sin modificar firmware.
- **Empaquetado Multi-Destino:** Envía BitMask al shell Fedora Y comandos de actuación (OPEN_RELAY) a controladoras de puertas simultáneamente.

### Lo que NO puede hacer

- Procesar lógica de negocio (impuestos, inventarios, contabilidad)
- Almacenar templates biométricos — es un negociador de tránsito
- Autenticación primaria — eso es de Keycloak; el Nexus solo pregunta a bauth si el usuario ya autenticado tiene permiso

---

## 2. Arquitectura Interna

```
┌─────────────────────────────────────────────┐
│                 bhnexus (Go)                │
│                                             │
│  ┌──────────────┐  ┌──────────────────────┐ │
│  │  WebSocket    │  │   Hardware Bridge    │ │
│  │  Manager      │  │   (OSDP/MQTT/ONVIF) │ │
│  │              │  │                      │ │
│  │  Agents[]    │  │  DeviceFichas[]      │ │
│  └──────┬───────┘  └──────────┬───────────┘ │
│         │                     │             │
│  ┌──────▼─────────────────────▼───────────┐ │
│  │         Request Router                  │ │
│  │  Identifica nodo + tipo de solicitud    │ │
│  └──────────────┬─────────────────────────┘ │
│                 │                           │
│  ┌──────────────▼─────────────────────────┐ │
│  │         Auth Cache                      │ │
│  │  In-memory cache de BitMasks recientes  │ │
│  │  TTL: 30s (configurable)                │ │
│  └──────────────┬─────────────────────────┘ │
│                 │ cache miss                │
│  ┌──────────────▼─────────────────────────┐ │
│  │         bauth Client                    │ │
│  │  Consulta a bauth via Unix socket       │ │
│  └──────────────┬─────────────────────────┘ │
│                 │                           │
│  ┌──────────────▼─────────────────────────┐ │
│  │         Response Dispatcher             │ │
│  │  Envía BitMask a agente                 │ │
│  │  Envía actuator commands a hardware     │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 3. Protocolo WebSocket bhnexus ↔ banexus

### 3.1 Conexión

```
banexus → bhnexus: WSS upgrade con mTLS
  Headers:
    X-Node-ID: "Ventas-01"
    X-Agent-Version: "0.9.3"
    X-Agent-Cert-Fingerprint: "sha256:abc123..."
  
bhnexus verifica:
  1. Certificado mTLS válido y no revocado
  2. Node-ID registrado en /etc/bos/blibs/bhnexus/nodes/
  3. Versión del agente compatible

SI OK → conexión establecida, agente registrado en Agents[]
SI FAIL → 403 Forbidden, log de intento fallido
```

### 3.2 Frames de comunicación

```json
// banexus → bhnexus: solicitud de autorización
{
  "type": "auth_request",
  "request_id": "uuid",
  "node_id": "Ventas-01",
  "input_type": "qr",               // qr | nfc | rfid | biometric | shell_command
  "payload": "sbos://auth/user-uuid/1710412200/hmac...",
  "timestamp": "2026-03-14T10:30:00Z"
}

// bhnexus → banexus: respuesta con BitMask
{
  "type": "auth_response",
  "request_id": "uuid",
  "status": "granted",               // granted | denied | error
  "bitmask": "0x000000000003E627",
  "user_id": "user-uuid",
  "user_name": "María García",
  "ttl_seconds": 28800,              // 8 horas
  "actuator_commands": [
    { "target": "RELAY_01", "action": "OPEN", "duration_ms": 3000 }
  ],
  "timestamp": "2026-03-14T10:30:00.015Z"
}

// bhnexus → banexus: push de actualización de política
{
  "type": "policy_update",
  "node_id": "Ventas-01",
  "reason": "roltemplate_changed",
  "affected_users": ["user-uuid-1", "user-uuid-2"],
  "action": "invalidate_cache"
}

// banexus → bhnexus: heartbeat
{
  "type": "heartbeat",
  "node_id": "Ventas-01",
  "uptime_seconds": 86400,
  "active_sessions": 3,
  "last_auth_request": "2026-03-14T10:30:00Z"
}
```

### 3.3 Reconexión

```
Si WebSocket se desconecta:
  banexus intenta reconectar con exponential backoff:
    1s → 5s → 15s → 30s → 60s (max)
  Durante desconexión: banexus opera con ephemeral policy cache
  Al reconectar: banexus envía heartbeat con resumen de actividad offline
```

---

## 4. Device Fichas (Hardware Bridge)

Cada dispositivo físico conectado se configura como una "ficha de dispositivo":

```yaml
# /etc/bos/blibs/bhnexus/devices/puerta-principal.yml
device:
  id: "AP-PUERTA-01"
  name: "Puerta Principal — Piso de Ventas"
  type: "access_point"             # access_point | reader | camera | relay
  protocol: "osdp"                 # osdp | mqtt | onvif | wiegand | http
  connection:
    host: "192.168.1.50"
    port: 9600
    baud_rate: 9600                # para serial/OSDP
  zone: "ZONE-VENTAS"
  actuators:
    - id: "RELAY_01"
      type: "door_lock"
      action_on_grant: "OPEN"
      open_duration_ms: 3000
  health:
    check_interval_seconds: 30
    check_command: "ping"          # ping | osdp_poll | mqtt_status
  enabled: true
```

---

## 5. El Flujo Soberano Completo

```
T+0.000s  Usuario presenta QR al lector USB de la terminal Fedora
T+0.001s  banexus intercepta datos del bus USB ANTES de que Fedora los procese
T+0.002s  banexus firma el payload con HMAC y lo envía a bhnexus via WebSocket
T+0.005s  bhnexus recibe, identifica nodo "Ventas-01"
T+0.006s  bhnexus: ¿auth cache hit? 
            SÍ (T+0.007s) → BitMask del cache
            NO → consulta bauth via Unix socket
T+0.010s  bauth evalúa: UserTemplate + RolTemplate
            Dominio lógico: red OK, dispositivo OK, LoA OK
            Dominio físico: zona VENTAS OK, horario OK
            Dominio financiero: límite OK
T+0.012s  bauth retorna BitMask: 0x000000000003E627
T+0.013s  bhnexus almacena en auth cache (TTL 30s)
T+0.014s  bhnexus envía a banexus:
            BitMask + actuator_commands[RELAY_01:OPEN]
T+0.015s  banexus recibe → ejecuta en paralelo:
            1. Libera shell de Fedora (Bit 1: SHELL_UNLOCK)
            2. Activa relé del cajón de dinero (Bit 5: DRAWER_OPEN)
            3. Envía OPEN a RELAY_01 via conexión serial

LATENCIA TOTAL: ~15ms (objetivo < 50ms)
```

---

## 6. Configuración (bhnexus.toml)

```toml
[server]
websocket_port = 9444
metrics_port = 9445
tls_cert = "/etc/bos/tls/bhnexus.crt"
tls_key = "/etc/bos/tls/bhnexus.key"
tls_ca = "/etc/bos/tls/ca.crt"        # CA para verificar agentes

[auth]
bauth_socket = "/run/bos/bauth.sock"
cache_ttl_seconds = 30
cache_max_entries = 10000

[hardware]
devices_path = "/etc/bos/blibs/bhnexus/devices/"
osdp_enabled = true
mqtt_enabled = true
mqtt_broker = "localhost:1883"

[agents]
nodes_path = "/etc/bos/blibs/bhnexus/nodes/"
heartbeat_interval_seconds = 30
max_idle_seconds = 300                  # desconectar agentes inactivos
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Especificación completa del SBOS Nexus Host: arquitectura interna con 6 componentes, protocolo WebSocket con banexus (frames, reconexión, heartbeat), device fichas para hardware bridge, flujo soberano completo con latencias, y configuración.

---

*SKULL · SBOS · SBOS-035-NEXUS-HOST · v1.0 · Marzo 2026*

> **Referencias:** NIST SP 800-207 Device Agent/Gateway model · OSDP v2 (SIA) for physical access control · MQTT 5.0 for IoT · WebSocket RFC 6455 · mTLS RFC 8446
