// Package screens — s03_admin.go: formulario de cuenta de administrador (S03).
// T-082: migrado de textinput manual a huh.NewForm con huh.EchoModePassword (Bloque 8).
// Los campos se vinculan a m.AdminEmail, AdminNombre, AdminPassword, AdminPasswordConfirm, MFAEnabled.
package screens

import (
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderWizardP3 renderiza el formulario de cuenta de administrador (S03).
func RenderWizardP3(m tuimodel.Model) string {
	return assembleScreen(m, renderP3Body(m))
}

func renderP3Body(m tuimodel.Model) string {
	w := m.Width
	if w == 0 {
		w = 80
	}
	if m.WizardP3Form == nil {
		return styles.Dim.Render("  Cargando formulario...")
	}
	return styles.BoxActive.Width(w - 4).Render(m.WizardP3Form.View())
}
