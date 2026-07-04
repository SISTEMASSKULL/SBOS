# BAUTH-VERIFICACION-JSONRPC.md — Auditoría de Cumplimiento ADR-019/020

**Versión:** 1.0.0 · **Fecha:** 2026-06-21 · **Autor:** sbos-coordinador  
**Propósito:** Verificar que bAuth cumple el principio de Interface Dual:
todas las operaciones expuestas vía JSON-RPC 2.0 sobre Unix socket,
siguiendo la convención `bauth.<modulo>.<operacion>`.

---

## 1. Verificación de Cumplimiento

### 1.1 Transporte — Unix Socket (ADR-020 §2)

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| Unix socket en `/run/bos/bauth.sock` | ✅ CUMPLE | `src/server/mod.rs:44` — `UnixListener::bind(path)` |
| Permisos 0660 | ✅ CUMPLE | `src/server/mod.rs:46` — `Permissions::from_mode(cfg.socket_perms)` |
| Grupo `bosagent` | ✅ CUMPLE | `src/server/mod.rs:48` — `change_group(path, &cfg.socket_group)` |
| Sin HTTP/TCP entre daemons | ✅ CUMPLE | Cero `TcpListener` o puertos TCP en bAuth |
| Conexiones concurrentes | ✅ CUMPLE | `max_connections` configurable, rechaza al exceder |
| Shutdown graceful (DrainManager) | ✅ CUMPLE | `src/server/mod.rs:56` — `drain.connection_start()` / `connection_end()` |

### 1.2 Naming Convention — `<componente>.<modulo>.<operacion>` (ADR-020 §3)

| Método | Formato | Registrado en código | Funcional |
|--------|---------|---------------------|-----------|
| `bauth.health.check` | ✅ `bauth.health.check` | ✅ `main.rs:91` | ✅ Probado |
| `bauth.policy.evaluate` | ✅ `bauth.policy.evaluate` | ✅ `main.rs:93` | ✅ Probado |
| `bauth.role.compute_mask` | ✅ `bauth.role.compute_mask` | ✅ `main.rs:97` | ✅ Probado |
| `bauth.ctx.validate` | ✅ `bauth.ctx.validate` | ✅ `main.rs:101` | ✅ Probado |

### 1.3 Protocolo — JSON-RPC 2.0 (ADR-019 §2)

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| Request: `{jsonrpc, method, params, id}` | ✅ CUMPLE | `src/server/jsonrpc.rs:18-25` — struct `Request` |
| Response: `{jsonrpc, result, error, id}` | ✅ CUMPLE | `src/server/jsonrpc.rs:28-35` — struct `Response` |
| Códigos de error estándar (-32601, -32600, -32700) | ✅ CUMPLE | `src/server/jsonrpc.rs:48-61` — `method_not_found`, `invalid_request`, `parse_error` |
| Dispatcher genérico (HashMap<String, Handler>) | ✅ CUMPLE | `src/server/jsonrpc.rs:73-74` — `handlers: HashMap<String, Arc<dyn JsonRpcHandler>>` |
| Handler trait (`handle(params) → Result<Value>`) | ✅ CUMPLE | `src/server/jsonrpc.rs:68-70` — trait `JsonRpcHandler` |

### 1.4 CLI — Interface Dual Vía 1 (ADR-020 §1)

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| CLI conecta vía Unix socket | ✅ CUMPLE | `src/bin/bauthctl.rs:76` — `UnixStream::connect(socket_path)` |
| CLI envía JSON-RPC 2.0 | ✅ CUMPLE | `src/bin/bauthctl.rs:58` — `{"jsonrpc":"2.0","method":"bauth.health.check","id":1}` |
| 7 subcomandos definidos | ⚠️ PARCIAL | `src/bin/bauthctl.rs:26-35` — definidos (Role, User, Auth, Ctx, Sign, Tenant, Sync) pero solo Health implementado |

---

## 2. Gaps — Lo que falta implementar

### 2.1 Handlers JSON-RPC NO implementados

