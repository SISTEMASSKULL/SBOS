// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package repair implementa la reparación multi-capa unificada del SBOS (D1).
// Cubre tres capas: Ubuntu host, nodos Kubernetes y fichas BOS.
//
// # Responsabilidades
//
//   - Capa Ubuntu: dpkg --audit → apt --fix-broken → restart de servicios fallidos.
//   - Capa K8s: diagnóstico de nodos NotReady, restart de pods fallidos, uncordon.
//   - Capa BOS: diagnóstico de fichas DEGRADADA/ERROR, triggering de saga repair.
//   - Exponer HealthCheck slice para el watchdog y la Core UI.
//   - Modo dry-run: loguea acciones sin ejecutarlas (seguro para diagnóstico).
//
// # Fuera de alcance
//
//   - Repair de datos en bases de datos — responsabilidad de cada ficha.
//   - Cordon/drain de nodos para mantenimiento planificado — responsabilidad de maintenance.
//   - Gestión de backups — responsabilidad de bBackup (daemon futuro).
//
// # Dependencias
//
//   - apt-get, dpkg, systemctl — binarios del host.
//   - kubectl — operaciones K8s de diagnóstico y reparación.
//   - log/slog — logging estructurado de cada paso de reparación.
//
// # Callers principales
//
//   - internal/watchdog/unified_watchdog.go — dispara reparación por capa.
//   - internal/reconcile/scheduler.go — dispara Repair() por drift o health DEGRADED.
//
// # Estándares y referencias
//
//   - P14 (diagnosis_first): diagnóstico antes de ejecutar cualquier reparación.
//   - ADR-021 #11 — estado REPARANDO y transiciones posibles.
//   - SBOS-032 §4 — runbook de reparación por capa.
//
// # Ejemplo de uso
//
//	repairer := repair.NewOSRepairer(false, logger)
//	result := repairer.Repair()
//	for _, step := range result.Steps {
//	    fmt.Printf("[%s] %s\n", step.Status, step.Action)
//	}
package repair
