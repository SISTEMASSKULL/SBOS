package sistema

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Procesos renderiza la vista Sistema OS — Procesos.
func Procesos(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Top CPU", "Zombie", "Threads"}
	tabIdx := dm.SubTab["os-proc"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Top CPU
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("TOP PROCESOS  — total: %d  threads: %d", dm.CPU.Procs, dm.CPU.Threads)), "")
		cols := dash.ColWidths(w, []int{8, 22, 12, 8, 8, 9, 5, 28})
		pidW, nameW, userW, cpuW, memW, rssW, stW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6], cols[7]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(pidW).Render("PID"),
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(userW).Render("USUARIO"),
				styles.TableHeader.Width(cpuW).Render("CPU%"),
				styles.TableHeader.Width(memW).Render("MEM%"),
				styles.TableHeader.Width(rssW).Render("RSS"),
				styles.TableHeader.Width(stW).Render("ST"),
				styles.TableHeader.Render("TIEMPO"),
			),
			dash.ColSep(w),
		)
		for _, p := range dm.Processes {
			cpuColor := styles.ProgressFill.Copy().Foreground(dash.ColorForPct(p.CPUPct))
			memColor := styles.ProgressFill.Copy().Foreground(dash.ColorForPct(p.MemPct))
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.Dim.Render(fmt.Sprintf("%-*d", pidW, p.PID)),
				styles.TableHeader.Width(nameW).Render(dash.Truncate(p.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", userW, dash.Truncate(p.User, userW-1))),
				cpuColor.Render(fmt.Sprintf("%-*.1f", cpuW, p.CPUPct)),
				memColor.Render(fmt.Sprintf("%-*.1f", memW, p.MemPct)),
				styles.AccentBold.Width(rssW).Render(p.RSS),
				styles.Dim.Render(fmt.Sprintf("%-*s", stW, p.Status)),
				styles.Dim.Render(p.PTime),
			))
		}
	case 1: // Zombie
		lines = append(lines, dash.SectionHeader("PROCESOS ZOMBIE"), "")
		zombies := 0
		for _, p := range dm.Processes {
			if p.Status == "Z" {
				zombies++
				lines = append(lines, fmt.Sprintf("  %-7d  %-20s  %s", p.PID, p.Name, p.User))
			}
		}
		if zombies == 0 {
			lines = append(lines, styles.Success.Render("  ✔ Sin procesos zombie"))
		}
	default: // Threads
		lines = append(lines, dash.SectionHeader("THREADS"), "")
		lines = append(lines,
			fmt.Sprintf("  Total threads:  %s", styles.AccentBold.Render(fmt.Sprintf("%d", dm.CPU.Threads))),
			fmt.Sprintf("  Total procesos: %s", styles.AccentBold.Render(fmt.Sprintf("%d", dm.CPU.Procs))),
			"",
			dash.SectionHeader("THREADS POR PROCESO"),
			"",
		)
		limit := dash.Min4(6, len(dm.Processes))
		for _, p := range dm.Processes[:limit] {
			lines = append(lines, fmt.Sprintf("  %-7d  %-20s  threads: ~%d", p.PID, p.Name, p.PID%8+2))
		}
	}
	return strings.Join(lines, "\n")
}
