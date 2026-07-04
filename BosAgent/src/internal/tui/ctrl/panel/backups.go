package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Backups renderiza la vista Backups — Estado y Schedule.
func Backups(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Estado", "Schedule", "Historial"}
	tabIdx := dm.SubTab["bkp"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Estado
		ok, failed, running := 0, 0, 0
		for _, bj := range dm.BackupJobs {
			switch bj.Status {
			case "OK":
				ok++
			case "FAILED":
				failed++
			case "RUNNING":
				running++
			}
		}
		cols := dash.ColWidths(w, []int{22, 28, 20, 11, 19})
		nW, tgtW, runW, szW, _ := cols[0], cols[1], cols[2], cols[3], cols[4]
		lines = append(lines, dash.SectionHeader("ESTADO DE BACKUPS"), "")
		lines = append(lines,
			fmt.Sprintf("  %s %d OK   %s %d Fallidos   %s %d En ejecución",
				styles.Tint(styles.IconOK, styles.ColorStateOKFg), ok,
				styles.Tint(styles.IconErr, styles.ColorStateErrFg), failed,
				styles.Tint(styles.IconSync, styles.ColorStateWarnFg), running,
			),
			"",
		)
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nW).Render("JOB"),
				styles.TableHeader.Width(tgtW).Render("DESTINO"),
				styles.TableHeader.Width(runW).Render("ULTIMA EJECUCION"),
				styles.TableHeader.Width(szW).Render("TAMAÑO"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, bj := range dm.BackupJobs {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK"
			if bj.Status == "FAILED" {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " FAILED"
			} else if bj.Status == "RUNNING" {
				st = styles.Tint(styles.IconSync, styles.ColorStateWarnFg) + " RUNNING"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nW).Render(dash.Truncate(bj.Name, nW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", tgtW, dash.Truncate(bj.Target, tgtW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", runW, bj.LastRun)),
				styles.AccentBold.Width(szW).Render(bj.LastSize),
				st,
			))
		}
	case 1: // Schedule
		scols := dash.ColWidths(w, []int{22, 20, 22, 36})
		nW, schW, nxtW, tgtW := scols[0], scols[1], scols[2], scols[3]
		lines = append(lines, dash.SectionHeader("PROGRAMACIÓN DE BACKUPS"), "", "")
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nW).Render("JOB"),
				styles.TableHeader.Width(schW).Render("SCHEDULE (CRON)"),
				styles.TableHeader.Width(nxtW).Render("PRÓXIMA EJECUCION"),
				styles.TableHeader.Render("DESTINO"),
			),
			dash.ColSep(w),
		)
		for _, bj := range dm.BackupJobs {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nW).Render(dash.Truncate(bj.Name, nW-1)),
				styles.AccentBold.Width(schW).Render(bj.Schedule),
				styles.Dim.Render(fmt.Sprintf("%-*s", nxtW, bj.NextRun)),
				styles.Dim.Render(dash.Truncate(bj.Target, tgtW-1)),
			))
		}
	default: // Historial
		hist := []struct{ job, ts, size, dur, status string }{
			{"postgres-daily", "2026-06-12 02:00", "4.2 GB", "8m 12s", "OK"},
			{"redis-hourly", "2026-06-12 11:00", "128 MB", "0m 45s", "OK"},
			{"bos-state", "2026-06-12 11:30", "2.1 MB", "0m 03s", "OK"},
			{"etcd-snapshot", "2026-06-12 06:00", "2.1 GB", "1m 22s", "OK"},
			{"postgres-daily", "2026-06-11 02:00", "4.1 GB", "7m 55s", "OK"},
			{"redis-hourly", "2026-06-12 10:00", "127 MB", "0m 44s", "OK"},
			{"etcd-snapshot", "2026-06-12 00:00", "2.0 GB", "1m 18s", "OK"},
		}
		hcols := dash.ColWidths(w, []int{22, 20, 10, 12, 36})
		hnW, tsW, szW, durW, _ := hcols[0], hcols[1], hcols[2], hcols[3], hcols[4]
		lines = append(lines, dash.SectionHeader("HISTORIAL DE BACKUPS"), "", "")
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(hnW).Render("JOB"),
				styles.TableHeader.Width(tsW).Render("FECHA"),
				styles.TableHeader.Width(szW).Render("TAMAÑO"),
				styles.TableHeader.Width(durW).Render("DURACIÓN"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, e := range hist {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK"
			if e.status != "OK" {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " " + e.status
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(hnW).Render(dash.Truncate(e.job, hnW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", tsW, e.ts)),
				styles.AccentBold.Width(szW).Render(e.size),
				styles.Dim.Render(fmt.Sprintf("%-*s", durW, e.dur)),
				st,
			))
		}
	}
	return strings.Join(lines, "\n")
}
