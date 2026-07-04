// Package tui — icon.go: renderizador de PNG a arte ANSI half-block.
//
// Convierte un PNG con fondo transparente en un bloque de texto coloreado
// usando el truco half-block: cada carácter ▀ representa 2 píxeles verticales.
// El pixel superior se mapea a Foreground y el inferior a Background, logrando
// el doble de resolución vertical respecto al número de líneas de terminal.
//
// Dependencias: solo stdlib (image, image/png, image/color) + lipgloss.
// Sin dependencias externas de resize — implementación propia nearest-neighbor.
package tui

import (
	"bytes"
	_ "embed"
	"fmt"
	"image"
	"image/color"
	_ "image/png" // registra el decoder PNG
	"io"
	"os"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

//go:embed assets/sbos-icon.png
var sbosIconPNG []byte

// RenderIconSBOS renderiza el ícono SBOS embebido en el binario como arte ANSI half-block.
// Variante preferida para producción — no depende de ningún path en disco.
// cols y rows son las dimensiones deseadas EN CARACTERES DE TERMINAL.
func RenderIconSBOS(cols, rows int) (string, error) {
	return renderIconFrom(bytes.NewReader(sbosIconPNG), cols, rows)
}

// RenderIcon carga el PNG en path y lo convierte a arte ANSI half-block.
// Útil para pruebas con íconos alternativos en disco.
func RenderIcon(path string, cols, rows int) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("icon: %w", err)
	}
	defer f.Close()
	return renderIconFrom(f, cols, rows)
}

// renderIconFrom es el núcleo de la conversión PNG → ANSI half-block.
// Acepta cualquier io.Reader para que sea reutilizable desde embed y desde disco.
func renderIconFrom(r io.Reader, cols, rows int) (string, error) {
	if cols <= 0 || rows <= 0 {
		return "", nil
	}
	src, _, err := image.Decode(r)
	if err != nil {
		return "", fmt.Errorf("icon decode: %w", err)
	}

	px := resizeNearestNeighbor(src, cols, rows*2)

	var sb strings.Builder
	for y := 0; y < rows*2-1; y += 2 {
		for x := 0; x < cols; x++ {
			top := blendOnTUIDark(px.NRGBAAt(x, y))
			bot := blendOnTUIDark(px.NRGBAAt(x, y+1))
			if top.A == 0 && bot.A == 0 {
				sb.WriteByte(' ')
				continue
			}
			style := lipgloss.NewStyle().
				Foreground(nrgbaToHex(top)).
				Background(nrgbaToHex(bot))
			sb.WriteString(style.Render("▀"))
		}
		sb.WriteByte('\n')
	}
	return sb.String(), nil
}

// resizeNearestNeighbor redimensiona src a (w, h) usando nearest-neighbor.
// Suficiente para logos con colores planos; evita dependencias externas.
func resizeNearestNeighbor(src image.Image, w, h int) *image.NRGBA {
	sb := src.Bounds()
	sw, sh := sb.Dx(), sb.Dy()
	dst := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		sy := sb.Min.Y + y*sh/h
		for x := 0; x < w; x++ {
			sx := sb.Min.X + x*sw/w
			r, g, b, a := src.At(sx, sy).RGBA()
			dst.SetNRGBA(x, y, color.NRGBA{
				R: uint8(r >> 8),
				G: uint8(g >> 8),
				B: uint8(b >> 8),
				A: uint8(a >> 8),
			})
		}
	}
	return dst
}

// tuiDarkR/G/B son los componentes de PrimSlate900 (#0f172a) — fondo base del TUI.
const (
	tuiDarkR = 0x0f
	tuiDarkG = 0x17
	tuiDarkB = 0x2a
)

// blendOnTUIDark compone el pixel c sobre el fondo oscuro del TUI (#0f172a).
// Pixels completamente transparentes devuelven NRGBA{A:0} para tratarse como espacio.
// Pixels semitransparentes se mezclan correctamente para evitar halos en el borde circular.
func blendOnTUIDark(c color.NRGBA) color.NRGBA {
	if c.A == 0 {
		return color.NRGBA{}
	}
	a := float64(c.A) / 255.0
	blend := func(fg, bg uint8) uint8 {
		return uint8(float64(fg)*a + float64(bg)*(1-a))
	}
	return color.NRGBA{
		R: blend(c.R, tuiDarkR),
		G: blend(c.G, tuiDarkG),
		B: blend(c.B, tuiDarkB),
		A: 0xff,
	}
}

// nrgbaToHex convierte un color.NRGBA a la cadena "#RRGGBB" que lipgloss acepta.
func nrgbaToHex(c color.NRGBA) lipgloss.Color {
	return lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", c.R, c.G, c.B))
}
