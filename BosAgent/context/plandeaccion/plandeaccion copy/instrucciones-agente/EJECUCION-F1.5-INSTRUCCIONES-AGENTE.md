# INSTRUCCIONES DE EJECUCIÓN — Átomo F1.5
## Observer loop → `internal/observer/` con Mutex compartido (P6/P14 — CRÍTICO)
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomo:** F1.5 — Resolver race condition entre Observer y Reconciler  
**Requiere previo:** F1.4 ✅ (`internal/network/` creado), F0.1 ✅ (`_legacy/` existe)  
**Duración estimada:** 90–120 minutos  
**Riesgo:** ALTO — este átomo toca el loop de control central del daemon  
**Reversión:** `git revert HEAD` + restaurar desde `_legacy/`  
**Feature flag:** `BOS_OBSERVER_V2=true` activa el nuevo código; `false` usa el legado

---

## CONTEXTO TÉCNICO — Por qué este átomo es el más importante del plan

La race condition P6/P14 es el único bug activo con potencial de **pérdida de datos en producción**.

Existen dos loops independientes que monitorizan fichas DEGRADADAS:

```
runObserverLoop (cmd/bos/main.go)           reconcile.Scheduler (internal/reconcile/scheduler.go)
│  tick: 5s                                 │  tick: 300s (configurable)
│  detecta: PENDIENTE→LISTA→INSTALANDO      │  detecta: drift de hashes SHA-256
│  detecta: DEGRADADA→REPARANDO             │  detecta: DEGRADED/ALERTA
│  llama: orchestrator.Repair(name)         │  llama: s.installer.Repair(name)
└──────────────────────────────────────────────────────────────────┘
                        SIN EXCLUSIÓN MUTUA

Resultado cuando ambos detectan "postgresql" DEGRADADA al mismo tiempo:
  → dos ejecuciones de 00_MASTER_INSTALL_SBOS.sh repair postgresql en paralelo
  → dos kubectl apply sobre el mismo StatefulSet
  → estado del archivo JSON corrupto (dos writers concurrentes)
  → pérdida potencial de datos si uno de los repairs hace delete del PVC
```

### Por qué `sync.Mutex` y no un canal

La decisión técnica está respaldada por el Go Wiki oficial y benchmarks 2025:

- **El problema es proteger estado compartido** (quién está reparando qué ficha), no comunicar datos entre goroutines → `sync.Mutex` es la herramienta correcta
- Un canal de capacidad 1 funcionaría pero añade overhead de scheduling innecesario
- `sync.RWMutex` no aplica: las operaciones de repair son siempre escrituras, no hay lectores concurrentes legítimos
- El mutex **debe ser un puntero compartido** inyectado en ambas structs (`Observer` y `Scheduler`) desde `cmd/bos/main.go` — es la clave de esta implementación

### El patrón correcto: mutex inyectado, no embebido

```go
// ❌ INCORRECTO — cada struct tiene su propio mutex independiente
type Observer  struct { mu sync.Mutex ... }
type Scheduler struct { mu sync.Mutex ... }
// Cada uno protege "su" sección pero no saben del otro → race persiste

// ✅ CORRECTO — mutex compartido inyectado desde afuera
type Observer  struct { repairMu *sync.Mutex ... }
type Scheduler struct { repairMu *sync.Mutex ... }

// En cmd/bos/main.go:
repairMu := &sync.Mutex{}
observer  := observer.New(repairMu, orchestrator, loader, stateMgr, logger)
scheduler := reconcile.NewScheduler(cfg, stateMgr, installer, repairMu)
// Ambos apuntan al MISMO mutex → exclusión mutua real
```

---

## PRE-CONDICIONES — Verificar antes de empezar

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/

# 1. F0.1 completo
[ -f _legacy/README.md ] && echo "✅ _legacy/ existe" || echo "❌ ejecutar F0.1 primero"

# 2. F1.4 completo (o al menos F0.1)
go build ./... && echo "✅ build limpio" || echo "❌ build roto — no continuar"

