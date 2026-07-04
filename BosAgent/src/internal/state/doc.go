// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package state implementa STATE_MANAGER — el único escritor de .sbos_state.json.
// Principio P8: ningún otro componente escribe en el archivo de estado.
// Usa fcntl(F_WRLCK) para bloqueo exclusivo entre procesos.
//
// # Responsabilidades
//
//   - Gestionar el ciclo de vida de .sbos_state.json con bloqueo exclusivo.
//   - Implementar la máquina de 18 estados (ADR-021): 13 estables + 5 transicionales.
//   - Validar transiciones de estado contra ValidTransitions (transiciones no
//     listadas son rechazadas).
//   - Escribir de forma atómica: write→sync→rename sobre .tmp; backup a .bak.
//   - Recuperación de tres niveles: archivo principal → .bak → reconstrucción vacía.
//
// # Fuera de alcance
//
//   - Leer el estado desde fuera del paquete de forma concurrente sin el Manager.
//   - Modificar campos del estado directamente — todo pasa por métodos del Manager.
//   - Sincronización del estado con K8s etcd — el estado es local al daemon.
//
// # Dependencias
//
//   - encoding/json — codificación/decodificación del estado.
//   - syscall.Flock — bloqueo exclusivo del archivo.
//   - sync.Mutex — serialización de operaciones concurrentes en proceso.
//
// # Callers principales
//
//   - cmd/bos/main.go — NewManager() al inicio del daemon.
//   - internal/observer/ — Transition(), Unblock(), RegisterHashes().
//   - internal/reconcile/ — RegisterHashes(), SetDriftDetected().
//   - internal/health/ — SetHealth().
//   - internal/domain/ — Register(), Transition() via FichaService.
//   - internal/ficha/ — Lógica de dominio pura (18 estados idénticos, sin dependencia).
//     Usar FichaStateFromString() / ToState() para convertir entre state.FichaState y ficha.FichaState.
//
// # Estándares y referencias
//
//   - P8 — STATE_MANAGER es el único escritor del archivo de estado.
//   - ADR-021 — máquina de 18 estados de fichas (13 estables + 5 transicionales).
//   - ISO 27001 A.8.15 — integridad de registros de auditoría.
//   - SBOS-019 §8 — estados de ficha y transiciones permitidas.
//   - internal/ficha/statemachine.go — StateMachine con lógica pura de los mismos 18 estados.
//
// # Ejemplo de uso
//
//	mgr, err := state.NewManager(paths.StateFile)
//	defer mgr.Close()
//	st, _ := mgr.Read()
//	_ = mgr.Transition("postgresql", state.StateInstalada)
package state
