// Package server — Handlers JSON-RPC 2.0 para system.* y mapeo de errores.
//
//   system.listMethods — catálogo completo de métodos registrados (descubrimiento dinámico)
//
// Mapeo de errores de dominio a códigos JSON-RPC 2.0 estándar (ORQUESTA-043 §2):
// el handler traduce, el dominio no conoce RPC. Cada error de dominio se mapea
// al código JSON-RPC correspondiente según su semántica.
package server

import (
	"errors"
	"fmt"
	"sort"

	"bos/internal/domain"
)

// ── system.listMethods ──────────────────────────────────────────────────

// rpcSystemListMethods devuelve el catálogo completo de métodos JSON-RPC registrados,
// ordenados alfabéticamente. Permite a clientes (biedata, agentes IA) descubrir
// la interfaz sin documentación estática — cumpliendo ORQUESTA-043 §6.
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

// ── Mapeo de errores de dominio a códigos JSON-RPC ─────────────────────

// domainErrToRPC traduce errores tipados de domain.* a códigos de error JSON-RPC 2.0.
// Usa errors.Is() para comparación semántica (no strings) según ORQUESTA-043 §2.
//
// Mapeo:
//   ErrFichaNotFound      → -32010 (ErrFichaNotFound)
//   Err*Required/Invalid  → -32602 (ErrInvalidParams)
//   ErrBootstrapInProgress → -32004 (ErrStateConflict)
//   ErrSagaFailed         → -32003 (ErrSagaFailed) con data de pasos fallidos
//   default                → -32603 (ErrInternal)
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