# 3. Confirmar que la race EXISTE antes de implementar la solución
go test -race -count=5 -timeout=3m ./... 2>&1 | grep "DATA RACE" \
  && echo "✅ race confirmada" \
  || echo "⚠️  race no reproducible en 5 runs — usar count=50"

# 4. Verificar que el archivo a extraer existe
grep -n "func runObserverLoop" cmd/bos/main.go \
  && echo "✅ runObserverLoop presente en main.go" \
  || echo "❌ función no encontrada — revisar el archivo"

# 5. Verificar el punto exacto de la race en reconcile
grep -n "s.installer.Repair\|go func.*Repair" internal/reconcile/scheduler.go \
  && echo "✅ llamada Repair() encontrada en scheduler" \
  || echo "❌ revisar scheduler.go"
```

Si el build falla, **detener**. No continuar hasta que `go build ./...` pase en verde.

---

## PASO 1 — Leer y mapear el código existente (obligatorio, no saltear)

Antes de escribir una línea, leer y entender:

```bash
# Leer runObserverLoop completo:
grep -n "func runObserverLoop" cmd/bos/main.go
# Anotar: línea de inicio y línea de fin

# Identificar las 3 fases del loop:
grep -n "Phase 1\|Phase 2\|Phase 3\|PENDIENTE\|DEGRADADA\|orchestrator.Repair\|orchestrator.Install" \
  cmd/bos/main.go | head -30

# Leer topologicalSort (va a internal/plugin/loader.go):
grep -n "func topologicalSort\|func depsSatisfied\|func findNextAutoInstall\|func initializeFichaStates" \
  cmd/bos/main.go

# Leer el scheduler — el otro participante de la race:
grep -n "func.*Repair\|autoRepair\|installer.Repair\|go func" \
  internal/reconcile/scheduler.go | head -20

# Entender la interfaz que usa orchestrator:
grep -n "type.*Orchestrator\|Repair(" internal/installer/saga.go | head -10
# o buscar la interfaz:
grep -rn "interface.*Orchestrator\|Orchestrator interface" internal/ | head -5
```

**Anotar antes de continuar:**
- Líneas exactas de `runObserverLoop` en `main.go`
- Qué importa `runObserverLoop` (qué variables de `main.go` usa)
- La firma exacta del método `Repair()` en el orquestador
- La firma del constructor de `Scheduler` en `reconcile/scheduler.go`

---

## PASO 2 — Archivar el código existente en `_legacy/`

```bash
DATE=$(date +%Y-%m-%d)

# Archivar runObserverLoop y funciones relacionadas del observer:
# (extraer las líneas relevantes de main.go a un archivo de archivo)
grep -n "func runObserverLoop\|func topologicalSort\|func depsSatisfied\|func findNextAutoInstall\|func initializeFichaStates" \
  cmd/bos/main.go
# Usar las líneas identificadas para copiar el bloque exacto:
# Ejemplo (ajustar líneas según el archivo real):
sed -n '<LINEA_INICIO>,<LINEA_FIN>p' cmd/bos/main.go \
  > _legacy/${DATE}_F1.5_observer_loop_sin_mutex.go

# Agregar header de archivo:
cat > /tmp/header.txt << 'EOF'
// ARCHIVADO: F1.5 — 2026-XX-XX
// Origen: cmd/bos/main.go
// Razón: Extraído a internal/observer/ con corrección de race condition P6/P14
// Problema: runObserverLoop y reconcile.Scheduler podían llamar Repair()
//           simultáneamente sin exclusión mutua.
// Solución: Observer struct con *sync.Mutex compartido inyectado desde main.go.
// Informe de Cierre: INFORME-CIERRE-F1.5.md
EOF
cat /tmp/header.txt _legacy/${DATE}_F1.5_observer_loop_sin_mutex.go > /tmp/tmp_arch.go
mv /tmp/tmp_arch.go _legacy/${DATE}_F1.5_observer_loop_sin_mutex.go

