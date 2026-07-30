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
	StatePendiente FichaState = "PENDIENTE" // ficha declarada, verificando deps
	StateLista     FichaState = "LISTA"     // deps OK, esperando turno en DAG

	// ── Estados de instalación ───────────────────────────────────────
	StateInstalando       FichaState = "INSTALANDO"        // saga install en progreso (30min)
	StateInstalada        FichaState = "INSTALADA"         // pod Running + health OK
	StateFallaInstalacion FichaState = "FALLA_INSTALACION" // saga install falló

	// ── Estados de actualización ─────────────────────────────────────
	StateActualizacionDisp     FichaState = "ACTUALIZACION_DISPONIBLE" // nueva versión detectada
	StateActualizacionAprobada FichaState = "ACTUALIZACION_APROBADA"   // tests OK, sin degradación
	StateActualizando          FichaState = "ACTUALIZANDO"             // saga update en progreso (15min)
	StateFallaActualizacion    FichaState = "FALLA_ACTUALIZACION"      // saga update falló

	// ── Estados de error ────────────────────────────────────────────
	StateDegradada         FichaState = "DEGRADADA"          // funciona reducido, auto-repara
	StateErrorFisico       FichaState = "ERROR_FISICO"       // disco/red/CPU/memoria
	StateErrorLogico       FichaState = "ERROR_LOGICO"        // config/deps/schema drift
	StateErrorNoCorregible FichaState = "ERROR_NO_CORREGIBLE" // reintentos agotados → HITL

	// ── Estados transicionales ───────────────────────────────────────
	StateReparando FichaState = "REPARANDO" // diagnóstico + repair (10min)
	StateRollback  FichaState = "ROLLBACK"  // restaurando versión anterior
	StateLimpieza  FichaState = "LIMPIEZA"  // eliminando artefactos, sin residuos

	// ── Estados administrativos ──────────────────────────────────────
	StatePausada      FichaState = "PAUSADA"      // admin suspendió (mantenimiento)
	StateDesinstalada FichaState = "DESINSTALADA" // removida del sistema
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
	case StatePendiente, StateLista,
		StateFallaInstalacion, // reintentar tras fallo
		StateLimpieza:         // tras limpiar artefactos
		return true
	}
	return false
}

// CanUpdate retorna true si la ficha puede actualizarse desde este estado.
func (sm *StateMachine) CanUpdate(state FichaState) bool {
	switch state {
	case StateInstalada, StateActualizacionDisp, StateActualizacionAprobada:
		return true
	}
	return false
}

// CanRepair retorna true si la ficha puede repararse desde este estado.
// StateInstalada se incluye para permitir repair preventivo (mantenimiento sin
// esperar degradación), consistente con ValidTransitions[StateInstalada].
func (sm *StateMachine) CanRepair(state FichaState) bool {
	switch state {
	case StateDegradada, StateErrorFisico, StateErrorLogico, StateInstalada:
		return true
	}
	return false
}

// CanRemove retorna true si la ficha puede eliminarse desde este estado.
func (sm *StateMachine) CanRemove(state FichaState) bool {
	switch state {
	case StateInstalada, StateDegradada, StateErrorFisico, StateErrorLogico,
		StateActualizacionDisp, StateActualizacionAprobada,
		StateFallaInstalacion, StateFallaActualizacion,
		StatePausada, StateErrorNoCorregible:
		return true
	}
	return false
}

// CanPause retorna true si la ficha puede pausarse desde este estado.
func (sm *StateMachine) CanPause(state FichaState) bool {
	return state == StateInstalada
}

// CanResume retorna true si la ficha puede reanudarse desde este estado.
func (sm *StateMachine) CanResume(state FichaState) bool {
	return state == StatePausada
}

// CanScale retorna true si la ficha puede escalarse desde este estado.
func (sm *StateMachine) CanScale(state FichaState) bool {
	return state == StateInstalada
}

// ── Determinación de estado siguiente ─────────────────────────────────

// NextAfterInstall retorna el estado resultante de una operación de instalación.
func (sm *StateMachine) NextAfterInstall(success bool) FichaState {
	if success {
		return StateInstalada
	}
	return StateFallaInstalacion
}

// NextAfterUpdate retorna el estado resultante de una operación de actualización.
func (sm *StateMachine) NextAfterUpdate(success bool) FichaState {
	if success {
		return StateInstalada
	}
	return StateFallaActualizacion
}

