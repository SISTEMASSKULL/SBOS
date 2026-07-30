// Package server — tests F9.5/F9.6: handlers bos.k8s.* y bos.maintenance.*
// con operador stub (cada método con test — DoD F9.5).
package server

import (
	"sync"
	"testing"
	"time"

	"bos/internal/k8s"
	"bos/internal/maintenance"
	"bos/internal/plugin"
	"bos/internal/state"
)

// k8sOpStub implementa K8sOperator registrando llamadas.
type k8sOpStub struct {
	mu       sync.Mutex
	llamadas []string
}

func (s *k8sOpStub) reg(call string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.llamadas = append(s.llamadas, call)
}
func (s *k8sOpStub) GetNodes() ([]k8s.NodeInfo, error) {
	s.reg("get-nodes")
	return []k8s.NodeInfo{{Name: "nodo-01", Ready: true, Schedulable: true}}, nil
}
func (s *k8sOpStub) Cordon(n string) error   { s.reg("cordon:" + n); return nil }
func (s *k8sOpStub) Uncordon(n string) error { s.reg("uncordon:" + n); return nil }
func (s *k8sOpStub) Drain(n string, _ time.Duration, dry bool) (string, error) {
	if dry {
		s.reg("drain-dry:" + n)
	} else {
		s.reg("drain-real:" + n)
	}
	return "evicted", nil
}
func (s *k8sOpStub) EvictPod(ns, pod string, _ int) error {
	s.reg("evict:" + ns + "/" + pod)
	return nil
}
func (s *k8sOpStub) ScaleDeployment(ns, d string, r int) error {
	s.reg("scale:" + ns + "/" + d)
	return nil
}
func (s *k8sOpStub) RolloutStatus(ns, d string) (string, error) { s.reg("rs"); return "ok", nil }
func (s *k8sOpStub) RolloutUndo(ns, d string) error             { s.reg("ru"); return nil }
func (s *k8sOpStub) SetResources(ns, d, c, m string) error      { s.reg("res"); return nil }
func (s *k8sOpStub) GetWorkloadStatus(kind, name, ns string) (*k8s.WorkloadStatus, error) {
	s.reg("gws:" + kind + "/" + name)
	return &k8s.WorkloadStatus{
		Kind: kind, Name: name, Namespace: ns,
		DesiredReplicas: 2, ReadyReplicas: 2, Found: true,
	}, nil
}

func (s *k8sOpStub) ultima() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.llamadas) == 0 {
		return ""
	}
	return s.llamadas[len(s.llamadas)-1]
}

func makeK8sServer() (*Server, *k8sOpStub) {
	s := makeCtxTestServer()
	stub := &k8sOpStub{}
	s.SetK8sOperator(stub)
	s.SetMaintenanceService(maintenance.NewService(stub))
	return s, stub
}

