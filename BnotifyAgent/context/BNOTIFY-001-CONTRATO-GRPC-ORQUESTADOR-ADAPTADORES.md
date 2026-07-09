---
codigo: BNOTIFY-001
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D4, D5, D11, D14]
criterio_implementado: >
  El archivo bnotify.proto compila con protoc sin errores.
  El servicio NotifyDispatcher responde a un DispatchRequest de prueba
  con DispatchResponse.status = ACCEPTED en la VPS de staging.
  Los adaptadores chat y email implementan el servicio AdapterChannel
  y responden DeliveryResult.status = DELIVERED a un mensaje de prueba.
---

# BNOTIFY-001 — Contrato gRPC Orquestador↔Adaptadores
## Definición proto del evento común y protocolo de entrega

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §3, §4.2 · ADR-001 · ADR-008
**Primer artefacto técnico del proyecto — todo lo demás depende de este contrato.**

---

## 1. Principio de diseño

El payload del intent es **independiente del canal**. Un daemon emisor (bAuth, bPay,
bCalendar) construye un `DispatchRequest` sin saber nada sobre el canal de destino.
bNotify decide el canal; el adaptador encapsula la mecánica concreta del canal.

**La frontera exacta:**
```
Daemon emisor → [gRPC] → bNotify (orquestador) → [gRPC] → Adaptador → [canal concreto]
                                                                       (REST/SMTP/SMPP/FCM)
```

Toda comunicación entre bNotify y adaptadores es gRPC sobre mTLS (ADR-001).
Los adaptadores NO usan REST, SMTP ni FCM directamente desde bNotify — lo hacen ellos
mismos, encapsulado. Para bNotify, todos los canales hablan el mismo gRPC.

---

## 2. Definición proto — bnotify.proto

