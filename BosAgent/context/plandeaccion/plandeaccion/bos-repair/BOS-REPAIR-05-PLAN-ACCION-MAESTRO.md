> ---
> ## ⚠️ ESTADO DE ESTE DOCUMENTO — actualización 2026-06-12
>
> Este documento (v2.0) es el diseño ORIGINAL del plan de acción y se
> conserva como referencia histórica de la refactorización técnica (F0-F10).
>
> **La brújula normativa del proyecto desde 2026-06-12 es:**
>
> | Documento | Propósito |
> |-----------|-----------|
> | `SBOS_Proyecto_Master.md` v2.1 | **Lo que el SBOS debe ser** — arquitectura completa, 8 daemons, contratos, stack canónico |
> | `BOS-CONTRATOS-SBOS.md` v1.0 | **Lo que el BOS debe cumplir** — 7 contratos con criterios de aceptación verificables |
> | `REGISTRO-ESTADO.md` | **Progreso real** — 174 átomos · 102✅ · 2🟡 · 70🔴 |
>
> **Plan vivo:** `BOS-REPAIR-PLAN-MAESTRO-v3.md` (v4.0 — F11-F17)  
> **Decisión de stubs:** `BOS-REPAIR-16-ADR007-DAEMONS-STUB.md`  
> **Bloqueante actual:** `REGISTRO-ESTADO.md` → F10.B.6 (setup.go fix)
>
> Ningún átomo se ejecuta desde este documento. Ante discrepancia, mandan
> `SBOS_Proyecto_Master.md`, `BOS-CONTRATOS-SBOS.md` y `REGISTRO-ESTADO.md`.
> ---
# Plan de Acción — BosAgent / SBOS
## Refactorización Arquitectónica, Modularización y Documentación Profesional

**Versión:** 2.0  
**Fecha:** Junio 2026  
**Estado del plan:** 🔴 NO INICIADO  
**Documentos de referencia:**
- `auditoria_tecnica_bosagent.md` — 16 problemas con evidencia de código
- `ADR-002-BOS-ROLES-PRIVILEGIOS.md` — roles, modos y privilegios del daemon bos *(nuevo)*
- `ADR-003-ESTANDARES-DOCUMENTACION.md` — estándar godoc + cumplimiento normativo *(nuevo)*
- `SBOS-049-CONTEXT-PLANE.md` — arquitectura del Context Plane
- `SBOS-MANUAL-ACOPLAMIENTO.md` — contratos entre daemons

**ADRs vigentes que este plan implementa:**

| ADR | Título | Fases que lo implementan |
|---|---|---|
| ADR-001 | BOS como capa OS — reemplaza sudo | Fase 1, Fase 4 |
| ADR-002 | Roles, modos y privilegios del bos | Fase 1 (F1.6), Fase 5 (F5.2), Fase 6 (F6.1) |
| ADR-003 | Estándares de documentación y cumplimiento normativo | Fase 7 (continua) |
| ADR-004 | bos como Kubernetes Operator Soberano — escalado y mantenimiento | Fase 9 (nueva) |
| ADR-021 | Máquina de 18 estados de fichas | Fase 1 (F1.5 — mutex observer) |

---

## Cómo usar este documento

Este documento está diseñado para que un agente (humano o IA) pueda:

1. **Leerlo en frío** y entender el estado actual del proyecto
2. **Retomar el trabajo** en cualquier fase sin perder contexto
3. **Verificar** si una fase está completa antes de avanzar
4. **Entender el por qué** de cada decisión, no solo el qué

Cada fase tiene:
- **Estado actual** — qué hay ahora y por qué es un problema
- **Estado objetivo** — qué debe existir cuando la fase termine
- **Por qué primero** — justificación del orden
- **Tareas atómicas** — cada una verificable independientemente
- **Criterio de completitud** — cómo saber que está terminada
- **Señal de retoma** — qué buscar en el código para saber dónde quedó

---

## Resumen ejecutivo del estado actual

El proyecto BosAgent/SBOS tiene una arquitectura de dominio correcta en `internal/` pero un desorden severo en `cmd/`. El resultado es un sistema que funciona pero que:

- **No se puede mantener:** `install_ui.go` tiene 4,834 líneas en un solo archivo
- **No se puede documentar:** la lógica está dispersa sin contratos claros entre capas
- **No se puede extender:** el JSON-RPC no tiene autenticación ni el Context Plane está completo
- **Tiene bugs latentes en producción:** race condition entre observer y reconciler puede corromper datos durante reparación de fichas

El principio de este plan es: **la modularización es el prerequisito de todo lo demás**. No se puede documentar lo que no está ordenado. No se puede robustecer el JSON-RPC sin antes tener los paquetes que lo respaldan. No se puede implementar el Context Plane sobre código monolítico.

### Mapa de problemas y su fase de solución

| Problema | Severidad | Fase que lo corrige |
|---|---|---|
| P1 — install_ui.go monolito 4,834 líneas | 🔴 Alta | Fase 3 |
| P2 — Doble implementación WebSocket | 🔴 Alta | Fase 2 |
| P3 — Violación del patrón TEA (BubbleTea) | 🔴 Alta | Fase 3 |
| P4 — Lógica de infraestructura en cmd/bos/main.go | 🟠 Media-Alta | Fase 1 |
| P5 — kubeconfig duplicado x6 | 🟠 Media | Fase 4 |
| P6/P14 — Race condition observer + reconciler | 🔴 Alta | Fase 1 |
| P7 — Estado global mutable en bosctl | 🟡 Media | Fase 4 |
| P8 — gorilla/websocket redundante | 🟡 Media | Fase 2 |
| P9 — Side effects sin rollback en ensureDaemonRunning | 🟠 Media-Alta | Fase 4 |
| P10 — syncViewports sin punto de verdad | 🟡 Media | Fase 3 |
| P11 — Campos step/screen inconsistentes | 🟡 Media | Fase 3 |
| P12 — startWatchdog nunca llamada | 🟡 Media | Fase 1 |
| P13 — Cero tests en cmd/ | 🟠 Media | Fase 8 |
| P15 — bosRBAC como nil interface | 🟡 Media | Fase 1 |
| P16 — Paths hardcoded dispersos | 🟡 Baja | Fase 4 |
| Context Plane 30% implementado | 🔴 Alta | Fase 5 |
| JSON-RPC sin auth ni timeout | 🔴 Alta | Fase 6 |
| Documentación ausente | 🟠 Media | Fase 7 |

---

## Arquitectura Objetivo — Actualizada 2026-06-12 (SBOS_Proyecto_Master.md v2.1)

> El BOS no es solo un instalador. Es el **Control Plane soberano del SBOS**
> (§3 del SBOS_Proyecto_Master.md). La arquitectura objetivo debe cumplir
> los 7 contratos de `BOS-CONTRATOS-SBOS.md`. F0-F10 completaron la
> refactorización técnica. F10.B-F11 entregan el instalador funcional.
> F12-F17 completan el despliegue del stack real y la certificación.

### Criterio de "BOS Listo para el SBOS" (del BOS-CONTRATOS-SBOS.md)

```
[ ] bos.service arranca sin errores en Ubuntu 26.04 virgen (F10.B.7)
[ ] /run/bos/bos.sock creado, permisos 0660, grupo bos
[ ] bosctl setup TUI funciona end-to-end (F10.B.9)
[ ] Stack Day 0: PG18.4, Redis8.6.2, KC26.6.2, Vault2.0, Kong3.9 (F12-F13)
[ ] GET :9443/api/v1/context/{ctx_id} responde en <5ms (F10.B.11)
[ ] context.promoted emitido al autenticar un usuario (C-1)
[ ] bosctl deploy seed.yml alta un tenant en <10 min (C-2, F11+)
[ ] Reconciliación repara drift sin intervención humana (C-7, F11.7)
[ ] 0 secretos hardcodeados — todo en Vault (F12.3)
[ ] audit_events con ctx_id en cada operación (A.8.15, F5.7)
```

### Árbol de paquetes objetivo (alcanzado en F0-F10)

Antes de ver las fases, entender adónde se va:

