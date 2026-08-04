# A.77 — Especificación del Protocolo de Wire: WebSocket + JSON-RPC 2.0

**Versión:** 1.1.0  
**Fecha:** 2026-08-05  
**Manual padre:** [2.18 — Motor de Comunicación](../2.18_MANUAL-MOTOR-COMUNICACION-v1.0.md)  
**Complementa:** [2.12 — Canales Protegidos](../2.12_MANUAL-CANALES-PROTEGIDOS.md) · ADR-020 Interface Dual  
**Contexto:** Especificación del nivel de wire para cualquier cliente del ecosistema SBOS (banexus-implicit — agnóstico de lenguaje y framework: TypeScript, PHP, Dart, Rust, Python)  

---

## 1. Propósito

Este anexo define el **contrato de bytes** entre cualquier cliente SBOS y el daemon bAuth.
Un cliente que implemente este protocolo funciona sin cambios en todas las capas del Motor de
Comunicación (2.18), independientemente del lenguaje (Dart, Go, Rust, Python, JavaScript/Browser).

---

## 2. Capa de transporte: RFC 6455 WebSocket

### 2.1 Handshake HTTP Upgrade

```http
GET /ws HTTP/1.1
Host: bauth.sbos.local
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: <base64(nonce-16-bytes)>
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: json-rpc-2.0
Authorization: Bearer <jwt>          ←  solo Capa 2+; ausente en Capa 1 dev local
X-SBOS-Ctx-Id: <ctx_id-32hex>        ←  SBOS-049 obligatorio
```

**Respuesta del daemon (éxito):**
```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: <sha1(key+magic)>
Sec-WebSocket-Protocol: json-rpc-2.0
```

**Respuesta del daemon (fallo):**

| Código | Causa | Acción cliente |
|--------|-------|---------------|
| 401 Unauthorized | JWT ausente, expirado o inválido | Renovar token → reintentar |
| 403 Forbidden | JWT válido pero sin scope `dashboard` | No reintentar — escalar |
| 503 Service Unavailable | Daemon en arranque o reinicio | Backoff exponencial |

### 2.2 Frames

El protocolo usa exclusivamente frames de **texto** (`opcode 0x1`) con payload UTF-8.
Los frames binarios (`opcode 0x2`) están reservados para uso futuro y el daemon los rechaza
cerrando la conexión con código `1003 (Unsupported Data)`.

Los mensajes pueden fragmentarse en frames (`FIN=0`) cuando superan 64 KiB.
El cliente debe ensamblar los frames antes de parsear JSON.

**Parámetros de keep-alive:**
- El daemon envía un frame `PING` (`opcode 0x9`) cada **30 segundos** de inactividad.
- El cliente debe responder con `PONG` (`opcode 0xA`) en menos de **10 segundos**.
- Sin `PONG` → el daemon cierra con código `1001 (Going Away)`.

---

## 3. Capa de mensaje: JSON-RPC 2.0

