# PROPUESTA-DESKTOP-CONTEXT-PLANE-v1.0 — Interfaz Desktop para Context Plane
## Documento no indexado — Evaluación de A.64 + Propuesta de Desarrollo

**Versión:** 1.0 · **Fecha:** 2026-07-31 · **Autor:** bauth-developer
**Referencia:** A.64_ANEXO-MAQUETAS-DESKTOP-v1.0.md · DDL `bos` v2.12.0 · PROPUESTA-INTERFAZ-CONTEXT-PLANE-v1.0.md
**Propósito:** Evaluar el estado actual del desktop contra la DDL `bos` y proponer las vistas, widgets y rutas necesarias para operar el Context Plane desde la interfaz.

---

## 1. Diagnóstico — qué existe y qué falta

### 1.1 Estado actual del código (58 archivos Dart)

| Capa | Archivos | Estado |
|------|:--------:|--------|
| **Shell** (layout 3 bloques) | `estructura_desktop.dart`, `bloque_central`, `bloque_lateral_izquierdo`, `bloque_lateral_derecho` | ⚠️ Izquierdo OK. **Derecho sin TOP/BODY/BOTTOM** — solo `SingleChildScrollView`. |
| **Navegación** | `menu_datos.dart`, `router_vistas.dart`, `sidenav_provider.dart` | ⚠️ Las rutas `bos`, `politicas`, `sesiones` están en el router pero redirigen a `_VistaEnConstruccion`. |
| **Conexión** | `cliente_rpc.dart`, `cliente_rpc_ssh.dart`, `tunel_ssh.dart`, `proveedor_conexion.dart` | ✅ SSH + WebSocket RPC funcional. |
| **Vistas implementadas** | `vista_dashboard`, `vista_roles`, `vista_usuarios`, `vista_entidades`, `vista_rol_template` | ✅ 5 vistas con datos reales. |
| **Vistas placeholder** | 13 rutas → `_VistaEnConstruccion` | ❌ Context Plane (`bos`), políticas, sesiones, auditoría entre ellas. |
| **Widgets comunes** | `arbol_sbos`, `tarjeta_kpi`, `panel_lateral`, `tira_tabs`, `campo_formulario`, `boton_sbos` | ✅ Kit de componentes reutilizable. |

### 1.2 Lo que A.64 ya planeó para Context Plane

En la sección 10 (Vistas en construcción), la ruta `bos` está listada como pendiente. No hay maqueta ASCII para Context Plane en A.64. La ruta existe en el router pero muestra el placeholder `En construcción`.

### 1.3 Lo que la DDL `bos` ya tiene (19 tablas en VPS)

| Grupo | Tablas | Propósito |
|-------|--------|-----------|
| Dispositivos | `ctx_registered_device`, `ctx_device_heartbeat` | Registro + keepalive |
| Sesiones | `ctx_context_session` | ctx_id 6 capas + BitMask |
| Políticas | `ctx_context_policy` | TTL, rate limit, MDM |
| Auditoría | `ctx_context_audit`, `ctx_context_switch_log`, `ctx_context_transfer` | 3× WORM hash-chain |
| Emergencias | `ctx_context_emergency` | Break-glass control dual |

---

## 2. Propuesta de interfaz — 4 vistas nuevas

### 2.1 Priorización

| Prioridad | Vista | Ruta | Dependencia |
|:---------:|-------|------|-------------|
| **P1** | Dashboard de Contexto | `/bos` | `bos.ctx.session.get` + `bos.ctx.device.list_by_tenant` |
| **P2** | Sesiones Activas | `/sesiones` | `bos.ctx.session.list_by_tenant` + `bos.ctx.session.invalidate` |
| **P2** | Dispositivos | `/dispositivos` | `bos.ctx.device.list_by_tenant` |
| **P3** | Auditoría y Emergencias | `/auditoria` | `bos.ctx.audit.query` + `bos.ctx.emergency.*` |

