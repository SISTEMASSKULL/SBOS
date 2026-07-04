# Plan de Desarrollo — Context Plane (Plano de Contexto Distribuido)

**Sesión:** S-35 (corregido S-35v2)
**Fecha:** 2026-05-20
**Fuente:** SBOS-049-CONTEXT-PLANE.md v3.0 (HUMAN-DOC, 824 líneas)
**Fase A ejecutada por:** Compositor
**Estado del gate:** ABIERTO (2 gaps críticos, 2 altos)
**Corrección v2:** HTTP REST vetado — toda comunicación es WebSocket (Unix socket + TCP :9443)

---

## 1. Resumen Ejecutivo

El **Context Plane** es la capa que dota de significado empresarial a todo evento en la infraestructura SBOS. Resuelve el problema de que Ubuntu, Kubernetes y Keycloak entienden aspectos técnicos aislados, pero ninguno entiende la semántica de negocio combinada.

> Ubuntu sabe qué máquina existe. Kubernetes sabe qué pod corre. Keycloak sabe quién es el usuario. **SBOS sabe qué significa todo eso junto.**

El **bos (IAM Installer)** es el dueño del Context Plane. Esta etapa añade 6 acciones WebSocket, 4 comandos CLI, cliente Redis, y una tabla de base de datos al binario existente del bos. **Toda comunicación es por WebSocket** — el bos no expone REST bajo ninguna circunstancia.

---

## 2. Arquitectura General

```
┌──────────────────────────────────────────────────────────────────┐
│                   CONTEXT PLANE (propiedad del bos)                │
│                                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐                │
│  │  Redis   │  │ bkernel  │  │  OTel Collector  │                │
│  │ Registry │  │   _db    │  │ Baggage Processor│                │
│  │ O(1) TTL │  │ sessions │  │ (spans + logs)   │                │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘                │
│       │             │                 │                           │
│       │    ┌────────┴────────┐        │                           │
│       │    │  pgx/v5 (solo   │        │                           │
│       │    │  context_sess.) │        │                           │
│       │    └────────┬────────┘        │                           │
│       │             │                 │                           │
│  ┌────┴─────────────┴─────────────────┴───────────────────┐      │
│  │                   bos IAM Installer                     │      │
│  │                                                         │      │
│  │  WebSocket Actions (dispatcher en ws.go):                │      │
│  │    "context_create"        ← crea ctx_id al login       │      │
│  │    "context_switch"        ← context switching          │      │
│  │    "context_invalidate"    ← invalidar ctx (logout)     │      │
│  │    "context_lookup"        ← lookup por ctx_id          │      │
│  │    "context_list"          ← listar ctx activos tenant  │      │
│  │    "context_invalidate_all"← suspensión tenant          │      │
│  │                                                         │      │
│  │  Canales:                                               │      │
│  │    Unix socket: /run/bos/bos.sock  (bosctl → bos)       │      │
│  │    TCP :9443:  /ws                 (Kong, Core UI, etc) │      │
│  └────────────────────┬────────────────────────────────────┘      │
│                       │                                           │
│  ┌────────────────────┴────────────────────────────────────┐      │
│  │  Kong Plugin SBOS-Context (Lua)                          │      │
│  │  Extrae ctx_id del baggage → Redis GET directo (O(1))   │      │
│  │  → No llama al bos en el hot path (≤1ms vs ~5ms WS)     │      │
│  └─────────────────────────────────────────────────────────┘      │
│                                                                   │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────────────────┐     │
│  │ Centrifugo  │  │  bAuth   │  │ bKernel (WAL + audit)    │     │
│  │ real-time   │  │ BitMask  │  │ context_sessions table   │     │
│  └─────────────┘  └──────────┘  └──────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### Flujo de lookup de contexto (hot path, por cada request)

```
Request HTTP → Kong
  → Plugin extrae ctx_id del header baggage
  → Redis GET ctx:skull:ctx-88291-a4f9   (directo, O(1), ≤1ms)
  → ¿Existe y TTL > 0?
      SÍ → inyecta headers internos (tenant, empresa, pos, user)
      NO → HTTP 401
  → Kong NUNCA llama al bos en el hot path
  → El bos escribe en Redis en create/switch/invalidate
  → Kong solo LEE Redis (read-only, sin latencia extra)
