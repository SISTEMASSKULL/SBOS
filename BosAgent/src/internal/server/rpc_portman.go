// Package server — Handlers JSON-RPC 2.0 para bos.portman.*.
//
// Motor de Asignación de Puertos (SBOS-050) — 7 métodos:
//
//	bos.portman.assign   — asignar puertos a una ficha (N1/N2/N3/HITL)
//	bos.portman.lookup   — consultar asignación activa de un puerto
//	bos.portman.release  — liberar puertos de una ficha (ficha.remove)
//	bos.portman.check    — verificar disponibilidad de un puerto (3 capas)
//	bos.portman.list     — listar asignaciones del Kardex
//	bos.portman.validate — comparar Kardex vs estado real K8s (drift)
//	bos.portman.export   — exportar Kardex completo en Markdown
//
// Todos los métodos requieren que el Server tenga un PortManager inyectado.
// Si PortManager es nil → error -32603 (no configurado).
package server

import (
	"fmt"
	"os"

	"bos/internal/portman"
)

// PortManager es la interfaz del motor de puertos que el Server usa.
// Implementado por portman.Manager; inyectable para tests.
type PortManager interface {
	Assign(req portman.PortRequest) (*portman.AssignResult, error)
	Release(fichaID, ctxID string) (int, error)
	Lookup(port int, portType, namespace string) (*portman.KardexRow, error)
	Check(port int, portType portman.PortType, namespace string) (*portman.CheckResult, error)
	List(fichaID string, limit int) ([]portman.KardexRow, error)
	ValidateKardex(getK8sSvcFn func(svc, ns string) (int, bool)) (*portman.ValidationResult, error)
	Export(limit int) (string, error)
}

// portmanOrDefault retorna el PortManager del servidor, o crea uno lazy
// usando BOS_PG_DSN si el servidor no tiene uno inyectado.
func (s *Server) portmanOrDefault() (PortManager, *RPCError) {
	if s.portman != nil {
		return s.portman, nil
	}
	dsn := os.Getenv("BOS_PG_DSN")
	if dsn == "" {
		return nil, rpcError(ErrInternal, "portman no configurado — BOS_PG_DSN requerido")
	}
	mgr, err := portman.NewWithDSN(dsn)
	if err != nil {
		return nil, rpcError(ErrInternal, "portman: "+err.Error())
	}
	s.portman = mgr
	return mgr, nil
}

// ── bos.portman.assign ────────────────────────────────────────────────────

// rpcPortmanAssign asigna puertos a una ficha aplicando algoritmos A/B y
// verificación en 3 capas. Devuelve las asignaciones o solicita HITL.
//
// Params:
//
//	ficha_id        string   — ID de la ficha
//	ficha_index     int      — índice de la ficha en el servidor (0-based)
//	logical_server  string   — ej: "S00"
//	port_types      []string — ej: ["K8S_CLUSTER_IP", "K8S_NODE_PORT"]
//	namespace       string   — namespace K8s (default: "default")
//	service_name    string   — nombre del servicio K8s (opcional)
//	transport       string   — "TCP" | "UDP" | "SCTP" | "DCCP" (default: "TCP")
//	ctx_id          string   — ctx_id (SBOS-049)
func (s *Server) rpcPortmanAssign(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID       string   `json:"ficha_id"`
		FichaIndex    int      `json:"ficha_index"`
		LogicalServer string   `json:"logical_server"`
		PortTypes     []string `json:"port_types"`
		Namespace     string   `json:"namespace"`
		ServiceName   string   `json:"service_name"`
		Transport     string   `json:"transport"`
		CtxID         string   `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}
	if p.FichaID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ficha_id requerido"))
	}
	if p.LogicalServer == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "logical_server requerido"))
	}
	if len(p.PortTypes) == 0 {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "port_types requerido (al menos uno)"))
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	pts := make([]portman.PortType, len(p.PortTypes))
	for i, t := range p.PortTypes {
		pts[i] = portman.PortType(t)
	}

	portReq := portman.PortRequest{
		FichaID:       p.FichaID,
		FichaIndex:    p.FichaIndex,
		LogicalServer: p.LogicalServer,
		PortTypes:     pts,
		Namespace:     p.Namespace,
		ServiceName:   p.ServiceName,
		Transport:     portman.Transport(p.Transport),
		AssignedBy:    "bos-installer",
		CtxID:         p.CtxID,
	}

	result, err := mgr.Assign(portReq)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	if result.NeedsHITL {
		return rpcFail(req.ID, &RPCError{
			Code:    ErrInternal,
			Message: "asignación requiere intervención manual (HITL)",
			Data:    map[string]string{"reason": result.HITLReason},
		})
	}

	assignments := make([]map[string]interface{}, len(result.Assignments))
	for i, a := range result.Assignments {
		assignments[i] = map[string]interface{}{
			"port":         a.Port,
			"port_type":    a.PortType,
			"algorithm":    a.Algorithm,
			"tipo_t":       a.TipoT,
			"service_name": a.ServiceName,
			"namespace":    a.Namespace,
			"ficha_id":     a.FichaID,
		}
	}

	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id":    p.FichaID,
		"assigned":    len(assignments),
		"assignments": assignments,
		"needs_hitl":  false,
	})
}

// ── bos.portman.lookup ───────────────────────────────────────────────────

// rpcPortmanLookup retorna la asignación activa de un puerto.
//
// Params: port int, port_type string, namespace string
func (s *Server) rpcPortmanLookup(req *RPCRequest) RPCResponse {
	var p struct {
		Port      int    `json:"port"`
		PortType  string `json:"port_type"`
		Namespace string `json:"namespace"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}
	if p.Port == 0 {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "port requerido"))
	}
	if p.PortType == "" {
		p.PortType = "K8S_CLUSTER_IP"
	}
	if p.Namespace == "" {
		p.Namespace = "default"
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	row, err := mgr.Lookup(p.Port, p.PortType, p.Namespace)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	if row == nil {
		return rpcFail(req.ID, rpcError(ErrFichaNotFound,
			fmt.Sprintf("puerto %d no asignado en %s/%s", p.Port, p.Namespace, p.PortType)))
	}

	return rpcOK(req.ID, rowToMap(row))
}