### 2.2 Vista 1 — Dashboard de Contexto (`/bos`) · P1

Reemplaza el placeholder `_VistaEnConstruccion` de la ruta `bos`. Es la vista principal del Context Plane, análoga al Dashboard de Salud existente pero para métricas de infraestructura.

**Maqueta:**

```
┌── BREADCRUMB ──────────────────────────────────────────────────────────────┐
│  Control Plane  /  Contexto                                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌── KPI ROW ──────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ 14 sesiones  │  │ 89 disp.     │  │ 0 emergencias│  │ 99.8% uptime │    │
│  │   activas    │  │   activos     │  │   activas    │  │   Context API│    │
│  │  ▲ 3 vs 24h  │  │  ▲ 12 vs 24h │  │  ● verde     │  │  ↕ 1.2ms    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌── SESIONES ACTIVAS ────────────────────────────────────────────────────────┐
│  [ ACTIVE ▾ ]  [ tenant: skull ]                     [ Ver todas → ]       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ctx_id (8chars)  usuario      entidad_1   loa  bitmask   expira     │  │
│  │ ───────────────  ────────────  ──────────  ───  ────────  ─────────  │  │
│  │ 019fb501...def   sbos-admin    SKULL-CORP  AAL2  0xFFFE  21:00 UTC │  │
│  │ 019fb502...abc   juan.perez    SKULL-CORP  AAL2  0x3F80  20:30 UTC │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

┌── DISPOSITIVOS RECIENTES ──────────────────────────────────────────────────┐
│  [ ACTIVE ▾ ]                                        [ Ver todos → ]       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ hostname         ip           node_k8s     heartbeats  state         │  │
│  │ ───────────────  ───────────  ───────────  ──────────  ───────────── │  │
│  │ ws-01.skull.loc  10.0.5.42    worker-3     58/60       ACTIVE   ●   │  │
│  │ vdi-maya-03      10.0.7.15    —            60/60       ACTIVE   ●   │  │
│  │ ws-15.skull.loc  10.0.5.88    worker-7      2/60       SUSPENDED ●  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

┌── PANEL DERECHO ───────────────────────────────────────────────────────────┐
│  [ Configuración ▾ ]                                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ POLÍTICA DEL TENANT              │ ÚLTIMOS EVENTOS                   │  │
│  │ device_ttl:        8h (28800s)   │ 09:00  DEVICE_REGISTER ws-01      │  │
│  │ session_ttl:      12h (43200s)   │ 09:05  SESSION_CREATE sbos-admin  │  │
│  │ heartbeat:            30s        │ 09:15  SESSION_SWITCH juan.perez  │  │
│  │ rate_limit:      500 req/s       │ 10:30  DEVICE_HEARTBEAT 89 disp   │  │
│  │ require_mdm:          false      │                                     │  │
│  │                                   │  [ Ver auditoría completa → ]      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Datos que consume:**
- `bos.ctx.session.list_by_tenant` → tabla de sesiones activas + count KPI
- `bos.ctx.device.list_by_tenant` → tabla de dispositivos + count KPI
- `bos.ctx.policy.get` → panel de política del tenant
- `bos.ctx.audit.query` → últimos eventos (limit 5)
- `bos.ctx.emergency.list_pending_reviews` → count KPI

**Widgets a crear:**
- `vistas/vista_contexto.dart` — vista principal
- `widgets/contexto/kpi_contexto.dart` — 4 tarjetas KPI (reutiliza `tarjeta_kpi.dart`)
- `widgets/contexto/tabla_sesiones.dart` — tabla filtrable
- `widgets/contexto/tabla_dispositivos.dart` — tabla con heartbeat status
- `widgets/contexto/panel_politica.dart` — resumen de `ctx_context_policy`

### 2.3 Vista 2 — Sesiones Activas (`/sesiones`) · P2

Vista dedicada para administradores. Lista completa de sesiones con filtros, búsqueda, y acciones (invalidar, extender).

**Maqueta:**

```
┌── BREADCRUMB ──────────────────────────────────────────────────────────────┐
│  Control Plane  /  Sesiones                                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌── FILTROS ──────────────────────────────────────────────────────────────────┐
│  [ ACTIVE ▾ ]  [ tenant: skull ▾ ]  [ 🔍 buscar usuario o ctx_id...    ]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌── TABLA (paginada, 50 por página) ─────────────────────────────────────────┐
│  ctx_id       usuario      entidad_1    entidad_2   loa  bitmask   expira  │
│  ───────────  ───────────  ───────────  ──────────  ───  ────────  ─────── │
│  019fb5...    juan.perez   SKULL-CORP   Norte       AAL2  0x3F80   20:30  │
│  019fb5...    maria.lopez  SKULL-CORP   Sur         AAL3  0xFFFE   21:00  │
│  ...                                                                       │
│                                   [ ◀ 1 2 3 ... 15 ▶ ]  1,247 sesiones    │
└─────────────────────────────────────────────────────────────────────────────┘

