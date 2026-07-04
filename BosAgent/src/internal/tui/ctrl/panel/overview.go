package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Overview renderiza la vista de resumen del sistema.
func Overview(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	if w < 20 {
		return dash.Placeholder("Overview", w, h)
	}
	half := w / 2

	colW := (w - 3) / 4
	if colW < 8 {
		colW = 8
	}

	cpuAvg := 0.0
	for _, c := range dm.CPU.Cores {
		cpuAvg += c
	}
	if len(dm.CPU.Cores) > 0 {
		cpuAvg /= float64(len(dm.CPU.Cores))
	}
	memPct := 0.0
	if dm.Mem.TotalGB > 0 {
		memPct = dm.Mem.UsedGB / dm.Mem.TotalGB * 100
	}
	diskPct := 0.0
	if len(dm.Disks) > 0 && dm.Disks[0].TotalGB > 0 {
		diskPct = dm.Disks[0].UsedGB / dm.Disks[0].TotalGB * 100
	}

	cpu := styles.JoinV(styles.PosLeft,
		dash.SectionHeader("CPU"),
		dash.Gauge(cpuAvg, colW),
		styles.Dim.Render(fmt.Sprintf("%d cores  load: %.1f", len(dm.CPU.Cores), dm.CPU.Load1)),
		styles.Dim.Render(fmt.Sprintf("uptime: %s", dash.FormatDur(dm.CPU.Uptime))),
	)
	ram := styles.JoinV(styles.PosLeft,
		dash.SectionHeader("RAM"),
		dash.GaugeColored(memPct, colW, dash.ColorForPct(memPct)),
		styles.Dim.Render(fmt.Sprintf("%.1f/%.1f GB", dm.Mem.UsedGB, dm.Mem.TotalGB)),
		styles.Dim.Render(fmt.Sprintf("libre: %.1f GB", dm.Mem.FreeGB)),
	)
	disk := styles.JoinV(styles.PosLeft,
		dash.SectionHeader("DISCO"),
		dash.GaugeColored(diskPct, colW, dash.ColorForPct(diskPct)),
		styles.Dim.Render(fmt.Sprintf("%.0f/%.0f GB", dm.Disks[0].UsedGB, dm.Disks[0].TotalGB)),
		styles.Dim.Render("mount: /"),
	)
	red := styles.JoinV(styles.PosLeft,
		dash.SectionHeader("RED"),
		styles.MetricTX.Render("↑ "+dash.FormatBytesPS(dm.Net.TXBytesS)),
		styles.AccentBold.Render("↓ "+dash.FormatBytesPS(dm.Net.RXBytesS)),
		styles.Dim.Render(dm.Net.Iface),
	)

	row1 := styles.JoinH(styles.PosTop,
		styles.Cell(colW, cpu),
		styles.Cell(colW, ram),
		styles.Cell(colW, disk),
		styles.Cell(colW, red),
	)

	leftW := half - 2
	rightW := w - half - 3

	var nodeLines []string
	nodeLines = append(nodeLines, dash.SectionHeader("NODOS K8s"), "")
	for _, n := range dm.Nodes {
		nd := styles.Tint(styles.IconDotActive, styles.ColorAccentText)
		if !n.Ready {
			nd = styles.Tint(styles.IconDotError, styles.ColorStateErrFg)
		}
		nodeLines = append(nodeLines,
			fmt.Sprintf("%s %-8s  CPU:%2.0f%%  MEM:%2.0f%%  %d/%d pods",
				nd, n.Name, n.CPUPct, n.MemPct, n.Pods, n.MaxPods),
		)
	}
	nodesStr := strings.Join(nodeLines, "\n")

	running, pending, failed := 0, 0, 0
	for _, p := range dm.Pods {
		switch p.Status {
		case dash.PodRunning:
			running++
		case dash.PodPending:
			pending++
		case dash.PodFailed:
			failed++
		}
	}
	total := len(dm.Pods)
	maxBar := rightW - 18
	if maxBar < 4 {
		maxBar = 4
	}
	var podLines []string
	podLines = append(podLines, dash.SectionHeader("PODS — RESUMEN"), "")
	podLines = append(podLines,
		fmt.Sprintf("Running: %3d  %s %s", running,
			dash.MiniBar(float64(running)/float64(total)*100, maxBar, styles.ColorStateOKFg),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)),
		fmt.Sprintf("Pending: %3d  %s %s", pending,
			dash.MiniBar(float64(pending)/float64(total)*100, maxBar, styles.ColorStateWarnFg),
			styles.Tint(styles.IconSync, styles.ColorStateWarnFg)),
		fmt.Sprintf("Error:   %3d  %s %s", failed,
			dash.MiniBar(float64(failed)/float64(total)*100, maxBar, styles.ColorStateErrFg),
			styles.Tint(styles.IconErr, styles.ColorStateErrFg)),
		"",
		styles.Dim.Render(fmt.Sprintf("Total:  %3d", total)),
	)
	podsStr := strings.Join(podLines, "\n")

	row2 := styles.JoinH(styles.PosTop,
		styles.Cell(leftW, nodesStr),
		dash.RightPane(podsStr, rightW),
	)

	var svcLines []string
	svcLines = append(svcLines, dash.SectionHeader("SERVICIOS SYSTEMD"), "")
	for _, s := range dm.Services {
		icon := styles.Tint(styles.IconOK, styles.ColorStateOKFg)
		if s.Failed {
			icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
		} else if !s.Active {
			icon = styles.Tint(styles.IconSync, styles.ColorStateWarnFg)
		}
		svcLines = append(svcLines,
			fmt.Sprintf("%s %s %s", icon,
				styles.White.Width(leftW-10).Render(s.Name),
				styles.Dim.Render(func() string {
					if s.Failed {
						return "failed"
					}
					if s.Active {
						return "running"
					}
					return "stopped"
				}())),
		)
	}
	svcStr := strings.Join(svcLines, "\n")

	var hpaLines []string
	hpaLines = append(hpaLines, dash.SectionHeader("HPA / VPA — AUTOSCALING"), "")
	for _, h := range dm.HPAs {
		icon := dash.HPADot(h.Status)
		var extra string
		switch h.Status {
		case dash.HPAScaling:
			extra = fmt.Sprintf("%d→%d replicas", h.MinReplicas, h.Current)
		case dash.HPAAtMax:
			extra = fmt.Sprintf("CPU:%d%%→↑", h.CPUCurrent)
		default:
			extra = "stable"
		}
		hpaLines = append(hpaLines,
			fmt.Sprintf("%s %s  HPA  %s",
				icon,
				styles.White.Width(rightW-14).Render(h.Name),
				styles.Dim.Render(extra)),
		)
	}
	hpaStr := strings.Join(hpaLines, "\n")

	row3 := styles.JoinH(styles.PosTop,
		styles.Cell(leftW, svcStr),
		dash.RightPane(hpaStr, rightW),
	)

	row4 := ""
	for _, j := range dm.Jobs {
		if j.Active {
			overhead := 1 + 13 + len(j.Name) + 3 + 2 + 4 + 5 + len(j.Items) + 6
			barW := w - overhead
			if barW < 4 {
				barW = 4
			}
			filled := int(float64(barW) * float64(j.Pct) / 100.0)
			bar := styles.ProgressFill.Render(strings.Repeat("█", filled)) +
				styles.Dim.Render(strings.Repeat("░", barW-filled))
			row4 = styles.Tint(styles.IconSync, styles.ColorStateWarnFg) + " Instalando: " +
				styles.TableHeader.Render(j.Name) +
				"  [" + bar + "] " +
				styles.AccentBold.Render(fmt.Sprintf("%d%%", j.Pct)) +
				"  │  " + styles.Dim.Render(j.Items+" items")
			break
		}
	}

	sections := []string{
		row1,
		dash.ColSep(w),
		row2,
		dash.ColSep(w),
		row3,
	}
	if row4 != "" {
		sections = append(sections, dash.ColSep(w), row4)
	}
	return strings.Join(sections, "\n")
}
