# PLAN-DESKTOP-BAUTH.md — Dashboard Soberano de Administración bAuth

**Versión:** 3.0.0 · **Fecha:** 2026-06-27 · **Autor:** bos-developer + investigación internacional
**Proyecto:** SBOS bAuth Identity Control Plane — Interfaz de Administración Desktop
**Stack:** Flutter 3.44+ + tf_shadcn_flutter + fl_chart + pluto_grid · Dart ≥3.4.0
**Plataformas:** Windows, Linux, macOS (primarias) · Android/iOS (pospuesto)
**Transporte:** WebSocket + JSON-RPC 2.0 directo (sin HTTP, sin SSH tunnel)
**Licencia:** BSD-3-Clause (shadcn_flutter) + MIT (fl_chart, pluto_grid)

## REGLAS IRRENUNCIABLES

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **Navegación total por teclado** | Toda función accesible sin mouse. `Tab`, `↑↓←→`, `Enter`, `Esc`, `Space` + atajos con combinaciones de teclas. Sin excepciones. |
| R2 | **Conexión directa WebSocket** | Sin HTTP. Sin REST. Sin SSH tunnel. WebSocket + JSON-RPC 2.0 puro al daemon. El instalador ya sabe IP y puerto. |
| R3 | **Instalador autocontenido** | Descargar → ejecutar → conectado. Cero dependencias externas. |

---

## 0. PROPÓSITO

El **Dashboard Soberano de Administración bAuth** es la interfaz visual del Identity Control
Plane del SBOS. Es el **PAP (Policy Administration Point)** del ecosistema — único lugar
donde un administrador puede crear, editar, publicar y sincronizar RolTemplates y
UserTemplates sobre los 12 dominios de control.

**No ejecuta operaciones directamente.** Toda mutación se canaliza vía JSON-RPC 2.0
sobre Unix socket `/run/bos/bauth.sock` (ADR-020). El desktop es una cáscara de
renderizado — la verdad vive en el daemon Rust.

---

## 1. ARQUITECTURA TÉCNICA

### 1.1 Capas de la aplicación

```
┌────────────────────────────────────────────────────────────┐
│                   UI LAYER (Flutter)                        │
│  Pantallas · Widgets · Árboles · Formularios · Gráficos    │
├────────────────────────────────────────────────────────────┤
│                STATE LAYER (Riverpod)                       │
│  Providers · Notifiers · AsyncValue · Cache TTL            │
├────────────────────────────────────────────────────────────┤
│               SERVICE LAYER (Dart)                          │
│  JsonRpcClient (Unix socket) · DomainTreeBuilder            │
│  AtomCatalogResolver · RolePublisher                       │
├────────────────────────────────────────────────────────────┤
│              TRANSPORT LAYER (WebSocket)                    │
│  ws://unix:/run/bos/bauth.sock → JSON-RPC 2.0              │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────┐
│              BAUTH DAEMON (Rust, systemd host)              │
│  47 handlers JSON-RPC · BitMask Dual · 12 dominios         │
│  PostgreSQL 18.4 · Redis 8.6.2                             │
└────────────────────────────────────────────────────────────┘
```

### 1.2 Decisiones de arquitectura

| Decisión | Elección | Justificación |
|----------|----------|---------------|
| **Framework UI** | `tf_shadcn_flutter` ^0.0.53+1 | 84+ componentes, árbol nativo (`TreeNodeData`), desktop-first, responsive integrado |
| **State management** | Riverpod 2.x | Providers declarativos, `AsyncValue` para loading/error/data, cache automática |
| **Tablas avanzadas** | `pluto_grid` | Sort, filtro, paginación, columnas ocultables — necesario para roles/usuarios |
| **Gráficos** | `fl_chart` | MIT license, liviano, sin dependencia de Material |
| **Tema visual** | **ForUI SSOT** (tokens) → `ShadThemeData` | Gobernanza SBOS-010. Tokens de color, tipografía, espaciado desde ForUI |
| **Comunicación** | JSON-RPC 2.0 sobre WebSocket Unix socket | ADR-020. Sin HTTP. Mismo socket que los daemons. |
| **Plataformas** | Windows, Linux, macOS (primarias) | Android/iOS responsive heredado del mismo codebase |
| **Ruteo** | `go_router` | Navegación declarativa, deep links, breadcrumbs |

### 1.3 Dependencias Flutter

```yaml
name: bauth_desktop
description: SBOS bAuth — Dashboard Soberano de Administración de Identidad
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'
  flutter: '>=3.32.3'

dependencies:
  flutter:
    sdk: flutter
  tf_shadcn_flutter: 0.0.53+1      # Base UI (84+ componentes, árbol nativo)
  flutter_riverpod: ^2.6.0          # State management
  riverpod_annotation: ^2.6.0       # Codegen para providers
  web_socket_channel: ^2.4.0        # WebSocket transport
  pluto_grid: ^8.0.0                # Tablas avanzadas (roles, usuarios, políticas)
  fl_chart: ^0.70.0                 # Gráficos de métricas (12 dominios)
  go_router: ^14.0.0                # Ruteo declarativo
  freezed_annotation: ^2.4.0        # Immutable state classes
  json_annotation: ^4.9.0           # JSON serialization

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.6.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
```

---

## 2. ARQUITECTURA DE COMPONENTES

### 2.1 Estructura del proyecto

```
desktop/
├── PLAN-DESKTOP-BAUTH.md          ← ESTE ARCHIVO
├── pubspec.yaml
├── lib/
│   ├── main.dart                  ← Entry point
│   ├── app.dart                   ← ShadApp + tema ForUI
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   ├── forui_tokens.dart  ← Tokens ForUI (colores, tipografía, espaciado)
│   │   │   └── shad_theme.dart    ← ShadThemeData desde tokens ForUI
│   │   ├── router/
│   │   │   └── app_router.dart    ← GoRouter config
│   │   └── constants/
│   │       └── endpoints.dart     ← Socket path, timeouts, etc.
│   │
│   ├── services/
│   │   ├── jsonrpc_client.dart    ← Cliente JSON-RPC 2.0 (WebSocket → Unix socket)
│   │   ├── atom_catalog.dart      ← Resolvedor de átomos (slug → atom_position)
│   │   └── domain_tree.dart       ← Constructor del árbol D1-D12 desde API
│   │
│   ├── models/
│   │   ├── role_template.dart     ← RolTemplate v6.0 (14 secciones JSONB)
│   │   ├── user_template.dart     ← UserTemplate v6.0 (15 secciones JSONB)
│   │   ├── atom.dart              ← AtomBitMask + atom_position
│   │   ├── domain.dart            ← DomainCode (D1-D12)
│   │   └── jsonrpc.dart           ← JsonRpcRequest/Response/Error
│   │
│   ├── providers/
│   │   ├── role_provider.dart     ← Provider<AsyncValue<List<RolTemplate>>>
│   │   ├── user_provider.dart     ← Provider<AsyncValue<List<UserTemplate>>>
│   │   ├── atom_provider.dart     ← Provider<AtomCatalog>
│   │   ├── domain_provider.dart   ← Provider<DomainConfig> (12 dominios × tenant)
│   │   └── health_provider.dart   ← Provider<HealthMetrics> (métricas Prometheus)
│   │
│   ├── screens/
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart    ← Vista 1: Salud global + métricas 12 dominios
│   │   ├── roles/
│   │   │   ├── role_list_screen.dart    ← Vista 2: Lista de RolTemplates
│   │   │   └── role_editor_screen.dart  ← Vista 3: Editor ÁRBOL (CRUD)
│   │   ├── users/
│   │   │   ├── user_list_screen.dart    ← Vista 4: Lista de UserTemplates
│   │   │   └── user_editor_screen.dart  ← Vista 5: Editor de Usuario
│   │   ├── policies/
│   │   │   └── policy_screen.dart       ← Vista 6: Políticas de autenticación
│   │   ├── audit/
│   │   │   └── audit_screen.dart        ← Vista 7: Auditoría ISO 27001
│   │   └── sync/
│   │       └── sync_screen.dart         ← Vista 8: Estado de sincronización KC+Tryton
│   │
│   └── widgets/
│       ├── tree/
│       │   ├── domain_tree.dart         ← Árbol jerárquico D1-D12 (TreeNodeData)
│       │   ├── tree_node_role.dart      ← Nodo: Rol
│       │   ├── tree_node_domain.dart    ← Nodo: Dominio (D1-D12)
│       │   ├── tree_node_app.dart       ← Nodo: Aplicación
│       │   ├── tree_node_module.dart    ← Nodo: Módulo
│       │   ├── tree_node_verb.dart      ← Nodo: Verbo + átomo
│       │   └── tree_search.dart         ← Buscador/filtro de nodos
│       ├── forms/
│       │   ├── section_identity.dart    ← Form: Identidad (cabecera)
│       │   ├── section_logical.dart     ← Form: D1 Lógico
│       │   ├── section_physical.dart    ← Form: D2 Físico
│       │   ├── section_financial.dart   ← Form: D3 Financiero
│       │   ├── section_temporal.dart    ← Form: D4 Temporal
│       │   ├── section_biometric.dart   ← Form: D5 Biométrico
│       │   ├── section_geospatial.dart  ← Form: D6 Geoespacial
│       │   ├── section_network.dart     ← Form: D7 Red
│       │   ├── section_credentials.dart ← Form: D9 Credenciales
│       │   ├── section_delegation.dart  ← Form: D10 Delegación
│       │   └── section_blockchain.dart  ← Form: D12 Blockchain
│       ├── charts/
│       │   ├── domain_health_radar.dart ← Radar 12 dominios (estado actual)
│       │   ├── domain_latency_bar.dart  ← Barras: latencia por dominio
│       │   └── role_distribution_pie.dart ← Tarta: roles por tier
│       └── shared/
│           ├── status_badge.dart        ← Badge de estado (SYNCED/DRIFT/ERROR)
│           ├── domain_icon.dart         ← Icono por dominio (D1-D12)
│           ├── confirm_dialog.dart      ← Diálogo de confirmación governance
│           └── loading_overlay.dart     ← Overlay de carga con progreso
```

### 2.2 El árbol de dominios — Componente central