┌── ACCIONES EN FILA ────────────────────────────────────────────────────────┐
│  Al hacer clic en una fila → panel derecho muestra:                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  DETALLE DE SESIÓN                                                  │  │
│  │  ctx_id:    019fb501...def                [ Invalidar sesión ]       │  │
│  │  usuario:   sbos-admin (AAL2)                                       │  │
│  │  entidad:   SKULL-CORP > Norte > CAJA-01                            │  │
│  │  bitmask:   0x3F80 (admin + finanzas)                               │  │
│  │  traceparent: 00-4bf92f...                                          │  │
│  │  creado:    09:05 UTC · expira: 21:00 UTC · TTL: 11h 55m           │  │
│  │                                                                      │  │
│  │  DISPOSITIVO                                                         │  │
│  │  ws-01.skull.local · 10.0.5.42 · worker-3                           │  │
│  │                                                                      │  │
│  │  HISTORIAL DE CAMBIOS (últimos 5 switches)                           │  │
│  │  09:15  Norte → Sur  "Cambio de sucursal"                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Datos que consume:**
- `bos.ctx.session.list_by_tenant` — tabla paginada
- `bos.ctx.session.get` — detalle de una sesión
- `bos.ctx.session.invalidate` — botón de invalidar
- `bos.ctx.audit.switches` — historial de switches de la sesión

**Widgets a crear:**
- `vistas/vista_sesiones.dart` — vista completa
- `widgets/sesiones/detalle_sesion.dart` — panel derecho con acciones

### 2.4 Vista 3 — Dispositivos (`/dispositivos`) · P2

**Maqueta:**

