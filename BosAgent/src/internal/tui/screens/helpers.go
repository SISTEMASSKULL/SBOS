// Package screens — helpers.go: utilidades de display exclusivas de screens/.
// Las funciones de formato puro (FormatDur, TruncA, WordWrap, MaxInt, BootMessage)
// viven en internal/tui/util/format.go — fuente canónica sin duplicados.
// Las versiones de fichas viven en internal/tui/util/ficha.go.
package screens

import (
	"bos/internal/tui/styles"

	"github.com/mattn/go-runewidth"
)

// summaryRow renderiza una fila de resumen con label de ancho fijo 10 chars (doc §P4).
// Usada por s04_confirmar.go.
func summaryRow(label, value string) string {
	l := styles.Dim.Width(10).Render(label)
	v := styles.TableHeader.Render(value)
	return l + " " + v
}

// StepMsgSuffix retorna ": msg" si msg no está vacío.
func StepMsgSuffix(msg string) string {
	if msg != "" {
		return ": " + msg
	}
	return ""
}

// TruncByWidth recorta s hasta que su ancho de display ≤ maxW.
// Necesario para emoji SMP (runewidth=2) que TruncA no maneja correctamente.
func TruncByWidth(s string, maxW int) string {
	w := 0
	for i, r := range s {
		rw := runewidth.RuneWidth(r)
		if w+rw > maxW {
			return s[:i]
		}
		w += rw
	}
	return s
}

// ClipColumnCenter centra visualmente focusLine dentro de maxH líneas.
func ClipColumnCenter(lines []string, maxH, focusLine int) []string {
	if len(lines) <= maxH {
		return lines
	}
	start := focusLine - maxH/2
	if start < 0 {
		start = 0
	}
	end := start + maxH
	if end > len(lines) {
		end = len(lines)
		start = end - maxH
		if start < 0 {
			start = 0
		}
	}
	return lines[start:end]
}

// ClipColumnTail retorna las últimas maxH líneas (tail view).
// Si withScrollbar=true, deja una línea extra para el scrollbar.
func ClipColumnTail(lines []string, maxH int, withScrollbar bool) []string {
	if withScrollbar && maxH > 1 {
		maxH--
	}
	if len(lines) <= maxH {
		return lines
	}
	return lines[len(lines)-maxH:]
}
