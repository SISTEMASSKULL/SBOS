package server

// query_system.go — Sagas bos.query.system y bos.query.vdi (M-13, F6.6/F6.8).

import (
	"context"
	"errors"
	"strings"

	"bos/internal/query"
)

// ── bos.query.system (F6.6) ──────────────────────────────────────────────

// rpcQuerySystem — método: bos.query.system
//
// Vista unificada Ubuntu + K8s + fichas + Context Plane + certificación.
// Params: {"tenant_id": string (opcional — habilita la fuente context_plane)}
// Returns: claves por fuente + "semaforo" + "timestamp" + "duration_ms".
// SLO: p99 < 4s (deadline interno del motor).
func (s *Server) rpcQuerySystem(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	_ = parseParams(req.Params, &p)

	k8sNodesSrc := query.Source(query.K8sNodesSummary)
	if s.k8sQuerier != nil {
		k8sNodesSrc = s.k8sQuerier.NodesSummary
	}
	sources := map[string]query.Source{
		"ubuntu":        query.UbuntuSnapshot,
		"kubernetes":    k8sNodesSrc,
		"fichas":        s.fichasResumenSource(),
		"certificacion": s.certificacionSource(),
	}
	if p.TenantID != "" {
		sources["context_plane"] = s.contextPlaneSource(p.TenantID)
	}

	out := query.Run(context.Background(), sources)
	out["semaforo"] = query.CalcSemaforo(out, []string{"ubuntu", "fichas"})
	return rpcOK(req.ID, out)
}

// ── bos.query.vdi (F6.8) ──────────────────────────────────────────────────

// fichasVDI son las fichas que componen el VDI Layer (BOS-REPAIR-04).
var fichasVDI = [...]string{"nextcloud", "guacamole", "fedora-logico"}

// rpcQueryVdi — método: bos.query.vdi
//
// Vista unificada del VDI Layer: una llamada reemplaza 6 verificaciones.
// Params: {"tenant_id": string (opcional)}
// Returns: nextcloud, guacamole, fedora_logico, context_plane_vdi,
// semaforo_vdi + metadatos. SLO: p99 < 3s (cubierto por deadline 4s).
func (s *Server) rpcQueryVdi(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	_ = parseParams(req.Params, &p)

	sources := map[string]query.Source{}
	for _, ficha := range fichasVDI {
		clave := strings.ReplaceAll(ficha, "-", "_")
		sources[clave] = s.fichaVistaSource(ficha)
	}
	if p.TenantID != "" {
		sources["context_plane_vdi"] = s.contextPlaneSource(p.TenantID)
	}

	out := query.Run(context.Background(), sources)
	out["tenant_id"] = p.TenantID
	out["semaforo_vdi"] = query.CalcSemaforo(out,
		[]string{"nextcloud", "guacamole", "fedora_logico"})
	return rpcOK(req.ID, out)
}

// fichaVistaSource expone la vista corta de una ficha como fuente de saga.
func (s *Server) fichaVistaSource(fichaID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		return fichaEstadoVista(st, fichaID), nil
	}
}
