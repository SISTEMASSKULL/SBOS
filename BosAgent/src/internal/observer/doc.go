// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package observer implementa el loop de observación continua del daemon bos
// y las funciones de arranque relacionadas con el estado de las fichas.
//
// # Responsabilidades
//
// Cuatro responsabilidades relacionadas, todas necesarias para la operación normal:
//   - Loop: loop de tick (5s por defecto) que observa estados de fichas y reacciona.
//     Fase 1 — desbloquear fichas con dependencias satisfechas (PENDIENTE → LISTA).
//     Fase 2 — instalar la siguiente ficha elegible (secuencial, determinista, LISTA → INSTALADA).
//     Fase 3 — reparar fichas degradadas (DEGRADADA → REPARANDO → INSTALADA).
//   - InitializeFichaStates: registra todas las fichas descubiertas en STATE_MANAGER al arrancar.
//   - StartupReconcile: verifica el estado de K8s inmediatamente al reiniciar el daemon,
//     evitando la ventana de hasta 300s del reconcile.Scheduler.
//   - FindNextAutoInstall / DepsSatisfied / TopologicalSort: funciones puras reutilizables.
//
// # Invariante de concurrencia (P6/P14)
//
// El loop de observación instala y repara fichas de forma SECUENCIAL (sin goroutines).
// Esto garantiza que no habrá dos operaciones sobre la misma ficha al mismo tiempo.
// El reconcile.Scheduler también puede llamar a Repair() en goroutines — ese es el
// punto donde existe la race condition; su fix está en reconcile/scheduler.go
// mediante inFlight sync.Map.
//
// # Fuera de alcance
//
// No gestiona el DAG de dependencias a nivel global — eso es reconcile.Scheduler.
// No escribe directamente en .sbos_state.json — usa internal/state.Manager.
// No expone API externa ni puerto — es puramente interno.
//
// # Dependencias
//
// bos/internal/installer: para invocar Install() y Repair() del orquestador.
// bos/internal/plugin: para cargar manifests de fichas.
// bos/internal/state: para leer y transicionar el estado de fichas.
// bos/internal/health: para CheckNow() en StartupReconcile.
// bos/internal/audit: para registrar operaciones en el audit log (ISO 27001 A.8.15).
// bos/internal/paths: para paths canónicos (P16 Zero Hardcoding).
//
// # Callers principales
//
// cmd/bos/main.go:runNormal — crea Loop, llama Run() como goroutine, y usa
// InitializeFichaStates + StartupReconcile en los pasos 5.5 y 10.5.
//
// # Estándares y referencias
//
// SBOS-018 §5 — Ciclo de reconciliación del daemon bos.
// ADR-021 — Máquina de 18 estados de ficha (PENDIENTE→LISTA→INSTALANDO→INSTALADA).
// BOS-REPAIR-03 — Race condition P6/P14 (observer + reconcile sin mutex).
// ISO 27001:2022 A.8.15 — registro de operaciones en audit log.
//
// # Ejemplo de uso
//
//	// Arranque normal
//	observer.InitializeFichaStates(pluginLoader, stateMgr)
//	loop := observer.New(observer.Config{
//	    Orchestrator: orchestrator,
//	    Loader:       pluginLoader,
//	    StateMgr:     stateMgr,
//	})
//	defer loop.Stop()
//	go loop.Run()
//
//	// Reconciliación inmediata al arrancar
//	observer.StartupReconcile(stateMgr, healthChecker, SystemctlCmd)
package observer
