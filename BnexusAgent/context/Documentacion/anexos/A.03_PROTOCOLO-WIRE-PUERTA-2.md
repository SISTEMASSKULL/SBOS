# A.03 — Spec Protocolo Wire Puerta 2 + Canal Privilegiado
## bhnexus ↔ bAuth: TLV Unix socket (bitmask) + canal privilegiado bidireccional

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `2.02_MANUAL-PUERTA-2-BAUTH.md`  

---

## 1. Sub-canal A — Unix socket TLV (bitmask resolution)

### 1.1 Socket

```
Ruta:     /run/bos/bauth.sock
Tipo:     Unix stream socket (AF_UNIX, SOCK_STREAM)
Permisos: 0660, owner bos:bos, grupo bos
Acceso:   Solo procesos del grupo 'bos' pueden conectarse
```

### 1.2 Framing TLV

```
Cada mensaje = un frame TLV:
  [4 bytes]  uint32 big-endian = longitud del payload JSON
  [N bytes]  payload JSON UTF-8 (sin terminador null)

Máximo: 65535 bytes de payload (NUNCA se espera un payload tan grande;
        los mensajes son < 2KB en condiciones normales)

Ejemplo:
  Payload JSON = '{"type":"bitmask_request",...}' (196 bytes = 0xC4)
  Frame = 0x000000C4 + {json bytes}
```

No hay framing adicional ni handshake propio — bAuth ya conoce el socket de bhnexus por configuración.

### 1.3 bitmask_request — esquema completo

```json
{
  "type":       "bitmask_request",
  "request_id": "uuid-v4",
  "user_id":    "uuid-v4",
  "node_id":    "string",
  "domain":     "D00|D01|D08|D11|D14|D15|D93|...",
  "operation":  "string",           // átomo a verificar ej: "access.physical.zone_a"
  "credential_type": "qr|nfc|...", // tipo de credencial presentada (para step-up)
  "ctx_id":     "00-hex32-hex16-01",
  "timestamp":  "RFC3339"
}
```

### 1.4 bitmask_response — esquema completo

```json
{
  "type":       "bitmask_response",
  "request_id": "uuid-v4",         // correlación con bitmask_request
  "result":     "granted|denied",

  // Si result = "granted":
  "sam128": {
    "word_a": "0x<hex16>",         // 64-bit: privilegios físicos
    "word_b": "0x<hex16>"          // 64-bit: contexto + TTL + flags
  },
  "actuator_commands": [
    {
      "target":      "RELAY_01|DRAWER_01|LOCK_01|BARRIER_01|...",
      "action":      "OPEN|CLOSE|TOGGLE|PULSE|ALARM",
      "duration_ms": 5000
    }
  ],
  "ttl_seconds":       28800,       // TTL de la decisión para el cache de bhnexus
  "roltemplate_hash":  "0x<hex4>", // versión del RolTemplate usado (para invalidación)
  "step_up_required":  false,       // true si se requiere factor adicional
  "step_up_methods":   [],          // métodos aceptados para step-up si aplica

  // Si result = "denied":
  "deny_reason": "outside_schedule|revoked|insufficient_privilege|...",
  "deny_message": "string en español",

  "ctx_id":    "00-hex32-hex16-01",
  "timestamp": "RFC3339"
}
```

### 1.5 Error response (bAuth no puede procesar)

```json
{
  "type":       "bitmask_error",
  "request_id": "uuid-v4",
  "code":       "user_not_found|db_timeout|policy_engine_error|...",
  "message":    "string en español",
  "timestamp":  "RFC3339"
}
```

Cuando bhnexus recibe `bitmask_error`: retorna `auth_response` con `status: denied`, `reason: auth_service_error`.

### 1.6 Pool de conexiones

```
bhnexus mantiene un pool de conexiones al Unix socket:
  pool_size:   100 conexiones concurrentes
  timeout:     1000ms por request (si bAuth no responde → error)
  keep_alive:  conexiones reutilizadas (no se cierra y reabre por cada request)
```

---

## 2. Sub-canal B — Canal Privilegiado bidireccional

### 2.1 Socket

```
Ruta:     /run/bos/bauth-nexus.sock
Tipo:     Unix stream socket (AF_UNIX, SOCK_STREAM)
Permisos: 0660, owner bos:bos, grupo bos
Acceso:   Solo bAuth y bhnexus (ambos en grupo 'bos')
Conexión: 1 conexión persistente (no pool)
```

### 2.2 Framing del canal privilegiado

```
Delimitador: newline '\n' (0x0A)
Cada mensaje = 1 línea JSON terminada en '\n'

Sin longitud prefija — el receptor lee hasta '\n' para delimitar mensajes.
Máximo de mensaje: 8KB (más grande → error de protocolo, cierre de conexión)

Ejemplo:
  '{"event":"emergency_revoke","user_id":"uuid","ts":"2026..."}\n'
```

### 2.3 Todos los eventos bAuth → bhnexus

#### emergency_revoke

```json
{
  "event":   "emergency_revoke",
  "user_id": "uuid-v4",
  "reason":  "credential_compromised|account_lockout|admin_forced|mfa_breach",
  "scope":   "all_nodes|specific_node",
  "node_id": "string",    // solo si scope = "specific_node"
  "ctx_id":  "string",
  "ts":      "RFC3339"
}
```

Acción bhnexus: eliminar TODAS las entradas de cache del `user_id` + enviar `policy_update` con `action: invalidate_cache` a todos los nodos banexus afectados.

