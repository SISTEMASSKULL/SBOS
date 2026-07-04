package sistema

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Red renderiza la vista Sistema OS — Red.
func Red(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Interfaces", "Conexiones", "DNS"}
	tabIdx := dm.SubTab["os-net"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Interfaces
		lines = append(lines, dash.SectionHeader("INTERFACES DE RED"), "")
		nameW := 8
		ipW := 22
		stW := 6
		txW := 12
		rxW := 12
		totTxW := 12
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("IFACE"),
				styles.TableHeader.Width(ipW).Render("IP"),
				styles.TableHeader.Width(stW).Render("ST"),
				styles.TableHeader.Width(txW).Render("TX/s"),
				styles.TableHeader.Width(rxW).Render("RX/s"),
				styles.TableHeader.Width(totTxW).Render("TX TOTAL"),
				styles.TableHeader.Render("RX TOTAL"),
			),
			dash.ColSep(w),
		)
		for _, ni := range dm.NetInterfaces {
			stColor := styles.StatusOK
			if ni.State != "UP" {
				stColor = styles.Dim
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(ni.Name),
				styles.AccentBold.Width(ipW).Render(ni.IPAddr),
				stColor.Render(fmt.Sprintf("%-6s", ni.State)),
				styles.MetricTX.Render(fmt.Sprintf("%-12s", dash.FormatBytesPS(ni.TXBytesS))),
				styles.AccentBold.Render(fmt.Sprintf("%-12s", dash.FormatBytesPS(ni.RXBytesS))),
				styles.Dim.Render(fmt.Sprintf("%-12s", ni.TXTotal)),
				styles.Dim.Render(ni.RXTotal),
			))
		}
	case 1: // Conexiones
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("CONEXIONES TCP  — activas: %d", len(dm.TCPConns))), "")
		localW := w * 24 / 100
		remoteW := w * 24 / 100
		stateW := 14
		pidW := 7
		procW := w - localW - remoteW - stateW - pidW
		if procW < 10 {
			procW = 10
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(localW).Render("LOCAL"),
				styles.TableHeader.Width(remoteW).Render("REMOTO"),
				styles.TableHeader.Width(stateW).Render("ESTADO"),
				styles.TableHeader.Width(pidW).Render("PID"),
				styles.TableHeader.Render("PROCESO"),
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
				styles.AccentBold.Width(localW).Render(dash.Truncate(c.LocalAddr, localW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", remoteW, dash.Truncate(c.RemoteAddr, remoteW-1))),
				stColor.Render(fmt.Sprintf("%-*s", stateW, c.State)),
				styles.Dim.Render(fmt.Sprintf("%-*d", pidW, c.PID)),
				styles.TableHeader.Render(dash.Truncate(c.Process, procW)),
			))
		}
	default: // DNS
		lines = append(lines,
			dash.SectionHeader("DNS"), "",
			"  "+styles.Dim.Render("Servidor DNS:   ")+styles.AccentBold.Render("10.96.0.10 (CoreDNS)"),
			"  "+styles.Dim.Render("Dominio local:  ")+styles.TableHeader.Render("cluster.local"),
			"  "+styles.Dim.Render("Search:         ")+styles.Dim.Render("default.svc.cluster.local  svc.cluster.local  cluster.local"),
			"",
			dash.SectionHeader("RESOLUCIONES RECIENTES"),
			"",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  postgres-svc.default.svc.cluster.local  →  10.96.0.20",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  redis-svc.default.svc.cluster.local     →  10.96.0.21",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  kubernetes.default.svc.cluster.local    →  10.96.0.1",
		)
	}
	return strings.Join(lines, "\n")
}
