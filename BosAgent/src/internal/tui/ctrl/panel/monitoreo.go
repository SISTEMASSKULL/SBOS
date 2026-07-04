package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Monitoreo renderiza la vista Monitoreo — Series Temporales.
func Monitoreo(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"CPU", "RAM", "Red", "K8s"}
	tabIdx := dm.SubTab["mon"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	sparkW := w - 12
	if sparkW < 20 {
		sparkW = 20
	}

	switch tabIdx {
	case 0: // CPU
		cur, avg, minV, maxV := dash.SparklineStats(dm.MonCPU)
		lines = append(lines, dash.SectionHeader("CPU — HISTÓRICO (últimos 30s)"), "")
		lines = append(lines,
			"",
			fmt.Sprintf("  Actual: %s   Promedio: %s   Min: %s   Max: %s",
				dash.ColorPct(cur),
				styles.Dim.Render(fmt.Sprintf("%.0f%%", avg)),
				styles.MetricOK.Render(fmt.Sprintf("%.0f%%", minV)),
				dash.ColorPct(maxV),
			),
			"",
			"  "+dash.SparklineASCII(dm.MonCPU, sparkW, dash.ColorForPct(cur)),
			"",
			dash.SectionHeader("CPU POR CORE (actual)"),
			"",
		)
		barW := sparkW / 2
		for i, pct := range dm.CPU.Cores {
			lines = append(lines, fmt.Sprintf("  core-%d  %s  %3.0f%%",
				i, dash.MiniBar(pct, barW, dash.ColorForPct(pct)), pct))
		}
	case 1: // RAM
		cur, avg, minV, maxV := dash.SparklineStats(dm.MonRAM)
		lines = append(lines, dash.SectionHeader("RAM — HISTÓRICO (últimos 30s)"), "")
		lines = append(lines,
			"",
			fmt.Sprintf("  Actual: %s   Promedio: %s   Min: %s   Max: %s",
				dash.ColorPct(cur),
				styles.Dim.Render(fmt.Sprintf("%.0f%%", avg)),
				styles.MetricOK.Render(fmt.Sprintf("%.0f%%", minV)),
				dash.ColorPct(maxV),
			),
			"",
			"  "+dash.SparklineASCII(dm.MonRAM, sparkW, dash.ColorForPct(cur)),
			"",
			styles.Dim.Render(fmt.Sprintf("  Total: %.1f GB  Usada: %.1f GB  Libre: %.1f GB",
				dm.Mem.TotalGB, dm.Mem.UsedGB, dm.Mem.FreeGB)),
		)
	case 2: // Red
		cur, avg, minV, maxV := dash.SparklineStats(dm.MonNet)
		lines = append(lines, dash.SectionHeader("RED — THROUGHPUT (últimos 30s, MB/s TX)"), "")
		lines = append(lines,
			"",
			fmt.Sprintf("  TX actual: %s   Promedio: %.1f MB/s   Min: %.1f MB/s   Max: %.1f MB/s",
				styles.MetricTX.Render(fmt.Sprintf("%.1f MB/s", cur)),
				avg, minV, maxV,
			),
			"",
			"  "+dash.SparklineASCII(dm.MonNet, sparkW, styles.ColorStateOKFg),
			"",
			dash.SectionHeader("INTERFACES"),
			"",
		)
		for _, ni := range dm.NetInterfaces {
			if ni.TXBytesS > 0 || ni.Name == "ens3" {
				lines = append(lines, fmt.Sprintf("  %-8s  TX: %-14s  RX: %-14s  %s",
					styles.White.Render(ni.Name),
					dash.FormatBytesPS(ni.TXBytesS),
					dash.FormatBytesPS(ni.RXBytesS),
					styles.Dim.Render(ni.IPAddr),
				))
			}
		}
	default: // K8s
		if len(dm.MonPods) > 0 {
			floatPods := make([]float64, len(dm.MonPods))
			for i, v := range dm.MonPods {
				floatPods[i] = float64(v)
			}
			cur, avg, minV, maxV := dash.SparklineStats(floatPods)
			lines = append(lines, dash.SectionHeader("K8s — PODS ACTIVOS (últimos 30s)"), "")
			lines = append(lines,
				"",
				fmt.Sprintf("  Actual: %s pods   Promedio: %.0f   Min: %.0f   Max: %.0f",
					styles.AccentBold.Render(fmt.Sprintf("%.0f", cur)),
					avg, minV, maxV,
				),
				"",
				"  "+dash.SparklineASCII(floatPods, sparkW, styles.ColorStateInfoFg),
			)
		}
		lines = append(lines, "", dash.SectionHeader("WORKLOADS ACTIVOS"), "")
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
		alertCount := 0
		for _, a := range dm.Alerts {
			if !a.Silenced {
				alertCount++
			}
		}
		lines = append(lines,
			fmt.Sprintf("  %s %d Running   %s %d Pending   %s %d Failed   Total: %d",
				styles.Tint(styles.IconDotActive, styles.ColorAccentText), running,
				styles.Tint(styles.IconDotPending, styles.ColorStateWarnFg), pending,
				styles.Tint(styles.IconDotError, styles.ColorStateErrFg), failed,
				len(dm.Pods),
			),
			"",
			fmt.Sprintf("  Nodos: %d/%d  Ready   HPA activos: %d   Alertas: %d",
				len(dm.Nodes), len(dm.Nodes), len(dm.HPAs), alertCount,
			),
		)
	}
	return strings.Join(lines, "\n")
}
