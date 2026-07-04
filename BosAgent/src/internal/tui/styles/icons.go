// Package styles — icons.go: catálogo único de íconos del TUI SBOS (TUI-LIB-005).
//
// REGLA: todo símbolo Unicode/emoji del TUI proviene de aquí.
// Ningún archivo de screens/ ni ctrl/ puede declarar símbolos inline.
// Para cambiar un ícono globalmente: editar solo este archivo.
//
// DISEÑO (revisión junio 2026 — integración con theme system):
// Los íconos son glyphs PLANOS, sin color. El color se inyecta en el call
// site usando Tint()/TintBold() con un color del theme activo o uno
// personalizado. Este archivo NO importa ni depende de ningún color del
// theme — esa responsabilidad es exclusiva de quien renderiza.
//
//	// con color del theme:
//	styles.Tint(styles.IconOK, theme.Success)
//	// con color personalizado (ej. preferencia de usuario, severidad dinámica):
//	styles.Tint(styles.IconWarn, lipgloss.Color("#FF8800"))
//
// Los comentarios "color sugerido" junto a cada ícono documentan qué color
// usaba el diseño anterior (antes de decolorearlos) a modo de guía semántica,
// no son vinculantes — el theme define el color real.
package styles

import "github.com/charmbracelet/lipgloss"

// ── Inyección de color ────────────────────────────────────────────────────
//
// Tint/TintBold agregan automáticamente un espacio de padding después del
// glyph. Esto NO es estético: varios símbolos de este catálogo tienen
// presentación "wide"/emoji en ciertas terminales (renderizan ocupando 2
// columnas) mientras que el cálculo de ancho de Go/lipgloss asume 1 columna.
// Ese desfase corrompe visualmente el carácter siguiente. El espacio
// absorbe la columna extra y evita tener que recordarlo en cada call site
// (que era justo el bug recurrente que motivó normalizar este archivo).
//
// Usar TintTight() únicamente si el layout ya maneja el espaciado a mano
// (ej. celdas de ancho fijo en una tabla donde el padding rompería la
// alineación).

// Tint aplica color + padding de seguridad a un ícono. Uso por defecto.
func Tint(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Render(glyph + " ")
}

// TintBold aplica color + negrita + padding (uso típico: cursores, estados críticos).
func TintBold(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Bold(true).Render(glyph + " ")
}

// TintTight aplica color SIN padding. Usar solo cuando el layout controla
// el espaciado manualmente (tablas, celdas de ancho fijo, etc.).
func TintTight(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Render(glyph)
}

// ── Categoría: Estado ─────────────────────────────────────────────────────

const (
	IconOK   = "✓" // U+2713 — color sugerido: éxito/acento
	IconErr  = "✗" // U+2717 — color sugerido: error
	IconWarn = "⚠" // U+26A0 — color sugerido: advertencia
	IconInfo = "›" // U+203A — color sugerido: info (cyan)
)

// IconDone es alias semántico de IconOK para estados "completado".
const IconDone = IconOK

// IconDelete es alias semántico de IconErr para acciones destructivas.
const IconDelete = IconErr

// ── Categoría: Actividad ──────────────────────────────────────────────────
// Nota: las 4 constantes de "dot" comparten el mismo glyph (●); antes se
// distinguían solo por color. Mantenidas como nombres separados por
// claridad semántica en el call site — el color las diferencia en runtime.

const (
	IconDotActive  = "●" // U+25CF — color sugerido: éxito/acento (antes IconActive)
	IconDotPending = "●" // U+25CF — color sugerido: advertencia (antes IconDotYellow)
	IconDotError   = "●" // U+25CF — color sugerido: error (antes IconDotRed)
	IconDotDim     = "●" // U+25CF — color sugerido: tenue/inactivo
	IconCircleOpen = "○" // U+25CB — color sugerido: neutro/pendiente (antes IconPending)
	IconSync       = "↻" // U+21BB — color sugerido: advertencia (en progreso)
)

// ── Categoría: Acciones del sistema ───────────────────────────────────────

const (
	IconPower      = "⏻" // U+23FB — color sugerido: error (apagado)
	IconRestart    = "↺" // U+21BA — color sugerido: advertencia
	IconRun        = "›" // U+203A — color sugerido: info/cyan (mismo glyph que IconInfo)
	IconStepRun    = "›" // U+203A — color sugerido: advertencia (paso activo en instalación)
	IconArrowUp    = "↑" // U+2191 — antes IconInstall/IconUpdate (mismo glyph, distinto color)
	IconRepair     = "⚙" // U+2699 — color sugerido: advertencia
)

// ── Categoría: Fichas / Paquetes ────────────────────────────────────────────
// Reemplazan los emojis 📦 y 🚀, inestables en terminales sin emoji support.

