# PROPUESTA-INTERFAZ-CONTEXT-PLANE-v1.0 — Diseño de API
## Documento no indexado — Propuesta para revisión y fusión en 4.01 oficial

**Versión:** 1.0 · **Fecha:** 2026-07-31 · **Autor:** bauth-developer
**Propósito:** Diseñar la interfaz completa del Context Plane (schema `bos`) basada en el DDL v2.12.0. JSON-RPC 2.0 + WebSocket. Este documento se fusionará en el manual oficial 4.01 tras aprobación HITL.

---

## 1. Arquitectura de la interfaz

### 1.1 Principios

| Principio | Aplicación |
|-----------|------------|
| **Interface Dual (ADR-020)** | JSON-RPC 2.0 sobre `/run/bos/bos.sock` para daemons + WebSocket RPC para CLI humano |
| **Redis primero, PG después** | Toda consulta de sesión/contexto activo va a Redis DB1 (O(1)). PG es fallback. |
| **Escritura atómica** | INSERT en PG + SET en Redis en la misma operación. Si Redis falla, PG es fuente de verdad. |
| **Invalidación inmediata** | Al revocar/expirar → Redis DEL inmediato (Kong deja de aceptar el ctx_id al instante). |
| **WORM inmutable** | Auditoría/switch/transferencia/emergencia son append-only desde el primer INSERT. |

### 1.2 Namespace JSON-RPC

```
bos.ctx.device.*       → Gestión de dispositivos (T-395, T-400)
bos.ctx.session.*      → Gestión de sesiones (T-396)
bos.ctx.policy.*       → Configuración de políticas (T-399)
bos.ctx.audit.*        → Consulta de auditoría (T-397, T-398, T-401)
bos.ctx.emergency.*    → Gestión de emergencias (T-402)
```

### 1.3 Eventos WebSocket (server→client push)

```
bos.ctx.session.revoked     → Sesión revocada (CAEP)
bos.ctx.session.expired     → Sesión expirada por TTL
bos.ctx.device.offline      → Dispositivo sin heartbeat > 3× intervalo
bos.ctx.emergency.activated → Emergencia activada (notificar admins)
bos.ctx.emergency.review_due → Revisión post-hoc pendiente (24h)
```

---

## 2. API — Dispositivos (`bos.ctx.device.*`)

### 2.1 `bos.ctx.device.register`

Registra un dispositivo en el Context Plane. El dispositivo aún no tiene usuario autenticado — BitMask = 0. TTL 8h. Heartbeat requerido cada 30s.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.device.register",
  "params": {
    "hostname": "ws-01.skull.local",
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "node_k8s": "worker-3",
    "ip": "10.0.5.42"
  },
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "dctx_id": "019fb500-1234-7abc-8def-123456789abc",
    "state": "PENDING",
    "expires_at": "2026-07-31T17:00:00Z",
    "heartbeat_interval_sec": 30
  },
  "id": 1
}
```

**Flujo interno:**
1. Validar `tenant_id` existe en `bauth.idn_tenant` y `status = 'ACTIVE'`
2. Verificar `bos.ctx_context_policy.require_mdm` para el tenant
3. `INSERT INTO bos.ctx_registered_device` → `dctx_id` UUIDv7
4. `INSERT INTO bos.ctx_context_audit (operation='DEVICE_REGISTER')`
5. `SET dctx:{dctx_id} = {json} EX 28800` en Redis DB1

### 2.2 `bos.ctx.device.heartbeat`

Renueva el TTL del dispositivo. Llamado cada 30s por `sbos-client`.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.device.heartbeat",
  "params": {
    "dctx_id": "019fb500-1234-7abc-8def-123456789abc",
    "ip": "10.0.5.42"
  },
  "id": 2
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "dctx_id": "019fb500-1234-7abc-8def-123456789abc",
    "ack": true,
    "expires_at": "2026-07-31T17:30:00Z"
  },
  "id": 2
}
```

