// Package server — ctx_handlers.go: handlers JSON-RPC del Context Plane completo.
// F5.4 — BOS-REPAIR Plan Maestro v3.
// 7 métodos: device.register, promote, switch, invalidate, get, list, tenant.suspend.
package server

import (
	"fmt"
	"time"

	"bos/internal/audit"
	bosctx "bos/internal/context"
	"bos/internal/paths"
)

// ── bos.ctx.device.register ───────────────────────────────────────────────

// rpcCtxDeviceRegister registra un nuevo DeviceContext (fase pre-autenticación).
//
// Params: {"hostname": string, "tenant_id": string, "node_k8s": string, "ip": string}
// Returns: {dctx_id, hostname, tenant_id, state, expires_at}
// SLO C-13: tiempo de respuesta < 2s
func (s *Server) rpcCtxDeviceRegister(req *RPCRequest) RPCResponse {
	var p struct {
		Hostname string `json:"hostname"`
		TenantID string `json:"tenant_id"`
		NodeK8s  string `json:"node_k8s"`
		IP       string `json:"ip"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	dctx, err := s.bosCtxSvc.RegisterDevice(p.Hostname, p.TenantID, p.NodeK8s, p.IP)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Info("DeviceContext registrado", "dctx_id", dctx.DctxID, "tenant", p.TenantID,
		"traceparent", tp)
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"dctx_id":    dctx.DctxID,
		"hostname":   dctx.Hostname,
		"tenant_id":  dctx.TenantID,
		"state":      dctx.State.String(),
		"expires_at": dctx.ExpiresAt,
	}, tp))
}

// ── bos.ctx.promote ──────────────────────────────────────────────────────

// rpcCtxPromote promueve un DeviceContext a SessionContext (evento context.promoted).
// El BitMask > 0 es calculado por bAuth y pasado como parámetro.
//
// Params: {"dctx_id", "empresa_id", "sucursal_id", "pos_logico", "user_id",
//
//	"bitmask": uint64, "loa": int, "traceparent": string}
//
// Returns: {ctx_id, dctx_id, user_id, bitmask, loa, state, traceparent, expires_at}
func (s *Server) rpcCtxPromote(req *RPCRequest) RPCResponse {
	var p struct {
		DctxID      string `json:"dctx_id"`
		EmpresaID   string `json:"empresa_id"`
		SucursalID  string `json:"sucursal_id"`
		PosLogico   string `json:"pos_logico"`
		UserID      string `json:"user_id"`
		BitMask     uint64 `json:"bitmask"`
		LoA         int    `json:"loa"`
		Traceparent string `json:"traceparent"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	sctx, err := s.bosCtxSvc.Promote(
		p.DctxID, p.EmpresaID, p.SucursalID, p.PosLogico, p.UserID,
		bosctx.BitMask(p.BitMask), p.LoA, p.Traceparent,
	)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Info("ctx_id promovido", "ctx_id", sctx.CtxID, "user", p.UserID,
		"traceparent", sctx.Traceparent)
	audit.Log(paths.AuditLog, "CONTEXT",
		"action=promote", "ctx_id="+sctx.CtxID, "user="+sctx.UserID,
		"tenant="+sctx.TenantID, "result=ok")
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"ctx_id":      sctx.CtxID,
		"dctx_id":     sctx.DctxID,
		"user_id":     sctx.UserID,
		"bitmask":     uint64(sctx.BitMask),
		"loa":         sctx.LoA,
		"state":       sctx.State.String(),
		"traceparent": sctx.Traceparent, // traceparent del contexto de sesión
		"expires_at":  sctx.ExpiresAt,
	}, tp))
}

// ── bos.ctx.switch ────────────────────────────────────────────────────────

