// Package server — Handlers JSON-RPC 2.0 para bos.capacity.*.
//
// Control de Admisión Dinámico (M1-CAP del Plan Maestro BOS-REPAIR):
// Evalúa si una operación (crear tenant, empresa, sucursal, usuario) puede
// ejecutarse sin exceder los límites de capacidad declarados en el wizard
// de instalación (capacity.yaml).
//
// Métodos:
//   bos.capacity.check  — verificar si una operación cabe en la capacidad declarada
//   bos.capacity.status — consultar estimados y requisitos calculados
//
// La capacidad se declara durante bosctl install --mode=interactive y se
// persiste en /etc/bos/capacity.yaml. El Admission Controller la consulta
// antes de cada operación de crecimiento del sistema.
package server

import (
	"fmt"

	"bos/internal/capacity"
)

// ── bos.capacity.check ─────────────────────────────────────────────────

// rpcCapacityCheck evalúa si una operación puede ejecutarse sin superar los
// límites de capacidad declarados en el wizard de instalación.
//
// Params:
//   op_type  string — "tenant" | "empresa" | "sucursal" | "usuario"
//   current  int    — unidades actuales del recurso limitante
//   used_mb  int    — RAM o disco en uso actualmente (MB); 0 si no aplica
//   req_mb   int    — incremento de MB que necesitaría la operación; 0 si no aplica
//
// Returns: { allowed: bool, reason: string, detail: string, thresholds: {...} }
func (s *Server) rpcCapacityCheck(req *RPCRequest) RPCResponse {
	var p struct {
		OpType  string `json:"op_type"`
		Current int    `json:"current"`
		UsedMB  int    `json:"used_mb"`
		ReqMB   int    `json:"req_mb"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}
	if p.OpType == "" {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "op_type es requerido"))
	}

	est, err := capacity.Load(capacity.DefaultPath)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal,
			"capacity.yaml no disponible: instalar BOS primero"))
	}
	reqs := capacity.Calculate(est)

	// Mapa de límites por tipo de operación
	limits := map[string]int{
		"tenant":   est.Tenants,
		"empresa":  est.Tenants * est.CompaniesPerTenant,
		"sucursal": est.Tenants * est.CompaniesPerTenant * est.BranchesPerCompany,
		"usuario":  est.TotalUsers(),
	}
	limit, ok := limits[p.OpType]
	if !ok {
		return rpcFail(req.ID, rpcError(ErrInvalidParams,
			fmt.Sprintf("op_type desconocido: %q (válidos: tenant, empresa, sucursal, usuario)", p.OpType)))
	}

	result := capacity.CheckAdmission(p.OpType, p.Current, limit, p.UsedMB, p.ReqMB)
	return rpcOK(req.ID, map[string]interface{}{
		"allowed": result.Allowed,
		"reason":  result.Reason,
		"detail":  result.Detail,
		"thresholds": map[string]interface{}{
			"ram_min_mb":     reqs.RAMMinMB,
			"ram_rec_mb":     reqs.RAMRecMB,
			"disk_min_gb":    reqs.DiskMinGB,
			"concurrent_ctx": reqs.ConcurrentCtx,
			"redis_db1_mb":   reqs.RedisDB1MB,
			"pg_data_gb":     reqs.PGDataGB,
		},
	})
}

// ── bos.capacity.status ────────────────────────────────────────────────

// rpcCapacityStatus devuelve los estimados declarados en capacity.yaml
// y los requisitos de infraestructura calculados a partir de ellos.
// No requiere parámetros. Útil para dashboards y diagnóstico de capacidad.
func (s *Server) rpcCapacityStatus(_ *RPCRequest) RPCResponse {
	req := &RPCRequest{}
	est, err := capacity.Load(capacity.DefaultPath)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal,
			"capacity.yaml no disponible: instalar BOS primero"))
	}
	reqs := capacity.Calculate(est)
	return rpcOK(req.ID, map[string]interface{}{
		"estimate": map[string]interface{}{
			"tenants":              est.Tenants,
			"companies_per_tenant": est.CompaniesPerTenant,
			"branches_per_company": est.BranchesPerCompany,
			"users_per_branch":     est.UsersPerBranch,
			"total_users":          est.TotalUsers(),
			"concurrent_users":     est.ConcurrentUsers(),
		},
		"requirements": map[string]interface{}{
			"ram_min_mb":     reqs.RAMMinMB,
			"ram_rec_mb":     reqs.RAMRecMB,
			"disk_min_gb":    reqs.DiskMinGB,
			"disk_rec_gb":    reqs.DiskRecGB,
			"cpu_min":        reqs.CPUMin,
			"cpu_rec":        reqs.CPURec,
			"concurrent_ctx": reqs.ConcurrentCtx,
			"redis_db1_mb":   reqs.RedisDB1MB,
			"pg_data_gb":     reqs.PGDataGB,
		},
	})
}
