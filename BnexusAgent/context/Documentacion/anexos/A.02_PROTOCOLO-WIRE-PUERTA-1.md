# A.02 — Spec Protocolo Wire Puerta 1
## banexus ↔ bhnexus: frames JSON, mTLS, reconexión, timing

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `2.01_MANUAL-PUERTA-1-AGENTES.md`  

---

## 1. Stack de wire completo

```
[Capa 4] TCP/IP
[Capa 5] TLS 1.3 (rustls 0.23+)
          Cipher suites permitidas:
            TLS_AES_256_GCM_SHA384
            TLS_CHACHA20_POLY1305_SHA256
            TLS_AES_128_GCM_SHA256
          Cipher suites prohibidas: todas las de TLS 1.2 y anteriores
[Capa 6] mTLS (certificados SPIFFE/SVID X.509 en ambos extremos)
[Capa 7] WebSocket RFC 6455
          Endpoint: wss://<host>:9444/ws
          Subprotocol negociado: "sbos-banexus-v1"
[Capa 8] Mensajes JSON UTF-8 (sin compresión por defecto)
```

---

## 2. Handshake HTTP/WebSocket upgrade

```
→ GET /ws HTTP/1.1
  Host: sbos-server:9444
  Upgrade: websocket
  Connection: Upgrade
  Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
  Sec-WebSocket-Version: 13
  Sec-WebSocket-Protocol: sbos-banexus-v1
  X-Node-ID: Ventas-01
  X-Agent-Version: 1.0.0
  X-Agent-Cert-Fingerprint: sha256:a3f1c2...

← HTTP/1.1 101 Switching Protocols
  Upgrade: websocket
  Connection: Upgrade
  Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
  Sec-WebSocket-Protocol: sbos-banexus-v1
  X-Server-Version: 1.0.0

← HTTP/1.1 403 Forbidden (si handshake falla)
  Content-Type: application/json
  {"error": "node_not_registered", "node_id": "Ventas-01"}
```

---

## 3. Framing WebSocket

Todos los mensajes son **WebSocket text frames** (opcode 0x1) con payload JSON UTF-8.

```
WebSocket frame:
  FIN=1  RSV=0  OPCODE=0x1 (text)
  MASK=1 (cliente→servidor, siempre enmascarado)
  PAYLOAD_LEN = longitud del JSON en bytes

Max frame size: 64KB (mensajes más grandes → multiple frames con FIN=0, FIN=1)
```

**Tipos de frame opcionales (ping/pong):**
- bhnexus envía Ping frames cada 15s (opcode 0x9)
- banexus responde con Pong frames (opcode 0xA)
- Si no hay Pong en 30s → bhnexus cierra la conexión (close code 1001)

---

## 4. Catálogo completo de mensajes

### Dirección banexus → bhnexus

| `type` | Descripción | Frecuencia |
|--------|-------------|-----------|
| `auth_request` | Credencial capturada del hardware | Por evento |
| `heartbeat` | Señal de vida del nodo | Cada 30s |
| `shell_auth` | Consulta Shell Sentinel | Por comando sensible |

### Dirección bhnexus → banexus

| `type` | Descripción | Frecuencia |
|--------|-------------|-----------|
| `auth_response` | Respuesta GRANTED/DENIED | Por auth_request |
| `policy_update` | Invalidar cache de política | Por cambio de RolTemplate |
| `node_config` | Actualizar configuración del nodo | Por cambio de config |

---

## 5. Esquema JSON detallado por tipo

### auth_request

```json
{
  "type":       "auth_request",          // string, obligatorio
  "request_id": "uuid-v4",              // string UUID, obligatorio
  "node_id":    "string",               // string, obligatorio
  "input_type": "qr|nfc|rfid|biometric|smartcard|ble|pin",  // enum, obligatorio
  "payload":    "string",               // contenido de la credencial, obligatorio
  "device_id":  "string",               // ID del device físico, obligatorio
  "ctx_id":     "00-hex32-hex16-01",   // W3C traceparent, obligatorio
  "hmac":       "sha256:hex64",         // HMAC-SHA256 del payload, obligatorio
  "timestamp":  "RFC3339 con ms"        // timestamp del nodo, obligatorio
}
```

Formato de `payload` por `input_type`:

| input_type | Formato del payload |
|-----------|---------------------|
| `qr` | `sbos://auth/<user_uuid>/<unix_ts>/<hmac>` |
| `nfc` | `nfc:<uid_hex>:<ndef_payload_b64>` |
| `rfid` | `rfid:<facility>:<card_number>` (Wiegand 26/34) |
| `biometric` | `bio:<template_hash_sha256>` (hash del template — nunca el template) |
| `smartcard` | `sc:<cert_fingerprint_sha256>` |
| `ble` | `ble:<device_uuid>:<challenge_response_hex>` (Aliro) |
| `pin` | `pin:<pin_hmac_sha256>` (nunca el PIN en claro) |

### auth_response

