// Package model — update_wizard.go: lógica de teclas del wizard de instalación.
// Contiene las funciones puras para P3B (capacidad) y P4 (confirmar).
//
// Regla de arquitectura (POLICY §4.4): la lógica de negocio de navegación y validación
// NO vive en los archivos de pantalla ni en install_ui_impl.go.
// Vive aquí, parametrizada, sin dependencia del struct local de cmd/bosctl.
//
// Extracción de cmd/bosctl/install_ui_impl.go en M1-CAP-FIX (BOS-REPAIR).
package model

import (
	"strconv"
	"strings"

	"bos/internal/capacity"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

// ── P3B — Capacidad ────────────────────────────────────────────────────────

// CapacityAction es el resultado de HandleCapacityKey.
type CapacityAction int

const (
	CapacityActionNone    CapacityAction = iota // Sin cambio de pantalla
	CapacityActionAdvance                       // Avanzar a P4 (todas las validaciones ok)
	CapacityActionBack                          // Volver a P3 (cuenta admin)
)

// HandleCapacityKey maneja teclas en la pantalla P3B (estimados de capacidad).
//
// Comportamiento:
//   - Tab / ↓      : siguiente campo
//   - ShiftTab / ↑ : campo anterior
//   - Enter (0–2)  : siguiente campo — navega, NO avanza de pantalla
//   - Enter (3)    : valida todos los campos y avanza a P4
//   - Esc          : volver a P3 (cuenta admin)
//
// Parámetros:
//   - inputs : slice de textinput — 4 campos: tenants, companies, branches, users
//   - focus  : puntero al índice del campo activo
//   - msg    : tecla recibida
//
// Retorna la acción y un mensaje de error si la validación falla en Enter (3).
func HandleCapacityKey(
	inputs []textinput.Model,
	focus *int,
	msg tea.KeyMsg,
) (action CapacityAction, errMsg string) {
	n := len(inputs)
	if n == 0 {
		return CapacityActionNone, ""
	}

	switch msg.Type {
	case tea.KeyTab, tea.KeyDown:
		inputs[*focus].Blur()
		*focus = (*focus + 1) % n
		inputs[*focus].Focus()

	case tea.KeyShiftTab, tea.KeyUp:
		inputs[*focus].Blur()
		*focus = (*focus + n - 1) % n
		inputs[*focus].Focus()

	case tea.KeyEnter:
		if *focus < n-1 {
			// Campos intermedios: Enter navega al siguiente (no avanza de pantalla)
			inputs[*focus].Blur()
			*focus++
			inputs[*focus].Focus()
		} else {
			// Último campo: validar todo y avanzar
			if err := ValidateCapacityInputs(inputs, focus); err != "" {
				return CapacityActionNone, err
			}
			return CapacityActionAdvance, ""
		}

	case tea.KeyEsc:
		inputs[*focus].Blur()
		*focus = 0
		return CapacityActionBack, ""
	}

	return CapacityActionNone, ""
}

// ValidateCapacityInputs verifica que todos los campos sean enteros positivos.
// Si un campo es inválido, ajusta *focus al campo con error y retorna el mensaje.
func ValidateCapacityInputs(inputs []textinput.Model, focus *int) string {
	for i, inp := range inputs {
		v := strings.TrimSpace(inp.Value())
		if v == "" {
			*focus = i
			inputs[i].Focus()
			return "Todos los estimados son obligatorios"
		}
		n := 0
		for _, ch := range v {
			if ch < '0' || ch > '9' {
				*focus = i
				inputs[i].Focus()
				return "Solo se permiten números enteros positivos"
			}
			n = n*10 + int(ch-'0')
		}
		if n == 0 {
			*focus = i
			inputs[i].Focus()
			return "El valor debe ser mayor que cero"
		}
	}
	return ""
}

// CapacityEstimate construye el Estimate con los valores reales del formulario.
// Los campos vacíos o inválidos resultan en 0 — correcto para persistir.
func CapacityEstimate(inputs []textinput.Model) capacity.Estimate {
	pi := func(i int) int {
		if i >= len(inputs) {
			return 0
		}
		v, _ := strconv.Atoi(strings.TrimSpace(inputs[i].Value()))
		if v < 0 {
			return 0
		}
		return v
	}
	return capacity.Estimate{
		Tenants:            pi(0),
		CompaniesPerTenant: pi(1),
		BranchesPerCompany: pi(2),
		UsersPerBranch:     pi(3),
	}
}

// CapacityEstimateForDisplay construye el Estimate usando 1 como mínimo por campo.
// Evita que el producto sea 0 cuando la entrada es parcial, dando retroalimentación
// progresiva al usuario mientras completa el formulario.
// NO usar para persistir ni para control de admisión — solo para visualización.
func CapacityEstimateForDisplay(inputs []textinput.Model) capacity.Estimate {
	pi := func(i int) int {
		if i >= len(inputs) {
			return 1
		}
		v, _ := strconv.Atoi(strings.TrimSpace(inputs[i].Value()))
		if v <= 0 {
			return 1
		}
		return v
	}
	return capacity.Estimate{
		Tenants:            pi(0),
		CompaniesPerTenant: pi(1),
		BranchesPerCompany: pi(2),
		UsersPerBranch:     pi(3),
	}
}

// ── P4 — Confirmar ─────────────────────────────────────────────────────────

// ConfirmAction es el resultado de HandleConfirmKey.
type ConfirmAction int

const (
	ConfirmActionNone    ConfirmAction = iota // Sin cambio de pantalla
	ConfirmActionInstall                      // Iniciar bootstrap (opciones 0 y 1)
	ConfirmActionBack                         // Volver a P3B (calculadora de capacidad)
)

// HandleConfirmKey maneja teclas en la pantalla P4 (confirmar instalación).
//
// Opciones: 0=Instalar, 1=Automático, 2=Volver
//
// CORRECCIÓN BUG: "Volver" retorna a ScreenWizardCapacity (P3B).
// La pantalla anterior al confirmar es la calculadora, NO la cuenta admin (P3).
func HandleConfirmKey(confirmFocus *int, msg tea.KeyMsg) ConfirmAction {
	switch msg.Type {
	case tea.KeyUp, tea.KeyShiftTab:
		*confirmFocus = (*confirmFocus + 2) % 3

	case tea.KeyDown, tea.KeyTab:
		*confirmFocus = (*confirmFocus + 1) % 3

	case tea.KeyEnter:
		switch *confirmFocus {
		case 0, 1:
			return ConfirmActionInstall
		case 2:
			*confirmFocus = 0
			return ConfirmActionBack
		}

	case tea.KeyEsc:
		*confirmFocus = 0
		return ConfirmActionBack
	}

	switch msg.String() {
	case "a", "A":
		return ConfirmActionInstall
	}

	return ConfirmActionNone
}
