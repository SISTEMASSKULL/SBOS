---
codigo: BNOTIFY-010
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-001, BNOTIFY-002, BNOTIFY-004]
doctrina_que_ejerce: [D2, D4, D5, D11, D14, D15]
criterio_implementado: >
  cargo build --release sin errores en el binario bnotify.
  El servicio NotifyDispatcher responde a un DispatchRequest de prueba (event_type=mfa.challenge,
  priority=A, destination_type=user) con DispatchResponse.status=ACCEPTED en <10ms.
  El rate limiter rechaza el intento 21 de un usuario que envió 20 en el mismo minuto
  con status=REJECTED_RATE_LIMITED. La deduplicación retorna REJECTED_DUPLICATE para
  un intent_id que ya fue procesado. Todo verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-010 — Núcleo Orquestador
## Especificación del motor central del daemon bNotify en Rust

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2, §4.3 · BNOTIFY-001 (proto) · BNOTIFY-004 (taxonomía) · BNOTIFY-008 (DDL)

---

## 1. Propósito y fronteras

El núcleo orquestador es el corazón del daemon bNotify. Recibe intents de los daemons
emisores (mediante gRPC `NotifyDispatcher.Dispatch`) y produce órdenes de entrega hacia
los adaptadores de canal (`AdapterChannel.Deliver`). No conoce los canales — los canales
son intercambiables (D5).

**Lo que hace el núcleo:**
1. Valida el intent entrante (ctx_id, campos obligatorios, event_type conocido)
2. Comprueba idempotencia (intent_id ya visto → `REJECTED_DUPLICATE`)
3. Consulta el perfil de usuario en bNotify (quiet hours, preferencias, opt-out)
4. Verifica el ctx_id contra bAuth (sesión activa, no revocada por CAEP)
5. Aplica rate limiting por usuario y tipo de evento
6. Resuelve el destinatario (UUID → email/teléfono/sala)
7. Selecciona la plantilla correcta (event_type + canal + locale)
8. Encola la orden de entrega en la cola de prioridad correspondiente (A/B/C)
9. Retorna `DispatchResponse` inmediata (la entrega es asíncrona)

**Lo que NO hace el núcleo:**
- No sabe cómo entregar por chat, email, SMS o push — eso es el adaptador
- No gestiona identidades — las consulta a bAuth (lectura)
- No es el bus de eventos — usa NATS/JetStream como transporte

---

## 2. Arquitectura de módulos Rust

```
src/
├── main.rs                     # ≤50 líneas: arranque, systemd notify, signal handlers
├── config/
│   └── mod.rs                  # ConfigBnotify: ruta socket, DB, Redis, NATS, timeouts
├── server/
│   ├── grpc.rs                 # Implementación NotifyDispatcher (tonic)
│   └── unix_socket.rs          # Listener /run/bos/bnotify.sock
├── core/                       # El núcleo orquestador (este documento)
│   ├── mod.rs                  # Trait Orchestrator + EngineRegistry
│   ├── dispatcher.rs           # Pipeline principal: validate→dedup→check→rate→resolve→queue
│   ├── validator.rs            # Validación del DispatchRequest
│   ├── dedup.rs                # Idempotencia por intent_id (Redis SET NX EX)
│   ├── session_check.rs        # Verificación ctx_id contra bAuth (gRPC)
│   ├── rate_limiter.rs         # Leaky bucket por (user_id, event_type_prefix)
│   ├── resolver.rs             # Resuelve destination → recipient_user_id(s)
│   ├── profile.rs              # Lee notification_profile desde PostgreSQL
│   ├── template.rs             # Renderiza plantilla (event_type + canal + locale)
│   └── queue.rs                # Encola en colas A/B/C (Redis Sorted Sets)
├── worker/
│   ├── mod.rs                  # Worker pool: consume cola → llama adaptador gRPC
│   ├── delivery_worker.rs      # Consumer de la cola, llama AdapterChannel.Deliver
│   ├── retry.rs                # Backoff exponencial por clase
│   ├── failover.rs             # Escalada a canal secundario (clase A)
│   └── dlq.rs                  # Registro en DLQ, alarma a #operaciones
├── caep/
│   └── receiver.rs             # Recibe CaepEvent de bAuth, actualiza caché de sesiones
├── audit/
│   └── recorder.rs             # Genera audit_event clasificado A/B/C → NATS
└── db/
    ├── postgres.rs             # Pool sqlx para bnotify.* tables
    └── redis.rs                # Pool redis para dedup + rate limit + queues
```

---

## 3. Pipeline del Dispatch (flujo principal)