// rpcCtxSwitch crea una nueva sesión reemplazando la anterior (cambio de empresa/sucursal).
//
// Params: {"ctx_id", "empresa_id", "sucursal_id", "pos_logico", "traceparent"}
// Returns: nuevo SessionContext {ctx_id, dctx_id, empresa_id, state}
func (s *Server) rpcCtxSwitch(req *RPCRequest) RPCResponse {
	var p struct {
		CtxID       string `json:"ctx_id"`
		EmpresaID   string `json:"empresa_id"`
		SucursalID  string `json:"sucursal_id"`
		PosLogico   string `json:"pos_logico"`
		Traceparent string `json:"traceparent"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	// F6.5 — validar TTL de la sesión previa antes de conmutar:
	// un ctx expirado no puede originar una nueva sesión (ISO 27001 A.9.4.2).
	if prev, err := s.bosCtxSvc.Get(p.CtxID); err == nil && prev.IsExpired() {
		return rpcFail(req.ID, rpcError(ErrContextExpired,
			fmt.Sprintf("ContextExpired: %s expiró en %s", p.CtxID, prev.ExpiresAt.Format(time.RFC3339))))
	}
	sctx, err := s.bosCtxSvc.Switch(p.CtxID, p.EmpresaID, p.SucursalID, p.PosLogico, p.Traceparent)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Info("ctx_id switched", "nuevo", sctx.CtxID, "anterior", p.CtxID,
		"traceparent", tp)
	audit.Log(paths.AuditLog, "CONTEXT",
		"action=switch", "ctx_id="+sctx.CtxID, "prev_ctx_id="+p.CtxID,
		"tenant="+sctx.TenantID, "result=ok")
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"ctx_id":      sctx.CtxID,
		"dctx_id":     sctx.DctxID,
		"empresa_id":  sctx.EmpresaID,
		"sucursal_id": sctx.SucursalID,
		"state":       sctx.State.String(),
		"expires_at":  sctx.ExpiresAt,
	}, tp))
}

// ── bos.ctx.invalidate ────────────────────────────────────────────────────

// rpcCtxInvalidate invalida un ctx_id activo (logout, revocación).
// Es idempotente: si ya está invalidado retorna OK.
//
// Params: {"ctx_id": string}
// Returns: {"ctx_id", "invalidated": true}
func (s *Server) rpcCtxInvalidate(req *RPCRequest) RPCResponse {
	var p struct {
		CtxID string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.CtxID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ctx_id requerido"))
	}
	if err := s.bosCtxSvc.Invalidate(p.CtxID); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Info("ctx_id invalidado", "ctx_id", p.CtxID, "traceparent", tp)
	audit.Log(paths.AuditLog, "CONTEXT",
		"action=invalidate", "ctx_id="+p.CtxID, "result=ok")
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"ctx_id":      p.CtxID,
		"invalidated": true,
	}, tp))
}

// ── bos.ctx.get ────────────────────────────────────────────────────────────

// rpcCtxGet recupera los campos completos de un ctx_id activo.
// Usado por Kong plugin SBOS-Context para lookup O(1).
//
// Params: {"ctx_id": string}
// Returns: SessionContext completo
func (s *Server) rpcCtxGet(req *RPCRequest) RPCResponse {
	var p struct {
		CtxID string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	sctx, err := s.bosCtxSvc.Get(p.CtxID)
	if err != nil {
		// NRS-07: respuesta idéntica para "no encontrado" y "expirado" — anti-enumeration.
		// Kong y biedata solo necesitan saber "no válido"; nunca distinguir entre los dos casos.
		if s.metrics != nil {
			s.metrics.Counter("bos_ctx_validate_fail_total").Inc()
		}
		return rpcFail(req.ID, rpcError(ErrContextExpired, "ctx_id no válido o expirado"))
	}
	// F6.5 — TTL agotado → -32001: misma respuesta que "no encontrado" (NRS-07).
	if sctx.IsExpired() {
		if s.metrics != nil {
			s.metrics.Counter("bos_ctx_validate_fail_total").Inc()
		}
		return rpcFail(req.ID, rpcError(ErrContextExpired, "ctx_id no válido o expirado"))
	}
	// NRS-09: contabilizar validaciones exitosas
	if s.metrics != nil {
		s.metrics.Counter("bos_ctx_validate_ok_total").Inc()
	}
	tp := ExtractTraceparent(req)
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"ctx_id":      sctx.CtxID,
		"dctx_id":     sctx.DctxID,
		"tenant_id":   sctx.TenantID,
		"empresa_id":  sctx.EmpresaID,
		"sucursal_id": sctx.SucursalID,
		"pos_logico":  sctx.PosLogico,
		"user_id":     sctx.UserID,
		"bitmask":     uint64(sctx.BitMask),
		"loa":         sctx.LoA,
		"state":       sctx.State.String(),
		"traceparent": sctx.Traceparent, // traceparent de la sesión (inmutable)
		"expires_at":  sctx.ExpiresAt,
		"expired":     false, // F6.5: una sesión expirada responde -32001, nunca llega aquí
	}, tp))
}

// ── bos.ctx.list ───────────────────────────────────────────────────────────

// rpcCtxList lista todos los ctx_id activos de un tenant.
// Usado por bosctl ctx list y dashboards de observabilidad.
//
// Params: {"tenant_id": string}
// Returns: {"sessions": [...], "total": int}
func (s *Server) rpcCtxList(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	sessions, err := s.bosCtxSvc.ListByTenant(p.TenantID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	out := make([]map[string]interface{}, 0, len(sessions))
	for _, sc := range sessions {
		out = append(out, map[string]interface{}{
			"ctx_id":      sc.CtxID,
			"user_id":     sc.UserID,
			"empresa_id":  sc.EmpresaID,
			"sucursal_id": sc.SucursalID,
			"loa":         sc.LoA,
			"state":       sc.State.String(),
			"expires_at":  sc.ExpiresAt,
		})
	}
	return rpcOK(req.ID, map[string]interface{}{
		"sessions": out,
		"total":    len(out),
	})
}

// ── bos.ctx.tenant.suspend ────────────────────────────────────────────────

// rpcCtxTenantSuspend invalida masivamente todos los ctx_id activos de un tenant.
// Usado en bosctl tenant suspend/remove (SBOS-049 §5.1, ISO 27001 A.9.2.6).
//
// Params: {"tenant_id": string}
// Returns: {"tenant_id", "invalidated": int}
func (s *Server) rpcCtxTenantSuspend(req *RPCRequest) RPCResponse {
	var p struct {
		TenantID string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	count, err := s.bosCtxSvc.InvalidateAllByTenant(p.TenantID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Info("tenant suspendido — ctx_ids invalidados", "tenant", p.TenantID,
		"count", count, "traceparent", tp)
	audit.Log(paths.AuditLog, "CONTEXT",
		"action=tenant.suspend", "tenant="+p.TenantID,
		fmt.Sprintf("invalidated=%d", count), "result=ok")
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"tenant_id":   p.TenantID,
		"invalidated": count,
	}, tp))
}

// ── bos.ctx.heartbeat ────────────────────────────────────────────────────

// rpcCtxHeartbeat prolonga el TTL de un ctx_id activo (SBOS-049 §3.3).
// Idempotente: múltiples heartbeats sucesivos extienden el TTL desde el momento actual.
//
// Params: {"ctx_id": string}
// Returns: {"ctx_id", "expires_at", "extended": true}
func (s *Server) rpcCtxHeartbeat(req *RPCRequest) RPCResponse {
	var p struct {
		CtxID string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.CtxID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ctx_id requerido"))
	}
	sctx, err := s.bosCtxSvc.Heartbeat(p.CtxID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrContextExpired, err.Error()))
	}
	tp := ExtractTraceparent(req)
	s.logger.Debug("ctx_id heartbeat", "ctx_id", p.CtxID, "new_expiry", sctx.ExpiresAt)
	return rpcOK(req.ID, InjectTraceparent(map[string]interface{}{
		"ctx_id":     sctx.CtxID,
		"expires_at": sctx.ExpiresAt,
		"extended":   true,
	}, tp))
}
