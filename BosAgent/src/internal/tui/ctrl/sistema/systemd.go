package sistema

import (
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Systemd renderiza la vista Sistema OS — Systemd.
func Systemd(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Activos", "Fallidos", "Todos"}
	tabIdx := dm.SubTab["os-svc"]
	bar := dash.SubTabs(tabs, tabIdx, w)

	var filtered []dash.Service
	switch tabIdx {
	case 1: // Fallidos
		for _, s := range dm.Services {
			if s.Failed {
				filtered = append(filtered, s)
			}
		}
	case 2: // Todos
		filtered = dm.Services
	default: // Activos
		for _, s := range dm.Services {
			if s.Active && !s.Failed {
				filtered = append(filtered, s)
			}
		}
	}

	cols := dash.ColWidths(w, []int{35, 20, 45})
	nameW, stW, _ := cols[0], cols[1], cols[2]

	var lines []string
	lines = append(lines, bar, "")
	lines = append(lines,
		styles.JoinH(styles.PosTop,
			styles.TableHeader.Width(nameW).Render("SERVICIO"),
			styles.TableHeader.Width(stW).Render("ESTADO"),
			styles.TableHeader.Render("DESDE"),
		),
		dash.ColSep(w),
	)
	if len(filtered) == 0 {
		lines = append(lines, styles.Dim.Render("  Sin servicios en esta categoría"))
	}
	for _, s := range filtered {
		icon := styles.Tint(styles.IconOK, styles.ColorStateOKFg)
		state := styles.StatusOK.Render("running")
		if s.Failed {
			icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
			state = styles.StatusErr.Render("failed")
		} else if !s.Active {
			icon = styles.Tint(styles.IconSync, styles.ColorStateWarnFg)
			state = styles.StatusWarn.Render("stopped")
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(icon+" "+s.Name),
				styles.Cell(stW, state),
				styles.Dim.Render(s.Since),
			),
		)
	}
	return strings.Join(lines, "\n")
}
