package server

// k8s_handlers.go — F9.5/F9.6: módulos bos.k8s.* (gobierno del cluster) y
// bos.maintenance.* (sagas de mantenimiento) — BOS-REPAIR-02, ADR-004.
//
// Todos los mutadores están en destructiveMethods (F6.1: exigen token) y
// auditados con audit.Log (ISO 27001 A.8.15). El drain real en single-node
// deja el cluster sin capacidad: dry_run=true es el default — el drain
// real exige dry_run:false explícito.

import (
	"errors"
	"fmt"
	"time"

	"bos/internal/audit"
	"bos/internal/k8s"
	"bos/internal/maintenance"
	"bos/internal/paths"
)

// K8sOperator es el puerto a las operaciones de cluster (lo implementa
// internal/k8s.Core; en tests, un stub).
type K8sOperator interface {
	GetNodes() ([]k8s.NodeInfo, error)
	Cordon(node string) error
	Uncordon(node string) error
	Drain(node string, timeout time.Duration, dryRun bool) (string, error)
	EvictPod(namespace, pod string, gracePeriod int) error
	ScaleDeployment(namespace, deployment string, replicas int) error
	RolloutStatus(namespace, deployment string) (string, error)
	RolloutUndo(namespace, deployment string) error
	SetResources(namespace, deployment, cpu, memory string) error
}

// SetK8sOperator inyecta el operador de cluster (run_normal.go).
func (s *Server) SetK8sOperator(op K8sOperator) { s.k8sOp = op }

// SetMaintenanceService inyecta el servicio de mantenimiento (run_normal.go).
func (s *Server) SetMaintenanceService(m *maintenance.Service) { s.maintSvc = m }

// k8sNoDisponible responde el error estándar cuando el operador no está inyectado.
func k8sNoDisponible(id interface{}) RPCResponse {
	return rpcFail(id, rpcError(ErrInternal, "operador K8s no disponible (modo config-pending o sin kubeconfig)"))
}

// ── bos.k8s.node.* ────────────────────────────────────────────────────────

// rpcK8sNodeList — método: bos.k8s.node.list
// Params: ninguno · Returns: {"nodes": [...], "total": int}
func (s *Server) rpcK8sNodeList(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	nodes, err := s.k8sOp.GetNodes()
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"nodes": nodes, "total": len(nodes)})
}

// rpcK8sNodeCordon — método: bos.k8s.node.cordon (destructivo)
// Params: {"node": string}
func (s *Server) rpcK8sNodeCordon(req *RPCRequest) RPCResponse {
	return s.nodeOp(req, "cordon", func(node string) error { return s.k8sOp.Cordon(node) })
}

// rpcK8sNodeUncordon — método: bos.k8s.node.uncordon (destructivo)
// Params: {"node": string}
func (s *Server) rpcK8sNodeUncordon(req *RPCRequest) RPCResponse {
	return s.nodeOp(req, "uncordon", func(node string) error { return s.k8sOp.Uncordon(node) })
}

