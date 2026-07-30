// Package server — JSON-RPC 2.0 sobre Unix socket /run/bos/bos.sock (ADR-019).
//
// Ruta: POST /rpc
// Transporte: Unix socket (SBOS-050 P9 — sin TCP entre daemons)
// Clientes: biedata, bkernel, bauth, bsearch, agentes IA
//
// Naming: bos.<modulo>.<operacion>
// Módulos: ficha | bootstrap | saga | state | health | ctx | query | release
//
// Robustez (F6): auth en métodos destructivos (auth.go), timeout por
// categoría (timeout.go), batch paralelo (dispatchBatch), sagas de consulta
// multi-fuente (query_handlers.go + internal/query).
//
// Archivos del subsistema JSON-RPC:
//   rpc_ficha.go        — handlers bos.ficha.* (install, update, repair, remove, status, probe, list, describe)
//   rpc_ficha_f11.go    — handlers bos.ficha.* F11 (plan, diff, validate, scale, pause, resume, rescan, logs)
//   rpc_bootstrap.go    — handlers bos.bootstrap.* y bos.saga.execute
//   rpc_ctx.go          — handlers bos.ctx.*, bos.state.read, bos.health.check
//   rpc_pg_auxiliar.go  — handlers bos.bootstrap.pg_auxiliar.*
//   rpc_release.go      — handlers bos.release.*
//   rpc_capacity.go     — handlers bos.capacity.*
//   rpc_system.go       — handlers system.* y domainErrToRPC
//   rpc_helpers.go      — parseParams, writeJSON, injectEnv, restoreEnv
package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"bos/internal/metrics"
	"bos/internal/ratelimit"
)

// ── Tipos JSON-RPC 2.0 ──────────────────────────────────────────────────

// RPCRequest es el sobre de solicitud JSON-RPC 2.0.
// Soporta llamada individual y batch ([]RPCRequest).
// Thread safety: inmutable tras ser decodificado por handleJSONRPC.
type RPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	ID      interface{}     `json:"id"`              // string | number | null (notificación)
	Ctx     context.Context `json:"-"`               // cancelable — asignado por runWithTimeout
}

// RPCResponse es el sobre de respuesta JSON-RPC 2.0.
// Solo uno de Result/Error puede ser no-nil (especificación JSON-RPC 2.0 §5).
type RPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

// RPCError es el objeto de error estándar JSON-RPC 2.0 (especificación §5.1).
// Data es opcional — se usa para errores de saga (lista de pasos fallidos).
type RPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// ── Códigos de error ────────────────────────────────────────────────────

// Códigos de error JSON-RPC 2.0 estándar (especificación §5.1) + extensiones SBOS.
//
// Rango estándar: -32768 a -32000 (reservado por spec).
// Extensiones SBOS: -32001 a -32099 (definidas en ADR-019).
const (
	ErrParse            = -32700 // JSON inválido recibido por el servidor
	ErrInvalidRequest   = -32600 // el JSON no es un Request object válido
	ErrMethodNotFound   = -32601 // el método no existe o no está disponible
	ErrInvalidParams    = -32602 // parámetros inválidos o ausentes
	ErrInternal         = -32603 // error interno del servidor
	ErrContextExpired   = -32001 // ctx_id expirado — requiere re-autenticación (F6.5)
	ErrDepNotSatisfied  = -32002 // dependencia de ficha no satisfecha
	ErrSagaFailed       = -32003 // la saga falló — data contiene pasos fallidos
	ErrStateConflict    = -32004 // transición de estado no permitida
	ErrGovernanceDeny   = -32005 // RBAC/Governance negó la operación
	ErrTimeout          = -32006 // el método excedió el plazo de su categoría (F6.2)
	ErrFichaNotFound    = -32010 // la ficha o recurso no está registrado
	ErrRateLimit        = -32029 // rate limit excedido — demasiadas solicitudes por IP (NRS-08)
)

// ── Constructores de respuesta ──────────────────────────────────────────

// rpcError construye un RPCError con el código y mensaje especificados.
func rpcError(code int, msg string) *RPCError {
	return &RPCError{Code: code, Message: msg}
}

// rpcOK construye una respuesta JSON-RPC exitosa con el resultado dado.
func rpcOK(id interface{}, result interface{}) RPCResponse {
	return RPCResponse{JSONRPC: "2.0", Result: result, ID: id}
}

// rpcFail construye una respuesta JSON-RPC de error.
func rpcFail(id interface{}, err *RPCError) RPCResponse {
	return RPCResponse{JSONRPC: "2.0", Error: err, ID: id}
}

// ── Handler HTTP /rpc ───────────────────────────────────────────────────

