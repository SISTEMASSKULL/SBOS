// Package server — Handlers JSON-RPC 2.0 para bos.ctx.*, bos.state.* y bos.health.*.
//
// Context Plane (SBOS-049):
//   bos.ctx.auto_migrate      — ejecutar DDL del Context Plane
//   bos.ctx.create            — crear un ctx_id con traceparent W3C
//   bos.ctx.validate          — validar un ctx_id activo
//   bos.ctx.device.register   — registrar dispositivo (F5)
//   bos.ctx.promote           — promover device → session (F5)
//   bos.ctx.switch            — cambiar contexto activo (F5)
//   bos.ctx.invalidate        — invalidar contexto (F5)
//   bos.ctx.get               — obtener contexto por ID (F5)
//   bos.ctx.list              — listar contextos por tenant (F5)
//   bos.ctx.tenant.suspend    — suspender todos los contextos de un tenant (F5)
//
// Estado y Health:
//   bos.state.read  — leer .sbos_state.json completo (sin hashes, F6.4)
//   bos.health.check — health check de una ficha o resumen global
//
// Mapeo de errores de dominio a códigos JSON-RPC 2.0 (domainErrToRPC).
package server

import (
	"context"
	"time"

	"bos/internal/domain"
	"bos/internal/state"
)

// ── bos.ctx.auto_migrate ────────────────────────────────────────────────

// rpcCtxAutoMigrate — método: bos.ctx.auto_migrate
//
// Params: {"tenant_id": string, "tables": [string], "indexes": [string]}
// Returns: {"ok": true}
// Verifica que las tablas del Context Plane existen en bos schema (sbos_db).
func (s *Server) rpcCtxAutoMigrate(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string   `json:"tenant_id"`
		Tables   []string `json:"tables"`
		Indexes  []string `json:"indexes"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}

	if err := s.AutoMigrateContextPlane(context.Background()); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{"ok": true})
}

// ── bos.ctx.create ──────────────────────────────────────────────────────

// rpcCtxCreate — método: bos.ctx.create
//
// Params: {"tenant_id": string (requerido), "empresa_id", "sucursal_id", "pos_logico", "user_id", "ttl_seconds": int}
// Returns: {"ctx_id": CtxID, "traceparent": string, "expires_at": time.Time}
// Errores: ErrInvalidParams si tenant_id vacío.
// Estándares: SBOS-049, W3C Trace Context spec.
func (s *Server) rpcCtxCreate(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID   string `json:"tenant_id"`
		EmpresaID  string `json:"empresa_id"`
		SucursalID string `json:"sucursal_id"`
		PosLogico  string `json:"pos_logico"`
		UserID     string `json:"user_id"`
		TTLSeconds int    `json:"ttl_seconds"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	result, err := s.bosCtxSvc.Create(domain.CreateParams{
		TenantID:   p.TenantID,
		EmpresaID:  p.EmpresaID,
		SucursalID: p.SucursalID,
		PosLogico:  p.PosLogico,
		UserID:     p.UserID,
		TTL:        time.Duration(p.TTLSeconds) * time.Second,
	})
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	s.logger.Info("ctx_id creado", "tenant", p.TenantID, "trace", result.TraceParent)
	return rpcOK(req.ID, map[string]interface{}{
		"ctx_id":      result,
		"traceparent": result.TraceParent,
		"expires_at":  result.ExpiresAt,
	})
}

// ── bos.ctx.validate ────────────────────────────────────────────────────

// rpcCtxValidate — método: bos.ctx.validate
//
// Params: {"traceparent": string (requerido), "tenant_id": string (opcional)}
// Returns: ValidateResult con {"valid": bool, "traceparent", "tenant_id"}
func (s *Server) rpcCtxValidate(req *RPCRequest) RPCResponse {
	var p struct {
		TraceParent string `json:"traceparent"`
		TenantID    string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	result, err := s.bosCtxSvc.Validate(p.TraceParent, p.TenantID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── bos.state.read ──────────────────────────────────────────────────────

// rpcStateRead — método: bos.state.read
//
// Params: ninguno
// Returns: {"version", "hostname", "cluster_name", "updated_at", "fichas_total", "fichas": map}
// Las fichas se exponen como fichaPublica — sin hashes internos de reconciliación (F6.4).
func (s *Server) rpcStateRead(req *RPCRequest) RPCResponse {
	st, err := s.stateMgr.Read()
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	fichas := make(map[string]fichaPublica, len(st.Fichas))
	for name, f := range st.Fichas {
		fichas[name] = fichaPublica{
			Name:         f.Name,
			Version:      f.Version,
			State:        f.State,
			Server:       f.Server,
			Category:     f.Category,
			Criticality:  f.Criticality,
			InstalledAt:  f.InstalledAt,
			UpdatedAt:    f.UpdatedAt,
			HealthStatus: f.HealthStatus,
			Backend:      f.Backend,
		}
	}
	return rpcOK(req.ID, map[string]interface{}{
		"version":      st.Version,
		"hostname":     st.Hostname,
		"cluster_name": st.ClusterName,
		"updated_at":   st.UpdatedAt,
		"fichas_total": len(fichas),
		"fichas":       fichas,
	})
}

// ── bos.health.check ────────────────────────────────────────────────────

// rpcHealthCheck — método: bos.health.check
//
// Params: {"ficha_id": string (opcional — vacío = chequeo global)}
// Returns individual: {"ficha_id", "state", "health", "healthy"}
// Returns global: {"healthy", "fichas_ok", "fichas_alerta", "fichas_total", "timestamp"}
func (s *Server) rpcHealthCheck(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	_ = parseParams(req.Params, &p)

	single, all, err := s.fichaSvc.Status(p.FichaID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}

	if single != nil {
		return rpcOK(req.ID, map[string]interface{}{
			"ficha_id": p.FichaID,
			"state":    single.State,
			"health":   single.Health,
			"healthy":  single.State == string(state.StateInstalada),
		})
	}

	ok, alerta, total := 0, 0, len(all)
	for _, f := range all {
		switch f.State {
		case string(state.StateInstalada):
			ok++
		case string(state.StateDegradada):
			alerta++
		}
	}
	return rpcOK(req.ID, map[string]interface{}{
		"healthy":       alerta == 0 && ok == total,
		"fichas_ok":     ok,
		"fichas_alerta": alerta,
		"fichas_total":  total,
		"timestamp":     time.Now(),
	})
}
