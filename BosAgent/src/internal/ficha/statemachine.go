// Package ficha — Máquina de 18 estados (F11.B.1-B.6).
// BOS-REPAIR Plan Maestro v3 · ADR-021.
//
// Cada ficha transita por hasta 18 estados durante su ciclo de vida.
// Esta máquina de estados es la capa de lógica pura sobre state.Manager:
// determina qué operaciones son válidas en cada estado y cuál es el
// estado resultante tras cada operación.
//
// Los 18 estados — ADR-021:
//
//	Pre-install:       PENDIENTE → LISTA
//	Install:           LISTA → INSTALANDO → INSTALADA / FALLA_INSTALACION
//	Update:            INSTALADA → ACTUALIZACION_DISPONIBLE → APROBADA → ACTUALIZANDO
//	                   → INSTALADA / FALLA_ACTUALIZACION
//	Degradación:       INSTALADA → DEGRADADA
//	Repair:            DEGRADADA → REPARANDO → INSTALADA / ERROR_NO_CORREGIBLE
//	Error:             → ERROR_FISICO / ERROR_LOGICO
//	Falla:             FALLA_INSTALACION → LIMPIEZA → PENDIENTE
//	                   FALLA_ACTUALIZACION → ROLLBACK → INSTALADA
//	Admin:             INSTALADA → PAUSADA → INSTALADA
//	Final:             → DESINSTALADA
//
// Estándares: ADR-021, SBOS-019 §8, ISO 27001 A.8.15.
package ficha

import "fmt"

// ── Tipos ────────────────────────────────────────────────────────────

// FichaState representa uno de los 18 estados del ciclo de vida (ADR-021).
// Es un alias del tipo state.FichaState para mantener independencia de capas.
type FichaState string

const (
	// ── Estados pre-install ──────────────────────────────────────────
	StatePending FichaState = "PENDING" // ficha declarada, verificando deps
	StateReady     FichaState = "READY"     // deps OK, esperando turno en DAG

	// ── Estados de instalación ───────────────────────────────────────
	StateInstalling       FichaState = "INSTALLING"        // saga install en progreso (30min)
	StateInstalled        FichaState = "INSTALLED"         // pod Running + health OK
	StateInstallFailed FichaState = "INSTALL_FAILED" // saga install falló

	// ── Estados de actualización ─────────────────────────────────────
	StateUpdateAvailable     FichaState = "UPDATE_AVAILABLE" // nueva versión detectada
	StateUpdateApproved FichaState = "UPDATE_APPROVED"   // tests OK, sin degradación
	StateUpdating          FichaState = "UPDATING"             // saga update en progreso (15min)
	StateUpdateFailed    FichaState = "UPDATE_FAILED"      // saga update falló

	// ── Estados de error ────────────────────────────────────────────
	StateDegraded         FichaState = "DEGRADED"          // funciona reducido, auto-repara
	StatePhysicalError       FichaState = "PHYSICAL_ERROR"       // disco/red/CPU/memoria
	StateLogicalError       FichaState = "LOGICAL_ERROR"        // config/deps/schema drift
	StateUnrecoverable FichaState = "UNRECOVERABLE" // reintentos agotados → HITL

	// ── Estados transicionales ───────────────────────────────────────
	StateRepairing FichaState = "REPAIRING" // diagnóstico + repair (10min)
	StateRollback  FichaState = "ROLLBACK"  // restaurando versión anterior
	StateCleanup  FichaState = "CLEANUP"  // eliminando artefactos, sin residuos

	// ── Estados administrativos ──────────────────────────────────────
	StatePaused      FichaState = "PAUSED"      // admin suspendió (mantenimiento)
	StateUninstalled FichaState = "UNINSTALLED" // removida del sistema
)

// ── Máquina de estados ────────────────────────────────────────────────

// StateMachine implementa la lógica de transición de los 18 estados.
// Es una capa pura — sin I/O, sin dependencias de state.Manager.
// El Manager ejecuta las transiciones; esta capa determina cuáles son válidas.
type StateMachine struct{}

// NewStateMachine crea una máquina de estados.
func NewStateMachine() *StateMachine {
	return &StateMachine{}
}

// ── Validación de operaciones ─────────────────────────────────────────

// CanInstall retorna true si la ficha puede instalarse desde este estado.
func (sm *StateMachine) CanInstall(state FichaState) bool {
	switch state {
	case StatePending, StateReady,
		StateInstallFailed, // reintentar tras fallo
		StateCleanup:         // tras limpiar artefactos
		return true
	}
	return false
}