```
cmd/
├── bos/
│   └── main.go          ~150 líneas — SOLO orquestación y señales del OS
└── bosctl/
    ├── main.go          ~120 líneas — SOLO router CLI + rbacGuard
    ├── bootstrap.go      ~80 líneas — CLI parsing, delega a internal/bootstrap
    ├── install_ui.go     ~80 líneas — entry points TUI
    ├── os_commands.go    ~80 líneas — cmdExec, cmdLS, cmdCat, etc.
    └── context.go        ~80 líneas — bosctl context subcomandos

internal/
├── audit/               auditLog centralizado (de main.go)
├── bootstrap/           autoBootstrap + check* C-01..C-08 + paths centralizados
├── cgroup/              cgroup delegation, isBareMetal (de main.go)
├── network/             nftables, bridge (de main.go)
├── observer/            runObserverLoop + DAG topológico + mutex anti-race
├── context/             Context Plane completo: dctx_id + ctx_id + promote
├── tui/
│   ├── model.go         struct model, Init, Update (TEA puro, sin mutación)
│   ├── styles/          lipgloss vars + iconos (sin deps de bubbletea)
│   ├── screens/         wizard, installing, complete, system
│   └── demo/            modo demo
└── wslib/               cliente WS único (ya existe, solo extender)
    (resto de internal/ sin cambios — ya está bien)
```

### Contrato de capas

```
cmd/         → puede importar: internal/*, stdlib
internal/X   → puede importar: internal/Y donde Y != cmd/*, otras reglas por paquete
              → NO puede importar: cmd/*, otros binarios

Regla absoluta: cmd/ es solo orquestación y presentación.
               La lógica vive en internal/ siempre.
```

---

## Estado de las fases

> Estado actualizado 2026-06-12. Detalle de átomos en `REGISTRO-ESTADO.md`.

| Fase | Nombre | Estado | Notas |
|---|---|---|---|
| 0 | Fundación — estructura de paquetes | ✅ COMPLETA | F0.0-F0.7 + F0.6.S |
| 1 | Extraer infraestructura de cmd/bos/main.go | ✅ COMPLETA | F1.1-F1.9 — main.go 118L |
| 2 | Unificar transporte WebSocket | ✅ COMPLETA | F2.1-F2.4 — gorilla eliminado |
| 3 | Partir install_ui.go | ✅ COMPLETA | F3.1-F3.18 — monolito → 10 paquetes |
| 4 | Limpiar cmd/bosctl/ | ✅ COMPLETA | F4.1-F4.5 — bosctl main 107L |
| 5 | Context Plane completo (SBOS-049) | ✅ 75% | F5.1-F5.6 ✅ · F5.7-F5.8 🔴 (req PG+Redis real) |
| 6 | JSON-RPC robusto | ✅ 92% | F6.1-F6.11 ✅ · F6.12 🔴 (catálogo staging) |
| 7 | Documentación del código (ADR-003) | ✅ COMPLETA | F7.1-F7.8 — godoc + runbooks |
| 8 | Tests y cobertura | ✅ COMPLETA | F8.1-F8.7 — 61% cobertura |
| 9 | Operator Soberano (K8s) | ✅ COMPLETA | F9.0-F9.10 — validado en VPS real |
| 10 | biaos — Agente OS + Gateway IA | ✅ 91% | F10.0-F10.9 ✅ · F10.10 ✅ |
| 10.B | Instalador funcional end-to-end | 🟡 42% | F10.B.6 BLOQUEANTE inmediato |
| 11 | Ficha Engine completo | 🔴 0% | Requiere F10.B completa |
| 12-17 | Stack real + VDI + Estándares | 🔴 0% | Requiere F11 |
| 8 | Tests | 🔴 NO INICIADA | 2-3 días |
| 9 | bos como Operator Soberano — escalado y mantenimiento (ADR-004) | 🔴 NO INICIADA | 4-5 días |

**Estados posibles:** 🔴 NO INICIADA · 🟡 EN PROGRESO · 🟢 COMPLETA · ⚠️ BLOQUEADA

**Dependencias entre fases:**
```
Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 4
                                         ↓
                              Fase 5 (requiere 0,1,2)
                                         ↓
                              Fase 6 (requiere 5)
                                         ↓
                              Fase 9 (requiere 1,5,6 — ADR-004)
Fase 7 corre en paralelo con todas las fases
Fase 8 corre al final de cada fase
```

---

## FASE 0 — Fundación: estructura de paquetes

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 2 horas  
**Bloquea:** Todas las demás fases  
**No requiere:** Nada

### Por qué primero

Sin los directorios y paquetes Go creados, no se puede hacer ningún import. Go no permite imports de paquetes que no existen. Esta fase crea los "contenedores vacíos" que las fases siguientes llenarán. No hay lógica aquí — solo declaraciones de paquete y godoc.

### Estado actual

No existen los siguientes directorios en `internal/`:
- `internal/audit/`
- `internal/bootstrap/`
- `internal/cgroup/`
- `internal/network/`
- `internal/observer/`
- `internal/context/`
- `internal/tui/` (y sus subdirectorios)

### Estado objetivo

Cada directorio existe con un archivo `doc.go` mínimo que:
1. Declara el nombre del paquete Go
2. Tiene un comentario godoc que describe el propósito
3. Menciona qué problemas de la auditoría resuelve

### Señal de retoma

```bash
# Si esta fase está incompleta, este comando mostrará directorios faltantes:
for d in audit bootstrap cgroup network observer context tui tui/styles tui/screens tui/demo; do
  [ -f "internal/$d/doc.go" ] || echo "FALTA: internal/$d/doc.go"
done
```

### Tareas atómicas

**F0.1** — Crear `internal/audit/doc.go`
```go
// Package audit centraliza el registro de auditoría del daemon bos.
//
// Toda operación privilegiada del sistema (instalación, reparación,
// cambios de configuración, accesos) debe registrarse aquí antes
// de ejecutarse. Proporciona trazabilidad para ISO 27001 A.8.15.
//
// Este paquete reemplaza la función auditLog() que estaba dispersa
// en cmd/bos/main.go (ver auditoria_tecnica_bosagent.md, Problema P4).
//
// Referencia: ADR-001 (BOS como capa OS), SBOS-018 §audit
package audit
```

**F0.2** — Crear `internal/bootstrap/doc.go`
```go
// Package bootstrap gestiona el proceso de preparación del entorno
// para la operación del daemon bos.
//
// Responsabilidades:
//   - Preparación del sistema operativo (directorios, permisos, scripts)
//   - Verificación de los 8 criterios de certificación C-01..C-08
//   - Rutas canónicas del sistema (paths centralizados)
//
// Este paquete extrae la lógica que estaba en cmd/bos/main.go:autoBootstrap()
// y en cmd/bosctl/bootstrap.go:check*() (Problema P4, P5 de la auditoría).
//
// Referencia: SBOS-018 §autoBootstrap, SBOS-035 criterios de certificación
package bootstrap
```

**F0.3** — Crear `internal/cgroup/doc.go`
```go
// Package cgroup gestiona la delegación de cgroups para Kubernetes.
//
// BOS necesita que runc/kubelet puedan crear sub-cgroups bajo k8s.io.
// Este paquete verifica, configura y valida esa delegación tanto en
// bare metal como en contenedores.
//
// Extraído de cmd/bos/main.go (Problema P4 de la auditoría).
// Referencia: SBOS-018 §cgroup-setup
package cgroup
```

**F0.4** — Crear `internal/network/doc.go`
```go
// Package network configura las reglas de red del host para Kubernetes.
//
// K8s necesita que el tráfico de pods pueda traversar el bridge del host.
// Este paquete detecta la subnet del host y aplica la regla nftables FORWARD.
//
// Extraído de cmd/bos/main.go (Problema P4 de la auditoría).
// Referencia: install.sh §0.1-0.2
package network
```

**F0.5** — Crear `internal/observer/doc.go`
```go
// Package observer implementa el loop reactivo de instalación de fichas.
//
// BOS es un daemon reactivo (SBOS-018 §10): observa el estado de las
// fichas cada 5 segundos y reacciona a cada transición:
//
//   PENDIENTE + deps OK  → LISTA  (unblock)
//   LISTA                → INSTALANDO → instala en orden topológico DAG
//   DEGRADADA            → REPARANDO  → repara automáticamente
//
// IMPORTANTE: Este paquete incluye mutex de exclusión mutua para
// prevenir que el reconcile.Scheduler dispare repairs en paralelo
// (race condition documentada en Problema P6/P14 de la auditoría).
//
// Referencia: SBOS-018 §10, ADR-021 máquina de estados
package observer
```

