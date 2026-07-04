// Package server — Handlers JSON-RPC 2.0 para bos.ficha.* (F11).
//
// Adaptadores delgados sobre domain.FichaService según ORQUESTA-043 §2:
// cada handler solo parsea parámetros y adapta errores. La lógica de
// negocio vive en domain.FichaService.
//
// Métodos expuestos:
//   bos.ficha.install   — instalar una ficha
//   bos.ficha.update    — actualizar una ficha
//   bos.ficha.repair    — reparar una ficha degradada
//   bos.ficha.remove    — eliminar una ficha
//   bos.ficha.status    — consultar estado de una o todas las fichas
//   bos.ficha.probe     — dry-run de instalación
//   bos.ficha.list      — listar todas las fichas registradas
//   bos.ficha.describe  — describir manifiesto completo con políticas
//   bos.ficha.plan      — orden topológico de instalación
//   bos.ficha.diff      — detectar drift declarado vs real
//   bos.ficha.validate  — validar manifest.yml contra reglas SOV/SAN-10
//   bos.ficha.scale     — escalar réplicas K8s
//   bos.ficha.pause     — pausar ficha para mantenimiento
//   bos.ficha.resume    — reanudar ficha pausada
//   bos.ficha.rescan    — re-descubrir fichas en servers/
//   bos.ficha.logs      — leer últimas N líneas del log
//
// Las variables en "env" se inyectan en el entorno del proceso antes de ejecutar
// la saga, y se restauran al finalizar. El Orchestrator serializa con mutex.
package server

import (
	"bos/internal/state"
	"time"
)

// ── Tipos ───────────────────────────────────────────────────────────────

// fichaPublica es la vista RPC de una state.Ficha SIN los hashes SHA-256
// internos de reconciliación (F6.4). Exponer los hashes por RPC filtraría
// información que permite fingerprinting exacto de recursos instalados.
type fichaPublica struct {
	Name         string           `json:"name"`
	Version      string           `json:"version"`
	State        state.FichaState `json:"state"`
	Server       string           `json:"server"`
	Category     int              `json:"category"`
	Criticality  bool             `json:"criticality"`
	InstalledAt  time.Time        `json:"installed_at"`
	UpdatedAt    time.Time        `json:"updated_at"`
	HealthStatus string           `json:"health_status"`
	Backend      string           `json:"backend"`
}

// ── bos.ficha.install ──────────────────────────────────────────────────

// rpcFichaInstall — método: bos.ficha.install
//
// Params: {"ficha_id": string, "version": string (opcional), "env": {string: string} (opcional)}
// Returns: {"ficha_id", "version", "duration", "steps"}
// Errores: ErrInvalidParams, ErrFichaNotFound, ErrSagaFailed, ErrInternal.
func (s *Server) rpcFichaInstall(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string            `json:"ficha_id"`
		Version string            `json:"version"`
		Env     map[string]string `json:"env"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}

	prevVals := injectEnv(p.Env)
	defer restoreEnv(prevVals, p.Env)

	result, err := s.fichaSvc.Install(p.FichaID, p.Version)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": result.FichaID,
		"version":  p.Version,
		"duration": result.Duration.String(),
		"steps":    result.StepCount,
	})
}

// ── bos.ficha.update ───────────────────────────────────────────────────

// rpcFichaUpdate — método: bos.ficha.update
//
// Params: {"ficha_id": string, "version": string (opcional), "env": {string: string} (opcional)}
// Returns: {"ficha_id", "version", "duration"}
func (s *Server) rpcFichaUpdate(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string            `json:"ficha_id"`
		Version string            `json:"version"`
		Env     map[string]string `json:"env"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}

	prevVals := injectEnv(p.Env)
	defer restoreEnv(prevVals, p.Env)

	result, err := s.fichaSvc.Update(p.FichaID, p.Version)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": result.FichaID,
		"version":  p.Version,
		"duration": result.Duration.String(),
	})
}

// ── bos.ficha.repair ───────────────────────────────────────────────────

// rpcFichaRepair — método: bos.ficha.repair
//
// Params: {"ficha_id": string, "env": {string: string} (opcional)}
// Returns: {"ficha_id", "success", "duration"}
func (s *Server) rpcFichaRepair(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string            `json:"ficha_id"`
		Env     map[string]string `json:"env"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}

	prevVals := injectEnv(p.Env)
	defer restoreEnv(prevVals, p.Env)

	result, err := s.fichaSvc.Repair(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": result.FichaID,
		"success":  result.Success,
		"duration": result.Duration.String(),
	})
}

// ── bos.ficha.remove ───────────────────────────────────────────────────

// rpcFichaRemove — método: bos.ficha.remove
//
// Params: {"ficha_id": string, "env": {string: string} (opcional)}
// Returns: {"ficha_id", "success", "duration"}
func (s *Server) rpcFichaRemove(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string            `json:"ficha_id"`
		Env     map[string]string `json:"env"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}

	prevVals := injectEnv(p.Env)
	defer restoreEnv(prevVals, p.Env)

	result, err := s.fichaSvc.Remove(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": result.FichaID,
		"success":  result.Success,
		"duration": result.Duration.String(),
	})
}

// ── bos.ficha.status ───────────────────────────────────────────────────

// rpcFichaStatus — método: bos.ficha.status
//
// Params: {"ficha_id": string (opcional — vacío retorna todas)}
// Returns: FichaInfo | []FichaInfo
func (s *Server) rpcFichaStatus(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	single, all, err := s.fichaSvc.Status(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	if single != nil {
		return rpcOK(req.ID, single)
	}
	return rpcOK(req.ID, all)
}

// ── bos.ficha.probe ────────────────────────────────────────────────────

// rpcFichaProbe — método: bos.ficha.probe
//
// Params: {"ficha_id": string}
// Returns: {"ficha_id", "ok", "steps", "failed_steps"}
func (s *Server) rpcFichaProbe(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	result, err := s.fichaSvc.Probe(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id":     result.FichaID,
		"ok":           result.Success,
		"steps":        result.StepCount,
		"failed_steps": result.FailedSteps,
	})
}

// ── bos.ficha.list ─────────────────────────────────────────────────────

// rpcFichaList — método: bos.ficha.list
//
// Params: ninguno
// Returns: {"fichas": []FichaInfo, "total": int}
func (s *Server) rpcFichaList(_ *RPCRequest) RPCResponse {
	list := s.fichaSvc.List()
	return rpcOK(nil, map[string]interface{}{"fichas": list, "total": len(list)})
}

// ── bos.ficha.describe ─────────────────────────────────────────────────

// rpcFichaDescribe — método: bos.ficha.describe (F9.1)
//
// Params: {"ficha_id": string}
// Returns: manifest completo con las políticas del Operator Soberano:
// {"id","version","server","dependencies","scaling","maintenance","slos"}.
func (s *Server) rpcFichaDescribe(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.FichaID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ficha_id requerido"))
	}
	if s.plugins == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "catálogo de fichas no disponible"))
	}
	mf, ok := s.plugins.Get(p.FichaID)
	if !ok {
		return rpcFail(req.ID, rpcError(ErrFichaNotFound, "ficha no registrada: "+p.FichaID))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"id":              mf.ID,
		"version":         mf.Version,
		"server":          mf.Server,
		"category":        mf.Category,
		"criticality":     mf.Criticality,
		"auto_install":    mf.AutoInstall,
		"execution_order": mf.ExecutionOrder,
		"dependencies":    mf.Dependencies,
		"backend":         mf.Backend,
		"scaling":         mf.Scaling,
		"maintenance":     mf.Maintenance,
		"slos":            mf.SLOs,
	})
}
