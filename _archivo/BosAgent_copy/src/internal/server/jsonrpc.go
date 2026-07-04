package server

// JSON-RPC 2.0 sobre Unix socket /run/bos/bos.sock — ADR-019
//
// Ruta: POST /rpc
// Transporte: Unix socket (SBOS-050 P9 — sin TCP entre daemons)
// Clientes: biedata, bkernel, bauth, bsearch, agentes IA
//
// Naming: bos.<modulo>.<operacion>
// Módulos: ficha | bootstrap | saga | state | health | ctx

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"time"

	"bos/internal/domain"
	"bos/internal/state"
)

// ── Tipos JSON-RPC 2.0 ────────────────────────────────────────────

// RPCRequest es el sobre de solicitud JSON-RPC 2.0.
// Soporta llamada individual y batch ([]RPCRequest).
type RPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	ID      interface{}     `json:"id"` // string | number | null
}

// RPCResponse es el sobre de respuesta JSON-RPC 2.0.
type RPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

// RPCError es el objeto de error estándar JSON-RPC 2.0.
type RPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Códigos de error JSON-RPC 2.0 estándar + extensiones SBOS.
const (
	ErrParse          = -32700
	ErrInvalidRequest = -32600
	ErrMethodNotFound = -32601
	ErrInvalidParams  = -32602
	ErrInternal       = -32603

	// Extensiones SBOS (-32000 a -32099)
	ErrFichaNotFound   = -32001
	ErrDepNotSatisfied = -32002
	ErrSagaFailed      = -32003
	ErrStateConflict   = -32004
	ErrGovernanceDeny  = -32005
)

func rpcError(code int, msg string) *RPCError {
	return &RPCError{Code: code, Message: msg}
}

func rpcOK(id interface{}, result interface{}) RPCResponse {
	return RPCResponse{JSONRPC: "2.0", Result: result, ID: id}
}

func rpcFail(id interface{}, err *RPCError) RPCResponse {
	return RPCResponse{JSONRPC: "2.0", Error: err, ID: id}
}

// ── Handler HTTP /rpc ─────────────────────────────────────────────

// handleJSONRPC procesa solicitudes JSON-RPC 2.0 en POST /rpc.
// Soporta llamada individual y batch.
func (s *Server) handleJSONRPC(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "método no permitido — usar POST", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	var raw json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		writeJSON(w, rpcFail(nil, rpcError(ErrParse, "JSON inválido: "+err.Error())))
		return
	}

	// Detectar batch (array) vs llamada individual (object)
	if len(raw) > 0 && raw[0] == '[' {
		var reqs []RPCRequest
		if err := json.Unmarshal(raw, &reqs); err != nil {
			writeJSON(w, rpcFail(nil, rpcError(ErrInvalidRequest, "batch inválido")))
			return
		}
		if len(reqs) == 0 {
			writeJSON(w, rpcFail(nil, rpcError(ErrInvalidRequest, "batch vacío")))
			return
		}
		responses := make([]RPCResponse, 0, len(reqs))
		for _, req := range reqs {
			if resp := s.dispatchRPC(&req); resp != nil {
				responses = append(responses, *resp)
			}
		}
		writeJSON(w, responses)
		return
	}

	var req RPCRequest
	if err := json.Unmarshal(raw, &req); err != nil {
		writeJSON(w, rpcFail(nil, rpcError(ErrInvalidRequest, err.Error())))
		return
	}
	if resp := s.dispatchRPC(&req); resp != nil {
		writeJSON(w, *resp)
	}
}

// RPCHandler es el tipo de función que implementa un método JSON-RPC 2.0.
// ORQUESTA-043 §6 — Registro de Métodos: Open/Closed, extensible sin tocar el dispatcher.
type RPCHandler func(*Server, *RPCRequest) RPCResponse

// rpcRegistry mapea method_name → handler (ORQUESTA-043 §6).
// Se inicializa en init() para evitar ciclo con system.listMethods.
// Para registrar un nuevo método: añadir una línea en init(). El dispatcher no cambia.
var rpcRegistry map[string]RPCHandler