| # | Método | Prioridad | Átomo | Estado |
|---|--------|----------|-------|--------|
| 1 | `bauth.saga.execute` | CRÍTICA | B35.T08 | 🔴 Sin handler |
| 2 | `bauth.saga.validate` | ALTA | B35.T08 | 🔴 Sin handler |
| 3 | `bauth.saga.list` | MEDIA | B40.T03 | 🔴 Sin handler |
| 4 | `bauth.saga.read` | MEDIA | B40.T03 | 🔴 Sin handler |
| 5 | `bauth.method.list` | MEDIA | B40.T01 | 🔴 Sin handler |
| 6 | `bauth.method.read` | MEDIA | B40.T01 | 🔴 Sin handler |
| 7 | `bauth.method.update` | MEDIA | B40.T01 | 🔴 Sin handler |
| 8 | `bauth.policy.list` | MEDIA | B40.T01 | 🔴 Sin handler |
| 9 | `bauth.policy.read` | MEDIA | B40.T01 | 🔴 Sin handler |
| 10 | `bauth.policy.update` | MEDIA | B40.T01 | 🔴 Sin handler |
| 11 | `bauth.config.list` | MEDIA | B40.T01 | 🔴 Sin handler |
| 12 | `bauth.config.read` | MEDIA | B40.T01 | 🔴 Sin handler |
| 13 | `bauth.config.update` | MEDIA | B40.T01 | 🔴 Sin handler |
| 14 | `bauth.crypto.list` | BAJA | B40.T02 | 🔴 Sin handler |
| 15 | `bauth.crypto.read` | BAJA | B40.T02 | 🔴 Sin handler |
| 16 | `bauth.crypto.update` | BAJA | B40.T02 | 🔴 Sin handler |
| 17 | `bauth.federation.list` | BAJA | B40.T02 | 🔴 Sin handler |
| 18 | `bauth.federation.read` | BAJA | B40.T02 | 🔴 Sin handler |
| 19 | `bauth.federation.update` | BAJA | B40.T02 | 🔴 Sin handler |
| 20 | `bauth.compliance.list` | BAJA | B40.T02 | 🔴 Sin handler |
| 21 | `bauth.compliance.read` | BAJA | B40.T02 | 🔴 Sin handler |
| 22 | `bauth.compliance.update` | BAJA | B40.T02 | 🔴 Sin handler |

**Total:** 4 ✅ implementados · 22 🔴 pendientes · 3 ⚠️ bauthctl pendiente

### 2.2 bauthctl — Comandos pendientes

El CLI tiene 7 subcomandos definidos como `enum Command` pero solo `Health` y `Version`
están implementados. Los demás imprimen "(conexión JSON-RPC pendiente)":

| Comando | Subcomandos planeados | Método JSON-RPC que debe invocar |
|---------|----------------------|----------------------------------|
| `role` | list, get, compute, assign | `bauth.role.compute_mask` + nuevos |
| `user` | list, get, auth, revoke | `bauth.saga.execute(auth.password.login)` |
| `auth` | login, mfa, logout | `bauth.saga.execute(auth.password.login)` |
| `ctx` | create, validate, list | `bauth.ctx.validate` |
| `sign` | sign, verify, keygen | Nuevos handlers de firma |
| `tenant` | create, list, delete | Nuevos handlers de tenant |
| `sync` | trigger, status | Nuevos handlers de sync |

---

## 3. Estructura del Dispatcher — Preparado para extensión

El `JsonRpcDispatcher` usa un `HashMap<String, Arc<dyn JsonRpcHandler>>`:

```rust
pub struct JsonRpcDispatcher {
    handlers: HashMap<String, Arc<dyn JsonRpcHandler>>,
}

impl JsonRpcDispatcher {
    pub fn register(&mut self, method: &str, handler: Arc<dyn JsonRpcHandler>) {
        self.handlers.insert(method.to_string(), handler);
    }
}
```

**Capacidad:** Ilimitada — el HashMap crece dinámicamente. No hay límite de handlers.
Agregar un nuevo método es 1 línea: `dispatcher.register("bauth.X.Y", Arc::new(Handler));`

