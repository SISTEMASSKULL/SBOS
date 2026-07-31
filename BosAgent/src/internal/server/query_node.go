package server

// query_node.go — Sagas bos.query.node y bos.query.context (M-13, F6.10/F6.11).

import (
	"context"
	"errors"
	"time"

	bosctx "bos/internal/context"
	"bos/internal/query"
	"bos/internal/state"
)

// ── bos.query.node (F6.10) ────────────────────────────────────────────────

// rpcQueryNode — método: bos.query.node
//
// Diagnóstico completo de un nodo antes de mantenimiento: estado K8s,
// métricas del SO, pods alojados e impacto si se drena.
//
// Params: {"node": string (requerido)}
// Returns: k8s, ubuntu, fichas_en_nodo, impacto_si_se_drena, nodos_ready.
// SLO: p99 < 3s (cubierto por deadline 4s del motor).
func (s *Server) rpcQueryNode(req *RPCRequest) RPCResponse {
	var p struct {
		Node string `json:"node"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Node == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "node requerido"))
	}

	k8sSrc := query.Source(query.K8sNodesSummary)
	var podsSrc query.Source = func(ctx context.Context) (interface{}, error) {
		return query.K8sPodsOnNode(ctx, p.Node)
	}
	if s.k8sQuerier != nil {
		k8sSrc = s.k8sQuerier.NodesSummary
		node := p.Node
		podsSrc = func(ctx context.Context) (interface{}, error) {
			return s.k8sQuerier.PodsOnNode(ctx, node)
		}
	}
	sources := map[string]query.Source{
		"k8s":                 k8sSrc,
		"ubuntu":              query.UbuntuSnapshot, // host local — multi-nodo real llega con F9
		"fichas_en_nodo":      podsSrc,
		"impacto_si_se_drena": s.impactoDrainSource(),
	}

	out := query.Run(context.Background(), sources)
	out["node"] = p.Node
	ready, conocido := todosLosNodosReady(out["k8s"])
	if conocido {
		out["nodos_ready"] = ready
	}
	return rpcOK(req.ID, out)
}

// impactoDrainSource estima el impacto de drenar el nodo con las fichas
// críticas registradas (Thread "impacto" de BOS-REPAIR-04 §bos.query.node).
func (s *Server) impactoDrainSource() query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		return buildImpactoDrain(st), nil
	}
}

// buildImpactoDrain produce la sección impacto_si_se_drena. Función pura.
// En cluster de 1 nodo (estado actual del SBOS) drenar deja sin capacidad —
// advertencia obligatoria de BOS-REPAIR-04.
func buildImpactoDrain(st *state.SBOSState) map[string]interface{} {
	criticas := []string{}
	for _, f := range st.Fichas {
		if f.Criticality && f.State == state.StateInstalled {
			criticas = append(criticas, f.Name)
		}
	}
	return map[string]interface{}{
		"fichas_a_migrar": len(st.Fichas),
		"fichas_criticas": criticas,
		"advertencia":     "verificar capacidad restante del cluster antes de drenar — en cluster de 1 nodo el drain deja sin capacidad",
	}
}

// todosLosNodosReady evalúa si la fuente k8s reporta todos los nodos Ready.
// Retorna (ready, conocido) — conocido es false si la fuente degradó.
// Función pura — testeable sin cluster (DoD TestQueryNode_TodosReady).
func todosLosNodosReady(k8sVal interface{}) (bool, bool) {
	m, ok := k8sVal.(map[string]interface{})
	if !ok {
		return false, false
	}
	if _, hasErr := m["error"]; hasErr {
		return false, false
	}
	ready, okR := m["nodes_ready"].(int)
	total, okT := m["nodes_total"].(int)
	if !okR || !okT {
		// la fuente pudo viajar por JSON — los números llegan como float64
		readyF, okRF := m["nodes_ready"].(float64)
		totalF, okTF := m["nodes_total"].(float64)
		if !okRF || !okTF {
			return false, false
		}
		ready, total = int(readyF), int(totalF)
	}
	return total > 0 && ready == total, true
}

// ── bos.query.context (F6.11) ─────────────────────────────────────────────

// rpcQueryContext — método: bos.query.context
//
// Diagnóstico del Context Plane de un tenant: distribución de estados,
// anomalías (ctx sin BitMask, expirados no invalidados) y TTLs restantes.
//
// Params: {"tenant_id": string (requerido)}
// Returns: resumen, anomalias, distribucion_estados, ttls.
// SLO: p99 < 2s (3 vistas derivadas de una sola lectura — muy por debajo).
func (s *Server) rpcQueryContext(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.TenantID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "tenant_id requerido"))
	}
	if s.bosCtxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "context plane no disponible"))
	}

	// Una sola lectura del store; las tres vistas se derivan en memoria —
	// no amerita goroutines (el motor paralelo es para fuentes independientes).
	// ListAllByTenant: el diagnóstico necesita también las sesiones terminales.
	sessions, err := s.bosCtxSvc.ListAllByTenant(p.TenantID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	out := buildContextDiag(sessions)
	out["tenant_id"] = p.TenantID
	out["timestamp"] = time.Now().UTC().Format(time.RFC3339)
	return rpcOK(req.ID, out)
}

// buildContextDiag deriva resumen, anomalías y TTLs de las sesiones de un
// tenant. Función pura (BOS-REPAIR-04 §bos.query.context).
func buildContextDiag(sessions []*bosctx.SessionContext) map[string]interface{} {
	distribucion := map[string]int{}
	sinBitmask := []string{}
	expiradosNoInvalidados := []string{}
	ttls := make([]map[string]interface{}, 0, len(sessions))
	activos := 0

	for _, sc := range sessions {
		distribucion[sc.State.String()]++

		if sc.BitMask.IsZero() {
			// invariante SessionContext: BitMask > 0 post-auth (SBOS-049 §16.1)
			sinBitmask = append(sinBitmask, sc.CtxID)
		}
		if sc.IsExpired() && !sc.State.IsTerminal() {
			expiradosNoInvalidados = append(expiradosNoInvalidados, sc.CtxID)
		}
		if sc.State == bosctx.StateActivo && !sc.IsExpired() {
			activos++
			ttls = append(ttls, map[string]interface{}{
				"ctx_id":         sc.CtxID,
				"user_id":        sc.UserID,
				"ttl_restante_s": ttlRestante(sc),
				"expires_at":     sc.ExpiresAt,
			})
		}
	}

	return map[string]interface{}{
		"resumen": map[string]interface{}{
			"ctx_total":   len(sessions),
			"ctx_activos": activos,
		},
		"distribucion_estados": distribucion,
		"anomalias": map[string]interface{}{
			"ctx_sin_bitmask":              sinBitmask,
			"ctx_expirados_no_invalidados": expiradosNoInvalidados,
		},
		"ttls": ttls,
	}
}