func init() {
	rpcRegistry = map[string]RPCHandler{
		// bos.ficha.*
		"bos.ficha.install": (*Server).rpcFichaInstall,
		"bos.ficha.update":  (*Server).rpcFichaUpdate,
		"bos.ficha.repair":  (*Server).rpcFichaRepair,
		"bos.ficha.remove":  (*Server).rpcFichaRemove,
		"bos.ficha.status":  (*Server).rpcFichaStatus,
		"bos.ficha.probe":   (*Server).rpcFichaProbe,
		"bos.ficha.list":    (*Server).rpcFichaList,
		// bos.bootstrap.*
		"bos.bootstrap.start":  (*Server).rpcBootstrapStart,
		"bos.bootstrap.verify": (*Server).rpcBootstrapVerify,
		"bos.bootstrap.resume": (*Server).rpcBootstrapResume,
		"bos.bootstrap.status": (*Server).rpcBootstrapStatus,
		// bos.saga.*
		"bos.saga.execute": (*Server).rpcSagaExecute,
		// bos.state.*
		"bos.state.read": (*Server).rpcStateRead,
		// bos.health.*
		"bos.health.check": (*Server).rpcHealthCheck,
		// bos.ctx.* — Context Plane (SBOS-049)
		"bos.ctx.create":   (*Server).rpcCtxCreate,
		"bos.ctx.validate": (*Server).rpcCtxValidate,
		// bos.bootstrap.pg_auxiliar.* — PG Auxiliar Anti-Pérdida (Parte V-B)
		"bos.bootstrap.pg_auxiliar_start":   (*Server).rpcPgAuxiliarStart,
		"bos.bootstrap.pg_auxiliar_sync":    (*Server).rpcPgAuxiliarSync,
		"bos.bootstrap.pg_auxiliar_status":  (*Server).rpcPgAuxiliarStatus,
		"bos.bootstrap.pg_auxiliar_cleanup": (*Server).rpcPgAuxiliarCleanup,
		// bos.release.* — SKULL Release Plane
		"bos.release.check": (*Server).rpcReleaseCheck,
		"bos.release.list":  (*Server).rpcReleaseList,
		// system.*
		"system.listMethods": (*Server).rpcSystemListMethods,
	}
}

// dispatchRPC enruta la llamada usando rpcRegistry (ORQUESTA-043 §7).
// Retorna nil para notificaciones (id == null).
func (s *Server) dispatchRPC(req *RPCRequest) *RPCResponse {
	if req.JSONRPC != "2.0" {
		r := rpcFail(req.ID, rpcError(ErrInvalidRequest, "jsonrpc debe ser '2.0'"))
		return &r
	}

	s.logger.Debug("rpc call", "method", req.Method)

	handler, ok := rpcRegistry[req.Method]
	if !ok {
		resp := rpcFail(req.ID, rpcError(ErrMethodNotFound,
			fmt.Sprintf("método no encontrado: %s", req.Method)))
		return &resp
	}

	resp := handler(s, req)

	// Notificación (id == null): no responder
	if req.ID == nil {
		return nil
	}
	return &resp
}

// ── bos.ficha.* — Adaptadores delgados sobre FichaService ────────
// ORQUESTA-043 §2: cada handler solo parsea parámetros y adapta errores.
// La lógica de negocio vive en domain.FichaService.