```
ÁRBOL DE DOMINIOS (widget domain_tree.dart)
│
├── Nodo RAÍZ — Rol
│   ├── children: 12 nodos de dominio (D1-D12)
│
├── Nodo DOMINIO (D1 Lógico)
│   ├── children: Zonas
│   │   └── Nodo ZONA (AREA-CAJA)
│   │       ├── children: Aplicaciones
│   │       │   └── Nodo APP (Tryton)
│   │       │       ├── children: Módulos
│   │       │       │   └── Nodo MÓDULO (sale_pos)
│   │       │       │       └── Nodo VERBO (READ) + ÁTOMO
│   │       │       │           └── Checkbox ☑
│
├── Nodo DOMINIO (D2 Físico)
│   ├── children: Edificios
│   │   └── children: Pisos
│   │       └── children: Zonas físicas
│   │           └── children: Puntos de acceso
│   │               └── children: Dispositivos (lectores, cámaras, cerraduras)
│
├── Nodo DOMINIO (D3 Financiero)
│   ├── children: Tipos de transacción
│   │   ├── Límites (max_transaction, max_daily, max_monthly)
│   │   ├── Cadena de aprobación (dual_approval_above)
│   │   └── Regla SoD (creador ≠ aprobador)
│
├── ... D4 a D12 con sus respectivas jerarquías
│
└── PANEL LATERAL — Resumen
    ├── Secciones configuradas: X/14
    ├── Átomos asignados: N
    ├── Conflictos SoD: N
    └── Botones: [💾 GUARDAR BORRADOR] [📋 PUBLICAR ROL]
```

---

## 3. INTEGRACIÓN CON EL DAEMON RUST

### 3.1 Handlers JSON-RPC consumidos

El desktop consume los **47 handlers** del daemon. Cada pantalla se mapea a un conjunto
específico:

| Pantalla | Handlers JSON-RPC |
|----------|-------------------|
| **Dashboard** | `bauth.health.check` · `bauth.context.evaluate` · `bauth.sync.status` |
| **Lista Roles** | `bauth.role.template.list` · `bauth.role.template.get` · `bauth.role.list` |
| **Editor Rol (ÁRBOL)** | `bauth.role.template.get` (full JSONB) · `bauth.role.compute.mask` · `bauth.template.validate` · `bauth.inheritance.compute` · `bauth.sod.check` · `bauth.merge.templates` |
| **Lista Usuarios** | `bauth.user.list` · `bauth.tenant.list` |
| **Editor Usuario** | `bauth.user.list` (por ID) · `bauth.role.template.list` (para asignar rol) |
| **Políticas** | `bauth.policy.evaluate` · `bauth.template.validate` · `bauth.domain.audit` |
| **Sincronización** | `bauth.sync.reconcile` · `bauth.sync.status` |
| **Auditoría** | `bauth.domain.audit` · `bauth.context.plane` |
| **Acceso** | `bauth.access.evaluate` · `bauth.ctx.validate` |
| **Dominios** | `bauth.domain.logical` · `bauth.domain.physical` · `bauth.domain.financial` · `bauth.domain.biometric` · `bauth.domain.temporal` · `bauth.domain.geospatial` · `bauth.domain.network` · `bauth.context.evaluate` |
| **Comercial** | `bauth.commercial` · `bauth.idp.external` · `bauth.sign.internal` |

### 3.2 Flujo de datos — Editor de Rol

```
USUARIO expande D1 → Zona → App → Módulo → marca Verbo ☑
  │
  ▼
DomainTreeBuilder construye árbol desde RolTemplate JSONB (14 secciones)
  │
  ▼
Usuario edita (checkboxes, límites, horarios)
  │
  ▼
Al guardar: se serializa el árbol → RolTemplate JSONB
  │
  ▼
bauth.template.validate → 260+ reglas NIST/OWASP/FIDO2
  │
  ▼
bauth.role.compute.mask → RolBitMask (one-hot a partir de atom_positions)
  │
  ▼
bauth.sod.check → ConflictMatrix → ¿hay conflicto?
  │
  ├── Conflicto ALTO: bloquear, mostrar conflicto
  └── Sin conflicto: bauth.merge.templates → escribir en idn_role_template
       │
       ▼
     bauth.sync.reconcile → disparar sync KC+Tryton
```

### 3.3 Conexión al daemon — WebSocket directo

```dart
// services/jsonrpc_client.dart
class JsonRpcClient {
  // Conexión WebSocket directa al daemon bAuth.
  // Sin HTTP. Sin REST. Sin SSH tunnel.
  // El host y puerto vienen de config.json (embebido en el binario).
  static String host = '13.140.128.230';  // desde config.json
  static int port = 9450;                  // desde config.json
  static const timeout = Duration(seconds: 30);
  static const pingInterval = Duration(seconds: 30);

  WebSocketChannel? _channel;
  int _requestId = 0;

  /// Conecta vía WebSocket directo al daemon
  Future<void> connect() async {
    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    // Verificar health
    final health = await call('bauth.health.check');
    if (health['status'] != 'ok') throw ConnectionFailedException();
  }

  Future<JsonRpcResponse> call(String method, [Map<String, dynamic>? params]);
  Stream<JsonRpcNotification> subscribe(String event);
}
```

---

### 3.4 Observaciones de BOS — Lo que el IAM Installer necesita ver

**BOS es el gobernador del Context Plane (SBOS-049).** Sin BOS no hay ctx_id, sin ctx_id
no hay trazabilidad, sin trazabilidad no hay auditoría. El dashboard de bAuth debe exponer
al operador BOS la salud completa de la capa de identidad que BOS instaló.

#### Lo que BOS monitorea desde este dashboard:

| # | Métrica | Handler JSON-RPC | Umbral de alerta |
|---|---------|-----------------|:---:|
| BOS-01 | **Socket health** `/run/bos/bauth.sock` | `bauth.health.check` | Sin respuesta > 5s → 🔴 |
| BOS-02 | **Ctx_id activos** — sesiones vivas en `ses_context` | `bauth.context.plane` | < 10 activos → 🟡 (posible fuga) |
| BOS-03 | **Roles sincronizados** — KC + Tryton sin drift | `bauth.sync.status` | DRIFT > 0 → 🟡 |
| BOS-04 | **Átomos registrados** en `bos_atom_catalog` | `bauth.role.compute.mask` | < 1000 → 🟡 (catálogo incompleto) |
| BOS-05 | **Ficha bauth instalada** — versión, estado, health | `bos.ficha.status` (vía BOS) | DEGRADADA → 🔴 |
| BOS-06 | **PostgreSQL reachable** — pool_size, conexiones activas | `bauth.health.check` | pool agotado → 🔴 |
| BOS-07 | **Redis reachable** — cache BitMaskBundle TTL | `bauth.health.check` | miss rate > 20% → 🟡 |
| BOS-08 | **Uptime del daemon** — systemd watchdog | `bauth.health.check` | Restarts > 3/hora → 🔴 |

#### Protocolo de verificación cruzada BOS ↔ bAuth:

```
BOS instala bAuth → bAuth publica su health en el socket
     │                      │
     ▼                      ▼
BOS lee bauth.health   bAuth consume ctx_id que BOS creó
BOS monitorea drift    bAuth registra aud_event con ctx_id
BOS alerta si 🔴       bAuth notifica si DRIFT
```

**El dashboard debe tener una sección "Visión BOS"** con semaforización de estos 8 indicadores.
Es el equivalente visual de `bosctl ficha status sbos-bauth` pero en tiempo real.

---

## 4. MÉTRICAS Y KPIs — MONITOREO DE RENDIMIENTO

### 4.0 KPIs de Sistema (CPU, Memoria, Concurrencia)

Basado en las mejores prácticas de monitoreo de sistemas de autenticación (Keycloak Metrics,
Skycloak Analytics, Ory Kratos Dashboard), el dashboard debe exponer:

#### KPIs de rendimiento del daemon

| KPI | Fuente | Descripción | Umbral 🟢 | Umbral 🟡 | Umbral 🔴 |
|-----|--------|-------------|:---:|:---:|:---:|
| **CPU Usage** | `/proc` vía systemd | % CPU del proceso bauth | < 20% | 20-50% | > 50% |
| **Memory Usage** | `/proc` vía systemd | MB residentes del proceso | < 100 MB | 100-250 MB | > 250 MB |
| **Active Threads** | tokio runtime metrics | Tareas tokio concurrentes | < 100 | 100-500 | > 500 |
| **Response Time P50** | DomainRegistry | Mediana latencia evaluación | < 1ms | 1-10ms | > 10ms |
| **Response Time P95** | DomainRegistry | Latencia percentil 95 | < 5ms | 5-50ms | > 50ms |
| **Response Time P99** | DomainRegistry | Latencia percentil 99 | < 10ms | 10-100ms | > 100ms |
| **Pool Connections** | sqlx PgPool | Conexiones activas/total | < 60% | 60-85% | > 85% |
| **Redis Hit Rate** | Redis cache | Cache hit / total lookups | > 95% | 80-95% | < 80% |
| **Evaluaciones/seg** | DomainRegistry | FastPath + PolicyPath | > 100K | 10K-100K | < 10K |
| **Uptime** | systemd | Tiempo desde último start | > 7d | 1-7d | < 1d |
| **Restart Count** | systemd journal | Reinicios en últimas 24h | 0 | 1-2 | ≥ 3 |
| **Disk I/O** | /proc vía systemd | KB/s lectura/escritura BD | < 1MB/s | 1-5MB/s | > 5MB/s |

#### Widget de rendimiento en el dashboard

```
┌─── RENDIMIENTO DEL DAEMON ──────────────────────────────┐
│                                                          │
│  CPU ████████░░░░░░░░░░  18%          🟢                 │
│  RAM ████████████░░░░░░  62 MB        🟢                 │
│  HILOS ██░░░░░░░░░░░░░░  47 activos   🟢                 │
│                                                          │
│  ── LATENCIA DE EVALUACIÓN ──                            │
│  P50  ▏ 0.3ms  P95  ▏ 1.2ms  P99  ▏ 4.7ms              │
│                                                          │
│  ── CONEXIONES ──                                        │
│  PostgreSQL ████████░░  8/20 (40%)     🟢                │
│  Redis      ██░░░░░░░░  95.2% hit     🟢                 │
│                                                          │
│  ── RENDIMIENTO ──                                       │
│  Evaluaciones/seg  │  142,857  ▏  7ms total 12 dominios  │
│  Uptime            │  12d 4h 31m    🟢                    │
│  Reinicios (24h)   │  0              🟢                   │
│                                                          │
│  [📊 Ampliar métricas]  [🔔 Configurar alertas]          │
└──────────────────────────────────────────────────────────┘
```

### 4.1 KPIs de Usuarios y Sesiones