// CanUpdate retorna true si la ficha puede actualizarse desde este estado.
func (sm *StateMachine) CanUpdate(state FichaState) bool {
	switch state {
	case StateInstalled, StateUpdateAvailable, StateUpdateApproved:
		return true
	}
	return false
}

// CanRepair retorna true si la ficha puede repararse desde este estado.
// StateInstalled se incluye para permitir repair preventivo (mantenimiento sin
// esperar degradación), consistente con ValidTransitions[StateInstalled].
func (sm *StateMachine) CanRepair(state FichaState) bool {
	switch state {
	case StateDegraded, StatePhysicalError, StateLogicalError, StateInstalled:
		return true
	}
	return false
}

// CanRemove retorna true si la ficha puede eliminarse desde este estado.
func (sm *StateMachine) CanRemove(state FichaState) bool {
	switch state {
	case StateInstalled, StateDegraded, StatePhysicalError, StateLogicalError,
		StateUpdateAvailable, StateUpdateApproved,
		StateInstallFailed, StateUpdateFailed,
		StatePaused, StateUnrecoverable:
		return true
	}
	return false
}

// CanPause retorna true si la ficha puede pausarse desde este estado.
func (sm *StateMachine) CanPause(state FichaState) bool {
	return state == StateInstalled
}

// CanResume retorna true si la ficha puede reanudarse desde este estado.
func (sm *StateMachine) CanResume(state FichaState) bool {
	return state == StatePaused
}

// CanScale retorna true si la ficha puede escalarse desde este estado.
func (sm *StateMachine) CanScale(state FichaState) bool {
	return state == StateInstalled
}

// ── Determinación de estado siguiente ─────────────────────────────────

// NextAfterInstall retorna el estado resultante de una operación de instalación.
func (sm *StateMachine) NextAfterInstall(success bool) FichaState {
	if success {
		return StateInstalled
	}
	return StateInstallFailed
}

// NextAfterUpdate retorna el estado resultante de una operación de actualización.
func (sm *StateMachine) NextAfterUpdate(success bool) FichaState {
	if success {
		return StateInstalled
	}
	return StateUpdateFailed
}

// NextAfterRepair retorna el estado resultante de una operación de reparación.
func (sm *StateMachine) NextAfterRepair(success bool) FichaState {
	if success {
		return StateInstalled
	}
	return StateUnrecoverable
}

// NextAfterRemove retorna el estado resultante de una operación de eliminación.
func (sm *StateMachine) NextAfterRemove() FichaState {
	return StateUninstalled
}

// NextAfterHealthFailure retorna el estado tras fallos consecutivos de health.
func (sm *StateMachine) NextAfterHealthFailure(from FichaState, consecutiveFailures int, threshold int) FichaState {
	if consecutiveFailures >= threshold {
		return StateDegraded
	}
	return from // aún no llega al umbral
}

// NextAfterRollback retorna el estado resultante de un rollback exitoso.
func (sm *StateMachine) NextAfterRollback(success bool) FichaState {
	if success {
		return StateInstalled // restaurado a versión N-1
	}
	return StateUnrecoverable // rollback falló → HITL
}

// NextAfterCleanup retorna el estado tras limpieza de artefactos.
func (sm *StateMachine) NextAfterCleanup() FichaState {
	return StatePending // vuelve a empezar
}

// StableStates retorna los 13 estados estables.
func (sm *StateMachine) StableStates() []FichaState {
	return []FichaState{
		StatePending, StateReady, StateInstalled,
		StateUpdateAvailable, StateUpdateApproved,
		StateDegraded, StatePhysicalError, StateLogicalError,
		StateUnrecoverable, StateInstallFailed, StateUpdateFailed,
		StatePaused, StateUninstalled,
	}
}

// TransitionalStates retorna los 5 estados transicionales.
func (sm *StateMachine) TransitionalStates() []FichaState {
	return []FichaState{
		StateInstalling, StateUpdating, StateRepairing, StateRollback, StateCleanup,
	}
}

// ── Clasificación de estados ─────────────────────────────────────────

// IsStable retorna true si el estado es estable (no transicional).
func (sm *StateMachine) IsStable(state FichaState) bool {
	switch state {
	case StateInstalling, StateUpdating, StateRepairing, StateRollback, StateCleanup:
		return false
	}
	return true
}

// IsTransitional retorna true si BOS está activamente trabajando.
func (sm *StateMachine) IsTransitional(state FichaState) bool {
	return !sm.IsStable(state)
}

