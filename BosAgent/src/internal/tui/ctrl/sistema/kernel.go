package sistema

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Kernel renderiza la vista Sistema OS — Kernel.
func Kernel(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Versión", "Módulos", "Sysctl"}
	tabIdx := dm.SubTab["os-ker"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	ki := dm.KernelInfo
	switch tabIdx {
	case 0: // Versión
		lines = append(lines, dash.SectionHeader("INFORMACIÓN DEL KERNEL"), "")
		rows := [][2]string{
			{"Versión", ki.Version},
			{"Arquitectura", ki.Arch},
			{"Boot time", ki.BootTime},
			{"Compilador", "gcc 14.0 (Ubuntu)"},
			{"Build", "#" + ki.Version + " SMP PREEMPT_DYNAMIC"},
		}
		kW := 16
		for _, r := range rows {
			lines = append(lines, fmt.Sprintf("  %s  %s",
				styles.Dim.Render(fmt.Sprintf("%-*s", kW, r[0])),
				styles.AccentBold.Render(r[1]),
			))
		}
		lines = append(lines, "",
			dash.SectionHeader("CAPACIDADES"),
			"",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  cgroups v2",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  namespaces (pid, net, ipc, uts, mnt)",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  overlay filesystem",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  bridge netfilter",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  eBPF support",
		)
	case 1: // Módulos
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("MÓDULOS KERNEL — %d cargados", len(ki.Modules))), "")
		nW := w * 24 / 100
		sW := 10
		uW := 6
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nW).Render("MÓDULO"),
				styles.TableHeader.Width(sW).Render("TAMAÑO"),
				styles.TableHeader.Width(uW).Render("USO"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, m := range ki.Modules {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nW).Render(dash.Truncate(m.Name, nW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", sW, m.Size)),
				styles.Dim.Render(fmt.Sprintf("%-*d", uW, m.Used)),
				styles.StatusOK.Render(m.Status),
			))
		}
	default: // Sysctl
		lines = append(lines, dash.SectionHeader("PARÁMETROS SYSCTL (críticos)"), "")
		kW := w * 40 / 100
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(kW).Render("PARÁMETRO"),
				styles.TableHeader.Render("VALOR"),
			),
			dash.ColSep(w),
		)
		for _, p := range ki.Params {
			lines = append(lines, fmt.Sprintf("  %s  %s",
				styles.Dim.Render(fmt.Sprintf("%-*s", kW-2, dash.Truncate(p[0], kW-3))),
				styles.AccentBold.Render(p[1]),
			))
		}
	}
	return strings.Join(lines, "\n")
}
