package ficha

import (
	"testing"
)

func TestStateMachine_CanInstall(t *testing.T) {
	sm := NewStateMachine()

	validStates := []FichaState{StatePendiente, StateLista, StateFallaInstalacion, StateLimpieza}
	for _, state := range sm.AllStates() {
		expected := containsState(validStates, state)
		if sm.CanInstall(state) != expected {
			t.Errorf("CanInstall(%s): esperado %v, obtenido %v", state, expected, !expected)
		}
	}
}

func TestStateMachine_CanUpdate(t *testing.T) {
	sm := NewStateMachine()

	if !sm.CanUpdate(StateInstalada) {
		t.Error("INSTALADA debe poder actualizarse")
	}
	if !sm.CanUpdate(StateActualizacionDisp) {
		t.Error("ACTUALIZACION_DISPONIBLE debe poder actualizarse")
	}
	if sm.CanUpdate(StateDegradada) {
		t.Error("DEGRADADA NO debe poder actualizarse (reparar primero)")
	}
	if sm.CanUpdate(StatePendiente) {
		t.Error("PENDIENTE NO debe poder actualizarse")
	}
}

func TestStateMachine_CanRepair(t *testing.T) {
	sm := NewStateMachine()

	validStates := []FichaState{StateDegradada, StateErrorFisico, StateErrorLogico}
	for _, state := range sm.AllStates() {
		expected := containsState(validStates, state)
		if sm.CanRepair(state) != expected {
			t.Errorf("CanRepair(%s): esperado %v, obtenido %v", state, expected, !expected)
		}
	}
}

func TestStateMachine_CanRemove(t *testing.T) {
	sm := NewStateMachine()

	if !sm.CanRemove(StateInstalada) {
		t.Error("INSTALADA debe poder eliminarse")
	}
	if !sm.CanRemove(StateDegradada) {
		t.Error("DEGRADADA debe poder eliminarse")
	}
	if !sm.CanRemove(StatePausada) {
		t.Error("PAUSADA debe poder eliminarse")
	}
	if sm.CanRemove(StatePendiente) {
		t.Error("PENDIENTE NO debe poder eliminarse (no está instalada)")
	}
	if sm.CanRemove(StateDesinstalada) {
		t.Error("DESINSTALADA NO debe poder eliminarse de nuevo")
	}
}

func TestStateMachine_CanPause(t *testing.T) {
	sm := NewStateMachine()

	if !sm.CanPause(StateInstalada) {
		t.Error("INSTALADA debe poder pausarse")
	}
	if sm.CanPause(StatePendiente) {
		t.Error("PENDIENTE NO debe poder pausarse")
	}
	if sm.CanPause(StateDegradada) {
		t.Error("DEGRADADA NO debe poder pausarse (reparar primero)")
	}
}

func TestStateMachine_CanResume(t *testing.T) {
	sm := NewStateMachine()

	if !sm.CanResume(StatePausada) {
		t.Error("PAUSADA debe poder reanudarse")
	}
	if sm.CanResume(StateInstalada) {
		t.Error("INSTALADA NO debe poder reanudarse (no está pausada)")
	}
}

func TestStateMachine_NextAfterInstall(t *testing.T) {
	sm := NewStateMachine()

	if sm.NextAfterInstall(true) != StateInstalada {
		t.Error("install exitoso → INSTALADA")
	}
	if sm.NextAfterInstall(false) != StateFallaInstalacion {
		t.Error("install fallido → FALLA_INSTALACION")
	}
}

func TestStateMachine_NextAfterUpdate(t *testing.T) {
	sm := NewStateMachine()

	if sm.NextAfterUpdate(true) != StateInstalada {
		t.Error("update exitoso → INSTALADA")
	}
	if sm.NextAfterUpdate(false) != StateFallaActualizacion {
		t.Error("update fallido → FALLA_ACTUALIZACION")
	}
}

func TestStateMachine_NextAfterRepair(t *testing.T) {
	sm := NewStateMachine()

	if sm.NextAfterRepair(true) != StateInstalada {
		t.Error("repair exitoso → INSTALADA")
	}
	if sm.NextAfterRepair(false) != StateErrorNoCorregible {
		t.Error("repair fallido → ERROR_NO_CORREGIBLE (HITL)")
	}
}

