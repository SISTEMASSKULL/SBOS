package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// NetworkOS renderiza la vista Network — Firewall y Red del OS.
func NetworkOS(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"UFW", "DNS", "Puertos", "Túneles"}
	tabIdx := dm.SubTab["net-os"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // UFW
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("REGLAS UFW — %d reglas activas", len(dm.UFWRules))), "")
		numW := 5
		actW := 7
		fromW := w * 22 / 100
		toW := w * 20 / 100
		protoW := 6
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(numW).Render("#"),
				styles.TableHeader.Width(actW).Render("ACCION"),
				styles.TableHeader.Width(fromW).Render("ORIGEN"),
				styles.TableHeader.Width(toW).Render("DESTINO"),
				styles.TableHeader.Width(protoW).Render("PROTO"),
				styles.TableHeader.Render("COMENTARIO"),
			),
			dash.ColSep(w),
		)
		for _, r := range dm.UFWRules {
			actStyle := styles.StatusOK
			if r.Action == "DENY" {
				actStyle = styles.StatusErr
			}
			cmtW := w - numW - actW - fromW - toW - protoW
			if cmtW < 8 {
				cmtW = 8
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.Dim.Render(fmt.Sprintf("%-*d", numW, r.Number)),
				actStyle.Render(fmt.Sprintf("%-*s", actW, r.Action)),
				styles.AccentBold.Width(fromW).Render(dash.Truncate(r.From, fromW-1)),
				styles.Dim.Width(toW).Render(dash.Truncate(r.To, toW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", protoW, r.Proto)),
				styles.Dim.Render(dash.Truncate(r.Comment, cmtW)),
			))
		}
	case 1: // DNS
		lines = append(lines,
			dash.SectionHeader("CONFIGURACIÓN DNS"), "",
			"  "+styles.Dim.Render("Servidor primario:    ")+styles.AccentBold.Render("10.96.0.10  (CoreDNS K8s)"),
			"  "+styles.Dim.Render("Servidor secundario:  ")+styles.AccentBold.Render("8.8.8.8   (Google DNS)"),
			"  "+styles.Dim.Render("Dominio local:        ")+styles.TableHeader.Render("cluster.local"),
			"  "+styles.Dim.Render("Search:               ")+styles.Dim.Render("default.svc.cluster.local  svc.cluster.local"),
			"",
			dash.SectionHeader("RESOLUCIONES RECIENTES"),
			"",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  postgres-svc.default.svc.cluster.local  →  10.96.0.20",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  redis-svc.default.svc.cluster.local     →  10.96.0.21",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  kubernetes.default.svc.cluster.local    →  10.96.0.1",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  api.sbos.local                          →  13.140.128.230",
			"",
			dash.SectionHeader("LATENCIA DNS"),
			"",
			"  CoreDNS    p50: 1ms   p99: 4ms",
			"  Google DNS p50: 12ms  p99: 28ms",
		)
	case 2: // Puertos
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("PUERTOS ABIERTOS — %d escuchando", len(dm.TCPConns))), "")
		portW := 22
		procW := w * 20 / 100
		pidW := 7
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(portW).Render("DIRECCIÓN:PUERTO"),
				styles.TableHeader.Width(pidW).Render("PID"),
				styles.TableHeader.Width(procW).Render("PROCESO"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, c := range dm.TCPConns {
			stColor := styles.Dim
			if c.State == "ESTABLISHED" {
				stColor = styles.StatusOK
			} else if c.State == "LISTEN" {
				stColor = styles.Info
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.AccentBold.Width(portW).Render(dash.Truncate(c.LocalAddr, portW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*d", pidW, c.PID)),
				styles.TableHeader.Width(procW).Render(dash.Truncate(c.Process, procW-1)),
				stColor.Render(c.State),
			))
		}
	default: // Túneles
		lines = append(lines,
			dash.SectionHeader("TÚNELES Y VPN"), "",
			"  "+styles.Dim.Render("WireGuard:   ")+styles.Dim.Render("no configurado"),
			"  "+styles.Dim.Render("OpenVPN:     ")+styles.Dim.Render("no configurado"),
			"  "+styles.Dim.Render("IPSec:       ")+styles.Dim.Render("no configurado"),
			"",
			dash.SectionHeader("INTERFACES VIRTUALES"),
			"",
		)
		for _, ni := range dm.NetInterfaces {
			if ni.Name == "cni0" || ni.Name == "lo" {
				icon := styles.Tint(styles.IconOK, styles.ColorStateOKFg)
				lines = append(lines, fmt.Sprintf("  %s  %-8s  %-24s  %s",
					icon, ni.Name, ni.IPAddr,
					styles.Dim.Render(fmt.Sprintf("TX: %s  RX: %s", dash.FormatBytesPS(ni.TXBytesS), dash.FormatBytesPS(ni.RXBytesS))),
				))
			}
		}
	}
	return strings.Join(lines, "\n")
}