**F0.6** — Crear `internal/context/doc.go`
```go
// Package context implementa el Context Plane del SBOS (SBOS-049).
//
// El Context Plane resuelve el problema semántico del sistema:
// Ubuntu sabe qué máquina existe. K8s sabe qué pod corre.
// Keycloak sabe quién es el usuario. SBOS sabe qué significa todo junto.
//
// Dos fases de contexto según SBOS-049 §16:
//
//  Fase 1 — Pre-autenticación (DeviceContext / dctx_id):
//    El dispositivo arranca → bos crea dctx_id automáticamente.
//    Contexto OS: hostname, IP, nodo K8s, tenant.
//    BitMask = 0x0 (ningún usuario autenticado).
//
//  Fase 2 — Post-autenticación (SessionContext / ctx_id):
//    Usuario se autentica con Keycloak → JWT con bos_contexts.
//    bos promueve dctx_id → ctx_id (evento context.promoted).
//    Contexto enriquecido: tenant + empresa + sucursal + POS + BitMask.
//
// Referencia: SBOS-049-CONTEXT-PLANE v3.0, NIST 800-207, ISO 27001 A.8.15
package context
```

**F0.7** — Crear `internal/tui/doc.go` y subdirectorios
```go
// Package tui implementa la interfaz de terminal del instalador SBOS.
//
// Estructura interna (cada subpaquete es independiente):
//   styles/  — variables lipgloss y funciones de iconos (sin deps bubbletea)
//   screens/ — funciones de renderizado por pantalla (wizard, installing, etc.)
//   demo/    — modo simulación sin daemon
//
// Este paquete resulta de partir cmd/bosctl/install_ui.go (4,834 líneas)
// en componentes cohesivos (Problema P1 de la auditoría).
//
// Referencia: BubbleTea TEA pattern, Elm Architecture
package tui
```

### Criterio de completitud

```bash
go build ./...  # debe pasar — los paquetes vacíos compilan
find internal/ -name "doc.go" | wc -l  # debe ser >= 10
go vet ./...    # debe pasar
```

---

## FASE 1 — Extraer infraestructura de cmd/bos/main.go

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 2-3 días  
**Requiere:** Fase 0 completa  
**Bloquea:** Fases 5, 6  
**Problemas que resuelve:** P4, P6/P14, P12, P15

### Por qué primero (después de Fase 0)

`cmd/bos/main.go` tiene 1,417 líneas porque contiene lógica de sistema operativo que nunca migró a `internal/`. Esto es el problema más crítico del daemon porque:

1. Hace imposible testear `autoBootstrap`, `verifyCgroupDelegation`, `runObserverLoop` sin arrancar el daemon completo como root
2. La race condition entre `runObserverLoop` y `reconcile.Scheduler` (Problema P6/P14) solo se puede corregir cuando el observer vive en su propio paquete con su propio mutex
3. El bug de `startWatchdog` nunca llamada (P12) hace que systemd reinicie el daemon periódicamente si `WatchdogSec` está activo

### Estado actual — qué hay en cmd/bos/main.go que no debería estar ahí

```
Función                     Líneas  Debería estar en
─────────────────────────────────────────────────────────────────
auditLog()                     12   internal/audit/log.go
copyDir()                      15   internal/bootstrap/setup.go
deployFile() [closure]         10   internal/bootstrap/setup.go
autoBootstrap()               150   internal/bootstrap/setup.go
loadBootstrapEnv()             45   internal/bootstrap/setup.go
verifyCgroupDelegation()       25   internal/cgroup/delegate.go
isBareMetal()                  20   internal/cgroup/delegate.go
configureSystemdDelegate()     10   internal/cgroup/delegate.go
detectContainerMapping()       20   internal/cgroup/delegate.go
ensureBridgeNetwork()           8   internal/network/bridge.go
detectNetworkSubnet()          25   internal/network/bridge.go
ensureNftablesForwardRule()    30   internal/network/bridge.go
topologicalSort()              55   internal/plugin/loader.go
depsSatisfied()                12   internal/observer/loop.go
findNextAutoInstall()          35   internal/observer/loop.go
runObserverLoop()              80   internal/observer/loop.go
initializeFichaStates()        30   internal/observer/loop.go
startupReconcile()             25   internal/reconcile/ (existente)
startWatchdog() [nunca llamada] 18  llamarla o eliminarla con doc
─────────────────────────────────────────────────────────────────
TOTAL a mover: ~625 líneas de 1,417
```

### Estado objetivo

- `cmd/bos/main.go`: ~150 líneas — solo `main()`, `runNormal()`, `runConfigPending()`, `shutdown()`
- Cada función listada arriba vive en su paquete correcto con godoc
- La race condition del observer está resuelta con mutex

### Señal de retoma

```bash
# Qué se ha movido ya:
grep -n "func auditLog" internal/audit/log.go 2>/dev/null && echo "audit OK"
grep -n "func autoBootstrap\|func Run" internal/bootstrap/setup.go 2>/dev/null && echo "bootstrap OK"
grep -n "func verifyCgroupDelegation\|func Verify" internal/cgroup/delegate.go 2>/dev/null && echo "cgroup OK"
grep -n "func ensureBridgeNetwork\|func EnsureBridge" internal/network/bridge.go 2>/dev/null && echo "network OK"
grep -n "func runObserverLoop\|func.*Run" internal/observer/loop.go 2>/dev/null && echo "observer OK"
# Qué queda por hacer:
wc -l cmd/bos/main.go  # si > 400, aún hay trabajo
```

### Tareas atómicas

**F1.1 — internal/audit/log.go**

El problema: `auditLog()` se llama 12 veces en main.go con la ruta hardcoded `/var/log/bos/audit.log`. Si la ruta cambia, hay 12 lugares que actualizar. Si se quiere agregar campos al log (como `ctx_id`), hay que hacerlo en 12 lugares.

```
Extraer y renombrar:
  auditLog(path, category, kvs...) → audit.Log(category, kvs...)
  Agregar: audit.LogTo(path, category, kvs...)  para ruta explícita
  Agregar: const DefaultPath = "/var/log/bos/audit.log"

Actualizar en main.go: reemplazar todas las llamadas auditLog(...)
por audit.Log(...) o audit.LogTo(...)
```

Verificar: `grep -n "func auditLog" cmd/bos/main.go` debe retornar vacío.

**F1.2 — internal/cgroup/delegate.go**

El problema: La verificación de cgroups es lógica de sistema operativo de bajo nivel. No puede testearse sin modificar el filesystem del kernel. Debe estar aislada.

```
Tipo público:
  type Manager struct { cgPath string; logger *slog.Logger }
  func New(cgPath string, logger *slog.Logger) *Manager

Métodos:
  func (m *Manager) Verify() bool           ← verifyCgroupDelegation
  func (m *Manager) Configure() error        ← configureSystemdDelegate
  func (m *Manager) DetectMapping() (uid, gid int) ← detectContainerMapping
  func IsBareMetal() bool                    ← función libre, sin estado
```

**F1.3 — internal/network/bridge.go**

El problema: La configuración de nftables es específica del host y no debe estar en el archivo de orquestación del daemon.

```
API pública:
  func EnsureBridge(logger *slog.Logger) error
  func DetectSubnet() string
  func EnsureForwardRule(subnet string, logger *slog.Logger) error
```

**F1.4 — internal/bootstrap/setup.go**

El problema: `autoBootstrap` tiene efectos de sistema (crea directorios, escribe archivos, mata procesos) sin ninguna posibilidad de rollback. Al estar en `main()` no hay forma de testearlo ni aislar sus fallos.

```
Tipo público:
  type Env struct {            ← renombrar bootstrapEnv
      RootUser, RootPassword string
      TenantID, TenantName, TenantDomain string
      HostIP, CGroupPath string
  }

Funciones:
  func LoadEnv() (*Env, error)              ← loadBootstrapEnv
  func Run(env *Env, logger) error          ← autoBootstrap
  func CopyDir(src, dst string) error       ← copyDir
  func DeployFile(src, dst string, mode os.FileMode) error ← deployFile closure

NOTA: bootstrapEnv en main.go es una struct privada. Al moverla
a internal/bootstrap/setup.go como Env, debe actualizarse el tipo
en cmd/bos/main.go para usar bootstrap.Env.
```

**F1.5 — internal/observer/loop.go con corrección de race condition**