```

Este diseño es superior al REST original: Kong no depende del bos para cada request, eliminando un punto de fallo y reduciendo latencia.

---

## 3. Ciclo de Vida de una Sesión

```
FASE 1 — PRE-AUTH (Device Context)
  Dispositivo arranca → banexus detecta → bos crea dctx_id
  BitMask = 0x0 (nadie autenticado)
  Usuario puede: YouTube, LibreOffice, herramientas sin BitMask

FASE 2 — AUTH (context.promoted)
  Usuario presenta credencial → bAuth valida 3 dominios → BitMask calculado
  bhnexus → bos (WebSocket action: "context_create") → ctx_id generado
  bos escribe en Redis (cache O(1)) + bkernel_db (auditoría)
  dctx_id → ctx_id (evento context.promoted)
  Historial pre-auth preservado

FASE 3 — ACTIVO (Context Session)
  Cada acción gobernada por bits del BitMask (64 bits)
  Chapas, cajón POS, apps: todo mediado por banexus + bAuth + ctx_id
  Trazabilidad completa: quién, dónde, qué tenant, qué POS, qué hizo
  Kong valida ctx_id en cada request vía Redis directo (no llama al bos)

FASE 4 — LOGOUT
  ctx invalidado → bos recibe "context_invalidate" vía WebSocket
  bos borra ctx de Redis → actualiza status en bkernel_db
  bAuth notifica bhnexus → BitMask = 0
  Dispositivo vuelve a pre-auth
  Audit trail completo preservado
```

---

## 4. Fases de Implementación

### Fase 0 — Fundaciones (N0)
**Objetivo:** Crear el paquete `internal/context/` con tipos, cliente Redis, y DDL.

**Archivos nuevos:**
| Archivo | Propósito | Líneas est. |
|---|---|---|
| `src/internal/context/context.go` | Tipos: ContextSession, DeviceContext, ctx_id, constantes | ~80 |
| `src/internal/context/registry.go` | Redis client: CRUD de context sessions, TTL, invalidación, lookup | ~180 |
| `src/internal/context/session.go` | Validación, serialización JSON, transiciones de estado | ~100 |
| `src/internal/context/config.go` | ContextConfig struct (Redis addr, password, DB, TTL, bkernel_db) | ~60 |
| `migrations/bkernel_db/001-context-sessions.sql` | DDL tabla particionada | ~40 |

**Archivos modificados:**
| Archivo | Cambio |
|---|---|
| `src/internal/config/config.go` | Agregar `ContextConfig` al struct Config |
| `src/go.mod` | Agregar `github.com/redis/go-redis/v9` + `github.com/jackc/pgx/v5` |
| `staging/bos.toml` | Agregar sección `[context]` |

**Dependencias:** Ninguna (es el nivel base)

**Verificación:**
```bash
go build ./internal/context/...
go test ./internal/context/... -v
```

---

### Fase 1 — WebSocket Actions (N1)
**Objetivo:** Añadir las 6 acciones de contexto al dispatcher WebSocket existente.

**El bos actual ya tiene WebSocket funcionando.** El dispatcher en `server/ws.go` recibe mensajes JSON con `{type: "request", action: "...", params: {...}}` y responde `{type: "response", ok: true, data: {...}}`. Esta fase extiende ese dispatcher sin añadir nuevas rutas HTTP.

**Archivos nuevos:**
| Archivo | Propósito | Líneas est. |
|---|---|---|
| `src/internal/server/context_ws.go` | 6 handlers de acciones WebSocket para contexto | ~200 |

**Archivos modificados:**
| Archivo | Cambio |
|---|---|
| `src/internal/server/ws.go` | Agregar casos al switch del dispatcher: context_create, context_switch, context_invalidate, context_lookup, context_list, context_invalidate_all |

**Acciones WebSocket (reemplazan los endpoints REST del SBOS-049 §10.1):**

```
action: "context_create"
  params:  {tenant, empresa, sucursal, pos, user_id, kc_session}
  response: {ctx_id, expires_at, ...}