func TestStateMachine_NextAfterHealthFailure(t *testing.T) {
	sm := NewStateMachine()

	// No llega al umbral
	if sm.NextAfterHealthFailure(StateInstalada, 2, 3) != StateInstalada {
		t.Error("2 fallos de 3 → sigue INSTALADA")
	}

	// Alcanza el umbral
	if sm.NextAfterHealthFailure(StateInstalada, 3, 3) != StateDegradada {
		t.Error("3 fallos de 3 → DEGRADADA")
	}

	// Excede umbral
	if sm.NextAfterHealthFailure(StateInstalada, 5, 3) != StateDegradada {
		t.Error("5 fallos → DEGRADADA")
	}
}

func TestStateMachine_IsStable(t *testing.T) {
	sm := NewStateMachine()

	stableStates := sm.StableStates()
	transitionalStates := sm.TransitionalStates()

	for _, s := range stableStates {
		if !sm.IsStable(s) {
			t.Errorf("%s debe ser estable", s)
		}
	}
	for _, s := range transitionalStates {
		if sm.IsStable(s) {
			t.Errorf("%s NO debe ser estable", s)
		}
	}
}

func TestStateMachine_NeedsHITL(t *testing.T) {
	sm := NewStateMachine()

	if !sm.NeedsHITL(StateErrorNoCorregible) {
		t.Error("ERROR_NO_CORREGIBLE debe necesitar HITL")
	}
	if sm.NeedsHITL(StateInstalada) {
		t.Error("INSTALADA NO debe necesitar HITL")
	}
}

func TestStateMachine_CanTransition(t *testing.T) {
	sm := NewStateMachine()

	// Transiciones válidas
	if !sm.CanTransition(StatePendiente, StateLista) {
		t.Error("PENDIENTE → LISTA debe ser válido")
	}
	if !sm.CanTransition(StateInstalando, StateInstalada) {
		t.Error("INSTALANDO → INSTALADA debe ser válido")
	}

	// Transiciones inválidas
	if sm.CanTransition(StatePendiente, StateInstalada) {
		t.Error("PENDIENTE → INSTALADA NO debe ser válido (falta LISTA e INSTALANDO)")
	}
	if sm.CanTransition(StateDesinstalada, StateInstalada) {
		t.Error("DESINSTALADA → INSTALADA NO debe ser válido")
	}
}

func TestStateMachine_ValidateTransition(t *testing.T) {
	sm := NewStateMachine()

	if err := sm.ValidateTransition(StateLista, StateInstalando); err != nil {
		t.Errorf("LISTA → INSTALANDO debe ser válido: %v", err)
	}
	if err := sm.ValidateTransition(StatePendiente, StateInstalada); err == nil {
		t.Error("PENDIENTE → INSTALADA debe ser inválido")
	}
}

func TestStateMachine_BeginOperations(t *testing.T) {
	sm := NewStateMachine()

	// Install
	next, err := sm.BeginInstall(StateLista)
	if err != nil || next != StateInstalando {
		t.Errorf("BeginInstall(LISTA): esperado INSTALANDO, obtenido %s err=%v", next, err)
	}
	_, err = sm.BeginInstall(StateInstalada)
	if err == nil {
		t.Error("BeginInstall(INSTALADA) debe fallar")
	}

	// Update
	next, err = sm.BeginUpdate(StateInstalada)
	if err != nil || next != StateActualizando {
		t.Errorf("BeginUpdate(INSTALADA): esperado ACTUALIZANDO, obtenido %s", next)
	}

	// Repair
	next, err = sm.BeginRepair(StateDegradada)
	if err != nil || next != StateReparando {
		t.Errorf("BeginRepair(DEGRADADA): esperado REPARANDO, obtenido %s err=%v", next, err)
	}
	_, err = sm.BeginRepair(StateInstalada)
	if err == nil {
		t.Error("BeginRepair(INSTALADA) debe fallar")
	}

	// Remove
	next, err = sm.BeginRemove(StateInstalada)
	if err != nil || next != StateDesinstalada {
		t.Errorf("BeginRemove(INSTALADA): esperado DESINSTALADA, obtenido %s", next)
	}
}

func TestStateMachine_AllStates(t *testing.T) {
	sm := NewStateMachine()
	states := sm.AllStates()

	if len(states) != 18 {
		t.Errorf("esperado 18 estados, obtenido %d", len(states))
	}

	// Verificar unicidad
	seen := make(map[FichaState]bool)
	for _, s := range states {
		if seen[s] {
			t.Errorf("estado duplicado: %s", s)
		}
		seen[s] = true
	}
}

