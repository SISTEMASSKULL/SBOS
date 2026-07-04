// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package maintenance implementa la saga compensada de mantenimiento de nodos:
// cordon → drain → [tarea de mantenimiento] → uncordon (ADR-004).
//
// # Responsabilidades
//
// Gestionar el ciclo completo de mantenimiento de un nodo K8s de forma
// segura y reversible. Cada paso tiene su compensador explícito:
//
//	Paso         Compensador (en caso de fallo)
//	──────────── ────────────────────────────────────────────────────────
//	cordon       uncordon (el nodo vuelve a aceptar pods)
//	drain        reschedule (los pods se redistribuyen al nodo original)
//	maintenance  log de fallo + alerta HITL
//	uncordon     retry ×3 → alerta crítica (nodo queda aislado si falla)
//
// Si drain falla, el compensador es automático (uncordon).
// Si uncordon final falla 3 veces → el nodo queda en MANTENIMIENTO_FORZADO
// y se alerta al operador (HITL).
//
// # Fuera de alcance
//
// No realiza la tarea de mantenimiento en sí (ej: actualización del SO) —
// solo gestiona el cordon/drain/uncordon alrededor de ella.
// No decide cuándo hacer mantenimiento — eso es el operador o el Scheduler.
//
// # Dependencias
//
// internal/paths: para la ruta del kubeconfig.
// internal/audit: para registrar cada paso de la saga.
// internal/observer: notifica cambio de estado del nodo.
//
// # Callers principales
//
// internal/server/jsonrpc.go: método bos.k8s.maintenance.
// cmd/bosctl/infra.go: comando `bosctl maintenance start`.
//
// # Estándares y referencias
//
// BOS-REPAIR-09 — Fase 9: sagas compensadas para operaciones K8s.
// ADR-004 — Patrones de compensación en sagas del daemon bos.
// SBOS-032 — SLOs: el mantenimiento no debe violar SLO de disponibilidad.
//
// # Ejemplo de uso
//
//	saga := maintenance.NewSaga(k8sClient, auditLogger)
//	if err := saga.Run(ctx, "nodo-01", maintenance.Task{
//	    Type:    maintenance.OSUpdate,
//	    Timeout: 30 * time.Minute,
//	}); err != nil {
//	    log.Printf("maintenance saga: %v", err)
//	}
package maintenance
