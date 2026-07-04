// Package screens — s00_welcome.go: pantalla de bienvenida (S00 — ScreenWelcome).
// Pantalla de arranque: ícono SBOS + nombre SKULL + barra de progreso de boot.
// Pantalla completa: sin header ni footer. WrapWithMargin se aplica externamente.
package screens

import (
	"fmt"
	"os"
	"strings"

	bostui "bos/internal/tui"
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderWelcome renderiza la pantalla de bienvenida (S00 — ScreenWelcome).
func RenderWelcome(m tuimodel.Model) string {
	w := m.Width
	if w == 0 {
		w = 80
	}
	mode := styles.Mode(w)

	// ── Ícono centrado arriba ─────────────────────────────────────────────────
	iconBlock := buildWelcomeIcon(w, mode)

	// ── Nombre SKULL ─────────────────────────────────────────────────────────
	skull := styles.TableHeader.Bold(true).Width(w).Align(styles.PosCenter).
		Render("S K U L L")

	sub1 := styles.Subtitle.Width(w).Align(styles.PosCenter).
		Render("SOVEREIGN KERNEL & UNIFIED LOGIC LAYER")

	sep := styles.Inactive.Width(w).Align(styles.PosCenter).
		Render(strings.Repeat("─", w/3))

	// ── Producto ──────────────────────────────────────────────────────────────
	product := styles.AccentBold.Width(w).Align(styles.PosCenter).
		Render("SBOS v1.0 GA")

	productSub := styles.Inactive.Width(w).Align(styles.PosCenter).
		Render("SISTEMA OPERATIVO EMPRESARIAL SOBERANO")

	tenantName := m.TenantValue("BOS_TENANT_NAME")
	if tenantName == "" {
		tenantName = "skull-sksistemas"
	}
	ctxLine := styles.Muted.Width(w).Align(styles.PosCenter).
		Render(fmt.Sprintf("Tenant %s · Node node-01 · Cluster cluster-sbos", tenantName))

	// ── Barra de progreso de boot ─────────────────────────────────────────────
	pct := int(m.BootPct * 100)
	barWidth := w - 20
	if barWidth < 20 {
		barWidth = 20
	}
	filled := int(float64(barWidth) * m.BootPct)
	empty := barWidth - filled
	progressBar := "[" + strings.Repeat("█", filled) + strings.Repeat("░", empty) + "]"

	bootLine := styles.AccentBold.Width(w).Align(styles.PosCenter).
		Render(fmt.Sprintf("%s %3d%%  %s", progressBar, pct, m.BootMsg))

	// ── Legal ─────────────────────────────────────────────────────────────────
	legal1 := styles.Muted.Faint(true).Width(w).Align(styles.PosCenter).
		Render("© 2026 SKULL — Sovereign Kernel & Unified Logic Layer")
	legal2 := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("Powered by SKULL · SBOS v1.0 GA · Sep 2026 · ISA-95 · NIST 800-207 · ISO 27001")
	legal3 := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("ALL COMPONENTS SIGNED WITH Ed25519 · SOVEREIGN · NO DATA LEAVES THIS NODE")

	// ── Composición ──────────────────────────────────────────────────────────
	parts := []string{}
	if iconBlock != "" {
		parts = append(parts, iconBlock, "")
	}
	parts = append(parts, skull, sub1, "", sep, "", product, productSub, "", ctxLine, "", bootLine)

	body := styles.JoinV(styles.PosCenter, parts...)
	footer := styles.JoinV(styles.PosCenter, legal1, legal2, legal3)

	bodyLines := strings.Count(body, "\n") + 1
	footerLines := strings.Count(footer, "\n") + 1
	total := bodyLines + 2 + footerLines
	pad := (m.Height - total) / 2
	if pad < 1 {
		pad = 1
	}

	return styles.JoinV(styles.PosCenter,
		strings.Repeat("\n", pad),
		body,
		"\n",
		footer,
	)
}

// buildWelcomeIcon renderiza el ícono SBOS centrado.
// Solo lo intenta si la terminal reporta soporte de truecolor.
// En caso de error o sin truecolor devuelve "".
func buildWelcomeIcon(w int, mode string) string {
	// Solo en terminales con truecolor declarado
	ct := os.Getenv("COLORTERM")
	if ct != "truecolor" && ct != "24bit" {
		return ""
	}

	var cols, rows int
	switch mode {
	case "xl":
		cols, rows = 32, 16
	case "lg":
		cols, rows = 26, 13
	case "md":
		cols, rows = 20, 10
	default:
		return "" // xs/sm: sin ícono
	}

	icon, err := bostui.RenderIconSBOS(cols, rows)
	if err != nil || icon == "" {
		return ""
	}

	// Centrar el bloque de ícono horizontalmente
	return styles.CellCenter(w, icon)
}