#### invalidate_cache

```json
{
  "event":   "invalidate_cache",
  "user_id": "uuid-v4",
  "reason":  "password_changed|role_modified|mfa_device_changed",
  "ts":      "RFC3339"
}
```

Acción bhnexus: eliminar la entrada de cache del `user_id` específico.

#### security_level_up

```json
{
  "event":          "security_level_up",
  "affected_zones": ["zona_servidores", "zona_financiero"],
  "new_level":      3,
  "duration_min":   60,
  "reason":         "security_incident|admin_manual|automated_threat",
  "ts":             "RFC3339"
}
```

Acción bhnexus: actualizar `security_level` para las zonas afectadas + propagar configuración actualizada a los nodos banexus en esas zonas.

#### blacklist_node

```json
{
  "event":   "blacklist_node",
  "node_id": "string",
  "reason":  "integrity_check_failed|tamper_detected|compromised|admin_disabled",
  "ts":      "RFC3339"
}
```

Acción bhnexus: cerrar la conexión WebSocket del nodo + agregar a deny-list + rechazar toda reconexión futura hasta `unblacklist_node`.

#### unblacklist_node

```json
{
  "event":   "unblacklist_node",
  "node_id": "string",
  "reason":  "admin_cleared",
  "ts":      "RFC3339"
}
```

Acción bhnexus: remover de la deny-list + permitir que el nodo reconecte normalmente.

#### policy_sync

```json
{
  "event":            "policy_sync",
  "roltemplate_id":   "uuid-v4",
  "roltemplate_hash": "0x<hex4>",
  "affected_users":   ["uuid-v4"],
  "action":           "invalidate_cache|full_reload",
  "ts":               "RFC3339"
}
```

Acción bhnexus: invalidar cache de los `affected_users` + enviar `policy_update` a los nodos banexus que tienen sesiones de esos usuarios.

---

### 2.4 Todos los eventos bhnexus → bAuth

#### device_tamper

```json
{
  "event":     "device_tamper",
  "node_id":   "string",
  "device_id": "string",      // entity_id en idn_identity_entity
  "evidence":  "osdp_tamper_bit_set|enclosure_opened|cable_disconnected",
  "severity":  "CRITICAL|HIGH|MEDIUM",
  "ts":        "RFC3339"
}
```

#### node_offline

```json
{
  "event":              "node_offline",
  "node_id":            "string",
  "last_heartbeat":     "RFC3339",
  "offline_duration_s": 60,
  "last_known_state":   "ok|degraded|unknown",
  "ts":                 "RFC3339"
}
```

#### node_online

```json
{
  "event":            "node_online",
  "node_id":          "string",
  "offline_events":   3,          // auth events resueltos en offline por cache local
  "cache_hits_offline": 3,
  "cache_misses_offline": 0,
  "ts":               "RFC3339"
}
```

#### auth_spike

```json
{
  "event":      "auth_spike",
  "node_id":    "string",
  "count":      47,
  "window_s":   60,
  "granted":    12,
  "denied":     35,
  "top_users":  ["uuid-1", "uuid-2"],   // los 3 usuarios con más intentos
  "severity":   "HIGH|CRITICAL",
  "ts":         "RFC3339"
}
```

#### hardware_failure

```json
{
  "event":     "hardware_failure",
  "node_id":   "string",
  "component": "relay_01|reader_usb|osdp_bus|gpio_pin_24|...",
  "error":     "serial_timeout|driver_error|device_not_responding",
  "impact":    "DOOR_STUCK_OPEN|DOOR_STUCK_CLOSED|READER_OFFLINE|ACTUATOR_OFFLINE",
  "ts":        "RFC3339"
}
```

#### integrity_breach

```json
{
  "event":     "integrity_breach",
  "node_id":   "string",
  "expected":  "sha256:<hex64>",
  "actual":    "sha256:<hex64>",
  "action_taken": "auto_shutdown",
  "ts":        "RFC3339"
}
```

bAuth, al recibir `integrity_breach`: emite automáticamente `blacklist_node` para ese nodo + alerta SIEM Wazuh + notifica a bnotify.

---

## 3. Reconexión del canal privilegiado

```
Si el canal privilegiado se desconecta (bAuth restart, bhnexus restart):

bhnexus intenta reconectar al socket /run/bos/bauth-nexus.sock:
  Espera 1s → intenta
  Espera 5s → intenta
  Espera 30s → intenta (máximo, repite cada 30s)

Durante la desconexión del canal B:
  Sub-canal A (bitmask) sigue funcionando normalmente
  Los eventos que se generarían por el canal B se encolan en memoria
  Al reconectar: se envían los eventos encolados en orden
  Si la cola supera 1000 eventos: se descartan los más antiguos (WARN en log)
```

---

## 4. Garantías del protocolo

| Garantía | Sub-canal A | Sub-canal B |
|----------|:-----------:|:-----------:|
| Ordenamiento | Garantizado por TCP | Garantizado por TCP (Unix stream) |
| Entrega | At-least-once (con retry) | Best-effort (sin retry automático) |
| Duplicados | Posibles (request_id para dedup) | Posibles (ts + event para dedup) |
| Latencia máxima | 1000ms (timeout) | No acotada en reconexión |
| Latencia típica | < 10ms | < 5ms |

---

*SKULL · SBOS · bNexus · A.03_PROTOCOLO-WIRE-PUERTA-2 · v1.0.0 · Agosto 2026*
