---
codigo: BNOTIFY-035
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-032, BNOTIFY-033]
doctrina_que_ejerce: [D2, D5, D12, D14]
criterio_implementado: >
  Una llamada de voz 1:1 entre dos clientes Flutter conecta en < 3 segundos.
  El audio es inteligible sin artefactos. La llamada finaliza correctamente al colgar
  cualquiera de los dos participantes. Las salas tipo 'Meet' soportan ≥ 8 participantes
  simultáneos con video habilitado (Gate G3 en VPS real).
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-035 — bChat LiveKit
## Llamadas 1:1, voz, salas Meet sobre LiveKit 1.8.x + SDK Flutter

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §A.0.4 (ADR-004: LiveKit sobre Jitsi) · BNOTIFY-033 (cliente Flutter)

---

## 1. Por qué LiveKit (ADR-004)

La decisión entre LiveKit y Jitsi está documentada en ADR-004 de BNOTIFY-007. Resumen:

- **Jitsi** usa una arquitectura de conferencia basada en Videobridge con alta complejidad operacional para llamadas 1:1 pequeñas y acoplada a XMPP
- **LiveKit** usa SFU (Selective Forwarding Unit) nativo WebRTC con SDK oficial Flutter, API simple y probada en producción con millones de usuarios
- **LiveKit es soberano:** LiveKit Server es open source (Apache 2.0) y se despliega en nuestro K8s — ningún dato de audio/video sale del servidor del cliente

---

## 2. Arquitectura de llamadas

```
Cliente A (Flutter)                 Cliente B (Flutter)
│                                   │
│ 1. bchat.call.invite(user_b)       │
│──────────────────────────────────►│ 2. Notification "bchat.call.incoming"
│                                   │
│                  3. bchat.call.accept(call_id)
│◄──────────────────────────────────│
│
│ 4. bchat.call.join_token(call_id) ─► Motor bChat
│                                      │ Genera Access Token JWT (LiveKit)
│                                      │ firmado con API Key + Secret de Vault
│                                   ◄──│ { livekit_url, token }
│
│ 5. livekit_client.connect(livekit_url, token)
│──────────────────────────────────────────────► LiveKit Server (K8s)
│                   Cliente B conecta igual ─────►│
│                                                  │ WebRTC SFU
│◄─────────────────── Audio/Video stream ──────────│
```

### 2.1 Access Token LiveKit

El motor bChat genera el Access Token usando la librería `livekit-api` Rust:

```rust
// services/call.rs
pub fn generate_livekit_token(
    api_key: &str,
    api_secret: &str,
    room_name: &str,
    participant_identity: &str,
    can_publish: bool,
) -> Result<String, BchatError> {
    let grants = VideoGrants {
        room_join: true,
        room: room_name.to_string(),
        can_publish,
        can_subscribe: true,
        ..Default::default()
    };
    livekit_api::generate_token(api_key, api_secret, participant_identity, grants)
        .map_err(BchatError::TokenGeneration)
}
```

El Access Token tiene TTL de 1 hora (suficiente para cualquier llamada). Si la llamada supera 1h, el cliente solicita un nuevo token via `bchat.call.refresh_token`.

---

## 3. Tipos de sala LiveKit

| Tipo | Participantes | Uso |
|------|:------------:|-----|
| `call_1to1` | 2 (max) | Llamada directa entre dos usuarios |
| `call_group` | ≤ 16 | Llamada grupal desde una sala de chat |
| `meet` | ≤ 100 (G3) | Sala de reunión tipo videoconferencia |

El nombre de sala en LiveKit sigue el patrón: `{tenant_id}_{room_type}_{call_id}`.

---

## 4. Flujo de señalización (bChat como servidor de señalización)

La señalización de llamadas usa el canal WebSocket + JSON-RPC 2.0 ya establecido (BNOTIFY-030). No se usa el servidor de señalización de LiveKit para la oferta/aceptación de llamada — eso va por bChat para poder integrar notificaciones y CAEP.

### Métodos JSON-RPC de llamadas

| Método | Emisor | Descripción |
|--------|--------|-------------|
| `bchat.call.invite` | Llamante | Inicia llamada a un usuario |
| `bchat.call.incoming` | Servidor | Notifica la llamada al destinatario |
| `bchat.call.accept` | Destinatario | Acepta la llamada |
| `bchat.call.reject` | Destinatario | Rechaza la llamada |
| `bchat.call.join_token` | Cualquiera | Obtiene el JWT de LiveKit para conectar |
| `bchat.call.end` | Cualquiera | Termina la llamada |
| `bchat.call.refresh_token` | Cualquiera | Renueva el JWT (llamadas >1h) |

### Integración con PushKit/CallKit

Para iOS, las llamadas de voz entrantes activadas mientras la app está en background usan **PushKit** (no FCM Push normal). La notificación PushKit activa **CallKit** en iOS para mostrar la UI de llamada nativa.

Para Android, las llamadas entrantes se entregan por FCM con prioridad HIGH y la app levanta la pantalla de llamada.

---

## 5. Despliegue de LiveKit Server en K8s

```yaml
# K8s namespace: bns-messaging (mismo que bRocket durante la era de coexistencia)
# Deployment: livekit-server

apiVersion: apps/v1
kind: Deployment
metadata:
  name: livekit-server
  namespace: bns-messaging
spec:
  replicas: 1          # G2: un nodo es suficiente para 100 llamadas simultáneas
  selector:
    matchLabels:
      app: livekit-server
  template:
    spec:
      containers:
        - name: livekit-server
          image: livekit/livekit-server:v1.8.x
          env:
            - name: LIVEKIT_CONFIG
              valueFrom:
                secretKeyRef:
                  name: livekit-secrets
                  key: config.yaml
```

**Configuración de LiveKit** (inyectada desde Vault):

```yaml
# livekit-config.yaml (secreto en Vault sbos/bchat/livekit)
port: 7880
rtc:
  tcp_port: 7881
  udp_port: 7882
  use_external_ip: false
keys:
  bChat-api-key: "{API_SECRET_FROM_VAULT}"
```

---

## 6. Grabación (G5 — opcional)

La grabación de llamadas no es parte del scope de G3. Si en el futuro se activa:
- LiveKit EgressService graba a S3 (MinIO soberano)
- El registro se guarda en `bchat.call_recording` (tabla no definida aún)
- La activación requiere consentimiento explícito de todos los participantes (D11)

Esta decisión queda pendiente para Gate G5.

---

*BNOTIFY-035 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*La señalización viaja por bChat (JSON-RPC). El audio/video viaja por LiveKit (WebRTC). Nunca al revés.*
