// Package screens — s01_bienvenida.go: pantalla de bienvenida del wizard (S01).
// Muestra info del sistema detectado + badges de instalación + form huh de selección.
package screens

import (
	"fmt"
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderWizardP1 renderiza la pantalla de bienvenida del wizard (S01).
func RenderWizardP1(m tuimodel.Model) string {
	return assembleScreen(m, renderWelcomeBody(m))
}

func renderWelcomeBody(m tuimodel.Model) string {
	mode := styles.Mode(m.Width)
	w := m.Width
	if w == 0 {
		w = 80
	}

	info := []struct{ label, val string }{
		{"Sistema Operativo", m.Sys.OS},
		{"Kernel", m.Sys.Kernel},
		{"RAM disponible", m.Sys.RAM},
		{"Disco disponible", m.Sys.Disk},
		{"Núcleos CPU", m.Sys.CPU},
	}
	var rows []string
	for _, r := range info {
		v := r.val
		if v == "" {
			v = styles.Dim.Render("detectando...")
		}
		rows = append(rows, fmt.Sprintf("  %s %s",
			styles.Dim.Render(fmt.Sprintf("%-20s", r.label+":")),
			styles.Bold.Render(v),
		))
	}
	sysBlock := strings.Join(rows, "\n")

	badges := styles.JoinH(styles.PosTop,
		styles.BadgeAccent.Render("22 fichas"),
		styles.BadgeSubtle.Render("7 niveles del DAG"),
		styles.BadgeMuted.Render("~48 min aprox."),
	)

	var menu string
	if m.WizardP1Form != nil {
		menu = m.WizardP1Form.View()
	} else {
		menu = styles.Dim.Render("  Cargando...")
	}

	if mode == "xs" {
		return styles.JoinV(styles.PosLeft, sysBlock, "\n", badges, "\n", menu)
	}
	boxW := w - 4
	if boxW < 30 {
		boxW = 30
	}
	box := styles.Box.Width(boxW).Render(sysBlock)
	return styles.JoinV(styles.PosCenter, box, "\n", badges, "\n", menu)
}
