# A.78 — Sagas del Motor de Comunicación

**Versión:** 1.1.0  
**Fecha:** 2026-08-05  
**Manual padre:** [2.18 — Motor de Comunicación](../2.18_MANUAL-MOTOR-COMUNICACION-v1.0.md)  
**Patrón de referencia:** Saga pattern (Richardson) · BOS IAM Installer (1.02) · Branch by Abstraction (Hammant)  
**Aplicable a:** Todo cliente banexus-implicit — TypeScript/React/Vue, PHP/Laravel, Dart/Flutter, Rust M2M, Python/Django (agnóstico de lenguaje y framework — ver [2.18](../2.18_MANUAL-MOTOR-COMUNICACION-v1.0.md) §4 para implementaciones completas por lenguaje)  

---

## 0. Principio

Una **saga** es una secuencia de pasos con compensación: si cualquier paso falla, el sistema
ejecuta los pasos de compensación en orden inverso para dejar el sistema en un estado limpio.

Patrón aplicado aquí: **coreografía local** — cada saga vive en el cliente y es orquestada
por el Motor de Comunicación. No requiere coordinador externo.

Cada saga tiene:
- Precondiciones (estado que debe existir antes de iniciar)
- Pasos ordenados con criterio de éxito
- Compensación por paso (qué hacer si falla)
- Postcondición (estado garantizado al terminar)

---

## 1. Saga S-01: Conexión inicial

**Precondición:** cliente sin canal activo  
**Postcondición:** canal WebSocket abierto + token válido en secure storage  

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAGA S-01: CONEXIÓN INICIAL                                        ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1: ¿hay token en   │  token presente y     │  —                   ║
║  secure storage?     │  exp > now + 5min     │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1-ALT: no hay      │  usuario ingresa      │  —                   ║
║  token → ejecutar    │  credenciales         │                      ║
║  Sub-saga S-01a      │                       │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P2: TCP handshake   │  conexión TCP OK      │  esperar 2s;         ║
║  con daemon          │  en < 3s              │  reintentar P2       ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P3: HTTP Upgrade    │  101 Switching        │  si 401 → P1-ALT;   ║
║  + JWT en header     │  Protocols            │  si 503 → backoff;   ║
║                      │                       │  si 403 → ABORT      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P4: verificar       │  {"status":           │  cerrar canal →      ║
║  canal activo        │  "operativo"}         │  volver a P2         ║
║  bauth.health.check  │  en < 5s              │                      ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

POSTCONDICIÓN EXITOSA:
  - Canal WebSocket abierto
  - Token en secure storage con exp > now + 5min
  - EstadoConexion.conectado emitido a UI

ABORT DEFINITIVO (sin reintento):
  - 403 Forbidden → usuario no tiene scope 'dashboard' → mostrar error
  - 3+ fallos en P4 → daemon inestable → mostrar error de sistema
```

### Sub-saga S-01a: Login user+password

```
╔══════════════════════════════════════════════════════════════════════╗
║  SUB-SAGA S-01a: LOGIN USER+PASSWORD                                ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1: abrir canal     │  101 Switching        │  backoff → reintentar║
║  SIN Authorization   │  Protocols            │  (dev local solo)    ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P2: enviar          │  result.token         │  si error -32001     ║
║  bauth.session.login │  presente y válido    │  → credenciales      ║
║  {usuario, password} │                       │  incorrectas         ║
║                      │                       │  → mostrar error UI  ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P3: persistir JWT   │  secure_storage.read  │  cerrar canal →      ║
║  en secure storage   │  retorna el JWT       │  S-01a completamente ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

NOTA CRÍTICA:
  En Capa 1 (desarrollo), el canal inicial se abre sin JWT solo para
  ejecutar S-01a. Después de obtener el JWT, se cierra ese canal y se
  abre uno nuevo con Authorization: Bearer <jwt>.
  El daemon NUNCA ejecuta métodos privilegiados sin JWT válido.
```

---

## 2. Saga S-02: Reconexión automática

**Precondición:** EstadoConexion.desconectado detectado por el WsTransportAdapter  
**Postcondición:** canal reabierto con el mismo JWT (o renovado si por expirar)  

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAGA S-02: RECONEXIÓN AUTOMÁTICA                                   ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1: emitir          │  UI muestra banner    │  —                   ║
║  reconectando        │  "Reconectando..."    │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P2: backoff         │  espera completada    │  —                   ║
║  exponencial         │                       │                      ║
║  intento N → 2^N s   │  máx 60s              │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P3: ¿token vigente  │  exp > now + 5min     │  si no → Saga S-03  ║
║  en secure storage?  │                       │  (renovación) primero║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P4: ejecutar        │  canal abierto +      │  volver a P2         ║
║  Saga S-01 (P2-P4)   │  health OK            │  con backoff mayor   ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

TABLA DE BACKOFF:
  Intento 1: esperar 2s
  Intento 2: esperar 4s
  Intento 3: esperar 8s
  Intento 4: esperar 16s
  Intento 5: esperar 32s
  Intento 6+: esperar 60s (máximo)
  Intento 10: ABORT → ejecutar Saga S-04 (revocación de sesión)

POSTCONDICIÓN EXITOSA:
  - EstadoConexion.conectado emitido
  - Banner "Reconectando" desaparece
  - Requests encolados durante reconexión se envían

ABORT (tras 10 intentos fallidos):
  - Ejecutar Saga S-04 (invalidar sesión local)
  - Mostrar pantalla de login
  - Mensaje: "La conexión con el servidor no pudo restablecerse"
```

