package panel

import (
	"fmt"
	"strings"
	"time"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
	"bos/internal/tui/tuilog"
)

// unidades del sistema que se pueden monitorear en el viewer de logs.
// El orden define los tabs. "bos-tui" es siempre el primero (logs propios del TUI).
var logTabs = []struct {
	Label  string // nombre del tab
	Target string // identificador journald (-t) o unidad (.service)
}{
	{"TUI",         tuilog.JournalID},   // bos-tui — logs del propio TUI
	{"bos",         "bos.service"},      // daemon IAM Installer
	{"bkernel",     "bkernel.service"},  // Data Kernel CDC
	{"biedata",     "biedata.service"},  // Data Gateway JSON-RPC
	{"bauth",       "bauth.service"},    // Auth Enforce
	{"bsearch",     "bsearch.service"},  // Motor de Búsqueda
	{"kubelet",      "kubelet.service"},  // Kubernetes kubelet
	{"postgresql",  "postgresql.service"},
	{"redis",       "redis-server.service"},
	{"keycloak",    "keycloak.service"},
	{"Todos",       ""},                 // sin filtro — todos los logs del sistema
}

// Logs renderiza el panel de logs con:
//   - Tab por fuente (TUI, daemons SBOS, infraestructura, todos)
//   - Íconos de nivel usando el sistema de estado SBOS
//   - Colores del sistema de estado independiente (tokens_state.go)
//   - Barra de estado con fuente activa, modo follow y conteo de líneas
func Logs(dm dash.DashModel, ring *tuilog.Ring, entries []tuilog.Entry, w, h int) string {
	// ── Barra de tabs ─────────────────────────────────────────────────────
	labels := make([]string, len(logTabs))
	for i, t := range logTabs {
		labels[i] = t.Label
	}
	tabBar := dash.SubTabs(labels, dm.LogDaemon, w)

	activeTab := logTabs[dm.LogDaemon]

	// ── Área de contenido ─────────────────────────────────────────────────
	contentH := h - 4 // tabs + línea status
	if contentH < 2 {
		contentH = 2
	}

	var lines []string

	if activeTab.Target == tuilog.JournalID && ring != nil {
		// Panel "TUI" — muestra el ring de la aplicación directamente (sin journalctl)
		ringEntries := ring.Last(contentH + 50)
		for _, e := range ringEntries {
			lines = append(lines, renderTUILogEntry(e, w))
		}
	} else {
		// Panels de daemons — muestra entradas del viewer de journalctl
		for _, e := range entries {
			lines = append(lines, renderTUILogEntry(e, w))
		}
		// Fallback: si no hay entradas del viewer, mostrar mock del DashModel
		if len(lines) == 0 {
			for _, e := range dm.Logs {
				if activeTab.Target != "" && e.Daemon != activeTab.Label {
					continue
				}
				lines = append(lines, dash.LogLine(e, w))
			}
		}
	}

	if len(lines) == 0 {
		lines = append(lines,
			"",
			"  "+styles.Dim.Render(styles.Tint(styles.IconDotDim, styles.ColorTextDisabled)+" Sin entradas"),
			"  "+styles.Dim.Render(fmt.Sprintf("journalctl -t %s", activeTab.Target)),
		)
	}

	// Limitar a las últimas contentH líneas (tail natural)
	if len(lines) > contentH {
		lines = lines[len(lines)-contentH:]
	}

	body := strings.Join(lines, "\n")

	// ── Barra de estado inferior ──────────────────────────────────────────
	statusBar := buildStatusBar(activeTab.Target, len(lines), w)

	return strings.Join([]string{tabBar, "", body, "", statusBar}, "\n")
}

// renderTUILogEntry renderiza una Entry de tuilog con íconos + colores de estado SBOS.
func renderTUILogEntry(e tuilog.Entry, maxW int) string {
	// Ícono y color según nivel — sistema de estado independiente
	var icon string
	var msgStyle styles.Style
	var lvlStyle styles.Style

	switch e.Level {
	case tuilog.LevelCrit:
		icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
		lvlStyle = styles.Danger
		msgStyle = styles.StatusErr
	case tuilog.LevelError:
		icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
		lvlStyle = styles.Error
		msgStyle = styles.StatusErr
	case tuilog.LevelWarn:
		icon = styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
		lvlStyle = styles.Warning
		msgStyle = styles.StatusWarn
	case tuilog.LevelDebug:
		icon = styles.Tint(styles.IconDotDim, styles.ColorTextDisabled)
		lvlStyle = styles.Disabled
		msgStyle = styles.Disabled
	default: // Info
		icon = styles.Tint(styles.IconInfo, styles.ColorTextMuted)
		lvlStyle = styles.Info
		msgStyle = styles.TableHeader
	}

	// Timestamp HH:MM:SS
	ts := styles.Dim.Render(e.Ts.Format("15:04:05"))

	// Fuente — ancho fijo 10 cols, color índigo (idle state = "subsistema en proceso")
	srcStyle := styles.Pending.Copy().Width(10)
	src := srcStyle.Render(truncStr(e.Source, 10))

	// Nivel — ancho fijo 5 cols
	lvl := lvlStyle.Render(e.Level.String())

	prefix := icon + " " + ts + "  " + src + "  " + lvl + "  "
	prefixW := styles.TextWidth(prefix)

	// Mensaje — truncar si no cabe
	msg := e.Message
	maxMsg := maxW - prefixW - 1
	if maxMsg > 4 && len(msg) > maxMsg {
		msg = msg[:maxMsg-1] + "…"
	}

	return prefix + msgStyle.Render(msg)
}

// buildStatusBar construye la línea de estado inferior del panel de logs.
func buildStatusBar(target string, lineCount, w int) string {
	var parts []string

	// Indicador de fuente activa
	if target == "" {
		parts = append(parts, styles.StatusWarn.Render("● Todos"))
	} else {
		parts = append(parts, styles.StatusOK.Render("● "+target))
	}

	// Modo follow (siempre activo en el viewer)
	parts = append(parts, styles.Dim.Render("follow: ON"))

	// Conteo de líneas
	parts = append(parts,
		styles.Dim.Render(fmt.Sprintf("%d líneas", lineCount)),
	)

	// Timestamp de última actualización
	parts = append(parts,
		styles.Dim.Render("actualizado: "+time.Now().Format("15:04:05")),
	)

	statusLine := strings.Join(parts, "  │  ")
	padR := w - styles.TextWidth(statusLine) - 2
	if padR < 0 {
		padR = 0
	}
	_ = padR

	return styles.Muted.Render(statusLine)
}

// LogTabTarget retorna el identificador journald del tab en el índice dado.
// Para el tab "TUI" retorna tuilog.JournalID ("bos-tui").
// Para "Todos" retorna "" (sin filtro -t en journalctl).
func LogTabTarget(idx int) string {
	if idx < 0 || idx >= len(logTabs) {
		return ""
	}
	return logTabs[idx].Target
}

// LogTabCount retorna el número de tabs disponibles en el viewer de logs.
func LogTabCount() int { return len(logTabs) }

// truncStr trunca s a maxLen runes con "…" si es necesario.
func truncStr(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	if maxLen <= 1 {
		return "…"
	}
	return string(runes[:maxLen-1]) + "…"
}