// IsError retorna true si el estado representa un error.
func (sm *StateMachine) IsError(state FichaState) bool {
	switch state {
	case StatePhysicalError, StateLogicalError, StateUnrecoverable,
		StateInstallFailed, StateUpdateFailed:
		return true
	}
	return false
}

// IsHealthy retorna true si la ficha está operativa sin alertas.
func (sm *StateMachine) IsHealthy(state FichaState) bool {
	return state == StateInstalled
}

// IsOperational retorna true si la ficha está funcionando (aunque degradada).
func (sm *StateMachine) IsOperational(state FichaState) bool {
	switch state {
	case StateInstalled, StateDegraded:
		return true
	}
	return false
}

// NeedsHITL retorna true si el estado requiere intervención humana.
func (sm *StateMachine) NeedsHITL(state FichaState) bool {
	switch state {
	case StateUnrecoverable:
		return true
	}
	return false
}

// ── Transiciones válidas ─────────────────────────────────────────────

// ValidTransitions mapea cada estado a los estados a los que puede transitar.
// Coincide exactamente con state.Manager.ValidTransitions.
func (sm *StateMachine) ValidTransitions() map[FichaState][]FichaState {
	return map[FichaState][]FichaState{
		StatePending:             {StateReady},
		StateReady:                 {StateInstalling},
		StateInstalling:            {StateInstalled, StateInstallFailed},
		StateInstallFailed:      {StateCleanup, StateInstalling},
		StateCleanup:              {StateReady, StatePending},
		StateInstalled:             {StateUpdateAvailable, StateUpdating, StateDegraded, StateRepairing, StatePaused, StateUninstalled},
		StateUpdateAvailable:     {StateUpdateApproved, StateInstalled},
		StateUpdateApproved: {StateUpdating},
		StateUpdating:          {StateInstalled, StateUpdateFailed, StateRollback},
		StateUpdateFailed:    {StateRollback, StateInstalled},
		StateRollback:              {StateInstalled, StateUnrecoverable},
		StateDegraded:             {StateRepairing, StatePhysicalError, StateLogicalError},
		StatePhysicalError:           {StateRepairing},
		StateLogicalError:           {StateRepairing},
		StateRepairing:             {StateInstalled, StateDegraded, StateUnrecoverable},
		StateUnrecoverable:     {StateRepairing, StateUninstalled, StateCleanup},
		StatePaused:               {StateInstalled, StateUninstalled},
		StateUninstalled:          {},
	}
}

// CanTransition verifica si una transición es válida.
func (sm *StateMachine) CanTransition(from, to FichaState) bool {
	validStates, ok := sm.ValidTransitions()[from]
	if !ok {
		return false
	}
	for _, valid := range validStates {
		if valid == to {
			return true
		}
	}
	return false
}

// TransitionError representa un error de transición inválida.
type TransitionError struct {
	From FichaState
	To   FichaState
}

func (e *TransitionError) Error() string {
	return fmt.Sprintf("transición inválida: %s → %s", e.From, e.To)
}

// ValidateTransition retorna error si la transición no es válida.
func (sm *StateMachine) ValidateTransition(from, to FichaState) error {
	if !sm.CanTransition(from, to) {
		return &TransitionError{From: from, To: to}
	}
	return nil
}

// ── Conversión entre state.FichaState y ficha.FichaState ──────────────
// state/manager.go es la fuente de verdad de persistencia (fcntl flock, JSON).
// ficha/statemachine.go es la fuente de verdad de lógica de dominio (pura, sin I/O).
// Ambos definen los mismos 18 estados con idénticos valores string (ADR-021).
// Estas funciones permiten convertir entre ambos tipos sin dependencia circular.

// ToState retorna el string del estado para usar con state.Manager.
// state.Manager espera un state.FichaState, pero como ambos usan los mismos
// valores string subyacentes, la conversión es trivial.
func (s FichaState) ToState() string {
	return string(s)
}

// FichaStateFromString convierte un string (de state.Manager o JSON) a FichaState.
// Retorna el estado parseado y true si es uno de los 18 estados conocidos.
func FichaStateFromString(s string) (FichaState, bool) {
	sm := NewStateMachine()
	for _, state := range sm.AllStates() {
		if string(state) == s {
			return state, true
		}
	}
	return "", false
}

// IsValidState verifica si un string representa uno de los 18 estados.
func IsValidState(s string) bool {
	_, ok := FichaStateFromString(s)
	return ok
}