echo "✅ Archivado en _legacy/"
ls -la _legacy/${DATE}_F1.5_*.go
```

---

## PASO 3 — Mover `topologicalSort` a `internal/plugin/loader.go`

`topologicalSort` opera sobre `FichaManifest` — pertenece al paquete que carga manifests, no al observer.

```bash
# Verificar que plugin/loader.go existe:
[ -f internal/plugin/loader.go ] && echo "✅" || echo "❌ revisar estructura"

# La función topologicalSort en main.go implementa el algoritmo de Kahn.
# Moverla a internal/plugin/loader.go como función exportada TopologicalSort.
```

Crear o agregar a `internal/plugin/loader.go`:

```go
// TopologicalSort ordena las fichas en orden de instalación usando el
// algoritmo de Kahn sobre el DAG de dependencias.
//
// Garantía: si ficha A depende de ficha B, B aparece antes que A en el resultado.
// El DAG actual tiene 22 fichas. Si hay un ciclo, retorna error.
//
// Referencia: P6/P14 BOS-REPAIR-00 — esta función debe estar en un paquete
// testeable para verificar el orden correcto de las 22 fichas.
func TopologicalSort(fichas map[string]*FichaManifest) ([]string, error) {
    // COPIAR el cuerpo de topologicalSort() de cmd/bos/main.go
    // Cambios requeridos:
    //   - Renombrar de topologicalSort → TopologicalSort (exportada)
    //   - Cambiar el tipo de retorno si es necesario para incluir error
    //   - Agregar validación de ciclos si no existe
}
```

**Test inmediato** (crear `internal/plugin/loader_test.go` si no existe):

```go
func TestTopologicalSort_DAGDe22Fichas(t *testing.T) {
    // Construir el DAG de las 22 fichas del stack SBOS
    fichas := map[string]*FichaManifest{
        "sbos-bootstrap-k8s": {DependsOn: []string{}},
        "postgresql":          {DependsOn: []string{"sbos-bootstrap-k8s"}},
        "redis":               {DependsOn: []string{"sbos-bootstrap-k8s"}},
        "vault":               {DependsOn: []string{"sbos-bootstrap-k8s"}},
        "keycloak":            {DependsOn: []string{"postgresql"}},
        "kong":                {DependsOn: []string{"keycloak"}},
        // ... resto de las 22 fichas según el stack SBOS
    }

    order, err := TopologicalSort(fichas)
    require.NoError(t, err)

    // postgresql DEBE aparecer antes que keycloak
    pgIdx, kcIdx := indexOf(order, "postgresql"), indexOf(order, "keycloak")
    assert.Less(t, pgIdx, kcIdx, "postgresql debe instalarse antes que keycloak")

    // sbos-bootstrap-k8s DEBE ser el primero
    assert.Equal(t, "sbos-bootstrap-k8s", order[0])

    assert.Len(t, order, 22, "deben estar las 22 fichas")
}

func TestTopologicalSort_DetectaCiclo(t *testing.T) {
    fichas := map[string]*FichaManifest{
        "a": {DependsOn: []string{"b"}},
        "b": {DependsOn: []string{"a"}}, // ciclo
    }
    _, err := TopologicalSort(fichas)
    assert.Error(t, err, "debe detectar el ciclo")
}
```

```bash
go test -race ./internal/plugin/ && echo "✅ topologicalSort testeada"
```

---

## PASO 4 — Crear `internal/observer/observer.go`

Este es el archivo central del átomo. Copiar y adaptar `runObserverLoop` de `main.go`:

```go
// Package observer implementa el loop reactivo de monitorización de fichas.
//
// # Responsabilidades
//
// El Observer monitoriza el estado de todas las fichas cada 5 segundos y
// reacciona a transiciones de estado: PENDIENTE→LISTA, LISTA→INSTALANDO,
// DEGRADADA→REPARANDO. Es el componente que decide cuándo instalar y cuándo
// reparar.
//
// # Fuera de alcance
//
// El Observer NO ejecuta reparaciones de hash-drift (responsabilidad del
// reconcile.Scheduler). NO gestiona el ciclo de vida del proceso systemd.
//
// # Race condition y exclusión mutua (P6/P14)
//
// El Observer comparte un *sync.Mutex con reconcile.Scheduler para garantizar
// que Repair() nunca se ejecuta en paralelo desde ambos componentes.
// El mutex es inyectado desde cmd/bos/main.go y apunta al MISMO objeto
// en ambas structs. Ver BOS-REPAIR-00 §P6/P14 y ADR-021.
//
// # Dependencias
//
// installer.Orchestrator: para ejecutar sagas de instalación y reparación.
// plugin.Loader: para acceder a manifiestos y su DAG de dependencias.
// state.Manager: para leer y transicionar el estado de las fichas.
//
// # Estándares
//
// SBOS-018 §10, ADR-021 (máquina de 18 estados), NIST SP 800-207 T-05.
package observer