// handleJSONRPC procesa solicitudes JSON-RPC 2.0 en POST /rpc.
// Soporta llamada individual y batch. Delega en dispatchRPC/dispatchBatch.
func (s *Server) handleJSONRPC(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "método no permitido — usar POST", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// NRS-08: rate limiting por IP — 100 req/s (token bucket).
	// Unix sockets pasan siempre (ExtractIP retorna "" para @/vacío).
	if s.limiter != nil && !s.limiter.Allow(ratelimit.ExtractIP(r)) {
		w.WriteHeader(http.StatusTooManyRequests)
		if s.metrics != nil {
			s.metrics.Counter("bos_rpc_ratelimit_total").Inc()
		}
		writeJSON(w, rpcFail(nil, rpcError(ErrRateLimit, "demasiadas solicitudes — límite 100 req/s por IP")))
		return
	}

	auth := parseRPCAuth(r)

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
		writeJSON(w, s.dispatchBatch(reqs, auth))
		return
	}

	var req RPCRequest
	if err := json.Unmarshal(raw, &req); err != nil {
		writeJSON(w, rpcFail(nil, rpcError(ErrInvalidRequest, err.Error())))
		return
	}
	if resp := s.dispatchRPC(&req, auth); resp != nil {
		writeJSON(w, *resp)
	}
}

// ── Dispatch ────────────────────────────────────────────────────────────

// dispatchBatch ejecuta cada solicitud del batch en su propia goroutine (F6.3).
// Preserva el orden de entrada. Las notificaciones (id null) no producen respuesta.
func (s *Server) dispatchBatch(reqs []RPCRequest, auth rpcAuth) []RPCResponse {
	slots := make([]*RPCResponse, len(reqs))
	var wg sync.WaitGroup
	for i := range reqs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			slots[i] = s.dispatchRPC(&reqs[i], auth)
		}(i)
	}
	wg.Wait()

	responses := make([]RPCResponse, 0, len(reqs))
	for _, r := range slots {
		if r != nil {
			responses = append(responses, *r)
		}
	}
	return responses
}

// RPCHandler es el tipo de función que implementa un método JSON-RPC 2.0.
// ORQUESTA-043 §6 — Registro de Métodos: Open/Closed, extensible sin tocar el dispatcher.
type RPCHandler func(*Server, *RPCRequest) RPCResponse

// rpcRegistry mapea method_name → handler (ORQUESTA-043 §6).
// Se inicializa en init(). Para registrar un nuevo método: añadir una línea en init().
// El dispatcher no cambia.
var rpcRegistry map[string]RPCHandler

func init() {
	rpcRegistry = map[string]RPCHandler{
		// bos.ficha.*
		"bos.ficha.install":  (*Server).rpcFichaInstall,
		"bos.ficha.update":   (*Server).rpcFichaUpdate,
		"bos.ficha.repair":   (*Server).rpcFichaRepair,
		"bos.ficha.remove":   (*Server).rpcFichaRemove,
		"bos.ficha.status":   (*Server).rpcFichaStatus,
		"bos.ficha.probe":    (*Server).rpcFichaProbe,
		"bos.ficha.list":     (*Server).rpcFichaList,
		"bos.ficha.describe": (*Server).rpcFichaDescribe,
		// bos.ficha.* — F11 (nuevos)
		"bos.ficha.plan":     (*Server).rpcFichaPlan,
		"bos.ficha.diff":     (*Server).rpcFichaDiff,
		"bos.ficha.validate": (*Server).rpcFichaValidate,
		"bos.ficha.scale":    (*Server).rpcFichaScale,
		"bos.ficha.pause":    (*Server).rpcFichaPause,
		"bos.ficha.resume":   (*Server).rpcFichaResume,
		"bos.ficha.rescan":   (*Server).rpcFichaRescan,
		"bos.ficha.logs":     (*Server).rpcFichaLogs,
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
		// bos.ctx.* — Context Plane DDL
		"bos.ctx.auto_migrate": (*Server).rpcCtxAutoMigrate,
		// bos.ctx.* — Context Plane legacy (SBOS-049 v1)
		"bos.ctx.create":   (*Server).rpcCtxCreate,
		"bos.ctx.validate": (*Server).rpcCtxValidate,
		// bos.ctx.* — Context Plane completo (F5)
		"bos.ctx.device.register": (*Server).rpcCtxDeviceRegister,
		"bos.ctx.promote":         (*Server).rpcCtxPromote,
		"bos.ctx.switch":          (*Server).rpcCtxSwitch,
		"bos.ctx.invalidate":      (*Server).rpcCtxInvalidate,
		"bos.ctx.get":             (*Server).rpcCtxGet,
		"bos.ctx.list":            (*Server).rpcCtxList,
		"bos.ctx.tenant.suspend":  (*Server).rpcCtxTenantSuspend,
		"bos.ctx.heartbeat":       (*Server).rpcCtxHeartbeat,
		// bos.bootstrap.pg_auxiliar.*
		"bos.bootstrap.pg_auxiliar_start":   (*Server).rpcPgAuxiliarStart,
		"bos.bootstrap.pg_auxiliar_sync":    (*Server).rpcPgAuxiliarSync,
		"bos.bootstrap.pg_auxiliar_status":  (*Server).rpcPgAuxiliarStatus,
		"bos.bootstrap.pg_auxiliar_cleanup": (*Server).rpcPgAuxiliarCleanup,
		// bos.release.*
		"bos.release.check": (*Server).rpcReleaseCheck,
		"bos.release.list":  (*Server).rpcReleaseList,
		// bos.k8s.* — Operator Soberano (F9.5)
		"bos.k8s.node.list":      (*Server).rpcK8sNodeList,
		"bos.k8s.node.cordon":    (*Server).rpcK8sNodeCordon,
		"bos.k8s.node.uncordon":  (*Server).rpcK8sNodeUncordon,
		"bos.k8s.node.drain":     (*Server).rpcK8sNodeDrain,
		"bos.k8s.pod.evict":      (*Server).rpcK8sPodEvict,
		"bos.k8s.pod.restart":    (*Server).rpcK8sPodRestart,
		"bos.k8s.scale":          (*Server).rpcK8sScale,
		"bos.k8s.rollout.status": (*Server).rpcK8sRolloutStatus,
		"bos.k8s.rollout.undo":   (*Server).rpcK8sRolloutUndo,
		"bos.k8s.resources.set":  (*Server).rpcK8sResourcesSet,
		// bos.maintenance.* — sagas de mantenimiento (F9.6)
		"bos.maintenance.start":  (*Server).rpcMaintenanceStart,
		"bos.maintenance.status": (*Server).rpcMaintenanceStatus,
		"bos.maintenance.cancel": (*Server).rpcMaintenanceCancel,
		// bos.ai.* — agente biaos (F10.8)
		"bos.ai.ask":     (*Server).rpcAIAsk,
		"bos.ai.run":     (*Server).rpcAIRun,
		"bos.ai.confirm": (*Server).rpcAIConfirm,
		"bos.ai.catalog": (*Server).rpcAICatalog,
		// bos.query.* — Sagas de consulta multi-fuente en paralelo (F6.6–F6.11)
		"bos.query.system":  (*Server).rpcQuerySystem,
		"bos.query.repair":  (*Server).rpcQueryRepair,
		"bos.query.vdi":     (*Server).rpcQueryVdi,
		"bos.query.tenant":  (*Server).rpcQueryTenant,
		"bos.query.node":    (*Server).rpcQueryNode,
		"bos.query.context": (*Server).rpcQueryContext,
		// bos.capacity.* — Control de admisión dinámico (M1-CAP)
		"bos.capacity.check":  (*Server).rpcCapacityCheck,
		"bos.capacity.status": (*Server).rpcCapacityStatus,
		// system.*
		"system.listMethods": (*Server).rpcSystemListMethods,
	}
}