// NextAfterRepair retorna el estado resultante de una operación de reparación.
func (sm *StateMachine) NextAfterRepair(success bool) FichaState {
	if success {
		return StateInstalada
	}
	return StateErrorNoCorregible
}

// NextAfterRemove retorna el estado resultante de una operación de eliminación.
func (sm *StateMachine) NextAfterRemove() FichaState {
	return StateDesinstalada
}

// NextAfterHealthFailure retorna el estado tras fallos consecutivos de health.
func (sm *StateMachine) NextAfterHealthFailure(from FichaState, consecutiveFailures int, threshold int) FichaState {
	if consecutiveFailures >= threshold {
		return StateDegradada
	}
	return from // aún no llega al umbral
}

// NextAfterRollback retorna el estado resultante de un rollback exitoso.
func (sm *StateMachine) NextAfterRollback(success bool) FichaState {
	if success {
		return StateInstalada // restaurado a versión N-1
	}
	return StateErrorNoCorregible // rollback falló → HITL
}

// NextAfterCleanup retorna el estado tras limpieza de artefactos.
func (sm *StateMachine) NextAfterCleanup() FichaState {
	return StatePendiente // vuelve a empezar
}

// StableStates retorna los 13 estados estables.
func (sm *StateMachine) StableStates() []FichaState {
	return []FichaState{
		StatePendiente, StateLista, StateInstalada,
		StateActualizacionDisp, StateActualizacionAprobada,
		StateDegradada, StateErrorFisico, StateErrorLogico,
		StateErrorNoCorregible, StateFallaInstalacion, StateFallaActualizacion,
		StatePausada, StateDesinstalada,
	}
}

// TransitionalStates retorna los 5 estados transicionales.
func (sm *StateMachine) TransitionalStates() []FichaState {
	return []FichaState{
		StateInstalando, StateActualizando, StateReparando, StateRollback, StateLimpieza,
	}
}

// ── Clasificación de estados ─────────────────────────────────────────

// IsStable retorna true si el estado es estable (no transicional).
func (sm *StateMachine) IsStable(state FichaState) bool {
	switch state {
	case StateInstalando, StateActualizando, StateReparando, StateRollback, StateLimpieza:
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
	case StateErrorFisico, StateErrorLogico, StateErrorNoCorregible,
		StateFallaInstalacion, StateFallaActualizacion:
		return true
	}
	return false
}

// IsHealthy retorna true si la ficha está operativa sin alertas.
func (sm *StateMachine) IsHealthy(state FichaState) bool {
	return state == StateInstalada
}

// IsOperational retorna true si la ficha está funcionando (aunque degradada).
func (sm *StateMachine) IsOperational(state FichaState) bool {
	switch state {
	case StateInstalada, StateDegradada:
		return true
	}
	return false
}

// NeedsHITL retorna true si el estado requiere intervención humana.
func (sm *StateMachine) NeedsHITL(state FichaState) bool {
	switch state {
	case StateErrorNoCorregible:
		return true
	}
	return false
}

// ── Transiciones válidas ─────────────────────────────────────────────

// ValidTransitions mapea cada estado a los estados a los que puede transitar.
// Coincide exactamente con state.Manager.ValidTransitions.
func (sm *StateMachine) ValidTransitions() map[FichaState][]FichaState {
	return map[FichaState][]FichaState{
		StatePendiente:             {StateLista},
		StateLista:                 {StateInstalando},
		StateInstalando:            {StateInstalada, StateFallaInstalacion},
		StateFallaInstalacion:      {StateLimpieza, StateInstalando},
		StateLimpieza:              {StateLista, StatePendiente},
		StateInstalada:             {StateActualizacionDisp, StateActualizando, StateDegradada, StateReparando, StatePausada, StateDesinstalada},
		StateActualizacionDisp:     {StateActualizacionAprobada, StateInstalada},
		StateActualizacionAprobada: {StateActualizando},
		StateActualizando:          {StateInstalada, StateFallaActualizacion, StateRollback},
		StateFallaActualizacion:    {StateRollback, StateInstalada},
		StateRollback:              {StateInstalada, StateErrorNoCorregible},
		StateDegradada:             {StateReparando, StateErrorFisico, StateErrorLogico},
		StateErrorFisico:           {StateReparando},
		StateErrorLogico:           {StateReparando},
		StateReparando:             {StateInstalada, StateDegradada, StateErrorNoCorregible},
		StateErrorNoCorregible:     {StateReparando, StateDesinstalada, StateLimpieza},
		StatePausada:               {StateInstalada, StateDesinstalada},
		StateDesinstalada:          {},
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
		StatePendiente, StateLista,
		StateInstalando, StateInstalada, StateFallaInstalacion,
		StateActualizacionDisp, StateActualizacionAprobada, StateActualizando, StateFallaActualizacion,
		StateDegradada, StateErrorFisico, StateErrorLogico,
		StateReparando, StateErrorNoCorregible,
		StateRollback, StateLimpieza,
		StatePausada, StateDesinstalada,
	}
}

