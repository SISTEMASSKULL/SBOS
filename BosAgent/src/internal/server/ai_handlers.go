package server

// ai_handlers.go — F10.8: módulo bos.ai.* (BOS-REPAIR-10 §2). El agente
// biaos se invoca por RPC como cualquier otro daemon; sus herramientas son
// los propios métodos del rpcRegistry (sagas F6 + Operator F9), ejecutados
// a través del dispatcher con el mismo enrutado de auth y timeout.

import (
	"encoding/json"
	"fmt"

	"bos/internal/biaos"
)

func jsonMarshal(v interface{}) ([]byte, error) { return json.Marshal(v) }

func errMethodDesconocido(m string) error { return fmt.Errorf("método desconocido: %s", m) }

func errRPC(code int, msg string) error { return fmt.Errorf("rpc error %d: %s", code, msg) }

// AIAgent es el contrato del agente biaos hacia el server (lo implementa
// *biaos.Agente; inyectado vía SetAIAgent).
type AIAgent interface {
	RunConParams(user, intencion string, params map[string]interface{}) (*biaos.Resultado, error)
	Confirmar(user, sesionID string) (*biaos.Resultado, error)
	Herramientas() []string
}

// SetAIAgent inyecta el agente biaos (F10.8 — run_normal.go).
func (s *Server) SetAIAgent(a AIAgent) { s.aiAgent = a }

// ToolExecutor es el ejecutor de herramientas del agente biaos: invoca un
// método del rpcRegistry como caller CONFIABLE del propio daemon (el agente
// ya pasó guardia de dominio + RBAC + HITL en biaos; aquí solo despacha).
// Devuelve el Result del método o el error mapeado.
//
// Pasado a biaos.Config.Exec en run_normal.go.
func (s *Server) ToolExecutor(metodo string, params map[string]interface{}) (interface{}, error) {
	handler, ok := rpcRegistry[metodo]
	if !ok {
		return nil, errMethodDesconocido(metodo)
	}
	var raw []byte
	if params != nil {
		raw, _ = jsonMarshal(params)
	}
	req := &RPCRequest{JSONRPC: "2.0", Method: metodo, Params: raw, ID: "biaos"}
	// caller confiable: el agente corre dentro del daemon, no por el socket;
	// no re-aplica el token RPC (ya validó RBAC sobre el metodo_rpc en biaos)
	resp := s.runWithTimeout(handler, req)
	if resp.Error != nil {
		return nil, errRPC(resp.Error.Code, resp.Error.Message)
	}
	return resp.Result, nil
}

// aiUser deriva el usuario de la credencial RPC; "anon" si no vino.
func aiUser(auth string) string {
	if auth == "" {
		return "anon"
	}
	return auth
}

// rpcAIRun — método: bos.ai.run (destructivo: puede proponer escrituras)
//
// Params: {"intencion": string, "user": string (opcional)}
// Returns: biaos.Resultado (trayectoria + conclusión; requiere_hitl si TIPO B)
func (s *Server) rpcAIRun(req *RPCRequest) RPCResponse {
	if s.aiAgent == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "agente biaos no disponible"))
	}
	var p struct {
		Intencion string                 `json:"intencion"`
		User      string                 `json:"user"`
		Params    map[string]interface{} `json:"params"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.Intencion == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "intencion requerida"))
	}
	res, err := s.aiAgent.RunConParams(aiUser(p.User), p.Intencion, p.Params)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrGovernanceDeny, err.Error()))
	}
	return rpcOK(req.ID, res)
}

// rpcAIAsk — método: bos.ai.ask (lectura)
//
// Alias de run para callers que solo consultan: el agente decide; si la
// intención fuese de escritura, devuelve requiere_hitl sin ejecutar.
func (s *Server) rpcAIAsk(req *RPCRequest) RPCResponse {
	return s.rpcAIRun(req)
}

// rpcAIConfirm — método: bos.ai.confirm (destructivo)
//
// Params: {"sesion_id": string, "user": string (opcional)}
// Reanuda y ejecuta una acción que estaba en HITL.
func (s *Server) rpcAIConfirm(req *RPCRequest) RPCResponse {
	if s.aiAgent == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "agente biaos no disponible"))
	}
	var p struct {
		SesionID string `json:"sesion_id"`
		User     string `json:"user"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, err.Error()))
	}
	if p.SesionID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "sesion_id requerido"))
	}
	res, err := s.aiAgent.Confirmar(aiUser(p.User), p.SesionID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrStateConflict, err.Error()))
	}
	return rpcOK(req.ID, res)
}

// rpcAICatalog — método: bos.ai.catalog (lectura)
// Returns: {"herramientas": [...], "total": int}
func (s *Server) rpcAICatalog(req *RPCRequest) RPCResponse {
	if s.aiAgent == nil {
		return rpcFail(req.ID, rpcError(ErrInternal, "agente biaos no disponible"))
	}
	hs := s.aiAgent.Herramientas()
	return rpcOK(req.ID, map[string]interface{}{"herramientas": hs, "total": len(hs)})
}
