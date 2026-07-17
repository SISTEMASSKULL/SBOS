# A.07 — Protocolo WebSocket de bi18n: Especificación Formal

**Tipo:** A — especificación de interfaz (contract-first)
**Versión del anexo:** 1.0.0
**Fecha:** 2026-07-17
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.04 (Ligadura Frontend)](A.04_ANEXO-BI18N-TECNICA-LIGADURA-FRONTEND-v2.1.md) · [A.05 (Cierre de Gaps)](A.05_ANEXO-BI18N-CIERRE-GAPS-v1.1.md)

---

## Principio

bi18n es **agnóstico de plataforma**. Este documento especifica el protocolo del servidor —
no el adapter del cliente. Cualquier entorno capaz de abrir una conexión WebSocket y
serializar/deserializar JSON puede consumir bi18n: scripts de shell, aplicaciones móviles,
dashboards web, daemons de backend, herramientas de terminal, integraciones IoT.

La implementación del adapter en el lado cliente es responsabilidad de cada equipo.
Este documento les da todo lo necesario para hacerlo correctamente.

---

## §1 Topología de red

```
Cliente (cualquier plataforma)
        │  wss://  (TLS terminado en Kong)
        ▼
  Kong API Gateway
        │  ws://  (HTTP upgrade, sin TLS — tráfico interno)
        ▼
  bi18nd  127.0.0.1:9454  (ws_bind — configurable en bi18n.toml)
```

**Regla:** los clientes NUNCA se conectan directamente al puerto 9454. Kong es el único
punto de entrada externo. La dirección y puerto interno son detalles de infraestructura
que no afectan al protocolo del cliente.

**Puerto del daemon:** `9454` (valor por defecto; configurable en `[servidor] ws_bind`).

---

## §2 Handshake — conexión y autenticación

### 2.1 Upgrade HTTP → WebSocket

Conexión estándar RFC 6455. El cliente envía:

```
GET /ws HTTP/1.1
Host: bi18n.tudominio.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: <base64>
Sec-WebSocket-Version: 13
Authorization: Bearer <jwt>
```

El servidor responde `101 Switching Protocols` si el token es válido.

### 2.2 Autenticación JWT

| Campo | Valor |
|---|---|
| Header | `Authorization: Bearer <token>` |
| Token emitido por | bAuth (mismo JWT de sesión SBOS) |
| Claim requerido | `sub` (subject) — identifica la sesión |
| Validación | Kong verifica el JWT antes de proxear al daemon |

Si el token es inválido o ausente, Kong retorna `401 Unauthorized` antes del upgrade.
El daemon no implementa validación JWT propia — la delega a Kong.

### 2.3 Errores de handshake

| Código HTTP | Causa |
|---|---|
| `401 Unauthorized` | JWT ausente o expirado |
| `403 Forbidden` | JWT válido pero sin permiso para esta ruta |
| `503 Service Unavailable` | bi18nd no alcanzable (down o unhealthy) |

---

## §3 Protocolo — framing y formato

### 3.1 Framing

Cada mensaje es un **WebSocket Text Frame** que contiene exactamente un objeto JSON.
No hay framing adicional ni delimitadores entre mensajes.

```
[WebSocket Frame 1]  {"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{...}}
[WebSocket Frame 2]  {"jsonrpc":"2.0","id":1,"result":{...}}
```

**Regla:** un frame = un objeto JSON-RPC. No hay streaming parcial ni concatenación.

### 3.2 Formato JSON-RPC 2.0

**Request (cliente → daemon):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "bi18n.<namespace>.<accion>",
  "params": {
    "ctx_id": "<uuid-v4>",
    ...parámetros del método...
  }
}
```

**Response exitoso (daemon → cliente):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    ...campos de respuesta...
  }
}
```

