package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// StorageOS renderiza la vista Storage — Discos del Sistema.
func StorageOS(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Discos", "SMART", "Backups"}
	tabIdx := dm.SubTab["stor-os"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Discos
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("DISCOS DEL SISTEMA — %d dispositivos", len(dm.StorageDisks))), "")
		cols := dash.ColWidths(w, []int{13, 30, 11, 9, 12, 25})
		devW, modelW, szW, tmpW, smW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		barW := w - 18
		if barW < 8 {
			barW = 8
		}
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(devW).Render("DISPOSITIVO"),
				styles.TableHeader.Width(modelW).Render("MODELO"),
				styles.TableHeader.Width(szW).Render("TAMAÑO"),
				styles.TableHeader.Width(tmpW).Render("TEMP"),
				styles.TableHeader.Width(smW).Render("SMART"),
				styles.TableHeader.Render("POW-ON-H"),
			),
			dash.ColSep(w),
		)
		for _, d := range dm.StorageDisks {
			health := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " PASSED"
			if d.Health != "PASSED" {
				health = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " " + d.Health
			}
			tempColor := styles.StatusOK
			if d.TempC > 65 {
				tempColor = styles.StatusErr
			} else if d.TempC > 50 {
				tempColor = styles.StatusWarn
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(devW).Render(d.Device),
				styles.Dim.Render(fmt.Sprintf("%-*s", modelW, dash.Truncate(d.Model, modelW-1))),
				styles.AccentBold.Width(szW).Render(fmt.Sprintf("%.0f GB", d.SizeGB)),
				tempColor.Render(fmt.Sprintf("%-*s", tmpW, fmt.Sprintf("%d°C", d.TempC))),
				styles.Cell(smW, health),
				styles.Dim.Render(fmt.Sprintf("%d h", d.PowerOnH)),
			))
		}
		lines = append(lines, "", dash.SectionHeader("PARTICIONES"), "")
		for _, d := range dm.Disks {
			pct := d.UsedGB / d.TotalGB * 100
			lines = append(lines,
				fmt.Sprintf("  %s %s  %.0f/%.0f GB",
					styles.White.Width(10).Render(d.Mount),
					dash.GaugeColored(pct, barW, dash.ColorForPct(pct)),
					d.UsedGB, d.TotalGB,
				),
			)
		}
	case 1: // SMART
		lines = append(lines, dash.SectionHeader("DIAGNÓSTICO SMART"), "")
		for _, d := range dm.StorageDisks {
			health := styles.StatusOK.Render("PASSED")
			if d.Health != "PASSED" {
				health = styles.StatusErr.Render(d.Health)
			}
			lines = append(lines, "",
				styles.AccentBold.Render(d.Device)+"  "+styles.Dim.Render(d.Model),
				dash.ColSep(w),
			)
			kW := 22
			rows := [][2]string{
				{"Health", d.Health},
				{"Temperatura", fmt.Sprintf("%d°C", d.TempC)},
				{"Power-On Hours", fmt.Sprintf("%d h", d.PowerOnH)},
				{"Reallocated Sectors", fmt.Sprintf("%d", d.Reallocated)},
				{"Resultado global", ""},
			}
			for _, r := range rows {
				val := styles.AccentBold.Render(r[1])
				if r[0] == "Health" {
					val = health
				} else if r[0] == "Resultado global" {
					val = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Sin errores detectados"
				}
				lines = append(lines, fmt.Sprintf("  %s  %s",
					styles.Dim.Render(fmt.Sprintf("%-*s", kW, r[0])), val))
			}
		}
	default: // Backups (referencia rápida)
		lines = append(lines, dash.SectionHeader("BACKUPS — RESUMEN"), "")
		cols := dash.ColWidths(w, []int{25, 28, 12, 35})
		nW, runW, szW, _ := cols[0], cols[1], cols[2], cols[3]
		for _, bj := range dm.BackupJobs {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " " + bj.Status
			if bj.Status != "OK" {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " " + bj.Status
			}
			lines = append(lines, fmt.Sprintf("  %-*s  %-*s  %-*s  %s",
				nW, dash.Truncate(bj.Name, nW-1),
				runW, styles.Dim.Render(bj.LastRun),
				szW, styles.Dim.Render(bj.LastSize),
				st,
			))
		}
	}
	return strings.Join(lines, "\n")
}