---

## 3. Saga S-03: Renovación de token

**Precondición:** token próximo a expirar (exp < now + 5min)  
**Postcondición:** nuevo token en secure storage, canal reconectado con él  

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAGA S-03: RENOVACIÓN DE TOKEN                                     ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1: detectar        │  exp < now + 300s     │  —                   ║
║  proximidad a        │  (5 minutos)          │  (IRepositorioTokens ║
║  expiración          │                       │   verifica siempre   ║
║  (pre-flight check)  │                       │   antes de llamar)   ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P2: enviar          │  result.token         │  si error → ejecutar ║
║  bauth.session       │  presente             │  Saga S-04 (forzar   ║
║  .refresh            │                       │  login nuevamente)   ║
║  {refresh_token}     │                       │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P3: persistir       │  secure_storage OK    │  si falla → S-04     ║
║  nuevo JWT           │                       │                      ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P4: reabrir canal   │  nuevo canal abierto  │  si falla → S-02     ║
║  con nuevo JWT       │  con nuevo JWT        │  (reconexión)        ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

NOTA: S-03 es transparente para la UI — el usuario no ve nada.
El canal anterior se cierra de forma limpia (código 1000 Normal Closure)
antes de abrir el nuevo.

RELACIÓN CON CAPAS:
  - Capas 1-3: refresh_token se emite en bauth.session.login
               (H-06 — decisión HITL pendiente)
  - Capa 4: refresh_token se obtiene via OIDC (OidcTokenProvider)
```

---

## 4. Saga S-04: Revocación de sesión (logout)

**Precondición:** usuario solicita logout O canal muere tras 10 intentos O token revocado por CAEP  
**Postcondición:** sesión completamente invalidada local y remotamente  

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAGA S-04: REVOCACIÓN DE SESIÓN                                    ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1: leer jti        │  jti extraído del     │  si no hay token:    ║
║  del JWT local       │  payload del JWT      │  saltar a P3 directo ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P2: enviar          │  result.ok: true      │  si falla (sin red): ║
║  bauth.session       │                       │  continuar P3 igual  ║
║  .logout {jti}       │                       │  (limpiar local de   ║
║                      │                       │  todas formas)       ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P3: limpiar         │  secure_storage       │  si falla secure_    ║
║  secure storage      │  vacío                │  storage: loguear    ║
║  (tokens + ctx_id)   │                       │  error; continuar    ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P4: cerrar canal    │  canal cerrado con    │  forzar close() si   ║
║  WebSocket           │  código 1000          │  close() tarda > 3s  ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P5: navegar a       │  pantalla de login    │  —                   ║
║  pantalla de login   │  visible              │                      ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

GARANTÍA CLAVE: P3 (limpiar local) siempre se ejecuta incluso si
P2 (logout remoto) falla. El cliente queda limpio sin importar el
estado del servidor.

TIMEOUT DEL TOKEN EN SERVIDOR: si el logout remoto no llega (sin red),
el daemon expirará el JWT cuando caduque (máximo TTL configurado, H-03).
El jti queda en lista negra de todas formas al llegar el logout diferido
una vez recuperada la conectividad (offline-queue opcional, Capa futura).
```

---

## 5. Saga S-05: Heartbeat y detección de canal zombie

**Precondición:** canal abierto en estado aparente de conectado  
**Postcondición:** canal sigue abierto (confirmado) o Saga S-02 iniciada  

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAGA S-05: HEARTBEAT                                               ║
╠══════════════════════╤═══════════════════════╤══════════════════════╣
║  PASO                │  CRITERIO DE ÉXITO    │  COMPENSACIÓN        ║
╠══════════════════════╪═══════════════════════╪══════════════════════╣
║  P1 (periódico)      │  PONG recibido en     │  si no PONG en 10s:  ║
║  enviar PING         │  < 10s                │  ejecutar S-02       ║
║  cada 25s            │  (RFC 6455 §5.5.3)    │  (reconexión)        ║
╚══════════════════════╧═══════════════════════╧══════════════════════╝

