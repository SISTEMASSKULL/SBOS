// Package domain — Adaptadores de infraestructura para DbInitService.
//
// PgExecAdapter: implementación real usando lib/pq (producción).
// MemDBExec:     implementación en memoria (tests, modo dev sin BD).
package domain

import (
	"database/sql"
	"fmt"
	"strings"
	"sync"

	_ "github.com/lib/pq"
)

// ── PgExecAdapter ────────────────────────────────────────────────────────────

// PgExecAdapter implementa DBExecPort sobre una conexión PostgreSQL real (lib/pq).
// DSN se pasa en la construcción; se toma de BOS_PG_DSN en producción.
type PgExecAdapter struct {
	db *sql.DB
}

// NewPgExecAdapter abre una conexión PostgreSQL usando el DSN dado.
//
// Caller: internal/server, cmd/bos/main.go — inyectado en DbInitService.
func NewPgExecAdapter(dsn string) (*PgExecAdapter, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("abrir conexión PG: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping PG (dsn invalido o BD no responde): %w", err)
	}
	db.SetMaxOpenConns(3)
	db.SetMaxIdleConns(1)
	return &PgExecAdapter{db: db}, nil
}

// Exec ejecuta una o más sentencias SQL. Errores de "ya existe" se toleran.
func (a *PgExecAdapter) Exec(sqlStr string) error {
	_, err := a.db.Exec(sqlStr)
	if err != nil && isDuplicateError(err) {
		return nil
	}
	return err
}

// ExecStrict ejecuta SQL y falla ante cualquier error (incluyendo duplicados).
func (a *PgExecAdapter) ExecStrict(sqlStr string) error {
	_, err := a.db.Exec(sqlStr)
	return err
}

// QueryInt ejecuta un query de una fila/columna integer.
func (a *PgExecAdapter) QueryInt(query string, args ...interface{}) (int, error) {
	var n int
	if err := a.db.QueryRow(query, args...).Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}

// SchemaExists retorna true si el schema existe en la BD.
func (a *PgExecAdapter) SchemaExists(schema string) (bool, error) {
	n, err := a.QueryInt(
		"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = $1",
		schema,
	)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// Close cierra la conexión subyacente.
func (a *PgExecAdapter) Close() error {
	return a.db.Close()
}

// isDuplicateError retorna true si el error es un "ya existe" de PostgreSQL.
func isDuplicateError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "already exists") ||
		strings.Contains(msg, "duplicate key") ||
		strings.Contains(msg, "unique constraint")
}

// ── MemDBExec ────────────────────────────────────────────────────────────────

// MemDBExec implementa DBExecPort en memoria para tests.
//
// Permite verificar qué SQL se ejecutó sin necesitar una BD real.
type MemDBExec struct {
	mu       sync.Mutex
	Executed []string        // todas las sentencias ejecutadas en orden
	Counts   map[string]int  // schema → n para QueryInt (configurable en test)
	Schemas  map[string]bool // schemas que "existen"
	FailOn   string          // si != "", falla en Exec si el SQL contiene esta cadena
}

// NewMemDBExec crea un MemDBExec vacío listo para usar en tests.
func NewMemDBExec() *MemDBExec {
	return &MemDBExec{
		Counts:  make(map[string]int),
		Schemas: make(map[string]bool),
	}
}

func (m *MemDBExec) Exec(sqlStr string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.FailOn != "" && strings.Contains(sqlStr, m.FailOn) {
		return fmt.Errorf("MemDBExec: fallo simulado en '%s'", m.FailOn)
	}
	m.Executed = append(m.Executed, sqlStr)
	return nil
}

func (m *MemDBExec) ExecStrict(sqlStr string) error {
	return m.Exec(sqlStr)
}

func (m *MemDBExec) QueryInt(query string, args ...interface{}) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	// Detectar schema del query para retornar el conteo configurado
	for schema, n := range m.Counts {
		if strings.Contains(query, "'"+schema+"'") ||
			(len(args) > 0 && fmt.Sprintf("%v", args[0]) == schema) {
			return n, nil
		}
	}
	return 0, nil
}

func (m *MemDBExec) SchemaExists(schema string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.Schemas[schema], nil
}
