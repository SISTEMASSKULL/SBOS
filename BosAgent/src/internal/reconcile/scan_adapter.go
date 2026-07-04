// Package reconcile — adaptador para exponer K8sDiscovery al server package.
//
// K8sScanAdapter implementa server.K8sScanner:
//   - Llama DiscoverK8sStates() (solo lectura)
//   - Aplica los estados al state manager vía SetK8sDiscoveredState
//
// Callers conocidos:
//   - cmd/bos/run_normal.go — inyecta en Server.SetK8sScanner
//   - internal/server/rpc_ficha_f11.go — llamado por bos.ficha.rescan
package reconcile

import "bos/internal/state"

// k8sStateApplier es el subconjunto de state.Manager que K8sScanAdapter necesita.
type k8sStateApplier interface {
	SetK8sDiscoveredState(name string, discovered state.FichaState) error
}

// K8sScanAdapter implementa server.K8sScanner combinando K8sDiscovery + state manager.
// Diseñado para ser inyectado en el Server para descubrimiento bajo demanda.
type K8sScanAdapter struct {
	discovery *K8sDiscovery
	stateMgr  k8sStateApplier
}

// NewK8sScanAdapter crea un adaptador listo para ser inyectado en el Server.
func NewK8sScanAdapter(d *K8sDiscovery, s k8sStateApplier) *K8sScanAdapter {
	return &K8sScanAdapter{discovery: d, stateMgr: s}
}

// Scan ejecuta un descubrimiento K8s completo y aplica los estados al state manager.
// Implementa server.K8sScanner.
//
// Retorna: (probed, skipped, errors) — métricas del ciclo de descubrimiento.
func (a *K8sScanAdapter) Scan() (probed, skipped, errors int) {
	result := a.discovery.DiscoverK8sStates()
	for fichaID, fichaState := range result.States {
		_ = a.stateMgr.SetK8sDiscoveredState(fichaID, fichaState)
	}
	return result.Probed, result.Skipped, result.Errors
}
