package server

// query_sources.go — Fuentes compartidas entre sagas bos.query.* (M-13, F6).

import (
	"context"
	"errors"
	"fmt"
	"time"

	bosctx "bos/internal/context"
	"bos/internal/query"
	"bos/internal/state"
)

// ── Fuentes compartidas entre sagas ───────────────────────────────────────

// fichasResumenSource agrega el estado de las fichas desde el STATE_MANAGER
// (Thread "fichas" de BOS-REPAIR-04).
func (s *Server) fichasResumenSource() query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible (modo config-pending)")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		return buildFichasResumen(st), nil
	}
}

// certificacionSource ejecuta la verificación C-01..C-08 del bootstrap.
func (s *Server) certificacionSource() query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.bootstrapSvc == nil {
			return nil, errors.New("bootstrap service no disponible")
		}
		return s.bootstrapSvc.Verify()
	}
}

// contextPlaneSource resume las sesiones activas de un tenant.
func (s *Server) contextPlaneSource(tenantID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.bosCtxSvc == nil {
			return nil, errors.New("context plane no disponible")
		}
		sessions, err := s.bosCtxSvc.ListByTenant(tenantID)
		if err != nil {
			return nil, err
		}
		activos := 0
		for _, sc := range sessions {
			if sc.State == bosctx.StateActivo && !sc.IsExpired() {
				activos++
			}
		}
		return map[string]interface{}{
			"healthy":     true,
			"tenant_id":   tenantID,
			"ctx_activos": activos,
			"ctx_total":   len(sessions),
		}, nil
	}
}

// buildFichasResumen produce el resumen de fichas del contrato BOS-REPAIR-04.
// Función pura — testeable sin daemon ni cluster.
func buildFichasResumen(st *state.SBOSState) map[string]interface{} {
	resumen := map[string]interface{}{}
	instalada, degradada, pendiente, errorN := 0, 0, 0, 0
	detalles := make([]map[string]interface{}, 0, len(st.Fichas))
	for _, f := range st.Fichas {
		switch f.State {
		case state.StateInstalada:
			instalada++
		case state.StateDegradada:
			degradada++
		case state.StatePendiente, state.StateLista:
			pendiente++
		case state.StateErrorFisico, state.StateErrorLogico, state.StateErrorNoCorregible:
			errorN++
		}
		detalles = append(detalles, map[string]interface{}{
			"id":      f.Name,
			"state":   string(f.State),
			"health":  f.HealthStatus,
			"version": f.Version,
		})
	}
	resumen["total"] = len(st.Fichas)
	resumen["instalada"] = instalada
	resumen["degradada"] = degradada
	resumen["pendiente"] = pendiente
	// "en_error" y no "error": esa clave es el contrato de fuente caída del
	// motor de sagas (hallazgo de staging real — colisión teñía el semáforo)
	resumen["en_error"] = errorN
	resumen["detalles"] = detalles
	resumen["healthy"] = degradada == 0 && errorN == 0
	return resumen
}

// ttlRestante retorna los segundos de vida restantes de una sesión (≥ 0).
func ttlRestante(sc *bosctx.SessionContext) int64 {
	rest := int64(time.Until(sc.ExpiresAt).Seconds())
	if rest < 0 {
		return 0
	}
	return rest
}

// fichaEstadoVista construye la vista corta de una ficha para sagas VDI/repair.
func fichaEstadoVista(st *state.SBOSState, fichaID string) map[string]interface{} {
	f, ok := st.Fichas[fichaID]
	if !ok {
		return map[string]interface{}{
			"healthy": false,
			"error":   fmt.Sprintf("ficha %s no registrada", fichaID),
		}
	}
	return map[string]interface{}{
		"healthy": f.State == state.StateInstalada && f.HealthStatus == "OK",
		"state":   string(f.State),
		"health":  f.HealthStatus,
		"version": f.Version,
	}
}
