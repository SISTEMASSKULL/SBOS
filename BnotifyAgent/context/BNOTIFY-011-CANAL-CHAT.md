---
codigo: BNOTIFY-011
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-003, BNOTIFY-010]
doctrina_que_ejerce: [D4, D5, D7, D14]
criterio_implementado: >
  El adaptador de chat entrega un mensaje de prueba a un usuario real en bRocket.
  El mensaje aparece en la sala correcta de la instancia CE 8.5.0.
  El método Health del adaptador retorna operational=true.
  Al simular caída de bRocket (pod detenido), el adaptador retorna
  DeliveryResult.status=CHANNEL_UNAVAILABLE (no FAILED_TEMPORARY).
  Todo verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-011 — Canal Chat
## Adaptador de chat: bRocket (interino) → bChat (nativo en G3)

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2, §5, ADR-003 (bRocket congelado), ADR-008

**D7 — La excepción HTTP documentada:**
> Este adaptador es la **única pieza del núcleo que habla HTTP/REST**. Lo hace porque
> bRocket (Rocket.Chat CE) solo tiene REST API — no tiene gRPC. Esta excepción está
> encapsulada aquí y muere cuando bRocket sea reemplazado por bChat (G3).
> En G3 este adaptador se reescribe con gRPC nativo — el contrato con el núcleo no cambia.

---

## 1. Arquitectura del adaptador

```
bNotify núcleo
    │  gRPC (mTLS)
    │  DeliverRequest { delivery_id, ctx_id, recipient, channel_recipient, body, ... }
    ▼
AdapterChat (este servicio)
    │
    ├── bRocket era (G0–G2): Rocket.Chat REST API v1
    │       POST /api/v1/chat.postMessage
    │       Authorization: Bearer {RC_API_TOKEN}
    │
    └── bChat era (G3+): bChat gRPC nativo
            AdapterChannel en el motor de bChat
```

El adaptador implementa el servicio `AdapterChannel` del proto (BNOTIFY-001 §proto).
Para el núcleo bNotify, el canal chat es siempre el mismo contrato gRPC — solo el
backend interno cambia.

---

## 2. Configuración para bRocket

### 2.1 Credenciales de bRocket

bNotify se autentica en bRocket como un **bot de integración** — una cuenta de servicio
con rol `BOT` en Rocket.Chat. Las credenciales se almacenan en Vault:
`sbos/bnotify/adapters/chat/rocketchat/{tenant_id}`

```toml
# /etc/bnotify/adapters/chat.toml
[rocketchat]
base_url = "https://{tenant_id}.sbos.app/chat"
# bot_token y bot_user_id se inyectan desde Vault en arranque
timeout_secs = 10
```

### 2.2 Resolución de `channel_recipient`

El campo `channel_recipient` del `DeliverRequest` (BNOTIFY-001) contiene el ID específico
del canal de destino. Para chat, puede ser:

| Tipo de destino | channel_recipient | API de RC |
|-----------------|:----------------:|-----------|
| Mensaje directo al usuario | `@{username}` | `POST /api/v1/chat.postMessage` con `channel: "@username"` |
| Sala/canal por nombre | `#{room_name}` | `POST /api/v1/chat.postMessage` con `channel: "#room_name"` |
| Sala por ID directo | `roomId:{room_id}` | `POST /api/v1/chat.postMessage` con `roomId: "room_id"` |

El núcleo (resolver.rs) es responsable de poblar `channel_recipient` correctamente
antes de llamar al adaptador.

### 2.3 Payload de la llamada REST a bRocket

```json
POST /api/v1/chat.postMessage
{
  "channel": "{channel_recipient}",
  "text": "{body del DeliverRequest}",
  "alias": "bNotify",
  "attachments": []
}
```

Para mensajes de alta prioridad (clase A — MFA, alertas de seguridad), se agrega:
```json
{
  "priority": "high",
  "attachments": [{ "color": "#FF0000", "text": "⚠️ Acción requerida" }]
}
```

### 2.4 Manejo de errores bRocket

| HTTP status de RC | Significado | DeliveryResult |
|:-----------------:|-------------|:-------------:|
| 200 | Entregado | `DELIVERED` |
| 401 | Token inválido/expirado | `FAILED_TEMPORARY` (renovar token) |
| 404 | Sala/usuario no encontrado | `FAILED_PERMANENT` |
| 429 | Rate limit de RC | `FAILED_TEMPORARY` |
| 500/503 | RC caído o degradado | `CHANNEL_UNAVAILABLE` |
| timeout (>10s) | Sin respuesta | `CHANNEL_UNAVAILABLE` |

---

## 3. Webhook inverso (bRocket → bNotify)

El adaptador también actúa como receptor de webhooks de bRocket para ingestar eventos
hacia NATS (taxonomía BNOTIFY-004):

```
bRocket → POST /hook/chat/{tenant_id}  (endpoint HTTP expuesto por el adaptador)
    │
    ▼
AdapterChat webhook handler
    │
    ├── Clasifica evento por taxonomía BNOTIFY-004
    ├── Asigna clase A/B/C según aud_compliance_map
    └── Publica en NATS subject: bnotify.events.chat.{clase}
```

El webhook de bRocket se configura en la instancia CE 8.5.0:
`Admin → Integraciones → WebHooks entrantes/salientes → URL: https://bnotify.sbos.internal/hook/chat/{tenant_id}`

**Seguridad:** el token secreto del webhook se almacena en Vault y se verifica en cada
llamada entrante (header `X-Rocketchat-Hmac-Sha256`).

---

## 4. Código Rust — estructura del adaptador

```
src/channel/chat/
├── mod.rs              # Implementación del trait AdapterChannel para chat
├── config.rs           # Config: base_url, token, timeout
├── rocketchat.rs       # Cliente HTTP para RC (reqwest) — encapsulado aquí
├── webhook_handler.rs  # Recibe webhooks de RC → clasifica → NATS
└── token_manager.rs    # Refresco del bot token cuando expira
```

El adaptador `chat` implementa el servicio `AdapterChannel` gRPC:

```rust
// Método Deliver — implementación de AdapterChannel para bRocket
async fn deliver(&self, req: DeliverRequest) -> Result<DeliveryResult, Status> {
    let resp = self.rc_client
        .post_message(&req.channel_recipient, &req.body, req.priority)
        .await;
    match resp {
        Ok(_) => Ok(DeliveryResult { status: DELIVERED, ... }),
        Err(RcError::Timeout) => Ok(DeliveryResult { status: CHANNEL_UNAVAILABLE, ... }),
        Err(RcError::NotFound) => Ok(DeliveryResult { status: FAILED_PERMANENT, ... }),
        Err(RcError::RateLimit) => Ok(DeliveryResult { status: FAILED_TEMPORARY, ... }),
    }
}
```

---

## 5. Transición G3: bChat gRPC nativo

Cuando bChat esté operativo (gate G3), este adaptador se **reescribe** en su backend:
- Se elimina todo el código de `rocketchat.rs` y `token_manager.rs`
- Se agrega la llamada gRPC nativa al motor de bChat
- El contrato con el núcleo (proto `AdapterChannel`) **no cambia**
- Los daemons emisores no notan el cambio

Esta es la promesa de D5: cambiar el canal = cambiar el adaptador, no el contrato.

---

*BNOTIFY-011 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*HTTP vive aquí y solo aquí. Cuando muera bRocket, muere también este HTTP. El contrato gRPC sobrevive.*