| KPI | Fuente | Descripción |
|-----|--------|-------------|
| **DAU** (Daily Active Users) | `bauth.user.list` + `last_login_at` | Usuarios únicos autenticados en 24h |
| **WAU** (Weekly Active Users) | `bauth.user.list` | Usuarios únicos autenticados en 7d |
| **MAU** (Monthly Active Users) | `bauth.user.list` | Usuarios únicos autenticados en 30d |
| **DAU/MAU Ratio** | Calculado | Engagement (stickiness). Ideal > 20% |
| **Total Users** | `bauth.user.list` | Total de usuarios registrados |
| **Active Sessions** | `ses_context` | Sesiones vivas ahora mismo |
| **Avg Session Duration** | `ses_context` | Duración promedio de sesión |
| **New Users (24h)** | `bauth.user.list` + `created_at` | Registros nuevos hoy |
| **Login Success Rate** | `aud_event` | % de logins exitosos |
| **Failed Logins (24h)** | `aud_event` | Intentos fallidos — señal de seguridad |

### 4.2 KPIs de Roles y Privilegios

| KPI | Fuente | Descripción |
|-----|--------|-------------|
| **Total Roles** | `idn_role_template` | Total de plantillas de rol |
| **Roles por Tier** | `idn_role_template.tier` | Distribución SU/SYS/BIZ_N1-N5/EXT |
| **Roles Publicados** | `idn_role_template.status='ACTIVO'` | Roles en producción |
| **Roles en Borrador** | `idn_role_template.status='BORRADOR'` | Roles sin publicar |
| **Átomos Asignados** | `bos_role_atom` | Total de átomos ↔ roles |
| **Conflictos SoD** | `fin_sod_rule` | Reglas de separación activas |
| **Roles con DRIFT** | `bauth.sync.status` | Roles desincronizados de KC+Tryton |
| **Herencia DAG** | `idn_role_closure` | Profundidad máxima del árbol |

### 4.3 KPIs de Seguridad (ISO 27001 A.8.15)

| KPI | Fuente | Descripción |
|-----|--------|-------------|
| **MFA Enrollment** | `ath_method` | % usuarios con MFA activo |
| **Phishing-Resistant Auth** | `ath_method` | % usuarios con WebAuthn/Passkey |
| **AAL3 Users** | `idn_role_template.loa_required` | Usuarios con LoA ≥ 3 |
| **Lockout Events (24h)** | `aud_event` | Cuentas bloqueadas por fuerza bruta |
| **Privilege Escalation Attempts** | `aud_event` | Intentos de acceso fuera de RolBitMask |
| **Geo-Anomalies** | `geo_fence` + `aud_event` | Accesos desde ubicaciones no autorizadas |
| **Credential Age > 90d** | `idn_credential` | Credenciales sin rotar |
| **Ghost Accounts** | `idn_user_template` + `last_login_at` | Usuarios sin actividad > 90d |

---

## 5. SEGUIMIENTO DE USUARIOS Y ROLES EN TIEMPO REAL

### 5.1 Panel de Usuarios Conectados/Desconectados

Basado en los patrones de dashboards profesionales investigados (Kratos Admin UI,
Checkpoint Infinity Identity, shadcn/ui OIDC Sessions Block, WSO2 Identity Server,
Beyond Identity Admin Console), el dashboard debe incluir:

```
┌─── USUARIOS Y SESIONES ─────────────────────────────────────────────┐
│                                                                      │
│  ┌─── INDICADORES ───────────────────────────────────────────────┐  │
│  │  👤 1,247      🔵 89         🔴 12         🟡 3               │  │
│  │  TOTAL USUARIOS  CONECTADOS     DESCONECTADOS   BLOQUEADOS      │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─── USUARIOS CONECTADOS AHORA ──────────────────────────────────┐  │
│  │  🔍 Filtrar: [________________]  │  Tenant: [Todos ▼]          │  │
│  │  ─────────────────────────────────────────────────────────────  │  │
│  │  Usuario          │ Rol           │ Tenant │ Sesión  │ Dispositivo │
│  │  ─────────────────┼───────────────┼────────┼─────────┼─────────────│
│  │  🟢 juan.perez    │ CAJERO        │ ORG-A  │ 3h 12m  │ 🖥️ Ubuntu   │
│  │  🟢 maria.lopez   │ SUPERVISOR    │ ORG-A  │ 1h 47m  │ 📱 Android  │
│  │  🟢 carlos.ruiz   │ GERENTE       │ ORG-B  │ 8h 01m  │ 🖥️ Windows  │
│  │  🟢 ana.torres    │ AUDITOR       │ ORG-A  │ 0h 23m  │ 🍎 macOS    │
│  │  ...                                                             │
│  │  [👁 Ver todos los 89 conectados]                                │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─── ÚLTIMOS DESCONECTADOS ──────────────────────────────────────┐  │
│  │  Usuario          │ Última sesión  │ Duración │ Cierre          │  │
│  │  ─────────────────┼────────────────┼──────────┼─────────────────│  │
│  │  🔴 pedro.salazar │ 14:22          │ 4h 15m   │ Timeout         │  │
│  │  🔴 lucia.mendoza │ 14:18          │ 2h 30m   │ Logout manual   │  │
│  │  🔴 diego.vargas  │ 14:05          │ 0h 05m   │ Credenciales err│  │
│  │  [📋 Historial completo de sesiones]                              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─── ACTIVIDAD DE LOGIN (24h) ───────────────────────────────────┐  │
│  │  ████████████████████████████░░░░░░░░  78% éxito               │  │
│  │  ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  12% fallo                │  │
│  │  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  10% bloqueado            │  │
│  │  ───────────────────────────────────────────                    │  │
│  │  00  02  04  06  08  10  12  14  16  18  20  22                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### 5.2 Panel de Roles Evaluados

```
┌─── ROLES EVALUADOS — ÚLTIMAS 24 HORAS ────────────────────────────┐
│                                                                    │
│  ┌─── DISTRIBUCIÓN POR TIER ──────────────────────────────────┐   │
│  │  Tier          │ Roles │ Usuarios │ Evaluaciones │ % Total  │   │
│  │  ──────────────┼───────┼──────────┼──────────────┼──────────│   │
│  │  SU            │     3 │       15 │      345,234 │    2.1 % │   │
│  │  SYS           │    12 │       47 │    4,567,890 │   27.8 % │   │
│  │  BIZ_N1        │    45 │      234 │    3,456,789 │   21.1 % │   │
│  │  BIZ_N2        │    89 │      567 │    5,678,901 │   34.6 % │   │
│  │  BIZ_N3        │    34 │      189 │    1,234,567 │    7.5 % │   │
│  │  BIZ_N4        │    12 │       89 │      567,890 │    3.5 % │   │
│  │  BIZ_N5        │     5 │       23 │      234,567 │    1.4 % │   │
│  │  EXT_N0        │     8 │      112 │      345,678 │    2.1 % │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌─── TOP ROLES MÁS EVALUADOS ─────────────────────────────────┐   │
│  │  # │ Rol                     │ Evaluaciones │ FastPath %     │   │
│  │  ──┼─────────────────────────┼──────────────┼────────────────│   │
│  │  1 │ CAJERO                  │  2,345,678   │ 99.8% 🟢       │   │
│  │  2 │ VENDEDOR                │  1,876,543   │ 99.5% 🟢       │   │
│  │  3 │ SUPERVISOR_TURNO        │  1,234,567   │ 98.2% 🟢       │   │
│  │  4 │ GERENTE_SUCURSAL        │    987,654   │ 95.1% 🟡       │   │
│  │  5 │ AUDITOR                 │    876,543   │ 99.9% 🟢       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌─── DOMINIOS MÁS DENEGADOS ───────────────────────────────────┐   │
│  │  Dominio        │ Denegaciones │ % del total │ Tendencia     │   │
│  │  ───────────────┼──────────────┼─────────────┼───────────────│   │
│  │  D3 Financiero  │       45,678 │      32.1 % │ 📈 +5% 🔴     │   │
│  │  D1 Lógico      │       34,567 │      24.3 % │ 📉 -2% 🟢     │   │
│  │  D4 Temporal    │       23,456 │      16.5 % │ ➡ 0%  🟡     │   │
│  │  D2 Físico      │       18,765 │      13.2 % │ 📈 +1% 🟡     │   │
│  │  D6 Geoespacial │       12,345 │       8.7 % │ 📉 -5% 🟢     │   │
│  └──────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### 5.3 Detalle de Sesión Individual (vista expandible)

Al hacer click en un usuario conectado, se expande:

```
┌─── DETALLE DE SESIÓN — juan.perez ────────────────────────────────┐
│                                                                    │
│  ┌─── DATOS DE IDENTIDAD ─────────────────────────────────────┐   │
│  │  UUID:      019abcd-1234-7abc-5678-efghijklmnop             │   │
│  │  Username:  juan.perez                                      │   │
│  │  Email:     juan.perez@org-a.com.bo                         │   │
│  │  Tenant:    ORG-A (sbos-1234567890)                         │   │
│  │  Empresa:   Comercializadora del Valle S.A.                 │   │
│  │  Sucursal:  Central — La Paz                                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌─── SESIÓN ACTUAL ──────────────────────────────────────────┐   │
│  │  ctx_id:    01J-abc123-def456-ghi789                        │   │
│  │  Inicio:    2026-06-27 08:15:32 BOT                         │   │
│  │  Duración:  3h 12m 47s                                      │   │
│  │  Expira:    2026-06-27 16:15:32 BOT                         │   │
│  │  LoA:       AAL2 (Password + TOTP)                          │   │
│  │  Dispositivo: Ubuntu 26.04 · Firefox 145                    │   │
│  │  IP:        192.168.1.45 (Internal) · 200.87.123.45 (Pub)   │   │
│  │  Ubicación: La Paz, Bolivia 🇧🇴 (confianza: HIGH)           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌─── ROLES ASIGNADOS ────────────────────────────────────────┐   │
│  │  ☑ CAJERO (BIZ_N1)       │ FastPath: 99.7% │ DENEG: 0.3%   │   │
│  │  ☐ SUPERVISOR (BIZ_N2)   │ (no activo)      │ —             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌─── ÚLTIMAS EVALUACIONES ───────────────────────────────────┐   │
│  │  Hora     │ Dominio │ Átomo              │ Resultado │ Lat   │   │
│  │  ─────────┼─────────┼────────────────────┼───────────┼───────│   │
│  │  11:27:45 │ D1      │ tryton.sale.write  │ PERMITIDO │ 0.3ns │   │
│  │  11:27:12 │ D3      │ fin.factura.emitir │ PERMITIDO │ 2.1ms │   │
│  │  11:26:58 │ D4      │ temp.horario.check │ PERMITIDO │ 1.8ms │   │
│  │  11:26:01 │ D1      │ tryton.party.read  │ PERMITIDO │ 0.3ns │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│  [🔒 Forzar cierre de sesión]  [📋 Ver auditoría completa]         │
└────────────────────────────────────────────────────────────────────┘
```

