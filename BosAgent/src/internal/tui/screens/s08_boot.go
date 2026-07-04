// Package screens — s08_boot.go: secuencia de arranque progresiva del SBOS (S08).
// m.BootPct (0.0–1.0) determina qué grupos de la secuencia de 6 están listos.
package screens

import (
	"fmt"
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
	"bos/internal/tui/util"
)

// RenderBoot renderiza S08: secuencia de arranque progresiva con m.BootPct (0.0–1.0).
func RenderBoot(m tuimodel.Model) string {
	return assembleScreen(m, buildBootBody(m))
}

func buildBootBody(m tuimodel.Model) string {
	bootSeq := []struct{ group, items string }{
		{"Ubuntu", "kernel · containerd · systemd · red"},
		{"Kubernetes", "etcd → apiserver → scheduler → controller → kubelet → Calico → Linkerd"},
		{"Stack de datos", "postgresql (Patroni) → redis → minio"},
		{"Seguridad", "vault → keycloak → kong"},
		{"Daemons SBOS", "bKernel → bAuth → bSearch → bCompass → biedata → bhnexus → banexus"},
		{"Context Plane", "Context Registry → JSON-RPC socket → ctx_id"},
	}
	n := len(bootSeq)

	boxW := m.Width - 2
	if boxW < 40 {
		boxW = 40
	}

	// Panel superior: secuencia de arranque con iconos progresivos
	var seqLines []string
	for i, seq := range bootSeq {
		stepPct := float64(i) / float64(n)
		var icon string
		switch {
		case m.BootPct >= float64(i+1)/float64(n):
			icon = styles.Tint(styles.IconOK, styles.ColorStateOKFg)
		case m.BootPct >= stepPct:
			icon = m.Spinner.View()
		default:
			icon = styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled)
		}
		groupStyle := styles.TableHeader.Bold(true)
		itemStyle := styles.Muted
		seqLines = append(seqLines,
			icon+" "+groupStyle.Render(seq.group),
			"   "+itemStyle.Render(seq.items),
			"",
		)
	}
	mainPanel := styles.Box.Width(boxW).Render(strings.Join(seqLines, "\n"))

	// Panel inferior: barra de progreso + info del arranque
	barW := boxW - 10
	if barW < 8 {
		barW = 8
	}
	filled := int(float64(barW) * m.BootPct)
	if filled > barW {
		filled = barW
	}
	pct := int(m.BootPct * 100)
	bar := styles.ProgressFill.Render(strings.Repeat("█", filled)) +
		styles.Dim.Render(strings.Repeat("░", barW-filled))
	barLine := fmt.Sprintf("[%s] %3d%%", bar, pct)

	msg := m.BootMsg
	if msg == "" {
		msg = "Iniciando..."
	}
	elapsed := ""
	if !m.StartTime.IsZero() {
		elapsed = util.FormatDur(time.Since(m.StartTime).Round(time.Second))
	}
	tenantName := m.TenantValue("BOS_TENANT_NAME")
	if tenantName == "" {
		tenantName = "sbos"
	}
	currentStep := styles.Dim.Render(msg)
	if pct >= 100 {
		currentStep = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.AccentBold.Render(" Sistema listo")
	}

	infoContent := styles.JoinV(styles.PosLeft,
		styles.AccentBold.Render("Arranque SBOS"),
		"",
		barLine,
		"",
		styles.JoinH(styles.PosTop,
			summaryRow("Tenant", tenantName)+"   ",
			summaryRow("Node", "node-01")+"   ",
			summaryRow("Elapsed", elapsed),
		),
		"",
		currentStep,
	)
	infoPanel := styles.Box.Width(boxW).Render(infoContent)

	return styles.JoinV(styles.PosLeft, mainPanel, infoPanel)
}
