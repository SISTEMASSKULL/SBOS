// Package server — Handlers JSON-RPC 2.0 para bos.ficha.* — F11 (Ficha Engine v2).
//
// Métodos añadidos en la iteración F11 del Plan Maestro BOS-REPAIR v3:
//   bos.ficha.plan     — orden topológico de instalación (oleadas paralelizables)
//   bos.ficha.diff     — detección de drift declarado vs real
//   bos.ficha.validate — validación de manifest.yml contra reglas SOV y SAN-10
//   bos.ficha.scale    — escalar réplicas K8s
//   bos.ficha.pause    — pausar ficha para mantenimiento (sin alertas)
//   bos.ficha.resume   — reanudar ficha previamente pausada
//   bos.ficha.rescan   — re-descubrir fichas en servers/
//   bos.ficha.logs     — leer últimas N líneas del log
//
// Estos métodos usan directamente FichaService, siguiendo el patrón de
// adaptadores delgados de ORQUESTA-043 §2.
package server

// ── bos.ficha.plan ──────────────────────────────────────────────────────

// rpcFichaPlan — método: bos.ficha.plan
// Retorna el orden topológico de instalación con oleadas paralelizables.
// Cada oleada contiene fichas sin dependencias entre sí que pueden instalarse en paralelo.
func (s *Server) rpcFichaPlan(req *RPCRequest) RPCResponse {
	result, err := s.fichaSvc.Plan()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"order":      result.Order,
		"waves":      result.Waves,
		"total":      result.Total,
		"has_cycles": result.HasCycles,
	})
}

// ── bos.ficha.diff ──────────────────────────────────────────────────────

// rpcFichaDiff — método: bos.ficha.diff
// Detecta drift entre el estado declarado en manifest.yml y el estado real del sistema.
// Si ficha_id está vacío, retorna un resumen de todas las fichas.
func (s *Server) rpcFichaDiff(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	_ = parseParams(req.Params, &p)

	single, summary, err := s.fichaSvc.Diff(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	if single != nil {
		return rpcOK(req.ID, map[string]interface{}{
			"ficha_id":  single.FichaID,
			"has_drift": single.HasDrift,
			"items":     single.Items,
		})
	}
	return rpcOK(req.ID, map[string]interface{}{
		"total_fichas":   summary.TotalFichas,
		"drifted_fichas": summary.DriftedFichas,
		"ok_fichas":      summary.OkFichas,
	})
}

// ── bos.ficha.validate ──────────────────────────────────────────────────

// rpcFichaValidate — método: bos.ficha.validate
// Valida el manifest.yml de una ficha (o todas) contra reglas de sintaxis (SOV)
// y semántica (SAN-10). Retorna lista de resultados con errores y advertencias.
func (s *Server) rpcFichaValidate(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	_ = parseParams(req.Params, &p)

	results, err := s.fichaSvc.Validate(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"results":      results,
		"total_fichas": len(results),
	})
}

// ── bos.ficha.scale ─────────────────────────────────────────────────────

// rpcFichaScale — método: bos.ficha.scale
// Escala una ficha K8s al número de réplicas especificado.
// Requiere K8sPort funcional — actualmente retorna ErrInternal hasta que F9 esté completo.
func (s *Server) rpcFichaScale(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID  string `json:"ficha_id"`
		Replicas int32  `json:"replicas"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	return rpcFail(req.ID, rpcError(ErrInternal, "bos.ficha.scale: acceso K8s no disponible (F9 pendiente)"))
}

// ── bos.ficha.pause ─────────────────────────────────────────────────────

// rpcFichaPause — método: bos.ficha.pause
// Pausa una ficha para mantenimiento (estado 17 PAUSADA). No genera alertas
// ni ejecuta reconciliación mientras está pausada.
func (s *Server) rpcFichaPause(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	outcome, err := s.fichaSvc.Pause(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": outcome.FichaID,
		"success":  outcome.Success,
	})
}

// ── bos.ficha.resume ────────────────────────────────────────────────────

// rpcFichaResume — método: bos.ficha.resume
// Reanuda una ficha previamente pausada, restaurando health checks y reconciliación.
func (s *Server) rpcFichaResume(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	outcome, err := s.fichaSvc.Resume(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": outcome.FichaID,
		"success":  outcome.Success,
	})
}

// ── bos.ficha.rescan ────────────────────────────────────────────────────

// rpcFichaRescan — método: bos.ficha.rescan
// Hace dos cosas:
//  1. Recarga el catálogo desde servers/ (fichas nuevas/modificadas sin reiniciar)
//  2. Dispara K8sDiscovery bajo demanda para que bos.ficha.list muestre estado real
//     sin esperar el próximo ciclo de reconciliación (300s).
func (s *Server) rpcFichaRescan(req *RPCRequest) RPCResponse {
	result, err := s.fichaSvc.Rescan()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}

	k8sProbed, k8sSkipped, k8sErrors := 0, 0, 0
	if s.k8sScanner != nil {
		k8sProbed, k8sSkipped, k8sErrors = s.k8sScanner.Scan()
	}

	return rpcOK(req.ID, map[string]interface{}{
		"discovered":  result.Discovered,
		"total":       result.Total,
		"added":       result.Added,
		"k8s_probed":  k8sProbed,
		"k8s_skipped": k8sSkipped,
		"k8s_errors":  k8sErrors,
	})
}

// ── bos.ficha.logs ──────────────────────────────────────────────────────

// rpcFichaLogs — método: bos.ficha.logs
// Retorna las últimas N líneas del log de una ficha desde /var/log/bos/fichas/.
// El streaming en tiempo real se maneja vía WebSocket o gRPC Watch.
func (s *Server) rpcFichaLogs(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID   string `json:"ficha_id"`
		TailLines int32  `json:"tail_lines"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.FichaID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ficha_id requerido"))
	}
	if p.TailLines == 0 {
		p.TailLines = 50
	}
	// TODO(F11.F.2): Implementar lectura real de /var/log/bos/fichas/<name>.log
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id":   p.FichaID,
		"tail_lines": p.TailLines,
		"lines":      []string{},
		"note":       "lectura de logs pendiente de implementación (F11.F.2)",
	})
}
