// Package screens — sauth_login.go: pantalla de login antes del dashboard (P12).
// Usa huh.NewForm() con campo usuario (echo normal) y contraseña (EchoModePassword).
// El form vive en m.AuthForm y se inicializa en HandleUpdate al entrar a ScreenAuthLogin.
package screens

import (
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderAuthLogin renderiza P12: formulario de login bAuth.
// Si m.AuthForm es nil muestra un placeholder hasta que HandleUpdate lo inicialice.
// Si m.AuthErr no está vacío muestra el error debajo del formulario.
func RenderAuthLogin(m tuimodel.Model) string {
	var body string
	if m.AuthForm != nil {
		body = m.AuthForm.View()
	} else {
		body = styles.Box.Render(
			styles.Bold.Render("  Acceso al SBOS") + "\n\n" +
				styles.Dim.Render("  Cargando formulario..."),
		)
	}
	if m.AuthErr != "" {
		body += "\n" + styles.Error.Render("  ✗ "+m.AuthErr)
	}
	return assembleScreen(m, body)
}
