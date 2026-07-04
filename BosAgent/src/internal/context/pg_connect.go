package context

// pg_connect.go — abre la conexión PostgreSQL para el Context Plane.
//
// Usa database/sql con el driver lib/pq. BOS no requiere ORM — queries
// directas con placeholders $1, $2 (PostgreSQL nativo).

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq" // registra el driver "postgres" en database/sql
)

// openPostgres abre una conexión *sql.DB a PostgreSQL y verifica conectividad.
// dsn: cadena de conexión libpq (ej: "postgres://user:pass@host:5432/db?sslmode=disable").
func openPostgres(dsn string) (*sql.DB, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("sql.Open postgres: %w", err)
	}
	db.SetMaxOpenConns(5)
	db.SetMaxIdleConns(2)
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("postgres ping: %w", err)
	}
	return db, nil
}
