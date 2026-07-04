package k8s

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Workloads renderiza la vista K8s — Workloads.
func Workloads(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Pods", "Deployments", "StatefulSets", "DaemonSets", "Jobs", "CronJobs"}
	tabIdx := dm.SubTab["k8s-wl"]
	bar := dash.SubTabs(tabs, tabIdx, w)

	if tabIdx != 0 {
		return bar + "\n\n" + dash.Placeholder(tabs[tabIdx], w, h-3)
	}

	cols := dash.ColWidths(w, []int{27, 17, 12, 9, 10, 9, 9, 7})
	nameW, nsW, stW, rdyW, rstW, cpuW, memW, ageW :=
		cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6], cols[7]

	hdr := styles.TableHeader
	var lines []string
	lines = append(lines, bar, "")
	lines = append(lines,
		styles.JoinH(styles.PosTop,
			hdr.Width(nameW).Render("NOMBRE"),
			hdr.Width(nsW).Render("NAMESPACE"),
			hdr.Width(stW).Render("ESTADO"),
			hdr.Width(rdyW).Render("READY"),
			hdr.Width(rstW).Render("RESTART"),
			hdr.Width(cpuW).Render("CPU"),
			hdr.Width(memW).Render("MEM"),
			hdr.Width(ageW).Render("AGE"),
		),
		dash.ColSep(w),
	)
	for _, p := range dm.Pods {
		cpu := "—"
		if p.CPUm > 0 {
			cpu = fmt.Sprintf("%dm", p.CPUm)
		}
		mem := "—"
		if p.MemMi > 0 {
			mem = fmt.Sprintf("%dMi", p.MemMi)
		}
		restarts := styles.Dim.Render("0")
		if p.Restarts > 0 && p.Restarts < 5 {
			restarts = styles.StatusWarn.Render(fmt.Sprintf("%d", p.Restarts))
		} else if p.Restarts >= 5 {
			restarts = styles.StatusErr.Render(fmt.Sprintf("%d", p.Restarts))
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.Cell(nameW, dash.PodDot(p.Status)+" "+dash.Truncate(p.Name, nameW-3)),
				styles.Cell(nsW, styles.Dim.Render(dash.Truncate(p.Namespace, nsW-2))),
				styles.Cell(stW, podStatusStr(p.Status)),
				styles.Cell(rdyW, styles.Dim.Render(p.Ready)),
				styles.Cell(rstW, restarts),
				styles.Cell(cpuW, styles.Dim.Render(cpu)),
				styles.Cell(memW, styles.Dim.Render(mem)),
				styles.Cell(ageW, styles.Dim.Render(p.Age)),
			),
		)
	}
	return strings.Join(lines, "\n")
}

func podStatusStr(s dash.PodStatus) string {
	switch s {
	case dash.PodRunning:
		return styles.StatusOK.Render("Running")
	case dash.PodPending:
		return styles.StatusWarn.Render("Pending")
	default:
		return styles.StatusErr.Render("Error")
	}
}
