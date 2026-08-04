# A.64.02 — Proyecto: Comunicación Segura Desktop ↔ bAuth

**Versión:** 5.0.0  
**Fecha:** 2026-08-04  
**Estado:** ACTIVO — PROPUESTA TÉCNICA  
**Extensión de:** [A.64 — Guía de Desarrollo Desktop](A.64_ANEXO-MAQUETAS-DESKTOP-v1.0.md)  
**Relacionado:** [A.64.01 — Inventario de Códigos Desktop](A.64.01_INVENTARIO-CODIGOS-DESKTOP-v1.0.md)

> ⚠️ **TAREA BLOQUEANTE:** El desarrollo del dashboard desktop está bloqueado hasta que las
> Capas 0-2 del **Motor de Comunicación (2.18)** estén implementadas y verifiquen sus gates.
> Este anexo es la aplicación desktop específica de ese motor.
> **Fuente de verdad del protocolo, adaptadores y sagas:** [2.18_MANUAL-MOTOR-COMUNICACION](../2.18_MANUAL-MOTOR-COMUNICACION-v1.0.md)  
> **Protocolo wire:** [A.77](A.77_PROTOCOLO-WS-JSONRPC-v1.0.md) · **Sagas:** [A.78](A.78_SAGAS-MOTOR-COMUNICACION-v1.0.md)

---

## Resumen ejecutivo

El dashboard desktop de bAuth (`src/desktop/`) está conectado hoy mediante SSH+root+password
y consulta la base de datos directamente con `psql` desde el cliente Dart. Esto viola
varios principios de seguridad del ecosistema SBOS (SBOS-050, ADR-020, ISO 27001, NIST 800-63B).

Este documento define el proyecto de migración a una arquitectura correcta:
**WebSocket Seguro (WSS) + Kong + JWT**, donde bAuth es el único que toca la base de datos
y el cliente Flutter solo habla JSON-RPC 2.0 con el daemon.

**v2.0.0 — Estrategia aditiva:** se corrige el antipatrón "Phased Big Bang". `ITransportClient`
como contrato permanente. Cada capa añade sin destruir la anterior.

**v3.0.0 — Sin átomos en Capas 1-4:** los átomos los genera `roles_template` — no existen aún.
Las primeras capas solo verifican el método de autenticación. JWT mínimo sin `rol_bitmask`.

**v4.0.0 — SSH fuera del path de comunicación:** SSH es administración de sistemas, no protocolo
de aplicación. Ningún daemon de producción real (Docker, Vault, Tailscale, 1Password) usa SSH
como transporte de datos. WebSocket desde la Capa 1 — `dartssh2` eliminado del primer día.

**v5.0.0 — Motor de Comunicación (2.18) como fuente de verdad:** la arquitectura de cliente-servidor
definida en este documento es **reutilizable para todos los clientes** (desktop, web, mobile, CLI,
daemons hermanos), no solo para el desktop. El Manual 2.18 es la especificación canónica. Este
documento (A.64.02) es la **aplicación desktop específica** del motor — contiene el diagnóstico,
el plan por capas adaptado al desktop, y los gates de avance.

---

## Tabla de contenidos

