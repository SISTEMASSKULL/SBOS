package sistema

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Disco renderiza la vista Sistema OS — Disco.
func Disco(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Particiones", "I/O", "Inodes"}
	tabIdx := dm.SubTab["os-disk"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Particiones
		lines = append(lines, dash.SectionHeader("PARTICIONES Y USO DE DISCO"), "")
		cols := dash.ColWidths(w, []int{14, 18, 60, 8})
		mountW, sizeW, barW, _ := cols[0], cols[1], cols[2], cols[3]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(mountW).Render("MOUNT"),
				styles.TableHeader.Width(sizeW).Render("USADO/TOTAL"),
				styles.TableHeader.Width(barW).Render("USO"),
				styles.TableHeader.Render("%"),
			),
			dash.ColSep(w),
		)
		for _, d := range dm.Disks {
			pct := 0.0
			if d.TotalGB > 0 {
				pct = d.UsedGB / d.TotalGB * 100
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(mountW).Render(dash.Truncate(d.Mount, mountW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", sizeW, fmt.Sprintf("%.0f/%.0f GB", d.UsedGB, d.TotalGB))),
				dash.GaugeColored(pct, barW, dash.ColorForPct(pct))+"  ",
				dash.ColorPct(pct),
			))
		}
	case 1: // I/O
		lines = append(lines,
			dash.SectionHeader("ESTADISTICAS I/O"), "",
			"  "+styles.Dim.Render("Disco principal: ")+styles.White.Render("sda"),
			"",
			"  "+styles.Dim.Render("Lecturas:  ")+"45.2 MB/s   "+styles.Dim.Render("ops: 1240/s"),
			"  "+styles.Dim.Render("Escrituras: ")+"12.1 MB/s   "+styles.Dim.Render("ops: 380/s"),
			"  "+styles.Dim.Render("I/O wait:  ")+styles.MetricOK.Render("0.8%"),
			"  "+styles.Dim.Render("Queue:     ")+styles.MetricOK.Render("0.12"),
			"",
			dash.SectionHeader("POR PARTICION"),
			"",
			"  sda1  "+styles.Dim.Render("r: 30.1 MB/s   w: 8.2 MB/s"),
			"  sda2  "+styles.Dim.Render("r: 15.1 MB/s   w: 3.9 MB/s"),
		)
	default: // Inodes
		lines = append(lines, dash.SectionHeader("USO DE INODES"), "")
		mW := 14
		barWI := w - mW - 8
		if barWI < 8 {
			barWI = 8
		}
		for _, d := range dm.Disks {
			pct := 12.0 + float64(len(d.Mount))*2 // mock
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(mW).Render(d.Mount),
				dash.GaugeColored(pct, barWI, dash.ColorForPct(pct)),
				"  "+dash.ColorPct(pct),
			))
		}
		lines = append(lines, "", styles.Dim.Render("  (inodes disponibles calculados sobre ext4 con 1%% reservado)"))
	}
	return strings.Join(lines, "\n")
}