const (
	IconFicha     = "◆" // U+25C6 — color sugerido: cyan
	IconBootstrap = "▶" // U+25B6 — color sugerido: acento
)

// ── Categoría: Navegación / Cursor ──────────────────────────────────────────

const (
	IconCursor = "›" // U+203A — color sugerido: cyan (mismo glyph que IconInfo/IconRun)
	IconArrowR = "→" // U+2192 — color sugerido: muted
	IconSep    = "│" // U+2502 — color sugerido: slate/tenue
)

// ── Categoría: Daemons SBOS ──────────────────────────────────────────────
// Identificadores visuales únicos por daemon soberano.

const (
	IconBos     = "⬡" // U+2B21 — daemon BOS (instalador) — color sugerido: cyan
	IconBAuth   = "⊕" // U+2295 — daemon bAuth (identidad) — color sugerido: acento
	IconBKernel = "⊙" // U+2299 — daemon bKernel (WAL/CDC) — color sugerido: cyan
	IconBiedata = "⊗" // U+2297 — daemon biedata (JSON-RPC gateway) — color sugerido: advertencia
	IconBSearch = "◎" // U+25CE — daemon bSearch (búsqueda PG) — color sugerido: cyan
	IconBNexus  = "⊘" // U+2298 — daemon bhnexus/banexus (conectividad física) — color sugerido: muted
	IconBNotify = "◇" // U+25C7 — daemon bnotify (notificaciones/MFA) — color sugerido: advertencia
)

// IconBGeneric: glyph reservado y libre para el próximo daemon SBOS que se
// agregue (no colisiona con ninguno de los anteriores).
const IconBGeneric = "⊚" // U+229A

// ── Categoría: Seguridad / Auth ───────────────────────────────────────────

const (
	IconLock = "⊡" // U+22A1 — color sugerido: advertencia
	IconKey  = "✦" // U+2726 — color sugerido: advertencia
	IconMFA  = "⊕" // U+2295 — color sugerido: cyan (mismo glyph que IconBAuth, contexto distinto)
)

// ── Categoría: Progreso ───────────────────────────────────────────────────

// SpinnerFrames: frames Braille para animaciones de espera. Sin color —
// aplicar Tint() por frame si se necesita un color fijo.
// Uso: styles.Tint(styles.SpinnerFrames[tick%len(styles.SpinnerFrames)], theme.Accent)
var SpinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

// SpinnerFramesClock: alternativa de 4 frames "reloj", para contextos donde
// se prefiera ese look (ej. countdown de instalación, timeouts).
var SpinnerFramesClock = []string{"◴", "◵", "◶", "◷"} // U+25F4–25F7

// Spin/SpinClock NO manejan el reloj — el contador `tick` lo posee y avanza
// el modelo Bubbletea (vía tea.Tick en Update()). Estas funciones solo
// traducen ese contador al frame correcto + color, para no repetir el
// cálculo de módulo en cada pantalla. Ver tutorial al final del archivo
// para el wiring completo con tea.Tick.

// Spin devuelve el frame de spinner Braille correspondiente a tick, coloreado.
func Spin(tick int, color lipgloss.TerminalColor) string {
	frame := SpinnerFrames[tick%len(SpinnerFrames)]
	return Tint(frame, color)
}

// SpinClock devuelve el frame de spinner "reloj" correspondiente a tick, coloreado.
func SpinClock(tick int, color lipgloss.TerminalColor) string {
	frame := SpinnerFramesClock[tick%len(SpinnerFramesClock)]
	return Tint(frame, color)
}

// ── Categoría: Red / Conectividad ─────────────────────────────────────────
// Para estados de daemons que dependen de red (bSearch, bhnexus, Kong GW).

const (
	IconUploadActivity   = "⇡" // U+21E1 — color sugerido: advertencia
	IconDownloadActivity = "⇣" // U+21E3 — color sugerido: acento
	IconSyncBidi         = "⇄" // U+21C4 — color sugerido: cyan
	IconLinkBroken       = "⇏" // U+21CF — color sugerido: error
	IconPulse            = "◌" // U+25CC — color sugerido: tenue
)

// ── Categoría: Almacenamiento / Datos ─────────────────────────────────────

const (
	IconDatabase = "▤" // U+25A4 — color sugerido: cyan
	IconVolume   = "▥" // U+25A5 — color sugerido: muted
	IconArchive  = "▦" // U+25A6 — color sugerido: advertencia
	IconBackup   = "⟲" // U+27F2 — color sugerido: acento
	IconRestore  = "⟳" // U+27F3 — color sugerido: advertencia
)

// ── Categoría: Métricas / Barras de progreso ──────────────────────────────
// Pensados para medidores de uso (CPU/RAM/disco) y sparklines simples.

