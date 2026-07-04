// Package server — Handlers JSON-RPC 2.0 para bos.bootstrap.pg_auxiliar.*.
//
// PG Auxiliar Anti-Pérdida (Parte V-B del Plan Maestro BOS-REPAIR):
// Sistema de respaldo de PostgreSQL vía WAL shipping. Mantiene una réplica
// auxiliar sincronizada para failover en caso de pérdida del primario.
//
// Métodos:
//   bos.bootstrap.pg_auxiliar_start   — iniciar sincronización con el pod source
//   bos.bootstrap.pg_auxiliar_sync    — disparar sincronización manual
//   bos.bootstrap.pg_auxiliar_status  — consultar estado de la réplica auxiliar
//   bos.bootstrap.pg_auxiliar_cleanup — limpiar artefactos de la réplica auxiliar
package server

// ── bos.bootstrap.pg_auxiliar.start ────────────────────────────────────

// rpcPgAuxiliarStart inicia la sincronización de la réplica auxiliar desde el pod source.
// Si source_pod y source_ns están vacíos, usa defaults: postgresql-0 en sbos-data.
func (s *Server) rpcPgAuxiliarStart(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	var p struct {
		SourcePod string `json:"source_pod"`
		SourceNS  string `json:"source_ns"`
	}
	_ = parseParams(req.Params, &p)
	if p.SourcePod == "" {
		p.SourcePod = "postgresql-0"
	}
	if p.SourceNS == "" {
		p.SourceNS = "sbos-data"
	}

	result, err := s.pgAuxSvc.Start(p.SourcePod, p.SourceNS, nil)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── bos.bootstrap.pg_auxiliar.sync ─────────────────────────────────────

// rpcPgAuxiliarSync dispara una sincronización manual de la réplica auxiliar.
// Sincroniza la base de datos especificada (default: postgres) desde el pod target.
func (s *Server) rpcPgAuxiliarSync(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	var p struct {
		TargetPod string `json:"target_pod"`
		TargetNS  string `json:"target_ns"`
		Database  string `json:"database"`
	}
	_ = parseParams(req.Params, &p)
	if p.TargetPod == "" {
		p.TargetPod = "postgresql-0"
	}
	if p.TargetNS == "" {
		p.TargetNS = "sbos-data"
	}
	if p.Database == "" {
		p.Database = "postgres"
	}

	result, err := s.pgAuxSvc.Sync(p.TargetPod, p.TargetNS, p.Database)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── bos.bootstrap.pg_auxiliar.status ───────────────────────────────────

// rpcPgAuxiliarStatus retorna el estado actual de la réplica auxiliar:
// sincronizada, atrasada, o no inicializada.
func (s *Server) rpcPgAuxiliarStatus(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	return rpcOK(req.ID, s.pgAuxSvc.Status())
}

// ── bos.bootstrap.pg_auxiliar.cleanup ──────────────────────────────────

// rpcPgAuxiliarCleanup elimina los artefactos de la réplica auxiliar
// (PVC temporal, secrets, configs) sin afectar al primario.
func (s *Server) rpcPgAuxiliarCleanup(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	if err := s.pgAuxSvc.Cleanup(); err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]bool{"cleaned": true})
}