action: "context_switch"
  params:  {ctx_id, target}   ← target = "skull/inka/lapaz/pos7"
  response: {new_ctx_id, previous_ctx_id}

action: "context_invalidate"
  params:  {ctx_id}
  response: {invalidated: true}

action: "context_lookup"
  params:  {ctx_id}
  response: {ctx_id, tenant, empresa, sucursal, pos, user_id, pod, ...}

action: "context_list"
  params:  {tenant}
  response: [{ctx_id, user_id, created_at, ...}, ...]

action: "context_invalidate_all"
  params:  {tenant}
  response: {invalidated_count: N}
```

**Dependencias:** Fase 0

**Verificación:**
```bash
# Probar vía bosctl (Fase 2) o vía script de prueba con wscat
# Conectar al WebSocket del bos y enviar acción de prueba:
echo '{"type":"request","id":"test-1","action":"context_lookup","params":{"ctx_id":"ctx-test-0001"}}' \
```

---

### Fase 2 — CLI bosctl context (N2)
**Objetivo:** Añadir el subcomando `bosctl context` con 4 operaciones, usando WebSocket igual que todos los demás comandos bosctl.

**Archivos nuevos:**
| Archivo | Propósito | Líneas est. |
|---|---|---|
| `src/cmd/bosctl/context.go` | cmdContext dispatcher + 4 subcomandos | ~150 |

**Archivos modificados:**
| Archivo | Cambio |
|---|---|
| `src/cmd/bosctl/main.go` | Agregar `case "context"` al switch + usage() |

**Comandos:**
```bash
bosctl context list --tenant=skull           # → wsRequest("context_list", {tenant})
bosctl context inspect ctx-88291-a4f9        # → wsRequest("context_lookup", {ctx_id})
bosctl context invalidate ctx-88291-a4f9     # → wsRequest("context_invalidate", {ctx_id})
bosctl context history --user=3397708 --days=7  # → wsRequest("context_history", {user, days})
```

**Dependencias:** Fase 1

**Verificación:**
```bash
```

---

### Fase 3 — Infraestructura y Plugins (N3)
**Objetivo:** Crear Kong plugin Lua (consulta Redis directo, sin llamar al bos), configuración OTel, y Centrifugo.

**Cambio clave vs plan original:** El Kong plugin NO llama al bos. Consulta Redis directamente para validar ctx_id en el hot path. Esto elimina latencia de red y un punto de fallo. El bos escribe en Redis; Kong lee de Redis.

**Archivos nuevos:**
| Archivo | Propósito | Líneas est. |
|---|---|---|
| `fichas/netserver/kong/plugins/sbos-context/handler.lua` | Extrae baggage, Redis GET directo, inyecta headers | ~100 |
| `fichas/netserver/kong/plugins/sbos-context/schema.lua` | Config schema (Redis host, port, DB) | ~40 |
| `fichas/monitorserver/otelcollector/config/otel-collector.yaml` | Pipeline con Baggage Processor | ~60 |

**Flujo del Kong plugin (corregido — sin REST):**
```lua
-- handler.lua (pseudocódigo)
function SBOSContextHandler:access(conf)
  local baggage = kong.request.get_header("baggage")
  if not baggage then return end  -- Sin contexto, dejar pasar (decisión del upstream)

  local ctx_id = extract_ctx_id(baggage)
  if not ctx_id then
    return kong.response.exit(401, {message = "ctx_id requerido"})
  end

  -- Redis GET directo — el bos ya escribió este key en create/switch
  local red = redis.connect(conf.redis_host, conf.redis_port)
  local ctx_json = red:get("ctx:skull:" .. ctx_id)
  if not ctx_json then
    return kong.response.exit(401, {message = "contexto inválido o expirado"})
  end

  -- Inyectar headers internos para el servicio destino
  local ctx = cjson.decode(ctx_json)
  kong.service.request.set_header("X-SBOS-Tenant", ctx.tenant)
  kong.service.request.set_header("X-SBOS-Empresa", ctx.empresa)
  kong.service.request.set_header("X-SBOS-POS", ctx.pos_logico)
  kong.service.request.set_header("X-SBOS-User", ctx.user_id)
  kong.service.request.set_header("X-SBOS-CtxID", ctx.ctx_id)
