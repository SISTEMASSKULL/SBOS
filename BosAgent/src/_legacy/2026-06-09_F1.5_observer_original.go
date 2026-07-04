// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: cmd/bos/main.go (extraído en átomo F1.5)
// Destino: internal/observer/observer.go + internal/observer/startup.go
// Razón: las 6 funciones del loop de observación violan SRP en main.go y
//         contienen una race condition latente (P6/P14) en el loop de reparación.
//         La extracción permite testear las funciones puras (depsSatisfied,
//         findNextAutoInstall, topologicalSort) y añadir Stop() al loop.
//
// Funciones incluidas:
//   - initializeFichaStates(): registra todas las fichas descubiertas en STATE_MANAGER.
//   - startupReconcile(): verifica estado K8s al arrancar (usa SystemctlCmd del main).
//   - runObserverLoop(): loop tick 5s — desbloquea, instala, repara fichas.
//   - findNextAutoInstall(): elige la siguiente ficha elegible para auto-install.
//   - depsSatisfied(): verifica si todas las dependencias están en INSTALADA.
//   - topologicalSort(): ordena fichas con algoritmo de Kahn + ExecutionOrder.
//
// Cambios en la versión migrada:
//   - runObserverLoop → Loop struct con Run()/Stop() (sync.Once en Stop)
//   - startupReconcile: parámetro orchestrator eliminado (nunca usado); SystemctlFn inyectada
//   - Funciones puras exportadas: FindNextAutoInstall, DepsSatisfied, TopologicalSort
//   - audit.Log usa paths.AuditLog en vez de string literal (P16)
//   - Mensajes de log en español
//   - Race condition P6/P14 documentada — la fix está en reconcile/scheduler.go (inFlight sync.Map)

package legacy

import (
	"math/rand"
	"sort"
	"sync"
	"time"

	"github.com/rs/zerolog/log"
)

// initializeFichaStates registers all discovered fichas in STATE_MANAGER
// with initial states derived from their manifest.yml.
//
// MIGRADO a: internal/observer.InitializeFichaStates()
func initializeFichaStates() {
	// ver cmd/bos/main.go línea ~581
}

// startupReconcile checks whether K8s was running before BOS stopped and,
// if so, triggers immediate reconciliation to avoid the 300s ticker window.
//
// MIGRADO a: internal/observer.StartupReconcile()
// CAMBIO: parámetro orchestrator eliminado (nunca se usaba); SystemctlCmd inyectado como SystemctlFn
func startupReconcile() {
	// ver cmd/bos/main.go línea ~611
	_ = rand.Intn(30) // jitter anti-thundering-herd
}

// runObserverLoop continuously observes ficha states and reacts.
// It runs as a goroutine so the API server starts immediately.
//
// MIGRADO a: internal/observer.Loop (struct con Run/Stop)
// CAMBIO: añadido Stop() con sync.Once; loop usa select {case <-stopCh} para terminar limpiamente
func runObserverLoop() {
	// ver cmd/bos/main.go línea ~671
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var once sync.Once
	stopCh := make(chan struct{})
	defer once.Do(func() { close(stopCh) })

	for {
		select {
		case <-stopCh:
			return
		case <-ticker.C:
			log.Debug().Msg("observer tick") // simplificado para referencia
		}
	}
}

// findNextAutoInstall returns the next ficha eligible for auto-install.
// Uses topological ordering: picks the lowest execution_order among
// NO_INSTALADA + auto_install fichas whose dependencies are all INSTALADA_OK.
//
// MIGRADO a: internal/observer.FindNextAutoInstall()
func findNextAutoInstall() {
	// ver cmd/bos/main.go línea ~796
}

// depsSatisfied returns true if all dependencies are in INSTALADA state (ADR-021 #4).
//
// MIGRADO a: internal/observer.DepsSatisfied()
func depsSatisfied(deps []string) bool {
	_ = deps
	return true // simplificado para referencia
}

// topologicalSort orders fichas so that dependencies come before dependents.
// Uses Kahn's algorithm for deterministic ordering.
//
// MIGRADO a: internal/observer.TopologicalSort()
func topologicalSort() {
	// ver cmd/bos/main.go línea ~854
	_ = sort.Slice // referencia al uso de sort
}