// nodeOp factoriza cordon/uncordon: parseo, audit y respuesta uniforme.
func (s *Server) nodeOp(req *RPCRequest, op string, fn func(string) error) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Node string `json:"node"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Node == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "node requerido"))
	}
	audit.Log(paths.AuditLog, "K8S_NODE_"+op, "node="+p.Node)
	if err := fn(p.Node); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"node": p.Node, op: true})
}

// rpcK8sNodeDrain — método: bos.k8s.node.drain (destructivo, saga)
//
// Params: {"node": string, "timeout_seconds": int, "dry_run": bool}
// dry_run por DEFECTO true: el drain real exige dry_run:false explícito
// (en single-node deja el cluster sin capacidad — F6.10).
func (s *Server) rpcK8sNodeDrain(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	p := struct {
		Node       string `json:"node"`
		TimeoutSec int    `json:"timeout_seconds"`
		DryRun     *bool  `json:"dry_run"`
	}{}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Node == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "node requerido"))
	}
	dryRun := true
	if p.DryRun != nil {
		dryRun = *p.DryRun
	}
	timeout := time.Duration(p.TimeoutSec) * time.Second
	audit.Log(paths.AuditLog, "K8S_NODE_drain",
		"node="+p.Node, fmt.Sprintf("dry_run=%v", dryRun))
	out, err := s.k8sOp.Drain(p.Node, timeout, dryRun)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"node": p.Node, "dry_run": dryRun, "output": out,
	})
}

// ── bos.k8s.pod.* ─────────────────────────────────────────────────────────

// rpcK8sPodEvict — método: bos.k8s.pod.evict (destructivo)
// Params: {"namespace": string, "pod": string, "grace_period": int}
func (s *Server) rpcK8sPodEvict(req *RPCRequest) RPCResponse {
	return s.podOp(req, "evict")
}

// rpcK8sPodRestart — método: bos.k8s.pod.restart (destructivo)
// Reinicio controlado: delete pod → el ReplicaSet crea el reemplazo.
// Params: {"namespace": string, "pod": string, "grace_period": int}
func (s *Server) rpcK8sPodRestart(req *RPCRequest) RPCResponse {
	return s.podOp(req, "restart")
}

func (s *Server) podOp(req *RPCRequest, op string) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Namespace   string `json:"namespace"`
		Pod         string `json:"pod"`
		GracePeriod int    `json:"grace_period"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Namespace == "" || p.Pod == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "namespace y pod requeridos"))
	}
	audit.Log(paths.AuditLog, "K8S_POD_"+op, "ns="+p.Namespace, "pod="+p.Pod)
	if err := s.k8sOp.EvictPod(p.Namespace, p.Pod, p.GracePeriod); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"namespace": p.Namespace, "pod": p.Pod, op: true,
	})
}

// ── bos.k8s.scale / rollout / resources ──────────────────────────────────

// rpcK8sScale — método: bos.k8s.scale (destructivo)
//
// Params: {"namespace","deployment","replicas", "ficha_id" (opcional)}
// Si ficha_id viene y su manifest declara scaling, las réplicas se validan
// contra min/max (la política es ley — BOS-REPAIR-02).
func (s *Server) rpcK8sScale(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Namespace  string `json:"namespace"`
		Deployment string `json:"deployment"`
		Replicas   *int   `json:"replicas"`
		FichaID    string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Namespace == "" || p.Deployment == "" || p.Replicas == nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "namespace, deployment y replicas requeridos"))
	}
	replicas := *p.Replicas

	// validación contra la política del manifest (decisión coordinada)
	if p.FichaID != "" && s.plugins != nil {
		if mf, ok := s.plugins.Get(p.FichaID); ok && mf.Scaling != nil {
			min, max := mf.Scaling.MinReplicas, mf.Scaling.MaxReplicas
			if min > 0 && replicas < min {
				return rpcFail(req.ID, rpcError(ErrGovernanceDeny,
					fmt.Sprintf("la política de %s exige min_replicas=%d (pedido: %d)", p.FichaID, min, replicas)))
			}
			if max > 0 && replicas > max {
				return rpcFail(req.ID, rpcError(ErrGovernanceDeny,
					fmt.Sprintf("la política de %s limita max_replicas=%d (pedido: %d)", p.FichaID, max, replicas)))
			}
		}
	}

	audit.Log(paths.AuditLog, "K8S_SCALE",
		"ns="+p.Namespace, "deploy="+p.Deployment, fmt.Sprintf("replicas=%d", replicas))
	if err := s.k8sOp.ScaleDeployment(p.Namespace, p.Deployment, replicas); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"namespace": p.Namespace, "deployment": p.Deployment, "replicas": replicas,
	})
}