import (
    "context"
    "sync"
    "time"

    "bos/internal/installer"
    "bos/internal/plugin"
    "bos/internal/state"
    // zerolog o slog según el proyecto
)

// tickInterval es el intervalo de monitorización del observer.
// Valor: 5 segundos — equilibrio entre reactividad y carga del sistema.
const tickInterval = 5 * time.Second

// Observer monitoriza el estado de las fichas y dispara instalaciones
// y reparaciones de forma reactiva.
//
// Thread safety: Observer es seguro para uso concurrente. El campo repairMu
// es un puntero compartido con reconcile.Scheduler para garantizar exclusión
// mutua en operaciones de reparación.
type Observer struct {
    // repairMu es el mutex COMPARTIDO con reconcile.Scheduler.
    // NUNCA crear un sync.Mutex propio — siempre inyectar desde main.go.
    // Ver doc del paquete §Race condition.
    repairMu *sync.Mutex

    orchestrator installer.Orchestrator // ejecuta instalaciones y reparaciones
    loader       *plugin.Loader        // accede a manifiestos de fichas
    stateMgr     *state.Manager        // lee y transiciona estados
    logger       Logger                // interfaz de logging (zerolog/slog)
    stopCh       chan struct{}          // señal de parada desde main.go
}

// Logger es la interfaz mínima de logging que usa el Observer.
// Compatible con zerolog.Logger y slog.Logger con wrapper.
type Logger interface {
    Info(msg string, args ...any)
    Error(msg string, args ...any)
    Warn(msg string, args ...any)
}

// New crea un Observer con el mutex compartido inyectado.
//
// Recibe:
//   - repairMu: *sync.Mutex compartido con reconcile.Scheduler — NUNCA nil
//   - orchestrator: implementación del orquestador de sagas
//   - loader: cargador de plugins/manifests
//   - stateMgr: gestor de estado de fichas
//   - logger: interfaz de logging
//
// Retorna: *Observer listo para llamar a Run()
func New(
    repairMu     *sync.Mutex,
    orchestrator installer.Orchestrator,
    loader       *plugin.Loader,
    stateMgr     *state.Manager,
    logger       Logger,
) *Observer {
    if repairMu == nil {
        panic("observer.New: repairMu no puede ser nil — inyectar desde main.go")
    }
    return &Observer{
        repairMu:     repairMu,
        orchestrator: orchestrator,
        loader:       loader,
        stateMgr:     stateMgr,
        logger:       logger,
        stopCh:       make(chan struct{}),
    }
}

// Run inicia el loop de observación. Bloqueante — llamar en goroutine.
//
// El loop se detiene cuando se cierra el canal stopCh (llamar Stop()).
// Implementa las 3 fases del ciclo de monitorización:
//   - Fase 1: inicializar fichas PENDIENTE al arranque
//   - Fase 2: instalar fichas LISTA cuyas dependencias están satisfechas
//   - Fase 3: reparar fichas DEGRADADA (con mutex compartido)
func (o *Observer) Run() {
    ticker := time.NewTicker(tickInterval)
    defer ticker.Stop()

    // Inicialización de estados al arranque (Phase 1 — una sola vez)
    o.initializeFichaStates()

    for {
        select {
        case <-o.stopCh:
            o.logger.Info("observer: loop detenido")
            return
        case <-ticker.C:
            o.tick()
        }
    }
}