```
┌── BREADCRUMB ──────────────────────────────────────────────────────────────┐
│  Control Plane  /  Dispositivos                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌── FILTROS ──────────────────────────────────────────────────────────────────┐
│  [ ACTIVE ▾ ]  [ tenant: skull ▾ ]                     [ 🔍 hostname... ]  │
└─────────────────────────────────────────────────────────────────────────────┘

┌── TABLA ────────────────────────────────────────────────────────────────────┐
│  hostname         ip           node       estado    heartbeats  expira     │
│  ───────────────  ───────────  ─────────  ────────  ──────────  ─────────  │
│  ws-01.skull.loc  10.0.5.42    worker-3   ACTIVE    58/60       17:00 UTC │
│  vdi-maya-03      10.0.7.15    —          ACTIVE    60/60       17:30 UTC │
│  ws-15.skull.loc  10.0.5.88    worker-7   SUSPENDED  2/60       15:00 UTC │
└─────────────────────────────────────────────────────────────────────────────┘

┌── PANEL DERECHO ───────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  DETALLE DE DISPOSITIVO                                             │  │
│  │  hostname:    ws-15.skull.local                                      │  │
│  │  estado:      SUSPENDED · sin heartbeat desde 10:00                  │  │
│  │  IP:          10.0.5.88                                              │  │
│  │  nodo K8s:    worker-7                                               │  │
│  │  creado:      07:30 · TTL: 8h · expira: 15:30                       │  │
│  │                                                                      │  │
│  │  [🔄 Forzar heartbeat]  [⏸ Suspender]  [✕ Invalidar]               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 Vista 4 — Auditoría y Emergencias (`/auditoria`) · P3

Combina el log de auditoría WORM con el panel de emergencias. Solapa con la ruta `auditoria` ya existente en el menú.

**Datos que consume:**
- `bos.ctx.audit.query` — log completo con filtros (operación, fecha, tenant)
- `bos.ctx.emergency.list_pending_reviews` — emergencias pendientes de revisión
- `bos.ctx.emergency.activate` — botón de activación (admin)
- `bos.ctx.emergency.approve` — botón de aprobación (segundo admin)
- `bos.ctx.emergency.review` — revisión post-hoc

---

## 3. Cambios en la navegación (sidenav)

### 3.1 Nuevos ítems en el menú

Los ítems actuales del grupo CRUD y SISTEMA se reorganizan para dar espacio al Context Plane:

```
┌─────────────────────────────────────┐
│  GENERAL                            │
│  ⊞ Dashboard de Salud               │
│  ⊞ Dashboard de Contexto     [NUEVO]│  ← ruta `/bos`
│  👥 Usuarios Conectados             │
│                                     │
│  CONTEXTO                    [NUEVO]│  ← nuevo grupo
│  📡 Sesiones Activas         [NUEVO]│  ← ruta `/sesiones`
│  🖥 Dispositivos             [NUEVO]│  ← ruta `/dispositivos`
│  📋 Auditoría                        │  ← ruta `/auditoria` (existente, ahora muestra datos reales)
│                                     │
│  SISTEMA                            │
│  🚨 Emergencias             [NUEVO]│  ← ruta `/emergencias` (atajo a sección emergencia en /auditoria)
│  ...                                │
```

**Impacto en `menu_datos.dart`:** agregar 4 entradas nuevas + 1 grupo nuevo.

### 3.2 Rutas en `router_vistas.dart`

```dart
GoRoute(path: '/bos', builder: (...) => const VistaContexto()),
GoRoute(path: '/sesiones', builder: (...) => const VistaSesiones()),
GoRoute(path: '/dispositivos', builder: (...) => const VistaDispositivos()),
// /auditoria ya existe — actualizar builder para datos reales
// /emergencias → redirige a /auditoria con tab Emergencias seleccionado
```

---

## 4. Integración con la API JSON-RPC

### 4.1 Nuevo cliente en `nucleo/api/`

Crear `bos_api.dart` con los 18 métodos definidos en PROPUESTA-INTERFAZ-CONTEXT-PLANE-v1.0.md:

```dart
class BosApi {
  final ClienteRpc _rpc;
  
  // Dispositivos
  Future<DeviceContext> registerDevice(...);
  Future<void> heartbeat(...);
  Future<DeviceContext?> getDevice(String dctxId);
  Future<List<DeviceContext>> listDevices(...);
  
  // Sesiones
  Future<SessionContext> createSession(...);
  Future<SessionContext?> getSession(String ctxId);
  Future<void> invalidateSession(String ctxId, String reason);
  Future<SessionContext> switchContext(...);
  Future<List<SessionContext>> listSessions(...);
  
  // Políticas
  Future<ContextPolicy?> getPolicy(String tenantId);
  Future<void> upsertPolicy(...);
  
  // Auditoría
  Future<List<AuditEvent>> queryAudit(...);
  Future<List<ContextSwitch>> querySwitches(...);
  Future<List<ContextTransfer>> queryTransfers(...);
  
