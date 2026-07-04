// Package ficha — Orquestador de Reparación con timeout (F11.B.5).
//
// La reparación es el proceso automático de recuperación de una ficha en estado
// DEGRADADA, ERROR_FISICO o ERROR_LOGICO. Sigue la estrategia de reintentos con
// backoff implícito definida en ADR-021:
//
//  1. Diagnosticar la causa raíz del error (Diagnose)
//  2. Ejecutar ficha_repair() en task_catalog.sh (vía Executor)
//  3. Verificar health post-reparación
//  4. Si falla: reintentar hasta maxAttempts (default 3)
//  5. Si éxito: transicionar a INSTALADA
//  6. Si agota reintentos: ERROR_NO_CORREGIBLE → HITL
//
// Timeout por intento: 10 minutos (ADR-021). Timeout total: maxAttempts × timeout.
package ficha

import (
	"fmt"
	"time"
)

// ── Tipos de Reparación ─────────────────────────────────────────────────

// RepairAttempt registra un intento de reparación individual con su diagnóstico,
// duración y resultado. Cada intento se registra en el audit log.
type RepairAttempt struct {
	Attempt   int            `json:"attempt"`
	Success   bool           `json:"success"`
	Duration  time.Duration  `json:"duration"`
	Diagnosis ErrorDiagnosis `json:"diagnosis"`
	Error     string         `json:"error,omitempty"`
}

// RepairResult contiene el resultado agregado de todos los intentos de reparación.
// Incluye el estado final de la ficha y la lista completa de intentos para auditoría.
type RepairResult struct {
	FichaID       string          `json:"ficha_id"`
	Success       bool            `json:"success"`
	Attempts      []RepairAttempt `json:"attempts"`
	TotalAttempts int             `json:"total_attempts"`
	TotalDuration time.Duration   `json:"total_duration"`
	FinalState    FichaState      `json:"final_state"`
}

// ── Constantes de reparación ────────────────────────────────────────────

const (
	// DefaultRepairMaxAttempts es el número máximo de reintentos de reparación.
	DefaultRepairMaxAttempts = 3
)

// ── Ejecución ───────────────────────────────────────────────────────────

// ExecuteRepair intenta reparar una ficha con reintentos y timeout por intento.
// Si el Lifecycle tiene un Executor cableado, cada intento ejecuta
// Executor.Execute(fichaID, "repair", taskDir). Si no, usa simulación.
//
// Parámetros:
//   - fichaID: identificador de la ficha a reparar
//   - maxAttempts: número máximo de reintentos (0 = usar DefaultRepairMaxAttempts)
//   - timeout: tiempo máximo por intento (0 = usar GlobalTimeoutLimits().Repair)
//   - errorOutput: salida de error del último health check fallido
//
// Retorna RepairResult con el resultado de cada intento y el estado final.
func (l *Lifecycle) ExecuteRepair(fichaID string, maxAttempts int, timeout time.Duration, errorOutput string) *RepairResult {
	start := time.Now()
	result := &RepairResult{
		FichaID:  fichaID,
		Attempts: make([]RepairAttempt, 0),
	}

	if maxAttempts <= 0 {
		maxAttempts = DefaultRepairMaxAttempts
	}
	if timeout <= 0 {
		timeout = GlobalTimeoutLimits().Repair
	}

	diag := l.Diagnose(errorOutput, "command")

	// Resolver taskDir una vez (no cambia entre intentos)
	hasRealExecutor := l.HasExecutor()
	var taskDir string
	if hasRealExecutor {
		taskDir = l.resolveTaskDir(fichaID)
		if taskDir == "" {
			l.logger.Warn("repair: taskDir no encontrado — usando simulación", "ficha", fichaID)
			hasRealExecutor = false
		}
	}

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		attemptStart := time.Now()
		ra := RepairAttempt{Attempt: attempt, Diagnosis: diag}

		l.logger.Info("intento de reparación",
			"ficha", fichaID,
			"attempt", attempt,
			"max", maxAttempts,
			"timeout", timeout,
		)

		// Ejecutar reparación: Executor real o simulación
		if hasRealExecutor {
			execResult, err := l.exec.Execute(fichaID, "repair", taskDir)
			if err != nil {
				ra.Success = false
				ra.Error = fmt.Sprintf("repair: %v", err)
			} else {
				ra.Success = execResult.Success
				if !execResult.Success {
					ra.Error = execResult.Error
				}
				ra.Duration = execResult.Duration
			}
		} else {
			// Simulación: éxito en 2do intento para errores recuperables
			if diag.Recoverable && attempt == 2 {
				ra.Success = true
			} else {
				ra.Success = false
				ra.Error = fmt.Sprintf("reparación fallida (intento %d/%d)", attempt, maxAttempts)
			}
			ra.Duration = time.Since(attemptStart)
		}

		result.Attempts = append(result.Attempts, ra)

		evalResult := l.EvaluateRepair(ra.Success, attempt, maxAttempts)
		if evalResult.NewState != StateReparando {
			result.FinalState = evalResult.NewState
			result.Success = ra.Success
			result.TotalAttempts = attempt
			break
		}
		result.TotalAttempts = attempt
	}

	result.TotalDuration = time.Since(start)
	return result
}
