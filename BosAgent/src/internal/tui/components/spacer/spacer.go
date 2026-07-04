// Package spacer — separadores con fondo del panel para gaps entre componentes.
package spacer

import (
	"strings"

	"bos/internal/tui/styles"

	"github.com/charmbracelet/lipgloss"
)

// Style retorna un estilo con el fondo del panel para rellenar gaps.
func Style() lipgloss.Style {
	return styles.BtnSpacer
}

// Gap renderiza un separador de N líneas de alto con el fondo del panel.
// Útil para JoinHorizontal cuando los elementos tienen distinta altura.
func Gap(lines int) string {
	if lines <= 0 {
		lines = 1
	}
	return styles.BtnSpacer.Render(strings.Repeat(" \n", lines-1) + " ")
}
