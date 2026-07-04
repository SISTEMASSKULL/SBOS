package domain

import "time"

// SagaOutcome es el resultado de una operación saga del dominio.
// No contiene tipos del paquete installer — es independiente del protocolo.
//
// Thread safety: inmutable tras ser creado por FichaService.
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
// Thread safety: inmutable — solo lectura desde FichaService.Status().
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
// Thread safety: inmutable — solo lectura.
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
//
// Thread safety: inmutable tras ser creado por CtxService.Create().
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
	Phase       string  // "idle" | "backup" | "restore" | "sync" | "cleanup" | "error"
	Progress    float64 // 0.0 a 1.0
	CurrentStep string  // paso actual ("pg_basebackup", "pg_dump", "pg_restore", "verify")
	BytesCopied int64
	BytesTotal  int64
	StartedAt   time.Time
	Duration    time.Duration
	PodName     string // nombre del pod temporal auxiliar
	Error       string
	WALOffset   string // LSN del WAL para sincronización futura
}

// ── Tipos nuevos para Ficha Engine v2 (F11) ────────────────────────

// PlanResult es el resultado del planificador topológico de fichas.
type PlanResult struct {
	Order     []string   // orden topológico total
	Waves     [][]string // oleadas paralelizables
	Total     int        // total de fichas
	HasCycles bool       // true si hay ciclos detectados
}

// Wave representa una oleada de fichas que pueden instalarse en paralelo.
type Wave struct {
	Level    int      // profundidad (0 = sin dependencias)
	FichaIDs []string // IDs de fichas en esta oleada
}

// DiffResult representa el resultado de comparar estado declarado vs real.
type DiffResult struct {
	FichaID  string
	HasDrift bool
	Items    []DriftItem
}

// DriftItem representa un recurso con drift.
type DriftItem struct {
	Path     string // ruta del recurso
	Declared string // hash declarado (manifest)
	Actual   string // hash real (sistema)
}

// DiffSummary resume el drift de todas las fichas.
type DiffSummary struct {
	TotalFichas   int
	DriftedFichas int
	OkFichas      int
	Drifts        []DiffResult
}

// ValidationResult representa el resultado de validar un manifest.
type ValidationResult struct {
	FichaID string
	Valid   bool
	Errors  []ValidationErrorItem
}

// ValidationErrorItem representa un error de validación específico.
type ValidationErrorItem struct {
	Field   string
	Message string
	Value   string
}

// RescanResult resume el resultado de re-escanear servers/.
type RescanResult struct {
	Discovered int      // fichas nuevas encontradas
	Total      int      // total después del rescan
	Added      []string // IDs de fichas nuevas
}

// ScaleResult es el resultado de escalar una ficha.
type ScaleResult struct {
	FichaID      string
	PrevReplicas int32
	NewReplicas  int32
	Duration     time.Duration
	Success      bool
}

// LogEntry representa una línea de log de ficha.
type LogEntry struct {
	FichaID    string
	Level      string // DEBUG, INFO, WARN, ERROR
	Message    string
	Timestamp  time.Time
	LineNumber int64
}

// PgAuxiliarResult es el resultado final de una operación pg_auxiliar.
type PgAuxiliarResult struct {
	Success    bool
	Operation  string // "pg_basebackup" | "pg_dump" | "pg_restore" | "sync_wal"
	PodName    string
	Duration   time.Duration
	BytesTotal int64
	WALOffset  string
	Error      string
}