end
```

**Archivos modificados:**
| Archivo | Cambio |
|---|---|
| `fichas/monitorserver/otelcollector/config/otel-collector.yaml` | Agregar batch + attributes processors |

**Dependencias:** Fase 0 (Redis funcionando y poblado por el bos)

**Verificación:**
```bash
# Escribir un ctx de prueba en Redis (simulando que el bos lo creó)

# Request HTTP con baggage
curl -H "baggage: ctx.id=ctx-test-0001,tenant.id=skull" http://kong:8000/api/test

# Kong debe inyectar los headers X-SBOS-* en el request al upstream
```

---

### Fase 4 — Eventos y Reglas bKernel (N4)
**Objetivo:** Crear reglas YAML para que bKernel procese eventos de contexto.

**Archivos nuevos:**
| Archivo | Propósito | Líneas est. |
|---|---|---|
| `blibs/bkernel/rules/context/context-created.yml` | Regla para context.created → audit_events | ~30 |
| `blibs/bkernel/rules/context/context-switched.yml` | Regla para context.switched | ~30 |
| `blibs/bkernel/rules/context/context-expired.yml` | Regla para context.expired | ~30 |

**Dependencias:** Fase 1 + bKernel operativo (G1 en GAPS-VALIDATION.md). Esta fase NO puede completarse hasta que bKernel tenga código funcional.

**Verificación:** Condicionada a bKernel operativo.

---

## 5. Resumen de Archivos

```
Archivos NUEVOS:     13
Archivos MODIFICADOS:  5
Total:                18
```

| # | Archivo | Fase | Acción |
|---|---------|------|--------|
| 1 | `src/internal/context/context.go` | F0 | Nuevo |
| 2 | `src/internal/context/registry.go` | F0 | Nuevo |
| 3 | `src/internal/context/session.go` | F0 | Nuevo |
| 4 | `src/internal/context/config.go` | F0 | Nuevo |
| 5 | `migrations/bkernel_db/001-context-sessions.sql` | F0 | Nuevo |
| 6 | `src/internal/server/context_ws.go` | F1 | Nuevo |
| 7 | `src/cmd/bosctl/context.go` | F2 | Nuevo |
| 8 | `fichas/netserver/kong/plugins/sbos-context/handler.lua` | F3 | Nuevo |
| 9 | `fichas/netserver/kong/plugins/sbos-context/schema.lua` | F3 | Nuevo |
| 10 | `fichas/monitorserver/otelcollector/config/otel-collector.yaml` | F3 | Nuevo |
| 11 | `blibs/bkernel/rules/context/context-created.yml` | F4 | Nuevo |
| 12 | `blibs/bkernel/rules/context/context-switched.yml` | F4 | Nuevo |
| 13 | `blibs/bkernel/rules/context/context-expired.yml` | F4 | Nuevo |
| 14 | `src/internal/config/config.go` | F0 | Modificar |
| 15 | `src/go.mod` | F0 | Modificar |
| 16 | `staging/bos.toml` | F0 | Modificar |
| 17 | `src/internal/server/ws.go` | F1 | Modificar |
| 18 | `src/cmd/bosctl/main.go` | F2 | Modificar |

### Archivos eliminados vs plan v1 (REST)

| Archivo eliminado | Motivo |
|---|---|
| `src/internal/server/context_api.go` | No se crea — reemplazado por context_ws.go (WebSocket) |
| `blibs/bkernel/rules/context/README.md` | Innecesario — documentado en este plan |
| `src/internal/server/api.go` (modificación) | No se modifica — no se añaden rutas REST |

---

## 6. GAPS Detectados

```
CRÍTICOS: 2   (bloquean Fase B)
ALTOS:    2   (bloquean fases específicas)
MEDIOS:   3   (deseables, no bloqueantes)
BAJOS:    3   (documentación y configuración)
```

### Críticos

| # | Gap | Impacto | Resolución |
|---|-----|---------|------------|
| **C1** | Kong no tiene acceso Redis directo para validar ctx_id. Necesita conectarse a la misma instancia Redis que el bos. | Sin validación en Kong, el ctx_id no se verifica en el API Gateway. | Kong plugin Lua usa `redis.connect()` directamente contra la instancia Redis compartida. Misma Redis que el bos usa para el Context Registry. |
| **C2** | No existe cliente Redis en el bos. El Context Registry requiere lookup O(1) con TTL. | Sin Redis, el bos no puede crear/consultar contextos. | Agregar `go-redis/v9` a `go.mod`, crear `internal/context/registry.go` |

### Altos

| # | Gap | Impacto | Resolución |
|---|-----|---------|------------|
| **C3** | No existe DDL `context_sessions`. No hay directorio `migrations/`. | Sin tabla no hay auditoría histórica (ISO 27001 A.8.15). | Crear `migrations/bkernel_db/001-context-sessions.sql` con DDL del §12 de SBOS-049 |
| **C4** | Kong Plugin SBOS-Context no existe (Lua). Sin el plugin, Kong no inyecta headers de contexto. | Los servicios upstream no reciben X-SBOS-* headers. | Crear `fichas/netserver/kong/plugins/sbos-context/` con handler.lua (Redis directo) + schema.lua |

### Medios

| # | Gap | Impacto | Resolución |
|---|-----|---------|------------|
| **C5** | bosctl sin subcomando `context`. | El administrador no tiene CLI para gestionar contextos. | Crear `cmd/bosctl/context.go` (Fase 2) |
| **C6** | OTel Collector sin Baggage Processor configurado. | ctx_id no se propaga automáticamente a logs/trazas. | Agregar config YAML con batch + attributes processors (Fase 3) |
| **C7** | Sin reglas bKernel para eventos de contexto. | Los eventos context.* no se reflejan en audit_events. | Crear reglas YAML en `blibs/bkernel/rules/context/` (Fase 4, depende de bKernel) |

### Bajos

| # | Gap | Impacto | Resolución |
|---|-----|---------|------------|
| **C8** | Config del bos sin sección `[context]`. | El Context API no puede inicializar conexiones. | Agregar `ContextConfig` a `config.go` + sección `[context]` en `bos.toml` |
| **C9** | Centrifugo sin canales de contexto. | El frontend no recibe notificaciones real-time de context switches. | Actualizar config de Centrifugo (SBOS-040) |
| **C10** | bkernel_db no accesible desde el bos (sin driver PostgreSQL). | El bos no puede persistir sesiones directamente en context_sessions. | Agregar `pgx/v5` a `go.mod` para escritura directa |

---

## 7. Decisiones Arquitectónicas

### DA-01: WebSocket puro — vetado HTTP REST
**Decisión:** Toda comunicación con el bos es por WebSocket. Las 6 operaciones de contexto se implementan como acciones en el dispatcher WebSocket existente. **No se agregan rutas REST bajo ninguna circunstancia.**
**Fundamento:** HTTP REST está vetado en el bos por decisión del HITL. El WebSocket ya funciona para todos los comandos bosctl existentes (install, status, health, repair, etc.). Las acciones de contexto siguen exactamente el mismo patrón `{type: "request", action: "...", params: {...}}`.

### DA-02: Kong consulta Redis directo, NO llama al bos
**Decisión:** El Kong plugin valida ctx_id haciendo Redis GET directo contra la misma instancia Redis que el bos usa como Context Registry. No establece conexión WebSocket ni HTTP al bos para el hot path.
**Alternativa rechazada:** Kong → WebSocket → bos → Redis. Demasiada latencia (~5ms vs ≤1ms), añade el bos como punto de fallo en cada request.
**Fundamento:** El bos escribe en Redis en create/switch/invalidate. Kong solo lee. Esto es una separación limpia de responsabilidades: el bos es el writer autoritativo, Kong es el reader de alta velocidad. Redis actúa como el contrato compartido.

### DA-03: Persistencia dual (Redis + bkernel_db)
**Decisión:** El bos escribe en Redis (cache, O(1)) y en bkernel_db (persistencia, auditoría) simultáneamente durante create/switch/invalidate.
**Alternativa rechazada:** Solo Redis (sin auditoría) o solo PostgreSQL (sin rendimiento).
**Fundamento:** SBOS-049 §8.3 define almacenamiento dual explícitamente. Cumple con ISO 27001 A.8.15 (audit trail) y garantiza latencia de lookup < 1ms vía Redis.

### DA-04: Conexión directa del bos a bkernel_db vía pgx
**Decisión:** El bos usa `pgx/v5` para escribir directamente en `context_sessions`.
**Alternativa rechazada:** Delegar toda escritura a bKernel vía WAL.
**Fundamento:** bKernel está en estado "en-concepción" (0 líneas Rust, G1 en GAPS-VALIDATION.md). No podemos bloquear el Context Plane esperando a bKernel. Cuando bKernel esté operativo, replicará estas escrituras vía WAL.

---

## 8. Stack Tecnológico

| Componente | Tecnología | Rol en Context Plane |
|---|---|---|
| **bos IAM Installer** | Go 1.22+, binario estático | Dueño del Context Plane. Escribe en Redis + bkernel_db. Expone acciones vía WebSocket. |
| **Redis client (bos)** | go-redis/v9 | CRUD de context sessions con TTL |
| **PostgreSQL driver (bos)** | pgx/v5 | Escritura directa en context_sessions |
| **Redis client (Kong)** | Lua redis library | Kong lee ctx_id en hot path (≤1ms) |
| **Redis server** | Redis 7.x | Context Registry cache. Compartido bos + Kong. |
| **bkernel_db** | PostgreSQL | Tabla context_sessions (particionada) + audit_events |
| **Kong plugin** | Lua 5.1 (Kong OSS 3.9.x) | Valida ctx_id vía Redis, inyecta headers X-SBOS-* |
| **OTel Collector** | OpenTelemetry Collector | Baggage Processor: extrae ctx en spans/logs |
| **Centrifugo** | Centrifugo | Notificaciones real-time de context switches |
| **Propagación** | W3C Trace Context + OTel Baggage | Headers estándar en todos los requests |

---

## 9. Plan de Ejecución Recomendado

```
SEMANA 1: Fase 0 — Fundaciones
  Día 1-2: internal/context/ (4 archivos Go) + config + go.mod (go-redis + pgx)
  Día 3:   migrations/ DDL + prueba de conexión Redis + PostgreSQL
  Día 4:   Tests unitarios del registry (Redis mock + pgx mock)

