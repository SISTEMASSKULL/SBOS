package dash

import (
	"fmt"
	"strings"
	"time"

	"bos/internal/tui/styles"
)

// Gauge renderiza una barra de progreso porcentual.
func Gauge(pct float64, w int) string {
	if w < 4 {
		w = 4
	}
	barW := w - 7
	if barW < 2 {
		barW = 2
	}
	if pct > 100 {
		pct = 100
	}
	if pct < 0 {
		pct = 0
	}
	filled := int(float64(barW) * pct / 100.0)
	if filled > barW {
		filled = barW
	}
	bar := styles.ProgressFill.Copy().Foreground(ColorForPct(pct)).Render(strings.Repeat("█", filled)) +
		styles.Dim.Render(strings.Repeat("░", barW-filled))
	return fmt.Sprintf("[%s] %3.0f%%", bar, pct)
}

// GaugeColored renderiza una barra con color explícito.
func GaugeColored(pct float64, w int, color styles.Color) string {
	if w < 4 {
		w = 4
	}
	barW := w - 7
	if barW < 2 {
		barW = 2
	}
	if pct > 100 {
		pct = 100
	}
	filled := int(float64(barW) * pct / 100.0)
	if filled > barW {
		filled = barW
	}
	bar := styles.ProgressFill.Copy().Foreground(color).Render(strings.Repeat("█", filled)) +
		styles.Dim.Render(strings.Repeat("░", barW-filled))
	return fmt.Sprintf("[%s] %3.0f%%", bar, pct)
}

// ColorForPct retorna el color de estado según porcentaje (OK→Warn→Err).
func ColorForPct(pct float64) styles.Color {
	switch {
	case pct >= 85:
		return styles.ColorStateErrFg
	case pct >= 70:
		return styles.ColorStateWarnFg
	default:
		return styles.ColorStateOKFg
	}
}

// MiniBar renderiza una barra compacta sin porcentaje.
func MiniBar(pct float64, w int, color styles.Color) string {
	if pct > 100 {
		pct = 100
	}
	filled := int(float64(w) * pct / 100.0)
	if filled > w {
		filled = w
	}
	return styles.ProgressFill.Copy().Foreground(color).Render(strings.Repeat("█", filled)) +
		styles.Dim.Render(strings.Repeat("░", w-filled))
}

// Dot renderiza un indicador de estado (✓ / ↻ / ✗).
func Dot(healthy, warning bool) string {
	switch {
	case !healthy && !warning:
		return styles.Tint(styles.IconErr, styles.ColorStateErrFg)
	case warning:
		return styles.Tint(styles.IconSync, styles.ColorStateWarnFg)
	default:
		return styles.Tint(styles.IconOK, styles.ColorStateOKFg)
	}
}

// AlertIcon retorna el icono según severidad de alerta.
func AlertIcon(sev AlertSeverity) string {
	switch sev {
	case SevCritical:
		return styles.Tint(styles.IconErr, styles.ColorStateErrFg)
	case SevWarning:
		return styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
	default:
		return styles.Dim.Render("ℹ")
	}
}

// HPADot retorna el icono de estado de un HPA.
func HPADot(s HPAStatus) string {
	switch s {
	case HPAScaling:
		return styles.AccentBold.Render("⚡")
	case HPAAtMax:
		return styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
	default:
		return styles.Tint(styles.IconDotActive, styles.ColorAccentText)
	}
}

// PodDot retorna el icono de estado de un pod.
func PodDot(s PodStatus) string {
	switch s {
	case PodRunning:
		return styles.Tint(styles.IconOK, styles.ColorStateOKFg)
	case PodPending:
		return styles.Tint(styles.IconSync, styles.ColorStateWarnFg)
	default:
		return styles.Tint(styles.IconErr, styles.ColorStateErrFg)
	}
}

// SectionHeader renderiza un título de sección en itálica atenuada.
func SectionHeader(title string) string {
	return styles.SectionTitle.Render(title)
}

// ColSep renderiza una línea separadora horizontal de ancho w.
func ColSep(w int) string {
	if w < 1 {
		w = 1
	}
	return styles.Dim.Render(strings.Repeat("─", w))
}

// RightPane envuelve contenido en un panel con borde vertical izquierdo.
func RightPane(content string, w int) string {
	return styles.Inactive.
		Copy().
		BorderLeft(true).
		BorderStyle(styles.NormalBorder()).
		PaddingLeft(1).
		Width(w).
		Render(content)
}

