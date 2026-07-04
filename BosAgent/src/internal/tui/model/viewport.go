// Package model — viewport.go: helpers de dimensionado y scrollbars del TUI.
// Extraído de cmd/bosctl/install_ui.go en F3.7 (BOS-REPAIR — corrige P10).
package model

import (
	"strings"

	"bos/internal/tui/styles"

	"github.com/charmbracelet/bubbles/viewport"
)

// VpDims calcula (wA, wB, wC, height) para los 3 viewports de la pantalla MD.
// contentWidth / contentHeight son los píxeles efectivos del body (sin márgenes).
// Garantiza que wA+wB+wC = contentWidth (frame de 2 por panel, border solamente).
func VpDims(contentWidth, contentHeight int) (wA, wB, wC, h int) {
	h = contentHeight - 10
	if h < 4 {
		h = 4
	}
	if contentWidth < 50 {
		return 14, 12, 14, h
	}
	frame := 2 // border izquierdo + derecho — sin padding extra
	outerA := contentWidth / 3
	outerB := contentWidth / 3
	outerC := contentWidth - outerA - outerB
	wA = outerA - frame
	wB = outerB - frame
	wC = outerC - frame
	if wA < 10 {
		wA = 10
	}
	if wB < 10 {
		wB = 10
	}
	if wC < 18 {
		wC = 18
	}
	return
}

// VScrollbar renderiza un scrollbar vertical de h líneas para el viewport dado.
// Usa ▋ para el thumb (acento) y ┆ para el track (slate).
// Si el contenido cabe entero, muestra track tenue sin thumb.
func VScrollbar(vp viewport.Model, h int) string {
	track := styles.ScrollTrack.Render("┆")
	thumb := styles.ScrollThumb.Render("▋")
	if h <= 0 {
		return ""
	}
	if vp.TotalLineCount() <= vp.Height {
		lines := make([]string, h)
		for i := range lines {
			lines[i] = track
		}
		return strings.Join(lines, "\n")
	}
	pct := vp.ScrollPercent()
	thumbPos := int(pct * float64(h-1))
	if thumbPos >= h {
		thumbPos = h - 1
	}
	lines := make([]string, h)
	for i := range lines {
		if i == thumbPos {
			lines[i] = thumb
		} else {
			lines[i] = track
		}
	}
	return strings.Join(lines, "\n")
}

// HScrollbar renderiza un scrollbar horizontal de w chars para el viewport dado.
// Usa ▬ para el thumb (acento) y ╌ para el track (slate).
// Si no hay scroll horizontal muestra track tenue.
func HScrollbar(vp viewport.Model, w int) string {
	if w <= 0 {
		return ""
	}
	trackCh := styles.ScrollTrack.Render("╌")
	thumbCh := styles.ScrollThumb.Render("▬")
	pct := vp.HorizontalScrollPercent()
	if pct <= 0 {
		out := make([]string, w)
		for i := range out {
			out[i] = trackCh
		}
		return strings.Join(out, "")
	}
	thumbPos := int(pct * float64(w-1))
	if thumbPos >= w {
		thumbPos = w - 1
	}
	out := make([]string, w)
	for i := range out {
		if i == thumbPos {
			out[i] = thumbCh
		} else {
			out[i] = trackCh
		}
	}
	return strings.Join(out, "")
}