**Flujo interno:**
1. `SELECT state, expires_at FROM bos.ctx_registered_device WHERE dctx_id = $1`
2. Si `state NOT IN ('PENDING','ACTIVE')` → error `DEVICE_NOT_ACTIVE`
3. `INSERT INTO bos.ctx_device_heartbeat` (alta escritura, solo INSERT)
4. `UPDATE bos.ctx_registered_device SET expires_at = now() + device_ttl, ip = $2, updated_at = now()`
5. Actualizar TTL en Redis: `EXPIRE dctx:{id} {ttl}`

### 2.3 `bos.ctx.device.get`

Consulta el estado de un dispositivo.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.device.get",
  "params": { "dctx_id": "019fb500-1234-7abc-8def-123456789abc" },
  "id": 3
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "dctx_id": "019fb500-1234-7abc-8def-123456789abc",
    "hostname": "ws-01.skull.local",
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "node_k8s": "worker-3",
    "ip": "10.0.5.42",
    "state": "ACTIVE",
    "created_at": "2026-07-31T09:00:00Z",
    "expires_at": "2026-07-31T17:30:00Z",
    "last_heartbeat": "2026-07-31T09:29:30Z",
    "heartbeats_24h": 58
  },
  "id": 3
}
```

### 2.4 `bos.ctx.device.list_by_tenant`

Lista dispositivos de un tenant con filtro por estado.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.device.list_by_tenant",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "state": "ACTIVE",
    "limit": 50,
    "offset": 0
  },
  "id": 4
}
```

---

## 3. API — Sesiones (`bos.ctx.session.*`)

### 3.1 `bos.ctx.session.create`

Crea una sesión de infraestructura post-autenticación. Promueve un DeviceContext (pre-auth) a SessionContext (post-auth). El BitMask > 0 viene de bAuth.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.session.create",
  "params": {
    "dctx_id": "019fb500-1234-7abc-8def-123456789abc",
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "entity_1_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "entity_2_id": null,
    "entity_3_id": "CAJA-01",
    "user_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "bitmask": 72057594037927935,
    "loa": 2,
    "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  },
  "id": 5
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "ctx_id": "019fb501-5678-7def-9012-345678901def",
    "state": "ACTIVE",
    "expires_at": "2026-07-31T21:00:00Z",
    "ttl_seconds": 43200
  },
  "id": 5
}
```

**Flujo interno:**
1. Validar que `dctx_id` existe y está en estado `ACTIVE` o `PENDING`
2. Validar que las entidades existen en `bauth.idn_identity_entity` y están `ACTIVE`
3. Validar `bitmask > 0` (invariante post-auth)
4. `INSERT INTO bos.ctx_context_session` con `ctx_id` UUIDv7
5. `UPDATE bos.ctx_registered_device SET state = 'ACTIVE'`
6. `INSERT INTO bos.ctx_context_audit (operation='SESSION_CREATE')`
7. `SET ctx:{ctx_id} = {json} EX {session_ttl}` en Redis DB1

### 3.2 `bos.ctx.session.get`

Lookup O(1) de sesión. Kong PEP llama este método en CADA request autenticado. Primero Redis, fallback PG.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.session.get",
  "params": { "ctx_id": "019fb501-5678-7def-9012-345678901def" },
  "id": 6
}
```

**Response (activa):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "ctx_id": "019fb501-5678-7def-9012-345678901def",
    "state": "ACTIVE",
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "user_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "bitmask": 72057594037927935,
    "loa": 2,
    "expires_at": "2026-07-31T21:00:00Z"
  },
  "id": 6
}
```

**Response (inactiva):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "ctx_id": "019fb501-5678-7def-9012-345678901def",
    "state": "EXPIRED",
    "reason": "TTL exceeded at 2026-07-31T21:00:00Z"
  },
  "id": 6
}
```

**Anti-enumeration:** misma latencia y mismo código HTTP para "no encontrado" y "expirado".

### 3.3 `bos.ctx.session.invalidate`

