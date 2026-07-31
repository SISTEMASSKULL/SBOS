// Kardex — CRUD sobre bos.prt_port_assignment (T-408, SBOS-050).
//
// Inmutabilidad lógica: las filas nunca se borran.
// El estado transiciona: assigned → released → revoked.
// Consulta y escritura se hacen via la interfaz KardexPort para
// facilitar tests sin base de datos real.
package portman

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
)

// KardexRow es la representación en memoria de una fila de bos.prt_port_assignment.
type KardexRow struct {
	PortID         string
	ServiceName    string
	Port           int
	Transport      string
	PortType       string
	LogicalServer  string
	Namespace      string
	FichaID        string
	AssignedBy     string
	Description    string
	DocReference   string
	Status         string
	Algorithm      string
	AssignedAt     time.Time
	ReleasedAt     *time.Time
	LastValidatedAt *time.Time
	CtxID          string
}

// KardexPort define las operaciones del Kardex que el motor necesita.
// Implementado por PgKardex para producción; por MockKardex en tests.
type KardexPort interface {
	ExistsActive(port int, portType, namespace string) (bool, error)
	Insert(row KardexRow) error
	SetStatus(portID, status string, releasedAt *time.Time) error
	ListByFicha(fichaID string) ([]KardexRow, error)
	ListAll(limit int) ([]KardexRow, error)
	GetByPort(port int, portType, namespace string) (*KardexRow, error)
	Close() error
}

// PgKardex implementa KardexPort sobre PostgreSQL (bos.prt_port_assignment).
type PgKardex struct {
	db *sql.DB
}

// NewPgKardex abre la conexión al Kardex usando el DSN dado.
func NewPgKardex(dsn string) (*PgKardex, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("kardex: abrir conexión: %w", err)
	}
	db.SetMaxOpenConns(4)
	db.SetMaxIdleConns(2)
	db.SetConnMaxLifetime(5 * time.Minute)
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("kardex: ping: %w", err)
	}
	return &PgKardex{db: db}, nil
}

// Close cierra la conexión de base de datos.
func (k *PgKardex) Close() error { return k.db.Close() }

// ExistsActive retorna true si ya hay un registro assigned para (port, port_type, namespace).
// Verifica la restricción UNIQUE(port, port_type, namespace) del Kardex.
func (k *PgKardex) ExistsActive(port int, portType, namespace string) (bool, error) {
	var count int
	err := k.db.QueryRow(`
		SELECT COUNT(*) FROM bos.prt_port_assignment
		WHERE port = $1 AND port_type = $2 AND namespace = $3 AND status = 'assigned'
	`, port, portType, namespace).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("kardex existsActive: %w", err)
	}
	return count > 0, nil
}

// Insert registra una nueva asignación de puerto en el Kardex.
// La fila se crea con status='assigned'. Nunca se actualiza ni borra.
func (k *PgKardex) Insert(row KardexRow) error {
	_, err := k.db.Exec(`
		INSERT INTO bos.prt_port_assignment (
			service_name, port, transport, port_type,
			logical_server, namespace, ficha_id, assigned_by,
			description, doc_reference, algorithm, status,
			assigned_at, ctx_id
		) VALUES (
			$1, $2, $3, $4,
			$5, $6, $7, $8,
			$9, $10, $11, 'assigned',
			NOW(), $12
		)`,
		row.ServiceName, row.Port, row.Transport, row.PortType,
		row.LogicalServer, row.Namespace, row.FichaID, row.AssignedBy,
		row.Description, row.DocReference, row.Algorithm,
		row.CtxID,
	)
	if err != nil {
		return fmt.Errorf("kardex insert puerto %d: %w", row.Port, err)
	}
	return nil
}

// SetStatus transiciona el estado de una fila (assigned → released → revoked).
// No permite borrar; solo transicionar. Inmutabilidad lógica garantizada.
func (k *PgKardex) SetStatus(portID, status string, releasedAt *time.Time) error {
	validStatuses := map[string]bool{"released": true, "revoked": true}
	if !validStatuses[status] {
		return fmt.Errorf("kardex: estado inválido %q (permitidos: released, revoked)", status)
	}

	var err error
	if releasedAt != nil {
		_, err = k.db.Exec(`
			UPDATE bos.prt_port_assignment
			SET status = $1, released_at = $2
			WHERE port_id = $3
		`, status, releasedAt, portID)
	} else {
		_, err = k.db.Exec(`
			UPDATE bos.prt_port_assignment
			SET status = $1
			WHERE port_id = $2
		`, status, portID)
	}
	if err != nil {
		return fmt.Errorf("kardex setStatus %s → %s: %w", portID, status, err)
	}
	return nil
}

