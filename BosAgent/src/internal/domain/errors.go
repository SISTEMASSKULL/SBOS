// Package domain implementa la capa de negocio del IAM Installer BOS.
// ORQUESTA-043 §2 — Capa de Dominio: completamente independiente de HTTP,
// JSON-RPC y cualquier protocolo de transporte.
//
// Los handlers RPC son adaptadores delgados:
//
//	parseParams → llamar servicio de dominio → adaptar resultado a RPCResponse
package domain

import "errors"

// Errores de dominio — sin códigos JSON-RPC, sin dependencias de servidor.
// El handler RPC mapea estos errores a códigos de error JSON-RPC.
var (
	ErrFichaIDRequired      = errors.New("ficha_id requerido")
	ErrVersionRequired      = errors.New("version requerida")
	ErrCommandRequired      = errors.New("command requerido")
	ErrFichaNotFound        = errors.New("ficha no encontrada")
	ErrInstallerUnavailable = errors.New("installer no disponible")
	ErrStateUnavailable     = errors.New("estado del sistema no disponible")
	ErrBootstrapInProgress  = errors.New("bootstrap ya en progreso")
	ErrCommandInvalid       = errors.New("command inválido: usar install|update|repair|remove|probe")
	ErrSagaFailed           = errors.New("saga falló")
	ErrTraceparentRequired  = errors.New("traceparent requerido")
	ErrTenantIDRequired     = errors.New("tenant_id requerido")

	// ── PG Auxiliar Anti-Pérdida ─────────────────────────────────
	ErrPgAuxiliarInProgress = errors.New("pg_auxiliar ya en progreso")
	ErrPgAuxiliarNotReady   = errors.New("pg_auxiliar no disponible — ejecute backup primero")
	ErrPgAuxiliarNoSource   = errors.New("pg_auxiliar: no hay PG principal disponible como fuente")

	// ── Ficha Engine v2 (F11) ──────────────────────────────────────
	ErrFichaNotScalable     = errors.New("ficha no soporta escalado")
	ErrFichaAlreadyPaused   = errors.New("ficha ya está pausada")
	ErrFichaNotPaused       = errors.New("ficha no está pausada")
	ErrFichaHasDependents   = errors.New("ficha tiene dependientes — remueva primero")
	ErrFichaManifestInvalid = errors.New("manifest.yml inválido")
	ErrFichaPlanFailed      = errors.New("planificación topológica falló")
	ErrFichaDriftDetected   = errors.New("drift detectado")
	ErrReplicasInvalidas    = errors.New("número de réplicas inválido — debe ser >= 0")
)

// IsFichaNotFound reporta si el error es ErrFichaNotFound (útil para mapeo a HTTP 404 / RPC -32001).
func IsFichaNotFound(err error) bool { return errors.Is(err, ErrFichaNotFound) }

// IsSagaFailed reporta si el error es ErrSagaFailed.
func IsSagaFailed(err error) bool { return errors.Is(err, ErrSagaFailed) }

// IsBootstrapInProgress reporta si el error es ErrBootstrapInProgress.
func IsBootstrapInProgress(err error) bool { return errors.Is(err, ErrBootstrapInProgress) }

// SagaError wraps saga failure with structured context for the caller.
// Distinct from ErrSagaFailed: carries exit code and failed steps.
type SagaError struct {
	Command     string
	ExitCode    int
	FailedSteps interface{} // []installer.Step — interface para evitar import circular
}

func (e *SagaError) Error() string {
	return ErrSagaFailed.Error() + ": command=" + e.Command
}

func (e *SagaError) Unwrap() error { return ErrSagaFailed }