El problema es doble:
1. `runObserverLoop` y `reconcile.Scheduler` pueden disparar `Repair()` sobre la misma ficha al mismo tiempo. Los scripts bash de instalación no son idempotentes. Dos ejecuciones paralelas pueden corromper el estado de Kubernetes (Problema P6/P14).
2. `topologicalSort` implementa el algoritmo de Kahn que ordena las 22 fichas. Un bug aquí instala en orden incorrecto. Debe estar en un paquete testeable.

```
Mover a internal/plugin/loader.go:
  topologicalSort()  ← opera sobre FichaManifest, pertenece allí
  (agregar tests unitarios del DAG de 22 fichas)

Tipo público en observer:
  type Observer struct {
      mu          sync.Mutex        ← NUEVO: exclusión mutua para repairs
      orchestrator *installer.Orchestrator
      loader       *plugin.Loader
      stateMgr     *state.Manager
      logger       *slog.Logger
      stopCh       chan struct{}
  }
  func New(orchestrator, loader, stateMgr, logger) *Observer
  func (o *Observer) Run()   ← runObserverLoop
  func (o *Observer) Stop()

CORRECCIÓN RACE CONDITION:
  En Observer.Run(), Phase 3 (auto-repair):
    o.mu.Lock()
    defer o.mu.Unlock()
    // ahora ejecutar orchestrator.Repair()

  El reconcile.Scheduler debe recibir el mismo mutex:
    type Scheduler struct {
        repairMu *sync.Mutex  ← inyectado desde cmd/bos/main.go
    }
  Así ambos comparten el mismo lock y no se ejecutan en paralelo.
```

**F1.6 — Corregir bosRBAC global (P15)**

El problema: `var bosRBAC *security.FileRBAC` es nil antes de que `autoBootstrap` lo inicialice. Si `autoBootstrap` falla antes de llegar al paso RBAC, `bosRBAC` es nil. Luego en `runNormal()` se hace `identityProvider := security.IdentityProvider(bosRBAC)` — una interfaz con valor nil subyacente que panea en runtime al primer uso.

```
SOLUCIÓN:
  autoBootstrap retorna (*security.FileRBAC, error) en lugar de modificar global
  runNormal() recibe rbac como parámetro
  Si RBAC falla → error explícito con log.Fatal, no nil silencioso

  // En main():
  rbac, err := bootstrap.Run(benv, logger)
  if err != nil {
      log.Fatal().Err(err).Msg("bootstrap failed")
  }
  runNormal(cfg, benv, rbac)  // rbac inyectado, no global
```

**F1.7 — Corregir startWatchdog nunca llamada (P12)**

El problema: Si `bos.service` tiene `WatchdogSec=30s` en su unit de systemd, systemd matará y reiniciará el proceso cada 30 segundos porque nunca recibe `WATCHDOG=1`. El daemon se reinicia periódicamente en producción sin causa aparente.

```
SOLUCIÓN A (si se usa systemd watchdog):
  En runNormal(), después de sdNotify("READY=1"):
    shutdownCh := make(chan struct{})
    go startWatchdog(shutdownCh)
    // cerrar shutdownCh en shutdown()

SOLUCIÓN B (si NO se usa systemd watchdog actualmente):
  Eliminar startWatchdog() con un comentario explicativo:
  // startWatchdog eliminada: bos.service no usa WatchdogSec actualmente.
  // Si se habilita en el futuro, ver SBOS-018 §watchdog para re-implementar.

Documentar la decisión tomada en el doc.go del paquete.
```

### Criterio de completitud Fase 1

```bash
go build ./...
go vet ./...
wc -l cmd/bos/main.go                        # debe ser ≤ 400 líneas
grep -c "func auditLog" cmd/bos/main.go      # debe ser 0
grep -c "func autoBootstrap" cmd/bos/main.go # debe ser 0
grep -c "func runObserverLoop" cmd/bos/main.go # debe ser 0
ls internal/audit/log.go                     # debe existir
ls internal/cgroup/delegate.go               # debe existir
ls internal/network/bridge.go               # debe existir
ls internal/bootstrap/setup.go              # debe existir
ls internal/observer/loop.go                # debe existir
grep -n "repairMu" internal/observer/loop.go # debe tener el mutex
```

---

## FASE 2 — Unificar transporte WebSocket

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 1 día  
**Requiere:** Fase 0 completa  
**Bloquea:** Nada directamente, pero es prerequisito para Fase 5 y 6  
**Problemas que resuelve:** P2, P8

### Por qué ahora

El transporte es la base de toda comunicación. Si hay dos clientes WebSocket distintos apuntando al mismo servidor, cualquier cambio de protocolo (nuevo campo, nuevo tipo de mensaje) hay que hacerlo dos veces. Y hay una tercera implementación (`wslib`) que ya existe y ya usa el servidor, pero que el cliente (`bosctl`) ignora.

### Estado actual

Tres implementaciones paralelas del mismo protocolo:

```
1. cmd/bosctl/main.go:wsRequest()
   — Síncrono: abre conexión, envía, lee UNA respuesta, cierra
   — Usa gorilla/websocket
   — Para: status, health, install, shutdown, bootstrap commands

2. cmd/bosctl/install_ui.go:connectWS/sendWS/awaitWS
   — Asíncrono: conexión persistente, goroutine lectora, canal de eventos
   — Usa gorilla/websocket
   — Para: TUI del instalador (recibe eventos saga_start, step_ok, etc.)

3. internal/wslib/websocket.go
   — Implementación propia que reemplaza gorilla (dice el comentario del archivo)
   — Usada por: internal/server/ws.go (el servidor)
   — NO usada por: cmd/bosctl/ (ninguno de los dos clientes)
```

El problema concreto: `wslib` dice `// Replaces gorilla/websocket` pero `bosctl` sigue usando gorilla. El servidor ya migró. El cliente no. Esto crea dos dialectos del mismo protocolo.

### Estado objetivo

- Un solo cliente WS en todo el proyecto: `internal/wslib`
- `gorilla/websocket` eliminado de `go.mod`
- `internal/wslib` extendido con helper para Unix socket

### Señal de retoma

```bash
grep -rn "gorilla/websocket" --include="*.go" .
# Si retorna resultados: la fase no está completa
# Si retorna vacío: la fase está completa
```

### Tareas atómicas

**F2.1 — Auditar y extender internal/wslib/websocket.go**

`wslib.Conn` ya tiene: `WriteJSON`, `ReadJSON`, `ReadMessage`, `WriteMessage`, `Close`, `SetReadDeadline`, `SetWriteDeadline`.

Agregar helper que falta:
```go
// DialUnix establece conexión WebSocket sobre Unix socket.
// Reemplaza el patrón gorilla.Dialer{NetDialContext:...} repetido
// en cmd/bosctl/main.go y cmd/bosctl/install_ui.go.
func DialUnix(socketPath string) (*Conn, error) {
    return DialContext(func() (net.Conn, error) {
        return (&net.Dialer{Timeout: 5 * time.Second}).
            DialContext(context.Background(), "unix", socketPath)
    })
}
```

**F2.2 — Migrar cmd/bosctl/main.go:wsRequest()**

```
ANTES (gorilla):
  dialer := websocket.Dialer{NetDialContext: func(...) { ... }}
  conn, _, err := dialer.DialContext(context.Background(), "ws://unix/ws", nil)
  conn.WriteJSON(req)
  conn.ReadJSON(&resp)

DESPUÉS (wslib):
  conn, err := wslib.DialUnix(socketPath())
  if err != nil { return nil, fmt.Errorf("daemon no disponible: %w", err) }
  defer conn.Close()
  conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
  conn.WriteJSON(req)
  conn.SetReadDeadline(time.Now().Add(30 * time.Second))
  conn.ReadJSON(&resp)
```

**F2.3 — Migrar cmd/bosctl/install_ui.go**

```
ANTES:
  conn, _, err := dialer.DialContext(...)  // gorilla.Conn
  go func() {
      defer func() { recover() }()  // comentario específico de gorilla
      conn.ReadMessage()
  }()

DESPUÉS:
  conn, err := wslib.DialUnix(socketPath)  // wslib.Conn
  go func() {
      // wslib NO panea — no necesita recover()
      // wslib retorna error en ReadMessage() en lugar de panic
      conn.ReadMessage()
  }()

CAMBIAR el tipo en wsEventMsg y sendWS:
  ANTES: wsReadyMsg struct{ conn *websocket.Conn }
  DESPUÉS: wsReadyMsg struct{ conn *wslib.Conn }
```

