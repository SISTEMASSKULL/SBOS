// Package screens — s05b_log.go: log completo con toolbar de filtros (S05B).
// Vista alternativa de S05 — activada por m.CurrentScreen=ScreenInstallLog
// o m.ViewMode="fulllog". Los helpers de log viven en s05_instalando.go.
package screens

import (
	"strconv"
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderInstallLog renderiza S05B: log completo con toolbar de filtros.
func RenderInstallLog(m tuimodel.Model) string {
	type filterBtn struct {
		label string
		level tuimodel.LogLevel
		sty   styles.Style
	}
	btns := []filterBtn{
		{"Todos",                  tuimodel.LogInfo,  styles.Info},
		{styles.IconWarn + " Warn", tuimodel.LogWarn,  styles.Warning},
		{styles.IconErr + " Error", tuimodel.LogError, styles.Error},
	}
	var btnParts []string
	for _, b := range btns {
		if m.LogFilter == b.level {
			btnParts = append(btnParts, b.sty.Bold(true).Underline(true).Render(b.label))
		} else {
			btnParts = append(btnParts, styles.Dim.Render(b.label))
		}
	}
	filterRow := strings.Join(btnParts, "  ")

	filtered := filteredLogs(m)
	counter := styles.Muted.Render(strconv.Itoa(len(filtered)) + " líneas")

	searchPart := ""
	if m.LogSearch != "" {
		searchPart = "  " + styles.Dim.Render("/") + " " + styles.AccentBold.Render(m.LogSearch)
	}

	toolbarInner := filterRow + searchPart
	padLen := m.Width - styles.TextWidth(toolbarInner) - styles.TextWidth(counter) - 2
	if padLen < 1 {
		padLen = 1
	}
	toolbar := toolbarInner + strings.Repeat(" ", padLen) + counter

	vp := m.VpLog
	bodyH := m.BodyHeight - 1
	if bodyH < 2 {
		bodyH = 2
	}
	vp.Height = bodyH

	var logLines []string
	for _, e := range filtered {
		var line string
		if m.ShowTimestamp {
			line = renderLogEntry(e, m.Width-2)
		} else {
			line = renderLogEntryNoTS(e)
		}
		if m.LogSearch != "" {
			line = highlightMatch(line, m.LogSearch)
		}
		logLines = append(logLines, line)
	}
	if len(logLines) == 0 {
		logLines = []string{styles.Dim.Render("Sin logs disponibles")}
	}
	vp.SetContent(strings.Join(logLines, "\n"))
	body := styles.JoinV(styles.PosLeft, toolbar, vp.View())
	return renderInstallFull(m, body)
}
