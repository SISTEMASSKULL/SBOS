package k8s

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Autoscaling renderiza la vista K8s — Autoscaling.
func Autoscaling(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"HPA", "VPA", "KEDA", "Cluster AS", "Quotas", "LimitRange", "PDB"}
	tabIdx := dm.SubTab["k8s-as"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // HPA
		lines = append(lines, dash.SectionHeader("HPA — HORIZONTAL POD AUTOSCALER"), "")
		cols := dash.ColWidths(w, []int{22, 22, 5, 5, 7, 8, 31})
		nameW, tgtW, minW, maxW, actW, cpuW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(tgtW).Render("TARGET"),
				styles.TableHeader.Width(minW).Render("MIN"),
				styles.TableHeader.Width(maxW).Render("MAX"),
				styles.TableHeader.Width(actW).Render("ACT"),
				styles.TableHeader.Width(cpuW).Render("CPU%"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, h := range dm.HPAs {
			var statusStr string
			switch h.Status {
			case dash.HPAScaling:
				statusStr = styles.AccentBold.Render("* Escalando")
			case dash.HPAAtMax:
				statusStr = styles.Warning.Render("! MaxReplicas")
			default:
				statusStr = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Estable"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(h.Name, nameW-1)),
				styles.Dim.Width(tgtW).Render(dash.Truncate(h.Target, tgtW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*d", minW, h.MinReplicas)),
				styles.Dim.Render(fmt.Sprintf("%-*d", maxW, h.MaxReplicas)),
				styles.AccentBold.Width(actW).Render(fmt.Sprintf("%d", h.Current)),
				styles.Cell(cpuW, dash.ColorPct(float64(h.CPUCurrent))),
				statusStr,
			))
		}
	case 1: // VPA
		lines = append(lines, dash.SectionHeader("VPA — VERTICAL POD AUTOSCALER"), "")
		cols := dash.ColWidths(w, []int{22, 22, 9, 14, 14, 19})
		nameW, tgtW, modeW, cpuW, memW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(tgtW).Render("TARGET"),
				styles.TableHeader.Width(modeW).Render("MODO"),
				styles.TableHeader.Width(cpuW).Render("CPU rec."),
				styles.TableHeader.Width(memW).Render("MEM rec."),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, v := range dm.VPAs {
			var statusStr string
			switch v.Status {
			case dash.VPAApplying:
				statusStr = styles.Tint(styles.IconSync, styles.ColorStateWarnFg) + " Aplicando"
			case dash.VPARec:
				statusStr = styles.Tint(styles.IconDotDim, styles.ColorTextDisabled) + " Sugerencia"
			default:
				statusStr = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Estable"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(v.Name, nameW-1)),
				styles.Dim.Width(tgtW).Render(dash.Truncate(v.Target, tgtW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", modeW, dash.Truncate(v.Mode, modeW-1))),
				styles.AccentBold.Width(cpuW).Render(v.CPURec),
				styles.AccentBold.Width(memW).Render(v.MemRec),
				statusStr,
			))
		}
	case 2: // KEDA
		lines = append(lines, dash.SectionHeader("KEDA — EVENT-DRIVEN AUTOSCALING"), "")
		cols := dash.ColWidths(w, []int{18, 24, 11, 11, 11, 25})
		nameW, trigW, curW, thrW, repW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(trigW).Render("TRIGGER"),
				styles.TableHeader.Width(curW).Render("ACTUAL"),
				styles.TableHeader.Width(thrW).Render("UMBRAL"),
				styles.TableHeader.Width(repW).Render("REPLICAS"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, k := range dm.KEDAScalers {
			var statusStr string
			switch k.Status {
			case dash.KEDARunning:
				statusStr = styles.AccentBold.Render("* Escalando")
			case dash.KEDAZero:
				statusStr = styles.Tint(styles.IconDotDim, styles.ColorTextDisabled) + " Scale-zero"
			default:
				statusStr = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Estable"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(k.Name, nameW-1)),
				styles.Dim.Width(trigW).Render(dash.Truncate(k.TriggerType, trigW-1)),
				styles.AccentBold.Width(curW).Render(fmt.Sprintf("%d", k.CurrentVal)),
				styles.Dim.Width(thrW).Render(fmt.Sprintf("%d", k.Threshold)),
				styles.Dim.Width(repW).Render(fmt.Sprintf("%d", k.Replicas)),
				statusStr,
			))
		}
	case 3: // Cluster AS
		ca := dm.ClusterAS
		barW := w / 3
		lines = append(lines,
			dash.SectionHeader("CLUSTER AUTOSCALER"), "",
			fmt.Sprintf("  Nodos: %d/%d (max: %d)   CPU cluster: %s   MEM cluster: %s   No schedulables: %d",
				ca.NodesReady, ca.NodesTotal, ca.NodesMax,
				dash.ColorPct(ca.CPUCluster), dash.ColorPct(ca.MemCluster),
				ca.UnschedulablePods),
			"",
			"  "+dash.SectionHeader("CPU cluster")+":  "+dash.GaugeColored(ca.CPUCluster, barW, dash.ColorForPct(ca.CPUCluster)),
			"  "+dash.SectionHeader("MEM cluster")+":  "+dash.GaugeColored(ca.MemCluster, barW, dash.ColorForPct(ca.MemCluster)),
			"",
			"  "+styles.Dim.Render("Ultimo scale-up:  ")+"hace "+ca.LastScaleUp+"  (+1 nodo)",
			"  "+styles.Dim.Render("Ultimo scale-down: ")+"hace "+ca.LastScaleDown+"  (-1 nodo)",
		)
	case 4: // Quotas
		if len(dm.Quotas) > 0 {
			q := dm.Quotas[0]
			lines = append(lines, dash.SectionHeader("RESOURCE QUOTAS — namespace: "+q.Namespace), "")
			cols := dash.ColWidths(w, []int{22, 14, 14, 9, 41})
			rW, usW, limW, pctW, _ := cols[0], cols[1], cols[2], cols[3], cols[4]
			lines = append(lines,
				styles.JoinH(styles.PosTop,
					styles.TableHeader.Width(rW).Render("RECURSO"),
					styles.TableHeader.Width(usW).Render("USADO"),
					styles.TableHeader.Width(limW).Render("LIMITE"),
					styles.TableHeader.Width(pctW).Render("%USO"),
					styles.TableHeader.Render("ESTADO"),
				),
				dash.ColSep(w),
			)
			for _, it := range q.Items {
				st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK"
				if it.Percent > 85 {
					st = styles.Error.Render("! Alto")
				} else if it.Percent > 70 {
					st = styles.Tint(styles.IconWarn, styles.ColorStateWarnFg) + " Medio"
				}
				lines = append(lines, styles.JoinH(styles.PosTop,
					styles.Dim.Width(rW).Render(dash.Truncate(it.Resource, rW-1)),
					styles.AccentBold.Width(usW).Render(it.Used),
					styles.Dim.Width(limW).Render(it.Hard),
					styles.Cell(pctW, dash.ColorPct(it.Percent)),
					st,
				))
			}
		}
	case 5: // LimitRange
		ns := "default"
		if len(dm.Quotas) > 0 {
			ns = dm.Quotas[0].Namespace
		}
		lines = append(lines, dash.SectionHeader("LIMITRANGE — namespace: "+ns), "")
		cols := dash.ColWidths(w, []int{14, 12, 14, 14, 12, 34})
		tpW, rsW, dreqW, dlimW, minW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(tpW).Render("TIPO"),
				styles.TableHeader.Width(rsW).Render("RECURSO"),
				styles.TableHeader.Width(dreqW).Render("DEF REQ"),
				styles.TableHeader.Width(dlimW).Render("DEF LIM"),
				styles.TableHeader.Width(minW).Render("MIN"),
				styles.TableHeader.Render("MAX"),
			),
			dash.ColSep(w),
		)
		for _, lr := range dm.LimitRanges {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.AccentBold.Width(tpW).Render(lr.LRType),
				styles.Dim.Width(rsW).Render(lr.Resource),
				styles.Dim.Render(fmt.Sprintf("%-*s", dreqW, lr.DefaultReq)),
				styles.Dim.Render(fmt.Sprintf("%-*s", dlimW, lr.DefaultLim)),
				styles.Dim.Render(fmt.Sprintf("%-*s", minW, lr.Min)),
				styles.Dim.Render(lr.Max),
			))
		}
	default: // PDB
		lines = append(lines, dash.SectionHeader("POD DISRUPTION BUDGETS"), "", "")
		cols := dash.ColWidths(w, []int{26, 26, 7, 9, 32})
		nameW, selW, minW, dispW, _ := cols[0], cols[1], cols[2], cols[3], cols[4]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(selW).Render("SELECTOR"),
				styles.TableHeader.Width(minW).Render("MIN"),
				styles.TableHeader.Width(dispW).Render("DISP"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, pdb := range dm.PDBs {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Saludable"
			if !pdb.Healthy {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " Degradado"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(pdb.Name, nameW-1)),
				styles.Dim.Width(selW).Render(dash.Truncate(pdb.Selector, selW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*d", minW, pdb.MinAvail)),
				styles.Dim.Render(fmt.Sprintf("%-*d", dispW, pdb.Available)),
				st,
			))
		}
	}
	return strings.Join(lines, "\n")
}
