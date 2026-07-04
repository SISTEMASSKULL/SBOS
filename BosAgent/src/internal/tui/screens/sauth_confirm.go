// Package screens — sauth_confirm.go: step-up LoA 3 para acciones destructivas (P13).
// Muestra huh.NewConfirm() + contraseña cuando m.AuthLoA < 3.
// Si m.AuthLoA >= 3 la pantalla muestra acceso confirmado (la acción se ejecuta directo).
package screens

import (
	"fmt"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderAuthConfirm renderiza P13: confirmación de identidad para acciones destructivas.
// Si m.AuthLoA >= 3 muestra acceso ya confirmado — HandleUpdate no debería mostrar esta
// pantalla en ese caso, pero la función lo maneja defensivamente.
func RenderAuthConfirm(m tuimodel.Model) string {
	if m.AuthLoA >= 3 {
		body := styles.Box.Render(
			styles.AccentBold.Render("  ✓ Nivel de acceso 3 — acción autorizada"),
		)
		return assembleScreen(m, body)
	}

	var body string
	if m.AuthConfirmForm != nil {
		body = m.AuthConfirmForm.View()
	} else {
		body = styles.Box.Render(
			styles.Danger.Render("  Confirmar acción privilegiada") + "\n\n" +
				styles.Dim.Render(fmt.Sprintf("  LoA actual: %d  →  requerido: 3", m.AuthLoA)) + "\n\n" +
				styles.Dim.Render("  Contraseña / PIN") + "\n" +
				styles.Dim.Render("  ────────────────────────────\n\n") +
				styles.Dim.Render("  [ Enter ] confirmar   [ Esc ] cancelar"),
		)
	}
	if m.AuthErr != "" {
		body += "\n" + styles.Error.Render("  ✗ "+m.AuthErr)
	}
	return assembleScreen(m, body)
}
