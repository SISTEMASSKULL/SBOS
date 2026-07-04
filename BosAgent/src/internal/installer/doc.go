// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package installer implementa el patrón Saga para el ciclo de vida de fichas.
// Cada operación (install/update/repair/remove) delega en el script Bash maestro
// (00_MASTER_INSTALL_SBOS.sh) y parsea su protocolo de señales para observabilidad
// por pasos.
//
// # Responsabilidades
//
//   - Ejecutar sagas de fichas: Install, Update, Repair, Remove, Probe, Status.
//   - Parsear el protocolo de señales del motor Bash (__SBOS__STEP_START__, etc.)
//     y emitir eventos Step al observador registrado.
//   - Activar la cadena de compensación (Compensator) ante fallos.
//   - Ejecutar la secuencia de apagado K8s: drain → stop kubelet → stop containerd.
//
// # Fuera de alcance
//
//   - Gestión del estado de fichas — responsabilidad de internal/state.
//   - Elección de qué ficha instalar a continuación — responsabilidad de internal/observer.
//   - Lógica de infraestructura K8s — responsabilidad de internal/k8s.
//
// # Dependencias
//
//   - Bash 5.x — 00_MASTER_INSTALL_SBOS.sh (motor de ejecución de fichas).
//   - log/slog — logging estructurado del ciclo de saga.
//
// # Callers principales
//
//   - internal/observer/observer.go — invoca Install() y Repair() en el loop.
//   - internal/domain/ficha_service.go — invoca Install/Update/Repair/Remove/Probe.
//   - internal/reconcile/scheduler.go — invoca Repair() en drift/health auto-repair.
//
// # Estándares y referencias
//
//   - P6 (compensación explícita), P12 (watchdog) — principios del IAM Installer.
//   - ADR-021 — estados INSTALANDO, ACTUALIZANDO, REPARANDO y sus transiciones.
//   - SBOS-018 §5 — protocolo de señales __SBOS__STEP_*.
//
// # Ejemplo de uso
//
//	orch := installer.NewOrchestrator(paths.MasterScript, paths.CoreDir, 0, logger)
//	orch.SetObserver(func(step installer.Step) { log.Info(step.Name, step.Status) })
//	result, err := orch.Install("postgresql", "18.4")
package installer
