// Package screens — s11_shutdown.go: pantalla de apagado/reinicio en progreso (S11).
package screens

import (
	"fmt"
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderShutdown renderiza S11: secuencia de apagado/reinicio progresiva con
// barra de progreso y panel de estado lateral.
func RenderShutdown(m tuimodel.Model) string {
	return assembleScreen(m, buildShutdownBody(m))
}

func buildShutdownBody(m tuimodel.Model) string {
	sideW := 28
	if m.Width < 70 {
		sideW = 0
	}
	mainW := m.Width - sideW - 1
	if sideW == 0 {
		mainW = m.Width
	}

	barSty := styles.Error
	titleSty := styles.CriticalText
	if m.ShutdownMode == "restart" {
		barSty = styles.AccentBold
		titleSty = styles.AccentBold
	}

	shutdownSeq := []struct{ group, action string }{
		{"Daemons SBOS", "banexus → bhnexus → bCompass → biedata → bSearch → bAuth → bKernel"},
		{"Context Plane", "context.expired → Redis DB1 vaciado → JSON-RPC cerrado"},
		{"Seguridad", "kong → keycloak → vault (secrets sellados)"},
		{"Stack de datos", "redis (RDB snapshot) → minio → postgresql (checkpoint final)"},
		{"Kubernetes", "drain pods → Linkerd → kubelet cordoned → apiserver → etcd snapshot"},
		{"Ubuntu", "containerd → systemd sync filesystem → kernel apagado"},
	}
	n := len(shutdownSeq)

	var seqLines []string
	for i, seq := range shutdownSeq {
		stepFrac := float64(i) / float64(n)
		nextFrac := float64(i+1) / float64(n)
		var icon string
		switch {
		case m.ShutdownPct >= nextFrac:
			icon = styles.Tint(styles.IconOK, styles.ColorStateOKFg)
		case m.ShutdownPct >= stepFrac:
			icon = m.Spinner.View()
		default:
			icon = styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled)
		}
		seqLines = append(seqLines,
			icon+" "+styles.TableHeader.Bold(true).Render(seq.group),
			"   "+styles.Dim.Render(seq.action),
			"",
		)
	}
	mainPanel := styles.Box.Width(mainW).Render(strings.Join(seqLines, "\n"))

	if sideW == 0 {
		return mainPanel
	}

	barW := sideW - 4
	if barW < 8 {
		barW = 8
	}
	filled := int(float64(barW) * m.ShutdownPct)
	if filled > barW {
		filled = barW
	}
	pct := int(m.ShutdownPct * 100)
	bar := barSty.Render(strings.Repeat("█", filled)) +
		styles.Dim.Render(strings.Repeat("░", barW-filled))

	var action string
	if m.ShutdownMode == "restart" {
		action = styles.Tint(styles.IconRestart, styles.ColorStateWarnFg) + " Reiniciando"
	} else {
		action = styles.Tint(styles.IconPower, styles.ColorStateErrFg) + " Apagando"
	}

	warnStyle := barSty.Italic(true)
	sideContent := styles.JoinV(styles.PosLeft,
		titleSty.Bold(true).Render(action),
		"",
		fmt.Sprintf("[%s] %3d%%", bar, pct),
		"",
		styles.Dim.Render("No interrumpir"),
		"",
		warnStyle.Render("Ctrl+C — solo"),
		warnStyle.Render("para forzar"),
		warnStyle.Render("(peligroso)"),
	)
	sidePanel := styles.Box.Width(sideW).Render(sideContent)

	return styles.JoinH(styles.PosTop, mainPanel, sidePanel)
}