**F2.4 — Eliminar gorilla de go.mod**

```bash
go mod tidy
grep "gorilla" go.mod   # debe ser vacío
grep "gorilla" go.sum   # debe ser vacío
```

### Criterio de completitud Fase 2

```bash
go build ./...
grep -rn "gorilla/websocket" --include="*.go" .  # debe retornar vacío
grep "gorilla" go.mod                             # debe retornar vacío
grep -n "DialUnix" internal/wslib/websocket.go   # debe existir
```

---

## FASE 3 — Partir install_ui.go

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 3-4 días  
**Requiere:** Fases 0 y 2 completas  
**Bloquea:** Nada directamente  
**Problemas que resuelve:** P1, P3, P7 (parcial), P10, P11

### Por qué esta fase es la más compleja

`install_ui.go` tiene 4,834 líneas en un solo archivo dentro de `package main`. Contiene sin separación: estilos, tipos, lógica TEA, rendering por pantalla, gestión de viewports, detección del sistema, modo demo y entry points. La complejidad no es la cantidad de código — es que todo está acoplado a todo.

El orden importa: si se intenta partir sin un orden correcto, los imports circulares impiden compilar. El orden seguro es de menos dependencias a más.

### El problema TEA (The Elm Architecture) — P3

BubbleTea exige que `Update(msg) (tea.Model, tea.Cmd)` sea pura: recibe por valor, devuelve por valor, sin mutación. El código actual viola esto:

```go
// INCORRECTO — viola TEA:
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    case wsEventMsg:
        m.handleWS(msg)  // ← receptor *model, muta estado directamente
}
func (m *model) handleWS(ev wsEventMsg) { m.fichasOK++ }

// CORRECTO — TEA puro:
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    case wsEventMsg:
        m = handleWS(m, ev)  // ← devuelve copia modificada
        return m, cmd
}
func handleWS(m model, ev wsEventMsg) model { m.fichasOK++; return m }
```

### El problema step/screen — P11

El modelo tiene dos campos para la misma cosa:
```go
type model struct {
    step   Screen  // campo antiguo
    screen Screen  // campo nuevo — el que se usa en View() y footer
}
// Y encima hay un alias incorrecto:
type stepID = Screen
const stepWelcome = ScreenWizardP1  // INCORRECTO: Welcome ≠ WizardP1
```

Algunos eventos actualizan solo `step`, otros solo `screen`, otros ambos. Cuando divergen, el footer muestra controles de una pantalla mientras el contenido muestra otra.

### Orden obligatorio de extracción

Cada paso debe compilar antes de continuar al siguiente.

**F3.1 — internal/tui/styles/styles.go** (sin dependencias)

Este paquete NO importa `bubbletea` ni `bubbles`. Solo `lipgloss`.

```
Extraer de install_ui.go:
  - Constantes: cGreenS, cCyanS, cBlackS, cBg2S, etc.
  - Variables: cGreen, cCyan, sBold, sBox, sTopBar, sBoxActive, etc.
  - Funciones: icOk(), icRun(), icPend(), icErr(), icWarn(), icBos()
  - Helpers: badge(), renderMFARow()

Verificar: go build ./internal/tui/styles/
```

**F3.2 — internal/tui/demo/demo.go** (solo depende de styles y tipos básicos)

```
Extraer de install_ui.go:
  - var demoSubComponents
  - func demoLogLine(ficha, step string) []string
  - func runDemo(ch chan wsEventMsg)

  NOTA: wsEventMsg debe definirse primero en internal/tui/model.go
  o en un types.go compartido. runDemo solo necesita ese tipo.
```

**F3.3 — internal/tui/model.go — tipos y correcciones**

Este es el paso más delicado. Aquí se corrigen los dos bugs de diseño.

```
Mover todos los tipos compartidos:
  type Screen int + constantes ScreenX
  type stepStatus, fichaStatus + constantes
  type fichaDetail, stepDetail, installPhase
  type logEntry + métodos
  type logLevel + constantes
  type wsEventMsg, wsReadyMsg, wsErrorMsg, sysInfoMsg
  type model struct  ← COMPLETO

CORRECCIÓN P11 — eliminar duplicación step/screen:
  ELIMINAR el campo: step Screen
  ELIMINAR el alias: type stepID = Screen
  ELIMINAR las constantes: stepWelcome, stepTenant, etc.
  TODO el código que usa m.step → reemplazar por m.screen

CORRECCIÓN P3 — cambiar receptores puntero a funciones puras:
  ELIMINAR: func (m *model) handleWS(ev wsEventMsg)
  AGREGAR:  func handleWS(m model, ev wsEventMsg) model

  ELIMINAR: func (m *model) addLog(e logEntry)
  AGREGAR:  func addLog(m model, e logEntry) model

  ELIMINAR: func (m *model) fichaOrCreate(id string) (*fichaDetail, model)
  AGREGAR:  func fichaOrCreate(m model, id string) (model, *fichaDetail)

CORRECCIÓN P7 — stopCh no puede ser global:
  ELIMINAR: var stopCh = make(chan struct{})
  En runInteractiveTUI(): stopCh := make(chan struct{})
  Pasar stopCh a connectWS() como parámetro
```

**F3.4 — internal/tui/screens/wizard.go** (P1-P4)

```
Extraer funciones de renderizado y manejo de teclas:
  viewWelcome(m model) string
  viewForm(m model, ...) string
  viewAdmin(m model) string
  viewConfirm(m model) string
  keyWelcome(m model, msg tea.KeyMsg) (model, tea.Cmd)
  keyTenant(m model, msg tea.KeyMsg) (model, tea.Cmd)
  keyAdmin(m model, msg tea.KeyMsg) (model, tea.Cmd)
  keyConfirm(m model, msg tea.KeyMsg) (model, tea.Cmd)
  validateTenant(m model) (model, string)
  validateAdmin(m model) (model, string)

Regla: todas reciben model por VALOR, devuelven model. Sin *model.
```

**F3.5 — internal/tui/screens/installing.go** (P5)

```
Extraer:
  viewInstalling(m model) string
  viewInstallingNormal/XS/SM/MD(m model) string
  buildColAContent(m model, w int) string
  buildColBContent(m model, w int) string
  buildColCContent(m model, w int) string
  vpDims(m model) (wA, wB, wC, h int)
  vScrollbar/hScrollbar(...)  string

CORRECCIÓN P10 — syncViewports con punto de verdad único:
  syncViewports NO se llama desde addLog()
  syncViewports NO se llama desde handleWS()
  syncViewports se llama SOLO desde Update() una vez por ciclo
  
  La regla: addLog() devuelve model con logs actualizado.
  Update() detecta cambio en logs → llama syncViewports una vez.
```

**F3.6 — internal/tui/screens/complete.go y system.go**

```
complete.go: viewComplete, viewCompleteBody, viewCompleteTabBar, viewReboot, viewBoot
system.go: viewSplashWelcome, viewSplashGoodbye, viewDashboard, viewLogs, viewShutdown,
           viewHeader, viewFooter
```

**F3.7 — internal/tui/model.go — Init, Update, View**

```
Completar model.go con:
  func initialModel() model
  func (m model) Init() tea.Cmd
  func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd)
  func (m model) View() string  ← delega a screens/*

Update() puro:
  case wsEventMsg:
      m = handleWS(m, ev)   ← función libre, devuelve model
      m = syncViewports(m)   ← llamado UNA SOLA VEZ aquí
      return m, awaitWS(m.wsCh)
```

**F3.8 — Reducir install_ui.go a entry points (~80 líneas)**

```
install_ui.go resultante:
  func cmdInstallUI(args []string) int
  func runInteractiveTUI() int    ← crea stopCh local, no global
  func runUnattended(seedFile string) int
  var demoMode bool
```

### Criterio de completitud Fase 3

```bash
go build ./...
wc -l cmd/bosctl/install_ui.go      # debe ser ≤ 100
wc -l internal/tui/model.go        # debe ser ≤ 300
grep -rn "func (m \*model)" internal/tui/  # debe ser 0
grep -rn "m\.step" internal/tui/           # debe ser 0
grep -rn "var stopCh" internal/tui/        # debe ser 0
```

---

