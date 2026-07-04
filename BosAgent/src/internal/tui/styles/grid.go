// Package styles — grid.go: sistema de grid de 12 columnas del TUI SBOS.
//
// El viewport se divide en 12 columnas iguales (ColUnit = TermW/12).
// Zonas horizontales: col 1 = margen izq, cols 2-11 = área de uso, col 12 = margen der.
// Zonas verticales: TopBar (TopBarH líneas) + Body (BodyH) + Footer (FooterH).
//
// Reglas:
//   - Nunca pasar TermW/TermH crudo a un componente — siempre g.ContentW o g.Span(n).
//   - TopBar y Footer usan g.TermW (ocupan el ancho total).
//   - Body usa MarginLeft(g.MarginL).MarginRight(g.MarginR).
//   - BodyH puede ser 0; los componentes deben tolerarlo.
package styles

// TopBarH y FooterH son las alturas fijas en líneas del TUI.
const (
	TopBarH = 3 // título + contexto + separador (dashboard: 3 líneas)
	FooterH = 2 // separador + hints (2 líneas)
)

// Grid centraliza la aritmética del viewport del TUI.
// Todas las medidas son en caracteres / líneas de terminal.
type Grid struct {
	TermW int // ancho total del terminal
	TermH int // alto total del terminal

	// Columnas
	Cols    int // siempre 12
	ColUnit int // ancho de cada columna = TermW / 12

	// Zonas horizontales
	MarginL  int // col 1  — margen izquierdo
	MarginR  int // col 12 — margen derecho
	ContentX int // x de inicio del área de uso (= MarginL)
	ContentW int // ancho del área de uso (cols 2-11 = 10 cols)

	// Zonas verticales
	TopY  int // siempre 0
	TopH  int // altura del topbar (TopBarH)
	FootY int // y de inicio del footer
	FootH int // altura del footer (FooterH)
	BodyY int // y de inicio del área de contenido (= TopH)
	BodyH int // altura del área de contenido
}

// NewGrid construye un Grid a partir del tamaño actual del terminal.
// topH y footH permiten ajustar las zonas fijas según la pantalla activa.
// Si topH/footH son 0 se usan las constantes TopBarH/FooterH.
func NewGrid(w, h int) Grid {
	if w < 12 {
		w = 12
	}

	colUnit := w / 12
	if colUnit < 1 {
		colUnit = 1
	}
	marginL := colUnit
	marginR := colUnit
	contentW := w - marginL - marginR
	if contentW < 1 {
		contentW = 1
	}

	bodyH := h - TopBarH - FooterH
	if bodyH < 0 {
		bodyH = 0
	}

	return Grid{
		TermW: w, TermH: h,
		Cols: 12, ColUnit: colUnit,

		MarginL:  marginL,
		MarginR:  marginR,
		ContentX: marginL,
		ContentW: contentW,

		TopY:  0,
		TopH:  TopBarH,
		FootY: h - FooterH,
		FootH: FooterH,
		BodyY: TopBarH,
		BodyH: bodyH,
	}
}

// Span retorna el ancho en caracteres de n columnas del grid.
// Útil para paneles internos: g.Span(5) = 5 cols del área de uso.
func (g Grid) Span(cols int) int {
	return cols * g.ColUnit
}

// InnerW retorna ContentW descontando el padding de Padding(0,1) de lipgloss.
// Padding(0,1) consume 1 char por lado = 2 totales.
func (g Grid) InnerW() int {
	return ColW(g.ContentW)
}

// ── Helpers de aritmética de anchos ──────────────────────────────────────────

// Mode retorna "xs", "sm" o "md" según el ancho del terminal.
func Mode(w int) string {
	if w < 60 {
		return "xs"
	}
	if w < 80 {
		return "sm"
	}
	return "md"
}

// ColW retorna el ancho utilizable de un panel con Padding(0,1).
// lipgloss Padding(0,1) consume 1 char por lado → 2 totales.
func ColW(w int) int {
	if w < 4 {
		return 0
	}
	return w - 2
}

// ContentW retorna el ancho del contenido interior con padding adicional.
func ContentW(w int) int {
	if w < 6 {
		return 0
	}
	return w - 4
}

// MarginW retorna el margen horizontal lateral para WrapWithMargin.
// Equivalente a termW/12 con mínimo 1 y máximo 16 (clamp superior B-05).
func MarginW(w int) int {
	if w == 0 {
		return 0
	}
	m := w / 12
	if m == 0 {
		return 1
	}
	if m > 16 {
		return 16
	}
	return m
}
