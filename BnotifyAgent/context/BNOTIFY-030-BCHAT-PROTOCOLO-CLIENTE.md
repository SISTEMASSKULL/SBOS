---
codigo: BNOTIFY-030
version: 1.0.0
estado: BORRADOR
gate: G2
depende_de: [BNOTIFY-000, BNOTIFY-004]
doctrina_que_ejerce: [D2, D4, D5, D6, D14]
criterio_implementado: >
  Un cliente de prueba en Rust se conecta al motor bChat por WebSocket,
  envía un mensaje en una sala y lo recibe en otro cliente conectado en < 100ms.
  Un cliente desconectado por 60s y reconectado recibe todos los mensajes perdidos
  (cola offline) en el orden correcto. Un mismo usuario conectado desde dos
  dispositivos recibe cada mensaje exactamente una vez en cada dispositivo.
  Todo verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-030 — bChat Protocolo Cliente
## WebSocket + JSON-RPC 2.0: el sistema nervioso de bChat

**Versión:** 1.0.0 · **Gate:** G2 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §B.1 (Regla de comunicación: cero REST), ADR-002 (WebSocket+JSON-RPC 2.0)

**Nota:** BNOTIFY-000 §10 marca este como "el documento más difícil del proyecto".
La dificultad no está en el protocolo en sí (JSON-RPC es conocido) sino en los
subsistemas de sincronización: deltas, reconciliación multi-dispositivo y cola offline.
Este documento se redacta como **especificación** — el prototipo de validación precede
a la implementación completa.

---

## 1. Principios del protocolo

### 1.1 Una sola conexión por dispositivo

El cliente Flutter mantiene **una sola conexión WebSocket persistente** hacia el motor
bChat. Por esa conexión viajan:
- Llamadas JSON-RPC 2.0 (cliente → servidor y servidor → cliente)
- Eventos push del servidor (notificaciones, mensajes, presencia)
- Suscripciones activas

No hay polling. No hay múltiples conexiones. Una conexión = un dispositivo.

### 1.2 JSON-RPC 2.0 sobre WebSocket

Se sigue el estándar JSON-RPC 2.0 (especificación jsonrpc.org). Cada frame del WebSocket
es un mensaje JSON. Los mensajes pueden ser:
- **Request** (cliente → servidor o servidor → cliente): `{ "jsonrpc": "2.0", "method": "...", "params": {...}, "id": "..." }`
- **Response** (servidor → cliente): `{ "jsonrpc": "2.0", "result": {...}, "id": "..." }`
- **Error** (servidor → cliente): `{ "jsonrpc": "2.0", "error": {"code": N, "message": "..."}, "id": "..." }`
- **Notification** (sin id — fire-and-forget): `{ "jsonrpc": "2.0", "method": "...", "params": {...} }`

Los **eventos push del servidor** son Notifications (sin id) — el servidor no espera ACK.

---

## 2. Ciclo de vida de la conexión

### 2.1 Handshake de capacidades (patrón B.0.1 de BNOTIFY-000)

Al conectar, el cliente se identifica y negocia capacidades:

```json
// Cliente → Servidor (Request)
{
  "jsonrpc": "2.0",
  "method": "bchat.connect",
  "params": {
    "access_token": "{JWT de bAuth}",
    "device_id": "{UUID del dispositivo}",
    "client_version": "1.0.0",
    "capabilities": ["messages", "presence", "rooms", "push_tokens"]
  },
  "id": "connect-1"
}

// Servidor → Cliente (Response)
{
  "jsonrpc": "2.0",
  "result": {
    "session_id": "{UUID de la sesión WS}",
    "ctx_id": "{ctx_id propagado del JWT}",
    "server_version": "1.0.0",
    "features_enabled": ["messages", "presence", "rooms"],
    "push_register_url": null,
    "sync_cursor": "{opaque cursor para sincronización inicial}"
  },
  "id": "connect-1"
}
```

### 2.2 Sincronización inicial tras conexión

Después del handshake, el cliente solicita los datos no vistos desde su último `sync_cursor`:

```json
// Cliente → Servidor
{
  "jsonrpc": "2.0",
  "method": "bchat.sync",
  "params": {
    "cursor": "{sync_cursor del connect o último cursor almacenado}",
    "limit": 100
  },
  "id": "sync-1"
}

// Servidor → Cliente
{
  "jsonrpc": "2.0",
  "result": {
    "events": [...],         // Lista de eventos desde cursor
    "next_cursor": "...",    // Nuevo cursor para la próxima sync
    "has_more": false        // true si hay más eventos (paginación)
  },
  "id": "sync-1"
}
```