---

## 6. MODELO DE DATOS — MAPEO DDL → UI

### 4.1 Tablas DDL expuestas al desktop

| Schema | Tabla | Propósito | Pantalla |
|--------|-------|-----------|----------|
| `bauth` | `idn_role_template` | Plantillas de rol (JSONB 14 secciones) | Editor Rol |
| `bauth` | `idn_user_template` | Plantillas de usuario (JSONB 15 secciones) | Editor Usuario |
| `bauth` | `idn_tenant` | Tenants (multi-tenant) | Dashboard |
| `bauth` | `idn_role_closure` | Jerarquía DAG (herencia OR) | Árbol roles |
| `bauth` | `ath_policy_d1` … `ath_policy_d12` | Políticas por dominio | Pantalla Políticas |
| `bauth` | `ath_config_d1` … `ath_config_d12` | Configuraciones por dominio | Editor Dominio |
| `bauth` | `fin_limit` + `fin_approval_chain` + `fin_sod_rule` | Límites financieros, SoD | D3 Financiero |
| `bauth` | `ath_method` + `ath_auth_flow` + `ath_auth_flow_method` | Métodos y flujos de auth | D9 Credenciales |
| `bauth` | `fis_location` + `fis_access_zone` + `fis_device` | Zonas físicas, dispositivos | D2 Físico |
| `bauth` | `cal_schedule` + `cal_fiscal_year` | Horarios, calendario fiscal | D4 Temporal |
| `bauth` | `geo_fence` + `geo_trust_policy` | Geo-fencing, nivel de confianza | D6 Geoespacial |
| `bauth` | `net_ztna_policy` + `net_cidr_allowlist` | Zero Trust Networking | D7 Red |
| `bauth` | `ses_context` + `ses_context_switch` | Sesiones activas (ctx_id) | D8 Contexto |
| `bauth` | `idn_biometric_binding` | Bindings biométricos | D5 Biométrico |
| `bauth` | `idn_delegation_rule` | Reglas de delegación | D10 Delegación |
| `bauth` | `aud_event` + `aud_review` | Auditoría WORM, revisiones | D11 Auditoría |
| `bauth` | `blk_anchor` + `blk_merkle_leaf` | Anclajes blockchain | D12 Blockchain |
| `bos` | `bos_atom_catalog` | Catálogo global de átomos | Todo el árbol |
| `bos` | `bos_role_atom` | Asignaciones rol ← átomos | FastPath |
| `bglobal` | `global_country` + `global_currency` | Catálogos ISO | D3, D6 |

### 4.2 Las 14 secciones del RolTemplate v6.0

```json
{
  "logical_access":     { "zones": [...], "apps": [...], "modules": [...] },
  "physical_access":    { "buildings": [...], "floors": [...], "zones": [...] },
  "financial":          { "transaction_types": [...], "limits": {...}, "sod_rules": [...] },
  "temporal":           { "schedules": [...], "holidays": [...], "max_session": "8h" },
  "biometric":          { "required_loa": 3, "step_up_enabled": true },
  "geospatial":         { "allowed_countries": ["BO"], "fences": [...] },
  "network":            { "cidrs": [...], "trust_level": 70, "ztna_enabled": true },
  "context":            { "max_concurrent": 3, "ctx_ttl": "8h" },
  "credentials":        { "methods": [...], "flows": [...], "alternatives": [...], "policies": [...] },
  "delegation":         { "max_days": 7, "allowed_target_roles": [...] },
  "audit":              { "level": "full", "review_interval_days": 90 },
  "blockchain":         { "anchor_enabled": false, "network": "besu-qbft" },
  "security":           { "mfa_required": true, "phishing_resistant": true },
  "compliance":         { "frameworks": ["ISO27001", "NIST800-53", "PCI-DSS"], "retention_days": 2555 }
}
```

---

## 7. PLAN DE DESARROLLO — 8 FASES (AMPLIADO)

### FASE 0 — ESQUELETO Y CONEXIÓN (2-3 días)

**Objetivo:** Proyecto Flutter compilando. Conexión JSON-RPC viva.

| # | Tarea | Archivos |
|---|-------|----------|
| 0.1 | `flutter create` + `pubspec.yaml` con dependencias | `pubspec.yaml` |
| 0.2 | Configurar `ShadApp` + tema ForUI (colores, tipografía, espaciado) | `main.dart`, `app.dart`, `forui_tokens.dart` |
| 0.3 | Implementar `JsonRpcClient` (WebSocket → Unix socket `/run/bos/bauth.sock`) | `jsonrpc_client.dart` |
| 0.4 | `bauth.health.check` — verificar conectividad con daemon | `health_provider.dart` |
| 0.5 | GoRouter con rutas vacías para todas las pantallas | `app_router.dart` |
| 0.6 | Layout base: `NavigationSidebar` + área de contenido + breadcrumb | `dashboard_screen.dart` |

**DoD:** `flutter run -d linux` muestra sidebar + "Conectado a bAuth vX.Y.Z" en el dashboard.

---

### FASE 1 — DASHBOARD DE SALUD (3-4 días)

**Objetivo:** Panel principal con métricas de los 12 dominios.

| # | Tarea | Archivos |
|---|-------|----------|
| 1.1 | Provider `HealthMetrics` → `bauth.context.evaluate` (12 dominios) | `health_provider.dart` |
| 1.2 | Gráfico radar: 12 dominios, estado actual (PERMITIDO/DENEGADO/PENDIENTE) | `domain_health_radar.dart` |
| 1.3 | Gráfico barras: latencia por dominio (Fast-Path vs Policy-Path) | `domain_latency_bar.dart` |
| 1.4 | Cards de resumen: total roles, usuarios activos, sync status | `dashboard_screen.dart` |
| 1.5 | Semaforización: verde/ámbar/rojo por dominio | `status_badge.dart` |
| 1.6 | `bauth.sync.status` — estado de sincronización KC+Tryton | `sync` provider |

**DoD:** Dashboard muestra 12 dominios con radar, barras y semáforos. Datos reales desde VPS.

---

### FASE 1.5 — KPIs, MÉTRICAS Y SEGUIMIENTO DE USUARIOS (4-5 días)

**Objetivo:** Panel completo de métricas de rendimiento, KPIs de negocio, usuarios
conectados/desconectados y roles evaluados en tiempo real.

| # | Tarea | Archivos |
|---|-------|----------|
| 1.5.1 | Provider `SystemMetrics` — CPU, memoria, hilos, uptime desde `bauth.health.check` + systemd | `providers/metrics_provider.dart` |
| 1.5.2 | Widget `PerformancePanel` — barras CPU/RAM, histograma P50/P95/P99 | `widgets/charts/performance_panel.dart` |
| 1.5.3 | Widget `ConnectionPoolGauges` — PostgreSQL pool, Redis hit rate | `widgets/charts/connection_gauges.dart` |
| 1.5.4 | Provider `UserSessions` — `ses_context` activas + `bauth.user.list` con `last_login_at` | `providers/session_provider.dart` |
| 1.5.5 | Panel "Usuarios Conectados Ahora" — tabla en tiempo real con filtro por tenant | `screens/dashboard/connected_users_panel.dart` |
| 1.5.6 | Panel "Usuarios Desconectados" — última sesión, motivo de cierre | `screens/dashboard/disconnected_users_panel.dart` |
| 1.5.7 | Panel "Roles Evaluados (24h)" — distribución por tier, top 5 roles, dominios más denegados | `screens/dashboard/roles_evaluated_panel.dart` |
| 1.5.8 | KPI cards superiores: DAU, WAU, MAU, DAU/MAU, Active Sessions, Login Success Rate, Failed Logins | `screens/dashboard/kpi_cards.dart` |
| 1.5.9 | Gráfico "Actividad de Login (24h)" — barras apiladas éxito/fallo/bloqueo por hora | `widgets/charts/login_activity_chart.dart` |
| 1.5.10 | Detalle de sesión individual — click en usuario expande datos de identidad, roles, últimas evaluaciones | `screens/dashboard/session_detail_sheet.dart` |
| 1.5.11 | Provider `SecurityKPIs` — MFA enrollment, phishing-resistant %, ghost accounts, credential age | `providers/security_provider.dart` |
| 1.5.12 | Panel "Visión BOS" — 8 indicadores de salud del daemon desde la perspectiva del IAM Installer | `screens/dashboard/bos_vision_panel.dart` |

**DoD:** Dashboard completo con 12 KPI cards, tabla de usuarios conectados en tiempo real,
roles evaluados, métricas de rendimiento, seguridad y panel Visión BOS.

---

### FASE 2 — LISTA DE ROLES Y USUARIOS (3-4 días)

**Objetivo:** CRUD básico de lectura. Tablas con filtros.

| # | Tarea | Archivos |
|---|-------|----------|
| 2.1 | Provider `RoleList` → `bauth.role.template.list` con filtros (tier, status) | `role_provider.dart` |
| 2.2 | `pluto_grid` con columnas: nombre, tier, status, LoA, MFA, versión, padre | `role_list_screen.dart` |
| 2.3 | Filtros: por tier (SU, SYS, BIZ_N1-N5, EXT_N0, M2M, VISITANTE), por status | `role_list_screen.dart` |
| 2.4 | Provider `UserList` → `bauth.user.list` | `user_provider.dart` |
| 2.5 | `pluto_grid` con columnas: username, email, tenant, status, roles, last_login | `user_list_screen.dart` |
| 2.6 | Navegación: click en rol → `role_editor_screen`; click en usuario → `user_editor_screen` | `app_router.dart` |

**DoD:** Tablas de roles y usuarios con filtros, ordenables, paginadas. Datos reales desde VPS.

---

### FASE 3 — EDITOR DE ROL (ÁRBOL JERÁRQUICO) (6-8 días)

**Objetivo:** El componente central. Árbol D1-D12 expandible/colapsable con checkboxes.