```protobuf
syntax = "proto3";
package bnotify.v1;

// ─── Tipos comunes ────────────────────────────────────────────────────────────

// Nivel de urgencia del evento. Determina la cola de despacho y el failover.
enum Priority {
  PRIORITY_UNSPECIFIED = 0;
  PRIORITY_A = 1;  // Crítico: OTP, alerta seguridad, wallet. WORM individual.
  PRIORITY_B = 2;  // Transaccional: factura, calendario, sincronización.
  PRIORITY_C = 3;  // Informativo: resúmenes, badges, presencia.
}

// Canal de entrega preferido o solicitado.
enum Channel {
  CHANNEL_UNSPECIFIED = 0;
  CHANNEL_CHAT = 1;     // bRocket (hoy) / bChat (G3+)
  CHANNEL_EMAIL = 2;
  CHANNEL_SMS = 3;
  CHANNEL_PUSH = 4;     // FCM/APNs/UnifiedPush
  CHANNEL_INAPP = 5;    // WebSocket en tiempo real
  CHANNEL_WEBHOOK = 6;  // HTTP a endpoint externo
}

// Tipo de destino de la notificación.
enum DestinationType {
  DESTINATION_USER = 0;        // Un usuario por UUID de bAuth
  DESTINATION_ROLE = 1;        // Un rol — bNotify expande a UUIDs
  DESTINATION_AUDIENCE = 2;    // Lista propia de bNotify
  DESTINATION_CHANNEL_ROOM = 3; // Sala/canal nativo del chat
}

// ─── Servicio principal: Orquestador ─────────────────────────────────────────

// Servicio que bNotify expone a los daemons emisores.
service NotifyDispatcher {
  // Enviar un intent de notificación. Respuesta inmediata: aceptado/rechazado.
  // La entrega efectiva es asíncrona — usar QueryDelivery para estado.
  rpc Dispatch(DispatchRequest) returns (DispatchResponse);

  // Consultar el estado de entrega de un intent previamente aceptado.
  rpc QueryDelivery(QueryDeliveryRequest) returns (QueryDeliveryResponse);

  // Health check del orquestador.
  rpc Health(HealthRequest) returns (HealthResponse);
}

// Intent de notificación enviado por un daemon emisor.
message DispatchRequest {
  // Clave de idempotencia: el mismo intent_id produce un solo despacho.
  // UUID v4 generado por el emisor.
  string intent_id = 1;

  // ctx_id de la sesión que originó el evento. SBOS-049. Obligatorio.
  string ctx_id = 2;

  // tenant del contexto. Determina las preferencias y plantillas a usar.
  string tenant_id = 3;

  // Quién origina el evento (daemon o subsistema).
  string emitter = 4;  // Ej: "bauth", "bpay", "bcalendar"

  // Tipo de evento de dominio. Determina la plantilla y la clase de auditoría.
  // Formato: "<dominio>.<recurso>.<acción>" — Ej: "invoice.issued", "mfa.challenge"
  string event_type = 5;

  // Destino de la notificación.
  Destination destination = 6;

  // Datos para rellenar la plantilla. Pares clave-valor arbitrarios.
  map<string, string> template_data = 7;

  // Urgencia del evento. Determina la cola y el failover.
  Priority priority = 8;

  // Canales candidatos en orden de preferencia. Si vacío, bNotify decide.
  repeated Channel preferred_channels = 9;

  // Tiempo de vida del intent en segundos. 0 = sin límite de TTL.
  // Un intent clase A nunca expira (TTL = 0).
  uint32 ttl_seconds = 10;
}

// Destinatario de la notificación.
message Destination {
  DestinationType type = 1;

  // Para DESTINATION_USER: UUID de bAuth del destinatario.
  // Para DESTINATION_ROLE: código de rol ("FINANCIERO_N1").
  // Para DESTINATION_AUDIENCE: ID de audiencia propia de bNotify.
  // Para DESTINATION_CHANNEL_ROOM: ID de sala/canal en el chat.
  string id = 2;
}

// Respuesta inmediata al Dispatch. Confirma que el intent fue aceptado,
// no que fue entregado. La entrega es asíncrona.
message DispatchResponse {
  enum Status {
    ACCEPTED = 0;         // Intent válido, encolado para despacho
    REJECTED_DUPLICATE = 1; // intent_id ya existe (idempotencia)
    REJECTED_INVALID = 2;   // Payload inválido (ctx_id faltante, etc.)
    REJECTED_RATE_LIMITED = 3; // El destinatario excedió su límite de frecuencia
    REJECTED_OPT_OUT = 4;   // El destinatario hizo opt-out de este tipo de evento
  }
  Status status = 1;

  // ID interno de seguimiento de bNotify. Distinto del intent_id del emisor.
  string delivery_id = 2;

  // Razón del rechazo, si aplica.
  string rejection_reason = 3;
}

// Consulta de estado de entrega.
message QueryDeliveryRequest {
  string delivery_id = 1;
  string ctx_id = 2;
}

message QueryDeliveryResponse {
  enum DeliveryStatus {
    PENDING = 0;
    IN_FLIGHT = 1;
    DELIVERED = 2;
    FAILED_RETRYING = 3;
    FAILED_PERMANENT = 4;  // Agotó reintentos — está en DLQ
  }
  DeliveryStatus status = 1;
  Channel channel_used = 2;
  string delivered_at = 3;   // RFC3339 timestamp, si entregado
  uint32 attempt_count = 4;
  string failure_reason = 5; // Si aplica
}

// Health check.
message HealthRequest {}
message HealthResponse {
  bool operational = 1;
  map<string, bool> adapter_status = 2; // Estado de cada adaptador
}

// ─── Servicio de adaptador: implementado por cada canal ──────────────────────

// Interfaz que cada adaptador implementa. bNotify llama a cada adaptador
// con el mismo contrato, independientemente del canal concreto.
service AdapterChannel {
  // Entregar una notificación por este canal.
  rpc Deliver(DeliverRequest) returns (DeliveryResult);

  // Health check del adaptador.
  rpc Health(HealthRequest) returns (HealthResponse);
}

// Solicitud de entrega enviada por bNotify al adaptador.
message DeliverRequest {
  string delivery_id = 1;      // ID de seguimiento de bNotify
  string ctx_id = 2;           // Propagado desde el intent original
  string tenant_id = 3;
  string recipient_user_id = 4; // UUID de bAuth del destinatario resuelto
  string channel_recipient = 5; // ID específico del canal: email, número, room_id, etc.
  string subject = 6;           // Asunto (email), título (push)
  string body = 7;              // Cuerpo del mensaje ya renderizado desde plantilla
  Priority priority = 8;
  map<string, string> channel_metadata = 9; // Datos específicos del canal
}

// Resultado de la entrega por el adaptador.
message DeliveryResult {
  enum Status {
    DELIVERED = 0;
    FAILED_TEMPORARY = 1;   // Error transitorio — bNotify reintentará
    FAILED_PERMANENT = 2;   // Error definitivo — ir a DLQ
    CHANNEL_UNAVAILABLE = 3; // Canal caído — failover a otro canal
  }
  Status status = 1;
  string provider_message_id = 2; // ID del proveedor externo si aplica
  string failure_reason = 3;
  string delivered_at = 4;        // RFC3339 timestamp
}
```