  // Emergencias
  Future<Emergency> activateEmergency(...);
  Future<Emergency> approveEmergency(...);
  Future<void> reviewEmergency(...);
  Future<List<Emergency>> listPendingReviews(...);
}
```

### 4.2 Provider con Riverpod

```dart
final contextoProvider = StateNotifierProvider<ContextoNotifier, ContextoState>((ref) {
  return ContextoNotifier(ref.read(bosApiProvider));
});
```

---

## 5. Plan de implementación — 4 sprints

| Sprint | Entregable | Vistas | Widgets | API |
|:------:|------------|:------:|:-------:|:---:|
| **1** | Dashboard de Contexto (`/bos`) | 1 | 5 (KPI, tabla sesiones, tabla dispositivos, panel política, últimos eventos) | `session.list`, `device.list`, `policy.get`, `audit.query` |
| **2** | Sesiones (`/sesiones`) + Dispositivos (`/dispositivos`) | 2 | 4 (tabla sesiones paginada, detalle sesión, tabla dispositivos, detalle dispositivo) | `session.get`, `session.invalidate`, `device.get`, `audit.switches` |
| **3** | Auditoría (`/auditoria`) + Emergencias | 1 | 3 (log auditoría, panel emergencia, formulario revisión) | `audit.query`, `audit.transfers`, `emergency.*` |
| **4** | Sidenav actualizado + integración | 0 | 1 (nuevos ítems de menú) | `policy.upsert` |

---

## 6. Reutilización de widgets existentes

| Widget existente | Se reutiliza en |
|------------------|-----------------|
| `tarjeta_kpi.dart` | 4 KPIs del dashboard de contexto |
| `tira_tabs.dart` | Pestañas de auditoría (eventos / emergencias) |
| `arbol_sbos.dart` | Vista jerárquica de entidades en detalle de sesión |
| `campo_formulario.dart` | Formulario de activación de emergencia |
| `boton_sbos.dart` | Acciones: invalidar, aprobar, suspender |
| `panel_lateral.dart` | Panel derecho con detalle de sesión/dispositivo |
| `barra_estado.dart` | Ya muestra métricas en tiempo real — agregar `bos_ctx_*` |
| `punto_estado.dart` | Estado de dispositivos: verde/ámbar/rojo según heartbeat |

---

## 7. Métricas en la BarraEstado

La barra de estado existente (§3.3 de A.64) ya muestra `142.857 eval/s · 89 sesiones · 366 roles`. Se agregan métricas del Context Plane:

```
● Conectado  WebSocket · ↕ 12 ms │ ● Reconcile · hace 3m │ ⚠ 1 drift │ 142k eval/s · 89 ctx · 14 sesiones · 366 roles
                                                                                   ─── nuevo ───
```

`89 ctx` = ctx_ids activos en Redis DB1. `14 sesiones` = `bos.ctx.session.list_by_tenant` count.

---

## 8. Áreas de decisión HITL

| ID | Pregunta | Recomendación |
|----|----------|---------------|
| **UI-01** | ¿Dashboard de Contexto como vista independiente o como pestaña dentro del Dashboard de Salud? | **Independiente** — son métricas de capas distintas (identidad vs infraestructura). El dashboard de salud muestra motores bAuth; el de contexto muestra dispositivos/sesiones BOS. |
| **UI-02** | ¿Grupo CONTEXTO en sidenav o los ítems van dentro de SISTEMA? | **Grupo CONTEXTO nuevo** — son 4 vistas (dashboard, sesiones, dispositivos, auditoría). Merecen su propia sección. |
| **UI-03** | ¿El panel de emergencia (break-glass) debe ser accesible desde el dashboard principal con un botón GRANDE y visible? | **Sí** — botón de emergencia siempre visible en la BarraSuperior (ícono ⚠ rojo) para acceso inmediato. NIST CP-2(8) exige acceso rápido. |
| **UI-04** | ¿Tablas con datos mock (mientras no hay API real) o solo esqueleto de UI? | **Esqueleto con datos mock** — permite validar la UX sin depender de la API. Los mock usan la misma estructura que los modelos Dart reales. |

---

*Documento no indexado — SKULL · SBOS · Julio 2026*
