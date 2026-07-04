// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package observability provee una vista de métricas unificada de las tres
// capas del SBOS: Ubuntu host, Kubernetes cluster, y fichas BOS.
//
// # Responsabilidades
//
//   - Construir TopSnapshot: carga CPU/memoria/disco del host via /proc y df.
//   - Resumir estado de pods K8s activos via kubectl get pods.
//   - Resumir fichas por estado (instaladas, degradadas, en error) desde STATE_MANAGER.
//   - Exponer HealthReport por capas para la Core UI y bosctl.
//
// # Fuera de alcance
//
//   - Exponer métricas en formato Prometheus — responsabilidad de internal/metrics.
//   - Almacenar series temporales — es una vista puntual sin historia.
//   - Alertar — responsabilidad del watchdog unificado.
//
// # Dependencias
//
//   - internal/state — STATE_MANAGER (solo lectura para resumen de fichas).
//   - df, /proc/meminfo, /proc/loadavg — comandos del host.
//
// # Callers principales
//
//   - internal/server/api.go — handler "bos.health.check" y "bos.status.read".
//   - cmd/bosctl/app.go — subcomando "bosctl top".
//
// # Estándares y referencias
//
//   - SBOS-032 OPERATIONS — SLOs, SLIs y error budgets del SBOS.
//   - SBOS-012 MCP §top — integración con herramientas de observabilidad.
//
// # Ejemplo de uso
//
//	snap := observability.CollectTop(stateMgr)
//	fmt.Printf("CPU: %.1f%% | Mem: %d/%d MB\n", snap.CPU.Load1, snap.Memory.UsedMB, snap.Memory.TotalMB)
package observability