---

## 3. Comportamiento de reintentos y failover

### 3.1 Política de reintentos por clase

| Clase | Máx. intentos | Backoff | Acción tras agotar |
|-------|:-------------:|---------|-------------------|
| A | 5 | Exponencial: 30s, 60s, 120s, 300s, 600s | Failover obligatorio a canal secundario, luego DLQ con alarma |
| B | 3 | Exponencial: 60s, 300s, 900s | DLQ con alarma |
| C | 1 | — | Descartar silenciosamente, registrar en métricas |

### 3.2 Orden de failover por defecto

```
CHAT → PUSH → EMAIL → SMS
```

Solo activo para eventos clase A. La política de failover es configurable por tipo de evento.

### 3.3 Dead Letter Queue (DLQ)

Un intent en DLQ:
1. Se registra en `bnotify.notification_event` con `status = FAILED_PERMANENT`
2. Genera un evento de auditoría clase A
3. Genera una alarma en el canal de operaciones (#operaciones en bRocket)
4. Permanece consultable por `QueryDelivery` indefinidamente

---

## 4. Identidad de los adaptadores — mTLS

Cada adaptador se autentica ante bNotify con un certificado cliente emitido por la
CA interna del ecosistema (Vault PKI). El Common Name del certificado es el nombre
del canal: `bnotify-adapter-chat`, `bnotify-adapter-email`, etc.

bNotify rechaza cualquier conexión sin certificado válido o con CN no reconocido.

---

## 5. Mapeo event_type → canal default y clase de auditoría

| event_type (prefijos) | Canal default | Clase | TTL |
|----------------------|:-------------:|:-----:|:---:|
| `mfa.*` | CHAT → PUSH → SMS | A | 0 (sin TTL) |
| `security.*` | CHAT → SMS | A | 0 |
| `wallet.*`, `payment.*` | CHAT → EMAIL | A | 0 |
| `invoice.*`, `calendar.*` | CHAT → EMAIL | B | 86400s (24h) |
| `role.changed`, `sync.*` | CHAT | B | 3600s (1h) |
| `system.*`, `presence.*` | INAPP | C | 300s (5min) |

Esta tabla es la configuración por defecto. Las preferencias de usuario la sobrescriben
para eventos clase B y C. Los eventos clase A no pueden ser suprimidos por preferencias.

---

## 6. Propagación de ctx_id

El ctx_id del intent **nunca cambia** en toda la cadena de despacho:
- Emisor → bNotify: en el campo `ctx_id` del `DispatchRequest`
- bNotify → Adaptador: en el campo `ctx_id` del `DeliverRequest`
- Adaptador → canal externo: en el header/metadata del mensaje cuando el canal lo soporta
- En todos los registros de `bnotify.notification_event`

Si el emisor no envía ctx_id, bNotify genera uno nuevo y lo registra como
`"ctx_id_generado_por_bnotify"` en el campo de razón del evento de auditoría.

---

## 7. Archivos del proyecto que implementan este contrato

| Archivo | Responsabilidad |
|---------|----------------|
| `proto/bnotify.proto` | Definición canónica (este documento) |
| `src/server/grpc.rs` | Implementación de `NotifyDispatcher` en bNotify |
| `src/channel/chat.rs` | Implementación de `AdapterChannel` para bRocket/bChat |
| `src/channel/email.rs` | Implementación de `AdapterChannel` para email |
| `src/channel/sms.rs` | Implementación de `AdapterChannel` para SMS |
| `src/channel/push.rs` | Implementación de `AdapterChannel` para push |
| `src/channel/webhook.rs` | Implementación de `AdapterChannel` para webhooks |

---

*BNOTIFY-001 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Este es el contrato que hace intercambiables a todos los canales. Cambiar un canal = cambiar un adaptador.*