Invalida una sesión (logout, revocación, CAEP). Redis DEL inmediato.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.session.invalidate",
  "params": {
    "ctx_id": "019fb501-5678-7def-9012-345678901def",
    "reason": "LOGOUT"
  },
  "id": 7
}
```

**Flujo interno:**
1. `UPDATE bos.ctx_context_session SET state = 'INVALIDATED'`
2. `INSERT INTO bos.ctx_context_audit (operation='SESSION_INVALIDATE', new_state='INVALIDATED')`
3. `DEL ctx:{ctx_id}` en Redis → Kong rechaza el siguiente request inmediatamente

### 3.4 `bos.ctx.session.switch`

Cambia el contexto organizacional sin reautenticación. El ctx_id anterior se invalida, se crea uno nuevo con las nuevas entidades.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.session.switch",
  "params": {
    "current_ctx_id": "019fb501-5678-7def-9012-345678901def",
    "new_entity_1_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "new_entity_2_id": "019faa09-1234-5678-9abc-def012345678",
    "reason": "Cambio de sucursal para atender cliente"
  },
  "id": 8
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "previous_ctx_id": "019fb501-5678-7def-9012-345678901def",
    "new_ctx_id": "019fb502-9abc-8def-3456-789012345def",
    "state": "ACTIVE",
    "expires_at": "2026-07-31T21:00:00Z"
  },
  "id": 8
}
```

**Flujo interno:**
1. Leer `current_ctx_id` de Redis → obtener `tenant_id`, `user_id`, `bitmask`, `loa`, `traceparent`
2. `UPDATE bos.ctx_context_session SET state='INVALIDATED' WHERE ctx_id = current_ctx_id`
3. `INSERT INTO bos.ctx_context_session` con nuevo `ctx_id`, mismas credenciales, nuevas entidades
4. `INSERT INTO bos.ctx_context_switch_log` (WORM) con old/new ctx_id + entidades
5. `INSERT INTO bos.ctx_context_audit (operation='SESSION_SWITCH')`
6. `DEL ctx:{old}` + `SET ctx:{new}` en Redis

### 3.5 `bos.ctx.session.list_by_tenant`

Lista sesiones activas de un tenant. Solo para administradores.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.session.list_by_tenant",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "state": "ACTIVE",
    "limit": 100
  },
  "id": 9
}
```

---

## 4. API — Políticas (`bos.ctx.policy.*`)

### 4.1 `bos.ctx.policy.get`

Obtiene la política de Context Plane para un tenant. Si no existe fila, se usan los defaults del CREATE TABLE.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.policy.get",
  "params": { "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f" },
  "id": 10
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "device_ttl_seconds": 28800,
    "session_ttl_seconds": 43200,
    "heartbeat_interval_sec": 30,
    "max_sessions_per_user": 50,
    "max_devices_per_tenant": 5000,
    "rate_limit_rps": 500,
    "require_mdm": false,
    "auto_block_jailbreak": false
  },
  "id": 10
}
```

### 4.2 `bos.ctx.policy.upsert`

Crea o actualiza la política de un tenant. Solo administradores del tenant o sistema.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.policy.upsert",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "session_ttl_seconds": 14400,
    "require_mdm": true
  },
  "id": 11
}
```

---

## 5. API — Auditoría (`bos.ctx.audit.*`)

### 5.1 `bos.ctx.audit.query`

Consulta el log de auditoría WORM con filtros.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.audit.query",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "operation": "SESSION_SWITCH",
    "from": "2026-07-31T00:00:00Z",
    "to": "2026-07-31T23:59:59Z",
    "limit": 50
  },
  "id": 12
}
```

### 5.2 `bos.ctx.audit.switches`

Consulta el historial de cambios de contexto de un usuario. Forensia ITDR: ¿por qué este usuario operó en 3 sucursales en 5 minutos?

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.audit.switches",
  "params": {
    "user_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "from": "2026-07-01T00:00:00Z",
    "limit": 100
  },
  "id": 13
}
```

### 5.3 `bos.ctx.audit.transfers`

Consulta el historial de transferencias de contexto entre dispositivos.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.audit.transfers",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "transfer_type": "BREAKGLASS",
    "from": "2026-07-01T00:00:00Z",
    "limit": 50
  },
  "id": 14
}
```