| # | Tarea | Archivos |
|---|-------|----------|
| 3.1 | `DomainTreeBuilder` — construir `TreeNodeData` desde RolTemplate JSONB v6.0 | `domain_tree.dart` |
| 3.2 | Widget `DomainTree` — renderizado recursivo con `TreeNodeData` + `Accordion` | `widgets/tree/domain_tree.dart` |
| 3.3 | Nodos: `tree_node_domain.dart` → `tree_node_app.dart` → `tree_node_module.dart` → `tree_node_verb.dart` | `widgets/tree/*.dart` |
| 3.4 | Checkboxes: marcar/desmarcar verbos (átomos). Heredar a nodos padres. | `widgets/tree/*.dart` |
| 3.5 | `tree_search.dart` — filtro de nodos por texto (🔍 "sale_pos" → expande y resalta) | `widgets/tree/tree_search.dart` |
| 3.6 | Panel lateral derecho: resumen de secciones configuradas, átomos asignados, conflictos SoD | `role_editor_screen.dart` |
| 3.7 | Formularios inline para cada sección (D1-D12) al hacer click en nodo | `widgets/forms/section_*.dart` |
| 3.8 | Guardar → serializar árbol a JSONB → `bauth.template.validate` → `bauth.merge.templates` | `role_editor_screen.dart` |

**DoD:** Editor de rol completamente funcional. Árbol navegable, checkboxes operativos, guardar valida.

---

### FASE 4 — EDITOR DE USUARIO Y POLÍTICAS (4-5 días)

**Objetivo:** Editor de UserTemplate + pantalla de políticas de autenticación.

| # | Tarea | Archivos |
|---|-------|----------|
| 4.1 | Editor de usuario: datos de identidad, asignación de roles, dispositivos, credenciales | `user_editor_screen.dart` |
| 4.2 | Selector de rol: popup con árbol de roles disponibles (buscar, filtrar, asignar) | `widgets/forms/role_selector.dart` |
| 4.3 | Flujo onboarding: IAL1 → IAL2 → IAL3 con verificación de identidad | `user_editor_screen.dart` |
| 4.4 | Pantalla de políticas: grid de 14 políticas × 12 dominios | `policy_screen.dart` |
| 4.5 | Editor de políticas: activar/desactivar, configurar umbrales, reglas | `widgets/forms/policy_editor.dart` |
| 4.6 | `bauth.policy.evaluate` — simular evaluación de política contra usuario/rol | `policy_screen.dart` |

**DoD:** CRUD de usuarios con asignación de roles. Políticas visibles y editables.

---

### FASE 5 — SINCRONIZACIÓN Y AUDITORÍA (3-4 días)

**Objetivo:** Panel de sync KC+Tryton + visor de auditoría ISO 27001.

| # | Tarea | Archivos |
|---|-------|----------|
| 5.1 | Panel de sync: estado por tenant, roles sincronizados vs drift | `sync_screen.dart` |
| 5.2 | `bauth.sync.reconcile` — disparar reconciliación manual | `sync_screen.dart` |
| 5.3 | Timeline de eventos de sincronización (WebSocket stream) | `sync_screen.dart` |
| 5.4 | Visor de auditoría: tabla `aud_event` con filtros (fecha, usuario, acción, resultado) | `audit_screen.dart` |
| 5.5 | Export JSON de eventos de auditoría | `audit_screen.dart` |
| 5.6 | `bauth.domain.audit` — DomainEvaluationAudit: trazabilidad de cada decisión | `audit_screen.dart` |

**DoD:** Sync y auditoría funcionales. Eventos trazables con export.

---

### FASE 6 — COMERCIAL, FIRMA DIGITAL Y CIERRE (3-4 días)

**Objetivo:** Funcionalidades comerciales, firma digital, hardening y pulido.

| # | Tarea | Archivos |
|---|-------|----------|
| 6.1 | Panel comercial: productos D12 (anclaje, liquidación, wallet) | `screens/commercial/` |
| 6.2 | `bauth.sign.internal` — firma digital Ed25519 visible con verificación | `screens/sign/` |
| 6.3 | `bauth.idp.external` — configuración de IdP externo (OIDC Discovery, SAML) | `screens/idp/` |
| 6.4 | `bauth.blockchain.panel` — lotes, verificar, publicar, liquidaciones | `screens/blockchain/` |
| 6.5 | Responsive: probar todas las pantallas en mobile (pixel 7, tablet) | Todas |
| 6.6 | Diálogos de confirmación governance dual-control (texto exacto + timeout 60min) | `confirm_dialog.dart` |
| 6.7 | `flutter test` — tests de providers, modelos y widgets clave | `test/` |
| 6.8 | Build release: `flutter build linux --release` + `flutter build windows --release` | `Makefile` |

**DoD:** Feature-complete. Compila para Linux y Windows release. Tests pasan.

---

## 8. RIESGOS Y MITIGACIONES

| Riesgo | Prob | Impacto | Mitigación |
|--------|:---:|:---:|---|
| `tf_shadcn_flutter` API inestable (pre-1.0) | Media | Alto | Fijar versión exacta en `pubspec.lock`. Probar cada upgrade en branch. |
| `pluto_grid` no compatible con shadcn | Baja | Medio | Fallback: `ShadTable` nativo + implementar sort/filter manual |
| Daemon no accesible por firewall | Baja | Alto | El daemon expone puerto TCP 9450. Asegurar en el firewall de la VPS. |
| Árbol con 5000+ nodos → rendimiento | Media | Medio | Virtual scroll + lazy loading de hijos. Solo expandir 1 nivel a la vez. |
| DDL cambia durante el desarrollo | Media | Medio | Los modelos usan JSONB → schemaless en la UI. Cambios de columna no rompen. |
| WebSocket se desconecta | Alta | Bajo | Reconexión automática con backoff exponencial. Cache TTL 30s en providers. |

---

## 9. CRITERIOS DE ACEPTACIÓN (DoD por fase)

Toda fase debe cumplir:
- [ ] `flutter build linux --release` compila sin errores
- [ ] `flutter test` pasa todos los tests nuevos y existentes
- [ ] Conexión real contra VPS (13.140.128.230) verificada
- [ ] Código documentado en español (DOC-SBOS-001 N3)
- [ ] Widgets ≤ 200 líneas, funciones ≤ 50 líneas

---

## 10. COMANDOS RÁPIDOS

```bash
# Crear proyecto
cd BauthAgent/src/desktop
flutter create --project-name bauth_desktop --org bo.skull.sbos .

# Desarrollo
flutter run -d linux          # Ejecutar en Linux
flutter run -d windows        # Ejecutar en Windows
flutter run -d macos          # Ejecutar en macOS

# Tests
flutter test                  # Todos los tests
flutter test --update-goldens # Actualizar golden files

# Build release
flutter build linux --release
flutter build windows --release

# El daemon bAuth escucha en puerto 9450 — WebSocket directo, sin túnel
```

---

## 11. INVENTARIO DE HANDLERS JSON-RPC POR PANTALLA

| Pantalla | Método | Estructura del params |
|----------|--------|----------------------|
| Dashboard | `bauth.health.check` | `{}` |
| Dashboard | `bauth.sync.status` | `{"tenant_id": "..."}` |
| Dashboard | `bauth.context.evaluate` | `{"ctx_id": "...", "atom_position": N}` |
| Lista Roles | `bauth.role.template.list` | `{"tier": "BIZ_N1", "status": "ACTIVO", "limit": 50}` |
| Lista Roles | `bauth.role.template.get` | `{"id": "uuid"}` |
| Editor Rol | `bauth.role.compute.mask` | `{"template_id": "uuid"}` |
| Editor Rol | `bauth.template.validate` | `{"template": {...}}` |
| Editor Rol | `bauth.inheritance.compute` | `{"role_id": "uuid"}` |
| Editor Rol | `bauth.inheritance.check` | `{"role_id": "uuid", "child_id": "uuid"}` |
| Editor Rol | `bauth.sod.check` | `{"role_id": "uuid", "atom_positions": [...]}` |
| Editor Rol | `bauth.merge.templates` | `{"role_id": "uuid", "domain_sections": {...}}` |
| Lista Usuarios | `bauth.user.list` | `{"limit": 100, "offset": 0, "tenant_id": "..."}` |
| Editor Usuario | `bauth.user.list` | `{"uuid": "uuid"}` |
| Políticas | `bauth.policy.evaluate` | `{"user_id": "uuid", "resource": "...", "action": "..."}` |
| Políticas | `bauth.template.validate` | `{"template": {...}}` |
| Sync | `bauth.sync.reconcile` | `{"tenant_id": "...", "force": true}` |
| Auditoría | `bauth.domain.audit` | `{"from": "ISO", "to": "ISO", "limit": 500}` |
| Auditoría | `bauth.context.plane` | `{"ctx_id": "uuid"}` |
| Acceso | `bauth.access.evaluate` | `{"user_id": "uuid", "resource": "...", "action": "..."}` |
| Comercial | `bauth.commercial` | `{"product": "...", "action": "..."}` |
| Firma | `bauth.sign.internal` | `{"payload": "...", "key_id": "..."}` |
| Dominios | `bauth.domain.*` | `{"atom_position": N, "ctx_id": "..."}` |

---

## 12. CRONOGRAMA VISUAL DE FASES

```
F0   ██ Esqueleto (2-3d)          flutter create + JSON-RPC vivo
F1   ██ Dashboard (3-4d)          Radar 12 dominios + métricas base
F1.5 ███ KPIs + Usuarios (4-5d)   ★ MÉTRICAS — CPU/RAM/concurrencia + tracking real-time
F2   ██ Listas (3-4d)             PlutoGrid roles + usuarios
F3   ██████ Editor Árbol (6-8d)   ★ CORAZÓN — TreeNodeData D1-D12
F4   ████ Usuarios/Políticas (4-5d) Editor User + policy grid
F5   ███ Sync/Auditoría (3-4d)    Reconcile + ISO 27001
F6   ███ Cierre (3-4d)            Comercial, firma digital, release
──────────────────────────────────────────────────────────────
     TOTAL: 28-37 días (8 fases, 60+ tareas atómicas)
```

---

## 13. REFERENCIAS INTERNACIONALES

El diseño de este dashboard se basa en el análisis de los siguientes sistemas
de administración de identidad profesionales investigados:

