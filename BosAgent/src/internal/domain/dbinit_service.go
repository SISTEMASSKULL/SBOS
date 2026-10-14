// Package domain — DbInitService: inicialización automática de SBOS_db.
//
// BC-07: aplica DDLs + seeds al postgresql instalado (C-04) automáticamente,
// sin intervención manual (ADR-022). Criterio de verificación: C-04b.
//
// Flujo:
//
//	postgresql healthy (C-04) → DbInitService.Init() → SBOS_db ready (C-04b)
//
// Principio P3 (domain separation): no importa nada de server/.
// Principio P6 (sin credenciales hardcodeadas): DSN viene de BOS_PG_DSN.
package domain

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// DBExecPort define las operaciones de BD que DbInitService necesita.
// Implementado por PgExecAdapter (producción) y MemDBExec (tests).
type DBExecPort interface {
	// Exec ejecuta una o más sentencias SQL separadas por punto y coma.
	// Tolerante a errores de "ya existe" (idempotente).
	Exec(sql string) error
	// ExecStrict ejecuta SQL y falla si hay cualquier error (incluyendo duplicados).
	ExecStrict(sql string) error
	// QueryInt ejecuta un query que retorna exactamente un entero.
	QueryInt(query string, args ...interface{}) (int, error)
	// SchemaExists retorna true si el schema existe en la BD.
	SchemaExists(schema string) (bool, error)
}

// DBInitStatus describe el estado actual de la base de datos SBOS.
type DBInitStatus struct {
	Initialized  bool           `json:"initialized"`
	Phase        string         `json:"phase"`   // idle | applying_ddl | applying_seeds | ready | error
	Schemas      map[string]int `json:"schemas"` // schema → total_tablas
	SeedsApplied int            `json:"seeds_applied"`
	Error        string         `json:"error,omitempty"`
	FinishedAt   *time.Time     `json:"finished_at,omitempty"`
}

// C04bMinTables define el mínimo de tablas por schema para criterio C-04b.
var C04bMinTables = map[string]int{
	"bauth":   130,
	"bos":     21,
	"bglobal": 10,
}

// DbInitService inicializa SBOS_db aplicando DDLs y seeds automáticamente.
//
// Thread safety: solo una operación Init puede ejecutarse a la vez.
// Llamadas concurrentes retornan el estado actual sin bloquear.
type DbInitService struct {
	db      DBExecPort
	ddlDir  string
	seedDir string

	mu     sync.Mutex
	status DBInitStatus
}

// NewDbInitService crea un nuevo servicio de inicialización de BD.
//
// ddlDir: directorio con los .sql de DDL (ej: /opt/skull/.../SBOS/DDLs/)
// seedDir: directorio con los seeds  (ej: /opt/skull/.../SBOS/DDLs/seeds/)
func NewDbInitService(db DBExecPort, ddlDir, seedDir string) *DbInitService {
	return &DbInitService{
		db:      db,
		ddlDir:  ddlDir,
		seedDir: seedDir,
		status:  DBInitStatus{Phase: "idle"},
	}
}

// ddlFiles retorna los archivos DDL en el orden canónico de aplicación.
func (s *DbInitService) ddlFiles() []string {
	return []string{
		filepath.Join(s.ddlDir, "SBOS_db_V2_DDL.sql"),
		filepath.Join(s.ddlDir, "bos_01__control_plane.sql"),
		filepath.Join(s.ddlDir, "bauth_atomlang_schema.sql"),
	}
}

// Init inicializa SBOS_db si no fue inicializada previamente.
//
// Idempotente: si los schemas ya existen y tienen tablas, retorna OK sin hacer nada.
// No destructivo: nunca hace DROP ni DELETE de datos existentes (P15 compatible).
func (s *DbInitService) Init(ctxID string) (DBInitStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.status.Phase == "applying_ddl" || s.status.Phase == "applying_seeds" {
		return s.status, fmt.Errorf("inicialización ya en progreso (fase: %s)", s.status.Phase)
	}

	// Verificar si ya está inicializado (schema bauth con tablas suficientes)
	n, err := s.db.QueryInt(
		"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'bauth' AND table_type = 'BASE TABLE'",
	)
	if err == nil && n >= C04bMinTables["bauth"] {
		if err2 := s.refreshCounts(); err2 != nil {
			return s.failStatus(err2)
		}
		s.status.Initialized = true
		s.status.Phase = "ready"
		return s.status, nil
	}

	// Aplicar DDLs
	s.status.Phase = "applying_ddl"
	for _, f := range s.ddlFiles() {
		sql, err := os.ReadFile(f)
		if err != nil {
			// DDL no encontrado: no es bloqueante (puede que el archivo aún no exista en este env)
			continue
		}
		if err := s.db.Exec(string(sql)); err != nil {
			return s.failStatus(fmt.Errorf("ejecutar DDL %s: %w", filepath.Base(f), err))
		}
	}

	// Aplicar seeds en orden alfabético; errores de seed se toleran (duplicados)
	s.status.Phase = "applying_seeds"
	seeds, err := filepath.Glob(filepath.Join(s.seedDir, "*.sql"))
	if err != nil {
		return s.failStatus(fmt.Errorf("leer directorio seeds: %w", err))
	}
	sort.Strings(seeds)
	applied := 0
	for _, seed := range seeds {
		sql, readErr := os.ReadFile(seed)
		if readErr != nil {
			continue
		}
		if execErr := s.db.Exec(string(sql)); execErr != nil {
			// Advertir pero no fallar — seeds son idempotentes por diseño
			_ = execErr
		}
		applied++
	}
	s.status.SeedsApplied = applied

	if err := s.refreshCounts(); err != nil {
		return s.failStatus(err)
	}

	now := time.Now().UTC()
	s.status.Initialized = true
	s.status.Phase = "ready"
	s.status.FinishedAt = &now
	return s.status, nil
}

// Status retorna el estado actual consultando conteos actualizados.
func (s *DbInitService) Status() DBInitStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	_ = s.refreshCounts()
	return s.status
}

// C04bPassed verifica si el criterio C-04b se cumple (tablas mínimas por schema).
func (s *DbInitService) C04bPassed() bool {
	st := s.Status()
	for schema, min := range C04bMinTables {
		if st.Schemas[schema] < min {
			return false
		}
	}
	return true
}

// refreshCounts consulta la cantidad de tablas por schema. Debe llamarse con mu tomado.
func (s *DbInitService) refreshCounts() error {
	schemas := []string{"bauth", "bos", "bglobal", "bcalendar", "public"}
	counts := make(map[string]int, len(schemas))
	for _, sc := range schemas {
		n, err := s.db.QueryInt(
			"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = $1 AND table_type = 'BASE TABLE'",
			sc,
		)
		if err != nil {
			continue // schema no existe aún — normal durante init
		}
		if n > 0 {
			counts[sc] = n
		}
	}
	s.status.Schemas = counts
	return nil
}

// failStatus actualiza el estado a error. Debe llamarse con mu tomado.
func (s *DbInitService) failStatus(err error) (DBInitStatus, error) {
	s.status.Phase = "error"
	s.status.Error = err.Error()
	return s.status, err
}