## FASE 4 — Limpiar cmd/bosctl/

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 1 día  
**Requiere:** Fase 0 completa  
**Bloquea:** Nada  
**Problemas que resuelve:** P5, P7, P9, P13 (parcial), P16

### Por qué esta fase

`cmd/bosctl/` tiene cuatro problemas independientes:
1. `main.go` hace demasiado: router CLI + RBAC + WS helpers + OS commands
2. `bootstrap.go` repite el kubeconfig 6 veces y tiene lógica que debería estar en `internal/`
3. `ensureDaemonRunning` tiene efectos de sistema sin rollback
4. Los paths del sistema están hardcoded en 3 archivos distintos

### Tareas atómicas

**F4.1 — internal/bootstrap/paths.go — paths centralizados**

```go
// paths.go — rutas canónicas del sistema SBOS.
// Un solo lugar para cambiar cualquier ruta.
// Problema P16 de la auditoría: paths hardcoded en múltiples archivos.
package bootstrap

const (
    DefaultSocket      = "/run/bos/bos.sock"
    DefaultKubeconfig  = "/etc/bos/.kube/config"
    DefaultAuditLog    = "/var/log/bos/audit.log"
    DefaultInstallToml = "/etc/bos/bos-install.toml"
    DefaultDaemonBin   = "/opt/bos/bin/bos"
    DefaultStatePath   = "/etc/sbos/tenant.conf"
)

// ResolveKubeconfig retorna la ruta del kubeconfig activo.
// Usa KUBECONFIG si está definida, si no DefaultKubeconfig.
// Reemplaza el bloque de 3 líneas repetido 6 veces en bootstrap.go.
func ResolveKubeconfig() string {
    if k := os.Getenv("KUBECONFIG"); k != "" {
        return k
    }
    return DefaultKubeconfig
}
```

**F4.2 — internal/bootstrap/verify.go — funciones check***

```
Extraer de cmd/bosctl/bootstrap.go y reemplazar kubeconfig x6:
  checkOSBootstrap() bool
  checkKubectl() bool
  checkK8sCluster() (bool, string)
  checkCalico() (bool, string)    ← usa bootstrap.ResolveKubeconfig()
  checkPostgres() (bool, string)  ← usa bootstrap.ResolveKubeconfig()
  checkRedis() (bool, string)     ← usa bootstrap.ResolveKubeconfig()
  checkVault() (bool, string)     ← usa bootstrap.ResolveKubeconfig()
  checkKeycloak() (bool, string)  ← usa bootstrap.ResolveKubeconfig()
  checkKong() (bool, string)      ← usa bootstrap.ResolveKubeconfig()
  runLocalVerify(jsonOutput bool) int
  formatVerifyResult(data interface{}) int

Mover a internal/k8s/core.go:
  runKubectl(kubeconfig string, args ...string) (string, error)

Mover a internal/domain/types.go:
  stateToIconBootstrap(state string) string
```

**F4.3 — Corregir ensureDaemonRunning (P9)**

El problema: escribe `/etc/bos/bos-install.toml` con datos falsos sin verificar si existe uno real con datos de producción, y mata procesos en el puerto 9443 sin confirmación.

```
CORRECCIÓN:
  Antes de escribir bos-install.toml, verificar os.IsNotExist(err)
  correctamente — el código actual lo hace pero con una lógica frágil.
  
  Agregar: if fileHasRealData(installToml) { skip writing }
  
  Reemplazar el kill -9 ciego:
    En lugar de matar cualquier proceso en :9443,
    verificar que sea específicamente "bos" antes de matar.
    Si no es bos, retornar error descriptivo.

Mover ensureDaemonRunning a internal/bootstrap/daemon.go:
  func EnsureRunning(socketPath string, logger) error
```

**F4.4 — cmd/bosctl/os_commands.go**

```
Mover de main.go a os_commands.go:
  cmdExec(args []string) int
  cmdLS(args []string) int
  cmdCat(args []string) int
  cmdTail(args []string) int
  cmdSystemctl(args []string) int
  cmdJournalctl(args []string) int
```

**F4.5 — Corregir globalRBAC (P7)**

```
ANTES (race condition potencial):
  var globalRBAC security.RBACProvider
  func getRBAC() security.RBACProvider {
      if globalRBAC != nil { return globalRBAC }
      globalRBAC = fileRBAC  // escritura sin lock
  }

DESPUÉS (thread-safe):
  var (
      rbacOnce sync.Once
      rbacInst security.RBACProvider
  )
  func getRBAC() security.RBACProvider {
      rbacOnce.Do(func() { rbacInst = initRBAC() })
      return rbacInst
  }
```

### Criterio de completitud Fase 4

```bash
go build ./...
wc -l cmd/bosctl/main.go          # debe ser ≤ 120
wc -l cmd/bosctl/bootstrap.go     # debe ser ≤ 100
grep -c "kubeconfig := os.Getenv" cmd/  # debe ser 0
ls internal/bootstrap/paths.go    # debe existir
ls internal/bootstrap/verify.go   # debe existir
ls cmd/bosctl/os_commands.go      # debe existir
```

---

## FASE 5 — Context Plane completo (SBOS-049)

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 3-4 días  
**Requiere:** Fases 0, 1, 2 completas  
**Bloquea:** Fase 6  
**Problema que resuelve:** Context Plane al 30%

### Por qué esta fase aquí

El Context Plane necesita un paquete propio (`internal/context/`), un cliente WS unificado (Fase 2) para que `bosctl context` pueda comunicarse con el daemon, y los paquetes de infraestructura de la Fase 1 para registrar correctamente los eventos de audit.

### Estado actual vs estado objetivo

**Ahora (30%):**
- `domain.CtxID` struct existe en `internal/domain/types.go`
- `bos.ctx.create` y `bos.ctx.validate` existen en JSON-RPC
- `domain.CtxService.Create()` y `Validate()` existen
- NO hay: dctx_id, promote, switch, invalidate, list, tenant.suspend
- NO hay: almacenamiento en Redis ni en bkernel_db
- NO hay: `bosctl context` subcomandos

**Objetivo (100%):**

El flujo que describes — terminal activa sin usuario → registrar contexto OS → usuario autentica → enriquecer con Keycloak — debe funcionar completo:

```bash
# 1. Terminal arranca (sin usuario autenticado)
bosctl rpc bos.ctx.device.register \
  '{"tenant_id":"skull","hostname":"caja-lpz-23","ip":"10.0.0.55"}'
# Retorna: { "dctx_id": "dctx-device-991", "status": "pre-auth",
#            "bitmask": "0x0", "node": "node-02", "cluster": "cluster-sbos" }
# Contexto OS completo: Ubuntu + K8s + tenant

# 2. Usuario se autentica (KC emite JWT con bos_contexts)
bosctl rpc bos.ctx.promote \
  '{"dctx_id":"dctx-device-991","kc_token":"eyJ...","loa":2}'
# Retorna: { "ctx_id": "ctx-88291-a4f9",
#            "tenant":"skull","empresa":"maya","sucursal":"lapaz",
#            "pos_logico":"POS-23","bitmask":"0x00000000008C87FF",
#            "traceparent":"00-...","expires_at":"..." }
# Contexto enriquecido: OS + empresa + usuario + BitMask
```

### Tareas atómicas

**F5.1 — internal/context/types.go**

```go
// DeviceContext — contexto pre-autenticación.
// Se crea cuando un dispositivo registra su presencia con el bos.
// No requiere usuario. Representa la capa OS: Ubuntu + K8s.
type DeviceContext struct {
    DctxID    string        // "dctx-device-991"
    DeviceID  string        // "DEVICE-991"
    Hostname  string        // "caja-lpz-23"
    IP        string        // "10.0.0.55"
    MAC       string
    NodeK8s   string        // nodo K8s donde corre el dispositivo
    Tenant    string        // tenant al que pertenece
    Status    string        // "pre-auth"
    BitMask   uint64        // 0x0 — nadie autenticado
    CreatedAt time.Time
}

// SessionContext — contexto post-autenticación.
// Creado al promover un DeviceContext tras autenticación con Keycloak.
// Contiene el árbol organizacional completo + BitMask de capacidades.
type SessionContext struct {
    CtxID      string    // "ctx-88291-a4f9"
    DctxIDPrev string    // DeviceContext que fue promovido
    Tenant     string
    Empresa    string
    Sucursal   string
    PosLogico  string
    UserID     string
    SessionKC  string    // ID de sesión de Keycloak
    BitMask    uint64    // calculado por bAuth
    Pod, Namespace, Node, Cluster, VPS, Geo string
    TraceParent string   // W3C: "00-traceId-spanId-flags"
    CreatedAt  time.Time
    ExpiresAt  time.Time
    Status     string    // "active"|"switched"|"expired"|"invalid"
}

// PromoteEvent — auditoría del momento de elevación dctx_id → ctx_id.
type PromoteEvent struct {
    DctxIDAnterior      string
    CtxIDNuevo          string
    UserID              string
    MetodoAuth          string    // "NFC_MIFARE_DESFIRE", "PASSWORD", etc.
    LoAAlcanzado        int
    BitMask             uint64
    ActividadPreAuthSeg int64     // segundos de actividad pre-auth preservada
    Timestamp           time.Time
}
```