| Sistema | Lección aplicada al dashboard bAuth |
|---------|--------------------------------------|
| **Ory Kratos Admin UI** | Dashboard con analytics: user growth, active sessions, verification rates, system health |
| **shadcn/ui OIDC Sessions Block** | Filas expandibles con IP, user agent, scopes, token expiry countdown |
| **Keycloak Admin Console** | Métricas de sesiones activas, eventos de login, distribución por realm |
| **LoginRadius B2B Admin Portal** | 5 widgets modulares: Org Details, Users, Roles, Connections, Security |
| **Beyond Identity Admin Console** | Overview: active users, authentications, devices con time range toggle |
| **Symantec IDSP 4.0** | Risk policies, FIDO2 enrollment, service account visibility |
| **WSO2 Identity Server** | Login attempts over time, Top 10 providers/users, drill-down en charts |
| **Checkpoint Infinity Identity** | Two-table session layout: active sessions + detail for selected row |
| **BOS-REPAIR Dashboard** | Semaforización verde/ámbar/rojo, health checks automatizados, build + race detector |

**Patrones comunes adoptados:**
- KPI cards superiores (activos, sesiones, intentos, éxito/fallo)
- Time-series line/area charts para actividad de login
- Tablas expandibles con detalle de sesión (IP, dispositivo, user agent, MFA, geo)
- Date range pickers (1h, 24h, 7d, 30d, personalizado)
- Semaforización verde/ámbar/rojo con umbrales configurables
- Dark/light theme (heredado de shadcn_flutter)
- Sesiones con revocación manual desde dashboard
- Search/filtro global por usuario, tenant, IP, servicio

---

## 14. DESPLIEGUE Y DISTRIBUCIÓN — INSTALADORES AUTOCONTENIDOS

### 14.0 Principio Cero-Configuración (ADR-044 aplicado al desktop)

```
EL USUARIO:
  1. Descarga el instalador de su sistema operativo
  2. Lo ejecuta (doble click o comando)
  3. La aplicación se abre — YA conectada al servidor VPS

NADA MÁS. Sin instalar Flutter. Sin instalar Dart. Sin dependencias del sistema.
Sin configurar IPs. Sin editar archivos de configuración. Sin terminal.
```

**El instalador contiene TODO:**
- Binario Flutter compilado nativo (AOT, release mode)
- Librerías del sistema empaquetadas (GTK, glibc, etc.)
- Configuración de conexión VPS pre-cargada
- Certificados TLS para validar el socket
- Icono, nombre, metadatos del sistema operativo

### 14.1 Formatos de distribución por sistema operativo

**Prioridad Linux:** Ubuntu (`.deb`) y Fedora (`.rpm`) son **obligatorios de primer nivel.**
Ambos se compilan y publican en cada release. `.AppImage` es el comodín universal.

| SO | Formato primario | Formato secundario | Universal | Tamaño est. |
|----|------------------|-------------------|-----------|:---:|
| **Ubuntu** (24.04/26.04) | `.deb` ✅ | — | `.AppImage` | ~45 MB |
| **Fedora** (41/42) | `.rpm` ✅ | — | `.AppImage` | ~45 MB |
| **Windows** (10/11) | `.msi` | `.exe` portable | — | ~55 MB |
| **macOS** (14/15) | `.dmg` | `.app` bundle | — | ~50 MB |
| **Android** | `.apk` | `.aab` (Play Store) | — | ~35 MB |
| **iOS** | `.ipa` | TestFlight | — | ~40 MB |

**Por qué `.deb` + `.rpm` + `.AppImage` (3 formatos Linux):**

| Formato | Ubuntu | Fedora | openSUSE | Arch | NixOS | Sin root |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|
| `.deb` | ✅ nativo | ❌ | ❌ | ❌ | ❌ | Requiere |
| `.rpm` | ❌ | ✅ nativo | ✅ nativo | ❌ | ❌ | Requiere |
| `.AppImage` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **No requiere** |

`AppImage` es el salvavidas: corre en cualquier distro sin instalación, sin root, sin dependencias.
Pero `.deb` y `.rpm` dan integración nativa (menú, actualizaciones, desinstalación limpia).

### 14.2 Flujo de compilación automatizada (GitHub Actions CI/CD)