// Stop detiene el loop de observación de forma limpia.
// Seguro para llamar múltiples veces (idempotente).
func (o *Observer) Stop() {
    select {
    case <-o.stopCh:
        // ya cerrado
    default:
        close(o.stopCh)
    }
}

// tick ejecuta un ciclo completo de monitorización.
// Separado de Run() para facilitar tests unitarios.
func (o *Observer) tick() {
    st, err := o.stateMgr.Read()
    if err != nil {
        o.logger.Error("observer: error leyendo estado", "error", err)
        return
    }

    for name, ficha := range st.Fichas {
        switch ficha.State {

        // Phase 2: instalar fichas listas (sus dependencias están INSTALADAS)
        case state.StateLista:
            manifest, err := o.loader.Get(name)
            if err != nil {
                continue
            }
            if o.loader.DepsSatisfied(manifest, st) {
                o.stateMgr.Transition(name, state.StateInstalando)
                go func(fichaName string) {
                    if err := o.orchestrator.Install(fichaName); err != nil {
                        o.logger.Error("observer: install falló",
                            "ficha", fichaName, "error", err)
                    }
                }(name)
            }

        // Phase 3: reparar fichas degradadas — MUTEX CRÍTICO
        case state.StateDegradada:
            o.repairWithMutex(name)
        }
    }
}

// repairWithMutex ejecuta una reparación con exclusión mutua.
//
// GARANTÍA: Repair() nunca se ejecuta en paralelo con reconcile.Scheduler
// porque ambos comparten el mismo *sync.Mutex inyectado desde main.go.
//
// El lock se adquiere ANTES de la transición de estado y se libera
// DESPUÉS de que el repair termina. Esto previene que el scheduler
// dispare un segundo repair mientras este está en curso.
func (o *Observer) repairWithMutex(fichaName string) {
    o.repairMu.Lock()
    defer o.repairMu.Unlock()

    // Re-verificar el estado después de adquirir el lock.
    // El scheduler puede haber cambiado el estado entre que detectamos
    // DEGRADADA y que adquirimos el mutex.
    st, err := o.stateMgr.Read()
    if err != nil {
        return
    }
    ficha, ok := st.Fichas[fichaName]
    if !ok || ficha.State != state.StateDegradada {
        // El scheduler ya inició el repair — no duplicar
        return
    }

    o.stateMgr.Transition(fichaName, state.StateReparando)
    o.logger.Info("observer: iniciando repair", "ficha", fichaName)

    if err := o.orchestrator.Repair(fichaName); err != nil {
        o.logger.Error("observer: repair falló", "ficha", fichaName, "error", err)
        // Revertir a DEGRADADA si el repair falla
        o.stateMgr.Transition(fichaName, state.StateDegradada)
    }
}

// initializeFichaStates inicializa los estados de fichas al arranque del daemon.
// COPIAR el cuerpo de initializeFichaStates() de cmd/bos/main.go.
func (o *Observer) initializeFichaStates() {
    // TODO: copiar implementación de main.go
}
```

---

## PASO 5 — Modificar `internal/reconcile/scheduler.go`

Agregar el campo `repairMu` al Scheduler y usarlo antes de llamar `Repair()`.

**Localizar el constructor del Scheduler:**
```bash
grep -n "func New\|func NewScheduler" internal/reconcile/scheduler.go | head -5
```

**Modificar la struct y el constructor:**

```go
// En la struct Scheduler, agregar el campo:
type Scheduler struct {
    // repairMu es el mutex COMPARTIDO con observer.Observer.
    // Inyectado desde cmd/bos/main.go. Garantiza que Repair() no
    // se ejecuta en paralelo con el observer. Ver P6/P14 BOS-REPAIR-00.
    repairMu *sync.Mutex

    // ... campos existentes sin cambio ...
}

