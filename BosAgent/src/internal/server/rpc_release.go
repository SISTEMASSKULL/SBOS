// Package server — Handlers JSON-RPC 2.0 para bos.release.*.
//
// SKULL Release Plane (ADR-019, ADR-044):
// Conexión pull-only con el Release Server de SKULL. El daemon BOS consulta
// periódicamente si hay actualizaciones disponibles para las fichas registradas,
// verificando firma Ed25519 + SHA-256 en cada release.
//
// Métodos:
//   bos.release.check — verificar disponibilidad de actualizaciones para una ficha
//   bos.release.list  — listar todas las releases conocidas
//
// Canales: canary → early → stable. El ReleaseChecker define la estrategia.
package server

// ── bos.release.check ───────────────────────────────────────────────────

// rpcReleaseCheck verifica si hay actualizaciones disponibles para una ficha
// en el SKULL Release Plane. Si releaseMgr no está disponible (offline),
// retorna success con offline:true en lugar de error.
//
// Params: {"ficha": string, "version": string}
//   - ficha vacío = "*" (todas las fichas)
//   - version vacío = "0.0.0" (cualquier versión superior)
func (s *Server) rpcReleaseCheck(req *RPCRequest) RPCResponse {
	if s.releaseMgr == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "release manager not available"))
	}
	var p struct {
		Ficha   string `json:"ficha"`
		Version string `json:"version"`
	}
	_ = parseParams(req.Params, &p)
	if p.Ficha == "" {
		p.Ficha = "*"
	}
	if p.Version == "" {
		p.Version = "0.0.0"
	}

	releases, err := s.releaseMgr.CheckAvailable(p.Ficha, p.Version)
	if err != nil {
		return rpcOK(req.ID, map[string]interface{}{
			"updates": []interface{}{},
			"offline": true,
			"error":   err.Error(),
		})
	}
	return rpcOK(req.ID, map[string]interface{}{
		"updates": releases,
		"count":   len(releases),
		"offline": false,
	})
}

// ── bos.release.list ────────────────────────────────────────────────────

// rpcReleaseList retorna el catálogo completo de releases conocidas
// por el Release Manager local (cache del Release Plane).
func (s *Server) rpcReleaseList(req *RPCRequest) RPCResponse {
	if s.releaseMgr == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "release manager not available"))
	}
	releases, err := s.releaseMgr.ListAll()
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"releases": releases,
		"count":    len(releases),
	})
}
