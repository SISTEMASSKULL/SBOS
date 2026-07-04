package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"

)

// Jobs renderiza la vista de instalaciones activas y su historial.
func Jobs(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Activos", "Historial", "Pendientes"}
	tabIdx := dm.SubTab["jobs"]
	tabBar := dash.SubTabs(tabs, tabIdx, w)

	var lines []string
	lines = append(lines, tabBar, "")

	switch tabIdx {
	case 1: // Historial
		lines = append(lines, dash.SectionHeader("HISTORIAL DE INSTALACIONES"), "")
		hist := []struct{ name, status, dur, ts string }{
			{"calico/setup.sh", "OK", "4m 12s", "2026-06-12 10:28"},
			{"postgresql/init.sh", "OK", "2m 45s", "2026-06-12 10:23"},
			{"redis/init.sh", "OK", "1m 18s", "2026-06-12 10:21"},
			{"keycloak/deploy.sh", "OK", "6m 02s", "2026-06-12 10:15"},
			{"vault/init.sh", "FAILED", "0m 45s", "2026-06-11 22:10"},
		}
		nW := w * 35 / 100
		for _, e := range hist {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.StatusOK.Render(" "+e.status)
			if e.status != "OK" {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + styles.StatusErr.Render(" "+e.status)
			}
			lines = append(lines, fmt.Sprintf("  %-*s  %-8s  %-18s  %s",
				nW, dash.Truncate(e.name, nW-1),
				styles.Dim.Render(e.dur),
				styles.Dim.Render(e.ts),
				st,
			))
		}
	case 2: // Pendientes
		lines = append(lines, dash.SectionHeader("INSTALACIONES PENDIENTES"), "")
		pending := []string{"kong/deploy.sh", "linkerd/install.sh", "grafana/deploy.sh"}
		if len(pending) == 0 {
			lines = append(lines, "  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+styles.Success.Render(" Sin instalaciones pendientes"))
		}
		for _, p := range pending {
			lines = append(lines, "  "+styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled)+" "+p)
		}
	default: // Activos
		lines = append(lines, dash.SectionHeader("INSTALACIONES ACTIVAS"), "")
		if len(dm.Jobs) == 0 {
			lines = append(lines, styles.Dim.Render("  Sin instalaciones activas"))
		}
		nameW := w * 25 / 100
		if nameW < 16 {
			nameW = 16
		}
		barW := w - nameW - 16
		if barW < 4 {
			barW = 4
		}
		for _, j := range dm.Jobs {
			icon := styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled)
			if j.Active {
				icon = styles.Tint(styles.IconSync, styles.ColorStateWarnFg)
			}
			filled := int(float64(barW) * float64(j.Pct) / 100)
			bar := styles.ProgressFill.Render(strings.Repeat("█", filled)) +
				styles.Dim.Render(strings.Repeat("░", barW-filled))
			lines = append(lines,
				fmt.Sprintf("%s %s  [%s] %3d%%  %s items",
					icon,
					styles.White.Width(nameW).Render(j.Name),
					bar, j.Pct,
					styles.Dim.Render(j.Items),
				),
			)
		}
	}
	return strings.Join(lines, "\n")
}
