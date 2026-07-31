// Package ficha — Clasificación de errores del ciclo de vida (F11.B.4).
//
// Diagnose analiza el output de error de un task_catalog.sh y clasifica la causa raíz
// usando heurísticas de keywords. Las categorías determinan la estrategia de reparación:
//   - ErrPhysical  → reparar infraestructura (disco, red, CPU, memoria)
//   - ErrLogical   → reparar configuración (dependencias, schema, permisos)
//   - ErrUnknown   → requiere investigación manual
//
// Cada diagnóstico incluye una acción de reparación sugerida (RepairAction)
// que guía al repair manager en la selección de la estrategia.
package ficha

import (
	"fmt"
	"strings"
	"time"
)

// ── Categorías de error ────────────────────────────────────────────────

// ErrorCategory clasifica la causa raíz de un error detectado en el ciclo de vida.
// La categoría determina la estrategia de reparación y el estado resultante:
//   - ErrPhysical → ERROR_FISICO → RepairAction de infraestructura
//   - ErrLogical  → ERROR_LOGICO  → RepairAction de configuración
//   - ErrUnknown  → requiere investigación manual (HITL)
type ErrorCategory string

const (
	ErrPhysical ErrorCategory = "physical" // disco, red, CPU, memoria — infraestructura
	ErrLogical  ErrorCategory = "logical"  // config, dependencias, schema drift — aplicación
	ErrUnknown  ErrorCategory = "unknown"  // no se pudo determinar — requiere HITL
)

// ErrorDiagnosis contiene el resultado de diagnosticar un error del ciclo de vida.
// Incluye la categoría, causa raíz, acción de reparación sugerida y si es recuperable.
type ErrorDiagnosis struct {
	Category     ErrorCategory `json:"category"`
	Cause        string        `json:"cause"`
	Detail       string        `json:"detail"`
	Recoverable  bool          `json:"recoverable"`
	RepairAction string        `json:"repair_action,omitempty"`
}

// Diagnose analiza el output de error de un task_catalog.sh y determina la causa raíz.
// Usa heurísticas de keywords para clasificar el error en físico, lógico o desconocido.
// Parámetros:
//   - errorOutput: salida stderr/stdout del comando fallido
//   - healthType: tipo de health check que detectó el error (para contexto)
//
// Retorna un ErrorDiagnosis con categoría, causa, acción sugerida y flag de recuperabilidad.
func (l *Lifecycle) Diagnose(errorOutput string, healthType string) ErrorDiagnosis {
	diag := ErrorDiagnosis{Recoverable: true}

	lower := strings.ToLower(errorOutput)

	switch {
	// ── Errores físicos (infraestructura) ──────────────────────────
	case containsAny(lower, "no space left", "disk full", "io error", "read-only"):
		diag.Category = ErrPhysical
		diag.Cause = "disco lleno o error de I/O"
		diag.Recoverable = true
		diag.RepairAction = "liberar espacio en disco, verificar volume mounts"

	case containsAny(lower, "connection refused", "no route to host", "network",
		"dns", "timeout", "dial tcp", "connect:"):
		diag.Category = ErrPhysical
		diag.Cause = "error de red o conectividad"
		diag.Recoverable = true
		diag.RepairAction = "verificar NetworkPolicy, DNS, y conectividad del pod"

	case containsAny(lower, "out of memory", "oom", "killed", "memory limit"):
		diag.Category = ErrPhysical
		diag.Cause = "memoria insuficiente"
		diag.Recoverable = true
		diag.RepairAction = "aumentar memory limits, verificar memory leaks"

	case containsAny(lower, "cpu throttl", "cpu limit"):
		diag.Category = ErrPhysical
		diag.Cause = "CPU throttling"
		diag.Recoverable = true
		diag.RepairAction = "aumentar CPU limits, verificar CPU usage anómalo"

	// ── Errores lógicos (aplicación/configuración) ─────────────────
	case containsAny(lower, "config", "configuration", "syntax error", "invalid",
		"malformed", "yaml:", "json:"):
		diag.Category = ErrLogical
		diag.Cause = "error de configuración"
		diag.RepairAction = "revisar manifest.yml y yaml_engine.yml, validar sintaxis"

	case containsAny(lower, "dependency", "missing", "not found", "no such file",
		"cannot find", "unresolved"):
		diag.Category = ErrLogical
		diag.Cause = "dependencia faltante o archivo no encontrado"
		diag.RepairAction = "verificar dependencias declaradas en manifest.yml"

	case containsAny(lower, "permission denied", "access denied", "forbidden",
		"unauthorized", "rbac"):
		diag.Category = ErrLogical
		diag.Cause = "error de permisos o RBAC"
		diag.Recoverable = true
		diag.RepairAction = "revisar ClusterRole, ServiceAccount y RBAC"

	case containsAny(lower, "schema", "migration", "column", "table", "relation",
		"constraint", "foreign key"):
		diag.Category = ErrLogical
		diag.Cause = "schema drift o error de base de datos"
		diag.Recoverable = true
		diag.RepairAction = "ejecutar migración SQL, verificar DDL"

	case containsAny(lower, "segfault", "panic", "fatal error", "core dump",
		"abort", "sigsegv", "sigabrt"):
		diag.Category = ErrLogical
		diag.Cause = "crash de la aplicación (segfault/panic)"
		diag.Recoverable = false // requiere investigación del desarrollador
		diag.RepairAction = "analizar core dump, verificar versión de la imagen"

	default:
		diag.Category = ErrUnknown
		diag.Cause = "causa no determinada — requiere investigación manual"
		diag.Recoverable = true
		diag.RepairAction = "revisar logs completos, ejecutar ficha_repair()"
	}

	if !diag.Recoverable {
		l.logger.Error("error no recuperable detectado",
			"category", diag.Category,
			"cause", diag.Cause,
		)
	}

	return diag
}

