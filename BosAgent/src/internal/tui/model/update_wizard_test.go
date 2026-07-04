// Package model — update_wizard_test.go: tests para los manejadores de P3B y P4.
// DoD: go test -race -count=10 ./internal/tui/model/
package model

import (
	"testing"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

// ── helpers ────────────────────────────────────────────────────────────────

func newCapacityInputs() []textinput.Model {
	inputs := buildInputs(CapacitySchema, nil)
	inputs[0].Focus()
	return inputs
}

func setInputValue(inputs []textinput.Model, i int, v string) {
	inputs[i].SetValue(v)
}

func keyMsg(t tea.KeyType) tea.KeyMsg {
	return tea.KeyMsg{Type: t}
}

func keyStr(s string) tea.KeyMsg {
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
}

// ── HandleCapacityKey ──────────────────────────────────────────────────────

func TestHandleCapacityKey_Tab_AvanzaCampo(t *testing.T) {
	inputs := newCapacityInputs()
	focus := 0
	action, _ := HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyTab))
	if action != CapacityActionNone {
		t.Errorf("Tab no debe cambiar pantalla, got action=%d", action)
	}
	if focus != 1 {
		t.Errorf("Tab: focus esperado 1, got %d", focus)
	}
}

func TestHandleCapacityKey_ShiftTab_RetrocedeCampo(t *testing.T) {
	inputs := newCapacityInputs()
	focus := 2
	HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyShiftTab))
	if focus != 1 {
		t.Errorf("ShiftTab: focus esperado 1, got %d", focus)
	}
}

func TestHandleCapacityKey_Tab_WrapAround(t *testing.T) {
	inputs := newCapacityInputs()
	focus := len(inputs) - 1
	HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyTab))
	if focus != 0 {
		t.Errorf("Tab en último campo debe volver a 0, got %d", focus)
	}
}

func TestHandleCapacityKey_Enter_CampoIntermedio_AvanzaCampo(t *testing.T) {
	inputs := newCapacityInputs()
	setInputValue(inputs, 0, "5")
	focus := 0
	// BUG FIX: Enter en campo 0 debe navegar al campo 1, NO avanzar a P4
	action, _ := HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyEnter))
	if action != CapacityActionNone {
		t.Errorf("Enter en campo 0: NO debe avanzar pantalla, got action=%d", action)
	}
	if focus != 1 {
		t.Errorf("Enter en campo 0: focus debe ser 1, got %d", focus)
	}
}

func TestHandleCapacityKey_Enter_UltimoCampo_ValidacionFalla(t *testing.T) {
	inputs := newCapacityInputs()
	// Solo campo 3 tiene foco, los otros están vacíos
	focus := 3
	action, errMsg := HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyEnter))
	if action != CapacityActionNone {
		t.Errorf("Enter con campos vacíos: debe quedarse, got action=%d", action)
	}
	if errMsg == "" {
		t.Error("Enter con campos vacíos: debe retornar error")
	}
}

func TestHandleCapacityKey_Enter_UltimoCampo_TodosValidos_Avanza(t *testing.T) {
	inputs := newCapacityInputs()
	for i := range inputs {
		setInputValue(inputs, i, "5")
	}
	focus := 3
	action, errMsg := HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyEnter))
	if action != CapacityActionAdvance {
		t.Errorf("Enter último campo válido: debe avanzar, got action=%d", action)
	}
	if errMsg != "" {
		t.Errorf("Enter válido: no debe haber error, got %q", errMsg)
	}
}

func TestHandleCapacityKey_Esc_Retrocede(t *testing.T) {
	inputs := newCapacityInputs()
	focus := 2
	action, _ := HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyEsc))
	if action != CapacityActionBack {
		t.Errorf("Esc: debe retroceder, got action=%d", action)
	}
	if focus != 0 {
		t.Errorf("Esc: debe resetear focus a 0, got %d", focus)
	}
}

// ── ValidateCapacityInputs ─────────────────────────────────────────────────

func TestValidateCapacityInputs_CampoVacio(t *testing.T) {
	inputs := newCapacityInputs()
	focus := 0
	err := ValidateCapacityInputs(inputs, &focus)
	if err == "" {
		t.Error("campo vacío: debe retornar error")
	}
}

func TestValidateCapacityInputs_ValorCero(t *testing.T) {
	inputs := newCapacityInputs()
	for i := range inputs {
		setInputValue(inputs, i, "0")
	}
	focus := 0
	err := ValidateCapacityInputs(inputs, &focus)
	if err == "" {
		t.Error("valor 0: debe retornar error")
	}
}