// ── bos.portman.release ──────────────────────────────────────────────────

// rpcPortmanRelease libera los puertos de una ficha (status → released).
//
// Params: ficha_id string, ctx_id string
func (s *Server) rpcPortmanRelease(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
		CtxID   string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}
	if p.FichaID == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "ficha_id requerido"))
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	released, err := mgr.Release(p.FichaID, p.CtxID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	return rpcOK(req.ID, map[string]interface{}{
		"ficha_id": p.FichaID,
		"released": released,
	})
}

// ── bos.portman.check ────────────────────────────────────────────────────

// rpcPortmanCheck verifica si un puerto está disponible (3 capas).
//
// Params: port int, port_type string, namespace string
func (s *Server) rpcPortmanCheck(req *RPCRequest) RPCResponse {
	var p struct {
		Port      int    `json:"port"`
		PortType  string `json:"port_type"`
		Namespace string `json:"namespace"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}
	if p.Port == 0 {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "port requerido"))
	}
	if p.PortType == "" {
		p.PortType = "K8S_CLUSTER_IP"
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	result, err := mgr.Check(p.Port, portman.PortType(p.PortType), p.Namespace)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	return rpcOK(req.ID, map[string]interface{}{
		"port":      p.Port,
		"available": result.Available,
		"conflicts": result.Conflicts,
	})
}

// ── bos.portman.list ─────────────────────────────────────────────────────

// rpcPortmanList retorna asignaciones del Kardex.
//
// Params: ficha_id string (opcional), limit int (default 100)
func (s *Server) rpcPortmanList(req *RPCRequest) RPCResponse {
	var p struct {
		FichaID string `json:"ficha_id"`
		Limit   int    `json:"limit"`
	}
	if req.Params != nil {
		if err := parseParams(req.Params, &p); err != nil {
			return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
		}
	}
	if p.Limit <= 0 {
		p.Limit = 100
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	rows, err := mgr.List(p.FichaID, p.Limit)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	items := make([]map[string]interface{}, len(rows))
	for i := range rows {
		items[i] = rowToMap(&rows[i])
	}

	return rpcOK(req.ID, map[string]interface{}{
		"total": len(items),
		"items": items,
	})
}

// ── bos.portman.validate ─────────────────────────────────────────────────

// rpcPortmanValidate compara el Kardex contra el estado real (drift detection).
// No necesita parámetros — usa el contexto K8s del servidor.
func (s *Server) rpcPortmanValidate(req *RPCRequest) RPCResponse {
	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	// En esta iteración validamos sin llamada real a K8s (nil = solo Kardex interno).
	// La integración completa con k8s.Core se implementa en el reconcile/scheduler.
	result, err := mgr.ValidateKardex(nil)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	drifted := make([]map[string]interface{}, len(result.Drifted))
	for i, d := range result.Drifted {
		drifted[i] = map[string]interface{}{
			"port_id":      d.PortID,
			"port":         d.Port,
			"ficha_id":     d.FichaID,
			"service_name": d.ServiceName,
			"reason":       d.Reason,
		}
	}

	return rpcOK(req.ID, map[string]interface{}{
		"checked": result.Checked,
		"ok":      result.OK,
		"drifted": len(result.Drifted),
		"items":   drifted,
	})
}

// ── bos.portman.export ───────────────────────────────────────────────────

// rpcPortmanExport exporta el Kardex en formato Markdown.
//
// Params: limit int (default 500)
func (s *Server) rpcPortmanExport(req *RPCRequest) RPCResponse {
	var p struct {
		Limit int `json:"limit"`
	}
	if req.Params != nil {
		_ = parseParams(req.Params, &p)
	}
	if p.Limit <= 0 {
		p.Limit = 500
	}

	mgr, rpcErr := s.portmanOrDefault()
	if rpcErr != nil {
		return rpcFail(req.ID, rpcErr)
	}

	md, err := mgr.Export(p.Limit)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}

	return rpcOK(req.ID, map[string]interface{}{
		"format":  "markdown",
		"content": md,
	})
}

// ── Helpers ──────────────────────────────────────────────────────────────

// rowToMap convierte un KardexRow al map JSON para la respuesta RPC.
func rowToMap(r *portman.KardexRow) map[string]interface{} {
	m := map[string]interface{}{
		"port_id":        r.PortID,
		"service_name":   r.ServiceName,
		"port":           r.Port,
		"transport":      r.Transport,
		"port_type":      r.PortType,
		"logical_server": r.LogicalServer,
		"namespace":      r.Namespace,
		"ficha_id":       r.FichaID,
		"assigned_by":    r.AssignedBy,
		"description":    r.Description,
		"doc_reference":  r.DocReference,
		"status":         r.Status,
		"algorithm":      r.Algorithm,
		"assigned_at":    r.AssignedAt,
		"ctx_id":         r.CtxID,
	}
	if r.ReleasedAt != nil {
		m["released_at"] = r.ReleasedAt
	}
	if r.LastValidatedAt != nil {
		m["last_validated_at"] = r.LastValidatedAt
	}
	return m
}