// En el constructor, agregar el parámetro:
func NewScheduler(cfg *config.Config, stateMgr *state.Manager, 
                  installer installer.Orchestrator, repairMu *sync.Mutex) *Scheduler {
    if repairMu == nil {
        panic("reconcile.NewScheduler: repairMu no puede ser nil")
    }
    return &Scheduler{
        repairMu: repairMu,
        // ... resto sin cambio ...
    }
}
```

**Localizar la llamada existente a Repair() en el scheduler:**
```bash
grep -n "installer.Repair\|s.installer.Repair\|go func.*Repair" \
  internal/reconcile/scheduler.go
```

**Envolver la llamada con el mutex compartido:**

```go
// ANTES (código actual — race condition):
go func(fichaName string) {
    s.installer.Repair(fichaName)
}(name)

// DESPUÉS (con mutex compartido):
go func(fichaName string) {
    s.repairMu.Lock()
    defer s.repairMu.Unlock()

    // Re-verificar estado después del lock (mismo patrón que observer)
    st, err := s.stateMgr.Read()
    if err != nil {
        return
    }
    ficha, ok := st.Fichas[fichaName]
    if !ok || (ficha.State != state.StateDegradada && ficha.HealthStatus != "DEGRADED") {
        return // observer ya tomó el lock y está reparando
    }

    s.installer.Repair(fichaName)
}(name)
```

---

## PASO 6 — Actualizar `cmd/bos/main.go`

Conectar los dos componentes con el mutex compartido:

```go
// En runNormal() o donde se inicializan observer y scheduler:

// 1. Crear el mutex compartido UNA SOLA VEZ
repairMu := &sync.Mutex{}

// 2. Crear el Observer con el mutex inyectado
obs := observer.New(
    repairMu,
    orchestrator,
    loader,
    stateMgr,
    logger,
)

// 3. Crear el Scheduler con el MISMO mutex
scheduler := reconcile.NewScheduler(cfg, stateMgr, orchestrator, repairMu)

// 4. Activar con feature flag (SFP-03)
if os.Getenv("BOS_OBSERVER_V2") == "true" {
    go obs.Run()
    defer obs.Stop()
} else {
    // Legado: runObserverLoop sigue en main.go hasta validación en staging
    go runObserverLoop(stopCh, orchestrator, loader, stateMgr, logger)
}

go scheduler.Run(stopCh)
```

**Verificar que el build pasa:**
```bash
go build ./... && echo "✅ build OK"
```

---

## PASO 7 — Crear `internal/observer/observer_test.go`

Estos tests son el criterio de éxito más importante del plan:

```go
package observer_test

import (
    "sync"
    "sync/atomic"
    "testing"
    "time"

    "bos/internal/observer"
    // mocks/stubs necesarios
)

// TestObserver_NoParallelRepair es EL test más importante del proyecto.
//
// Simula la race condition P6/P14: dos goroutines (observer + scheduler)
// intentan reparar la misma ficha simultáneamente.
// Verifica que Repair() se ejecuta EXACTAMENTE UNA VEZ, no dos.
func TestObserver_NoParallelRepair(t *testing.T) {
    var repairCount int64
    repairMu := &sync.Mutex{}

    // Mock del orchestrator que cuenta cuántas veces se llama Repair
    mockOrch := &mockOrchestrator{
        repairFn: func(name string) error {
            atomic.AddInt64(&repairCount, 1)
            time.Sleep(50 * time.Millisecond) // simular trabajo real
            return nil
        },
    }

    obs := observer.New(repairMu, mockOrch, mockLoader(), mockStateMgr("postgresql", "DEGRADADA"), testLogger(t))

    // Simular: observer Y scheduler intentan reparar al mismo tiempo
    var wg sync.WaitGroup
    wg.Add(2)

    // Goroutine 1: observer
    go func() {
        defer wg.Done()
        obs.RepairWithMutexForTest("postgresql")
    }()

    // Goroutine 2: scheduler (usando el mismo repairMu)
    go func() {
        defer wg.Done()
        repairMu.Lock()
        defer repairMu.Unlock()
        // El scheduler adquiere el lock — debe ver que observer ya está reparando
        // y NO llamar Repair() de nuevo
    }()

    wg.Wait()

    count := atomic.LoadInt64(&repairCount)
    if count != 1 {
        t.Errorf("Repair() llamado %d veces, se esperaba exactamente 1", count)
    }
}

