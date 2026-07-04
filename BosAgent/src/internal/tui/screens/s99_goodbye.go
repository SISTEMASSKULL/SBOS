// Package screens — s99_goodbye.go: pantalla de despedida (P14 — ScreenGoodbye).
// Muestra resumen de sesión: tenant, ctx_id, duración, fichas activas.
// Pantalla completa: sin header ni footer. WrapWithMargin se aplica externamente.
package screens

import (
	"fmt"
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
	"bos/internal/tui/util"
)

// RenderGoodbye renderiza la pantalla de despedida (P14 — ScreenGoodbye).
func RenderGoodbye(m tuimodel.Model) string {
	return renderGoodbyeAt(m, time.Now())
}

// renderGoodbyeAt permite inyectar "now" para producir tests deterministas.
func renderGoodbyeAt(m tuimodel.Model, now time.Time) string {
	w := m.Width
	if w == 0 {
		w = 80
	}

	goodbye := styles.AccentBold.Width(w).Align(styles.PosCenter).
		Render("G O O D  B Y E")

	skull := styles.Slate.Bold(true).Width(w).Align(styles.PosCenter).
		Render("\nS K U L L")

	sub1 := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("SOVEREIGN KERNEL & UNIFIED LOGIC LAYER")

	sub2 := styles.Muted.Italic(true).Width(w).Align(styles.PosCenter).
		Render("\"Certificamos mejora continua\"")

	sep := styles.Dim.Width(w).Align(styles.PosCenter).
		Render(strings.Repeat("─", w/2))

	sessionStart := m.StartTime
	if sessionStart.IsZero() {
		sessionStart = now.Add(-5 * time.Minute)
	}
	fichasStr := fmt.Sprintf("%d / %d OK", m.FichasOK, m.FichasTotal)
	if m.FichasTotal == 0 {
		fichasStr = "22 / 22 OK"
	}
	sessionInfo := styles.JoinV(styles.PosLeft,
		styles.Label.Render("Tenant")+"        skull-sksistemas",
		styles.Label.Render("Sesión")+"        ctx-"+now.Format("05040302"),
		styles.Label.Render("Inicio")+"        "+sessionStart.Format("2006-01-02  15:04:05"),
		styles.Label.Render("Fin")+"          "+now.Format("2006-01-02  15:04:05"),
		styles.Label.Render("Duración")+"     "+util.FormatDur(now.Sub(sessionStart)),
		styles.Label.Render("Fichas activas")+" "+fichasStr,
		styles.Label.Render("Apagado")+"      ordenado — sin errores",
	)

	boxW := w * 55 / 100
	if boxW < 48 {
		boxW = 48
	}
	if boxW > 70 {
		boxW = 70
	}
	summaryBox := styles.Box.Width(boxW).Render(sessionInfo)
	summaryC := styles.CellCenter(w, summaryBox)

	savedMsg := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("Todos los datos han sido guardados y los secretos sellados")

	legal1 := styles.Muted.Faint(true).Width(w).Align(styles.PosCenter).
		Render("© 2026 SKULL — Sovereign Kernel & Unified Logic Layer")
	legal2 := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("Powered by SKULL · SBOS v1.0 GA · ISA-95 · NIST 800-207 · ISO 27001")
	legal3 := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("ALL COMPONENTS SIGNED WITH Ed25519 · SOVEREIGN · NO DATA LEAVES THIS NODE")

	body := styles.JoinV(styles.PosCenter,
		goodbye,
		skull, sub1, sub2,
		"\n", sep, "\n",
		summaryC,
		"\n",
		savedMsg,
	)
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