SEMANA 2: Fase 1 — WebSocket Actions
  Día 1-2: context_ws.go (6 handlers de acciones WebSocket)
  Día 3:   Modificar ws.go (agregar casos al dispatcher)

SEMANA 3: Fase 2 — CLI
  Día 1:   context.go (4 subcomandos, mismo patrón wsRequest que el resto)
  Día 2:   main.go (switch + usage)

SEMANA 4: Fase 3 — Infraestructura
  Día 1-2: Kong plugin Lua (Redis directo, sin REST/WS al bos)
  Día 3:   OTel config (Baggage Processor)
  Día 4:   Integración: escribir ctx en Redis → request HTTP → verificar X-SBOS-* headers

FUTURO: Fase 4 — Reglas bKernel
  Bloqueada hasta que bKernel tenga código funcional (G1 en GAPS-VALIDATION.md)
```

---

## 10. Verificación por Fase

### Fase 0
```bash
# Compilación
podman run --rm -v "$SRC:/src:Z" -w /src -e CGO_ENABLED=0 \
  golang:1.22 go build ./internal/context/...

# Unit tests
podman run --rm -v "$SRC:/src:Z" -w /src -e CGO_ENABLED=0 \
  golang:1.22 go test ./internal/context/... -v

```

### Fase 1
```bash
# Probar acciones WebSocket desde el contenedor
# (requiere websocat o script de prueba Go)
```

### Fase 2
```bash
bosctl context list --tenant=skull
bosctl context inspect ctx-test-0001
bosctl context invalidate ctx-test-0001
bosctl context history --user=3397708 --days=7
```

### Fase 3
```bash
# Simular creación de contexto por el bos
  '{"ctx_id":"ctx-test-0001","tenant":"skull","empresa":"maya","sucursal":"lapaz","pos_logico":"POS-23","user_id":"3397708"}' \
  EX 3600