// TestK8sNodeOps: list/cordon/uncordon con args y guards.
func TestK8sNodeOps(t *testing.T) {
	s, stub := makeK8sServer()

	lista := s.rpcK8sNodeList(buildRPC("bos.k8s.node.list", nil))
	if lista.Error != nil || lista.Result.(map[string]interface{})["total"] != 1 {
		t.Fatalf("node.list: %+v", lista)
	}

	if r := s.rpcK8sNodeCordon(buildRPC("x", map[string]string{"node": "nodo-01"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if stub.ultima() != "cordon:nodo-01" {
		t.Errorf("cordon no llegó al operador: %s", stub.ultima())
	}
	if r := s.rpcK8sNodeUncordon(buildRPC("x", map[string]string{"node": "nodo-01"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if r := s.rpcK8sNodeCordon(buildRPC("x", map[string]string{})); r.Error == nil {
		t.Error("cordon sin node debe fallar")
	}

	// sin operador inyectado → error interno claro
	sinOp := makeCtxTestServer()
	if r := sinOp.rpcK8sNodeList(buildRPC("x", nil)); r.Error == nil || r.Error.Code != ErrInternal {
		t.Error("sin operador debe responder ErrInternal")
	}
}

// TestK8sDrain_DryRunPorDefecto: la salvaguarda single-node — sin dry_run
// explícito el drain es dry-run; el real exige dry_run:false.
func TestK8sDrain_DryRunPorDefecto(t *testing.T) {
	s, stub := makeK8sServer()

	r := s.rpcK8sNodeDrain(buildRPC("x", map[string]interface{}{"node": "nodo-01"}))
	if r.Error != nil {
		t.Fatal(r.Error)
	}
	if stub.ultima() != "drain-dry:nodo-01" {
		t.Errorf("drain por defecto debe ser dry-run: %s", stub.ultima())
	}
	if r.Result.(map[string]interface{})["dry_run"] != true {
		t.Error("la respuesta debe declarar dry_run")
	}

	r = s.rpcK8sNodeDrain(buildRPC("x", map[string]interface{}{"node": "nodo-01", "dry_run": false}))
	if r.Error != nil {
		t.Fatal(r.Error)
	}
	if stub.ultima() != "drain-real:nodo-01" {
		t.Errorf("dry_run:false debe drenar real: %s", stub.ultima())
	}
}

// TestK8sPodYRollout: evict/restart/rollout/resources con cada método.
func TestK8sPodYRollout(t *testing.T) {
	s, stub := makeK8sServer()

	if r := s.rpcK8sPodEvict(buildRPC("x", map[string]interface{}{
		"namespace": "sbos-monitoring", "pod": "ksm-1"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if stub.ultima() != "evict:sbos-monitoring/ksm-1" {
		t.Errorf("evict: %s", stub.ultima())
	}
	if r := s.rpcK8sPodRestart(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "pod": "p"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if r := s.rpcK8sPodEvict(buildRPC("x", map[string]interface{}{"pod": "p"})); r.Error == nil {
		t.Error("evict sin namespace debe fallar")
	}

	if r := s.rpcK8sRolloutStatus(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "deployment": "d"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if r := s.rpcK8sRolloutUndo(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "deployment": "d"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if r := s.rpcK8sResourcesSet(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "deployment": "d", "cpu": "500m"})); r.Error != nil {
		t.Fatal(r.Error)
	}
	if r := s.rpcK8sResourcesSet(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "deployment": "d"})); r.Error == nil {
		t.Error("resources.set sin cpu/memory debe fallar")
	}
}

// TestK8sScale_PoliticaDelManifest: la política scaling del manifest es ley
// (GovernanceDeny fuera de min/max — BOS-REPAIR-02).
func TestK8sScale_PoliticaDelManifest(t *testing.T) {
	s, stub := makeK8sServer()
	s.stateMgr = queryStateStub{fichas: map[string]*state.Ficha{}}
	s.plugins = stubCatalog{fichas: map[string]*plugin.FichaManifest{
		"redis": {ID: "redis", Scaling: &plugin.ScalingPolicy{
			Strategy: "coordinated", MinReplicas: 2, MaxReplicas: 4}},
	}}

	// dentro de la política → procede
	r := s.rpcK8sScale(buildRPC("x", map[string]interface{}{
		"namespace": "sbos-data", "deployment": "redis", "replicas": 3, "ficha_id": "redis"}))
	if r.Error != nil {
		t.Fatalf("scale válido: %v", r.Error)
	}
	if stub.ultima() != "scale:sbos-data/redis" {
		t.Errorf("scale no llegó: %s", stub.ultima())
	}

	// fuera de max → GovernanceDeny
	r = s.rpcK8sScale(buildRPC("x", map[string]interface{}{
		"namespace": "sbos-data", "deployment": "redis", "replicas": 9, "ficha_id": "redis"}))
	if r.Error == nil || r.Error.Code != ErrGovernanceDeny {
		t.Errorf("sobre max_replicas: want GovernanceDeny, got %+v", r)
	}
	// bajo min → GovernanceDeny
	r = s.rpcK8sScale(buildRPC("x", map[string]interface{}{
		"namespace": "sbos-data", "deployment": "redis", "replicas": 1, "ficha_id": "redis"}))
	if r.Error == nil || r.Error.Code != ErrGovernanceDeny {
		t.Errorf("bajo min_replicas: want GovernanceDeny, got %+v", r)
	}
	// sin replicas → InvalidParams
	r = s.rpcK8sScale(buildRPC("x", map[string]interface{}{
		"namespace": "ns", "deployment": "d"}))
	if r.Error == nil || r.Error.Code != ErrInvalidParams {
		t.Errorf("sin replicas: %+v", r)
	}
}

// TestMaintenanceStart_SagaCompleta es el DoD de F9.6: la saga vía RPC
// ejecuta cordon→drain(dry)→uncordon y reporta los pasos; status refleja
// inactividad al cerrar; cancel sin saga retorna false.
func TestMaintenanceStart_SagaCompleta(t *testing.T) {
	s, stub := makeK8sServer()

	r := s.rpcMaintenanceStart(buildRPC("x", map[string]interface{}{"node": "nodo-01"}))
	if r.Error != nil {
		t.Fatalf("maintenance.start: %v", r.Error)
	}
	res := r.Result.(*maintenance.Resultado)
	if !res.Exito || !res.Uncordoned {
		t.Errorf("saga completa: %+v", res)
	}
	if stub.ultima() != "uncordon:nodo-01" {
		t.Errorf("el último paso debe ser uncordon: %s", stub.ultima())
	}

	st := s.rpcMaintenanceStatus(buildRPC("x", nil))
	if st.Error != nil || st.Result.(maintenance.Estado).Activa {
		t.Errorf("status tras saga: %+v", st)
	}

	c := s.rpcMaintenanceCancel(buildRPC("x", nil))
	if c.Result.(map[string]interface{})["cancelada"] != false {
		t.Error("cancel sin saga activa → false")
	}

	if r := s.rpcMaintenanceStart(buildRPC("x", map[string]string{})); r.Error == nil {
		t.Error("start sin node debe fallar")
	}
}