const (
	IconBlockFull = "█" // U+2588 — ~100%
	IconBlockHigh = "▓" // U+2593 — ~75%
	IconBlockMed  = "▒" // U+2592 — ~50%
	IconBlockLow  = "░" // U+2591 — ~25%
	IconTrendUp   = "◢" // U+25E2 — color sugerido: acento
	IconTrendDown = "◣" // U+25E3 — color sugerido: error
	IconGaugeHalf = "◐" // U+25D0 — color sugerido: advertencia
)

// ── Categoría: Jerarquía / Árbol ──────────────────────────────────────────
// Conectores para listas anidadas (ej. árbol de procesos, dependencias).

const (
	IconTreeBranch = "├" // U+251C — rama intermedia
	IconTreeLast   = "└" // U+2514 — última rama
	IconTreeLine   = "─" // U+2500 — relleno horizontal
	IconTreeVert   = "│" // U+2502 — continuación vertical (mismo glyph que IconSep)
)

// ── Categoría: Selección / Formularios ────────────────────────────────────
// Para wizards estilo DevInstaller (selección múltiple, opciones exclusivas).

const (
	IconCheckboxOn  = "☑" // U+2611 — color sugerido: acento
	IconCheckboxOff = "☐" // U+2610 — color sugerido: tenue
	IconRadioOn     = "◉" // U+25C9 — color sugerido: cyan
	// Para "radio off" reutilizar IconCircleOpen — mismo semántico de "no seleccionado".
)

// ── Categoría: CI / CD y Build ─────────────────────────────────────────────
// Pensado para el pipeline GAP1 (GitHub Actions, validate.sh, cobertura).
// Para pass/fail de build reutilizar IconOK / IconErr — no duplicar glyphs.

const (
	IconCoverage = "◔" // U+25D4 — color sugerido: advertencia
	IconLint     = "◧" // U+25E7 — color sugerido: cyan
	IconRelease  = "⚑" // U+2691 — color sugerido: acento
)

// ═══════════════════════════════════════════════════════════════════════
// TUTORIAL DE USO
// ═══════════════════════════════════════════════════════════════════════
//
// 1. Ícono estático con color del theme activo:
//
//	fmt.Println(styles.Tint(styles.IconOK, theme.Success))
//
// 2. Ícono con color personalizado, sin pasar por el theme (ej. severidad
//    calculada dinámicamente, preferencia de usuario):
//
//	fmt.Println(styles.Tint(styles.IconWarn, lipgloss.Color("#FF8800")))
//
// 3. Cursor de selección activa en un menú (negrita + padding):
//
//	linea := styles.TintBold(styles.IconCursor, theme.Accent) + "Instalar bAuth"
//
// 4. Ícono SIN padding, dentro de una celda de ancho fijo (tablas, donde
//    el espacio extra de Tint() rompería la alineación de columnas):
//
//	celda := lipgloss.NewStyle().Width(3).Render(
//		styles.TintTight(styles.IconDotActive, theme.Success),
//	)
//
// 5. Checkbox en un wizard de selección múltiple (DevInstaller):
//
//	if seleccionado {
//		fmt.Println(styles.Tint(styles.IconCheckboxOn, theme.Accent), "Kong Gateway")
//	} else {
//		fmt.Println(styles.Tint(styles.IconCheckboxOff, theme.Dim), "Kong Gateway")
//	}
//
// 6. Árbol de jerarquía (ej. dependencias de un daemon):
//
//	fmt.Println(styles.IconTreeBranch + styles.IconTreeLine + " bKernel")
//	fmt.Println(styles.IconTreeLast + styles.IconTreeLine + " bSearch")
//
// 7. Spinner animado — el "tick" lo posee y avanza el modelo Bubbletea,
//    NO este archivo. icons.go solo traduce ese contador a frame+color.
//    Wiring completo con tea.Tick:
//
//	type tickMsg struct{}
//
//	type model struct {
//		tick int
//	}
//
//	func (m model) Init() tea.Cmd {
//		return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
//			return tickMsg{}
//		})
//	}
//
//	func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
//		switch msg.(type) {
//		case tickMsg:
//			m.tick++
//			return m, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
//				return tickMsg{}
//			})
//		}
//		return m, nil
//	}
//
//	func (m model) View() string {
//		return styles.Spin(m.tick, theme.Accent) + " Instalando bKernel..."
//	}
//
//    Si preferís el look "reloj" en vez de Braille, mismo wiring pero
//    llamando styles.SpinClock(m.tick, theme.Accent) en View().
//
// REGLA general: si necesitás un símbolo nuevo, agregalo en la categoría
// correspondiente de este archivo (como const plana, sin color) — nunca
// inline en screens/ o ctrl/.