// ListByFicha retorna todas las asignaciones (activas o no) de una ficha.
func (k *PgKardex) ListByFicha(fichaID string) ([]KardexRow, error) {
	rows, err := k.db.Query(`
		SELECT
			port_id::text, service_name, port, transport, port_type,
			COALESCE(logical_server,''), namespace, COALESCE(ficha_id,''),
			COALESCE(assigned_by,''), COALESCE(description,''),
			COALESCE(doc_reference,''), status,
			COALESCE(algorithm,'A'), assigned_at,
			released_at, last_validated_at, ctx_id
		FROM bos.prt_port_assignment
		WHERE ficha_id = $1
		ORDER BY assigned_at DESC
	`, fichaID)
	if err != nil {
		return nil, fmt.Errorf("kardex listByFicha: %w", err)
	}
	defer rows.Close()
	return scanRows(rows)
}

// ListAll retorna todas las asignaciones del Kardex (para export/audit).
func (k *PgKardex) ListAll(limit int) ([]KardexRow, error) {
	if limit <= 0 {
		limit = 500
	}
	rows, err := k.db.Query(`
		SELECT
			port_id::text, service_name, port, transport, port_type,
			COALESCE(logical_server,''), namespace, COALESCE(ficha_id,''),
			COALESCE(assigned_by,''), COALESCE(description,''),
			COALESCE(doc_reference,''), status,
			COALESCE(algorithm,'A'), assigned_at,
			released_at, last_validated_at, ctx_id
		FROM bos.prt_port_assignment
		ORDER BY assigned_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, fmt.Errorf("kardex listAll: %w", err)
	}
	defer rows.Close()
	return scanRows(rows)
}

// GetByPort retorna la fila activa para (port, port_type, namespace), si existe.
func (k *PgKardex) GetByPort(port int, portType, namespace string) (*KardexRow, error) {
	row := k.db.QueryRow(`
		SELECT
			port_id::text, service_name, port, transport, port_type,
			COALESCE(logical_server,''), namespace, COALESCE(ficha_id,''),
			COALESCE(assigned_by,''), COALESCE(description,''),
			COALESCE(doc_reference,''), status,
			COALESCE(algorithm,'A'), assigned_at,
			released_at, last_validated_at, ctx_id
		FROM bos.prt_port_assignment
		WHERE port = $1 AND port_type = $2 AND namespace = $3 AND status = 'assigned'
		LIMIT 1
	`, port, portType, namespace)

	rows := &sql.Rows{}
	_ = rows
	return scanRow(row)
}

// scanRows convierte filas SQL en KardexRow.
func scanRows(rows *sql.Rows) ([]KardexRow, error) {
	var result []KardexRow
	for rows.Next() {
		r, err := scanSQLRow(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, r)
	}
	return result, rows.Err()
}

// rowScanner abstrae *sql.Row y *sql.Rows para el mismo scanner.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanRow(r rowScanner) (*KardexRow, error) {
	row := KardexRow{}
	var relAt, valAt *time.Time
	err := r.Scan(
		&row.PortID, &row.ServiceName, &row.Port, &row.Transport, &row.PortType,
		&row.LogicalServer, &row.Namespace, &row.FichaID,
		&row.AssignedBy, &row.Description, &row.DocReference, &row.Status,
		&row.Algorithm, &row.AssignedAt,
		&relAt, &valAt, &row.CtxID,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("kardex scan: %w", err)
	}
	row.ReleasedAt = relAt
	row.LastValidatedAt = valAt
	return &row, nil
}

func scanSQLRow(rows *sql.Rows) (KardexRow, error) {
	row := KardexRow{}
	var relAt, valAt *time.Time
	err := rows.Scan(
		&row.PortID, &row.ServiceName, &row.Port, &row.Transport, &row.PortType,
		&row.LogicalServer, &row.Namespace, &row.FichaID,
		&row.AssignedBy, &row.Description, &row.DocReference, &row.Status,
		&row.Algorithm, &row.AssignedAt,
		&relAt, &valAt, &row.CtxID,
	)
	if err != nil {
		return KardexRow{}, fmt.Errorf("kardex scanRow: %w", err)
	}
	row.ReleasedAt = relAt
	row.LastValidatedAt = valAt
	return row, nil
}