**F5.2 — internal/context/service.go**

```
API pública requerida por JSON-RPC (SBOS-049 §10.1):
  func New(logger *slog.Logger) *Service
  func (s *Service) RegisterDevice(deviceID, hostname, ip, tenant string) (*DeviceContext, error)
  func (s *Service) Create(p CreateParams) (*SessionContext, error)
  func (s *Service) Promote(dctxID string, p PromoteParams) (*SessionContext, error)
  func (s *Service) Switch(ctxID string, p SwitchParams) (*SessionContext, error)
  func (s *Service) Invalidate(ctxID string) error
  func (s *Service) Get(ctxID string) (*SessionContext, error)
  func (s *Service) ListByTenant(tenant string) ([]*SessionContext, error)
  func (s *Service) InvalidateAllByTenant(tenant string) (int, error)
  func (s *Service) Validate(traceParent, tenantID string) (*ValidateResult, error)

Almacenamiento Fase 5: en memoria (map con mutex)
Almacenamiento futuro: Redis DB2 (TTL) + bkernel_db.context_sessions
```

**F5.3 — Agregar métodos JSON-RPC al registry**

```go
// En internal/server/jsonrpc.go, agregar en init():
"bos.ctx.device.register"    → rpcCtxDeviceRegister
"bos.ctx.promote"            → rpcCtxPromote
"bos.ctx.switch"             → rpcCtxSwitch
"bos.ctx.invalidate"         → rpcCtxInvalidate
"bos.ctx.get"                → rpcCtxGet
"bos.ctx.list"               → rpcCtxList
"bos.ctx.tenant.suspend"     → rpcCtxTenantSuspend
```

**F5.4 — cmd/bosctl/context.go**

```bash
bosctl context device register --tenant=skull
bosctl context inspect <ctx_id>
bosctl context invalidate <ctx_id>
bosctl context list --tenant=skull
bosctl context history --user=<id> --days=7
```

### Criterio de completitud Fase 5

```bash
go build ./...
bosctl rpc bos.ctx.device.register '{"tenant_id":"test","hostname":"srv-01"}'
# debe retornar un dctx_id
bosctl rpc system.listMethods | grep "bos.ctx" | wc -l
# debe ser >= 7
```

---

## FASE 6 — JSON-RPC robusto

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 1-2 días  
**Requiere:** Fase 5 completa  
**Bloquea:** Nada  
**Problemas que resuelve:** Sin auth en dispatcher, batch en serie, sin timeout, state.read sin filtro, TTL sin validar

### Contexto

Los problemas del JSON-RPC documentados en la auditoría no se pueden resolver bien hasta tener el Context Plane (Fase 5) porque la autenticación del dispatcher se basa en verificar `ctx_id` activo.

### Tareas atómicas

**F6.1 — Autenticación para métodos destructivos**

```go
var destructiveMethods = map[string]bool{
    "bos.ficha.remove":       true,
    "bos.bootstrap.reset":    true,
    "bos.ctx.tenant.suspend": true,
}
// En dispatchRPC(): si isDestructive(method) → verificar ctx_id del header
```

**F6.2 — Timeout por método**

```go
var methodTimeouts = map[string]time.Duration{
    "bos.ficha.list":    5 * time.Second,
    "bos.ctx.get":       2 * time.Second,
    "bos.ficha.install": 30 * time.Minute,
    "bos.saga.execute":  30 * time.Minute,
    // default: 60s
}
```

**F6.3 — Batch con lecturas en paralelo, escrituras en serie**

```go
var readOnlyMethods = map[string]bool{
    "bos.ficha.list":    true,
    "bos.ficha.status":  true,
    "bos.state.read":    true,
    "bos.health.check":  true,
    "bos.ctx.get":       true,
    "system.listMethods": true,
}
```

**F6.4 — bos.state.read sin hashes internos**

```go
// Exponer vista pública sin campos internos de implementación:
// NO exponer: Hashes (SHA-256 internos), Server (path del filesystem),
//             Backend (apt/pip/helm — implementación interna)
```

**F6.5 — Validación de TTL en bos.ctx.create**

```go
const ctxTTLMin     = 5 * time.Minute
const ctxTTLMax     = 12 * time.Hour   // ISO 27001 — sesión razonable
const ctxTTLDefault = 8 * time.Hour
```

### Criterio de completitud Fase 6

```bash
go build ./...
bosctl rpc bos.ficha.remove '{"ficha_id":"test"}' 2>&1 | grep -i "denied\|auth\|unauthorized"
bosctl rpc bos.state.read | python3 -c "import json,sys; d=json.load(sys.stdin); \
  fichas=list(d['fichas'].values()); print('hashes' in fichas[0] if fichas else 'ok')"
# debe imprimir False (no expone hashes)
```

---

## FASE 7 — Documentación del código

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** Continuo — 30 min por paquete  
**Requiere:** Corre en paralelo con cada fase  
**Bloquea:** Nada

### Principio

La documentación se escribe mientras se codifica, no después. Cada función exportada que se crea o mueve debe llegar con su godoc. Esta fase no es un bloque de tiempo al final — es una disciplina aplicada en cada commit.

### Estándar de documentación

**Para paquetes (doc.go):**
```
1. Propósito en una línea
2. Responsabilidades (lista)
3. Lo que NO hace (fronteras)
4. Referencia al ADR o documento SBOS
```

**Para funciones exportadas:**
```go
// FunctionName hace X dado Y.
// Retorna Z cuando todo está bien.
// Retorna error si W ocurre — el error incluye contexto con %w.
func FunctionName(param Type) (Result, error)
```

**Para el JSON-RPC registry (obligatorio):**
```go
// rpcRegistry — catálogo completo de métodos JSON-RPC 2.0.
// Convención: bos.<modulo>.<operacion>
// Módulos: ficha | bootstrap | saga | state | health | ctx | release | system
// Para agregar: una línea en init(). El dispatcher no cambia.
```

### Entregables específicos

- `cmd/bos/README.md` — qué es el daemon, modos, flags, env vars
- `cmd/bosctl/README.md` — qué es bosctl, todos los subcomandos con ejemplos
- `godoc` completo en: `internal/observer`, `internal/context`, `internal/bootstrap`, `internal/audit`

### Criterio de completitud Fase 7

```bash
# Verificar que no hay funciones exportadas sin godoc:
go doc ./internal/observer/ | grep -c "^func"
go doc ./internal/context/  | grep -c "^func"
# Si retorna 0 hay un problema (las funciones existen pero no documentadas)
ls cmd/bos/README.md      # debe existir
ls cmd/bosctl/README.md   # debe existir
```

---

## FASE 8 — Tests

**Estado:** 🔴 NO INICIADA  
**Duración estimada:** 2-3 días  
**Requiere:** Cada fase debe tener sus tests antes de declararse completa  
**Bloquea:** Nada

### Por qué los tests son parte del plan principal

Sin tests, no se puede saber si una refactorización rompió algo. La race condition del observer (P6/P14) es imposible de detectar sin un test de concurrencia. La corrección TEA (P3) es imposible de verificar sin un test que ejecute `Update()` dos veces y compare estados.

### Tests prioritarios (en orden de criticidad)

**T1 — internal/observer: race condition** (el más crítico)
```go
func TestObserver_NoParallelRepair(t *testing.T) {
    // Dos goroutines llaman Run() simultáneamente con una ficha DEGRADADA
    // Verificar que Repair() se llama exactamente una vez, no dos
}
func TestTopologicalSort_DAGDe22Fichas(t *testing.T) {
    // El DAG completo de 22 fichas debe ordenarse correctamente
    // PostgreSQL debe aparecer ANTES que Keycloak
    // sbos-bootstrap-k8s debe aparecer ANTES que postgresql
}
```

