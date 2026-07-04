// Package screens — s02_empresa.go: formulario de datos del tenant (S02).
// T-081: migrado de textinput manual a huh.NewForm con huh.NewInput (Bloque 8).
// Los campos se vinculan a m.TenantName, TenantNIT, TenantPais, TenantDomain.
package screens

import (
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderWizardP2 renderiza el formulario de datos del tenant (S02).
func RenderWizardP2(m tuimodel.Model) string {
	return assembleScreen(m, renderP2Body(m))
}

func renderP2Body(m tuimodel.Model) string {
	w := m.Width
	if w == 0 {
		w = 80
	}
	if m.WizardP2Form == nil {
		return styles.Dim.Render("  Cargando formulario...")
	}
	return styles.BoxActive.Width(w - 4).Render(m.WizardP2Form.View())
}