// LogLine renderiza una entrada de log con ícono de estado, timestamp y fuente.
func LogLine(e LogEntry, w int) string {
	var icon string
	var lvlStyle styles.Style
	var lvlTag string

	switch e.Level {
	case LogError:
		icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
		lvlStyle = styles.StatusErr
		lvlTag = "ERROR"
	case LogWarn:
		icon = styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
		lvlStyle = styles.StatusWarn
		lvlTag = "WARN "
	default:
		icon = styles.Tint(styles.IconInfo, styles.ColorTextMuted)
		lvlStyle = styles.Info
		lvlTag = "INFO "
	}

	srcStyle := styles.Pending.Copy().Width(12)

	prefix := icon + " " + lvlStyle.Render(lvlTag) + "  " +
		styles.Dim.Render(e.Time) + "  " +
		srcStyle.Render(e.Daemon) + "  "

	msg := e.Message
	maxMsg := w - styles.TextWidth(prefix) - 1
	if maxMsg > 0 && len(msg) > maxMsg {
		msg = msg[:maxMsg-1] + "…"
	}
	return prefix + lvlStyle.Render(msg)
}

// SubTabs renderiza una barra de sub-tabs con el activo resaltado.
func SubTabs(tabs []string, active int, w int) string {
	var parts []string
	for i, t := range tabs {
		if i == active {
			parts = append(parts, styles.Cyan.Render(t))
		} else {
			parts = append(parts, styles.Dim.Render(t))
		}
	}
	line := strings.Join(parts, "  ")
	_ = w
	return line
}

// Placeholder renderiza un panel "Vista en desarrollo".
func Placeholder(title string, w, h int) string {
	msg := styles.JoinV(styles.PosCenter,
		"",
		styles.AccentBold.Render(title),
		"",
		styles.Dim.Render("Vista en desarrollo"),
		styles.Dim.Render("Disponible en la próxima fase"),
	)
	return styles.NewStyle().
		Width(w).
		Height(h).
		Align(styles.PosCenter, styles.PosCenter).
		Render(msg)
}

// FormatBytesPS formatea bytes/s a unidad legible.
func FormatBytesPS(b float64) string {
	switch {
	case b >= 1024*1024:
		return fmt.Sprintf("%.1f MB/s", b/1024/1024)
	case b >= 1024:
		return fmt.Sprintf("%.1f KB/s", b/1024)
	default:
		return fmt.Sprintf("%.0f B/s", b)
	}
}

// FormatDur formatea una duración a "Xd Xh Xm".
func FormatDur(d time.Duration) string {
	d = d.Round(time.Minute)
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	mins := int(d.Minutes()) % 60
	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm", days, hours, mins)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, mins)
	}
	return fmt.Sprintf("%dm", mins)
}

// SparklineASCII renderiza una sparkline de bloque con los últimos w valores.
func SparklineASCII(values []float64, w int, color styles.Color) string {
	blocks := []rune{' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'}
	if len(values) == 0 {
		return styles.Dim.Render(strings.Repeat("░", w))
	}
	start := 0
	if len(values) > w {
		start = len(values) - w
	}
	vals := values[start:]
	minV, maxV := vals[0], vals[0]
	for _, v := range vals {
		if v < minV {
			minV = v
		}
		if v > maxV {
			maxV = v
		}
	}
	var sb strings.Builder
	for _, v := range vals {
		idx := 0
		if maxV > minV {
			idx = int((v-minV)/(maxV-minV)*8 + 0.5)
		}
		if idx > 8 {
			idx = 8
		}
		sb.WriteRune(blocks[idx])
	}
	for styles.TextWidth(sb.String()) < w {
		sb.WriteRune('░')
	}
	return styles.ProgressFill.Copy().Foreground(color).Render(sb.String())
}

// SparklineStats retorna (cur, avg, min, max) de una serie de valores.
func SparklineStats(values []float64) (cur, avg, minV, maxV float64) {
	if len(values) == 0 {
		return
	}
	cur = values[len(values)-1]
	minV, maxV = values[0], values[0]
	sum := 0.0
	for _, v := range values {
		sum += v
		if v < minV {
			minV = v
		}
		if v > maxV {
			maxV = v
		}
	}
	avg = sum / float64(len(values))
	return
}

// ColorPct formatea un porcentaje con color contextual.
func ColorPct(pct float64) string {
	return styles.ProgressFill.Copy().Foreground(ColorForPct(pct)).Render(fmt.Sprintf("%.0f%%", pct))
}

// Min4 es un helper min(a,b) para enteros.
func Min4(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Truncate trunca s a max runes, añadiendo "…" si se acorta.
func Truncate(s string, max int) string {
	if max <= 0 {
		return s
	}
	if len(s) <= max {
		return s
	}
	if max <= 1 {
		return "…"
	}
	return s[:max-1] + "…"
}

// ColWidths distribuye w en columnas proporcionales según porcentajes.
func ColWidths(w int, pcts []int) []int {
	widths := make([]int, len(pcts))
	if len(pcts) == 0 {
		return widths
	}
	used := 0
	for i, p := range pcts[:len(pcts)-1] {
		widths[i] = w * p / 100
		if widths[i] < 1 {
			widths[i] = 1
		}
		used += widths[i]
	}
	last := w - used
	if last < 1 {
		last = 1
	}
	widths[len(pcts)-1] = last
	return widths
}