func (s *Server) rpcFichaInstall(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
		Version string `json:"version"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
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

func (s *Server) rpcFichaUpdate(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
		Version string `json:"version"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
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

func (s *Server) rpcFichaRepair(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
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

func (s *Server) rpcFichaRemove(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
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

func (s *Server) rpcFichaList(_ *RPCRequest) RPCResponse {
	list := s.fichaSvc.List()
	return rpcOK(nil, map[string]interface{}{"fichas": list, "total": len(list)})
}

// ── bos.bootstrap.* — Adaptadores sobre BootstrapService ─────────

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

func (s *Server) rpcBootstrapVerify(req *RPCRequest) RPCResponse {
	result, err := s.bootstrapSvc.Verify()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

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

func (s *Server) rpcBootstrapStatus(req *RPCRequest) RPCResponse {
	result, err := s.bootstrapSvc.Status()
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── bos.saga.execute — Adaptador sobre FichaService.ExecuteSaga ──

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

// ── bos.state.read ────────────────────────────────────────────────

func (s *Server) rpcStateRead(req *RPCRequest) RPCResponse {
	st, err := s.stateMgr.Read()
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]interface{}{
		"version":      st.Version,
		"hostname":     st.Hostname,
		"cluster_name": st.ClusterName,
		"updated_at":   st.UpdatedAt,
		"fichas_total": len(st.Fichas),
		"fichas":       st.Fichas,
	})
}

// ── bos.health.check ─────────────────────────────────────────────

func (s *Server) rpcHealthCheck(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
	}
	_ = parseParams(req.Params, &p)

	// Status delega al dominio; health.check usa la misma vista de estado
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

// ── bos.ctx.* — Adaptadores sobre CtxService ─────────────────────

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
	result, err := s.ctxSvc.Create(domain.CreateParams{
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

func (s *Server) rpcCtxValidate(req *RPCRequest) RPCResponse {
	var p struct {
		TraceParent string `json:"traceparent"`
		TenantID    string `json:"tenant_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	result, err := s.ctxSvc.Validate(p.TraceParent, p.TenantID)
	if err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, result)
}

// ── Mapeo de errores de dominio a códigos JSON-RPC ───────────────
// ORQUESTA-043 §2: el handler mapea, el dominio no conoce RPC.

func domainErrToRPC(_ interface{}, err error) *RPCError {
	switch {
	case errors.Is(err, domain.ErrFichaNotFound):
		return rpcError(ErrFichaNotFound, err.Error())
	case errors.Is(err, domain.ErrFichaIDRequired),
		errors.Is(err, domain.ErrVersionRequired),
		errors.Is(err, domain.ErrCommandRequired),
		errors.Is(err, domain.ErrCommandInvalid),
		errors.Is(err, domain.ErrTenantIDRequired),
		errors.Is(err, domain.ErrTraceparentRequired):
		return rpcError(ErrInvalidParams, err.Error())
	case errors.Is(err, domain.ErrBootstrapInProgress):
		return rpcError(ErrStateConflict, err.Error())
	case errors.Is(err, domain.ErrInstallerUnavailable),
		errors.Is(err, domain.ErrStateUnavailable):
		return rpcError(ErrInternal, err.Error())
	case errors.Is(err, domain.ErrSagaFailed):
		var sagaErr *domain.SagaError
		if errors.As(err, &sagaErr) {
			return &RPCError{
				Code:    ErrSagaFailed,
				Message: fmt.Sprintf("saga %s falló (exit %d)", sagaErr.Command, sagaErr.ExitCode),
				Data:    sagaErr.FailedSteps,
			}
		}
		return rpcError(ErrSagaFailed, err.Error())
	default:
		return rpcError(ErrInternal, err.Error())
	}
}

// ── system.* ─────────────────────────────────────────────────────

// rpcSystemListMethods devuelve el catálogo completo de métodos registrados.
// Permite a clientes (biedata, agentes IA) descubrir la interfaz sin documentación estática.
func (s *Server) rpcSystemListMethods(req *RPCRequest) RPCResponse {
	methods := make([]string, 0, len(rpcRegistry))
	for m := range rpcRegistry {
		methods = append(methods, m)
	}
	sort.Strings(methods)
	return rpcOK(req.ID, map[string]interface{}{
		"methods": methods,
		"total":   len(methods),
		"version": "bos-1.0",
	})
}

// ── Helpers ──────────────────────────────────────────────────────

func parseParams(raw json.RawMessage, dst interface{}) error {
	if raw == nil {
		return nil
	}
	return json.Unmarshal(raw, dst)
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

// ── PG Auxiliar Anti-Pérdida (Parte V-B) ─────────────────────────────

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

func (s *Server) rpcPgAuxiliarStatus(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	return rpcOK(req.ID, s.pgAuxSvc.Status())
}

func (s *Server) rpcPgAuxiliarCleanup(req *RPCRequest) RPCResponse {
	if s.pgAuxSvc == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "pg_auxiliar service not available"))
	}
	if err := s.pgAuxSvc.Cleanup(); err != nil {
		return rpcFail(req.ID, domainErrToRPC(req.ID, err))
	}
	return rpcOK(req.ID, map[string]bool{"cleaned": true})
}

// ── SKULL Release Plane ─────────────────────────────────────────────

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
			"updates":  []interface{}{},
			"offline":  true,
			"error":    err.Error(),
		})
	}
	return rpcOK(req.ID, map[string]interface{}{
		"updates": releases,
		"count":   len(releases),
		"offline": false,
	})
}

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
