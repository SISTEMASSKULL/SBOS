// Package screens — s04_confirmar.go: pantalla de confirmación antes de instalar (S04).
// T-083 (Bloque 8): el resumen se genera dinámicamente con WizardP4Summary(m) para que
// refleje el estado actual del Model. El huh.Form solo contiene el NewConfirm() (1 grupo).
// Panel de fases a instalar se mantiene en layout md+.
package screens

import (
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
	"bos/internal/tui/util"
)

// RenderWizardP4 renderiza la pantalla de confirmación antes de instalar (S04).
func RenderWizardP4(m tuimodel.Model) string {
	return assembleScreen(m, renderConfirmBody(m))
}

func renderConfirmBody(m tuimodel.Model) string {
	mode := styles.Mode(m.Width)
	w := m.Width
	if w == 0 {
		w = 80
	}

	summaryTitle := styles.Muted.Bold(true).Render("Confirmar instalación")
	summary := tuimodel.WizardP4Summary(&m)

	var confirmView string
	if m.WizardP4Form != nil {
		confirmView = m.WizardP4Form.View()
	} else {
		confirmView = styles.Dim.Render("  Cargando...")
	}

	leftContent := summaryTitle + "\n\n" + summary + "\n\n" + confirmView

	if mode == "xs" || mode == "sm" {
		return styles.Box.Width(w-4).Render(leftContent)
	}

	// md+: izquierda (resumen + confirm) | derecha (panel de fases)
	phW := 34
	if w < 80 {
		phW = 28
	}
	leftW := w - phW - 4

	var phLines []string
	phLines = append(phLines,
		styles.DimItalic.Render("Fases a instalar"), "",
	)
	for _, ph := range m.Phases {
		phLines = append(phLines,
			styles.Muted.Render(styles.IconCircleOpen+" "+ph.Nombre),
		)
		for _, f := range ph.Fichas {
			v := util.FichaVersions[f]
			suffix := ""
			if v != "" {
				suffix = " " + v
			}
			phLines = append(phLines,
				styles.Muted.PaddingLeft(2).Render("• "+f+suffix),
			)
		}
	}

	leftCol := styles.BoxActive.Width(leftW).Render(leftContent)
	phPanel := styles.Box.Width(phW).Render(strings.Join(phLines, "\n"))
	return styles.JoinH(styles.PosTop, leftCol, phPanel)
}