func TestValidateCapacityInputs_ValoresValidos(t *testing.T) {
	inputs := newCapacityInputs()
	for i, v := range []string{"3", "10", "5", "20"} {
		setInputValue(inputs, i, v)
	}
	focus := 0
	err := ValidateCapacityInputs(inputs, &focus)
	if err != "" {
		t.Errorf("valores válidos: no debe haber error, got %q", err)
	}
}

func TestValidateCapacityInputs_CaracterInvalido(t *testing.T) {
	inputs := newCapacityInputs()
	setInputValue(inputs, 0, "abc")
	focus := 0
	err := ValidateCapacityInputs(inputs, &focus)
	if err == "" {
		t.Error("carácter inválido: debe retornar error")
	}
}

// ── CapacityEstimateForDisplay ─────────────────────────────────────────────

func TestCapacityEstimateForDisplay_CamposVacios_MinimoCero(t *testing.T) {
	inputs := newCapacityInputs()
	// Sin valores: todos los campos retornan 1 (mínimo de visualización)
	est := CapacityEstimateForDisplay(inputs)
	if est.TotalUsers() == 0 {
		t.Error("campos vacíos: TotalUsers no debe ser 0 para visualización")
	}
	if est.Tenants != 1 || est.CompaniesPerTenant != 1 {
		t.Errorf("campos vacíos: esperaba 1,1,1,1 got %d,%d,%d,%d",
			est.Tenants, est.CompaniesPerTenant, est.BranchesPerCompany, est.UsersPerBranch)
	}
}

func TestCapacityEstimateForDisplay_EntradaParcial_ProductoNoNulo(t *testing.T) {
	inputs := newCapacityInputs()
	// Solo campo 0 tiene valor
	setInputValue(inputs, 0, "5")
	est := CapacityEstimateForDisplay(inputs)
	if est.TotalUsers() == 0 {
		t.Error("entrada parcial: TotalUsers no debe ser 0")
	}
}

func TestCapacityEstimate_CamposVacios_RetornaCero(t *testing.T) {
	inputs := newCapacityInputs()
	est := CapacityEstimate(inputs)
	if est.TotalUsers() != 0 {
		t.Errorf("CapacityEstimate campos vacíos: TotalUsers debe ser 0, got %d", est.TotalUsers())
	}
}

// ── HandleConfirmKey ───────────────────────────────────────────────────────

func TestHandleConfirmKey_Tab_AvanzaFoco(t *testing.T) {
	focus := 0
	action := HandleConfirmKey(&focus, keyMsg(tea.KeyTab))
	if action != ConfirmActionNone {
		t.Errorf("Tab: sin cambio de pantalla, got %d", action)
	}
	if focus != 1 {
		t.Errorf("Tab: focus esperado 1, got %d", focus)
	}
}

func TestHandleConfirmKey_Enter_Instalar(t *testing.T) {
	focus := 0
	action := HandleConfirmKey(&focus, keyMsg(tea.KeyEnter))
	if action != ConfirmActionInstall {
		t.Errorf("Enter opción 0: debe instalar, got %d", action)
	}
}

func TestHandleConfirmKey_Enter_Volver_ACapacidad(t *testing.T) {
	focus := 2 // opción Volver
	// BUG FIX: Volver debe retornar ConfirmActionBack (→ P3B), NO quedarse en P3
	action := HandleConfirmKey(&focus, keyMsg(tea.KeyEnter))
	if action != ConfirmActionBack {
		t.Errorf("Enter opción 2 (Volver): debe ser ConfirmActionBack, got %d", action)
	}
	if focus != 0 {
		t.Errorf("Volver: debe resetear focus a 0, got %d", focus)
	}
}

func TestHandleConfirmKey_Esc_ACapacidad(t *testing.T) {
	focus := 1
	// BUG FIX: Esc en P4 debe volver a P3B (CapacityActionBack), NO a P3
	action := HandleConfirmKey(&focus, keyMsg(tea.KeyEsc))
	if action != ConfirmActionBack {
		t.Errorf("Esc: debe ser ConfirmActionBack, got %d", action)
	}
}

// ── Race ───────────────────────────────────────────────────────────────────

func TestUpdateWizard_Race(t *testing.T) {
	t.Run("HandleCapacityKey", func(t *testing.T) {
		for i := 0; i < 10; i++ {
			t.Run("", func(t *testing.T) {
				t.Parallel()
				inputs := newCapacityInputs()
				focus := 0
				HandleCapacityKey(inputs, &focus, keyMsg(tea.KeyTab))
			})
		}
	})
	t.Run("HandleConfirmKey", func(t *testing.T) {
		for i := 0; i < 10; i++ {
			t.Run("", func(t *testing.T) {
				t.Parallel()
				focus := 0
				HandleConfirmKey(&focus, keyMsg(tea.KeyDown))
			})
		}
	})
}
