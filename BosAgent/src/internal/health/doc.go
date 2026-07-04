// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package health implementa el health checker periódico de las fichas instaladas.
// Lee el check_command definido en cada manifest.yml y clasifica el resultado
// en cuatro estados (HEALTHY, DEGRADED, DOWN, UNKNOWN).
//
// # Responsabilidades
//
//   - Ejecutar check_command de cada ficha via exec.CommandContext con timeout.
//   - Clasificar resultados: exit 0 → HEALTHY, no-zero → DEGRADED/DOWN según
//     conteo de fallos consecutivos.
//   - Actualizar health_status en STATE_MANAGER mediante SetHealth().
//   - Exponer Classify() para clasificación desde señales externas (podReady, etc.).
//
// # Fuera de alcance
//
//   - Reparar fichas degradadas — responsabilidad del observer y reconcile.
//   - Exponer métricas Prometheus — responsabilidad de internal/metrics.
//   - Interpretar el output del check_command — solo el exit code importa.
//
// # Dependencias
//
//   - internal/state — STATE_MANAGER (Read, SetHealth).
//   - gopkg.in/yaml.v3 — leer health config de manifest.yml.
//
// # Callers principales
//
//   - cmd/bos/main.go — crea Checker y lo inicia como goroutine.
//   - internal/observer/startup.go — StartupReconcile recibe *Checker para
//     consultar el estado inicial post-boot.
//
// # Estándares y referencias
//
//   - SBOS-018 §6 — health check loop del IAM Installer.
//   - ADR-021 #8 — transición INSTALADA→DEGRADADA cuando health falla.
//
// # Ejemplo de uso
//
//	checker := health.NewChecker(stateMgr, 30*time.Second, paths.ServersPath, logger)
//	go checker.Run()
//	defer checker.Stop()
package health