El patrón para crear un handler nuevo es siempre el mismo:

```rust
pub struct NuevoHandler { pub pg_pool: Option<sqlx::PgPool> }

#[async_trait::async_trait]
impl JsonRpcHandler for NuevoHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        // 1. Extraer parámetros de params
        // 2. Validar
        // 3. Ejecutar lógica (consultar BD, invocar saga, etc.)
        // 4. Retornar resultado como serde_json::Value
    }
}

// En main.rs:
dispatcher.register("bauth.nuevo.metodo", Arc::new(NuevoHandler { pg_pool }));
```

---

## 4. Verificación de que NO hay HTTP

bAuth **no expone ningún puerto TCP**. Verificado:

- ✅ Cero `TcpListener` en `src/`
- ✅ Cero `hyper::`, `actix-web`, `warp::`, `axum::` en dependencias
- ✅ Cero `:9450`, `:9451`, `:9452`, `:9453` en código
- ✅ Transporte exclusivo: `tokio::net::UnixListener` en `src/server/mod.rs`
- ✅ Cumple SBOS-050 P9: "HTTP vetado entre daemons"

---

## 5. Auditoría de TODOS los Daemons

| Daemon | JSON-RPC handlers | Unix socket | HTTP/TCP expuesto | gRPC | Cumple ADR-020 |
|--------|------------------|-------------|-------------------|------|---------------|
| **BosAgent** | ✅ 140 refs | ✅ `/run/bos/bos.sock` | ⚠️ TCP :9443 (Core UI humano, no daemon) | ✅ gRPC en Unix socket `/run/bos/bos-grpc.sock` | ✅ |
| **BauthAgent** | ✅ 10 métodos registrados | ✅ `/run/bos/bauth.sock` | ✅ Cero HTTP | — | ✅ |
| **BkernelAgent** | ✅ `bkernel.dest.*` | ⚠️ Usa TCP `127.0.0.1:9460` | ⚠️ TCP :9460 | ⚠️ 21 refs gRPC | ⚠️ MIGRAR A UNIX SOCKET |
| **BiedataAgent** | ⚠️ 13 refs (planificado) | ❌ NO TIENE | ❌ TCP :9470, :9471, :9472 | — | ❌ VIOLACIÓN |
| **BintelligenceAgent** | ❌ CERO | ⚠️ WebSocket :9493 | ⚠️ :9493 (WebSocket) | — | ❌ VIOLACIÓN |
| **BnexusAgent** | ❌ 1 ref | ⚠️ WebSocket mTLS :9444 | ⚠️ :9444 (WebSocket mTLS) | — | ❌ VIOLACIÓN |

### 5.1 BiedataAgent — VIOLACIÓN CRÍTICA

**Problema:** JSON-RPC 2.0 sobre TCP `:9470`. Sin Unix socket.
**ADR-020 §2 exige:** `/run/bos/biedata.sock` (0660, grupo bosagent). NUNCA TCP.