```
DispatchRequest entrante (gRPC)
    │
    ▼ validate (validator.rs)
    ├── ctx_id obligatorio y UUID v4 válido
    ├── intent_id UUID v4 válido
    ├── event_type en taxonomy (v_audit_class retorna clase conocida)
    ├── destination.type + destination.id no vacíos
    └── tenant_id no vacío
    │ → FALLA: DispatchResponse { REJECTED_INVALID, reason }
    │
    ▼ dedup (dedup.rs)
    ├── Redis: SET intent:{intent_id} 1 NX EX 86400 (24h de ventana)
    └── Si clave ya existe:
    │ → DispatchResponse { REJECTED_DUPLICATE }
    │
    ▼ session_check (session_check.rs)
    ├── Consulta bAuth: ¿ctx_id está activo?
    │   (caché local 30s para no llamar a bAuth en cada evento)
    └── Si ctx_id revocado (CAEP ya notificó):
    │ → DispatchResponse { REJECTED_INVALID, reason: "ctx_id revocado" }
    │
    ▼ profile (profile.rs)
    ├── SELECT * FROM bnotify.notification_profile WHERE bauth_user_id = ...
    │   (caché Redis 60s)
    ├── ¿event_type en opted_out_event_types? (solo clase B/C)
    └── Si opt-out aplica:
    │ → DispatchResponse { REJECTED_OPT_OUT }
    │
    ▼ rate_limit (rate_limiter.rs)
    ├── Leaky bucket: Redis INCR rate:{user_id}:{event_prefix} EX 60
    ├── Si supera profile.max_per_hour o max_per_day:
    └── Si supera límite:
    │ → DispatchResponse { REJECTED_RATE_LIMITED }
    │
    ▼ resolve (resolver.rs)
    ├── DESTINATION_USER → recipient_user_id = destination.id
    ├── DESTINATION_ROLE → consulta bAuth: UUID[] de usuarios con ese rol
    ├── DESTINATION_AUDIENCE → SELECT bauth_user_id FROM bnotify.audience_member
    └── DESTINATION_CHANNEL_ROOM → expandido al despachar (bRocket: REST; bChat: gRPC)
    │
    ▼ quiet_hours (profile.rs)
    ├── ¿Estamos en quiet hours del usuario? (solo clase B/C — clase A ignora)
    ├── Si sí y clase B/C: defer delivery hasta fin de quiet hours
    │   (encolar con timestamp de entrega diferida en la cola)
    └── Si clase A: ignorar quiet hours
    │
    ▼ template (template.rs)
    ├── SELECT subject, body FROM bnotify.template
    │   WHERE event_type=? AND channel=? AND locale=? AND (tenant_id=? OR tenant_id IS NULL)
    └── Render: reemplazar {{variable}} con template_data del request
    │
    ▼ enqueue (queue.rs)
    ├── Cola A: Redis Sorted Set "queue:A" score=unix_timestamp
    ├── Cola B: Redis Sorted Set "queue:B" score=unix_timestamp+delay_quiet_hours
    └── Cola C: Redis Sorted Set "queue:C" score=unix_timestamp
    │
    ▼ audit (audit/recorder.rs)
    └── Publica notify.intent.accepted en NATS (clase C — telemetría)
    │
    ▼ RETORNA DispatchResponse { ACCEPTED, delivery_id }
```

---

## 4. Workers de entrega (delivery_worker.rs)

### 4.1 Pool de workers

Tres pools de workers separados — uno por clase. Las colas A nunca esperan detrás de B/C.

| Pool | Workers | Cola | Comportamiento |
|------|:-------:|------|----------------|
| Pool A | 10 | Redis queue:A | Procesa en orden FIFO. Al fallar: retry.rs con backoff |
| Pool B | 5 | Redis queue:B | Procesa en orden FIFO. At-least-once |
| Pool C | 3 | Redis queue:C | Best-effort. Si falla, descarta y registra en métricas |

### 4.2 Ciclo de un worker

```
1. ZPOPMIN queue:{clase}  (Redis — atómico)
2. Leer delivery_record de bnotify.notification_event (estado=PENDING|IN_FLIGHT)
3. UPDATE bnotify.notification_event SET status='IN_FLIGHT', attempt_count+=1
4. Llamar AdapterChannel.Deliver con DeliverRequest (gRPC, timeout 10s para A, 30s para B/C)
5. Según DeliveryResult.status:
   - DELIVERED → UPDATE status='DELIVERED', delivered_at=now()
   - FAILED_TEMPORARY → retry.rs (backoff, re-encolar con nuevo score)
   - FAILED_PERMANENT → dlq.rs
   - CHANNEL_UNAVAILABLE → failover.rs (clase A) o dlq.rs (clase B/C)
6. Publicar audit event en NATS
```

---

## 5. Rate Limiter (rate_limiter.rs)

Algoritmo: **leaky bucket** implementado con Redis.

```rust
// Clave: "rate:{user_id}:{event_prefix}:{ventana_minutos}"
// Ventana: 1 minuto (rate_per_minute) y 1 hora (max_per_hour) y 1 día (max_per_day)
// Operación: INCR + EX — atómica

fn check_rate(user_id: Uuid, event_type: &str, limits: &RateLimits) -> Result<(), RateLimitError>
```

El límite por defecto está en `notification_profile.max_per_hour` y `max_per_day`.
Para usuarios sin perfil: valores por defecto del sistema (20/hora, 100/día).

Los eventos clase A nunca son rate-limited — el rate limiter los pasa siempre.
Solo clase B y C aplican rate limiting.

---

## 6. Verificación de sesión y CAEP (session_check.rs + caep/receiver.rs)

