# SBOS Notify — bnotify
## Manual de Uso · v1.0.0 · SKULL · Mayo 2026

---

> **Para agentes IA:** Este documento está estructurado para lectura tanto humana como programática. Cada sección lleva una etiqueta `[AI-HINT]` con instrucciones precisas de uso. Los ejemplos de código son ejecutables sin modificación salvo los placeholders `{tenant}`, `{user_id}` y similares. Nunca generes código que llame a Telegram, Twilio o SMTP directamente desde una app — siempre publica en el Redis Stream correspondiente y deja que biedata despache.

---

## Índice

1. [¿Qué es bnotify?](#1-qué-es-bnotify)
2. [Arquitectura en el SBOS](#2-arquitectura-en-el-sbos)
3. [Canales disponibles](#3-canales-disponibles)
4. [Cómo enviar una notificación](#4-cómo-enviar-una-notificación)
5. [Push MFA — doble autenticación](#5-push-mfa--doble-autenticación)
6. [Integración con Vue / Laravel](#6-integración-con-vue--laravel)
7. [Integración con Flutter desktop](#7-integración-con-flutter-desktop)
8. [Integración CLI / terminal](#8-integración-cli--terminal)
9. [Configurar canales de un usuario](#9-configurar-canales-de-un-usuario)
10. [Templates de mensajes](#10-templates-de-mensajes)
11. [Reglas bKernel — notificaciones automáticas](#11-reglas-bkernel--notificaciones-automáticas)
12. [Operación y monitoreo](#12-operación-y-monitoreo)
13. [Referencia de la API HTTP](#13-referencia-de-la-api-http)
14. [Referencia del Redis Stream](#14-referencia-del-redis-stream)
15. [Checklist de integración](#15-checklist-de-integración)
16. [Errores comunes](#16-errores-comunes)

---

## 1. ¿Qué es bnotify?

**bnotify** (SBOS Notify) es la ficha de notificaciones universales del SBOS. Actúa como el despachador central de mensajes del sistema hacia personas: administradores, clientes finales, operadores.

**Lo que hace bnotify:**
- Recibe eventos del sistema (del WAL vía bKernel o de llamadas directas a su API)
- Despacha los mensajes por el canal configurado para cada destinatario
- Registra en PostgreSQL cada envío con su `ctx_id` de auditoría
- Gestiona el flujo Push MFA para doble autenticación de Keycloak

**Lo que NO hace bnotify:**
- No autentica a los destinatarios externos — los mensajes son del sistema a persona
- No llama directamente a Telegram, Twilio ni SMTP — eso lo hace biedata
- No es un chat entre personas — es un bus de eventos del sistema

**Casos de uso principales:**

| Caso | Quién recibe | Canal típico |
|------|-------------|--------------|
| Factura emitida | Cliente final | WhatsApp / Email |
| Error crítico en proceso | Administrador | Telegram / CLI |
| Tarea pendiente vencida | Usuario asignado | Desktop / Telegram |
| Push MFA — ¿eres tú? | Usuario que inicia sesión | Telegram / ntfy app |
| Alerta de sistema K8s | DevOps / Admin | CLI / Telegram |
| Validación fallida en importación | Operador | Desktop toast / CLI |

---

## 2. Arquitectura en el SBOS

```
┌─────────────────────────────────────────────────────────┐
│                    Aplicaciones SBOS                    │
│  Vue Frontend  │  Laravel API  │  Flutter Desktop  │ CLI │
└───────┬────────┴───────┬───────┴────────┬──────────┴──┬──┘
        │                │                │             │
        │  WebSocket     │  HTTP POST     │  WebSocket  │ subscribe
        │  (suscribe)    │  /notify       │  (suscribe) │
        ▼                ▼                ▼             ▼
┌───────────────────────────────────────────────────────────┐
│                    Kong (API Gateway)                     │
│           Inyecta X-SBOS-CtxId en cada request           │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────────┐
│                   sbos-notifier pod                       │
│                                                           │
│  ┌─────────────────────┐  ┌──────────────────────────┐   │
│  │  App principal      │  │  Sidecar ntfy            │   │
│  │  puerto 28200       │  │  puerto 28204 (HTTP)     │   │
│  │                     │  │  puerto 28205 (WebSocket) │   │
│  │  - API REST         │  │  Bus pub/sub interno     │   │
│  │  - MFA confirm      │  │  Topics por tenant       │   │
│  │  - Consumer streams │  │  Cache SQLite            │   │
│  └──────────┬──────────┘  └─────────────┬────────────┘   │
└─────────────┼───────────────────────────┼────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────┐   ┌───────────────────────────┐
│   Redis DB3             │   │   PostgreSQL              │
│   Streams y cache       │   │   notifier_db             │
│   biedata:notify:*      │   │   - notification_events   │
│   mfa:challenges:*      │   │   - notification_channels │
└────────────┬────────────┘   │   - mfa_challenges        │
             │                │   - notification_templates│
             ▼                └───────────────────────────┘
┌────────────────────────────────────────────────────────────┐
│                    biedata (cajas)                         │
│                                                            │
│  caja mfa-push      caja notify-external  caja notify-cli │
│  (Push MFA)         (Telegram/WA/Email)   (ntfy/CLI)      │
└────────┬────────────────────┬─────────────────────────────┘
         │                    │
         ▼                    ▼
   Celular usuario      Destinos externos
   (botón SÍ/NO)        Telegram · WhatsApp · Email · Desktop
```

### Flujo de un mensaje desde el WAL

```
1. Módulo escribe en su BD (tryton, saleor, etc.)
2. bKernel detecta el cambio via WAL
3. bKernel publica en Redis Stream biedata:notify:{tenant}
4. biedata caja notify-external consume el stream
5. Resuelve template + canal del destinatario desde notifier_db
6. Despacha al canal externo (Telegram API, Twilio, SMTP)
7. Registra resultado en notifier_db.notification_events
```

---

## 3. Canales disponibles

| Canal | Código | Plataformas | Requiere config |
|-------|--------|-------------|----------------|
| Telegram Bot | `telegram` | Android, iOS, Desktop, Web | Bot token en Vault + chat_id del usuario |
| WhatsApp | `whatsapp` | Android, iOS, WhatsApp Web | Cuenta Twilio en Vault + número del usuario |
| Email SMTP | `email` | Todos | Credenciales SMTP en Vault + email del usuario |
| Push desktop (ntfy app) | `ntfy` | Linux, Windows, macOS, Android, iOS | App ntfy instalada + topic suscrito |
| CLI / terminal | `cli` | Linux, macOS, Windows (WSL) | `ntfy subscribe` o `bosctl notify subscribe` |
| WebSocket web | `websocket` | Vue, React, cualquier browser | Frontend suscrito al topic por WS |
| Push MFA | `mfa` | Telegram o ntfy | Canal MFA configurado para el usuario |

---

## 4. Cómo enviar una notificación

`[AI-HINT]` Hay dos formas de enviar: **API HTTP directa** (para código que tiene ctx_id y ya está dentro del SBOS) o **publicar en Redis Stream** (para scripts, cronjobs y módulos batch). Nunca llames a Telegram/Twilio/SMTP directamente.

### 4.1 Vía API HTTP (desde Laravel, Vue backend, módulos)

```http
POST /notify
Host: sbos-{tenant}.sksistemas.com
Content-Type: application/json
Authorization: Bearer {jwt_de_servicio}
X-SBOS-CtxId: ctx-abc-123

{
  "type":          "factura-emitida",
  "recipient_id":  "usr_456",
  "channels":      ["telegram", "email"],
  "template_vars": {
    "invoice_number": "FAC-2026-001",
    "amount":         "1500.00",
    "currency":       "BOB",
    "partner_name":   "Juan Pérez"
  }
}
```

**Respuesta exitosa:**
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "ctx_id":   "ctx-abc-123",
  "status":   "queued",
  "channels": ["telegram", "email"]
}
```

### 4.2 Vía Redis Stream (desde scripts, bKernel, batch)

```bash
# Desde bash / script del sistema
redis-cli -n 3 XADD biedata:notify:{tenant} '*' \
  ctx_id        "ctx-abc-123" \
  type          "error-critico" \
  severity      "critical" \
  source_module "importador-batch" \
  recipient_id  "usr_admin" \
  channels      '["telegram","cli"]' \
  template_vars '{"message":"Fallo en importación línea 847","source_module":"importador-batch"}'
```

```python
# Desde Python (módulo interno SBOS)
import redis, json

r = redis.Redis(host='redis', port=6379, db=3)
r.xadd(f'biedata:notify:{tenant}', {
    'ctx_id':        ctx_id,
    'type':          'tarea-pendiente',
    'severity':      'warning',
    'source_module': 'bcompass',
    'recipient_id':  user_id,
    'channels':      json.dumps(['telegram', 'ntfy']),
    'template_vars': json.dumps({
        'title':       'Revisar facturas pendientes',
        'due_date':    '2026-05-30',
        'assigned_to': 'admin@empresa.com'
    })
})
```

```php
// Desde Laravel (servicio interno SBOS)
use Illuminate\Support\Facades\Redis;

Redis::connection('notifier')->xadd(
    "biedata:notify:{$tenant}",
    '*',
    [
        'ctx_id'        => $ctxId,
        'type'          => 'factura-emitida',
        'severity'      => 'info',
        'source_module' => 'facturacion',
        'recipient_id'  => $userId,
        'channels'      => json_encode(['whatsapp', 'email']),
        'template_vars' => json_encode([
            'invoice_number' => 'FAC-2026-001',
            'amount'         => '1500.00',
            'currency'       => 'BOB',
            'partner_name'   => 'Juan Pérez',
        ]),
    ]
);
```

### 4.3 Vía CLI desde terminal del servidor

```bash
# Enviar alerta directa desde bash
bosctl notify send \
  --tenant=acme \
  --type=alerta-sistema \
  --to=admin \
  --channel=cli \
  --msg="Backup S03 completado: 3.2GB" \
  --severity=info

# Equivalente con curl directo a ntfy
curl -d "Backup S03 completado: 3.2GB" \
  -H "Title: [INFO] backup" \
  -H "X-SBOS-CtxId: ctx-backup-$(date +%s)" \
  http://localhost:28204/acme-cli-alerts
```

---

## 5. Push MFA — doble autenticación

`[AI-HINT]` El Push MFA es activado por el SPI de Keycloak `PushMfaSPI`. Cuando implementes o modifiques el flujo de login, NO llames a bnotify directamente desde el SPI. El SPI debe insertar un registro en `notifier_db.mfa_challenges` y esperar polling en Redis. bKernel detecta el INSERT via WAL y dispara la caja mfa-push.

### Flujo completo

```
Usuario: ingresa user + password en la app desktop
         │
         ▼
Keycloak: valida credenciales → activa PushMfaSPI
         │
         ▼
PushMfaSPI: INSERT en notifier_db.mfa_challenges
            {user_id, geo, device_info, expires_at: +60s}
         │
         ▼
bKernel: detecta INSERT via WAL
         → publica en Redis Stream mfa:challenges:{tenant}
         │
         ▼
biedata caja mfa-push: despacha mensaje al celular
  ┌──────────────────────────────────────────┐
  │ 🔐 Intento de acceso a SBOS              │
  │ 📍 Desde: La Paz, Bolivia                │
  │ 💻 Chrome 124 / Ubuntu                   │
  │                                          │
  │  [✅ SÍ, SOY YO]  [❌ NO FUI YO]        │
  └──────────────────────────────────────────┘
         │
         ├── Usuario presiona ✅
         │   POST /api/mfa/confirm/{token}?action=confirm
         │   Kong → sbos-notifier → verifica JWT del token
         │   → Redis SET mfa:{token}:status = "confirmed"
         │   → PushMfaSPI polling detecta CONFIRMED
         │   → Keycloak emite JWT con BitMask completo ✓
         │
         └── Usuario presiona ❌
             POST /api/mfa/confirm/{token}?action=deny
             → Redis SET mfa:{token}:status = "denied"
             → bKernel registra intento sospechoso en audit_events
             → Keycloak bloquea la sesión
```

### Implementar PushMfaSPI en Keycloak

```java
// Fragmento del SPI — archivo completo en /etc/bos/blibs/keycloak/spis/PushMfaSPI.java
public class PushMfaSPI implements Authenticator {

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String userId  = context.getUser().getId();
        String ctxId   = context.getHttpRequest().getHttpHeaders()
                           .getHeaderString("X-SBOS-CtxId");
        String geo     = resolveGeo(context.getConnection().getRemoteAddr());
        String device  = context.getHttpRequest().getHttpHeaders()
                           .getHeaderString("User-Agent");

        // 1. Insertar challenge en PostgreSQL — bKernel lo detecta via WAL
        String token = insertMfaChallenge(userId, ctxId, geo, device);

        // 2. Polling en Redis (máx 60s, cada 500ms)
        String status = pollRedisForConfirmation(token, 60_000, 500);

        if ("confirmed".equals(status)) {
            context.success();
        } else {
            context.failure(AuthenticationFlowError.INVALID_CREDENTIALS);
        }
    }

    private String insertMfaChallenge(String userId, String ctxId,
                                       String geo, String device) {
        // INSERT INTO notifier_db.mfa_challenges
        // (user_id, ctx_id, geo, device_info, expires_at)
        // VALUES (?, ?, ?, ?, NOW() + INTERVAL '60 seconds')
        // RETURNING challenge_token
        // ... implementación con JDBC
        return challengeToken;
    }

    private String pollRedisForConfirmation(String token,
                                             int timeoutMs, int intervalMs) {
        long deadline = System.currentTimeMillis() + timeoutMs;
        Jedis redis = getRedisDB1();
        while (System.currentTimeMillis() < deadline) {
            String status = redis.get("mfa:" + token + ":status");
            if (status != null) return status;
            Thread.sleep(intervalMs);
        }
        return "timeout";
    }
}
```

### Configurar canal MFA de un usuario

```http
POST /notify/channels
Content-Type: application/json
Authorization: Bearer {jwt_admin}

{
  "user_id": "usr_456",
  "channel": "mfa",
  "address": "987654321",
  "meta": {
    "provider": "telegram",
    "chat_id":  "987654321"
  }
}
```

---

## 6. Integración con Vue / Laravel

`[AI-HINT]` Para Vue: suscríbete al WebSocket de ntfy en el componente montado. Para Laravel: publica en el Redis Stream desde un Job o Event Listener. Nunca llames a la API externa desde el frontend.

### Vue 3 — suscripción WebSocket en tiempo real

```javascript
// composables/useNotifications.js
import { ref, onMounted, onUnmounted } from 'vue'

export function useNotifications(tenant, topic = 'admin-alerts') {
  const messages  = ref([])
  const connected = ref(false)
  let   socket    = null

  const connect = () => {
    const wsUrl = `wss://${tenant}.sksistemas.com/ntfy/${tenant}-${topic}/ws`
    socket = new WebSocket(wsUrl)

    socket.onopen = () => {
      connected.value = true
      console.log(`[bnotify] conectado al topic ${topic}`)
    }

    socket.onmessage = (event) => {
      const msg = JSON.parse(event.data)
      if (msg.event === 'message') {
        messages.value.unshift({
          id:       msg.id,
          title:    msg.title,
          body:     msg.message,
          priority: msg.priority,
          tags:     msg.tags || [],
          time:     new Date(msg.time * 1000)
        })
      }
    }

    socket.onclose = () => {
      connected.value = false
      // Reconexión automática en 3s
      setTimeout(connect, 3000)
    }
  }

  onMounted(connect)
  onUnmounted(() => socket?.close())

  return { messages, connected }
}
```

```vue
<!-- components/NotificationBell.vue -->
<template>
  <div class="notification-bell">
    <span v-if="messages.length > 0" class="badge">{{ messages.length }}</span>
    <ul v-if="showList">
      <li v-for="msg in messages" :key="msg.id"
          :class="`priority-${msg.priority}`">
        <strong>{{ msg.title }}</strong>
        <p>{{ msg.body }}</p>
        <time>{{ msg.time.toLocaleTimeString() }}</time>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { useNotifications } from '@/composables/useNotifications'
const { messages } = useNotifications('acme', 'client-notify')
</script>
```

### Laravel — enviar notificación desde un Event Listener

```php
<?php
// app/Listeners/NotificarFacturaEmitida.php
namespace App\Listeners;

use App\Events\FacturaEmitida;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Str;

class NotificarFacturaEmitida
{
    public function handle(FacturaEmitida $event): void
    {
        $tenant = tenant()->id;
        $ctxId  = request()->header('X-SBOS-CtxId', 'ctx-' . Str::uuid());

        Redis::connection('notifier')->xadd(
            "biedata:notify:{$tenant}",
            '*',
            [
                'ctx_id'        => $ctxId,
                'type'          => 'factura-emitida',
                'severity'      => 'info',
                'source_module' => 'facturacion',
                'recipient_id'  => $event->factura->partner->user_id,
                'channels'      => json_encode(['whatsapp', 'email']),
                'template_vars' => json_encode([
                    'invoice_number' => $event->factura->numero,
                    'amount'         => $event->factura->total,
                    'currency'       => $event->factura->moneda,
                    'partner_name'   => $event->factura->partner->nombre,
                ]),
            ]
        );
    }
}
```

```php
// config/database.php — conexión Redis para notifier
'redis' => [
    'notifier' => [
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD', null),
        'port'     => env('REDIS_PORT', 6379),
        'database' => 3,   // DB3 — notifier
    ],
],
```

---

## 7. Integración con Flutter desktop

`[AI-HINT]` Flutter se suscribe a ntfy por HTTP polling o WebSocket. Usa el paquete `http` o `web_socket_channel`. El topic es `{tenant}-{tipo}`. Para notificaciones desktop nativas en Linux/Windows/macOS, usa el paquete `local_notifications` combinado con ntfy como fuente.

```dart
// lib/services/bnotify_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BnotifyService {
  final String tenant;
  final String topic;
  final String baseUrl;

  BnotifyService({
    required this.tenant,
    required this.topic,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? 'https://$tenant.sksistemas.com/ntfy';

  /// Escucha notificaciones en tiempo real (streaming HTTP)
  Stream<Map<String, dynamic>> listen() async* {
    final url = Uri.parse('$baseUrl/$tenant-$topic/json');
    final client = http.Client();

    final request = http.Request('GET', url);
    final response = await client.send(request);

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final msg = json.decode(line) as Map<String, dynamic>;
          if (msg['event'] == 'message') yield msg;
        } catch (_) {}
      }
    }
  }

  /// Envía notificación (solo para servicios internos con JWT)
  Future<void> send({
    required String type,
    required String recipientId,
    required List<String> channels,
    required Map<String, dynamic> templateVars,
    required String ctxId,
    required String jwtToken,
  }) async {
    final sbosHost = 'https://$tenant.sksistemas.com';
    await http.post(
      Uri.parse('$sbosHost/notify'),
      headers: {
        'Content-Type':    'application/json',
        'Authorization':   'Bearer $jwtToken',
        'X-SBOS-CtxId':    ctxId,
      },
      body: json.encode({
        'type':          type,
        'recipient_id':  recipientId,
        'channels':      channels,
        'template_vars': templateVars,
      }),
    );
  }
}
```

```dart
// Uso en un widget Flutter — mostrar toast al recibir notificación
class _HomeState extends State<HomePage> {
  late BnotifyService _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = BnotifyService(
      tenant: 'acme',
      topic:  'task-reminders',
    );
    _listenForNotifications();
  }

  void _listenForNotifications() {
    _notifier.listen().listen((msg) {
      // Mostrar notificación nativa del sistema operativo
      showDesktopNotification(
        title:   msg['title'] ?? 'SBOS',
        message: msg['message'] ?? '',
      );
    });
  }
}
```

---

## 8. Integración CLI / terminal

`[AI-HINT]` Para CLI usa `bosctl notify subscribe` o directamente `ntfy subscribe`. La URL del topic siempre es `http://localhost:28204/{tenant}-{topic}` desde dentro del cluster, o la URL pública desde fuera.

```bash
# ── Suscribirse a alertas en tiempo real (permanece escuchando) ──

# Opción 1: bosctl (wrapper SBOS)
bosctl notify subscribe --tenant=acme --topic=admin-alerts

# Opción 2: ntfy CLI nativo
ntfy subscribe http://localhost:28204/acme-admin-alerts

# Opción 3: curl streaming (sin instalar nada)
curl -s "http://localhost:28204/acme-admin-alerts/json" | \
  while IFS= read -r line; do
    echo "$line" | python3 -m json.tool | grep -E '"message"|"title"|"priority"'
  done


# ── Enviar notificación desde script bash ──

# Alerta crítica al admin
curl -d "ERROR: Backup fallido en S03 — disco al 95%" \
  -H "Title: [CRITICAL] Backup S03" \
  -H "Priority: urgent" \
  -H "Tags: rotating_light" \
  -H "X-SBOS-CtxId: ctx-backup-$(date +%s)" \
  http://localhost:28204/acme-admin-alerts

# Aviso informativo
curl -d "Importación completada: 4,821 registros procesados" \
  -H "Title: [INFO] Importación batch" \
  -H "Priority: default" \
  http://localhost:28204/acme-cli-alerts

# Alerta con acción (abre URL al hacer clic)
curl -d "Nueva solicitud de aprobación pendiente" \
  -H "Title: Aprobación requerida" \
  -H "Actions: view, Abrir bCompass, https://acme.sksistemas.com/compass/tasks" \
  http://localhost:28204/acme-task-reminders


# ── Topics disponibles por tenant ──
# {tenant}-admin-alerts     Alertas críticas del sistema → Administradores
# {tenant}-client-notify    Notificaciones para clientes finales
# {tenant}-mfa-push         Push MFA (uso interno de bnotify — no publicar)
# {tenant}-cli-alerts       Alertas de scripts y cronjobs
# {tenant}-task-reminders   Recordatorios de tareas (bCompass)
```

---

## 9. Configurar canales de un usuario

`[AI-HINT]` Antes de que un usuario reciba notificaciones, debes registrar su canal en `notification_channels`. Esto se hace una sola vez (al registrar el usuario o desde el panel de preferencias).

```http
# Registrar Telegram de un usuario
POST /notify/channels
Authorization: Bearer {jwt_admin_o_servicio}
Content-Type: application/json

{
  "user_id": "usr_456",
  "channel": "telegram",
  "address": "987654321"
}

# Registrar WhatsApp
POST /notify/channels
{
  "user_id": "usr_456",
  "channel": "whatsapp",
  "address": "+59171234567"
}

# Registrar Email
POST /notify/channels
{
  "user_id": "usr_456",
  "channel": "email",
  "address": "juan.perez@empresa.com"
}

# Listar canales de un usuario
GET /notify/channels?user_id=usr_456
Authorization: Bearer {jwt_admin}

# Respuesta:
{
  "user_id": "usr_456",
  "channels": [
    { "channel": "telegram", "address": "987654321",      "active": true },
    { "channel": "email",    "address": "juan@emp.com",   "active": true },
    { "channel": "whatsapp", "address": "+59171234567",   "active": true }
  ]
}
```

```sql
-- También directo en PostgreSQL (desde migraciones o seeds)
INSERT INTO notification_channels (tenant, user_id, channel, address)
VALUES
  ('acme', 'usr_456', 'telegram', '987654321'),
  ('acme', 'usr_456', 'email',    'juan@empresa.com'),
  ('acme', 'usr_456', 'whatsapp', '+59171234567')
ON CONFLICT (tenant, user_id, channel) DO UPDATE
  SET address = EXCLUDED.address, active = TRUE;
```

---

## 10. Templates de mensajes

`[AI-HINT]` Los templates usan `{{variable}}` como placeholders. Se resuelven en la caja biedata con los `template_vars` del payload del stream. Siempre usa `ON CONFLICT DO NOTHING` al insertar templates para no pisar personalizaciones del tenant.

```sql
-- Ver templates disponibles
SELECT type, channel, lang, subject, body
FROM notification_templates
WHERE tenant = 'acme'
ORDER BY type, channel;

-- Crear o actualizar un template personalizado
INSERT INTO notification_templates
  (tenant, type, channel, lang, subject, body)
VALUES (
  'acme',
  'factura-emitida',
  'whatsapp',
  'es',
  NULL,
  '📄 *Estimado {{partner_name}}*
Su factura *{{invoice_number}}* por *{{amount}} {{currency}}* ha sido emitida.
Puede descargarla en: {{download_url}}
Gracias por su preferencia.'
)
ON CONFLICT (tenant, type, channel, lang)
DO UPDATE SET body = EXCLUDED.body;
```

**Variables disponibles por tipo de evento:**

| Tipo | Variables |
|------|-----------|
| `factura-emitida` | `invoice_number`, `amount`, `currency`, `partner_name`, `download_url` |
| `error-critico` | `message`, `source_module`, `ctx_id`, `severity` |
| `tarea-pendiente` | `title`, `due_date`, `assigned_to`, `task_url` |
| `mfa-push` | `geo`, `device_info`, `created_at`, `expires_at` |
| `alerta-sistema` | `severity`, `source_module`, `message`, `server` |
| `validacion-fallida` | `module`, `line`, `field`, `value`, `reason` |

---

## 11. Reglas bKernel — notificaciones automáticas

`[AI-HINT]` Las reglas bKernel se declaran en el `manifest.yml` de bnotify (sección `bkernel_rules`). bos las registra en bKernel al instalar la ficha. Para agregar una nueva regla, edita el manifest y ejecuta `bosctl ficha upgrade sbos-notifier`.

```yaml
# Agregar una regla nueva en manifest.yml → bkernel_rules:
- id:      "pago-recibido"
  table:   "tryton_db.account_payment"
  event:   "UPDATE"
  filter:  "state = 'succeeded'"
  action:  "publish_stream"
  stream:  "biedata:notify:{tenant}"
  payload: "payment_id, partner_id, amount, currency, date"
```

```bash
# Aplicar la nueva regla
bosctl ficha upgrade sbos-notifier --tenant=acme

# Verificar reglas activas
bosctl bkernel rules list --filter=sbos-notifier --tenant=acme
```

---

## 12. Operación y monitoreo

```bash
# ── Estado general ──
bosctl ficha task sbos-notifier status --tenant=acme

# ── Logs en tiempo real (con ctx_id estructurado) ──
kubectl logs -n sbos-acme -l app=sbos-notifier -f | \
  jq 'select(.level=="error") | {time, msg, ctx_id, channel, error}'

# ── Métricas Prometheus ──
curl http://localhost:28202/metrics | grep sbos_notifier

# Métricas clave:
#   sbos_notifier_sent_total{channel,tenant}
#   sbos_notifier_failed_total{channel,tenant,error}
#   sbos_notifier_mfa_challenges_total{status,tenant}
#   sbos_notifier_queue_depth{stream,tenant}
#   sbos_notifier_latency_ms{channel,tenant}

# ── Consultas operativas en PostgreSQL ──

-- Notificaciones fallidas últimas 24h
SELECT type, channel, error_msg, COUNT(*) as total, MAX(created_at) as last_seen
FROM notification_events
WHERE tenant='acme' AND status='failed' AND created_at > NOW() - INTERVAL '24h'
GROUP BY type, channel, error_msg
ORDER BY total DESC;

-- MFA challenges sin resolver (posible ataque o problema)
SELECT user_id, geo, device_info, expires_at, created_at
FROM mfa_challenges
WHERE tenant='acme' AND status='pending' AND expires_at < NOW()
ORDER BY created_at DESC LIMIT 20;

-- Volumen por canal últimos 7 días
SELECT channel, DATE(created_at) as dia, COUNT(*) as enviados,
       SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END) as fallidos
FROM notification_events
WHERE tenant='acme' AND created_at > NOW() - INTERVAL '7 days'
GROUP BY channel, dia
ORDER BY dia DESC, enviados DESC;
```

---

## 13. Referencia de la API HTTP

| Método | Ruta | Descripción | Auth |
|--------|------|-------------|------|
| `POST` | `/notify` | Enviar notificación | JWT servicio |
| `GET`  | `/notify/events` | Listar eventos del tenant | JWT admin |
| `POST` | `/notify/channels` | Registrar canal de usuario | JWT admin |
| `GET`  | `/notify/channels` | Listar canales de usuario | JWT admin |
| `DELETE` | `/notify/channels/{id}` | Desactivar canal | JWT admin |
| `GET`  | `/notify/templates` | Listar templates | JWT admin |
| `POST` | `/notify/templates` | Crear/actualizar template | JWT admin |
| `POST` | `/api/mfa/confirm/{token}` | Confirmar/denegar challenge MFA | Token JWT one-shot |
| `GET`  | `/health` | Health check K8s | Sin auth |
| `GET`  | `/ready` | Readiness check K8s | Sin auth |
| `GET`  | `/metrics` | Métricas Prometheus | Sin auth (red interna) |

---

## 14. Referencia del Redis Stream

`[AI-HINT]` Todos los campos del stream son strings. Los arrays y objetos van como JSON serializado en string. El campo `ctx_id` es **obligatorio** en todos los mensajes — sin él el mensaje es rechazado.

| Stream | Producer | Consumer | Uso |
|--------|----------|----------|-----|
| `biedata:notify:{tenant}` | bKernel, apps SBOS | biedata caja notify-external | Notificaciones generales |
| `biedata:notify:cli:{tenant}` | bKernel, scripts | biedata caja notify-cli | Alertas CLI y terminal |
| `mfa:challenges:{tenant}` | bKernel (via WAL) | biedata caja mfa-push | Push MFA |
| `notify:sent:{tenant}` | bnotify | Consumidores auditoria | Confirmaciones de envío |

**Campos obligatorios en todos los streams:**

```
ctx_id        string   ID de contexto SBOS — obligatorio
type          string   Tipo de notificación (factura-emitida, error-critico, etc.)
severity      string   info | warning | critical
source_module string   Módulo que origina el evento
recipient_id  string   user_id del destinatario en SBOS
channels      string   JSON array: ["telegram","email"]
template_vars string   JSON object con las variables del template
```

---

## 15. Checklist de integración

`[AI-HINT]` Usa esta lista para verificar una integración nueva antes de hacer merge. Cada ítem debe ser `true` para que la integración sea válida en SBOS.

```
□ El módulo publica en el Redis Stream — nunca llama a Telegram/Twilio/SMTP directamente
□ El campo ctx_id está presente en todos los mensajes publicados
□ El canal del destinatario está registrado en notification_channels antes del primer envío
□ Los tokens de Telegram/Twilio/SMTP están en Vault — no en .env ni en código
□ Si el módulo envía por HTTP API, usa el header X-SBOS-CtxId
□ Las reglas bKernel nuevas están declaradas en manifest.yml → bkernel_rules
□ Los templates personalizados usan ON CONFLICT DO NOTHING
□ Para Push MFA: el SPI inserta en mfa_challenges — NO publica en Redis directamente
□ Los tests del módulo incluyen mock del Redis Stream (no deben enviar notificaciones reales en CI)
□ El log del módulo incluye el event_id retornado por bnotify para trazabilidad
```

---

## 16. Errores comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `ctx_id missing` | Publicación sin ctx_id | Agregar campo ctx_id al XADD |
| `channel not found for user` | Usuario sin canal registrado | POST /notify/channels antes del primer envío |
| `template not found` | Tipo de evento sin template | Insertar template en notification_templates |
| `mfa challenge expired` | El usuario tardó más de 60s | El TTL es de 60s — Keycloak muestra "sesión expirada" |
| `vault secret not found` | Token de Telegram/Twilio no en Vault | `vault kv put secret/tenants/{tenant}/sbos-notifier/telegram-bot-token value=...` |
| `ntfy: topic not found` | Topic no creado en instalación | Ejecutar `bosctl ficha task sbos-notifier repair` |
| `stream consumer lag` | Backlog en Redis Stream | Escalar réplicas de biedata o revisar conectividad externa |

---

*bnotify · SBOS Notify · v1.0.0 · SKULL · Mayo 2026*
*Licencia Apache-2.0 · ntfy (Apache-2.0 / GPLv2) · Apprise (MIT)*
