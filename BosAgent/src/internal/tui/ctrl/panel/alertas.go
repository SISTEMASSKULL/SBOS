package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Alertas renderiza la vista de alertas del sistema.
func Alertas(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Activas", "Historial", "Reglas", "Silenciadas"}
	tabIdx := dm.SubTab["alertas"]
	bar := dash.SubTabs(tabs, tabIdx, w)

	if tabIdx != 0 {
		return bar + "\n\n" + dash.Placeholder(tabs[tabIdx], w, h-3)
	}

	crit, warn, info := 0, 0, 0
	for _, a := range dm.Alerts {
		switch a.Severity {
		case dash.SevCritical:
			crit++
		case dash.SevWarning:
			warn++
		default:
			info++
		}
	}

	cols := dash.ColWidths(w, []int{6, 32, 22, 40})
	sevW, nameW, srcW, msgW := cols[0], cols[1], cols[2], cols[3]

	var lines []string
	lines = append(lines, bar, "")
	lines = append(lines,
		styles.JoinH(styles.PosTop,
			styles.TableHeader.Width(sevW).Render("SEV"),
			styles.TableHeader.Width(nameW).Render("NOMBRE"),
			styles.TableHeader.Width(srcW).Render("ORIGEN"),
			styles.TableHeader.Render("MENSAJE"),
		),
		dash.ColSep(w),
	)

	for _, a := range dm.Alerts {
		if a.Silenced {
			continue
		}
		msg := dash.Truncate(a.Message, msgW)
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.Cell(sevW, dash.AlertIcon(a.Severity)),
				styles.White.Width(nameW).Render(dash.Truncate(a.Name, nameW-2)),
				styles.Cell(srcW, styles.Dim.Render(dash.Truncate(a.Source, srcW-2))),
				styles.Dim.Render(msg),
			),
		)
	}

	lines = append(lines,
		"",
		dash.ColSep(w),
		fmt.Sprintf("%s %d  %s %d  %s %d  %s %d",
			styles.Error.Render("Críticas:"), crit,
			styles.Warning.Render("Warnings:"), warn,
			styles.Dim.Render("Info:"), info,
			styles.Dim.Render("Silenciadas:"), 0,
		),
	)
	return strings.Join(lines, "\n")
}
