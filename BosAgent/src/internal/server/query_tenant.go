package server

// query_tenant.go — Saga bos.query.tenant (M-13, F6.9).

import (
	"context"
	"errors"

	bosctx "bos/internal/context"
	"bos/internal/query"
)

// ── bos.query.tenant (F6.9) ───────────────────────────────────────────────

// rpcQueryTenant — método: bos.query.tenant
//
// Snapshot completo de un tenant: identidad, infraestructura, contextos.
// Las fuentes keycloak/nextcloud/audit degradan hasta que sus clientes se
// conecten (F9/F10) — el snapshot reporta lo que el bos sabe HOY.
//
// Params: {"tenant_id": string (requerido)}
// Returns: identidad, infraestructura, contexto (todas las sesiones del
// tenant — aislamiento multi-tenant), usuarios, metadatos.
func (s *Server) rpcQueryTenant(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.TenantID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "tenant_id requerido"))
	}

	sources := map[string]query.Source{
		"identidad":       s.tenantIdentidadSource(p.TenantID),
		"infraestructura": s.tenantInfraSource(p.TenantID),
		"contexto":        s.tenantContextoSource(p.TenantID),
		"usuarios": func(_ context.Context) (interface{}, error) {
			return nil, errors.New("cliente Keycloak pendiente (F9) — usuarios no disponibles")
		},
	}

	out := query.Run(context.Background(), sources)
	out["tenant_id"] = p.TenantID
	return rpcOK(req.ID, out)
}

// tenantIdentidadSource reúne la identidad del tenant desde el estado.
func (s *Server) tenantIdentidadSource(tenantID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		identidad := map[string]interface{}{
			"tenant_id": tenantID,
			"namespace": "sbos-" + tenantID,
		}
		if s.stateMgr != nil {
			if st, err := s.stateMgr.Read(); err == nil {
				identidad["hostname"] = st.Hostname
				identidad["cluster"] = st.ClusterName
				identidad["version_sbos"] = st.Version
				for k, v := range st.Meta {
					identidad[k] = v
				}
			}
		}
		return identidad, nil
	}
}

// tenantInfraSource resume la infraestructura que sirve al tenant.
func (s *Server) tenantInfraSource(tenantID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.stateMgr == nil {
			return nil, errors.New("state manager no disponible")
		}
		st, err := s.stateMgr.Read()
		if err != nil {
			return nil, err
		}
		resumen := buildFichasResumen(st)
		return map[string]interface{}{
			"namespace":         "sbos-" + tenantID,
			"fichas_instaladas": resumen["instalada"],
			"fichas_degradadas": resumen["degradada"],
			"fichas_total":      resumen["total"],
			"healthy":           resumen["healthy"],
		}, nil
	}
}

// tenantContextoSource lista TODAS las sesiones del tenant con TTL restante.
// Solo las del tenant — el aislamiento multi-tenant es la invariante.
func (s *Server) tenantContextoSource(tenantID string) query.Source {
	return func(_ context.Context) (interface{}, error) {
		if s.bosCtxSvc == nil {
			return nil, errors.New("context plane no disponible")
		}
		sessions, err := s.bosCtxSvc.ListByTenant(tenantID)
		if err != nil {
			return nil, err
		}
		activos := 0
		detalle := make([]map[string]interface{}, 0, len(sessions))
		for _, sc := range sessions {
			if sc.State == bosctx.StateActivo && !sc.IsExpired() {
				activos++
			}
			detalle = append(detalle, map[string]interface{}{
				"ctx_id":         sc.CtxID,
				"user_id":        sc.UserID,
				"state":          sc.State.String(),
				"ttl_restante_s": ttlRestante(sc),
			})
		}
		return map[string]interface{}{
			"ctx_activos": activos,
			"ctx_total":   len(sessions),
			"sesiones":    detalle,
		}, nil
	}
}

