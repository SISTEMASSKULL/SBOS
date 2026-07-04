package sistema

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Metricas renderiza la vista Sistema OS — Métricas.
func Metricas(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"CPU", "RAM", "Swap", "I/O"}
	tabIdx := dm.SubTab["os-met"]
	bar := dash.SubTabs(tabs, tabIdx, w)

	half := w / 2
	leftW := half - 2
	rightW := w - half - 3

	switch tabIdx {
	case 0: // CPU
		var coreLines []string
		coreLines = append(coreLines, dash.SectionHeader("CPU POR CORE"), "")
		for i, pct := range dm.CPU.Cores {
			warn := ""
			if pct >= 85 {
				warn = " " + styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
			}
			coreLines = append(coreLines,
				fmt.Sprintf("core-%d  %s %3.0f%%%s",
					i,
					dash.MiniBar(pct, 12, dash.ColorForPct(pct)),
					pct, warn),
			)
		}
		coreLines = append(coreLines,
			"",
			styles.Dim.Render(fmt.Sprintf("Load avg: %.1f  %.1f  %.1f", dm.CPU.Load1, dm.CPU.Load5, dm.CPU.Load15)),
			styles.Dim.Render(fmt.Sprintf("Uptime: %s", dash.FormatDur(dm.CPU.Uptime))),
			styles.Dim.Render(fmt.Sprintf("Procs: %d total  Threads: %d", dm.CPU.Procs, dm.CPU.Threads)),
		)
		coresStr := strings.Join(coreLines, "\n")

		var redLines []string
		redLines = append(redLines, dash.SectionHeader(fmt.Sprintf("RED: %s", dm.Net.Iface)), "")
		redLines = append(redLines,
			styles.MetricTX.Render(fmt.Sprintf("↑ TX: %s", dash.FormatBytesPS(dm.Net.TXBytesS)))+
				styles.Dim.Render(fmt.Sprintf("  Total: %.1f GB", dm.Net.TXTotalGB)),
			styles.AccentBold.Render(fmt.Sprintf("↓ RX: %s", dash.FormatBytesPS(dm.Net.RXBytesS)))+
				styles.Dim.Render(fmt.Sprintf("  Total: %.1f GB", dm.Net.RXTotalGB)),
		)
		redStr := strings.Join(redLines, "\n")

		return bar + "\n\n" +
			styles.JoinH(styles.PosTop,
				styles.Cell(leftW, coresStr),
				dash.RightPane(redStr, rightW),
			)

	case 1: // RAM
		memPct := dm.Mem.UsedGB / dm.Mem.TotalGB * 100
		memLines := []string{
			dash.SectionHeader("MEMORIA RAM"),
			"",
			fmt.Sprintf("Total:  %.1f GB", dm.Mem.TotalGB),
			fmt.Sprintf("Usada:  %.1f GB  %s", dm.Mem.UsedGB, dash.Gauge(memPct, 24)),
			fmt.Sprintf("Libre:  %.1f GB", dm.Mem.FreeGB),
			fmt.Sprintf("Buff:   %.1f GB", dm.Mem.BuffGB),
			"",
			styles.Dim.Render(fmt.Sprintf("Uso: %.1f%%  — %.1f/%.1f GB", memPct, dm.Mem.UsedGB, dm.Mem.TotalGB)),
		}
		return bar + "\n\n" + strings.Join(memLines, "\n")

	case 2: // Swap
		swapPct := 0.0
		if dm.Mem.SwapTotal > 0 {
			swapPct = dm.Mem.SwapUsed / dm.Mem.SwapTotal * 100
		}
		swapLines := []string{
			dash.SectionHeader("SWAP"),
			"",
			fmt.Sprintf("Total:  %.1f GB", dm.Mem.SwapTotal),
			fmt.Sprintf("Usada:  %.1f GB  %s", dm.Mem.SwapUsed, dash.Gauge(swapPct, 24)),
			fmt.Sprintf("Libre:  %.1f GB", dm.Mem.SwapTotal-dm.Mem.SwapUsed),
			"",
			styles.Dim.Render("vm.swappiness = 10  (conservador — recomendado para servidores)"),
		}
		return bar + "\n\n" + strings.Join(swapLines, "\n")

	default: // I/O
		mountW := 10
		barW := w - mountW - 22
		if barW < 8 {
			barW = 8
		}
		ioLines := []string{
			dash.SectionHeader("I/O DISCO"), "",
			"  " + styles.Dim.Render("Disco principal: ") + styles.White.Render("sda"),
			"",
			"  " + styles.Dim.Render("Lecturas:   ") + "45.2 MB/s   " + styles.Dim.Render("ops: 1240/s"),
			"  " + styles.Dim.Render("Escrituras: ") + "12.1 MB/s   " + styles.Dim.Render("ops:  380/s"),
			"  " + styles.Dim.Render("I/O wait:   ") + styles.MetricOK.Render("0.8%"),
			"  " + styles.Dim.Render("Queue:      ") + styles.MetricOK.Render("0.12"),
			"",
			dash.SectionHeader("USO POR PARTICION"), "",
		}
		for _, d := range dm.Disks {
			pct := d.UsedGB / d.TotalGB * 100
			ioLines = append(ioLines,
				fmt.Sprintf("  %s %s  %.0f/%.0f GB",
					styles.White.Width(mountW).Render(d.Mount),
					dash.GaugeColored(pct, barW, dash.ColorForPct(pct)),
					d.UsedGB, d.TotalGB,
				),
			)
		}
		return bar + "\n\n" + strings.Join(ioLines, "\n")
	}
}