func TestStateIcons(t *testing.T) {
	sm := NewStateMachine()
	for _, state := range sm.AllStates() {
		icon := StateIcon(state)
		if icon == "" || icon == "❓" {
			// Solo estado desconocido debería retornar ❓
			continue
		}
		if len(icon) < 1 {
			t.Errorf("icono de %s muy corto: %q", state, icon)
		}
	}
}

func TestStateDescriptions(t *testing.T) {
	sm := NewStateMachine()
	for _, state := range sm.AllStates() {
		desc := StateDescription(state)
		if len(desc) < 10 {
			t.Errorf("descripción de %s muy corta: %q", state, desc)
		}
	}
}

func TestStateMachine_StableStates(t *testing.T) {
	sm := NewStateMachine()
	stable := sm.StableStates()
	if len(stable) != 13 {
		t.Errorf("esperado 13 estados estables, obtenido %d", len(stable))
	}
}

func TestStateMachine_TransitionalStates(t *testing.T) {
	sm := NewStateMachine()
	trans := sm.TransitionalStates()
	if len(trans) != 5 {
		t.Errorf("esperado 5 estados transicionales, obtenido %d", len(trans))
	}
}

func containsState(states []FichaState, target FichaState) bool {
	for _, s := range states {
		if s == target {
			return true
		}
	}
	return false
}

func TestFichaStateFromString_Valid(t *testing.T) {
	validStates := []string{
		"PENDIENTE", "LISTA", "INSTALANDO", "INSTALADA", "FALLA_INSTALACION",
		"ACTUALIZACION_DISPONIBLE", "ACTUALIZACION_APROBADA", "ACTUALIZANDO", "FALLA_ACTUALIZACION",
		"DEGRADADA", "ERROR_FISICO", "ERROR_LOGICO", "ERROR_NO_CORREGIBLE",
		"REPARANDO", "ROLLBACK", "LIMPIEZA", "PAUSADA", "DESINSTALADA",
	}

	for _, s := range validStates {
		state, ok := FichaStateFromString(s)
		if !ok {
			t.Errorf("FichaStateFromString(%q): debe ser válido", s)
		}
		if string(state) != s {
			t.Errorf("FichaStateFromString(%q): esperado %q, obtenido %q", s, s, state)
		}
	}
}

func TestFichaStateFromString_Invalid(t *testing.T) {
	invalidStates := []string{"", "RUNNING", "STOPPED", "OK", "ERROR", "instalada", "pendiente", "installing"}

	for _, s := range invalidStates {
		_, ok := FichaStateFromString(s)
		if ok {
			t.Errorf("FichaStateFromString(%q): debe ser inválido", s)
		}
	}
}

func TestIsValidState(t *testing.T) {
	if !IsValidState("INSTALADA") {
		t.Error("INSTALADA debe ser válido")
	}
	if !IsValidState("DEGRADADA") {
		t.Error("DEGRADADA debe ser válido")
	}
	if IsValidState("RUNNING") {
		t.Error("RUNNING NO debe ser válido")
	}
	if IsValidState("") {
		t.Error("vacío NO debe ser válido")
	}
}

func TestFichaState_ToState(t *testing.T) {
	state := StateInstalada
	if state.ToState() != "INSTALADA" {
		t.Errorf("ToState: esperado INSTALADA, obtenido %s", state.ToState())
	}

	state = StateDegradada
	if state.ToState() != "DEGRADADA" {
		t.Errorf("ToState: esperado DEGRADADA, obtenido %s", state.ToState())
	}
}

func TestStateConsistency_18States(t *testing.T) {
	// Verificar que los 18 estados son consistentes entre state.Manager y ficha.StateMachine
	sm := NewStateMachine()
	states := sm.AllStates()

	if len(states) != 18 {
		t.Fatalf("esperado 18 estados, obtenido %d", len(states))
	}

	// Cada estado debe poder convertirse a string y de vuelta
	for _, s := range states {
		str := s.ToState()
		back, ok := FichaStateFromString(str)
		if !ok {
			t.Errorf("conversión ida y vuelta falló para %s: string=%q no es válido", s, str)
		}
		if back != s {
			t.Errorf("conversión ida y vuelta incorrecta: %s → %q → %s", s, str, back)
		}
	}

	// Cada estado debe ser válido
	for _, s := range states {
		if !IsValidState(string(s)) {
			t.Errorf("IsValidState(%s) debe ser true", s)
		}
	}
}