El `sync_cursor` es opaco — el cliente no lo interpreta. El servidor lo usa para saber
desde qué punto en el tiempo/secuencia empezar a enviar eventos.

### 2.3 Reconexión automática

Si la conexión se corta:
1. El cliente almacena localmente el último `sync_cursor` recibido
2. Reconecta y hace `bchat.connect` con `device_id` igual
3. Hace `bchat.sync` con el cursor guardado para recuperar los eventos perdidos
4. **Exactamente una vez:** el servidor no envía dos veces el mismo evento (deduplicación por cursor)

---

## 3. Suscripciones

### 3.1 Suscribirse a una sala

```json
// Cliente → Servidor
{
  "jsonrpc": "2.0",
  "method": "bchat.room.subscribe",
  "params": { "room_id": "{UUID}" },
  "id": "sub-room-1"
}

// Servidor → Cliente (confirmación)
{
  "jsonrpc": "2.0",
  "result": { "subscribed": true, "room_id": "{UUID}" },
  "id": "sub-room-1"
}
```

Mientras la suscripción está activa, el servidor envía Notifications para cada evento
de la sala: mensajes nuevos, ediciones, borrados, cambios de membresía.

### 3.2 Desuscribirse

```json
{ "jsonrpc": "2.0", "method": "bchat.room.unsubscribe", "params": { "room_id": "..." }, "id": "..." }
```

### 3.3 Presencia

```json
// Cliente → Servidor (actualizar estado)
{ "jsonrpc": "2.0", "method": "bchat.presence.set",
  "params": { "status": "online|away|offline" }, "id": "..." }

// Servidor → Cliente (Notification — cambio de presencia de otro usuario)
{ "jsonrpc": "2.0", "method": "bchat.presence.changed",
  "params": { "user_id": "...", "status": "away", "last_seen": "2026-07-06T12:00:00Z" } }
```

---

## 4. Mensajes

### 4.1 Enviar un mensaje

```json
// Cliente → Servidor
{
  "jsonrpc": "2.0",
  "method": "bchat.message.send",
  "params": {
    "room_id": "{UUID}",
    "content": {
      "type": "text",            // "text", "media_ref", "forwarded", "reply"
      "text": "Hola equipo",
      "reply_to": null           // message_id si es respuesta
    },
    "client_message_id": "{UUID local del cliente — idempotencia}"
  },
  "id": "send-1"
}

// Servidor → Cliente (Response)
{
  "jsonrpc": "2.0",
  "result": {
    "message_id": "{UUID del servidor}",
    "room_id": "{UUID}",
    "sender_id": "{bauth_user_id}",
    "timestamp": "2026-07-06T12:00:00.123Z",
    "sequence": 1042              // Número de secuencia dentro de la sala
  },
  "id": "send-1"
}
```

### 4.2 Recibir un mensaje (Notification del servidor)

```json
// Servidor → Cliente (Notification — llega a todos los suscriptores de la sala)
{
  "jsonrpc": "2.0",
  "method": "bchat.message.new",
  "params": {
    "message_id": "{UUID}",
    "room_id": "{UUID}",
    "sender_id": "{bauth_user_id}",
    "sender_name": "Ana López",
    "content": { "type": "text", "text": "Hola equipo" },
    "timestamp": "2026-07-06T12:00:00.123Z",
    "sequence": 1042
  }
}
```

### 4.3 Números de secuencia (el mecanismo anti-gap)

Cada sala tiene un contador de secuencia (`bigserial` en PostgreSQL). Cada mensaje tiene
un `sequence` monótonamente creciente. El cliente detecta gaps:
- Si recibe sequence 1044 y el último que tenía era 1042 → le falta el 1043
- Pide `bchat.room.history` con `from_sequence=1043, to_sequence=1043` para recuperarlo

Esto garantiza **entrega ordenada y sin gaps** incluso en redes inestables.

---

## 5. Cola offline y reconciliación multi-dispositivo

### 5.1 Cola offline

Mientras un dispositivo está desconectado, el servidor mantiene una cola de eventos
para ese dispositivo (indexada por `device_id`). Al reconectar con `bchat.sync(cursor)`,
el servidor entrega todos los eventos perdidos en orden.

**Límite de retención:** configurable por tier de usuario. Por defecto: 30 días o
los últimos 10.000 eventos, lo que sea menor.

