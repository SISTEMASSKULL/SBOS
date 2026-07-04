package styles

import "github.com/charmbracelet/lipgloss"

// Alias de tipos — screens y ctrl usan styles.Style/Color/Position/Border
// sin importar lipgloss directamente.
type (
	Style    = lipgloss.Style
	Color    = lipgloss.Color
	Position = lipgloss.Position
	Border   = lipgloss.Border
)

// NewStyle construye un estilo vacío — punto único de entrada a lipgloss.
func NewStyle() lipgloss.Style { return lipgloss.NewStyle() }

// Posiciones de alineación — re-exportadas de lipgloss.
var (
	PosTop    = lipgloss.Top
	PosBottom = lipgloss.Bottom
	PosCenter = lipgloss.Center
	PosLeft   = lipgloss.Left
	PosRight  = lipgloss.Right
)

// JoinH une strings horizontalmente con la posición vertical indicada.
func JoinH(pos lipgloss.Position, strs ...string) string {
	return lipgloss.JoinHorizontal(pos, strs...)
}

// JoinV une strings verticalmente con la posición horizontal indicada.
func JoinV(pos lipgloss.Position, strs ...string) string {
	return lipgloss.JoinVertical(pos, strs...)
}

// TextWidth devuelve el ancho visual (en celdas de terminal) de s.
func TextWidth(s string) int { return lipgloss.Width(s) }

// TextHeight devuelve la altura en líneas de s.
func TextHeight(s string) int { return lipgloss.Height(s) }

// Cell renderiza text en una columna de ancho fijo w (sin color).
func Cell(w int, text string) string {
	return lipgloss.NewStyle().Width(w).Render(text)
}

// CellCenter renderiza text centrado en una columna de ancho w.
func CellCenter(w int, text string) string {
	return lipgloss.NewStyle().Width(w).Align(lipgloss.Center).Render(text)
}

// MaxCell aplica un ancho máximo maxW a text.
func MaxCell(maxW int, text string) string {
	return lipgloss.NewStyle().MaxWidth(maxW).Render(text)
}

// Place posiciona text en un área w×h con alineación hPos/vPos.
func Place(w, h int, hPos, vPos lipgloss.Position, str string) string {
	return lipgloss.Place(w, h, hPos, vPos, str)
}

// NormalBorder devuelve el borde normal de lipgloss.
func NormalBorder() lipgloss.Border { return lipgloss.NormalBorder() }

// RoundedBorder devuelve el borde redondeado de lipgloss.
func RoundedBorder() lipgloss.Border { return lipgloss.RoundedBorder() }

// ThickBorder devuelve el borde grueso de lipgloss.
func ThickBorder() lipgloss.Border { return lipgloss.ThickBorder() }

// DoubleBorder devuelve el borde doble de lipgloss.
func DoubleBorder() lipgloss.Border { return lipgloss.DoubleBorder() }
