package k8s

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// ControlPlane renderiza la vista K8s — Control Plane.
func ControlPlane(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	cols := dash.ColWidths(w, []int{34, 15, 18, 18, 15})
	nameW, stW, latW, errW, _ := cols[0], cols[1], cols[2], cols[3], cols[4]

	var lines []string
	lines = append(lines,
		styles.JoinH(styles.PosTop,
			styles.TableHeader.Width(nameW).Render("COMPONENTE"),
			styles.TableHeader.Width(stW).Render("ESTADO"),
			styles.TableHeader.Width(latW).Render("LATENCIA"),
			styles.TableHeader.Width(errW).Render("ERRORES"),
			styles.TableHeader.Render("UPTIME"),
		),
		dash.ColSep(w),
	)
	for _, c := range dm.CPComps {
		d := dash.Dot(c.Healthy, c.Warning)
		lat := "—"
		if c.LatencyMs > 0 {
			lat = fmt.Sprintf("%.0fms", c.LatencyMs)
		}
		errs := "0/min"
		if c.ErrorsMin > 0 {
			errs = styles.Warning.Render(fmt.Sprintf("%d/min", c.ErrorsMin))
		}
		var stStr string
		if !c.Healthy && !c.Warning {
			stStr = styles.StatusErr.Width(stW).Render(styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " ERROR")
		} else if c.Warning {
			stStr = styles.StatusWarn.Width(stW).Render(styles.Tint(styles.IconSync, styles.ColorStateWarnFg) + " WARN")
		} else {
			stStr = styles.StatusOK.Width(stW).Render(styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK")
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(d+" "+c.Name),
				stStr,
				styles.AccentBold.Width(latW).Render(lat),
				styles.Cell(errW, errs),
				styles.Dim.Render(c.Uptime),
			),
		)
	}
	lines = append(lines,
		"",
		dash.ColSep(w),
		styles.Dim.Render("API Server: req/s: 142  p99: 45ms  errores 5xx: 0%"),
		styles.Dim.Render("etcd: tamaño DB: 2.1GB  líderes: 1  peers: 2  health: ✔"),
	)
	return strings.Join(lines, "\n")
}
