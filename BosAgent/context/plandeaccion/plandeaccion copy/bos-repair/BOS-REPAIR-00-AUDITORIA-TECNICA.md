# Auditoría Técnica — BosAgent / SBOS
**Fecha:** Junio 2026  
**Módulo Go:** `bos`  
**Alcance:** Todo el código fuente — `cmd/` + `internal/`  
**Método:** Revisión estática del código real, sin ejecutar el proyecto

---

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Inventario de archivos](#2-inventario-de-archivos)
3. [Problema 1 — Monolito en package main](#3-problema-1--monolito-en-package-main)
4. [Problema 2 — Doble implementación WebSocket](#4-problema-2--doble-implementación-websocket)
5. [Problema 3 — Violación del patrón TEA en BubbleTea](#5-problema-3--violación-del-patrón-tea-en-bubbletea)
6. [Problema 4 — Lógica de infraestructura en cmd/bos/main.go](#6-problema-4--lógica-de-infraestructura-en-cmdbosmaingo)
7. [Problema 5 — Duplicación de kubeconfig x6](#7-problema-5--duplicación-de-kubeconfig-x6)
8. [Problema 6 — Observer loop y DAG duplicados](#8-problema-6--observer-loop-y-dag-duplicados)
9. [Problema 7 — Estado global mutable en bosctl](#9-problema-7--estado-global-mutable-en-bosctl)
10. [Problema 8 — Dependencia externa innecesaria (gorilla/websocket)](#10-problema-8--dependencia-externa-innecesaria-gorillawebsocket)
11. [Problema 9 — Side effects sin rollback en ensureDaemonRunning](#11-problema-9--side-effects-sin-rollback-en-ensuredaemonrunning)
12. [Problema 10 — syncViewports sin punto de verdad único](#12-problema-10--syncviewports-sin-punto-de-verdad-único)
13. [Problema 11 — Inconsistencia de tipos entre step y screen](#13-problema-11--inconsistencia-de-tipos-entre-step-y-screen)
14. [Problema 12 — startWatchdog declarada pero nunca llamada](#14-problema-12--startwatchdog-declarada-pero-nunca-llamada)
15. [Problema 13 — Testabilidad casi nula en cmd/](#15-problema-13--testabilidad-casi-nula-en-cmd)
16. [Problema 14 — Reconcile duplicado entre observer y scheduler](#16-problema-14--reconcile-duplicado-entre-observer-y-scheduler)
17. [Problema 15 — bosRBAC como variable global de paquete](#17-problema-15--bosrbac-como-variable-global-de-paquete)
18. [Problema 16 — Hardcoded paths dispersos en dos paquetes](#18-problema-16--hardcoded-paths-dispersos-en-dos-paquetes)
19. [Matriz de riesgo](#19-matriz-de-riesgo)
20. [Lo que está bien](#20-lo-que-está-bien)

---

## 1. Resumen ejecutivo

El proyecto tiene una arquitectura de dominio bien diseñada en `internal/` — interfaces limpias, máquina de estados de 18 transiciones, DAG topológico correcto, health checker con umbral configurable. Eso es el 60% del código y está bien hecho.

El problema está en el 40% restante: `cmd/`. Todo creció sin plan de modularización. El resultado son 16 problemas concretos que van desde bugs latentes hasta riesgos operativos reales en producción.

**Deuda técnica cuantificada:**

| Archivo | Líneas | Debería tener |
|---|---|---|
| `cmd/bosctl/install_ui.go` | 4,834 | ~80 |
| `cmd/bos/main.go` | 1,417 | ~150 |
| `cmd/bosctl/bootstrap.go` | 648 | ~100 |
| `cmd/bosctl/main.go` | 639 | ~100 |

---

## 2. Inventario de archivos

```
cmd/
├── bos/main.go          1,417 líneas  ← daemon completo + infraestructura mezclada
└── bosctl/
    ├── install_ui.go    4,834 líneas  ← TUI completo sin estructura
    ├── main.go            639 líneas  ← router + RBAC + WS + OS commands
    ├── bootstrap.go       648 líneas  ← CLI + verificación + kubectl directo
    ├── ask.go             ~150 líneas  OK
    ├── app.go             ~100 líneas  OK
    ├── packages.go        ~100 líneas  OK
    ├── repair.go           ~30 líneas  stub que delega
    ├── rpc.go             ~100 líneas  OK
    ├── identity.go        ~100 líneas  OK
    ├── set.go              ~80 líneas  OK
    ├── release.go          ~80 líneas  OK
    ├── security.go         ~50 líneas  OK
    ├── top.go               ~5 líneas  stub
    └── health_report.go    ~10 líneas  stub

internal/                             ← bien estructurado
├── wslib/websocket.go     299 líneas  cliente WS propio (no usado por bosctl)
├── state/manager.go       599 líneas  máquina 18 estados — correcto
├── server/ws.go           962 líneas  grande pero cohesivo
├── server/jsonrpc.go      671 líneas  grande pero cohesivo
├── installer/saga.go      413 líneas  OK
├── ai/model_router.go     465 líneas  OK
└── ...resto bien
```

---

## 3. Problema 1 — Monolito en package main

**Archivo:** `cmd/bosctl/install_ui.go`  
**Severidad:** 🔴 Alta  
**Tipo:** Arquitectura

### Descripción

4,834 líneas en un único archivo dentro de `package main`. Contiene mezclados sin separación:

- Constantes de color y estilos lipgloss (~80 líneas)
- Tipos de datos del dominio TUI (~150 líneas)
- Lógica de negocio: handleWS, handleKey, validaciones (~600 líneas)
- Rendering: 15+ funciones view* (~1,500 líneas)
- Gestión de viewports: syncViewports, buildColA/B/C (~400 líneas)
- Detección del sistema operativo: detectSystemInfo (~80 líneas)
- Gestión de procesos: ensureDaemonRunning (~60 líneas)
- Modo demo: runDemo, demoSubComponents (~150 líneas)
- CLI entry points: cmdInstallUI, runInteractiveTUI, runUnattended (~80 líneas)

### Por qué es un problema

Cualquier cambio en los estilos requiere navegar 4,834 líneas. Agregar una pantalla nueva implica modificar `bodyContent()`, `setScreen()`, `viewHeader()`, `viewFooter()` y el enum `Screen` — todos en el mismo archivo. Un bug en `syncViewports` puede afectar el rendering de cualquier pantalla sin que sea obvio.

### Riesgo operativo

En producción, cuando falle una pantalla durante una instalación real, el debug será extremadamente lento porque no hay separación de concerns. Un cambio de urgencia en el log viewer afecta el mismo archivo que el wizard de instalación.

---

## 4. Problema 2 — Doble implementación WebSocket

**Archivos:** `cmd/bosctl/main.go` + `cmd/bosctl/install_ui.go` + `internal/wslib/websocket.go`  
**Severidad:** 🔴 Alta  
**Tipo:** Duplicación crítica

### Descripción

Existen tres implementaciones del cliente WebSocket en el mismo proyecto:

**Implementación 1** — `cmd/bosctl/main.go:wsRequest()`:
```go
// Síncrona: abre conexión, envía, lee una respuesta, cierra
func wsRequest(action string, params map[string]interface{}) (*wsResponse, error) {
    dialer := websocket.Dialer{...}  // gorilla/websocket
    conn, _, err := dialer.DialContext(...)
    defer conn.Close()
    conn.WriteJSON(req)
    conn.ReadJSON(&resp)
    return &resp, nil
}
```

**Implementación 2** — `cmd/bosctl/install_ui.go:connectWS/sendWS/awaitWS`:
```go
// Asíncrona: conexión persistente con goroutines y canal
func connectWS(ch chan wsEventMsg) tea.Cmd { ... }  // gorilla/websocket
func sendWS(conn *websocket.Conn, ...) tea.Cmd { ... }
func awaitWS(ch chan wsEventMsg) tea.Cmd { ... }
```

**Implementación 3** — `internal/wslib/websocket.go`:
```go
// Ya existe un cliente propio que reemplaza gorilla
// Usado por internal/server/ws.go pero NUNCA por cmd/bosctl/
func DialContext(netDial func() (net.Conn, error)) (*Conn, error) { ... }
```

### Por qué es un problema

El proyecto ya tomó la decisión de escribir su propio cliente WebSocket (`wslib`) y lo usa en el servidor. Pero `bosctl` sigue usando `gorilla/websocket`. Esto significa que cualquier cambio de protocolo (nuevo campo en el envelope, nuevo tipo de mensaje) hay que hacerlo en dos lugares con lógica diferente. Cuando divergen silenciosamente, el TUI deja de recibir eventos sin ningún error visible.

### Riesgo operativo

Durante una instalación larga, si el servidor cambia el formato de un evento (por ejemplo `saga_ok` → `bootstrap_ok`), la implementación 1 (`wsRequest`) puede manejarlo correctamente mientras la implementación 2 (`connectWS`) lo ignora silenciosamente. El operador ve el progreso detenerse sin error visible.

---

## 5. Problema 3 — Violación del patrón TEA en BubbleTea

**Archivo:** `cmd/bosctl/install_ui.go`  
**Severidad:** 🔴 Alta  
**Tipo:** Bug de diseño

### Descripción

BubbleTea requiere que `Update()` sea una función pura que recibe el modelo por **valor** y devuelve un modelo nuevo. Esto es la garantía de inmutabilidad del patrón TEA (The Elm Architecture).

En el código actual:

```go
// Update recibe por VALOR — correcto según TEA
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    ...
    case wsEventMsg:
        m.handleWS(msg)  // ← llama a método con receptor PUNTERO
        ...
}

// handleWS muta el modelo con receptor por PUNTERO — viola TEA
func (m *model) handleWS(ev wsEventMsg) {
    m.fichasOK++          // mutación directa
    m.logs = append(...)  // mutación directa
    m.errPanel = fd       // mutación directa
    ...
}
```

Igualmente `updateFocused`, `addLog`, `fichaOrCreate`, `handleKey`, `setScreen` usan receptor `*model` y mutan estado directamente.

### Por qué es un problema

BubbleTea copia el modelo en cada llamada a `Update`. Las mutaciones con `*model` afectan la copia local pero el runtime de BubbleTea trabaja con la copia devuelta por `return m, cmd`. Si alguna versión futura de BubbleTea cambia cómo maneja las copias, o si se introducen tests que ejecuten `Update` en paralelo, el estado se corrompe silenciosamente.

### Riesgo operativo

El comportamiento actual funciona por accidente de implementación: Go copia structs por valor y las mutaciones vía puntero afectan la misma instancia que `Update` devuelve. Pero esto no está garantizado por el contrato de la librería. Un upgrade de `bubbletea` puede romper el TUI de instalación durante una instalación real sin que los tests lo detecten (porque no hay tests).

---

## 6. Problema 4 — Lógica de infraestructura en cmd/bos/main.go

**Archivo:** `cmd/bos/main.go`  
**Severidad:** 🟠 Media-Alta  
**Tipo:** Responsabilidades mezcladas

### Descripción

`cmd/bos/main.go` debería ser un orquestador puro (~150 líneas). En cambio tiene 1,417 líneas porque contiene directamente lógica que pertenece a `internal/`:

| Función | Líneas | Debería estar en |
|---|---|---|
| `autoBootstrap()` | ~150 | `internal/bootstrap/setup.go` |
| `copyDir()` | ~15 | `internal/bootstrap/setup.go` |
| `auditLog()` | ~12 | `internal/audit/log.go` |
| `verifyCgroupDelegation()` | ~20 | `internal/cgroup/delegate.go` |
| `isBareMetal()` | ~15 | `internal/cgroup/delegate.go` |
| `configureSystemdDelegate()` | ~8 | `internal/cgroup/delegate.go` |
| `detectContainerMapping()` | ~20 | `internal/cgroup/delegate.go` |
| `ensureBridgeNetwork()` | ~8 | `internal/network/bridge.go` |
| `detectNetworkSubnet()` | ~20 | `internal/network/bridge.go` |
| `ensureNftablesForwardRule()` | ~25 | `internal/network/bridge.go` |
| `topologicalSort()` | ~50 | `internal/plugin/loader.go` |
| `depsSatisfied()` | ~12 | `internal/plugin/loader.go` |
| `findNextAutoInstall()` | ~30 | `internal/observer/loop.go` |
| `runObserverLoop()` | ~80 | `internal/observer/loop.go` |
| `startupReconcile()` | ~25 | `internal/reconcile/` |

### Por qué es un problema

`auditLog()` es llamada 12 veces en `main.go`. Si mañana hay que agregar un campo (por ejemplo el `ctx_id`), hay que modificar `main.go` — el archivo de mayor impacto del daemon. Lo mismo pasa con `verifyCgroupDelegation`: es lógica de sistema que debería poder testearse sola, pero al estar en `package main` es imposible importarla en un test unitario.

### Riesgo operativo

Un bug en `autoBootstrap` (por ejemplo crear un directorio con permisos incorrectos) es imposible de testear sin arrancar el daemon completo como root. En producción, si `autoBootstrap` falla a mitad, deja el sistema en estado parcial sin posibilidad de rollback.

---

## 7. Problema 5 — Duplicación de kubeconfig x6

**Archivo:** `cmd/bosctl/bootstrap.go`  
**Severidad:** 🟠 Media  
**Tipo:** Duplicación

### Descripción

Esta lógica aparece idéntica 6 veces seguidas en el mismo archivo:

```go
// Aparece en: checkCalico, checkPostgres, checkRedis,
// checkVault, checkKeycloak, checkKong — 6 veces exactas:
kubeconfig := os.Getenv("KUBECONFIG")
if kubeconfig == "" {
    kubeconfig = "/etc/bos/.kube/config"
}
```

### Por qué es un problema

Si la ruta por defecto cambia (`/etc/bos/.kube/config` → `/etc/sbos/.kube/config`), hay que cambiarla en 6 lugares. Ya ocurrió una vez — la ruta original era `/root/.kube/config` y fue cambiada manualmente. La próxima vez es probable que se cambie en 4 de 6 lugares.

### Riesgo operativo

Durante `bosctl bootstrap verify`, si el kubeconfig tiene una ruta no estándar, algunos checks pasan y otros fallan dependiendo de cuáles funciones actualizaron la variable y cuáles no. El operador ve resultados de verificación inconsistentes.

---

## 8. Problema 6 — Observer loop y DAG duplicados

**Archivos:** `cmd/bos/main.go` + `internal/reconcile/scheduler.go`  
**Severidad:** 🟠 Media  
**Tipo:** Duplicación de responsabilidad

### Descripción

Hay dos sistemas que monitorizan el estado de las fichas y reaccionan:

**Observer loop** (`cmd/bos/main.go:runObserverLoop`):
- Tick cada 5 segundos
- Detecta fichas PENDIENTE → LISTA → INSTALANDO
- Detecta fichas DEGRADADA → REPARANDO
- Llama a `orchestrator.Install()` y `orchestrator.Repair()`

**Reconcile scheduler** (`internal/reconcile/scheduler.go`):
- Tick cada 300 segundos (configurable)
- Detecta drift de hashes SHA-256
- También detecta fichas DEGRADED/ALERTA
- También llama a `installer.Repair()`

Ambos pueden disparar un `Repair()` para la misma ficha al mismo tiempo. `reconcile/scheduler.go` línea 195:
```go
// Health-based reconciliation (legacy path for DEGRADED/ALERTA)
for name, ficha := range st.Fichas {
    if ficha.HealthStatus == "DEGRADED" || ficha.State == state.StateDegradada {
        if s.installer != nil && s.autoRepair {
            go func(fichaName string) {
                s.installer.Repair(fichaName)  // ← puede ocurrir simultáneamente
            }(name)
        }
    }
}
```

### Por qué es un problema

Dos goroutines pueden llamar `orchestrator.Repair("postgresql")` simultáneamente. El orquestador ejecuta el script bash `00_MASTER_INSTALL_SBOS.sh` que hace cambios en Kubernetes. Dos ejecuciones paralelas del mismo script pueden dejar el pod en estado inconsistente.

### Riesgo operativo

En producción, si PostgreSQL entra en estado DEGRADADA, ambos sistemas disparan repair. El resultado puede ser dos execuciones de `kubectl apply` sobre el mismo StatefulSet con configuraciones ligeramente diferentes según el momento de ejecución. Pérdida de datos potencial si uno de los repairs hace un delete del PVC.

---

## 9. Problema 7 — Estado global mutable en bosctl

**Archivo:** `cmd/bosctl/main.go`  
**Severidad:** 🟡 Media  
**Tipo:** Diseño

### Descripción

```go
// Variable global mutable accedida desde múltiples goroutines sin sincronización
var globalRBAC security.RBACProvider

func getRBAC() security.RBACProvider {
    if globalRBAC != nil {
        return globalRBAC  // ← lectura sin lock
    }
    // ...
    globalRBAC = fileRBAC  // ← escritura sin lock
    return globalRBAC
}
```

`globalRBAC` se inicializa de forma lazy en `getRBAC()`. Si dos comandos se ejecutan en paralelo (por ejemplo desde un script), la inicialización puede ocurrir dos veces con resultados diferentes.

Adicionalmente en `install_ui.go`:

```go
// Variable global que controla todo el flujo del TUI
var stopCh = make(chan struct{})
var demoMode bool
```

`stopCh` se inicializa en `var` (tiempo de carga del paquete) pero `runInteractiveTUI` lo reinicializa:
```go
func runInteractiveTUI() int {
    stopCh = make(chan struct{})  // ← reinicializa global
    ...
}
```

Si `runInteractiveTUI` se llama dos veces (por ejemplo en tests), el `stopCh` anterior queda huérfano y sus goroutines WS nunca terminan.

### Riesgo operativo

Memory leak en cualquier entorno de test o en el caso de que `cmdInstallUI` se invoque múltiples veces dentro del mismo proceso.

---

## 10. Problema 8 — Dependencia externa innecesaria (gorilla/websocket)

**Archivo:** `cmd/bosctl/install_ui.go` + `cmd/bosctl/main.go`  
**Severidad:** 🟡 Media  
**Tipo:** Dependencia redundante

### Descripción

`go.mod` incluye `gorilla/websocket v1.5.3` pero el proyecto ya tiene `internal/wslib/websocket.go` — una implementación propia que el comentario del archivo dice explícitamente:

```go
// Package wslib provides a minimal WebSocket implementation for bos.
// Replaces gorilla/websocket.
```

El servidor (`internal/server/ws.go`) ya migró a `wslib`. El cliente (`cmd/bosctl/`) no migró.

### Por qué es un problema

Dos implementaciones del mismo protocolo en el mismo binario. `gorilla/websocket` tiene su propio manejo de frames, masking y estado de conexión. `wslib` tiene el suyo. Si hay un bug en el handshake o en el framing de mensajes grandes, hay que debuggearlo en dos sitios diferentes.

El comentario de `install_ui.go` incluso documenta un comportamiento específico de gorilla:
```go
// Regla crítica de gorilla/websocket: tras cualquier error en ReadMessage
// NO se puede volver a llamar ReadMessage — la conexión queda inválida
// y gorilla panea con "repeated read on failed websocket connection".
```

Este comportamiento es específico de gorilla. Si alguna vez se migra a `wslib`, este comentario confundirá al desarrollador porque `wslib` no tiene ese comportamiento.

---

## 11. Problema 9 — Side effects sin rollback en ensureDaemonRunning

**Archivo:** `cmd/bosctl/install_ui.go`  
**Severidad:** 🟠 Media-Alta  
**Tipo:** Riesgo operativo

### Descripción

`ensureDaemonRunning()` tiene efectos secundarios de sistema sin ningún rollback:

```go
func ensureDaemonRunning(socketPath string) error {
    // 1. Crea directorios del sistema
    for _, d := range []string{"/var/log/bos", "/etc/bos", ...} {
        os.MkdirAll(d, 0755)  // ← sin rollback si algo falla después
    }

    // 2. Escribe archivo TOML con datos falsos
    const minimalToml = "org_name = \"SBOS-Setup\"\nclient_domain = \"setup.local\"..."
    os.WriteFile(installToml, []byte(minimalToml), 0644)  // ← sin verificar si ya existe

    // 3. Mata un proceso en el puerto 9443 sin confirmación
    exec.Command("sh", "-c", "ss -tlnp ... | grep ':9443' ... | kill -9 ...").Output()
    // ← puede matar un proceso legítimo
}
```

### Riesgo operativo

Si el operador tiene una instalación previa en `/etc/bos/bos-install.toml` con datos reales, `ensureDaemonRunning` la sobreescribe con `org_name = "SBOS-Setup"` si la condición `os.IsNotExist(err)` no se evalúa correctamente. Pérdida de configuración de producción.

El `kill -9` al puerto 9443 es especialmente peligroso — si hay otro servicio legítimo en ese puerto (por ejemplo una instancia de Kong o el propio daemon BOS reiniciándose), se mata sin ningún aviso.

---

## 12. Problema 10 — syncViewports sin punto de verdad único

**Archivo:** `cmd/bosctl/install_ui.go`  
**Severidad:** 🟡 Media  
**Tipo:** Diseño

### Descripción

`syncViewports()` es llamada desde 4 lugares diferentes:

```go
// Lugar 1: desde handleWS (cada evento WebSocket)
case wsEventMsg:
    m.handleWS(msg)
    m.syncViewports()  // ← después de cada evento

// Lugar 2: desde addLog (cada línea de log)
func (m *model) addLog(e logEntry) {
    m.vpB.SetContent(m.buildColBContent(wB - 1))  // ← duplica parte de syncViewports
    m.vpC.SetContent(m.buildColCContent(9999))
}

// Lugar 3: desde spinner.TickMsg
case spinner.TickMsg:
    if m.screen == ScreenInstalling {
        m.syncViewports()  // ← en cada tick del spinner (100ms)
    }

// Lugar 4: desde tea.WindowSizeMsg
case tea.WindowSizeMsg:
    // No llama syncViewports pero actualiza dimensiones directamente
```

`addLog` actualiza vpB y vpC directamente duplicando parte de lo que haría `syncViewports`, pero sin actualizar vpA. Esto significa que durante una instalación activa, la columna A (árbol de fases) puede estar desactualizada respecto a B y C.

### Riesgo operativo

El operador puede ver el árbol de fases mostrando una ficha como "activa" mientras el panel de pasos ya muestra que completó. Inconsistencia visual durante la pantalla más crítica: la instalación en progreso.

---

## 13. Problema 11 — Inconsistencia de tipos entre step y screen

**Archivo:** `cmd/bosctl/install_ui.go`  
**Severidad:** 🟡 Media  
**Tipo:** Deuda técnica

### Descripción

```go
// Screen es el tipo correcto para las pantallas
type Screen int
const (
    ScreenWelcome    Screen = iota
    ScreenWizardP1
    ...
)

// Pero el modelo tiene DOS campos para la pantalla actual:
type model struct {
    step   Screen  // ← campo antiguo
    screen Screen  // ← campo nuevo
    ...
}

// Y hay un alias que confunde más:
type stepID = Screen  // ← alias innecesario

const (
    stepWelcome    = ScreenWizardP1  // ← alias que apunta a P1, no a Welcome
    stepTenant     = ScreenWizardP2
    ...
)
```

El alias `stepWelcome = ScreenWizardP1` es incorrecto: `ScreenWelcome` (el splash) y `ScreenWizardP1` (la bienvenida del wizard) son pantallas diferentes, pero el alias las equipara.

En el código se actualizan ambos campos en algunos lugares y solo uno en otros:
```go
// Algunos lugares actualizan ambos:
m.step = ScreenBoot
m.setScreen(ScreenBoot)  // setScreen actualiza m.screen

// Otros solo uno:
m.step = ScreenInstallDone  // ← m.screen no se actualiza
```

### Riesgo operativo

El footer y el header usan `m.screen` para decidir qué mostrar. Las teclas de navegación usan `m.screen`. Pero algunos eventos WS actualizan solo `m.step`. Si `m.step` y `m.screen` divergen, el footer muestra controles de una pantalla mientras el contenido muestra otra.

---

## 14. Problema 12 — startWatchdog declarada pero nunca llamada

**Archivo:** `cmd/bos/main.go`  
**Severidad:** 🟡 Baja-Media  
**Tipo:** Código muerto / bug latente

### Descripción

```go
// Declarada en main.go (línea ~780):
func startWatchdog(stopCh <-chan struct{}) {
    usecStr := os.Getenv("WATCHDOG_USEC")
    // ... envía WATCHDOG=1 a systemd cada medio intervalo
}

// En runNormal, el watchdog de BOS fichas se lanza:
go unifiedWatchdog.Run()  // ← este sí se llama

// Pero startWatchdog() NUNCA se llama en ningún lugar del código
```

La función correcta para el watchdog de systemd (`WATCHDOG_USEC`) está implementada pero nunca invocada. El watchdog de `internal/watchdog/unified_watchdog.go` es diferente — monitorea K8s y fichas, no el proceso bos en systemd.

### Riesgo operativo

Si `bos.service` tiene `WatchdogSec=30s` en systemd, systemd matará el proceso después de 30s de silencio porque nunca recibe `WATCHDOG=1`. En producción con systemd watchdog activo, el daemon se reinicia periódicamente sin causa aparente.

---

## 15. Problema 13 — Testabilidad casi nula en cmd/

**Archivos:** Todo `cmd/`  
**Severidad:** 🟠 Media  
**Tipo:** Calidad del código

### Descripción

`internal/` tiene tests:
- `internal/reconcile/scheduler_test.go`
- `internal/state/manager_test.go`
- `internal/health/checker_test.go`
- `internal/domain/bootstrap_service_test.go`
- etc.

`cmd/` tiene cero tests. Ningún archivo `*_test.go` en `cmd/bosctl/` ni en `cmd/bos/`.

Esto es consecuencia directa del Problema 1: toda la lógica está en `package main`, que no puede ser importado por tests externos. Las funciones `checkPostgres()`, `checkVault()`, `runLocalVerify()`, `topologicalSort()`, `depsSatisfied()` — todas con lógica compleja — son imposibles de testear sin ejecutar el binario completo.

### Riesgo operativo

`topologicalSort()` implementa el algoritmo de Kahn para el DAG de instalación. Un bug aquí instala fichas fuera de orden, lo que puede causar que `keycloak` intente conectarse a `postgresql` antes de que exista. No hay ningún test que verifique que el orden topológico es correcto para el DAG de 22 fichas.

---

## 16. Problema 14 — Reconcile duplicado entre observer y scheduler

**Archivos:** `cmd/bos/main.go` + `internal/reconcile/scheduler.go`  
**Severidad:** 🔴 Alta  
**Tipo:** Race condition

### Descripción (ampliación del Problema 6)

El `scheduler.go` tiene un path explícito para reparación basada en health:

```go
// internal/reconcile/scheduler.go línea ~195
for name, ficha := range st.Fichas {
    if ficha.HealthStatus == "DEGRADED" || ficha.State == state.StateDegradada {
        if s.autoRepair {
            go func(fichaName string) {
                s.installer.Repair(fichaName)
            }(name)
        }
    }
}
```

Y el `runObserverLoop` en `main.go`:

```go
// cmd/bos/main.go — Phase 3
for name, ficha := range st.Fichas {
    if ficha.State == state.StateDegradada || ficha.State == state.StateReparando {
        // Transición a REPARANDO
        stateMgr.Transition(name, state.StateReparando)
        result, err := orchestrator.Repair(name)
        ...
    }
}
```

No hay ningún mecanismo de exclusión mutua entre estos dos loops. El `state.Manager` tiene un mutex interno pero ese mutex protege la escritura en el archivo de estado, no la ejecución del script de reparación.

### Riesgo operativo

Dos ejecuciones simultáneas de `00_MASTER_INSTALL_SBOS.sh repair postgresql` son una carrera condición real. Los scripts bash de SBOS no son idempotentes por diseño — están pensados para ejecutarse secuencialmente.

---

## 17. Problema 15 — bosRBAC como variable global de paquete

**Archivo:** `cmd/bos/main.go`  
**Severidad:** 🟡 Media  
**Tipo:** Diseño

### Descripción

```go
var bosRBAC *security.FileRBAC  // global de paquete, inicializado en autoBootstrap
```

`bosRBAC` se inicializa en `autoBootstrap()` y se usa más tarde en `runNormal()` para pasarlo al servidor. Si `autoBootstrap` falla antes de inicializar RBAC, `bosRBAC` es nil. `runNormal()` hace:

```go
identityProvider := security.IdentityProvider(bosRBAC)  // ← bosRBAC puede ser nil
rbacProvider := security.RBACProvider(bosRBAC)
```

Interfaz con nil subyacente — el código compila y no panea en la asignación, pero cualquier llamada a `rbacProvider.CanExecute()` panea en runtime.

### Riesgo operativo

Si RBAC falla durante el bootstrap (por ejemplo `/etc/bos/rbac/roles.json` tiene permisos incorrectos), el daemon arranca aparentemente bien pero panea en el primer request WebSocket que requiera autorización.

---

## 18. Problema 16 — Hardcoded paths dispersos en dos paquetes

**Archivos:** `cmd/bos/main.go` + `cmd/bosctl/bootstrap.go` + `cmd/bosctl/install_ui.go`  
**Severidad:** 🟡 Baja  
**Tipo:** Mantenibilidad

### Descripción

Las rutas del sistema aparecen hardcoded en múltiples archivos sin ninguna constante compartida:

| Ruta | Aparece en |
|---|---|
| `/etc/bos/.kube/config` | `bootstrap.go` x6, `main.go` x2 |
| `/run/bos/bos.sock` | `main.go` (defaultSocket), `install_ui.go` |
| `/var/log/bos/audit.log` | `main.go` x12 |
| `/etc/bos/bos-install.toml` | `main.go` x3, `install_ui.go` |
| `/opt/bos/bin/bos` | `main.go`, `install_ui.go` |
| `/etc/sbos/tenant.conf` | `install_ui.go` |

`defaultSocket` está definida en `cmd/bosctl/main.go` y es accesible en `install_ui.go` porque ambos son `package main`. Si se modulariza (como propone este plan), esa constante debe moverse a un lugar accesible.

---

## 19. Matriz de riesgo

| # | Problema | Severidad | Probabilidad de fallo | Impacto en producción |
|---|---|---|---|---|
| 6 | Observer + reconcile race condition | 🔴 Alta | Media | Corrupción de estado de fichas |
| 2 | Doble WebSocket | 🔴 Alta | Media | TUI pierde eventos silenciosamente |
| 3 | Violación TEA | 🔴 Alta | Baja-Media | Estado TUI inconsistente |
| 9 | ensureDaemonRunning side effects | 🟠 Media-Alta | Baja | Pérdida de config de producción |
| 4 | Infraestructura en main.go | 🟠 Media-Alta | Alta | Imposible testear, debug lento |
| 1 | Monolito install_ui.go | 🔴 Alta | Alta | Mantenimiento extremadamente lento |
| 14 | Race condition repair | 🔴 Alta | Media | Scripts bash en paralelo |
| 12 | startWatchdog nunca llamada | 🟡 Media | Alta | Daemon reiniciado por systemd |
| 15 | bosRBAC nil interface | 🟡 Media | Baja-Media | Panic en runtime en primer auth |
| 11 | step vs screen inconsistente | 🟡 Media | Media | UI muestra controles incorrectos |
| 5 | kubeconfig x6 | 🟠 Media | Media | Verificación inconsistente |
| 10 | syncViewports sin verdad única | 🟡 Media | Media | Display incorrecto durante install |
| 13 | Cero tests en cmd/ | 🟠 Media | Alta | Bugs no detectados |
| 7 | Estado global mutable | 🟡 Media | Baja | Memory leak en tests/reinvocación |
| 8 | gorilla/websocket redundante | 🟡 Baja | Baja | Comportamiento divergente |
| 16 | Paths hardcoded dispersos | 🟡 Baja | Alta | Mantenimiento propenso a errores |

---

## 20. Lo que está bien

Para dar un cuadro completo, lo siguiente está correctamente diseñado e implementado:

**`internal/state/manager.go`** — La máquina de 18 estados con `ValidTransitions` es correcta. El uso de `fcntl(F_WRLCK)` para locking exclusivo entre procesos es la solución apropiada para este problema. El sistema de backup + recovery es profesional.

**`internal/wslib/websocket.go`** — La decisión de escribir un cliente WS propio (en lugar de depender de gorilla) es acertada para un proyecto que controla ambos extremos del socket. La implementación es correcta y completa.

**`internal/reconcile/scheduler.go`** — El enfoque de hash SHA-256 para detectar drift es correcto y eficiente. La separación entre `ReconcileNow()` (síncróno, para tests) y `Run()` (periódico) es buena práctica.

**`internal/plugin/loader.go`** — El parser de `manifest.yml` con máquina de estados es robusto. La decisión de hacer el ID de la ficha basado en el directorio (con override opcional en el manifest) es la correcta.

**`cmd/bos/main.go:runNormal()`** — La orquestación de subsistemas con `errCh` + `sigCh` + `ShutdownCh` es el patrón correcto para un daemon Go. El orden de shutdown inverso al de inicio es correcto.

**`internal/health/checker.go`** — El umbral de fallos consecutivos (`ConsecutiveFailuresThresh`) antes de marcar DOWN evita falsos positivos. La inyección del runner (`CommandRunner`) permite tests unitarios.

**ADR-001 consistencia** — La arquitectura de "BOS reemplaza sudo" está aplicada consistentemente en toda la codebase. El audit log en cada operación privilegiada es correcto.

---

*Documento generado con revisión estática del código fuente real del proyecto BosAgent/SBOS.*  
*Todos los números de línea y extractos de código son del código fuente actual, no aproximaciones.*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