// ── Helpers para UI y CLI ────────────────────────────────────────────

// AllStates retorna los 18 estados en orden de ciclo de vida.
func (sm *StateMachine) AllStates() []FichaState {
	return []FichaState{
		StatePending, StateReady,
		StateInstalling, StateInstalled, StateInstallFailed,
		StateUpdateAvailable, StateUpdateApproved, StateUpdating, StateUpdateFailed,
		StateDegraded, StatePhysicalError, StateLogicalError,
		StateRepairing, StateUnrecoverable,
		StateRollback, StateCleanup,
		StatePaused, StateUninstalled,
	}
}

// StateIcon retorna un ícono representativo para cada estado.
func StateIcon(state FichaState) string {
	switch state {
	case StatePending:
		return "⬜"
	case StateReady:
		return "🔵"
	case StateInstalling, StateUpdating, StateRepairing:
		return "⏳"
	case StateInstalled:
		return "🟢"
	case StateUpdateAvailable:
		return "🔔"
	case StateUpdateApproved:
		return "✅"
	case StateDegraded:
		return "🟡"
	case StatePhysicalError, StateLogicalError:
		return "🔴"
	case StateUnrecoverable:
		return "🚨"
	case StateInstallFailed, StateUpdateFailed:
		return "❌"
	case StateRollback:
		return "↩️"
	case StateCleanup:
		return "🧹"
	case StatePaused:
		return "⏸️"
	case StateUninstalled:
		return "💀"
	}
	return "❓"
}

// StateDescription retorna una descripción humana del estado.
func StateDescription(state FichaState) string {
	switch state {
	case StatePending:
		return "Ficha declarada, dependencias verificándose"
	case StateReady:
		return "Dependencias OK, esperando turno en DAG"
	case StateInstalling:
		return "Saga de instalación en progreso (timeout 30min)"
	case StateInstalled:
		return "Pod Running + health OK + hashes registrados"
	case StateUpdateAvailable:
		return "Nueva versión detectada, no evaluada"
	case StateUpdateApproved:
		return "Tests OK, sin degradación del sistema"
	case StateUpdating:
		return "Saga de actualización en progreso (timeout 15min)"
	case StateDegraded:
		return "Funciona con capacidad reducida, auto-reparando"
	case StatePhysicalError:
		return "Error externo: disco, red, CPU, memoria"
	case StateLogicalError:
		return "Error interno: config, dependencias, schema drift"
	case StateRepairing:
		return "Diagnóstico + repair en progreso (timeout 10min)"
	case StateUnrecoverable:
		return "Reintentos agotados — requiere intervención humana"
	case StateInstallFailed:
		return "Saga install falló — evaluar rollback/limpieza"
	case StateUpdateFailed:
		return "Saga update falló — evaluar rollback"
	case StateRollback:
		return "Restaurando versión anterior estable"
	case StateCleanup:
		return "Eliminando artefactos — sin residuos"
	case StatePaused:
		return "Suspendida por administrador (mantenimiento)"
	case StateUninstalled:
		return "Removida del sistema"
	}
	return "Estado desconocido"
}

// ── Operaciones de ciclo de vida ──────────────────────────────────────

// BeginInstall inicia la transición de instalación.
// Retorna el estado INSTALANDO y error si no es válido.
func (sm *StateMachine) BeginInstall(current FichaState) (FichaState, error) {
	if !sm.CanInstall(current) {
		return current, fmt.Errorf("no se puede instalar desde %s", current)
	}
	return StateInstalling, nil
}

// BeginUpdate inicia la transición de actualización.
func (sm *StateMachine) BeginUpdate(current FichaState) (FichaState, error) {
	if !sm.CanUpdate(current) {
		return current, fmt.Errorf("no se puede actualizar desde %s", current)
	}
	return StateUpdating, nil
}

// BeginRepair inicia la transición de reparación.
func (sm *StateMachine) BeginRepair(current FichaState) (FichaState, error) {
	if !sm.CanRepair(current) {
		return current, fmt.Errorf("no se puede reparar desde %s (debe estar DEGRADADA/ERROR_FISICO/ERROR_LOGICO)", current)
	}
	return StateRepairing, nil
}

// BeginRemove inicia la transición de eliminación.
func (sm *StateMachine) BeginRemove(current FichaState) (FichaState, error) {
	if !sm.CanRemove(current) {
		return current, fmt.Errorf("no se puede eliminar desde %s", current)
	}
	return StateUninstalled, nil
}
