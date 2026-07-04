// Package screens — s05c_error.go: panel de error de instalación (S05C).
// Vista alternativa de S05 — activada por m.CurrentScreen=ScreenInstallErr
// o m.ViewMode="error". Los helpers de paso viven en s05_instalando.go.
package screens

import (
	"strconv"
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
	"bos/internal/tui/util"
)

// RenderInstallErr renderiza S05C: panel de error con causa, pasos y menú lateral.
func RenderInstallErr(m tuimodel.Model) string {
	if m.ErrPanel == nil {
		body := styles.Dim.Render("  No hay error activo")
		return renderInstallFull(m, body)
	}
	return renderInstallFull(m, buildErrBody(m))
}

func buildErrBody(m tuimodel.Model) string {
	fd := m.ErrPanel

	var cntDone, cntPending, cntFailed int
	for _, f := range m.Fichas {
		switch f.Status {
		case tuimodel.FichaDone:
			cntDone++
		case tuimodel.FichaPending:
			cntPending++
		case tuimodel.FichaFailed:
			cntFailed++
		}
	}

	errOpts := []string{
		"Reintentar ficha",
		"Saltar ficha",
		"Ver log completo",
		"Cancelar instalación",
	}
	errStyles := []styles.Style{
		styles.AccentBold,  // Reintentar ficha
		styles.Muted,       // Saltar ficha
		styles.Dim,         // Ver log completo
		styles.Error,       // Cancelar instalación
	}
	var menuLines []string
	for i, opt := range errOpts {
		if i == m.ErrFocus {
			menuLines = append(menuLines,
				errStyles[i].Bold(true).Render(styles.IconCursor+" "+opt))
		} else {
			menuLines = append(menuLines, styles.Dim.Render("  "+opt))
		}
	}

	mode := styles.Mode(m.Width)
	sideW := 32
	switch mode {
	case "xs":
		sideW = 0
	case "sm":
		sideW = 22
	}
	leftW := m.Width - sideW - 1
	if sideW == 0 {
		leftW = m.Width
	}

	causeStyle := styles.ErrorBanner.Copy().
		Border(styles.NormalBorder()).
		Width(leftW - 2)
	var causeLines []string
	if fd.ErrMsg != "" {
		for _, l := range strings.Split(util.WordWrap(fd.ErrMsg, leftW-6), "\n") {
			causeLines = append(causeLines,
				styles.CriticalText.Render(l))
		}
	} else {
		causeLines = []string{styles.Dim.Render("Sin información de causa")}
	}
	causeBox := causeStyle.Render(
		styles.Error.Render(styles.IconErr+" Causa") + "\n" +
			strings.Join(causeLines, "\n"),
	)

	var stepsLines []string
	stepsLines = append(stepsLines,
		styles.DimItalic.Render("Pasos ejecutados"))
	for _, s := range fd.Steps {
		stepsLines = append(stepsLines, renderStepRow(s, leftW-4))
	}
	stepsBlock := strings.Join(stepsLines, "\n")

	var recentLines []string
	for _, e := range m.Logs {
		if strings.EqualFold(e.Ficha, fd.ID) {
			recentLines = append(recentLines, renderLogEntryNoTS(e))
		}
	}
	if len(recentLines) > 12 {
		recentLines = recentLines[len(recentLines)-12:]
	}
	recentBox := ""
	if len(recentLines) > 0 {
		recentBox = styles.Box.Copy().
			Border(styles.NormalBorder()).
			Width(leftW - 2).
			Render(strings.Join(recentLines, "\n"))
	}

	mainParts := []string{causeBox, "", stepsBlock}
	if recentBox != "" {
		mainParts = append(mainParts, "", recentBox)
	}
	mainCol := strings.Join(mainParts, "\n")

	if sideW == 0 {
		return mainCol
	}

	sideLines := []string{
		styles.DimItalic.Render("Estado"),
		"",
		summaryRow("✅ Listas", strconv.Itoa(cntDone)),
		summaryRow("⏳ Pend.", strconv.Itoa(cntPending)),
		summaryRow(styles.IconErr+" Error", strconv.Itoa(cntFailed+1)),
		"",
		styles.Dim.Render("───"),
		"",
		styles.DimItalic.Render("Acciones"),
		"",
	}
	sideLines = append(sideLines, menuLines...)
	sidePanel := styles.Box.Width(sideW).Render(strings.Join(sideLines, "\n"))
	return styles.JoinH(styles.PosTop, mainCol, " ", sidePanel)
}
