// shutdown.go — apagado graceful del daemon bos.
// Extraído de cmd/bos/main.go en F1.9 — SRP: main.go solo orquesta.
//
// F9.0 (hallazgo de staging real 13.140.128.230): el apagado del DAEMON
// (SIGTERM de systemctl restart/stop) NO puede apagar el CLUSTER. La saga
// drain→stop kubelet→stop containerd derribaba el nodo en cada redeploy
// del binario (cordon 08:59:46Z + kubelet muerto 09:00:24Z — dos incidentes
// el 2026-06-10). El apagado del stack completo queda reservado a la orden
// explícita del operador (acción WS "shutdown" del dashboard — P11).
package main

import (
	"os"
	"strconv"

	"bos/internal/audit"
	"bos/internal/health"
	"bos/internal/installer"
	"bos/internal/reconcile"
	"bos/internal/server"
	"bos/internal/system"
	"bos/internal/watchdog"
	"bos/internal/paths"

	"github.com/rs/zerolog/log"
)

// shutdown realiza el apagado graceful según el ámbito solicitado.
//
//   - fullStack=false (SIGTERM/SIGINT — restart o stop del servicio):
//     detiene SOLO los subsistemas del daemon. El cluster K8s sigue intacto.
//   - fullStack=true (orden explícita del operador vía WS "shutdown"):
//     además ejecuta la saga de apagado del nodo (drain → kubelet →
//     containerd) ANTES de detener los subsistemas.
//
// Todos los punteros admiten nil (robustez en arranques parciales).
func shutdown(apiServer *server.Server, healthChecker *health.Checker, reconcileScheduler *reconcile.Scheduler, orchestrator *installer.Orchestrator, wd *watchdog.UnifiedWatchdog, fullStack bool) {
	// 1. Notificar a systemd que estamos deteniéndonos
	system.SDNotify("STOPPING=1")

	// 2. Saga de apagado del stack — SOLO bajo orden explícita del operador
	if fullStack && orchestrator != nil {
		nodeName, _ := os.Hostname()
		phases := orchestrator.Shutdown(nodeName)
		audit.Log(paths.AuditLog, "SHUTDOWN",
			"user=root",
			"scope=full_stack",
			"phases="+strconv.Itoa(len(phases)),
			"action=saga_shutdown_complete")
	} else {
		audit.Log(paths.AuditLog, "SHUTDOWN",
			"user=root",
			"scope=daemon_only",
			"action=cluster_intacto")
	}

	// 3. Detener subsistemas internos
	if wd != nil {
		wd.Stop()
	}
	if apiServer != nil {
		apiServer.Shutdown()
	}
	if healthChecker != nil {
		healthChecker.Stop()
	}
	if reconcileScheduler != nil {
		reconcileScheduler.Stop()
	}

	// 4. Registro de auditoría final
	audit.Log(paths.AuditLog, "SHUTDOWN", "user=root", "state=stopped")
	log.Info().Msg("bos daemon stopped — all subsystems shut down")
}