IMPLEMENTACIÓN DE REFERENCIA — Dart/Flutter (una de cinco — ver 2.18 §4 para las otras):
  Timer.periodic(const Duration(seconds: 25), (_) {
    if (_canal != null && _canal!.closeCode == null) {
      _canal!.sink.add('{"jsonrpc":"2.0","method":"__ping","id":null}');
      // El daemon responde con PONG de RFC 6455 (nivel frame) automáticamente.
    }
  });
  // TypeScript: setInterval(() => ws.send(JSON.stringify({jsonrpc:'2.0',method:'__ping',id:null})), 25_000);
  // PHP: $ws->send(json_encode(['jsonrpc'=>'2.0','method'=>'__ping','id'=>null])); // en bucle 25s
  // Rust: tokio::time::interval → sink.send(Message::Ping(vec![])).await
  // Python: await ws.ping(); await asyncio.sleep(25)

NOTA: el daemon bAuth envía PINGs cada 30s (ADR-020). S-05 envía PINGs
cada 25s del lado cliente como detección proactiva independiente.
```

---

## 6. Máquina de estados del cliente

```
                    ┌──────────────────────────────────────────────────────┐
                    │              ESTADOS DEL CLIENTE                     │
                    └──────────────────────────────────────────────────────┘

              inicialización
                    │
                    ▼
              ┌──────────┐
         ┌──► │DESCONECT.│ ◄─────────────────────────── logout / S-04
         │    └────┬─────┘
         │         │ S-01 iniciada
         │         ▼
         │    ┌───────────┐
         │    │CONECTANDO │
         │    └─────┬─────┘
         │          │ 101 Switching Protocols
         │          ▼
         │    ┌───────────┐ ─── S-05 heartbeat ok ──► ┌───────────┐
         │    │ CONECTADO │ ◄─────────────────────────  │ CONECTADO │
         │    └─────┬─────┘
         │          │ canal cae (cierre inesperado)
         │          ▼
         │    ┌─────────────┐
         └─── │RECONECTANDO │ ─── 10 intentos fallidos ──► S-04 → DESCONECT.
              └─────────────┘
                    ▲
                    │ S-03 renovación → S-02 reconexión
                    └──────────────────────────────────
```

---

## 7. Implementación de referencia en Dart/Flutter

> Este §7 muestra la implementación para Dart/Flutter (`MotorComunicacion` + Riverpod).  
> Implementaciones equivalentes para TypeScript, PHP/Laravel, Rust M2M y Python/Django están  
> documentadas en **[2.18 §4](../2.18_MANUAL-MOTOR-COMUNICACION-v1.0.md)** — el patrón de sagas  
> (S-01 a S-05) es idéntico en todos los lenguajes; solo cambia la librería WebSocket.

```dart
// nucleo/comunicacion/motor_comunicacion.dart
// Orquesta las 5 sagas. Inyectado en los ViewModels via Riverpod.
class MotorComunicacion {
  final ITransportClient _cliente;
  final IRepositorioTokens _tokens;
  Timer? _heartbeatTimer;

  /// Inicializa el motor: saga S-01.
  Future<void> iniciar(ParametrosConexion params) async {
    await _ejecutarSagaConexion(params);
    _iniciarHeartbeat();
  }

  Future<void> _ejecutarSagaConexion(ParametrosConexion p) async {
    int intentos = 0;
    while (intentos < 10) {
      try {
        await _cliente.conectar(p);
        return; // S-01 exitosa
      } on SocketException {
        intentos++;
        final espera = Duration(seconds: _backoffSegundos(intentos));
        await Future.delayed(espera);
      } on Unauthorized catch (_) {
        // JWT inválido → renovar → reintentar
        await _tokens.invalidar('');
        await _ejecutarLogin();
      }
    }
    throw ComunicacionException('No se pudo conectar tras 10 intentos');
  }

  int _backoffSegundos(int intento) => min(pow(2, intento).toInt(), 60);

  void _iniciarHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!_cliente.estaConectado) {
        await _ejecutarSagaConexion(_params!);
      }
    });
  }

  Future<void> cerrarSesion() async {
    // Saga S-04
    _heartbeatTimer?.cancel();
    try {
      final jwt = await _tokens.tokenValido();
      final jti = _extraerJti(jwt);
      await _cliente.llamar('bauth.session.logout', {'jti': jti});
    } catch (_) { /* ignorar si sin red */ }
    await _tokens.invalidar('');
    _cliente.desconectar();
  }
}
```

---

## Changelog

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.1.0 | 2026-08-05 | Aplicable-a actualizado: banexus-implicit multi-lenguaje (TS/PHP/Dart/Rust/Python); §5 heartbeat añade ejemplos en los 4 lenguajes restantes; §7 título clarifica que Dart es una de las 5 implementaciones de referencia (2.18 §4) |
| 1.0.0 | 2026-08-04 | Versión inicial — S-01 conexión + S-01a login, S-02 reconexión, S-03 renovación, S-04 revocación, S-05 heartbeat, máquina de estados, implementación Dart |