// StateIcon retorna un ícono representativo para cada estado.
func StateIcon(state FichaState) string {
	switch state {
	case StatePendiente:
		return "⬜"
	case StateLista:
		return "🔵"
	case StateInstalando, StateActualizando, StateReparando:
		return "⏳"
	case StateInstalada:
		return "🟢"
	case StateActualizacionDisp:
		return "🔔"
	case StateActualizacionAprobada:
		return "✅"
	case StateDegradada:
		return "🟡"
	case StateErrorFisico, StateErrorLogico:
		return "🔴"
	case StateErrorNoCorregible:
		return "🚨"
	case StateFallaInstalacion, StateFallaActualizacion:
		return "❌"
	case StateRollback:
		return "↩️"
	case StateLimpieza:
		return "🧹"
	case StatePausada:
		return "⏸️"
	case StateDesinstalada:
		return "💀"
	}
	return "❓"
}

// StateDescription retorna una descripción humana del estado.
func StateDescription(state FichaState) string {
	switch state {
	case StatePendiente:
		return "Ficha declarada, dependencias verificándose"
	case StateLista:
		return "Dependencias OK, esperando turno en DAG"
	case StateInstalando:
		return "Saga de instalación en progreso (timeout 30min)"
	case StateInstalada:
		return "Pod Running + health OK + hashes registrados"
	case StateActualizacionDisp:
		return "Nueva versión detectada, no evaluada"
	case StateActualizacionAprobada:
		return "Tests OK, sin degradación del sistema"
	case StateActualizando:
		return "Saga de actualización en progreso (timeout 15min)"
	case StateDegradada:
		return "Funciona con capacidad reducida, auto-reparando"
	case StateErrorFisico:
		return "Error externo: disco, red, CPU, memoria"
	case StateErrorLogico:
		return "Error interno: config, dependencias, schema drift"
	case StateReparando:
		return "Diagnóstico + repair en progreso (timeout 10min)"
	case StateErrorNoCorregible:
		return "Reintentos agotados — requiere intervención humana"
	case StateFallaInstalacion:
		return "Saga install falló — evaluar rollback/limpieza"
	case StateFallaActualizacion:
		return "Saga update falló — evaluar rollback"
	case StateRollback:
		return "Restaurando versión anterior estable"
	case StateLimpieza:
		return "Eliminando artefactos — sin residuos"
	case StatePausada:
		return "Suspendida por administrador (mantenimiento)"
	case StateDesinstalada:
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
	return StateInstalando, nil
}

// BeginUpdate inicia la transición de actualización.
func (sm *StateMachine) BeginUpdate(current FichaState) (FichaState, error) {
	if !sm.CanUpdate(current) {
		return current, fmt.Errorf("no se puede actualizar desde %s", current)
	}
	return StateActualizando, nil
}

// BeginRepair inicia la transición de reparación.
func (sm *StateMachine) BeginRepair(current FichaState) (FichaState, error) {
	if !sm.CanRepair(current) {
		return current, fmt.Errorf("no se puede reparar desde %s (debe estar DEGRADADA/ERROR_FISICO/ERROR_LOGICO)", current)
	}
	return StateReparando, nil
}

// BeginRemove inicia la transición de eliminación.
func (sm *StateMachine) BeginRemove(current FichaState) (FichaState, error) {
	if !sm.CanRemove(current) {
		return current, fmt.Errorf("no se puede eliminar desde %s", current)
	}
	return StateDesinstalada, nil
}