```yaml
# .github/workflows/bauth-desktop-release.yml
name: Build bAuth Desktop Installers

on:
  push:
    tags: ['desktop-v*']
  workflow_dispatch:

jobs:
  # ── LINUX: UBUNTU .deb ──────────────────────────
  build-linux-deb:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.1' }
      - run: sudo apt-get install -y libgtk-3-dev libappindicator3-dev libsecret-1-dev
      - run: flutter pub get
      - run: flutter build linux --release
      - run: |
          # Empaquetar .deb
          mkdir -p dist/bauth-desktop_1.0.0/DEBIAN
          mkdir -p dist/bauth-desktop_1.0.0/usr/local/bin
          mkdir -p dist/bauth-desktop_1.0.0/usr/share/applications
          mkdir -p dist/bauth-desktop_1.0.0/usr/share/icons
          cp -r build/linux/x64/release/bundle/* dist/bauth-desktop_1.0.0/usr/local/bin/
          cp assets/config.json dist/bauth-desktop_1.0.0/usr/local/bin/data/flutter_assets/
          cp assets/icons/bauth.png dist/bauth-desktop_1.0.0/usr/share/icons/
          dpkg-deb --build dist/bauth-desktop_1.0.0
      - uses: actions/upload-artifact@v4
        with: { name: linux-deb, path: dist/*.deb }

  # ── LINUX: FEDORA .rpm ──────────────────────────
  build-linux-rpm:
    runs-on: ubuntu-26.04
    container: fedora:42
    steps:
      - uses: actions/checkout@v4
      - run: dnf install -y flutter gtk3-devel libsecret-devel rpm-build
      - run: flutter pub get
      - run: flutter build linux --release
      - run: |
          # Empaquetar .rpm
          mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
          cp installer/linux/bauth-desktop.spec ~/rpmbuild/SPECS/
          cp -r build/linux/x64/release/bundle ~/rpmbuild/BUILD/bauth-desktop
          cp assets/config.json ~/rpmbuild/BUILD/bauth-desktop/data/flutter_assets/
          rpmbuild -bb ~/rpmbuild/SPECS/bauth-desktop.spec
      - uses: actions/upload-artifact@v4
        with: { name: linux-rpm, path: ~/rpmbuild/RPMS/x86_64/*.rpm }

  # ── LINUX: UNIVERSAL .AppImage ──────────────────
  build-linux-appimage:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: sudo apt-get install -y libgtk-3-dev libappindicator3-dev
      - run: flutter pub get
      - run: flutter build linux --release
      - run: |
          # Empaquetar .AppImage con linuxdeploy
          wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
          chmod +x linuxdeploy-x86_64.AppImage
          cp assets/config.json build/linux/x64/release/bundle/data/flutter_assets/
          ./linuxdeploy-x86_64.AppImage --appdir AppDir --executable build/linux/x64/release/bundle/bauth_desktop \
            --desktop-file installer/linux/bauth-desktop.desktop \
            --icon-file assets/icons/bauth.png --output appimage
      - uses: actions/upload-artifact@v4
        with: { name: linux-appimage, path: '*.AppImage' }

  # ── WINDOWS ──────────────────────────────────────
  build-windows:
    runs-on: windows-2025
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.1' }
      - run: flutter pub get
      - run: flutter build windows --release
      - run: |
          # Empaquetar .msi con WiX Toolset
          & "C:\Program Files (x86)\WiX Toolset v4\bin\wix.exe" build installer.wxs
      - uses: actions/upload-artifact@v4
        with: { name: windows-msi, path: dist/*.msi }

  # ── macOS ────────────────────────────────────────
  build-macos:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.1' }
      - run: flutter pub get
      - run: flutter build macos --release
      - run: |
          # Crear .dmg
          create-dmg --volname "bAuth Desktop" --window-pos 200 120 \
            --window-size 800 400 --icon-size 100 \
            --icon "bauth_desktop.app" 200 190 \
            --hide-extension "bauth_desktop.app" \
            --app-drop-link 600 185 \
            "dist/bauth-desktop-1.0.0.dmg" "build/macos/Build/Products/Release/bauth_desktop.app"
      - uses: actions/upload-artifact@v4
        with: { name: macos-dmg, path: dist/*.dmg }

  # ── RELEASE UNIFICADA ───────────────────────────
  create-release:
    needs: [build-linux-deb, build-linux-rpm, build-linux-appimage, build-windows, build-macos]
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/download-artifact@v4
      - name: Crear GitHub Release con todos los instaladores
        uses: softprops/action-gh-release@v2
        with:
          name: "bAuth Desktop v${{ github.ref_name }}"
          body: |
            ## 🖥️ bAuth Desktop — Identity Control Plane SBOS
            **Instaladores autocontenidos. Descargar → ejecutar → conectado.**
            
            ### Linux
            | Distro | Formato | Instalación |
            |--------|---------|-------------|
            | **Ubuntu** 24.04/26.04 | `.deb` | `sudo dpkg -i bauth-desktop_*.deb` |
            | **Fedora** 41/42 | `.rpm` | `sudo dnf install bauth-desktop-*.rpm` |
            | **Cualquier distro** | `.AppImage` | `chmod +x *.AppImage && ./*.AppImage` |
            
            ### Otros sistemas
            | SO | Formato |
            |----|---------|
            | Windows 10/11 | `.msi` — doble click |
            | macOS 14/15 | `.dmg` — arrastrar a Applications |
          draft: false
          prerelease: false
          files: |
            linux-deb/*.deb
            linux-rpm/*.rpm
            linux-appimage/*.AppImage
            windows-msi/*.msi
            macos-dmg/*.dmg
```

### 14.3 Conexión directa — Sin SSH, sin HTTP, sin intermediarios

**El daemon bAuth expone JSON-RPC 2.0 + WebSocket en el puerto 9450 del host.**
El instalador ya sabe a qué IP y puerto conectarse. Nada de HTTP, nada de REST,
nada de SSH tunnel. WebSocket puro.

El archivo `config.json` se **empaqueta dentro del binario** como asset de Flutter:

```json
{
  "version": "1.0.0",
  "daemon": {
    "host": "13.140.128.230",
    "port": 9450,
    "protocol": "websocket",
    "path": "/"
  },
  "connection": {
    "timeout_seconds": 10,
    "reconnect_backoff_ms": [100, 500, 1000, 5000, 15000],
    "max_retries": 5,
    "ping_interval_seconds": 30
  },
  "update": {
    "check_url": "https://github.com/SISTEMASSKULL/bos-install/releases/latest",
    "auto_check_hours": 24
  }
}
```

**Arquitectura de conexión directa:**

```
┌──────────────────────────┐                         ┌──────────────────────────┐
│  Desktop (Windows/       │  WebSocket              │  VPS 13.140.128.230      │
│  Linux/macOS)            │  ws://13.140.128.230:   │                          │
│                          │  9450                    │  puerto 9450             │
│  App ── JSON-RPC 2.0 ───┼─────────────────────────┼── 🧠 bauth (systemd)     │
│                          │  (TLS opcional)          │                          │
│                          │                         │  /run/bos/bauth.sock     │
│                          │  Sin HTTP               │  (interface dual ADR-020)│
│                          │  Sin SSH tunnel         │                          │
│                          │  Sin REST               │                          │
└──────────────────────────┘                         └──────────────────────────┘
```

La app al iniciar:
1. Lee `config.json` desde sus assets (embebido en el binario)
2. Abre WebSocket a `ws://13.140.128.230:9450`
3. Envía JSON-RPC 2.0 `bauth.health.check`
4. El usuario ve: "Conectado a bAuth v3.0.0 ✅"

**El instalador de cada SO ya contiene la IP y puerto correctos.** Si cambian,
se actualiza el `config.json` y se publica una nueva release. Nada que el usuario
tenga que configurar.

### 14.4 Seguridad de la conexión

**La conexión es WebSocket directo al daemon.** El daemon bAuth ya maneja
autenticación y autorización en cada llamada JSON-RPC. El desktop no necesita
credenciales de sistema ni SSH.

| Capa | Responsabilidad |
|------|----------------|
| **Transporte** | WebSocket sobre TCP (puerto 9450). TLS opcional para entornos expuestos. |
| **Autenticación** | Cada request JSON-RPC incluye `auth_token` en los params. El daemon valida. |
| **Autorización** | El daemon aplica BitMask Dual + 12 dominios. El desktop solo muestra lo que el daemon permite. |
| **Confianza** | En red local (VPS + LAN), sin TLS. En WAN/Internet, con TLS + certificado. |

**El desktop no almacena credenciales del sistema operativo.**
El token de sesión viaja en memoria y expira con la sesión del daemon.

### 14.5 Estructura final del proyecto

```
BauthAgent/
├── src/                          ← Daemon Rust (existente)
│   ├── main.rs
│   ├── domain/
│   ├── server/
│   └── ...
│
├── desktop/                      ← Dashboard Flutter (NUEVO)
│   ├── PLAN-DESKTOP-BAUTH.md     ← Este documento
│   ├── pubspec.yaml
│   ├── lib/                      ← Código Dart
│   ├── assets/
│   │   ├── config.json           ← Configuración VPS (embebida en binario)
│   │   ├── icons/                ← Iconos de la aplicación
│   │   └── fonts/                ← Tipografía SBOS (ForUI)
│   ├── installer/                ← Scripts de empaquetado por SO
│   │   ├── linux/
│   │   │   ├── control           ← DEBIAN/control (.deb)
│   │   │   ├── postinst          ← Script post-instalación (.deb)
│   │   │   ├── bauth-desktop.spec ← RPM spec (.rpm)
│   │   │   └── bauth-desktop.desktop ← Desktop entry (.AppImage)
│   │   ├── windows/
│   │   │   └── installer.wxs     ← WiX Toolset
│   │   └── macos/
│   │       └── entitlements.plist
│   ├── .github/workflows/
│   │   └── bauth-desktop-release.yml  ← CI/CD
│   └── Makefile                  ← build, test, package, deploy
```

### 14.6 Comandos de empaquetado

```bash
# Desarrollo local
cd BauthAgent/src/desktop
flutter run -d linux          # Ejecutar conectado a VPS real

# Compilación release
make build-linux              # flutter build linux --release
make build-windows            # flutter build windows --release
make build-macos              # flutter build macos --release

# Empaquetado de instaladores
make package-linux-deb        # Genera .deb (Ubuntu 24.04/26.04)
make package-linux-rpm        # Genera .rpm (Fedora 41/42)
make package-linux-appimage   # Genera .AppImage (cualquier distro)
make package-windows-msi      # Genera .msi (Windows 10/11)
make package-macos-dmg        # Genera .dmg (macOS 14/15)

# Release completa (local o CI)
make release VERSION=1.0.0    # Compila + empaqueta + firma + publica

# Verificación post-compilación
make verify-release           # Prueba que el .deb/.msi/.dmg funciona
```

### 14.7 DoD de despliegue

- [ ] `.deb` instalable en **Ubuntu 24.04 y 26.04** con `sudo dpkg -i bauth-desktop_*.deb` — entrada en menú, icono, desinstalación limpia
- [ ] `.rpm` instalable en **Fedora 41 y 42** con `sudo dnf install bauth-desktop-*.rpm` — integración nativa con GNOME Software
- [ ] `.AppImage` ejecutable en **cualquier distro Linux** con `chmod +x` — sin root, sin instalación, portable
- [ ] `.msi` instalable en **Windows 10 y 11** con doble click, aparece en menú Inicio, desinstalable desde Configuración
- [ ] `.dmg` montable en **macOS 14 y 15**, arrastrar a Applications funciona, Gatekeeper no bloquea
- [ ] Al abrir la app en **cualquier SO**: conexión WebSocket directa → dashboard vivo en < 5s
- [ ] La app se actualiza automáticamente (chequea GitHub Releases cada 24h, descarga e instala el nuevo paquete nativo)
- [ ] No requiere Flutter, Dart, Java, ni ninguna dependencia instalada por el usuario
- [ ] Tamaño del instalador < 60 MB en todas las plataformas
- [ ] Probado en: Ubuntu 26.04, Fedora 42, Windows 11, macOS 15

---

## 15. VACÍOS DETECTADOS — LO QUE FALTA DEFINIR

Investigación internacional completada. Estos son los temas que un dashboard profesional
de administración de identidad DEBE cubrir y que aún no estaban en el plan:

---

### 15.1 Firma de Código y Notarización

Sin firma, los sistemas operativos bloquean la instalación. Es requisito para producción.

| Plataforma | Tecnología | Proceso |
|-----------|-----------|---------|
| **macOS** | `codesign` + `xcrun notarytool` | Developer ID Certificate (Apple, $99/año) → firmar .app → notarizar → grapar ticket → empaquetar .dmg |
| **Windows** | `signtool` (Windows SDK) | OV/EV Code Signing Certificate (DigiCert/Sectigo, ~$300/año) → firmar .exe y .dll → firmar .msi |
| **Linux** | GPG + `debsign` / `rpmsign` | GPG key pair → firmar paquete .deb/.rpm. Sin notarización. |

**Impacto si no se hace:**
- macOS: Gatekeeper bloquea con "no se puede verificar el desarrollador"
- Windows: SmartScreen muestra "Windows protegió su PC" (rojo)
- Linux: el gestor de paquetes advierte "paquete no autenticado"

**Acción:** Adquirir certificados antes de la Fase 6. Agregar job `sign-macos` + `sign-windows` al CI/CD.

---

### 15.2 Auto-Actualización (Sparkle / WinSparkle)

| Plataforma | Framework | Paquete Flutter |
|-----------|-----------|-----------------|
| **macOS** | Sparkle 2.x | `auto_updater_macos` |
| **Windows** | WinSparkle | `auto_updater_windows` |
| **Linux** | GitHub Releases + `pkcon`/`dnf`/`apt` | Script bash en postinst (`.deb`/`.rpm` ya lo manejan vía repo) |

**Flujo:**
```
App inicia → chequea https://github.com/SISTEMASSKULL/bos-install/releases/latest
  → ¿versión > actual?
    → Sí: descarga instalador nativo → ejecuta instalador → reinicia app
    → No: continúa
```

**AppImage:** Auto-update vía `appimageupdatetool` (incrustado en el bundle).

---

### 15.3 Crash Reporting (Sentry)

```
main.dart:
  runZonedGuarded(() async {
    await SentryFlutter.init((options) {
      options.dsn = 'https://xxx@sentry.io/project-id';
      options.environment = 'production';
      options.release = 'bauth-desktop@1.0.0';
    }, appRunner: () => runApp(BauthDesktop()));
  }, (error, stack) => Sentry.captureException(error, stackTrace: stack));
```

**Paquete:** `sentry_flutter` — soporta Windows, macOS, Linux.
**Privacy:** Sanitizar PII (nunca enviar claves SSH, contraseñas, ni ctx_id a Sentry).
**Error Boundary:** Widget `ErrorBoundary` con fallback UI: "Algo salió mal — [Reintentar] [Reportar]".

---

### 15.4 Accesibilidad (WCAG 2.1 AA)

Obligatorio para clientes gubernamentales y enterprise. Flutter lo soporta vía `Semantics`.

| Requisito | WCAG | Implementación |
|-----------|------|---------------|
| **Contraste de color** | 1.4.3 (4.5:1 texto, 3:1 grande) | Tokens ForUI ya definen paleta accesible. Verificar con `flutter_accessibility_scanner` |
| **Navegación por teclado** | 2.1.1 (todo operable sin mouse) | `FocusNode` + `FocusTraversalGroup` + `ShortcutManager` |
| **Etiquetas en iconos** | 1.1.1 (texto alternativo) | `Semantics(label: 'Roles')` en cada icono interactivo |
| **Indicador de foco visible** | 2.4.7 | `FocusIndicatorSpec` — borde visible en el elemento activo |
| **Zoom 200%** | 1.4.4 | Layout responsive no se rompe al escalar |
| **Lector de pantalla** | 4.1.2 | Probar con VoiceOver (macOS), Narrator (Windows), Orca (Linux) |

---

### 15.5 Atajos de Teclado — IRREUNCIABLE (R1)

**El dashboard debe ser 100% operable sin mouse.** Todo botón, todo campo, todo nodo
del árbol, toda celda de tabla, todo diálogo debe ser accesible vía teclado.
Esta regla no admite excepciones.

Administradores de sistemas operan más rápido con teclado:

| Atajo | Acción |
|-------|--------|
| `Ctrl+K` / `Cmd+K` | Barra de búsqueda/comando global |
| `Ctrl+1..9` | Cambiar entre vistas (Dashboard, Roles, Usuarios...) |
| `Ctrl+F` | Buscar en tabla/árbol actual |
| `Ctrl+S` | Guardar rol/usuario actual |
| `Ctrl+Shift+P` | Publicar rol |
| `Ctrl+R` | Refrescar datos |
| `Ctrl+Z` | Deshacer último cambio en editor |
| `Esc` | Cerrar panel/diálogo lateral / Cancelar edición |
| `Tab` / `Shift+Tab` | Navegar entre campos de formulario y secciones |
| `↑↓←→` | Navegar nodos del árbol (arriba/abajo/colapsar/expandir) |
| `Space` | Marcar/desmarcar checkbox en nodo del árbol |
| `Enter` | Expandir nodo colapsado / Abrir detalle del elemento |
| `Ctrl+Shift+F` | Foco a barra de búsqueda global |
| `Alt+←` / `Alt+→` | Navegar historial de vistas (atrás/adelante) |
| `F5` | Refrescar datos actuales |
| `F2` | Renombrar nodo seleccionado (edición inline) |
| `Delete` | Eliminar elemento seleccionado (con confirmación) |
| `Ctrl+A` | Seleccionar todos en tabla actual |

**Implementación:** `ShortcutManager` nativo de Flutter + `CallbackShortcuts` + `FocusableActionDetector` + `FocusTraversalGroup` en cada pantalla.

---

### 15.6 Persistencia de Estado de Ventana

El administrador configura su espacio de trabajo y espera encontrarlo igual al volver.

| Estado | Almacenamiento |
|--------|---------------|
| Tamaño y posición de ventana | `window_manager` package → JSON en `~/.config/bauth-desktop/` |
| Ancho del sidebar | Mismo archivo |
| Última vista activa | Índice de pestaña, guardado al cerrar |
| Filtros activos (tenant, tier, fecha) | `shared_preferences` (escritorio) |
| Tema (claro/oscuro) | `shared_preferences` → `ThemeMode.system/dark/light` |
| Columnas visibles en tablas | Configuración por tabla, guardada en JSON |

**Paquete:** `window_manager` para tamaño/posición. `shared_preferences` para preferencias.

---

### 15.7 Notificaciones In-App (Toast + Sistema)

| Tipo | Implementación |
|------|---------------|
| **Toast** (operación completada) | `ShadToast` — "Rol CAJERO guardado ✅" |
| **Alerta** (requiere atención) | `ShadAlert` en navbar — badge rojo con contador |
| **Sistema** (app en segundo plano) | `flutter_local_notifications` — Windows/macOS/Linux |
| **Push** (móvil, futuro) | Firebase Cloud Messaging |

**Eventos que disparan notificación:**
- DRIFT detectado en rol sincronizado
- Usuario bloqueado por fuerza bruta
- Intento de acceso denegado desde ubicación no autorizada
- Nueva versión del desktop disponible

---

### 15.8 Modo Sin Conexión y Reconexión

La VPS puede ser inaccesible por red, mantenimiento o caída del daemon.

| Estado | Comportamiento |
|--------|---------------|
| **Sin conexión** | Banner superior naranja: "Sin conexión al daemon — reconectando en 5s..." |
| **Datos cacheados** | Última respuesta de cada provider guardada en `shared_preferences`. Modo lectura. |
| **Operaciones** | Todos los botones de escritura deshabilitados. Tooltip: "Requiere conexión al daemon" |
| **Reconexión** | Backoff exponencial: 1s → 2s → 5s → 15s → 30s → 60s. Máximo 10 intentos. |
| **Reconexión exitosa** | Banner verde 3s: "Reconectado ✅" → providers refrescan datos |
| **Fallo total (>5 min)** | Diálogo: "No se pudo conectar al servidor. [Reintentar] [Modo offline] [Salir]" |

---

### 15.9 Exportación de Datos

| Formato | Uso | Paquete |
|---------|-----|---------|
| **CSV** | Roles, usuarios, auditoría (compatible Excel) | `csv` o trina_grid nativo |
| **JSON** | RolTemplate completo (backup/restore) | `dart:convert` |
| **PDF** | Informe de cumplimiento ISO 27001, resumen de privilegios | `pdf` + `printing` |

**Exportaciones predefinidas:**
- "Exportar todos los roles" → CSV con tier, status, LoA, MFA, átomos
- "Exportar auditoría (filtro actual)" → CSV con fecha, usuario, acción, resultado
- "Exportar RolTemplate" → JSON completo con 14 secciones (para importar en otro tenant)
- "Informe de cumplimiento" → PDF con KPIs de seguridad, ghost accounts, credenciales vencidas

---

### 15.10 Bloqueo por Inactividad (Security Auto-Lock)

Escritorio desatendido = riesgo de seguridad. ISO 27001 A.9.4.2 lo exige.

| Configuración | Default |
|---------------|---------|
| Timeout de inactividad | 15 minutos (configurable) |
| Acción al bloquear | Minimizar a bandeja + overlay "Presione Ctrl+Shift+L para desbloquear" |
| Método desbloqueo | Atajo de teclado `Ctrl+Shift+L` (sin contraseña — la sesión del daemon ya expiró) |
| Post-bloqueo | Al desbloquear, re-conectar al daemon y validar health check |

---

### 15.11 Menú Contextual (Click Derecho)

Interacción natural en escritorio que la web no tiene.

| Elemento | Menú contextual |
|----------|----------------|
| Nodo de rol en árbol | Editar · Duplicar · Publicar · Sincronizar · Exportar JSON · Eliminar |
| Usuario en tabla | Ver detalle · Editar roles · Revocar sesiones · Desbloquear · Exportar |
| Celda de auditoría | Copiar valor · Filtrar por este valor · Ver evento completo |
| Espacio vacío en árbol | Crear nuevo rol · Importar JSON · Refrescar |

**Paquete:** `contextual_menu` o `CustomContextMenu` con `showMenu()` de Flutter.

---

### 15.12 Logging Estructurado

```dart
// services/app_logger.dart
class AppLogger {
  void info(String message, {Map<String, dynamic>? context});
  void warn(String message, {Map<String, dynamic>? context});
  void error(String message, dynamic error, StackTrace? stack, {Map<String, dynamic>? context});
}

// Uso:
logger.info('RolTemplate guardado', context: {
  'role_id': roleId,
  'tenant_id': tenantId,
  'duration_ms': elapsed,
  // NUNCA: password, ssh_key, token, ctx_id completo
});
```

**Salidas:**
- Archivo rotativo: `~/.local/share/bauth-desktop/logs/app.log` (30 días, 10 MB máx por archivo)
- Consola (modo dev): `--verbose` flag
- Sentry (errores): automático vía `sentry_flutter`

---

### 15.13 Primer Arranque — Wizard de Configuración

```
PASO 1: BIENVENIDA
┌─────────────────────────────────────────────┐
│  🛡️ bAuth Desktop — Identity Control Plane  │
│                                             │
│  Bienvenido al panel de administración de   │
│  identidad del SBOS.                        │
│                                             │
│  Antes de comenzar, necesitamos conectarnos │
│  al servidor donde corre el daemon bAuth.   │
│                                             │
│  [COMENZAR CONFIGURACIÓN]                   │
└─────────────────────────────────────────────┘

PASO 2: CONEXIÓN (AUTOMÁTICO)
┌─────────────────────────────────────────────┐
│  📡 Conectando al daemon bAuth...           │
│                                             │
│  ⏳ Conectando a 13.140.128.230:9450...    │
│  ✅ WebSocket establecido                   │
│  ✅ bauth.health.check respondió            │
│                                             │
│  Daemon:    bAuth v3.0.0                    │
│  Uptime:    12d 4h 31m                      │
│  Conexión:  WebSocket directo (puerto 9450) │
│                                             │
│  [CONTINUAR]                                │
└─────────────────────────────────────────────┘

PASO 3: LISTO
┌─────────────────────────────────────────────┐
│  ✅ Configuración completa                   │
│                                             │
│  Servidor:   13.140.128.230:9450            │
│  Daemon:     bAuth v3.0.0                   │
│  Usuarios:   1,247 registrados              │
│  Roles:      366 definidos                  │
│  Sesiones:   89 activas                     │
│                                             │
│  [ABRIR DASHBOARD]                          │
└─────────────────────────────────────────────┘
```

---

### 15.14 Resumen de paquetes adicionales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `sentry_flutter` | ^8.0.0 | Crash reporting multiplataforma |
| `auto_updater` | ^1.0.0 | Auto-actualización (Sparkle/WinSparkle) |
| `window_manager` | ^0.4.0 | Persistencia tamaño/posición ventana |
| `shared_preferences` | ^2.3.0 | Preferencias (tema, filtros, columnas) |
| `flutter_secure_storage` | — | ❌ No necesario — sin credenciales SSH |
| `flutter_local_notifications` | ^18.0.0 | Notificaciones del sistema |
| `pdf` + `printing` | ^3.11.0 / ^2.12.0 | Exportación PDF |
| `csv` | ^6.0.0 | Exportación CSV |
| `flutter_accessibility_scanner` | ^1.0.0 | CI check de WCAG 2.1 AA |
| `contextual_menu` | ^0.1.0 | Menú contextual click derecho |

---

### 15.15 Nuevas tareas para las fases existentes

Estos puntos se integran en las fases ya definidas:

| Fase | Tareas agregadas |
|------|-----------------|
| **F0** | Configurar Sentry + logger estructurado + `flutter_accessibility_scanner` en CI |
| **F1** | Notificaciones in-app (toast + alert badge) + modo sin conexión + banner reconexión |
| **F2** | Exportar CSV/JSON desde tablas + menú contextual en filas |
| **F3** | Atajos de teclado globales + menú contextual en nodos de árbol + drag-drop reordenar |
| **F4** | Bloqueo por inactividad + persistencia de ventana + tema claro/oscuro |
| **F6** | Firma de código macOS/Windows + CI/CD de signing + primer arranque wizard |
| **F6** | Auto-update integrado con GitHub Releases (Sparkle/WinSparkle/Linux nativo) |

---

*PLAN-DESKTOP-BAUTH v3.0 · 2026-06-27 · SKULL · SBOS*
*Basado en: DDL 179 tablas · 47 handlers JSON-RPC · 12 dominios · BAUTH-CRUD-ROLES-USUARIOS.md v3.0 · SBOS-020-COREUI · SBOS-010-GOVERNANCE · BOS-REPAIR-PLAN-MAESTRO-v3*
*Investigación: 9 dashboards IAM internacionales · WCAG 2.1 AA · Sparkle/WinSparkle · Sentry · auto_updater · código de firma OV/EV*
*Próximo paso: FASE 0 — flutter create + conexión JSON-RPC viva contra VPS*