Toda la comunicación sigue la especificación JSON-RPC 2.0 (https://www.jsonrpc.org/specification).
El daemon sirve el mismo dispatcher `jsonrpc.rs` que atiende el Unix socket (ADR-020 Interface Dual).

### 3.1 Request del cliente

```json
{
  "jsonrpc": "2.0",
  "method": "bauth.rol_template.tree",
  "params": {
    "tenant": "skull",
    "ctx_id": "a1b2c3d4e5f67890a1b2c3d4e5f67890"
  },
  "id": 42
}
```

**Campos:**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `jsonrpc` | `"2.0"` | ✅ | Literal. Cualquier otro valor → error `ParseError` |
| `method` | `string` | ✅ | Namespace `bauth.*`. Ver catálogo en 2.18 §8 |
| `params` | `object` | Depende del método | `ctx_id` siempre presente (SBOS-049) |
| `id` | `integer \| string \| null` | ✅ para requests con respuesta | Entero incremental recomendado |

**Notificaciones** (`id` ausente): el daemon las procesa pero no retorna respuesta.
Usar solo para telemetría o heartbeat del cliente — nunca para operaciones que requieran confirmación.

### 3.2 Response del daemon

**Éxito:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "nodos": [...],
    "total": 134,
    "ctx_id": "a1b2c3d4e5f67890a1b2c3d4e5f67890"
  },
  "id": 42
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32001,
    "message": "Token expirado",
    "data": {
      "expired_at": "2026-08-04T10:00:00Z",
      "jti": "uuid-del-token"
    }
  },
  "id": 42
}
```

### 3.3 Tabla de códigos de error

| Código | Nombre | Causa |
|--------|--------|-------|
| `-32700` | Parse error | JSON malformado |
| `-32600` | Invalid Request | Falta `jsonrpc`/`method`/`id` o tipos incorrectos |
| `-32601` | Method not found | Método `bauth.*` no existe en el dispatcher |
| `-32602` | Invalid params | Parámetro obligatorio ausente o tipo incorrecto |
| `-32603` | Internal error | Error interno del daemon (logeado en Wazuh) |
| `-32001` | Unauthorized | JWT expirado o inválido → renovar y reintentar |
| `-32002` | Forbidden | JWT válido pero sin permiso para este método |
| `-32003` | Tenant not found | `tenant` desconocido en SBOSDB |
| `-32004` | Rate limit | Demasiadas solicitudes — esperar `data.retry_after_ms` |
| `-32005` | Ctx-Id required | `ctx_id` ausente en `params` — incluirlo (SBOS-049) |

---

## 4. Multiplexado de requests

El canal WebSocket es full-duplex y bidireccional. El cliente puede tener **múltiples requests
en vuelo simultáneamente** sin esperar respuesta de los anteriores. El daemon correlaciona cada
respuesta con su request usando el campo `id`.

**Ejemplo: 3 requests en vuelo:**

```
Cliente → Daemon
  {"jsonrpc":"2.0","method":"bauth.health.check","params":{},"id":1}
  {"jsonrpc":"2.0","method":"bauth.rol_template.tree","params":{"tenant":"skull"},"id":2}
  {"jsonrpc":"2.0","method":"bauth.session.refresh","params":{"refresh_token":"..."},"id":3}

Daemon → Cliente (en cualquier orden)
  {"jsonrpc":"2.0","result":{"status":"operativo"},"id":1}       ← primero en responder
  {"jsonrpc":"2.0","result":{"token":"nuevo_jwt"},"id":3}         ← segundo en responder
  {"jsonrpc":"2.0","result":{"nodos":[...]},"id":2}               ← último (más pesado)
```

El cliente mantiene un mapa `id → Completer/Promise` y resuelve cada promesa cuando llega
la respuesta con el `id` correspondiente.

**Límite de concurrencia (Capa 1 inicial):** el daemon no impone límite en la implementación
de referencia, pero el cliente debe limitar a **50 requests concurrentes** para evitar
sobrecarga. Si se superan 50, encolar los adicionales.

---

## 5. ctx_id — propagación obligatoria (SBOS-049)

Todo request debe incluir `ctx_id` en `params`. Es la trazabilidad de extremo a extremo.

**Formato:** 32 caracteres hexadecimales (UUID v4 sin guiones): `a1b2c3d4e5f67890a1b2c3d4e5f67890`

**Generación por lenguaje (banexus-implicit — ver 2.18 §4 para implementaciones completas):**

```typescript
// TypeScript / JavaScript (React, Vue, Node)
import { v4 as uuidv4 } from 'uuid';
const nuevoCtxId = () => uuidv4().replaceAll('-', '');
```

```php
// PHP / Laravel
function nuevoCtxId(): string {
    return str_replace('-', '', (string) \Ramsey\Uuid\Uuid::uuid4());
}
```

```dart
// Dart / Flutter
import 'package:uuid/uuid.dart';
String nuevoCtxId() => const Uuid().v4().replaceAll('-', '');
```

```rust
// Rust (M2M daemon, bauthctl)
use uuid::Uuid;
fn nuevo_ctx_id() -> String { Uuid::new_v4().simple().to_string() }
```

```python
# Python / Django
import uuid
def nuevo_ctx_id() -> str: return uuid.uuid4().hex
```

**Propagación:** el `ctx_id` se genera al iniciar una operación de negocio (ej: "abrir la vista de roles").
Todos los requests JSON-RPC realizados para completar esa operación llevan el **mismo** `ctx_id`.
No generar uno nuevo por cada request — eso rompe la cadena de trazabilidad.

---

## 6. JWT — estructura mínima pre-átomos

Emitido por `bauth.session.login`. Firmado con Ed25519 (Vault PKI).

```json
{
  "iss": "bauth.sbos.local",
  "sub": "usuario-uuid",
  "aud": ["sbos-dashboard"],
  "exp": 1754380800,
  "iat": 1754351000,
  "jti": "uuid-único-del-token",
  "ctx_id": "a1b2c3d4e5f67890a1b2c3d4e5f67890",
  "scope": "dashboard",
  "tenant": "skull"
}
```

**Ausente intencionalmente:** `rol_bitmask` — se añade en Capa 5 cuando `roles_template`
haya generado átomos D03. Hasta entonces, `scope:"dashboard"` es suficiente para que
Kong valide el acceso al WebSocket.

---

## 7. Verificación del protocolo con herramientas de sistema

### 7.1 wscat (Node.js)
```bash
npx wscat -c ws://127.0.0.1:9450 \
  --header "Authorization: Bearer <jwt>" \
  --header "X-SBOS-Ctx-Id: a1b2c3d4e5f67890a1b2c3d4e5f67890"