1. [§1 Diagnóstico — Estado actual y sus aberraciones](#1-diagnóstico)
2. [§2 Arquitectura objetivo](#2-arquitectura-objetivo)
3. [§3 Autenticación usuario+contraseña — análisis de pertinencia](#3-autenticación-usuariocontraseña)
4. [§4 Autorización mediante átomos bAuth](#4-autorización-mediante-átomos-bauth)
5. [§5 Plan de implementación (4 fases)](#5-plan-de-implementación)
6. [§6 API JSON-RPC necesaria en el daemon](#6-api-json-rpc-necesaria)
7. [§7 Cambios en el cliente Flutter](#7-cambios-en-el-cliente-flutter)
8. [§8 Seguridad del canal y cifrado](#8-seguridad-del-canal)
9. [§9 Decisiones HITL pendientes](#9-decisiones-hitl-pendientes)
10. [§10 Registro de cambios](#10-changelog)

---

## §1 Diagnóstico

### 1.1 Situación actual (aberraciones detectadas)

El dashboard desktop conecta hoy de la siguiente forma:

```
[Flutter Desktop]
    ↓ SSH TCP port 22 (dartssh2)
    ↓ user: root, password: hardcodeado en config_conexion.dart
[VPS bAuth]
    ↓ socat - UNIX-CONNECT:/run/bos/bauth.sock   ← correcto (canal persistente JSON-RPC)
[bauth daemon] ← llega el JSON-RPC aquí ✓

    ↓ PERO TAMBIÉN:
[Flutter Desktop]
    ↓ SSH exec session (ejecutarCmd)
    ↓ echo <SQL_base64> | base64 -d | psql 'postgres://postgres:postgres@localhost:15432/SBOSDB'
[SBOSDB] ← el cliente Dart accede directamente a la BD sin pasar por bAuth ✗
```

#### Aberraciones catalogadas

| ID | Aberración | Norma violada | Impacto |
|----|-----------|---------------|---------|
| AB-01 | `root` como usuario de conexión | NIST 800-53 AC-6 (least privilege) | Compromiso total del host si el token SSH es robado |
| AB-02 | Password `12345678ubuntu` hardcodeado en la app | OWASP ASVS 5.0 §2.10.4 | Credencial OS en código fuente — riesgo máximo |
| AB-03 | `psql` directo desde cliente Dart | ADR-020, SBOS-050 P9 | Bypassea todo: PEP, PDP, auditoría, BitMask — cero trazabilidad |
| AB-04 | DSN `postgres://postgres:postgres` en código Dart | OWASP ASVS 5.0 §2.10 | Superusuario de BD en código fuente |
| AB-05 | SQL inline en `bauth_api.dart` | ADR-020 Interface Dual | Lógica de datos en el cliente — no existe contrato RPC |
| AB-06 | Sin autenticación de usuario (dashboard) | ISO 27001 A.9.2.1 | Cualquier proceso SSH puede usar el dashboard sin credenciales propias |
| AB-07 | Sin auditoría de acciones del dashboard | ISO 27001 A.8.15 | Forensia imposible — quién hizo qué no se registra |
| AB-08 | `ejecutarCmd` abre nueva sesión SSH por comando | Rendimiento | ~300-2000ms overhead por consulta — causa la lentitud percibida |

### 1.2 Por qué SSH es una aberración de comunicación — no solo de configuración

La aberración no está solo en el password hardcodeado (AB-02) o en el usuario root (AB-01).
**El uso de SSH como protocolo de transporte de datos de aplicación es en sí mismo incorrecto.**

SSH fue diseñado para que un administrador humano obtenga una shell en un host remoto
(RFC 4251-4256). Su unidad de identidad es el usuario del sistema operativo, no la
identidad de la aplicación. Usar SSH para tunelizar JSON-RPC es equivalente a usar una
retroexcavadora para clavar un tornillo — la herramienta no corresponde al trabajo.

**Evidencia de la industria (todos usan protocolos de aplicación, nunca SSH):**

| Sistema | Protocolo de comunicación | Autenticación |
|---------|--------------------------|---------------|
| Docker daemon | REST sobre Unix socket / TLS TCP | Certificados TLS mutuo |
| HashiCorp Vault | HTTPS en 0.0.0.0:8200 | Token Bearer / mTLS |
| Tailscale daemon | HTTP sobre Unix socket local | Token POSIX + plataforma |
| 1Password daemon | IPC sobre abstract Unix socket | Identidad de plataforma + biometría |
| HashiCorp Nomad | HTTP RESTful API | Token Bearer |

Ninguno de estos sistemas usa SSH para que su cliente hable con su daemon. SSH aparece
únicamente cuando un *administrador humano* necesita acceso de emergencia al host — nunca
como mecanismo de comunicación cliente-daemon.

**Lo que se conserva del código actual:** el patrón JSON-RPC 2.0 multiplexado y la
interfaz `IClienteRpc` — el protocolo de mensajes es correcto. Lo que se elimina es
el transporte SSH por completo, incluyendo `dartssh2` del `pubspec.yaml`.

---

## §2 Arquitectura objetivo

### 2.1 Diagrama de flujo objetivo

```
[Flutter Desktop]
    │
    │ 1. login: usuario + contraseña
    │    → POST https://bauth.sbos.local/auth  (Kong)
    │    ← JWT firmado (Vault Ed25519, 8h TTL)
    │
    │ 2. Conexión WebSocket Segura
    │    wss://bauth.sbos.local/ws  (Kong 443)
    │    Header: Authorization: Bearer <JWT>
    │
    ▼
[Kong API Gateway]  ← valida firma JWT (Vault Ed25519 public key)
    │                  rechaza si expirado, mal firmado, o scope ≠ "dashboard"
    │
    │ 3. Proxy WS → ws://127.0.0.1:9450 (loopback — nunca TCP externo)
    │    X-bAuth-Subject: <user_id>
    │    X-bAuth-RolBitMask: <64bit_hex>
    │    X-bAuth-CtxId: <ctx_id>
    ▼
[bAuth daemon TCP listener :9450]
    │
    │ 4. JSON-RPC 2.0 — métodos bauth.*
    │    bauth.rol_template.tree → consulta SBOSDB internamente
    │    bauth.identidad.lista   → evalúa BitMask antes de retornar
    │
    ▼
[SBOSDB via connection pool interno]
```

### 2.2 Principios que cumple esta arquitectura

| Principio | Cumplimiento |
|-----------|-------------|
| ADR-020 Interface Dual | JSON-RPC 2.0 sobre WebSocket — sin HTTP/TCP entre daemons |
| SBOS-050 P9 | WS loopback `127.0.0.1:9450` — nunca TCP externo entre daemons |
| SBOS-049 Context Plane | `ctx_id` generado por daemon, propagado en cada respuesta |
| ISO 27001 A.8.15 | Cada operación deja registro de auditoría con user_id + ctx_id |
| NIST SP 800-63B AAL1 | Autenticación usuario+contraseña emitida por bAuth propio |
| ADR-010 (bAuth autosuficiente) | bAuth emite JWT con Vault Ed25519 — sin Keycloak |
| Least privilege (NIST AC-6) | Cada usuario del dashboard tiene rol con átomos específicos |

### 2.3 Componentes del lado servidor

```
bauth daemon
├── src/server/
│   ├── tcp_listener.rs       ← NUEVO: listener TCP 127.0.0.1:9450
│   ├── ws_handler.rs         ← NUEVO: upgrade HTTP → WebSocket
│   ├── jwt_middleware.rs     ← NUEVO: valida JWT en handshake WS
│   └── jsonrpc.rs            ← EXISTENTE: dispatcher de métodos bauth.*
│
└── src/api/dashboard/        ← NUEVO: módulo de métodos del dashboard
    ├── mod.rs
    ├── rol_template.rs       ← bauth.rol_template.*
    ├── identidad.rs          ← bauth.identidad.*
    ├── dominio.rs            ← bauth.dominio.*
    └── motor_salud.rs        ← bauth.motor.estado
```

---

## §3 Autenticación usuario+contraseña

### 3.1 ¿Es pertinente desarrollarla ahora?

**SÍ — es la primera prioridad, antes que cualquier otra fase.**

Argumentos:

1. **El dashboard no tiene autenticación de aplicación hoy.** SSH root no es autenticación
   de usuario del dashboard — es acceso al sistema operativo. Si un atacante tiene SSH, tiene
   todo. Con JWT, el atacante que tiene SSH aún no tiene sesión de dashboard válida.

2. **bAuth ES el proveedor OIDC del ecosistema.** Si bAuth no autentica a sus propios
   administradores, ningún daemon del ecosistema puede confiar en que bAuth autentica a nadie.
   Es una contradicción filosófica: el IAM que no gestiona su propia identidad.

3. **Habilita la auditoría por usuario.** Con JWT, cada acción del dashboard queda registrada
   con `user_id` real, no con "el proceso SSH root que estaba conectado".

4. **Es el primer paso del roadmap hacia OIDC PKCE** (Fase 3). Implementar user+password
   ahora establece el flujo de autenticación que luego se eleva a PKCE sin reescribir el cliente.

5. **El costo es bajo.** bAuth ya implementa el método `Contraseña+Argon2id` (estado: ✅).
   El endpoint de login del dashboard reutiliza ese motor.

### 3.2 Diseño del flujo de autenticación — Capas 1-3 (sin átomos)

> **Restricción fundamental:** los átomos no existen todavía. Son generados por
> `roles_template` — que es precisamente el sistema que el dashboard administra.
> Usar átomos para autorizar el acceso a `roles_template` sería un bloqueo circular.
> Las primeras capas NO evalúan átomos. La autorización es binaria: **método de
> autenticación verificado = acceso concedido**.

```
1. [Flutter] vista_login.dart
      ↓ usuario (email o nombre_usuario) + contraseña
      ↓ JSON-RPC: bauth.session.login({ "usuario": "...", "password": "..." })

2. [bAuth daemon]
      → Encuentra usuario en SBOSDB (idn_user_template)
      → Verifica hash Argon2id  ← único criterio de autorización en estas capas
      → Si verificado: construye JWT mínimo
           sub: user_id (UUID)
           iss: bauth.sbos.local
           exp: now + 8h
           iat: now
           ctx_id: uuid_v7 generado
           scope: "dashboard"          ← audiencia fija, sin bitmask
           jti: uuid_v7 (para revocación)
      → Firma con Vault Ed25519
      ← Retorna { token, expira_en }   ← sin rol_bitmask (no existen átomos aún)

3. [Flutter]
      → Almacena JWT con flutter_secure_storage
      → JWT válido = acceso completo al dashboard
      → No hay decodificación de átomos (todavía no hay átomos)
```

**El rol_bitmask se incorpora en Capa 5** (futura), cuando `roles_template` haya
generado los primeros átomos y el usuario tenga rol asignado con ellos.

### 3.3 Política de contraseñas para cuentas de dashboard

Aplican las reglas NIST 800-63B ya implementadas en `domain/password_policy.rs`:

| Parámetro | Valor |
|-----------|-------|
| Longitud mínima | 12 caracteres |
| Longitud máxima | 64 caracteres |
| Screening contra listas HIBP | Obligatorio |
| Complejidad impuesta | No (NIST 800-63B Rev.4 §3.1.1 — la complejidad forzada reduce entropía real) |
| Rotación periódica | No (NIST 800-63B Rev.4 §3.4.1 — rotación periódica solo si hay evidencia de compromiso) |
| Intentos fallidos máximos | 5 en 15 min → bloqueo temporal (cooldown exponencial) |
| MFA al crear cuenta | Recomendado; TOTP o WebAuthn para cuentas D03 |

### 3.4 Escalada futura: OIDC PKCE (Fase 3)

Una vez operativa la autenticación usuario+contraseña, la Fase 3 eleva el flujo a
**OAuth 2.0 Authorization Code + PKCE** (RFC 6749 + RFC 7636):

- Flutter genera `code_verifier` (aleatorio 43-128 chars) + `code_challenge` (SHA-256)
- Abre webview con URL de autorización de bAuth OIDC Provider
- bAuth emite `authorization_code` (corta vida: 10 min)
- Flutter intercambia `code` + `code_verifier` → `access_token` + `refresh_token`
- Ventaja: el password nunca viaja al cliente Flutter — solo el código de autorización

Este flujo ya está diseñado en bAuth (motor OIDC Provider nativo, ADR-010).
La Fase 1 (user+password) establece las mismas tablas y el mismo JWT — Fase 3 solo cambia
cómo se obtiene el JWT, no qué contiene ni cómo se valida.

---

## §4 Autorización: separación de autenticación y autorización por átomos

### 4.1 Principio fundamental — los átomos no se generan manualmente

**Los átomos NO se crean a mano.** Son generados por el motor `roles_template` al procesar
los nodos del árbol `idn_roles_template` de la BD. Ningún átomo existe hasta que
`roles_template` los produce.

Esto crea un orden de dependencia estricto:

```
roles_template opera → genera átomos → átomos pueden usarse para autorización
      ↑
  el dashboard administra roles_template
      ↑
  para entrar al dashboard se necesitaría... ← BLOQUEO CIRCULAR si usamos átomos
```

**La conclusión es obligatoria:** las primeras capas del dashboard NO pueden depender
de átomos. La autorización inicial es solo verificación de método de autenticación.

### 4.2 Dos fases de autorización — sin huevo ni gallina

El ciclo de vida de la autorización tiene dos fases bien separadas:

| Fase | Cuándo | Autorización | JWT contiene |
|------|--------|-------------|-------------|
| **Pre-átomos** (Capas 1-4) | Ahora y hasta que roles_template genere átomos | Método de autenticación verificado = acceso total | `sub`, `scope:"dashboard"`, `ctx_id`, `jti` |
| **Con átomos** (Capa 5+) | Cuando roles_template haya generado el catálogo de átomos | BitMask 64-bit evalúa qué puede hacer cada usuario | Todo lo anterior + `rol_bitmask` |

**La separación es limpia:** cambiar de "pre-átomos" a "con átomos" es agregar un campo al
JWT y un nuevo decorador de autorización (`AtomAuthzDecorator`) — sin reescribir nada.

### 4.3 Qué ocurre en las Capas 1-4 (pre-átomos)

La pregunta de autorización en estas capas es solo:

> **¿El método de autenticación del usuario fue verificado exitosamente?**  
> → Sí: JWT emitido, acceso concedido.  
> → No: rechazo.

No hay rol, no hay bitmask, no hay átomo. El campo `scope: "dashboard"` en el JWT
identifica la audiencia del token (el daemon valida que el token es para el dashboard,
no para otro servicio).

### 4.4 Diseño futuro de átomos del dashboard (Capa 5 — cuando roles_template los genere)

Una vez que `roles_template` genere átomos, el catálogo propuesto para el dashboard es:

| Átomo (propuesto, dominio D03) | Acción | AAL |
|-------------------------------|--------|-----|
| `D03.dashboard.acceso` | Acceder al dashboard | AAL1 |
| `D03.rol_template.ver` | Ver árbol de rol template | AAL1 |
| `D03.rol_template.editar` | Crear/modificar nodos | AAL2 |
| `D03.identidad.ver` | Listar identidades | AAL1 |
| `D03.identidad.crear` | Crear identidades | AAL2 |
| `D03.motor.estado` | Ver salud de los 7 motores | AAL1 |
| `D03.auditoria.ver` | Ver logs de auditoría | AAL2 |

> **Nota:** estos átomos se definen como nodos en `roles_template` (dominio D03),
> y son producidos por el motor `roles_template` — **no** insertados manualmente en BD.
> Esta tabla es una especificación de diseño, no una instrucción de inserción directa.

### 4.5 El `EvaluadorBitmask` — preparado pero inactivo hasta Capa 5

El código del evaluador se puede escribir en Capa 1 (por ser lógica pura, sin dependencias),
pero no se invoca hasta que el JWT contenga `rol_bitmask`:

```dart
// domain/bitmask_evaluador.dart — lógica pura, sin I/O
// Escrito en Capa 1, activado en Capa 5.
class EvaluadorBitmask {
  final int _mascara;
  const EvaluadorBitmask(this._mascara);
  bool tieneAtomo(int bitPos) => (_mascara >> bitPos) & 1 == 1;
}
```

Mientras no haya `rol_bitmask` en el JWT, el evaluador no se instancia y la UI
no condiciona visibilidad por átomo — todo es visible para usuarios autenticados.

---

## §5 Plan de implementación — Estrategia aditiva por capas (sin SSH)

### 5.0 El doble antipatrón que corregimos

Los planes v1.0, v2.0 y v3.0 cometían dos errores distintos:

```
v1.0 — Phased Big Bang:  cada fase descartaba la anterior
v2.0 — SSH como Capa 1:  SSH formalizado como primer transporte "legítimo"
        ↑ INCORRECTO — SSH es administración de sistemas, no protocolo de aplicación
        Docker, Vault, Tailscale, 1Password NUNCA usan SSH para hablar con su daemon
```

El plan v4.0 (este) corrige ambos:

```
PLAN CORRECTO (v4.0 — Capas aditivas sin SSH en el path de la aplicación):
Capa 0 → ITransportClient          ← contrato permanente — NUNCA cambia
Capa 1 → WebSocketAdapter (ws://)  ← WebSocket DIRECTO al daemon, sin SSH, sin Kong
Capa 2 → JwtAuthDecorator          ← añade autenticación sobre la Capa 1
Capa 3 → Kong TLS Gateway          ← ws://dev → wss://prod; la app solo cambia URL
Capa 4 → OidcTokenProvider         ← cambia cómo se obtiene el JWT, no el transporte
Capa 5 → AtomAuthzDecorator        ← FUTURA; cuando roles_template genere átomos

SSH permanece como herramienta de ADMINISTRACIÓN del host (deploy, configs, emergencias).
NUNCA en el path de comunicación de la aplicación.
```

El principio es idéntico al IAM Installer de BOS (`1.02_MANUAL-IAM-INSTALLER-SAGAS.md`):
cada capa tiene criterios de éxito verificables antes de avanzar, y lo construido en Capa N
**no se modifica** en Capa N+1 — solo se agrega encima.

---

### 5.1 Capa 0 — El contrato permanente: `ITransportClient`

**Duración:** 1 día. **Tipo:** Fundación — permanente, nunca cambia.

Este artefacto vive en todas las capas sin modificación. Se define antes de cualquier
implementación. `dartssh2` se elimina de `pubspec.yaml` en este mismo paso.

```dart
// nucleo/conexion/i_transport_client.dart
abstract interface class ITransportClient {
  /// Envía un request JSON-RPC 2.0 y retorna la respuesta.
  Future<Map<String, dynamic>> llamar(String metodo, [Map<String, dynamic>? params]);

  /// Conecta al servidor. Los parámetros son polimórficos — cada adaptador extrae lo suyo.
  Future<void> conectar(ParametrosConexion params);

  void desconectar();
  Stream<EstadoConexion> get estado;
  bool get estaConectado;
  void dispose();
}
```

**Cambios en `pubspec.yaml`:**

```yaml
# ELIMINAR:
dartssh2: ^2.x.x

# AGREGAR:
web_socket_channel: ^3.0.0
flutter_secure_storage: ^9.0.0
```

**Criterio de cierre:** `grep -r dartssh2 lib/` → 0 resultados. Ningún import de
`cliente_rpc_ssh.dart` en capas de UI o API.

---

### 5.2 Capa 1 — `WebSocketTransportAdapter` directo (modo dev)

**Duración:** 3-5 días. **Tipo:** Primer transporte real — WebSocket puro, sin intermediarios.

En esta capa el cliente Flutter conecta directamente al daemon por TCP WebSocket.
Sin Kong, sin TLS, solo `ws://host:9450`. El patrón es exactamente como trabajan
HashiCorp Vault y Docker en modo de desarrollo: listener TCP local, acceso directo.

#### Lado Rust: TCP WebSocket listener en el daemon

```rust
// src/server/tcp_listener.rs
// Listener TCP en 127.0.0.1:9450 (loopback en prod; 0.0.0.0:9450 en dev).
// HTTP Upgrade → WebSocket (tokio-tungstenite).
// Usa el MISMO dispatcher jsonrpc.rs que el socket Unix — cero duplicación.
// Patrón HashiCorp Vault: mismo código sirve Unix socket y TCP listener.

pub async fn arrancar(addr: SocketAddr, dispatcher: Arc<JsonRpcDispatcher>) {
    let listener = TcpListener::bind(addr).await?;
    while let Ok((stream, _)) = listener.accept().await {
        let ws_stream = accept_async(stream).await?;
        tokio::spawn(manejar_ws(ws_stream, Arc::clone(&dispatcher)));
    }
}
```

ADR-020 Interface Dual se cumple: el mismo `jsonrpc.rs` dispatcher sirve tanto
el Unix socket (daemons hermanos) como el TCP WebSocket (clientes externos).

#### Lado Flutter

```dart
// nucleo/conexion/ws_transport_adapter.dart
// Primera implementación real de ITransportClient — WebSocket puro.
// Multiplexado JSON-RPC 2.0 idéntico al patrón de ClienteRpcSsh.llamar()
// pero sin ninguna dependencia de SSH.
class WsTransportAdapter implements ITransportClient {
  final WebSocketChannel _canal;
  final StringBuffer _buf = StringBuffer();
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};
  int _nextId = 1;

  static Future<WsTransportAdapter> conectar(Uri uri, {Map<String,dynamic>? headers}) async {
    final canal = WebSocketChannel.connect(uri, protocols: ['json-rpc-2.0']);
    await canal.ready;
    return WsTransportAdapter._(canal);
  }

  @override
  Future<Map<String, dynamic>> llamar(String metodo, [Map<String, dynamic>? params]) async {
    final id = _nextId++;
    _canal.sink.add(jsonEncode({'jsonrpc': '2.0', 'method': metodo, 'params': params, 'id': id}));
    final completer = Completer<Map<String, dynamic>>();
    _pendientes[id] = completer;
    return completer.future.timeout(const Duration(seconds: 15));
  }
}
```

**Qué se agrega (del lado daemon Rust):**

```
src/api/dashboard/
├── mod.rs
├── sesion.rs        ← bauth.session.login/logout/refresh
├── rol_template.rs  ← bauth.rol_template.tree/hijos/nodo
└── motor_salud.rs   ← bauth.motor.estado
```

**Qué se agrega en Flutter:**

```
nucleo/auth/
├── sesion_manager.dart       ← guarda JWT en flutter_secure_storage
├── jwt_claims.dart           ← decodifica claims JWT (base64url decode, sin verificar firma)
└── i_repositorio_tokens.dart ← interfaz de tokens para composición en Capa 4

vistas/
└── vista_login.dart          ← formulario usuario + contraseña
```

**Criterios de cierre (gate):**

| Criterio | Verificación |
|----------|-------------|
| Sin SSH en ningún archivo | `grep -r dartssh2 lib/` → 0; `grep -r ssh lib/` → 0 |
| `ejecutarCmd` eliminado | `grep -r ejecutarCmd lib/` → 0 |
| Sin SQL en Dart | `grep -r psql lib/` → 0; `grep -r _dsnSbos lib/` → 0 |
| TCP listener activo en daemon | `curl http://localhost:9450` → `426 Upgrade Required` |
| Conexión WS funciona | `wscat -c ws://127.0.0.1:9450` → conecta |
| Login verifica método | `bauth.session.login` con password correcto → JWT firmado Ed25519 |
| Login rechaza inválido | `bauth.session.login` con password incorrecto → error -32001 |
| Árbol carga vía RPC | `bauth.rol_template.tree` retorna todos los nodos en < 200ms |
| JWT sin rol_bitmask | JWT contiene `scope:"dashboard"`, NO `rol_bitmask` (no existen átomos) |
| `flutter analyze` limpio | 0 errores, 0 warnings |

---

### 5.3 Capa 2 — `JwtAuthDecorator`: autenticación sin tocar el transporte

**Duración:** 2-3 días. **Tipo:** Decorador GoF sobre `WsTransportAdapter`.

JWT es una responsabilidad ortogonal al transporte. El decorator inyecta el Bearer token
en el handshake WebSocket. `WsTransportAdapter` no sabe que existe el decorator.

```dart
// nucleo/conexion/jwt_auth_decorator.dart
class JwtAuthDecorator implements ITransportClient {
  final IRepositorioTokens _tokens;
  WsTransportAdapter? _ws;
  final Uri _baseUri;

  @override
  Future<void> conectar(ParametrosConexion p) async {
    final jwt = await _tokens.tokenValido();
    // El JWT va en el header del Upgrade — patrón OAuth 2.0 + WebSocket estándar
    _ws = await WsTransportAdapter.conectar(
      _baseUri,
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  @override
  Future<Map<String, dynamic>> llamar(String metodo, [Map<String, dynamic>? params]) async {
    if (_ws == null || !_ws!.estaConectado) await conectar(_params!);
    return _ws!.llamar(metodo, params);
  }
}
```

El daemon valida el JWT en el handshake (antes de aceptar la conexión WebSocket).
Si el JWT es inválido o expirado, el handshake falla con HTTP 401 — la conexión nunca abre.

**Criterios de cierre (gate):**

| Criterio | Verificación |
|----------|-------------|
| JWT sin token → 401 | Conectar sin `Authorization` → daemon rechaza con 401 |
| JWT inválido → 401 | JWT firmado con clave incorrecta → daemon rechaza |
| JWT expirado → renovación | Decorator llama `_tokens.tokenValido()` → renueva antes de expirar |
| `WsTransportAdapter` sin JWT | `grep -i jwt nucleo/conexion/ws_transport_adapter.dart` → 0 |

---

### 5.4 Capa 3 — Kong como proxy TLS: `ws://` → `wss://`

**Duración:** 1-2 días. **Tipo:** Infraestructura — el daemon NO cambia, Flutter solo cambia la URL.

Esta es la capa más simple en código: Kong se interpone entre el cliente y el daemon.
El daemon sigue escuchando en `127.0.0.1:9450` exactamente igual que en Capa 1.
Flutter solo cambia de `ws://host:9450` a `wss://bauth.sbos.local/ws`.

```
Capa 1:  Flutter  →  ws://vps_ip:9450  →  daemon (dev, sin TLS)
Capa 3:  Flutter  →  wss://bauth.sbos.local/ws  →  Kong  →  ws://127.0.0.1:9450  →  daemon
```

```yaml
# Kong — declarativo
services:
  - name: bauth-desktop-ws
    url: ws://127.0.0.1:9450   ← mismo endpoint del daemon, sin cambios en Rust

routes:
  - name: bauth-desktop-ws-route
    service: bauth-desktop-ws
    protocols: [wss]
    hosts: [bauth.sbos.local]
    paths: [/ws]

plugins:
  - name: jwt
    service: bauth-desktop-ws
    config:
      key_claim_name: sub
      secret_is_base64: false
```

Kong valida el JWT (firma Ed25519 de Vault, `scope:"dashboard"`, `exp`).
El daemon valida el JWT **también** (defensa en profundidad — si Kong es comprometido,
el daemon no ejecuta operaciones no autorizadas). Patrón documentado por HashiCorp Vault.

**Criterios de cierre (gate):**

| Criterio | Verificación |
|----------|-------------|
| Kong proxea WebSocket | `wscat -c wss://bauth.sbos.local/ws -H "Authorization: Bearer <jwt>"` → conecta |
| TLS 1.3 activo | `openssl s_client -connect bauth.sbos.local:443` → `Protocol: TLSv1.3` |
| JWT inválido → Kong rechaza | Conectar con JWT expirado → `401 Unauthorized` antes de llegar al daemon |
| Daemon sin cambios | `git diff src/server/` → 0 líneas modificadas en Capa 3 |

---

### 5.5 Capa 4 — `OidcTokenProvider`: elevar la autenticación sin tocar el transporte

**Duración:** 2-3 semanas. **Tipo:** Nueva implementación de `IRepositorioTokens`.

OIDC PKCE es solo un cambio en **cómo se obtiene el JWT inicial**. `JwtAuthDecorator` acepta
cualquier `IRepositorioTokens` — Capa 3 y Capa 2 no se modifican.

```dart
// nucleo/auth/oidc_token_provider.dart
class OidcTokenProvider implements IRepositorioTokens {
  // RFC 7636 PKCE:
  // 1. Genera code_verifier (43-128 chars aleatorio, base64url)
  // 2. Calcula code_challenge = SHA-256(code_verifier), base64url
  // 3. Abre webview: bAuth /authorize?response_type=code&code_challenge=...
  // 4. Recibe authorization_code del redirect
  // 5. POST /token: { code, code_verifier } → access_token + refresh_token
  // El password NUNCA viaja desde Flutter — solo el código de autorización
}
```

---

### 5.6 Capa 5 — `AtomAuthzDecorator` (futura)

**Cuando:** después de que `roles_template` genere los átomos D03.
**Tipo:** Decorador sobre `JwtAuthDecorator` — nada de lo anterior se modifica.

Cuando el daemon emita JWTs con `rol_bitmask`, este decorator verifica localmente que
el usuario tiene el átomo requerido antes de enviar cada request. Para las operaciones
de escritura (editar nodos, crear identidades), el daemon también evalúa el bitmask.

---

### 5.7 Resumen visual del plan

```
         Capa 0          Capa 1         Capa 2         Capa 3        Capa 4        Capa 5
         ──────          ──────         ──────         ──────        ──────        ──────
Arte-    ITransport      WsTransport    JwtAuth        Kong TLS      OidcToken     AtomAuthz
facto    Client          Adapter        Decorator      Gateway       Provider      Decorator

Trans-   (contrato)      ws://          ws:// + JWT    wss://        wss:// +      wss:// +
porte                    directo        header         (mismo ws)    PKCE          JWT+bitmask

¿Se      NO              NO             NO             NO            NO            —
borra?

Rol      Pacto           Transporte     Auth           Seguridad     Auth          AuthZ
final    permanente      principal      de app         TLS+Kong      sin pwd       por átomo
```

**SSH:** únicamente herramienta de administración del host (deploy, incidentes).
**Nunca** en el path de comunicación de la aplicación, en ninguna capa.

**Duración estimada:**

| Capa | Tiempo | Gate de avance |
|------|--------|----------------|
| Capa 0 | 1 día | `dartssh2` eliminado; `ITransportClient` definida; 0 imports directos a adaptadores |
| Capa 1 | 3-5 días | WebSocket funciona; 0 SSH en `lib/`; login verifica método; árbol carga < 200ms |
| Capa 2 | 2-3 días | JWT en handshake; sin token → 401; renovación automática |
| Capa 3 | 1-2 días | Kong proxea wss://; TLS 1.3; daemon sin cambios en Rust |
| Capa 4 | 2-3 semanas | PKCE completa; password nunca viaja en tránsito |
| Capa 5 | Futuro | roles_template genera átomos D03 → JWT incluye rol_bitmask |

---

## §6 API JSON-RPC necesaria

### 6.1 Métodos de sesión

```
bauth.session.login
  params: { usuario: string, password: string, device_info?: object }

  result (Capas 1-4, sin átomos):
    { token: string, tipo: "Bearer", expira_en: int, ctx_id: string }
    JWT claims: { sub, iss, exp, iat, ctx_id, scope:"dashboard", jti }

  result (Capa 5+, con átomos generados por roles_template):
    { token: string, tipo: "Bearer", expira_en: int, ctx_id: string, rol_bitmask_hex: string }
    JWT claims: { sub, iss, exp, iat, ctx_id, scope:"dashboard", jti, rol_bitmask }

  error: -32001 credenciales inválidas | -32002 cuenta bloqueada | -32003 requiere MFA

bauth.session.logout
  params: { jti: string }   ← id del JWT a invalidar
  result: { ok: true }

bauth.session.refresh
  params: { refresh_token: string }
  result: { token: string, expira_en: int }
```

### 6.2 Métodos del árbol de rol template

```
bauth.rol_template.tree
  params: { tenant_slug: string, profundidad?: int }
  result: { nodos: NodoRolTemplate[] }   ← todos los nodos, aplanados, con parent_id

bauth.rol_template.nodo
  params: { id: string }
  result: NodoRolTemplate

bauth.rol_template.hijos
  params: { parent_id: string | null }
  result: { nodos: NodoRolTemplate[] }

NodoRolTemplate {
  id: string, parent_id: string | null,
  tipo: string, clave: string, nombre: object (i18n),
  depth: int, sort_order: int, alias: string,
  block_code: string, domain_number: int,
  effect: string, verb_id: string | null
}
```

### 6.3 Métodos de salud de motores

```
bauth.motor.estado
  params: {}
  result: {
    motores: [
      { id: string, nombre: string, estado: "OK"|"DEGRADADO"|"ERROR",
        latencia_ms: int, ultimo_chequeo: string (ISO8601) }
    ]
  }
```

### 6.4 Métodos de identidad (Fase 1+)

```
bauth.identidad.lista
  params: { tenant_slug: string, pagina?: int, por_pagina?: int, filtro?: string }
  result: { total: int, identidades: IdentidadResumen[] }
  requiere_atomo: D03.identidad.ver

bauth.identidad.detalle
  params: { id: string }
  result: IdentidadDetalle
  requiere_atomo: D03.identidad.ver
```

---

## §7 Cambios en el cliente Flutter

### 7.1 Resumen de modificaciones por archivo

| Archivo | Acción | Fase |
|---------|--------|------|
| `pubspec.yaml` | Agregar `flutter_secure_storage`, `web_socket_channel` | F1 / F2 |
| `pubspec.yaml` | Eliminar `dartssh2` | F2 |
| `nucleo/conexion/config_conexion.dart` | Eliminar `_dsnSbos`, agregar `wss_url` | F1 |
| `nucleo/conexion/cliente_rpc_ssh.dart` | Eliminar `ejecutarCmd` | F1 |
| `nucleo/conexion/cliente_rpc_ws.dart` | Crear — `IClienteRpc` sobre WebSocket | F2 |
| `nucleo/auth/sesion_manager.dart` | Crear — guarda/renueva JWT | F1 |
| `nucleo/auth/jwt_claims.dart` | Crear — decodifica claims (sin validar firma) | F1 |
| `nucleo/api/bauth_api.dart` | Eliminar `rolTemplateTodos()` con SQL | F1 |
| `nucleo/api/bauth_api.dart` | Agregar `rolTemplateTree()` via `llamar()` | F1 |
| `vistas/vista_login.dart` | Crear — formulario usuario+contraseña | F1 |
| `widgets/panel_conexion.dart` | Reemplazar por `vista_login.dart` | F1 |
| `domain/bitmask_evaluador.dart` | Crear — evaluación local de átomos | F1 |

### 7.2 Árbol de dependencias entre capas (sin cambios a la interfaz IClienteRpc)

```
vista_login.dart
    └── sesion_manager.dart  →  bauth_api.session.login()
                             →  SecureStorage (jwt, refresh_token)

vista_rol_template.dart
    └── bauth_api.rolTemplateTree()     ← llamar('bauth.rol_template.tree', ...)
        └── IClienteRpc.llamar()        ← sin cambios en la interfaz
            ├── ClienteRpcSsh (Fase 1)  ← conserva llamar() pero elimina ejecutarCmd()
            └── ClienteRpcWs (Fase 2)  ← reemplaza SSH por WebSocket
```

La interfaz `IClienteRpc` **no cambia** entre Fase 1 y Fase 2 — solo cambia la implementación.
Toda la capa de API y vistas se mantiene sin modificaciones al migrar de SSH a WebSocket.

---

## §8 Seguridad del canal

### 8.1 TLS 1.3 obligatorio

Kong termina TLS en la conexión cliente (`wss://bauth.sbos.local`).
El tramo Kong → daemon (`ws://127.0.0.1:9450`) es loopback sin cifrar — correcto porque
permanece dentro del mismo host y nunca cruza red externa.

**Prohibido:** TLS self-signed permanente en producción. El certificado de Kong debe ser
firmado por la PKI interna de Vault (SBOS-054-NETWORK-SECURITY NRS-03).

### 8.2 Validación de JWT en el daemon

Aunque Kong valida el JWT en el Upgrade header, el daemon **también lo valida** internamente:

1. Verifica firma Ed25519 contra la clave pública de Vault.
2. Verifica que `exp` no haya pasado (margen de 60s de clock skew).
3. Verifica que `jti` no esté en la lista negra de revocación (Redis — cuando esté activo).
4. Extrae `rol_bitmask` y evalúa el átomo necesario para el método solicitado.

Defensa en profundidad: si Kong es comprometido o mal configurado, el daemon no ejecuta
operaciones no autorizadas.

### 8.3 Almacenamiento de JWT en Flutter

```dart
// flutter_secure_storage — cifrado por Keychain (macOS) / Keystore (Android) / libsecret (Linux)
// Nunca SharedPreferences ni memoria cleartext para el JWT

final storage = const FlutterSecureStorage(
  lOptions: LinuxOptions(useSessionKeyring: false),
);
await storage.write(key: 'bauth_jwt', value: token);
await storage.write(key: 'bauth_refresh', value: refreshToken);
```

### 8.4 Renovación automática (token refresh)

El `sesion_manager.dart` renueva el JWT silenciosamente:
- Comprueba `exp - now < 5 min` antes de cada llamada RPC.
- Si es el caso, llama `bauth.session.refresh` y actualiza el store.
- Si el refresh_token también expiró → logout + pantalla de login.

---

## §9 Decisiones HITL pendientes

Estas decisiones requieren aprobación del humano antes de implementar:

| ID | Decisión | Opciones | Impacto |
|----|----------|----------|---------|
| H-01 | Dominio para átomos del dashboard | D03 (propuesto) / D99 (administración interna) / D00 (identidad organizacional) | Define dónde van los átomos en la BD y el BitMask |
| H-02 | Puerto TCP del listener del daemon | 9450 (según config actual) / otro del rango 9400-9499 | Configuración Kong + firewall |
| H-03 | TTL del JWT del dashboard | 8h (propuesto) / 4h / 12h | Frecuencia de re-login |
| H-04 | MFA obligatorio para cuentas D03 | Sí (TOTP/WebAuthn) / Opcional / Solo para roles D03.*.editar | Nivel de seguridad vs. fricción operativa |
| H-05 | Nombre de host Kong para el dashboard | `bauth.sbos.local` / `dashboard.bauth.sbos.local` / otro | DNS interno + certificado PKI |
| H-06 | ¿Activar refresh_token en Fase 1? | Sí (más seguro) / No (simplifica Fase 1) | Complejidad de implementación |
| H-07 | ¿Fase 0 antes de Fase 1 o es redundante? | Sí (credenciales en archivo local) / Directamente Fase 1 | Ventana de exposición del password |

---

## §10 Changelog

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 5.0.0 | 2026-08-04 | Reorientado como aplicación desktop del Motor de Comunicación 2.18. Se agrega bloque TAREA BLOQUEANTE referenciando 2.18/A.77/A.78 como fuentes de verdad del protocolo. Propósito de A.64.02 clarificado: diagnóstico desktop + plan capas desktop + gates — no la definición canónica del motor (eso es 2.18). |
| 4.0.0 | 2026-08-04 | §1.2 §5 reescritos — SSH eliminado del path de comunicación en TODAS las capas. La investigación (Docker, Vault, Tailscale, 1Password) confirma que ningún daemon de producción usa SSH como protocolo de aplicación. Capa 1 es WebSocket directo (`ws://`) + `dartssh2` eliminado de pubspec.yaml desde el día 1. Capa 3 agrega Kong como proxy TLS sin modificar el daemon. |
| 3.0.0 | 2026-08-04 | §3.2 §4 §5 §6 corregidos — los átomos no existen aún y son generados POR roles_template (no manualmente). Capas 1-4 prescinden de átomos: autorización = método verificado. JWT mínimo sin rol_bitmask. Capa 5 (futura) agrega AtomAuthzDecorator sin tocar las capas previas. |
| 2.0.0 | 2026-08-03 | §5 reescrito — Estrategia aditiva por capas (Strangler Fig + Branch by Abstraction + Decorator GoF + Parallel Run). Se corrige el antipatrón "Phased Big Bang" del v1.0. Cada capa es permanente; nada se descarta. |
| 1.0.0 | 2026-08-03 | Versión inicial — diagnóstico, arquitectura objetivo, 4 fases, API RPC, cambios Flutter, átomos |