---

## 6. API — Emergencias (`bos.ctx.emergency.*`)

### 6.1 `bos.ctx.emergency.activate`

Declara una emergencia de contexto. Requiere `incident_ref` externo obligatorio. La sesión NO se crea hasta que un segundo administrador apruebe.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.emergency.activate",
  "params": {
    "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f",
    "activated_by": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "reason": "IdP caído — incapaz de autenticar usuarios en sucursal Norte. Incidente INC-12345 requiere operación inmediata del sistema de inventario.",
    "incident_ref": "INC-12345",
    "entity_1_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c",
    "user_id": "019faa08-698e-79a8-a7ad-f474e7e8b41c"
  },
  "id": 15
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "emergency_id": "019fb510-abcd-7ef0-1234-567890abcdef",
    "state": "ACTIVATED",
    "expires_at": "2026-07-31T11:00:00Z",
    "pending_approval": true,
    "message": "Emergencia declarada. Esperando aprobación de un segundo administrador."
  },
  "id": 15
}
```

**Flujo interno:**
1. Validar `reason >= 50 caracteres`
2. Validar `incident_ref` no vacío
3. `INSERT INTO bos.ctx_context_emergency (state='ACTIVATED')`
4. `INSERT INTO bos.ctx_context_audit (operation='EMERGENCY_ACTIVATE')`
5. WebSocket push `bos.ctx.emergency.activated` a todos los administradores del tenant
6. Notificación urgente vía bNotify

### 6.2 `bos.ctx.emergency.approve`

Un SEGUNDO administrador aprueba la emergencia. `activated_by ≠ approved_by` (control dual NIST AC-17(3)). Al aprobar, se crea la sesión de emergencia.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.emergency.approve",
  "params": {
    "emergency_id": "019fb510-abcd-7ef0-1234-567890abcdef",
    "approved_by": "019faa09-1234-5678-9abc-def012345678"
  },
  "id": 16
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "emergency_id": "019fb510-abcd-7ef0-1234-567890abcdef",
    "state": "SESSION_CREATED",
    "resulting_ctx_id": "019fb511-fedc-8ba0-9876-543210fedcba",
    "ctx_expires_at": "2026-07-31T11:00:00Z",
    "message": "Emergencia aprobada. Sesión de emergencia creada con TTL 2h máximo."
  },
  "id": 16
}
```

**Flujo interno:**
1. Validar `approved_by ≠ activated_by` (chk_cem_dual)
2. `UPDATE bos.ctx_context_emergency SET approved_by=$2, state='SESSION_CREATED'`
3. `bos.ctx.session.create(emergency=true, ttl=2h)` → `resulting_ctx_id`
4. `UPDATE bos.ctx_context_emergency SET resulting_ctx_id = $3`
5. `INSERT INTO bos.ctx_context_audit (operation='EMERGENCY_APPROVE')`

### 6.3 `bos.ctx.emergency.review`

Revisión post-hoc obligatoria (24h después de la activación). Determina si la emergencia fue JUSTIFIED, UNJUSTIFIED o POLICY_VIOLATION.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.emergency.review",
  "params": {
    "emergency_id": "019fb510-abcd-7ef0-1234-567890abcdef",
    "reviewed_by": "019faa10-5678-9abc-def0-123456789abc",
    "review_outcome": "JUSTIFIED"
  },
  "id": 17
}
```

### 6.4 `bos.ctx.emergency.list_pending_reviews`

Lista emergencias que requieren revisión post-hoc (state='CLOSED' y sin review_outcome).

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "bos.ctx.emergency.list_pending_reviews",
  "params": { "tenant_id": "019f8ae0-4282-731e-8d71-c42029fded2f" },
  "id": 18
}
```

---

## 7. Seguridad de la API

