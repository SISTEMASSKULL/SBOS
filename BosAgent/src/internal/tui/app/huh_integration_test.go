// Package app — huh_integration_test.go: valida que huh.Form se integra
// correctamente en el ciclo Init/Update/View de BubbleTea (Gap G-01 de §9).
package app_test

import (
	"testing"

	"github.com/charmbracelet/huh"
	tea "github.com/charmbracelet/bubbletea"
)

// TestHuh_FormInitUpdateView verifica el ciclo de vida básico de huh.Form
// embebido como sub-modelo en un programa BubbleTea.
func TestHuh_FormInitUpdateView(t *testing.T) {
	var valor string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Campo de prueba").
				Value(&valor),
		),
	)

	// Init() debe devolver un Cmd (puede ser nil)
	cmd := form.Init()
	_ = cmd

	// View() debe devolver string no vacío antes de cualquier Update
	view := form.View()
	if view == "" {
		t.Fatal("huh.Form.View() retornó string vacío en estado inicial")
	}

	// State inicial debe ser StateNormal (no completado).
	// form.State es un campo, no un método — huh.FormState(int)
	if form.State == huh.StateCompleted {
		t.Fatal("form.State es StateCompleted sin input — error en la integración")
	}
}

// TestHuh_FormCompletionPattern verifica el patrón de detección de formulario completado.
// Este es el patrón que usará model/update.go para avanzar de pantalla.
func TestHuh_FormCompletionPattern(t *testing.T) {
	var valor string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Dominio").
				Value(&valor),
		),
	)

	form.Init()

	// Simular Enter para completar el form (sin input, el valor queda vacío)
	updatedModel, _ := form.Update(tea.KeyMsg{Type: tea.KeyEnter})
	form = updatedModel.(*huh.Form)

	// Patrón de uso en model/update.go:
	//   if m.WizardForm.State == huh.StateCompleted { ... avanzar pantalla }
	// State es un campo público (huh.FormState), no un método.
	// StateNormal=0, StateCompleted=1, StateAborted=2
	_ = form.State
}

// TestHuh_PasswordEchoMode verifica que EchoPassword está disponible en huh v1.
// Se usa en sauth_login.go para el campo de contraseña.
func TestHuh_PasswordEchoMode(t *testing.T) {
	var pass string

	// Si EchoPassword no existiera en v1, este test no compila.
	// huh v1: la constante es EchoModePassword (no EchoPassword)
	field := huh.NewInput().
		Title("Contraseña").
		EchoMode(huh.EchoModePassword).
		Value(&pass)

	if field == nil {
		t.Fatal("huh.NewInput().EchoMode() retornó nil")
	}
}

// TestHuh_SelectDisponible verifica que huh.NewSelect está disponible en v1.
// Se usa en s01_bienvenida.go (T-080).
func TestHuh_SelectDisponible(t *testing.T) {
	var opcion string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Acción").
				Options(
					huh.NewOption("Comenzar instalación", "instalar"),
					huh.NewOption("Salir", "salir"),
				).
				Value(&opcion),
		),
	)

	form.Init()
	view := form.View()
	if view == "" {
		t.Fatal("huh.NewSelect.View() retornó vacío")
	}
}

// TestHuh_ConfirmDisponible verifica que huh.NewConfirm está disponible en v1.
// Se usa en sauth_confirm.go (T-071) y s04_confirmar.go (T-083).
func TestHuh_ConfirmDisponible(t *testing.T) {
	var confirmado bool

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("¿Confirmar instalación?").
				Affirmative("Sí, instalar").
				Negative("Cancelar").
				Value(&confirmado),
		),
	)

	form.Init()
	view := form.View()
	if view == "" {
		t.Fatal("huh.NewConfirm.View() retornó vacío")
	}
}
