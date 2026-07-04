// Package ficha — Manejador de estado DEGRADADA (F11.B.6).
//
// El ciclo de degradación es automático y sigue el flujo definido en ADR-021:
//
//  1. Health check falla consecutivamente (umbral configurable, default 3)
//  2. INSTALADA → DEGRADADA (estado 8)
//  3. Auto-repair inmediato (hasta MaxAttempts intentos, default 3)
//  4. Cada intento ejecuta ficha_repair() y verifica health post-reparación
//  5. Si repair OK → INSTALADA (recuperado)
//  6. Si repair falla todas las veces → ERROR_NO_CORREGIBLE → HITL (estado 12)
//
// Métricas registradas en DEGRADADA:
//   - degraded_since: timestamp de entrada en DEGRADADA
//   - repair_attempts: número de intentos ejecutados
//   - last_repair_error: último error de reparación
//   - health_check_interval: intervalo de monitoreo (default 30s)
//   - consecutive_health_fails: fallos de health consecutivos que dispararon la degradación
package ficha

import (
	"fmt"
	"strings"
	"time"

	"log/slog"
)

// ── Tipos ───────────────────────────────────────────────────────────────

// DegradedState contiene el estado detallado de una ficha en estado DEGRADADA.
// Persistido en .sbos_state.json para trazabilidad entre reinicios del daemon.
type DegradedState struct {
	FichaID                string        `json:"ficha_id"`
	DegradedSince          time.Time     `json:"degraded_since"`
	RepairAttempts         int           `json:"repair_attempts"`
	MaxAttempts            int           `json:"max_attempts"`
	LastRepairError        string        `json:"last_repair_error,omitempty"`
	LastRepairTime         time.Time     `json:"last_repair_time,omitempty"`
	HealthInterval         time.Duration `json:"health_interval"`
	ConsecutiveHealthFails int           `json:"consecutive_health_fails"`
	AutoRepairEnabled      bool          `json:"auto_repair_enabled"`
}

// ── Constantes de degradación ───────────────────────────────────────────

const (
	// DefaultDegradeThreshold es el número de health checks fallidos consecutivos
	// necesarios para degradar una ficha de INSTALADA a DEGRADADA.
	DefaultDegradeThreshold = 3
	// DefaultHealthInterval es el intervalo entre health checks en estado DEGRADADA.
	DefaultHealthInterval = 30 * time.Second
	// DefaultDegradeMaxAttempts es el número máximo de intentos de auto-reparación.
	DefaultDegradeMaxAttempts = 3
)

// ── Manejador ───────────────────────────────────────────────────────────

// DegradedHandler gestiona el ciclo de vida completo de una ficha en estado DEGRADADA:
// entrada, intentos de reparación, recuperación o escalación a HITL.
// Se crea uno por ficha degradada y persiste hasta que la ficha sale de DEGRADADA.
type DegradedHandler struct {
	state     *DegradedState
	lifecycle *Lifecycle
	logger    *slog.Logger
}

// NewDegradedHandler crea un manejador de estado degradado para una ficha específica.
// Inicializa el estado con los defaults de MaxAttempts, HealthInterval y AutoRepairEnabled.
//
// Parámetros:
//   - fichaID: identificador de la ficha a gestionar
//   - lc: orquestador de ciclo de vida (nil = crea uno por defecto)
//   - logger: logger estructurado (nil = usa slog.Default)
func NewDegradedHandler(fichaID string, lc *Lifecycle, logger *slog.Logger) *DegradedHandler {
	if lc == nil {
		lc = NewLifecycle(nil)
	}
	if logger == nil {
		logger = slog.Default()
	}
	dh := &DegradedHandler{
		lifecycle: lc,
		logger:    logger,
	}
	dh.state = &DegradedState{
		FichaID:           fichaID,
		MaxAttempts:       DefaultDegradeMaxAttempts,
		HealthInterval:    DefaultHealthInterval,
		AutoRepairEnabled: true,
	}
	return dh
}

// ── Transiciones ────────────────────────────────────────────────────────

// EnterDegraded transiciona la ficha a estado DEGRADADA.
// Registra el timestamp de entrada y el conteo de health fails que dispararon la degradación.
// Se llama cuando health check falla consecutivamente por encima del umbral.
//
// Parámetros:
//   - healthFails: número de health checks fallidos consecutivos
//   - threshold: umbral mínimo para degradar (debe ser >= healthFails)
func (dh *DegradedHandler) EnterDegraded(healthFails int, threshold int) error {
	if healthFails < threshold {
		return fmt.Errorf("no se cumplen condiciones para degradar (%d < %d fallos)", healthFails, threshold)
	}

	dh.state.DegradedSince = time.Now()
	dh.state.ConsecutiveHealthFails = healthFails

	dh.logger.Warn("ficha degradada",
		"ficha", dh.state.FichaID,
		"health_fails", healthFails,
		"threshold", threshold,
		"auto_repair", dh.state.AutoRepairEnabled,
	)

	return nil
}

