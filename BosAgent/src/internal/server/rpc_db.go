// Package server — Handlers JSON-RPC 2.0 para bos.db.*.
//
// BC-07: DbInitService — inicialización automática de SBOS_db (C-04b).
// Métodos:
//
//	bos.db.init   — aplicar DDLs + seeds a SBOS_db
//	bos.db.status — consultar estado de inicialización y conteos de tablas
//
// Principio P3: los handlers son adaptadores delgados — toda la lógica
// vive en domain.DbInitService.
package server

import (
	"fmt"
	"os"

	"bos/internal/domain"
)

// dbInitSvc retorna el servicio de inicialización de BD.
// Si no fue inyectado, usa MemDBExec (modo dev — sin BD real).
// Nil-safe: nunca retorna nil.
func (s *Server) dbInitSvc() *domain.DbInitService {
	if s.dbInit == nil {
		s.dbInit = domain.NewDbInitService(
			domain.NewMemDBExec(),
			"",
			"",
		)
	}
	return s.dbInit
}

// ── bos.db.init ──────────────────────────────────────────────────────────────

// rpcDBInit aplica DDLs y seeds a SBOS_db (criterio C-04b).
//
// Si BOS_PG_DSN está definido, crea un PgExecAdapter real en el primer llamado.
//
// Params:
//
//	ctx_id string — contexto de auditoría (SBOS-049)
//
// Returns: DBInitStatus { initialized, phase, schemas, seeds_applied, finished_at }
func (s *Server) rpcDBInit(req *RPCRequest) RPCResponse {
	var p struct {
		CtxID string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}

	// Si hay BOS_PG_DSN y aún usamos MemDBExec, inyectar el adaptador real.
	if dsn := os.Getenv("BOS_PG_DSN"); dsn != "" && s.dbInit == nil {
		if err := s.initRealDBAdapter(dsn); err != nil {
			return rpcFail(req.ID, rpcError(ErrInternal, fmt.Sprintf("conectar a PostgreSQL: %v", err)))
		}
	}

	status, err := s.dbInitSvc().Init(p.CtxID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, status)
}

// ── bos.db.status ────────────────────────────────────────────────────────────

// rpcDBStatus retorna el estado actual de SBOS_db y los conteos de tablas por schema.
//
// Params: ninguno (ctx_id opcional)
//
// Returns: DBInitStatus + c04b_passed bool
func (s *Server) rpcDBStatus(req *RPCRequest) RPCResponse {
	svc := s.dbInitSvc()
	st := svc.Status()
	return rpcOK(req.ID, map[string]interface{}{
		"status":      st,
		"c04b_passed": svc.C04bPassed(),
	})
}

// ── inicialización del adaptador real ────────────────────────────────────────

// initRealDBAdapter crea un PgExecAdapter real e inyecta un DbInitService con las
// rutas canónicas de DDL derivadas de la ubicación del binario.
//
// Rutas canónicas:
//
//	ddlDir  = BOS_DDL_DIR (env) o /opt/skull/orquestador/proyectos/SBOS/DDLs/
//	seedDir = BOS_SEED_DIR (env) o /opt/skull/orquestador/proyectos/SBOS/DDLs/seeds/
func (s *Server) initRealDBAdapter(dsn string) error {
	adapter, err := domain.NewPgExecAdapter(dsn)
	if err != nil {
		return err
	}

	ddlDir := os.Getenv("BOS_DDL_DIR")
	if ddlDir == "" {
		ddlDir = "/opt/skull/orquestador/proyectos/SBOS/DDLs"
	}
	seedDir := os.Getenv("BOS_SEED_DIR")
	if seedDir == "" {
		seedDir = "/opt/skull/orquestador/proyectos/SBOS/DDLs/seeds"
	}

	s.dbInit = domain.NewDbInitService(adapter, ddlDir, seedDir)
	return nil
}