**Response de error (daemon → cliente):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Método JSON-RPC no encontrado: 'bi18n.método.inexistente'"
  }
}
```

### 3.3 Campo `ctx_id` — obligatorio (SBOS-049)

Todo request DEBE incluir `ctx_id` en `params`. Ausente o vacío → error `-32602`.

```json
{
  "params": {
    "ctx_id": "550e8400-e29b-41d4-a716-446655440000",
    ...
  }
}
```

El `ctx_id` debe ser un UUID v4 generado por el cliente al inicio de cada operación lógica
(no por request individual). Permite correlacionar requests en los logs del daemon.

---

## §4 Métodos disponibles por WebSocket

Todos los métodos disponibles en el Unix socket también están disponibles por WebSocket.
La paridad es total — mismo dispatcher, mismo contrato, mismo resultado.

### 4.1 Estado y locale

| Método | Parámetros | Respuesta |
|---|---|---|
| `bi18n.health.check` | `ctx_id` | `{status, version, paises_cargados, mensaje}` |
| `bi18n.locale.resolve` | `ctx_id, tenant_id, branch_id, user_id` | `{locale, timezone, currency, country, fuente}` |
| `bi18n.regional.snapshot` | `ctx_id, tenant_id, branch_id?, user_id?` | `{...config regional completa...}` |

### 4.2 Contrato de ligadura (A.04 §3) — más usados por clientes remotos

| Método | Parámetros | Respuesta |
|---|---|---|
| `bi18n.attr.config_batch` | `ctx_id, fields:[{key,display_format}...], locale?, country?, tenant_id?, branch_id?, user_id?` | `{campos:{<key>:{display_format,validator_profile,mask_pattern,input_mask,masks_pii},...}, locale, country}` |
| `bi18n.attr.pipeline` | `ctx_id, field_id (o key), value, validator_profile (o validate_format), locale?, country?` | `{raw,valid,display,masked,validation_errors:[...]}` |
| `bi18n.attr.config` | `ctx_id, display_format, locale?` | `{display_format,validator_profile,mask_pattern,input_mask,masks_pii}` |

**Flujo típico:**
1. Al abrir formulario: `bi18n.attr.config_batch` (una vez, todos los campos)
2. Al perder foco de un campo: `bi18n.attr.pipeline` (por campo, con debounce ≥ 250ms en cliente)
3. Al enviar: `bi18n.attr.pipeline` para todos los campos (revalidación final, sin excepción)

### 4.3 Validación

| Método | Parámetros | Respuesta |
|---|---|---|
| `bi18n.validate.email` | `ctx_id, value` | `{valid, normalized, errores}` |
| `bi18n.validate.phone` | `ctx_id, value, country_hint?` | `{valid, e164, errores}` |
| `bi18n.validate.national_id` | `ctx_id, value, kind?, country?` | `{valid, normalized, errores}` |

### 4.4 Formateo

| Método | Parámetros | Respuesta |
|---|---|---|
| `bi18n.format.date` | `ctx_id, iso_datetime, granularity?, locale?, timezone?` | `{display, timezone, locale}` |
| `bi18n.format.number` | `ctx_id, value, decimales?, locale?` | `{display}` |
| `bi18n.format.money` | `ctx_id, amount, currency_code?, locale?` | `{display, symbol_local}` |

### 4.5 Enmascaramiento y enums

| Método | Parámetros | Respuesta |
|---|---|---|
| `bi18n.mask.value` | `ctx_id, value, strategy?, country?, kind?` | `{masked}` |
| `bi18n.mask.pii` | `ctx_id, text, mask_emails?, mask_phones?` | `{redacted, campos_redactados}` |
| `bi18n.enum.display` | `ctx_id, enum_name, value, locale?` | `{label, found, fallback}` |

---

## §5 Códigos de error

### 5.1 Códigos estándar JSON-RPC 2.0

| Código | Significado |
|---|---|
| `-32700` | Parse error — el frame no es JSON válido |
| `-32601` | Método no encontrado |
| `-32602` | Parámetros inválidos — incluye `ctx_id` ausente |

### 5.2 Códigos específicos de bi18n (rango -32000 a -32099)

| Código | Mensaje | Causa |
|---|---|---|
| `-32000` | `rate limit excedido — demasiados requests por segundo` | Cliente supera `ws_rate_limit_rps` (default: 60 req/s) |
| `-32001` | `timeout: el handler no respondió en el tiempo configurado` | Request tardó más de `ws_timeout_ms` (default: 5000ms) |
| `-32000` | Cualquier otro error de negocio | Ver campo `message` para detalle |

---

## §6 Rate limiting

El daemon aplica un límite de tasa **por conexión WebSocket** (no global).

| Parámetro | Config TOML | Default |
|---|---|---|
| `ws_rate_limit_rps` | `[servidor] ws_rate_limit_rps` | `60` req/s |
| Ventana | deslizante de 1 segundo | — |
| Comportamiento al superar | error `-32000`, la conexión continúa | — |

El cliente recibe el error y puede esperar antes de reintentar. La conexión NO se cierra.

**Recomendación para clientes:** implementar debounce de ≥ 250ms en `attr.pipeline`
(validación al perder foco, no al escribir). Esto evita superar el límite incluso con 60
campos en un formulario.

---

## §7 Requisito de accesibilidad para clientes

El daemon retorna mensajes de error en `validation_errors[]`. El cliente es responsable de
presentarlos de forma accesible:

**Contrato de comportamiento observable (plataforma-agnóstico):**
- Cuando `valid: false` y `validation_errors` tiene al menos un elemento, el mensaje de
  error DEBE ser anunciado por el lector de pantalla del sistema operativo sin que el
  usuario tenga que mover el foco al campo afectado.
- El mecanismo concreto para lograr esto es responsabilidad del adapter de cada plataforma.

---

## §8 Sesión mínima — pseudocódigo neutro

```
FUNCIÓN conectar_bi18n(url, jwt_token):
    ws ← WebSocket.connect(url, headers={"Authorization": "Bearer " + jwt_token})
    RETORNAR ws