### 6.1 Verificación de ctx_id

El núcleo mantiene una caché local (Redis) de ctx_ids revocados. Antes de despachar,
consulta si el ctx_id está en la lista de revocados.

```
Caché Redis: SET revoked_ctx:{ctx_id} 1 EX {ttl_sesion_max}
```

Cuando llega un `CaepEvent { event_type: "session-revoked", subject_ctx_id }`:
1. Agrega `revoked_ctx:{subject_ctx_id}` a Redis
2. Busca en `bnotify.notification_event` todos los registros con ese ctx_id y status IN ('PENDING', 'FAILED_RETRYING')
3. Cancela esos registros: `UPDATE SET status='FAILED_PERMANENT', last_error='ctx_id_revocado_CAEP'`
4. Los registros cancelados no van a DLQ — van a un estado especial `CANCELLED_BY_CAEP`

### 6.2 SLA de suspensión

BNOTIFY-002 §5 establece que bNotify suspende entregas en < 30 segundos tras recibir
`session-revoked`. Con la caché Redis y el worker pool, el SLA es alcanzable:
- CAEP llega → caché actualizada en < 1ms
- Siguiente ciclo del worker (cada 5s para clase B, 1s para clase A) → verifica caché → cancela
- Peor caso: 5s para clase B, 1s para clase A. Muy por debajo de los 30s del SLA.

---

## 7. Resolución de plantillas (template.rs)

### 7.1 Prioridad de búsqueda de plantilla

```
1. Plantilla del tenant_id del intent + event_type + canal + locale
2. Plantilla global (tenant_id IS NULL) + event_type + canal + locale
3. Plantilla global + event_type + canal + locale='es' (fallback idioma)
4. Si ninguna: alerta en log, entrega sin renderizar (body = template_data serializado)
```

### 7.2 Motor de renderizado

El motor es Tera (template engine en Rust, tipo Jinja2) o minijinja.
Variables: `{{ variable_name }}` con los pares de `template_data` del DispatchRequest.

```toml
# Cargo.toml — crate de templates
tera = "1.20"      # O minijinja = "2.x" — decidir en la implementación
```

---

## 8. Configuración del daemon (config/mod.rs)

```toml
# /etc/bnotify/config.toml
[server]
socket_path = "/run/bos/bnotify.sock"
socket_mode = 0o660

[database]
postgres_url = "postgresql://bnotify_rw:${BNOTIFY_DB_PASS}@postgres.infra:5432/SBOS_db"
max_pool_size = 20

[redis]
url = "redis://redis-cluster.infra:6379"
dedup_ttl_secs = 86400   # 24h ventana de deduplicación
rate_window_secs = 60

[nats]
url = "nats://nats.infra:4222"
stream_name = "BNOTIFY_EVENTS"

[workers]
pool_a_size = 10
pool_b_size = 5
pool_c_size = 3
worker_poll_interval_ms = 1000

[bauth_grpc]
endpoint = "http://unix:///run/bos/bauth.sock"   # Unix socket (SBOS-050)
session_cache_ttl_secs = 30

[rate_limits]
default_per_hour = 20
default_per_day = 100
```

---

## 9. Healthcheck y observabilidad

```protobuf
// Health: ya definido en BNOTIFY-001
rpc Health(HealthRequest) returns (HealthResponse)
// HealthResponse.adapter_status: estado de cada adaptador registrado
```

Métricas Prometheus expuestas en `/metrics` (puerto 9450 — SBOS-050):

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `bnotify_dispatch_total` | Counter | Intents recibidos por status |
| `bnotify_delivery_total` | Counter | Entregas por canal y status |
| `bnotify_queue_depth` | Gauge | Profundidad de cola por clase |
| `bnotify_rate_limited_total` | Counter | Rechazos por rate limit |
| `bnotify_dlq_total` | Counter | Entradas en DLQ por clase |
| `bnotify_caep_events_total` | Counter | Eventos CAEP recibidos por tipo |
| `bnotify_dispatch_latency_ms` | Histogram | Latencia del pipeline Dispatch (p50/p95/p99) |

---

## 10. Definición de terminado — verificaciones obligatorias

```bash
# 1. Compilación
cargo build --release --target x86_64-unknown-linux-musl 2>&1 | tail -5

# 2. Tests unitarios
cargo nextest run --workspace 2>&1 | tail -10

# 3. Clippy sin warnings
cargo clippy -- -D warnings 2>&1 | tail -5

# 4. Dispatch exitoso con DispatchRequest clase A
grpcurl -plaintext -d '{"intent_id":"...", "ctx_id":"...", ...}' \
  unix:///run/bos/bnotify.sock bnotify.v1.NotifyDispatcher/Dispatch

# 5. Rate limiting funciona
# (enviar 21 events del mismo tipo al mismo usuario en 1 minuto)

# 6. Deduplicación funciona
# (enviar el mismo intent_id dos veces — segunda retorna REJECTED_DUPLICATE)
```

---

*BNOTIFY-010 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El núcleo no conoce los canales. Los canales no conocen el núcleo. La frontera entre ellos es el proto.*