**Acción requerida (Issue #BIEDATA-JSONRPC-001):**
```rust
// ANTES (violación):
// JSON-RPC 2.0 server en :9470 (TCP)
TcpListener::bind("0.0.0.0:9470").await

// DESPUÉS (cumplimiento):
// JSON-RPC 2.0 server en /run/bos/biedata.sock (Unix)
UnixListener::bind("/run/bos/biedata.sock")
```

**Métodos que debe exponer:** `biedata.fiscal.factura.obtener_datos`, `biedata.saga.orquestar`, etc.

### 5.2 BintelligenceAgent (bSearch) — VIOLACIÓN CRÍTICA

**Problema:** Cero referencias JSON-RPC. Usa WebSocket pero sin capa JSON-RPC 2.0.
**ADR-020 §3 exige:** `bsearch.query.execute`, `bsearch.index.status`, etc.

**Acción requerida (Issue #BSEARCH-JSONRPC-001):**
- Agregar dispatcher JSON-RPC 2.0 sobre `/run/bos/bsearch.sock`
- Mismo patrón que BauthAgent: `JsonRpcDispatcher` + handlers por método
- WebSocket puede coexistir como Vía 1 (humanos), pero Vía 2 (daemons) DEBE ser JSON-RPC

### 5.3 BkernelAgent — VIOLACIÓN PARCIAL

**Problema:** JSON-RPC escucha en TCP `127.0.0.1:9460`, no en Unix socket.
**SBOS-050 §5:** :9460-:9461 reservados para métricas. La API debe ir en Unix socket.

**Acción requerida (Issue #BKERNEL-JSONRPC-001):**
- Migrar `bkernel.dest.*` a `/run/bos/bkernel.sock`
- Dejar :9460 para métricas Prometheus solamente

### 5.4 BnexusAgent — VIOLACIÓN PARCIAL

**Problema:** Solo 1 referencia JSON-RPC. WebSocket mTLS en :9444 sin capa JSON-RPC.
**ADR-020 §3 exige:** `bhnexus.auth.validate`, `banexus.device.intercept`.

**Acción requerida (Issue #BNEXUS-JSONRPC-001):**
- Agregar dispatcher JSON-RPC 2.0 sobre `/run/bos/bhnexus.sock`
- WebSocket mTLS :9444 sigue siendo Vía 1 para hardware bridges

---

## 6. Verificación CERO HTTP (SBOS-050 P9)

**Principio P9:** HTTP vetado entre daemons. Solo WebSocket y Unix socket.
Todo daemon debe escuchar en `/run/bos/<daemon>.sock`, NUNCA en TCP.

| Daemon | Puerto TCP expuesto | Protocolo | ¿Violación HTTP? | Acción |
|--------|--------------------|-----------|------------------|--------|
| **BosAgent** | :9443 (Core UI) | HTTPS | ✅ OK — interfaz humana, no daemon | — |
| **BosAgent** | `/run/bos/bos.sock` | Unix socket | ✅ OK | — |
| **BauthAgent** | NINGUNO | Unix socket | ✅ ZERO HTTP | — |
| **BkernelAgent** | `127.0.0.1:9460` | TCP | ❌ VIOLACIÓN | Migrar a `/run/bos/bkernel.sock` |
| **BiedataAgent** | `0.0.0.0:9470` | TCP HTTP | ❌ VIOLACIÓN | Migrar a `/run/bos/biedata.sock` |
| **BiedataAgent** | `:9471` métricas | TCP | ⚠️ Permitido (métricas) | Solo Prometheus |
| **BiedataAgent** | `:9472` health | TCP | ⚠️ Permitido (health) | Solo kubelet probe |
| **BintelligenceAgent** | `:9493` | WebSocket (HTTP upgrade) | ❌ VIOLACIÓN | Debe ser Unix socket |
| **BnexusAgent** | `:9444` | WebSocket mTLS | ❌ VIOLACIÓN | Debe ser Unix socket |

### Regla absoluta

```
✅ PERMITIDO:
  - Unix socket /run/bos/<daemon>.sock (WebSocket + JSON-RPC)
  - Puerto TCP solo para Core UI (:9443), métricas (:9471, :9461), health probes
  - WebSocket sobre Unix socket (no necesita puerto TCP)

❌ PROHIBIDO:
  - HTTP/REST entre daemons
  - JSON-RPC sobre TCP
  - WebSocket sobre TCP para daemon-to-daemon
  - Cualquier puerto TCP que no sea Core UI o métricas/health
```

---

## 7. Plan de Corrección

| # | Issue | Daemon | Severidad | Acción | Tiempo est. |
|---|-------|--------|-----------|--------|------------|
| 1 | TCP :9470 → Unix socket | BiedataAgent | CRÍTICA | `TcpListener` → `UnixListener` en `/run/bos/biedata.sock` | 4h |
| 2 | Sin JSON-RPC Vía 2 | BintelligenceAgent | CRÍTICA | Agregar `JsonRpcDispatcher` en `/run/bos/bsearch.sock` | 4h |
| 3 | TCP :9460 → Unix socket | BkernelAgent | ALTA | Migrar JSON-RPC a `/run/bos/bkernel.sock` | 2h |
| 4 | Sin JSON-RPC Vía 2 | BnexusAgent | ALTA | Agregar `JsonRpcDispatcher` en `/run/bos/bhnexus.sock` | 3h |
| 5 | WebSocket Vía 1 pendiente | BauthAgent | BAJA | Agregar WebSocket RPC en mismo socket | 2h (B18) |

---

## 8. Issues Abiertos

### Issue #BIEDATA-001 — CRÍTICO: Sin Interface Dual
- **Estado actual:** JSON-RPC 2.0 sobre TCP `:9470`. Cero Unix socket. Cero WebSocket.
- **Debe ser:** `/run/bos/biedata.sock` con WebSocket (Vía 1) + JSON-RPC 2.0 (Vía 2)
- **Métodos requeridos:** `biedata.fiscal.factura.*`, `biedata.saga.*`
- **Patrón de referencia:** `BauthAgent/src/server/mod.rs` — copiar `UnixListener` + `JsonRpcDispatcher`

### Issue #BSEARCH-001 — CRÍTICO: Falta JSON-RPC Vía 2
- **Estado actual:** WebSocket wss:// en :9493 sobre Unix socket. Cero JSON-RPC.
- **Debe ser:** Mismo socket con WebSocket (Vía 1) + JSON-RPC 2.0 (Vía 2)
- **Métodos requeridos:** `bsearch.query.execute`, `bsearch.index.status`, `bsearch.index.rebuild`
- **Patrón de referencia:** Agregar `JsonRpcDispatcher` (mismo patrón que BauthAgent)

### Issue #BNEXUS-001 — ALTO: Falta JSON-RPC Vía 2
- **Estado actual:** WebSocket mTLS en :9444. JSON-RPC sin implementar.
- **Debe ser:** Mismo socket con WebSocket mTLS (Vía 1) + JSON-RPC 2.0 (Vía 2)
- **Métodos requeridos:** `bhnexus.auth.validate`, `banexus.device.intercept`
- **Patrón de referencia:** Multiplexar JSON-RPC en el mismo puerto que WebSocket

### Issue #BKERNEL-001 — MEDIO: Migrar JSON-RPC a Unix socket
- **Estado actual:** JSON-RPC escucha en TCP `127.0.0.1:9460`
- **Debe ser:** `/run/bos/bkernel.sock` con JSON-RPC 2.0. :9460 solo métricas.
- **Métodos existentes:** `bkernel.dest.add`, `bkernel.dest.list`, `bkernel.dest.get`, `bkernel.dest.pause`

### Issue #BAUTH-001 — BAJO: WebSocket Vía 1 pendiente
- **Estado actual:** JSON-RPC en Unix socket ✅. WebSocket Vía 1 comentado como "pendiente B18".
- **Debe ser:** Agregar WebSocket RPC en el MISMO `/run/bos/bauth.sock` para CLI y Core UI.

---

## 6. Conclusión

| Aspecto | Cumplimiento |
|---------|-------------|
| **Transporte Unix socket** | ✅ 100% — zero HTTP |
| **Protocolo JSON-RPC 2.0** | ✅ 100% — tipos, errores, dispatcher |
| **Naming convention** | ✅ 100% — `bauth.<modulo>.<operacion>` |
| **Interface Dual** | ⚠️ 50% — Vía 2 (JSON-RPC) implementada, Vía 1 (WebSocket RPC) pendiente |
| **Handlers implementados** | ⚠️ 15% — 4/26 implementados |
| **bauthctl CLI** | ⚠️ 10% — estructura definida, solo health funcional |
| **Extensibilidad** | ✅ 100% — dispatcher genérico, agregar handler = 1 línea |

**Veredicto:** bAuth está **arquitectónicamente correcto** — cumple ADR-019 y ADR-020
en su base. El dispatcher genérico permite agregar handlers sin modificar el core.
Los 22 handlers faltantes son implementación mecánica siguiendo el mismo patrón.
No hay deuda arquitectónica — solo deuda de implementación.