// dispatchRPC enruta la llamada usando rpcRegistry (ORQUESTA-043 §7).
// Verifica auth en métodos destructivos (F6.1) antes de ejecutar el handler.
// Retorna nil para notificaciones (id == null).
func (s *Server) dispatchRPC(req *RPCRequest, auth rpcAuth) *RPCResponse {
	if req.JSONRPC != "2.0" {
		r := rpcFail(req.ID, rpcError(ErrInvalidRequest, "jsonrpc debe ser '2.0'"))
		return &r
	}

	s.logger.Debug("rpc call", "method", req.Method)
	if s.metrics != nil {
		s.metrics.Counter("bos_rpc_requests_total").Inc()
	}

	handler, ok := rpcRegistry[req.Method]
	if !ok {
		resp := rpcFail(req.ID, rpcError(ErrMethodNotFound,
			fmt.Sprintf("método no encontrado: %s", req.Method)))
		return &resp
	}

	if authErr := s.authorizeRPC(req.Method, auth); authErr != nil {
		s.logger.Warn("rpc unauthorized", "method", req.Method, "user", auth.User)
		if s.metrics != nil {
			s.metrics.Counter("bos_rpc_unauthorized_total").Inc()
		}
		resp := rpcFail(req.ID, authErr)
		return &resp
	}

	resp := s.runWithTimeout(handler, req)

	if s.metrics != nil && resp.Error != nil {
		s.metrics.Counter("bos_rpc_errors_total").Inc()
		if resp.Error.Code == ErrTimeout {
			s.metrics.Counter("bos_rpc_timeouts_total").Inc()
		}
	}

	// Notificación (id == null): no responder
	if req.ID == nil {
		return nil
	}
	return &resp
}

// SetMetrics inyecta el registro de métricas (F9.7 — run_normal.go).
func (s *Server) SetMetrics(r *metrics.Registry) { s.metrics = r }

// runWithTimeout ejecuta el handler con el plazo de su categoría (F6.2).
// A-10: ctx con timeout inyectado en req.Ctx — handlers que bloquean pueden verificar
// ctx.Done() para abortar. defer cancel() libera recursos cuando el handler termina antes.
func (s *Server) runWithTimeout(handler RPCHandler, req *RPCRequest) RPCResponse {
	timeout := methodTimeout(req.Method)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	reqCtx := *req
	reqCtx.Ctx = ctx
	done := make(chan RPCResponse, 1)
	go func() { done <- handler(s, &reqCtx) }()

	select {
	case resp := <-done:
		return resp
	case <-ctx.Done():
		s.logger.Warn("rpc timeout", "method", req.Method, "limit", timeout)
		return rpcFail(req.ID, rpcError(ErrTimeout,
			fmt.Sprintf("método %s excedió el plazo de %s", req.Method, timeout)))
	}
}
