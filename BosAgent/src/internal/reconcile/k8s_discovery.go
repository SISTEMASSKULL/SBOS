// Package reconcile — Descubrimiento de estado K8s real para fichas (M2.2).
//
// Problema: el reconciliador solo compara hashes de archivos declarativos
// pero no sabe si el workload ESTÁ corriendo en K8s. Fichas instaladas
// fuera del Ficha Engine quedan como PENDIENTE indefinidamente.
//
// Solución: DiscoverK8sStates escanea servers/, lee yaml_engine.yml de cada
// ficha para obtener el namespace, consulta K8s en modo LECTURA PURA, y
// retorna el mapa ficha_id → FichaState real.
//
// Cero modificaciones al cluster — solo kubectl get (SBOS-018 P1).
// Cero modificaciones a .sbos_state.json — el Scheduler decide qué hacer.
//
// Callers conocidos:
//   - Scheduler.reconcile() — actualiza el state manager antes del hash-diff.
//   - internal/server/jsonrpc.go — bos.ficha.status (estado en tiempo real).
//
// Estándares: SBOS-055 SOV-01..08, ADR-021, SBOS-018 P1, SBOS-050 P9.
package reconcile

import (
	"os"
	"path/filepath"

	"bos/internal/ficha"
	"bos/internal/k8s"
	"bos/internal/state"
	"log/slog"
)

// K8sDiscovery descubre el estado real de las fichas consultando K8s.
// Solo lectura — no modifica pods, deployments, ni el cluster.
type K8sDiscovery struct {
	serversPath string
	k8sCore     *k8s.Core
	logger      *slog.Logger
}

// NewK8sDiscovery crea un K8sDiscovery.
//
// Recibe:
//   - serversPath: ruta al directorio servers/ (paths.ServersPath).
//   - k8sCore: cliente K8s (solo lectura en este contexto).
//   - logger: logger estructurado.
func NewK8sDiscovery(serversPath string, k8sCore *k8s.Core, logger *slog.Logger) *K8sDiscovery {
	return &K8sDiscovery{
		serversPath: serversPath,
		k8sCore:     k8sCore,
		logger:      logger,
	}
}

// K8sDiscoveryResult contiene los estados K8s descubiertos para un conjunto de fichas.
type K8sDiscoveryResult struct {
	// States mapea ficha_id → FichaState derivado del estado K8s real.
	States map[string]state.FichaState
	// Probed es el número de fichas para las que se pudo hacer probe K8s.
	Probed int
	// Skipped es el número de fichas que no tienen runtime kubernetes.
	Skipped int
	// Errors es el número de fichas donde el probe falló (kubectl error no-not-found).
	Errors int
}

// DiscoverK8sStates escanea servers/ y para cada ficha kubernetes determina
// su estado real consultando el cluster. Solo lectura — no modifica nada.
//
// Retorna: K8sDiscoveryResult con el mapa ficha_id → FichaState.
//
// Si k8sCore es nil (modo sin K8s), retorna resultado vacío sin error.
func (d *K8sDiscovery) DiscoverK8sStates() *K8sDiscoveryResult {
	result := &K8sDiscoveryResult{
		States: make(map[string]state.FichaState),
	}

	if d.k8sCore == nil {
		d.logger.Debug("k8s_discovery: k8sCore nil — modo sin K8s")
		return result
	}

	// Escanear servers/ en dos niveles: servers/<servidor>/<ficha>/
	serverEntries, err := os.ReadDir(d.serversPath)
	if err != nil {
		d.logger.Warn("k8s_discovery: no se pudo leer servers/", "err", err)
		return result
	}

	for _, serverEntry := range serverEntries {
		if !serverEntry.IsDir() {
			continue
		}
		serverPath := filepath.Join(d.serversPath, serverEntry.Name())

		fichaEntries, err := os.ReadDir(serverPath)
		if err != nil {
			continue
		}

		for _, fichaEntry := range fichaEntries {
			if !fichaEntry.IsDir() {
				continue
			}
			fichaPath := filepath.Join(serverPath, fichaEntry.Name())
			d.probeOne(fichaPath, result)
		}
	}

	d.logger.Info("k8s_discovery completado",
		"probed", result.Probed,
		"skipped", result.Skipped,
		"errors", result.Errors,
		"instaladas", countState(result.States, state.StateInstalled),
	)
	return result
}

// probeOne hace el probe K8s para una ficha individual y actualiza el resultado.
func (d *K8sDiscovery) probeOne(fichaPath string, result *K8sDiscoveryResult) {
	// Verificar que tiene task_catalog.sh (es una ficha válida)
	tcPath := filepath.Join(fichaPath, "task_catalog.sh")
	if _, err := os.Stat(tcPath); err != nil {
		return
	}

	info, err := ficha.ParseWorkloadInfo(fichaPath)
	if err != nil {
		// Sin manifest.yml — no es una ficha completa
		return
	}

	if !info.CanProbe() {
		result.Skipped++
		return
	}

	ws, err := d.k8sCore.GetWorkloadStatus(info.Kind, info.FichaID, info.Namespace)
	if err != nil {
		d.logger.Debug("k8s_discovery: probe error",
			"ficha", info.FichaID,
			"kind", info.Kind,
			"ns", info.Namespace,
			"err", err,
		)
		result.Errors++
		return
	}

	fichaState := workloadStatusToFichaState(ws)
	result.States[info.FichaID] = fichaState
	result.Probed++

	if fichaState == state.StateInstalled {
		d.logger.Info("k8s_discovery: ficha INSTALADA",
			"ficha", info.FichaID,
			"kind", info.Kind,
			"ns", info.Namespace,
		)
	} else {
		d.logger.Debug("k8s_discovery: ficha probe",
			"ficha", info.FichaID,
			"state", fichaState,
		)
	}
}

// workloadStatusToFichaState mapea WorkloadStatus → FichaState (ADR-021).
//
//   - IsReady()   → INSTALADA (todas las réplicas deseadas están Ready)
//   - IsDegraded() → DEGRADADA (hay réplicas pero no todas Ready)
//   - IsFound() pero sin réplicas → ERROR_FISICO (CrashLoop, OOM, ImagePull...)
//   - !IsFound() → PENDIENTE (no existe en K8s)
func workloadStatusToFichaState(ws *k8s.WorkloadStatus) state.FichaState {
	switch {
	case ws.IsReady():
		return state.StateInstalled
	case ws.IsDegraded():
		return state.StateDegraded
	case ws.Found:
		return state.StatePhysicalError
	default:
		return state.StatePending
	}
}

// countState cuenta fichas con un estado específico en el mapa.
func countState(states map[string]state.FichaState, target state.FichaState) int {
	n := 0
	for _, s := range states {
		if s == target {
			n++
		}
	}
	return n
}