// TestObserver_MutexPreventsDoubleRepair — stress test con 10 goroutines
func TestObserver_MutexPreventsDoubleRepair(t *testing.T) {
    var repairCount int64
    repairMu := &sync.Mutex{}

    mockOrch := &mockOrchestrator{
        repairFn: func(name string) error {
            atomic.AddInt64(&repairCount, 1)
            time.Sleep(10 * time.Millisecond)
            return nil
        },
    }

    obs := observer.New(repairMu, mockOrch, mockLoader(), mockStateMgr("redis", "DEGRADADA"), testLogger(t))

    var wg sync.WaitGroup
    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            obs.RepairWithMutexForTest("redis")
        }()
    }
    wg.Wait()

    // Con el mutex, aunque 10 goroutines intentan reparar,
    // solo 1 encuentra el estado DEGRADADA — las demás ven REPARANDO y salen
    count := atomic.LoadInt64(&repairCount)
    if count != 1 {
        t.Errorf("10 goroutines → Repair() llamado %d veces, se esperaba 1", count)
    }
}

// TestObserver_Run_NoDataRace verifica que Run() no produce DATA RACE.
// DEBE ejecutarse con: go test -race -count=100
func TestObserver_Run_NoDataRace(t *testing.T) {
    repairMu := &sync.Mutex{}
    stateMgr := mockStateMgr("postgresql", "DEGRADADA")

    obs := observer.New(repairMu, &mockOrchestrator{}, mockLoader(), stateMgr, testLogger(t))

    go obs.Run()
    time.Sleep(50 * time.Millisecond)
    obs.Stop()
    // Si hay DATA RACE, go test -race lo detecta aquí
}
```

**Nota sobre `RepairWithMutexForTest`:** exponer el método para tests es un patrón aceptado en Go cuando el método privado es la pieza crítica a testear. Alternativa: usar build tags `//go:build !integration` para exponer solo en tests.

---

## PASO 8 — Ejecutar el DoD completo

```bash
echo "=== DOD UNIVERSAL ==="
go build ./...            && echo "✅ BUILD" || echo "❌ BUILD FALLA"
go vet ./...              && echo "✅ VET"   || echo "❌ VET FALLA"
gofmt -l . | wc -l | grep "^0$" && echo "✅ FORMAT" || echo "❌ FORMAT — ejecutar: gofmt -w ."

echo ""
echo "=== DOD ESPECÍFICO F1.5 (el más importante) ==="
echo "Test crítico — race condition (100 runs, puede tardar 5-10 min):"
go test -race -count=100 -timeout=15m ./internal/observer/ \
  -run TestObserver_NoParallelRepair -v 2>&1 | \
  grep -E "^--- (PASS|FAIL)|DATA RACE|^PASS|^FAIL"
echo "(debe mostrar PASS 100 veces, NUNCA DATA RACE)"

echo ""
echo "Test de stress — 10 goroutines (50 runs):"
go test -race -count=50 -timeout=10m ./internal/observer/ \
  -run TestObserver_MutexPreventsDoubleRepair -v 2>&1 | \
  grep -E "^--- (PASS|FAIL)|DATA RACE"

echo ""
echo "Test topological sort:"
go test -race ./internal/plugin/ -run TestTopologicalSort -v 2>&1 | \
  grep -E "^--- (PASS|FAIL)|DATA RACE"

echo ""
echo "Suite completa con race detector:"
go test -race -count=10 ./... 2>&1 | grep -E "DATA RACE|^ok|FAIL" | tail -20
echo "(cero DATA RACE en cualquier paquete)"
```