// AttemptRepair ejecuta un intento de reparación desde estado DEGRADADA.
// Si el Lifecycle tiene Executor cableado, ejecuta el task_catalog.sh real.
// Si no, usa simulación determinística (éxito en 2do intento para errores de config).
//
// Parámetros:
//   - errorOutput: salida de error del último health check
//
// Retorna:
//   - bool: true si la reparación fue exitosa (ficha recuperada)
//   - FichaState: nuevo estado de la ficha (INSTALADA, REPARANDO, o ERROR_NO_CORREGIBLE)
func (dh *DegradedHandler) AttemptRepair(errorOutput string) (bool, FichaState) {
	dh.state.RepairAttempts++
	dh.state.LastRepairTime = time.Now()

	dh.logger.Info("intento de reparación desde DEGRADADA",
		"ficha", dh.state.FichaID,
		"attempt", dh.state.RepairAttempts,
		"max", dh.state.MaxAttempts,
	)

	// Diagnosticar el error actual
	diag := dh.lifecycle.Diagnose(errorOutput, "command")

	// Error no recuperable → escalar inmediatamente sin reintentar
	if !diag.Recoverable {
		dh.state.LastRepairError = fmt.Sprintf("error no recuperable: %s — %s", diag.Category, diag.Cause)
		dh.logger.Error("reparación imposible — error no recuperable",
			"ficha", dh.state.FichaID,
			"cause", diag.Cause,
		)
		return false, StateErrorNoCorregible
	}

	// Intentar reparación: Executor real o simulación
	var repairOK bool
	if dh.lifecycle.HasExecutor() {
		taskDir := dh.lifecycle.resolveTaskDir(dh.state.FichaID)
		if taskDir != "" {
			execResult, err := dh.lifecycle.exec.Execute(dh.state.FichaID, "repair", taskDir)
			if err != nil {
				dh.state.LastRepairError = fmt.Sprintf("repair: %v", err)
			} else {
				repairOK = execResult.Success
				if !repairOK {
					dh.state.LastRepairError = execResult.Error
				}
			}
		} else {
			dh.state.LastRepairError = "taskDir no encontrado para reparación"
		}
	} else {
		// Simulación: éxito en 2do intento para errores de configuración recuperables
		repairOK = dh.state.RepairAttempts >= 2 && diag.Category == ErrLogical &&
			containsAny(strings.ToLower(errorOutput), "config")
		if !repairOK {
			dh.state.LastRepairError = fmt.Sprintf("intento %d fallido", dh.state.RepairAttempts)
		}
	}

	if repairOK {
		dh.logger.Info("reparación exitosa — ficha recuperada",
			"ficha", dh.state.FichaID,
			"attempt", dh.state.RepairAttempts,
		)
		return true, StateInstalada
	}

	// Falló — ¿quedan reintentos disponibles?
	if dh.state.RepairAttempts >= dh.state.MaxAttempts {
		dh.state.LastRepairError = fmt.Sprintf("agotados %d intentos de reparación", dh.state.RepairAttempts)
		dh.logger.Error("reparación agotada — escalando a HITL",
			"ficha", dh.state.FichaID,
			"attempts", dh.state.RepairAttempts,
		)
		return false, StateErrorNoCorregible
	}

	return false, StateReparando
}

// Recover transiciona de DEGRADADA a INSTALADA tras reparación exitosa.
// Registra la duración total en DEGRADADA y el número de intentos necesarios.
func (dh *DegradedHandler) Recover() FichaState {
	dh.logger.Info("ficha recuperada de DEGRADADA",
		"ficha", dh.state.FichaID,
		"degraded_duration", time.Since(dh.state.DegradedSince).Round(time.Second),
		"repair_attempts", dh.state.RepairAttempts,
	)
	return StateInstalada
}

// Escalate escala a HITL cuando la reparación agota todos los reintentos.
// Delega en Lifecycle.EscalateToHITL con el contexto del manejador.
func (dh *DegradedHandler) Escalate(diag ErrorDiagnosis) HITLRequest {
	return dh.lifecycle.EscalateToHITL(
		dh.state.FichaID,
		diag,
		dh.state.RepairAttempts,
		dh.state.MaxAttempts,
	)
}

// ── Consultas ───────────────────────────────────────────────────────────

// ShouldRetry retorna true si todavía hay reintentos de reparación disponibles.
func (dh *DegradedHandler) ShouldRetry() bool {
	return dh.state.RepairAttempts < dh.state.MaxAttempts
}

// RemainingAttempts retorna el número de reintentos de reparación restantes.
// Si ya se excedió el máximo, retorna 0.
func (dh *DegradedHandler) RemainingAttempts() int {
	remaining := dh.state.MaxAttempts - dh.state.RepairAttempts
	if remaining < 0 {
		return 0
	}
	return remaining
}

// State retorna el estado interno del manejador (referencia solo-lectura).
func (dh *DegradedHandler) State() *DegradedState {
	return dh.state
}

// DegradedDuration retorna cuánto tiempo lleva la ficha en estado DEGRADADA.
// Si la ficha nunca entró en DEGRADADA (DegradedSince es zero), retorna 0.
func (dh *DegradedHandler) DegradedDuration() time.Duration {
	if dh.state.DegradedSince.IsZero() {
		return 0
	}
	return time.Since(dh.state.DegradedSince)
}
