// Package screens — s03b_capacidad.go: estimados de capacidad del wizard (P3B).
// Panel izquierdo: recoge los 4 estimados (tenants, empresas, sucursales, usuarios).
// Panel derecho: calcula y muestra requisitos de hardware en tiempo real.
// Los valores calculados se usan en el observer y en el control de admisión en ejecución.
package screens

import (
	"fmt"
	"strconv"
	"strings"

	"bos/internal/capacity"
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderWizardCapacity renderiza la pantalla de estimados de capacidad (P3B).
func RenderWizardCapacity(m tuimodel.Model) string {
	return assembleScreen(m, renderCapacityBody(m))
}

func renderCapacityBody(m tuimodel.Model) string {
	w := m.Width
	if w == 0 {
		w = 80
	}

	// ── Panel izquierdo: formulario de estimados ────────────────────────────
	cursor := styles.AccentBold
	var rows []string
	for i, f := range m.CapacityFields {
		if i >= len(m.CapacityInputs) {
			break
		}
		var prefix, labelRendered string
		if i == m.CapacityFocus {
			prefix = cursor.Render(styles.IconCursor + " ")
			labelRendered = styles.LabelActive.Render(fmt.Sprintf("%-28s", f.Label+":"))
		} else {
			prefix = "  "
			labelRendered = styles.Label.Render(fmt.Sprintf("%-28s", f.Label+":"))
		}
		rows = append(rows, prefix+labelRendered+m.CapacityInputs[i].View())
	}
	hint := styles.Dim.Render("  Tab / ↑↓ para navegar  ·  Enter para continuar")
	formContent := strings.Join(rows, "\n\n") + "\n\n" + hint

	// ── Panel derecho: requisitos calculados en tiempo real ─────────────────
	// CapacityEstimateForDisplay usa mín. 1 por campo para retroalimentación
	// progresiva mientras el usuario completa el formulario. No afecta persistencia.
	est := tuimodel.CapacityEstimateForDisplay(m.CapacityInputs)
	req := capacity.Calculate(est)

	totalUsers := est.TotalUsers()
	concurrent := est.ConcurrentUsers()

	statusSty := func(ok bool) styles.Style {
		if ok {
			return styles.AccentBold
		}
		return styles.Muted
	}
	statusMark := func(ok bool) string {
		if ok {
			return styles.IconOK
		}
		return "~"
	}

	calcLines := []string{
		styles.AccentBold.Render("Requisitos calculados"),
		"",
		fmt.Sprintf("  Usuarios totales      %s", styles.Bold.Render(formatInt(totalUsers))),
		fmt.Sprintf("  Sesiones concurrentes %s", styles.Bold.Render(formatInt(concurrent))),
		fmt.Sprintf("  ctx_id en Redis       %s", styles.Bold.Render(capacity.FormatRAM(req.RedisDB1MB))),
		fmt.Sprintf("  Datos PostgreSQL      %s", styles.Bold.Render(fmt.Sprintf("%d GB", req.PGDataGB))),
		"",
		styles.Dim.Render("── Hardware mínimo ──"),
		fmt.Sprintf("  %s RAM                %s / rec %s",
			statusSty(req.RAMMinMB <= 16384).Render(statusMark(req.RAMMinMB <= 16384)),
			styles.Bold.Render(capacity.FormatRAM(req.RAMMinMB)),
			styles.Dim.Render(capacity.FormatRAM(req.RAMRecMB))),
		fmt.Sprintf("  %s Disco libre         %s / rec %s",
			statusSty(req.DiskMinGB <= 300).Render(statusMark(req.DiskMinGB <= 300)),
			styles.Bold.Render(fmt.Sprintf("%d GB", req.DiskMinGB)),
			styles.Dim.Render(fmt.Sprintf("%d GB", req.DiskRecGB))),
		fmt.Sprintf("  %s CPU cores           %d / rec %d",
			statusSty(req.CPUMin <= 16).Render(statusMark(req.CPUMin <= 16)),
			req.CPUMin, req.CPURec),
		"",
		styles.Dim.Render("Estos valores se guardan en /etc/bos/capacity.yaml"),
		styles.Dim.Render("y el observer los usa como referencia de capacidad."),
		styles.Dim.Render("Las operaciones se niegan si superan estos límites."),
	}
	calcContent := strings.Join(calcLines, "\n")

	if w < 100 {
		combined := formContent + "\n\n" + styles.Box.Width(w-4).Render(calcContent)
		return styles.Box.Width(w - 4).Render(combined)
	}

	leftW := (w - 6) * 55 / 100
	rightW := (w - 6) - leftW
	leftPanel := styles.BoxActive.Width(leftW).Render(formContent)
	rightPanel := styles.Box.Width(rightW).Render(calcContent)
	return styles.JoinH(styles.PosTop, leftPanel, " ", rightPanel)
}

// formatInt formatea un entero con sufijos K/M para legibilidad en tabla de capacidad.
func formatInt(n int) string {
	if n == 0 {
		return "—"
	}
	if n >= 1_000_000 {
		return fmt.Sprintf("%.1fM", float64(n)/1_000_000)
	}
	if n >= 1_000 {
		return fmt.Sprintf("%.1fK", float64(n)/1_000)
	}
	return strconv.Itoa(n)
}
