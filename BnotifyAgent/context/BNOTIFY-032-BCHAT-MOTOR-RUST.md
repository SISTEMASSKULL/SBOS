---
codigo: BNOTIFY-032
version: 1.0.0
estado: BORRADOR
gate: G2
depende_de: [BNOTIFY-030, BNOTIFY-031]
doctrina_que_ejerce: [D2, D4, D5, D14]
criterio_implementado: >
  cargo build --release --target x86_64-unknown-linux-musl del motor bChat sin errores.
  Un cliente de prueba envía un mensaje por WebSocket y lo recibe otro cliente en < 100ms.
  El motor arranque, acepta conexión, procesa bchat.connect y responde session_id válido.
  10 conexiones WS concurrentes simultáneas sin errores. Verificado con
  verificar_afirmacion.sh en VPS.
---

# BNOTIFY-032 — bChat Motor Rust
## Axum/Tokio + NATS/JetStream: el motor de mensajería nativo

**Versión:** 1.0.0 · **Gate:** G2 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §B.1, §B.4 · BNOTIFY-030 (protocolo) · BNOTIFY-031 (esquema)

---

## 1. Arquitectura del motor

```
Cliente Flutter (wss://)
    │
    ▼
Axum WebSocket Handler
    │  JSON-RPC 2.0 frame
    ▼
Router JSON-RPC (bchat.*)
    │
    ├── bchat.connect      → AuthService (verifica JWT bAuth)
    ├── bchat.message.send → MessageService (INSERT + next_sequence + fan-out)
    ├── bchat.room.*       → RoomService
    ├── bchat.presence.*   → PresenceService
    └── bchat.sync         → SyncService (cursor-based)
         │
         ▼ Fan-out
    NATS JetStream (subject: bchat.events.{tenant_id}.{room_id})
         │
         ▼ Subscriptores activos
    Notification Broadcaster (Axum broadcast channel por sesión WS)
```

---

## 2. Estructura de módulos Rust

```
bchat-engine/src/
├── main.rs               # ≤50 líneas: arranque systemd, signal handlers
├── config/mod.rs         # ConfigBchat: ws_bind, postgres, redis, nats, bauth_grpc
├── ws/
│   ├── handler.rs        # Axum WebSocket upgrade handler
│   ├── session.rs        # Estado de una sesión WS: user_id, ctx_id, device_id, suscripciones
│   └── router.rs         # Despacha método JSON-RPC al service correcto
├── services/
│   ├── auth.rs           # Verifica JWT bAuth, extrae ctx_id + sbos_roles + bauth_user_id
│   ├── message.rs        # send, edit, delete, history
│   ├── room.rs           # list, create, subscribe, unsubscribe, members
│   ├── sync.rs           # Sync desde cursor, cola offline
│   ├── presence.rs       # set_status, get_status (Redis hash)
│   └── fanout.rs         # Publica en NATS, broadcaster local por sala
├── caep/
│   └── handler.rs        # Recibe session-revoked de bNotify → cierra sesión WS
├── db/
│   ├── postgres.rs       # Pool sqlx, schema bchat
│   └── redis.rs          # Presencia, sync cursors, sesiones activas
└── audit/
    └── emitter.rs        # Publica eventos bchat.* en NATS → bNotify los clasifica
```

---

## 3. Fan-out de mensajes

El fan-out es el subsistema más crítico del motor. Cuando un cliente envía un mensaje:

```
1. Validar átomo D1.bchat.message.SEND en bAuth (caché local 30s)
2. Llamar bchat.next_sequence(room_id) — atómico en PostgreSQL
3. INSERT INTO bchat.message (sin esperar replicación)
4. Publicar en NATS subject: bchat.room.{room_id}.messages
5. Retornar DispatchResponse al cliente (< 50ms hasta aquí)

NATS fan-out (asíncrono):
6. Todos los workers con sesiones suscritas a room_id consumen el evento
7. Cada worker envía Notification JSON-RPC por el WS de su sesión
```

**Separación crítica:** el INSERT en PostgreSQL y el retorno al cliente emisor ocurren
en la misma transacción (pasos 2-5). El fan-out a los receptores es asíncrono por NATS.
Esto garantiza que el emisor recibe confirmación rápida sin bloquear en la entrega a N receptores.

### 3.1 Fan-out local (mismo nodo)

Para sesiones WS en el mismo proceso, el fan-out usa un `tokio::sync::broadcast::Sender`
por sala — sin pasar por NATS. Latencia típica < 1ms.

### 3.2 Fan-out distribuido (múltiples nodos)

En G3 con múltiples instancias del motor, el fan-out local no es suficiente. NATS
JetStream actúa como bus distribuido: cada instancia del motor suscribe al subject
de las salas donde tiene sesiones activas.

---

## 4. Cursor de sincronización

El cursor es un string opaco que encapsula `(tenant_id, last_event_id, timestamp)`.
Codificado en base64 para que el cliente no lo interprete.

```rust
struct SyncCursor {
    tenant_id:    String,
    last_seq:     i64,      // Último sequence visto en el global event log
    timestamp:    i64,      // Unix timestamp ms
}
// Serializado con serde_json + base64url
```

El `global event log` es una tabla `bchat.event_log` con un sequence global del tenant
(no por sala — es el timestamp de inserción que permite recuperar todos los eventos
en orden independientemente de la sala).

---

## 5. Presencia (Redis)

```
# Hash por usuario: HSET presence:{tenant_id}:{user_id} status online last_seen {ts}
# TTL: 60s — el cliente envía heartbeat cada 30s para mantenerlo vivo
# Al expirar: presencia implícita "offline"
```

El servicio de presencia es eventual — los cambios de estado se propagan en < 5s,
no en tiempo real estricto. Esto reduce enormemente la carga bajo miles de usuarios.

---

## 6. Integración con bAuth

- **Autenticación:** cada `bchat.connect` verifica el JWT con la clave pública JWKS de bAuth
- **Autorización:** cada acción verifica el átomo correspondiente con una llamada gRPC a bAuth
  - Caché local por `(user_id, atom)` con TTL 30s para no sobrecargar bAuth
- **CAEP:** el motor expone un endpoint gRPC `bchat.v1.SessionManager.RevokeSession`
  que bNotify llama cuando recibe `session-revoked` de bAuth

---

## 7. Configuración

```toml
# /etc/bchat-engine/config.toml
[server]
ws_bind = "0.0.0.0:9460"   # Puerto bChat (SBOS-050)
socket_path = "/run/bos/bchat.sock"

[database]
postgres_url = "postgresql://bchat_rw:${BCHAT_DB_PASS}@postgres.infra:5432/SBOS_db"
max_pool_size = 30

[redis]
url = "redis://redis-cluster.infra:6379"
presence_ttl_secs = 60

[nats]
url = "nats://nats.infra:4222"
fanout_stream = "BCHAT_EVENTS"

[bauth_grpc]
endpoint = "http://unix:///run/bos/bauth.sock"
atom_cache_ttl_secs = 30
```

---

*BNOTIFY-032 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El INSERT y el retorno al emisor van juntos. El fan-out a los receptores va por NATS. Estos dos tiempos nunca se mezclan.*