---

## PASO 9 — Activar en staging y validar

```bash
# En VPS STAGING (13.140.128.230):
ssh root@13.140.128.230

# Activar el nuevo observer con feature flag:
systemctl edit bos-staging.service
# Agregar en [Service]:
# Environment=BOS_OBSERVER_V2=true
systemctl daemon-reload
systemctl restart bos-staging.service

# Monitorizar durante 30 minutos:
journalctl -u bos-staging -f | grep -E "DATA RACE|observer:|repair"
# No debe aparecer: DATA RACE
# Debe aparecer: "observer: iniciando repair" cuando una ficha se degrada

# Verificar que el daemon sigue saludable:
sleep 1800  # 30 minutos
systemctl is-active bos-staging.service
bosctl bootstrap verify --full
```

---

## PASO 10 — Commit y actualizar registros

```bash
# Commit semántico (SFP-04):
git add internal/observer/ internal/reconcile/scheduler.go cmd/bos/main.go _legacy/
git commit -m "[F1.5] fix: mutex compartido anti-race en observer y reconciler

Resuelve P6/P14 (BOS-REPAIR-00): race condition entre runObserverLoop
y reconcile.Scheduler que podían ejecutar Repair() en paralelo sobre
la misma ficha.

Solución: *sync.Mutex inyectado desde main.go, compartido entre
observer.Observer y reconcile.Scheduler. Re-verificación de estado
después del lock previene repairs duplicados.

Feature flag: BOS_OBSERVER_V2=true activa el nuevo observer.

Tests: TestObserver_NoParallelRepair 100/100 sin DATA RACE
       TestObserver_MutexPreventsDoubleRepair 50/50 sin DATA RACE

Closes: P6, P14
Informe: INFORME-CIERRE-F1.5.md"

# Actualizar REGISTRO-ESTADO.md:
# F1.5 → ✅ + hash del commit
```

---

## CRITERIO DE ÉXITO — F1.5 está COMPLETO cuando:

```bash
# Todos deben ser verdad:
[ -f internal/observer/observer.go ] \
  && grep -q "repairMu \*sync.Mutex" internal/observer/observer.go \
  && echo "✅ observer.go con mutex inyectado"

[ -f internal/observer/observer_test.go ] \
  && echo "✅ tests presentes"

grep -q "repairMu \*sync.Mutex" internal/reconcile/scheduler.go \
  && echo "✅ scheduler.go con mutex inyectado"

go test -race -count=100 -timeout=15m ./internal/observer/ \
  -run TestObserver_NoParallelRepair 2>&1 | grep -c "^--- PASS" | grep "^100$" \
  && echo "✅ 100/100 sin DATA RACE"

go build ./... && echo "✅ build limpio"

# En staging (después de 30+ minutos con BOS_OBSERVER_V2=true):
# journalctl -u bos-staging | grep "DATA RACE" → vacío ✅
```

---

## SEÑAL DE RETOMA

Si el trabajo fue interrumpido:

```bash
[ -f internal/observer/observer.go ] \
  && echo "Paso 4 completo — continuar en Paso 5" \
  || echo "Empezar en Paso 3"

grep -q "repairMu" internal/reconcile/scheduler.go \
  && echo "Paso 5 completo — continuar en Paso 6" \
  || echo "Scheduler aún no modificado"

grep -q "BOS_OBSERVER_V2" cmd/bos/main.go \
  && echo "Paso 6 completo — continuar en Paso 7" \
  || echo "main.go aún no actualizado"

go test -race -count=5 ./internal/observer/ 2>&1 | grep "DATA RACE" \
  && echo "⚠️  Race aún presente — revisar implementación" \
  || echo "✅ Race resuelta"
```

---

*EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md v1.0*  
*BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Fuentes: BOS-REPAIR-00 §P6/P14, BOS-REPAIR-05 §F1.5, go.dev/wiki/MutexOrChannel*  
*Validación técnica: Go concurrency best practices 2025 — sync.Mutex para protección de estado compartido*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