FUNCIÓN pedir_config_batch(ws, campos, locale, ctx_id):
    request ← {
        jsonrpc: "2.0",
        id: generar_id_único(),
        method: "bi18n.attr.config_batch",
        params: {
            ctx_id: ctx_id,
            fields: campos,      // [{key: "CI", display_format: "ID_BO"}, ...]
            locale: locale       // "es-BO"
        }
    }
    ws.send(JSON.serializar(request))
    respuesta ← JSON.deserializar(ws.recibir())
    SI respuesta.error ENTONCES lanzar_error(respuesta.error)
    RETORNAR respuesta.result.campos   // {CI: {mask_pattern, validator_profile, ...}, ...}

FUNCIÓN validar_campo(ws, field_id, valor, validator_profile, locale, ctx_id):
    request ← {
        jsonrpc: "2.0",
        id: generar_id_único(),
        method: "bi18n.attr.pipeline",
        params: {
            ctx_id: ctx_id,
            field_id: field_id,
            value: valor,
            validator_profile: validator_profile,
            locale: locale
        }
    }
    ws.send(JSON.serializar(request))
    respuesta ← JSON.deserializar(ws.recibir())
    SI respuesta.error ENTONCES lanzar_error(respuesta.error)
    RETORNAR respuesta.result  // {valid, display, masked, validation_errors}

// Uso típico
ws     ← conectar_bi18n("wss://bi18n.dominio.com/ws", token)
ctx_id ← generar_uuid_v4()
config ← pedir_config_batch(ws, [{key:"CI", display_format:"ID_BO"}], "es-BO", ctx_id)
// usuario escribe en el campo CI...
// al perder foco (debounce ≥ 250ms):
resultado ← validar_campo(ws, "CI", "1234567", config.CI.validator_profile, "es-BO", ctx_id)
SI NO resultado.valid:
    mostrar_error_accesible(resultado.validation_errors[0])
```

---

## §9 Ejemplo de verificación con herramienta estándar

```bash
# Verificar que bi18n.health.check responde por WebSocket — sin adapter específico
# Requiere: websocat (cargo install websocat) o wscat (npm install -g wscat)

websocat ws://127.0.0.1:9454 <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":"550e8400-e29b-41d4-a716-446655440000"}}
EOF

# Respuesta esperada:
# {"jsonrpc":"2.0","id":1,"result":{"status":"ok","version":"0.1.0","paises_cargados":3,"mensaje":"bi18n operativo"}}
```

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Especificación inicial. Topología Kong→daemon, handshake JWT, framing JSON-RPC 2.0 por frame WebSocket, tabla de métodos, códigos de error (-32000 rate limit, -32001 timeout), requisito de a11y agnóstico, pseudocódigo neutro de sesión. Generado junto con la implementación del Bloque 9. |
