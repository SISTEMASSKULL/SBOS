package server

// query_repair.go — Saga bos.query.repair (M-13, F6.7).

import (
	"context"
	"errors"
	"fmt"

	bosctx "bos/internal/context"
	"bos/internal/query"
	"bos/internal/state"
)

// ── bos.query.repair (F6.7) ───────────────────────────────────────────────

// rpcQueryRepair — método: bos.query.repair
//
// Pre-diagnóstico antes de reparar: qué falla, por qué, qué impacto tiene.
// El watchdog DEBE invocarlo antes de auto-repair (BOS-REPAIR-12 §5.2) y
// queda registrado en audit antes de cualquier intervención.
//
// Params: {"ficha_id": string (requerido), "tenant_id": string (opcional)}
// Returns: estado_actual, diagnostico (causa_probable, logs), impacto,
// historial_reparaciones, recomendacion.
func (s *Server) rpcQueryRepair(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID  string `json:"ficha_id"`
		TenantID string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.FichaID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ficha_id requerido"))
	}

	sources := map[string]query.Source{
		"estado_actual": s.fichaEstadoSource(p.FichaID),
		"diagnostico":   s.diagnosticoSource(p.FichaID),
		"impacto":       s.impactoSource(p.FichaID, p.TenantID),
		"historial_reparaciones": func(_ context.Context) (interface{}, error) {
			return nil, errors.New("audit reader pendiente (F7) — historial no disponible")
		},
	}

	out := query.Run(context.Background(), sources)
	out["ficha_id"] = p.FichaID
	out["tenant_id"] = p.TenantID
	out["recomendacion"] = buildRecomendacion(p.FichaID, out)
	return rpcOK(req.ID, out)
}

// fichaEstadoSource expone el estado actual de una ficha (Thread 1).
func (s *Server) fichaEstadoSource(fichaID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		f, ok := st.Fichas[fichaID]
		if !ok {
			return nil, fmt.Errorf("ficha %s no registrada", fichaID)
		}
		return map[string]interface{}{
			"state":      string(f.State),
			"health":     f.HealthStatus,
			"version":    f.Version,
			"updated_at": f.UpdatedAt,
		}, nil
	}
}

// diagnosticoSource deriva la causa probable y reúne logs del pod (Threads 2+6).
func (s *Server) diagnosticoSource(fichaID string) query.Source {
	return func(ctx context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		f, ok := st.Fichas[fichaID]
		if !ok {
			return nil, fmt.Errorf("ficha %s no registrada", fichaID)
		}
		diag := map[string]interface{}{
			"causa_probable": causaProbable(f),
		}
		var logResult interface{}
		var logErr error
		if s.k8sQuerier != nil {
			logResult, logErr = s.k8sQuerier.PodLogs(ctx, fichaID, 50)
		} else {
			logResult, logErr = query.K8sPodLogs(ctx, fichaID, 50)
		}
		if logErr == nil {
			diag["logs_recientes"] = logResult
		} else {
			diag["logs_recientes"] = map[string]string{"error": logErr.Error()}
		}
		return diag, nil
	}
}

// impactoSource calcula dependientes afectados y contextos activos (Threads 4+7).
func (s *Server) impactoSource(fichaID, tenantID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		impacto := map[string]interface{}{
			"dependientes_afectados": s.dependientesDe(fichaID),
		}
		if tenantID != "" && s.bosCtxSvc != nil {
			sessions, err := s.bosCtxSvc.ListByTenant(tenantID)
			if err == nil {
				activos := 0
				for _, sc := range sessions {
					if sc.State == bosctx.StateActivo && !sc.IsExpired() {
						activos++
					}
				}
				impacto["ctx_id_activos"] = activos
				impacto["usuarios_afectados"] = activos
			}
		}
		return impacto, nil
	}
}

// dependientesDe lista las fichas cuyo manifest declara fichaID como dependencia.
func (s *Server) dependientesDe(fichaID string) []string {
	dependientes := []string{}
	if s.plugins == nil {
		return dependientes
	}
	for _, m := range s.plugins.List() {
		for _, dep := range m.Dependencies {
			if dep == fichaID {
				dependientes = append(dependientes, m.ID)
				break
			}
		}
	}
	return dependientes
}

// causaProbable deriva el diagnóstico inicial de los 18 estados de la ficha
// (ADR-021). Heurística de primer nivel — biaos la refinará con logs en F10.
func causaProbable(f *state.Ficha) string {
	switch f.State {
	case state.StateErrorFisico:
		return "recurso físico insuficiente (disco/red/CPU/memoria) — revisar el nodo"
	case state.StateErrorLogico:
		return "configuración, dependencias o schema drift — revisar manifest y deps"
	case state.StateErrorNoCorregible:
		return "reintentos agotados — requiere intervención humana (HITL)"
	case state.StateDegradada:
		if f.HealthStatus != "OK" {
			return "servicio degradado — probe de salud fallando (health=" + f.HealthStatus + ")"
		}
		return "capacidad reducida — replicas listas por debajo de lo deseado"
	case state.StateFallaInstalacion:
		return "saga install falló — evaluar rollback o limpieza"
	case state.StateFallaActualizacion:
		return "saga update falló — evaluar rollback a versión anterior"
	case state.StateInstalada:
		if f.HealthStatus != "OK" {
			return "estado INSTALADA con probe inconsistente — verificar endpoint"
		}
		return "sin anomalías detectadas"
	default:
		return "estado " + string(f.State) + " — sin diagnóstico automático"
	}
}

// buildRecomendacion produce la acción sugerida según el estado agregado.
func buildRecomendacion(fichaID string, out map[string]interface{}) map[string]interface{} {
	rec := map[string]interface{}{
		"accion":       "bos.ficha.repair",
		"rpc_ejecutar": fmt.Sprintf(`bosctl rpc bos.ficha.repair '{"ficha_id":"%s"}'`, fichaID),
	}
	if estado, ok := out["estado_actual"].(map[string]interface{}); ok {
		if estado["state"] == string(state.StateInstalada) && estado["health"] == "OK" {
			rec["accion"] = "ninguna"
			rec["rpc_ejecutar"] = ""
			rec["motivo"] = "la ficha está INSTALADA y saludable — reparar no aporta"
		}
	}
	return rec
}
