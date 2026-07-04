// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package watchdog implementa el watchdog unificado de tres capas del daemon bos
// (P12 — watchdog obligatorio para todo daemon soberano).
//
// # Responsabilidades
//
//   - Ejecutar un ciclo de 30s verificando Ubuntu host, K8s cluster y fichas BOS.
//   - Detectar umbrales críticos de disco y memoria y emitir alertas.
//   - Comprobar estado de nodos K8s (NotReady) y pods fallidos.
//   - Verificar fichas BOS en estado DEGRADADA/ERROR y disparar reparación si autoRepair=true.
//   - Exponer Snapshot con resultados agregados de las tres capas.
//
// # Fuera de alcance
//
//   - Reparación profunda — delega en repair.RepairManager.
//   - Health check periódico de fichas — responsabilidad de health.Checker.
//   - Monitoreo Prometheus — responsabilidad de internal/metrics.
//
// # Dependencias
//
//   - internal/health — health.Checker para consultas de estado de fichas.
//   - internal/repair — RepairManager para auto-reparación de nodos/fichas.
//   - internal/state — STATE_MANAGER (Read para estado de fichas).
//   - log/slog — logging estructurado de anomalías detectadas.
//
// # Callers principales
//
//   - cmd/bos/main.go — startWatchdog() (P12) crea e inicia el watchdog.
//
// # Estándares y referencias
//
//   - P12 — watchdog de 60s obligatorio para todos los daemons soberanos.
//   - SBOS-032 §3 — SLOs de disponibilidad (99.9% fichas críticas).
//
// # Ejemplo de uso
//
//	wd := watchdog.NewUnifiedWatchdog(stateMgr, 30*time.Second,
//	    80, 85, true, true, true, true, repairMgr, logger)
//	go wd.Run()
//	defer wd.Stop()
package watchdog
