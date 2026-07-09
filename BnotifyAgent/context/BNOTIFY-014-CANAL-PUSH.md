---
codigo: BNOTIFY-014
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-002, BNOTIFY-010]
doctrina_que_ejerce: [D4, D5, D12, D14]
criterio_implementado: >
  El adaptador push entrega una notificación de prueba a un dispositivo Android
  real (FCM) y a un dispositivo iOS real (APNs). Ambas notificaciones aparecen
  en el dispositivo. El token de un dispositivo desinstalado retorna
  FAILED_PERMANENT y el registro en bnotify.device_token se marca inactive=true.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-014 — Canal Push
## Adaptador Push: FCM, APNs, UnifiedPush/ntfy — despertar el teléfono al estilo WhatsApp

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 Anexo B (patrón push WhatsApp) · BNOTIFY-002 §6.2 (CAEP device-compliance-change)

---

## 1. Propósito y diseño

El push es la forma en que bNotify despierta el teléfono del usuario cuando la app
no está en primer plano. El objetivo es el patrón WhatsApp:
- Socket persistente mientras la app está abierta
- Push de alta prioridad FCM/APNs para despertar la app cuando está en background
- PushKit/CallKit en iOS para que las llamadas de bChat suenen como llamadas nativas

**D12 — Credenciales propias obligatorias:** en iOS no existe alternativa a APNs
(regla de Apple). En Android FCM es la opción de Google; UnifiedPush/ntfy es la
opción soberana para Android sin Google Services.

---

## 2. Proveedores y credenciales

| Proveedor | Plataforma | Credencial | Almacenamiento |
|-----------|:----------:|-----------|:-------------:|
| **FCM v1** (Firebase Cloud Messaging) | Android | Service Account JSON | Vault: `sbos/bnotify/adapters/push/fcm/{tenant_id}` |
| **APNs** (Apple Push Notification service) | iOS | Certificado `.p8` + Team ID + Key ID | Vault: `sbos/bnotify/adapters/push/apns/{tenant_id}` |
| **UnifiedPush / ntfy** | Android sin Google | URL de endpoint del dispositivo | Tabla `bnotify.device_token.endpoint_url` |

**Nota FCM:** se usa la API **HTTP v1** (no la API legacy). La API legacy fue deprecada
en mayo 2024 y eliminada en junio 2024. Usar siempre FCM v1.

---

## 3. Prioridades de push

### 3.1 Android — FCM v1

```json
{
  "message": {
    "token": "{fcm_device_token}",
    "android": {
      "priority": "HIGH"   // SIEMPRE HIGH para clase A — despierta el teléfono
    },
    "notification": {
      "title": "{subject}",
      "body": "{body}"
    },
    "data": {
      "delivery_id": "{delivery_id}",
      "event_type": "{event_type}",
      "ctx_id": "{ctx_id}"
    }
  }
}
```

Para clase B/C: `"priority": "NORMAL"` — llega cuando el sistema lo considere oportuno.

### 3.2 iOS — APNs

```json
{
  "aps": {
    "alert": {
      "title": "{subject}",
      "body": "{body}"
    },
    "sound": "default",
    "badge": 1,
    "content-available": 1,
    "mutable-content": 1,
    "priority": 10         // 10 = HIGH para clase A; 5 = LOW para clase B/C
  },
  "delivery_id": "{delivery_id}",
  "event_type": "{event_type}"
}
```

### 3.3 PushKit (llamadas iOS — bChat)

Para eventos de llamada entrante (futuro bChat G2+), se usa APNs con el push type `voip`
(PushKit), que despierta la app incluso en modo de bajo consumo y dispara CallKit:

```json
// APNs push-type: voip
{
  "aps": {
    "content-available": 1
  },
  "caller_id": "{caller_user_id}",
  "room_id": "{room_id}",
  "call_type": "audio|video"
}
```

Este tipo de push se implementa cuando bChat tenga llamadas (BNOTIFY-035). Se documenta
aquí para reservar el diseño.

### 3.4 UnifiedPush / ntfy (Android soberano)

Para dispositivos Android sin Google Services, el cliente bChat registra una URL
de endpoint de ntfy (instancia propia del ecosistema):

```
POST {endpoint_url}
Content-Type: application/json
{
  "title": "{subject}",
  "message": "{body}",
  "priority": 5,   // 1=min, 5=max
  "tags": ["{event_type}"]
}
```

El endpoint_url se almacena en `bnotify.device_token.endpoint_url` cuando el dispositivo
se registra con provider='ntfy'.

---

## 4. Registro y ciclo de vida de tokens

### 4.1 Registro del token

El cliente Flutter registra su token de push al iniciar sesión:

```
gRPC → bNotify.RegisterPushToken(user_id, ctx_id, platform, provider, token, endpoint_url)
→ INSERT INTO bnotify.device_token ON CONFLICT DO UPDATE SET token=..., active=true
```

### 4.2 Invalidación automática de tokens

Cuando FCM/APNs retornan que el token es inválido (dispositivo desinstalado o token vencido):

```
DeliveryResult.status = FAILED_PERMANENT
→ UPDATE bnotify.device_token SET active=false WHERE token={token}
→ Audit event: "notify.push.token_invalidated" (clase B)
```

### 4.3 Revocación por CAEP (device-compliance-change)

Cuando bAuth emite `CAEP { event_type: "device-compliance-change", device_id }`:
- bNotify busca el token del dispositivo en `bnotify.device_token` por `ctx_id`
- Marca `active=false` el token del dispositivo afectado
- Las próximas notificaciones a ese usuario no llegan a ese dispositivo

---

## 5. Manejo de errores

| Error | Proveedor | DeliveryResult |
|-------|:---------:|:-------------:|
| Token inválido / no registrado | FCM/APNs | `FAILED_PERMANENT` (invalida token) |
| Cuota excedida | FCM | `FAILED_TEMPORARY` |
| Certificado APNs expirado | APNs | `CHANNEL_UNAVAILABLE` (alerta operaciones) |
| Timeout (>10s) | Cualquiera | `CHANNEL_UNAVAILABLE` |

---

## 6. Código Rust — estructura del adaptador

```
src/channel/push/
├── mod.rs              # Dispatcher push: elige FCM, APNs o UnifiedPush según platform
├── config.rs           # PushConfig: credenciales, timeouts
├── fcm.rs              # Cliente FCM v1 HTTP (reqwest + rustls)
├── apns.rs             # Cliente APNs HTTP/2 con certificado .p8 (reqwest + rustls)
├── unified_push.rs     # Cliente HTTP para ntfy/UnifiedPush
└── token_registry.rs   # Registro/invalidación de tokens (escribe en bnotify.device_token)
```

---

*BNOTIFY-014 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*FCM v1 (no legacy). APNs con .p8 (no certificados). ntfy para soberanía Android. PushKit reservado para llamadas bChat.*