### 5.2 Multi-dispositivo: el mismo usuario en 2+ dispositivos

```
Dispositivo A (conectado)  ←──── Servidor ────→  Dispositivo B (conectado)
    │                                                      │
    └── envía mensaje ──→ Servidor ──→ Notification ──→ ambos dispositivos
```

Cuando el mismo usuario está en dos dispositivos, el servidor envía el Notification
a ambas sesiones WS activas. Si un dispositivo está offline, va a su cola offline.

**El mensaje aparece en el dispositivo emisor también** (confirmado por el `message_id`
del Response) — el cliente no muestra optimistamente el mensaje antes de recibir la
confirmación del servidor. Este es un diseño deliberado para consistencia sobre UX.

---

## 6. Paginación de historial

```json
// Cliente → Servidor
{
  "jsonrpc": "2.0",
  "method": "bchat.room.history",
  "params": {
    "room_id": "{UUID}",
    "before_sequence": 1000,    // Cargar mensajes ANTES de este número de secuencia
    "limit": 50                  // Máximo 100 por solicitud
  },
  "id": "history-1"
}

// Servidor → Cliente
{
  "jsonrpc": "2.0",
  "result": {
    "messages": [...],    // Array de mensajes en orden descendente
    "has_more": true,     // true si hay mensajes más antiguos
    "oldest_sequence": 951
  },
  "id": "history-1"
}
```

---

## 7. Métodos del protocolo — catálogo completo

| Método | Dirección | Descripción |
|--------|:---------:|-------------|
| `bchat.connect` | C→S | Handshake de capacidades + autenticación |
| `bchat.sync` | C→S | Sincronización desde cursor |
| `bchat.disconnect` | C→S | Cierre limpio de sesión |
| `bchat.room.list` | C→S | Lista de salas del usuario |
| `bchat.room.subscribe` | C→S | Suscribirse a eventos de una sala |
| `bchat.room.unsubscribe` | C→S | Desuscribirse de una sala |
| `bchat.room.create` | C→S | Crear sala (verifica átomo D1.bchat.room.CREATE) |
| `bchat.room.history` | C→S | Cargar historial paginado |
| `bchat.room.members` | C→S | Lista de miembros |
| `bchat.message.send` | C→S | Enviar mensaje |
| `bchat.message.edit` | C→S | Editar mensaje propio (verifica D1.bchat.message.EDIT_OWN) |
| `bchat.message.delete` | C→S | Borrar mensaje (propio o cualquiera con permiso) |
| `bchat.presence.set` | C→S | Actualizar estado de presencia |
| `bchat.message.new` | S→C | Notificación: mensaje nuevo en sala suscrita |
| `bchat.message.updated` | S→C | Notificación: mensaje editado |
| `bchat.message.deleted` | S→C | Notificación: mensaje borrado |
| `bchat.presence.changed` | S→C | Notificación: cambio de presencia de otro usuario |
| `bchat.room.membership_changed` | S→C | Notificación: usuario entró/salió de sala |
| `bchat.session.revoked` | S→C | CAEP: sesión revocada — el cliente debe cerrar |

---

## 8. Códigos de error

| Código | Nombre | Descripción |
|:------:|--------|-------------|
| -32600 | InvalidRequest | Request malformado |
| -32601 | MethodNotFound | Método desconocido |
| -32602 | InvalidParams | Parámetros inválidos |
| 4001 | Unauthorized | JWT inválido o expirado |
| 4003 | Forbidden | Sin permiso (átomo bAuth rechazó) |
| 4004 | RoomNotFound | Sala inexistente |
| 4029 | RateLimited | Demasiadas solicitudes |
| 5001 | InternalError | Error interno del servidor |

---

## 9. Seguridad

- **Autenticación:** JWT de bAuth (claim `sub`, `ctx_id`, `sbos_roles`) en `bchat.connect`
- **Autorización:** cada método verifica el átomo correspondiente contra bAuth antes de ejecutar
- **ctx_id propagado:** todas las operaciones del servidor llevan el ctx_id del connect inicial
- **TLS obligatorio:** la conexión WebSocket es siempre `wss://` — `ws://` rechazado
- **CAEP:** el servidor recibe `session-revoked` de bNotify (que lo recibió de bAuth) y envía `bchat.session.revoked` al cliente

---

*BNOTIFY-030 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*La dificultad no es el protocolo — es el sistema de sincronización. Los números de secuencia y la cola offline son lo que diferencia un mensajero de verdad de un chat de demo.*