# Una vez conectado:
> {"jsonrpc":"2.0","method":"bauth.health.check","params":{"ctx_id":"a1b2c3d4e5f67890a1b2c3d4e5f67890"},"id":1}
< {"jsonrpc":"2.0","result":{"status":"operativo","version":"3.0.0"},"id":1}
```

### 7.2 Script de verificación de conectividad (bash)
```bash
#!/bin/bash
# scripts/verificar_ws_daemon.sh
# Verifica que el daemon acepta conexión WebSocket JSON-RPC 2.0.
set -euo pipefail

DAEMON_URL="${1:-ws://127.0.0.1:9450}"
CTX_ID="$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"

echo "[VERIFICAR] Conectando a $DAEMON_URL"
RESPUESTA=$(echo '{"jsonrpc":"2.0","method":"bauth.health.check","params":{"ctx_id":"'"$CTX_ID"'"},"id":1}' \
  | timeout 5 websocat "$DAEMON_URL" 2>&1)

echo "[RESPUESTA] $RESPUESTA"

if echo "$RESPUESTA" | grep -q '"status":"operativo"'; then
  echo "[OK] Daemon respondiendo correctamente"
  exit 0
else
  echo "[FALLO] Respuesta inesperada"
  exit 1
fi
```

### 7.3 socat (verificar Unix socket — lo que existe hoy en producción)
```bash
# El socket Unix actual en VPS: /tmp/bauth/bauth.sock
echo -n '{"jsonrpc":"2.0","method":"bauth.health.check","params":{},"id":1}' \
  | socat - UNIX-CONNECT:/tmp/bauth/bauth.sock
```

---

## 8. Restricciones de seguridad del protocolo

| Restricción | Razón |
|-------------|-------|
| TLS 1.3 obligatorio en producción (Kong) | RFC 8446; TLS 1.2 deprecado para nuevas implementaciones |
| JWT debe incluir `jti` | Permite revocación por JTI (lista negra en Redis) |
| `ctx_id` en cada request | SBOS-049 — auditoría de extremo a extremo |
| Frames texto solamente (UTF-8) | Previene inyección via frames binarios |
| Timeout 15s por request | Previene goroutine/task leak por requests huérfanos |
| Máximo 50 requests concurrentes por cliente | Previene sobrecarga involuntaria del daemon |
| `Sec-WebSocket-Protocol: json-rpc-2.0` | Previene conexiones de clientes no SBOS |

---

## Changelog

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.1.0 | 2026-08-05 | §5 ctx_id: ejemplos multi-lenguaje (TS/PHP/Dart/Rust/Python) en línea con 2.18 v3.0.0 (banexus-implicit agnóstico); actualizado encabezado Contexto |
| 1.0.0 | 2026-08-04 | Versión inicial — handshake HTTP, frames, JSON-RPC, multiplexado, ctx_id, JWT mínimo, verificación, restricciones |