// rpcK8sRolloutStatus — método: bos.k8s.rollout.status (lectura)
func (s *Server) rpcK8sRolloutStatus(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Namespace  string `json:"namespace"`
		Deployment string `json:"deployment"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Namespace == "" || p.Deployment == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "namespace y deployment requeridos"))
	}
	out, err := s.k8sOp.RolloutStatus(p.Namespace, p.Deployment)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"status": out})
}

// rpcK8sRolloutUndo — método: bos.k8s.rollout.undo (destructivo)
// Reversibilidad ADR-021: vuelve a la revisión anterior del deployment.
func (s *Server) rpcK8sRolloutUndo(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Namespace  string `json:"namespace"`
		Deployment string `json:"deployment"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Namespace == "" || p.Deployment == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "namespace y deployment requeridos"))
	}
	audit.Log(paths.AuditLog, "K8S_ROLLOUT_UNDO", "ns="+p.Namespace, "deploy="+p.Deployment)
	if err := s.k8sOp.RolloutUndo(p.Namespace, p.Deployment); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"undone": true})
}

// rpcK8sResourcesSet — método: bos.k8s.resources.set (destructivo)
// Actuador del escalado vertical. Params: {"namespace","deployment","cpu","memory"}
func (s *Server) rpcK8sResourcesSet(req *RPCRequest) RPCResponse {
	if s.k8sOp == nil {
		return k8sNoDisponible(req.ID)
	}
	var p struct {
		Namespace  string `json:"namespace"`
		Deployment string `json:"deployment"`
		CPU        string `json:"cpu"`
		Memory     string `json:"memory"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Namespace == "" || p.Deployment == "" || (p.CPU == "" && p.Memory == "") {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "namespace, deployment y cpu o memory requeridos"))
	}
	audit.Log(paths.AuditLog, "K8S_RESOURCES_SET",
		"ns="+p.Namespace, "deploy="+p.Deployment, "cpu="+p.CPU, "mem="+p.Memory)
	if err := s.k8sOp.SetResources(p.Namespace, p.Deployment, p.CPU, p.Memory); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"applied": true})
}

// ── bos.maintenance.* (F9.6) ─────────────────────────────────────────────

// rpcMaintenanceStart — método: bos.maintenance.start (destructivo, saga)
//
// Params: {"node": string, "drain_timeout_seconds": int, "dry_run_drain": bool}
// Ejecuta cordon→drain→uncordon con la garantía de uncordon (F9.4). La
// operación intermedia de mantenimiento llega vía catálogo en F10.
func (s *Server) rpcMaintenanceStart(req *RPCRequest) RPCResponse {
	if s.maintSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "servicio de mantenimiento no disponible"))
	}
	p := struct {
		Node        string `json:"node"`
		DrainSec    int    `json:"drain_timeout_seconds"`
		DryRunDrain *bool  `json:"dry_run_drain"`
	}{}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Node == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "node requerido"))
	}
	dryRun := true
	if p.DryRunDrain != nil {
		dryRun = *p.DryRunDrain
	}
	audit.Log(paths.AuditLog, "MAINTENANCE_START",
		"node="+p.Node, fmt.Sprintf("dry_run_drain=%v", dryRun))
	res, err := s.maintSvc.Ejecutar(p.Node, time.Duration(p.DrainSec)*time.Second, dryRun, nil)
	if err != nil {
		if errors.Is(err, maintenance.ErrEnCurso) {
			return rpcFail(req.ID, rpcError(ErrStateConflict, err.Error()))
		}
		// res lleva el detalle (pasos ejecutados, uncordoned) — se adjunta
		fail := rpcFail(req.ID, rpcError(ErrSagaFailed, err.Error()))
		fail.Error.Data = res
		return fail
	}
	return rpcOK(req.ID, res)
}

// rpcMaintenanceStatus — método: bos.maintenance.status (lectura)
func (s *Server) rpcMaintenanceStatus(req *RPCRequest) RPCResponse {
	if s.maintSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "servicio de mantenimiento no disponible"))
	}
	return rpcOK(req.ID, s.maintSvc.Estado())
}

// rpcMaintenanceCancel — método: bos.maintenance.cancel (destructivo)
func (s *Server) rpcMaintenanceCancel(req *RPCRequest) RPCResponse {
	if s.maintSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "servicio de mantenimiento no disponible"))
	}
	cancelada := s.maintSvc.Cancelar()
	audit.Log(paths.AuditLog, "MAINTENANCE_CANCEL", fmt.Sprintf("activa=%v", cancelada))
	return rpcOK(req.ID, map[string]interface{}{"cancelada": cancelada})
}