**T2 — internal/context: ciclo completo**
```go
func TestRegisterDevice_RetornaContextoOS(t *testing.T)
func TestPromote_EnriqueceBitMask(t *testing.T)
func TestInvalidate_CtxYaNoValido(t *testing.T)
func TestTTL_MinimoYMaximo(t *testing.T)
func TestInvalidateAllByTenant_LimpiaSession(t *testing.T)
```

**T3 — internal/tui/model: corrección TEA**
```go
func TestHandleWS_NoMutaModeloOriginal(t *testing.T) {
    m1 := initialModel()
    m2 := handleWS(m1, wsEventMsg{evType: "saga_ok", ficha: "test"})
    assert.Equal(t, 0, m1.fichasOK, "el modelo original no debe cambiar")
    assert.Equal(t, 1, m2.fichasOK, "el nuevo modelo debe tener el cambio")
}
func TestUpdate_SoloCampaScreen_NoStep(t *testing.T) {
    // Verificar que no existe m.step — solo m.screen
}
```

**T4 — internal/bootstrap: verificación**
```go
func TestResolveKubeconfig_UsaEnvVar(t *testing.T)
func TestResolveKubeconfig_UsaDefault(t *testing.T)
func TestCheckOSBootstrap_SysctlPresente(t *testing.T)
```

### Criterio de completitud Fase 8

```bash
go test ./internal/observer/...  # debe pasar
go test ./internal/context/...   # debe pasar
go test ./internal/tui/...       # debe pasar
go test ./internal/bootstrap/... # debe pasar
go test -race ./internal/...     # sin race conditions detectadas
```

---

## Criterios de completitud del plan completo

El plan está **terminado** cuando todos estos comandos pasan:

```bash
# Compilación y análisis
go build ./...
go vet ./...
go test -race ./...

# Tamaños objetivo
[ $(wc -l < cmd/bos/main.go) -le 200 ]           && echo "bos/main OK"
[ $(wc -l < cmd/bosctl/main.go) -le 120 ]         && echo "bosctl/main OK"
[ $(wc -l < cmd/bosctl/install_ui.go) -le 100 ]   && echo "install_ui OK"
[ $(wc -l < cmd/bosctl/bootstrap.go) -le 100 ]    && echo "bootstrap OK"

# Sin duplicaciones
[ $(grep -rn "gorilla/websocket" --include="*.go" . | wc -l) -eq 0 ]  && echo "ws OK"
[ $(grep -rn "func auditLog" cmd/ --include="*.go" | wc -l) -eq 0 ]   && echo "audit OK"
[ $(grep -rn "kubeconfig := os.Getenv" cmd/ --include="*.go" | wc -l) -eq 0 ] && echo "kubeconfig OK"

# Sin violaciones TEA
[ $(grep -rn "func (m \*model)" internal/tui/ | wc -l) -eq 0 ]  && echo "TEA OK"
[ $(grep -rn "m\.step" internal/tui/ | wc -l) -eq 0 ]           && echo "screen OK"

# Context Plane funcional
bosctl rpc bos.ctx.device.register '{"tenant_id":"test","hostname":"srv"}' | grep dctx_id
bosctl rpc system.listMethods | grep "bos.ctx" | wc -l  # >= 7

# Documentación
ls cmd/bos/README.md cmd/bosctl/README.md
go doc ./internal/observer/ > /dev/null
go doc ./internal/context/ > /dev/null
```

---

## Registro de progreso

Actualizar esta tabla al terminar cada tarea atómica:

| Tarea | Completada | Fecha | Notas |
|---|---|---|---|
| F0.1 internal/audit/doc.go | ☐ | | |
| F0.2 internal/bootstrap/doc.go | ☐ | | |
| F0.3 internal/cgroup/doc.go | ☐ | | |
| F0.4 internal/network/doc.go | ☐ | | |
| F0.5 internal/observer/doc.go | ☐ | | |
| F0.6 internal/context/doc.go | ☐ | | |
| F0.7 internal/tui/doc.go | ☐ | | |
| F1.1 internal/audit/log.go | ☐ | | |
| F1.2 internal/cgroup/delegate.go | ☐ | | |
| F1.3 internal/network/bridge.go | ☐ | | |
| F1.4 internal/bootstrap/setup.go | ☐ | | |
| F1.5 internal/observer/loop.go + mutex | ☐ | | race condition P6/P14 |
| F1.6 bosRBAC → sin global nil | ☐ | | P15 |
| F1.7 startWatchdog → llamar o eliminar | ☐ | | P12 |
| F2.1 wslib.DialUnix() | ☐ | | |
| F2.2 wsRequest → wslib | ☐ | | |
| F2.3 connectWS → wslib, eliminar recover() | ☐ | | |
| F2.4 go mod tidy, eliminar gorilla | ☐ | | |
| F3.1 tui/styles/styles.go | ☐ | | |
| F3.2 tui/demo/demo.go | ☐ | | |
| F3.3 tui/model.go tipos + correcciones P3/P11/P7 | ☐ | | CRÍTICO |
| F3.4 tui/screens/wizard.go | ☐ | | |
| F3.5 tui/screens/installing.go + P10 | ☐ | | |
| F3.6 tui/screens/complete.go + system.go | ☐ | | |
| F3.7 tui/model.go Init/Update/View | ☐ | | |
| F3.8 install_ui.go → ~80 líneas | ☐ | | |
| F4.1 internal/bootstrap/paths.go | ☐ | | |
| F4.2 internal/bootstrap/verify.go | ☐ | | |
| F4.3 ensureDaemonRunning → internal/bootstrap/daemon.go | ☐ | | P9 |
| F4.4 os_commands.go | ☐ | | |
| F4.5 globalRBAC → sync.Once | ☐ | | P7 |
| F5.1 internal/context/types.go | ☐ | | |
| F5.2 internal/context/service.go | ☐ | | |
| F5.3 JSON-RPC nuevos métodos ctx | ☐ | | 7 métodos |
| F5.4 cmd/bosctl/context.go | ☐ | | |
| F6.1 auth métodos destructivos | ☐ | | |
| F6.2 timeout por método | ☐ | | |
| F6.3 batch paralelo | ☐ | | |
| F6.4 state.read sin hashes | ☐ | | |
| F6.5 TTL validación ctx | ☐ | | |
| F7 godoc observer | ☐ | | |
| F7 godoc context | ☐ | | |
| F7 godoc bootstrap | ☐ | | |
| F7 README cmd/bos + cmd/bosctl | ☐ | | |
| T1 tests observer race condition | ☐ | | |
| T2 tests context plane | ☐ | | |
| T3 tests TEA corrección | ☐ | | |
| T4 tests bootstrap verify | ☐ | | |
| F9.1 manifest.yml schema scaling+maintenance+slos | ☐ | | ADR-004 |
| F9.2 internal/k8s/core.go Scale/Cordon/Uncordon/Drain/Evict | ☐ | | |
| F9.3 internal/scaler/ escalado coordinado HPA+VPA | ☐ | | death spiral |
| F9.4 internal/maintenance/ saga cordon→drain→op→uncordon | ☐ | | |
| F9.5 jsonrpc: bos.k8s.* métodos | ☐ | | |
| F9.6 jsonrpc: bos.maintenance.* métodos | ☐ | | |
| F9.7 jsonrpc: bos.ficha.scale + bos.ficha.upgrade | ☐ | | |
| F9.8 k8s/bosagent-clusterrole.yaml least privilege | ☐ | | CIS 4.1.1 |
| F9.9 internal/metrics/ métricas Prometheus escalado | ☐ | | |
| F9.10 cmd/bosctl/infra.go subcomandos | ☐ | | |
| T9 TestScaleCoordinated_NoDeathSpiral | ☐ | | |
| T9 TestMaintenanceSaga_Compensates | ☐ | | |

---

*Plan de Acción BosAgent/SBOS v2.0 — Junio 2026*  
*Referencia: auditoria_tecnica_bosagent.md (16 problemas con evidencia de código)*  
*Referencia: SBOS-049-CONTEXT-PLANE v3.0 — arquitectura Context Plane*  
*Referencia: SBOS-MANUAL-ACOPLAMIENTO v2.0 — contratos entre daemons*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
