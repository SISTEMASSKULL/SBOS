---
codigo: BNOTIFY-033
version: 1.0.0
estado: BORRADOR
gate: G2
depende_de: [BNOTIFY-030]
doctrina_que_ejerce: [D1, D6, D14]
criterio_implementado: >
  La app Flutter compila para Android e iOS sin errores (flutter build apk, flutter build ios).
  El flujo login OIDC bAuth → sala de chat → envío de mensaje funciona en un dispositivo
  físico Android. Los mensajes aparecen en ambos dispositivos de un mismo usuario (multi-device).
  Los badges de notificación se actualizan en tiempo real. Verificado manualmente en
  dispositivo físico (no emulador) por el Testeador.
---

# BNOTIFY-033 — bChat Cliente Flutter
## Un código base — Android, iOS, desktop y web — Material 3 + notify integrado

**Versión:** 1.0.0 · **Gate:** G2 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §B.0, §B.2, Anexo A · BNOTIFY-030 (protocolo WS+JSON-RPC)

---

## 1. Principios del cliente

- **Un código base, todas las plataformas:** Flutter 3.27.x — Android, iOS, desktop (Linux/macOS/Windows), web
- **Material 3** con design tokens propios (paleta, tipografía, espaciados inspirados en Fuselage de RC pero propios)
- **WebSocket persistente:** una sola conexión por dispositivo — el mismo protocolo en todas las plataformas (ADR-002)
- **Notify integrado estilo WhatsApp:** badges, notificaciones push, respuesta desde la notificación, canales por conversación
- **Negociación de capacidades al conectar** (patrón BNOTIFY-000 §B.0.1): la UI se construye según las features habilitadas

---

## 2. Estructura de paquetes Dart

```
bchat-flutter/
├── lib/
│   ├── main.dart                   # Entry point — inicialización, router, theme
│   ├── app/
│   │   ├── router.dart             # go_router: rutas y guards de autenticación
│   │   └── theme.dart              # Material 3 ThemeData con tokens propios
│   ├── auth/
│   │   ├── oidc_service.dart       # Login OIDC bAuth (flutter_appauth)
│   │   └── token_storage.dart      # JWT + refresh token en flutter_secure_storage
│   ├── chat/
│   │   ├── ws_client.dart          # WebSocket + JSON-RPC 2.0 (web_socket_channel)
│   │   ├── sync_manager.dart       # Cursor de sync, cola offline local, gap detection
│   │   ├── message_repository.dart # Cache local sqlite3 de mensajes
│   │   └── presence_service.dart   # Estado de presencia propio y de contactos
│   ├── rooms/
│   │   ├── room_list_screen.dart   # Lista de salas con badges de mensajes no leídos
│   │   └── room_screen.dart        # Vista de mensajes + campo de escritura
│   ├── notifications/
│   │   ├── push_service.dart       # FCM/APNs — registro de token en bNotify
│   │   └── local_notifications.dart # flutter_local_notifications (badges, heads-up)
│   └── media/
│       ├── picker.dart             # Selección de imagen/video/archivo
│       └── upload_service.dart     # Upload a S3 vía URL pre-firmada
└── pubspec.yaml
```

---

## 3. Dependencias Dart (pubspec.yaml)

```yaml
dependencies:
  flutter: { sdk: flutter }

  # WebSocket + JSON-RPC
  web_socket_channel: ^3.0.0

  # Autenticación OIDC
  flutter_appauth: ^7.0.0         # PKCE OIDC — soporta bAuth como IdP custom

  # Almacenamiento seguro
  flutter_secure_storage: ^9.2.0  # JWT + refresh token

  # Cache local mensajes
  sqflite: ^2.4.0                 # SQLite local (Android/iOS/desktop)
  drift: ^2.20.0                  # ORM sobre SQLite

  # Push
  firebase_messaging: ^15.0.0    # FCM (requiere google-services.json en Android)
  flutter_local_notifications: ^18.0.0

  # Video/voz LiveKit (G3+)
  livekit_client: ^2.3.0         # SDK LiveKit Flutter oficial

  # UI
  go_router: ^14.0.0
  riverpod: ^2.6.0               # State management

dev_dependencies:
  flutter_test: { sdk: flutter }
  build_runner: ^2.4.0
  riverpod_generator: ^2.6.0
```

---

## 4. Flujo de autenticación OIDC

```dart
// auth/oidc_service.dart
class OidcService {
  static const _discoveryUrl =
      'https://bauth.sbos.internal/.well-known/openid-configuration';

  Future<AuthTokens> login() async {
    final result = await FlutterAppAuth().authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        'rocketchat-${tenantId}',  // En bChat: 'bchat-${tenantId}'
        'bchat://auth/callback',
        discoveryUrl: _discoveryUrl,
        scopes: ['openid', 'profile', 'email', 'sbos_roles'],
        preferEphemeralSession: false,
      ),
    );
    return AuthTokens(
      accessToken: result.accessToken!,
      idToken: result.idToken!,
      refreshToken: result.refreshToken!,
    );
  }
}
```

---

## 5. Conexión WebSocket y sincronización

```dart
// chat/ws_client.dart
class BchatWsClient {
  late final WebSocketChannel _channel;
  final SyncManager _sync;

  Future<ConnectResult> connect(String accessToken) async {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://bchat.${tenantId}.sbos.app/ws'),
    );
    final result = await _rpc('bchat.connect', {
      'access_token': accessToken,
      'device_id': await deviceId(),
      'client_version': appVersion,
      'capabilities': ['messages', 'presence', 'rooms', 'push_tokens'],
    });
    await _sync.syncFromCursor(result['sync_cursor']);
    return ConnectResult.fromJson(result);
  }

  // Reintento exponencial en desconexión (1s, 2s, 4s, 8s, max 60s)
  void _handleDisconnect() => _reconnectWithBackoff();
}
```

---

## 6. Notify integrado — badges y push

```dart
// notifications/push_service.dart
class PushService {
  Future<void> registerDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      // Registrar token en bNotify via JSON-RPC
      await _wsClient.rpc('bchat.push.register', {
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'provider': 'fcm',
        'token': token,
      });
    }
    // Para Android sin Google Services: UnifiedPush (ntfy)
    // Ver UnifiedPush Flutter plugin
  }
}
```

**Comportamiento de notificaciones:**
- App en primer plano: Notification JSON-RPC por WS → `flutter_local_notifications` in-app banner
- App en background: push FCM/APNs → heads-up notification con texto del mensaje
- App cerrada: push FCM/APNs → notificación en la barra, badge en el ícono

---

## 7. Decisiones de diseño de UI

| Elemento | Decisión |
|----------|---------|
| Lista de salas | Material 3 `ListTile` con badge de no leídos. Sin tabs complejos |
| Vista de mensajes | `CustomScrollView` + `SliverList` con lazy loading (cargar hacia arriba) |
| Campo de escritura | `TextField` con acciones para adjuntar media, emoji, voice note |
| Presencia | Dot de color en el avatar: verde (online), amarillo (away), gris (offline) |
| Media | Preview inline de imágenes; video/audio con player nativo |
| Tema | Material 3 con dark/light automático según el sistema |

---

*BNOTIFY-033 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Un código base. No hay "la app Android" y "la app iOS" — hay una app. La complejidad vive en el motor, no en el cliente.*
