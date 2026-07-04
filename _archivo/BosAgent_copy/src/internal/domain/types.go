package domain

import "time"

// SagaOutcome es el resultado de una operación saga del dominio.
// No contiene tipos del paquete installer — es independiente del protocolo.
type SagaOutcome struct {
	FichaID     string
	Command     string
	Success     bool
	ExitCode    int
	Duration    time.Duration
	StepCount   int
	FailedSteps interface{} // []installer.Step — opaco al dominio
}

// FichaInfo describe el estado de una ficha en el sistema.
type FichaInfo struct {
	ID          string
	State       string
	Version     string
	Health      string
	Server      string
	InstalledAt time.Time
	UpdatedAt   time.Time
}

// FichaDetail extiende FichaInfo con metadatos del catálogo (manifest).
type FichaDetail struct {
	FichaInfo
	AutoInstall    bool
	ExecutionOrder int
	Dependencies   []string
}

// BootstrapStatus resume el estado actual del proceso de bootstrap.
type BootstrapStatus struct {
	Progress    float64
	Total       int
	Completados int
	Instalando  int
	Alerta      int
	Pendientes  int
	Bloqueadas  int
}

// CertCriterion es un criterio de certificación del Operador (C-01..C-08).
type CertCriterion struct {
	ID      string
	Nombre  string
	OK      bool
	Detalle string
}

// VerifyResult es el resultado de verificar los criterios de certificación.
type VerifyResult struct {
	Criterios []CertCriterion
	Passed    int
	Total     int
	Certified bool
	Timestamp time.Time
}

// CtxID es la estructura del Context Plane (SBOS-049).
// W3C Trace Context + campos SBOS.
type CtxID struct {
	TenantID    string
	EmpresaID   string
	SucursalID  string
	PosLogico   string
	UserID      string
	TraceParent string // W3C Trace Context: 00-traceId-spanId-flags
	SpanID      string
	CreatedAt   time.Time
	ExpiresAt   time.Time
	Source      string
}

// ValidateResult es el resultado de validar un traceparent W3C.
type ValidateResult struct {
	Valid       bool
	TraceParent string
	TenantID    string
}

// BootstrapStartResult es el resultado de iniciar el bootstrap.
type BootstrapStartResult struct {
	BootstrapID string
	Mode        string
	Total       int
	Completados int
}

// ── PG Auxiliar Anti-Pérdida (SBOS-BOOTSTRAP-MANUAL Parte V-B) ──────

// PgAuxiliarStatus representa el estado en tiempo real de la operación
// del PostgreSQL auxiliar anti-pérdida.
type PgAuxiliarStatus struct {
	Phase       string        // "idle" | "backup" | "restore" | "sync" | "cleanup" | "error"
	Progress    float64       // 0.0 a 1.0
	CurrentStep string        // paso actual ("pg_basebackup", "pg_dump", "pg_restore", "verify")
	BytesCopied int64
	BytesTotal  int64
	StartedAt   time.Time
	Duration    time.Duration
	PodName     string        // nombre del pod temporal auxiliar
	Error       string
	WALOffset   string        // LSN del WAL para sincronización futura
}

// PgAuxiliarResult es el resultado final de una operación pg_auxiliar.
type PgAuxiliarResult struct {
	Success    bool
	Operation  string        // "pg_basebackup" | "pg_dump" | "pg_restore" | "sync_wal"
	PodName    string
	Duration   time.Duration
	BytesTotal int64
	WALOffset  string
	Error      string
}