# Verificar que Kong inyecta headers
curl -H "baggage: ctx.id=ctx-test-0001,tenant.id=skull" \
  http://kong:8000/api/test -v 2>&1 | grep X-SBOS-
```

---

## 11. Comparación con el Plan v1 (REST)

| Aspecto | Plan v1 (REST) | Plan v2 (WebSocket puro) |
|---|---|---|
| Comunicación bos | REST + WebSocket híbrido | **Solo WebSocket** |
| Kong → bos | REST GET /api/v1/context/{ctx_id} | **Redis GET directo** (sin llamar al bos) |
| Latencia lookup Kong | ~5ms (HTTP al bos) | **≤1ms** (Redis directo) |
| Punto de fallo en hot path | bos + Redis | **Solo Redis** |
| Archivos nuevos | 14 | 13 |
| `context_api.go` | REST handlers | **context_ws.go** (WebSocket handlers) |
| Modificaciones server | api.go + ws.go | **Solo ws.go** |
| Complejidad | Mayor (dos protocolos) | **Menor** (un solo protocolo) |

---

## 12. Trazabilidad

| Sección | Fuente |
|---|---|
| §1 Resumen | SBOS-049 §1, §3 |
| §2 Arquitectura | SBOS-049 §10, §11, §13 — corregido a WebSocket puro |
| §3 Ciclo de Vida | SBOS-049 §16 |
| §4 Fases | Análisis Compositor S-35 — corregido v2 |
| §5 Archivos | SBOS-049 §13 — simplificado (sin REST) |
| §6 Gaps | SBOS-049 completo + GAPS-VALIDATION.md — corregido C1 |
| §7 Decisiones | SBOS-049 §10, §8, §14 + doctrina BOS (HTTP vetado) |
| §8 Stack | SBOS-005, SBOS-023, SBOS-029, SBOS-040 |
| §9 Plan | Estimaciones basadas en fases A-D previas (S-30 a S-33) |
| §11 Comparación | Corrección v2 — contraste con plan original |

---

## 13. Referencias

- [SBOS-049-CONTEXT-PLANE.md](../v6/SBOS-049-CONTEXT-PLANE.md) — Documento fuente (HUMAN-DOC v3.0)
- [SBOS-018-DAEMON-BOS.md](../v6/SBOS-018-DAEMON-BOS.md) — Especificación del bos IAM Installer
- [SBOS-023-DAEMON-BKERNEL.md](../v6/SBOS-023-DAEMON-BKERNEL.md) — Especificación de bKernel
- [SBOS-021-DAEMON-BAUTH.md](../v6/SBOS-021-DAEMON-BAUTH.md) — Especificación de bAuth (BitMask)
- [SBOS-039-DAEMON-NEXUS.md](../v6/SBOS-039-DAEMON-NEXUS.md) — Especificación de banexus/bhnexus
- [SBOS-037-DEPLOY-SEED.md](../v6/SBOS-037-DEPLOY-SEED.md) — Seed file del tenant
- [GAPS-VALIDATION.md](../ia/GAPS-VALIDATION.md) — Estado actual de gaps SBOS
- [guia-desarrollador.md](project/developer/guia-desarrollador.md) — Guía del desarrollador BosAgent

---

_SKULL · SBOS · PLAN-DESARROLLO-CONTEXT-PLANE v2 · S-35 · Mayo 2026_
_Generado por el Compositor en Fase A. Corregido v2: HTTP REST vetado → WebSocket puro + Kong→Redis directo._
_Gate ABIERTO — pendiente autorización del HITL para Fase B._