```json
{
  "type":       "auth_response",         // string
  "request_id": "uuid-v4",              // correlación con auth_request
  "status":     "granted|denied",       // enum
  "ctx_id":     "00-hex32-hex16-01",   // propagado del auth_request

  // Solo si status = "granted":
  "sam128": {
    "word_a": "0x<hex16>",             // 64-bit privileges
    "word_b": "0x<hex16>"              // 64-bit context
  },
  "user_id":    "uuid-v4",
  "user_name":  "string",              // para display en UI del POS
  "ttl_seconds": 28800,
  "actuator_commands": [
    {
      "target":      "RELAY_01|DRAWER_01|LOCK_01|...",
      "action":      "OPEN|CLOSE|TOGGLE|PULSE",
      "duration_ms": 5000              // solo para OPEN temporal
    }
  ],

  // Solo si status = "denied":
  "reason":  "outside_schedule|revoked|insufficient_privilege|...",
  "message": "string en español",

  "timestamp": "RFC3339 con ms"
}
```

Códigos de razón de DENIED:

| reason | Descripción |
|--------|-------------|
| `outside_schedule` | Fuera de horario autorizado |
| `revoked` | Credencial revocada |
| `insufficient_privilege` | Átomo no en el SAM-128 |
| `zone_restricted` | Zona no autorizada para este usuario |
| `step_up_required` | Requiere factor adicional (RFC 9470) |
| `node_blacklisted` | El nodo banexus está en la blacklist |
| `user_suspended` | Cuenta suspendida |
| `credential_not_found` | Credencial no registrada en bAuth |
| `auth_service_unavailable` | bAuth no disponible y no hay cache |

### policy_update

```json
{
  "type":           "policy_update",
  "reason":         "roltemplate_changed|user_modified|security_level_changed",
  "affected_users": ["uuid-v4", "uuid-v4"],
  "action":         "invalidate_cache|reload_config",
  "timestamp":      "RFC3339"
}
```

### heartbeat

```json
{
  "type":              "heartbeat",
  "node_id":           "string",
  "uptime_seconds":    86400,
  "active_sessions":   2,
  "cache_entries":     3,
  "offline_events":    0,           // eventos resueltos por cache local desde el último heartbeat
  "last_auth_ts":      "RFC3339",
  "integrity_ok":      true,        // false → bhnexus alerta a bAuth
  "binary_hash":       "sha256:..." // hash del binario banexus para verificación remota
}
```

### shell_auth

```json
{
  "type":      "shell_auth",
  "node_id":   "string",
  "user":      "string",            // username de sistema (no el user_id UUID)
  "command":   "string",            // comando completo con argumentos
  "ctx_id":    "00-hex32-hex16-01",
  "timestamp": "RFC3339"
}
```

Respuesta: `auth_response` con `status: granted|denied` y `actuator_commands: []` (sin comandos de hardware).

---

## 6. Secuencia de tiempo completa (flujo exitoso)

```
T+0.000  [Nodo]    banexus captura QR via udev+libusb
T+0.001  [Nodo]    banexus construye auth_request + HMAC
T+0.002  [Wire]    WebSocket text frame sale del nodo → TLS → red LAN
T+0.004  [Servidor] bhnexus recibe frame, deserializa JSON
T+0.005  [Servidor] bhnexus verifica HMAC del payload
T+0.006  [Servidor] bhnexus consulta Auth Cache → ¿hit?
            └─ cache hit  (< 2ms) → T+0.007 construye auth_response
            └─ cache miss (+ 8ms) → consulta Puerta 2A → bAuth → SAM-128

T+0.013  [Servidor] bhnexus construye auth_response + actuator_commands
T+0.014  [Wire]    WebSocket text frame sale del servidor → TLS → red LAN
T+0.015  [Nodo]    banexus recibe frame, deserializa JSON
T+0.016  [Nodo]    banexus ejecuta en paralelo:
           → Shell: libera sesión si GRANTED
           → Serial: pulso al relay si actuator_commands incluye RELAY

TOTAL: ~15-16ms (objetivo < 50ms garantizado)
```

---

## 7. Close codes WebSocket usados por bhnexus

| Code | Nombre | Cuándo |
|------|--------|--------|
| 1000 | Normal Closure | Shutdown limpio de banexus |
| 1001 | Going Away | bhnexus en shutdown |
| 1006 | Abnormal Closure | Pérdida de conexión sin frame de cierre |
| 1008 | Policy Violation | Autenticación mTLS fallida |
| 1009 | Message Too Big | Frame > 64KB |
| 1011 | Internal Error | Error interno de bhnexus |
| 1013 | Try Again Later | Backpressure — cola interna llena (> 5000 items) |
| 4001 | Node Not Registered | node_id no en SBOSDB |
| 4002 | Version Incompatible | versión del agente por debajo del mínimo |
| 4003 | Node Blacklisted | nodo en la deny-list de bAuth |

---

*SKULL · SBOS · bNexus · A.02_PROTOCOLO-WIRE-PUERTA-1 · v1.0.0 · Agosto 2026*
