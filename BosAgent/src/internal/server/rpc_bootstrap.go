// Package server — Handlers JSON-RPC 2.0 para bos.bootstrap.* y bos.saga.*.
//
// Métodos del plano de control:
//   bos.bootstrap.start  — iniciar bootstrap del cluster
//   bos.bootstrap.verify — verificar criterios C-01 a C-13
//   bos.bootstrap.resume — reanudar bootstrap interrumpido
//   bos.bootstrap.status — consultar progreso del bootstrap
//   bos.saga.execute      — ejecutar una saga con compensación
package server

// ── bos.bootstrap.* ─────────────────────────────────────────────────────

// rpcBootstrapStart — método: bos.bootstrap.start
//
// Params: {"mode": "unattended" | "interactive" (opcional)}
// Returns: BootstrapStartResult con estado inicial del proceso.
func (s *Server) rpcBootstrapStart(req *RPCRequest) RPCResponse {
	var p struct {
		Mode string `json:"mode"`
	}
	_ = parseParams(req.Params, &p)
	result, err := s.bootstrapSvc.Start(p.Mode)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// rpcBootstrapVerify — método: bos.bootstrap.verify
//
// Params: ninguno
// Returns: VerifyResult con criterios C-01..C-13 y certified:bool.
func (s *Server) rpcBootstrapVerify(req *RPCRequest) RPCResponse {
	result, err := s.bootstrapSvc.Verify()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// rpcBootstrapResume — método: bos.bootstrap.resume
//
// Params: ninguno
// Returns: {"message", "fichas_completadas", "fichas_total"}.
// Reanuda el observer loop tras una interrupción del bootstrap.
func (s *Server) rpcBootstrapResume(req *RPCRequest) RPCResponse {
	result, err := s.bootstrapSvc.Resume()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"message":            "observer loop reanudado",
		"fichas_completadas": result.Completados,
		"fichas_total":       result.Total,
	})
}

// rpcBootstrapStatus — método: bos.bootstrap.status
//
// Params: ninguno
// Returns: BootstrapStatus con progreso, totales y estados de fichas.
func (s *Server) rpcBootstrapStatus(req *RPCRequest) RPCResponse {
	result, err := s.bootstrapSvc.Status()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── bos.saga.execute ────────────────────────────────────────────────────

// rpcSagaExecute — método: bos.saga.execute
//
// Params: {"ficha_id": string, "command": "install"|"update"|"repair"|"remove", "version": string (opcional)}
// Returns: {"ficha_id", "command", "success", "duration", "steps"}
// Errores: ErrInvalidParams, ErrSagaFailed (con data = pasos fallidos).
func (s *Server) rpcSagaExecute(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
		Command string `json:"command"`
		Version string `json:"version"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	result, err := s.fichaSvc.ExecuteSaga(p.FichaID, p.Command, p.Version)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": result.FichaID,
		"command":  result.Command,
		"success":  result.Success,
		"duration": result.Duration.String(),
		"steps":    result.StepCount,
	})
}