| Mecanismo | Implementación |
|-----------|---------------|
| **Autenticación** | Unix socket `/run/bos/bos.sock` — solo procesos con grupo `bos` (0660). Sin auth en el socket. |
| **Rate limiting** | Token bucket por IP según `ctx_context_policy.rate_limit_rps`. Redis INCR + TTL. |
| **Anti-enumeration** | `bos.ctx.session.get` responde con misma latencia y mismo HTTP status para "no encontrado" y "expirado". |
| **Cross-tenant validation** | Todo método que recibe `tenant_id` verifica que el caller tiene permisos sobre ese tenant. |
| **ctx_id en logs** | Solo primeros 8 caracteres + hash en logs (sanitización ISO 27001 A.8.15). |
| **WORM enforcement** | `audit`, `switch_log`, `transfer`, `emergency` son append-only — el daemon NUNCA hace UPDATE/DELETE sobre estas tablas. |

---

## 8. Jobs programados (crontab VPS)

| Job | Schedule | Descripción |
|-----|----------|-------------|
| `bos_ctx_heartbeat_check` | `*/5 * * * *` | Dispositivos sin heartbeat en 3×`heartbeat_interval_sec` → `state = 'SUSPENDED'` |
| `bos_ctx_session_expiry` | `*/1 * * * *` | Sesiones con `expires_at < now()` y `state = 'ACTIVE'` → `state = 'EXPIRED'` + Redis DEL |
| `bos_ctx_cleanup_heartbeats` | `0 2 * * *` | `DELETE FROM bos.ctx_device_heartbeat WHERE received_at < now() - INTERVAL '24 hours'` |
| `bos_ctx_emergency_expiry` | `*/5 * * * *` | Emergencias `ACTIVATED` con `expires_at < now()` → `state = 'EXPIRED'` |
| `bos_ctx_audit_retention` | `0 3 28 * *` | Purga de tablas WORM según `idn_roles_ver_b01_retention_policy` (particiones mensuales) |

---

## 9. Métricas de observabilidad

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `bos_ctx_sessions_active` | Gauge | Sesiones ACTIVAS en Redis DB1 |
| `bos_ctx_devices_active` | Gauge | Dispositivos con heartbeat en último intervalo |
| `bos_ctx_lookup_duration_ms` | Histogram | Latencia de `bos.ctx.session.get` (Redis + PG fallback) |
| `bos_ctx_emergencies_active` | Gauge | Emergencias en estado ACTIVATED |
| `bos_ctx_rate_limits_hit` | Counter | Requests rechazados por rate limiting |

---

## 10. Resumen de métodos

| Método | Tabla | Tipo |
|--------|-------|------|
| `bos.ctx.device.register` | T-395 | Escritura |
| `bos.ctx.device.heartbeat` | T-400 | Escritura (alta frecuencia) |
| `bos.ctx.device.get` | T-395 | Lectura |
| `bos.ctx.device.list_by_tenant` | T-395 | Lectura |
| `bos.ctx.session.create` | T-396 | Escritura |
| `bos.ctx.session.get` | T-396 | Lectura (O(1), Kong PEP) |
| `bos.ctx.session.invalidate` | T-396 | Escritura |
| `bos.ctx.session.switch` | T-396+T-398 | Escritura |
| `bos.ctx.session.list_by_tenant` | T-396 | Lectura |
| `bos.ctx.policy.get` | T-399 | Lectura |
| `bos.ctx.policy.upsert` | T-399 | Escritura |
| `bos.ctx.audit.query` | T-397 | Lectura |
| `bos.ctx.audit.switches` | T-398 | Lectura |
| `bos.ctx.audit.transfers` | T-401 | Lectura |
| `bos.ctx.emergency.activate` | T-402 | Escritura |
| `bos.ctx.emergency.approve` | T-402 | Escritura |
| `bos.ctx.emergency.review` | T-402 | Escritura |
| `bos.ctx.emergency.list_pending_reviews` | T-402 | Lectura |

**Total: 18 métodos** · 10 escritura · 8 lectura

---

*Documento no indexado — Propuesta para fusión en 4.01 Manual Context Plane · SKULL · SBOS · Julio 2026*