// ClassifyState determina el FichaState correspondiente a un diagnóstico de error.
// Mapea ErrorCategory a FichaState según ADR-021:
//   - ErrPhysical → ERROR_FISICO (estado 9)
//   - ErrLogical  → ERROR_LOGICO  (estado 10)
//   - ErrUnknown  → ERROR_LOGICO  (por defecto, más seguro — reparable)
func (l *Lifecycle) ClassifyState(diag ErrorDiagnosis) FichaState {
	switch diag.Category {
	case ErrPhysical:
		return StatePhysicalError
	case ErrLogical:
		return StateLogicalError
	default:
		return StateLogicalError
	}
}

// ── HITL Escalation ─────────────────────────────────────────────────────

// HITLRequest representa una solicitud de intervención humana (Human-In-The-Loop).
// Se genera cuando la reparación automática agota todos los reintentos configurados
// y la ficha entra en estado ERROR_NO_CORREGIBLE (estado 12, ADR-021).
type HITLRequest struct {
	FichaID     string        `json:"ficha_id"`
	State       FichaState    `json:"state"`
	Diagnosis   ErrorDiagnosis `json:"diagnosis"`
	Attempts    int           `json:"attempts"`
	MaxAttempts int           `json:"max_attempts"`
	Reason      string        `json:"reason"`
	Timestamp   time.Time     `json:"timestamp"`
}

// EscalateToHITL genera una solicitud de intervención humana cuando la reparación
// automática agota los reintentos sin éxito. Registra el evento como ERROR y
// construye el mensaje de razón con el diagnóstico más reciente.
//
// Parámetros:
//   - fichaID: identificador de la ficha
//   - diag: diagnóstico del último intento fallido
//   - attempts: intentos ejecutados
//   - maxAttempts: máximo de reintentos configurado
func (l *Lifecycle) EscalateToHITL(fichaID string, diag ErrorDiagnosis, attempts, maxAttempts int) HITLRequest {
	req := HITLRequest{
		FichaID:     fichaID,
		State:       StateUnrecoverable,
		Diagnosis:   diag,
		Attempts:    attempts,
		MaxAttempts: maxAttempts,
		Reason:      fmt.Sprintf("%d intentos de reparación fallidos. Último diagnóstico: %s — %s", attempts, diag.Category, diag.Cause),
		Timestamp:   time.Now(),
	}

	l.logger.Error("🚨 HITL REQUERIDO",
		"ficha", fichaID,
		"attempts", attempts,
		"cause", diag.Cause,
		"recoverable", diag.Recoverable,
	)

	// TODO(ctx-plane): persistir HITL request en bkernel_db cuando F5 esté operativo
	// TODO(F11.F.5): requerir confirmación de 2 administradores (governance dual-control)

	return req
}

// IsRecoverableError retorna true si el error tiene solución automática
// sin requerir intervención humana directa.
func (l *Lifecycle) IsRecoverableError(diag ErrorDiagnosis) bool {
	return diag.Recoverable
}
